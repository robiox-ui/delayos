# 게임 성능: CPU 맞춤 패키지, Proton, X3D, GPU 드라이버, 게이밍 모드

같은 PC에서 Windows와 같거나 더 높은 프레임을 내기 위한 구성입니다. 측정 방법은 [benchmark.md](benchmark.md)에 있습니다.

| 기능 | 파일 | 언제 동작하나 |
|---|---|---|
| CPU 맞춤 패키지와 커널 | `/usr/local/bin/delay-cpu-opt`, `delay-cpu-opt.service` | 설치할 때(네트워크가 있으면), 없으면 첫 부팅 때, 그리고 드라이버 앱 |
| Proton 기본 도구 | `/usr/bin/delay-steam-compat`, `/etc/xdg/autostart/org.delayos.SteamCompat.desktop` | 로그인할 때마다(이미 정해져 있으면 아무것도 하지 않음) |
| Ryzen X3D | `/usr/lib/udev/rules.d/62-delay-x3d.rules`, `delay-gamemode-root` | 부팅할 때, 게이밍 모드 |
| GPU 드라이버 | `/usr/local/bin/delay-gpu-setup`, 드라이버 앱 | 설치할 때, CPU 맞춤 패키지를 켠 뒤, 드라이버 앱 |
| 게이밍 모드 | `/usr/local/bin/delay-gamemode`, `delay-gamemode-root`, `/usr/bin/delay-game` | 상단바 게이밍 버튼(Meta+G), GameMode 훅 |
| 벤치마크 | `/usr/bin/delay-bench` | 직접 실행 |

## 1. CPU 맞춤 패키지 (`delay-cpu-opt`)

**소스는 두 가지입니다.** 기본은 DelayOS 자체 저장소이고, CachyOS 저장소는 `--source cachyos`로 고르는 선택 사항입니다.

| | `--source delayos` (기본) | `--source cachyos` |
|---|---|---|
| 저장소 | `[delayos-v3]` / `[delayos-v4]` / `[delayos-znver4]` | `[cachyos-v3]` 등 CachyOS 저장소 |
| 범위 | 선별한 핵심 패키지(Mesa, Qt, KWin, PipeWire, FFmpeg, zstd, Python 등)와 `linux-delayos-<수준>` | Arch 패키지 대부분 |
| 내려받는 양 | 수백 MB | 약 2GB |
| 서명 | DelayOS 저장소 키(`delayos-keyring`) | CachyOS 키 |
| Proton | `proton-delayos`(저장소에 있을 때) | `proton-cachyos-slr` |
| 커널 | `linux-delayos-v3` / `-v4` / `-znver4` | `linux-cachyos` |

DelayOS 소스에서는 CPU가 지원하는 수준의 저장소가 게시되어 있는지 먼저 확인하고, 없으면 한 단계씩 내려갑니다(znver4 → v4 → v3). 게시된 수준이 하나도 없으면 아무것도 바꾸지 않습니다(종료 코드 3). 저장소를 만들고 게시하는 방법, 재빌드 목록과 업데이트 정책은 [packaging.md](packaging.md)에 있습니다. 설치 프로그램에서 CachyOS 소스를 쓰려면 `delayos.cpuopt.source=cachyos` 커널 옵션으로 부팅합니다.

아래 순서는 `--source cachyos`의 동작입니다. DelayOS 소스는 2~3단계가 없고(키와 미러 목록이 `delayos-keyring`, `delayos-mirrorlist` 패키지로 이미 설치되어 있음) 4단계의 블록이 `[delayos-<수준>]` 하나입니다.

Arch 패키지는 모든 x86-64 CPU에서 돌도록 빌드됩니다. CachyOS는 같은 패키지를 x86-64-v3(AVX2), x86-64-v4(AVX-512), Zen 4/5(znver4)용으로 다시 빌드해 저장소로 제공합니다. `delay-cpu-opt`는 CachyOS의 `cachyos-repo.sh`와 같은 순서로 이 저장소를 켭니다.

