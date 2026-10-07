# Xiaomi Book S 12.4 (SC8180X) — Linux hardware status

Board: `xiaomi,book-12.4` / `TM2133`, BIOS `XM28C2B0P16`, Qualcomm SC8180X
(Snapdragon 8cx Gen 2). Kernel: `linux-mibook` (6.18.2) from this repo.

## Working

| Subsystem | Driver / notes |
|---|---|
| Display | CSOT PNC357DB1-4 via Himax HX83121A, upstream `panel-himax-hx83121a` driver, single DSI0 link + DSC, msm_dpu, pmc8180c WLED backlight |
| GPU | Adreno 680 (`adreno`, `msm`), ZAP shader `qcom/XIAOMI/BOOK124/qcdxkmsuc8180.mbn`; the `-oc` device tree adds the firmware's 530/595/670 MHz states |
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

Even in ROM mode `hci0` comes up, but with no patch/NVM and a bogus BD address.

#### Bluetooth address (board has none) — fixed in the device tree

This board was never provisioned with a BD address (no on-chip OTP and nothing
in secure world), so the chip boots with the placeholder that the generic
`qca/crnv21.bin` NVM carries as its tag-2 default. On this unit that shows up
as `39:90:21:64:07:00` (the same six bytes, `00 07 64 21 90 39`, read in the
other direction).

`qca_check_bdaddr()` reads the address back after the NVM download and, if the
controller still reports the NVM default, sets
`HCI_QUIRK_USE_BDADDR_PROPERTY`. With no `local-bd-address` in the device tree,
the kernel then leaves the controller `HCI_UNCONFIGURED`:

* `hciconfig` shows `hci0` as `DOWN RAW`, yet
* `bluetoothctl list` and `btmgmt info` are empty — the adapter only sits in
  the *unconfigured* mgmt index list, so BlueZ never powers it up.

`btmgmt --index 0 public-addr …` supplies the missing config option and makes
it work, but only until the next power cycle (the address is not persistent),
so it has to be repeated after every boot.

The device tree provides the address, and the kernel programs it into the chip
during every setup (`qca_set_bdaddr`) before bluetoothd starts:

```
local-bd-address = [60 ad ce 9e 16 14];	/* 14:16:9E:CE:AD:60 */
```

