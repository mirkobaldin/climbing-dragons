# Modelli dei borghi cinesi e giapponesi per Roblox, costruiti da codice in Blender (5.2).
# Tutti visitabili: porte e finestre sono aperture vere, ci sono pavimenti, scale e arredi.
#
# Nel Blender aperto (MCP o Text Editor > Run Script): crea la scena "Borghi" coi modelli in fila.
# Senza finestra (non tocca il Blender aperto):
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup \
#       --python tools/blender/borghi.py -- [--render] [--only CasaFenghuang] [--export]
# --export scrive tools/blender/out/borghi.fbx (Studio: File > Import 3D) e le collisioni in
# src/mapgen/BorghiCollide.luau (scatole invisibili: in Roblox si cammina dentro le case).
# Ogni modello e' un Empty con un oggetto per materiale ("<Modello>__<MATERIALE>"); i segnaposto
# FRONT (davanti all'ingresso) e ORIGIN (origine, a terra) servono a Studio per girarli e scalarli.
#
# Riferimenti: case su palafitte di Fenghuang (diaojiaolou: ali sporgenti con i pilastri sospesi,
# travi passanti, ballatoi con la panchina), case-negozio e case da te' cinesi, machiya di Kyoto
# (grata koshi, noren, inuyarai, corridoio di terra, giardino interno), case di Huizhou (muri
# bianchi a gradini, cortile tianjing), minka col focolare irori.

import bpy
import math
import os
import sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.path.join(os.path.expanduser("~"), "Desktop", "RObloxGame", "tools", "blender")
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import importlib
import borghi_lib
importlib.reload(borghi_lib)
from borghi_lib import (Builder, frame_of, roof, shed_roof, wall, opening_frame, lattice, slab, stairs, red_lantern, railing,
                        table, stool, teapot, jar, bed, shelf, hanging_post, buddha, incense_burner)

FH = 10.0  # altezza di un piano


def posts_and_ties(b, x0, x1, y0, y1, z0, h, every=4.7, ties=(3.4, 6.8), out=0.8, doors=()):
    """Pilastri scuri agli angoli e lungo i muri, travi passanti che sporgono oltre gli angoli
    (la struttura a traversi delle case cinesi di legno).
    doors: porte da lasciare libere, (lato, s0, s1, alto) con s misurato come nel muro (wall):
    "front" da x0 verso x1, "right" da y0 verso y1, "back" da x1 verso x0, "left" da y1 verso y0.
    Nel vano niente pilastri e niente travi sotto l'architrave (prima sbarravano le porte)."""
    gaps = {"front": [], "back": [], "left": [], "right": []}
    for side, s0, s1, top in doors:
        if side == "front":
            lo, hi = x0 + s0, x0 + s1
        elif side == "back":
            lo, hi = x1 - s1, x1 - s0
        elif side == "right":
            lo, hi = y0 + s0, y0 + s1
        else:
            lo, hi = y1 - s1, y1 - s0
        gaps[side].append((lo, hi, top))

    def in_gap(side, c):
        return any(lo + 0.3 < c < hi - 0.3 for lo, hi, _ in gaps[side])

    def tie(side, a, c, fixed, z, along_x):
        # trave da a a c (lungo x o y) interrotta dove c'e' una porta piu' alta della trave
        cuts = sorted((lo, hi) for lo, hi, top in gaps[side] if z - z0 < top + 0.4)
        segs, cur = [], a
        for lo, hi in cuts:
            if lo > cur:
                segs.append((cur, lo))
            cur = max(cur, hi)
        if c > cur:
            segs.append((cur, c))
        for s0, s1 in segs:
            if s1 - s0 < 0.2:
                continue
            m = (s0 + s1) / 2
            if along_x:
                b.box("TIMBERDARK", (m, fixed, z), (s1 - s0, 0.55, 0.5), collide=False)
            else:
                b.box("TIMBERDARK", (fixed, m, z), (0.55, s1 - s0, 0.5), collide=False)

    nx = max(1, round((x1 - x0) / every))
    ny = max(1, round((y1 - y0) / every))
    for k in range(nx + 1):
        x = x0 + (x1 - x0) * k / nx
        for y, side in ((y0, "front"), (y1, "back")):
            if not in_gap(side, x):
                b.box("TIMBERDARK", (x, y, z0 + h / 2), (0.8, 0.8, h), collide=False)
    for k in range(1, ny):
        y = y0 + (y1 - y0) * k / ny
        for x, side in ((x0, "left"), (x1, "right")):
            if not in_gap(side, y):
                b.box("TIMBERDARK", (x, y, z0 + h / 2), (0.8, 0.8, h), collide=False)
    for t in ties:
        z = z0 + t
        tie("front", x0 - out, x1 + out, y0, z, True)
        tie("back", x0 - out, x1 + out, y1, z, True)
        tie("left", y0 - out, y1 + out, x0, z, False)
        tie("right", y0 - out, y1 + out, x1, z, False)


def window(b, p0, p1, s0, s1, z0, zb, zt, bars=(4, 3)):
    """Finestra aperta nel muro p0-p1: cornice, grata e carta."""
    opening_frame(b, p0, p1, s0, s1, z0, zb, zt)
    lattice(b, p0, p1, s0, s1, z0, zb, zt, bars=bars)


def door_frame(b, p0, p1, s0, s1, z0, zt, leaves=True):
    """Porta aperta: cornice, soglia e i due battenti spalancati verso l'interno."""
    opening_frame(b, p0, p1, s0, s1, z0, 0, zt, sill=False)
    if not leaves:
        return
    P0, P1 = Vector((p0[0], p0[1], 0)), Vector((p1[0], p1[1], 0))
    d = (P1 - P0).normalized()
    inward = Vector((-d.y, d.x, 0))  # i muri girano in senso antiorario: dentro e' a sinistra
    w = (s1 - s0) / 2
    for s, hinge in ((1, s0), (-1, s1)):
        q = P0 + d * hinge
        c = q + inward * (w / 2 + 0.2) + d * (0.25 * s)
        b.box("TIMBER", (c.x, c.y, z0 + zt / 2), (0.25, w, zt - 0.2) if abs(d.x) > 0.5 else (w, 0.25, zt - 0.2), collide=False)


# ---------------------------------------------------------------------------------------
# casa di Fenghuang (diaojiaolou)

def casa_fenghuang(name, tower=False):
    b = Builder(name)
    W, D = 14.0, 12.0
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    t = 0.5
    z = 0.3
    b.box("STONE", (0, 0, -0.5), (W + 1.4, D + 1.4, 1.0), collide=True)
    slab(b, "WOOD", x0, x1, y0, y1, z, t=0.3)
    # piano terra: porta in mezzo, finestre ai lati (i muri girano in senso antiorario)
    front = ((x0, y0), (x1, y0))
    wall(b, "TIMBER", *front, z, FH, t, holes=[(5, 9, 0, 7.6), (1.4, 4.2, 3.2, 6.4), (9.8, 12.6, 3.2, 6.4)])
    door_frame(b, *front, 5, 9, z, 7.6)
    window(b, *front, 1.4, 4.2, z, 3.2, 6.4)
    window(b, *front, 9.8, 12.6, z, 3.2, 6.4)
    back = ((x1, y1), (x0, y1))
    wall(b, "TIMBER", *back, z, FH, t, holes=[(2.5, 5.5, 3.4, 6.4)])
    window(b, *back, 2.5, 5.5, z, 3.4, 6.4)
    right = ((x1, y0), (x1, y1))
    wall(b, "TIMBER", *right, z, FH, t, holes=[(4.5, 7.5, 3.4, 6.4)])
    window(b, *right, 4.5, 7.5, z, 3.4, 6.4)
    left = ((x0, y1), (x0, y0))
    wall(b, "TIMBER", *left, z, FH, t)
    posts_and_ties(b, x0, x1, y0, y1, z - 0.3, FH + 0.3, doors=[("front", 5, 9, 7.9)])
    # dentro: la scala lungo il muro di sinistra, la cucina in fondo a destra, il tavolo
    stairs(b, (x0 + 1.55, y0 + 1.4, z), (0, 1), 2.2, FH, rise=1.0, tread=0.95)
    b.box("STONE", (x1 - 2.2, y1 - 1.6, z + 1.3), (3.6, 2.2, 2.6), collide=True)
    b.sphere("BRONZE", (x1 - 2.2, y1 - 1.6, z + 2.7), 0.9, rz=0.45, seg=10, rings=5)
    b.cyl("STONEDARK", (x1 - 0.9, y1 - 1.0, z + 2.6), (x1 - 0.9, y1 - 1.0, z + FH + 9), 0.4, n=6)
    shelf(b, (2.0, y1 - 0.9, z), w=4.0, h=5.5)
    table(b, (2.4, -0.6, z))
    for dx, dy in ((-2.2, 0), (2.2, 0), (0, -1.9), (0, 1.9)):
        stool(b, (2.4 + dx, -0.6 + dy, z))
    teapot(b, (2.4, -0.6, z + 2.6))
    for k in range(3):
        jar(b, (x0 + 4 + k * 1.3, y1 - 0.9, z), r=0.55, h=1.5)
    red_lantern(b, (0.5, 0, z + FH - 0.6), 0.8)

    def upper(z, bal_front, bal_right):
        slab(b, "WOOD", x0, x1, y0, y1, z, t=0.5, hole=(x0 + 0.25, x0 + 2.85, y0 + 5.0, y1 - 0.25))
        fr = ((x0, y0), (x1, y0))
        wall(b, "TIMBER", *fr, z, FH - 1, t, holes=[(5, 9, 0, 7.4), (0.9, 4.4, 2.4, 6.6), (9.6, 13.1, 2.4, 6.6)])
        door_frame(b, *fr, 5, 9, z, 7.4)
        window(b, *fr, 0.9, 4.4, z, 2.4, 6.6, bars=(5, 3))
        window(b, *fr, 9.6, 13.1, z, 2.4, 6.6, bars=(5, 3))
        bk = ((x1, y1), (x0, y1))
        wall(b, "TIMBER", *bk, z, FH - 1, t, holes=[(2.0, 5.5, 2.6, 6.2), (8.5, 12, 2.6, 6.2)])
        window(b, *bk, 2.0, 5.5, z, 2.6, 6.2)
        window(b, *bk, 8.5, 12, z, 2.6, 6.2)
        rt = ((x1, y0), (x1, y1))
        holes = [(2.0, 5.0, 0, 7.2)] if bal_right else []
        holes.append((7.0, 10.0, 2.6, 6.2))
        wall(b, "TIMBER", *rt, z, FH - 1, t, holes=holes)
        if bal_right:
            door_frame(b, *rt, 2.0, 5.0, z, 7.2)
        window(b, *rt, 7.0, 10.0, z, 2.6, 6.2)
        lf = ((x0, y1), (x0, y0))
        wall(b, "TIMBER", *lf, z, FH - 1, t, holes=[(6.5, 9.5, 2.6, 6.2)])
        window(b, *lf, 6.5, 9.5, z, 2.6, 6.2)
        posts_and_ties(b, x0, x1, y0, y1, z, FH - 1, ties=(3.0, 7.2),
                       doors=[("front", 5, 9, 7.4)] + ([("right", 2.0, 5.0, 7.2)] if bal_right else []))
        return z

    z1 = z + FH
    upper(z1, True, True)
    # camera: letto, tavolino con la teiera, armadio (nella torre al loro posto c'e' la scala)
    table(b, (1.5, -2.0, z1), w=2.6, d=1.8, h=2.4)
    teapot(b, (1.5, -2.0, z1 + 2.4))
    for dx in (-1.8, 1.8):
        stool(b, (1.5 + dx, -2.0, z1))
    if not tower:
        bed(b, (x1 - 3.4, y1 - 2.2, z1), d_axis="x")
        b.box("TIMBER", (x0 + 4.0, y1 - 0.8, z1 + 3), (3.0, 1.2, 6.0), collide=True)
        b.box("GOLD", (x0 + 4.0, y1 - 1.45, z1 + 3.2), (0.3, 0.1, 0.3), collide=False)
    # ballatoio davanti e sul fianco destro, con la panchina e i pilastri sospesi
    bx1, by0 = x1 + 3.6, y0 - 3.6
    slab(b, "WOOD", x0 - 0.3, bx1, by0, y0, z1, t=0.5)
    slab(b, "WOOD", x1, bx1, y0, y1 + 0.3, z1, t=0.5)
    railing(b, (x0 - 0.3, by0, z1), (bx1, by0, z1), bench=True)
    railing(b, (bx1, by0, z1), (bx1, y1 + 0.3, z1), bench=True)
    railing(b, (x0 - 0.3, y0, z1), (x0 - 0.3, by0, z1), h=3.2)
    top = z1 + FH - 1
    for k in range(5):
        x = x0 - 0.2 + (bx1 - x0 + 0.2) * k / 4
        b.box("TIMBERDARK", (x, by0 + 0.3, (z1 + top) / 2), (0.7, 0.7, top - z1), collide=False)
        hanging_post(b, x, by0 + 0.3, z1 - 0.5)
        b.beam("TIMBERDARK", (x, y0, z1 - 3.0), (x, by0 + 0.4, z1 - 0.45), 0.4, 0.4, collide=False)
    for k in range(1, 4):
        y = by0 + (y1 + 0.3 - by0) * k / 3.4
        b.box("TIMBERDARK", (bx1 - 0.3, y, (z1 + top) / 2), (0.7, 0.7, top - z1), collide=False)
        hanging_post(b, bx1 - 0.3, y, z1 - 0.5)
        b.beam("TIMBERDARK", (x1, y, z1 - 3.0), (bx1 - 0.4, y, z1 - 0.45), 0.4, 0.4, collide=False)
    for k in range(3):
        red_lantern(b, (x0 + 2.5 + k * 6.5, by0 + 0.3, top - 0.4), 1.0)
    # tettoia dietro sopra il piano terra
    shed_roof(b, x0 - 0.8, x1 + 0.8, y1 + 2.6, y1 + 0.1, z1 - 1.6, z1 + 0.2, mat="SKIRT")
    zr = top
    if tower:
        # terzo piano piu' piccolo, rientrato, con la sua scala (lungo il muro di destra)
        # lungo il muro di fondo, verso sinistra (cosi' non copre la porta del ballatoio)
        stairs(b, (x1 - 1.0, y1 - 1.4, z1), (-1, 0), 2.2, FH - 1, rise=1.0, tread=0.95)
        z2 = top
        tx0, tx1, ty0, ty1 = x0 + 1.5, x1 - 0.0, y0 + 0.5, y1
        slab(b, "WOOD", x0, x1, y0, y1, z2, t=0.5, hole=(-3.9, 3.3, y1 - 2.6, y1 - 0.25))
        for (p, q, hl) in ((((tx0, ty0), (tx1, ty0)), None, [(4.5, 8.5, 2.4, 6.4)]), (((tx1, ty1), (tx0, ty1)), None, [(4.0, 7.5, 2.6, 6.2)]),
                           (((tx1, ty0), (tx1, ty1)), None, [(3.5, 6.5, 2.6, 6.2)]), (((tx0, ty1), (tx0, ty0)), None, [(3.5, 6.5, 2.6, 6.2)])):
            wall(b, "PLASTER", *p, z2, 8.0, t, holes=hl)
            for h in hl:
                window(b, *p, h[0], h[1], z2, h[2], h[3], bars=(5, 3))
        posts_and_ties(b, tx0, tx1, ty0, ty1, z2, 8.0, ties=(2.8, 6.0), out=0.5)
        roof(b, 0, 0, z1 + FH - 1.2, W / 2 + 4.6, D / 2 + 4.4, 3.0, style="skirt", ug=0.38, mat="SKIRT")
        zr = z2 + 8.0
        roof(b, (tx0 + tx1) / 2, (ty0 + ty1) / 2, zr, (tx1 - tx0) / 2 + 3.0, (ty1 - ty0) / 2 + 3.0, ((ty1 - ty0) / 2 + 3.0) * 0.7, style="gable", white=True)
    else:
        cx, cy = (x0 - 0.3 + bx1) / 2, (by0 + y1) / 2
        hx, hy = (bx1 - x0 + 0.3) / 2 + 2.6, (y1 - by0) / 2 + 2.6
        roof(b, cx, cy, zr, hx, hy, hy * 0.62, style="gable", white=True)
    return b


