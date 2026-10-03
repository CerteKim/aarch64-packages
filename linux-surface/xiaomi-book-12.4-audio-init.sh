#!/bin/sh
# Xiaomi Book 12.4 (SC8180X) audio routing bring-up.
#
# There is no UCM profile for this machine yet, so the ADSP front ends, the
# WCD9340 codec-internal DAPM path and the SLIM RX port muxes all have to be
# set by hand before any sound comes out.
#
# The codec-internal controls come from the upstream alsa-ucm-conf WCD934x
# sequences (ucm2/codecs/wcd934x/), the ADM routing from the sc8180x-mainline
# UCM profile for the Lenovo Flex 5G (ucm2/Qualcomm/sm8150/).
#
# Usage:
#   ./xiaomi-book-12.4-audio-init.sh          # set everything
#   ./xiaomi-book-12.4-audio-init.sh --store  # ...and persist via alsactl
#
# Persist afterwards so it survives reboots:
#   sudo alsactl store

CARD="${CARD:-0}"
STORE=0
[ "$1" = "--store" ] && STORE=1

ok=0
fail=0

cset() {
	if amixer -c "$CARD" cset "name='$1'" "$2" >/dev/null 2>&1; then
		ok=$((ok + 1))
		printf '  ok    %s = %s\n' "$1" "$2"
	else
		fail=$((fail + 1))
		printf '  MISS  %s = %s\n' "$1" "$2"
	fi
}

echo "== WCD9340 output volumes (ucm2/codecs/wcd934x/init.conf) =="
cset 'RX7 Digital Volume' 80
cset 'RX8 Digital Volume' 80
cset 'RX1 Digital Volume' 80
cset 'RX2 Digital Volume' 80

echo "== WCD9340 SLIM RX port -> AIF muxes (DefaultEnableSeq.conf) =="
cset 'SLIM RX0 MUX' AIF1_PB
cset 'SLIM RX1 MUX' AIF1_PB
cset 'SLIM RX2 MUX' AIF2_PB
cset 'SLIM RX3 MUX' AIF2_PB
cset 'AIF1_CAP Mixer SLIM TX0' 1
cset 'CDC_IF TX0 MUX' DEC0

echo "== WCD9340 speaker path (SpeakerEnableSeq.conf) =="
cset 'COMP7 Switch' 1
cset 'COMP8 Switch' 1
cset 'RX INT7_1 MIX1 INP0' RX0
cset 'RX INT8_1 MIX1 INP0' RX1

echo "== WSA881x amplifier SoundWire ports (wsa881x/SpeakerEnableSeq.conf) =="
# These populate wsa881x port_enable[].  Without them wsa881x_hw_params()
# adds the amplifier to the SoundWire stream with ZERO ports, so no audio is
# ever sent to it -- the amplifier still powers up, which is the audible pop.
cset 'SpkrLeft COMP Switch' 1
cset 'SpkrLeft BOOST Switch' 1
cset 'SpkrLeft DAC Switch' 1
cset 'SpkrLeft VISENSE Switch' 0
cset 'SpkrLeft PA Volume' 12
cset 'SpkrRight COMP Switch' 1
cset 'SpkrRight BOOST Switch' 1
cset 'SpkrRight DAC Switch' 1
cset 'SpkrRight VISENSE Switch' 0
cset 'SpkrRight PA Volume' 12

echo "== ADSP frontend -> SLIMbus backend routing (q6routing) =="
cset 'SLIMBUS_0_RX Audio Mixer MultiMedia1' 1
cset 'SLIMBUS_1_RX Audio Mixer MultiMedia3' 1
cset 'MultiMedia2 Mixer SLIMBUS_0_TX' 1

echo
echo "applied: $ok   missing: $fail"

if [ "$STORE" = 1 ]; then
	echo "== storing ALSA state =="
	if command -v alsactl >/dev/null 2>&1; then
		sudo alsactl store && echo "stored (alsa-restore.service will apply it at boot)"
	else
		echo "alsactl not found (install alsa-utils)"
	fi
fi

cat <<'EOF'

Test:
  speaker-test -D hw:0,0 -c 2 -t sine     # speakers   (MultiMedia1)
  speaker-test -D hw:0,2 -c 2 -t sine     # headphones (MultiMedia3)

Anything reported as MISS does not exist on this card; send that list back.
EOF
