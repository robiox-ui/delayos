# DelayOS 패키지 저장소

DelayOS는 자체 pacman 저장소를 운영합니다. 커널, DelayOS 고유 구성(셸, 앱, 설정, 브랜딩), Proton, 그리고 CPU 수준별로 다시 빌드한 핵심 패키지를 여기서 배포합니다. 설치된 PC는 `pacman -Syu`만으로 DelayOS 자체의 업데이트를 받습니다.

빌드 장비는 VM 한 대(8 vCPU, RAM 10GB)입니다. 빌드 팜이 아니므로 Arch 전체(1000개 이상)를 다시 빌드하지 않습니다. 직접 빌드하는 것은 아래 "무엇을 빌드하나"에 적은 목록이 전부이고, 나머지는 Arch 저장소의 패키지를 그대로 씁니다.

## 저장소 구성

| 저장소 | GitHub 릴리스 태그 | 패키지 아키텍처 | 컴파일 대상 | 내용 |
|---|---|---|---|---|
| `[delayos]` | `repo-delayos` | `x86_64`, `any` | `-march=x86-64` | `linux-delayos`, `pahole`, `delayos-*`, `proton-delayos`, `delayos-sb-general` |
| `[delayos-v3]` | `repo-delayos-v3` | `x86_64_v3` | `-march=x86-64-v3` | 선별 재빌드, `linux-delayos-v3` |
| `[delayos-v4]` | `repo-delayos-v4` | `x86_64_v4` | `-march=x86-64-v4` | 선별 재빌드, `linux-delayos-v4` |
| `[delayos-znver4]` | `repo-delayos-znver4` | `x86_64_v4` | `-march=znver4` | 선별 재빌드, `linux-delayos-znver4` |

`/etc/pacman.conf`에서의 순서는 수준 저장소, `[delayos]`, `[core]`, `[extra]`, `[multilib]`입니다. pacman은 패키지를 처음 찾은 저장소에서 가져오므로 위에 있는 저장소가 이깁니다.

```ini
# >>> DelayOS CPU-optimized repositories (managed by delay-cpu-opt, do not edit) >>>
[delayos-v3]
Include = /etc/pacman.d/delayos-mirrorlist
# <<< DelayOS CPU-optimized repositories <<<

# >>> DelayOS repository (managed by delay-cpu-opt, do not edit) >>>
[delayos]
Include = /etc/pacman.d/delayos-mirrorlist
# <<< DelayOS repository <<<
```

`/etc/pacman.d/delayos-mirrorlist`(패키지 `delayos-mirrorlist`)는 한 줄입니다.

```
Server = https://github.com/robiox-ui/delayos/releases/download/repo-$repo
```

### 호스팅: GitHub Releases

저장소 하나가 릴리스 하나입니다. 릴리스의 첨부 파일이 `*.pkg.tar.zst`, `*.pkg.tar.zst.sig`, `<저장소>.db`, `<저장소>.db.sig`, `<저장소>.files`, `<저장소>.files.sig`입니다. pacman은 `Server` 주소 뒤에 파일 이름을 붙여 내려받고, GitHub이 저장 서버로 넘기는 리디렉션을 따라갑니다.

GitHub Pages를 쓰지 않은 이유는 크기 제한입니다. Pages는 사이트 전체 1GB, 파일당 100MB이고 커널 패키지 하나가 이미 100MB를 넘습니다. Releases의 제한은 다음과 같고 `tools/repo-publish.sh`가 올리기 전에 확인합니다.

- 첨부 파일 하나에 2GiB. 지금 가장 큰 패키지는 `proton-delayos`(약 400MB)입니다.
- 릴리스 하나에 첨부 1000개. 패키지마다 파일이 2개이므로 저장소당 약 490개까지입니다.
- 파일 이름에는 `A-Za-z0-9._-`만 남습니다. 다른 문자는 GitHub이 `.`으로 바꿉니다(`pahole-1:1.32-2` → `pahole-1.1.32-2`). 그래서 풀에 넣을 때 파일 이름을 먼저 같은 규칙으로 바꾸고 DB에는 그 이름을 기록합니다. 올린 뒤 GitHub이 저장한 이름이 다르면 게시를 멈춥니다.

