#!/usr/bin/env python3
"""Build PeekMeow.icns inputs and PeekMeow.ico from the two logo masters.

Full art is used at 48 px and above. The simplified master is used at 32 px
and below so the eyes, ears, and door edge survive.
"""

from __future__ import annotations

import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "Brand"
FULL = BRAND / "PeekMeow-Logo.png"
SMALL = BRAND / "PeekMeow-Logo-Small.png"
ICONSET = BRAND / "AppIcon.iconset"
ICNS = BRAND / "AppIcon.icns"
ICO = ROOT / "windows" / "src" / "PeekMeow.Windows" / "Assets" / "PeekMeow.ico"
MENU = BRAND / "PeekMeow-MenuBar.png"

# (filename, pixels, simplified)
ICONSET_IMAGES = [
    ("icon_16x16.png", 16, True),
    ("icon_16x16@2x.png", 32, True),
    ("icon_32x32.png", 32, True),
    ("icon_32x32@2x.png", 64, False),
    ("icon_128x128.png", 128, False),
    ("icon_128x128@2x.png", 256, False),
    ("icon_256x256.png", 256, False),
    ("icon_256x256@2x.png", 512, False),
    ("icon_512x512.png", 512, False),
    ("icon_512x512@2x.png", 1024, False),
]

ICO_SIZES = [16, 20, 24, 32, 48, 64, 128, 256]


def render(size: int, simplified: bool, destination: Path) -> None:
    source = SMALL if simplified else FULL
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["sips", "-s", "format", "png", "-z", str(size), str(size), str(source), "--out", str(destination)],
        check=True,
        stdout=subprocess.DEVNULL,
    )


def write_ico(images: list[tuple[int, bytes]], destination: Path) -> None:
    count = len(images)
    header = struct.pack("<HHH", 0, 1, count)
    directory = bytearray()
    payload = bytearray()
    offset = 6 + 16 * count
    for size, data in images:
        width = 0 if size >= 256 else size
        height = 0 if size >= 256 else size
        directory += struct.pack("<BBBBHHII", width, height, 0, 0, 1, 32, len(data), offset)
        payload += data
        offset += len(data)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(header + directory + payload)


def write_menu_bar() -> None:
    """Color cat for the menu bar. The cream field becomes transparent; the door stays."""
    from collections import deque

    from PIL import Image

    image = Image.open(SMALL).convert("RGBA")
    width, height = image.size
    pixels = image.load()
    background = pixels[0, 0][:3]
    seen = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def is_background(color: tuple[int, int, int, int]) -> bool:
        return all(abs(color[channel] - background[channel]) <= 26 for channel in range(3))

    def consider(x: int, y: int) -> None:
        index = y * width + x
        if seen[index]:
            return
        seen[index] = 1
        if is_background(pixels[x, y]):
            queue.append((x, y))

    for x in range(width):
        consider(x, 0)
        consider(x, height - 1)
    for y in range(height):
        consider(0, y)
        consider(width - 1, y)
    while queue:
        x, y = queue.popleft()
        red, green, blue, _ = pixels[x, y]
        pixels[x, y] = (red, green, blue, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < width and 0 <= ny < height:
                consider(nx, ny)

    min_x, min_y, max_x, max_y = width, height, 0, 0
    for y in range(height):
        for x in range(width):
            if pixels[x, y][3] <= 16:
                continue
            min_x = min(min_x, x)
            min_y = min(min_y, y)
            max_x = max(max_x, x)
            max_y = max(max_y, y)
    pad = 8
    crop = image.crop(
        (
            max(0, min_x - pad),
            max(0, min_y - pad),
            min(width, max_x + 1 + pad),
            min(height, max_y + 1 + pad),
        )
    )
    point_height = 144
    point_width = max(1, round(crop.size[0] * point_height / crop.size[1]))
    crop.resize((point_width, point_height), Image.Resampling.LANCZOS).save(MENU)


def main() -> int:
    if not FULL.is_file() or not SMALL.is_file():
        print("missing logo masters in Brand/", file=sys.stderr)
        return 1
    if ICONSET.exists():
        for child in ICONSET.iterdir():
            child.unlink()
    ICONSET.mkdir(parents=True, exist_ok=True)
    for name, size, simplified in ICONSET_IMAGES:
        render(size, simplified, ICONSET / name)
    subprocess.run(["iconutil", "-c", "icns", str(ICONSET), "-o", str(ICNS)], check=True)
    ico_images: list[tuple[int, bytes]] = []
    temporary = BRAND / ".ico-build"
    temporary.mkdir(exist_ok=True)
    for size in ICO_SIZES:
        path = temporary / f"{size}.png"
        render(size, size <= 32, path)
        ico_images.append((size, path.read_bytes()))
        path.unlink()
    temporary.rmdir()
    write_ico(ico_images, ICO)
    write_menu_bar()
    print(f"wrote {ICNS}")
    print(f"wrote {ICO}")
    print(f"wrote {MENU}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
