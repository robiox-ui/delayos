# Windows 전환 (delay-winboot)

커널 안티치트 때문에 Linux에서 실행할 수 없는 게임(발로란트, 리그 오브 레전드, 포트나이트, 배틀그라운드 등)을
DelayOS에서 클릭 한 번으로 **이 PC에 설치된 실제 Windows**에서 실행하고, 게임을 끝내면 DelayOS로 돌아오는 기능입니다.

## 솔직한 설명: 실제로 일어나는 일

마법이 아니라 **듀얼 부팅 재시작**입니다. 가상 머신도, Wine도 아닙니다.

1. DelayOS에서 게임을 누르면 전체 화면 전환 화면(검은 배경 + DelayOS 로고 + "Windows로 전환 중…")이 뜹니다.
   "다시 시작할까요?" 같은 확인 창은 기본적으로 없습니다.
2. DelayOS가 "어떤 게임을 실행할지"를 적은 작은 요청 파일을 EFI 시스템 파티션(ESP)에 쓰고,
   **다음 한 번만** Windows로 부팅하도록 펌웨어에 지정합니다(UEFI `BootNext`). 기본 부팅 순서는 바뀌지 않습니다.
3. 열려 있는 앱을 닫고 로그아웃한 뒤 PC가 다시 시작됩니다. 종료 화면은 Plymouth(같은 로고)라서 글자가 보이지 않습니다.
4. Windows가 시작되고 로그인하면, 한 번 설치해 둔 **Windows 연동 도우미**가 요청 파일을 읽고 지운 뒤 게임을 실행합니다.
5. 게임이 끝나면 도우미가 10초 카운트다운 창("Windows에 머물기" 버튼 있음)을 보여 주고,
   다음 한 번만 DelayOS로 부팅하도록 지정한 뒤(`bcdedit /set {fwbootmgr} bootsequence {DelayOS 항목}`) 다시 시작합니다.

숨길 수 없는 것:

- **메인보드/제조사 로고(POST 화면)** 는 재시작할 때마다 잠깐 보입니다. 펌웨어가 그리는 화면이라 OS가 없앨 수 없습니다.
  (BIOS의 "Fast Boot"나 "로고 표시 끄기"로 줄일 수는 있습니다.)
- Windows 로그인 화면: **자동 로그인**을 켜지 않으면 암호/PIN을 한 번 입력해야 게임이 시작됩니다.
- 돌아올 때 GRUB 메뉴가 설정된 시간(기본 3초)만큼 보일 수 있습니다.
- 전환에는 PC에 따라 대략 30초~1분이 걸립니다(재시작 두 번이 아니라 갈 때 한 번, 올 때 한 번).

## 필요한 것

- 같은 PC에 설치된 Windows 10/11 (듀얼 부팅). Windows가 없으면 시작 메뉴에 Windows 게임이 나타나지 않습니다.
- Windows에서 **한 번** 연동 도우미 설치 (아래).
- 클릭 없이 게임까지 가려면 Windows 자동 로그인.
- 게임 자체는 Windows에 설치되어 있어야 합니다.

## 한 번만 하는 설치

1. DelayOS에서 설정 › 앱 지원 › **Windows 전환** › "도우미 설치"를 누르거나, Windows 게임을 처음 누르면 안내 창이 뜹니다.
   "Windows로 이동"을 누르면 설치 파일이 준비되고 PC가 Windows로 다시 시작됩니다.
2. Windows에서:
   - `C:\DelayOS-연동\DelayOS-Windows-연동.cmd` 가 있으면 두 번 클릭합니다(관리자 권한을 묻습니다).
   - 없으면(Windows가 빠른 시작/최대 절전 상태이거나 BitLocker를 쓰는 경우 C:에 쓰지 않습니다)
     시작 버튼을 마우스 오른쪽 버튼으로 눌러 **터미널(관리자)** 을 열고 다음 두 줄을 입력합니다.
     ```
     mountvol S: /S
     S:\EFI\DelayOS\winboot\setup.cmd
     ```
   - 같은 파일이 DelayOS의 `/usr/share/delayos/winboot/windows/` 에도 있으므로 USB로 옮겨 실행해도 됩니다.