릴리스는 `make_latest: false`로 만들어서 ISO 릴리스가 "Latest"로 남습니다.

### 서명

저장소 키는 Secure Boot 키 두 벌과 별개인 세 번째 키입니다.

- `tools/make-delayos-repo-key.sh [OUTDIR]`가 만듭니다. 인증 전용 주 키(ed25519, 만료 없음)와 서명 보조 키(3년)입니다. 사용자 PC가 신뢰하는 것은 주 키의 지문이므로 보조 키는 신뢰를 건드리지 않고 교체할 수 있습니다.
- 비공개 키는 저장소 밖(`OUTDIR`)에만 있습니다. `delayos-repo-master.asc`는 오프라인으로 옮기고, 빌드 VM에는 `delayos-repo-signing.asc`(보조 키만)를 둡니다.
- 공개 키만 저장소에 들어갑니다: `packages/delayos-keyring/delayos.gpg`, `delayos-trusted`, `delayos-revoked`. `delayos-keyring` 패키지가 이 파일을 `/usr/share/pacman/keyrings/`에 설치하고 `pacman-key --populate delayos`를 실행합니다.
- `tools/repo-publish.sh`는 실행할 때 환경 변수로 키 파일 경로(`DELAYOS_REPO_KEY`)와 토큰(`GITHUB_TOKEN`)을 받습니다. 키는 tmpfs의 임시 GnuPG 홈에 넣었다가 끝나면 지웁니다. 가져온 키의 지문이 `delayos-trusted`와 다르면 서명하지 않습니다.
- 패키지마다 분리 서명(`.sig`)을 만들고 DB와 files DB도 서명합니다. 클라이언트는 pacman 기본값 `SigLevel = Required DatabaseOptional`로 검증합니다.

## 무엇을 빌드하나

### 1. DelayOS 자체 (`[delayos]`, 아키텍처 `any`)

이전에는 DelayOS 고유 파일이 모두 ISO의 `airootfs`에 구워져 있어서 설치 뒤에는 바뀌지 않았습니다. 이제는 패키지입니다.

| 패키지 | 내용 |
|---|---|
| `delayos-settings-base` | sysctl, udev, zram, systemd 한도, modprobe, `delay-cpu-opt`, `delay-gamemode`, `delay-gpu-setup`, `delay-steam-compat`, `delay-eac` |
| `delayos-branding` | 로고, `os-release`, Plymouth, SDDM 테마, 배경 화면, `delayfetch` |
| `delayos-shell` | 플라스모이드, `DelayShell`/`DelayUI` QML, 룩앤필, 창 장식, 색 구성, `DelayOS` 아이콘 테마, KDE 기본 설정(`/etc/xdg`, `/etc/skel/.config`) |
| `delayos-apps` | PySide6 앱(설정, 스토어, 작업 관리자, 파일 탐색기, 메모장, 계산기 등)과 `delay-sys-helper` |
| `delayos-winboot` | Windows 전환, 숨겨진 Windows(`delay-winsetup`), Secure Boot 커널 훅 |
| `delayos-keyring` | 저장소 공개 키 |
| `delayos-mirrorlist` | `/etc/pacman.d/delayos-mirrorlist` |
| `delayos-desktop` | 위 전부에 의존하는 메타 패키지 |

**파일은 옮기지 않았습니다.** 모든 작업 스트림이 지금처럼 `profile/airootfs/<최종 경로>`에서 편집합니다. 패키지마다 `packages/delayos-<이름>/files.list`가 자기 파일을 적어 두고, PKGBUILD가 그 목록대로 트리에서 복사합니다(`tools/content-pkgs.sh`). 같은 파일이 두 군데 있지 않습니다.

