# 안티치트 모드 (Easy Anti-Cheat Linux v2)

Epic은 2026년 10월 14일에 Easy Anti-Cheat(EAC) Linux v2를 발표했습니다. EAC v2 게임은 PC가 아래 8가지 조건을 모두 갖춰야 실행됩니다. 조건이 맞지 않으면 게임이 오류 메시지를 띄우고 끝납니다. 계정이 정지되지는 않습니다.

TEMUOS_LINUX는 이 조건을 갖춘 별도 부팅 항목 **"TEMUOS (안티치트 모드)"**를 제공합니다. 평소에는 지금처럼 일반 모드(`linux-temuos`)로 쓰고, EAC 게임을 할 때만 안티치트 모드로 부팅하면 됩니다.

> **아직 남은 한 가지 (TEMUOS가 해결할 일):** EAC는 Epic이 승인한 "잘 알려진 키"로 서명된 커널만 받아들입니다. 지금 승인된 키는 Canonical(Ubuntu), Fedora, Universal Blue, Debian, openSUSE, SUSE, Rocky Linux, AlmaLinux, Microsoft UEFI CA입니다. TEMUOS 키는 Epic에 승인을 요청한 상태입니다(linux-gaming@epicgames.com). **승인 전까지는 아래 설정을 모두 마쳐도 EAC 게임이 실행을 거부합니다.** 설정 앱의 "앱 지원 → 안티치트 (EAC Linux v2)" 카드에 승인 상태가 표시됩니다. 그동안은 일반 모드(`linux-temuos`)로 다른 게임을 그대로 즐기세요.

## 무엇이 준비되어 있나요

| Epic 요구 사항 | TEMUOS에서 |
|---|---|
| 1. 커널과 모든 커널 모듈이 잘 알려진 키로 서명됨 | `linux-temuos-eac` 커널: 커널 이미지와 모든 모듈(NVIDIA 오픈 모듈, r8125 포함)을 TEMUOS 키로 서명합니다. 서명 없는 모듈은 로드되지 않습니다. |
| 2. TPM 2.0 | PC 기능입니다. BIOS에서 켭니다. |
| 3. Secure Boot, 부팅 체인에 잘 알려진 키만 | Microsoft 서명 shim → TEMUOS 서명 GRUB(또는 systemd-boot) → TEMUOS 서명 커널. TEMUOS 인증서는 MOK로 등록합니다. |
| 4. 측정 부팅(Measured Boot) | 펌웨어와 GRUB(tpm 모듈) / systemd-boot가 TPM에 기록합니다. |
| 5. IOMMU 켜짐, 통과(passthrough) 모드 아님 | 커널 기본값과 부팅 옵션 `iommu.passthrough=0 intel_iommu=on`. BIOS에서도 켜야 합니다. 휴대용 게임기(Steam Deck, ROG Ally 등)는 필요 없습니다. |
| 6. 커널 잠금(lockdown) 무결성 모드 | 커널 설정과 부팅 옵션 `lockdown=integrity` |
| 7. kexec 차단 | 부팅 옵션 `sysctl.kernel.kexec_load_disabled=1` |
| 8. BPF LSM 동작 | 부팅 옵션 `lsm=landlock,lockdown,yama,integrity,bpf` |

EAC는 커널 모듈을 설치하지 않습니다. 게임을 처음 실행하면 게임이 EAC 시스템 서비스(systemd) 설치를 묻고, 이 서비스는 EAC 게임이 실행 중일 때만 동작합니다.

## 설정 방법

### 1. 안티치트 모드 설치

설정 앱 → 앱 지원 → 안티치트 (EAC Linux v2) → **설정**을 누르거나, 터미널(Konsole)에서:

```bash
temu-eac setup
```

관리자 비밀번호를 물은 뒤 다음을 자동으로 합니다.

- `linux-temuos-eac` 커널 설치 (NVIDIA 그래픽카드가 있으면 `linux-temuos-eac-nvidia-open`도)
- Microsoft 서명 shim과 TEMUOS 서명 부트로더를 EFI 파티션(`EFI/TEMUOS_SB`)에 설치하고 UEFI 부팅 항목 "TEMUOS Secure Boot"를 맨 앞에 추가
- 부팅 메뉴에 **"TEMUOS (안티치트 모드)"** 추가 (GRUB / systemd-boot)
- TEMUOS 인증서를 MOK로 등록 요청. 이때 **일회용 비밀번호**를 정합니다 (숫자와 영문 소문자 권장, 다음 재부팅 때 한 번만 씁니다).

### 2. 재부팅하고 인증서 등록 (한 번만)

