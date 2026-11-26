#!/usr/bin/env bash
# DelayOS ISO builder. Run as root on Arch Linux (real install, VM or WSL2).
#   sudo ./build.sh            -> out/delayos-YYYY.MM.DD-x86_64.iso
#   sudo ./build.sh --clean    -> wipe work dir first
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${WORK:-/var/tmp/delayos-build}"
OUT="${OUT:-$HERE/out}"
PROFILE="$WORK/profile"
LOCALREPO="$WORK/localrepo"
BUILDER=delaybuilder

log()  { printf '\e[1;36m==>\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m==> WARNING:\e[0m %s\n' "$*"; }
die()  { printf '\e[1;31m==> ERROR:\e[0m %s\n' "$*"; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root: sudo $0"
[[ -f /etc/arch-release ]] || die "This must run on Arch Linux (or Arch in WSL2/VM)."
if [[ ${1:-} == --clean ]]; then
  log "Cleaning $WORK"
  # An interrupted mkarchiso/pacstrap leaves /proc, /sys (efivarfs!), /dev and /run of this machine
  # mounted inside the work directory; rm -rf through them wipes device nodes and UEFI boot entries.
  findmnt -rno TARGET | awk -v p="$WORK/" 'index($0, p) == 1' | sort -r | while read -r m; do umount -R "$m" 2>/dev/null || umount -R -l "$m" || true; done
  findmnt -rno TARGET | awk -v p="$WORK/" 'index($0, p) == 1 { f = 1 } END { exit !f }' \
    && die "$WORK still has mounted file systems inside (findmnt -R). Unmount them or reboot, then run again."
  rm -rf --one-file-system "$WORK"
fi

# ---------------------------------------------------------------- host setup
log "Preparing build host"
grep -q '^\[multilib\]' /etc/pacman.conf || printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf
pacman -Syu --noconfirm --needed archiso git base-devel sudo
mkdir -p "$WORK" "$OUT" "$LOCALREPO"
# Build AUR packages with the same CachyOS-style flags the ISO ships for users
install -Dm644 "$HERE/profile/airootfs/etc/makepkg.conf.d/delayos.conf" /etc/makepkg.conf.d/delayos.conf

# --------------------------------------------------------- AUR -> local repo
id "$BUILDER" >/dev/null 2>&1 || useradd -m "$BUILDER"
echo "$BUILDER ALL=(ALL) NOPASSWD: /usr/bin/pacman" > /etc/sudoers.d/90-delaybuilder
chmod 440 /etc/sudoers.d/90-delaybuilder

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
    warn "$line failed to build - skipping (optional)"
  else
    die "Required AUR package $line failed to build"
  fi
done < "$HERE/aur-packages.txt"

# ------------------------------------------- DelayOS kernel (CachyOS-based)
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

KDIR="/home/$BUILDER/linux-delayos"
if ! ls "$KDIR"/linux-delayos-[0-9]*.pkg.tar.zst >/dev/null 2>&1; then
  log "Building linux-delayos kernel (CachyOS sources, BORE, ThinLTO, -O3) - this takes a while"
  pacman -S --noconfirm --needed clang llvm lld rust rust-bindgen rust-src bc cpio xmlto   # pahole: CachyOS build above
  if [[ -f "$KDIR/src/version" || -f $(ls -d "$KDIR"/src/cachyos-*/version 2>/dev/null | head -1) ]] \
     && ls -d "$KDIR"/src/cachyos-*/.config >/dev/null 2>&1; then
    # An earlier run already extracted + configured the tree: continue the compile where it stopped
    log "Resuming the interrupted linux-delayos compile"
    KFLAGS="-e"
  else
    rm -rf "$KDIR"; KFLAGS=""
  fi
  mkdir -p "$KDIR"; cp "$HERE/kernel/linux-delayos/"{PKGBUILD,config} "$KDIR/"
  sed -i 's/\r$//' "$KDIR/PKGBUILD"
  chown -R "$BUILDER:$BUILDER" "$KDIR"
  as_builder "cd ~/linux-delayos && MAKEFLAGS=-j$(nproc) makepkg -s $KFLAGS --noconfirm --skippgpcheck" \
    || die "linux-delayos kernel failed to build"
fi
cp -u "$KDIR"/linux-delayos-*.pkg.tar.zst "$LOCALREPO/"

# ------------------- linux-delayos-v3: the same kernel built for x86-64-v3 (optional)
# Opt-in with DELAYOS_KERNEL_V3=1: a second full kernel compile (about as long as the first).
# It is the same PKGBUILD with two values changed, so the two can never drift apart. The packages
# ride along on the ISO in /var/cache/delayos/kernel-v3; `delay-cpu-opt kernel install` installs
# them on CPUs with x86-64-v3 when the CachyOS repositories (linux-cachyos) are not in use.
# linux-delayos (generic x86-64) always stays installed as the GRUB fallback.
V3_FILES=()
if [[ ${DELAYOS_KERNEL_V3:-0} == 1 ]]; then
  K3DIR="/home/$BUILDER/linux-delayos-v3"
  if ! ls "$K3DIR"/linux-delayos-v3-[0-9]*.pkg.tar.zst >/dev/null 2>&1; then
    log "Building linux-delayos-v3 kernel (x86-64-v3) - this takes a while"
    rm -rf "$K3DIR"; mkdir -p "$K3DIR"; cp "$HERE/kernel/linux-delayos/"{PKGBUILD,config} "$K3DIR/"
    sed -i -e 's/\r$//' -e 's/^_pkgsuffix=delayos$/_pkgsuffix=delayos-v3/' \
           -e 's/^: "${_processor_opt:=generic_v1}"/: "${_processor_opt:=generic_v3}"/' "$K3DIR/PKGBUILD"
    grep -q '^_pkgsuffix=delayos-v3$' "$K3DIR/PKGBUILD" && grep -q '_processor_opt:=generic_v3' "$K3DIR/PKGBUILD" \
      || die "linux-delayos-v3: could not derive the PKGBUILD from kernel/linux-delayos/PKGBUILD"
    chown -R "$BUILDER:$BUILDER" "$K3DIR"
    as_builder "cd ~/linux-delayos-v3 && MAKEFLAGS=-j$(nproc) makepkg -s --noconfirm --skippgpcheck" \
      || die "linux-delayos-v3 kernel failed to build"
  fi
  V3_FILES=("$K3DIR"/linux-delayos-v3-*.pkg.tar.zst)
fi

# ------------------- EAC Linux v2: DelayOS-signed boot loaders + linux-delayos-eac (optional)
# Needs the DelayOS Secure Boot keys (tools/make-delayos-sb-key.sh). Skipped without them.
KEYS="${DELAYOS_KEYS:-/root/delayos-keys}"
EAC_FILES=()
if [[ -f $KEYS/delayos-sb-signing.key && -f $KEYS/delayos-sb-signing.crt && -f $KEYS/delayos-sb-ca.crt ]]; then
  BKEYS="/home/$BUILDER/.delayos-keys"
  EDIR="/home/$BUILDER/linux-delayos-eac"
  SDIR="/home/$BUILDER/delayos-sb-signed"
  # the builder user cannot read /root: give it a private copy, always removed again
  cleanup_keys() { rm -rf "$BKEYS"; rm -f "$EDIR/src/delayos-module-signing.pem"; }
  trap cleanup_keys EXIT
  install -d -m700 -o "$BUILDER" -g "$BUILDER" "$BKEYS"
  install -m600 -o "$BUILDER" -g "$BUILDER" "$KEYS"/delayos-sb-signing.{key,crt} "$KEYS"/delayos-sb-ca.crt "$BKEYS/"
  SBENV="DELAYOS_SB_KEY=$BKEYS/delayos-sb-signing.key DELAYOS_SB_CERT=$BKEYS/delayos-sb-signing.crt DELAYOS_SB_CA=$BKEYS/delayos-sb-ca.crt"
  pacman -S --noconfirm --needed sbsigntools grub systemd openssl

  log "Building delayos-sb-signed (DelayOS-signed GRUB + systemd-boot)"
  rm -rf "$SDIR"; cp -r "$HERE/packages/delayos-sb-signed" "$SDIR"
  sed -i 's/\r$//' "$SDIR/PKGBUILD"; chown -R "$BUILDER:$BUILDER" "$SDIR"
  as_builder "cd ~/delayos-sb-signed && $SBENV makepkg -f --noconfirm" || die "delayos-sb-signed failed to build"
  cp -u "$SDIR"/delayos-sb-signed-*.pkg.tar.zst "$LOCALREPO/"

  NVV=$(pacman -Si nvidia-utils | sed -n 's/^Version *: *//p' | head -n1)
  if ls "$EDIR"/linux-delayos-eac-[0-9]*.pkg.tar.zst >/dev/null 2>&1 && \
     ! bsdtar -xOf "$(ls "$EDIR"/linux-delayos-eac-nvidia-open-*.pkg.tar.zst 2>/dev/null | head -1)" .PKGINFO 2>/dev/null | grep -q "nvidia-utils=${NVV%-*}"; then
    log "nvidia-utils changed to $NVV: rebuilding linux-delayos-eac"
    rm -rf "$EDIR"
  fi
  if ! ls "$EDIR"/linux-delayos-eac-[0-9]*.pkg.tar.zst >/dev/null 2>&1; then
    log "Building linux-delayos-eac (anti-cheat kernel, NVIDIA $NVV) - this takes a while"
    rm -rf "$EDIR"; mkdir -p "$EDIR"; cp "$HERE/kernel/linux-delayos-eac/"{PKGBUILD,config} "$EDIR/"
    sed -i 's/\r$//' "$EDIR/PKGBUILD"; chown -R "$BUILDER:$BUILDER" "$EDIR"
    as_builder "cd ~/linux-delayos-eac && $SBENV MAKEFLAGS=-j$(nproc) makepkg -s --noconfirm --skippgpcheck" \
      || die "linux-delayos-eac kernel failed to build"
  fi
  cleanup_keys
  for p in "$EDIR"/linux-delayos-eac-*.pkg.tar.zst; do
    case "$p" in *-headers-*) continue ;; esac
    EAC_FILES+=("$p")
  done
