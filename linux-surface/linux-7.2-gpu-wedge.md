# 7.2 的 GPU/GMU 静默停摆 —— 排查结论与交接

日期：2026-10-08
相关树：`src/kernel-7.2`（worktree，分支 `xiaomi-mainline-7.2`；tip `c1bf1df572f4`，**28 补丁**。本报告成文时为 `3f8e2efe10f8` / 30 补丁）、构建树 `~/zcc-aur/packages/linux-mibook-mainline/src/linux-7.2`
相关包：`~/zcc-aur/packages/linux-mibook-mainline/linux-mibook-mainline-7.2-1-aarch64.pkg.tar.xz`（**10-08 23:26，含 GBIF 修复，已实测可用**；已知可用副本在 `known-good/`）

---

## 0. 已解决（2026-10-08 晚）：GEN2 的 CX GBIF 配置被 7.2 弄丢了

**根因**：上游 7.2 的 `60a4e18e0e8a`（"drm/msm/adreno: Do CX GBIF config before GMU
start"，正是 §6 A 组的第二条）把 `GBIF_QSB_SIDE0..3 = 0x00071620` 从 `hw_init()` 的
`a640_family` 分支搬进 catalog 的 `a640_gbif` reglist（由 `a6xx_gmu_fw_start()` 在
GMU 唤醒前写入）。但这个 list **叫 `a640_gbif`，却没挂到 A640 / A680
（`ADRENO_6XX_GEN2`）条目上**；同时 `hw_init()` 里剩下的那份只覆盖 `a610_family`
→ **GEN2 的四个 QSB 侧寄存器彻底没人写了**。6.18 是给整个 a640 family 写的 —— 那是
2020 年 `24e6938ec604`（"Adreno 640 and 650 GPUs need some registers set
differently"）专门为 A640/A650 加的。

上游 review 里已经点过：Konrad Dybcio 在 v2 里写 *"a640/650 family GPUs didn't
receive a `.gbif_cx` addition in the catalog to match"*，Akhil 回 *"Oops, I missed
that. Will fix this."* —— 但合进 7.2 的 v4 **只补上了 a650**，A640/A680 仍然漏着。
<https://lkml.iu.edu/hypermail/linux/kernel/2511.1/08279.html>

**为什么第 1–2 节的每个症状都对得上**：

* **复位救不回来**：GBIF/QSB 在 **CX** 域，而 `a6xx_recover()` 复位的是 **GX** 域 →
  卡住之后复位永远清不掉，GMU（同在 CX）自然也回不来 —— 正是"复位跑得完但 GMU
  回不来，几轮后整机死"。
* **零 fault**：丢的是 GBIF QoS 侧配置而不是地址映射，表现是"事务永久不返回"，
  不是 page fault → IOMMU / SMMU / 时钟 / 稳压器日志全空。
* **40–190 秒随机、与频率无关**：只有内存压力上来（GNOME 开始合成）才踩得到。

**修复**（commit `c1bf1df572f4`，重新编号后是补丁 0028；只有两行）：

```c
/* drivers/gpu/drm/msm/adreno/a6xx_catalog.c —— A640 与 A680 两个 GEN2 条目 */
.gbif_cx = a640_gbif,
```

**实测**：带该修复的 31 补丁版（当时仍含 UBWC 调试补丁 0030）进 GNOME 使用正常，
不再出现 `HFI_H2F_MSG_GX_BW_PERF_VOTE ... timed out`。

**上游**：这是通用缺陷（A640 / SM8150 同样漏），值得单独发；建议 commit message 补
`Fixes: 60a4e18e0e8a` 与 `Signed-off-by`。

**顺带清掉的调试补丁**（用 `drop-commits.sh`，见 §7）：`0022 + 0027`
（`no_gpu_recovery` 及其 revert，净零）与 `0030`（UBWC 报不支持）。`0020`（禁 UBWC
scanout）暂时保留 —— 恢复压缩 scanout 需要单独一轮上机验证。

---

## TL;DR（原标题，2026-10-08 晚更新）

* **已解决**（见 §0）：原来"未解决"的 GPU/GMU 静默停摆 = GEN2 的 `gbif_cx` 漏挂，
  补两行后实测通过。
