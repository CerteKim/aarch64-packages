#!/bin/bash
# Switch the Xiaomi Book S 12.4 DTB between the single-link and dual-link
# panel variants.  The kernel is the same for both; only the device tree
# differs.  Run as root.
#
#   sudo ./set-panel-link-mode.sh single
#   sudo ./set-panel-link-mode.sh dual
#   sudo ./set-panel-link-mode.sh --status
#
# These prebuilt panel DTBs only go to the stock path: the "-oc" name is the
# overclocked GPU device tree built from sc8180x-xiaomi-book-12.4-oc.dts, and
# is installed by tools/refresh-boot-from-tree.sh rather than overwritten here.
# Note also that panel-dtb/*.dtb are snapshots from before the power-key,
# volume-key and backlight work, so a build from the source tree is preferable.
set -euo pipefail

REPO="/home/certe/aarch64-packages/linux-surface"
DTBDIR="$REPO/panel-dtb"
BOOT_DTB_DIR="/boot/dtb/linux-mibook/qcom"
TARGET="sc8180x-xiaomi-book-12.4.dtb"
OC_TARGET="sc8180x-xiaomi-book-12.4-oc.dtb"

status() {
    echo "installed DTB:"
    md5sum "$BOOT_DTB_DIR/$TARGET" "$BOOT_DTB_DIR/$OC_TARGET" 2>/dev/null || true
    echo
    echo "candidates:"
    md5sum "$DTBDIR"/*.dtb 2>/dev/null || true
}

case "${1:---status}" in
--status)
    status
    ;;
single)
    src="$DTBDIR/sc8180x-xiaomi-book-12.4.single-link.dtb"
    install -Dm644 "$src" "$BOOT_DTB_DIR/$TARGET"
    echo "installed single-link DTB"
    status
    ;;
dual)
    src="$DTBDIR/sc8180x-xiaomi-book-12.4.dual-link.dtb"
    install -Dm644 "$src" "$BOOT_DTB_DIR/$TARGET"
    echo "installed dual-link DTB"
    status
    ;;
*)
    echo "usage: $0 {single|dual|--status}" >&2
    exit 1
    ;;
esac
