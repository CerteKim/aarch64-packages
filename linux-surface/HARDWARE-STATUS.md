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
| Remoteprocs | ADSP, CDSP, MPSS, SLPI all running |
| Sensors | SSC via SLPI + hexagonrpcd (started by `hexagonrpcd-sdsp.path`): accelerometer `icm4x6xx`, ALS + proximity `stk3a5x`. Readings work; GNOME auto-rotation needs the inhibit recipe at login until mutter#4931 is fixed |

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

## SLPI / sensors — working (SLPI + FastRPC + a startup-claim fix)

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
registry. The mismatch turns out not to matter.

### Result: the accelerometer works

Confirmed on hardware 2026-10-03:

    remoteproc0: remote processor slpi is now up
    qcom,fastrpc ...:fastrpc:compute-cb@1: Adding to iommu group 13   (and 14, 15)
    /dev/fastrpc-sdsp present

    Accelerometer sensor measurement: X=8.432084 Y=-0.004791 Z=4.963431 m/s^2

which is gravity (|a| = 9.8 m/s^2).  The borrowed SM8150 SMMU stream IDs
were correct — the compute context banks attached with no faults — and the
`soc_id` 340/404 mismatch did not stop the SSC accepting the registry.

Two things worth knowing:

* `/dev/fastrpc-sdsp` comes up `crw------- root root`, so a udev rule is
  needed for the unprivileged `fastrpc` user that the service runs as
  (`KERNEL=="fastrpc-*", GROUP="fastrpc", MODE="0660"`).
* libssc warns "Mount matrix provided by firmware is all 0, falling back to
  identity matrix" — that is faithful: the vendor's own
  `icm4x6xx_0_platform.placement` is all zeros with `orient` `+x/+y/+z`, so
  identity is what the OEM declares.
* `hexagonrpcd` logs "Tried to open .../sns_reg_version for writing" on a
  loop; it serves the registry read-only, and this is harmless.

#### The daemon loses a boot race and systemd never retries it

This one only shows up after a **reboot**, which is why it was missed at first.
`hexagonrpcd-sdsp.service` ships with

    ConditionPathExists=/dev/fastrpc-sdsp

and is `WantedBy=multi-user.target`, but the kernel creates that node only after
the SLPI's `fastrpc` driver has probed, about 1.3 s *after* systemd evaluates the
unit:

    12:57:40  systemd: skipped, unmet condition ConditionPathExists=/dev/fastrpc-sdsp
    12:57:41  kernel:  qcom,fastrpc ... compute-cb@1: Adding to iommu group 13
    12:57:41  /dev/fastrpc-sdsp created

systemd does not re-evaluate a condition that failed, and the device's own udev
rules only pull in `iio-sensor-proxy.service` (their `SYSTEMD_WANTS`), never
`hexagonrpcd`. The daemon therefore never started, the SSC was never handed the
sensor registry, and `iio-sensor-proxy` retried

    'registry' sensor unavailable, retrying... (N/100)

until it gave up — so the accelerometer simply did not exist after a reboot,
while `hexagonrpcd-sdsp.service` still reported "enabled". Because the proxy
does give up, `HasAccelerometer` read false and nothing rotated.

Fix: a path unit, which has no such race - it activates at `multi-user.target`
and starts the service whenever the device appears, before or after that point:

    /etc/systemd/system/hexagonrpcd-sdsp.path     (staged in ~/qcom-slpi/usr/...)

    [Path]
    PathExists=/dev/fastrpc-sdsp
    Unit=hexagonrpcd-sdsp.service

`systemctl enable --now hexagonrpcd-sdsp.path`. The service keeps its condition
(so a manual start without the device is still skipped), the path unit is what
actually brings it up. Note the condition is also *sticky per attempt*, so
recovery during a session needs the proxy restarted afterwards, since it has
already given up on the registry.

### Getting the accelerometer to GNOME: `rotv`, not `accel`

`iio-sensor-proxy` 3.9 does not ask the SSC for the accelerometer. It asks for
two data types, and only one of them is what you would guess:

    Discovering sensor UID for data type 'ambient_light'
    Discovered 'ambient_light' sensor ... name: stk_stk3a5x     -> ALS exposed
    Discovering sensor UID for data type 'rotv'
    No 'rotv' sensor available                                  -> gives up

So `HasAmbientLight` was true while `HasAccelerometer` stayed false, even
though `ssccli --sensor accelerometer` printed gravity perfectly. iio-sensor-
proxy wants a **rotation vector** fusion sensor.

