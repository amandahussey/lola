from PIL import Image
from lib import *
import numpy as np
def make_cup_full():
    """Procreate pencil cup (2 pencils) + Lola's tidied pencil standing in the middle,
    like the fanned pencils on the book's clean-room page."""
    cup = to_img(composite([92]))
    pen = to_img(composite([94])); b = bbox(94); pen = pen.crop(b)
    pen = pen.rotate(-72, expand=True, resample=Image.BICUBIC)
    a = np.asarray(pen)[..., 3]; ys, xs = np.nonzero(a > 10)
    pen = pen.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    top_y, cx = 1584, 4247
    x0 = int(cx - pen.width / 2); y0 = top_y
    layer = Image.new('RGBA', cup.size, (0, 0, 0, 0)); layer.alpha_composite(pen, (x0, y0))
    L = np.asarray(layer).copy()
    # hide the part of the pencil that is inside the cup (below the front rim)
    rcx, rcy, rx, ry = 4245, 1650, 35, 13
    yy, xx = np.mgrid[0:DH, 0:DW]
    t = np.clip(1 - ((xx - rcx) / rx) ** 2, 0, 1)
    rim = rcy + ry * np.sqrt(t) - 1
    L[..., 3] = np.where((yy < rim) | (np.abs(xx - rcx) > rx + 6) & (yy < rcy), L[..., 3], 0)
    out = cup.copy(); out.alpha_composite(Image.fromarray(L))
    return out
if __name__ == '__main__':  # preview
    im = make_cup_full().crop((4170, 1560, 4320, 1760)).resize((450, 600), Image.LANCZOS)
    bg = Image.new('RGBA', im.size, (130, 100, 85, 255)); bg.alpha_composite(im); bg.save('cup_full_test.png')
