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
- 게임은 Windows에 설치되어 있어야 합니다. 없으면 DelayOS Store › Windows 게임에서 설치를 시작할 수 있습니다(아래 "Windows 게임 설치").

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
| `C:\ProgramData\DelayOS\winboot\` | `agent.ps1`, `messages.ko.json`, 설정/로그, `downloads\`(설치 파일 임시 보관, 설치 후 삭제) (관리자만 쓰기 가능) |
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
   레인보우 식스 시즈, 그리고 Steam으로 설치하는 콜 오브 듀티, 배틀필드 6, EA SPORTS FC 26, F1 25, 데스티니 가디언즈,
   이스케이프 프롬 타르코프, 델타 포스, 러스트, GTA 5(종료 감지는 설치 폴더 기준). 한국어 이름, 종료 감지용 프로세스 이름, 안티치트 설명이 들어 있고, 자동 감지된 게임과 `aliases`로 합쳐집니다.
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

## Windows 게임 설치 (DelayOS Store › Windows 게임)

게임이 아직 Windows에 없어도 DelayOS에서 클릭 한 번으로 설치를 시작할 수 있습니다.
DelayOS Store 왼쪽의 **Windows 게임**(Windows와 연동 도우미가 있을 때만 보임)에서 **설치**를 누르거나
`delay-winboot --install <게임 ID>` / `delay-winboot --install-launcher <steam|epic|riot|battlenet|ea|ubisoft>` 를 실행합니다.
이미 설치된 게임은 버튼이 **플레이**로 바뀝니다. 버튼마다 "Windows로 전환해서 설치합니다. 로그인은 직접 해야 합니다."라고 적혀 있습니다.

### 솔직한 설명

- 설치는 **Windows 안에서** 일어납니다. DelayOS는 "무엇을 설치할지"만 적어 Windows로 다시 시작합니다(위의 전환과 같은 방식).
- **로그인은 대신 해 드리지 않습니다.** Riot, Epic Games, Steam 계정의 아이디·암호·2단계 인증은 Windows에서 직접 입력해야 하고,
  런처 안의 "설치" 버튼(설치 위치 확인)도 직접 눌러야 합니다. DelayOS와 도우미는 계정 정보를 다루지 않습니다.
- 설치하는 동안에는 **자동으로 돌아오지 않습니다.** 수십 GB를 내려받는 동안 PC는 Windows에 머뭅니다.
  알림 영역(트레이)의 DelayOS 아이콘과 오른쪽 아래 안내 창의 **"DelayOS로 돌아가기"** 는 언제든 쓸 수 있고,
  **"설치가 끝나면 DelayOS로 돌아가기"** 를 체크하면 설치가 끝난 것을 감지했을 때 카운트다운 후 돌아옵니다(기본은 꺼짐).
- 설치 파일은 **각 회사의 공식 서버에서만** 내려받습니다. 비공식 미러는 쓰지 않습니다.

### Windows에서 일어나는 순서

1. 로그인하면 도우미(`agent.ps1`, 1.1 이상)가 요청(`"type": "install"`)을 읽고 지운 뒤 오른쪽 아래에 안내 창을 띄웁니다.
2. 런처가 이미 있으면 내려받기를 건너뜁니다. 없으면 공식 설치 파일을 `C:\ProgramData\DelayOS\winboot\downloads`
   (관리자만 쓸 수 있는 폴더)에 내려받습니다(`curl.exe`, https만 허용, 실패하면 여러 번 다시 시도).
3. **디지털 서명 확인**: `Get-AuthenticodeSignature`의 상태가 `Valid`이고 서명자가 그 회사일 때만 실행합니다.
   아니면 파일을 지우고 "설치를 중단했습니다"라는 창을 띄웁니다. 주소의 호스트와 서명자 목록은 도우미 안에 따로 들어 있어,
   DelayOS가 보낸 요청이 잘못되어 있어도 다른 곳의 파일은 실행되지 않습니다.
4. 설치 프로그램 실행. 회사가 지원하는 경우에만 조용히 설치합니다(아래 표). 나머지는 설치 창이 뜨고 안내 창이 무엇을 누를지 알려 줍니다.
5. 런처가 설치되면 런처 안의 게임 설치를 엽니다(Steam `steam://install/<appid>`, Epic `com.epicgames.launcher://apps/<AppName>?action=install`,
   Riot `RiotClientServices.exe --launch-product=<게임> --launch-patchline=live`). 여기서 **직접 로그인**하고 설치를 누릅니다.
6. 도우미가 30초마다 설치 여부를 확인합니다. 끝나면 게임 목록(`inventory.json`)을 바로 다시 내보내므로,
   DelayOS로 돌아가면 시작 메뉴의 **Windows 게임**과 Store에 게임이 나타납니다("DelayOS로 돌아가기"를 누를 때도 목록을 한 번 더 내보냅니다).
7. 자동 다운로드가 끝내 실패하거나 주소가 없는 항목(Riot Client 단독)은 **공식 다운로드 페이지**를 기본 브라우저로 엽니다.

| 런처 | 공식 설치 파일 | 서명자 | 설치 방식 | 설치 완료 감지 |
|---|---|---|---|---|
| Steam | `cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe` | Valve Corp. | 조용히(`/S`, UAC 창 없음) | `appmanifest_<appid>.acf`의 `StateFlags`에 4(설치 완료) |
| Epic Games Launcher | `launcher-public-service-prod06.ol.epicgames.com/…/EpicGamesLauncherInstaller.msi` | Epic Games Inc. | 조용히(`msiexec /i … /qn /norestart`) | `Manifests\*.item`이 있고 `bIsIncompleteInstall`이 아님 |
| Riot (발로란트, 리그 오브 레전드) | `valorant.secure.dyn.riotcdn.net/…/live.live.kr.exe`, `lol.secure.dyn.riotcdn.net/…/live.kr.exe` (한국 서버용) | Riot Games, Inc. | 설치 창에서 직접 클릭 (조용한 설치를 지원하지 않음) | 추정: 설치 폴더가 일정 크기(발로란트 15GB, 롤 8GB) 이상이 되고 2분 동안 커지지 않음 |
| Battle.net | `downloader.battle.net/download/getInstallerForGame?…BATTLENET_APP…` | Blizzard Entertainment, Inc. | 설치 창에서 직접 클릭 | 런처 실행 파일 |
| EA app | `origin-a.akamaihd.net/EA-Desktop-Client-Download/installer-releases/EAappInstaller.exe` (ea.com의 다운로드 버튼이 가리키는 주소) | Electronic Arts, Inc. | 설치 창에서 직접 클릭 | 런처 실행 파일 |
| Ubisoft Connect | `static3.cdn.ubi.com/orbit/launcher_installer/UbisoftConnectInstaller.exe` | Ubisoft Entertainment | 설치 창에서 직접 클릭 | 런처 실행 파일 |
| Riot Client (단독) | 단독 설치 파일이 없음 → `riotgames.com/ko` 페이지를 엶 | | | |

