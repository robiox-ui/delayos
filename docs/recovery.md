# 복구: 스냅샷, DelayOS 복구 환경, delay-deploy

DelayOS가 고장 났을 때 쓰는 세 가지를 설명합니다.

| 기능 | Windows에서 비슷한 것 | 도구 |
|---|---|---|
| 시스템 스냅샷, "이전 상태로 부팅" | 시스템 복원 지점 | `delay-snapshot` (snapper, snap-pac, grub-btrfs) |
| DelayOS 복구 (복구 환경) | Windows RE, "고급 시작 옵션", "이 PC 초기화" | 복구 파티션 `DELAYOS-RE`, `delay-recovery-ctl` |
| 배포 도구 | `bcdboot`, `dism /apply-image`, `reagentc` | `delay-deploy` |

설정에서는 **설정 › 시스템 › 복구**에 모여 있습니다.

## 한눈에 보기

```
디스크 (GPT)
├─ EFI 시스템 파티션   /boot/efi   EFI/DelayOS/grubx64.efi, EFI/DelayOS/recovery.efi, EFI/BOOT/BOOTX64.EFI
├─ DelayOS (btrfs)
│    @            시스템 (/). /boot도 여기에 있습니다
│    @home        /home             ┐
│    @cache       /var/cache        │ 스냅샷에 들어가지 않고
│    @log         /var/log          │ 되돌려도 그대로인 데이터
│    @docker      /var/lib/docker   ┘
│    @snapshots   /.snapshots       스냅샷 (snapper 형식: <번호>/snapshot, <번호>/info.xml)
│    @factory     설치 직후의 읽기 전용 사본 ("이 PC 초기화"의 원본)
├─ DELAYOS-RE (ext4, 2 GiB)   복구 환경. 파일 관리자에 보이지 않음
└─ (선택) 숨겨진 Windows 파티션 (docs/windows-switch.md). 복구 기능은 절대 건드리지 않습니다
```

시스템 파티션이 btrfs가 아니면(설치할 때 ext4/xfs를 고른 경우) 스냅샷, 초기화, 복구 파티션이 없습니다. 그 경우에도 설치 USB에서 `delay-deploy boot`로 부팅을 고칠 수 있습니다.

## 1. 시스템 스냅샷

### 언제 만들어지나

- **pacman 작업 직전과 직후** (snap-pac): 앱 설치, 제거, 업데이트마다 한 쌍. 최근 10개를 남기고, 커널 같은 중요 패키지가 낀 것은 6개까지 더 남깁니다.
- **하루에 한 번** (`delay-snapshot-daily.timer`): 최근 5일치와 2주치(주마다 하나)를 남깁니다.
- **되돌리기/초기화 직전**: "되돌리기 전 상태", "초기화 전 상태". 실수로 되돌렸을 때 돌아올 수 있게 합니다.
- **직접**: 설정 › 시스템 › 복구 › "스냅샷 만들기" 또는 `sudo delay-snapshot create -d "설명"`. 직접 만든 것은 지울 때까지 남습니다.

정리는 `snapper-cleanup.timer`가 하고 한도는 `/etc/snapper/configs/root`에 있습니다. snapper가 한 시간마다 만드는 타임라인은 끄고(`TIMELINE_CREATE="no"`) 하루 한 번만 만듭니다. 부팅 메뉴와 디스크가 스냅샷으로 가득 차지 않게 하기 위해서입니다.

스냅샷은 `@`만 담습니다. 홈 폴더, 로그, 패키지 캐시, Docker 데이터(Windows Engine의 가상 디스크 포함)는 다른 하위 볼륨이라 들어가지 않고, 되돌려도 바뀌지 않습니다. 스냅샷은 처음에는 공간을 쓰지 않고, 그 뒤로 시스템이 바뀐 만큼만 차지합니다.

### 되돌리기

```bash
delay-snapshot list                 # 목록
sudo delay-snapshot rollback 12     # 12번 상태로. 다시 시작하면 적용
```

