#!/bin/bash
# Sync the freshly built kernel, modules, DTB and initramfs to the live system.
# Run as root from anywhere:
#   sudo bash /tmp/apply-videocc-fix.sh
set -euo pipefail

K=/home/certe/aarch64-packages/linux-surface/src/kernel
KVER="$(make -s -C "$K" ARCH=arm64 kernelrelease)"
DTB=sc8180x-xiaomi-book-12.4.dtb

echo "==> kernel release: $KVER"
echo "==> 1/4 installing modules from the build tree"
make -C "$K" ARCH=arm64 INSTALL_MOD_PATH=/ INSTALL_MOD_STRIP=1 modules_install >/dev/null
depmod "$KVER"

echo "==> 2/4 installing kernel image"
install -Dm644 "$K/arch/arm64/boot/Image" /boot/vmlinuz-linux-mibook
install -Dm644 "$K/System.map" "/usr/lib/modules/$KVER/System.map"
install -Dm644 "$K/.config"  "/usr/lib/modules/$KVER/config"

echo "==> 3/4 installing DTB"
# Both GRUB-referenced paths: the default entry uses -oc.dtb, the advanced
# entry uses the plain name.  Missing one leaves a stale DTB behind.
install -Dm644 "$K/arch/arm64/boot/dts/qcom/$DTB" "/boot/dtb/linux-mibook/qcom/$DTB"
install -Dm644 "$K/arch/arm64/boot/dts/qcom/$DTB" "/boot/dtb/linux-mibook/qcom/sc8180x-xiaomi-book-12.4-oc.dtb"
md5sum "/boot/dtb/linux-mibook/qcom/$DTB" "/boot/dtb/linux-mibook/qcom/sc8180x-xiaomi-book-12.4-oc.dtb"

echo "==> 4/4 regenerating initramfs"
rm -f /boot/initramfs-linux-mibook.img
mkinitcpio -k "$KVER" -g /boot/initramfs-linux-mibook.img

echo
echo "==> verification (must all be non-empty / matching)"
md5sum "$K/arch/arm64/boot/Image" /boot/vmlinuz-linux-mibook
ls -l "/usr/lib/modules/$KVER/kernel/drivers/clk/qcom/videocc-sm8150.ko"
ls -l "/usr/lib/modules/$KVER/kernel/drivers/media/platform/qcom/iris/qcom-iris.ko"
strings "/usr/lib/modules/$KVER/kernel/drivers/clk/qcom/videocc-sm8150.ko" | grep -m1 sc8180x-videocc
ls -l /boot/initramfs-linux-mibook.img
echo
echo "Now: sudo reboot"
