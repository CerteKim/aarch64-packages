# 基于 Linux 7.2 制作补丁的可行性评估

日期：2026-10-07
对象：本仓库 `kernel` 镜像里 `xiaomi-mainline-panel2` 分支（当前打包基线 `linux-mibook`
6.18.2，tip `07050c50`）相对上游的全部改动，评估其能否改以 **Linux 7.2** 为基线重新做成一套补丁。

## 结论

**可行，但不是"重新打一遍"的量级。** 55 个提交 / 48 个文件（+4309 −199）里：

| 类别 | 规模 | 处理方式 |
|---|---|---|
| 7.2 上游已收编，或本地 hack 已被上游机制取代 | 8 组、约 12 个文件 | 从补丁序列中直接删除 |
| 只涉及"能干净套用"文件的提交 | 55 个中的 34 个 | 直接 rebase / cherry-pick |
| 有真实语义冲突，需要手工移植 | 20 个文件 | 逐个改，见下表 |
| 上游 7.2 已删除的文件 | 2 个 | 重写或放弃 |
| VPU / iris 视频整组 | 13 文件、约 925 行 | 建议不移植（上游大重构 + 本机被 TZ 卡住） |

实测（把本地终态 diff 逐文件 `git apply --3way` 到 v7.2）：

* 48 个文件：**26 干净 / 20 冲突 / 2 上游已删除**
* 55 个提交：**34 个只碰干净文件 / 21 个至少碰一个冲突文件**

整理后的 7.2 序列预计 **约 20–25 个补丁、约 2600–3000 行**（其中 1843 行是设备树），
工作量估计 **3–5 人日**，之后需一轮完整构建（本机 8 核，全量约 1–2 小时）和上机验证。

## 基线事实

| 项目 | 值 |
|---|---|
| 上游 6.18 基点 | `7d0a66e4bb90`（Linux 6.18），树内含 6.18.1/6.18.2 |
| surface 基点 | `ef9de32e3deb`（surface 栈最后一个提交） |
| 本板补丁起点 | `1d30d9d1edda` “Patch for Xiaomi Book S 12.4 (a51)”（1 个压扁的大提交） |
| 本板 tip | `07050c5050af`（xiaomi-mainline-panel2），`1d30d9d1edda` 之后另有 54 个提交 |
| 本地增量 | 55 提交 / 48 文件 / +4309 −199 |
| Linux 7.2 | tag `v7.2`，commit `8d3ae59288f1`，2026-08-16；6.18→7.2 之间 66 387 个提交 |
| 当前上游最新 | v7.3-rc6 |
| linux-surface 内核仓库 | 最新只到 `v6.19-surface(-devel)`，**没有 7.x 分支** |

## 7.2 已经收编 / 已被取代（应从补丁里删掉）

| 本地改动 | 7.2 上游 | 说明 |
|---|---|---|
| `panel-himax-hx83121a.c` 驱动本体、binding 本体、panel Kconfig 条目 | `a7c61963b727`、`9f96a50d61ec` | 驱动和 DT binding 已进 7.2，注释里甚至写了 “CSOT PNC357DB1-4: on MI Book S 12.4”；只剩 PNC 描述符等增量（见下） |
| `Bluetooth: qca: fix ROM version reading on WCN3998`（`73c9902589b2`） | `99b2c531e0e7` | 完全重复 |
| `sdhci-msm` HS400 时钟倍频改动 | `b1f856b1727c` | 7.2 函数签名与本地改法一致 |
| `a6xx_gpu.c` 里 `ifpc_reglist` 的 NULL 保护 | 已在 7.2 | 本地那段已多余 |
| `a6xx_preempt.c` 把 `preempt_prepare_postamble()` 移到 `IS_ERR` 之后 | 已在 7.2 | 完全重复 |
| `phy-qcom-qmp-usb.c` 的 `sc8180x-qmp-usb3-uni-phy` 条目（+3） | 已在 7.2 | 本地这处还是**重复条目**（树里出现两次），应直接删 |
| `drivers/base/dd.c` 的 `fw_devlink_timeout` hack（+39 −2） | `CONFIG_DRIVER_DEFERRED_PROBE_TIMEOUT`（driver-core 7.2-rc1） | 用配置即可：负值 = 无限等待，本板需要的行为可由 config/cmdline 表达 |
| panel Kconfig 的 DSC helper select（`copilot/fix-missing-dsc-select-statements`） | 已在 7.2 | 上游条目已 `select DRM_DISPLAY_DSC_HELPER` |

