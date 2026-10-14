# Modelli della mappa (docs/CLOUD_SESSIONE.md v2, sezione 5), uno alla volta:
#   blender -b --factory-startup --python tools/blender/mappa.py -- --modello PosatoioDrago [--render] [--sagoma]
# Scrive cloud/<Nome>/ (FBX, collisioni, marcatori, texture cotte, anteprime JPG).
# Assi: Blender Z in alto, il davanti guarda -Y (= +Z di Roblox). Metri, origine a terra.

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cloud_lib as L
from cloud_lib import Vector, Matrix
import kit_pietra as K
import organico as O

MODELLI = {}


def modello(fn):
    MODELLI[fn.__name__] = fn
    return fn


# ---------------------------------------------------------------------------------------------
@modello
def PosatoioDrago(m):
    """trespolo per draghi adulti: tronco nodoso potato, base di pietra a filari, catena all'anello"""
    rng = random.Random(11)
    pb = m.part("Posatoio_Base", "Granito")
    pt = m.part("Posatoio_Tronco", "Corteccia")
    pc = m.part("Posatoio_Tagli", "LegnoTaglio")
    pf = m.part("Posatoio_Ferro", "FerroBattuto")
    # base ottagonale: tre filari da 0,3 m a scarpa, lastre di copertina
    for i, r in enumerate((1.8, 1.72, 1.64)):
        K.ring_ashlar(pb, Matrix.Identity(4), r, r, 0.3 * i - (0.3 if i == 0 else 0.0), 0.3 * (i + 1), rng,
                      course=0.3 if i else 0.6, depth=0.5, bev=0.04, lmin=2.4, lmax=3.8)
    for k in range(8):
        a = 2 * math.pi * (k + 0.5) / 8
        rot = Matrix.Rotation(a + math.pi / 2, 3, "Z")
        K._block(pb, Vector((1.05 * math.cos(a), 1.05 * math.sin(a), 0.84)), (2 * 1.6 * math.tan(math.pi / 8) + 0.02, 1.15, 0.14), rot, 0.03,
                 rng.random(), chip=0.3 if rng.random() < 0.4 else 0.0, rng=rng, vis=((0, 0, 1), (0, -1, 0)), drop=((0, 0, -1),))
    K.tint_fill(pb)
    L.lathe(pb, [(0.0, 0.9), (0.55, 0.9), (0.55, 0.8)], 8, smooth=False, close=False)
    K.tint_fill(pb)
    # tronco: un po' storto, radici a contrafforte che abbracciano la copertina
    pts = [(0, 0, 0.75), (0.05, 0.02, 1.6), (0.2, -0.06, 2.8), (0.12, 0.08, 3.9), (0.2, 0.04, 4.8), (0.22, 0.0, 5.35)]
    O.tronco(pt, pts, [0.62, 0.44, 0.38, 0.34, 0.3, 0.27], seed=3, nseg=24, sub=4, bark=0.06, flare=0.9, flare_lobes=5, flare_pow=3,
             knots=[(0.3, 1.0, 0.25, 0.5), (0.55, 3.6, 0.22, 0.45), (0.78, 5.2, 0.2, 0.4)], tile=1.6, cap_part=pc)
    # posatoio: ramo grosso che esce di lato e sale un poco (il drago lo stringe), tagliato in punta;
    # dall'altra parte un ramo piu' corto che sale (forma a Y, albero morto potato)
    top = Vector((-0.75, 0.05, 5.35))
    O.tronco(pt, [Vector((0.1, 0.0, 4.75)), Vector((-0.4, 0.02, 5.15)), Vector((-1.1, 0.06, 5.4)), Vector((-1.75, 0.1, 5.55))],
             [0.26, 0.23, 0.2, 0.17], seed=4, nseg=16, sub=4, bark=0.04, tile=1.6, cap_part=pc, twist=0.2,
             knots=[(0.55, 4.5, 0.15, 0.6)])
    O.tronco(pt, [Vector((0.3, 0.0, 5.0)), Vector((0.65, 0.12, 5.55)), Vector((0.95, 0.25, 6.0))],
             [0.2, 0.17, 0.14], seed=5, nseg=12, sub=3, bark=0.03, tile=1.6, cap_part=pc)
    # monconi dei rami tagliati
    for (z, a, ln, r, up) in ((2.2, 0.6, 0.65, 0.17, 0.35), (3.3, 3.4, 0.8, 0.15, 0.5), (4.1, 1.9, 0.55, 0.13, 0.3), (1.6, 4.8, 0.45, 0.14, 0.2)):
        d = Vector((math.cos(a), math.sin(a), up)).normalized()
        b = Vector((0.12, 0.0, z))
        rt = 0.62 - (z - 0.75) * 0.075            # raggio del tronco a quella quota: il moncone deve uscirne
        ln += rt
        O.tronco(pt, [b, b + d * (rt * 0.8), b + d * ln + Vector((0, 0, 0.05))], [r * 1.4, r * 1.15, r], seed=int(z * 10), nseg=10, sub=2,
                 bark=0.02, tile=1.6, cap_part=pc)
    # collari di ferro con i ribattini dove il drago stringe
    for z, rr in ((3.6, 0.4), (4.5, 0.36)):
        c = Vector((0.15, 0.06, z))
        L.lathe(pf, [(rr, -0.09), (rr + 0.035, -0.08), (rr + 0.035, 0.08), (rr, 0.09)], 18, c=c, smooth=False, close=False)
        for k in range(8):
            a = 2 * math.pi * k / 8
            L.sphere(pf, c + Vector((math.cos(a), math.sin(a), 0)) * (rr + 0.04), 0.025, seg=6, rings=4)
    c = Vector((-1.2, 0.07, 5.44))                 # fascia sul ramo del posatoio
    L.lathe(pf, [(0.22, -0.07), (0.25, -0.06), (0.25, 0.06), (0.22, 0.07)], 14, smooth=False, close=False,
            M=Matrix.Translation(c) @ Matrix.Rotation(math.pi / 2 - 0.25, 4, "Y"))
    # anello sul ramo, catena fino all'anello nella base
    a0 = Vector((-1.45, 0.08, 5.3))
    L.torus(pf, a0 + Vector((0, 0, -0.1)), 0.11, 0.025, normal=(1, 0, 0), nR=12, nr=5)
    ring = Vector((-1.25, -0.6, 0.86))
    L.torus(pf, ring + Vector((0, 0, 0.12)), 0.16, 0.03, normal=(1, 0, 0), nR=14, nr=5)
    L.box(pf, ring + Vector((0, 0, 0.0)), (0.12, 0.08, 0.06))
    L.chain(pf, a0 + Vector((0, 0, -0.2)), ring + Vector((0, 0, 0.28)), sag=0.35, link=0.2, thick=0.022)
    # graffi degli artigli sul ramo: tagli chiari (legno nudo) a gruppi di tre
    for sx in (-0.95, -0.5):
        for k in range(3):
            q = Vector((sx + k * 0.07, -0.13, 5.38 + 0.0))
            L.box(pc, q, (0.025, 0.05, 0.3), rot=Matrix.Rotation(0.4, 3, "Y"), uv=None)
    m.marker("SPOT_Posatoio", Vector((-1.0, 0.06, 5.75)))
    for k, r in enumerate((0.0, math.pi / 4)):
        m.col("Base%d" % k, (0, 0, 0.45), (3.4, 3.4, 0.9), Matrix.Rotation(r + math.pi / 8, 3, "Z"))
    m.col("Tronco", (0.12, 0.0, 3.2), (0.75, 0.75, 4.6))
    m.col("Ramo", Vector((-0.85, 0.05, 5.3)), (1.9, 0.45, 0.45), Matrix.Rotation(-0.2, 3, "Y"))
    m.notes.update({"misure_m": "4 x 6 x 4", "marcatori": ["SPOT_Posatoio"]})


# ---------------------------------------------------------------------------------------------
def pesce(pp, pf, M, ln, seed):
    """pesce intero (corpo affusolato, coda, pinne), lungo ln, sdraiato su un fianco se M lo gira"""
    r = random.Random(seed)
    k = ln / 1.0
    prof = [(0.0, 0.0, 0.0, 0.0), (0.04 * k, 0.04 * k, 0.05 * k, 0.0), (0.12 * k, 0.07 * k, 0.1 * k, 0.005 * k),
            (0.3 * k, 0.085 * k, 0.13 * k, 0.01 * k), (0.5 * k, 0.075 * k, 0.12 * k, 0.01 * k), (0.7 * k, 0.05 * k, 0.08 * k, 0.005 * k),
            (0.84 * k, 0.025 * k, 0.04 * k, 0.0), (0.88 * k, 0.015 * k, 0.025 * k, 0.0)]
    bend = r.uniform(-0.25, 0.25)
    Mb = M @ Matrix.Rotation(bend * 0.3, 4, "Z")
    O.loft(pp, Mb, prof, n=10)
    O.pinna(pf, Mb, [(0.86 * k, 0.0), (1.0 * k, 0.12 * k), (0.96 * k, 0.0), (1.0 * k, -0.11 * k)], th=0.004 * k + 0.002)
    O.pinna(pf, Mb, [(0.3 * k, 0.12 * k), (0.42 * k, 0.2 * k), (0.6 * k, 0.11 * k)], th=0.003 * k + 0.002)
    O.pinna(pf, Mb, [(0.55 * k, -0.1 * k), (0.62 * k, -0.15 * k), (0.7 * k, -0.07 * k)], th=0.003 * k + 0.002)


def bistecca(pc, po, M, ln, seed, osso=True):
    """pezzo di carne con l'osso che spunta (coscia)"""
    r = random.Random(seed)
    prof = [(0.0, 0.0, 0.0, 0.0), (0.05 * ln, 0.12 * ln, 0.09 * ln, 0.0), (0.25 * ln, 0.22 * ln, 0.15 * ln, 0.01 * ln),
            (0.5 * ln, 0.24 * ln, 0.16 * ln, 0.0), (0.72 * ln, 0.17 * ln, 0.12 * ln, 0.0), (0.82 * ln, 0.08 * ln, 0.07 * ln, 0.0),
            (0.86 * ln, 0.0, 0.0, 0.0)]
    prof = [(x, ry * r.uniform(0.9, 1.1), rz * r.uniform(0.9, 1.1), dz) for (x, ry, rz, dz) in prof]
    O.loft(pc, M, prof, n=12)
    if osso:
        O.loft(po, M, [(0.78 * ln, 0.0, 0.0, 0.0), (0.8 * ln, 0.04 * ln, 0.04 * ln, 0.0), (1.05 * ln, 0.035 * ln, 0.035 * ln, 0.0),
                       (1.12 * ln, 0.06 * ln, 0.055 * ln, 0.0), (1.18 * ln, 0.05 * ln, 0.05 * ln, 0.0), (1.2 * ln, 0.0, 0.0, 0.0)], n=8)


@modello
def MangiatoiaDrago(m):
    """mangiatoia di pietra per draghi: vasca del cibo (pesci, carne) e abbeveratoio, su zoccoli"""
    rng = random.Random(21)
    ps = m.part("Mangiatoia_Pietra", "Granito")
    pw = m.part("Mangiatoia_Acqua", "MAT_Water")
    pp = m.part("Mangiatoia_Pesci", "Pesce")
    pf = m.part("Mangiatoia_Pinne", "Pesce")
    pc = m.part("Mangiatoia_Carne", "Carne")
    po = m.part("Mangiatoia_Ossa", "OssoDrago")
    pi = m.part("Mangiatoia_Ferro", "FerroBattuto")
    D, H = 1.6, 1.2
    # due vasche: cibo (x -2,5..0,4) e acqua (0,5..2,5), pareti di lastre spesse 0,22 m
    for (x0, x1, fondo) in ((-2.5, 0.42, 0.55), (0.52, 2.5, 0.45)):
        t = 0.22
        for sy in (-1, 1):   # pareti lunghe (fronte e retro): due lastre ciascuna
            xm = x0 + (x1 - x0) * rng.uniform(0.4, 0.6)
            for a, b in ((x0, xm), (xm, x1)):
                K._block(ps, Vector(((a + b) / 2, sy * (D / 2 - t / 2), 0.35 + (H - 0.35) / 2)), (b - a - 0.015, t, H - 0.35), None, 0.04,
                         rng.random(), chip=0.35 if rng.random() < 0.6 else 0.0, rng=rng)
        for xx in (x0 + t / 2, x1 - t / 2):    # testate
            K._block(ps, Vector((xx, 0, 0.35 + (H - 0.35) / 2)), (t, D - 2 * t - 0.015, H - 0.35), None, 0.04, rng.random(),
                     chip=0.3, rng=rng)
        K._block(ps, Vector(((x0 + x1) / 2, 0, 0.35 + fondo / 2 - 0.1)), (x1 - x0 - 2 * t, D - 2 * t, fondo - 0.2 + 0.2), None, 0.03,
                 rng.random())
    # bordo superiore smussato (labbro) e zoccoli
    for (x0, x1) in ((-2.5, 0.42), (0.52, 2.5)):
        for sy in (-1, 1):
            K._block(ps, Vector(((x0 + x1) / 2, sy * (D / 2 - 0.12), H + 0.04)), (x1 - x0 + 0.06, 0.3, 0.1), None, 0.03, rng.random(),
                     chip=0.4 if rng.random() < 0.5 else 0.0, rng=rng)
    for x in (-2.2, -0.9, 0.47, 1.8):
        K._block(ps, Vector((x, 0, 0.175)), (0.55, D - 0.1, 0.35), None, 0.04, rng.random(), chip=0.3, rng=rng, drop=((0, 0, -1),))
    K.tint_fill(ps)
    # acqua
    L.boxz(pw, 0.74, 2.28, -D / 2 + 0.22, D / 2 - 0.22, 0.6, 1.05)
    m.marker("FX_Light_Acqua", (1.5, 0, 1.06))
    # fasce di ferro agli angoli delle vasche
    for x in (-2.5, 0.42, 0.52, 2.5):
        for sy in (-1, 1):
            L.box(pi, (x, sy * D / 2, H - 0.25), (0.16, 0.03, 0.45), rot=None)
            L.box(pi, (x, sy * (D / 2 - 0.11), H + 0.1), (0.16, 0.25, 0.03))
    # cibo: mucchio di pesci e carne nella vasca grande
    fz = 0.35 + 0.55
    for i in range(13):
        x = rng.uniform(-2.1, -0.4)
        y = rng.uniform(-0.4, 0.4)
        z = fz + 0.08 + 0.06 * (i % 4)
        a = rng.uniform(0, 2 * math.pi)
        M = Matrix.Translation((x, y, z)) @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(math.pi / 2 * rng.choice((1, -1)), 4, "X") @ \
            Matrix.Translation((-0.35, 0, 0))
        pesce(pp, pf, M, rng.uniform(0.55, 0.8), i)
    # un pesce che pende dal bordo, due cosce e un costato
    M = Matrix.Translation((-1.4, -D / 2 + 0.05, H + 0.05)) @ Matrix.Rotation(-1.3, 4, "X") @ Matrix.Rotation(math.pi / 2, 4, "Z") @ \
        Matrix.Rotation(math.pi / 2, 4, "X")
    pesce(pp, pf, M, 0.7, 99)
    for i, (x, y, a) in enumerate(((-1.6, 0.15, 0.4), (-0.85, -0.2, 2.6))):
        M = Matrix.Translation((x, y, fz + 0.28)) @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(0.25, 4, "Y") @ Matrix.Translation((-0.35, 0, 0))
        bistecca(pc, po, M, 0.75, i)
    # costato: carne e costole curve
    c = Vector((-2.0, -0.1, fz + 0.25))
    O.loft(pc, Matrix.Translation(c) @ Matrix.Rotation(0.3, 4, "Z"), [(-0.3, 0.0, 0.0, 0.0), (-0.25, 0.2, 0.07, 0.0), (0.3, 0.22, 0.08, 0.0), (0.35, 0.0, 0.0, 0.0)], n=10)
    for k in range(5):
        x = -0.22 + k * 0.11
        q0 = c + Matrix.Rotation(0.3, 3, "Z") @ Vector((x, -0.2, 0.05))
        q1 = c + Matrix.Rotation(0.3, 3, "Z") @ Vector((x, 0.0, 0.18))
        q2 = c + Matrix.Rotation(0.3, 3, "Z") @ Vector((x, 0.22, 0.04))
        L.tube(po, L.smooth_path([q0, q1, q2], 3), 0.022, n=6, taper=0.3)
    # riquadri in rilievo sui fianchi lunghi (cornice di pietra) e anelli di ferro per legare
    for (x0, x1) in ((-2.5, 0.42), (0.52, 2.5)):
        for sy in (-1, 1):
            Mfr = Matrix.Translation((0, sy * D / 2, 0)) @ Matrix.Rotation(0 if sy < 0 else math.pi, 4, "Z")
            xa, xb = (x0 + 0.3, x1 - 0.3) if sy < 0 else (-x1 + 0.3, -x0 - 0.3)
            for z in (0.55, H - 0.2):
                K._block(ps, Mfr @ Vector(((xa + xb) / 2, -0.03, z)), (xb - xa, 0.08, 0.09), Mfr.to_3x3(), 0.025, rng.random())
            for x in (xa, xb):
                K._block(ps, Mfr @ Vector((x, -0.03, (0.55 + H - 0.2) / 2)), (0.09, 0.08, H - 0.2 - 0.55), Mfr.to_3x3(), 0.025, rng.random())
            K.tint_fill(ps)
            L.torus(pi, Mfr @ Vector(((xa + xb) / 2, -0.12, 0.82)), 0.09, 0.018, normal=Mfr.to_3x3() @ Vector((1, 0, 0)), nR=12, nr=4)
            L.box(pi, Mfr @ Vector(((xa + xb) / 2, -0.07, 0.92)), (0.06, 0.06, 0.06))
    m.notes["viste_extra"] = {"dettaglio": ((-0.6, -2.2, 2.4), (-1.3, 0.0, 0.9), 35)}
    m.marker("SPOT_Cibo", (-1.2, 0, 1.3))
    m.marker("SPOT_Acqua", (1.5, 0, 1.3))
    m.col("Vasche", (0, 0, H / 2 + 0.05), (5.0, D, H + 0.1))
    m.notes.update({"misure_m": "5 x 1,2 x 1,6"})


