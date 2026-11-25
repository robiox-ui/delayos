# CachyOS 분석 → DelayOS 적용 정리

CachyOS GitHub 조직의 저장소 129개를 5개 묶음으로 나눠 읽었습니다(2026-11-25). 자세한 내용은 아래 보고서에 있습니다.

| 보고서 | 다루는 저장소 |
|---|---|
| [linux-cachyos.md](linux-cachyos.md) | 커널 PKGBUILD, 변형 11개, config |
| [kernel-patches.md](kernel-patches.md) | 7.3 / 7.4 패치, BORE 설정값 |
| [system-tuning.md](system-tuning.md) | CachyOS-Settings, ananicy-rules, chwd, scx, tuned, uksmd 등 13개 |
| [build-toolchain.md](build-toolchain.md) | PKGBUILD 모음, pacman, makepkg 플래그, 툴체인 37개 |
| [gaming-desktop.md](gaming-desktop.md) | proton/wine, gamescope, ISO, 설치기, KDE·테마, 위키 등 나머지 전부 |

## 적용한 것

- **커널 `linux-delayos`** (`kernel/linux-delayos/`): CachyOS PKGBUILD와 config를 그대로 씁니다.
  - 소스: CachyOS 패치가 적용된 7.3.6 소스
  - 스케줄러와 컴파일: BORE 스케줄러, Clang ThinLTO, `-O3`
  - 타이머와 선점: 1000Hz, full tickless, full preempt
  - 메모리: THP always, MGLRU
  - 그 밖에 ntsync, ADIOS
  - CachyOS와 다른 점:
    - `generic_v1`로 빌드합니다. CachyOS 기본값인 native는 빌드한 PC에서만 돌아가기 때문입니다.
    - BBRv3를 기본으로 켰습니다.
- **시스템 튜닝** (`/usr/lib`, CachyOS-Settings와 동일): sysctl, zram, I/O 스케줄러 udev, THP, SATA, 오디오 절전, NVIDIA 런타임 PM, HPET/RTC, 워치독 블랙리스트, systemd 타임아웃/limits/oomd, journald 크기, ntsync, `game-performance`, `kerver`, `pci-latency`, `dlss-swapper`, `zink-run`, `topmem`
- **스케줄러 확장:** `scx-scheds`를 넣었습니다. CachyOS는 게임용으로 `scx_lavd --performance`를 씁니다.
- **KDE:** 애니메이션 0.25, Baloo 인덱싱 끔
- **게임:** `* hard nice -15` (proton-cachyos 권장)
- **라이브 ISO 커널 옵션:** `copytoram=auto cow_spacesize=10G nvme_load=yes i915/amdgpu.modeset=1 module_blacklist=pcspkr`
- **설치기:** Btrfs `noatime,compress=zstd:1`, zram, `zswap.enabled=0`, fstrim. 이미 CachyOS와 같았습니다.
- **makepkg** (`/etc/makepkg.conf.d/delayos.conf`): `-O3 -pipe -fno-plt`, `-flto=auto`, Rust `opt-level=3`, zstd `-20`. CPU 대상은 일반 x86-64입니다.

## 적용하지 않은 것과 이유

- **CachyOS 바이너리 저장소(v3/v4/znver4 재빌드 패키지):** CachyOS 서명 키와 pacman 포크가 필요합니다. 따로 결정할 사항입니다.
- **EAC 커널 변형과 `eac-setup`:** CachyOS 전용 Secure Boot 키가 필요합니다.
- **AutoFDO/Propeller 프로파일:** 저장소에 프로파일이 없습니다. 실제 하드웨어에서 따로 측정해야 합니다.
- **CachyOS 전용 도구:** 버그 리포트, paste, debuginfod URL, CachyOS 아이콘과 브랜딩
