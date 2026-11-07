#!/usr/bin/env bash
# install-oneplus-sdm845-firmware.sh
# Fully automatic Debian installer for OnePlus 6 / 6T (SDM845) firmware.
set -euo pipefail

NAME="firmware-oneplus-sdm845"
COMMIT="3e31a0c3e5a061645c09f805387b49fa9d35acbf"
URL="https://gitlab.com/sdm845-mainline/${NAME}/-/archive/${COMMIT}/${NAME}-${COMMIT}.tar.gz"
SHA512="56604c46ad0f30f1f715af4b83bd2686d96723024063c7ef6baa5c73cd52b375478e3d65b886ff08efc95ce129fc789b8509efcdf9f0d46cf7229f4ec1afa513"

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
PATCH="$SCRIPT_DIR/0001-oneplus6-set-mount-matrix.patch"   # optional

# Re-run as root automatically
if [ "$(id -u)" -ne 0 ]; then
	exec sudo -E bash "$0" "$@"
fi

echo "==> Installing dependencies"
apt-get update
apt-get install -y curl tar patch firmware-atheros firmware-qcom-soc \
	|| echo "WARNING: could not install firmware-atheros/firmware-qcom-soc (enable non-free-firmware in apt sources)"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

echo "==> Downloading firmware"
curl -fL --retry 3 -o src.tar.gz "$URL"

echo "==> Verifying checksum"
echo "$SHA512  src.tar.gz" | sha512sum -c -

echo "==> Extracting"
tar xzf src.tar.gz
cd "${NAME}-${COMMIT}"

if [ -f "$PATCH" ]; then
	echo "==> Applying $(basename "$PATCH")"
	patch -p1 < "$PATCH"
else
	echo "==> No mount-matrix patch next to the script, skipping (optional)"
fi

echo "==> Installing firmware to /usr/lib/firmware"
if [ -d lib/firmware ]; then
	find lib/firmware -type f -print0 | while IFS= read -r -d '' f; do
		install -Dm644 "$f" "/usr/$f"
	done
else
	echo "ERROR: lib/firmware not found in the tarball, upstream layout changed" >&2
	exit 1
fi

if [ -d usr/share/qcom ]; then
	echo "==> Installing sensor/Qualcomm config to /usr/share/qcom"
	find usr/share/qcom -type f -print0 | while IFS= read -r -d '' f; do
		install -Dm644 "$f" "/$f"
	done
	OP="/usr/share/qcom/sdm845/OnePlus"
	if [ -d "$OP/oneplus6" ]; then
		ln -sfn oneplus6 "$OP/enchilada"   # OnePlus 6
		ln -sfn oneplus6 "$OP/fajita"      # OnePlus 6T
	fi
fi

if command -v update-initramfs >/dev/null; then
	echo "==> Updating initramfs"
	update-initramfs -u -k all
fi

echo "Done. Reboot to use the new firmware."