# ---------------------------------------------------------------------------------------------
def corda(p, pts, r=0.022, n=6):
    L.tube(p, L.smooth_path([Vector(q) for q in pts], 3), r, n=n)


@modello
def PonteTibetano(m):
    """ponte sospeso: tratto modulare di 6 m (assi su due funi portanti, corrimano di corda, pendini)
    e una testata (due pali con traverso, basamento di pietra, funi avvolte). Il ponte corre lungo Y."""
    rng = random.Random(31)
    pa = m.part("Ponte_Tratto_Assi", "LegnoAsse")
    pc = m.part("Ponte_Tratto_Corde", "Corda")
    pf = m.part("Ponte_Tratto_Ferro", "FerroBattuto")
    LEN, W, HR = 6.0, 2.0, 1.1
    sag = 0.06                          # piccola freccia anche nel tratto (i tratti si attaccano ai capi)
    zf = lambda y: -sag * (1 - (2 * y / LEN) ** 2)
    # assi: larghe 0,22-0,3, qualcuna storta, rotta o mancante
    y = -LEN / 2 + 0.02
    while y < LEN / 2 - 0.15:
        w = rng.uniform(0.22, 0.3)
        if rng.random() > 0.05:
            ln = 1.7 + rng.uniform(-0.06, 0.06) - (0.5 if rng.random() < 0.04 else 0.0)
            rot = Matrix.Rotation(rng.uniform(-0.03, 0.03), 3, "Z") @ Matrix.Rotation(rng.uniform(-0.02, 0.02), 3, "Y")
            K._block(pa, Vector((rng.uniform(-0.04, 0.04), y + w / 2, zf(y) + 0.02)), (ln, w - 0.02, 0.05), rot, 0.012, rng.random(),
                     chip=0.4 if rng.random() < 0.25 else 0.0, rng=rng)
        y += w + rng.uniform(0.03, 0.07)
    # due correnti di legno sotto le assi (dove si legano)
    for sx in (-0.62, 0.62):
        K._block(pa, Vector((sx, 0, zf(0) - 0.06)), (0.1, LEN, 0.08), None, 0.015, rng.random())
    K.tint_fill(pa)
    # funi portanti (sotto, doppie), corrimano, pendini a V ogni 0,6 m, rete laterale rada
    for sx in (-1, 1):
        for dx in (0.78, 0.86):
            corda(pc, [(sx * dx, yy, zf(yy) - 0.04) for yy in (-LEN / 2, -LEN / 4, 0, LEN / 4, LEN / 2)], r=0.025)
        hand = [(sx * W / 2, yy, HR + zf(yy) * 0.5) for yy in (-LEN / 2, -LEN / 4, 0, LEN / 4, LEN / 2)]
        corda(pc, hand, r=0.03)
        yy = -LEN / 2 + 0.3
        while yy < LEN / 2:
            top = Vector((sx * W / 2, yy, HR + zf(yy) * 0.5 - 0.02))
            bot = Vector((sx * 0.82, yy, zf(yy) - 0.03))
            corda(pc, [top, top.lerp(bot, 0.5) + Vector((sx * 0.03, 0, 0)), bot], r=0.012, n=5)
            if rng.random() < 0.8:          # diagonale della rete
                bot2 = Vector((sx * 0.82, yy + 0.3, zf(yy + 0.3) - 0.03))
                corda(pc, [top.lerp(bot, 0.45), bot2.lerp(top, 0.0)], r=0.008, n=4)
            # legature sulle assi (anelli di corda)
            L.torus(pc, Vector((sx * 0.62, yy, zf(yy) - 0.03)), 0.07, 0.012, normal=(0, 1, 0), nR=8, nr=4)
            yy += 0.6
    # moschettoni / grilli ai capi (per attaccare il tratto successivo)
    for sy in (-1, 1):
        for sx in (-1, 1):
            for (x, z) in ((sx * W / 2, HR), (sx * 0.82, -0.04)):
                L.torus(pf, Vector((x, sy * LEN / 2, z)), 0.05, 0.012, normal=(1, 0, 0), nR=10, nr=4)
    m.marker("SPOT_Inizio", (0, -LEN / 2, 0.05))
    m.marker("SPOT_Fine", (0, LEN / 2, 0.05))
    m.col("Piano", (0, 0, -0.03), (1.8, LEN, 0.1))
    for sx in (-1, 1):
        m.col("Sponda%d" % sx, (sx * W / 2, 0, 0.55), (0.1, LEN, 1.1))
    # --- testata (a parte, a 1,5 m dal capo del tratto): pali, traverso, basamento, funi agli ancoraggi
    pt = m.part("Ponte_Testa_Legno", "LegnoAsse")
    ps = m.part("Ponte_Testa_Pietra", "Granito")
    pk = m.part("Ponte_Testa_Corde", "Corda")
    pz = m.part("Ponte_Testa_Ferro", "FerroBattuto")
    y0 = -LEN / 2 - 1.6
    K._block(ps, Vector((0, y0 - 0.4, 0.2)), (3.2, 1.6, 0.6), None, 0.05, rng.random(), chip=0.3, rng=rng, drop=((0, 0, -1),))
    for sx in (-1, 1):
        K._block(ps, Vector((sx * 1.15, y0 - 0.4, 0.75)), (0.7, 0.7, 0.5), None, 0.05, rng.random(), chip=0.3, rng=rng)
        # palo: tronco squadrato con smussi e spacchi
        K._block(pt, Vector((sx * 1.15, y0 - 0.4, 2.0)), (0.3, 0.3, 2.1), Matrix.Rotation(rng.uniform(-0.03, 0.03), 3, "Y"), 0.03, rng.random(),
                 chip=0.3, rng=rng)
        K._block(pt, Vector((sx * 1.15, y0 - 0.4, 3.1)), (0.36, 0.36, 0.14), None, 0.02, rng.random())
        # funi che vanno dal corrimano e dalle portanti al palo e poi all'ancoraggio dietro
        anc = Vector((sx * 1.3, y0 - 2.6, 0.15))
        corda(pk, [(sx * W / 2, -LEN / 2, HR), (sx * 1.1, y0 - 0.25, 1.75), (sx * 1.2, y0 - 0.6, 1.7), anc + Vector((0, 0, 0.1))], r=0.03)
        corda(pk, [(sx * 0.82, -LEN / 2, -0.04), (sx * 1.0, y0 - 0.2, 0.75), (sx * 1.1, y0 - 0.6, 0.7), anc + Vector((0, 0.1, 0.05))], r=0.03)
        for z in (1.75, 0.98):        # legature avvolte sul palo
            for k in range(4):
                L.torus(pk, Vector((sx * 1.15, y0 - 0.4, z + k * 0.05)), 0.19, 0.022, nR=12, nr=4)
        K._block(ps, anc + Vector((0, 0, -0.05)), (0.6, 0.6, 0.35), None, 0.04, rng.random(), chip=0.3, rng=rng)
        L.torus(pz, anc + Vector((0, 0, 0.2)), 0.1, 0.025, normal=(0, 1, 0), nR=10, nr=4)
    K._block(pt, Vector((0, y0 - 0.4, 3.0)), (2.75, 0.28, 0.24), None, 0.03, rng.random(), chip=0.3, rng=rng)
    # assi d'accesso dal basamento al tratto
    y = y0 + 0.4
    while y < -LEN / 2 - 0.05:
        K._block(pt, Vector((0, y + 0.13, 0.43)), (1.7, 0.24, 0.05), Matrix.Rotation(rng.uniform(-0.03, 0.03), 3, "Z"), 0.012, rng.random())
        y += 0.29
    K.tint_fill(pt)
    m.col("Testa", (0, y0 - 0.4, 0.2), (3.2, 1.6, 0.6))
    for sx in (-1, 1):
        m.col("Palo%d" % sx, (sx * 1.15, y0 - 0.4, 1.8), (0.4, 0.4, 2.8))
    m.notes.update({"misure_m": "tratto 6 x 2 x 1,6 (lungo Y), testata 3,2 x 3,2 x 2,7"})
    m.notes["viste_extra"] = {"dettaglio": ((1.6, -1.2, 1.7), (0, 1.0, 0.3), 30)}
    m.notes["umani"] = [(0.0, 0.5, 0.0, 0.0), (0.4, -6.0, 0.47, 0.0)]
    m.notes["terreno_z"] = -6.0          # il tratto sta sospeso: nelle anteprime il terreno e' molto piu' in basso


