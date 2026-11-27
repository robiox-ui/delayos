#!/usr/bin/env bash
# Makes a PERSONAL DelayOS ISO that carries a Windows install ISO on the live medium, so that the
# installer's "Windows 게임 지원" uses it without downloading anything (docs/windows-switch.md,
# "개인용 ISO에 Windows ISO 넣기"). Run as root on the build machine, on a finished DelayOS ISO.
#
#   tools/make-personal-iso.sh --iso delayos-YYYY.MM.DD-x86_64.iso --winiso /path/Windows.iso \
#       --out /somewhere/outside/the/repository/delayos-YYYY.MM.DD-x86_64-personal.iso
#
# THE RESULT CONTAINS THIRD-PARTY SOFTWARE (the Windows image). It is for the PC of the person who
# made it: never publish, upload or commit it. That is why this script refuses to write into the
# repository and insists on "personal" in the file name (.gitignore and build.sh skip that name).
#
# What changes in the ISO: one file is added, /windows/<name of the Windows ISO>. Everything else,
# including the El Torito BIOS image and the EFI partition (Secure Boot chain of
# tools/iso-secureboot.sh), is replayed 1:1; the volume UUID and label stay the same, so the boot
# entries are untouched. "delay-winsetup probe" finds /windows/*.iso on the live medium (also after
# copytoram, as long as the medium stays plugged in) and the installer page preselects it.
set -euo pipefail

log()  { printf '\e[1;36m==>\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m==> WARNING:\e[0m %s\n' "$*" >&2; }
die()  { printf '\e[1;31m==> ERROR:\e[0m %s\n' "$*" >&2; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd -P)"
IN="" WIN="" OUT=""
while (( $# )); do
  case $1 in
    --iso) IN=${2:-}; shift 2 ;;
    --winiso) WIN=${2:-}; shift 2 ;;
    --out) OUT=${2:-}; shift 2 ;;
    -h|--help) sed -n '2,17p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[[ -f $IN ]] || die "--iso: no such DelayOS ISO: $IN"
[[ -f $WIN ]] || die "--winiso: no such file: $WIN"
[[ -n $OUT ]] || die "--out is missing"
for t in xorriso blkid sha256sum realpath stat df; do
  command -v "$t" >/dev/null || die "$t is missing (pacman -S libisoburn util-linux coreutils)"
done

OUT_DIR="$(realpath -m "$(dirname "$OUT")")"
OUT="$OUT_DIR/$(basename "$OUT")"
IN="$(realpath "$IN")"; WIN="$(realpath "$WIN")"
[[ $OUT != "$IN" && $OUT != "$WIN" ]] || die "--out must be a new file"
[[ "$(basename "$OUT")" == *personal*.iso ]] \
  || die "--out must be named *personal*.iso (e.g. $(basename "${IN%.iso}")-personal.iso): that name is never picked up for publishing"
