# 7.2 休眠/唤醒这一轮：白屏与触摸

日期：2026-10-09
相关树：`src/kernel-7.2`（分支 `xiaomi-mainline-7.2`，upstream-v7.2 基线）
相关包：`~/zcc-aur/packages/linux-mibook-mainline`（补丁集 0030 / 0031、配置改动）

本轮起点是"昨晚休眠失败"：日志停在 05:22:52 的 `PM: suspend entry (s2idle)`，
之后没有任何 `PM: suspend exit`，机器只能硬断电。追下去牵出**两个互相独立**的
问题，一个让显示子系统起不来（白屏），一个让触摸在挂起/恢复时刷错误。

---

## 一、白屏：7.2 把 6.18 的"无限等待"丢了，配置停在默认 10 秒

### 现象

装上新 DTB 后那次启动（boot -1，09:12）屏幕白亮、无图像，日志里没有
`adreno` 探测消息，也没有 DSI/panel 的绑定：

```
msm-mdss ae00000.display-subsystem: deferred probe timeout, ignoring dependency
msm-mdss ae00000.display-subsystem: probe with driver msm-mdss failed with error -110
```

正常的启动一定有：

```
adreno 2c00000.gpu: supply vdd not found, using dummy regulator
msm_dpu ae01000.display-controller: bound 2c00000.gpu (ops a3xx_ops [msm])
[drm] fb0: msmdrmfb frame buffer device
```

msm 的 DRM 设备由 DPU + DSI + **GPU** 组件拼成；GPU 没在时限内就位 → 组件绑定
失败 → `msm-mdss` 探测失败 → 没有 framebuffer → 背光亮着、没有图像。

### 根因

| | |
| --- | --- |
| 6.18 树 | 板级补丁 `1d30d9d1edda` 把 `drivers/base/dd.c` 的 `driver_deferred_probe_timeout` 从 10 改成 **-1**（无限等） |
| 7.2 分支 | 按 `linux-7.2-port-eval.md` 的建议去掉这个 hack，改说"用 `CONFIG_DRIVER_DEFERRED_PROBE_TIMEOUT` 表达" |
| 实际配置 | `base.config` / `xiaomi-only.config` **都没设这个符号** → 走默认 **10 秒** |

`dd.c` 只在 `driver_deferred_probe_timeout > 0` 时挂那个超时定时器
（[dd.c:361](../../aarch64-packages/linux-surface/src/kernel-7.2/drivers/base/dd.c)），
负值即"永不放弃"，与 `Documentation/admin-guide/kernel-parameters.txt` 里
"a negative value is treated as an infinite timeout" 一致。所以 10 秒一到，
`driver_deferred_probe_check_state()` 返回 `-ETIMEDOUT`，显示子系统永久失败。

保留的 12 次启动里只有这一次踩到——是个竞态，但 6.18 永远不会踩。

### 处理

* `xiaomi-only.config` 显式加 `CONFIG_DRIVER_DEFERRED_PROBE_TIMEOUT=-1`
  （`merge_config.sh` + `make olddefconfig` 已验证最终 `.config` 就是 -1）。
* 临时替代：GRUB 的 `linux` 行加 `deferred_probe_timeout=-1`，不用重编。

---

## 二、触摸：控制器 NAK `SET_POWER(SLEEP)`，abort 把 GENI 控制器拖坏

### 设备与现场

| | |
| --- | --- |
| 设备 | Himax `HIMX1234`，hid-over-i2c `4858:121a`，`884000.i2c`（QUP0 SE1，sysfs `i2c-0`） |
| ACPI | `\_SB.TSC1`，I2cSerialBus 0x4f + `GpioInt`（TLMM 122）；**没有 reset GPIO** |
| 电源 | vdd = LDO4_C (3.3 V)、vddl = LDO12_E (1.8 V)，确认只有触摸一个消费者 |
| ACPI PEP0 `LPXC` 里的 D0 序列 | DELAY 500ms → 驱动 TLMM **GPIO 54** → DELAY 200ms → LDO4_C → LDO12_E → DELAY 1ms → 再驱动 GPIO 54 → DELAY 200ms → 最后把 GPIO 122 配成输入 |
| D3 序列 | … 先关 LDO12_E，200ms 后再关 LDO4_C |

Linux 侧只描述了电轨和中断，**没有 GPIO 54，也没有这个顺序**。

### 原来的失败链

