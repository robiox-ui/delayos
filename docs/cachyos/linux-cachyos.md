# CachyOS `linux-cachyos` repository: full optimization audit

Source: `https://github.com/CachyOS/linux-cachyos`, HEAD tarball from codeload, downloaded 2026-11-25.
All 49 files in the tarball were covered (see "Files read" at the end). The repository was never executed. It was only read and diffed with local helper scripts.

Verbatim copies of the default variant files are in `docs/cachyos/linux-cachyos-src/`:
`PKGBUILD` (31799 bytes), `config` (297558 bytes), `.SRCINFO` (3089 bytes). SHA-256 hashes match the originals.
The default variant directory has **no** `.install`, `.preset`, or other helper files. Only these three files exist.

---

## 0. Key facts to understand first

1. **Patches are not in this repo.** The kernel source is a **pre-patched tarball** from CachyOS's kernel fork:
   `https://github.com/CachyOS/linux/releases/download/cachyos-7.3.6-1/cachyos-7.3.6-1.tar.gz` (+ `.asc`, signed by Eric Naim `E18447AC260021D31F3FF6C4C8A2A4774B8B63C4` or Peter Jung `E8B9AA39F054E30E8290D492C3C4820857F654FE`).
   The README says the fork "merges topic branches on top of upstream stable". The listed branches are `amd-isp4`, `bbr3`, `cachy`, `cgroup-vram`, `drm-fair`, `fixes`, `hdmi`, `lenovo-wmi`, `mglru`, `preempt-ipi`, `sched-cluster`, `snd-codecs`, `t2`, `vesa-dsc-bpp`, `vmalloc-free`. (The README text says "Linux 7.1" and "fifteen". The PKGBUILD is at 7.3.6, so the README is out of date.)
   Only **extra** patches (alternative schedulers, hardened, RT, handheld, nvidia/r8125 fixes, dkms-clang) come from `https://raw.githubusercontent.com/cachyos/kernel-patches/master/${_major}/...`.
   **To copy CachyOS exactly, use their tarball (or the `CachyOS/linux` git tag `cachyos-7.3.6-1`). A vanilla kernel.org tarball plus this PKGBUILD will not work**, because symbols such as `CACHY`, `SCHED_BORE`, `CC_OPTIMIZE_FOR_PERFORMANCE_O3`, `MZEN4`, `HZ_500/600/750`, `MQ_IOSCHED_ADIOS`, `TCP_CONG_BBR3`, `SCHED_POC_SELECTOR`, `PCI_ACS_OVERRIDE`, `V4L2_LOOPBACK`, `VHBA`, and `MIN_BASE_SLICE_NS` only exist in the fork.
2. **The shipped `config` is a neutral base, not the final config.** In the file, `# CONFIG_CACHY is not set`, `# CONFIG_SCHED_BORE is not set`, `CONFIG_HZ_300=y`, `CONFIG_GENERIC_CPU=y` / `CONFIG_X86_64_VERSION=1`, `CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y` (-O2), and `CONFIG_LTO_NONE=y`. **`prepare()` in the PKGBUILD changes these** through `scripts/config`. The effective result is in section 2.4.
3. **Scheduler label vs. reality.** `pkgdesc` and the README call the default kernel "EEVDF". However, the default `_cpusched=cachyos` runs `scripts/config -e SCHED_BORE` (`cachyos|bore|hardened) scripts/config -e SCHED_BORE;;`). The `config` file already contains the `SCHED_BORE` Kconfig symbol, so BORE is part of the fork tarball. **As written, the default package enables BORE.** (`linux-cachyos-eevdf` is the variant that runs `eevdf) ;;`, which does not touch the scheduler.) `-deckify`, `-lts`, and `-rc` also default to `_cpusched=cachyos`.
4. Version state at HEAD: main/bore/eevdf/bmq/server/deckify/rt-bore/eac = **7.3.6-1**; hardened = **7.2.11** (pkgrel 3); lts = **6.18.65**; rc = **7.4-rc4**. NVIDIA open = **620.73.04**, NVIDIA 580xx legacy = **580.196.07**, ZFS = `cachyos/zfs` commit `fb48c76e17d3e0092fbba430a9eec1960e1b9961`.

---

## 1. Kernel variants: what differs

Every variant directory contains exactly `PKGBUILD`, `config`, and `.SRCINFO`. The PKGBUILDs were diffed line by line (LCS diff) and the configs were diffed key by key.

**Configs:** `linux-cachyos`, `-bmq`, `-bore`, `-deckify`, `-eac`, `-eevdf`, `-rt-bore`, and `-server` share a **byte-identical** `config` (SHA-256 prefix `32B3C2004BF8640A`). Only `-hardened`, `-lts`, and `-rc` have their own configs. Every other variant difference comes from PKGBUILD variables and extra patches.

### 1.1 Default values per variant

| Variant | `_cpusched` | `_use_llvm_lto` | `_HZ_ticks` | `_preempt` | `_hugepage` | `_cachy_config` | Kernel | Extra patches (from kernel-patches) | Other |
|---|---|---|---|---|---|---|---|---|---|
| **linux-cachyos** (default) | `cachyos` (= `-e SCHED_BORE`) | `thin` | 1000 | full | always | yes | 7.3.6 | `misc/dkms-clang.patch` (LTO only) | Has AutoFDO/Propeller knobs. `_use_gcc_suffix=yes`, `_use_lto_suffix=no`. Provides/replaces `linux-cachyos-lto`. |
| linux-cachyos-bore | `bore` | `none` (GCC) | 1000 | full | always | yes | 7.3.6 | `sched/0001-bore-cachy.patch` | pkgsuffix `cachyos-bore`. `cachyos` case also pulls the bore patch here. No AutoFDO/Propeller knobs. |
| linux-cachyos-eevdf | `eevdf` | `none` | 1000 | full | always | yes | 7.3.6 | none | No scheduler `scripts/config` change (pure EEVDF). |
| linux-cachyos-bmq | `bmq` | `none` | 1000 | full | always | yes | 7.3.6 | `sched/0001-prjc-cachy.patch` | `-e SCHED_ALT -e SCHED_BMQ`. SCX is not compatible with this variant. |
| linux-cachyos-rt-bore | `rt-bore` | `none` | 1000 | (skipped for RT) | always | yes | 7.3.6 | `sched/0001-bore-cachy.patch`, `misc/0001-rt-i915.patch` | `-e SCHED_BORE -e PREEMPT_RT`. ZFS is forcibly unset. |
| linux-cachyos-server | `eevdf` | `none` | **300** | **lazy** | **madvise** | **no** | 7.3.6 | none | Server tuning: no CACHY sauce. |
| linux-cachyos-deckify | `cachyos` (BORE) | `none` | 1000 | full | always | yes | 7.3.6 | `misc/0001-acpi-call.patch`, `misc/0001-handheld.patch` (always in `source`) | Extra handheld `scripts/config` block (see 1.2). |
| linux-cachyos-hardened | `hardened` | `none` | 1000 | full | always | yes | **7.2.11** | `sched/0001-bore-cachy.patch`, `misc/0001-hardened.patch` (from `.../master/7.2/`) | Separate config. Adds `scripts/config -e USER_NS`. QR panic only for GCC builds. |
| linux-cachyos-lts | `cachyos` | `none` | 1000 | full | always | yes | **6.18.65** | none | Separate config. Preempt choices are full/lazy/voluntary/none with `PREEMPT_DYNAMIC` handling. Adds `-e USER_NS`. QR panic only for GCC. |
| linux-cachyos-rc | `cachyos` | `thin` | 1000 | full | always | yes | **7.4-rc4** | `misc/dkms-clang.patch` | Separate config. Has AutoFDO/Propeller knobs. **No** QR-panic `scripts/config` block (the rc config already sets `DRM_PANIC_SCREEN="qr_code"`). nvidia-580xx gets `0003-Fix-build-on-Linux-7.4.patch`. |
| linux-cachyos-eac (not in README) | `cachyos` | `thin` | 1000 | full | always | yes | 7.3.6 | dkms-clang, nvidia patches, `misc/r8125/0001-Remove-rtltool.patch` | Easy Anti-Cheat Linux v2. Defaults `_build_zfs/_build_nvidia_open/_build_nvidia_580xx/_build_r8125=yes`. Requires sbsign key/cert (see 1.3). |

