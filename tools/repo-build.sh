#!/usr/bin/env bash
# Builds packages for the DelayOS pacman repositories into the local pool (docs/packaging.md).
# Run as root on Arch Linux (the build VM). Nothing is signed or uploaded here: tools/repo-publish.sh.
#
#   tools/repo-build.sh [options] <target>...
#
# Targets
#   content        delayos-settings-base, -branding, -shell, -apps, -winboot, -keyring, -mirrorlist,
#                  -desktop   (arch "any", only into [delayos]; unchanged packages are skipped)
#   pahole         CachyOS-patched pahole (the kernel needs it)                     -> [delayos]
#   kernel         linux-delayos (generic) / linux-delayos-v3, -v4, -znver4         -> matching repo
#   curated        every package of packages/repo/curated.list, rebuilt per level   -> level repos
#   pkg:<name>     one Arch package (by pkgbase), rebuilt per level                  -> level repos
#   local:<dir>    a PKGBUILD directory below packages/                              -> [delayos]
#   proton         proton-delayos (hours, 60 GB disk: see packages/proton-delayos)   -> [delayos]
#   all            content pahole kernel curated
#   list           show what the pool holds
#
# Options
#   --level L[,L]  generic, v3, v4, znver4 or all. Default: generic for kernel, the levels named in
#                  curated.list for curated, v3 for pkg:<name>
#   --no-chroot    build with makepkg on this machine instead of a devtools clean chroot
#                  (containers without systemd-nspawn, e.g. GitHub Actions)
#   --force        rebuild even when the pool already has this version (pkgrel .N goes up)
#   --nocheck      skip check() (also automatic when this CPU cannot run the level)
#   --jobs N       parallel compile jobs (default: all cores)
#   --proton-repack   proton target: repackage CachyOS's released build instead of compiling
#
# Environment: DELAYOS_REPO_STATE (default /var/lib/delayos-repo), DELAYOS_KEYS (Secure Boot keys for
# delayos-sb-general, default /root/delayos-keys), DELAYOS_PKGVER (version of the content packages).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=tools/repo-common.sh
. "$HERE/repo-common.sh"

USE_CHROOT=1; FORCE=0; NOCHECK=0; LEVELSEL=""; PROTON_REPACK=0
TARGETS=()
while (( $# )); do
  case "$1" in
    --level) LEVELSEL=${2:?}; shift ;;
    --level=*) LEVELSEL=${1#*=} ;;
    --no-chroot) USE_CHROOT=0 ;;
    --force) FORCE=1 ;;
    --nocheck) NOCHECK=1 ;;
    --jobs) export DELAYOS_JOBS=${2:?}; shift ;;
    --proton-repack) PROTON_REPACK=1 ;;
    -h|--help) sed -n '2,31p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown option $1" ;;
    *) TARGETS+=("$1") ;;
  esac
  shift
