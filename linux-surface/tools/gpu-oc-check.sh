#!/bin/bash
# Is the binned GPU device tree booted, and does it reach its higher states?
#
#   tools/gpu-oc-check.sh                     # state only
#   tools/gpu-oc-check.sh -- <gpu workload>   # also sample the clock under load
#
# The board device tree declares the firmware's own 670 MHz profile (ACPI
# ENGINE_PSTATE_SET 0x02 / GRAPHICS_FREQ_CONTROL / CORE_CLOCK), which pairs
# every RPMh corner with a higher clock than the stock SC8180X set:
#
#     235 MHz @ LOW_SVS (0x40)     530 MHz @ NOM      (0x100)
#     315 MHz @ SVS     (0x80)     595 MHz @ NOM_L1   (0x140)
#     392 MHz @ SVS_L1  (0xc0)     625 MHz @ TURBO    (0x180)
#                                  670 MHz @ TURBO_L1 (0x1a0)
#
# The stock states must be *replaced*, not extended: a6xx_hfi_send_perf_table()
# hands the OPP table to the GMU keyed by these corner levels, so a stock state
# left in at the same level as a binned one (405 and 530 both at NOM, ...) gives
# the firmware two clocks for one corner and it runs the lower one.  Any stock
# frequency still in available_frequencies therefore means the merged (stock)
# table is booted.
#
# Neither the a6xx driver nor the GMU firmware needs to change for the binned
# profile to work - each level's GX rail vote comes from opp-level, and the
# device tree has no speed-bin nvmem cell, so a6xx_set_supported_hw() gets
# -ENOENT and no OPP gating (opp-supported-hw) is applied.
#
# Exit status: 0 = binned profile booted, 2 = stock/merged table booted,
#              3 = the devfreq device is missing (driver not loaded).
set -uo pipefail

DEV=/sys/class/devfreq/2c00000.gpu
# The binned profile, and the stock frequencies it replaces.
PROFILE_STATES="235000000 315000000 392000000 530000000 595000000 625000000 670000000"
STOCK_ONLY="177000000 256000000 405000000 461000000 500000000 514000000"
DTB_DIRS="/boot/dtb/linux-mibook-mainline/qcom /boot/dtb/linux-mibook/qcom"
rc=0

if [ ! -d "$DEV" ]; then
    echo "!! $DEV is missing - msm/adreno not loaded?"
    exit 3
fi

echo "== booted device trees"
for d in $DTB_DIRS; do
    for f in "$d"/sc8180x-xiaomi-book-12.4*.dtb; do
        [ -f "$f" ] || continue
        printf '   %-56s %s\n' "$f" "$(md5sum "$f" | cut -d' ' -f1)"
    done
done

echo
echo "== GPU devfreq"
printf '   available_frequencies: %s\n' "$(cat "$DEV/available_frequencies")"
printf '   cur_freq: %s   max_freq: %s   governor: %s\n' \
       "$(cat "$DEV/cur_freq")" "$(cat "$DEV/max_freq")" "$(cat "$DEV/governor" 2>/dev/null || echo -)"

echo
echo "== binned profile"
missing=""
for f in $PROFILE_STATES; do
    if grep -qw "$f" "$DEV/available_frequencies"; then
        printf '   %3s MHz  present\n' "$((f / 1000000))"
    else
        printf '   %3s MHz  MISSING\n' "$((f / 1000000))"
        missing="$missing $f"
    fi
done

echo
echo "== stock states that must be gone"
stale=""
for f in $STOCK_ONLY; do
    if grep -qw "$f" "$DEV/available_frequencies"; then
        printf '   %3s MHz  still present (stock/merged table)\n' "$((f / 1000000))"
        stale="$stale $f"
    fi
done
[ -n "$stale" ] || echo "   none"

if [ -n "$missing$stale" ]; then
    echo
    echo "-> not running the binned profile: install the rebuilt DTB and reboot, e.g."
    echo "   sudo install -Dm644 src/kernel/arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4.dtb \\"
    echo "        /boot/dtb/linux-mibook/qcom/sc8180x-xiaomi-book-12.4.dtb"
    echo "   sudo install -Dm644 src/kernel-7.2/arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4.dtb \\"
    echo "        /boot/dtb/linux-mibook-mainline/qcom/sc8180x-xiaomi-book-12.4.dtb"
    rc=2
fi

if [ "${1:-}" = "--" ] && [ "$#" -gt 1 ]; then
    shift
    echo
    echo "== sampling cur_freq while running: $*"
    "$@" >/dev/null 2>&1 &
    pid=$!
    peak=0
    while kill -0 "$pid" 2>/dev/null; do
        v=$(cat "$DEV/cur_freq" 2>/dev/null) || break
        [ "${v:-0}" -gt "$peak" ] && peak="$v"
        sleep 0.2
    done
    wait "$pid"
    st=$?
    printf '   peak cur_freq %s Hz (%s MHz), %s exited %s\n' \
           "$peak" "$((peak / 1000000))" "$*" "$st"
    if [ "$peak" -ge 670000000 ]; then
        echo "   reached the 670 MHz state"
    else
        echo "   stayed below 670 MHz - the workload may be too light to reach it"
    fi
fi

echo
echo "== GPU errors in the log"
if dmesg 2>/dev/null | grep -iE "adreno|gmu|msm" | grep -iE "fail|error|fault|timeout|reset|hang" | tail -10; then
    :
else
    echo "   none"
fi

exit "$rc"