（`Documentation/.../mmc/sdhci-msm.yaml` 里的 `+qcom,sc8180x-sdhci` **仍然需要**：该 binding 被
`94044acc20cd` 改名为 `qcom,sdhci-msm.yaml`，而 7.2 的新文件里还没有 sc8180x，重新应用到新路径即可。）

## 需要移植的清单（真实冲突）

| 文件 | 本地改动 | 冲突原因 | 难度 |
|---|---|---|---|
| `arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4.dts` | 新增板级 DTS（~838 行） | 新文件，**干净套用** | 低（注意与 7.2 新节点/属性的对齐） |
| `sc8180x.dtsi`、`sc8180x-pmics.dtsi`、`dts/Makefile` | SLPI/FastRPC/视频 OPP/PON RESIN/按键/sdhc_2 | 干净套用（上游 6 次改动未撞行） | 低 |
| `Documentation/.../mmc/qcom,sdhci-msm.yaml` | 补 `qcom,sc8180x-sdhci`（+1） | 旧路径 `sdhci-msm.yaml` 被改名 | 低（驱动靠 `qcom,sdhci-msm-v5` 通用匹配，不需驱动补丁） |
| `panel-himax-hx83121a.c` | 相对 7.2 仅 +199 −21：`csot,pnc357db1-4` 描述符、per-panel 稳压器、`enable-gpios`、单链路 fallback | 线路被上游驱动改写 | 中（须以上游 7.2 驱动为基重排；本地这版基于 10 月主线，可能已含 7.3 内容） |
| `himax,hx83121a.yaml` | 相对 7.2 仅 +10 行（compatible + 三个 supply） | 同上 | 低 |
| `drivers/soundwire/qcom.c` | AHB 串行化、FIFO 失败关闭、重试、IRQ 有界（+184 −53） | 7.2 重构过该文件（`kmalloc_obj`、guard、v3.1.0、弃用 `qcom,din/out-ports`、删 `rd_fifo_depth`） | **高**（语义不冲突，但要按新结构重排） |
| `sound/soc/qcom/sdm845.c` | Xiaomi Book 12.4 声卡（+134） | 干净套用 | 低 |
| `sound/soc/codecs/wsa881x.c`、`wcd934x.c` | PA 增益跨 DAPM、RX 音量上限（+25/+63） | 干净套用 | 低 |
| `drivers/slimbus/qcom-ngd-ctrl.c` | 后续 capability 消息里解析从机地址（+9 −2） | 干净套用（上游 14 次改动未撞） | 低 |
| `dpu_encoder.c` | 单接口单 slice 用 1 个 DSC（+5） | 7.2 仍是旧逻辑，**上游没有** | 低（可上游化） |
| `dsi_host.c` | 视频模式下禁用 wide bus（+7） | 7.2 仍是旧逻辑 | 低（属 workaround，需决定是否上游） |
| `a6xx_catalog.c` / `a6xx_gpu.c` | a680 SQE/GMU 固件名 + ucode 检查 | 7.2 仍是 `a630_sqe.fw`/`a640_gmu.bin` | 低（可上游化） |
| `videocc-sm8150.c` | 匹配 `qcom,sc8180x-videocc`（+9） | 7.2 仍只匹配 sm8150 | 低（可上游化） |
| `gcc-sc8180x.c` | 4 个 PCIe GDSC 加 `ALWAYS_ON`（+8 −4） | 上游 7 次改动 | 中（hack，需要理由或换做法） |
| `qcom_q6v5_pas.c` | 增加 `qcom,sc8180x-slpi-pas`（+1） | 匹配表被大量新 SoC 挤动 | 低 |
| `mdt_loader.c` | `skip_pas_mem_setup` **DEBUG module_param**（+13） | 上游 5 次改动 | 中（临时 hack，需要正规设计） |
| `firmware/qcom/qcom_scm.c` + 头文件 | VPU/SCM 调试调用（+45/+4） | 干净套用，但属 iris 组 | 随 iris 一起决定 |
| `firmware/efi/efi.c` | 屏蔽 `EFI_RT_SUPPORTED_RESET_SYSTEM`（+2） | 7.2 该函数改名重组（`efipostcore_init`） | 中；**本地那两行还缺大括号，实际无条件执行**，重写时修掉 |
| `tools/lib/bpf/libbpf.c` | `strstr/strchr` 结果加 `(char *)`（+3 −3） | 7.2 **尚未**修，仍然需要 | 低 |
| `iris/*`（13 文件） | SC8180X VPU bring-up | 7.2 删掉 `iris_platform_sm8250.c`，平台文件拆成 vpu2/vpu3x，寄存器与 HFI 层全改 | 高，且硬件受 TZ/VTL1 阻塞 → **建议不移植** |

