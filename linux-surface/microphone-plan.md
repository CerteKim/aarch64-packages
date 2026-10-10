# Built-in microphones: solved

Date: 2026-10-10
Scope: Xiaomi Book S 12.4 (SC8180X, SDM/8cx Gen 2 class) running the
`linux-mibook-mainline` 7.2 tree (`src/kernel-7.2`, branch
`xiaomi-mainline-7.2`).

**Final state: the built-in two-microphone array works.** It sits on the
WCD9340's DMIC0/DMIC1 inputs, both microphones answer (DMIC1 is the louder of
the two), the capture is a single mono source, and PipeWire records cleanly.
Two fixes were needed, and both are now in the AUR patch series
(`~/zcc-aur/packages/linux-mibook-mainline`, patches 0032 and 0033):

* the sound node's `audio-routing` must carry `"DMICn" -> "MIC BIASx"` and
  `"DMICn" -> "MCLK"` (device tree, patch 0032);
* the capture front end must be narrowed to S16_LE, exactly as the playback
  front end already was (machine driver, patch 0033).

The rest of this note is the record of how that was established, wrong turns
included — it went through several confident but incorrect conclusions before
the measurements settled it, and those wrong turns are the more useful part to
keep.

> **The one-off investigation tools are gone.** Everything referenced below as
> `tools/mic-*.sh` / `tools/capture-*.sh` (register forensics, format and
> channel matrices, state diffs) was diagnostic scaffolding and has been
> removed. Two scripts remain because they are useful in normal operation:
> `tools/install-ucm.sh` (installs the UCM profile) and `tools/mic-record.sh`
> (records the built-in microphone straight from ALSA, with an envelope
> printout and a listenable WAV).

## 1. What was wrong with the earlier conclusion

The previous round concluded "the only microphone on this machine is the one on
the 3.5 mm headset" from three observations:

1. Xiaomi's spec sheet lists "Dual speakers, 3.5 mm headphone jack" and no
   microphone.
2. `arecord -l` shows only the WCD9340 capture PCM.
3. Sweeping AMIC1..4 and DMIC0..5 showed AMIC flat and DMIC returning no data.

(1) and (2) are about *enumeration*, and they are expected: the built-in mics
are not separate ALSA/ACPI devices, they are inputs of the WCD9340, so they can
never appear in `arecord -l`. (3) is the substantive measurement, and it was
taken under a configuration in which the DMIC path could not work — see §3.

## 2. Hard evidence that the mics are on the codec

* **ACPI.** `~/acpi-dumps/dsdt.dsl` exposes exactly one audio codec path:
  `\_SB.ADSP.SLM1.ADCM.AUDD` (SPI4-attached), with children `MBHC`, `QCRT` and
  codec children `QCOM0437`/`QCOM042C`; `SLM2` has no children at all. There is
  no LPASS TX/VA macro device anywhere in the DSDT, so ACPI says the audio
  capture hardware the OS is meant to use is the codec, not a macro.
* **Vendor device tree.** In the local CodeLinaro checkout of Qualcomm's
  `msm-4.14`, branch `auto-kernel.lnx.4.14.c34` (the SC8180X / `sdmshrike`
  tree, see `vendor-ref/README.md`), `sdmshrike-audio-overlay.dtsi` declares
  for the WCD9340 sound card:

  ```
  "DMIC0", "MIC BIAS1", "MIC BIAS1", "Digital Mic0",
  "DMIC1", "MIC BIAS1", "MIC BIAS1", "Digital Mic1",
  "DMIC2", "MIC BIAS3", "MIC BIAS3", "Digital Mic2",
  "DMIC3", "MIC BIAS3", "MIC BIAS3", "Digital Mic3",
  "DMIC4", "MIC BIAS4", "MIC BIAS4", "Digital Mic4",
  "DMIC5", "MIC BIAS4", "MIC BIAS4", "Digital Mic5",
  ```

  with `qcom,cdc-dmic-sample-rate = <4800000>` on the codec. The same file also
  wires AMIC2..AMIC5 to the headset/ANC/handset mics, which is the analogue
  side of the same codec.
* **Silicon layout.** The WCD9340 has six DMIC inputs grouped into three clock
  pairs (0/1, 2/3, 4/5), each with its own PDM clock register
  (`WCD934X_CPE_SS_DMIC0/1/2_CTL`). Two microphones flanking the camera is
  exactly the layout this supports.
