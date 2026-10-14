# Arena dei Draghi (docs/CLOUD_SESSIONE.md, priorita' 1): colosseo ottagonale, 8 torri (una per
# elemento), portale con due teste di drago, pedana del domatore, palco d'onore, altare del Duello.
#   blender -b --factory-startup --python tools/blender/arena.py -- [--render] [--solo-render vista,...]
# Scrive cloud/ArenaDraghi/ (ArenaDraghi.fbx, ArenaDraghi_Collision.fbx, Markers.json, Textures/, anteprime/).
#
# Misure (metri; Blender Z in alto, l'ingresso guarda verso -Y = +Z di Roblox):
# - pianta ottagonale: apotema interno 75 (diametro interno 150), esterno 95 (circa 190)
# - podio 5 m, 10 gradoni (1.7 m x 1 m) fino a 22 m, camminamento, parapetto a 25 m e merli
# - fuori: arcate a due piani (stile Colosseo), fasce, cornicione merlato
# - torri al centro degli spigoli (raggio 9, alte 40 con il braciere), portale sul lato -Y
# Lato k dell'ottagono: sistema locale ruotato di 45*k gradi; nel locale la faccia esterna guarda
# -Y e il centro dell'arena sta verso +Y (distanza dal centro r = -y).

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cloud_lib as L
from cloud_lib import Vector, Matrix, box, boxz, cyl, lathe, prism, sphere, tube, torus, chain, cornice

T = math.tan(math.radians(22.5))
R_IN, R_OUT = 75.0, 95.0
R_POD = 76.5                  # fine del podio
STEP_RUN, STEP_RISE, STEPS = 1.0, 1.7, 10
R_STEPS_END = R_POD + STEP_RUN * STEPS     # 86.5
R_BACK = 89.5                 # parete di fondo della galleria
R_SLAB = 92.5                 # spessore del muro esterno: 92.5 .. 95
Z_POD, Z_DECK, Z_PARA = 5.0, 22.0, 25.0
GATE = 20.0                   # mezza larghezza del corpo del portale (lato 0, fuori)
GATE_IN = 13.5                # mezza larghezza del portale dentro le gradinate
LOGGIA = 13.0                 # mezza larghezza del palco (lato 4)
BAY = 8.5                     # passo delle arcate esterne
TORRE_D, TORRE_R = 100.0, 9.0
PEDANA = Vector((0.0, -120.0, 0.0))
ALTARE = Vector((16.5, -121.0, 0.0))
INF = 1e9

m = L.Model("ArenaDraghi")
rng = random.Random(7)


def side_M(k):
    return Matrix.Rotation(math.radians(45 * k), 4, "Z")


def gap_of(k):
    return GATE_IN if k == 0 else (LOGGIA if k == 4 else 0.0)


def ranges(gap, lim=INF):
    if gap <= 0:
        return [(-lim, lim)]
    return [(-lim, -gap), (gap, lim)]


def oslab(p, r0, r1, z0, z1, xa=-INF, xb=INF, M=None, cap=True):
    """lastra fra i raggi r0 < r1 (tagliata a 22.5 gradi agli spigoli), opzionale fra x = xa e xb"""
    pts = []
    for r, side in ((r0, 1), (r1, -1)):
        xl, xr = max(xa, -r * T), min(xb, r * T)
        if xl >= xr - 1e-3:
            return
        if side > 0:
            pts += [(xl, -r), (xr, -r)]
        else:
            pts += [(xr, -r), (xl, -r)]
    prism(p, pts, z0, z1, M, cap=cap)


def mcol(name, M, x0, x1, r0, r1, z0, z1):
    """scatola di collisione nel sistema del lato"""
    c = M @ Vector(((x0 + x1) / 2, -(r0 + r1) / 2, (z0 + z1) / 2))
    R = M.to_3x3()
    m.col(name, c, (x1 - x0, r1 - r0, z1 - z0), R)


# ---------------------------------------------------------------------------------------------
# rune (tratti nel quadratino [-0.5, 0.5]) e simboli degli elementi (forme 2D estruse)

def rune_strokes(r):
    st = [((0.0, -0.5), (0.0, 0.5))] if r.random() < 0.8 else [((-0.25, -0.5), (-0.25, 0.5)), ((0.25, -0.5), (0.25, 0.5))]
    opts = [((0.0, 0.5), (0.35, 0.2)), ((0.0, 0.2), (0.35, -0.1)), ((0.0, 0.5), (-0.35, 0.2)), ((0.0, -0.1), (0.35, -0.4)),
            ((-0.35, 0.3), (0.35, -0.3)), ((0.0, 0.0), (-0.35, -0.35)), ((0.0, 0.3), (0.3, 0.0)), ((0.3, 0.0), (0.0, -0.3)),
            ((-0.3, 0.5), (0.3, 0.5))]
    for o in r.sample(opts, r.choice((1, 2, 2, 3))):
        st.append(o)
    return st


def stroke_pts(a, b, w):
    a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
    d = (b - a)
    if d.length < 1e-6:
        return None
    d.normalize()
    n = Vector((-d.y, d.x, 0)) * w / 2
    a2, b2 = a - d * w / 2, b + d * w / 2
    return [(a2 + n).to_2d(), (b2 + n).to_2d(), (b2 - n).to_2d(), (a2 - n).to_2d()]


def strokes_geo(p, strokes, w, M, depth):
    """tratti (in 2D) estrusi da 0 a depth lungo la Z locale di M"""
    for a, b in strokes:
        q = stroke_pts(a, b, w)
        if q:
            prism(p, [tuple(v) for v in q], 0.0, depth, M)


def poly_geo(p, pts, M, depth):
    prism(p, pts, 0.0, depth, M)


