# CachyOS system-level tuning: what CachyOS ships and what BrookOS can copy

Source snapshot: the `HEAD` tarballs of 13 CachyOS GitHub repos, downloaded 2026-11-25 from `codeload.github.com`. Fork diffs come from the GitHub compare API (upstream default branch against the CachyOS default branch).
Verbatim copy of `CachyOS-Settings` `usr/` and `etc/` (55 files): `docs/cachyos/cachyos-settings-src/`.

Notation: paths are relative to each repo root unless stated otherwise. Values are quoted exactly from the files.

---

## 0. TL;DR: BrookOS adoption checklist

| Area | CachyOS value | Where |
|---|---|---|
| Swappiness | `vm.swappiness = 100` (raised to `150` by udev when zram0 initialises) | `usr/lib/sysctl.d/70-cachyos-settings.conf`, `usr/lib/udev/rules.d/30-zram.rules` |
| VFS cache | `vm.vfs_cache_pressure = 50` | sysctl.d |
| Dirty memory | `vm.dirty_ratio = 10`, `vm.dirty_background_ratio = 3`, plus a 256 MiB per-device cap (16 MiB for USB) on slow disks | sysctl.d, `61-writeback-limits.rules` |
| Swap readahead | `vm.page-cluster = 0` | sysctl.d |
| Watchdogs | `kernel.nmi_watchdog = 0`; blacklist `iTCO_wdt`, `sp5100_tco`, `wdat_wdt` | sysctl.d, `modprobe.d/blacklist.conf` |
| zram | `zstd`, `zram-size = ram`, `swap-priority = 100`; zswap disabled when zram is up | `usr/lib/systemd/zram-generator.conf` |
| THP | `defrag = defer+madvise`; `khugepaged/max_ptes_none = 409` (the tuned profile also sets `transparent_hugepages=always`) | `tmpfiles.d/thp*.conf`, tuned `cachyos-common` |
| I/O schedulers | HDD `bfq`, SATA SSD/eMMC `mq-deadline`, NVMe `kyber` | `60-ioschedulers.rules` |
| SATA ALPM | `max_performance` | `50-sata.rules` |
| NTSync | module `ntsync` loaded at boot | `modules-load.d/ntsync.conf` |
| NVIDIA | `NVreg_InitializeSystemMemoryAllocations=0`; runtime PM `auto` on bind; `NVreg_DynamicPowerManagement=0x02` only for Turing laptops (chwd) | `modprobe.d/nvidia.conf`, `71-nvidia.rules`, chwd |
| systemd | `DefaultTimeoutStopSec=10s`; `DefaultLimitNOFILE=2048:2097152` (system) / `1024:1048576` (user); journal `SystemMaxUse=50M`; coredumps cleaned after 3 days; systemd-oomd kill at 80% memory pressure | `system.conf.d`, `user.conf.d`, `journald.conf.d`, `tmpfiles.d/coredump.conf` |
| Realtime audio | `@audio - rtprio 99`, `@audio - nice -11`; rtc0, hpet and cpu_dma_latency owned by group `audio` | `etc/security/limits.d/20-audio.conf`, udev |
| Process priority | ananicy-cpp with the CachyOS rules (15,820 rules, 13,528 of them `Game`) | `ananicy-rules` |
| Scheduler (sched-ext) | gaming and handhelds: `scx_lavd` in Gaming mode (`--performance`); desktop: `scx_bpfland` | Handheld README, tuned profiles |
| Power profiles | tuned-ppd maps power-saver, balanced and performance to `cachyos-powersave`, `cachyos-desktop` and `cachyos-gaming` | tuned `tuned/ppd/ppd.conf` |
| Per-game boost | `game-performance %command%` runs the game under `powerprofilesctl launch -p performance` | `usr/bin/game-performance` |

**Not found in any of the 13 repos:** `kernel.split_lock_mitigate`, `kernel.sched_*` sysctls, `net.ipv4.tcp_congestion_control`/BBR sysctls, `net.core.rmem/wmem`, and any `vm.max_map_count` override. These are presumably set in the kernel itself (linux-cachyos config and patches; the Handheld README and kernel-manager options confirm that BBRv3 is a kernel-side default) or in other packages in `CachyOS/linux-cachyos` and `CachyOS-PKGBUILDS` (e.g. `cachyos-ksm-settings`). Those repos were out of scope here, so check them for split_lock and sched settings. The only `net.*` sysctls in scope are `net.core.netdev_max_backlog = 4096` and, on handhelds, `net.ipv4.tcp_fin_timeout = 5`.

**README drift to watch for:** the `CachyOS-Settings` README describes several values that the shipped files no longer contain:
- It lists `vm.dirty_bytes`/`vm.dirty_background_bytes`, but the shipped file uses `vm.dirty_ratio = 10` and `vm.dirty_background_ratio = 3`.
- It describes `vm.dirty_writeback_centisecs`, which is absent from the shipped file.
- It claims `nvidia.conf` sets `NVreg_DynamicPowerManagement=0x02` and `NVreg_EnableS0ixPowerManagement=1`. The shipped file contains only `NVreg_InitializeSystemMemoryAllocations=0`.
- It says the THP shrinker targets kernel 6.12+.

Always copy from the files, not the README.

---

## 1. CachyOS/CachyOS-Settings (the core package, `cachyos-settings`)

### 1.1 Sysctl: `usr/lib/sysctl.d/70-cachyos-settings.conf` (full content)
```
vm.swappiness = 100
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 10
vm.page-cluster = 0
vm.dirty_background_ratio = 3
kernel.nmi_watchdog = 0
kernel.unprivileged_userns_clone = 1
kernel.printk = 3 3 3 3
kernel.kptr_restrict = 2
net.core.netdev_max_backlog = 4096
fs.file-max = 2097152
kernel.sysrq = 1
```
The file's comments explain the choices:
- `swappiness 100` means the kernel treats swap and page-cache IO as equal cost.
- `page-cluster 0` suits zram; use 1 for SSD swap or 2 for HDD swap.
- `dirty_ratio` is ratio-based so fast NVMe drives can absorb write bursts, while slow devices are capped per device.
- `sysrq = 1` allows a safe reboot when the system hangs.

