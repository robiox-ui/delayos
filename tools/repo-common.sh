#!/hint/bash
# Shared by tools/repo-build.sh, repo-publish.sh and repo-update.sh (docs/packaging.md).
#
# Repositories and where they live:
#   level     pacman repo        GitHub release tag     package arch   compiler target
#   generic   [delayos]          repo-delayos           x86_64 / any   -march=x86-64
#   v3        [delayos-v3]       repo-delayos-v3        x86_64_v3      -march=x86-64-v3
#   v4        [delayos-v4]       repo-delayos-v4        x86_64_v4      -march=x86-64-v4
#   znver4    [delayos-znver4]   repo-delayos-znver4    x86_64_v4      -march=znver4
#
# Local state (build VM), all below $DELAYOS_REPO_STATE (default /var/lib/delayos-repo):
#   pool/<repo>/     the packages of one repository + its database (what repo-publish.sh uploads)
#   chroot/<level>/  devtools clean chroot of that level
#   work/            build directories
#   conf/            generated makepkg.conf / pacman.conf per level

# pacman, makepkg and gpg answer in the language of the machine; this script reads their output
export LC_ALL=C LANG=C

GH_OWNER="${DELAYOS_GH_OWNER:-robiox-ui}"
GH_REPO="${DELAYOS_GH_REPO:-delayos}"
LEVELS=(generic v3 v4 znver4)
STATE="${DELAYOS_REPO_STATE:-/var/lib/delayos-repo}"
POOL="${DELAYOS_REPO_POOL:-$STATE/pool}"
BUILDER="${DELAYOS_BUILDER:-delaybuilder}"
REPO_ROOT="${DELAYOS_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
PACKAGER_ID="${DELAYOS_PACKAGER:-DelayOS Build <packages@delayos.invalid>}"

log()  { printf '\e[1;36m==>\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m==> WARNING:\e[0m %s\n' "$*" >&2; }
die()  { printf '\e[1;31m==> ERROR:\e[0m %s\n' "$*" >&2; exit 1; }

valid_level() { local l; for l in "${LEVELS[@]}"; do [[ $l == "$1" ]] && return 0; done; return 1; }
repo_name()   { [[ $1 == generic ]] && echo delayos || echo "delayos-$1"; }
release_tag() { echo "repo-$(repo_name "$1")"; }
pool_dir()    { echo "$POOL/$(repo_name "$1")"; }
level_arch()  { case "$1" in v3) echo x86_64_v3 ;; v4|znver4) echo x86_64_v4 ;; *) echo x86_64 ;; esac; }
level_march() { case "$1" in v3) echo x86-64-v3 ;; v4) echo x86-64-v4 ;; znver4) echo znver4 ;; *) echo x86-64 ;; esac; }
# kernel/linux-delayos/PKGBUILD: _processor_opt and the package suffix of each level
level_kopt()  { case "$1" in v3) echo generic_v3 ;; v4) echo generic_v4 ;; znver4) echo zen4 ;; *) echo generic_v1 ;; esac; }
level_ksuffix() { [[ $1 == generic ]] && echo delayos || echo "delayos-$1"; }

# "a,b" or "all" -> one level per line
expand_levels() {
  local l
  if [[ $1 == all ]]; then printf '%s\n' "${LEVELS[@]}"; return; fi
  for l in ${1//,/ }; do valid_level "$l" || die "unknown level '$l' (generic, v3, v4, znver4, all)"; echo "$l"; done
}

# can this machine run code of that level? (needed for check() and for anything a build executes)
cpu_runs_level() {
  case "$1" in
    generic) return 0 ;;
    v3) /lib/ld-linux-x86-64.so.2 --help 2>/dev/null | grep -q 'x86-64-v3 (supported' ;;
    v4) /lib/ld-linux-x86-64.so.2 --help 2>/dev/null | grep -q 'x86-64-v4 (supported' ;;
    znver4) /lib/ld-linux-x86-64.so.2 --help 2>/dev/null | grep -q 'x86-64-v4 (supported' &&
            grep -qm1 'AuthenticAMD' /proc/cpuinfo && grep -qEm1 '^cpu family\s*: (25|26)$' /proc/cpuinfo ;;
  esac
}

# GitHub turns every character of an asset name that is not [A-Za-z0-9._-] into "."
# (pahole-1:1.32-2 -> pahole-1.1.32-2). pacman asks for the name stored in the database, so the
# files get the GitHub-safe name before repo-add ever sees them.
safe_name() { local n; n=$(basename "$1"); printf '%s\n' "${n//[^A-Za-z0-9._-]/.}"; }

# ------------------------------------------------------------------ pool + database
db_file() { echo "$(pool_dir "$1")/$(repo_name "$1").db.tar.gz"; }

