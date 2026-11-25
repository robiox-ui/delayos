#!/usr/bin/env python3
"""Plymouth theme images for /usr/share/plymouth/themes/temuos (ui-spec §1).

  python3 gen_boot.py <out-root>      (needs Pillow, numpy, rsvg-convert, Noto Sans CJK KR + Inter)
"""
import os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

root = sys.argv[1]
T = os.path.join(root, 'usr/share/plymouth/themes/temuos')
os.makedirs(T, exist_ok=True)
LOGO = os.path.join(root, 'usr/share/temuos/logo/temuos.svg')

# background: #0B0B10 + brand-crimson radial glow at 18 %, centred 50 % / 0 %
W, H = 1920, 1080
y, x = np.mgrid[0:H, 0:W].astype(np.float32)
d = np.sqrt(((x - W / 2) / (W * 0.55)) ** 2 + (y / (H * 0.75)) ** 2)
g = np.clip(1 - d, 0, 1) ** 1.8 * 0.18
base = np.array([0x0B, 0x0B, 0x10], np.float32)
crim = np.array([0xD4, 0x19, 0x4F], np.float32)
img = base * (1 - g[..., None]) + crim * g[..., None]
rng = np.random.default_rng(3)
img += (rng.random((H, W, 1), dtype=np.float32) - 0.5) * 0.9      # dither
Image.fromarray(np.clip(img + 0.5, 0, 255).astype(np.uint8), 'RGB').save(os.path.join(T, 'background.png'), optimize=True)

# logo at 2x of 132 px
subprocess.run(['rsvg-convert', '-w', '264', '-h', '264', LOGO, '-o', os.path.join(T, 'logo.png')], check=True)


def circle(path, size, rgba):
    s = size * 4
    im = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(im).ellipse((0, 0, s - 1, s - 1), fill=rgba)
    im.resize((size, size), Image.LANCZOS).save(os.path.join(T, path))


circle('dot.png', 24, (0xF4, 0x7D, 0x67, 255))        # accent (Coral)
circle('bullet.png', 16, (0xF2, 0xF3, 0xF5, 255))

# password field 280x40 (2x), radius 8, field colour + 1 px rim, accent focus border
fw, fh = 560, 80
im = Image.new('RGBA', (fw * 2, fh * 2), (0, 0, 0, 0))
dr = ImageDraw.Draw(im)
dr.rounded_rectangle((0, 0, fw * 2 - 1, fh * 2 - 1), 32, fill=(0xF4, 0x7D, 0x67, 255))
dr.rounded_rectangle((6, 6, fw * 2 - 7, fh * 2 - 7), 28, fill=(0x1E, 0x21, 0x29, 255))
im.resize((fw, fh), Image.LANCZOS).save(os.path.join(T, 'field.png'))

# Korean prompt label (rendered here: the initramfs only carries a Latin font)
def label(path, text, px, rgb):
    f = ImageFont.truetype('/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc', px, index=1)  # index 1 = KR
    l, t, r, b = f.getbbox(text)
    im = Image.new('RGBA', (r - l + 8, b - t + 8), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((4 - l, 4 - t), text, font=f, fill=rgb + (255,))
    im.save(os.path.join(T, path))


label('prompt.png', '디스크 암호를 입력하세요', 30, (0x9A, 0xA0, 0xAA))
label('wrong.png', '암호가 올바르지 않습니다', 26, (0xF4, 0x7D, 0x67))
subprocess.run(['rsvg-convert', '-w', '36', '-h', '36', os.path.join(root, 'usr/share/icons/TemuOS/symbolic/actions/temuos-sym-lock.svg'),
                '-o', os.path.join(T, 'lock.png')], check=True)
print('ok')