Package naming: main/rc/lts/eac/server/deckify use fixed suffixes (for example `cachyos-rc-lto`). bore/eevdf/bmq/rt-bore/hardened use `cachyos-${_cpusched}[-lto|-gcc]`. On GCC-default variants `_use_lto_suffix=yes` and `_use_gcc_suffix=no`, so GCC builds are named plainly (for example `linux-cachyos-bore`). An LTO build of those is `linux-cachyos-bore-lto`. On main/rc/lts/eac it is the opposite: `_use_gcc_suffix=yes`, so a GCC build becomes `linux-cachyos-gcc`.

### 1.2 deckify extra block (verbatim)
```bash
    echo "Enabling handheld configs"
    scripts/config \
        -d RCU_LAZY_DEFAULT_OFF \
        -e AMD_PRIVATE_COLOR \
        -m SENSORS_STEAMDECK \
        -m MFD_STEAMDECK \
        -m SND_SOC_AW87XXX \
        -m HID_ASUS_ALLY \
        -m HID_LENOVO_GO \
        -m HID_LENOVO_GO_S \
        -m HID_MSI_CLAW \
        -m ZOTAC_ZONE_HID \
        -m LEDS_STEAMDECK \
        -m LEDS_VALVE \
        -e ACPI_CALL \
        -m ZOTAC_ZONE_PLATFORM \
        -m EXTCON_STEAMDECK \
        -m HID_MSI
```
Note `-d RCU_LAZY_DEFAULT_OFF`: lazy RCU is **on by default** on handhelds to save battery. The base config sets `CONFIG_RCU_LAZY_DEFAULT_OFF=y`.

### 1.3 eac (Easy Anti-Cheat Linux v2) extras
- New knobs: `_eac:=yes`, `_eac_sbsign_key:=` (PEM path or `pkcs11:` URI, using the libp11 provider `--provider default --provider pkcs11prov`), `_eac_sbsign_cert:=`. The build dies if `_eac=yes` and a key or cert is missing. The kernel image is signed with `sbsign` in `package()`.
- Required cmdline (from comment): `lockdown=integrity lsm=landlock,lockdown,yama,integrity,bpf iommu.passthrough=0 intel_iommu=on module.sig_enforce=1 sysctl.kernel.kexec_load_disabled=1`.
- `scripts/config -e SECURITY_LOCKDOWN_LSM -e SECURITY_LOCKDOWN_LSM_EARLY -d LOCK_DOWN_KERNEL_FORCE_NONE -e LOCK_DOWN_KERNEL_FORCE_INTEGRITY -d LOCK_DOWN_KERNEL_FORCE_CONFIDENTIALITY -e BPF_LSM`
- `scripts/config -e MODULE_SIG -e MODULE_SIG_ALL -e MODULE_SIG_FORCE -d INTEGRITY_MACHINE_KEYRING -e SECONDARY_TRUSTED_KEYRING_SIGNED_BY_BUILTIN`
- `scripts/config -d HIBERNATION`, `scripts/config -d ACPI_TABLE_UPGRADE`
- `scripts/config -e INTEL_IOMMU_DEFAULT_ON -d IOMMU_DEFAULT_PASSTHROUGH -d PCI_ACS_OVERRIDE`
- Writes an SBAT csv and runs `scripts/config --set-str EFI_SBAT_FILE "${srcdir}/sbat.csv"`. Checks that `CONFIG_LSM` contains `bpf`. After `make config` it re-verifies that the options above survived.
- r8125 is pinned to commit `7ae458895545f023fc27d8f3d1385e21b6b581cf` with rtltool removed. Out-of-tree modules have to be built in this PKGBUILD because DKMS modules will not load.
- It does not have the `provides/replaces linux-cachyos-lto` lines.

### 1.4 hardened config vs. base config (notable)
The config is pre-baked: `CACHY=y`, `SCHED_BORE=y`, `HZ_1000=y`/`HZ=1000`, `MIN_BASE_SLICE_NS 1600000 -> 2000000`, `RCU_LAZY_DEFAULT_OFF=n`, `DEFAULT_HOSTNAME="archlinux"`.
Security changes:
- Off: `RUST`, `KEXEC*`, `HIBERNATION`, `X86_X32_ABI`, `MODIFY_LDT_SYSCALL`, `USERFAULTFD`, `PROC_KCORE`, `DEVMEM`, `DEVPORT`, `SLAB_MERGE_DEFAULT`, many `*_DEBUGFS`.
- Changed: `LEGACY_VSYSCALL_NONE`, `ARCH_MMAP_RND_BITS 32` / `ARCH_MMAP_RND_COMPAT_BITS 16`, THP shmem/tmpfs `NEVER`, `MQ_IOSCHED_ADIOS=m`.
- On: `GCC_PLUGINS` (+ `GCC_PLUGIN_LATENT_ENTROPY`, `GCC_PLUGIN_STACKLEAK`), `KMALLOC_PARTITION_CACHES`, `IOMMU_DEFAULT_DMA_STRICT`, `KSTACK_ERASE`, `INIT_ON_FREE_DEFAULT_ON`, `BUG_ON_DATA_CORRUPTION`, `PANIC_ON_OOPS`, `DEBUG_LIST/SG/NOTIFIERS/VM/VIRTUAL/PREEMPT`, `DEBUG_FS_ALLOW_NONE`, `PROC_MEM_FORCE_PTRACE`, `SECURITY_PERF_EVENTS_RESTRICT`, `SECURITY_TIOCSTI_RESTRICT`, `USER_NS_UNPRIVILEGED=n`, `RESET_ATTACK_MITIGATION`, `CMDLINE_BOOL`.
This variant is not suitable for gaming.

### 1.5 lts config vs. base (notable)
- `MIN_BASE_SLICE_NS=2000000`, `COMPACT_UNEVICTABLE_DEFAULT=0`, `ANDROID_BINDER_IPC=y`.
- No `SCHED_CACHE`, `SCHED_POC_SELECTOR`, `EXT_SUB_SCHED`, or THP shmem/tmpfs ADVISE symbols (older kernel).
- Contains `SCHED_ALT/BMQ/PDS=n`, `PREEMPT_NONE/VOLUNTARY=n`, `SLUB_CPU_PARTIAL=y`, `READ_ONLY_THP_FOR_FS=y`.