The fix is in the config selection, and it is a trap: the device's own
`config_list.txt` does **not** list `sns_rotv.json` or `default_sensors.json`,
but both are needed. Copying only the files `config_list.txt` names yields a
registry with no `rotv` sensor. Include those two as well and regenerate:

    sscregistrygen -p CLS -s 340 <configs> <out>

which takes the registry from 47 to 58 files, adding `sns_rotv_platform`,
`sns_rotv_platform.config` and the `default_sensors.{accel,gyro,mag,
motion_detect}` bindings. The SSC reads the registry when the SLPI starts, so
this needs a reboot rather than just a daemon restart.

### The actual cause: an incomplete udev rule upstream

The `rotv` trail was a red herring. `rotv` does not appear anywhere in
iio-sensor-proxy's source — that message came from **libssc**, invoked by the
*compass* driver, not the accelerometer one.

The real gate is a udev property. Every SSC driver refuses to engage unless
`IIO_SENSOR_PROXY_TYPE` contains its own string:

    drv-ssc-accel.c      "ssc-accel"
    drv-ssc-light.c      "ssc-light"
    drv-ssc-proximity.c  "ssc-proximity"
    drv-ssc-compass.c    "ssc-compass"

and that property is set by `/usr/lib/udev/rules.d/80-iio-sensor-proxy.rules`:

    SUBSYSTEM=="misc", KERNEL=="fastrpc-sdsp*", ENV{IIO_SENSOR_PROXY_TYPE}+="ssc-light ssc-compass"

Only light and compass. So the ALS worked while the accelerometer driver never
ran at all — `udevadm info /dev/fastrpc-sdsp` shows exactly
`IIO_SENSOR_PROXY_TYPE=ssc-light ssc-compass`. The compass entry is what
produced the `No 'rotv' sensor available` line, because libssc's compass
support looks for a rotation vector this firmware does not expose.

The fix is a rule of our own in `/etc/udev/rules.d/`, staged at
`~/qcom-slpi/udev/91-fastrpc-sensors.rules`:

    SUBSYSTEM=="misc", KERNEL=="fastrpc-sdsp*", ENV{IIO_SENSOR_PROXY_TYPE}+="ssc-accel ssc-proximity"

Both sensors are known good on this machine (`icm4x6xx` accel, `stk3a5x`
proximity), so this is a genuine gap in the upstream rule rather than
something board-specific.

Confirmed on hardware: with the extra rule, `udevadm info /dev/fastrpc-sdsp`
shows `ssc-light ssc-compass ssc-accel ssc-proximity`, and
`iio-sensor-proxy` then reports

    HasAccelerometer   b true
    HasAmbientLight    b true
    HasProximity       b true

with the journal showing the accelerometer discovered as `data-type: accel`.
Note the mount matrix is the identity - libssc substitutes identity because the
vendor ships zeros, and iio-sensor-proxy independently falls back to identity
too, so the two agree.

#### But `HasAccelerometer` was still not enough: the startup-claim race

`HasAccelerometer: true` still did not make the accelerometer work, and this was
the real blocker. iio-sensor-proxy owns its D-Bus name *before* it opens the
sensors, and `name_acquired_handler()` then spends seconds on SSC discovery
(each libssc client is a full QMUX connect + SUID + attribute round trip).
gnome-shell claims the accelerometer as soon as the name appears, so the claim
lands in that window:

* at claim time `driver_type_exists (data, DRIVER_TYPE_ACCEL)` is still false,
  so `handle_generic_method_call()` answers the claim with an immediate
  success and never calls `set_polling()`;
* the claim is nevertheless recorded in `data->clients[DRIVER_TYPE_ACCEL]`;
* when the device is finally opened, nothing revisits that claim - and because
  `g_hash_table_size (ht) != 1`, every later claim takes the "client added while
  sensor is active" branch and returns success without starting anything either.

The sensor is therefore dead for the entire session, while the D-Bus API claims
it is present and working. Hardware evidence from the instrumented proxy:

    XIAOMI-CLAIM: inserted sender=:1.54 ht_size=1        <- gnome-shell, too early, no-op
    XIAOMI-CLAIM: type=0 device=0x... driver=0x... drv=0x...   <- later claim, driver IS correct
    XIAOMI-CLAIM: ht_size=2 invocations_delayed=0 event_delayed=0   <- so it only returns success