기본 목록의 게임: 발로란트·리그 오브 레전드(Riot), 포트나이트(Epic), 배틀그라운드·에이펙스 레전드·레인보우 식스 시즈(Steam).
다른 게임은 런처를 설치한 뒤 Windows에서 직접 설치하면 다음부터 자동 감지됩니다.
주소와 설치 방법은 `/usr/share/delayos/winboot/games.json`의 `launchers`와 각 게임의 `install`에 있습니다(관리자 추가: `/etc/delayos/winboot/games.d/*.json`).
직접 추가한 게임(`~/.config`)과 Windows가 보고한 목록은 설치 요청이 될 수 없습니다(설치 프로그램은 관리자 권한으로 실행되므로 root 소유 목록만 신뢰).

### 한국어

DelayOS는 한국어 시스템이므로 설치도 한국어 기준입니다.

- Riot: 한국 공식 사이트(playvalorant.com/ko-kr, leagueoflegends.com/ko-kr)가 주는 **한국 서버용 설치 파일**을 씁니다.
- Steam: 도우미가 새로 설치할 때 `HKCU\Software\Valve\Steam\Language`를 `koreana`로 설정합니다(Steam 설치 프로그램이 쓰는 값과 같음).
  Steam으로 설치하는 게임은 기본적으로 클라이언트 언어를 따릅니다. 이미 Steam이 설치되어 있으면 사용자가 고른 언어를 바꾸지 않습니다.
- 강제할 수 없는 것: Epic Games Launcher, Battle.net, EA app, Ubisoft Connect는 **Windows 표시 언어**를 따르며 지원되는 언어 지정 방법이 없습니다
  (DelayOS가 자동 설치한 Windows는 한국어이므로 한국어로 나옵니다). Riot Client와 게임 안의 언어는 계정 지역/클라이언트 설정을 따릅니다.
  다른 언어로 나오면 각 런처의 설정 › 언어에서 바꾸세요.
- 다운로드 페이지를 여는 경우에도 한국어 페이지(`/ko-kr`, `?l=koreana`)를 엽니다.

### 안티치트 요구 사항

Store의 Windows 게임 화면과 설치 확인 창은 이 PC의 **TPM 2.0 / Secure Boot 상태**를 보여 줍니다
(`delay-winboot --status`의 `requirements`: `tpm2`, `secureBoot`, `win11`. 같은 메인보드이므로 DelayOS에서 읽은 값이 Windows에도 적용됩니다).

| 게임 | 안티치트 | Windows 11에서 필요한 것 |
|---|---|---|
| 발로란트 | Riot Vanguard | TPM 2.0 + Secure Boot (없으면 VAN9001/9003). Vanguard 설치 후 Windows를 한 번 다시 시작해야 함 |
| 리그 오브 레전드 | Riot Vanguard | TPM 2.0 (Secure Boot 권장) |
| 포트나이트 | Easy Anti-Cheat / BattlEye | 일반 플레이는 없음. 대회 참가에는 TPM 2.0 + Secure Boot |
| 배틀그라운드, 에이펙스 레전드, 레인보우 식스 시즈 | BattlEye / Easy Anti-Cheat | 없음 |

요구 사항이 꺼져 있는 게임의 설치를 누르면 바로 전환하지 않고 확인 창에서 먼저 알려 줍니다. 그 밖에는 "전환 전에 확인" 설정을 따릅니다(기본: 바로 전환).

### 도우미 버전

게임 설치에는 Windows 도우미 **1.1 이상**이 필요합니다. 1.0이 설치된 PC에서 설치를 누르면 DelayOS가 새 설치 파일을 준비하고
"Windows 연동 도우미를 업데이트해야 합니다" 안내를 띄웁니다. Windows에서 `DelayOS-Windows-연동.cmd`(또는 `setup.cmd`)를 다시 실행해
`1`(다시 설치/업데이트)을 고르면 됩니다. 1.0 도우미는 설치 요청을 무시합니다(요청에 `launch` 항목이 없기 때문).

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
  DelayOS가 직접 설치한 Windows(아래 "Windows 게임 지원")에서는 자동으로 되돌립니다: Windows 도우미가 로그온할 때마다
  (`config.json`의 `delayos_first`), DelayOS는 켜질 때마다(`delay-winsetup-finalize.service`) DelayOS를 부팅 순서 첫 번째로 다시 둡니다.
  직접 설치한 일반 듀얼 부팅 PC의 부팅 순서는 건드리지 않습니다.
- 연동 도우미는 설치한 Windows 계정으로 로그인할 때만 동작합니다.
- 라이브 USB로 부팅한 DelayOS에서는 Windows 게임 항목을 만들지 않습니다.

## 명령과 파일

```
delay-winboot --game <id> [--yes] [--dry-run]   전환 (--dry-run: 전환 화면만 4초 보여 줌)
delay-winboot --install <id> [--yes]            Windows로 전환해서 기본 목록의 게임을 설치
delay-winboot --install-launcher <런처> [--yes]  런처만 설치 (steam|epic|riot|battlenet|ea|ubisoft)
delay-winboot --store-json                      Store의 Windows 게임 화면 데이터 (root 불필요)
delay-winboot --add [--file X.exe] | --remove <id> | --list [--json]
delay-winboot --setup                            연동 도우미 설치 안내
delay-winboot --status                           JSON 상태 (게임 목록 캐시도 갱신)
delay-winboot --session-start                    로그인 훅 (/etc/xdg/autostart/org.delayos.WinBootSync.desktop)
```