`local-bd-address` is little-endian, per
`Documentation/devicetree/bindings/net/bluetooth/bluetooth-controller.yaml`.
`qcom,local-bd-address-broken` is *not* needed here (that flag is for boot
firmware that passes the value big-endian). The value is synthetic and per
board — there is no stored address anywhere on this machine to recover — so it
is shared by every user of this DTB. It does not have the locally-administered
bit set (the first octet's low nibble should be 2, 6, a or e); worth fixing if
this DTB is ever copied to another machine, but this is what the machine has
been using.

The property lives in `arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4.dtsi`,
so every DTB built from the tree carries it. Deploying a change is:

```
make -C src/kernel ARCH=arm64 qcom/sc8180x-xiaomi-book-12.4.dtb
sudo bash tools/install-dtb-from-tree.sh     # parked DTB into both GRUB paths,
sudo reboot                                  # probe variant refreshed next to it
```

`tools/install-dtb-from-tree.sh` keeps the booted paths on the parked (VPU
disabled) variant; `tools/update-probe-dtb.sh` is the one that flips them to
the probe variant.

Verified on hardware after that rebuild (2026-10-05):

```
$ od -An -tx1 /sys/firmware/devicetree/base/soc@0/geniqup@cc0000/serial@c8c000/bluetooth/local-bd-address
 60 ad ce 9e 16 14
$ hciconfig hci0
hci0:	Type: Primary  Bus: UART
	BD Address: 14:16:9E:CE:AD:60  ACL MTU: 1024:7  SCO MTU: 240:4
	UP RUNNING PSCAN ISCAN
$ bluetoothctl list
Controller 14:16:9E:CE:AD:60 archlinux [default]
```

#### History: why Bluetooth disappeared on 2026-10-05

The property used to exist only in the prebuilt
`panel-dtb/sc8180x-xiaomi-book-12.4.{single,dual}-link.dtb` snapshots, never in
the DTSI. When the DTBs in `/boot/dtb/linux-mibook/qcom/` were rebuilt from the
tree on 2026-10-04, the property went with them: `hci0` came back `DOWN RAW` on
the placeholder `39:90:21:64:07:00`, absent from the mgmt index list, and
`bluetoothctl list` / `btmgmt info` / the GNOME panel showed no adapter at all.

`bluetooth-bdaddr.service` (see `systemd/`) was meant to cover exactly that gap,
and it never worked, for two reasons:

* it waited only for `/sys/class/bluetooth/hci0`, which appears well before the
  controller leaves `HCI_SETUP`/`HCI_CONFIG`. `MGMT_OP_SET_PUBLIC_ADDRESS`
  during that window is answered with `0x11 (Invalid Index)` — the journal
  shows exactly that at every boot;
* it used `btmgmt --timeout`, whose result is invisible. With a timeout set,
  `bt_shell_noninteractive_quit()` (BlueZ `src/shared/shell.c`) returns early
  and the process exits 0 when the timer fires, whatever the command answered.
  The `hci0 address set to 14:16:9E:CE:AD:60` line was therefore a false
  positive, and the "is it already set" check read
  `/sys/class/bluetooth/hci0/address`, an attribute this kernel does not have
  (`net/bluetooth/hci_sysfs.c` only exposes `reset`).

The fix is the DTSI property above. The unit stays in the repo as a fallback for
DTBs that lack the property — it now retries until the controller is
configurable, reads the address back with `hciconfig`, treats `HCI_RAW` being
clear as success, and a udev rule re-runs it if the controller is re-registered
— but it should not be installed on a machine whose DTB carries the address:

```
sudo bash tools/install-bluetooth-bdaddr.sh --uninstall
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
  UART is completed" and works once it has a BD address (supplied by hand at
  the time; now taken from the device tree — see the Bluetooth address
  section above).

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
* Watchdog — stale as written: the binding already lists
  `qcom,apss-wdt-sc8180x`, and `qcom-wdt` matches the generic `qcom,kpss-wdt`
  fallback, so a node with `"qcom,apss-wdt-sc8180x", "qcom,kpss-wdt"` binds
  today.  Template: `sm8150.dtsi`'s node (`0x17c10000`, `sleep_clk`,
  `GIC_SPI 0`), not sc7180's.
* QCE crypto — driver present (`qcom,qce`), no DT node.  The register layout
  and the SMMU SIDs are available from the SM8150 sibling: `crypto@1dfa000`,
  `"qcom,sm8150-qce", "qcom,qce"`, cryptobam dmas plus five stream IDs.
* BAM parameters — the DT copies SDM845's `num-channels`/`num-ees`; the
  community SC8180X tree uses `num-channels = <31>`, `qcom,num-ees = <2>`,
  `reg` size `0x2c000`. Enumeration is a bus-level operation, so this is
  unlikely to be the amplifier blocker, but it is worth aligning.

## Display: the mainline Himax HX83121A driver (single DSI link)

> Status: **verified working** — the upstream `panel-himax-hx83121a` driver
> now drives the CSOT PNC357DB1-4 on DSI0 with DSC, replacing the bring-up
> driver, and the image is correct.  Verified on hardware 2026-10-03 16:54.
>
> ```
> panel-himax-hx83121a ae94000.dsi.0: no secondary link, using single-link configuration
> msm_dpu ae01000.display-controller: bound ae94000.dsi (ops dsi_ops [msm])
> msm_dpu ae01000.display-controller: [drm] fb0: msmdrmfb frame buffer device
> card0-DSI-1: connected, enabled, 1600x2560
> ```
>
> A **dual-link** variant exists and comes up without a single DSI or DSC
> error (both controllers bound, connector enabled) but renders garbage; the
> open question is the DSC geometry the panel decoder expects.  See "First
> dual-link boot" and "Second dual-link boot" below.

The panel first came up with the bring-up driver on a **single** DSI0 link and
a 1600-wide DSC slice, which needed three msm workarounds (one DSC block for a
single-interface/single-slice topology, `DIV_ROUND_UP()` on the DSC active
width, and wide bus disabled for DSI video mode).  Branch
`xiaomi-mainline-panel2` replaces that driver with the upstream
`panel-himax-hx83121a.c`; the msm workarounds are unchanged and still needed.

Ported pieces, all in `drivers/gpu/drm/panel/panel-himax-hx83121a.c`:

* a `csot,pnc357db1-4` panel descriptor: the ACPI/GPU0 7-command init sequence,
  `needs_display_on` (the ACPI sequence does not turn the display on itself, so
  that has to happen after the PPS and compression mode) and the DSC
  parameters the panel was verified with — 1600-wide, slice height 40, one
  slice;
* a second descriptor `csot_pnc357db1_4_single_desc`, used automatically when
  the panel node has no second graph port.  The dual-link descriptor keeps the
  PPC357DB1-4 geometry (800x20 per link) for experiments;
* a per-panel regulator list instead of the driver-wide `vddi`/`avdd`/`avee`,
  so this board can use its own `vdd1`/`vddi`/`vdd` rails;
* support for the optional `enable-gpios` (TLMM 6, `DSI Mode Select` in the
  ACPI tables), which the bring-up driver already used;
* `enable_dsc` now defaults to true; the panel cannot be driven without it.
  The full vendor sequence of the related PPC357DB1-4 remains selectable with
  the `pnc_full_init=1` parameter.

Device tree: the default tree drives the panel from **DSI0 alone** — no
`qcom,dual-dsi-mode` flags and no `panel_secondary` node, DSI1 left disabled —
which is the configuration the panel was verified with (DTB md5
`1adbba631ade4c166580ae3c66a58b41`).  The dual-link tree is kept as a separate
DTB, see the dual-link section below.  Also fixed while here: the malformed
comment that had swallowed the `chosen` node's closing brace, so the
simple-framebuffer (and with it `bootargs`) is part of the DT again.

Supporting changes: `select DRM_DISPLAY_DSC_HELPER` and
`DRM_DISPLAY_HELPER` in the Kconfig entry, and the upstream
`himax,hx83121a.yaml` binding extended with `csot,pnc357db1-4` and the
`vdd1`/`vdd` supplies.

One caveat: `enable_dsc = true` is a local default, not an upstream one.

### DSI node flags matter more than they look

Two failures in this bring-up were caused purely by DSI device-tree shape, and
both are worth remembering:

* with DSI1 **enabled** but the secondary panel node carrying the panel
  `compatible`, the DSI host instantiated a panel device for that node, the
  driver probed it instead (it has no supplies and no reset GPIO) and the
  driver's own secondary device registration then collided with it
  (`-EEXIST`), taking the primary probe down as well;
* with DSI1 **disabled** but `qcom,dual-dsi-mode` still set on DSI0, the msm
  DSI manager takes the bonded path, finds no second DSI
  (`other_dsi == NULL`) and returns success *without ever calling*
  `msm_dsi_host_register()`.  No panel device, no DPU component, no DRM card:
  a black screen with the backlight on.  This is silence, not an error message.

### First dual-link boot (2026-10-03 16:28) — no panel

Both links came up (`dsi@ae94000` and `dsi@ae96000` both `okay` in the live
DT, `msm` bound to both), but no DRM card was created at all: the panel driver
failed to probe twice.

```
panel-himax-hx83121a ae96000.dsi.0: supply vdd1 not found, using dummy regulator
panel-himax-hx83121a ae96000.dsi.0: error -ENOENT: Failed to get reset-gpios
panel-himax-hx83121a ae96000.dsi.0: probe with driver panel-himax-hx83121a failed with error -2
sysfs: cannot create duplicate filename '.../ae96000.dsi/ae96000.dsi.0'
  himax_probe+0x2f4/0x3c0
msm_dsi ae96000.dsi: failed to add DSI device -17
panel-himax-hx83121a ae94000.dsi.0: cannot get secondary DSI device
panel-himax-hx83121a ae94000.dsi.0: probe with driver panel-himax-hx83121a failed with error -17
```

Two chained problems, both from the DT shape, not from the panel:

1. the `panel_secondary` node under `&mdss_dsi1` carried
   `compatible = "csot,pnc357db1-4"`, so the DSI host instantiated a panel
   device for it (`ae96000.dsi.0`) and the driver probed it; that node has no
   supplies and no reset GPIO, hence `-ENOENT`;
2. the driver then tried to register *its own* secondary DSI device on DSI1,
   named `dsi-secondary`, which resolves to the same `ae96000.dsi.0` name and
   collided (`-EEXIST`), taking the primary probe down with it.

Fix: the secondary panel node is now a pure graph anchor and has **no**
`compatible`.  That is also what upstream dual-DSI panels do (`nt36523`):
the driver registers the secondary device itself.  The change is DTB-only —
no kernel rebuild was needed.

Install and rollback: `./install-mainline-panel.sh` (run as root) installs the
kernel, the dual-link DTB and a fresh initramfs, and saves the previous
kernel and DTBs under `/home/certe/panel-fallback-single-dsi/`;
`./tools/restore-single-dsi-panel.sh` puts them back and regenerates the
initramfs.  The boot partition is a 256M EFI partition with no room for two
initramfs images, which is why the fallback initramfs is regenerated rather
than stored.

To replace only the DTB (no kernel reinstall), as after this fix:

```
sudo install -Dm644 \
  src/kernel/arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4.dtb \
  /boot/dtb/linux-mibook/qcom/sc8180x-xiaomi-book-12.4.dtb
sudo install -Dm644 \
  src/kernel/arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4.dtb \
  /boot/dtb/linux-mibook/qcom/sc8180x-xiaomi-book-12.4-oc.dtb
```

### Second dual-link boot (2026-10-03 16:32) — links up, image garbled

With the secondary node fixed the whole pipeline came up cleanly:

```
msm_dpu ae01000.display-controller: bound ae94000.dsi (ops dsi_ops [msm])
msm_dpu ae01000.display-controller: bound ae96000.dsi (ops dsi_ops [msm])
[drm] fb0: msmdrmfb frame buffer device
```

`card0-DSI-1` reports `connected`/`enabled` with two 1600x2560 modes and there
is not a single DSI or DSC error in dmesg.  The panel nevertheless shows
garbage: bright noise over the whole right half, the left half mostly
white/grey with faint horizontal streaks and noise in its lower half, split
exactly on the seam between the two 800-column links.

So the two links, the timing and the DSC *transport* are all correct, but the
panel's DSC decoder does not agree with the 800-wide, slice-height-20
geometry that mainline uses for the sibling PPC357DB1-4.  The bring-up driver
was verified with a **1600-wide, slice-height-40, single slice**, and that is
what drives the fallback below.

### The shipped configuration and the experimental one

`csot_pnc357db1_4_single_desc` is the same panel on DSI0 only, with the
verified DSC parameters.  Probe picks it automatically when the panel node has
no second graph port, so one kernel boots either wiring:

* `panel-dtb/sc8180x-xiaomi-book-12.4.single-link.dtb` — **the default and the
  one that renders correctly**: DSI0 only, no `port@1`, no dual-DSI flags,
  DSI1 disabled (md5 `1adbba631ade4c166580ae3c66a58b41`);
* `panel-dtb/sc8180x-xiaomi-book-12.4.dual-link.dtb` — both links, the layout
  that renders garbage; kept for further DSC experiments.

`./set-panel-link-mode.sh single|dual` installs either one into both
GRUB-referenced DTB paths.

## Video decode: the hardware is IRIS1, and the SC8180X entry is device-tree only

The SC8180X video accelerator is a **Venus/IRIS VPU**.  What exists today:

* the `venus` driver has no SM8150/SC8180X platform data at all (`core.c` stops
  at `sc7280`/`sm8250`); `xiaomi-only.config` disables it and builds `iris`;
* VIDEOCC is already upstream for this SoC (`videocc-sc8180x` on
  `qcom,sm8150-videocc`, with `VENUS_GDSC`, `VCODEC0_GDSC`, `VCODEC1_GDSC`
  and the IRIS core clocks), and `gcc-sc8180x` has the Venus reset with the
  right delay;
* `linux-firmware` carries several candidates, but none is the one Windows
  uses (`qcom/vpu-1.0/venus.mbn` is `VIDEO.VPU.1.0-00119`, `vpu20_p1.mbn` is
  `video-firmware.1.0-ed457c1`, `venus-5.4/venus.mbn` is `VIDEO.VE.5.4`);
* neither `sc8180x.dtsi` nor mainline has a video-codec node, and the ACPI
  tables do not describe the block at all.

### What the Windows install proves

The Windows partition is still on the NVMe.  Its SYSTEM registry hive has a
`VENUS` subsystem service (`VENUS_QCOM_DEVICE_0`, next to the ADSP/SLPI/CDSP/
WPSS subsystems), the driver package is `qcdx8180`, and the video firmware it
ships is `qcvss8180.mbn`, whose build string is:

```
QC_IMAGE_VERSION_STRING=VIDEO.IR.1.2-00042-PROD-1
```

`IR.1.2` means the **IRIS1** generation (the `VIDEO.VE.*` strings are the
older AR50 `venus-*` firmware, `VIDEO.VPU.*` the IRIS2 one).  So this board is
IRIS1 with the Gen1 HFI, which also matches its SM8150 era.

### Why it cannot work today

The upstream `venus` driver (this tree, 6.18) stops at `sm8250` and has no
platform data for SM8150/SC8180X.  The `iris` driver, which is the one with
the IRIS1 Gen1 code path (`iris_platform_sm8250.c`), only matches
`qcs8300`, `sm8250`, `sm8550`, `sm8650` and `sm8750`.  There is no upstream
platform data for this SoC in either driver, and no matching firmware in
`linux-firmware`.

### The probe attempt in this tree (branch `xiaomi-mainline-panel2`)

`613d5b87508e` adds a video-codec node to `sc8180x.dtsi`
(`0xaa00000`, SPI 174, `apps_smmu` stream `0x2100 0x0400`, the videocc GDSCs
and IRIS clocks, two NOC paths), enables it for the board and adds an
`sc8180x` entry to the **venus** driver using the SM8250 tables with the
IRIS2/HFI-6XX assumption.  That assumption is now known to be wrong (the
hardware is IRIS1), so the entry is a probe vehicle only: its only purpose is
to find out whether the block is where the sm8250/sc7180 layout suggests and
what the probe reports.

The PoC has since been moved **to the iris driver**, which is the correct one
for IRIS1:

* `iris_platform_sm8250.c` gains `sc8180x_data` (Gen1 HFI, `iris_vpu2_ops`,
  SM8250 tables, `fwname = "qcom/vpu-1.0/venus.mbn"`, `pas_id = IRIS_PAS_ID`);
* `iris_probe.c` matches `qcom,sc8180x-venus`, and `sc8180x.dtsi` grew an
  `operating-points-v2` table of its own (the iris driver calls
  `devm_pm_opp_of_add_table()`);
* `CONFIG_VIDEO_QCOM_IRIS=m` is set and `CONFIG_VIDEO_QCOM_VENUS` is turned
  off in `xiaomi-only.config`: `iris/Makefile` only compiles
  `iris_platform_sm8250.o` when venus is *not* selected, and no sc8180x board
  uses the venus driver.

### The real blocker was the VIDEOCC driver, not the video driver

Probing the decoder on hardware showed the device never even reached a driver:

```
aa00000.video-codec: waiting_for_supplier
ab00000.clock-controller: waiting_for_supplier, no driver bound
```

The video codec's clocks and its `VENUS_GDSC`/`VCODEC0_GDSC` power domains all
live in VIDEOCC, so with no driver on `ab00000.clock-controller` the codec can
never probe.  Two separate holes caused that:

* `drivers/clk/qcom/videocc-sm8150.c` only matched `qcom,sm8150-videocc`,
  while the device tree node has
  `compatible = "qcom,sc8180x-videocc", "qcom,sm8150-videocc"` — the DT half
  of that upstream series landed, the driver half did not (fixed here);
* `CONFIG_SM_VIDEOCC_8150` was not set at all, so the driver was not even
  built.

With both fixed, the chain did exactly that on hardware: `ab00000.clock-controller`
bound to `video_cc-sm8150`, `aa00000.video-codec` bound to `qcom-iris`, and the
iris driver reached its power-on step.  It then failed on one more device tree
detail:

```
qcom-iris aa00000.video-codec: dev_pm_opp_set_rate: failed to find OPP for freq 533000000 (-34)
qcom-iris aa00000.video-codec: power on failed
qcom-iris aa00000.video-codec: core init failed
```

`ftbl_video_cc_iris_clk_src` offers up to 533 MHz and the OPP table only went to
444 MHz, so the highest rate had no OPP; 365 MHz was missing as well.  Both are
added.

The device-tree side has been checked as far as software can take it:

* `0xaa00000` overlaps nothing in the SC8180X memory map (camera ends at
  `0xa8f8800`, VIDEOCC starts at `0xab00000`, so Venus sits between them, which
  is what the address map implies);
* `apps_smmu 0x2100 0x0400` is used by no other node on this SoC;
* `GIC_SPI 174` is used by no other node on this SoC, and it is the same
  interrupt that sm8250 and sc7180 use for Venus;
* the clock names (`iface`, `core`, `vcodec0_core`), the power domains
  (`venus`, `vcodec0`, `mx`) and the resets (`bus`, `core`) all resolve to the
  videocc this device tree already instantiates.

So a failing probe now points at the VPU/PCIe-side details (physical address
space id, secure context bank) or at the firmware, not at the memory map.

What is still missing before a decoder can work:

1. firmware: the Windows `qcvss8180.mbn` is signed for the Windows PIL path
   and is not a drop-in for `linux-firmware`; a matching IRIS1 firmware for
   SC8180X has to be sourced from a vendor/Android image (none of
   `vpu-1.0/venus.mbn`, `vpu-2.0/venus.mbn`, `venus-5.4/venus.mbn` carries an
   `IR.1.x` version string);
2. verification of the physical address space id and the secure context bank
   for this SoC (both copied from SM8250 for now);
3. userspace: there is no VA-API driver for this VPU, so even a working
   `/dev/video0` would only be usable through a V4L2 stateful decoder path
   (for example ffmpeg's `v4l2` hwaccel), not through the browser stack.

### Outcome: parked, with the video node disabled

The probe answered everything it could and then had to be stopped:

* the device tree side is fully correct — VIDEOCC binds, `aa00000.video-codec`
  binds to the iris driver, the OPP table is complete;
* the iris driver gets as far as powering the VPU on, and that is where the
  machine dies: with no firmware the VPU does not answer the boot-handshake
  registers, all four boot attempts stalled ~27 s in with
  `rcu_preempt detected stalls`, and the traces only show victims blocked on
  mm locks (no iris frame survives).  (The "no firmware" part of this diagnosis
  was wrong — the driver never requested any firmware at all, see below.)

So the video-codec node is now `disabled` in `sc8180x.dtsi` — the node and its
full resource set stay in the tree as a reference, but nothing probes the
hardware.  Three real upstream bugs found on the way are kept:

1. `videocc-sm8150.c` did not match `qcom,sc8180x-videocc`, so the VIDEOCC
   node (added to this device tree by an upstream series whose driver half
   never landed) had no driver at all;
2. `CONFIG_SM_VIDEOCC_8150` was not set, so that driver was not even built;
3. the video OPP table was missing the clock's own top rates (533 MHz and
   365 MHz), which is what the first successful probe tripped over.

What a future attempt needs, in order:

1. an IRIS1 firmware for SC8180X (the Windows one is `VIDEO.IR.1.2` and is
   signed for the Windows PIL path; nothing in `linux-firmware` carries an
   `IR.1.x` version string);
2. a way to power the VPU on without wedging the machine when the firmware is
   absent — upstream `iris` polls the VPU registers right after power-on;
3. userspace support (no VA-API driver exists for this VPU).

To re-enable the experiment later: add `&venus { status = "okay"; };` to the
board device tree, build, and be ready to boot the previous kernel if the
firmware is still missing.

### Second round: SC8280XP/SM8350 is the reference, and the blocker was `memory-region`

Re-checked 2026-10-04 against the upstream series and the driver source.

**sc7180 is the wrong reference, SC8280XP is the right one.**  sc7180 sits in
the *venus* driver with `HFI_VERSION_4XX` and `venus-5.4/venus.mbn`, five
clocks and `iommus = <&apps_smmu 0x0c00 0x60>` — the previous AR50 generation,
not usable for an IRIS1 core.  The live series
`[PATCH v7 0/6] media: iris: enable SM8350 and SC8280XP support` instead adds
SM8350/SC8280XP to the iris driver's **Gen1** path, and does it with device
tree only: the node is
`compatible = "qcom,sc8280xp-iris", "qcom,sm8250-venus"`, a SoC-specific
string with the SM8250 one as fallback, so "driver bits ... covered by
compatible string now" — the sm8250 platform data applies unchanged.  Its
cover letter also records two things that match this board: the **venus**
driver fails to boot the Iris core on SM8350 (a `UC_REGION` error), and the
SM8250 firmware is *not* compatible with SM8350/SC8280XP, so every Gen1 SoC
needs the firmware extracted from its own Windows/Android install.

**Why the earlier probe could not have reached the firmware.**
`iris_firmware.c` gets the carve-out through the node's `memory-region`
phandle and returns `-EINVAL` when it is missing; neither the node nor this
device tree had such a region, so `request_firmware()` was never called and
the firmware question was never actually tested.  Two more details from the
source: `dev_pm_opp_set_rate()` in `iris_vpu_common.c` is called *without*
checking its return value, so the OPP complaint in the log was not by itself
the fatal step, and the first thing that touches VPU registers after power-on
is `set_preset_registers()` — which is where a machine that "hangs after
power on" would be hanging.

**What changed in this round:**

* `sc8180x.dtsi` gained a `video_mem` carve-out (`0xa0000000`, 5 MB, `no-map`,
  immediately above the last bootloader reservation) and the node now has
  `memory-region` and `firmware-name`;
* the compatible is upstream-shaped (`"qcom,sc8180x-iris",
  "qcom,sm8250-venus"`) and the driver-side `sc8180x_data` entry is gone: it
  was a byte-identical copy of `sm8250_data`, so the fallback is exactly
  equivalent and the iris driver diff is now zero;
* the firmware was extracted from the Windows partition
  (`Windows/System32/qcvss8180.mbn`, `VIDEO.IR.1.2-00079-PROD-2`, ELF32 ARM
  with the usual Qualcomm hash-table program headers) and staged in
  `firmware/qcom/sc8180x/` with its provenance;
* the node is still `disabled`, so nothing probes until a deliberate run.

**Still open, in order:**

1. install the firmware
   (`sudo install -Dm644 firmware/qcom/sc8180x/venus.mbn
   /lib/firmware/qcom/sc8180x/venus.mbn`) and enable `&venus`;
2. check the apps_smmu stream: `0x2100` is copied from sm8250 while sc8280xp
   uses `0x2a00`, so it is per-SoC silicon.  ACPI does not answer it — the
   IORT has no Venus named component and the DSDT only carries the PILC/MON0
   engine manifest (`Venus`, `ArmSmmuV2`, one non-secure plus four secure page
   tables, matching the iris driver's `tz_cp_config`) with a SMMU *UUID*, no
   number — so expect to read the real one from an arm-smmu fault;
3. if power-on wedges before any firmware message: this SoC's video clock
   controller has a `VIDEO_CC_IRIS_AHB_CLK` that SM8250 and SM8350 do not
   have, and none of the three clocks the driver enables covers it — a bus
   stall on register access would look exactly like that;
4. userspace: still no VA-API driver, so only the V4L2 stateful path (ffmpeg
   `v4l2m2m`), not the browser stack.

One naming caveat to keep in mind: upstream's binding patch describes the
SM8250 block as "Iris v2.xx" while this board's firmware version is
`VIDEO.IR.1.2`.  If `IR.1.2` really is an *older* Iris revision than the
SM8250 core, the Gen1 HFI/`iris_vpu2_ops` path may not match the firmware and
the failure will look like a firmware boot/handshake error rather than a
device-tree one.  The SC8280XP/SM8350 series is still the closest available
reference (same driver path, same SoC vintage), and it is the only in-tree
one; the first probe after install will answer this.

**Probe run: `tools/probe-vdec-run.sh`, and the packaging failure it replaces.**

The first attempt at this (package `-6`, 2026-10-04 ~08:36) did not boot
properly: the kernel log flooded with `BPF: Invalid name` and
`failed to validate module [fuse] BTF: -22`, and `pd-mapper.service` (the
Qualcomm PD mapper) failed, so the machine was put back on the previous
package.  The cause was the packaging, not the VPU work:
`tools/make-kernel-package.sh` did not put the kernel image into the package or
into `/boot`, so `pacman -U` replaced all 2557 modules while `/boot` kept the
kernel from an older build - and the mkinitcpio hook was interrupted, so the
initramfs stayed old as well.  The booted kernel then validated every module's
BTF against its own vmlinux and rejected modules from a different build (hence
the "BPF" flood), and the remoteproc/qrtr stack behind `pd-mapper` stopped
working.  Nothing in the device tree or the iris driver was implicated: the
interrupted install also left the old (node-disabled) DTB in place, so the VPU
itself never probed.

What changed since:

* the package now ships `/boot/vmlinuz-linux-mibook` (the tree's `Image`,
  gzipped) plus a `.INSTALL` that runs `depmod` and `mkinitcpio -P`, so a
  package install can no longer leave a kernel/module mix;
* it ships both GRUB DTB paths as the **parked** DTB (VPU node disabled) and,
  separately, a `sc8180x-xiaomi-book-12.4-vdec-probe.dtb` produced by setting
  that node's `status` to `okay`.  The board DTS in the tree stays parked, so
  the default boot can never probe the VPU;
* `tools/probe-vdec-run.sh` now does, in order: save the known-good `/boot`
  files into the fallback directory, install the staged firmware, write
  `blacklist qcom-iris` (a plain blacklist still allows an explicit
  `modprobe qcom-iris`), install the package, copy the probe DTB over both GRUB
  paths (keeping a `-parked.dtb` copy), and then *verify* before telling you to
  reboot: `/boot/vmlinuz` must be this tree's build, the initramfs must be
  newer, both DTBs must have the node enabled with its `memory-region`, and the
  blacklist must be in place.  Any mismatch aborts the script;
* `tools/recover-working.sh` now restores the parked DTB and leaves the kernel
  alone by default, because restoring the fallback kernel while the new modules
  are installed is exactly the mix that broke the `-6` boot.  `--restore-kernel`
  exists for a kernel that cannot boot at all, with that caveat printed.

The first `-8` install then exposed two more packaging defects, both fixed in
`-9` and both worth remembering:

* the package did not ship `/etc/mkinitcpio.d/linux-mibook.preset`.  The
  previous package owned that file, so pacman deleted it as part of the
  upgrade, `mkinitcpio -P` then failed with
  `No presets found in /etc/mkinitcpio.d`, and `/boot` was left with an
  initramfs built from the *old* kernel's modules (the pacman mkinitcpio hook
  stays quiet in this situation).  The preset is now shipped, and the
  `.INSTALL` scriptlet falls back to an explicit
  `mkinitcpio -k /boot/vmlinuz-linux-mibook -g /boot/initramfs-linux-mibook.img`
  if it ever finds no presets again;
* every file was packaged with the build user's uid/gid, so the installed
  kernel modules were owned by `certe` instead of root - a local privilege
  problem, since that user could edit modules root later loads.  `bsdtar` now
  records `root:root`, which also removes the per-file warnings for the vfat
  `/boot` partition.  `tools/probe-vdec-run.sh` fails its pre-reboot
  verification if the installed module is not root-owned.

The iris driver bug fixes from the first round are kept (the `sc8180x-videocc`
match in `videocc-sm8150.c`, `CONFIG_SM_VIDEOCC_8150`, the missing 533/365 MHz
OPPs), because they are independent of how the VPU node is expressed.

### Third round: the VPU answers — correct register map, and the wall at TZ

This round got further than every previous attempt combined, and ended at a
boundary that is *not* a Linux bug.  The short version:

    VPU powered -> registers respond -> IRQ init done -> firmware in place
    -> TZ authenticates the image -> TZ refuses to configure/release the core

**The register map was the wall.**  `iris_vpu_register_defines.h` hardcodes the
*Venus 6xx* layout (`CPU 0xA0000`, `CPU_CS 0xA0000`, `WRAPPER 0xB0000`), which is
what SM8250-and-later use.  SM8150/SC8180X uses the **older Venus 4xx layout**:

| block | iris driver had | SC8180X uses |
| --- | --- | --- |
| CPU | `0x000A0000` | `0x000C0000` |
| CPU_CS | `0x000A0000` | `(CPU + 0x12000)` = `0x000D2000` |
| WRAPPER | `0x000B0000` | `0x000E0000` |
| VBIF | - | `0x00080000` |

Three independent sources agree: the mainline **venus** driver
(`hfi_venus_io.h` has both layouts, `*_V6` vs plain), the vendor's downstream
IRIS1 header (`msm-extra/video-driver`, `hfi_io_common.h`, the same values), and
the hardware itself - after the change `WRAPPER_INTR_MASK` (`0x0E0010`) reads
**`0x1f6`**, its documented reset value, and everything after it proceeds.  Every
access before that went to an unmapped address, which is why an unpowered block
*stalled* the bus (no response) and a powered one raised a synchronous external
abort (`0x0B0010`, `Comm: v4l_id`) - the two symptoms that consumed several
rounds.

The same conclusion came out of the vendor device tree, which supplied the rest
of the node: **six** clocks (`gcc_video_axic`, `gcc_video_axi0`,
`gcc_video_axi1`, `video_cc_mvsc_core`, `video_cc_mvs0_core`,
`video_cc_mvs1_core`) instead of three, four resets (`GCC_VIDEO_AXIC_CLK_BCR`,
`VIDEO_CC_MVSC_CORE_CLK_BCR`, `GCC_VIDEO_AXI0_CLK_BCR`,
`GCC_VIDEO_AXI1_CLK_BCR`) instead of two, and the IOMMU SID **`0x1300 0x60`**
instead of SM8250's `0x2100 0x400`.  `axic` is the AXI *config* port a CPU
register access goes through and was simply never enabled.  The vendor window is
2 MB, but that overlaps the VIDEOCC at `0x0AB00000` and mainline *reserves* its
region, so the node keeps 1 MB.

**What is in the tree from this round**

* `sc8180x.dtsi`'s venus node: six clocks, four resets (AXIC carried as the
  driver's `"bus"` reset, so no driver change was needed for it), six
  clock-names, SID `0x1300 0x60`, `memory-region`, 1 MB window;
* iris: a new `IRIS_AXIC_CLK` type, `"axic"`/`"axi1"` entries in the SM8250
  clock table, and best-effort enable/disable of both (a missing clock returns
  `-EINVAL` and is tolerated, so SM8250 is unaffected);
* `reserved_memory` is now labelled so the board DTS can add children, and the
  board DTS carries a **ramoops** region (`0xa0500000`, 1 MB) - see the capture
  recipe below;
* `tools/update-probe-dtb.sh` (rebuild DTBs, install parked + probe variants
  into both GRUB paths, verify), `tools/repack-venus-firmware.py`,
  `windows-drivers/` (the Windows PIL and video drivers plus their INFs) and
  `~/acpi-dumps/` (DSDT/CSRT).

**The firmware path, step by step**

`iris_firmware.c` needs the node's `memory-region`; the SM8250 platform data
uses PAS id 9 and `qcom/sc8180x/venus.mbn` (from the Windows driver store,
`qcvss8180.mbn`, ELF32, `VIDEO.IR.1.2-00079-PROD-2`).  With the register map
fixed, the sequence now runs: power-on -> `WRAPPER_INTR_MASK = 0x1f6` -> IRQ
init -> `qcom_mdt_load` -> `PAS auth and reset`.  Two findings decide the rest:

* the Windows image marks all three LOAD segments `QCOM_MDT_RELOCATABLE`
  (p_flags bit 27), so the loader calls `qcom_scm_pas_mem_setup(9, addr, size)`
  - and **TZ answers `-EINVAL` for every region we can name**: our own
  `0xa0000000`, the bootloader's 5 MB carve-out `0x9ffb0000` (whose size matches
  the firmware footprint exactly), and the 40 MB / ~43 MB reserved pools;
* `qcom_scm_pas_init_image` *succeeds* - TZ authenticates the untouched image -
  so this is not a signature problem.

Two experiments narrowed it further:

* **Repacking the image does not help.**  Clearing bit 27 and rebasing `p_paddr`
  onto the carve-out (only 9 bytes change, all inside the program-header table,
  no hashed segment byte touched) makes the loader skip the SCM call
  (`qcom_mdt_load ret=0`, firmware in place) but `qcom_mdt_load` then fails one
  step earlier with `error -22 initializing firmware`: **TZ authenticates the ELF
  header and program-header table too**, so the image cannot be re-shaped
  (`tools/repack-venus-firmware.py` is kept for reference);
* skipping *only* the SCM call, via a debug parameter on `mdt_loader`, gets the
  firmware into memory (`ret=0`) but `PAS auth ret=-22` - consistent with TZ
  wanting a configured region before it will release the core.

**The control that matters:** `qcom/XIAOMI/BOOK124/qcadsp8180.mbn` is
*relocatable too* (16 segments, 26 MB) and it goes through the identical
`qcom_mdt_load` -> `qcom_scm_pas_mem_setup` path **and works** on this machine
(the SLPI likewise, 18 segments, in `0x92c00000`).  So the TZ call is
implemented and functional here; the refusal is specific to the video PAS -
either its id or the region TZ has configured for it.  `PAS_IS_SUPPORTED`
(`0x07`) exists in the kernel's command set but returns 0 for every id on this
TZ, i.e. this is an older TZ revision than the kernel assumes.

Sweeping ids to find the video PAS is **not safe**: with `pas_id=12` the machine
wedged even with the core release disabled (`no_auth=1`), because feeding the
video image to another subsystem's PAS disturbs a live engine.  Do not repeat it.

**What Windows does (from `qcpil8180.sys`, copied into `windows-drivers/`)**

It is a KMDF **WMI** driver (imports `IoWMIRegistrationControl`; contains no
`smc`/`hvc` instruction), and it knows the subsystem as `VENUS` among
`ADSP CDSP SLCPI SPSS SLPI MODEM WCNSS ISS9 THSS9 SSCS8 HSS9 GFXSUC GCTL RSDS`.
Its messages show a flow with steps mainline has no equivalent for:

    Tree ELF image authentication                       = Linux pas_init_image (works)
    Request to define relocatable subsystem memory      = Linux pas_mem_setup  (fails)
    Request to share subsystem memory                   - nothing in Linux
    Request to unlock subsystem memory / XPU            - nothing in Linux (TREE)

The kernel's whole PIL command set is `INIT_IMAGE 0x01`, `MEM_SETUP 0x02`,
`AUTH_AND_RESET 0x05`, `SHUTDOWN 0x06`, `IS_SUPPORTED 0x07`, `MSS_RESET 0x0a`;
the DSDT exposes `\_SB.SCM0` (`QCOM040B`), `\_SB.TREE` (`QCOM0476`, whose `_CRS`
points at a dynamic `\_SB.TCMA`/`TCML` region) and `\_SB.PILC` (`QCOM041B`), and
the video device's `_CRS` lists only MMIO/IRQs/GPIOs - no firmware RAM range.
The carve-outs are the EFI reservations visible in `/proc/iomem`
(`9d400000-9ff91fff`, `9ffb0000-a04fffff`).

**Where it stands, and how to go further**

The Linux side is correct up to the TZ boundary: power, clocks, resets, SID,
register map, IRQ, firmware placement and image authentication all work, and
failures are clean and repeatable (no bus access in the teardown path).  To get
past it we need one of:

* the **video PAS id** and the **region TZ has configured** for it, from the
  Windows/UEFI/secure side (the vendor's PIL configuration or a memory-map dump)
  - not by probing TZ, which is unsafe;
* or the **extra TZ steps** (`share`, XPU `unlock`), if those turn out to be
  prerequisites rather than follow-ups.

**Debug hooks and tools from this round** (all temporary; revert before any
upstream submission)

| hook | where | purpose |
| --- | --- | --- |
| `fw_phys`, `fw_size` | `qcom_iris` params | move the carve-out without touching the DTB |
| `pas_id`, `fw_name` | `qcom_iris` params | try another PAS id / firmware |
| `no_auth` | `qcom_iris` param | stop after image init; never releases the core |
| `scan_pas` | `qcom_iris` param | ask TZ `PAS_IS_SUPPORTED` for ids 0..31 |
| `skip_pas_mem_setup` | `mdt_loader` param | skip the TZ relocation call only |
| `IRIS-TRACE:` breadcrumbs | iris `core/resources/vpu_common/firmware` | progress log |
| VPU-free teardown | `iris_vpu_power_off_controller` | makes a failed probe survivable (it used to abort a second time and take the machine down) |
| `debug/videocc-peek.py` | `dump`, `powerup`, `gdsc-test`, `scan`, ... | /dev/mem view of VIDEOCC/GCC; `scan` and VPU reads are **not** safe |

Gotchas worth keeping:

* `mdt_loader` is loaded **from the initramfs**, so replacing
  `/usr/lib/modules/.../mdt_loader.ko` does nothing until `mkinitcpio -P` packs
  the new copy in;
* `find ... -iname A -o -iname B -exec cp {} dir \;` only applies `-exec` to
  `B`; the `.sys` files were silently skipped the first time;
* a kernel-mode access to an unmapped VPU register is an oops and is survivable,
  a *user-mode* `/dev/mem` read of the same address can take the machine down -
  do not "scan" the window;
* journald cannot flush during a bus stall, and a hard power-cycle wipes RAM;
  for a post-mortem either panic deliberately (`panic_on_rcu_stall=1`,
  `kernel.panic=20`, plus a shortened `rcu_cpu_stall_timeout`) so ramoops
  captures the log and the machine reboots itself - read it back with
  `sudo cat /sys/fs/pstore/dmesg-ramoops-0` - or photograph the screen.

### Fourth round: the VPU almost boots — PGCM, and the wall is a secure-world unlock

This round got the VPU from "powered but silent" to "firmware in place, region
configured, image authenticated, core released by TZ".  It ends at a
secure-world prerequisite that mainline has no implementation for.  Status:

    power-on / clocks / resets / IRQ          OK   (WRAPPER_INTR_MASK reads 0x1f6)
    firmware placed in the PIL pool           OK   (qcom_mdt_load ret=0)
    TZ region setup (PAS_MEM_SETUP)           OK
    TZ image authentication (INIT_IMAGE)      OK
    wrapper firmware window (FW/CPA regs)     BLOCKED - writes stall the bus
    VIDEOCC AHB clock (iris_ahb)              BLOCKED - enable bit cannot be set
    TZ core release (AUTH_AND_RESET)          BLOCKED - no safe way to program the above first

**PGCM was the region blocker.**  `qcom_scm_pas_mem_setup()` returned `-EINVAL`
for *every* address we tried - our own carve-out, the bootloader's 5 MB EFI
reservation (`0x9ffb0000`), the TREE region (`0x9e400000`), and the pool bases.
The Windows PIL driver's own configuration (read out of the SYSTEM hive with
`tools/hive-dump.py`, which is a minimal read-only regf parser added this round)
explains why:

    \DriverDatabase\...\qcpil8180.inf...\Configurations\PIL_Device.NT\Device\PGCM
        BaseAddress = 0x8bd80000      Size = 0x0e780000
    ...\Device\PilConfig
        HypProtectionEnabled = 0x1
    ...\Device\SubsystemLoad\VENUS
        MemoryAlignment = 0x0        MemoryReservation = 0x500000   (no fixed address)

Every subsystem that *works* on this machine has its region inside that pool
(`MPSS 0x8d800000`, `ADSP 0x90800000`, `CDSP 0x92400000`, `SLPI 0x92c00000` -
all from the same registry tree), and every address we had tried was outside it.
`0x8bd80000`, `0x9a000000` and `0x8c000000` all return `qcom_mdt_load ret=0`;
`0x94000000` does not (the SLPI's 20 MB ends exactly there).  `video_mem` in
`sc8180x.dtsi` now lives at `0x8bd80000` (5 MB) for that reason.  Note the
reservation size (5 MB) equals the image footprint exactly, and the video
firmware is allocated dynamically like the ADSP's - only MODEM has a pinned
`MemoryAddress`.

**Two more fixes came out of the vendor sources**

* the node gained `VIDEO_CC_IRIS_AHB_CLK` (`"ahb"`), which the downstream PIL
  node lists as a proxy clock together with `xo` and `core`, and the driver
  enables it in `power_on_controller` (best effort, so other platforms are
  unaffected);
* `iris_vpu_boot_firmware()` had been writing two Venus-6xx-only registers
  (`CPU_CS_H2XSOFTINTEN` 0x148, `CPU_CS_X2RPMH` 0x168).  `hfi_venus.c` writes
  them only for IRIS2/IRIS2_1/AR50-lite; the Venus-4xx boot path stops after
  `CTRL_INIT`.  Those writes are gone.

**The two blockers, and why they are the same blocker**

1. `iris_vpu_setup_fw_region()`, added this round, mirrors
   `venus_reset_cpu()`'s non-IRIS2 path: it programs the wrapper's
   `WRAPPER_FW_START/END_ADDR` (0x1028/0x102C), `WRAPPER_CPA_START/END_ADDR`
   (0x1020/0x1024), `WRAPPER_NONPIX_START/END_ADDR` (0x1030/0x1034),
   `WRAPPER_CPU_CGC_DIS` (0x2010), `WRAPPER_CPU_CLOCK_CONFIG` (0x2000) and
   releases the CPU with `WRAPPER_A9SS_SW_RESET` (0x3000, `BIT(4)` holds it).
   The vendor PIL node maps exactly this block (`reg = <0xaae0000 0x4000>`,
   i.e. `0xE0000..0xE4000`), and the block is what TZ reads when it releases
   the core - with it zeroed the core would fetch from address 0.
   In practice **every store into that half of the wrapper stalls the bus**
   (hard lock: caps-lock dead, no panic, no RCU stall report, empty pstore),
   while the low window (`WRAPPER_INTR_STATUS/MASK` at 0x0C/0x10) reads and
   writes normally.
2. `video_cc_iris_ahb_clk` (VIDEOCC 0x8f4, `BIT(0)`, parent
   `video_cc_iris_clk_src`) **cannot be enabled**: a raw write does not stick,
   and neither does the clock framework's - which still reports success because
   that branch's `halt_check` is `BRANCH_VOTED`, a modifier with no halt check
   at all, so `clk_prepare_enable()` can never fail there.  The shared RCG
   itself is fine (its enable lives in `CFG_REG`, not in `CMD_RCGR` bit 0, and
   `mvsc_core`/`mvs0_core` run at the programmed 533 MHz), so the missing piece
   is the AHB branch specifically - i.e. the VPU's register-interface clock.

(1) and (2) are the same problem seen from two sides: the AHB clock gates the
wrapper's upper window, and both are unreachable from the non-secure OS.

**The wall** is therefore the secure-world handshake that the Windows PIL driver
performs and mainline has no equivalent for.  From `qcpil8180.sys` (a KMDF WMI
driver - it imports `IoWMIRegistrationControl` and contains no `smc`/`hvc`
instruction, so the secure calls are issued through its TREE/"PIL-TZ" plumbing):

    Tree ELF image authentication                       = Linux pas_init_image   (works)
    Request to define relocatable subsystem memory      = Linux pas_mem_setup    (works)
    Request to share subsystem memory                   - nothing in mainline
    Request to unlock subsystem memory / XPU            - nothing in mainline

The kernel's whole SCM surface is PIL `INIT_IMAGE 0x01`, `MEM_SETUP 0x02`,
`AUTH_AND_RESET 0x05`, `SHUTDOWN 0x06`, `IS_SUPPORTED 0x07`, `MSS_RESET 0x0a`,
plus `MP_VIDEO_VAR 0x08`, `MP_ASSIGN 0x16`, `SHM_BRIDGE_{CREATE,ENABLE,DELETE}`
0x1c/0x1d/0x1e.  `PAS_IS_SUPPORTED` exists in the kernel but returns 0 for
every id on this TZ (it is an older TZ revision than the kernel assumes).  Both
the ACPI DSDT (`\_SB.SCM0` = QCOM040B, `\_SB.TREE` = QCOM0476 with a dynamic
`TCMA/TCML` region, `\_SB.PILC` = QCOM041B) and the CSRT contain only resource
*names* and vendor blobs - no PAS ids, no region addresses, no XPU permissions.

**Who actually performs the unlock (resolved from the registry and the binaries)**

Using `tools/hive-dump.py` on the SYSTEM hive, the ACPI devices map to services:

    \Enum\ACPI\QCOM040B  ->  qcscm     (System32\DriverStore\...\qcscm8180.sys)
    \Enum\ACPI\QCOM041B  ->  qcPILC    (qcpil8180.sys)
    \Enum\ACPI\QCOM0476  ->  QcTrEE    (QcTrEE8180.sys)

Both `qcscm8180.sys` and `QcTrEE8180.sys` contain **no `smc`/`hvc` instruction at
all**.  Their strings show why: the secure calls are made through a
hypervisor-mediated "TREE" target - `TreeOpenTarget` / `TreeSendIrp`, with
`AllocMemFromTreeSMB` / `FreeMemFromTreeSMB` allocating the shared block - and
they reference the TZ secure applications `qcom.tz.winsecapp` and
`qcom.tz.uefisecapp`.  In other words the vendor's *share/unlock subsystem
memory* is a **TZ secapp operation** reached through a Windows-only client
stack, not an SIP SCM call that `qcom_scm` could simply mirror.  The only
mainline call with comparable semantics is `qcom_scm_assign_mem()`
(`SVC_MP`/`MP_ASSIGN 0x16`), whose VM and permission arguments are not
derivable from anything we can read.

That is the end of the Linux-reachable path: the blocker is a secure-world
service with a Windows-side client.

**Fifth round: the SCM path completes, and the reset comes from below Linux**

With the wrapper window left to TZ (see the venus `use_tz` rule below) the trace
finally runs all the way through the secure firmware handshake:

    fw_load: name qcom/sc8180x/venus.mbn
    set remote state (SCM call)
    set remote state ret=-22          <- expected: venus tolerates -EINVAL here
    fw region phys=0x8bd80000 size=5242880
    qcom_mdt_load ret=0
    PAS auth and reset (SCM call)
    PAS auth ret=0                    <- TZ released the core
    mem protect video var (SCM call)
    boot_fw: ucregion map
    boot_fw: CTRL_INIT write

and then the machine resets.  Two details identify the failure: **pstore is
empty** (no kernel panic, although `panic_on_rcu_stall=1` and ramoops were
armed) and **journald never flushed the trace** even though `dmesg -w` showed it
live.  A reset with no panic and no flushed log came from *below* Linux - the
hypervisor/secure world or a hardware watchdog acting on a fault the OS cannot
see.  That is the signature of a NoC/XPU-class event from the VPU, which the
vendor driver handles explicitly (`FATAL:NOCErrInfo:
VCODEC_NOC_ERR_ERRVLD_LOW_OFFS` in `qcdxkm8180.sys`), and it matches the DSDT
engine manifest, which gives the video four pagetable sets (`VideoNonSecurePT`,
`VideoSecurePT1..4`).  Those secure context banks belong to TZ; mainline can
only declare the non-secure SID.

**The `use_tz` rule, which cost a round to rediscover**

    np = of_get_child_by_name(core->dev->of_node, "video-firmware");
    if (!np) core->use_tz = true;                  /* TZ-managed firmware */

    int venus_set_hw_state(struct venus_core *core, bool resume) {
            if (core->use_tz)
                    return qcom_scm_set_remote_state(resume, 0);  /* -EINVAL is fine */
            if (resume)
                    venus_reset_cpu(core);   /* WRAPPER_FW/CPA/NONPIX/CPU */
    }

i.e. the wrapper's firmware window (`0x1020`-`0x1034`, `0x2000`, `0x2010`,
`0x3000`) is written **only when the firmware is not TZ-managed**.  On the
secure flow it is TZ's register block, and stores to it **stall the bus** (hard
lock, no panic).  An earlier attempt to write it "like venus does" therefore had
to be removed, and `qcom_scm_set_remote_state(1, 0)` was added before the load
instead.  The AR50 boot order from `venus_boot_core()` was also adopted: mask
`WRAPPER_INTR_MASK` down to `0x8` (the V6-era `0x1f2` unmasks extra level
sources), write the HFI-version register, then `CTRL_INIT`.

**Artifacts added this round** (under `tools/` and `debug/`, plus `windows-drivers/`)

* `tools/hive-dump.py` - minimal read-only registry hive reader (regf/hbin/nk/
  vk/lf/lh/li, ASCII and UTF-16 names).  It is what found PGCM and the per-
  subsystem reservations.  Cell offsets are relative to the first hbin
  (file offset 0x1000) - getting that wrong makes the walk return zero keys.
* `debug/videocc-peek.py` - `/dev/mem` view of VIDEOCC/GCC with `dump`,
  `gdsc-test`, `powerup`, `ahb-on`.  Its `clk_off(bit1)` annotation is wrong
  (`CBCR_CLK_OFF` is bit 31); `scan`/VPU reads must not be used (they hang).
* `tools/repack-venus-firmware.py` - shows why firmware repacking is a dead end:
  clearing `QCOM_MDT_RELOCATABLE` and rebasing `p_paddr` makes the loader skip
  the SCM call, but TZ then rejects the image one step earlier, i.e. the ELF
  header and program-header table are part of what it authenticates.
* `tools/update-probe-dtb.sh`, the `ramoops` node, and the persistent capture
  recipe (`panic_on_rcu_stall=1`, `kernel.panic=20`, shortened
  `rcu_cpu_stall_timeout`) - note a *NoC* wedge does not reach the panic path,
  so a screen photo is still the fallback.
* iris debug parameters: `fw_phys`, `fw_size`, `pas_id`, `fw_name`, `no_auth`,
  `scan_pas`; and `skip_pas_mem_setup` on `mdt_loader`.  `mdt_loader` is loaded
  from the initramfs, so replacing its .ko requires `mkinitcpio -P`.
* `windows-drivers/` (qcpil8180 + qcdx8180 drivers and INFs) and
  `~/acpi-dumps/` (DSDT/CSRT).

**Traps that cost time this round, worth remembering**

* a module installed in `/usr/lib/modules` is not the module that is running
  until it is reloaded - check the build timestamp *and* a unique string from
  the new build (the `[dbg=intclear1]` tag exists for exactly this);
* `find ... -iname A -o -iname B -exec cp {} dir \;` applies `-exec` only to
  `B`;
* adding `WRAPPER_BASE_OFFS` to an offset macro that already contains it walks
  off the end of the ioremap and produces a level-3 translation fault - a
  *survivable* oops, unlike a bus stall, which is a hard lock;
* a user-mode `/dev/mem` read of an unmapped VPU register can take the machine
  down, while the same access from kernel context is an oops.

### Sixth round: SM8150 / Xiaomi Pad 5 (`nabu`) is the right reference, and it names the recipe

Checked 2026-10-04.  The Gen1 work was referenced against SM8250/SM8350/
SC8280XP (the only in-tree Gen1 path) and against the vendor SC8180X device
tree.  The correct family to compare against is **SM8150**: the Xiaomi Pad 5
(`nabu`, Snapdragon 855/860) is the same silicon generation, and its vendor
tree is public.

Mainline has *no* SM8150 video support — `venus` stops at
`sdm845`/`sc7180`/`sc7280`/`sm8250`, `iris` has no SM8150 entry, and
`sm8150.dtsi` has no video node — so the useful artefact is the downstream
tree (`MiCode/Xiaomi_Kernel_OpenSource`, branch `nabu-r-oss`; mirrored as
`crdroidandroid/android_kernel_xiaomi_sm8150`, read at `d43213ae`).

#### What it confirms

| Fact | SC8180X (this tree) | SM8150 vendor (`sm8150-vidc.dtsi`) |
| --- | --- | --- |
| node base / window | `0xaa00000`, 1 MB (the vendor 2 MB overlaps VIDEOCC) | `0xaa00000`, 2 MB — the same overlap with VIDEOCC at `0xab00000` |
| clocks | `gcc_video_axic`, `axi0`, `axi1`, `VIDEO_CC_MVSC/MVS0/MVS1_CORE` | identical six |
| resets | `GCC_VIDEO_AXIC_CLK_BCR`, `VIDEO_CC_MVSC_CORE_CLK_BCR`, `GCC_VIDEO_AXI0_CLK_BCR`, `GCC_VIDEO_AXI1_CLK_BCR` | identical four |
| non-secure SID | `0x1300 0x60` | `0x1300 0x60` |
| firmware region | `video_mem`, 5 MB | `VENUS_REGION_SIZE` = `0x00500000` |

The same file supplies the **secure context banks**, which this project had no
numbers for.  They line up with the DSDT manifest's four pagetable sets
(`VideoNonSecurePT` + `VideoSecurePT1..4`):

| bank | SID / mask | buffer types |
| --- | --- | --- |
| `venus_ns` | `0x1300 0x60` | `0xfff` |
| `venus_sec_bitstream` | `0x1301 0x4` | `0x241` |
| `venus_sec_pixel` | `0x1303 0x20` | `0x106` |
| `venus_sec_non_pixel` | `0x1304 0x60` | `0x480` |

#### What it changes about the blocker

`venus_boot.c`'s `pil_venus_auth_and_reset()` brings the core up with **no SCM
PIL call at all** — neither `venus_boot.c` nor `venus_hfi.c` contains a single
`qcom_scm_*`.  It:

1. writes the wrapper firmware window — `WRAPPER_SEC_CPA_START/END`
   (`0x1020`/`0x1024`) and `WRAPPER_SEC_FW_START/END` (`0x1028`/`0x102C`) —
   with `0 .. fw_sz`;
2. attaches the video IOMMU domain and maps the firmware at IOVA 0 to
   `resources->firmware_base` with `IOMMU_READ|WRITE|PRIV`;
3. clears `WRAPPER_A9SS_SW_RESET` (`0x3000`) to release the ARM9.

That is the *same* sequence this machine hard-stalls on when Linux writes it —
the third round established that `0x1020`-`0x1034`, `0x2000`, `0x2010` and
`0x3000` are TZ's block — and `firmware_base` is a fixed per-SoC physical base.
On Android the bootloader has already placed the signed image there, which is
why the vendor kernel needs neither `pas_init_image` nor `pas_mem_setup`.

Two consequences:

* the missing steps are the CPA/FW window programming, the ARM9 release and
  the IOVA-0 firmware mapping — not the SCM memory call;
* there is no `share`/`unlock`/XPU string anywhere in the vendor boot path, so
  the "request to share / unlock subsystem memory" steps read out of
  `qcpil8180.sys` look like a Windows hypervisor/TREE artefact rather than
  something the Venus core requires.  (For the record, `QcTrEE8180.sys`
  exports `MemShareServiceAllocSyscall` /
  `MemShareServiceSHMBridgeCreateSyscall` — the named implementation of the
  "share" half, if that path is ever revisited.)

How `nabu` actually decodes is itself a caution: through the downstream
`msm_vidc` V4L2 driver (pre-M2M, private `PORT_SETTINGS_*` events, no
`SOURCE_CHANGE`), which is a bring-up reference and not portable code.

#### Limits

* nothing here is mainline — all of it is vendor downstream and has to be
  rewritten for the iris path;
* `firmware_base` and the region are per-SoC bootloader values, so SM8150's
  are a hypothesis for SC8180X; the PAS-id sweeping ban still stands;
* no help for the cameras — upstream CAMSS has no SM8150 entry either.

Sources: `MiCode/Xiaomi_Kernel_OpenSource` branch `nabu-r-oss`;
`crdroidandroid/android_kernel_xiaomi_sm8150` at `d43213ae`
(`arch/arm64/boot/dts/qcom/sm8150-vidc.dtsi`,
`drivers/media/platform/msm/vidc/venus_boot.c`, `venus_hfi.c`).

### Seventh round: CodeLinaro's `sdmshrike` tree *is* SC8180X

Checked 2026-10-05.  `sdmshrike` is Qualcomm's internal name for **SC8180X**,
this laptop's SoC, so this reference is the same part and not an analogue.
Source: `git.codelinaro.org/clo/la/kernel/msm-4.14`, branch
`auto-kernel.lnx.4.14.c34`, commit `9366ea378de5` (2025-04-10).  It is a 4.14
`msm_vidc` tree, so nothing in it is portable code, but its device tree and
register map are.  Extracts plus a fetch script live in `vendor-ref/`.

#### The video subsystem is two devices, and one of them is TZ's

`sdmshrike-vidc.dtsi` describes `qcom,vidc@aa00000` and nothing else, but
`sdmshrike.dtsi` carries a second node that mainline has no equivalent for:

```
pil_venus: qcom,venus@aae0000 {
	compatible = "qcom,pil-tz-generic";
	reg = <0xaae0000 0x4000>;        /* the wrapper half: 0xE0000..0xE4000 */
	vdd-supply = <&mvsc_gdsc>;
	clocks = <&clock_videocc VIDEO_CC_XO_CLK>,
		 <&clock_videocc VIDEO_CC_MVSC_CORE_CLK>,
		 <&clock_videocc VIDEO_CC_IRIS_AHB_CLK>;
	qcom,core-freq = <200000000>;
	qcom,ahb-freq = <200000000>;
	qcom,pas-id = <9>;
	qcom,firmware-name = "venus";
	memory-region = <&pil_video_mem>;
};
```

All firmware handling belongs to that PAS node: it holds the MVSC GDSC, the
`xo`/`core`/`ahb` clocks, PAS id 9, the firmware region, and the wrapper
window.  The vidc node only ever drives the HFI.

That this is the vendor's own design, not a mainline accommodation, is settled
by `venus_hfi.c`/`venus_boot.c`: the kernel-side bring-up that programs
`WRAPPER_SEC_CPA_START/END` (0x1020/0x1024), `WRAPPER_SEC_FW_START/END`
(0x1028/0x102C) and clears `WRAPPER_A9SS_SW_RESET` (0x3000) runs only when the
vidc node has **both** `qcom,use-non-secure-pil` and `qcom,fw-context-bank`,
and `sdmshrike-vidc.dtsi` has neither.  On this board that path bails out at
`fw_bias == 0` and those registers stay TZ's.  So the `use_tz` rule from round
3 is the intended arrangement, and "stores to the wrapper stall the bus" is the
hardware protecting TZ's block rather than a bug in the sequence.

(One exception worth knowing: `WRAPPER_CPU_CGC_DIS` and
`WRAPPER_CPU_CLOCK_CONFIG` at 0x2010/0x2000 are *not* in that protected set -
the vendor driver writes both, to 0, from `clock_config_on_enable_vpu5` once
the clocks are up.)

#### What it confirms

| Fact | Vendor `sdmshrike` | This tree |
| --- | --- | --- |
| register map | `vidc_hfi_io.h`: VBIF `0x80000`, CPU `0xC0000`, CPU_CS `CPU+0x12000`, WRAPPER `0xE0000` | the round-3 correction, now from a second independent source |
| node window / IRQ | `0xaa00000`, 2 MB, `GIC_SPI 174` | `0xaa00000`, 1 MB (VIDEOCC is reserved), SPI 174 |
| clocks | `gcc_video_axic/axi0/axi1` + `MVSC/MVS0/MVS1_CORE` | identical six, plus `ahb` |
| resets | `GCC_VIDEO_AXIC_CLK_BCR`, `VIDEO_CC_MVSC_CORE_CLK_BCR`, `GCC_VIDEO_AXI0/AXI1_CLK_BCR` | identical four |
| SMMU SIDs | `0x1300/0x60` ns, `0x1301/0x4`, `0x1303/0x20`, `0x1304/0x60` | non-secure `0x1300 0x60` in the node; the rest known from SM8150 |
| VIDEOCC variant | `qcom,videocc-sm8150-v2` -> 240/338/365/444/**533** MHz | the OPP table added in round 1 is exactly that set |
| PAS id | `qcom,pas-id = <9>` in the DT | `IRIS_PAS_ID` is 9 - the assumption was right |
| firmware region | `pil_video_mem`, 5 MB, `no-map` | `video_mem`, 5 MB |
| secure/non-secure VA split | pools `ns 0x25800000+`, `sec_non_pixel 0x1000000+0x24800000` | `tz_cp_config_sm8250` (`cp_size 0x25800000`, `nonpixel 0x1000000+0x24800000`) matches byte for byte |
| HFI generation | `VPU_VERSION_5`, VPU4 vs VPU5 ops split | Gen1 HFI, `iris_vpu2_ops` |
| SCM surface | `PAS_INIT_IMAGE`, `PAS_MEM_SETUP`, `PAS_AUTH_AND_RESET`; regulators and clocks enabled immediately before the auth | `qcom_mdt_load` + `pas_auth_and_reset`, same three calls |

The SCM-surface row answers round 4/5's open question in the negative, and it
agrees with round 6: **there is no share/unlock/XPU call anywhere in the video
path**.  The vendor's own PAS implementation
(`drivers/soc/qcom/subsys-pil-tz.c`) is the plain three-call sequence.  The
"request to share / unlock subsystem memory" strings in `qcpil8180.sys` are a
Windows hypervisor/TREE artefact, as suspected.

#### What it changes

1. **The wrapper interrupt bits are the V6 ones, and the boot-time mask is the
   vpu4 one.**  This is one conflation in three places:
   * `WRAPPER_INTR_MASK_A2HWD_BMSK` (and `WRAPPER_INTR_STATUS_A2HWD_BMSK`) are
     `BIT(3)` in this tree - upstream `iris`'s *V6* watchdog bit.  Downstream
     and upstream `venus` put the watchdog at `0x10`/`BIT(4)` and use
     `0x8`/`BIT(3)` for **A2HVCODEC**, which is what the Venus-4xx map has and
     V6 reuses for the watchdog.  So the IRQ handler's watchdog test is looking
     at the VCODEC bit as well;
   * consequently `iris_vpu_interrupt_init()`'s read-modify-write computes
     `0x1f2` (it clears `0x8|0x4` from the `0x1f6` reset value) - which is
     exactly the "Venus-6xx mask" the source comment rejects;
   * `iris_vpu_boot_firmware()` then writes `0x8`, which is upstream `venus`'s
     AR50 path (`IS_IRIS2() || IS_IRIS2_1()` else-branch) and downstream's
     `interrupt_init_vpu4()` - the SDM845-class value, not this SoC's.

   The vendor's **vpu5** path - and sdmshrike is `vpu_ver = VPU_VERSION_5` -
   only clears CPU and watchdog from the `0x1f6` reset value, i.e. it leaves
   **`0x1e2`**, and it does so once, never narrowing afterwards.  The current
   value masks the VCODEC source the vendor unmasks and unmasks bits 1 and 5..8
   that the vendor leaves masked.
2. **The VPU is booted at the top OPP, the vendor boots it at 200 MHz.**
   `iris_vpu_power_on()` calls `dev_pm_opp_set_rate(dev, ULONG_MAX)` when no
   instance has asked for a rate yet, which selects 533 MHz.  The PAS node
   asks for `qcom,core-freq = <200000000>` and `qcom,ahb-freq = <200000000>`,
   i.e. the firmware handshake runs at the lowest rate in the table.  Worth
   matching while the handshake is being debugged.
3. **Three register blocks the tree does not have yet**, all inside the 1 MB
   window, all useful for the "silent reset" that round 5 ends on:
   * `VCODEC_CORE0_VIDEO_NOC_BASE_OFFS = 0x4000` and
     `CVP_NOC_BASE_OFFS = 0xC000`, with `ERRVLD` at `+0x510` and `ERRCLR` at
     `+0x518` - a NoC error from the VPU is exactly the event round 5
     diagnosed, and this is the register pair that would confirm it (clear
     before a retry, read after);
   * the VBIF AXI-halt handshake, `VBIF 0x80000`: `VENUS_VBIF_AXI_HALT_CTRL0`
     `0x80208` / `_CTRL1` `0x8020C`, `HALT_REQ`/`HALT_ACK`, 500 ms timeout,
     plus `VIDC_VENUS_VBIF_CLK_ON` at `0x80004`;
   * `WRAPPER_HW_VERSION` at wrapper `+0x00`, decoded as major `31:28`,
     minor `23:16`, step `15:0`.  Reading `0xaae0000` would settle round 2's
     naming caveat (`VIDEO.IR.1.2` versus the binding's "Iris v2.xx") from the
     hardware instead of by inference - the low wrapper window reads safely,
     as `WRAPPER_INTR_MASK` already proved.
4. **The firmware region address is a difference to record, not to fix.**  The
   vendor pins video at `0x96e00000` (5 MB, directly above the 150 MB modem
   region).  This tree instead uses `0x8bd80000`, the base of the Windows
   "PGCM" pool, and TZ accepts it (`PAS_MEM_SETUP` and `PAS_AUTH_AND_RESET`
   both return 0 there), so there is no reason to move it.

#### What it does not give

Nothing here explains the silent reset at the end of round 5, and nothing here
is a Linux-side substitute for the secure-world steps - the vendor reaches TZ
through the same three SCM calls mainline does.  The remaining candidates are
unchanged: a NoC/XPU-class event below Linux, or a firmware/core mismatch that
the interrupt mask and boot rate above might themselves be provoking.

#### Ordered next attempt

1. `iris_vpu_common.c`: move the two `A2HWD` bits from `BIT(3)` to `BIT(4)`,
   drop the `writel(0x8, WRAPPER_INTR_MASK)` in `boot_firmware()` and let the
   read-modify-write in `iris_vpu_interrupt_init()` stand (it then yields
   `0x1e2`);
2. `iris_vpu_power_on()`: use the table minimum (or an explicit 200 MHz)
   instead of `ULONG_MAX` for the power-on rate, and set the `ahb` clock to the
   same rate before enabling it;
3. before enabling `&venus`, add a one-shot read of `0xaa04510` (NoC `ERRVLD`)
   and `0xaae0000` (`WRAPPER_HW_VERSION`) to the existing trace breadcrumbs, so
   the first attempt after these changes reports both;
4. only then rebuild the probe DTB and take a boot, with the round-5 capture
   recipe armed (`panic_on_rcu_stall=1`, `kernel.panic=20`, ramoops).

#### Applied 2026-10-05

Points 1-3 are in the kernel tree (`src/kernel`, branch
`xiaomi-mainline-panel2`, not yet committed):

* `iris_vpu_common.c`: `WRAPPER_INTR_STATUS_A2HWD_BMSK` and
  `WRAPPER_INTR_MASK_A2HWD_BMSK` are `BIT(4)` now, and
  `iris_vpu_boot_firmware()` no longer writes `0x8` over the mask - the
  read-modify-write in `iris_vpu_interrupt_init()` stands.  The value to look
  for in the trace is **`intr_mask=0x1e2`**.
* `iris_vpu_common.c`: `iris_vpu_power_on()` uses `IRIS_BOOT_FREQ`
  (200 MHz, the vendor's `qcom,core-freq`) instead of `ULONG_MAX` when no
  instance has voted yet.  Measured on hardware this gives
  **`IRIS_HW_CLK = 200000097 Hz`**, not the 240 MHz that was predicted here at
  first: `_opp_config_clk_single()` programs the *rounded* target frequency for
  the rate and uses the next OPP up (240 MHz, the table's lowest) only for its
  `required-opps` voltage corner.
  The separate `clk_set_rate()` on the `ahb` clock that point 2 asked for was
  dropped: MVSC, MVS0 and AHB are three branches off the *same*
  `video_cc_iris_clk_src`, so the one OPP `set_rate` already moves all three and
  a second one would only add a transient flip-flop.
* `iris_vpu_common.c` + `iris_vpu_register_defines.h`:
  `iris_vpu_trace_probe_registers()` reads `WRAPPER_HW_VERSION` (wrapper + 0x00)
  and the VCODEC core0 NoC `ERRVLD` (vidc + 0x4510) at the top of
  `iris_vpu_boot_firmware()`, and the two `ERRLOG0` words only if `ERRVLD` is
  set - one new register access in the expected case, on a block this board has
  not been talked to before.  It prints
  `IRIS-TRACE: probe: hw_version=... (major N minor N step ...) intr_mask=...
  noc_errvld=...`.
* to read the rate back, `iris_get_clk_by_type()` had to stop being static
  (`iris_resources.c`, `iris_resources.h`), plus `#include <linux/clk.h>` in
  `iris_vpu_common.c`.

The first boot after this has to answer three things, all of them in the trace
before the point where the machine used to reset:

1. `intr_mask=0x1e2` (the vendor's vpu5 value) rather than `0x1f2`/`0x8`;
2. `IRIS_HW_CLK = 200000097` (~200 MHz) rather than 533000000;
3. `hw_version=` - whether the core really is the "Iris v2.xx" of the sm8250
   binding or an older revision, which is what round 2 left unresolved; and
   `noc_errvld=0`, or a non-zero value with an `errlog0` to decode.

Built and packaged as `linux-mibook-6.18.2-1-11-aarch64.pkg.tar.zst`
(2557 modules, 0 missing, no compile errors).  Checked inside the package
before handing it over: the iris module carries the new trace strings and no
longer contains the `intr mask 0x8` write, the plain and `-oc` DTBs have the
video node `disabled`, and `-vdec-probe.dtb` has it `okay` together with
`firmware-name = "qcom/sc8180x/venus.mbn"`.

##### The `no_auth=1` run (pre-auth half, 2026-10-05)

`sudo modprobe qcom-iris no_auth=1` on the `-11` build, with the probe DTB
active.  It answered two of the three questions and, more usefully, drew a
clean line around what is *not* dangerous:

    enable clock 2 (video_cc_iris_ahb_clk)      ret=0   <- round 4's blocker
    enable clock 1 (gcc_video_axic_clk)         ret=0
    enable clock 0/5/3/4  (axi0, axi1, mvsc, mvs0)      <- all six clocks up
    opp set_rate(200000000)
    opp done, IRIS_HW_CLK = 200000097 Hz
    WRAPPER_INTR_MASK (+0xe0010) = 0x1f6 (expect 0x1f6)
    set remote state ret=-22
    fw region phys=0x8bd80000 size=5242880
    qcom_mdt_load ret=0

So: the whole pre-auth path - power domains, all six clocks including the AHB
one, the OPP at ~200 MHz, the wrapper register read, the SCM remote-state
call, `qcom_mdt_load` and the image authentication - runs without a bus stall
and the failure path is survivable.  It ran **three times in one modprobe**
(15 s apart, the debug window below); that repetition is
`iris_sys_error_handler()` in `iris_probe.c` re-running `iris_core_deinit()` +
`iris_core_init()`, not the operator.

Two things it could **not** answer, by construction:

* `iris_firmware.c:161-168` returns `-EIO` from `iris_fw_load()` in the
  `no_auth` branch (after a `msleep(15000)` "window" meant for
  `videocc-peek.py`), so `iris_vpu_boot_firmware()` never runs - and that is
  where the `probe:` line lives.  `hw_version` and `noc_errvld` therefore need
  the real run;
* because `core_init` jumped to `error_power_off` and not `error_unload_fw`,
  `iris_fw_unload()` (and with it `qcom_scm_pas_shutdown`) never ran: the PAS
  is left with the image authenticated and the core still held.  Reboot before
  the real probe rather than stacking a fourth `init_image` onto that state.

##### The real run (2026-10-05): CTRL_INIT is acknowledged, and the wall moves

`sudo modprobe qcom-iris` on the `-11` build with the probe DTB active.  This is
the first attempt that got past the point where round 5 lost the machine:

    PAS auth and reset (SCM call)
    PAS auth ret=0                       <- TZ released the core
    mem protect video var (SCM call)
    core_init: boot firmware
    boot_fw: probe registers
    probe: hw_version=0x5010002f (major 5 minor 16 step 0x2f) intr_mask=0x1e2 noc_errvld=0x0
    boot_fw: ucregion map
    boot_fw: CTRL_INIT write
    boot_fw: ctrl_status=0x1 count=77    <- the firmware answered
    core_init: hfi core init
    core_init: waiting for sys response
    <machine dies>

Three answers, all of them the ones the fixes were aimed at:

* **`intr_mask=0x1e2`** - the vendor's vpu5 value, on hardware, at last.  The
  `BIT(4)` A2HWD correction and dropping the `writel(0x8)` did what they were
  supposed to;
* **`IRIS_HW_CLK = 200000097 Hz`** - the bottom of the table instead of 533 MHz;
* **`hw_version=0x5010002f`** - decoded with the vendor/mainline masks that is
  major `5`, minor `0x10`, step `0x2f`.  It does not by itself settle round 2's
  "Iris v2.xx" naming caveat (there is no SM8250 value to compare against), but
  it is now on record as the number this part reports.

And `noc_errvld=0x0` at that point: no NoC error had been logged yet.

**The wall moved from "the first register write after power-on" to "the
firmware is running and has been sent SYS_INIT".**  `iris_vpu_boot_firmware()`
returned success (`ctrl_status=0x1`, count 77 of 1000, no error bits), the HFI
queues were programmed, `iris_hfi_core_init()` queued SYS_INIT and got as far as
`iris_wait_for_system_response()` - and the machine died inside that window.
How it died is still unknown, and that is the gap to close.

**The capture gap.**  journald has *none* of this run: of the last four boots
only the `no_auth` one contains `IRIS-TRACE` lines at all, and the boot that
died is the only one that ended without a `systemd-shutdown` line.  The trace
survives only because the operator ran `dmesg -w` into a file, and that file may
itself be missing its tail (the register-dump line came out, the death did not).
So "hard stall (screen frozen, power-cycle needed)" and "reset from below Linux"
are still not distinguished - and if it was a reset, any `arm-smmu` "Unhandled
context fault" line went with it.  Round 5 taught the same lesson; what changed
is that the interesting lines now print *before* the fatal point.

**Two divergences from the vendor's own sdmshrike driver** came out of
comparing the boot path, and both are worth eliminating on their own merits:

| | vendor `sdmshrike` (`msm-4.14`) | this tree (`-11`) |
| --- | --- | --- |
| UC region | `SHARED_QSIZE = ALIGN(SFR + QUEUE + QDSS, SZ_1M)`, and the queue block is sized to fill it up to the SFR/QDSS blocks, so the whole advertised region is mapped | `UC_REGION_SIZE = ALIGN(SFR_SIZE + queue_size, SZ_1M)` while only `queue_size` was allocated there - ~0.5 MB of the advertised region was unmapped IOVA, and the SFR sat in a separate allocation |
| `VIDC_VERSION_INFO` | never written (mainline `venus` writes 1 only for `IS_V1()`) | `writel(0x1, CPU_CS_SCIACMDARG3)` before `CTRL_INIT`, i.e. HFI 1.x advertised to a firmware fed HFI-4xx packets |

`-12` fixes both (one 1 MB-aligned allocation, SFR at the end of it; the
version-register write dropped) and replaces the sleeping wait with a polling
one that prints every change of `WRAPPER_INTR_STATUS`, `CTRL_STATUS`, the NoC
`ERRVLD` bit and the message queue's write index, plus the total on response or
timeout.  The UC region line (`IRIS-TRACE: ucregion: qtable=... size=... sfr=...`)
also goes into the log, so the next run shows exactly what the firmware was
told.

What the next run has to answer, in order:

1. does the firmware write anything into the message queue (`msgq_write_idx`)
   before the machine goes - and does `noc_errvld` ever set?
2. if it gets as far as a response, does `/dev/video0` appear;
3. if it dies the same way, whether it was a stall (a rebuild with
   `panic_on_rcu_stall` / `hung_task_panic` armed would leave a ramoops record)
   or a reset below Linux (which would not).

###### The run that was not the new build (and the tooling bug behind it)

The second probe run on 2026-10-05 reproduced the first one exactly -
`ctrl_status=0x1`, `count=75` instead of 77, and the same death right after
`waiting for sys response` - *including* the absence of every new `-12` line
(`IRIS-TRACE: ucregion: ...`, `IRIS-TRACE: wait t=...`).  It was running the
`-11` module: the `sha256` of the installed
`/usr/lib/modules/6.18.2-1-mibook+/.../qcom-iris.ko` equals the copy inside
`linux-mibook-6.18.2-1-11-aarch64.pkg.tar.zst`, and `pacman.log`'s last
linux-mibook transaction is the `-11` install at 15:35:55.

The cause was in `tools/probe-vdec-run.sh`, not in the hardware.  Its "already
this build" gate compared `/boot/vmlinuz-linux-mibook` against the tree's
`Image` and checked that the installed module files are root-owned - and a
**module-only rebuild leaves the kernel image byte-identical**, so the gate said
"already this build ... skipping the package install" and `pacman -U` never ran.
The script then re-copied the probe DTB and its own verification passed (it too
only looked at the kernel, the DTBs, the blacklist and file ownership), so it
reported success.  A change to `iris_hfi_queue.c`/`iris_vpu_common.c` is exactly
that case.

Both places now compare the installed module **byte for byte with the copy
inside the package** (`bsdtar -xOf "$PKG" <member> | sha256sum`), which is the
practical form of round 5's "check the build timestamp *and* a unique string
from the new build".  mtimes are unusable here because the packaged copy is
stripped, the bytes are not.

Useful by-product: the `-11` failure is *reproducible* - same `ctrl_status`, same
point, twice - so it is a stable fault, not a race.

###### The `-12` run: the hang is on the first firmware interrupt

`-12` really ran this time (the `ucregion:` and `wait` lines are there).  The
tail of the trace:

    probe: hw_version=0x5010002f (major 5 minor 16 step 0x2f) intr_mask=0x1e2 noc_errvld=0x0
    boot_fw: ucregion map
    ucregion: qtable=0xdfc00000 size=0x400000 sfr=0xdffff000
    boot_fw: CTRL_INIT write
    boot_fw: ctrl_status=0x1 count=79
    core_init: hfi core init
    core_init: waiting for sys response
    wait t=0ms intr_status=0x6 ctrl_status=0x1 noc_errvld=0x0 msgq_write_idx=0
    <hang, then the hardware watchdog resets the board>

That `ucregion:` line is what `-12` was for: one allocation at
`0xdfc00000`, 4 MB, SFR at its end (`0xdffff000` = base + size - 4K), and the
address is inside the iris device's DMA domain (the region ends exactly at the
`0xe0000000` DMA mask), so the SMMU is attached and translating.  CTRL_INIT was
acknowledged again.

**The step forward is `intr_status=0x6` and what follows it.**  0x6 is A2H
(`BIT(2)`, the firmware saying it has something for the host) plus `BIT(1)`, a
source the vendor leaves masked.  The firmware therefore *did* raise the
interrupt this time - and `msgq_write_idx=0` says it had not yet put anything in
the message queue when the wait began.

Then: nothing.  No further poll print, no `wait: no response in 1000 ms`, no
`core init failed`.  The machine hung and the **hardware watchdog**
(`qcom,wdt`, bark-time 11 s) reset it - it was *not* a software panic: ramoops
reports all four record slots as `uncorrectable error in header`, i.e. empty, on
the next boot.  So the death is now localised to **the driver's first pass
through the firmware-interrupt path**.

Two ends are possible, and both are new code that has never completed before:

* `iris_vpu_clear_interrupt()` writes `CPU_CS_A2HSOFTINTCLR` and
  `WRAPPER_INTR_CLEAR`.  Neither register has ever been written by this driver
  (every previous run died earlier), and the wrapper's *upper* window was
  already shown to stall the bus when touched (round 4);
* an interrupt storm.  The A2H line is level-based on the message queue having
  data, so if `hfi_response_handler()` never drains the queue - wrong HFI
  version, a packet it does not understand, or an `iris_hfi_queue_read()` that
  consumes nothing - the handler re-enters forever and the board hangs exactly
  like this.  It is also what the two references do *not* have in common with
  this driver: mainline venus and the vendor both clear and drain in one pass,
  and both run their message pump to completion.

`-13` instruments precisely that path: capped breadcrumbs
(`intr_status`, `intr_mask`, `ctrl_status`, `noc_errvld`, message queue read and
write index) at handler entry, after the clear and after the response handler,
plus a **storm guard** that stops re-enabling the IRQ once 100 interrupts have
arrived with less than 50 ms between them.  If it is a storm the machine should
now survive it, the 1 s wait should time out, and the log should show the burst
and the queue indices that explain why nothing was drained.

###### The actual bug: the H2X doorbell went to the Venus-6xx address

The `-13` run came back with the answer, and it is not a storm.  The whole
interrupt path completed, once, cleanly:

    isr[0 entry]:   intr_status=0x6 intr_mask=0x1e2 ctrl_status=0x1 noc_errvld=0x0 msgq_r=0 msgq_w=0
    wait t=0ms intr_status=0x6 ...
    wait t=0ms intr_status=0x2 ...          <- A2H cleared by the driver
    isr[1 cleared]: intr_status=0x2 ...     <- so the clear works
    isr[2 done]:    intr_status=0x2 ...     <- response handler returned
    <hang, hardware watchdog reset>

One interrupt, handled end to end, with the message queue untouched
(`msgq_w=0`).  So neither the clear path nor the response handler is the
problem, and the firmware never wrote a byte to the host.

That pointed at the *other* direction - the host-to-firmware doorbell - and
there the register map is wrong:

| | mainline `venus` | vendor `sdmshrike` | this tree |
| --- | --- | --- | --- |
| CPU interrupt controller | `CPU_IC_BASE = CPU_BASE + 0x1f000` | `VIDC_CPU_IC_BASE_OFFS = CPU_BASE + 0x1F000` | `CPU_IC_BASE_OFFS = CPU_BASE` (!) |
| doorbell register | `CPU_IC_SOFTINT = 0x18` | `VIDC_CPU_IC_SOFTINT = +0x18` | `+ 0x150` (!) |
| H2X bit | `CPU_IC_SOFTINT_H2A_SHIFT = 0xf` -> `BIT(15)` | `VIDC_CPU_IC_SOFTINT_H2A_SHFT = 0xF` -> `1 << 15` | shift `0x0` -> `1` (!) |

`venus_soft_int()` picks the `_V6` values only `if (IS_V6() || (IS_V4() &&
is_lite()))`; this SoC is neither, so it takes `BIT(0xf)` at `CPU_IC + 0x18`.
The vendor's `__iface_cmdq_write()` does exactly the same.  All three of the
columns on the right are the *V6* values, which is what upstream `iris` uses for
SM8550/SM8650 - and the round-3 register-map correction repointed `CPU_BASE`,
`CPU_CS_BASE` and `WRAPPER_BASE` for the 4xx map but not these, because they
were written as `CPU_BASE_OFFS` plus a *delta* and so silently followed
`CPU_BASE` to `0xC0000` while keeping the V6 offsets.

`iris_vpu_raise_interrupt()` was therefore writing **`1` to `0xC0150`** where it
had to write **`0x8000` to `0xDF018`**.  Every HFI command this driver ever
queued was written into the command queue and then never announced: the
firmware had no reason to look at the queue, which is exactly what the traces
show (`msgq_write_idx = 0` in every run, no SYS_INIT response ever), and why the
1 s wait could never succeed.  The stray write into the middle of the CPU block
is also the best candidate for the hang that follows it - that address is not a
register this driver has any business writing.

`-14` fixes the three values and extends the traces to print all three queues'
read/write indices, so the next run can be read directly: `cmdq_r` should reach
**3** as the firmware consumes `sys_init`, `image_version` and
`interframe_powercollapse`, `msgq_w` should become non-zero when the SYS_INIT
done response lands, and the wait should then report
`wait: response after N ms` instead of hanging.

This is a genuine bug in the `iris` driver for any Venus-4xx core, not a
board-specific hack - worth keeping for an eventual upstream submission.

###### The `-14` run: the failure point moves with the core, not with our registers

With the doorbell fixed, `-14` got *less* far than `-13`: its log ends on
`boot_fw: CTRL_INIT write` with no `ctrl_status=...` line after it at all, where
`-13` had printed `ctrl_status=0x1 count=77` 8 ms later.

That is the point.  Lining the runs up:

| run | last thing the driver managed | ~time after `PAS auth ret=0` |
| --- | --- | --- |
| `-11` (twice) | `waiting for sys response` | ~9 ms |
| `-12` | first `wait` poll (`intr_status=0x6`) | ~9 ms |
| `-13` | a complete interrupt round trip (`entry`/`cleared`/`done`) | ~9 ms |
| `-14` | the `CTRL_INIT` write itself | ~0.02 ms |

Nothing in common in the *driver's* actions - the common factor is that TZ has
just released the core and the machine wedges within a few milliseconds.  And
the `no_auth=1` run is the control: with the core **not** released the driver
took the whole pre-auth path three times in a row and the machine was fine.

So the working hypothesis is now that **what takes the bus down is the firmware
starting to execute** - its first memory accesses (through the SMMU, and with
the four secure context banks that only TZ knows about) - and not any particular
register this driver touches.  If that is right, no amount of driver-side
register fixing will get past it.

`-15` bisects exactly that with a new `hold_after_auth_ms` parameter: after
`qcom_scm_pas_auth_and_reset()` returns, the driver touches no VPU register for
half the interval, then takes one snapshot, then waits out the other half.

* nothing after `hold: N ms with no VPU register access at all` -> the core's
  own execution wedges the bus; look at the firmware image, the SMMU streams
  and the secure context banks, not the driver;
* `hold 1/2 survived` and then nothing -> the first register access after the
  release is what trips it;
* both holds and then the usual death -> it is later than the release, i.e. the
  `CTRL_INIT` path again.

Caveat on `-14`: if that capture was a plain `dmesg -w > file` rather than
`stdbuf -oL ... | tee`, its last few KB may simply be missing and "before the
acknowledgement" is provisional.  The next run should use the unbuffered form.

###### The `-15` bisect: the released core is harmless until CTRL_INIT

    PAS auth ret=0
    hold: 6000 ms with no VPU register access at all
    hold 1/2 survived, first register snapshot now          (+3025 ms)
    isr[0 hold-read]: intr_status=0x0 intr_mask=0x1e2 ctrl_status=0x0
                      noc_errvld=0x0 cmdq_rw=0/0 msgq_rw=0/0 dbgq_rw=0/0
    hold 2/2 survived, continuing                           (+3009 ms)
    mem protect video var (SCM call)
    ... CTRL_INIT -> ctrl_status=0x1 count=66 -> wait -> intr_status=0x6 -> death

So the `-14` reading was wrong: **the released core sat there for six seconds
with no VPU register access at all and the machine was completely fine** - the
snapshot even read back cleanly (`intr_status=0x0`, `ctrl_status=0x0`, every
queue empty).  The firmware is not doing anything harmful by itself; before
CTRL_INIT it is idle and waiting for the host.

What the failure needs is CTRL_INIT.  The acknowledgement comes back
(`ctrl_status=0x1 count=66`), A2H goes up (`intr_status=0x6`, i.e. the firmware
signalling plus the masked `BIT(1)`), every queue is still `0/0`, and the
machine goes - and this time not even the `isr[... entry]` breadcrumb printed,
where `-13` had run a whole interrupt round trip.  The death races the first
thing the firmware does after being kicked.

A2H raised with **all three queues untouched** is the one clue left on the
table, and it is precisely what the SFR exists for: the subsystem failure
reason buffer is where this firmware writes why it gave up.  The driver has
never read it - `-16` does (size, bytes written, and the first 96 bytes as
text) after CTRL_INIT is acknowledged, on every change in the wait loop and in
the interrupt snapshot.  Because the SFR is plain DDR at the end of the UC
region, reading it costs *no* VPU register access, so it is safe in exactly the
state the machine dies in.

`-16` also adds `hold_after_ctrl_init_ms`, which waits between CTRL_INIT being
acknowledged and the first HFI command - to separate "CTRL_INIT, i.e. the
firmware's own post-init work, is enough to kill it" from "our H2X doorbell is
what it reacts to".

###### The `-16` run: the window is ~10 ms after the CTRL_INIT write

`-16` (with `hold_after_ctrl_init_ms=6000`, i.e. no `hold_after_auth_ms`) ended
on `boot_fw: CTRL_INIT write` again - no `ctrl_status` line, and of course no
`sfr[post-ctrl-init]`, which sits after the poll loop.  Same shape as `-14`.

Lining the six runs up once more, the acknowledgement itself takes 8-10 ms
(`count=77`/`79`/`66` polls at ~110 us), and the death lands somewhere inside
that window:

| | CTRL_INIT write | ack printed | then |
| --- | --- | --- | --- |
| `-11`, `-12` | yes | yes | dead at `waiting for sys response` |
| `-13` | yes | yes | one full interrupt round trip, then dead |
| `-15` | yes | yes | A2H, then dead |
| `-14`, `-16` | yes | **no** | dead inside the poll |

Two conclusions follow, and they change what the next experiment has to be:

1. writing CTRL_INIT starts something in the firmware that takes the VPU's bus
   away about 10 ms later - it is not our command queue, not the doorbell
   (`-14`/`-16` never got that far) and not the interrupt path;
2. in `-14`/`-16` the log stops with no output for the whole remaining window,
   which is exactly the shape of **a CPU stuck inside `readl(CTRL_STATUS)`** -
   and a CPU stuck in an MMIO read is also what turns "the VPU is gone" into "the
   machine is frozen, then the hardware watchdog resets it".  Our own polling is
   therefore part of the blast radius, independently of why the bus goes.

`-17` acts on that with `quiet_after_ctrl_init_ms`: after the CTRL_INIT write it
reads **no VPU register at all**, sleeps, reads only the SFR (plain DDR, still
reachable with the VPU bus gone) and fails the probe cleanly.  Three outcomes,
all of them informative:

* machine survives, `sfr[quiet]: written=0` -> the firmware has nothing to
  report, and since nothing of ours touched the bus, the wedge was not caused by
  a register access we made;
* machine survives, `sfr[quiet] text='...'` -> **the firmware's own reason for
  stopping**, printed even though its bus is dead.  That is the answer this whole
  sequence has been looking for;
* the machine still dies during the quiet sleep -> the firmware wedges the bus by
  itself, with no host register access involved at all.

###### The `-17` run: it is the third case

    boot_fw: CTRL_INIT write
    quiet: 6000 ms after the CTRL_INIT write, no register access
    <dead>

No `sfr[quiet]`, no `quiet: done`: the machine went down inside the 6 s sleep,
with the driver touching **no VPU register at all** after the CTRL_INIT write,
and before even the DDR-only SFR read.

Put together with `-15` (six seconds completely stable with the core released
and no CTRL_INIT), the picture is now unambiguous:

* the released core is harmless while it waits for CTRL_INIT;
* CTRL_INIT starts something in the firmware, and about 10 ms later the VPU's
  bus is gone;
* nothing the host does after that write is involved - not the `CTRL_STATUS`
  poll (the `-16` hypothesis, dead), not the H2X doorbell, not the interrupt
  path.

So the remaining question is not "what does the driver do wrong" but "what does
the firmware need that is not there".  Two candidates, and the firmware image is
*not* one of them:

**The image is fine.**  `qcom_scm_pas_init_image` authenticates it, TZ releases
the core with it, and the core executes it far enough to answer the CTRL_INIT
handshake - a wrong or reshaped image cannot do that (round 3 showed TZ
authenticates the ELF header and program-header table too).  The copy installed
(`md5 d99528d5010d9e8ed71c4276ddc0bb1c`, `VIDEO.IR.1.2-00079-PROD-2`) is
byte-identical to the one Windows itself loads
(`/Windows/System32/qcvss8180.mbn` and the 2025 DriverStore package), so
re-extracting it from the Windows partition would produce the same bytes.  The
only other build on that machine is the 2022 driver's
`6909a826800cf68d4bc82e05c10bc132` (`VIDEO.IR.1.2-00042-PROD-1`), an older build
of the same IR.1.2 generation - worth remembering as an A/B, not worth trying
first.

**The environment is the suspect**, and the one unresolved item there is round
4's blocker #2: `VIDEO_CC_IRIS_AHB_CLK` (VIDEOCC `0x8f4`) "cannot be enabled",
while the vendor's own `pil_venus` node lists exactly that clock as required
(`clocks = <xo>, <mvsc_core>, <iris_ahb>`) - it is the VPU's register/AHB
interface clock.  Right next to it is `VIDEO_CC_INTERFACE_BCR` (`0x8f0`), the
**AHB2AXI bridge reset**, which mainline's `videocc-sm8150` does not expose as a
reset at all: its binding has exactly one (`VIDEO_CC_MVSC_CORE_CLK_BCR`).  A
bridge held in reset is precisely the kind of thing that makes traffic through
it stop answering - which is the shape of every failure in this section.

`debug/videocc-peek.py dump` answers both with no rebuild and without going near
the VPU (VIDEOCC/GCC only), and the `no_auth=1` window is the state in which the
machine is provably stable, so it can be run safely:

    sudo modprobe qcom-iris no_auth=1 &
    sleep 1
    sudo python3 debug/videocc-peek.py dump | tee ~/videocc.txt

What it should say: `videocc +0x08f4 ... branch_enable(bit0)=1 clk_off(bit1)=0`;
`videocc +0x08f0 ... reset deasserted (bit0=0)`;
`videocc +0x0814`/`+0x0874 ... PWR_ON(bit31)=1 (POWERED)`; and the RCG/branches
at `0x7f0`, `0x850`, `0x890` enabled.

###### First look at VIDEOCC (idle state, 2026-10-05)

The first `dump` came ~17 s after the last `no_auth` window's teardown (this
boot ran three of them, `core_init: vpu power_on` at 251/266/282 s, each 15.5 s
apart), so it shows the *idle* state - which is exactly why `0x8f4` reads 0:
the driver clears that branch when it powers the VPU down.  It does settle
things, though:

