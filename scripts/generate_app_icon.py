from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
APPICON_DIR = ROOT / "CodecLab" / "Assets.xcassets" / "AppIcon.appiconset"
DOCS_DIR = ROOT / "docs"


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def vertical_gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    image = Image.new("RGBA", (size, size))
    px = image.load()
    for y in range(size):
        t = y / max(1, size - 1)
        r = int(top[0] * (1 - t) + bottom[0] * t)
        g = int(top[1] * (1 - t) + bottom[1] * t)
        b = int(top[2] * (1 - t) + bottom[2] * t)
        for x in range(size):
            px[x, y] = (r, g, b, 255)
    return image


def add_glow(base: Image.Image, shape: Image.Image, blur: int, opacity: int, position: tuple[int, int] = (0, 0)) -> None:
    glow = shape.filter(ImageFilter.GaussianBlur(blur))
    alpha = glow.getchannel("A").point(lambda value: int(value * opacity / 255))
    glow.putalpha(alpha)
    base.alpha_composite(glow, position)


def draw_icon(size: int = 1024) -> Image.Image:
    scale = size / 1024
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    def s(value: float) -> int:
        return int(round(value * scale))

    # Shadow and app tile.
    tile_box = (s(80), s(78), s(944), s(946))
    tile_w = tile_box[2] - tile_box[0]
    tile_mask = rounded_mask(tile_w, s(210))
    shadow = Image.new("RGBA", (tile_w, tile_w), (0, 0, 0, 190))
    shadow.putalpha(tile_mask.filter(ImageFilter.GaussianBlur(s(34))))
    icon.alpha_composite(shadow, (s(80), s(112)))

    tile = vertical_gradient(tile_w, (43, 33, 78), (10, 13, 23))
    tile.putalpha(tile_mask)
    icon.alpha_composite(tile, (tile_box[0], tile_box[1]))

    draw = ImageDraw.Draw(icon, "RGBA")
    draw.rounded_rectangle(tile_box, radius=s(210), outline=(168, 126, 255, 128), width=s(4))
    draw.arc((s(120), s(98), s(904), s(720)), 200, 340, fill=(255, 255, 255, 42), width=s(4))

    # Inner analyzer slab.
    slab_box = (s(210), s(236), s(814), s(782))
    slab = Image.new("RGBA", (slab_box[2] - slab_box[0], slab_box[3] - slab_box[1]), (0, 0, 0, 0))
    slab_draw = ImageDraw.Draw(slab, "RGBA")
    slab_draw.rounded_rectangle(
        (0, 0, slab.size[0] - 1, slab.size[1] - 1),
        radius=s(118),
        fill=(18, 18, 34, 235),
        outline=(168, 126, 255, 120),
        width=s(3),
    )
    slab_draw.rounded_rectangle(
        (s(20), s(18), slab.size[0] - s(20), slab.size[1] - s(26)),
        radius=s(98),
        outline=(255, 255, 255, 28),
        width=s(2),
    )
    add_glow(icon, slab, blur=s(22), opacity=135, position=(slab_box[0], slab_box[1]))
    icon.alpha_composite(slab, (slab_box[0], slab_box[1]))

    # AB channel capsules.
    for label, x, color in [
        ("A", 282, (58, 213, 247, 255)),
        ("B", 656, (150, 95, 255, 255)),
    ]:
        box = (s(x), s(296), s(x + 92), s(362))
        draw.rounded_rectangle(box, radius=s(32), fill=(20, 22, 42, 245), outline=color, width=s(3))
        try:
            font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", s(38))
        except OSError:
            font = ImageFont.load_default()
        text_bbox = draw.textbbox((0, 0), label, font=font)
        draw.text(
            (box[0] + (box[2] - box[0] - (text_bbox[2] - text_bbox[0])) / 2, box[1] + s(12)),
            label,
            font=font,
            fill=color,
        )

    # Central waveform bars.
    center_x = s(512)
    base_y = s(538)
    bar_width = s(24)
    gap = s(15)
    heights = [92, 142, 188, 248, 316, 246, 184, 146, 104]
    start_x = center_x - ((bar_width + gap) * len(heights) - gap) // 2
    for i, height in enumerate(heights):
        x0 = start_x + i * (bar_width + gap)
        y0 = base_y - s(height) // 2
        y1 = base_y + s(height) // 2
        t = i / (len(heights) - 1)
        r = int(43 * (1 - t) + 159 * t)
        g = int(221 * (1 - t) + 93 * t)
        b = int(248 * (1 - t) + 255 * t)
        draw.rounded_rectangle((x0, y0, x0 + bar_width, y1), radius=s(12), fill=(r, g, b, 242))
        draw.rounded_rectangle((x0 + s(4), y0 + s(5), x0 + bar_width - s(5), y0 + s(34)), radius=s(8), fill=(255, 255, 255, 55))

    # Difference residual curve.
    points = []
    for i in range(190):
        x = s(280) + int(i * s(2.45))
        angle = i / 16
        decay = 1 - i / 230
        y = s(650) + int(math.sin(angle) * s(38) * decay + math.sin(angle * 2.1) * s(13))
        points.append((x, y))
    draw.line(points, fill=(45, 238, 172, 220), width=s(7), joint="curve")
    draw.line([(x, y - s(5)) for x, y in points], fill=(255, 255, 255, 38), width=s(2), joint="curve")

    # Bottom lab rail.
    rail = (s(290), s(720), s(734), s(746))
    draw.rounded_rectangle(rail, radius=s(13), fill=(238, 244, 255, 160))
    for x in [350, 424, 498, 572, 646]:
        draw.ellipse((s(x), s(713), s(x + 40), s(753)), fill=(17, 21, 36, 255), outline=(71, 224, 245, 120), width=s(2))

    return icon


def save_iconset() -> None:
    APPICON_DIR.mkdir(parents=True, exist_ok=True)
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    source = draw_icon(1024)
    source.save(DOCS_DIR / "CodecLab-AppIcon-1024.png")

    outputs = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for filename, output_size in outputs.items():
        source.resize((output_size, output_size), Image.Resampling.LANCZOS).save(APPICON_DIR / filename)


if __name__ == "__main__":
    save_iconset()