- 목록 형식: airootfs 기준 경로 한 줄에 하나. `/`로 끝나면 그 아래 전부, 글로브 가능, `!`로 시작하면 제외.
- `packages/delayos-live-only.list`: 라이브 ISO와 설치 프로그램만 쓰는 파일(Calamares 설정, 라이브 자동 로그인, `delay-postinstall` 등). 패키지에 넣지 않습니다.
- `tools/content-pkgs.sh check`: 모든 파일이 정확히 한 패키지 또는 live-only에 속하는지 검사합니다. **`airootfs`에 파일을 추가하면 해당 `files.list`에 들어가는지 이 명령으로 확인하세요.** 어디에도 없으면 빌드가 멈춥니다(업데이트되지 않는 파일이 생기는 것을 막기 위해서입니다).
- 실행 권한은 지금처럼 `profile/profiledef.sh`의 `file_permissions`에서 읽습니다. `/usr/bin`, `/usr/local/bin`은 항상 755입니다.
- 사용자가 고칠 수 있는 `/etc` 파일은 `backup=()`에 자동으로 들어갑니다(고친 파일은 유지되고 새 파일은 `.pacnew`). pacman 훅, systemd 유닛, sudoers, 자동 시작 항목, `/etc/skel`은 제외합니다.
- 버전은 빌드 시각(`2026.11.26.0909`)입니다. 내용 해시가 그대로인 패키지는 다시 빌드하지 않으므로 사용자는 바뀐 패키지만 받습니다.
- Python 바이트코드는 패키지에 들어 있습니다(checked-hash).

**ISO 빌드:** `build.sh`가 `tools/repo-build.sh --no-chroot content`로 같은 패키지를 **게시용 풀(`$DELAYOS_REPO_STATE`, 기본 `/var/lib/delayos-repo`)에서** 만들어 로컬 저장소에 넣고(내용이 그대로인 패키지는 저장소에 이미 있는 버전을 그대로 씁니다. 빌드마다 따로 풀을 쓰던 때는 ISO에만 새 버전이 들어가 설치한 PC의 `pacman -Syu`가 "local is newer"라고 경고했습니다. 바뀐 패키지는 `repo-publish.sh`를 돌릴 때까지 저장소보다 새것이므로 ISO를 만든 뒤에는 바로 게시합니다), 조립한 프로필의 `airootfs`에서 패키지가 가진 파일과 그 `file_permissions` 항목을 뺍니다(`content-pkgs.sh strip`). `packages.x86_64`에 패키지 이름이 있으므로 pacstrap이 설치합니다. 저장소 키가 없으면 `delayos-keyring`과 `delayos-desktop`을 빼고 경고합니다. 이 경우 설치된 시스템은 `[delayos]`를 쓰지 않습니다.

**설치된 시스템:** Calamares가 라이브 이미지를 복사하므로 pacman DB도 함께 넘어가고 파일은 패키지 소유가 됩니다. `delay-postinstall`이 `delay-cpu-opt repo-setup`을 불러 `[delayos]` 블록을 `[core]` 위에 넣습니다(키링과 미러 목록이 있을 때만).

**이전 ISO로 설치한 PC:** 파일이 패키지 소유가 아니어서 처음 한 번은 덮어쓰기를 허용해야 합니다.

```bash
sudo pacman -U delayos-keyring-*.pkg.tar.zst delayos-mirrorlist-*.pkg.tar.zst   # 릴리스 repo-delayos에서 받은 파일
sudo delay-cpu-opt repo-setup
sudo pacman -Sy --overwrite '*' delayos-desktop
```

### 2. 커널

`kernel/linux-delayos/PKGBUILD` 하나에서 네 가지를 만듭니다. 바뀌는 값은 `_pkgsuffix`와 `_processor_opt` 둘뿐입니다.

| 패키지 | 저장소 | `_processor_opt` |
|---|---|---|
| `linux-delayos` | `[delayos]` | `generic_v1` |
| `linux-delayos-v3` | `[delayos-v3]` | `generic_v3` |
| `linux-delayos-v4` | `[delayos-v4]` | `generic_v4` |
| `linux-delayos-znver4` | `[delayos-znver4]` | `zen4` |

이름이 다르므로 `linux-delayos`(모든 x86-64용)는 항상 설치된 채로 GRUB의 대체 항목으로 남습니다. 수준별 커널은 `delay-cpu-opt kernel install`로 고릅니다. 커널을 CPU 수준에 맞춰 얻는 프레임 차이는 보통 1% 안팎이므로 v4와 znver4 커널은 빌드 시간이 남을 때만 만들어도 됩니다.