另外，54 个提交里有明显的实验/回滚噪声，直接 rebase 会把它们带过去，需要先压平：

* 面板：`790c63d4`（backport）→ `47790266`（port）→ `2ac0befd`（再 port 主线驱动）→ `37331be5`（去调试）→ `28db32ca`/`cb8e5e30`
* DTB：`f52de895`/`fcfb9543`/`59d85eaf`/`e7f42460` 四步“加回又删掉 oc 变体”
* DSI/DPU 调试：`831dbeb5`、`69f9e095`、`9edde735`、`d922ebd1`、`aa89e681`、`fa026674`（fix build）
* 音频：`ff4dc28f` → `3ba6fcba`（revert）→ `e7ca7608` → `57de82c7` → `430e0dbd`

## 建议的 7.2 补丁序列（草案）

1. `arm64: dts: qcom: sc8180x-pmics.dtsi: add PON RESIN`
2. `arm64: dts: qcom: sc8180x: add SLPI remoteproc`（+ FastRPC，可拆两条）
3. `arm64: dts: qcom: sc8180x: video codec OPPs`（依赖 10；video 驱动本身不移植）
4. `arm64: dts: qcom: add Xiaomi Book S 12.4 (a51)`
5. `dt-bindings: mmc: qcom,sdhci-msm: add qcom,sc8180x-sdhci`
6. `dt-bindings: display: panel: himax,hx83121a: add csot,pnc357db1-4`（基于 7.2 上游 binding）
7. `drm/panel: himax-hx83121a: support the CSOT PNC357DB1-4`（相对 7.2 约 +199）
8. `drm/msm/dpu: one DSC block for single-interface single-slice topologies`
9. `drm/msm/dsi: keep wide bus off in video mode`（workaround）
10. `clk: qcom: videocc-sm8150: match qcom,sc8180x-videocc`
11. `clk: qcom: gcc-sc8180x: keep PCIe GDSCs always-on`（需先论证）
12. `remoteproc: qcom_q6v5_pas: add sc8180x SLPI PAS`
13. `soc: qcom: mdt_loader: …`（把 DEBUG module_param 正规化，或确认可以不要）
14. `soundwire: qcom: harden the AHB bridge, FIFO handling and IRQ path`
15. `ASoC: qcom: sdm845: add the Xiaomi Book 12.4 sound card`
16. `ASoC: codecs: wsa881x: keep the user PA gain across DAPM power-up`
17. `ASoC: codecs: wcd934x: cap the RX volumes`
18. `slimbus: qcom-ngd-ctrl: resolve slave addresses on later capability messages`
19. `drm/msm/adreno: a680 firmware names and ucode check`
20. `tools/lib/bpf: cast string-search results`（或等上游修）
21. `firmware: efi: mask the broken ResetSystem runtime service`（重写，去掉无条件执行）

删除：iris 全组（9–13 个提交）、btqca、`drivers/mmc/host/sdhci-msm.c` 的时钟改动、phy、
a6xx 两处修复、`dd.c`、panel/Kconfig 基底（binding 里那 1 行保留，见第 5 条）。

## 打包与配置层面

* `xiaomi-only.config` 的 540 个符号里，7.2 已无 Kconfig 定义的共 4 个：
  `DRM_DP_AUX_BUS`、`SPI_HID`（7.2 移除/改名），`RTC_DRV_SURFACE`、`UCSI_GLINK`（surface 补丁栈提供）。
  `merge_config.sh` + `olddefconfig` 只是静默丢弃，需要顺手清掉。
