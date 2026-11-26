#!/usr/bin/env bash
# DelayOS content packages: which file of profile/airootfs belongs to which delayos-* package.
#
# The files stay where every work stream edits them (profile/airootfs/<final path>). Each content
# package has a list of paths, packages/delayos-<name>/files.list, and its PKGBUILD copies exactly
# those files out of the tree. Nothing is stored twice. docs/packaging.md has the whole picture.
#
#   tools/content-pkgs.sh list                     names of the content packages
#   tools/content-pkgs.sh files <pkg>              files of one package (relative to airootfs)
#   tools/content-pkgs.sh check                    every file is in exactly one package or live-only
#   tools/content-pkgs.sh hash <pkg>               content hash (files, modes, PKGBUILD, files.list, install script)
#   tools/content-pkgs.sh install <pkg> <destdir>  copy the files into <destdir> with their modes
#   tools/content-pkgs.sh backup <pkg>             the /etc files for the PKGBUILD backup=() array
#   tools/content-pkgs.sh strip <airootfs> <profiledef.sh> <pkgfile>...
#                                                  build.sh: take what the built packages ship out of
#                                                  the assembled ISO profile (pacstrap installs it)
#
# files.list: one path per line, relative to airootfs. A directory (trailing "/") means everything
# below it. Shell globs work (*, ?, **). A line starting with "!" takes matching files out again.
# packages/delayos-live-only.list has the same format: files that only the live ISO needs.
#
# DELAYOS_REPO_ROOT overrides the repository root (default: the parent directory of tools/).
set -euo pipefail
export LC_ALL=C.UTF-8

ROOT="${DELAYOS_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
TREE="${DELAYOS_TREE:-$ROOT/profile/airootfs}"
PKGS="$ROOT/packages"
PROFILEDEF="${DELAYOS_PROFILEDEF:-$ROOT/profile/profiledef.sh}"

die() { printf 'content-pkgs: %s\n' "$*" >&2; exit 1; }

content_pkgs() {
  local d
  for d in "$PKGS"/delayos-*/; do
    [[ -f $d/files.list ]] && basename "$d"
  done
}

# expand one list file to the files it names (sorted, unique)
expand_list() { # $1 = list file
  local list=$1 line pat inc ex
  [[ -f $list ]] || die "no such list: $list"
  inc=$(mktemp); ex=$(mktemp)
  (
    cd "$TREE"
    shopt -s globstar nullglob dotglob
    while IFS= read -r line || [[ -n $line ]]; do
      line="${line%$'\r'}"; line="${line%%#*}"
      line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"
      [[ -z $line ]] && continue
      out=$inc
      [[ $line == \!* ]] && { out=$ex; line="${line#!}"; }
      pat="${line%/}"
      for m in $pat; do
        if [[ -d $m && ! -L $m ]]; then
          find "$m" \( -type f -o -type l \) -print
        elif [[ -e $m || -L $m ]]; then
          printf '%s\n' "$m"
        fi
      done >> "$out"
    done < "$list"
  )
  sort -u "$inc" | grep -vxFf <(sort -u "$ex") || true
  rm -f "$inc" "$ex"
}

pkg_files() { # $1 = package
  [[ -f $PKGS/$1/files.list ]] || die "$1 is not a content package (no packages/$1/files.list)"
  expand_list "$PKGS/$1/files.list"
}

# modes from the archiso profile: file_permissions=( ["/path"]="uid:gid:mode" )
declare -A file_permissions=()
load_modes() {
  [[ -f $PROFILEDEF ]] || return 0
  # shellcheck disable=SC1090
  source "$PROFILEDEF" >/dev/null 2>&1 || die "cannot read $PROFILEDEF"
}

