# CachyOS build, toolchain and packaging optimizations

This document records what we found in the CachyOS GitHub repos (snapshots taken 2026-11-25) and how it applies to BrookOS. It covers compiler flags, LTO, PGO, BOLT, AutoFDO and Propeller, ISA-level repositories, the pacman fork, kernel build mechanics, gaming packages and the build/repo infrastructure.

Sibling documents in this folder cover the kernel patch set (`kernel-patches.md`, `linux-cachyos.md`), system tuning (`system-tuning.md`) and the desktop/gaming stack (`gaming-desktop.md`). This file concentrates on **how things are built and shipped**.

All repo content was treated as untrusted data. It was read, never executed. Files were downloaded as `codeload.github.com` tarballs. Forks were inspected through the GitHub API, using about 20 requests in total.

---

## 0. TL;DR for BrookOS

1. **Package flags by ISA level.** These are the real repo builder flags, from `CachyOS/docker-makepkg`:
   - **Common to all four levels:**
     - `-O3`
     - `-fno-plt -fexceptions`
     - Arch's hardening set: `_FORTIFY_SOURCE=3`, `-fstack-clash-protection`, `-fcf-protection`
     - `LTOFLAGS="-flto=auto"`
     - `OPTIONS=(... lto !debug ...)`
     - zstd `--ultra -20`
   - **Per level:**
     - Generic: `-march=x86-64 -mtune=generic`
     - v3: `-march=x86-64-v3 -mtune=generic -mpclmul`, plus `GOAMD64=v3`
     - v4: `-march=x86-64-v4 -mtune=generic -mpclmul`, plus `GOAMD64=v4`
     - znver4: `-march=znver4 -mpclmul` with no `-mtune`, plus `GOAMD64=v4`
   - **Rust:** `-C opt-level=3 -C target-cpu=<level> -Clink-arg=-z -Clink-arg=pack-relative-relocs`. The znver4 builder still uses `target-cpu=x86-64-v4` for Rust.
2. **CachyOS does not use frame pointers.** Arch's devtools v3 config adds `-fno-omit-frame-pointer`; CachyOS's builders do not.
3. **Package architecture is set with `PACKAGECARCH`.** The `CachyOS/pacman` fork adds this makepkg variable, which stamps packages `x86_64_v3` or `x86_64_v4` while `CARCH` stays `x86_64`. That way PKGBUILD `arch=(x86_64)` checks keep working.
4. **Pacman detects the CPU level itself.** With `Architecture = auto`, the fork's `lib/libalpm/cpu_capabilities.c` runs CPUID/XGETBV and accepts `x86_64`, `x86_64_v2`, `x86_64_v3` and `x86_64_v4` packages accordingly.
   - The repo installer script picks `znver4`, `v4` or `v3` repos with `ld.so --help` (ISA levels) plus `gcc -march=native` (Zen 4/5 detection).
   - It then inserts `[cachyos-<lvl>] [cachyos-core-<lvl>] [cachyos-extra-<lvl>] [cachyos]` **above** `[core]`/`[extra]`.
5. **Kernel build.** The kernel is built with **clang + ThinLTO by default** (`_use_llvm_lto=thin`, `CC=clang LD=ld.lld LLVM=1 LLVM_IAS=1`), with `-O3` (`CC_OPTIMIZE_FOR_PERFORMANCE_O3`), 1000 Hz, full NO_HZ and full preempt.
   - AutoFDO is a two-pass workflow: `CONFIG_AUTOFDO_CLANG` plus `CLANG_AUTOFDO_PROFILE=`.
   - Propeller is a third pass: `CONFIG_PROPELLER_CLANG` plus `CLANG_PROPELLER_PROFILE_PREFIX=`.
   - Source is the pre-patched, signed `CachyOS/linux` release tarball `cachyos-<ver>-<rel>.tar.gz`.
6. **Toolchain packages are PGO'd.**
   - LLVM: 3-stage clang IR-PGO plus ThinLTO (fat objects). Training builds LLVM, a PCH build and a Linux kernel.
   - GCC: `profiledbootstrap` + `bootstrap-lto`.
   - binutils: `--enable-pgo-build=lto`.
   - Python 3.14: `-O3`, PGO with an extended test suite, LTO and the tail-call interpreter.
   - Others with PGO: bash, zsh, sqlite (ClickBench), lz4 (clang IR-PGO), xz, zstd CLI, nginx, nodejs, php, ripgrep, svt-av1, valkey.
   - zlib-ng replaces zlib system-wide.
7. **Gaming packages are not ISA-tuned.**
   - Mesa ships at Arch settings: `!lto`, `--optimization 2`, plus a gamescope FPS-limiter patch.
   - Wine and Proton-native are deliberately generic (`-march=nocona -mtune=core-avx2`; Wine adds `-mno-avx -mno-avx2 -mno-avx512f`).
   - Proton is shipped mainly as an **SLR** (Steam Linux Runtime) build.
   - NVIDIA is open-module DKMS. `dkms` depends on `clang lld llvm` so modules build for clang/LTO kernels.

---

## 1. makepkg.conf: exact flags per architecture

### 1.1 Repo build containers (`CachyOS/docker-makepkg`)

There are four images: `docker-makepkg` (generic), `-v3`, `-v4` and `-znver4`. Each image `COPY`s its `makepkg.conf`, `rust.conf`, `pacman.conf`, `ccache.conf` and mirrorlists.

| Key | generic | x86-64-v3 | x86-64-v4 | znver4 |
|---|---|---|---|---|
| `CARCH` | `x86_64` | `x86_64` | `x86_64` | `x86_64` |
| `PACKAGECARCH` | (unset) | `x86_64_v3` | `x86_64_v4` | `x86_64_v4` |
| `-march` | `x86-64` | `x86-64-v3` | `x86-64-v4` | `znver4` |
| `-mtune` | `generic` | `generic` | `generic` | (none, implied znver4) |
| extra | none | `-mpclmul` | `-mpclmul` | `-mpclmul` |
| `GOAMD64` | (unset) | `v3` | `v4` | `v4` |
| Rust `target-cpu` | `x86-64` | `x86-64-v3` | `x86-64-v4` | `x86-64-v4` |

The common part, verbatim from the v3 image (the other images only differ in `-march`/`-mtune`):

```bash
CFLAGS="-march=x86-64-v3 -mtune=generic -O3 -pipe -fno-plt -fexceptions \
        -Wp,-D_FORTIFY_SOURCE=3 -Wformat -Werror=format-security \
        -fstack-clash-protection -fcf-protection -mpclmul"
CXXFLAGS="$CFLAGS -Wp,-D_GLIBCXX_ASSERTIONS"
LDFLAGS="-Wl,-O1 -Wl,--sort-common -Wl,--as-needed -Wl,-z,relro -Wl,-z,now \
         -Wl,-z,pack-relative-relocs"
LTOFLAGS="-flto=auto"
MAKEFLAGS="-j$(nproc)"
NINJAFLAGS="-j$(nproc)"
DEBUG_CFLAGS="-g"
BUILDENV=(!distcc color !ccache check !sign)
OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge !debug lto !autodeps)
INTEGRITY_CHECK=(sha256)
COMPRESSZST=(zstd -c -T0 --ultra -20 -)
PKGEXT='.pkg.tar.zst'
PKGDEST=/home/notroot/packages
```

**rust.conf** (`/etc/makepkg.conf.d/rust.conf`):

```bash
RUSTFLAGS="-C opt-level=3 -C target-cpu=x86-64-v3 -Clink-arg=-z -Clink-arg=pack-relative-relocs"
DEBUG_RUSTFLAGS="-C debuginfo=2"
```

**ccache.conf:** `cache_dir = /home/notroot/.buildcache` and `sloppiness = locale, time_macros`. ccache is disabled in BUILDENV, but legacy build scripts mount a persistent ccache volume.

**Notes and gotchas**

- **The znver4 builder keeps Rust at `target-cpu=x86-64-v4`** rather than `znver4`. Presumably this is deliberate, for portability within the v4 directory.
- **znver4 packages are published as `x86_64_v4`** (`PACKAGECARCH="x86_64_v4"`). The public dashboard maps `*-znver4` repos to the `x86_64_v4` arch directory.
- **The images differ from Arch in these ways:**
  - `-O3` instead of `-O2`
  - no `-fno-omit-frame-pointer -mno-omit-leaf-frame-pointer`
  - `!debug`, so no debug packages from these images
  - zstd `--ultra -20` instead of Arch's `-19` (generic Arch is `zstd -c -T0 -`)
