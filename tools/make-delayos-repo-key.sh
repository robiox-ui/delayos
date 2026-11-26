#!/usr/bin/env bash
# Creates the DelayOS package repository signing key (run once, keep it forever).
#
#   tools/make-delayos-repo-key.sh [OUTDIR]
#       Linux default OUTDIR:   /root/delayos-keys/repo
#       Windows (Git Bash):     tools/make-delayos-repo-key.sh "C:\Users\<you>\Documents\delayos-keys\repo"
#
# pacman verifies every package and every database of the [delayos] repositories with this key
# (docs/packaging.md). It is a third, independent key next to the two Secure Boot key sets
# (make-delayos-sb-key.sh, make-delayos-general-key.sh).
#
# Layout: a certify-only primary key (the identity users trust, never expires) and a signing
# subkey (expires after 3 years, can be replaced without touching the trust on user PCs).
#
# Written to OUTDIR (private, mode 600, NEVER into the repository):
#   delayos-repo-master.asc     primary + subkey, private. Move it OFFLINE after this.
#   delayos-repo-signing.asc    signing subkey only, private. This is what the build VM gets
#                               (tools/repo-publish.sh, DELAYOS_REPO_KEY=/path/to/this/file).
#   delayos-repo-public.asc     public key
#   delayos-repo-revoke.asc     revocation certificate of the primary key
#   fingerprint.txt
# Written into the repository (PUBLIC key only), for the delayos-keyring package:
#   packages/delayos-keyring/delayos.gpg, delayos-trusted, delayos-revoked
#
# Environment:
#   DELAYOS_KEY_UID      user ID of the key  (default "DelayOS Package Signing <packages@delayos.invalid>")
#   DELAYOS_KEYRING_DIR  where the public keyring files go (default packages/delayos-keyring)
set -euo pipefail

die() { printf 'make-delayos-repo-key: %s\n' "$*" >&2; exit 1; }

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
OUT="${1:-/root/delayos-keys/repo}"
command -v cygpath >/dev/null 2>&1 && OUT="$(cygpath -u "$OUT")"
KEY_UID="${DELAYOS_KEY_UID:-DelayOS Package Signing <packages@delayos.invalid>}"
KEYRING_DIR="${DELAYOS_KEYRING_DIR:-$REPO/packages/delayos-keyring}"
command -v gpg >/dev/null || die "gpg is missing (pacman -S gnupg; Git for Windows ships it)"

OUT_ABS="$(realpath -m "$OUT")"
case "$OUT_ABS/" in
    "$REPO"/*) die "$OUT_ABS is inside the repository ($REPO). Keys must never be committed." ;;
esac
mkdir -p "$(dirname "$OUT_ABS")"
if git -C "$(dirname "$OUT_ABS")" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "$OUT_ABS is inside a git work tree. Keys must never be committed: choose another directory"
fi
for f in delayos-repo-master.asc delayos-repo-signing.asc; do
    [ -e "$OUT_ABS/$f" ] && die "$OUT_ABS/$f already exists. Never replace the key: user PCs trust it."
done
[ -d "$KEYRING_DIR" ] || die "$KEYRING_DIR does not exist"

umask 077
mkdir -p "$OUT_ABS"
chmod 700 "$OUT_ABS" 2>/dev/null || true
GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
cleanup() { gpgconf --kill all >/dev/null 2>&1 || true; rm -rf "$GNUPGHOME"; }
trap cleanup EXIT
G=(gpg --batch --quiet --no-tty --pinentry-mode loopback --passphrase '')

echo "==> Primary key (ed25519, certify only, no expiry): $KEY_UID"
"${G[@]}" --quick-generate-key "$KEY_UID" ed25519 cert never
FPR="$(gpg --batch --with-colons --list-secret-keys | awk -F: '$1=="fpr" && !d {print $10; d=1}')"
[ ${#FPR} -eq 40 ] || die "could not read the fingerprint of the new key"
echo "==> Signing subkey (ed25519, 3 years)"
"${G[@]}" --quick-add-key "$FPR" ed25519 sign 3y

"${G[@]}" --armor --export-secret-keys "$FPR"    > "$OUT_ABS/delayos-repo-master.asc"
"${G[@]}" --armor --export-secret-subkeys "$FPR" > "$OUT_ABS/delayos-repo-signing.asc"
"${G[@]}" --armor --export "$FPR"                > "$OUT_ABS/delayos-repo-public.asc"
"${G[@]}" --armor --gen-revoke "$FPR"            > "$OUT_ABS/delayos-repo-revoke.asc" 2>/dev/null \
    || cp "$GNUPGHOME/openpgp-revocs.d/$FPR.rev" "$OUT_ABS/delayos-repo-revoke.asc" 2>/dev/null || true
printf '%s\n' "$FPR" > "$OUT_ABS/fingerprint.txt"
chmod 600 "$OUT_ABS"/delayos-repo-*.asc 2>/dev/null || true

grep -q 'PRIVATE KEY' "$OUT_ABS/delayos-repo-public.asc" && die "the public export contains a private key (gpg bug?)"
umask 022
cp "$OUT_ABS/delayos-repo-public.asc" "$KEYRING_DIR/delayos.gpg"
printf '%s:4:\n' "$FPR" > "$KEYRING_DIR/delayos-trusted"
: > "$KEYRING_DIR/delayos-revoked"

echo
echo "Fingerprint: $FPR"
gpg --batch --list-keys --keyid-format long "$FPR" | sed 's/^/  /'
echo
echo "Private keys: $OUT_ABS  (back the directory up offline; move delayos-repo-master.asc offline)"
echo "Public key:   $KEYRING_DIR/delayos.gpg + delayos-trusted + delayos-revoked  (commit these three)"
echo "Next: copy delayos-repo-signing.asc to the build VM (outside the repository) and publish with"
echo "      DELAYOS_REPO_KEY=/root/delayos-keys/repo/delayos-repo-signing.asc GITHUB_TOKEN=... tools/repo-publish.sh"
