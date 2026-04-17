#!/usr/bin/env python3

import argparse
import colorsys
import re
import subprocess
from pathlib import Path


PALETTE_NAME = "ghostty_dynamic"
HEX_RE = re.compile(r"^#([0-9a-fA-F]{6})$")
PALETTE_LINE_RE = re.compile(r"^(\d+)\s*=\s*(#[0-9a-fA-F]{6})$")
KEY_VALUE_RE = re.compile(r"^([a-z0-9-]+)\s*=\s*(.+)$")

DARK_BACKGROUND_LUMINANCE_THRESHOLD = 0.26
DARK_THEME_MIN_SATURATION = 0.4
DARK_ACCENT_MIN_CONTRAST = 3.5
DARK_ACCENT_MAX_LUMINANCE = 0.45

LIGHT_THEME_MIN_SATURATION = 0.45
LIGHT_ACCENT_MIN_CONTRAST = 4.0
LIGHT_ACCENT_MAX_LUMINANCE = 0.35


def normalize_hex(value: str) -> str | None:
    match = HEX_RE.match(value.strip())
    if not match:
        return None
    return f"#{match.group(1).lower()}"


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    raw = value.lstrip("#")
    return int(raw[0:2], 16), int(raw[2:4], 16), int(raw[4:6], 16)


def rgb_to_hex(rgb: tuple[int, int, int]) -> str:
    return f"#{rgb[0]:02x}{rgb[1]:02x}{rgb[2]:02x}"


def blend(a: str, b: str, amount: float) -> str:
    ar, ag, ab = hex_to_rgb(a)
    br, bg, bb = hex_to_rgb(b)
    r = round(ar + (br - ar) * amount)
    g = round(ag + (bg - ag) * amount)
    b_out = round(ab + (bb - ab) * amount)
    return rgb_to_hex((r, g, b_out))


def channel_to_linear(channel: int) -> float:
    value = channel / 255
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def linear_to_channel(value: float) -> int:
    value = max(0.0, min(1.0, value))
    if value <= 0.0031308:
        srgb = value * 12.92
    else:
        srgb = 1.055 * (value ** (1 / 2.4)) - 0.055
    return round(srgb * 255)


def relative_luminance(color: str) -> float:
    r, g, b = hex_to_rgb(color)
    rl = channel_to_linear(r)
    gl = channel_to_linear(g)
    bl = channel_to_linear(b)
    return 0.2126 * rl + 0.7152 * gl + 0.0722 * bl


def contrast_ratio(a: str, b: str) -> float:
    la = relative_luminance(a)
    lb = relative_luminance(b)
    lighter = max(la, lb)
    darker = min(la, lb)
    return (lighter + 0.05) / (darker + 0.05)


def best_contrast_text(background: str, candidates: list[str]) -> str:
    unique_candidates: list[str] = []
    for color in candidates:
        normalized = normalize_hex(color)
        if normalized is not None and normalized not in unique_candidates:
            unique_candidates.append(normalized)

    if not unique_candidates:
        return "#ffffff"

    return max(unique_candidates, key=lambda color: contrast_ratio(background, color))


def ensure_min_saturation_hsv(color: str, min_saturation: float) -> str:
    if min_saturation <= 0.0:
        return color

    r8, g8, b8 = hex_to_rgb(color)
    h, s, v = colorsys.rgb_to_hsv(r8 / 255, g8 / 255, b8 / 255)
    boosted = colorsys.hsv_to_rgb(h, max(s, min(1.0, min_saturation)), v)
    return rgb_to_hex(
        (
            round(boosted[0] * 255),
            round(boosted[1] * 255),
            round(boosted[2] * 255),
        )
    )


def scale_luminance(color: str, target_lum: float) -> str:
    """Scale a color to reach target luminance while preserving chromaticity."""
    r, g, b = hex_to_rgb(color)
    rl = channel_to_linear(r)
    gl = channel_to_linear(g)
    bl = channel_to_linear(b)
    current_lum = 0.2126 * rl + 0.7152 * gl + 0.0722 * bl

    if current_lum < 0.001:
        return color

    factor = target_lum / current_lum
    new_r = rl * factor
    new_g = gl * factor
    new_b = bl * factor

    # If any channel overflows, reduce factor to stay in gamut
    max_val = max(new_r, new_g, new_b)
    if max_val > 1.0:
        factor /= max_val
        new_r = rl * factor
        new_g = gl * factor
        new_b = bl * factor

    return rgb_to_hex(
        (
            linear_to_channel(new_r),
            linear_to_channel(new_g),
            linear_to_channel(new_b),
        )
    )


