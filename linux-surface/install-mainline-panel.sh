#!/bin/bash
# Install the mainline-derived HX83121A panel driver (dual-DSI port) for the
# Xiaomi Book S 12.4.
#
#   sudo ./install-mainline-panel.sh [KERNEL_BUILD_DIR] [FALLBACK_DIR]
#
# /boot is a 256M EFI partition with ~55M free, so the old and the new
# initramfs cannot both live there.  The previous kernel/DTBs are therefore
# saved on the root filesystem (FALLBACK_DIR), and the previous initramfs is
# regenerated from the still-present old modules if a rollback is needed
# (tools/restore-single-dsi-panel.sh does both).
set -euo pipefail

KSRC="${1:-/home/certe/aarch64-packages/linux-surface/src/kernel}"
FALLBACK="${2:-/home/certe/panel-fallback-single-dsi}"
# With --no-modules the installer only touches the kernel image, the DTBs and
# the initramfs, which is what you want after pacman -U installed the modules
# (installing them again would put them outside pacman's database).
INSTALL_MODULES=1
[ "${1:-}" = "--no-modules" ] && { INSTALL_MODULES=0; KSRC="/home/certe/aarch64-packages/linux-surface/src/kernel"; shift; }
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KVER="$(make -s -C "$KSRC" ARCH=arm64 kernelrelease)"
MODDIR="/usr/lib/modules/${KVER}"
BOOT_DTB_DIR="/boot/dtb/linux-mibook/qcom"
DTB="sc8180x-xiaomi-book-12.4.dtb"
NEW_INITRAMFS="/tmp/initramfs-linux-mibook.new.img"

echo "==> kernel release: ${KVER}"
[ -f "$KSRC/vmlinux" ] || { echo "!! no vmlinux in $KSRC - build first"; exit 1; }
[ -f "$KSRC/arch/arm64/boot/Image" ] || { echo "!! no Image built"; exit 1; }
[ -f "$KSRC/arch/arm64/boot/dts/qcom/${DTB}" ] || { echo "!! no DTB built"; exit 1; }

echo "==> saving previous kernel/DTBs to ${FALLBACK}"
mkdir -p "$FALLBACK"
for f in vmlinuz-linux-mibook; do
    [ -f "/boot/$f" ] || continue
    [ -f "$FALLBACK/$f.single-dsi" ] || cp -a "/boot/$f" "$FALLBACK/$f.single-dsi"
    echo "    saved $f"
done
for f in "$DTB" "sc8180x-xiaomi-book-12.4-oc.dtb"; do
    [ -f "$BOOT_DTB_DIR/$f" ] || continue
    [ -f "$FALLBACK/$f.single-dsi" ] || cp -a "$BOOT_DTB_DIR/$f" "$FALLBACK/$f.single-dsi"
    echo "    saved $f"
done

if [ "$INSTALL_MODULES" = 1 ]; then
    echo "==> installing kernel modules into ${MODDIR}"
    make -C "$KSRC" ARCH=arm64 INSTALL_MOD_PATH=/ INSTALL_MOD_STRIP=1 modules_install >/dev/null
else
    echo "==> skipping modules (--no-modules)"
fi

echo "==> installing kernel image"
install -Dm644 "$KSRC/arch/arm64/boot/Image" /boot/vmlinuz-linux-mibook
install -Dm644 "$KSRC/System.map" "${MODDIR}/System.map"
install -Dm644 "$KSRC/.config" "${MODDIR}/config"

echo "==> generating initramfs (to ${NEW_INITRAMFS})"
rm -f "$NEW_INITRAMFS"
mkinitcpio -k "$KVER" -g "$NEW_INITRAMFS"
[ -s "$NEW_INITRAMFS" ] || { echo "!! initramfs generation failed"; exit 1; }

echo "==> swapping initramfs into /boot"
rm -f /boot/initramfs-linux-mibook.img
mv "$NEW_INITRAMFS" /boot/initramfs-linux-mibook.img
chmod 644 /boot/initramfs-linux-mibook.img

echo "==> installing the DTB"
# The single-link variant is the one that renders correctly; use
# ./set-panel-link-mode.sh dual to switch the DTB afterwards.
#
# Only the stock path is written: sc8180x-xiaomi-book-12.4-oc.dtb is the
# overclocked GPU variant built by the kernel Makefile, not a copy of this
# one.  Install it with debug/refresh-boot-from-tree.sh.
install -Dm644 "$REPO/panel-dtb/sc8180x-xiaomi-book-12.4.single-link.dtb" \
    "$BOOT_DTB_DIR/${DTB}"

echo
echo "Done."
ls -la /boot/vmlinuz-linux-mibook /boot/initramfs-linux-mibook.img "$BOOT_DTB_DIR/"
df -h /boot | tail -1
echo
echo "Reboot and pick the 'Arch Linux' GRUB entry, then run debug/verify-mainline-panel.sh."
echo "To roll back: sudo ./tools/restore-single-dsi-panel.sh"
