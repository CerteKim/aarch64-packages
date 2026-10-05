# `vendor-ref/` — the CodeLinaro sdmshrike (SC8180X) vendor tree

Reference material for the VPU (`venus` / `iris`) bring-up, extracted from
Qualcomm's public downstream tree.  Nothing here is compiled or shipped; the
files exist so that the excerpt in `HARDWARE-STATUS.md` can be re-checked
without network access.

| item | value |
| --- | --- |
| repo | <https://git.codelinaro.org/clo/la/kernel/msm-4.14> |
| branch | `auto-kernel.lnx.4.14.c34` |
| commit read | `9366ea378de5bec62ef449f31aad85be573a1e50` (2025-04-10) |
| SoC name | `sdmshrike` — Qualcomm's name for SC8180X, this laptop's SoC |
| video driver | `drivers/media/platform/msm/vidc` (`msm_vidc`, downstream) |
| kernel | 4.14, so *none* of it is portable code; the DTS and the register
  map are the useful parts |

## Files

* `sdmshrike-vidc.dtsi` — verbatim.  The SoC's video node: register window,
  interrupt, six clocks, four resets, GDSCs, the four SMMU context banks and
  their SIDs.
* `vidc_hfi_io.h` — verbatim.  The register map (`VBIF 0x80000`, `CPU 0xC0000`,
  `CPU_CS 0xD2000`, `WRAPPER 0xE0000`), the wrapper interrupt registers, the
  VBIF AXI-halt handshake and the NoC error offsets.
* `sdmshrike-pil-venus.dtsi` — trimmed excerpts, with sources noted in the
  header: the `qcom,venus@aae0000` `qcom,pil-tz-generic` node (PAS id, clocks,
  firmware region), the `pil_video_mem` carve-out, the `-v2` VIDEOCC node, the
  `vpu4`/`vpu5` interrupt-mask difference and the vendor PAS call sequence.
* `fetch-sdmshrike-ref.sh` — recreates the sparse clone the excerpts came
  from (blobless, shallow, ~30 MB, default `~/vpu-ref/msm-4.14`).

## Why this tree and not SM8150/`nabu`

The sixth round used the Xiaomi Pad 5 (`nabu`, SM8150) vendor tree because it
is the same silicon generation.  This tree is better in one specific way: it
is the **same SoC**, so its device tree is not a hypothesis.  It is worse in
another: 4.14 versus 4.19 for `nabu`, and it contains only the downstream
`msm_vidc` driver, never `iris`.

The two references agree on everything they both cover; where they differ, the
sdmshrike one is authoritative for this board.  See the "Seventh round"
section of `HARDWARE-STATUS.md` for what it confirms and what it changes.
