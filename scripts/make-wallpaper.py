#!/usr/bin/env python3
"""Generate Omarchy-style gradient wallpapers for the sway desktop.

Omarchy's look is dark, saturated and abstract - deep gradients with soft
colour blooms rather than photography. sway has no animations or blur to lean
on, so the wallpaper is doing most of the visual work here.

Output is written to assets/wallpapers/<name>.png and installed to
/usr/share/omarchy-wsl2/wallpapers by scripts/provision/40-desktop.sh.

Usage: python3 scripts/make-wallpaper.py [output-dir] [--size WxH]
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = ROOT / "assets" / "wallpapers"
DEFAULT_SIZE = (2560, 1440)

# Palettes chosen to sit alongside Omarchy's own themes. Each is
# (base, blooms[(colour, cx, cy, radius_factor), ...]) with cx/cy in 0..1.
PALETTES: dict[str, dict] = {
    "omarchy-wsl2": {
        "base": (9, 12, 24),
        "blooms": [
            ((91, 75, 214), 0.18, 0.22, 0.75),
            ((42, 166, 196), 0.82, 0.30, 0.65),
            ((61, 220, 200), 0.70, 0.85, 0.55),
            ((232, 132, 43), 0.12, 0.88, 0.45),
        ],
    },
    "tokyo-night": {
        "base": (17, 18, 28),
        "blooms": [
            ((122, 162, 247), 0.20, 0.25, 0.80),
            ((187, 154, 247), 0.78, 0.35, 0.65),
            ((125, 207, 255), 0.60, 0.85, 0.55),
        ],
    },
    "ember": {
        "base": (14, 9, 12),
        "blooms": [
            ((216, 59, 1), 0.22, 0.78, 0.75),
            ((245, 166, 91), 0.75, 0.28, 0.60),
            ((124, 108, 245), 0.85, 0.85, 0.45),
        ],
    },
    "matte-black": {
        "base": (10, 10, 11),
        "blooms": [
            ((60, 60, 66), 0.25, 0.30, 0.85),
            ((90, 88, 100), 0.80, 0.70, 0.70),
        ],
    },
}


def _blend(base: tuple, over: tuple, alpha: float) -> tuple:
    return tuple(int(b + (o - b) * alpha) for b, o in zip(base, over))


def render(name: str, spec: dict, size: tuple[int, int]):
    """Draw the gradient at low resolution, then upscale.

    Radial falloff is expensive per-pixel in Python, so compute it on a small
    canvas and let PIL's bicubic resize do the smoothing. The result is
    indistinguishable for soft gradients and roughly 400x faster.
    """
    from PIL import Image, ImageDraw, ImageFilter

    w, h = size
    sw, sh = 160, int(160 * h / w)
    img = Image.new("RGB", (sw, sh), spec["base"])
    px = img.load()

    diag = math.hypot(sw, sh)
    for y in range(sh):
        for x in range(sw):
            colour = spec["base"]
            for bloom, cx, cy, rf in spec["blooms"]:
                d = math.hypot(x - cx * sw, y - cy * sh) / (diag * rf)
                if d < 1.0:
                    # smoothstep falloff - softer edges than a linear ramp
                    t = 1.0 - d
                    colour = _blend(colour, bloom, t * t * (3 - 2 * t) * 0.42)
            px[x, y] = colour

    img = img.resize(size, Image.LANCZOS).filter(ImageFilter.GaussianBlur(2))

    # A faint vignette stops the corners competing with tiled windows.
    vign = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(vign).ellipse(
        (-sw * 0.25, -sh * 0.25, sw * 1.25, sh * 1.25), fill=255
    )
    vign = vign.resize(size, Image.LANCZOS).filter(ImageFilter.GaussianBlur(size[0] // 30))
    img = Image.composite(img, Image.new("RGB", size, (0, 0, 0)), vign)

    return img


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    out = Path(args[0]) if args else DEFAULT_OUT

    size = DEFAULT_SIZE
    for a in sys.argv[1:]:
        if a.startswith("--size"):
            _, _, val = a.partition("=")
            if not val:
                continue
            try:
                w, _, h = val.partition("x")
                size = (int(w), int(h))
            except ValueError:
                print(f"ignoring bad --size {val!r}", file=sys.stderr)

    try:
        from PIL import Image  # noqa: F401
    except ImportError:
        print("Pillow is required: pip install Pillow", file=sys.stderr)
        return 1

    out.mkdir(parents=True, exist_ok=True)
    for name, spec in PALETTES.items():
        img = render(name, spec, size)
        dest = out / f"{name}.png"
        img.save(dest, "PNG", optimize=True)
        print(f"  {dest.relative_to(ROOT) if dest.is_relative_to(ROOT) else dest} "
              f"({size[0]}x{size[1]})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