* `0x8f0 VIDEO_CC_INTERFACE_BCR` = 0 -> the AHB2AXI bridge is **not** held in
  reset.  That suspected cause is out;
* `VCODEC0_GDSC` (0x874) = `0x00282002`: SW_COLLAPSE=0 (armed) with PWR_ON=0
  (not powered), and `mvs0_core_clk` (0x890) enabled but `CLK_OFF` (bit 31).
  This is **expected**, not a fault: mainline defines `vcodec0_gdsc` with
  `HW_CTRL_TRIGGER`, so Linux only *arms* it and the **hardware** - the VPU's
  own power sequencer, driven by the firmware - powers it up on demand.
  `PWR_ON=0` before the firmware asks for it means nothing; it is that request,
  made right after CTRL_INIT, that pulls the domain up - and it goes through the
  VPU's register/AHB interface;
* `VENUS_GDSC` PWR_ON=1 and `mvsc_core_clk` still enabled after the teardown:
  the MVSC domain is left powered.  Worth cleaning up, not obviously harmful.

The reading that matters - `0x8f4` **while the driver has the VPU powered** - can
only come from a dump taken inside the `no_auth` window.

###### The live in-window dump: everything up except the AHB branch

Taken inside a real `no_auth` window (the log confirms `WINDOW OPEN 15 s`
immediately before it).  Everything the driver asks for is up:

| register | value | meaning |
| --- | --- | --- |
| `0x0814` VENUS_GDSC | `0xf8282000` | powered |
| `0x07f4` CFG_RCGR | `0x00000103` | the iris RCG is configured and running |
| `0x0850` mvsc_core | `0x00000221` | bit 0 = 1, bit 31 = 0: enabled and running |
| `0x0890` mvs0_core | `0x80000221` | enabled; output halted because vcodec0 is not powered yet (expected - `HW_CTRL_TRIGGER`) |
| `0xb024` gcc axi0 | `0x00004221` | enabled and running |
| `0x08f0` INTERFACE_BCR | `0x00000000` | bridge not held in reset |
| **`0x08f4` iris_ahb_clk** | **`0x00000000`** | **bit 0 = 0: not enabled** |

The dump carries its own control: `0x850 mvsc_core` lives in the *same* BRIC
page, is declared the *same* way (`BRANCH_VOTED`, `enable_mask = BIT(0)`,
`clk_branch2_ops`) and was enabled by the *same* driver run - and its bit 0 *is*
set.  So bit 0 can stick for a voted branch in this block, and the AHB branch is
the one that refuses.  A raw write of bit 0 from `videocc-peek.py` does not
change it either.

That matters because `0x8f4` is the AHB2AXI bridge clock - the VPU's *outbound*
path for its own masters (its route to the SMMU and DDR).  With that bridge
unclocked the firmware can still run its CPU (which is why it answers CTRL_INIT)
but its first outbound access can never complete, which is exactly the "the
machine dies ~10 ms after CTRL_INIT with no host register access" that `-17`
proved - and it is also the first explanation that fits the two things that have
been odd all along: **`msgq_write_idx` never moved and the SFR was never
written**, i.e. the firmware cannot reach DDR at all.

