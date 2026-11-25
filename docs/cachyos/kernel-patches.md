# CachyOS `kernel-patches` repository – full analysis (for linux-brook)

Source: https://github.com/CachyOS/kernel-patches (snapshot of `HEAD`, downloaded 2026-11-25 as
`codeload.github.com/CachyOS/kernel-patches/tar.gz/HEAD`, 56,141,220 bytes, 1,215 tar entries,
1,050 files; `tar.exe` extracted everything, no missing paths).
Verbatim copy of the newest stable version's patches: `kernel-patches-src/7.3/` (14 files, SHA-256 verified identical).

---

## 0. TL;DR for linux-brook

| Item | Value |
|---|---|
| Newest **stable** directory | **7.3** (linux-cachyos PKGBUILD on master: `_major=7.3`, `_minor=6` → 7.3.6) |
| Newest **rc/next** directory | **7.4** (nvidia "Fix build on Linux 7.4" dated 2026-11-05/07; 7.4 not yet in the PKGBUILD) |
| Where the "cachy base" lives now | **Not in this repo any more.** Since 6.18 there is no `all/` directory and no `0001-cachyos-base-all.patch`. The PKGBUILD downloads a pre-patched tree: `https://github.com/CachyOS/linux/releases/download/cachyos-${_major}.${_minor}-${_tagrel}/…tar.gz`. The last in-repo base patch is **6.17** (`6.17/all/0001-cachyos-base-all.patch` = `0001-asus` + `0002-bbr3` + `0003-block` + `0004-cachy` + `0005-fixes`); it is broken down in §4 as the best available reference. |
| What 7.3 in this repo contains | Only add-ons applied **on top of** the CachyOS/linux tree: scheduler (`sched/`: BORE, PRJC/BMQ) and optional `misc/` patches (handheld, aufs, acpi_call, RT-i915, dkms-clang, NVIDIA open/580xx module fixes, r8125 module fix). |
| Default CachyOS scheduler | `_cpusched=cachyos` → `scripts/config -e SCHED_BORE` (BORE on top of EEVDF) |
| PKGBUILD defaults worth copying | `_cc_harder=yes` (-O3), `_HZ_ticks=1000`, `_preempt=full`, `_tickrate=full` (NO_HZ_FULL), `_hugepage=always`, `_use_llvm_lto=thin`, `_tcp_bbr3=no` (BBRv3 is in the base tree but not selected as default), `CONFIG_CACHY=y` |

Practical recipe for linux-brook 7.3: take the CachyOS/linux `cachyos-7.3.x` source tag (base patches
pre-applied) **or** vanilla 7.3 + CachyOS base patches, then apply `7.3/sched/0001-bore-cachy.patch`, optionally
`7.3/misc/0001-handheld.patch` (handhelds), `0001-acpi-call.patch`, `dkms-clang.patch` (when building with clang),
and the NVIDIA module patches if you package nvidia-open. Note that `*-cachy.patch` sched variants are
rebased against the CachyOS tree (they touch `CONFIG_CACHY` and `CONFIG_SCHED_POC_SELECTOR` hunks) and will
not apply cleanly to vanilla 7.3 without the base.

---

## 1. Directory layout (all versions)

Top level: `README.md`, `Files/` (empty dir), and one directory per kernel series:
`5.15 5.17 5.18 5.19 6.0 6.1 6.2 … 6.19 7.0 7.1 7.2 7.3 7.4`.

Sub-directory conventions:
- `all/` – single squashed CachyOS base patch (5.18 – 6.17 only).
- `00NN-*.patch` at version root – the same base split per topic (e.g. 6.17: asus, bbr3, block, cachy, fixes).
- `sched/` – CPU scheduler patches (BORE, PRJC = BMQ/PDS "Project C", earlier also EEVDF/TT/CacULE/MuQSS…).
- `sched-dev/`, `sched-prjc/` – development versions of the scheduler patches.
- `misc/` – optional patches (handheld, aufs, hardened, rt-i915, acpi-call, clang-polly, cgroup-vram, nvidia…).
- `misc/nvidia*`, `misc/r8125` – patches for **out-of-tree modules** (NVIDIA open kernel modules, NVIDIA 580xx, Realtek r8125), not for the kernel tree.

### Per-version file lists (one line per version, paths relative to the version dir)