* **仍然有效**：显示链路（面板 / DSI / DSC）、GPU 降频（8cx Gen 2 的 670MHz
  profile）、以及若干 7.2 相对 6.18 的**真实缺陷**（见第 4 节）。
* **§6 的"按组回退 A–D"不再需要**：`60a4e18e0e8a` 已被单点定位并修复。
* 第 1–8 节保留原始排查记录；其中的补丁编号是当时的 30 补丁序列（当晚摘掉
  0022/0027/0030 后有位移，稳定标识请用 commit hash）。

---

## 1. 症状与可复现性

进 GNOME 后几十秒，日志出现如下固定序列（`/var/log/blackbox/sample-*.txt`、SD 上的 journal 都能看到）：

```
[   57.8] platform 2c6a000.gmu: [drm:a6xx_hfi_wait_for_msg_interrupt [msm]] *ERROR*
          Message HFI_H2F_MSG_GX_BW_PERF_VOTE id NNN timed out waiting for response
[   58.3] platform 2c6a000.gmu: GMU watchdog expired
[   58.3] msm_dpu ae01000.display-controller: [drm:recover_worker [msm]] *ERROR* 06080001: hangcheck recover!
[   58.3] msm_dpu ae01000.display-controller: [drm:recover_worker [msm]] *ERROR* 06080001: offending task: gnome-shell
[   58.3] adreno 2c00000.gpu: [drm:a6xx_recover [msm]] status:   00d31db5
[   58.3] platform 2c6a000.gmu: [drm:a6xx_hfi_stop [msm]] *ERROR* HFI queue 0 is not empty
```

* 触发时间是随机的：实测 47 / 57 / 72 / 95 / 190 秒都出现过；
* 与 **GPU 频率无关**（把上限压到 530MHz 也照样挂）、与负载强度无关；
* 一旦发生，后续每轮复位都「跑完但不复活」，几轮之后整机死；
* 全程**没有任何** fault / IOMMU / SMMU / 时钟 / 稳压器报错（这正是最难的地方）。

## 2. 关键观测

从 `/sys/class/devcoredump/devcd0/data`（挂死瞬间的 crashstate）得到：

* **HFI 命令队列里有一条没被取走的消息**：`read_index=240`（冻结）、`write_index=244`，里面正是 `HFI_H2F_MSG_GX_BW_PERF_VOTE`（`ack_type=1, freq=10, bw=0`）；**响应队列为空** → **GMU 不再消费 HFI 消息**；
* GPU 与 GMU 的寄存器都**可读**（分别 40.6% / 36.7% 非零）→ 不是掉电；
* ring：`rptr 316 / wptr 551` → 有未消费的命令。

`a6xx_recover` 打印的 `status: 00d31db5`（A6XX_RBBM_STATUS）解码：

```
0x00d31db5 = GPU_BUSY_IGN_AHB | GPU_BUSY_IGN_AHB_CP | VSC_BUSY | UCHE_BUSY | VPC_BUSY |
             PC_DCALL_BUSY | COM_DCOM_BUSY | LRZ_BUSY | CCU_BUSY | RB_BUSY |
             TSE_BUSY | VBIF_BUSY | CP_BUSY | CP_AHB_BUSY_CX_MASTER
```

→ **GPU 卡在一次 draw 里，显存端口（VBIF）busy** —— 即「某次显存访问永远不返回」。

> ⚠️ **一个容易误判的点（本报告自我纠正）**：crashstate 里的 `rbbm-status: 0x00000000` **不能**说明「GPU 空转、没人喂活」——`a6xx_recover()` 在抓 crashstate **之前**就写了 `CP_SQE_CNTL = 3` 把 CP halt 掉，读到 0 是 driver 停住的结果。真实状态应以复位时读到的 `0xd31db5`（3D 流水线 + VBIF + CP 全 busy）为准。

## 3. 已实测排除的方向（含做法）

