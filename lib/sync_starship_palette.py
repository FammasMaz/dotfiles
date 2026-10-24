#!/usr/bin/env python3
"""Generate a Starship config whose palette is derived from the terminal's colors.

The colors come from the terminal itself (OSC 4/10/11 queries, see
lib/termpalette.c), so this works in Ghostty, Rex, and any other terminal that
answers xterm color queries.
"""

from __future__ import annotations

import argparse
import colorsys
import os
import re
import time
from pathlib import Path


PALETTE_NAME = "terminal"
HEX_RE = re.compile(r"^#([0-9a-fA-F]{6})$")

DARK_BACKGROUND_LUMINANCE_THRESHOLD = 0.26
DARK_THEME_MIN_SATURATION = 0.4
DARK_ACCENT_MIN_CONTRAST = 3.5
DARK_ACCENT_MAX_LUMINANCE = 0.45

LIGHT_THEME_MIN_SATURATION = 0.52
LIGHT_ACCENT_MIN_CONTRAST = 3.0
LIGHT_ACCENT_MAX_LUMINANCE = 0.48
LIGHT_PROMPT_BG_BLEND = 0.28


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


def parse_colors_arg(values: list[str]) -> dict:
    """Turn `BG FG C0..C15` (termpalette output order) into the parsed-theme shape."""
    colors = [normalize_hex(v) for v in values]
    if len(colors) != 18 or any(c is None for c in colors):
        raise SystemExit("--colors expects 18 #rrggbb values: BG FG C0..C15")
    return {
        "background": colors[0],
        "foreground": colors[1],
        "palette": {idx: color for idx, color in enumerate(colors[2:])},
    }


def query_terminal_colors(timeout: float = 0.5) -> list[str] | None:
    """Python fallback for lib/termpalette.c (used when no C compiler is available)."""
    import select
    import termios

    try:
        fd = os.open("/dev/tty", os.O_RDWR | os.O_NOCTTY)
    except OSError:
        return None
    try:
        saved = termios.tcgetattr(fd)
        raw = termios.tcgetattr(fd)
        raw[3] &= ~(termios.ICANON | termios.ECHO)
        raw[6][termios.VMIN] = 0
        raw[6][termios.VTIME] = 0
        termios.tcsetattr(fd, termios.TCSANOW, raw)
        try:
            query = "".join(f"\033]4;{i};?\033\\" for i in range(16))
            os.write(fd, (query + "\033]10;?\033\\\033]11;?\033\\\033[c").encode())
            buf = b""
            deadline = time.monotonic() + timeout
            da1 = re.compile(rb"\033\[\?[0-9;]*c")
            while not da1.search(buf):
                left = deadline - time.monotonic()
                if left <= 0 or not select.select([fd], [], [], left)[0]:
                    break
                buf += os.read(fd, 4096)
        finally:
            termios.tcsetattr(fd, termios.TCSANOW, saved)
    finally:
        os.close(fd)

    def to_hex(spec: bytes) -> str:
        parts = spec.split(b"/")[:3]
        return "#" + "".join(
            f"{round(int(p, 16) * 255 / (16 ** len(p) - 1)):02x}" for p in parts
        )

    slots: dict[int, str] = {}
    osc = re.compile(rb"\033\](4;(\d+)|10|11);rgba?:([0-9a-fA-F]{1,4}/[0-9a-fA-F]{1,4}/[0-9a-fA-F]{1,4})")
    for match in osc.finditer(buf):
        if match.group(2) is not None:
            slot = 2 + int(match.group(2))
        else:
            slot = 1 if match.group(1) == b"10" else 0
        if 0 <= slot < 18:
            slots.setdefault(slot, to_hex(match.group(3)))
    if len(slots) != 18:
        return None
    return [slots[i] for i in range(18)]


