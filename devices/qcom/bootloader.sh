#!/bin/sh

SCRIPT="$0"
DEVICE="$1"

CONFIG="$(dirname ${SCRIPT})/configs/${DEVICE}.toml"
if ! [ -f "${CONFIG}" ]; then
    echo "ERROR: No configuration for device type '${DEVICE}'!"
    exit 1
fi

bootimg_offsets() {
    local BOOTIMG="$1"

    local BASE="$(echo "${BOOTIMG}" | jq -r 'if .base then .base else 0 end' -)"
    # Export addresses as offsets, we'll add base address later
    local KERNEL="$(echo "${BOOTIMG}" | jq -r '.kernel' -)"
    local RAMDISK="$(echo "${BOOTIMG}" | jq -r '.ramdisk' -)"
    local SECOND="$(echo "${BOOTIMG}" | jq -r '.second' -)"
    local TAGS="$(echo "${BOOTIMG}" | jq -r '.tags' -)"
    local DTB="$(echo "${BOOTIMG}" | jq -r 'if .dtb then .dtb else "" end' -)"
    local VERSION="$(echo "${BOOTIMG}" | jq -r 'if .version then .version else 0 end' -)"
    local PAGE_SIZE="$(echo "${BOOTIMG}" | jq -r '.pagesize' -)"

    local ARGS="--base ${BASE}"

    if [ "${KERNEL}" != "null" ]; then
        KERNEL=$((BASE+KERNEL))
        ARGS="${ARGS} --kernel_offset ${KERNEL}"
    fi

    if [ "${RAMDISK}" != "null" ]; then
        RAMDISK=$((BASE+RAMDISK))
        ARGS="${ARGS} --ramdisk_offset ${RAMDISK}"
    fi

    if [ "${SECOND}" != "null" ]; then
        SECOND=$((BASE+SECOND))
        ARGS="${ARGS} --second_offset ${SECOND}"
    fi

    if [ "${TAGS}" != "null" ]; then
        TAGS=$((BASE+TAGS))
        ARGS="${ARGS} --tags_offset ${TAGS}"
    fi

    if [ "${PAGE_SIZE}" != "null" ]; then
        ARGS="${ARGS} --pagesize ${PAGE_SIZE}"
    fi

    if [ "${VERSION}" != "null" ] && [ "${VERSION}" != "0" ]; then
        ARGS="${ARGS} --header_version ${VERSION}"
    fi

    if [ -n "${DTB}" ] && [ "${DTB}" != "null" ]; then
        ARGS="${ARGS} --dtb_offset ${DTB}"
    fi

    echo "${ARGS}"
}

ROOTPART="UUID=$(findmnt -n -o UUID /)"
if [ "${ROOTPART}" = "UUID=" ]; then
    # This means we're using an encrypted rootfs
    ROOTPART="/dev/mapper/root"
fi
KERNEL_VERSION=$(linux-version list | tail -1)

# Parse config for generic parameters for the current SoC
SOC=$(tomlq -r "if .chipset then .chipset else \"${DEVICE}\" end" ${CONFIG})
MKBOOTIMG_ARGS="$(bootimg_offsets "$(tomlq -r '.bootimg' ${CONFIG})")"

