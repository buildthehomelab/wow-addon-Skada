#!/usr/bin/env python3
"""Builds the WoW Forever meter button art in Skada/Media/Textures/forever.

Pure Python (no PIL): every shape is a coverage test, supersampled 4x4 per
pixel, written as an uncompressed 32-bit TGA (bottom-left origin), which the
3.3.5a client loads as-is. Run from the repository root:

    python3 tools/make_forever_glyphs.py
"""

import math
import os
import struct

SIZE = 64
SS = 4
OUT = os.path.join("Skada", "Media", "Textures", "forever")


def rounded_rect(x, y, x0, y0, x1, y1, r):
    if x < x0 or x > x1 or y < y0 or y > y1:
        return False
    cx = min(max(x, x0 + r), x1 - r)
    cy = min(max(y, y0 + r), y1 - r)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(len(a)))


def render(shade):
    """shade(x, y) -> (r, g, b, a) floats 0..1 or None; returns RGBA rows top-down."""
    rows = []
    for py in range(SIZE):
        row = []
        for px in range(SIZE):
            acc = [0.0, 0.0, 0.0, 0.0]
            for sy in range(SS):
                for sx in range(SS):
                    c = shade(px + (sx + 0.5) / SS, py + (sy + 0.5) / SS)
                    if c:
                        acc[0] += c[0] * c[3]
                        acc[1] += c[1] * c[3]
                        acc[2] += c[2] * c[3]
                        acc[3] += c[3]
            n = SS * SS
            a = acc[3] / n
            if a > 0:
                rgb = [acc[i] / acc[3] for i in range(3)]
            else:
                rgb = [0.0, 0.0, 0.0]
            row.append(tuple(int(round(v * 255)) for v in rgb + [a]))
        rows.append(row)
    return rows


def write_tga(name, rows):
    path = os.path.join(OUT, name + ".tga")
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x08)
    with open(path, "wb") as f:
        f.write(header)
        for row in reversed(rows):  # bottom-left origin
            for r, g, b, a in row:
                f.write(bytes((b, g, r, a)))
    print("wrote", path)


def button(border_top, border_bottom, fill_top, fill_bottom, gloss):
    def shade(x, y):
        if not rounded_rect(x, y, 2, 2, 62, 62, 10):
            return None
        t = (y - 2) / 60
        if rounded_rect(x, y, 5, 5, 59, 59, 7):
            c = lerp(fill_top, fill_bottom, t)
            if gloss and y < 22:  # soft top sheen
                c = lerp(c, (1, 1, 1), 0.10 * (22 - y) / 17)
            return c + (1.0,)
        return lerp(border_top, border_bottom, t) + (1.0,)
    return shade


WHITE = (1.0, 1.0, 1.0, 1.0)


def ring(x, y):
    d = math.hypot(x - 32, y - 32)
    return WHITE if 10 <= d <= 15 else None


def gear(x, y):
    dx, dy = x - 32, y - 32
    d = math.hypot(dx, dy)
    if d < 6 or d > 19:
        return None
    if d <= 13.5:
        return WHITE
    step = 2 * math.pi / 8
    ang = math.atan2(dy, dx) % step
    ang = min(ang, step - ang)
    return WHITE if d * math.sin(ang) <= 3.6 else None


def minus(x, y):
    return WHITE if rounded_rect(x, y, 17, 28.5, 47, 35.5, 2) else None


def arrow(x, y):
    # down-pointing triangle (19,24) (45,24) (32,40)
    if y < 24 or y > 40:
        return None
    half = 13 * (40 - y) / 16
    return WHITE if abs(x - 32) <= half else None


def main():
    os.makedirs(OUT, exist_ok=True)
    gold_top, bronze_bottom = (0.86, 0.68, 0.32), (0.42, 0.30, 0.13)
    write_tga("button", render(button(gold_top, bronze_bottom, (0.17, 0.15, 0.12), (0.05, 0.045, 0.04), False)))
    write_tga("button-red", render(button((0.55, 0.10, 0.06), (0.25, 0.03, 0.02), (0.80, 0.14, 0.08), (0.45, 0.04, 0.02), True)))
    write_tga("ring", render(ring))
    write_tga("gear", render(gear))
    write_tga("minus", render(minus))
    write_tga("arrow", render(arrow))


if __name__ == "__main__":
    main()