### 1.2 udev rules (`usr/lib/udev/rules.d/`)
| File | Rule (exact) |
|---|---|
| `20-audio-pm.rules` | On `snd_hda_intel` card add, runs `/usr/lib/udev/audio-pm-ctl init`. On a `power_supply` Mains change it runs `audio-pm-ctl battery` (ONLINE==0) or `audio-pm-ctl ac` (ONLINE==1). The helper `usr/lib/udev/audio-pm-ctl` writes `0` to `/sys/module/snd_hda_intel/parameters/power_save` on AC and restores the stashed value on battery (default `10`); the value is stashed in `/run/udev/snd-hda-intel-powersave`. The goal is to prevent audio crackle. |
| `30-zram.rules` | `ACTION=="change", KERNEL=="zram0", ATTR{initstate}=="1", SYSCTL{vm.swappiness}="150", RUN+="/bin/sh -c 'echo N > /sys/module/zswap/parameters/enabled'"` |
| `40-hpet-permissions.rules` | `KERNEL=="rtc0", GROUP="audio"` and `KERNEL=="hpet", GROUP="audio"` |
| `50-sata.rules` | For `scsi_host` `host*` with `link_power_management_supported=="1"`: `ATTR{link_power_management_policy}="max_performance"` |
| `60-ioschedulers.rules` | `sd[a-z]*` with rotational=1 gets `bfq`. `sd[a-z]*\|mmcblk[0-9]*` with rotational=0 gets `mq-deadline`. `nvme[0-9]*` with rotational=0 gets `kyber`. |
| `61-writeback-limits.rules` | Sets `ATTR{bdi/strict_limit}="1"`. Removable disks, HDDs (`sd*` rotational) and `mmcblk*` get `ATTR{bdi/max_bytes}="268435456"` (256 MiB). USB disks (`ENV{ID_BUS}=="usb"`, rule placed last) get `"16777216"` (16 MiB). |
| `69-hdparm.rules` | Rotational ATA `sd[a-z]` (not USB): `RUN+="/usr/bin/hdparm -B 254 -S 0 /dev/%k"` (max APM, no spindown) |
| `71-nvidia.rules` | On NVIDIA PCI display-class device bind/add: `ATTR{power/control}="auto"`. On unbind/remove: `"on"`. |
| `85-iw-regulatory.rules` | On ieee80211 add, starts `cachyos-iw-set-regdomain.service` |
| `99-cpu-dma-latency.rules` | `DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"` |

### 1.3 modprobe and modules-load
- `usr/lib/modprobe.d/amdgpu.conf`: `options amdgpu si_support=1 cik_support=1` and `options radeon si_support=0 cik_support=0`
- `usr/lib/modprobe.d/blacklist.conf`: `blacklist iTCO_wdt`, `blacklist sp5100_tco`, `blacklist wdat_wdt`
- `usr/lib/modprobe.d/nvidia.conf`: `options nvidia NVreg_InitializeSystemMemoryAllocations=0`. This skips clearing system memory before GPU use, which helps performance at some security cost.
- `usr/lib/modules-load.d/ntsync.conf`: `ntsync`

### 1.4 zram and swap
- `usr/lib/systemd/zram-generator.conf`:
  ```
  [zram0]
  compression-algorithm = zstd
  zram-size = ram
  swap-priority = 100
  fs-type = swap
  ```
- `usr/lib/systemd/system-generators/xswap-generator`: if `/sys/kernel/mm/xswap` exists and has no `type*` entries, it masks zram-generator by symlinking `/run/systemd/zram-generator.conf` to `/dev/null`, then runs `echo 100 > /sys/kernel/mm/xswap/create`. This prefers the CachyOS kernel's "xswap" when available.
- `usr/lib/systemd/system/systemd-zram-setup@.service.d/xswap.conf`: `ConditionPathExistsGlob=!/sys/kernel/mm/xswap/type*`

### 1.5 systemd tweaks
| File | Content |
|---|---|
| `usr/lib/systemd/system.conf.d/00-timeout.conf` | `[Manager] DefaultTimeoutStopSec=10s` |
| `usr/lib/systemd/user.conf.d/00-timeout.conf` | `DefaultTimeoutStopSec=10s` |
| `usr/lib/systemd/system.conf.d/10-limits.conf` | `DefaultLimitNOFILE=2048:2097152` |
| `usr/lib/systemd/user.conf.d/10-limits.conf` | `DefaultLimitNOFILE=1024:1048576` |
| `usr/lib/systemd/journald.conf.d/00-journal-size.conf` | `[Journal] SystemMaxUse=50M` |
| `usr/lib/systemd/timesyncd.conf.d/10-timesyncd.conf` | `NTP=time.cloudflare.com`, `FallbackNTP=time.google.com 0..3.arch.pool.ntp.org` |
| `usr/lib/systemd/system/user@.service.d/delegate.conf` | `Delegate=cpu cpuset io memory pids` |
| `usr/lib/systemd/system/rtkit-daemon.service.d/override.conf` | `LogLevelMax=info` |
| `usr/lib/systemd/system/system.slice.d/10-oomd-per-slice-defaults.conf` | `ManagedOOMSwap=kill`, `ManagedOOMMemoryPressure=kill`, `ManagedOOMMemoryPressureLimit=80%` |
| `usr/lib/systemd/user-generators/cachyos-oomd-generator` | Writes the same three ManagedOOM keys for the user manager's `slice.d`. It skips this when `/proc/1/cgroup` is unreadable (hidepid). |
| `usr/lib/systemd/user/session.slice.d/10-ignore-session-slice.conf` | `ManagedOOMPreference=omit`, which protects the session slice |
| `usr/lib/systemd/system/pci-latency.service` | Oneshot unit that runs `/usr/bin/pci-latency`. It is not enabled by default. |
| `usr/lib/systemd/system/cachyos-iw-set-regdomain.{path,service}` | Re-runs `/usr/lib/iw-set-regdomain` when `/etc/localtime` changes. The script reads `/etc/iw-regdomain` `COUNTRY=` or derives the country from the timezone via `zone.tab`. |

### 1.6 tmpfiles
- `usr/lib/tmpfiles.d/coredump.conf`: `e /var/lib/systemd/coredump - - - 3d`
- `usr/lib/tmpfiles.d/thp.conf`: `w! /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise` (helps tcmalloc)
- `usr/lib/tmpfiles.d/thp-shrinker.conf`: `w! /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none - - - - 409`. Any THP that is more than 80% zero-filled gets split.

### 1.7 Limits, environment and other config
- `etc/security/limits.d/20-audio.conf`: `@audio - rtprio 99` / `@audio - nice  -11`
- `usr/lib/NetworkManager/conf.d/dns.conf`: `dns=systemd-resolved`
- `etc/debuginfod/cachyos.urls`: `https://debuginfod.cachyos.org`
- `usr/share/X11/xorg.conf.d/20-touchpad.conf`: libinput `Tapping True`
- `usr/share/glib-2.0/schemas/zz_cachyos.org.gnome.login-screen.gschema.override`: GDM logo
- There is no global environment-variable file in this repo. The env vars live in wrapper scripts (1.8).

