#!/bin/sh

DEVICE=$1
IMAGE=$2

[ "$IMAGE" ] || exit 1

case "${DEVICE}" in
    "a5ulte")
        VARIANTS="a5u-eur-modem"
        ;;
    "gt58lte")
        VARIANTS="gt58lte-modem"
        ;;
    *)
        echo "ERROR: unsupported device ${DEVICE}"
        exit 1
        ;;
esac

# On an Android device, we can't simply flash a full bootable image: we can only
# flash one partition at a time using fastboot.

# Extract rootfs partition
PART_OFFSET=`/sbin/fdisk -lu $IMAGE.img | tail -1 | awk '{ print $2; }'` &&
echo "Extracting rootfs @ $PART_OFFSET"
dd if=$IMAGE.img of=$IMAGE.root.img bs=512 skip=$PART_OFFSET

# Filesystem images need to be converted to Android sparse images first
echo "Converting rootfs to sparse image"
img2simg $IMAGE.root.img $IMAGE.root.simg && mv $IMAGE.root.simg $IMAGE.root.img

# Extract bootimg (already an Android-specific format, no need to convert it)
BOOT_OFFSET=`/sbin/fdisk -lu $IMAGE.img | grep "\.img1" | awk '{ print $3; }'` &&

for variant in ${VARIANTS}; do
    echo "Extracting boot @ $BOOT_OFFSET for variant ${variant}"
    # Extract only 64M (131072 x 512b) of the bootimg as larger ones wouldn't fit
    dd if=$IMAGE.img of=$IMAGE.boot-${variant}.img bs=512 skip=$BOOT_OFFSET count=131072
    # Next bootimg is right after the current one
    BOOT_OFFSET=$(expr ${BOOT_OFFSET} + 131072)
done

# Ditch the old image, we don't need it anymore
rm $IMAGE.img
