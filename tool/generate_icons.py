"""Generate Welhof favicon + PWA app icons.

Uses the opaque logo (white text on its own blue background) and pads it to a
square with the logo's own background colour, so the wordmark stays white.
Run from the project root:  python tool/generate_icons.py
"""
from PIL import Image

# Opaque version: blue background, red ellipse, solid white "Welhof".
SRC = "assets/images/welhof_logo_full.png"

logo = Image.open(SRC).convert("RGBA")
bg = logo.getpixel((2, 2))  # sample the logo's own blue background


def make(size, out, logo_width_ratio):
    canvas = Image.new("RGBA", (size, size), bg)
    target_w = int(size * logo_width_ratio)
    scale = target_w / logo.width
    target_h = max(1, int(logo.height * scale))
    resized = logo.resize((target_w, target_h), Image.LANCZOS)
    x = (size - target_w) // 2
    y = (size - target_h) // 2
    canvas.alpha_composite(resized, (x, y))
    canvas.convert("RGB").save(out)
    print("wrote", out, f"{size}x{size}", "bg", bg)


# Standard icons: wordmark spans most of the width.
make(32, "web/favicon.png", 0.94)
make(192, "web/icons/Icon-192.png", 0.90)
make(512, "web/icons/Icon-512.png", 0.90)
# Maskable icons: keep content inside the ~80% safe zone.
make(192, "web/icons/Icon-maskable-192.png", 0.70)
make(512, "web/icons/Icon-maskable-512.png", 0.70)
