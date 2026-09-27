#!/usr/bin/env python3
"""Generates the DMG background at 1x and 2x, matching the app icon's navy/teal palette.

Run with the system Python 3 (Pillow is the only dependency: `pip3 install pillow`).
Writes Resources/dmg/background.png (600x400) and Resources/dmg/background@2x.png
(1200x800). Icon slot positions here must match the --icon/--app-drop-link coordinates
passed to create-dmg in scripts/make-dmg.sh.
"""

import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "Resources", "dmg")

WIDTH, HEIGHT = 600, 400
APP_X, APPS_X, ICON_Y = 150, 450, 190
LABEL_Y = 320

TOP_COLOR = (18, 42, 60)
BOTTOM_COLOR = (9, 20, 30)
GLOW_COLOR = (110, 224, 208)
ARROW_COLOR = (140, 170, 185)
LABEL_COLOR = (168, 196, 206)


def vertical_gradient(w: int, h: int, top: tuple, bottom: tuple) -> Image.Image:
    gradient = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        gradient.putpixel((0, y), tuple(round(top[c] + (bottom[c] - top[c]) * t) for c in range(3)))
    return gradient.resize((w, h))


def render(scale: int) -> Image.Image:
    w, h = WIDTH * scale, HEIGHT * scale
    img = vertical_gradient(w, h, TOP_COLOR, BOTTOM_COLOR).convert("RGBA")

    # Soft teal glow behind the icon row, echoing the app icon's ball.
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    cx, cy = w // 2, ICON_Y * scale
    radius = 150 * scale
    glow_draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=(*GLOW_COLOR, 40))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=40 * scale))
    img = Image.alpha_composite(img, glow).convert("RGB")
    draw = ImageDraw.Draw(img)

    # Arrow between the two icon slots.
    arrow_y = ICON_Y * scale
    start_x = (APP_X + 46) * scale
    end_x = (APPS_X - 46) * scale
    draw.line([(start_x, arrow_y), (end_x, arrow_y)], fill=ARROW_COLOR, width=max(1, scale))
    head = 9 * scale
    draw.polygon(
        [
            (end_x, arrow_y),
            (end_x - head, arrow_y - head * 0.6),
            (end_x - head, arrow_y + head * 0.6),
        ],
        fill=ARROW_COLOR,
    )

    # Instructional label.
    font = ImageFont.truetype("/System/Library/Fonts/SFNSRounded.ttf", 16 * scale)
    text = "Drag Kiito to Applications to install"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    draw.text(((w - text_w) / 2, LABEL_Y * scale), text, fill=LABEL_COLOR, font=font)

    return img


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    render(1).save(os.path.join(OUT_DIR, "background.png"))
    render(2).save(os.path.join(OUT_DIR, "background@2x.png"))
    print(f"Wrote {OUT_DIR}/background.png and background@2x.png")


if __name__ == "__main__":
    main()
