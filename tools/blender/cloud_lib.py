# Libreria dei modelli della sessione cloud (arena dei draghi e modelli della mappa).
# Uso: blender -b --factory-startup --python tools/blender/arena.py -- [--render] [--quick]
#
# Convenzioni (docs/CLOUD_SESSIONE.md):
# - 1 unita' di Blender = 1 m = 1 stud; Z in alto; il fronte/ingresso guarda verso -Y di Blender,
#   che in Roblox e' +Z (Roblox = Blender (x, z, -y)). Origine a terra al centro.
# - Ogni parte esportata ha UN materiale (tools/modelli/esporta_modelli.py legge solo il primo):
#   una parte con piu' materiali diventa piu' oggetti (<Parte>, <Parte>_Ferro, ...).
# - Collisioni: solo scatole (8 vertici, anche ruotate: le rampe sono scatole inclinate).
# - Texture PBR 1024 fatte qui con numpy (tileable), una cartella Textures/ per modello.
# Solo numpy e bpy: gira con il Blender 5.2 normale.

import bpy
import bmesh
import json
import math
import os
import random
import sys
import time

import numpy as np
from mathutils import Matrix, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CLOUD = os.path.join(REPO, "cloud")
TEX = 1024

# ---------------------------------------------------------------------------------------
# elementi dei draghi (solo questi 8, AGENTS.md) e colori (sRGB 0..1)

ELEMENTI = ["Roccia", "Gelo", "Cosmico", "Tempesta", "Eclissi", "Fulmine", "Ossa", "Gas"]
COLORE = {
    "Roccia": (0.58, 0.37, 0.16), "Gelo": (0.56, 0.82, 0.96), "Cosmico": (0.40, 0.24, 0.70),
    "Tempesta": (0.27, 0.40, 0.57), "Eclissi": (0.07, 0.06, 0.08), "Fulmine": (0.09, 0.09, 0.10),
    "Ossa": (0.89, 0.85, 0.73), "Gas": (0.52, 0.80, 0.16),
}
# secondo colore (bordi, simboli)
ACCENTO = {
    "Roccia": (0.95, 0.66, 0.22), "Gelo": (0.92, 0.98, 1.00), "Cosmico": (0.62, 0.72, 1.00),
    "Tempesta": (0.78, 0.86, 0.95), "Eclissi": (0.86, 0.66, 0.24), "Fulmine": (1.00, 0.88, 0.10),
    "Ossa": (0.45, 0.36, 0.26), "Gas": (0.86, 1.00, 0.35),
}


# ---------------------------------------------------------------------------------------
# texture procedurali (numpy, tutte ripetibili sui bordi)

def _freq(n):
    fx = np.fft.fftfreq(n)[:, None]
    fy = np.fft.fftfreq(n)[None, :]
    return fx, fy


def noise(n, beta=2.2, seed=0, aniso=(1.0, 1.0)):
    """rumore frattale ripetibile 0..1 (beta alto = macchie grandi); aniso allunga le venature"""
    rng = np.random.default_rng(seed)
    w = rng.standard_normal((n, n))
    fx, fy = _freq(n)
    r = np.sqrt((fx * aniso[0]) ** 2 + (fy * aniso[1]) ** 2)
    r[0, 0] = 1.0
    f = np.fft.fft2(w) * r ** (-beta / 2.0)
    f[0, 0] = 0
    out = np.real(np.fft.ifft2(f))
    out -= out.min()
    return out / max(out.max(), 1e-9)


def blur(a, px):
    """sfocatura gaussiana ripetibile (FFT)"""
    n = a.shape[0]
    fx, fy = _freq(n)
    g = np.exp(-2 * (math.pi * px) ** 2 * (fx ** 2 + fy ** 2))
    if a.ndim == 3:
        return np.stack([np.real(np.fft.ifft2(np.fft.fft2(a[..., k]) * g)) for k in range(a.shape[2])], -1)
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    t = np.asarray(t)
    if t.ndim == 2:
        t = t[..., None]
    return a * (1 - t) + b * t


def col(c, n=TEX):
    return np.ones((n, n, 3)) * np.array(c)[None, None, :]


def blocks(n, rows, seed, wmin=1.0, wmax=2.2, mortar=0.04, offset=True):
    """muro a blocchi sfalsati: altezza (bordi consumati), id del blocco, maschera della malta"""
    rng = np.random.default_rng(seed)
    y = np.arange(n)[:, None] / n
    x = np.arange(n)[None, :] / n
    h = np.zeros((n, n))
    bid = np.zeros((n, n))
    rh = 1.0 / rows
    k = 0
    for r in range(rows):
        # larghezze del filare (in unita' di altezza del filare)
        xs = [0.0]
        while xs[-1] < 1.0:
            xs.append(xs[-1] + rng.uniform(wmin, wmax) * rh)
        xs = np.array(xs) / xs[-1]
        sh = rng.uniform(0, 1) if offset else 0.0
        ry = (y - r * rh) / rh
        inrow = ((ry >= 0) & (ry < 1)).astype(float)
        xx = (x + sh) % 1.0
        idx = np.searchsorted(xs, xx[0], side="right") - 1
        x0 = xs[idx]
        x1 = xs[idx + 1]
        u = (xx[0] - x0) / (x1 - x0)
        # distanza dal bordo del blocco (in frazione del blocco)
        du = np.minimum(u, 1 - u)[None, :] * ((x1 - x0)[None, :] / rh)
        dv = np.minimum(ry, 1 - ry)
        d = np.minimum(du, dv)
        hb = smooth(mortar, mortar + 0.07, d)  # mortar in altezze di filare
        h += inrow * hb
        bid += inrow * (idx[None, :] + k)
        k += len(xs) + 3
    return h, bid, (h < 0.02).astype(float)


def hashf(bid, seed=0):
    return (np.sin(bid * 12.9898 + seed * 78.233) * 43758.5453) % 1.0


def worley(n, count, seed):
    """distanza dal punto piu' vicino (celle ripetibili), normalizzata"""
    rng = np.random.default_rng(seed)
    pts = rng.uniform(0, n, (count, 2))
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    d1 = np.full((n, n), 1e9, np.float32)
    d2 = np.full((n, n), 1e9, np.float32)
    for px, py in pts:
        dx = np.abs(xx - px)
        dx = np.minimum(dx, n - dx)
        dy = np.abs(yy - py)
        dy = np.minimum(dy, n - dy)
        d = np.sqrt(dx * dx + dy * dy)
        d2 = np.where(d < d1, d1, np.minimum(d2, d))
        d1 = np.minimum(d1, d)
    return d1 / (n / math.sqrt(count)), (d2 - d1) / (n / math.sqrt(count))


def normal_from(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nz = np.ones_like(h)
    l = np.sqrt(dx * dx + dy * dy + nz)
    # convenzione OpenGL (Roblox): verde in su; la riga 0 dell'array e' in alto nell'immagine
    return np.stack([0.5 - 0.5 * dx / l, 0.5 + 0.5 * dy / l, 0.5 + 0.5 * nz / l], -1)


def fill_poly(n, pts, scale=1.0):
    """maschera di un poligono (coordinate in pixel, x a destra, y in basso), pari/dispari"""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) + 0.5
    inside = np.zeros((n, n), bool)
    m = len(pts)
    for i in range(m):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % m]
        if y0 == y1:
            continue
        c = ((y0 > yy) != (y1 > yy)) & (xx < (x1 - x0) * (yy - y0) / (y1 - y0) + x0)
        inside ^= c
    return inside.astype(float)


def disc(n, cx, cy, r, soft=1.0):
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) + 0.5
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    return np.clip((r - d) / soft + 0.5, 0, 1)


def line(n, x0, y0, x1, y1, w):
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) + 0.5
    vx, vy = x1 - x0, y1 - y0
    L2 = vx * vx + vy * vy + 1e-9
    t = np.clip(((xx - x0) * vx + (yy - y0) * vy) / L2, 0, 1)
    d = np.sqrt((xx - x0 - t * vx) ** 2 + (yy - y0 - t * vy) ** 2)
    return np.clip((w * 0.5 - d) + 0.5, 0, 1)


# --- materiali: ognuno restituisce (colore sRGB, altezza 0..1, rugosita' 0..1) ----------------

def m_pietra(seed, base, rows=6, var=0.10, wear=1.0, moss=0.0):
    n = TEX
    h, bid, mort = blocks(n, rows, seed)
    t = hashf(bid, seed)
    nz = noise(n, 2.0, seed + 1)
    fine = noise(n, 1.2, seed + 2)
    big = noise(n, 3.2, seed + 3)
    # bordi scheggiati: il rumore mangia i bordi dei blocchi
    h2 = np.clip(h - smooth(0.35, 0.75, nz) * 0.9 * wear * (1 - h * 0.6), 0, 1)
    edge = smooth(0.0, 0.6, h2)
    height = 0.55 * edge + 0.25 * nz * edge + 0.12 * fine + 0.08 * big
    c = col(base) * (1 + var * (t[..., None] - 0.5) * 2) * (0.82 + 0.3 * nz[..., None])
    c = mix(c, col((0.10, 0.10, 0.10)), (1 - edge) * 0.75)                 # malta e fessure scure
    c = mix(c, c * 0.55, smooth(0.62, 0.9, big) * 0.45)                    # sporco e colature
    c = c * (0.9 + 0.2 * fine[..., None])
    if moss:
        mo = smooth(0.55, 0.8, noise(n, 2.6, seed + 9)) * (1 - edge * 0.5) * moss
        c = mix(c, col((0.22, 0.26, 0.15)), mo)
    rough = 0.82 + 0.12 * fine - 0.1 * edge * nz
    return c, height, rough


def m_bugnato(seed, base):
    """pietra da cornice: blocchi grandi lisciati, poche venature"""
    c, h, r = m_pietra(seed, base, rows=3, var=0.06, wear=0.45)
    vein = smooth(0.48, 0.5, noise(TEX, 2.4, seed + 7, (1.0, 4.0))) * smooth(0.52, 0.5, noise(TEX, 2.4, seed + 7, (1.0, 4.0)))
    c = mix(c, c * 0.7, vein * 0.5)
    return c, h, r * 0.92