# ---------------------------------------------------------------------------------------
# casa da te' (bottega su due piani)

def casa_te(name):
    b = Builder(name)
    W, D = 16.0, 14.0
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    t = 0.5
    z = 0.3
    H1 = 10.5
    b.box("STONE", (0, 0, -0.5), (W + 1.4, D + 1.4, 1.0), collide=True)
    for k in range(3):
        b.box("STONE", (0, y0 - 1.2 - k * 1.0, -0.3 - k * 0.3), (6, 1.0, 0.6), collide=True)
    slab(b, "WOOD", x0, x1, y0, y1, z, t=0.3)
    # davanti tutto aperto: pilastri laccati, fregio di legno traforato in alto
    for x in (x0, -4, 0, 4, x1):
        b.box("LACQUER", (x, y0, z + H1 / 2), (0.9, 0.9, H1), collide=True)
    wall(b, "TIMBER", (x0, y0), (x1, y0), z + 7.9, H1 - 7.9, t, collide=False)
    for k in range(4):
        xa = x0 + 4 * k
        lattice(b, (x0, y0), (x1, y0), 4 * k + 0.5, 4 * k + 3.5, z + 7.9, 0.3, H1 - 8.2, offset=-0.3, bars=(6, 1), paper=False)
    b.box("SIGN", (0, y0 - 0.45, z + 9.2), (7.5, 0.25, 1.8), collide=False)
    # banconi nelle campate laterali
    for xc in (-6, 6):
        b.box("TIMBER", (xc, y0 + 0.8, z + 1.6), (3.4, 1.4, 3.2), collide=True)
        b.box("WOOD", (xc, y0 + 0.8, z + 3.3), (3.8, 1.8, 0.25), collide=False)
        for j in range(3):
            jar(b, (xc - 1.2 + j * 1.2, y0 + 0.8, z + 3.45), r=0.4, h=1.0, mat="CERAMIC" if j % 2 else "BRONZE")
    wall(b, "TIMBER", (x1, y1), (x0, y1), z, H1, t, holes=[(2, 5, 3.4, 6.8), (11, 14, 3.4, 6.8)])
    window(b, (x1, y1), (x0, y1), 2, 5, z, 3.4, 6.8)
    window(b, (x1, y1), (x0, y1), 11, 14, z, 3.4, 6.8)
    wall(b, "TIMBER", (x1, y0), (x1, y1), z, H1, t, holes=[(4, 8, 3.2, 6.8)])
    window(b, (x1, y0), (x1, y1), 4, 8, z, 3.2, 6.8, bars=(5, 3))
    wall(b, "TIMBER", (x0, y1), (x0, y0), z, H1, t)
    posts_and_ties(b, x0, x1, y0, y1, z - 0.3, H1 + 0.3, ties=(7.6,))
    # dentro: scaffale con le giare, tavolini con la teiera, la scala a sinistra
    shelf(b, (3.5, y1 - 0.9, z), w=7.0, h=6.5)
    for (tx, ty) in ((2.0, -1.5), (5.2, 2.5), (-1.6, 3.0)):
        table(b, (tx, ty, z), w=2.6, d=2.0, h=2.5)
        teapot(b, (tx, ty, z + 2.5))
        for dx, dy in ((-1.9, 0), (1.9, 0)):
            stool(b, (tx + dx, ty + dy, z))
    stairs(b, (x0 + 1.55, y0 + 2.0, z), (0, 1), 2.2, H1, rise=1.0, tread=0.95)
    for x in (-2.5, 3.5):
        red_lantern(b, (x, 0, z + H1 - 0.6), 0.9)
    # piano di sopra: galleria aperta davanti con la panchina, sala da te' dietro le grate
    z1 = z + H1
    slab(b, "WOOD", x0, x1, y0 - 0.4, y1, z1, t=0.5, hole=(x0 + 0.25, x0 + 2.85, y0 + 5.0, y1 - 0.25))
    ya = y0 + 3.0  # muro della sala, arretrato: davanti resta la galleria
    railing(b, (x0 - 0.2, y0 - 0.4, z1), (x1 + 0.2, y0 - 0.4, z1), bench=True)
    H2 = 8.5
    wall(b, "TIMBER", (x0, ya), (x1, ya), z1, H2, t, holes=[(1, 5, 0, 7.2), (6, 10, 0, 7.2), (11, 15, 0, 7.2)])
    for s0 in (1, 6, 11):
        opening_frame(b, (x0, ya), (x1, ya), s0, s0 + 4, z1, 0, 7.2, sill=False)
        lattice(b, (x0, ya), (x1, ya), s0, s0 + 1.1, z1, 0.2, 7.0, bars=(2, 6))
        lattice(b, (x0, ya), (x1, ya), s0 + 2.9, s0 + 4, z1, 0.2, 7.0, bars=(2, 6))
    wall(b, "TIMBER", (x1, y1), (x0, y1), z1, H2, t, holes=[(3, 7, 2.6, 6.0), (9, 13, 2.6, 6.0)])
    window(b, (x1, y1), (x0, y1), 3, 7, z1, 2.6, 6.0)
    window(b, (x1, y1), (x0, y1), 9, 13, z1, 2.6, 6.0)
    for p in (((x1, y0 - 0.4), (x1, y1)), ((x0, y1), (x0, y0 - 0.4))):
        wall(b, "TIMBER", *p, z1, H2, t, holes=[(7.5, 11.5, 2.6, 6.0)])
        window(b, *p, 7.5, 11.5, z1, 2.6, 6.0)
    for x in (x0, -4, 0, 4, x1):
        b.box("LACQUER", (x, y0 - 0.4, z1 + H2 / 2), (0.7, 0.7, H2), collide=False)
    for (tx, ty) in ((-3.0, 3.6), (3.0, 3.6)):
        b.box("TIMBER", (tx, ty, z1 + 0.9), (3.0, 2.0, 0.3), collide=True)
        for s in (-1, 1):
            b.box("FABRIC", (tx, ty + s * 1.5, z1 + 0.25), (1.4, 1.0, 0.4), collide=False)
        teapot(b, (tx, ty, z1 + 1.05))
    roof(b, 0, 0, z1 - 0.5, W / 2 + 2.8, D / 2 + 3.2, 2.6, style="skirt", ug=0.36, mat="SKIRT")
    zr = z1 + H2
    roof(b, 0, -0.2, zr, W / 2 + 3.0, D / 2 + 3.4, (D / 2 + 3.4) * 0.62, style="gable")
    for k in range(5):
        red_lantern(b, (x0 + k * 4, y0 - 0.6, zr - 0.4), 0.9)
    return b


# ---------------------------------------------------------------------------------------
# machiya di Kyoto: stretta e profonda, negozio davanti, giardino interno, stanza dietro

def stone_lantern_small(b, c, s=1.0):
    c = Vector(c)
    b.cyl("STONEDARK", c, c + Vector((0, 0, 0.6 * s)), 0.9 * s, n=6)
    b.cyl("STONEDARK", c + Vector((0, 0, 0.6 * s)), c + Vector((0, 0, 2.4 * s)), 0.35 * s, n=8)
    b.cyl("STONEDARK", c + Vector((0, 0, 2.4 * s)), c + Vector((0, 0, 2.8 * s)), 0.85 * s, n=6)
    b.box("PAPER", c + Vector((0, 0, 3.4 * s)), (0.8 * s, 0.8 * s, 1.0 * s), collide=False)
    roof(b, c.x, c.y, c.z + 3.9 * s, 1.2 * s, 1.2 * s, 0.8 * s, style="hip", mat="STONEDARK", ribs=False, tips=False, ridge=False, lift=0.25 * s, t=0.3)
    b.sphere("STONEDARK", c + Vector((0, 0, 5.0 * s)), 0.3 * s, seg=6, rings=4)


def tree_small(b, c, s=1.0):
    c = Vector(c)
    b.tube("TIMBER", [c, c + Vector((0.3, 0.2, 2.5)) * s, c + Vector((-0.2, 0.5, 4.5)) * s], 0.28 * s, n=6)
    for (dx, dy, dz, r) in ((0, 0.4, 5.2, 1.8), (1.2, -0.2, 4.6, 1.3), (-1.1, 0.8, 4.4, 1.2), (0.4, 1.0, 6.1, 1.1)):
        b.sphere("LEAF", c + Vector((dx, dy, dz)) * s, r * s, rz=r * 0.75 * s, seg=8, rings=5)


def cushion(b, c):
    b.box("FABRIC", Vector(c) + Vector((0, 0, 0.18)), (1.3, 1.3, 0.35), collide=False)


