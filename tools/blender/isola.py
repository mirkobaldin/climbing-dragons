# Isola dei Draghi con l'arena (docs/CLOUD_SESSIONE.md v2, sezione 4).
#   blender -b --factory-startup --python tools/blender/isola.py -- --fase sagoma [--render]
#   blender -b --factory-startup --python tools/blender/isola.py -- --fase modello [--render] [--solo arena,isola,...]
# Scrive cloud/IsolaDraghi/ (FBX, collisioni, marcatori, texture, anteprime JPG).
# Assi: Blender Z in alto, il portale e l'arrivo guardano verso -Y (= +Z di Roblox). Metri.
# Origine: centro del pavimento dell'arena, a terra.

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cloud_lib as L
from cloud_lib import Vector, Matrix

# --- disposizione ----------------------------------------------------------------------------
ISLAND_R = 200.0          # raggio medio del bordo (circa 400 x 400 m)
ISLAND_DEPTH = 160.0      # spessore sotto il prato
R_IN, R_OUT = 75.0, 95.0  # apotemi dell'arena (interno 150, esterno ~190)
T = math.tan(math.radians(22.5))
Z_POD, Z_DECK, Z_PARA, Z_MERLI = 4.0, 22.0, 24.5, 26.5
TOWER_D, TOWER_R, TOWER_H = 100.0, 8.0, 40.0
GATE_W, GATE_H = 20.0, 30.0
ARRIVO = Vector((0.0, -165.0, 0.6))
ISOLETTE = [  # centro (x, y), quota del prato, raggio
    ((-300.0, -150.0), 25.0, 38.0),
    ((-330.0, 120.0), -20.0, 30.0),
    ((60.0, 330.0), 40.0, 26.0),
    ((310.0, 190.0), 5.0, 40.0),
    ((300.0, -230.0), -35.0, 22.0),
]
ELEMENTI = L.ELEMENTI


def noise1(seed, x):
    """rumore 1D liscio e periodico su 2*pi (somma di sinusoidi)"""
    rnd = random.Random(seed)
    s = 0.0
    for k in range(1, 7):
        s += math.sin(k * x + rnd.uniform(0, 6.28)) * rnd.uniform(0.4, 1.0) / k
    return s


def island_outline(theta):
    return ISLAND_R * (1.0 + 0.13 * noise1(3, theta))


def oslab(p, r0, r1, z0, z1, xa=-1e9, xb=1e9, M=None):
    """lastra fra gli apotemi r0 < r1 di un lato dell'ottagono (tagliata a 22,5 gradi), fra x = xa e xb;
    nel sistema del lato la faccia esterna guarda -Y"""
    pts = []
    for r, first in ((r0, True), (r1, False)):
        xl, xr = max(xa, -r * T), min(xb, r * T)
        if xl >= xr - 1e-3:
            return
        pts += [(xl, -r), (xr, -r)] if first else [(xr, -r), (xl, -r)]
    L.prism(p, pts, z0, z1, M)


# --- sagoma: solo forme grandi --------------------------------------------------------------

def bottom_depth(r, t):
    """profondita' del sotto dell'isola: cono rovesciato a gradoni irregolari (strati)"""
    R = island_outline(t)
    u = min(r / R, 1.0)
    base = ISLAND_DEPTH * (1 - u ** 1.6)
    # strati: la profondita' scende a gradini di 12 m con bordi morbidi
    step = 12.0
    q = base / step
    stepped = (math.floor(q) + 0.5 * (1 + math.tanh(6 * (q - math.floor(q) - 0.5)))) * step
    return -(0.55 * base + 0.45 * stepped) * (1 + 0.12 * noise1(21, t * 3 + r * 0.02))


def top_height(r, t):
    """quota del prato: piano attorno all'arena, colline e rocce verso il bordo"""
    R = island_outline(t)
    u = r / R
    hills = max(0.0, (u - 0.55) / 0.3) * (6 + 6 * noise1(31, t * 2))
    edge = -max(0.0, (u - 0.93) / 0.07) ** 2 * 8
    return hills * (1 - max(0.0, (u - 0.85) / 0.15)) + edge


def spires(seed, count, rmin, rmax):
    """speroni di roccia che pendono sotto l'isola: (x, y, z attacco, lunghezza, raggio)"""
    rnd = random.Random(seed)
    out = []
    for _ in range(count):
        t = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(rmin, rmax) * island_outline(t)
        z = bottom_depth(r, t) + 2
        out.append((r * math.cos(t), r * math.sin(t), z, rnd.uniform(18, 55) * (1.2 - r / ISLAND_R * 0.5), rnd.uniform(5, 12)))
    return out


def sagoma(m):
    p = m.part("Sagoma", "MAT_Gold")
    # isola: sopra colline, sotto cono a strati, speroni pendenti
    n, nr = 72, 24
    verts, faces = [], []
    for ri in range(nr + 1):
        u = ri / nr
        for i in range(n):
            t = 2 * math.pi * i / n
            r = island_outline(t) * u
            verts.append((r * math.cos(t), r * math.sin(t), top_height(r, t)))
    off = len(verts)
    for ri in range(nr + 1):
        u = ri / nr
        for i in range(n):
            t = 2 * math.pi * i / n
            r = island_outline(t) * u
            verts.append((r * math.cos(t), r * math.sin(t), bottom_depth(r, t) if ri < nr else top_height(r, t) - 6))
    for ri in range(nr):
        for i in range(n):
            a, b = ri * n + i, ri * n + (i + 1) % n
            faces.append([a, b, b + n, a + n])
            faces.append([off + a + n, off + b + n, off + b, off + a])
    for i in range(n):
        a, b = nr * n + i, nr * n + (i + 1) % n
        faces.append([a + off, b + off, b, a])
    p.add_raw(verts, faces)
    for (x, y, z, ln, rr) in spires(5, 26, 0.15, 0.85):
        L.cyl(p, (x, y, z), (x * 1.02, y * 1.02, z - ln), rr, 0.4, n=7)
    # rocce in piedi verso il bordo (sagoma frastagliata)
    rnd = random.Random(9)
    for _ in range(14):
        t = rnd.uniform(0, 2 * math.pi)
        if abs(((t + math.pi / 2) % (2 * math.pi)) - math.pi) > math.pi - 0.35:
            continue  # niente rocce davanti all'arrivo
        r = island_outline(t) * rnd.uniform(0.72, 0.9)
        x, y = r * math.cos(t), r * math.sin(t)
        h = rnd.uniform(10, 26)
        L.cyl(p, (x, y, top_height(r, t) - 2), (x + rnd.uniform(-3, 3), y + rnd.uniform(-3, 3), top_height(r, t) + h), rnd.uniform(5, 9), rnd.uniform(1.5, 3), n=6)
    # arena: anello ottagonale fino al parapetto, varco del portale sul lato 0
    for k in range(8):
        M = Matrix.Rotation(math.radians(45 * k), 4, "Z")
        for xa, xb in (((-999, -GATE_W / 2 - 6), (GATE_W / 2 + 6, 999)) if k == 0 else ((-999, 999),)):
            oslab(p, R_IN, R_OUT, 0, Z_PARA, xa, xb, M)
            for x in [-27 + 3 * i for i in range(19)]:
                if xa + 1 < x < xb - 1:
                    L.box(p, M @ Vector((x, -(R_OUT - 1.2), Z_PARA + 1)), (1.6, 2.4, 2.0), rot=M.to_3x3())
    # torri: rastremate, corona sporgente, drago accucciato in cima (ali alzate)
    for j in range(8):
        a = math.radians(-90 + 22.5 + 45 * j)
        c = Vector((TOWER_D * math.cos(a), TOWER_D * math.sin(a), 0))
        L.cyl(p, c, c + Vector((0, 0, 33)), TOWER_R + 1.5, TOWER_R, n=16)
        L.cyl(p, c + Vector((0, 0, 33)), c + Vector((0, 0, 36.5)), TOWER_R, TOWER_R + 1.6, n=16)
        L.cyl(p, c + Vector((0, 0, 36.5)), c + Vector((0, 0, 38.5)), TOWER_R + 1.6, n=16)
        R = Matrix.Rotation(a + math.pi / 2, 3, "Z")
        L.box(p, c + Vector((0, 0, 41)), (3.5, 7, 4.5), rot=R)                    # corpo
        L.box(p, c + R @ Vector((0, -4.5, 42.5)), (1.6, 3, 1.8), rot=R)          # testa in avanti
        for sx in (-1, 1):
            L.prism(p, [(0, 0), (sx * 6, 3), (sx * 3.5, -1)][:: -sx if sx < 0 else 1], -0.3, 0.3,
                    Matrix.Translation(c + R @ Vector((sx * 1.2, 1.5, 42))) @ R.to_4x4() @ Matrix.Rotation(math.radians(70), 4, "X"))
    # portale: arco a tutto sesto, due piloni piu' alti delle mura con le teste di drago
    blk = L.Part("tmp", "MAT_Gold")
    L.boxz(blk, -GATE_W / 2 - 6, GATE_W / 2 + 6, -R_OUT - 6, -R_IN + 2, 0, 34)
    cut = L.Part("tmpc", "MAT_Gold")
    L.arch_cutter(cut, 0, GATE_W, -0.5, GATE_H - GATE_W / 2, -R_OUT - 7, -R_IN + 3, segs=20)
    L.boolean(blk, cut)
    p.add_raw(blk.v, [f[0] for f in blk.f])
    for sx in (-1, 1):
        x0 = sx * (GATE_W / 2 + 6)
        L.boxz(p, min(x0, x0 + sx * 8), max(x0, x0 + sx * 8), -R_OUT - 9, -R_IN + 2, 0, 44)
        L.cyl(p, (x0 + sx * 4, -R_OUT - 5, 44), (x0 + sx * 4, -R_OUT - 5, 50), 3.5, 0.3, n=8)
        L.box(p, (x0 + sx * 4, -R_OUT - 13, 30), (6, 9, 6))                     # testa di drago
    # palco del domatore: balcone interno sopra l'arco
    L.boxz(p, -12, 12, -R_IN, -R_IN + 7, 11, 12)
    L.boxz(p, -12, 12, -R_IN + 6.5, -R_IN + 7, 12, 13.1)
    # arrivo e isolette con rovine
    L.cyl(p, ARRIVO - Vector((0, 0, 1.5)), ARRIVO, 8, n=24)
    for (cx, cy), z, r in ISOLETTE:
        c = Vector((cx, cy, z))
        L.cyl(p, c - Vector((0, 0, r * 1.6)), c, r * 0.15, r, n=12)
        for k in range(3):
            q = c + Vector((r * 0.4 * math.cos(k * 2.1), r * 0.4 * math.sin(k * 2.1), 0))
            L.box(p, q + Vector((0, 0, 4 + k)), (2, 2, 8 + 2 * k))


