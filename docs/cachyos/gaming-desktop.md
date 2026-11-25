# CachyOS gaming, desktop, installer and ISO optimizations: what BrookOS should copy

Sources: HEAD tarballs from codeload.github.com/CachyOS/<repo>, downloaded 2026-11-25. The large forks (wine-cachyos, rclone, CachyOS-icons, cachyos-wallpapers) were checked through the GitHub API (commits, branches and trees) instead of being downloaded. All repository content was treated as data; nothing from it was executed.

Two repos were read only partly. For the wiki, only the English pages in the requested topic areas were read; translations and unrelated pages were skipped. For the website, only marketing copy matched.

The `CachyOS-Settings`, `linux-cachyos`, `CachyOS-PKGBUILDS` and `kernel-manager` repos were out of scope for this pass. The real sysctl, udev, zram and modprobe values live in `CachyOS-Settings`; this report quotes only the values that appear in the repos below or in the wiki.

---

## 1. Top recommendations for BrookOS (KDE Plasma, gaming)

1. **Installer defaults** (calamares and gucc/cli-installer, both current):
   - Filesystem: Btrfs on GPT.
   - Mount options: `defaults,noatime` plus `compress=zstd` (HDD/SATA SSD) or `compress=zstd:1` (NVMe).
   - Btrfs subvolumes: `@ @home @root @srv @cache @tmp @log`.
   - No swap partition; zram instead, with `zswap.enabled=0`.
   - `fstrim.timer` enabled.
   - `/tmp` on tmpfs (`defaults,noatime,mode=1777`) on SSDs.
   - Default bootloader: Limine (4 GiB `/boot` ESP). systemd-boot uses a 2 GiB `/boot` ESP; GRUB uses a 512 MiB `/boot/efi`.
   - Kernel cmdline: `quiet nowatchdog`, plus `zswap.enabled=0` (gucc) and, for GRUB, `nvme_load=YES`; `splash` when Plymouth is enabled.
   - systemd-based initramfs (`useSystemdHook: true`) with the `kms` hook **removed**. Plymouth uses simpledrm instead, and the `cachyos-drm-awaiter` package waits for the GPU driver before starting the display manager.
2. **CPU-optimized repos**: detect znver4/znver5, x86-64-v4 or x86-64-v3 at install time, using `ld.so --help` and cpuinfo (the `detect-architecture` script is in §4.2), and insert the matching `[cachyos-*-v3|v4|znver4]` repos above `[cachyos]`, core and extra.
3. **KDE defaults** (`cachyos-kde-settings`):
   - `AnimationDurationFactor=0.25` (4x faster animations).
   - **Baloo indexing disabled** (`Indexing-Enabled=false`).
   - `Trolltech.conf GUIEffects=none`.
   - `ksmserverrc loginMode=emptySession` (no session restore).
   - `plasmashellrc PreloadWeight=0`.
   - SDDM / plasma-login-manager running on Wayland (`kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1`).
   - Breeze Dark theme.
4. **Proton**: ship `proton-cachyos` (SLR build) next to Valve Proton.
   - NTSync is the default (`PROTON_NO_NTSYNC=1` turns it off).
   - The `winepipewire.drv` audio driver is the default and has realtime dispatch, so `rtkit` is recommended.
   - Useful opt-ins: `PROTON_FSR4_UPGRADE`, `PROTON_DLSS_UPGRADE`, `PROTON_XESS_UPGRADE`, `PROTON_DXVK_LOWLATENCY`, `PROTON_VKD3D_LOWLATENCY`, `PROTON_LOCAL_SHADER_CACHE`, `PROTON_ENABLE_WAYLAND`, `PROTON_USE_OPTISCALER`, `DXVK_HDR`.
   - Allow thread niceness: `* hard nice -15` in `/etc/security/limits.d/`.
