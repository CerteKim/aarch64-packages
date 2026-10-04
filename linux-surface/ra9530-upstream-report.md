# Xiaomi Book S 12.4 (SC8180X): magnetic stylus charging is gated outside the AP

**Device:** Xiaomi Book S 12.4 (`xiaomi,book-12.4`, TIMI, SC8180X)
**ACPI device:** `Device (SXB)`, `_HID = "TXRA9530"` — "Wingtech SXB Charger-TXRA9530 Device"
**Chip:** Renesas RA9530 (50 W wireless power receiver with WattShare TRx mode), chip ID `0x9530`,
rev 2, customer ID 2
**Kernel:** 6.18.2, DT boot (the platform's ACPI tables are not consumed)

---

## TL;DR

The magnetic pen charger (a Renesas RA9530 on I2C8 at address `0x3B`) is present, powered
(VOUT ≈ 7.05 V), healthy, and fully responsive on I2C — but it cannot be switched into
transmit (TRx) mode from the AP.

* The DSDT hands the AP exactly **two** GPIOs for this device: `gpio11` and `gpio186`.
  Measured, they are **the external power switch** and **the 7 V boost enable** — i.e. the
  two enables from the Renesas reference design. Neither is `GP2/TX_EN`.
* The chip's **entire TX command register (`0x007C`) is inert** — none of bits 0–4 are ever
  cleared by the chip, while normal registers on the same chip read/write fine.
* The Renesas documentation gives exactly two ways to enable TX: the `GP2/TX_EN` pin being
  high when VOUT is powered, or writing `0x007C` bit0. Both are unavailable to us.
* The shipped Windows driver (`wtSXBCharger.dll`, UMDF) **never writes `0x007C`** either —
  it only monitors the chip — yet the pen charges under Windows.

**Conclusion:** TX is enabled by the EC/firmware (via `GP2`), which is not exposed to the AP
on this board. A Linux driver cannot turn the pen charger on. Reports of a working
implementation, or a test that isolates the enabler, would be very welcome.

---

## ACPI facts (from the decompiled DSDT)

The full ACPI dump for this machine is already available in this repository:
<https://github.com/aarch64-laptops/build/tree/master/misc/xiaomi-book-s>
(`dsdt.dsl` is the decompiled ASL, `dsdt.dat` the raw table).

```asl
Device (SXB)
{
    Name (_DEP, Package (0x03) { \_SB.GIO0, \_SB.I2C8, \_SB.PEP0 })
    Name (_HID, "TXRA9530")
    Name (_UID, One)
    Name (_STA, 0x0F)
    Method (_CRS, 0, NotSerialized)
    {
        Name (RBUF, ResourceTemplate ()
        {
            I2cSerialBusV2 (0x003B, ControllerInitiated, 0x00061A80,   // 0x61A80 = 400 kHz
                AddressingMode7Bit, "\\_SB.I2C8", 0x00, ResourceConsumer, , Exclusive)
            GpioInt (Level, ActiveLow, SharedAndWake, PullUp, 0x0000, "\\_SB.GIO0", ...)
                { 0x0065 }        // TLMM 101
            GpioInt (Edge,  ActiveLow, SharedAndWake, PullUp, 0x0032, "\\_SB.GIO0", ...)
                { 0x00BD }        // TLMM 189
            GpioInt (Edge,  ActiveLow, SharedAndWake, PullUp, 0x0032, "\\_SB.GIO0", ...)
                { 0x0061 }        // TLMM 97
            GpioIo  (Shared, PullUp, 0x0000, 0x0000, IoRestrictionNone, "\\_SB.GIO0", ...)
                { 0x000B }        // TLMM 11
            GpioIo  (Shared, PullUp, 0x0000, 0x0000, IoRestrictionNone, "\\_SB.GIO0", ...)
                { 0x00BA }        // TLMM 186
        })
        Return (RBUF)
    }
}
```

* `\_SB.I2C8` has `Memory32Fixed (0x0089C000, 0x4000)` and interrupt `0x280` (640), which
  matches Linux `/sys/firmware/devicetree/.../i2c@89c000` and `/proc/interrupts`
  (`GICv3 640 Level 89c000.i2c`). So the charger is `&i2c7` in the Linux DT.
* **There are no `_PR0` / `PowerResource` / `_ON` / `_OFF` / `_DSM` objects on this device.**
  All ACPI power sequencing that one might hope to replicate is absent.
* `_DEP` includes `\_SB.PEP0`; there is also `Device (RHPX)` with `_HID = "MSFT8000"` — the
  Windows *Resource Hub Proxy* (`rhproxy`), an I2C device at `0x48` on `I2C2`
  (0x00884000 = Linux `i2c-0`, the touchscreen bus). The Windows driver is UMDF and
  therefore accesses its GPIO/I2C resources through `\\.\RESOURCE_HUB\<id>`.

---

## What is measured to work

### I2C

Slave `0x3B`, **two-byte big-endian register address**, multi-byte data is **little-endian**,
address auto-increments. Confirmed against the Renesas I2C write-format figure and by
reading the chip ID at `0x0000` (= `0x30 0x95` = `0x9530`).

```bash
# chip id
sudo i2ctransfer -y 1 w2@0x3b 0x00 0x00 r2        # -> 0x30 0x95
# system operating mode
sudo i2ctransfer -y 1 w2@0x3b 0x00 0x4d r1        # -> 0x80
```

Practical notes:

* `i2cdetect -y 1` **cannot see `0x3b`** — `geni-i2c` does not implement
  `I2C_FUNC_SMBUS_QUICK`, so the tool only probes `0x30–0x37` and `0x50–0x5f`.
  Use `sudo i2cdetect -y -r 1`.
* A broad `i2cdetect -r` sweep at 1 MHz produces a burst of
  `geni_i2c 89c000.i2c: Bus arbitration lost, clock line undriveable`.
  Targeted transactions at 1 MHz are fine. **The ACPI descriptor says 400 kHz** —
  the in-tree DT node for `&i2c7` sets `clock-frequency = <1000000>`, which should be
  changed to `<400000>`.

### GPIOs

| Pin | Role (measured) | Evidence |
|---|---|---|
| TLMM 11 | **Switch** — chip enable/power | Write `0x0050 = DEADBEEF`, drive pin low 600 ms, release: the marker is gone (the chip really reset). It also disappears from I2C while low. |
| TLMM 186 | **7 V boost enable** | Low → `Vin`(`0x0080`) = 3793 mV; high → 6998 mV |
| TLMM 97 | **Pen attach detect**, works | Pen removed → `1`; pen attached → `0` |
| TLMM 101 | The IC's INT (`OD2`, open drain, idle high) | High when idle, goes low while an interrupt is pending |
| TLMM 189 | Unknown | Stays high; does not follow the pen, the switch or the boost |

`gpio11` is therefore **`GPIO_ACTIVE_HIGH`**. Note that the commented-out node in
`sc8180x-xiaomi-book-12.4.dts` in this tree says `GPIO_ACTIVE_LOW` for both pins, which is
wrong, and references a `txra9530_int_default` pinctrl label that does not exist anywhere in
the tree.

### Chip state

| Register | Value | Meaning |
|---|---|---|
| `0x004D` System Operating Mode | `0x80` | **Back Powered** — powered by VRECT/VOUT, TX *not* enabled |
| `0x007E` TX Status | `0x00` | bit1 "TX ready (waiting for TX_EN command)" = 0 |
| `0x0034` Interrupt Enable (TX) | `0x21FF` | bits 0–8 + 13 enabled — the TX handshake cluster |
| `0x0080` Vin | 7044–7054 mV | Within the 7–9 V the TRx mode needs |
| `0x0082` Vrect | ~7032 mV | |
| `0x0084` Die temperature | 33 °C | Chip is running |
| `0x00E0` Ping interval | 11000 | default is 0x04B0 = 1200 |
| `0x00E2` Ping frequency | 500 | default 0x015F |
| `0x00E4` Ping duty | 156 | default 0x4C |
| `0x00EC` Low-voltage threshold | 500 | |
| `0x00E8` Over-voltage threshold | 412 | |
| `0x00F8/FA/FC` FOD thresholds | 800 / 65436 (= −100 mW) / 3700 | the manual documents 0xFF9C as −100 mW |
| `0x00D2` Q-factor | 30 | |

So the TX parameter block **is** configured; this is not an unconfigured chip.

---

## What does not work

### The TX command register is completely inert

The Renesas manual states for every bit of `TX System Command Register (0x007C, 16-bit)`:
*"AP writes '1' to corresponding bit to trigger a command one time. It is self-clean
register. After the command is handled by IC, IC clear the related bit."*

Measured on this chip:

```
bit0 TX EN          written -> still set after 100 ms
bit1 CLR Interrupt  written -> still set after 100 ms
bit2 TX DIS         written -> still set after 100 ms
bit3 TX BC          written -> still set after 100 ms
bit4 TX WD          written -> still set after 100 ms
```

Not one bit is ever cleared, i.e. **the chip never processes the command**, while normal
read/write registers on the same chip behave correctly (`0x0050` write→read returns exactly
what was written). So this is not a bus/protocol problem.

### Exhaustive sequencing on the two AP GPIOs

* Power-up in the order the reference design prescribes
  (both low → `gpio11` high → 50 ms → `gpio186` high) does produce an interrupt
  `0x0030 = 0x00002080`: bit7 *TX Initialization Done* + bit13 *Proprietary Packet Received*.
  The INT line goes low. But it clears by itself and MODE stays `0x80`.
  (bit13 is interesting — it suggests the coil was in fact driven at least briefly and the
  pen answered.)
* Six orderings of `gpio11`/`gpio186` transitions (including GP2-inverted hypotheses):
  no effect.
* The same, held for 15 s with per-second polling: no effect.
* A 20 ms-resolution poll for 5 s after writing `0x007C = 0x0001` at +100 ms:
  MODE never leaves `0x80`, i.e. not a "starts and falls back" case.

### The shipped Windows driver does not enable TX either

`wtSXBCharger.dll` is installed (DriverStore and `System32\drivers\UMDF\`, identical hash to
the copy in <https://github.com/Wapitiii/xiaomi-book-s-12-4-drivers>). It is a proper UMDF2
driver (exports `FxDriverEntryUm`, statically linked WUDFx2000 stubs) and registers a device
interface `\DosDevices\Global\WTSXBCHARGER`.

A complete scan of every `mov`/`movz`/`movk` immediate in its `.text` shows it only ever
touches register addresses `0x0028`, `0x0030`, `0x0034`, `0x003A`, `0x004D`, `0x0050`,
`0x0058`. Mapping those onto the Renesas TX register table:

| Address | Purpose |
|---|---|
| `0x004D` (read, 5 sites) | poll the operating mode |
| `0x0030`/`0x0034`/`0x0028` | read interrupt, enable interrupt, clear interrupt |
| `0x003A` | read the **pen's** battery (CSP) |
| `0x0050`/`0x0058` | send/receive proprietary packets |

**It never writes `0x007C` (nor `0x007E`/`0x007A`/the `0x3F0` command channel).** It is a
monitor/telemetry driver, not the enabler. Yet the pen charges under Windows — so whatever
enables TX there is outside this driver (EC/firmware).

The driver also accesses `\\.\RESOURCE_HUB\...`, i.e. it obtains its GPIO/I2C resources via
the Windows Resource Hub Proxy (it is user-mode, so it cannot touch the pins directly).

---

## Why we think this is not solvable from Linux alone

Renesas [RA9530/RA9520 Stylus Application AP Design Guide](https://www.renesas.com/en/document/mah/ra9530ra9520-stylus-application-ap-design-guide)
(R16UH0023EU0100) and [RA953-R Evaluation Kit Manual](https://www.renesas.com/en/document/mah/ra9530-evaluation-kit-manual)
(R16UH0022EU0200) describe two ways to start transmitting:

1. **`GP2/TX_EN` (chip pin 10) high at the moment VOUT is powered.** The eval manual's
   "TRx Mode Auto-Enable" section: *"The RA9530-R enters into TRx mode automatically if GP2
   level is high when Vout is powered by external power or AP."*
2. **Write `0x0001` to `0x007C`** while VOUT is powered (the eval kit's documented procedure).

Route 2 is inert on this chip, and route 1 cannot be driven: the ACPI `_CRS` for the device
exposes only the switch and the boost, and the DSDT contains no power resources or other
objects that could drive `GP2`.

So on this board `GP2` must be either tied low, or driven by the EC/firmware. Since the
Windows driver does not enable TX, the EC/firmware must be doing it — presumably triggered
by something that Linux has no interface for.

**The decisive experiment** (not yet done, would settle it): under Windows, disable
*"Wingtech SXB Charger-TXRA9530 Device"* in Device Manager and check whether the pen still
charges.

* If it still charges → the EC/firmware enables TX autonomously, and the enable condition is
  the thing to find.
* If it stops → the driver is the enabler after all, despite never touching `0x007C`, and
  the mechanism needs another look.

---

## Register map used above (TX side, from the Renesas documents)

| Register | Address | RW | Len | Notes |
|---|---|---|---|---|
| System Interrupt Clear (TX) | `0x0028` | RW | 4 | write back exactly the bits read from `0x0030` |
| System Interrupt (TX) | `0x0030` | R | 4 | bit7 TX Initialization Done, bit15 CSP, bit13 prop. packet, bit0 EPT |
| System Interrupt Enable (TX) | `0x0034` | RW | 4 | |
| Battery Charge Status | `0x003A` | R | 1 | the *pen's* battery, valid after a CSP interrupt |
| System Operating Mode | `0x004D` | R | 1 | `0x80` back powered, `0x04` TRx, `0x01`/`0x09` WPC, `0x00` AC missing |
| Proprietary Data-Out | `0x0050` | RW | 8 | |
| Proprietary Data-In | `0x0058` | RW | 8 | |
| Tx EPT Type | `0x007A` | R | 2 | POCP/OTP/FOD/LVP/OVP/OCP/timeouts |
| TX System Command | `0x007C` | RW | 2 | bit0 TX EN, bit1 CLR INT, bit2 TX DIS, bit3 TX BC, bit4 TX WD |
| TX Status | `0x007E` | R | 1 | bit1 TX ready, bit0 digital ping, bit3 transfer |
| Vin | `0x0080` | R | 2 | mV |
| Vrect | `0x0082` | R | 2 | mV |
| Die temperature | `0x0084` | R | 2 | °C |
| Ping interval | `0x00E0` | RW | 2 | ms, default 0x04B0 |
| Ping frequency | `0x00E2` | RW | 2 | frequency = 60 MHz / N |
| Ping duty | `0x00E4` | RW | 1 | |
| OV / LV thresholds | `0x00E8` / `0x00EC` | RW | 2 | mV |
| FOD thresholds | `0x00F8` / `0x00FA` / `0x00FC` | RW | 2 | mW, signed |
| TX commands must be ≥3–5 ms apart; the AP should clear interrupts *before* acting on events | | | | |

Interrupt clear sequence (design guide §5.1.1):

```
m = read(0x0030)
write(0x0028, m)          # exactly the bits read
write(0x007C, 0x0002)     # CLR Interrupt
verify 0x0030 == 0 and the INT pin is high
```

---

## Fixes worth making in the DT regardless

1. `&i2c7` `clock-frequency` should be `400000`, not `1000000` (per the ACPI descriptor).
2. `gpio11` is `GPIO_ACTIVE_HIGH`; the commented-out node has `GPIO_ACTIVE_LOW`.
3. The commented-out node references `pinctrl-0 = <&txra9530_int_default>` — that label
   does not exist anywhere in the tree, so the node cannot simply be uncommented.
4. The interrupt for `gpio101` is declared `IRQ_TYPE_LEVEL_LOW`; the Renesas design guide
   recommends an **active falling edge** interrupt for the INT pin.

## Diagnostic scripts used

These are device-specific and were written for this board (they live next to this report):

| Script | Purpose |
|---|---|
| `verify-ra9530.sh` | read-only probe: chip id, mode, interrupts, EPT, rails, GPIO state |
| `ra9530-txparams.sh` | dump the whole TX parameter block |
| `ra9530-cmd-test.sh` | the decisive test: is `0x007C` self-clearing for any bit? |
| `ra9530-power-path.sh` | marker test proving `gpio11` resets the chip; `gpio186` vs `Vin` |
| `ra9530-irq-lines.sh` | identify the three interrupt lines (found the pen detect on 97) |
| `ra9530-tx-go.sh`, `ra9530-txen.sh`, `ra9530-txready.sh`, `ra9530-enable-sweep.sh`, `ra9530-slow-sweep.sh`, `ra9530-tx-fastpoll.sh` | the (negative) attempts to enable TX |
| `parse-regf.py` | minimal read-only Windows registry hive parser (used to read `Enum\ACPI\TXRA9530\1\LogConf`) |