- **5.15** (103 files): `0001-arch-patches.patch`, `0001-bbr2.patch`, `0001-bcachefs.patch`, `0001-bitmap.patch`, `0001-blake2.patch`, `0001-block-patches.patch`, `0001-block-sbitmap.patch`, `0001-btrfs-fixes.patch`, `0001-btrfs-patches.patch`, `0001-cachy.patch`, `0001-cfi.patch`, `0001-clang.patch`, `0001-clearlinux-patches.patch`, `0001-cpu-patches.patch`, `0001-damon-patches.patch`, `0001-fixes-miscellaneous.patch`, `0001-futex-wait.v-fsync-winesync.patch`, `0001-hardened-5.15.6-hardened.patch`, `0001-hwmon-patches.patch`, `0001-intel-patches.patch`, `0001-ksmbd-patches.patch`, `0001-ksm-patches.patch`, `0001-le9.patch`, `0001-lqx-patches.patch`, `0001-lrng-patches.patch`, `0001-lru-patches.patch`, `0001-MGLRU-v5.patch`, `0001-misc.patch`, `0001-mm-lru.patch`, `0001-mm-protect-mappings-under-memory-pressure.patch`, `0001-NEST.patch`, `0001-net-patches.patch`, `0001-ntfs3.patch`, `0001-page-table-check.patch`, `0001-pf-patches.patch`, `0001-PGO.patch`, `0001-prjc.patch`, `0001-prjc-fixes.patch`, `0001-rt.patch`, `0001-sbitmap-patches.patch`, `0001-sched-perf-fix.patch`, `0001-security-patches.patch`, `0001-sitemap.patch`, `0001-spectre-patches.patch`, `0001-stable-rc.patch`, `0001-string.patch`, `0001-v4l2loopback.patch`, `0001-xanmod-patches.patch`, `0001-xfs-backport.patch`, `0001-zen-patches.patch`, `0001-zstd.patch`, `0001-zstd-patches.patch`, `0001-zstd-patches-v2.patch`, `0001-zstd-upstream-patches.patch`, `AMD/0001-amd64-patches.patch`, `AMD/0001-amd-c3.patch`, `AMD/0001-amd-gpu.patch`, `AMD/0001-amd-perf.patch`, `AMD/0001-AMD-PERF-PATCH.patch`, `AMD/0001-amd-perf-v3.patch`, `AMD/0001-amdpstate.patch`, `AMD/0001-amd-pstate-dev-v5-fixes.patch`, `AMD/0001-amd-stb.patch`, `AMD/0001-pstate-perf.patch`, `AMD/amd-sched.patch`, `android-patches/0001-android-export-symbold-and-enable-building-ashmem-an.patch`, `arch-patches/0001-arch-patches.patch`, `arch-patches/0001-ZEN-Add-sysctl-and-CONFIG-to-disallow-unprivileged-C.patch`, `bore/0001-bore-sched.patch`, `cacule/cacule-5.15.patch`, `cacule/cacule-5.15-full.patch`, `cacule/cacule-5.15-rt.patch`, `cacule/cacule-5.15-rt-full.patch`, `lru_5.15.patch`, `misc/0001-Allow-changing-the-polling-interval-of-any-usb-hid.patch`, `misc/0001-burst.patch`, `misc/0001-cluster.patch`, `misc/0001-cpu-fixes.patch`, `misc/0001-f2fs-add.patch`, `misc/0001-misc.patch`, `misc/0001-misc-2.patch`, `misc/0001-misc-next.patch`, `misc/0001-mm.patch`, `misc/0001-rcu-next.patch`, `misc/0001-winesync.patch`, `misc/0001-ZFS-Support.patch`, `misc/0002-LL-elevator-set-default-scheduler-to-bfq-for-blk-mq.patch`, `misc/0003-sched-core-nr_migrate-256-increases-number-of-tasks-.patch`, `misc/0004-folio-mm.patch`, `misc/0004-mm-set-8-megabytes-for-address_space-level-file-read.patch`, `misc/0009-compiler-remove-stale-cc-option-checks.patch`, `misc/0010-ELF.patch`, `misc/1000-tune-vm-mm-and-vfs-settings.patch`, `misc/600-750hz.patch`, `misc/sched-patch.patch`, `sched/0001-bore.patch`, `sched/0001-tt.patch`, `TT/0001-high-hz.patch`, `TT/0001-tt-5.15.patch`, `TT/0001-tt-high-hz.patch`, `TT/0001-tt-r3.patch`, `TT/0001-tt-r3-rt.patch`, `TT/high-hz.patch`
- **5.17** (49 files): `0001-arch.patch`, `0001-latency_nice.patch`, `0002-anbox.patch`, `0003-bbr2.patch`, `0004-cachy.patch`, `0005-migrate.patch`, `0005-migrate-cacule.patch`, `0006-clearlinux.patch`, `0007-cpu.patch`, `0008-fixes-miscellaneous.patch`, `0009-fs-patches.patch`, `0010-hwmon.patch`, `0011-lru-le9.patch`, `0012-spf-lru.patch`, `0013-xanmod.patch`, `0014-lrng.patch`, `0015-ck-hrtimer.patch`, `0016-futex-winesync.patch`, `dev/0001-arch.patch`, `dev/0002-anbox.patch`, `dev/0003-bbr2.patch`, `dev/0004-cachy.patch`, `dev/0005-clearlinux.patch`, `dev/0006-cpu.patch`, `dev/0007-fixes-miscellaneous.patch`, `dev/0008-fs-patches.patch`, `dev/0009-hwmon.patch`, `dev/0010-lru-le9.patch`, `dev/0011-spf-lru.patch`, `dev/0012-xanmod.patch`, `dev/0013-lrng.patch`, `dev/0014-ck-hrtimer.patch`, `dev/0015-futex-winesync.patch`, `dev/0016-thinlto-cachedir.patch`, `dev/0017-FG-KASLR.patch`, `misc/0001-cfi.patch`, `misc/0001-cfi-rt.patch`, `misc/0001-damon-folios.patch`, `misc/0001-damos.patch`, `misc/0001-folio.patch`, `misc/0001-high-hz.patch`, `misc/0001-PCI-Allow-BAR-movement-during-boot-and-hotplug.patch`, `misc/0001-rt.patch`, `sched/0001-bore.patch`, `sched/0001-bore-sched.patch`, `sched/0001-cacULE.patch`, `sched/0001-cacULE-5.17-RT.patch`, `sched/0001-prjc.patch`, `sched/0001-tt.patch`
- **5.18** (54 files): `0001-aufs-20220620.patch`, `0001-bbr2.patch`, `0001-bcachefs-after-lru.patch`, `0001-hardened.patch`, `0001-hardening.patch`, `0001-spadfs-5.18-merge-v1.0.16.patch`, `0002-cachy.patch`, `0003-Extend-DAMOS-for-Proactive-LRU-lists-Sorting.patch`, `0004-fixes.patch`, `0005-hwmon.patch`, `0006-lrng.patch`, `0007-lru-le9-spf.patch`, `0008-kbuild-module.patch`, `0009-misc.patch`, `0010-futex-winesync.patch`, `0011-rcu.patch`, `0012-clr.patch`, `0013-fs-patches.patch`, `0014-perf.patch`, `0015-Introducing-OpenVPN-Data-Channel-Offload.patch`, `all/0001-cachyos-base-all.patch`, `misc/0001-arch.patch`, `misc/0001-bcachefs-after-lru.patch`, `misc/0001-bitmap.patch`, `misc/0001-ck-hrtimer.patch`, `misc/0001-clearlinux.patch`, `misc/0001-cpu.patch`, `misc/0001-Enable-resizable-BAR-support.patch`, `misc/0001-grub-backport-security.patch`, `misc/0001-kbuild.patch`, `misc/0001-ksm.patch`, `misc/0001-latency_nice.patch`, `misc/0001-migrate.patch`, `misc/0001-PCI-Allow-BAR-movement-during-boot-and-hotplug.patch`, `misc/0001-randstruct.patch`, `misc/0001-rust-5.18.patch`, `misc/0001-thinlto-cachdir.patch`, `misc/0001-zram-entropy-calculation.patch`, `misc/0001-zstd.patch`, `sched/0001-bore.patch`, `sched/0001-bore-sched.patch`, `sched/0001-cacULE-5.18.patch`, `sched/0001-cacULE-5.18-migrate.patch`, `sched/0001-prjc.patch`, `sched/0001-tt.patch`, `sched/0001-tt-cachy-5.18.patch`, `trunk/0001-amd-5.18-amd-pstate-enhancement-and-issue-fixs.patch`, `trunk/0001-bcachefs-5.18-introduce-bcachefs-patchset.patch`, `trunk/0001-firmware-5.18-merge-changes-from-dev-tree.patch`, `trunk/0001-kbuild-5.18-merge-changes-from-dev-tree.patch`, `trunk/0001-lib-string.c-Optimize-memchr.patch`, `trunk/0001-zstd-dev.patch`, `trunk/kbuild-modules-patches/0001-kbuild-5.18-merge-changes-from-dev-tree.patch`, `trunk/modules-patches/0001-modules-5.18-merge-changes-from-dev-tree.patch`
- **5.19** (80 files): `0001-bbr2.patch`, `0002-cachy.patch`, `0003-sched.patch`, `0004-Extend-DAMOS-for-Proactive-LRU-lists-Sorting.patch`, `0005-fixes.patch`, `0006-fs-patches.patch`, `0007-futex-winesync.patch`, `0008-Introducing-OpenVPN-Data-Channel-Offload.patch`, `0009-ksmbd.patch`, `0010-lrng.patch`, `0011-lru.patch`, `0012-misc.patch`, `0013-perf.patch`, `0014-rcu.patch`, `0015-rtw88.patch`, `0016-vma.patch`, `all/0001-cachyos-base-all.patch`, `misc/0001-Add-latency-priority-for-CFS-class.patch`, `misc/0001-amd-pstate-epp-enhancement.patch`, `misc/0001-aufs-5.19-merge-v20220808.patch`, `misc/0001-bcachefs.patch`, `misc/0001-bcachefs-after-lru.patch`, `misc/0001-cachy.patch`, `misc/0001-ck-hrtimer.patch`, `misc/0001-cpu.patch`, `misc/0001-hardened.patch`, `misc/0001-high-hz.patch`, `misc/0001-hwmon.patch`, `misc/0001-kbuild-5.19-allow-setting-zstd-compression-level-for.patch`, `misc/0001-kbuild-modules-5.19-allow-setting-zstd-compression-l.patch`, `misc/0001-kcfi.patch`, `misc/0001-mm-introduce-Designated-Movable-Blocks.patch`, `misc/0001-mm-remove-the-per-task-RSS-counter-cache.patch`, `misc/0001-per-VMA-locks-proposal.patch`, `misc/0001-rust.patch`, `misc/0001-sched-Introduce-classes-of-tasks-for-load-balance.patch`, `misc/0001-spadfs-5.19-merge-v1.0.16.patch`, `misc/0001-stable-rc.patch`, `misc/0001-task_struct-Add-field-for-per-task-userspace-schedul.patch`, `misc/0001-x86-Avoid-relocation-information-in-final-vmlinux.patch`, `misc/sched-next/0001-sched-numa-Initialise-numa_migrate_retry.patch`, `misc/sched-next/0002-sched-numa-Do-not-swap-tasks-between-nodes-when-spar.patch`, `misc/sched-next/0003-sched-numa-Apply-imbalance-limitations-consistently.patch`, `misc/sched-next/0004-sched-numa-Adjust-imb_numa_nr-to-a-better-approximat.patch`, `misc/sched-next/0005-sched-fair-Consider-CPU-affinity-when-allowing-NUMA-.patch`, `misc/sched-next/0006-sched-fair-Optimize-and-simplify-rq-leaf_cfs_rq_list.patch`, `misc/sched-next/0007-sched-deadline-Use-proc_douintvec_minmax-limit-minim.patch`, `misc/sched-next/0008-sched-Allow-newidle-balancing-to-bail-out-of-load_ba.patch`, `misc/sched-next/0009-sched-Fix-the-check-of-nr_running-at-queue-wakelist.patch`, `misc/sched-next/0010-sched-Remove-the-limitation-of-WF_ON_CPU-on-wakelist.patch`, `misc/sched-next/0011-selftests-rseq-riscv-use-rseq_get_abi-helper.patch`, `misc/sched-next/0012-selftests-rseq-riscv-fix-literal-suffix-warning.patch`, `misc/sched-next/0013-selftests-rseq-check-if-libc-rseq-support-is-registe.patch`, `misc/sched-next/0014-sched-fair-Remove-redundant-word.patch`, `misc/sched-next/0015-sched-Remove-unused-function-group_first_cpu.patch`, `misc/sched-next/0016-sched-only-perform-capability-check-on-privileged-op.patch`, `misc/sched-next/0017-sched-fair-Introduce-SIS_UTIL-to-search-idle-CPU-bas.patch`, `misc/sched-next/0018-sched-fair-Provide-u64-read-for-32-bits-arch-helper.patch`, `misc/sched-next/0019-sched-fair-Decay-task-PELT-values-during-wakeup-migr.patch`, `misc/sched-next/0020-sched-drivers-Remove-max-param-from-effective_cpu_ut.patch`, `misc/sched-next/0021-sched-fair-Rename-select_idle_mask-to-select_rq_mask.patch`, `misc/sched-next/0022-sched-fair-Use-the-same-cpumask-per-PD-throughout-fi.patch`, `misc/sched-next/0023-sched-fair-Remove-task_util-from-effective-utilizati.patch`, `misc/sched-next/0024-sched-fair-Remove-the-energy-margin-in-feec.patch`, `misc/sched-next/0025-sched-core-add-forced-idle-accounting-for-cgroups.patch`, `misc/sched-next/0026-sched-core-Use-try_cmpxchg-in-set_nr_-and_not-if-_po.patch`, `misc/sched-next/0027-sched-fair-fix-case-with-reduced-capacity-CPU.patch`, `misc/sched-next/0028-sched-core-Always-flush-pending-blk_plug.patch`, `misc/sched-next/0029-nohz-full-sched-rt-Fix-missed-tick-reenabling-bug-in.patch`, `misc/sched-next/0030-sched-core-Fix-the-bug-that-task-won-t-enqueue-into-.patch`, `misc/sched-next/0031-rseq-Deprecate-RSEQ_CS_FLAG_NO_RESTART_ON_-flags.patch`, `misc/sched-next/0032-rseq-Kill-process-when-unknown-flags-are-encountered.patch`, `sched/0001-bore.patch`, `sched/0001-cacULE.patch`, `sched/0001-cacULE-cachy.patch`, `sched/0001-NEST.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`, `sched/0001-tt.patch`, `sched/0001-tt-cachy.patch`
- **6.0** (54 files): `0001-cachy.patch`, `0002-bbr2.patch`, `0003-futex-winesync.patch`, `0004-Introducing-OpenVPN-Data-Channel-Offload.patch`, `0005-mm-Introduce-the-maple-tree-with-MG-LRU.patch`, `0006-mm-multi-gen-LRU-memcg-LRU.patch`, `0007-mm-demotion-Memory-tiers-and-demotion.patch`, `0008-rtw88.patch`, `0009-lrng.patch`, `0010-folios.patch`, `0011-fixes.patch`, `0012-kallsyms.patch`, `0013-rcu.patch`, `0014-clr.patch`, `0015-ksm.patch`, `0016-THP-Shrinker.patch`, `0017-fs-patches.patch`, `0018-zstd-1.5.2.patch`, `0019-bfq.patch`, `0020-Implement-AMD-Pstate-EPP-Driver-v7.patch`, `all/0001-cachyos-base-all.patch`, `misc/0001-Add-latency-priority-for-CFS-class.patch`, `misc/0001-amd-pstate-next-and-amd-pstate-epp-v4.patch`, `misc/0001-aufs-6.0-merge-v20221031.patch`, `misc/0001-bcachefs.patch`, `misc/0001-bcachefs-after-lru.patch`, `misc/0001-bore-tuning-sysctl.patch`, `misc/0001-ck-hrtimer.patch`, `misc/0001-Clang-PGO.patch`, `misc/0001-hardened.patch`, `misc/0001-kcfi.patch`, `misc/0001-mm-add-zblock-new-allocator-for-use-via-zpool-API.patch`, `misc/0001-NEST-global.patch`, `misc/0001-NEST-global-cachy.patch`, `misc/0001-PCI-Allow-BAR-movement-during-boot-and-hotplug.patch`, `misc/0001-random-implement-getrandom-in-vDSO.patch`, `misc/0001-Reviving-the-Proxy-Execution-Series.patch`, `misc/0001-rt.patch`, `misc/0001-rust-6.0-merge-changes-from-dev-tree.patch`, `misc/0001-sched-Persistent-user-requested-affinity.patch`, `misc/0001-sched-task_struct-Introduce-classes-of-tasks.patch`, `misc/0001-sched-Userspace-Hinting-for-Task-Placement.patch`, `misc/0001-spadfs-6.0-merge-v1.0.17.patch`, `misc/0001-x86-Avoid-relocation-information-in-final-vmlinux.patch`, `misc/0001-zstd-import-upstream-v1.5.2-6.0-port.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-cacULE.patch`, `sched/0001-cacULE-cachy.patch`, `sched/0001-NEST.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`, `sched/0001-tt.patch`, `sched/0001-tt-cachy.patch`
- **6.1** (40 files): `0001-bbr2.patch`, `0002-cachy.patch`, `0003-clr.patch`, `0004-ksm.patch`, `0005-zstd-Update-to-upstream-v1.5.5.patch`, `all/0001-cachyos-base-all.patch`, `misc/0001-Add-latency-priority-for-CFS-class.patch`, `misc/0001-amd_pstate-Add-guided-autonomous-mode-support.patch`, `misc/0001-aufs-6.1-merge-v20230109.patch`, `misc/0001-bcachefs.patch`, `misc/0001-bore-tuning-sysctl.patch`, `misc/0001-Clang-PGO.patch`, `misc/0001-hardened.patch`, `misc/0001-high-hz.patch`, `misc/0001-Introduce-per-VMA-lock.patch`, `misc/0001-lrng.patch`, `misc/0001-mm-add-zblock-new-allocator-for-use-via-zpool-API.patch`, `misc/0001-mm-introduce-THP-Shrinker.patch`, `misc/0001-PCI-Allow-BAR-movement-during-boot-and-hotplug.patch`, `misc/0001-rt.patch`, `misc/0001-spadfs-6.1-merge-v1.0.17.patch`, `misc/0001-x86-sched-Avoid-unnecessary-migrations-within-SMT-do.patch`, `misc/0002-sched-Introduce-IPC-classes-for-load-balance.patch`, `misc/crypto-patches/0001-crypto-x86-ghash-fix-unaligned-access-in-ghash_setke.patch`, `misc/crypto-patches/0002-crypto-x86-ghash-use-le128-instead-of-u128.patch`, `misc/crypto-patches/0003-crypto-x86-ghash-add-comment-and-fix-broken-link.patch`, `misc/enable-resizable-bar-support-nv-driver.patch`, `misc/gcc-lto/0001-gcc-LTO-support-for-the-kernel.patch`, `misc/gcc-lto/0002-gcc-lto-no-pie.patch`, `queue-for-6.1.68/zstd-cachyos-patches/0001-zstd-6.1-merge-v1.5.5-into-kernel-tree.patch`, `queue-for-6.1.68/zstd-cachyos-patches/0002-zstd-fix-g_debuglevel-export-warning.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-cacULE-cachy.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`, `sched/0001-tt.patch`, `sched/0001-tt-cachy.patch`, `sched-dev/0001-bore.patch`, `sched-dev/0001-bore-cachy.patch`
- **6.2** (37 files): `0001-bbr2.patch`, `0002-bfq.patch`, `0003-bitmap.patch`, `0004-cachy.patch`, `0005-clr.patch`, `0006-fixes.patch`, `0007-fs-patches.patch`, `0008-Implement-amd-pstate-epp-and-amd-pstate-guided-drive.patch`, `0009-ksm.patch`, `0010-maple-lru.patch`, `0011-objtool.patch`, `0012-sched.patch`, `0013-zram.patch`, `0014-zstd-import-1.5.5.patch`, `0015-v4l2-core-add-v4l2loopback.patch`, `all/0001-cachyos-base-all.patch`, `all/0001-cachyos-base-all.tar.gz`, `misc/0001-Add-latency-priority-for-CFS-class.patch`, `misc/0001-aufs-6.2-merge-v20230227.patch`, `misc/0001-bcachefs.patch`, `misc/0001-bore-tuning-sysctl.patch`, `misc/0001-Introduce-per-VMA-lock.patch`, `misc/0001-lrng.patch`, `misc/0001-Per-VMA-locks.patch`, `misc/0001-rt.patch`, `misc/0001-sched-fair-Avoid-unnecessary-migrations-within-SMT-d.patch`, `misc/0002-sched-Introduce-classes-of-tasks-for-load-balance.patch`, `misc/gcc-lto/0001-gcc-LTO-support-for-the-kernel.patch`, `misc/gcc-lto/0002-gcc-lto-no-pie.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-bore-eevdf.patch`, `sched/0001-EEVDF.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`, `sched/0001-tt.patch`, `sched/0001-tt-cachy.patch`
- **6.3** (35 files): `0001-bbr2.patch`, `0002-bfq.patch`, `0003-cachy.patch`, `0004-fixes.patch`, `0005-fs-patches.patch`, `0006-Implement-amd-pstate-guided-driver.patch`, `0007-ksm.patch`, `0008-kvm-lru.patch`, `0009-Per-VMA-locks.patch`, `0010-sched.patch`, `0011-surface.patch`, `0012-zstd-import-1.5.5.patch`, `all/0001-cachyos-base-all.patch`, `all/0001-cachyos-base-all.tar.gz`, `misc/0001-Add-extra-version-CachyOS.patch`, `misc/0001-Add-latency-priority-for-CFS-class.patch`, `misc/0001-aufs-6.3-merge-v20230515.patch`, `misc/0001-bcachefs.patch`, `misc/0001-bore-tuning-sysctl.patch`, `misc/0001-high-hz.patch`, `misc/0001-lrng.patch`, `misc/0001-rt.patch`, `misc/0001-sched-fair-Avoid-unnecessary-migrations-within-SMT-d.patch`, `misc/0001-spadfs-6.3-merge-v1.0.17.patch`, `misc/0002-sched-Introduce-classes-of-tasks-for-load-balance.patch`, `misc/gcc-lto/0001-gcc-LTO-support-for-the-kernel.patch`, `misc/gcc-lto/0002-gcc-lto-no-pie.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-bore-eevdf.patch`, `sched/0001-EEVDF.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`, `sched/0001-tt.patch`, `sched/0001-tt-cachy.patch`
- **6.4** (26 files): `0001-amd-pref-core.patch`, `0002-bbr3.patch`, `0003-cachy.patch`, `0004-fixes.patch`, `0005-HDR.patch`, `0006-ksm.patch`, `0007-kvm-lru.patch`, `0008-zstd.patch`, `all/0001-cachyos-base-all.patch`, `misc/0001-Add-extra-version-CachyOS.patch`, `misc/0001-aufs-6.4-merge-v20230821.patch`, `misc/0001-bcachefs.patch`, `misc/0001-bore-tuning-sysctl.patch`, `misc/0001-hardened.patch`, `misc/0001-high-hz.patch`, `misc/0001-lrng.patch`, `misc/0001-rt.patch`, `misc/0001-sched-Implement-BPF-extensible-scheduler-class.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-bore-eevdf.patch`, `sched/0001-EEVDF.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`, `sched/0001-tt.patch`, `sched/0001-tt-cachy.patch`
- **6.5** (30 files): `0001-amd-hdr.patch`, `0002-amd-pref-core.patch`, `0003-bbr3.patch`, `0004-cachy.patch`, `0005-fixes.patch`, `0006-ksm.patch`, `0007-zstd.patch`, `all/0001-cachyos-base-all.patch`, `misc/0001-Add-extra-version-CachyOS.patch`, `misc/0001-aufs-6.5-merge-v20230925.patch`, `misc/0001-bcachefs.patch`, `misc/0001-bore-tuning-sysctl.patch`, `misc/0001-Clang-PGO.patch`, `misc/0001-eevdf-Disable-DELAY_DEQUEUE.patch`, `misc/0001-hardened.patch`, `misc/0001-high-hz.patch`, `misc/0001-lrng.patch`, `misc/0001-rt.patch`, `misc/0001-spadfs-6.5-merge-v1.0.18.patch`, `misc/gcc-lto/0001-gcc-lto.patch`, `misc/gcc-lto/0002-gcc-lto-no-pie.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-bore-eevdf.patch`, `sched/0001-EEVDF.patch`, `sched/0001-EEVDF-cachy.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`, `sched/0001-tt.patch`, `sched/0001-tt-cachy.patch`
- **6.6** (31 files): `0001-bbr3.patch`, `0002-cachy.patch`, `0003-fixes.patch`, `0004-ksm.patch`, `0005-zstd.patch`, `all/0001-cachyos-base-all.patch`, `misc/0001-Add-extra-GCC-optimization-flags.patch`, `misc/0001-Add-extra-version-CachyOS.patch`, `misc/0001-aufs-6.6-merge-v20231106.patch`, `misc/0001-bcachefs.patch`, `misc/0001-hardened.patch`, `misc/0001-intel-thread-director.patch`, `misc/0001-le9uo.patch`, `misc/0001-lrng.patch`, `misc/0001-openssl-provider.patch`, `misc/0001-rt.patch`, `misc/0001-spadfs-6.6-merge-v1.0.18.patch`, `misc/dkms-clang.patch`, `misc/nvidia/0001-Make-modeset-and-fbdev-default-enabled.patch`, `misc/nvidia/0002-Do-not-error-on-unkown-CPU-Type-and-add-Zen5-support.patch`, `misc/nvidia/0003-Add-IBT-Support.patch`, `misc/nvidia/0004-Fix-for-6.12.0-rc1-drm_mode_config_funcs.output_poll.patch`, `misc/nvidia/0006-silence-event-assert-until-570.patch`, `misc/nvidia/0009-fix-hdmi-names.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-bore-cachy-ext.patch`, `sched/0001-bore-cachy-rt.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`, `sched/0001-sched-ext.patch`
- **6.7** (32 files): `0001-amd-pstate.patch`, `0002-bbr3.patch`, `0003-block.patch`, `0004-cachy.patch`, `0005-fixes.patch`, `0006-ksm.patch`, `0007-zstd.patch`, `all/0001-cachyos-base-all.patch`, `misc/0001-Add-extra-GCC-optimization-flags.patch`, `misc/0001-Add-extra-version-CachyOS.patch`, `misc/0001-amd-hdr.patch`, `misc/0001-aufs-6.7-merge-v20240226.patch`, `misc/0001-hardened.patch`, `misc/0001-le9uo.patch`, `misc/0001-lrng.patch`, `misc/0001-mm-Mitigate-a-vmap-lock-contention-v3.patch`, `misc/0001-ntsync.patch`, `misc/0001-rt.patch`, `misc/0001-spadfs-6.7-merge-v1.0.18.patch`, `misc/intel/0001-intel-thread-director.patch`, `misc/nvidia/nvidia-drivers-470.223.02-gpl-pfn_valid.patch`, `misc/nvidia/nvidia-drm-hotplug-workqueue.patch`, `misc/v4l2loopback.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-bore-cachy-rt.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`, `sched/0001-sched-ext.patch`, `sched-dev/0001-bore.patch`, `sched-dev/0001-bore-cachy.patch`, `sched-dev/0001-bore-cachy-rt.patch`
- **6.8** (40 files): `0001-aes-crypto.patch`, `0002-amd-pstate.patch`, `0003-bbr3.patch`, `0004-block.patch`, `0005-cachy.patch`, `0006-fixes.patch`, `0007-handheld.patch`, `0008-ksm.patch`, `0009-ntsync.patch`, `0010-zstd.patch`, `all/0001-cachyos-base-all.patch`, `misc/0001-Add-extra-version-CachyOS.patch`, `misc/0001-aufs-6.8-merge-v20240318.patch`, `misc/0001-hardened.patch`, `misc/0001-le9uo.patch`, `misc/0001-lrng.patch`, `misc/0001-ntsync.patch`, `misc/0001-rt.patch`, `misc/0001-spadfs-6.8-merge-v1.0.18.patch`, `misc/ddcci.patch`, `misc/intel/0001-intel-thread-director.patch`, `misc/intel/0002-pcores-fair.patch`, `misc/nvidia/0001-nvidia-545.patch`, `misc/nvidia/0001-NVIDIA-Fixup-GPL-issue.patch`, `misc/nvidia/0001-NVIDIA-take-modeset-ownership-early.patch`, `misc/nvidia/make-modeset-fbdev-default.patch`, `misc/nvidia/nvidia-drm-hotplug-workqueue.patch`, `misc/nvidia/nvidia-open-gcc-ibt-sls.patch`, `misc/v4l2loopback.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-bore-cachy-ext.patch`, `sched/0001-bore-cachy-quanta.patch`, `sched/0001-bore-cachy-rt.patch`, `sched/0001-echo.patch`, `sched/0001-echo-cachy.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`, `sched/0001-sched-ext.patch`, `sched/0002-tunable-sched-slice.patch`
- **6.9** (39 files): `0001-aes-crypto.patch`, `0002-amd-pstate.patch`, `0003-bbr3.patch`, `0004-cachy.patch`, `0005-fixes.patch`, `0006-handheld.patch`, `0007-ksm.patch`, `0008-ntsync.patch`, `0009-t2.patch`, `0010-zstd.patch`, `all/0001-cachyos-base-all.patch`, `misc/0001-acpi-call.patch`, `misc/0001-Add-extra-version-CachyOS.patch`, `misc/0001-aufs-6.9-merge-v20240701.patch`, `misc/0001-hardened.patch`, `misc/0001-le9uo.patch`, `misc/0001-ntsync.patch`, `misc/0001-rt.patch`, `misc/0001-spadfs-6.9-merge-v1.0.19.patch`, `misc/0001-wifi-ath11k-Rename-QCA2066-fw-dir-to-QCA206X.patch`, `misc/0002-slab.patch`, `misc/intel/0001-intel-thread-director.patch`, `misc/nvidia/0001-nvidia-545.patch`, `misc/nvidia/0001-NVIDIA-Fixup-GPL-issue.patch`, `misc/nvidia/0001-NVIDIA-take-modeset-ownership-early.patch`, `misc/nvidia/fix-zen5.patch`, `misc/nvidia/gsp-fix-stutter.patch`, `misc/nvidia/make-modeset-fbdev-default.patch`, `misc/nvidia/nvidia-drm-hotplug-workqueue.patch`, `misc/nvidia/nvidia-open-gcc-ibt-sls.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-bore-cachy-ext.patch`, `sched/0001-bore-cachy-rt.patch`, `sched/0001-echo.patch`, `sched/0001-echo-cachy.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`, `sched/0001-sched-ext.patch`
- **6.10** (39 files): `0001-amd-pstate.patch`, `0002-bbr3.patch`, `0003-block.patch`, `0004-cachy.patch`, `0005-crypto.patch`, `0006-fixes.patch`, `0007-intel-pstate.patch`, `0008-ksm.patch`, `0009-ntsync.patch`, `0010-perf-per-core.patch`, `0011-t2.patch`, `0012-zstd.patch`, `all/0001-cachyos-base-all.patch`, `misc/0001-acpi-call.patch`, `misc/0001-Add-extra-version-CachyOS.patch`, `misc/0001-aufs-6.10-merge-v20240701.patch`, `misc/0001-autofdo.patch`, `misc/0001-BOLT-vmlinux.patch`, `misc/0001-Fix-6.10-NVIDIA.patch`, `misc/0001-handheld.patch`, `misc/0001-hardened.patch`, `misc/0001-rt.patch`, `misc/0001-spadfs-6.10-merge-v1.0.19.patch`, `misc/0001-wifi-ath11k-Rename-QCA2066-fw-dir-to-QCA206X.patch`, `misc/nvidia/0001-Make-modeset-and-fbdev-default-enabled.patch`, `misc/nvidia/0002-Do-not-error-on-unkown-CPU-Type-and-add-Zen5-support.patch`, `misc/nvidia/0003-Add-IBT-Support.patch`, `misc/nvidia/0004-Fix-for-6.12.0-rc1-drm_mode_config_funcs.output_poll.patch`, `misc/nvidia/0006-silence-event-assert-until-570.patch`, `misc/nvidia/0009-fix-hdmi-names.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-bore-cachy-ext.patch`, `sched/0001-bore-cachy-rt.patch`, `sched/0001-echo.patch`, `sched/0001-echo-cachy.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`, `sched/0001-sched-ext.patch`
- **6.11** (37 files): `0001-address-masking.patch`, `0002-amd-cache-optimizer.patch`, `0003-amd-pstate.patch`, `0004-bbr3.patch`, `0005-cachy.patch`, `0006-fixes.patch`, `0007-intel-pstate.patch`, `0008-ksm.patch`, `0009-ntsync.patch`, `0010-perf-per-core.patch`, `0011-t2.patch`, `0012-thp-shrinker.patch`, `0013-zstd.patch`, `all/0001-cachyos-base-all.patch`, `misc/0001-acpi-call.patch`, `misc/0001-aufs-6.11-merge-v20241111.patch`, `misc/0001-autofdo.patch`, `misc/0001-BOLT-vmlinux.patch`, `misc/0001-handheld.patch`, `misc/0001-hardened.patch`, `misc/0001-rt.patch`, `misc/0001-wifi-ath11k-Rename-QCA2066-fw-dir-to-QCA206X.patch`, `misc/dkms-clang.patch`, `misc/nvidia/0001-Make-modeset-and-fbdev-default-enabled.patch`, `misc/nvidia/0002-Do-not-error-on-unkown-CPU-Type-and-add-Zen5-support.patch`, `misc/nvidia/0003-Add-IBT-Support.patch`, `misc/nvidia/0004-Fix-for-6.12.0-rc1-drm_mode_config_funcs.output_poll.patch`, `misc/nvidia/0006-silence-event-assert-until-570.patch`, `misc/nvidia/0009-fix-hdmi-names.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-bore-cachy-ext.patch`, `sched/0001-bore-cachy-rt.patch`, `sched/0001-eevdf-next.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`, `sched/0001-sched-ext.patch`
- **6.12** (41 files): `0001-amd-cache-optimizer.patch`, `0002-bbr3.patch`, `0003-cachy.patch`, `0004-fixes.patch`, `0005-ntsync.patch`, `0006-t2.patch`, `0007-zstd.patch`, `all/0001-cachyos-base-all.patch`, `misc/0001-acpi-call.patch`, `misc/0001-aufs-6.12-merge-v20250106.patch`, `misc/0001-clang-polly.patch`, `misc/0001-handheld.patch`, `misc/0001-hardened.patch`, `misc/0001-preempt-lazy.patch`, `misc/0001-rt.patch`, `misc/dkms-clang.patch`, `misc/nvidia/0001-Enable-atomic-kernel-modesetting-by-default.patch`, `misc/nvidia/0002-Add-IBT-support.patch`, `misc/nvidia/0002-CFLAGS-Set-std-gnu17-for-all-compilation-flags.patch`, `misc/nvidia/0003-Kbuild-Convert-EXTRA_CFLAGS-to-ccflags-y.patch`, `misc/nvidia/0004-kernel-open-nvidia-Use-new-timer-functions-for-6.15.patch`, `misc/nvidia/0005-nvidia-uvm-Use-__iowrite64_hi_lo.patch`, `misc/nvidia/0006-nvidia-uvm-Use-page_pgmap.patch`, `misc/nvidia/0007-nvidia-uvm-Convert-make_device_exclusive_range-to-ma.patch`, `misc/nvidia/0008-kbuild-Add-workaround-for-GCC-15-Compilation.patch`, `misc/nvidia/0009-nvkms-Limit-default-maximum-TMDS-character-rate-to-3.patch`, `misc/nvidia/565/0001-Make-modeset-and-fbdev-default-enabled.patch`, `misc/nvidia/565/0002-Do-not-error-on-unkown-CPU-Type-and-add-Zen5-support.patch`, `misc/nvidia/565/0003-Add-IBT-Support.patch`, `misc/nvidia/565/0004-silence-event-assert-until-570.patch`, `misc/nvidia/565/0005-nvkms-Sanitize-trim-ELD-product-name-strings.patch`, `misc/nvidia/565/0006-crypto-Add-fix-for-6.13-Module-compilation.patch`, `misc/nvidia/565/0007-nvidia-nv-Convert-symbol-namespace-to-string-literal.patch`, `misc/nvidia/565/0008-Kbuild-Use-absolute-paths-for-symbolic-links.patch`, `misc/nvidia/565/0009-FROM-AOSC-Use-linux-aperture.c-for-removing-conflict.patch`, `misc/nvidia/565/0010-FROM-AOSC-TTM-fbdev-emulation-for-Linux-6.13.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-prjc-cachy.patch`, `sched-dev/0001-bore.patch`, `sched-dev/0001-bore-cachy.patch`
- **6.13** (42 files): `0001-amd-pstate.patch`, `0002-amd-tlb-broadcast.patch`, `0003-bbr3.patch`, `0004-cachy.patch`, `0005-crypto.patch`, `0006-fixes.patch`, `0007-itmt-core-ranking.patch`, `0008-ntsync.patch`, `0009-perf-per-core.patch`, `0010-pksm.patch`, `0011-t2.patch`, `0012-zstd.patch`, `all/0001-cachyos-base-all.patch`, `misc/0001-acpi-call.patch`, `misc/0001-aufs-6.13-merge-v20250210.patch`, `misc/0001-clang-polly.patch`, `misc/0001-handheld.patch`, `misc/0001-hardened.patch`, `misc/0001-rt-i915.patch`, `misc/dkms-clang.patch`, `misc/nvidia/0001-Enable-atomic-kernel-modesetting-by-default.patch`, `misc/nvidia/0002-Add-IBT-support.patch`, `misc/nvidia/0002-CFLAGS-Set-std-gnu17-for-all-compilation-flags.patch`, `misc/nvidia/0003-Kbuild-Convert-EXTRA_CFLAGS-to-ccflags-y.patch`, `misc/nvidia/0004-kernel-open-nvidia-Use-new-timer-functions-for-6.15.patch`, `misc/nvidia/0005-nvidia-uvm-Use-__iowrite64_hi_lo.patch`, `misc/nvidia/0006-nvidia-uvm-Use-page_pgmap.patch`, `misc/nvidia/0007-nvidia-uvm-Convert-make_device_exclusive_range-to-ma.patch`, `misc/nvidia/0008-kbuild-Add-workaround-for-GCC-15-Compilation.patch`, `misc/nvidia/565/0001-Make-modeset-and-fbdev-default-enabled.patch`, `misc/nvidia/565/0002-Do-not-error-on-unkown-CPU-Type-and-add-Zen5-support.patch`, `misc/nvidia/565/0003-Add-IBT-Support.patch`, `misc/nvidia/565/0004-silence-event-assert-until-570.patch`, `misc/nvidia/565/0005-nvkms-Sanitize-trim-ELD-product-name-strings.patch`, `misc/nvidia/565/0006-crypto-Add-fix-for-6.13-Module-compilation.patch`, `misc/nvidia/565/0007-nvidia-nv-Convert-symbol-namespace-to-string-literal.patch`, `misc/nvidia/565/0008-Kbuild-Use-absolute-paths-for-symbolic-links.patch`, `misc/nvidia/565/0009-FROM-AOSC-Use-linux-aperture.c-for-removing-conflict.patch`, `misc/nvidia/565/0010-FROM-AOSC-TTM-fbdev-emulation-for-Linux-6.13.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-prjc-cachy.patch`
- **6.14** (30 files): `0001-amd-pstate.patch`, `0002-amd-tlb-broadcast.patch`, `0003-asus.patch`, `0004-bbr3.patch`, `0005-cachy.patch`, `0006-crypto.patch`, `0007-fixes.patch`, `0008-t2.patch`, `0009-zstd.patch`, `all/0001-cachyos-base-all.patch`, `misc/0001-acpi-call.patch`, `misc/0001-aufs-6.14-merge-v20250526.patch`, `misc/0001-clang-polly.patch`, `misc/0001-handheld.patch`, `misc/0001-hardened.patch`, `misc/0001-rt-i915.patch`, `misc/dkms-clang.patch`, `misc/nvidia/0001-Enable-atomic-kernel-modesetting-by-default.patch`, `misc/nvidia/0002-Add-IBT-support.patch`, `misc/nvidia/0002-CFLAGS-Set-std-gnu17-for-all-compilation-flags.patch`, `misc/nvidia/0003-Kbuild-Convert-EXTRA_CFLAGS-to-ccflags-y.patch`, `misc/nvidia/0004-kernel-open-nvidia-Use-new-timer-functions-for-6.15.patch`, `misc/nvidia/0005-nvidia-uvm-Use-__iowrite64_hi_lo.patch`, `misc/nvidia/0006-nvidia-uvm-Use-page_pgmap.patch`, `misc/nvidia/0007-nvidia-uvm-Convert-make_device_exclusive_range-to-ma.patch`, `misc/nvidia/0008-kbuild-Add-workaround-for-GCC-15-Compilation.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`
- **6.15** (26 files): `0001-amd-pstate.patch`, `0002-asus.patch`, `0003-bbr3.patch`, `0004-cachy.patch`, `0005-fixes.patch`, `all/0001-cachyos-base-all.patch`, `misc/0001-acpi-call.patch`, `misc/0001-aufs-6.15-merge-v20250602.patch`, `misc/0001-clang-polly.patch`, `misc/0001-handheld.patch`, `misc/0001-hardened.patch`, `misc/0001-rt-i915.patch`, `misc/dkms-clang.patch`, `misc/nvidia/0001-Enable-atomic-kernel-modesetting-by-default.patch`, `misc/nvidia/0002-Add-IBT-support.patch`, `misc/nvidia/0003-Kbuild-Convert-EXTRA_CFLAGS-to-ccflags-y.patch`, `misc/nvidia/0003-Workaround-nv_vm_flags_-calling-GPL-only-code.patch`, `misc/nvidia/0004-kernel-open-nvidia-Use-new-timer-functions-for-6.15.patch`, `misc/nvidia/0005-nvidia-uvm-Use-__iowrite64_hi_lo.patch`, `misc/nvidia/0006-nvidia-uvm-Use-page_pgmap.patch`, `misc/nvidia/0007-nvidia-uvm-Convert-make_device_exclusive_range-to-ma.patch`, `misc/nvidia/0008-kbuild-Add-workaround-for-GCC-15-Compilation.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`
- **6.16** (23 files): `0001-asus.patch`, `0002-bbr3.patch`, `0003-block.patch`, `0004-cachy.patch`, `0005-fixes.patch`, `0006-t2.patch`, `all/0001-cachyos-base-all.patch`, `misc/0001-acpi-call.patch`, `misc/0001-aufs-6.16-merge-v20250922.patch`, `misc/0001-clang-polly.patch`, `misc/0001-handheld.patch`, `misc/0001-hardened.patch`, `misc/0001-rt-i915.patch`, `misc/dkms-clang.patch`, `misc/nvidia/0001-Enable-atomic-kernel-modesetting-by-default.patch`, `misc/nvidia/0002-Add-IBT-support.patch`, `misc/nvidia/0003-Workaround-nv_vm_flags_-calling-GPL-only-code.patch`, `misc/nvidia/0004-nv-dmabuf-Inline-dma_buf_attachment_is_dynamic.patch`, `misc/nvidia/0005-nvidia-uvm-Disable-SVA-support-for-6.16.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`
- **6.17** (28 files): `0001-asus.patch`, `0002-bbr3.patch`, `0003-block.patch`, `0004-cachy.patch`, `0005-fixes.patch`, `all/0001-cachyos-base-all.patch`, `misc/0001-acpi-call.patch`, `misc/0001-aufs-6.17-merge-v20251110.patch`, `misc/0001-clang-polly.patch`, `misc/0001-handheld.patch`, `misc/0001-hardened.patch`, `misc/0001-rt-i915.patch`, `misc/dkms-clang.patch`, `misc/nvidia/0001-Enable-atomic-kernel-modesetting-by-default.patch`, `misc/nvidia/0002-Add-IBT-support.patch`, `misc/nvidia/0003-Workaround-nv_vm_flags_-calling-GPL-only-code.patch`, `misc/nvidia/0004-nv-dmabuf-Inline-dma_buf_attachment_is_dynamic.patch`, `misc/nvidia/0005-nvidia-uvm-Disable-SVA-support-for-6.16.patch`, `misc/nvidia/0006-nvkms-Limit-default-maximum-TMDS-character-rate-to-3.patch`, `misc/nvidia/6.17.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`, `sched/0001-prjc-cachy-lfbmq.patch`, `sched/0001-prjc-lfbmq.patch`, `sched-dev/0001-bore.patch`, `sched-dev/0001-bore-cachy.patch`
- **6.18** (24 files): `misc/0001-acpi-call.patch`, `misc/0001-aufs-6.18-merge-v20251208.patch`, `misc/0001-clang-polly.patch`, `misc/0001-handheld.patch`, `misc/0001-hardened.patch`, `misc/0001-rt-i915.patch`, `misc/dkms-clang.patch`, `misc/nap-governor.patch`, `misc/nvidia/0001-Enable-atomic-kernel-modesetting-by-default.patch`, `misc/nvidia/0002-Add-IBT-support.patch`, `misc/nvidia/0003-nvidia-uvm-Remove-unused-get_devmap_page-parameter.patch`, `misc/nvidia/0004-nvkms-Limit-default-maximum-TMDS-character-rate-to-3.patch`, `misc/nvidia-580xx/0001-Enable-atomic-kernel-modesetting-by-default.patch`, `misc/nvidia-580xx/0002-fix-hw-cursor-kde.patch`, `misc/poc-selector.patch`, `misc/reflex-governor.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`, `sched/0001-prjc-cachy-lfbmq.patch`, `sched/0001-prjc-lfbmq.patch`, `sched-dev/0001-bore.patch`, `sched-dev/0001-bore-cachy.patch`
- **6.19** (21 files): `misc/0001-acpi-call.patch`, `misc/0001-aufs-6.19-merge-v20260223.patch`, `misc/0001-clang-polly.patch`, `misc/0001-handheld.patch`, `misc/0001-hardened.patch`, `misc/0001-rt-i915.patch`, `misc/dkms-clang.patch`, `misc/nap-governor.patch`, `misc/nvidia/0001-Enable-atomic-kernel-modesetting-by-default.patch`, `misc/nvidia/0002-Add-IBT-support.patch`, `misc/nvidia/0003-Fix-compile-for-6.19.patch`, `misc/poc-selector.patch`, `misc/reflex-governor.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`, `sched-dev/0001-bore.patch`, `sched-dev/0001-bore-cachy.patch`, `sched-dev/0001-prjc-cachy-lfbmq.patch`, `sched-dev/0001-prjc-lfbmq.patch`
- **7.0** (22 files): `misc/0001-acpi-call.patch`, `misc/0001-aufs-7.0-merge-v20260518.patch`, `misc/0001-cgroup-vram.patch`, `misc/0001-clang-polly.patch`, `misc/0001-handheld.patch`, `misc/0001-hardened.patch`, `misc/0001-rt-i915.patch`, `misc/dkms-clang.patch`, `misc/nvidia/0001-Enable-atomic-kernel-modesetting-by-default.patch`, `misc/nvidia/0002-Add-IBT-support.patch`, `misc/nvidia/0003-Fix-compile-for-6.19.patch`, `misc/nvidia/0003-fix-dsc-correct-RC-parameter-tables-to-match-VESA-DS.patch`, `misc/nvidia/0004-fix-dsc-use-bits_per_component-for-flatnessDetThresh.patch`, `misc/nvidia/0004-HACK-kernel-open-Makefile-Remove-PAHOLE_VARIABLE.patch`, `misc/nvidia/0005-fix-dp-add-Bigscreen-Beyond-VR-headset-to-WAR-databa.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`, `sched-dev/0001-prjc.patch`, `sched-dev/0001-prjc-cachy-lfbmq.patch`, `sched-dev/0001-prjc-lfbmq.patch`
- **7.1** (22 files): `misc/0001-acpi-call.patch`, `misc/0001-aufs-7.1-merge-v20260713.patch`, `misc/0001-clang-polly.patch`, `misc/0001-handheld.patch`, `misc/0001-hardened.patch`, `misc/0001-rt-i915.patch`, `misc/dkms-clang.patch`, `misc/nvidia/0001-Add-IBT-support.patch`, `misc/nvidia/0002-fix-dsc-correct-RC-parameter-tables-to-match-VESA-DS.patch`, `misc/nvidia/0003-fix-dsc-use-bits_per_component-for-flatnessDetThresh.patch`, `misc/nvidia/0004-fix-dp-add-Bigscreen-Beyond-VR-headset-to-WAR-databa.patch`, `misc/nvidia/0005-HACK-kernel-open-Makefile-Remove-PAHOLE_VARIABLE.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-prjc.patch`, `sched/0001-prjc-cachy.patch`, `sched/0001-prjc-cachy-lfbmq.patch`, `sched/0001-prjc-lfbmq.patch`, `sched-dev/0001-bore.patch`, `sched-dev/0001-bore-cachy.patch`, `sched-prjc/0001-prjc-cachy.patch`, `sched-prjc/0001-prjc-cachy-lfbmq.patch`
- **7.2** (16 files): `misc/0001-acpi-call.patch`, `misc/0001-aufs-7.2-merge-v20260914.patch`, `misc/0001-handheld.patch`, `misc/0001-hardened.patch`, `misc/0001-rt-i915.patch`, `misc/dkms-clang.patch`, `misc/nvidia/0001-make-Add-support-for-7.2-Kernel.patch`, `misc/nvidia/0002-fix-dsc-correct-RC-parameter-tables-to-match-VESA-DS.patch`, `misc/nvidia/0003-fix-dp-add-Bigscreen-Beyond-VR-headset-to-WAR-databa.patch`, `misc/nvidia-580xx/0001-Enable-atomic-kernel-modesetting-by-default.patch`, `misc/nvidia-580xx/0002-fix-hw-cursor-kde.patch`, `sched/0001-bore.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-muqss-cachy.patch`, `sched/0001-prjc-cachy.patch`, `sched-dev/0001-bore-cachy.patch`
- **7.3** (14 files): `misc/0001-acpi-call.patch`, `misc/0001-aufs-7.3-merge-v20260914.patch`, `misc/0001-handheld.patch`, `misc/0001-rt-i915.patch`, `misc/dkms-clang.patch`, `misc/nvidia/0001-fix-dsc-correct-RC-parameter-tables-to-match-VESA-DS.patch`, `misc/nvidia/0002-fix-dp-add-Bigscreen-Beyond-VR-headset-to-WAR-databa.patch`, `misc/nvidia/0003-Pass-dmem_cgroup_init-to-dmem_cgroup_register_region.patch`, `misc/nvidia/0004-Open-sysfs-config-from-the-userspace-root-on-7.3.patch`, `misc/nvidia-580xx/0001-Enable-atomic-kernel-modesetting-by-default.patch`, `misc/nvidia-580xx/0002-fix-hw-cursor-kde.patch`, `misc/r8125/0001-Remove-rtltool.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-prjc-cachy.patch`
- **7.4** (13 files): `misc/0001-acpi-call.patch`, `misc/0001-aufs-7.4-merge-v20260914.patch`, `misc/0001-rt-i915.patch`, `misc/dkms-clang.patch`, `misc/nvidia/0001-fix-dsc-correct-RC-parameter-tables-to-match-VESA-DS.patch`, `misc/nvidia/0002-fix-dp-add-Bigscreen-Beyond-VR-headset-to-WAR-databa.patch`, `misc/nvidia/0004-Open-sysfs-config-from-the-userspace-root-on-7.3.patch`, `misc/nvidia/0005-Fix-build-on-Linux-7.4.patch`, `misc/nvidia-580xx/0001-Enable-atomic-kernel-modesetting-by-default.patch`, `misc/nvidia-580xx/0002-fix-hw-cursor-kde.patch`, `misc/nvidia-580xx/0003-Fix-build-on-Linux-7.4.patch`, `sched/0001-bore-cachy.patch`, `sched/0001-prjc-cachy.patch`

