#!/bin/sh

export PATH=/sbin:/usr/sbin:$PATH
DEBOS_CMD=debos
if [ -z ${ARGS+x} ]; then
    ARGS=""
fi

device="pinephone"
image="image"
partitiontable="mbr"
filesystem="ext4"
environment="phosh"
hostname=
arch=
do_compress=
family=
image_only=
installer=
zram=
memory=
password=
use_docker=
username=
no_blockmap=
ssh=
debian_suite="bookworm"
suite="bookworm"
contrib=
sign=
miniramfs=

while getopts "dDizobsZCrx:S:e:H:f:g:h:m:p:t:u:F:" opt
do
  case "$opt" in
    d ) use_docker=1 ;;
    D ) debug=1 ;;
    e ) environment="$OPTARG" ;;
    H ) hostname="$OPTARG" ;;
    i ) image_only=1 ;;
    z ) do_compress=1 ;;
    b ) no_blockmap=1 ;;
    s ) ssh=1 ;;
    o ) installer=1 ;;
    Z ) zram=1 ;;
    f ) ftp_proxy="$OPTARG" ;;
    h ) http_proxy="$OPTARG" ;;
    g ) sign="$OPTARG" ;;
    m ) memory="$OPTARG" ;;
    p ) password="$OPTARG" ;;
    t ) device="$OPTARG" ;;
    u ) username="$OPTARG" ;;
    F ) filesystem="$OPTARG" ;;
    x ) debian_suite="$OPTARG" ;;
    S ) suite="$OPTARG" ;;
    C ) contrib=1 ;;
    r ) miniramfs=1 ;;
  esac
done

case "$device" in
  "pinephone" )
    arch="arm64"
    family="sunxi"
    ;;
  "pinephonepro" )
    arch="arm64"
    family="rockchip"
    suite="staging"
    ARGS="$ARGS -t nonfree:true -t bootstart:16MiB"
    ;;
  "pinetab" )
    arch="arm64"
    family="sunxi"
    ;;
  "librem5" )
    arch="arm64"
    family="librem5"
    ;;
  "oneplus6"|"pocof1" )
    arch="arm64"
    family="sdm845"
    suite="staging"
    ARGS="$ARGS -t nonfree:true -t imagesize:5GB"
    ;;
  "surfacepro3" )
    arch="amd64"
    family="amd64"
    partitiontable="gpt"
    ARGS="$ARGS -t nonfree:true -t imagesize:5GB"
    ;;
  "amd64" )
    arch="amd64"
    family="amd64"
    device="efi"
    partitiontable="gpt"
    ARGS="$ARGS -t imagesize:20GB"
    ;;
  "amd64-legacy" )
    arch="amd64"
    family="amd64"
    device="pc"
    ARGS="$ARGS -t imagesize:20GB"
    ;;
  * )
    echo "Unsupported device '$device'"
    exit 1
    ;;
esac

compress_suffix=
[ "$do_compress" ] && compress_suffix='.gz'

file_date=$(date +%Y%m%d)

installfs_file="installfs-$arch-$file_date.tar$compress_suffix"
rootfs_device_base="rootfs-$device-$environment-$file_date"
rootfs_device_file="$rootfs_device_base.tar$compress_suffix"

image_file_base="mobian-$device-$environment-$file_date"
if [ "$installer" ]; then
  image="installer"
  image_file_base="mobian-installer-$device-$environment-$file_date"
fi

rootfs_file="rootfs-$arch-$environment-$file_date.tar$compress_suffix"
if echo $ARGS | grep -q "nonfree:true"; then
  rootfs_file="rootfs-$arch-$environment-nonfree-$file_date.tar$compress_suffix"
fi

if [ "$use_docker" ]; then
  DEBOS_CMD=docker
  ARGS="run --rm --interactive --tty --device /dev/kvm --workdir /recipes \
            --mount type=bind,source=$(pwd),destination=/recipes \
            --security-opt label=disable godebos/debos $ARGS"
fi

[ "$debug" ] && ARGS="$ARGS --debug-shell"
[ "$username" ] && ARGS="$ARGS -t username:$username"
[ "$password" ] && ARGS="$ARGS -t password:$password"
[ "$ssh" ] && ARGS="$ARGS -t ssh:$ssh"
[ "$environment" ] && ARGS="$ARGS -t environment:$environment"
[ "$hostname" ] && ARGS="$ARGS -t hostname:$hostname"
[ "$http_proxy" ] && ARGS="$ARGS -e http_proxy:$http_proxy"
[ "$ftp_proxy" ] && ARGS="$ARGS -e ftp_proxy:$ftp_proxy"
[ "$memory" ] && ARGS="$ARGS --memory $memory"
[ "$miniramfs" ] && ARGS="$ARGS -t miniramfs:true"
[ "$contrib" ] && ARGS="$ARGS -t contrib:true"
[ "$zram" ] && ARGS="$ARGS -t zram:true"

ARGS="$ARGS -t architecture:$arch -t family:$family -t device:$device \
            -t partitiontable:$partitiontable -t filesystem:$filesystem \
            -t environment:$environment -t image:$image_file_base -t rootfs:$rootfs_file \
            -t debian_suite:$debian_suite -t suite:$suite --scratchsize=8G \
            -t installfs:$installfs_file -t rootfs_device:$rootfs_device_base -t do_compress:$do_compress"

if [ ! "$image_only" -o ! -f "$rootfs_file" ]; then
  $DEBOS_CMD $ARGS rootfs.yaml || exit 1
  if [ "$installer" ]; then
    $DEBOS_CMD $ARGS installfs.yaml || exit 1
  fi
fi

if [ ! "$image_only" -o ! -f "$rootfs_device_file" ]; then
  $DEBOS_CMD $ARGS rootfs-device.yaml || exit 1
fi

rootfs_device_sqfs="$rootfs_device_base.sqfs"
# Convert rootfs tarball to squashfs for inclusion in the installer image
if [ "$installer" -a ! -f "$rootfs_device_sqfs" ]; then
  zcat "$rootfs_device_file" | tar2sqfs "$rootfs_device_sqfs"
fi

$DEBOS_CMD $ARGS "$image.yaml"

if [ ! "$no_blockmap" -a -f "$image_file_base.img" ]; then
  bmaptool create "$image_file_base.img" > "$image_file_base.img.bmap"
fi

if [ "$do_compress" ]; then
  echo "Compressing ${image_file_base}.img ..."
  [ -f ${image_file_base}.img ] && gzip --keep --force ${image_file_base}.img
  # for sdm845 ...
  [ -f ${image_file_base}.root.img ] && tar czf ${image_file_base}.tar.gz ${image_file_base}.boot-*.img ${image_file_base}.root.img
fi

if [ -n "$sign" ]; then
    truncate -s0 ${image_file_base}.sha256sums
    if [ "$do_compress" ]; then
        extensions="img.gz tar.gz img.bmap"
    else
        extensions="img boot-*.img root.img img.bmap"
    fi

    for ext in ${extensions}; do
        for file in $(ls ${image_file_base}.${ext} 2>/dev/null); do
            sha256sum ${file} >> ${image_file_base}.sha256sums
        done
    done

    [ -f ${image_file_base}.sha256sums.asc ] && rm ${image_file_base}.sha256sums.asc
    gpg -u ${sign} --clearsign ${image_file_base}.sha256sums
fi