- **v4/znver4 images mark `[cachyos]` as `SigLevel = Optional TrustAll`** (container convenience). BrookOS should not copy that.
- **Each image's `run.sh` handles a few environment switches:**
  - `LLVM_BOLT` prepends `/home/notroot/llvm/bin` to `PATH`, so builds use a BOLTed LLVM from the builder.
  - `USE_PARU` builds with `paru -U` (for AUR deps).
  - `CHECKSUMS` runs `updpkgsums`.
  - Otherwise it runs `makepkg -sc --skipinteg --noconfirm --log || true`. Note that `--skipinteg` and `|| true` swallow failures.

### 1.2 Default end-user `/etc/makepkg.conf` (shipped by CachyOS `pacman`)

This is the file CachyOS installs on user systems. It is for local AUR builds, not the repos.

```bash
CFLAGS="-march=native -O3 -pipe -fno-plt -fexceptions \
        -Wp,-D_FORTIFY_SOURCE=3 -Wformat -Werror=format-security \
        -fstack-clash-protection -fcf-protection"
CXXFLAGS="$CFLAGS -Wp,-D_GLIBCXX_ASSERTIONS"
LDFLAGS="-Wl,-O1 -Wl,--sort-common -Wl,--as-needed -Wl,-z,relro -Wl,-z,now -Wl,-z,pack-relative-relocs"
LTOFLAGS="-flto=auto"
MAKEFLAGS="-j$(nproc)"
NINJAFLAGS="-j$(nproc)"
OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge !debug lto !autodeps)
COMPRESSZST=(zstd -c -T0 -9 -)    # fast local compression
#PACKAGECARCH="x86_64"
```

`/etc/makepkg.conf.d/rust.conf` sets `RUSTFLAGS="-C opt-level=3 -C target-cpu=native"`.

### 1.3 `CachyOS/devtools` (clean-chroot builds)

This is a fork of Arch devtools. The `config/makepkg/x86_64_v3.conf` here is Arch's own v3 config:

```bash
CARCH="x86_64_v3"
CFLAGS="-march=x86-64-v3 -mtune=generic -O2 -pipe -fno-plt -fexceptions \
        -Wp,-D_FORTIFY_SOURCE=3 -Wformat -Werror=format-security \
        -fstack-clash-protection -fcf-protection \
        -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer"
OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge debug lto)
COMPRESSZST=(zstd -c -T0 --ultra -20 -)
```

The rust.conf for this config is `RUSTFLAGS="-C force-frame-pointers=yes -C link-arg=-Wl,--icf=safe"`.

Other pieces of the fork:
- `setarch-aliases.d/x86_64_v3` maps to `x86_64`.
- The pacman configs `extra-x86_64_v3.conf` etc. use `Architecture = x86_64_v3 x86_64`.

The CachyOS `devtools` package is upstream Arch devtools 1.5.3 plus three CachyOS commits for `makechrootpkg`:
- a paccache flag
- `-V` to build in a private network namespace
- quieter networkd output

`pkg-manage-util` drives these chroots with a swappable `--makepkg-conf` (Section 7).

### 1.4 Per-package compiler overrides

Many CachyOS PKGBUILDs switch to the LLVM stack per package, even though the repo default is GCC:
- `pacman`, `sqlite`, `lz4`, `nginx`, `valkey`, `limine` and `llvm-propeller` set `CC=clang CXX=clang++ AR=llvm-ar NM=llvm-nm RANLIB=llvm-ranlib`.
- The Rust tools `chwd`, `scx-manager` and `cachyos-kernel-manager` use:

```bash
RUSTFLAGS="-Cembed-bitcode -C opt-level=3 -Ccodegen-units=1 -Clinker=clang -C link-arg=-flto -Clink-arg=-fuse-ld=/usr/bin/ld.lld"
```

`pacman` itself uses cross-language ThinLTO:

```bash
CFLAGS+=" -fno-semantic-interposition -flto=thin"
RUSTFLAGS+=" -Cembed-bitcode -Clinker-plugin-lto -Clinker=clang -C link-arg=-flto=thin"
```

Common recurring tweaks across packages:

| Tweak | Where it is used | Why |
|---|---|---|
| `-fno-semantic-interposition` | zlib-ng, svt-av1, python313, php, nodejs, pacman | Lets the compiler inline and optimize calls within shared libraries |
| `-ffat-lto-objects` | python, zstd, sdl2, nvidia-settings | Keeps static archives usable by non-LTO consumers |
| `-O2` → `-O3` | python, python311/313, java, mutter | Higher optimization for hot paths |
| `_FORTIFY_SOURCE=3` → `2` | sqlite, pacman, nodejs | Avoids breakage around `malloc_usable_size` |

---

## 2. Repository layout and pacman changes

### 2.1 Repos and pacman.conf

`cachyos-repo.sh` (from `cachyos-repo-add-script`) works as follows:

1. Imports key `F3B607488DB35A47` and `pacman -U`s `cachyos-keyring`, `cachyos-mirrorlist`, `cachyos-v3-mirrorlist`, `cachyos-v4-mirrorlist` and the **CachyOS pacman** package.
2. Detects the CPU:
   - `check_supported_isa_level()` runs `/lib/ld-linux-x86-64.so.2 --help | grep "x86-64-v4 (supported, searched)"`.
   - `check_supported_znver45()` runs `gcc -march=native -Q --help=target | grep march | grep -E '(znver4|znver5)'`. Note that this makes the installer depend on gcc.
3. Uses gawk scripts to rewrite `/etc/pacman.conf`, keeping a backup at `/etc/pacman.conf.bak`:
   - Inserts the repo block **before the first existing repo section**.
   - Rewrites any `Architecture = x86_64 [x86_64_v3 [x86_64_v4]]` line to `Architecture = auto`.

The result on a Zen 4/5 machine:

```ini
[options]
Architecture = auto

[cachyos-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos-core-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos-extra-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist

[core]
Include = /etc/pacman.d/mirrorlist
[extra]
Include = /etc/pacman.d/mirrorlist
[multilib]
Include = /etc/pacman.d/mirrorlist
```

The v4 and v3 variants follow the same pattern: `[cachyos-v4] [cachyos-core-v4] [cachyos-extra-v4]` and `[cachyos-v3] [cachyos-core-v3] [cachyos-extra-v3]`, each followed by `[cachyos]`.

**How the repos divide up:**
- `cachyos-core-*` and `cachyos-extra-*` are **full rebuilds of Arch `core`/`extra`** at that ISA level.
- `cachyos-<lvl>` holds CachyOS's own packages built at that level.
- `[cachyos]` is the generic x86_64 CachyOS repo.
- `cachyos-testing-v3` exists as well; the remover handles it.

**Version ordering.** Rebuilt Arch packages get a `.1` pkgrel suffix (e.g. `godot-4.4.1-4.1-x86_64_v4`), as seen in the `repo-manage-util` test SQL. That way the CachyOS rebuild sorts newer than Arch's `-4` and wins even if repo order were changed.

**Removal.** `cachyos-repo.sh --remove` strips the sections, then runs `pacman -Suuy` (downgrade to Arch), `pacman -S core/pacman` and `pacman -Qqn | pacman -S -`, and finally removes the keyring and mirrorlists.

**Mirrorlists.** The `cachyos-v3-mirrorlist` entries look like:

```
Server = https://cdn77.cachyos.org/repo/$arch_v3/$repo
Server = https://cdn.cachyos.org/repo/$arch_v3/$repo
```

`$arch_v3` is not a separate variable. pacman substitutes `$arch` with the first architecture (`x86_64`), and the literal `_v3` that follows produces the `x86_64_v3` directory. This is our inference from pacman's `$arch` substitution. The znver4 repos reuse the v4 mirrorlist and server directory.

**Container configs.** The configs in `CachyOS/docker` and `docker-makepkg` use explicit lists rather than `auto`: `Architecture = x86_64 x86_64_v3` or `x86_64 x86_64_v3 x86_64_v4`, with `ParallelDownloads = 10` (the shipped default is `5`) and `DisableDownloadTimeout`.

### 2.2 CachyOS pacman fork (`CachyOS/pacman`, branch `release/7.1.x`, packaged at commit `663941f`)

**Architecture handling**

- **`lib/libalpm/cpu_capabilities.c`** exports `alpm_option_get_physical_architectures()`, which returns `uname -m` plus each ISA level the CPU supports:
  - **Probing.** It runs `cpuid` leaves 0, 1 and 7.0, plus `xgetbv`:
    - It checks for OS-enabled AVX state (`(mask & 6) == 6`).
    - AVX-512 features are only accepted if `(mask & 224) == 224` (opmask/ZMM state is enabled).
  - **Levels it reports:**
    - `x86_64_v2` requires SSSE3, SSE4.1 and SSE4.2. Note that it does **not** check POPCNT or CX16, unlike glibc.
    - `x86_64_v3` requires v2 plus AVX and AVX2. It does **not** check FMA, BMI1/2, F16C, LZCNT or MOVBE.
    - `x86_64_v4` requires v3 plus AVX512F, VL, BW, CD and DQ.
  - On aarch64 it returns only `uname -m`.
