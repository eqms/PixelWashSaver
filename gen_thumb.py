#!/usr/bin/env python3
"""Generate PixelWash screensaver thumbnails (2x2 montage of the four modes)."""
import random
from PIL import Image, ImageDraw

random.seed(7)  # deterministic noise

PALETTE = [
    (255, 255, 255), (0, 0, 0), (255, 0, 0), (0, 255, 0), (0, 0, 255),
    (255, 255, 0), (0, 255, 255), (255, 0, 255), (128, 128, 128),
]


def draw_noise(d, x0, y0, w, h, block=8):
    for y in range(y0, y0 + h, block):
        for x in range(x0, x0 + w, block):
            c = (random.randint(0, 255), random.randint(0, 255), random.randint(0, 255))
            d.rectangle([x, y, x + block, y + block], fill=c)


def draw_cycle(d, x0, y0, w, h):
    # vertical color bands to suggest the full-color cycle
    bands = 5
    bw = w / bands
    for i in range(bands):
        c = PALETTE[(i * 2 + 2) % len(PALETTE)]
        d.rectangle([x0 + i * bw, y0, x0 + (i + 1) * bw, y0 + h], fill=c)


def draw_bars(d, x0, y0, w, h, bar=22):
    d.rectangle([x0, y0, x0 + w, y0 + h], fill=(0, 0, 0))
    x = -h
    while x < w + h:
        d.polygon([(x0 + x, y0 + h), (x0 + x + bar, y0 + h),
                   (x0 + x + bar + h, y0), (x0 + x + h, y0)], fill=(255, 255, 255))
        x += bar * 2


def draw_checker(d, x0, y0, w, h, c=16):
    ry = 0
    y = y0
    while y < y0 + h:
        rx = 0
        x = x0
        while x < x0 + w:
            if (rx + ry) & 1:
                d.rectangle([x, y, x + c, y + c], fill=(255, 255, 255))
            x += c
            rx += 1
        y += c
        ry += 1


def make(path, W, H):
    img = Image.new("RGB", (W, H), (0, 0, 0))
    d = ImageDraw.Draw(img)
    hw, hh = W // 2, H // 2
    draw_noise(d, 0, 0, hw, hh, block=max(4, W // 100))
    draw_cycle(d, hw, 0, W - hw, hh)
    draw_bars(d, 0, hh, hw, H - hh, bar=max(10, W // 40))
    draw_checker(d, hw, hh, W - hw, H - hh, c=max(8, W // 50))
    img.save(path)
    print("wrote", path, img.size)


# 16:10 to match a display tile
make("Resources/thumbnail.png", 400, 250)
make("Resources/thumbnail@2x.png", 800, 500)