def load_ghostty_config(ghostty_cmd: str) -> dict:
    try:
        result = subprocess.run(
            [ghostty_cmd, "+show-config"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return {}

    palette: dict[int, str] = {}
    parsed: dict[str, str | dict[int, str]] = {"palette": palette}

    for raw_line in result.stdout.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        kv = KEY_VALUE_RE.match(line)
        if not kv:
            continue

        key, value = kv.group(1), kv.group(2).strip()
        if key == "palette":
            palette_match = PALETTE_LINE_RE.match(value)
            if palette_match:
                idx = int(palette_match.group(1))
                color = normalize_hex(palette_match.group(2))
                if color is not None:
                    palette[idx] = color
            continue

        if key in {"foreground", "background", "selection-background"}:
            color = normalize_hex(value)
            if color is not None:
                parsed[key.replace("-", "_")] = color

    return parsed


def build_starship_palette(parsed: dict) -> dict[str, str]:
    colors = parsed.get("palette", {})

    foreground = parsed.get("foreground") or colors.get(7) or "#fbf1c7"
    background = parsed.get("background") or colors.get(0) or "#3c3836"
    selection_background = (
        parsed.get("selection_background")
        or colors.get(8)
        or blend(background, foreground, 0.25)
    )

    red = colors.get(1) or "#cc241d"
    green = colors.get(2) or "#98971a"
    yellow = colors.get(3) or "#d79921"
    blue = colors.get(4) or "#458588"
    purple = colors.get(5) or "#b16286"
    aqua = colors.get(6) or "#689d6a"
    orange = blend(red, yellow, 0.5)

    bg_lum = relative_luminance(background)
    is_dark = bg_lum < DARK_BACKGROUND_LUMINANCE_THRESHOLD

    if is_dark:
        red = ensure_min_saturation_hsv(red, DARK_THEME_MIN_SATURATION)
        green = ensure_min_saturation_hsv(green, DARK_THEME_MIN_SATURATION)
        yellow = ensure_min_saturation_hsv(yellow, DARK_THEME_MIN_SATURATION)
        blue = ensure_min_saturation_hsv(blue, DARK_THEME_MIN_SATURATION)
        purple = ensure_min_saturation_hsv(purple, DARK_THEME_MIN_SATURATION)
        aqua = ensure_min_saturation_hsv(aqua, DARK_THEME_MIN_SATURATION)
        orange = ensure_min_saturation_hsv(orange, DARK_THEME_MIN_SATURATION)

        def _ensure_dark_contrast(c: str) -> str:
            # Floor: ensure minimum contrast
            if contrast_ratio(c, background) < DARK_ACCENT_MIN_CONTRAST:
                target_lum = DARK_ACCENT_MIN_CONTRAST * (bg_lum + 0.05) - 0.05
                target_lum = max(target_lum, 0.15)
                c = scale_luminance(c, target_lum)
            # Ceiling: cap luminance so accents aren't washed out / pastel
            if relative_luminance(c) > DARK_ACCENT_MAX_LUMINANCE:
                c = scale_luminance(c, DARK_ACCENT_MAX_LUMINANCE)
            return c

        red = _ensure_dark_contrast(red)
        green = _ensure_dark_contrast(green)
        yellow = _ensure_dark_contrast(yellow)
        blue = _ensure_dark_contrast(blue)
        purple = _ensure_dark_contrast(purple)
        aqua = _ensure_dark_contrast(aqua)
        orange = _ensure_dark_contrast(orange)
    else:
        # Light theme: boost saturation and darken colors for contrast on bright bg
        red = ensure_min_saturation_hsv(red, LIGHT_THEME_MIN_SATURATION)
        green = ensure_min_saturation_hsv(green, LIGHT_THEME_MIN_SATURATION)
        yellow = ensure_min_saturation_hsv(yellow, LIGHT_THEME_MIN_SATURATION)
        blue = ensure_min_saturation_hsv(blue, LIGHT_THEME_MIN_SATURATION)
        purple = ensure_min_saturation_hsv(purple, LIGHT_THEME_MIN_SATURATION)
        aqua = ensure_min_saturation_hsv(aqua, LIGHT_THEME_MIN_SATURATION)
        orange = ensure_min_saturation_hsv(orange, LIGHT_THEME_MIN_SATURATION)

        def _ensure_light_contrast(c: str) -> str:
            cr = contrast_ratio(c, background)
            if cr < LIGHT_ACCENT_MIN_CONTRAST:
                # Darken: target luminance such that contrast ratio meets minimum
                target_lum = (bg_lum + 0.05) / LIGHT_ACCENT_MIN_CONTRAST - 0.05
                target_lum = min(target_lum, LIGHT_ACCENT_MAX_LUMINANCE)
                target_lum = max(target_lum, 0.03)
                return scale_luminance(c, target_lum)
            return c

        red = _ensure_light_contrast(red)
        green = _ensure_light_contrast(green)
        yellow = _ensure_light_contrast(yellow)
        blue = _ensure_light_contrast(blue)
        purple = _ensure_light_contrast(purple)
        aqua = _ensure_light_contrast(aqua)
        orange = _ensure_light_contrast(orange)

    # Offset bg1 from terminal background so prompt segments are visible
    # Blend slightly toward foreground to create visual separation
    prompt_bg = blend(background, foreground, 0.12)

    contrast_candidates = [foreground, background, "#ffffff", "#000000"]

    on_bg1 = best_contrast_text(prompt_bg, contrast_candidates)
    on_bg3 = best_contrast_text(selection_background, contrast_candidates)
    on_blue = best_contrast_text(blue, contrast_candidates)
    on_aqua = best_contrast_text(aqua, contrast_candidates)
    on_green = best_contrast_text(green, contrast_candidates)
    on_orange = best_contrast_text(orange, contrast_candidates)
    on_purple = best_contrast_text(purple, contrast_candidates)
    on_red = best_contrast_text(red, contrast_candidates)
    on_yellow = best_contrast_text(yellow, contrast_candidates)

    return {
        "color_fg0": foreground,
        "color_bg1": prompt_bg,
        "color_bg3": selection_background,
        "color_on_bg1": on_bg1,
        "color_on_bg3": on_bg3,
        "color_on_blue": on_blue,
        "color_on_aqua": on_aqua,
        "color_on_green": on_green,
        "color_on_orange": on_orange,
        "color_on_purple": on_purple,
        "color_on_red": on_red,
        "color_on_yellow": on_yellow,
        "color_blue": blue,
        "color_aqua": aqua,
        "color_green": green,
        "color_orange": orange,
        "color_purple": purple,
        "color_red": red,
        "color_yellow": yellow,
    }


def ensure_palette_name(config_text: str) -> str:
    palette_line = f"palette = '{PALETTE_NAME}'"
    pattern = re.compile(r"^palette\s*=\s*['\"][^'\"]+['\"]\s*$", re.MULTILINE)
    if pattern.search(config_text):
        return pattern.sub(palette_line, config_text, count=1)

    lines = config_text.splitlines()
    insert_at = 0
    for idx, line in enumerate(lines):
        if line.strip().startswith("["):
            insert_at = idx
            break
    else:
        insert_at = len(lines)

    lines.insert(insert_at, "")
    lines.insert(insert_at, palette_line)
    return "\n".join(lines) + "\n"


def update_palette_section(config_text: str, values: dict[str, str]) -> str:
    section_header = f"[palettes.{PALETTE_NAME}]"
    lines = config_text.splitlines()

    output: list[str] = []
    in_section = False
    found_section = False
    seen: set[str] = set()

    for line in lines:
        stripped = line.strip()

        if stripped.startswith("[") and stripped.endswith("]"):
            if in_section:
                for key, value in values.items():
                    if key not in seen:
                        output.append(f"{key} = '{value}'")
                in_section = False

            if stripped == section_header:
                found_section = True
                in_section = True
                output.append(line)
                continue

        if in_section:
            match = re.match(
                r"^(\s*)([A-Za-z0-9_]+)\s*=\s*(['\"])([^'\"]*)(['\"])\s*$",
                line,
            )
            if match:
                indent = match.group(1)
                key = match.group(2)
                if key in values:
                    output.append(f"{indent}{key} = '{values[key]}'")
                    seen.add(key)
                    continue

        output.append(line)

    if in_section:
        for key, value in values.items():
            if key not in seen:
                output.append(f"{key} = '{value}'")

    if not found_section:
        if output and output[-1].strip() != "":
            output.append("")
        output.append(section_header)
        for key, value in values.items():
            output.append(f"{key} = '{value}'")

    return "\n".join(output) + "\n"


def write_if_changed(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text() == content:
        return
    path.write_text(content)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate Starship config with palette derived from Ghostty theme"
    )
    parser.add_argument(
        "--template", required=True, help="Path to Starship template config"
    )
    parser.add_argument(
        "--output", required=True, help="Path to generated Starship config"
    )
    parser.add_argument(
        "--ghostty-cmd",
        default="ghostty",
        help="Ghostty executable name/path (default: ghostty)",
    )
    args = parser.parse_args()

    template_path = Path(args.template).expanduser()
    output_path = Path(args.output).expanduser()

    template_text = template_path.read_text()
    rendered = template_text

    parsed = load_ghostty_config(args.ghostty_cmd)
    if parsed:
        rendered = ensure_palette_name(rendered)
        rendered = update_palette_section(rendered, build_starship_palette(parsed))

    write_if_changed(output_path, rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
