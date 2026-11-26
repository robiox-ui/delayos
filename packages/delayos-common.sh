#!/hint/bash
# Shared by the DelayOS content packages (packages/delayos-*/PKGBUILD with a files.list).
# The files come straight out of profile/airootfs (tools/content-pkgs.sh); see docs/packaging.md.
#
#   DELAYOS_REPO_ROOT  repository root (default: two directories above the PKGBUILD)
#   DELAYOS_PKGVER     version for all content packages of one build (default: today's date, UTC)
#   DELAYOS_PKGREL     pkgrel (default 1)

_delayos_root="${DELAYOS_REPO_ROOT:-$(realpath "${startdir:-$PWD}/../..")}"
_delayos_tool="$_delayos_root/tools/content-pkgs.sh"
[[ -f $_delayos_tool ]] || { echo "delayos-common: $_delayos_tool not found (set DELAYOS_REPO_ROOT)" >&2; return 1; }

pkgver="${DELAYOS_PKGVER:-$(date -u +%Y.%m.%d)}"
pkgrel="${DELAYOS_PKGREL:-1}"
arch=('any')
url='https://github.com/robiox-ui/delayos'
license=('GPL-3.0-or-later')
options=('!strip' '!debug' 'emptydirs')

# /etc files of this package that a user may edit
delayos_backup() { DELAYOS_REPO_ROOT="$_delayos_root" bash "$_delayos_tool" backup "$pkgname"; }

# package(): copy the files named in files.list from the tree into $pkgdir
delayos_package() {
    DELAYOS_REPO_ROOT="$_delayos_root" bash "$_delayos_tool" install "$pkgname" "$pkgdir"
}
