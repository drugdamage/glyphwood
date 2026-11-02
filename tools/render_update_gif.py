"""Render the 0.14.0 editorial overview using exported repository pixel art.

python tools/render_update_gif.py /tmp/glyphwood-art
Requires Pillow. This is an update illustration, not a gameplay recording.
"""
from pathlib import Path
import math
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ART = Path(sys.argv[1])
W, H = 960, 540
BG = (12, 15, 22)
INK = (226, 225, 216)
MUTED = (139, 149, 159)
GOLD = (219, 177, 107)
COLORS = [(145, 169, 136), (193, 177, 148), (220, 122, 85),
          (132, 168, 106), (164, 157, 207), (146, 195, 217)]
FONT = ROOT / 'fonts/DejaVuSansMono.ttf'
BOLD = ROOT / 'fonts/DejaVuSansMono-Bold.ttf'
FONTS = {}


def font(size, bold=False):
    key = (size, bold)
    if key not in FONTS:
        FONTS[key] = ImageFont.truetype(str(BOLD if bold else FONT), size)
    return FONTS[key]


def text(d, xy, value, size=18, color=INK, bold=False):
    d.text(xy, value, fill=color, font=font(size, bold))


def center(d, y, value, size=18, color=INK, bold=False, x=W // 2):
    box = d.textbbox((0, 0), value, font=font(size, bold))
    text(d, (int(x - (box[2] - box[0]) / 2), y), value, size, color, bold)


def diamond(d, x, y, size, color):
    d.polygon([(x, y-size), (x+size, y), (x, y+size), (x-size, y)], fill=color)


def sprite(im, item, center_xy, scale=5, rotate=False):
    art = Image.open(ART / (item + '.png')).convert('RGBA')
    if rotate:
        art = art.rotate(45, resample=Image.Resampling.NEAREST, expand=True)
    art = art.resize((art.width * scale, art.height * scale), Image.Resampling.NEAREST)
    im.paste(art, (int(center_xy[0] - art.width/2), int(center_xy[1] - art.height/2)), art)


def base(page, frame):
    im = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(im)
    # Quiet architectural frame, with sparse glyph stars.
    d.rectangle((18, 18, W-19, H-19), outline=(56, 61, 67))
    d.line((40, 76, W-40, 76), fill=(56, 61, 67))
    for x in (18, W-19):
        for y in (18, H-19):
            diamond(d, x, y, 4, GOLD)
    text(d, (42, 33), 'GLYPHWOOD', 23, INK, True)
    text(d, (668, 39), '0.14.0 / THE DESCENT', 16, GOLD)
    for i in range(24):
        x = 34 + (i * 137) % 884
        y = 95 + (i * 73) % 390
        b = 28 + int(10 * math.sin(frame / 10 + i))
        d.point((x, y), fill=(b, b+3, b+8))
    text(d, (42, 498), 'ANIMATED UPDATE OVERVIEW', 12, MUTED)
    text(d, (634, 498), 'PIXEL ART FROM THE GAME', 12, MUTED)
    for i in range(3):
        d.rectangle((439 + i*30, 504, 457 + i*30, 507), fill=GOLD if page == i else (54, 60, 67))
    return im, d


def fragments(t):
    im, d = base(0, t)
    text(d, (48, 99), '01 / DISCOVER', 14, GOLD)
    text(d, (48, 127), 'Find the pieces. Restore the blueprint.', 27, INK, True)
    text(d, (48, 172), 'Local chests: 1 fragment. Hidden chests: 2.', 17, MUTED)
    d.rectangle((50, 220, 383, 458), fill=(20, 26, 33), outline=(61, 74, 80))
    # Stylized chest is clearly illustration, paired with the actual saber sprite.
    d.rectangle((112, 300, 260, 360), fill=(84, 59, 43), outline=(184, 139, 81), width=3)
    d.rectangle((112, 279, 260, 306), fill=(105, 73, 46), outline=(184, 139, 81), width=3)
    for x in (130, 236):
        d.rectangle((x, 281, x+8, 358), fill=(177, 141, 91))
    d.rectangle((178, 300, 194, 321), fill=GOLD)
    center(d, 404, 'CHESTS & SECRETS', 15, MUTED, x=217)
    count = min(3, t // 13)
    for i in range(3):
        x = 335 + i*63
        y = 326 - int(14 * math.sin(t / 6 + i))
        diamond(d, x, y, 9, GOLD if count > i else (57, 66, 76))
    d.rectangle((550, 220, 909, 458), fill=(20, 26, 33), outline=GOLD if count == 3 else (61, 74, 80))
    sprite(im, 'glyph_saber', (647, 302), 4, True)
    text(d, (735, 263), f'{count} / 3', 30, GOLD, True)
    text(d, (735, 309), 'FRAGMENTS', 12, MUTED)
    center(d, 376, 'GLYPH SABER', 21, INK, True, x=730)
    center(d, 414, 'PURCHASE UNLOCKED' if count == 3 else 'BLUEPRINT IN PROGRESS', 14,
           GOLD if count == 3 else MUTED, x=730)
    return im


def collections(t):
    im, d = base(1, t)
    text(d, (48, 99), '02 / TRADE', 14, GOLD)
    text(d, (48, 127), 'Six biomes. Six distinct collections.', 27, INK, True)
    names = ['GRAVEWOOD', 'OSSUARY', 'ASHEN ABYSS', 'GALLOWS MIRE', 'CATHEDRAL', 'FROSTBOUND CRYPT']
    weapons = ['glyph_saber', 'hollow_spear', 'ember_brand', 'widow_fangs', 'bell_halberd', 'frost_brand']
    for i, (name, weapon, color) in enumerate(zip(names, weapons, COLORS)):
        x = 48 + i*146
        focus = (t // 9) % 6 == i
        d.rectangle((x, 202, x+134, 321), fill=(22, 28, 35), outline=color if focus else (48, 55, 62), width=2)
        d.rectangle((x+1, 203, x+133, 206), fill=color)
        sprite(im, weapon, (x+67, 254), 2, True)
        center(d, 296, name, 11, color, x=x+67)
    text(d, (48, 351), 'FOUR NEW ARMOUR OPTIONS', 16, GOLD)
    armor = [('cinder_veil', 'Cinder Veil', 'Ink gain'), ('marsh_wrap', 'Marsh Wrap', 'Speed + crit'),
             ('choir_hood', 'Choir Hood', 'Crit + ink'), ('rime_mail', 'Rime Mail', 'Dash recovery')]
    for i, (item, name, perk) in enumerate(armor):
        x = 48 + i*220
        sprite(im, item, (x+28, 421), 4)
        text(d, (x+63, 394), name, 15, INK, True)
        text(d, (x+63, 423), perk, 12, MUTED)
    return im


def routes(t):
    im, d = base(2, t)
    text(d, (48, 99), '03 / KEEP DESCENDING', 14, GOLD)
    text(d, (48, 127), 'After the final biome, choose your route.', 26, INK, True)
    text(d, (48, 170), 'One shorter floor. Mixed foes. One guardian. No hero reset.', 16, MUTED)
    start = (480, 236)
    selected = min(2, t // 20)
    options = [('ELITE HUNT', '+40% kill shards', 'More elite enemies', COLORS[2]),
               ('RESTLESS', '+30% kill shards', 'Faster ordinary foes', COLORS[4]),
               ('RELIC TRAIL', '+1 fragment / chest', 'Restore more blueprints', COLORS[5])]
    for i, (name, reward, desc, color) in enumerate(options):
        x = 48 + i*299
        cx = x+132
        d.line((start, (cx, 282)), fill=color if i == selected else (58, 65, 74), width=2)
        d.rectangle((x, 283, x+265, 443), fill=(22, 28, 35), outline=color if i == selected else (51, 59, 68), width=2)
        center(d, 304, name, 20, color, True, x=cx)
        center(d, 348, reward, 16, INK, x=cx)
        center(d, 389, desc, 13, MUTED, x=cx)
        if i == selected:
            phase = (t % 20) / 19
            diamond(d, int(start[0] + (cx-start[0])*phase), int(236+46*phase), 5, GOLD)
    diamond(d, *start, 9, GOLD)
    return im


frames = []
for render in (fragments, collections, routes):
    for t in range(60):
        frames.append(render(t).quantize(colors=96, method=Image.Quantize.MEDIANCUT))
out = ROOT / 'docs/expeditions.gif'
frames[0].save(out, save_all=True, append_images=frames[1:], duration=85, loop=0, optimize=True, disposal=2)
# Contact sheet for local review, separate from the committed GIF.
contact = Image.new('RGB', (W, H*3))
for i, idx in enumerate((50, 90, 170)):
    contact.paste(frames[idx].convert('RGB'), (0, i*H))
contact.save(ART / 'contact.png')
print(f'{out}: {len(frames)} frames, {out.stat().st_size:,} bytes')
