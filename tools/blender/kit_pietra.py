# Kit di pietra per i modelli della sessione cloud (Isola dei Draghi, santuari, basi...):
# muri a blocchi squadrati veri (ogni concio e' un blocco smussato, sfalsato, un po' storto,
# qualcuno manca o e' rotto), archi a conci con la chiave, semicolonne con base e capitello,
# cornici a tratti, merli (anche rotti), lastre di pavimento. Ogni blocco porta nell'attributo
# "Tinta" (colore dei vertici) un numero a caso: la cottura dei materiali lo usa per variare il
# colore blocco per blocco.

import math
import random

import bmesh
from mathutils import Matrix, Vector

import cloud_lib as L


def _block(p, c, s, rot, bev, tint, chip=0.0, rng=None):
    """un concio: scatola smussata; chip > 0 smussa di piu' uno spigolo a caso (pietra scheggiata)"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.transform(Matrix.Diagonal((s[0], s[1], s[2], 1)))
    b = min(bev, min(s) * 0.3)
    if b > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=b, segments=1, affect="EDGES", profile=0.5)
    if chip > 0 and rng is not None:
        # sposta verso l'interno i vertici vicini a un angolo a caso (scheggiatura)
        corner = Vector((rng.choice((-1, 1)) * s[0] / 2, rng.choice((-1, 1)) * s[1] / 2, rng.choice((-1, 1)) * s[2] / 2))
        for v in bm.verts:
            d = (v.co - corner).length
            lim = min(s) * chip
            if d < lim:
                v.co = v.co + (Vector((0, 0, 0)) - v.co).normalized() * (lim - d) * 0.6
    M = L.mat4(c, rot)
    bm.transform(M)
    base = len(p.v)
    bm.verts.index_update()
    p.v.extend(tuple(v.co) for v in bm.verts)
    for f in bm.faces:
        p.f.append(([base + l.vert.index for l in f.loops], False, None))
    if not hasattr(p, "tint"):
        p.tint = []
    p.tint.extend([tint] * len(bm.verts))
    bm.free()


def tint_fill(p):
    """allinea la tinta ai vertici aggiunti senza _block (0.5 = neutro)"""
    if not hasattr(p, "tint"):
        p.tint = []
    if len(p.tint) < len(p.v):
        p.tint.extend([0.5] * (len(p.v) - len(p.tint)))


def ashlar(p, M, x0, x1, z0, z1, rng, course=1.0, depth=0.5, bev=0.06, jitter=0.03, missing=0.0, chip=0.25,
           lmin=1.2, lmax=2.6, face_y=0.0, clip=None):
    """parete di conci nel piano XZ del sistema M (la faccia guarda -Y, sta a y = face_y):
    filari alti course, lunghi fra lmin e lmax volte course, giunti sfalsati.
    clip(x, z) -> False per saltare un concio (aperture)."""
    tint_fill(p)
    rows = max(1, round((z1 - z0) / course))
    h = (z1 - z0) / rows
    R3 = M.to_3x3()
    for r in range(rows):
        zc = z0 + (r + 0.5) * h
        x = x0 - rng.uniform(0, lmax * h * 0.5) if r % 2 else x0
        while x < x1 - 0.05:
            ln = rng.uniform(lmin, lmax) * h
            a, b = max(x, x0), min(x + ln, x1)
            x += ln
            if b - a < 0.25 * h:
                continue
            cx = (a + b) / 2
            if clip and not clip(cx, zc):
                continue
            if rng.random() < missing:
                continue
            out = rng.uniform(-jitter, jitter)
            tilt = Matrix.Rotation(rng.uniform(-0.012, 0.012), 3, "Y") @ Matrix.Rotation(rng.uniform(-0.008, 0.008), 3, "Z")
            c = M @ Vector((cx, face_y + depth / 2 - out, zc))
            _block(p, c, (b - a - 0.02, depth, h - 0.02), R3 @ tilt, bev, rng.random(),
                   chip=chip if rng.random() < 0.35 else 0.0, rng=rng)


def hull_block(p, pts, M, bev, tint):
    """blocco convesso dai suoi vertici (inviluppo), smussato"""
    bm = bmesh.new()
    for q in pts:
        bm.verts.new(q)
    bmesh.ops.convex_hull(bm, input=bm.verts[:])
    bmesh.ops.dissolve_limit(bm, angle_limit=0.01, verts=bm.verts[:], edges=bm.edges[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if bev > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bev, segments=1, affect="EDGES")
    bm.transform(M)
    base = len(p.v)
    bm.verts.index_update()
    p.v.extend(tuple(v.co) for v in bm.verts)
    for fc in bm.faces:
        p.f.append(([base + l.vert.index for l in fc.loops], False, None))
    tint_fill(p)
    p.tint[base:] = [tint] * (len(p.v) - base)
    bm.free()


def arch(p, M, cx, zs, r_in, r_out, y0, y1, rng, n=13, bev=0.06, key=1.25):
    """arco a tutto sesto di conci (cuneo per cuneo) nel piano XZ di M, da y0 (davanti) a y1;
    centro (cx, zs); la chiave e' piu' alta e sporge"""
    tint_fill(p)
    gap = 0.01
    for i in range(n):
        a0 = math.pi - math.pi * i / n - gap
        a1 = math.pi - math.pi * (i + 1) / n + gap
        k = i == n // 2
        ro = r_out * (key if k else 1.0)
        ya = y0 - (0.15 if k else 0.0)
        pts = []
        for a in (a0, a1):
            for rr in (r_in, ro):
                for yy in (ya, y1):
                    pts.append((cx + rr * math.cos(a), yy, zs + rr * math.sin(a)))
        hull_block(p, pts, M, bev, rng.random())


def half_column(p, M, x, y, z0, z1, r, seg=10):
    """semicolonna addossata (verso -Y) con base e capitello"""
    tint_fill(p)
    prof = [(r * 1.35, z0), (r * 1.35, z0 + 0.25), (r * 1.15, z0 + 0.4), (r * 1.22, z0 + 0.55), (r, z0 + 0.75),
            (r, z1 - 0.9), (r * 1.1, z1 - 0.75), (r * 1.1, z1 - 0.6), (r * 1.45, z1 - 0.3), (r * 1.5, z1)]
    L.lathe(p, prof, seg, (0, 0, 0), math.pi, 2 * math.pi, M=M @ Matrix.Translation((x, y, 0)))
    tint_fill(p)


def cornice(p, M, x0, x1, z, prof, rng, seg_len=3.0, y=0.0):
    """cornice a tratti (blocchi lunghi seg_len con giunti), profilo [(sporgenza, dz)]"""
    tint_fill(p)
    x = x0
    while x < x1 - 0.1:
        b = min(x + seg_len * rng.uniform(0.8, 1.2), x1)
        n0 = len(p.v)
        L.cornice(p, [(sp, z + dz) for sp, dz in prof], x + 0.015, b - 0.015, M @ Matrix.Translation((0, y, 0)))
        p.tint.extend([rng.random()] * (len(p.v) - n0))
        x = b


def merlons(p, M, x0, x1, z, rng, w=1.6, gap=1.1, h=2.2, depth=1.6, y=0.0, broken=0.15):
    """merli; qualcuno rotto (piu' basso e scheggiato) o mancante"""
    tint_fill(p)
    x = x0 + gap / 2
    while x + w <= x1:
        r = rng.random()
        if r < broken * 0.3:
            x += w + gap
            continue
        hh = h * (rng.uniform(0.35, 0.7) if r < broken else rng.uniform(0.95, 1.05))
        _block(p, M @ Vector((x + w / 2, y + depth / 2, z + hh / 2)), (w, depth, hh), M.to_3x3(), 0.08, rng.random(),
               chip=0.5 if r < broken else 0.2, rng=rng)
        x += w + gap


