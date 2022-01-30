#!/bin/sh

usage() {
    echo "usage: $0 [options]"
    echo "  -d               use Docker to execute debos"
    echo "  -D               debug mode; output additional diagnostic information"
    echo "  -e environment   specify the Mobian graphical shell/environment (phosh)"
    echo "  -H hostname      specify the system hostname (default: mobian)"
    echo "  -i               skip creating, re-use existing, rootfs and installfs if possible"
    echo "  -z               compress the built image"
    echo "  -b               skip block map (bmap) creation"
    echo "  -s               install and configure openssh-server package in image"
    echo "  -o               produce an installer image, rather than a system image"
    echo "  -Z               configure /tmp and /var/tmp as ZRAM-backed EXT FS"
    echo "  -f ftp_proxy     specify the build environment ftp_proxy variable"
    echo "  -h http_proxy    specify the build environment http_proxy variable"
    echo "  -g sign          sign the generated image sha256sums with the specified GPG key-name"
    echo "  -m memory        specify the amount of memory for debos build VM"
    echo "  -X scratchsize   specify the scratchsize for debos build VM"
    echo "  -p password      specify the password configured for the user in the built image (default: 1234)"
    echo "  -t device        specify the Mobian device to build for (default: pinephone)"
    echo "  -u username      specify the username for the user in the built image (default: mobian)"
    echo "  -F filesystem    specify the filesystem to use in the built image (default: ext4)"
    echo "  -x debian_suite  specify the Debian suite to build the image with (default: bookworm)"
    echo "  -S suite         specify the Mobian suite to build the image with (default: bookworm)"
    echo "  -C               enable the contrib repository in the built image"
    echo "  -r               create miniramfs"
    echo "NOTE: ARGS environment variable is respected and may be used to command debos directly"
    echo "NOTE: specifying a device may override other specified options without warning"
    exit 0
}

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
scratchsize="8G"
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

while getopts "dDizobsZCrx:S:e:H:f:g:h:m:X:p:t:u:F:" opt
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
    X ) scratchsize="$OPTARG" ;;
    p ) password="$OPTARG" ;;
    t ) device="$OPTARG" ;;
    u ) username="$OPTARG" ;;
    F ) filesystem="$OPTARG" ;;
    x ) debian_suite="$OPTARG" ;;
    S ) suite="$OPTARG" ;;
    C ) contrib=1 ;;
    r ) miniramfs=1 ;;
    * ) usage && exit 1
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
    suite="unstable"
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
    suite="unstable"
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

installfs_file="installfs-$arch.tar.gz"

image_file="mobian-$device-$environment-`date +%Y%m%d`"
if [ "$installer" ]; then
  image="installer"
  image_file="mobian-installer-$device-$environment-`date +%Y%m%d`"
fi

rootfs_file="rootfs-$arch-$environment.tar.gz"
if echo $ARGS | grep -q "nonfree:true"; then
  rootfs_file="rootfs-$arch-$environment-nonfree.tar.gz"
fi

if [ "$use_docker" ]; then
  DEBOS_CMD=docker
  ARGS="run --rm --interactive --tty --device /dev/kvm --workdir /recipes \
            --mount type=bind,source=$(pwd),destination=/recipes \
            --security-opt label=disable godebos/debos $ARGS"
fi

[ "$debug"       ] && ARGS="$ARGS --debug-shell"
[ "$memory"      ] && ARGS="$ARGS --memory $memory"
[ "$scratchsize" ] && ARGS="$ARGS --scratchsize=$scratchsize"
[ "$http_proxy"  ] && ARGS="$ARGS -e  http_proxy:$http_proxy"
[ "$ftp_proxy"   ] && ARGS="$ARGS -e   ftp_proxy:$ftp_proxy"
[ "$username"    ] && ARGS="$ARGS -t    username:$username"
[ "$password"    ] && ARGS="$ARGS -t    password:$password"
[ "$ssh"         ] && ARGS="$ARGS -t         ssh:$ssh"
[ "$environment" ] && ARGS="$ARGS -t environment:$environment"
[ "$hostname"    ] && ARGS="$ARGS -t    hostname:$hostname"
[ "$miniramfs"   ] && ARGS="$ARGS -t   miniramfs:true"
[ "$contrib"     ] && ARGS="$ARGS -t     contrib:true"
[ "$zram"        ] && ARGS="$ARGS -t        zram:true"

ARGS="$ARGS \
-t   architecture:$arch \
-t         family:$family \
-t         device:$device \
-t partitiontable:$partitiontable \
-t     filesystem:$filesystem  \
-t   debian_suite:$debian_suite \
-t          suite:$suite \
-t          image:$image_file \
-t         rootfs:$rootfs_file \
-t      installfs:$installfs_file"

if [ ! "$image_only" -o ! -f "$rootfs_file" ]; then
  $DEBOS_CMD $ARGS rootfs.yaml || exit 1
  if [ "$installer" ]; then
    $DEBOS_CMD $ARGS installfs.yaml || exit 1
  fi
fi

if [ ! "$image_only" -o ! -f "rootfs-$device-$environment.tar.gz" ]; then
  $DEBOS_CMD $ARGS "rootfs-device.yaml" || exit 1
fi

# Convert rootfs tarball to squashfs for inclusion in the installer image
if [ "$installer" -a ! -f "rootfs-$device-$environment.sqfs" ]; then
  zcat "rootfs-$device-$environment.tar.gz" | tar2sqfs "rootfs-$device-$environment.sqfs"
fi

$DEBOS_CMD $ARGS "$image.yaml"

if [ ! "$no_blockmap" -a -f "$image_file.img" ]; then
  bmaptool create "$image_file.img" > "$image_file.img.bmap"
fi

if [ "$do_compress" ]; then
  echo "Compressing ${image_file}..."
  [ -f ${image_file}.img ] && gzip --keep --force ${image_file}.img
  [ -f ${image_file}.root.img ] && tar czf ${image_file}.tar.gz ${image_file}.boot-*.img ${image_file}.root.img
fi

if [ -n "$sign" ]; then
    truncate -s0 ${image_file}.sha256sums
    if [ "$do_compress" ]; then
        extensions="img.gz tar.gz img.bmap"
    else
        extensions="img boot-*.img root.img img.bmap"
    fi

    for ext in ${extensions}; do
        for file in $(ls ${image_file}.${ext} 2>/dev/null); do
            sha256sum ${file} >> ${image_file}.sha256sums
        done
    done

    [ -f ${image_file}.sha256sums.asc ] && rm ${image_file}.sha256sums.asc
    gpg -u ${sign} --clearsign ${image_file}.sha256sums
fi
