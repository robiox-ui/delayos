#!/usr/bin/env bash
# Keeps the DelayOS repositories in step with Arch and with this repository (docs/packaging.md).
# Run as root on the build VM, by hand or from a timer.
#
#   tools/repo-update.sh --check                 only report what is out of date (exit 1 when something is)
#   tools/repo-update.sh [--level L[,L]|all]     rebuild what changed
#   tools/repo-update.sh --publish               ... and publish (needs DELAYOS_REPO_KEY and GITHUB_TOKEN)
#   tools/repo-update.sh --no-kernel             leave the kernels alone (they take 40 minutes each)
#
# What "changed" means:
#   content packages   their files in profile/airootfs or their PKGBUILD changed (content hash)
#   kernel             the version in kernel/linux-delayos/PKGBUILD is not the one in the pool
#   curated rebuilds   Arch's version of the package is not the one our level build was made from
#
# Update policy for the curated rebuilds: a level repository sits above [core]/[extra], so while it
# holds a package, pacman takes it from there, even when Arch has a newer release. A stale level
# build therefore holds its users back. This script rebuilds on every Arch release; when a rebuild
# FAILS, the stale package is taken out of the level repository, and those PCs get Arch's newer
# build with their next pacman -Syu (pkgrel N.1 sorts below Arch's next release).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=tools/repo-common.sh
. "$HERE/repo-common.sh"

CHECK=0; PUBLISH=0; KERNEL=1; LEVELSEL=all; BUILD_ARGS=()
while (( $# )); do
  case "$1" in
    --check) CHECK=1 ;;
    --publish) PUBLISH=1 ;;
    --no-kernel) KERNEL=0 ;;
    --level) LEVELSEL=${2:?}; shift ;;
    --level=*) LEVELSEL=${1#*=} ;;
    --no-chroot|--nocheck) BUILD_ARGS+=("$1") ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option $1" ;;
  esac
  shift
done
[[ $EUID -eq 0 ]] || die "Run as root: sudo $0"
mapfile -t SEL < <(expand_levels "$LEVELSEL")

# a new build VM (or a CI runner) starts without a pool: learn what is published
for l in "${LEVELS[@]}"; do
  pool_has_packages "$l" || { bash "$HERE/repo-publish.sh" --pull --level "$l" >/dev/null 2>&1 || true; }
done

pacman -Sy >/dev/null || die "pacman -Sy failed"

in_sel() { local l; for l in "${SEL[@]}"; do [[ $l == "$1" ]] && return 0; done; return 1; }
kernel_version() { ( set +eu; _major=; _minor=; pkgrel=; eval "$(tr -d '\r' < "$REPO_ROOT/kernel/linux-delayos/PKGBUILD" | grep -E '^(_major|_minor|pkgrel)=')"; echo "$_major.$_minor-$pkgrel" ); }

# ------------------------------------------------------------------ report
OUTDATED=0
STALE=()        # "level name": our build is older than Arch's release
report() {
  local name levels flags l av have kv p h
  printf '%-10s %-22s %-22s %-22s %s\n' REPO PACKAGE OURS WANTED STATE
  # content
  for p in $(bash "$HERE/content-pkgs.sh" list); do
    have=$(pool_version generic "$p"); h=$(bash "$HERE/content-pkgs.sh" hash "$p")
    if [[ -n $have && $h == "$(awk -v p="$p" '$1==p{print $2}' "$(pool_dir generic)/content-hashes.txt" 2>/dev/null)" ]]; then
      printf '%-10s %-22s %-22s %-22s %s\n' delayos "$p" "$have" "(tree)" ok
    else
      printf '%-10s %-22s %-22s %-22s %s\n' delayos "$p" "${have:--}" "(tree)" "REBUILD (files changed)"; OUTDATED=1
    fi
  done
  # kernels
  kv=$(kernel_version)
  for l in "${SEL[@]}"; do
    have=$(pool_version "$l" "linux-$(level_ksuffix "$l")")
    if [[ $have == "$kv" ]]; then printf '%-10s %-22s %-22s %-22s %s\n' "$(repo_name "$l")" "linux-$(level_ksuffix "$l")" "$have" "$kv" ok
    else printf '%-10s %-22s %-22s %-22s %s\n' "$(repo_name "$l")" "linux-$(level_ksuffix "$l")" "${have:--}" "$kv" "REBUILD"; (( KERNEL )) && OUTDATED=1; fi
  done
  # curated
  while read -r name levels flags; do
    av=$(arch_version "$name")
    for l in $(expand_levels "$levels"); do
      [[ $l == generic ]] && continue
      in_sel "$l" || continue
      have=$(pool_version "$l" "$name")
      if [[ -z $av ]]; then printf '%-10s %-22s %-22s %-22s %s\n' "$(repo_name "$l")" "$name" "${have:--}" "?" "NOT IN ARCH (check curated.list)"
      elif [[ -n $have && $(base_version "$have") == "$av" ]]; then printf '%-10s %-22s %-22s %-22s %s\n' "$(repo_name "$l")" "$name" "$have" "$av" ok
      else
        printf '%-10s %-22s %-22s %-22s %s\n' "$(repo_name "$l")" "$name" "${have:--}" "$av" "REBUILD"; OUTDATED=1
        [[ -n $have ]] && STALE+=("$l $name")
      fi
    done
  done < <(curated_lines)
}

report
if (( CHECK )); then
  (( OUTDATED )) && { echo; log "Something is out of date: run tools/repo-update.sh"; exit 1; }
  echo; log "Everything is up to date."; exit 0
fi
(( OUTDATED )) || { echo; log "Everything is up to date."; (( PUBLISH )) || exit 0; }

# ------------------------------------------------------------------ rebuild
rc=0
if (( OUTDATED )); then
  targets=(content)
  (( KERNEL )) && targets+=(pahole kernel)
  # content and pahole only exist in [delayos]; --level selects kernels and curated rebuilds
  bash "$HERE/repo-build.sh" "${BUILD_ARGS[@]}" --level "$LEVELSEL" "${targets[@]}" || rc=1
  lv=$(printf '%s\n' "${SEL[@]}" | grep -vx generic | paste -sd, || true)
  if [[ -n $lv ]]; then bash "$HERE/repo-build.sh" "${BUILD_ARGS[@]}" --level "$lv" curated || rc=1; fi

  # a level build that is still older than Arch's release (its rebuild failed) must not hold users back
  for s in "${STALE[@]}"; do
    read -r l name <<<"$s"
    have=$(pool_version "$l" "$name"); av=$(arch_version "$name")
    if [[ -n $have && $(base_version "$have") != "$av" ]]; then
      mapfile -t names < <(bsdtar -xOf "$(db_file "$l")" '*/desc' 2>/dev/null | awk -v b="$name" '/^%NAME%$/{getline n; next} /^%BASE%$/{getline x; if (x==b) print n}')
      (( ${#names[@]} )) || names=("$name")
      warn "$name@$l: rebuild failed; removing the stale $have from [$(repo_name "$l")] so PCs get Arch's $av"
      pool_remove "$l" "${names[@]}"
    fi
  done
fi

if (( PUBLISH )); then
  bash "$HERE/repo-publish.sh" --level "$LEVELSEL" || rc=1
else
  log "Not published. Review with tools/repo-build.sh list, then: DELAYOS_REPO_KEY=... GITHUB_TOKEN=... tools/repo-publish.sh"
fi
exit $rc