else
  warn "No Secure Boot keys in $KEYS: skipping linux-delayos-eac / delayos-sb-signed (anti-cheat mode unavailable)"
fi

# ------------------- Secure Boot for the normal DelayOS (hidden Windows / Vanguard, optional)
# docs/windows-switch.md: GRUB + linux-delayos signed with the DelayOS GENERAL key
# (tools/make-delayos-general-key.sh), never with the anti-cheat key above. Skipped without the keys:
# the installer then says "Secure Boot 미지원 빌드".
SBG_BUILT=0
if [[ -f $KEYS/delayos-general-signing.key && -f $KEYS/delayos-general-signing.crt && -f $KEYS/delayos-general-ca.crt ]]; then
  GKEYS="/home/$BUILDER/.delayos-general-keys"
  GDIR="/home/$BUILDER/delayos-sb-general"
  cleanup_gkeys() { rm -rf "$GKEYS"; }
  trap 'cleanup_gkeys; declare -F cleanup_keys >/dev/null && cleanup_keys' EXIT
  install -d -m700 -o "$BUILDER" -g "$BUILDER" "$GKEYS"
  install -m600 -o "$BUILDER" -g "$BUILDER" "$KEYS"/delayos-general-signing.{key,crt} "$KEYS"/delayos-general-ca.crt "$GKEYS/"
  KPKG=$(ls "$KDIR"/linux-delayos-[0-9]*.pkg.tar.zst | head -n1)
  pacman -S --noconfirm --needed sbsigntools grub openssl
  log "Building delayos-sb-general (GRUB + $(basename "$KPKG") signed with the DelayOS general key)"
  rm -rf "$GDIR"; cp -r "$HERE/packages/delayos-sb-general" "$GDIR"
  sed -i 's/\r$//' "$GDIR/PKGBUILD"; chown -R "$BUILDER:$BUILDER" "$GDIR"
  as_builder "cd ~/delayos-sb-general && DELAYOS_SBG_KEY=$GKEYS/delayos-general-signing.key DELAYOS_SBG_CERT=$GKEYS/delayos-general-signing.crt DELAYOS_SBG_CA=$GKEYS/delayos-general-ca.crt DELAYOS_KERNEL_PKG=$KPKG makepkg -f --noconfirm" \
    || die "delayos-sb-general failed to build"
  cleanup_gkeys
  rm -f "$LOCALREPO"/delayos-sb-general-*.pkg.tar.zst
  cp "$GDIR"/delayos-sb-general-*.pkg.tar.zst "$LOCALREPO/"
  SBG_BUILT=1
