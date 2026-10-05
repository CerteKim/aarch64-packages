# SoundWire pops and the bus-clash storm — Xiaomi Book S 12.4 (SC8180X)

Investigated 2026-10-05 on `6.18.2-1-mibook+`. Two separate faults, both in the
`WCD9340`-internal SoundWire master + `WSA881x` path, both audible:

1. **A 68-second "bus clash" storm** — 10,513 `wsa881x-codec ...:3: Bus clash
   detected` and 322 `...: Reached MAX_RETRY on alert read`, between 08:24:30
   and 08:25:38, with only **two** master-side
   `qcom-soundwire ...: SWR bus clsh detected` reports (08:24:30, 08:25:21).
2. **`Slave N state check1: UNATTACHED, status was 1`** from both amplifiers,
   about 30 occurrences a day, which is a real detach/attach cycle of the
   amplifiers and therefore an audible pop.

Everything below marked **verified** was read from this tree; the rest is
flagged **inferred**. Line numbers are for `src/kernel/`.

## 1. Framing facts

**F1 (verified).** The master is driven through the codec's **SLIMbus** regmap,
not MMIO: [qcom.c:1504-1513](src/kernel/drivers/soundwire/qcom.c#L1504-L1513)
selects `qcom_swrm_ahb_reg_read` ([280-298](src/kernel/drivers/soundwire/qcom.c#L280-L298)).
Every master-register access is therefore two SLIMbus transactions, and
`qcom_swrm_ahb_reg_read()` leaves `*val` **untouched** on error while every
caller ignores the return value (`550-565`, `531-548`, `698`).

**F2 (verified).** `clock_stop_not_supported` comes from
`slave->prop.clk_stop_mode1` ([qcom.c:617-623](src/kernel/drivers/soundwire/qcom.c#L617-L623)),
and WSA881x sets it ([wsa881x.c:1177](src/kernel/sound/soc/codecs/wsa881x.c#L1177),
upstream `32ac501957e5` — *"WSA881x codecs do not retain the state while clock
is stopped"*). So this board never uses clock stop: suspend only gates `hclk`
([1721-1760](src/kernel/drivers/soundwire/qcom.c#L1721-L1760)), and resume does
`SWRM_COMP_SW_RESET` + `qcom_swrm_init()` + a 100 ms enumeration wait +
`qcom_swrm_get_device_status()` + `sdw_handle_slave_status()`
([1668-1683](src/kernel/drivers/soundwire/qcom.c#L1668-L1683)).

**F3 (verified).** Runtime PM physically power-cycles each amplifier:
`wsa881x_runtime_suspend()` asserts `SD_N`
([wsa881x.c:1201](src/kernel/sound/soc/codecs/wsa881x.c#L1201)) and
`wsa881x_runtime_resume()` releases it
([1216](src/kernel/sound/soc/codecs/wsa881x.c#L1216)). Autosuspend delay is
3 s (`power/autosuspend_delay_ms`, observed), and both amps sit `suspended`
when idle.

**F4 (verified).** ASoC resumes every component at PCM open
([soc-pcm.c:854](src/kernel/sound/soc/soc-pcm.c#L854) →
[soc-component.c:1252-1267](src/kernel/sound/soc/soc-component.c#L1252-L1267)),
and a child's resume resumes **the parent first**
([runtime.c:896-925](src/kernel/drivers/base/power/runtime.c#L896-L925)). The
reference is held for the whole substream
([soc-pcm.c:769](src/kernel/sound/soc/soc-pcm.c#L769)).

**F5 (verified).** The qcom master never calls `sdw_master_read_prop()` (only
`amd_manager.c:675` and `intel_auxdevice.c:248` do), so
`bus->prop.err_threshold` stays 0 and `do_transfer()`'s
`for (i = 0; i <= retry; i++)` ([bus.c:241](src/kernel/drivers/soundwire/bus.c#L241))
makes **exactly one attempt** — a single flaky command is a hard `-EIO`.

## 2. Mechanism 1 — the master's clash report is one-shot

On `SWRM_INTERRUPT_STATUS_MASTER_CLASH_DET`
([qcom.c:708-716](src/kernel/drivers/soundwire/qcom.c#L708-L716)) the handler
clears `BIT(3)` in the software mirror `ctrl->intr_mask` and writes the reduced
mask to `SWRM_REG_INTERRUPT_CPU_EN`. The bit is restored in three places, and
**none of them is reachable on this board**:

| Restore site | Reachable here? |
|---|---|
| [qcom.c:844](src/kernel/drivers/soundwire/qcom.c#L844) — `intr_mask = RMSK` in `qcom_swrm_init()` | yes, but only on the next resume |
| [qcom.c:1701-1707](src/kernel/drivers/soundwire/qcom.c#L1701-L1707) — `else` branch of `swrm_runtime_resume()` | **no**, that is the clock-stop path (F2) |
| [qcom.c:887-891](src/kernel/drivers/soundwire/qcom.c#L887-L891) — `qcom_swrm_init()` writes CPU_EN | **no**, guarded by `if (ctrl->mmio)`, and this master is AHB (`mmio == NULL`) |

So after one clash the driver stops *reporting* clashes until the next
`SW_RESET`/`qcom_swrm_init()`. **The two master messages 51 s apart are one
report per resume cycle, not two clashes total** — how long the electrical
clash actually persisted is unobservable, because the counter was masked. This
is the upstream `671ca2ef12fe` workaround ("*sometimes hard reset does not clear
some of the registers, this sometimes results in firing a bus clash
interrupt*", present at [qcom.c:829-905](src/kernel/drivers/soundwire/qcom.c#L829-L905))
biting, because this board hard-resets the master on **every** runtime resume.

Two further defects in the same handler: the outer
`do { ... } while (intr_sts_masked)` loop
([678-803](src/kernel/drivers/soundwire/qcom.c#L678-L803)) is **unbounded**, and
`qcom_swrm_get_alert_slave_dev_num()` returns on the **first** alerting device
([538-545](src/kernel/drivers/soundwire/qcom.c#L538-L545)), so only the
lowest-numbered alerting slave is ever serviced.

## 3. Mechanism 2 — the storm has a bounded inner loop but no recovery

"Bus clash detected" is a plain `dev_err` at
[bus.c:1709](src/kernel/drivers/soundwire/bus.c#L1709); the only bits WSA881x
enables to report are clash and parity
([wsa881x.c:1176](src/kernel/sound/soc/codecs/wsa881x.c#L1176)), and the driver
has no `interrupt_callback`, so clashes are only logged.

The retry loop **is** bounded — `count < SDW_READ_INTR_CLEAR_RETRY` (= 10,
[bus.h:184](src/kernel/drivers/soundwire/bus.h#L184)), with
`Reached MAX_RETRY` at [bus.c:1844-1845](src/kernel/drivers/soundwire/bus.c#L1844-L1845).
One call prints at most 10 clash lines plus one MAX_RETRY, so 10,513 / 322 is
~1000 calls of which 322 exhausted the budget. The ack write to `SDW_SCP_INT1`
exists ([bus.c:1791](src/kernel/drivers/soundwire/bus.c#L1791)) — what is
missing is **recovery**: [bus.c:1713-1718](src/kernel/drivers/soundwire/bus.c#L1713-L1718)
is the upstream TODO saying clash/parity are "unlikely to be recoverable" and
that the bus should be reset. Nothing resets it, and the master's unbounded
outer loop keeps re-entering.

Rate sanity: 10,513 messages in 68 s is ~155/s. Given that one slave register
access costs two SLIMbus transactions plus 100 µs/250 µs sleeps, and a failed
one burns up to 30×500 µs, that is the expected speed of a slow software loop —
not a fast hardware interrupt storm.

There is also a **spurious-detach hazard**: the alert path refreshes only the
alerting device number in `ctrl->status[]`, leaving the others stale (often 0),
and `sdw_handle_slave_status()` treats a 0 as a real detach
([bus.c:1900-1910](src/kernel/drivers/soundwire/bus.c#L1900-L1910)). One amp
alerting can therefore mark the *other* amp unattached.

**Why the left amp and not the right (inferred).** The alert helper returns on
the first alerting device and the handler services only that one, so if both
were alerting the left (which held SoundWire device number 1 in the
`status was 2` line) would be serviced forever and the right **starved** — its
alerts never logged. "The right produced nothing" does not mean the right was
quiet. The physical origin of the left amp's stuck clash bit is not decidable
from the logs; the left amp is the one with the DTS `SD_N` hog workaround
([dtsi:1005-1025](src/kernel/arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4.dtsi#L1005-L1025),
WCD9340 GPIO1), and the concurrent master-side `read enable valid mismatch` is
at least consistent with a peripheral driving the shared data line out of turn.

## 4. Mechanism 3 — the UNATTACHED warnings are a bookkeeping mismatch

The warning is guarded by a **transition** test
([bus.c:1900-1903](src/kernel/drivers/soundwire/bus.c#L1900-L1903)):

```c
if (status[i] == SDW_SLAVE_UNATTACHED &&
    slave->status != SDW_SLAVE_UNATTACHED) {
	dev_warn(&slave->dev, "Slave %d state check1: UNATTACHED, status was %d\n", ...);
	sdw_modify_slave_status(slave, SDW_SLAVE_UNATTACHED);
```

so it fires when the master reads a slave as gone while the core still believes
it is attached (or alerting) — `status was 1` / `2` in the observed lines — and
then the bookkeeping stays `UNATTACHED` until a later full status read
re-attaches it ([bus.c:1950-1958](src/kernel/drivers/soundwire/bus.c#L1950-L1958)).

Only three callers exist in this path: the alert IRQ
([qcom.c:691](src/kernel/drivers/soundwire/qcom.c#L691)), attach/enumeration
([705](src/kernel/drivers/soundwire/qcom.c#L705)) and runtime resume
([1683](src/kernel/drivers/soundwire/qcom.c#L1683)). Neither
`sdm845_snd_hw_free`/`sdm845_snd_shutdown` nor the SoundWire stream teardown
calls it ([sdm845.c:473-577](src/kernel/sound/soc/qcom/sdm845.c#L473-L577),
[sdw.c:81-190](src/kernel/sound/soc/qcom/sdw.c#L81-L190)), so stream
start/stop cannot itself produce this warning.

The mechanism is the power/enumeration life-cycle (F3 + F4), **inferred** in its
timing allocation: runtime PM cuts an amplifier's power while the master is
still running, the bus notices the peripheral disappear and reports it against
bookkeeping the driver never updated when it cut the power; and at stream start
the master resumes **before** the amps, hard-resets and waits only 100 ms for
enumeration while both amps are still held in shutdown, so a zero status read is
compared against `status == ATTACHED`.

### What the measurements say

I tried to reproduce this deliberately and **could not**, which matters for
interpreting the counts:

| Experiment | `UNATTACHED` | `Bus clash` |
|---|---|---|
| 3 × `aplay -D hw:0,0` of 2 s digital silence | 0 | 0 |
| 3 × `pw-play` of digital silence through PipeWire, 8 s apart | 0 | 0 |
| `systemctl --user restart wireplumber` | 0 | 0 |
| `systemctl --user restart pipewire` | 0 | 0 |
| `pw-play` 44.1 kHz silence | 0 | 0 |
| `aplay -D hw:0,0` 44.1 kHz silence | 0 | 0 |

Zero messages for every case, and no SoundWire message of any kind. Combined
with the transition guard, the honest reading is: **the warning marks a
bookkeeping mismatch on a real detach/attach cycle, and it only prints when the
core's state has been re-armed to ATTACHED.** Once it has printed, the state
stays `UNATTACHED` and the same cycle is silent — so ~30 a day is the rate of
*re-armed* cycles, not the rate of detach/attach cycles, which is likely higher.
The pops themselves come from the amplifier power cycling (F3), not from the
warning being printed.

The storm is in the same category of evidence: it is correlated with unrelated
user activity (a new Chrome tab at 08:24:26, six seconds before the first master
clash), so the trigger is most plausibly the runtime-resume hard reset (F2)
landing on a bus that was already unhappy, not the activity itself.

## 5. The codec's own PA event is not the cause

`__soc_pcm_prepare()` runs the machine `.prepare`
(`sdw_prepare_stream` + `sdw_enable_stream`,
[sdm845.c:524-561](src/kernel/sound/soc/qcom/sdm845.c#L524-L561)) **before**
`snd_soc_dapm_stream_event(STREAM_START)`
([soc-pcm.c:929-949](src/kernel/sound/soc/soc-pcm.c#L929-L949)), so
`wsa881x_spkr_pa_event()`'s PRE_PMU
([wsa881x.c:912-978](src/kernel/sound/soc/codecs/wsa881x.c#L912-L978)) always
runs after the SoundWire ports are enabled — matching the hardware ordering note
in `sdm845_snd_prepare()`. It cannot be a direct cause of a clash. Our
`cecbd35ca830` adds one register read plus one read-modify-write of
`SPKR_DRV_GAIN` at that point, i.e. two more vendor access pairs exactly when
the master has just been reset and `err_threshold == 0` (F5) — an aggravator at
most, worth knowing but not a reason to avoid the patch.

## 6. Ranked options, with trade-offs

**H1 — coordinate the power/enumeration life-cycle (explains the pops).**
- **A (smallest, most direct):** drop the
  `gpiod_direction_output(wsa881x->sd_n, wsa881x->sd_n_val)` line from
  `wsa881x_runtime_suspend()`
  ([wsa881x.c:1201](src/kernel/sound/soc/codecs/wsa881x.c#L1201)), keeping only
  `regcache_cache_only(true)` + `regcache_mark_dirty()`. The amps stay
  enumerated, so no detach/attach per stream and no pop. **Trade-off:** ~10–30 mW
  standby per amp and the protection circuits stay powered; also masks genuine
  power-gating bugs.
- **B (more correct, more invasive):** give the core a way to be told "this
  peripheral is going off the bus", or re-arm `initialization_complete` in
  `wsa881x_runtime_resume()` so it always waits for a fresh ATTACH. Touches the
  SoundWire/WSA PM contract; resume gets slower when an amp is genuinely off.
- **C (master):** in `swrm_runtime_resume()`, do not treat a zero device-status
  read as a detach before the bus has enumerated; in `sdw_handle_slave_status()`,
  do not re-init `initialization_complete` for a slave with `dev_num == 0`. A
  genuinely dead amp would then be reported attached until a real CHANGE_ENUM.

**H2 — make the clash path recover (explains the 68 s, ~10k lines).**
- Re-arm `BIT(3)` after a bounded interval instead of clearing it permanently.
- Bound the outer `do/while` in `qcom_swrm_irq_handler()` (e.g. 16 iterations)
  and, on exhaustion, stop servicing and schedule re-enumeration.
- On `SDW_READ_INTR_CLEAR_RETRY` exhaustion with clash/parity set, do what
  [bus.c:1713-1718](src/kernel/drivers/soundwire/bus.c#L1713-L1718) says and
  reset the bus, or at least mask that slave's alert source until it
  re-enumerates. Trade-off: a brief audio drop versus hiding a real fault.
- Rate-limit the clash print ([bus.c:1709](src/kernel/drivers/soundwire/bus.c#L1709)
  is a plain `dev_err`).
- Refresh the whole `ctrl->status[]` in the alert path so one alert cannot
  spuriously detach the other amp.

**H3 — zero-risk cleanups.**
- Check `ctrl->reg_read()`'s return and initialise the destination everywhere
  (`550-565`, `531-548`, `698`, `878`); today a single failed AHB read (F1)
  injects garbage into `ctrl->status[]`.
- Set `bus->prop.err_threshold = 1..3` (or call `sdw_master_read_prop()` and add
  the DT property). Trade-off: up to ~15 ms extra per dead command.
- Serialise the AHB address-write/data-read pair; only `port_lock` exists today
  and the threaded IRQ races the ASoC path.
- Worth knowing: `trf on Slave 0 failed:-5` means `slave->dev_num == 0`, i.e. a
  read to a peripheral that was never enumerated; `0x311C` (`SPKR_DAC_CTL`, the
  RDAC widget) and `0x3103` (the Bandgap widget) are DAPM accesses, so DAPM is
  touching an amp before `qcom_swrm_set_slave_dev_num()` assigned it a number
  ([qcom.c:567-584](src/kernel/drivers/soundwire/qcom.c#L567-L584)).

**H4 — electrical/sequencing fault on the left amp.** Not decidable from kernel
logs. The cheapest experiment that separates it from H1 is to apply **H1-A** and
see whether the clashes stop; if they do, it was sequencing, not the amplifier.

## 7. What would settle the open questions

- Log `ctrl->clock_stop_not_supported` and `ctrl->intr_mask` at every
  suspend/resume: this confirms F2 and the one-shot clash mask directly instead
  of by derivation.
- Count attach/detach cycles rather than printed warnings: instrument
  `sdw_modify_slave_status()` so the real cycle rate is visible.
- Apply H1-A and re-measure both symptoms.

## 8. Upstream references

- `671ca2ef12fe` *soundwire: qcom: add software workaround for bus clash
  interrupt assertion* — the workaround already in this tree, whose premise
  ("hard reset does not clear some of the registers") is hit on every resume
  here.
- `32ac501957e5` *ASoC: codecs: wsa881x: set clk_stop_mode1 flag*, and the
  [alsa-devel thread](https://mailman.alsa-project.org/hyperkitty/list/alsa-devel@alsa-project.org/message/V6LPQ7SLXXFQFBLJOSTKQG5GXAXWT4IT/)
  where the "disable clock stop on v1.3.0" patch was rejected in favour of that
  flag because WSA881x does not retain state across clock stop — the reason
  `clock_stop_not_supported` is true here.
- [bus.c:1713-1718](src/kernel/drivers/soundwire/bus.c#L1713-L1718) — the
  upstream TODO acknowledging that clash/parity needs a bus reset.