### 1.6 rc config vs. base (notable)
- Has `DRM_PANIC_SCREEN="qr_code"` with QR URL/version 40 baked in.
- New 7.4 symbols: `TCP_CONG_ROCCET=m`, `CPU_IDLE_GOV_NAP=y`, `PREFERRED_CPU=y`, `RCU_DEFER=y`, `CC_OPT_FALIGN_JUMPS="-falign-jumps=1"`, `CC_OPT_FALIGN_LOOPS="-falign-loops=1"`, `CHECK_WX=y`.
- No `SCHED_POC_SELECTOR` and no `PER_VMA_LOCK` symbol in the rc config at this snapshot.
- Everything else matches the base config.

---

## 2. Main `linux-cachyos` PKGBUILD in detail

### 2.1 Every build variable and its default (verbatim names)

| Variable | Default | Meaning |
|---|---|---|
| `_cachy_config` | `yes` | `scripts/config -e CACHY` ("Cachy Sauce", a fork Kconfig bundle of scheduler/MM tweaks) |
| `_cpusched` | `cachyos` | One of `bore`, `bmq`, `hardened`, `cachyos`, `eevdf`, `rt`, `rt-bore` |
| `_makenconfig` | `no` | Runs `make nconfig` |
| `_makexconfig` | `no` | Runs `make xconfig` |
| `_localmodcfg` | `no` | Runs `make LSMOD=$_localmodcfg_path localmodconfig` |
| `_localmodcfg_path` | `$XDG_DATA_HOME/modprobed-db/modprobed.db` | Path to the module list |
| `_use_current` | `no` | Uses `/proc/config.gz` of the running kernel. Note: this happens *after* all `scripts/config` edits, so it overwrites them. |
| `_cc_harder` | `yes` | -O3 |
| `_per_gov` | `no` | Makes performance the default cpufreq governor |
| `_tcp_bbr3` | `no` | Makes BBR(v3) the default congestion control and FQ the default qdisc |
| `_HZ_ticks` | `1000` | Valid values: 100, 250, 300, 500, 600, 750, 1000 |
| `_tickrate` | `full` | `periodic`, `idle`, or `full` |
| `_preempt` | `full` | `full` or `lazy` (comment says lazy "doesn't seem to perform well") |
| `_hugepage` | `always` | `always` or `madvise` |
| `_processor_opt` | *(empty)* -> native | `native`, `zen4`, `generic`, `generic_v1..v4` (upper-cased internally) |
| `_use_llvm_lto` | `thin` | `none`, `thin`, `thin-dist`, `full` |
| `_use_lto_suffix` | `no` | Adds `-lto` to pkgbase |
| `_use_gcc_suffix` | `yes` | Adds `-gcc` to pkgbase when not LTO |
| `_use_kcfi` | `no` | `scripts/config -e CFI` |
| `_build_zfs` | `no` | Builds ZFS from `git+https://github.com/cachyos/zfs.git#commit=fb48c76e...` (unset for rt/rt-bore) |
| `_build_nvidia_open` | `no` | NVIDIA open modules 620.73.04 (Turing+) |
| `_build_nvidia_580xx` | `no` | Closed 580.196.07 legacy module (Maxwell/Pascal/Volta) |
| `_build_r8125` | `no` | `git+https://github.com/aravance/r8125.git`. Blacklists r8169 through `/usr/lib/modprobe.d/<pkg>.conf`. |
| `_build_debug` | `no` | Adds a `-dbg` package with an unstripped vmlinux in `/usr/src/debug/<pkgbase>` |
| `_autofdo` | `no` | `scripts/config -e AUTOFDO_CLANG` |
| `_autofdo_profile_name` | *(empty)* | Profile file. Adds `CLANG_AUTOFDO_PROFILE=${srcdir}/<name>` to `BUILD_FLAGS`. |
| `_propeller` | `no` | `scripts/config -e PROPELLER_CLANG` |
| `_propeller_profiles` | `no` | Adds `propeller_cc_profile.txt` and `propeller_ld_profile.txt` to `source` and `CLANG_PROPELLER_PROFILE_PREFIX=${srcdir}/propeller` |

**Not present in current HEAD** (searched across the whole repo): `_mq_deadline_disable`, `_kyber_disable`, `_lru_config`, `_vma_config`, `_damon`, `_numa`, `_use_gcc_lto`, `_use_auto_optimization`, `_nr_cpus`, `_mglru`. These were older PKGBUILD knobs and have been removed. MGLRU, per-VMA locks, DAMON, NUMA, and all I/O schedulers are now simply on in `config` (section 4). The repo-build scripts still `sed` `_use_auto_optimization:=yes -> no`, but this is a no-op leftover.

### 2.2 Exactly what `prepare()` runs, in order

```bash
cp ../config .config
```
1. **CPU / -march**
   - `_processor_opt` empty (default): `scripts/config -d GENERIC_CPU -d MZEN4 -e X86_NATIVE_CPU`. **This means `-march=native` by default for local AUR builds.**
   - `GENERIC_V1..V4`: `scripts/config -e GENERIC_CPU -d MZEN4 -d X86_NATIVE_CPU --set-val X86_64_VERSION <n>`
   - `ZEN4`: `scripts/config -d GENERIC_CPU -e MZEN4 -d X86_NATIVE_CPU`
   - `NATIVE`: `scripts/config -d GENERIC_CPU -d MZEN4 -e X86_NATIVE_CPU`
   - Any other value (for example `GENERIC`, used by `script.sh`) matches no case, so the config's `GENERIC_CPU=y` / `X86_64_VERSION=1` stays. That is how the plain `x86-64` repo kernel is built.
2. `_cachy_config=yes`: `scripts/config -e CACHY`
3. **Scheduler**
   - `cachyos|bore|hardened`: `scripts/config -e SCHED_BORE`
   - `bmq`: `scripts/config -e SCHED_ALT -e SCHED_BMQ`
   - `eevdf`: nothing
   - `rt`: `scripts/config -e PREEMPT_RT`
   - `rt-bore`: `scripts/config -e SCHED_BORE -e PREEMPT_RT`
4. `_use_kcfi=yes`: `scripts/config -e CFI`
5. **LTO**: `thin` runs `-e LTO_CLANG_THIN`, `thin-dist` runs `-e LTO_CLANG_THIN_DIST`, `full` runs `-e LTO_CLANG_FULL`, `none` runs `-e LTO_NONE`.
   For any LTO mode, `BUILD_FLAGS=(CC=clang LD=ld.lld LLVM=1 LLVM_IAS=1)`, makedepends gain `clang llvm lld 'pahole>=1:1.32-2'`, and `misc/dkms-clang.patch` is applied.
6. **QR panic** (always on main):
   `scripts/config --set-str DRM_PANIC_SCREEN qr_code -e DRM_PANIC_SCREEN_QR_CODE --set-str DRM_PANIC_SCREEN_QR_CODE_URL https://panic.archlinux.org/panic_report# --set-val CONFIG_DRM_PANIC_SCREEN_QR_VERSION 40`
7. **HZ**
   - 100/250/500/600/750/1000: `scripts/config -d HZ_300 -e "HZ_${_HZ_ticks}" --set-val HZ "${_HZ_ticks}"`
   - 300: `scripts/config -e HZ_300 --set-val HZ 300`