### 1.8 Scripts (`usr/bin/`)
| Script | What it does |
|---|---|
| `game-performance` | Uses `powerprofilesctl`, falling back to `tlpctl`. If the CPU has no `performance:` profile it just runs the command. Otherwise: `exec systemd-inhibit --why "CachyOS game-performance is running" $PROFILE_CMD launch -p performance -r "Launched with CachyOS game-performance utility" -- "$@"`. Setting `GAME_PERFORMANCE_SCREENSAVER_ON` (any non-empty value) skips the inhibitor. Usage: Steam launch option `game-performance %command%`. |
| `kerver` | Prints `/proc/version` and `uname -a`, the x86-64 levels from `ld-linux --help`, CPU-march config grepped from `/proc/config.gz` (`CONFIG_GENERIC_CPU`, `X86_64_VERSION`, `MZEN*`, `MNATIVE_*`, `X86_NATIVE_CPU`), each block device's `queue/scheduler`, and the active sched_ext scheduler with its command-line flags (parsed from `journalctl -k`). |
| `pci-latency` | `setpci -v -s '*:*' latency_timer=20`, then `setpci -v -s '0:0' latency_timer=0`, then sound cards (`*:*:04xx`) `latency_timer=80` |
| `dlss-swapper` | Exports `PROTON_ENABLE_NGX_UPDATER=1`, `DXVK_NVAPI_DRS_NGX_DLSS_{RR,SR,FG}_OVERRIDE=on` and `DXVK_NVAPI_DRS_NGX_DLSS_{RR,SR}_OVERRIDE_RENDER_PRESET_SELECTION=render_preset_latest`, then runs the command |
| `dlss-swapper-dll` | Same as `dlss-swapper` without `PROTON_ENABLE_NGX_UPDATER` |
| `zink-run` | `MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink __GLX_VENDOR_LIBRARY_NAME=mesa __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json` |
| `topmem` | Lua (lua-luv) script: top processes by RSS, swap or KSM profit (`/proc/<pid>/ksm_stat`) |
| `cachyos-bugreport.sh` | Root only. Collects inxi, sched_ext state, dmesg and journal, redacts hostname, user, SSIDs, IP, MAC, email and UUIDs, then offers to upload to paste.cachyos.org. |
| `paste-cachyos` | Uploads with curl to `https://paste.cachyos.org` |
| `sbctl-batch-sign` | Signs every unsigned ESP file, skipping MS/Windows, `.mui`, `.dll`, grub and files signed with the CachyOS EAC CA. Refuses to run with Limine. |
| `eac-setup` / `eac-status` | Easy Anti-Cheat v2 setup and check. Requires Secure Boot and TPM, plus a separate "CachyOS EAC" boot entry with `lockdown=integrity lsm=landlock,lockdown,yama,integrity,bpf iommu.passthrough=0 intel_iommu=on module.sig_enforce=1 sysctl.kernel.kexec_load_disabled=1`, using the CachyOS-signed systemd-boot and kernel. This is CachyOS-specific (it needs CachyOS signing keys), so it is not portable to BrookOS without our own signing infrastructure. |

---

## 2. CachyOS/ananicy-rules (installed to `/etc/ananicy.d/` for ananicy-cpp)

**Structure:**
- `ananicy.conf`: `check_freq = 15`, all `apply_*` flags `true` (nice, latnice, ionice, sched, oom_score_adj, cgroup), `loglevel = info`, `log_applied_rule = false`, `cgroup_realtime_workaround = false`
- `00-types.types`, the type definitions:
  | Type | Settings |
  |---|---|
  | `Game` | nice -5, ioclass best-effort, sched normal |
  | `Player-Audio` / `Player-Video` | nice -4 |
  | `Image-View` / `Doc-View` | nice -4 |
  | `LowLatency_RT` | nice -12, best-effort |
  | `BG_CPUIO` | nice 16, ioclass idle, sched idle |
  | `BG_CPU` | nice 14, best-effort, sched idle |
  | `Launcher` | nice 16, ioclass idle, sched normal |
  | `Heavy_CPU` | nice 9, best-effort, ionice 7 |
  | `Chat` | nice -3, best-effort, ionice 7 |
  | `Service` | nice 10, best-effort, ionice 6 |
  | `IN_DIFF` | nice 0, ionice 7 |
  | `OOM_KILL` / `OOM_NO_KILL` | oom_score_adj 1000 / -1000 |
- `00-cgroups.cgroups`: `cpu90`, `cpu85`, `cpu80` (CPUQuota 90/85/80). No rule uses them.
- `ananicy.schema.json`: rules can also set `latency_nice`, `rtprio`, `cgroup` and `cpuset` (`big-cores`, `little-cores`, `performance-cores`, `efficiency-cores`, `x3d-cache`, `x3d-frequency`, `llc-N`, `node-N` or core lists). No shipped rule uses cpuset.
- Rules are one JSON object per line: `{ "name": "<comm>", "type": "<Type>" }`. Tooling: `lint.py` (schema check plus duplicate-name check), `sort-games.sh`, and `Makefile` (`make install` copies to `/etc/ananicy.d/`).
- Counts: 362 `.rules` files, 15,820 rules. By type: Game 13,528, BG_CPUIO 1,615, Service 194, Doc-View 161, LowLatency_RT 112, Chat 51, other types make up the rest. `Games/wine_proton` holds 12,722 rules (one file per first letter, plus `common.rules` and non-latin) and `Games/linux-native` holds 2,242.
- The README warns against running GameMode together with ananicy-cpp because both adjust nice levels.

**Notable rules:**
- Compositors and display servers as `LowLatency_RT`: `kwin_wayland`, `kwin_x11`, `gnome-shell`, `Xorg`, `Xwayland`, `gamescope`, `gamescope-wl`
- Audio as `LowLatency_RT`: `pipewire`, `pipewire-pulse`, `wireplumber`
- Wine: `wineserver` is `LowLatency_RT`. Wine helpers `explorer.exe`, `services.exe`, `plugplay.exe` and `tabtip.exe` are `BG_CPUIO`.
- Steam: `steam` is `Launcher`, `steamwebhelper` is `Doc-View`, and the shader compiler `fossilize_replay` is `BG_CPUIO` (the rule comment says this avoids FPS spikes).
- Other launchers: `heroic` is `Service`, `bottles`, `EpicGamesLauncher.exe` and `EALauncher.exe` are `Launcher`, and many EA/Ubisoft helpers are `BG_CPUIO`.
- Games: `cs2`, `dota2` and `hl2_linux` are `Game`. Emulators (dolphin-emu, cemu, xemu, xenia, yuzu, suyu, eden, melonDS, RMG and others) are `Game`. Waydroid Android games are matched by truncated comm names.
- UE4 tools (`ShaderCompileWorker`, `UE4Editor`) are `BG_CPUIO`.
- Background tools: `tuned`, `tuned-ppd` and `power-profiles-daemon` are `BG_CPUIO`. `dmemcg-booster`, `foreground_booster` and `niri-focused-booster` are `Service`.
- Browsers are `Doc-View`. `obs` is `Player-Video`. `Discord` is `Chat`.
- Special-case rules:
  - `linphon`: nice -15, ioclass realtime
  - `thrash-protect`: nice -12, realtime
  - `bees`: `BG_CPUIO` + `oom_score_adj 1000`

---

## 3. CachyOS/cachyos-hooks (pacman hooks)