**Secure Boot:** `delayos-sb-general`에는 특정 `linux-delayos` 빌드를 서명한 이미지가 들어 있습니다. 그래서 이 패키지는 `linux-delayos=<그 버전>`에 의존하고, `repo-build.sh kernel`은 일반 Secure Boot 키(`$DELAYOS_KEYS`)가 있으면 둘을 함께 빌드합니다. `repo-publish.sh`는 풀의 두 버전이 맞지 않으면 게시하지 않습니다. 키 없이 커널만 게시하면 `delayos-sb-general`이 설치된 PC는 pacman이 커널 업그레이드를 거부합니다(부팅 불가보다 안전한 쪽).

수준별 커널 세 개(7.3.6-1)는 이미 빌드되어 있습니다(`BrookOS-vm/out/kernels/`). 다시 컴파일하지 말고 `repo-build.sh import`로 풀에 넣으세요. 이름으로 저장소를 찾습니다. 일반 `linux-delayos`와 `pahole`도 ISO 빌드가 만든 파일(`/home/delaybuilder/linux-delayos/`, `/home/delaybuilder/pahole/`)을 같은 방법으로 넣습니다. chroot 없이 호스트에서 바로 빌드하려면(이전 `kbuild.sh`와 같은 방식) `repo-build.sh --no-chroot --level v3,v4,znver4 kernel`입니다.

`linux-delayos-eac`와 `delayos-sb-signed`는 아직 저장소에 넣지 않았습니다(ISO에 실려 가는 지금 방식 그대로). 안티치트 키로 서명해야 하고 NVIDIA 드라이버 버전에 묶여 있어 별도 작업입니다.

### 3. Proton (`proton-delayos`)

소스는 Proton-CachyOS(Valve Proton + CachyOS/GE 패치)입니다. 업스트림 문서(`BUILDING.md`)대로 Valve의 Proton SDK 컨테이너(Steam Linux Runtime) 안에서 podman으로 빌드합니다: `packages/proton-delayos/build-proton.sh`. makepkg는 결과물(`redist`)을 `/usr/share/steam/compatibilitytools.d/proton-delayos`로 포장만 합니다.

- 필요한 것: 소스 약 15GB, 빌드 트리 약 40GB, SDK 이미지 약 6GB, 합쳐 60GB 이상의 빈 디스크. Wine을 64비트와 32비트로 두 번, DXVK, vkd3d-proton, GStreamer, FFmpeg을 컴파일합니다.
- 우리 VM에서의 예상: 첫 빌드 4~6시간. RAM 10GB는 최소선이어서 스크립트가 작업 수를 RAM/1.5GB로 제한합니다(8코어 중 6개). 스왑이 있어야 합니다. **아직 실행해 보지 않았습니다.**
- `tools/repo-build.sh proton --proton-repack`: CachyOS가 배포한 SLR 빌드를 우리 이름으로 다시 포장합니다(몇 분). 우리 빌드가 아니라는 점이 Steam에 보이는 이름("CachyOS build")에 적힙니다. 소스 빌드를 돌리기 전까지의 임시 수단입니다.
- `delay-steam-compat`의 우선순위: `proton-delayos` → `proton-cachyos-slr` → `proton-cachyos` → 최신 GE-Proton.

### 4. 수준별 선별 재빌드 (`packages/repo/curated.list`)

| 패키지 | 이유 |
|---|---|
| `zstd`, `lz4` | 패키지 설치, btrfs/zram 압축, 게임 자산 로딩 |
| `mesa`, `lib32-mesa` | RADV, ANV, radeonsi, iris, llvmpipe. `vulkan-radeon` 등은 mesa의 분할 패키지라 함께 나옵니다 |
| `qt6-base`, `qt6-declarative`, `kwin` | 데스크톱의 모든 프레임 |
| `pipewire`, `ffmpeg` | 오디오 믹싱, 소프트웨어 디코딩 |
| `sdl2-compat`, `sdl3`, `gamemode`, `mangohud` | 게임 라이브러리와 도구 |
| `python` | DelayOS 앱 시작 시간 |

