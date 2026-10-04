#!/bin/bash
# Emergency: go back to the last kernel/setup that is known to boot.
#
#   sudo bash /home/certe/aarch64-packages/linux-surface/tools/recover-working.sh
#
# Restores the pre-PoC kernel and initramfs, and rebuilds the DTBs so that the
# video-codec node is NOT enabled (that node is what makes the iris driver
# probe and, with the current driver, hang the machine).
set -euo pipefail

F=/home/certe/vdec-poc-fallback
K=/home/certe/aarch64-packages/linux-surface/src/kernel
KVER="$(make -s -C "$K" ARCH=arm64 kernelrelease 2>/dev/null || echo 6.18.2-1-mibook+)"

echo "==> restoring the pre-PoC kernel and initramfs"
install -Dm644 "$F/vmlinuz-linux-mibook.pre-vdec" /boot/vmlinuz-linux-mibook
[ -f "$F/initramfs-linux-mibook.img.pre-vdec" ] && \
    install -Dm644 "$F/initramfs-linux-mibook.img.pre-vdec" /boot/initramfs-linux-mibook.img

echo "==> disabling the video-codec node in the device tree"
# The node itself is what makes the iris driver probe; turn it off in the
# board device tree and rebuild, so both GRUB DTB paths lose it.
if grep -q '^&venus {' "$K/arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4.dts"; then
    sed -i '/^\/\* Bringing-up probe of the Venus\/IRIS video decoder/,+3d' \
        "$K/arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4.dts"
fi
make -s -C "$K" ARCH=arm64 dtbs
install -Dm644 "$K/arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4.dtb" \
    /boot/dtb/linux-mibook/qcom/sc8180x-xiaomi-book-12.4.dtb
install -Dm644 "$K/arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4.dtb" \
    /boot/dtb/linux-mibook/qcom/sc8180x-xiaomi-book-12.4-oc.dtb

echo "==> blacklisting the video drivers so a stray module cannot probe"
mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/blacklist-video-poc.conf <<'CONF'
# Added by recover-working.sh: the iris/VIDEOCC probe hangs this machine.
blacklist qcom-iris
blacklist videocc-sm8150
install qcom-iris /bin/false
install videocc-sm8150 /bin/false
CONF

echo "==> verification"
md5sum "$F/vmlinuz-linux-mibook.pre-vdec" /boot/vmlinuz-linux-mibook
ls -l /boot/dtb/linux-mibook/qcom/
echo
echo "Reboot now:  sudo reboot"
