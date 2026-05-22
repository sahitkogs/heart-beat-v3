"""Generate the Heartbeat app icon at 1024x1024.

Produces:
  app/assets/icon/heartbeat-icon.png       (1024x1024 — the source)
  app/assets/icon/heartbeat-icon-bg.png    (1024x1024 — solid paper, for adaptive icon)
  app/assets/icon/heartbeat-icon-fg.png    (1024x1024 — transparent fg, for adaptive icon)

The mark: a serif "h" + a small terracotta circle + a serif "b", on the
paper-cream background that the rest of the app uses.
"""
from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# ---- palette (mirrors lib/core/theme.dart) ----
PAPER = (244, 237, 224)         # #F4EDE0
INK = (43, 35, 28)               # #2B231C
ACCENT = (184, 92, 60)           # #B85C3C

SIZE = 1024

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "icon"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def find_serif_font(size: int) -> ImageFont.FreeTypeFont:
    """Best-effort serif font lookup. Falls back to PIL default if missing."""
    candidates = [
        # Windows system serifs that ship with the OS
        r"C:\Windows\Fonts\georgia.ttf",
        r"C:\Windows\Fonts\georgiab.ttf",
        r"C:\Windows\Fonts\times.ttf",
        r"C:\Windows\Fonts\timesbd.ttf",
        # macOS / Linux fallbacks (harmless if not present)
        "/System/Library/Fonts/NewYork.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf",
    ]
    for path in candidates:
        if os.path.isfile(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size)


def draw_mark(canvas: Image.Image, fg_only: bool = False) -> None:
    """Draws the 'h • b' mark on [canvas], centered by actual rendered bbox.

    Strategy: render each piece to a temporary RGBA image, then paste those
    pieces onto the canvas after computing their union bbox so the composite
    is dead-center.
    """
    font = find_serif_font(size=int(SIZE * 0.60))

    dot_radius = int(SIZE * 0.045)
    gap = int(SIZE * 0.04)

    # Render "h" and "b" to their own bbox-tight RGBA tiles.
    def render_glyph(ch: str) -> Image.Image:
        # Get the ink-tight bbox at origin.
        tmp = Image.new("RGBA", (SIZE * 2, SIZE * 2), (0, 0, 0, 0))
        d = ImageDraw.Draw(tmp)
        d.text((SIZE, SIZE), ch, fill=INK, font=font)
        bbox = tmp.getbbox()  # (l, t, r, b) of non-transparent pixels
        if bbox is None:
            return tmp
        return tmp.crop(bbox)

    h_img = render_glyph("h")
    b_img = render_glyph("b")

    # Build a dot tile.
    dot_d = dot_radius * 2
    dot_img = Image.new("RGBA", (dot_d, dot_d), (0, 0, 0, 0))
    ImageDraw.Draw(dot_img).ellipse((0, 0, dot_d - 1, dot_d - 1), fill=ACCENT)

    # Lay them out left-to-right on a common baseline. We use the *bottom* of
    # the cropped tiles as the baseline (h and b have no descender so this is
    # correct).
    h_w, h_h = h_img.size
    b_w, b_h = b_img.size

    total_w = h_w + gap + dot_d + gap + b_w
    # Composite height = ascender block (tallest of h and b).
    composite_h = max(h_h, b_h)

    # Center the composite on the canvas.
    composite_x = (SIZE - total_w) // 2
    composite_top = (SIZE - composite_h) // 2

    # Paste h aligned to the bottom of the composite (baseline shared).
    canvas.alpha_composite(
        h_img,
        (composite_x, composite_top + composite_h - h_h),
    )

    # Dot: vertically centered on the x-height midline of "h" — that's the
    # vertical center of the cropped h tile (since h has no ascender bar above
    # x-height beyond the stem, which the bbox of the rendered glyph already
    # captures).
    dot_center_y = composite_top + composite_h - int(h_h * 0.45)
    dot_x = composite_x + h_w + gap
    dot_y = dot_center_y - dot_radius
    canvas.alpha_composite(dot_img, (dot_x, dot_y))

    # b aligned the same way.
    b_x = dot_x + dot_d + gap
    canvas.alpha_composite(
        b_img,
        (b_x, composite_top + composite_h - b_h),
    )


def main() -> None:
    # 1) Full icon — solid paper background + mark
    full = Image.new("RGBA", (SIZE, SIZE), PAPER + (255,))
    draw_mark(full)
    full.save(OUT_DIR / "heartbeat-icon.png", optimize=True)

    # 2) Adaptive-icon background — pure paper
    bg = Image.new("RGBA", (SIZE, SIZE), PAPER + (255,))
    bg.save(OUT_DIR / "heartbeat-icon-bg.png", optimize=True)

    # 3) Adaptive-icon foreground — transparent canvas, just the mark, with
    #    a 25% safe-zone padding (Android crops the outer ring).
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_mark(fg)
    fg.save(OUT_DIR / "heartbeat-icon-fg.png", optimize=True)

    print(f"Wrote icons to {OUT_DIR}")


if __name__ == "__main__":
    main()
