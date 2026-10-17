"""Crops and resizes the original Unity sprites into Godot/assets/art.
Run from the repository root:  python Godot/platform/prepare_art.py
Sources are read-only; outputs are small, ready-to-import PNG/JPG files."""
import math
import os
from PIL import Image, ImageDraw

A = "Assets/"
OUT = "Godot/assets/art/"
os.makedirs(OUT, exist_ok=True)


def load(path):
    return Image.open(A + path).convert("RGBA")


def trim(im):
    box = im.getbbox()
    return im.crop(box) if box else im


def fit(im, width=None, height=None):
    w, h = im.size
    if width and not height:
        height = round(h * width / w)
    if height and not width:
        width = round(w * height / h)
    return im.resize((width, height), Image.LANCZOS)


def save(im, name):
    if name.endswith(".jpg"):
        im.convert("RGB").save(OUT + name, quality=88)
    else:
        im.save(OUT + name, optimize=True)


def art(name):
    return Image.open(OUT + name).convert("RGBA")


# ---- Space Shooter
save(fit(load("Sprites/Images/Background/Nebula_1_1_Top.png"), 1024), "nebula.png")
save(fit(load("Sprites/Images/Background/Stars-Big_1_1.png"), 1024), "stars_big.png")
save(fit(load("Sprites/Images/Background/Stars-Medium_1_1.png"), 1024), "stars_medium.png")
save(load("Sprites/Images/Explosion.png"), "explosion.png")  # 4 x 4 frames of 128 px
save(fit(trim(load("Sprites/Images/Asteroid Shatter.png")), 320), "asteroid_shatter.png")
save(fit(trim(load("Sprites/Images/pointvfx.png")), 96), "spark.png")
save(fit(trim(load("Images/SpaceShips/Laser-Beam-PNG-HD-Image.png")), height=110), "laser.png")
save(fit(trim(load("Sprites/Images/Short-Lazer-Ship.png")), 200), "ship_blue.png")

# ---- Tuk Tuk
save(fit(trim(load("FlappyBirdStyleAssets/Sprites/New Folder/auto.png")), 300), "tuktuk.png")
save(fit(trim(load("FlappyBirdStyleAssets/Sprites/New Folder/wheel.png")), 120), "wheel.png")
save(fit(trim(load("FlappyBirdStyleAssets/Sprites/ColumnSprite.png")), 120), "column.png")
save(fit(load("FlappyBirdStyleAssets/Sprites/New level/groundGrass.png"), 808), "ground_grass.png")
save(fit(trim(load("FlappyBirdStyleAssets/Sprites/New level/puffLarge.png")), 84), "puff.png")
save(fit(trim(load("FlappyBirdStyleAssets/Sprites/New level/starGold.png")), 78), "star_gold.png")
save(fit(trim(load("FlappyBirdStyleAssets/Sprites/medalGold.png")), 114), "medal_gold.png")
save(fit(load("FlappyBirdStyleAssets/Sprites/SkyTileSprite.png"), 1024), "sky_tile.png")
save(fit(load("FlappyBirdStyleAssets/Sprites/New level/background.png"), 1600), "tt_background.png")