8. `_per_gov=yes`: `scripts/config -d CPU_FREQ_DEFAULT_GOV_SCHEDUTIL -e CPU_FREQ_DEFAULT_GOV_PERFORMANCE`
9. **Tick type**
   - `periodic`: `-d NO_HZ_IDLE -d NO_HZ_FULL -d NO_HZ -d NO_HZ_COMMON -e HZ_PERIODIC`
   - `idle`: `-d HZ_PERIODIC -d NO_HZ_FULL -e NO_HZ_IDLE -e NO_HZ -e NO_HZ_COMMON`
   - `full` (default): `-d HZ_PERIODIC -d NO_HZ_IDLE -d CONTEXT_TRACKING_FORCE -e NO_HZ_FULL_NODEF -e NO_HZ_FULL -e NO_HZ -e NO_HZ_COMMON -e CONTEXT_TRACKING`
   - (`NO_HZ_FULL_NODEF` is not in the shipped base config. It only survives if the fork's Kconfig defines it.)
10. **Preempt** (skipped for rt/rt-bore): `full` runs `-e PREEMPT -d PREEMPT_LAZY`, `lazy` runs `-d PREEMPT -e PREEMPT_LAZY`. `PREEMPT_DYNAMIC=y` stays from the config, so `preempt=` on the cmdline can still switch modes.
11. `_cc_harder=yes`: `scripts/config -d CC_OPTIMIZE_FOR_PERFORMANCE -e CC_OPTIMIZE_FOR_PERFORMANCE_O3`
12. **CI only** (`$CI` or `$GITHUB_RUN_ID` set): `-d CC_OPTIMIZE_FOR_PERFORMANCE_O3 -e CC_OPTIMIZE_FOR_SIZE -d DEBUG_KERNEL -e DEBUG_INFO_REDUCED`. bpftool `vmlinux.h` generation is also skipped.
13. `_tcp_bbr3=yes`:
    `scripts/config -m TCP_CONG_CUBIC -d DEFAULT_CUBIC -e TCP_CONG_BBR -e DEFAULT_BBR --set-str DEFAULT_TCP_CONG bbr -m NET_SCH_FQ_CODEL -e NET_SCH_FQ -d CONFIG_DEFAULT_FQ_CODEL -e CONFIG_DEFAULT_FQ`
    In the fork, `TCP_CONG_BBR` is BBRv3 from the `bbr3` branch, and a separate `TCP_CONG_BBR3=m` also exists.
14. **THP**: `always` runs `-d TRANSPARENT_HUGEPAGE_MADVISE -e TRANSPARENT_HUGEPAGE_ALWAYS`. `madvise` runs the reverse.
15. `_autofdo=yes`: `-e AUTOFDO_CLANG`. With a profile name, `BUILD_FLAGS+=(CLANG_AUTOFDO_PROFILE=...)`.
16. `_propeller=yes`: `-e PROPELLER_CLANG`. With `_propeller_profiles=yes`, `BUILD_FLAGS+=(CLANG_PROPELLER_PROFILE_PREFIX="${srcdir}/propeller")`.
17. `_use_current=yes`: `zcat /proc/config.gz > .config`. `_localmodcfg=yes`: `make localmodconfig`.
18. `make prepare`, `yes "" | make config`, then `diff -u ../config .config`, and the final config is saved as `config-${pkgver}-${pkgrel}${pkgbase#linux}` next to the PKGBUILD.

### 2.3 build() / package() details worth copying
- `make "${BUILD_FLAGS[@]}" -j"$(nproc)" all`. Outside CI it also runs `make -C tools/bpf/bpftool vmlinux.h feature-clang-bpf-co-re=1`, and `vmlinux.h` is shipped in headers (for sched-ext/BPF).
- Exports: `KBUILD_BUILD_HOST=cachyos`, `KBUILD_BUILD_USER=$pkgbase`, reproducible `KBUILD_BUILD_TIMESTAMP` from `SOURCE_DATE_EPOCH`.
- `options=('!strip' '!debug' '!lto')`. Makepkg LTO is off (the kernel uses its own).
- Modules: `ZSTD_CLEVEL=19 make ... INSTALL_MOD_STRIP=1 DEPMOD=/doesnt/exist modules_install`. `CONFIG_MODULE_COMPRESS_ZSTD=y` and `MODULE_COMPRESS_ALL=y` apply.
- Out-of-tree modules (zfs/nvidia/r8125) are stripped with `llvm-strip`/`strip --strip-debug`, signed with `scripts/sign-file` using `CONFIG_MODULE_SIG_HASH` (sha512) and the in-tree key, then `zstd --rm -19 -T0`. NVIDIA builds use `IGNORE_CC_MISMATCH=yes` and empty `CFLAGS/CXXFLAGS/LDFLAGS`. The ZFS configure gets `KERNEL_LLVM=1` for LTO builds.
- `MODULE_FLAGS=(KERNEL_UNAME=... IGNORE_PREEMPT_RT_PRESENCE=1 SYSSRC=... SYSOUT=...)`.
- `provides=(VIRTUALBOX-GUEST-MODULES WIREGUARD-MODULE KSMBD-MODULE V4L2LOOPBACK-MODULE NTSYNC-MODULE VHBA-MODULE ADIOS-MODULE)`. These modules are in-tree, so DKMS packages for them are unnecessary.
- optdepends include `scx-scheds` (sched-ext userspace schedulers).
- Headers packaging follows Arch's `linux` package, plus Rust `.rmeta`/`.so`/`generated_*.rs`, `resolve_btfids`, and objtool. It removes non-x86 arch dirs and Documentation, and strips tools.

### 2.4 Effective `.config` of the default package (config + prepare defaults)

| Area | Effective value (default `linux-cachyos`, LTO, local build) |
|---|---|
| CachyOS sauce | `CONFIG_CACHY=y` |
| Scheduler | EEVDF base + `CONFIG_SCHED_BORE=y`. Also `SCHED_CLASS_EXT=y` (sched-ext), `SCHED_POC_SELECTOR=y`, `SCHED_CACHE=y`, `SCHED_AUTOGROUP=y`, `SCHED_CORE=y`, `SCHED_MC/SMT/CLUSTER=y`, `SCHED_MC_PRIO=y`, `MIN_BASE_SLICE_NS=1600000`, `SCHED_HRTICK=y`, `UCLAMP_TASK(_GROUP)=y` |
| Timer | `HZ_1000=y`, `HZ=1000`. `NO_HZ_FULL=y` (+ `NO_HZ_FULL_NODEF` if supported), `CONTEXT_TRACKING=y`, `HIGH_RES_TIMERS=y` |
| Preemption | `PREEMPT=y` (full), `PREEMPT_DYNAMIC=y`, `PREEMPT_RCU=y`, `RCU_BOOST=y` (delay 500), `RCU_NOCB_CPU=y`, `RCU_LAZY=y` with `RCU_LAZY_DEFAULT_OFF=y` |
| Compiler | Clang + ld.lld, `LTO_CLANG_THIN=y`, `CC_OPTIMIZE_FOR_PERFORMANCE_O3=y`, `X86_NATIVE_CPU=y` (-march=native). Repo builds use generic v1/v3/v4 or `MZEN4`. |
| THP | `TRANSPARENT_HUGEPAGE_ALWAYS=y`. shmem/tmpfs `..._HUGE_ADVISE=y`, `THP_SWAP=y` |
| Panic | DRM panic shows a QR code linking to `panic.archlinux.org` |
| Governor | schedutil default (`CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y`), `X86_AMD_PSTATE=y` with `X86_AMD_PSTATE_DEFAULT_MODE=3` (active/EPP), `X86_INTEL_PSTATE=y` |
| TCP | CUBIC default, BBR and BBR3 as modules (unless `_tcp_bbr3=yes`), default qdisc `fq_codel` |

---

## 3. Patches downloaded from `cachyos/kernel-patches`

Base URL: `_patchsource="https://raw.githubusercontent.com/cachyos/kernel-patches/master/${_major}"` (7.3 for main; 7.2 for hardened; 6.18 for lts; 7.4 for rc).

| Condition | Patch path |
|---|---|
| any LTO (`thin`, `thin-dist`, `full`) | `misc/dkms-clang.patch` |
| `_cpusched` = `bore`, `rt-bore`, `hardened` (on main; the `-bore`, `-eac`... copies also include `cachyos`) | `sched/0001-bore-cachy.patch` |
| `_cpusched=bmq` | `sched/0001-prjc-cachy.patch` |
| `_cpusched=hardened` | `misc/0001-hardened.patch` |
| `_cpusched` = `rt` or `rt-bore` | `misc/0001-rt-i915.patch` (PREEMPT_RT itself is mainline) |
| `_cpusched=cachyos` / `eevdf` (main) | **no scheduler patch.** BORE code is in the fork tarball. |
| deckify (always) | `misc/0001-acpi-call.patch`, `misc/0001-handheld.patch` |
| `_build_nvidia_open=yes` | `misc/nvidia/0001-fix-dsc-correct-RC-parameter-tables-to-match-VESA-DS.patch`, `misc/nvidia/0002-fix-dp-add-Bigscreen-Beyond-VR-headset-to-WAR-databa.patch`, `misc/nvidia/0004-Open-sysfs-config-from-the-userspace-root-on-7.3.patch` (applied to the NVIDIA source tree). Source: `https://download.nvidia.com/XFree86/NVIDIA-kernel-module-source/NVIDIA-kernel-module-source-620.73.04.tar.xz` |
| `_build_nvidia_580xx=yes` | `misc/nvidia-580xx/0001-Enable-atomic-kernel-modesetting-by-default.patch`, `misc/nvidia-580xx/0002-fix-hw-cursor-kde.patch` (+ `0003-Fix-build-on-Linux-7.4.patch` on rc). Source: `https://us.download.nvidia.com/XFree86/Linux-x86_64/580.196.07/NVIDIA-Linux-x86_64-580.196.07.run` (`--extract-only`) |
| eac with r8125 | `misc/r8125/0001-Remove-rtltool.patch` |

Patch application: every `source` entry ending in `.patch` gets `patch -Np1`. NVIDIA patches go to the NVIDIA tree and r8125 patches (eac) to the r8125 tree.

**Caveat (inferred, not verified):** `linux-cachyos-bore` downloads `0001-bore-cachy.patch` on top of the same `cachyos-7.3.6-1` tarball whose config already contains the `SCHED_BORE` symbol. Check how that patch interacts with the tarball before reusing the bore variant. For `linux-brook`, the simplest and verified path is to copy the main PKGBUILD (`_cpusched=cachyos`, which enables BORE with no extra patch).

---

## 4. The `config` file: notable performance and gaming options

The header says `Linux/x86 7.3.0`, generated with `gcc (GCC) 16.2.1`, Rust 1.98.0, pahole 1.31. The values below are what the file itself contains, before `prepare()`.

### Scheduler / CPU
- `# CONFIG_CACHY is not set`, `# CONFIG_SCHED_BORE is not set` (both turned on by the PKGBUILD)
- `CONFIG_SCHED_CLASS_EXT=y`, `CONFIG_EXT_GROUP_SCHED=y`, `CONFIG_EXT_SUB_SCHED=y` (sched-ext for scx schedulers)
- `CONFIG_SCHED_POC_SELECTOR=y` (Piece-Of-Cake idle-CPU selector, v2.6.3 per README)
- `CONFIG_SCHED_CACHE=y`, `CONFIG_SCHED_AUTOGROUP=y`, `CONFIG_SCHED_CORE=y`, `CONFIG_SCHED_MC_PRIO=y`, `CONFIG_SCHED_SMT/CLUSTER/MC=y`, `CONFIG_SCHED_HRTICK=y`
- `CONFIG_MIN_BASE_SLICE_NS=1600000` (fork option; 2000000 on lts/hardened)
- `CONFIG_UCLAMP_TASK=y` (`UCLAMP_BUCKETS_COUNT=5`), `CONFIG_UCLAMP_TASK_GROUP=y`, `CONFIG_FAIR_GROUP_SCHED=y`, `CONFIG_CFS_BANDWIDTH=y`, `# CONFIG_RT_GROUP_SCHED is not set`
- `CONFIG_NUMA=y`, `CONFIG_NUMA_BALANCING=y`, `CONFIG_NUMA_BALANCING_DEFAULT_ENABLED=y`
- `CONFIG_GENERIC_CPU=y`, `CONFIG_X86_64_VERSION=1`, `# CONFIG_X86_NATIVE_CPU`, `# CONFIG_MZEN4` (set by the PKGBUILD)
- `CONFIG_MAXSMP=y`, `CONFIG_NR_CPUS=8192`
- `CONFIG_X86_AMD_PSTATE=y`, `CONFIG_X86_AMD_PSTATE_DEFAULT_MODE=3`, `CONFIG_X86_INTEL_PSTATE=y`, `CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y`, cpuidle governors ladder/menu/teo/haltpoll all `=y`, `CONFIG_INTEL_IDLE=y`
- `CONFIG_X86_FRED=y`, `CONFIG_X86_KERNEL_IBT=y`, `CONFIG_X86_USER_SHADOW_STACK=y`
- All CPU mitigations are left **on** (`CONFIG_CPU_MITIGATIONS=y` and every `MITIGATION_*=y`). CachyOS does not disable mitigations in config.

### Timer / preemption / RCU
- `CONFIG_HZ_300=y` / `CONFIG_HZ=300` in the file (1000 after prepare). `HZ_500/600/750` choices exist (fork).
- `CONFIG_NO_HZ_FULL=y`, `CONFIG_NO_HZ=y`, `CONFIG_NO_HZ_COMMON=y`, `CONFIG_CONTEXT_TRACKING_USER=y`, `CONFIG_VIRT_CPU_ACCOUNTING_GEN=y`, `CONFIG_IRQ_TIME_ACCOUNTING=y`
- `CONFIG_PREEMPT=y`, `# CONFIG_PREEMPT_LAZY`, `# CONFIG_PREEMPT_RT`, `CONFIG_PREEMPT_DYNAMIC=y`
- `CONFIG_RCU_EXPERT=y`, `CONFIG_RCU_BOOST=y`, `CONFIG_RCU_BOOST_DELAY=500`, `CONFIG_RCU_NOCB_CPU=y`, `CONFIG_RCU_LAZY=y`, `CONFIG_RCU_LAZY_DEFAULT_OFF=y`, `CONFIG_RCU_FANOUT=64`, `CONFIG_RCU_FANOUT_LEAF=16`
- `CONFIG_PSI=y` (not default-disabled)

### Compiler / build
- `CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y` (O3 is set by the PKGBUILD), `CONFIG_LTO_NONE=y` (Thin is set by the PKGBUILD), `# CONFIG_AUTOFDO_CLANG`, `# CONFIG_PROPELLER_CLANG`, `# CONFIG_CFI`
- `CONFIG_KERNEL_ZSTD=y` (zstd-compressed bzImage)
- `CONFIG_MODULE_COMPRESS_ZSTD=y`, `CONFIG_MODULE_COMPRESS_ALL=y`, `CONFIG_MODULE_SIG=y`, `CONFIG_MODULE_SIG_ALL=y`, `CONFIG_MODULE_SIG_SHA512=y`, `CONFIG_MODULE_SIG_KEY_TYPE_ECDSA=y`, `# CONFIG_MODULE_SIG_FORCE`, `# CONFIG_MODVERSIONS`, `# CONFIG_TRIM_UNUSED_KSYMS`
- `CONFIG_DEFAULT_HOSTNAME="cachyos"`, `CONFIG_IKCONFIG=y` + `CONFIG_IKCONFIG_PROC=y` (/proc/config.gz), `CONFIG_IKHEADERS=m`

### Memory management
- `CONFIG_LRU_GEN=y`, `CONFIG_LRU_GEN_ENABLED=y`, `CONFIG_LRU_GEN_WALKS_MMU=y`, `# CONFIG_LRU_GEN_STATS` (MGLRU on by default)
- `CONFIG_PER_VMA_LOCK=y`, `CONFIG_ANON_VMA_NAME=y`, `CONFIG_USERFAULTFD=y`
- `CONFIG_TRANSPARENT_HUGEPAGE=y`, `CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS=y`, `CONFIG_TRANSPARENT_HUGEPAGE_SHMEM_HUGE_ADVISE=y`, `CONFIG_TRANSPARENT_HUGEPAGE_TMPFS_HUGE_ADVISE=y`, `CONFIG_THP_SWAP=y`
- `CONFIG_ZSWAP=y`, `CONFIG_ZSWAP_DEFAULT_ON=y`, `CONFIG_ZSWAP_SHRINKER_DEFAULT_ON=y`, `CONFIG_ZSWAP_COMPRESSOR_DEFAULT="zstd"`, `CONFIG_ZSMALLOC=y`, `CONFIG_ZSMALLOC_CHAIN_SIZE=8`
- `CONFIG_ZRAM=m`, `CONFIG_ZRAM_DEF_COMP="zstd"`, all zram backends on, `ZRAM_WRITEBACK=y`, `ZRAM_MULTI_COMP=y`
- `CONFIG_DAMON=y` with `VADDR`, `PADDR`, `SYSFS`, `RECLAIM`, `LRU_SORT`, `STAT` (`# CONFIG_DAMON_STAT_ENABLED_DEFAULT`)
- `CONFIG_KSM=y`, `CONFIG_COMPACTION=y`, `CONFIG_COMPACT_UNEVICTABLE_DEFAULT=1`, `CONFIG_PCP_BATCH_SCALE_MAX=5`, `CONFIG_DEFAULT_MMAP_MIN_ADDR=65536`, `# CONFIG_DEFERRED_STRUCT_PAGE_INIT`
- `CONFIG_SLAB_FREELIST_RANDOM=y`, `CONFIG_SLAB_FREELIST_HARDENED=y`, `CONFIG_SHUFFLE_PAGE_ALLOCATOR=y`, `CONFIG_INIT_ON_ALLOC_DEFAULT_ON=y`, `# CONFIG_INIT_ON_FREE_DEFAULT_ON`, `CONFIG_INIT_STACK_ALL_ZERO=y`, `CONFIG_RANDSTRUCT_NONE=y`
- `CONFIG_CGROUP_DMEM=y` (VRAM cgroup), `CONFIG_MEMCG=y`, `# CONFIG_MEMCG_V1`

### Block / I/O schedulers
- `CONFIG_MQ_IOSCHED_DEADLINE=y`, `CONFIG_MQ_IOSCHED_KYBER=y`, `CONFIG_MQ_IOSCHED_ADIOS=y` (fork; README says ADIOS v3.2.0), `# CONFIG_MQ_IOSCHED_DEFAULT_ADIOS`, `CONFIG_IOSCHED_BFQ=y`, `CONFIG_BFQ_GROUP_IOSCHED=y`
- `CONFIG_BLK_WBT=y`, `CONFIG_BLK_WBT_MQ=y`, `CONFIG_BLK_CGROUP_IOLATENCY=y`, `CONFIG_BLK_CGROUP_IOCOST=y`
- No I/O scheduler is disabled. All are built in, and the choice is left to udev rules (CachyOS ships those in `cachyos-settings`).

### Networking
- `CONFIG_TCP_CONG_CUBIC=y`, `CONFIG_DEFAULT_CUBIC=y`, `CONFIG_DEFAULT_TCP_CONG="cubic"`, `CONFIG_TCP_CONG_BBR=m`, `CONFIG_TCP_CONG_BBR3=m`
- `CONFIG_NET_SCH_DEFAULT=y`, `CONFIG_DEFAULT_FQ_CODEL=y`, `CONFIG_DEFAULT_NET_SCH="fq_codel"`, `CONFIG_NET_SCH_FQ_CODEL=y`, `CONFIG_NET_SCH_FQ=m`, `CONFIG_NET_SCH_CAKE=m`
- `CONFIG_MPTCP=y`

### Gaming / desktop features
- `CONFIG_NTSYNC=m` (Wine/Proton NT sync primitives)
- `CONFIG_FUTEX=y`, `CONFIG_FUTEX_PI=y`, `CONFIG_FUTEX_PRIVATE_HASH=y`, `CONFIG_FUTEX_MPOL=y`, `CONFIG_FUTEX_ROBUST_UNLOCK=y`
- `CONFIG_V4L2_LOOPBACK=m`, `CONFIG_VHBA=m` (in-tree via fork)
- `CONFIG_ANDROID_BINDER_IPC_RUST=y`, `CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"` (Waydroid)
- `CONFIG_PCI_ACS_OVERRIDE=y` (VFIO passthrough)
- `CONFIG_USER_NS=y` (unprivileged user namespaces for Steam/Flatpak sandboxes)
- GPU: `CONFIG_DRM_AMDGPU=m` with `SI=y`, `CIK=y`, `USERPTR=y`, `DC=y`, `HSA_AMD=y`, `HSA_AMD_P2P=y`, `# CONFIG_AMD_PRIVATE_COLOR` (deckify enables it). Also `CONFIG_DRM_I915=m`, `CONFIG_DRM_XE=m`, `CONFIG_DRM_NOUVEAU=m`, `# CONFIG_DRM_NOVA`, `# CONFIG_NOVA_CORE`.
- `CONFIG_DRM_PANIC=y`, `CONFIG_DRM_PANIC_SCREEN="kmsg"` (qr_code after prepare)
- `CONFIG_SND_HDA_POWER_SAVE_DEFAULT=10`, `CONFIG_WQ_POWER_EFFICIENT_DEFAULT=y`, `CONFIG_ENERGY_MODEL=y`
- `CONFIG_IOMMU_DEFAULT_DMA_LAZY=y`, `# CONFIG_INTEL_IOMMU_DEFAULT_ON`
- `# CONFIG_LEGACY_TIOCSTI`
- `CONFIG_LEGACY_VSYSCALL_XONLY=y`, `CONFIG_X86_X32_ABI=y`

### Debug / tracing (what is and isn't disabled)
- Still enabled: `CONFIG_DEBUG_KERNEL=y`, `CONFIG_DEBUG_INFO=y` (`DWARF5`, uncompressed), `CONFIG_DEBUG_INFO_BTF=y` + `_MODULES=y` (needed for sched-ext/BPF), `CONFIG_DEBUG_FS=y`, `CONFIG_SLUB_DEBUG=y` (runtime-off), `CONFIG_PAGE_POISONING=y` (runtime-off), `CONFIG_SCHEDSTATS=y`, `CONFIG_KFENCE=y` (sample interval 100), `CONFIG_FTRACE/FUNCTION_TRACER/FUNCTION_GRAPH_TRACER/DYNAMIC_FTRACE/STACK_TRACER/SCHED_TRACER/HWLAT/OSNOISE/TIMERLAT=y`, `CONFIG_MMIOTRACE=y`, `CONFIG_KPROBES=y`, `CONFIG_BPF_KPROBE_OVERRIDE=y`, `CONFIG_PM_DEBUG=y`, `CONFIG_MEMTEST=y`
- Disabled: `# CONFIG_DEBUG_PREEMPT`, `# CONFIG_DEBUG_LIST`, `# CONFIG_DEBUG_MISC`, `# CONFIG_DEBUG_VM`, `# CONFIG_KASAN`, `# CONFIG_UBSAN`, `# CONFIG_PROVE_LOCKING`, `# CONFIG_DEBUG_SPINLOCK`, `# CONFIG_DEBUG_MUTEXES`, `# CONFIG_DEBUG_ATOMIC_SLEEP`, `# CONFIG_LATENCYTOP`, `# CONFIG_IRQSOFF_TRACER`, `# CONFIG_PREEMPT_TRACER`, `# CONFIG_WQ_WATCHDOG`, `# CONFIG_BUG_ON_DATA_CORRUPTION`, `# CONFIG_RCU_TRACE`
- `CONFIG_DEFAULT_HUNG_TASK_TIMEOUT=120`, `CONFIG_RCU_CPU_STALL_TIMEOUT=60`, `CONFIG_PANIC_TIMEOUT=0`, `CONFIG_MAGIC_SYSRQ_DEFAULT_ENABLE=0x0`
- Only CI builds flip `-d DEBUG_KERNEL -e DEBUG_INFO_REDUCED`. Release packages keep full debug info, which is stripped from modules at install (`INSTALL_MOD_STRIP=1`), and vmlinux is stripped in headers.

### Security / LSM (relevant to anti-cheat and gaming)
- `CONFIG_LSM="landlock,lockdown,yama,integrity,bpf"`, `CONFIG_DEFAULT_SECURITY_DAC=y`. SELinux, AppArmor, Tomoyo, Yama, and Landlock are built.
- `CONFIG_SECURITY_LOCKDOWN_LSM=y` (not early), `CONFIG_BPF_LSM=y`, `CONFIG_BPF_UNPRIV_DEFAULT_OFF=y`, `CONFIG_BPF_JIT_ALWAYS_ON=y`
- `CONFIG_HIBERNATION=y`, `CONFIG_KEXEC=y`, `CONFIG_CRASH_DUMP=y`, `CONFIG_PROC_MEM_ALWAYS_FORCE=y`, `CONFIG_STACKPROTECTOR_STRONG=y`, `CONFIG_FORTIFY_SOURCE=y`, `CONFIG_HARDENED_USERCOPY=y`, `# CONFIG_GCC_PLUGINS`

---

## 5. AutoFDO / Propeller, helper scripts, CI, README guidance

### AutoFDO / Propeller
- **No profile files are shipped in this repo.** The README and pkgdesc say the official default kernel is built with AutoFDO + Propeller, but the profiles are not in `linux-cachyos`. They are supplied in CachyOS's own build infrastructure.
- Workflow from the PKGBUILD comments (main and rc only), citing `https://cachyos.org/blog/2411-kernel-autofdo/`:
  1. Build with `_autofdo=yes` and `_build_debug=yes`. Clang LTO is required: "Add additonal check if Thin or Full LTO is enabled otherwise die", although no such check is implemented.
  2. Boot it, run a workload, and profile with `perf`.
  3. Convert the profile and put it into the source dir.
  4. Rebuild with `_autofdo_profile_name=<file>` (the file must exist, otherwise `_die`).
  5. For Propeller, rebuild with `_propeller=yes`, profile the AutoFDO kernel, convert with
     `create_llvm_prof --binary=/usr/src/debug/linux-cachyos-rc/vmlinux --profile=propeller.data --format=propeller --propeller_output_module_name --out=propeller_cc_profile.txt --propeller_symorder=propeller_ld_profile.txt`,
     place both txt files in srcdir, and set `_propeller_profiles=yes`.

### Repo-build helper scripts (top level)
These scripts are for CachyOS's own infrastructure. They use Docker images `pttrr/docker-makepkg[-v3|-v4|-znver4]` and the maintainer's local paths.
- `script.sh` (x86-64 repo): `_processor_opt:=GENERIC`, `_build_zfs=yes`, `_build_nvidia_open=yes`, `_build_nvidia_580xx=yes`, `_build_r8125=yes`. Builds every PKGBUILD and moves the packages to `cachyos`.
- `script-v3-v4.sh`: same module flags. Builds with `_processor_opt:=GENERIC_V3` first with `_use_llvm_lto=none` and then `thin`, then repeats with `GENERIC_V4`. Results go to the `cachyos-v3` and `cachyos-v4` repos.
- `script-znver4.sh`: `_processor_opt:=zen4` plus the same module flags. Results go to `cachyos-znver4`.
- So **official repo kernels are not `-march=native`**. They are built for generic x86-64, x86-64-v3, x86-64-v4, or `MZEN4`, each in GCC and ThinLTO flavours, with ZFS, NVIDIA (open and 580xx), and r8125 modules prebuilt.
- `srcinfo.sh`: `updpkgsums` + `makepkg --printsrcinfo > .SRCINFO` for every PKGBUILD.
- `aur-push.sh`: pushes committed package dirs to the AUR and checks that `.SRCINFO` is fresh.
- `tag-release.sh`: creates signed `cachyos-<ver>-<pkgrel>` tags in `CachyOS/linux`, generates a changelog from first-parent merge commits of topic branches, and uploads a `git archive` tarball + `.asc` with `gh release`. This explains where the source tarball comes from.

### CI (`.github/workflows/build.yml`)
- Triggers on changes to `linux-cachyos/PKGBUILD` or the workflow file. The matrix is `toolchain: [gcc, clang]` in an `archlinux:base-devel` container, with the `[cachyos]` repo added and ccache enabled.
- `MAKEFLAGS="-j$(nproc) -l$(nproc)"`. Env: `_build_zfs=yes`, `_build_nvidia_open=yes`, `_use_llvm_lto=none|thin`.
- CI detection in the PKGBUILD switches to `-Os`, `DEBUG_INFO_REDUCED`, and `-d DEBUG_KERNEL`, and skips bpftool `vmlinux.h`. This is only for CI speed.

### README guidance (summary of performance claims)
- Default `linux-cachyos`: Clang ThinLTO + AutoFDO + Propeller. Scheduler-specific packages are GCC builds without LTO.
- Timer options 100 to 1000 Hz (default 1000). PREEMPT_DYNAMIC. vmalloc bulk-free optimizations.
- POC selector, cluster-aware scheduling, preempt-IPI optimizations, sched/wait LIFO `accept()`, prefer-previous-CPU wakeups, amd-pstate preferred core.
- BBRv3 as a separate module. MGLRU enhancements and "Cachy Sauce MM tuning (LRU-gen working set protection, compaction/watermark tweaks, hugepage reclaim)". BFQ and mq-deadline improvements. ADIOS v3.2.0. DMEM VRAM cgroup.
- Hardware: Steam Deck, ROG Ally, MSI Claw, T2 Macs, ASUS/Lenovo/HP/Samsung fixes. HDR, AMDGPU `amdgpu_ignore_min_pcap`, DRM fair scheduling, HDMI VRR/ALLM. v4l2loopback and ACS override.
- SCX schedulers are supported, except with `-bmq`.
- Repo tiers: `x86-64`, `x86-64-v3`, `x86-64-v4`, `znver4`. Debuginfod is at `https://debuginfod.cachyos.org`.

---

## 6. Recommendations for `linux-brook` (copying CachyOS exactly)

1. Start from `linux-cachyos-src/PKGBUILD` + `config` verbatim, with the same `cachyos-7.3.6-1` tarball and PGP keys. Change only `pkgbase`/`_pkgsuffix` naming (`linux-brook`), `KBUILD_BUILD_HOST`, and `provides/replaces` (remove `linux-cachyos-lto`).
2. Keep these defaults to match the default CachyOS package:
   - `_cachy_config=yes`, `_cpusched=cachyos` (BORE), `_HZ_ticks=1000`, `_tickrate=full`, `_preempt=full`, `_hugepage=always`, `_cc_harder=yes`, `_use_llvm_lto=thin`
   - `_per_gov=no`, `_tcp_bbr3=no`
3. For a distributable binary, set `_processor_opt` to `generic_v3` (or `zen4`) as CachyOS's repo scripts do. The empty default produces `-march=native`, which is not portable.
4. AutoFDO/Propeller require your own profiling run because no profiles are shipped. Without them you get ThinLTO + O3, which matches CachyOS's GCC/LTO kernels except for the PGO step.
5. For anti-cheat (EAC Linux v2) support, the `linux-cachyos-eac` PKGBUILD is the reference. It needs a Secure Boot signing key and forces lockdown, signed modules, IOMMU, and no hibernation.

---

## Files read (all 49 tarball files)

Downloaded: `codeload.github.com/CachyOS/linux-cachyos/tar.gz/HEAD`, extracted to `...\scratchpad\cachy\linux-cachyos\linux-cachyos-HEAD\`.

| # | File | How it was covered |
|---|---|---|
| 1 | `.gitignore` | read fully |
| 2 | `aur-push.sh` | read fully |
| 3 | `CODE_OF_CONDUCT.md` | read fully (Contributor Covenant 2.0, nothing technical) |
| 4 | `CONTRIBUTING.md` | read fully |
| 5 | `LICENSE.md` | read header and checked by search: standard GNU GPL v3 text (lines 1-542 terms, END OF TERMS at line 542), nothing technical |
| 6 | `README.md` | read fully |
| 7 | `script-v3-v4.sh` | read fully |
| 8 | `script-znver4.sh` | read fully |
| 9 | `script.sh` | read fully |
| 10 | `srcinfo.sh` | read fully |
| 11 | `tag-release.sh` | read fully |
| 12 | `.github/FUNDING.yml` | read fully |
| 13 | `.github/ISSUE_TEMPLATE/bug_report.yml` | read fully |
| 14 | `.github/ISSUE_TEMPLATE/config.yml` | read fully |
| 15 | `.github/ISSUE_TEMPLATE/feature_request.yml` | read fully |
| 16 | `.github/workflows/build.yml` | read fully |
| 17 | `linux-cachyos/.SRCINFO` | read fully (copied) |
| 18 | `linux-cachyos/config` | searched/read for all performance-relevant sections (lines 1-340, 440-600, 1180-1400 read directly; ~400 options extracted by pattern). Used as the baseline for key-by-key diffs (copied verbatim) |
| 19 | `linux-cachyos/PKGBUILD` | read fully, all 880 lines (copied) |
| 20 | `linux-cachyos-bmq/.SRCINFO` | read (all non-boilerplate fields) |
| 21 | `linux-cachyos-bmq/config` | SHA-256 identical to main config |
| 22 | `linux-cachyos-bmq/PKGBUILD` | full LCS diff vs main |
| 23 | `linux-cachyos-bore/.SRCINFO` | read |
| 24 | `linux-cachyos-bore/config` | identical to main |
| 25 | `linux-cachyos-bore/PKGBUILD` | full LCS diff vs main |
| 26 | `linux-cachyos-deckify/.SRCINFO` | read |
| 27 | `linux-cachyos-deckify/config` | identical to main |
| 28 | `linux-cachyos-deckify/PKGBUILD` | full LCS diff vs bore |
| 29 | `linux-cachyos-eac/.SRCINFO` | read |
| 30 | `linux-cachyos-eac/config` | identical to main |
| 31 | `linux-cachyos-eac/PKGBUILD` | full LCS diff vs main |
| 32 | `linux-cachyos-eevdf/.SRCINFO` | read |
| 33 | `linux-cachyos-eevdf/config` | identical to main |
| 34 | `linux-cachyos-eevdf/PKGBUILD` | full LCS diff vs main |
| 35 | `linux-cachyos-hardened/.SRCINFO` | read |
| 36 | `linux-cachyos-hardened/config` | full key-by-key diff vs main (595 differences; all changed values reviewed, notable added/removed keys listed) |
| 37 | `linux-cachyos-hardened/PKGBUILD` | full LCS diff vs bore |
| 38 | `linux-cachyos-lts/.SRCINFO` | read |
| 39 | `linux-cachyos-lts/config` | full key-by-key diff vs main (695 differences; all changed values reviewed, notable keys listed) |
| 40 | `linux-cachyos-lts/PKGBUILD` | full LCS diff vs bore |
| 41 | `linux-cachyos-rc/.SRCINFO` | read |
| 42 | `linux-cachyos-rc/config` | full key-by-key diff vs main (169 differences, all reviewed) |
| 43 | `linux-cachyos-rc/PKGBUILD` | full LCS diff vs bore |
| 44 | `linux-cachyos-rt-bore/.SRCINFO` | read |
| 45 | `linux-cachyos-rt-bore/config` | identical to main |
| 46 | `linux-cachyos-rt-bore/PKGBUILD` | full LCS diff vs bore |
| 47 | `linux-cachyos-server/.SRCINFO` | read |
| — | `linux-cachyos-server/config` | identical to main |
| — | `linux-cachyos-server/PKGBUILD` | full LCS diff vs main |

Total: 16 non-variant files (11 root + 5 under `.github/`) plus 11 variant directories x 3 files (`PKGBUILD`, `config`, `.SRCINFO`) = 49 files, all listed above. Rows 48-49 are the two "—" rows. There are no other files: no `.install`, `.preset`, patches, or profiles exist in the repo.