ensure_pool() { # $1 = level ; an empty database, so pacman can sync a repo that has nothing yet
  local d db name; d=$(pool_dir "$1"); name=$(repo_name "$1"); db=$(db_file "$1")
  mkdir -p "$d"
  if [[ ! -f $db ]]; then
    bsdtar -czf "$db" -T /dev/null
    cp "$db" "$d/$name.files.tar.gz"
  fi
  [[ -e $d/$name.db ]] || ln -sf "$name.db.tar.gz" "$d/$name.db"
  [[ -e $d/$name.files ]] || ln -sf "$name.files.tar.gz" "$d/$name.files"
}

# "name version filename" of every package in a database file
db_list() { # $1 = db file
  [[ -s $1 ]] || return 0
  # an empty database has no desc entries: bsdtar fails, the list is simply empty
  { bsdtar -xOf "$1" '*/desc' 2>/dev/null || true; } | awk '
    /^%FILENAME%$/ { getline f; next }
    /^%NAME%$/     { getline n; next }
    /^%VERSION%$/  { getline v; print n, v, f; f = n = v = "" }'
}
# (no early exit in these awk programs: under pipefail a writer killed by SIGPIPE fails the pipeline)
pool_version() { db_list "$(db_file "$1")" | awk -v n="$2" '$1==n && !d {print $2; d=1}'; }
pool_has_packages() { [[ -n $(db_list "$(db_file "$1")") ]]; }

pkg_field() { bsdtar -xOf "$1" .PKGINFO 2>/dev/null | sed -n "s/^$2 = //p"; }