def machiya(name):
    b = Builder(name)
    x0, x1 = -5.0, 5.0
    yf, yg, yb, ye = -12.0, 0.0, 6.0, 12.0  # facciata, inizio giardino, stanza dietro, fondo
    z = 0.3
    zr = 1.5  # pavimento rialzato (tatami)
    t = 0.45
    b.box("STONE", (0, 0, -0.5), (x1 - x0 + 1.2, ye - yf + 1.2, 1.0), collide=True)
    # corridoio di terra (toori-niwa) lungo tutta la casa a sinistra, pavimento rialzato a destra
    slab(b, "EARTH", x0, -2, yf, ye, z, t=0.3)
    slab(b, "WOOD", -2, x1, yf, yg, zr, t=1.2)
    b.box("STONE", (-2.6, -6, z + 0.3), (1.0, 2.0, 0.6), collide=True)
    # facciata: porta col noren, grata koshi fitta, staccionata curva di bambu' (inuyarai)
    fr = ((x0, yf), (x1, yf))
    H1 = 8.6
    wall(b, "TIMBER", *fr, z, H1, t, holes=[(0.25, 3.15, 0, 7.0), (3.4, 9.6, 0.8, 7.0)])
    opening_frame(b, *fr, 0.25, 3.15, z, 0, 7.0, sill=False)
    opening_frame(b, *fr, 3.4, 9.6, z, 0.8, 7.0)
    for k in range(18):
        x = x0 + 3.4 + 6.2 * (k + 0.5) / 18
        b.box("TIMBER", (x, yf - 0.05, z + 3.9), (0.18, 0.22, 6.2), collide=False)
    for zz in (2.6, 5.2):
        b.box("TIMBER", (x0 + 6.5, yf - 0.05, z + zz), (6.2, 0.25, 0.2), collide=False)
    b.collider((x0 + 6.5, yf, z + 3.9), (6.2, 0.4, 6.2))
    b.poly("PAPER", [(x0 + 3.4, yf + 1.0, z + 0.8), (x0 + 9.6, yf + 1.0, z + 0.8), (x0 + 9.6, yf + 1.0, z + 7.0), (x0 + 3.4, yf + 1.0, z + 7.0)], thick=0.06)
    for k in range(3):
        b.box("FABRIC", (x0 + 1.0 + k * 0.8, yf - 0.3, z + 6.35), (0.72, 0.08, 1.3), collide=False)
    b.box("WOOD", (x0 + 1.6, yf - 0.32, z + 7.15), (2.6, 0.12, 0.15), collide=False)
    for k in range(16):
        x = x0 + 3.6 + 5.8 * (k + 0.5) / 16
        b.tube("BAMBOO", [(x, yf - 0.3, z), (x, yf - 1.15, z + 0.6), (x, yf - 1.1, z + 1.6), (x, yf - 0.4, z + 2.6)], 0.09, n=5)
    for zz, yy in ((0.9, yf - 1.05), (2.0, yf - 0.85)):
        b.tube("BAMBOO", [(x0 + 3.5, yy, z + zz), (x0 + 9.5, yy, z + zz)], 0.08, n=5)
    shed_roof(b, x0 - 0.6, x1 + 0.6, yf - 2.6, yf + 0.1, z + H1 - 0.8, z + H1 + 0.6, mat="SKIRT")
    # muri di confine (intonaco) per tutta l'altezza
    for p in (((x1, yf), (x1, yg)), ((x0, yg), (x0, yf))):
        wall(b, "PLASTER", *p, z, 15.0, t)
    b.box("TIMBERDARK", (x0, (yf + yg) / 2, z + H1), (0.6, yg - yf, 0.5), collide=False)
    b.box("TIMBERDARK", (x1, (yf + yg) / 2, z + H1), (0.6, yg - yf, 0.5), collide=False)
    # dietro verso il giardino: passaggio del corridoio e shoji aperti
    bk = ((x1, yg), (x0, yg))
    wall(b, "TIMBER", *bk, z, H1, t, holes=[(7.1, 9.9, 0, 7.0), (0.6, 6.6, 1.2, 7.2)])
    opening_frame(b, *bk, 0.6, 6.6, z, 1.2, 7.2, sill=False)
    lattice(b, *bk, 0.6, 1.9, z, 1.2, 7.2, bars=(2, 5))
    lattice(b, *bk, 5.3, 6.6, z, 1.2, 7.2, bars=(2, 5))
    # dentro il negozio: scaffali coi rotoli di stoffa, cassa, lanterna di carta
    shelf(b, (1.5, yf + 4.5, zr), w=5.0, h=5.5, along="x")
    b.box("TIMBER", (1.2, yf + 2.0, zr + 1.1), (3.0, 1.2, 2.2), collide=True)
    b.box("PAPER", (2.4, -3.0, zr + 1.0), (0.8, 0.8, 1.6), collide=False)
    # scala a cassettiera (hako-kaidan): sale verso la facciata lungo il muro di destra
    n = 8
    rise = (9.1 - zr) / n
    for i in range(n):
        yy = -1.0 - (i + 0.5) * 1.0
        b.box("TIMBER", (3.9, yy, zr + rise * (i + 1) / 2), (2.0, 1.0, rise * (i + 1)), collide=True)
        if i % 2 == 0:
            b.box("GOLD", (2.88, yy, zr + rise * (i + 0.5) / 2), (0.08, 0.3, 0.12), collide=False)
    # piano di sopra (basso): finestre a stecche d'intonaco (mushiko-mado), stanza di tatami
    z1 = 9.1
    slab(b, "WOOD", x0, x1, yf, yg, z1, t=0.5, hole=(2.8, x1 - 0.25, -9.2, -3.0))
    H2 = 6.2
    wall(b, "PLASTER", *fr, z1, H2, t, holes=[(1.0, 3.2, 1.6, 4.4), (3.9, 6.1, 1.6, 4.4), (6.8, 9.0, 1.6, 4.4)])
    for s0 in (1.0, 3.9, 6.8):
        lattice(b, *fr, s0, s0 + 2.2, z1, 1.6, 4.4, bars=(6, 0), mat="PLASTER", paper=True)
    wall(b, "PLASTER", *bk, z1, H2, t, holes=[(2.0, 8.0, 1.2, 4.8)])
    window(b, *bk, 2.0, 8.0, z1, 1.2, 4.8, bars=(6, 2))
    b.box("TATAMI", (-1.0, -6.0, z1 + 0.06), (7.0, 8.0, 0.12), collide=False)
    b.box("TIMBER", (-1.0, -6.0, z1 + 0.9), (3.0, 2.0, 0.25), collide=True)
    for s in (-1, 1):
        cushion(b, (-1.0, -6.0 + s * 1.6, z1))
    teapot(b, (-1.0, -6.0, z1 + 1.05))
    roof(b, 0, (yf + yg) / 2, z1 + H2, (x1 - x0) / 2 + 0.6, (yg - yf) / 2 + 1.6, 3.6, style="simple", gable_mat="PLASTER")
    # giardino interno (tsubo-niwa): lanterna di pietra, alberello, pietre, veranda
    slab(b, "EARTH", -2, x1, yg, yb, z, t=0.3)
    b.box("WOOD", (1.5, yg + 0.8, zr - 0.3), (7.0, 1.6, 0.6), collide=True)
    stone_lantern_small(b, (3.2, 3.8, z))
    tree_small(b, (0.0, 4.2, z))
    for (sx, sy) in ((-1.4, 1.8), (-0.6, 3.0), (-1.2, 4.4)):
        b.cyl("STONE", (sx, sy, z), (sx, sy, z + 0.25), 0.55, n=8, collide=False)
    for p in (((x1, yg), (x1, yb)), ((x0, yb), (x0, yg))):
        wall(b, "PLASTER", *p, z, 6.5, t)
        b.box("SKIRT", (p[0][0], (yg + yb) / 2, z + 6.7), (1.2, yb - yg, 0.4), collide=False)
    # stanza di dietro (zashiki): tokonoma col rotolo e il vaso, lampada andon
    slab(b, "WOOD", x0, x1, yb, ye, zr, t=1.2)
    b.box("TATAMI", (0, (yb + ye) / 2, zr + 0.06), (9.0, 5.0, 0.12), collide=False)
    fr2 = ((x0, yb), (x1, yb))
    H3 = 8.0
    wall(b, "TIMBER", *fr2, z, H3, t, holes=[(1.8, 8.2, 1.2, 7.2)])
    opening_frame(b, *fr2, 1.8, 8.2, z, 1.2, 7.2, sill=False)
    lattice(b, *fr2, 1.8, 3.2, z, 1.2, 7.2, bars=(2, 5))
    lattice(b, *fr2, 6.8, 8.2, z, 1.2, 7.2, bars=(2, 5))
    for p in (((x1, yb), (x1, ye)), ((x1, ye), (x0, ye)), ((x0, ye), (x0, yb))):
        wall(b, "PLASTER", *p, z, H3, t)
    b.box("WOOD", (0, ye - 0.8, zr + 0.25), (3.0, 1.0, 0.5), collide=False)
    b.box("CLOTH", (0, ye - 0.3, zr + 3.6), (1.4, 0.08, 4.0), collide=False)
    jar(b, (0.8, ye - 0.8, zr + 0.5), r=0.35, h=1.1)
    b.box("PAPER", (x0 + 1.2, yb + 1.5, zr + 1.0), (0.8, 0.8, 1.8), collide=False)
    b.box("TIMBER", (0, (yb + ye) / 2, zr + 0.9), (3.0, 2.0, 0.25), collide=True)
    for s in (-1, 1):
        cushion(b, (s * 2.0, (yb + ye) / 2, zr))
    roof(b, 0, (yb + ye) / 2, z + H3, (x1 - x0) / 2 + 0.6, (ye - yb) / 2 + 1.5, 2.6, style="simple", gable_mat="PLASTER")
    return b


# ---------------------------------------------------------------------------------------
# casa di Huizhou a corte: muri bianchi coi gradini, cortile a cielo aperto, sala degli antenati

def casa_huizhou(name):
    b = Builder(name)
    x0, x1, y0, y1 = -10.0, 10.0, -10.0, 10.0
    H = 11.0
    t = 0.8
    b.box("STONE", (0, 0, -0.5), (21.4, 21.4, 1.0), collide=True)
    slab(b, "STONE", x0, x1, y0, y1, 0.3, t=0.3)
    fr = ((x0, y0), (x1, y0))
    wall(b, "PLASTER", *fr, 0, H, t, holes=[(7.8, 12.2, 0, 7.6), (3.0, 4.6, 8.0, 9.6), (15.4, 17.0, 8.0, 9.6)])
    for s0 in (3.0, 15.4):
        window(b, *fr, s0, s0 + 1.6, 0, 8.0, 9.6, bars=(2, 2))
    for p in (((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))):
        wall(b, "PLASTER", *p, 0, H, t, holes=[(9.0, 11.0, 8.0, 9.6)])
        window(b, *p, 9.0, 11.0, 0, 8.0, 9.6, bars=(2, 2))
    for (cx, cy, sx, sy) in ((0, y0 - 0.45, 21.0, 0.15), (0, y1 + 0.45, 21.0, 0.15), (x0 - 0.45, 0, 0.15, 21.0), (x1 + 0.45, 0, 0.15, 21.0)):
        b.box("STONEDARK", (cx, cy, 0.8), (sx, sy, 1.6), collide=False)
    # portale di pietra con la tettoia, porta aperta, lanterne e la tavola col nome
    b.box("STONE", (-2.55, y0 - 0.5, 4.0), (0.8, 0.6, 8.0), collide=False)
    b.box("STONE", (2.55, y0 - 0.5, 4.0), (0.8, 0.6, 8.0), collide=False)
    b.box("STONE", (0, y0 - 0.5, 8.1), (6.0, 0.7, 0.8), collide=False)
    b.box("SIGN", (0, y0 - 0.85, 9.2), (4.4, 0.2, 1.3), collide=False)
    door_frame(b, *fr, 7.8, 12.2, 0, 7.6)
    roof(b, 0, y0 - 1.2, 10.0, 3.8, 1.5, 1.2, style="gable", ug=0.5, lift=0.7)
    for s in (-1, 1):
        red_lantern(b, (s * 3.2, y0 - 1.9, 9.6), 0.9)
    # muri a gradini (testa di cavallo) sui lati
    for s in (-1, 1):
        x = s * x1
        for half, top in ((10.4, 12.8), (6.6, 14.4), (2.8, 15.8)):
            b.box("PLASTER", (x, 0, (H + top) / 2), (t, half * 2, top - H), collide=False)
            b.box("SKIRT", (x, 0, top + 0.25), (1.9, half * 2 + 0.6, 0.5), collide=False)
            b.box("RIDGE", (x, 0, top + 0.62), (0.7, half * 2 + 0.2, 0.4), collide=False)
            for e in (-1, 1):
                yy = e * (half + 0.3)
                b.tube("RIDGE", [(x, yy - e * 0.6, top + 0.55), (x, yy, top + 0.75), (x, yy + e * 0.5, top + 1.4)], 0.33, n=4)
    # sala d'ingresso con le panche (niente schermo davanti alla porta: sembrava un muro)
    for s in (-1, 1):
        b.box("TIMBER", (s * 7.0, -8.6, 1.3), (4.0, 1.0, 0.3), collide=True)
    shed_roof(b, x0, x1, -1.6, y0, 7.6, H - 0.2)
    for k in range(6):
        b.box("TIMBER", (x0 + 20 * k / 5, -3.0, 4.0), (0.6, 0.6, 7.8), collide=True)
    # cortile: pietra, giara dei pesci, vasi con le piante
    b.box("STONEDARK", (0, 1.0, 0.4), (10.0, 8.0, 0.2), collide=False)
    jar(b, (0, 1.0, 0.5), r=1.3, h=2.0, mat="BRONZE")
    for (px, py) in ((-4, -2), (4, -2), (-4, 4), (4, 4)):
        jar(b, (px, py, 0.5), r=0.6, h=1.2, mat="CERAMIC")
        b.sphere("LEAF", (px, py, 2.2), 0.9, seg=8, rings=5)
    # ali laterali: stanze con le porte a grata verso il cortile
    for s in (-1, 1):
        xi = s * 5.0
        p = ((xi, 5.0), (xi, -3.0)) if s < 0 else ((xi, -3.0), (xi, 5.0))
        wall(b, "TIMBER", *p, 0.3, 7.6, 0.4, holes=[(1.0, 3.4, 0, 7.0), (4.4, 7.4, 2.4, 6.6)])
        door_frame(b, *p, 1.0, 3.4, 0.3, 7.0, leaves=False)
        window(b, *p, 4.4, 7.4, 0.3, 2.4, 6.6, bars=(5, 3))
        shed_roof(b, -3.0, 5.0, s * 3.8, s * 10.0, 7.6, H - 0.2, axis="x")
    bed(b, (-7.6, 2.0, 0.3), d_axis="y")
    table(b, (7.4, 2.0, 0.3), w=3.0, d=1.8)
    stool(b, (7.4, 0.2, 0.3))
    shelf(b, (9.0, 1.0, 0.3), w=4.0, h=5.5, along="y")
    # sala degli antenati in fondo: aperta sul cortile, altare, poltrone, rotolo
    for k in range(6):
        b.box("LACQUER", (x0 + 20 * k / 5, 5.0, 4.2), (0.7, 0.7, 8.2), collide=True)
    b.box("TIMBERDARK", (0, 5.0, 8.1), (20.0, 0.6, 0.6), collide=False)
    lattice(b, (x0, 5.0), (x1, 5.0), 0.4, 19.6, 0.3, 7.2, 7.8, bars=(30, 0), paper=False)
    b.box("TIMBER", (0, 9.0, 1.5), (7.0, 1.4, 3.0), collide=True)
    for k in range(3):
        b.cyl("GOLD", (-2 + k * 2, 9.0, 3.0), (-2 + k * 2, 9.0, 3.6), 0.2, n=6)
    b.box("CLOTH", (0, 9.55, 6.0), (3.0, 0.06, 4.6), collide=False)
    for s in (-1, 1):
        b.box("TIMBERDARK", (s * 3.2, 7.4, 1.0), (1.8, 1.6, 0.4), collide=True)
        b.box("TIMBERDARK", (s * 3.2, 8.1, 2.4), (1.8, 0.3, 3.0), collide=False)
    red_lantern(b, (0, 7.0, 8.0), 1.0)
    shed_roof(b, x0, x1, 3.6, y1, 8.2, H - 0.2)
    return b


# ---------------------------------------------------------------------------------------
# minka: casa di campagna giapponese col focolare (irori) al centro

