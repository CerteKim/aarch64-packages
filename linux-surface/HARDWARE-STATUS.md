# Xiaomi Book S 12.4 (SC8180X) — Linux hardware status

Board: `xiaomi,book-12.4` / `TM2133`, BIOS `XM28C2B0P16`, Qualcomm SC8180X
(Snapdragon 8cx Gen 2). Kernel: `linux-mibook` (6.18.2) from this repo.

## Working

| Subsystem | Driver / notes |
|---|---|
| Display | CSOT PNC357DB1-4 panel via Himax HX83121A, msm_dpu + DSI, pmc8180c WLED backlight |
| GPU | Adreno 680 (`adreno`, `msm`), ZAP shader `qcom/XIAOMI/BOOK124/qcdxkmsuc8180.mbn` |
| Wi-Fi | WCN3990 (`ath10k_snoc`), fw `WLAN.HL.3.2.0.c8-…`. Random MAC each boot (`regulatory.db` now installed) |
| NVMe | PCIe2 x2 lanes |
| microSD | `sdhc_2` |
| USB | 3x DWC3 + UCSI/pmic-glink, 2x USB-C, Pericom PI3USB102 SBU muxes |
| Touchscreen | HID-over-I2C `0018:4858:121A` @ i2c1/0x4f (irq tlmm 122), incl. stylus collection |
| Keyboard/touchpad | Detachable cover over USB (`2717:5032`, SINO WEALTH) |
| Battery/charger | `qcom-battmgr` (pmic-glink) |
| Thermal | `qcom-tsens` (2), `qcom-lmh`, 14 thermal zones |
| RTC / lid / power key | `rtc-pm8xxx`, gpio-keys (tlmm 121) |
| Remoteprocs | ADSP, CDSP, MPSS all running |

## Fixed in the `xiaomi-bringup` branch

### Bluetooth (WCN3998)

The running kernel asked for `qca/crbtfw01.tlv`, which has never existed.