* **The board's own audio DTSI heritage.** The Xiaomi Book sound node was
  written from the Lenovo Yoga C630 (SDM850 + WCD9340 + WSA881x) description,
  and the C630's built-in microphones are on the codec's DMIC pins. The
  `AMIC2`/`MIC BIAS2` routing that came along with it is the headset mic.

## 3. Why DMIC0..DMIC5 returned no data

The codec driver has no built-in `DMICn -> MIC BIASx` routing: those routes
have to come from the machine's `audio-routing` property. Ours has only
`"AMIC2", "MIC BIAS2"`.

ASoC builds its DAPM graph from `audio-routing`, and a digital MEMS microphone
needs two things that graph is responsible for:

| Need | Route that supplies it | Effect of it being absent |
| --- | --- | --- |
| Power (mic bias) | `"DMICn", "MIC BIASx"` | bias rail never powers up; mic is dead |
| A consumer for the bias widget | `"MIC BIASx", "Digital Mic n"` | bias has no sink, so it still does not power up |
| PDM clock | DAPM powering the `DMICn` widget runs `wcd934x_codec_enable_dmic()` | `WCD934X_CPE_SS_DMICn_CTL` is never enabled |

So in the state the sweep was run in there was no bias, no PDM clock and no
powered input. "No data at all" (rather than a flat noise floor, which is what
AMIC showed) is exactly what an unpowered digital input looks like, and is
*consistent with* the mics being there.

The AMIC rows in the same sweep were valid — AMIC2 did have its bias route —
and they were flat, which is the actual evidence that the internal array is not
on the analogue inputs.

## 4. What was changed

`src/kernel-7.2/arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4.dts`, in the
`sound` node:

* Added the six DMIC bias routes for **all three pairs**
  (DMIC0/1 -> MIC BIAS1, DMIC2/3 -> MIC BIAS3, DMIC4/5 -> MIC BIAS4), so the
  input can be identified in a single boot. Which pair the array is on is not
  public, and the vendor DT wires all six.
* The `AMIC2`/`MIC BIAS2` headset route is untouched.
* The whole change is inside the `audio-routing` property; no driver change is
  needed and nothing else in the tree moves.

The DTB was rebuilt (`make ARCH=arm64 qcom/sc8180x-xiaomi-book-12.4.dtb`) and
verified to carry the new strings with `fdtget`.

### 4.1 The first revision killed the sound card (fixed, 2026-10-10)

The first revision also copied the vendor DT's companion routes:

```
"MIC BIAS1", "Digital Mic0",  ...  "MIC BIAS4", "Digital Mic5",
```

and the machine driver rejected every one of them:

```
msm-snd-sdm845 sound: ASoC: Failed to add route Digital Mic0(*) -> MIC BIAS1
```

`Digital Mic0..5` are DAPM widgets *of Qualcomm's downstream machine driver*;
mainline has no such widget, for any codec or board. The consequence was much
worse than a cosmetic error: a failed route makes
`snd_soc_dapm_add_routes(card->of_dapm_routes)` return an error, and
`snd_soc_register_card()` aborts on it — so the **whole card** failed to
register (`/proc/asound/cards` reports "no soundcards", `alsamixer` says
"cannot find card '0'"), taking the speakers with it.

Those six routes are therefore **not** part of the fix and must not be added.
The codec driver's own `"DMICn", NULL, "DMICn Pin"` route already models the
physical input, and `MIC BIASn` is a supply widget, so `"DMICn", "MIC BIASn"`
alone both powers the rail and — by powering the `DMICn` ADC — enables the PDM
clock.

The second revision keeps only the six bias routes; the DTB was rebuilt.
`DMIC0..5`, `AMIC2`, `RX_BIAS`, `MCLK`, `SpkrLeft/Right IN`, `SPK1/2 OUT` and
`MIC BIAS1..4` were each checked to exist as widgets in `wcd934x.c` /
`wsa881x.c` before rebuilding.

**Whenever `audio-routing` is edited, boot first and check
`dmesg | grep ASoC` and `/proc/asound/cards` before anything else** — a single
bad route is card-fatal, not a warning.

## 5. How to confirm on hardware

```
# DTB: keep a backup, drop the new one in, reboot
sudo cp /boot/dtb/linux-mibook-mainline/qcom/sc8180x-xiaomi-book-12.4.dtb \
        /boot/dtb/linux-mibook-mainline/qcom/sc8180x-xiaomi-book-12.4.dtb.pre-dmic
sudo cp src/kernel-7.2/arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4.dtb \
        /boot/dtb/linux-mibook-mainline/qcom/sc8180x-xiaomi-book-12.4.dtb
sudo reboot

# then, on the desktop session
./tools/mic-dmic-probe.sh
```

