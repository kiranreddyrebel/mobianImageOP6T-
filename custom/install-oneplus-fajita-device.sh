#!/usr/bin/env bash
# install-oneplus-fajita-device.sh
# Debian port of the postmarketOS device-oneplus-fajita APKBUILD (OnePlus 6T).
# Run AFTER install-oneplus-sdm845-firmware.sh.
set -uo pipefail

DEVICE="device-oneplus-fajita"
BRANCH="master"
BASE="https://gitlab.com/postmarketOS/pmaports/-/raw/${BRANCH}/device"
DIRS=(community testing main)

if [ "$(id -u)" -ne 0 ]; then
	exec sudo -E bash "$0" "$@"
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

# --- 1. Dependencies available in Debian
echo "==> Installing Debian dependencies"
apt-get update
apt-get install -y curl git meson ninja-build build-essential pkg-config \
	alsa-ucm-conf udev systemd
# Optional Qualcomm helpers: packaged in newer Debian only, so install one by one
for p in qrtr-tools rmtfs pd-mapper tqftpserv libqrtr-dev libgbm-dev; do
	apt-get install -y "$p" 2>/dev/null || echo "    (skipped: $p not in your Debian release)"
done

# --- 2. Download device files from pmaports
echo "==> Downloading device files from pmaports"
fetch() {
	local f=$1 d
	for d in "${DIRS[@]}"; do
		if curl -fsSL "$BASE/$d/$DEVICE/$f" -o "$f"; then
			echo "    got $f ($d)"
			return 0
		fi
	done
	echo "    FAILED: $f (check the path in pmaports)" >&2
	return 1
}

FILES=(
	80-device-oneplus-fajita.preset
	81-libssc-oneplus-fajita.rules
	hexagonrpcd-sdsp.conf
	q6voiced.conf
	deviceinfo
)
for f in "${FILES[@]}"; do fetch "$f"; done

# --- 3. Install them to the same locations as the APKBUILD package()
echo "==> Installing config files"
inst() { [ -f "$1" ] && install -Dm644 "$1" -t "$2"; }
inst 81-libssc-oneplus-fajita.rules   /usr/lib/udev/rules.d/
inst q6voiced.conf                    /usr/share/q6voiced/
inst hexagonrpcd-sdsp.conf            /usr/share/hexagonrpcd/
inst 80-device-oneplus-fajita.preset  /usr/lib/systemd/system-preset/
inst deviceinfo                       /usr/share/"$DEVICE"/   # reference copy only

udevadm control --reload-rules && udevadm trigger || true

# --- 4. Build tools that have no Debian package
build_meson() {   # name, git url
	local name=$1 url=$2
	if command -v "$name" >/dev/null; then
		echo "    $name already installed"; return
	fi
	echo "==> Building $name"
	if git clone --depth 1 "$url" "src-$name" \
	   && meson setup "src-$name/build" "src-$name" --prefix=/usr \
	   && ninja -C "src-$name/build" \
	   && ninja -C "src-$name/build" install; then
		echo "    $name installed"
	else
		echo "    WARNING: building $name failed, install it manually" >&2
	fi
}
build_meson hexagonrpcd https://github.com/linux-msm/hexagonrpcd.git   # sensors via DSP
build_meson qbootctl    https://github.com/linux-msm/qbootctl.git       # A/B slot control

# --- 5. Enable services listed in the preset (only if the unit exists)
if [ -f 80-device-oneplus-fajita.preset ]; then
	echo "==> Enabling services from the preset"
	systemctl daemon-reload
	while read -r action unit _; do
		[ "$action" = "enable" ] || continue
		if systemctl list-unit-files "$unit" 2>/dev/null | grep -q "$unit"; then
			systemctl enable "$unit" && echo "    enabled $unit"
		else
			echo "    skipped $unit (not installed on this system)"
		fi
	done < 80-device-oneplus-fajita.preset
fi

if command -v update-initramfs >/dev/null; then
	update-initramfs -u -k all
fi

cat <<'EOF'

Done. Not covered by this script (no Debian equivalent):
  - Kernel: linux-postmarketos-qcom-sdm845 (you need an SDM845 mainline kernel)
  - Audio profiles: alsa-ucm-conf-sdm845 (generic alsa-ucm-conf was installed instead)
  - Boot image creation (mkbootimg/systemd-boot setup) and unl0kr
Reboot when ready.
EOF