`ssc_accelerometer_set_polling()` was never entered, and the same race can hit
light, proximity or an `input-accel` device. The fix is one block in the
device-opening loop of `name_acquired_handler()`: if clients are already
waiting, start polling once the device has been opened.

    if (g_hash_table_size (data->clients[i]) > 0) {
        g_debug ("Sensor %s was claimed during startup, starting it",
                 driver_type_to_str (i));
        driver_set_polling (sensor_device, TRUE);
    }

Staged as `~/qcom-slpi/iio-sensor-proxy/0001-start-sensor-claimed-during-
startup.patch` and installed to `/usr/local/lib/iio-sensor-proxy/` by
`~/qcom-slpi/install-iio-proxy.sh` (the packaged `/usr/lib/iio-sensor-proxy` is
left untouched). Confirmed on hardware 2026-10-03:

    Sensor accelerometer was claimed during startup, starting it
    Accel sent by driver (quirk applied): 8, 0, 4 (scale: 1.0,1.0,1.0)
    Emitted orientation changed: from undefined to left-up

and D-Bus then reports a real orientation instead of `undefined`:

    === Has accelerometer (orientation: left-up, tilt: tilted-up)

#### The mount matrix: the panel is portrait and the sensor frame is rotated

Getting measurements through was not enough to make screen rotation *correct*.

The panel's native mode is **1600x2560, i.e. portrait** (the only mode `DSI-1`
offers, matching the DT). Per the BIOS, in the native image direction the
**camera edge is the 2560px (long) side on the right**, the **keyboard edge is
the long side on the left**, the **pen magnet is on a 1600px (short) side, top**
and the **power button on the other short side, bottom** - so a
keyboard-attached landscape desktop needs mutter to apply a **90/270 degree
transform (`1` or `3`)**. Transforms `0` and `2` are portrait and come up wrong.
(Mutter's values: `0` = normal, `1` = 90°, `2` = 180°, `3` = 270°; there is no
`8`.)

The vendor sensor frame is rotated against that panel, and it is also mirrored
relative to it. In the keyboard-landscape hold the raw sample is about
`(8.7, 0.1, 4.5) m/s²`, with `+Z` the screen normal (screen up on a table reads
`Z=+10`), so the in-plane gravity component sits mostly on `x` - which
`orientation_calc()` reads as a **portrait** hold, picking `left-up` or
`right-up` from the sign of `x`. Getting landscape right therefore means fixing
the frame's handedness, not moving the gravity component onto `y`.

The corrected value (row-major, rows separated by `;`), staged at
`~/qcom-slpi/udev/92-fastrpc-accel-matrix.rules`, is a **180° rotation about the
screen normal**:

    SUBSYSTEM=="misc", KERNEL=="fastrpc-sdsp*", \
        ENV{ACCEL_MOUNT_MATRIX}="-1,0,0;0,-1,0;0,0,1"

It falls straight out of `orientation.c`:

    portrait_rotation  = atan2 (x, sqrt (y*y + z*z))
    landscape_rotation = atan2 (y, sqrt (x*x + z*z))

`|portrait| > 35°` picks `left-up`/`right-up` from the **sign of x**;
otherwise `|landscape| > 35°` picks `bottom-up`/`normal` from the **sign of y**.
Both earlier values were wrong, in instructive ways:

* `0,-1,0;1,0,0;0,0,1` (documented first) is a 90° rotation. It shifts the
  gravity component into the landscape branch, so the keyboard-landscape hold
  reports `bottom-up` -> transform 180, i.e. an upside-down **portrait** image;
  it had been picked for a `transform 8` that does not exist.
* `1,0,0;0,-1,0;0,0,1` is what the later matrix sweep actually left installed in
  `/etc/udev/rules.d/92-fastrpc-accel-matrix.rules`. Its determinant is `-1`, so
  it is a **reflection** and inverts the handedness of the sensor frame: the
  observed profile on this panel is *portrait fine, both landscape holds 180°
  out*.
* negating `x` as well (`-1,0,0;0,-1,0;0,0,1`, `det = +1`) swaps
  `left-up`↔`right-up` and leaves `normal`/`bottom-up` untouched. Checked
  against the 18 `(quirked vector -> orientation)` pairs logged while rotating
  the device: all 8 portrait samples keep their label, all 10 landscape samples
  swap.