def m_basalto(seed):
    n = TEX
    d1, d2 = worley(n, 36, seed)
    crack = 1 - smooth(0.0, 0.05, d2)
    nz = noise(n, 1.6, seed + 1)
    big = noise(n, 3.0, seed + 2)
    c = col((0.12, 0.12, 0.13)) * (0.75 + 0.5 * nz[..., None]) * (0.85 + 0.3 * big[..., None])
    c = mix(c, col((0.03, 0.03, 0.035)), crack * 0.9)
    h = 0.8 - 0.7 * crack + 0.2 * nz
    r = 0.65 + 0.25 * nz + 0.1 * crack
    return c, h, r


def m_ferro(seed):
    n = TEX
    d1, d2 = worley(n, 140, seed)
    dents = smooth(0.0, 0.9, d1)                      # martellato
    nz = noise(n, 1.8, seed + 1)
    rust = smooth(0.62, 0.85, noise(n, 2.4, seed + 2) * 0.7 + nz * 0.3)
    c = col((0.15, 0.15, 0.16)) * (0.8 + 0.35 * dents[..., None]) * (0.85 + 0.3 * nz[..., None])
    c = mix(c, col((0.36, 0.19, 0.09)) * (0.7 + 0.5 * nz[..., None]), rust * 0.85)
    h = 0.6 * dents + 0.25 * nz + 0.15 * rust
    r = 0.45 + 0.2 * nz + 0.35 * rust
    return c, h, r


def m_oro(seed):
    n = TEX
    nz = noise(n, 2.0, seed + 1)
    fine = noise(n, 1.0, seed + 2)
    grime = smooth(0.55, 0.85, noise(n, 2.8, seed + 3))
    c = col((0.66, 0.50, 0.24)) * (0.85 + 0.3 * nz[..., None])
    c = mix(c, col((0.26, 0.20, 0.11)), grime * 0.6)
    h = 0.5 * nz + 0.2 * fine
    r = 0.28 + 0.15 * fine + 0.4 * grime
    return c, h, r


def m_legno(seed, base=(0.36, 0.23, 0.13), planks=5):
    n = TEX
    grain = noise(n, 2.2, seed, (1.0, 14.0))          # venature lungo X (lungo l'asse U)
    fine = noise(n, 1.0, seed + 1, (1.0, 8.0))
    knots = smooth(0.05, 0.0, worley(n, 6, seed + 2)[0]) * 0.5
    y = np.arange(n)[:, None] / n
    pv = (y * planks) % 1.0
    gap = smooth(0.0, 0.04, np.minimum(pv, 1 - pv))
    pid = np.floor(y * planks) * np.ones((1, n))
    t = hashf(pid, seed)
    c = col(base) * (0.75 + 0.45 * grain[..., None]) * (0.9 + 0.2 * t[..., None])
    c = mix(c, col((0.12, 0.07, 0.04)), knots * 0.8 + (1 - gap) * 0.85)
    c = c * (0.92 + 0.12 * fine[..., None])
    h = 0.4 * gap + 0.3 * grain + 0.2 * fine - 0.2 * knots
    r = 0.7 + 0.15 * fine
    return c, h, r


def m_corteccia(seed, base=(0.27, 0.19, 0.13)):
    n = TEX
    ridges = noise(n, 2.6, seed, (12.0, 1.0))          # solchi verticali (lungo V)
    fine = noise(n, 1.4, seed + 1, (4.0, 1.0))
    h = smooth(0.3, 0.7, ridges) * 0.8 + fine * 0.2
    c = col(base) * (0.55 + 0.7 * h[..., None])
    lich = smooth(0.7, 0.85, noise(n, 2.4, seed + 3)) * 0.4
    c = mix(c, col((0.45, 0.48, 0.38)), lich)
    return c, h, 0.9 - 0.1 * h


def m_sabbia(seed):
    """pavimento dell'arena: lastre consumate con sabbia nelle fughe, bruciature e graffi"""
    n = TEX
    h, bid, mort = blocks(n, 8, seed, 0.9, 1.9, 0.025)
    t = hashf(bid, seed)
    nz = noise(n, 2.0, seed + 1)
    fine = noise(n, 1.0, seed + 2)
    sandmask = smooth(0.45, 0.75, noise(n, 3.0, seed + 3) * 0.7 + (1 - h) * 0.5)
    stone = col((0.50, 0.44, 0.36)) * (0.85 + 0.25 * t[..., None]) * (0.85 + 0.3 * nz[..., None])
    stone = mix(stone, col((0.20, 0.17, 0.14)), (1 - smooth(0.0, 0.4, h)) * 0.6)
    sand = col((0.70, 0.58, 0.40)) * (0.85 + 0.3 * fine[..., None])
    c = mix(stone, sand, sandmask)
    # bruciature: macchie scure con bordo bruno
    rng = np.random.default_rng(seed + 5)
    burn = np.zeros((n, n))
    for _ in range(3):
        cx, cy, r = rng.uniform(0, n), rng.uniform(0, n), rng.uniform(110, 190)
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                burn = np.maximum(burn, disc(n, cx + ox, cy + oy, r, r * 1.6))
    burn = smooth(0.35, 0.95, burn * (0.55 + 0.9 * noise(n, 2.3, seed + 6)))
    c = mix(c, col((0.26, 0.17, 0.10)), smooth(0.0, 0.5, burn) * 0.5)
    c = mix(c, col((0.07, 0.06, 0.05)), smooth(0.4, 1.0, burn) * 0.7)
    # graffi di artigli: tre righe parallele chiare
    scr = np.zeros((n, n))
    for _ in range(9):
        cx, cy = rng.uniform(80, n - 80), rng.uniform(80, n - 80)
        a = rng.uniform(0, math.pi)
        L = rng.uniform(70, 160)
        dx, dy = math.cos(a), math.sin(a)
        for k in (-1, 0, 1):
            ox, oy = -dy * k * 9, dx * k * 9
            scr = np.maximum(scr, line(n, cx + ox - dx * L / 2, cy + oy - dy * L / 2, cx + ox + dx * L / 2, cy + oy + dy * L / 2, 3.2))
    c = mix(c, col((0.80, 0.72, 0.60)), scr * 0.55)
    height = 0.5 * h * (1 - sandmask * 0.6) + 0.2 * nz + 0.1 * fine - 0.25 * scr
    rough = 0.88 + 0.1 * fine - 0.15 * burn * 0
    return c, height, rough


def m_tegole(seed, base=(0.22, 0.21, 0.24)):
    n = TEX
    rows = 10
    y = np.arange(n)[:, None] / n
    x = np.arange(n)[None, :] / n
    rv = (y * rows) % 1.0
    row = np.floor(y * rows)
    cols = 8
    xs = (x * cols + (row % 2) * 0.5) % 1.0
    tid = np.floor(x * cols + (row % 2) * 0.5) + row * 31
    arc = np.sin(xs * math.pi)                       # coppo curvo
    h = arc * (0.4 + 0.6 * rv)                       # si sovrappongono (scalino)
    nz = noise(n, 2.0, seed)
    t = hashf(tid, seed)
    c = col(base) * (0.75 + 0.35 * arc[..., None]) * (0.85 + 0.3 * t[..., None]) * (0.85 + 0.3 * nz[..., None])
    c = mix(c, col((0.06, 0.06, 0.07)), smooth(0.12, 0.0, rv) * 0.8)
    return c, h + 0.2 * nz, 0.7 + 0.2 * nz


def m_neve(seed):
    n = TEX
    nz = noise(n, 2.4, seed)
    sp = noise(n, 0.8, seed + 1)
    c = col((0.90, 0.93, 0.97)) * (0.92 + 0.1 * nz[..., None])
    c = mix(c, col((0.70, 0.78, 0.88)), smooth(0.5, 0.2, nz) * 0.4)
    return c, 0.7 * nz + 0.3 * sp, 0.55 + 0.3 * sp


def m_corda(seed, base=(0.62, 0.50, 0.32)):
    n = TEX
    y = np.arange(n)[:, None] / n
    x = np.arange(n)[None, :] / n
    tw = (x * 12 + y * 24) % 1.0                     # trefoli attorcigliati
    h = np.sin(tw * math.pi) ** 0.6
    fib = noise(n, 1.0, seed, (1.0, 6.0))
    c = col(base) * (0.6 + 0.5 * h[..., None]) * (0.85 + 0.3 * fib[..., None])
    return c, h * 0.8 + fib * 0.2, 0.9 - 0.05 * h


def m_lamiera(seed, base=(0.62, 0.11, 0.08)):
    n = TEX
    x = np.arange(n)[None, :] / n
    wav = 0.5 + 0.5 * np.sin(x * 2 * math.pi * 16) * np.ones((n, 1))
    nz = noise(n, 2.2, seed)
    rust = smooth(0.6, 0.85, noise(n, 2.0, seed + 1))
    c = col(base) * (0.8 + 0.3 * wav[..., None]) * (0.85 + 0.3 * nz[..., None])
    c = mix(c, col((0.32, 0.17, 0.08)), rust * 0.7)
    rivet = np.zeros((n, n))
    for yy in (0.06, 0.94):
        for k in range(16):
            rivet = np.maximum(rivet, disc(n, (k + 0.5) * n / 16, yy * n, 5, 1.5))
    return c, wav * 0.8 + 0.2 * nz + rivet * 0.5, 0.45 + 0.35 * rust


def m_aghi(seed, base=(0.12, 0.22, 0.13)):
    n = TEX
    a = noise(n, 1.2, seed, (6.0, 1.0))
    b = noise(n, 1.2, seed + 1, (1.0, 6.0))
    st = np.maximum(smooth(0.55, 0.75, a), smooth(0.55, 0.75, b))
    nz = noise(n, 2.6, seed + 2)
    c = col(base) * (0.6 + 0.6 * st[..., None]) * (0.8 + 0.4 * nz[..., None])
    return c, st * 0.7 + nz * 0.3, 0.8


def m_stoffa(seed, base):
    n = TEX
    y = np.arange(n)[:, None] / n
    x = np.arange(n)[None, :] / n
    weave = 0.5 + 0.25 * np.sin(x * 2 * math.pi * 180) + 0.25 * np.sin(y * 2 * math.pi * 180)
    nz = noise(n, 2.4, seed)
    c = col(base) * (0.85 + 0.2 * weave[..., None]) * (0.8 + 0.35 * nz[..., None])
    return c, weave * 0.4 + nz * 0.3, 0.92


