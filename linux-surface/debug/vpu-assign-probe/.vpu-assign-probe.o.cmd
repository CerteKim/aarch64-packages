savedcmd_vpu-assign-probe.o := gcc -Wp,-MMD,./.vpu-assign-probe.o.d -nostdinc -I/home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include -I/home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/generated -I/home/certe/aarch64-packages/linux-surface/src/kernel/include -I/home/certe/aarch64-packages/linux-surface/src/kernel/include -I/home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/uapi -I/home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/generated/uapi -I/home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi -I/home/certe/aarch64-packages/linux-surface/src/kernel/include/generated/uapi -include /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/compiler-version.h -include /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kconfig.h -include /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/compiler_types.h -D__KERNEL__ -mlittle-endian -DKASAN_SHADOW_SCALE_SHIFT= -std=gnu11 -fshort-wchar -funsigned-char -fno-common -fno-PIE -fno-strict-aliasing -mgeneral-regs-only -DCONFIG_CC_HAS_K_CONSTRAINT=1 -Wno-psabi -mabi=lp64 -fno-asynchronous-unwind-tables -fno-unwind-tables -mbranch-protection=pac-ret -Wa,-march=armv8.5-a -DARM64_ASM_ARCH='"armv8.5-a"' -DKASAN_SHADOW_SCALE_SHIFT= -fno-delete-null-pointer-checks -O2 -fno-allow-store-data-races -fstack-protector-strong -fno-omit-frame-pointer -fno-optimize-sibling-calls -fzero-init-padding-bits=all -fno-stack-clash-protection -fno-inline-functions-called-once -fmin-function-alignment=4 -fstrict-flex-arrays=3 -fno-strict-overflow -fno-stack-check -fconserve-stack -fno-builtin-wcslen -Wall -Wextra -Wundef -Werror=implicit-function-declaration -Werror=implicit-int -Werror=return-type -Werror=strict-prototypes -Wno-format-security -Wno-trigraphs -Wno-frame-address -Wno-address-of-packed-member -Wmissing-declarations -Wmissing-prototypes -Wframe-larger-than=1024 -Wno-main -Wno-dangling-pointer -Wvla-larger-than=1 -Wno-pointer-sign -Wcast-function-type -Wno-unterminated-string-initialization -Wno-array-bounds -Wno-stringop-overflow -Wno-alloc-size-larger-than -Wimplicit-fallthrough=5 -Werror=date-time -Werror=incompatible-pointer-types -Werror=designated-init -Wenum-conversion -Wunused -Wno-unused-but-set-variable -Wno-unused-const-variable -Wno-packed-not-aligned -Wno-format-overflow -Wno-format-truncation -Wno-stringop-truncation -Wno-override-init -Wno-missing-field-initializers -Wno-type-limits -Wno-shift-negative-value -Wno-maybe-uninitialized -Wno-sign-compare -Wno-unused-parameter -g -DGCC_PLUGINS -mstack-protector-guard=sysreg -mstack-protector-guard-reg=sp_el0 -mstack-protector-guard-offset=1504  -DMODULE  -DKBUILD_BASENAME='"vpu_assign_probe"' -DKBUILD_MODNAME='"vpu_assign_probe"' -D__KBUILD_MODNAME=kmod_vpu_assign_probe -c -o vpu-assign-probe.o vpu-assign-probe.c  

source_vpu-assign-probe.o := vpu-assign-probe.c

