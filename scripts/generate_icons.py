#!/usr/bin/env python3
"""Generate the Things app icon (no star, violet accent) at 1024x1024.

Outputs to Things/Assets.xcassets/AppIcon.appiconset/icon-1024.png

iOS 14+ Asset Catalogs accept a single 1024x1024 image (single-size mode);
Xcode handles downscaling for all device sizes.
"""

from __future__ import annotations
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "Things", "Assets.xcassets", "AppIcon.appiconset")
os.makedirs(OUT_DIR, exist_ok=True)

SIZE = 1024
ACCENT = (162, 132, 244, 255)         # violet
DARK_TOP = (31, 31, 35, 255)
DARK_BOT = (14, 14, 16, 255)
PAPER_TOP = (42, 42, 46, 255)
PAPER_BOT = (30, 30, 34, 255)
HOLE = (14, 14, 16, 255)
LINE_DIM_1 = (255, 255, 255, 46)      # ~0.18 alpha
LINE_DIM_2 = (255, 255, 255, 31)      # ~0.12 alpha
HAIRLINE = (255, 255, 255, 20)


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


def diagonal_gradient(size, top, bot):
    """Approximate a 160deg gradient via diagonal blend."""
    img = Image.new("RGBA", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = ((x * 0.18) + (y * 0.82)) / size
            t = max(0.0, min(1.0, t))
            r = int(top[0] * (1 - t) + bot[0] * t)
            g = int(top[1] * (1 - t) + bot[1] * t)
            b = int(top[2] * (1 - t) + bot[2] * t)
            a = int(top[3] * (1 - t) + bot[3] * t)
            px[x, y] = (r, g, b, a)
    return img


def main():
    icon = diagonal_gradient(SIZE, DARK_TOP, DARK_BOT)
    draw = ImageDraw.Draw(icon, "RGBA")

    # Notepad surface — left 22%, top 18%, width 56%, height 64%
    pad_x = int(SIZE * 0.22)
    pad_y = int(SIZE * 0.18)
    pad_w = int(SIZE * 0.56)
    pad_h = int(SIZE * 0.64)
    pad_radius = int(SIZE * 0.05)

    # Build the notepad on its own layer so we can apply a soft drop shadow.
    pad_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    pad_draw = ImageDraw.Draw(pad_layer, "RGBA")

    # Vertical paper gradient via a clipped region
    paper_grad = vertical_gradient(pad_w, PAPER_TOP, PAPER_BOT)
    # Resize gradient to (pad_w, pad_h)
    paper_grad = paper_grad.resize((pad_w, pad_h))
    # Mask with rounded rect
    mask = Image.new("L", (pad_w, pad_h), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle((0, 0, pad_w, pad_h), radius=pad_radius, fill=255)
    pad_layer.paste(paper_grad, (pad_x, pad_y), mask)

    # Soft shadow under the paper
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow, "RGBA")
    sdraw.rounded_rectangle(
        (pad_x, pad_y + int(SIZE * 0.012), pad_x + pad_w, pad_y + pad_h + int(SIZE * 0.012)),
        radius=pad_radius,
        fill=(0, 0, 0, 110),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=int(SIZE * 0.012)))
    icon.alpha_composite(shadow)
    icon.alpha_composite(pad_layer)

    # Hairline border on paper
    draw.rounded_rectangle(
        (pad_x, pad_y, pad_x + pad_w, pad_y + pad_h),
        radius=pad_radius,
        outline=HAIRLINE,
        width=2,
    )

    # Binding dots — 3 holes near top
    dot_d = int(SIZE * 0.045)
    dots_y = pad_y + int(SIZE * 0.04)
    dots_inset = int(SIZE * 0.06)
    dots_left = pad_x + dots_inset
    dots_right = pad_x + pad_w - dots_inset
    for i in range(3):
        cx = dots_left + (dots_right - dots_left) * i // 2
        cy = dots_y + dot_d // 2
        draw.ellipse(
            (cx - dot_d // 2, cy - dot_d // 2, cx + dot_d // 2, cy + dot_d // 2),
            fill=HOLE,
        )

    # Lines — accent bar + neutral lines
    lines_left = pad_x + int(SIZE * 0.07)
    lines_right = pad_x + pad_w - int(SIZE * 0.07)
    lines_width = lines_right - lines_left
    line_y = pad_y + int(SIZE * 0.18)
    gap = int(SIZE * 0.05)

    # Accent bar (60% width, slightly thicker, rounded)
    accent_h = int(SIZE * 0.018)
    accent_w = int(lines_width * 0.60)
    draw.rounded_rectangle(
        (lines_left, line_y, lines_left + accent_w, line_y + accent_h),
        radius=accent_h // 2,
        fill=ACCENT,
    )

    # Two neutral lines below
    line_y2 = line_y + accent_h + gap
    neut_h = int(SIZE * 0.012)
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