동작: 스냅샷 12를 쓰기 가능한 새 하위 볼륨으로 복사(`@.new`)하고, 지금의 `@`를 `@old-<시각>`으로 바꾼 다음 `@.new`를 `@`로 바꿉니다. GRUB과 fstab은 시스템을 이름(`subvol=@`)으로 찾으므로 다른 것은 고칠 필요가 없습니다. `/boot`가 `@` 안에 있어서 커널과 initramfs도 함께 그 시점으로 돌아가 서로 어긋나지 않습니다. 실행 중이던 옛 `@`는 다음 부팅 때 `delay-snapshot-boot.service`가 지우고 부팅 메뉴를 다시 만듭니다.

`snapper rollback` 명령은 쓰지 않습니다. 그 명령은 기본 하위 볼륨(default subvolume)을 바꾸는 방식이라 `subvol=@`로 부팅하는 이 배치에서는 효과가 없습니다. 목록 보기와 정리는 `snapper -c root list`처럼 snapper를 그대로 써도 됩니다.

`@` 안에 중첩된 하위 볼륨(systemd의 `/var/lib/machines`, `/var/lib/portables` 등)은 스냅샷에 들어가지 않으므로 되돌릴 때 새 시스템으로 옮겨 줍니다.

### 이전 상태로 부팅 (GRUB)

PC를 켤 때 **Esc**를 누르면 부팅 메뉴가 나오고 "이전 상태로 부팅" 아래에 스냅샷이 날짜순으로 있습니다(grub-btrfs, 최근 12개). 스냅샷은 읽기 전용이므로 RAM 덮개를 씌워 부팅합니다(`systemd.volatile=overlay`, initramfs의 `sd-volatile` 훅). 그래서:

- 그 상태에서 바꾼 시스템 설정과 설치한 앱은 다시 시작하면 사라집니다. 홈 폴더의 파일은 평소처럼 저장됩니다.
- 로그인하면 설정 › 시스템 › 복구가 열리고 "이 상태로 되돌리기" 버튼이 보입니다. 잘 동작하면 그 버튼(또는 `sudo delay-snapshot rollback <번호>`)으로 확정합니다.

부팅 메뉴는 기본적으로 숨겨져 있습니다(`GRUB_TIMEOUT_STYLE=hidden`, 1초). GRUB은 대기 시간이 0이면 키를 확인하지 않으므로 1초를 둡니다. Esc는 전원을 켠 직후부터 여러 번 누르는 것이 확실합니다. Shift를 누르고 있어도 메뉴가 나오게 해 두었지만(`keystatus --shift`) 이 기능은 펌웨어가 키 상태를 알려 줄 때만 동작하고, 많은 UEFI PC에서는 동작하지 않습니다. 다른 운영 체제가 함께 설치된 PC(os-prober가 찾은 경우)는 메뉴를 3초 동안 보여 줍니다.


### 부팅 메뉴의 글자

부팅 메뉴는 한국어입니다: "DelayOS", "DelayOS 고급 옵션"(커널별 항목과 대체 initramfs), "UEFI 펌웨어 설정", "이전 상태로 부팅", "DelayOS 복구".