# ---------------------------------------------------------------------------------------------
@modello
def BivaccoAlto(m):
    """bivacco a botte di lamiera rossa ondulata (onde vere), su pedana di legno e pilastrini di pietra,
    controventato con cavi d'acciaio; dentro 4 brande a castello, tavolino, gancio per la lanterna"""
    rng = random.Random(41)
    pl = m.part("Bivacco_Lamiera", "LamieraRossa")
    pw = m.part("Bivacco_Legno", "LegnoAsse")
    pi = m.part("Bivacco_Interno", "LegnoChiaro")
    ps = m.part("Bivacco_Pietra", "Granito")
    pf = m.part("Bivacco_Ferro", "FerroBattuto")
    pt = m.part("Bivacco_Brande", "TelaGrigia")
    pr = m.part("Bivacco_Coperte", "TelaRossa")
    pg = m.part("Bivacco_Vetro", "MAT_Glass")
    LEN, RX, RZ, Z0 = 5.0, 1.5, 2.5, 0.5          # botte: semiellisse larga 3, alta 2,5 sopra il pavimento
    # pedana e pilastrini
    for x in (-1.2, 1.2):
        for y in (-2.1, 0.0, 2.1):
            K._block(ps, Vector((x, y, 0.08)), (0.5, 0.5, 0.36), None, 0.04, rng.random(), chip=0.3, rng=rng, drop=((0, 0, -1),))
    for x in (-1.2, 1.2):
        K._block(pw, Vector((x, 0, 0.32)), (0.16, LEN + 0.6, 0.16), None, 0.02, rng.random())
    x = -1.62
    while x < 1.62:
        w = rng.uniform(0.18, 0.22)
        K._block(pw, Vector((x + w / 2, 0, Z0 - 0.04)), (w - 0.015, LEN + 0.9, 0.06), None, 0.01, rng.random(), chip=0.2 if rng.random() < 0.2 else 0.0, rng=rng)
        x += w
    # gusci: lamiera ondulata (onde lungo Y, alte 2,5 cm, passo 12 cm), costoloni ogni 1,25 m
    na = 28
    rows = []
    y = -LEN / 2
    step = 0.03
    while y <= LEN / 2 + 1e-6:
        rows.append(y)
        y += step
    verts, faces = [], []
    for y in rows:
        wv = 0.025 * math.sin(2 * math.pi * (y + LEN / 2) / 0.12)
        for i in range(na + 1):
            a = math.pi * i / na
            verts.append((math.cos(a) * (RX + wv), y, Z0 + math.sin(a) * (RZ + wv * 0.8)))
    w = na + 1
    for r in range(len(rows) - 1):
        for i in range(na):
            a = r * w + i
            faces.append([a, a + 1, a + w + 1, a + w])
    pl.add_raw(verts, faces, smooth=True)
    for y in (-LEN / 2 + 0.05, -1.25, 0.0, 1.25, LEN / 2 - 0.05):
        prof = [(math.cos(math.pi * i / 20) * (RX + 0.045), math.sin(math.pi * i / 20) * (RZ + 0.04)) for i in range(21)]
        L.tube(pf, [Vector((x_, y, Z0 + z_)) for x_, z_ in prof], 0.035, n=6)
    # rivestimento interno di legno (liscio)
    verts, faces = [], []
    for y in (-LEN / 2 + 0.06, LEN / 2 - 0.06):
        for i in range(17):
            a = math.pi * i / 16
            verts.append((math.cos(a) * (RX - 0.06), y, Z0 + math.sin(a) * (RZ - 0.06)))
    for i in range(16):
        faces.append([i + 1, i, 17 + i, 17 + i + 1])
    pi.add_raw(verts, faces, smooth=True)
    # pareti di testa: lamiera piana con la porta (davanti) e l'oblo' (dietro), cornice di legno
    for sy in (-1, 1):
        yy = sy * (LEN / 2 - 0.02)
        pts = [(math.cos(math.pi * i / 20) * RX, Z0 + math.sin(math.pi * i / 20) * RZ) for i in range(21)]
        Mw = Matrix(((1, 0, 0, 0), (0, 0, 1, yy), (0, 1, 0, 0), (0, 0, 0, 1)))
        if sy < 0:
            # davanti: due ante di lamiera ai lati della porta (0,9 x 2,0) e sopraluce
            dw, dh = 0.9, 2.0
            left = [q for q in pts if q[0] <= -dw / 2] + [(-dw / 2, Z0)]
            right = [(dw / 2, Z0)] + [q for q in pts if q[0] >= dw / 2]
            L.prism(pl, [(x_, z_) for x_, z_ in right][::-1] + [(dw / 2, Z0 + RZ * math.sqrt(max(0, 1 - (dw / 2 / RX) ** 2)))], -0.02, 0.02, Mw)
            L.prism(pl, [(-dw / 2, Z0 + RZ * math.sqrt(max(0, 1 - (dw / 2 / RX) ** 2)))] + [(x_, z_) for x_, z_ in left][::-1], -0.02, 0.02, Mw)
            ztop = Z0 + RZ * math.sqrt(max(0, 1 - (dw / 2 / RX) ** 2))
            L.prism(pl, [(-dw / 2, Z0 + dh), (dw / 2, Z0 + dh), (dw / 2, ztop), (-dw / 2, ztop)], -0.02, 0.02, Mw)
            # stipiti, architrave, porta socchiusa con le cerniere e la maniglia
            for sx in (-1, 1):
                K._block(pw, Vector((sx * (dw / 2 + 0.05), yy - 0.03, Z0 + dh / 2)), (0.1, 0.1, dh + 0.1), None, 0.012, rng.random())
            K._block(pw, Vector((0, yy - 0.03, Z0 + dh + 0.05)), (dw + 0.2, 0.1, 0.1), None, 0.012, rng.random())
            hinge = Vector((-dw / 2, yy - 0.04, Z0))
            Rd = Matrix.Rotation(-0.55, 3, "Z")
            for k in range(5):
                K._block(pw, hinge + Rd @ Vector((0.09 + k * 0.18, -0.025, dh / 2)), (0.17, 0.045, dh - 0.04), Rd, 0.008, rng.random())
            for z_ in (0.3, 1.7):
                L.box(pf, hinge + Rd @ Vector((0.18, -0.055, z_)), (0.32, 0.01, 0.05), rot=Rd)
            L.cyl(pf, hinge + Rd @ Vector((0.78, -0.07, 1.0)), hinge + Rd @ Vector((0.78, -0.14, 1.0)), 0.02, n=6)
            # gradini di legno (0,25 m) davanti alla porta
            for k, (yy2, zz) in enumerate(((yy - 0.95, 0.12), (yy - 0.62, 0.3))):
                K._block(pw, Vector((0, yy2 + 0.15, zz)), (1.1, 0.32, 0.05), None, 0.01, rng.random())
            for sx in (-1, 1):
                L.prism(pw, [(yy - 1.15, 0.0), (yy - 0.45, 0.0), (yy - 0.45, Z0 - 0.07), (yy - 0.62, Z0 - 0.07)], sx * 0.55 - 0.03, sx * 0.55 + 0.03,
                        Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1))))
        else:
            L.prism(pl, pts + [(-RX, Z0)], -0.02, 0.02, Mw)
            c = Vector((0, yy + 0.03, Z0 + 1.55))
            L.torus(pf, c, 0.32, 0.045, normal=(0, 1, 0), nR=20, nr=6)
            L.cyl(pg, c + Vector((0, -0.01, 0)), c + Vector((0, 0.02, 0)), 0.3, n=20)
            for k in range(8):
                a = 2 * math.pi * k / 8
                L.sphere(pf, c + Vector((math.cos(a) * 0.32, 0.04, math.sin(a) * 0.32)), 0.02, seg=6, rings=4)
    # tubo della stufa sul tetto e cavi d'acciaio agli ancoraggi
    top = Vector((0.75, 1.2, Z0 + RZ * math.sqrt(1 - (0.75 / RX) ** 2)))
    L.cyl(pf, top - Vector((0, 0, 0.1)), top + Vector((0, 0, 0.9)), 0.07, n=10)
    L.cyl(pf, top + Vector((0, 0, 0.9)), top + Vector((0, 0, 1.0)), 0.16, 0.05, n=10)
    for sx in (-1, 1):
        for sy in (-1, 1):
            a = Vector((sx * 0.6, sy * 1.6, Z0 + RZ * math.sqrt(1 - (0.6 / RX) ** 2) + 0.03))
            b = Vector((sx * 2.6, sy * 2.2, 0.05))
            L.cyl(pf, a, b, 0.008, n=4, caps=False)
            K._block(ps, b + Vector((0, 0, -0.05)), (0.4, 0.4, 0.25), None, 0.03, rng.random(), chip=0.3, rng=rng)
            L.torus(pf, b + Vector((0, 0, 0.12)), 0.05, 0.012, normal=(1, 0, 0), nR=8, nr=4)
    K.tint_fill(ps)
    # dentro: 4 brande a castello (2 per lato), materassi e coperte, tavolino ribaltabile
    for sx in (-1, 1):
        x0 = sx * 0.82
        for zb in (Z0 + 0.35, Z0 + 1.2):
            K._block(pw, Vector((x0, 0.0, zb)), (0.7, 3.9, 0.06), None, 0.01, rng.random())
            K._block(pt, Vector((x0, 0.0, zb + 0.1)), (0.64, 3.7, 0.14), None, 0.05, rng.random())
            K._block(pr, Vector((x0 - sx * 0.02, 0.9 + rng.uniform(-0.2, 0.2), zb + 0.19)), (0.66, 1.5, 0.05), None, 0.02, rng.random())
            K._block(pt, Vector((x0, -1.55, zb + 0.22)), (0.5, 0.35, 0.12), None, 0.05, rng.random())     # cuscino
        for yb in (-1.9, 1.9):
            K._block(pw, Vector((x0 - sx * 0.35, yb, Z0 + 0.8)), (0.07, 0.07, 1.6), None, 0.01, rng.random())
    K._block(pw, Vector((0, 2.15, Z0 + 0.75)), (0.9, 0.5, 0.04), None, 0.01, rng.random())
    L.box(pf, (0, 2.3, Z0 + 0.5), (0.03, 0.03, 0.5))
    K.tint_fill(pw)
    m.marker("FX_Light_Bivacco", (0, 0, Z0 + 2.1))
    m.marker("SPOT_Porta", (0, -LEN / 2 - 1.0, 0.3))
    m.col("Pedana", (0, 0, Z0 / 2 - 0.02), (3.2, LEN + 0.9, Z0))
    for sx in (-1, 1):
        m.col("Fianco%d" % sx, (sx * 1.35, 0, Z0 + 0.9), (0.3, LEN, 1.8))
        m.col("Branda%d" % sx, (sx * 0.82, 0, Z0 + 0.45), (0.7, 3.9, 0.2))
    m.col("Tetto", (0, 0, Z0 + 2.2), (2.4, LEN, 0.6))
    m.col("Retro", (0, LEN / 2 - 0.05, Z0 + 1.2), (2.8, 0.1, 2.4))
    for sx in (-1, 1):
        m.col("Fronte%d" % sx, (sx * 0.95, -LEN / 2 + 0.05, Z0 + 1.0), (1.0, 0.1, 2.0))
    m.ramp("Gradini", (0, -LEN / 2 - 1.15, 0.0), (0, -LEN / 2 - 0.1, Z0), 1.1)
    m.notes.update({"misure_m": "5 x 3 x 3 (lungo Y; porta verso -Y)"})
    m.notes["viste_extra"] = {"dettaglio": ((1.4, -5.2, 1.4), (0, -2.2, 1.3), 28), "dentro": ((0.0, -2.25, 1.6), (0, 1.0, 1.1), 16)}
    m.notes["umani"] = [(1.0, -3.6, 0.0, 0.3)]


# ---------------------------------------------------------------------------------------------
@modello
def StatuaDrago(m):
    """piedistallo di pietra per le statue dei draghi (le statue sono Meshy: segnaposto), con la targa
    di bronzo dell'elemento: 8 targhe nella stessa posizione (StatuaDrago_Targa_<Elemento>), se ne
    tiene una"""
    rng = random.Random(51)
    pp = m.part("StatuaDrago_Piedistallo", "PietraVulcanica")
    # zoccolo a gradino, dado con specchiature, cornice di coronamento
    K._block(pp, Vector((0, 0, 0.15)), (2.9, 2.9, 0.3), None, 0.05, rng.random(), chip=0.3, rng=rng, drop=((0, 0, -1),))
    K._block(pp, Vector((0, 0, 0.42)), (2.6, 2.6, 0.24), None, 0.05, rng.random(), chip=0.3, rng=rng)
    for k in range(4):
        R = Matrix.Rotation(math.pi / 2 * k, 4, "Z")
        K.ashlar(pp, R @ Matrix.Translation((0, -1.1, 0)), -1.1, 1.1, 0.54, 1.3, rng, course=0.38, depth=0.35, bev=0.04, lmin=1.6, lmax=2.6)
        K._block(pp, R @ Vector((0, -1.12, 0.92)), (1.5, 0.06, 0.55), R.to_3x3(), 0.02, rng.random())    # specchiatura
    K.tint_fill(pp)
    L.boxz(pp, -0.8, 0.8, -0.8, 0.8, 0.54, 1.3)
    K.tint_fill(pp)
    for k in range(4):
        R = Matrix.Rotation(math.pi / 2 * k, 4, "Z")
        K.cornice(pp, R @ Matrix.Translation((0, -1.1, 0)), -1.25, 1.25, 1.3, [(0.0, 0.0), (0.1, 0.0), (0.18, 0.08), (0.18, 0.2), (0.0, 0.2)], rng,
                  seg_len=2.6)
    K.tint_fill(pp)
    L.boxz(pp, -1.1, 1.1, -1.1, 1.1, 1.3, 1.5)
    K.tint_fill(pp)
    # targhe (una per elemento, stessa posizione)
    for j, el in enumerate(L.ELEMENTI):
        pt = m.part("StatuaDrago_Targa_" + el, "Targhe")
        u0, u1 = (j + 0.02) / 8, (j + 0.98) / 8
        x0, x1, z0, z1 = -0.35, 0.35, 0.68, 1.16
        y = -1.16
        verts = [(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1), (x0, y + 0.03, z0), (x1, y + 0.03, z0), (x1, y + 0.03, z1), (x0, y + 0.03, z1)]
        base = len(pt.v)
        pt.v.extend(verts)
        v0, v1 = 0.5 - 0.5 * 0.125 * 0.75, 0.5 + 0.5 * 0.125 * 0.75
        pt.f.append(([base, base + 1, base + 2, base + 3], False, [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]))
        for a, b in ((0, 1), (1, 2), (2, 3), (3, 0)):
            pt.f.append(([base + b, base + a, base + 4 + a, base + 4 + b], False, [(u0, v0)] * 4))
    # segnaposto della statua (Meshy: StatuaDrago_<Elemento>, drago seduto 2,4 x 3,4 x 3,5 m, guarda -Y)
    ph = m.part("PLACEHOLDER_StatuaDrago", "Basalto")
    L.box(ph, (0, 0.2, 1.5 + 1.0), (2.0, 2.4, 2.0))
    L.box(ph, (0, -0.6, 1.5 + 2.6), (0.8, 1.2, 1.2))
    m.marker("SPOT_Statua", (0, 0, 1.5))
    m.col("Piedistallo", (0, 0, 0.75), (2.9, 2.9, 1.5))
    m.notes.update({"misure_m": "3 x 5 x 3 con la statua (piedistallo 2,9 x 1,5 x 2,9)"})
    m.notes["nascondi_in_anteprima"] = ["StatuaDrago_Targa_" + el for el in L.ELEMENTI[1:]]
    m.notes["viste_extra"] = {"dettaglio": ((0.9, -3.4, 1.4), (0, -1.1, 0.95), 35)}


@modello
def SantuarioVetta(m):
    """santuario di vetta: pedana di pietra a secco, tempietto con due pilastri, architrave e tetto a
    capanna di lastre, campana di bronzo appesa a una trave, nicchia con la candela, ometto di sassi"""
    rng = random.Random(61)
    ps = m.part("Santuario_Pietra", "Granito")
    pw = m.part("Santuario_Legno", "LegnoAsse")
    pb = m.part("Santuario_Bronzo", "Bronzo")
    pn = m.part("Santuario_Neve", "Neve")
    pk = m.part("Santuario_Ometto", "Granito")
    pe = m.part("Santuario_Candela", "MAT_WarmLight")
    # pedana a secco (4 x 4) con due filari irregolari
    for k in range(4):
        R = Matrix.Rotation(math.pi / 2 * k, 4, "Z")
        K.ashlar(ps, R @ Matrix.Translation((0, -2.0, 0)), -2.0, 2.0, -0.2, 0.4, rng, course=0.3, depth=0.5, bev=0.04, lmin=1.2, lmax=2.4,
                 jitter=0.05, chip=0.4)
    K.tint_fill(ps)
    K.slabs(ps, Matrix.Identity(4), -1.75, 1.75, -1.75, 1.75, 0.45, rng, th=0.1, lmin=0.6, lmax=1.2)
    # tempietto: pilastri di conci, architrave, tetto a capanna di lastre
    for sx in (-1, 1):
        for i in range(6):
            z = 0.45 + i * 0.4
            w = 0.55 if i % 2 else 0.5
            K._block(ps, Vector((sx * 0.95, 0.4, z + 0.2)), (w, 0.55, 0.38), Matrix.Rotation(rng.uniform(-0.04, 0.04), 3, "Z"), 0.04,
                     rng.random(), chip=0.35, rng=rng)
    K._block(ps, Vector((0, 0.4, 2.95)), (2.6, 0.7, 0.3), None, 0.04, rng.random(), chip=0.3, rng=rng)
    K._block(ps, Vector((0, 1.15, 1.65)), (1.5, 0.3, 2.4), None, 0.04, rng.random())                  # fondo
    for sx in (-1, 1):
        a = math.radians(32)
        R = Matrix.Rotation(sx * a, 3, "Y")
        for i in range(3):
            y = -0.1 + i * 0.5
            K._block(ps, Vector((sx * 0.68, y + 0.25, 3.33)) + R @ Vector((0, 0, 0)), (1.55, 0.52, 0.12), R, 0.03, rng.random(), chip=0.3, rng=rng)
        # neve sulle falde
        L.box(pn, Vector((sx * 0.66, 0.4, 3.43)), (1.45, 1.4, 0.08), rot=R, bev=0.03)
    K._block(ps, Vector((0, 0.4, 3.78)), (0.3, 1.55, 0.2), None, 0.03, rng.random())                  # colmo
    K.tint_fill(ps)
    # trave e campana
    K._block(pw, Vector((0, 0.4, 2.62)), (1.6, 0.16, 0.16), None, 0.015, rng.random())
    c = Vector((0, 0.4, 2.54))
    L.lathe(pb, [(0.02, 0.0), (0.09, -0.03), (0.16, -0.12), (0.19, -0.3), (0.24, -0.45), (0.28, -0.5), (0.22, -0.48), (0.17, -0.32),
                 (0.13, -0.14), (0.0, -0.08)], 16, c=c)
    L.torus(pb, c + Vector((0, 0, 0.03)), 0.05, 0.015, normal=(1, 0, 0), nR=8, nr=4)
    L.sphere(pb, c + Vector((0, 0, -0.45)), 0.05, seg=8, rings=5)
    L.cyl(pw, c + Vector((0.0, -0.05, -0.5)), c + Vector((0.0, -0.3, -1.4)), 0.012, n=4)               # corda del batacchio
    # nicchia con la candela e le offerte
    K._block(ps, Vector((0, 0.95, 0.85)), (0.7, 0.3, 0.06), None, 0.02, rng.random())
    L.cyl(pe, (0, 0.95, 0.88), (0, 0.95, 1.05), 0.035, n=8)
    m.marker("FX_Light_Candela", (0, 0.95, 1.1))
    for i in range(5):
        L.sphere(pk, (rng.uniform(-0.25, 0.25), 0.9 + rng.uniform(-0.05, 0.05), 0.92), 0.04, seg=6, rings=4)
    # ometto: pila di sassi piatti, il piu' grande sotto
    base = Vector((1.35, -1.2, 0.45))
    z = 0.0
    for i in range(9):
        sz = 0.75 * (1 - i / 11)
        h = rng.uniform(0.12, 0.2) * (1 - i / 14)
        O.roccia(pk, base + Vector((rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05), z + h / 2)), (sz, sz * rng.uniform(0.7, 0.95), h),
                 seed=200 + i, res=6, crag=0.25, flat_bottom=False)
        z += h * 0.85
    O.roccia(pn, base + Vector((0, 0, z + 0.02)), (0.25, 0.2, 0.06), seed=7, res=5, crag=0.1, flat_bottom=True)
    # neve accumulata sulla pedana (in un angolo e contro i pilastri)
    O.roccia(pn, Vector((-1.4, -1.3, 0.47)), (1.0, 0.8, 0.14), seed=8, res=7, crag=0.1)
    O.roccia(pn, Vector((-0.9, 1.4, 0.47)), (0.8, 0.6, 0.12), seed=9, res=7, crag=0.1)
    m.marker("SPOT_Campana", (0, 0.4, 2.0))
    m.col("Pedana", (0, 0, 0.1), (4.0, 4.0, 0.6))
    for sx in (-1, 1):
        m.col("Pilastro%d" % sx, (sx * 0.95, 0.4, 1.65), (0.55, 0.55, 2.4))
    m.col("Fondo", (0, 1.15, 1.65), (1.5, 0.3, 2.4))
    m.col("Tetto", (0, 0.4, 3.3), (2.6, 1.6, 0.7))
    m.col("Ometto", base + Vector((0, 0, 0.6)), (0.75, 0.7, 1.2))
    m.notes.update({"misure_m": "4 x 4 x 4"})
    m.notes["viste_extra"] = {"dettaglio": ((0.8, -1.6, 1.9), (0, 0.4, 2.2), 30)}