def render_sagome(m, objs):
    """sagome nere contro il cielo chiaro: da lontano (200 m dal bordo) e dalla camera del gioco"""
    import bpy
    out = os.path.join(L.CLOUD, m.name, "anteprime")
    os.makedirs(out, exist_ok=True)
    scene = bpy.context.scene
    world = bpy.data.worlds.new("Bianco")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.85, 0.9, 1.0, 1)
    scene.world = world
    black = bpy.data.materials.new("Nero")
    black.use_nodes = True
    bs = black.node_tree.nodes["Principled BSDF"]
    bs.inputs["Base Color"].default_value = (0, 0, 0, 1)
    bs.inputs["Roughness"].default_value = 1.0
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(black)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.clip_end = 5000
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.render.image_settings.file_format = "JPEG"
    scene.render.image_settings.quality = 85
    scene.view_settings.view_transform = "Standard"
    views = {
        # da lontano: 200 m oltre il bordo dell'isola
        "lontano_davanti": ((0, -620, 40), (0, 0, -30), 30),
        "lontano_destra": ((620, 0, 40), (0, 0, -30), 30),
        "lontano_dietro": ((0, 620, 40), (0, 0, -30), 30),
        "lontano_sinistra": ((-620, 0, 40), (0, 0, -30), 30),
        "alto": ((0, -1, 900), (0, 0, 0), 30),
        # camera del gioco (15-40 m dal personaggio): all'arrivo, al portale, dal palco
        "gioco_arrivo": ((0, -190, 8), (0, -100, 18), 30),
        "gioco_portale": ((14, -128, 4), (0, -96, 22), 24),
        "gioco_palco": ((0, -78, 16), (0, 40, 10), 24),
    }
    only = os.environ.get("VISTE")
    for name, (pos, target, lens) in views.items():
        if only and name not in only.split(","):
            continue
        cam.location = pos
        cam.data.lens = lens
        d = (Vector(target) - Vector(pos)).normalized()
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out, "sagoma_%s.jpg" % name)
        bpy.ops.render.render(write_still=True)
        print("  sagoma", name)


def _main():
    args = L.argv()
    fase = args[args.index("--fase") + 1] if "--fase" in args else "sagoma"
    L.clear_scene()
    m = L.Model("IsolaDraghi")
    if fase == "sagoma":
        sagoma(m)
        import bpy
        coll = bpy.data.collections.new("Sagoma")
        bpy.context.scene.collection.children.link(coll)
        objs = [L.build_object(p, coll, os.path.join(L.CLOUD, m.name, "Textures"), sharp_deg=30) for p in m.parts.values()]
        if "--render" in args:
            render_sagome(m, objs)


# =============================================================================================
# MODELLO VERO (kit di pietra)
import kit_pietra as K

BAY = 8.5
BAYS = [i * BAY for i in range(-3, 4)]
GATE_HALF = GATE_W / 2 + 14.0
STEP_VIS = ((0, 0, 1), (0, 1, 0))      # gradoni: si vedono il piano e il fronte verso il centro
STEP_DROP = ((0, 0, -1), (0, -1, 0))   # sul lato del portale le mura finiscono qui (piloni)


def lato(m, k, variant):
    """un lato dell'arena (sistema del lato: fuori verso -Y). variant 'A' integra, 'B' rovinata"""
    rng = random.Random(100 + (0 if variant == "A" else 1) + (50 if k == 0 else 0))
    M = Matrix.Rotation(math.radians(45 * k), 4, "Z")
    nm = "Arena_Mura_%02d" % (k + 1)
    pb = m.part(nm + "_EsternoBasso", "PietraVulcanica")
    pa = m.part(nm + "_EsternoAlto", "PietraVulcanica")
    pi = m.part(nm + "_Interno", "PietraVulcanica")
    pz = m.part(nm + "_Bronzo", "Bronzo")
    dmg = 0.05 if variant == "B" else 0.0
    gap = GATE_HALF if k == 0 else 0.0
    xs = 30.5                                       # oltre: dentro le torri

    def ranges(lim):
        return [(-lim, -gap), (gap, lim)] if gap else [(-lim, lim)]
    bays = [x for x in BAYS if abs(x) - BAY / 2 >= gap - 0.01]

    # --- fuori, ordine basso: zoccolo, arcate, galleria dietro
    def in_arch(x, z, spring, ro):
        # dentro l'apertura (rettangolo sotto l'imposta + semicerchio) o sui conci dell'arco
        for b in bays:
            dx = x - b
            if abs(dx) < ro + 0.25 and (z < spring or dx * dx + (z - spring) ** 2 < (ro + 0.2) ** 2):
                return True
        return False

    def open_low(x, z):
        return not in_arch(x, z, 7.6, 3.95)

    def open_high(x, z):
        if z > 12.2 and in_arch(x, z, 17.4, 3.4):
            return False
        for b in bays:
            if abs(x - b) < 1.0 and 22.2 < z < 23.8:   # finestrelle dell'attico
                return False
        return True
    for xa, xb in ranges(xs):
        K.ashlar(pb, M @ Matrix.Translation((0, -R_OUT, 0)), xa, xb, -2.0, 1.2, rng, course=1.6, depth=0.9, face_y=-0.35, lmin=1.4, lmax=2.4)
        K.ashlar(pb, M @ Matrix.Translation((0, -R_OUT, 0)), xa, xb, 1.2, 11.0, rng, course=1.3, depth=0.7, clip=open_low, missing=dmg)
        K.cornice(pb, M @ Matrix.Translation((0, -R_OUT, 0)), xa, xb, 11.0, [(0.0, 0.0), (0.3, 0.0), (0.3, 0.3), (0.55, 0.55), (0.55, 0.95), (0.7, 1.05), (0.7, 1.2), (0.0, 1.2)], rng)
        # massa dietro la facciata (galleria): pavimento, fondo scuro, soffitto
        K.tint_fill(pb)
        oslab(pb, R_OUT - 4.0, R_OUT - 0.6, -2.0, 0.0, xa, xb, M)
        oslab(pb, R_OUT - 4.6, R_OUT - 4.0, 0.0, 11.0, xa, xb, M)
        oslab(pb, R_OUT - 4.0, R_OUT - 0.6, 10.4, 11.0, xa, xb, M)
        K.tint_fill(pb)
    for x in bays:
        K.arch(pb, M @ Matrix.Translation((0, -R_OUT, 0)), x, 7.6, 3.0, 3.95, -0.05, 0.8, rng)
        K.arch(pa, M @ Matrix.Translation((0, -R_OUT, 0)), x, 17.4, 2.6, 3.4, -0.05, 0.75, rng, n=11)
        # cancellate di bronzo nelle arcate basse (alcune aperte nella variante B)
        if variant == "A" or rng.random() < 0.6:
            for i in range(9):
                bx = x - 2.6 + i * 0.65
                top = 7.6 + math.sqrt(max(9.0 - (bx - x) ** 2, 0.0)) - 0.05
                L.box(pz, M @ Vector((bx, -R_OUT + 1.3, top / 2)), (0.1, 0.1, top), rot=M.to_3x3())
            for z in (2.6, 5.4):
                L.box(pz, M @ Vector((x, -R_OUT + 1.3, z)), (6.0, 0.08, 0.14), rot=M.to_3x3())
        # scudo di bronzo sull'attico
        L.cyl(pz, M @ Vector((x + BAY / 2 - 0.0, -R_OUT - 0.05, 23.0)), M @ Vector((x + BAY / 2, -R_OUT - 0.35, 23.0)), 0.75, 0.6, n=14, bev=0.05)
    for x in sorted(set([b - BAY / 2 for b in bays] + [b + BAY / 2 for b in bays])):
        if abs(x) <= 30.0:
            K.half_column(pb, M, x, -R_OUT, 1.2, 11.0, 0.62)
            K.half_column(pa, M, x, -R_OUT, 12.2, 20.6, 0.52)
    # --- fuori, ordine alto e attico
    for xa, xb in ranges(xs):
        K.ashlar(pa, M @ Matrix.Translation((0, -R_OUT, 0)), xa, xb, 12.2, 24.4, rng, course=1.22, depth=0.7, clip=open_high, missing=dmg)
        K.cornice(pa, M @ Matrix.Translation((0, -R_OUT, 0)), xa, xb, 20.6, [(0.0, 0.0), (0.25, 0.0), (0.25, 0.25), (0.45, 0.5), (0.45, 0.85), (0.6, 0.95), (0.6, 1.1), (0.0, 1.1)], rng)
        K.cornice(pa, M @ Matrix.Translation((0, -R_OUT, 0)), xa, xb, 24.4, [(0.0, -0.1), (0.3, -0.1), (0.55, 0.2), (0.95, 0.45), (1.05, 0.6), (1.05, 0.85), (0.0, 0.85)], rng)
        K.tint_fill(pa)
        oslab(pa, R_OUT - 4.0, R_OUT - 0.6, 11.0, 12.2, xa, xb, M)
        oslab(pa, R_OUT - 4.6, R_OUT - 4.0, 12.2, 21.4, xa, xb, M)
        oslab(pa, R_OUT - 4.6, R_OUT - 0.6, 21.4, Z_DECK, xa, xb, M)
        oslab(pa, R_OUT - 2.2, R_OUT - 0.6, Z_DECK, 25.25, xa, xb, M)          # parapetto (dentro)
        K.tint_fill(pa)
        K.merlons(pa, M @ Matrix.Translation((0, -R_OUT, 0)), max(xa, -29.9), min(xb, 29.9), 25.25, rng, y=-0.25, depth=2.0,
                  broken=0.12 + (0.35 if variant == "B" else 0.0))

    # --- dentro: podio a conci, gradoni a lastre, scalinata
    for xa, xb in ranges(R_IN * T - 0.3):
        # podio: la faccia guarda il centro (+Y del lato): sistema girato di 180 gradi
        K.ashlar(pi, M @ Matrix.Translation((0, -R_IN, 0)) @ Matrix.Rotation(math.pi, 4, "Z"),
                 -min(xb, R_IN * T - 0.3), -max(xa, -R_IN * T + 0.3), 0.0, Z_POD, rng,
                 course=1.0, depth=0.8, face_y=0.0, missing=dmg * 0.5)
        # copertina del podio: la faccia interna guarda il centro (+Y): sistema girato di 180 gradi
        K.cornice(pi, M @ Matrix.Translation((0, -R_IN, 0)) @ Matrix.Rotation(math.pi, 4, "Z"),
                  -min(xb, R_IN * T), -max(xa, -R_IN * T), Z_POD, [(0.0, 0.0), (0.25, 0.05), (0.35, 0.35), (0.35, 0.55), (-0.8, 0.55), (-0.8, 0.0)], rng)
        K.tint_fill(pi)
        oslab(pi, R_IN + 0.8, R_IN + 2.0, 0.0, Z_POD + 0.55, xa, xb, M)
        K.tint_fill(pi)
        rows = 12
        rise = (Z_DECK - Z_POD - 0.55) / rows
        for s in range(rows):
            r0 = R_IN + 2.0 + s * 1.0
            z1 = Z_POD + 0.55 + rise * (s + 1)
            lim = r0 * T
            a, b = max(xa, -lim), min(xb, lim)
            x = a
            while x < b - 0.3:
                e = min(x + rng.uniform(4.5, 7.5), b)
                if not (gap == 0 and abs((x + e) / 2) < 1.4):     # varco della scalinata al centro
                    cx = (x + e) / 2
                    if abs(cx) < 1.6 and gap == 0:
                        pass
                    K._block(pi, M @ Vector((cx, -(r0 + 0.5), z1 - 0.45)), (e - x - 0.04, 1.06, 0.9), M.to_3x3(), 0.05, rng.random(),
                             chip=0.3 if rng.random() < 0.3 else 0.0, rng=rng, vis=STEP_VIS, drop=STEP_DROP)
                x = e
            # riempimento sotto il gradone (non si vede, chiude la forma)
            K.tint_fill(pi)
            oslab(pi, r0, r0 + 1.0, z1 - rise - 0.6, z1 - 0.9, xa, xb, M)
            K.tint_fill(pi)
    if gap == 0:
        # scalinata a misura d'uomo al centro: gradini da 0,3 m
        n = int((Z_DECK - Z_POD) / 0.3)
        run = 12.0 / n
        for i in range(n):
            z1 = Z_POD + 0.3 * (i + 1)
            K._block(pi, M @ Vector((0, -(R_IN + 1.0 + run * (i + 0.5)), z1 - 0.15)), (2.2, run + 0.02, 0.3), M.to_3x3(), 0.02, rng.random(),
                     vis=STEP_VIS, drop=STEP_DROP)
        for sx in (-1, 1):
            K.tint_fill(pi)
            prism_side = [(-(R_IN + 0.8), Z_POD - 0.3), (-(R_IN + 13.0), Z_DECK - 0.3), (-(R_IN + 13.0), Z_DECK + 0.6), (-(R_IN + 0.8), Z_POD + 0.6)]
            L.prism(pi, prism_side[::-1], sx * 1.1 - 0.15, sx * 1.1 + 0.15,
                    M @ Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1))))
            K.tint_fill(pi)
    # anello per i draghi selvatici in cima (bronzo) sul parapetto
    if k != 0:
        L.torus(pz, M @ Vector((0, -(R_OUT - 1.4), 26.2)), 1.3, 0.16, normal=M.to_3x3() @ Vector((0, 1, 0)), nR=20, nr=6)
        L.box(pz, M @ Vector((0, -(R_OUT - 1.4), 25.5)), (0.6, 0.6, 0.6), rot=M.to_3x3())
        m.marker("SPOT_Posatoio%d" % (k + 1), M @ Vector((0, -(R_OUT - 1.4), 27.6)))
    for part in (pb, pa, pi):
        K.tint_fill(part)