done
(( ${#TARGETS[@]} )) || { sed -n '2,31p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

if [[ ${TARGETS[*]} == list ]]; then
  for l in "${LEVELS[@]}"; do
    echo "[$(repo_name "$l")]  $(pool_dir "$l")"
    db_list "$(db_file "$l")" | awk '{printf "  %-34s %s\n", $1, $2}'
  done
  exit 0
fi

[[ $EUID -eq 0 ]] || die "Run as root: sudo $0"
[[ -f /etc/arch-release ]] || die "This must run on Arch Linux"

WORK="$STATE/work"
SRC="$WORK/tree"          # a copy of the repository the builder user may read, LF line endings
FAILED=()

host_setup() {
  local need=(base-devel git libarchive pacman-contrib)
  (( USE_CHROOT )) && need+=(devtools)
  pacman -S --noconfirm --needed "${need[@]}" >/dev/null
  ensure_builder
  mkdir -p "$WORK" "$STATE/conf" "$POOL"
  ensure_pool generic
  # the builder reads the pool (pacman -U of its own results) and the chroot binds it
  chmod 755 "$STATE" "$POOL" "$WORK"
  rm -rf "$SRC"; mkdir -p "$SRC/profile"
  cp -a "$REPO_ROOT/packages" "$REPO_ROOT/tools" "$REPO_ROOT/kernel" "$SRC/"
  cp -a "$REPO_ROOT/profile/airootfs" "$REPO_ROOT/profile/profiledef.sh" "$SRC/profile/"
  find "$SRC/packages" "$SRC/tools" "$SRC/kernel" "$SRC/profile/profiledef.sh" -type f \
    \( -name PKGBUILD -o -name '*.sh' -o -name '*.list' -o -name '*.install' -o -name '*-mirrorlist' \
       -o -name 'delayos-trusted' -o -name 'delayos-revoked' -o -name '*.patch' -o -name '*.template' \) \
    -exec sed -i 's/\r$//' {} +
  chown -R "$BUILDER:$BUILDER" "$SRC"
}

ensure_chroot() { # $1 = level
  local level=$1 c="$STATE/chroot/$1" mk pc
  mk=$(gen_makepkg_conf "$level"); pc=$(gen_pacman_conf "$level")
  ensure_pool "$level"; ensure_pool generic
  if [[ ! -d $c/root ]]; then
    log "Creating the $level build chroot ($c)"
    mkdir -p "$c"
    mkarchroot -C "$pc" -M "$mk" "$c/root" base-devel
  else
    install -m644 "$pc" "$c/root/etc/pacman.conf"
    install -m644 "$mk" "$c/root/etc/makepkg.conf"
  fi
  # makepkg reads /etc/makepkg.conf.d/*.conf after makepkg.conf (Arch keeps RUSTFLAGS in rust.conf
  # there): our settings again, sorted last, so they are the ones that count
  install -Dm644 "$mk.dropin" "$c/root/etc/makepkg.conf.d/zz-delayos.conf"
}

# run makepkg for one PKGBUILD directory; the package files end up in that directory
run_makepkg() { # $1 = level, $2 = dir, rest = makepkg arguments
  local level=$1 dir=$2 mk binds=(); shift 2
  chown -R "$BUILDER:$BUILDER" "$dir"
  rm -f "$dir"/*.pkg.tar.zst
  if (( USE_CHROOT )); then
    ensure_chroot "$level"
    binds=(-D "$(pool_dir generic)")
    [[ $level != generic ]] && binds+=(-D "$(pool_dir "$level")")
    ( cd "$dir" && makechrootpkg -c -u -r "$STATE/chroot/$level" -U "$BUILDER" "${binds[@]}" -- "$@" )
  else
    mk=$(gen_makepkg_conf "$level")
    as_builder "cd '$dir' && makepkg --config '$mk' -s -f --noconfirm $*"
  fi
}

# every package a level build produced must carry that level's architecture
check_arch() { # $1 = level, $2.. = package files
  local level=$1 want f a; shift
  want=$(level_arch "$level")
  for f in "$@"; do
    a=$(pkg_field "$f" arch)
    [[ $a == any || $a == "$want" ]] || die "$(basename "$f") is '$a', expected '$want' (PACKAGECARCH override in makepkg.conf did not work)"
  done
}

built_files() { # $1 = dir -> the package files of this build, without debug packages
  find "$1" -maxdepth 1 -name '*.pkg.tar.zst' ! -name '*-debug-[0-9]*' | sort
}

# ------------------------------------------------------------------ content packages
dir_hash() { # packages that do not come out of profile/airootfs
  find "$1" -maxdepth 1 -type f ! -name '*.pkg.tar.zst' -print0 | sort -z | xargs -0 cat | sha256sum | cut -d' ' -f1
}

build_content() {
  local ver hashes p h old mk dir files
  ver="${DELAYOS_PKGVER:-$(date -u +%Y.%m.%d.%H%M)}"
  hashes="$(pool_dir generic)/content-hashes.txt"; touch "$hashes"
  mk=$(gen_makepkg_conf generic)
  DELAYOS_REPO_ROOT="$SRC" bash "$SRC/tools/content-pkgs.sh" check || die "packages/*/files.list do not cover profile/airootfs exactly (see above)"
  for p in delayos-keyring delayos-mirrorlist $(DELAYOS_REPO_ROOT="$SRC" bash "$SRC/tools/content-pkgs.sh" list) delayos-desktop; do
    dir="$SRC/packages/$p"
    if [[ $p == delayos-keyring && ! -s $dir/delayos.gpg ]]; then
      warn "delayos-keyring: no public key yet (tools/make-delayos-repo-key.sh). Skipped: nothing can be published without it."
      continue
    fi
    if [[ -f $dir/files.list ]]; then h=$(DELAYOS_REPO_ROOT="$SRC" bash "$SRC/tools/content-pkgs.sh" hash "$p"); else h=$(dir_hash "$dir"); fi
    old=$(awk -v p="$p" '$1==p{print $2}' "$hashes")
    if (( ! FORCE )) && [[ $h == "$old" && -n $(pool_version generic "$p") ]]; then
      log "$p: unchanged ($(pool_version generic "$p"))"
      continue
    fi
    log "$p: building $ver"
    chown -R "$BUILDER:$BUILDER" "$dir"; rm -f "$dir"/*.pkg.tar.zst
    # no chroot: these packages only copy files (arch "any"), nothing is compiled
    if ! as_builder "cd '$dir' && DELAYOS_REPO_ROOT='$SRC' DELAYOS_PKGVER='$ver' makepkg --config '$mk' -f -d --noconfirm"; then
      FAILED+=("$p"); warn "$p failed to build"; continue
    fi
    mapfile -t files < <(built_files "$dir")
    pool_add generic "${files[@]}"
    sed -i "/^$p /d" "$hashes"; echo "$p $h" >> "$hashes"
  done
}

# ------------------------------------------------------------------ pahole, local PKGBUILDs
build_local() { # $1 = directory name below packages/, rest = makepkg arguments
  local name=$1 dir files; shift
  dir="$SRC/packages/$name"
  [[ -f $dir/PKGBUILD ]] || die "packages/$name/PKGBUILD does not exist"
  log "$name -> [delayos]"
  run_makepkg generic "$dir" --skippgpcheck "$@" || { FAILED+=("$name"); warn "$name failed to build"; return 1; }
  mapfile -t files < <(built_files "$dir")
  pool_add generic "${files[@]}"
}

build_pahole() {
  local want; want=$(set +eu; . "$SRC/packages/pahole/PKGBUILD" >/dev/null 2>&1; echo "${epoch:+$epoch:}$pkgver-$pkgrel")
  if (( ! FORCE )) && [[ $(pool_version generic pahole) == "$want" ]]; then log "pahole: up to date ($want)"; return 0; fi
  build_local pahole --nocheck
}

# ------------------------------------------------------------------ kernel
kernel_version() { ( set +eu; _major=; _minor=; pkgrel=; eval "$(grep -E '^(_major|_minor|pkgrel)=' "$SRC/kernel/linux-delayos/PKGBUILD")"; echo "$_major.$_minor-$pkgrel" ); }

build_kernel() { # $1 = level
  local level=$1 suffix kopt dir want have files
  suffix=$(level_ksuffix "$level"); kopt=$(level_kopt "$level")
  want=$(kernel_version); have=$(pool_version "$level" "linux-$suffix")
  if (( ! FORCE )) && [[ $have == "$want" ]]; then log "linux-$suffix: up to date ($want)"; return 0; fi
  [[ -n $(pool_version generic pahole) ]] || build_pahole || die "the kernel needs the patched pahole"
  dir="$WORK/linux-$suffix"
  rm -rf "$dir"; mkdir -p "$dir"
  cp "$SRC/kernel/linux-delayos/"{PKGBUILD,config} "$dir/"
  # one PKGBUILD for every level: only the package suffix and the compiler target differ
  sed -i -e "s/^_pkgsuffix=delayos\$/_pkgsuffix=$suffix/" \
         -e "s/^: \"\${_processor_opt:=generic_v1}\"/: \"\${_processor_opt:=$kopt}\"/" "$dir/PKGBUILD"
  grep -q "^_pkgsuffix=$suffix\$" "$dir/PKGBUILD" && grep -q "_processor_opt:=$kopt}" "$dir/PKGBUILD" \
    || die "linux-$suffix: could not derive the PKGBUILD from kernel/linux-delayos/PKGBUILD"
  log "linux-$suffix $want (_processor_opt=$kopt) -> [$(repo_name "$level")]   this takes a while"
  # the kernel is compiled with clang by its own flags; the generic makepkg.conf is used for every
  # level so the package architecture stays x86_64 (the level is in the package name)
  run_makepkg generic "$dir" --skippgpcheck || { FAILED+=("linux-$suffix"); warn "linux-$suffix failed to build"; return 1; }
  mapfile -t files < <(built_files "$dir")
  pool_add "$level" "${files[@]}"
  [[ $level == generic ]] && build_sb_general "$dir"
  return 0
}

# Secure Boot (general key): the signed image belongs to exactly one linux-delayos build, so the
# two are always published together. Without the keys the package cannot be built here.
build_sb_general() { # $1 = directory with the linux-delayos package
  local keys="${DELAYOS_KEYS:-/root/delayos-keys}" kpkg gk dir files
  kpkg=$(find "$1" -maxdepth 1 -name 'linux-delayos-[0-9]*.pkg.tar.zst' | head -n1)
  if [[ ! -f $keys/delayos-general-signing.key || ! -f $keys/delayos-general-signing.crt || ! -f $keys/delayos-general-ca.crt ]]; then
    warn "No general Secure Boot keys in $keys: delayos-sb-general is NOT rebuilt for this kernel."
    warn "PCs that boot with Secure Boot on (hidden Windows) must not get this kernel: repo-publish.sh refuses to publish it while the pool holds an older delayos-sb-general."
    return 0
  fi
  pacman -S --noconfirm --needed sbsigntools grub openssl >/dev/null
  gk="/home/$BUILDER/.delayos-general-keys"; dir="$SRC/packages/delayos-sb-general"
  install -d -m700 -o "$BUILDER" -g "$BUILDER" "$gk"
  install -m600 -o "$BUILDER" -g "$BUILDER" "$keys"/delayos-general-signing.{key,crt} "$keys"/delayos-general-ca.crt "$gk/"
  log "delayos-sb-general for $(basename "$kpkg")"
  chown -R "$BUILDER:$BUILDER" "$dir"; rm -f "$dir"/*.pkg.tar.zst
  if as_builder "cd '$dir' && DELAYOS_SBG_KEY=$gk/delayos-general-signing.key DELAYOS_SBG_CERT=$gk/delayos-general-signing.crt DELAYOS_SBG_CA=$gk/delayos-general-ca.crt DELAYOS_KERNEL_PKG='$kpkg' makepkg -f --noconfirm"; then
    mapfile -t files < <(built_files "$dir")
    pool_add generic "${files[@]}"
  else
    FAILED+=(delayos-sb-general); warn "delayos-sb-general failed to build"
  fi
  rm -rf "$gk"
}

# ------------------------------------------------------------------ Arch packages rebuilt per level
# devtools' rule for the GitLab project name of a package
gitlab_name() { sed -E 's/([a-zA-Z0-9]+)\+([a-zA-Z]+)/\1-\2/g; s/\+/plus/g; s/[^a-zA-Z0-9_.-]/-/g; s/[_-]{2,}/-/g; s/^tree$/unix-tree/' <<<"$1"; }

build_arch_pkg() { # $1 = level, $2 = pkgbase, $3 = flags (comma separated: nocheck)
  local level=$1 name=$2 flags=",${3:-}," archver have n=1 dir tag args=(--skippgpcheck) files gotver
  archver=$(arch_version "$name")
  [[ -n $archver ]] || { warn "$name: not in the Arch repositories (core/extra/multilib)"; FAILED+=("$name@$level"); return 1; }
  have=$(pool_version "$level" "$name")
  if [[ -n $have && $(base_version "$have") == "$archver" ]]; then
    if (( ! FORCE )); then log "$name@$level: up to date ($have)"; return 0; fi
    n=$(( ${have##*.} + 1 ))
  fi
  dir="$WORK/$level/$name"
  rm -rf "$dir"; mkdir -p "$(dirname "$dir")"
  git clone -q "https://gitlab.archlinux.org/archlinux/packaging/packages/$(gitlab_name "$name").git" "$dir" \
    || { warn "$name: cannot clone the Arch packaging repository"; FAILED+=("$name@$level"); return 1; }
  # the release that is in the Arch repositories right now (the branch head may be ahead of it)
  tag=${archver//:/-}
  if ! git -C "$dir" -c advice.detachedHead=false checkout -q "$tag" 2>/dev/null; then
    warn "$name: no tag $tag in the packaging repository, using the branch head"
  fi
  chown -R "$BUILDER:$BUILDER" "$dir"
  gotver=$(as_builder "cd '$dir' && makepkg --printsrcinfo" | awk '$1=="epoch"{e=$3":"} $1=="pkgver"{v=$3} $1=="pkgrel"{r=$3} END{print e v "-" r}')
  [[ $gotver == "$archver" ]] || warn "$name: PKGBUILD is $gotver, the Arch repositories have $archver"
  # 1 -> 1.1: newer than Arch's build of the same release, older than Arch's next one
  sed -i -E "s/^pkgrel=([0-9]+)(\.[0-9]+)?[[:space:]]*\$/pkgrel=\1.$n/" "$dir/PKGBUILD"
  grep -qE "^pkgrel=[0-9]+\.$n\$" "$dir/PKGBUILD" || { warn "$name: could not set pkgrel"; FAILED+=("$name@$level"); return 1; }
  if (( NOCHECK )) || [[ $flags == *,nocheck,* ]] || ! cpu_runs_level "$level"; then args+=(--nocheck); fi
  cpu_runs_level "$level" || warn "$name@$level: this CPU cannot run $level code; a build that executes its own programs will fail"
  log "$name ${gotver%-*}-${gotver##*-}.$n -> [$(repo_name "$level")]  ($(level_march "$level"))"
  if ! run_makepkg "$level" "$dir" "${args[@]}"; then
    FAILED+=("$name@$level"); warn "$name@$level failed to build"; return 1
  fi
  mapfile -t files < <(built_files "$dir")
  (( ${#files[@]} )) || { FAILED+=("$name@$level"); warn "$name@$level produced no package"; return 1; }
  check_arch "$level" "${files[@]}"
  pool_add "$level" "${files[@]}"
}

build_curated() { # $1 = level filter ("" = every level a line names)
  local filter=$1 name levels flags l
  pacman -Sy >/dev/null
  while read -r name levels flags; do
    for l in $(expand_levels "$levels"); do
      [[ $l == generic ]] && continue
      [[ -z $filter || " $filter " == *" $l "* ]] || continue
      build_arch_pkg "$l" "$name" "${flags:-}" || true
    done
  done < <(curated_lines)
}

# ------------------------------------------------------------------ Proton
build_proton() {
  local dir="$SRC/packages/proton-delayos" tar files
  if (( PROTON_REPACK )); then
    log "proton-delayos: repackaging the CachyOS release (not our own build)"
    as_builder "cd '$dir' && DELAYOS_PROTON_REPACK=1 makepkg --config '$(gen_makepkg_conf generic)' -f -s --noconfirm" \
      || { FAILED+=(proton-delayos); return 1; }
  else
    pacman -S --noconfirm --needed podman git make rsync fuse-overlayfs >/dev/null
    log "proton-delayos: building Proton from source in the Steam Runtime SDK container (hours)"
    install -d -o "$BUILDER" -g "$BUILDER" "$WORK/proton"
    grep -q "^$BUILDER:" /etc/subuid 2>/dev/null || usermod --add-subuids 200000-265535 --add-subgids 200000-265535 "$BUILDER"
    as_builder "PROTON_WORK='$WORK/proton' ${DELAYOS_JOBS:+PROTON_JOBS=$DELAYOS_JOBS} bash '$dir/build-proton.sh'" \
      || { FAILED+=(proton-delayos); warn "the Proton build failed (log: $WORK/proton/build.log)"; return 1; }
    tar=$(find "$WORK/proton" -maxdepth 1 -name 'proton-delayos-*.tar' | sort | tail -n1)
    [[ -f $tar ]] || { FAILED+=(proton-delayos); return 1; }
    as_builder "cd '$dir' && DELAYOS_PROTON_TARBALL='$tar' makepkg --config '$(gen_makepkg_conf generic)' -f -d --noconfirm" \
      || { FAILED+=(proton-delayos); return 1; }
  fi
  mapfile -t files < <(built_files "$dir")
  pool_add generic "${files[@]}"
}

# ------------------------------------------------------------------ main
host_setup
sel=""; [[ -n $LEVELSEL ]] && sel=$(expand_levels "$LEVELSEL" | tr '\n' ' ')

run_target() {
  local t=$1 l
  case "$t" in
    content) build_content ;;
    pahole)  build_pahole || true ;;
    kernel)  for l in ${sel:-generic}; do build_kernel "$l" || true; done ;;
    curated) build_curated "${sel% }" ;;
    pkg:*)   pacman -Sy >/dev/null
             for l in ${sel:-v3}; do
               [[ $l == generic ]] && { warn "pkg: targets are level rebuilds; [delayos] takes Arch's own build"; continue; }
               build_arch_pkg "$l" "${t#pkg:}" "" || true
             done ;;
    local:*) build_local "${t#local:}" || true ;;
    proton)  build_proton || true ;;
    all)     for l in content pahole kernel curated; do run_target "$l"; done ;;
    *) die "unknown target '$t'" ;;
  esac
}
for t in "${TARGETS[@]}"; do run_target "$t"; done

echo
for l in "${LEVELS[@]}"; do
  n=$(db_list "$(db_file "$l")" | wc -l)
  (( n )) && log "[$(repo_name "$l")] $n packages in $(pool_dir "$l")"
done
if (( ${#FAILED[@]} )); then
  warn "Failed: ${FAILED[*]}"
  exit 1
fi
log "Done. Publish with: DELAYOS_REPO_KEY=... GITHUB_TOKEN=... tools/repo-publish.sh"