The `ahb-probe` run settled the first half and then undid the conclusion.  Its
control was written badly the first time (it wrote back the value already in
VENUS_GDSC, where bit 0 was already 0, so "write landed" proved nothing); fixed
to toggle `VCODEC1_GDSC` bit 0 for real, the control did land - `0x8b4` went
`0x00282001 -> 0xf8282000`, i.e. the write not only stuck but **powered the
vcodec1 domain up** - and `0x8f4` still refused every value it was given,
including the reserved bit 16.  Same 4 KB page, same mapping, same run, one
register accepts writes and the other does not.

**But that does not mean the AHB clock is off.**  This boot has no
`status stuck at 'off'` warning anywhere (the only clock WARN is `sdhci_msm_probe`
on the SD controller's RCG), and mainline's `clk_branch_wait()` raises exactly
that WARN and returns `-EBUSY` whenever `CBCR_CLK_OFF` (bit 31) is set.  So when
the driver enabled `video_cc_iris_ahb_clk` and got 0 back, bit 31 was clear -
and "bit 31 clear" is the driver's own definition of *the branch is running*.
The live dump agrees: `0x8f4 = 0x00000000`.

Retraction, then: reading "bit 0 = 0" as "the bridge has no clock" was an
over-reading.  The consistent picture is a hardware-gated/voted branch whose
software enable bit is inert - the driver's halt check looks at bit 31, the
hardware says it is not off, and the driver is satisfied - so **the AHB branch is
a red herring**, not the cause of the failure.

###### The ACPI `PAGETABLES` manifest: the video banks are split by address

`~/acpi-dumps/dsdt.dsl`'s `GPU0` "PAGETABLES" package (13 entries) gives each of
the video's SMMU banks an **IOVA window**.  The field order is pinned down by the
graphics and crypto entries in the same package (`GraphicsGlobalPT` is a 64-bit
512 GB range, `GraphicsPerProcessPT` starts at 4 MB, and each non-secure window
ends where its secure one begins); field 3 is the secure flag and the video
entries' last field is the bank index:

| entry | secure | IOVA window |
| --- | --- | --- |
| `VideoNonSecurePT` | no | `0x00100000` + `0xBFF00000` -> `0x00100000..0xBFFFFFFF` |
| `VideoSecurePT1` | yes | `0xC0000000` + `0x10000000` |
| `VideoSecurePT2` | yes | `0xD0000000` + `0x10000000` |
| `VideoSecurePT3` | yes | `0xE0000000` + `0x10000000` |
| `VideoSecurePT4` | yes | `0xF0000000` + `0x10000000` |

The same manifest settles a question the platform data raised: `iris`'s
`tz_cp_config_sm8250` (`cp 0..0x25800000`, `cp_nonpixel 0x01000000..0x25800000`)
and its `dma_mask = 0xe0000000 - 1` are **not** SM8250 leftovers - they match the
vendor's sc8180x `virtual-addr-pool`s exactly (`venus_ns` `0x25800000 + 0xba800000`,
`venus_sec_non_pixel` `0x1000000 + 0x24800000`, and 0xe0000000 is the top of the
non-secure pool).  The platform data is right for this SoC.

