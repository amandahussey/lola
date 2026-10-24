"""Reads a book page's unzipped .procreate folder: its layers (bottom first) as premultiplied
RGBA arrays turned the way the page is shown, plus its background colour.
Text layers are flagged so the game can draw the words itself (and read them aloud)."""
import os, plistlib, struct
import numpy as np
from PIL import Image
from dec import bv41

# the ways a page can be turned relative to how Procreate stores its tiles
TURNS = [lambda a: a.transpose(1, 0, 2), lambda a: a.transpose(1, 0, 2)[::-1, ::-1],
         lambda a: a, lambda a: a[::-1, ::-1]]


class Page:
    def __init__(self, folder):
        self.folder = folder
        d = plistlib.load(open(folder + '/Document.archive', 'rb')); O = d['$objects']
        R = lambda x: O[x.data] if isinstance(x, plistlib.UID) else x
        top = R(d['$top']['root'])
        self.W, self.H = map(int, R(top['size']).strip('{}').split(','))
        self.T = int(R(top['tileSize']))
        self.bg = list(struct.unpack('<4f', R(top['backgroundColor'])))[:3]
        self.layers = []
        for l in reversed([R(u) for u in R(top['layers'])['NS.objects']]):
            text = R(l.get('text'))
            self.layers.append(dict(uuid=R(l['UUID']), name=R(l['name']) if 'name' in l else '',
                                    hidden=bool(R(l['hidden'])), opacity=float(R(l['opacity'])),
                                    text=text is not None and text != '$null'))
        self.turn = self._find_turn()

    def raw(self, i):
        W, H, T = self.W, self.H, self.T
        img = np.zeros((H, W, 4), np.uint8); folder = self.folder + '/' + self.layers[i]['uuid']
        if os.path.isdir(folder):
            for f in os.listdir(folder):
                if not f.endswith('.lz4'): continue
                c, r = map(int, f[:-4].split('~'))
                a = np.frombuffer(bv41(open(folder + '/' + f, 'rb').read()), np.uint8)
                tw, th = min(T, W - c * T), min(T, H - r * T)
                img[r * T:r * T + th, c * T:c * T + tw] = (a.reshape(T, T, 4)[:th, :tw] if len(a) == T * T * 4
                                                           else a.reshape(th, tw, 4))
        return img

    def layer(self, i):
        return np.ascontiguousarray(TURNS[self.turn](self.raw(i)))

    def _find_turn(self):
        """Picks the turn whose composite looks most like Procreate's own thumbnail."""
        acc = None
        for i, l in enumerate(self.layers):
            if l['hidden']: continue
            s = self.raw(i).astype(np.float32) / 255 * l['opacity']
            acc = s if acc is None else s + acc * (1 - s[..., 3:4])
        thumb = Image.open(self.folder + '/QuickLook/Thumbnail.png').convert('RGB')
        best = None
        for k, f in enumerate(TURNS):
            c = f(acc)
            if abs(c.shape[1] / c.shape[0] - thumb.width / thumb.height) > 0.02: continue
            rgb = np.clip(c[..., :3] + np.array(self.bg) * (1 - c[..., 3:4]), 0, 1)
            im = Image.fromarray((rgb * 255).astype(np.uint8)).resize(thumb.size)
            e = np.abs(np.asarray(im, float) - np.asarray(thumb, float)).mean()
            if best is None or e < best[0]: best = (e, k)
        return best[1]

    def composite(self, idxs):
        acc = None
        for i in sorted(idxs):
            s = self.layer(i).astype(np.float32) / 255 * self.layers[i]['opacity']
            acc = s if acc is None else s + acc * (1 - s[..., 3:4])
        return acc


def to_img(acc):
    a = acc[..., 3:4]
    return Image.fromarray((np.dstack([(acc[..., :3] / np.maximum(a, 1e-4)).clip(0, 1), a]) * 255).astype(np.uint8), 'RGBA')