# --- torri ------------------------------------------------------------------------------------
TOWER_SEED = 300   # stessa geometria per le 8 torri: si cuoce una volta sola


def tower_frame(j):
    a = math.radians(-90 + 22.5 + 45 * j)
    c = Vector((TOWER_D * math.cos(a), TOWER_D * math.sin(a), 0))
    # sistema della torre: -Y verso fuori dall'arena
    return Matrix.Translation(c) @ Matrix.Rotation(a + math.pi / 2, 4, "Z"), a


def torre(m, j):
    el = ELEMENTI[j]
    rng = random.Random(TOWER_SEED)
    M, a = tower_frame(j)
    pt = m.part("Arena_Torre_" + el, "PietraVulcanica")
    pz = m.part("Arena_Torre_%s_Bronzo" % el, "Bronzo")
    pe = m.part("Arena_Torre_%s_Braci" % el, "MAT_Ember")
    R0, R1 = TOWER_R + 0.8, TOWER_R

    def ang(d):
        return math.radians(d)
    doors = (ang(22.5), ang(157.5))          # verso le mura, al camminamento (z 22)
    slits = [(ang(-90 + s), z) for s in (-32, 0, 32) for z in (9.5, 17.5)]

    def open_shaft(t, z):
        for d in doors:
            if abs(math.atan2(math.sin(t - d), math.cos(t - d))) * R1 < 1.25 and Z_DECK - 0.2 < z < Z_DECK + 3.6:
                return False
        for s, zz in slits:
            if abs(math.atan2(math.sin(t - s), math.cos(t - s))) * R1 < 0.45 and abs(z - zz) < 1.5:
                return False
        return True
    # zoccolo a scarpa, fusto a conci, nucleo (chiude le fughe)
    K.ring_ashlar(pt, M, R0 + 0.8, R0 + 0.4, -2.0, 2.2, rng, course=1.4, depth=1.0, lmin=1.2, lmax=1.9)
    K.tint_fill(pt)
    L.lathe(pt, [(R0 + 0.5, 2.2), (R0 + 0.75, 2.35), (R0 + 0.6, 2.75), (R0 + 0.02, 2.95)], 32, M=M, smooth=False)
    K.tint_fill(pt)
    K.ring_ashlar(pt, M, R0, R1, 2.95, 31.0, rng, course=2.0, depth=0.9, lmin=1.4, lmax=2.1, clip=open_shaft)
    K.tint_fill(pt)
    L.lathe(pt, [(R1 - 0.85, -2.0), (R1 - 0.85, 33.0)], 16, M=M, smooth=False, close=False)
    for d in doors:
        K.arch(pt, M @ Matrix.Rotation(d + math.pi / 2, 4, "Z") @ Matrix.Translation((0, -R1 - 0.02, 0)), 0, Z_DECK + 2.4, 0.8, 1.35, -0.05, 0.7, rng, n=7)
    for s, zz in slits:
        Ms = M @ Matrix.Rotation(s + math.pi / 2, 4, "Z") @ Matrix.Translation((0, -R1 - 0.03, 0))
        K._block(pt, Ms @ Vector((0, 0.3, zz + 1.6)), (1.3, 0.7, 0.35), Ms.to_3x3(), 0.05, rng.random())
        K._block(pt, Ms @ Vector((0, 0.3, zz - 1.6)), (1.4, 0.7, 0.35), Ms.to_3x3(), 0.05, rng.random())
    # beccatelli e corona sporgente con i merli
    n = 18
    for i in range(n):
        t = 2 * math.pi * (i + 0.5) / n
        Rt = M.to_3x3() @ Matrix.Rotation(t + math.pi / 2, 3, "Z")
        for (dd, hh, z0, w) in ((1.3, 1.3, 30.1, 0.8), (2.4, 1.5, 31.4, 0.9)):
            rr = R1 - 0.6 + dd / 2
            K._block(pt, M @ Vector((rr * math.cos(t), rr * math.sin(t), z0 + hh / 2)), (w, dd, hh), Rt, 0.05, rng.random())
    K.tint_fill(pt)
    L.lathe(pt, [(R1 - 0.6, 32.85), (R1 + 1.85, 32.85), (R1 + 1.85, 33.0)], 32, M=M, smooth=False, close=False)
    K.tint_fill(pt)
    RC = R1 + 1.9
    K.ring_ashlar(pt, M, RC, RC, 33.0, 36.3, rng, course=1.65, depth=0.9, lmin=1.3, lmax=2.0)
    K.tint_fill(pt)
    L.lathe(pt, [(RC - 0.1, 36.3), (RC + 0.25, 36.35), (RC + 0.35, 36.6), (RC + 0.1, 36.8), (0.0, 36.8)], 32, M=M, smooth=False, close=False)
    L.lathe(pt, [(RC - 1.0, 36.8), (RC - 1.0, 33.0)], 24, M=M, smooth=False, close=False)
    K.tint_fill(pt)
    nm = 16
    for i in range(nm):
        t = 2 * math.pi * (i + 0.25) / nm
        if math.cos(t + math.pi / 2) > 0.8 and i % 2:     # varco per la statua
            continue
        Rt = M.to_3x3() @ Matrix.Rotation(t + math.pi / 2, 3, "Z")
        hh = 2.0 * (rng.uniform(0.5, 0.7) if rng.random() < 0.15 else 1.0)
        rr = RC - 0.5
        K._block(pt, M @ Vector((rr * math.cos(t), rr * math.sin(t), 36.8 + hh / 2)), (1.7, 1.0, hh), Rt, 0.07, rng.random(), chip=0.3, rng=rng)
    # basamento della statua (verso fuori) e del braciere (verso dentro)
    K._block(pt, M @ Vector((0, -3.2, 37.4)), (5.2, 7.5, 1.2), M.to_3x3(), 0.08, rng.random())
    K._block(pt, M @ Vector((0, 5.0, 37.2)), (3.4, 3.4, 0.8), M.to_3x3(), 0.08, rng.random())
    K.tint_fill(pt)
    # bronzo: fascia, braciere su tre zampe, asta dello stendardo
    L.lathe(pz, [(R1 + 0.02, 29.2), (R1 + 0.14, 29.25), (R1 + 0.14, 29.75), (R1 + 0.02, 29.8)], 32, M=M, smooth=False, close=False)
    Mb = M @ Matrix.Translation((0, 5.0, 37.6))
    L.lathe(pz, [(0.0, 1.0), (0.9, 1.05), (1.7, 1.6), (1.95, 2.3), (1.85, 2.35), (1.55, 1.85), (0.0, 1.75)], 18, M=Mb)
    for i in range(3):
        t = 2 * math.pi * i / 3
        q0 = Mb @ Vector((1.3 * math.cos(t), 1.3 * math.sin(t), 0.0))
        q1 = Mb @ Vector((0.7 * math.cos(t), 0.7 * math.sin(t), 1.3))
        L.cyl(pz, q0, q1, 0.12, 0.1, n=6)
    L.torus(pz, Mb @ Vector((0, 0, 2.32)), 1.9, 0.08, nR=24, nr=5)
    L.lathe(pe, [(0.0, 2.25), (1.4, 1.95), (1.0, 2.35), (0.4, 2.55), (0.0, 2.6)], 12, M=Mb)
    m.marker("FX_Fire_" + el, Mb @ Vector((0, 0, 2.7)))
    m.marker("FX_Light_" + el, Mb @ Vector((0, 0, 4.0)))
    # asta dello stendardo sotto i beccatelli, verso fuori
    L.cyl(pz, M @ Vector((-2.4, -R1 - 0.2, 29.5)), M @ Vector((-2.4, -R1 - 1.5, 29.5)), 0.12, n=6)
    L.cyl(pz, M @ Vector((2.4, -R1 - 0.2, 29.5)), M @ Vector((2.4, -R1 - 1.5, 29.5)), 0.12, n=6)
    L.cyl(pz, M @ Vector((-2.7, -R1 - 1.4, 29.5)), M @ Vector((2.7, -R1 - 1.4, 29.5)), 0.1, n=6)
    stendardo(m, j, M @ Matrix.Translation((0, -R1 - 1.4, 29.4)))
    # segnaposto della statua (Meshy: StatuaDrago_<El>, 9 x 5 x 6 m, testa verso fuori)
    ps = m.part("PLACEHOLDER_Arena_Statua_" + el, "Basalto")
    L.box(ps, M @ Vector((0, -3.2, 38.0 + 3.0)), (5.0, 9.0, 6.0), rot=M.to_3x3())
    L.box(ps, M @ Vector((0, -8.4, 40.2)), (2.0, 2.4, 2.0), rot=M.to_3x3())      # testa (verso fuori)
    m.marker("SPOT_Statua_" + el, M @ Vector((0, -3.2, 38.0)))
    # collisioni: ottagono di due scatole + corona
    c = M @ Vector((0, 0, 0))
    for r in (0.0, math.pi / 4):
        m.col("Torre%s_%d" % (el, int(r * 4 / math.pi)), c + Vector((0, 0, 16.0)), (2 * R1, 2 * R1, 36.0), Matrix.Rotation(a + r, 3, "Z"))
        m.col("Corona%s_%d" % (el, int(r * 4 / math.pi)), c + Vector((0, 0, 34.9)), (2 * RC, 2 * RC, 3.8), Matrix.Rotation(a + r, 3, "Z"))


