#!/bin/sh
# Xiaomi Book 12.4 -- capture the built-in microphone (WCD9340 DMIC0) straight
# from ALSA and write a listenable WAV.
#
# Why ALSA and not PipeWire: every earlier capture went through pw-cat, and the
# stream it returned was a constant full-scale white noise with a ~2.8e6 DC
# offset -- |delta|avg == AC RMS, i.e. mathematically random, unchanged over
# 7.4 s.  The same input captured with `arecord -D hw:0,1` gives DC ~0 and
# |delta|avg an order of magnitude below AC RMS (smooth audio), and the level
# rises when you make noise.  So the codec/DSP path is fine and the broken part
# was the session audio path, not the hardware.
#
# Usage:
#   ./tools/mic-record.sh 8          # 8 seconds, S24_LE, arecord
#   DMIC=1 ./tools/mic-record.sh 8   # DMIC1 instead of DMIC0
#
# Speak / tap after the "GO" marker.  The script prints a per-0.5 s envelope so
# you can see the level follow you, and writes a WAV to listen to.

set -u
CARD="${CARD:-hw:0}"
SECS="${1:-8}"
DMIC="${DMIC:-0}"
# Channel count MUST stay 2 for a clean capture: the stream is S24_LE stereo and
# the machine driver takes its SLIM TX channel map from this number.  CHAN=1 is
# kept only so the difference can be demonstrated (it produces white noise).
CHAN="${CHAN:-2}"
OUTDIR="${OUTDIR:-/home/certe/.cache/mic-wav}"
mkdir -p "$OUTDIR" || exit 1
RAW="$OUTDIR/mic-dmic$DMIC.raw"
WAV="$OUTDIR/mic-dmic$DMIC.wav"

cset() { amixer -D "$CARD" -q cset "name='$1'" "$2" >/dev/null 2>&1; }

echo "== route the capture path at DMIC$DMIC =="
cset 'AIF1_CAP Mixer SLIM TX0' 1
cset 'CDC_IF TX0 MUX' DEC0
cset 'MultiMedia2 Mixer SLIMBUS_0_TX' 1
cset 'ADC MUX0' DMIC
cset "DMIC MUX0" "DMIC$DMIC"
amixer -D "$CARD" sget "ADC MUX0" 2>&1 | grep -E "Item0" | sed 's/^/   /'
amixer -D "$CARD" sget "DMIC MUX0" 2>&1 | grep -E "Item0" | sed 's/^/   /'

echo
# hw:0,1 is what the UCM's InternalMic opens, so while the session audio stack
# is running PipeWire holds it and arecord gets nothing.  Say so instead of
# reporting an empty capture as a fault.
if amixer -D hw:0 controls >/dev/null 2>&1; then
	if grep -q "^subdevices_avail: 0" /proc/asound/card0/pcm1c/sub0/status 2>/dev/null \
	   || grep -q "state: RUNNING" /proc/asound/card0/pcm1c/sub0/status 2>/dev/null; then
		echo "note: hw:0,1 looks busy (the session audio stack is capturing through it)."
		echo "      For an ALSA-direct capture, free it first:"
		echo "        systemctl --user stop pipewire pipewire-pulse wireplumber"
		echo "      ...and start it again afterwards."
		echo
	fi
fi

echo "== recording ${SECS}s with arecord (ALSA direct) =="
echo "   >>> TALK / TAP AFTER THE 'GO' MARKER <<<"
rm -f "$RAW"
arecord -D hw:0,1 -f S24_LE -r 48000 -c "$CHAN" -t raw -d "$SECS" "$RAW" >/dev/null 2>&1 &
rec=$!
sleep 1
echo "   GO"
wait "$rec" 2>/dev/null
[ -s "$RAW" ] || { echo "arecord produced nothing" >&2; exit 1; }
echo "   $(wc -c < "$RAW") bytes"

python3 - "$RAW" "$WAV" <<'PY'
import struct, sys, wave

raw, wav = sys.argv[1], sys.argv[2]
d = open(raw, 'rb').read()
n = len(d) // 8
words = struct.unpack('<%di' % (n * 2), d[:n * 8])
ch0 = [words[i] >> 8 for i in range(0, len(words), 2)]
ch1 = [words[i] >> 8 for i in range(1, len(words), 2)]

def stats(s):
    if not s: return 0.0, 0.0, 0.0
    m = sum(s) / len(s)
    ac = (sum((x - m) ** 2 for x in s) / len(s)) ** 0.5
    return m, ac, max(abs(x - m) for x in s)

m0, ac0, pk0 = stats(ch0)
m1, ac1, pk1 = stats(ch1)

# write 16-bit WAV (DC removed)
w = wave.open(wav, 'wb'); w.setnchannels(2); w.setsampwidth(2); w.setframerate(48000)
o = bytearray()
for i in range(n):
    for v, m in ((ch0[i], m0), (ch1[i], m1)):
        x = int((v - m) / 256)
        x = max(-32768, min(32767, x))
        o += struct.pack('<h', x)
w.writeframes(bytes(o)); w.close()

print()
print(f"  frames: {n} ({n/48000:.1f} s)")
print(f"  DC   : L {m0:.0f}  R {m1:.0f}   (0 = healthy; ~1e6+ means a broken capture)")
print(f"  AC   : L {ac0:.0f}  R {ac1:.0f}   RMS in S24 counts")
print(f"  peak : L {pk0:.0f}  R {pk1:.0f}")
print()
print("  0.5 s envelope (AC RMS per window, left channel; first window is the")
print("  codec's startup transient and should be ignored):")
step = 24000
bars = ""
vals = []
for k in range(0, n, step):
    s = ch0[k:k + step]
    if len(s) < 1000: break
    mm = sum(s) / len(s)
    ac = (sum((x - mm) ** 2 for x in s) / len(s)) ** 0.5
    vals.append(ac)
    bars += f"    t={k/48000:5.1f}s  AC {ac:9.0f}  " + "#" * min(60, int(ac / 3000)) + "\n"
print(bars, end="")
if len(vals) > 2:
    body = vals[1:]                       # drop the startup transient
    lo = min(body[:max(1, len(body) // 3)])
    hi = max(body)
    print(f"\n  quietest third: {lo:.0f}   loudest: {hi:.0f}   "
          f"ratio {hi/max(lo,1):.1f}x")
    print("  a ratio above ~2 means the capture followed your voice")
PY

cat <<EOF

Listen:

    pw-play $WAV

If you hear yourself, the built-in microphone works and what is left is only
routing/gain/UCM work.  This is an ALSA-direct capture on purpose; the same
input through pw-cat did not produce usable samples.
EOF