| 方向 | 做法 | 结果 |
| --- | --- | --- |
| 显示 / 面板 / DSI / DSC | 补丁 0018（7nm DSI PHY digital top）、0019（DSC 宽度 DIV_ROUND_UP） | **有效**，GNOME 能起来 |
| GPU 降频 | 补丁 0023 / 0026（8cx Gen 2 的 670MHz profile + LPDDR4X bank bit） | **有效**（`available_frequencies` 变成 235…670，单调） |
| DVFS / 电压 / 频率 | 用降频 DTB 把上限压到 625 / 595 / **530**MHz | 仍然挂 ✗ |
| GMU 时钟门控 | 补丁 0024（回退 A612 提交对 `a6xx_pm_suspend/resume` 的时钟门控） | 无效 ✗ |
| 第三个 HFI 队列 | 补丁 0025（Debug HFI Q 只在 a7xx/a8xx 注册） | 无效 ✗ |
| UBWC | 0026（bank bit 15）+ 0030（对本板把三个 UBWC 参数报成不支持，用户态退回线性） | 无效 ✗ |
| GPU/GMU runtime PM | `/etc/tmpfiles.d/gpu-no-runtime-pm.conf` 把 `power/control` 固定 `on` | 无效 ✗ |
| IFPC / ACD | IFPC 未使能（无 `ADRENO_QUIRK_IFPC`，`idle_level=ACTIVE`）；`msm.disable_acd=1` | 无效 ✗ |
| GEM shrinker / eviction | `msm.enable_eviction=0` | 无效 ✗ |
| 懒惰 TLB 失效 | `iommu.strict=1`（替换 `strict=0`） | 无效 ✗ |
| 复位顺序 | 补丁 0029（recover 提到 retire 之前，上游 2026-06 系列） | 复位现在**能跑起来**，但 GMU 回不来 |
| RPMH 停序列 | 补丁 0028（`a6xx_rpmh_stop` 判断取反 + halt CM3，同一上游系列） | 同上 |
| GMU 寄存器重定位 | 逐条验证 XML 偏移：6.18→7.2 全部 `+0x1a800` dword = +0x6a000 = GMU 相对 GPU 基址 | **算术正确** ✗ |
| fenced write / doorbell | 两份实现逐行一致；失败会打印 `fenced register write ... fail`，日志中没有 | 排除 ✗ |
| GPU 家族 / 目录 / hwcg / GDSC | 三棵树逐项对照（`a680` = `ADRENO_6XX_GEN2`、`gpu_cx_gdsc`/`gpu_gx_gdsc` 定义完全相同） | 排除 ✗ |
| 投递给 GMU 的消息内容 | `a6xx_hfi_start`、特征使能、perf/bw table、`a6xx_gmu_set_freq`、BCM 投票构造全部逐函数对照 | 一致 ✗ |

## 4. 已应用的修复（建议保留）

> 下表编号是**当时的 30 补丁序列**。2026-10-08 晚摘掉 0022/0027/0030 之后全部有位移
> （例如旧的 0023 → 新 0022，旧的 0031 → 新 0028），稳定标识请用 commit hash。

| 补丁 | 内容 | 性质 |
| --- | --- | --- |
| 0018 | `drm/msm/dsi/phy`: 先给 digital top 上电再起 7nm PLL | **上游 cherry-pick**（Dmitry Baryshkov, 2026-09-24），基线到 7.3 后可删 |
| 0019 | `drm/msm/dpu`: DSC active width 用 `DIV_ROUND_UP` | 本地修复（6.18↔7.2 的偏差） |
| 0021 | `drm/msm/a6xx`: 检查 `pm_runtime_resume_and_get()` 返回值 | **上游 cherry-pick**（Roman Demidov, 2026-09-04），基线到 7.3 后可删 |
| 0023 | `arm64: dts`: 本板改用**高 bin 的 670MHz GPU DVFS profile**（235/315/392/530/595/625/670，一个 corner 一档） | 本地，**修掉真实降频** |
| 0024 | `drm/msm/a6xx`: 不在 GPU PM 路径里门控 GMU 时钟 | 本地，修引用计数错配（非本次病根） |
| 0025 | `drm/msm/a6xx`: Debug HFI queue 只在 a7xx/a8xx 注册（并让上报的队列数取自实际注册数） | 本地，修真实缺陷 |
| 0026 | `soc: qcom: ubwc`: 本板用 LPDDR4X 的 highest bank bit（15） | 本地，修真实配置错误。**摘掉 0030 之后它是必须的** |
| 0028 | `drm/msm/a6xx`: **Fix stale rpmh votes after suspend** + halt CM3 | **上游 cherry-pick**（Shivam Rawat / Akhil P Oommen, 2026-06 系列），7.3 后可删 |
| 0029 | `drm/msm`: **Recover HW before retire hung submit** | **上游 cherry-pick**（Jie Zhang, 同一系列），7.3 后可删 |
| **0031** | `drm/msm/adreno`: 给 A640/A680 补上 `.gbif_cx = a640_gbif`（新增，commit `c1bf1df572f4`） | 本地，**本次病根的修复**，见 §0；通用缺陷，值得发上游（新编号 0028） |