def stendardo(m, j, M, w=4.6, h=13.0):
    """drappo con la coda a rondine, pieghe leggere; UV nella colonna j dell'atlante Stendardi"""
    el = ELEMENTI[j]
    p = m.part("Arena_Stendardo_" + el, "Stendardi")
    cols, rows = 6, 16
    th = 0.04

    def pos(s, t):
        x = (s - 0.5) * w
        notch = 1.8 * (1 - abs(s - 0.5) * 2)
        z = -t * (h - notch)
        y = -0.16 * math.sin(s * math.pi * 2.0 + t * 1.3) * (0.3 + t) - 0.3 * t * t
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
                v = 1.0 - t * (1 - (1.8 * (1 - abs(s - 0.5) * 2)) / h) * 0.985 - 0.005
                row.append((M @ q, (u, v)))
            grid.append(row)
        for i in range(rows):
            for jx in range(cols):
                a_, b_, c_, d_ = grid[i][jx], grid[i][jx + 1], grid[i + 1][jx + 1], grid[i + 1][jx]
                fc = [a_, b_, c_, d_] if side == 0 else [d_, c_, b_, a_]
                base = len(p.v)
                p.v.extend([tuple(q[0]) for q in fc])
                p.f.append(([base, base + 1, base + 2, base + 3], True, [q[1] for q in fc]))


# --- portale, saracinesca, palco ----------------------------------------------------------------
SPRING = GATE_H - GATE_W / 2          # imposta dell'arco del portale (20 m)
PY0, PY1 = -R_OUT - 5.0, -R_IN        # profondita' dei piloni
PX = GATE_HALF                        # i piloni vanno da |x| = GATE_W/2 a PX


