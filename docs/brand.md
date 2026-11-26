# DelayOS 브랜드 가이드

DelayOS 로고를 쓰는 규칙입니다. 그림으로 한눈에 보려면 [reports/brand-preview.html](reports/brand-preview.html)을 여세요.

모든 파일은 `assets-src/gen_brand.py`가 만듭니다. 심벌 모양은 `assets-src/brand_mark.py` 한 곳에만 정의되어 있고, 아이콘 테마(`gen_icons.py`)도 그 정의를 씁니다. SVG를 손으로 고치지 말고 생성기를 고친 뒤 다시 실행하세요(맨 아래 "다시 만들기").

## 1. 구성 요소

| 요소 | 설명 |
|---|---|
| 심벌 | "물결 구". 원을 물결 모양 틈 두 개로 세 띠로 나눈 모양입니다. 위에서 아래로 갈수록 짙어집니다. |
| 워드마크 | `DelayOS`. 원과 곧은 줄기만으로 직접 그린 글자입니다(글꼴 파일 없음). `Delay`는 무채색, `OS`는 강조색입니다. |
| 한글 워드마크 | `딜레이OS`. 같은 굵기의 곧은 획과 원으로 그렸습니다. 한국어 문서나 한국어 화면에서 씁니다. |
| 조합 | 심벌 + 워드마크. 가로형(기본)과 세로형이 있습니다. |

글로 쓸 때는 항상 `DelayOS`입니다(띄어쓰기 없음, D·O·S는 대문자). 한글로는 `딜레이OS`.

## 2. 심벌 규격

- 격자 64×64, 원의 반지름 28(지름 56), 바깥 여백 4. 아이콘 세트의 타일 격자(`docs/icon-style.md`)와 같은 크기입니다.
- 물결 틈의 두께는 3.4, 물결의 높이는 ±3.2입니다. 16~24px로 쓸 때는 틈을 5.0으로 넓힌 `delayos-small.svg`를 씁니다(틈이 1px 아래로 내려가 뭉개지지 않게). PNG 16/22/24와 `.ico`의 16~24px은 이미 그렇게 만들어져 있습니다.
- 로고는 아이콘 타일 위에 올리지 않습니다. 항상 원 그대로 씁니다.

### 변형

| 파일 (`/usr/share/delayos/logo/`) | 용도 |
|---|---|
| `delayos.svg` | 기본 색 로고. 어두운 배경과 밝은 배경 모두에 쓸 수 있습니다. 잘 모르겠으면 이것을 쓰세요. |
| `delayos-on-dark.svg` | 아주 어두운 배경(부팅 화면, 설치 프로그램, 배너)용. 한 단계 밝습니다. |
| `delayos-on-light.svg` | 흰 배경(문서, 인쇄)용. 한 단계 짙습니다. |
| `delayos-white.svg` | 흰색 단색. 사진, 강조색 배경, 대비가 낮은 배경 위. |
| `delayos-black.svg` | 검은색 단색. 흑백 인쇄, 각인. |
| `delayos-symbolic.svg` | 패널·트레이용. 글자색(`currentColor`)을 따라가고 띠마다 불투명도(55 %, 80 %, 100 %)가 다릅니다. |
| `delayos-small.svg` | 16~24px용(틈이 넓음). |

## 3. 조합 규격

단위는 심벌 격자(64)입니다.

| | 가로형 | 세로형 |
|---|---|---|
| 워드마크 대문자 높이 | 25 (원 지름의 0.45배) | 21 |
| 심벌과 글자 사이 | 12 (원 가장자리부터) | 10 (원 아래부터 글자 윗선까지) |
| 정렬 | 대문자 높이의 가운데 = 원의 가운데 | 가운데 정렬 |

파일 이름은 `delayos[-ko]-{wordmark,lockup-h,lockup-v}-{on-dark,on-light,white,black}.svg`입니다. `on-dark`는 어두운 배경 위에 올리는 것(흰 글자), `on-light`는 밝은 배경 위에 올리는 것(짙은 글자)입니다.

비율과 간격은 바꾸지 않습니다. 필요한 조합이 없으면 생성기에 추가하세요.

## 4. 여백

**X = 원 지름의 1/4** (64 격자에서 14).

로고(심벌만 쓸 때도, 조합일 때도) 둘레로 X만큼은 비워 둡니다. 그 안에 다른 글자, 그림, 화면이나 종이의 가장자리가 들어오면 안 됩니다. 아이콘처럼 정해진 칸에 넣을 때(파비콘, 앱 아이콘, 패널)는 SVG에 들어 있는 바깥 여백 4로 충분합니다.

## 5. 최소 크기