`tools/mic-dmic-probe.sh` walks DMIC0..DMIC5, capturing a silent window (sink
muted, so playback crosstalk cannot fake a response) and then a 2 kHz tone
window, and reports the tone magnitude per channel. A live input shows its
2 kHz magnitude far above the silent window; an unwired one does not.

Expected outcomes:

| Result | Meaning | Next step |
| --- | --- | --- |
| One pair RESPONDS | that pair is the array | keep only its two routes, drop the rest |
| One *channel* responds | one of the two mics, or a mono feed | same, then sort out stereo in UCM |
| All three flat | see §5.1 before concluding anything about wiring | register evidence, then §7 |

`amixer -D hw:0 cget 'name=ADC MUX0'`-style names used by the script are the
codec's own: `ADC MUX0` (ZERO/AMIC/DMIC), `DMIC MUX0` (ZERO/DMIC0..DMIC5),
`CDC_IF TX0 MUX` (DEC0..DEC8), and the `AIF1_CAP Mixer SLIM TX0` capture-backend
switch the machine driver exposes.

### 5.1 First hardware run: all three pairs flat (2026-10-10)

`tools/mic-dmic-probe.sh` ran with the bias routes in place and reported:

| pair | silent 2 kHz mag (L/R) | tone 2 kHz mag (L/R) | RMS |
| --- | --- | --- | --- |
| DMIC0 | 3045 / 4418 | 7513 / 3087 | ~2.8e6 |
| DMIC1 | 1815 / 1986 | 2059 / 5109 | ~2.8e6 |
| DMIC2 | 3939 / 3222 | 8862 / 4883 | ~2.8e6 |
| DMIC3 | 2236 / 6805 | 5925 / 6030 | ~2.8e6 |
| DMIC4 | 0 / 0 | 0 / 0 | 1 |
| DMIC5 | 0 / 0 | 0 / 0 | 1 |

So DMIC0..3 are a constant noise floor (the huge RMS with a tiny 2 kHz
magnitude is a DC/offset-dominated floor, not signal) and DMIC4/5 delivered
essentially no samples. Nothing followed the tone.

**This still does not establish where the microphones are.** A capture can be
flat because the array is elsewhere, or because the input was never actually
powered — and PCM data cannot tell those apart. One concrete suspect was found
by reading the DAPM graph rather than the data:

* The codec's PDM clock is derived from the codec's **MCLK** supply widget, and
  `wcd934x_codec_enable_dmic()` only *programs a divider* — it does not turn
  MCLK on.
* MCLK is powered solely by the machine route `"RX_BIAS", "MCLK"`, and
  `RX_BIAS` is a *playback* supply. A capture-only stream never touches it.
* So on a capture-only stream MCLK — and with it the codec's system clock, the
  analog bias and the PDM clock — was plausibly never running, and the divider
  writes were going nowhere.

That is why the second revision adds `"DMICn", "MCLK"` alongside
`"DMICn", "MIC BIASx"`: the DMIC widget now powers the codec clock it needs.
This is a hypothesis with a mechanism, not a proven fix, which is why the
register window below exists.

`tools/mic-regs.sh` (needs the instrumented codec module, §5.2) reads the codec
while a DMIC capture is live and answers the question directly:

| register | what it proves |
| --- | --- |
| `ANA_MICB1/3/4` (0x0622/0x0625/0x0626) | `0x50` = rail on at 1800 mV, so a flat capture is real; `0x10` = voltage programmed but rail off; `0x40` = enabled at 0 V |
| `CLK_SYS_MCLK_PRG` (0x0711) | bit 0 set = the codec's MCLK is actually programmed on |
| `CPE_SS_DMIC0/1/2_CTL` (0x0218/0x0219/0x021a) | bit 0 set = the PDM clock is running |
| `ANA_BIAS` (0x0601) | bit 7 = analog bias on |
| `TX0_PATH_CTL/CFG0`, `INP_MUX_ADC0_CFG0/1` | which input ADC MUX0 is really pointed at |

If none of those move between idle and capturing, the DAPM path never powered
and the PCM result is void — do not conclude anything about wiring from it.

#### Idle state, observed on hardware