---

## 2. Newest stable: 7.3 – every patch

Files (14):

| Path | Size | Author / date | Diffstat |
|---|---|---|---|
| `sched/0001-bore-cachy.patch` | 45,273 | Piotr Gorski, 2026-09-22 | 14 files, +951/-20 |
| `sched/0001-prjc-cachy.patch` | 336,798 | Piotr Gorski, 2026-08-17 ("PRJC for 7.3") | 45 files, +10313/-34 |
| `misc/0001-handheld.patch` | 1,361,448 | Peter Jung, 2026-11-18 | 181 files, +33630/-264 |
| `misc/0001-aufs-7.3-merge-v20260914.patch` | 1,002,621 | Piotr Gorski, 2026-09-29 | 130 files, +37834/-11 |
| `misc/0001-acpi-call.patch` | 15,975 | Eric Naim, 2026-02-11 | 3 files, +458 |
| `misc/0001-rt-i915.patch` | 13,011 | Eric Naim, 2026-03-26 | 12 files, +81/-35 |
| `misc/dkms-clang.patch` | 1,857 | Eric Naim, 2026-02-23 | 2 files, -6 |
| `misc/nvidia/0001-fix-dsc-correct-RC-parameter-tables-to-match-VESA-DS.patch` | 5,951 | triple-groove, 2026-02-22 | 1 file, +9/-9 |
| `misc/nvidia/0002-fix-dp-add-Bigscreen-Beyond-VR-headset-to-WAR-databa.patch` | 1,821 | triple-groove, 2026-02-22 | 1 file, +13 |
| `misc/nvidia/0003-Pass-dmem_cgroup_init-to-dmem_cgroup_register_region.patch` | 1,379 | Eric Naim, 2026-09-01 | 1 file, +10 |
| `misc/nvidia/0004-Open-sysfs-config-from-the-userspace-root-on-7.3.patch` | 1,985 | treshaun, 2026-10-20 | 1 file, +14/-1 |
| `misc/nvidia-580xx/0001-Enable-atomic-kernel-modesetting-by-default.patch` | 1,508 | Peter Jung, 2025-04-20 | 2 files, +2/-2 |
| `misc/nvidia-580xx/0002-fix-hw-cursor-kde.patch` | 1,630 | (plain diff, no header) | nvidia-drm-fb.c |
| `misc/r8125/0001-Remove-rtltool.patch` | 1,728 | (plain diff, no header) | r8125 Makefile + r8125_n.c |

