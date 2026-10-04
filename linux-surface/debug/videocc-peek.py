#!/usr/bin/env python3
"""Peek at / touch the SC8180X video clock-controller registers.  Run as root.

The instrumented iris module showed the probe dies on the *first* VPU register
write (reg_base + 0xB0088), with every clock and both power domains the driver
knows about already enabled.  That is what an unclocked register interface looks
like, and this SoC's VIDEOCC has one interface clock the driver never enables:
VIDEO_CC_IRIS_AHB_CLK (branch enable bit 0 at 0xab008f4).

    sudo python3 tools/videocc-peek.py dump        # read-only
    sudo python3 tools/videocc-peek.py enable-ahb  # set bit 0 @ 0xab008f4

Then, with `sudo dmesg -w` running in another terminal:

    sudo modprobe qcom-iris

If the IRIS-TRACE output now gets past "power_on: preset regs (first VPU write)",
the AHB clock was the missing piece.  A power-cycle undoes the manual bit.
"""
import mmap
import os
import sys

VIDEOCC = 0x0AB00000
GCC = 0x00100000

REGS = [
    ("videocc", 0x7F0, "iris_clk_src CMD_RCGR  (root enable + src sel)"),
    ("videocc", 0x7F4, "iris_clk_src CFG_RCGR"),
    ("videocc", 0x810, "MVSC_BCR              (block reset)"),
    ("videocc", 0x814, "VENUS_GDSC gdscr      (driver calls this 'venus')"),
    ("videocc", 0x850, "mvsc_core_clk branch"),
    ("videocc", 0x870, "MVS0_BCR              (block reset)"),
    ("videocc", 0x874, "VCODEC0_GDSC gdscr    (driver calls this 'vcodec0')"),
    ("videocc", 0x890, "mvs0_core_clk branch"),
    ("videocc", 0x8B4, "VCODEC1_GDSC gdscr"),
    ("videocc", 0x8F0, "VIDEO_CC_INTERFACE_BCR <-- AHB2AXI bridge reset"),
    ("videocc", 0x8F4, "iris_ahb_clk branch   <-- VPU register interface"),
    ("gcc", 0xB024, "gcc_video_axi0_clk branch (driver: 'iface')"),
]

AHB = ("videocc", 0x8F4)


def read32(base, off):
    page = base + (off & ~0xFFF)
    fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
    mm = mmap.mmap(fd, 0x1000, mmap.MAP_SHARED,
                   mmap.PROT_READ | mmap.PROT_WRITE, offset=page)
    try:
        return int.from_bytes(mm[off & 0xFFF:(off & 0xFFF) + 4], "little")
    finally:
        mm.close()
        os.close(fd)


def write32(base, off, val):
    page = base + (off & ~0xFFF)
    fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
    mm = mmap.mmap(fd, 0x1000, mmap.MAP_SHARED,
                   mmap.PROT_READ | mmap.PROT_WRITE, offset=page)
    try:
        mm[off & 0xFFF:(off & 0xFFF) + 4] = val.to_bytes(4, "little")
        # mmap.flush() is not supported on /dev/mem mappings (EINVAL); reading
        # the value back is enough to push the store out and see if it stuck.
        _ = int.from_bytes(mm[off & 0xFFF:(off & 0xFFF) + 4], "little")
    finally:
        mm.close()
        os.close(fd)


def dump():
    for which, off, name in REGS:
        base = VIDEOCC if which == "videocc" else GCC
        try:
            val = read32(base, off)
        except OSError as exc:
            val = f"read failed: {exc}"
            print(f"{which} +0x{off:04x}  {name:<58} {val}")
            continue
        bits = []
        if off == AHB[1]:
            bits.append(f"branch_enable(bit0)={'1' if val & 1 else '0'}")
            bits.append(f"clk_off(bit1)={'1' if val & 2 else '0'}")
        if off in (0x814, 0x874, 0x8B4):
            bits.append("SW_COLLAPSE(bit0)=1 (OFF)" if val & 1 else "SW_COLLAPSE(bit0)=0")
            bits.append("PWR_ON(bit31)=1 (POWERED)" if val & 0x80000000 else "PWR_ON(bit31)=0 (NOT POWERED)")
        if off == 0x8F0:
            bits.append("reset_asserted(bit0)=1  <-- BRIDGE HELD IN RESET"
                        if val & 1 else "reset deasserted (bit0=0)")
        print(f"{which} +0x{off:04x}  {name:<58} 0x{val:08x}  {' '.join(bits)}")