1. CPU 수준 확인: `/lib/ld-linux-x86-64.so.2 --help`가 `x86-64-v3 (supported, searched)`라고 답하는 수준만 사용합니다. AMD family 25·26이면서 v4를 지원하면 znver4입니다. v3를 지원하지 않는 CPU에서는 아무것도 바꾸지 않습니다(종료 코드 3).
2. CachyOS 서명 키(`882DCFE48E2051D48E2562ABF3B607488DB35A47`)를 `pacman-key`로 등록하고 로컬 서명합니다. 키는 이미지에 들어 있는 `/usr/share/delayos/trust/cachyos.asc`에서 읽고, 없으면 키 서버에서 받은 뒤 지문이 정확히 같은지 확인합니다.
3. `[cachyos]` 저장소에서 `cachyos-keyring`, `cachyos-mirrorlist`, `cachyos-v3-mirrorlist`, `cachyos-v4-mirrorlist`를 설치합니다.
4. `/etc/pacman.conf`의 첫 저장소 위에 블록을 넣습니다(표시 줄 사이, 원본은 `/etc/pacman.conf.delay-bak`).
   - v3: `[cachyos-v3] [cachyos-core-v3] [cachyos-extra-v3] [cachyos]`
   - v4: `[cachyos-v4] [cachyos-core-v4] [cachyos-extra-v4] [cachyos]`
   - znver4: `[cachyos-znver4] [cachyos-core-znver4] [cachyos-extra-znver4] [cachyos]`
   - `Architecture = x86_64 x86_64_v3 [x86_64_v4]`: Arch의 pacman은 `auto`를 x86_64로만 풀기 때문에 직접 적습니다. 업그레이드 뒤에는 CachyOS의 pacman이 설치되며 이 줄을 그대로 이해합니다.
   - `[multilib]`이 꺼져 있으면 켭니다.
5. `pacman -Syuw`(내려받기)와 `pacman -Su`(설치)를 나눠 실행합니다. 설치 중에는 종료·절전을 막고 SIGTERM을 무시합니다.
6. `proton-cachyos-slr`을 설치하고 `delay-gpu-setup`을 다시 실행합니다.

중간에 실패하면 `pacman.conf`를 원본으로 되돌립니다. pacman이 트랜잭션을 시작하기 전에 멈춘 경우 시스템은 그대로입니다.

**설치할 때:** `delay-postinstall`이 `delay-cpu-opt enable --install-time`을 부릅니다. 네트워크가 없거나 실패하면 `/var/lib/delay/cpu-opt/pending`만 남기고 설치는 정상으로 끝납니다. 그 뒤 네트워크가 있는 첫 부팅에서 `delay-cpu-opt.service`가 적용하고 알림을 띄웁니다. 한 번 시도해서 실패하면 다시 시도하지 않습니다(드라이버 앱에서 켤 수 있음). 설치 프로그램을 `delayos.cpuopt=off` 커널 옵션으로 부팅하면 이 단계를 건너뜁니다. `delayos.cpuopt=kernel`이면 커널까지 설치합니다.

**직접 켜고 끄기:** 드라이버 앱 > 성능 최적화 > CPU 맞춤 패키지, 또는

```bash
sudo delay-cpu-opt status
sudo delay-cpu-opt enable
sudo delay-cpu-opt disable      # 되돌리기
```

**되돌리기(`disable`)가 하는 일:**

1. `linux-cachyos`를 제거하고 GRUB 기본값을 `linux-delayos`로 돌립니다.
2. 저장소 블록을 지우고 `Architecture = auto`로 되돌린 뒤 `pacman -Sy`.
3. Arch의 pacman을 먼저 다시 설치합니다. CachyOS의 pacman은 로컬 DB에 `%INSTALLED_DB%` 항목을 남기는데, Arch의 pacman은 그런 패키지마다 경고를 내기 때문입니다.
4. CachyOS가 빌드한 패키지(아키텍처가 `x86_64_v3/v4`이거나 Packager가 CachyOS) 가운데 Arch 저장소에 있는 것을 한 번의 트랜잭션으로 Arch 빌드로 다시 설치합니다. 약 2GB를 받습니다. `pacman -Syuu`는 쓰지 않습니다. DelayOS가 직접 빌드한 패키지(`pahole` 등)까지 내려 버리기 때문입니다.
5. 키링과 미러 목록을 제거하고, 남은 `%INSTALLED_DB%` 항목을 지웁니다.

Arch에 없는 패키지(예: `proton-cachyos-slr`)는 남겨 두고 이름을 알려 줍니다. 중간에 끊겨도 `disable`을 다시 실행하면 이어서 진행합니다.