else
  warn "No general Secure Boot keys in $KEYS (delayos-general-*): DelayOS will not boot with Secure Boot on (Vanguard on the hidden Windows needs it)"
fi

# ------------------- DelayOS's own system as packages (docs/packaging.md)
# delayos-settings-base, -branding, -shell, -apps, -winboot take their files out of profile/airootfs
# (packages/delayos-*/files.list). The ISO installs them like any other package, so an installed
# system owns these files through pacman and receives updates from the [delayos] repository.
# The same script builds them for the repository (tools/repo-build.sh content).
log "Building the DelayOS content packages (delayos-shell, delayos-apps, ...)"
CPOOL="$WORK/repo/pool/delayos"
DELAYOS_REPO_STATE="$WORK/repo" bash "$HERE/tools/repo-build.sh" --no-chroot content \
  || die "The DelayOS content packages failed to build"
CONTENT_NAMES=(delayos-settings-base delayos-branding delayos-shell delayos-apps delayos-winboot delayos-mirrorlist)
HAVE_KEYRING=0
if ls "$CPOOL"/delayos-keyring-[0-9]*.pkg.tar.zst >/dev/null 2>&1; then
  HAVE_KEYRING=1; CONTENT_NAMES+=(delayos-keyring delayos-desktop)
else
  warn "No DelayOS repository key (tools/make-delayos-repo-key.sh): the ISO is built without delayos-keyring,"
  warn "installed systems will NOT use the [delayos] repository and will not receive DelayOS updates."
