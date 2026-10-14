# Forme organiche fatte bene da codice (tronchi, rami, radici, rocce): sezioni ad alta risoluzione
# deformate dal rumore (nodi, solchi della corteccia, torsione, radici a contrafforte), poi
# ridotte al budget. Le UV sono cilindriche (corteccia continua) e i tagli hanno la UV centrata
# per il materiale LegnoTaglio (anelli).

import math
import random

from mathutils import Vector
from mathutils import noise as MN

import cloud_lib as L


def _n(q, s, octv=3):
    return MN.fractal(Vector(q) * s, 0.6, 2.0, octv, noise_basis="PERLIN_ORIGINAL")


def tronco(p, pts, radii, seed=0, nseg=20, sub=3, bark=0.03, knots=(), flare=0.0, flare_lobes=5, tile=2.0,
           twist=0.6, cap_part=None, cap_top=True, cap_bottom=False, flare_pow=6):
    """tronco (o ramo) lungo pts (Catmull-Rom), raggi radii per punto.
    knots: [(t, angolo, ampiezza, larghezza)] gonfiori dei nodi; flare: radici a contrafforte alla base.
    cap_part: parte (LegnoTaglio) dove mettere il taglio netto in cima"""
    rnd = random.Random(seed)
    path = L.smooth_path(pts, sub)
    m = len(path)
    # raggi interpolati sul percorso lisciato
    rr = []
    for i in range(m):
        u = i / (m - 1) * (len(radii) - 1)
        k = min(int(u), len(radii) - 2)
        f = u - k
        rr.append(radii[k] * (1 - f) + radii[k + 1] * f)
    P, T, N, B = L.frames(path)
    off = Vector((rnd.uniform(0, 50), rnd.uniform(0, 50), rnd.uniform(0, 50)))
    verts, uvs_v = [], []
    length = 0.0
    for i in range(m):
        if i:
            length += (P[i] - P[i - 1]).length
        t = i / (m - 1)
        ring = []
        for j in range(nseg + 1):
            a = 2 * math.pi * j / nseg
            aa = a + twist * t * 2 * math.pi * 0.25
            d = N[i] * math.cos(a) + B[i] * math.sin(a)
            r = rr[i]
            # solchi della corteccia (rumore stirato lungo l'asse) e bozzi grandi
            q = off + Vector((math.cos(aa) * 3.0, math.sin(aa) * 3.0, length * 0.35))
            r *= 1.0 + bark / max(rr[i], 0.05) * _n(q, 1.0) + 0.12 * _n(off + Vector((math.cos(a), math.sin(a), length * 0.15)), 1.3)
            for (kt, ka, kamp, kw) in knots:
                da = math.atan2(math.sin(a - ka), math.cos(a - ka))
                r *= 1.0 + kamp * math.exp(-(da / kw) ** 2 - ((t - kt) / (kw * 0.25)) ** 2)
            if flare > 0:
                lobe = max(0.0, math.cos(flare_lobes * a + 0.7)) ** 2
                r *= 1.0 + flare * lobe * (1 - t) ** flare_pow
            ring.append(tuple(P[i] + d * r))
            uvs_v.append((j / nseg * 2 * math.pi * rr[0] / tile, length / tile))
        verts.extend(ring)
    base = len(p.v)
    p.v.extend(verts)
    w = nseg + 1
    for i in range(m - 1):
        for j in range(nseg):
            a, b = i * w + j, i * w + j + 1
            idx = [a, b, b + w, a + w]
            p.f.append(([base + x for x in idx], True, [uvs_v[x] for x in idx]))
    caps = []
    if cap_top:
        caps.append((m - 1, False))
    if cap_bottom:
        caps.append((0, True))
    for i, rev in caps:
        tgt = cap_part or p
        ring = [Vector(verts[i * w + j]) for j in range(nseg)]
        c = sum(ring, Vector()) / nseg
        rmax = max((q - c).length for q in ring)
        b0 = len(tgt.v)
        tgt.v.append(tuple(c))
        tgt.v.extend(tuple(q) for q in ring)
        for j in range(nseg):
            j2 = (j + 1) % nseg
            uv = [(0.5, 0.5)]
            for jj in (j, j2):
                d = ring[jj] - c
                ang = 2 * math.pi * jj / nseg
                rl = d.length / rmax * 0.47
                uv.append((0.5 + rl * math.cos(ang), 0.5 + rl * math.sin(ang)))
            f = [b0, b0 + 1 + j, b0 + 1 + j2]
            if rev:
                f, uv = f[::-1], uv[::-1]
            tgt.f.append((f, False, uv))
    return P, rr


