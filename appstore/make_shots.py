#!/usr/bin/env python3
"""Compose App Store 6.9" screenshots (1320x2868) from raw simulator captures.

Brand: DRILL green #22D68A on the app's near-black ground, matching
site/style.css and ios/DRILL/Views/Theme.swift.
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1320, 2868
GREEN = (0x22, 0xD6, 0x8A)
INK = (0x0A, 0x0A, 0x0A)

RAW = "/tmp/drillshots/raw"
OUT = "/tmp/drillshots/out"
os.makedirs(OUT, exist_ok=True)

SF = "/System/Library/Fonts/SFNS.ttf"


def font(size, weight="Regular"):
    f = ImageFont.truetype(SF, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def radial_glow(size, center, radius, color, peak):
    """Soft radial glow, drawn cheaply as stacked ellipses then blurred."""
    w, h = size
    layer = Image.new("L", (w // 4, h // 4), 0)
    d = ImageDraw.Draw(layer)
    cx, cy, r = center[0] // 4, center[1] // 4, radius // 4
    steps = 48
    for i in range(steps, 0, -1):
        t = i / steps
        rr = r * t
        v = int(peak * 255 * (1 - t) ** 2)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=v)
    layer = layer.filter(ImageFilter.GaussianBlur(12)).resize((w, h), Image.LANCZOS)
    tint = Image.new("RGB", (w, h), color)
    return tint, layer


def background():
    bg = Image.new("RGB", (W, H), INK)
    # Green glow behind the headline, echoing the welcome screen.
    tint, mask = radial_glow((W, H), (W // 2, 560), 1500, GREEN, 0.30)
    bg = Image.composite(tint, bg, mask)
    # A second, tighter glow under the device for lift off the ground.
    tint2, mask2 = radial_glow((W, H), (W // 2, 1750), 1150, GREEN, 0.10)
    bg = Image.composite(tint2, bg, mask2)
    return bg


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius, fill=255)
    return m


def centered(draw, text, y, f, fill):
    box = draw.textbbox((0, 0), text, font=f)
    draw.text(((W - (box[2] - box[0])) / 2 - box[0], y), text, font=f, fill=fill)
    return box[3] - box[1]


def frame(raw_name, eyebrow, headline, sub, out_name):
    bg = background()
    draw = ImageDraw.Draw(bg)

    f_eye = font(34, "Bold")
    f_head = font(88, "Bold")
    f_sub = font(40, "Regular")

    y = 196
    # Eyebrow, letterspaced by hand since PIL has no tracking.
    spaced = "  ".join(eyebrow.upper())
    centered(draw, spaced, y, f_eye, GREEN)
    y += 78

    for line in headline:
        centered(draw, line, y, f_head, (255, 255, 255))
        y += 108
    y += 18

    # A mid grey rather than translucent white: PIL text alpha needs its own
    # RGBA layer, and this reads the same against the near-black ground.
    for line in sub:
        centered(draw, line, y, f_sub, (163, 168, 165))
        y += 54

    # Device screenshot
    shot = Image.open(os.path.join(RAW, raw_name)).convert("RGB")
    target_w = 952
    target_h = round(target_w * shot.height / shot.width)
    shot = shot.resize((target_w, target_h), Image.LANCZOS)
    radius = 74
    mask = rounded_mask((target_w, target_h), radius)

    x0 = (W - target_w) // 2
    y0 = 700

    # Drop shadow
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle(
        [x0, y0 + 26, x0 + target_w, y0 + target_h + 26], radius, fill=(0, 0, 0, 190)
    )
    sh = sh.filter(ImageFilter.GaussianBlur(38))
    bg = Image.alpha_composite(bg.convert("RGBA"), sh).convert("RGB")

    bg.paste(shot, (x0, y0), mask)

    # Hairline edge so the black screen separates from the black ground.
    edge = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle(
        [x0, y0, x0 + target_w, y0 + target_h], radius, outline=(255, 255, 255, 46), width=3
    )
    bg = Image.alpha_composite(bg.convert("RGBA"), edge).convert("RGB")

    bg.save(os.path.join(OUT, out_name), "PNG")
    print(f"{out_name}  {bg.size[0]}x{bg.size[1]}")


FRAMES = [
    ("welcome.png", "Multi-sport training",
     ["Never miss", "a rep"],
     ["A fresh session every training day,", "built around the sports they play."],
     "01-welcome.png"),
    ("today.png", "Every training day",
     ["A session built", "around their sports"],
     ["Warmup, drills, a finisher, a cooldown.", "Composed fresh, never the same twice."],
     "02-today.png"),
    ("timer.png", "Guided out loud",
     ["A timer that talks", "them through it"],
     ["Every step read aloud and timed on its own,", "so the phone can go in a pocket."],
     "03-timer.png"),
    ("progress.png", "Streaks that forgive",
     ["Rest days never", "break the streak"],
     ["Twelve badges, all of them reachable.", "Today never counts against you."],
     "04-progress.png"),
    ("pick_sports.png", "Nine sports",
     ["Pick the sports", "they actually play"],
     ["Soccer, football, basketball, baseball,", "track, cardio, strength, plyo, balance."],
     "05-sports.png"),
    ("steps.png", "Plain words",
     ["Written for an", "8 to 12 year old"],
     ["Every drill explained step by step,", "with no coach standing over them."],
     "06-steps.png"),
    ("calendar.png", "The whole month",
     ["See every day", "at a glance"],
     ["Tap any day to open its session.", "Nothing leaves the phone, ever."],
     "07-calendar.png"),
]

for args in FRAMES:
    frame(*args)
print("done")
