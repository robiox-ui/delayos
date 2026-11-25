"""Hardware detection and driver recommendations (shared by Settings › 업데이트 및 드라이버 and the Drivers app).

lspci -nnk gives vendor:device ids and the kernel driver in use. For each device class we recommend the
packages a gaming install wants; `installed` is checked with pacman -Q.
"""
import re
from syskit import sh, out

NV_OPEN_MIN = 0x1E00   # Turing and newer -> nvidia-open (device ids >= 0x1e00 are TU1xx+)
NV_580_MIN = 0x1300    # Maxwell/Pascal/Volta -> legacy 580xx branch


def _installed(pkgs):
    if not pkgs:
        return {}
    rc, o = sh(["pacman", "-Q"] + pkgs, 10)
    have = {l.split()[0] for l in o.splitlines() if l.strip()}
    return {p: p in have for p in pkgs}


def _lspci():
    devs, cur = [], None
    for l in out(["lspci", "-nnk"], 10).splitlines():
        if l and not l[0].isspace():
            m = re.match(r"(\S+) (.+?) \[([0-9a-f]{4})\]: (.+) \[([0-9a-f]{4}):([0-9a-f]{4})\]", l)
            if m:
                cur = {"slot": m.group(1), "cls": m.group(2), "clsId": m.group(3), "name": m.group(4),
                       "vendor": m.group(5), "device": m.group(6), "driver": ""}
                devs.append(cur)
            else:
                cur = None
        elif cur is not None and "Kernel driver in use:" in l:
            cur["driver"] = l.split(":", 1)[1].strip()
    return devs


def _short(name):
    name = re.sub(r"\(rev [0-9a-f]+\)", "", name)
    name = name.replace("Advanced Micro Devices, Inc. [AMD/ATI]", "AMD").replace("NVIDIA Corporation", "NVIDIA")
    name = name.replace("Intel Corporation", "Intel").replace("Realtek Semiconductor Co., Ltd.", "Realtek")
    name = name.replace("Broadcom Inc. and subsidiaries", "Broadcom").replace("Qualcomm Atheros", "Qualcomm")
    m = re.search(r"\[([^\]]+)\]\s*$", name.strip())
    if m and len(m.group(1)) > 3:
        vend = name.split(" ")[0]
        name = vend + " " + m.group(1)
    return name.strip()


def detect():
    res = []
    for d in _lspci():
        cid, ven, dev = d["clsId"], d["vendor"], int(d["device"], 16)
        item = {"slot": d["slot"], "name": _short(d["name"]), "driver": d["driver"] or "없음",
                "kind": "", "icon": "", "packages": [], "note": "", "recommended": ""}
        if cid.startswith("03"):  # display
            item["kind"] = "그래픽"
            item["icon"] = "video-display"
            if ven == "10de":
                if dev >= NV_OPEN_MIN:
                    item["packages"] = ["nvidia-open-dkms", "nvidia-utils", "lib32-nvidia-utils", "nvidia-settings"]
                    item["recommended"] = "NVIDIA 독점 드라이버 (오픈 커널 모듈)"
                elif dev >= NV_580_MIN:
                    item["packages"] = ["nvidia-580xx-dkms", "nvidia-580xx-utils", "lib32-nvidia-580xx-utils"]
                    item["recommended"] = "NVIDIA 580xx 레거시 드라이버"
                else:
                    item["recommended"] = "오픈소스 nouveau 드라이버 (이 GPU는 최신 NVIDIA 드라이버를 지원하지 않습니다)"
                    item["packages"] = ["mesa", "vulkan-nouveau", "lib32-mesa"]
            elif ven == "1002":
                item["packages"] = ["mesa", "lib32-mesa", "vulkan-radeon", "lib32-vulkan-radeon", "libva-mesa-driver"]
                item["recommended"] = "AMD 오픈소스 드라이버 (Mesa RADV)"
            elif ven == "8086":
                item["packages"] = ["mesa", "lib32-mesa", "vulkan-intel", "lib32-vulkan-intel", "intel-media-driver"]
                item["recommended"] = "Intel 오픈소스 드라이버 (Mesa ANV)"
            elif ven == "15ad":
                item["packages"] = ["mesa", "open-vm-tools"]
                item["recommended"] = "VMware 가상 그래픽 (SVGA)"
            elif ven == "1af4" or ven == "1234":
                item["packages"] = ["mesa"]
                item["recommended"] = "가상 머신 그래픽 (virtio)"
        elif cid == "0280":  # wireless
            item["kind"] = "Wi-Fi"
            item["icon"] = "network-wireless"
            if ven == "14e4" and d["driver"] in ("", "bcma-pci-bridge"):
                item["packages"] = ["broadcom-wl-dkms"]
                item["recommended"] = "Broadcom wl 드라이버"
            else:
                item["packages"] = ["linux-firmware"]
                item["recommended"] = "커널 내장 드라이버 + 펌웨어"
        elif cid == "0200":  # ethernet
            item["kind"] = "이더넷"
            item["icon"] = "network-wired"
            if ven == "10ec" and dev in (0x8125, 0x8126):
                item["packages"] = ["r8125-dkms"] if dev == 0x8125 else []
                item["recommended"] = "Realtek 2.5GbE 드라이버" if dev == 0x8125 else "커널 내장 드라이버"
            else:
                item["recommended"] = "커널 내장 드라이버"
        elif cid in ("0403", "0401"):
            item["kind"] = "오디오"
            item["icon"] = "audio-card"
            item["packages"] = ["sof-firmware", "alsa-firmware"] if ven == "8086" else []
            item["recommended"] = "PipeWire + 커널 내장 드라이버"
        else:
            continue
        res.append(item)
    # gaming extras that apply to every machine
    extras = {"slot": "extra", "name": "게임 런타임", "kind": "게임", "icon": "input-gaming",
              "driver": "Vulkan / 32비트 라이브러리", "packages": ["vulkan-icd-loader", "lib32-vulkan-icd-loader", "gamemode", "lib32-gamemode"],
              "recommended": "Steam과 Proton 게임에 필요한 Vulkan·GameMode 구성 요소", "note": ""}
    res.append(extras)
    allp = sorted({p for r in res for p in r["packages"]})
    inst = _installed(allp)
    for r in res:
        missing = [p for p in r["packages"] if not inst.get(p)]
        r["missing"] = missing
        r["ok"] = not missing
    return res