| 경로 | 역할 |
|---|---|
| `/usr/bin/delay-winboot`, `/usr/share/delayos/winboot/{wbgames.py,wbui.py,qml/}` | 사용자 쪽 (PySide6 + QML) |
| `/usr/lib/delayos/delay-winboot-helper` | root 쪽: `status`, `arm` (`--install`, `--install-launcher`), `disarm`, `install-helper` |
| `/usr/share/polkit-1/actions/org.delayos.winboot.policy` | 암호 없는 pkexec |
| `/usr/share/delayos/winboot/games.json` | 기본 게임 목록 + 설치 정보(`launchers`, `install`) |
| `/usr/share/delayos/apps/store/` (`storeback.wingames`, `qml/main.qml`) | Store의 Windows 게임 화면 (`delay-store --windows`) |
| `/usr/share/delayos/winboot/windows/` | Windows 도우미 (`DelayOS-Windows-연동.cmd`, `install.ps1`, `agent.ps1`, `messages.ko.json`) |
| `/var/cache/delayos/winboot/` | ESP에서 읽어 온 게임 목록과 아이콘 |
| `/etc/xdg/menus/applications-merged/delayos-windows-games.menu` | 시작 메뉴 "Windows 게임" 분류 |

Windows 쪽 문제는 `C:\ProgramData\DelayOS\winboot\agent.log` 를 보세요.

개발 참고: `.ps1`은 ASCII로만 작성합니다(Windows PowerShell 5.1은 BOM 없는 파일을 ANSI로 읽음). 한국어 문구는 `messages.ko.json`(UTF-8)에 둡니다.

---

# Windows 게임 지원: 보이지 않는 Windows 자동 설치 (delay-winsetup)

위의 Windows 전환은 **이미 Windows가 설치된 PC**가 전제입니다. Windows가 없는 PC(또는 디스크를 통째로 DelayOS에 쓰는 설치)에서는
설치 프로그램의 **"Windows 게임 지원"** 옵션이 DelayOS 옆에 실제 Windows 11을 자동으로 설치해 줍니다.
사용자는 듀얼 부팅을 직접 다루지 않습니다. Windows 파티션은 DelayOS 파일 탐색기에 보이지 않고, 부팅 메뉴에도 나오지 않으며,
Windows로 가는 길은 시작 메뉴의 Windows 게임(= 위의 Windows 전환)뿐입니다.

## 솔직한 설명

- 가상 머신이 아니라 **진짜 Windows 11**을 별도 파티션에 설치합니다. 그래서 커널 안티치트 게임이 실행됩니다.
- 디스크 공간을 씁니다: Windows 파티션(기본 100GB, 최소 64GB) + 설치하는 동안만 쓰는 임시 파티션 10GB(끝나면 DelayOS로 되돌림).
- Windows 설치 파일(약 6~7GB)은 **Microsoft 공식 서버에서만** 내려받습니다(microsoft.com의 소프트웨어 다운로드 API, 한국어 64비트).
  Microsoft가 공개한 SHA-256과 일치하는지 확인하고, 다르면 버립니다. 비공식 미러는 쓰지 않습니다.
- 전환은 여전히 재시작입니다(갈 때 한 번, 올 때 한 번). 메인보드 로고는 숨길 수 없습니다.
- Windows 라이선스는 DelayOS가 주지 않습니다. 아래 "정품 인증"을 읽어 주세요.

## 필요한 것

| 조건 | 이유 |
|---|---|
| UEFI 부팅 | 레거시 BIOS에서는 설치하지 않습니다 |
| TPM 2.0 (`/sys/class/tpm/tpm0`, `tpm_version_major` = 2) | Windows 11과 Vanguard(발로란트)의 요구 사항. 없으면 옵션을 켤 수 없습니다. BIOS에서 fTPM/PTT를 켜세요 |
| GPT 디스크, Windows + 10GB + DelayOS 20GB 이상의 공간 | |
| 인터넷 (또는 직접 가지고 있는 Windows ISO, 아래 "직접 가지고 있는 Windows ISO 쓰기") | 설치 파일 다운로드 |
| 디스크 암호화(LUKS)를 쓰지 않는 설치 | 암호화된 설치에서는 이 옵션을 건너뜁니다 |
| **Secure Boot** | 발로란트(Vanguard)는 Windows 11에서 Secure Boot가 **켜져 있어야** 실행됩니다. 아래 "Secure Boot" 참고 |

같은 EFI 시스템 파티션에 이미 Windows 부팅 파일이 있으면(기존 Windows를 남긴 설치) 아무것도 건드리지 않고 건너뜁니다.
그 Windows는 위의 Windows 전환으로 그대로 쓸 수 있습니다.

## 정품 인증 (정식 방법만 사용)

DelayOS는 KMS 에뮬레이터나 인증 우회 도구를 쓰지 않으며 앞으로도 넣지 않습니다. 인증되는 길은 세 가지입니다.

1. **PC에 내장된 정품 키 (OEM)**: Windows가 설치된 채로 판매된 PC는 메인보드 펌웨어(ACPI `MSDM` 표)에 제품 키가 들어 있습니다.
   설치 프로그램이 이를 찾으면 "PC에 내장된 Windows 정품 키를 찾았습니다"라고 알려 줍니다. 그 PC에 원래 들어 있던 에디션(대부분 Home)을
   고르면 Windows가 그 키를 직접 읽어 인터넷에 연결될 때 자동으로 인증됩니다. DelayOS는 이 키를 파일에 적거나 기록하지 않습니다
   (Windows 안에서 `slmgr /ipk`로 Windows가 읽은 키를 등록할 뿐입니다). 에디션이 다르면 등록에 실패하고 인증되지 않습니다.
2. **디지털 라이선스**: 이 PC에서 같은 에디션의 Windows 10/11이 정품 인증된 적이 있으면, 키가 없어도 인터넷에 연결될 때
   Microsoft 서버가 하드웨어를 알아보고 자동으로 인증합니다.
3. **제품 키 직접 입력**: 설치 프로그램에 입력한 키는 Windows 첫 로그인 때 `slmgr /ipk`로 등록되고, 임시 파일은 바로 지워집니다.
   나중에 Windows 설정 › 시스템 › 정품 인증에서 입력해도 됩니다.