def enable_ahb():
    which, off = AHB
    base = VIDEOCC if which == "videocc" else GCC
    before = read32(base, off)
    write32(base, off, before | 1)
    after = read32(base, off)
    print(f"iris_ahb branch before 0x{before:08x} after 0x{after:08x}")
    if after & 1:
        print("bit 0 set: the AHB branch is now enabled (power-cycle undoes it)")
    else:
        print("bit 0 did NOT stick - branch is hardware gated, this test cannot work")
    print("now run: sudo modprobe qcom-iris")


def release_interface():
    """Deassert VIDEO_CC_INTERFACE_BCR (0x8f0 bit 0): assert = set, deassert = clear."""
    base, off = VIDEOCC, 0x8F0
    before = read32(base, off)
    write32(base, off, before & ~1)
    after = read32(base, off)
    print(f"VIDEO_CC_INTERFACE_BCR before 0x{before:08x} after 0x{after:08x}")
    if after & 1:
        print("bit 0 still set: the interface bridge stays in reset (hw controlled?)")
    else:
        print("interface bridge reset deasserted")
    print("now run: sudo modprobe qcom-iris")


def release_bric():
    """Do both halves of the BRIC page: deassert the interface reset (0x8f0)
    and enable the AHB clock branch (0x8f4).  Intended to be run inside the
    driver's power-on window."""
    before_r = read32(VIDEOCC, 0x8F0)
    write32(VIDEOCC, 0x8F0, before_r & ~1)
    after_r = read32(VIDEOCC, 0x8F0)
    before_c = read32(VIDEOCC, 0x8F4)
    write32(VIDEOCC, 0x8F4, before_c | 1)
    after_c = read32(VIDEOCC, 0x8F4)
    print(f"INTERFACE_BCR 0x8f0: 0x{before_r:08x} -> 0x{after_r:08x}")
    print(f"iris_ahb_clk  0x8f4: 0x{before_c:08x} -> 0x{after_c:08x}")


def gdsc_test():
    """Try to power VENUS_GDSC with a direct write and see whether it sticks.

    This distinguishes "writes to the videocc never reach the hardware" from
    "the driver's genpd/clock path is a no-op".  It only touches the GDSC
    register - no VPU access, so it cannot hang the bus.
    """
    import time
    base, off = VIDEOCC, 0x814
    before = read32(base, off)
    write32(base, off, before & ~1)          # clear SW_COLLAPSE -> power up
    after_write = read32(base, off)

    powered = None
    for _ in range(20):
        val = read32(base, off)
        if val & 0x80000000:                 # PWR_ON
            powered = val
            break
        time.sleep(0.05)

    write32(base, off, before)               # restore the state we found
    restored = read32(base, off)

    print(f"VENUS_GDSC before       0x{before:08x}")
    if after_write & 1:
        print(f"after clearing bit0     0x{after_write:08x}   <- bit0 still set: WRITE IGNORED")
    else:
        print(f"after clearing bit0     0x{after_write:08x}   <- write landed")
    print(f"PWR_ON                  0x{powered:08x}  (domain powered up!)"
          if powered else "PWR_ON                  never came up within 1 s (domain stayed off)")
    print(f"restored                0x{restored:08x}")