**What does not line up is where the UC region lands.**  That `dma_mask` bounds
the IOVAs the IOMMU layer hands out, and the allocator fills from the top, so the
region the firmware is told to use ends up at `0xdfc00000` - inside
`VideoSecurePT2`'s half of the address space, and *outside* the non-secure
window this machine's secure world was provisioned with.  Nothing on the CPU side
notices, because the CPU does not go through the SMMU: Linux wrote the queue
table there and read it back.  But a device access from the video's non-secure
bank to an IOVA outside that bank's window is precisely the thing that cannot
succeed - and "the firmware's first outbound access never completes" is the
failure `-17` pinned down.

That is testable without touching the code: `iris dma_mask_limit` is an exclusive
upper bound for the video's IOVAs, and `0xC0000000` puts every one of them below
the secure windows - inside both this board's non-secure window and the vendor's
non-secure pool.

`-18` ran that test.  The parameter did exactly what it was meant to:
`dma_mask=0xbfffffff (platform 0xdfffffff, limit 0xc0000000)` and
`ucregion: qtable=0xbfc00000 size=0x400000 sfr=0xbffff000` - the firmware's UC
region moved from `0xdfc00000` (inside `VideoSecurePT2`'s half) to `0xbfc00000`
(inside the non-secure window, and inside the vendor's non-secure pool as well).
The run then died in exactly the same place as before, on
`boot_fw: CTRL_INIT write`, with no new kernel message of any kind.

So the placement is not the cause, and this is the useful shape of negative
result: the intervention demonstrably changed the thing it was supposed to change
- the log proves the address moved - so "the firmware was handed memory outside
the window its bank is allowed" is eliminated rather than merely untested.

###### The VTL1 wall: what the Windows reverse engineering settled

Reverse engineering the four Windows drivers plus `QcSkExt8180.exe` (extracted
from the qcpil driver package on the Windows partition) settled what the "share /
unlock subsystem memory" steps are and why they cannot be reproduced from Linux:

* They are all **SIP/PIL SCM calls**, in a wire format bit-identical to
  mainline's `struct qcom_scm_desc` - `{u32 (owner<<24|svc<<8|cmd), u32 arginfo,
  u64 args[]}`.  qcpil's sequence is PIL/5 auth, **PIL/6 "unlock subsystem
  memory"**, PIL/1 init_image, PIL/2 mem_setup, MP/0x16 assign_mem, **PIL/0xb
  "share subsystem memory"**.  mainline has wrappers for all of them except
  PIL/6 (which it *names* `pas_shutdown`) and PIL/0xb.
* **PIL/6 cannot be issued from here.**  Called before init_image - the position
  Windows uses - the SMC never returns: the calling thread parks in it, the GPU's
  TZ traffic starves (`msm_dpu: hangcheck detected gpu lockup`) and the display
  freezes until a hard power cycle.  Windows sends it only behind a guard
  (`obj[0x110] == 1`, cleared afterwards), so mainline's naming looks like the
  accurate one.
* **MP/0x16 is VTL1-mediated on this machine.**  `QcSkExt8180.exe` is not a
  user-mode client but the Windows **VTL1 "SK extension" trustlet** (installed
  via `PlatformExecute`, imports only `IumSdk.dll`, assigns through
  `AssignMemoryToSocDomain`).  It *intercepts* `0x02000c16` and re-emits it to
  the real TrustZone in its own argument form (`pSrcVMList` + a 4 KB
  indirect-params block), which is not the flat six-argument form qcpil sends
  from VTL0 and `qcom_scm_assign_mem()` sends.  That is why every assign from
  Linux returns `-EINVAL`: four CP_* VMIDs (0x8/0xa/0xb/0xd), qcpil's own two
  hardcoded selector tuples, the trustlet's video sequence
  (`HLOS -> 0x0e -> 0x0c -> HLOS`) and a control all failed, both before and
  after `mem_protect_video_var()`.
* **PIL/0xb is the one call the trustlet does not intercept** (no case for
  `0x0200020b` in its dispatch table), so it does reach the real TrustZone from
  VTL0.  Implemented behind `pil0b_share` (via a project-local
  `qcom_scm_debug_call()`, since mainline has no wrapper) and tried at the safe
  `stop_before_boot` checkpoint - core released, never kicked - TrustZone answers
  **-EIO** for the `(address, size, pas_id, HLOS)` reading and **-EIO** again for
  the `(addr_lo, addr_hi, pas_id, HLOS)` one.  It returns rather than hangs, but
  it refuses both.

So the wall is specific: the step the Venus firmware needs before it can touch
DDR is an assign/XPU operation that on this machine is performed by a **Windows
VTL1 component**, which Linux cannot instantiate.  What VTL0 *can* reach is the
QSEE app interface - `qcom_scm_qseecom_app_get_id("qcom.tz.winsecapp")` answers
app_id 3 on this TZ, with `qcom.tz.uefisecapp` as a working control - and the
un-intercepted PIL/0xb, and neither of those is the missing assign.

###### Where the VPU bring-up ends (2026-10-05)

Two independent firmware builds fail identically.  The 2022 driver's
`VIDEO.IR.1.2-00042-PROD-1` (1159200 bytes, `md5 6909a826…`) goes through the
same sequence - TZ authenticates it (`PAS auth ret=0`), the probe registers read
back the same (`hw_version=0x5010002f`, `intr_mask=0x1e2`) - and dies on the same
line, at/just after `boot_fw: CTRL_INIT write`.  The image is not the variable.

What is established, in order:

1. the block comes up correctly: in a live `no_auth` window VENUS_GDSC is
   powered, the iris RCG is running, mvsc_core/mvs0_core/axi0/axi1 are enabled,
   and the AHB2AXI bridge is out of reset;
2. TZ authenticates the firmware and releases the core (`PAS auth ret=0`), and
   the core executes it - the CTRL_INIT handshake comes back;
3. with the core released and **no host register access at all**, the machine
   dies about 10 ms after CTRL_INIT (`-17`);
4. in every run the firmware never wrote to DDR: the message queue's write index
   stayed 0 and the SFR stayed empty.

So the application processor does everything it controls - power, clocks, a
DDR-visible UC region, an authenticated image, a released core - the firmware
starts, and then its first trip out to memory takes the interconnect down.  The
SMMU translation and the XPU permissions on that path are the secure world's:
the vendor's vidc node declares four context banks (one non-secure plus three
secure; mainline declares one and trusts TZ for the rest), the wrapper's FW/CPA
window is TZ-programmed, and the handover itself is what the Windows PIL driver
does with its "share"/"unlock subsystem memory" TREE steps - for which mainline
has no equivalent.  Nothing the driver writes changes any of that.

That is where the non-secure road ends.  Every lever on this side of the fence
has now been either verified working or tested and eliminated: power, clocks,
resets and the UC region's placement all provably happen; the firmware image
(two builds), the driver's register sequences, the doorbell, the interrupt path,
the polling and the IOVA window are all ruled out.  The instrumentation stays in
the tree behind debug module parameters
(`hold_after_auth_ms`, `quiet_after_ctrl_init_ms`, `hold_after_ctrl_init_ms`,
`dma_mask_limit`, `no_auth`, `fw_name`, `fw_phys`, `fw_size`), together with
`tools/probe-vdec-run.sh`, `debug/videocc-peek.py` and the `vendor-ref/`
extracts, as the record of how far this got and what ruled out what.

## Suspend / s2idle — WORKING (root cause: the power key was never enabled)

Status: **working**, verified on hardware 2026-10-04.  Two s2idle cycles,
`suspend_stats: success=2 fail=0`, with

    PM: suspend entry (s2idle)
    PM: suspend exit

in the kernel log, entered and left with the power button; the lid switch does
the same.

The original symptom — "screen goes off and never comes back, hard reset
required" — was never a hang in the suspend path: the machine was suspending
correctly and **nothing could wake it**.  That is also why `suspend_stats` read
0/0 and why no `PM: suspend entry` line existed in any retained boot — the only
way out was a hard reset, which discarded the evidence.

### What is already in place

* `mem_sleep` is `s2idle`; `CONFIG_SUSPEND`, `CONFIG_PM_SLEEP`, `CONFIG_CPU_IDLE`,
  `CONFIG_ARM_PSCI_CPUIDLE`, `CONFIG_QCOM_PDC` and `CONFIG_QCOM_RPMHPD` are set;
* the `psci` node carries the CPU and cluster power domains plus both vendor
  `domain-idle-states`, and the running DT has them
  (`/proc/device-tree/cpus/domain-idle-states/`);
* TLMM has `wakeup-parent = <&pdc>`;
* firmware reports PSCI v1.1 in OSI mode.  `SET_SUSPEND_MODE(PC)` is **denied**
  (`psci: [Firmware Bug]: failed to set PC mode: -3`), so the platform stays in
  OSI mode and `CPUidle PSCI` builds the OSI topology.

### Cleared against the vendor reference

`sc8180x-xiaomi-book-12.4-oc-reference.dts` (vendor-derived) agrees with the
upstream DT on every suspend-relevant node, so none of them is a transcription
error:

| node | vendor reference | this tree |
| --- | --- | --- |
| `pdc` ranges | `0x00 0x1e0 0x5e`, `0x5e 0x261 0x1f` | `<0 480 94>, <94 609 31>` |
| `pdc` reg | one region, `0xb220000` + `0x30000` | identical |
| cluster idle states | `0x41000044`, `0x4100a344` | identical |

The second `pdc` region that `sm8250`/`sc8280xp` carry (`<0 0x17c000f0 0x60>`) is
absent from the vendor DT too, and the mainline driver only maps resource 0 — so
it is not a deviation.

### The fix

`sc8180x-pmics.dtsi` declares the PM8150 PON power key but leaves it
`status = "disabled"`, and no board enabled it for the Xiaomi — upstream does
that per board (`3706bcfbdb8a`, "arm64: dts: qcom: sc8180x: Enable the power
key", for Primus and the Flex 5G).  The board DTS now carries:

    &pmc8180_pwrkey {
            status = "okay";
    };

Consequences of the omission: there was no `KEY_POWER` input device
(`/proc/bus/input/devices` had no pwrkey) and the power key was absent from
`/sys/class/wakeup/*`.  With the node enabled, `pm8941-pwrkey` probes and — since
`pwrkey_data.wakeup_source_default = true` — registers itself as a wakeup source
(`c440000.spmi:pmic@0:pon@800:pwrkey`), which is what lets the power button wake
the machine from s2idle.

`panel-dtb/pwrkey-enable.dts` + `sc8180x-xiaomi-book-12.4-oc-pwrkey.dtb` was the
runtime form used for the first test.  Note that `fdtoverlay` **cannot** apply it
to these DTBs — they are built without `-@`, so there is no `/__symbols__` node
("base blob does not have a '/__symbols__' node") — hence the fix has to come
from a source build.

### Why the usual pm_test ladder cannot localise this

For suspend-to-idle the kernel accepts only `none/freezer/devices/platform`
(`kernel/power/suspend.c`), and with `TEST_PLATFORM` set `suspend_enter()` jumps
straight to `Platform_wake` — so `platform` never runs `s2idle_loop()`.  The
ladder proves the device and noirq/late paths are clean but cannot reach the
s2idle entry itself (cpuidle -> PSCI OSI -> `cluster_sleep_aoss_sleep`, wakeup
through the PDC).  Only a real suspend exercises that.

### Recipe (kept for reference — the ladder turned out not to be needed)

`tools/suspend-test.sh` (root) writes a synced marker log, so after a hard reset
`ATTEMPT` without `RESUMED` means the kernel never returned:

    sudo install -Dm644 panel-dtb/sc8180x-xiaomi-book-12.4-oc-pwrkey.dtb \
         /boot/dtb/linux-mibook/qcom/sc8180x-xiaomi-book-12.4-oc.dtb
    sudo reboot
    sudo bash tools/suspend-test.sh prep
    sudo bash tools/suspend-test.sh level devices     # dpm_suspend/resume only
    sudo bash tools/suspend-test.sh level platform    # adds noirq + late prepare
    sudo bash tools/suspend-test.sh rtc 30            # decisive: real s2idle + alarm
    bash tools/suspend-test.sh report                 # after any hard reset

Interpretation:

* `rtc 30` returns — s2idle entry/exit and RTC wakeup both work, so the original
  failure was the missing wake source; then verify the power key and the lid
  really do wake it;
* `rtc 30` never returns — the hang is in the s2idle entry or in the wakeup
  routing; next suspects are the deepest cluster state and the wakeup path behind
  the PDC;
* `level devices`/`platform` hangs — a driver, named by the last line of the
  verbose dpm log (`pm_debug_messages=1`).

## Volume keys — wired from ACPI (volume up working)

The volume keys are described **only** in ACPI, by the Generic Buttons device
(`\_SB.BTNS`, `_HID ACPI0011`) that Linux has no driver for — the vendor device
tree does not mention them, and neither do the upstream SC8180X boards:

| `_CRS` GpioInt on `\_SB.PM01` | flags | `_DSD` usage | key |
| --- | --- | --- | --- |
| pin `0x0000` | ActiveBoth, ExclusiveAndWake, PullDown | page `0x01`, `0x81` | KPDPWR (power) |
| pin `0x0001` | ActiveBoth, Exclusive, PullDown | page `0x0C`, `0xEA` | Volume Down |
| pin `0x0085` | ActiveBoth, Exclusive, PullUp | page `0x0C`, `0xE9` | Volume Up |

`\_SB.PM01` (`_HID QCOM0430`, `_UID 1`) mixes two number spaces, which is what
made this take several attempts: plain PMIC interrupts sit below `0x80` (the ADC
and BCL entries in *both* this machine's dump and the Surface Pro X's are like
that), while the PMIC GPIOs are `0x7f + gpio`.

The Surface Pro X dump in `aarch64-laptops/build/misc/microsoft-surface-prox`
supplies the second half: its own button device (`\_SB.MSBT`, `MSHW0040`)
declares the same `0x00`/`0x80`/`0x85` triple on the same controller, and the
linux-surface Surface Pro X port (`4bc1a33`, "surface-prox: Add support for
volume buttons") drives its volume keys from the first PMIC's **GPIO 1 and
GPIO 6** — i.e. `0x80` and `0x85`.  Reading the three pins that way:

| pin | is | Linux |
| --- | --- | --- |
| `0x0000` | PON KPDPWR | `&pmc8180_pwrkey` — the power key already enabled |
| `0x0001` | PON RESIN | `&pmc8180_resin`, `linux,code = <KEY_VOLUMEDOWN>` |
| `0x0085` | first PMIC GPIO 6 | `gpio-keys`, `linux,code = <KEY_VOLUMEUP>` |

Volume up was verified on hardware 2026-10-04.  Volume down needs RESIN, which
`sc8180x-pmics.dtsi` never declared at all (upstream `pm8150.dtsi` has it, and
the Surface Duo enables it for exactly this key):

    pmc8180_resin: resin {
            compatible = "qcom,pm8941-resin";
            interrupts = <0x0 0x8 0x1 IRQ_TYPE_EDGE_BOTH>;
            debounce = <15625>;
            bias-pull-up;
            status = "disabled";        /* enabled by the board */
    };

    &pmc8180_resin {
            status = "okay";
            linux,code = <KEY_VOLUMEDOWN>;
    };

