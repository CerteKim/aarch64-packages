#!/bin/sh
# Install / update the ALSA UCM profile for the Xiaomi Book 12.4 -- speaker,
# headphones, headset mic and the built-in microphone.
#
#   sudo tools/install-ucm.sh
#
# UCM profiles are pure userspace text; no kernel module is involved, so this is
# safe to run on any kernel (unlike tools/audio-fix-install.sh, which also
# swaps codec modules and therefore refuses to run when the running kernel is
# not the one those modules were built for).
#
# What it installs:
#   /usr/share/alsa/ucm2/Qualcomm/xiaomi-book-12.4/HiFi.conf
#   /usr/share/alsa/ucm2/conf.d/sdm845/TIMI-XiaomiBook12.4-INVALID-TM2133.conf
#
# The HiFi.conf here adds SectionDevice."InternalMic", which is what makes the
# built-in DMIC0 array appear as a capture source.  Its EnableSequence asserts
# the routing verified on hardware:
#
#   ADC MUX0 = DMIC      (the DMIC/AMIC selector -- NOT ZERO, which wedges TX)
#   DMIC MUX0 = DMIC0    (which digital mic input)
#   DEC0 Volume = 104    (+20 dB capture gain; raw 0 = -84 dB, 84 = 0 dB)
#
# and CapturePCM hw:<card>,1, which is MultiMedia2 -> SLIMBUS_0_TX.
#
# After installing, restart the session audio so the new section is picked up:
#
#   systemctl --user restart wireplumber pipewire pipewire-pulse
#
# Then `wpctl status` should list "Internal Microphone" and
#
#   pw-record --target "Internal Microphone" /tmp/test.wav
#
# should capture you.

set -eu

[ "$(id -u)" = 0 ] || { echo "run me with sudo" >&2; exit 1; }

here=$(cd "$(dirname "$0")/.." && pwd)
ucmdir=/usr/share/alsa/ucm2/Qualcomm/xiaomi-book-12.4
confdir=/usr/share/alsa/ucm2/conf.d/sdm845
confname=TIMI-XiaomiBook12.4-INVALID-TM2133.conf
stamp=$(date +%Y%m%d-%H%M%S)

for f in "${here}/ucm2/Qualcomm/xiaomi-book-12.4/HiFi.conf" \
         "${here}/ucm2/conf.d/sdm845/${confname}"; do
	[ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
done

echo "== backing up and installing =="
for pair in \
	"${here}/ucm2/Qualcomm/xiaomi-book-12.4/HiFi.conf:${ucmdir}/HiFi.conf" \
	"${here}/ucm2/conf.d/sdm845/${confname}:${confdir}/${confname}"
do
	src=${pair%%:*}
	dst=${pair##*:}
	if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
		cp -a "$dst" "${dst}.bak-${stamp}"
		echo "   backed up $dst -> ${dst}.bak-${stamp}"
	fi
	install -Dm644 "$src" "$dst"
	echo "   installed $dst"
done

# The card has to be down for a new UCM section to be re-read.
echo
echo "== restarting the session audio =="
if [ -n "${SUDO_USER:-}" ] && [ -d "/run/user/$(id -u "$SUDO_USER")" ]; then
	uid=$(id -u "$SUDO_USER")
	if runuser -u "$SUDO_USER" -- env XDG_RUNTIME_DIR="/run/user/$uid" \
			systemctl --user restart wireplumber pipewire pipewire-pulse 2>/dev/null
	then
		echo "   restarted wireplumber/pipewire for $SUDO_USER"
	else
		echo "   automatic restart failed; as $SUDO_USER run:" >&2
		echo "     systemctl --user restart wireplumber pipewire pipewire-pulse" >&2
	fi
else
	echo "   as your desktop user run:"
	echo "     systemctl --user restart wireplumber pipewire pipewire-pulse"
fi

cat <<'EOF'

== verify ==

  wpctl status | grep -i -A2 "internal"
  # or list the UCM devices for this card:
  alsaucm -c hw:0 list _devices HiFi

  # capture through the new profile (bypasses the hw:0,1 path used in testing):
  pw-record --target "Internal Microphone" /tmp/mic-test.wav
  pw-play /tmp/mic-test.wav

If it does not appear, check for a parse error:

  journalctl --user -u wireplumber --since "-2min" | grep -i ucm

Undo:

  for f in /usr/share/alsa/ucm2/Qualcomm/xiaomi-book-12.4/HiFi.conf \
           /usr/share/alsa/ucm2/conf.d/sdm845/TIMI-XiaomiBook12.4-INVALID-TM2133.conf; do
      [ -e "$f".bak-* ] && sudo cp -a "$(ls -1t "$f".bak-* | head -1)" "$f"
  done
  systemctl --user restart wireplumber pipewire pipewire-pulse
EOF
