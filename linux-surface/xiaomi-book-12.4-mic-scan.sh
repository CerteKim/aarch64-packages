#!/bin/sh
# Xiaomi Book S 12.4 (SC8180X) -- find which WCD9340 input the mics are on.
#
# Capture works end to end on this machine (codec ADC -> SLIM TX -> ADSP ADM
# -> MultiMedia2 -> ALSA) but the input the DTS selects, AMIC2, only ever
# returns a constant noise floor that does not respond to sound.  That is
# what an unbonded/unpowered analogue input looks like: the ADC converts,
# but nothing drives it.
#
# An input can only be powered if the card-level audio-routing declares the
# supply it needs (MIC BIASn, MCLK) -- the wcd934x driver has no AMIC/DMIC to
# MIC BIAS routes of its own.  The stock DTS only declares AMIC2/MIC BIAS2,
# copied from the Lenovo Yoga C630.  The xiaomi-audio-capture branch adds the
# rest; with that DTB installed this script can walk every candidate input.
#
# Usage:
#   ./xiaomi-book-12.4-mic-scan.sh
#
# Requires the xiaomi-audio-capture DTB to be installed, otherwise only the
# AMIC2 row can respond.  Keep the room reasonably quiet; the script plays a
# loud pulsing tone through the speakers and looks for the capture level to
# follow it.

CARD="${CARD:-hw:0}"
DUR="${DUR:-4}"                 # seconds of capture per candidate
FULLSCALE=8388608               # 2^23, S24_LE
TMP="${TMPDIR:-/tmp}/mic-scan"
mkdir -p "$TMP"

if ! command -v pw-cat >/dev/null 2>&1; then
	echo "pw-cat not found (install pipewire)" >&2
	exit 1
fi

cset() {
	# name, value -- fails softly so a missing control does not abort
	amixer -D "$CARD" -q cset "name='$1'" "$2" >/dev/null 2>&1
}

# --- pulsing tone: 1 kHz, 0.5 s on / 0.5 s off -----------------------------
python3 - "$TMP/pulse.wav" <<'PY'
import wave, struct, math, sys
sr = 48000
w = wave.open(sys.argv[1], 'wb')
w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
out = []
for i in range(sr * 30):
    t = i / sr
    out.append(int(28000 * math.sin(2 * math.pi * 1000 * t / sr)) if (t % 1.0) < 0.5 else 0)
w.writeframes(struct.pack('<%dh' % len(out), *out))
w.close()
PY
[ -s "$TMP/pulse.wav" ] || { echo "failed to generate tone" >&2; exit 1; }

# --- make sure the capture backend is actually wired up --------------------
echo "== enabling capture backend =="
cset 'AIF1_CAP Mixer SLIM TX0' 1
cset 'CDC_IF TX0 MUX' DEC0
cset 'MultiMedia2 Mixer SLIMBUS_0_TX' 1
cset 'ADC2 Volume' 20

echo
printf '%-14s %-10s %-12s %-12s %s\n' INPUT ADC_MUX SEL "tone(peak)" "response"
printf '%-14s %-10s %-12s %-12s %s\n' ---- ------- --- ---------- --------

# start the tone loop for the whole scan
pw-play "$TMP/pulse.wav" >/dev/null 2>&1 &
TONE=$!
trap 'kill $TONE 2>/dev/null' EXIT INT TERM
sleep 1

probe() {
	# name, adc-mux-value, selector-control, selector-value
	iname=$1; adcmux=$2; selctl=$3; selval=$4

	cset 'AMIC MUX0' ZERO
	cset 'DMIC MUX0' ZERO
	cset "$selctl" "$selval"
	cset 'ADC MUX0' "$adcmux"
	sleep 1

	rm -f "$TMP/rec.raw"
	timeout $((DUR + 3)) pw-cat --record --format s24 --rate 48000 --channels 2 \
		"$TMP/rec.raw" >/dev/null 2>&1
	[ -s "$TMP/rec.raw" ] || { printf '%-14s %-10s %-12s %-12s %s\n' "$iname" "$adcmux" "$selval" "-" "no data"; return; }

	python3 - "$TMP/rec.raw" "$iname" "$adcmux" "$selval" "$FULLSCALE" <<'PY'
import struct, statistics, sys
path, iname, adcmux, selval, full = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
d = open(path, 'rb').read()
n = len(d) // 4
s = [x >> 8 for x in struct.unpack('<%di' % n, d[:n * 4])]
step = 12000                      # 0.25 s * 2 ch
windows = [s[i:i + step] for i in range(0, len(s) - step, step)]
rms = [statistics.pstdev(w) for w in windows if len(w) > 1000]
if not rms:
    print(f"{iname:<14} {adcmux:<10} {selval:<12} {'-':<12} no data")
    sys.exit()
mx, mn = max(rms), max(min(rms), 1.0)
ratio = mx / mn
peak = max(abs(x) for x in s)
# a live mic follows the 1 Hz pulse; a dead one is flat
verdict = "RESPONDS" if ratio > 1.8 else ("flat" if ratio < 1.3 else "weak?")
print(f"{iname:<14} {adcmux:<10} {selval:<12} {peak:<12} ratio={ratio:5.2f}  {verdict}")
PY
}

probe "AMIC1"      AMIC ADC1 1
probe "AMIC2"      AMIC ADC2 2
probe "AMIC3"      AMIC ADC3 3
probe "AMIC4"      AMIC ADC4 4
probe "DMIC0"      DMIC DMIC0 1
probe "DMIC1"      DMIC DMIC1 2
probe "DMIC2"      DMIC DMIC2 3
probe "DMIC3"      DMIC DMIC3 4
probe "DMIC4"      DMIC DMIC4 5
probe "DMIC5"      DMIC DMIC5 6

kill $TONE 2>/dev/null
trap - EXIT INT TERM

echo
echo "== restoring the DTS default (AMIC2) =="
cset 'DMIC MUX0' ZERO
cset 'AMIC MUX0' ADC2
cset 'ADC MUX0' AMIC

cat <<'EOF'

Any row reporting RESPONDS is where the built-in microphones are wired.
If every row is "flat", the mics are not on the WCD9340 at all, or they
sit on an input this codec cannot reach, and the next step is to check
the DAPM state instead:

  pw-cat --record --format s24 --rate 48000 --channels 2 /tmp/cap.raw &
  sleep 2
  sudo grep -r . /sys/kernel/debug/asoc/*/dapm/ 2>/dev/null |
      grep -iE 'MIC BIAS|MCLK|ADC2|AMIC MUX0|ADC MUX0|CDC_IF TX0|SLIM TX0|AIF1 CAP'
EOF
