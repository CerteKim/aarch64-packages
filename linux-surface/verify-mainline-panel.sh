#!/bin/bash
# Verify that the mainline HX83121A dual-DSI panel port came up.
# Run after booting the newly installed kernel (no root needed for most of it).
set -uo pipefail

echo "== kernel =="
uname -r

echo
echo "== driver binding / panel probe =="
if [ -r /sys/kernel/debug/devices_deferred ]; then
    grep -i himax /sys/kernel/debug/devices_deferred || echo "  (no deferred himax devices)"
fi

echo
echo "== DSI links =="
for n in dsi@ae94000 dsi@ae96000; do
    p="/sys/firmware/devicetree/base/soc@0/display-subsystem@ae00000/$n/status"
    [ -f "$p" ] && echo "  $n: $(tr -d '\0' < "$p")"
done

echo
echo "== DRM connectors =="
for c in /sys/class/drm/card*/card*-DSI-*; do
    [ -e "$c" ] || continue
    echo "  $(basename "$c"): status=$(cat "$c/status" 2>/dev/null)"
    echo "    modes: $(tr '\n' ' ' < "$c/modes" 2>/dev/null)"
done

echo
echo "== panel / backlight =="
cat /sys/class/backlight/*/brightness 2>/dev/null | sed 's/^/  brightness: /'
cat /sys/class/backlight/*/max_brightness 2>/dev/null | sed 's/^/  max: /'

echo
echo "== panel module parameters (built-in: shown via /sys/module) =="
for p in enable_dsc pnc_full_init; do
    f="/sys/module/himax_hx83121a/parameters/$p"
    [ -f "$f" ] && echo "  $p = $(cat "$f")"
done

echo
echo "== dmesg (panel/DSI/DSC) =="
if dmesg >/dev/null 2>&1; then
    dmesg | grep -iE "himax|hx83121|dsi|dsc|panel" | tail -40
else
    sudo dmesg | grep -iE "himax|hx83121|dsi|dsc|panel" | tail -40
fi