넣지 않은 것:

- `glibc`, `gcc`, `llvm`: 잘못되면 시스템 전체가 망가지고, glibc는 이미 실행 중에 CPU별 구현을 고릅니다(IFUNC).
- `wine`, `dxvk`, `vkd3d`: 게임은 Proton 안의 것을 씁니다. CachyOS도 Wine/Proton은 일부러 일반 타깃으로 빌드합니다.
- `plasma-workspace`: Qt와 KWin에 비해 뜨거운 경로가 적고 KDE 릴리스마다 다시 빌드해야 합니다.

빌드 방식:

- Arch의 PKGBUILD를 그대로 씁니다. `gitlab.archlinux.org/archlinux/packaging/packages/<이름>`에서 Arch 저장소에 지금 있는 버전의 태그를 체크아웃합니다.
- devtools의 깨끗한 chroot(`makechrootpkg -c`)에서 빌드합니다. chroot의 `pacman.conf`에는 우리 풀이 맨 위에 있어서 `qt6-declarative`는 우리 `qt6-base`를 상대로 빌드됩니다. `curated.list`의 순서가 빌드 순서입니다.
- `makepkg.conf`는 수준별로 생성합니다(`tools/repo-common.sh`의 `gen_makepkg_conf`). CachyOS 빌더와 같은 값입니다: `-O3`, Arch의 보안 플래그, `-flto=auto`, 프레임 포인터 없음, 디버그 패키지 없음, v3 이상에 `-mpclmul`과 `GOAMD64`, Rust `target-cpu`.
- `CARCH`는 `x86_64` 그대로 두고 패키지에 찍히는 아키텍처만 바꿉니다. CachyOS는 이것 때문에 makepkg를 패치했지만(`PACKAGECARCH`), 여기서는 생성한 `makepkg.conf`가 makepkg의 `get_pkg_arch` 함수를 다시 정의합니다. makepkg가 바뀌어 이 방법이 통하지 않게 되면 `repo-build.sh`가 빌드 결과의 아키텍처를 확인하다가 멈춥니다.
- 소스의 PGP 서명 검사는 건너뜁니다(`--skippgpcheck`). 체크섬은 Arch의 PKGBUILD에 고정된 값으로 검사합니다.

**버전 규칙:** `pkgrel`에 `.1`을 붙입니다(`1.5.7-2` → `1.5.7-2.1`, 같은 버전을 다시 빌드하면 `.2`). pacman의 비교에서 Arch의 같은 릴리스보다 크고 다음 릴리스보다 작습니다. `.delayos1` 같은 글자 접미사는 쓸 수 없습니다. pacman은 글자로 끝나는 쪽을 더 **낮은** 버전으로 보기 때문에(`2.delayos1` < `2`) 저장소를 켠 직후 Arch 빌드가 "더 새것"으로 남습니다. DelayOS 빌드는 아키텍처(`x86_64_v3`)와 Packager(`DelayOS Build`)로 구분합니다.

**업데이트 정책:** 수준 저장소가 `[core]` 위에 있으므로, 그 안에 패키지가 있는 동안에는 Arch에 새 릴리스가 나와도 pacman은 우리 것을 씁니다. 오래된 재빌드는 사용자를 붙잡아 둡니다. 그래서:

1. `tools/repo-update.sh`가 Arch 버전과 풀 버전을 비교해 바뀐 것만 다시 빌드합니다.
2. 재빌드가 **실패하면** 그 오래된 패키지를 수준 저장소에서 빼 버립니다. 해당 PC는 다음 `pacman -Syu`에서 Arch의 새 빌드를 받습니다.
3. 따라서 `repo-update.sh`를 주기적으로(권장: 매일 한 번, 적어도 `pacman -Syu`를 권하기 전에) 돌려야 합니다.

## 빌드와 게시

모두 빌드 VM(Arch)에서 root로 실행합니다. 상태는 `/var/lib/delayos-repo`(`DELAYOS_REPO_STATE`)에 있습니다: `pool/<저장소>/`(게시할 파일과 DB), `chroot/<수준>/`, `work/`, `conf/`.

