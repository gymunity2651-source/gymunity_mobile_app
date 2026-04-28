from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_FULL = ROOT / "assets" / "images" / "logo_app_icon.png"
OUTPUT_FOREGROUND = ROOT / "assets" / "images" / "logo_app_icon_foreground.png"

SIZE = 1024
CIRCLE_BOUNDS = (8, 8, 1016, 1016)

SURFACE = (250, 249, 246, 255)
SURFACE_LOW = (244, 243, 241, 255)
SURFACE_LOWEST = (255, 255, 255, 255)
PRIMARY_DARK = (92, 25, 0, 255)
PRIMARY = (130, 39, 0, 255)
SECONDARY = (254, 126, 79, 255)
SECONDARY_SOFT = (255, 190, 160, 255)
GHOST_SHADOW = (26, 28, 26, 20)


def _load_font(size: int) -> ImageFont.FreeTypeFont:
    candidates = [
        Path("C:/Windows/Fonts/ARLRDBD.TTF"),
        Path("C:/Windows/Fonts/arialbd.ttf"),
        Path("C:/Windows/Fonts/segoeuib.ttf"),
        Path("C:/Windows/Fonts/verdanab.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()

def _vertical_gradient(size: tuple[int, int], top: tuple[int, int, int, int], bottom: tuple[int, int, int, int]) -> Image.Image:
    width, height = size
    image = Image.new("RGBA", size)
    pixels = image.load()
    for y in range(height):
        t = y / max(height - 1, 1)
        color = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(4))
        for x in range(width):
            pixels[x, y] = color
    return image


def _make_tile() -> Image.Image:
    base = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))

    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow_mask = Image.new("L", (SIZE, SIZE), 0)
    shadow_draw = ImageDraw.Draw(shadow_mask)
    shadow_draw.ellipse((CIRCLE_BOUNDS[0], CIRCLE_BOUNDS[1] + 22, CIRCLE_BOUNDS[2], CIRCLE_BOUNDS[3] + 22), fill=255)
    shadow.paste(GHOST_SHADOW, (0, 0), shadow_mask)
    shadow = shadow.filter(ImageFilter.GaussianBlur(44))
    base.alpha_composite(shadow)

    tile = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    tile_mask = Image.new("L", (SIZE, SIZE), 0)
    tile_draw = ImageDraw.Draw(tile_mask)
    tile_draw.ellipse(CIRCLE_BOUNDS, fill=255)

    tile_gradient = _vertical_gradient((SIZE, SIZE), SURFACE_LOWEST, SURFACE_LOW)
    tile.paste(tile_gradient, (0, 0), tile_mask)

    spotlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    spotlight_draw = ImageDraw.Draw(spotlight)
    spotlight_draw.ellipse((180, 190, 860, 838), fill=(254, 126, 79, 24))
    spotlight = spotlight.filter(ImageFilter.GaussianBlur(95))
    tile.alpha_composite(spotlight)

    highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(highlight)
    highlight_draw.ellipse((CIRCLE_BOUNDS[0] + 10, CIRCLE_BOUNDS[1] + 8, CIRCLE_BOUNDS[2] - 10, CIRCLE_BOUNDS[3] - 12), outline=(255, 255, 255, 58), width=2)
    highlight = highlight.filter(ImageFilter.GaussianBlur(8))
    tile.alpha_composite(highlight)

    base.alpha_composite(tile)
    return base


def _make_monogram_mask(font: ImageFont.FreeTypeFont) -> Image.Image:
    mask = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(mask)

    g_bbox = draw.textbbox((0, 0), "G", font=font, stroke_width=0)
    u_bbox = draw.textbbox((0, 0), "U", font=font, stroke_width=0)
    g_w = g_bbox[2] - g_bbox[0]
    u_w = u_bbox[2] - u_bbox[0]
    y = 260
    total = g_w + u_w - 132
    start_x = (SIZE - total) // 2
    draw.text((start_x, y), "G", font=font, fill=255)
    draw.text((start_x + g_w - 132, y + 6), "U", font=font, fill=255)
    return mask.filter(ImageFilter.GaussianBlur(0.15))


def _make_monogram() -> Image.Image:
    font = _load_font(390)
    mask = _make_monogram_mask(font)

    depth = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    depth_fill = Image.new("RGBA", (SIZE, SIZE), PRIMARY_DARK)
    shifted_mask = ImageChops.offset(mask, -16, 28)
    depth.paste(depth_fill, (0, 0), shifted_mask)
    depth = depth.filter(ImageFilter.GaussianBlur(1.0))

    main = _vertical_gradient((SIZE, SIZE), SECONDARY, PRIMARY)
    main.putalpha(mask)

    shine = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shine_draw = ImageDraw.Draw(shine)
    shine_draw.ellipse((250, 220, 774, 560), fill=(255, 255, 255, 44))
    shine = shine.filter(ImageFilter.GaussianBlur(42))
    shine_alpha = ImageChops.multiply(shine.getchannel("A"), mask)
    shine.putalpha(shine_alpha)

    rim = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rim_mask = ImageChops.subtract(mask, mask.filter(ImageFilter.GaussianBlur(6)))
    rim.paste((255, 245, 232, 90), (0, 0), rim_mask)

    composed = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    composed.alpha_composite(depth)
    composed.alpha_composite(main)
    composed.alpha_composite(shine)
    composed.alpha_composite(rim)
    return composed


def build_full_icon() -> Image.Image:
    icon = _make_tile()
    icon.alpha_composite(_make_monogram())
    return icon


def build_foreground_icon() -> Image.Image:
    return build_full_icon()


def main() -> None:
    OUTPUT_FULL.parent.mkdir(parents=True, exist_ok=True)
    build_full_icon().save(OUTPUT_FULL, format="PNG")
    build_foreground_icon().save(OUTPUT_FOREGROUND, format="PNG")
    print(f"generated {OUTPUT_FULL}")
    print(f"generated {OUTPUT_FOREGROUND}")


if __name__ == "__main__":
    main()
