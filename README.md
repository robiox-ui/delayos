# DelayOS: Arch 기반 게이밍 데스크톱

HT 채널의 FlowOS 영상 4개(약 23분)를 **1초 단위 프레임으로 전부 분석**하고, 화면에 나온 기능, 레이아웃, 사용감을 Arch Linux와 KDE Plasma 6(Wayland)로 재현한 archiso 프로필입니다.
초 단위 분석 원본은 [docs/video-analysis/](docs/video-analysis/)에 있습니다.

> FlowOS는 Velotic Studios의 상용 제품입니다. 그래서 이름, 로고, 배경화면은 직접 만든 것(DelayOS, Delay Current)을 쓰고, 기능과 사용감만 따라 만들었습니다.

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

## 영상 기능 ↔ 구현 대응표

| 영상에 나온 것 | DelayOS 구현 |
|---|---|
| 반투명 글래스 UI, 코랄 강조색 | KWin 블러/대비 효과, `DelayDark` 색 구성(#F2735F), Inter 폰트 |
| 상단바 (로고·앱 이름 / 트레이·시계 "ddd d MMM HH:mm") | Look-and-Feel `org.delayos.dock` 레이아웃 스크립트 |
| 가운데 떠 있는 독, 지니 최소화 | 플로팅 패널(fit 너비), Magic Lamp 효과 |
| 독 ↔ 작업표시줄 실시간 전환 | `org.delayos.taskbar` (시스템 설정 → 전역 테마에서 전환) |
| 시작 메뉴 검색: 단위·환율·계산 답변 | Kickoff와 KRunner의 계산기·단위변환·웹 러너 |
| Super+Space 명령 바, `>명령` 실행 | KRunner (Meta+Space, 셸 러너) |
| Win+V 클립보드, Win+. 이모지 | Klipper, Plasma Emoji Selector |
| Win+Shift+S 캡처 → 클립보드와 사진/스크린샷 폴더 | Spectacle (자동 복사·자동 저장 설정) |
| Ctrl+Shift+Esc 작업 관리자 | Plasma System Monitor |
| Win+X 빠른 도구, Win+1~9 독 앱, Win+Tab 작업 보기 | `delay-winx`, 작업 관리자 단축키, Overview 효과 |
| 파일 탐색기 탭, Ctrl+Z 삭제 취소, ZIP, 사진을 배경으로 | Dolphin, Ark 서비스 메뉴, `delay-desktop` 서비스 메뉴 |
| 상단 가운데 알림 알약 | Plasma 알림 위치 TopCenter |
| **상단바 "Gaming" 버튼 원클릭** | `org.delayos.gamingtoggle` 위젯과 `delay-gamemode` (Win+G) |
| Steam 게임 (Cyberpunk, CS2, Dota 2) | Steam, Proton, GameMode, MangoHud(Shift+F12 FPS), gamescope |
| .exe/.msi 더블클릭 → "Windows Engine" | `delay-open`: WinBoat(Windows VM, 앱 창 연동)를 쓰고, 없으면 Wine/Proton(umu)과 DXVK |
| .apk와 Android 앱 각각 자기 창 | Waydroid 멀티윈도우와 GApps (`delay-android`) |
| Android 게임 키보드/마우스 조작 | waydroid-helper (선택 AUR) |
| Debian·Fedora 앱 (.deb/.rpm) | distrobox와 Podman, 시작 메뉴로 자동 내보내기 |
| Mac 앱 (.dmg) | Darling (실험적, 선택) |
| 앱 스토어 (Flathub) | Discover와 Flathub (첫 부팅 때 자동 추가) |
| 128MB RAM, 저사양 PC | 1.5GB 미만이면 경량 세션(sway, ~120MB)을 자동 선택하고 zram을 2배로 설정 |
| TPM·Secure Boot·SSE4.2·POPCNT 불필요 | x86-64-v1 기본 Arch 패키지와 linux-delayos 커널 (generic x86-64, 모든 64비트 CPU) |
| Windows 옆에 설치, 부팅 메뉴 | Calamares의 "Install alongside" 기본값, GRUB과 os-prober |
| 드라이브 암호화 옵션 | Calamares LUKS2 |
| 텔레메트리 없음 | KDE 사용자 피드백 끔 |

## 성능 최적화 (부드러움)

- **커널:** `linux-delayos`(CachyOS 소스 기반: BORE 스케줄러, Clang ThinLTO, -O3, 1000Hz, 완전 선점, BBRv3, `kernel/linux-delayos/`)과 대체용 `linux-lts`. `split_lock_detect=off`, `nowatchdog`을 씁니다.
- **메모리:**
  - zram(zstd)을 swappiness 150으로 운용합니다.
  - MGLRU, THP는 madvise로 둡니다.
  - `vm.max_map_count`를 최대로 올렸습니다(최신 게임 필수).
  - dirty 버퍼를 작게 잡아 파일 복사 중 끊김을 없앴습니다.
- **I/O:** HDD는 BFQ, SATA SSD는 mq-deadline, NVMe는 none으로 자동 선택합니다. btrfs는 zstd:1 압축과 noatime으로 마운트합니다.
- **CPU 우선순위:**
  - ananicy-cpp(백그라운드 자동 nice), irqbalance, power-profiles-daemon을 씁니다.
  - GameMode가 게임마다 renice와 성능 프로필을 자동 적용합니다.
- **게이밍 모드 버튼:**
  - performance 프로필로 바꾸고 CPU 거버너와 EPP를 성능으로 올립니다.
  - 블러 등 KWin 효과를 내리고, 파일 인덱서와 업데이트 서비스를 멈춥니다.
- **GPU:**
  - NVIDIA는 modeset=1, AMD는 구형 GCN도 amdgpu로 돌립니다.
  - 셰이더 캐시를 10GB로 늘렸고, RADV GPL로 셰이더 컴파일 끊김을 줄였습니다.
  - Wine은 fsync/ntsync를 씁니다.
- **화면 지연:**
  - 전체 화면 게임은 컴포지터를 우회하고, 티어링을 허용합니다(입력 지연 감소).
  - 애니메이션 속도는 0.7배입니다.
- **네트워크:** BBR과 fq, TCP Fast Open을 씁니다.
- **파일 인덱싱:** 이름만 인덱싱하고 Steam/게임 폴더는 제외해 CPU와 디스크 부담을 줄였습니다.

## 영상 주장 중 현실적으로 불가능하거나 다르게 처리한 것

- **커널 수준 안티치트 게임**(발로란트, 롤 등): 리눅스에서는 동작하지 않습니다. EAC나 BattlEye를 허용한 게임만 됩니다.
- **Office·Photoshop 실행:** 영상 속 "Windows Engine"은 실제로는 Windows VM으로 보입니다. 그래서 WinBoat(정품 Windows 라이선스 필요)로 연결했습니다.
- **128MB RAM에서 KDE와 Steam 실행:** 불가능합니다. 저사양 PC는 경량 세션으로 대응합니다(영상도 별도 세션과 swap을 쓴 것으로 확인됨).

## 구조

```
build.sh              Arch에서 ISO 빌드 (AUR → 로컬 저장소 → mkarchiso)
build-windows.ps1     Windows에서 WSL2 Arch로 build.sh 실행
aur-packages.txt      AUR 패키지 (?로 표시한 것은 선택)
profile/              archiso 프로필 (releng 위에 덮어씀)
  packages.x86_64     공식 저장소 패키지
  airootfs/etc/       sysctl·zram·udev·gamemode·KDE 기본 설정·Calamares
  airootfs/usr/       게이밍 위젯, 레이아웃, 색 구성, 배경, delay-* 스크립트
docs/video-analysis/  영상별 초 단위 분석 보고서
```
