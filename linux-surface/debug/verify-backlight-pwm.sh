#!/usr/bin/env bash
#
# verify-backlight-pwm.sh - test whether the PMC8180C LPG channel 5 (0xbd00)
# PWM is what actually drives the panel backlight.
#
# Why this is the prime suspect
# -----------------------------
# The pmic@5 register dump (backlight-diag/) shows the LPG channel at 0xbd00
# configured as a 9-bit PWM, ~1.17 kHz, 256/511 = 50.1% duty, output enabled
# (0xbd46 = 0x80) - a textbook display-backlight setting - and nothing else in
# the whole PMIC register map looks like a running light source.  No Linux
# driver consumes the LPG: this board's DT enables &pmc8180c_lpg (the DTSI
# default is "disabled") but no backlight/pwm consumer references it, and the
# qcom-wled device the panel points at (0xd800) reads back as all zeroes.  So
# the panel keeps running at whatever the bootloader left in that PWM.
#
# This script exports pwm4 (LPG channel index 4 -> base 0xbd00), sweeps the duty
# and then restores the bootloader's 50.1% setting.  Watch the screen while it
# runs: if this PWM is the backlight, the screen dims at step 1 and brightens at
# step 2.  If nothing happens, the LPG is not the light source.
#
# Run as root:  sudo ./verify-backlight-pwm.sh

set -u

CHIP=/sys/class/pwm/pwmchip0
CH=4
# decoded from the register dump with leds-qcom-lpg's own formulas:
#   period = (2^9 - 1) * pre_div[0]=1 * 2^exp[5]=32 / 19.2MHz = 851667 ns
#   duty   = 256 * 1 * 32 / 19.2MHz                            = 426667 ns
PERIOD=851667
DUTY_ORIG=426667

if [ "$(id -u)" -ne 0 ]; then
	printf 'run me as root:  sudo %s\n' "$0" >&2
	exit 1
fi
if [ ! -d "$CHIP" ]; then
	echo "!! no $CHIP - the LPG driver is not bound" >&2
	exit 1
fi

exported=0
if [ -e "$CHIP/pwm$CH" ]; then
	echo "pwm$CH is already exported, reusing it"
else
	echo "$CH" > "$CHIP/export" || exit 1
	exported=1
fi
P="$CHIP/pwm$CH"
sleep 0.2

set_state() {
	local period="$1" duty="$2"

	echo "$period" > "$P/period" 2>/dev/null
	echo "$duty" > "$P/duty_cycle" 2>/dev/null
	echo 1 > "$P/enable" 2>/dev/null
	printf '   -> period=%s duty=%s enable=%s\n' \
		"$(cat "$P/period" 2>/dev/null)" \
		"$(cat "$P/duty_cycle" 2>/dev/null)" \
		"$(cat "$P/enable" 2>/dev/null)"
}

echo "== before: period=$(cat "$P/period" 2>/dev/null) duty=$(cat "$P/duty_cycle" 2>/dev/null) enable=$(cat "$P/enable" 2>/dev/null)"
echo "   (decoded bootloader state: period=$PERIOD duty=$DUTY_ORIG = 50.1% duty, ~1.17 kHz)"

echo
echo ">>> STEP 1/3: duty 20%   -- screen should get DARKER (or brighter, if inverted)"
set_state "$PERIOD" $((PERIOD / 5))
sleep 8

echo
echo ">>> STEP 2/3: duty 80%   -- screen should get BRIGHTER (or darker, if inverted)"
set_state "$PERIOD" $((PERIOD * 4 / 5))
sleep 8

echo
echo ">>> STEP 3/3: restoring the bootloader's 50% setting"
set_state "$PERIOD" "$DUTY_ORIG"
sleep 3

if [ "$exported" = 1 ]; then
	echo "$CH" > "$CHIP/unexport" 2>/dev/null
fi

echo
echo "== done.  Did the screen brightness change in steps 1 and 2?"
