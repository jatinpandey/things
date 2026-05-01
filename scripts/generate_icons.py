#!/usr/bin/env python3
"""Generate the Things app icon (no star, violet accent) at 1024x1024.

Outputs to Things/Assets.xcassets/AppIcon.appiconset/icon-1024.png

iOS 14+ Asset Catalogs accept a single 1024x1024 image (single-size mode);
Xcode handles downscaling for all device sizes. The image intentionally does
not draw the outer app-icon rounded rectangle; iOS applies that mask on the
home screen.
"""

from __future__ import annotations
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "Things", "Assets.xcassets", "AppIcon.appiconset")
os.makedirs(OUT_DIR, exist_ok=True)

SIZE = 1024
ACCENT = (162, 132, 244, 255)         # violet
PAPER_TOP = (42, 42, 46, 255)
PAPER_BOT = (30, 30, 34, 255)
LINE_DIM_1 = (255, 255, 255, 46)      # ~0.18 alpha
LINE_DIM_2 = (255, 255, 255, 31)      # ~0.12 alpha


def vertical_gradient(size, top, bot):
    img = Image.new("RGBA", (size, size), top)
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        r = int(top[0] * (1 - t) + bot[0] * t)
        g = int(top[1] * (1 - t) + bot[1] * t)
        b = int(top[2] * (1 - t) + bot[2] * t)
        a = int(top[3] * (1 - t) + bot[3] * t)
        for x in range(size):
            px[x, y] = (r, g, b, a)
    return img


def main():
    icon = vertical_gradient(SIZE, PAPER_TOP, PAPER_BOT)
    draw = ImageDraw.Draw(icon, "RGBA")

    # Lines — accent bar + neutral lines (centered vertically since dots are gone)
    lines_left = int(SIZE * 0.12)
    lines_right = int(SIZE * 0.88)
    lines_width = lines_right - lines_left
    line_y = int(SIZE * 0.36)
    gap = int(SIZE * 0.09)

    # Accent bar (60% width, slightly thicker, rounded)
    accent_h = int(SIZE * 0.032)
    accent_w = int(lines_width * 0.60)
    draw.rounded_rectangle(
        (lines_left, line_y, lines_left + accent_w, line_y + accent_h),
        radius=accent_h // 2,
        fill=ACCENT,
    )

    # Two neutral lines below
    line_y2 = line_y + accent_h + gap
    neut_h = int(SIZE * 0.022)
    neut_w_1 = int(lines_width * 0.85)
    draw.rounded_rectangle(
        (lines_left, line_y2, lines_left + neut_w_1, line_y2 + neut_h),
        radius=neut_h // 2,
        fill=LINE_DIM_1,
    )
    line_y3 = line_y2 + neut_h + gap
    neut_w_2 = int(lines_width * 0.70)
    draw.rounded_rectangle(
        (lines_left, line_y3, lines_left + neut_w_2, line_y3 + neut_h),
        radius=neut_h // 2,
        fill=LINE_DIM_2,
    )

    # NOTE: per user request, no star is drawn on the app icon.

    out_path = os.path.join(OUT_DIR, "icon-1024.png")
    icon.convert("RGB").save(out_path, "PNG", optimize=True)
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