Mutter's transform numbering, for the record (it is *not* the XRandR bitmask,
and there is no value 8):

    0 = normal   1 = 90°   2 = 180°   3 = 270°

Measured live against this panel once mutter was holding the sensor:
`left-up` -> `1`, `normal` -> `0`, `right-up` -> `3`. So the mapping is the bare
`meta_orientation_to_transform()`, `bottom-up` -> `2`, and the panel's own
orientation transform is `0` (`normal`) - there is no extra composition to
account for.

Note the format trap: `strsplit_num_tokens()` wants `-1,0,0;0,-1,0;0,0,1`, not
`-1,0,0,0,-1,0,0,0,1` (that fails with "Failed to parse ACCEL_MOUNT_MATRIX").

`libssc` applies the vendor matrix to every sample before iio-sensor-proxy ever
sees it (`ssc_accelerometer_response` → `priv->mount_matrix`), and its
`SSC_SENSOR_MOUNT_MATRIX` property is `G_PARAM_READABLE`, so the board cannot be
corrected through the sensor properties. The fix is to let the SSC driver honour
the standard `ACCEL_MOUNT_MATRIX` udev property, which `setup_mount_matrix()`
already parses for the IIO drivers.

The **base transform** GNOME stores for `DSI-1` is `<rotation>right</rotation>`
in `~/.config/monitors.xml` (the 1600x2560 portrait mode at 270 degrees) - the
"landscape left" setting chosen in GNOME. Mutter composes that base with the
accelerometer reading, so with the corrected matrix the two landscape holds map
to transforms `3` and `1` - one of them is the stored `right`.


##### Mutter will not retry a failed claim

Worth knowing while testing, and it bit twice here:
`meta-orientation-manager.c` only calls `ClaimAccelerometer` when `should_claim`
*changes* - driven by the D-Bus proxy being (re)created, or by the
orientation-lock inhibit count. A failed claim is **never retried** for that
session, and `HasAccelerometer` keeps reading true, so rotation silently does
nothing while the screen stays frozen at its stored transform. Reloading the
shell (Alt+F2, `r`) or logging out/in is what re-arms it.

##### The remaining reason rotation dies at login: mutter drives its inhibit count negative