어느 것도 해당하지 않으면 **인증되지 않은 Windows**가 설치됩니다. 게임은 실행되지만 화면 구석에 "Windows 정품 인증" 표시가 나오고
배경·색·테마 같은 개인 설정을 바꿀 수 없으며, 설정에 인증 안내가 계속 나옵니다. 사용 조건은 Microsoft 라이선스를 따릅니다.

참고: 자동 설치 파일에는 Microsoft가 공개한 **설치용 일반 키**(에디션 선택용, 인증되지 않음)만 들어갑니다.

## 설치 과정

1. 설치 프로그램 › 소프트웨어 단계 다음의 **"Windows 게임도 하시나요?"** 에서 스위치를 켭니다(기본은 끔).
   Windows에 줄 공간, 에디션(Home/Pro, 한국어), 선택 사항인 제품 키, 게이밍 정리(기본 켬), 직접 가지고 있는 ISO 경로를 정합니다.
2. "지금 설치"를 누르면 DelayOS가 평소처럼 설치되고, 그 과정에서
   - 새로 만든(아직 비어 있는) DelayOS 파티션의 **끝부분**을 줄여 `DelayOS-WinSetup`(FAT32, 10GB)과 `DelayOS-Windows` 파티션을 만들고,
   - Windows 11 ISO를 내려받아 임시 파티션에 풀고(4GB가 넘는 `install.wim`은 wimlib으로 나눔), 자동 설치 스크립트를 넣고,
   - 다음 한 번만 Windows 설치 환경으로 부팅하도록 지정합니다(펌웨어 항목 "DelayOS Windows Setup" + `BootNext`).
3. 마지막 화면: "다시 시작하면 Windows 게임 지원을 자동으로 준비합니다 (약 20~40분, 컴퓨터를 끄지 마세요)".
4. 다시 시작하면 검은 화면에 진행 상황이 나옵니다(Windows PE). 묻는 것은 없습니다. 이미지 적용 → 재시작 →
   (DelayOS가 잠깐 켜졌다가 스스로 Windows로 넘김) → Windows가 장치를 준비하고 재시작 → `DelayOS` 계정으로 자동 로그인 →
   연동 도우미 설치 → DelayOS로 재시작. 중간에 DelayOS 시작 화면이 한두 번 잠깐 보이는 것은 정상입니다.
5. DelayOS가 켜질 때 `delay-winsetup-finalize.service`가 임시 파티션을 지워 DelayOS에 돌려주고, 설치용 부팅 항목을 지우고,
   GRUB/systemd-boot 메뉴에서 Windows를 숨깁니다. "Windows Boot Manager" 펌웨어 항목은 Windows 전환이 쓰므로 남깁니다.

설치되는 Windows의 설정:

- 한국어, 한국어 키보드(Microsoft 입력기), 표준 시간대 Asia/Seoul. 하드웨어 시계는 DelayOS와 같이 UTC로 읽습니다(`RealTimeIsUniversal`).
- 암호 없는 로컬 관리자 계정 **DelayOS**, 자동 로그인. Microsoft 계정이나 네트워크 연결을 요구하지 않습니다(`BypassNRO`).
  암호가 없으므로 PC를 켠 사람은 누구나 그 Windows를 쓸 수 있습니다(Windows는 암호 없는 계정의 네트워크 로그온을 기본으로 막습니다).
  원하면 Windows에서 암호를 설정하세요. 그러면 전환할 때 암호를 한 번 입력해야 합니다.
- 개인정보 관련 선택 항목은 모두 끔(선택적 진단 데이터, 광고 ID, 맞춤형 환경, 추천 앱, 위치).
- **VBS + 메모리 무결성(HVCI) 켬.** 일부 안티치트가 요구하거나 권장합니다. 대신 Windows 게임 성능이
  조금(보통 몇 %, CPU와 게임에 따라 더) 낮아질 수 있습니다. 끄려면 Windows 보안 › 장치 보안 › 코어 격리 › 메모리 무결성.
  CPU 가상화(VT-x/AMD-V, SLAT)가 BIOS에서 꺼져 있으면 Windows가 스스로 켜지 않습니다.
- **BitLocker/장치 암호화 끔**(`PreventDeviceEncryption`), **빠른 시작과 최대 절전 끔**. EFI 파티션과 펌웨어를 DelayOS와 같이 쓰기 때문입니다.
- 연동 도우미 설치(`install.ps1 -Unattended`): 로그온 작업, 부팅 로고 숨김, "DelayOS로 돌아가기" 바로 가기.

게임과 런처(Riot Client, Steam, Epic 등)는 DelayOS Store › **Windows 게임**에서 설치를 시작할 수 있습니다(위의 "Windows 게임 설치"; 로그인은 직접).
그 밖의 프로그램은 설정 › 앱 지원 › Windows 전환으로 Windows에 들어가 설치하세요. 그 Windows에는 메인보드/그래픽 드라이버도 Windows 업데이트나
제조사 사이트에서 설치해야 합니다(유선 LAN 드라이버가 없는 메인보드는 처음에 인터넷이 안 될 수 있습니다).

## 게이밍 정리

Microsoft 공식 Windows 11 이미지는 게임과 상관없는 앱과 백그라운드 기능이 많습니다. 숨은 Windows는 안티치트 게임을 돌리는 것이 유일한 일이므로,
설치 프로그램의 **"게이밍 정리"**(기본 켬)가 자동 설치 도중에 이를 정리합니다. 이미지 파일 자체는 건드리지 않고(Microsoft가 준 그대로 적용),
설치된 Windows 안에서 **문서화된 설정만** 바꿉니다: 정책 레지스트리 값, 사용자 설정, 서비스 시작 유형, 예약된 작업, 프로비저닝된 Store 앱 제거.
시스템 파일을 지우거나 구성 요소 저장소에서 기능을 뜯어내지 않습니다. 그래서 Windows 업데이트와 안티치트가 그대로 동작하고, 되돌릴 수 있습니다.

끄거나 지우는 것 (`/usr/share/delayos/winsetup/cleanup.ps1`):

