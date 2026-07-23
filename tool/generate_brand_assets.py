"""Generate Recess launcher and splash assets from original geometry."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
GREEN = "#315C4B"
CREAM = "#F7F3E8"
CANVAS = 1024

# One original silhouette used by both the SVG and raster renderers.
BODY_COMMANDS = (
    ("M", (512, 210)),
    ("C", (408, 210, 334, 286, 326, 402)),
    ("C", (319, 518, 300, 610, 250, 680)),
    ("C", (234, 702, 250, 732, 278, 732)),
    ("L", (746, 732)),
    ("C", (774, 732, 790, 702, 774, 680)),
    ("C", (724, 610, 705, 518, 698, 402)),
    ("C", (690, 286, 616, 210, 512, 210)),
    ("Z", ()),
)


def _hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.removeprefix("#")
    return tuple(int(value[index : index + 2], 16) for index in (0, 2, 4))


def _cubic(
    start: tuple[float, float],
    control1: tuple[float, float],
    control2: tuple[float, float],
    end: tuple[float, float],
    steps: int = 32,
) -> list[tuple[float, float]]:
    points = []
    for index in range(1, steps + 1):
        t = index / steps
        inverse = 1 - t
        points.append(
            (
                inverse**3 * start[0]
                + 3 * inverse**2 * t * control1[0]
                + 3 * inverse * t**2 * control2[0]
                + t**3 * end[0],
                inverse**3 * start[1]
                + 3 * inverse**2 * t * control1[1]
                + 3 * inverse * t**2 * control2[1]
                + t**3 * end[1],
            )
        )
    return points


def _body_points() -> list[tuple[float, float]]:
    points: list[tuple[float, float]] = []
    current = (0.0, 0.0)
    start = current
    for command, values in BODY_COMMANDS:
        if command == "M":
            current = (values[0], values[1])
            start = current
            points.append(current)
        elif command == "L":
            current = (values[0], values[1])
            points.append(current)
        elif command == "C":
            control1 = (values[0], values[1])
            control2 = (values[2], values[3])
            end = (values[4], values[5])
            points.extend(_cubic(current, control1, control2, end))
            current = end
        elif command == "Z":
            points.append(start)
    return points


def _svg_path() -> str:
    pieces = []
    for command, values in BODY_COMMANDS:
        suffix = " ".join(str(value) for value in values)
        pieces.append(f"{command}{suffix}")
    return " ".join(pieces)


def _svg(*, include_background: bool) -> str:
    background = (
        f'  <rect width="1024" height="1024" fill="{CREAM}"/>\n'
        if include_background
        else ""
    )
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">\n'
        f"{background}"
        f'  <rect x="448" y="150" width="128" height="96" rx="48" fill="{GREEN}"/>\n'
        f'  <path fill="{GREEN}" d="{_svg_path()}"/>\n'
        f'  <rect x="266" y="710" width="492" height="64" rx="32" fill="{GREEN}"/>\n'
        f'  <circle cx="512" cy="820" r="48" fill="{GREEN}"/>\n'
        "</svg>\n"
    )


def _render(size: int, *, background: bool, mark_scale: float = 1.0) -> Image.Image:
    oversample = 4
    working = CANVAS * oversample
    mode = "RGB" if background else "RGBA"
    fill = _hex_rgb(CREAM) if background else (0, 0, 0, 0)
    image = Image.new(mode, (working, working), fill)
    draw = ImageDraw.Draw(image)
    green = _hex_rgb(GREEN) if background else (*_hex_rgb(GREEN), 255)

    def transform(point: tuple[float, float]) -> tuple[float, float]:
        x = 512 + (point[0] - 512) * mark_scale
        y = 512 + (point[1] - 512) * mark_scale
        return x * oversample, y * oversample

    x1, y1 = transform((448, 150))
    x2, y2 = transform((576, 246))
    draw.rounded_rectangle((x1, y1, x2, y2), radius=48 * mark_scale * oversample, fill=green)
    draw.polygon([transform(point) for point in _body_points()], fill=green)
    x1, y1 = transform((266, 710))
    x2, y2 = transform((758, 774))
    draw.rounded_rectangle((x1, y1, x2, y2), radius=32 * mark_scale * oversample, fill=green)
    cx, cy = transform((512, 820))
    radius = 48 * mark_scale * oversample
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=green)
    return image.resize((size, size), Image.Resampling.LANCZOS)


def _write_png(path: Path, size: int, *, background: bool, mark_scale: float = 1.0) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    _render(size, background=background, mark_scale=mark_scale).save(path, optimize=True)


def _write_android() -> None:
    legacy_sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    foreground_sizes = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
    res = ROOT / "android/app/src/main/res"
    for density, size in legacy_sizes.items():
        directory = res / f"mipmap-{density}"
        _write_png(directory / "ic_launcher.png", size, background=True)
        _write_png(directory / "ic_launcher_round.png", size, background=True)
    for density, size in foreground_sizes.items():
        _write_png(
            res / f"mipmap-{density}/ic_launcher_foreground.png",
            size,
            background=False,
            mark_scale=0.83,
        )


def _write_ios() -> None:
    app_icon = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((app_icon / "Contents.json").read_text(encoding="utf-8"))
    for entry in contents["images"]:
        points = float(entry["size"].split("x")[0])
        scale = float(entry["scale"].removesuffix("x"))
        _write_png(app_icon / entry["filename"], round(points * scale), background=True)

    splash = ROOT / "ios/Runner/Assets.xcassets/RecessBell.imageset"
    for scale, size in (("1x", 128), ("2x", 256), ("3x", 384)):
        _write_png(splash / f"RecessBell@{scale}.png", size, background=False)
    contents = {
        "images": [
            {"idiom": "universal", "filename": f"RecessBell@{scale}.png", "scale": scale}
            for scale in ("1x", "2x", "3x")
        ],
        "info": {"version": 1, "author": "recess"},
    }
    (splash / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    branding = ROOT / "assets/branding"
    branding.mkdir(parents=True, exist_ok=True)
    (branding / "recess_bell_master.svg").write_text(_svg(include_background=True), encoding="utf-8")
    _write_png(branding / "recess_bell_master_1024.png", 1024, background=True)
    _write_android()
    _write_ios()
    print(f"Generated Recess identity with green {GREEN} and cream {CREAM}.")


if __name__ == "__main__":
    main()
