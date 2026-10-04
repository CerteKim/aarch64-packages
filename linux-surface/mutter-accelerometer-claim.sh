#!/bin/bash
# ===================================================================
# Claim the accelerometer for GNOME, working around mutter#4931.
#
# After login mutter's MetaOrientationManager drives its inhibit counter
# to -1 with an unpaired uninhibit (panel_orientation_managed going
# FALSE -> TRUE through notify::has-accelerometer), and
# uninhibit_tracking() only re-evaluates should_claim when the counter
# lands on exactly 0. should_claim therefore stays FALSE, mutter never
# sends ClaimAccelerometer, GNOME reports HasAccelerometer = true and the
# screen never rotates.
#
# Two inhibits followed by one uninhibit walk the counter
# -1 -> 0 -> 1 -> 0. The last step lands exactly on 0, so mutter
# re-evaluates and claims; the trailing lock release (0 -> -1) cannot drop
# the claim because uninhibit only re-evaluates on 0.
#
# Installed as a GNOME autostart entry; documented in HARDWARE-STATUS.md
# ("Working around it in the running session"). See also
# https://gitlab.gnome.org/GNOME/mutter/-/work_items/4931
#
# Options:
#   --force    run the poke even if the sensor already looks claimed
#   --quiet    only log warnings
# ===================================================================
set -u

FORCE=false
QUIET=false
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --quiet) QUIET=true ;;
  esac
done

LOG="${XDG_STATE_HOME:-$HOME/.local/state}/mutter-accelerometer-claim.log"
mkdir -p "$(dirname "$LOG")" 2>/dev/null

log() {
  local level="$1"; shift
  local line
  line="$(date '+%F %T') $*"
  printf '%s\n' "$line" >> "$LOG" 2>/dev/null
  if ! $QUIET || [ "$level" = "warn" ]; then
    printf '%s\n' "$line"
  fi
}
info()  { log info  "$*"; }
warn()  { log warn  "WARNING: $*"; }

: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "$XDG_RUNTIME_DIR/bus" ]; then
  export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
fi

DISPLAY_CONFIG_DEST=org.gnome.Mutter.DisplayConfig
DISPLAY_CONFIG_PATH=/org/gnome/Mutter/DisplayConfig
LOCK_KEY=org.gnome.settings-daemon.peripherals.touchscreen
LOCK_SCHEMA="gsettings get $LOCK_KEY orientation-lock"

sensor() {
  gdbus introspect --system --dest net.hadess.SensorProxy \
    --object-path /net/hadess/SensorProxy 2>/dev/null
}
orientation() {
  sensor | sed -n "s/.*AccelerometerOrientation = '\(.*\)'.*/\1/p"
}
accel_readings() {
  journalctl -b -u iio-sensor-proxy --no-pager --since '5 sec ago' 2>/dev/null \
    | grep -c 'Accel sent by driver'
}
set_power_save() {
  gdbus call --session --dest "$DISPLAY_CONFIG_DEST" \
    --object-path "$DISPLAY_CONFIG_PATH" \
    --method org.freedesktop.DBus.Properties.Set \
    "$DISPLAY_CONFIG_DEST" PowerSaveMode "<int32 $1>" >/dev/null 2>&1
}

claimed() {
  local o
  o="$(orientation)"
  [ -n "$o" ] && [ "$o" != "undefined" ] && return 0
  [ "$(accel_readings)" -gt 0 ] && return 0
  return 1
}

# --- 1. wait for the compositor D-Bus name -----------------------------
for _ in $(seq 1 60); do
  gdbus call --session --dest "$DISPLAY_CONFIG_DEST" \
    --object-path "$DISPLAY_CONFIG_PATH" \
    --method "$DISPLAY_CONFIG_DEST.GetCurrentState" >/dev/null 2>&1 && break
  sleep 1
done

# --- 2. wait for the sensor proxy to expose the accelerometer ----------
for _ in $(seq 1 60); do
  sensor | grep -q "HasAccelerometer = true" && break
  sleep 1
done
if ! sensor | grep -q "HasAccelerometer = true"; then
  warn "HasAccelerometer never became true; is hexagonrpcd-sdsp running?"
  exit 1
fi

# --- 3. let mutter resolve its proxy, which is what trips the bug ------
sleep 6

if [ "$($LOCK_SCHEMA)" = "true" ]; then
  info "rotation is locked (orientation-lock=true); leaving the sensor alone"
  exit 0
fi

if ! $FORCE && claimed; then
  info "accelerometer already claimed (orientation $(orientation)); nothing to do"
  exit 0
fi

# --- 4. the poke -------------------------------------------------------
lock_orig="$($LOCK_SCHEMA)"
restore() {
  set_power_save 0
  [ "$lock_orig" = "true" ] && gsettings set "$LOCK_KEY" orientation-lock true
}
trap restore EXIT

info "poking mutter to claim the accelerometer (counter -1 -> 0 -> 1 -> 0)"
gsettings set "$LOCK_KEY" orientation-lock true
set_power_save 1
set_power_save 0
gsettings set "$LOCK_KEY" orientation-lock false

# --- 5. verify ---------------------------------------------------------
for _ in $(seq 1 15); do
  if [ "$(orientation)" != "undefined" ] && [ -n "$(orientation)" ]; then
    info "mutter claimed the accelerometer (orientation $(orientation))"
    exit 0
  fi
  if [ "$(accel_readings)" -gt 0 ]; then
    info "mutter claimed the accelerometer (readings flowing)"
    exit 0
  fi
  sleep 1
done

warn "no accelerometer readings after the poke; run the recipe in HARDWARE-STATUS.md by hand"
exit 1
