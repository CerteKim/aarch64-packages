#!/usr/bin/env bash
# Re-create the sparse checkout of the CodeLinaro sdmshrike (SC8180X) vendor
# tree that this directory's excerpts were taken from.
#
#   ./vendor-ref/fetch-sdmshrike-ref.sh [target-dir]
#
# The clone is blobless and shallow (one commit, tree objects only) and then
# narrowed with sparse-checkout, so it is ~30 MB instead of a full kernel.
# Blobs are fetched on demand, so the first `git show`/grep of a new path
# needs network access.
set -euo pipefail

REF_BRANCH="auto-kernel.lnx.4.14.c34"
REF_COMMIT="9366ea378de5bec62ef449f31aad85be573a1e50"
URL="https://git.codelinaro.org/clo/la/kernel/msm-4.14.git"
DEST="${1:-$HOME/vpu-ref/msm-4.14}"

if [ -e "$DEST" ]; then
	echo "refusing to touch existing $DEST" >&2
	exit 1
fi

mkdir -p "$(dirname "$DEST")"

git clone --filter=blob:none --no-checkout --depth=1 \
	--branch "$REF_BRANCH" "$URL" "$DEST"

cd "$DEST"
git sparse-checkout init --cone
git sparse-checkout set \
	drivers/media/platform/msm/vidc \
	drivers/soc/qcom \
	drivers/clk/qcom \
	include/dt-bindings/clock \
	arch/arm64/boot/dts/qcom
git checkout

have="$(git rev-parse HEAD)"
if [ "$have" != "$REF_COMMIT" ]; then
	echo "warning: branch tip is $have, excerpts were taken from $REF_COMMIT" >&2
fi
echo
echo "ready: $DEST"
echo "  arch/arm64/boot/dts/qcom/sdmshrike-vidc.dtsi"
echo "  arch/arm64/boot/dts/qcom/sdmshrike.dtsi        (pil_venus, PIL regions)"
echo "  drivers/media/platform/msm/vidc/               (msm_vidc, vidc_hfi_io.h)"
echo "  drivers/soc/qcom/subsys-pil-tz.c               (PAS sequence)"
echo "  drivers/clk/qcom/videocc-sm8150.c              (VIDEOCC + iris_ahb, v2 fixup)"