def minka(name):
    b = Builder(name)
    w, d = 18.0, 12.0
    hx, hy = w / 2, d / 2
    lift = 2.2
    for i in range(-2, 3):
        for j in (-1, 0, 1):
            b.box("STONE", (i * (hx + 2) / 2, j * (hy + 2), 0.6), (1.4, 1.4, 1.6), collide=False)
    slab(b, "WOOD", -hx - 2.5, hx + 2.5, -hy - 2.5, hy + 2.5, lift, t=0.6)
    b.collider((0, 0, lift / 2 - 0.3), (w + 5, d + 5, lift - 0.6))
    for k in range(3):
        b.box("STONE", (0, -hy - 3.2 - k * 0.9, 0.3 + (2 - k) * 0.6), (4.5, 1.0, 0.6), collide=True)
    z = lift
    H = 8.4
    fr = ((-hx, -hy), (hx, -hy))
    wall(b, "PLASTER", *fr, z, H, 0.4, holes=[(7.5, 10.5, 0, 7.0), (1.0, 6.5, 0.6, 6.8), (11.5, 17.0, 0.6, 6.8)])
    door_frame(b, *fr, 7.5, 10.5, z, 7.0, leaves=False)
    for s0 in (1.0, 11.5):
        opening_frame(b, *fr, s0, s0 + 5.5, z, 0.6, 6.8)
        lattice(b, *fr, s0, s0 + 5.5, z, 0.6, 6.8, bars=(5, 4))
    for p, hl in ((((hx, -hy), (hx, hy)), [(3.5, 8.5, 2.2, 6.2)]), (((hx, hy), (-hx, hy)), [(3, 7, 2.6, 6.0), (11, 15, 2.6, 6.0)]), (((-hx, hy), (-hx, -hy)), [(3.5, 8.5, 2.2, 6.2)])):
        wall(b, "PLASTER", *p, z, H, 0.4, holes=hl)
        for h in hl:
            window(b, *p, h[0], h[1], z, h[2], h[3])
    posts_and_ties(b, -hx, hx, -hy, hy, z, H, every=4.5, ties=(H - 0.4,), out=0.4, doors=[("front", 7.5, 10.5, 7.0)])
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box("TIMBERDARK", (sx * (hx + 2.2), sy * (hy + 2.2), z + H / 2), (0.6, 0.6, H), collide=False)
    # dentro: tatami attorno al focolare, travi a vista, cassettone
    for (cx, cy) in ((-5, -2), (5, -2), (-5, 2.5), (5, 2.5)):
        b.box("TATAMI", (cx, cy, z + 0.06), (6.0, 3.2, 0.12), collide=False)
    for k in (-1, 0, 1):
        b.box("TIMBERDARK", (k * 5.5, 0, z + H + 0.4), (0.8, d + 0.6, 0.9), collide=False)
    b.box("TIMBERDARK", (0, 0, z + H + 1.3), (w + 0.6, 0.8, 0.9), collide=False)
    for (ox, oy, sx, sy) in ((0, -1.6, 3.6, 0.4), (0, 1.6, 3.6, 0.4), (-1.6, 0, 0.4, 3.6), (1.6, 0, 0.4, 3.6)):
        b.box("STONEDARK", (ox, oy, z + 0.25), (sx, sy, 0.5), collide=True)
    b.box("EARTH", (0, 0, z + 0.1), (2.8, 2.8, 0.2), collide=False)
    for k in range(4):
        a = k / 4 * math.tau
        b.cyl("TIMBER", (math.cos(a) * 0.6, math.sin(a) * 0.6, z + 0.25), (math.cos(a + 2) * 0.5, math.sin(a + 2) * 0.5, z + 0.35), 0.12, n=5)
    b.sphere("LANTERN", (0, 0, z + 0.5), 0.45, rz=0.35, seg=8, rings=5)
    b.cyl("BAMBOO", (0, 0, z + H + 1.3), (0, 0, z + 2.6), 0.12, n=6)
    b.box("WOOD", (0, 0, z + 3.6), (1.4, 0.25, 0.6), collide=False)
    b.sphere("BRONZE", (0, 0, z + 2.0), 0.75, rz=0.6, seg=10, rings=6)
    for (cx, cy) in ((0, -2.6), (0, 2.6), (-2.6, 0), (2.6, 0)):
        cushion(b, (cx, cy, z))
    b.box("TIMBER", (hx - 2.5, hy - 1.0, z + 2.4), (4.0, 1.4, 4.8), collide=True)
    for k in range(3):
        for j in range(2):
            b.box("GOLD", (hx - 3.5 + j * 2.0, hy - 1.75, z + 0.8 + k * 1.5), (0.4, 0.08, 0.15), collide=False)
    b.box("PAPER", (-hx + 1.5, hy - 1.5, z + 1.2), (0.9, 0.9, 1.8), collide=False)
    rhx, rhy = hx + 4.2, hy + 4.2
    RH = rhy * 1.05
    roof(b, 0, 0, z + H, rhx, rhy, RH, style="gable", lift=0.35, ug=0.5, mat="THATCH", ribs=False, t=1.6, tips=False, ridge=False, p=1.2)
    top = z + H + RH
    b.box("THATCH", (0, 0, top + 0.2), (2 * (rhx - rhy * 0.5) + 1.5, 2.6, 1.6), collide=False)
    b.box("TIMBERDARK", (0, 0, top + 1.1), (2 * (rhx - rhy * 0.5) + 1.8, 1.2, 0.5), collide=False)
    for k in range(-3, 4):
        b.box("TIMBERDARK", (k * (rhx - rhy * 0.5) / 3.5, 0, top + 1.4), (0.5, 3.4, 0.6), collide=False)
    red_lantern(b, (0, -hy - 2.2, z + H - 0.6), 0.9)
    return b


# ---------------------------------------------------------------------------------------
# pagoda (si entra al piano terra: altare con la statua)

def pagoda(name, size=14, tiers=5):
    b = Builder(name)
    b.box("STONE", (0, 0, 0.6), (size + 12, size + 12, 1.6), collide=True)
    b.box("STONE", (0, 0, 1.9), (size + 7, size + 7, 1.2), collide=True)
    for k in range(4):
        b.box("STONE", (0, -size / 2 - 4.4 - k * 1.0, 0.3 + (3 - k) * 0.6), (6, 1.0, 0.6), collide=True)
    z = 2.5
    s = size
    for tier in range(tiers):
        th = 12 if tier == 0 else 7.5
        h = s / 2
        if tier == 0:
            fr = ((-h, -h), (h, -h))
            wall(b, "PLASTER", *fr, z, th, 0.6, holes=[(s / 2 - 2.2, s / 2 + 2.2, 0, 8.0)])
            door_frame(b, *fr, s / 2 - 2.2, s / 2 + 2.2, z, 8.0)
            for p in (((h, -h), (h, h)), ((h, h), (-h, h)), ((-h, h), (-h, -h))):
                wall(b, "PLASTER", *p, z, th, 0.6, holes=[(s / 2 - 1.8, s / 2 + 1.8, 4.0, 8.4)])
                window(b, *p, s / 2 - 1.8, s / 2 + 1.8, z, 4.0, 8.4)
            slab(b, "STONEDARK", -h, h, -h, h, z + 0.15, t=0.2, collide=False)
            b.box("LACQUER", (0, h - 2.6, z + 1.2), (5.0, 3.0, 2.4), collide=True)
            buddha(b, (0, h - 2.6, z + 2.4), 1.15)
            for sx in (-1, 1):
                b.cyl("GOLD", (sx * 2.0, h - 4.6, z + 2.4), (sx * 2.0, h - 4.6, z + 3.2), 0.18, n=6)
                red_lantern(b, (sx * 3.0, -1.0, z + th - 0.8), 0.9)
            b.box("FABRIC", (0, -1.0, z + 0.3), (1.4, 1.4, 0.35), collide=False)
            slab(b, "WOOD", -h, h, -h, h, z + th, t=0.4)
        else:
            b.box("PLASTER", (0, 0, z + th / 2), (s, s, th), collide=True)
            for p in (((-h, -h - 0.05), (h, -h - 0.05)), ((h + 0.05, -h), (h + 0.05, h)), ((h, h + 0.05), (-h, h + 0.05)), ((-h - 0.05, h), (-h - 0.05, -h))):
                lattice(b, *p, s / 2 - 1.6, s / 2 + 1.6, z, th * 0.25, th * 0.8, bars=(4, 3), offset=-0.25)
        for sx in (-1, 1):
            for sy in (-1, 1):
                b.cyl("LACQUER", (sx * h, sy * h, z), (sx * h, sy * h, z + th), 0.6, n=8)
        b.box("LACQUER", (0, 0, z + th - 0.4), (s + 0.6, s + 0.6, 0.8), collide=False)
        for k in range(-2, 3):
            for side in range(4):
                a = side * math.pi / 2
                ca, sa = math.cos(a), math.sin(a)
                px, py = k * s / 5, -h - 0.5
                b.box("TIMBER", (px * ca - py * sa, px * sa + py * ca, z + th + 0.1), (0.8, 0.8, 0.6), collide=False)
        z += th
        o = 3.4 + s * 0.12
        if tier < tiers - 1:
            roof(b, 0, 0, z + 0.5, h + o, h + o, 3.6, style="skirt", ug=0.42, lift=1.7, mat="SKIRT")
            for sx in (-1, 1):
                for sy in (-1, 1):
                    red_lantern(b, (sx * (h + o - 0.8), sy * (h + o - 0.8), z + 0.1), 0.75)
            s *= 0.84
            z += 0.6
        else:
            roof(b, 0, 0, z + 0.5, h + o, h + o, s * 0.55 + 2.4, style="hip", lift=1.7, ridge=False)
            top = z + 0.5 + s * 0.55 + 2.4
            b.cyl("GOLD", (0, 0, top - 0.6), (0, 0, top + 9), 0.35, n=8)
            for k in range(7):
                b.cyl("GOLD", (0, 0, top + 1.5 + k * 0.9), (0, 0, top + 1.8 + k * 0.9), 1.1 - k * 0.1, n=10)
            b.sphere("GOLD", (0, 0, top + 9.5), 0.8, seg=8, rings=6)
    return b


# ---------------------------------------------------------------------------------------
# sala del tempio: colonnato, porte aperte, dentro la statua grande sull'altare

def tempio(name, w=28, d=18):
    b = Builder(name)
    hx, hy = w / 2, d / 2
    b.box("STONE", (0, 0, 1.25), (w + 9, d + 9, 2.5), collide=True)
    for k in range(4):
        b.box("STONE", (0, -hy - 5.0 - k * 1.1, 0.3 + (3 - k) * 0.62), (9, 1.1, 0.62), collide=True)
    incense_burner(b, (0, -hy - 11.5, 0), 1.3)
    b.collider((0, -hy - 11.5, 1.8), (3.0, 3.0, 3.6))
    z = 2.5
    H = 12.5
    n = 6
    cols = [-hx + 1 + (w - 2) * k / (n - 1) for k in range(n)]
    for x in cols:
        for y in (-hy + 0.8, hy - 0.8):
            b.cyl("LACQUER", (x, y, z), (x, y, z + H), 0.8, n=12, collide=True)
            b.cyl("STONE", (x, y, z), (x, y, z + 0.6), 1.15, n=12)
            for k in range(3):
                b.box("TIMBER", (x, y, z + H + 0.3 + k * 0.6), (1.4 + k * 1.1, 1.4 + k * 0.5, 0.55), collide=False)
    ix0, ix1, iy0, iy1 = -hx + 2.5, hx - 2.5, -hy + 2.4, hy - 0.8
    fr = ((ix0, iy0), (ix1, iy0))
    L = ix1 - ix0
    bay = L / 5
    holes = [(bay * k + 0.5, bay * (k + 1) - 0.5, 0 if 1 <= k <= 3 else 1.5, 9.6) for k in range(5)]
    wall(b, "LACQUER", *fr, z, H, 0.5, holes=holes)
    for k, hh in enumerate(holes):
        if 1 <= k <= 3:
            door_frame(b, *fr, hh[0], hh[1], z, hh[3])
        else:
            window(b, *fr, hh[0], hh[1], z, hh[2], hh[3], bars=(5, 6))
    for p in (((ix1, iy0), (ix1, iy1)), ((ix1, iy1), (ix0, iy1)), ((ix0, iy1), (ix0, iy0))):
        wall(b, "LACQUER", *p, z, H, 0.5)
    slab(b, "STONEDARK", ix0, ix1, iy0, iy1, z + 0.15, t=0.2, collide=False)
    b.box("LACQUER", (0, iy1 - 3.2, z + 1.6), (9.0, 4.2, 3.2), collide=True)
    b.box("GOLD", (0, iy1 - 5.35, z + 2.4), (9.0, 0.12, 0.5), collide=False)
    buddha(b, (0, iy1 - 3.2, z + 3.2), 1.7)
    table(b, (0, iy1 - 7.2, z), w=5.0, d=1.6, h=2.8, mat="LACQUER")
    for k in range(-2, 3):
        b.cyl("GOLD", (k * 0.9, iy1 - 7.2, z + 2.8), (k * 0.9, iy1 - 7.2, z + 3.4), 0.15, n=6)
        b.box("FABRIC", (k * 2.2, iy1 - 10.0, z + 0.25), (1.4, 1.4, 0.35), collide=False)
    for s in (-1, 1):
        b.box("CLOTH", (s * (ix1 - 0.4), 0, z + 6.5), (0.08, 2.2, 7.0), collide=False)
        red_lantern(b, (s * 5.5, -1.0, z + H - 0.4), 1.3)
    slab(b, "WOOD", ix0, ix1, iy0, iy1, z + H, t=0.4)
    b.box("TIMBERDARK", (0, -hy + 0.8, z + H - 0.6), (w, 0.9, 1.2), collide=False)
    b.box("GOLD", (0, -hy + 0.3, z + H - 0.6), (w - 2, 0.2, 0.4), collide=False)
    roof(b, 0, 0, z + H + 1.8, hx + 4.2, hy + 4.2, 3.6, style="skirt", ug=0.4, lift=2.0, mat="SKIRT")
    b.box("LACQUER", (0, 0, z + H + 4.0), (w - 6, d - 6, 4.4), collide=False)
    b.box("SIGN", (0, -hy + 2.9, z + H + 4.0), (8, 0.3, 2.4), collide=False)
    roof(b, 0, 0, z + H + 6.0, hx + 2.6, hy + 2.6, (hy + 2.6) * 0.72, style="gable", lift=2.4)
    for s in (-1, 1):
        red_lantern(b, (s * (hx - 2), -hy - 1.8, z + H + 0.9), 1.4)
    return b


# ---------------------------------------------------------------------------------------
# torii, portale, padiglione, ponti, lanterna di pietra

def torii(name, w=12, h=14):
    b = Builder(name)
    for s in (-1, 1):
        b.cyl("LACQUER", (s * w / 2, 0, 0), (s * w / 2, 0, h), 0.75, n=14, collide=True)
        b.cyl("RIDGE", (s * w / 2, 0, -0.5), (s * w / 2, 0, 1.4), 0.95, n=14)
    b.beam("LACQUER", (-w / 2 - 1.6, 0, h * 0.78), (w / 2 + 1.6, 0, h * 0.78), 1.0, 1.0)
    ext = w / 2 + 2.8

    def curve(z0, lift):
        return [(x, 0, z0 + lift * (abs(x) / ext) ** 2.6) for x in [-ext + 2 * ext * k / 16 for k in range(17)]]

    b.tube("LACQUER", curve(h + 0.6, 0.8), 0.75, n=4)
    b.tube("RIDGE", curve(h + 1.6, 1.0), 0.85, n=4)
    b.box("LACQUER", (0, 0, h * 0.89), (1.0, 0.8, h * 0.2), collide=False)
    b.box("SIGN", (0, -0.55, h * 0.89), (1.6, 0.2, 2.2), collide=False)
    return b


def portale(name, w=22):
    b = Builder(name)
    H = 14.5
    for x in (-w / 2, -w / 6, w / 6, w / 2):
        b.box("LACQUER", (x, 0, H / 2), (1.4, 1.4, H), collide=True)
        b.cyl("STONE", (x, 0, 0), (x, 0, 1.6), 1.5, n=10)
        for s in (-1, 1):
            b.box("STONE", (x, s * 1.5, 1.2), (1.0, 1.8, 2.4), collide=True)
    b.box("LACQUER", (0, 0, H - 0.7), (w + 1.6, 1.4, 1.2), collide=False)
    b.box("LACQUER", (0, 0, H - 4.6), (w + 1.6, 1.2, 1.0), collide=False)
    b.box("TIMBER", (0, 0, H - 2.65), (w / 3 + 0.8, 0.6, 2.9), collide=False)
    b.box("SIGN", (0, -0.45, H - 2.65), (w / 3 * 0.92, 0.3, 2.5), collide=False)
    for s in (-1, 1):
        b.box("TIMBER", (s * w / 3, 0, H - 2.65), (w / 3 - 1.4, 0.5, 2.9), collide=False)
        for k in range(6):
            x = s * w / 3 - (w / 3 - 1.4) / 2 + (w / 3 - 1.4) * (k + 0.5) / 6
            b.box("TIMBERDARK", (x, -0.3, H - 2.65), (0.18, 0.2, 2.6), collide=False)
    for k in range(9):
        b.box("TIMBER", (-w / 2 + w * (k + 0.5) / 9, 0, H + 0.3), (0.7, 1.6, 0.6), collide=False)
    roof(b, 0, 0, H + 3.2, w / 6 + 3.2, 3.2, 3.0, style="gable", lift=1.4, ug=0.5)
    for s in (-1, 1):
        roof(b, s * w / 3, 0, H + 0.9, w / 6 + 1.0, 2.8, 2.4, style="gable", lift=1.2, ug=0.5, skip_tip_x=-s)
        red_lantern(b, (s * w / 3, -1.2, H - 4.8), 1.1)
    return b


