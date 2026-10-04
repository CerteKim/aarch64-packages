#!/bin/bash
# Install the WCN3998 BD address workaround.
#
#   sudo bash tools/install-bluetooth-bdaddr.sh [address]
#
# The board's Bluetooth controller has no address provisioned, so it comes up
# with the placeholder from the generic NVM and btqca refuses to configure it.
# This installs a oneshot unit that sets a real address after bluetoothd has
# brought the controller up, replacing the local-bd-address device tree
# property that was used before.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/systemd"
ADDR="${1:-}"

echo "==> installing script, config and unit"
install -Dm755 "$SRC/bluetooth-bdaddr.sh"   /usr/local/bin/bluetooth-bdaddr.sh
install -Dm644 "$SRC/bluetooth-bdaddr.conf" /etc/conf.d/bluetooth-bdaddr
install -Dm644 "$SRC/bluetooth-bdaddr.service" /etc/systemd/system/bluetooth-bdaddr.service

if [ -n "$ADDR" ]; then
    echo "==> setting address to $ADDR"
    sed -i "s/^BDADDR=.*/BDADDR=\"$ADDR\"/" /etc/conf.d/bluetooth-bdaddr
fi

echo "==> enabling and running it now"
systemctl daemon-reload
systemctl enable bluetooth-bdaddr.service
systemctl restart bluetooth-bdaddr.service || true

echo
echo "==> result"
systemctl --no-pager --full status bluetooth-bdaddr.service | head -12 || true
echo
echo "current address: $(cat /sys/class/bluetooth/hci0/address 2>/dev/null || echo '(no hci0)')"
echo "change it in /etc/conf.d/bluetooth-bdaddr and run: sudo systemctl restart bluetooth-bdaddr"