fi
CONTENT_FILES=()
for n in "${CONTENT_NAMES[@]}"; do
  rm -f "$LOCALREPO/$n"-[0-9]*.pkg.tar.zst
  f=$(ls "$CPOOL/$n"-[0-9]*.pkg.tar.zst 2>/dev/null | head -n1)
  [[ -f $f ]] || die "$n was not built"
  cp "$f" "$LOCALREPO/"; CONTENT_FILES+=("$f")
done

log "Collecting built packages into $LOCALREPO"
find "/home/$BUILDER/.cache/yay" "/home/$BUILDER/yay-bin" -name '*.pkg.tar.zst' ! -name '*-debug-*' -exec cp -u {} "$LOCALREPO/" \; 2>/dev/null || true
rm -f "$LOCALREPO"/delayos-local.db* "$LOCALREPO"/delayos-local.files*
repo-add -q "$LOCALREPO/delayos-local.db.tar.gz" "$LOCALREPO"/*.pkg.tar.zst

# ------------------------------------------------------- assemble the profile
log "Assembling profile (Arch releng + DelayOS overlay)"
rm -rf "$PROFILE"
cp -a /usr/share/archiso/configs/releng "$PROFILE"
rm -f "$PROFILE/packages.x86_64" "$PROFILE/airootfs/etc/mkinitcpio.d/linux.preset"
cp -a "$HERE/profile/." "$PROFILE/"
# BIOS boot menu splash: DelayOS instead of Arch
[[ -f $HERE/docs/assets/boot/syslinux-splash.png ]] && cp "$HERE/docs/assets/boot/syslinux-splash.png" "$PROFILE/syslinux/splash.png"

sed -i "s|@LOCALREPO@|$LOCALREPO|" "$PROFILE/pacman.conf"

# What the content packages ship leaves the overlay (pacstrap would stop on a file that exists
# already) together with its file_permissions entry. What stays in airootfs is live-ISO-only:
# installer configuration, live autologin (packages/delayos-live-only.list).
bash "$HERE/tools/content-pkgs.sh" strip "$PROFILE/airootfs" "$PROFILE/profiledef.sh" "${CONTENT_FILES[@]}"
# packages.x86_64 lists the content packages; the keyring and the meta package need the repository key
(( HAVE_KEYRING )) && printf '%s\n' delayos-keyring delayos-desktop >> "$PROFILE/packages.x86_64"

# Anti-cheat kernel packages ride along on the ISO; `delay-eac setup` installs them on demand
if (( ${#EAC_FILES[@]} )); then
  install -d "$PROFILE/airootfs/var/cache/delayos/eac-pkgs"
  cp "${EAC_FILES[@]}" "$LOCALREPO"/delayos-sb-signed-*.pkg.tar.zst "$PROFILE/airootfs/var/cache/delayos/eac-pkgs/"
  echo delayos-sb-signed >> "$PROFILE/packages.x86_64"
fi
# x86-64-v3 build of the kernel (DELAYOS_KERNEL_V3=1): installed on demand by `delay-cpu-opt kernel install`
if (( ${#V3_FILES[@]} )); then
  install -d "$PROFILE/airootfs/var/cache/delayos/kernel-v3"
  cp "${V3_FILES[@]}" "$PROFILE/airootfs/var/cache/delayos/kernel-v3/"
fi
# Signed GRUB + kernel image for Secure Boot next to the hidden Windows (delay-winsetup)
(( SBG_BUILT )) && echo delayos-sb-general >> "$PROFILE/packages.x86_64"

# Recovery environment "DelayOS 복구" (docs/recovery.md): a second, small archiso system (kernel +
# initramfs + squashfs, about 400 MB) built in netboot mode from recovery/profile with the same
# linux-delayos package. It rides in the image under /usr/share/delayos/recovery/image; the
# installer copies it to the hidden recovery partition. Rebuilt only when recovery/, the three
# tools it carries or the kernel package changed (a few minutes). DELAYOS_RECOVERY=0 skips it.
if [[ ${DELAYOS_RECOVERY:-1} == 1 ]]; then
  log "Building the recovery environment (DelayOS 복구)"
  sed "s|@LOCALREPO@|$LOCALREPO|" "$HERE/profile/pacman.conf" > "$WORK/recovery-pacman.conf"
  if RE_WORK="$WORK/recovery" RE_PACMAN_CONF="$WORK/recovery-pacman.conf" \
     bash "$HERE/recovery/build-recovery.sh" "$WORK/recovery/image"; then
    install -d "$PROFILE/airootfs/usr/share/delayos/recovery"
    cp -a "$WORK/recovery/image" "$PROFILE/airootfs/usr/share/delayos/recovery/image"
    rm -f "$PROFILE/airootfs/usr/share/delayos/recovery/image/delayos-re/.stamp"
  else
    warn "The recovery environment failed to build: this ISO installs DelayOS without the recovery partition"
  fi
fi

# Boot splash: plymouth hook in the live initramfs, theme selected inside the image
sed -i 's/\(HOOKS=([^)]*\bkms\b\)/\1 plymouth/' "$PROFILE/airootfs/etc/mkinitcpio.conf.d/archiso.conf"
grep -q plymouth "$PROFILE/airootfs/etc/mkinitcpio.conf.d/archiso.conf" || \
  sed -i 's/\(HOOKS=(base udev\)/\1 plymouth/' "$PROFILE/airootfs/etc/mkinitcpio.conf.d/archiso.conf"
# Live initramfs: zstd instead of xz (a little bigger, several times faster to unpack on old CPUs)
sed -i -e 's/^COMPRESSION=.*/COMPRESSION="zstd"/' -e 's/^COMPRESSION_OPTIONS=.*/COMPRESSION_OPTIONS=(-19 -T0)/' \
  "$PROFILE/airootfs/etc/mkinitcpio.conf.d/archiso.conf"

