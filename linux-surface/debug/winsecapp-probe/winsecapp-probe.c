// SPDX-License-Identifier: GPL-2.0-only
/*
 * winsecapp-probe - ask this board's TZ which QSEE secure applications it has.
 *
 * The VPU on this machine (SC8180X) gets as far as a released, executing
 * firmware and then wedges the interconnect on the firmware's first outbound
 * access.  Every lever on the non-secure side has been tested and eliminated, so
 * what is left is the "share / unlock subsystem memory (XPU)" handover that the
 * Windows PIL performs.  The Windows binaries reference qcom.tz.winsecapp for
 * that, and reach TZ through the hypervisor's TreeSendIrp path.
 *
 * Linux has its own way to reach a TZ app by name - qcom_scm_qseecom_app_get_id()
 * is the same lookup qcom_qseecom_uefisecapp performs at boot on this very
 * machine, and QSEECOM is present here (qseecom version 0x1401001).  This module
 * only asks whether the apps exist:
 *
 *   qcom.tz.uefisecapp  control - it is in use on this board, so a failure here
 *                       means the lookup itself is not working;
 *   qcom.tz.winsecapp   the question - if TZ answers with an app id, the secure
 *                       world is reachable from Linux and what remains is only
 *                       the command protocol, which can be reverse engineered
 *                       from qcpil8180.sys / QcTrEE8180.sys offline.  If it
 *                       answers -ENOENT, the video unlock is not a plain QSEE
 *                       app on this TZ but a hypervisor/VTL1 component, and
 *                       nothing on the Linux side can reach it;
 *   qcom.tz.doesnotexist  negative control - it must fail, otherwise the call is
 *                       not reporting anything meaningful.
 *
 * A lookup issues no command to any app and has no side effects.  Load it with
 * insmod; it prints and then fails its own init on purpose, so it never stays
 * resident.  Build with:
 *
 *   make -C ../../../src/kernel M=$PWD modules
 */
#include <linux/firmware/qcom/qcom_scm.h>
#include <linux/module.h>

static const char *const secapps[] = {
	"qcom.tz.winsecapp",	/* the video share/unlock app, per the Windows binaries */
	"qcom.tz.mssecapp",
	"qcom.tz.tpm",
	"qcom.tz.uefisecapp",	/* control: in use on this board */
	"qcom.tz.doesnotexist",	/* control: must fail */
};

static int __init winsecapp_probe_init(void)
{
	unsigned int i;

	pr_info("winsecapp-probe: qcom_scm available: %d\n",
		qcom_scm_is_available());

	for (i = 0; i < ARRAY_SIZE(secapps); i++) {
		u32 app_id = 0;
		int ret = qcom_scm_qseecom_app_get_id(secapps[i], &app_id);

		pr_info("winsecapp-probe: %-22s ret=%3d app_id=%#x%s\n",
			secapps[i], ret, ret ? 0 : app_id,
			ret == -ENOENT ? "   (no such app / not loaded)" : "");
	}

	return -EINVAL;		/* one-shot: print, then refuse to stay loaded */
}
module_init(winsecapp_probe_init);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Probe which QSEE secure apps this board's TZ exposes");
