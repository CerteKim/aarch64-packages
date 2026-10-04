#!/bin/bash
# Deprecated: superseded by tools/probe-vdec-run.sh.
#
# The old flow installed the video PoC package and then refreshed /boot by hand.
# That is unsafe: those packages (pkgrel <= 6) do not ship the kernel image, so
# installing one replaces every module while /boot keeps the previous kernel.
# The kernel then rejects each module's BTF ("BPF: Invalid name" /
# "failed to validate module ... BTF") and services that depend on those
# modules, such as pd-mapper, fail.  That is what broke the -6 attempt.
#
# tools/probe-vdec-run.sh does the same job with a self-consistent package and
# verifies the result before you reboot.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "!! tools/install-vdec-poc.sh is deprecated; running the checked flow instead."
echo
exec "$REPO/tools/probe-vdec-run.sh" "$@"
