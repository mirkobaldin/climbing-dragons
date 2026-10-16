# Anteprima della rifinitura UI (17/10): montaggio dell'HUD in alto a sinistra con le misure di
# client/HUD (layoutLeft) e i PNG di Codex + quelli nuovi, e confronto delle schede prima/dopo.
# Non e' uno screenshot di Roblox: serve solo a controllare proporzioni e attacchi delle cornici.
import json, os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
A = os.path.join(ROOT, "artifacts", "ui-cornici-20261016", "png")
N = os.path.join(ROOT, "artifacts", "ui-rifinitura-20261017")
K = 2  # pixel dell'anteprima per pixel logico (i PNG sono 2x)

def png(name):
    p = os.path.join(N, name + ".png")
    if not os.path.exists(p):
        p = os.path.join(A, name + ".png")
    return Image.open(p).convert("RGBA")

def nine(im, sl, w, h, s):
    """9-slice come Roblox: margini sl (pixel del PNG) scalati di s, centro stirato."""
    l, t, r, b = sl
    W, H = im.size
    L, T, R, B = [max(1, int(round(v * s))) for v in (l, t, r, b)]
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    xs = [(0, l, 0, L), (l, W - r, L, w - R), (W - r, W, w - R, w)]
    ys = [(0, t, 0, T), (t, H - b, T, h - B), (H - b, H, h - B, h)]
    for (sx0, sx1, dx0, dx1) in xs:
        for (sy0, sy1, dy0, dy1) in ys:
            if sx1 > sx0 and sy1 > sy0 and dx1 > dx0 and dy1 > dy0:
                out.alpha_composite(im.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0)), (dx0, dy0))
    return out

man = json.load(open(os.path.join(N, "manifest.json")))
base = json.load(open(os.path.join(ROOT, "artifacts", "ui-cornici-20261016", "manifest.json")))["assets"]

def para(draw, x, y, w, h, sl, color):
    draw.polygon([(x + sl, y), (x + w, y), (x + w - sl, y + h), (x, y + h)], fill=color)

def bar(canvas, draw, kind, x, y, w, h, ratio, color):
    """barra a parallelogramma nella cornice obliqua (UiKit.bar), misure logiche"""
    e = man["frame_bar_" + kind + "_slant"]
    fx, fy, fw, fh = e["free_rect"]
    s = h / fh
    sl = e["shear_px"] * s
    para(draw, (x) * K, y * K, w * K, h * K, sl * K, (20, 24, 34, 230))
    para(draw, x * K, y * K, (w * ratio + sl * (1 - ratio)) * K, h * K, sl * K, color)
    W, H = e["size"]
    l, t = fx * s, fy * s
    fr = nine(png("frame_bar_" + kind + "_slant"), e["slice"], int((w + (W - fw) * s) * K), int((h + (H - fh) * s) * K), s * K)
    canvas.alpha_composite(fr, (int((x - l) * K), int((y - t) * K)))

def circle_frame(canvas, name, x, y, d, key):
    e = base[name]
    c = e["free_circle"]
    k = d / c["diameter"]
    im = png(name).resize((int(e["size"][0] * k * K), int(e["size"][1] * k * K)))
    canvas.alpha_composite(im, (int((x + d / 2 - c["center"][0] * k) * K), int((y + d / 2 - c["center"][1] * k) * K)))

W, H = 420, 250
bg = Image.new("RGBA", (W * K, H * K), (96, 112, 104, 255))
d = ImageDraw.Draw(bg)
# sfondo "montagna"
for i in range(H * K):
    d.line([(0, i), (W * K, i)], fill=(70 + i // 12, 92 + i // 14, 100 + i // 16, 255))
# GIOCATORE (layoutLeft): ritratto 76, barre 20/15/15 attaccate
x0, y0, av = 12, 8, 76
bx = x0 + av // 2
gap = 13
bar(bg, d, "health", bx, y0 + 4, 268, 20, 1.0, (255, 76, 90, 255))
bar(bg, d, "stamina", bx, y0 + 4 + 20 + gap, 246, 15, 0.8, (90, 220, 90, 255))
bar(bg, d, "shield", bx, y0 + 4 + 20 + gap + 15 + gap, 228, 15, 0.6, (70, 180, 255, 255))
d.ellipse([(x0 - 3) * K, (y0 + 4 - 3) * K, (x0 + av + 3) * K, (y0 + 4 + av + 3) * K], fill=(28, 32, 44, 255))
circle_frame(bg, "frame_portrait_player", x0, y0 + 4, av, "player")
# DRAGO: cerchio 60, nome 20, xp 13
py = y0 + av + 22
ec = 60
px = x0 + 8
bar(bg, d, "stamina", px + ec // 2, py + 4 + 6, 250, 20, 1.0, (32, 36, 50, 255))
bar(bg, d, "xp", px + ec // 2, py + 4 + 6 + 20 + 12, 226, 13, 0.45, (170, 110, 255, 255))
d.ellipse([(px - 2) * K, (py + 4 - 2) * K, (px + ec + 2) * K, (py + 4 + ec + 2) * K], fill=(28, 32, 44, 255))
circle_frame(bg, "frame_portrait_dragon", px, py + 4, ec, "dragon")
d.ellipse([(px - 8) * K, (py - 2) * K, (px - 8 + 30) * K, (py - 2 + 30) * K], fill=(255, 196, 64, 255))
circle_frame(bg, "frame_level_badge", px - 8, py - 2, 30, "lv")
try:
    f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
except Exception:
    f = ImageFont.load_default()
d.text(((bx + 46) * K, (y0 + 6) * K), "HP 100", font=f, fill="white")
d.text(((px + ec // 2 + 34) * K, (py + 11) * K), "Alioth · Legendary", font=f, fill="white")

# SCHEDE prima/dopo, allungate a 230 logici x 56
tabs = Image.new("RGBA", (W * K, 150 * K), (30, 32, 38, 255))
s = 56 / 128
for i, src in enumerate((os.path.join(A, "frame_tab_normal.png"), os.path.join(N, "frame_tab_normal.png"))):
    im = nine(Image.open(src).convert("RGBA"), (109, 38, 109, 38), 330 * K, 56 * K, s * K / 2 * 2)
    tabs.alpha_composite(im, (20 * K, (14 + i * 70) * K))
    ImageDraw.Draw(tabs).text((360 * K, (34 + i * 70) * K), "prima" if i == 0 else "dopo", font=f, fill="white")
out = Image.new("RGBA", (W * K, (H + 150) * K))
out.alpha_composite(bg, (0, 0))
out.alpha_composite(tabs, (0, H * K))
out.convert("RGB").save(os.path.join(N, "anteprima_hud_e_schede.png"))
print("ok")
