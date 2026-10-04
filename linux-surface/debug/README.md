# debug/ — archived debug utilities

One-off debug helpers and superseded installers, moved here out of the repo root
and `tools/` so the top level reflects the live build/install path.

**Archived does not mean obsolete.** Several of these relate to subsystems that
are still open (backlight PWM, rotation, microphones). Nothing here is wired into
`PKGBUILD`, the systemd units, or any other script — every file was checked for
references before it was moved. The history was preserved with `git mv`, so
`git log --follow debug/<file>` still works.

## The live path (what stayed in `tools/`)

These are still referenced and deliberately were **not** moved:

| file | why it stays |
| --- | --- |
| `tools/probe-vdec-run.sh` | cited at `PKGBUILD:118` |
| `tools/make-kernel-package.sh` | the package build |
| `tools/recover-working.sh` | recovery path  |
| `tools/gpu-oc-check.sh`, `tools/hive-dump.py` | cited in `HARDWARE-STATUS.md` |
| `tools/repack-venus-firmware.py`, `tools/suspend-test.sh`, `tools/update-probe-dtb.sh` | cited in `HARDWARE-STATUS.md` |

`systemd/bluetooth-bdaddr.sh` also stayed: it is installed to
`/usr/local/bin` by `systemd/bluetooth-bdaddr.service`.

## Archived files

### Video decode / IRIS1 (VPU) — work parked

`HARDWARE-STATUS.md:1344` marks this round's hooks "all temporary; revert before
any upstream submission". The kernel-side hooks (`fw_phys`, `pas_id`, `no_auth`,
`scan_pas`, `skip_pas_mem_setup`, the `IRIS-TRACE:` breadcrumbs) are already gone
from both `kernel/` and `src/kernel/`. These are their userspace counterparts.

| file | was | what it does |
| --- | --- | --- |
| `videocc-peek.py` | `tools/videocc-peek.py` | `/dev/mem` view of VIDEOCC/GCC (`dump`, `powerup`, `gdsc-test`, `scan`). The `scan` and VPU-read modes are **not** safe — an unmapped read can take the machine down. |
| `iris-trace.patch` | `tools/iris-trace.patch` | `IRIS-TRACE:` breadcrumbs across iris core / resources / vpu_common / firmware. Version-pinned; will not apply to a moved tree. |
| `iris-skip-preset.patch` | `tools/iris-skip-preset.patch` | Skips the `iris_set_sm8250_preset_registers` write to `0xB0088`, suspected to not exist in the SC8180X IRIS1 wrapper where it stalls the bus. |
| `apply-videocc-fix.sh` | `tools/apply-videocc-fix.sh` | Sync a freshly built kernel/modules/DTB/initramfs to the live system. |
| `install-iris-firmware.sh` | `tools/install-iris-firmware.sh` | Install the `qcom/sc8180x/venus.mbn` staged from the Windows install (see `firmware/qcom/sc8180x/README.md`). |
| `install-vdec-poc.sh` | `tools/install-vdec-poc.sh` | **Deprecated in its own header** — superseded by `tools/probe-vdec-run.sh`. Its package set (pkgrel ≤ 6) ships no kernel image, so installing one left `/boot` stale and every module failed BTF validation. |
| `restore-pre-vdec.sh` | `tools/restore-pre-vdec.sh` | Restore the pre-PoC `/boot` files from `~/vdec-poc-fallback`. Depends on that directory still existing. |

### Installers superseded by the tree they install into

| file | was | what it does |
| --- | --- | --- |
| `install-bluetooth-bdaddr.sh` | `tools/install-bluetooth-bdaddr.sh` | Install the WCN3998 BD-address oneshot. Superseded by the device tree `local-bd-address` (see `HARDWARE-STATUS.md`), and the unit is committed under `systemd/`. |
| `refresh-boot-from-tree.sh` | `tools/refresh-boot-from-tree.sh` | Refresh `/boot` from the built tree by hand. `tools/make-kernel-package.sh` plus the package install does this now. Hard-codes the `src/kernel` path. |

### Verifiers

Each hard-codes the `src/kernel` / `linux-surface` paths and was written against
one investigation. Kept because the questions they ask are not all closed.

| file | was | what it checks |
| --- | --- | --- |
| `verify-backlight.sh` | `verify-backlight.sh` | Capture PMC8180C backlight hardware state. The panel lights but the `backlight` sysfs node has no visible effect, including at 0. |
| `verify-backlight-pwm.sh` | `verify-backlight-pwm.sh` | Whether LPG channel 5 (`0xbd00`) PWM is what actually drives the backlight — the prime suspect from the `backlight-diag/` register dump. |
| `verify-mainline-panel.sh` | `verify-mainline-panel.sh` | That the HX83121A panel port came up and the driver bound. Run after installing a new kernel. |
| `verify-rotation.sh` | `verify-rotation.sh` | Auto-rotation after a GNOME Shell reload. Needs the `mutter#4931` inhibit recipe first (see `HARDWARE-STATUS.md`). |
| `xiaomi-book-12.4-mic-scan.sh` | `xiaomi-book-12.4-mic-scan.sh` | Which WCD9340 input the microphones are on. Capture works end to end, but the DTS-selected `AMIC2` only returns a constant noise floor. Its sibling `xiaomi-book-12.4-mic-tap-test.sh` stayed at the root because `HARDWARE-STATUS.md` cites it. |

## Note for future edits

`HARDWARE-STATUS.md` cites files by **filename**, so moving things here can
leave stale references. This move updated the four that existed:
`HARDWARE-STATUS.md` (two `videocc-peek.py` mentions),
`install-mainline-panel.sh` (`refresh-boot-from-tree.sh` and
`verify-mainline-panel.sh`) and `set-panel-link-mode.sh`
(`refresh-boot-from-tree.sh`). Check again on any later move.
