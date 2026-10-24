import json, os, numpy as np
from PIL import Image, ImageDraw, ImageFilter
from lib import *
from items import ITEMS, EXCLUDE, OFF_FLOOR, BED_MESSY, BED_MADE, BED_POSTS, BED_BAND, FLOWER_PILLOW, TEDDY_SHIFT
from cupfull import make_cup_full

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../assets/room') + '/'
S = 0.75
os.makedirs(OUT + '/items', exist_ok=True)
os.makedirs(OUT + '/closeup', exist_ok=True)
os.makedirs(OUT + '/overlays', exist_ok=True)
for f in os.listdir(OUT + '/overlays'):
    if f.endswith('.png'): os.remove(OUT + '/overlays/' + f)

def sc(v): return round(float(v) * S, 1)

def save_crop(acc, bb, path, pad=4):
    x0, y0, x1, y1 = bb
    x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
    x1, y1 = min(DW, x1 + pad), min(DH, y1 + pad)
    im = to_img(acc[y0:y1, x0:x1])
    im = im.resize((max(1, round((x1 - x0) * S)), max(1, round((y1 - y0) * S))), Image.LANCZOS)
    im.save(path, optimize=True)
    return (x0, y0, x1, y1)

def alpha_bbox(acc):
    a = acc[..., 3] > 0.01
    ys = np.nonzero(a.any(1))[0]; xs = np.nonzero(a.any(0))[0]
    return (xs[0], ys[0], xs[-1] + 1, ys[-1] + 1)

used = {l for it in ITEMS for l in it[2]} | set(BED_MESSY + BED_MADE + BED_POSTS + BED_BAND + FLOWER_PILLOW)
statics = [i for i, (u, n, h, b) in enumerate(info) if not h and b and i not in used and i not in EXCLUDE]
statics = [i for i in statics if i != 24] + [25]   # clean dresser in background, sock becomes an item

# ---------- background ----------
bg = composite(statics)
im = to_img(bg)
bgw, bgh = round(DW * S), round(DH * S)
im.convert('RGB').resize((bgw, bgh), Image.LANCZOS).save(OUT + '/background.png', optimize=True)

# ---------- items ----------
manifest = {'room_size': [bgw, bgh], 'items': [], 'overlays': [], 'dests': {}}
masks = {}
for idx, (iid, kind, layers, dest) in enumerate(ITEMS):
    acc = composite(layers)
    bb = alpha_bbox(acc)
    x0, y0, x1, y1 = save_crop(acc, bb, f'{OUT}/items/{iid}.png')
    masks[iid] = (acc[..., 3] > 0.05, max(layers))
    entry = {'id': iid, 'kind': kind, 'dest': dest, 'z': int(max(layers)),
             'tex': f'res://assets/room/items/{iid}.png',
             'pos': [sc((x0 + x1) / 2), sc((y0 + y1) / 2)], 'floor': iid not in OFF_FLOOR}
    if kind == 'fold' and dest in ('dresser', 'bed_foot'):
        # full resolution copy for the close-up folding view
        x0c, y0c, x1c, y1c = bb
        to_img(acc[y0c:y1c, x0c:x1c]).save(f'{OUT}/closeup/{iid}.png', optimize=True)
        entry['closeup'] = f'res://assets/room/closeup/{iid}.png'
    manifest['items'].append(entry)

# dresser sock: pixels that differ between messy (24) and clean (25) dresser
a24, a25 = disp(24).astype(np.int16), disp(25).astype(np.int16)
diff = (np.abs(a24 - a25).sum(2) > 40)
diff = np.array(Image.fromarray(diff.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(5))) > 0
sock = disp(24).astype(np.float32) / 255 * diff[..., None]
bb = alpha_bbox(sock)
x0, y0, x1, y1 = save_crop(sock, bb, f'{OUT}/items/dresser_sock.png')
masks['dresser_sock'] = (sock[..., 3] > 0.05, 26)
manifest['items'].append({'id': 'dresser_sock', 'kind': 'tap', 'dest': 'tuck', 'z': 26,
    'tex': 'res://assets/room/items/dresser_sock.png', 'pos': [sc((x0 + x1) / 2), sc((y0 + y1) / 2)],
    'floor': False})

# ---------- the bed: unmade on top, the made bed (Bedroom_Cleanest) revealed underneath ----------
def sprite(layers, name, shift=(0, 0)):
    acc = composite(layers); bb = alpha_bbox(acc)
    x0, y0, x1, y1 = save_crop(acc, bb, f'{OUT}/{name}.png')
    return {'tex': f'res://assets/room/{name}.png',
            'pos': [sc((x0 + x1) / 2 + shift[0]), sc((y0 + y1) / 2 + shift[1])]}
