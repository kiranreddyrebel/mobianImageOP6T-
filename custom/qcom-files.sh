
#!/usr/bin/env bash
set -eu

SRC=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

copy_file() {
    source_file="$SRC/$1"
    destination="$2"
    mode="$3"

    if [ ! -f "$source_file" ]; then
        echo "ERROR: Missing source file: $source_file" >&2
        exit 1
    fi

    sudo install -D -m "$mode" "$source_file" "$destination"
    echo "Installed: $destination"
}

echo "Installing Qualcomm configuration files..."

copy_file UPower.conf \
    /etc/UPower/UPower.conf.d/50-soc-qcom.conf 644

copy_file 51-qcom.conf \
    /usr/share/wireplumber/wireplumber.conf.d/51-qcom.conf 644

copy_file gstreamer.conf \
    /etc/environment.d/50-soc-qcom-gstreamer.conf 644

copy_file call_audio_idle_suspend_workaround.sh \
    /sbin/call_audio_idle_suspend_workaround.sh 755

copy_file call_audio_idle_suspend_workaround.service \
    /usr/lib/systemd/user/call_audio_idle_suspend_workaround.service 644

echo
echo "Reloading user systemd units..."
for service in \
    call_audio_idle_suspend_workaround.service \
    q6voiced \
    81voltd \
    qbootctl \
    touch-autobind.service
do
    if systemctl --global enable "$service"; then
        echo "SUCCESS: Enabled $service"
    else
        echo "WARNING: Failed to enable $service; continuing..." >&2
    fi
done