def powerup():
    """Power the video block by hand and leave it on: uncollapse the three
    GDSCs and set the branch enable bits.  Used to test whether the VPU answers
    once it is genuinely powered+clocked, i.e. whether the driver's framework
    based power/clock path is the only thing broken.
    """
    print("== GDSCs (clear SW_COLLAPSE) ==")
    for off, name in ((0x814, "VENUS_GDSC"), (0x874, "VCODEC0_GDSC"), (0x8B4, "VCODEC1_GDSC")):
        before = read32(VIDEOCC, off)
        write32(VIDEOCC, off, before & ~1)
        import time
        val = read32(VIDEOCC, off)
        for _ in range(20):
            if val & 0x80000000:
                break
            time.sleep(0.05)
            val = read32(VIDEOCC, off)
        print(f"  {name:14} 0x{before:08x} -> 0x{val:08x}  "
              f"{'POWERED' if val & 0x80000000 else 'still off'}")

    print("== branch clocks (set enable bit 0) ==")
    for base, off, name in ((VIDEOCC, 0x850, "mvsc_core_clk"),
                            (VIDEOCC, 0x890, "mvs0_core_clk"),
                            (VIDEOCC, 0x7F0, "iris_clk_src root_en"),
                            (VIDEOCC, 0x8F4, "iris_ahb_clk"),
                            (GCC, 0xB024, "gcc_video_axi0_clk"),
                            (GCC, 0xB02C, "gcc_video_axic_clk"),
                            (GCC, 0xB028, "gcc_video_axi1_clk")):
        before = read32(base, off)
        write32(base, off, before | 1)
        after = read32(base, off)
        print(f"  {name:20} 0x{before:08x} -> 0x{after:08x}")

    print("state left ON (power-cycle to undo)")


def ahb_on():
    """Enable the VPU AHB/register-interface clock the way the vendor PIL does.

    The downstream PIL node enables VIDEO_CC_XO_CLK, VIDEO_CC_MVSC_CORE_CLK and
    VIDEO_CC_IRIS_AHB_CLK before the SCM auth.  The iris driver has no "ahb"
    clock at all, and this branch stays off (0x8f4 = 0) because its parent RCG
    (iris_clk_src, 0x7f0) is not root-enabled either.  Turn the RCG on first,
    then the branch, and report whether both stick.
    """
    import time
    print("== iris_clk_src RCG (0x7f0) root enable ==")
    before = read32(VIDEOCC, 0x7F0)
    write32(VIDEOCC, 0x7F0, before | 1)
    time.sleep(0.05)
    after = read32(VIDEOCC, 0x7F0)
    print(f"  0x7f0: 0x{before:08x} -> 0x{after:08x}  "
          f"{'root enabled' if after & 1 else 'STILL OFF'}")

    print("== iris_ahb_clk branch (0x8f4) ==")
    before = read32(VIDEOCC, 0x8F4)
    write32(VIDEOCC, 0x8F4, before | 1)
    val = read32(VIDEOCC, 0x8F4)
    for _ in range(20):
        if not (val & 2):
            break
        time.sleep(0.05)
        val = read32(VIDEOCC, 0x8F4)
    print(f"  0x8f4: 0x{before:08x} -> 0x{val:08x}  "
          f"enable={'set' if val & 1 else 'NOT SET'} "
          f"clk_off(bit1)={1 if val & 2 else 0} "
          f"{'RUNNING' if (val & 1) and not (val & 2) else 'not running'}")


def main():
    if os.geteuid() != 0:
        sys.exit("run me with sudo")
    cmd = sys.argv[1] if len(sys.argv) > 1 else "dump"
    if cmd == "dump":
        dump()
    elif cmd == "enable-ahb":
        enable_ahb()
    elif cmd == "release-interface":
        release_interface()
    elif cmd == "release-bric":
        release_bric()
    elif cmd == "gdsc-test":
        gdsc_test()
    elif cmd == "powerup":
        powerup()
    elif cmd == "ahb-on":
        ahb_on()
    else:
        sys.exit(f"unknown command {cmd!r}: use dump, enable-ahb, release-interface, release-bric, gdsc-test, powerup or ahb-on")


if __name__ == "__main__":
    main()