os.makedirs(OUT + '/bed', exist_ok=True)
manifest['bed'] = {
    'messy': {**sprite(BED_MESSY, 'bed/unmade'), 'z': max(BED_MESSY)},
    'made': {**sprite(BED_MADE, 'bed/made'), 'z': 43},     # above the rumpled duvet, below the shirt
    'posts': {**sprite(BED_POSTS, 'bed/posts'), 'z': 45},  # below the throw blanket
}
# what tidied things turn into once they land: Mr. Teddy sitting up, the flower pillow
# propped next to him, the throw blanket folded across the foot of the bed
manifest['settle'] = {
    'teddy': {**sprite([89], 'bed/teddy', TEDDY_SHIFT), 'z': 60},
    'flower': {**sprite(FLOWER_PILLOW, 'bed/flower'), 'z': 58},
    'throw_blanket': {**sprite(BED_BAND, 'bed/band'), 'z': 44},
}

# ---------- front overlays: static layers drawn above an item they overlap ----------
for s in statics:
    m = disp(s)[..., 3] > 0.05
    if any(z < s and (m & mk).any() for mk, z in masks.values()):
        acc = composite([s]); bb = alpha_bbox(acc)
        x0, y0, x1, y1 = save_crop(acc, bb, f'{OUT}/overlays/layer_{s}.png')
        manifest['overlays'].append({'tex': f'res://assets/room/overlays/layer_{s}.png', 'z': int(s),
                                     'pos': [sc((x0 + x1) / 2), sc((y0 + y1) / 2)]})

# ---------- destinations (full-res coords -> scaled) ----------
D = {
    'dresser':    (1745, 1330), 'toybox': (2950, 1180), 'dollhouse': (3110, 1690),
    'trash':      (4420, 2230), 'pencil_cup': (4246, 1600),
}
manifest['dests'] = {k: [sc(x), sc(y)] for k, (x, y) in D.items()}
# containers bounce when something lands in them: [layer-ish bbox centre] for squash
manifest['bounce'] = {
    'dresser': [sc(1743), sc(1426)], 'toybox': [sc(2983), sc(1261)],
    'dollhouse': [sc(3116), sc(1687)], 'trash': [sc(4420), sc(2340)], 'pencil_cup': [sc(4246), sc(1667)],
}
# places where tidied things stay visible, by item id: [x, y, scale, rotation_deg]
SLOTS = {
    'coloring_book': (4060, 1665, 0.40, -10), 'notebook': (4060, 1625, 0.36, 6),
}
manifest['slots'] = {k: [sc(x), sc(y), s, r] for k, (x, y, s, r) in SLOTS.items()}
# ---------- props: containers that bounce when something lands in them ----------
os.makedirs(OUT + '/props', exist_ok=True)
PROPS = {'dresser': [25], 'toybox': [19, 20, 21, 22], 'dollhouse': [67, 69, 70],
         'trash': [104, 105], 'pencil_cup': [92]}
# pencil cup after Lola's pencil is put away (fanned pencils, like the book's clean room)
full = make_cup_full()
fa = np.asarray(full).astype(np.float32) / 255
fa = np.dstack([fa[..., :3] * fa[..., 3:4], fa[..., 3:4]])  # premultiplied like composite()
bb = alpha_bbox(fa)
x0, y0, x1, y1 = save_crop(fa, bb, f'{OUT}/props/pencil_cup_full.png')
cup_full = {'tex': 'res://assets/room/props/pencil_cup_full.png', 'bottom': [sc((x0 + x1) / 2), sc(y1)]}

# ---------- the dresser drawer that opens for folded clothes ----------
DRAWER = [(1518, 1322), (1733, 1282), (1736, 1376), (1524, 1414)]   # top-left drawer front
dm = Image.new('L', (DW, DH), 0); ImageDraw.Draw(dm).polygon(DRAWER, fill=255)
dacc = composite([25]) * (np.asarray(dm)[..., None] > 0)
bb = alpha_bbox(dacc)
x0, y0, x1, y1 = save_crop(dacc, bb, f'{OUT}/props/drawer_front.png', pad=0)
manifest['drawer'] = {'tex': 'res://assets/room/props/drawer_front.png',
                      'pos': [sc((x0 + x1) / 2), sc((y0 + y1) / 2)],
                      'quad': [[sc(x), sc(y)] for x, y in DRAWER],
                      'pull': [sc(42), sc(54)]}  # drawers slide out toward the viewer
manifest['props'] = {}
for name, layers in PROPS.items():
    acc = composite(layers); bb = alpha_bbox(acc)
    x0, y0, x1, y1 = save_crop(acc, bb, f'{OUT}/props/{name}.png')
    pm = acc[..., 3] > 0.05
    for iid, (mk, z) in masks.items():
        if z < max(layers) and (pm & mk).any(): print('  prop', name, 'covers lower item', iid)
    manifest['props'][name] = {'tex': f'res://assets/room/props/{name}.png', 'z': int(max(layers)),
                               'bottom': [sc((x0 + x1) / 2), sc(y1)]}
manifest['props']['pencil_cup']['full'] = cup_full
json.dump(manifest, open(OUT + '/manifest.json', 'w'), indent=1)
print(len(manifest['items']), 'items,', len(manifest['overlays']), 'overlays')
