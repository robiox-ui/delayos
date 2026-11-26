# 벤치마크: Windows와 DelayOS를 같은 PC에서 공정하게 비교하기

목표는 "같은 PC, 같은 게임, 같은 장면, 같은 설정"에서 두 OS의 프레임 시간을 기록하고, **같은 계산식**으로 평균 FPS / 1% low / 0.1% low를 구하는 것입니다. DelayOS에는 이를 위한 `delay-bench`가 들어 있습니다. Windows에서 기록한 CSV(PresentMon, CapFrameX)도 `delay-bench`로 계산하므로 도구마다 식이 달라서 생기는 차이가 없습니다.

## 1. 측정 전에 맞출 것

| 항목 | 맞추는 방법 |
|---|---|
| 게임 버전 | 양쪽 모두 최신 패치. Steam 게임은 같은 빌드인지 확인합니다. |
| 그래픽 설정 | 해상도, 프리셋, 업스케일러(DLSS/FSR)와 그 품질, 레이 트레이싱, 프레임 생성까지 모두 같게. 설정 화면을 캡처해 두세요. |
| 그래픽 API | Windows에서 DX12면 DelayOS(Proton)에서도 DX12로 실행합니다. Vulkan 네이티브 옵션이 있는 게임은 따로 한 번 더 잽니다. |
| 화면 | 같은 모니터, 같은 해상도와 주사율. **V-Sync 끔, 프레임 제한 끔.** VRR은 양쪽 모두 켜거나 모두 끕니다. 전체 화면(또는 테두리 없는 전체 화면)으로 통일합니다. |
| 드라이버 | 양쪽 모두 최신 GPU 드라이버. 버전을 기록합니다. |
| 백그라운드 | 브라우저, 런처, 녹화 프로그램, 오버레이(Discord, GeForce Experience 등)를 끕니다. Windows는 게임 모드 켬, 전원 관리 옵션 "고성능" 또는 "균형"(어느 쪽인지 기록). DelayOS는 게이밍 모드(Meta+G) 켬. |
| 온도 | 양쪽 모두 PC를 10분 이상 켜 둔 상태에서, 같은 실내 온도로. 노트북은 전원 연결. |
| 셰이더 | **첫 실행은 버립니다.** DelayOS는 처음 실행할 때 셰이더를 컴파일하므로, 같은 장면을 한 번 끝까지 돌린 뒤 두 번째부터 기록합니다. Windows도 똑같이 한 번 돌리고 시작합니다. |
| BIOS | 같은 설정(PBO, XMP/EXPO, CPPC). 두 OS 사이에 바꾸지 않습니다. |

같은 장면을 재현하기 쉬운 순서: ① 게임에 들어 있는 벤치마크 → ② 리플레이/데모 재생 → ③ 정해진 길을 60초 동안 걷기. ③은 사람 손이 들어가므로 5번 이상 반복해야 합니다.

**3회 이상 측정해서 가운데 값(중앙값)을 씁니다.** 회차 사이 차이가 3%를 넘으면 그 조건은 다시 잽니다.

## 2. DelayOS에서 기록하기

기록은 MangoHud가 합니다(프레임마다 한 줄, CSV).

**Steam 게임:** 터미널에서

```bash
delay-bench steam -t 60 -w 30
```

을 실행하면 Steam 시작 옵션에 넣을 한 줄이 나옵니다. 게임 속성 > 일반 > 시작 옵션에 붙여 넣으면, 게임을 시작하고 30초 뒤부터 60초 동안 자동으로 기록합니다. 직접 시작하고 멈추려면 왼쪽 Shift+F2를 누릅니다. 기록은 `~/delay-bench/`에 `<게임>_<날짜>.csv`로 저장됩니다.

**Steam 밖의 게임이나 프로그램:**

```bash
delay-bench run -t 60 -w 10 -n 게임이름 -- ./game
```

**결과 계산:**

```bash
delay-bench parse ~/delay-bench/game_2026-11-26_21-03-10.csv
delay-bench sysinfo        # 보고서에 붙일 시스템 정보(커널, 드라이버, 스케줄러, 전원 모드)
```

측정할 때 MangoHud 화면 표시가 켜져 있어도 됩니다(영향은 보통 1% 미만). 다만 Windows 쪽에서 오버레이를 껐다면 DelayOS도 `no_display`로 맞추는 편이 공정합니다.

## 3. Windows에서 기록하기

둘 중 하나를 씁니다. 두 도구 모두 프레임 시간을 CSV로 저장합니다.

