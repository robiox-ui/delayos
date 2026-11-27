#!/usr/bin/env bash
# shellcheck disable=SC2034
# DelayOS archiso profile (based on Arch "releng")

iso_name="delayos"
iso_label="DELAYOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="DelayOS"
iso_application="DelayOS Live/Install"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# zstd: much faster live boot/decompression than xz on old CPUs
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '9' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/20-delay-gamemode"]="0:0:440"
  ["/usr/local/bin/delay-gamemode"]="0:0:755"
  ["/usr/local/bin/delay-gamemode-root"]="0:0:755"
  ["/usr/local/bin/delay-open"]="0:0:755"
  ["/usr/local/bin/delay-android"]="0:0:755"
  ["/usr/local/bin/delay-winx"]="0:0:755"
  ["/usr/local/bin/systemsettings"]="0:0:755"
  ["/usr/local/bin/kcmshell6"]="0:0:755"
  ["/usr/lib/delayos/delay-kcm-route"]="0:0:755"
  ["/usr/lib/delayos/delay-desktop-menu"]="0:0:755"
  ["/usr/local/bin/delay-firstboot"]="0:0:755"
  ["/usr/local/bin/delay-lowmem-session"]="0:0:755"
  ["/usr/local/bin/delay-postinstall"]="0:0:755"
  ["/usr/local/bin/delay-eac"]="0:0:755"
  ["/usr/bin/delay-darkmode"]="0:0:755"
  ["/usr/bin/delay-run-in-terminal"]="0:0:755"
  ["/usr/bin/delay-shell"]="0:0:755"
  ["/usr/local/bin/delay-shell-layout"]="0:0:755"
  ["/usr/local/bin/delay-shell-activate"]="0:0:755"
  ["/usr/local/bin/delay-game-key"]="0:0:755"
  # DelayOS apps
  ["/usr/bin/delay-notepad"]="0:0:755"
  ["/usr/bin/delayfetch"]="0:0:755"
  ["/usr/bin/delay-calc"]="0:0:755"
  ["/usr/bin/delay-taskmanager"]="0:0:755"
  ["/usr/bin/delay-snip"]="0:0:755"
  ["/usr/bin/delay-files"]="0:0:755"
  ["/usr/bin/delay-terminal"]="0:0:755"
  ["/usr/bin/delay-settings"]="0:0:755"
  ["/usr/bin/delay-store"]="0:0:755"
  ["/usr/bin/delay-macapps"]="0:0:755"
  ["/usr/bin/delay-welcome"]="0:0:755"
  ["/usr/bin/delay-drivers"]="0:0:755"
  ["/usr/bin/delay-winengine"]="0:0:755"
  ["/usr/bin/delay-android-apps"]="0:0:755"
  ["/usr/bin/delay-gamecontrols"]="0:0:755"
  ["/usr/lib/delayos/delay-sys-helper"]="0:0:755"
  # Windows 전환 (dual-boot switch, docs/windows-switch.md)
  ["/usr/bin/delay-winboot"]="0:0:755"
  ["/usr/lib/delayos/delay-winboot-helper"]="0:0:755"
  # Hidden Windows for anti-cheat games (delay-winsetup, docs/windows-switch.md)
  ["/usr/local/bin/delay-winsetup"]="0:0:755"
  # Gaming performance (docs/gaming-performance.md): CPU-optimized packages, GPU drivers, Proton default, benchmark
  # Snapshots, recovery environment, deployment tool (docs/recovery.md)
  ["/usr/local/bin/delay-snapshot"]="0:0:755"
  ["/usr/local/bin/delay-deploy"]="0:0:755"
  ["/usr/local/bin/delay-recovery-ctl"]="0:0:755"
  ["/usr/lib/delayos/delay-recovery-info"]="0:0:755"
  ["/etc/grub.d/45_delayos-recovery"]="0:0:755"
  # Korean boot menu (10_delayos replaces grub's 10_linux, 30_delayos-firmware its 30_uefi-firmware)
  ["/etc/grub.d/10_delayos"]="0:0:755"
  ["/etc/grub.d/30_delayos-firmware"]="0:0:755"
  ["/usr/lib/delayos/delay-grub-ko"]="0:0:755"
  ["/usr/lib/delayos/delay-splash-handoff"]="0:0:755"
  ["/usr/lib/delayos/delay-render-detect"]="0:0:755"
  ["/usr/lib/delayos/delay-boot-tune"]="0:0:755"
  ["/usr/local/bin/delay-cpu-opt"]="0:0:755"
  ["/usr/local/bin/delay-gpu-setup"]="0:0:755"
  ["/usr/bin/delay-steam-compat"]="0:0:755"
  ["/usr/bin/delay-game"]="0:0:755"
  ["/usr/bin/delay-bench"]="0:0:755"
  # Tuning tools taken from CachyOS-Settings
  ["/usr/bin/dlss-swapper"]="0:0:755"
  ["/usr/bin/dlss-swapper-dll"]="0:0:755"
  ["/usr/bin/game-performance"]="0:0:755"
  ["/usr/bin/kerver"]="0:0:755"
  ["/usr/bin/pci-latency"]="0:0:755"
  ["/usr/bin/topmem"]="0:0:755"
  ["/usr/bin/zink-run"]="0:0:755"
  ["/usr/lib/iw-set-regdomain"]="0:0:755"
  ["/usr/lib/udev/audio-pm-ctl"]="0:0:755"
  ["/usr/lib/systemd/system-generators/xswap-generator"]="0:0:755"
  ["/usr/lib/systemd/user-generators/delayos-oomd-generator"]="0:0:755"
)
