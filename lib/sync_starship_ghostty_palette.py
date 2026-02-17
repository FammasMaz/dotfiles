#!/usr/bin/env python3

import argparse
import re
import subprocess
from pathlib import Path


PALETTE_NAME = "ghostty_dynamic"
HEX_RE = re.compile(r"^#([0-9a-fA-F]{6})$")
PALETTE_LINE_RE = re.compile(r"^(\d+)\s*=\s*(#[0-9a-fA-F]{6})$")
KEY_VALUE_RE = re.compile(r"^([a-z0-9-]+)\s*=\s*(.+)$")

DARK_BACKGROUND_LUMINANCE_THRESHOLD = 0.26
DARK_THEME_SATURATION_BOOST = 1.35
DARK_ACCENT_MAX_LUMINANCE = 0.55
DARK_ACCENT_MIN_CONTRAST = 3.5


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


def boost_saturation_preserve_luminance(color: str, factor: float) -> str:
    if factor <= 1.0:
        return color

    r8, g8, b8 = hex_to_rgb(color)
    r = channel_to_linear(r8)
    g = channel_to_linear(g8)
    b = channel_to_linear(b8)
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b

    def transform(k: float) -> tuple[float, float, float]:
        return (
            y + (r - y) * k,
            y + (g - y) * k,
            y + (b - y) * k,
        )

    low = 1.0
    high = factor
    for _ in range(20):
        mid = (low + high) / 2
        tr, tg, tb = transform(mid)
        if 0.0 <= tr <= 1.0 and 0.0 <= tg <= 1.0 and 0.0 <= tb <= 1.0:
            low = mid
        else:
            high = mid

    out_r, out_g, out_b = transform(low)
    return rgb_to_hex(
        (
            linear_to_channel(out_r),
            linear_to_channel(out_g),
            linear_to_channel(out_b),
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

    return rgb_to_hex((
        linear_to_channel(new_r),
        linear_to_channel(new_g),
        linear_to_channel(new_b),
    ))


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

    if relative_luminance(background) < DARK_BACKGROUND_LUMINANCE_THRESHOLD:
        red = boost_saturation_preserve_luminance(red, DARK_THEME_SATURATION_BOOST)
        green = boost_saturation_preserve_luminance(green, DARK_THEME_SATURATION_BOOST)
        yellow = boost_saturation_preserve_luminance(
            yellow, DARK_THEME_SATURATION_BOOST
        )
        blue = boost_saturation_preserve_luminance(blue, DARK_THEME_SATURATION_BOOST)
        purple = boost_saturation_preserve_luminance(
            purple, DARK_THEME_SATURATION_BOOST
        )
        aqua = boost_saturation_preserve_luminance(aqua, DARK_THEME_SATURATION_BOOST)
        orange = boost_saturation_preserve_luminance(
            orange, DARK_THEME_SATURATION_BOOST
        )

        # Clamp accent luminance to prevent washed-out segment backgrounds
        def _clamp_lum(c: str) -> str:
            if relative_luminance(c) > DARK_ACCENT_MAX_LUMINANCE:
                return scale_luminance(c, DARK_ACCENT_MAX_LUMINANCE)
            return c

        red = _clamp_lum(red)
        green = _clamp_lum(green)
        yellow = _clamp_lum(yellow)
        blue = _clamp_lum(blue)
        purple = _clamp_lum(purple)
        aqua = _clamp_lum(aqua)
        orange = _clamp_lum(orange)

        # Brighten colors with insufficient contrast against background
        bg_lum = relative_luminance(background)

        def _ensure_contrast(c: str) -> str:
            if contrast_ratio(c, background) < DARK_ACCENT_MIN_CONTRAST:
                target_lum = DARK_ACCENT_MIN_CONTRAST * (bg_lum + 0.05) - 0.05
                target_lum = max(target_lum, 0.15)
                return scale_luminance(c, target_lum)
            return c

        red = _ensure_contrast(red)
        green = _ensure_contrast(green)
        yellow = _ensure_contrast(yellow)
        blue = _ensure_contrast(blue)
        purple = _ensure_contrast(purple)
        aqua = _ensure_contrast(aqua)
        orange = _ensure_contrast(orange)

    contrast_candidates = [foreground, background, "#ffffff", "#000000"]

    on_bg1 = best_contrast_text(background, contrast_candidates)
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
        "color_bg1": background,
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