```bash
# 한 번만: 저장소 키 (Windows 호스트의 Git Bash에서)
tools/make-delayos-repo-key.sh "C:\Users\<사용자>\Documents\delayos-keys\repo"
#   -> packages/delayos-keyring/ 의 공개 키 3개를 커밋
#   -> delayos-repo-signing.asc 를 빌드 VM의 /root/delayos-keys/repo/ 로 복사

# 빌드
sudo tools/repo-build.sh content                      # delayos-* (1분)
sudo tools/repo-build.sh pahole kernel                # linux-delayos (+ delayos-sb-general)
sudo tools/repo-build.sh --level v3 kernel curated    # linux-delayos-v3 + 선별 재빌드
sudo tools/repo-build.sh --level v3 pkg:zstd          # 패키지 하나
sudo tools/repo-build.sh proton                       # 몇 시간
sudo tools/repo-build.sh import /path/linux-delayos-v3-*.pkg.tar.zst   # 다른 곳에서 이미 빌드한 패키지를 풀에 넣기
sudo tools/repo-build.sh list                         # 풀에 든 것

# 게시 (키와 토큰은 실행할 때만 환경 변수로)
sudo DELAYOS_REPO_KEY=/root/delayos-keys/repo/delayos-repo-signing.asc tools/repo-publish.sh --dry-run
sudo DELAYOS_REPO_KEY=/root/delayos-keys/repo/delayos-repo-signing.asc GITHUB_TOKEN=... tools/repo-publish.sh

# 유지
sudo tools/repo-update.sh --check                     # 무엇이 오래됐는지만
sudo DELAYOS_REPO_KEY=... GITHUB_TOKEN=... tools/repo-update.sh --publish
```

토큰은 `robiox-ui/delayos`에 대한 Contents 읽기/쓰기 권한의 fine-grained 토큰이면 됩니다. 게시 순서는 패키지와 서명, 그다음 DB, 마지막으로 DB가 더 이상 가리키지 않는 파일 삭제입니다. 클라이언트가 없는 파일을 가리키는 DB를 받는 일이 없습니다.

### 예상 빌드 시간 (빌드 VM: 8 vCPU, RAM 10GB)

| 대상 | 시간 | 근거 |
|---|---|---|
| `delayos-*` 8개 | 약 1분 | 테스트 VM(4 vCPU)에서 측정: 20초 |
| `linux-delayos` 하나 | 40~45분 | 빌드 VM의 이전 빌드 기록(clang ThinLTO, 전체 설정) |
| 커널 4종 | 약 3시간 | 위의 4배 |
| `zstd` (v3) | 38초(테스트 제외, chroot가 이미 있을 때). chroot를 처음 만들 때 3분 추가. 테스트 포함은 15분 이상 | 테스트 VM(4 vCPU)에서 측정 |
| `mesa` + `lib32-mesa` | 수준당 30~45분 | 추정 |
| `qt6-base` + `qt6-declarative` | 수준당 50~70분 | 추정 |
| `kwin`, `pipewire`, `ffmpeg`, 나머지 | 수준당 40~60분 | 추정 |
| `python` (PGO+LTO, 테스트 제외) | 수준당 20~30분 | 추정 |
| 선별 목록 전체 | 수준당 2.5~3.5시간, 3수준 8~10시간 | 추정 |
| `proton-delayos` | 4~6시간, 디스크 60GB | 추정, 미실행 |

"추정"은 실제로 돌려 보지 않은 값입니다. 첫 전체 빌드(커널 4 + 선별 3수준 + Proton)는 15~20시간으로 잡으세요. 이후에는 Arch에서 바뀐 패키지만 다시 빌드합니다. Mesa, Qt, KWin은 한 달에 여러 번 올라옵니다.

### GitHub Actions

`.github/workflows/packages.yml`은 `profile/airootfs`나 `packages/delayos-*`가 바뀐 푸시마다 `delayos-*` 패키지를 Arch 컨테이너에서 빌드합니다. 저장소 시크릿 `DELAYOS_REPO_SIGNING_KEY`(서명 보조 키의 내용)가 있으면 `[delayos]`에 게시하고, 없으면 빌드 결과만 아티팩트로 남깁니다. 커널, Mesa, Qt, Proton은 무료 러너(4 vCPU, 디스크 14GB, 6시간 제한)에서 빌드하지 않습니다.