**已删除的诊断项（2026-10-08 晚，见 `drop-commits.sh`）**：

* 补丁 **0022 + 0027**（`msm.no_gpu_recovery` 调试开关及其 revert）—— 两者净差 0 行，纯噪音；
* 补丁 **0030**（`drm/msm/adreno: report UBWC as unsupported on the Xiaomi Book S 12.4`）—— 为验证 UBWC 加的板级一刀切，带着它照样挂，已证无效，留着只会让 GPU 退回线性缓冲。

**待定**：补丁 **0020**（`drm/msm/dpu: do not advertise UBWC scanout on SC8180X`，把
`QCOM_COMPRESSED` 从 `dpu_plane.c` 的 `supported_format_modifiers[]` 里删掉）。它
commit message 里"compressed scanout 几秒就挂"的现象，现在看就是 §0 那个病；恢复它
= 打开压缩 scanout，需要单独一轮上机验证，别和 0030 混在一起。


上游那两条修复对应的线程：
* <https://lore.kernel.org/all/20260605-assorted-fixes-june-v1-1-2caa04f7287c@oss.qualcomm.com/>
* <https://lore.kernel.org/all/20260605-assorted-fixes-june-v1-2-2caa04f7287c@oss.qualcomm.com/>
* 另见 `drm/msm: Wait for MMU devcoredump when waiting for GMU`（上游已知「fault 洪水会把 GMU 卡住」这条故障模式）

## 5. 试过的绕过（均无效，可撤销）

* **runtime PM pin**：SD 上已装 `/etc/tmpfiles.d/gpu-no-runtime-pm.conf`（把 `2c00000.gpu` / `2c6a000.gmu` 的 `power/control` 固定为 `on`）。无效，可删：
  `sudo rm /etc/tmpfiles.d/gpu-no-runtime-pm.conf`，并把两个 `power/control` 写回 `auto`。
* **降频 DTB**：`test-dtb/sc8180x-xiaomi-book-12.4-gpu{625,595,530}.dtb`。当前 `/boot/dtb/linux-mibook-mainline/qcom/` 上装的是**完整 7 档**版（md5 `bfe7a6118d7517fa77463b6bc507dc9e`），无需处理。
* **cmdline 开关**：目前 mainline(SD) 条目上多了
  `msm.enable_eviction=0 msm.disable_acd=1` 与 `iommu.strict=1`（原为 `iommu.strict=0`）。
  建议恢复为：`… loglevel=3 ignore_loglevel iommu.passthrough=0 iommu.strict=0 efi=noruntime msm.hang_debug=1`
  （`initcall_debug` 也建议去掉，它会刷满内核日志缓冲）。
* 诊断补丁 `msm.no_gpu_recovery`（旧 0022 + 其 revert 0027）与 UBWC 调试补丁（旧
  0030）已从补丁集里**整条摘掉**了（不是 revert 留着），见 §4 与 §7 的
  `drop-commits.sh`；`0020`（禁压缩 scanout）仍在，待单独一轮验证后决定。

## 6.（已作废）原计划：按组回退 7.2 的 GPU 驱动改动

> **2026-10-08 晚：本节不再需要。** 病根已在 §0 单点定位并修复（就在 A 组里：
> `60a4e18e0e8a` 漏给 A640/A680 挂 `gbif_cx`）。以下保留作为排查记录，以及"以后再
> 遇到同类问题时"的思路。

