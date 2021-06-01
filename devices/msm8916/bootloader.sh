#!/bin/sh

DEVICE="$1"
OFFSET=0

ROOTPART=$(grep f2fs /etc/fstab | awk '{ print $1; }')
BOOTDEV=$(lsblk -o PATH,MOUNTPOINT -n | grep /boot | awk '{ print $1; }')
KERNEL_VERSION=$(linux-version list)

# Update the initramfs to make sure it's up-to-date
update-initramfs -u -k all

case "${DEVICE}" in
    "a5ulte")
        DTB_VENDOR="samsung"
        DTB_VARIANTS="a5u-eur-modem"
        ;;
    "gt58lte")
        DTB_VENDOR="samsung"
        DTB_VARIANTS="gt58lte-modem"
        ;;
    *)
        echo "ERROR: unsupported device ${DEVICE}"
        exit 1
        ;;
esac

# HACK: Overwrite the /boot partition with the created bootimg so we can extract
# it later (we don't need the contents of /boot anyway, the bootimg contains all
# required data: kernel, DTB and initrd)
cp /boot/vmlinuz-${KERNEL_VERSION} /boot/initrd.img-${KERNEL_VERSION} /tmp/
umount /boot
sed -i '/\/boot/d' /etc/fstab

# Create a bootimg for each variant
for variant in ${DTB_VARIANTS}; do
    # Append DTB to kernel
    cat /tmp/vmlinuz-${KERNEL_VERSION} /usr/lib/linux-image-${KERNEL_VERSION}/qcom/msm8916-${DTB_VENDOR}-${variant}.dtb > /tmp/kernel-dtb

    # Create the bootimg as it's the only format recognized by the Android bootloader
    mkbootimg --kernel /tmp/kernel-dtb --ramdisk /tmp/initrd.img-${KERNEL_VERSION} \
        --kernel_offset 0x80000 --ramdisk_offset 0x2000000 --tags_offset 0x1e00000 \
        --pagesize 2048 --cmdline "mobian.root=${ROOTPART} mobian.variant=${variant} init=/sbin/init rw quiet splash" \
        --base 0x80000000 --second_offset 0xf00000 -o /tmp/bootimg

    dd if=/tmp/bootimg of=${BOOTDEV} bs=1M seek=${OFFSET}

    # Put the next bootimg 64MB after the current one
    OFFSET=$(expr ${OFFSET} + 64)
done