def circle_strokes(cx, cy, r, n=20, a0=0.0, a1=2 * math.pi):
    pts = [(cx + r * math.cos(a0 + (a1 - a0) * i / n), cy + r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]
    return list(zip(pts, pts[1:]))


def symbol_geo(p, el, M, s=1.0, depth=0.3):
    """simbolo dell'elemento in rilievo, alto circa 2*s, nel piano XY di M (estruso lungo Z)"""
    w = 0.16 * s
    R = s
    if el == "Roccia":
        poly_geo(p, [(-R, -0.7 * R), (-0.25 * R, 0.8 * R), (0.35 * R, -0.7 * R)], M, depth)
        poly_geo(p, [(-0.1 * R, -0.7 * R), (0.45 * R, 0.3 * R), (R, -0.7 * R)], M, depth * 0.8)
    elif el == "Gelo":
        st = []
        for a in range(3):
            t = a * math.pi / 3 + math.pi / 2
            st.append(((-R * math.cos(t), -R * math.sin(t)), (R * math.cos(t), R * math.sin(t))))
            for sg in (-1, 1):
                bx, by = sg * R * 0.6 * math.cos(t), sg * R * 0.6 * math.sin(t)
                for d in (-1, 1):
                    tt = t + d * math.pi / 4
                    st.append(((bx, by), (bx + sg * R * 0.32 * math.cos(tt), by + sg * R * 0.32 * math.sin(tt))))
        strokes_geo(p, st, w, M, depth)
    elif el == "Cosmico":
        pts = []
        for k in range(8):
            r = R if k % 2 == 0 else R * 0.28
            a = k * math.pi / 4 + math.pi / 2
            pts.append((r * math.cos(a), r * math.sin(a)))
        poly_geo(p, pts, M, depth)
        strokes_geo(p, circle_strokes(0.72 * R, 0.72 * R, 0.22 * R, 10, -0.6, 3.6), w * 0.7, M, depth)
    elif el == "Tempesta":
        st = []
        for k in range(3):
            yb = 0.6 * R - k * 0.6 * R
            prev = None
            for i in range(11):
                x = -R + i * 2 * R / 10
                y = yb + math.sin(i / 10 * 2 * math.pi) * 0.18 * R
                if prev:
                    st.append((prev, (x, y)))
                prev = (x, y)
        strokes_geo(p, st, w, M, depth)
    elif el == "Eclissi":
        strokes_geo(p, circle_strokes(0, 0, R * 0.9, 28), w * 1.3, M, depth)
        n = 20
        poly_geo(p, [(0.15 * R + 0.62 * R * math.cos(2 * math.pi * i / n), 0.1 * R + 0.62 * R * math.sin(2 * math.pi * i / n)) for i in range(n)], M, depth * 0.5)
    elif el == "Fulmine":
        poly_geo(p, [(0.15 * R, R), (-0.55 * R, -0.1 * R), (-0.02 * R, -0.1 * R), (-0.25 * R, -R), (0.6 * R, 0.15 * R), (0.05 * R, 0.15 * R)], M, depth)
    elif el == "Ossa":
        st = [((-0.8 * R, -0.8 * R), (0.8 * R, 0.8 * R)), ((-0.8 * R, 0.8 * R), (0.8 * R, -0.8 * R))]
        strokes_geo(p, st, w * 1.4, M, depth)
        for ex, ey in ((-0.8, -0.8), (0.8, 0.8), (-0.8, 0.8), (0.8, -0.8)):
            for dx, dy in ((0.12, -0.12), (-0.12, 0.12)) if ex * ey > 0 else ((0.12, 0.12), (-0.12, -0.12)):
                n = 10
                poly_geo(p, [(ex * R + dx * R + 0.16 * R * math.cos(2 * math.pi * i / n), ey * R + dy * R + 0.16 * R * math.sin(2 * math.pi * i / n)) for i in range(n)], M, depth)
    elif el == "Gas":
        for (dx, dy, r) in ((-0.35, -0.35, 0.42), (0.38, -0.2, 0.32), (0.0, 0.45, 0.3)):
            strokes_geo(p, circle_strokes(dx * R, dy * R, r * R, 16), w * 0.9, M, depth)
            n = 8
            poly_geo(p, [((dx - 0.12) * R + 0.08 * R * math.cos(2 * math.pi * i / n), (dy + 0.12) * R + 0.08 * R * math.sin(2 * math.pi * i / n)) for i in range(n)], M, depth)
    elif el == "Stella":   # stella a 8 punte (stemma dell'arena)
        pts = []
        for k in range(16):
            r = R if k % 2 == 0 else R * 0.45
            a = k * math.pi / 8 + math.pi / 2
            pts.append((r * math.cos(a), r * math.sin(a)))
        poly_geo(p, pts, M, depth)


def plane_M(origin, right, up):
    """matrice per disegnare nel piano (right, up), estrusione verso right x up"""
    right, up = Vector(right).normalized(), Vector(up).normalized()
    out = right.cross(up)
    return Matrix.Translation(Vector(origin)) @ Matrix((right, up, out)).transposed().to_4x4()


# ---------------------------------------------------------------------------------------------
# posatoio dei draghi selvatici: base di pietra, palo di ferro, traversa, anello con catene

def posatoio(k_name, M, base_z, p_stone, p_iron, p_gold, h=7.0):
    B = lambda x, y, z: M @ Vector((x, y, z))
    box(p_stone, B(0, 0, base_z + 0.6), (2.6, 2.6, 1.2), rot=M.to_3x3(), bev=0.15)
    box(p_stone, B(0, 0, base_z + 1.4), (1.8, 1.8, 0.4), rot=M.to_3x3(), bev=0.1)
    top = base_z + h
    cyl(p_iron, B(0, 0, base_z + 1.5), B(0, 0, top), 0.34, 0.28, n=10)
    for z in (base_z + 2.0, base_z + h * 0.55, top - 0.5):
        cyl(p_iron, B(0, 0, z - 0.15), B(0, 0, z + 0.15), 0.45, n=10)
    cyl(p_iron, B(-2.4, 0, top), B(2.4, 0, top), 0.26, n=8)
    for sx in (-1, 1):
        cyl(p_iron, B(sx * 1.6, 0, top - 0.05), B(sx * 0.3, 0, top - 1.4), 0.12, n=6)       # saette
        sphere(p_gold, B(sx * 2.5, 0, top), 0.33, seg=10, rings=6)
        cyl(p_gold, B(sx * 2.75, 0, top), B(sx * 3.2, 0, top + 0.1), 0.18, 0.0, n=8)
    torus(p_iron, B(0, 0, top - 1.45), 1.15, 0.13, normal=M.to_3x3() @ Vector((0, 1, 0)), nR=20, nr=6)
    for sx in (-1, 1):
        chain(p_iron, B(sx * 0.55, 0, top - 2.45), B(sx * 1.2, -0.9 if sx > 0 else 0.9, base_z + 1.25), sag=0.4, link=0.42, thick=0.06)
    m.marker("SPOT_Posatoio%s" % k_name, B(0, 0, top + 0.3))
    m.col("Posatoio%s" % k_name, B(0, 0, base_z + (h + 0.4) / 2), (1.0, 1.0, h + 0.4), M.to_3x3())


# ---------------------------------------------------------------------------------------------
# mura: un ottavo per oggetto

def mura(k):
    M = side_M(k)
    nm = "Arena_Mura_%02d" % (k + 1)
    ps = m.part(nm, "PietraScura")
    pc = m.part(nm + "_Cornici", "PietraCornice")
    pf = m.part(nm + "_Ferro", "FerroBattuto")
    gap = gap_of(k)
    deck_gap = GATE if k == 0 else 0.0
    for xa, xb in ranges(gap):
        # podio, gradoni, massa dietro
        oslab(ps, R_IN, R_POD, -6.0, Z_POD, xa, xb, M)
        oslab(pc, R_IN - 0.35, R_POD + 0.1, Z_POD, Z_POD + 0.45, xa, xb, M)               # copertina del podio
        oslab(pc, R_IN - 0.2, R_IN + 0.3, -0.2, 0.8, xa, xb, M)                            # zoccolo
        oslab(pc, R_IN - 0.12, R_IN + 0.3, 3.4, 3.8, xa, xb, M)                            # fascia
        for s in range(STEPS):
            r0 = R_POD + s * STEP_RUN
            z1 = Z_POD + STEP_RISE * (s + 1)
            oslab(ps, r0, r0 + STEP_RUN, z1 - STEP_RISE - 0.3, z1, xa, xb, M)
            oslab(pc, r0 - 0.18, r0 + 0.25, z1 - 0.22, z1 + 0.06, xa, xb, M)              # spigolo del gradone
        oslab(ps, R_STEPS_END, R_BACK, -6.0, Z_DECK, xa, xb, M)
    for xa, xb in ranges(deck_gap):
        oslab(ps, R_BACK, R_SLAB, -6.0, 0.0, xa, xb, M)                                    # pavimento della galleria
        oslab(ps, R_BACK, R_SLAB, 11.9, 12.5, xa, xb, M)                                   # solaio del primo piano
        oslab(ps, R_BACK, R_SLAB, Z_DECK - 0.8, Z_DECK, xa, xb, M)                         # camminamento
    # muro esterno con le arcate (booleano)
    outer = L.Part("tmp_outer", "PietraScura")
    for xa, xb in ranges(deck_gap):
        oslab(outer, R_SLAB, R_OUT, -6.0, Z_PARA, xa, xb)
    cut = L.Part("tmp_cut", "PietraScura")
    bays = [i * BAY for i in range(-3, 4)]
    bays = [x for x in bays if abs(x) - BAY / 2 >= deck_gap - 0.01]
    for x in bays:
        L.arch_cutter(cut, x, 6.0, 0.0, 7.5, -R_OUT - 0.5, -R_SLAB + 0.5)
        L.arch_cutter(cut, x, 5.2, 12.5, 17.9, -R_OUT - 0.5, -R_SLAB + 0.5)
        prism(cut, [(x - 0.8, -R_OUT - 0.5), (x + 0.8, -R_OUT - 0.5), (x + 0.8, -R_SLAB + 0.5), (x - 0.8, -R_SLAB + 0.5)], 22.9, 24.3)
    if cut.f:
        L.boolean(outer, cut)
    outer.v = [tuple(M @ Vector(v)) for v in outer.v]
    base = len(ps.v)
    ps.v.extend(outer.v)
    ps.f.extend([([base + i for i in f[0]], False, None) for f in outer.f])
    # galleria: parete di fondo con lesene scure
    for x in bays:
        for z0, z1 in ((0.0, 11.9), (12.5, 21.2)):
            box(pc, M @ Vector((x - BAY / 2, -R_BACK - 0.25, (z0 + z1) / 2)), (0.9, 0.5, z1 - z0), rot=M.to_3x3())
    # facciata: semicolonne, ghiere, chiavi, fasce, cornicione, merli
    xs_lim = 30.5
    edges = sorted(set([x - BAY / 2 for x in bays] + [x + BAY / 2 for x in bays]))
    for x in edges:
        if abs(x) > 30.0:
            continue
        for z0, z1, r in ((0.0, 11.0, 0.8), (12.5, 21.0, 0.68)):
            box(pc, M @ Vector((x, -R_OUT - 0.4, z0 + 0.4)), (2.2, 0.9, 0.8), rot=M.to_3x3(), bev=0.08)          # piedistallo
            lathe(pc, [(r * 1.25, z0 + 0.8), (r * 1.25, z0 + 1.05), (r * 1.05, z0 + 1.25), (r, z0 + 1.5), (r, z1 - 1.2),
                       (r * 1.08, z1 - 1.0), (r * 1.3, z1 - 0.55), (r * 1.45, z1 - 0.3), (r * 1.45, z1)],
                  6, (0, 0, 0), math.pi, 2 * math.pi, M=M @ Matrix.Translation((x, -R_OUT, 0)))
    for x in bays:
        L.arch_ring(pc, x, 6.0, 7.5, -R_OUT - 0.3, -R_OUT + 0.05, band=0.75, segs=12, M=M)
        L.arch_ring(pc, x, 5.2, 17.9, -R_OUT - 0.25, -R_OUT + 0.05, band=0.6, segs=12, M=M)
        box(pc, M @ Vector((x, -R_OUT - 0.25, 10.85)), (1.0, 0.7, 1.4), rot=M.to_3x3(), bev=0.08)                 # chiave
        box(pc, M @ Vector((x, -R_OUT - 0.2, 20.7)), (0.85, 0.6, 1.2), rot=M.to_3x3(), bev=0.08)
        box(pc, M @ Vector((x, -R_OUT - 0.1, 22.8)), (2.0, 0.3, 0.2), rot=M.to_3x3())                            # davanzale
        # cancellate di ferro nelle arcate del piano terra
        for i in range(9):
            bx = x - 2.6 + i * 0.65
            top = 7.5 + math.sqrt(max(9.0 - (bx - x) ** 2, 0.0)) - 0.05
            box(pf, M @ Vector((bx, -R_SLAB - 1.25, top / 2)), (0.12, 0.12, top), rot=M.to_3x3())
            cyl(pf, M @ Vector((bx, -R_SLAB - 1.25, top - 0.05)), M @ Vector((bx, -R_SLAB - 1.25, top + 0.35)), 0.09, 0.0, n=4) if top < 9.5 else None
        for z in (3.0, 6.0):
            box(pf, M @ Vector((x, -R_SLAB - 1.25, z)), (6.0, 0.1, 0.18), rot=M.to_3x3())
    for xa, xb in ranges(deck_gap, xs_lim):
        for z0, prof in ((11.0, [(0.0, 0.0), (0.35, 0.0), (0.35, 0.35), (0.6, 0.6), (0.6, 1.1), (0.75, 1.2), (0.75, 1.5), (0.0, 1.5)]),
                         (21.0, [(0.0, 0.0), (0.3, 0.0), (0.3, 0.3), (0.5, 0.55), (0.5, 1.0), (0.65, 1.1), (0.65, 1.3), (0.0, 1.3)]),
                         (25.0, [(0.0, -0.6), (0.25, -0.6), (0.25, -0.3), (0.55, 0.0), (0.95, 0.35), (1.05, 0.55), (1.05, 0.85), (0.0, 0.85)])):
            cornice(pc, [(y, z0 + z) for y, z in prof], max(xa, -xs_lim), min(xb, xs_lim), M @ Matrix.Translation((0, -R_OUT, 0)))
        cornice(pc, [(0.0, -6.0), (0.5, -6.0), (0.5, 0.35), (0.25, 0.6), (0.0, 0.6)], max(xa, -xs_lim), min(xb, xs_lim), M @ Matrix.Translation((0, -R_OUT, 0)))
        # merli sul parapetto
        x = -29.9
        while x <= 29.95:
            if xa <= x - 0.8 and x + 0.8 <= xb:
                box(ps, M @ Vector((x, -(R_SLAB + R_OUT) / 2 - 0.15, Z_PARA + 0.85 + 1.25)), (1.6, R_OUT - R_SLAB + 0.3, 2.5), rot=M.to_3x3(), bev=0.12)
                box(pc, M @ Vector((x, -(R_SLAB + R_OUT) / 2 - 0.15, Z_PARA + 0.85 + 2.6)), (1.8, R_OUT - R_SLAB + 0.5, 0.25), rot=M.to_3x3(), bev=0.06)
            x += 2.6
    # ringhiera di ferro sul podio
    for xa, xb in ranges(gap):
        lim = R_IN * T - 1.0
        a, b = max(xa, -lim), min(xb, lim)
        if gap and xa < 0:
            b -= 0.5
        if gap and xa > 0:
            a += 0.5
        if a >= b:
            continue
        n = max(1, int((b - a) / 2.5))
        for i in range(n + 1):
            x = a + (b - a) * i / n
            cyl(pf, M @ Vector((x, -R_IN - 0.25, Z_POD + 0.45)), M @ Vector((x, -R_IN - 0.25, Z_POD + 1.75)), 0.07, n=6)
            cyl(pf, M @ Vector((x, -R_IN - 0.25, Z_POD + 1.75)), M @ Vector((x, -R_IN - 0.25, Z_POD + 2.05)), 0.07, 0.0, n=4)
        for z in (Z_POD + 1.0, Z_POD + 1.6):
            cyl(pf, M @ Vector((a, -R_IN - 0.25, z)), M @ Vector((b, -R_IN - 0.25, z)), 0.05, n=6)
    # cancelli delle belve nel podio
    if k not in (0, 4):
        for gx in (-14.0, 14.0):
            box(ps, M @ Vector((gx, -R_IN - 0.4, 2.2)), (4.6, 0.3, 4.4), rot=M.to_3x3())   # fondo scuro (riempito dal ferro)
            L.arch_ring(pc, gx, 3.6, 2.6, -R_IN - 0.45, -R_IN + 0.05, band=0.5, segs=10, M=M)
            for i in range(7):
                bx = gx - 1.5 + i * 0.5
                top = 2.6 + math.sqrt(max(1.8 ** 2 - (bx - gx) ** 2, 0)) - 0.05
                box(pf, M @ Vector((bx, -R_IN - 0.6, top / 2)), (0.12, 0.12, top), rot=M.to_3x3())
            for z in (1.0, 2.2, 3.4):
                hw = 1.8 if z < 2.6 else math.sqrt(max(1.8 ** 2 - (z - 2.6) ** 2, 0))
                box(pf, M @ Vector((gx, -R_IN - 0.62, z)), (hw * 2, 0.1, 0.14), rot=M.to_3x3())
    # parapetti fra i settori delle gradinate
    for px in ((-22.0, 22.0) if k != 0 else ()):
        if abs(px) < gap + 1:
            continue
        pts = [(-R_POD + 0.3, Z_POD - 0.2), (-R_STEPS_END, Z_DECK - 0.2), (-R_STEPS_END, Z_DECK + 1.1), (-R_POD + 0.3, Z_POD + 1.1)]
        Mp = M @ Matrix.Translation((px, 0, 0)) @ Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
        prism(pc, pts[::-1], -0.4, 0.4, Mp)
    # posatoio sul camminamento (sul portale e sul palco li mettono quei pezzi)
    if k not in (0, 4):
        posatoio(str(k + 1), M @ Matrix.Translation((0, -(R_BACK + R_SLAB) / 2 + 1.2, 0)), Z_DECK, pc, pf, pc)
    # collisioni
    for xa, xb in ranges(gap):
        def w(r):
            return max(xa, -r * T), min(xb, r * T)
        a, b = w(R_POD)
        mcol("%s_Podio%s" % (nm, "A" if xa < 0 else "B"), M, a, b, R_IN, R_POD, -6, Z_POD)
        for s in range(STEPS):
            r0 = R_POD + s * STEP_RUN
            a, b = w(r0 + STEP_RUN)
            mcol("%s_Gradone%d%s" % (nm, s + 1, "A" if xa < 0 else "B"), M, a, b, r0, r0 + STEP_RUN, -6, Z_POD + STEP_RISE * (s + 1))
        a, b = w(R_BACK)
        mcol("%s_Fondo%s" % (nm, "A" if xa < 0 else "B"), M, a, b, R_STEPS_END, R_BACK, -6, Z_DECK)
    for xa, xb in ranges(deck_gap):
        a, b = max(xa, -R_SLAB * T), min(xb, R_SLAB * T)
        mcol("%s_Camminamento%s" % (nm, "A" if xa < 0 else "B"), M, a, b, R_BACK, R_SLAB, Z_DECK - 0.8, Z_DECK)
        a, b = max(xa, -R_OUT * T), min(xb, R_OUT * T)
        mcol("%s_MuroEsterno%s" % (nm, "A" if xa < 0 else "B"), M, a, b, R_SLAB, R_OUT, -6, Z_PARA + 2.0)


# ---------------------------------------------------------------------------------------------
# torri: una per elemento, al centro degli spigoli

def torre(j):
    el = L.ELEMENTI[j]
    phi = math.radians(-90 + 22.5 + 45 * j)
    c = Vector((TORRE_D * math.cos(phi), TORRE_D * math.sin(phi), 0))
    M = Matrix.Translation(c) @ Matrix.Rotation(phi + math.pi / 2, 4, "Z")     # locale -Y = fuori
    nm = "Arena_Torre_" + el
    ps = m.part(nm, "PietraScura")
    pc = m.part(nm + "_Cornici", "PietraCornice")
    pf = m.part(nm + "_Ferro", "FerroBattuto")
    pg = m.part(nm + "_Oro", "OroAntico")
    pe = m.part(nm + "_Braci", "MAT_Ember")
    R = TORRE_R
    lathe(ps, [(11.2, -6.0), (11.2, -0.6), (10.6, 0.6), (R + 0.3, 4.6), (R, 5.0), (R, 33.0)], 28, M=M, smooth=True)
    lathe(pc, [(11.35, -0.6), (11.35, -0.2), (11.0, 0.4)], 28, M=M, close=False)
    lathe(pc, [(R + 0.4, 4.4), (R + 0.55, 4.6), (R + 0.55, 5.1), (R, 5.4)], 28, M=M, close=False)
    for z in (11.0, 21.0):
        lathe(pc, [(R, z), (R + 0.45, z + 0.2), (R + 0.45, z + 0.9), (R + 0.6, z + 1.0), (R + 0.6, z + 1.25), (R, z + 1.45)], 28, M=M, close=False)
    # beccatelli e parapetto in cima
    lathe(pc, [(R, 33.0), (R + 0.15, 33.0), (R + 0.15, 34.0), (R + 1.4, 34.0), (R + 1.4, 34.6), (R, 34.6)], 28, M=M)
    for i in range(28):
        a = 2 * math.pi * (i + 0.5) / 28
        q = M @ Vector(((R + 0.6) * math.cos(a), (R + 0.6) * math.sin(a), 33.4))
        box(pc, q, (1.2, 0.7, 1.2), rot=M.to_3x3() @ Matrix.Rotation(a, 3, "Z"), bev=0.08)
    lathe(ps, [(R + 0.2, 34.6), (R + 1.3, 34.6), (R + 1.3, 36.6), (R + 0.2, 36.6), (R + 0.2, 34.6)], 28, M=M, close=False)
    for i in range(14):
        a = 2 * math.pi * i / 14
        q = M @ Vector(((R + 0.75) * math.cos(a), (R + 0.75) * math.sin(a), 37.75))
        box(ps, q, (1.25, 2.3, 2.3), rot=M.to_3x3() @ Matrix.Rotation(a, 3, "Z"), bev=0.12)
        q2 = M @ Vector(((R + 0.75) * math.cos(a), (R + 0.75) * math.sin(a), 38.98))
        box(pc, q2, (1.4, 2.5, 0.2), rot=M.to_3x3() @ Matrix.Rotation(a, 3, "Z"), bev=0.05)
    lathe(pc, [(R + 0.25, 36.6), (R + 1.45, 36.6), (R + 1.45, 36.9), (R + 0.25, 36.9), (R + 0.25, 36.6)], 28, M=M, close=False)
    # braciere in cima: colonna di pietra, coppa di ferro, braci
    lathe(pc, [(2.6, 34.6), (2.6, 35.2), (2.0, 35.5), (1.4, 35.8), (1.2, 37.4), (1.6, 37.7), (1.9, 37.9)], 16, M=M)
    lathe(pf, [(1.5, 37.8), (2.6, 38.1), (3.3, 38.7), (3.6, 39.5), (3.75, 39.9), (3.45, 39.9), (3.1, 39.2), (0.5, 38.6)], 20, M=M, close=False)
    for i in range(8):
        a = 2 * math.pi * i / 8
        cyl(pf, M @ Vector((3.2 * math.cos(a), 3.2 * math.sin(a), 38.5)), M @ Vector((3.95 * math.cos(a), 3.95 * math.sin(a), 40.3)), 0.12, 0.0, n=5)
    lathe(pe, [(3.15, 39.4), (2.2, 39.65), (1.0, 39.85), (0.01, 39.95)], 16, M=M, close=False)
    for i in range(9):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.2, 2.4)
        sphere(pe, M @ Vector((r * math.cos(a), r * math.sin(a), 39.7)), rng.uniform(0.25, 0.45), (1, 1, 0.6), seg=6, rings=4)
    m.marker("FX_Fire_Torre" + el, M @ Vector((0, 0, 40.2)))
    m.marker("FX_Light_Torre" + el, M @ Vector((0, 0, 41.5)))
    # feritoie (verso fuori, non dove attaccano le mura)
    for z, angs in ((8.0, (-90, -135, -45)), (17.0, (-140, -40)), (27.0, (-140, -40))):
        for ad in angs:
            a = math.radians(ad)
            Rz = M.to_3x3() @ Matrix.Rotation(a + math.pi / 2, 3, "Z")
            q = M @ Vector((R * math.cos(a), R * math.sin(a), z))
            box(pf, q, (0.5, 0.5, 2.6), rot=Rz)
            q2 = M @ Vector(((R + 0.12) * math.cos(a), (R + 0.12) * math.sin(a), z + 1.55))
            box(pc, q2, (1.4, 0.45, 0.5), rot=Rz, bev=0.06)
            q3 = M @ Vector(((R + 0.12) * math.cos(a), (R + 0.12) * math.sin(a), z - 1.5))
            box(pc, q3, (1.2, 0.45, 0.35), rot=Rz, bev=0.06)
    # stemma scolpito: medaglione con il simbolo d'oro (verso fuori, sotto lo stendardo)
    cyl(pc, M @ Vector((0, -R + 0.4, 14.5)), M @ Vector((0, -R - 0.55, 14.5)), 3.0, n=24, bev=0.2)
    torus(pg, M @ Vector((0, -R - 0.58, 14.5)), 2.7, 0.16, normal=M.to_3x3() @ Vector((0, -1, 0)), nR=32, nr=6)
    Ms = M @ plane_M((0, -R - 0.55, 14.5), (1, 0, 0), (0, 0, 1))
    symbol_geo(pg, el, Ms, 1.9, 0.35)
    # stendardo: asta di ferro e drappo (pezzo a parte, il gioco lo fa ondeggiare)
    cyl(pf, M @ Vector((0, -R + 0.5, 31.0)), M @ Vector((0, -R - 3.2, 31.0)), 0.18, n=8)
    cyl(pf, M @ Vector((-2.6, -R - 2.6, 31.0)), M @ Vector((2.6, -R - 2.6, 31.0)), 0.13, n=8)
    for sx in (-1, 1):
        sphere(pg, M @ Vector((sx * 2.75, -R - 2.6, 31.0)), 0.25, seg=8, rings=5)
        cyl(pf, M @ Vector((0, -R + 0.2, 29.0)), M @ Vector((sx * 2.0, -R - 2.6, 31.0)), 0.06, n=5)
    sphere(pg, M @ Vector((0, -R - 3.3, 31.0)), 0.3, seg=8, rings=5)
    stendardo(j, M @ Matrix.Translation((0, -R - 2.6, 30.85)))
    # collisione: ottagono di due scatole e la cima
    for a in (0.0, math.pi / 4):
        m.col("Torre%s_%d" % (el, int(a * 4 / math.pi)), c + Vector((0, 0, 15.3)), (2 * R, 2 * R, 42.6), Matrix.Rotation(a + phi, 3, "Z"))


