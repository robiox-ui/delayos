#!/usr/bin/env bash
# Makes a DelayOS ISO start with UEFI Secure Boot ON (docs/secure-boot.md). Run by build.sh after
# mkarchiso when the DelayOS general Secure Boot keys were there; can also be run by hand on a
# finished ISO. No private key is needed here: everything signed comes out of two packages.
#
#   tools/iso-secureboot.sh --iso IN.iso --out OUT.iso \
#       --sb-pkg delayos-sb-general-*.pkg.tar.zst --shim-pkg shim-signed*.pkg.tar.zst \
#       [--opts "kernel options after archisosearchuuid=..."] [--install-dir arch] [--work DIR]
#
# What changes in the ISO (everything else, including BIOS boot through syslinux, is replayed 1:1):
#   EFI partition image (El Torito UEFI image = partition 2 of a dd-written stick), rebuilt:
#     /EFI/BOOT/BOOTx64.EFI      shimx64.efi of shim-signed (signed by Microsoft)
#     /EFI/BOOT/mmx64.efi        MokManager of shim-signed
#     /EFI/BOOT/grubx64.efi      GRUB of delayos-sb-general (signed with the DelayOS general key, SBAT)
#     /EFI/BOOT/BOOTIA32.EFI     unsigned GRUB for 32-bit UEFI (no Secure Boot there), when grub has i386-efi
#     /EFI/DelayOS/grub.cfg      tools/iso-secureboot/grub.cfg: finds the live volume, boots it, no menu
#     /delayos-general-ca.cer    DelayOS general CA (public) for MokManager's "Enroll key from disk"
#   ISO 9660: the same /EFI tree and /delayos-general-ca.cer (USB sticks made by copying the files,
#     and firmware that hands GRUB the whole DVD), /boot/grub/fonts/unicode.pf2 (Korean menu),
#     /<install dir>/boot/x86_64/vmlinuz-linux-delayos replaced by the signed image of
#     delayos-sb-general (the installer copies it to the new system; BIOS boot ignores the signature),
#     systemd-boot's /loader removed.
# The volume UUID (archisosearchuuid of the BIOS boot entries) and the label stay the same.
set -euo pipefail

log()  { printf '\e[1;36m==>\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m==> WARNING:\e[0m %s\n' "$*" >&2; }
die()  { printf '\e[1;31m==> ERROR:\e[0m %s\n' "$*" >&2; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IN="" OUT="" SBPKG="" SHIMPKG="" OPTS="" INSTALL_DIR=arch ARCH=x86_64 WORK="" FONT=/usr/share/grub/unicode.pf2
while (( $# )); do
  case $1 in
    --iso) IN=$2; shift 2 ;;
    --out) OUT=$2; shift 2 ;;
    --sb-pkg) SBPKG=$2; shift 2 ;;
    --shim-pkg) SHIMPKG=$2; shift 2 ;;
    --opts) OPTS=$2; shift 2 ;;
    --install-dir) INSTALL_DIR=$2; shift 2 ;;
    --work) WORK=$2; shift 2 ;;
    --font) FONT=$2; shift 2 ;;
    -h|--help) sed -n '2,24p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[[ -f $IN ]] || die "--iso: no such file: $IN"
[[ -n $OUT && $OUT != "$IN" ]] || die "--out must be a new file"
[[ -f $SBPKG ]] || die "--sb-pkg: no delayos-sb-general package: $SBPKG"
[[ -f $SHIMPKG ]] || die "--shim-pkg: no shim-signed package: $SHIMPKG"
for t in xorriso bsdtar mkfs.fat mmd mcopy blkid sha256sum; do
  command -v "$t" >/dev/null || die "$t is missing (pacman -S libisoburn libarchive dosfstools mtools util-linux)"
done

OWN_WORK=0
if [[ -z $WORK ]]; then WORK="$(mktemp -d)"; OWN_WORK=1; else rm -rf "$WORK"; mkdir -p "$WORK"; fi
cleanup() { (( OWN_WORK )) && rm -rf "$WORK"; return 0; }
trap cleanup EXIT