3. 도우미가 묻는 선택 사항(각각 동의해야 적용):
   - Windows 부팅 로고/회전 점 숨기기 (`bcdedit /set {current} bootuxdisabled on`). BitLocker 사용 중이면 건드리지 않습니다.
   - 빠른 시작 끄기 (듀얼 부팅에서는 권장).
   - 자동 로그인: 도우미는 **암호를 저장하지 않습니다.** Windows의 "사용자 계정"(netplwiz) 창을 열어 줄 뿐이며,
     거기에서 "사용자 이름과 암호를 입력해야…" 체크를 해제하면 됩니다. Microsoft의 Sysinternals Autologon을 써도 됩니다.
     자동 로그인을 켜면 PC를 켠 누구나 그 계정을 쓸 수 있다는 점은 알고 켜세요.
4. 시작 메뉴의 "DelayOS로 돌아가기"로 DelayOS에 돌아옵니다. 이제 DelayOS 시작 메뉴의 **Windows 게임**에 게임이 보입니다.

제거: 같은 `.cmd`를 다시 실행하고 `2`(제거)를 고릅니다. 예약된 작업, 바로 가기, `C:\ProgramData\DelayOS`, ESP의 목록 파일을 지우고
부팅 로고 설정을 되돌립니다.

도우미가 Windows에 설치하는 것:

| 항목 | 내용 |
|---|---|
| `C:\ProgramData\DelayOS\winboot\` | `agent.ps1`, `messages.ko.json`, 설정/로그 (관리자만 쓰기 가능) |
| 예약된 작업 `\DelayOS\WinBoot-Agent` | 로그온 시/절전 해제 시, 가장 높은 권한. 요청 확인 → 게임 실행 → 종료 대기 → 복귀 |
| 예약된 작업 `\DelayOS\WinBoot-Launch` | 요청 시, **일반 권한**. 게임은 항상 관리자 권한 없이 실행됩니다 |
| 예약된 작업 `\DelayOS\WinBoot-Return` | 요청 시, 가장 높은 권한. "DelayOS로 돌아가기" |
| 시작 메뉴 바로 가기 "DelayOS로 돌아가기" | 언제든 수동으로 DelayOS로 재시작 (UAC 창 없음) |

요청 파일이 없으면(Windows를 평소처럼 켠 경우) 도우미는 게임 목록만 갱신하고 끝납니다. 아무것도 실행하지 않습니다.

## 지원하는 게임: 전부

고정 목록이 아닙니다. 세 가지 출처를 합칩니다.

1. **자동 감지 (권장 경로)**: Windows 도우미가 Windows를 켤 때마다 설치된 게임 목록과 아이콘(PNG 64px)을 ESP의
   `\EFI\DelayOS\winboot\inventory.json`, `icons\` 에 내보냅니다. DelayOS는 로그인할 때 이를 읽어
   게임마다 시작 메뉴 항목(`~/.local/share/applications/delayos-wingame-<id>.desktop`, 분류 "Windows 게임")을 만듭니다.
   DelayOS가 NTFS를 직접 읽지 않으므로 빠른 시작/최대 절전/BitLocker와 무관하게 동작합니다.
   - Steam: `libraryfolders.vdf` + `appmanifest_*.acf` → `steam://rungameid/<appid>`
   - Epic Games: `C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests\*.item` →
     `com.epicgames.launcher://apps/<네임스페이스>%3A<항목 ID>%3A<AppName>?action=launch&silent=true`
     (Epic 런처가 바탕 화면 바로 가기에 쓰는 형식)
   - Riot: 발로란트, 리그 오브 레전드 (`RiotClientServices.exe --launch-product=… --launch-patchline=live`)
   - Ubisoft Connect: 레지스트리 `Ubisoft\Launcher\Installs` → `uplay://launch/<id>/0`
   - Battle.net, EA app, Nexon 등은 자동 감지하지 않습니다. 아래 "직접 추가"를 쓰세요.
2. **기본 목록** `/usr/share/delayos/winboot/games.json`: 발로란트, 리그 오브 레전드, 포트나이트, 배틀그라운드, 에이펙스 레전드,
   레인보우 식스 시즈. 한국어 이름, 종료 감지용 프로세스 이름, 안티치트 설명이 들어 있고, 자동 감지된 게임과 `aliases`로 합쳐집니다.
   도우미를 설치하기 전에는 발로란트·리그 오브 레전드·포트나이트만 미리 보이고, 설치 후에는 **실제로 설치된 게임만** 보입니다.
   관리자는 `/etc/delayos/winboot/games.d/*.json` 에 같은 형식으로 추가할 수 있습니다.