# DelayOS apps: ship Python bytecode, so no app compiles its sources at start (/usr is not writable
# for users, they could never cache it themselves). checked-hash stays valid whatever happens to
# file times in the image; a Python upgrade re-runs this through 70-delay-pycache.hook.
# The content packages ship their own bytecode (tools/content-pkgs.sh install); this covers
# anything under /usr/share/delayos that is still in the overlay.
if [[ -d $PROFILE/airootfs/usr/share/delayos ]]; then
  log "Precompiling DelayOS app bytecode"
  python3 -m compileall -q -s "$PROFILE/airootfs" -p / --invalidation-mode checked-hash \
    "$PROFILE/airootfs/usr/share/delayos" || warn "bytecode precompile failed - apps will compile at start"
fi

# ananicy-cpp needs a rule set: use CachyOS's (same as CachyOS ships)
log "Adding CachyOS ananicy-cpp rules"
rm -rf "$WORK/ananicy-rules"
git clone -q --depth 1 https://github.com/CachyOS/ananicy-rules.git "$WORK/ananicy-rules"
mkdir -p "$PROFILE/airootfs/etc/ananicy.d"
cp -r "$WORK/ananicy-rules/." "$PROFILE/airootfs/etc/ananicy.d/"
rm -rf "$PROFILE/airootfs/etc/ananicy.d/.git" "$PROFILE/airootfs/etc/ananicy.d/.github"
printf '%s\n' "${BUILT[@]}" >> "$PROFILE/packages.x86_64"