def stendardo(j, M, w=4.0, h=12.0):
    """drappo con la coda a rondine, pieghe leggere; UV nella colonna j dell'atlante Stendardi"""
    el = L.ELEMENTI[j]
    p = m.part("Arena_Stendardo_" + el, "Stendardi")
    cols, rows = 6, 18
    th = 0.04
    verts, uvs = [], []

    def pos(s, t):
        x = (s - 0.5) * w
        # coda a rondine: il bordo in basso risale al centro
        notch = 1.6 * (1 - abs(s - 0.5) * 2)
        z = -t * (h - notch)
        y = 0.18 * math.sin(s * math.pi * 2.0 + t * 1.3) * (0.3 + t) + 0.25 * t * t
        return Vector((x, y, z))

    for side in (0, 1):
        grid = []
        for i in range(rows + 1):
            t = i / rows
            row = []
            for jx in range(cols + 1):
                s = jx / cols
                q = pos(s, t) + Vector((0, (-th if side == 0 else th), 0))
                u = (j + 0.03 + 0.94 * s) / 8.0
                v = 1.0 - t * (1 - (1.6 * (1 - abs(s - 0.5) * 2)) / h) * 0.985 - 0.005
                row.append((M @ q, (u, v)))
            grid.append(row)
        for i in range(rows):
            for jx in range(cols):
                a, b, c2, d = grid[i][jx], grid[i][jx + 1], grid[i + 1][jx + 1], grid[i + 1][jx]
                fc = [a, b, c2, d] if side == 0 else [d, c2, b, a]
                base = len(p.v)
                p.v.extend([tuple(q[0]) for q in fc])
                p.f.append(([base, base + 1, base + 2, base + 3], True, [q[1] for q in fc]))