재부팅하면 파란 화면(MokManager)이 나타납니다. 10초 안에 아무 키나 누르고:

**Enroll MOK → Continue → Yes → 비밀번호 입력 → Reboot**

### 3. BIOS 설정 (한 번만)

부팅 중 `Del` 또는 `F2`로 BIOS에 들어가서:

- **Secure Boot 켜기.** OS 유형은 "Windows UEFI 모드"로 둡니다. "Microsoft 3rd-party UEFI CA 허용(Allow Microsoft 3rd Party UEFI CA)" 같은 항목이 있으면 켭니다(최신 Windows 11 노트북에서 꺼져 있는 경우가 많습니다).
- **TPM 2.0 켜기.** Intel은 "PTT", AMD는 "fTPM"입니다.
- **IOMMU 켜기.** Intel은 "VT-d", AMD는 "AMD-Vi" 또는 "IOMMU: Enabled"입니다.
- MSI 메인보드는 "Secure Boot Preset"을 "Maximum Security"로 설정합니다(오래된 펌웨어는 "Image Execution Policy"를 "Deny Execute"로).
- Secure Boot를 켠 뒤 부팅이 안 되면 BIOS를 최신 버전으로 업데이트하세요. 2026년 이후 shim은 "Microsoft UEFI CA 2023"으로 서명되어 있어, 이 인증서가 없는 오래된 펌웨어에서는 부팅되지 않을 수 있습니다(Windows 업데이트나 BIOS 업데이트로 추가됩니다).

### 4. 안티치트 모드로 부팅

부팅 메뉴에서 **"TEMUOS (안티치트 모드)"**를 고릅니다. 바로 다시 시작하려면 `temu-eac boot`(또는 설정 앱의 버튼)를 씁니다. 고급 메뉴(Advanced options)에 보이는 `linux-temuos-eac` 항목은 필요한 부팅 옵션이 없어서 EAC 검사를 통과하지 못합니다.

### 5. 확인

```bash
temu-eac status
```

8가지 조건을 하나씩 "충족 / 미충족 / 부팅 후"로 보여 줍니다. 설정 앱의 카드도 같은 결과를 보여 줍니다.

## 안티치트 모드에서 달라지는 점

- 최대 절전(하이버네이션)을 쓸 수 없습니다. 절전(Suspend)은 됩니다.
- 서명되지 않은 DKMS 모듈(xpadneo, v4l2loopback-dkms, VirtualBox/VMware 호스트 모듈 등)은 로드되지 않습니다. Xbox 컨트롤러는 커널 기본 드라이버로 동작합니다.
- `/dev/mem`, MSR 쓰기를 쓰는 언더볼트/튜닝 도구는 동작하지 않습니다.
- 일반 모드(`linux-temuos`)는 아무것도 바뀌지 않습니다. 다만 **Secure Boot를 켜면 TEMUOS 서명 항목(안티치트 모드)과 Windows만 부팅됩니다.** 일반 모드와 `linux-lts`는 커널 잠금이 없는 커널이라 TEMUOS 키로 서명하지 않으며, Secure Boot를 끈 상태에서만 부팅됩니다. Secure Boot가 켜져 있으면 GRUB이 안티치트 모드를 자동으로 기본 항목으로 고릅니다. 안티치트 모드는 평소 용도로 써도 괜찮습니다(NVIDIA 드라이버, 유선랜 r8125 포함).
- **Epic 승인 전에는 Secure Boot를 켤 필요가 없습니다.** 승인 전에는 EAC 게임이 어차피 실행되지 않으므로, 지금처럼 Secure Boot를 끈 채 일반 모드(`linux-temuos`)로 모든 게임을 하세요. 설치와 인증서 등록은 미리 해 두어도 됩니다.
- NVIDIA: 안티치트 모드의 NVIDIA 모듈은 시스템의 `nvidia-utils`와 버전이 정확히 같아야 합니다. TEMUOS 업데이트로 함께 갱신됩니다.

## 되돌리기

- 부팅 메뉴에서 일반 항목을 고르면 그대로 일반 모드입니다.
- 안티치트 항목을 지우려면: `sudo rm /etc/grub.d/42_temuos-eac && sudo grub-mkconfig -o /boot/grub/grub.cfg` (systemd-boot는 `/boot/loader/entries/temuos-eac.conf` 삭제), 커널은 `sudo pacman -Rns linux-temuos-eac`.
- TEMUOS 인증서 등록 해제: `sudo mokutil --delete /usr/share/temuos/secureboot/temuos-sb-ca.cer` 후 재부팅해서 MokManager에서 승인.