| Hook | Trigger | Action |
|---|---|---|
| `cachyos-branding.hook` | Install/Upgrade `cachyos-hooks` | `/usr/share/libalpm/scripts/cachyos-branding`: rewrites `/etc/os-release` (NAME, PRETTY_NAME, `ID=cachyos`, `ID_LIKE=arch`, ANSI_COLOR, URLs, LOGO), `/etc/lsb-release` and `/etc/issue` (Arch Linux becomes CachyOS Linux) |
| `os-release.hook` | `filesystem` | `cachyos-branding os-release` |
| `lsb-release.hook` | `lsb-release` | `cachyos-branding lsb-release` |
| `cachyos-plymouth-initramfs.hook` | plymouth install/upgrade/remove | `ln -sf /usr/bin/update-initramfs /usr/lib/plymouth/plymouth-update-initrd` |
| `cachyos-reboot-required.hook` | Upgrade of `amd-ucode intel-ucode btrfs-progs e2fsprogs xfsprogs cryptsetup linux linux-hardened linux-lts linux-zen linux-firmware linux-cachyos* linux-cacule* nvidia nvidia-dkms nvidia-*xx-dkms nvidia-*xx nvidia-*lts-dkms nvidia*-lts nvidia-utils lib32-nvidia-utils nvidia-open nvidia-open-dkms mesa systemd* wayland egl-wayland xf86-video-* xorg-server* xorg-fonts* mkinitcpio* booster* dracut* winesync-dkms` (NeedsTargets) | The script notifies only when the change is relevant: it skips non-running kernels, nvidia builds for another kernel, and fs-progs whose filesystem is not mounted. It sends a desktop notification through `busctl` (2 s timeout when no notification daemon is running) and also prints to the TTY. Translated via gettext (`po/`). |
| `update-initramfs` (helper script) | (none) | Auto-detects `limine-mkinitcpio` > `mkinitcpio --allpresets` > `limine-dracut` > `dracut --regenerate-all --force` > booster |

BrookOS can reuse the reboot-required and update-initramfs logic directly; only the branding strings need to change.

---

## 4. CachyOS/chwd and CachyOS/chwd-db (hardware detection)

`chwd` is written in Rust. It matches PCI and USB devices against TOML profiles in `/var/lib/chwd/db/{pci,usb}/` and runs `/var/lib/chwd/scripts/chwd` (Lua) to install packages and run the shell hooks `pre_install`, `post_install`, `pre_remove`, `post_remove` and `conditional_packages`. Child profiles (`a.b`) inherit from parents. Main CLI flags: `-a/--autoconfigure [classid]`, `-i/--install`, `-r/--remove`, `--list`, `--list-all`, `--list-installed`, `--ai_sdk`, `-f/--force`. The Lua script strips `lib32-*` packages when `[multilib]` is disabled and never removes `mesa`/`lib32-mesa`.

**Current profiles live in the `chwd` repo under `profiles/`.** The `chwd-db` repo is an older copy: `nvidia-dkms` priority 8 with 470xx and 390xx sub-profiles, the `virtualmachine` combo profile, and an `r8168` profile.

### Graphics (`profiles/pci/graphic_drivers/profiles.toml`)
| Profile | Match | Packages and actions |
|---|---|---|
| `nvidia-open-dkms` (prio 10) | 10de, class 0300/0302/0380, all IDs | `nvidia-utils egl-wayland nvidia-settings opencl-nvidia lib32-opencl-nvidia lib32-nvidia-utils libva-nvidia-driver vulkan-icd-loader lib32-vulkan-icd-loader cachyos-drm-awaiter`. Conditional: `<kernel>-nvidia-open` for each installed `linux-cachyos*` kernel, falling back to `nvidia-open-dkms`. `pre_install` writes `/etc/mkinitcpio.conf.d/10-chwd-kms.conf` with `HOOKS=(${HOOKS[@]/kms/})`, which removes the kms hook. |
| `nvidia-open-dkms.prime` (11) | Laptops (`chassis_types = "8 9 10 11 31"`) | Adds `nvidia-prime switcheroo-control`. `post_install` enables `nvidia-powerd` on non-Turing GPUs. On Turing it writes `/etc/modprobe.d/chwd-nvidia.conf` with `options nvidia NVreg_DynamicPowerManagement=0x02`. It also enables `switcheroo-control`. |
| `nvidia-dkms-580xx` (12) | IDs in `/var/lib/chwd/ids/nvidia-580.ids` (Maxwell/Pascal/Volta, e.g. 13xx, 15xx, 17xx, 1bxx, 1cxx, 1dxx) | The 580xx closed branch (`nvidia-580xx-utils` and related), kernel modules `<kernel>-nvidia-580xx` or `nvidia-580xx-dkms`, and the same kms-hook removal |
| `nvidia-dkms-580xx.prime` (13) | Laptops | Adds `nvidia-prime switcheroo-control` |
| `nouveau` (18) | IDs in `nouveau.ids` | `mesa lib32-mesa nouveau-fw opencl-mesa lib32-opencl-mesa cachyos-drm-awaiter`. Kepler GPUs (470 ids) also get `vulkan-nouveau linux-firmware-nvidia`. `post_install` sets `RUSTICL_ENABLE=nouveau` in `/etc/profile.d/opencl.sh` and `/etc/environment.d/30-opencl.conf`. Fermi GPUs (390 ids) get `options nouveau config=NvBoost=2` in `/etc/modprobe.d/20-nouveau-nvboost.conf`. |
| `intel` (4) | 8086 | `mesa lib32-mesa vulkan-intel lib32-vulkan-intel gst-plugin-va linux-firmware-intel cachyos-drm-awaiter`. `opencl-mesa` is added if there is no NVIDIA GPU. VA-API: old IDs (`intel-vaapi.ids`) get `libva-intel-driver-irql`, everything else gets `intel-media-driver`. `intel-media-sdk.ids` devices get `intel-media-sdk`, otherwise `vpl-gpu-rt`. Sets `RUSTICL_ENABLE=iris` (env and profile.d) if there is no NVIDIA GPU. |
| `amd` (4) | 1002 | `mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon xf86-video-amdgpu gst-plugin-va linux-firmware-amdgpu cachyos-drm-awaiter`, plus `opencl-mesa` if there is no NVIDIA GPU |
| `fallback` (3) | Any vendor | `mesa lib32-mesa vulkan-swrast xf86-video-vesa lib32-vulkan-swrast` |
| `virtualbox` / `vmware` / `qemu` (5) | 80EE / 15AD / 1af4 1b36 1013 1234 | Guest tools and services. QEMU adds `MODULES+=(virtio virtio_blk virtio_pci virtio_net)` in `/etc/mkinitcpio.conf.d/10-chwd-qemu.conf`. |

### Other chwd profiles
- `handhelds`:
  - `handheld` (generic): matches by DMI product name (Legion Go 83E1/83L3/..., AYANEO, OneXPlayer, GPD G1617/G1618/G1619, AOKZOE, Loki and others). Installs `steamos-manager inputplumber steamos-powerbuttond`, plus `fwupd` when the BIOS vendor is Lenovo.
  - `handheld.steam-deck` (`Jupiter|Galileo`): `steamos-manager steamos-powerbuttond jupiter-fan-control steamdeck-dsp`, plus `galileo-mura` on OLED. Enables `jupiter-fan-control`.
  - `handheld.rog-ally` (board `RC71L|RC72LA|RC73XA|RC73YA`): symlinks the PipeWire convolver `filter-chain.conf` and WirePlumber `alsa-card0(-x).conf`/`alsa-card1.conf` from cachyos-handheld.
  - `handheld.msi-claw` (board `MS-1T..`): loads `msi-wmi-platform` and adds a WirePlumber headroom fix.
