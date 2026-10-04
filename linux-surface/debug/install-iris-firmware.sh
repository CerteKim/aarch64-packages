#!/bin/bash
# Install the SC8180X VPU (IRIS1) firmware staged from the Windows install.
#
#   sudo bash /home/certe/aarch64-packages/linux-surface/tools/install-iris-firmware.sh
#
# The iris driver loads "qcom/sc8180x/venus.mbn" here, which is the name the
# &venus node carries as "firmware-name".  See firmware/qcom/sc8180x/README.md
# for where the blob came from.
#
# This only installs the blob: it does not touch the device tree, the kernel or
# modprobe.d, so it cannot make the machine probe anything.  Use
# tools/probe-vdec-run.sh for the full, verified probe install.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/firmware/qcom/sc8180x/venus.mbn"
DST=/lib/firmware/qcom/sc8180x/venus.mbn

echo "==> installing firmware"
install -Dm644 "$SRC" "$DST"
ls -l "$DST"
strings "$DST" | grep -m1 QC_IMAGE_VERSION_STRING

echo
echo "The blob is in place.  To run the probe (device tree + kernel package +"
echo "blacklist, with pre-reboot verification):"
echo
echo "    sudo $REPO/tools/probe-vdec-run.sh"
