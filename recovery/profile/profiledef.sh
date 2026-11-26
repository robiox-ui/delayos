#!/usr/bin/env bash
# shellcheck disable=SC2034
# DelayOS recovery environment ("DelayOS 복구", docs/recovery.md): a small archiso system that
# build.sh builds in netboot mode (kernel + initramfs + squashfs, no ISO) and puts into the main
# image under /usr/share/delayos/recovery/image. The installer copies it to the hidden recovery
# partition (label DELAYOS-RE); GRUB starts it with archisobasedir=delayos-re.

iso_name="delayos-re"
iso_label="DELAYOS_RE"
iso_publisher="DelayOS"
iso_application="DelayOS Recovery Environment"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="delayosre"       # mkarchiso allows [a-z0-9] only; build.sh stores the result as delayos-re/
buildmodes=('netboot')
bootmodes=()
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# xz + BCJ: the image is read once at start, size matters more than speed here
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/usr/local/bin/delay-recovery"]="0:0:755"
  ["/usr/local/bin/delay-recovery-session"]="0:0:755"
  ["/usr/local/bin/delay-deploy"]="0:0:755"
  ["/usr/local/bin/delay-snapshot"]="0:0:755"
  ["/usr/local/bin/delay-recovery-ctl"]="0:0:755"
)