3. **직접 추가**: 설정 › 앱 지원 › Windows 전환 › "Windows 게임 추가" (또는 `delay-winboot --add`).
   Windows 기준 실행 파일 경로(`D:\Games\X\X.exe`)나 런처 주소(`steam://…`, `battlenet://…` 등)를 입력합니다.
   "찾아보기"로 DelayOS에 마운트된 Windows 드라이브의 `.exe`를 고르면 경로를 Windows 형식으로 바꿔 주는데,
   드라이브 문자는 추측(Windows 폴더가 있는 드라이브는 `C:`, 나머지는 `D:`)이므로 확인하세요.
   목록은 `~/.config/delayos/winboot-games.json` 에 저장됩니다.

Windows Engine 연동: `.exe`를 열었을 때 기본 목록의 `exe_names`와 일치하면(예: `VALORANT.exe`, `Install VALORANT.exe`)
Wine으로 실행하는 대신 "실제 Windows에서 실행" 창을 띄웁니다("그래도 여기서 열기"도 가능).
Wine 실행에 실패한 프로그램의 오류 창에도 "실제 Windows에서 실행…" 버튼이 있어 바로 직접 추가할 수 있습니다.

### 게임 종료 감지

- 프로세스 이름을 아는 게임(기본 목록, Riot, Epic의 `LaunchExecutable`)은 그 프로세스가 나타났다가 모두 사라지면 종료로 봅니다.
  리그 오브 레전드는 클라이언트(`LeagueClient*`)까지 닫아야 종료입니다(매 판이 끝날 때마다 재시작되지 않도록).
- 그 밖의 게임은 **설치 폴더** 기준입니다. 설치 폴더 안의 실행 파일로 돌아가는 프로세스가 하나도 없으면 종료로 봅니다
  (런처 → 게임 본체로 넘어가는 경우 포함).
- 설치 폴더도 프로세스 이름도 모르는 경우(런처 주소만 직접 추가한 경우)는 자동으로 돌아오지 않습니다.
  알림 영역(트레이)의 DelayOS 아이콘이나 시작 메뉴의 **"DelayOS로 돌아가기"** 를 쓰세요. 이 수동 복귀는 항상 사용할 수 있습니다.
- 게임이 30분 안에 시작되지 않으면 자동 복귀를 끕니다. 카운트다운 중에 게임이 다시 뜨면(패치 후 재실행 등) 복귀를 취소합니다.
- 대기 시간은 `~/.config/delayosrc` 의 `[WinBoot] ReturnDelay=10` (초, 0이면 즉시)로 바꿉니다.

## 설정

설정 › 앱 지원 › Windows 전환:

- 상태: Windows를 찾았는지, 연동 도우미가 설치됐는지, 자동 로그인이 켜져 있는지.
- **전환 전에 확인** (기본 끔): 켜면 전환하기 전에 한 번 물어봅니다. (`[WinBoot] Confirm`)
- **전환 화면 문구** (기본 켬): "Windows로 전환 중…" 글자를 숨길 수 있습니다. (`[WinBoot] SplashText`)
- Windows 게임 추가/제거.

## 안전 장치

전환을 막고 이유를 한국어로 알려 주는 경우:

- Windows 부팅 항목을 찾지 못함.
- BitLocker + GRUB/systemd-boot 경유 부팅만 가능한 경우(복구 키를 요구하게 되므로).
- 레거시 BIOS 부팅에서 Windows가 최대 절전/빠른 시작 상태이거나 BitLocker인 경우(요청 파일을 NTFS에 써야 하므로).
- GRUB이 일회성 부팅 정보를 저장할 수 없는 `/boot` 구성(Btrfs/LVM/RAID)에서 GRUB 방식밖에 쓸 수 없는 경우.

경고만 하는 경우:

- **BitLocker (UEFI)**: DelayOS는 GRUB을 거치지 않고 펌웨어가 Windows 부팅 관리자를 직접 시작하게 하므로(BootNext)
  TPM 측정값이 평소 Windows 부팅과 같아 보통 복구 키를 묻지 않습니다. 다만 펌웨어 설정/업데이트에 따라 물어볼 수 있으니
  복구 키(Microsoft 계정 › 장치 › BitLocker 복구 키)를 미리 확인해 두세요. 이 안내는 처음 한 번 확인 창으로 보여 줍니다.
- Windows가 최대 절전/빠른 시작 상태(UEFI): 전환은 되지만, 최대 절전에서 깨어나는 경우 로그온이 일어나지 않을 수 있습니다
  (도우미는 절전 해제 이벤트에도 반응하도록 등록되어 있습니다).

그 밖에:

- 전환이 실제로 일어나지 않은 경우(전원 차단 등) 다음 DelayOS 로그인 때 남은 요청과 일회성 부팅 지정을 지웁니다.
  그 전에 Windows를 직접 켜면 요청된 게임이 한 번 실행될 수 있습니다.