def m_bronzo(seed):
    n = TEX
    nz = noise(n, 2.0, seed)
    pat = smooth(0.5, 0.8, noise(n, 2.6, seed + 1))
    c = col((0.48, 0.32, 0.16)) * (0.8 + 0.35 * nz[..., None])
    c = mix(c, col((0.25, 0.48, 0.40)), pat * 0.75)   # verderame
    return c, nz * 0.6 + pat * 0.3, 0.35 + 0.4 * pat


def m_statua(seed, el):
    """pietra scolpita (senza blocchi) tinta del colore dell'elemento, venature dell'accento"""
    n = TEX
    base = np.array(COLORE[el])
    if el in ("Eclissi", "Fulmine"):
        base = base + 0.07
    nz = noise(n, 2.2, seed)
    fine = noise(n, 1.1, seed + 1)
    big = noise(n, 3.2, seed + 2)
    c = col(base * 0.9 + 0.04) * (0.8 + 0.35 * nz[..., None]) * (0.9 + 0.15 * fine[..., None])
    c = mix(c, c * 0.6, smooth(0.6, 0.85, big) * 0.5)
    vein = noise(n, 2.2, seed + 11, (1.0, 3.0))
    v = smooth(0.47, 0.5, vein) * smooth(0.53, 0.5, vein)
    c = mix(c, col(ACCENTO[el]), v * 0.8)
    if el == "Cosmico":
        rng = np.random.default_rng(seed)
        stars = np.zeros((n, n))
        for _ in range(140):
            stars = np.maximum(stars, disc(n, rng.uniform(0, n), rng.uniform(0, n), rng.uniform(1.2, 3.2), 1.0))
        c = mix(c, col((0.95, 0.95, 1.0)), stars)
    h = 0.5 * nz + 0.3 * fine + 0.2 * v
    return c, h, 0.55 + 0.25 * fine - 0.15 * v


def m_spicchi(seed):
    """atlante: 8 bande verticali (una per elemento, nell'ordine di ELEMENTI), pietra poco satura"""
    n = TEX
    c, h, r = m_pietra(seed, (0.5, 0.5, 0.5), rows=12, var=0.12, wear=0.8)
    lum = c.mean(-1, keepdims=True)
    out = np.zeros_like(c)
    w = n // 8
    for k, el in enumerate(ELEMENTI):
        tint = np.array(COLORE[el])
        if el in ("Eclissi", "Fulmine"):
            tint = np.array((0.22, 0.20, 0.18))
        g = tint.mean()
        tint = (tint - g) * 0.42 + 0.55 * g + 0.22      # poco saturo
        out[:, k * w:(k + 1) * w] = lum[:, k * w:(k + 1) * w] * 1.9 * tint
    return out, h, r


def m_stendardi(seed):
    """atlante: 8 colonne (128 px) = 8 stendardi; bordo d'oro e simbolo dell'elemento in alto"""
    n = TEX
    w = n // 8
    c = np.zeros((n, n, 3))
    h = np.zeros((n, n))
    weave = noise(n, 0.6, seed) * 0.3 + noise(n, 2.4, seed + 1) * 0.7
    for k, el in enumerate(ELEMENTI):
        x0 = k * w
        cc = col(COLORE[el])[:, :w].copy()
        if el in ("Eclissi", "Fulmine"):
            cc = cc + 0.03
        # bordo d'oro
        yy, xx = np.mgrid[0:n, 0:w]
        border = ((xx < 9) | (xx > w - 10) | (yy < 18)).astype(float)
        inner = ((xx > 13) & (xx < w - 14) & (yy > 22)).astype(float) * (1 - ((xx > 17) & (xx < w - 18) & (yy > 26)).astype(float))
        gold = np.array((0.85, 0.64, 0.25))
        cc = mix(cc, col(gold)[:, :w], np.clip(border + inner * 0.9, 0, 1))
        sym = symbol_mask(el, w, 0.30)              # simbolo (w x w) piazzato in alto
        big = np.zeros((n, w))
        big[150:150 + w, :] = sym
        cc = mix(cc, col(ACCENTO[el] if el != "Ossa" else (0.30, 0.22, 0.14))[:, :w], big)
        c[:, x0:x0 + w] = cc
        h[:, x0:x0 + w] = border * 0.6 + big * 0.4
    c = c * (0.8 + 0.3 * weave[..., None])
    return c, h * 0.5 + weave * 0.5, 0.9 - 0.4 * h


def symbol_mask(el, s, lw=0.3):
    """simbolo dell'elemento disegnato in un quadrato s x s (0..1)"""
    m = np.zeros((s, s))
    c = s / 2
    R = s * 0.40
    w = max(2.0, s * 0.07)
    if el == "Roccia":   # due montagne
        m = np.maximum(fill_poly(s, [(c - R, c + R * 0.7), (c - R * 0.25, c - R * 0.8), (c + R * 0.35, c + R * 0.7)]),
                       fill_poly(s, [(c - R * 0.1, c + R * 0.7), (c + R * 0.45, c - R * 0.3), (c + R, c + R * 0.7)]))
    elif el == "Gelo":   # fiocco di neve
        for a in range(3):
            t = a * math.pi / 3
            m = np.maximum(m, line(s, c - R * math.cos(t), c - R * math.sin(t), c + R * math.cos(t), c + R * math.sin(t), w))
            for sg in (-1, 1):
                bx, by = c + sg * R * 0.6 * math.cos(t), c + sg * R * 0.6 * math.sin(t)
                for d in (-1, 1):
                    tt = t + d * math.pi / 4
                    m = np.maximum(m, line(s, bx, by, bx + sg * R * 0.3 * math.cos(tt), by + sg * R * 0.3 * math.sin(tt), w * 0.8))
    elif el == "Cosmico":   # stella a 4 punte e luna
        pts = []
        for k in range(8):
            r = R if k % 2 == 0 else R * 0.28
            a = k * math.pi / 4 - math.pi / 2
            pts.append((c + r * math.cos(a), c + r * math.sin(a)))
        m = fill_poly(s, pts)
        m = np.maximum(m, disc(s, c + R * 0.75, c - R * 0.75, R * 0.22) - disc(s, c + R * 0.85, c - R * 0.85, R * 0.18))
    elif el == "Tempesta":   # tre onde di vento
        for k in range(3):
            yb = c - R * 0.6 + k * R * 0.6
            prev = None
            for i in range(13):
                x = c - R + i * R * 2 / 12
                y = yb + math.sin(i / 12 * math.pi * 2) * R * 0.18
                if prev:
                    m = np.maximum(m, line(s, prev[0], prev[1], x, y, w))
                prev = (x, y)
    elif el == "Eclissi":   # anello con il disco nero dentro
        m = np.clip(disc(s, c, c, R) - disc(s, c + R * 0.18, c - R * 0.05, R * 0.78), 0, 1)
    elif el == "Fulmine":
        m = fill_poly(s, [(c + R * 0.15, c - R), (c - R * 0.55, c + R * 0.1), (c - R * 0.02, c + R * 0.1),
                          (c - R * 0.25, c + R), (c + R * 0.6, c - R * 0.15), (c + R * 0.05, c - R * 0.15)])
    elif el == "Ossa":   # ossa incrociate
        for sg in (-1, 1):
            m = np.maximum(m, line(s, c - R * 0.8, c - sg * R * 0.8, c + R * 0.8, c + sg * R * 0.8, w * 1.2))
            for ex, ey in ((c - R * 0.8, c - sg * R * 0.8), (c + R * 0.8, c + sg * R * 0.8)):
                m = np.maximum(m, disc(s, ex + w * 0.6, ey, w * 0.9))
                m = np.maximum(m, disc(s, ex - w * 0.6, ey, w * 0.9))
    elif el == "Gas":   # tre bolle
        for (dx, dy, r) in ((-0.35, 0.35, 0.42), (0.38, 0.2, 0.32), (0.0, -0.45, 0.3)):
            m = np.maximum(m, np.clip(disc(s, c + dx * R, c + dy * R, r * R) - disc(s, c + dx * R, c + dy * R, r * R - w), 0, 1))
            m = np.maximum(m, disc(s, c + (dx - 0.12) * R, c + (dy - 0.12) * R, r * R * 0.22))
    return np.clip(m, 0, 1)


def m_osso(seed):
    """osso antico: avorio caldo, crepe sottili, sporco scuro nelle pieghe"""
    n = TEX
    nz = noise(n, 2.2, seed)
    fine = noise(n, 1.0, seed + 1)
    fib = noise(n, 1.6, seed + 2, (1.0, 7.0))
    d1, d2 = worley(n, 30, seed + 3)
    crack = (1 - smooth(0.0, 0.03, d2)) * smooth(0.45, 0.6, noise(n, 2.4, seed + 4))
    c = col((0.80, 0.73, 0.58)) * (0.8 + 0.3 * nz[..., None]) * (0.9 + 0.15 * fib[..., None])
    c = mix(c, col((0.42, 0.34, 0.24)), smooth(0.55, 0.85, noise(n, 2.8, seed + 5)) * 0.55)
    c = mix(c, col((0.20, 0.15, 0.10)), crack * 0.8)
    h = 0.5 * nz + 0.25 * fib + 0.15 * fine - 0.3 * crack
    return c, h, 0.6 + 0.25 * fine + 0.15 * crack


def m_membrana(seed):
    """membrana delle ali: cuoio scuro rosso bruno con vene"""
    n = TEX
    nz = noise(n, 2.4, seed)
    fine = noise(n, 1.2, seed + 1)
    d1, d2 = worley(n, 18, seed + 2)
    vein = 1 - smooth(0.0, 0.025, d2)
    c = col((0.30, 0.09, 0.07)) * (0.75 + 0.45 * nz[..., None]) * (0.9 + 0.15 * fine[..., None])
    c = mix(c, col((0.14, 0.04, 0.035)), vein * 0.75)
    c = mix(c, col((0.45, 0.20, 0.12)), smooth(0.65, 0.9, noise(n, 2.0, seed + 3)) * 0.4)
    h = 0.5 * nz + 0.3 * vein + 0.2 * fine
    return c, h, 0.7 + 0.15 * fine