def portale(m):
    rng = random.Random(400)
    pp = m.part("Arena_Portale", "PietraVulcanica")
    pv = m.part("Arena_Portale_Volta", "PietraVulcanica")
    po = m.part("Arena_Portale_Oro", "OroAntico")
    pf = m.part("Arena_Portale_Saracinesca", "FerroBattuto")
    gw = GATE_W / 2
    RO = gw + 2.6

    def outside_gate(x, z, extra=0.3):
        return not (abs(x) < RO + extra and (z < SPRING or x * x + (z - SPRING) ** 2 < (RO + 0.2) ** 2))

    def front_clip(x, z):
        if z > 40.0 and abs(x) < gw:
            return False
        return outside_gate(x, z)

    def inner_clip(x, z):
        if not front_clip(x, z):
            return False
        for dx in (-12.0, 12.0):                     # porte del palco
            if abs(x - dx) < 1.05 and 11.9 < z < 15.6:
                return False
        return True
    # nuclei (chiudono le fughe)
    for s in (-1, 1):
        L.boxz(pp, min(s * gw, s * PX) + 0.0, max(s * gw, s * PX), PY0 + 0.6, PY1 - 0.6, -2.0, 43.6)
    L.boxz(pp, -gw, gw, PY0 + 0.6, PY1 - 0.6, SPRING + RO - 0.4, 39.8)
    K.tint_fill(pp)
    # facciata esterna e interna
    Mf = Matrix.Translation((0, PY0, 0))
    K.ashlar(pp, Mf, -PX, PX, -2.0, 1.6, rng, course=1.8, depth=1.0, face_y=-0.3, lmin=1.2, lmax=2.0, clip=lambda x, z: outside_gate(x, z, -0.2))
    K.ashlar(pp, Mf, -PX, PX, 1.6, 44.0, rng, course=1.8, depth=0.8, lmin=1.3, lmax=2.3, clip=front_clip)
    Mi = Matrix.Translation((0, PY1, 0)) @ Matrix.Rotation(math.pi, 4, "Z")
    K.ashlar(pp, Mi, -PX, PX, 0.0, 44.0, rng, course=1.8, depth=0.8, lmin=1.3, lmax=2.3, clip=inner_clip)
    # fianchi verso il passaggio (fino all'imposta) e verso fuori
    for s in (-1, 1):
        Ms = Matrix.Translation((s * gw, 0, 0)) @ Matrix.Rotation(-s * math.pi / 2, 4, "Z")
        ya, yb = sorted((-s * PY0 if s > 0 else PY0, -s * PY1 if s > 0 else PY1))
        K.ashlar(pp, Ms, ya, yb, 0.0, SPRING, rng, course=1.8, depth=0.8, lmin=1.3, lmax=2.3)
        K.ashlar(pp, Ms, ya, yb, 40.0, 44.0, rng, course=1.8, depth=0.8, lmin=1.3, lmax=2.3)
        Mo = Matrix.Translation((s * PX, 0, 0)) @ Matrix.Rotation(s * math.pi / 2, 4, "Z")
        ya, yb = sorted((s * PY0, s * (-R_OUT)))
        K.ashlar(pp, Mo, ya, yb, -2.0, 44.0, rng, course=1.8, depth=0.8, lmin=1.3, lmax=2.3)
        ya, yb = sorted((s * (-R_OUT), s * PY1))
        K.ashlar(pp, Mo, ya, yb, Z_MERLI - 1.0, 44.0, rng, course=1.8, depth=0.8, lmin=1.3, lmax=2.3)
        # cornicione e tetto a piramide dei piloni con il pinnacolo di bronzo
        cx = s * (gw + PX) / 2
        K.tint_fill(pp)
        L.prism(pp, [(cx - 7.6, PY0 - 0.6), (cx + 7.6, PY0 - 0.6), (cx + 7.6, PY1 + 0.6), (cx - 7.6, PY1 + 0.6)], 44.0, 44.8)
        L.lathe(pp, [(0.0, 44.8), (9.5, 44.8), (0.6, 52.0), (0.0, 52.2)], 4, c=(cx, (PY0 + PY1) / 2, 0), a0=math.pi / 4,
                a1=math.pi / 4 + 2 * math.pi, smooth=False)
        K.tint_fill(pp)
        L.cyl(po, (cx, (PY0 + PY1) / 2, 51.6), (cx, (PY0 + PY1) / 2, 55.0), 0.35, 0.05, n=8)
        L.sphere(po, (cx, (PY0 + PY1) / 2, 52.4), 0.6, seg=10, rings=6)
        # segnaposto della testa di drago (Meshy: TestaDrago, 10 x 6 x 7 m) che esce dal pilone
        ph = m.part("PLACEHOLDER_Arena_TestaDrago_" + ("Sx" if s < 0 else "Dx"), "Basalto")
        L.box(ph, (cx, PY0 - 5.0, 27.5), (6.0, 10.0, 7.0))
        m.marker("SPOT_TestaDrago_" + ("Sx" if s < 0 else "Dx"), (cx, PY0, 27.5))
        # mensola che regge la testa
        for i, (dd, hh) in enumerate(((1.5, 1.2), (3.0, 1.2), (4.5, 1.4))):
            K._block(pp, Vector((cx, PY0 - dd / 2, 24.0 - 1.2 * (2 - i) - hh / 2 + 1.2)), (5.0 - i * 0.6, dd, hh), None, 0.06, rng.random())
    # cornice alta e merli sopra l'attico
    K.cornice(pp, Mf, -PX, PX, 40.0, [(0.0, 0.0), (0.3, 0.0), (0.6, 0.35), (1.0, 0.6), (1.0, 0.9), (0.0, 0.9)], rng)
    K.merlons(pp, Mf, -gw + 0.3, gw - 0.3, 40.9, rng, y=-0.25, depth=1.8, broken=0.1)
    for xa, xb in ((-PX, -RO - 0.3), (RO + 0.3, PX)):
        K.cornice(pp, Mf, xa, xb, 12.0, [(0.0, 0.0), (0.25, 0.0), (0.45, 0.3), (0.45, 0.7), (0.0, 0.7)], rng)
    K.tint_fill(pp)
    # pavimento del passaggio: lastre
    pg = m.part("Arena_Portale_Passaggio", "PietraVulcanica")
    K.slabs(pg, Matrix.Identity(4), -gw, gw, PY0 - 0.5, PY1 + 1.0, 0.12, rng, th=0.3, lmin=1.0, lmax=1.8)
    m.col("Passaggio", (0, (PY0 + PY1) / 2, -0.4), (GATE_W, PY1 - PY0 + 2, 1.0))
    # volta: anelli di conci lungo il passaggio, arco di facciata con la chiave grande
    K.arch(pv, Mf, 0, SPRING, gw, RO, -0.15, 2.2, rng, n=19, key=1.12)
    y = PY0 + 2.2
    while y < PY1 - 2.0:
        y1 = min(y + 2.4, PY1 - 2.0)
        K.arch(pv, Matrix.Identity(4), 0, SPRING, gw, gw + 1.2, y, y1, rng, n=15, key=1.0)
        y = y1
    K.arch(pv, Matrix.Translation((0, PY1, 0)) @ Matrix.Rotation(math.pi, 4, "Z"), 0, SPRING, gw, RO - 0.6, -0.15, 2.0, rng, n=19, key=1.1)
    # imposte (capitelli) dell'arco
    for s in (-1, 1):
        K._block(pv, Vector((s * (gw + 0.2), PY0 + 1.0, SPRING - 0.35)), (1.2, 2.4, 0.7), None, 0.06, rng.random())
    K.tint_fill(pv)
    # oro: archivolto, medaglione sulla chiave, fascia
    L.lathe(po, [(RO + 0.05, -0.0), (RO + 0.35, 0.0), (RO + 0.35, 0.25), (RO + 0.05, 0.25)], 24, a0=0, a1=math.pi, close=False,
            M=Matrix.Translation((0, PY0 - 0.05, SPRING)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    L.cyl(po, (0, PY0 - 0.5, SPRING + RO + 2.2), (0, PY0 - 0.9, SPRING + RO + 2.2), 1.7, 1.5, n=24, bev=0.08)
    L.torus(po, (0, PY0 - 0.95, SPRING + RO + 2.2), 1.15, 0.12, normal=(0, 1, 0), nR=24, nr=6)
    # saracinesca alzata a meta' (fondo a 16 m), dentro la sagoma dell'arco
    yb = PY0 + 2.6
    zb = 16.0
    for i in range(-7, 8):
        x = i * 1.3
        top = SPRING + math.sqrt(max(gw * gw - x * x, 0.0)) - 0.2
        if top <= zb:
            continue
        L.box(pf, (x, yb, (zb + top) / 2), (0.28, 0.28, top - zb))
        L.lathe(pf, [(0.0, zb - 0.9), (0.2, zb), (0.0, zb + 0.01)], 4, c=(x, yb, 0), smooth=False)
    z = zb + 0.8
    while z < SPRING + gw - 0.6:
        hw = math.sqrt(max(gw * gw - max(z - SPRING, 0) ** 2, 0.0)) - 0.2 if z > SPRING else gw - 0.2
        L.box(pf, (0, yb + 0.25, z), (2 * hw, 0.22, 0.32))
        z += 1.6
    # collisioni dei piloni e dell'attico
    for s in (-1, 1):
        m.col("Pilone%d" % s, (s * (gw + PX) / 2, (PY0 + PY1) / 2, 21.0), (PX - gw, PY1 - PY0, 46.0))
    m.col("Attico", (0, (PY0 + PY1) / 2, (SPRING + RO + 42.0) / 2), (GATE_W, PY1 - PY0, 42.0 - SPRING - RO))


def palco(m):
    rng = random.Random(500)
    pl = m.part("Arena_Palco", "PietraVulcanica")
    pz = m.part("Arena_Palco_Bronzo", "Bronzo")
    pw = m.part("Arena_Palco_Porte", "LegnoScuro")
    pe = m.part("Arena_Palco_Braci", "MAT_Ember")
    y0, y1 = PY1, PY1 + 6.5
    X = 13.4
    # piano: lastre squadrate
    x = -X
    while x < X - 0.1:
        w = min(rng.uniform(2.2, 3.0), X - x)
        K._block(pl, Vector((x + w / 2, (y0 + y1) / 2, 11.7)), (w - 0.03, y1 - y0, 0.6), None, 0.05, rng.random())
        x += w
    # mensoloni a tre gradini
    for i in range(7):
        cx = -X + 0.6 + i * (2 * X - 1.2) / 6
        for dd, hh, z1 in ((5.9, 0.7, 11.4), (4.0, 0.8, 10.7), (2.2, 1.0, 9.9)):
            K._block(pl, Vector((cx, y0 + dd / 2, z1 - hh / 2)), (0.95, dd, hh), None, 0.05, rng.random())
    K.cornice(pl, Matrix.Translation((0, y1, 0)) @ Matrix.Rotation(math.pi, 4, "Z"), -X, X, 11.1,
              [(0.0, 0.0), (0.15, 0.0), (0.3, 0.2), (0.3, 0.3), (0.0, 0.3)], rng)
    # balaustra: zoccolo, colonnine, corrimano, pilastrini
    K.tint_fill(pl)
    rail = [((-X + 0.25, y1 - 0.25), (X - 0.25, y1 - 0.25)), ((-X + 0.25, y0 + 0.4), (-X + 0.25, y1 - 0.25)),
            ((X - 0.25, y0 + 0.4), (X - 0.25, y1 - 0.25))]
    for (ax, ay), (bx, by) in rail:
        cx, cy = (ax + bx) / 2, (ay + by) / 2
        ln = math.hypot(bx - ax, by - ay)
        rot = Matrix.Rotation(math.atan2(by - ay, bx - ax), 3, "Z")
        K._block(pl, Vector((cx, cy, 12.11)), (ln + 0.5, 0.5, 0.22), rot, 0.04, rng.random())
        K._block(pl, Vector((cx, cy, 13.02)), (ln + 0.5, 0.42, 0.16), rot, 0.04, rng.random())
        n = int(ln / 0.55)
        for i in range(n + 1):
            t = i / n
            q = (ax + (bx - ax) * t, ay + (by - ay) * t)
            if i % 8 == 0:
                K._block(pl, Vector((q[0], q[1], 12.6)), (0.5, 0.5, 1.0), rot, 0.04, rng.random())
            else:
                L.lathe(pl, [(0.12, 12.22), (0.16, 12.35), (0.09, 12.55), (0.15, 12.75), (0.07, 12.94)], 6, c=(q[0], q[1], 0), smooth=True)
                K.tint_fill(pl)
    # baldacchino: quattro colonne sul davanti e un tetto di lastre con la cornice (si legge da lontano)
    ZC = 18.0
    for cx in (-X + 0.6, -4.2, 4.2, X - 0.6):
        K._block(pl, Vector((cx, y1 - 0.6, 12.35)), (0.9, 0.9, 0.5), None, 0.05, rng.random())
        L.lathe(pl, [(0.34, 12.6), (0.3, 12.8), (0.27, 13.0), (0.25, ZC - 0.9), (0.33, ZC - 0.6), (0.45, ZC - 0.35)], 10,
                c=(cx, y1 - 0.6, 0), smooth=True, close=False)
        K.tint_fill(pl)
        K._block(pl, Vector((cx, y1 - 0.6, ZC - 0.2)), (1.0, 1.0, 0.4), None, 0.05, rng.random())
    x = -X - 0.4
    while x < X + 0.4 - 0.1:
        w = min(rng.uniform(2.4, 3.2), X + 0.4 - x)
        K._block(pl, Vector((x + w / 2, (y0 + y1) / 2 + 0.2, ZC + 0.3)), (w - 0.03, y1 - y0 + 0.8, 0.6), None, 0.05, rng.random())
        x += w
    K.cornice(pl, Matrix.Translation((0, y1 + 0.6, 0)) @ Matrix.Rotation(math.pi, 4, "Z"), -X - 0.4, X + 0.4, ZC + 0.6,
              [(0.0, 0.0), (0.2, 0.0), (0.35, 0.2), (0.35, 0.45), (0.0, 0.45)], rng)
    K.tint_fill(pl)
    for cx in (-X + 0.6, -4.2, 4.2, X - 0.6):
        L.lathe(pz, [(0.26, 13.3), (0.29, 13.32), (0.29, 13.5), (0.26, 13.52)], 10, c=(cx, y1 - 0.6, 0), smooth=False, close=False)
    m.col("PalcoTetto", (0, (y0 + y1) / 2 + 0.2, ZC + 0.3), (2 * X + 0.8, y1 - y0 + 0.8, 0.6))
    # porte di legno nei piloni (1,6 x 3 m, arco in cima)
    for dx in (-12.0, 12.0):
        L.box(pw, (dx, PY1 - 0.68, 13.1), (1.6, 0.1, 2.2))
        L.cyl(pw, (dx, PY1 - 0.73, 14.2), (dx, PY1 - 0.63, 14.2), 0.8, n=12)
        K.arch(pl, Matrix.Translation((0, PY1, 0)) @ Matrix.Rotation(math.pi, 4, "Z"), -dx, 14.2, 0.8, 1.3, -0.05, 0.75, rng, n=7)
        for sx in (-1, 1):
            K._block(pl, Vector((dx + sx * 1.05, PY1 + 0.1, 13.1)), (0.5, 0.75, 2.2), None, 0.04, rng.random())
    # due bracieri sul davanti
    for sx in (-1, 1):
        c = Vector((sx * (X - 0.9), y1 - 0.9, 12.0))
        L.lathe(pz, [(0.0, 0.0), (0.4, 0.0), (0.25, 0.15), (0.12, 0.25), (0.12, 0.85), (0.3, 0.95), (0.6, 1.25), (0.62, 1.35), (0.0, 1.2)], 12, c=c)
        L.lathe(pe, [(0.0, 1.32), (0.5, 1.25), (0.3, 1.45), (0.0, 1.5)], 10, c=c)
        m.marker("FX_Fire_Palco%d" % (1 if sx < 0 else 2), c + Vector((0, 0, 1.55)))
    m.marker("SPOT_Domatore", Vector((0, (y0 + y1) / 2, 12.0)))
    m.col("Palco", (0, (y0 + y1) / 2, 11.7), (2 * X, y1 - y0, 0.6))
    m.col("PalcoRinghiera", (0, y1 - 0.25, 12.55), (2 * X, 0.5, 1.1))
    for sx in (-1, 1):
        m.col("PalcoRinghiera%d" % sx, (sx * (X - 0.25), (y0 + y1) / 2, 12.55), (0.5, y1 - y0, 1.1))


# --- pavimento e altare ---------------------------------------------------------------------------
RUNE_R0, RUNE_R1 = 33.0, 35.0


def pavimento(m):
    rng = random.Random(600)
    pa = m.part("Arena_Pavimento", "SabbiaDuello")
    pc = m.part("Arena_Pavimento_Cerchio", "PietraVulcanica")
    pk = m.part("Arena_Pavimento_Spicchi", "Spicchi")
    po = m.part("Arena_Pavimento_Rune", "OroAntico")
    Rv = R_IN / math.cos(math.radians(22.5)) + 0.5
    pts = [(Rv * math.cos(math.radians(-90 + 22.5 + 45 * k)), Rv * math.sin(math.radians(-90 + 22.5 + 45 * k))) for k in range(8)]
    L.prism(pa, pts, -1.0, 0.0)
    # anello di rune: conci curvi (lastre) fra 33 e 35 m, glifi d'oro incassati
    n = 64
    for i in range(n):
        a = 2 * math.pi * (i + 0.5) / n
        rr = (RUNE_R0 + RUNE_R1) / 2
        rot = Matrix.Rotation(a + math.pi / 2, 3, "Z")
        K._block(pc, Vector((rr * math.cos(a), rr * math.sin(a), 0.0)), (2 * math.pi * rr / n - 0.05, RUNE_R1 - RUNE_R0, 0.3), rot, 0.04,
                 rng.random(), vis=((0, 0, 1),), drop=((0, 0, -1),))
        # glifo: due o tre tratti d'oro
        Rg = Matrix.Translation((rr * math.cos(a), rr * math.sin(a), 0.155)) @ rot.to_4x4()
        g = random.Random(i)
        for _ in range(g.randint(2, 3)):
            ang = g.choice((0, 0.5, -0.5, 1.5708))
            L.box(po, Rg @ Vector((g.uniform(-0.6, 0.6), g.uniform(-0.4, 0.4), 0)), (g.uniform(0.6, 1.2), 0.12, 0.02),
                  rot=rot @ Matrix.Rotation(ang, 3, "Z"))
    # medaglione centrale di 7 m
    for i in range(16):
        a = 2 * math.pi * (i + 0.5) / 16
        rot = Matrix.Rotation(a + math.pi / 2, 3, "Z")
        K._block(pc, Vector((5.5 * math.cos(a), 5.5 * math.sin(a), 0.0)), (2 * math.pi * 5.5 / 16 - 0.05, 3.0, 0.3), rot, 0.04,
                 rng.random(), vis=((0, 0, 1),), drop=((0, 0, -1),))
    L.lathe(pc, [(0.0, 0.15), (4.0, 0.15), (4.0, 0.0)], 24, smooth=False, close=False)
    K.tint_fill(pc)
    L.torus(po, (0, 0, 0.15), 3.5, 0.1, nR=48, nr=4, scale=(1, 0.3))
    L.prism(po, [(0.0, 2.6), (0.5, 0.5), (2.6, 0.0), (0.5, -0.5), (0.0, -2.6), (-0.5, -0.5), (-2.6, 0.0), (-0.5, 0.5)], 0.15, 0.18)
    # 8 spicchi colorati fra il medaglione e le rune, divisi da file di lastre
    r0, r1 = 7.3, RUNE_R0 - 0.3
    seg = 10
    for j in range(8):
        a0 = math.radians(-90 + 45 * j + 1.6)
        a1 = math.radians(-90 + 45 * (j + 1) - 1.6)
        verts, faces, uvs = [], [], []
        for i in range(seg + 1):
            t = i / seg
            a = a0 + (a1 - a0) * t
            for r in (r0, r1):
                verts.append((r * math.cos(a), r * math.sin(a), 0.06))
        base = len(pk.v)
        pk.v.extend(verts)
        for i in range(seg):
            u0 = (j + 0.05 + 0.9 * i / seg) / 8.0
            u1 = (j + 0.05 + 0.9 * (i + 1) / seg) / 8.0
            pk.f.append(([base + i * 2, base + i * 2 + 1, base + i * 2 + 3, base + i * 2 + 2], False,
                         [(u0, 0.03), (u0, 0.97), (u1, 0.97), (u1, 0.03)]))
        # fila di lastre sul confine
        a = math.radians(-90 + 45 * j)
        rot = Matrix.Rotation(a, 3, "Z")
        r = r0 - 0.2
        while r < r1:
            ln = min(rng.uniform(1.3, 2.2), r1 - r)
            K._block(pc, Vector(((r + ln / 2) * math.cos(a), (r + ln / 2) * math.sin(a), 0.0)), (ln - 0.04, 1.1, 0.3), rot, 0.04,
                     rng.random(), vis=((0, 0, 1),), drop=((0, 0, -1),))
            r += ln
    K.tint_fill(pc)
    for k, r in enumerate((0.0, math.pi / 4)):
        m.col("Pavimento%d" % k, (0, 0, -0.5), (2 * R_IN, 2 * R_IN, 1.0), Matrix.Rotation(r + math.pi / 8, 3, "Z"))


ALTARE = Vector((0, PY1 + 22.0, 0))


def altare(m):
    rng = random.Random(700)
    pa = m.part("Arena_Altare", "Basalto")
    pd = m.part("Arena_Altare_Drappo", "TelaRossa")
    pz = m.part("Arena_Altare_Bronzo", "Bronzo")
    pe = m.part("Arena_Altare_Braci", "MAT_Ember")
    c = ALTARE
    # tre gradini ottagonali da 0,3 m
    for i, r in enumerate((6.0, 5.2, 4.4)):
        n = 8
        for k in range(n):
            a = 2 * math.pi * (k + 0.5) / n + math.pi / 8
            rot = Matrix.Rotation(a + math.pi / 2, 3, "Z")
            rr = r - 0.8
            K._block(pa, c + Vector((rr * math.cos(a), rr * math.sin(a), 0.15 + 0.3 * i)), (2 * r * math.tan(math.pi / n) + 0.05, 1.6, 0.3),
                     rot, 0.03, rng.random(), vis=((0, -1, 0), (0, 0, 1)))
        K.tint_fill(pa)
        L.lathe(pa, [(r - 1.5, 0.3 * i + 0.29), (0.0, 0.3 * i + 0.29)], 8, c=c, a0=math.pi / 8, a1=math.pi / 8 + 2 * math.pi, smooth=False, close=False)
        K.tint_fill(pa)
    # blocco dell'altare: zoccolo, corpo, lastra
    z = 0.9
    K._block(pa, c + Vector((0, 0, z + 0.15)), (3.6, 2.0, 0.3), None, 0.05, rng.random())
    K._block(pa, c + Vector((0, 0, z + 0.65)), (3.1, 1.5, 0.7), None, 0.05, rng.random())
    K._block(pa, c + Vector((0, 0, z + 1.15)), (3.5, 1.9, 0.3), None, 0.05, rng.random())
    # rune rosse incise sui fianchi lunghi del blocco (Neon)
    pr = m.part("Arena_Altare_Rune", "MAT_Ember")
    for sy in (-1, 1):
        g = random.Random(71 + sy)
        for i in range(7):
            x = -1.2 + i * 0.4
            for _ in range(2):
                L.box(pr, c + Vector((x + g.uniform(-0.06, 0.06), sy * 0.755, z + 0.65 + g.uniform(-0.15, 0.15))),
                      (0.05, 0.02, g.uniform(0.12, 0.3)), rot=Matrix.Rotation(g.choice((0, 0.5, -0.5)), 3, "Y"))
    # drappo rosso: sopra la lastra, ricade davanti e dietro
    w = 1.3
    prof = [(-1.25, z + 0.55), (-1.02, z + 0.95), (-0.98, z + 1.31), (0.98, z + 1.31), (1.02, z + 0.95), (1.25, z + 0.55)]
    for s in (0, 1):
        verts = []
        for (yy, zz) in prof:
            for x in (-w / 2, w / 2):
                verts.append(c + Vector((x, yy * (1.0 + 0.02 * s), zz + 0.02 * s)))
        faces = []
        for i in range(len(prof) - 1):
            q = [i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2]
            faces.append(q if s == 0 else q[::-1])
        pd.add_raw([tuple(v) for v in verts], faces)
    # coppa di bronzo con le braci e il segnaposto delle corna (Meshy: CornaAltare)
    q = c + Vector((0, 0, z + 1.3))
    L.lathe(pz, [(0.0, 0.0), (0.3, 0.0), (0.18, 0.12), (0.2, 0.25), (0.55, 0.45), (0.6, 0.52), (0.0, 0.42)], 14, c=q)
    L.lathe(pe, [(0.0, 0.48), (0.45, 0.46), (0.2, 0.6), (0.0, 0.62)], 10, c=q)
    m.marker("FX_Fire_Altare", q + Vector((0, 0, 0.65)))
    ph = m.part("PLACEHOLDER_CornaAltare", "Basalto")
    for sx in (-1, 1):
        L.box(ph, c + Vector((sx * 1.2, 0.5, z + 1.3 + 1.25)), (0.5, 0.5, 2.5))
    m.marker("SPOT_Altare", c + Vector((0, -1.6, 0.9)))
    m.col("AltareGradini", c + Vector((0, 0, 0.45)), (8.8, 8.8, 0.9))
    m.col("Altare", c + Vector((0, 0, z + 0.65)), (3.6, 2.0, 1.3))


# --- isola: roccia, prato, sentiero, arrivo, isolette ----------------------------------------------
from mathutils import noise as MN


def fbm(q, scale, octaves=4):
    return MN.fractal(Vector(q) * scale, 0.6, 2.0, octaves, noise_basis="PERLIN_ORIGINAL")


def path_flat(x, y):
    """1 sul sentiero e attorno all'arrivo (prato piano), 0 lontano"""
    d = 1e9
    if -175.0 < y < -95.0:
        d = abs(x) - 6.0
    d = min(d, (Vector((x, y)) - ARRIVO.to_2d()).length - 14.0)
    return 1.0 - max(0.0, min(1.0, d / 14.0))


def prato_z(x, y):
    r = math.hypot(x, y)
    t = math.atan2(y, x)
    h = top_height(r, t) + 0.8 * fbm((x, y, 0), 0.04)
    if r < R_OUT + 12:
        h *= max(0.0, (r - R_OUT - 4) / 8)
    return h * (1.0 - path_flat(x, y))


def isola_roccia(m, pieces=4, na=232, nr=46):
    """sotto: cono rovesciato a strati con spostamento a rumore; il bordo e' una parete di roccia"""
    rim_top = []
    per = na // pieces
    for k in range(pieces):
        p = m.part("Isola_Roccia_%02d" % (k + 1), "RocciaIsola")
        verts, faces = [], []
        cols = per + 1
        for ri in range(nr + 1):
            u = ri / nr
            for i in range(k * per, k * per + cols):
                t = 2 * math.pi * i / na
                R = island_outline(t)
                if ri == nr:
                    r = R
                    z = prato_z(r * math.cos(t), r * math.sin(t)) - 0.3
                elif ri == nr - 1:
                    r = R * 0.995
                    z = prato_z(r * math.cos(t), r * math.sin(t)) - 7.0
                else:
                    uu = u / ((nr - 1) / nr)
                    r = R * uu
                    z = min(bottom_depth(r, t), -9.0)
                q = Vector((r * math.cos(t), r * math.sin(t), z))
                if ri < nr - 1 and r > 1:
                    # strati: sporgenze orizzontali e rientranze
                    d = 7.0 * fbm(q, 0.012) + 2.5 * fbm(q, 0.05) + 1.8 * math.sin(z * 0.45 + 2 * fbm(q, 0.02))
                    dirv = Vector((math.cos(t), math.sin(t), 0)) * 0.8 + Vector((0, 0, -0.6))
                    q = q + dirv * d
                elif ri == nr - 1:
                    q = q + Vector((math.cos(t), math.sin(t), 0)) * (1.5 * fbm(q, 0.08))
                verts.append(tuple(q))
        for ri in range(nr):
            for i in range(per):
                a = ri * cols + i
                faces.append([a, a + cols, a + cols + 1, a + 1])
        p.add_raw(verts, faces, smooth=True)
    # speroni e stalattiti che pendono sotto, radici di pietra dal bordo
    ps = m.part("Isola_Roccia_Speroni", "RocciaIsola")
    rnd = random.Random(5)
    for (x, y, z, ln, rr) in spires(5, 24, 0.12, 0.8):
        top = Vector((x, y, z + 4))
        segs, nn = 6, 8
        verts, faces = [], []
        for si in range(segs + 1):
            t = si / segs
            rad = rr * (1 - t) ** 1.3 + 0.2
            cz = top + Vector((rnd.uniform(-0.8, 0.8) * t * 4, rnd.uniform(-0.8, 0.8) * t * 4, -ln * t))
            for i in range(nn):
                a = 2 * math.pi * i / nn
                off = Vector((math.cos(a), math.sin(a), 0)) * rad * (1 + 0.35 * fbm(cz + Vector((math.cos(a), math.sin(a), 0)) * 3, 0.2))
                verts.append(tuple(cz + off))
        for si in range(segs):
            for i in range(nn):
                a, b = si * nn + i, si * nn + (i + 1) % nn
                faces.append([a, b, b + nn, a + nn])
        ps.add_raw(verts, faces, smooth=True)
    for i in range(12):
        t = rnd.uniform(0, 2 * math.pi)
        R = island_outline(t)
        a = Vector((R * 0.97 * math.cos(t), R * 0.97 * math.sin(t), -6.0))
        pts = [a]
        cur = a.copy()
        for s in range(6):
            cur = cur + Vector((math.cos(t) * rnd.uniform(1, 4), math.sin(t) * rnd.uniform(1, 4), -rnd.uniform(5, 10)))
            pts.append(cur.copy())
        L.tube(ps, L.smooth_path(pts, 3), rnd.uniform(1.6, 2.6), n=6, taper=0.85)
    # cascate dal bordo (lati e retro, mai davanti all'arrivo)
    for i, deg in enumerate((200, 330, 25, 110)):
        t = math.radians(deg)
        R = island_outline(t)
        m.marker("SPOT_Cascata%d" % (i + 1), (R * math.cos(t), R * math.sin(t), prato_z(R * 0.98 * math.cos(t), R * 0.98 * math.sin(t)) - 0.5))


def isola_prato(m, na=144, nr=24):
    p = m.part("Isola_Prato", "PratoAlto")
    verts, faces = [], []
    r_in = R_OUT - 2.0
    for ri in range(nr + 1):
        u = ri / nr
        for i in range(na):
            t = 2 * math.pi * i / na
            R = island_outline(t)
            r = r_in + (R - r_in) * (u ** 0.85)
            x, y = r * math.cos(t), r * math.sin(t)
            verts.append((x, y, prato_z(x, y)))
    for ri in range(nr):
        for i in range(na):
            a, b = ri * na + i, ri * na + (i + 1) % na
            faces.append([a, b, b + na, a + na])
    p.add_raw(verts, faces, smooth=True)
    # rocce in piedi verso il bordo
    pr = m.part("Isola_Rocce", "RocciaIsola")
    rnd = random.Random(9)
    for _ in range(18):
        t = rnd.uniform(0, 2 * math.pi)
        if abs(math.atan2(math.sin(t + math.pi / 2), math.cos(t + math.pi / 2))) < 0.45:
            continue
        r = island_outline(t) * rnd.uniform(0.7, 0.92)
        x, y = r * math.cos(t), r * math.sin(t)
        h = rnd.uniform(6, 22)
        base = Vector((x, y, prato_z(x, y) - 2))
        lean = Vector((rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15), 1)).normalized()
        nn, segs = 7, 5
        r0 = rnd.uniform(3, 7)
        verts, faces = [], []
        for si in range(segs + 1):
            s = si / segs
            c = base + lean * h * s
            rad = r0 * (1 - 0.6 * s)
            for i in range(nn):
                a = 2 * math.pi * i / nn + rnd.uniform(-0.15, 0.15)
                verts.append(tuple(c + Vector((math.cos(a), math.sin(a), 0)) * rad * (1 + 0.3 * fbm(c * 0.3 + Vector((i, 0, 0)), 0.5))))
        for si in range(segs):
            for i in range(nn):
                a, b = si * nn + i, si * nn + (i + 1) % nn
                faces.append([a, b, b + nn, a + nn])
        top = len(verts)
        verts.append(tuple(base + lean * h * 1.05))
        for i in range(nn):
            faces.append([segs * nn + i, segs * nn + (i + 1) % nn, top])
        pr.add_raw(verts, faces, smooth=True)
    for k, r in enumerate((0.0, math.pi / 4)):
        m.col("Prato%d" % k, (0, 0, -2.0), (300.0, 300.0, 4.0), Matrix.Rotation(r + math.pi / 8, 3, "Z"))


def sentiero(m):
    rng = random.Random(800)
    p = m.part("Isola_Sentiero", "PietraVulcanica")
    y0, y1 = ARRIVO.y + 8.6, PY0 - 0.2
    K.slabs(p, Matrix.Identity(4), -2.0, 2.0, y0, y1, 0.12, rng, th=0.3, lmin=0.8, lmax=1.5)
    # cordoli
    for sx in (-1, 1):
        y = y0
        while y < y1 - 0.2:
            ln = min(rng.uniform(1.5, 2.6), y1 - y)
            K._block(p, Vector((sx * 2.2, y + ln / 2, 0.05)), (0.4, ln - 0.04, 0.4), None, 0.05, rng.random(),
                     chip=0.3 if rng.random() < 0.3 else 0.0, rng=rng, drop=((0, 0, -1),))
            y += ln
    K.tint_fill(p)
    # quattro pilastrini con le braci lungo il sentiero
    pz = m.part("Isola_Sentiero_Bronzo", "Bronzo")
    pe = m.part("Isola_Sentiero_Braci", "MAT_Ember")
    for i, y in enumerate((y0 + 12, y0 + 34)):
        for sx in (-1, 1):
            c = Vector((sx * 3.6, y, 0))
            K._block(p, c + Vector((0, 0, 0.9)), (0.9, 0.9, 1.8), None, 0.06, rng.random(), drop=((0, 0, -1),))
            K._block(p, c + Vector((0, 0, 1.95)), (1.15, 1.15, 0.3), None, 0.05, rng.random())
            L.lathe(pz, [(0.0, 2.1), (0.25, 2.1), (0.5, 2.4), (0.55, 2.5), (0.0, 2.4)], 10, c=c)
            L.lathe(pe, [(0.0, 2.45), (0.4, 2.42), (0.2, 2.55), (0.0, 2.6)], 8, c=c)
            m.marker("FX_Fire_Sentiero%d" % (i * 2 + (sx > 0) + 1), c + Vector((0, 0, 2.7)))
    K.tint_fill(p)
    m.col("Sentiero", (0, (y0 + y1) / 2, -0.4), (5.0, y1 - y0, 1.0))


def arrivo(m):
    rng = random.Random(900)
    p = m.part("Arrivo", "PietraVulcanica")
    po = m.part("Arrivo_Rune", "OroAntico")
    pz = m.part("Arrivo_Bronzo", "Bronzo")
    pe = m.part("Arrivo_Braci", "MAT_Ember")
    c = ARRIVO - Vector((0, 0, ARRIVO.z))
    # tre gradini da 0,3 m: anelli di conci curvi
    for i, (r0, r1) in enumerate(((7.2, 8.0), (6.4, 7.2), (5.2, 6.4))):
        n = 24 - 4 * i
        for k in range(n):
            a = 2 * math.pi * (k + 0.5) / n + i * 0.2
            rot = Matrix.Rotation(a + math.pi / 2, 3, "Z")
            rr = (r0 + r1) / 2
            K._block(p, c + Vector((rr * math.cos(a), rr * math.sin(a), 0.3 * i + 0.15 - 0.15)), (2 * math.pi * r1 / n + 0.02, r1 - r0 + 0.02, 0.6),
                     rot, 0.04, rng.random(), chip=0.25 if rng.random() < 0.3 else 0.0, rng=rng, vis=((0, -1, 0), (0, 0, 1)), drop=((0, 0, -1),))
    # piano: lastre a raggiera
    for k in range(12):
        a = 2 * math.pi * (k + 0.5) / 12
        rot = Matrix.Rotation(a + math.pi / 2, 3, "Z")
        K._block(p, c + Vector((3.6 * math.cos(a), 3.6 * math.sin(a), 0.75)), (2 * math.pi * 5.2 / 12 - 0.05, 3.2, 0.3), rot, 0.04,
                 rng.random(), vis=((0, 0, 1),), drop=((0, 0, -1),))
    K.tint_fill(p)
    L.lathe(p, [(0.0, 0.9), (2.0, 0.9), (2.0, 0.6)], 16, c=c, smooth=False, close=False)
    K.tint_fill(p)
    # cerchio di rune d'oro e rosa dei venti
    L.torus(po, c + Vector((0, 0, 0.9)), 4.9, 0.08, nR=48, nr=4, scale=(1, 0.3))
    L.torus(po, c + Vector((0, 0, 0.9)), 2.15, 0.08, nR=32, nr=4, scale=(1, 0.3))
    for k in range(16):
        a = 2 * math.pi * k / 16
        g = random.Random(k)
        L.box(po, c + Vector((3.6 * math.cos(a), 3.6 * math.sin(a), 0.91)), (g.uniform(0.5, 0.9), 0.1, 0.02),
              rot=Matrix.Rotation(a + g.choice((0, 0.6, -0.6, 1.57)), 3, "Z"))
    L.prism(po, [(0.0, 1.8), (0.35, 0.35), (1.8, 0.0), (0.35, -0.35), (0.0, -1.8), (-0.35, -0.35), (-1.8, 0.0), (-0.35, 0.35)],
            0.9, 0.93, M=Matrix.Translation(c))
    # quattro obelischi bassi con le braci
    for k in range(4):
        a = math.radians(45 + 90 * k)
        q = c + Vector((9.4 * math.cos(a), 9.4 * math.sin(a), 0))
        rot = Matrix.Rotation(a, 3, "Z")
        K._block(p, q + Vector((0, 0, 0.3)), (1.6, 1.6, 0.6), rot, 0.05, rng.random(), drop=((0, 0, -1),))
        K.tint_fill(p)
        L.lathe(p, [(0.0, 0.6), (0.62, 0.6), (0.48, 3.2), (0.6, 3.35), (0.6, 3.5), (0.0, 3.5)], 4, c=q, a0=a + math.pi / 4,
                a1=a + math.pi / 4 + 2 * math.pi, smooth=False)
        K.tint_fill(p)
        L.lathe(pz, [(0.0, 3.5), (0.3, 3.5), (0.55, 3.8), (0.6, 3.9), (0.0, 3.8)], 10, c=q)
        L.lathe(pe, [(0.0, 3.85), (0.45, 3.82), (0.2, 3.95), (0.0, 4.0)], 8, c=q)
        m.marker("FX_Fire_Arrivo%d" % (k + 1), q + Vector((0, 0, 4.1)))
    m.marker("SPOT_Arrivo", c + Vector((0, 0, 0.9)))
    m.marker("FX_Light_Arrivo", c + Vector((0, 0, 3.0)))
    for k, r in enumerate((0.0, math.pi / 4)):
        m.col("Arrivo%d" % k, c + Vector((0, 0, 0.45)), (15.0, 15.0, 0.9), Matrix.Rotation(r + math.pi / 8, 3, "Z"))


def isolette(m):
    rng = random.Random(1000)
    pv = m.part("Isolette_Rovine", "PietraVulcanica")
    pz = m.part("Isolette_Bronzo", "Bronzo")
    for n, ((cx, cy), z0, R) in enumerate(ISOLETTE):
        c = Vector((cx, cy, z0))
        pr = m.part("Isoletta_%d" % (n + 1), "RocciaIsola")
        pg = m.part("Isoletta_%d_Prato" % (n + 1), "PratoAlto")
        na, nr = 36, 11
        verts, faces = [], []
        top = []
        for ri in range(nr + 1):
            u = ri / nr
            for i in range(na):
                t = 2 * math.pi * i / na
                Rr = R * (1 + 0.15 * noise1(n * 7 + 1, t))
                if ri == nr:
                    q = c + Vector((Rr * math.cos(t), Rr * math.sin(t), -0.4))
                else:
                    r = Rr * (u ** 0.6)
                    depth = -R * 1.5 * (1 - u ** 1.3)
                    q = c + Vector((r * math.cos(t), r * math.sin(t), depth - 3))
                    q = q + Vector((math.cos(t), math.sin(t), -0.4)) * (R * 0.12 * fbm(q, 0.04) + 1.2 * math.sin(q.z * 0.5))
                verts.append(tuple(q))
        for ri in range(nr):
            for i in range(na):
                a, b = ri * na + i, ri * na + (i + 1) % na
                faces.append([a, a + na, b + na, b])
        pr.add_raw(verts, faces, smooth=True)
        # prato in cima (disco a rumore)
        gv, gf = [tuple(c + Vector((0, 0, 0.3)))], []
        for i in range(na):
            t = 2 * math.pi * i / na
            Rr = R * (1 + 0.15 * noise1(n * 7 + 1, t))
            for ring in (0.55, 1.0):
                rr = Rr * ring
                hz = 0.0 if ring == 1.0 else 0.6 * fbm(c + Vector((rr * math.cos(t), rr * math.sin(t), 0)), 0.1)
                gv.append(tuple(c + Vector((rr * math.cos(t), rr * math.sin(t), hz))))
        for i in range(na):
            a0, a1 = 1 + 2 * i, 1 + 2 * ((i + 1) % na)
            gf.append([0, a0, a1])
            gf.append([a0, a0 + 1, a1 + 1, a1])
        pg.add_raw(gv, gf, smooth=True)
        # rovine: colonne spezzate, un arco rotto, lastre
        ang = rng.uniform(0, 2 * math.pi)
        for i in range(rng.randint(3, 5)):
            a = ang + i * 0.7
            q = c + Vector((R * 0.45 * math.cos(a), R * 0.45 * math.sin(a), 0))
            h = rng.uniform(1.5, 6.5)
            K._block(pv, q + Vector((0, 0, 0.35)), (1.8, 1.8, 0.7), Matrix.Rotation(a, 3, "Z"), 0.06, rng.random(), chip=0.4, rng=rng)
            K.tint_fill(pv)
            prof = [(0.62, 0.7), (0.55, 0.9), (0.55, h - 0.3), (0.5, h)]
            L.lathe(pv, prof, 10, c=q, smooth=True, close=False)
            K.tint_fill(pv)
            if rng.random() < 0.5:     # rocchio caduto
                d = Vector((math.cos(a + 1.2), math.sin(a + 1.2), 0))
                L.cyl(pv, q + d * 2.0 + Vector((0, 0, 0.5)), q + d * 4.2 + Vector((0, 0, 0.55)), 0.55, n=10)
                K.tint_fill(pv)
        Ma = Matrix.Translation(c + Vector((-R * 0.2 * math.cos(ang), -R * 0.2 * math.sin(ang), 0))) @ Matrix.Rotation(ang, 4, "Z")
        for sx in (-1, 1):
            K._block(pv, Ma @ Vector((sx * 3.3, 0, 2.6)), (1.4, 1.4, 5.2), Ma.to_3x3(), 0.06, rng.random(), chip=0.3, rng=rng)
        rr = random.Random(n)
        K.arch(pv, Ma @ Matrix.Translation((0, -0.6, 0)), 0, 5.2, 2.6, 3.4, 0, 1.2, rr, n=9)
        # toglie i conci di un fianco (arco crollato): tieni solo quelli aggiunti finora
        K.tint_fill(pv)
        # anello di bronzo del posatoio su un cippo
        q = c + Vector((R * 0.15 * math.cos(ang + 3), R * 0.15 * math.sin(ang + 3), 0))
        K._block(pv, q + Vector((0, 0, 1.2)), (1.4, 1.4, 2.4), None, 0.06, rng.random(), chip=0.3, rng=rng)
        L.torus(pz, q + Vector((0, 0, 3.0)), 1.1, 0.15, normal=(1, 0, 0), nR=18, nr=6)
        L.box(pz, q + Vector((0, 0, 2.5)), (0.5, 0.5, 0.3))
        m.marker("SPOT_PosatoioIsola%d" % (n + 1), q + Vector((0, 0, 4.4)))
        m.col("Isoletta%d" % (n + 1), c + Vector((0, 0, -1.0)), (R * 1.4, R * 1.4, 2.0))


# --- montaggio, cottura, anteprime ---------------------------------------------------------------
VARIANTE = {k: ("A" if k % 2 else "B") for k in range(8)}


def modello(m, solo=None):
    want = (lambda s: solo is None or s in solo)
    if want("arena"):
        for k in range(8):
            lato(m, k, VARIANTE[k])
        for j in range(8):
            torre(m, j)
        portale(m)
        palco(m)
        pavimento(m)
        altare(m)
        # anello del posatoio 1 sopra l'attico del portale
        pz = m.part("Arena_Portale_Bronzo", "Bronzo")
        L.torus(pz, Vector((0, PY0 + 2.0, 43.4)), 1.3, 0.16, normal=(0, 1, 0), nR=20, nr=6)
        L.box(pz, Vector((0, PY0 + 2.0, 42.7)), (0.6, 0.6, 0.6))
        m.marker("SPOT_Posatoio1", Vector((0, PY0 + 2.0, 44.8)))
        # collisioni delle mura: muro esterno, gradoni (rampa), camminamento, parapetto
        for k in range(8):
            Rz = Matrix.Rotation(math.radians(45 * k), 3, "Z")
            spans = [(-30.0, -GATE_HALF), (GATE_HALF, 30.0)] if k == 0 else [(-30.0, 30.0)]
            for i, (xa, xb) in enumerate(spans):
                cx = (xa + xb) / 2
                w = xb - xa
                m.col("Mura%d_%d" % (k + 1, i), Rz @ Vector((cx, -(R_OUT - 2.3), Z_DECK / 2 - 1)), (w, 4.6, Z_DECK + 2), Rz)
                m.col("Camminamento%d_%d" % (k + 1, i), Rz @ Vector((cx, -(R_IN + 14.0 + R_OUT - 4.6) / 2, Z_DECK - 0.5)),
                      (w, R_OUT - 4.6 - R_IN - 14.0 + 0.2, 1.0), Rz)
                m.col("Parapetto%d_%d" % (k + 1, i), Rz @ Vector((cx, -(R_OUT - 1.0), Z_PARA + 0.5)), (w, 2.0, 3.0), Rz)
                m.col("Podio%d_%d" % (k + 1, i), Rz @ Vector((cx * 0.95, -(R_IN + 1.0), Z_POD / 2)), (w * 0.95 - 4, 2.0, Z_POD + 0.55), Rz)
                m.ramp("Gradoni%d_%d" % (k + 1, i), Rz @ Vector((cx, -(R_IN + 2.0), Z_POD + 0.55)), Rz @ Vector((cx, -(R_IN + 14.0), Z_DECK)), w - 6)
    if want("isola"):
        isola_roccia(m)
        isola_prato(m)
        sentiero(m)
        arrivo(m)
    if want("isolette"):
        isolette(m)


# pezzi da cuocere: nome -> (aspetto); i lati uguali (stessa variante) e le torri condividono la cottura
LOOK_MURA = {"dirt_z0": -2.0, "dirt_z1": 9.0, "moss": 0.55, "streak": 0.4}
LOOK_PIANO = {"dirt_z0": -1.0, "dirt_z1": 1.0, "dirt": 0.2, "moss": 0.25, "streak": 0.0}


def cuoci(objs, texdir, res=1024):
    import cottura as C
    by = {o.name: o for o in objs}
    done = {}
    jobs = []
    for o in objs:
        mat = o.data.materials[0].name
        if mat not in ("PietraVulcanica", "Basalto") or o.name.startswith("PLACEHOLDER"):
            continue
        n = o.name
        if n.startswith("Arena_Mura_"):
            k = int(n[11:13]) - 1
            key = ("mura", 0 if k == 0 else VARIANTE[k], n[14:])
            look = LOOK_MURA
        elif n.startswith("Arena_Torre_"):
            key = ("torre",)
            look = LOOK_MURA
        elif n in ("Arena_Pavimento_Cerchio", "Isola_Sentiero", "Arrivo", "Arena_Portale_Passaggio"):
            key = (n,)
            look = LOOK_PIANO
        else:
            key = (n,)
            look = dict(LOOK_MURA, dirt_z1=4.0)
        jobs.append((key, o, mat, look))
    for key, o, mat, look in jobs:
        if key in done:
            C.share_bake(done[key], o)
        else:
            nm = "Cotto_" + "_".join(str(x) if x != 0 else "Portale" for x in key)
            big = key[0] in ("mura", "torre") or o.name in ("Arena_Portale", "Arena_Portale_Volta")
            C.bake_piece(o, mat, texdir, texdir, nm, res=res if big else res // 2, look=look)
            done[key] = o
    return done


def _main():
    args = L.argv()
    fase = args[args.index("--fase") + 1] if "--fase" in args else "sagoma"
    L.clear_scene()
    m = L.Model("IsolaDraghi")
    if fase == "sagoma":
        sagoma(m)
        import bpy
        coll = bpy.data.collections.new("Sagoma")
        bpy.context.scene.collection.children.link(coll)
        objs = [L.build_object(p, coll, os.path.join(L.CLOUD, m.name, "Textures"), sharp_deg=30) for p in m.parts.values()]
        if "--render" in args:
            render_sagome(m, objs)
        return
    solo = args[args.index("--solo") + 1].split(",") if "--solo" in args else None
    modello(m, solo)
    for k, p in m.parts.items():
        t = p.tris()
        if t > 15000:
            print("  pezzo grande: %s %d" % (k, t))
    bake = "--niente-cottura" not in args
    res = int(args[args.index("--res") + 1]) if "--res" in args else 1024
    objs, cobs, info = L.export(m, before_fbx=(lambda o, d: cuoci(o, d, res)) if bake else None)
    if "--render" in args:
        anteprime(m, objs, info)


VISTE = {
    # nome: (camera, bersaglio, focale) in metri (Blender: Z in alto, ingresso verso -Y)
    "davanti": ((0, -640, 70), (0, 0, -25), 30),
    "tre_quarti": ((-440, -460, 190), (0, 0, -15), 30),
    "dietro": ((60, 620, 90), (0, 0, -25), 30),
    "alto": ((0, -80, 820), (0, 0, 0), 30),
    "arena": ((175, -235, 95), (0, -15, 8), 28),
    "portale": ((16, -150, 5), (0, -96, 22), 24),
    "dentro": ((-38, 30, 26), (0, -80, 14), 24),
    "umano": ((7, -121, 2.2), (0, -100, 9), 26),
    "dettaglio": ((58, -130, 3.5), (38, -92, 12), 26),
    "arrivo": ((-14, -186, 6), (0, -160, 1), 28),
}
UMANI = [(0.6, -108.0), (44.0, -104.0), (2.0, -163.0), (-1.5, -62.0)]


def anteprime(m, objs, info):
    """JPG 1280x720 (<400 KB) in cloud/IsolaDraghi/anteprime/"""
    import anteprime as A
    umani = []
    for x, y in UMANI:
        z = 0.12 if abs(x) < 3 else prato_z(x, y)
        if (Vector((x, y)) - ARRIVO.to_2d()).length < 6:
            z = 0.9
        umani.append((x, y, z))
    A.render(m.name, VISTE, umani)

if __name__ == "__main__":
    _main()
