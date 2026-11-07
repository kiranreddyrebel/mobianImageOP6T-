#!/usr/bin/env bash
# Noninteractive root installer for a Mobian/Debian image build.
# Builds qmic and 81voltd, installs them, and skips runtime-only sysfs prompts.
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
export PATH="/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

QMIC_REPO="https://github.com/linux-msm/qmic.git"
VOLTD_REPO="https://gitlab.postmarketos.org/modem/81voltd.git"
SRC_DIR="/usr/local/src/mobian-volte-stack"
QMIC_DIR="${SRC_DIR}/qmic"
VOLTD_DIR="${SRC_DIR}/81voltd"
BUILD_DIR="${VOLTD_DIR}/build"

log()  { printf '\n==> %s\n' "$*"; }
warn() { printf '\nWARNING: %s\n' "$*" >&2; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

if [[ "$(id -u)" -ne 0 ]]; then
  die "Run this direct-install version as root."
fi
command -v apt-get >/dev/null 2>&1 || die "This script requires Debian/Mobian with apt-get."
command -v git >/dev/null 2>&1 || true

log "Step 1/6: Install build dependencies"
apt-get update
apt-get install -y --no-install-recommends \
  git ca-certificates build-essential make meson ninja-build pkg-config \
  python3 libmm-glib-dev libqmi-glib-dev libqrtr-glib-dev \
  libqrtr-dev cmake libglib2.0-dev

install -d -m 0755 "$SRC_DIR"

log "Step 2/6: Fetch qmic"
if [[ -d "${QMIC_DIR}/.git" ]]; then
  git -C "$QMIC_DIR" remote set-url origin "$QMIC_REPO"
  if [[ -z "$(git -C "$QMIC_DIR" status --porcelain)" ]]; then
    git -C "$QMIC_DIR" pull --ff-only
  else
    warn "Local changes in ${QMIC_DIR}; preserving the existing checkout."
  fi
elif [[ -e "$QMIC_DIR" ]]; then
  die "${QMIC_DIR} exists but is not a Git checkout; remove or rename it before retrying."
else
  git clone --depth 1 "$QMIC_REPO" "$QMIC_DIR"
fi

log "Step 3/6: Build and install qmic"
make -C "$QMIC_DIR"
[[ -x "${QMIC_DIR}/qmic" ]] || die "qmic build did not produce ${QMIC_DIR}/qmic"
make -C "$QMIC_DIR" prefix=/usr/local install
[[ -x /usr/local/bin/qmic ]] || die "qmic was not installed to /usr/local/bin/qmic"

log "Step 4/6: Fetch 81voltd"
if [[ -d "${VOLTD_DIR}/.git" ]]; then
  git -C "$VOLTD_DIR" remote set-url origin "$VOLTD_REPO"
  if [[ -z "$(git -C "$VOLTD_DIR" status --porcelain)" ]]; then
    git -C "$VOLTD_DIR" pull --ff-only
  else
    warn "Local changes in ${VOLTD_DIR}; preserving the existing checkout."
  fi
elif [[ -e "$VOLTD_DIR" ]]; then
  die "${VOLTD_DIR} exists but is not a Git checkout; remove or rename it before retrying."
else
  git clone --depth 1 "$VOLTD_REPO" "$VOLTD_DIR"
fi

log "Step 5/6: Apply stdbool fix if needed"
python3 - "$VOLTD_DIR" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
for name in ("qvd-modem.c", "qvd-message.c"):
    path = root / name
    if not path.is_file():
        continue
    text = path.read_text()
    if "true" in text and "#include <stdbool.h>" not in text:
        path.write_text("#include <stdbool.h>\n" + text)
        print(f"Added <stdbool.h> to {name}")
PY

log "Step 6/6: Configure, build, and install 81voltd"
if [[ -d "$BUILD_DIR" ]]; then
  meson setup --reconfigure "$BUILD_DIR" "$VOLTD_DIR"
else
  meson setup "$BUILD_DIR" "$VOLTD_DIR"
fi
meson compile -C "$BUILD_DIR"
meson install -C "$BUILD_DIR"

log "Install optional support packages when available"
if apt-cache show qcom-phone-utils >/dev/null 2>&1; then
  apt-get install -y --no-install-recommends qcom-phone-utils
else
  warn "qcom-phone-utils is unavailable from configured APT repositories; skipped."
fi
if apt-cache show sysfsutils >/dev/null 2>&1; then
  apt-get install -y --no-install-recommends sysfsutils
else
  warn "sysfsutils is unavailable from configured APT repositories; skipped."
fi

# Image builds/chroots usually do not have the phone's live /sys tree.
# Do not prompt or try to write to runtime sysfs here.
if [[ -e /sys/bus/rpmsg/devices/4080000.remoteproc:glink-edge.IPCRTR.-1.-1/power/wakeup ]]; then
  log "Modem wakeup sysfs path exists; leaving runtime wakeup state unchanged."
else
  warn "Runtime modem wakeup sysfs path is absent (normal during image builds); skipped."
fi

log "Verification"
printf 'qmic: '; command -v qmic || true
printf '81voltd: '; command -v 81voltd || true
[[ ! -e "$BUILD_DIR/81voltd" ]] || ls -l "$BUILD_DIR/81voltd"
printf '\nBuild/install phase completed. This does not configure IMS/VoLTE or enable a service automatically.\n'