* `PKGBUILD` 现在把 `pkgver` 钉在 6.18.2、`_ref_ksource` 钉在 `07050c50`，且 `pkgrel` 刻意保持 1
  以维持 `6.18.2-1-mibook+` 的模块 ABI。换 7.2 就要新分支/新 commit、`pkgver=7.2`、
  `pkgrel` 重开，并且 `-headers`、BTF、`resolve_btfids` 都要重出一遍。
* 若坚持"整包 = linux-surface 栈 + 本板补丁"，7.2 没有可跟的 surface 基线（最新 v6.19-surface-devel），
  这一层要自己维护；对本板而言 surface 补丁大多无关，**vanilla 7.2 + 本套补丁**更省事。
* 若目标是"少维护"，6.19 是比 7.2 更现实的目标（surface 栈现成）；7.2 的价值在于面板驱动已上游。

## 复现方式

```bash
cd kernel
git fetch --no-tags https://github.com/torvalds/linux.git refs/tags/v7.2:refs/tags/upstream-v7.2
git worktree add --detach ../.scratch/wt72 upstream-v7.2
git diff ef9de32e3deb xiaomi-mainline-panel2 > ../.scratch/xiaomi-delta.patch

# 逐文件试应用（结果见 ../.scratch/perfile72.txt）
cd ../.scratch/wt72
for f in $(git -C ../../kernel diff --name-only ef9de32e3deb xiaomi-mainline-panel2); do
  git -C ../../kernel diff ef9de32e3deb xiaomi-mainline-panel2 -- "$f" > ../one.patch
  git apply --3way --whitespace=nowarn ../one.patch && echo "CLEAN $f" || echo "CONFLICT $f"
  git reset --hard upstream-v7.2 -q
done
```

## 本次评估留下的工件

| 路径 | 内容 |
|---|---|
| `kernel/.git` 中的 tag `upstream-v7.2` | 指向 `8d3ae59288f1`（Linux 7.2），只加了对象和 tag，未改分支 |
| `.scratch/wt72/` | v7.2 的 worktree（约 2 GB），可直接用来做移植 |
| `.scratch/xiaomi-delta.patch` | 本地全部增量的压扁补丁（5886 行） |
| `.scratch/perfile72.txt` | 48 个文件逐个套用 7.2 的结果 |
| `.scratch/commit-risk.txt` | 55 个提交逐个的 CLEAN/CONFLICT 判定 |
| `.scratch/conflict-files.txt`、`kconfig-syms72.txt` | 冲突文件表、7.2 的 Kconfig 符号表 |

## 下一步（择一）

1. **按上面的草案实际生成 7.2 补丁序列**（20 个补丁左右），先在 v7.2 worktree 里把
   第 1–9、13–18 条做完，构建通过为止；
2. 只做 **DT + 面板 + 音频** 的最小可用子集（对日常使用影响最大，冲突最少）；
3. 改目标为 **6.19-surface-devel**（沿用 surface 栈，改一个版本号）而不是 7.2；
4. 先把可上游的部分（DPU DSC、videocc、a680、SoundWire 加固）整理成上游补丁发出去。

---

# 执行结果（2026-10-07 晚）

选的是「精简集 + 维护一套补丁集 + 主线 tarball 走 makepkg」这条路。

## 产物

| 位置 | 内容 |
|---|---|
| `~/zcc-aur/packages/linux-mibook-mainline/` | 新包：`PKGBUILD`（源 = `cdn.kernel.org` 的 `linux-7.2.tar.xz`，sha256 已固定）、`base.config` + `xiaomi-only.config`、`linux-mibook-mainline.{preset,install}`、`README.md`、`regen-patches.sh`、17 个补丁文件 |
| `linux-surface/src/kernel-7.2` | 开发树（内核镜像的 worktree，分支 `xiaomi-mainline-7.2`，基线 `upstream-v7.2`）；`patches` 由它导出 |
| 内核镜像 tag `upstream-v7.2` | `8d3ae59288f1`（Linux 7.2），评估时取的，只加对象未动分支 |

维护方式：改 `src/kernel-7.2` 里的提交 → `./regen-patches.sh` 重新导出 → `makepkg`。
补丁平铺在包目录（makepkg 只按 basename 找本地源，放不了子目录）。

## 最终 17 个补丁