Even with the claim patch, auto-rotation is dead after **every** login on this
machine. This one is a mutter 50 bug, not a sensor problem:
[mutter#4931](https://gitlab.gnome.org/GNOME/mutter/-/work_items/4931) - the
compositor half. The daemon half is
[iio-sensor-proxy MR!414](https://gitlab.freedesktop.org/hadess/iio-sensor-proxy/-/merge_requests/414);
both are still open as of mutter 50.4 / iio-sensor-proxy 3.9.

`should_claim` is `iio_proxy && inhibited_count == 0`, and
`meta_orientation_manager_uninhibit_tracking()` only re-evaluates the claim when
`inhibited_count` lands on exactly 0. At startup `panel_orientation_managed` is
`FALSE`; the first `update_panel_orientation_managed()` early-returns on the
`FALSE == FALSE` no-op *without* inhibiting; then `HasAccelerometer` arriving
`FALSE -> TRUE` flips it `FALSE -> TRUE`, calling `uninhibit_tracking()`
**unpaired**. `inhibited_count` goes `0 -> -1`, `sync_accelerometer_claimed()`
is skipped because it only runs on the `0`/`1` boundaries, and `should_claim` is
never recomputed. Mutter therefore never sends `ClaimAccelerometer` for the
whole session, while `HasAccelerometer` and the auto-rotate toggle both read
`true`.

Hardware evidence (journal, session started 14:11 on 2026-10-03):

    iio-sensor-proxy: zero ClaimAccelerometer lines for that session
    Mutter DisplayConfig: PanelOrientationManaged = true   <- mutter thinks it
                          manages the panel, and still never claims the sensor
    a manual gdbus ClaimAccelerometer from the same session works and streams
                          12.5 Hz

`PanelOrientationManaged = true` is the tell. On this board the ordering is
deterministic: mutter has the builtin monitor before the sensor proxy's
property arrives, so the unpaired uninhibit always happens.

##### Working around it in the running session

Two inhibits followed by one uninhibit walk the count `-1 -> 0 -> 1 -> 0`; the
last step lands on 0, mutter re-evaluates and claims. Run inside the user
session (`DBUS_SESSION_BUS_ADDRESS` set); it costs one ~1 s DPMS blink:

    gsettings set org.gnome.settings-daemon.peripherals.touchscreen orientation-lock true
    gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
      --object-path /org/gnome/Mutter/DisplayConfig \
      --method org.freedesktop.DBus.Properties.Set \
      org.gnome.Mutter.DisplayConfig PowerSaveMode "<int32 1>"
    gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
      --object-path /org/gnome/Mutter/DisplayConfig \
      --method org.freedesktop.DBus.Properties.Set \
      org.gnome.Mutter.DisplayConfig PowerSaveMode "<int32 0>"
    gsettings set org.gnome.settings-daemon.peripherals.touchscreen orientation-lock false

##### Installed: the recipe runs itself at login

Since the failure repeats on **every** login, the recipe is wrapped in
`mutter-accelerometer-claim.sh` (in this repo, installed to
`~/.local/bin/mutter-accelerometer-claim.sh`) and started by
`~/.config/autostart/mutter-accelerometer-claim.desktop`
(`X-GNOME-Autostart-Delay=8`; delete that file to disable it).

The script waits for `org.gnome.Mutter.DisplayConfig` and for
`HasAccelerometer = true`, gives mutter a further 6 s to reach the broken state,
does nothing if the sensor already looks claimed *or* if the user has the
rotation lock on (`orientation-lock=true`, where not claiming is correct), then
runs the recipe above and verifies that readings start. It always restores
`PowerSaveMode` and the lock via an EXIT trap. Result is logged to
`~/.local/state/mutter-accelerometer-claim.log`:

    2026-10-03 14:28:25 accelerometer already claimed (orientation right-up); nothing to do
    2026-10-03 14:28:32 mutter claimed the accelerometer (orientation right-up)

Both paths were exercised on hardware: a no-op run while the sensor was already
claimed, and `--force` (Release+Claim in the journal, orientation restored).

Verified on hardware: immediately after a poke, the journal shows `Handling
driver refcounting method 'ClaimAccelerometer'` plus continuous `Accel sent by
driver` readings, and the transform tracks the orientation. Note that the
*first* orientation event after a first claim still runs
`orientation_changed()`'s initial-config inhibit in `meta-monitor-manager.c` and
releases the sensor once; the second claim - the one this recipe produces -
sticks, because `initial_orient_change_done` is set by then.

Decision taken here: **wait for the upstream fix** rather than rebuild mutter,
and let the autostart entry run the recipe after each login. If mutter is ever
patched locally, the fix is to keep inhibit/uninhibit balanced around
`panel_orientation_managed` (or to guard `uninhibit_tracking()` against
underflow and re-evaluate `should_claim` whenever its inputs change).

##### The "sample rate" red herring

`libssc`'s `sample-rate` property is `G_PARAM_READABLE` and carries the value
the SSC itself declares, so `g_object_set (sensor, SSC_SENSOR_SAMPLE_RATE, …)`
is both impossible and unnecessary - the firmware rate (12.5 Hz for the
`icm4x6xx`) is what `ssc_sensor_open()` already sends. An earlier attempt to
force 12.5 Hz was reverted; `ssccli --sensor accelerometer` and a plain
`new_sync()` + `open_sync()` both stream fine without it.

##### Cheaper workaround (no patch)

If rebuilding iio-sensor-proxy is not wanted, `systemctl restart
iio-sensor-proxy` and then claim the accelerometer *after* the proxy has settled
- but this cannot be relied on, because gnome-shell always claims first. This is
why the session-wide fix above is the useful one. (Restarting the proxy is also
not enough by itself for the inhibit-count bug below - the name appearing again
re-runs the same unpaired uninhibit.)

The compass remains unavailable (`No 'rotv' sensor available`), which is real:
libssc's compass support wants a rotation vector this firmware does not
expose. iio-sensor-proxy has no `HasCompass` property at all, so it is
cosmetic.

### Summary — sensors now working

    accelerometer (icm4x6xx)                          WORKING
    screen rotation                                   WORKING; mutter#4931 means
                                                      mutter only claims the
                                                      sensor after the inhibit
                                                      recipe - installed as a
                                                      GNOME autostart entry
    ambient light (stk3a5x)                           WORKING
    proximity     (stk3a5x)                           WORKING
    compass                                           not exposed by firmware

Mount matrix: **applied**. `/etc/udev/rules.d/92-fastrpc-accel-matrix.rules` now
holds the corrected `-1,0,0;0,-1,0;0,0,1` (identical to the copy in
`~/qcom-slpi/udev/`), confirmed by `udevadm info /dev/fastrpc-sdsp`. The
commands that were used:

    sudo cp ~/qcom-slpi/udev/92-fastrpc-accel-matrix.rules /etc/udev/rules.d/
    sudo udevadm control --reload
    sudo udevadm trigger --sysname-match=fastrpc-sdsp
    sudo systemctl restart iio-sensor-proxy

Auto-rotation claim: **automated**. `~/.config/autostart/mutter-accelerometer-claim.desktop`
starts `~/.local/bin/mutter-accelerometer-claim.sh` after each login; delete the
desktop file (or the script) to go back to running the recipe by hand.

## Not achievable with reasonable effort

| Subsystem | Why |
|---|---|
| Cameras | SC8180X has **no** upstream CAMSS support at all — no `camss`/`cci` nodes in `sc8180x.dtsi`. Sensors are likely S5K3L6 (rear), GC5035 (front), OV7251 (IR). This is a from-scratch upstream port. |
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

## Display: the mainline Himax HX83121A driver on a dual-DSI link

> Status: ported, built and installed; the panel has **not** been verified on
> this link yet — verification happens on the next reboot
> (`./verify-mainline-panel.sh`).  Until then the single-DSI configuration
> described first in this section is the one known to light the panel.

The panel first came up with the bring-up driver on a **single** DSI0 link and
a 1600-wide DSC slice, which needed three msm workarounds (one DSC block for a
single-interface/single-slice topology, `DIV_ROUND_UP()` on the DSC active
width, and wide bus disabled for DSI video mode).  Branch
`xiaomi-mainline-panel2` replaces that driver with the upstream
`panel-himax-hx83121a.c` and drives the panel over **both** DSI links, which is
how the sibling CSOT/BOE PPC357DB1-4 panels and the mainline HX83121A driver
work.

Ported pieces, all in `drivers/gpu/drm/panel/panel-himax-hx83121a.c`:

* a `csot,pnc357db1-4` panel descriptor: the ACPI/GPU0 7-command init sequence,
  the PPC357DB1-4 DSC configuration (800x20 slices, one per link) and
  `needs_display_on`, because the ACPI sequence does not turn the display on
  itself — that has to happen after the PPS and compression mode.
* a per-panel regulator list instead of the driver-wide `vddi`/`avdd`/`avee`,
  so this board can use its own `vdd1`/`vddi`/`vdd` rails.
* support for the optional `enable-gpios` (TLMM 6, `DSI Mode Select` in the
  ACPI tables), which the bring-up driver already used.
* `enable_dsc` now defaults to true; the panel cannot be driven without it.
  The full vendor sequence of the related PPC357DB1-4 remains selectable with
  the `pnc_full_init=1` parameter.

Device tree: `&mdss_dsi0` and `&mdss_dsi1` are both enabled with
`qcom,dual-dsi-mode` / `qcom,sync-dual-dsi`, DSI0 is the master, and DSI1's
byte and pixel clocks are parented to the DSI0 PLL.  `panel@0` has
`port@0` -> `mdss_dsi0_out` and `port@1` -> `mdss_dsi1_out`; the secondary
DSI device is the usual empty `panel_secondary` node, which the driver
registers itself.  Also fixed while here: the malformed comment that had
swallowed the `chosen` node's closing brace, so the simple-framebuffer (and
with it `bootargs`) is part of the DT again.

Supporting changes: `select DRM_DISPLAY_DSC_HELPER` and
`DRM_DISPLAY_HELPER` in the Kconfig entry, and the upstream
`himax,hx83121a.yaml` binding extended with `csot,pnc357db1-4` and the
`vdd1`/`vdd` supplies.

Two caveats:

* the panel's DSC parameters are the ones the mainline driver uses for the
  same IC on the Matebook E Go; if the image shows banding or distortion,
  this is the first thing to reconsider;
* `enable_dsc = true` is a local default, not an upstream one.

Install and rollback: `./install-mainline-panel.sh` (run as root) installs the
kernel, the dual-link DTB and a fresh initramfs, and saves the previous
kernel and DTBs under `/home/certe/panel-fallback-single-dsi/`;
`./tools/restore-single-dsi-panel.sh` puts them back and regenerates the
initramfs.  The boot partition is a 256M EFI partition with no room for two
initramfs images, which is why the fallback initramfs is regenerated rather
than stored.

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