수동으로 되돌려야 할 때: `/etc/pacman.conf`에서 `# >>> DelayOS CPU-optimized repositories`와 `# <<<` 사이를 지우고 `Architecture = auto`로 바꾼 뒤 `sudo delay-cpu-opt disable`을 실행합니다.

### CPU 맞춤 커널

기본 소스(DelayOS)에서는 `delay-cpu-opt kernel install`이 켜져 있는 수준의 `linux-delayos-v3` / `-v4` / `-znver4`를 그 수준 저장소에서 설치합니다. `linux-delayos`와 같은 PKGBUILD를 수준별로 컴파일한 것이고 저장소로 업데이트됩니다([packaging.md](packaging.md)). 아래 표는 `--source cachyos`와 오프라인(ISO에 실린 `linux-delayos-v3`) 경로입니다. `linux-delayos`가 이제 `[delayos]` 저장소로 업데이트되므로, 표에 적힌 "`linux-delayos`는 설치 뒤 업데이트되지 않는다"는 이유는 `delayos-keyring` 없이 만든 ISO에만 해당합니다.

두 가지 길이 있고, 둘 다 `linux-delayos`(모든 x86-64용)와 `linux-lts`를 GRUB 고급 옵션에 남깁니다.

| | `linux-cachyos` (기본 선택) | `linux-delayos-v3` |
|---|---|---|
| 출처 | CachyOS 최적화 저장소 | `DELAYOS_KERNEL_V3=1 sudo ./build.sh`로 ISO에 넣은 패키지 |
| CPU 수준 | v3 / v4 / znver4 저장소별 빌드 | x86-64-v3 |
| 업데이트 | `pacman -Syu`로 계속 받음 | 받지 못함(ISO에 든 버전 그대로) |
| 빌드 비용 | 없음 | 커널 컴파일 한 번 더(첫 커널과 비슷한 시간) |
| 쓰는 경우 | CPU 맞춤 패키지를 켠 PC | 저장소를 쓰지 않거나 오프라인인 PC |

`linux-cachyos`를 기본으로 고른 이유: `linux-delayos`는 로컬 저장소에서 설치되어 설치 뒤에는 업데이트되지 않지만, `linux-cachyos`는 같은 소스(우리 커널의 기반)에 수준별 빌드와 보안 업데이트가 계속 나옵니다. `linux-delayos-v3`는 같은 PKGBUILD에서 `_pkgsuffix`와 `_processor_opt` 두 값만 바꿔 만듭니다.

```bash
sudo delay-cpu-opt kernel install    # 저장소가 켜져 있으면 linux-cachyos, 아니면 ISO의 linux-delayos-v3
sudo delay-cpu-opt kernel remove
```

숨겨진 Windows용 Secure Boot 구성(`/etc/delayos/winsetup.conf`의 `SB='1'`)에서는 서명되지 않은 커널을 설치하지 않습니다. 커널을 CPU 수준에 맞춰도 게임 프레임 차이는 보통 1% 안팎입니다. 사용자 공간 패키지 쪽이 효과가 큽니다.

## 2. Proton

- CPU 맞춤 패키지를 켜면 `proton-cachyos-slr`이 설치됩니다. CachyOS 위키가 권장하는 Steam Linux Runtime 빌드로, 시스템 라이브러리 업데이트의 영향을 받지 않습니다. 켜지 않은 PC는 ProtonUp-Qt(ISO에 포함)로 GE-Proton을 설치합니다.
- `delay-steam-compat`가 로그인할 때 `~/.local/share/Steam/config/config.vdf`의 `InstallConfigStore > Software > Valve > Steam > CompatToolMapping > "0"`에 `name`(도구 이름), `config ""`, `priority "75"`를 씁니다. `"0"`은 "다른 모든 타이틀"의 기본 도구입니다. 우선순위: `proton-delayos`(DelayOS 빌드, [packaging.md](packaging.md)) → `proton-cachyos-slr` → `proton-cachyos` → 가장 최신 GE-Proton. 도구 이름은 각 도구의 `compatibilitytool.vdf`에서 읽습니다.
- Steam을 망가뜨리지 않기 위한 규칙: Steam 실행 중에는 쓰지 않음, 이미 `"0"` 항목이 있으면 건드리지 않음(사용자 선택), 파일의 나머지는 그대로 두고 필요한 줄만 삽입, 원본은 `config.vdf.delay-bak`. 되돌리려면 Steam 설정 > 호환성에서 다른 도구를 고르면 됩니다.
- `steam_dev.cfg`가 없으면 `unShaderBackgroundProcessingThreads`를 코어 수의 3/4로 적어 셰이더 사전 처리를 빠르게 합니다. Steam의 셰이더 사전 캐싱 설정 자체는 바꾸지 않습니다(기본값 켬). CachyOS 위키는 Proton-CachyOS에서 사전 캐싱을 끄라고 권하므로, 게임 시작 전 "Vulkan 셰이더 처리"가 길면 Steam 설정 > 다운로드에서 끄면 됩니다.
- ntsync: 커널 모듈은 부팅 때 로드되고(`modules-load.d/ntsync.conf`) `/dev/ntsync`는 누구나 쓸 수 있습니다. Proton-CachyOS와 Proton 11은 기본으로 사용하고, GE-Proton 10을 위해 `PROTON_USE_NTSYNC=1`을 설정했습니다.
- 켜지 않은 것: `PROTON_ENABLE_WAYLAND`(실험적: Steam 오버레이와 일부 입력이 동작하지 않음), DXVK async 계열(공식 DXVK에 없고 안티치트 게임에서 위험, RADV는 GPL로 이미 같은 효과). 게임별로 시작 옵션에서 켤 수 있습니다.

