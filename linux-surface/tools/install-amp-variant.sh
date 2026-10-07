#!/bin/sh
# Switch the WSA881x amplifier module variant.  Run with sudo.
#
#   sudo tools/install-amp-variant.sh orig     # stock driver, no local patches
#   sudo tools/install-amp-variant.sh gain     # + keep the user PA gain (default)
#   sudo tools/install-amp-variant.sh h1a      # + never power-cycle the amp
#
# Why this exists: the amplifiers are power-cycled by runtime PM
# (wsa881x_runtime_suspend() asserts SD_N), which takes them off the SoundWire
# bus while the master is still running.  That is what pops, and occasionally
# the re-attach race loses outright -- the amp ends up stuck:
#
#   wsa881x-codec sdw:...:4: Initialization not complete, timed out
#   wsa881x-codec sdw:...:4: ASoC error (-110) at ...pm_runtime_get()
#   SLIM Playback:            ASoC error (-110) at __soc_pcm_open()
#
# and then no PCM can be opened at all, so there is no sound anywhere.
# `h1a` removes that failure mode by never cutting the amp's power; the cost is
# roughly 10-30 mW of idle power per amplifier.
#
# The variants:
#   orig  tools/orig-snd-soc-wsa881x.ko   stock 6.18.2 driver
#   gain  src/kernel/.../snd-soc-wsa881x.ko
#         keeps "SpkrLeft/Right PA Volume" across DAPM power-up, so the UCM's
#         +18 dB sticks instead of being rewritten to +12 dB.  Adds one bus
#         access at PRE_PMU, which the SoundWire analysis calls an aggravator
#         of the power-up race above.
#   h1a   tools/h1a-snd-soc-wsa881x.ko
#         `gain` plus: wsa881x_runtime_suspend() no longer asserts SD_N.
#
# The prebuilt variants are per-kernel objects: a .ko carries BTF that the
# loader validates against the running kernel, so they must be rebuilt whenever
# the kernel is (tools/build-amp-variant.sh).  This refuses to install a
# prebuilt module that does not match.
set -eu

[ "$(id -u)" = 0 ] || { echo "run me with sudo" >&2; exit 1; }

here=$(cd "$(dirname "$0")/.." && pwd)
kernver=$(uname -r)
dest="/usr/lib/modules/${kernver}/kernel/sound/soc/codecs/snd-soc-wsa881x.ko"

# A stale module keeps a matching vermagic and modinfo, so nothing looks wrong
# until the loader rejects it:
#
#   failed to validate module [snd_soc_wsa881x] BTF: -22
#
# and then the machine boots with no sound card at all -- both WSA881x
# components fail to register, so snd_soc_sdm845 cannot build the card.  That
# is what happened on 2026-10-07: the 10-05 prebuilts met a kernel rebuilt
# in between.  /sys/kernel/btf/vmlinux is the exact table the loader checks
# against, so build-amp-variant.sh records its hash and this compares.
check_prebuilt_btf() {
	stamp="${here}/tools/.amp-variant-btf"
	now=$(sha256sum /sys/kernel/btf/vmlinux 2>/dev/null | awk '{print $1}')
	want=$(awk '/^btf /{print $2}' "$stamp" 2>/dev/null || true)

	[ -n "$now" ] && [ "$want" = "$now" ] && return 0

	cat >&2 <<EOF
refusing to install the prebuilt '$1' module: it does not match this kernel.

    running kernel BTF : ${now:-unreadable}
    module built for   : ${want:-unknown}
    stamp              : ${stamp}

It would fail to load with "failed to validate module [...] BTF: -22" and
leave the machine with no sound card.  Rebuild the variants for the running
kernel first (as your normal user, NOT with sudo):

    tools/build-amp-variant.sh

or use the tree's own build, which always matches:

    sudo tools/install-amp-variant.sh gain

Set AMP_VARIANT_FORCE=1 to install anyway.
EOF
	[ "${AMP_VARIANT_FORCE:-0}" = 1 ] || exit 3
	echo "AMP_VARIANT_FORCE=1 set: installing the mismatched module anyway" >&2
}

case "${1:-gain}" in
orig) check_prebuilt_btf orig; src="${here}/tools/orig-snd-soc-wsa881x.ko" ;;
gain) src="${here}/src/kernel/sound/soc/codecs/snd-soc-wsa881x.ko" ;;
h1a)  check_prebuilt_btf h1a; src="${here}/tools/h1a-snd-soc-wsa881x.ko" ;;
*) echo "usage: $0 [orig|gain|h1a]" >&2; exit 2 ;;
esac

[ -f "$src" ] || { echo "missing $src" >&2; exit 1; }

printf 'variant %-5s : %s\n' "$1" "$src"
printf '  spkr_pa_event = %s (0188=stock, 01e4=keeps the PA gain)\n' \
	"$(nm -S --size-sort "$src" | grep wsa881x_spkr_pa_event | awk '{print $2}')"

install -Dm644 "$src" "$dest"
depmod -a "$kernver"
echo "installed -> $dest"
echo "reboot to activate"