思路：在 `upstream-v7.2` 上开临时分支，只带上**少数必要补丁**（面板驱动、DSI PHY 0018、DSC 0019、a680 固件名 0007），然后**回退一个组**，编译、启动、正常用几分钟，看 `GX_BW_PERF_VOTE timed out` 是否消失。约 4 组即可收敛。

统计（6.18→7.2）：`drivers/gpu/drm/msm/adreno` **97** 个提交、`msm_gpu.c` 13、`msm_gem.c` 12、`msm_gem_vma.c` 18、`msm_ringbuffer.c` 6、`msm_gem_submit.c` 2。

### A 组（最可能，先做）：A8xx 批里改动共用 a6xx 路径的提交

```
e39333a81eef drm/msm/a6xx: Retrieve gmu core range by index
60a4e18e0e8a drm/msm/adreno: Do CX GBIF config before GMU start
bb9b1d6e945e drm/msm/a6xx: Fix gpu init from secure world
61957ab99d8c drm/msm/a6xx: Add support for Debug HFI Q
d34b6919798c drm/msm/a6xx: Correct OOB usage
dc78b35d5ec0 drm/msm/a6xx: Use barriers while updating HFI Q headers
29c1d7e5db01 drm/msm/a6xx: Use packed structs for HFI
742b4e88cddb drm/msm/a6xx: Update HFI definitions
188db3d7fe66 drm/msm/a6xx: Rebase GMU register offsets
15cc59ac954e drm/msm/a6xx: Add support for Adreno 612
```

（**必须整组一起回退**：`188db3d7fe66` 的寄存器重定位与其余代码是配套的，单独回退会破坏地址换算。）

### B 组：UBWC rework 全批（含 DPU / mdss 侧）

```
5c8cbca290ac Merge branch '20260507-ubwc-rework-v4-…'
d158886cba08 drm/msm/adreno: Trust the SSoT UBWC config
95776c9f016b / d2fb2372768a / d7c0878bbda8 use new helper to set ubwc_swizzle
ddbcc8750043 drm/msm/adreno: write reserved UBWC-related bits
ca65f7f7545e drm/msm/adreno: set fp16compoptdis for UBWC 3.0 formats
579f66114027 drm/msm/adreno: use version ranges in A8xx UBWC code
62342315b65a / 25d06d0a4760 drm/msm/dpu: drop ubwc_dec_version / invert the order of UBWC checks
933430f1709b drm/msm/dpu: fix UV scanlines calculation for YUV UBWC formats
258b080dc280 / 5dcec3fc1311 / 2f3ff6ab8f5c / ada4a19ed21c DPU UBWC 编程路径
```

（注意：之前只验证了**显存参数**那一小块（0026/0030），**DPU/mdss 侧的 UBWC 编程完全没测过**。）

### C 组：msm 核心（gpuvm / VM_BIND / submit / ringbuffer）

```
8c0e0b4628e5 drm/msm: Remove abuse of drm_exec internals
85042c2cd970 drm/msm: Fix VM_BIND UNMAP locking
c07612365087 drm/msm: Disallow foreign mapping of _NO_SHARE
8a7023b03535 drm/msm/vma: Avoid lock in VM_BIND fence signaling path
379e8f1ca5e9 drm/gem: Make the GEM LRU lock part of drm_device
9c44ff055965 / 2683a0e7c4cc drm/msm: Remove drm_sched_init_args->num_rqs usage (+其 revert)
02195633635c / 6477bd5ef0f6 drm/msm: perfcntr 基础设施 / 移除旧 perf 设施
```

（这组最难干净回退——`drm/gpuvm` 的 API 迁移是横向的。若冲突太多，可只回退 `85042c2cd970`、`8a7023b03535`、`c07612365087` 三个局部改动先试。）

### D 组：恢复 / 中断 / fault-coredump

```
01a0d6cd7032 drm/msm: always recover the gpu
50a0b122cfc8 drm/msm: Wait for MMU devcoredump when waiting for GMU
4625fe5bbdac drm: gpu: msm: forbid mem reclaim from reset
```

### 具体做法

