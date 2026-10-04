#!/usr/bin/env bash
#
# verify-backlight.sh - capture the PMC8180C backlight hardware state.
#
# What this investigates
# ----------------------
# The panel is lit, but writing /sys/class/backlight/backlight/brightness has no
# visible effect - and neither does writing 0, which qcom-wled turns into
# "disable the WLED module".  So one of these must be true:
#
#   (a) the qcom-wled driver's SPMI writes never reach the WLED register block,
#       so the panel keeps running at whatever the bootloader left behind, or
#   (b) the panel's light does not come from that WLED at all - the candidates
#       are the PMC8180C LPG/PWM block (which this board's DT enables although
#       nothing consumes it) or the panel's own DCS brightness control.
#
# The script dumps the whole pmic@5 register map twice - once with brightness 0
# and once with 3000 - so the registers the driver actually changed show up in a
# diff.  It also prints the LPG channel registers, because a PWM channel left
# running by the bootloader would point at a PWM-dimmed backlight.
#
# Run as root:   sudo ./verify-backlight.sh
# Results:       ./backlight-diag/{summary.txt,regs-0.txt,regs-3000.txt}

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/backlight-diag"
BL=/sys/class/backlight/backlight
DBG=/tmp/backlight-debugfs

if [ "$(id -u)" -ne 0 ]; then
	printf 'run me as root:  sudo %s\n' "$0" >&2
	exit 1
fi

if [ ! -e "$BL/brightness" ]; then
	echo "!! no backlight device at $BL" >&2
	exit 1
fi

mkdir -p "$OUT" "$DBG"
mountpoint -q "$DBG" || mount -t debugfs none "$DBG" || exit 1

exec > >(tee "$OUT/summary.txt") 2>&1

orig=$(cat "$BL/brightness")
echo "== $(date -Is)   kernel $(uname -r)"
echo "== regmap entries:"
ls "$DBG/regmap" 2>/dev/null || true

# The pmic@5 regmap is registered under the SPMI USID ("0-05"), not the node name.
regmap=""
for d in "$DBG"/regmap/*; do
	[ -d "$d" ] || continue
	base=$(basename "$d")
	name=$(cat "$d/name" 2>/dev/null)
	case "$base $name" in
	*pmic@5*|0-05*) regmap="$d"; break ;;
	esac
done
if [ -z "$regmap" ]; then
	echo "!! no pmic@5 (0-05) regmap under $DBG/regmap (missing CONFIG_DEBUG_FS?)" >&2
	exit 1
fi
echo "== pmic regmap: $regmap"
echo "== regmap name: $(cat "$regmap/name" 2>/dev/null)"
echo "== regmap range: $(cat "$regmap/range" 2>/dev/null | tr '\n' ' ')"

echo
echo "== before: brightness=$orig max=$(cat "$BL/max_brightness") type=$(cat "$BL/type") bl_power=$(cat "$BL/bl_power")"
echo "== mode: $(head -1 /sys/class/drm/card0-DSI-1/modes 2>/dev/null)"

for v in 0 3000; do
	echo "$v" > "$BL/brightness"
	sleep 1
	echo
	echo "== request=$v  readback=$(cat "$BL/brightness") actual=$(cat "$BL/actual_brightness") bl_power=$(cat "$BL/bl_power") dpms=$(cat /sys/class/drm/card0-DSI-1/dpms 2>/dev/null)"
	if cat "$regmap/registers" > "$OUT/regs-$v.txt"; then
		echo "   dumped $(wc -l < "$OUT/regs-$v.txt") register lines"
	else
		echo "!! registers dump failed" >&2
		break
	fi
done

echo "$orig" > "$BL/brightness"

if [ -s "$OUT/regs-0.txt" ] && [ -s "$OUT/regs-3000.txt" ]; then
	echo
	echo "== register lines that differ between brightness 0 and 3000:"
	if diff -q "$OUT/regs-0.txt" "$OUT/regs-3000.txt" > /dev/null; then
		echo "   NONE - the qcom-wled writes did not reach this register map"
	else
		diff -u "$OUT/regs-0.txt" "$OUT/regs-3000.txt" |
			grep -E '^[+-][0-9a-fX]{4}:' | sort -u | head -60
	fi

	echo
	echo "== WLED modulator registers at request=3000:"
	for a in d800 d846 d946 d950 d951 d952 d953 d954 d960 d961 d962 d963 d964 d965; do
		line=$(grep -E "^$a:" "$OUT/regs-3000.txt" 2>/dev/null)
		[ -n "$line" ] && echo "   $line"
	done
	echo "   (d846 = module enable, d950 = modulator A enable,"
	echo "    d953/d954 = modulator A brightness LSB/MSB, d965 = mod sync)"

	echo
	echo "== LPG channel windows at request=3000 (0x40 clock/type/value/enable, 0x50 ramp):"
	for b in b1 b2 b3 bc bd; do
		echo "   -- ${b}00"
		grep -E "^${b}[45][0-9a-f]:" "$OUT/regs-3000.txt" 2>/dev/null | sed 's/^/      /'
	done
fi

echo
echo "== done - results in $OUT"