All patches are single squashed commits (one `From`/`Subject` each); there are no sub-commits inside them.

### 2.1 `sched/0001-bore-cachy.patch` – BORE 7.0.0 (Burst-Oriented Response Enhancer)

Author of BORE: Masahito Suzuki (firelzrd), `SCHED_BORE_VERSION "7.0.0"`. Applies on top of the CachyOS 7.3
tree (it deletes the `CONFIG_CACHY` base-slice / migration-cost lines from `fair.c`, see below).

**What it does**
- Adds `struct bore_ctx` to `task_struct` (burst_time, prev/curr penalty, `futex_waiting`, sleep credit, two
  48-bit-timestamp+16-bit-penalty "burst caches" for subtree and thread group).
- New file `kernel/sched/bore.c`. Each task accumulates *burst time* (CPU time since it last slept/yielded).
  `calc_burst_penalty()`: `greed = log2(burst_ns)+1` in 8.8 fixed point; penalty = `(greed - offset) * scale/1024`,
  capped at 39 nice levels. With defaults (offset 24, scale 1536) a task gets no penalty while its burst is
  below 2^23 ns ≈ 8.4 ms, then +1.5 nice levels per doubling of the burst.
- `effective_prio_bore() = static_prio-100 + (penalty >> 8)` (clamped 0..39) – used by `set_load_weight()`, so
  CPU hogs get a *lower EEVDF weight*, interactive tasks keep their nice weight. Kernel threads are never penalised.