for i in $(seq 0 $(tomlq -r '.device | length - 1' ${CONFIG})); do
    # Parse device-specific parameters
    VENDOR=$(tomlq -r ".device[$i].vendor" ${CONFIG})
    MODEL=$(tomlq -r ".device[$i].model" ${CONFIG})
    VARIANT=$(tomlq -r "if .device[$i].variant then .device[$i].variant else \"\" end" ${CONFIG})
    DEVICE_SOC=$(tomlq -r "if .device[$i].chipset then .device[$i].chipset else \"${SOC}\" end" ${CONFIG})
    APPEND=$(tomlq -r "if .device[$i].append then .device[$i].append else \"\" end" ${CONFIG})
    # Extract device-specific bootimg parameters in JSON format for processing by `bootimg_offsets()`
    DEVICE_BOOTIMG=$(tomlq -r "if .device[$i].bootimg then .device[$i].bootimg else \"\" end" ${CONFIG})

    CMDLINE="mobile.qcomsoc=qcom/${DEVICE_SOC} mobile.vendor=${VENDOR} mobile.model=${MODEL}"
    if [ "${VARIANT}" ]; then
        CMDLINE="${CMDLINE} mobile.variant=${VARIANT}"
        FULLMODEL="${MODEL}-${VARIANT}"
    else
        FULLMODEL="${MODEL}"
    fi
    DTB_FILE="/usr/lib/linux-image-${KERNEL_VERSION}/qcom/${DEVICE_SOC}-${VENDOR}-${FULLMODEL}.dtb"

    LOGLEVEL="quiet"
    # Include additional cmdline args if specified
    if [ "${APPEND}" ]; then
        CMDLINE="${CMDLINE} ${APPEND}"
        if echo "${APPEND}" | grep -q "console="; then
            LOGLEVEL="loglevel=7"
        fi
    fi

    # if there are device-specific parameters (DEVICE_BOOTIMG has length >0), parse those,
    # otherwise keep the SoC-default values
    if [ -n "${DEVICE_BOOTIMG}" ]; then
        BOOTIMG_ARGS="$(bootimg_offsets "${DEVICE_BOOTIMG}")"

        # make sure we have a complete set of parameters, starting from device-specific and adding SoC-default that haven't been overwritten
        # we assume BASE does not need to be re-populated:
        # - BASE is forced to be populated in bootimg_offsets(), and defaults to 0 when not specified

        # additionally, VERSION is assumed to be 0 in this file unless otherwise specified, then we just have to take care of the case when
        # there's no device-specific VERSION specified, but there is a SoC-default value !=0
        if ! echo "${BOOTIMG_ARGS}" | sed 's/ --/\n--/g' | grep -q "kernel_offset"; then
            BOOTIMG_ARGS="${BOOTIMG_ARGS} $(echo "${MKBOOTIMG_ARGS}" | sed 's/ --/\n--/g' | grep "kernel_offset")"
        fi

        if ! echo "${BOOTIMG_ARGS}" | sed 's/ --/\n--/g' | grep -q "ramdisk_offset"; then
            BOOTIMG_ARGS="${BOOTIMG_ARGS} $(echo "${MKBOOTIMG_ARGS}" | sed 's/ --/\n--/g' | grep "ramdisk_offset")"
        fi

        if ! echo "${BOOTIMG_ARGS}" | sed 's/ --/\n--/g' | grep -q "second_offset"; then
            BOOTIMG_ARGS="${BOOTIMG_ARGS} $(echo "${MKBOOTIMG_ARGS}" | sed 's/ --/\n--/g' | grep "second_offset")"
        fi

        if ! echo "${BOOTIMG_ARGS}" | sed 's/ --/\n--/g' | grep -q "tags_offset"; then
            BOOTIMG_ARGS="${BOOTIMG_ARGS} $(echo "${MKBOOTIMG_ARGS}" | sed 's/ --/\n--/g' | grep "tags_offset")"
        fi

        if ! echo "${BOOTIMG_ARGS}" | sed 's/ --/\n--/g' | grep -q "header_version"; then
            SOC_BOOTIMG_HEADER_VERSION="$(echo "${MKBOOTIMG_ARGS}" | sed 's/ --/\n--/g' | grep "header_version" | cut -f2 -d ' ')"
            if [ ${SOC_BOOTIMG_HEADER_VERSION} != "null" ]; then
                if [ ${SOC_BOOTIMG_HEADER_VERSION} != "0" ]; then
                    BOOTIMG_ARGS="${BOOTIMG_ARGS} ${SOC_BOOTIMG_HEADER_VERSION}"
                fi
            fi
        fi

        if ! echo "${BOOTIMG_ARGS}" | sed 's/ --/\n--/g' | grep -q "dtb_offset"; then
            BOOTIMG_ARGS="${BOOTIMG_ARGS} $(echo "${MKBOOTIMG_ARGS}" | sed 's/ --/\n--/g' | grep "dtb_offset")"
        fi

    else
        BOOTIMG_ARGS="${MKBOOTIMG_ARGS}"
    fi

    if echo "${BOOTIMG_ARGS}" | grep -q "dtb_offset"; then
        BOOTIMG_ARGS="${BOOTIMG_ARGS} --dtb ${DTB_FILE}"
    fi

    echo "Creating boot image for ${FULLMODEL}..."
    cat /boot/vmlinuz-${KERNEL_VERSION} ${DTB_FILE} > /tmp/kernel-dtb

    # Create the bootimg as it's the only format recognized by the Android bootloader
    mkbootimg -o /bootimg-${FULLMODEL} ${BOOTIMG_ARGS} \
        --kernel /tmp/kernel-dtb --ramdisk /boot/initrd.img-${KERNEL_VERSION} \
        --cmdline "mobile.root=${ROOTPART} ${CMDLINE} init=/sbin/init ro ${LOGLEVEL} splash"
done
