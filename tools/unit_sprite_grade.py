"""Small, alpha-safe color grade shared by rendered unit sprite atlases."""

from PIL import Image, ImageChops, ImageEnhance


def grade_vibrant(
    frame: Image.Image,
    *,
    saturation: float = 1.35,
    contrast: float = 1.08,
    brightness: float = 1.02,
    accent_hues: tuple[int, int] | None = None,
    accent_saturation: float = 1.0,
) -> Image.Image:
    """Lift color while preserving the alpha mask and natural skin tones."""
    rgba = frame.convert("RGBA")
    rgb = rgba.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(saturation)
    if accent_hues is not None and accent_saturation != 1.0:
        hue, source_saturation, _ = rgba.convert("HSV").split()
        low_hue, high_hue = accent_hues
        hue_mask = Image.eval(hue, lambda value: 255 if low_hue <= value <= high_hue else 0)
        color_mask = Image.eval(source_saturation, lambda value: 255 if value >= 14 else 0)
        accent_mask = ImageChops.multiply(hue_mask, color_mask)
        accent = ImageEnhance.Color(rgb).enhance(accent_saturation)
        rgb = Image.composite(accent, rgb, accent_mask)
    rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
    rgb = ImageEnhance.Brightness(rgb).enhance(brightness)
    graded = rgb.convert("RGBA")
    graded.putalpha(rgba.getchannel("A"))
    return graded