# ---------------------------------------------------------------------------------------------
# i due draghi scheletrici avvolti sulle mura (generatori anatomici della skill
# roblox-reference-modeling): crani a fauci aperte sui piloni del portale, spina dorsale sopra le
# mura con le costole drappeggiate dentro e fuori, zampe che artigliano i merli, ali alzate,
# code intrecciate in una guglia dietro il palco. Qui il drago di sinistra (x < 0); quello di
# destra e' lo specchio (x -> -x).

SKILL_ASSETS = os.path.join(L.SKILL_SCRIPTS, "..", "assets")
JAW_TIP = {}
HEAD_SCALE = 22.0
WING_SCALE = 13.0
Z_SPINE = 36.0
R_SPINE = 88.0


def P(th, r=R_SPINE, z=Z_SPINE):
    a = math.radians(th)
    return [round(r * math.cos(a), 3), round(r * math.sin(a), 3), z]


def draghi():
    import json
    ex = json.load(open(os.path.join(SKILL_ASSETS, "dragon_anatomy.example.json"), encoding="utf-8"))
    exl = ex["landmarks"]
    exc = ex["components"]
    pb = {}

    def part(nm, mat, mirror):
        side = "Dx" if mirror else "Sx"
        return m.part("Arena_Drago%s_%s" % (side, nm), mat)

    # --- testa (coordinate dell'esempio, poi scala e posizione) -------------------------------
    hb = Vector(exl["head_base"])
    hinge = (Vector(exl["jaw_hinge_L"]) + Vector((-exl["jaw_hinge_L"][0], exl["jaw_hinge_L"][1], exl["jaw_hinge_L"][2]))) / 2
    Rj = Matrix.Rotation(math.radians(30), 3, "X")       # fauci spalancate
    hl = {k: list(v) for k, v in exl.items()}
    for k in ("jaw_hinge_L", "jaw_mid_L", "jaw_tip"):
        hl["u" + k] = list(exl[k])
        hl[k] = list(hinge + Rj @ (Vector(exl[k]) - hinge))
    hc = {k: dict(exc[k]) for k in ("skull", "horn", "jaw", "teeth_lower", "teeth_upper")}
    hc["teeth_upper"]["points"] = [{"lm": "ujaw_hinge_L", "offset": [0, -0.05, 0.06]}, {"lm": "ujaw_mid_L", "offset": [0.01, 0, 0.07]},
                                   {"lm": "ujaw_tip", "offset": [0, -0.03, 0.07]}, {"lm": "ujaw_mid_R", "offset": [-0.01, 0, 0.07]},
                                   {"lm": "ujaw_hinge_R", "offset": [0, -0.05, 0.06]}]
    hc["skull"]["sections"] = [[0, 0.17, 0.15, 0.0], [0.2, 0.21, 0.17, 0.02], [0.42, 0.15, 0.12, 0.0], [0.7, 0.095, 0.07, -0.02],
                               [0.9, 0.075, 0.06, -0.02], [1, 0.04, 0.045, -0.03]]
    hc["skull"]["stations"] = 18
    hc["horn"] = dict(hc["horn"], length=0.75, radius=0.055, curve_deg=45)
    hc["crest"] = {"type": "spike_row", "role": "horn", "bone": "head", "name": "Crest",
                   "points": [{"lm": "head_base", "offset": [0, 0.04, 0.15]}, {"lm": "skull_mid", "offset": [0, 0, 0.16]}, {"lm": "skull_tip", "offset": [0, 0.12, 0.1]}],
                   "count": 7, "t_range": [0.0, 0.7], "length": [0.16, 0.1, 0.05], "radius": [0.03], "direction": [0, 0.7, 1], "curve_deg": 25, "segments": 6}
    hc["horn2"] = dict(exc["horn"], base={"lm": "horn_base_{S}", "offset": [0.06, 0.08, -0.12]}, direction=[0.7, 0.5, 0.15], length=0.28, radius=0.028, name="Horn2")
    hc["horn3"] = dict(exc["horn"], base={"lm": "jaw_hinge_{S}", "offset": [0.05, 0.03, 0.02]}, direction=[0.5, 0.75, -0.25], length=0.2, radius=0.022, name="Horn3", curve_deg=20)
    head_base_w = Vector((-18.0, -101.2, 37.6))
    Mh = (Matrix.Translation(head_base_w) @ Matrix.Rotation(math.radians(-15), 4, "Z") @ Matrix.Rotation(math.radians(6), 4, "X")
          @ Matrix.Diagonal((HEAD_SCALE, HEAD_SCALE, HEAD_SCALE, 1)) @ Matrix.Translation(-hb))
    hcfg = {"landmarks": hl, "joints": {"head": ex["joints"]["head"] | {"parent": None}, "jaw": ex["joints"]["jaw"] | {"parent": "head"}}, "components": hc}
    jt = Mh @ Vector(hl["jaw_tip"])
    JAW_TIP[-1] = jt + Vector((0, 0, -0.6))
    JAW_TIP[1] = Vector((-jt.x, jt.y, jt.z - 0.6))

    # --- corpo in coordinate dell'arena -----------------------------------------------------
    lm = {}
    neck_pts = [P(-108), [-24.5, -93.0, 40.5], [-20.0, -98.5, 39.0], list(head_base_w)]
    lm.update({"n0": neck_pts[0], "n1": neck_pts[1], "n2": neck_pts[2], "n3": neck_pts[3]})
    sp = [P(-172, z=Z_SPINE - 0.5), P(-155, z=Z_SPINE + 1.0), P(-135, z=Z_SPINE + 1.5), P(-118, z=Z_SPINE + 0.8), P(-108)]
    for i, q in enumerate(sp):
        lm["s%d" % i] = q
    tail = [P(-172, z=Z_SPINE - 0.5), P(-195, z=Z_SPINE - 1.0), P(-220, z=Z_SPINE - 1.5), P(-243, 87.0, Z_SPINE - 1.0),
            [-14.0, 92.5, 40.0], [-4.0, 97.5, 49.0], [4.0, 96.5, 58.0], [1.0, 93.0, 66.0], [-2.0, 95.5, 72.0]]
    for i, q in enumerate(tail):
        lm["t%d" % i] = q
    # ali: il disegno dell'esempio girato sul fianco del drago e alzato
    th_w = -121.0
    a = math.radians(th_w)
    o = Vector((math.cos(a), math.sin(a), 0))                       # verso fuori
    f = Vector((-math.sin(a), math.cos(a), 0))                      # verso la testa
    z = Vector((0, 0, 1))
    r0 = Vector(exl["wing_root_L"])
    for side, out, tilt in (("L", o, 52.0), ("R", -o, 84.0)):
        lat = (out * math.cos(math.radians(tilt)) + z * math.sin(math.radians(tilt))).normalized()
        up2 = lat.cross(f).normalized()
        if up2.z < 0:
            up2 = -up2
        root = Vector(P(th_w, R_SPINE + (2.4 if side == "L" else -2.4), Z_SPINE + 1.5))
        for k in ("wing_root", "wing_elbow", "wing_wrist", "d1_tip", "d2_1", "d2_2", "d2_tip", "d3_1", "d3_tip", "d4_1", "d4_tip", "d5_1", "d5_tip"):
            q = Vector(exl[k + "_L"]) - r0
            w = root + WING_SCALE * (q.x * lat + (-q.y) * f + q.z * up2)
            lm["%s_%s" % (k, side)] = list(w)
        rr = R_SPINE + (2.2 if side == "L" else -2.2)
        lm["flank_" + side] = P(-133, rr, Z_SPINE + 0.5)
        lm["hip_attach_" + side] = P(-150, rr, Z_SPINE)
    # zampe: L artiglia i merli fuori, R il camminamento dentro
    for (th, pre) in ((-124.0, "f"), (-163.0, "h")):
        lm[pre + "sh_L"] = P(th, 90.0, 33.5)
        lm[pre + "el_L"] = P(th - 3, 97.5, 35.0)
        lm[pre + "wr_L"] = P(th + 1, 96.2, 28.6)
        lm[pre + "ba_L"] = P(th + 1, 94.6, 27.7)
        lm[pre + "to_L"] = P(th + 1, 91.8, 27.7)
        lm[pre + "sh_R"] = P(th, 86.0, 33.5)
        lm[pre + "el_R"] = P(th - 3, 80.0, 33.0)
        lm[pre + "wr_R"] = P(th + 1, 84.6, 24.2)
        lm[pre + "ba_R"] = P(th + 1, 86.4, 22.4)
        lm[pre + "to_R"] = P(th + 1, 89.4, 22.2)
    joints = {
        "spine": {"type": "axial", "points": ["s0", "s1", "s2", "s3", "s4"], "bones": 6},
        "neck": {"type": "axial", "points": ["n0", "n1", "n2", "n3"], "bones": 5, "parent": "spine:last"},
        "tail": {"type": "axial", "points": ["t%d" % i for i in range(len(tail))], "bones": 12},
    }
    comps = {
        "vert_neck": {"type": "vertebra_chain", "name": "VertNeck", "bone_chain": "neck", "points": ["n0", "n1", "n2", "n3"], "count": 7,
                      "centrum_radius": [1.7, 1.25], "length_ratio": 0.78, "neural_spine_height": [2.2, 1.2], "neural_spine_tilt_deg": 20,
                      "transverse_length": [1.6, 1.0], "segments": 10},
        "vert_spine": {"type": "vertebra_chain", "name": "VertDorsal", "bone_chain": "spine", "points": ["s0", "s1", "s2", "s3", "s4"], "count": 15,
                       "centrum_radius": [2.0, 2.3, 2.0], "length_ratio": 0.78, "neural_spine_height": [4.0, 5.5, 3.5],
                       "neural_spine_tilt_deg": 25, "transverse_length": [2.2, 2.6, 2.0], "segments": 10},
        "vert_tail": {"type": "vertebra_chain", "name": "VertTail", "bone_chain": "tail", "points": ["t%d" % i for i in range(len(tail))], "count": 44,
                      "centrum_radius": [2.0, 0.55], "length_ratio": 0.8, "neural_spine_height": [3.0, 0.0], "neural_spine_tilt_deg": -25,
                      "transverse_length": [0.9, 0.0], "segments": 8},
        "ribs": {"type": "rib_set", "name": "Rib", "vertebrae": "vert_spine", "range": [1, 13], "symmetry": False,
                 "spread": [6.0, 8.5, 6.5], "drop": [12.0, 15.0, 12.0], "sweep": [2.0, 2.6, 2.0], "radius": [0.85, 0.32], "flatten": 0.6,
                 "stations": 10, "segments": 7},
        "fore_leg": {"type": "limb_chain", "side": "LR", "symmetry": False, "role": "limb_bone", "points": ["fsh_{S}", "fel_{S}", "fwr_{S}", "fba_{S}"],
                     "names": ["Humerus", "Ulna", "Metacarpal"], "bones": ["a", "b", "c"], "radius": [1.15, 0.85, 0.6], "gap": 0.5, "stations": 7, "segments": 9},
        "hind_leg": {"type": "limb_chain", "side": "LR", "symmetry": False, "role": "limb_bone", "points": ["hsh_{S}", "hel_{S}", "hwr_{S}", "hba_{S}"],
                     "names": ["Femur", "Tibia", "Metatarsus"], "bones": ["a", "b", "c"], "radius": [1.3, 0.95, 0.65], "gap": 0.5, "stations": 7, "segments": 9},
        "fore_toes": {"type": "digit_set", "side": "LR", "symmetry": False, "name": "ForeToe", "base": "fba_{S}", "toward": "fto_{S}", "digits": 4,
                      "spread_deg": 70, "phalanx_length": 1.8, "phalanx_radius": 0.32, "claw_length": 1.6, "claw_radius": 0.3, "claw_curve_deg": 75, "bone": "c", "segments": 8},
        "hind_toes": {"type": "digit_set", "side": "LR", "symmetry": False, "name": "HindToe", "base": "hba_{S}", "toward": "hto_{S}", "digits": 4,
                      "spread_deg": 70, "phalanx_length": 2.0, "phalanx_radius": 0.35, "claw_length": 1.8, "claw_radius": 0.33, "claw_curve_deg": 75, "bone": "c", "segments": 8},
    }
    for k in ("wing_arm_bones", "wing_d2_bones", "wing_d3_bones", "wing_d4_bones", "wing_d5_bones", "wing_thumb_claw", "wing_membrane"):
        c = json.loads(json.dumps(exc[k]))
        c["symmetry"] = False
        if "radius" in c:
            c["radius"] = [r * WING_SCALE for r in c["radius"]] if isinstance(c["radius"], list) else c["radius"] * WING_SCALE
        for key in ("gap", "length", "thickness"):
            if key in c:
                c[key] = c[key] * WING_SCALE
        if k == "wing_thumb_claw":
            c["base"] = "wing_wrist_{S}"
        if k == "wing_membrane":
            c["thickness"] = 0.25
            c["sag"] = 0.18
        comps[k] = c
    cfg = {"landmarks": lm, "joints": joints, "components": comps}

    # costole: niente costole dove passano le torri
    if L.SKILL_SCRIPTS not in sys.path:
        sys.path.insert(0, L.SKILL_SCRIPTS)
    import anatomy_lib as al
    lay, _ = al.vertebra_layout(comps["vert_spine"], al.Landmarks(lm))
    torri = [-90 + 22.5 + 45 * j for j in range(8)]
    skip = set()
    for i, (c, _fr) in enumerate(lay):
        th = math.degrees(math.atan2(c.y, c.x))
        if any(abs(((th - t) + 180) % 360 - 180) < 7.5 for t in torri):
            skip.add(i + 1)

    for mirror in (False, True):
        bone_h = part("Cranio", "OssoDrago", mirror)
        bone_n = part("Collo", "OssoDrago", mirror)
        bone_s = part("Schiena", "OssoDrago", mirror)
        bone_t = part("Coda", "OssoDrago", mirror)
        bone_r = part("Costole", "OssoDrago", mirror)
        bone_l = part("Zampe", "OssoDrago", mirror)
        bone_w = part("AliOssa", "OssoDrago", mirror)
        mem = part("AliMembrana", "MembranaDrago", mirror)
        L.anatomia(hcfg, Mh, lambda k, r, n: bone_h, mirror=mirror)

        def pick(k, r, n):
            if k == "ribs":
                idx = int(n.split("_")[2])
                return None if idx in skip else bone_r
            return {"vert_neck": bone_n, "vert_spine": bone_s, "vert_tail": bone_t, "fore_leg": bone_l, "hind_leg": bone_l,
                    "fore_toes": bone_l, "hind_toes": bone_l, "wing_membrane": mem}.get(k, bone_w)
        L.anatomia(cfg, Matrix.Identity(4), pick, mirror=mirror)
    # occhi di brace nelle orbite e marcatori
    for sx in (-1, 1):
        for ex_ in (-1, 1):
            q = Mh @ Vector((0.085 * ex_, -2.6, 2.74))
            if sx > 0:
                q = Vector((-q.x, q.y, q.z))
            sphere(m.part("Arena_Draghi_Occhi", "MAT_Ember"), q, 0.9, seg=10, rings=6)
        tipq = Vector(lm["t8"])
        m.marker("FX_Light_Occhi%s" % ("Dx" if sx > 0 else "Sx"), Vector((sx * abs((Mh @ Vector((0, -2.6, 2.74))).x), (Mh @ Vector((0, -2.6, 2.74))).y, (Mh @ Vector((0, -2.6, 2.74))).z)))
    m.marker("SPOT_GugliaCode", Vector((0.0, 95.0, 72.0)))
    # collisioni dei crani (sopra i piloni)
    for sx in (-1, 1):
        c = Mh @ Vector((0, -2.7, 2.62))
        m.col("Cranio%s" % ("Dx" if sx > 0 else "Sx"), Vector((sx * abs(c.x), c.y, c.z)), (7.5, 13.0, 7.0), Matrix.Rotation(math.radians(15 * (1 if sx > 0 else -1)), 3, "Z"))


