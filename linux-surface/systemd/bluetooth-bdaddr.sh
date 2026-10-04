#!/bin/bash
# Set the BD address of the on-board WCN3998, which has none provisioned.
#
# Has to run after the bluetooth stack brought the controller up and before
# anything tries to use it.  btmgmt needs the controller index, and the
# address can only be changed while the controller is powered down, which is
# how bluetoothd leaves it at this point.
set -euo pipefail

[ -r /etc/conf.d/bluetooth-bdaddr ] && . /etc/conf.d/bluetooth-bdaddr
BDADDR="${BDADDR:-02:00:00:12:34:56}"

# Wait for hci0 to exist (the UART attach can take a moment).
for _ in $(seq 1 30); do
    [ -d /sys/class/bluetooth/hci0 ] && break
    sleep 0.5
done

if [ ! -d /sys/class/bluetooth/hci0 ]; then
    echo "hci0 never appeared, not setting the address" >&2
    exit 0
fi

current="$(cat /sys/class/bluetooth/hci0/address 2>/dev/null || true)"
if [ "$current" = "$BDADDR" ]; then
    echo "hci0 already has $BDADDR"
    exit 0
fi

# -t 10: the command is a oneshot mgmt request; without a timeout btmgmt would
# keep waiting for events and the unit would never finish.
if btmgmt --index 0 --timeout 10 public-addr "$BDADDR" 2>&1; then
    echo "hci0 address set to $BDADDR (was ${current:-unknown})"
else
    echo "failed to set hci0 address to $BDADDR" >&2
    exit 1
fi