binding 3：mmc `qcom,sc8180x-sdhci`、venus `qcom,sc8180x-iris`、面板 `csot,pnc357db1-4`；
驱动 11：面板 PNC、dpu 单 DSC、dsi wide bus、adreno a680、videocc、q6v5 SLPI、sdm845 声卡、
wsa881x 增益、wcd934x RX 预置、slimbus ngd、soundwire 加固、libbpf 强转（共 12 个提交，
其中 dpu/dsi/adreno 各自独立）；DT 2：`sc8180x*.dtsi` 与板级 DTS。

## 与评估预案的偏差（都朝"更少"的方向）

| 项 | 预案 | 实际 |
|---|---|---|
| `gcc-sc8180x` PCIe GDSC `ALWAYS_ON` | 需论证 | **不要了**：7.2 已有 `ccb92c78b42e clk: qcom: gcc-sc8180x: Use retention for PCIe power domains`（`PWRSTS_RET_ON`），本地 hack 被取代 |
| `drivers/base/dd.c` fw_devlink hack | 改用 config | 同上，直接不要 |
| `drivers/firmware/efi/efi.c` ResetSystem | 重写 | **不要了**：本机 cmdline 已有 `efi=noruntime`，那段（还缺大括号）无作用 |
| `mdt_loader` `skip_pas_mem_setup` | 正规化 | **不要了**：默认关闭的 DEBUG module_param，随 iris 组一起丢弃 |
| `sdhci-msm.c` 驱动改动 | 上游已有 | 确认丢掉；但 binding 那 1 行要应用到改名后的 `qcom,sdhci-msm.yaml` |
| `dsi_host.c` | 冲突 | 冲突的只是 7.2 已改写的 `bits_per_pclk` 那行（本地是格式化），采用 7.2 版本，只保留 wide-bus guard |
| 面板驱动 | +199/−21 | 与 7.2 上游驱动做 blob 级 diff 后原样套用（去掉一处已被上游清理的 `mod_devicetable.h` 包含） |

## 验证

* `makepkg -o`：源校验通过，补丁全部套用，`merge_config.sh + olddefconfig` 通过；
  `make -s kernelrelease` = `7.2.0-1-mibook-mainline`；
  `CONFIG_DRM_PANEL_HIMAX_HX83121A=m`、`CONFIG_SND_SOC_SDM845=m`、`CONFIG_SOUNDWIRE_QCOM=m`、
  `CONFIG_SLIMBUS=m`、`CONFIG_UCSI_PMIC_GLINK=m`、`CONFIG_ARCH_QCOM=y`。
* `xiaomi-only.config` 清掉了 4 个死符号（`DRM_DP_AUX_BUS`、`SPI_HID` 上游已移除；
  `RTC_DRV_SURFACE`、`UCSI_GLINK` 属 surface 栈；USB-C 走 mainline 的 `UCSI_PMIC_GLINK`，
  本来就在 `base.config` 里）。
* 完整 `makepkg` 构建通过（含 `-headers`），产物：
  `linux-mibook-mainline-7.2-1-aarch64.pkg.tar.xz`（56 MB）与
  `linux-mibook-mainline-headers-7.2-1-aarch64.pkg.tar.xz`（155 MB），
  已用 `scripts/build.sh --collect` 收进 `~/zcc-aur/repo/`（db 14 个包）。
* 产物核对：`vermagic = 7.2.0-1-mibook-mainline SMP preempt mod_unload aarch64`；
  `/boot/vmlinuz-linux-mibook-mainline` 是单层 gzip（解开后与构建出的
  `arch/arm64/boot/Image` 逐字节相同），`usr/lib/modules/*/vmlinuz` 是裸 Image；
  面板模块含 `csot,pnc357db1-4` 与 `pnc_full_init` 参数，`qcom_q6v5_pas` 含
  `qcom,sc8180x-slpi-pas`，`soundwire-qcom` 含加固后的报错字符串。
* 上机前注意：包名独立，`/boot` 下是 `vmlinuz-linux-mibook-mainline` 与
  `initramfs-linux-mibook-mainline.img`，GRUB 需要自己加一条菜单项（安装脚本会提示）。

## 移植过程中新暴露的三个坑（纸上评估时看不出来）