# ---------------------------------------------------------------------------------------------
# portale d'ingresso (lato 0, -Y): arco largo 20 e alto 30, teste di drago, catene, saracinesca

def portale():
    ps = m.part("Arena_Portale", "PietraScura")
    pc = m.part("Arena_Portale_Cornici", "PietraCornice")
    pf = m.part("Arena_Portale_Ferro", "FerroBattuto")
    pk = m.part("Arena_Portale_Catene", "FerroBattuto")
    pg = m.part("Arena_Portale_Oro", "OroAntico")
    pe = m.part("Arena_Portale_Braci", "MAT_Ember")
    Y0, Y1 = -101.0, -72.0       # facciata esterna e interna
    YM = -86.0                   # fin qui il corpo alto; dentro le gradinate e' piu' stretto e basso
    for (xa, ya, yb, zt) in ((GATE, Y0, YM, 36.0), (GATE_IN, YM - 0.01, Y1, 33.0)):
        blk = L.Part("tmp_gate", "PietraScura")
        boxz(blk, -xa, xa, ya, yb, -6.0, zt)
        cut = L.Part("tmp_gcut", "PietraScura")
        L.arch_cutter(cut, 0.0, 20.0, -0.5, 20.0, Y0 - 1, Y1 + 1, segs=24)
        L.boolean(blk, cut)
        base = len(ps.v)
        ps.v.extend(blk.v)
        ps.f.extend([([base + i for i in f[0]], False, None) for f in blk.f])
    # piloni ai lati (le teste escono da qui)
    for sx in (-1, 1):
        boxz(ps, sx * 14.5 if sx > 0 else -21.5, 21.5 if sx > 0 else -14.5, Y0 - 3.5, Y0 + 0.2, -6.0, 38.0, bev=0.3)
        for z0 in (0.0, 12.0, 24.0):
            boxz(pc, sx * 14.2 if sx > 0 else -21.8, 21.8 if sx > 0 else -14.2, Y0 - 3.8, Y0 - 3.3, z0 - 0.4, z0 + 0.4, bev=0.12)
        boxz(pc, sx * 14.0 if sx > 0 else -22.0, 22.0 if sx > 0 else -14.0, Y0 - 4.0, Y0 + 0.4, 37.6, 38.6, bev=0.15)
        boxz(pc, sx * 14.2 if sx > 0 else -21.8, 21.8 if sx > 0 else -14.2, Y0 - 3.8, Y0 + 0.2, -6.0, 1.2, bev=0.15)
        # catena dalla mascella del cranio (draghi()) a un anello nel blocco a terra
        jaw = JAW_TIP[sx]
        ring_at = Vector((sx * 19.5, Y0 - 13.0, 1.6))
        boxz(pc, ring_at.x - 1.0, ring_at.x + 1.0, ring_at.y - 1.0, ring_at.y + 1.0, -0.5, 1.4, bev=0.15)
        torus(pf, ring_at + Vector((0, 0, 0.1)), 0.55, 0.11, normal=(1, 0, 0), nR=14, nr=5)
        chain(pk, jaw, ring_at + Vector((0, 0, 0.5)), sag=2.5, link=0.95, thick=0.14)
        m.col("PortaleBlocco%s" % ("Dx" if sx > 0 else "Sx"), ring_at + Vector((0, 0, 0.45)), (2, 2, 1.9))
    # arco: ghiera a conci con bordo d'oro, chiave con lo stemma
    for y0, y1 in ((Y0 - 0.6, Y0 + 0.05), (Y1 - 0.05, Y1 + 0.6)):
        L.arch_ring(pc, 0.0, 20.0, 20.0, y0, y1, band=1.7, segs=24)
        L.arch_ring(pg, 0.0, 23.4, 20.0, y0 - 0.1 if y0 < -90 else y0, y1 if y0 < -90 else y1 + 0.1, band=0.22, segs=28)
        for sx in (-1, 1):
            boxz(pc, sx * 10.0 if sx > 0 else -11.7, 11.7 if sx > 0 else -10.0, y0, y1, -0.2, 20.0)
            boxz(pc, sx * 9.8 if sx > 0 else -12.0, 12.0 if sx > 0 else -9.8, y0 - 0.2, y1 + 0.2, 19.2, 20.2, bev=0.1)  # imposta
    for y, d in ((Y0 - 1.2, -1), (Y1 + 1.2, 1)):
        box(pc, (0, y + 0.5 * -d, 31.0), (3.0, 1.2, 3.4), bev=0.2)
        cyl(pg, (0, y, 31.0), (0, y - 0.25 * d, 31.0), 1.2, n=20, bev=0.08)
        symbol_geo(pg, "Stella", plane_M((0, y - 0.25 * d, 31.0), (d * -1, 0, 0) if d > 0 else (1, 0, 0), (0, 0, 1)), 0.95, 0.2)
    # cornicione, attico con targa d'oro, merli
    boxz(pc, -GATE - 0.3, GATE + 0.3, Y0 - 0.9, Y0, 33.0, 34.2, bev=0.15)
    boxz(pc, -GATE - 0.5, GATE + 0.5, Y0 - 0.3, YM + 0.3, 35.8, 36.3, bev=0.08)
    boxz(pc, -GATE_IN - 0.4, GATE_IN + 0.4, Y1, Y1 + 0.9, 30.8, 31.8, bev=0.12)
    boxz(pc, -GATE_IN - 0.5, GATE_IN + 0.5, YM, Y1 + 0.3, 32.8, 33.3, bev=0.08)
    boxz(pg, -8.0, 8.0, Y0 - 0.45, Y0 - 0.1, 34.4, 35.6, bev=0.05)
    for i in range(12):   # rune sulla targa (incise nel bordo, braci)
        strokes_geo(pe, rune_strokes(rng), 0.12, plane_M((-7.0 + i * 1.27, Y0 - 0.46, 35.0), (1, 0, 0), (0, 0, -1)) @ Matrix.Diagonal((0.8, 0.8, 1, 1)), 0.05)
    for y, z, lim in ((Y0 + 0.6, 37.5, 18.9), (YM + 0.6, 37.5, 18.9), (Y1 - 0.6, 34.5, 12.4)):
        x = -lim
        while x <= lim + 0.01:
            box(ps, (x, y, z), (1.6, 1.2, 2.4), bev=0.12)
            x += lim * 2 / round(lim * 2 / 2.7)
    for sx in (-1, 1):
        x = sx * (GATE - 0.6)
        for y in [YM + 0.6 - i * 2.6 for i in range(1, 5)]:
            box(ps, (x, y, 37.5), (1.2, 1.6, 2.4), bev=0.12)
        for y in [YM + 1.5 + i * 2.65 for i in range(5)]:
            box(ps, (sx * (GATE_IN - 0.6), y, 34.5), (1.2, 1.6, 2.4), bev=0.12)
    # saracinesca alzata (si vede il bordo dentati sotto l'arco)
    ys = Y0 + 2.0
    for i in range(13):
        x = -9.0 + i * 1.5
        top = 20.0 + math.sqrt(max(100.0 - x * x, 0.0))
        if top - 26.0 < 0.3:
            continue
        box(pf, (x, ys, (26.0 + top) / 2), (0.32, 0.32, top - 26.0))
        cyl(pf, (x, ys, 26.05), (x, ys, 25.0), 0.22, 0.0, n=6)
    for z in (26.6, 28.2, 29.6):
        hw = math.sqrt(max(100.0 - (z - 20.0) ** 2, 0.0)) - 0.1
        box(pf, (0, ys, z), (2 * hw, 0.25, 0.28))
    for sx in (-1, 1):
        chain(pk, Vector((sx * 6.0, ys - 0.3, 27.0)), Vector((sx * 7.5, Y0 - 0.7, 33.0)), sag=0.3, link=0.7, thick=0.11)
        # bracieri a terra ai lati dell'ingresso
        q = Vector((sx * 12.6, Y0 - 5.5, 0.0))
        lathe(pc, [(1.3, 0.0), (1.3, 0.5), (0.9, 0.8), (0.65, 1.2), (0.6, 2.9), (0.9, 3.2), (1.1, 3.4)], 14, q)
        lathe(pf, [(0.8, 3.3), (1.5, 3.55), (1.8, 4.1), (1.85, 4.5), (1.6, 4.5), (1.35, 4.0), (0.3, 3.7)], 16, q, close=False)
        lathe(pe, [(1.5, 4.1), (0.8, 4.3), (0.01, 4.4)], 12, q, close=False)
        m.marker("FX_Fire_Ingresso%s" % ("Dx" if sx > 0 else "Sx"), q + Vector((0, 0, 4.6)))
        m.marker("FX_Light_Ingresso%s" % ("Dx" if sx > 0 else "Sx"), q + Vector((0, 0, 5.4)))
        m.col("Braciere%s" % ("Dx" if sx > 0 else "Sx"), q + Vector((0, 0, 2.2)), (2.2, 2.2, 4.4))
    # posatoio 1 sopra il portale
    posatoio("1", Matrix.Translation((0, -93.0, 0)), 36.3, pc, pf, pg)
    # collisioni: aperto in mezzo (20 x 30)
    for nm_, xa, ya, yb, zt in (("Fuori", GATE, Y0, YM, 36.0), ("Dentro", GATE_IN, YM, Y1, 33.0)):
        for sx in (-1, 1):
            m.col("Portale%s%s" % (nm_, "Dx" if sx > 0 else "Sx"), (sx * (xa + 10.0) / 2, (ya + yb) / 2, (zt - 6.0) / 2), (xa - 10.0, yb - ya, zt + 6.0))
        m.col("Portale%sSopra" % nm_, (0.0, (ya + yb) / 2, (30.0 + zt) / 2), (20.0, yb - ya, zt - 30.0))
    for sx in (-1, 1):
        m.col("Pilone%s" % ("Dx" if sx > 0 else "Sx"), (sx * 18.0, Y0 - 1.65, 16.0), (7.0, 3.7, 44.0))


