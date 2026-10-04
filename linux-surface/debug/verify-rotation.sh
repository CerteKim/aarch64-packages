#!/bin/bash
# ===================================================================
# Verify auto-rotation after reloading GNOME Shell.
#
#   1. Reload the shell first:  Alt+F2, type  r , Enter
#      (Wayland: log out and back in instead)
#   2. If the sensor was never claimed (see HARDWARE-STATUS.md,
#      mutter#4931), run the inhibit recipe there first - otherwise the
#      steps below will show readings that never change.
#   3. Then run:  ./verify-rotation.sh
#   4. Rotate the tablet through the four positions when prompted.
#
# Expected sensor-side readings with the correct mount matrix
# (-1,0,0;0,-1,0;0,0,1, see ~/qcom-slpi/udev/):
#   keyboard edge down (one landscape)  -> left-up  or right-up
#   keyboard edge up   (other landscape) -> the other one
#   portrait, camera edge up            -> normal
#   portrait, camera edge down          -> bottom-up
# ===================================================================
set -u

read_transform() {
  gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
    --object-path /org/gnome/Mutter/DisplayConfig \
    --method org.gnome.Mutter.DisplayConfig.GetCurrentState 2>/dev/null \
    | grep -oE '\[\(0, 0, 2\.0, uint32 [0-9]+' | grep -oE '[0-9]+$'
}
read_orientation() {
  gdbus introspect --system --dest net.hadess.SensorProxy \
    --object-path /net/hadess/SensorProxy 2>/dev/null \
    | grep AccelerometerOrientation | sed "s/.*'\(.*\)'.*/\1/"
}

echo "=== 1. is GNOME holding the accelerometer? ==="
if journalctl -b -u iio-sensor-proxy --no-pager --since '5 min ago' 2>&1 \
     | grep -q "refcounting method 'ClaimAccelerometer'"; then
  echo "  yes - a client claimed it in the last 5 minutes"
else
  echo "  NO claim seen. Reload the shell (Alt+F2, r) and re-run this script."
  echo "  Mutter will NOT retry a claim it already failed once."
fi

echo
echo "=== 2. matrix in use ==="
udevadm info /dev/fastrpc-sdsp 2>/dev/null | grep ACCEL_MOUNT_MATRIX || echo "  (rule missing!)"

echo
echo "=== 3. watching for 90s ==="
echo "    rotate the tablet through the four positions now"
echo
printf '%-9s %-20s %-10s\n' "time" "orientation" "transform"
prev=""
end=$(( $(date +%s) + 90 ))
while [ "$(date +%s)" -lt "$end" ]; do
  o=$(read_orientation)
  t=$(read_transform)
  if [ "$o|$t" != "$prev" ]; then
    printf '%-9s %-20s %-10s\n' "$(date +%T)" "$o" "$t"
    prev="$o|$t"
  fi
  sleep 0.7
done

echo
echo "transform legend (mutter MtkMonitorTransform):"
echo "  0=normal  1=90deg  2=180deg  3=270deg   (there is no 8)"
echo "portrait holds -> 0 / 2, landscape holds -> 1 / 3."
echo "The transform MUST change as you rotate the tablet; if it never does, GNOME"
echo "is not holding the sensor - run the inhibit recipe in HARDWARE-STATUS.md"
echo "(mutter#4931), then re-run this script."