1. **`remoteproc_adsp_glink` 标签被上游删了**：`85abff154951 arm64: dts: qcom: Drop
   unused remoteproc_adsp_glink label` 在 7.2 里删掉了它，而本板 DTS 的 `apr` 节点
   挂在它上面。补丁里把这个标签加回 ADSP 的 glink-edge。
2. **`refgen` / `gpu_mem` 标签与 7.2 新增节点撞名**：7.2 的 `sc8180x.dtsi` 新增了
   refgen 稳压器（`4be2ab8c4e7d`，直接接到两个 DSI 节点上）和 8 KB 的 `gpu_mem`。
   板级 DTS 里那套 bring-up 期自造的 1.2 V refgen 固定稳压器已经多余（删掉），
   厂商 20 KB 的 GPU ZAP carve-out 改名成 `gpu_zap_mem`（保留原有行为）。
3. **因此多了一个配置依赖**：既然 7.2 的 dtsi 用 `&refgen` 给 DSI 供电，
   `CONFIG_REGULATOR_QCOM_REFGEN` 必须开（6.18 的 config 里是 `not set`），
   否则 DSI PHY 的 `refgen-supply` 永远等不到 provider，直接没显示。
   已加进 `xiaomi-only.config`。

这三条是"6.18 → 7.2 配置/DT 漂移"的典型：补丁能套上，不代表 DT 能过 dtc、
更不代表驱动能拿到资源。装机前值得对照 `dtbs_check` 与启动日志再看一遍。

另外两个只有真正编译/打包才会撞上的坑：

4. **`sound/soc/qcom/sdm845.c` 的合并残骸**：本板的改动用到了 `pdata`
   （`struct sdm845_snd_data`），但 7.2 把那个函数的上下文改掉了，三方合并
   留下了用 `pdata` 却没有声明的代码，编译才报 `'pdata' undeclared`。
   补上声明（并确认 7.2 已移除的 `sruntime` 逻辑没有跟着回来）。
5. **`make -s image_name` 在 arm64 上是 `Image.gz`**：照抄原 PKGBUILD 的
   `install -Dm644 "$(make -s image_name)" ...` 会装一个 gzip 镜像，
   再按"给 /boot 的镜像 gzip 一下"处理就变成 gzip 套 gzip，GRUB 起不来。
   现在显式用 `arch/arm64/boot/Image`：`usr/lib/modules/*/vmlinuz` 放裸镜像，
   `/boot/vmlinuz-*` 放单层 gzip（与已安装的 `linux-mibook` 一致，解开后
   与构建产物逐字节相同）。

顺带修了 `~/zcc-aur/scripts/build.sh` 的一个 bug：`--collect` 后的 `prune_old`
用 `<pkgname>-*.pkg.tar.*` 前缀 glob 分组，`linux-mibook-mainline` 会把
`linux-mibook-mainline-headers` 一起吞进自己的组，然后"只留最新的一个"把内核包
删掉、留下 -headers 兄弟（第一次 collect 就是这样丢了内核包）。现在按每个文件名
自己解析出的包名分组，并且内层循环改用进程替换喂数据（`find | while read` 会和
外层 while 抢同一个 stdin，把外层一次读空）。

## 7.2 上机结果（2026-10-08 更新）

补丁集已经落地可用：`src/kernel-7.2`（30 个补丁，分支 `xiaomi-mainline-7.2`）、
`~/zcc-aur/packages/linux-mibook-mainline` 下的 7.2 包、以及 `/boot` 上的
`Arch Linux mainline` 条目。**显示链路已修好**（面板驱动 / DSI PHY / DSC 宽度）、
**GPU 降频已修**（8cx Gen 2 的 670MHz profile）、并 cherry-pick 了上游若干真实修复
（含 "Fix stale rpmh votes after suspend"、"Recover HW before retire hung submit"）。

唯一未解决的问题是 **7.2 上 GPU/GMU 的静默停摆**：进 GNOME 后几十秒，GPU 卡在一次
draw 里，随后 GMU 停止响应 HFI，复位能跑完但 GMU 回不来。完整排查记录、已实测排除的
20 余个方向、试过的绕过方案、以及下一步的成组回退二分方案，见
**[linux-7.2-gpu-wedge.md](linux-7.2-gpu-wedge.md)**。日常仍建议使用 6.18。