# ---------------------------------------------------------------------------------------------
# palco d'onore (lato 4, +Y): loggia coperta con trono e due statue di drago

def palco():
    M = side_M(4)
    R3 = M.to_3x3()
    ps = m.part("Arena_Palco", "PietraScura")
    pc = m.part("Arena_Palco_Cornici", "PietraCornice")
    pr = m.part("Arena_Palco_Tetto", "Tegole")
    pg = m.part("Arena_Palco_Oro", "OroAntico")
    pb = m.part("Arena_Palco_Trono", "Basalto")
    pt = m.part("Arena_Palco_Drappi", "TelaRossa")
    pf = m.part("Arena_Palco_Ferro", "FerroBattuto")
    pe = m.part("Arena_Palco_Braci", "MAT_Ember")
    pst = m.part("Arena_Palco_Statue", "StatuaEclissi")
    psd = m.part("Arena_Palco_StatueDett", "StatuaEclissi")
    W = LOGGIA
    YF, YB = -72.0, -R_BACK
    F = 9.5   # piano della loggia

    def B(x0, x1, y0, y1, z0, z1, p, bev=0.0):
        c = M @ Vector(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
        box(p, c, (x1 - x0, y1 - y0, z1 - z0), rot=R3, bev=bev)

    B(-W, W, YB, YF, -6.0, 9.0, ps)
    B(-W - 0.4, W + 0.4, YB, YF + 0.4, 9.0, F, pc, 0.1)
    B(-W - 0.3, W + 0.3, YF - 0.3, YF + 0.35, -0.3, 0.8, pc, 0.1)
    for x0 in (-W + 0.6, -4.0, 4.0):    # pannelli in rilievo sul fronte
        x1 = x0 + (W - 4.6 if x0 < -4.5 else 8.0) if x0 != 4.0 else W - 0.6
        B(x0, x1, YF, YF + 0.3, 1.6, 7.8, pc, 0.08)
        B(x0 + 0.5, x1 - 0.5, YF + 0.2, YF + 0.35, 2.1, 7.3, ps)
    torus(pg, M @ Vector((0, YF + 0.42, 4.7)), 2.0, 0.14, normal=R3 @ Vector((0, 1, 0)), nR=28, nr=6)
    symbol_geo(pg, "Stella", M @ plane_M((0, YF + 0.36, 4.7), (-1, 0, 0), (0, 0, 1)), 1.6, 0.25)
    # balaustra
    n = 30
    for i in range(n + 1):
        x = -W + 0.3 + (2 * W - 0.6) * i / n
        if abs(x) < 1.6:
            continue
        lathe(pc, [(0.2, F), (0.22, F + 0.15), (0.12, F + 0.35), (0.24, F + 0.65), (0.1, F + 0.95), (0.16, F + 1.05)], 8, (0, 0, 0), M=M @ Matrix.Translation((x, YF + 0.6, 0)))
    for sx in (-1, 1):
        B(sx * 1.6 if sx > 0 else -W, W if sx > 0 else -1.6, YF + 0.35, YF + 0.85, F + 1.05, F + 1.35, pc, 0.06)
    # colonne (davanti e ai lati) con base e capitello
    cols_ = [(x, YF + 1.2) for x in (-W + 1.0, -4.3, 4.3, W - 1.0)] + [(sx * (W - 1.0), y) for sx in (-1, 1) for y in (-80.5, -87.0)]
    for (x, y) in cols_:
        Mc = M @ Matrix.Translation((x, y, 0))
        B(x - 1.0, x + 1.0, y - 1.0, y + 1.0, F, F + 0.5, pc, 0.08)
        lathe(pc, [(0.85, F + 0.5), (0.85, F + 0.7), (0.72, F + 0.9), (0.66, F + 1.1), (0.58, 16.6), (0.66, 16.8), (0.95, 17.2), (1.05, 17.5)], 14, M=Mc)
    # architrave, soffitto, tetto a capanna (colmo verso l'arena), frontone
    B(-W - 0.6, W + 0.6, YB, YF + 0.2, 17.5, 19.0, pc, 0.12)
    B(-W - 0.3, W + 0.3, YB - 0.2, YF - 0.6, 19.0, 19.3, ps)
    Mr = M @ Matrix.Translation((0, 0, 0)) @ Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    ridge = 24.5
    for sx in (-1, 1):
        x0, x1 = sx * 0.0, sx * (W + 1.6)
        pts = [(x0, ridge), (x1, 18.9), (x1, 18.5), (x0, ridge - 0.45)]
        if sx < 0:
            pts = pts[::-1]
        prism(pr, pts, -(YF + 1.4), -(YB - 0.4), Mr)
    cyl(pc, M @ Vector((0, YF + 1.6, ridge)), M @ Vector((0, YB - 0.6, ridge)), 0.4, n=10)
    Mf = M @ Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    prism(pc, [(-W - 0.6, 19.0), (0, ridge - 0.2), (W + 0.6, 19.0)][::-1], -(YF + 1.0), -(YF + 0.2), Mf)
    torus(pg, M @ Vector((0, YF + 0.1, 21.2)), 1.25, 0.12, normal=R3 @ Vector((0, 1, 0)), nR=24, nr=5)
    symbol_geo(pg, "Eclissi", M @ plane_M((0, YF + 0.15, 21.2), (-1, 0, 0), (0, 0, 1)), 1.0, 0.2)
    for x, z in ((0, ridge + 0.2), (-W - 1.4, 19.1), (W + 1.4, 19.1)):
        q = M @ Vector((x, YF + 1.5, z))
        cyl(pg, q, q + Vector((0, 0, 1.6)), 0.45, 0.0, n=10)
    # muro di fondo, drappo e trono su tre gradini
    B(-W, W, YB - 0.3, YB + 0.5, F, 17.5, ps)
    B(-3.6, 3.6, YB + 0.5, YB + 0.7, 11.0, 17.0, pt)
    for i, (hw, d) in enumerate(((3.6, 4.6), (3.0, 3.8), (2.4, 3.0))):
        B(-hw, hw, YB + 0.5, YB + 0.5 + d, F + i * 0.35, F + (i + 1) * 0.35, pb, 0.05)
    s0 = F + 1.05
    B(-1.7, 1.7, YB + 1.3, YB + 3.2, s0, s0 + 1.2, pb, 0.1)                              # seduta
    B(-1.5, 1.5, YB + 1.35, YB + 3.1, s0 + 1.2, s0 + 1.45, pt, 0.12)                     # cuscino
    B(-1.6, 1.6, YB + 0.8, YB + 1.4, s0, s0 + 5.0, pb, 0.12)                             # schienale
    for sx in (-1, 1):
        B(sx * 1.55 if sx > 0 else -2.15, 2.15 if sx > 0 else -1.55, YB + 1.3, YB + 3.4, s0 + 1.2, s0 + 2.0, pb, 0.08)
        sphere(pg, M @ Vector((sx * 1.85, YB + 3.5, s0 + 2.1)), 0.38, seg=10, rings=6)
        # ali d'oro sopra lo schienale
        wing = [(0, 0), (1.4, 0.6), (2.6, 2.0), (3.0, 3.4), (2.2, 2.6), (1.9, 3.1), (1.2, 2.0), (0.9, 2.4), (0.3, 1.0)]
        pts = [(sx * x, z) for x, z in wing]
        if sx < 0:
            pts = pts[::-1]
        prism(pg, pts, -(YB + 1.15), -(YB + 0.95), M @ Matrix.Translation((sx * 0.3, 0, s0 + 4.0)) @ Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1))))
    sphere(pg, M @ Vector((0, YB + 1.1, s0 + 5.25)), 0.45, seg=10, rings=6)
    # bracieri sul davanti
    for sx in (-1, 1):
        q = M @ Vector((sx * 7.0, YF + 1.4, F))
        for i in range(3):
            a = 2 * math.pi * i / 3
            cyl(pf, q + R3 @ Vector((0.55 * math.cos(a), 0.55 * math.sin(a), 0)), q + Vector((0, 0, 1.3)), 0.07, n=5)
        lathe(pf, [(0.3, 1.2), (0.75, 1.35), (0.95, 1.7), (0.85, 1.7), (0.6, 1.45), (0.1, 1.4)], 12, q, close=False)
        lathe(pe, [(0.75, 1.55), (0.3, 1.68), (0.01, 1.72)], 10, q, close=False)
        m.marker("FX_Fire_Palco%s" % ("Dx" if sx < 0 else "Sx"), q + Vector((0, 0, 1.85)))
    m.marker("FX_Light_Palco", M @ Vector((0, -81.0, 16.0)))
    # statue di drago ai lati della loggia, su piedistalli, rivolte verso il centro dell'arena
    for sx in (-1, 1):
        x, y = sx * (W + 3.6), YF + 1.6
        q = M @ Vector((x, y, 0))
        B(x - 2.0, x + 2.0, y - 2.0, y + 2.0, -0.3, 8.6, ps, 0.15)
        B(x - 2.3, x + 2.3, y - 2.3, y + 2.3, 8.6, 9.3, pc, 0.12)
        B(x - 2.3, x + 2.3, y - 2.3, y + 2.3, -0.3, 0.7, pc, 0.12)
        Ms = Matrix.Translation(M @ Vector((x, y, 9.3))) @ (M @ Matrix.Rotation(math.pi + sx * 0.25, 4, "Z")).to_3x3().to_4x4() @ Matrix.Diagonal((1.05, 1.05, 1.05, 1))
        L.drago_seduto(pst, psd, Ms, "Eclissi", pg, pe, res=0.08, target=3500)
        m.col("PalcoStatua%s" % ("Dx" if sx < 0 else "Sx"), q + Vector((0, 0, 4.5)), (4.6, 4.6, 9.6), R3)
    # posatoio 5 sul colmo
    posatoio("5", M @ Matrix.Translation((0, (YF + YB) / 2, 0)), ridge - 0.2, pc, pf, pg, h=6.0)
    # collisioni
    def C(name, x0, x1, y0, y1, z0, z1):
        m.col(name, M @ Vector(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)), (x1 - x0, y1 - y0, z1 - z0), R3)
    C("PalcoBase", -W, W, YB, YF, -6.0, F)
    C("PalcoFondo", -W, W, YB - 0.3, YB + 0.5, F, 17.5)
    C("PalcoTetto", -W - 0.6, W + 0.6, YB, YF + 0.2, 17.5, 19.3)
    C("PalcoBalaustra", -W, W, YF, YF + 0.9, F, F + 1.35)
    C("PalcoTrono", -2.4, 2.4, YB + 0.5, YB + 3.5, F, s0 + 1.2)
    for sx in (-1, 1):
        # falde del tetto (rampe)
        p0 = M @ Vector((sx * (W + 1.6), (YF + YB) / 2, 18.9))
        p1 = M @ Vector((0, (YF + YB) / 2, ridge))
        mid = (p0 + p1) / 2
        L_ = (p1 - p0).length
        ang = math.atan2(ridge - 18.9, W + 1.6)
        C2 = Matrix.Rotation(-sx * ang, 3, "Y")
        m.col("PalcoFalda%s" % ("Dx" if sx < 0 else "Sx"), mid, (L_, (YF - YB) + 1.8, 0.5), R3 @ C2)
    # gradini e massa dietro dei lati vicini restano nelle mura: qui chiudo sopra la galleria
    oslab(ps, R_STEPS_END, R_BACK, 17.5, Z_DECK, -W, W, M)
    C("PalcoMuroAlto", -W, W, R_STEPS_END * -1 - 3.0, -R_STEPS_END, 17.5, Z_DECK)