- 권한: `pkexec /usr/lib/delayos/delay-winboot-helper` 는 로컬에 로그인한 활성 사용자에게 암호를 묻지 않습니다
  (`org.delayos.winboot` polkit 정책). 이 도우미는 검증된 게임 정보로 요청 파일을 쓰고 다음 부팅을 Windows로 지정하는 것만 할 수 있습니다.
  직접 추가한 게임의 경로도 Windows에서 **일반 사용자 권한**으로만 실행됩니다.

## 부팅 방식별 동작과 한계

| 환경 | 방법 | 비고 |
|---|---|---|
| UEFI (기본) | `efibootmgr --bootnext <Windows Boot Manager>` | 가장 안정적. BitLocker와 호환 |
| UEFI + systemd-boot | 위가 실패하면 `bootctl set-oneshot auto-windows` | Windows가 같은 ESP에 있어야 함. BitLocker면 차단 |
| GRUB (UEFI 대체/레거시 BIOS) | `grub-reboot <os-prober의 Windows 항목>` | `/boot`가 ext4 등 GRUB이 쓸 수 있는 파일 시스템이어야 함. BitLocker면 차단 |

- 방식을 강제하려면 `/etc/delayos/winboot.conf` 에 `method=efi|systemd-boot|grub`.
- 요청 파일 위치: UEFI는 **Windows 부팅 관리자가 있는 ESP**(`\EFI\DelayOS\winboot\request.json`).
  FAT 파티션이고 Windows가 평소 마운트하지 않으므로 빠른 시작/최대 절전과 충돌하지 않습니다. 디스크가 둘이고 ESP도 둘이어도 됩니다.
  레거시 BIOS는 ESP가 없으므로 `C:\ProgramData\DelayOS\winboot\request.json` 을 ntfs-3g로 씁니다(Windows가 깨끗하게 종료된 경우만).
- 레거시 BIOS에서는 돌아올 때 `bcdedit` 지정이 필요 없습니다(GRUB이 MBR에 있어 재시작하면 DelayOS가 기본).
  UEFI에서 DelayOS 펌웨어 항목을 찾지 못해도 DelayOS가 부팅 순서 첫 번째면 그냥 재시작으로 돌아옵니다.
- 일부 펌웨어는 `BootNext`를 무시하거나 Windows 업데이트 뒤 부팅 순서를 Windows 우선으로 바꿉니다. 이때는 BIOS에서 DelayOS를 첫 번째로 두세요.
- 연동 도우미는 설치한 Windows 계정으로 로그인할 때만 동작합니다.
- 라이브 USB로 부팅한 DelayOS에서는 Windows 게임 항목을 만들지 않습니다.

## 명령과 파일

```
delay-winboot --game <id> [--yes] [--dry-run]   전환 (--dry-run: 전환 화면만 4초 보여 줌)
delay-winboot --add [--file X.exe] | --remove <id> | --list [--json]
delay-winboot --setup                            연동 도우미 설치 안내
delay-winboot --status                           JSON 상태 (게임 목록 캐시도 갱신)
delay-winboot --session-start                    로그인 훅 (/etc/xdg/autostart/org.delayos.WinBootSync.desktop)
```

| 경로 | 역할 |
|---|---|
| `/usr/bin/delay-winboot`, `/usr/share/delayos/winboot/{wbgames.py,wbui.py,qml/}` | 사용자 쪽 (PySide6 + QML) |
| `/usr/lib/delayos/delay-winboot-helper` | root 쪽: `status`, `arm`, `disarm`, `install-helper` |
| `/usr/share/polkit-1/actions/org.delayos.winboot.policy` | 암호 없는 pkexec |
| `/usr/share/delayos/winboot/games.json` | 기본 게임 목록 |
| `/usr/share/delayos/winboot/windows/` | Windows 도우미 (`DelayOS-Windows-연동.cmd`, `install.ps1`, `agent.ps1`, `messages.ko.json`) |
| `/var/cache/delayos/winboot/` | ESP에서 읽어 온 게임 목록과 아이콘 |
| `/etc/xdg/menus/applications-merged/delayos-windows-games.menu` | 시작 메뉴 "Windows 게임" 분류 |

Windows 쪽 문제는 `C:\ProgramData\DelayOS\winboot\agent.log` 를 보세요.

개발 참고: `.ps1`은 ASCII로만 작성합니다(Windows PowerShell 5.1은 BOM 없는 파일을 ANSI로 읽음). 한국어 문구는 `messages.ko.json`(UTF-8)에 둡니다.