시크릿에 서명 키를 두면 그 저장소에 쓰기 권한이 있는 워크플로가 패키지에 서명할 수 있게 됩니다. 원하지 않으면 시크릿을 만들지 말고 빌드 VM에서만 게시하세요.

## 클라이언트 쪽 (`delay-cpu-opt`)

- `delay-cpu-opt repo-setup`: `[delayos]` 블록을 넣고 키를 확인합니다. 설치할 때 한 번 실행됩니다.
- `delay-cpu-opt enable`: 기본 소스가 `delayos`입니다. CPU가 지원하는 수준의 저장소가 게시되어 있는지 확인하고(znver4 → v4 → v3 순으로 내려가며 찾음) 수준 블록을 넣은 뒤 `pacman -Syu`를 실행합니다. 게시된 수준이 없으면 아무것도 바꾸지 않고 종료 코드 3으로 끝납니다.
- `delay-cpu-opt enable --source cachyos`: 이전 동작(CachyOS 저장소)입니다. 설치 프로그램에서는 커널 옵션 `delayos.cpuopt.source=cachyos`로 고릅니다. 두 소스를 동시에 켤 수는 없습니다(`disable` 뒤에 바꿉니다).
- `delay-cpu-opt disable`: 수준 블록을 지우고 아키텍처가 `x86_64_v3/v4`인 패키지를 Arch 빌드로 되돌립니다. `[delayos]`는 그대로 둡니다.

## 위험과 한계

- **키를 잃으면** 사용자 PC가 업데이트를 받지 못합니다. 주 키는 오프라인 백업이 필수입니다. 서명 보조 키가 새면 주 키로 폐기하고 새 보조 키를 만든 뒤 `delayos-keyring`을 올립니다.
- **한 사람, 한 VM:** 재빌드가 밀리면 수준 저장소 사용자는 Mesa나 Qt의 보안 수정이 늦어집니다. 위의 "실패하면 뺀다" 규칙이 최악의 경우를 막지만, `repo-update.sh`를 아예 돌리지 않는 경우는 막지 못합니다.
- **부분 업그레이드 위험:** Arch가 `qt6-base`를 올렸는데 우리 재빌드가 아직 이전 버전이면, 수준 저장소 사용자는 Arch의 새 `qt6-*` 나머지와 우리의 옛 `qt6-base`를 함께 갖게 됩니다. Qt는 비공개 API 버전을 검사하므로 이 상태에서 Plasma가 뜨지 않을 수 있습니다. Qt와 KWin은 Arch에 올라온 날 다시 빌드하거나, 그럴 수 없으면 목록에서 빼는 것이 맞습니다.
- **GitHub 의존:** 릴리스 다운로드가 막히거나 계정에 문제가 생기면 저장소 전체가 멈춥니다. 미러 목록 패키지에 `Server` 줄을 추가하면 다른 호스트를 함께 쓸 수 있습니다.
- **`get_pkg_arch` 재정의**는 makepkg 내부 함수에 기대고 있습니다. pacman 대규모 업데이트 뒤에는 `repo-build.sh --level v3 pkg:zstd`로 먼저 확인하세요.
- **v4/znver4 빌드에는 AVX-512가 있는 빌드 호스트가 필요합니다**(테스트와 빌드 중 실행되는 도구 때문). 지금 호스트(Zen 5)는 됩니다.
- **`/usr/local/bin`과 `/etc/systemd/system`, `/etc/pacman.d/hooks`에 패키지 파일이 있습니다.** Arch 패키징 지침과는 다르지만, 다른 스크립트와 유닛이 이 경로를 참조하고 있어 옮기지 않았습니다.
- **`cachyos-settings`와 충돌:** `delayos-settings-base`는 CachyOS-Settings에서 가져온 파일을 같은 이름으로 갖고 있어 두 패키지를 함께 설치할 수 없습니다(`conflicts`로 표시).