The first successful read (stock state, no capture running) gives a baseline to
compare the capture-time dump against — and it is all "off", as it should be:

| register | idle | reading |
| --- | --- | --- |
| `ANA_MICB1` / `ANA_MICB4` | `0x10` | voltage field = 1800 mV, enable = 0 → rail off |
| `ANA_MICB2` / `ANA_MICB3` | `0x25` | enable = 1, voltage field maximum — MBHC headset detection owns MIC BIAS2 |
| `ANA_BIAS` | `0x80` | configured, bit 7 = 0 → off |
| `CODEC_RPM_CLK_MCLK_CFG` | `0x01` | MCLK = 9.6 MHz selected |
| `CLK_SYS_MCLK_PRG` | `0x91` | bit 0 = 0 → MCLK **not** enabled |
| `CPE_SS_DMIC0/1/2_CTL` | `0x04` | bit 0 = 0 → PDM clock **not** running (divider field already written) |
| `INP_MUX_ADC0_CFG0/1` | `0x31` / `0x01` | ADC MUX0 sits on AMIC1, not a DMIC |

So in the idle state the codec clock, the analog bias and the PDM clock are all
genuinely off, which is correct — and it means the capture-time dump is the only
one that can settle the question.

#### "No data" on DMIC4/5, corrected

The probe's byte column showed DMIC4/5 did produce a full-size capture
(1.7 MB); the samples are just ~0. That is the DSP idle pattern, not a missing
capture, so DMIC4/5 read "flat because the path was never opened" rather than
"never captured".

#### Capture-time dump — the answer (2026-10-10)

`tools/mic-regs.sh` was run over DMIC0..3 with the instrumented module. The
driver's own log lines and the registers during capture:

```
XIAOMI-AUDIO: init_dmic rate=4800000 mclk=9600000 vout=16/37/37/16 mv=1800/2850/2850/1800
XIAOMI-AUDIO: DMIC0 on mclk=9600000 fs=2400000 val=0x2 cnt=1 reg=0x218
XIAOMI-AUDIO: DMIC2 on mclk=9600000 fs=2400000 val=0x2 cnt=1 reg=0x219
```

| register | idle | capturing DMIC0 | capturing DMIC2 | verdict |
| --- | --- | --- | --- | --- |
| `ANA_MICB1` | `0x10` | **`0x50`** | `0x10` | bias rail **on at 1800 mV** for DMIC0/1 |
| `ANA_MICB3` | `0x25` | `0x25` | **`0x65`** | rail **on** for DMIC2/3 |
| `ANA_MICB4` | `0x10` | `0x10` | `0x10` | (only read for DMIC4/5, not captured here) |
| `CPE_SS_DMIC0_CTL` | `0x04` | **`0x05`** | `0x04` | **PDM clock running** for DMIC0/1 (4.8 MHz) |
| `CPE_SS_DMIC1_CTL` | `0x04` | `0x04` | **`0x05`** | **PDM clock running** for DMIC2/3 |
| `TX0_PATH_CFG0` | `0x50` | **`0xd0`** | **`0xd0`** | bit 7 = TX0 source switched to **DMIC** |
| `TX0_PATH_CTL` | `0x04` | `0x24` | `0x24` | TX0 running |
| `INP_MUX_ADC0_CFG0` | `0x31` | `0x09` (DMIC0) | `0x19` (DMIC2) | ADC MUX0 correctly on the DMIC |
| `INP_MUX_ADC0_CFG1` | `0x01` | `0x00` | `0x00` | DMIC select |

(`CLK_SYS_MCLK_PRG` stayed `0x91`, bit 0 clear — the codec's MCLK-generator bit
apparently stays off while it runs from the external MCLK, since every clocked
path below it works.)

Everything the codec needs to receive audio on a DMIC input was verified
powered and routed: the MIC BIAS rail was enabled at 1.8 V, the PDM clock was
running with the expected divider, the TX path was switched to its DMIC source,
and the ADC MUX was pointed at the right input. The captures still came back
with no response to sound on **both** pairs.

**Conclusion: the built-in microphones are not reachable through the WCD9340's
DMIC inputs.** With the whole path demonstrably powered, an electrical
connection would have produced signal. The earlier "there are no microphones on
the codec" observation was right about the codec; it was wrong about the
machine.

## 6. Where the microphones probably are, and why it is not reachable

The microphones are digital MEMS parts; they exist and are on some PDM bus the
codec does not own. The mechanisms a Snapdragon 8cx tablet normally uses, and
what is known about each here:

