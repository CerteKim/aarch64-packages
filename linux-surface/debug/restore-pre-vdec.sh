#!/bin/bash
# Restore the pre-Venus-PoC boot files.  Run as root.
set -euo pipefail
F=/home/certe/vdec-poc-fallback
install -Dm644 "$F/vmlinuz-linux-mibook.pre-vdec" /boot/vmlinuz-linux-mibook
install -Dm644 "$F/sc8180x-xiaomi-book-12.4.dtb.pre-vdec" /boot/dtb/linux-mibook/qcom/sc8180x-xiaomi-book-12.4.dtb
install -Dm644 "$F/sc8180x-xiaomi-book-12.4.dtb.pre-vdec" /boot/dtb/linux-mibook/qcom/sc8180x-xiaomi-book-12.4-oc.dtb
mkinitcpio -k 6.18.2-1-mibook+ -g /boot/initramfs-linux-mibook.img
echo "restored pre-PoC boot files"