| | 화면 | 인쇄 |
|---|---|---|
| 심벌 | 16px (24px 이하는 `delayos-small.svg` 또는 준비된 PNG) | 5mm |
| 가로형 조합 | 높이 20px (너비 약 70px) | 높이 7mm |
| 세로형 조합 | 높이 56px | 높이 15mm |
| 워드마크만 | 높이 14px | 높이 4mm |

이보다 작으면 심벌만 씁니다.

## 6. 색

`Theme.accent`(#4D6BFE)를 중심으로 한 파란 계열입니다. 아이콘 세트와 같은 표입니다.

| 이름 | HEX | RGB | 쓰임 |
|---|---|---|---|
| B100 | `#E4E9FF` | 228, 233, 255 | 밝은 배경 |
| B200 | `#C5CEFF` | 197, 206, 255 | 어두운 배경용 심벌의 윗띠 |
| B300 | `#A9B8FF` | 169, 184, 255 | 윗띠 시작, 어두운 배경의 보조 글자 |
| B400 | `#7C93FF` | 124, 147, 255 | 윗띠 끝, 어두운 배경의 `OS` |
| B500 | `#6480FF` | 100, 128, 255 | 가운데 띠 시작 |
| **B600** | `#4D6BFE` | 77, 107, 254 | **강조색**, 가운데 띠 끝, 밝은 배경의 `OS` |
| B700 | `#3350D8` | 51, 80, 216 | 아랫띠 시작 |
| B800 | `#2640B4` | 38, 64, 180 | |
| B900 | `#1F2F94` | 31, 47, 148 | 아랫띠 끝 |
| Ink | `#141A2E` | 20, 26, 46 | 밝은 배경의 `Delay` 글자 |
| Night | `#0E1224` | 14, 18, 36 | 배너·아바타 배경 |
| White | `#FFFFFF` | 255, 255, 255 | 어두운 배경의 `Delay` 글자 |

심벌의 띠는 모두 왼쪽 위에서 오른쪽 아래로 가는 선형 그러데이션입니다.

| 변형 | 윗띠 | 가운데 띠 | 아랫띠 |
|---|---|---|---|
| 기본 | `#A9B8FF` → `#7C93FF` | `#6480FF` → `#4D6BFE` | `#3350D8` → `#1F2F94` |
| 어두운 배경용 | `#C5CEFF` → `#A9B8FF` | `#7C93FF` → `#5B77FF` | `#4D6BFE` → `#3350D8` |
| 밝은 배경용 | `#8FA3FF` → `#6480FF` | `#4D6BFE` → `#3F58E8` | `#2640B4` → `#182675` |

### 배경 고르기

- 어두운 배경(대략 `#2A2F45`보다 어두움): `on-dark` 조합, 심벌은 `delayos.svg` 또는 `delayos-on-dark.svg`.
- 밝은 배경(대략 `#C5CEFF`보다 밝음): `on-light` 조합, 심벌은 `delayos.svg` 또는 `delayos-on-light.svg`.
- 파란 배경, 중간 밝기 배경, 사진 위: 색 로고를 쓰지 말고 `white`(또는 `black`) 단색을 씁니다.

## 7. 하지 말 것

- 늘이거나 찌그러뜨리지 않습니다. 가로세로 비율을 지킵니다.
- 돌리거나 기울이거나 뒤집지 않습니다.
- 정해진 색 말고 다른 색을 입히지 않습니다. 띠의 순서(위가 밝고 아래가 짙음)를 바꾸지 않습니다.
- 그림자, 외곽선, 빛 번짐, 입체 효과를 넣지 않습니다.
- 흐리게 하거나 반투명하게 쓰지 않습니다(패널용 `symbolic`은 예외).
- 대비가 낮은 배경이나 복잡한 사진 위에 색 로고를 올리지 않습니다.
- 워드마크를 다른 글꼴로 다시 쓰지 않습니다. 본문에서 이름을 쓸 때는 그냥 글자로 `DelayOS`라고 씁니다.
- 심벌과 글자의 크기 비율, 간격, 위치를 바꾸지 않습니다.
- 심벌을 아이콘 타일(둥근 사각형) 위에 올리거나 다른 도형 안에 가두지 않습니다.
- 다른 제품의 로고와 섞어 새 로고처럼 만들지 않습니다. FlowOS/Velotic의 이름, 로고, 그림은 어디에도 쓰지 않습니다.

## 8. 파일

### 이미지에 들어가는 것 (`delayos-branding` 패키지, `/usr/share/delayos/logo/`)

- 심벌 SVG 7개, 워드마크·조합 SVG 24개(영문/한글 × 3종 × 4색).
- 심벌 PNG: 16, 22, 24, 32, 48, 64, 96, 128, 256, 512.
- `delayos.ico`: 16, 20, 24, 32, 40, 48, 64, 256.

### 저장소에만 있는 것 (`docs/assets/`)

| 파일 | 크기 | 용도 |
|---|---|---|
| `banner-dark.png`, `banner-light.png` (+ `.svg`) | 1600×400 | README 맨 위 배너. GitHub 테마에 맞춰 바뀝니다. |
| `social-preview.png` | 1280×640 | GitHub 저장소 Settings › Social preview |
| `github-avatar.png` | 500×500 | GitHub 조직/계정 아바타. 원으로 잘려도 심벌이 온전히 보입니다. |
| `logo/delayos-{16…1024}.png` | | 심벌 PNG 전체(1024 포함) |
| `logo/delayos[-ko]-lockup-*.png` | 너비 1024 / 512 | 문서에 바로 넣을 조합 PNG |
| `favicon/` | | `favicon.ico`(16/32/48), `favicon.svg`, `favicon-16/32/48.png`, `apple-touch-icon.png`(180), `icon-192.png`, `icon-512.png`, `site.webmanifest` |
| `windows/delayos.ico`, `windows/autorun.inf` | | USB/ISO 맨 위에 두면 Windows 탐색기에서 드라이브 아이콘과 이름이 DelayOS로 보입니다. |
| `boot/syslinux-splash.png` | 640×480 | ISO를 BIOS로 부팅할 때의 부팅 메뉴 배경(`syslinux/splash.png` 자리). |

웹 페이지 `<head>`에는 이렇게 넣습니다.

```html
<link rel="icon" href="/favicon.ico" sizes="48x48">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="manifest" href="/site.webmanifest">
```

## 9. OS 안에서 쓰이는 곳

| 위치 | 쓰는 파일 |
|---|---|
| 부팅 화면(Plymouth), 로그인 스플래시(ksplash), Windows 전환 화면 | `/usr/share/plymouth/themes/delayos/logo.png` (264px = 132px의 2배, 어두운 배경용 심벌). 아래 점 3개(`dot.png`)는 그대로입니다. |
| 상단바 로고, 독의 시작 버튼 | `logo/delayos.svg` (`org.delayos.shell` `Logo.qml`) |
| 아이콘 테마 `delayos-logo`, `delayos`, `distributor-logo`, `start-here`, `start-here-kde`, `start-here-kde-plasma` | `logo/delayos.svg`의 사본 |
| 아이콘 테마 `delayos-logo-symbolic`, `start-here-symbolic` | `logo/delayos-symbolic.svg`의 사본 |
| `os-release`의 `LOGO=delayos-logo` | hicolor의 `delayos-logo.svg` |
| 설치 프로그램(Calamares) | 환영 화면과 설치 중 화면: `delayos-on-dark.svg`. `branding.desc`: `productLogo` = `delayos-on-dark.svg`, `productIcon` = `delayos.svg`, `productWelcome` = `delayos-lockup-h-on-dark.svg` |
| 시작하기 앱 첫 화면, 설정 › 정보 | `logo/delayos.svg` |
| `delayfetch` / fastfetch | `/usr/share/delayos/fastfetch/logo.txt` (심벌을 반 칸 블록 문자로 옮긴 것, 34×17칸, 띠마다 색 `$1`~`$3`) |
| Windows 연동 도우미의 트레이 아이콘 | `agent.ps1` 안의 `$DelayIconB64` (16/20/24/32px `.ico`) |

로그인 화면(SDDM), 잠금 화면, 복구 환경, GRUB 메뉴에는 로고가 없습니다. 로그인·잠금 화면은 화면 설계(`docs/ui-spec.md`)에 로고가 없고, 복구 환경은 글자 화면이며, GRUB은 테마 없이 글자 메뉴를 씁니다.

## 10. 다시 만들기

PySide6, Pillow, Noto Sans CJK KR 글꼴이 있는 곳(DelayOS 라이브 세션이면 됩니다)에서 실행합니다.

```bash
QT_QPA_PLATFORM=offscreen python3 assets-src/gen_brand.py .          # 브랜드 파일 전부 + 미리 보기 페이지
python3 assets-src/gen_icons.py profile/airootfs --keep              # 아이콘 테마 (로고 사본 포함)
```

`gen_brand.py`는 쓴 파일의 목록과 크기를 출력합니다. 심벌 모양을 바꾸면 Plymouth `logo.png`, 터미널 로고, 트레이 아이콘, 모든 PNG/ICO가 함께 바뀝니다. 배너의 문구(`TAGLINE`)는 글꼴 윤곽선으로 바꿔 넣으므로 SVG에 글꼴이 남지 않습니다.