def m_vulcanica(seed, base=(0.30, 0.28, 0.27)):
    """pietra vulcanica senza giunti (i blocchi sono geometria): grana, pori, venature chiare"""
    n = TEX
    nz = noise(n, 2.0, seed)
    fine = noise(n, 1.0, seed + 1)
    big = noise(n, 3.0, seed + 2)
    d1, d2 = worley(n, 400, seed + 3)
    pores = 1 - smooth(0.0, 0.25, d1)
    c = col(base) * (0.8 + 0.3 * nz[..., None]) * (0.9 + 0.18 * fine[..., None]) * (0.9 + 0.2 * big[..., None])
    c = mix(c, col((0.12, 0.11, 0.10)), pores * 0.6)
    vein = noise(n, 2.4, seed + 5, (1.0, 5.0))
    v = smooth(0.48, 0.5, vein) * smooth(0.52, 0.5, vein)
    c = mix(c, c * 1.5, v * 0.4)
    h = 0.5 * nz + 0.3 * fine - 0.4 * pores
    return c, h, 0.85 + 0.1 * fine - 0.1 * v


# registro: nome del materiale -> (funzione, metri per ripetizione della texture)
MATERIALI = {
    "PietraScura": (lambda: m_pietra(11, (0.37, 0.33, 0.29), rows=5, moss=0.25), 6.0),
    "PietraCornice": (lambda: m_bugnato(12, (0.64, 0.56, 0.45)), 3.0),
    "Basalto": (lambda: m_basalto(13), 3.0),
    "FerroBattuto": (lambda: m_ferro(14), 1.5),
    "OroAntico": (lambda: m_oro(15), 1.5),
    "LegnoScuro": (lambda: m_legno(16), 2.5),
    "LegnoChiaro": (lambda: m_legno(17, (0.55, 0.38, 0.22)), 2.5),
    "Corteccia": (lambda: m_corteccia(18), 2.0),
    "SabbiaArena": (lambda: m_sabbia(19), 26.0),
    "Spicchi": (lambda: m_spicchi(20), 0),
    "Stendardi": (lambda: m_stendardi(21), 0),
    "Tegole": (lambda: m_tegole(22), 3.0),
    "TegoleRosse": (lambda: m_tegole(23, (0.42, 0.13, 0.08)), 3.0),
    "Neve": (lambda: m_neve(24), 4.0),
    "Corda": (lambda: m_corda(25), 0.6),
    "LamieraRossa": (lambda: m_lamiera(26), 2.0),
    "AghiPino": (lambda: m_aghi(27), 2.0),
    "Bronzo": (lambda: m_bronzo(28), 1.5),
    "OssoDrago": (lambda: m_osso(32), 3.0),
    "MembranaDrago": (lambda: m_membrana(33), 6.0),
    "PietraVulcanica": (lambda: m_vulcanica(34), 2.5),
    "PietraChiara": (lambda: m_pietra(29, (0.60, 0.57, 0.52), rows=4, wear=0.7), 3.0),
    "TelaRossa": (lambda: m_stoffa(30, (0.55, 0.10, 0.07)), 2.0),
    "TelaGrigia": (lambda: m_stoffa(31, (0.40, 0.42, 0.40)), 2.0),
}
for _i, _el in enumerate(ELEMENTI):
    MATERIALI["Statua" + _el] = ((lambda e=_el, s=40 + _i: m_statua(s, e)), 3.0)

# materiali senza texture (tools/modelli/carica_modelli.luau: PLAIN) e colore per le anteprime
PIANI = {
    "MAT_Ember": ((1.0, 0.28, 0.05), 0.9),       # rune luminose, braci (Neon)
    "MAT_WarmLight": ((1.0, 0.75, 0.45), 4.0),   # lanterne
    "MAT_Gold": ((0.84, 0.69, 0.27), 0.0),
    "MAT_Glass": ((0.66, 0.80, 0.90), 0.0),
}

_texcache = {}


def texture_files(name, outdir):
    """scrive (una volta per sessione) le 3 PNG del materiale e le copia in outdir"""
    os.makedirs(outdir, exist_ok=True)
    files = {k: os.path.join(outdir, "%s_%s.png" % (name, k)) for k in ("BaseColor", "Normal", "Roughness")}
    if name not in _texcache:
        t0 = time.time()
        c, h, r = MATERIALI[name][0]()
        r = np.broadcast_to(np.asarray(r, float), h.shape)
        nrm = normal_from(h, 6.0)
        data = {"BaseColor": np.clip(c, 0, 1), "Normal": nrm, "Roughness": np.clip(np.repeat(r[..., None], 3, -1), 0.02, 1)}
        _texcache[name] = data
        print("  texture %s (%.1fs)" % (name, time.time() - t0))
    for k, path in files.items():
        if not os.path.exists(path) or name not in _written:
            _save_png(_texcache[name][k], path, k != "BaseColor")
    _written.add(name)
    return files


_written = set()


def _save_png(arr, path, linear):
    n = arr.shape[0]
    img = bpy.data.images.new("tmp_png", n, n, alpha=False, float_buffer=False)
    if linear:
        img.colorspace_settings.name = "Non-Color"
    rgba = np.ones((n, n, 4), np.float32)
    rgba[..., :3] = arr[::-1]          # Blender parte dal basso
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


# ---------------------------------------------------------------------------------------
# geometria: ogni Parte accumula vertici e facce (un materiale), poi diventa un oggetto

def V(*a):
    return Vector(a if len(a) == 3 else a[0])


def rot_to(direction):
    """matrice 3x3 che porta +Z su direction"""
    d = Vector(direction).normalized()
    return d.to_track_quat("Z", "Y").to_matrix()


