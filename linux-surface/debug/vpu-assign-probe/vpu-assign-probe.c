// SPDX-License-Identifier: GPL-2.0-only
/*
 * vpu-assign-probe - retry MP/0x16 with the VMID/permission vocabulary that the
 * Windows PIL actually uses.
 *
 * Every assign this project sent from Linux used the CP_* VMIDs (0x8/0x9/0xa/
 * 0xb/0xd) that the Android/vendor trees talk about, and TrustZone answered
 * -EINVAL every time, at both plausible points in the sequence.  Reverse
 * engineering of qcpil8180.sys and QcSkExt8180.exe then showed that neither
 * binary contains any of those values.  What they do use:
 *
 *   qcpil8180.sys, hardcoded selector rules (fn 0x14000da10):
 *     selector == 0 : src {0x3}          -> dst [{0x0f, code 6}, {0x3, code 6}]
 *     selector != 0 : src {0x0f, 0x3}    -> dst [{0x3, code 7}]
 *   QcSkExt8180.exe, the trustlet's video memory sequence
 *     (pil_video_mem_assign): HLOS -> 0x0e (HLOS_UNMAPPED) -> 0x0c (video) -> HLOS
 *   permission *codes* -> *bits*: 1->0x10, 4->0x02, 5->0x20, 6->0x04, 7->0x40
 *
 * mainline's qcom_scm_assign_mem() takes src as a bitmap of VMIDs and dst as
 * (vmid, perm) pairs, which is exactly the flat 6-argument form qcpil emits, so
 * each tuple below is one SCM call.  This is a pure probe: each call either
 * succeeds or comes back -EINVAL, and the region is the firmware carve-out,
 * which is a reserved-memory carve-out present from boot.
 *
 * Load with insmod; it prints and then fails its own init so it never stays
 * resident:
 *
 *   insmod vpu-assign-probe.ko
 *   dmesg | tail -12
 */
#include <linux/firmware/qcom/qcom_scm.h>
#include <linux/module.h>

static unsigned long long fw_phys = 0x8bd80000;
module_param(fw_phys, ullong, 0444);
MODULE_PARM_DESC(fw_phys, "physical base of the region to assign");

static unsigned int fw_size = 0x500000;
module_param(fw_size, uint, 0444);
MODULE_PARM_DESC(fw_size, "size of the region to assign");

struct assign_combo {
	const char *name;
	u64 src_bits;
	struct qcom_scm_vmperm dst[3];
	unsigned int ndst;
};

static const struct assign_combo combos[] = {
	{ "qcpil sel0   src{3} -> 0f:6,3:6",
	  BIT(0x3), { { 0x0f, 0x04 }, { 0x03, 0x04 } }, 2 },
	{ "qcpil sel!=0 src{0f,3} -> 3:7",
	  BIT(0x0f) | BIT(0x03), { { 0x03, 0x40 } }, 1 },
	{ "trustlet    src{3} -> 0e:7 (to UNMAPPED)",
	  BIT(0x3), { { 0x0e, 0x40 } }, 1 },
	{ "trustlet    src{0e} -> 0c:7 (to video VM)",
	  BIT(0x0e), { { 0x0c, 0x40 } }, 1 },
	{ "trustlet    src{0e} -> 3:7 (back to HLOS)",
	  BIT(0x0e), { { 0x03, 0x40 } }, 1 },
	{ "old guess    src{3} -> 3:RW,0b:RW",
	  BIT(0x3), { { 0x03, QCOM_SCM_PERM_RW }, { 0x0b, QCOM_SCM_PERM_RW } }, 2 },
};

static int __init vpu_assign_probe_init(void)
{
	unsigned int i;

	pr_info("vpu-assign-probe: region %#llx size %#x, qcom_scm available %d\n",
		fw_phys, fw_size, qcom_scm_is_available());

	for (i = 0; i < ARRAY_SIZE(combos); i++) {
		u64 owners = combos[i].src_bits;
		int ret;

		ret = qcom_scm_assign_mem(fw_phys, fw_size, &owners,
					  combos[i].dst, combos[i].ndst);
		pr_info("vpu-assign-probe: %-38s ret=%3d owners=%#llx\n",
			combos[i].name, ret, owners);
	}

	return -EINVAL;		/* one-shot: print, then refuse to stay loaded */
}
module_init(vpu_assign_probe_init);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Retry MP/0x16 with the Windows PIL's VMID/permission vocabulary");
