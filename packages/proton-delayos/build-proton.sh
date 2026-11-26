#!/usr/bin/env bash
# Builds Proton for DelayOS from the public Proton-CachyOS sources (Valve Proton + the CachyOS/GE
# patch set), the way upstream documents it (BUILDING.md): inside Valve's Proton SDK container
# (Steam Linux Runtime), driven by podman. Run as a normal user with rootless podman; called by
# tools/repo-build.sh proton.
#
#   PROTON_TAG    source tag of github.com/CachyOS/proton-cachyos   (default: _srctag of the PKGBUILD)
#   PROTON_WORK   work directory, needs ~60 GB                       (default: ~/proton-build)
#   PROTON_JOBS   parallel jobs (default: cores, at most RAM/1.5 GB)
#   PROTON_MARCH  optional: compiler target of the Linux-side code, e.g. x86-64-v3
#                 (upstream default: -march=nocona -mtune=core-avx2, runs on every 64-bit CPU)
#
# Result: $PROTON_WORK/proton-delayos-<version>.tar  (the "redist" tree, top directory proton-delayos)
#
# What to expect on the DelayOS build VM (8 vCPU, 10 GB RAM): the first build compiles Wine twice
# (64-bit and 32-bit), DXVK, vkd3d-proton, GStreamer, FFmpeg and a Rust tool chain's worth of
# media code: 4 to 6 hours, ~15 GB of sources, ~40 GB of build tree, ~6 GB for the SDK image.
# 10 GB RAM is the floor: the script limits the job count to RAM/1.5 GB and the VM needs swap.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TAG="${PROTON_TAG:-cachyos-$(sed -n 's/^_srctag=//p' "$HERE/PKGBUILD" | head -n1)-slr}"
WORK="${PROTON_WORK:-$HOME/proton-build}"
VER="${TAG#cachyos-}"; VER="${VER%-slr}"
NAME="proton-delayos"

die() { printf 'build-proton: %s\n' "$*" >&2; exit 1; }
[[ $EUID -ne 0 ]] || die "run as a normal user (rootless podman), not as root"
command -v podman >/dev/null || die "podman is missing (pacman -S podman fuse-overlayfs)"
command -v git >/dev/null || die "git is missing"

mem_kb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
jobs=$(nproc); cap=$(( mem_kb / 1572864 )); (( cap < 1 )) && cap=1
(( jobs > cap )) && jobs=$cap
jobs="${PROTON_JOBS:-$jobs}"
avail_gb=$(( $(df -Pk "$(dirname "$WORK")" | awk 'NR==2{print $4}') / 1048576 ))
mkdir -p "$WORK"
[[ -d $WORK/build ]] || (( avail_gb >= 60 )) || die "only ${avail_gb} GB free below $(dirname "$WORK"); a Proton build needs about 60 GB"

if [[ ! -d $WORK/src/.git ]]; then
  echo "==> Cloning $TAG"
  git clone --filter=tree:0 --branch "$TAG" https://github.com/CachyOS/proton-cachyos "$WORK/src"
fi
cd "$WORK/src"
if [[ $(git describe --tags --exact-match 2>/dev/null || true) != "$TAG" ]]; then
  git fetch --filter=tree:0 origin "refs/tags/$TAG:refs/tags/$TAG"
  git checkout -f "$TAG"
fi
echo "==> Updating submodules (wine, dxvk, vkd3d-proton, gstreamer, ...)"
git submodule update --init --recursive --filter=tree:0 --jobs 4

mkdir -p "$WORK/build"; cd "$WORK/build"
if [[ ! -f Makefile ]]; then
  "$WORK/src/configure.sh" --container-engine=podman --build-name="$NAME"
fi
echo "==> make redist  (-j$jobs)   log: $WORK/build.log"
margs=()
[[ -n ${PROTON_MARCH:-} ]] && margs+=("HOST_CFLAGS=-O2 -march=$PROTON_MARCH")
make -j"$jobs" "${margs[@]}" redist 2>&1 | tee "$WORK/build.log" | grep -E --line-buffered '^(:: |make.*Error)|\] Error [0-9]' || true
[[ -f redist/proton && -f redist/version ]] || die "the build did not produce redist/ (see $WORK/build.log; grep -n '] Error [0-9]')"

rm -rf "$WORK/pkgroot"; mkdir -p "$WORK/pkgroot"
cp -a redist "$WORK/pkgroot/$NAME"
tar -C "$WORK/pkgroot" -cf "$WORK/$NAME-$VER.tar" "$NAME"
rm -rf "$WORK/pkgroot"
echo "==> $WORK/$NAME-$VER.tar"