# ---------------------------------------------------------------- the signed files
mkdir -p "$WORK/sbg" "$WORK/shim" "$WORK/tree/EFI/BOOT" "$WORK/tree/EFI/DelayOS"
bsdtar -xf "$SBPKG" -C "$WORK/sbg" usr/share/delayos/secureboot/general
bsdtar -xf "$SHIMPKG" -C "$WORK/shim" usr/share/shim-signed
G="$WORK/sbg/usr/share/delayos/secureboot/general"
SH="$WORK/shim/usr/share/shim-signed"
for f in "$G/grubx64.efi" "$G/vmlinuz-linux-delayos.signed" "$G/vmlinuz-linux-delayos.sha256" "$G/delayos-general-ca.cer" \
         "$G/delayos-general-ca.crt" "$SH/shimx64.efi" "$SH/mmx64.efi"; do
  [[ -s $f ]] || die "missing in the packages: ${f#"$WORK"/*/}"
done
if command -v sbverify >/dev/null; then
  sbverify --cert "$G/delayos-general-ca.crt" "$G/grubx64.efi" >/dev/null || die "grubx64.efi is not signed by the DelayOS general CA"
  sbverify --cert "$G/delayos-general-ca.crt" "$G/vmlinuz-linux-delayos.signed" >/dev/null || die "the kernel image is not signed by the DelayOS general CA"
  sbverify --list "$SH/shimx64.efi" 2>/dev/null | grep -i 'subject:' | sed 's/^/    shim signer: /' || true
else
  warn "sbverify (sbsigntools) is not installed: the signatures were not checked here"
fi

# ---------------------------------------------------------------- the ISO
UUID="$(blkid -o value -s UUID "$IN")"
LABEL="$(blkid -o value -s LABEL "$IN")"
[[ $UUID =~ ^[0-9]{4}(-[0-9]{2}){6}$ ]] || die "cannot read the ISO 9660 UUID of $IN (got '$UUID')"
SEARCH_FILE="/boot/$UUID.uuid"
K="/$INSTALL_DIR/boot/$ARCH/vmlinuz-linux-delayos"
xorriso -no_rc -report_about SORRY -osirrox on -indev "$IN" -extract "$K" "$WORK/vmlinuz.iso" \
  || die "$IN has no $K"
xorriso -no_rc -report_about SORRY -indev "$IN" -find "$SEARCH_FILE" 2>/dev/null | grep -q "$UUID" \
  || die "$IN has no $SEARCH_FILE (archiso too old?)"
have="$(sha256sum "$WORK/vmlinuz.iso" | awk '{print $1}')"
want="$(awk '{print $1; exit}' "$G/vmlinuz-linux-delayos.sha256")"
signed="$(sha256sum "$G/vmlinuz-linux-delayos.signed" | awk '{print $1}')"
[[ $have == "$want" || $have == "$signed" ]] \
  || die "the kernel on the ISO is not the one delayos-sb-general was made from (rebuild delayos-sb-general for this linux-delayos)"

# ---------------------------------------------------------------- /EFI tree
install -m644 "$SH/shimx64.efi" "$WORK/tree/EFI/BOOT/BOOTx64.EFI"
install -m644 "$SH/mmx64.efi"   "$WORK/tree/EFI/BOOT/mmx64.efi"
install -m644 "$G/grubx64.efi"  "$WORK/tree/EFI/BOOT/grubx64.efi"
sed -e "s|@SEARCH_FILE@|$SEARCH_FILE|g" -e "s|@INSTALL_DIR@|$INSTALL_DIR|g" -e "s|@ARCH@|$ARCH|g" \
    -e "s|@LIVE_OPTS@|${OPTS//|/ }|g" -e 's/\r$//' "$HERE/iso-secureboot/grub.cfg" > "$WORK/tree/EFI/DelayOS/grub.cfg"
grep -q '@[A-Z_]*@' "$WORK/tree/EFI/DelayOS/grub.cfg" && die "grub.cfg still has placeholders"
if command -v grub-script-check >/dev/null; then
  grub-script-check "$WORK/tree/EFI/DelayOS/grub.cfg" || die "tools/iso-secureboot/grub.cfg has a syntax error"