@modello
def BandierePreghiera(m):
    """bandierine di preghiera fra due pali (modulare: si ripete lungo X), corda che pende, 20 drappi
    nei 5 colori (atlante Bandierine), consumati e mossi dal vento"""
    rng = random.Random(71)
    pw = m.part("Bandiere_Pali", "LegnoAsse")
    pc = m.part("Bandiere_Corda", "Corda")
    pf = m.part("Bandiere_Drappi", "Bandierine")
    ps = m.part("Bandiere_Sassi", "Granito")
    SP, H = 8.0, 4.0
    for sx in (-1, 1):
        x = sx * SP / 2
        K._block(pw, Vector((x, 0, H / 2)), (0.14, 0.14, H), Matrix.Rotation(sx * 0.03, 3, "Y"), 0.02, rng.random(), chip=0.3, rng=rng)
        L.lathe(pw, [(0.0, H), (0.09, H), (0.0, H + 0.25)], 6, c=(x + sx * 0.06, 0, 0), smooth=False)
        for i in range(6):        # sassi a cerchio alla base
            a = 2 * math.pi * i / 6 + rng.uniform(-0.2, 0.2)
            O.roccia(ps, Vector((x + 0.3 * math.cos(a), 0.3 * math.sin(a), 0.08)), (0.32, 0.28, 0.22), seed=300 + i + (10 if sx > 0 else 0), res=5, crag=0.3)
        # tirante a terra
        L.cyl(pc, (x, 0, H - 0.2), (x + sx * 1.5, 0.3, 0.02), 0.012, n=4, caps=False)
    sag = 0.9
    pts = []
    N = 40
    for i in range(N + 1):
        t = i / N
        pts.append(Vector((-SP / 2 + SP * t, 0.04 * math.sin(t * 9), H - 0.25 - sag * 4 * t * (1 - t))))
    L.tube(pc, pts, 0.012, n=5)
    nfl = 20
    for k in range(nfl):
        t = (k + 0.7) / (nfl + 0.4)
        x = -SP / 2 + SP * t
        z = H - 0.25 - sag * 4 * t * (1 - t)
        col_i = k % 5
        u0, u1 = (col_i + 0.03) / 5, (col_i + 0.97) / 5
        fw, fh = 0.3, 0.38
        rows, cols = 4, 3
        grid = []
        for r in range(rows + 1):
            rr = r / rows
            row = []
            for c_ in range(cols + 1):
                cc = c_ / cols
                yb = 0.07 * math.sin(cc * 3.0 + k) * rr + 0.12 * rr * rr        # il vento le spinge verso +Y
                q = Vector((x - fw / 2 + fw * cc, yb, z - 0.01 - fh * rr))
                row.append((q, (u0 + (u1 - u0) * cc, 0.97 - 0.94 * rr)))
            grid.append(row)
        for side in (0, 1):
            for r in range(rows):
                for c_ in range(cols):
                    quad = [grid[r][c_], grid[r][c_ + 1], grid[r + 1][c_ + 1], grid[r + 1][c_]]
                    if side:
                        quad = quad[::-1]
                    off = Vector((0, 0.004 if side else -0.004, 0))
                    base = len(pf.v)
                    pf.v.extend([tuple(q[0] + off) for q in quad])
                    pf.f.append(([base, base + 1, base + 2, base + 3], True, [q[1] for q in quad]))
    m.marker("SPOT_Bandiere", (0, 0, H - 1.2))
    for sx in (-1, 1):
        m.col("Palo%d" % sx, (sx * SP / 2, 0, H / 2), (0.2, 0.2, H))
    m.notes.update({"misure_m": "8 x 4 x 0,2"})
    m.notes["viste_extra"] = {"dettaglio": ((-1.5, -2.5, 3.0), (0.5, 0, 3.1), 30)}


# ---------------------------------------------------------------------------------------------
def chioma_pino(pc, pn, H, rng, R0=2.0, z0=1.4):
    """palchi di rami a gonna (stella frastagliata che pende), neve sopra ogni palco"""
    tiers = int((H - z0) / 1.05)
    for t in range(tiers):
        u = t / max(tiers - 1, 1)
        zt = z0 + (H - z0 - 0.6) * u ** 0.92
        R = R0 * (1 - u) ** 0.9 + 0.35
        droop = 0.45 * R + 0.15
        npts = 9 if R > 1.0 else 7
        rot = rng.uniform(0, 6.28)
        rings = [(0.18, 0.0), (0.45, -0.15), (0.75, -0.45), (1.0, -1.0)]
        nseg = npts * 4
        f0, v0 = len(pc.f), len(pc.v)
        top, bot = [], []
        for ri, (rf, dz) in enumerate(rings):
            rowt, rowb = [], []
            for j in range(nseg):
                a = rot + 2 * math.pi * j / nseg
                star = 1.0 + (0.22 * math.cos(npts * (a - rot)) + 0.06 * math.sin(3 * npts * a)) * rf
                r = R * rf * star * rng.uniform(0.96, 1.04)
                z = zt + droop * dz * star + (0.08 * math.sin(a * 5 + t) if ri else 0.0)
                rowt.append(len(pc.v))
                pc.v.append((r * math.cos(a), r * math.sin(a), z))
            for j in range(nseg):
                a = rot + 2 * math.pi * j / nseg
                q = Vector(pc.v[rowt[j]])
                rowb.append(len(pc.v))
                pc.v.append(tuple(q - Vector((0, 0, 0.22 * (1 - rf * 0.6)))))
            top.append(rowt)
            bot.append(rowb)
        for ri in range(len(rings) - 1):
            for j in range(nseg):
                j2 = (j + 1) % nseg
                pc.f.append(([top[ri][j], top[ri + 1][j], top[ri + 1][j2], top[ri][j2]], True, None))
                pc.f.append(([bot[ri][j2], bot[ri + 1][j2], bot[ri + 1][j], bot[ri][j]], True, None))
        last = len(rings) - 1
        for j in range(nseg):
            j2 = (j + 1) % nseg
            pc.f.append(([top[last][j], bot[last][j], bot[last][j2], top[last][j2]], True, None))
        # neve: solo le prime due corone sopra e un po' della terza, bordo mosso
        snow = []
        for ri, rf in enumerate((0.18, 0.45, 0.72)):
            row = []
            for j in range(nseg):
                if ri < 2:
                    q = Vector(pc.v[top[ri][j]])
                else:
                    a_ = Vector(pc.v[top[1][j]])
                    b_ = Vector(pc.v[top[2][j]])
                    q = a_.lerp(b_, rng.uniform(0.3, 0.9))
                row.append(len(pn.v))
                pn.v.append(tuple(q + Vector((0, 0, 0.09 - 0.03 * ri))))
            snow.append(row)
        for ri in range(2):
            for j in range(nseg):
                j2 = (j + 1) % nseg
                pn.f.append(([snow[ri][j], snow[ri + 1][j], snow[ri + 1][j2], snow[ri][j2]], True, None))
    # punta
    L.cyl(pc, (0, 0, H - 0.9), (0, 0, H + 0.2), 0.35, 0.02, n=7)


@modello
def PinoInnevato(m):
    """3 pini innevati (9, 11,5 e 14 m) affiancati lungo X: tronco, chioma a palchi, neve; ogni variante
    ha i suoi pezzi Pino<k>_Tronco/_Chioma/_Neve e il marcatore SPOT_Pino<k> alla base"""
    for k, (H, R0, x) in enumerate(((9.0, 1.8, -6.0), (11.5, 2.0, 0.0), (14.0, 2.2, 6.5))):
        rng = random.Random(81 + k)
        pt = m.part("Pino%d_Tronco" % (k + 1), "Corteccia")
        pc = m.part("Pino%d_Chioma" % (k + 1), "AghiPino")
        pn = m.part("Pino%d_Neve" % (k + 1), "Neve")
        n0t, n0c, n0n = len(pt.v), len(pc.v), len(pn.v)
        O.tronco(pt, [(0, 0, -0.3), (0.05, 0.02, H * 0.3), (0.0, -0.03, H * 0.7), (0.02, 0.0, H)], [0.32, 0.24, 0.14, 0.05], seed=90 + k,
                 nseg=10, sub=2, bark=0.02, flare=0.5, flare_lobes=4, flare_pow=8, tile=1.5, cap_top=False)
        chioma_pino(pc, pn, H, rng, R0=R0)
        for part, n0 in ((pt, n0t), (pc, n0c), (pn, n0n)):
            part.v[n0:] = [(q[0] + x, q[1], q[2]) for q in part.v[n0:]]
        m.marker("SPOT_Pino%d" % (k + 1), (x, 0, 0))
        m.col("Pino%d" % (k + 1), (x, 0, 1.2), (0.6, 0.6, 2.4))
        m.col("Chioma%d" % (k + 1), (x, 0, H * 0.55), (R0 * 1.2, R0 * 1.2, H * 0.8))
    m.notes.update({"misure_m": "4 x 9 / 11,5 / 14 x 4"})
    m.notes["viste_extra"] = {"dettaglio": ((2.5, -4.5, 3.0), (0, 0, 3.5), 30)}
    m.notes["umani"] = [(-2.5, -2.5, 0.0)]


@modello
def RocceSet(m):
    """6 rocce di granito con la neve sopra: masso piccolo, masso medio, masso grande, lastra, sperone
    alto, sporgenza; affiancate lungo X (marcatori SPOT_Roccia1..6 alla base)"""
    specs = [((2.0, 1.7, 1.5), 0.35, 0.0), ((3.2, 2.6, 2.4), 0.4, 0.0), ((4.5, 4.0, 3.4), 0.45, 0.0),
             ((6.0, 4.0, 1.4), 0.3, 0.06), ((3.6, 3.2, 12.0), 0.5, 0.0), ((8.0, 5.0, 3.0), 0.45, 0.1)]
    x = 0.0
    xs = []
    for k, (size, crag, strata) in enumerate(specs):
        x += size[0] / 2 + (1.5 if k else 0.0)
        xs.append(x)
        x += size[0] / 2
    off = (xs[0] + xs[-1]) / 2
    for k, (size, crag, strata) in enumerate(specs):
        rng = random.Random(101 + k)
        pr = m.part("Roccia%d" % (k + 1), "Granito")
        pn = m.part("Roccia%d_Neve" % (k + 1), "Neve")
        c = Vector((xs[k] - off, 0, size[2] * 0.3))
        f0 = len(pr.f)
        if k == 4:   # sperone: roccia allungata e storta
            O.roccia(pr, c + Vector((0, 0, size[2] * 0.2)), size, seed=500 + k, res=26, crag=crag, strata=0.0)
        else:
            O.roccia(pr, c, size, seed=500 + k, res=24 if size[0] > 3 else 16, crag=crag, strata=strata)
        O.neve_sopra(pr, pn, 0, f0, soglia=0.62, spessore=0.1, rng=rng)
        m.marker("SPOT_Roccia%d" % (k + 1), (xs[k] - off, 0, 0))
        m.col("Roccia%d" % (k + 1), c + Vector((0, 0, size[2] * 0.15)), (size[0] * 0.8, size[1] * 0.8, size[2] * 0.85))
    m.notes.update({"misure_m": "2 / 3 / 4,5 / 6 (lastra) / 12 (sperone) / 8 (sporgenza)"})
    m.notes["umani"] = [(xs[0] - off - 2.0, -2.0, 0.0), (xs[2] - off - 1.0, -3.2, 0.0)]
    m.notes["viste_extra"] = {"dettaglio": ((xs[2] - off + 2.0, -8.0, 3.0), (xs[2] - off, 0, 1.2), 35)}


# ---------------------------------------------------------------------------------------------
GAUGE = 0.9


def binario(pw, pf, path_fn, length, rng, sleepers=True):
    """binario lungo una curva path_fn(s) -> (punto, direzione) per s in [0, length]: due rotaie a doppio T
    (profilo estruso), traversine di legno ogni 0,6 m con le piastre e i chiodi"""
    prof = [(-0.035, 0.0), (0.035, 0.0), (0.035, 0.012), (0.009, 0.02), (0.009, 0.085), (0.026, 0.092), (0.026, 0.12),
            (-0.026, 0.12), (-0.026, 0.092), (-0.009, 0.085), (-0.009, 0.02), (-0.035, 0.012)]
    n = max(2, int(length / 0.25))
    for side in (-1, 1):
        rings = []
        for i in range(n + 1):
            s_ = length * i / n
            q, d = path_fn(s_)
            side_v = d.cross(Vector((0, 0, 1))).normalized()
            up = side_v.cross(d).normalized()
            c = q + side_v * side * GAUGE / 2 + up * 0.14
            rings.append([tuple(c + side_v * x + up * z) for (x, z) in prof])
        base = len(pf.v)
        k = len(prof)
        for r in rings:
            pf.v.extend(r)
        for i in range(n):
            for j in range(k):
                j2 = (j + 1) % k
                pf.f.append(([base + i * k + j, base + i * k + j2, base + (i + 1) * k + j2, base + (i + 1) * k + j], False, None))
        pf.f.append(([base + j for j in range(k)][::-1], False, None))
        pf.f.append(([base + n * k + j for j in range(k)], False, None))
    if sleepers:
        s_ = 0.3
        while s_ < length:
            q, d = path_fn(s_)
            side_v = d.cross(Vector((0, 0, 1))).normalized()
            up = side_v.cross(d).normalized()
            R = Matrix((side_v, d, up)).transposed()
            K._block(pw, q + up * 0.07, (1.5 + rng.uniform(-0.05, 0.05), 0.2, 0.14), R @ Matrix.Rotation(rng.uniform(-0.04, 0.04), 3, "Z"), 0.015,
                     rng.random(), chip=0.3 if rng.random() < 0.3 else 0.0, rng=rng)
            for sd in (-1, 1):
                L.box(pf, q + up * 0.145 + side_v * sd * GAUGE / 2, (0.16, 0.14, 0.012), rot=R)
                for o in (-0.05, 0.05):
                    L.box(pf, q + up * 0.16 + side_v * (sd * GAUGE / 2 + o), (0.022, 0.022, 0.03), rot=R)
            s_ += 0.6
        K.tint_fill(pw)