```
挂起: SET_POWER(SLEEP) → NAK(-ENXIO) → GENI abort（RX_FSM 复位）
恢复: i2c_hid_core_pm_resume: PWR_ON → NAK → 返回 -6 → PM: failed to resume async
      ~1.2s 后 geni_i2c 884000.i2c: Timeout resetting RX_FSM
```

触摸和笔**一直能用**（设备在它有数据要报时会应答），所以这条链是"每次挂起留下
一次失败的设备恢复 + 一次总线抖动"，而不是设备死掉。

### 处理（两个补丁）

* **0030** `arm64: dts: ...: keep the Himax touch powered across suspend`
  （`85dd31388743`）：节点加 `wakeup-source`。`device_may_wakeup()` 为真后，
  i2c-hid 在 `i2c_hid_core_suspend()` 跳过 `power_down()`、在
  `i2c_hid_core_resume()` 跳过 `power_up()`，设备带着电和状态跨过 s2idle。
  副作用：I2C core 会把触摸 IRQ 武装成 wake IRQ（摸屏可唤醒）。
* **0031** `HID: i2c-hid: don't send SET_POWER(SLEEP) to the Xiaomi Book S 12.4
  touchscreen`（`1ccd0d5ab7da`）：`hid-ids.h` 加 Himax `0x4858:0x121a`，quirk 表
  里给 `I2C_HID_QUIRK_NO_SLEEP_ON_SUSPEND`——上游给 Cirque 1063 的就是这个处理
  （那颗同样 NAK 这条命令）。

### 实测

| 时间 | 配置 | 挂起阶段 | 恢复阶段 |
| --- | --- | --- | --- |
| 10:03 | 只有 0030 | `failed to change power setting` ×1 | `failed to change power setting` ×1、`returns -6`、RX_FSM 超时 |
| 10:36 | 0030 + 0031 | **零 I2C 流量，无任何错误** | `PWR_ON` 仍被 NAK（`failed_resume=1`）、RX_FSM 超时一次 |

两次都能正常唤醒，显示、触摸、笔、WiFi、另一条 I2C 总线（ra9530，SE7）都正常。

### 还剩什么

1. **每次 resume 记一次 `failed_resume`（`last_failed_dev = 0-004f`）**：那颗
   控制器在空闲时不回应主机的**主动**命令，而 resume 路径里 spec 要求的
   `PWR_ON` 正是这种命令。功能无影响。
   * 想彻底干净，只有走厂商那套"关电轨 → 开电轨 + GPIO 54 + 时序"的复位；
     GPIO 54 的极性/作用没能从 ACPI 确证（它的 D0/D3 描述是同一个值），照抄有把
     触摸按在复位里的风险。属可选实验。
2. **每次 resume SLPI 崩一次**：
   ```
   PDM: service 'sensor_process' crash: 'EX:sensor_process:0x1:frpc_dsp:0x6e:PC=0xb205fb9c'
   remoteproc remoteproc0: crash detected in slpi: type fatal error
   ```
   之后 remoteproc 自动恢复，但传感器/自动旋转会掉一下。与触摸无关，待查。

---

## 复现 / 验证 / 回滚

```bash
# 触摸修复的依赖之一（config）要等下一次编内核；本次是先用手改的模块验证
# 1) 确认 wakeup-source 已生效
ls /proc/device-tree/soc@0/geniqup@8c0000/i2c@884000/touchscreen@4f/
cat /sys/devices/platform/soc@0/8c0000.geniqup/884000.i2c/i2c-0/0-004f/power/wakeup   # enabled

# 2) 睡一次，醒来查
journalctl -b 0 -k | grep -iE 'i2c_hid|geni_i2c|PM: suspend'
cat /sys/power/suspend_stats/failed_resume

# 3) 本次临时验证用的模块（NO_SLEEP quirk）备份在 /root/i2c-hid.ko.orig
```

DTB 的回滚副本是 `/boot/dtb/linux-mibook-mainline/qcom/sc8180x-xiaomi-book-12.4.dtb.pre-wakeup`。

## 相关补丁

| 补丁 | commit | 内容 |
| --- | --- | --- |
| 0030 | `85dd31388743` | 触摸节点 `wakeup-source` |
| 0031 | `1ccd0d5ab7da` | i2c-hid：`NO_SLEEP_ON_SUSPEND`（Himax 0x4858:0x121a） |
| （配置） | — | `CONFIG_DRIVER_DEFERRED_PROBE_TIMEOUT=-1` |

补丁集已由 `regen-patches.sh` 重新导出并推送：zcc-aur `4cd7a8a`。