mode_of() { # $1 = path relative to airootfs
  local p="/$1" m="${file_permissions["/$1"]:-}"
  if [[ -n $m ]]; then echo "${m##*:}"; return; fi
  case "$p" in
    /usr/bin/*|/usr/local/bin/*) echo 755 ;;
    /etc/sudoers.d/*) echo 440 ;;
    *) if [[ -x $TREE/$1 && ! -d $TREE/$1 ]] && head -c2 "$TREE/$1" 2>/dev/null | grep -q '^#!'; then echo 755; else echo 644; fi ;;
  esac
}

cmd_check() {
  local all tmp p rc=0
  tmp=$(mktemp -d)
  ( cd "$TREE" && find . \( -type f -o -type l \) -print | sed 's|^\./||' | sort ) > "$tmp/all"
  : > "$tmp/claimed"
  for p in $(content_pkgs); do
    pkg_files "$p" | sed "s|\$|\t$p|" >> "$tmp/claimed"
  done
  expand_list "$PKGS/delayos-live-only.list" | sed 's|$|\tlive-only|' >> "$tmp/claimed"
  # in two lists
  if cut -f1 "$tmp/claimed" | sort | uniq -d | grep -q .; then
    echo "Files claimed more than once:"
    cut -f1 "$tmp/claimed" | sort | uniq -d | while IFS= read -r f; do
      printf '  %s  (%s)\n' "$f" "$(grep -F "$f"$'\t' "$tmp/claimed" | cut -f2 | tr '\n' ' ')"
    done
    rc=1
  fi
  # in no list: they stay baked into the ISO and never update on installed systems
  if comm -23 "$tmp/all" <(cut -f1 "$tmp/claimed" | sort -u) | grep -q .; then
    echo "Files in no package and not in delayos-live-only.list (they will not receive updates):"
    comm -23 "$tmp/all" <(cut -f1 "$tmp/claimed" | sort -u) | sed 's/^/  /'
    rc=1
  fi
  for p in $(content_pkgs); do
    printf '%-24s %5d files\n' "$p" "$(grep -c $'\t'"$p"'$' "$tmp/claimed" || true)"
  done
  printf '%-24s %5d files\n' "live-only" "$(grep -c $'\tlive-only$' "$tmp/claimed" || true)"
  rm -rf "$tmp"
  return $rc
}

cmd_hash() { # stable over checkouts: path, mode and content of every file + the packaging files
  local p=$1 f
  load_modes
  {
    while IFS= read -r f; do
      printf '%s %s %s\n' "$f" "$(mode_of "$f")" "$(sha256sum < "$TREE/$f" | cut -d' ' -f1)"
    done < <(pkg_files "$p")
    for f in "$PKGS/$p"/*; do
      case "$f" in *.pkg.tar.zst|*.sig|*.log) continue ;; esac
      [[ -f $f ]] && printf '%s %s\n' "$(basename "$f")" "$(tr -d '\r' < "$f" | sha256sum | cut -d' ' -f1)"
    done
  } | sha256sum | cut -d' ' -f1
}

cmd_install() {
  local p=$1 dest=$2 f n=0
  [[ -d $dest ]] || die "no such directory: $dest"
  load_modes
  while IFS= read -r f; do
    install -d "$dest/$(dirname "$f")"
    if [[ -L $TREE/$f ]]; then
      cp -P "$TREE/$f" "$dest/$f"
    else
      install -m "$(mode_of "$f")" "$TREE/$f" "$dest/$f"
    fi
    n=$((n + 1))
  done < <(pkg_files "$p")
  (( n )) || die "$p: files.list matches nothing in $TREE"
  # the directories other packages own with special modes
  [[ -d $dest/etc/sudoers.d ]] && chmod 750 "$dest/etc/sudoers.d"
  # ship Python bytecode: /usr is not writable for users, they could never cache it themselves.
  # checked-hash stays valid whatever happens to file times; 70-delay-pycache.hook redoes it
  # when Python itself is upgraded.
  if [[ -d $dest/usr/share/delayos ]] && find "$dest/usr/share/delayos" -name '*.py' -print -quit | grep -q .; then
    python3 -m compileall -q -s "$dest" -p / --invalidation-mode checked-hash "$dest/usr/share/delayos" >/dev/null \
      || echo "content-pkgs: bytecode precompile failed for $p (apps compile at start)" >&2
  fi
  echo "$p: $n files"
}

# /etc files a user may edit are backup files (pacman keeps the user's version and writes .pacnew).
# Hooks, units, sudoers and autostart entries are code, not configuration: always replaced.
cmd_backup() {
  pkg_files "$1" | grep '^etc/' | grep -Ev '^etc/(pacman\.d/hooks|systemd/system|sudoers\.d|xdg/autostart|xdg/menus|skel)/' || true
}

cmd_strip() {
  local airootfs=$1 profiledef=$2; shift 2
  local pkg f n=0
  [[ -d $airootfs ]] || die "no such directory: $airootfs"
  for pkg in "$@"; do
    while IFS= read -r f; do
      [[ $f == .* || $f == */ ]] && continue
      if [[ -e $airootfs/$f || -L $airootfs/$f ]]; then
        rm -f "${airootfs:?}/$f"; n=$((n + 1))
        ( cd "$airootfs" && rmdir -p --ignore-fail-on-non-empty "$(dirname "$f")" 2>/dev/null ) || true
      fi
      # mkarchiso stops when a file_permissions entry points into a directory that is gone
      [[ -f $profiledef ]] && sed -i "\|^[[:space:]]*\[\"/$f\"\]=|d" "$profiledef"
    done < <(bsdtar -tf "$pkg")
  done
  :
  echo "content-pkgs: $n files now come from packages instead of the ISO overlay"
}

case "${1:-}" in
  list)    content_pkgs ;;
  files)   pkg_files "${2:?package}" ;;
  check)   cmd_check ;;
  hash)    cmd_hash "${2:?package}" ;;
  install) cmd_install "${2:?package}" "${3:?destdir}" ;;
  backup)  cmd_backup "${2:?package}" ;;
  strip)   shift; (( $# >= 3 )) || die "usage: strip <airootfs> <profiledef.sh> <pkgfile>..."; cmd_strip "$@" ;;
  *) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
