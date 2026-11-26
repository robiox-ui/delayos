#!/usr/bin/env bash
# Creates the DelayOS GENERAL Secure Boot keys on the build host (run once, keep them forever).
#
#   sudo tools/make-delayos-general-key.sh [OUTDIR]        default OUTDIR: /root/delayos-keys
#
# These keys sign the normal boot path (GRUB + linux-delayos, package delayos-sb-general) so that
# DelayOS boots with Secure Boot ON next to the hidden Windows (docs/windows-switch.md).
# They are a different CA and key than the anti-cheat keys of tools/make-delayos-sb-key.sh
# (delayos-sb-ca / delayos-sb-signing): that key may only sign the locked-down linux-delayos-eac,
# this one signs a kernel that loads unsigned modules, so it can never be a "well-known" key for
# Epic. The two sets live side by side in OUTDIR and never replace each other.
#
# Output (private keys mode 600):
#   delayos-general-ca.key         CA private key: move it OFFLINE after this
#   delayos-general-ca.crt / .cer  CA certificate (PEM / DER). PUBLIC: enrolled as MOK on user PCs
#   delayos-general-signing.key    signing key (GRUB, linux-delayos image)
#   delayos-general-signing.crt    signing certificate, issued by the CA (codeSigning)
set -euo pipefail

die() { printf 'make-delayos-general-key: %s\n' "$*" >&2; exit 1; }

OUT="${1:-/root/delayos-keys}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
YEAR="$(date -u +%Y)"
command -v openssl >/dev/null || die "openssl is missing (pacman -S openssl)"

OUT_ABS="$(realpath -m "$OUT")"
case "$OUT_ABS/" in
    "$REPO"/*) die "$OUT_ABS is inside the repository ($REPO). Keys must never be committed: use e.g. /root/delayos-keys" ;;
esac
if git -C "$(dirname "$OUT_ABS")" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "$OUT_ABS is inside a git work tree. Keys must never be committed: choose another directory"
fi
for f in delayos-general-ca.key delayos-general-signing.key; do
    [ -e "$OUT_ABS/$f" ] && die "$OUT_ABS/$f already exists. Never replace the keys: users enrolled the CA."
done

umask 077
mkdir -p "$OUT_ABS"
chmod 700 "$OUT_ABS"
cd "$OUT_ABS"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/ca.cnf" <<CNF
[ req ]
distinguished_name = dn
prompt             = no
x509_extensions    = v3_ca
[ dn ]
CN = DelayOS General Boot CA ${YEAR}
O  = DelayOS
[ v3_ca ]
basicConstraints       = critical, CA:TRUE
keyUsage               = critical, keyCertSign, cRLSign, digitalSignature
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always
CNF

cat > "$TMP/signing.cnf" <<CNF
[ req ]
distinguished_name = dn
prompt             = no
[ dn ]
CN = DelayOS General Boot Signing ${YEAR}
O  = DelayOS
[ v3_sign ]
basicConstraints       = critical, CA:FALSE
keyUsage               = critical, digitalSignature
extendedKeyUsage       = codeSigning
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid
CNF

echo "==> DelayOS General Boot CA (20 years)"
openssl req -x509 -new -newkey rsa:2048 -sha256 -days 7300 -noenc \
    -config "$TMP/ca.cnf" -keyout delayos-general-ca.key -out delayos-general-ca.crt
openssl x509 -in delayos-general-ca.crt -outform DER -out delayos-general-ca.cer

echo "==> DelayOS General Boot signing key (10 years, issued by the CA)"
openssl req -new -newkey rsa:2048 -sha256 -noenc \
    -config "$TMP/signing.cnf" -keyout delayos-general-signing.key -out "$TMP/signing.csr"
openssl x509 -req -in "$TMP/signing.csr" -sha256 -days 3650 \
    -CA delayos-general-ca.crt -CAkey delayos-general-ca.key -set_serial "0x$(openssl rand -hex 16)" \
    -extfile "$TMP/signing.cnf" -extensions v3_sign -out delayos-general-signing.crt
openssl verify -CAfile delayos-general-ca.crt delayos-general-signing.crt

chmod 600 delayos-general-ca.key delayos-general-signing.key
chmod 644 delayos-general-ca.crt delayos-general-ca.cer delayos-general-signing.crt

echo
echo "Created in $OUT_ABS:"
ls -l "$OUT_ABS" | grep general
echo
openssl x509 -in delayos-general-ca.crt -noout -subject -fingerprint -sha256
echo
echo "Next: back up the directory offline, move delayos-general-ca.key offline, then run sudo ./build.sh"
echo "(build.sh picks the keys up from /root/delayos-keys or \$DELAYOS_KEYS and builds delayos-sb-general)."
