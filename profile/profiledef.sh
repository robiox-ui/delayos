#!/usr/bin/env bash
# shellcheck disable=SC2034
# TEMUOS_LINUX archiso profile (based on Arch "releng")

iso_name="temuos_linux"
iso_label="TEMUOS_LINUX_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="TEMUOS_LINUX"
iso_application="TEMUOS_LINUX Live/Install"
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
  ["/etc/sudoers.d/20-temu-gamemode"]="0:0:440"
  ["/usr/local/bin/temu-gamemode"]="0:0:755"
  ["/usr/local/bin/temu-gamemode-root"]="0:0:755"
  ["/usr/local/bin/temu-open"]="0:0:755"
  ["/usr/local/bin/temu-android"]="0:0:755"
  ["/usr/local/bin/temu-winx"]="0:0:755"
  ["/usr/local/bin/temu-firstboot"]="0:0:755"
  ["/usr/local/bin/temu-lowmem-session"]="0:0:755"
  ["/usr/local/bin/temu-postinstall"]="0:0:755"
  ["/usr/local/bin/temu-eac"]="0:0:755"
  ["/usr/bin/temu-darkmode"]="0:0:755"
  ["/usr/bin/temu-run-in-terminal"]="0:0:755"
  ["/usr/bin/temu-shell"]="0:0:755"
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
  ["/usr/lib/systemd/user-generators/temuos-oomd-generator"]="0:0:755"
)