def mat4(loc=(0, 0, 0), rot=None, scale=None):
    M = Matrix.Translation(Vector(loc))
    if rot is not None:
        if isinstance(rot, (int, float)):
            R = Matrix.Rotation(rot, 4, "Z")
        elif isinstance(rot, Matrix):
            R = rot.to_4x4()
        else:
            R = (Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X"))
        M = M @ R
    if scale is not None:
        s = scale if hasattr(scale, "__len__") else (scale, scale, scale)
        M = M @ Matrix.Diagonal((s[0], s[1], s[2], 1))
    return M


class Part:
    def __init__(self, name, mat):
        self.name = name
        self.mat = mat
        self.v = []
        self.f = []          # (indici, liscia, uv o None)

    def add_bm(self, bm, M=None, smooth=False, uv=None):
        if M is not None:
            bm.transform(M)
        base = len(self.v)
        bm.verts.index_update()
        self.v.extend(tuple(v.co) for v in bm.verts)
        for f in bm.faces:
            fu = None
            if uv is not None:
                fu = [uv(Vector(l.vert.co)) for l in f.loops]
            self.f.append(([base + l.vert.index for l in f.loops], smooth if not isinstance(smooth, set) else (f.index in smooth), fu))
        bm.free()

    def add_raw(self, verts, faces, smooth=False, uvs=None):
        base = len(self.v)
        self.v.extend(tuple(p) for p in verts)
        for i, fc in enumerate(faces):
            self.f.append(([base + k for k in fc], smooth, uvs[i] if uvs else None))

    def tris(self):
        return sum(len(f[0]) - 2 for f in self.f)


class Model:
    def __init__(self, name):
        self.name = name
        self.parts = {}
        self.order = []
        self.cols = []        # (nome, Matrix 4x4 della scatola unitaria)
        self.markers = []     # (nome, Vector)
        self.notes = {}

    def part(self, name, mat):
        key = name
        if key not in self.parts:
            assert len(name) < 50, name
            self.parts[key] = Part(name, mat)
            self.order.append(key)
        p = self.parts[key]
        assert p.mat == mat, "%s: %s / %s" % (name, p.mat, mat)
        return p

    # --- collisioni -----------------------------------------------------------------------
    def col(self, name, center, size, rot=None):
        M = mat4(center, rot, size)
        self.cols.append((name, M))

    def ramp(self, name, p0, p1, width, thick=0.6):
        """rampa: scatola inclinata da p0 (basso) a p1 (alto), larga width, superficie su p0-p1"""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        L = d.length
        fwd = d.normalized()
        side = fwd.cross(Vector((0, 0, 1)))
        if side.length < 1e-4:
            side = Vector((1, 0, 0))
        side.normalize()
        up = side.cross(fwd).normalized()
        if up.z < 0:
            up = -up
            side = -side
        c = (p0 + p1) / 2 - up * thick / 2
        R = Matrix((side, fwd, up)).transposed()
        self.cols.append((name, mat4(c, R, (width, L, thick))))

    def marker(self, name, pos):
        self.markers.append((name, Vector(pos)))


# --- primitive (aggiungono a una Parte) ------------------------------------------------------

def box(p, c, s, rot=None, bev=0.0, seg=1, uv=None):
    """scatola centrata in c, misure s, smussata di bev"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.transform(Matrix.Diagonal((s[0], s[1], s[2], 1)))
    if bev > 0:
        b = min(bev, min(s) * 0.45)
        bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=b, segments=seg, affect="EDGES", profile=0.5)
    p.add_bm(bm, mat4(c, rot), smooth=seg > 1, uv=uv)


def boxz(p, x0, x1, y0, y1, z0, z1, bev=0.0, rot=None):
    box(p, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), rot, bev)


def cyl(p, a, b, r0, r1=None, n=16, caps=True, bev=0.0, smooth=True):
    """cilindro (o tronco di cono) da a a b"""
    r1 = r0 if r1 is None else r1
    a, b = Vector(a), Vector(b)
    L = (b - a).length
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=n, radius1=r0, radius2=r1, depth=L)
    if bev > 0 and caps:
        edges = [e for e in bm.edges if all(abs(abs(v.co.z) - L / 2) < 1e-5 for v in e.verts)]
        bmesh.ops.bevel(bm, geom=edges, offset=min(bev, min(r0, r1) * 0.4, L * 0.3), segments=1, affect="EDGES")
    R = rot_to(b - a)
    M = mat4((a + b) / 2, R)
    sm = set(f.index for f in bm.faces if abs(f.normal.z) < 0.7) if smooth else False
    p.add_bm(bm, M, smooth=sm)


def lathe(p, prof, n=24, c=(0, 0, 0), a0=0.0, a1=2 * math.pi, smooth=True, close=True, M=None, sharp_rows=()):
    """rivoluzione attorno a Z di un profilo [(r, z), ...] dal basso in alto"""
    full = abs(a1 - a0 - 2 * math.pi) < 1e-6
    segs = n if full else n
    cols_ = n if full else n + 1
    verts = []
    for i in range(cols_):
        t = a0 + (a1 - a0) * i / n
        ct, st = math.cos(t), math.sin(t)
        for (r, z) in prof:
            verts.append((c[0] + r * ct, c[1] + r * st, c[2] + z))
    m = len(prof)
    faces = []
    for i in range(segs):
        i2 = (i + 1) % cols_
        for j in range(m - 1):
            faces.append([i * m + j, i2 * m + j, i2 * m + j + 1, i * m + j + 1])
    extra = []
    if close and full:
        if prof[0][0] > 1e-6:
            extra.append([i * m for i in range(cols_)][::-1])
        if prof[-1][0] > 1e-6:
            extra.append([i * m + m - 1 for i in range(cols_)])
    if M is not None:
        verts = [tuple(M @ Vector(v)) for v in verts]
    base = len(p.v)
    p.v.extend(verts)
    for fc in faces:
        p.f.append(([base + k for k in fc], smooth, None))
    for fc in extra:
        p.f.append(([base + k for k in fc], False, None))


def prism(p, pts, z0, z1, M=None, cap=True, smooth=False):
    """estrusione di un poligono 2D (x, y) da z0 a z1"""
    n = len(pts)
    verts = [(x, y, z0) for x, y in pts] + [(x, y, z1) for x, y in pts]
    if M is not None:
        verts = [tuple(M @ Vector(v)) for v in verts]
    faces = [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    # orientamento: se il poligono e' orario le facce vanno girate
    area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
    if area < 0:
        faces = [f[::-1] for f in faces]
    caps = []
    if cap:
        bot = list(range(n))[::-1]
        top = list(range(n, 2 * n))
        if area < 0:
            bot, top = bot[::-1], top[::-1]
        caps = [bot, top]
    base = len(p.v)
    p.v.extend(verts)
    for fc in faces:
        p.f.append(([base + k for k in fc], smooth, None))
    for fc in caps:
        p.f.append(([base + k for k in fc], False, None))


def sphere(p, c, r, scale=(1, 1, 1), seg=16, rings=10, M=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    bm.transform(Matrix.Diagonal((r * scale[0], r * scale[1], r * scale[2], 1)))
    T = mat4(c) if M is None else M @ mat4(c)
    p.add_bm(bm, T, smooth=True)


def frames(pts, up=Vector((0, 0, 1))):
    """terne lungo una polilinea (trasporto parallelo)"""
    pts = [Vector(q) for q in pts]
    T = []
    for i in range(len(pts)):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        T.append((b - a).normalized())
    n0 = T[0].cross(up)
    if n0.length < 1e-4:
        n0 = T[0].cross(Vector((1, 0, 0)))
    n0.normalize()
    N = [n0]
    for i in range(1, len(pts)):
        n = N[-1] - T[i] * N[-1].dot(T[i])
        if n.length < 1e-6:
            n = N[-1]
        N.append(n.normalized())
    B = [T[i].cross(N[i]) for i in range(len(pts))]
    return pts, T, N, B


def tube(p, pts, r, n=8, taper=None, caps=True, smooth=True, prof=None):
    """tubo lungo una polilinea; r numero o lista; prof = sezione 2D [(x, y)] al posto del cerchio"""
    pts, T, N, B = frames(pts)
    m = len(pts)
    rs = r if hasattr(r, "__len__") else [r] * m
    if taper:
        rs = [rs[i] * (1 - taper * i / (m - 1)) for i in range(m)]
    sec = prof or [(math.cos(2 * math.pi * k / n), math.sin(2 * math.pi * k / n)) for k in range(n)]
    k = len(sec)
    verts = []
    for i in range(m):
        for (sx, sy) in sec:
            verts.append(tuple(pts[i] + (N[i] * sx + B[i] * sy) * rs[i]))
    faces = []
    for i in range(m - 1):
        for j in range(k):
            j2 = (j + 1) % k
            faces.append([i * k + j, i * k + j2, (i + 1) * k + j2, (i + 1) * k + j])
    base = len(p.v)
    p.v.extend(verts)
    for fc in faces:
        p.f.append(([base + q for q in fc], smooth, None))
    if caps:
        if rs[0] > 1e-5:
            p.f.append(([base + j for j in range(k)][::-1], False, None))
        if rs[-1] > 1e-5:
            p.f.append(([base + (m - 1) * k + j for j in range(k)], False, None))
        else:
            pass


def torus(p, c, R, r, normal=(0, 0, 1), nR=12, nr=6, scale=(1, 1)):
    pts = [Vector((R * scale[0] * math.cos(2 * math.pi * i / nR), R * scale[1] * math.sin(2 * math.pi * i / nR), 0)) for i in range(nR)]
    Rm = rot_to(normal)
    pts = [Vector(c) + Rm @ q for q in pts]
    pts.append(pts[0])
    pts2, T, N, B = frames(pts + [pts[1]])
    verts = []
    sec = [(math.cos(2 * math.pi * k / nr), math.sin(2 * math.pi * k / nr)) for k in range(nr)]
    for i in range(nR):
        for (sx, sy) in sec:
            verts.append(tuple(pts2[i] + (N[i] * sx + B[i] * sy) * r))
    base = len(p.v)
    p.v.extend(verts)
    for i in range(nR):
        i2 = (i + 1) % nR
        for j in range(nr):
            j2 = (j + 1) % nr
            p.f.append(([base + i * nr + j, base + i * nr + j2, base + i2 * nr + j2, base + i2 * nr + j], True, None))


def chain(p, a, b, sag=0.0, link=0.35, thick=0.06):
    """catena di anelli da a a b (con abbassamento sag al centro)"""
    a, b = Vector(a), Vector(b)
    L = (b - a).length
    cnt = max(2, int(L / (link * 0.78)))
    pts = []
    for i in range(cnt + 1):
        t = i / cnt
        q = a.lerp(b, t)
        q.z -= sag * 4 * t * (1 - t)
        pts.append(q)
    for i in range(cnt):
        q0, q1 = pts[i], pts[i + 1]
        d = (q1 - q0).normalized()
        side = d.cross(Vector((0, 0, 1)))
        if side.length < 1e-3:
            side = Vector((1, 0, 0))
        side.normalize()
        if i % 2:
            side = d.cross(side).normalized()
        nrm = side
        c = (q0 + q1) / 2
        # anello ovale: asse lungo d, piano che contiene d e perpendicolare a nrm
        Rm = Matrix((d, nrm.cross(d), nrm)).transposed()
        verts = []
        nR, nr = 10, 5
        for k in range(nR):
            t = 2 * math.pi * k / nR
            ctr = Vector((math.cos(t) * link * 0.5, math.sin(t) * link * 0.3, 0))
            tang = Vector((-math.sin(t) * link * 0.5, math.cos(t) * link * 0.3, 0)).normalized()
            out = Vector((tang.y, -tang.x, 0))
            for j in range(nr):
                s = 2 * math.pi * j / nr
                q = ctr + (out * math.cos(s) + Vector((0, 0, 1)) * math.sin(s)) * thick
                verts.append(tuple(c + Rm @ q))
        base = len(p.v)
        p.v.extend(verts)
        for k in range(nR):
            k2 = (k + 1) % nR
            for j in range(nr):
                j2 = (j + 1) % nr
                p.f.append(([base + k * nr + j, base + k2 * nr + j, base + k2 * nr + j2, base + k * nr + j2], True, None))


def meta(p, elems, res=0.25, M=None, thresh=0.6):
    """forma organica da metaball: elems = [(tipo, centro, raggio, (sx, sy, sz), rot, negativo)]
    tipo: BALL, ELLIPSOID, CAPSULE; rot = quaternion/euler (x, y, z) in radianti"""
    mb = bpy.data.metaballs.new("tmp_meta")
    mb.resolution = res
    mb.render_resolution = res
    mb.threshold = thresh
    for e in elems:
        typ, c, r = e[0], e[1], e[2]
        sz = e[3] if len(e) > 3 and e[3] else (1, 1, 1)
        rot = e[4] if len(e) > 4 and e[4] else (0, 0, 0)
        neg = e[5] if len(e) > 5 else False
        el = mb.elements.new()
        el.type = typ
        el.co = c
        el.radius = r
        el.size_x, el.size_y, el.size_z = sz
        from mathutils import Euler
        el.rotation = Euler(rot).to_quaternion()
        el.use_negative = neg
        el.stiffness = 2.0
    ob = bpy.data.objects.new("tmp_meta", mb)
    bpy.context.scene.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = ob.evaluated_get(dg).to_mesh()
    bm = bmesh.new()
    bm.from_mesh(me)
    ob.evaluated_get(dg).to_mesh_clear()
    bpy.data.objects.remove(ob)
    bpy.data.metaballs.remove(mb)
    p.add_bm(bm, M, smooth=True)


def decimate_part(p, ratio):
    """riduce i triangoli di una parte (collapse)"""
    me = bpy.data.meshes.new("tmp_dec")
    me.from_pydata(p.v, [], [f[0] for f in p.f])
    ob = bpy.data.objects.new("tmp_dec", me)
    bpy.context.scene.collection.objects.link(ob)
    mod = ob.modifiers.new("d", "DECIMATE")
    mod.ratio = ratio
    dg = bpy.context.evaluated_depsgraph_get()
    m2 = ob.evaluated_get(dg).to_mesh()
    p.v = [tuple(v.co) for v in m2.vertices]
    p.f = [(list(f.vertices), True, None) for f in m2.polygons]
    ob.evaluated_get(dg).to_mesh_clear()
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)


def boolean(p_target, cutters, op="DIFFERENCE"):
    """applica un booleano (EXACT) alla parte; cutters = Parte con i volumi da togliere"""
    def obj_of(pp, nm):
        me = bpy.data.meshes.new(nm)
        me.from_pydata(pp.v, [], [f[0] for f in pp.f])
        me.update()
        ob = bpy.data.objects.new(nm, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob
    smooth_before = any(f[1] for f in p_target.f)
    a = obj_of(p_target, "tmp_boolA")
    b = obj_of(cutters, "tmp_boolB")
    mod = a.modifiers.new("b", "BOOLEAN")
    mod.operation = op
    mod.solver = "EXACT"
    mod.object = b
    dg = bpy.context.evaluated_depsgraph_get()
    m2 = a.evaluated_get(dg).to_mesh()
    p_target.v = [tuple(v.co) for v in m2.vertices]
    p_target.f = [(list(f.vertices), False, None) for f in m2.polygons]
    a.evaluated_get(dg).to_mesh_clear()
    for ob in (a, b):
        me = ob.data
        bpy.data.objects.remove(ob)
        bpy.data.meshes.remove(me)


def arch_pts(w, h_spring, segs=12, x0=0.0):
    """contorno di un'apertura ad arco a tutto sesto (x, z) dal basso a sinistra, in senso orario"""
    r = w / 2
    pts = [(x0 - r, 0.0)]
    for i in range(segs + 1):
        t = math.pi - math.pi * i / segs
        pts.append((x0 + r * math.cos(t), h_spring + r * math.sin(t)))
    pts.append((x0 + r, 0.0))
    return pts


def arch_cutter(p, x, w, z0, h_spring, y0, y1, segs=12, M=None):
    """volume da togliere per un arco: in piano XZ, profondo da y0 a y1"""
    pts = arch_pts(w, h_spring - z0, segs, x)
    pts = [(a, b + z0) for a, b in pts]
    # prism in XZ: costruisco in (x, z) poi ruoto il piano
    R = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # (x, y, e) -> (x, -e, y), senza specchiare
    MM = (M or Matrix.Identity(4)) @ R
    prism(p, pts, -y1, -y0, MM)


def arch_ring(p, x, w, h_spring, y0, y1, band=0.8, segs=14, M=None, z0=0.0):
    """ghiera dell'arco (conci) sporgente: fascia curva di larghezza band, da y0 a y1"""
    r0 = w / 2
    r1 = r0 + band
    verts, faces = [], []
    for i in range(segs + 1):
        t = math.pi - math.pi * i / segs
        for (r, y) in ((r0, y0), (r1, y0), (r1, y1), (r0, y1)):
            verts.append((x + r * math.cos(t), y, z0 + h_spring + r * math.sin(t)))
    for i in range(segs):
        for j in range(4):
            j2 = (j + 1) % 4
            faces.append([i * 4 + j, (i + 1) * 4 + j, (i + 1) * 4 + j2, i * 4 + j2])
    faces.append([0, 1, 2, 3][::-1])
    faces.append([segs * 4 + k for k in range(4)])
    if M is not None:
        verts = [tuple(M @ Vector(v)) for v in verts]
    base = len(p.v)
    p.v.extend(verts)
    for fc in faces:
        p.f.append(([base + k for k in fc], False, None))


def cornice(p, prof, x0, x1, M=None):
    """modanatura dritta: profilo [(y, z)] (y sporgenza verso -Y) estruso lungo X da x0 a x1"""
    m = len(prof)
    verts = [(x0, -y, z) for (y, z) in prof] + [(x1, -y, z) for (y, z) in prof]
    faces = [[j, j + 1, m + j + 1, m + j] for j in range(m - 1)]
    faces.append(list(range(m)))
    faces.append(list(range(m, 2 * m))[::-1])
    if M is not None:
        verts = [tuple(M @ Vector(v)) for v in verts]
    base = len(p.v)
    p.v.extend(verts)
    for fc in faces:
        p.f.append(([base + k for k in fc], False, None))


def capitello(p, c, r, h=1.0, n=12):
    """base o capitello tondo (toro + abaco)"""
    x, y, z = c
    lathe(p, [(r * 0.0, z), (r * 1.25, z), (r * 1.25, z + h * 0.25), (r * 1.1, z + h * 0.4), (r * 1.18, z + h * 0.55),
              (r * 1.0, z + h * 0.8), (r * 0.95, z + h)], n, (x, y, 0))


# ---------------------------------------------------------------------------------------
# costruzione degli oggetti, UV, esportazione

def _uv_box(co, nrm, tile):
    a = abs(nrm.x), abs(nrm.y), abs(nrm.z)
    if a[2] >= a[0] and a[2] >= a[1]:
        u, v = co.x, co.y * (1 if nrm.z >= 0 else -1)
    elif a[0] >= a[1]:
        u, v = co.y * (1 if nrm.x < 0 else -1), co.z
    else:
        u, v = co.x * (1 if nrm.y >= 0 else -1), co.z
    return (u / tile, v / tile)


def make_material(name, texdir):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    if hasattr(m, "use_nodes") and not m.use_nodes:
        m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    if name in PIANI:
        c, em = PIANI[name]
        bsdf.inputs["Base Color"].default_value = (*c, 1)
        if em:
            bsdf.inputs["Emission Color"].default_value = (*c, 1)
            bsdf.inputs["Emission Strength"].default_value = em
        if name == "MAT_Gold":
            bsdf.inputs["Metallic"].default_value = 1.0
            bsdf.inputs["Roughness"].default_value = 0.35
        return m
    files = texture_files(name, texdir)
    img = nt.nodes.new("ShaderNodeTexImage")
    img.image = bpy.data.images.load(files["BaseColor"], check_existing=True)
    nt.links.new(img.outputs["Color"], bsdf.inputs["Base Color"])
    r = nt.nodes.new("ShaderNodeTexImage")
    r.image = bpy.data.images.load(files["Roughness"], check_existing=True)
    r.image.colorspace_settings.name = "Non-Color"
    nt.links.new(r.outputs["Color"], bsdf.inputs["Roughness"])
    nn = nt.nodes.new("ShaderNodeTexImage")
    nn.image = bpy.data.images.load(files["Normal"], check_existing=True)
    nn.image.colorspace_settings.name = "Non-Color"
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nn.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if name in ("FerroBattuto",):
        bsdf.inputs["Metallic"].default_value = 0.6
    if name in ("OroAntico", "Bronzo"):
        bsdf.inputs["Metallic"].default_value = 0.9
    return m


def build_object(p, coll, texdir, sharp_deg=38):
    me = bpy.data.meshes.new(p.name)
    me.from_pydata(p.v, [], [f[0] for f in p.f])
    me.validate(clean_customdata=False)
    me.update()
    ob = bpy.data.objects.new(p.name, me)
    coll.objects.link(ob)
    mat = make_material(p.mat, texdir)
    me.materials.append(mat)
    # liscio dove serve, spigoli vivi sopra sharp_deg
    sm = [f[1] for f in p.f]
    if len(sm) == len(me.polygons):
        me.polygons.foreach_set("use_smooth", sm)
    me.set_sharp_from_angle(angle=math.radians(sharp_deg))
    # tinta per blocco (kit_pietra): attributo dei vertici "Tinta" (usato dalla cottura dei materiali)
    tint = getattr(p, "tint", None)
    if tint and len(tint) == len(me.vertices):
        at = me.attributes.new("Tinta", "FLOAT", "POINT")
        at.data.foreach_set("value", tint)
    # UV: proiezione a scatola (metri / ripetizione) oppure UV dell'atlante
    tile = MATERIALI.get(p.mat, (None, 4.0))[1] or 1.0
    uvl = me.uv_layers.new(name="UVMap")
    data = uvl.data
    for poly, fsrc in zip(me.polygons, p.f):
        nrm = poly.normal
        for k, li in enumerate(poly.loop_indices):
            if fsrc[2] is not None and k < len(fsrc[2]):
                data[li].uv = fsrc[2][k]
            else:
                co = me.vertices[me.loops[li].vertex_index].co
                data[li].uv = _uv_box(co, nrm, tile)
    return ob


def build_collision(model, coll):
    obs = []
    for name, M in model.cols:
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        me = bpy.data.meshes.new("COL_" + name)
        bm.to_mesh(me)
        bm.free()
        # vertici gia' trasformati (l'importatore li legge in coordinate del mondo)
        me.transform(M)
        ob = bpy.data.objects.new("COL_" + name, me)
        coll.objects.link(ob)
        obs.append(ob)
    return obs


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export(model, quick=False):
    """scrive cloud/<Nome>/<Nome>.fbx, _Collision.fbx, Markers.json, Materials.json, Textures/"""
    out = os.path.join(CLOUD, model.name)
    texdir = os.path.join(out, "Textures")
    os.makedirs(out, exist_ok=True)
    scene = bpy.context.scene
    coll = bpy.data.collections.new(model.name)
    scene.collection.children.link(coll)
    objs = []
    stats = []
    for key in model.order:
        p = model.parts[key]
        if not p.f:
            continue
        ob = build_object(p, coll, texdir)
        t = sum(len(poly.vertices) - 2 for poly in ob.data.polygons)
        stats.append((p.name, p.mat, t, ob))
        objs.append(ob)
    # marcatori come empty
    mk = []
    for name, pos in model.markers:
        e = bpy.data.objects.new(name, None)
        e.empty_display_size = 0.5
        e.location = pos
        coll.objects.link(e)
        mk.append(e)
    ccoll = bpy.data.collections.new(model.name + "_Collision")
    scene.collection.children.link(ccoll)
    cobs = build_collision(model, ccoll)
    ccoll.hide_render = True

    def fbx(path, sel):
        bpy.ops.object.select_all(action="DESELECT")
        for o in sel:
            o.select_set(True)
        bpy.context.view_layer.objects.active = sel[0]
        bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"EMPTY", "MESH"},
                                 axis_forward="-Z", axis_up="Y", apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE",
                                 mesh_smooth_type="OFF", use_mesh_modifiers=True, path_mode="STRIP", add_leaf_bones=False,
                                 use_custom_props=False, bake_anim=False)

    fbx(os.path.join(out, model.name + ".fbx"), objs + mk)
    if cobs:
        fbx(os.path.join(out, model.name + "_Collision.fbx"), cobs)
    markers = [{"name": n, "position_y_up_m": [round(v.x, 3), round(v.z, 3), round(-v.y, 3)]} for n, v in model.markers]
    with open(os.path.join(out, "Markers.json"), "w", encoding="utf-8") as fh:
        json.dump(markers, fh, indent=1)
    mats = []
    for m in sorted(set(s[1] for s in stats)):
        if m in PIANI:
            mats.append({"name": m, "plain": True})
        else:
            mats.append({"name": m, "BaseColor": "Textures/%s_BaseColor.png" % m, "Normal": "Textures/%s_Normal.png" % m,
                         "Roughness": "Textures/%s_Roughness.png" % m})
    with open(os.path.join(out, "Materials.json"), "w", encoding="utf-8") as fh:
        json.dump(mats, fh, indent=1)
    # controlli
    total = sum(s[2] for s in stats)
    print("== %s: %d parti, %d triangoli, %d collisioni, %d marcatori" % (model.name, len(stats), total, len(cobs), len(mk)))
    big = [(s[0], s[2]) for s in stats if s[2] >= 20000]
    for s in stats:
        dims = s[3].dimensions
        if max(dims) >= 2048:
            big.append((s[0], "lato %.0f m" % max(dims)))
    if big:
        print("!! TROPPO GRANDI:", big)
    mins = Vector((1e9, 1e9, 1e9))
    maxs = Vector((-1e9, -1e9, -1e9))
    for s in stats:
        for c in s[3].bound_box:
            w = s[3].matrix_world @ Vector(c)
            mins = Vector(map(min, mins, w))
            maxs = Vector(map(max, maxs, w))
    info = {
        "nome": model.name, "triangoli": total, "parti": [{"nome": s[0], "materiale": s[1], "triangoli": s[2]} for s in stats],
        "ingombro_m": [round(maxs.x - mins.x, 2), round(maxs.y - mins.y, 2), round(maxs.z - mins.z, 2)],
        "min_blender": [round(c, 2) for c in mins], "max_blender": [round(c, 2) for c in maxs],
        "collisioni": len(cobs), "marcatori": [n for n, _ in model.markers],
    }
    info.update(model.notes)
    with open(os.path.join(out, "info.json"), "w", encoding="utf-8") as fh:
        json.dump(info, fh, indent=1)
    return objs, cobs, info


