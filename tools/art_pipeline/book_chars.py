"""Cuts Lola and Ned out of the book's Procreate pages (clean layers, no page background).
Usage:
  for n in 2 7 10 16 28 36; do mkdir -p book/$n && unzip -o ~/Downloads/$n.procreate -x 'video/*' -d book/$n; done
  ./venv/bin/python book_chars.py
Writes assets/ui: lola_{worried,happy,joy}.png (round portraits), ned_wave.png (Ned waving,
cut off at the bottom so he pops up from the screen edge), ned_full.png (Ned holding folded
clothes, for the folding close-up), ned_badge.png and grandpa_badge.png."""
import os
from PIL import Image, ImageDraw
from procreate import Page, to_img

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../assets/ui') + '/'
INK = (38, 26, 46, 255)
BADGE_BG = (205, 188, 226, 255)


def cut(n, keep):
    """Composites the chosen layers of book page n into a tightly cropped RGBA image."""
    im = to_img(Page(f'book/{n}').composite(keep))
    return im.crop(im.getbbox())


def badge(im, size, top=0.0, zoom=1.0, dx=0.0):
    """Round portrait: the character's head and shoulders on a soft lavender disc."""
    k = 4; n = size * k
    side = im.width / zoom
    crop = im.crop((int((im.width - side) / 2 + dx * im.width), int(top * im.height),
                    int((im.width + side) / 2 + dx * im.width), int(top * im.height + side)))
    crop = crop.resize((n, n), Image.LANCZOS)
    card = Image.new('RGBA', (n, n), BADGE_BG); card.alpha_composite(crop)
    mask = Image.new('L', (n, n), 0); ImageDraw.Draw(mask).ellipse((6 * k, 6 * k, n - 6 * k, n - 6 * k), fill=255)
    out = Image.new('RGBA', (n, n), (0, 0, 0, 0)); out.paste(card, (0, 0), mask)
    ImageDraw.Draw(out).ellipse((5 * k, 5 * k, n - 5 * k, n - 5 * k), outline=INK, width=7 * k)
    return out.resize((size, size), Image.LANCZOS)


def save_h(im, path, h):
    im.resize((round(im.width * h / im.height), h), Image.LANCZOS).save(path, optimize=True)


# ---- Lola: worried (page 10, "Where?"), happy (page 2, "Lola loves purple"), joy (page 28, the ring) ----
badge(cut(10, {3, 4, 5, 8, 10, 11, 12, 13}), 384, top=0.0, zoom=1.2, dx=0.03).save(OUT + 'lola_worried.png', optimize=True)
badge(cut(2, {0, 1, 2, 4, 5, 6, 7, 8, 9}), 384, top=0.0, zoom=1.05).save(OUT + 'lola_happy.png', optimize=True)
badge(cut(28, set(range(20, 33))), 384, top=0.04, zoom=1.0).save(OUT + 'lola_joy.png', optimize=True)

# ---- Ned waving from the last page: he pops up from the bottom of the screen with tips ----
wave = cut(36, {13, 14, 15, 16, 17})
save_h(wave, OUT + 'ned_wave.png', 900)
badge(cut(36, {14, 15, 16, 17}), 256, top=-0.08, zoom=0.78).save(OUT + 'ned_badge.png', optimize=True)

# ---- Ned holding folded clothes ("to help fold and clean and make her bed") for the folding close-up ----
save_h(cut(7, {0, 1, 2, 3, 4, 5}), OUT + 'ned_full.png', 1000)

# ---- Grandpa at the dinner table (page 16), for his lines in the story ----
badge(cut(16, {6}), 256, top=-0.04, zoom=0.95).save(OUT + 'grandpa_badge.png', optimize=True)
print('wrote lola_*.png, ned_wave.png, ned_full.png, ned_badge.png, grandpa_badge.png')
