#!/bin/sh

DEVICE="$1"
DTB_VENDOR="oneplus"
DTB_DEVICE="enchilada"

ROOTPART=$(grep f2fs /etc/fstab | awk '{ print $1; }')
BOOTDEV=$(lsblk -o PATH,MOUNTPOINT -n | grep /boot | awk '{ print $1; }')
KERNEL_VERSION=$(linux-version list)

case "${DEVICE}" in
    "oneplus6t")
        DTB_DEVICE="fajita"
        ;;
    "pocof1")
        DTB_VENDOR="xiaomi"
        DTB_DEVICE="beryllium"
        ;;
esac

# Append DTB to kernel
cat /boot/vmlinuz-${KERNEL_VERSION} /usr/lib/linux-image-${KERNEL_VERSION}/qcom/sdm845-${DTB_VENDOR}-${DTB_DEVICE}.dtb > /tmp/kernel-dtb

# Create the bootimg as it's the only format recognized by the Android bootloader
mkbootimg --kernel /tmp/kernel-dtb --ramdisk /boot/initrd.img-${KERNEL_VERSION} \
    --kernel_offset 0x8000 --ramdisk_offset 0x1000000 --tags_offset 0x100 \
    --pagesize 4096 --cmdline "mobian.root=${ROOTPART} init=/sbin/init rw quiet splash" \
    --base 0x0 --second_offset 0x0 -o /tmp/bootimg

# HACK: Overwrite the /boot partition with the created bootimg so we can extract
# it later (we don't need the contents of /boot anyway, the bootimg contains all
# required data: kernel, DTB and initrd)
umount /boot
sed -i '/\/boot/d' /etc/fstab
dd if=/tmp/bootimg of=${BOOTDEV} bs=1M