# ---------------------------------------------------------------------------------------
# anteprime (Eevee 1600x900): davanti, dietro, dall'alto, 3/4

def render_previews(model, objs, info, views=("davanti", "dietro", "alto", "tre_quarti"), res=(1600, 900), ground=True,
                    engine="BLENDER_EEVEE", samples=32, extra_views=None):
    out = os.path.join(CLOUD, model.name, "anteprime")
    os.makedirs(out, exist_ok=True)
    scene = bpy.context.scene
    mn = Vector(info["min_blender"])
    mx = Vector(info["max_blender"])
    ctr = (mn + mx) / 2
    size = (mx - mn).length
    # cielo e sole
    world = bpy.data.worlds.new("Cielo")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes.get("Background")
    sky = nt.nodes.new("ShaderNodeTexSky")
    try:
        sky.sky_type = "MULTIPLE_SCATTERING"
    except Exception:
        try:
            sky.sky_type = "NISHITA"
        except Exception:
            pass
    try:
        sky.sun_elevation = math.radians(38)
        sky.sun_rotation = math.radians(200)
    except Exception:
        pass
    nt.links.new(sky.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.25
    sun = bpy.data.objects.new("Sole", bpy.data.lights.new("Sole", "SUN"))
    sun.data.energy = 3.4
    sun.data.color = (1.0, 0.93, 0.82)
    sun.data.angle = math.radians(2)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
    scene.collection.objects.link(sun)
    if ground:
        gm = bpy.data.materials.new("Prato")
        gm.use_nodes = True
        b = gm.node_tree.nodes.get("Principled BSDF")
        b.inputs["Base Color"].default_value = (0.16, 0.20, 0.10, 1)
        b.inputs["Roughness"].default_value = 1.0
        bpy.ops.mesh.primitive_plane_add(size=size * 8, location=(ctr.x, ctr.y, -0.02))
        g = bpy.context.active_object
        g.data.materials.append(gm)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.lens = 35
    cam.data.clip_end = size * 20
    scene.render.engine = engine
    if engine == "CYCLES":
        scene.cycles.samples = samples
        scene.cycles.device = "CPU"
        try:
            scene.cycles.use_denoising = True
        except Exception:
            pass
    else:
        try:
            scene.eevee.taa_render_samples = samples
        except Exception:
            pass
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"

    dist = size * 0.95
    VIEWS = {
        "davanti": (Vector((0, -1, 0.32)), 0),
        "dietro": (Vector((0, 1, 0.32)), 0),
        "alto": (Vector((0.0001, -0.12, 1)), 0),
        "tre_quarti": (Vector((0.75, -0.85, 0.55)), 0),
        "tre_quarti_dietro": (Vector((-0.8, 0.8, 0.5)), 0),
    }
    if extra_views:
        VIEWS.update(extra_views)
    look = ctr.copy()
    done = []
    for v in views:
        spec = VIEWS[v]
        if len(spec) == 2:
            d, _ = spec
            pos = ctr + d.normalized() * dist
            target = look
        else:
            pos, target = Vector(spec[0]), Vector(spec[1])
            if len(spec) > 2:
                cam.data.lens = spec[2]
        cam.location = pos
        dirv = (target - pos).normalized()
        cam.rotation_euler = dirv.to_track_quat("-Z", "Y").to_euler()
        path = os.path.join(out, "%s_%s.png" % (model.name, v))
        scene.render.filepath = path
        t0 = time.time()
        bpy.ops.render.render(write_still=True)
        print("  render %s (%.0fs)" % (v, time.time() - t0))
        cam.data.lens = 35
        done.append(path)
    return done


def argv():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


# ---------------------------------------------------------------------------------------
# draghi scolpiti (metaball + tubi): statue sedute e teste del portale

def _chain_balls(pts, radii, typ="BALL"):
    out = []
    n = len(pts)
    if len(radii) != n:   # raggi dati per pochi punti: interpolati lungo la curva
        rr = list(radii)
        radii = [np.interp(i / (n - 1) * (len(rr) - 1), range(len(rr)), rr) for i in range(n)]
    # palline fitte lungo la curva (interpolate) per un corpo continuo
    for i in range(n - 1):
        a, b = Vector(pts[i]), Vector(pts[i + 1])
        steps = max(1, int((b - a).length / (min(radii[i], radii[i + 1]) * 0.6)))
        for k in range(steps):
            t = k / steps
            out.append((typ, tuple(a.lerp(b, t)), radii[i] * (1 - t) + radii[i + 1] * t))
    out.append((typ, tuple(pts[-1]), radii[-1]))
    return out


def smooth_path(pts, sub=4):
    """curva morbida (Catmull-Rom) per i punti dati"""
    P = [Vector(q) for q in pts]
    out = []
    for i in range(len(P) - 1):
        p0 = P[max(i - 1, 0)]
        p1, p2 = P[i], P[i + 1]
        p3 = P[min(i + 2, len(P) - 1)]
        for k in range(sub):
            t = k / sub
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-1])
    return out