- On sleep (`dequeue_task_fair` with `DEQUEUE_SLEEP`) the burst is folded into a smoothed penalty
  (`binary_smooth`, growth limited by `sched_burst_smoothness`, decay immediate) and the sleep timestamp is stored.
- **Fork inheritance**: new processes inherit a penalty from parent or from the nearest "ancestor hub"
  (ancestor with >1 child), threads from the thread-group average; results cached for `sched_burst_cache_lifetime`.
  Uses RCU child lists (`exit.c`/`fork.c` switch `sibling` list ops to `_rcu` variants).
- **EEVDF placement tweaks** (`place_entity`): with BORE on, wakeup/initial placements get half a slice of
  virtual deadline (`vslice >>= 1` on `ENQUEUE_INITIAL|ENQUEUE_WAKEUP`); tasks woken from a **futex wait** get
  `vslice = 0` (deadline = vruntime → picked almost immediately: helps game/wine thread hand-offs);
  **sleep credit**: on wakeup the deadline is pulled earlier by `min(slept_time, sched_credit_cap_us)`.
  Delayed-dequeue requeues are treated as wakeups.
- **Slice protection / wakeup preemption** (`pick_eevdf`, `wakeup_preempt_fair`): new `do_preempt_weight()`
  lets a heavier (= less bursty, more interactive) waking task cancel the running task's RUN_TO_PARITY slice
  protection; a running task that is futex-waiting never keeps protection.
