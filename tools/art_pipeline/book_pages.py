"""Rebuilds the storybook pages from the book's Procreate files, split into parts that the
game can animate (Lola, Ned, the diamond, the bucket...). Everything not named in PAGES is
part of the page's background. Text layers are skipped: the game shows (and narrates) the
words itself, so caption boxes and speech bubbles are dropped too.
Usage:
  for n in 2 3 4 ... 36; do mkdir -p book/$n && unzip -o ~/Downloads/$n.procreate -x 'video/*' -d book/$n; done
  ./venv/bin/python book_pages.py            # or: book_pages.py 13 14  (just those pages)
Writes assets/story/pages/<page>/<part>.png and assets/story/pages/pages.json."""
import json, os, sys
import numpy as np
from PIL import Image
from procreate import Page, to_img

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../assets/story/pages') + '/'
HEIGHT = 1300  # every page is drawn this many pixels tall

r = lambda a, b: list(range(a, b + 1))
# page: {'parts': {name: [layer numbers, counted up from the bottom]}, 'drop': [caption boxes, bubbles...],
#        'key': [parts painted on a flat background colour, which gets cut away]}
PAGES = {
    2: {'parts': {'lola': r(0, 9), 'hearts': [15, 16, 17]}, 'drop': [11, 13, 14]},
    3: {'drop': [1]},
    4: {'drop': [1, 2, 3]},
    5: {'parts': {'tornado': [1]}, 'drop': [2], 'key': ['tornado']},
    6: {'parts': {'tornado': [1], 'notebook': [2], 'butterfly': [3], 'ball': [6, 7]}, 'drop': [4], 'key': ['tornado']},
    7: {'parts': {'ned': r(0, 5)}},
    8: {'parts': {'mirror': [1], 'reflection': [2], 'ned': [3, 4], 'rag': [5], 'lights': [6]}},
    9: {'parts': {'ned': [0, 1], 'duck': [2, 3]}},
    10: {'parts': {'where': [0, 1, 2], 'lola': [3, 4, 5, 8, 10, 11, 12, 13]}},
    11: {'parts': {'b': [1], 'o': [2]}},
    12: {'parts': {'n': [3], 'k': [2], 'bang': [1]}},
    13: {'parts': {'ned': [1, 2, 3, 4, 5, 8, 9, 10], 'bucket': [6, 7, 12], 'lola': [11] + r(13, 23),
                   'diamond': [24, 25, 26, 29], 'dizzy': [28]}},
    14: {'parts': {'lola': r(1, 11), 'drops': [12], 'ring': [13, 14, 16, 17, 18, 19]}, 'drop': [23]},
    15: {'parts': {'lola': [2, 4], 'ned': [7]}, 'drop': [12, 13]},
    16: {'parts': {'grandpa': [6], 'bread': [57], 'ned': r(66, 75), 'lola': r(81, 100)}},
    17: {'drop': [1]},
    18: {'parts': {'lola': r(1, 15), 'ned': r(22, 36)}, 'drop': [16, 18, 19]},
    19: {'drop': [35]},
    20: {'parts': {'lola': r(9, 33), 'ned': r(38, 52)}, 'drop': [1, 3, 4, 5, 6, 34]},
    21: {'drop': [33]},
    22: {'parts': {'ned': [1]}},
    23: {'parts': {'lola': r(9, 16), 'sigh': [7, 8]}},
    24: {'parts': {'ned': r(0, 13), 'lola': r(18, 34)}, 'drop': [14, 16, 37, 40, 41, 42, 43, 49]},
    25: {'drop': [28]},
    26: {'parts': {'ned': [1]}},
    27: {'parts': {'shimmer': r(2, 17)}},
    28: {'parts': {'lola': r(20, 32)}},
    29: {'parts': {'diamond': [17], 'shine': [18]}, 'drop': [19]},
    30: {'parts': {'sparkles': r(7, 12)}},
    31: {},
    32: {'parts': {'almost': [1, 2]}},
    33: {},
    34: {'parts': {'ned': [1, 2, 3, 5, 6, 7, 8, 9, 10, 21], 'lola': [4] + r(11, 20)}},
    35: {},
    36: {'parts': {'lola': r(1, 11), 'ned': r(13, 17)}},
}


def key_out(acc):
    """Cuts away the flat colour a part was painted on (the colour along its edges)."""
    a = acc[..., 3:4]
    rgb = acc[..., :3] / np.maximum(a, 1e-4)
    edge = np.concatenate([acc[0], acc[-1], acc[:, 0], acc[:, -1]])
    edge = edge[edge[:, 3] > 0.5]
    fill = np.median(edge[:, :3] / edge[:, 3:4], 0)
    dist = np.sqrt(((rgb - fill) ** 2).sum(2))[..., None]
    keep = np.clip((dist - 0.04) / 0.1, 0, 1) * a
    return np.dstack([rgb * keep, keep])


def export(n, spec):
    page = Page(f'book/{n}')
    labels = {}
    for name, idxs in spec.get('parts', {}).items():
        for i in idxs: labels[i] = name
    drop = set(spec.get('drop', []))
    groups = {}   # name -> layer numbers
    base_run = -1; prev = None
    for i, l in enumerate(page.layers):
        if l['hidden'] or l['text'] or i in drop or l['name'] == 'Divider': continue
        name = labels.get(i)
        if name is None:
            if prev is None or not prev.startswith('base'):
                base_run += 1
            name = f'base{base_run}'
        groups.setdefault(name, []).append(i)
        prev = name
    first = page.layer(0)
    H, W = first.shape[:2]
    s = HEIGHT / H
    os.makedirs(f'{OUT}{n}', exist_ok=True)
    for f in os.listdir(f'{OUT}{n}'):
        if f.endswith('.png'): os.remove(f'{OUT}{n}/{f}')
    parts = []
    for name, idxs in sorted(groups.items(), key=lambda g: max(g[1])):
        acc = page.composite(idxs)
        if name in spec.get('key', []):
            acc = key_out(acc)
        a = acc[..., 3] > 0.01
        ys = np.nonzero(a.any(1))[0]; xs = np.nonzero(a.any(0))[0]
        if not len(xs): continue
        x0, y0, x1, y1 = max(0, xs[0] - 3), max(0, ys[0] - 3), min(W, xs[-1] + 4), min(H, ys[-1] + 4)
        im = to_img(acc[y0:y1, x0:x1]).resize((max(1, round((x1 - x0) * s)), max(1, round((y1 - y0) * s))), Image.LANCZOS)
        im.save(f'{OUT}{n}/{name}.png', optimize=True)
        parts.append({'part': name, 'tex': f'res://assets/story/pages/{n}/{name}.png',
                      'pos': [round((x0 + x1) / 2 * s, 1), round((y0 + y1) / 2 * s, 1)]})
    return {'size': [round(W * s), HEIGHT], 'bg': [round(c, 4) for c in page.bg], 'chunks': parts}


if __name__ == '__main__':
    path = OUT + 'pages.json'
    data = json.load(open(path)) if os.path.exists(path) else {}
    todo = [int(a) for a in sys.argv[1:]] or list(PAGES)
    for n in todo:
        data[str(n)] = export(n, PAGES[n])
        print(n, [c['part'] for c in data[str(n)]['chunks']])
    os.makedirs(OUT, exist_ok=True)
    json.dump(dict(sorted(data.items(), key=lambda kv: int(kv[0]))), open(path, 'w'), indent=1)
