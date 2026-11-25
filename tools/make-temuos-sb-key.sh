#!/usr/bin/env bash
# Creates the TEMUOS_LINUX Secure Boot keys on the build host (run once, keep them forever).
#
#   sudo tools/make-temuos-sb-key.sh [OUTDIR]        default OUTDIR: /root/temuos-keys
#
# Output (OUTDIR is created with mode 700, private keys mode 600):
#   temuos-sb-ca.key        TEMUOS Secure Boot CA private key. Only needed to issue a new
#                           signing certificate: move it OFFLINE (encrypted USB stick) after this.
#   temuos-sb-ca.crt / .cer TEMUOS Secure Boot CA certificate (PEM / DER). PUBLIC. This is the
#                           "well-known key": enrolled as MOK on user machines (or put into db),
#                           and the file to send to Epic (linux-gaming@epicgames.com).
#   temuos-sb-signing.key   Signing key (kernel image, all modules, GRUB, systemd-boot).
#   temuos-sb-signing.crt   Signing certificate, issued by the CA (codeSigning).
#   env.sh                  export TEMUOS_SB_KEY / TEMUOS_SB_CERT / TEMUOS_SB_CA for makepkg
#
# The keys are never written into the repository: OUTDIR must be outside of it.
# RSA-2048 / SHA-256 on purpose: every UEFI firmware and shim verifies it (some firmware
# fails on RSA-4096 in db, and the Microsoft UEFI CAs are RSA-2048 as well).
set -euo pipefail

die() { printf 'make-temuos-sb-key: %s\n' "$*" >&2; exit 1; }

OUT="${1:-/root/temuos-keys}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
YEAR="$(date -u +%Y)"

command -v openssl >/dev/null || die "openssl is missing (pacman -S openssl)"

OUT_ABS="$(realpath -m "$OUT")"
case "$OUT_ABS/" in
    "$REPO"/*) die "$OUT_ABS is inside the repository ($REPO). Keys must never be committed: use e.g. /root/temuos-keys" ;;
esac
if git -C "$(dirname "$OUT_ABS")" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "$OUT_ABS is inside a git work tree. Keys must never be committed: choose another directory"
fi
for f in temuos-sb-ca.key temuos-sb-signing.key; do
    [ -e "$OUT_ABS/$f" ] && die "$OUT_ABS/$f already exists. Never replace the keys: users enrolled the CA and Epic knows it."
done

umask 077
mkdir -p "$OUT_ABS"
chmod 700 "$OUT_ABS"
cd "$OUT_ABS"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/ca.cnf" <<EOF
[ req ]
distinguished_name = dn
prompt             = no
x509_extensions    = v3_ca
[ dn ]
CN = TEMUOS_LINUX Secure Boot CA ${YEAR}
O  = TEMUOS_LINUX
[ v3_ca ]
basicConstraints       = critical, CA:TRUE
keyUsage               = critical, keyCertSign, cRLSign, digitalSignature
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always
EOF

cat > "$TMP/signing.cnf" <<EOF
[ req ]
distinguished_name = dn
prompt             = no
[ dn ]
CN = TEMUOS_LINUX Secure Boot Signing ${YEAR}
O  = TEMUOS_LINUX
[ v3_sign ]
basicConstraints       = critical, CA:FALSE
keyUsage               = critical, digitalSignature
# codeSigning + Linux kernel module signing
extendedKeyUsage       = codeSigning, 1.3.6.1.4.1.2312.16.1.2
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid
EOF

echo "==> TEMUOS Secure Boot CA (20 years)"
openssl req -x509 -new -newkey rsa:2048 -sha256 -days 7300 -noenc \
    -config "$TMP/ca.cnf" -keyout temuos-sb-ca.key -out temuos-sb-ca.crt
openssl x509 -in temuos-sb-ca.crt -outform DER -out temuos-sb-ca.cer

echo "==> TEMUOS Secure Boot signing key (10 years, issued by the CA)"
openssl req -new -newkey rsa:2048 -sha256 -noenc \
    -config "$TMP/signing.cnf" -keyout temuos-sb-signing.key -out "$TMP/signing.csr"
openssl x509 -req -in "$TMP/signing.csr" -sha256 -days 3650 \
    -CA temuos-sb-ca.crt -CAkey temuos-sb-ca.key -set_serial "0x$(openssl rand -hex 16)" \
    -extfile "$TMP/signing.cnf" -extensions v3_sign -out temuos-sb-signing.crt

openssl verify -CAfile temuos-sb-ca.crt temuos-sb-signing.crt

cat > env.sh <<EOF
# source this before makepkg (linux-temuos-eac, temuos-sb-signed)
export TEMUOS_SB_KEY="$OUT_ABS/temuos-sb-signing.key"
export TEMUOS_SB_CERT="$OUT_ABS/temuos-sb-signing.crt"
export TEMUOS_SB_CA="$OUT_ABS/temuos-sb-ca.crt"
EOF

chmod 600 temuos-sb-ca.key temuos-sb-signing.key
chmod 644 temuos-sb-ca.crt temuos-sb-ca.cer temuos-sb-signing.crt env.sh

echo
echo "Created in $OUT_ABS:"
ls -l "$OUT_ABS"
echo
echo "CA fingerprint (SHA-256), give it to Epic together with temuos-sb-ca.cer:"
openssl x509 -in temuos-sb-ca.crt -noout -subject -fingerprint -sha256
echo
echo "Next:"
echo "  1. Back up the whole directory offline (2 copies). Losing the keys = all users re-enroll."
echo "  2. Move temuos-sb-ca.key offline; the build only needs the signing key + certificates."
echo "  3. Email temuos-sb-ca.cer to linux-gaming@epicgames.com (see docs/eac-linux-v2.md)."
echo "  4. Build: sudo ./build.sh (picks up $OUT_ABS when it is /root/temuos-keys or \$TEMUOS_KEYS)."
