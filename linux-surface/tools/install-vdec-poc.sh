#!/bin/bash
# Install the Venus video-decoder probe PoC: pacman package + boot refresh.
# Run as root.  Revert with tools/restore-pre-vdec.sh.
set -euo pipefail
REPO=/home/certe/aarch64-packages/linux-surface
K=$REPO/src/kernel
PKG=$REPO/linux-mibook-6.18.2-3-aarch64.pkg.tar.zst

echo "==> installing $PKG"
pacman -U --noconfirm "$PKG"

echo "==> refreshing boot files (includes the DTB with the venus node)"
install -Dm644 "$K/arch/arm64/boot/Image" /boot/vmlinuz-linux-mibook
install -Dm644 "$K/arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4.dtb" \
    /boot/dtb/linux-mibook/qcom/sc8180x-xiaomi-book-12.4.dtb
install -Dm644 "$K/arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4.dtb" \
    /boot/dtb/linux-mibook/qcom/sc8180x-xiaomi-book-12.4-oc.dtb
mkinitcpio -k 6.18.2-1-mibook+ -g /boot/initramfs-linux-mibook.img
echo "==> done; reboot and check: dmesg | grep -i venus"
