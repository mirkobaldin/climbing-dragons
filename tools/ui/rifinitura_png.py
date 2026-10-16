# Genera i PNG della rifinitura UI (17/10) dai PNG di Codex (artifacts/ui-cornici-20261016/png):
#  - frame_tab_*: fondo interno uniforme (il PNG originale aveva un gradino di colore proprio dove
#    comincia il margine 9-slice destro: allungando la scheda il fondo sembrava "tagliato")
#  - frame_bar_*_slant: barre a parallelogramma (shear orizzontale, in alto piu' lunghe a destra)
# Uso: python3 tools/ui/rifinitura_png.py   -> artifacts/ui-rifinitura-20261017/
import json, os, sys
from collections import deque
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "artifacts", "ui-cornici-20261016", "png")
OUT = os.path.join(ROOT, "artifacts", "ui-rifinitura-20261017")
os.makedirs(OUT, exist_ok=True)
info = {}

def lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]

def fix_tab(name):
    im = Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")
    W, H = im.size
    px = im.load()
    # colore del fondo per ogni riga, dal tratto centrale (quello che si allunga)
    def ok(p):
        return p[3] > 200 and 14 <= lum(p) <= 62 and abs(p[0] - p[2]) < 14
    seen = set()
    q = deque([(W // 2, H // 2)])
    while q:
        x, y = q.popleft()
        if (x, y) in seen or x < 8 or y < 4 or x >= W - 4 or y >= H - 4:
            continue
        if not ok(px[x, y]):
            continue
        seen.add((x, y))
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    rows = {}
    for (x, y) in seen:
        if 150 <= x <= 420:
            rows.setdefault(y, []).append(px[x, y])
    mean = {}
    for y, ps in rows.items():
        n = len(ps)
        mean[y] = tuple(int(sum(p[i] for p in ps) / n) for i in range(3))
    # trama leggera: si tiene meta' della variazione del tratto centrale (ripetuto), non il gradino
    out = im.copy()
    op = out.load()
    for (x, y) in seen:
        m = mean.get(y)
        if not m:
            continue
        sx = 150 + (x - 150) % 270  # stessa trama del centro
        sp = px[sx, y] if (sx, y) in seen else m
        op[x, y] = tuple(int(m[i] + (sp[i] - m[i]) * 0.5) for i in range(3)) + (px[x, y][3],)
    out.save(os.path.join(OUT, name + ".png"))
    info[name] = {"size": [W, H], "slice": [109, 38, 109, 38], "note": "fondo interno uniforme"}

SHEAR = 0.55  # spostamento orizzontale per pixel di altezza (circa 29 gradi)

def slant(name, base_slice, base_free):
    im = Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")
    W, H = im.size
    d = int(round(H * SHEAR))
    out = Image.new("RGBA", (W + d, H), (0, 0, 0, 0))
    # shear: la riga y si sposta a destra di (H-1-y)*SHEAR (in alto piu' a destra)
    sheared = im.transform((W + d, H), Image.AFFINE, (1, SHEAR, -SHEAR * (H - 1), 0, 1, 0), resample=Image.BICUBIC)
    out.alpha_composite(sheared)
    # i lati verticali dei terminali diventano obliqui: i margini 9-slice comprendono l'obliquo
    l, t, r, b = base_slice
    sl = [l + d, t, r + d, b]
    fx, fy, fw, fh = base_free
    new = name + "_slant"
    out.save(os.path.join(OUT, new + ".png"))
    info[new] = {"size": [W + d, H], "slice": sl, "free_rect": [fx + d // 2, fy, fw, fh], "shear_px": d,
                 "note": "barra a parallelogramma: il riempimento e' obliquo di shear_px (pixel del PNG 2x)"}

for n in ("frame_tab_normal", "frame_tab_hover", "frame_tab_selected"):
    fix_tab(n)
man = json.load(open(os.path.join(SRC, "..", "manifest.json")))
for n in ("frame_bar_health", "frame_bar_stamina", "frame_bar_shield", "frame_bar_xp"):
    e = man["assets"][n]
    slant(n, e["slice"], e["free_rect"])
json.dump(info, open(os.path.join(OUT, "manifest.json"), "w"), indent=2)
print(json.dumps(info, indent=1))
