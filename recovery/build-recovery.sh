#!/usr/bin/env bash
# Build the DelayOS recovery environment image (docs/recovery.md). Run as root on Arch.
#   recovery/build-recovery.sh <image-dir>
# Result: <image-dir>/delayos-re/{boot/x86_64/vmlinuz-*,boot/x86_64/initramfs-*.img,x86_64/airootfs.sfs,version}
# build.sh copies that to /usr/share/delayos/recovery/image of the ISO; `delay-deploy recovery`
# installs it on the recovery partition.
#
# Environment:
#   RE_KERNEL       kernel package (default linux-delayos; linux-lts works for a test build)
#   RE_PACMAN_CONF  pacman.conf to install from (default /etc/pacman.conf; build.sh passes the one
#                   with the delayos-local repository, where linux-delayos comes from)
#   RE_WORK         work directory (default /var/tmp/delayos-build/recovery)
#   DELAYOS_RE_REBUILD=1   rebuild even when nothing changed
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
IMG="${1:?usage: build-recovery.sh <image-dir>}"
RE_KERNEL="${RE_KERNEL:-linux-delayos}"
RE_PACMAN_CONF="${RE_PACMAN_CONF:-/etc/pacman.conf}"
WORK="${RE_WORK:-/var/tmp/delayos-build/recovery}"
P="$WORK/profile"
TOOLS=(delay-deploy delay-snapshot delay-recovery-ctl)

log()  { printf '\e[1;36m==>\e[0m %s\n' "$*"; }
die()  { printf '\e[1;31m==> ERROR:\e[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root"
command -v mkarchiso >/dev/null || die "archiso is not installed"
for t in "${TOOLS[@]}"; do [[ -f $REPO/profile/airootfs/usr/local/bin/$t ]] || die "missing profile/airootfs/usr/local/bin/$t"; done

# Nothing changed since the last build (same sources, same kernel package)? Keep the image.
kver="$(pacman --config "$RE_PACMAN_CONF" -Sp --print-format '%n-%v' "$RE_KERNEL" 2>/dev/null | tail -n1 || true)"
stamp="$( { find "$HERE" -type f -print0 | sort -z | xargs -0 sha256sum
            for t in "${TOOLS[@]}"; do sha256sum "$REPO/profile/airootfs/usr/local/bin/$t"; done
            echo "$RE_KERNEL $kver"; } | sed 's/\r$//' | sha256sum | cut -d' ' -f1)"
if [[ ${DELAYOS_RE_REBUILD:-0} != 1 && -f $IMG/delayos-re/.stamp && $(<"$IMG/delayos-re/.stamp") == "$stamp" \
      && -s $IMG/delayos-re/x86_64/airootfs.sfs ]]; then
  log "Recovery environment is up to date ($(<"$IMG/delayos-re/version"))"
  exit 0
fi

# An interrupted pacstrap leaves /proc, /sys (with efivarfs), /dev and /run of THIS machine mounted
# inside the work directory. Deleting through them would wipe device nodes and firmware boot
# entries of the build host: unmount first, never cross file systems, stop if anything is left.
safe_rm() {
  local d m
  for d in "$@"; do
    [[ -e $d ]] || continue
    while read -r m; do
      [[ -n $m ]] && { umount -R "$m" 2>/dev/null || umount -R -l "$m" 2>/dev/null || true; }
    done < <(findmnt -rno TARGET | awk -v p="$d" 'index($0, p "/") == 1' | sort -r)
    if findmnt -rno TARGET | awk -v p="$d" 'index($0, p "/") == 1 { f = 1 } END { exit !f }'; then
      die "$d still has mounted file systems inside (see: findmnt -R). Unmount them or reboot, then run again."
    fi
    rm -rf --one-file-system "$d"
  done
}

log "Assembling the recovery profile (kernel: $RE_KERNEL)"
safe_rm "$P" "$WORK/work" "$WORK/out"
mkdir -p "$P" "$IMG"
cp -a "$HERE/profile/." "$P/"
cp "$RE_PACMAN_CONF" "$P/pacman.conf"
for t in "${TOOLS[@]}"; do install -Dm755 "$REPO/profile/airootfs/usr/local/bin/$t" "$P/airootfs/usr/local/bin/$t"; done
# a checkout on Windows may carry CRLF
find "$P" -type f ! -name '*.sfs' -exec sed -i 's/\r$//' {} +
if [[ $RE_KERNEL != linux-delayos ]]; then
  sed -i "s/^linux-delayos\$/$RE_KERNEL/" "$P/packages.x86_64"
  sed "s/linux-delayos/$RE_KERNEL/g" "$P/airootfs/etc/mkinitcpio.d/linux-delayos.preset" > "$P/airootfs/etc/mkinitcpio.d/$RE_KERNEL.preset"
  rm -f "$P/airootfs/etc/mkinitcpio.d/linux-delayos.preset"
fi
# unit links (not kept in git: a Windows checkout has no symlinks)
S="$P/airootfs/etc/systemd/system"
mkdir -p "$S/multi-user.target.wants"
ln -sf /etc/systemd/system/delay-recovery.service "$S/multi-user.target.wants/delay-recovery.service"
ln -sf /dev/null "$S/getty@tty1.service"
# Korean time on the log lines and in the snapshot list (the hardware clock is UTC, as in DelayOS)
ln -sf /usr/share/zoneinfo/Asia/Seoul "$P/airootfs/etc/localtime"
for u in systemd-networkd.service systemd-networkd.socket systemd-resolved.service systemd-timesyncd.service \
         systemd-networkd-wait-online.service systemd-firstboot.service man-db.timer shadow.timer archlinux-keyring-wkd-sync.timer; do
  ln -sf /dev/null "$S/$u"
done

log "Building the recovery image (mkarchiso, netboot mode)"
mkarchiso -v -m netboot -w "$WORK/work" -o "$WORK/out" "$P"

src="$WORK/out/delayosre"
k="$(ls "$src"/boot/x86_64/vmlinuz-* | head -n1)"
i="$(ls "$src"/boot/x86_64/initramfs-*.img | head -n1)"
[[ -f $k && -f $i && -f $src/x86_64/airootfs.sfs ]] || die "mkarchiso did not produce kernel, initramfs and airootfs.sfs"
rm -rf "$IMG/delayos-re"
install -d "$IMG/delayos-re/boot/x86_64" "$IMG/delayos-re/x86_64"
install -m644 "$k" "$i" "$IMG/delayos-re/boot/x86_64/"
install -m644 "$src/x86_64/airootfs.sfs" "$IMG/delayos-re/x86_64/airootfs.sfs"
[[ -f $src/pkglist.x86_64.txt ]] && install -m644 "$src/pkglist.x86_64.txt" "$IMG/delayos-re/pkglist.txt"
kv="$(grep -m1 "^$RE_KERNEL " "$src/pkglist.x86_64.txt" 2>/dev/null | cut -d' ' -f2 || true)"
printf '%s (%s %s)\n' "$(date +%Y.%m.%d)" "$RE_KERNEL" "${kv:-?}" > "$IMG/delayos-re/version"
printf '%s\n' "$stamp" > "$IMG/delayos-re/.stamp"
safe_rm "$WORK/work" "$WORK/out"
log "Recovery environment: $(du -sh "$IMG/delayos-re" | cut -f1) in $IMG/delayos-re ($(<"$IMG/delayos-re/version"))"