`btqca.c` decoded the chip's ROM version with the generic mask. The chip
reports ROM version `0x1001`, and `get_soc_ver()` yields `0x02241001`, so the
generic formula extracted `0x01` instead of `0x21`. WCN3998 uses a different
bit layout (upstream commit `99b2c531e0e7`, "Bluetooth: qca: fix ROM version
reading on WCN3998 chips").

With the fix the driver requests `qca/crbtfw21.tlv` + `qca/crnv21.bin`, both
already installed by `linux-firmware`. The linux-surface project works around
the same bug with `crbtfw01.tlv -> crbtfw21.tlv` symlinks; these are no longer
needed.

Note: even in ROM mode `hci0` comes up, but with no patch/NVM and a bogus BD
address. After the fix, set the address if the NVM still has none:

```
btmgmt --index 0 public-addr <your-mac>
```

### Audio (WCD9340 + WSA881x) — WORKING

Confirmed on hardware: audio plays through the speakers. The kernel side is
complete; the remaining requirement is a userspace mixer/UCM profile
(`./xiaomi-book-12.4-audio-init.sh`, then `sudo alsactl store`).

Topology, confirmed by the public SC8180X work
(`gitlab.com/sc8180x-mainline/linux`, branch `6.6.0-audio-wip`, and the
Lenovo Flex 5G audio DT): a **WCD9340 on SLIMbus** (`slim217,250`) for the
headset and microphone, plus **two WSA881x amplifiers on the WCD9340's
internal SoundWire master** (`soundwire@c85`, `qcom,soundwire-v1.3.0`).
This is the SDM845/SDM850 "tavil + WSA8810" arrangement — *not* WCD9385 and
*not* an LPASS SoundWire master.

Enabled by the branch:

* APR/Q6 services (`q6core`, `q6afe`, `q6asm`, `q6adm`/`q6routing`) on the ADSP
  glink channel.
* LPASS SLIMbus (`slimbam@17184000` + `slim-ngd@171c0000`) and the WCD9340,
  including its GPIO controller and internal SoundWire master.
* Both WSA881x amplifiers.
* Machine driver quirks in `sdm845.c`: SLIM RX/TX channel-map fallback and
  `S24_LE` on `SLIMBUS_0_RX` (Windows declares 48 kHz/24-bit for the speakers).
* Codec-side SLIM RX pre-seed in `wcd934x.c` (there is no UCM profile yet, so
  nothing sets the `SLIM_RX` DAPM muxes).
* `slimbus/qcom-ngd-ctrl.c`: re-run the slave notification on every capability
  message. The first SAT can arrive before `slim_register_controller()` has
  registered the DT children, in which case they never get a logical address.

### Verified on hardware

A boot of the first build confirmed:

* `card 0: X124 [Xiaomi Book 12.4]` registers, with `MultiMedia1` (device 0)
  and `MultiMedia3` (device 2) playback PCMs.
* **Both** amplifiers enumerate — `sdw:0:0:0217:2110:00:3` (left) and
  `sdw:0:0:0217:2110:00:4` (right). The GPIO hog is what fixed the left one.
* Bluetooth loads `qca/crbtfw21.tlv` + `qca/crnv21.bin`, reports "QCA setup on
  UART is completed" and gets a real BD address.

Two follow-ups came out of that boot:

* The hog declared `GPIO_ACTIVE_HIGH`, which flipped the polarity the wsa881x
  driver sees (`Using ACTIVE_HIGH for shutdown GPIO`). It now uses
  `GPIO_ACTIVE_LOW` + `output-low` — the same physical level (high = amplifier
  enabled), but matching the amplifier's `powerdown-gpios`.
* Now that both amplifiers enumerate, the left one is wired into the SLIM
  Playback DAI link and the `"SpkrLeft IN", "SPK1 OUT"` route is restored.

### Routing is required before any sound comes out

The ADSP audio front ends are not connected to the SLIMbus back ends by
default; the `q6routing` mixer controls do that. There is no UCM profile for
this machine yet, so nothing sets them, and `aplay` fails with
`no backend DAIs enabled ... possibly missing ALSA mixer-based routing or UCM
profile`. The three controls are:

| Control | Connects |
|---|---|
| `SLIMBUS_0_RX Audio Mixer MultiMedia1` | MultiMedia1 → speakers |
| `SLIMBUS_1_RX Audio Mixer MultiMedia3` | MultiMedia3 → headphones |
| `MultiMedia2 Mixer SLIMBUS_0_TX` | capture → MultiMedia2 |

Set them by hand for testing — the helper script in this directory does all
of it:

```
./xiaomi-book-12.4-audio-init.sh          # set everything
./xiaomi-book-12.4-audio-init.sh --store  # ...and persist via alsactl
speaker-test -D hw:0,0 -c 2 -t sine       # speakers
speaker-test -D hw:0,2 -c 2 -t sine       # headphones
```

### The WSA881x port switches (the "pop then silence" trap)

`wsa881x_hw_params()` builds the amplifier's SoundWire port list from
`wsa881x->port_enable[]`, which only the codec's own mixer controls populate:

| Control (per amplifier) | Sets |
|---|---|
| `SpkrLeft/SpkrRight DAC Switch` | `WSA881X_PORT_DAC` |
| `SpkrLeft/SpkrRight COMP Switch` | `WSA881X_PORT_COMP` |
| `SpkrLeft/SpkrRight BOOST Switch` | `WSA881X_PORT_BOOST` |
| `SpkrLeft/SpkrRight VISENSE Switch` | `WSA881X_PORT_VISENSE` |

With none of them set, `active_ports` is 0, so the amplifier is added to the
SoundWire stream with *zero ports*: it still powers up (the audible pop) but
the SoundWire frames carry no audio for it. Upstream sets these in
`ucm2/codecs/wsa881x/SpeakerEnableSeq.conf`; the sc8180x-mainline Flex 5G UCM
has that include commented out.

Debug instrumentation (`dmesg | grep XIAOMI-AUDIO`) showing the failure:

```
wsa881x: hw_params ports 0 sruntime SLIMBUS_0_RX status 1     <-- no ports!
wcd934x: slim hw_params dir 0 ch_count 2 port_mask 0x30000 payload 0x3 bps 24
sdw: prepare(SLIMBUS_0_RX) = 0
sdw: enable(SLIMBUS_0_RX) = 0
wcd934x: slim_stream_enable(dai 0) = 0
```

Everything downstream of the codec was already succeeding.

`sudo alsactl store` makes the settings persist across reboots via
`alsa-restore.service`. All of these come from the upstream alsa-ucm-conf
`wcd934x` and `wsa881x` sequences plus the sc8180x-mainline sm8150 profile,
so a proper UCM profile can be assembled from them later.

## Microphones — there are none on the codec

Capture works end to end (codec ADC → SLIM TX → ADSP ADM → MultiMedia2 →
ALSA): tying off `AIF1_CAP Mixer SLIM TX0` collapses the stream to the DSP
idle pattern, so the data really does come from the codec. But nothing that
reaches the WCD9340's ADC responds to sound.

Measured with the speaker muted, a quiet baseline followed by tapping on the
tablet and talking (`./xiaomi-book-12.4-mic-tap-test.sh`, "lift" = loud-window
mean over the loudest quiet window):

| Input | lift |
|---|---|
| AMIC1 (ADC1) | 0.96x |
| AMIC2 (ADC2) | 0.98x |
| AMIC3 (ADC3) | 1.25x |
| AMIC4 (ADC4) | 0.81x |
| DMIC0…DMIC5 | no data at all |

That matches the hardware. Xiaomi's own spec sheet lists the audio as
"Dual speakers, 3.5mm headphone jack" and no microphone anywhere; `arecord -l`
shows the WCD9340 capture PCM as the only capture device on the system, and
the keyboard cover is a plain composite device with no USB audio. The codec
does register a `Headset Mic Jack` / `Headset Mic Switch`, and the machine
driver has jack pins for `Headset Mic`, so the only microphone on this
machine is the one on the 3.5 mm headset.

Consequence: the `AMIC2`/`MIC BIAS2` routing inherited from the Yoga C630 is
the headset-mic wiring and is probably right as it stands. Capture should
work with a headset that has a microphone plugged in; there is no built-in
microphone to fix.

### Traps found while chasing this

* **Speaker-pulse tests are useless on this machine.** Electrical crosstalk
  out of the playback path makes AMIC1, AMIC2 and AMIC3 all "respond" to a
  tone. Mute the speaker and use a real acoustic source instead.
* **Capture only delivers data at `S24_LE`.** `arecord -D hw:0,1 -f S16_LE`
  reports success and returns pure silence, while `-f S24_LE` works. The
  machine driver's BE fixup pins the capture backend to `S16_LE` while the
  front end runs `S24_LE`; anything asking for S16 gets nothing.
* **`ADC MUX0` → `ZERO` wedges the TX path.** Afterwards captures return the
  DSP idle pattern (3 distinct sample values) and only recover later on their
  own. Switch `AMIC MUX0` / `DMIC MUX0` straight between inputs instead.
* The `missing qcom,mbhc-buttons-vthreshold-microvolt entry` error is a driver
  logging bug: `wcd934x_init_dmic()` re-parses the MBHC config with the ASoC
  component device, which has no `of_node`
  (`/sys/bus/platform/devices/wcd934x-codec.4.auto/of_node` does not exist).
  The real parse already happened in probe with the SLIMbus device, so headset
  detection is unaffected; only the headset *button* thresholds get replaced
  by the 500 mV default.
* `command[0x10dac] not expecting rsp` / `0x10bdb` are `ASM_DATA_CMD_READ_V2`
  and `ASM_DATA_CMD_EOS`. Both are response-less by design — cosmetic noise
  from `q6asm.c`, not a capture fault.

## SLPI / sensors — the DSP boots, the sensors still need FastRPC

The accelerometer and everything else the device senses live on the Qualcomm
Sensor Core, which runs on the SLPI (SPSS). `sc8180x.dtsi` had `smp2p-slpi`
but no remoteproc node, so the SLPI never booted. It does now — the branch
adds a `remoteproc_slpi@2400000` node, a `qcom,sc8180x-slpi-pas` compatible in
`qcom_q6v5_pas.c` (reusing `sdm845_slpi_resource_init`), and the
`0x92c00000` reserved region from the Windows memory map.

The SM8150 values were borrowed and they are correct: the two SoCs share
identical MPSS/CDSP/ADSP register bases and ADSP wdog IRQ, the `smp2p-slpi`
nodes are byte-for-byte identical, and SM8150's `slpi_mem` is `0x1400000`,
exactly the SPSS/SLPI size in this machine's Windows memory map. The firmware
is `qcom/XIAOMI/BOOK124/qcslpi8180.mbn`, taken from the Windows driver store
package `qcsubsys_ext_scss8180.inf_arm64_82a97072e5b00832`.

Boot result:

    remoteproc remoteproc0: Booting fw image qcom/XIAOMI/BOOK124/qcslpi8180.mbn
    remoteproc remoteproc0: remote processor slpi is now up

and the Sensor Core service then appears on QRTR:

    400  1  0  9  12  Snapdragon Sensor Core service

`libssc` (0.4.4, already installed, along with `iio-sensor-proxy` 3.9)
connects to it as a QMI client on `qrtr://9/` — but the sensor registry
never becomes available, so no sensor reports. libssc says why itself:

    'registry' sensor unavailable, is hexagonrpcd running?

That is `sscrpd` in downstream terms: a **FastRPC daemon** that reads the
vendor's sensor JSON configs (bus type, address, mount matrix, …) from the
persist partition and pushes them to the SSC. Without it the SSC has no
sensors to report. Upstream hit the same wall on the Yoga C630 — Baryshkov's
patch enabling `slpi_pas` there notes the DSP "provides QMI services, however
it is of limited functionality due to the missing `fastrpc_shell_1` binary".

All three pieces of the FastRPC chain were then found or built, from the
Windows driver store on `nvme0n1p3` (mount it read-only to look):

1. a `fastrpc` node under the SLPI's `glink-edge`, labelled `sdsp` — added,
   giving `/dev/fastrpc-sdsp`. Its SMMU stream IDs are SM8150's, which is the
   one unconfirmed value in the whole chain;
2. `hexagonrpcd` from `github.com/linux-msm/hexagonrpc` (v0.5.0) — builds
   with meson; note its sdsp unit runs `-f /dev/fastrpc-sdsp -d sdsp -s` and
   needs **no** `fastrpc_shell_1` (that binary genuinely is not on the Windows
   install — only `ADSP/fastrpc_shell_0` and `CDSP/fastrpc_shell_3` are);
3. the sensor configs, in `qcsensorsconfigcls8180.inf_arm64_0a6924f604d585ff`.
   The device is platform `CLS` and its own `config_list.txt` names the files
   to use; `sscregistrygen -p CLS -s 340 <configs> <out>` turns them into the
   registry hexagonrpcd serves. That registry names the real sensors:
   **`icm4x6xx`** (6-axis IMU — this is the accelerometer), `stk3a5x`
   (ambient light + proximity) and `ak0991x` (magnetometer).

Note `-s 340`: the configs declare `soc_id` 340 while the kernel reports
`/sys/devices/soc0/soc_id` as **404**, and filtering on 404 yields an empty
registry. Whether the SSC cares about that mismatch is not yet known.

Install staged at `~/qcom-slpi/install.sh` (hexagonrpcd, the configs, the
registry, a systemd override passing `-R /usr/share/qcom/sc8180x/XIAOMI/BOOK124`).

## Not achievable with reasonable effort

| Subsystem | Why |
|---|---|
| Cameras | SC8180X has **no** upstream CAMSS support at all — no `camss`/`cci` nodes in `sc8180x.dtsi`. Sensors are likely S5K3L6 (rear), GC5035 (front), OV7251 (IR). This is a from-scratch upstream port. |
| Accelerometer / gyro / ALS | The SLPI now boots and exposes the Sensor Core (see below); the sensors themselves are still waiting on the FastRPC daemon. |
| Fingerprint | None present in hardware (face unlock uses the IR camera). |
| Venus video codec | The driver exists (`qcom,sm8250-venus`) but there is no DT node and no firmware packaged. Needs board-specific work. |
| Charger (TXRA9536) | No upstream driver. |

## Candidates not yet done

* Wi-Fi random MAC — the WLAN NV holds no per-unit MAC; set one statically.
  Confirmed still open: three consecutive boots gave three different addresses
  with `ath10k_snoc: invalid MAC address; choosing random`.
* Watchdog — `qcom-wdt` is built, but this kernel's driver has no SC8180X
  compatible, so a DT node alone is not enough.
* QCE crypto — driver present (`qcom,qce`), no DT node; register layout unknown.
* BAM parameters — the DT copies SDM845's `num-channels`/`num-ees`; the
  community SC8180X tree uses `num-channels = <31>`, `qcom,num-ees = <2>`,
  `reg` size `0x2c000`. Enumeration is a bus-level operation, so this is
  unlikely to be the amplifier blocker, but it is worth aligning.

## Build note

`tools/lib/bpf/libbpf.c` needs explicit `(char *)` casts on `strstr()`/`strchr()`
results for GCC 16 (`resolve_btfids` is built with `-Werror`). Without them the
build fails in `tools/bpf/resolve_btfids`.

## Volume: the "everything is routed but there is no sound" trap

Confirmed working on hardware 2026-10-03 — but the last hurdle was **gain, not
routing**. `Speaker Digital Volume` (the ctl-remap of `RX7/RX8 Digital
Volume`, `-84 dB .. 0 dB`, raw 0..124) had ended up very low, which is
inaudible no matter how correct the routing is. Raising it to full in
`alsamixer` produced sound immediately.

Why the desktop volume slider does not help: the UCM verb declares
`PlaybackMixerElem "Speaker"` / `"HP"`, but the remapped controls are named
`Speaker Digital Volume` / `HP Digital Volume`. WirePlumber therefore logs

    spa.alsa: Path Speaker is not a volume or mute control

and falls back to **software** volume, leaving the hardware gain wherever it
happens to be. Two consequences:

* the volume keys / slider never change the real gain, and
* software volume at 100% can still be silent if the hardware gain is low.

Fix in this tree: `ucm2/Qualcomm/xiaomi-book-12.4/HiFi.conf`, a copy of
`/Qualcomm/sdm845/HiFi-MM1.conf` with the element names corrected. Caveat: the
remapped controls are **write-only** (`access=rw---R--`), so the ALSA
simple-mixer layer does not list them (`amixer scontrols` shows no volume
controls at all) and WirePlumber may still refuse them. If so, the pragmatic
answer is to pin the gain (`alsactl store`, or `amixer -c 0 cset numid=2 124`)
rather than rely on the desktop slider.

### Disproven along the way

* **mmap vs RW access** — PipeWire opens the PCM `MMAP_INTERLEAVED`,
  `speaker-test`/`aplay` use `RW_INTERLEAVED`. Disabling mmap
  (`api.alsa.disable-mmap`) made no difference; audio worked with it off.
* **24-bit format** — `speaker-test --format S24_LE` is audible; the format is
  not the problem.
* **UCM/routing** — every control the profile sets was verified correct at the
  time playback was silent.
* **alsa state restore** — a full `alsactl` diff during a PipeWire stream shows
  no mixer changes, so nothing was mutating the routing mid-stream.

### Outcome of the volume-element fix (tested)

The corrected verb **is** in use — WirePlumber's warning now names
`Path Speaker Digital Volume`, proving the UCM parsed our file rather than the
upstream one. But it still refuses the control:

    spa.alsa: Path Speaker Digital Volume is not a volume or mute control

Root cause of that refusal: the ctl-remap creates the merged volume with
`access=rw---R--`, i.e. **write-only**. The ALSA simple-mixer layer (which
WirePlumber and PulseAudio use) cannot represent a volume it cannot read, so
the element is invisible to them regardless of its name. `amixer scontrols`
lists no volume controls at all on this card for the same reason.

Therefore: **the desktop volume slider cannot drive the hardware gain on this
machine.** This is an alsa-lib/remap limitation, not something a UCM profile
can fix. The workable approach is to pin the gain:

    amixer -c 0 cset numid=2 124      # Speaker Digital Volume, full scale
    sudo alsactl store                # persist across reboots

Note the UCM BootSequence (`/codecs/wcd934x/init.conf`) also sets
`RX7/RX8 Digital Volume` to 80 (-4 dB) whenever the card is enabled, which is
audible; the value above is worth applying only if you want full scale.

### Lessons / gotchas hit during this bring-up

* UCM `cset` takes ONE quoted string: `cset "name='X' 1"`, not
  `cset "name='X'" 1`. The second form fails with
  `string type is expected for sequence command` and the whole verb fails to
  parse, which drops the card profile entirely (no sinks at all).
* A UCM verb can be syntax-checked without touching the system by pointing
  `ALSA_CONFIG_UCM2` at an overlay copy of `/usr/share/alsa/ucm2` and running
  `alsaucm -c hw:0 list _verbs`. Do this before installing.
* The working verb is validated by that overlay test; the broken revision was
  not, which cost a round trip.
