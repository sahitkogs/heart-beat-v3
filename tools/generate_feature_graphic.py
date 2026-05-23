"""Generates the 1024x500 Play Store feature graphic.

Paper background, centered "heart•beat" wordmark (Georgia serif) with the
terracotta accent dot, italic tagline below. Outputs to
heart-beat-v3/marketing/feature-graphic.png.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "marketing" / "feature-graphic.png"

# Tokens from lib/theme/app_colors.dart
PAPER = (244, 237, 224)
INK = (43, 35, 28)
ACCENT = (184, 92, 60)
INK_SOFT = (111, 95, 79)

W, H = 1024, 500


def load_font(candidates: list[str], size: int) -> ImageFont.FreeTypeFont:
    for path in candidates:
        try:
            return ImageFont.truetype(path, size=size)
        except (OSError, IOError):
            continue
    return ImageFont.load_default()


def main() -> None:
    img = Image.new("RGB", (W, H), PAPER)
    draw = ImageDraw.Draw(img)

    wordmark_font = load_font(
        ["C:/Windows/Fonts/georgiab.ttf", "C:/Windows/Fonts/georgia.ttf"],
        size=140,
    )
    tagline_font = load_font(
        ["C:/Windows/Fonts/georgiai.ttf", "C:/Windows/Fonts/georgia.ttf"],
        size=42,
    )

    heart = "heart"
    beat = "beat"

    heart_w = draw.textlength(heart, font=wordmark_font)
    beat_w = draw.textlength(beat, font=wordmark_font)
    gap = 36
    dot_diameter = 28
    total_w = heart_w + gap + dot_diameter + gap + beat_w

    baseline_y = 200
    x = (W - total_w) / 2

    draw.text((x, baseline_y), heart, font=wordmark_font, fill=INK)
    x += heart_w + gap

    cy = baseline_y + wordmark_font.size * 0.55
    draw.ellipse(
        [(x, cy - dot_diameter / 2), (x + dot_diameter, cy + dot_diameter / 2)],
        fill=ACCENT,
    )
    x += dot_diameter + gap

    draw.text((x, baseline_y), beat, font=wordmark_font, fill=INK)

    tagline = "private messages, for two"
    tagline_w = draw.textlength(tagline, font=tagline_font)
    draw.text(
        ((W - tagline_w) / 2, baseline_y + wordmark_font.size + 24),
        tagline,
        font=tagline_font,
        fill=INK_SOFT,
    )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, "PNG", optimize=True)
    print(f"Wrote {OUT}  ({W}x{H})")


if __name__ == "__main__":
    main()