@modello
def CarrelloMiniera(m):
    """carrello da miniera (cassa di assi a tronco di piramide, ferri agli angoli, 4 ruote a bordino,
    minerale dentro) e binari modulari: dritto 4 m, curva (raggio 8 m, 30 gradi), salita (4 m, +0,5 m)"""
    rng = random.Random(111)
    pw = m.part("Carrello_Legno", "LegnoAsse")
    pf = m.part("Carrello_Ferro", "FerroBattuto")
    pm = m.part("Carrello_Minerale", "Granito")
    # cassa: assi orizzontali sui 4 lati, piu' larga in alto
    zb, zt = 0.45, 1.2
    wb, wt, lb, lt = 0.95, 1.15, 1.65, 1.9
    for side in range(4):
        long = side % 2 == 0
        sgn = 1 if side < 2 else -1
        nb = 5
        for i in range(nb):
            z0 = zb + (zt - zb) * i / nb
            z1 = zb + (zt - zb) * (i + 1) / nb - 0.012
            t0, t1 = (z0 - zb) / (zt - zb), (z1 - zb) / (zt - zb)
            w0, w1 = wb + (wt - wb) * t0, wb + (wt - wb) * t1
            l0, l1 = lb + (lt - lb) * t0, lb + (lt - lb) * t1
            if long:
                y0, y1 = sgn * w0 / 2, sgn * w1 / 2
                pts = [(-l0 / 2, y0, z0), (l0 / 2, y0, z0), (l1 / 2, y1, z1), (-l1 / 2, y1, z1)]
            else:
                x0, x1 = sgn * l0 / 2, sgn * l1 / 2
                pts = [(x0, -w0 / 2, z0), (x0, w0 / 2, z0), (x1, w1 / 2, z1), (x1, -w1 / 2, z1)]
            inner = []
            for q in pts:
                v = Vector(q)
                dirn = Vector((0, -sgn, 0)) if long else Vector((-sgn, 0, 0))
                inner.append(tuple(v + dirn * 0.04))
            base = len(pw.v)
            pw.v.extend(pts + inner)
            quads = [[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [3, 2, 6, 7], [1, 5, 6, 2], [0, 3, 7, 4]]
            if (long and sgn < 0) or (not long and sgn > 0):
                quads = [qq[::-1] for qq in quads]
            for qq in quads:
                pw.f.append(([base + x for x in qq], False, None))
    K._block(pw, Vector((0, 0, zb - 0.02)), (lb, wb, 0.05), None, 0.01, rng.random())
    K.tint_fill(pw)
    # ferri: angolari, bordo superiore, telaio, ruote, assi, ganci
    for sx in (-1, 1):
        for sy in (-1, 1):
            a = Vector((sx * lb / 2, sy * wb / 2, zb))
            b = Vector((sx * lt / 2, sy * wt / 2, zt))
            L.cyl(pf, a, b, 0.035, n=4)
    for sy in (-1, 1):
        L.box(pf, (0, sy * wt / 2, zt + 0.02), (lt + 0.06, 0.06, 0.05))
    for sx in (-1, 1):
        L.box(pf, (sx * lt / 2, 0, zt + 0.02), (0.06, wt + 0.06, 0.05))
    for sy in (-1, 1):
        L.box(pf, (0, sy * 0.38, zb - 0.1), (lb + 0.3, 0.08, 0.12))
    for sx in (-1, 1):
        L.cyl(pf, (sx * 0.55, -0.6, 0.27), (sx * 0.55, 0.6, 0.27), 0.04, n=8)
        for sy in (-1, 1):
            c = Vector((sx * 0.55, sy * GAUGE / 2, 0.27))
            Mw = Matrix.Translation(c) @ Matrix.Rotation(math.pi / 2, 4, "X")
            L.lathe(pf, [(0.0, -0.05), (0.2, -0.05), (0.2, -0.02), (0.25, -0.02), (0.25, 0.0), (0.2, 0.02), (0.2, 0.05), (0.06, 0.05), (0.06, 0.07), (0.0, 0.07)],
                    16, M=Mw if sy > 0 else Mw @ Matrix.Rotation(math.pi, 4, "X"))
    for sx in (-1, 1):
        L.box(pf, (sx * (lb / 2 + 0.25), 0, zb - 0.05), (0.3, 0.06, 0.06))
        L.torus(pf, (sx * (lb / 2 + 0.42), 0, zb - 0.05), 0.07, 0.02, normal=(0, 1, 0), nR=8, nr=4)
    # minerale (sassi) che sporge dalla cassa
    for i in range(10):
        O.roccia(pm, (rng.uniform(-0.65, 0.65), rng.uniform(-0.35, 0.35), zt - 0.05 + rng.uniform(-0.05, 0.12)),
                 (rng.uniform(0.25, 0.4),) * 2 + (0.22,), seed=700 + i, res=5, crag=0.3, cuts=5)
    m.col("Carrello", (0, 0, 0.75), (2.0, 1.2, 1.1))
    # binari: dritto, curva, salita (affiancati lungo X, cominciano a y = -2)
    pb = m.part("Binari_Legno", "LegnoAsse")
    pr = m.part("Binari_Ferro", "FerroBattuto")

    def dritto(x0):
        return lambda s_: (Vector((x0, -2.0 + s_, 0.0)), Vector((0, 1, 0)))

    def curva(x0, R=8.0):
        def f(s_):
            a = s_ / R
            return Vector((x0 + R - R * math.cos(a), -2.0 + R * math.sin(a), 0.0)), Vector((math.sin(a), math.cos(a), 0))
        return f

    def salita(x0, rise=0.5):
        d = Vector((0, 4.0, rise)).normalized()
        return lambda s_: (Vector((x0, -2.0, 0.0)) + d * s_, d)
    for nm, fn, ln, x0 in (("Dritto", dritto, 4.0, 3.0), ("Curva", curva, 8.0 * math.radians(30), 6.0), ("Salita", salita, math.hypot(4.0, 0.5), 10.5)):
        f = fn(x0)
        binario(pb, pr, f, ln, rng)
        q0, _ = f(0.0)
        q1, _ = f(ln)
        m.marker("SPOT_Binari%s_Inizio" % nm, q0)
        m.marker("SPOT_Binari%s_Fine" % nm, q1)
        m.ramp("Binari%s" % nm, q0, q1 + Vector((0, 0.001, 0)), 1.6, thick=0.3) if nm != "Curva" else m.col("BinariCurva", (q0 + q1) / 2, (2.5, 4.2, 0.2))
    m.notes.update({"misure_m": "carrello 2 x 1,5 x 1,2; binari 4 m (dritto), curva r 8 m 30 gradi, salita 4 m +0,5 m; scartamento 0,9"})
    m.notes["viste_extra"] = {"dettaglio": ((1.8, -2.6, 1.8), (0, 0, 0.7), 32), "tre_quarti": ((14, -12, 8), (5, 0, 0.5), 30)}
    m.notes["umani"] = [(-1.8, -0.8, 0.0)]


@modello
def IngressoMiniera(m):
    """imbocco di miniera: telaio di travi (ritti, cappello, saette), assito di contenimento, quadri di
    armatura nella galleria, roccia attorno, due lanterne, binario che entra"""
    rng = random.Random(121)
    pw = m.part("Miniera_Travi", "LegnoAsse")
    pa = m.part("Miniera_Assito", "LegnoScuro")
    pr = m.part("Miniera_Roccia", "Granito")
    pf = m.part("Miniera_Ferro", "FerroBattuto")
    pl = m.part("Miniera_Lanterne", "MAT_WarmLight")
    W, H, D = 3.2, 3.4, 3.0
    # quadri di armatura: davanti (grosso) e due dentro la galleria
    for i, y in enumerate((0.0, 1.3, 2.6)):
        k = 1.0 if i == 0 else 0.8
        for sx in (-1, 1):
            K._block(pw, Vector((sx * W / 2, y, H / 2)), (0.32 * k, 0.32 * k, H), Matrix.Rotation(sx * 0.04, 3, "Y"), 0.03, rng.random(),
                     chip=0.3, rng=rng)
        K._block(pw, Vector((0, y, H + 0.18 * k)), (W + 0.7, 0.36 * k, 0.36 * k), None, 0.03, rng.random(), chip=0.3, rng=rng)
        if i == 0:
            for sx in (-1, 1):       # saette
                a = Vector((sx * W / 2, -0.02, H - 0.9))
                b = Vector((sx * (W / 2 - 0.8), -0.02, H))
                d = b - a
                R = Matrix.Rotation(math.atan2(d.z, d.x * sx) * -sx, 3, "Y")
                K._block(pw, (a + b) / 2, (d.length + 0.15, 0.22, 0.2), R, 0.02, rng.random())
            K._block(pw, Vector((0, -0.05, H + 0.75)), (W + 1.4, 0.3, 0.3), None, 0.03, rng.random(), chip=0.3, rng=rng)
            # tavola sopra l'ingresso (senza scritte)
            K._block(pa, Vector((0, -0.25, H + 0.25)), (1.5, 0.05, 0.4), Matrix.Rotation(0.03, 3, "Y"), 0.01, rng.random())
    # assito: tavole dietro i ritti e sul cielo della galleria
    for sx in (-1, 1):
        y = 0.2
        while y < D:
            K._block(pa, Vector((sx * (W / 2 + 0.12), y + 0.15, H / 2)), (0.05, 0.28, H), None, 0.01, rng.random())
            y += 0.3
    x = -W / 2
    while x < W / 2:
        K._block(pa, Vector((x + 0.14, D / 2 + 0.1, H + 0.42)), (0.27, D, 0.05), None, 0.01, rng.random())
        x += 0.29
    K.tint_fill(pa)
    L.boxz(pa, -W / 2 - 0.2, W / 2 + 0.2, D + 0.05, D + 0.15, 0.0, H + 0.5)       # fondo buio
    # roccia attorno (il fronte della montagna): blocchi di granito fratturati
    for i in range(9):
        a = math.pi * (i + 0.5) / 9
        r = 3.1 + rng.uniform(-0.2, 0.3)
        c = Vector((math.cos(a) * r * 1.05, 0.9 + rng.uniform(0, 0.8), math.sin(a) * r * 1.2 + 0.2))
        O.roccia(pr, c, (rng.uniform(1.8, 2.6), 2.4, rng.uniform(1.6, 2.4)), seed=800 + i, res=8, crag=0.45, cuts=13, flat_bottom=False)
    for sx in (-1, 1):
        O.roccia(pr, (sx * 3.3, 1.0, 0.6), (2.0, 2.6, 1.8), seed=820 + (sx > 0), res=8, crag=0.45, cuts=13)
    # lanterne sui ganci
    for sx in (-1, 1):
        c = Vector((sx * (W / 2 + 0.05), -0.35, H - 0.7))
        L.box(pf, c + Vector((0, 0.18, 0.35)), (0.04, 0.4, 0.04))
        L.box(pf, c + Vector((0, 0.0, 0.15)), (0.02, 0.02, 0.3))
        L.lathe(pf, [(0.0, -0.3), (0.13, -0.3), (0.13, -0.26), (0.03, -0.24), (0.03, 0.0), (0.14, 0.02), (0.0, 0.1)], 8, c=c)
        for k in range(4):
            a = math.pi / 2 * k + math.pi / 4
            L.box(pf, c + Vector((math.cos(a) * 0.1, math.sin(a) * 0.1, -0.12)), (0.015, 0.015, 0.24))
        L.cyl(pl, c + Vector((0, 0, -0.24)), c + Vector((0, 0, -0.02)), 0.08, n=8)
        m.marker("FX_Light_Lanterna%d" % (1 if sx < 0 else 2), c + Vector((0, 0, -0.12)))
    # binario che entra
    pb = m.part("Miniera_Binari_Legno", "LegnoAsse")
    pr2 = m.part("Miniera_Binari_Ferro", "FerroBattuto")
    binario(pb, pr2, lambda s_: (Vector((0, -3.0 + s_, 0.0)), Vector((0, 1, 0))), 5.8, rng)
    m.marker("SPOT_Galleria", (0, D, 0.1))
    for sx in (-1, 1):
        m.col("Ritto%d" % sx, (sx * W / 2, D / 2, H / 2), (0.4, D, H))
        m.col("Roccia%d" % sx, (sx * 3.6, 1.2, 1.8), (2.4, 2.8, 3.6))
    m.col("Cielo", (0, D / 2, H + 0.5), (W + 1.4, D + 0.4, 1.0))
    m.col("Fondo", (0, D + 0.1, H / 2), (W, 0.2, H))
    m.notes.update({"misure_m": "6 x 5 x 3"})
    m.notes["viste_extra"] = {"dettaglio": ((2.0, -3.2, 2.2), (0.8, 0, 2.3), 32)}
    m.notes["umani"] = [(-0.6, -1.5, 0.0)]


@modello
def Incubatrice(m):
    """incubatrice per l'uovo (casa): vasca tonda di pietra su zoccolo, piena di braci e sassi roventi,
    culla di pietre ritte al centro dove si posa l'uovo (SPOT_Uovo), anello di bronzo"""
    rng = random.Random(131)
    ps = m.part("Incubatrice_Pietra", "PietraVulcanica")
    pb = m.part("Incubatrice_Bronzo", "Bronzo")
    pe = m.part("Incubatrice_Braci", "MAT_Ember")
    pk = m.part("Incubatrice_Sassi", "Basalto")
    # zoccolo e vasca a conci curvi
    K.ring_ashlar(ps, Matrix.Identity(4), 1.5, 1.5, 0.0, 0.35, rng, course=0.35, depth=0.5, lmin=2.0, lmax=3.0)
    K.ring_ashlar(ps, Matrix.Identity(4), 1.35, 1.3, 0.35, 1.1, rng, course=0.375, depth=0.3, lmin=1.6, lmax=2.6)
    K.tint_fill(ps)
    L.lathe(ps, [(1.0, 0.3), (1.0, 0.75), (0.0, 0.75)], 24, smooth=False, close=False)        # fondo interno
    L.lathe(ps, [(1.04, 1.1), (1.4, 1.1), (1.45, 1.16), (1.38, 1.22), (1.0, 1.22), (1.0, 0.75)], 32, smooth=False, close=False)
    K.tint_fill(ps)
    L.lathe(pb, [(1.36, 0.8), (1.395, 0.82), (1.395, 0.95), (1.36, 0.97)], 32, smooth=False, close=False)
    # braci e sassi roventi
    for i in range(26):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.25, 0.9)
        O.roccia(pk, (r * math.cos(a), r * math.sin(a), 0.85 + rng.uniform(0, 0.06)), (rng.uniform(0.2, 0.35),) * 2 + (0.16,),
                 seed=900 + i, res=4, crag=0.3, cuts=4)
    L.lathe(pe, [(0.0, 0.88), (0.98, 0.86), (0.98, 0.8), (0.0, 0.8)], 24, smooth=False)
    for i in range(18):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.3, 0.9)
        L.sphere(pe, (r * math.cos(a), r * math.sin(a), 0.92), rng.uniform(0.04, 0.08), seg=6, rings=4)
    # culla di pietre ritte
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.3
        O.roccia(ps, (0.42 * math.cos(a), 0.42 * math.sin(a), 1.05), (0.22, 0.2, 0.55), seed=950 + i, res=5, crag=0.3, cuts=5)
    K.tint_fill(ps)
    m.marker("SPOT_Uovo", (0, 0, 1.0))
    m.marker("FX_Fire_Incubatrice", (0, 0, 0.95))
    m.marker("FX_Light_Incubatrice", (0, 0, 1.6))
    for k, r in enumerate((0.0, math.pi / 4)):
        m.col("Vasca%d" % k, (0, 0, 0.6), (2.8, 2.8, 1.2), Matrix.Rotation(r + math.pi / 8, 3, "Z"))
    m.notes.update({"misure_m": "3 x 1,5 x 3"})
    m.notes["viste_extra"] = {"dettaglio": ((1.2, -1.9, 2.3), (0, 0, 0.9), 35)}


