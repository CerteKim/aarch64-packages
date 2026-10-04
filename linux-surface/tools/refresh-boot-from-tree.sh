#!/bin/bash
# Refresh the /boot files from the built tree after pacman -U.
set -e
install -Dm644 /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/boot/Image /boot/vmlinuz-linux-mibook
install -Dm644 /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4.dtb /boot/dtb/linux-mibook/qcom/sc8180x-xiaomi-book-12.4.dtb
install -Dm644 /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4-oc.dtb /boot/dtb/linux-mibook/qcom/sc8180x-xiaomi-book-12.4-oc.dtb
mkinitcpio -k 6.18.2-1-mibook+ -g /boot/initramfs-linux-mibook.img
echo "--- /boot now ---"
ls -la /boot/vmlinuz-linux-mibook /boot/initramfs-linux-mibook.img
md5sum /boot/dtb/linux-mibook/qcom/*.dtb
