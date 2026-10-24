"""Cuts Ned out of book page 8 (holding folded clothes) and makes his round badge.
Usage: python ned_art.py "/path/to/Lola - FINAL.pdf"   (needs pymupdf, pillow, numpy, scipy)"""
import os, sys
import numpy as np, pymupdf
from PIL import Image, ImageDraw
from scipy import ndimage

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../assets/ui') + '/'
doc = pymupdf.open(sys.argv[1])
pix = pymupdf.Pixmap(doc, doc[7].get_images()[0][0])
if pix.n - pix.alpha > 3:
    pix = pymupdf.Pixmap(pymupdf.csRGB, pix)
page = Image.frombytes('RGB', (pix.width, pix.height), pix.samples)
W, H = page.size
c = np.asarray(page.crop((int(.10 * W), int(.20 * H), int(.42 * W), int(.74 * H)))).astype(float)
bgc = np.median(c[:20, :20].reshape(-1, 3), 0)
dist = np.sqrt(((c - bgc) ** 2).sum(2))
near = dist < 38
lab, n = ndimage.label(near)
sizes = ndimage.sum(near, lab, range(1, n + 1))
edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
bg = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if (i + 1 in edge) or s > 400])
band = ndimage.binary_dilation(bg, iterations=2)
soft = np.clip((dist - 10) / 40, 0, 1)
a = np.where(bg, 0.0, 1.0)
a = np.where(band & ~bg, np.maximum(a * soft, soft), a)
A = a[..., None]
rgb = np.where(A > 0.05, (c - bgc * (1 - A)) / np.maximum(A, 0.05), c).clip(0, 255)
ned = Image.fromarray(np.dstack([rgb, a * 255]).astype(np.uint8), 'RGBA')
ned = ned.crop(ned.getbbox())
ned.resize((int(ned.width * 1000 / ned.height), 1000), Image.LANCZOS).save(OUT + 'ned_full.png', optimize=True)

head = ned.crop((0, 0, 470, 560))
side = 620
card = Image.new('RGBA', (side, side), (209, 201, 212, 255))
card.alpha_composite(head, ((side - 470) // 2 + 20, 70))
card = card.resize((1024, 1024), Image.LANCZOS)
mask = Image.new('L', (1024, 1024), 0); ImageDraw.Draw(mask).ellipse((24, 24, 1000, 1000), fill=255)
badge = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0)); badge.paste(card, (0, 0), mask)
ImageDraw.Draw(badge).ellipse((20, 20, 1004, 1004), outline=(38, 26, 46, 255), width=26)
badge.resize((256, 256), Image.LANCZOS).save(OUT + 'ned_badge.png')
print('wrote ned_full.png and ned_badge.png')