- `/etc/grub.d/10_delayos`와 `30_delayos-firmware`가 grub 패키지의 `10_linux`, `30_uefi-firmware` 대신 항목을 씁니다(항목 id와 커널 옵션은 같음). 원래 파일은 지우지 않고 실행 권한만 뺍니다. grub이 업데이트되면 권한이 돌아오므로 `10_delayos`가 실행될 때마다, 그리고 pacman 훅 `65-delay-grub-ko.hook`이 다시 뺍니다.
- 스냅샷 메뉴는 grub-btrfs가 만든 파일을 `/usr/lib/delayos/delay-grub-ko snapshots`가 고칩니다: 열 제목 "날짜 / 설명", 스냅샷마다 "이 상태로 부팅 (커널 …)"이 먼저, "…, 대체 initramfs"가 그다음. 이 PC의 CPU와 다른 제조사의 마이크로코드 항목은 뺍니다. `41_snapshots-btrfs`에 한 줄을 끼워 넣는 방식이고 grub-btrfs가 업데이트되면 같은 훅이 다시 넣습니다.
- `/etc/default/grub` 끝의 한 줄이 `/etc/locale.conf`의 `LANG`을 읽어 GRUB 자체의 안내문(키 설명)도 한국어로 나오게 합니다.
- 한글은 GRUB의 그래픽 터미널과 unicode 글꼴이 있어야 그려집니다. 글꼴을 불러오지 못하면(`$lang`이 비어 있음) 같은 항목이 영어 제목("DelayOS advanced options", "UEFI firmware settings", "DelayOS Recovery")으로 나옵니다. "이전 상태로 부팅" 하위 메뉴만은 그 경우에도 한글 그대로입니다.
- 펌웨어 부팅 메뉴의 "DelayOS Recovery"와 전용 부트로더 `recovery.efi`의 안내문은 영어입니다. 펌웨어와 글꼴 없는 GRUB 이미지는 한글을 그리지 못합니다.
### 켜기/끄기

새로 설치하면 켜져 있습니다(`delay-postinstall`의 마지막 단계 `delay-snapshot setup --install-time`). 이전 ISO로 설치한 PC는 설정 › 시스템 › 복구의 "켜기" 또는:

```bash
sudo pacman -S --needed snapper snap-pac grub-btrfs inotify-tools
sudo delay-snapshot setup && sudo mkinitcpio -P && sudo grub-mkconfig -o /boot/grub/grub.cfg
```

끄려면 `sudo systemctl disable --now snapper-cleanup.timer delay-snapshot-daily.timer grub-btrfsd`와 `sudo pacman -R snap-pac`.

## 2. DelayOS 복구 (복구 환경)

디스크의 숨겨진 파티션 `DELAYOS-RE`에 들어 있는 작은 Linux입니다(커널 + initramfs + squashfs, 약 380 MB). 설치된 DelayOS가 전혀 시작되지 않아도 따로 시작됩니다. 네트워크와 GPU 드라이버 없이, 펌웨어가 준 화면(`nomodeset`)에서 키보드만으로 씁니다. 한글은 kmscon이 내장 글꼴(GNU Unifont)로 그립니다. kmscon이 화면을 열지 못하면 같은 메뉴가 영어로 나옵니다.

### 들어가는 방법

1. **설정 › 시스템 › 복구 › 고급 시작 옵션 › 지금 다시 시작** (`sudo delay-recovery-ctl reboot`). "이 PC 초기화" 버튼은 초기화 화면을 바로 엽니다.
2. **부팅 메뉴**: PC를 켤 때 Esc → "DelayOS 복구".
3. **자동**: DelayOS가 3번 연속으로 정상 시작하지 못하면 네 번째에 복구 환경이 열리고 시동 복구를 제안합니다.
4. **펌웨어 부팅 메뉴** (F8/F11/F12 등, UEFI만): "DelayOS Recovery". `/boot`나 GRUB 파일이 망가져 2번이 안 될 때를 위한 길입니다. EFI 파티션의 `EFI/DelayOS/recovery.efi`는 `/boot`의 아무 파일도 쓰지 않는 독립된 GRUB 이미지입니다. DelayOS의 부트로더 파일이 없어지면 펌웨어가 부팅 순서의 다음 항목인 이것으로 넘어갑니다.

### 메뉴