def padiglione(name, s=11):
    b = Builder(name)
    b.box("STONE", (0, 0, 0.6), (s + 4, s + 4, 1.2), collide=True)
    for k in range(2):
        b.box("STONE", (0, -s / 2 - 2.6 - k * 0.9, 0.2 + (1 - k) * 0.4), (4, 0.9, 0.4), collide=True)
    H = 9.0
    hs = s / 2
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cyl("LACQUER", (sx * hs, sy * hs, 1.2), (sx * hs, sy * hs, 1.2 + H), 0.55, n=10, collide=True)
    b.box("WOOD", (0, hs - 0.9, 3.0), (s - 1.2, 1.6, 0.4), collide=True)
    railing(b, (-hs, hs, 1.2), (hs, hs, 1.2), h=3.6, mat="LACQUER")
    for sx in (-1, 1):
        b.box("WOOD", (sx * (hs - 0.9), 0, 3.0), (1.6, s - 1.2, 0.4), collide=True)
        railing(b, (sx * hs, -hs, 1.2), (sx * hs, hs, 1.2), h=3.6, mat="LACQUER")
    b.cyl("STONE", (0, 0, 1.2), (0, 0, 3.6), 1.4, n=12, collide=True)
    teapot(b, (0, 0, 3.6))
    b.box("TIMBERDARK", (0, 0, 1.2 + H - 0.4), (s + 1, s + 1, 0.8), collide=False)
    roof(b, 0, 0, 1.2 + H + 0.2, hs + 2.8, hs + 2.8, s * 0.55 + 1.2, style="hip", lift=1.5, ridge=False)
    top = 1.2 + H + 0.2 + s * 0.55 + 1.2
    b.sphere("GOLD", (0, 0, top + 0.8), 0.9, seg=8, rings=6)
    b.cyl("GOLD", (0, 0, top - 0.2), (0, 0, top + 0.4), 0.6, n=8)
    red_lantern(b, (0, 0, 1.2 + H - 0.8), 1.2)
    return b


def ponte_pietra(name, span=30, width=8):
    b = Builder(name)
    hs = span / 2
    rise = span * 0.2

    def deck(x):
        return rise * (1 - (x / hs) ** 2)

    N = 20
    xs = [-hs + span * k / N for k in range(N + 1)]
    for k in range(N):
        b.beam("STONE", (xs[k], 0, deck(xs[k])), (xs[k + 1], 0, deck(xs[k + 1])), width, 1.2, collide=True, up=(0, 0, 1))
    R = span * 0.32
    for s in (-1, 1):
        y = s * width / 2
        pts = [(x, y, deck(x) - 0.6) for x in xs]
        arc = [(R * math.cos(math.pi * k / 16), y, -2.0 + R * 0.9 * math.sin(math.pi * k / 16)) for k in range(17)]
        b.poly("STONE", pts + [(hs, y, -2.0)] + arc + [(-hs, y, -2.0)], thick=0.6, normal=(0, s, 0))
    rows = [[(R * math.cos(math.pi * k / 16), yy, -2.0 + R * 0.9 * math.sin(math.pi * k / 16)) for yy in (-width / 2, width / 2)] for k in range(17)]
    b.shell("STONEDARK", rows, 0.8)
    for s in (-1, 1):
        y = s * (width / 2 - 0.3)
        for k in range(N):
            b.beam("STONE", (xs[k], y, deck(xs[k]) + 1.6), (xs[k + 1], y, deck(xs[k + 1]) + 1.6), 0.6, 1.4, collide=True, up=(0, 0, 1))
        for k in range(0, N + 1, 2):
            x = xs[k]
            b.box("STONE", (x, y, deck(x) + 1.4), (0.9, 0.9, 2.8), collide=False)
            b.sphere("STONE", (x, y, deck(x) + 3.1), 0.55, seg=6, rings=4)
    return b


def ponte_rosso(name, span=26, width=7):
    b = Builder(name)
    hs = span / 2
    rise = span * 0.22

    def deck(x):
        return rise * (1 - (x / hs) ** 2)

    N = 18
    xs = [-hs + span * k / N for k in range(N + 1)]
    for k in range(N):
        x0, x1 = xs[k], xs[k + 1]
        b.beam("WOOD", (x0, 0, deck(x0)), (x1, 0, deck(x1)), width, 0.7, collide=True, up=(0, 0, 1))
        for s in (-1, 1):
            b.beam("TIMBERDARK", (x0, s * (width / 2 - 0.2), deck(x0) - 0.6), (x1, s * (width / 2 - 0.2), deck(x1) - 0.6), 0.5, 1.0, collide=False, up=(0, 0, 1))
    for x in (-hs * 0.5, 0, hs * 0.5):
        for s in (-1, 1):
            b.cyl("TIMBERDARK", (x, s * (width / 2 - 0.6), deck(x) - 0.5), (x, s * (width / 2 - 0.6), -6), 0.45, n=8)
        b.beam("TIMBERDARK", (x, -width / 2, deck(x) - 1.2), (x, width / 2, deck(x) - 1.2), 0.6, 0.6, collide=False)
    for s in (-1, 1):
        y = s * width / 2
        for k in range(N):
            x0, x1 = xs[k], xs[k + 1]
            b.beam("LACQUER", (x0, y, deck(x0) + 3.0), (x1, y, deck(x1) + 3.0), 0.4, 0.4, collide=True, up=(0, 0, 1))
            b.beam("LACQUER", (x0, y, deck(x0) + 1.4), (x1, y, deck(x1) + 1.4), 0.3, 0.3, collide=False, up=(0, 0, 1))
        for k in range(0, N + 1, 3):
            b.box("LACQUER", (xs[k], y, deck(xs[k]) + 1.6), (0.55, 0.55, 3.2), collide=False)
        for x in (-hs, hs):
            b.box("LACQUER", (x, y, deck(x) + 2.0), (0.9, 0.9, 4.0), collide=True)
            b.sphere("RIDGE", (x, y, deck(x) + 4.5), 0.7, seg=8, rings=6)
            b.cyl("GOLD", (x, y, deck(x) + 3.9), (x, y, deck(x) + 4.1), 0.55, n=8)
    return b


def ponte_coperto(name, span=28, width=8):
    b = Builder(name)
    hs = span / 2
    rise = 2.2

    def deck(x):
        return rise * (1 - (x / hs) ** 2)

    N = 16
    xs = [-hs + span * k / N for k in range(N + 1)]
    for k in range(N):
        x0, x1 = xs[k], xs[k + 1]
        b.beam("WOOD", (x0, 0, deck(x0)), (x1, 0, deck(x1)), width, 0.8, collide=True, up=(0, 0, 1))
        b.beam("STONEDARK", (x0, 0, deck(x0) - 1.2), (x1, 0, deck(x1) - 1.2), width - 1, 1.6, collide=False, up=(0, 0, 1))
    for x in (-hs * 0.45, hs * 0.45):
        b.box("STONEDARK", (x, 0, -4), (3, width - 0.5, 9), collide=True)
    H = 8.5
    for k in range(0, N + 1, 2):
        x = xs[k]
        for s in (-1, 1):
            b.box("LACQUER", (x, s * (width / 2 - 0.3), deck(x) + (rise + H - deck(x)) / 2), (0.6, 0.6, rise + H - deck(x)), collide=True)
    for s in (-1, 1):
        y = s * (width / 2 - 0.3)
        for k in range(N):
            x0, x1 = xs[k], xs[k + 1]
            b.beam("LACQUER", (x0, y, deck(x0) + 2.4), (x1, y, deck(x1) + 2.4), 0.35, 0.35, collide=True, up=(0, 0, 1))
            b.beam("WOOD", (x0, y - s * 0.7, deck(x0) + 1.5), (x1, y - s * 0.7, deck(x1) + 1.5), 1.2, 0.3, collide=False, up=(0, 0, 1))
    b.box("TIMBERDARK", (0, 0, rise + H), (span + 0.6, width + 0.6, 0.6), collide=False)
    roof(b, 0, 0, rise + H + 0.3, hs + 1.6, width / 2 + 2.2, 3.6, style="gable", lift=1.2, ug=0.5)
    for k in (-1, 0, 1):
        red_lantern(b, (k * hs * 0.55, 0, rise + H - 0.3), 0.9)
    return b


def lanterna_pietra(name):
    b = Builder(name)
    stone_lantern_small(b, (0, 0, 0), 1.4)
    b.collider((0, 0, 2.0), (1.6, 1.6, 4.0))
    return b


# ---------------------------------------------------------------------------------------

MODELS = {
    "CasaFenghuang": lambda: casa_fenghuang("CasaFenghuang"),
    "TorreFenghuang": lambda: casa_fenghuang("TorreFenghuang", tower=True),
    "CasaTe": lambda: casa_te("CasaTe"),
    "Machiya": lambda: machiya("Machiya"),
    "CasaHuizhou": lambda: casa_huizhou("CasaHuizhou"),
    "Minka": lambda: minka("Minka"),
    "Pagoda": lambda: pagoda("Pagoda"),
    "Tempio": lambda: tempio("Tempio"),
    "Torii": lambda: torii("Torii"),
    "Portale": lambda: portale("Portale"),
    "Padiglione": lambda: padiglione("Padiglione"),
    "PontePietra": lambda: ponte_pietra("PontePietra"),
    "PonteRosso": lambda: ponte_rosso("PonteRosso"),
    "PonteCoperto": lambda: ponte_coperto("PonteCoperto"),
    "LanternaPietra": lambda: lanterna_pietra("LanternaPietra"),
}



# =======================================================================================
# altre case

def kura(name):
    """Deposito giapponese (kura): muri bianchi spessi, zoccolo nero a rombi, tetto pesante,
    porta di ferro aperta; dentro scaffali con casse e giare."""
    b = Builder(name)
    W, D, H = 12.0, 9.0, 11.0
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    b.box("STONE", (0, 0, -0.4), (W + 1.6, D + 1.6, 1.2), collide=True)
    slab(b, "WOOD", x0, x1, y0, y1, 0.6, t=0.4)
    fr = ((x0, y0), (x1, y0))
    wall(b, "PLASTER", *fr, 0.2, H, 0.9, holes=[(4.2, 7.8, 0.4, 7.2), (1.6, 2.8, 7.8, 9.0), (9.2, 10.4, 7.8, 9.0)])
    for p in (((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))):
        L = 9.0 if p[0][0] == p[1][0] else 12.0
        wall(b, "PLASTER", *p, 0.2, H, 0.9, holes=[(L / 2 - 0.7, L / 2 + 0.7, 7.6, 8.8)])
        opening_frame(b, *p, L / 2 - 0.7, L / 2 + 0.7, 0.2, 7.6, 8.8, mat="IRON")
    # zoccolo a rombi (namako): piastrelle scure con le fughe bianche in rilievo
    # (davanti si ferma ai lati della porta: prima la sbarrava fino a 3 stud)
    door_lo, door_hi = x0 + 4.2 - 0.3, x0 + 7.8 + 0.3
    for (p, L) in ((((x0, y0 - 0.5), (door_lo, y0 - 0.5)), door_lo - x0), (((door_hi, y0 - 0.5), (x1, y0 - 0.5)), x1 - door_hi),
                   (((x1 + 0.5, y0), (x1 + 0.5, y1)), D), (((x1, y1 + 0.5), (x0, y1 + 0.5)), W), (((x0 - 0.5, y1), (x0 - 0.5, y0)), D)):
        a, c = Vector((*p[0], 0)), Vector((*p[1], 0))
        d = (c - a).normalized()
        b.box("STONEDARK", ((a.x + c.x) / 2, (a.y + c.y) / 2, 1.9), (L + 0.45, 0.12, 2.6) if abs(d.x) > 0.5 else (0.12, L + 0.9, 2.6), collide=False)
        n = max(1, int(L / 1.2))
        for k in range(n + 1):
            q = a + d * (L * k / n)
            for s in (-1, 1):
                e = q + d * (s * 1.3)
                if (e - a).dot(d) < -0.05 or (e - a).dot(d) > L + 0.05:
                    continue  # i rombi non escono dal tratto (davanti alla porta)
                b.beam("PLASTER", q + Vector((0, 0, 0.6)), e + Vector((0, 0, 3.2)), 0.16, 0.16, collide=False, up=None)
    # porta: due ante di ferro spalancate, cornice a gradini
    door_frame(b, *fr, 4.2, 7.8, 0.2, 7.0, leaves=False)
    for s, x in ((-1, -1.8), (1, 1.8)):
        b.box("IRON", (x + s * 1.9, y0 - 1.0, 3.8), (0.4, 1.8, 6.8), collide=False)
    for k in range(3):
        b.box("PLASTER", (0, y0 - 0.55 - k * 0.15, 7.7 + k * 0.3), (4.6 + k * 0.6, 0.3, 0.3), collide=False)
    for s0 in (1.6, 9.2):
        opening_frame(b, *fr, s0, s0 + 1.2, 0.2, 7.8, 9.0, mat="IRON")
    roof(b, 0, 0, H + 0.2, W / 2 + 1.6, D / 2 + 2.0, 3.6, style="simple", gable_mat="PLASTER")
    b.box("RIDGE", (0, 0, H + 4.2), (W + 1.0, 1.4, 1.0), collide=False)
    for s in (-1, 1):
        b.box("RIDGEWHITE", (s * (W / 2 + 0.6), 0, H + 4.5), (0.8, 1.6, 1.4), collide=False)
    # dentro
    for s in (-1, 1):
        shelf(b, (s * (W / 2 - 1.1), 0.5, 0.6), w=5.0, h=6.5, along="y")
    for k in range(3):
        b.box("WOOD", (-1.5 + k * 1.6, y1 - 1.4, 0.6 + 0.8), (1.4, 1.4, 1.6), collide=True)
        b.box("IRON", (-1.5 + k * 1.6, y1 - 1.4, 0.6 + 1.62), (1.45, 1.45, 0.1), collide=False)
    jar(b, (2.8, y1 - 1.5, 0.6), r=0.8, h=2.2)
    return b