# ---------------------------------------------------------------------------------------------
# pavimento: lastricato e sabbia, cerchio di rune di 70 m, 8 spicchi colorati

def pavimento():
    pa = m.part("Arena_Pavimento", "SabbiaArena")
    pc = m.part("Arena_Pavimento_Cerchi", "PietraCornice")
    pk = m.part("Arena_Pavimento_Spicchi", "Spicchi")
    pe = m.part("Arena_Pavimento_Rune", "MAT_Ember")
    Rv = R_IN / math.cos(math.radians(22.5))
    pts = [(Rv * math.cos(math.radians(-90 + 22.5 + 45 * k)), Rv * math.sin(math.radians(-90 + 22.5 + 45 * k))) for k in range(8)]
    prism(pa, pts, -1.0, 0.0)
    # spicchi: corona fra 36 e 62 m, un elemento per spicchio (colonna dell'atlante)
    r0, r1 = 36.4, 61.6
    seg = 10
    for j in range(8):
        a0 = math.radians(-90 + 45 * j + 1.2)
        a1 = math.radians(-90 + 45 * (j + 1) - 1.2)
        # lo spicchio j sta fra le torri j-1 e j: elemento della torre j (in senso antiorario)
        el_idx = j
        verts, faces, uvs = [], [], []
        for i in range(seg + 1):
            t = i / seg
            a = a0 + (a1 - a0) * t
            for r in (r0, r1):
                verts.append((r * math.cos(a), r * math.sin(a), 0.03))
        for i in range(seg):
            q = [i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2]
            faces.append(q)
            u0 = (el_idx + 0.05 + 0.9 * i / seg) / 8.0
            u1 = (el_idx + 0.05 + 0.9 * (i + 1) / seg) / 8.0
            uvs.append([(u0, 0.03), (u0, 0.97), (u1, 0.97), (u1, 0.03)])
        base = len(pk.v)
        pk.v.extend(verts)
        for f, u in zip(faces, uvs):
            pk.f.append(([base + x for x in f], False, u))
        # bordo dello spicchio (lati)
    lathe(pc, [(r0 - 0.9, 0.0), (r0 - 0.9, 0.06), (r0, 0.06), (r0, 0.0)], 96, close=False)
    lathe(pc, [(r1, 0.0), (r1, 0.06), (r1 + 0.9, 0.06), (r1 + 0.9, 0.0)], 96, close=False)
    for j in range(8):
        a = math.radians(-90 + 45 * j)
        d = Vector((math.cos(a), math.sin(a), 0))
        nrm = Vector((-d.y, d.x, 0))
        q0, q1 = d * (r0 - 0.9), d * (r1 + 0.9)
        prism(pc, [tuple((q0 - nrm * 0.45).to_2d()), tuple((q1 - nrm * 0.45).to_2d()), tuple((q1 + nrm * 0.45).to_2d()), tuple((q0 + nrm * 0.45).to_2d())], 0.0, 0.065)
    # cerchio di rune: diametro 70 (raggio 35)
    lathe(pc, [(33.9, 0.0), (33.9, 0.05), (35.0, 0.05), (35.0, 0.0)], 128, close=False)
    lathe(pc, [(30.6, 0.0), (30.6, 0.05), (31.2, 0.05), (31.2, 0.0)], 128, close=False)
    n = 84
    for i in range(n):
        a = 2 * math.pi * i / n
        d = Vector((math.cos(a), math.sin(a), 0))
        # piano orizzontale: X = tangente, Y = verso fuori, estrusione in su
        Mg = Matrix.Translation(d * 32.55) @ Matrix((Vector((-d.y, d.x, 0)), d, Vector((0, 0, 1)))).transposed().to_4x4() @ Matrix.Diagonal((1.3, 1.5, 1, 1))
        strokes_geo(pe, rune_strokes(rng), 0.13, Mg, 0.045)
    # rosone al centro: stella a 8 punte e raggi verso il cerchio
    lathe(pc, [(5.4, 0.0), (5.4, 0.05), (6.0, 0.05), (6.0, 0.0)], 48, close=False)
    symbol_geo(pc, "Stella", Matrix.Identity(4), 4.6, 0.05)
    for j in range(8):
        a = math.radians(-90 + 22.5 + 45 * j)
        d = Vector((math.cos(a), math.sin(a), 0))
        nrm = Vector((-d.y, d.x, 0))
        q0, q1 = d * 6.0, d * 30.6
        prism(pe, [tuple((q0 - nrm * 0.12).to_2d()), tuple((q1 - nrm * 0.05).to_2d()), tuple((q1 + nrm * 0.05).to_2d()), tuple((q0 + nrm * 0.12).to_2d())], 0.0, 0.04)
    m.marker("SPOT_Centro", (0, 0, 0))
    for a in (0.0, math.pi / 4):
        m.col("Pavimento_%d" % int(a * 4 / math.pi), (0, 0, -1.0), (2 * R_IN, 2 * R_IN, 2.0), Matrix.Rotation(a, 3, "Z"))