# never inside the repository (this checkout, or any git work tree the folder belongs to)
case "$OUT_DIR/" in
  "$REPO"/*) die "--out is inside the repository ($REPO). A personal ISO must stay outside it: it must never be committed or published." ;;
esac
d="$OUT_DIR"
while [[ -n $d && $d != / ]]; do
  [[ -e $d/.git ]] && die "--out is inside a git work tree ($d). A personal ISO must stay outside any repository."
  d="$(dirname "$d")"
done
case "$WIN" in
  "$REPO"/*) die "the Windows ISO lies inside the repository ($REPO). Move it out: it must never be committed." ;;
esac

WNAME="$(basename "$WIN")"
[[ ${WNAME,,} == *.iso ]] || die "--winiso must be an .iso file (the live system looks for /windows/*.iso)"
[[ $WNAME != *[[:cntrl:]]* ]] || die "--winiso: strange file name"
wtype="$(blkid -o value -s TYPE "$WIN" 2>/dev/null || true)"
[[ $wtype == udf || $wtype == iso9660 ]] || warn "$WNAME does not look like a disc image (blkid: '${wtype:-unknown}'). It is added as it is."

UUID="$(blkid -o value -s UUID "$IN")"
LABEL="$(blkid -o value -s LABEL "$IN")"
[[ $UUID =~ ^[0-9]{4}(-[0-9]{2}){6}$ ]] || die "cannot read the ISO 9660 UUID of $IN (got '$UUID')"
[[ ${LABEL^^} == DELAYOS* ]] || warn "$IN has the label '$LABEL', not DELAYOS_*: is this a DelayOS ISO?"
xorriso -no_rc -report_about SORRY -indev "$IN" -find "/boot/$UUID.uuid" 2>/dev/null | grep -q "$UUID" \
  || die "$IN has no /boot/$UUID.uuid: not a DelayOS (archiso) ISO"
if xorriso -no_rc -report_about SORRY -indev "$IN" -find /windows -maxdepth 0 2>/dev/null | grep -q .; then
  die "$IN has a /windows folder already: start from the ISO that build.sh wrote"
fi

mkdir -p "$OUT_DIR"
need=$(( $(stat -c %s "$IN") + $(stat -c %s "$WIN") + 64 * 1024 * 1024 ))
avail=$(( $(df -P -B1 "$OUT_DIR" | awk 'NR==2{print $4}') ))
(( avail > need )) || die "not enough space in $OUT_DIR: $(( need / 1048576 )) MiB needed, $(( avail / 1048576 )) MiB free"

boot_report() { xorriso -no_rc -report_about SORRY -indev "$1" -report_el_torito plain 2>/dev/null; }
# sha256 of every El Torito UEFI boot image / of the appended EFI partition (they hold the Secure Boot chain)
uefi_sums() {
  local iso=$1 dir; dir="$(mktemp -d)"
  xorriso -no_rc -report_about SORRY -osirrox on -indev "$iso" -extract_boot_images "$dir/" >/dev/null 2>&1 || true
  ( cd "$dir" && for f in *uefi* *efi*; do if [[ -f $f ]]; then sha256sum < "$f"; fi; done | sort -u )
  rm -rf "$dir"
}

log "Personal ISO: adding $WNAME ($(( $(stat -c %s "$WIN") / 1048576 )) MiB) as /windows/$WNAME"
rm -f "$OUT" "$OUT.sha256"
trap 'rc=$?; (( rc )) && rm -f "$OUT" "$OUT.sha256"; exit $rc' EXIT
# -boot_image any replay: the same El Torito / MBR / GPT layout and the same EFI partition as the
#   ISO that is read (BIOS boot and the Secure Boot chain stay as they are).
# -volume_date uuid: keep the ISO 9660 UUID that the boot entries search for.
# iso_9660_level=3: a Windows ISO of 4 GiB or more is stored as one file with several extents.
xorriso -no_rc -report_about WARNING \
  -indev "$IN" -outdev "$OUT" \
  -compliance iso_9660_level=3 \
  -volume_date uuid "${UUID//-/}" \
  -map "$WIN" "/windows/$WNAME" \
  -chmod 0444 "/windows/$WNAME" -- \
  -boot_image any replay \
  -commit || die "xorriso failed"

# ---------------------------------------------------------------- check the result
[[ "$(blkid -o value -s UUID "$OUT")" == "$UUID" ]] || die "the new ISO has another UUID: it would not find itself at boot"
[[ "$(blkid -o value -s LABEL "$OUT")" == "$LABEL" ]] || die "the new ISO has another label"
rin="$(boot_report "$IN")"; rout="$(boot_report "$OUT")"
for kind in BIOS UEFI; do
  if grep -q "$kind" <<<"$rin"; then
    grep -q "$kind" <<<"$rout" || die "the new ISO lost its El Torito $kind boot image"
  fi
done
sin="$(uefi_sums "$IN")"; sout="$(uefi_sums "$OUT")"
if [[ -n $sin ]]; then
  [[ $sin == "$sout" ]] || die "the EFI boot image of the new ISO differs from the one of $IN"
  log "EFI boot image: identical to the one of $(basename "$IN")"
else
  warn "this xorriso cannot extract boot images: the EFI boot image was not compared"
fi
got="$(xorriso -no_rc -report_about SORRY -indev "$OUT" -find "/windows/$WNAME" -exec lsdl -- 2>/dev/null | awk '{print $5; exit}')"
[[ $got == "$(stat -c %s "$WIN")" ]] || die "/windows/$WNAME on the new ISO has the wrong size ($got)"

( cd "$OUT_DIR" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256" )
trap - EXIT
log "Done: $OUT"
log "sha256: $(awk '{print $1}' "$OUT.sha256")"
printf '\e[1;31m%s\e[0m\n' \
  "======================================================================================" \
  " PERSONAL ISO: DO NOT PUBLISH" \
  " $OUT" \
  " contains third-party software (the Windows image in /windows/)." \
  " Use it on your own PC only. Never upload, share, release or commit this file." \
  "======================================================================================" >&2