## 3. Ryzen X3D와 CPU 전원

- CCD가 두 개인 X3D(7900X3D, 7950X3D, 9900X3D, 9950X3D)는 `amd_x3d_vcache` 드라이버가 `/sys/bus/platform/drivers/amd_x3d_vcache/*/amd_x3d_mode`를 제공합니다. udev 규칙이 부팅 때 `cache`로 설정해 amd-pstate의 선호 코어 순위에서 V-Cache 코어가 앞에 오게 합니다. BIOS의 CPPC Dynamic Preferred Cores가 "Driver"여야 파일이 생깁니다. CCD가 하나인 X3D(7800X3D, 9800X3D)는 필요 없습니다.
- 게이밍 모드는 이 값을 다시 `cache`로 맞추고, 끌 때 켜기 전 값으로 되돌립니다.
- `scx_lavd --help` 확인 결과: `--cpu-pref-order`는 코어 압축(balanced/powersave)에서만 쓰이고 `--performance`는 모든 코어를 활성으로 둡니다. 그래서 V-Cache 코어 고정은 스케줄러 옵션이 아니라 ① 커널 선호 코어 순위(`amd_x3d_mode=cache`)와 ② GameMode의 `pin_cores=yes`(캐시가 큰 코어/P-코어에 게임 고정, `/etc/gamemode.ini`)로 합니다. ②는 `delay-game %command%`나 `gamemoderun`으로 실행한 게임에 적용됩니다.
- AMD: 커널 기본이 `amd_pstate=active`(EPP)입니다. 평소에는 power-profiles-daemon의 균형 프로필(powersave 거버너 + balance_performance), 게이밍 모드에서는 performance 프로필 + performance 거버너 + EPP performance.
- Intel: 같은 EPP 경로(`intel_pstate`). P/E 코어 구분은 LAVD가 코어 용량으로 처리하고 GameMode `pin_cores`가 게임을 P-코어에 둡니다.

## 4. GPU 드라이버 (`delay-gpu-setup`)

ISO에는 모든 제조사 드라이버가 들어 있고, 설치된 시스템은 실제 GPU에 맞게 정리합니다.

| GPU | 결과 |
|---|---|
| AMD | `mesa`, `vulkan-radeon`, 32비트 |
| Intel | `mesa`, `vulkan-intel`, 32비트, `intel-media-driver` |
| NVIDIA Turing 이상(GTX 16xx, RTX) | `nvidia-open-dkms`, `nvidia-utils`, `lib32-nvidia-utils`, 절전 서비스 |
| NVIDIA Maxwell/Pascal/Volta | `nvidia-580xx-dkms`와 utils(CachyOS 저장소에 있을 때). 설치할 수 없으면 NVIDIA 패키지를 지워 nouveau로 동작 |
| NVIDIA Kepler 이하 | nouveau(470xx/390xx 드라이버는 Wayland를 지원하지 않음) |
| NVIDIA 없음 | NVIDIA 패키지 제거(커널 업데이트마다 DKMS 빌드하지 않음) |