# ---- Diamond Catcher
chars = load("Sprites/CATCHDIAMOND/image (8).png")  # 4 x 2 cells of 96 px
for i in range(8):
    x, y = (i % 4) * 96, (i // 4) * 96
    save(fit(trim(chars.crop((x, y, x + 96, y + 96))), height=92), "catcher_%d.png" % i)
save(fit(load("Sprites/CATCHDIAMOND/image (10).png"), 128), "gem.png")
save(fit(load("Sprites/CATCHDIAMOND/image (11).png"), 256), "flare.png")
save(fit(load("Sprites/CATCHDIAMOND/5-gold-sparkle-5.png"), 900), "gold_sparkle.png")

# ---- Match Catch (baskets 3x2, spheres 3x2)
names = ["orange", "green", "blue", "purple", "pink", "red"]
baskets = load("Sprites/MATCH&DROP/baskets.png")
bw, bh = baskets.size[0] // 3, baskets.size[1] // 2
for i, n in enumerate(names):
    cell = baskets.crop(((i % 3) * bw, (i // 3) * bh, (i % 3 + 1) * bw, (i // 3 + 1) * bh))
    save(fit(trim(cell), 190), "basket_%s.png" % n)
spheres = load("Sprites/MATCH&DROP/colored_spheres_transparent.png")
sw, sh = spheres.size[0] // 3, spheres.size[1] // 2
for i, n in enumerate(names):
    cell = spheres.crop(((i % 3) * sw, (i // 3) * sh, (i % 3 + 1) * sw, (i // 3 + 1) * sh))
    save(fit(trim(cell), 100), "ball_%s.png" % n)

# ---- Table Wiping
board = load("Sprites/TABLEWIPPING/Images/bg 1.png")  # 3 x 2 grid of tools
tw, th = board.size[0] // 3, board.size[1] // 2


def tool(col, row, name, width):
    save(fit(trim(board.crop((col * tw, row * th, (col + 1) * tw, (row + 1) * th))), width), name)


tool(0, 0, "spray.png", 120)
tool(1, 0, "sponge.png", 180)
tool(2, 0, "cloth_blue.png", 180)
tool(0, 1, "hand_cloth.png", 220)
floor = load("Sprites/MATCH&DROP/wooden-sidewalk.jpg")
fw, fh = floor.size
# The photo starts with a smooth white wall; keep only the textured floor.
gray = floor.convert("L").resize((200, 200))
rows = [max(gray.getpixel((x, y)) for x in range(200)) - min(gray.getpixel((x, y)) for x in range(200)) for y in range(200)]
start = next(y for y in range(40, 200) if rows[y] > 70)
save(fit(floor.crop((0, int(fh * (start + 2) / 200), fw, fh)).resize((1600, 900), Image.LANCZOS), 1600), "table.jpg")
save(fit(trim(load("Sprites/TABLEWIPPING/dustpng.png")), 128), "dust.png")
save(fit(trim(load("Sprites/TABLEWIPPING/Images/new2.png")), 200), "crumbs.png")


# ---- Branding
save(fit(trim(load("Images/logonew.png")), 520), "logo_lab.png")
save(fit(trim(load("Images/icon.png")), 160), "mars_icon.png")
save(fit(trim(load("Images/best score.png")), 300), "best_score.png")
save(fit(load("Images/iit.png"), 96), "logo_iit.png")
save(fit(load("Images/cmc.png"), 96), "logo_cmc.png")

# ---- Game card thumbnails (320 x 200), one per game
def card(name, top, bottom, sprites=(), extra=None):
    im = Image.new("RGBA", (320, 200))
    g = ImageDraw.Draw(im)
    for y in range(200):
        t = y / 199
        g.line([(0, y), (320, y)], fill=tuple(round(top[i] * (1 - t) + bottom[i] * t) for i in range(3)) + (255,))
    if extra:
        extra(g)
    for sprite, (cx, cy), width in sprites:
        s = fit(sprite, width)
        im.alpha_composite(s, (round(cx - s.size[0] / 2), round(cy - s.size[1] / 2)))
    mask = Image.new("L", (320, 200), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 319, 199), 22, fill=255)
    im.putalpha(mask)
    save(im, "card_%s.png" % name)


def pong(g):
    g.rounded_rectangle((44, 60, 58, 140), 6, fill=(120, 255, 220, 255))
    g.rounded_rectangle((262, 80, 276, 160), 6, fill=(255, 140, 100, 255))
    g.ellipse((150, 90, 178, 118), fill=(255, 255, 255, 255))
    for x in range(20, 300, 24):
        g.line([(x, 100), (x + 10, 100)], fill=(255, 255, 255, 60), width=3)


def bubble(g):
    for r, a in [(70, 40), (60, 70), (50, 110)]:
        g.ellipse((160 - r, 100 - r, 160 + r, 100 + r), outline=(130, 255, 230, a), width=6)
    g.ellipse((135, 70, 160, 92), fill=(255, 255, 255, 140))


def fireworks(g):
    for cx, cy, col in [(110, 90, (255, 200, 90, 255)), (210, 70, (255, 120, 160, 255)), (170, 130, (140, 220, 255, 255))]:
        for k in range(16):
            a = k * math.pi / 8
            g.line([(cx + math.cos(a) * 12, cy + math.sin(a) * 12), (cx + math.cos(a) * 46, cy + math.sin(a) * 46)], fill=col, width=4)


fish_dir = "Godot/games/fish-rescue/assets/"
card("SS", (12, 10, 40), (60, 24, 96), [(art("asteroid_shatter.png"), (235, 70), 110), (art("ship_blue.png"), (110, 130), 130)])
card("MC", (246, 214, 150), (230, 160, 110), [(art("ball_green.png"), (150, 50), 64), (art("ball_orange.png"), (235, 90), 52), (art("basket_green.png"), (130, 135), 150)])
card("PP", (16, 70, 80), (10, 40, 60), extra=pong)
card("TT", (170, 224, 246), (230, 244, 252), [(art("tuktuk.png"), (160, 110), 190), (art("wheel.png"), (110, 168), 40), (art("wheel.png"), (214, 168), 40)])
card("DC", (20, 16, 60), (60, 30, 100), [(art("flare.png"), (210, 90), 150), (art("gem.png"), (210, 90), 80), (art("catcher_0.png"), (100, 140), 90)])
card("TW", (170, 120, 70), (120, 80, 45), [(art("crumbs.png"), (170, 115), 170), (art("sponge.png"), (235, 70), 110)])
card("FR", (8, 70, 110), (4, 30, 60), [(Image.open(fish_dir + "fish.png").convert("RGBA"), (205, 90), 90), (Image.open(fish_dir + "shark.png").convert("RGBA"), (110, 130), 130)])
card("BS", (22, 22, 64), (40, 40, 100), extra=bubble)
card("FW", (28, 14, 52), (70, 30, 80), extra=fireworks)
print("prepared", len(os.listdir(OUT)), "files")