# ---------------------------------------------------------------------------------------------
def trave(p, a, b, w, h, rng, bev=0.02, chip=0.25):
    """trave squadrata da a a b (sezione w x h), un po' scheggiata"""
    a, b = Vector(a), Vector(b)
    d = b - a
    fwd = d.normalized()
    side = fwd.cross(Vector((0, 0, 1)))
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side.normalize()
    up = side.cross(fwd).normalized()
    R = Matrix((side, fwd, up)).transposed()
    K._block(p, (a + b) / 2, (w, d.length, h), R, bev, rng.random(), chip=chip if rng.random() < 0.4 else 0.0, rng=rng)


def lanterna_carta(pl, pf, c, r=0.22, h=0.42):
    """lanterna di carta tonda con anelli scuri e nappa"""
    L.lathe(pl, [(0.0, -h / 2), (r * 0.55, -h / 2), (r * 0.9, -h * 0.3), (r, 0.0), (r * 0.9, h * 0.3), (r * 0.55, h / 2), (0.0, h / 2)], 12, c=c)
    for z in (-h / 2, h / 2):
        L.lathe(pf, [(r * 0.5, z - 0.02), (r * 0.6, z - 0.02), (r * 0.6, z + 0.02), (r * 0.5, z + 0.02)], 10, c=c, smooth=False, close=False)
    L.cyl(pf, Vector(c) + Vector((0, 0, h / 2)), Vector(c) + Vector((0, 0, h / 2 + 0.25)), 0.008, n=4)


@modello
def StallaDraghi(m):
    """stalla aperta per draghi adulti: telaio di travi (pilastri, capriate, arcarecci), tetto a due
    falde di scandole, parete di fondo e fianchi di assi, fieno in balle e sciolto, abbeveratoio,
    anelli con le catene, lanterne"""
    rng = random.Random(141)
    pw = m.part("Stalla_Travi", "LegnoAsse")
    pa = m.part("Stalla_Assi", "LegnoScuro")
    pt = m.part("Stalla_Tetto", "Scandole")
    ps = m.part("Stalla_Pietra", "Granito")
    ph = m.part("Stalla_Fieno", "Fieno")
    pf = m.part("Stalla_Ferro", "FerroBattuto")
    pl = m.part("Stalla_Lanterne", "MAT_WarmLight")
    X, Y, ZE, ZR = 7.0, 4.5, 5.6, 9.0
    xs = (-7.0, -3.5, 0.0, 3.5, 7.0)
    for x in xs:
        for y in (-Y, Y):
            K._block(ps, Vector((x, y, 0.2)), (0.75, 0.75, 0.4), None, 0.05, rng.random(), chip=0.3, rng=rng, drop=((0, 0, -1),))
            trave(pw, (x, y, 0.4), (x, y, ZE + 0.2), 0.42, 0.42, rng)
            # mensole a squadra sotto la trave di bordo
            for dx in (-1, 1):
                if abs(x + dx * 1.0) <= X:
                    trave(pw, (x, y, ZE - 1.1), (x + dx * 1.0, y, ZE - 0.1), 0.22, 0.22, rng)
        # capriata: catena, monaco, puntoni, saette
        trave(pw, (x, -Y - 0.3, ZE + 0.15), (x, Y + 0.3, ZE + 0.15), 0.3, 0.36, rng)
        trave(pw, (x, 0, ZE + 0.3), (x, 0, ZR - 0.1), 0.3, 0.3, rng)
        for sy in (-1, 1):
            trave(pw, (x, sy * (Y + 0.9), ZE - 0.25), (x, 0, ZR + 0.05), 0.28, 0.3, rng)
            trave(pw, (x, 0, ZE + 1.0), (x, sy * 2.3, ZE + 0.35 + (ZR - ZE) * (2.2 / 5.4) * 1.0 + 0.6), 0.2, 0.2, rng)
    for y in (-Y, Y):
        trave(pw, (-X - 0.5, y, ZE + 0.25), (X + 0.5, y, ZE + 0.25), 0.34, 0.38, rng)
    # arcarecci e colmo
    slope = (ZR - ZE) / (Y + 0.9)
    for sy in (-1, 1):
        for t in (0.25, 0.55, 0.85):
            yy = sy * (Y + 0.9) * (1 - t)
            trave(pw, (-X - 0.9, yy, ZE - 0.1 + slope * (Y + 0.9) * t + 0.22), (X + 0.9, yy, ZE - 0.1 + slope * (Y + 0.9) * t + 0.22), 0.22, 0.22, rng)
    trave(pw, (-X - 1.0, 0, ZR + 0.12), (X + 1.0, 0, ZR + 0.12), 0.3, 0.3, rng)
    K.tint_fill(pw)
    # falde di scandole (lastre spesse con il bordo frastagliato)
    ang = math.atan2(ZR - ZE, Y + 0.9)
    run = math.hypot(Y + 1.6, (ZR - ZE) * (Y + 1.6) / (Y + 0.9))
    for sy in (-1, 1):
        R = Matrix.Rotation(-sy * ang, 3, "X")
        c = Vector((0, sy * (Y + 1.6) / 2, ZR + 0.42 - (ZR - ZE) * 0.5 * (Y + 1.6) / (Y + 0.9)))
        L.box(pt, c, (2 * X + 2.2, run + 0.1, 0.12), rot=R, bev=0.03)
        # fila di scandole sul bordo di gronda (ombra frastagliata)
        for i in range(30):
            x = -X - 1.0 + (2 * X + 2.0) * (i + 0.5) / 30
            q = c + R @ Vector((x, sy * (run / 2 - 0.1), 0.08))
            L.box(pt, q, ((2 * X + 2) / 30 - 0.03, 0.35, 0.05), rot=R @ Matrix.Rotation(rng.uniform(-0.05, 0.05), 3, "Y"))
    L.box(pt, (0, 0, ZR + 0.5), (2 * X + 2.2, 0.5, 0.18), bev=0.03)
    # parete di fondo, fianchi a meta' altezza, timpani
    def assito(x0, x1, y, z0, z1, along_x=True):
        x = x0
        while x < x1 - 0.05:
            w = min(rng.uniform(0.22, 0.32), x1 - x)
            if along_x:
                K._block(pa, Vector((x + w / 2, y, (z0 + z1) / 2)), (w - 0.015, 0.06, z1 - z0), None, 0.01, rng.random())
            else:
                K._block(pa, Vector((y, x + w / 2, (z0 + z1) / 2)), (0.06, w - 0.015, z1 - z0), None, 0.01, rng.random())
            x += w
    assito(-X, X, Y + 0.25, 0.3, ZE)
    for sx in (-1, 1):
        assito(-Y, Y, sx * (X + 0.25), 0.3, 2.6, along_x=False)
        L.prism(pa, [(-Y - 0.3, ZE + 0.3), (Y + 0.3, ZE + 0.3), (0.0, ZR + 0.1)], sx * (X + 0.25) - 0.03, sx * (X + 0.25) + 0.03,
                Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1))))
    K.tint_fill(pa)
    # fieno: balle impilate e mucchi sciolti
    for (x, y, z, r) in ((-5.2, 3.3, 0.45, 0.1), (-4.0, 3.4, 0.45, -0.05), (-4.6, 3.3, 1.3, 0.2), (5.0, 3.4, 0.45, 0.0), (5.2, 2.2, 0.45, 0.4)):
        K._block(ph, Vector((x, y, z)), (1.1, 0.75, 0.85), Matrix.Rotation(r, 3, "Z"), 0.12, rng.random())
        for dz in (-0.2, 0.2):     # legacci
            L.box(pf, (x, y, z + dz), (1.13, 0.78, 0.03), rot=Matrix.Rotation(r, 3, "Z"))
    for (x, y, sz) in ((-1.5, 2.8, (4.5, 2.6, 1.3)), (2.2, 3.0, (3.5, 2.2, 1.0)), (-6.0, -1.0, (2.0, 2.4, 0.8))):
        O.roccia(ph, (x, y, 0.2), sz, seed=int(x * 10 + 1000), res=10, crag=0.25, cuts=0)
    # abbeveratoio di pietra e anelli con le catene sui pilastri di fondo
    K._block(ps, Vector((1.8, -2.4, 0.35)), (2.8, 1.0, 0.7), None, 0.05, rng.random(), chip=0.3, rng=rng)
    for x in (-3.5, 0.0, 3.5):
        c = Vector((x, Y - 0.25, 2.2))
        L.torus(pf, c, 0.14, 0.03, normal=(1, 0, 0), nR=10, nr=4)
        L.chain(pf, c + Vector((0, -0.05, -0.1)), Vector((x + 0.6, Y - 1.2, 0.05)), sag=0.5, link=0.16, thick=0.02)
    # lanterne di ferro ai pilastri del davanti
    for x in (-3.5, 3.5):
        c = Vector((x, -Y - 0.45, 3.2))
        L.box(pf, c + Vector((0, 0.2, 0.42)), (0.04, 0.45, 0.04))
        L.lathe(pf, [(0.0, -0.25), (0.12, -0.25), (0.12, -0.2), (0.03, -0.2), (0.03, 0.12), (0.13, 0.14), (0.0, 0.22)], 8, c=c)
        L.cyl(pl, c + Vector((0, 0, -0.2)), c + Vector((0, 0, 0.1)), 0.075, n=8)
        m.marker("FX_Light_Stalla%d" % (1 if x < 0 else 2), c)
    m.marker("SPOT_Drago", (0, 0, 0.0))
    for x in xs:
        for y in (-Y, Y):
            m.col("Pilastro_%d_%d" % (int(x), int(y)), (x, y, ZE / 2), (0.45, 0.45, ZE))
    for sy in (-1, 1):
        q0 = Vector((0, sy * (Y + 1.6), ZE - 0.4))
        q1 = Vector((0, 0.001 * sy, ZR + 0.4))
        m.ramp("Falda%d" % sy, q0, q1, 2 * X + 2.2, thick=0.4)
    m.col("Fondo", (0, Y + 0.25, ZE / 2), (2 * X, 0.2, ZE))
    for sx in (-1, 1):
        m.col("Fianco%d" % sx, (sx * (X + 0.25), 0, 1.4), (0.2, 2 * Y, 2.6))
    m.notes.update({"misure_m": "14 x 9 x 10 (aperta verso -Y)"})
    m.notes["viste_extra"] = {"dettaglio": ((3.0, -6.5, 2.6), (-1.0, 2.0, 3.2), 26)}
    m.notes["umani"] = [(-2.0, -6.0, 0.0)]


@modello
def BancarellaMercato(m):
    """3 bancarelle del mercato del borgo (affiancate lungo X): telaio di legno, banco, tenda a righe,
    lanterne di carta; merci: A frutta in ceste, B ceramiche, C rotoli di stoffa"""
    for k in range(3):
        rng = random.Random(151 + k)
        x0 = (k - 1) * 6.0
        pw = m.part("Bancarella%d_Legno" % (k + 1), "LegnoAsse")
        pc = m.part("Bancarella%d_Tenda" % (k + 1), "TendaRighe")
        pl = m.part("Bancarella%d_Lanterne" % (k + 1), "MAT_WarmLight")
        pf = m.part("Bancarella%d_Ferro" % (k + 1), "FerroBattuto")
        W, D, H = 4.0, 2.0, 2.5
        for sx in (-1, 1):
            for sy in (-1, 1):
                hh = H if sy > 0 else H - 0.25
                trave(pw, (x0 + sx * (W / 2 - 0.1), sy * (D / 2 - 0.1), 0.0), (x0 + sx * (W / 2 - 0.1), sy * (D / 2 - 0.1), hh), 0.12, 0.12, rng)
        # banco: piano, fronte di assi, mensola dietro
        K._block(pw, Vector((x0, -0.35, 0.92)), (W - 0.1, 0.9, 0.06), None, 0.012, rng.random())
        x = x0 - W / 2 + 0.1
        while x < x0 + W / 2 - 0.1:
            w = min(rng.uniform(0.2, 0.3), x0 + W / 2 - 0.1 - x)
            K._block(pw, Vector((x + w / 2, -0.82, 0.46)), (w - 0.012, 0.04, 0.88), None, 0.008, rng.random())
            x += w
        K._block(pw, Vector((x0, 0.75, 1.3)), (W - 0.3, 0.4, 0.04), None, 0.01, rng.random())
        K.tint_fill(pw)
        # tenda a righe (colonna k dell'atlante): spiovente con la balza ondulata davanti
        u0, u1 = (k + 0.02) / 3, (k + 0.98) / 3
        front, back = -D / 2 - 0.5, D / 2
        zf, zb = H - 0.35, H + 0.15
        nx = 12
        rows = [(back, zb, 0.0), (0.0, (zf + zb) / 2 + 0.06, 0.45), (front, zf, 0.9)]
        verts, uvs = [], []
        for (yy, zz, v) in rows:
            for i in range(nx + 1):
                t = i / nx
                xx = x0 - W / 2 - 0.15 + (W + 0.3) * t
                sag = 0.05 * math.sin(t * math.pi * nx / 2) if yy == front else 0.0
                verts.append((xx, yy, zz - sag))
                uvs.append((u0 + (u1 - u0) * t, v))
        base = len(pc.v)
        pc.v.extend(verts)
        w_ = nx + 1
        for r in range(2):
            for i in range(nx):
                idx = [r * w_ + i, r * w_ + i + 1, (r + 1) * w_ + i + 1, (r + 1) * w_ + i]
                pc.f.append(([base + q for q in idx][::-1], True, [uvs[q] for q in idx][::-1]))
                pc.f.append(([base + q for q in idx], True, [uvs[q] for q in idx]))
        # balza a festoni
        for i in range(nx):
            t0, t1 = i / nx, (i + 1) / nx
            xa = x0 - W / 2 - 0.15 + (W + 0.3) * t0
            xb = x0 - W / 2 - 0.15 + (W + 0.3) * t1
            pts = [(xa, front, zf), (xb, front, zf), (xb, front - 0.01, zf - 0.25), ((xa + xb) / 2, front - 0.01, zf - 0.38), (xa, front - 0.01, zf - 0.25)]
            base = len(pc.v)
            pc.v.extend(pts)
            uv = [(u0 + (u1 - u0) * t0, 0.92), (u0 + (u1 - u0) * t1, 0.92), (u0 + (u1 - u0) * t1, 0.98), (u0 + (u1 - u0) * (t0 + t1) / 2, 1.0), (u0 + (u1 - u0) * t0, 0.98)]
            pc.f.append(([base + q for q in range(5)], False, uv))
            pc.f.append(([base + q for q in range(5)][::-1], False, uv[::-1]))
        for sx in (-1, 1):
            trave(pw, (x0 + sx * (W / 2 - 0.1), -D / 2 + 0.1, H - 0.25), (x0 + sx * (W / 2 - 0.1), front, zf - 0.02), 0.08, 0.08, rng)
        # lanterne di carta
        for sx in (-1, 1):
            c = Vector((x0 + sx * (W / 2 - 0.5), front + 0.2, zf - 0.75))
            lanterna_carta(pl, pf, c)
            m.marker("FX_Light_Bancarella%d_%d" % (k + 1, 1 if sx < 0 else 2), c)
        # merci
        if k == 0:
            pb = m.part("Bancarella1_Ceste", "Bambu")
            for i, (dx, mat) in enumerate(((-1.3, "FruttaRossa"), (-0.45, "FruttaArancio"), (0.45, "FruttaVerde"), (1.3, "FruttaRossa"))):
                c = Vector((x0 + dx, -0.4, 0.95))
                L.lathe(pb, [(0.0, 0.0), (0.3, 0.0), (0.38, 0.18), (0.4, 0.22), (0.36, 0.22), (0.33, 0.04), (0.0, 0.04)], 14, c=c)
                pfr = m.part("Bancarella1_" + mat, mat)
                for j in range(14):
                    a = rng.uniform(0, 2 * math.pi)
                    r = rng.uniform(0.0, 0.28)
                    L.sphere(pfr, c + Vector((r * math.cos(a), r * math.sin(a), 0.16 + 0.07 * (j % 3))), 0.07, seg=8, rings=6)
        elif k == 1:
            for i in range(9):
                mat = "Ceramica" if i % 2 else "CeramicaVerde"
                pv = m.part("Bancarella2_" + mat, mat)
                c = Vector((x0 - 1.6 + i * 0.4, -0.4 + rng.uniform(-0.15, 0.15), 0.95))
                h = rng.uniform(0.25, 0.5)
                rr = rng.uniform(0.1, 0.17)
                L.lathe(pv, [(0.0, 0.0), (rr * 0.6, 0.0), (rr, h * 0.35), (rr * 0.95, h * 0.6), (rr * 0.45, h * 0.85), (rr * 0.55, h), (rr * 0.45, h * 1.0),
                             (0.0, h * 0.9)], 14, c=c)
            for i in range(5):
                pv = m.part("Bancarella2_Ceramica", "Ceramica")
                c = Vector((x0 - 1.4 + i * 0.7, 0.75, 1.32))
                L.lathe(pv, [(0.0, 0.0), (0.12, 0.0), (0.2, 0.08), (0.22, 0.1), (0.0, 0.06)], 14, c=c)
        else:
            for i in range(7):
                mat = ("TelaRossa", "TelaBlu", "VelaGiunca")[i % 3]
                pv = m.part("Bancarella3_" + mat, mat)
                c = Vector((x0 - 1.5 + i * 0.5, -0.4, 0.95 + 0.13))
                L.cyl(pv, c + Vector((0, -0.4, 0)), c + Vector((0, 0.4, 0)), 0.12, n=12)
            for i in range(3):
                pv = m.part("Bancarella3_TelaBlu", "TelaBlu")
                K._block(pv, Vector((x0 - 1.0 + i * 1.0, 0.75, 1.36 + 0.05)), (0.7, 0.35, 0.1), None, 0.03, rng.random())
        m.marker("SPOT_Bancarella%d" % (k + 1), (x0, -1.4, 0.0))
        m.col("Bancarella%d" % (k + 1), (x0, -0.35, 0.47), (W, 0.95, 0.95))
        m.col("Tenda%d" % (k + 1), (x0, -0.2, H), (W + 0.3, D + 0.6, 0.3))
    m.notes.update({"misure_m": "4 x 3 x 2,5 ciascuna"})
    m.notes["viste_extra"] = {"dettaglio": ((-4.0, -4.2, 2.0), (-6.0, -0.2, 1.1), 30)}
    m.notes["umani"] = [(-3.0, -2.2, 0.0)]


