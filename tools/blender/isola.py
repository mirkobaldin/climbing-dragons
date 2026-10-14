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
GATE_HALF = GATE_W / 2 + 14.0   # sul lato del portale le mura finiscono qui (piloni)


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
        K.ashlar(pi, M @ Matrix.Translation((0, -R_IN, 0)), max(xa, -R_IN * T + 0.3), min(xb, R_IN * T - 0.3), 0.0, Z_POD, rng,
                 course=1.0, depth=0.8, face_y=-0.8 + 0.8, missing=dmg * 0.5)
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
                             chip=0.3 if rng.random() < 0.3 else 0.0, rng=rng)
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
            K._block(pi, M @ Vector((0, -(R_IN + 1.0 + run * (i + 0.5)), z1 - 0.15)), (2.2, run + 0.02, 0.3), M.to_3x3(), 0.02, rng.random())
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
if __name__ == "__main__":
    _main()