def ryokan(name):
    """Locanda giapponese a due piani: ingresso col noren e l'insegna, banco della reception,
    scala, veranda tutto attorno al piano di sopra, camere di tatami coi futon."""
    b = Builder(name)
    W, D = 18.0, 13.0
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    H1, H2 = 9.5, 8.0
    z = 0.6
    b.box("STONE", (0, 0, -0.2), (W + 1.4, D + 1.4, 1.6), collide=True)
    slab(b, "WOOD", x0, x1, y0, y1, z, t=0.3)
    fr = ((x0, y0), (x1, y0))
    wall(b, "TIMBER", *fr, z, H1, 0.4, holes=[(7.0, 11.0, 0, 7.4), (1.0, 6.0, 1.0, 7.0), (12.0, 17.0, 1.0, 7.0)])
    door_frame(b, *fr, 7.0, 11.0, z, 7.4, leaves=False)
    for k in range(4):
        b.box("FABRIC", (-1.5 + k * 1.0, y0 - 0.3, z + 6.75), (0.9, 0.08, 1.3), collide=False)
    for s0 in (1.0, 12.0):
        opening_frame(b, *fr, s0, s0 + 5.0, z, 1.0, 7.0)
        lattice(b, *fr, s0, s0 + 5.0, z, 1.0, 7.0, bars=(6, 4))
    b.box("SIGN", (0, y0 - 0.5, z + H1 - 0.2), (7.0, 0.3, 1.6), collide=False)
    for p, L in ((((x1, y0), (x1, y1)), D), (((x1, y1), (x0, y1)), W), (((x0, y1), (x0, y0)), D)):
        wall(b, "TIMBER", *p, z, H1, 0.4, holes=[(L / 2 - 2.5, L / 2 + 2.5, 2.6, 6.4)])
        window(b, *p, L / 2 - 2.5, L / 2 + 2.5, z, 2.6, 6.4, bars=(6, 3))
    posts_and_ties(b, x0, x1, y0, y1, z, H1, ties=(H1 - 0.5,), out=0.3, doors=[("front", 7.0, 11.0, 7.4)])
    # reception: banco, campanello, lanterna di carta, cassettiera e la scala in fondo a destra
    b.box("WOOD", (3.5, -1.0, z + 1.4), (5.0, 1.2, 2.8), collide=True)
    b.sphere("GOLD", (2.2, -1.0, z + 3.0), 0.25, seg=8, rings=5)
    b.box("PAPER", (5.4, -1.0, z + 3.4), (0.7, 0.7, 1.2), collide=False)
    b.box("TIMBER", (-6.0, y1 - 1.0, z + 2.5), (4.0, 1.2, 5.0), collide=True)
    stairs(b, (x1 - 1.4, y0 + 2.0, z), (0, 1), 2.2, H1, rise=1.0, tread=0.95)
    # piano di sopra con la veranda attorno
    z1 = z + H1
    slab(b, "WOOD", x0 - 2.8, x1 + 2.8, y0 - 2.8, y1 + 2.8, z1, t=0.5, hole=(x1 - 2.65, x1 - 0.25, y0 + 5.6, y1 - 0.25))
    for (p0, p1) in (((x0 - 2.8, y0 - 2.8), (x1 + 2.8, y0 - 2.8)), ((x1 + 2.8, y0 - 2.8), (x1 + 2.8, y1 + 2.8)), ((x1 + 2.8, y1 + 2.8), (x0 - 2.8, y1 + 2.8)), ((x0 - 2.8, y1 + 2.8), (x0 - 2.8, y0 - 2.8))):
        railing(b, (*p0, z1), (*p1, z1), h=3.0, lattice=False)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box("TIMBERDARK", (sx * (W / 2 + 2.6), sy * (D / 2 + 2.6), z1 + H2 / 2), (0.6, 0.6, H2), collide=False)
    ix0, ix1, iy0, iy1 = x0 + 1.0, x1 - 1.0, y0 + 1.0, y1 - 1.0
    for p, L in ((((ix0, iy0), (ix1, iy0)), W - 2), (((ix1, iy0), (ix1, iy1)), D - 2), (((ix1, iy1), (ix0, iy1)), W - 2), (((ix0, iy1), (ix0, iy0)), D - 2)):
        holes = [(L * 0.12, L * 0.38, 0, 7.0), (L * 0.62, L * 0.88, 0, 7.0)]
        wall(b, "PLASTER", *p, z1, H2, 0.3, holes=holes)
        for h in holes:
            opening_frame(b, *p, h[0], h[1], z1, 0, 7.0, sill=False)
            lattice(b, *p, h[0], h[0] + (h[1] - h[0]) * 0.3, z1, 0.2, 6.8, bars=(2, 5))
    for k, xx in enumerate((-4.5, 0.5)):
        b.box("TATAMI", (xx, 0, z1 + 0.06), (5.6, 8.0, 0.12), collide=False)
        b.box("FABRIC", (xx - 1.0, 1.5, z1 + 0.25), (2.0, 4.0, 0.35), collide=False)
        b.box("CLOTH", (xx - 1.0, 3.2, z1 + 0.45), (1.8, 0.8, 0.3), collide=False)
        b.box("TIMBER", (xx + 1.4, -1.5, z1 + 0.9), (2.0, 1.4, 0.25), collide=True)
        teapot(b, (xx + 1.4, -1.5, z1 + 1.05))
    roof(b, 0, 0, z1 - 0.3, W / 2 + 4.2, D / 2 + 4.2, 2.6, style="skirt", ug=0.32, lift=0.9, mat="SKIRT")
    roof(b, 0, 0, z1 + H2, (ix1 - ix0) / 2 + 4.6, (iy1 - iy0) / 2 + 4.6, ((iy1 - iy0) / 2 + 4.6) * 0.6, style="gable", lift=0.9)
    for k in range(4):
        b.box("PAPER", (x0 + 2.5 + k * 4.4, y0 - 2.6, z1 + 5.5), (0.8, 0.8, 1.4), collide=False)
    return b


def chashitsu(name):
    """Casa del te' nel giardino: tetto di paglia, veranda, tokonoma, servizio da te', vasca
    di pietra (tsukubai) e pietre per arrivarci."""
    b = Builder(name)
    W, D = 10.0, 8.0
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    z = 1.6
    for sx in (-1, 0, 1):
        for sy in (-1, 1):
            b.box("STONE", (sx * (W / 2), sy * (D / 2), 0.5), (1.1, 1.1, 1.4), collide=False)
    slab(b, "WOOD", x0 - 1.8, x1 + 0.4, y0 - 1.8, y1 + 0.4, z, t=0.4)
    b.collider((0, 0, 0.6), (W + 2, D + 2, 1.0))
    b.box("STONE", (0, y0 - 2.8, 0.4), (2.0, 1.2, 0.8), collide=True)
    b.box("TATAMI", (0, 0, z + 0.06), (W - 0.6, D - 0.6, 0.12), collide=False)
    fr = ((x0, y0), (x1, y0))
    wall(b, "PLASTER", *fr, z, 7.0, 0.35, holes=[(3.2, 6.8, 0, 6.0)])
    opening_frame(b, *fr, 3.2, 6.8, z, 0, 6.0, sill=False)
    lattice(b, *fr, 3.2, 4.0, z, 0.2, 5.8, bars=(1, 4))
    for p, L in ((((x1, y0), (x1, y1)), D), (((x1, y1), (x0, y1)), W), (((x0, y1), (x0, y0)), D)):
        wall(b, "PLASTER", *p, z, 7.0, 0.35, holes=[(L / 2 - 1.2, L / 2 + 1.2, 2.4, 4.8)])
        window(b, *p, L / 2 - 1.2, L / 2 + 1.2, z, 2.4, 4.8, bars=(3, 2))
    posts_and_ties(b, x0, x1, y0, y1, z, 7.0, ties=(6.6,), out=0.2, doors=[("front", 3.2, 6.8, 6.0)])
    b.box("WOOD", (x0 + 1.4, y1 - 0.8, z + 0.25), (2.4, 1.2, 0.5), collide=False)
    b.box("CLOTH", (x0 + 1.4, y1 - 0.25, z + 3.4), (1.0, 0.06, 3.0), collide=False)
    jar(b, (x0 + 1.8, y1 - 0.8, z + 0.5), r=0.25, h=0.8)
    b.cyl("IRON", (1.0, 0.5, z), (1.0, 0.5, z + 0.9), 0.55, n=10)
    b.sphere("IRON", (1.0, 0.5, z + 1.2), 0.5, rz=0.4, seg=10, rings=5)
    teapot(b, (-0.6, 0.2, z))
    for s in (-1, 1):
        b.box("FABRIC", (-0.6 + s * 1.5, 0.2, z + 0.25), (1.2, 1.2, 0.3), collide=False)
    # vasca di pietra con il mestolo di bambu'
    b.cyl("STONE", (x0 - 3.0, y0 - 1.0, 0), (x0 - 3.0, y0 - 1.0, 1.2), 1.0, n=10, collide=True)
    b.cyl("STONEDARK", (x0 - 3.0, y0 - 1.0, 1.2), (x0 - 3.0, y0 - 1.0, 1.25), 0.7, n=10)
    b.cyl("BAMBOO", (x0 - 3.0, y0 - 1.0, 1.3), (x0 - 1.6, y0 - 1.0, 1.6), 0.08, n=5)
    for k in range(4):
        b.cyl("STONE", (x0 - 2.5 + k * 1.3, y0 - 3.2 - (k % 2) * 0.5, 0), (x0 - 2.5 + k * 1.3, y0 - 3.2 - (k % 2) * 0.5, 0.25), 0.55, n=8)
    roof(b, -0.7, -0.7, z + 7.0, W / 2 + 2.6, D / 2 + 2.6, 4.8, style="gable", lift=0.3, ug=0.5, mat="THATCH", ribs=False, t=1.0, tips=False, ridge=False, p=1.2)
    b.box("TIMBERDARK", (-0.7, -0.7, z + 12.0), (W * 0.4, 1.0, 0.6), collide=False)
    return b


def torre_tamburo(name):
    """Torre del tamburo: basamento di pietra col passaggio ad arco (ci si cammina sotto),
    scale sul fianco, padiglione di legno in cima col grande tamburo, doppio tetto."""
    b = Builder(name)
    W, D, HB = 22.0, 16.0, 10.0
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    # basamento: due blocchi coi lati del passaggio e la volta sopra
    for s in (-1, 1):
        b.box("STONE", (s * (W / 4 + 1.5), 0, HB / 2), (W / 2 - 3, D, HB), collide=True)
    rows = []
    for k in range(13):
        a = math.pi * k / 12
        rows.append([(3.0 * math.cos(a), yy, 6.0 + 3.0 * math.sin(a)) for yy in (y0, y1)])
    b.shell("STONEDARK", rows, 0.6)
    b.box("STONE", (0, 0, 8.0 + 1.0), (6.2, D, 2.0), collide=True)
    for s in (-1, 1):
        b.box("STONE", (s * 3.0, 0, 3.0), (0.2, D, 6.0), collide=False)
    slab(b, "STONE", x0, x1, y0, y1, HB, t=0.4)
    for (p0, p1) in (((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))):
        b.beam("STONE", (*p0, HB + 0.8), (*p1, HB + 0.8), 0.9, 1.6, collide=True)
    # scala sul fianco destro, contro il muro
    stairs(b, (x1 + 1.3, y0 - 0.5, 0), (0, 1), 2.4, HB, rise=1.0, tread=1.4, mat="STONE", rail=False)
    b.box("STONE", (x1 + 1.3, y1 + 0.6, HB / 2), (2.6, 2.0, HB), collide=True)
    # padiglione in cima
    px, py = W / 2 - 3.0, D / 2 - 2.5
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cyl("LACQUER", (sx * px, sy * py, HB), (sx * px, sy * py, HB + 9.0), 0.6, n=10, collide=True)
    for k in (-1, 0, 1):
        b.cyl("LACQUER", (k * px * 0.5, -py, HB), (k * px * 0.5, -py, HB + 9.0), 0.5, n=10, collide=True)
        b.cyl("LACQUER", (k * px * 0.5, py, HB), (k * px * 0.5, py, HB + 9.0), 0.5, n=10, collide=True)
    for (p0, p1) in (((-px, -py), (px, -py)), ((px, -py), (px, py)), ((px, py), (-px, py)), ((-px, py), (-px, -py))):
        railing(b, (*p0, HB), (*p1, HB), h=3.0, mat="LACQUER")
    # il grande tamburo sul suo cavalletto
    b.cyl("CLOTH", (0, -1.8, HB + 5.0), (0, 1.8, HB + 5.0), 3.2, n=20, collide=True)
    for s in (-1, 1):
        b.cyl("PLASTER", (0, s * 1.85, HB + 5.0), (0, s * 1.95, HB + 5.0), 3.0, n=20)
        b.cyl("GOLD", (0, s * 1.6, HB + 5.0), (0, s * 1.8, HB + 5.0), 3.35, n=20)
        b.box("TIMBERDARK", (s * 3.6, 0, HB + 3.5), (0.6, 0.6, 7.0), collide=False)
    b.box("TIMBERDARK", (0, 0, HB + 1.5), (8.0, 1.0, 0.6), collide=False)
    for s in (-1, 1):
        b.beam("TIMBER", (s * 1.5, -3.2, HB + 1.0), (s * 1.2, -2.2, HB + 4.6), 0.25, 0.25, collide=False)
        b.sphere("CLOTH", (s * 1.2, -2.1, HB + 4.8), 0.4, seg=6, rings=4)
    roof(b, 0, 0, HB + 9.0, px + 3.6, py + 3.6, 2.8, style="skirt", ug=0.38, lift=1.8, mat="SKIRT")
    b.box("LACQUER", (0, 0, HB + 11.0), (2 * px - 2, 2 * py - 2, 3.6), collide=False)
    roof(b, 0, 0, HB + 12.6, px + 2.6, py + 2.6, (py + 2.6) * 0.7, style="gable", lift=2.0, white=True)
    for s in (-1, 1):
        red_lantern(b, (s * 4.6, y0 - 0.4, 7.6), 1.1)
    return b