- `yield_task_fair`: yielding restarts the burst and rescales the remaining deadline.
- `switched_to_fair` resets BORE state; `sched_init_bore()` prints `BORE CPU Scheduler modification 7.0.0 by Masahito Suzuki`.
- 7.3-specific: uses `reweight_task_fair()` (made non-static) because 7.3 split `reweight_entity()`/`reweight_eevdf()` and flattened the EEVDF cgroup tree.
- **Base slice**: with BORE, `base_slice = ceil(min_base_slice / tick) * tick` (`TUNABLESCALING_NONE`, no
  CPU-count scaling). debugfs `/sys/kernel/debug/sched/base_slice_ns` becomes read-only; new writable
  `/sys/kernel/debug/sched/min_base_slice_ns`; `tunable_scaling` is removed. HZ=1000 → 2 ms; HZ=500 → 2 ms; HZ=300 → 3.33 ms; HZ=250 → 4 ms.
- Debug: `/proc/<pid>/sched` shows `bore.score`; `/proc/sched_debug` task lines get a score column.
- Removes the CachyOS-base `CONFIG_CACHY` values `sysctl_sched_base_slice = 400000` and
  `sysctl_sched_migration_cost = 400000` (so in the 7.3 cachy tree, base slice = 0.4 ms and migration cost =
  0.4 ms *without* BORE; with BORE base slice is tick-derived and migration cost back to upstream 0.5 ms).

**Kconfig**
| Option | Default | Notes |
|---|---|---|
| `CONFIG_SCHED_BORE` (init/Kconfig) | `y` | "Burst-Oriented Response Enhancer" |
| `CONFIG_MIN_BASE_SLICE_NS` (kernel/Kconfig.hz) | `2000000` | lower bound for base slice |

**sysctls (`/proc/sys/kernel/…`) – see §5 for the consolidated table.**

**Gaming / latency impact**: the main CachyOS latency feature. Keeps compositor, game render/input threads,
audio and wine/proton futex hand-offs responsive while background compiles/shader caches run; the futex fast
path and sleep credit specifically target frame-pacing hitches. Slight fairness cost to CPU hogs.

### 2.2 `sched/0001-prjc-cachy.patch` – Project C (BMQ / PDS) v7.2-r0 for 7.3

Alfred Chen's alternative scheduler replacing CFS/EEVDF entirely (`kernel/sched/alt_core.c`, 7.7k lines; `bmq.h`, `pds.h`).
- `menuconfig SCHED_ALT` **default y** (!), `choice` default `SCHED_BMQ`, alternative `SCHED_PDS`.
  CachyOS only enables it for `_cpusched=bmq`. If you apply this patch you must explicitly `-d SCHED_ALT` when you don't want it.
- When enabled it forces off: `PSI`, `NUMA_BALANCING`, `SCHED_CACHE`, `CPUSETS_V1`, `SCHED_AUTOGROUP`,
  `SCHED_CORE`, **`SCHED_CLASS_EXT` (no sched_ext)**; the `-cachy` variant also makes `SCHED_POC_SELECTOR` depend on `!SCHED_ALT`.
- Knobs: sysctl `kernel.yield_type` (0 = no yield, 1 = requeue, default 1); base slice 4 MiB-ns ≈ 4.19 ms
  (`sysctl_sched_base_slice = 4<<20`, debugfs `base_slice_ns`); boot param `pcore_cpus=<cpulist>` (hybrid P-core
  mask); `sched_timeslice_shift` 23 (PDS). Also touches rtmutex, cpufreq_schedutil, posix-cpu-timers, workqueue, f2fs, cpuset.
- Gaming impact: very low-latency desktop scheduler but loses sched_ext, PSI (breaks systemd-oomd), autogroup. Not
  the CachyOS default. For linux-brook: optional flavour only.

### 2.3 `misc/0001-handheld.patch` – handheld / Steam Deck / gaming-device support (181 files)