| 항목 | 하는 일 |
|---|---|
| 시동 복구 | 파일 시스템 열기 확인(안 열리면 로그 트리 초기화를 물어봄), 디스크 오류 기록 확인, 선택 시 `btrfs check --readonly`, 이어서 `delay-deploy boot`: fstab 점검, 커널 이미지 복원, GRUB 재설치, initramfs와 grub.cfg 재생성, UEFI 부팅 순서 정리 |
| 이전 상태로 되돌리기 | 스냅샷 목록에서 골라 `delay-snapshot rollback` |
| 이 PC 초기화 | **내 파일 유지** 또는 **모두 제거** (아래) |
| 명령 프롬프트 | root 셸. `delay-deploy`, `delay-snapshot`, btrfs-progs, cryptsetup, grub, efibootmgr, parted, nano가 있습니다 |
| 펌웨어 설정(UEFI)으로 재부팅 | `systemctl reboot --firmware-setup` |
| 계속 | 다시 시작해서 DelayOS로 |

`btrfs check --repair`는 메뉴에 없습니다. 상태를 더 나쁘게 만들 수 있어서, 필요하면 명령 프롬프트에서 직접 판단해 실행해야 합니다.

복구 환경은 자신이 시작된 디스크의 DelayOS만 다룹니다. NTFS, BitLocker, FAT 파티션, 숨겨진 Windows 파티션(`DelayOS-Windows`, `DelayOS-WinSetup`), 다른 디스크는 대상 목록에 넣지 않습니다. 디스크가 암호화(LUKS)되어 있으면 먼저 암호를 묻고 `cryptsetup open`으로 엽니다. 작업 기록은 복구 파티션의 `delayos-re/logs/recovery-<날짜>.log`에 남습니다(최근 20개).

Ctrl+Alt+F2에는 root 셸이 따로 있습니다.

### 이 PC 초기화

원본은 설치의 마지막 순간에 찍은 읽기 전용 스냅샷 `@factory`입니다(Calamares 모듈 `delayos_factory`). 초기화는 `@factory`에서 새 `@`를 만드는 일이라 몇 초면 끝나고 내려받는 것이 없습니다.

**내 파일 유지** (`delay-snapshot reset keep`)

- 설치 후에 추가한 앱, 드라이버, 시스템 설정이 사라집니다.
- 유지: 홈 폴더 전체, 사용자 계정과 암호(`/etc/passwd`, `shadow`, `group` 등), PC 이름, Wi-Fi 설정, Bluetooth 연결, 숨겨진 Windows 구성(`/etc/delayos`), fstab.
- 직전 상태가 "초기화 전 상태" 스냅샷으로 남습니다.
- 시스템이 설치 당시 버전으로 돌아가므로 초기화 뒤에 업데이트를 실행해야 합니다.

**모두 제거** (`delay-snapshot reset wipe`)

- `@home`, `@cache`, `@log`, `@docker`와 모든 스냅샷을 지우고 새로 만듭니다. 계정도 지웁니다.
- 메뉴에서 새 계정 이름과 암호를 받아 만듭니다. 그룹은 설치 프로그램이 첫 계정에 준 것과 같습니다.
- 두 번 확인합니다. 되돌릴 수 없습니다.
- 디스크를 덮어쓰지는 않습니다. PC를 남에게 넘길 때 복구 불가능하게 지워야 한다면 설치 USB로 디스크 전체를 다시 설치하세요(SSD는 TRIM이 지워진 블록을 비웁니다).

`@factory`가 없으면(이전 ISO로 설치했거나 지운 경우) 초기화할 수 없고 설치 USB를 안내합니다. 지금 상태를 원본으로 삼으려면 `sudo delay-snapshot factory --refresh`.

`@factory`는 시스템이 업데이트로 달라질수록 디스크를 차지합니다(오래 쓰면 대략 시스템 크기만큼, 10 GB 안팎). 공간이 더 중요하면 `sudo btrfs subvolume delete`로 지울 수 있지만 초기화는 못 하게 됩니다.

### 부팅 실패 감지

`/boot`가 btrfs라서 GRUB은 `/boot/grub/grubenv`에 쓸 수 없습니다. 그래서 상태를 **복구 파티션(ext4)의 `delayos-re/grubenv`**에 둡니다.

