#!/bin/sh

IMAGE=$1

[ "$IMAGE" ] || exit 1

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
BOOT_SIZE=`/sbin/fdisk -lu $IMAGE.img | grep "\.img1" | awk '{ print $5; }'` &&
echo "Extracting boot @ $BOOT_OFFSET"
dd if=$IMAGE.img of=$IMAGE.boot.img bs=512 skip=$BOOT_OFFSET count=$BOOT_SIZE

# The boot partition on oneplus6 & pocof1 is 67.1M, trimming to 64M will ensure
# our bootimg fits
truncate -s 64M $IMAGE.boot.img

# Ditch the old image, we don't need it anymore
rm $IMAGE.img
