#!/bin/sh
# Xiaomi Book S 12.4 (SC8180X) -- acoustic (not crosstalk) mic test.
#
# The speaker-pulse test cannot tell a real microphone apart from electrical
# crosstalk out of the playback path: both track the tone.  This test removes
# that ambiguity by muting the speaker and using YOU as the only sound source.
#
# It records a quiet baseline first and then asks you to make noise, so the
# two halves of one recording can be compared directly.
#
# Usage:
#   ./xiaomi-book-12.4-mic-tap-test.sh              # walks DMIC0..DMIC5
#   ./xiaomi-book-12.4-mic-tap-test.sh ADC3         # just one input
#   ./xiaomi-book-12.4-mic-tap-test.sh DMIC2 DMIC3  # any subset
#
# Accepts ADC1..ADC4 (WCD9340 analogue mic inputs) and DMIC0..DMIC5 (its
# digital mic inputs).  The analogue ones have already been tested and are
# all dead on this machine, so the digital ones are the default.
#
# When it says so: stay quiet for the first 3 seconds, then tap firmly on the
# tablet body near the camera / mic grille and talk at it until it ends.
# Keep the room otherwise quiet and play nothing through the speakers.

CARD="${CARD:-hw:0}"
SECS="${SECS:-10}"              # total capture time per input
TMP="${TMPDIR:-/tmp}/mic-tap"
mkdir -p "$TMP"

INPUTS="$*"
# The analogue inputs were tested first and all came back dead, so default to
# the digital ones.  Pass explicit names to test anything.
[ -n "$INPUTS" ] || INPUTS="DMIC0 DMIC1 DMIC2 DMIC3 DMIC4 DMIC5"

cset() { amixer -D "$CARD" -q cset "name='$1'" "$2" >/dev/null 2>&1; }

echo "== muting the speaker =="
if wpctl set-mute @DEFAULT_AUDIO_SINK@ 1 >/dev/null 2>&1; then
	echo "  speaker muted -- the only sound will be you"
fi

# Do not drive ADC MUX0 (or AMIC MUX0) to ZERO while switching: that wedges
# the TX path.  Just point the selectors straight at the input we want.
cset 'AIF1_CAP Mixer SLIM TX0' 1
cset 'CDC_IF TX0 MUX' DEC0

for iname in $INPUTS; do
	case "$iname" in
	ADC1|ADC2|ADC3|ADC4)
		cset 'ADC MUX0' AMIC
		cset 'AMIC MUX0' "$iname"
		;;
	DMIC0|DMIC1|DMIC2|DMIC3|DMIC4|DMIC5)
		cset 'ADC MUX0' DMIC
		cset 'DMIC MUX0' "$iname"
		;;
	*)
		echo "skipping '$iname' (expected ADC1..ADC4 or DMIC0..DMIC5)"
		continue
		;;
	esac
	sleep 2

	echo
	echo "================ $iname ================"
	echo "  recording ${SECS}s -- STAY QUIET for the first 3 s,"
	echo "  then TAP ON THE TABLET and talk at it until it ends."
	echo
	rm -f "$TMP/rec.raw"
	timeout $((SECS + 5)) pw-cat --record --format s24 --rate 48000 --channels 2 \
		"$TMP/rec.raw" >/dev/null 2>&1

	python3 - "$TMP/rec.raw" <<'PY'
import struct, statistics, sys
try:
    d = open(sys.argv[1], 'rb').read()
except OSError:
    print("  no data"); sys.exit()
n = len(d) // 4
s = [x >> 8 for x in struct.unpack('<%di' % n, d[:n * 4])]
sr, ch = 48000, 2

# drop the first 0.5 s: the stream is still spinning up there, and a single
# near-zero window is what made a plain max/min ratio meaningless
s = s[int(0.5 * sr) * ch:]
if len(s) < sr * ch:
    print("  too little data"); sys.exit()

step = int(0.5 * sr) * ch          # 0.5 s windows
win = [statistics.pstdev(s[i:i + step])
       for i in range(0, len(s) - step, step) if len(s[i:i + step]) > 1000]
if not win:
    print("  no windows"); sys.exit()

if len(set(s)) <= 4:
    print("  IDLE - capture path did not come up; rerun this input alone")
    sys.exit()

# quiet = windows 0..3 (0.5-2.5 s), loud = window 7 onward (3.5 s..)
q = win[:4] or [0.0]
l = win[7:] or [0.0]
qm, lm = statistics.fmean(q), statistics.fmean(l)
lift = lm / (max(q) or 1.0)        # loud mean vs the loudest quiet window

print("  rms per 0.5 s window (tap window starts at index 7):")
print("   ", " ".join(f"{v/1000:5.0f}k" for v in win))
print(f"  quiet 0.5-2.5s: mean {qm:8.0f}  max {max(q):8.0f}")
print(f"  loud  3.5s-end: mean {lm:8.0f}  max {max(l):8.0f}")
if lift > 3.0:
    verdict = "LIVE - clearly responds to you"
elif lift > 1.5:
    verdict = "weak - some response, could be ambient"
else:
    verdict = "dead - no response to you"
print(f"  lift = {lift:5.2f}x  ->  {verdict}")
PY
done

echo
echo "== unmuting the speaker =="
wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 >/dev/null 2>&1 && echo "  speaker unmuted"

cat <<'EOF'

How to read it:
  LIVE on some input -> that input is the real microphone; tell me which one
                        and I will point the UCM profile and the DTS at it.
  dead on all        -> the mics are not on the WCD9340 at all, and the next
                        step is the DAPM state / a different capture block.
  IDLE on some       -> that input never powered up; rerun it alone:
                           ./xiaomi-book-12.4-mic-tap-test.sh DMIC3

The "lift" is the loud-window mean divided by the loudest quiet window.  A
microphone hearing you tap gives a big number; electrical crosstalk and a
dead input both give ~1x, because the speaker is muted either way.
EOF
