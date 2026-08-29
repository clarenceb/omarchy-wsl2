#!/usr/bin/env python3
"""Render assets/logo.svg into the PNG and Windows .ico files the build needs.

The Start-menu shortcut declared in wsl/wsl-distribution.conf points at
/usr/lib/wsl/omarchy-wsl2.ico, so a real multi-resolution .ico is required.

Usage: python3 scripts/make-logo.py [output-dir]
"""

from __future__ import annotations

import io
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]
PNG_SIZES = [256, 512]


def render(svg: Path, size: int) -> "Image.Image":
    from PIL import Image

    import cairosvg

    png = cairosvg.svg2png(
        url=str(svg), output_width=size, output_height=size, background_color=None
    )
    return Image.open(io.BytesIO(png)).convert("RGBA")


def main() -> int:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ASSETS
    out.mkdir(parents=True, exist_ok=True)

    mark = ASSETS / "logo.svg"
    if not mark.exists():
        print(f"error: {mark} not found", file=sys.stderr)
        return 1

    try:
        import cairosvg  # noqa: F401
        from PIL import Image  # noqa: F401
    except ImportError:
        print(
            "error: needs cairosvg and Pillow.\n"
            "  pip install --user cairosvg Pillow\n"
            "  (Debian/Ubuntu: sudo apt install python3-cairosvg python3-pil)",
            file=sys.stderr,
        )
        return 1

    for size in PNG_SIZES:
        target = out / f"logo-{size}.png"
        render(mark, size).save(target)
        print(f"wrote {target.relative_to(ROOT)}")

    base = render(mark, 256)
    ico = out / "omarchy-wsl2.ico"
    base.save(ico, format="ICO", sizes=[(s, s) for s in ICO_SIZES])
    print(f"wrote {ico.relative_to(ROOT)} ({len(ICO_SIZES)} sizes)")

    learn = ASSETS / "omarchy-learn.svg"
    if learn.exists():
        for size in (256,):
            target = out / f"omarchy-learn-{size}.png"
            render(learn, size).save(target)
            print(f"wrote {target.relative_to(ROOT)}")

    wordmark = ASSETS / "logo-wordmark.svg"
    if wordmark.exists():
        import cairosvg
        from PIL import Image

        png = cairosvg.svg2png(url=str(wordmark), output_width=1120)
        target = out / "logo-wordmark.png"
        Image.open(io.BytesIO(png)).convert("RGBA").save(target)
        print(f"wrote {target.relative_to(ROOT)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
