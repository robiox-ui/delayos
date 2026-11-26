# DelayOS: Arch 기반 게이밍 데스크톱

DelayOS는 Arch Linux와 KDE Plasma 6(Wayland) 위에 만든 게이밍 중심 배포판입니다. 상단바와 독, 한국어 기본 설정, 자체 앱(메모장, 계산기, 작업 관리자, 캡처 도구, 파일 탐색기, 설정, 스토어 등), CachyOS 기반 커널 `linux-delayos`를 기본으로 제공합니다.

## 빌드 방법

**Windows (WSL2에서 빌드합니다. 창은 뜨지 않습니다):**
```powershell
powershell -ExecutionPolicy Bypass -File .\build-windows.ps1
```
**Arch Linux:**
```bash
sudo ./build.sh
```
결과물은 `out/delayos-YYYY.MM.DD-x86_64.iso`입니다. USB에는 Rufus나 Ventoy로 굽습니다. 빌드할 때 약 4GB를 받고, 1~2시간 걸립니다.

## 주요 기능

| 기능 | 구현 |
|---|---|
| 반투명 글래스 UI, 파란 강조색(#4D6BFE) | KWin 블러, `DelayDark`/`DelayLight` 색 구성, DelayOS 데스크톱 테마·창 장식 |
| 상단바와 가운데 독 / 작업표시줄 모드 | `org.delayos.topbar`, `org.delayos.dock`, `delay-shell-layout` |
| 시작 메뉴, 명령 바(Meta+Space), 제어 센터, 달력, 클립보드(Meta+V), Win+X 메뉴 | `org.delayos.*` 위젯과 `DelayShell` QML 모듈 |
| 게이밍 모드 버튼(Meta+G) | `org.delayos.gamingtoggle`, `delay-gamemode` (sched-ext LAVD 성능 모드) |
| 자체 앱 | 메모장, 계산기, 작업 관리자, 캡처 도구, 파일 탐색기, 터미널, 설정, 스토어, 시작하기, 드라이버 |
| .exe/.msi 실행 | Windows 앱 엔진(Wine/Proton, DXVK) |
| Android 앱 | Waydroid 기반 Android 앱, 게임 키 조작 오버레이 |
| 앱 스토어 | Flathub |
| 시스템 정보 | `delayfetch` (fastfetch, DelayOS 로고) |
| 저사양 PC | RAM이 적으면 경량 세션과 zram 자동 설정 |
| 안티치트(EAC Linux v2) | 별도 서명 커널 `linux-delayos-eac`와 부팅 항목 ([docs/eac-linux-v2.md](docs/eac-linux-v2.md)) |
| 설치 | Calamares (Windows 옆 설치, LUKS2 암호화) |
| 텔레메트리 없음 | KDE 사용자 피드백 끔 |

## 성능 최적화

- **커널:** `linux-delayos`(CachyOS 소스 기반: BORE 스케줄러, Clang ThinLTO, -O3, 1000Hz, 완전 선점, BBRv3)과 대체용 `linux-lts`.
- **스케줄러:** sched-ext `scx_lavd`, ananicy-cpp(CachyOS 규칙), irqbalance, GameMode.
- **메모리:** zram(zstd), MGLRU, `vm.max_map_count` 최대.
- **I/O:** HDD는 BFQ, SATA SSD는 mq-deadline, NVMe는 kyber 자동 선택.
- **GPU:** 셰이더 캐시 확대, ntsync, 전체 화면 게임 컴포지터 우회.
- **네트워크:** BBRv3와 fq.
- **부팅:** 부팅 메뉴 자동 선택, 불필요한 대기 서비스 제거.
- **자체 패키지 저장소:** 커널, DelayOS 셸·앱·설정(`delayos-*` 패키지), Proton을 `[delayos]` 저장소로 배포하므로 설치 뒤에도 `pacman -Syu`로 업데이트됩니다. x86-64-v3/v4, Zen 4/5 CPU에서는 그 수준으로 다시 빌드한 핵심 패키지(Mesa, Qt, KWin 등) 저장소를 씁니다(`delay-cpu-opt`). CachyOS 저장소는 선택 사항(`--source cachyos`). 자세한 내용은 [docs/packaging.md](docs/packaging.md), [docs/gaming-performance.md](docs/gaming-performance.md).
- **게이밍 모드:** CPU EPP performance, LAVD gaming 모드, AMD GPU 최고 전원 상태, Ryzen X3D V-Cache 코어 우선. 끄면 켜기 전 값으로 복원.
- **벤치마크:** `delay-bench`로 Windows(PresentMon/CapFrameX)와 DelayOS(MangoHud) 기록을 같은 식으로 비교 ([docs/benchmark.md](docs/benchmark.md)).

## 구조

```
build.sh              Arch에서 ISO 빌드 (커널 → AUR → 로컬 저장소 → mkarchiso)
build-windows.ps1     Windows에서 WSL2 Arch로 build.sh 실행
aur-packages.txt      AUR 패키지 (?로 표시한 것은 선택)
kernel/               linux-delayos, linux-delayos-eac
packages/             pahole, delayos-sb-signed, delayos-* (airootfs를 패키지로 묶는 PKGBUILD와 files.list),
                      proton-delayos, repo/curated.list (CPU 수준별 재빌드 목록)
tools/                저장소 빌드·게시(repo-build.sh, repo-publish.sh, repo-update.sh), 키 생성
profile/              archiso 프로필
  packages.x86_64     공식 저장소 패키지
  airootfs/           시스템 설정, 셸 위젯, 앱, 테마
```

## 라이선스

GPL-3.0