- `power_management`, `intel-lpmd`: Intel family 6, models `151 154 183 186 191 170 172 181 189 204 213`, hybrid CPUs only. Installs `intel-lpmd` and enables `intel_lpmd.service`.
- `network_drivers`:
  - `broadcom-wl`: installs `broadcom-wl-dkms linux-firmware-broadcom` and blacklists `b43 b43legacy ssb bcm43xx brcm80211 brcmfmac brcmsmac bcma`
  - `marvell-wifi`: installs `linux-firmware-marvell`
- `framework`, `framework-laptop-12`: installs `iio-sensor-proxy`.
- `t2-macbook`: `apple-t2-audio-config t2fanrd`, t2bce modules, kernel params `intel_iommu=on iommu=pt pcie_ports=compat`, `brcmfmac feature_disable=0x82000`.
- `ai_sdk` (opt-in with `--ai_sdk`):
  - NVIDIA: `cuda cudnn nccl python-pytorch-opt-cuda ollama-cuda tensorflow-opt-cuda ...`
  - AMD ROCm: for listed gfx IP versions
- `usb/fprint`: installs `fprintd` for known sensor vendors and adds `auth sufficient pam_fprintd.so` to `/etc/pam.d/sudo`.

`scripts/chwd-kernel` is a separate Rust CLI to list, install and remove kernels.

---

## 5. CachyOS/uksmd (KSM daemon), now **deprecated**

The README says it is no longer developed and recommends `cachyos-ksm-settings` (in CachyOS-PKGBUILDS) instead.

**Behaviour of `uksmd.c` v1.3.0:**
- Needs the pf-kernel/CachyOS `process_ksm_{enable,disable,status}` syscalls; their numbers are read from `/sys/kernel/process_ksm/*`.
- At start it writes `1` to `/sys/kernel/mm/ksm/run` and matches the nice level of the `ksmd` kthread.
- Every `IDLE_SLEEP_SECS 15` it checks whether KSM finished a full scan or `pages_volatile==0`. If so, it walks all user tasks older than `OBSERVE_WINDOW_SECS 30` and enables per-process KSM (MMF_VM_MERGE_ANY).
- It explicitly disables KSM for `mariadbd`, `mysqld` and `p2pool`.
- On exit it writes `2` to `ksm/run`, which unmerges all pages.
- It reports `STATUS=Profit: N MiB` via sd_notify.

The unit `uksmd.service` is `Type=notify` and runs with `DynamicUser`. It holds `CAP_SYS_PTRACE`, `CAP_DAC_OVERRIDE` and `CAP_SYS_NICE`, uses `WatchdogSec=30`, and has extensive sandboxing.

Other files: `uksmdstats` prints the `/sys/kernel/mm/ksm/*` stats, and `90-uksmd-upgrade.hook` restarts the service on upgrade.

For BrookOS, the modern equivalent is a kernel with `prctl(PR_SET_MEMORY_MERGE)` plus systemd `MemoryKSM=yes`, or `cachyos-ksm-settings`.

---

## 6. CachyOS/sysctl-manager, scx-manager and kernel-manager (Qt GUIs)

- **sysctl-manager**: lists every file under `/proc/sys` except `debug`/`dev`, linking each to kernel.org docs, and applies changes via pkexec plus a terminal helper. It ships **no preset values**.
- **scx-manager**: GUI for `scx_loader` over D-Bus `org.scx.Loader`. It writes the config to `/etc/scx_loader.toml` (written to `/tmp` first, then copied via pkexec).
  - It offers modes `Auto/Gaming/Powersave/Lowlatency/Server` (0 to 4); the mode selector appears only for `scx_bpfland, scx_lavd, scx_p2dq, scx_tickless, scx_cosmos`.
  - It disables the legacy `scx.service` and enables `scx_loader`.
- **kernel-manager**: installs kernels from the repos and builds custom ones from the `linux-cachyos*` PKGBUILDs.
  - Variants: `linux-cachyos` ("CachyOS default Scheduler (tuned EEVDF)"), `-bore`, `-rc`, `-rt-bore`, `-lts`, `-eevdf`, `-bmq`, `-hardened`, `-deckify` (handheld), `-server`.
  - Build options and defaults:

    | Option | Choices (default first or marked) |
    |---|---|
    | `_cachy_config` | default on |
    | `_cc_harder` (`-O3`) | default on |
    | `HZ_ticks` | 1000/750/600/500/300/250/100 |
    | `tickrate` | full/idle/periodic |
    | `preempt` | full/lazy |
    | `hugepage` | always/madvise |
    | `processor_opt` | native, generic v1–v4, zen4 |
    | `use_llvm_lto` | none/full/thin/thin-dist; default **thin** |
    | `tcp_bbr3` | toggle |
    | `per_gov` | performance governor as default |
    | other toggles | `localmodcfg` (modprobed-db), `build_zfs`, `build_nvidia_open` |
  - These options are the knobs where the kernel-side tuning lives.

---

## 7. CachyOS/tuned (fork of redhat-performance/tuned; default branch `cachyos`)