# Boot entries: releng boots "linux"; we boot linux-delayos (+ an LTS fallback entry)
log "Patching boot loaders for linux-delayos"
for f in $(grep -rl 'vmlinuz-linux\b\|initramfs-linux\.img' "$PROFILE/efiboot" "$PROFILE/syslinux" "$PROFILE/grub" 2>/dev/null); do
  sed -i -e 's/vmlinuz-linux\b/vmlinuz-linux-delayos/g' \
         -e 's/initramfs-linux\.img/initramfs-linux-delayos.img/g' \
         -e 's/Arch Linux/DelayOS/g' "$f"
done
# Live kernel options: quiet, fast, no mitigations-induced FPS loss on the live USB
# plymouth.use-simpledrm: the live initramfs has no GPU drivers (they load from the squashfs), and
# Plymouth otherwise waits for one before it shows anything: splash on the firmware framebuffer
# at once. show_status=false: no "[ OK ] ..." console lines flashing between splash and desktop.
# The same options go into the GRUB entry of the Secure Boot path (tools/iso-secureboot.sh below).
LIVE_OPTS='quiet splash plymouth.use-simpledrm systemd.show_status=false rd.systemd.show_status=false loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0 nowatchdog split_lock_detect=off module_blacklist=pcspkr i915.modeset=1 amdgpu.modeset=1 nvme_load=yes copytoram=auto cow_spacesize=10G'
for f in $(grep -rl 'archisobasedir' "$PROFILE/efiboot" "$PROFILE/syslinux" "$PROFILE/grub"); do
  sed -i "s/archisosearchuuid=%ARCHISO_UUID%/& $LIVE_OPTS/" "$f"
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
ln -sf /etc/systemd/system/delay-firstboot.service "$W/multi-user.target.wants/delay-firstboot.service"
ln -sf /usr/lib/systemd/system/fstrim.timer "$W/timers.target.wants/fstrim.timer"
for s in NetworkManager-dispatcher rtkit-daemon scx_loader; do
  ln -sf "/usr/lib/systemd/system/$s.service" "$W/multi-user.target.wants/$s.service"