def horn(p, base, pts, r0, M=None, n=8):
    """corno: tubo affusolato lungo una curva morbida"""
    P = smooth_path([base] + pts, 5)
    if M is not None:
        P = [M @ q for q in P]
        s = M.to_scale()[0]
    else:
        s = 1.0
    m = len(P)
    tube(p, P, [r0 * s * (1 - i / (m - 1)) ** 0.9 + 0.002 for i in range(m)], n=n)


def spike(p, base, tip, r, n=6):
    cyl(p, base, tip, r, 0.0, n=n, caps=True)


def wing_folded(p_mem, p_bone, M, side=1):
    """ala ripiegata sul fianco (membrana sottile a festoni + ossa)"""
    S = Vector((0.62 * side, 0.2, 2.7))      # spalla
    W = Vector((0.98 * side, 0.6, 3.55))     # polso (in alto)
    tips = [Vector((0.95 * side, 1.65, 1.6)), Vector((1.08 * side, 1.3, 1.0)), Vector((1.02 * side, 0.8, 0.85))]
    base_back = Vector((0.7 * side, 1.05, 2.2))
    for a, b in ((S, W),):
        tube(p_bone, [M @ q for q in smooth_path([a, (a + b) / 2 + Vector((0.12 * side, 0, 0.1)), b], 3)], 0.11 * M.to_scale()[0], n=6)
    for t in tips:
        tube(p_bone, [M @ q for q in smooth_path([W, (W + t) / 2 + Vector((0.1 * side, 0.05, 0)), t], 3)],
             [0.075 * M.to_scale()[0] * (1 - k / 6) + 0.01 for k in range(7)], n=5)
    # membrana: ventaglio dal polso, bordo a festoni fra le dita
    edge = [base_back, tips[0]]
    for i in range(len(tips) - 1):
        mid = (tips[i] + tips[i + 1]) / 2
        mid = W.lerp(mid, 0.8)
        edge += [mid, tips[i + 1]]
    mid = W.lerp((tips[-1] + S) / 2, 0.85)
    edge += [mid, S]
    nrm = Vector((side, 0, 0))
    th = 0.035
    verts = []
    ring = [W] + edge
    for q in ring:
        verts.append(tuple(M @ (q + nrm * th)))
    for q in ring:
        verts.append(tuple(M @ (q - nrm * th)))
    n = len(ring)
    faces = []
    for i in range(1, n - 1):
        faces.append([0, i, i + 1] if side > 0 else [0, i + 1, i])
        faces.append([n, n + i + 1, n + i] if side > 0 else [n, n + i, n + i + 1])
    base = len(p_mem.v)
    p_mem.v.extend(verts)
    for fc in faces:
        p_mem.f.append(([base + k for k in fc], True, None))