Squashed collection (Valve's Steam Deck kernel bits, ASUS Ally, MSI Claw, Zotac Zone, GPD, AYANEO, OneXPlayer, Legion Go).

New Kconfig options:
| Option | Type | Purpose |
|---|---|---|
| `MFD_STEAMDECK` | tristate, depends ACPI && X86_64 | Valve Steam Deck MFD (EC) core |
| `EXTCON_STEAMDECK` | tristate, dep MFD_STEAMDECK | USB-C role/extcon for Deck (dwc3-pci now uses `linux,extcon-name=steamdeck-extcon`) |
| `SENSORS_STEAMDECK` | tristate | `steamdeck-hwmon` (fan/temps/battery) |
| `LEDS_STEAMDECK` | tristate | Deck power LED |
| `LEDS_VALVE` | tristate | "LED Support for Valve Freemont" (`leds/rgb/leds-valve.c`, 771 lines) |
| `HID_ASUS_ALLY` | tristate | ROG Ally gamepad config (`hid-asus-ally.c`, 2.3k lines: remap, deadzones, RGB, gyro) |
| `ZOTAC_ZONE_HID` | tristate | Zotac Zone controller/RGB HID driver (xpad's 0x1ee9 entry disabled when reachable) |
| `ZOTAC_ZONE_PLATFORM` | tristate | Zotac Zone platform driver (fan, TDP via fw-attributes/platform_profile) |
| `SND_SOC_AW87XXX` | tristate, dep I2C | Awinic AW87xxx smart PA (AYANEO etc. speakers) |
| (existing) `I2C_PIIX4` | now `depends on … && X86` | |

New module params / sysfs / uevents:
- `ttm.pages_min` (ulong) – minimum TTM page pool limit (more GTT for iGPU handhelds).
- `/sys/power/lps0_screen_off` – trigger ACPI LPS0 "Display Off/On" DSM from userspace (fan/TDP drop when screen off, gamescope uses it).
- DRM uevent `RESET=1 PID= NAME= FLAGS=` on amdgpu GPU reset (`drm_sysfs_reset_event`) – Steam uses it to detect GPU hangs.
- USB uevent `USB_NOT_ENOUGH_BANDWIDTH=1`.
- cros-ec debugfs `cec_phys_addr`, `cec_wake_enable`; ath11k `test_interface` param (unitest).

AMD GPU / display changes:
- **`amdgpu_dm_commit_planes`: `vrr_active = true` unconditionally** ("Hack: Make unconditional") – keeps
  VRR-style flip timing always on (Steam Deck/gamescope behaviour).
- `force_disable_subvp = true` on DCN3.2/3.21/4.01 (RDNA3/RDNA4 dGPUs) – avoids SubVP flicker/hangs.
- DCN3.01 (Van Gogh/Deck) `max_slave_planes` 2→3 (extra overlay plane for gamescope).
- IH ring overflow now sets `ih->overflow` on all IH versions and re-processes fences (lost-fence fix).
- gfx v10 CSIB submitted only once (`csib_initialized`) – resume fix; soft-recovery deadline fix.
- Hibernation: amdgpu thaw returns `-EBUSY` + `dev->power.is_frozen` so PM core skips thaw (faster S4 on handhelds); new `dpm_resume_suspended_devices()`.
- eDP: no "common modes" added; KT50X0 DP branch (Deck dock) quirks; DP-alt-mode wait 200 ms→500 ms; backlight bookkeeping fix.
- fbdev client not created for `virtio_gpu`.

Panel/backlight quirks: orientation quirks for AOKZOE A1/A2 Pro, AYANEO 2S/3/FLIP DS/NEO 2021, GPD Win Max 2021/Pocket 4,
OneXPlayer X1/X1 mini/X1Air/X1Pro/F1/G1 family, Zotac Zone, Tectoy Zeenix, Mysten SuiPlay0X1; min-brightness=1 for Steam Deck (Jupiter/Galileo).

Power management / ACPI:
- Steam Deck: s2idle refused (`"Steam Deck quirk - no s2idle allowed!"`) – Deck uses S3.
- MSI Claw A8 / 8 EX AI+ (MS-1T8K/MS-1T91): EC no-wakeup, derived battery rate, RTS525A/RTS5264 card reader fixes, SD-Express runtime-D3 block, forced ASPM L1/L1.2 for S0ix, degraded-link reset worker.
- Power button: KEY_POWER during suspend/hibernate is consumed as a wakeup (prevents double suspend); ACPI button "hard" wakeups.
- Hibernation aborts image write/power-down when a wakeup is pending.
- pinctrl-amd: bounded wait (Cirrus amp quirk, ROG Ally X/Legion Go).
- PCI: LTR re-enable on hot-add, `no_runtime_d3` flag, AER replay-timer masking (GL975x/RTS5264).

Other: uinput interruptible wait (Steam Input hang fix), xpad, hid-multitouch, hid-asus, hid-msi; Bluetooth
(btrtl RTL firmware, 200 ms delayed power-on, wake-capable accept list, user-term disconnect on suspend);
ath11k (QCA2066 in Deck OLED: MHI firmware reload, regdb), ath12k, rtw89 regd; Wi-Fi world regdomain now
allows passive 6 GHz; backlight uevents disabled ("Celeste re-enumerates controllers"); audio: ALC269 headphone fixups,
cs35l41, max98388 (Ally X), nau8821 (Deck), SOF PM; MMC/rtsx SD-Express + trim-quirk; vhci_hcd always suspends.

Gaming impact: essential for handheld PCs (controllers, fans, TDP, panels, sleep); the AMD display hacks
(`vrr_active=true`, SubVP off) also affect desktop AMD GPUs – evaluate before shipping in a desktop kernel.

### 2.4 `misc/0001-aufs-7.3-merge-v20260914.patch`
AUFS (Advanced multi-layered unification filesystem) v20260914 for 7.3 – `fs/aufs/*` (130 files).
Kconfig: `AUFS_FS` (tristate), `AUFS_BRANCH_MAX_127|511|1023|32767` (choice), `AUFS_SBILIST` (def y),
`AUFS_HNOTIFY`, `AUFS_HFSNOTIFY`, `AUFS_EXPORT`, `AUFS_INO_T_64` (def y), `AUFS_XATTR`, `AUFS_FHSM`,
`AUFS_RDU`, `AUFS_DIRREN`, `AUFS_SHWH`, `AUFS_BR_RAMFS`, `AUFS_BR_FUSE`, `AUFS_POLL`, `AUFS_BR_HFSPLUS` (def y),
`AUFS_BDEV_LOOP` (def y), `AUFS_DEBUG`, `AUFS_MAGIC_SYSRQ`. No gaming impact (live-ISO/overlay use only).

### 2.5 `misc/0001-acpi-call.patch`
Builds the `acpi_call` module in-tree (`drivers/platform/x86/acpi_call.c`, Michal Kottman):
`/proc/acpi/call` lets root invoke arbitrary ACPI methods (used for dGPU power-off, Legion/ThinkPad battery
thresholds, handheld TDP scripts). Kconfig `CONFIG_ACPI_CALL` (tristate, no default). No latency impact; security-sensitive.

### 2.6 `misc/0001-rt-i915.patch`
Makes i915 usable with `PREEMPT_RT` (used by `_cpusched=rt|rt-bore`): drops `depends on !PREEMPT_RT` from
`DRM_I915`, no `local_irq_disable()` around vblank evasion on RT, `spin_lock_irqsave` uncore sections,
`spin_lock_irq` in execlists dequeue, `rcu_preempt_depth()` atomic checks, `NOTRACE` for i915 tracepoints on RT,
and `/sys/kernel/realtime` (=1 on RT kernels). Only relevant for an RT flavour.

### 2.7 `misc/dkms-clang.patch`
Removes `-Werror=unknown-warning-option`, `-Werror=unused-command-line-argument` (Makefile.clang) and
`-Werror=strict-prototypes`, `-Werror=incompatible-pointer-types` (Makefile.warn) so out-of-tree DKMS modules
(NVIDIA, VirtualBox, etc.) build against a clang/LTO-built kernel. Needed if linux-brook is built with LLVM.

### 2.8 NVIDIA open-module patches (`misc/nvidia/`, applied to `NVIDIA-kernel-module-source`, not the kernel)
- `0001-fix-dsc-…`: corrects VESA DSC 1.1 RC tables (8 bpc / 8 bpp) – fixes "rainbow static" on DSC sinks (Bigscreen Beyond VR).
- `0002-fix-dp-…Bigscreen-Beyond…`: DP WAR entry forcing 4-lane HBR2 for Bigscreen Beyond (0x2709/0x1234).
- `0003-Pass-dmem_cgroup_init…`: build fix for 7.3 `dmem_cgroup_register_region()` API change.
- `0004-Open-sysfs-config-from-the-userspace-root-on-7.3`: `scoped_with_init_fs()` so runtime D3 (fine-grained PM) works again on 7.3 laptops.

### 2.9 NVIDIA 580xx legacy-branch patches (`misc/nvidia-580xx/`)
- `0001-Enable-atomic-kernel-modesetting-by-default`: `nvidia-drm` modeset/atomic on by default (Wayland).
- `0002-fix-hw-cursor-kde`: always create an NvKms surface for framebuffers (fixes HW cursor on KDE when sysmem-backed).

### 2.10 `misc/r8125/0001-Remove-rtltool.patch`
For the out-of-tree Realtek r8125 2.5GbE driver: drops `rtltool.o` and the `SIOCRTLTOOL` private ioctl (raw register access) – build/security fix.

---

## 3. Newest rc: 7.4 – differences from 7.3

Files (13): `misc/0001-acpi-call.patch` (rebased), `misc/0001-aufs-7.4-merge-v20260914.patch` (rebased),
`misc/0001-rt-i915.patch` (8 files, +74/-19 – part of it upstreamed), `misc/dkms-clang.patch` (unchanged),
`misc/nvidia/0001-fix-dsc…`, `0002-fix-dp…`, `0004-Open-sysfs…` (same), **new** `misc/nvidia/0005-Fix-build-on-Linux-7.4.patch`
(VM_SPECIAL removal → `vma_is_mm_backed()`/`vma_is_hugetlb()`, `drm_fb_helper.h` moved to `drm/clients/drm_fbdev_helper.h`),
`misc/nvidia-580xx/0001`, `0002` (same), **new** `misc/nvidia-580xx/0003-Fix-build-on-Linux-7.4.patch` (fbdev header +
backport of `atomic_create_state` for plane/CRTC because `.reset` hooks were removed), `sched/0001-bore-cachy.patch`
(BORE 7.0.0, essentially identical to 7.3: +946/-19, only context/hunk differences in slice protection / requeue code),
`sched/0001-prjc-cachy.patch` ("PRJC for 7.4", +10145/-34).
Not (yet) present for 7.4: `0001-handheld.patch`, `nvidia/0003-dmem…` (no longer needed), `r8125`.

Recent history worth knowing (from 7.0–7.2 directories):
- 7.2 `sched/0001-muqss-cachy.patch` (6 commits): *Revert POC*, *Revert gaming-sched*, *muqss-cachy*, PSI fix, CK sync,
  rt_mutex futex hooks. The reverts reveal two **CachyOS-base scheduler features** in the 7.x tree:
  - `CONFIG_SCHED_POC_SELECTOR` "Piece-Of-Cake Fast Idle CPU Selector" (default y, depends SMP): per-LLC cached idle
    bitmasks inspired by the scx_cake BPF scheduler; speeds up `select_idle_cpu` on wakeup (`kernel/sched/poc_selector.c`, ~2k lines).
  - "gaming-sched": flattened EEVDF cgroup scheduling (`cgroup_mode` debugfs, `cpuset_num_cpus`) – upstream in 7.3.
- 7.2 `sched-dev/0001-bore-cachy.patch`, 7.1 `sched-dev/`, `sched-prjc/`: development BORE/PRJC.
- `0001-hardened.patch` exists up to 7.2, `0001-cgroup-vram.patch` only 7.0, `0001-clang-polly.patch` up to 7.1.

---

## 4. CachyOS base ("cachyos-base-all") broken down – last in-repo version 6.17

For 6.18+ the same content is maintained as commits in https://github.com/CachyOS/linux (branch/tag
`cachyos-<ver>-<rel>`), so the 6.17 split is the best in-repo reference. 6.17 base = 5 squashed commits
(`[PATCH n/5]`, Peter Jung, 2025-12-18):

### 4.1 `0001-asus.patch` (15 files, +5583/-85)
`hid-asus-ally.c/.h` (ROG Ally gamepad), `asus-armoury.c/.h` (firmware-attributes: PPT limits, GPU MUX, dGPU
disable, mini-LED, panel OD…), `asus-wmi` changes + LED IDs; old asus-wmi sysfs marked "DEPRECATED, use asus-armoury".
Kconfig: `HID_ASUS_ALLY`, `ASUS_ARMOURY` (drivers/platform/x86). Gaming impact: TDP/fan/RGB control on ASUS laptops & Ally.
(In 7.3 the Ally HID driver is carried in `misc/0001-handheld.patch`.)

### 4.2 `0002-bbr3.patch` (16 files, +1941/-555)
Google BBRv3 TCP congestion control replacing `tcp_bbr.c` (ECN-aware, loss-tolerant, `tso_segs` CA hook,
`inet_diag` BBR info, `TCP_CONG_BBR` help text). Selected as default only if PKGBUILD `_tcp_bbr3=yes`
(→ `TCP_CONG_BBR=y`, `DEFAULT_BBR`, and typically `net.core.default_qdisc=fq`). Impact: lower bufferbloat/latency for online games and downloads.

### 4.3 `0003-block.patch` (3 files, +70/-13)
BFQ and mq-deadline lock-contention fixes (Jens Axboe series): `spin_trylock` in bio-merge paths, skip dispatch if
another CPU is already dispatching (`BFQ_DISPATCHING`), insert_request takes `request_queue`. Impact: less I/O
scheduler overhead at high IOPS (NVMe game loading).

### 4.4 `0004-cachy.patch` (67 files, +8447/-76) – the "Cachy sauce"

| Area | Change | Kconfig / knob (default) |
|---|---|---|
| Master switch | `config CACHY "Some kernel tweaks by CachyOS"` | `CONFIG_CACHY` **y** |
| Compiler | `-O3` option; `-fmodulo-sched -fmodulo-sched-allow-regmoves -fivopts` always added (cc-option) | `CC_OPTIMIZE_FOR_PERFORMANCE_O3` (choice; PKGBUILD `_cc_harder=yes`) |
| -march | choice "x86_64 Compiler Build Optimization": `GENERIC_CPU` (default) / `MZEN4` (`-march=znver4`) / `X86_NATIVE_CPU`; `X86_64_VERSION` int 1–4 → `-march=x86-64-vN` | `GENERIC_CPU`, `MZEN4`, `X86_64_VERSION` |
| LTO | ThinLTO default when `LTO_CLANG`; new **distributed ThinLTO** (`scripts/Makefile.thinlto`, `Makefile.vmlinux_a`, modpost `.thinlto-native.o`) | `LTO_CLANG_THIN_DIST` |
| Timer | HZ 500/600/750 choices added | `HZ_500`, `HZ_600`, `HZ_750` (PKGBUILD default 1000) |
| Preempt | `PREEMPT_RT` no longer needs `EXPERT` | – |
| EEVDF tuning (CACHY) | `sysctl_sched_base_slice` 0.70 ms → **0.35 ms** (7.x tree: 0.4 ms); `sched_migration_cost` 0.5 ms → **0.3 ms** (7.x: 0.4 ms); `sched_cfs_bandwidth_slice` 5 ms → **3 ms**; `SCHED_NR_MIGRATE_BREAK` 32 → **8** | via `CONFIG_CACHY` |
| ADIOS I/O scheduler | `block/adios.c` "Adaptive Deadline I/O Scheduler" v3.1.7 (Masahito Suzuki): learning latency model per op type, batch dispatch | `MQ_IOSCHED_ADIOS` (**m**), `MQ_IOSCHED_DEFAULT_ADIOS` (n). sysfs tunables per queue: `batch_actual_max`(ro), `bq_refill_below_ratio`, `global_latency_window`, `lat_model_latency_limit`, `batch_order`, `compliance_flags`, `batch_limit_{read,write,discard}`, `lat_model_{read,write,discard}`, `lat_target_{read,write,discard}`, `shrink_at_kreqs`, `shrink_at_gbytes`, `shrink_resist`, `read_priority`, `reset_bq_stats`(wo), `reset_lat_model`(wo), `adios_version` |
| Default elevator | CACHY: single-queue devices default to **BFQ** (if built) instead of mq-deadline; ADIOS if `DEFAULT_ADIOS` | – |
| le9uo working-set protection (`mm/vmscan.c`, `mm/util.c`) | hard/soft protection of anon & clean file pages against reclaim (prevents stutter/thrashing under memory pressure) | `ANON_MIN_RATIO` (**1**), `CLEAN_LOW_RATIO` (**15**), `CLEAN_MIN_RATIO` (**4**); sysctls `vm.workingset_protection` (bool, on), `vm.anon_min_ratio`, `vm.clean_low_ratio`, `vm.clean_min_ratio`; boot log "le9 Unofficial (le9uo) working set protection 1.15a" |
| MM defaults (CACHY) | `dirty_background_ratio` 10→**5**; `dirty_writeback_interval` 5 s→**10 s**; swap `page_cluster` → **0** (no swap readahead, zram-friendly); `vmpressure_level_med` 60→**65**; `compaction_proactiveness` 20→**0**; `COMPACT_UNEVICTABLE_DEFAULT` → **0**; THP defrag → `defer+madvise` (`DEFRAG_KSWAPD_OR_MADV`); `watermark_boost_factor` 15000→**0**; `VM_READAHEAD_PAGES` 128 KiB→**8 MiB** | via `CONFIG_CACHY` |
| Locking | `rwsem_spin_on_owner`: `cpu_relax()` only after 1000 spins | – |
| Split-lock | `sysctl_sld_mitigate` 1 → **0** (no split-lock slowdown penalty; fixes some Windows games under Proton) | `kernel.split_lock_mitigate` default 0 |
| Input | evdev client freed via `call_rcu` instead of `synchronize_rcu()` (faster device close, no stalls for Steam Input) | – |
| User namespaces | `kernel.unprivileged_userns_clone` sysctl | `USER_NS_UNPRIVILEGED` (**y** → sysctl 1) |
| cpufreq | intel_pstate/amd_pstate no longer force-select schedutil; `intel_pstate=enable` | – |
| AMD GPU | `amdgpu.ignore_min_pcap=1` lets you set power cap below firmware minimum (undervolting/handheld TDP) | module param, default 0 |
| AMD color / HDR | Steam Deck/gamescope **AMD private color properties** (per-plane degamma/shaper/3D-LUT/blend TF – used for HDR in gamescope/KDE) | `AMD_PRIVATE_COLOR` (n) |
| PCIe ACS override | `pcie_acs_override=downstream,multifunction,id:vvvv:dddd` (VFIO GPU passthrough) | boot param |
| Intel NVMe remap | `drivers/pci/controller/intel-nvme-remap.c` – exposes NVMe behind Intel RST "RAID" AHCI | built when `X86_64 && SATA_AHCI` |
| Drivers bundled | `v4l2loopback` (OBS virtual cam), `vhba` (CDEmu) | `V4L2_LOOPBACK`, `VHBA` |
| Misc | GPU drivers moved later in link order (after ata/nvme, faster boot), `.gitignore` | – |

### 4.5 `0005-fixes.patch` (3 files)
CACHY: disables the Zen5 RDSEED32 microcode check; i915 PSR flush fix; `scripts/package/PKGBUILD` installs `resolve_btfids` for headers.

Things often associated with CachyOS that are **not** separate patches at 7.3 (file names checked across all
version dirs): ntsync (separate `ntsync` patches only in 6.7–6.13; upstream since 6.14), futex/fsync (only in
5.15–6.0 era dirs; upstream `futex_waitv` since 5.16), zstd update patches (up to 6.14), Clear Linux patches
(5.15–5.18 only), amd-pstate patches (up to 6.15; now upstream), LRU/le9 patches (old dirs; now le9uo inside the
base), HDR (upstream color pipeline + `AMD_PRIVATE_COLOR` in base).

---

## 5. All sysctl / Kconfig knobs introduced by BORE and the Cachy base (with defaults)

### BORE (7.3 `0001-bore-cachy.patch`) – `/proc/sys/kernel/`
| sysctl | Type / range | Default | Meaning |
|---|---|---|---|
| `kernel.sched_bore` | u8 0–1 | **1** | master on/off (static key; re-weights all tasks on change) |
| `kernel.sched_burst_inherit_type` | u8 0–2 | **2** | 0 = no inheritance, 1 = from parent, 2 = from ancestor hub (threads always from thread group) |
| `kernel.sched_burst_smoothness` | u8 0–3 | **1** | penalty growth smoothing shift (higher = slower to penalise) |
| `kernel.sched_burst_penalty_offset` | u8 0–63 | **24** | log2(ns) burst tolerated without penalty (24 → ~8.4 ms) |
| `kernel.sched_burst_penalty_scale` | uint 0–4095 | **1536** | penalty slope (/1024 → 1.5 nice levels per burst doubling) |
| `kernel.sched_burst_cache_lifetime` | uint (ns) | **75000000** (75 ms) | lifetime of fork-inheritance caches |
| `kernel.sched_burst_protect_slice_lv` | u8 0–3 | **1** | 0 = never honour slice protection; 1 = protect, strictly heavier waker may preempt; 2 = protect, equal-or-heavier may preempt; 3 = protect, no weight preemption |
| `kernel.sched_credit_cap_us` | uint 0–1,000,000 | **16000** (16 ms) | max sleep credit subtracted from wake-up deadline; 0 disables |
| debugfs `sched/min_base_slice_ns` | uint | `CONFIG_MIN_BASE_SLICE_NS` = **2000000** | base slice = smallest multiple of tick ≥ this |
| debugfs `sched/base_slice_ns` | read-only | tick-derived (2 ms @1000 Hz) | |
| `sched_tunable_scaling` | – | NONE | (debugfs file removed) |
| Kconfig `SCHED_BORE` | bool | **y** | |
| Kconfig `MIN_BASE_SLICE_NS` | int | **2000000** | |

### PRJC (if used)
`kernel.yield_type` (0/1, default 1); base slice 4<<20 ns; `pcore_cpus=` boot param; Kconfig `SCHED_ALT` (default y), `SCHED_BMQ` (default choice) / `SCHED_PDS`.

### Cachy base (6.17 reference, carried forward in CachyOS/linux 7.x)
| Knob | Default |
|---|---|
| `CONFIG_CACHY` | y |
| `CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3` | choice (PKGBUILD selects) |
| `CONFIG_GENERIC_CPU` / `CONFIG_MZEN4` / `CONFIG_X86_NATIVE_CPU` | GENERIC_CPU |
| `CONFIG_X86_64_VERSION` | int 1–4 (CachyOS repos ship v3/v4/znver4 builds) |
| `CONFIG_HZ_500/600/750` | not default (PKGBUILD HZ=1000) |
| `CONFIG_LTO_CLANG_THIN_DIST` | n |
| `CONFIG_MQ_IOSCHED_ADIOS` | m |
| `CONFIG_MQ_IOSCHED_DEFAULT_ADIOS` | n |
| `CONFIG_ANON_MIN_RATIO` → `vm.anon_min_ratio` | 1 |
| `CONFIG_CLEAN_LOW_RATIO` → `vm.clean_low_ratio` | 15 |
| `CONFIG_CLEAN_MIN_RATIO` → `vm.clean_min_ratio` | 4 |
| `vm.workingset_protection` | 1 (true) |
| `CONFIG_USER_NS_UNPRIVILEGED` → `kernel.unprivileged_userns_clone` | y → 1 |
| `CONFIG_AMD_PRIVATE_COLOR` | n (CachyOS config enables it for gamescope HDR) |
| `CONFIG_V4L2_LOOPBACK`, `CONFIG_VHBA` | tristate (no default) |
| `CONFIG_SCHED_POC_SELECTOR` (7.x base) | y |
| `amdgpu.ignore_min_pcap` | 0 |
| `pcie_acs_override=` | unset |
| EEVDF base slice (CACHY, no BORE) | 0.35 ms (6.17) / 0.4 ms (7.x) |
| `sched_migration_cost` (CACHY) | 0.3 ms (6.17) / 0.4 ms (7.x) |
| `sched_cfs_bandwidth_slice` | 3 ms |
| `SCHED_NR_MIGRATE_BREAK` | 8 |
| `kernel.split_lock_mitigate` | 0 |
| `vm.dirty_background_ratio` | 5 |
| `vm.dirty_writeback_centisecs` | 1000 |
| `vm.page-cluster` | 0 |
| `vm.compaction_proactiveness` | 0 |
| `vm.compact_unevictable_allowed` | 0 |
| `vm.watermark_boost_factor` | 0 |
| THP defrag | defer+madvise |
| readahead `VM_READAHEAD_PAGES` | 8 MiB |
| handheld: `ttm.pages_min` | 0 (unset) |
| handheld: `/sys/power/lps0_screen_off` | 0 |

---

## 6. Files read

Downloaded archive: `C:\Users\asdf\AppData\Local\Temp\claude\faac1ebfcdbfa908\8ecb1a70-57dd-4709-906b-003f361f46b5\scratchpad\cachy\kernel-patches\src.tar.gz` → `kernel-patches-HEAD/`.

Read in full:
- `README.md`
- `7.3/sched/0001-bore-cachy.patch`
- `7.3/misc/0001-rt-i915.patch`, `7.3/misc/dkms-clang.patch`, `7.3/misc/r8125/0001-Remove-rtltool.patch`,
  `7.3/misc/nvidia-580xx/0002-fix-hw-cursor-kde.patch`
- headers/commit messages + diffstat of every file in `7.3/` and `7.4/` (all nvidia/nvidia-580xx patches read through their messages)
- `6.17/0005-fixes.patch`, `6.17/0003-block.patch` (all +/- lines)

Read in part (headers, diffstat, all Kconfig/sysctl/module_param hunks, all core-kernel hunks):
- `7.3/misc/0001-handheld.patch` (lines 1–2310, 9913–9997, 12526–12885, 15790–16480 + Kconfig/param/DMI greps; driver bodies for asus-ally/zotac/aw87xxx/leds/msi-wmi not read line by line)
- `7.3/sched/0001-prjc-cachy.patch` (diffstat, docs, init/Kconfig, Kconfig.preempt, alt_core header, alt_topology params, sysctl table)
- `7.3/misc/0001-aufs-7.3-merge-v20260914.patch` (header + all Kconfig entries)
- `7.3/misc/0001-acpi-call.patch` (header, Kconfig, Makefile, start of acpi_call.c)
- `7.4/sched/0001-bore-cachy.patch` (diffed against 7.3)
- `7.1/sched/0001-prjc.patch` vs `0001-prjc-cachy.patch` (diff), `7.2/sched/0001-bore.patch` vs `0001-bore-cachy.patch`
- `7.2/sched/0001-muqss-cachy.patch` (commit subjects, Revert POC / Revert gaming-sched sections, Kconfig list)
- `6.17/all/0001-cachyos-base-all.patch` (header), `6.17/0001-asus.patch` (diffstat), `6.17/0002-bbr3.patch` (diffstat + Kconfig),
  `6.17/0004-cachy.patch` (diffstat + every non-driver hunk: Makefile, arch/Kconfig, Kconfig.cpu, x86 Makefile,
  Kconfig.iosched, init/Kconfig, Kconfig.hz, Kconfig.preempt, sysctl.c, fair.c, sched.h, mm/*, fork.c,
  user_namespace, cpufreq, amdgpu, evdev, rwsem, pagemap.h, bus_lock.c, elevator.c, ahci.c, pci quirks (ACS),
  scripts; ADIOS version/sysfs attribute list)
- directory listings of all versions (5.15 … 7.4)

External (context only): `https://raw.githubusercontent.com/CachyOS/linux-cachyos/master/linux-cachyos/PKGBUILD`
(version 7.3.6, source tarball, option defaults, which patches are applied).