deps_vpu-assign-probe.o := \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/compiler-version.h \
    $(wildcard include/config/CC_VERSION_TEXT) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/generated/gcc-plugins.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kconfig.h \
    $(wildcard include/config/CPU_BIG_ENDIAN) \
    $(wildcard include/config/BOOGER) \
    $(wildcard include/config/FOO) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/compiler_types.h \
    $(wildcard include/config/DEBUG_INFO_BTF) \
    $(wildcard include/config/PAHOLE_HAS_BTF_TAG) \
    $(wildcard include/config/FUNCTION_ALIGNMENT) \
    $(wildcard include/config/CC_HAS_SANE_FUNCTION_ALIGNMENT) \
    $(wildcard include/config/X86_64) \
    $(wildcard include/config/ARM64) \
    $(wildcard include/config/LD_DEAD_CODE_DATA_ELIMINATION) \
    $(wildcard include/config/LTO_CLANG) \
    $(wildcard include/config/HAVE_ARCH_COMPILER_H) \
    $(wildcard include/config/CC_HAS_ASSUME) \
    $(wildcard include/config/CC_HAS_COUNTED_BY) \
    $(wildcard include/config/CC_HAS_MULTIDIMENSIONAL_NONSTRING) \
    $(wildcard include/config/UBSAN_INTEGER_WRAP) \
    $(wildcard include/config/CFI) \
    $(wildcard include/config/ARCH_USES_CFI_GENERIC_LLVM_PASS) \
    $(wildcard include/config/CC_HAS_ASM_INLINE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/compiler_attributes.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/compiler-gcc.h \
    $(wildcard include/config/ARCH_USE_BUILTIN_BSWAP) \
    $(wildcard include/config/SHADOW_CALL_STACK) \
    $(wildcard include/config/KCOV) \
    $(wildcard include/config/CC_HAS_TYPEOF_UNQUAL) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/compiler.h \
    $(wildcard include/config/ARM64_PTR_AUTH_KERNEL) \
    $(wildcard include/config/ARM64_PTR_AUTH) \
    $(wildcard include/config/BUILTIN_RETURN_ADDRESS_STRIPS_PAC) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/firmware/qcom/qcom_scm.h \
    $(wildcard include/config/QCOM_QSEECOM) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/err.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/compiler.h \
    $(wildcard include/config/TRACE_BRANCH_PROFILING) \
    $(wildcard include/config/PROFILE_ALL_BRANCHES) \
    $(wildcard include/config/OBJTOOL) \
    $(wildcard include/config/64BIT) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/rwonce.h \
    $(wildcard include/config/LTO) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/rwonce.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kasan-checks.h \
    $(wildcard include/config/KASAN_GENERIC) \
    $(wildcard include/config/KASAN_SW_TAGS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/types.h \
    $(wildcard include/config/HAVE_UID16) \
    $(wildcard include/config/UID16) \
    $(wildcard include/config/ARCH_DMA_ADDR_T_64BIT) \
    $(wildcard include/config/PHYS_ADDR_T_64BIT) \
    $(wildcard include/config/ARCH_32BIT_USTAT_F_TINODE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/generated/uapi/asm/types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/asm-generic/types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/int-ll64.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/asm-generic/int-ll64.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/uapi/asm/bitsperlong.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitsperlong.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/asm-generic/bitsperlong.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/posix_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/stddef.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/stddef.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/uapi/asm/posix_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/asm-generic/posix_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kcsan-checks.h \
    $(wildcard include/config/KCSAN) \
    $(wildcard include/config/KCSAN_WEAK_MEMORY) \
    $(wildcard include/config/KCSAN_IGNORE_ATOMICS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/generated/uapi/asm/errno.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/asm-generic/errno.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/asm-generic/errno-base.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/cpumask.h \
    $(wildcard include/config/FORCE_NR_CPUS) \
    $(wildcard include/config/HOTPLUG_CPU) \
    $(wildcard include/config/SMP) \
    $(wildcard include/config/DEBUG_PER_CPU_MAPS) \
    $(wildcard include/config/CPUMASK_OFFSTACK) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/cleanup.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/args.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kernel.h \
    $(wildcard include/config/PREEMPT_VOLUNTARY_BUILD) \
    $(wildcard include/config/PREEMPT_DYNAMIC) \
    $(wildcard include/config/HAVE_PREEMPT_DYNAMIC_CALL) \
    $(wildcard include/config/HAVE_PREEMPT_DYNAMIC_KEY) \
    $(wildcard include/config/PREEMPT_) \
    $(wildcard include/config/DEBUG_ATOMIC_SLEEP) \
    $(wildcard include/config/MMU) \
    $(wildcard include/config/PROVE_LOCKING) \
    $(wildcard include/config/TRACING) \
    $(wildcard include/config/DYNAMIC_FTRACE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/stdarg.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/align.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/vdso/align.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/vdso/const.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/const.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/array_size.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/limits.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/limits.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/vdso/limits.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/linkage.h \
    $(wildcard include/config/ARCH_USE_SYM_ANNOTATIONS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/stringify.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/export.h \
    $(wildcard include/config/MODVERSIONS) \
    $(wildcard include/config/GENDWARFKSYMS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/linkage.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/container_of.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/build_bug.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/bitops.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/bits.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/vdso/bits.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/bits.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/overflow.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/const.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/typecheck.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/kernel.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/sysinfo.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/generic-non-atomic.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/barrier.h \
    $(wildcard include/config/ARM64_PSEUDO_NMI) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/alternative-macros.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/cpucaps.h \
    $(wildcard include/config/ARM64_PAN) \
    $(wildcard include/config/ARM64_EPAN) \
    $(wildcard include/config/ARM64_SVE) \
    $(wildcard include/config/ARM64_SME) \
    $(wildcard include/config/ARM64_CNP) \
    $(wildcard include/config/ARM64_MTE) \
    $(wildcard include/config/ARM64_BTI) \
    $(wildcard include/config/ARM64_TLB_RANGE) \
    $(wildcard include/config/ARM64_POE) \
    $(wildcard include/config/ARM64_GCS) \
    $(wildcard include/config/ARM64_HAFT) \
    $(wildcard include/config/UNMAP_KERNEL_AT_EL0) \
    $(wildcard include/config/ARM64_ERRATUM_843419) \
    $(wildcard include/config/ARM64_ERRATUM_1742098) \
    $(wildcard include/config/ARM64_ERRATUM_2645198) \
    $(wildcard include/config/ARM64_ERRATUM_2658417) \
    $(wildcard include/config/CAVIUM_ERRATUM_23154) \
    $(wildcard include/config/NVIDIA_CARMEL_CNP_ERRATUM) \
    $(wildcard include/config/ARM64_WORKAROUND_REPEAT_TLBI) \
    $(wildcard include/config/ARM64_ERRATUM_3194386) \
    $(wildcard include/config/HW_PERF_EVENTS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/generated/asm/cpucap-defs.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/insn-def.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/brk-imm.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/barrier.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/bitops.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/builtin-__ffs.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/builtin-ffs.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/builtin-__fls.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/builtin-fls.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/ffz.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/fls64.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/sched.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/hweight.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/arch_hweight.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/const_hweight.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/atomic.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/atomic.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/atomic.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/cmpxchg.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/lse.h \
    $(wildcard include/config/ARM64_LSE_ATOMICS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/atomic_ll_sc.h \
    $(wildcard include/config/CC_HAS_K_CONSTRAINT) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/alternative.h \
    $(wildcard include/config/MODULES) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/init.h \
    $(wildcard include/config/MEMORY_HOTPLUG) \
    $(wildcard include/config/HAVE_ARCH_PREL32_RELOCATIONS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/atomic_lse.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/atomic/atomic-arch-fallback.h \
    $(wildcard include/config/GENERIC_ATOMIC64) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/atomic/atomic-long.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/atomic/atomic-instrumented.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/instrumented.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kmsan-checks.h \
    $(wildcard include/config/KMSAN) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/instrumented-atomic.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/lock.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/instrumented-lock.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/non-atomic.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/non-instrumented-non-atomic.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/le.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/uapi/asm/byteorder.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/byteorder/little_endian.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/byteorder/little_endian.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/swab.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/swab.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/generated/uapi/asm/swab.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/asm-generic/swab.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/byteorder/generic.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bitops/ext2-atomic-setbit.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/hex.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kstrtox.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/log2.h \
    $(wildcard include/config/ARCH_HAS_ILOG2_U32) \
    $(wildcard include/config/ARCH_HAS_ILOG2_U64) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/math.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/generated/asm/div64.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/div64.h \
    $(wildcard include/config/CC_OPTIMIZE_FOR_PERFORMANCE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/minmax.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/panic.h \
    $(wildcard include/config/PANIC_TIMEOUT) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/printk.h \
    $(wildcard include/config/MESSAGE_LOGLEVEL_DEFAULT) \
    $(wildcard include/config/CONSOLE_LOGLEVEL_DEFAULT) \
    $(wildcard include/config/CONSOLE_LOGLEVEL_QUIET) \
    $(wildcard include/config/EARLY_PRINTK) \
    $(wildcard include/config/PRINTK) \
    $(wildcard include/config/PRINTK_INDEX) \
    $(wildcard include/config/DYNAMIC_DEBUG) \
    $(wildcard include/config/DYNAMIC_DEBUG_CORE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kern_levels.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/ratelimit_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/param.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/uapi/asm/param.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/param.h \
    $(wildcard include/config/HZ) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/asm-generic/param.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/spinlock_types_raw.h \
    $(wildcard include/config/DEBUG_SPINLOCK) \
    $(wildcard include/config/DEBUG_LOCK_ALLOC) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/spinlock_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/qspinlock_types.h \
    $(wildcard include/config/NR_CPUS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/qrwlock_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/lockdep_types.h \
    $(wildcard include/config/PROVE_RAW_LOCK_NESTING) \
    $(wildcard include/config/LOCKDEP) \
    $(wildcard include/config/LOCK_STAT) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/once_lite.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/dynamic_debug.h \
    $(wildcard include/config/JUMP_LABEL) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/jump_label.h \
    $(wildcard include/config/HAVE_ARCH_JUMP_LABEL_RELATIVE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/jump_label.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/insn.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/sprintf.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/static_call_types.h \
    $(wildcard include/config/HAVE_STATIC_CALL) \
    $(wildcard include/config/HAVE_STATIC_CALL_INLINE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/instruction_pointer.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/util_macros.h \
    $(wildcard include/config/FOO_SUSPEND) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/wordpart.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/bitmap.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/errno.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/errno.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/find.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/string.h \
    $(wildcard include/config/BINARY_PRINTF) \
    $(wildcard include/config/FORTIFY_SOURCE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/string.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/string.h \
    $(wildcard include/config/ARCH_HAS_UACCESS_FLUSHCACHE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/bitmap-str.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/cpumask_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/threads.h \
    $(wildcard include/config/BASE_SMALL) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/bug.h \
    $(wildcard include/config/GENERIC_BUG) \
    $(wildcard include/config/BUG_ON_DATA_CORRUPTION) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/bug.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/asm-bug.h \
    $(wildcard include/config/DEBUG_BUGVERBOSE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/bug.h \
    $(wildcard include/config/BUG) \
    $(wildcard include/config/GENERIC_BUG_RELATIVE_POINTERS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/instrumentation.h \
    $(wildcard include/config/NOINSTR_VALIDATION) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/gfp_types.h \
    $(wildcard include/config/KASAN_HW_TAGS) \
    $(wildcard include/config/SLAB_OBJ_EXT) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/numa.h \
    $(wildcard include/config/NUMA_KEEP_MEMINFO) \
    $(wildcard include/config/NUMA) \
    $(wildcard include/config/HAVE_ARCH_NODE_DEV_GROUP) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/nodemask.h \
    $(wildcard include/config/HIGHMEM) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/nodemask_types.h \
    $(wildcard include/config/NODES_SHIFT) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/random.h \
    $(wildcard include/config/VMGENID) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/list.h \
    $(wildcard include/config/LIST_HARDENED) \
    $(wildcard include/config/DEBUG_LIST) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/poison.h \
    $(wildcard include/config/ILLEGAL_POINTER_VALUE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/random.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/ioctl.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/generated/uapi/asm/ioctl.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/ioctl.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/asm-generic/ioctl.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/irqnr.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/irqnr.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/dt-bindings/firmware/qcom,scm.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/module.h \
    $(wildcard include/config/SYSFS) \
    $(wildcard include/config/MODULES_TREE_LOOKUP) \
    $(wildcard include/config/LIVEPATCH) \
    $(wildcard include/config/STACKTRACE_BUILD_ID) \
    $(wildcard include/config/ARCH_USES_CFI_TRAPS) \
    $(wildcard include/config/MODULE_SIG) \
    $(wildcard include/config/KALLSYMS) \
    $(wildcard include/config/TRACEPOINTS) \
    $(wildcard include/config/TREE_SRCU) \
    $(wildcard include/config/BPF_EVENTS) \
    $(wildcard include/config/DEBUG_INFO_BTF_MODULES) \
    $(wildcard include/config/EVENT_TRACING) \
    $(wildcard include/config/KPROBES) \
    $(wildcard include/config/KUNIT) \
    $(wildcard include/config/MODULE_UNLOAD) \
    $(wildcard include/config/CONSTRUCTORS) \
    $(wildcard include/config/FUNCTION_ERROR_INJECTION) \
    $(wildcard include/config/MITIGATION_RETPOLINE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/stat.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/stat.h \
    $(wildcard include/config/COMPAT) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/generated/uapi/asm/stat.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/asm-generic/stat.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/time.h \
    $(wildcard include/config/POSIX_TIMERS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/cache.h \
    $(wildcard include/config/ARCH_HAS_CACHE_LINE_SIZE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/vdso/cache.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/cache.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kasan-enabled.h \
    $(wildcard include/config/ARCH_DEFER_KASAN) \
    $(wildcard include/config/KASAN) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/static_key.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/cputype.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/sysreg.h \
    $(wildcard include/config/BROKEN_GAS_INST) \
    $(wildcard include/config/ARM64_PA_BITS_52) \
    $(wildcard include/config/ARM64_4K_PAGES) \
    $(wildcard include/config/ARM64_16K_PAGES) \
    $(wildcard include/config/ARM64_64K_PAGES) \
    $(wildcard include/config/AMPERE_ERRATUM_AC04_CPU_23) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kasan-tags.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/gpr-num.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/generated/asm/sysreg-defs.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/bitfield.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/mte-def.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/math64.h \
    $(wildcard include/config/ARCH_SUPPORTS_INT128) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/vdso/math64.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/time64.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/vdso/time64.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/time.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/time_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/time32.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/timex.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/timex.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/timex.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/arch_timer.h \
    $(wildcard include/config/ARM_ARCH_TIMER_OOL_WORKAROUND) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/hwcap.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/uapi/asm/hwcap.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/cpufeature.h \
    $(wildcard include/config/ARM64_SW_TTBR0_PAN) \
    $(wildcard include/config/ARM64_DEBUG_PRIORITY_MASKING) \
    $(wildcard include/config/ARM64_BTI_KERNEL) \
    $(wildcard include/config/ARM64_PA_BITS) \
    $(wildcard include/config/ARM64_HW_AFDBM) \
    $(wildcard include/config/ARM64_AMU_EXTN) \
    $(wildcard include/config/ARM64_LPA2) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/percpu.h \
    $(wildcard include/config/RANDOM_KMALLOC_CACHES) \
    $(wildcard include/config/PAGE_SIZE_4KB) \
    $(wildcard include/config/NEED_PER_CPU_PAGE_FIRST_CHUNK) \
    $(wildcard include/config/HAVE_SETUP_PER_CPU_AREA) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/alloc_tag.h \
    $(wildcard include/config/MEM_ALLOC_PROFILING_DEBUG) \
    $(wildcard include/config/MEM_ALLOC_PROFILING) \
    $(wildcard include/config/ARCH_MODULE_NEEDS_WEAK_PER_CPU) \
    $(wildcard include/config/MEM_ALLOC_PROFILING_ENABLED_BY_DEFAULT) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/codetag.h \
    $(wildcard include/config/CODE_TAGGING) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/preempt.h \
    $(wildcard include/config/PREEMPT_RT) \
    $(wildcard include/config/PREEMPT_COUNT) \
    $(wildcard include/config/DEBUG_PREEMPT) \
    $(wildcard include/config/TRACE_PREEMPT_TOGGLE) \
    $(wildcard include/config/PREEMPTION) \
    $(wildcard include/config/PREEMPT_NOTIFIERS) \
    $(wildcard include/config/PREEMPT_NONE) \
    $(wildcard include/config/PREEMPT_VOLUNTARY) \
    $(wildcard include/config/PREEMPT) \
    $(wildcard include/config/PREEMPT_LAZY) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/preempt.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/thread_info.h \
    $(wildcard include/config/THREAD_INFO_IN_TASK) \
    $(wildcard include/config/GENERIC_ENTRY) \
    $(wildcard include/config/ARCH_HAS_PREEMPT_LAZY) \
    $(wildcard include/config/HAVE_ARCH_WITHIN_STACK_FRAMES) \
    $(wildcard include/config/SH) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/restart_block.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/current.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/thread_info.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/memory.h \
    $(wildcard include/config/ARM64_VA_BITS) \
    $(wildcard include/config/KASAN_SHADOW_OFFSET) \
    $(wildcard include/config/RANDOMIZE_BASE) \
    $(wildcard include/config/DEBUG_VIRTUAL) \
    $(wildcard include/config/EFI) \
    $(wildcard include/config/ARM_GIC_V3_ITS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/sizes.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/page-def.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/vdso/page.h \
    $(wildcard include/config/PAGE_SHIFT) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/mmdebug.h \
    $(wildcard include/config/DEBUG_VM) \
    $(wildcard include/config/DEBUG_VM_IRQSOFF) \
    $(wildcard include/config/DEBUG_VM_PGFLAGS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/boot.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/sections.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/sections.h \
    $(wildcard include/config/HAVE_FUNCTION_DESCRIPTORS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/memory_model.h \
    $(wildcard include/config/FLATMEM) \
    $(wildcard include/config/SPARSEMEM_VMEMMAP) \
    $(wildcard include/config/SPARSEMEM) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/pfn.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/stack_pointer.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/percpu.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/percpu.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/percpu-defs.h \
    $(wildcard include/config/DEBUG_FORCE_WEAK_PER_CPU) \
    $(wildcard include/config/AMD_MEM_ENCRYPT) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/smp.h \
    $(wildcard include/config/UP_LATE_INIT) \
    $(wildcard include/config/CSD_LOCK_WAIT_DEBUG) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/smp_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/llist.h \
    $(wildcard include/config/ARCH_HAVE_NMI_SAFE_CMPXCHG) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/smp.h \
    $(wildcard include/config/ARM64_ACPI_PARKING_PROTOCOL) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/irqflags.h \
    $(wildcard include/config/TRACE_IRQFLAGS) \
    $(wildcard include/config/IRQSOFF_TRACER) \
    $(wildcard include/config/PREEMPT_TRACER) \
    $(wildcard include/config/DEBUG_IRQFLAGS) \
    $(wildcard include/config/TRACE_IRQFLAGS_SUPPORT) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/irqflags_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/irqflags.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/ptrace.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/uapi/asm/ptrace.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/uapi/asm/sve_context.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/irqchip/arm-gic-v3-prio.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/stacktrace/frame.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/sched.h \
    $(wildcard include/config/VIRT_CPU_ACCOUNTING_NATIVE) \
    $(wildcard include/config/SCHED_INFO) \
    $(wildcard include/config/SCHEDSTATS) \
    $(wildcard include/config/SCHED_CORE) \
    $(wildcard include/config/FAIR_GROUP_SCHED) \
    $(wildcard include/config/RT_GROUP_SCHED) \
    $(wildcard include/config/RT_MUTEXES) \
    $(wildcard include/config/UCLAMP_TASK) \
    $(wildcard include/config/UCLAMP_BUCKETS_COUNT) \
    $(wildcard include/config/KMAP_LOCAL) \
    $(wildcard include/config/SCHED_CLASS_EXT) \
    $(wildcard include/config/CGROUP_SCHED) \
    $(wildcard include/config/CFS_BANDWIDTH) \
    $(wildcard include/config/BLK_DEV_IO_TRACE) \
    $(wildcard include/config/PREEMPT_RCU) \
    $(wildcard include/config/TASKS_RCU) \
    $(wildcard include/config/TASKS_TRACE_RCU) \
    $(wildcard include/config/MEMCG_V1) \
    $(wildcard include/config/LRU_GEN) \
    $(wildcard include/config/COMPAT_BRK) \
    $(wildcard include/config/CGROUPS) \
    $(wildcard include/config/BLK_CGROUP) \
    $(wildcard include/config/PSI) \
    $(wildcard include/config/PAGE_OWNER) \
    $(wildcard include/config/EVENTFD) \
    $(wildcard include/config/ARCH_HAS_CPU_PASID) \
    $(wildcard include/config/X86_BUS_LOCK_DETECT) \
    $(wildcard include/config/TASK_DELAY_ACCT) \
    $(wildcard include/config/STACKPROTECTOR) \
    $(wildcard include/config/ARCH_HAS_SCALED_CPUTIME) \
    $(wildcard include/config/VIRT_CPU_ACCOUNTING_GEN) \
    $(wildcard include/config/NO_HZ_FULL) \
    $(wildcard include/config/POSIX_CPUTIMERS) \
    $(wildcard include/config/POSIX_CPU_TIMERS_TASK_WORK) \
    $(wildcard include/config/KEYS) \
    $(wildcard include/config/SYSVIPC) \
    $(wildcard include/config/DETECT_HUNG_TASK) \
    $(wildcard include/config/IO_URING) \
    $(wildcard include/config/AUDIT) \
    $(wildcard include/config/AUDITSYSCALL) \
    $(wildcard include/config/DETECT_HUNG_TASK_BLOCKER) \
    $(wildcard include/config/UBSAN) \
    $(wildcard include/config/UBSAN_TRAP) \
    $(wildcard include/config/COMPACTION) \
    $(wildcard include/config/TASK_XACCT) \
    $(wildcard include/config/CPUSETS) \
    $(wildcard include/config/X86_CPU_RESCTRL) \
    $(wildcard include/config/FUTEX) \
    $(wildcard include/config/PERF_EVENTS) \
    $(wildcard include/config/NUMA_BALANCING) \
    $(wildcard include/config/RSEQ) \
    $(wildcard include/config/DEBUG_RSEQ) \
    $(wildcard include/config/SCHED_MM_CID) \
    $(wildcard include/config/FAULT_INJECTION) \
    $(wildcard include/config/LATENCYTOP) \
    $(wildcard include/config/FUNCTION_GRAPH_TRACER) \
    $(wildcard include/config/MEMCG) \
    $(wildcard include/config/UPROBES) \
    $(wildcard include/config/BCACHE) \
    $(wildcard include/config/VMAP_STACK) \
    $(wildcard include/config/SECURITY) \
    $(wildcard include/config/BPF_SYSCALL) \
    $(wildcard include/config/KSTACK_ERASE) \
    $(wildcard include/config/KSTACK_ERASE_METRICS) \
    $(wildcard include/config/X86_MCE) \
    $(wildcard include/config/KRETPROBES) \
    $(wildcard include/config/RETHOOK) \
    $(wildcard include/config/ARCH_HAS_PARANOID_L1D_FLUSH) \
    $(wildcard include/config/RV) \
    $(wildcard include/config/RV_PER_TASK_MONITORS) \
    $(wildcard include/config/USER_EVENTS) \
    $(wildcard include/config/UNWIND_USER) \
    $(wildcard include/config/SCHED_PROXY_EXEC) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/sched.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/processor.h \
    $(wildcard include/config/KUSER_HELPERS) \
    $(wildcard include/config/ARM64_FORCE_52BIT) \
    $(wildcard include/config/HAVE_HW_BREAKPOINT) \
    $(wildcard include/config/ARM64_TAGGED_ADDR_ABI) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/vdso/processor.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/vdso/processor.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/hw_breakpoint.h \
    $(wildcard include/config/CPU_PM) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/virt.h \
    $(wildcard include/config/KVM) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/kasan.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/mte-kasan.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/pgtable-types.h \
    $(wildcard include/config/PGTABLE_LEVELS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/pgtable-nop4d.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/pgtable-hwdef.h \
    $(wildcard include/config/ARM64_CONT_PTE_SHIFT) \
    $(wildcard include/config/ARM64_CONT_PMD_SHIFT) \
    $(wildcard include/config/ARM64_VA_BITS_52) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/pointer_auth.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/prctl.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/spectre.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/fpsimd.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/uapi/asm/sigcontext.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/pid_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/sem_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/shm.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/page.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/personality.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/personality.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/getorder.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/shmparam.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/shmparam.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kmsan_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/mutex_types.h \
    $(wildcard include/config/MUTEX_SPIN_ON_OWNER) \
    $(wildcard include/config/DEBUG_MUTEXES) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/osq_lock.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/spinlock_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/rwlock_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/plist_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/hrtimer_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/timerqueue_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/rbtree_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/timer_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/seccomp_types.h \
    $(wildcard include/config/SECCOMP) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/refcount_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/resource.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/resource.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/generated/uapi/asm/resource.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/resource.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/asm-generic/resource.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/latencytop.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/sched/prio.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/sched/types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/signal_types.h \
    $(wildcard include/config/OLD_SIGACTION) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/signal.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/signal.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/uapi/asm/signal.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/signal.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/asm-generic/signal.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/asm-generic/signal-defs.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/generated/uapi/asm/siginfo.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/asm-generic/siginfo.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/spinlock.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/bottom_half.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/lockdep.h \
    $(wildcard include/config/DEBUG_LOCKING_API_SELFTESTS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/generated/asm/mmiowb.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/mmiowb.h \
    $(wildcard include/config/MMIOWB) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/spinlock.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/generated/asm/qspinlock.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/qspinlock.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/generated/asm/qrwlock.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/qrwlock.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/rwlock.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/spinlock_api_smp.h \
    $(wildcard include/config/INLINE_SPIN_LOCK) \
    $(wildcard include/config/INLINE_SPIN_LOCK_BH) \
    $(wildcard include/config/INLINE_SPIN_LOCK_IRQ) \
    $(wildcard include/config/INLINE_SPIN_LOCK_IRQSAVE) \
    $(wildcard include/config/INLINE_SPIN_TRYLOCK) \
    $(wildcard include/config/INLINE_SPIN_TRYLOCK_BH) \
    $(wildcard include/config/UNINLINE_SPIN_UNLOCK) \
    $(wildcard include/config/INLINE_SPIN_UNLOCK_BH) \
    $(wildcard include/config/INLINE_SPIN_UNLOCK_IRQ) \
    $(wildcard include/config/INLINE_SPIN_UNLOCK_IRQRESTORE) \
    $(wildcard include/config/GENERIC_LOCKBREAK) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/rwlock_api_smp.h \
    $(wildcard include/config/INLINE_READ_LOCK) \
    $(wildcard include/config/INLINE_WRITE_LOCK) \
    $(wildcard include/config/INLINE_READ_LOCK_BH) \
    $(wildcard include/config/INLINE_WRITE_LOCK_BH) \
    $(wildcard include/config/INLINE_READ_LOCK_IRQ) \
    $(wildcard include/config/INLINE_WRITE_LOCK_IRQ) \
    $(wildcard include/config/INLINE_READ_LOCK_IRQSAVE) \
    $(wildcard include/config/INLINE_WRITE_LOCK_IRQSAVE) \
    $(wildcard include/config/INLINE_READ_TRYLOCK) \
    $(wildcard include/config/INLINE_WRITE_TRYLOCK) \
    $(wildcard include/config/INLINE_READ_UNLOCK) \
    $(wildcard include/config/INLINE_WRITE_UNLOCK) \
    $(wildcard include/config/INLINE_READ_UNLOCK_BH) \
    $(wildcard include/config/INLINE_WRITE_UNLOCK_BH) \
    $(wildcard include/config/INLINE_READ_UNLOCK_IRQ) \
    $(wildcard include/config/INLINE_WRITE_UNLOCK_IRQ) \
    $(wildcard include/config/INLINE_READ_UNLOCK_IRQRESTORE) \
    $(wildcard include/config/INLINE_WRITE_UNLOCK_IRQRESTORE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/syscall_user_dispatch_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/mm_types_task.h \
    $(wildcard include/config/ARCH_WANT_BATCHED_UNMAP_TLB_FLUSH) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/tlbbatch.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/netdevice_xmit.h \
    $(wildcard include/config/NET_EGRESS) \
    $(wildcard include/config/NET_ACT_MIRRED) \
    $(wildcard include/config/NF_DUP_NETDEV) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/task_io_accounting.h \
    $(wildcard include/config/TASK_IO_ACCOUNTING) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/posix-timers_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/rseq.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/seqlock_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kcsan.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/rv.h \
    $(wildcard include/config/RV_LTL_MONITOR) \
    $(wildcard include/config/RV_REACTORS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/uidgid_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/tracepoint-defs.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/unwind_deferred_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/generated/asm/kmap_size.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/kmap_size.h \
    $(wildcard include/config/DEBUG_KMAP_LOCAL) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/generated/rq-offsets.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/sched/ext.h \
    $(wildcard include/config/EXT_GROUP_SCHED) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/clocksource/arm_arch_timer.h \
    $(wildcard include/config/ARM_ARCH_TIMER) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/timecounter.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/timex.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/vdso/time32.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/vdso/time.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/compat.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/compat.h \
    $(wildcard include/config/COMPAT_FOR_U64_ALIGNMENT) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/sched/task_stack.h \
    $(wildcard include/config/STACK_GROWSUP) \
    $(wildcard include/config/DEBUG_STACK_USAGE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/magic.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/refcount.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kasan.h \
    $(wildcard include/config/KASAN_STACK) \
    $(wildcard include/config/KASAN_VMALLOC) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/stat.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/uidgid.h \
    $(wildcard include/config/MULTIUSER) \
    $(wildcard include/config/USER_NS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/highuid.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/buildid.h \
    $(wildcard include/config/VMCORE_INFO) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kmod.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/umh.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/gfp.h \
    $(wildcard include/config/ZONE_DMA) \
    $(wildcard include/config/ZONE_DMA32) \
    $(wildcard include/config/ZONE_DEVICE) \
    $(wildcard include/config/CONTIG_ALLOC) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/mmzone.h \
    $(wildcard include/config/ARCH_FORCE_MAX_ORDER) \
    $(wildcard include/config/PAGE_BLOCK_MAX_ORDER) \
    $(wildcard include/config/CMA) \
    $(wildcard include/config/MEMORY_ISOLATION) \
    $(wildcard include/config/ZSMALLOC) \
    $(wildcard include/config/UNACCEPTED_MEMORY) \
    $(wildcard include/config/IOMMU_SUPPORT) \
    $(wildcard include/config/SWAP) \
    $(wildcard include/config/HUGETLB_PAGE) \
    $(wildcard include/config/TRANSPARENT_HUGEPAGE) \
    $(wildcard include/config/LRU_GEN_STATS) \
    $(wildcard include/config/LRU_GEN_WALKS_MMU) \
    $(wildcard include/config/MEMORY_FAILURE) \
    $(wildcard include/config/PAGE_EXTENSION) \
    $(wildcard include/config/DEFERRED_STRUCT_PAGE_INIT) \
    $(wildcard include/config/HAVE_MEMORYLESS_NODES) \
    $(wildcard include/config/SPARSEMEM_EXTREME) \
    $(wildcard include/config/SPARSEMEM_VMEMMAP_PREINIT) \
    $(wildcard include/config/HAVE_ARCH_PFN_VALID) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/list_nulls.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/wait.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/seqlock.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/mutex.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/debug_locks.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/pageblock-flags.h \
    $(wildcard include/config/HUGETLB_PAGE_SIZE_VARIABLE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/page-flags-layout.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/generated/bounds.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/sparsemem.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/pgtable-prot.h \
    $(wildcard include/config/HAVE_ARCH_USERFAULTFD_WP) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/rsi.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/rsi_cmds.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/arm-smccc.h \
    $(wildcard include/config/HAVE_ARM_SMCCC) \
    $(wildcard include/config/ARM) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/uuid.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/rsi_smc.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/mm_types.h \
    $(wildcard include/config/HAVE_ALIGNED_STRUCT_PAGE) \
    $(wildcard include/config/HUGETLB_PMD_PAGE_TABLE_SHARING) \
    $(wildcard include/config/SLAB_FREELIST_HARDENED) \
    $(wildcard include/config/USERFAULTFD) \
    $(wildcard include/config/ANON_VMA_NAME) \
    $(wildcard include/config/PER_VMA_LOCK) \
    $(wildcard include/config/HAVE_ARCH_COMPAT_MMAP_BASES) \
    $(wildcard include/config/MEMBARRIER) \
    $(wildcard include/config/FUTEX_PRIVATE_HASH) \
    $(wildcard include/config/ARCH_HAS_ELF_CORE_EFLAGS) \
    $(wildcard include/config/AIO) \
    $(wildcard include/config/MMU_NOTIFIER) \
    $(wildcard include/config/SPLIT_PMD_PTLOCKS) \
    $(wildcard include/config/IOMMU_MM_DATA) \
    $(wildcard include/config/KSM) \
    $(wildcard include/config/MM_ID) \
    $(wildcard include/config/CORE_DUMP_DEFAULT_ELF_HEADERS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/auxvec.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/auxvec.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/uapi/asm/auxvec.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kref.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/rbtree.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/rcupdate.h \
    $(wildcard include/config/TINY_RCU) \
    $(wildcard include/config/RCU_STRICT_GRACE_PERIOD) \
    $(wildcard include/config/RCU_LAZY) \
    $(wildcard include/config/RCU_STALL_COMMON) \
    $(wildcard include/config/VIRT_XFER_TO_GUEST_WORK) \
    $(wildcard include/config/RCU_NOCB_CPU) \
    $(wildcard include/config/TASKS_RCU_GENERIC) \
    $(wildcard include/config/TASKS_RUDE_RCU) \
    $(wildcard include/config/TREE_RCU) \
    $(wildcard include/config/DEBUG_OBJECTS_RCU_HEAD) \
    $(wildcard include/config/PROVE_RCU) \
    $(wildcard include/config/ARCH_WEAK_RELEASE_ACQUIRE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/context_tracking_irq.h \
    $(wildcard include/config/CONTEXT_TRACKING_IDLE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/rcutree.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/maple_tree.h \
    $(wildcard include/config/MAPLE_RCU_DISABLED) \
    $(wildcard include/config/DEBUG_MAPLE_TREE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/rwsem.h \
    $(wildcard include/config/RWSEM_SPIN_ON_OWNER) \
    $(wildcard include/config/DEBUG_RWSEMS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/completion.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/swait.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/uprobes.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/timer.h \
    $(wildcard include/config/DEBUG_OBJECTS_TIMERS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/ktime.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/jiffies.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/vdso/jiffies.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/generated/timeconst.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/vdso/ktime.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/timekeeping.h \
    $(wildcard include/config/POSIX_AUX_CLOCKS) \
    $(wildcard include/config/GENERIC_CMOS_UPDATE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/clocksource_ids.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/debugobjects.h \
    $(wildcard include/config/DEBUG_OBJECTS) \
    $(wildcard include/config/DEBUG_OBJECTS_FREE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/uprobes.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/debug-monitors.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/esr.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/probes.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/workqueue.h \
    $(wildcard include/config/DEBUG_OBJECTS_WORK) \
    $(wildcard include/config/FREEZER) \
    $(wildcard include/config/WQ_WATCHDOG) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/workqueue_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/percpu_counter.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/mmu.h \
    $(wildcard include/config/ARM64_E0PD) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/page-flags.h \
    $(wildcard include/config/PAGE_IDLE_FLAG) \
    $(wildcard include/config/ARCH_USES_PG_ARCH_2) \
    $(wildcard include/config/ARCH_USES_PG_ARCH_3) \
    $(wildcard include/config/MIGRATION) \
    $(wildcard include/config/HUGETLB_PAGE_OPTIMIZE_VMEMMAP) \
    $(wildcard include/config/DEBUG_KMAP_LOCAL_FORCE_MAP) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/local_lock.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/local_lock_internal.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/zswap.h \
    $(wildcard include/config/ZSWAP) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/memory_hotplug.h \
    $(wildcard include/config/ARCH_HAS_ADD_PAGES) \
    $(wildcard include/config/MEMORY_HOTREMOVE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/notifier.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/srcu.h \
    $(wildcard include/config/TINY_SRCU) \
    $(wildcard include/config/NEED_SRCU_NMI_SAFE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/rcu_segcblist.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/srcutree.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/rcu_node_tree.h \
    $(wildcard include/config/RCU_FANOUT) \
    $(wildcard include/config/RCU_FANOUT_LEAF) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/topology.h \
    $(wildcard include/config/USE_PERCPU_NUMA_NODE_ID) \
    $(wildcard include/config/SCHED_SMT) \
    $(wildcard include/config/GENERIC_ARCH_TOPOLOGY) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/arch_topology.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/topology.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/topology.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/sysctl.h \
    $(wildcard include/config/SYSCTL) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/sysctl.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/elf.h \
    $(wildcard include/config/ARCH_HAVE_EXTRA_ELF_NOTES) \
    $(wildcard include/config/ARCH_USE_GNU_PROPERTY) \
    $(wildcard include/config/ARCH_HAVE_ELF_PROT) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/elf.h \
    $(wildcard include/config/COMPAT_VDSO) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/generated/asm/user.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/user.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/elf.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/elf-em.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/fs.h \
    $(wildcard include/config/FANOTIFY_ACCESS_PERMISSIONS) \
    $(wildcard include/config/READ_ONLY_THP_FOR_FS) \
    $(wildcard include/config/FS_POSIX_ACL) \
    $(wildcard include/config/CGROUP_WRITEBACK) \
    $(wildcard include/config/IMA) \
    $(wildcard include/config/FILE_LOCKING) \
    $(wildcard include/config/FSNOTIFY) \
    $(wildcard include/config/EPOLL) \
    $(wildcard include/config/UNICODE) \
    $(wildcard include/config/FS_ENCRYPTION) \
    $(wildcard include/config/FS_VERITY) \
    $(wildcard include/config/QUOTA) \
    $(wildcard include/config/FS_DAX) \
    $(wildcard include/config/BLOCK) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/vfsdebug.h \
    $(wildcard include/config/DEBUG_VFS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/wait_bit.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kdev_t.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/kdev_t.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/dcache.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/rculist.h \
    $(wildcard include/config/PROVE_RCU_LIST) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/rculist_bl.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/list_bl.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/bit_spinlock.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/lockref.h \
    $(wildcard include/config/ARCH_USE_CMPXCHG_LOCKREF) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/stringhash.h \
    $(wildcard include/config/DCACHE_WORD_ACCESS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/hash.h \
    $(wildcard include/config/HAVE_ARCH_HASH) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/path.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/list_lru.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/shrinker.h \
    $(wildcard include/config/SHRINKER_DEBUG) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/xarray.h \
    $(wildcard include/config/XARRAY_MULTI) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/sched/mm.h \
    $(wildcard include/config/MMU_LAZY_TLB_REFCOUNT) \
    $(wildcard include/config/ARCH_HAS_MEMBARRIER_CALLBACKS) \
    $(wildcard include/config/ARCH_HAS_SYNC_CORE_BEFORE_USERMODE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/sync_core.h \
    $(wildcard include/config/ARCH_HAS_PREPARE_SYNC_CORE_CMD) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/sched/coredump.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/radix-tree.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/pid.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/capability.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/capability.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/semaphore.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/fcntl.h \
    $(wildcard include/config/ARCH_32BIT_OFF_T) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/fcntl.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/uapi/asm/fcntl.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/asm-generic/fcntl.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/openat2.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/migrate_mode.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/percpu-rwsem.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/rcuwait.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/sched/signal.h \
    $(wildcard include/config/SCHED_AUTOGROUP) \
    $(wildcard include/config/BSD_PROCESS_ACCT) \
    $(wildcard include/config/TASKSTATS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/signal.h \
    $(wildcard include/config/DYNAMIC_SIGFRAME) \
    $(wildcard include/config/PROC_FS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/sched/jobctl.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/sched/task.h \
    $(wildcard include/config/HAVE_EXIT_THREAD) \
    $(wildcard include/config/ARCH_WANTS_DYNAMIC_TASK_STRUCT) \
    $(wildcard include/config/HAVE_ARCH_THREAD_STRUCT_WHITELIST) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/uaccess.h \
    $(wildcard include/config/ARCH_HAS_SUBPAGE_FAULTS) \
    $(wildcard include/config/HARDENED_USERCOPY) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/fault-inject-usercopy.h \
    $(wildcard include/config/FAULT_INJECTION_USERCOPY) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/nospec.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/ucopysize.h \
    $(wildcard include/config/HARDENED_USERCOPY_DEFAULT_ON) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/uaccess.h \
    $(wildcard include/config/CC_HAS_ASM_GOTO_OUTPUT) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/kernel-pgtable.h \
    $(wildcard include/config/RELOCATABLE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/asm-extable.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/mte.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/extable.h \
    $(wildcard include/config/BPF_JIT) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/access_ok.h \
    $(wildcard include/config/ALTERNATE_USER_ADDRESS_SPACE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/cred.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/key.h \
    $(wildcard include/config/KEY_NOTIFICATIONS) \
    $(wildcard include/config/NET) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/assoc_array.h \
    $(wildcard include/config/ASSOCIATIVE_ARRAY) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/sched/user.h \
    $(wildcard include/config/VFIO_PCI_ZDEV_KVM) \
    $(wildcard include/config/IOMMUFD) \
    $(wildcard include/config/WATCH_QUEUE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/ratelimit.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/posix-timers.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/alarmtimer.h \
    $(wildcard include/config/RTC_CLASS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/hrtimer.h \
    $(wildcard include/config/HIGH_RES_TIMERS) \
    $(wildcard include/config/TIME_LOW_RES) \
    $(wildcard include/config/TIMERFD) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/hrtimer_defs.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/timerqueue.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/rcuref.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/rcu_sync.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/delayed_call.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/errseq.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/ioprio.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/sched/rt.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/iocontext.h \
    $(wildcard include/config/BLK_ICQ) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/ioprio.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/fs_types.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/mount.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/mnt_idmapping.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/slab.h \
    $(wildcard include/config/FAILSLAB) \
    $(wildcard include/config/KFENCE) \
    $(wildcard include/config/SLUB_TINY) \
    $(wildcard include/config/SLUB_DEBUG) \
    $(wildcard include/config/SLAB_BUCKETS) \
    $(wildcard include/config/KVFREE_RCU_BATCHED) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/percpu-refcount.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/rw_hint.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/file_ref.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/unicode.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/fs.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/quota.h \
    $(wildcard include/config/QUOTA_NETLINK_INTERFACE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/dqblk_xfs.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/dqblk_v1.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/dqblk_v2.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/dqblk_qtree.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/projid.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/uapi/linux/quota.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kobject.h \
    $(wildcard include/config/UEVENT_HELPER) \
    $(wildcard include/config/DEBUG_KOBJECT_RELEASE) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/sysfs.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kernfs.h \
    $(wildcard include/config/KERNFS) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/idr.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/kobject_ns.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/moduleparam.h \
    $(wildcard include/config/ALPHA) \
    $(wildcard include/config/PPC64) \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/rbtree_latch.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/linux/error-injection.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/error-injection.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/arch/arm64/include/asm/module.h \
  /home/certe/aarch64-packages/linux-surface/src/kernel/include/asm-generic/module.h \
    $(wildcard include/config/HAVE_MOD_ARCH_SPECIFIC) \

vpu-assign-probe.o: $(deps_vpu-assign-probe.o)

$(deps_vpu-assign-probe.o):