# put freshly built package files into the pool of a level and into its database
pool_add() { # $1 = level ; $2.. = package files
  local level=$1 d db f dst added=(); shift
  d=$(pool_dir "$level"); db=$(db_file "$level")
  ensure_pool "$level"
  for f in "$@"; do
    [[ -f $f ]] || continue
    case "$f" in *-debug-[0-9]*.pkg.tar.zst) continue ;; esac
    dst="$d/$(safe_name "$f")"
    # a package whose signature was made for other bytes is worse than an unsigned one
    rm -f "$dst.sig"
    cp -f "$f" "$dst"
    added+=("$dst")
  done
  (( ${#added[@]} )) || return 0
  # -R: the files of the versions being replaced leave the pool
  repo-add -q -R "$db" "${added[@]}"
  rm -f "$db.sig" "$d/$(repo_name "$level").files.tar.gz.sig" "$d"/*.old
}

pool_remove() { # $1 = level ; $2.. = package names
  local level=$1 d db n; shift
  d=$(pool_dir "$level"); db=$(db_file "$level")
  [[ -f $db ]] || return 0
  for n in "$@"; do
    db_list "$db" | awk -v n="$n" '$1==n{print $3}' | while read -r f; do rm -f "$d/$f" "$d/$f.sig"; done
    repo-remove -q "$db" "$n" 2>/dev/null || true
  done
  rm -f "$db.sig" "$d/$(repo_name "$level").files.tar.gz.sig" "$d"/*.old
}

# ------------------------------------------------------------------ makepkg.conf / pacman.conf per level
# CachyOS's repo builders (docs/cachyos/build-toolchain.md): -O3, Arch's hardening set, LTO,
# no frame pointers, no debug packages. CARCH stays x86_64 so every PKGBUILD works unchanged;
# only the architecture stamped on the package differs (PACKAGECARCH, see below).
gen_makepkg_conf() { # $1 = level -> prints the path
  local level=$1 out base march mtune extra="" rustcpu go=""
  out="$STATE/conf/makepkg-$level.conf"; mkdir -p "$STATE/conf"
  base=/usr/share/devtools/makepkg.conf.d/x86_64.conf
  [[ -f $base ]] || base=/etc/makepkg.conf
  march=$(level_march "$level"); mtune="-mtune=generic"; rustcpu=$march
  case "$level" in
    v3) extra=" -mpclmul"; go=v3 ;;
    v4) extra=" -mpclmul"; go=v4 ;;
    znver4) extra=" -mpclmul"; mtune="-mtune=znver4"; rustcpu=x86-64-v4; go=v4 ;;
  esac
  {
    cat <<EOF

# ---- DelayOS $(repo_name "$level") builder (generated by tools/repo-common.sh, do not edit) ----
CFLAGS="-march=$march $mtune -O3 -pipe -fno-plt -fexceptions \\
        -Wp,-D_FORTIFY_SOURCE=3 -Wformat -Werror=format-security \\
        -fstack-clash-protection -fcf-protection$extra"
CXXFLAGS="\$CFLAGS -Wp,-D_GLIBCXX_ASSERTIONS"
LDFLAGS="-Wl,-O1 -Wl,--sort-common -Wl,--as-needed -Wl,-z,relro -Wl,-z,now -Wl,-z,pack-relative-relocs"
LTOFLAGS="-flto=auto"
RUSTFLAGS="-C opt-level=3 -C target-cpu=$rustcpu -Clink-arg=-z -Clink-arg=pack-relative-relocs"
MAKEFLAGS="-j${DELAYOS_JOBS:-\$(nproc)}"
NINJAFLAGS="-j${DELAYOS_JOBS:-\$(nproc)}"
OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge !debug lto)
COMPRESSZST=(zstd -c -T0 -19 -)
PKGEXT='.pkg.tar.zst'
PACKAGER="$PACKAGER_ID"
EOF
    [[ -n $go ]] && echo "export GOAMD64=$go"
    if [[ $level != generic ]]; then
      cat <<EOF
# The architecture written into the package (and its file name). Stock makepkg only knows CARCH;
# CachyOS patches makepkg for this (PACKAGECARCH). makepkg reads this file after its own
# functions are defined, so the same thing is done here by replacing get_pkg_arch.
# tools/repo-build.sh checks the result of every build (arch in .PKGINFO).
PACKAGECARCH="$(level_arch "$level")"
get_pkg_arch() {
	if [[ -z \$1 ]]; then
		if [[ \$arch = "any" ]]; then printf '%s\n' any; else printf '%s\n' "\$PACKAGECARCH"; fi
	else
		local arch_override
		get_pkgbuild_attribute "\$1" arch 1 arch_override
		(( \${#arch_override[@]} == 0 )) && arch_override=("\${arch[@]}")
		if [[ \$arch_override = "any" ]]; then printf '%s\n' any; else printf '%s\n' "\$PACKAGECARCH"; fi
	fi
}
EOF
    fi
  } > "$out.dropin"
  # the same settings twice: appended to the main file (makepkg --config on this machine), and as a
  # drop-in for the chroot, where /etc/makepkg.conf.d/rust.conf etc. are read after makepkg.conf
  cat "$base" "$out.dropin" > "$out"
  echo "$out"
}

# pacman.conf of the build chroot: our own pools first (pahole for the kernel, qt6-base for
# qt6-declarative, ...), then Arch.
gen_pacman_conf() { # $1 = level -> prints the path
  local level=$1 out archs="x86_64"
  out="$STATE/conf/pacman-$level.conf"; mkdir -p "$STATE/conf"
  case "$level" in v3) archs="x86_64 x86_64_v3" ;; v4|znver4) archs="x86_64 x86_64_v3 x86_64_v4" ;; esac
  {
    cat <<EOF
[options]
HoldPkg      = pacman glibc
Architecture = $archs
ParallelDownloads = 8
SigLevel     = Required DatabaseOptional
LocalFileSigLevel = Optional
NoProgressBar

EOF
    printf '[%s]\nSigLevel = Optional TrustAll\nServer = file://%s\n\n' "$(repo_name "$level")" "$(pool_dir "$level")"
    [[ $level == generic ]] ||
      printf '[%s]\nSigLevel = Optional TrustAll\nServer = file://%s\n\n' "$(repo_name generic)" "$(pool_dir generic)"
    printf '[core]\nInclude = /etc/pacman.d/mirrorlist\n\n[extra]\nInclude = /etc/pacman.d/mirrorlist\n\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n'
  } > "$out"
  echo "$out"
}

# ------------------------------------------------------------------ builder user
ensure_builder() {
  id "$BUILDER" >/dev/null 2>&1 || useradd -m "$BUILDER"
  if [[ ! -f /etc/sudoers.d/90-delaybuilder ]]; then
    echo "$BUILDER ALL=(ALL) NOPASSWD: /usr/bin/pacman" > /etc/sudoers.d/90-delaybuilder
    chmod 440 /etc/sudoers.d/90-delaybuilder
  fi
}
as_builder() { sudo -u "$BUILDER" -H bash -c "$*"; }

# ------------------------------------------------------------------ Arch versions
# version of a package in the Arch sync databases of this machine (run pacman -Sy first)
# (the value is everything after the first ": " - a version may contain a colon, 1:1.11.1-1)
arch_version() {
  pacman -Si "$1" 2>/dev/null | awk '
    { i = index($0, ":"); if (!i) next; k = substr($0, 1, i - 1); sub(/ +$/, "", k); v = substr($0, i + 2) }
    k == "Repository" { r = v }
    k == "Version" && !d && (r == "core" || r == "extra" || r == "multilib") { print v; d = 1 }'
}

# 1.2-3.1 -> 1.2-3   (the ".N" a level rebuild adds to pkgrel)
base_version() { sed -E 's/^(.*-[0-9]+)\.[0-9]+$/\1/' <<<"$1"; }

# curated list: "name levels [flags]" per line -> prints the lines without comments
curated_lines() { sed -e 's/\r$//' -e 's/#.*//' -e '/^[[:space:]]*$/d' "$REPO_ROOT/packages/repo/curated.list"; }