5. **Steam Game Mode**: copy `gamescope-session` (CachyOS fork of Valve's jupiter session).
   - It uses a full SteamOS environment-variable set: dynamic VRS, tearing/VRR/NIS support flags, `ENABLE_GAMESCOPE_WSI=1`, `vk_xwayland_wait_ready=false`, `VKD3D_SWAPCHAIN_LATENCY_FRAMES=3`, `STEAM_LAUNCH_WRAPPER_SCOPE=1` (one cgroup per game) and `ulimit -n 524288`.
   - It autologins through plasma-login-manager or SDDM drop-ins and has a `steamos-session-select` switcher.
6. **Services and tweaks offered by CachyOS-Welcome**:
   - Toggles: profile-sync-daemon (user `psd.service`), `systemd-oomd`, `bpftune`, `ananicy-cpp`, `bluetooth` and the `arch-update.timer` update notifier.
   - A one-click "gaming" install: `cachyos-gaming-meta` plus `cachyos-gaming-applications`.
7. **Browser**: the CachyOS-Browser-Settings prefs are a good template (see §8):
   - VA-API decode.
   - Forced WebRender, compositor and GPU process.
   - Accelerated canvas.
   - Larger memory caches.
   - Disk cache off (pairs with psd).
   - `content.notify.interval=100000`.
   - Telemetry locked off.
8. **Live ISO**:
   - Two kernels (linux-cachyos and -lts) plus prebuilt nvidia-open and ZFS modules.
   - Cmdline `module_blacklist=pcspkr i915.modeset=1 amdgpu.modeset=1 nvme_load=yes copytoram=auto cow_spacesize=10G`.
   - A nomodeset fallback that blacklists the NVIDIA modules.
   - Live-session KDE: no screen locking, wallet, automounter, DPMS or suspend.
   - The installer drops nvidia packages when no NVIDIA GPU is detected (`chwd --is_nvidia_card`).

---

## 2. Gaming and runtime repos

### proton-cachyos
The repo now holds only docs (README, CHANGELOG, BUILDING, docs/); the sources live in submodules elsewhere. The base is Valve Proton Experimental 11 with wine rebased on Proton-EM wine plus CachyOS patches. It ships as SLR (Steam Linux Runtime, recommended), native (`proton-cachyos-native`, wow64-only, hidden from Steam because SteamRT3 breaks it, still usable with umu) and x86_64/x86_64_v3 builds (v4 dropped as "nothing substantial").

**CachyOS-specific options** (environment variable / compat string):
- **Low latency:** `PROTON_DXVK_LOWLATENCY` (dxvklowlatency, the dxvk-low-latency frame-pacing fork) and `PROTON_VKD3D_LOWLATENCY` (vkd3dlowlatency: native Reflex in vkd3d-proton plus waitable swapchains; read its limitations first). Also `LOW_LATENCY_LAYER` (`low_latency_layer`) and `DXVK_NVAPI_VKREFLEX` (Vulkan Reflex layer).
- **Upscalers:**
  - `PROTON_FSR4_UPGRADE[=ver]` downloads `amdxcffx64.dll` and upgrades FSR 3.1 games to FSR4.
  - `PROTON_FSR4_INDICATOR` shows the watermark.
  - `PROTON_MLFG_UPGRADE` enables ML frame generation (FSR4 >= 4.0.3).
  - `PROTON_DLSS_UPGRADE[=ver]` also sets the latest DRS preset; `PROTON_DLSS_INDICATOR` shows the overlay.
  - Also `PROTON_XESS_UPGRADE`, `PROTON_FFX3_UPGRADE` and `PROTON_FFX4_UPGRADE`.
  - `PROTON_USE_OPTISCALER=1` auto-injects OptiScaler. Related: `PROTON_OPTISCALER_NAME` (dxgi/d3d12/dbghelp), `PROTON_OPTISCALER_CONFIG="Section.key=val;..."` and `PROTON_OPTISCALER_STREAMLINE`.
- **Old GPUs and APIs:** `PROTON_DXVK_SAREK` (DXVK for Vulkan 1.1–1.2 GPUs; async, so not for anti-cheat games), `PROTON_D7VK_DDRAW` (DX7 and older) and `PROTON_DXVK_D3D8`.
- **Wayland:** `PROTON_ENABLE_WAYLAND` / `PROTON_USE_WAYLAND` (winewayland.drv, experimental). HDR uses `DXVK_HDR=1` (plus `ENABLE_HDR_WSI=1` on NVIDIA older than 595); `DXVK_NO_HDR` forces it off. KDE before 6.4 (Wayland) or 6.6 (X11) needs `WINE_USE_KWIN_HACKS`. Electron launchers that show a white window need `--in-process-gpu`.
- **Audio:**
  - `winepipewire.drv` is the default; `PROTON_USE_PIPEWIRE=0` falls back to pulse. `WINE_AUDIO_DRIVER=pipewire,pulse,alsa` sets the driver order.
  - Lower latency comes from the PipeWire quantum: `pw-metadata -n settings 0 clock.force-quantum 256`, or `default.clock.min-quantum = 256` in `~/.config/pipewire/pipewire.conf.d/99-lowlatency.conf`. `PIPEWIRE_LATENCY` has no effect.
  - Without `rtkit` the driver falls back to async mode.
  - Also `WINEALSA_CHANNELS` and `WINEALSA_SPATIAL`.
- **Shader cache:** `PROTON_LOCAL_SHADER_CACHE=1` gives a per-game cache under `<steamlibrary>/shadercache/<appid>`. It raises the Mesa cache to 10 GB and the NVIDIA cache to 10 GiB, and sets `__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1`. It was default-on in some releases; it is now opt-in.
- **Sync:** NTSync is the default (Proton 11); disable it with `PROTON_NO_NTSYNC`. It was disabled per game for Hogwarts Legacy and Death Stranding 2. `PROTON_USE_NTSYNC` is retired, and esync leftovers were removed.
- **NVIDIA extras:** `PROTON_NVIDIA_LIBS` (nvcuda, nvenc, nvml and nvoptix; nvml is on by default), `PROTON_NVIDIA_LIBS_NO_32BIT` and `PROTON_ZLUDA=1` (32-bit PhysX on AMD; native build only).
- **Input and misc:**
  - Input: `PROTON_PREFER_SDL` / `PROTON_USE_SDL` and `PROTON_NO_STEAMINPUT`.
  - Discord Rich Presence: `PROTON_DISCORD_BRIDGE`.
  - Block hosts: `WINE_BLOCK_HOSTS`.
  - Window decorations: `PROTON_NO_WM_DECORATION`.
  - Video playback: `PROTON_MEDIA_FORCE_GST` and `PROTON_GST_VIDEO_ORIENTATION`.
  - Integer scaling: `WINE_FULLSCREEN_INTEGER_SCALING`.
  - Wine defaults to Windows 11. The Proton media converter is disabled because enough codecs are shipped. The build uses -O2 (reverted from -O3).
  - `user_settings.py` is read from the Proton directory or the game's compatdata.
- **docs/THREAD_PRIORITY.md:** Proton maps Windows thread priorities to niceness. This needs `*  hard  nice  -15` in `/etc/security/limits.d/` (any value from -20 to 0). **BrookOS should ship this.**
- docs/PRIME.md: use `DXVK_FILTER_DEVICE_NAME` to pick the GPU on multi-GPU systems.

### wine-cachyos (API only: default branch `proton_9.0` is stale; active branches `cachyos_11.0_<date>/main` and `main_native`)
The latest branch `cachyos_11.0_20261014/main` merges topic branches:
- `_em*` (Proton-EM wine)
- `_em_upstream_pipewire*` (the new **winepipewire.drv**)
- `_exp_dualsense`
- `_exp_staging`
- `_exp_icu_forwarders`
- `_exp_crypt32_wc3`

Commits by M0n7y5 add the native PipeWire audio driver:
- "Enable realtime render dispatch by default", with an RLIMIT_RTTIME safety check.
- The driver follows the forced quantum and validates daemon data.

Other changes: winewayland popup reparenting (Etaash Mathamsetty) and an ntdll change to skip `%fs` switching for system threads.

Older Proton 9 branch commits include:
- fshack
- "winex11.drv: Do not shape layered windows in Gamescope"
- Xalia gamepad UI
- rawinput fixes
- an NVIDIA DriverVersion spoof bump
- vkd3d and Vulkan updates

Release builds standalone as `wine-cachyos` and `wine-cachyos-opt`; the wiki says both default to WoW64 and NTSync.

### gamescope-session (fork of SteamOS jupiter gamescope-session; upstream commit 2ad49ed0)
`usr/lib/steamos/gamescope-session` exports the following.

**Performance and latency:**
- `STEAM_USE_DYNAMIC_VRS=1` with a `RADV_FORCE_VRS_CONFIG_FILE` temp file (initial value 1x1).
- `STEAM_GAMESCOPE_DYNAMIC_FPSLIMITER=1`.
- Tearing, VRR and NIS support flags: `STEAM_GAMESCOPE_HAS_TEARING_SUPPORT`, `STEAM_GAMESCOPE_TEARING_SUPPORTED`, `STEAM_GAMESCOPE_VRR_SUPPORTED`, `STEAM_GAMESCOPE_NIS_SUPPORTED`.
- `vk_xwayland_wait_ready=false`.
- `ENABLE_GAMESCOPE_WSI=1`.
- `VKD3D_SWAPCHAIN_LATENCY_FRAMES=3`.
- `GAMESCOPE_DISABLE_ASYNC_FLIPS=1`.
- `STEAM_MULTIPLE_XWAYLANDS=1`.
- `STEAM_LAUNCH_WRAPPER_SCOPE=1` (one cgroup per game, for VRAM management).
- `WINEDLLOVERRIDES=dxgi=n`.
- `SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0`.
- `ulimit -n 524288`.
- `vblank_mode=0` and `MESA_VK_WSI_PRESENT_MODE=immediate` are present but commented out.

**Steam features:** mangoapp via `STEAM_USE_MANGOAPP=1`, HDR and color management, fan control, volume handler, drive adopt/unmount and `QT_QPA_PLATFORM_THEME=kde`.

**Gamescope invocation:** `--generate-drm-mode fixed --xwayland-count 2 --default-touch-mode 4 --hide-cursor-delay 3000 --max-scale 2 --fade-out-duration 200 -O *,eDP-1`. `DRM_MODE`, `XWAYLAND_COUNT`, `OUTPUT_CONNECTOR` and similar environment variables override these.

**Units and switching:**
- systemd user units `gamescope-session.target` / `gamescope-session.service`. `steam-launcher` runs Steam with `-steamos3 -steampal -steamdeck -gamepadui`.
- Other units: mangoapp, ibus and xbindkeys. `cachyos-gamescope-autologin.service` returns the user to gamescope on logout.
- `steamos-session-select persistent|oneshot|gamescope|plasma` writes `/etc/{plasmalogin,sddm}.conf.d/zz-steamos-autologin.conf` through pkexec and a polkit policy.
- `holo-update` stubs updates with exit 7.

### cachyos-vapor
SteamOS Vapor/VGUI Plasma 6 look-and-feel, color schemes, GTK theme and Konsole profile (credit GloriousEggroll). No perf content.

### firefox-wayland-cachy-hg (PKGBUILD)
Builds mozilla-unified autoland. Build flags:
- `--enable-default-toolkit=cairo-gtk3-wayland-only` (no X11).
- clang/lld with `--enable-lto=cross,full` and `MOZ_PGO=1`, profiled headless under `cage`.
- `--enable-optimize=-O3`, `--enable-rust-simd`, `--enable-wasm-simd`.
- JXL enabled.
- Crash reporter, updater, telemetry, webspeech and necko-wifi disabled.

`vendor.js` enables JXL and turns off the default-browser check.

### CachyOS-Browser-Common
Patch set for Cachy-Browser (LibreWolf-based):
- `use-mcpu-native-with-lto-pgo.patch`: LTO ldflags use `-mcpu=x86-64-v3`.
- `add-mold-linker.patch`.
- Gentoo patches, including GCC LTO/PGO.
- KDE/Unity integration patches.
- LibreWolf patches: privacy, JXL default, uBO.
- `disable-pocket` and `stop-undesired-requests` sed patches.
- `0023-...dont-advertise-hdr-support-on-wayland`.

### CachyOS-Browser-Settings
See §8. It also includes `cachy-browser.psd`, a profile-sync-daemon browser definition for `~/.cachy` profiles.

### profile-sync-daemon (fork of graysky2 psd)
Keeps browser profiles in tmpfs and rsyncs them back hourly (`psd-resync.timer` `OnUnitActiveSec=1h`). It supports overlayfs via `fuse-overlayfs`, crash-recovery snapshots (`BACKUP_LIMIT=5`) and an optional suspend sync. The service runs in `background.slice`. Contrib browser files add zen, floorp, brave, thorium, edge and firefox-flatpak. It reduces disk I/O and speeds up the browser.

---

## 3. Live ISO and CLI ISO

### CachyOS-Live-ISO (archiso profile "desktop")
**Boot:** GRUB on UEFI, syslinux on BIOS (systemd-boot entries kept). Menu: CachyOS (linux-cachyos), CachyOS LTS, and Legacy (nomodeset, LTS). The UEFI loader timeout is 15.

**Kernel cmdline (default entries):**
```
archisobasedir=arch archisosearchuuid=... cow_spacesize=10G copytoram=auto module_blacklist=pcspkr i915.modeset=1 amdgpu.modeset=1 nvme_load=yes
```
**Fallback entry:** `module_blacklist=nvidia,nvidia_modeset,nvidia_uvm,nvidia_drm nomodeset copytoram=n`.

**Image:**
- squashfs compressed `xz -Xbcj x86 -b 1M -Xdict-size 1M`.
- initramfs hooks `base udev microcode modconf memdisk archiso* block filesystems keyboard`, `COMPRESSION="xz"`. An older changelog entry mentions zstd 19.

**Kernel packages:** linux-cachyos and linux-cachyos-lts, each with `-nvidia-open` and `-zfs` prebuilt modules; `nvidia-utils`; `power-profiles-daemon`; `realtime-privileges`; `rtkit`; pipewire with pipewire-alsa, pipewire-jack and pipewire-pulse; `cachyos-settings`; `cachyos-drm-awaiter`; `chwd`; `cachyos-kde-settings`; `cachyos-rate-mirrors`; and `occt` (a stress tester).

**Live services:**
- Enabled: NetworkManager, systemd-networkd, systemd-resolved, systemd-timesyncd with time-wait-sync (`TimeoutStartSec=30s`), sshd, ModemManager, bluetooth, pcscd, pacman-init (keyring), and VM guest tools for VirtualBox, VMware and Hyper-V.
- journald uses volatile storage; logind is set not to suspend.
- `systemd-gpt-auto-generator` is masked (symlink to null).
- Live user `liveuser` autologins through plasmalogin.

**Live skel:**
- `kscreenlockerrc` Autolock=false.
- `kwalletrc` Enabled=false.
- `kded5rc` device_automounter autoload=false.
- powerdevil: display never turns off on AC, plus SpecialBehavior noSuspend.
- The plasma-login kwin_wayland override uses `--no-lockscreen --no-global-shortcuts --no-kactivities --locale1`.

**Pacman (ISO):** `ParallelDownloads = 10`, `DisableDownloadTimeout`, `DisableSandbox`, `Architecture = auto`. The CachyOS-patched pacman auto-detects v3.

**Install helpers:**
- `calamares-online.sh` refreshes the keyrings, sets `timedatectl set-ntp true` and updates calamares.
- `removeun` / `remove-nvidia` remove the ISO-only packages and remove nvidia packages if `chwd --is_nvidia_card` finds nothing. VM guest tools are removed on bare metal.
- `_try_v3` swaps in the v3 pacman.conf.
- `dmcheck` picks the display manager in the order ly, plasma-login-manager, sddm, gdm, cosmic-greeter, lightdm, lxdm, noctalia-greeter.

`sysctl 99-local.conf`: only `net.ipv6.conf.default.use_tempaddr = 2`.

**CHANGELOG (61 KB) highlights for defaults:**
- 26.11:
  - EAC kernel (`linux-cachyos-eac`) and secure-boot tooling.
  - `cachyos-drm-awaiter` replaces early KMS and nvidia-module-loader.
  - The `kms` hook is no longer added; Plymouth is optional and uses simpledrm.
  - systemd-boot `console-mode max`.
  - Root partition type `SD_GPT_ROOT_X86_64`.
  - systemd-oomd is back and enabled by default; it kills based on swap usage and ignores the user session.
  - sysctl dirty ratios now cap writeback on slow disks and USB drives.
  - REISUB is allowed.
  - game-performance gained tlpctl support.
  - `bpftune-gaming`.
  - `linux-cachyos-server` THP madvise.
  - intel-lpmd only on hybrid CPUs.
  - mutter tearing patches.
- 26.06: user services get a 15 s start and 10 s stop timeout.
- 26.04: NVMe I/O scheduler changed from none to kyber.
- 26.01: single-level zstd on NVMe.
- 25.11: zram skips incompressible pages.
- 25.03:
  - Wine defaults to WoW64 and NTSync.
  - `dlss-swapper`.
- 25.02: Propeller plus AutoFDO kernel ("~10%").
- 24.12: reworked sysctl.
- 24.11: thp-shrinker `max_ptes_none` 80%.
- 24.07:
  - power-profiles-daemon on AMD toggles CPB boost and raises the lowest frequency for better 1% lows.
  - `game-performance` script.
- Older:
  - Swap disabled by default because zram is generated dynamically.
  - zswap disabled on the cmdline.
  - `bpftune` was added to cachyos-settings.

### CachyOS-CLI-ISO (older, text-mode ISO)
- GRUB `GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"`.
- UEFI entries for normal, speech and copy-to-RAM boot, with microcode as separate initrds.
- Services: haveged, ntpd, reflector, avahi, qemu-guest-agent, sshd and NetworkManager.
- journald volatile; logind no-suspend.
- `ZPOOL_VDEV_NAME_PATH=1`.

Little perf content beyond the ISO itself.

### liveuser-desktop-settings (2021, legacy)
Live-user KDE dotfiles (kwin big_icons switcher, qt5ct), a calamares launcher and `mkinitcpio.conf` with `COMPRESSION="zstd"` and hooks `base udev autodetect modconf block filesystems keyboard fsck`. No perf content beyond zstd initramfs.

---

## 4. Installers

### 4.1 cachyos-calamares (the current GUI installer: a Calamares fork with configs under `src/modules`, plus the gucc backend)

**Sequence (online):** welcome → locale → keyboard → bootloader chooser → partition → desktop chooser → netinstall → users. The exec phase runs:
1. partition, zfs, mount
2. gucc `modify_mk_hook`, which defers initramfs generation so it runs once
3. pacman init: ranks mirrors with cachyos-rate-mirrors and copies the v3/v4 mirrorlists and keyring
4. `detect-architecture`, then pacstrap
5. chwd (hardware drivers), packages
6. fstab, plymouthcfg, initcpiocfg, initcpio
7. displaymanager, gucc hwclock, grubcfg, bootloader
8. services, shellprocess, ufw
9. Btrfs installation snapshot

**Mount options** (mount.conf):
| fs | options |
|---|---|
| default | `defaults,noatime` |
| btrfs | `defaults,noatime` + HDD `compress=zstd`, SSD `compress=zstd`, **NVMe `compress=zstd:1`** |
| ext4 | `defaults,noatime` |
| xfs | `defaults,lazytime,noatime,inode64,logbsize=256k,noquota` |
| f2fs | `defaults,compress_algorithm=lz4,compress_chksum,gc_merge,lazytime` |
| efi | `defaults,umask=0077` |

**Btrfs subvolumes:** `/@`, `/@home`, `/@root`, `/@srv`, `/@cache`→/var/cache, `/@tmp`→/var/tmp, `/@log`→/var/log.

**fstab:** `/tmp` on tmpfs only on SSD (`defaults,noatime,mode=1777`).

**ZFS:** pool `zpcachyos` with `ashift=12 autotrim=on atime=off xattr=sa acltype=posixacl normalization=formD`, datasets `compression=lz4`, and separate ROOT/cos/{root,home,varcache,varlog}.

**Partition (partition.conf):**
- GPT, default filesystem btrfs; the choices are btrfs, xfs, ext4, f2fs and zfs.
- `userSwapChoices: none` and `initialSwapChoice: none`, so no swap partition is offered (zram comes from cachyos-settings).
- LUKS2.
- ESP: `/boot` at 2048M by default, `/boot/efi` at 512M for GRUB, `/boot` at 4096M for Limine.

**Bootloader:**
- Chooser default **limine**; the other options are GRUB, rEFInd and systemd-boot.
- `bootloader.conf`: `kernelParams: [quiet, nowatchdog]`; systemd-boot `timeout 5` and `console-mode max`; `installEFIFallback: true`.
- Post-setup for Limine: `limine-mkinitcpio-hook`, `limine-snapper-sync` with `cachyos-snapper-support` and the `sd-btrfs-overlayfs` hook to boot snapshots. For systemd-boot: `sdboot-manage gen`.
- **GRUB** (grubcfg.conf):
  - `kernel_params: nowatchdog nvme_load=YES`.
  - `GRUB_TIMEOUT=5`, `GRUB_DISABLE_RECOVERY=true`, `GRUB_DISABLE_BOOTNEXT=true`, os-prober enabled.
  - Top-level kernel linux-cachyos.

**initramfs (initcpiocfg.conf):** `useSystemdHook: true`, `remove: [kms]`. Plymouth themes: `cachyos-bootanimation`, or `cachyos` on amdgpu (an amdgpu limit on laptop plus second monitor), with `plymouth_simpledrm: true`.

**Services enabled:**
- NetworkManager, cups, avahi-daemon, systemd-timesyncd, bluetooth and firewalld/ufw.
- **fstrim.timer**.
- zfs units, plus vboxservice and vmtoolsd when present.
- User `arch-update.timer` (cachy-update).

**Shell:** fish if installed, else zsh (`shell-setup`).

**pacstrap base:** base, base-devel, btrfs-progs, cachyos-hooks, cachyos-keyring, the cachyos/v3/v4 mirrorlists, cachyos-rate-mirrors, **cachyos-settings**, chwd, mkinitcpio and filesystem tools.

**netinstall (default-selected):**
- Kernels `linux-cachyos(+headers)` and `linux-cachyos-lts(+headers)` (handheld: `linux-cachyos-deckify`).
- CachyOS apps: `cachyos-hello`, `cachyos-kernel-manager`, `cachyos-packageinstaller`, `cachyos-settings` and `cachyos-micro-settings`.
- Audio: `pipewire-pulse`, `wireplumber`, `pipewire-alsa`, `realtime-privileges`.
- Power: `cpupower`, `power-profiles-daemon`, `upower`.
- Tools: `ufw`, `plocate`, `pacman-contrib`, `rebuild-detector`, and the GStreamer libav and dav1d plugins.
- KDE group: plasma-desktop, plasma-login-manager, `cachy-update`, `cachyos-kde-settings`, the Nord and Emerald themes, char-white, haruna, `powerdevil`, `kio-admin` and `xsettingsd`.

**`detect-architecture`** inserts repos above `[cachyos]`:
- **Zen 4 / Zen 5** (family 0x19 model 0x10–0x1f or 0x60–0xaf, or family 0x1a, and avx512f present): `[cachyos-znver4]`, `[cachyos-core-znver4]`, `[cachyos-extra-znver4]` from the v4 mirrorlist.
- **x86-64-v4:** `[cachyos-v4]`, `[cachyos-extra-v4]`, `[cachyos-core-v4]`.
- **x86-64-v3:** `[cachyos-v3]`, `[cachyos-extra-v3]`, `[cachyos-core-v3]`.

### 4.2 calamares-config (older standalone config repo)
Same layout as above at an earlier stage: a mount.conf with the same options; mhwdcfg, mount and packages Python modules; and the scripts `try-v3`, `update-mirrorlist` and `pacstrap_calamares`. These are superseded by cachyos-calamares.

### 4.3 calamares (CachyOS mirror of upstream Calamares)
Upstream Calamares source. No CachyOS perf content beyond what cachyos-calamares carries.

### 4.4 New-Cli-Installer (C++ "gucc" library, shared by Calamares since 26.11)
- `kDefaultKernelParams = {"quiet", "zswap.enabled=0", "nowatchdog"}`. The GRUB default cmdline is `loglevel=3 quiet`.
- `get_default_mount_opts()`:
  - btrfs SSD: `defaults,noatime,compress=zstd:1`; btrfs HDD: `defaults,noatime,compress=zstd`.
  - ext4: `defaults,noatime`.
  - f2fs: `defaults,compress_algorithm=lz4,compress_chksum,gc_merge,lazytime`.
  - xfs: `defaults,lazytime,noatime,inode64,logbsize=256k,noquota`.
  - vfat: `umask=0077`.
- Headless JSON config: default kernel `linux-cachyos`, default bootloader `grub`, `mount_opts` auto, and server profiles (minimal, web, container-host, db, cockpit).
- ufw defaults: deny incoming, allow outgoing.
- The initramfs is generated once (deferral hook) and the `kms` hook is removed. The hardware clock is UTC. A cmdline file is created for systemd-boot.

### 4.5 cachyos-cli-installer (legacy Python wrapper around archinstall)
Patches archinstall for a separate ext2 /boot on BIOS and LUKS GRUB. Its kernel swap target is the long-dead `linux-cacule`. Obsolete; no useful defaults.

### 4.6 archinstall (fork of upstream archinstall)
Stock upstream content with no CachyOS-specific tweaks found (grep for cachy, noatime and compress found nothing). No perf content.

### 4.7 install-scripts (legacy, EndeavourOS-derived)
Calamares helper scripts: an old NVIDIA dkms detection, a GRUB fix, mirror ranking and netinstall.yaml. Superseded. No perf content of value.

---

## 5. Tools

- **CachyOS-Welcome (cachyos-hello, Rust/GTK):**
  - Tweak toggles map to units: psd → user `psd.service`; oomd → `systemd-oomd.service`; bpftune → `bpftune.service`; ananicy → `ananicy-cpp.service`; bluetooth; cachy-update → user `arch-update.timer`.
  - "Install gaming packages" installs `cachyos-gaming-meta` and `cachyos-gaming-applications`.
  - DNS page: preset resolvers, DoT/DoH/DoQ via blocky, and a speed-test ranking.
  - Also handles kernel and mirror updates and Winboat.
- **packageinstaller:** a libalpm app store with opt-in AUR (built with paru after in-app PKGBUILD review and static analysis), Flatpak and AppImage support. No perf content.
- **cachy-update:** an Arch-Update fork, an update notifier with a systray applet. Not a perf tweak, though it is enabled by default (user timer).
- **cachyos-recovery:** a mkosi-built recovery UKI (about 70 MB on the ESP) that restores and boots Btrfs snapshots through overlayfs and supports LUKS and Secure Boot. Useful robustness feature; no perf content.
- **cachyos-wsl:** a WSL rootfs with `systemd=true`. First setup switches to the znver4/v4/v3 repos (`optimize-repos`) and ships cachyos-settings with **zram disabled** (WSL manages memory). `ParallelDownloads=5`.
- **WSL:** a fork of microsoft/WSL with no CachyOS changes found. No perf content.
- **cachyos-kdump-tools:** kdump on panic via `crashkernel=256M`. `disable-hardened-kexec.conf` sets `kernel.kexec_load_disabled=0` and `kernel.sysrq=1`. Debugging only.
- **cachy-chroot:** a Rust tool that auto-mounts Btrfs, ZFS and LUKS roots for chroot. No perf content.
- **cachyos-benchmarker:** a benchmark suite (stress-ng, perf sched, schbench, cyclictest, y-cruncher, blender, x265 and more) plus `kernel-autofdo.sh`, which collects a workload for AutoFDO kernel profiles. Useful for BrookOS QA.
- **ntn:** wraps commands with `chrt -i 0 ionice -c 3` (idle CPU and I/O class) for make, gcc, cmake, mkinitcpio, mksquashfs, tar, zstd, xz, balooctl and ccache. A responsiveness tweak worth considering, though ananicy-cpp covers most of it.
- **neofetch / fastfetch:** forks carrying CachyOS logos. No perf content.
- **rclone:** a fork tracking upstream (recent commits are upstream ones by Nick Craig-Wood). No perf content.
- **cachyos-community-software-tips:** a list of community apps (Thorium, MangoHud, proton-cachyos). No perf content.
- **distribution, .github, statuspage (Upptime), discord-moderation-bot, bin-pastebin, CachyOS-services:** project infrastructure. No perf content.

---

## 6. KDE and other desktop settings

### cachyos-kde-settings (the important one)
`/etc/skel/.config`:
- `kdeglobals`: `AnimationDurationFactor=0.25`, BreezeDark, breeze-dark icons.
- `baloofilerc`: **`Indexing-Enabled=false`**, plus a large exclude-filter list.
- `Trolltech.conf`: `GUIEffects=none`.
- `ksmserverrc`: `loginMode=emptySession`.
- `plasmashellrc`: `PlasmaTransientsConfig PreloadWeight=0`, floating panel.
- `kwinrc`: Breeze decoration only. **No compositor overrides** (no latency, vsync or tearing keys), so KWin defaults apply.
- `arkrc`, `kcminputrc` (capitaine-cursors), panel layout and `libinput-gestures.conf`.
- gtk-3/4 `settings.ini` and xsettingsd (Breeze, animations on).

SDDM: `/usr/lib/sddm/sddm.conf.d/zz-wayland.conf` sets `DisplayServer=wayland` with `CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1`; `general.conf` sets `Numlock=none` and HiDPI. Newer installs use plasma-login-manager.

### Others
- **cachyos-gnome-settings:** dconf for a dark theme, numlock and tap-to-click. No perf content.
- **cachyos-compositor-settings:** the shared Wayland-compositor base, with `uwsm/env.d` setting `ELECTRON_OZONE_PLATFORM_HINT=auto` and `QT_QPA_PLATFORM="wayland;xcb"`. kanshi turns `adaptive_sync off`. Also kitty, portals and mimeapps.
- **cachyos-compositor-tinted:** README and license only. No perf content.
- **cachyos-noctalia-settings:** Noctalia shell and greeter TOML configs. No perf content.
- **cachyos-umbriel-settings:** turns animation blur off and two animations off, and disables overview background blur (a light perf benefit).
- **cachyos-mango-noctalia:** MangoWM with `allow_tearing = 2` and optimized blur (2 passes).
- **cachyos-hypr-noctalia:** Hyprland (Lua config) with `vrr = 3`, `render.direct_scanout = 2`, `xwayland.force_zero_scaling`, fast animations, swallow, `GBM_BACKEND=nvidia-drm` in profile.d, and commented NVIDIA environment hints (`LIBVA_DRIVER_NAME`, `__GL_GSYNC_ALLOWED`).
- **cachyos-hyprland-settings (classic):** `vrr = 2`, blur disabled, `ELECTRON_OZONE_PLATFORM_HINT=auto`, Hyprland logo disabled.
- **cachyos-niri-noctalia / cachyos-niri-settings:** niri KDL configs with Wayland environment variables for Electron and Qt, and blur set to 2 passes.
- **cachyos-jay-noctalia:** the jay compositor with `vrr variant1, cursor-hz=90` and `tearing.mode variant1`.
- **cachyos-qtile-settings, cachyos-i3wm-settings, cachyos-openbox-settings, cachyos-spectrwm-config:** X11 WM dotfiles, with picom on the `glx` backend. spectrwm picom sets `vsync=false` and `unredir-if-possible=false`. No real perf content.
- **cachyos-wayfire-settings:** `max_render_time = -1`, blur on toplevels.
- **cachyos-xfce-settings:** xfwm4 `unredirect_overlays=true`, which lets fullscreen games bypass the compositor.
- **cachyos-picom-config:** picom on `glx` with `vsync = true` and **`unredir-if-possible = true`**, which unredirects fullscreen windows.
- **cachyos-fish-config:** aliases (`update` = rate-mirrors plus `-Syu`, `cleanup`, `jctl`, `big`, `rip`), `done.fish` notifications and a bat man pager. No perf content.
- **cachyos-zsh-config:** oh-my-zsh and powerlevel10k setup. No perf content.
- **cachyos-alacritty-config:** colors and font. No perf content.
- **cachyos-micro-settings:** micro editor colorschemes and syntax files. No perf content.
- **cachyos-st-config / cachyos-dwm-config:** patched suckless sources. No perf content.

### Themes, icons and boot splash
These have no perf content and are branding only:
- **CachyOS-Emerald-KDE, CachyOS-Nord-KDE, CachyOS-Lavender-KDE, cachyos-iridescent-kde, Iridescent, Brise, Arch:** Plasma look-and-feel packages. Their `defaults` files set colors, icons, the splash, and the big_icons window switcher.
- **char-white:** icon theme.
- **CachyOS-icons:** a few app SVGs.
- **cachyos-wallpapers:** PNG wallpapers, including the Limine splash.
- **cachyos-kofuku:** a bspwm rice.
- **Plymouth themes:**
  - cachyos-plymouth-theme: `two-step` with BGRT firmware background.
  - plymouth-theme: `cachyos-bootanimation`, two-step with an end animation.
  - plymouth-themes: blue and green spinners.
  - All use `Transition=none`, so they add no fade delay.

---

## 7. Wiki summary (English pages; delegated read, condensed)

**Kernels:**
- `linux-cachyos` is the default kernel: EEVDF with CachyOS tunables, 1000 Hz, Clang ThinLTO, AutoFDO and Propeller.
- Variants: `-bore`, `-bmq` (no sched-ext), `-eevdf`, `-lts` (BORE), `-deckify` (handhelds, BORE, RCU lazy), `-server` (300 Hz, no preempt), `-rt-bore` (worse for gaming), `-hardened`, `-rc` and `-eac`.
- Prebuilt nvidia-open, nvidia and ZFS modules (no dkms).
- Patches: amd-pstate preferred core, BBRv3, ADIOS I/O scheduler (not default), DMEM VRAM cgroup, HDMI VRR and ALLM on AMD, ACS override, handheld HID.
- Builds for v3, v4 and znver4.

**sched-ext:**
- Tools: `scx-scheds`, `scx-tools`, `scxctl` and `scx_loader`.
- To start one at boot, put `/etc/scx_loader/config.toml` with `default_sched`/`default_mode` in place, then run `systemctl enable --now scx_loader`.
- Recommended for gaming:
  - `scx_lavd --performance` (the handheld default).
  - `scx_bpfland -m performance`.
  - `scx_flash -m all`.
  - `scx_cosmos -s 700 -S`.
  - `scx_p2dq --task-slice true -f --sched-mode performance`.
- CachyOS's patched power-profiles-daemon maps Power Saver → PowerSave, Balanced → Auto and Performance → Gaming.

**cachyos-settings (values the wiki shows):**
- `kernel.sched_rt_runtime_us=-1`.
- I/O schedulers: HDD bfq, SATA SSD mq-deadline, NVMe none (kyber since 26.04).
- zram via zram-generator; zswap off via cmdline and the `30-zram.rules` udev rule.
- Tools: `game-performance` (powerprofilesctl performance plus screensaver inhibit), `dlss-swapper`, `zink-run`, `pci-latency.service`, `kerver`.
- ananicy-cpp enabled; do not combine it with gamemode.

**Gaming:**
- Install `cachyos-gaming-meta` and `cachyos-gaming-applications`. The wiki recommends proton-cachyos-slr per game, with Valve Proton as the global default.
- Launch-option pattern: `game-performance %command%`. `LD_PRELOAD=""` avoids game-recorder stutter.
- Shader cache: `MESA_SHADER_CACHE_MAX_SIZE=12G` (AMD); `__GL_SHADER_DISK_CACHE_SIZE=12000000000` and `__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1` (NVIDIA).
- Turn off Steam shader pre-caching when using Proton-CachyOS.
- gamescope example: `-W -H -w -h -S fit -F fsr --mangoapp`.
- EAC v2 needs Secure Boot plus the signed `linux-cachyos-eac` kernel.

**Power:**
- amd-pstate EPP (active) by default, with the powersave governor plus an EPP hint.
- `rcutree.enable_rcu_lazy=1` is optional.
- On X3D CPUs: `amd_x3d_mode=cache`.
- thermald for Intel laptops.

**Filesystems:** Btrfs default with snapper and snap-pac (limit 10 snapshots). XFS for speed, F2FS for flash, ZFS with prebuilt modules. Game drives mounted with `defaults,exec,rw,noatime,nofail`. `fstrim.timer` enabled.

**Boot:**
- Default cmdline examples: `zswap.enabled=0 nowatchdog quiet splash`, plus `rd.udev.log_priority=3` for Limine.
- No fallback initramfs.
- Microcode via the mkinitcpio hook.
- systemd hook in the initramfs.
- If `systemd-analyze blame` shows it is slow, mask `cachyos-rate-mirrors`.
- To hide GRUB: `GRUB_TIMEOUT=0`.

**NVIDIA:**
- chwd installs nvidia-open automatically and enables switcheroo-control. PRIME offload uses `prime-run`.
- `NVreg_EnableGpuFirmware=0` is optional.
- `NVPRESENT_ENABLE_SMOOTH_MOTION=1` on RTX 40/50.
- `nvidia-powerd` is enabled on laptops.

**Handheld:** deckify kernel, scx_lavd, Limine, gamescope-session-cachyos, steamos-manager, inputplumber, PipeWire min quantum 256.

**Two conflicts to verify in CachyOS-Settings:**
- NVMe scheduler: the wiki snippet shows `none`, but the 26.04 changelog says `kyber`.
- systemd-oomd: disabled in 25.07, then re-enabled by default in 26.11.

---

## 8. Browser performance prefs (CachyOS-Browser-Settings `cachyos.cfg`)
```
browser.cache.disk.enable=false            browser.tabs.unloadOnLowMemory=true
media.ffmpeg.vaapi.enabled=true            media.gpu-process-decoder=true
gfx.webrender.all=true                     gfx.webrender.precache-shaders=true
gfx.webrender.compositor=true              layers.gpu-process.enabled/force-enabled=true
gfx.canvas.accelerated=true (+cache-items 4096, cache-size 512)
gfx.content.skia-font-cache-size=20        image.cache.size=10485760
image.mem.decode_bytes_at_a_time=32768     image.mem.shared.unmap.min_expiration_ms=120000
media.memory_cache_max_size=65536          media.memory_caches_combined_limit_kb=2560000
media.cache_readahead_limit=7200           media.cache_resume_threshold=3600
browser.cache.memory.max_entry_size=153600 content.notify.interval=100000
network.http.max-connections=1800          network.http.max-persistent-connections-per-server=10
network.http.max-urgent-start-excessive-connections-per-host=5
network.http.pacing.requests.enabled=false network.dnsCacheExpiration=3600
network.ssl_tokens_cache_capacity=10240    dom.webgpu.enabled=true
browser.startup.preXulSkeletonUI=false     dom.enable_web_task_scheduling=false
network.predictor/prefetch/dns-prefetch/speculative-connect = off (privacy)
toolkit.telemetry.* locked off; https-only mode; media.autoplay.default=5
```
Several of these come from Betterfox. Pair them with profile-sync-daemon.

---

## Repos covered
- proton-cachyos: env-var catalogue (NTSync default, pipewire driver, FSR4/DLSS/XeSS upgrade, low-latency DXVK/VKD3D, OptiScaler, shader cache, thread-priority limits); see §2.
- wine-cachyos: API only. 11.0 branches merge Proton-EM wine, winepipewire.drv (realtime dispatch), DualSense and wayland fixes.
- gamescope-session: SteamOS game-mode session with the full environment-variable set, gamescope flags and the session switcher; see §2.
- cachyos-vapor: SteamOS Vapor Plasma theme. No perf content.
- firefox-wayland-cachy-hg: Wayland-only, -O3, full cross-LTO, PGO build of Firefox.
- CachyOS-Browser-Common: Cachy-Browser patches (x86-64-v3 LTO, mold, LibreWolf/Gentoo/KDE patches).
- CachyOS-Browser-Settings: perf and privacy prefs (§8) plus a psd browser definition.
- profile-sync-daemon: browser profile in tmpfs with an hourly resync.
- CachyOS-Live-ISO: kernel cmdline, services, live skel and the changelog of defaults; see §3.
- CachyOS-CLI-ISO: text ISO, `loglevel=3 quiet`, volatile journald. Minimal perf content.
- New-Cli-Installer: gucc defaults (cmdline `quiet zswap.enabled=0 nowatchdog`, per-filesystem mount options).
- cachyos-cli-installer: legacy archinstall wrapper. Obsolete, no perf content.
- cachyos-calamares: current installer configs (Btrfs/zstd, noatime, no swap, Limine, systemd initramfs without kms, fstrim, arch detection).
- calamares: upstream Calamares mirror. No CachyOS perf content.
- calamares-config: older standalone installer config (same mount options). Superseded.
- install-scripts: legacy EndeavourOS-style helper scripts. No perf content of value.
- archinstall: upstream archinstall fork with no CachyOS tweaks. No perf content.
- CachyOS-Welcome: tweak toggles (psd, oomd, bpftune, ananicy, bluetooth, cachy-update), gaming meta install, DNS.
- packageinstaller: app store (AUR, Flatpak, AppImage). No perf content.
- cachy-update: Arch-Update-based notifier, enabled by default. No perf content.
- cachyos-recovery: snapshot-recovery UKI. No perf content.
- cachyos-wsl: WSL image with auto v3/v4/znver4 repo switching; zram disabled.
- WSL: Microsoft WSL fork with no CachyOS changes. No perf content.
- cachyos-kdump-tools: kdump with `crashkernel=256M`, kexec and sysrq enabled. Debugging only.
- cachy-chroot: chroot helper. No perf content.
- cachyos-benchmarker: benchmark and latency suite plus an AutoFDO profiling script.
- kernel-manager: skipped as instructed (covered elsewhere).
- cachyos-community-software-tips: app list. No perf content.
- distribution: issue tracker only. No perf content.
- .github: org profile README. No perf content.
- statuspage: Upptime status site. No perf content.
- discord-moderation-bot: Discord bot. No perf content.
- bin-pastebin: pastebin server. No perf content.
- neofetch: fork with a CachyOS logo. No perf content.
- fastfetch: fork with a CachyOS logo. No perf content.
- rclone: fork tracking upstream. No perf content.
- ntn: idle CPU and I/O priority wrapper for heavy commands (minor responsiveness tweak).
- CachyOS-services: list of hosted services. No perf content.
- liveuser-desktop-settings: legacy live-user dotfiles with a zstd initramfs. Minimal perf content.
- cachyos-kde-settings: animation factor 0.25, Baloo off, GUIEffects=none, empty session, Wayland SDDM.
- cachyos-gnome-settings: dark theme, numlock, tap-to-click. No perf content.
- cachyos-compositor-settings: Wayland environment variables (Electron Ozone, Qt wayland), adaptive_sync off. Minor.
- cachyos-compositor-tinted: README and license only. No perf content.
- cachyos-noctalia-settings: Noctalia shell config. No perf content.
- cachyos-umbriel-settings: some animations and blur disabled. Minor.
- cachyos-mango-noctalia: allow_tearing=2, optimized blur. Minor.
- cachyos-hypr-noctalia: vrr=3, direct_scanout=2, NVIDIA GBM environment variable. Minor and not KDE.
- cachyos-hyprland-settings: vrr=2, blur off. Minor and not KDE.
- cachyos-niri-noctalia: Wayland environment variables, blur passes. Minor.
- cachyos-niri-settings: Wayland environment variables. Minor.
- cachyos-jay-noctalia: VRR and tearing enabled. Minor.
- cachyos-qtile-settings: dotfiles with picom glx. No perf content.
- cachyos-i3wm-settings: dotfiles. No perf content.
- cachyos-openbox-settings: dotfiles with picom. No perf content.
- cachyos-wayfire-settings: max_render_time=-1. Minor.
- cachyos-xfce-settings: xfwm4 unredirect_overlays=true. Minor.
- cachyos-picom-config: glx backend, vsync, unredir-if-possible. Minor.
- cachyos-fish-config: aliases and the done plugin. No perf content.
- cachyos-zsh-config: oh-my-zsh and p10k. No perf content.
- cachyos-alacritty-config: terminal theme. No perf content.
- cachyos-micro-settings: editor themes. No perf content.
- cachyos-st-config: patched st. No perf content.
- cachyos-spectrwm-config: dotfiles. No perf content.
- cachyos-dwm-config: patched dwm. No perf content.
- CachyOS-Emerald-KDE: Plasma theme. No perf content.
- CachyOS-Nord-KDE: Plasma theme. No perf content.
- CachyOS-Lavender-KDE: Plasma theme. No perf content.
- cachyos-iridescent-kde: Plasma theme. No perf content.
- Iridescent: Plasma theme (duplicate). No perf content.
- Brise: Plasma theme. No perf content.
- Arch: Plasma theme and icons. No perf content.
- CachyOS-icons: API tree only, a few SVGs. No perf content.
- cachyos-wallpapers: API tree only, PNG wallpapers. No perf content.
- cachyos-plymouth-theme: two-step BGRT theme, Transition=none. No perf content.
- plymouth-theme: cachyos-bootanimation theme. No perf content.
- plymouth-themes: spinner themes. No perf content.
- char-white: icon theme. No perf content.
- cachyos-kofuku: bspwm rice. No perf content.
- wiki: performance, gaming, kernel, sched-ext, repos, NVIDIA, power, zram and filesystem pages summarized in §7.
- website: marketing copy only (CPU-optimized repos, tuned kernel). Nothing beyond the wiki.