def granaio(name):
    """Granaio su palafitte (takakura): pali coi dischi di pietra contro i topi, scala a pioli,
    tetto di paglia; dentro i sacchi di riso."""
    b = Builder(name)
    W, D, Z = 9.0, 7.0, 4.5
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    for sx in (-1, 0, 1):
        for sy in (-1, 1):
            x, y = sx * (W / 2 - 0.5), sy * (D / 2 - 0.5)
            b.cyl("TIMBER", (x, y, 0), (x, y, Z), 0.4, n=8, collide=True)
            b.cyl("STONE", (x, y, Z - 1.2), (x, y, Z - 0.95), 0.95, n=12)
            b.cyl("STONE", (x, y, 0), (x, y, 0.5), 0.7, n=8)
    slab(b, "WOOD", x0, x1, y0, y1, Z, t=0.5)
    fr = ((x0, y0), (x1, y0))
    wall(b, "BAMBOO", *fr, Z, 6.0, 0.35, holes=[(3.2, 5.8, 0, 5.2)])
    opening_frame(b, *fr, 3.2, 5.8, Z, 0, 5.2, sill=False)
    for p in (((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))):
        wall(b, "BAMBOO", *p, Z, 6.0, 0.35)
    posts_and_ties(b, x0, x1, y0, y1, Z, 6.0, ties=(5.6,), out=0.3, doors=[("front", 3.2, 5.8, 5.2)])
    # scala a pioli (i pioli fanno da gradini)
    for k in range(6):
        zz = Z * (k + 0.5) / 6
        yy = y0 - 2.6 + (Z - zz) * 0.55
        b.box("WOOD", (0, yy, zz), (2.4, 0.6, 0.25), collide=True)
    for s in (-1, 1):
        b.beam("TIMBER", (s * 1.3, y0 - 2.6 - Z * 0.55, 0), (s * 1.3, y0 - 0.2, Z + 0.4), 0.3, 0.3, collide=False)
    for k in range(5):
        b.sphere("FABRIC" if k % 2 else "ROPE", (-2.5 + k * 1.2, 1.5, Z + 0.9), 0.75, rz=0.6, seg=8, rings=5)
    roof(b, 0, 0, Z + 6.0, W / 2 + 2.2, D / 2 + 2.2, 4.4, style="gable", lift=0.3, ug=0.5, mat="THATCH", ribs=False, t=1.0, tips=False, ridge=False, p=1.2)
    b.box("TIMBERDARK", (0, 0, Z + 10.6), (W * 0.5, 1.0, 0.5), collide=False)
    return b


def pescatore(name):
    """Capanna del pescatore sull'acqua: pontile su pali, capanna, reti stese, barca legata."""
    b = Builder(name)
    Z = 3.0
    for i in range(-3, 4):
        for j in (-2, 0, 2):
            b.cyl("TIMBERDARK", (i * 3.0, j * 3.0, -6.0), (i * 3.0, j * 3.0, Z), 0.35, n=6, collide=False)
    slab(b, "WOOD", -10, 10, -7, 7, Z, t=0.5)
    for (p0, p1) in (((-10, -7), (10, -7)), ((10, -7), (10, 7))):
        railing(b, (*p0, Z), (*p1, Z), h=2.6, lattice=False)
    hx0, hx1, hy0, hy1 = -9.0, -1.0, -1.0, 6.5
    fr = ((hx0, hy0), (hx1, hy0))
    wall(b, "BAMBOO", *fr, Z, 7.0, 0.3, holes=[(3.0, 5.6, 0, 6.0), (0.6, 2.4, 2.5, 4.5)])
    door_frame(b, *fr, 3.0, 5.6, Z, 6.0, leaves=False)
    window(b, *fr, 0.6, 2.4, Z, 2.5, 4.5, bars=(2, 2))
    for p in (((hx1, hy0), (hx1, hy1)), ((hx1, hy1), (hx0, hy1)), ((hx0, hy1), (hx0, hy0))):
        wall(b, "BAMBOO", *p, Z, 7.0, 0.3)
    roof(b, (hx0 + hx1) / 2, (hy0 + hy1) / 2, Z + 7.0, (hx1 - hx0) / 2 + 2.0, (hy1 - hy0) / 2 + 2.0, 3.6, style="gable", lift=0.8, mat="THATCH", ribs=False, t=0.9, tips=False, ridge=False, p=1.3)
    # reti stese su due pali
    for s in (3.0, 9.0):
        b.cyl("BAMBOO", (s, 5.5, Z), (s, 5.5, Z + 6.0), 0.15, n=6)
    for k in range(9):
        b.beam("ROPE", (3.0 + k * 0.75, 5.5, Z + 1.0), (3.0 + k * 0.75, 5.5, Z + 5.6), 0.05, 0.05, collide=False)
        b.beam("ROPE", (3.0, 5.5, Z + 1.0 + k * 0.55), (9.0, 5.5, Z + 1.0 + k * 0.55), 0.05, 0.05, collide=False)
    for k in range(3):
        jar(b, (2.0 + k * 1.3, -5.0, Z), r=0.5, h=1.0, mat="BAMBOO")
    red_lantern(b, (-1.5, -2.2, Z + 6.8), 0.8)
    # barca (sampan) legata accanto al pontile
    bx, by = 3.0, -10.5
    rows = []
    for i in range(9):
        t = i / 8
        x = bx - 7 + 14 * t
        wdt = 2.2 * math.sin(math.pi * t) ** 0.6 + 0.2
        lift = 0.6 * (2 * t - 1) ** 4
        rows.append([(x, by - wdt, 0.6 + lift), (x, by - wdt * 0.7, -0.4), (x, by + wdt * 0.7, -0.4), (x, by + wdt, 0.6 + lift)])
    b.shell("TIMBER", rows, 0.25)
    b.collider((bx, by, 0.1), (14, 4, 1.0))
    rows = [[(bx - 2.5 + 5 * k / 6, by + 2.0 * math.cos(math.pi * j / 6), 0.6 + 2.0 * math.sin(math.pi * j / 6)) for j in range(7)] for k in range(7)]
    b.shell("BAMBOO", rows, 0.15)
    b.beam("ROPE", (bx + 6.5, by + 0.5, 0.9), (6.0, -7.0, Z + 0.2), 0.08, 0.08, collide=False)
    return b


def bancarella(name):
    """Bancarella del mercato: telaio di legno, tettoia di stoffa, bancone con la merce, insegna."""
    b = Builder(name)
    W, D = 8.0, 4.5
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box("TIMBER", (sx * W / 2, sy * D / 2, 3.6 if sy > 0 else 3.0), (0.4, 0.4, 7.2 if sy > 0 else 6.0), collide=True)
    b.box("WOOD", (0, -0.6, 2.4), (W - 0.4, 2.2, 0.3), collide=True)
    b.box("TIMBER", (0, -0.6, 1.2), (W - 0.6, 2.0, 2.2), collide=True)
    # tettoia di stoffa a strisce, inclinata
    for k in range(6):
        x = -W / 2 + W * (k + 0.5) / 6
        b.beam("CLOTH" if k % 2 == 0 else "PLASTER", (x, D / 2 + 0.3, 7.3), (x, -D / 2 - 1.2, 5.6), W / 6, 0.12, collide=False)
    for k in range(7):
        x = -W / 2 + 0.6 + k * (W - 1.2) / 6
        b.box("CLOTH", (x, -D / 2 - 1.15, 5.25), (W / 7 - 0.1, 0.08, 0.7), collide=False)
    # merce: giare, cesti di frutta, panini al vapore
    for k in range(3):
        jar(b, (-2.8 + k * 0.9, -0.2, 2.55), r=0.35, h=0.9, mat="CERAMIC" if k % 2 else "BRONZE")
    for k in range(2):
        cx = 0.6 + k * 1.8
        b.cyl("BAMBOO", (cx, -0.6, 2.55), (cx, -0.6, 3.0), 0.75, n=12)
        for j in range(5):
            a = j / 5 * math.tau
            b.sphere("LANTERN" if k == 0 else "GOLD", (cx + math.cos(a) * 0.4, -0.6 + math.sin(a) * 0.4, 3.15), 0.28, seg=6, rings=5)
    b.box("SIGN", (0, -D / 2 - 0.3, 6.6), (4.0, 0.2, 0.9), collide=False)
    for s in (-1, 1):
        red_lantern(b, (s * (W / 2 - 0.3), -D / 2 - 0.3, 5.2), 0.7)
    b.box("TIMBER", (0, D / 2 - 0.4, 1.4), (2.0, 0.8, 2.8), collide=True)
    return b


def pozzo(name):
    b = Builder(name)
    for k in range(10):
        a = k / 10 * math.tau
        b.box("STONE", (math.cos(a) * 1.9, math.sin(a) * 1.9, 1.3), (1.3, 0.6, 2.6), rot=frame_of((-math.sin(a), math.cos(a), 0)), collide=True)
    b.cyl("STONEDARK", (0, 0, 0.0), (0, 0, 1.0), 1.6, n=14)
    for s in (-1, 1):
        b.box("TIMBER", (s * 2.3, 0, 3.8), (0.4, 0.4, 5.2), collide=False)
    b.cyl("TIMBER", (-2.5, 0, 5.4), (2.5, 0, 5.4), 0.25, n=8)
    b.cyl("ROPE", (-0.6, 0, 5.4), (0.6, 0, 5.4), 0.42, n=10)
    b.beam("ROPE", (0, 0, 5.1), (0, 0, 2.6), 0.08, 0.08, collide=False)
    b.cyl("WOOD", (0, 0, 2.0), (0, 0, 2.6), 0.45, n=10)
    roof(b, 0, 0, 6.6, 3.0, 1.7, 1.2, style="gable", lift=0.5, ug=0.5, ridge=False, ribs=True)
    return b