| 분류 | 내용 |
|---|---|
| 기본 앱 (프로비저닝된 Store 앱 제거) | Clipchamp, 뉴스, 날씨, Bing 검색, 도움말, 팁, Microsoft 365(Office 허브), 솔리테어, 스티커 메모, 피플, Power Automate, To Do, 피드백 허브, 지도, 영화 및 TV, 휴대폰과 연결, Cortana, Copilot, Dev Home, 새 Outlook, 메일/일정, Teams(개인용), 가족, 빠른 지원, 위젯(Web Experience) 등. 목록에 **정확히 있는 이름만** 지웁니다 |
| 소비자 기능 | 추천 앱 자동 설치(캔디 크러시류), 시작 메뉴·설정·잠금 화면의 추천/광고/팁, "장치 설정 마무리" 안내, 맞춤형 환경, 광고 ID |
| OneDrive | 새 계정에 설치되지 않게 함(기본 프로필의 `OneDriveSetup` 시작 항목 제거 + 정책 `DisableFileSyncNGSC`) |
| Copilot · Recall · Click to Do | 정책으로 끔 (`TurnOffWindowsCopilot`, `DisableAIDataAnalysis`, `AllowRecallEnablement=0`, `DisableClickToDo`) |
| 위젯 · 뉴스 · 채팅 아이콘 | 정책으로 끔 (`AllowNewsAndInterests=0` 등), 검색의 웹 결과와 "검색 하이라이트" 끔 |
| 진단 데이터 | 이 에디션이 허용하는 **최소 수준**(`AllowTelemetry=0`; Home/Pro에서는 "필수 진단 데이터"), 피드백 알림·CEIP 끔, 서비스 `DiagTrack`·`dmwappushservice` 사용 안 함 |
| 잠금 화면 · 첫 로그인 애니메이션 | 끔 (자동 로그인이라 필요 없음) |
| 시작 프로그램 | OneDrive, Edge 자동 실행, Teams 시작 항목 제거. Edge의 시작 부스트/백그라운드 실행 끔(Edge와 WebView2는 **그대로 설치되어 있음**). 시작 프로그램 지연 제거 |
| 예약된 작업 | CEIP(Consolidator, UsbCeip), 호환성 평가(Compatibility Appraiser, ProgramDataUpdater, MareBackup), 디스크 진단 데이터 수집, 피드백(Siuf), 지도 업데이트 |
| 서비스 (사용 안 함) | `DiagTrack`, `dmwappushservice`, `MapsBroker`, `RetailDemo`, `Fax`, `WMPNetworkSvc`. 이 여섯 개뿐입니다 |
| 저장 공간 | 최대 절전 끔(`hiberfil.sys` 없음), 예약된 저장소 끔(약 6GB 확보, `DISM /Set-ReservedStorageState`), 배달 최적화의 다른 PC로 업로드 끔 |
| Game Bar | 백그라운드 녹화/캡처 끔(`AllowGameDVR=0`). Game Bar 앱과 **게임 모드는 그대로** |

건드리지 않는 것 (스크립트 맨 위에 적혀 있고, 앱 제거에는 이중 안전장치 `$AppxKeep`가 있습니다):

- **TPM, Secure Boot, VBS/메모리 무결성(HVCI)**: 위의 설치 설정대로 켜진 채.
- **Windows 보안(Microsoft Defender), SmartScreen, 방화벽**: 일부 안티치트가 상태를 확인하므로 손대지 않습니다. 예외 경로도 추가하지 않습니다.
- **Windows 업데이트**와 그 서비스(`wuauserv`, `UsoSvc`, `WaaSMedicSvc`, `BITS`, `DoSvc`): 보안 업데이트와 안티치트가 요구하는 빌드를 받아야 합니다.
- **WMI(`Winmgmt`), 작업 스케줄러, 이벤트 로그** 등 기본 서비스 전부. Vanguard(`vgc`/`vgk`), Easy Anti-Cheat, BattlEye 서비스는 게임이 설치하며 영향을 받지 않습니다.
- **Microsoft Store, Xbox 앱(Game Pass), Xbox 서비스, Gaming Services, 앱 설치 관리자(winget)**, VC++/.NET/DirectX/WebView2/Edge.
- 메모장, 계산기, 그림판, 사진, 터미널, 캡처 도구, 미디어 플레이어 같은 기본 도구.

확인과 되돌리기 (Windows에서):

- 무엇을 바꿨는지: `C:\ProgramData\DelayOS\winsetup\cleanup-state.json`(바꾸기 전 값 포함), `cleanup.log`.
- 현재 상태(디스크·메모리·프로세스 수, TPM/Secure Boot/VBS/Defender 상태)를 JSON으로:
  `powershell -ExecutionPolicy Bypass -File C:\ProgramData\DelayOS\winsetup\cleanup.ps1 -Phase Report`
- **되돌리기**: `C:\ProgramData\DelayOS\winsetup\cleanup-undo.cmd`를 실행(관리자 권한을 묻습니다). 레지스트리 값·서비스·예약된 작업을 바꾸기 전 값으로
  되돌리고, 지운 앱의 목록을 보여 줍니다. 지운 앱은 Microsoft Store에서 다시 설치합니다. 최대 절전과 빠른 시작은 듀얼 부팅 때문에 꺼진 채로 둡니다.
- 설치할 때 건너뛰었는데 나중에 적용하려면 관리자 PowerShell에서 같은 스크립트를 `-Phase Machine`, 이어서 `-Phase User`로 실행하고 다시 시작합니다.
- DelayOS에서: `delay-winsetup status`가 "게이밍 정리: 적용됨/적용 안 함"을 보여 줍니다.

게이밍 정리를 적용하지 않는 경우: 설치 프로그램에서 스위치를 끈 경우(`--cleanup off`), 그리고 **Microsoft 공식 파일로 확인되지 않은 ISO**를 쓴 경우(아래).

## 직접 가지고 있는 Windows ISO 쓰기

설치 프로그램의 "Windows ISO 파일을 이미 가지고 있다면" 칸이나 `sudo delay-winsetup retry --iso <경로>`에 다음 중 하나를 줄 수 있습니다.

- ISO 파일 (`/run/media/…/Win11.iso`)
- 디스크가 들어 있는 광학 드라이브나 ISO를 기록한 USB 파티션 (`/dev/sr1`). 설치 프로그램은 찾은 드라이브를 버튼으로 보여 줍니다.
- ISO 내용을 풀어 둔 폴더 (`sources/`가 있는 폴더)