fi
# 32-bit UEFI (64-bit CPU, e.g. Bay Trail tablets): no Secure Boot there, so an unsigned GRUB with
# the same prefix and configuration. Left out when this grub has no i386-efi modules.
if command -v grub-mkimage >/dev/null && [[ -d /usr/lib/grub/i386-efi ]]; then
  mods=()
  for m in all_video boot cat configfile echo efifwsetup exfat ext2 fat font gfxterm halt iso9660 keystatus linux \
           loadenv loopback ls minicmd normal ntfs part_gpt part_msdos probe read reboot regexp search \
           search_fs_file search_fs_uuid search_label sleep test true udf video; do
    [[ -f /usr/lib/grub/i386-efi/$m.mod ]] && mods+=("$m")
  done
  grub-mkimage -O i386-efi -p /EFI/DelayOS -o "$WORK/tree/EFI/BOOT/BOOTIA32.EFI" "${mods[@]}" \
    || { warn "no GRUB for 32-bit UEFI (grub-mkimage failed)"; rm -f "$WORK/tree/EFI/BOOT/BOOTIA32.EFI"; }
fi
install -m644 "$G/delayos-general-ca.cer" "$WORK/delayos-general-ca.cer"

# ---------------------------------------------------------------- EFI partition image
kib=$(( ( $(du -bcs "$WORK/tree" "$WORK/delayos-general-ca.cer" | awk 'END{print $1}') / 1024 / 1024 + 5 ) * 1024 ))
ESP="$WORK/efiboot.img"
rm -f "$ESP"
mkfs.fat -C -n ARCHISO_EFI "$ESP" "$kib" >/dev/null
mcopy -s -i "$ESP" "$WORK/tree/EFI" ::/
mcopy -i "$ESP" "$WORK/delayos-general-ca.cer" ::/

# ---------------------------------------------------------------- write the new ISO
maps=(-map "$WORK/tree/EFI" /EFI
      -map "$WORK/delayos-general-ca.cer" /delayos-general-ca.cer
      -map "$G/vmlinuz-linux-delayos.signed" "$K")
if [[ -s $FONT ]]; then
  maps+=(-map "$FONT" /boot/grub/fonts/unicode.pf2)
else
  warn "$FONT is missing: the boot menu of the medium will be English (it is hidden anyway)"
fi
# what systemd-boot (or archiso's own GRUB) left on the ISO 9660 file system
rm=()
for d in /EFI /loader; do
  if xorriso -no_rc -report_about SORRY -indev "$IN" -find "$d" -maxdepth 0 2>/dev/null | grep -q .; then
    rm+=(-rm_r "$d" --)
  fi
done
log "Secure Boot: writing $(basename "$OUT") (shim -> DelayOS-signed GRUB -> signed linux-delayos)"
rm -f "$OUT"
# -boot_image any replay: the same El Torito / MBR / GPT layout as the ISO that is read (BIOS boot
# through syslinux included); the EFI partition is then replaced by the image made above.
# -volume_date uuid: keep the ISO 9660 UUID that the BIOS boot entries search for.
xorriso -no_rc -report_about WARNING \
  -indev "$IN" -outdev "$OUT" \
  -volume_date uuid "${UUID//-/}" \
  "${rm[@]}" \
  "${maps[@]}" \
  -boot_image any replay \
  -append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B "$ESP" \
  -commit || die "xorriso failed"

# ---------------------------------------------------------------- check the result
[[ "$(blkid -o value -s UUID "$OUT")" == "$UUID" ]] || die "the new ISO has another UUID: BIOS boot would not find it"
[[ "$(blkid -o value -s LABEL "$OUT")" == "$LABEL" ]] || die "the new ISO has another label"
rep="$(xorriso -no_rc -report_about SORRY -indev "$OUT" -report_el_torito plain 2>/dev/null)"
grep -q 'UEFI' <<<"$rep" || die "the new ISO has no El Torito UEFI boot image"
if xorriso -no_rc -report_about SORRY -indev "$IN" -report_el_torito plain 2>/dev/null | grep -q 'BIOS'; then
  grep -q 'BIOS' <<<"$rep" || die "the new ISO lost its BIOS boot image"
fi
xorriso -no_rc -report_about SORRY -osirrox on -indev "$OUT" -extract "$K" "$WORK/vmlinuz.out" >/dev/null 2>&1
[[ "$(sha256sum "$WORK/vmlinuz.out" | awk '{print $1}')" == "$signed" ]] || die "the kernel on the new ISO is not the signed image"
log "Secure Boot: done. First start on a PC: MokManager > Enroll key from disk > delayos-general-ca.cer (docs/secure-boot.md)"
