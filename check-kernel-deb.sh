#!/bin/sh
# Verify a bindeb-pkg linux-image .deb has what devices/qcom/bootloader.sh needs.
# Usage: ./check-kernel-deb.sh linux-image-7.2.0-sdm845_*.deb
D="$1"; [ -f "$D" ] || { echo "usage: $0 linux-image-<ver>.deb"; exit 1; }
case "$D" in *-dbg_*) echo "[FAIL] this is the -dbg package, use the plain linux-image one"; exit 1;; esac
L=$(mktemp); dpkg-deb -c "$D" | awk '{print $NF}' > "$L"
V=$(dpkg-deb -f "$D" Package | sed 's/^linux-image-//')
echo "kernel release: $V"
ok(){ echo "[ OK ] $*"; }; bad(){ echo "[FAIL] $*"; F=1; }
grep -q "boot/vmlinuz-$V\$" "$L" && ok "/boot/vmlinuz-$V" || bad "no /boot/vmlinuz-$V"
for d in enchilada fajita; do
  grep -q "usr/lib/linux-image-$V/qcom/sdm845-oneplus-$d.dtb\$" "$L" \
   && ok "DTB $d" || bad "missing /usr/lib/linux-image-$V/qcom/sdm845-oneplus-$d.dtb"
done
grep -q "lib/modules/$V/" "$L" && ok "modules" || bad "no /lib/modules/$V"
echo "depends: $(dpkg-deb -f "$D" Depends)"
rm -f "$L"; exit ${F:-0}
