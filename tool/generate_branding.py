#!/usr/bin/env python3
"""Generates the app mark (launcher icons, web icons, in-app logo).

The design is deterministic: dark asphalt badge, a chunky safety-yellow "P"
and a hazard-striped curb at the bottom. Run from the repo root:

    python3 tool/generate_branding.py

Requires Pillow (`python3 -m pip install pillow`).
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter
import random

ROOT = Path(__file__).resolve().parent.parent
SIZE = 1024
YELLOW = (255, 214, 10, 255)
INK = (10, 12, 15, 255)
WHITE = (245, 246, 248, 255)


def gradient(size, top, bottom):
    img = Image.new('RGBA', (size, size))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line([(0, y), (size, y)], fill=color + (255,))
    return img


def badge_mask(size, radius):
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=radius, fill=255
    )
    return mask


def base_layer(size):
    layer = gradient(size, (34, 41, 48), (7, 9, 12))
    rnd = random.Random(11)
    speck = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(speck)
    for _ in range(size * size // 700):
        x, y = rnd.randrange(size), rnd.randrange(size)
        radius = rnd.choice([1, 1, 2])
        draw.ellipse(
            [x, y, x + radius, y + radius],
            fill=(255, 255, 255, rnd.randrange(6, 22)),
        )
    layer = Image.alpha_composite(layer, speck)
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [-size * 0.4, -size * 0.6, size, size * 0.55],
        fill=(255, 255, 255, 16),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.08))
    return Image.alpha_composite(layer, glow)


def p_mask(size):
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    left, top, stem, bowl, bottom = 250, 180, 180, 380, 760
    right = left + 540
    draw.rounded_rectangle([left, top, left + stem, bottom], radius=42, fill=255)
    draw.rounded_rectangle([left, top, right, top + bowl], radius=180, fill=255)
    # Counter (the hole of the P), cut back to transparent.
    draw.rounded_rectangle(
        [left + stem, top + 140, right - 130, top + 260], radius=62, fill=0
    )
    return mask


def hazard_band(layer, size, y0, stripe=64):
    band = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(band)
    draw.rectangle([0, y0, size, size], fill=YELLOW)
    for x in range(-size, size * 2, stripe * 2):
        draw.polygon(
            [
                (x, y0),
                (x + stripe, y0),
                (x + stripe - (size - y0), size),
                (x - (size - y0), size),
            ],
            fill=INK,
        )
    return Image.alpha_composite(layer, band)


def render(size=SIZE, full_bleed=False, content_scale=1.0):
    layer = base_layer(size)
    p = p_mask(size)
    shadow = p.filter(ImageFilter.GaussianBlur(size * 0.01))
    layer.paste((0, 0, 0, 120), (0, int(size * 0.018)), shadow)
    layer.paste(YELLOW, (0, 0), p)
    layer = hazard_band(layer, size, int(size * 0.8))

    if content_scale != 1.0:
        inner = int(size * content_scale)
        scaled = layer.resize((inner, inner), Image.LANCZOS)
        layer = Image.new('RGBA', (size, size), INK)
        offset = (size - inner) // 2
        layer.alpha_composite(scaled, (offset, offset))
        return layer

    mask = badge_mask(size, int(size * 0.225))
    layer.putalpha(
        Image.composite(
            layer.getchannel('A'), Image.new('L', (size, size), 0), mask
        )
    )
    return layer


def save(image, path, size):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.LANCZOS).save(path, optimize=True)
    print(f'{path.relative_to(ROOT)} {size}x{size}')


def main():
    master = render()

    save(master, ROOT / 'assets/branding/logo.png', 512)
    save(master, ROOT / 'web/favicon.png', 32)
    save(master, ROOT / 'web/icons/Icon-192.png', 192)
    save(master, ROOT / 'web/icons/Icon-512.png', 512)

    # Maskable icons need the badge inside the safe zone of a full-bleed tile.
    maskable = render(full_bleed=True, content_scale=0.72)
    save(maskable, ROOT / 'web/icons/Icon-maskable-192.png', 192)
    save(maskable, ROOT / 'web/icons/Icon-maskable-512.png', 512)

    for folder, px in [
        ('mdpi', 48),
        ('hdpi', 72),
        ('xhdpi', 96),
        ('xxhdpi', 144),
        ('xxxhdpi', 192),
    ]:
        save(master, ROOT / f'android/app/src/main/res/mipmap-{folder}/ic_launcher.png', px)


if __name__ == '__main__':
    main()
