#!/bin/sh

set -e

# Sync DTBs to /boot so they're available to u-boot and update boot menu
KERNEL_VERSION=$(linux-version list)
for version in ${KERNEL_VERSION}; do
    /etc/kernel/postinst.d/zz-u-boot-menu "${version}"
done