| candidate | status |
| --- | --- |
| WCD9340 `DMIC0..DMIC5` | **ruled out** — see the capture-time dump above |
| LPASS **VA macro** DMIC pins | plausible (that is how the sibling SC8280XP X13s/Arcata designs do it), but: `sc8180x.dtsi` has **no** macro nodes, ACPI exposes **none**, and Qualcomm's own SC8180X (`sdmshrike`) device tree has no `lpass_va`/`tx_macro`/`lpass_rx` node either — the only audio block it describes is the WCD9340 on SLIMbus |
| LPASS **TX macro** DMIC pins | same as above |
| a GPIO/PMIC-gated analogue path | no such node or supply exists in the vendor tree or the DSDT |

So the remaining candidate requires hardware documentation this project does not
have (the mic-to-macro routing and the VA/TX macro register map for SC8180X),
plus a machine driver extension (`sdm845.c` has no VA/TX macro DAI links — only
`sound/soc/qcom/lpass-sc7280.c` and `sc7180.c` use those macros at all), plus
UCM work. That is a project, not a patch, and it is not possible to confirm even
the premise (that the array is on a macro) without probing the LPASS registers
or a schematic.

**Practical position: use a headset with a microphone (already works through
`AMIC2`/`MIC BIAS2`), a USB headset, or the keyboard cover's own audio. The
built-in array stays unsupported.**

## 6.1 The Windows partition says the array is on the codec (2026-10-10)

`/mnt/win` (the Windows 11 install, ntfs3, read-only) carries the complete
Qualcomm audio stack, and it contradicts the "not on the codec" conclusion
above. What is there:

* **The array is enumerated.** `/mnt/win/Windows/System32/config/SYSTEM`
  (extract with `strings -e l -n 5`, then grep) contains:

  ```
  Internal Microphone Array - Front
  Internal Microphone Array - Front (Qualcomm(R) Aqstic(TM) Audio Adapter Device)
  QCAUD Wave Microphone Array - Front
  QCAUD Topology Bluetooth HFP Microphone
  QCAUD Wave Handset Microphone
  QCAUD Wave Microphone Headset
  QCAUD Wave USBC Headset Microphone
  ```

  So the built-in array is a single Windows capture endpoint named
  "Microphone Array - Front" (there is no "- Rear" on this machine), alongside
  the handset/headset/BT/USB-C ones.

* **Its device path is the codec's ACPI node.**
  `ACPI(_SB_)#ACPI(ADSP)#ACPI(SLM1)#ACPI(ADCM)#ACPI(AUDD)`, hardware IDs
  `ADCM\VEN_QCOM&DEV_0425&SUBSYS_CLS08180` / `ADCM\QCOM0425`, bound to
  `oem48.inf` = `qcauddev8180.inf` → "Qualcomm(R) Aqstic(TM) Audio Device".
  The DSP side is a *child* of it: `AUDD\QCOM042C` →
  "Qualcomm(R) Aqstic(TM) Audio Adapter Device" (`qcaudminiport8180.sys`), and
  the voice/sound-model extension `qclistensm8180.inf` binds to the same
  `AUDD\QCOM042C`.

* **The only codec-specific microphone calibration is a digital one.**
  In
  `.../qcacsp_cls8180.inf_arm64_b4ce06a0776383a6/Codec_cal.acdb` (the
  "Audio Calibration Settings" package for the ACDM/ACDB), grepping the ACDB
  calibration keys out of the binblob gives, **uniquely in this file**:

  ```
  WDMICDFT  WDMICDOT  WDMILUT0      <- Wideband DMIC (digital mic) block
  WMCACDFT  WMCNCDFT  WMIDCDFT  WSGCCDFT   <- speaker / analog-mic blocks
  CDCNAME   CCDB
  ```

  Cross-check: the `WDMIC*`/`WMC*` block appears **only** in
  `Codec_cal.acdb` (15 keys) and in none of `Bluetooth/General/Global/Handset/
  Hdmi/Headset/Speaker_cal.acdb`; the `LSMIC*` keys show up in *all* of them
  because they are generic listen/sound-model parameters.
  `qcom,cdc-dmic-sample-rate = <4800000>` in the vendor DT is the 4.8 MHz the
  live `CPE_SS_DMICn_CTL` registers already program.

  A codec-only calibration blob carrying a Wideband-DMIC block is what
  ACDB generates for a product whose digital microphones are wired to that
  codec. That is direct product-configuration evidence, and it agrees with the
  vendor `sdmshrike` device tree that wires all six DMIC inputs.