- GRUB(`/etc/grub.d/45_delayos-recovery`가 만든 코드): 부팅할 때마다 `delay_boot_ok=0`으로 쓰고, 이전 부팅이 `1`로 바꿔 놓지 않았으면 `delay_boot_tries`를 올립니다. 3이 되면 "DelayOS 복구"를 고르고 카운터를 지웁니다.
- DelayOS: 부팅 90초 뒤 로그인 화면이 떠 있으면(`delay-boot-ok.timer`), 그리고 정상적으로 종료/재시작할 때(`delay-boot-ok.service`) `delay_boot_ok=1`을 씁니다.
- 한 번만 복구 환경으로: `delay_next=recovery`, `delay_re_action=<동작>`. GRUB이 읽고 지웁니다.

90초 안에 전원을 세 번 연속으로 강제로 끄면 복구 환경이 열립니다. "계속"을 고르면 됩니다. 상태 확인은 `sudo delay-recovery-ctl status`.

### 복구 파티션

- Calamares 모듈 `delayos_recoverypart`가 `partition`(그리고 `delayos_winparts`) 다음, `mount` 전에 만듭니다. 방금 만든 빈 시스템 파티션의 끝에서 2 GiB를 떼어 ext4(`DELAYOS-RE`)로 포맷하고 `/usr/share/delayos/recovery/image`의 복구 환경을 복사합니다. 실제 작업은 `delay-deploy recovery create`.
- 만들지 않는 경우(설치는 계속됩니다): 디스크가 64 GB 미만, 시스템이 btrfs가 아님, LVM/RAID, 주 파티션 자리가 없는 MBR 디스크, 복구 환경 없이 빌드한 ISO.
- GPT에서는 파티션 이름 `DELAYOS-RE`와 "필수 파티션" 속성을 붙입니다. udev 규칙 `62-delayos-recovery.rules`(`UDISKS_IGNORE`)로 파일 관리자에 보이지 않습니다.
- 나중에 만들거나 고치기: 설정 › 시스템 › 복구 › 복구 파티션의 "만들기/업데이트" 또는

```bash
sudo delay-deploy recovery create /     # 없으면: 실행 중에 시스템 파티션을 2 GiB 줄여서 만듦
sudo delay-deploy recovery install      # 있으면: 복구 환경만 다시 복사
sudo delay-deploy boot /                # 부팅 메뉴 항목과 전용 부트로더까지 다시
```

Secure Boot(`delayos-sb-general`, docs/windows-switch.md)를 쓰는 설치에서는 복구 환경의 커널을 서명된 사본으로 바꿔 넣습니다(같은 커널 이미지일 때). 전용 부트로더 `recovery.efi`는 서명되지 않아 그 구성에서는 설치하지 않습니다.

## 3. delay-deploy

```
delay-deploy boot <루트> [--esp <경로>] [--bios <디스크>]     부트로더와 부팅 항목 (bcdboot)
delay-deploy apply <이미지> <파티션> [--format|--replace-system]  이미지 풀기 (dism /apply-image)
delay-deploy capture <루트> <이미지>                           이미지 만들기 (dism /capture-image)
delay-deploy recovery status|create|install|loader             복구 파티션 (reagentc)
공통: --dry-run (바꾸지 않고 할 일만 출력), --force, --help
```

### boot

`<루트>`는 DelayOS가 마운트된 곳입니다. `/`이면 실행 중인 시스템, 복구 환경이나 설치 USB에서는 `/mnt` 같은 곳입니다. 다른 파일 시스템(`/proc`, `/dev`, EFI 파티션)은 도구가 알아서 붙였다가 뗍니다.

