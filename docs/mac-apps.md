# Mac 앱

DelayOS에서 Mac 앱 파일(`.dmg`, `.pkg`, `.app`)을 열면 어떤 일이 일어나는지, 무엇이 되고 무엇이 안 되는지 정리한 문서입니다.

## 먼저 알아 둘 것

**Mac 앱은 DelayOS에서 그대로 실행되지 않습니다.** 과장 없이 적으면 이렇습니다.

- 화면이 있는 macOS 앱(Cocoa, SwiftUI, Metal을 쓰는 앱)을 Linux에서 실행하는 방법은 없습니다. Windows 프로그램에는 Wine/Proton이 있지만, Mac 앱에는 그만한 호환 계층이 없습니다.
- [Darling](https://www.darlinghq.org/)은 macOS용 **명령줄 프로그램 일부**만 실행합니다. 화면이 있는 앱은 거의 동작하지 않고, 프로젝트 스스로도 실험 단계라고 밝힙니다.
- macOS 자체를 가상 머신으로 실행하는 것은 Apple 소프트웨어 사용권 계약상 **Apple 하드웨어에서만** 허용됩니다. 그래서 DelayOS는 macOS 가상 머신을 넣지도, 자동으로 설치해 주지도 않습니다.

그래서 DelayOS의 "Mac 앱" 기능은 Mac 앱을 실행하는 척하지 않습니다. 파일이 어떤 앱인지 알아내고, **지금 이 PC에서 그 앱을 쓸 수 있는 가장 좋은 방법**을 안내합니다.

## 쓰는 방법

1. **파일을 두 번 클릭합니다.** `.dmg`, `.pkg` 파일을 열면 "Mac 앱" 창이 뜹니다. 압축을 푼 `.app` 폴더나 `.zip`은 터미널에서 `delay-macapps 경로`로 열 수 있습니다.
2. 창에 앱 이름, 버전, 아이콘이 나오고 아래 순서로 방법을 알려 줍니다.

| 순서 | 상황 | 창에 나오는 것 |
|---|---|---|
| 1 | 같은 앱의 Linux 버전이 있음 | "Linux용 ○○ 설치" 버튼. DelayOS Store와 같은 방식으로 설치됩니다(Flathub 또는 DelayOS 저장소, 한국어 포함). 이미 설치되어 있으면 "열기" |
| 2 | DelayOS에 같은 기능이 들어 있음 | 터미널, 창 맞춤, 명령 바, 압축 풀기 등. 따로 설치할 것이 없습니다 |
| 3 | 제작사가 Linux용을 직접 배포함 | 공식 다운로드 페이지 열기 |
| 4 | Linux 버전은 없지만 대신 쓸 앱이 있음 | 대체 앱 목록과 설치 버튼 (예: Photoshop → GIMP, Krita) |
| 5 | Windows 버전이 있음 | 제작사 공식 페이지 열기. 내려받은 `.exe`를 두 번 클릭하면 Windows 앱 엔진(Wine/Proton)에서 실행됩니다 (예: 카카오톡) |
| 6 | 웹 버전이 있음 | "웹 버전 열기" (예: Figma, Notion) |
| 7 | 명령줄 Mac 프로그램 | Darling 설치/실행 버튼 (실험적, 아래 참고) |
| 8 | 어느 것도 없음 | macOS 전용이라 실행할 수 없다는 안내와 Store 검색 버튼 |

3. 목록에 없는 앱은 Store(Flathub와 저장소)에서 **같은 이름**의 앱을 찾아봅니다. 이름이 정확히 같을 때만 "Linux 버전"으로 보여 주고, 다른 앱일 수 있다는 안내를 함께 띄웁니다. 비슷한 이름만 있으면 "이름이 비슷한 앱"으로 따로 보여 줍니다.

## Mac에서 쓰던 앱 찾기

**DelayOS Store › Mac 앱**(또는 설정 › 앱 지원 › Mac 앱 › "Mac에서 쓰던 앱 찾기", 명령 `delay-store --mac`)에 자주 쓰는 Mac 앱 116개의 대응표가 있습니다. 이름으로 찾고 한 번 눌러 설치할 수 있습니다. 분류는 브라우저, 메신저 및 회의, 개발, 음악 및 동영상, 사진 및 디자인, 문서 및 생산성, 보안 및 파일, 원격 및 가상화, 시스템 도구, 게임입니다.

몇 가지 예:

| Mac 앱 | DelayOS에서 |
|---|---|
| Chrome, Firefox, VS Code, Discord, Slack, Zoom, Spotify, Telegram, Obsidian, 1Password, Bitwarden, Postman, Unity Hub, Blender, OBS, VLC, Steam | 같은 앱의 Linux 버전 설치 |
| iTerm2 / 터미널 | DelayOS 터미널 |
| Rectangle / Magnet | 기본 창 맞춤 (가장자리로 끌기, Meta+방향키) |
| Alfred / Raycast | 명령 바 (Meta+Space) |
| Docker Desktop | Docker 엔진 (Linux에서는 가상 머신 없이 실행) |
| Photoshop / Illustrator / Lightroom | GIMP·Krita / Inkscape / darktable (Adobe 앱은 Windows 앱 엔진에서도 동작하지 않습니다) |
| Final Cut Pro / Logic Pro | Kdenlive·DaVinci Resolve / Ardour·REAPER |
| Word / Excel / PowerPoint, Pages / Numbers / Keynote | 웹용 Office·iCloud 또는 LibreOffice·ONLYOFFICE |
| Figma, Notion, ChatGPT, Claude | 웹 버전 |
| 카카오톡, LINE, Battle.net | Windows 버전을 Windows 앱 엔진으로 실행 |
| Xcode | 대체할 수 없음 (iOS/macOS 빌드는 Mac 필요) |
| League of Legends, VALORANT | DelayOS에서 불가 (커널 안티치트). 이 PC에 Windows가 있으면 Store › Windows 게임 |

## Darling (명령줄 프로그램, 실험적)

- 기본으로 설치되어 있지 않습니다. 창에서 "Darling 설치 (실험적)"을 누르면 터미널이 열리고 AUR의 `darling-bin`을 설치합니다(`yay -S darling-bin`). 내려받는 양이 크고, DelayOS가 검증하거나 관리하는 꾸러미가 아닙니다.
- 설치되어 있으면 "Darling으로 실행"이 터미널에서 `darling shell …`로 파일을 넘깁니다. Darling 안에서 Linux 파일은 `/Volumes/SystemRoot/…` 아래에 보입니다.
- 화면이 있는 앱은 Darling으로도 실행되지 않습니다. 이 버튼은 명령줄 도구로 보이는 파일(Mach-O 실행 파일, 앱이 들어 있지 않은 `.dmg`/`.pkg`)에만 나옵니다.

## 파일을 읽는 방법 (안전)

- 전부 **읽기 전용**이고 관리자 권한이 필요 없습니다. 디스크 이미지를 마운트하지 않고, 안에 든 Mac 프로그램을 실행하지 않습니다.
- `.dmg`: `7z`(7zip 꾸러미)로 이미지 안의 HFS+/APFS 볼륨 목록을 읽고, 첫 번째 `.app`의 `Contents/Info.plist`와 아이콘(`.icns`)만 꺼냅니다.
- `.pkg`: xar 보관 파일이므로 `bsdtar`(libarchive)로 `Distribution`/`PackageInfo`만 읽습니다.
- `.app` 폴더와 `.zip`: `Info.plist`를 바로 읽습니다.
- 아이콘은 `.icns` 안의 PNG 조각을 꺼내 `~/.cache/delayos/macapps/`에 둡니다. 예전 방식(RLE) 아이콘만 있는 앱은 일반 아이콘으로 표시합니다.
- 암호화된 이미지처럼 안을 읽지 못한 경우에는 파일 이름으로만 판단하고, 그 사실을 창에 표시합니다.

## 한계

- Mac 앱을 실행하는 기능이 아닙니다. Mac 전용 앱(Xcode, Final Cut Pro, Logic Pro, Sketch 등)은 대체 앱을 쓰는 것 외에 방법이 없습니다.
- 앱 안의 자료(프로젝트 파일, 설정)는 옮겨 주지 않습니다. 계정으로 동기화되는 앱은 Linux 버전에 로그인하면 됩니다.
- Windows 버전 안내는 "Windows 앱 엔진에서 실행될 수 있다"는 뜻이지 보장이 아닙니다. 커널 안티치트 게임과 Adobe 앱은 동작하지 않습니다.
- 대응표는 사람이 관리하는 목록입니다(`/usr/share/delayos/apps/macapps/macapps.json`). 목록에 없는 앱은 이름 검색에 의존하므로 못 찾거나, 드물게 이름만 같은 다른 앱을 보여 줄 수 있습니다.
- AUR에서 설치하는 항목(JetBrains Toolbox, Cursor, Darling)은 터미널에서 `yay`로 설치하며 Store의 한 번 클릭 설치가 아닙니다.
- spec §10.4의 "Mac 앱 창(신호등 버튼이 있는 프레임)"은 만들지 않았습니다. 실행할 수 있는 Mac 앱이 없기 때문입니다.

## 개발자용

| 항목 | 위치 |
|---|---|
| 실행 파일 | `/usr/bin/delay-macapps FILE` (`--json FILE`은 분석 결과만 출력) |
| 코드 | `/usr/share/delayos/apps/macapps/` (`macback.py`, `macapps.json`, `qml/main.qml`) |
| Store 페이지 | `/usr/share/delayos/apps/store/qml/MacPage.qml` (`delay-store --mac`) |
| 데스크톱 파일 | `/usr/share/applications/org.delayos.MacApps.desktop` (NoDisplay, MIME 처리기) |
| MIME | `application/x-apple-diskimage`, `application/vnd.apple.installer+xml`(`*.pkg`, `/usr/share/mime/packages/delayos-macapps.xml`), `application/x-xar`, `application/x-mach-binary` |
| 아이콘 | `delayos-macapps` (Apple 로고를 쓰지 않습니다) |

대응표 항목 형식:

```json
{ "name": "Adobe Photoshop", "cat": "사진 및 디자인",
  "ids": ["com.adobe.Photoshop"],            // CFBundleIdentifier, 끝의 * 는 접두사 일치
  "names": ["photoshop"],                    // 파일 이름으로 맞출 때 쓰는 다른 이름
  "linux": [{ "source": "flathub|repo|aur", "pkg": "…" }],   // 같은 앱의 Linux 버전
  "builtin": { "label": "버튼 글자", "argv": ["…"] },          // DelayOS 기본 기능
  "link": "제작사의 Linux 다운로드 페이지",
  "alt": [{ "source": "flathub", "pkg": "org.gimp.GIMP", "name": "GIMP" }],
  "win": "제작사의 Windows 다운로드 페이지", "web": "웹 버전 주소",
  "note": "창에 보여 줄 설명" }
```

Flathub ID와 꾸러미 이름은 실제로 있는 것만 넣습니다(추가할 때 `https://flathub.org/api/v2/appstream/<id>`와 저장소 검색으로 확인).
