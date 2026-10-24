#!/usr/bin/env python3
"""Generate a Starship config whose palette is derived from the terminal's colors.

The colors come from the terminal itself (OSC 4/10/11 queries, see
lib/termpalette.c), so this works in Ghostty, Rex, and any other terminal that
answers xterm color queries.
"""

from __future__ import annotations

import argparse
import os
import re
import time
from pathlib import Path


PALETTE_NAME = "terminal"
HEX_RE = re.compile(r"^#([0-9a-fA-F]{6})$")

# Segment fill = this much of the accent mixed into the terminal background.
DARK_TINT = 0.28
LIGHT_TINT = 0.20
# Minimum WCAG contrast for segment text and for the prompt character.
TEXT_MIN_CONTRAST = 4.5
CHAR_MIN_CONTRAST = 3.0


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


def is_dark(color: str) -> bool:
    """Same light/dark rule as termpalette and Neovim's 'background' detection."""
    r, g, b = hex_to_rgb(color)
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255 < 0.5


def readable(color: str, against: str, min_contrast: float) -> str:
    """Move `color` toward white (dark `against`) or black (light) until it has
    `min_contrast` against `against`. Colors that already pass are unchanged."""
    target = "#ffffff" if is_dark(against) else "#000000"
    out, t = color, 0.0
    while contrast_ratio(out, against) < min_contrast and t < 1.0:
        t = min(1.0, t + 0.04)
        out = blend(color, target, t)
    return out


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
    """Tinted style: each segment is a soft tint of one of the theme's accents
    over the terminal background, with its text in that accent. Colors come
    straight from the theme; only lightness is adjusted, and only when needed
    for contrast."""
    c = parsed["palette"]
    bg, fg = parsed["background"], parsed["foreground"]
    dark = is_dark(bg)

    accents = {"red": c[1], "green": c[2], "yellow": c[3], "blue": c[4], "purple": c[5], "aqua": c[6]}
    accents["orange"] = blend(c[1], c[3], 0.5)
    # Text color per segment: the bright variant on dark themes, the normal
    # one on light themes (bright variants are usually lighter).
    text = {"red": c[9], "green": c[10], "yellow": c[11], "blue": c[12], "purple": c[13], "aqua": c[14]}
    text["orange"] = blend(c[9], c[11], 0.5)
    if not dark:
        text = dict(accents)

    tint = DARK_TINT if dark else LIGHT_TINT
    palette = {
        "color_fg0": blend(bg, fg, 0.55),  # fill dots
        "color_bg1": blend(bg, fg, 0.10),  # neutral segments (time, docker)
        "color_bg3": blend(bg, fg, 0.18),  # conda/pixi
    }
    palette["color_on_bg1"] = readable(fg, palette["color_bg1"], TEXT_MIN_CONTRAST)
    palette["color_on_bg3"] = readable(fg, palette["color_bg3"], TEXT_MIN_CONTRAST)

    for name, accent in accents.items():
        fill = blend(bg, accent, tint)
        palette[f"color_{name}"] = fill
        palette[f"color_on_{name}"] = readable(text[name], fill, TEXT_MIN_CONTRAST)

    # The prompt character sits on the terminal background, not on a tint.
    for key, name in (("ok", "green"), ("err", "red"), ("replace", "purple"), ("visual", "yellow")):
        palette[f"color_char_{key}"] = readable(text[name], bg, CHAR_MIN_CONTRAST)

    return palette


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
        print(output_path, "dark" if is_dark(parsed["background"]) else "light")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