```bash
cd ~/aarch64-packages/linux-surface/src/kernel-7.2      # 或另建 worktree
git checkout -b bisect-a8xx upstream-v7.2
# 只挑必要补丁（显示/GPU 能起来即可；DTB 由 GRUB 从 ESP 提供，不需要打 DTB 补丁）
git cherry-pick <面板驱动提交> <0018 对应提交> <0019 对应提交> <a680 固件名提交>
git revert -n e39333a81eef 60a4e18e0e8a …              # 整组
git commit -m "TEST: revert A8xx batch (bisect)"
```
然后把该树作为构建源编包、安装、启动、正常用几分钟，看
`grep -l "timed out waiting for response" /var/log/blackbox/sample-*.txt` 是否为空。

## 7. 接手所需的现场状态

* **dev 树**：`src/kernel-7.2`（分支 `xiaomi-mainline-7.2`，**28 补丁**，tip `c1bf1df572f4`）；
  补丁集由 `~/zcc-aur/packages/linux-mibook-mainline/regen-patches.sh` 从提交重新生成；
  从序列里摘提交用同目录的 `drop-commits.sh`（改写前自动记
  `refs/backup/drop-commits-<时间戳>`，rebase 冲突自动 abort）。
* **构建树**：`~/zcc-aur/packages/linux-mibook-mainline/src/linux-7.2`（已与 28 补丁序列
  **逐文件核对一致**：27 个被触及文件 0 差异；`makepkg -e --noprepare -f` 增量重编）。
  ⚠️ `makepkg -e` 不会刷新 `src/` 里的补丁符号链接（现存只有 0001–0017，是 17 补丁
  时代留下的），所以**不要**用不带 `--noprepare` 的 `-e` 去跑 `prepare()`；改用全量
  `makepkg -s`（会重新链接全部补丁）。
* **包**：`linux-mibook-mainline-7.2-1-aarch64.pkg.tar.xz`（**10-08 23:26，含 GBIF 修复，
  已实测可用**，md5 `a442c0ce5c76b5bea85fcd2b58be77b4`）、headers（23:31）。
  已知可用副本：`known-good/linux-mibook-mainline-7.2-1-gbif-fix-aarch64.pkg.tar.xz`
  （同 md5）+ 对应 headers；每次撤补丁重编之前先确认它还在。
* **ESP（当前已装 = 修好那版）**：`/boot/vmlinuz-linux-mibook-mainline`（10-08 23:19，
  md5 `980715bf999cfb963a61a6271cb811af`）、`/boot/initramfs-linux-mibook-mainline.img`
  （23:36，md5 `0e7e865559565e78099aa53a92eb2d96`）、
  `/boot/dtb/linux-mibook-mainline/qcom/sc8180x-xiaomi-book-12.4.dtb`（完整 7 档，md5
  `bfe7a6118d7517fa77463b6bc507dc9e`）。
* **崩溃现场**：SD 卡 `/var/log/blackbox/sample-*.txt`（采样器每秒记录 `devices_deferred` + dmesg 尾）、SD 的 systemd journal、用户主目录下的 `dmesg*.log`；devcoredump 只存在于 RAM，重启即失，需要现场时要在挂死状态下 `cat /sys/class/devcoredump/devcd*/data`。
* **黑匣子工具**：SD `/usr/local/bin/blackbox-dmesg.sh`、`blackbox-sample.sh` 及对应 systemd units（`test-crashlog/` 里有源文件）。
* **采样器/服务的注意事项**：采样器每秒 `sync` 一次，对 SD 卡有持续写入；已知它**不是**本次挂死的原因（最早的挂死发生在采样器部署之前）。

## 8. 参考

* `HARDWARE-STATUS.md` —— 板级硬件/ACPI/DVFS 的完整笔记（GPU 670MHz profile、PCIe、面板、音频等）。
* `linux-7.2-port-eval.md` —— 7.2 移植评估。
* 上游相关：
  * `drm/msm: Wait for MMU devcoredump when waiting for GMU`（"a flood of faults … the GMU becomes blocked"）
  * `[PATCH 0/6] drm/msm: Assorted fixes - June/26`（本报告已 cherry-pick 0028/0029）
  * `drm/msm/a6xx: Increase HFI response timeout` / `Be more robust when HFI response times out`
  * `drm/gpuvm: reject zero-length VM_BIND ranges at the shared gate`（2026-09，7.2 之后）
  * `drm/msm: Temporarily disable stall-on-fault after a page fault`