# ---------------------------------------------------------------------------------------------
@modello
def Teleferica(m):
    """pilone di traliccio d'acciaio (4 montanti rastremati, croci di Sant'Andrea), traversa con le
    pulegge, funi, cabina rossa appesa al carrello; plinti di cemento"""
    rng = random.Random(161)
    pf = m.part("Teleferica_Traliccio", "FerroBattuto")
    ps = m.part("Teleferica_Plinti", "Granito")
    pc = m.part("Teleferica_Cabina", "LamieraRossa")
    pg = m.part("Teleferica_Vetri", "MAT_Glass")
    H, B, T_ = 14.0, 1.6, 0.6
    def corner(sx, sy, z):
        w = B + (T_ - B) * z / H
        return Vector((sx * w, sy * w, z))
    for sx in (-1, 1):
        for sy in (-1, 1):
            K._block(ps, Vector((sx * B, sy * B, 0.25)), (0.9, 0.9, 0.7), None, 0.04, rng.random(), chip=0.2, rng=rng, drop=((0, 0, -1),))
            L.cyl(pf, corner(sx, sy, 0.5), corner(sx, sy, H), 0.09, n=6)
    levels = [0.5 + (H - 0.5) * k / 7 for k in range(8)]
    faces = [((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))]
    for (a, b) in faces:
        for k in range(7):
            z0, z1 = levels[k], levels[k + 1]
            L.cyl(pf, corner(*a, z0), corner(*b, z0), 0.05, n=5)
            L.cyl(pf, corner(*a, z0), corner(*b, z1), 0.035, n=4)
            L.cyl(pf, corner(*b, z0), corner(*a, z1), 0.035, n=4)
    # traversa in cima con le pulegge e la scaletta
    L.box(pf, (0, 0, H + 0.15), (5.0, 0.3, 0.3))
    for sx in (-1, 1):
        L.cyl(pf, corner(sx, -1, H - 1.5), (sx * 2.4, 0, H), 0.05, n=4)
        L.cyl(pf, corner(sx, 1, H - 1.5), (sx * 2.4, 0, H), 0.05, n=4)
        for dy in (-0.6, 0.6):
            c = Vector((sx * 2.2, dy, H + 0.45))
            L.lathe(pf, [(0.0, -0.06), (0.35, -0.06), (0.3, 0.0), (0.35, 0.06), (0.0, 0.06)], 16,
                    M=Matrix.Translation(c) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
    for z in [0.8 + 0.35 * i for i in range(int((H - 1) / 0.35))]:
        L.box(pf, (corner(1, -1, z).x - 0.05, -corner(1, -1, z).y + 0.0 - 0.0 if False else corner(1, -1, z).y - 0.12, z), (0.3, 0.03, 0.03))
    # funi (portante e traente) da una parte all'altra
    for sx in (-1, 1):
        L.cyl(pf, (sx * 2.2, -25.0, H - 0.8), (sx * 2.2, 25.0, H - 0.8), 0.03, n=5, caps=False)
    # cabina rossa appesa a destra, 6 m dal pilone
    cy = -6.0
    top = Vector((2.2, cy, H - 0.8))
    L.box(pf, top + Vector((0, 0, 0.12)), (0.25, 1.2, 0.25))
    for dy in (-0.45, 0.45):
        L.lathe(pf, [(0.0, -0.05), (0.18, -0.05), (0.18, 0.05), (0.0, 0.05)], 12,
                M=Matrix.Translation(top + Vector((0, dy, 0.08))) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
    L.cyl(pf, top, top + Vector((0, 0, -2.4)), 0.07, n=6)
    L.box(pf, top + Vector((0, 0, -2.4)), (0.2, 1.6, 0.12))
    cz = top.z - 2.5 - 1.15
    cc = Vector((2.2, cy, cz))
    L.box(pc, cc, (2.0, 2.4, 2.3), bev=0.22, seg=3)
    L.box(pc, cc + Vector((0, 0, 1.2)), (1.6, 2.0, 0.15), bev=0.07, seg=2)
    for sx in (-1, 1):
        for dy in (-0.55, 0.55):
            L.box(pg, cc + Vector((sx * 1.005, dy, 0.35)), (0.02, 0.85, 0.9))
    for sy in (-1, 1):
        L.box(pg, cc + Vector((0, sy * 1.205, 0.35)), (1.5, 0.02, 0.9))
    L.box(pf, cc + Vector((0, 0, -1.2)), (2.1, 2.5, 0.08))
    m.marker("SPOT_Cabina", cc + Vector((0, 0, -1.1)))
    m.col("Pilone", (0, 0, H / 2), (2 * B, 2 * B, H))
    m.col("Cabina", cc, (2.0, 2.4, 2.3))
    m.notes.update({"misure_m": "pilone 3 x 14 x 3, cabina 2 x 2,3 x 2,4, funi lunghe 50 m (lungo Y)"})
    m.notes["viste_extra"] = {"dettaglio": ((6.0, -11.0, 9.5), (2.2, -6.0, 9.5), 30), "tre_quarti": ((18, -22, 14), (0, -3, 7), 30)}
    m.notes["umani"] = [(2.5, -1.5, 0.0)]


@modello
def FaroScogliera(m):
    """faro di pietra su scoglio: torre tonda rastremata a conci con fasce rosse, porta, finestrelle,
    ballatoio con ringhiera, lanterna a vetri con i montanti, cupola rossa; scogli attorno"""
    rng = random.Random(171)
    ps = m.part("Faro_Pietra", "PietraBianca")
    pr = m.part("Faro_Fasce", "LamieraRossa")
    pf = m.part("Faro_Ferro", "FerroBattuto")
    pg = m.part("Faro_Vetri", "MAT_Glass")
    pl = m.part("Faro_Luce", "MAT_WarmLight")
    pk = m.part("Faro_Scogli", "Granito")
    H = 13.0
    def door(t, z):
        return not (abs(math.atan2(math.sin(t + math.pi / 2), math.cos(t + math.pi / 2))) < 0.34 and z < 2.3)
    K.ring_ashlar(ps, Matrix.Identity(4), 2.4, 1.6, 0.0, H, rng, course=0.65, depth=0.45, lmin=1.6, lmax=2.6, clip=door)
    K.tint_fill(ps)
    L.lathe(ps, [(2.0, 0.0), (1.2, H)], 16, smooth=False, close=False)
    K.tint_fill(ps)
    for z in (4.2, 8.4):                       # fasce rosse
        r0 = 2.4 + (1.6 - 2.4) * z / H
        L.lathe(pr, [(r0 + 0.1, z), (r0 + 0.08, z + 1.3)], 24, smooth=True, close=False)
    K.arch(ps, Matrix.Rotation(0, 4, "Z") @ Matrix.Translation((0, -2.35, 0)), 0, 2.0, 0.55, 0.85, -0.05, 0.45, rng, n=7)
    L.box(m.part("Faro_Porta", "LegnoScuro"), (0, -2.1, 1.0), (1.1, 0.1, 2.0))
    for z, a in ((5.6, 0.0), (9.6, math.pi)):
        r0 = 2.4 + (1.6 - 2.4) * z / H
        q = Vector((math.sin(a) * r0, -math.cos(a) * r0, z))
        L.box(pg, q, (0.4, 0.06, 0.7), rot=Matrix.Rotation(a, 3, "Z"))
        L.box(pf, q + Vector((0, 0, 0.42)), (0.6, 0.15, 0.12), rot=Matrix.Rotation(a, 3, "Z"))
    # ballatoio: lastra sporgente su mensole, ringhiera
    L.lathe(ps, [(0.0, H), (2.3, H), (2.3, H + 0.25), (0.0, H + 0.25)], 24, smooth=False)
    K.tint_fill(ps)
    for i in range(12):
        a = 2 * math.pi * i / 12
        K._block(ps, Vector((math.cos(a) * 1.75, math.sin(a) * 1.75, H - 0.35)), (0.25, 0.8, 0.5), Matrix.Rotation(a + math.pi / 2, 3, "Z"), 0.03, rng.random())
    L.torus(pf, (0, 0, H + 1.2), 2.2, 0.04, nR=40, nr=4)
    L.torus(pf, (0, 0, H + 0.7), 2.2, 0.025, nR=40, nr=4)
    for i in range(24):
        a = 2 * math.pi * i / 24
        L.cyl(pf, (math.cos(a) * 2.2, math.sin(a) * 2.2, H + 0.25), (math.cos(a) * 2.2, math.sin(a) * 2.2, H + 1.2), 0.025, n=4)
    # lanterna: zoccolo, vetri con montanti, cupola rossa, pinnacolo
    L.lathe(pr, [(0.0, H + 0.25), (1.3, H + 0.25), (1.3, H + 0.9), (0.0, H + 0.9)], 16, smooth=False)
    L.lathe(pg, [(1.15, H + 0.9), (1.15, H + 2.6)], 16, smooth=False, close=False)
    for i in range(8):
        a = 2 * math.pi * i / 8
        L.cyl(pf, (math.cos(a) * 1.17, math.sin(a) * 1.17, H + 0.9), (math.cos(a) * 1.17, math.sin(a) * 1.17, H + 2.6), 0.05, n=5)
    L.sphere(pl, (0, 0, H + 1.7), 0.45, seg=12, rings=8)
    L.lathe(pr, [(0.0, H + 2.6), (1.4, H + 2.6), (1.35, H + 2.75), (1.0, H + 3.3), (0.45, H + 3.7), (0.15, H + 3.85), (0.0, H + 3.9)], 20)
    L.cyl(pf, (0, 0, H + 3.85), (0, 0, H + 4.6), 0.06, 0.02, n=6)
    L.sphere(pf, (0, 0, H + 3.95), 0.14, seg=8, rings=6)
    m.marker("FX_Light_Faro", (0, 0, H + 1.7))
    # scogli
    for i in range(7):
        a = 2 * math.pi * i / 7 + 0.3
        r = rng.uniform(2.6, 3.6)
        O.roccia(pk, (math.cos(a) * r, math.sin(a) * r, 0.1), (rng.uniform(1.6, 2.8), rng.uniform(1.4, 2.4), rng.uniform(0.9, 1.8)),
                 seed=1100 + i, res=10, crag=0.4, cuts=10)
    m.marker("SPOT_Porta", (0, -3.0, 0.0))
    for k, rr in enumerate((0.0, math.pi / 4)):
        m.col("Torre%d" % k, (0, 0, H / 2), (3.6, 3.6, H), Matrix.Rotation(rr + math.pi / 8, 3, "Z"))
    m.col("Ballatoio", (0, 0, H + 0.12), (4.4, 4.4, 0.25))
    m.notes.update({"misure_m": "5 x 18 x 5"})
    m.notes["viste_extra"] = {"dettaglio": ((3.5, -5.5, H + 2.5), (0, 0, H + 1.5), 30)}


@modello
def FossiliDrago(m):
    """fossili di drago (Meshy: teschio, vertebre, artiglio, ala ossea): qui la lastra di roccia a
    strati in cui sono incastrati, le pietre attorno e i segnaposto con le misure"""
    rng = random.Random(181)
    pk = m.part("Fossili_Roccia", "RocciaIsola")
    O.roccia(pk, (0, 0, 0.0), (9.0, 6.0, 1.6), seed=1200, res=18, crag=0.3, cuts=8, strata=0.04)
    for i in range(6):
        a = rng.uniform(0, 2 * math.pi)
        O.roccia(pk, (math.cos(a) * 5.0, math.sin(a) * 3.6, 0.1), (rng.uniform(0.8, 1.6),) * 2 + (0.7,), seed=1210 + i, res=7, crag=0.4, cuts=7)
    ph = m.part("PLACEHOLDER_Fossili", "OssoDrago")
    L.box(ph, (-2.6, 0.2, 0.9), (2.0, 1.4, 1.2))         # teschio (2 x 1,4 x 1,2)
    for k in range(7):                                    # vertebre
        L.box(ph, (-1.2 + k * 0.55, 0.0, 0.6), (0.4, 0.5, 0.45))
    L.box(ph, (2.8, -1.4, 0.6), (1.2, 0.6, 0.4))          # artiglio
    L.box(ph, (1.5, 1.6, 0.55), (4.0, 2.0, 0.15))         # ala ossea
    for nm, q in (("Teschio", (-2.6, 0.2, 0.9)), ("Vertebre", (0.45, 0.0, 0.6)), ("Artiglio", (2.8, -1.4, 0.6)), ("Ala", (1.5, 1.6, 0.55))):
        m.marker("SPOT_Fossile_" + nm, q)
    m.col("Lastra", (0, 0, 0.2), (8.0, 5.2, 1.2))
    m.notes.update({"misure_m": "lastra 9 x 1,6 x 6; fossili da Meshy (vedi MESHY_PROMPT.md)"})


def scafo(p, M, L_, B_, D_, sheer_bow, sheer_stern, flat=0.35, stations=18, ring=10):
    """scafo di giunca/sampan lungo X: fondo piatto, fianchi svasati, insellatura alta a prua (+X) e a
    poppa (-X), specchio di poppa piatto; restituisce le quote del ponte per stazione"""
    verts, faces = [], []
    secs = []
    for i in range(stations + 1):
        t = i / stations                      # 0 poppa, 1 prua
        x = -L_ / 2 + L_ * t
        u = 2 * t - 1
        b = B_ / 2 * (1 - abs(u) ** 2.4) ** 0.6 + (0.12 * B_ if t < 0.05 else 0)
        b = max(b, 0.06 * B_) if t > 0.97 else max(b, 0.32 * B_ if t < 0.03 else b)
        zb = D_ * (0.15 * u ** 4 + (0.25 if t > 0.9 else 0) * ((t - 0.9) / 0.1) ** 2)
        sheer = D_ + (sheer_stern * (1 - t) ** 3 + sheer_bow * t ** 3)
        row = []
        for j in range(ring + 1):
            k = j / ring                      # 0 chiglia, 1 bordo
            y = b * min(1.0, flat + (1 - flat) * k ** 0.7)
            z = zb + (sheer - zb) * (k ** 1.6)
            row.append((x, y, z))
        secs.append((x, sheer, b))
        for side in (1, -1):
            pass
        verts.append(row)
    out_v = []
    idx = {}
    for i, row in enumerate(verts):
        for j, (x, y, z) in enumerate(row):
            for side in (1, -1):
                idx[(i, j, side)] = len(out_v)
                out_v.append(tuple(M @ Vector((x, side * y, z))))
    fc = []
    for i in range(stations):
        for j in range(ring):
            a, b2, c, d = idx[(i, j, 1)], idx[(i + 1, j, 1)], idx[(i + 1, j + 1, 1)], idx[(i, j + 1, 1)]
            fc.append([a, b2, c, d])
            a, b2, c, d = idx[(i, j, -1)], idx[(i + 1, j, -1)], idx[(i + 1, j + 1, -1)], idx[(i, j + 1, -1)]
            fc.append([d, c, b2, a])
        fc.append([idx[(i, 0, -1)], idx[(i + 1, 0, -1)], idx[(i + 1, 0, 1)], idx[(i, 0, 1)]])
    # specchio di poppa e chiusura di prua
    st = [idx[(0, j, 1)] for j in range(ring + 1)] + [idx[(0, j, -1)] for j in range(ring, -1, -1)]
    fc.append(st[::-1])
    bw = [idx[(stations, j, 1)] for j in range(ring + 1)] + [idx[(stations, j, -1)] for j in range(ring, -1, -1)]
    fc.append(bw)
    p.add_raw(out_v, fc, smooth=True)
    return secs


@modello
def Giunca(m):
    """giunca cinese (18 x 12 x 5) e sampan (7 x 2,5 x 2) ormeggiabili: scafo di assi con fondo
    piatto e poppa alta, ponte, casseretto a poppa, tre alberi con vele a stecche di bambu',
    timone, occhi sulla prua; il sampan ha la copertura ad arco di stuoie"""
    rng = random.Random(191)
    # --- giunca (lungo X, prua verso +X), ingombro con le vele 18 x 12 x 5 m di scafo
    ph = m.part("Giunca_Scafo", "LegnoScuro")
    pd = m.part("Giunca_Ponte", "LegnoAsse")
    pv = m.part("Giunca_Vele", "VelaGiunca")
    pb = m.part("Giunca_Bambu", "Bambu")
    pr = m.part("Giunca_Corde", "Corda")
    pe = m.part("Giunca_Occhi", "MAT_Gold")
    pl = m.part("Giunca_Lanterne", "MAT_WarmLight")
    pf = m.part("Giunca_Ferro", "FerroBattuto")
    Lg, Bg, Dg = 18.0, 5.0, 2.4
    secs = scafo(ph, Matrix.Translation((0, 0, -1.2)), Lg, Bg, Dg, 1.2, 2.6)
    # ponte di assi (all'altezza del bordo meno 0,35) e falchetta
    zdeck = Dg - 1.2 - 0.35
    x = -Lg / 2 + 1.0
    while x < Lg / 2 - 1.6:
        t = (x + Lg / 2) / Lg
        u = 2 * t - 1
        b = Bg / 2 * (1 - abs(u) ** 2.4) ** 0.6 - 0.25
        K._block(pd, Vector((x + 0.15, 0, zdeck)), (0.28, 2 * b, 0.06), None, 0.01, rng.random())
        x += 0.3
    K.tint_fill(pd)
    for (xs, sheer, b) in secs[1:-1]:
        for side in (1, -1):
            L.box(ph, (xs, side * (b - 0.05), sheer - 1.2 + 0.05), (Lg / len(secs) + 0.05, 0.14, 0.12))
    # casseretto a poppa con il tetto curvo
    K._block(pd, Vector((-6.2, 0, zdeck + 1.0)), (3.6, 3.6, 2.0), None, 0.04, rng.random())
    L.box(ph, (-6.2, 0, zdeck + 2.1), (4.2, 4.2, 0.2), bev=0.06)
    for sx in (-1, 1):
        lanterna_carta(pl, pf, Vector((-4.2, sx * 1.6, zdeck + 1.6)), r=0.25, h=0.45)
    m.marker("FX_Light_Giunca1", (-4.2, -1.6, zdeck + 1.6))
    m.marker("FX_Light_Giunca2", (-4.2, 1.6, zdeck + 1.6))
    # timone
    K._block(ph, Vector((-Lg / 2 - 0.3, 0, -0.2)), (1.2, 0.15, 2.4), None, 0.03, rng.random())
    L.cyl(pb, (-Lg / 2 - 0.2, 0, 2.2), (-Lg / 2 + 1.5, 0, 2.4), 0.07, n=6)
    # occhi sulla prua
    for side in (1, -1):
        c = Vector((Lg / 2 - 1.6, side * 1.15, Dg - 1.2 - 0.1))
        L.cyl(pe, c, c + Vector((0, side * 0.05, 0)), 0.35, n=16)
        L.cyl(m.part("Giunca_Pupille", "Basalto"), c + Vector((0.05, side * 0.06, 0)), c + Vector((0.05, side * 0.09, 0)), 0.15, n=12)
    # alberi e vele a stecche (lug sail): vela trapezoidale con le stecche di bambu'
    for (xm, hm, wv, hv) in ((5.0, 9.0, 4.6, 6.2), (0.5, 11.5, 6.0, 8.2), (-4.8, 8.0, 4.0, 5.4)):
        L.cyl(pb, (xm, 0, zdeck), (xm, 0, zdeck + hm), 0.16, 0.08, n=8)
        z0, z1 = zdeck + hm - hv - 0.4, zdeck + hm - 0.4
        nb = 6
        prof = []
        for k in range(nb + 1):
            t = k / nb
            z = z0 + (z1 - z0) * t
            xa = xm - wv * 0.35 - 0.5 * t
            xb = xm + wv * 0.65 - 0.8 * t ** 2
            bulge = 0.25 * math.sin(math.pi * t)
            prof.append((xa, xb, z, bulge))
        verts, faces, uvs = [], [], []
        nx = 6
        for k, (xa, xb, z, bu) in enumerate(prof):
            for i in range(nx + 1):
                u = i / nx
                xx = xa + (xb - xa) * u
                yy = 0.35 + bu * math.sin(math.pi * u) + 0.12 * math.sin(math.pi * k)
                verts.append((xx, yy, z))
                uvs.append((u * wv / 2.0, (z - z0) / 2.0))
        w_ = nx + 1
        base = len(pv.v)
        pv.v.extend(verts)
        for k in range(nb):
            for i in range(nx):
                q = [k * w_ + i, k * w_ + i + 1, (k + 1) * w_ + i + 1, (k + 1) * w_ + i]
                pv.f.append(([base + a for a in q], True, [uvs[a] for a in q]))
                pv.f.append(([base + a for a in q][::-1], True, [uvs[a] for a in q][::-1]))
        for (xa, xb, z, bu) in prof:
            L.cyl(pb, (xa - 0.1, 0.35 + 0.05, z), (xb + 0.1, 0.35 + 0.05, z), 0.04, n=5)
        # scotte a ventaglio verso poppa
        for (xa, xb, z, bu) in prof[1:]:
            L.cyl(pr, (xa, 0.35, z), (xm - wv * 0.6, 0.3, zdeck + 0.5), 0.012, n=4, caps=False)
    m.marker("SPOT_Ormeggio_Giunca", (0, Bg / 2 + 0.3, zdeck))
    m.col("GiuncaScafo", (0, 0, -0.1), (Lg - 1.0, Bg - 0.4, 2.0))
    m.col("GiuncaPonte", (0, 0, zdeck), (Lg - 3.0, Bg - 0.8, 0.1))
    m.col("Casseretto", (-6.2, 0, zdeck + 1.0), (3.6, 3.6, 2.0))
    # --- sampan accanto (7 x 2,5 x 2), a +Y
    oy = 7.0
    ps = m.part("Sampan_Scafo", "LegnoScuro")
    pm = m.part("Sampan_Stuoia", "Bambu")
    scafo(ps, Matrix.Translation((0, oy, -0.4)), 7.0, 2.3, 0.9, 0.5, 0.6, stations=14, ring=8)
    x = -2.8
    while x < 2.6:
        K._block(m.part("Sampan_Ponte", "LegnoAsse"), Vector((x + 0.15, oy, 0.25)), (0.28, 1.7, 0.05), None, 0.01, rng.random())
        x += 0.32
    for i in range(9):                        # copertura ad arco di stuoie
        xx = -1.6 + i * 0.35
        pts = [Vector((xx, oy + 1.05 * math.cos(a), 0.3 + 1.1 * math.sin(a))) for a in [math.pi * k / 10 for k in range(11)]]
        L.tube(pm, pts, 0.03, n=5)
    verts, faces = [], []
    for k in range(11):
        a = math.pi * k / 10
        for xx in (-1.65, 1.15):
            verts.append((xx, oy + 1.07 * math.cos(a), 0.3 + 1.12 * math.sin(a)))
    for k in range(10):
        faces.append([2 * k, 2 * k + 1, 2 * k + 3, 2 * k + 2])
        faces.append([2 * k + 2, 2 * k + 3, 2 * k + 1, 2 * k])
    pm.add_raw(verts, faces, smooth=True)
    L.cyl(m.part("Sampan_Remo", "LegnoAsse"), (-3.6, oy, 0.9), (-2.4, oy + 0.2, 0.2), 0.04, n=6)
    m.marker("SPOT_Ormeggio_Sampan", (0, oy - 1.3, 0.3))
    m.col("Sampan", (0, oy, 0.0), (6.5, 2.0, 0.8))
    m.notes.update({"misure_m": "giunca 18 x 12 x 5 (lunga X, prua +X); sampan 7 x 2,5 x 2 a +Y"})
    m.notes["umani"] = [(1.0, 0.0, zdeck + 0.03), (0.0, oy, 0.28)]
    m.notes["terreno_z"] = -0.6
    m.notes["viste_extra"] = {"tre_quarti": ((22, -24, 12), (0, 2, 3), 30), "dettaglio": ((10.5, -5.0, 3.0), (7.0, 0, 1.5), 30)}


def VISTE_PICCOLO(h, d):
    up = max(h * 0.75, d * 0.38)
    return {
        "davanti": ((0, -d, max(h * 0.5, d * 0.2)), (0, 0, h * 0.4), 35),
        "tre_quarti": ((d * 0.7, -d * 0.75, up), (0, 0, h * 0.35), 35),
        "dietro": ((-d * 0.2, d, max(h * 0.55, d * 0.25)), (0, 0, h * 0.4), 35),
        "alto": ((0, -d * 0.12, d * 1.1), (0, 0, 0), 35),
        "umano": ((-d * 0.55, -d * 1.05, 1.6), (0, 0, h * 0.4), 35),
    }


LOOK = {
    "PietraBianca": {"dirt_z0": 0.0, "dirt_z1": 3.0, "moss": 0.4, "streak": 0.35},
    "Granito": {"dirt_z0": 0.0, "dirt_z1": 0.9, "moss": 0.7, "streak": 0.2},
    "Corteccia": {"dirt_z0": 0.5, "dirt_z1": 2.0, "moss": 0.5, "streak": 0.1, "ao_dist": 0.4, "edge_r": 0.03, "tint": 0.0},
    "PietraVulcanica": {"dirt_z0": 0.0, "dirt_z1": 2.0, "moss": 0.5},
    "Granito_basso": {},
    "AghiPino": {"dirt": 0.0, "moss": 0.0, "streak": 0.0, "ao_dist": 0.8, "ao_min": 0.3, "edge_r": 0.02, "tint": 0.1},
    "Scandole": {"dirt_z0": 5.0, "dirt_z1": 9.0, "dirt": 0.2, "moss": 0.5, "streak": 0.2, "ao_dist": 0.6, "edge_r": 0.02, "tint": 0.0},
    "Neve": {"dirt": 0.0, "moss": 0.0, "streak": 0.0, "ao_dist": 0.3, "ao_min": 0.6, "edge_r": 0.02, "tint": 0.0,
             "wear_col": (0.0, 0.0, 0.0)},
    "LamieraRossa": {"dirt_z0": 0.0, "dirt_z1": 1.5, "moss": 0.0, "streak": 0.5, "ao_dist": 0.5, "edge_r": 0.01, "tint": 0.0,
                     "dirt_col": (0.25, 0.09, 0.04), "wear_col": (0.35, 0.3, 0.27)},
    "LegnoAsse": {"dirt_z0": -0.2, "dirt_z1": 0.8, "moss": 0.15, "streak": 0.1, "ao_dist": 0.3, "edge_r": 0.015, "tint": 0.2},
    "LegnoScuro": {"dirt_z0": -0.2, "dirt_z1": 0.6, "moss": 0.1, "streak": 0.1, "ao_dist": 0.3, "edge_r": 0.02, "tint": 0.15},
}


def _main():
    args = L.argv()
    nome = args[args.index("--modello") + 1]
    L.clear_scene()
    m = L.Model(nome)
    MODELLI[nome](m)
    import cottura as C

    def cuoci(objs, texdir):
        for o in objs:
            mat = o.data.materials[0].name
            if mat in LOOK and not o.name.startswith("PLACEHOLDER"):
                C.bake_piece(o, mat, texdir, texdir, "Cotto_" + o.name, res=1024, look=LOOK[mat])
    objs, cobs, info = L.export(m, before_fbx=None if "--niente-cottura" in args else cuoci)
    if "--render" in args:
        import anteprime as A
        for o in objs:
            if o.name in m.notes.get("nascondi_in_anteprima", []):
                o.hide_render = True
        h = info["ingombro_m"][2]
        d = max(info["ingombro_m"]) * 2.2 + 2
        views = VISTE_PICCOLO(h, d)
        views.update(m.notes.get("viste_extra", {}))
        umani = m.notes.get("umani", [(-1.8 - info["ingombro_m"][0] / 2, -1.0, 0.0)])
        A.render(nome, views, umani, ground=((0, 0, m.notes.get("terreno_z", 0.0)), 200, (0.16, 0.2, 0.1)))


if __name__ == "__main__":
    _main()
