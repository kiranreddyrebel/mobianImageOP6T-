#!/bin/sh

# Remove temporary dummy bootsector and u-boot binary
rm -f /tmp/bootsector.bin \
      /u-boot-sunxi-with-spl.bin \
      /librem5-boot.img \
      /tmp/kernel-dtb /tmp/bootimg