done
ln -sf /usr/lib/systemd/system/NetworkManager-dispatcher.service "$W/dbus-org.freedesktop.nm-dispatcher.service"
ln -sf /etc/systemd/system/delay-eac-facts.service "$W/multi-user.target.wants/delay-eac-facts.service"
ln -sf /usr/lib/systemd/system/bluetooth.service "$W/dbus-org.bluez.service"
# VM guest tools (each unit has its own ConditionVirtualization, so they idle on real hardware).
# qemu-guest-agent and spice-vdagentd are NOT enabled here: they have no such condition and
# qemu-guest-agent waits 90 s for /dev/virtio-ports/org.qemu.guest_agent.0 on every machine
# that is not a QEMU guest. Their own udev rules start them when the virtio port exists.
for s in vmtoolsd vmware-vmblock-fuse vboxservice; do
  ln -sf "/usr/lib/systemd/system/$s.service" "$W/multi-user.target.wants/$s.service"
done
# pacman already runs ldconfig after every transaction; ldconfig.service only repeats it
# (ConditionNeedsUpdate is always true on the live overlay) and cost 7.5 s of every live boot
ln -sf /dev/null "$W/ldconfig.service"
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

ISO=$(ls -t "$OUT"/delayos-*.iso | head -1)

# ------------------------------------------- Secure Boot for the live/install medium itself
# docs/secure-boot.md. mkarchiso wrote an ISO that starts through the unsigned systemd-boot (UEFI
# with Secure Boot off) and syslinux (BIOS). With the general keys, its EFI boot path becomes
#   shim (Microsoft-signed, shim-signed) -> GRUB -> linux-delayos, both signed with the DelayOS
#   general key (the files of delayos-sb-general built above: no private key is used here),
# so the same medium starts with Secure Boot on or off; BIOS boot stays as it is. Only the public
# CA certificate (delayos-general-ca.cer) goes onto the medium, for MokManager's "Enroll key from disk".
ISO_SB=0
if (( SBG_BUILT )); then
  SHIM_PKG=$(ls -t "$LOCALREPO"/shim-signed*.pkg.tar.zst 2>/dev/null | head -n1)
  SBG_PKG=$(ls -t "$LOCALREPO"/delayos-sb-general-*.pkg.tar.zst | head -n1)
  if [[ -f $SHIM_PKG ]]; then
    log "Making the ISO start with Secure Boot on (shim + DelayOS general key)"
    if ! bash "$HERE/tools/iso-secureboot.sh" --iso "$ISO" --out "$ISO.sb" --sb-pkg "$SBG_PKG" --shim-pkg "$SHIM_PKG" --opts "$LIVE_OPTS" --work "$WORK/iso-secureboot"; then
      rm -f "$ISO.sb"
      die "The Secure Boot boot path could not be put on the ISO. $ISO is left as mkarchiso wrote it: it starts with Secure Boot off only."
    fi
    mv -f "$ISO.sb" "$ISO"
    rm -rf "$WORK/iso-secureboot"
    ISO_SB=1
  else
    warn "shim-signed was not built (aur-packages.txt): the ISO starts with Secure Boot OFF only"
  fi
else
  warn "No general Secure Boot keys: the ISO is not signed and starts with Secure Boot OFF only (docs/secure-boot.md)"
fi

( cd "$OUT" && sha256sum "$(basename "$ISO")" > "$(basename "$ISO").sha256" )
log "Done: $ISO"
(( ISO_SB )) && log "Secure Boot: the ISO starts with Secure Boot on. First start on a PC: MokManager > Enroll key from disk > delayos-general-ca.cer"
log "Write it to a USB stick with Rufus/Ventoy (Windows) or: dd if=$ISO of=/dev/sdX bs=4M status=progress oflag=sync"