The compare API shows the fork 16 commits ahead and 18 behind upstream. The CachyOS commits are by Peter Jung and Vasiliy Stelmachenok, dated Feb–Mar 2026. Changed files: 5 new profiles, `plugin_amd_x3d.py`, `plugin_scx.py`, `plugin_video.py` (`dpm_perf_level`), `tuned/ppd/powerprofilesctl` (new, a drop-in replacement for PPD's CLI), `tuned/ppd/ppd.conf`, and rotational-device matching in `plugins/base.py`, `instance.py`, `profiles/unit.py` and `units/manager.py`.

### `tuned/ppd/ppd.conf` (tuned-ppd replaces power-profiles-daemon)
```
[main] default=balanced  battery_detection=true  sysfs_acpi_monitor=true
[profiles] power-saver=cachyos-powersave  balanced=cachyos-desktop  performance=cachyos-gaming
[battery]  balanced=cachyos-balanced-battery
```
Because `game-performance` calls `powerprofilesctl launch -p performance`, it activates **cachyos-gaming** for the lifetime of the game.

### `profiles/cachyos-common/tuned.conf` (included by all other CachyOS profiles)
- `[vm]`:
  - `transparent_hugepages=always`
  - `transparent_hugepage.defrag=defer+madvise`
  - `dirty_bytes=10%`
  - `dirty_background_bytes=3%`
- `[sysctl]`:
  - `kernel.nmi_watchdog=0`
  - `vm.swappiness=100`
  - `vm.page-cluster=0`
  - `vm.vfs_cache_pressure=50`
  - `vm.dirty_expire_centisecs=1500`
  - `vm.compaction_proactiveness=0`
- `[sysctl-zram]` (devices `zram*`): `vm.swappiness=150`
- `[disk-hdd]` (`sd*`, rotational=1): `elevator=bfq`
- `[disk-ssd]` (`sd*`, rotational=0): `elevator=mq-deadline`
- `[disk-nvme]` (`nvme*`): `elevator=kyber`

### `cachyos-gaming`
- `[cpu]`:
  - `governor=performance`
  - `energy_perf_bias=performance`
  - `energy_performance_preference=performance`
  - `min_perf_pct=100`
  - `boost=1`
- `[acpi] platform_profile=performance`
- `[video] radeon_powersave=dpm-performance`, `panel_power_savings=0`
- `[usb] autosuspend=0`
- `[audio] timeout=0`
- `[amd_x3d] mode=cache`
- Commented out: `[scx] scheduler=scx_lavd mode=gaming`

### `cachyos-desktop`
- `[cpu]`:
  - `governor=schedutil|powersave`
  - `energy_perf_bias=normal`
  - `energy_performance_preference=balance_performance`
- `[video] radeon_powersave=dpm-balanced, auto`, `panel_power_savings=0`
- `[amd_x3d] mode=frequency`
- Commented out: `[scx] scheduler=scx_bpfland mode=auto`

### `cachyos-powersave`
- `[cpu]`:
  - `governor=conservative|powersave`
  - `energy_perf_bias=powersave|power`
  - `energy_performance_preference=power`
  - `boost=0`
- `[acpi] platform_profile=low-power|quiet`
- `[video] radeon_powersave=dpm-battery, auto`, `panel_power_savings=3`
- `[sysctl] vm.dirty_writeback_centisecs=1500`
- `[usb] autosuspend=1`
- `[audio] timeout=10`
- `[vm] dirty_bytes=5%`, `dirty_background_bytes=2%`
- `[amd_x3d] mode=frequency`
- Commented out: `[scx] scheduler=scx_bpfland mode=powersave`

### `cachyos-balanced-battery`
- Includes `cachyos-powersave`
- `[acpi] platform_profile=balanced`
- `[video] panel_power_savings=1`

### New plugins
- `[amd_x3d] mode=cache|frequency` writes to `/sys/bus/platform/drivers/amd_x3d_vcache/*/amd_x3d_mode`. It applies to dual-CCD X3D CPUs (7950X3D, 9950X3D and similar) and needs BIOS CPPC set to "Driver".
- `[scx] scheduler=<name|none> mode=auto|gaming|powersave|lowlatency|server` calls `SwitchScheduler(name, mode)` on `org.scx.Loader`. Mode numbers: auto=0, gaming=1, powersave=2, lowlatency=3, server=4.
- `[video] dpm_perf_level=auto|low|high|manual|profile_standard|profile_min_sclk|profile_min_mclk|profile_peak` sets amdgpu `power_dpm_force_performance_level`.

The commit history also shows that `vm.laptop_mode=5` was removed and a separate `cachyos-laptop` profile was dropped.

---

## 8. CachyOS/intel-lpmd (fork of intel/intel-lpmd; default branch `cachyos`)

The fork is 6 commits ahead and 170 behind upstream. All 6 commits are by Peter Jung, dated Mar–Apr 2026:
1. `data/intel_lpmd_config_F6_M189.xml` and `F6_M204.xml` (Arrow Lake / Lunar Lake class): `<BalancedDef>` and `<PowersaverDef>` changed from `-1` to `0`. This turns LPM **auto** on for the PPD balanced and power-saver profiles instead of force-off. Commit: "power-profile: Enable intel-lpmd with auto".
2. New D-Bus method `GetState`, returning `OFF/ON/AUTO/FREEZE/RESTORE/TERMINATE`, and a matching `intel_lpmd_control STATUS` command.
3. Fixes:
   - The polling interval is re-armed (`DEF_POLLING_INTERVAL 100`) after switching back to an AUTO profile; previously that switch caused a deadlock.
   - The order of polling-interval writes is corrected (upstream issue #106).
   - `copy_user_string` overflow and underflow are fixed.
   - The SliderDC dump now prints the DC value instead of the AC value.

chwd installs and enables `intel-lpmd` only on hybrid Intel CPUs (see section 4).

---

## 9. CachyOS/scx (fork of sched-ext/scx)

**The fork has no CachyOS-specific commits.** The compare API reports `status=behind`, ahead 0, **behind 3,458** (the snapshot is v1.0.15 era). Upstream has since moved on, and `scx_loader` later moved to its own repo. Build from upstream `sched-ext/scx`, not from this fork. The CachyOS contributions here are `tools/scx_loader` (authored by Vladislav Nepogodin of CachyOS) and the OpenRC/systemd service files.

**Services in the snapshot:**
- `services/scx` (`/etc/default/scx`): `SCX_SCHEDULER=scx_flash`
- `scx.service`: runs `${SCX_SCHEDULER_OVERRIDE:-$SCX_SCHEDULER} ${SCX_FLAGS_OVERRIDE:-$SCX_FLAGS}`
- `scx_loader.service`: `Type=dbus`, bus name `org.scx.Loader`
- Vendor config `/usr/share/scx_loader/config.toml`: `default_sched = "scx_flash"`
- Config search order: `/etc/scx_loader/config.toml`, `/etc/scx_loader.toml`, `$vendordir/scx_loader/config.toml`, `$vendordir/scx_loader.toml`

**Per-mode default flags in scx_loader (`tools/scx_loader/src/config.rs`):**
| Scheduler | Auto | Gaming | LowLatency | PowerSave | Server |
|---|---|---|---|---|---|
| scx_bpfland | – | `-m performance` | `-s 5000 -S 500 -l 5000 -m performance` | `-m powersave` | `-p` |
| scx_lavd | – | `--performance` | `--performance` | `--powersave` | – |
| scx_flash | – | `-m all` | `-m performance -w -C 0` | `-m powersave -I 10000 -t 10000 -s 10000 -S 1000` | `-m all -s 20000 -S 1000 -I -1 -D -L` |
| scx_p2dq | – | – | `-y` | – | `--keep-running` |
| scx_tickless | – | `-f 5000 -s 5000` | `-f 5000 -s 1000` | `-f 50 -p` | `-f 100` |
| scx_cosmos | `-d` | `-c 0 -p 0` | `-m performance -c 0 -p 0 -w` | `-m powersave -d -p 5000` | `-a -s 20000` |
| scx_rusty, scx_rustland | no mode flags | | | | |

**Schedulers in the tree:**

`scheds/rust/`:
| Scheduler | What it is for |
|---|---|
| **scx_lavd** | Latency-criticality Aware Virtual Deadline. Its README says it was "initially motivated by gaming workloads", aiming to reduce stutter with high throughput and low tail latency. Creates per-LLC, per core-type (P/E) and per-NUMA domains. Mainly targets single-CCX, single-socket systems. **CachyOS's gaming and handheld choice.** |
| **scx_bpfland** | vruntime-based, fully in BPF, derived from rustland. Classifies tasks as interactive when they make frequent voluntary context switches and prioritises them. **CachyOS's desktop choice.** |
| **scx_flash** | EDF with dynamic latency weights, aimed at fairness and predictability. Latency-sensitive and good on overcommitted systems. The upstream default in this snapshot's service files. |
| **scx_cosmos** | Lightweight and locality-preserving (local DSQs when the system is not saturated, deadline-based when saturated). Batches and defers wakeups. |
| **scx_p2dq** | Pick-2 load balancing across LLCs and NUMA nodes with multi-layer queues. General purpose. |
| **scx_rusty** | Multi-domain BPF and user-space hybrid with Rust load balancing. Flexible and tunable, general purpose and server use. |
| **scx_rustland** | Scheduling policy runs in user-space Rust. Favours interactive tasks (gaming, video calls) and doubles as a template. |
| **scx_tickless** | Server/HPC/cloud. Routes scheduling events to primary CPUs so the other CPUs can run without a tick (less OS noise). |
| **scx_layered** | Highly configurable multi-layer scheduler with per-cgroup policies (Meta production use). |
| **scx_mitosis** | Cell-based, cgroup-partitioned (experimental). |
| **scx_wd40** | Experimental arena-based fork of rusty. |
| **scx_rlfifo** | Simple user-space round-robin template, not for production. |
| **scx_chaos** | Deliberately injects latency to expose race conditions, testing only. |

`scheds/c/` holds examples and tests: `scx_simple`, `scx_central`, `scx_flatcg`, `scx_nest`, `scx_pair`, `scx_prev`, `scx_qmap`, `scx_sdt`, `scx_userland`.

**Which one CachyOS defaults to for gaming: `scx_lavd` in Gaming mode (`--performance`).** Evidence:
- The CachyOS-Handheld README: "scx_lavd used as default scheduler - LAVD is a latency sensitive scheduler, which is intended to be used for handhelds and gaming".
- The tuned `cachyos-gaming` profile and the `plugin_scx.py` docstring both name `scheduler=scx_lavd mode=gaming`.

For desktop use, `cachyos-desktop` and `cachyos-powersave` name `scx_bpfland` (modes auto and powersave). On the desktop editions the `[scx]` sections are **commented out**, so sched-ext is opt-in through scx-manager or scx_loader, and the default CPU scheduler is the kernel's tuned EEVDF or BORE.

---

## 10. CachyOS/CachyOS-Handheld (the `cachyos-handheld` package)

- Defaults stated in the README:
  - scx_lavd as default scheduler (disable with `systemctl disable --now scx.service; systemctl mask scx.service`)
  - BBRv3, NTSync/Fsync, btrfs default filesystem
  - systemd-boot
  - gamescope session; `steamos-session-select persistent|oneshot` controls the boot session
- `usr/lib/sysctl.d/20-steamos-customizations.conf`: `net.ipv4.tcp_fin_timeout = 5`
- `etc/security/limits.d/memlock.conf`: `* hard memlock 2147484` / `* soft memlock 2147484` (about 2 GiB in KiB, as SteamOS uses)
- `usr/lib/modprobe.d/blacklist-handheld.conf`: `blacklist wdat_wdt`
- `usr/lib/modules-load.d/hid-preload.conf`: `hid_nintendo`, `hid_playstation`. Loading these early stops Steam from falling back to evdev instead of hidraw.
- `usr/lib/sdboot-manage.conf.d/10-handheld.conf`: on Steam Deck (`Jupiter`/`Galileo`) adds `amd_iommu=off amdgpu.ppfeaturemask=0xffffffff`
- `usr/share/pipewire/pipewire.conf.d/10-min-quant.conf`: `default.clock.min-quantum = 256`
- WirePlumber rules:
  - `acp5x`/`acp6x`/`sof-nau8821-max`: `session.suspend-timeout-seconds = 0`, `api.alsa.headroom = 1024`
  - Ally and Legion Go: `api.alsa.period-size = 256`
  - Convolver EQ filter-chains for ROG Ally and Legion Go
- `etc/environment.d/handheld.conf`: `DECKY_USER=deck`, `DECKY_USER_HOME=/home/deck`, `QT_QUICK_CONTROLS_STYLE=org.kde.desktop`
- `etc/systemd/logind.conf.d/steam-deckify.conf`: `HandlePowerKey=ignore`, `KillUserProcesses=True`
- plasma-login autologin: `Session=gamescope-session.desktop`, `User=deck`, `Relogin=true`
- KDE defaults:
  - baloo indexing off
  - screen locker off
  - virtual keyboard on
  - powerdevil (battery: dim and display off after 60 s, suspend after 300 s)
  - Vapor look-and-feel
- Hooks:
  - `blocked-packages.hook` aborts any transaction that installs `packagekit`
  - `steam-handheld.hook` and `steam-force-handheld` add `-steamdeck` to `/usr/bin/steam`
- udev:
  - `70-led-control.rules` chowns LED sysfs nodes to uid 1000
  - `99-kwin-ignore-tablet-mode.rules`
- `hhd@.service.d/override.conf`: everything is commented out

---

## Files read

The following were not read in detail: binary files (PNG, SVG, WAV), LICENSE files, translation catalogs (`.po`, `.ts`, `.ftl`), vendored build helpers (`cmake/*.cmake`, CPM.cmake) and lockfiles.

- **CachyOS-Settings** (every text file, read in full): `README.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` (skimmed), `etc/debuginfod/cachyos.urls`, `etc/security/limits.d/20-audio.conf`, `usr/bin/{cachyos-bugreport.sh,dlss-swapper,dlss-swapper-dll,game-performance,kerver,paste-cachyos,pci-latency,sbctl-batch-sign,topmem,zink-run}`, `usr/bin/eac-setup` (header and constants), `usr/bin/eac-status` (purpose only), `usr/lib/iw-set-regdomain`, `usr/lib/modprobe.d/{amdgpu,blacklist,nvidia}.conf`, `usr/lib/modules-load.d/ntsync.conf`, `usr/lib/NetworkManager/conf.d/dns.conf`, `usr/lib/sysctl.d/70-cachyos-settings.conf`, `usr/lib/systemd/zram-generator.conf`, `usr/lib/systemd/journald.conf.d/00-journal-size.conf`, `usr/lib/systemd/system/{cachyos-iw-set-regdomain.path,cachyos-iw-set-regdomain.service,pci-latency.service}`, `usr/lib/systemd/system/rtkit-daemon.service.d/override.conf`, `usr/lib/systemd/system/system.slice.d/10-oomd-per-slice-defaults.conf`, `usr/lib/systemd/system/systemd-zram-setup@.service.d/xswap.conf`, `usr/lib/systemd/system/user@.service.d/delegate.conf`, `usr/lib/systemd/system-generators/xswap-generator`, `usr/lib/systemd/{system,user}.conf.d/{00-timeout,10-limits}.conf`, `usr/lib/systemd/timesyncd.conf.d/10-timesyncd.conf`, `usr/lib/systemd/user/session.slice.d/10-ignore-session-slice.conf`, `usr/lib/systemd/user-generators/cachyos-oomd-generator`, `usr/lib/tmpfiles.d/{coredump,thp,thp-shrinker}.conf`, `usr/lib/udev/audio-pm-ctl`, `usr/lib/udev/rules.d/{20-audio-pm,30-zram,40-hpet-permissions,50-sata,60-ioschedulers,61-writeback-limits,69-hdparm,71-nvidia,85-iw-regulatory,99-cpu-dma-latency}.rules`, `usr/share/glib-2.0/schemas/zz_cachyos.org.gnome.login-screen.gschema.override`, `usr/share/X11/xorg.conf.d/20-touchpad.conf`.
- **ananicy-rules**: read in full: `.gitattributes`, `00-cgroups.cgroups`, `00-types.types`, `ananicy.conf`, `ananicy.schema.json`, `ananicy-cgroups.schema.json`, `lint.py`, `Makefile`, `README.md`, `sort-games.sh` (most of it). All 362 `00-default/**/*.rules` files were parsed programmatically (every rule line counted and classified, special keys extracted). Read directly: `Games/{asf,emulators,gaming-tools,launchers,steam-shader-compilation,ue4,waydroid,wine,wineserver}.rules`, `Services/{dmemcg-booster,misc-services}.rules`, `Tools/{tuned,ppd}.rules`, `Browsers/browsers.rules`, `Audio-Video/audioserver.rules`, `DEs-and-WMs/{gamescope,plasma,gdm,xorg,xwayland}.rules`.
- **cachyos-hooks** (all): `.gitignore`, `README.md`, `cachyos-branding`, `cachyos-branding.hook`, `cachyos-plymouth-initramfs.hook`, `cachyos-reboot-required`, `cachyos-reboot-required.hook`, `lsb-release.hook`, `os-release.hook`, `update-initramfs`. `po/*` was listed only.
- **chwd**: read in full: `README.md`, all 8 `profiles/**/profiles.toml`, `scripts/chwd` (Lua), `src/args.rs`, `src/consts.rs`, `ids/nvidia-580.ids`. Header only: `scripts/chwd-kernel/src/main.rs`. Listed or skimmed: the remaining `src/*.rs`, `libpci*`, `libusb*`, `tests/*`, `ids/*`, `i18n/*`.
- **chwd-db** (all): `README.md`, `pci/graphic_drivers/profiles.toml`, `pci/network_drivers/profiles.toml`, `LICENSE` (listed).
- **uksmd** (all): `README.md`, `uksmd.c`, `uksmd.service`, `uksmdstats`, `uksmd-systemd-restart`, `90-uksmd-upgrade.hook`, `meson.build`, `meson.options`, `locale/{LINGUAS,meson.build}`, `.gitignore`. `.po`/`.pot` files listed.
- **sysctl-manager**: `README.md`, `src/sysctl_option.cpp`, `src/utils.cpp`, `src/rootshell.sh`, `src/terminal-helper`. Other source, UI and build files listed or skimmed.
- **scx-manager**: `README.md`, `scx-rustlib/src/lib.rs`, `src/scx_utils.cpp`, `src/schedext-window-internal.cpp`, plus the header `config_path` (`/etc/scx_loader.toml`). Build and lang files listed.
- **kernel-manager**: `README.md`, `Changelog.md`, `src/compile_options.json`, `src/mkoptions.py`, `config-option-lib/src/lib.rs`, `src/conf-options-page.ui` (labels), `src/conf-window.cpp` (option tables, lines 95–184 and 480–570). Other source listed.
- **CachyOS-Handheld** (all text files): `README.md`, `etc/environment.d/handheld.conf`, `etc/plasmalogin.conf.d/{cachyos,steam-deckify}.conf`, `etc/security/limits.d/memlock.conf`, `etc/systemd/logind.conf.d/steam-deckify.conf`, `etc/xdg/{baloofilerc,kcminputrc,kdeglobals,krunnerrc,kscreenlockerrc,kwinrc,kwinrulesrc,powerdevilrc}`, `etc/xdg/autostart/steam.desktop`, `usr/bin/steamos-add-to-steam`, `usr/lib/hwsupport/valve-hardware`, `usr/lib/modprobe.d/blacklist-handheld.conf`, `usr/lib/modules-load.d/hid-preload.conf`, `usr/lib/sdboot-manage.conf.d/10-handheld.conf`, `usr/lib/sysctl.d/20-steamos-customizations.conf`, `usr/lib/systemd/system/hhd@.service.d/override.conf`, `usr/lib/udev/rules.d/{70-led-control,99-kwin-ignore-tablet-mode}.rules`, `usr/share/applications/steamos-gamemode.desktop`, all `usr/share/cachyos-handheld/**/*.conf`, `usr/share/kio/servicemenus/steam.desktop`, `usr/share/libalpm/hooks/{blocked-packages,steam-handheld}.hook`, `usr/share/libalpm/scripts/steam-force-handheld`, `usr/share/pipewire/pipewire.conf.d/10-min-quant.conf`, `usr/share/plasma/kickeractions/steam.desktop`. `etc/skel/Desktop/steamos-gamemode.desktop` is a 0-byte symlink placeholder that the Windows extraction could not resolve.
- **tuned** (CachyOS delta only): the GitHub compare `redhat-performance/tuned:master...CachyOS:cachyos` (16 commits, 16 files). Read in full: `profiles/cachyos-{common,desktop,gaming,powersave,balanced-battery}/tuned.conf`, `tuned/plugins/plugin_scx.py`, `tuned/plugins/plugin_amd_x3d.py`, `tuned/ppd/ppd.conf`. Partly read: `tuned/plugins/plugin_video.py` (`dpm_perf_level` section), `tuned/ppd/powerprofilesctl` (header), `recommend.conf` (header). Upstream `profiles/{desktop,balanced}/tuned.conf` were read for comparison.
- **intel-lpmd** (CachyOS delta only): the GitHub compare `intel/intel-lpmd:main...CachyOS:cachyos` (6 commits). Full patches read for `data/intel_lpmd_config_F6_M{189,204}.xml`, `src/include/lpmd.h`, `src/intel_lpmd_dbus_interface.xml`, `src/lpmd_dbus_server.c`, `src/lpmd_helpers.c`, `src/lpmd_proc.c`, `src/lpmd_state_machine.c`, `tools/intel_lpmd_control.c`.
- **scx** (fork delta plus CachyOS-relevant parts): the GitHub compare `sched-ext/scx:main...CachyOS:main` (0 ahead, 3,458 behind). Read in full: `README.md` (first 60 lines), all `services/**` files (`README.md`, `scx`, `scx_loader.toml`, `systemd/{scx.service,scx_loader.service,org.scx.Loader.service,meson.build}`, `openrc/{scx.initrd,meson.build}`), `tools/scx_loader/src/config.rs`, `tools/scx_loader/src/lib.rs` (enums). The README overview sections of all 13 `scheds/rust/*` schedulers were read; `scheds/c/` was listed. `INSTALL.md` and `DEVELOPER_GUIDE.md` were grepped for CachyOS mentions.
