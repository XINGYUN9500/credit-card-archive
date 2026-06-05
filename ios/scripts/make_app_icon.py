#!/usr/bin/env python3
import json
import math
import os
import struct
import zlib

ROOT = os.path.join(os.path.dirname(__file__), "..", "CreditCardArchive", "Assets.xcassets", "AppIcon.appiconset")
CONTENTS = os.path.join(ROOT, "Contents.json")


def rgba_png(path, size):
    pixels = bytearray()
    for y in range(size):
        row = bytearray()
        for x in range(size):
            nx = x / max(size - 1, 1)
            ny = y / max(size - 1, 1)
            r = int(13 + 12 * nx)
            g = int(118 + 58 * (1 - ny))
            b = int(112 + 62 * nx)
            a = 255

            # White credit card body.
            cx0, cy0, cx1, cy1 = 0.17 * size, 0.31 * size, 0.83 * size, 0.68 * size
            rr = 0.055 * size
            inside_card = rounded_rect(x, y, cx0, cy0, cx1, cy1, rr)
            if inside_card:
                r, g, b = 245, 252, 250

            # Teal magnetic stripe.
            if inside_card and cy0 + 0.11 * size <= y <= cy0 + 0.16 * size:
                r, g, b = 22, 135, 128

            # Gold chip.
            chip = rounded_rect(x, y, cx0 + 0.08 * size, cy0 + 0.22 * size, cx0 + 0.25 * size, cy0 + 0.34 * size, 0.018 * size)
            if chip:
                r, g, b = 223, 176, 80

            # Two small lines.
            if inside_card and cx0 + 0.34 * size <= x <= cx0 + 0.68 * size:
                if cy0 + 0.24 * size <= y <= cy0 + 0.27 * size or cy0 + 0.33 * size <= y <= cy0 + 0.36 * size:
                    r, g, b = 75, 96, 102

            # Tiny shine.
            dist = math.hypot(nx - 0.24, ny - 0.18)
            if dist < 0.28:
                lift = int((0.28 - dist) * 90)
                r, g, b = min(255, r + lift), min(255, g + lift), min(255, b + lift)

            row.extend([r, g, b, a])
        pixels.extend(b"\x00" + row)

    raw = zlib.compress(bytes(pixels), 9)
    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xffffffff)
    data = b"\x89PNG\r\n\x1a\n"
    data += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
    data += chunk(b"IDAT", raw)
    data += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(data)


def rounded_rect(x, y, x0, y0, x1, y1, r):
    if x0 + r <= x <= x1 - r and y0 <= y <= y1:
        return True
    if x0 <= x <= x1 and y0 + r <= y <= y1 - r:
        return True
    for cx, cy in ((x0 + r, y0 + r), (x1 - r, y0 + r), (x0 + r, y1 - r), (x1 - r, y1 - r)):
        if (x - cx) ** 2 + (y - cy) ** 2 <= r ** 2:
            return True
    return False


def icon_size(entry):
    base = float(entry["size"].split("x")[0])
    scale = int(entry["scale"].replace("x", ""))
    return int(round(base * scale))


os.makedirs(ROOT, exist_ok=True)
with open(CONTENTS, "r", encoding="utf-8") as f:
    contents = json.load(f)
for image in contents["images"]:
    rgba_png(os.path.join(ROOT, image["filename"]), icon_size(image))
print("Generated", len(contents["images"]), "app icon PNGs")