1. fstab 점검: 루트나 EFI 파티션의 UUID가 실제와 다르면 고치고, 없는 장치를 가리키는 다른 항목에는 `nofail`을 붙입니다(원본은 `fstab.delay-bak`). 루트 항목이 아예 없으면 새로 씁니다.
2. `/boot/vmlinuz-*`가 없으면 커널 패키지가 `/usr/lib/modules/<버전>/vmlinuz`에 둔 사본으로 복원합니다.
3. `grub-install`: UEFI는 `EFI/DelayOS`와 펌웨어 항목 "DelayOS", 대체 경로 `EFI/BOOT/BOOTX64.EFI`(다른 운영 체제의 것이면 덮어쓰지 않음), 복구 환경 전용 `recovery.efi`. BIOS는 디스크의 MBR. Secure Boot 구성이면 `delay-winsetup sb-setup`으로 서명된 GRUB과 커널을 다시 놓습니다.
4. `mkinitcpio -P`
5. `grub-mkconfig`
6. UEFI 부팅 순서에서 DelayOS를 맨 앞으로.

### apply / capture

```bash
sudo delay-deploy capture / /mnt/usb/delayos.dimg            # 실행 중인 시스템을 캡처 (@만)
sudo delay-deploy apply /mnt/usb/delayos.dimg /dev/sdb2 --esp /dev/sdb1 --format
sudo delay-deploy apply delayos.dimg /dev/nvme0n1p2 --replace-system   # @만 교체, @home 유지
```

- `.dimg`는 읽기 전용 스냅샷의 `btrfs send` 스트림을 zstd로 압축한 것입니다. `.tar.zst`, `.sfs`도 됩니다(확장자로 고름).
- `apply`는 하위 볼륨 `@ @home @cache @log @snapshots @docker`와 fstab을 만들고 `boot`를 실행합니다. 사용자 계정은 이미지에 들어 있는 그대로입니다.
- 설치 USB로 부팅한 상태에서는 USB의 `airootfs.sfs`도 적용할 수 있습니다. 이때는 커널을 USB에서 복사하고 `delay-postinstall`을 실행합니다. 계정은 직접 만들어야 합니다. 설치 프로그램 없이 설치하는 방법이고, 이 문서의 기능을 시험한 VM도 이렇게 설치했습니다.
- `--overlay <폴더>`: 이미지를 푼 뒤 폴더의 파일을 덮어씁니다.

### 안전장치

- NTFS/BitLocker/FAT/exFAT, EFI 파티션, `DELAYOS-RE`, 숨겨진 Windows 파티션에는 `--force`를 줘도 이미지를 풀지 않습니다.
- 마운트된 파티션, 실행 중인 시스템이 쓰는 파티션은 거부합니다.
- 실행 중인 시스템과 같은 디스크의 다른 파티션, 다른 디스크의 MBR은 `--force`가 있어야 합니다. 복구 환경은 같은 디스크의 복구 파티션에서 시작하므로 메뉴가 `--force`를 붙여 부릅니다.
- 파일 시스템이 있는 파티션은 `--format`이 있어야 지웁니다. DelayOS가 이미 있으면 `--format`이나 `--replace-system` 중 하나를 골라야 합니다.

## 빌드

`build.sh`가 `recovery/build-recovery.sh`를 불러 복구 환경을 만듭니다. `recovery/profile`은 작은 archiso 프로필이고 mkarchiso의 netboot 모드로 커널, initramfs, `airootfs.sfs`만 만듭니다(ISO 없음). 커널은 본 ISO와 같은 `linux-delayos` 패키지입니다. 결과는 ISO의 `/usr/share/delayos/recovery/image/delayos-re/`에 들어가 설치된 시스템에도 남으므로 복구 파티션을 나중에 다시 만들 수 있습니다.

- 소스(`recovery/`, 도구 세 개)와 커널 패키지가 그대로면 다시 만들지 않습니다. 새로 만들 때 3~5분.
- `DELAYOS_RECOVERY=0 ./build.sh`: 복구 환경 없이 빌드. `DELAYOS_RE_REBUILD=1`: 강제로 다시.
- 따로 만들어 보기: `sudo RE_KERNEL=linux-lts recovery/build-recovery.sh /tmp/re-image` (로컬 저장소 없이 Arch 저장소의 커널로).
- `delay-deploy`, `delay-snapshot`, `delay-recovery-ctl`은 `profile/airootfs/usr/local/bin`의 것을 복사해 넣습니다. 복구 메뉴 `delay-recovery`만 `recovery/profile`에 있습니다.

