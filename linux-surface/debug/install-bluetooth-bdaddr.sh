#!/bin/bash
# Superseded: the supported installer now lives in tools/, because the systemd
# workaround it installs is in use again (it used to silently do nothing, see
# systemd/bluetooth-bdaddr.sh).  This shim only exists so the old debug/ path
# does not reinstall the broken version.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$here/../tools/install-bluetooth-bdaddr.sh" "$@"