def drago_seduto(p_body, p_detail, M, el=None, p_gold=None, p_eye=None, res=0.07, target=11000):
    """drago seduto sulle zampe posteriori, alto ~5 unita' (M scala e piazza), muso verso -Y.
    p_body: corpo (metaball, poi decimato); p_detail: corna, aculei, ali; p_gold: accenti; p_eye: occhi"""
    E = []
    E.append(("ELLIPSOID", (0, 0.55, 1.05), 1.0, (1.05, 1.15, 0.85)))          # bacino
    for sx in (-1, 1):
        E.append(("ELLIPSOID", (0.82 * sx, 0.35, 0.95), 0.85, (0.65, 1.0, 0.85), (0.3, 0, 0)))   # cosce
        E += _chain_balls(smooth_path([(0.85 * sx, 0.2, 0.75), (0.95 * sx, -0.1, 0.4), (0.97 * sx, -0.4, 0.2)], 2), [0.5, 0.36, 0.3])
        E.append(("ELLIPSOID", (0.97 * sx, -0.45, 0.17), 0.42, (0.75, 1.3, 0.4)))             # piedi dietro
        E += _chain_balls(smooth_path([(0.48 * sx, -0.4, 2.05), (0.56 * sx, -0.72, 1.3), (0.52 * sx, -0.86, 0.55), (0.5 * sx, -0.95, 0.2)], 2),
                          [0.44, 0.33, 0.27, 0.25])                                            # zampa davanti
        E.append(("ELLIPSOID", (0.5 * sx, -1.05, 0.14), 0.33, (0.85, 1.3, 0.45)))               # piede davanti
    E.append(("ELLIPSOID", (0, -0.15, 2.1), 0.95, (0.85, 0.8, 1.25), (-0.35, 0, 0)))          # torace
    E.append(("ELLIPSOID", (0, -0.45, 2.0), 0.6, (0.8, 0.6, 1.1), (-0.35, 0, 0)))             # petto
    neck = smooth_path([(0, -0.2, 2.75), (0, -0.25, 3.25), (0, -0.42, 3.7), (0, -0.72, 4.0)], 3)
    E += _chain_balls(neck, [0.62 - 0.17 * i / (len(neck) - 1) for i in range(len(neck))])
    E.append(("ELLIPSOID", (0, -0.98, 4.25), 0.6, (0.85, 1.15, 0.8)))        # cranio
    E.append(("ELLIPSOID", (0, -1.72, 4.17), 0.46, (0.66, 1.6, 0.46), (0.08, 0, 0)))    # muso
    E.append(("ELLIPSOID", (0, -1.55, 3.84), 0.4, (0.66, 1.55, 0.34), (0.3, 0, 0)))    # mascella
    for sx in (-1, 1):
        E.append(("ELLIPSOID", (0.25 * sx, -1.1, 4.5), 0.22, (1.0, 1.6, 0.6)))         # arcata
        E.append(("ELLIPSOID", (0.36 * sx, -0.95, 4.02), 0.26, (0.8, 1.2, 0.9)))       # guancia
        E.append(("ELLIPSOID", (0.17 * sx, -2.3, 4.25), 0.11, (1.0, 1.0, 0.8)))         # narice
    E.append(("ELLIPSOID", (0, -1.95, 3.99), 0.22, (1.1, 1.8, 0.3), (0.2, 0, 0), True))  # bocca socchiusa
    tail = smooth_path([(0, 1.45, 0.45), (0.85, 1.75, 0.32), (1.65, 1.1, 0.26), (1.85, 0.0, 0.22), (1.5, -0.95, 0.2), (0.85, -1.4, 0.18)], 4)
    E += _chain_balls(tail, [0.5 * (1 - i / len(tail)) + 0.12 for i in range(len(tail))])
    tmp = Part("tmp", p_body.mat)
    meta(tmp, E, res=res, thresh=0.6)
    if tmp.tris() > target:
        decimate_part(tmp, target / tmp.tris())
    T = M
    tmp.v = [tuple(T @ Vector(v)) for v in tmp.v]
    base = len(p_body.v)
    p_body.v.extend(tmp.v)
    p_body.f.extend([([base + k for k in f[0]], True, None) for f in tmp.f])
    sc = M.to_scale()[0]
    # corna (all'indietro, curve) e aculei sulla schiena
    for sx in (-1, 1):
        horn(p_detail, Vector((0.18 * sx, -0.95, 4.42)), [Vector((0.3 * sx, -0.55, 4.86)), Vector((0.4 * sx, -0.05, 4.98)), Vector((0.43 * sx, 0.25, 4.85))], 0.15, M)
        horn(p_detail, Vector((0.32 * sx, -0.8, 4.22)), [Vector((0.62 * sx, -0.5, 4.38)), Vector((0.74 * sx, -0.28, 4.3))], 0.08, M)
    spine = smooth_path([(0, -0.55, 4.55), (0, -0.3, 4.05), (0, -0.05, 3.5), (0, 0.15, 2.95), (0, 0.55, 2.5), (0, 0.95, 1.95), (0, 1.35, 1.35), (0, 1.75, 0.65)], 2)
    for i, q in enumerate(spine[3:-1]):
        q = Vector(q)
        d = Vector((0, 0.55, 0.85)).normalized()
        h = 0.32 * (1 - abs(i - len(spine) / 2) / len(spine))
        cyl(p_detail, M @ (q - d * 0.1), M @ (q + d * h + Vector((0, 0.12, 0))), 0.1 * sc, 0.0, n=5)
    for sx in (-1, 1):
        wing_folded(p_detail, p_detail, M, sx)
        # artigli
        for k in (-1, 0, 1):
            spike(p_detail, M @ Vector((0.5 * sx + 0.12 * k, -1.2, 0.12)), M @ Vector((0.5 * sx + 0.14 * k, -1.42, 0.02)), 0.05 * sc, 5)
            spike(p_detail, M @ Vector((0.95 * sx + 0.14 * k, -0.85, 0.12)), M @ Vector((0.95 * sx + 0.16 * k, -1.08, 0.02)), 0.055 * sc, 5)
    if p_eye is not None:
        for sx in (-1, 1):
            sphere(p_eye, M @ Vector((0.33 * sx, -1.3, 4.38)), 0.05 * sc, seg=8, rings=5)
    # accenti per elemento (oro o pietra)
    pa = p_gold if p_gold is not None else p_detail
    if el == "Eclissi":
        torus(pa, M @ Vector((0, 0.05, 4.4)), 0.95 * sc, 0.07 * sc, normal=(0, 1, 0.15), nR=28, nr=6)
    elif el == "Cosmico":
        for k in range(5):
            a = k * 2 * math.pi / 5
            sphere(pa, M @ Vector((0.0 + 0.35 * math.cos(a), -0.72 + 0.1 * math.sin(a), 2.25 + 0.35 * math.sin(a))), 0.07 * sc, seg=6, rings=4)
    elif el == "Gelo":
        for k in range(6):
            q = Vector((0.22 * ((k % 2) * 2 - 1), 0.75 + 0.2 * k, 2.55 - 0.3 * k))
            cyl(pa, M @ q, M @ (q + Vector((0.12 * ((k % 2) * 2 - 1), 0.25, 0.5))), 0.09 * sc, 0.0, n=4)
    elif el == "Fulmine":
        for sx in (-1, 1):
            zz = [Vector((0.25 * sx, -0.75, 4.5)), Vector((0.45 * sx, -0.55, 4.9)), Vector((0.32 * sx, -0.3, 4.95)), Vector((0.55 * sx, -0.05, 5.35))]
            for a, b in zip(zz, zz[1:]):
                cyl(pa, M @ a, M @ b, 0.05 * sc, 0.04 * sc, n=5)
    elif el == "Roccia":
        for k in range(5):
            q = Vector((0.0, 0.25 + 0.25 * k, 2.85 - 0.38 * k))
            box(pa, M @ q, (0.5 * sc, 0.35 * sc, 0.18 * sc), rot=Matrix.Rotation(-0.6, 3, "X") @ M.to_3x3().normalized(), bev=0.04 * sc)
    elif el == "Gas":
        for k, (dx, dz, r) in enumerate(((0.3, 2.9, 0.13), (-0.25, 2.5, 0.1), (0.15, 2.2, 0.08), (-0.1, 3.3, 0.09))):
            sphere(pa, M @ Vector((dx, 0.55 + 0.1 * k, dz)), r * sc, seg=8, rings=6)
    elif el == "Tempesta":
        for sx in (-1, 1):
            horn(pa, Vector((0.3 * sx, -0.6, 4.25)), [Vector((0.7 * sx, -0.35, 4.3)), Vector((0.95 * sx, 0.1, 4.45)), Vector((1.1 * sx, 0.45, 4.8))], 0.05, M, n=5)
    elif el == "Ossa":
        for k in range(4):
            q = Vector((0, -0.35, 1.7 + 0.22 * k))
            torus(pa, M @ q, (0.62 - 0.04 * k) * sc, 0.035 * sc, normal=(0, 0, 1), nR=16, nr=4, scale=(1.0, 0.7))


# ---------------------------------------------------------------------------------------
# anatomia procedurale della skill roblox-reference-modeling (.claude/skills/.../anatomy_lib.py):
# cranio, mascella, denti, corna, vertebre, costole, ossa delle ali, membrane.

SKILL_SCRIPTS = os.path.join(REPO, ".claude", "skills", "roblox-reference-modeling", "scripts")


def anatomia(cfg, M, pick, detail=1.0, smooth=True, mirror=False):
    """genera i componenti di cfg (formato dragon_anatomy.json) e li aggiunge alle Parti.
    pick(key, role, name) -> Parte (o None per scartare). M: trasformazione (scala e posizione)."""
    if SKILL_SCRIPTS not in sys.path:
        sys.path.insert(0, SKILL_SCRIPTS)
    import anatomy_lib as al
    lm = al.Landmarks(cfg.get("landmarks", {}))
    joints, chains = al.resolve_joints(cfg.get("joints", {}), lm)
    ctx = {"detail": detail, "chains": chains, "components": cfg["components"],
           "name": lambda base, side: "A_" + base + ("_" + side if side else "")}
    count = 0
    for key, spec in cfg["components"].items():
        if spec.get("enabled", True) is False:
            continue
        for part in al.generate_component(key, spec, lm, ctx):
            p = pick(key, part["role"], part["name"])
            if p is None:
                continue
            base = len(p.v)
            for v in part["verts"]:
                w = M @ Vector(v)
                p.v.append((-w.x, w.y, w.z) if mirror else tuple(w))
            for f in part["faces"]:
                fc = [base + i for i in f]
                p.f.append((fc[::-1] if mirror else fc, smooth, None))
            count += 1
    return count