def palette_key(colors: list[str]) -> str:
    """Same FNV-1a hash termpalette prints, so both paths share cache files."""
    h = 2166136261
    for byte in "".join(f" {c}" for c in colors).encode():
        h = ((h ^ byte) * 16777619) & 0xFFFFFFFF
    return f"{h:08x}"


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
        # Light theme: keep Ghostty accent hues vivid; only nudge luminance when contrast is low.
        yellow = colors.get(3) or yellow
        orange = colors.get(11) or colors.get(3) or orange

        red = ensure_min_saturation_hsv(red, LIGHT_THEME_MIN_SATURATION)
        green = ensure_min_saturation_hsv(green, LIGHT_THEME_MIN_SATURATION)
        yellow = ensure_min_saturation_hsv(yellow, LIGHT_THEME_MIN_SATURATION)
        blue = ensure_min_saturation_hsv(blue, LIGHT_THEME_MIN_SATURATION)
        purple = ensure_min_saturation_hsv(purple, LIGHT_THEME_MIN_SATURATION)
        aqua = ensure_min_saturation_hsv(aqua, LIGHT_THEME_MIN_SATURATION)
        orange = ensure_min_saturation_hsv(orange, LIGHT_THEME_MIN_SATURATION)

        def _ensure_light_contrast(c: str) -> str:
            cr = contrast_ratio(c, background)
            if cr >= LIGHT_ACCENT_MIN_CONTRAST:
                lum = relative_luminance(c)
                if lum <= LIGHT_ACCENT_MAX_LUMINANCE:
                    return c
                return scale_luminance(c, LIGHT_ACCENT_MAX_LUMINANCE)
            target_lum = (bg_lum + 0.05) / LIGHT_ACCENT_MIN_CONTRAST - 0.05
            target_lum = min(target_lum, LIGHT_ACCENT_MAX_LUMINANCE)
            target_lum = max(target_lum, 0.06)
            return scale_luminance(c, target_lum)

        red = _ensure_light_contrast(red)
        green = _ensure_light_contrast(green)
        yellow = _ensure_light_contrast(yellow)
        blue = _ensure_light_contrast(blue)
        purple = _ensure_light_contrast(purple)
        aqua = _ensure_light_contrast(aqua)
        orange = _ensure_light_contrast(orange)

    # Offset bg1 from terminal background so prompt segments are visible
    if is_dark:
        prompt_bg = blend(background, foreground, 0.12)
    else:
        neutral = colors.get(8) or foreground
        prompt_bg = blend(background, neutral, LIGHT_PROMPT_BG_BLEND)
        if contrast_ratio(prompt_bg, background) < 1.35:
            prompt_bg = blend(background, foreground, LIGHT_PROMPT_BG_BLEND)

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


def write_output(path: Path, content: str) -> None:
    # Always rewrite: callers use the file's mtime to decide whether to regenerate.
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(content)
    tmp.replace(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--template", required=True, help="Starship template config")
    out = parser.add_mutually_exclusive_group(required=True)
    out.add_argument("--output", help="Generated Starship config path")
    out.add_argument(
        "--output-dir",
        help="Write <dir>/<palette-hash>.toml and print '<path> <dark|light>'",
    )
    src = parser.add_mutually_exclusive_group(required=True)
    src.add_argument("--colors", nargs=18, metavar="HEX", help="BG FG C0..C15")
    src.add_argument("--query", action="store_true", help="Query the terminal (/dev/tty)")
    args = parser.parse_args()

    if args.colors:
        colors = args.colors
    else:
        colors = query_terminal_colors()
        if colors is None:
            return 1
    parsed = parse_colors_arg(colors)

    if args.output:
        output_path = Path(args.output).expanduser()
    else:
        output_path = Path(args.output_dir).expanduser() / f"{palette_key(colors)}.toml"

    rendered = Path(args.template).expanduser().read_text()
    rendered = ensure_palette_name(rendered)
    rendered = update_palette_section(rendered, build_starship_palette(parsed))
    write_output(output_path, rendered)

    if args.output_dir:
        # Same light/dark rule as termpalette and Neovim's 'background' detection.
        r, g, b = hex_to_rgb(parsed["background"])
        print(output_path, "dark" if (0.299 * r + 0.587 * g + 0.114 * b) / 255 < 0.5 else "light")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
