#!/usr/bin/env bash
# TEMUOS_LINUX ISO builder. Run as root on Arch Linux (real install, VM or WSL2).
#   sudo ./build.sh            -> out/temuos-YYYY.MM.DD-x86_64.iso
#   sudo ./build.sh --clean    -> wipe work dir first
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${WORK:-/var/tmp/temuos-build}"
OUT="${OUT:-$HERE/out}"
PROFILE="$WORK/profile"
LOCALREPO="$WORK/localrepo"
BUILDER=temubuilder

log()  { printf '\e[1;36m==>\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m==> WARNING:\e[0m %s\n' "$*"; }
die()  { printf '\e[1;31m==> ERROR:\e[0m %s\n' "$*"; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root: sudo $0"
[[ -f /etc/arch-release ]] || die "This must run on Arch Linux (or Arch in WSL2/VM)."
[[ ${1:-} == --clean ]] && { log "Cleaning $WORK"; rm -rf "$WORK"; }

# ---------------------------------------------------------------- host setup
log "Preparing build host"
grep -q '^\[multilib\]' /etc/pacman.conf || printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf
pacman -Syu --noconfirm --needed archiso git base-devel sudo
mkdir -p "$WORK" "$OUT" "$LOCALREPO"
# Build AUR packages with the same CachyOS-style flags the ISO ships for users
install -Dm644 "$HERE/profile/airootfs/etc/makepkg.conf.d/temuos.conf" /etc/makepkg.conf.d/temuos.conf

# --------------------------------------------------------- AUR -> local repo
id "$BUILDER" >/dev/null 2>&1 || useradd -m "$BUILDER"
echo "$BUILDER ALL=(ALL) NOPASSWD: /usr/bin/pacman" > /etc/sudoers.d/90-temubuilder
chmod 440 /etc/sudoers.d/90-temubuilder

as_builder() { sudo -u "$BUILDER" -H bash -c "$*"; }

if ! command -v yay >/dev/null; then
  log "Building yay (AUR helper)"
  as_builder "rm -rf ~/yay-bin && git clone -q https://aur.archlinux.org/yay-bin.git ~/yay-bin && cd ~/yay-bin && makepkg -si --noconfirm"
fi

BUILT=()
while read -r line; do
  line="${line%%#*}"; line="${line// /}"
  [[ -z $line ]] && continue
  optional=0; [[ $line == \?* ]] && { optional=1; line="${line#\?}"; }
  log "AUR: $line"
  if as_builder "yay -S --noconfirm --needed --answerdiff None --answerclean None --removemake=false $line"; then
    BUILT+=("$line")
  elif (( optional )); then
    warn "$line failed to build ??skipping (optional)"
  else
    die "Required AUR package $line failed to build"
  fi
done < "$HERE/aur-packages.txt"

# ------------------------------------------- TEMUOS_LINUX kernel (CachyOS-based)
# CachyOS pahole 1:1.32-2 (BTF fix for Rust modules in Clang-LTO kernels) - the kernel needs it
PDIR="/home/$BUILDER/pahole"
if ! ls "$PDIR"/pahole-1:*.pkg.tar.zst >/dev/null 2>&1; then
  log "Building pahole (CachyOS patched)"
  pacman -S --noconfirm --needed cmake git ninja python python-matplotlib
  rm -rf "$PDIR"; cp -r "$HERE/packages/pahole" "$PDIR"
  sed -i 's/\r$//' "$PDIR/PKGBUILD"
  chown -R "$BUILDER:$BUILDER" "$PDIR"
  as_builder "cd ~/pahole && makepkg --noconfirm --skippgpcheck --nocheck" || die "pahole failed to build"
fi
pacman -U --noconfirm --needed "$PDIR"/pahole-1:*.pkg.tar.zst
cp -u "$PDIR"/pahole-1:*.pkg.tar.zst "$LOCALREPO/"

KDIR="/home/$BUILDER/linux-temuos"
if ! ls "$KDIR"/linux-temuos-[0-9]*.pkg.tar.zst >/dev/null 2>&1; then
  log "Building linux-temuos kernel (CachyOS sources, BORE, ThinLTO, -O3) - this takes a while"
  pacman -S --noconfirm --needed clang llvm lld rust rust-bindgen rust-src bc cpio xmlto   # pahole: CachyOS build above
  if [[ -f "$KDIR/src/version" || -f $(ls -d "$KDIR"/src/cachyos-*/version 2>/dev/null | head -1) ]] \
     && ls -d "$KDIR"/src/cachyos-*/.config >/dev/null 2>&1; then
    # An earlier run already extracted + configured the tree: continue the compile where it stopped
    log "Resuming the interrupted linux-temuos compile"
    KFLAGS="-e"
  else
    rm -rf "$KDIR"; KFLAGS=""
  fi
  mkdir -p "$KDIR"; cp "$HERE/kernel/linux-temuos/"{PKGBUILD,config} "$KDIR/"
  sed -i 's/\r$//' "$KDIR/PKGBUILD"
  chown -R "$BUILDER:$BUILDER" "$KDIR"
  as_builder "cd ~/linux-temuos && MAKEFLAGS=-j$(nproc) makepkg -s $KFLAGS --noconfirm --skippgpcheck" \
    || die "linux-temuos kernel failed to build"
fi
cp -u "$KDIR"/linux-temuos-*.pkg.tar.zst "$LOCALREPO/"

log "Collecting built packages into $LOCALREPO"
find "/home/$BUILDER/.cache/yay" "/home/$BUILDER/yay-bin" -name '*.pkg.tar.zst' ! -name '*-debug-*' -exec cp -u {} "$LOCALREPO/" \; 2>/dev/null || true
rm -f "$LOCALREPO"/temuos-local.db* "$LOCALREPO"/temuos-local.files*
repo-add -q "$LOCALREPO/temuos-local.db.tar.gz" "$LOCALREPO"/*.pkg.tar.zst

# ------------------------------------------------------- assemble the profile
log "Assembling profile (Arch releng + TEMUOS_LINUX overlay)"
rm -rf "$PROFILE"
cp -a /usr/share/archiso/configs/releng "$PROFILE"
rm -f "$PROFILE/packages.x86_64" "$PROFILE/airootfs/etc/mkinitcpio.d/linux.preset"
cp -a "$HERE/profile/." "$PROFILE/"

sed -i "s|@LOCALREPO@|$LOCALREPO|" "$PROFILE/pacman.conf"

# ananicy-cpp needs a rule set: use CachyOS's (same as CachyOS ships)
log "Adding CachyOS ananicy-cpp rules"
rm -rf "$WORK/ananicy-rules"
git clone -q --depth 1 https://github.com/CachyOS/ananicy-rules.git "$WORK/ananicy-rules"
mkdir -p "$PROFILE/airootfs/etc/ananicy.d"
cp -r "$WORK/ananicy-rules/." "$PROFILE/airootfs/etc/ananicy.d/"
rm -rf "$PROFILE/airootfs/etc/ananicy.d/.git" "$PROFILE/airootfs/etc/ananicy.d/.github"
printf '%s\n' "${BUILT[@]}" >> "$PROFILE/packages.x86_64"

# Boot entries: releng boots "linux"; we boot linux-temuos (+ an LTS fallback entry)
log "Patching boot loaders for linux-temuos"
for f in $(grep -rl 'vmlinuz-linux\b\|initramfs-linux\.img' "$PROFILE/efiboot" "$PROFILE/syslinux" "$PROFILE/grub" 2>/dev/null); do
  sed -i -e 's/vmlinuz-linux\b/vmlinuz-linux-temuos/g' \
         -e 's/initramfs-linux\.img/initramfs-linux-temuos.img/g' \
         -e 's/Arch Linux/TEMUOS_LINUX/g' "$f"
done
# Live kernel options: quiet, fast, no mitigations-induced FPS loss on the live USB
for f in $(grep -rl 'archisobasedir' "$PROFILE/efiboot" "$PROFILE/syslinux" "$PROFILE/grub"); do
  sed -i 's/\(archisosearchuuid=%ARCHISO_UUID%\)/\1 quiet splash loglevel=3 nowatchdog split_lock_detect=off module_blacklist=pcspkr i915.modeset=1 amdgpu.modeset=1 nvme_load=yes copytoram=auto cow_spacesize=10G/' "$f"
done

# Services (releng uses systemd-networkd/iwd; we use NetworkManager + SDDM)
W="$PROFILE/airootfs/etc/systemd/system"
rm -f "$W/multi-user.target.wants/"{systemd-networkd,systemd-resolved,iwd}.service \
      "$W/sockets.target.wants/systemd-networkd.socket" \
      "$W/network-online.target.wants/systemd-networkd-wait-online.service" \
      "$W/systemd-networkd-wait-online.service.wants/"* 2>/dev/null || true
rm -rf "$W/getty@tty1.service.d" "$PROFILE/airootfs/etc/systemd/network" 2>/dev/null || true
mkdir -p "$W/multi-user.target.wants" "$W/bluetooth.target.wants" "$W/timers.target.wants"
ln -sf /usr/lib/systemd/system/sddm.service            "$W/display-manager.service"
for s in NetworkManager bluetooth power-profiles-daemon ananicy-cpp irqbalance; do
  ln -sf "/usr/lib/systemd/system/$s.service" "$W/multi-user.target.wants/$s.service"
done
ln -sf /etc/systemd/system/temu-firstboot.service "$W/multi-user.target.wants/temu-firstboot.service"
ln -sf /usr/lib/systemd/system/fstrim.timer "$W/timers.target.wants/fstrim.timer"
for s in NetworkManager-dispatcher rtkit-daemon scx_loader; do
  ln -sf "/usr/lib/systemd/system/$s.service" "$W/multi-user.target.wants/$s.service"
done
ln -sf /usr/lib/systemd/system/NetworkManager-dispatcher.service "$W/dbus-org.freedesktop.nm-dispatcher.service"
# VM guest tools (each unit has its own ConditionVirtualization, so they idle on real hardware)
for s in vmtoolsd vmware-vmblock-fuse qemu-guest-agent vboxservice spice-vdagentd; do
  ln -sf "/usr/lib/systemd/system/$s.service" "$W/multi-user.target.wants/$s.service"
done
# Boot was stuck 2 minutes in systemd-networkd-wait-online (we use NetworkManager), and
# systemd-loop@ tried to loop-attach the CD drive: mask both, plus networkd itself
for s in systemd-networkd-wait-online.service systemd-networkd.service systemd-networkd.socket \
         systemd-networkd-varlink.socket systemd-networkd-varlink-metrics.socket systemd-networkd-resolve-hook.socket \
         systemd-loop@.service NetworkManager-wait-online.service systemd-time-wait-sync.service; do
  ln -sf /dev/null "$W/$s"
done

# Korean by default: locale, time zone (Asia/Seoul), hardware clock left as UTC
ln -sf /usr/share/zoneinfo/Asia/Seoul "$PROFILE/airootfs/etc/localtime"

# Boot straight into the live system: no boot menu (hold a key / press Esc to see it)
sed -i 's/^timeout .*/timeout 0/' "$PROFILE/efiboot/loader/loader.conf" 2>/dev/null || true
grep -q '^timeout' "$PROFILE/efiboot/loader/loader.conf" || echo 'timeout 0' >> "$PROFILE/efiboot/loader/loader.conf"
for f in "$PROFILE"/syslinux/*.cfg; do
  sed -i -e 's/^TIMEOUT .*/TIMEOUT 1/' -e 's/^PROMPT .*/PROMPT 0/' "$f"
done
for f in "$PROFILE"/grub/*.cfg; do
  sed -i 's/^\(\s*\)set timeout=.*/\1set timeout=0/' "$f" 2>/dev/null || true
done

# Calamares desktop shortcut name
mkdir -p "$PROFILE/airootfs/etc/skel/Desktop"

# ------------------------------------------------------------------- build
log "Building ISO (this takes a while)"
mkarchiso -v -r -w "$WORK/archiso-tmp" -o "$OUT" "$PROFILE"

ISO=$(ls -t "$OUT"/temuos_linux-*.iso | head -1)
( cd "$OUT" && sha256sum "$(basename "$ISO")" > "$(basename "$ISO").sha256" )
log "Done: $ISO"
log "Write it to a USB stick with Rufus/Ventoy (Windows) or: dd if=$ISO of=/dev/sdX bs=4M status=progress oflag=sync"
