#!/bin/bash
# Rebuild the WSA881x amplifier variants against the tree that built the
# running kernel.  Run as your NORMAL user, not with sudo (it writes into the
# kernel tree, and building as root would leave root-owned objects behind).
#
#   tools/build-amp-variant.sh [kernel-tree]
#
# Writes:
#   tools/orig-snd-soc-wsa881x.ko   stock driver
#   tools/h1a-snd-soc-wsa881x.ko    PA gain kept + SD_N never asserted
#   tools/.amp-variant-btf          stamp checked by install-amp-variant.sh
#
# and leaves the tree - including its own snd-soc-wsa881x.ko, the "gain" build
# that the kernel package ships - exactly as it found it.
#
# Why a rebuild is not optional.  A .ko is only valid for the kernel whose BTF
# it was generated against, and BTF is validated *at load time* against the
# running kernel's table (/sys/kernel/btf/vmlinux).  A module from an older
# build still has a matching vermagic and modinfo, so nothing looks wrong -
# and then the kernel says
#
#   failed to validate module [snd_soc_wsa881x] BTF: -22
#
# and the machine boots with no sound card at all, because the two WSA881x
# components never register and snd_soc_sdm845 cannot build the card.  That is
# exactly what the shipped prebuilt tools/*.ko did on 2026-10-07 (built
# 2026-10-05, kernel #21; the running kernel was #35 with sched_ext/uclamp/
# DEBUG_INFO_BTF config changes in between).
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
K="${1:-${here}/src/kernel}"
SRC="$K/sound/soc/codecs/wsa881x.c"
KO="$K/sound/soc/codecs/snd-soc-wsa881x.ko"
GAIN_PATCH=cecbd35ca830		# "ASoC: wsa881x: keep the user PA gain ..."
NPROC=$(nproc)

[ "$(id -u)" != 0 ] || { echo "run me as your normal user, not with sudo" >&2; exit 1; }
[ -d "$K" ] || { echo "no kernel tree at $K" >&2; exit 1; }
[ -f "$K/vmlinux" ] || { echo "$K is not built (no vmlinux)" >&2; exit 1; }
[ -f "$SRC" ] || { echo "no $SRC" >&2; exit 1; }

if ! git -C "$K" diff --quiet -- sound/soc/codecs/wsa881x.c; then
	echo "sound/soc/codecs/wsa881x.c has local changes; commit or stash them first" >&2
	exit 1
fi
git -C "$K" cat-file -e "${GAIN_PATCH}^{commit}" 2>/dev/null || {
	echo "commit $GAIN_PATCH is missing from $K; cannot derive the stock variant" >&2
	exit 1
}

backup=$(mktemp /tmp/wsa881x.c.XXXXXX)
trap 'cp -f "$backup" "$SRC"' EXIT

build() {
	# The whole-modules pass is deliberate: the single-module target
	# (make <path>.ko) runs modpost without the sibling symbols and fails.
	make -s -C "$K" ARCH=arm64 -j"$NPROC" modules >/dev/null
	[ -f "$KO" ] || { echo "build produced no $KO" >&2; exit 1; }
}

stage() {
	install -Dm644 "$KO" "$1"
	strip --strip-debug "$1"
	readelf -S "$1" | grep -q '\.BTF ' || {
		echo "!! $1 lost its .BTF section; the kernel would reject it" >&2
		exit 1
	}
	printf '   %-30s %s\n' "$(basename "$1")" \
		"$(nm -S --size-sort "$1" |
			grep -E 'wsa881x_runtime_suspend|wsa881x_spkr_pa_event' |
			awk '{printf "%s=%s ", $4, $2}')"
}

cp -f "$SRC" "$backup"

echo "== orig (stock; the local PA-gain patch is reverted)"
git -C "$K" show "$GAIN_PATCH" -- sound/soc/codecs/wsa881x.c | git -C "$K" apply -R
build
stage "${here}/tools/orig-snd-soc-wsa881x.ko"

echo "== h1a (gain kept, wsa881x_runtime_suspend() no longer asserts SD_N)"
cp -f "$backup" "$SRC"
python3 - "$SRC" <<'PY'
import sys

path = sys.argv[1]
src = open(path).read()

old = """static int wsa881x_runtime_suspend(struct device *dev)
{
\tstruct regmap *regmap = dev_get_regmap(dev, NULL);
\tstruct wsa881x_priv *wsa881x = dev_get_drvdata(dev);

\tgpiod_direction_output(wsa881x->sd_n, wsa881x->sd_n_val);

\tregcache_cache_only(regmap, true);"""

new = """static int wsa881x_runtime_suspend(struct device *dev)
{
\tstruct regmap *regmap = dev_get_regmap(dev, NULL);

\t/*
\t * Local (Xiaomi Book 12.4): deliberately do NOT assert SD_N here.
\t * Cutting the amplifier's power while the SoundWire master keeps
\t * running takes it off the bus mid-flight; it then pops on the way
\t * down, sometimes loses the re-attach race on the way up, and after a
\t * failed port programming it can be left powered with no stream to
\t * decode.  Keeping it enabled costs roughly 10-30 mW per amplifier.
\t */
\tregcache_cache_only(regmap, true);"""

if src.count(old) != 1:
    sys.exit("h1a edit: expected exactly one runtime_suspend body, found %d"
             % src.count(old))

open(path, "w").write(src.replace(old, new))
PY
build
stage "${here}/tools/h1a-snd-soc-wsa881x.ko"

echo "== restoring the tree (gain build)"
cp -f "$backup" "$SRC"
build
trap - EXIT
rm -f "$backup"

sha256sum /sys/kernel/btf/vmlinux |
	awk -v r="$(uname -r)" '{printf "btf %s\nkernel %s\n", $1, r}' \
	> "${here}/tools/.amp-variant-btf"
echo "== stamped tools/.amp-variant-btf"
cat "${here}/tools/.amp-variant-btf"
echo
echo "now:  sudo tools/install-amp-variant.sh orig     # or h1a"