`qcom-pon` populates the PON children (`devm_of_platform_populate()`), so the
resin probes exactly the way the power key does.

Two readings of `0x85` (`0x7f + 6` and `0x80 + 5`) are still instantiated as
separate volume-up input devices; once the firing one is known the other is
removed.  Those pins are configured active-low with an internal pull-up,
matching the Surface Pro X port; if a key reports the opposite of what is
pressed, flip `GPIO_ACTIVE_LOW` (or the bias).

## GPU DVFS: the higher states this part advertises — WORKING

The part on this board is binned above the profile `sc8180x.dtsi` describes: the
DSDT carries several GPU DVFS sets, and the stock table Linux uses is the
slowest of them.  They are all `"ENGINE_PSTATE_SET" 0x02` /
`"GRAPHICS_FREQ_CONTROL"` / `"CORE_CLOCK"` entries in `~/acpi-dumps/dsdt.dsl`,
each PSTATE giving the core clock, a GPU percentage and the RPMh corner:

| set | PSTATE -> CORE_CLOCK (RPMh level) |
| --- | --- |
| stock (what `sc8180x.dtsi` has) | 514 (TURBO_L1), 500 (TURBO), 461 (NOM_L1), 405 (NOM), 315 (SVS_L1), 256 (SVS), 177 (LOW_SVS) |
| 670 MHz profile | 670 (TURBO_L1), 625 (TURBO), 595 (NOM_L1), 530 (NOM), 392 (SVS_L1), 315 (SVS), 235 (LOW_SVS) |
| 718 MHz profile | 718 (TURBO_L2), 670 (TURBO_L1), 625 (TURBO), 595 (NOM_L1), 530 (NOM), 392 (SVS_L1), 315 (SVS), 235 (LOW_SVS) |

Windows on this machine reports 670 MHz as the GPU maximum, i.e. it runs the
670 MHz profile.

Validated by building the same tree with the extra frequencies appended and
running it: adding the states to the OPP table is all it takes for the GPU to
use them, which is what the mechanism below predicts.  The three added levels
also need no new RPMh arc — each one is already used by a stock state
(`NOM`/`NOM_L1`/`TURBO_L1` back 405/461/514 MHz), so the `gfx.lvl` lookup that
`a6xx_gmu_rpmh_arc_votes_init()` performs cannot fail on them.

### Why declaring the states is enough

The a6xx driver does not read its DVFS levels from the firmware — it *sends* its
whole OPP table to the GMU over HFI:

    a6xx_hfi_send_perf_table(): msg.num_gpu_levels = gmu->nr_gpu_freqs;
                                msg.gx_votes[i].freq = gmu->gpu_freqs[i] / 1000;

and each level's GX rail vote comes from the OPP's `opp-level`
(`a6xx_gmu_rpmh_arc_votes_init()` -> `a6xx_gmu_get_arc_level()` ->
`dev_pm_opp_get_level()`), matched against the RPMh `gfx.lvl` command-db list.
So an extra OPP carrying the vendor's own corner fully describes a new firmware
DVFS level; nothing else needs to change.

### What is in the tree

The board content lives in `sc8180x-xiaomi-book-12.4.dtsi`, which now carries
the three extra states itself — there is no separate variant any more:

| state | `opp-level` |
| --- | --- |
| 530 MHz | `RPMH_REGULATOR_LEVEL_NOM` (`0x100`) |
| 595 MHz | `RPMH_REGULATOR_LEVEL_NOM_L1` (`0x140`) |
| 670 MHz | `RPMH_REGULATOR_LEVEL_TURBO_L1` (`0x1a0`) |

625 MHz (`TURBO`) and 718 MHz (`TURBO_L2`) are deliberately left out.  Folding
them into the board file produced a DTB byte-identical to the earlier
`-oc` variant build, so this is exactly the same device tree the default entry
used to boot.

`sc8180x-xiaomi-book-12.4.dts` is a thin wrapper for it, and the package installs
that one DTB under every name GRUB references —
`sc8180x-xiaomi-book-12.4.dtb` (Advanced / SD-card entries) and
`sc8180x-xiaomi-book-12.4-oc.dtb` (the default entry), plus a
`-vdec-probe.dtb` copy with the VPU node enabled for the video work.  So
whatever entry is picked, the GPU gets the full set; `set-panel-link-mode.sh`
and `install-mainline-panel.sh` still only write the stock path because their
prebuilt panel DTBs predate all of this.

### Speed bin or profile?

