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
    # spazio libero = rettangolo che contiene il parallelogramma interno; inner_shear = di quanto
    # e' obliquo il riempimento (in basso a sinistra parte da x0, in alto finisce a x0 + larghezza)
    x0 = int(round(fx + (H - 1 - fy - fh) * SHEAR))
    inner = int(round(fh * SHEAR))
    new = name + "_slant"
    out.save(os.path.join(OUT, new + ".png"))
    info[new] = {"size": [W + d, H], "slice": sl, "free_rect": [x0, fy, fw + inner, fh], "shear_px": inner,
                 "note": "barra a parallelogramma: il riempimento e' obliquo di shear_px (pixel del PNG 2x)"}

def fix_panel(name):
    # fessura trasparente fra la cornice e il fondo carbone (20 px nel PNG 2x): dentro i pannelli
    # si vedeva lo scenario fra il bordo e il fondo (Mirko 16/10, statistiche del profilo)
    im = Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")
    W, H = im.size
    px = im.load()
    fill = px[W // 2, H // 2]
    seen = set()
    q = deque([(W // 2, H // 2)])
    while q:
        x, y = q.popleft()
        if (x, y) in seen:
            continue
        if x <= 0 or y <= 0 or x >= W - 1 or y >= H - 1:
            raise SystemExit("il riempimento esce dalla cornice: " + name)
        p = px[x, y]
        if not (p[3] < 40 or p[:3] == fill[:3]):
            continue
        seen.add((x, y))
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    n = 0
    for (x, y) in seen:
        if px[x, y][3] < 255:
            a = px[x, y][3]
            if a < 40:
                n += 1
            px[x, y] = fill
    im.save(os.path.join(OUT, name + ".png"))
    info[name] = {"size": [W, H], "slice": [112, 112, 112, 112], "free_rect": [87, 107, 626, 388],
                  "note": "fondo carbone fino alla cornice (%d pixel riempiti)" % n}

fix_panel("frame_panel")
for n in ("frame_tab_normal", "frame_tab_hover", "frame_tab_selected"):
    fix_tab(n)
man = json.load(open(os.path.join(SRC, "..", "manifest.json")))
def inner_x(name):
    # interno VERO della barra a meta' altezza (il free_rect del manifest di Codex e' prudente:
    # 51..589 contro 16..623 della salute, e il riempimento si fermava prima dei terminali)
    im = Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")
    W, H = im.size
    y = H // 2
    a = [im.getpixel((x, y))[3] > 60 for x in range(W)]
    l = next(x for x in range(W // 2, 0, -1) if a[x]) + 1
    r = next(x for x in range(W // 2, W) if a[x]) - 1
    return l + 6, r - 6

for n in ("frame_bar_health", "frame_bar_stamina", "frame_bar_shield", "frame_bar_xp"):
    e = man["assets"][n]
    fx, fy, fw, fh = e["free_rect"]
    l, r = inner_x(n)
    info[n] = {"size": e["size"], "free_rect_vero": [l, fy, r - l + 1, fh], "note": "solo misure (PNG di Codex invariato)"}
    slant(n, e["slice"], [l, fy, r - l + 1, fh])
json.dump(info, open(os.path.join(OUT, "manifest.json"), "w"), indent=2)
print(json.dumps(info, indent=1))