* **The SLIMbus wiring is confirmed independently.** `qcslimbus8180.inf`:

  ```
  HKR,SLM1, "MasterEA",        0x00,0x00,0xA0,0x02,0x17,0x02   <- 0217:0250, the WCD9340
  HKR,SLM1\CHLD, "0", "SLM1\QCOM0424"
  HKR,SLM1, "BamBaseAddr",     0x17184000                      <- matches our slimbam
  HKR,SLM2, "BamBaseAddr",     0x17204000, NumChld 0
  ```

  i.e. SLM1 (0x171c0000, irq 0xC3) carries the codec and has BAM DMA, while
  SLM2 (0x17240000, irq 0x143) has **no children** — the same picture our DT
  has.

* **What is *not* there:** the ACDB is encrypted/proprietary
  (`workspaceFile.qwsp` is opaque, and the packed `.acdb` files do not expose
  device IDs in plain form), and the Windows side has **no AFE/DSP port
  configuration** — that lives in the ADSP firmware and in the DSP's own
  routing payload, not in the driver package. So the Windows tree cannot tell
  us *which* AFE port or DMIC pair the array uses.

### What this changes

It moves the verdict from "not reachable through the codec" to **"the array is
almost certainly on the WCD9340's DMIC pins, and our capture path is missing
something Windows does"** — because a product-configuration file calibrates a
Wideband DMIC on this codec. The codec-side registers we verified
(§5.1: bias 1.8 V, PDM clock running at 4.8 MHz, TX0 switched to its DMIC
source, `ADC MUX0` = DMIC with `DMIC MUX0` = DMIC0) are then *necessary but not
sufficient*.

The most likely missing piece is one of:

1. a codec/DSP **enable or port setup performed by the ADSP side** that the
   downstream `msm-pcm-afe` / `q6afe` routing does and the mainline
   `MultiMedia2 → SLIMBUS_0_TX` route does not (the Windows graph has an
   "Audio Adapter Device" and a sound-model extension sitting on top of the
   same AUDD node, i.e. there is a DSP-level capture path above the codec);
2. the **other DMIC pair** combined with that setup — all three pairs were
   probed without it, so the pair question is unresolved again;
3. a codec input-configuration detail (DMIC clock drive / pad config,
   `WCD934X_TEST_DEBUG_PAD_DRVCTL_0`) that the early-return path skips.

None of these is settled. What *is* settled is the direction, and it is now
worth more experiments on the codec rather than the LPASS-macro rewrite
proposed in §6.

## 6.2 It works — captured through ALSA (2026-10-10)

`tools/capture-bytes.sh` was switched to capture with `arecord -D hw:0,1`
(ALSA direct) instead of `pw-cat`, on the same DMIC0 route, and the two
datasets are not the same signal at all:

| | pw-cat (PipeWire) | arecord (ALSA) |
| --- | --- | --- |
| DC offset | ~2.8e6 (a third of full scale) | **~0–500** |
| `\|Δ\|avg` vs AC RMS | equal → **white noise** | an order of magnitude lower → **smooth audio** |
| over 7.4 s | identical in every window | **31–36k quiet, rising to 61–95k when the user spoke** |
| distinct values / 0.25 s | always 766 | 600–700 idle, 1000–1700 while speaking |

The ALSA capture's 0.5 s envelope follows the user's voice exactly
(`tools/mic-record.sh`: 32k ambient → 93k while talking, ~2.9x), and its low
byte in every 4-byte slot is `0x00`, confirming S24_LE left-justified is the
right parse.

**Conclusion: the built-in microphone on the WCD9340's DMIC0 works, and the
whole chain (codec DMIC → MIC BIAS1 → SLIM TX0 → ADSP → MultiMedia2 → ALSA) is
functional.** The "constant full-scale white noise" that drove every earlier
wrong conclusion was an artefact of the *PipeWire* capture path — the same
input through `pw-cat` never produced usable samples, which is also why
`@DEFAULT_AUDIO_SOURCE@` showed up muted at volume 0.

So what remains is not a hardware or codec problem:

1. **PipeWire/ALSA userspace capture path** — the reason the microphone looks
   dead to every application. This is exactly what the missing UCM profile
   would fix (an "Internal Microphone" device pointing at `hw:0,1` with the
   right format), and it is the reason `tools/*.sh` must use `arecord` for
   measurement until it exists.