직접 지정한 ISO에는 **Microsoft의 SHA-256을 요구하지 않습니다.** 대신 인터넷이 되면 Microsoft 다운로드 페이지에 공개된 SHA-256 목록(모든 언어)과
비교해서(드라이브에 든 디스크나 USB는 ISO 이미지 크기만큼만 읽어 같은 방식으로 확인합니다):

- 일치하면 **공식 파일로 확인됨** → 내려받은 것과 똑같이 취급하고 게이밍 정리를 적용합니다.
- 일치하지 않거나 비교할 수 없으면(수정된 ISO, 직접 만든 ISO, 폴더, 오프라인) **확인 없이 그대로 사용**하고, 설치 프로그램의 마지막 화면과
  `/var/log/delayos-winsetup.log`, `delay-winsetup status`에 그 사실을 경고로 남깁니다. 그 이미지가 믿을 만한지는 사용자가 판단해야 합니다.
  이런 이미지는 이미 만든 사람이 정리해 둔 것으로 보고 **게이밍 정리를 건너뜁니다**(설치 프로그램의 "확인되지 않은 ISO에도 게이밍 정리 적용" 또는 `--cleanup on`으로 켤 수 있음).

수정된(커스텀) ISO에서 달라지는 점과 DelayOS가 처리하는 방식:

| 상황 | 처리 |
|---|---|
| `install.wim` / `install.esd` / 이미 나뉜 `install.swm` | 모두 지원. 4GB가 넘는 `install.wim`은 나누고, 4GB가 넘는 `install.esd`(나눌 수 없음)나 준비 파티션에 다 들어가지 않는 ISO는 설치할 이미지 하나만 임시로 내보내서 씁니다 |
| 이미지가 하나뿐이거나 에디션 이름이 다른 ISO | 고른 에디션(Home/Pro)의 `EDITIONID`가 있으면 그것, 없고 이미지가 하나뿐이면 그 이미지, 그다음 이미지 이름으로 고릅니다. 직접 고르려면 `--index <번호>` 또는 `--image-name <이름>`. 고르지 못하면 들어 있는 이미지 목록을 보여 주고 멈춥니다 |
| 에디션이 Home/Pro가 아닌 이미지 | 자동 설치 파일에 설치용 일반 키를 넣지 않습니다(다른 에디션의 키를 넣으면 Windows 설치가 실패하므로). 이미지에 들어 있는 키/에디션 그대로 설치됩니다 |
| ISO에 들어 있는 `autounattend.xml`, `sources\$OEM$` | 쓰지 않습니다. DelayOS는 Windows 설치 프로그램(setup.exe)을 실행하지 않고 이미지를 직접 적용하기 때문입니다 |
| ISO의 설치 환경(Windows PE)이 **자체 설치 프로그램**을 띄우도록 바뀐 경우 (`winpeshl.exe`를 바꿔치기했거나 레지스트리의 `Setup\CmdLine`을 바꾼 ISO) | 그대로 두면 DelayOS 스크립트 대신 그 설치 프로그램이 실행되어 디스크를 직접 나누려고 할 수 있습니다. DelayOS는 준비 단계에서 부팅 이미지를 검사해, 표준 셸(1MB 미만의 `winpeshl.exe`)이 아니면 부팅 이미지 레지스트리의 `Setup\CmdLine`을 제자리에서 `cmd /c d.cmd`(DelayOS 스크립트)로 바꿉니다. 바꿀 수 없으면 그 ISO를 **거부**합니다(디스크는 건드리지 않음) |
| 첫 실행 화면(OOBE)을 빼거나 바꾼 이미지 | 확인되지 않은 이미지에는 응답 파일에 `SkipMachineOOBE`/`SkipUserOOBE`를 넣어 첫 실행 화면을 통째로 건너뜁니다(없으면 "왜 PC가 다시 시작되었나요?" 화면에서 멈춤). 계정은 응답 파일이 만듭니다. Microsoft 공식 이미지에는 넣지 않습니다 |
| Windows PE에 한국어 콘솔 글꼴(굴림체, `gulim.ttc`)이 없는 ISO | 설치 중 검은 화면의 진행 문구가 영어로 나옵니다(한글이 빈 네모로 보이는 것을 피함). 맑은 고딕만 들어 있는 설치 환경도 여기에 해당합니다(콘솔 창은 굴림체로 그립니다) |
| 이미지 **안에** 들어 있는 응답 파일 (`Windows\Panther\Unattend\`, `Windows\Panther\unattend.xml`, `Windows\System32\Sysprep\unattend.xml`, `C:\unattend.xml`, 레지스트리의 `Setup\UnattendFile`) | Windows가 DelayOS의 응답 파일보다 먼저 읽을 수 있으므로 `*.iso-bak`으로 이름을 바꿔 **옆에 보관**하고 DelayOS의 응답 파일(계정 `DelayOS`, 자동 로그인, 연동 도우미)이 쓰이게 합니다 |
| 이미지의 `SetupComplete.cmd`, `OOBE.cmd`, 레지스트리에 미리 넣어 둔 설정, 미리 설치된 프로그램 | **그대로 동작합니다.** 이미지 고유의 설정과 DelayOS의 설정이 함께 적용됩니다 |
| PowerShell 모듈, Defender, 정품 인증 WMI 등이 빠진 이미지 | `finish.ps1`과 연동 도우미는 단계마다 따로 실패를 넘깁니다(예: 작업 등록은 `schtasks.exe`로 대체). 건너뛴 단계는 `done.json`의 `skipped`와 `delay-winsetup status`에 나옵니다. 연동 도우미만 설치되면 성공으로 봅니다 |
| PowerShell 자체가 없는 이미지, 64비트가 아닌 이미지 | 준비 단계에서 거부합니다 |
| 한국어가 아닌 이미지 | 설치는 됩니다. 부팅 파일 언어와 표시 언어는 이미지의 것을 따릅니다 |

주의할 점:

- 수정된 ISO에서 **Windows 업데이트, Defender, 메모리 무결성 등을 뺀 경우** 그 상태가 그대로 설치됩니다. 안티치트(특히 Vanguard)는 그런 Windows를
  거부할 수 있습니다. DelayOS는 빠진 것을 되살리지 않습니다.
- sysprep으로 일반화되지 않은 이미지(이미 사용자가 만들어진 이미지)는 자동 설치가 끝나지 않을 수 있습니다. 그러면 DelayOS가 몇 번 넘겨준 뒤
  "설치 실패"로 표시하고 켜진 채로 남습니다(`sudo delay-winsetup retry --iso …` 또는 `remove`).
- 수정된 Windows 이미지의 재배포는 Microsoft 라이선스가 허용하지 않습니다. 이 기능은 **자기 PC에 자기 ISO를 쓰는 경우**를 위한 것이고,
  DelayOS는 어떤 Windows 이미지도 포함하거나 배포하지 않습니다.

## 개인용 ISO에 Windows ISO 넣기 (배포 금지)

자기 PC에만 쓸 **개인용 DelayOS ISO**에는 가지고 있는 Windows 설치 ISO를 함께 넣어 둘 수 있습니다. 그러면 설치 프로그램의 "Windows 게임 지원"이
그 ISO를 바로 쓰고 아무것도 내려받지 않습니다(인터넷이 없어도 됩니다).

> **이렇게 만든 ISO는 배포할 수 없습니다.** Windows 이미지(다른 회사의 소프트웨어)가 들어 있으므로 올리거나, 공유하거나, 릴리스에 붙이거나,
> 저장소에 커밋하면 안 됩니다. DelayOS 저장소와 공식 ISO에는 어떤 Windows 이미지도 들어 있지 않고, 여기에는 넣는 방법만 있습니다.

만들기(빌드한 PC에서 root로, `build.sh`가 만든 ISO를 가지고):

```
sudo tools/make-personal-iso.sh --iso out/delayos-YYYY.MM.DD-x86_64.iso \
     --winiso /경로/Windows.iso --out /저장소-밖의-폴더/delayos-YYYY.MM.DD-x86_64-personal.iso
```

- Windows ISO가 라이브 미디어의 `/windows/<파일 이름>`으로 들어갑니다. 나머지(BIOS 부팅, UEFI Secure Boot 부팅 경로, 볼륨 UUID와 레이블)는
  원래 ISO와 똑같습니다. 4GB가 넘는 ISO도 넣을 수 있습니다.
- 스크립트는 결과를 **저장소 안에 쓰는 것을 거부**하고, 파일 이름에 `personal`이 들어가야 합니다. `.gitignore`와 `build.sh`는 그 이름을 건너뜁니다.
  끝나면 SHA-256과 배포 금지 경고를 출력합니다.
- USB에 쓸 때는 ISO 이미지를 그대로 기록하세요(`dd`, Rufus의 DD 모드). 파일을 복사하는 방식(FAT32)은 4GB가 넘는 파일을 담지 못합니다.

설치할 때:

- 설치 프로그램을 열 때 `delay-winsetup probe`가 라이브 미디어의 `/windows/*.iso`를 찾습니다. 라이브 시스템이 RAM으로 복사되어(copytoram) 미디어가
  분리된 경우에는 미디어를 읽기 전용으로 다시 연결해서 찾습니다. **설치가 끝날 때까지 USB를 뽑지 마세요.**
- "Windows 게임" 단계에서 ISO 칸이 그 파일로 **미리 채워져 있고** "USB에 들어 있는 Windows ISO 사용" 버튼이 선택되어 있습니다.
  "Windows 게임 지원 설치"만 켜면 됩니다. 버튼을 다시 눌러 칸을 비우면 평소처럼 Microsoft에서 받습니다.
- 그 뒤는 위의 "직접 가지고 있는 Windows ISO 쓰기"와 같습니다: Microsoft가 공개한 SHA-256과 일치하면 공식 파일로 확인하고, 일치하지 않으면
  확인되지 않은 ISO라는 경고를 남기고 그대로 쓰며 게이밍 정리는 건너뜁니다("확인되지 않은 ISO에도 게이밍 정리 적용"으로 켤 수 있음).
- 설치된 시스템에서 나중에 다시 시도할 때(`delay-winsetup retry`)는 미디어의 ISO를 자동으로 찾지 않습니다. USB를 꽂고 `--iso <경로>`로 지정하세요.

## Secure Boot

Secure Boot는 PC 전체에 하나뿐인 펌웨어 설정입니다. 발로란트를 하려면 켜야 하고, 켜면 DelayOS도 서명된 부트로더와 커널로 부팅해야 합니다.

- **Secure Boot 지원 빌드**(ISO를 만들 때 DelayOS 일반 서명 키가 있었던 경우): 설치 프로그램이 Microsoft가 서명한 shim →
  DelayOS 일반 키로 서명한 GRUB → 서명한 `linux-delayos` 순서로 부팅되게 구성합니다. DelayOS 일반 CA의 MOK 등록은
  **자동 Windows 설치가 모두 끝난 뒤에** 요청합니다(설치 도중에 요청하면 아무도 없는 사이에 10초짜리 화면이 지나가 버립니다).
  Windows 준비가 끝나고 DelayOS에 로그인하면 안내 창이 나오고, **그다음에 PC를 다시 시작할 때**
  **파란 화면(MOK 관리, 영어)** 이 한 번 나옵니다:
  `Enroll MOK` → `Continue` → `Yes` → 암호 **`delayos`** 입력 → `Reboot`. (10초 안에 아무 키나 눌러야 합니다. 놓쳤으면
  `sudo delay-winsetup sb-setup` 후 다시 시작.) 그다음 BIOS에서 Secure Boot를 켜세요. 등록 전에 Secure Boot를 켜면 DelayOS가
  시작되지 않습니다. 켠 뒤에는:
  - `linux-delayos`만 부팅됩니다. 예비 커널 `linux-lts`와 직접 설치한 커널은 서명이 없어 부팅되지 않습니다.
  - 서명되지 않은 모듈(NVIDIA DKMS 등)은 그대로 로드됩니다(일반 커널은 잠금 모드를 강제하지 않음).
- **Secure Boot 미지원 빌드**: 설치 프로그램에 "Secure Boot 미지원 빌드"라고 나옵니다. 설치는 되지만 Secure Boot를 켜면 DelayOS가
  부팅되지 않으므로 꺼 둔 채 써야 하고, 그러면 **발로란트는 Windows 11에서 실행을 거부합니다**(Vanguard 오류 VAN9001/9003 등).
  리그 오브 레전드, 포트나이트, 배틀그라운드 등은 대부분 Secure Boot 없이 실행됩니다.
- DelayOS **설치 USB도 같은 키로 서명되어 있어 Secure Boot를 켠 채로 부팅됩니다**([secure-boot.md](secure-boot.md)). USB로 처음 부팅할 때 파란 화면에서 `Enroll key from disk` → `delayos-general-ca.cer`로 DelayOS 키를 등록하면, 그 PC에서는 위의 MOK 등록(암호 `delayos`)을 다시 하지 않아도 되고 설치 뒤에 BIOS에서 할 일도 없습니다. Secure Boot를 끈 채로 설치했다면 위 순서(등록 → BIOS에서 켜기)를 따릅니다.

**EAC Linux v2(안티치트 모드, `docs/eac-linux-v2.md`)와의 관계:** 일반 키는 안티치트 키와 **다른 CA**입니다. 안티치트 키는 잠금 모드가 강제된
`linux-delayos-eac`만 서명한다는 약속을 지키기 위해서입니다. 그 대신 Epic의 "등록된 MOK는 모두 잘 알려진 키여야 한다"는 규칙 때문에,
일반 CA가 MOK에 들어 있는 동안에는 Linux 쪽 EAC v2 조건을 채울 수 없습니다(`delay-eac status`에 알 수 없는 MOK로 표시).
Linux에서 EAC v2 게임을 하려면 `sudo mokutil --delete /usr/share/delayos/secureboot/general/delayos-general-ca.cer`로 일반 CA를 빼고
안티치트 항목으로만 부팅해야 합니다. 보이지 않는 Windows가 있는 PC에서는 EAC 게임도 Windows에서 하는 쪽이 간단합니다.

## 안전 장치와 실패했을 때

- DelayOS 루트 파티션이 있는 디스크만, 그 파티션에서 방금 떼어 낸 공간만 사용합니다. 다른 디스크와 기존 파티션은 건드리지 않습니다.
  이후 단계는 파티션 GUID와 이름(`DelayOS-WinSetup`, `DelayOS-Windows`)이 모두 맞을 때만 진행합니다.
- Windows PE 쪽 스크립트는 이번 설치의 무작위 ID가 적힌 표식 파일이 있는 볼륨 하나만 포맷하고, 같은 ID가 있는 EFI 파티션에만 부팅 파일을 씁니다.
  Windows 설치 프로그램의 디스크 선택 기능은 쓰지 않습니다(DISM으로 이미지를 적용).
- DelayOS는 부팅 순서의 첫 번째로 남습니다(Windows 부팅 항목은 DelayOS가 맨 뒤에 추가). 설치 중에 PC가 다시 시작될 때마다 DelayOS의
  `delay-winsetup-finalize.service`가 로그인 화면이 뜨기 전에 "다음 한 번만 Windows로"(`BootNext`, Windows 전환과 같은 방식)를 지정하고
  바로 다시 시작합니다. 이 넘겨주기는 최대 6번까지만 하므로, Windows가 끝내지 못하면 **DelayOS가 켜진 채로 멈춥니다.**
- 실패하면 DelayOS 로그인 때 알림이 나옵니다. DelayOS는 정상입니다.
  - 다시 시도: `sudo delay-winsetup retry` (필요하면 `--iso /경로/Win11.iso`, `--edition pro`, `--index N`, `--image-name 이름`, `--cleanup on|off`) 후 다시 시작
  - 제거하고 공간 되돌리기: `sudo delay-winsetup remove`
  - 상태: `delay-winsetup status` / 미리 보기(아무것도 바꾸지 않음): `sudo delay-winsetup --dry-run retry`
- Windows 화면에서 멈춘 채 DelayOS로 돌아오지 않으면 전원 버튼으로 끄고 다시 켜세요. 몇 번 안에 DelayOS가 켜집니다.
  그래도 Windows만 켜지면 켤 때 부팅 메뉴 키(F8/F11/F12 등)로 "DelayOS"를 고르세요.
- 기록: `/var/log/delayos-winsetup.log`, EFI 파티션의 `EFI/DelayOS/winsetup/`(`winsetup.log`, `winpe.log`, `finish.log`, `done.json`),
  Windows 쪽 `C:\ProgramData\DelayOS\winsetup\*.log`.

## 구성 요소

| 경로 | 역할 |
|---|---|
| `/usr/local/bin/delay-winsetup` | 전체 로직(Python 표준 라이브러리). `probe`, `parts`, `stage`, `finalize`, `retry`, `remove`, `status`, `sb-setup`, `--dry-run` |
| `/etc/calamares/branding/delayos/wingames.qml`, `modules/wingames.conf` | 설치 프로그램 페이지 (`notesqml@wingames`) |
| `/usr/lib/calamares/modules/delayos_winparts`, `delayos_winsetup` | 설치 단계(파티션 직후 / 부트로더 직후) |
| `/usr/share/delayos/winsetup/` | Windows 쪽 파일: `install.cmd.in`(Windows PE), `unattend.xml.in`, `specialize.cmd`, `finish.ps1`, `cleanup.ps1`(게이밍 정리), `cleanup-undo.cmd`, `winpeshl.ini` 등 |
| `/etc/systemd/system/delay-winsetup-finalize.service` | 부팅 시: 설치 중이면 Windows로 넘겨주기, 끝났으면 마무리, 아니면 실패 처리 |
| `/usr/lib/udev/rules.d/61-delayos-winsetup.rules` | Windows 파티션을 파일 탐색기에서 숨김(`UDISKS_IGNORE`) |
| `/etc/delayos/winsetup.conf` | 상태(`STATE=pending|done|failed|removed`)와 파티션 GUID |
| `packages/delayos-sb-general`, `tools/make-delayos-general-key.sh` | Secure Boot용 일반 키와 서명된 GRUB/커널 (빌드 쪽) |

파티션 속성 참고: Windows 파티션에 GPT "숨김/드라이브 문자 없음" 속성(비트 62, 63)은 **설정하지 않습니다.** 이 속성은 Windows 자신이
해석하며, 부팅 볼륨에 걸면 Windows가 자기 C: 드라이브를 마운트하지 못합니다. DelayOS에서 숨기는 일은 udev 규칙과
os-prober 끄기(`GRUB_DISABLE_OS_PROBER=true`)로 합니다.
