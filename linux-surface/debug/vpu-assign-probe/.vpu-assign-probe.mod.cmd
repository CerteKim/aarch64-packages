savedcmd_vpu-assign-probe.mod := printf '%s\n'   vpu-assign-probe.o | awk '!x[$$0]++ { print("./"$$0) }' > vpu-assign-probe.mod