def roccia(p, c, size, seed=0, res=10, crag=0.35, flat_bottom=True, strata=0.0, up=(0, 0, 1), cuts=9):
    """masso di granito: sfera deformata dal rumore e tagliata da piani a caso (facce di frattura
    piatte, spigoli vivi), base piatta; strata > 0 aggiunge cenge orizzontali"""
    rnd = random.Random(seed)
    off = Vector((rnd.uniform(0, 99), rnd.uniform(0, 99), rnd.uniform(0, 99)))
    c = Vector(c)
    sx, sy, sz = size
    planes = []
    for _ in range(cuts):
        n = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.5, 1))).normalized()
        planes.append((n, rnd.uniform(0.72, 0.9)))
    verts, faces = [], []
    nu, nv = res * 2, res
    for iv in range(nv + 1):
        v = iv / nv
        th = math.pi * v
        for iu in range(nu):
            ph = 2 * math.pi * iu / nu
            d = Vector((math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)))
            k = 1.0 + crag * 0.5 * _n(off + d * 1.2, 1.0, 5) + 0.05 * _n(off + d * 6.0, 1.0)
            q = d * k
            for (n, dd) in planes:          # fratture: tutto cio' che sporge oltre il piano ci finisce sopra
                e = q.dot(n) - dd
                if e > 0:
                    q = q - n * e
            q = Vector((q.x * sx / 2, q.y * sy / 2, q.z * sz / 2))
            if strata:
                q.x *= 1 + strata * math.sin(q.z * 9.0 / max(sz, 0.1))
                q.y *= 1 + strata * math.sin(q.z * 9.0 / max(sz, 0.1))
            if flat_bottom and q.z < -sz * 0.3:
                q.z = -sz * 0.3 + (q.z + sz * 0.3) * 0.1
            verts.append(tuple(c + q))
    for iv in range(nv):
        for iu in range(nu):
            iu2 = (iu + 1) % nu
            a, b = iv * nu + iu, iv * nu + iu2
            faces.append([a, a + nu, b + nu, b])
    p.add_raw(verts, faces, smooth=True)


def loft(p, M, prof, n=12, tile=None, caps=True):
    """corpo affusolato lungo X nel sistema M: prof = [(x, semilarghezza y, semialtezza z, dz)] ;
    sezioni ellittiche (pesci, pezzi di carne, ossa). UV: u lungo X, v attorno"""
    verts, uvs = [], []
    L0 = prof[-1][0] - prof[0][0]
    for (x, ry, rz, dz) in prof:
        for j in range(n + 1):
            a = 2 * math.pi * j / n
            verts.append(tuple(M @ Vector((x, ry * math.cos(a), dz + rz * math.sin(a)))))
            uvs.append(((x - prof[0][0]) / (tile or L0), j / n))
    base = len(p.v)
    p.v.extend(verts)
    w = n + 1
    for i in range(len(prof) - 1):
        for j in range(n):
            idx = [i * w + j, (i + 1) * w + j, (i + 1) * w + j + 1, i * w + j + 1]
            p.f.append(([base + q for q in idx], True, [uvs[q] for q in idx]))
    if caps:
        for i, rev in ((0, True), (len(prof) - 1, False)):
            if prof[i][1] < 1e-4:
                continue
            ring = [base + i * w + j for j in range(n)]
            p.f.append((ring[::-1] if rev else ring, False, [uvs[q - base] for q in (ring[::-1] if rev else ring)]))


def pinna(p, M, pts, th=0.01):
    """pinna sottile (poligono nel piano XZ di M, spessore th)"""
    L.prism(p, [(x, z) for x, z in pts], -th, th, M @ Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1))))


from mathutils import Matrix  # noqa: E402


def neve_sopra(p_src, p_neve, first_vert, first_face, soglia=0.5, spessore=0.06, rng=None):
    """copia come neve le facce rivolte in su (normale z > soglia) della parte p_src aggiunte da
    first_face in poi, alzate di spessore lungo la normale media; bordo irregolare"""
    faces = p_src.f[first_face:]
    vn = {}
    keep = []
    for (idx, sm, uv) in faces:
        pts = [Vector(p_src.v[i]) for i in idx]
        nrm = (pts[1] - pts[0]).cross(pts[2] - pts[0])
        if len(pts) > 3:
            nrm = nrm + (pts[2] - pts[0]).cross(pts[3] - pts[0])
        if nrm.length < 1e-9:
            continue
        nrm.normalize()
        cz = sum((q.z for q in pts)) / len(pts)
        if nrm.z > soglia:
            keep.append(idx)
            for i in idx:
                vn.setdefault(i, Vector()).__iadd__(nrm)
    remap = {}
    for idx in keep:
        for i in idx:
            if i not in remap:
                n = vn[i].normalized()
                remap[i] = len(p_neve.v)
                p_neve.v.append(tuple(Vector(p_src.v[i]) + n * spessore + Vector((0, 0, spessore * 0.5))))
        p_neve.f.append(([remap[i] for i in idx], True, None))