# ---------------------------------------------------------------------------------------------
# pedana del domatore (fuori, davanti al portale) e altare del Duello

def pedana():
    ps = m.part("Arena_Pedana", "PietraChiara")
    pc = m.part("Arena_Pedana_Cornici", "PietraCornice")
    pe = m.part("Arena_Pedana_Rune", "MAT_Ember")
    pg = m.part("Arena_Pedana_Oro", "OroAntico")
    c = PEDANA
    H = 0.35
    radii = (6.8, 5.9, 5.0)
    for i, r in enumerate(radii):
        lathe(ps, [(r, -1.5 if i == 0 else i * H - 0.1), (r, (i + 1) * H - 0.08), (r - 0.08, (i + 1) * H)], 48, c)
        lathe(pc, [(r + 0.02, (i + 1) * H - 0.14), (r + 0.1, (i + 1) * H - 0.1), (r + 0.1, (i + 1) * H - 0.02), (r - 0.06, (i + 1) * H + 0.02)], 48, c, close=False)
    top = 3 * H
    # cerchio di rune e stella d'oro sul piano
    lathe(pc, [(3.7, top), (3.7, top + 0.02), (4.6, top + 0.02), (4.6, top)], 48, c, close=False)
    for i in range(22):
        a = 2 * math.pi * i / 22
        d = Vector((math.cos(a), math.sin(a), 0))
        Mg = Matrix.Translation(c + d * 4.15 + Vector((0, 0, top))) @ Matrix((Vector((-d.y, d.x, 0)), d, Vector((0, 0, 1)))).transposed().to_4x4() @ Matrix.Diagonal((0.5, 0.6, 1, 1))
        strokes_geo(pe, rune_strokes(rng), 0.09, Mg, 0.035)
    symbol_geo(pg, "Stella", Matrix.Translation(c + Vector((0, 0, top))), 1.5, 0.03)
    # leggio di pietra con le rune, verso l'arena (piano inclinato verso chi sta sulla pedana)
    q = c + Vector((0, 3.7, top))
    lathe(pc, [(0.65, 0.0), (0.65, 0.15), (0.45, 0.3), (0.32, 0.45), (0.28, 0.85), (0.4, 1.0)], 12, q)
    Mt = Matrix.Translation(q + Vector((0, 0, 1.12))) @ Matrix.Rotation(math.radians(-25), 4, "X")
    box(ps, Mt @ Vector((0, 0, 0)), (1.3, 0.9, 0.22), rot=Mt.to_3x3(), bev=0.05)
    box(pc, Mt @ Vector((0, 0.5, 0.06)), (1.4, 0.12, 0.3), rot=Mt.to_3x3(), bev=0.03)
    for i in range(6):
        Mg = Mt @ Matrix.Translation((-0.45 + (i % 3) * 0.45, -0.17 + (i // 3) * 0.34, 0.11)) @ Matrix.Diagonal((0.24, 0.24, 1, 1))
        strokes_geo(pe, rune_strokes(rng), 0.12, Mg, 0.02)
    m.marker("SPOT_Pedana", c + Vector((0, 0, top)))
    m.marker("FX_Light_Pedana", c + Vector((0, 3.7, top + 1.6)))
    # collisione: ottagono di due scatole e rampe sui gradini
    for a in (0.0, math.pi / 4):
        m.col("Pedana_%d" % int(a * 4 / math.pi), c + Vector((0, 0, (top - 1.5) / 2)), (10.0, 10.0, top + 1.5), Matrix.Rotation(a + math.radians(22.5), 3, "Z"))
    for k in range(8):
        a = math.radians(45 * k)
        d = Vector((math.cos(a), math.sin(a), 0))
        m.ramp("PedanaRampa%d" % (k + 1), c + d * 7.1, c + d * 4.85 + Vector((0, 0, top)), 4.4, 0.5)


def altare():
    pb = m.part("Arena_Altare", "Basalto")
    pc = m.part("Arena_Altare_Cornici", "PietraCornice")
    ph = m.part("Arena_Altare_Corna", "StatuaOssa")
    pf = m.part("Arena_Altare_Ferro", "FerroBattuto")
    pe = m.part("Arena_Altare_Rune", "MAT_Ember")
    c = ALTARE
    box(pc, c + Vector((0, 0, 0.15)), (3.8, 2.8, 0.5), bev=0.1)
    box(pb, c + Vector((0, 0, 0.4 + 0.6)), (3.0, 2.0, 1.2), bev=0.12)
    box(pb, c + Vector((0, 0, 1.68)), (3.3, 2.3, 0.22), bev=0.06)
    # rune rosse sul davanti (-Y) e sui fianchi
    for i in range(5):
        Mg = plane_M(c + Vector((-1.1 + i * 0.55, -1.0, 1.0)), (1, 0, 0), (0, 0, 1)) @ Matrix.Diagonal((0.42, 0.55, 1, 1))
        strokes_geo(pe, rune_strokes(rng), 0.13, Mg, 0.04)
    for sx in (-1, 1):
        for i in range(3):
            Mg = plane_M(c + Vector((sx * 1.5, -0.55 + i * 0.55, 1.0)), (0, -sx, 0), (0, 0, 1)) @ Matrix.Diagonal((0.42, 0.55, 1, 1))
            strokes_geo(pe, rune_strokes(rng), 0.13, Mg, 0.04)
    box(pe, c + Vector((0, -1.0, 0.52)), (2.6, 0.06, 0.06))
    # braciere rosso al centro
    q = c + Vector((0, 0.1, 1.79))
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        cyl(pf, q + Vector((0.5 * math.cos(a), 0.5 * math.sin(a), 0)), q + Vector((0.35 * math.cos(a), 0.35 * math.sin(a), 0.5)), 0.06, n=5)
    lathe(pf, [(0.2, 0.4), (0.6, 0.5), (0.8, 0.8), (0.82, 0.95), (0.7, 0.95), (0.55, 0.65), (0.1, 0.55)], 14, q, close=False)
    lathe(pe, [(0.68, 0.82), (0.35, 0.92), (0.01, 0.96)], 10, q, close=False)
    m.marker("FX_Fire_Altare", q + Vector((0, 0, 1.05)))
    m.marker("FX_Light_Altare", q + Vector((0, 0, 1.8)))
    # due corna di drago dagli angoli dietro, curve in su e verso il centro
    for sx in (-1, 1):
        b = c + Vector((sx * 1.25, 0.65, 1.75))
        L.horn(ph, Vector((0, 0, 0)), [Vector((sx * 0.45, 0.2, 0.9)), Vector((sx * 0.5, 0.05, 1.8)), Vector((sx * 0.15, -0.35, 2.35)), Vector((-sx * 0.25, -0.5, 2.5))], 0.3, Matrix.Translation(b), n=10)
        torus(pf, b + Vector((sx * 0.1, 0.06, 0.25)), 0.32, 0.05, normal=(0, 0, 1), nR=12, nr=4)
    m.marker("SPOT_Altare", c + Vector((0, 0, 1.79)))
    m.col("Altare", c + Vector((0, 0, 0.9)), (3.3, 2.3, 1.8))
    m.col("AltareBase", c + Vector((0, 0, 0.2)), (3.8, 2.8, 0.4))


# ---------------------------------------------------------------------------------------------

def build():
    draghi()
    for k in range(8):
        mura(k)
    for j in range(8):
        torre(j)
    portale()
    palco()
    pavimento()
    pedana()
    altare()
    m.notes.update({
        "diametro_interno_m": 2 * R_IN, "diametro_esterno_m": 2 * R_OUT, "altezza_mura_m": Z_DECK,
        "torri_m": 40, "arco_portale_m": [20, 30], "pedana_centro_blender": list(PEDANA),
    })


if __name__ == "__main__":
    args = L.argv()
    L.clear_scene()
    build()
    objs, cobs, info = L.export(m)
    for p in sorted(info["parti"], key=lambda q: -q["triangoli"])[:8]:
        print("   %-34s %6d" % (p["nome"], p["triangoli"]))
    if "--render" in args:
        views = ["davanti", "dietro", "alto", "tre_quarti", "pedana", "interno"]
        extra = {
            "pedana": ((0, -131.0, 9.0), (0, -60.0, 14.0), 30),
            "interno": ((-40.0, 45.0, 30.0), (10.0, -40.0, 12.0), 24),
            "portale": ((-35.0, -150.0, 18.0), (0, -100.0, 20.0), 35),
            "palco": ((0, 20.0, 18.0), (0, 80.0, 14.0), 35),
            "torre": ((70.0, -160.0, 22.0), (38.0, -92.0, 24.0), 40),
        }
        if "--viste" in args:
            views = args[args.index("--viste") + 1].split(",")
        L.render_previews(m, objs, info, views=views, extra_views=extra)