These are **firmware-advertised profiles, not an over-bin**: the tables are
ACPI `PMCL` capability lists in `Device (MON0)` (`Method (PMCL)`), i.e. sets the
OS is offered and selects from, and the DSDT contains no speed-bin/GCN fuse
value at all (it would be a `speed_bin` nvmem cell in the DT).  There is no such
cell here, so `a6xx_set_supported_hw()` gets `-ENOENT`, applies no
`opp-supported-hw` gating, and every declared OPP is available — which is also
why `dmesg` has no speed-bin warning.  Windows on this machine picks the 670 MHz
set; the board device tree simply declares the same states to the GMU.

### Verify

`tools/gpu-oc-check.sh` confirms a booted tree in one go — the booted DTB
hashes, the devfreq table, which of the three states are present, the log's GPU
errors, and (with `-- <command>`) the peak `cur_freq` while a workload runs:

    tools/gpu-oc-check.sh
    tools/gpu-oc-check.sh -- vulkaninfo --summary   # any GPU load works

It exits 2 when the booted tree is the stock one and prints the install line.
With the `-oc` DTB booted the table reads:

    available_frequencies: 177000000 256000000 315000000 405000000 461000000 \
                           500000000 514000000 530000000 595000000 670000000

To install it, package the built tree (`tools/make-kernel-package.sh 10`,
which needs no source clone and installs the one DTB under every GRUB name) and
`sudo pacman -U` the result, or copy the DTB by hand into both names:

    D=/boot/dtb/linux-mibook/qcom
    sudo install -Dm644 src/kernel/arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4.dtb $D/sc8180x-xiaomi-book-12.4.dtb
    sudo install -Dm644 src/kernel/arch/arm64/boot/dts/qcom/sc8180x-xiaomi-book-12.4.dtb $D/sc8180x-xiaomi-book-12.4-oc.dtb

The way back is to delete the three OPPs and rebuild, or to drop a stock DTB
into those slots.

## Build note

`tools/lib/bpf/libbpf.c` needs explicit `(char *)` casts on `strstr()`/`strchr()`
results for GCC 16 (`resolve_btfids` is built with `-Werror`). Without them the
build fails in `tools/bpf/resolve_btfids`.

## Volume: the "everything is routed but there is no sound" trap

Confirmed working on hardware 2026-10-03 — but the last hurdle was **gain, not
routing**. `Speaker Digital Volume` (the ctl-remap of `RX7/RX8 Digital
Volume`) had ended up very low, which is inaudible no matter how correct the
routing is. Raising it in `alsamixer` produced sound immediately.

**Read the dB scale before trusting "full".** The control is
`SOC_SINGLE_S8_TLV(..., -84, 40, digital_gain)`, i.e. a *signed* value in dB:
raw 0 = -84 dB, **raw 84 = 0 dB**, raw 124 = **+40 dB**. The user-visible range
0..124 is the signed value offset by 84, so the top of the range is 40 dB
*above* 0 dBFS, not "full scale". alsa-lib reports this directly:

```
$ amixer -c 0 sget 'Speaker Digital'
  Limits: 0 - 124
  Front Left: 124 [100%] [40.00dB]
$ amixer -c 0 sget 'HP Digital'
  Front Left:  82 [ 66%] [-2.00dB]      # the headphone path, for comparison
```

`alsactl` records the same thing (`dbvalue.0 4000` for RX7/RX8). Upstream agrees
on where 0 dB is: `codecs/qcom-lpass/rx-macro/init.conf` sets its RX macro
volumes to 84, and `codecs/wcd934x/init.conf` sets RX1/RX2/RX7/RX8 to 80
(-4 dB).

### The S24_LE speaker backend was the quiet path (root cause, 2026-10-05)

The obvious reading of the above — "124 is overdrive, 84 is full scale, so use
84" — is **wrong here, and acting on it silences the machine completely.** This
box genuinely needed all 40 dB, because the playback path was 20-48 dB down.

Root cause: `sdm845_be_hw_params_fixup()` pinned `SLIMBUS_0_RX` to `S24_LE` for
this machine, on the strength of the Windows ACDB declaring the built-in
speaker topology as 48 kHz/24-bit (`8592f84cf7ba`). That reading is wrong end
to end. Measured on hardware with `RX7/RX8 Digital Volume` held at a fixed
+20 dB, playing the same -12 dBFS 880 Hz tone as raw PCM straight to `hw:0,0`:

| front end | result |
|---|---|
| `S16_LE` | clearly audible |
| `S24_LE` | **not audible at all** |

One byte of misalignment, 20-48 dB. And because PipeWire picks the front-end
format from the advertised backend constraints, **every** player ended up on
the quiet path (`hw_params: format: S24_LE`). The only way to get usable sound
out was to push the RX digital volumes to their +40 dB maximum, which then
squared off anything loud — the "quieter than Windows, with the occasional
crackle" this machine had been living with since the first bring-up.

Fixed in `57de82c7de84` by keeping the generic `S16_LE` (the 48 kHz /
2-channel constraints, which the ACDB reading did get right, are unchanged),
plus the 0 dB cap in `ff4dc28f8045`. **The cap is only correct once the format
is right** — while the path was still 20-48 dB down it removed the gain the
machine was living on and made the speakers completely silent.

### The backend alone was not enough: the front end has to be 16-bit too

`57de82c7de84` pins the *backend*. That is necessary but not sufficient,
because the front ends advertise S16/S24/S32 and **ACP picks S24_LE from that
set on its own** — the node property `audio.format` does not override it
(a WirePlumber rule setting it was tried and did nothing). So every player
still landed on the quiet path; `hw_params` read `format: S24_LE` even with
the backend already forced to `S16_LE`, and PipeWire playback at 0 dB was
silent while `aplay -f S16_LE` at the same gain was audible.

`430e0dbdb508` fixes it where it belongs, in `sdm845_fe_startup()`: the
playback front ends of this machine are constrained to `S16_LE`, so the choice
is not left to the sound server. Playback only — capture has its own,
separate quirk (see the microphone section).

So the complete fix is three commits, and they only work together:

| commit | what |
|---|---|
| `57de82c7de84` | `SLIMBUS_0_RX` backend back to the mainline `S16_LE` |
| `430e0dbdb508` | playback front ends narrowed to `S16_LE` |
| `ff4dc28f8045` | RX1/RX2/RX7/RX8 capped at 84 = 0 dB (correct *because* of the two above) |

Verify with `tools/audio-level-test.sh`, which pins 0 dB and plays straight to
the hardware: audible at 0 dB means the level is right. Then check that
PipeWire agrees — `grep format /proc/asound/card0/pcm0p/sub0/hw_params` while
something plays should now read `S16_LE`, not `S24_LE`.

### Verified on hardware 2026-10-05

With `57de82c7de84` + `430e0dbdb508` + `ff4dc28f8045` loaded and the stock
`wsa881x` driver, everything finally reads the way it should, and it sounds
loud and clean at 0 dB — with no +40 dB of digital gain anywhere:

```
$ amixer -c 0 sget 'Speaker Digital'
  Limits: 0 - 84
  Front Left: 84 [100%] [0.00dB]
$ grep format /proc/asound/card0/pcm0p/sub0/hw_params
  format: S16_LE
$ cat /sys/bus/soundwire/devices/sdw:0:0:0217:2110:00:{3,4}/status
  Attached
  Attached
```

`format: S16_LE` is the one that matters — that is the fingerprint of this
whole bug, and it read `S24_LE` on every previous attempt.

### The amplifier power-up race is what actually breaks the machine

Worth keeping separate from all of the above, because it bit hard during this
debugging: our own PA-gain patch (`cecbd35ca830`) adds a bus access at
`SND_SOC_DAPM_PRE_PMU`, and the SoundWire analysis calls that an **aggravator**
of the amplifier power-up race. When that race is lost the amplifier ends up
stuck, and the failure is total rather than merely quiet:

```
wsa881x-codec sdw:0:0:0217:2110:00:4: Initialization not complete, timed out
wsa881x-codec sdw:0:0:0217:2110:00:4: ASoC error (-110) at ...pm_runtime_get()
SLIM Playback:                          ASoC error (-110) at __soc_pcm_open()
MultiMedia1:                            ASoC error (-110) at dpcm_fe_dai_startup()
...
sdw:0:0:0217:2110:00:4  UNATTACHED  power/runtime_status = error
```

The card still registers, but the amps are off the bus, WirePlumber can only
offer `Dummy Output`, and no PCM can be opened at all — so there is no sound
anywhere, which reads like a far worse bug than it is. Recovery is a reboot;
`tools/install-amp-variant.sh h1a` removes the failure mode (and the pops) by
never power-cycling the amplifier. `tools/install-amp-variant.sh` switches
between the three variants, and the default install uses the *stock* driver on
purpose.

### The prebuilt variants are per-kernel objects (2026-10-07)

`tools/orig-snd-soc-wsa881x.ko` and `tools/h1a-snd-soc-wsa881x.ko` are binaries,
and a kernel module is only valid for the kernel build it was generated
against: the loader validates the module's BTF against the **running** kernel's
table (`/sys/kernel/btf/vmlinux`). A stale `.ko` keeps a matching `vermagic`
and `modinfo`, so nothing looks wrong at install time — and then the kernel
says

```
failed to validate module [snd_soc_wsa881x] BTF: -22
```

The module never loads, both WSA881x components are missing, `snd_soc_sdm845`
cannot build the card, and the machine boots with **no sound card at all**
(`--- no soundcards ---`, `alsamixer: cannot find card '0'`). This is not the
amplifier race above and not a SoundWire fault: nothing was misconfigured, the
codec never got a chance to register.

It happened on 2026-10-07: `tools/audio-fix-install.sh` installed the 10-05
prebuilts, and the running kernel was #35, rebuilt in between with
`sched_ext` / `uclamp` / `DEBUG_INFO_BTF` config changes that moved the vmlinux
BTF. The fix is to *rebuild* the variants for the running kernel:

```
tools/build-amp-variant.sh          # normal user, not sudo
sudo tools/install-amp-variant.sh orig
```

`build-amp-variant.sh` rebuilds both variants from the tree (reverting
`cecbd35ca830` for `orig`, dropping the `SD_N` assert for `h1a`), strips debug
info while keeping `.BTF`, restores the tree's own `gain` build, and writes
`tools/.amp-variant-btf` — the hash of `/sys/kernel/btf/vmlinux` at build time.
`install-amp-variant.sh` refuses to install `orig`/`h1a` when that hash no
longer matches the running kernel (`AMP_VARIANT_FORCE=1` overrides), so this
failure mode cannot come back silently. `gain` comes from the tree build and is
never checked because it is always in step with it.

Verification: the tree's `vmlinux` `.BTF` section and the running kernel's
`/sys/kernel/btf/vmlinux` hash the same (`761c4fc4…` on this boot), which is
what makes a freshly built variant trustworthy without rebooting to test it.

### Correction: an earlier revision of this file got this backwards

It previously claimed `124` was "squared off" overdrive, that "84 was already
loud", and that "**0 dB (84) is the correct maximum for this control**" — with
an A/B test cited as evidence. That A/B rested on a mis-heard answer, and the
claim was wrong: at 84 the speakers are inaudible on this machine (pre-format
fix). The wrong conclusion then drove a kernel patch that muted the machine for
hours while the mixer, DAPM and DSP all read correctly. Recorded here so the
same reasoning is not repeated.

Why the desktop volume slider does not help: the UCM verb declares
`PlaybackMixerElem "Speaker"` / `"HP"`, but the remapped controls are named
`Speaker Digital Volume` / `HP Digital Volume`. WirePlumber therefore logs

    spa.alsa: Path Speaker is not a volume or mute control

and falls back to **software** volume, leaving the hardware gain wherever it
happens to be. Two consequences:

* the volume keys / slider never change the real gain, and
* software volume at 100% can still be silent if the hardware gain is low.

Fix in this tree: `ucm2/Qualcomm/xiaomi-book-12.4/HiFi.conf`, a copy of
`/Qualcomm/sdm845/HiFi-MM1.conf` with the element names corrected.

**The remaining name bug (found 2026-10-05).** `PlaybackMixerElem` takes the
*simple-mixer* element name, which is the control name with a trailing
`" Volume"` / `" Switch"` stripped — compare every other profile, which writes
`PlaybackMixerElem "Headphone"`, `"Digital PCM"`, `"Line Out"`. Our file wrote
the full control name, so the lookup failed:

```
$ amixer -c 0 sget 'Speaker Digital'          # the element that exists
  Capabilities: volume
  Front Left: 84 [68%] [0.00dB]
$ amixer -c 0 sget 'Speaker Digital Volume'
amixer: Unable to find simple control 'Speaker Digital Volume',0
```

The earlier conclusion that the control was refused because it is write-only
was **wrong**: the remapped control reads back fine (`Capabilities: volume`,
and `amixer scontrols` does list `Speaker Digital`). It is only the name that
does not resolve. Use `PlaybackMixerElem "Speaker Digital"` and
`"HP Digital"`.

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

### Outcome of the volume-element fix (re-tested 2026-10-05)

The corrected verb **is** in use — WirePlumber's warning named
`Path Speaker Digital Volume`, proving the UCM parsed our file rather than the
upstream one — but it still refused the control. The explanation recorded here
originally (the ctl-remap creates a write-only control with `access=rw---R--`,
so the simple mixer cannot represent it) was **wrong**. The control is read
back happily; the real cause was the element name. `PlaybackMixerElem` takes
the *simple-mixer* name, i.e. the control name with the trailing `" Volume"`
stripped, so it has to be `"Speaker Digital"` / `"HP Digital"`.

Verified against a live WirePlumber, without installing anything, by pointing
the session at an overlay copy of ucm2:

    systemctl --user set-environment ALSA_CONFIG_UCM2=/tmp/ucm-overlay
    systemctl --user restart wireplumber pipewire
    # -> neither device logs "not a volume or mute control" any more

and that it is a genuine hardware handover, because moving the desktop slider
now moves the codec register (nothing was playing, so nothing was heard):

    wpctl 0.2 -> Speaker Digital 83  [ -1.00 dB]
    wpctl 0.4 ->                101  [+17.00 dB]
    wpctl 0.6 ->                111  [+27.00 dB]
    wpctl 0.8 ->                119  [+35.00 dB]
    wpctl 1.0 ->                124  [+40.00 dB]

Which exposes the second trap: with the control exposed as-is, **100% on the
slider means +40 dB** and the useful part of the travel is the bottom fifth. So
the name fix alone is not a fix — it just moves the overdrive out of
`asound.state` and into the user's hands. Three changes therefore belong
together, and all are in this tree:

1. `ucm2/Qualcomm/xiaomi-book-12.4/HiFi.conf`: `PlaybackMixerElem` uses the
   simple-mixer names, so the desktop slider drives the real hardware gain.
2. `sdm845.c`: caps `RX1/RX2/RX7/RX8 Digital Volume` at 84 (0 dB) on this
   machine, the same way `sc8280xp.c` caps the WSA macro volumes. With the cap
   the slider's whole travel is useful and 100% is exactly 0 dB.
   (`e7ca760822ae` "ASoC: qcom: sdm845: cap the Xiaomi Book 12.4 playback
   volumes at 0 dB" — `snd_soc_limit_volume()` locates the control by exact
   name and clamps in the same 0..124 space userspace sees, so 84 is 0 dB.)
3. `wsa881x.c`: keeps the user's `SpkrLeft/Right PA Volume` across DAPM
   power-up, so the amplifier gain the UCM asks for (+18 dB) is not rewritten
   back to +12 dB on every stream start. (`cecbd35ca830` "ASoC: wsa881x: keep
   the user PA gain across DAPM power-up".)

The PA-gain reset is easy to reproduce **without making any sound**, because
DAPM powers the amplifier up on stream start regardless of the content:

    # right after WirePlumber has applied the Speaker enable sequence
    amixer -c 0 cget numid=4        # SpkrLeft PA Volume -> 12  (+18 dB)
    aplay -D hw:0,0 silence.wav     # 2 s of digital silence
    amixer -c 0 cget numid=4        # -> 8  (+12 dB)  <- gain lost

Measured exactly like that on 2026-10-05. Note the mixer *cache* is what
reports 8: `wsa881x_pre_pmu_pa_2_0[]` writes `SPKR_DRV_GAIN` through regmap,
so the control read back follows the hardware rather than what was asked for.

`tools/audio-fix-install.sh` installs the three pieces, `depmod`s, pins the
stored gain at 0 dB and re-stores it. All of it takes effect on the next
reboot.

Until the patched machine driver is loaded, pin the stored gain at 0 dB:

    amixer -c 0 cset numid=2 84       # Speaker Digital Volume, 0 dB (RX7/RX8)
    sudo alsactl store                # persist across reboots

**Do not use 124** — that is +40 dB, not "full scale". `init.conf` also declares
a `BootSequence` setting `RX7/RX8 Digital Volume` to 80 (-4 dB) whenever the
card is enabled; whether alsa-lib applies that in UCM2 is unverified (the value
actually observed in the register came from `asound.state`), but 80 is a sane
value in any case.

### Known remaining audio fault: SoundWire pops and the clash storm

The `Slave N state check1: UNATTACHED` lines (~30/day) and the 68-second
`Bus clash detected` storm (10,513 lines at 08:24:30–08:25:38) are investigated
in [soundwire-pops-report.md](soundwire-pops-report.md). Summary: the master's
clash report is effectively one-shot per resume cycle, the slave alert path has
a bounded retry loop but no recovery at all, and the UNATTACHED lines are a
transition-triggered bookkeeping mismatch on a *real* detach/attach cycle,
because runtime PM physically powers the amplifiers down
(`wsa881x_runtime_suspend()` asserts `SD_N`) while the master is still running.
Deliberate silent-stream, service-restart and sample-rate experiments did
**not** reproduce either message, which is consistent with the transition guard
rather than with a per-stream fault. Ranked fixes with their trade-offs are in
that file; **none is applied yet** — the smallest is to stop
`wsa881x_runtime_suspend()` from asserting `SD_N`.

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