2. **Gain/level** — ambient sits around -48 dBFS, speech peaks around -42 to
   -38 dBFS, so a digital-gain stage (ADC/TX volume) is needed before it is a
   usable recording level.
3. **Which inputs are live** — only DMIC0 has been confirmed. DMIC1 shares the
   same PDM clock and bias rail, so re-checking it with `arecord` is cheap and
   now meaningful (the earlier "DMIC1 flat" verdict came from the same broken
   pw-cat path and is void).

The device-tree work already in place (DMIC0/DMIC1 bias + MCLK routes) is what
makes this possible; no further kernel change is needed for capture.

### Both microphones work; the array is mono

DMIC1 answers too (louder than DMIC0), so both halves of the array are present
on the one PDM pair.  Two further measurements:

* **The capture stream is mono.**  Analysing an `arecord` capture gives
  `ch0 == ch1`, correlation `+1.000`, because both inputs go through the same
  decimator (`DMIC MUX0` -> `ADC MUX0` -> `CDC_IF TX0 MUX = DEC0`).
* **A second channel is not reachable through the codec.**  Routing DMIC1 via
  `ADC MUX1`/`DMIC MUX1` -> `CDC_IF TX1 MUX = DEC1` -> `AIF1_CAP Mixer SLIM
  TX1` (tools/mic-stereo-map.sh) gives `ch1 AC ~= 0` with `ch0` at full scale
  and correlation `+0.61`: the backend carries only SLIM TX0 for this card.
  Real stereo therefore needs the DSP-side channel map plus a machine-driver
  change, not a codec mux.  The profile exposes a single-channel array.

**Gain**: with DMIC1 and the capture gain at +20 dB, ambient alone sat near
-5 dBFS -- the first listen was "loud noise" partly for that reason.  The UCM
enable sequence therefore sets `DEC0 Volume` to 84 = 0 dB and leaves the rest
to the session, rather than pinning a large digital gain the way the playback
side once was.

### Why PipeWire capture was white noise: the channel count

`pw-record`/`pw-cat` returned full-scale white noise on the same route that
`arecord -c 2` captured cleanly, and the cause turned out to be the UCM profile
itself -- the first revision declared `CaptureChannels 1`.  The capture stream
is **S24_LE stereo**, and `sdm845_slim_snd_hw_params()` derives its SLIM TX
channel map directly from the count ALSA asks for:

```c
tx_ch_cnt = min_t(u32, channels, ARRAY_SIZE(sdm845_wcd934x_tx_ch));
```

so a mono open mis-describes the sample layout and the session receives
byte-offset data -- white noise.  `/proc/asound/card0/pcm1c/sub0/hw_params`
showing `channels: 1` during the noisy capture is the fingerprint.
`CaptureChannels 2` is therefore required, not cosmetic; the session then
downmixes to mono for applications that ask for it.  (`CHAN=1
./tools/mic-record.sh` reproduces the broken case on the ALSA path, which is
how the mechanism was confirmed without PipeWire in the loop.)

### Next experiments (cheap, one boot each)

1. **Ask Windows.** Boot Windows, check Settings → Sound → Input for
   "Microphone Array - Front", and confirm it actually records. That confirms
   the array is alive and on this codec.
2. **Sweep DMIC pairs again with a longer capture and a louder source**
   (`tools/mic-dmic-probe.sh`, `SEGS=4`), now that the DAPM routes exist —
   specifically DMIC0/DMIC1 vs DMIC2/DMIC3, and check the *left/right split*;
   a two-microphone array often lands as one channel per pair.
3. **Probe `WCD934X_TEST_DEBUG_PAD_DRVCTL_0` and the DMIC clock-drive field**
   through `/sys/kernel/debug/wcd934x/regs` (`echo w <reg> <val>`) while
   capturing. This is exactly the register the early-return in
   `wcd934x_init_dmic()` (6.18 wording; in 7.2 it is
   `wcd_dt_parse_micbias_info()`) historically skipped, and it controls the
   DMIC pad drive strength — a wrong value here can leave a digital mic
   unable to drive the data line even though the clock and bias are correct.
4. Only if all of that is flat: treat the DSP-side AFE port path as the
   suspect and compare against the downstream `msm-pcm-afe` graph.

### 5.2 The instrumented codec module

`src/kernel-7.2/sound/soc/codecs/wcd934x.c` carries temporary bring-up
instrumentation (clearly marked, meant to be dropped before shipping):