## 파일

| 경로 | 내용 |
|---|---|
| `/usr/local/bin/delay-snapshot` | 스냅샷 만들기/목록/삭제/되돌리기, `setup`, `factory`, `reset` |
| `/usr/local/bin/delay-deploy` | boot / apply / capture / recovery |
| `/usr/local/bin/delay-recovery-ctl` | 복구 환경으로 재시작, 부팅 성공 기록, 상태 |
| `/etc/grub.d/45_delayos-recovery` | 부팅 메뉴 항목 "DelayOS 복구", 한 번만 시작, 3회 실패 감지 |
| `/etc/grub.d/10_delayos`, `30_delayos-firmware`, `/usr/lib/delayos/delay-grub-ko`, `/etc/pacman.d/hooks/65-delay-grub-ko.hook` | 한국어 부팅 메뉴 |
| `/usr/lib/systemd/system/delay-snapshot-{daily.timer,daily.service,boot.service}` | 매일 스냅샷, 되돌린 뒤 정리 |
| `/usr/lib/systemd/system/delay-boot-ok{.service,.timer,-mark.service}` | 부팅 성공 기록 |
| `/usr/lib/udev/rules.d/62-delayos-recovery.rules` | 복구 파티션 숨기기 |
| `/usr/lib/delayos/delay-recovery-info`, `org.delayos.recovery.policy` | 설정 앱이 암호 없이 상태를 읽는 통로 (변경은 `delay-sys-helper recovery …`, 암호 필요) |
| `/usr/share/delayos/apps/settings/{sb/recovery.py,qml/pages/Recovery.qml}` | 설정 › 시스템 › 복구 |
| `/etc/xdg/autostart/org.delayos.SnapshotBoot.desktop` | 스냅샷으로 부팅했을 때 복구 페이지 열기 |
| `/usr/lib/calamares/modules/delayos_recoverypart`, `delayos_factory` | 설치 프로그램 단계 |
| `recovery/profile`, `recovery/build-recovery.sh` | 복구 환경의 archiso 프로필과 빌드 스크립트 |
| `/etc/snapper/configs/root`, `/etc/mkinitcpio.conf.d/delayos-snapshots.conf` | `delay-snapshot setup`이 씀 |

설치 프로그램 설정에서 바뀐 것: `mount.conf`의 `btrfsSubvolumes`에 `/.snapshots → @snapshots`, `/var/lib/docker → @docker` 두 줄, `settings.conf`의 실행 순서에 `delayos_recoverypart`(`delayos_winparts` 다음)와 `delayos_factory`(`umount` 직전).

## 한계

- 복구 환경의 커널은 ISO를 만들 때의 것입니다. 시스템을 업데이트해도 복구 파티션은 바뀌지 않습니다(복구 환경을 패키지로 배포하는 것은 아직 없음).
- BIOS(레거시) 부팅 PC에는 전용 부트로더가 없어서 GRUB이 `/boot`를 읽지 못하면 복구 환경에 들어갈 수 없습니다. 설치 USB를 쓰세요.
- 암호화(LUKS) 설치에서는 GRUB이 먼저 암호를 물은 뒤에야 부팅 메뉴가 나옵니다. 펌웨어 부팅 메뉴의 "DelayOS Recovery"는 암호 없이 시작하고 복구 환경이 암호를 묻습니다.
- 시동 복구는 설치된 시스템 안의 GRUB과 mkinitcpio를 씁니다. 그것들이 없을 만큼 망가졌으면 되돌리기나 초기화를 써야 합니다.
- 스냅샷으로 부팅한 상태에서는 `delay-deploy boot /`를 쓸 수 없습니다(루트가 RAM 덮개).