**CapFrameX** (권장, GUI)
1. CapFrameX를 실행하고 Capture 탭에서 게임 프로세스를 선택합니다.
2. Capture time을 60초로, 단축키(기본 F11)를 확인합니다.
3. 게임에서 정한 장면이 시작될 때 단축키를 누릅니다.
4. 기록은 `문서\CapFrameX\Captures\`에 JSON으로 저장됩니다. Analysis 탭에서 기록을 고르고 **Export > CSV(frametimes)** 로 내보냅니다. `MsBetweenPresents` 열이 들어 있으면 됩니다.

**PresentMon** (명령줄, 관리자 권한 PowerShell)

```powershell
PresentMon-x64.exe --process_name game.exe --output_file C:\bench\game_win.csv --timed 60 --terminate_after_timed
```

PresentMon 1.x의 `MsBetweenPresents`, 2.x의 `FrameTime` 열을 모두 읽습니다.

CSV를 USB나 공유 폴더로 DelayOS에 가져옵니다. 듀얼 부팅이면 DelayOS에서 Windows 파티션을 열어 바로 읽어도 됩니다.

## 4. 비교하기

```bash
# 한 번에 비교 (앞이 기준)
delay-bench compare --process game.exe game_win.csv ~/delay-bench/game_2026-11-26_21-03-10.csv

# 여러 기록을 표로
delay-bench table game_win_1.csv game_win_2.csv game_win_3.csv
delay-bench table ~/delay-bench/game_*.csv
```

기록 길이가 다르면 `--skip`과 `--duration`으로 같은 구간만 잘라 씁니다(예: `--skip 5 --duration 55`).

### 계산식

| 값 | 식 |
|---|---|
| 평균 FPS | 프레임 수 ÷ 전체 시간(초). 순간 FPS의 평균이 아닙니다. |
| 1% low | 프레임 시간을 정렬했을 때 99번째 백분위수 프레임의 FPS. CapFrameX의 P1, MangoHud 요약의 "1% Min FPS"와 같은 정의입니다. |
| 0.1% low | 99.9번째 백분위수 프레임의 FPS (P0.1). 60초 기록이면 프레임 몇 개로 정해지므로 회차마다 흔들립니다. 3회 이상의 중앙값을 쓰세요. |
| 1% low 평균 | 가장 느린 1% 프레임의 평균 FPS. `parse`가 괄호 안에 함께 보여 줍니다. 다른 자료와 비교할 때는 어느 정의인지 확인하세요. |

## 5. 결과 표 양식

시스템 정보는 `delay-bench sysinfo`의 출력으로 채웁니다.

```markdown
## 시스템
| 항목 | 값 |
|---|---|
| CPU / 메인보드 / BIOS | |
| GPU | |
| 메모리 | |
| 저장 장치 | |
| 모니터 | 2560x1440 @ 165 Hz, VRR 끔 |
| Windows | 11 24H2 (빌드 ), GPU 드라이버 , 전원: 균형 |
| DelayOS | 2026.11.26, 커널 , Mesa/NVIDIA , 패키지 빌드: x86-64-v3, 게이밍 모드 켬 |

## 게임 A (DX12, 1440p 높음, 업스케일 끔, 내장 벤치마크)
| OS | 회차 | 평균 FPS | 1% low | 0.1% low |
|---|---:|---:|---:|---:|
| Windows 11 | 1 | | | |
| Windows 11 | 2 | | | |
| Windows 11 | 3 | | | |
| **Windows 11 중앙값** | | | | |
| DelayOS | 1 | | | |
| DelayOS | 2 | | | |
| DelayOS | 3 | | | |
| **DelayOS 중앙값** | | | | |
| **차이 (DelayOS ÷ Windows − 1)** | | % | % | % |

비고: (Proton 버전, 셰이더 예열 여부, 특이 사항)
```

## 6. 결과를 읽을 때

- 3% 이내 차이는 측정 오차로 봅니다.
- 평균은 비슷한데 1% low만 낮다면 셰이더 컴파일이 덜 끝났을 수 있습니다. 같은 장면을 한 번 더 돌리고 다시 잽니다.
- 결과는 게임과 GPU에 따라 갈립니다. DX12 게임은 NVIDIA에서 Windows보다 낮게 나오는 일이 알려져 있으니(vkd3d-proton과 NVIDIA 드라이버 조합), API별로 나눠 적으세요.
- 커널 안티치트를 쓰는 게임은 DelayOS에서 실행되지 않으므로 비교 대상에서 뺍니다.
- DelayOS 쪽 조건을 바꿔 가며 볼 것: 게이밍 모드 켬/끔, CPU 맞춤 패키지 켬/끔(드라이버 앱), Proton-CachyOS와 Valve Proton, `delay-game %command%` 사용 여부, X3D CPU라면 `delay-bench sysinfo`의 X3D 모드. 한 번에 한 가지만 바꿉니다.