- **`src/pacman/conf.c` `config_add_architecture()`.** For `"auto"`, it adds every physical arch from the function above, so `Architecture = auto` expands to e.g. `x86_64 x86_64_v2 x86_64_v3 x86_64_v4`.

  > **BrookOS note:** use a stricter detector (glibc's `ld.so --help` list or the full psABI feature set). Otherwise some odd CPUs, or VMs with partial CPUID masking, could be offered v3 packages they cannot run.

- **makepkg `PACKAGECARCH`:**
  - Added to `makepkg.conf.in` as `PACKAGECARCH="@CARCH@"`, to the config linter and to `config.sh`.
  - `makepkg.sh` does `[[ "x${PACKAGECARCH}" != "x" ]] && CARCH="${PACKAGECARCH}"` at package-creation time, and the signature code does the same.
  - The result: packages build with `CARCH=x86_64`, so PKGBUILD `arch=()` checks and `$CARCH` paths are unchanged, but they are **named and stamped** `x86_64_v3` or `x86_64_v4`.
  - A TODO notes that arch aliasing (v4 → v3 → v2 → x86_64) in the PKGBUILD linter is still missing.

**Database and repo tooling**

- **New sync-DB format.** `repo-add` is rewritten in Rust (`scripts/repo-add`, edition 2024, release profile `lto=true, codegen-units=1, opt-level=3, panic=abort, strip`). It embeds a **SQLite `pacman.db`** inside the repo database archive.
  - libalpm (`be_sync.c`, `HAVE_LIBSQLITE`) loads package metadata from SQLite instead of thousands of `desc` files, which makes sync-DB parsing faster.
  - SQLite is linked **statically**. The PKGBUILD builds sqlite from source with FTS/RTREE and `-DSQLITE_*` options; `static_sqlite.patch` changes meson to `cc.find_library(... static : true)`.
- **Update notice** (`pacman: add update message/notice`): pacman can display a notice file from the repo, e.g. for manual-intervention news.
- **Network isolation.** `libalpm: isolate scriptlets and hooks from the network` (2026-06). Upstream pacman 7's `DownloadUser = alpm` sandboxing is also kept.
- **Other:** `makepkg: add rw permissions to /pkg directory on fail`, and the "Revert makepkg: remove libdepends and libprovides" commit (CachyOS keeps libdepends/libprovides).

**Packaging patches** (from the CachyOS-PKGBUILDS `pacman` package):
- `78cd453.patch` adds the `PrettyProgressBar` option, which uses Fira Code, Iosevka or JuliaMono progress glyphs. `pacutils` is patched to parse it.
- `disable-always-stale.patch` (repo-add meson target).
- Two upstream backports.
- pacman itself is built with clang ThinLTO plus Rust linker-plugin LTO (§1.4).

**Shipped `/etc/pacman.conf` defaults:**
- `Architecture = auto`
- `ParallelDownloads = 5`
- `DownloadUser = alpm`
- `CheckSpace`
- `SigLevel = Required DatabaseOptional`

The CachyOS repo sections are added by the installer, not by the package.

### 2.3 Mirrors and P2P

**`rate-mirrors`** (used via `cachyos-rate-mirrors`) is a Rust mirror ranker with a CachyOS target:
- It reads the dashboard mirror JSON from `https://cachyos.org/archlinuxmirrorlist/api/cachyos-mirrors`, with fields `country_code`, `url` and `delay_seconds`.
- It uses tier comments, `--max-delay 86400` and the test file `x86_64/cachyos/cachyos.files`.
- With `--arch auto` it emits `Server = <url>$arch/$repo`.
- How it works:
  - Speed-tests 2 mirrors per country.
  - Hops between countries along internet-exchange and submarine-cable neighbours, with `--max-jumps=7`.
  - Re-tests the top 5 sequentially.
  - Stops a test early once the stddev/mean of the last 40 chunks is ≤ 0.0625.

**`mirrorlist-proxy-experiment`** is a Go caching proxy (5-minute refresh, serves stale data on failure) for Arch mirror status and the CachyOS mirror list.

**`pacman2pacman`** provides BitTorrent package downloads as an `XferCommand`:
- It falls back to HTTP after a 45 s stall.
- `.db` files are always fetched over HTTP.
- Seeding is handled by `pacman2pacman-upload`.

---

## 3. Kernel: clang + ThinLTO + AutoFDO + Propeller

The main `linux-cachyos` repo was not in the assigned list. We fetched only `linux-cachyos/linux-cachyos/PKGBUILD`, because the COPR specs and deb script reference it; it is the kernel 7.3.6 PKGBUILD. Details of the patches and config are in `linux-cachyos.md` and `kernel-patches.md`.

### 3.1 Source

- **Source tarball.** The source is `https://github.com/CachyOS/linux/releases/download/cachyos-7.3.6-1/cachyos-7.3.6-1.tar.gz{,.asc}`, a **pre-patched, GPG-signed release tarball** produced by `tag-release.sh` in the `CachyOS/linux` fork.
  - Signing keys: Eric Naim `E18447AC…4B8B63C4` and Peter Jung `E8B9AA39…57F654FE`.
  - The tarball replaces the old "vanilla tarball + many patches" approach. Only optional extras are still applied as patches: BORE, prjc, hardened, rt-i915, `dkms-clang.patch`, and NVIDIA module patches.
- **Config** comes from `linux-cachyos/config`.

### 3.2 Build defaults and switches

| Option | Default | Effect |
|---|---|---|
| `_cachy_config` | `yes` | `scripts/config -e CACHY` (enables the "Cachy sauce" Kconfig defaults) |
| `_cpusched` | `cachyos` | `-e SCHED_BORE` (BORE on EEVDF); other choices are `bore`, `bmq` (`SCHED_ALT`+`SCHED_BMQ`), `hardened`, `eevdf`, `rt` and `rt-bore` (`PREEMPT_RT`) |
| `_use_llvm_lto` | `thin` | `LTO_CLANG_THIN`; also `thin-dist` (`LTO_CLANG_THIN_DIST`, distributed ThinLTO), `full` or `none` |
| `_processor_opt` | empty = native | `-d GENERIC_CPU -d MZEN4 -e X86_NATIVE_CPU`; `zen4` → `MZEN4`; `generic_v1..v4` → `GENERIC_CPU` + `X86_64_VERSION=N` |
| `_cc_harder` | `yes` | `-d CC_OPTIMIZE_FOR_PERFORMANCE -e CC_OPTIMIZE_FOR_PERFORMANCE_O3` |
| `_HZ_ticks` | `1000` | also 100/250/300/500/600/750 (CachyOS adds the extra HZ choices in Kconfig) |
| `_tickrate` | `full` | `NO_HZ_FULL_NODEF NO_HZ_FULL CONTEXT_TRACKING` |
| `_preempt` | `full` | `-e PREEMPT -d PREEMPT_LAZY` (the comment says lazy performed worse) |
| `_hugepage` | `always` | `TRANSPARENT_HUGEPAGE_ALWAYS` |
| `_tcp_bbr3` | `no` | when on: BBR default, `DEFAULT_FQ` |
| `_use_kcfi` | `no` | `-e CFI` |
| `_build_zfs`, `_build_nvidia_open`, `_build_nvidia_580xx`, `_build_r8125` | `no` | build out-of-tree modules **inside** the kernel package, using the same `BUILD_FLAGS` |
| `_autofdo`, `_autofdo_profile_name`, `_propeller`, `_propeller_profiles` | `no` | see 3.3 |
| `_localmodcfg` | `no` | `make LSMOD=$XDG_DATA_HOME/modprobed-db/modprobed.db localmodconfig` |

Other things the PKGBUILD does:
- Enables the DRM panic QR code (`DRM_PANIC_SCREEN_QR_CODE`, URL `https://panic.archlinux.org/panic_report#`).
- **Settings applied only in CI:** `CC_OPTIMIZE_FOR_SIZE` and `DEBUG_INFO_REDUCED`, both to make CI builds faster.

The LTO toolchain wiring is:

```bash
makedepends+=(clang llvm lld 'pahole>=1:1.32-2')   # pahole --lang_exclude fix: BTF for Rust modules with LTO
BUILD_FLAGS=(CC=clang LD=ld.lld LLVM=1 LLVM_IAS=1)
make "${BUILD_FLAGS[@]}" -j"$(nproc)" all
make -C tools/bpf/bpftool vmlinux.h feature-clang-bpf-co-re=1   # ships vmlinux.h for sched-ext/BPF
```

Packaging details:
- `options=('!strip' '!debug' '!lto')`
- Modules are installed with `ZSTD_CLEVEL=19 ... INSTALL_MOD_STRIP=1 DEPMOD=/doesnt/exist`.
- The `-headers` package depends on `clang llvm lld` for LTO kernels, so DKMS uses the same compiler.
- `provides=(... NTSYNC-MODULE VHBA-MODULE ADIOS-MODULE V4L2LOOPBACK-MODULE KSMBD-MODULE WIREGUARD-MODULE ...)`

### 3.3 AutoFDO and Propeller workflow

This is documented in the PKGBUILD and on the CachyOS blog (`cachyos.org/blog/2411-kernel-autofdo/`).

1. Build with `_autofdo=yes _build_debug=yes`. This sets `scripts/config -e AUTOFDO_CLANG`, which adds `-fdebug-info-for-profiling -mllvm -enable-fs-discriminator` and keeps the unstripped `vmlinux`.
2. Boot that kernel and run a representative workload while recording with `perf record` using LBR or AMD BRS.
3. Convert the profile with `create_llvm_prof` (CachyOS packages it as `autofdo-bin`) into an AutoFDO profile.
4. Rebuild with `_autofdo_profile_name=<file>`, which passes `BUILD_FLAGS+=(CLANG_AUTOFDO_PROFILE=$srcdir/<file>)`.
5. Optionally run a Propeller pass: build with `_propeller=yes` (`-e PROPELLER_CLANG`), profile again, and convert:

   ```
   create_llvm_prof --binary=.../vmlinux --profile=propeller.data --format=propeller \
     --propeller_output_module_name --out=propeller_cc_profile.txt --propeller_symorder=propeller_ld_profile.txt
   ```

6. Rebuild with `_propeller_profiles=yes`, which passes `CLANG_PROPELLER_PROFILE_PREFIX=$srcdir/propeller`.

Related commits in `CachyOS/linux`:
- `kbuild: AutoFDO: Disable Profi (-fno-sample-profile-use-profi)` (7.3/fixes)
- `kbuild: rust: support stabilized flag -Cprofile-sample-use for Rust >= 1.100` (7.3/cachy)
- `rust: Allow BTF generation with Rust + LTO`
- `Kbuild: Enable LLVM machine pipeliner`
- `kbuild: Add GCC SMS-based modulo scheduling`
- `Kconfig: Restore CONFIG_OPTIMIZE_FOR_PERFORMANCE_O3`
- `arch/x86: Add x86_64 ISA and Zen4 compiler optimizations` (provides `X86_64_VERSION`, `MZEN4` and `X86_NATIVE_CPU`)
- Branches `6.10/autofdo`, `6.11/autofdo`, `6.17/autofdo` and `6.15/thin-dist-lto` show this work being developed over time.

Supporting packages in CachyOS-PKGBUILDS:
- `autofdo-bin` repackages Google's `create_llvm_prof` 0.30.1. Packaging bug: the `/usr/bin/autofdo` symlink points into `$pkgdir`.
- `llvm-propeller` builds `generate_propeller_profiles` with clang.
- `binutils` reverts two strip commits because "AutoFDO packaging is currently broken, since strip is failing".
- `pahole` carries LTO+Rust BTF fixes.

### 3.4 `CachyOS/linux` fork: branches (summary only; the tree was not downloaded)

The fork has 336 branches and its default branch is `7.0/cachy`.

**Branch scheme.** Branches are named `<kver>/<topic>`, and `<kver>/base` merges every topic branch for that version on top of the latest stable release. For example, `7.3/base` is "Linux 7.3.6" plus merges of `amd-iommu, bbr3, cachy, fixes, hdmi, sched, snd-codecs, t2, vesa-dsc-bpp, zram`. Release tags `cachyos-<ver>-<rel>` are cut from `base`.

| Topic branch(es) | What it carries |
|---|---|
| `X/cachy` | the "Cachy sauce" (listed below) |
| `X/sched` | upstream EEVDF/sched backports |
| `X/fixes` | hardware quirks and backports (amd-pstate, i915 RC6, BT IDs, HID, AutoFDO Profi disable) |
| `X/bbr3` | TCP BBRv3 |
| `X/t2` | Apple T2 Mac support |
| `X/handheld` | handheld device support (Steam Deck, Ally and similar) |
| `X/hdmi` | HDMI improvements |
| `X/vesa-dsc-bpp` | VESA DSC bpp fixes |
| `X/snd-codecs` | audio codec quirks |
| `X/amd-pstate`, `X/amd-iommu` | AMD power-state and IOMMU work |
| `X/zram`, `X/zswap` | memory compression work |
| `X/mglru`, `7.4/mglru-fg` | multi-gen LRU tuning |
| `X/rt` | PREEMPT_RT |
| `X/crypto` | crypto (AES-XTS and similar) |
| `X/ntsync` | NTSync, in older versions before it was upstreamed |
| `X/asus`, `X/lenovo-wmi` | laptop platform drivers |
| `X/cgroup-vram` | VRAM cgroup support |
| experimental branches | `7.0/gaming-sched`, `7.1/gaming-sched-2`, `7.0/panther-sched`, `7.1/drm-fair`, `7.1/preempt-ipi`, `7.1/sched-cluster`, `7.0/cache-aware`, `6.11/amd-cache-optimizer`, `6.13/amd-tlb-broadcast`, `6.15/prjc`, `6.10/sched-ext`, `6.13/pksm`, `6.7/uksm` |

Contents of `7.3/cachy` (CachyOS-only commits on top of 7.3-rc1):

**Kconfig and compiler options**
- `Kconfig: Add CONFIG_CACHY`
- `Kconfig.hz` with additional timer frequencies
- `x86_64 ISA and Zen4 compiler optimizations`
- `Restore CONFIG_OPTIMIZE_FOR_PERFORMANCE_O3`
- GCC SMS modulo scheduling
- LLVM machine pipeliner
- `Kconfig.preempt`: PREEMPT_RT no longer requires EXPERT

**Scheduler**
- `CACHY: sched/fair: Tweak EEVDF for interactivity`
- `sched/core: add some branch hints based on gcov analysis` (Colin Ian King)
- `list: Mark some functions as __always_inline`
- `readdir: unlikely hint`

**Memory management**
- `vm_swappiness` raised to 100
- `VM_READAHEAD_PAGES` raised to 256K
- `mm/swap_state: Disable swap-in readahead`
- `CACHY: mm: lru-gen: Protect the working set of the last 100 jiffies`
- proactive compaction disabled
- watermark boosting disabled
- background reclaim of hugepages enabled

**Block I/O**
- the ADIOS I/O scheduler (v3.3.0)
- `CACHY: Use BFQ for SQ devices and mq-deadline for MQ devices`

**x86 and timekeeping**
- `CACHY: Disable split lock mitigation by default`
- `ACPI: processor: Disable bus master check for AMD` (Sultan Alsawaf)
- Steven Noonan's TSC series: `tsc=directsync`, save/restore TSC across sleep, and related fixes

**Drivers**
- ACS override
- VHBA (CD emulation)
- v4l2loopback in-tree
- `AMD_PRIVATE_COLOR` exposed in Kconfig (for HDR in gamescope/KWin)
- `intel-pstate "enable" parameter`
- Intel remapped NVMe (VMD) support
- `evdev call_rcu`

**Security and build tooling**
- sysctl to disable unprivileged `CLONE_NEWUSER`
- `tag-release.sh` (GPG-signed tarballs)
- `kbuild: add resolve_btfids to pacman PKGBUILD`

### 3.5 LTS kernels (`CachyOS/linux-cachyos-lts`)

This repo is **stale**. It holds 5.15.20 PKGBUILDs from about 2022, one per scheduler: `bmq, bore, cacule, pds, tt, cacule-rdb`.

How they differ from the current kernel PKGBUILD:
- **GCC is the default compiler.** `_use_llvm_lto=` is empty; LLVM mode sets `LLVM=1 LLVM_IAS=1`, `CC=clang LD=ld.lld` and `-d LTO_NONE`. Clang CFI is optional. PGO is commented out as "not working".
- **CPU optimization works differently:**
  - `auto-cpu-optimization.sh` parses `gcc -Q -march=native --help=target` and flips `CONFIG_M<MARCH>` in `.config`. This is the forerunner of `X86_NATIVE_CPU`.
  - `configure` offers an interactive menu of 62 `-march` targets, including `GENERIC_CPU2/3/4` (from the graysky patch).
- **Configuration defaults:**
  - 750 Hz
  - NUMA disabled
  - MQ-deadline and Kyber disabled
  - `-O3`
  - BBR2 as the default TCP congestion control
  - performance governor as default
  - LRNG
  - MGLRU (`NR_LRU_GENS 7`)
  - page-table-check
  - Anbox binder/ashmem
  - winesync/futex2
  - `KERNEL_ZSTD_LEVEL 19`
- **Patches** are pulled from `ptr1337/kernel-patches/5.15`.
- **Build pipeline.** `script.sh` builds every variant 4× in `pttrr/docker-makepkg[-v3]` (generic, v3 via `sed GENERIC_CPU=y→GENERIC_CPU3=y`, v3 + LLVM LTO, then back to generic) with a ccache volume.

The current LTS kernel is built from `linux-cachyos/linux-cachyos-lts` (not in scope). The COPR spec references kernel 6.18.65 for LTS.

### 3.6 Debian/Ubuntu builder (`linux-cachyos-deb`, `linux-cachyos-for-deb`)

**Note on scope:** `linux-cachyos-for-deb` contains only LICENSE, CONTRIBUTING and CODE_OF_CONDUCT. There is no code in it.

`linux-cachyos-deb/cachyos-deb.sh` (maintainer Laio O. Seman) is an interactive whiptail TUI:

1. `apt install`s the build dependencies.
2. Scrapes kernel.org for the latest kernel and downloads the vanilla tarball.
3. Downloads `linux-cachyos/config` and patches from `cachyos/kernel-patches/<maj.min>`:
   - `all/0001-cachyos-base-all.patch`
   - plus one scheduler patch: `sched-ext`, `bore-cachy`, `rt`, `bore-cachy-rt` or `hardened`
4. Configures:
   - CPU: `-d GENERIC_CPU -e CONFIG_M<detected>`, detected via `gcc -march=native` (ZNVER4 → `MZEN4`)
   - `-e LTO_CLANG_THIN` or `-e LTO_CLANG_FULL`
   - HZ, NR_CPUS (default 320), THP `always`, MGLRU, `-O3`, performance governor and NUMA
5. Builds with plain `make -j$(nproc)`, then hand-rolls `.deb` packages: `dpkg-deb --build` with a handwritten `DEBIAN/control`; `custom-kernel-<ver>` holds `/boot/vmlinuz-<ver>` and modules, `custom-kernel-headers-<ver>`. An optional ZFS package can be added.

**How it differs from the Arch PKGBUILD:**
- vanilla tarball plus patches instead of the pre-patched `CachyOS/linux` tarball
- GCC by default (`_llvm_lto_selection="none"`)
- no AutoFDO or Propeller
- no DKMS or `-headers` build tree; headers come only from `make headers_install`, so DKMS modules **cannot** build against it
- no initramfs or bootloader integration
- 500 Hz and nohz_full defaults

**Bugs worth avoiding** if BrookOS writes a similar tool:
- The case statements test `$_cpusched_config` (never set) instead of `$_cpusched_selection`, so the scheduler Kconfig is never enabled.
- The tick-type cases are `perodic|idle|full`, but the values are `periodic|nohz_idle|nohz_full`, so they never match.
- The preempt default `preempt` matches no case.
- LTO is selected without `CC=clang LLVM=1`, so a GCC build silently ignores it.
- `--with-linux=$(LINUX_DIR)` is a command substitution, not a variable.
- The ZFS `lib/modules/.../extra` directory is never created.
- `/tmp/kernel-modules` is reused across builds.

### 3.7 Fedora COPR (`copr-linux-cachyos`)

These RPM specs follow the same pattern as the Arch PKGBUILD:
- **Source:** the `CachyOS/linux` tag tarball plus `linux-cachyos/config`.
- **Configuration:**
  - `scripts/config -e CACHY -e SCHED_BORE`
  - `--set-val X86_64_VERSION %{_x86_64_lvl}`: 3 for `kernel-cachyos`, 2 for `-server` and `-lts` (3 on EPEL10)
  - `_hz_tick` 1000; 300 for server
  - `-e LTO_CLANG_THIN` in the `-lto` specs, with `%define _lto_args CC=clang CXX=clang++ LD=ld.lld LLVM=1 LLVM_IAS=1`
- **Fedora specifics:**
  - SELinux LSM order (`lockdown,yama,integrity,selinux,bpf,landlock`)
  - IMA secure-boot options
  - `symvers.zst`
  - `devel-matched` meta package
  - a 90 MB stub initramfs to reserve `/boot` space
- **akmods-clang.patch** (Eric Naim). This is a useful idea:

  ```bash
  if grep -q CONFIG_CC_IS_CLANG=y "/lib/modules/${kver}/build/.config"; then
      export CC=clang CXX=clang++ LD=ld.lld LLVM=1 LLVM_IAS=1
  fi
  ```

  BrookOS's DKMS should auto-detect a clang-built kernel the same way. Arch dkms does this already; CachyOS adds `clang lld llvm` to dkms depends.
- Prebuilt NVIDIA modules in COPR were dropped in February 2026 because the release schedules did not line up.

---

## 4. Toolchain packages (CachyOS-PKGBUILDS `toolchain/`, `llvm/`)

### 4.1 LLVM 23 (`llvm`): 3-stage PGO + ThinLTO

- **Stage 0.** The host GCC builds clang, lld, the llvm tools and compiler-rt profile, with `LLVM_TARGETS_TO_BUILD=Native`.
- **Stage 1.** An instrumented clang is built with `-DLLVM_BUILD_INSTRUMENTED=IR -DLLVM_PROFILE_DATA_DIR=...`. `LLD_IN_TEST=1` makes lld return from `main` so it writes its profile.
- **Training workloads:**
  1. Compile core LLVM and clang libraries (`LLVMSupport ... LLVMX86CodeGen clangAST clangSema clangCodeGen`).
  2. A PCH build (`CMAKE_DISABLE_PRECOMPILE_HEADERS=OFF`), which trains the AST deserializer.
  3. `make x86_64_defconfig vmlinux` of Linux 7.2.10 with stage-1 clang and lld, which covers C, asm and a large LTO-style link.
  4. Merge with `llvm-profdata merge`.
- **Final build.** Stage-0 clang builds with `-DLLVM_PROFDATA_FILE=... -DLLVM_ENABLE_LTO=Thin -DLLVM_ENABLE_FATLTO=ON -DLLVM_USE_LINKER=lld`, `-g1`, and `options=('staticlibs' '!lto')`. makepkg's GCC-style LTO is disabled because it breaks `typeids.test`.
- **Configure and packaging:**
  - `LLVM_LINK_LLVM_DYLIB`, `CLANG_LINK_CLANG_DYLIB`, `LLD_BUILD_SHARED`
  - `LLVM_USE_PERF=ON`
  - `LLVM_DISTRIBUTION_COMPONENTS` filtering (Gentoo-style; drops static libs)
  - projects `clang;clang-tools-extra;lld;lldb;polly;bolt`
  - runtimes `compiler-rt;openmp;offload;libcxx;libcxxabi`
  - libclc, and the wasi runtimes
- **CachyOS-specific patch `llvm-libstdcxx-export-compat.patch`.** With PGO+ThinLTO, `std::string::_M_mutate/_M_replace/_M_append` get fully inlined and disappear from libLLVM, which breaks `librustc_driver`. The patch adds explicit instantiations. **Any distro that PGO-builds libLLVM needs this.**
- BOLT is built and packaged (`llvm-bolt`, `perf2bolt`, `merge-fdata`), but clang itself is not BOLTed in the PKGBUILD. docker-makepkg's `LLVM_BOLT` switch suggests a BOLTed toolchain is used on the builders.
- **`CachyOS/llvm-pkgbuilds`** is an older Arch-derived set (19.1.4). It has no PGO and contains:
  - `rebuild-order.txt` for LLVM soname bumps: llvm → compiler-rt → clang → lld → … → rust → mesa → lib32-mesa → …
  - an experimental clang-built monorepo `llvm-full` 15.0.7 with kCFI backport patches
  - a BOLT-enabled `llvm+bolt`
  - rust 1.72 with `codegen-units-std = 1` for cross-language ThinLTO

### 4.2 GCC 16

- **Configure:** `--with-build-config=bootstrap-lto --enable-bootstrap` plus Arch's options, with languages `ada,c,c++,d,fortran,go,lto,m2,objc,obj-c++,rust,cobol`.
- **Build:** `make -O STAGE1_CFLAGS="-O3" BOOT_CFLAGS="$CFLAGS" BOOT_LDFLAGS="$LDFLAGS" LDFLAGS_FOR_TARGET="$LDFLAGS" profiledbootstrap`. This is a **PGO + LTO bootstrapped compiler** (Arch uses a plain `bootstrap`).
- **Patches:**
  - `gcc-16-52cd02606b90.patch`: x86 generic-tune branch-mispredict cost (+3), which favours if-conversion; claimed +12% on 544.nab_r.
  - `gcc-16-comp-goto-profile.patch`: fixes computed-goto edge counts under `-fprofile-use`. Without it, CPython's eval loop was treated as cold. **This is essential for PGO-built interpreters** (Python, PHP).
- `libgccjit` is built separately with `--enable-host-shared`, so the main compilers avoid the PIC penalty.

### 4.3 glibc 2.44

- `options=(staticlibs !lto)`
- FORTIFY is stripped from glibc's own CFLAGS.
- Configure: `--enable-kernel=6.1 --enable-multi-arch --enable-bind-now --enable-stack-protector=strong --enable-systemtap --enable-cet --enable-sframe`.
- **Tunables.** `/etc/tunables.conf` (`include /etc/tunables.conf.d/*.conf`) plus a commented `shstk.conf` provide a system-wide glibc tunables mechanism, with per-binary `[proc:/usr/bin/app]` stanzas applied with `ldconfig -X`.
- `clearlinux.patch` (64-byte aligned `sqrt/exp/exp2`, `-mprefer-vector-width` per file) is shipped **but not applied**. That is dead code.

### 4.4 binutils 2.47

- Configure: `--enable-pgo-build=lto`, i.e. binutils' own PGO+LTO self-build, plus gold, BPF target, debuginfod and deterministic archives.
- Reverts two strip commits (the AutoFDO packaging issue).
- The fat-IR strip fix patch is shipped but not applied.

### 4.5 Other optimized packages

| Package | Compiler | PGO training / LTO | Notes |
|---|---|---|---|
| python 3.14 | GCC | `--enable-optimizations --with-lto`, `PROFILE_TASK='-m test --pgo-extended -x test_socket'`, failures tolerated (`profiled-build.patch`) | `-O3 -ffat-lto-objects`, `--with-computed-gotos --with-tail-call-interp`; BOLT disabled (cpython#124948) |
| python313 | GCC | default PGO + LTO | `-O3 -fno-semantic-interposition`, `altinstall` |
| python311 (aur-derived) | GCC | `--enable-optimizations --with-lto=no` | `-O3 -ffat-lto-objects` |
| bash 5.3 | GCC | `-fprofile-generate -fprofile-update=atomic -fprofile-partial-training`, training = `make check` and loadables | |
| zsh 5.9.2 | GCC | trained with `make test`; `-fprofile-use -Wno-error=coverage-mismatch` | **bug:** missing `\` in `./configure`, so the options are lost |
| sqlite 3.54 | clang | IR-PGO trained on **ClickBench** (5M rows of `hits.csv`, every query ×3); `-fprofile-use ... -flto=thin` | |
| lz4 1.11 | clang | IR-PGO: datagen text/low/high-entropy data plus 32 MB of `libLLVM.so`, all levels, legacy `-l` (initramfs) mode, fullbench | |
| xz 5.8 | GCC | `add-pgo.patch` `pgo-build` target, trained with `make check` | |
| zstd 1.5.7 | GCC | `zstd-pgo`: `-b19i1 -b16i1 -b9i2 -b -b7i2 -b5` (CLI only, not libzstd) | `-ffat-lto-objects`; `_optimize_znver4` → `-DXXH_ENABLE_AUTOVECTORIZE=ON` (AVX-512 XXH64 on Zen 4) |
| zlib-ng 2.3 | GCC | none (runtime dispatch) | **`zlib-ng-compat` replaces `zlib`** system-wide; `-fno-semantic-interposition` |
| nginx | clang | IR-PGO from 10k HTTP GETs | `!lto` |
| nodejs 26 | GCC | `--enable-pgo-generate` → full test suite plus a crypto/JSON/Buffer/zlib JS workload → `--enable-pgo-use`; `--enable-lto` | |
| php 8.5 | GCC | `make prof-gen`, bench.php ×1/2/4/8 → `prof-use` | opcache on by default, `huge_code_pages=1`, Clear Linux hugepage patch; `CXXLAGS` typo |
| ripgrep | rustc | `-Cprofile-generate`, hyperfine over a kernel tree, `-Cprofile-use` | fat LTO, `codegen-units=1`, `panic=abort` |
| svt-av1 | GCC | upstream `-DSVT_AV1_PGO=ON` + `RunPGO` | `-fno-semantic-interposition` |
| valkey | clang | `-fprofile-instr-generate` + valkey-benchmark | `LDFLAGS=-fuse-ld=lld` drops hardening flags |
| go 1.27 | | `_optimize_v3/_v4` → `GOAMD64=v3/v4` for the toolchain | `go.env` forced back to `GOAMD64=v1` for user builds |
| openjdk 27/21/17 | GCC | `link-time-opt` JVM feature (27 only) | `-O3` HotSpot; `CARCH x86_64_v3/v4` → `x86_64` mapping |
| openblas-v3 / -v4 | GCC | none | `TARGET=HASWELL` / `TARGET=SKYLAKEX`, `DYNAMIC_ARCH=ON`, OpenMP, 256 threads |
| paru | rustc | | LTO only on `CARCH == x86_64`; **v3/v4 builds silently lose LTO** |

**PGO conclusions for BrookOS:**
- CachyOS uses **instrumented PGO only**. There is no CS-IRPGO and no sampling AutoFDO for userspace.
- The gcc comp-goto patch and the LLVM libstdc++ export patch are prerequisites for that approach.
- **CI never compiles** (see §6). Bugs like the zsh configure one slip through, so BrookOS should build packages in CI, not just run `--nobuild`.

---

## 5. Gaming and graphics packaging

Details are in `gaming-desktop.md` and `system-tuning.md`. The build-relevant findings:

**Mesa**
- **`mesa` / `lib32-mesa` 26.3:** Arch-derived.
  - `options=(!lto)`; the comment says GCC LTO segfaults in `si_llvm_optimize_module`.
  - `--optimization 2 -D b_ndebug=true -D gallium-drivers=all -D video-codecs=all`
  - all Vulkan drivers, rusticl, `intel-rt`, and dynamic system LLVM
  - The ISA-level flags come from the v3/v4/znver4 makepkg.conf.
- **Patch `gamescope-fps-limiter.patch`** ("STEAMOS: Dynamic swapchain override for gamescope limiter", DRI3 only). It lets gamescope's frame limiter work for GL apps.
- **`mesa-git`:**
  - Built from Frogging-Family TKG with `_compiler=gcc`, `_lto=false`, `-Db_pgo=use` support, and `--buildtype release`.
  - `PKGBUILDS-git-v3` builds it as `mesa-git` (`mesa-git.patch` only renames the TKG pkgnames) in the v3 docker image with `IGNORE_ARCH=1`.
- The old `llvm-pkgbuilds/mesa` shows earlier choices: `gallium-nine`, `d3d12` and `intel-clc`.

**Proton and Wine**
- **`proton-cachyos-native`:**
  - Built from CachyOS/proton-cachyos with no container, against host libraries.
  - Flags: `CFLAGS="-O3 -march=nocona -mtune=core-avx2"`, `RUSTFLAGS="-C opt-level=3 -C target-cpu=nocona"`, `options=(!lto ...)`.
  - Bundles DXVK plus low-latency variants of dxvk/vkd3d, vkd3d-proton, dxvk-nvapi, nvcuda/nvenc/nvml/nvoptix shims, ZLUDA/hipwine, pyroveil, vkbasalt, the low-latency layer, protonfixes, OpenXR and an ffmpeg build.
  - Autoloads `ntsync` via `modules-load.d`.
- **`proton-cachyos-slr`** repackages the upstream SLR-container build. It is the one `cachyos-gaming-meta` installs (for anti-cheat compatibility).
- **`wine-cachyos`(`-opt`):**
  - Flags: `-O2 -march=nocona -mtune=core-avx2 -mfpmath=sse` plus `-mno-avx -mno-avx2 -mno-avx512f -fvect-cost-model=cheap -fipa-pta -fwrapv -fno-strict-aliasing`, cross-linked with `--file-alignment,4096`, no LTO.
  - A pure WoW64 build (`--enable-archs=x86_64,i386`) with Wayland, gstreamer and ffmpeg.
  - The `-opt` variant installs into `/opt/wine-cachyos`, so it can coexist with system wine.

  **Lesson:** CachyOS deliberately does *not* build Windows-facing PE code with high ISA levels.

**NVIDIA**
- `nvidia-utils` 620.x ships **`nvidia-open-dkms` only**:
  - dkms.conf gets parallel jobs (`nproc`) and `IGNORE_PREEMPT_RT_PRESENCE=1`.
  - CachyOS patches: DSC RC tables, Bigscreen Beyond, kernel 7.3 sysfs.
- The `CachyOS/open-gpu-kernel-modules` fork has `<ver>-cachyos` branches (560 to 615). Peter Jung's patches on `560-cachyos` are:
  - "Make modeset and fbdev default enabled"
  - "Do not error on unknown CPU Type and add Zen5 support"
  - "Add IBT support"
  - fbdev fix and 6.12 compat (`PageSwapCache`, `output_poll_changed`)
  - "nvkms: Sanitize & trim ELD product name strings"
  - silence event assert

  Newer `*-cachyos` branches appear to track NVIDIA releases. The patches have moved to `kernel-patches/<ver>/misc/nvidia/*`, which the kernel PKGBUILD applies when building modules in-tree.
- **580xx legacy branch:** closed and open DKMS, the atomic-modeset-default patch, and `NVreg_PreserveVideoMemoryAllocations=1`.
- **Extras:**
  - `/usr/lib/environment.d/50-nvidia-cuda-disable-perf-boost.conf`: `CUDA_DISABLE_PERF_BOOST=1`
  - application profiles that limit VRAM reuse for browsers and Discord, and allow full clocks for recorders
  - DLSS DLLs installed into `/usr/lib/nvidia/wine/`
- **`dkms` 3.4.5 depends on `clang lld llvm`**, so modules build for clang/LTO kernels.

**ZFS**
- The `CachyOS/zfs` fork has `zfs-<ver>-cachyos` branches. These are upstream release branches plus early **new-kernel compat** backports (e.g. `zfs-2.4.5-cachyos`: "Linux 7.3 compat: META", `bvec_iter` and `inode_operations.create` changes, `cpu_feature_enabled()`), plus older per-kernel branches (`6.11`, `6.12-zfs`, `7.0`).
- `zfs-utils` builds with `CFLAGS+=" -fno-tree-vectorize"` (OpenZFS #13605/#13620).
- The kernel PKGBUILD can build ZFS in-tree with `KERNEL_LLVM=1` for LTO kernels.

**Other gaming-relevant builds**
- **`mutter`:** `-O3 -fno-semantic-interposition -Wl,-Bsymbolic-functions` plus an 11-part **tearing / async page-flip** series.
- **`power-profiles-daemon`:** patch that switches scx_loader modes (power-saver/balanced/performance → `POWER_SAVE`/`AUTO`/`GAMING`).
- **`scx-scheds`:** cargo workspace with `!lto`.
- **`bpftune-gaming`:** `-march=native` replaced with `-O3` for BPF objects.
- **`lsfg-vk`:** clang + IPO.
- **`gamescope`:** stock Arch; lib32 WSI layer.
- **Handheld stack:** `steam-jupiter-stable`, `steamos-manager`, `jupiter-hw-support` with CachyOS patches.
- **`cachyos-gaming-meta`:** installs `kernel.split_lock_mitigate=0`; the kernel also defaults the split-lock mitigation off.
- **`cachyos-aur-derived`** carries gaming tooling (heroic built against system electron, sunshine with NVENC and an auto-detected CUDA gcc, ryujinx, obs-vkcapture plus lib32, xone/xpadneo DKMS, protonplus, protonup-qt, faugus, mangojuice, hhd). It has **no ISA-flag changes** apart from python311 `-O3` and sdl2 fat LTO.

---

## 6. Build and repo infrastructure

```
 PKGBUILD git repos (CachyOS-PKGBUILDS, cachyos-aur-derived, linux-cachyos, PKGBUILDS-git[-v3])
        |  nvchecker/pkgctl bots open update PRs (every 4-6 h); namcap + makepkg --nobuild CI
        v
 Build farm: "Standard Builder" (builder-api.cachyos.org) + "Zen4 Builder" (builder-api-1)
   march x86-64-v3 / x86-64-v4 / znver4 (+ generic); docker-makepkg-<lvl> or clean chroot
   (pkg-manage-util -> mkarchroot/makechrootpkg with swapped makepkg.conf), ccache volume,
   per-process timeout watchdog
        v
 repo-manage-util: sign + repo-add (Rust, SQLite db), route *-debug pkgs to debug repos,
   backups, soname-breakage check (check-rebuild), AUR topo build order, promote testing->stable,
   PostgreSQL index (advisory locks) -> api-service (C++ userver) -> public-dashboard
        v
 Mirrors: build.cachyos.org/repo/<arch>/<repo>/lastupdate baseline; tier-1/2 mirrors,
   CDN77/Cloudflare R2/Tebi CDN; rate-mirrors client; lag shown on dashboard.cachyos.org
```

**Repo and build tools**
- **`builder-dashboard`** is an internal Next.js UI with:
  - package status (QUEUED/BUILDING/DONE/FAILED/LATEST/SKIPPED/CANCELLED)
  - single and bulk rebuild endpoints `rebuild/{march}/{repository}/{pkgbase}`, where repositories are `core`/`extra`
  - build logs `logs/{march}/{pkgbase}.log`
  - build-time statistics
  - audit logs and RBAC
  - a custom package submission flow (allowlisted git owners)
- **`public-dashboard`** shows arches `any, x86_64, x86_64_v3, x86_64_v4` and the 10 CachyOS repos plus core/extra, with mirror lag tracking. It caches with SWR, using an in-process LRU and a Redis Sentinel L2.
- **`repo-manage-util`** has one TOML profile per repo, e.g. `add_params = ["--sign","--include-sigs","--verify"]`, `require_signature`, `debug_repo` and `reference_repo`. Commands:
  - `update` and `sync`
  - `move-pkgs`
  - `check-rebuild`: ELF `DT_NEEDED` scan against all `.files` DBs
  - `aur`: topological order with cycle detection
- **`pkg-manage-util`** is a Rust wrapper around clean-chroot builds. It runs:

  ```
  makechrootpkg -c -D ... -- --config <makepkg.conf> -m --noprogressbar --syncdeps --noconfirm --holdver --skippgpcheck --clean --cleanbuild
  ```

  It also has a `/proc` watchdog that SIGTERMs hung test processes.
- **`db-wrap`** is a header-only C++23 libpqxx/Boost.PFR wrapper used by these services.

**CI**
- **`CachyOS-PKGBUILDS` CI:**
  - `makepkg --syncdeps --nobuild --skippgpcheck` on changed PKGBUILDs, in the `cachyos/cachyos` container. It never compiles.
  - namcap validation (fails on E-level findings).
  - nvchecker every 4 h, which opens or closes `out-of-date` issues.
- **`cachyos-aur-derived` CI:**
  - every 6 h runs `pkgctl version check`, then opens `bot/update/<pkg>-<ver>` PRs (max 10 per run)
  - optional `makepkg --verifysource`
  - **risk flags** in PR bodies: changed `.install`, changed sources, new `SKIP` checksums, added `curl|wget|systemctl|useradd|setcap|rm -rf` lines
- **`PKGBUILDs` / `PKGBUILDS-git` / `PKGBUILDS-git-v3`:**
  - Weekly self-hosted runners build -git packages in docker-makepkg(-v3) with `IGNORE_ARCH=1` and a ccache volume, then run `repo-manage-util move-pkgs-to-repo` or `repoctl update -P cachyos-v3`.
  - Packages include gamescope-git, dxvk/vkd3d-proton-mingw-git, mold-git, lact-git and mesa-git.
- **`pkgbuild-action`** is a GitHub Action fork:
  - adds the `[cachyos]` repo and key
  - sets `MAKEFLAGS="-j$(nproc) -l$(nproc)"`
  - optional ccache
- **`docker`** builds the `cachyos/cachyos`, `-v3`, `-v4` and distrobox images daily from `archlinux:base-devel`, squashed `FROM scratch`.

**Boot and install**
- **`mkinitcpio`** is a tracking mirror of upstream v40 with **no CachyOS changes**:
  - default zstd `-T0`
  - `MODULES_DECOMPRESS`, so modules and firmware are decompressed and the whole image is compressed once
- **`dracut-cachyos`** is CachyOS's dracut integration: hostonly plus fallback, optional UKI, and a btrfs snapshot overlay.
- **`arch-install-scripts`** is upstream; CachyOS added only a ShellCheck workflow.
- **`systemd-boot-manager`** (`sdboot-manage`):
  - ALPM hooks regenerate loader entries on kernel install and remove
  - default `LINUX_OPTIONS="nowatchdog quiet splash"` in CachyOS's packaging
  - `/usr/lib/sdboot-manage.conf.d/` drop-ins (used by the handheld package to add `amd_iommu=off amdgpu.ppfeaturemask=0xffffffff`)
- **`sbctl`** has no visible CachyOS changes.
- **`shim-review`** is an unfilled template: CachyOS has not submitted a shim.
  - Requirements a submission must meet: shim 16.1, signing by Microsoft UEFI CA 2023 only, RSA ≥ 4096 for embedded certs, SBAT generation ≥ 5 for GRUB, and reproducible builds.
  - CachyOS instead ships an **EAC-signing** path: its own CA in `/var/lib/sbctl/keys/custom/db`, `systemd-boot-cachyos-signed`, and `linux-cachyos-eac`.

**Repos with no build relevance**
- **`mkosi`** is a pure mirror: 0 commits ahead and 64 behind systemd/mkosi.
- **`linux-raspberrypi`** is a stale mirror of `raspberrypi/linux` (default `rpi-6.6.y`, last push July 2024) with no visible CachyOS changes. CachyOS does not appear to ship an ARM kernel from it.
- **`cacule-cpu-scheduler`** is a historical archive of Hamad Marri's CacULE/RDB patches (5.3 to 6.0) and of `apply_suggested_configs.sh`. That script disables PSI, MEMCG, RETPOLINE, debug and lockup detectors for latency, which is not advisable for a general distro.

---

## 7. Recommendations for BrookOS

1. **Adopt the CachyOS ISA layout.** Use three optimized repo sets (v3, v4, znver4) plus generic, with `*-core`/`*-extra` full rebuilds and a `.1` pkgrel suffix.
   - Build them with the docker-makepkg flag sets in §1.1.
   - Consider keeping Arch's frame pointers (`-fno-omit-frame-pointer -mno-omit-leaf-frame-pointer`) for profiling. The cost is about 1–2%, and profiles are needed for AutoFDO and BOLT.
   - Consider `target-cpu=znver4` for Rust in the znver4 set.
2. **Pacman.** Port the `cpu_capabilities.c` + `Architecture = auto` + `PACKAGECARCH` changes.
   - Tighten v2/v3 detection to the full psABI feature lists (POPCNT, CX16, FMA, BMI1/2, F16C, LZCNT, MOVBE, XSAVE).
   - Make the installer detect Zen 4/5 via `/proc/cpuinfo` family/model, or `ld.so`, rather than requiring `gcc`.
3. **Kernel.** Use clang ThinLTO by default, plus a CI job that runs the AutoFDO → Propeller workflow on a fixed gaming and desktop workload (§3.3).
   - Ship `-headers` with a `clang lld llvm` dependency, and give DKMS the akmods-style auto-detection.
   - Take the pre-patched-signed-tarball approach (`tag-release.sh`) rather than applying patches at package time.
4. **Toolchain.** Copy the LLVM 3-stage PGO, including the libstdc++ export-compat patch, plus GCC `profiledbootstrap` + `bootstrap-lto`, binutils `--enable-pgo-build=lto`, and the gcc comp-goto PGO fix.
   - PGO the interpreters and shells (Python, bash) and the compression libraries.
   - Unlike CachyOS, also profile **libzstd** (not only the CLI) and apply the glibc Clear Linux patch if it helps after benchmarking.
5. **Gaming.** Keep Mesa and Wine/Proton portable, as CachyOS does. Ship Proton SLR as the default, autoload NTSync, and carry the gamescope FPS-limiter Mesa patch and the mutter tearing series.
6. **CI.** Do better than CachyOS here: actually compile changed packages in CI, and run a smoke test of PGO packages.
   - CachyOS's `--nobuild` CI missed the zsh configure bug, unapplied patches and the paru LTO-on-v3 loss.
   - Adopt the cachyos-aur-derived risk-flag PR scanner as-is.

---

## Repos covered

| Repo | What was read |
|---|---|
| CachyOS/CachyOS-PKGBUILDS | Full tree listing, README, `.github` CI (makepkg/namcap/nvchecker). Every perf-relevant PKGBUILD in full: pacman (+makepkg.conf, pacman.conf, rust.conf, patches), devtools, toolchain/{gcc, glibc, binutils, libtool, linux-api-headers}, llvm, llvm-git/*, llvm-propeller, autofdo-bin, python, python313, zstd*, xz, lz4, zlib-ng*, sqlite, bash, zsh, nginx, nodejs, go, java*, openblas*, php, ripgrep, svt-av1, valkey, pahole, paru, sudo-rs, pacutils, pacman-contrib, mesa*, nvidia/*, proton-cachyos-*, wine-cachyos*, umu-launcher, lsfg-vk, handheld/*, cachyos-gaming-*, cachyos-settings, ksm, scx/*, dmemcg, bpftune-gaming, chwd, dkms, dracut-cachyos, linux-firmware, mutter, power-profiles-daemon, tuned, eac/*, limine, plymouth, systemd-boot-manager, zfs/* and others (via subagents) |
| CachyOS/PKGBUILDs | Legacy POLAUR-derived repo: README, script.sh, workflows, perf-relevant -git PKGBUILDs (zstd-git, zlib-ng-git, git-git, mkinitcpio-git, meson-git, ninja-git) |
| CachyOS/PKGBUILDS-git | All files (script.sh, kde-git meta, 2 workflows) |
| CachyOS/PKGBUILDS-git-v3 | All files (README, script.sh, mesa-git.patch) |
| CachyOS/cachyos-aur-derived | Top-level structure (~250 packages), `.github/workflows/aur-update.yml` and `ci/*.sh`, perf/gaming PKGBUILDs (cargo-pgo, gcc14, gcc9, python311, sdl2, faudio, heroic, hhd, sunshine, ryujinx, obs-vkcapture, xone/xpadneo, protonplus, protonup-qt, faugus, mangojuice, modprobed-db, bin-cpuflags-x86, auto-cpufreq…); grep for flag changes |
| CachyOS/llvm-pkgbuilds | All PKGBUILDs (llvm, clang, lld, compiler-rt, lib32-llvm, llvm+bolt, llvm-bolt, llvm-full, mesa, rust, libc++, wasi), rebuild-order.txt, srcinfo.sh |
| CachyOS/pacman | Default branch listing (upstream-like master); branches via API; full `release/7.1.x` history (100 commits) via API; downloaded packaged commit `663941f`: cpu_capabilities.c, conf.c, makepkg PACKAGECARCH code/docs, Rust repo-add Cargo.toml, SQLite db loader |
| CachyOS/devtools | Full tree listing; makepkg/pacman configs for x86_64 and x86_64_v3 (+ conf.d rust/fortran), setarch alias; CachyOS patches as applied by the PKGBUILD |
| CachyOS/mkinitcpio | README, CHANGELOG, meson files, mkinitcpio.conf, hooks/install lists, compression code, CI; grep for CachyOS changes (none) |
| CachyOS/docker-makepkg | All files of all 4 variants (Dockerfile, run.sh, makepkg.conf, rust.conf, pacman.conf, ccache.conf, mirrorlists), README |
| CachyOS/docker | All files (Dockerfiles, pacman-v3/v4.conf, workflow, distrobox) |
| CachyOS/pkg-manage-util | All source files and README |
| CachyOS/repo-manage-util | README, config docs, example config, main Rust sources (args, update path, rebuild_check, aur, alpm/postgres helpers), migrations, api-service sources, split_data.sql |
| CachyOS/cachyos-repo-add-script | All files (cachyos-repo.sh, 4 awk scripts, README) |
| CachyOS/rate-mirrors | README, CachyOS target/config sources, algorithm and speed-test code |
| CachyOS/linux-cachyos-deb | All files (cachyos-deb.sh, README) |
| CachyOS/linux-cachyos-for-deb | All files (only LICENSE/CONTRIBUTING/CODE_OF_CONDUCT; no code) |
| CachyOS/linux-cachyos-lts | README, script.sh, srcinfo.sh, full bore-lts PKGBUILD, auto-cpu-optimization.sh, configure; other variants compared (stale 5.15) |
| CachyOS/copr-linux-cachyos | README, kernel-cachyos-lto.spec in full, diffs of the other kernel specs, akmods-clang.patch, addon spec list |
| CachyOS/cacule-cpu-scheduler | README and scripts (apply_suggested_configs.sh); patch list; PDFs skipped |
| CachyOS/linux | API only: all 336 branches listed and categorized; repo metadata; commit lists of 7.3/cachy (all CachyOS commits since 7.3-rc1), 7.3/base, 7.3/sched, 7.3/fixes; compare base...cachy. Tree not downloaded. Also fetched linux-cachyos/linux-cachyos/PKGBUILD (raw) for the kernel build mechanics |
| CachyOS/linux-raspberrypi | API only: metadata, branch list, recent commits (stale rpi-6.6.y mirror) |
| CachyOS/open-gpu-kernel-modules | API only: metadata, branches, commits on 560-cachyos (CachyOS patches) and 615-cachyos |
| CachyOS/zfs | API only: metadata, branches, commits on zfs-2.4.5-cachyos |
| CachyOS/pkgbuild-action | All files (action.yml, entrypoint.sh, README) |
| CachyOS/mirrorlist-proxy-experiment | All files |
| CachyOS/public-dashboard | README and src/lib/*.ts (types, mirrors, utils, caching) |
| CachyOS/builder-dashboard | README and src/lib (API base, typings: marches, statuses, endpoints) |
| CachyOS/db-wrap | README and headers overview |
| CachyOS/shim-review | All files (unfilled template) |
| CachyOS/sbctl | File list, workflows, hooks, go.mod; grep for CachyOS changes (none) |
| CachyOS/mkosi | API only: metadata, recent commits, compare against systemd/mkosi (0 ahead, 64 behind; pure mirror) |
| CachyOS/arch-install-scripts | All files (pacstrap, arch-chroot, genfstab, common, workflows) |
| CachyOS/systemd-boot-manager | All files (sdboot-manage, conf, hooks, README) |
| CachyOS/pacman2pacman | All files |