- CachyOS와 달리 `linux-cachyos-nvidia-open`(미리 빌드된 모듈)을 쓰지 않고 DKMS를 유지합니다. `linux-delayos`, `linux-lts`, `linux-cachyos` 세 커널 모두에 모듈이 필요하기 때문입니다.
- CPU 맞춤 패키지를 켜면 Mesa와 NVIDIA 패키지도 CachyOS 저장소 것으로 바뀝니다(저장소 순서가 Arch보다 위).
- NVIDIA 설정은 그대로입니다: `nvidia_drm modeset=1 fbdev=1`, 셰이더 디스크 캐시 10GiB와 정리 안 함. 그 밖의 `__GL_*` 조정은 게임마다 결과가 달라 넣지 않았습니다.

## 5. 게이밍 모드

상단바 버튼(Meta+G) 또는 `delay-gamemode on|off`. GameMode를 쓰는 게임이 시작되면 하드웨어 부분은 버튼 없이도 적용됩니다(`gamemode.ini`의 훅).

| 켤 때 | 끌 때 |
|---|---|
| 전원 프로필 performance | 켜기 전 프로필 |
| 모든 코어 거버너 performance, EPP performance | 코어별로 켜기 전 값 |
| `scx_lavd` gaming 모드(`--performance`) | 켜기 전 스케줄러와 모드 |
| X3D `amd_x3d_mode=cache` | 켜기 전 값 |
| AMD GPU `power_dpm_force_performance_level=high` (잠든 외장 GPU는 깨우지 않음) | 켜기 전 값(보통 auto) |
| packagekit, fwupd, snapper·man-db·updatedb 타이머 정지 | 실행 중이던 타이머만 다시 시작 |
| KWin 블러 등 효과 해제, Baloo 일시 정지, Discover 알림 정지 | 로드되어 있던 효과만 다시 로드, 재개 |

바꾸기 전 값은 `/run/delay-gamemode/saved`에 기록합니다(`sudo delay-gamemode-root status`로 확인). 버튼과 게임 훅이 겹치면 마지막 하나가 끝날 때 되돌립니다. 재부팅하면 모두 기본값입니다.

깊은 CPU 절전 상태(C-state) 차단은 넣지 않았습니다. 발열과 부스트 클럭에 손해가 될 수 있고 효과가 게임마다 다릅니다.

### 게임별 옵션 (`delay-game`)

강제하지 않습니다. 원하는 게임의 Steam 시작 옵션에 `delay-game %command%`를 넣습니다.

- 항상: 성능 전원 프로필 유지 + 화면 꺼짐 방지(`game-performance`), GameMode(`gamemoderun`: X3D/P-코어 고정 포함)
- `delay-gamemode mangohud on|off|toggle`: 다음에 실행하는 게임부터 MangoHud 표시
- `delay-gamemode gamescope on|off|toggle`: gamescope 안에서 실행(모니터 기본 해상도, 전체 화면). 추가 인수는 `~/.config/delayos/gaming.conf`의 `gamescope_args=-w 1920 -h 1080 -F fsr` 또는 `DELAY_GAMESCOPE_ARGS`
- 게임별로 끄기: `DELAY_MANGOHUD=0 DELAY_GAMESCOPE=0 DELAY_GAMEMODE=0 delay-game %command%`

## 위험과 한계

- **외부 저장소 신뢰:** CPU 맞춤 패키지를 켜면 시스템 패키지 대부분을 CachyOS가 빌드하고 서명한 것으로 받습니다. CachyOS 저장소가 멈추거나 키가 바뀌면 업데이트가 막힙니다. 이때 `delay-cpu-opt disable`로 Arch로 돌아갑니다.
- **업데이트로 인한 고장:** CachyOS 저장소는 Arch보다 며칠 앞서거나 늦을 수 있습니다. DelayOS가 직접 빌드한 패키지(`kwin-effect-rounded-corners-git` 등)는 KWin이 올라가면 다시 빌드해야 합니다. 이는 `pacman -Syu` 전반의 문제이며 최적화 저장소에서도 같습니다.
- **CPU를 바꿀 때:** v4/znver4 패키지를 쓰던 디스크를 AVX-512가 없는 PC에 옮기면 부팅되지 않습니다. 옮기기 전에 `delay-cpu-opt disable`을 실행하세요.
- **가상 머신:** 호스트 CPU가 그대로 보이면 그 수준으로 설치됩니다. VM을 다른 호스트로 옮길 때도 위와 같습니다.