* `dev_info("XIAOMI-AUDIO: ...")` in `wcd934x_init_dmic()` (rate, MCLK, the
  parsed MIC BIAS voltages) and in `wcd934x_codec_enable_dmic()` (which DMIC
  powered, at which MCLK/FS, which divider value, which register).
* `/sys/kernel/debug/wcd934x/regs` — dumps the registers above and accepts
  `echo r <reg>` / `echo w <reg> <val>` for ad-hoc pokes.

Build and install. Two things bite here:

* the 7.2 worktree has no `vmlinux.o`, so an in-tree single-module build fails at
  modpost — either build the whole `modules` target once (`make -j8 ARCH=arm64
  modules`, ~1 h on this machine, which was done), or build against the
  installed head as below;
* the vermagic has to come out exactly `7.2.0-1-mibook-mainline`. Building from
  the worktree produced `7.2.0+` (dirty tree, no `localversion.*`), which
  `modprobe` refuses. The recipe that works uses the **installed** build tree —
  which is also where its `Module.symvers` and `localversion.*` live — as the
  head, and does *not* pass `O=` to an empty directory (that fails for lack of
  `include/config/auto.conf`):

```
KDIR=/usr/lib/modules/7.2.0-1-mibook-mainline/build
SRC=$PWD/src/kernel-7.2/sound/soc/codecs
D=/tmp/mod72; mkdir -p $D; cp $SRC/wcd934x.c $D/
printf 'obj-m := snd-soc-wcd934x.o\nsnd-soc-wcd934x-y := wcd934x.o\nccflags-y += -I%s -I%s/../common\n' \
    "$SRC" "$SRC" > $D/Makefile
make -C "$KDIR" M=$D ARCH=arm64 modules
modinfo $D/snd-soc-wcd934x.ko | grep vermagic     # must be 7.2.0-1-mibook-mainline
```

A ready-built copy of exactly that module is staged in `build/mic-diag/`
(md5 `6ba5ef6d681c2ee8ceb9fec300c70bf5`), with install/uninstall/rebuild notes
in `build/mic-diag/README.md`:

```
M=/usr/lib/modules/7.2.0-1-mibook-mainline/kernel/sound/soc/codecs
sudo cp -a $M/snd-soc-wcd934x.ko $M/snd-soc-wcd934x.ko.stock
sudo install -Dm644 build/mic-diag/snd-soc-wcd934x.ko $M/snd-soc-wcd934x.ko
sudo modprobe -r snd_soc_sdm845 snd_soc_wcd934x && sudo modprobe snd_soc_sdm845
```

## 6. Codec nits found while doing this (not blockers)

* In this tree `wcd934x_init_dmic()` calls `wcd_dt_parse_micbias_info()` (not
  `wcd_dt_parse_mbhc_data()` as in 6.18), so the MIC BIAS *voltage* fields are
  programmed at probe. The `dev_info` line added above prints what it computed,
  which is how to tell that apart from an unpowered rail.
* `wcd934x_codec_parse_data()` reads the DMIC rate from
  `dev->parent->of_node` as `qcom,dmic-sample-rate`, while the binding documents
  it on the codec child as `qcom,cdc-dmic-sample-rate`. The value is then
  overwritten by the 9.6 MHz-MCLK default in `wcd934x_init_dmic()` anyway. On
  this board both paths end up at 4.8 MHz, so this is cosmetic — but it means
  the property is not doing anything.
* These are worth a separate cleanup patch; neither has to be fixed for capture
  to work.

## 7. If the codec's DMIC pins turn out to be empty

Then the array is on the LPASS digital-mic interface, and that is a real
project rather than a device-tree line change:

* `sc8180x.dtsi` has **no** LPASS macro nodes at all — no `lpass-tx-macro`, no
  `lpass-va-macro`, no `lpass-wsa-macro`, no `q6afecc`/`q6prmcc` clock
  controller, and no TX soundwire controller. Mainline's `sdm845.c` machine
  driver (which this board uses) has no VA-macro DAI links either.
* The macro register blocks themselves should be SM8250/SC8280XP-compatible
  (`txmacro@3220000`, `vamacro@3370000` on those SoCs), but the SC8180X
  addresses, clocks, resets and the ADSP front-end IDs would all have to be
  established, and no upstream machine driver matches this combination.
* Nothing in the DSDT or the vendor `sdmshrike` device tree suggests this is
  the case for SC8180X, which is why the codec hypothesis is the one to test
  first.