def emporio(name):
    """Emporio (il negozio): grande bottega a due piani col bancone lungo, scaffali coi
    minerali nelle casse, rastrelliera delle piccozze, insegna grande, galleria sopra."""
    b = Builder(name)
    W, D = 24.0, 16.0
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    z = 0.6
    H1 = 11.0
    b.box("STONE", (0, 0, -0.2), (W + 2, D + 2, 1.6), collide=True)
    for k in range(3):
        b.box("STONE", (0, y0 - 1.5 - k * 1.0, -0.1 - k * 0.4), (W * 0.6, 1.0, 0.8), collide=True)
    slab(b, "WOOD", x0, x1, y0, y1, z, t=0.3)
    for k in range(7):
        x = x0 + W * k / 6
        b.box("LACQUER", (x, y0, z + H1 / 2), (1.0, 1.0, H1), collide=True)
    wall(b, "TIMBER", (x0, y0), (x1, y0), z + 8.6, H1 - 8.6, 0.5, collide=False)
    b.box("SIGN", (0, y0 - 0.55, z + 9.8), (12.0, 0.3, 2.2), collide=False)
    for p in (((x1, y0), (x1, y1)), ((x0, y1), (x0, y0))):
        wall(b, "TIMBER", *p, z, H1, 0.5, holes=[(5.0, 11.0, 3.0, 7.2)])
        window(b, *p, 5.0, 11.0, z, 3.0, 7.2, bars=(7, 3))
    wall(b, "TIMBER", (x1, y1), (x0, y1), z, H1, 0.5)
    posts_and_ties(b, x0, x1, y0, y1, z - 0.3, H1 + 0.3, ties=(8.4,), every=4.0)
    # bancone lungo con la bilancia e il pallottoliere
    b.box("TIMBER", (0, -2.0, z + 1.6), (14.0, 1.6, 3.2), collide=True)
    b.box("WOOD", (0, -2.0, z + 3.3), (14.6, 2.0, 0.25), collide=False)
    b.cyl("BRONZE", (-4.0, -2.0, z + 3.4), (-4.0, -2.0, z + 5.2), 0.1, n=6)
    b.beam("BRONZE", (-5.2, -2.0, z + 5.2), (-2.8, -2.0, z + 5.2), 0.12, 0.12, collide=False)
    for s in (-1, 1):
        b.cyl("BRONZE", (-4.0 + s * 1.2, -2.0, z + 4.2), (-4.0 + s * 1.2, -2.0, z + 4.3), 0.55, n=10)
    b.box("TIMBER", (3.0, -2.0, z + 3.7), (2.0, 1.2, 0.6), collide=False)
    for r in range(4):
        b.beam("IRON", (2.1, -2.0, z + 3.55 + r * 0.12), (3.9, -2.0, z + 3.55 + r * 0.12), 0.04, 0.04, collide=False)
    # casse coi minerali (in Studio ogni cassa prende il colore del suo minerale)
    for k in range(5):
        cx = -9.0 + k * 4.5
        b.box("WOOD", (cx, y1 - 2.0, z + 0.9), (3.0, 2.0, 1.8), collide=True)
        for j in range(5):
            b.sphere("CRYSTAL" if k >= 2 else ("IRON" if k == 0 else "GOLD"), (cx - 0.9 + (j % 3) * 0.9, y1 - 2.0 + (j // 3) * 0.6 - 0.3, z + 1.9), 0.42, seg=6, rings=4)
    shelf(b, (-6.0, y1 - 0.8, z + 2.0), w=8.0, h=6.0)
    shelf(b, (6.0, y1 - 0.8, z + 2.0), w=8.0, h=6.0)
    # rastrelliera delle piccozze e rotoli di corda sul muro di sinistra
    b.box("TIMBERDARK", (x0 + 0.5, 0, z + 5.5), (0.3, 6.0, 0.4), collide=False)
    for k in range(4):
        y = -2.2 + k * 1.5
        b.cyl("WOOD", (x0 + 0.7, y, z + 2.0), (x0 + 0.7, y, z + 5.8), 0.12, n=6)
        b.beam("METAL", (x0 + 0.7, y - 0.8, z + 5.6), (x0 + 0.7, y + 0.6, z + 6.0), 0.15, 0.35, collide=False)
    for k in range(2):
        b.tube("ROPE", [(x0 + 0.8, 4.0 + k * 1.6 + 0.8 * math.cos(a / 8 * math.tau), z + 4.0 + 0.8 * math.sin(a / 8 * math.tau)) for a in range(9)], 0.18, n=5)
    stairs(b, (x1 - 1.6, y0 + 2.0, z), (0, 1), 2.4, H1, rise=1.0, tread=1.0)
    for k in range(3):
        red_lantern(b, (-6 + k * 6, -4.0, z + H1 - 0.6), 1.0)
    # piano di sopra: galleria con la panchina, magazzino dietro le grate
    z1 = z + H1
    slab(b, "WOOD", x0, x1, y0 - 0.5, y1, z1, t=0.5, hole=(x1 - 2.85, x1 - 0.35, y0 + 5.2, y1 - 0.3))
    railing(b, (x0 - 0.2, y0 - 0.5, z1), (x1 + 0.2, y0 - 0.5, z1), bench=True)
    ya = y0 + 3.0
    H2 = 8.0
    wall(b, "PLASTER", (x0, ya), (x1, ya), z1, H2, 0.4, holes=[(2, 7, 0, 7.0), (9.5, 14.5, 0, 7.0), (17, 22, 0, 7.0)])
    for s0 in (2, 9.5, 17):
        opening_frame(b, (x0, ya), (x1, ya), s0, s0 + 5, z1, 0, 7.0, sill=False)
        lattice(b, (x0, ya), (x1, ya), s0, s0 + 1.4, z1, 0.2, 6.8, bars=(2, 6))
    for p in (((x1, y0 - 0.5), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0 - 0.5))):
        wall(b, "PLASTER", *p, z1, H2, 0.4)
    for k in range(7):
        b.box("LACQUER", (x0 + W * k / 6, y0 - 0.5, z1 + H2 / 2), (0.7, 0.7, H2), collide=False)
    for k in range(4):
        b.box("WOOD", (-8 + k * 3.5, y1 - 2.5, z1 + 1.0), (2.4, 2.4, 2.0), collide=True)
    for k in range(4):
        b.box("CLOTH", (x0 + 3 + k * 6, y0 - 0.9, z1 + 4.6), (1.2, 0.08, 4.0), collide=False)
    roof(b, 0, 0, z1 - 0.5, W / 2 + 3.0, D / 2 + 3.4, 2.8, style="skirt", ug=0.34, mat="SKIRT")
    roof(b, 0, -0.2, z1 + H2, W / 2 + 3.2, D / 2 + 3.6, (D / 2 + 3.6) * 0.62, style="gable", white=True)
    for k in range(7):
        red_lantern(b, (x0 + W * k / 6, y0 - 0.9, z1 + H2 - 0.5), 1.0)
    return b


# =======================================================================================
# isole volanti e nuvole

def crystal(b, base, direction, length, radius, mat="CRYSTAL", sides=6):
    """Prisma esagonale con la punta: base, direzione, lunghezza, raggio."""
    base = Vector(base)
    d = Vector(direction).normalized()
    R = frame_of(d)
    a, c = R.col[0], R.col[2]
    ring0 = [base + (a * math.cos(k / sides * math.tau) + c * math.sin(k / sides * math.tau)) * radius for k in range(sides)]
    top = base + d * length * 0.78
    ring1 = [p + d * length * 0.78 for p in ring0]
    tip = base + d * length
    verts = ring0 + ring1 + [tip]
    faces = [(k, (k + 1) % sides, sides + (k + 1) % sides, sides + k) for k in range(sides)]
    faces += [(sides + k, sides + (k + 1) % sides, 2 * sides) for k in range(sides)]
    faces.append(tuple(reversed(range(sides))))
    b.face_list(mat, verts, faces)



def rock_lump(b, center, r, seed, mat="ROCK", squash=0.7):
    """Masso irregolare (sfera deformata)."""
    import random
    rnd = random.Random(seed)
    c = Vector(center)
    seg, rings = 10, 7
    noise = {}
    verts = [c + Vector((0, 0, -r * squash))]
    for i in range(1, rings):
        phi = -math.pi / 2 + math.pi * i / rings
        for k in range(seg):
            t = k / seg * math.tau
            f = 0.75 + rnd.random() * 0.45
            verts.append(c + Vector((math.cos(t) * math.cos(phi) * r * f, math.sin(t) * math.cos(phi) * r * f, math.sin(phi) * r * squash * f)))
    verts.append(c + Vector((0, 0, r * squash)))
    faces = [(0, 1 + (k + 1) % seg, 1 + k) for k in range(seg)]
    for i in range(rings - 2):
        a0, a1 = 1 + i * seg, 1 + (i + 1) * seg
        for k in range(seg):
            faces.append((a0 + k, a0 + (k + 1) % seg, a1 + (k + 1) % seg, a1 + k))
    top = len(verts) - 1
    last = 1 + (rings - 2) * seg
    faces += [(last + k, last + (k + 1) % seg, top) for k in range(seg)]
    b.face_list(mat, verts, faces)


def isola(name, R, seed):
    """Isola volante: cima di prato irregolare, roccia sotto a cono rovesciato con le punte,
    massi sopra. R = raggio della cima. In Roblox roccia e prato usano i materiali di Roblox."""
    import random
    rnd = random.Random(seed)
    b = Builder(name)
    nseg = 28
    prof = [0.85 + 0.25 * math.sin(k * 0.9 + seed) * 0.6 + rnd.random() * 0.18 for k in range(nseg)]

    def edge(k, scale=1.0, z=0.0):
        a = k / nseg * math.tau
        r = R * prof[k % nseg] * scale
        return (math.cos(a) * r, math.sin(a) * r, z)

    # prato in cima (cupola bassa) e il bordo di terra
    rows = []
    for i in range(6):
        s = 1.0 - i / 5
        rows.append([edge(k, s, R * 0.06 * (1 - s * s) + 0.3) for k in range(nseg + 1)])
    rows = [r for r in reversed(rows)]
    top = []
    for i in range(6):
        s = i / 5
        top.append([(x * 1.0, y * 1.0, z) for (x, y, z) in [edge(k, max(s, 0.001), R * 0.06 * (1 - s * s) + 0.3) for k in range(nseg + 1)]])
    b.shell("GRASS", top, 0.6)
    # roccia sotto: anelli che si stringono verso il basso, con qualche punta
    rows = []
    depth = R * 1.25
    for i in range(9):
        t = i / 8
        s = (1 - t) ** 1.25 * 1.02
        z = -depth * t
        row = []
        for k in range(nseg + 1):
            jit = 1 + (rnd.random() - 0.5) * 0.18 * (1 - t)
            x, y, _ = edge(k, max(s * jit, 0.02), z)
            row.append((x, y, z + (rnd.random() - 0.5) * R * 0.04))
        rows.append(row)
    b.shell("ROCK", rows, 1.2)
    for k in range(5):
        a = rnd.random() * math.tau
        rr = R * (0.2 + rnd.random() * 0.45)
        L = R * (0.3 + rnd.random() * 0.35)
        z0 = -depth * (0.35 + rnd.random() * 0.25)
        crystal(b, (math.cos(a) * rr, math.sin(a) * rr, z0 + L * 0.2), (0, 0, -1), L, R * 0.09, mat="ROCK", sides=6)
    # qualche masso sopra (niente alberelli: Mirko non li vuole)
    for k in range(int(R / 4) + 2):
        a = rnd.random() * math.tau
        rr = R * rnd.random() * 0.7
        rock_lump(b, (math.cos(a) * rr, math.sin(a) * rr, 0.7), 0.8 + rnd.random() * 1.4, seed * 10 + k, squash=0.6)
    return b


def nuvola(name, seed, size):
    """Cumulo: una base di sbuffi larghi e schiacciati, sopra sbuffi piu' piccoli che salgono
    verso il centro; la pancia e' piatta (i vertici sotto lo zero si schiacciano)."""
    import random
    rnd = random.Random(seed)
    b = Builder(name)
    n = 8 + seed % 4
    for k in range(n):  # base
        t = k / (n - 1) - 0.5
        x = t * size * 1.7 + (rnd.random() - 0.5) * size * 0.15
        y = (rnd.random() - 0.5) * size * 0.55
        r = size * (0.26 + rnd.random() * 0.12) * (1 - abs(t) * 0.6)
        b.sphere("CLOUD", (x, y, r * 0.25), r, rz=r * 0.7, seg=18, rings=11)
    m = 4 + seed % 3
    for k in range(m):  # sbuffi alti
        t = k / max(m - 1, 1) - 0.5
        x = t * size * 0.9 + (rnd.random() - 0.5) * size * 0.2
        y = (rnd.random() - 0.5) * size * 0.3
        r = size * (0.2 + rnd.random() * 0.12) * (1 - abs(t) * 0.7)
        b.sphere("CLOUD", (x, y, size * 0.22 * (1 - abs(t)) + r * 0.45), r, rz=r * 0.85, seg=18, rings=11)
    vs, _ = b.geo["CLOUD"]
    for v in vs:
        if v.z < 0:
            v.z *= 0.12
    b.remesh["CLOUD"] = size / 28
    return b


MODELS.update({
    "Kura": lambda: kura("Kura"),
    "Ryokan": lambda: ryokan("Ryokan"),
    "Chashitsu": lambda: chashitsu("Chashitsu"),
    "TorreTamburo": lambda: torre_tamburo("TorreTamburo"),
    "Granaio": lambda: granaio("Granaio"),
    "Pescatore": lambda: pescatore("Pescatore"),
    "Bancarella": lambda: bancarella("Bancarella"),
    "Pozzo": lambda: pozzo("Pozzo"),
    "Emporio": lambda: emporio("Emporio"),
    "IsolaPiccola": lambda: isola("IsolaPiccola", 14, 3),
    "IsolaMedia": lambda: isola("IsolaMedia", 24, 7),
    "IsolaGrande": lambda: isola("IsolaGrande", 38, 11),
    "NuvolaA": lambda: nuvola("NuvolaA", 1, 26),
    "NuvolaB": lambda: nuvola("NuvolaB", 2, 40),
    "NuvolaC": lambda: nuvola("NuvolaC", 3, 18),
    "NuvolaD": lambda: nuvola("NuvolaD", 4, 55),
})
# da Blender (x, y, z; davanti -Y, su +Z) al pivot di Roblox (davanti -Z, su +Y, destra +X)
T = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))


def _num(v):
    if abs(v) < 1e-6:
        return "0"
    return ("%.3f" % v).rstrip("0").rstrip(".")


def write_colliders(builders, path):
    lines = ["--!strict", "-- GENERATO da tools/blender/borghi.py: non modificare a mano.",
             "-- Scatole di collisione dei modelli dei borghi nel sistema del pivot del modello (davanti -Z,",
             "-- su +Y): { cx, cy, cz, sx, sy, sz, X.x, X.y, X.z, Y.x, Y.y, Y.z, Z.x, Z.y, Z.z } (posizione,",
             "-- misure e assi della scatola). BorghiKit le trasforma in Part invisibili.", "", "return {"]
    for b in builders:
        lines.append("\t%s = {" % b.name)
        for c, s, R in b.colliders:
            p = T @ c
            vx = T @ R.col[0]
            vy = T @ R.col[2]
            vz = -(T @ R.col[1])
            vals = [p.x, p.y, p.z, s[0], s[2], s[1], vx.x, vx.y, vx.z, vy.x, vy.y, vy.z, vz.x, vz.y, vz.z]
            lines.append("\t\t{ " + ", ".join(_num(v) for v in vals) + " },")
        lines.append("\t},")
    lines.append("} :: { [string]: { { number } } }")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def setup_render(out_png, target, view=(0.55, -0.8, 0.38), scale=1.1):
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 900
    scene.render.resolution_y = 650
    scene.render.filepath = out_png
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for ob in target.children:
        if ob.hide_render:
            continue
        for v in ob.bound_box:
            w = ob.matrix_world @ Vector(v)
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    c = (lo + hi) / 2
    size = (hi - lo).length
    cam = bpy.data.objects.get("BorghiCam") or bpy.data.objects.new("BorghiCam", bpy.data.cameras.new("BorghiCam"))
    if cam.name not in scene.collection.objects:
        scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = c + Vector(view).normalized() * size * scale
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 40
    bpy.ops.render.render(write_still=True)


def build_all(only=None, render_dir=None, export=False):
    made = borghi_lib.prepare_textures(os.path.normpath(os.path.join(HERE, "..", "..", "textures")), os.path.join(HERE, "out", "tex"))
    if made:
        print("[borghi] texture preparate:", made)
    # una scena tutta per i borghi: nel Blender aperto non si tocca il resto
    scene = bpy.data.scenes.get("Borghi") or bpy.data.scenes.new("Borghi")
    if bpy.context.window:
        bpy.context.window.scene = scene
    coll = bpy.data.collections.get("BorghiModelli")
    if coll:
        for ob in list(coll.objects):
            bpy.data.objects.remove(ob, do_unlink=True)
    else:
        coll = bpy.data.collections.new("BorghiModelli")
    if coll.name not in scene.collection.children:
        scene.collection.children.link(coll)
    builders, roots = [], []
    cols = 4
    for name, make in MODELS.items():
        if only and name not in only.split(","):
            continue
        b = make()
        k = len(builders)
        roots.append(b.build(coll, at=((k % cols) * 80.0, (k // cols) * 80.0, 0)))
        builders.append(b)
    if render_dir:
        if bpy.context.window is None:
            bpy.context.window_manager  # senza finestra: la scena attiva e' quella del contesto
        os.makedirs(render_dir, exist_ok=True)
        old = bpy.context.scene
        for root in roots:
            for r in roots:
                for ch in r.children:
                    ch.hide_render = (r is not root) or ch.name.endswith(("__FRONT", "__ORIGIN"))
            setup_render(os.path.join(render_dir, root.name + ".png"), root)
            setup_render(os.path.join(render_dir, root.name + "_dietro.png"), root, view=(-0.6, 0.75, 0.45))
        for r in roots:
            for ch in r.children:
                ch.hide_render = ch.name.endswith(("__FRONT", "__ORIGIN"))
    if export:
        out = os.path.join(HERE, "out")
        os.makedirs(out, exist_ok=True)
        saved = [r.location.copy() for r in roots]
        for r in roots:
            r.location = (0, 0, 0)  # nel file ogni modello sta all'origine
        bpy.context.view_layer.update()
        for ob in scene.objects:
            ob.select_set(False)
        for r in roots:
            r.select_set(True)
            for ch in r.children:
                ch.select_set(True)
        # tutti i modelli: borghi.fbx; con --only solo quelli scelti, in aggiornamento.fbx (da importare
        # sopra il resto: BorghiKit.prepare() sostituisce solo i modelli con lo stesso nome)
        fbx = "aggiornamento.fbx" if only else "borghi.fbx"
        bpy.ops.export_scene.fbx(filepath=os.path.join(out, fbx), use_selection=True, object_types={"EMPTY", "MESH"}, path_mode="STRIP",
                                 apply_scale_options="FBX_SCALE_UNITS", axis_forward="-Z", axis_up="Y",
                                 mesh_smooth_type="FACE", add_leaf_bones=False)
        for r, loc in zip(roots, saved):
            r.location = loc
        if not only:
            write_colliders(builders, os.path.normpath(os.path.join(HERE, "..", "..", "src", "mapgen", "BorghiCollide.luau")))
    tris = {b.name: sum(len(f) - 2 for _, fs in b.geo.values() for f in fs) for b in builders}
    print("[borghi] triangoli:", tris)
    print("[borghi] collisioni:", {b.name: len(b.colliders) for b in builders})
    return roots


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = argv[argv.index("--only") + 1] if "--only" in argv else None
    render_dir = os.path.join(HERE, "out", "anteprime") if "--render" in argv else None
    build_all(only=only, render_dir=render_dir, export="--export" in argv)


if __name__ == "__main__":
    main()
