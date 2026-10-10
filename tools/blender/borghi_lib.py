# Libreria per i modelli dei borghi (vedi borghi.py): materiali, raccoglitore di geometria,
# tetti curvi, muri con le aperture vere, scale, solai, finestre, porte, arredi.
# Unita': 1 unita' di Blender = 1 stud. L'ingresso di ogni edificio guarda verso -Y.

import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix

# ---------------------------------------------------------------------------------------
# materiali (in Studio il suffisso del nome del pezzo da' colore e materiale Roblox)

MATS = {
    "TILE": (0.13, 0.14, 0.16),       # coppi del tetto principale (collisione a scafo)
    "SKIRT": (0.13, 0.14, 0.16),      # tettoie tra i piani (stesso colore, niente collisione)
    "RIDGE": (0.07, 0.07, 0.08),
    "RIDGEWHITE": (0.80, 0.80, 0.78), # bordo bianco dei colmi (Fenghuang)
    "TIMBER": (0.30, 0.17, 0.09),
    "TIMBERDARK": (0.12, 0.07, 0.04),
    "WOOD": (0.52, 0.35, 0.19),       # pavimenti e assi chiari
    "PLASTER": (0.86, 0.83, 0.76),
    "LACQUER": (0.52, 0.05, 0.035),
    "PAPER": (1.0, 0.70, 0.38),       # carta delle finestre (Neon in Roblox)
    "LANTERN": (0.95, 0.12, 0.06),
    "STONE": (0.40, 0.39, 0.37),
    "STONEDARK": (0.25, 0.25, 0.24),
    "EARTH": (0.36, 0.30, 0.24),      # terra battuta (doma)
    "THATCH": (0.47, 0.36, 0.20),
    "TATAMI": (0.62, 0.60, 0.36),
    "BAMBOO": (0.55, 0.45, 0.22),
    "LEAF": (0.16, 0.34, 0.14),
    "GOLD": (0.85, 0.60, 0.18),
    "BRONZE": (0.30, 0.22, 0.12),
    "FABRIC": (0.10, 0.16, 0.32),     # tende noren, cuscini
    "CLOTH": (0.55, 0.08, 0.06),      # stoffe rosse (coperte, striscioni)
    "CERAMIC": (0.75, 0.78, 0.80),    # giare e teiere
    "SIGN": (0.10, 0.12, 0.18),       # tavola per il testo (SurfaceGui in Studio)
    "METAL": (0.70, 0.72, 0.75),      # acciaio delle piccozze
    "IRON": (0.20, 0.21, 0.22),       # ferro scuro (rinforzi, chiodi, cerchi)
    "LEATHER": (0.35, 0.20, 0.10),    # cinghie, zaino
    "GRIP": (0.06, 0.06, 0.06),       # impugnature
    "ROPE": (0.75, 0.62, 0.40),
    "ROCK": (0.38, 0.38, 0.32),       # roccia delle isole volanti
    "GRASS": (0.25, 0.42, 0.16),      # prato in cima alle isole
    "CRYSTAL": (0.85, 0.90, 0.95),    # cristalli (in Roblox prendono il colore del bioma)
    "CLOUD": (0.95, 0.96, 0.98),      # nuvole
    "FRONT": (1.0, 0.0, 1.0),         # segnaposto: davanti all'ingresso (Studio lo toglie)
    "ORIGIN": (0.0, 1.0, 1.0),        # segnaposto: origine del modello (Studio lo toglie)
}

# materiali che fanno da struttura: i loro blocchi diventano collisioni in Roblox
STRUCT = {"TIMBER", "TIMBERDARK", "WOOD", "PLASTER", "LACQUER", "STONE", "STONEDARK", "EARTH", "TATAMI", "BAMBOO"}


# texture (cartella textures/ del progetto, ambientCG 1K): sorgente e tinta (moltiplica il colore)
TEX_SRC = {
    "TILE": ("RoofingTiles013A", 1.7), "SKIRT": ("RoofingTiles013A", 1.7), "RIDGE": ("RoofingTiles013A", 1.0),
    "RIDGEWHITE": ("PaintedPlaster017", 1.0), "PLASTER": ("PaintedPlaster017", 1.0),
    "TIMBER": ("WoodFloor043", 0.9), "TIMBERDARK": ("WoodFloor043", 0.55), "WOOD": ("WoodFloor043", 1.15),
    "LACQUER": ("PaintedWood003", 0.85), "STONE": ("PavingStones054", 1.0), "STONEDARK": ("Rock064", 0.7),
    "THATCH": ("ThatchedRoof002A", 1.0), "BAMBOO": ("Bamboo001C", 1.0), "TATAMI": ("Bamboo001C", (1.15, 1.1, 0.7)),
    "GOLD": ("Metal007", 1.0), "BRONZE": ("Metal007", 0.45), "METAL": ("Metal012", 1.0), "IRON": ("Metal029", 1.0),
    "LEATHER": ("Leather037", 1.0), "GRIP": ("Leather026", 1.0), "ROCK": ("Rock063", 1.0),
    "EARTH": ("Rock063", (0.62, 0.5, 0.38)), "GRASS": ("Rock063", (0.55, 0.9, 0.45)), "ROPE": ("Bamboo001C", (1.3, 1.1, 0.8)),
}
# quanti stud occupa una ripetizione della texture
TEX_SCALE = {
    "TILE": 7, "SKIRT": 7, "RIDGE": 4, "RIDGEWHITE": 6, "PLASTER": 12, "TIMBER": 7, "TIMBERDARK": 6, "WOOD": 8,
    "LACQUER": 6, "STONE": 9, "STONEDARK": 9, "THATCH": 9, "BAMBOO": 4, "TATAMI": 4, "GOLD": 3, "BRONZE": 3,
    "METAL": 2.5, "IRON": 2.5, "LEATHER": 2, "GRIP": 1.5, "ROCK": 22, "EARTH": 12, "GRASS": 14, "ROPE": 1.2,
    "CRYSTAL": 6, "CLOUD": 30,
}
TEXTURES_DIR = None  # cartella delle texture pronte (out/tex): la imposta prepare_textures()


def _tex_file(name, kind):
    if not TEXTURES_DIR:
        return None
    path = os.path.join(TEXTURES_DIR, "%s_%s.jpg" % (name, kind))
    return path if os.path.exists(path) else None


# materiali con l'ombreggiatura liscia (le nuvole a facce piatte sembravano squadrate)
SMOOTH = {"CLOUD"}


def material(name):
    m = bpy.data.materials.get("Borghi_" + name)
    if m:
        return m
    m = bpy.data.materials.new("Borghi_" + name)
    if hasattr(m, "use_nodes") and not m.use_nodes:
        m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    c = MATS[name]
    bsdf.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1)
    bsdf.inputs["Roughness"].default_value = 0.8
    col = _tex_file(name, "Color")
    if col:
        nt = m.node_tree
        img = nt.nodes.new("ShaderNodeTexImage")
        img.image = bpy.data.images.load(col, check_existing=True)
        nt.links.new(img.outputs["Color"], bsdf.inputs["Base Color"])
        rough = _tex_file(name, "Roughness")
        if rough:
            r = nt.nodes.new("ShaderNodeTexImage")
            r.image = bpy.data.images.load(rough, check_existing=True)
            r.image.colorspace_settings.name = "Non-Color"
            nt.links.new(r.outputs["Color"], bsdf.inputs["Roughness"])
        nrm = _tex_file(name, "Normal")
        if nrm:
            n = nt.nodes.new("ShaderNodeTexImage")
            n.image = bpy.data.images.load(nrm, check_existing=True)
            n.image.colorspace_settings.name = "Non-Color"
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(n.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if name in ("PAPER", "LANTERN"):
        try:
            bsdf.inputs["Emission Color"].default_value = (c[0], c[1], c[2], 1)
            bsdf.inputs["Emission Strength"].default_value = 1.5
        except KeyError:
            pass
    m.diffuse_color = (c[0], c[1], c[2], 1)
    return m


def frame_of(d, up=None):
    """Matrice con l'asse Y lungo d (per travi e muri)."""
    d = Vector(d).normalized()
    up = Vector(up) if up else (Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0)))
    right = d.cross(up).normalized()
    up = right.cross(d).normalized()
    return Matrix((right, d, up)).transposed()


# ---------------------------------------------------------------------------------------

class Builder:
    def __init__(self, name):
        self.name = name
        self.geo = {}
        self.remesh = {}  # materiale -> lato del voxel (pezzi fusi in una sola superficie)
        self.fuv = {}  # per materiale: coordinate texture (studs) di ogni faccia, o None (proiezione)
        self.colliders = []  # (centro, misure, rotazione) in coordinate del modello

    def _g(self, m):
        if m not in self.geo:
            self.geo[m] = ([], [])
            self.fuv[m] = []
        return self.geo[m]

    def face_list(self, m, verts, faces, uvs=None, uv_faces=None):
        """uvs: coordinate texture (in stud) di ogni vertice; uv_faces: quante facce (le prime)
        le usano (le altre: proiezione a scatola)."""
        vs, fs = self._g(m)
        o = len(vs)
        vs.extend(Vector(v) for v in verts)
        fs.extend(tuple(i + o for i in f) for f in faces)
        fu = self.fuv[m]
        for k, f in enumerate(faces):
            fu.append(tuple(uvs[i] for i in f) if uvs is not None and (uv_faces is None or k < uv_faces) else None)

    def collider(self, center, size, rot=None):
        self.colliders.append((Vector(center), Vector(size), (rot or Matrix.Identity(3)).copy()))

    def box(self, m, center, size, rot=None, collide=None):
        sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
        R = rot or Matrix.Identity(3)
        c = Vector(center)
        local = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
                 (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)]
        verts = [c + R @ Vector(p) for p in local]
        faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self.face_list(m, verts, faces)
        if collide is None:
            collide = m in STRUCT and min(size) >= 0.3 and size[0] * size[1] * size[2] > 0.8
        if collide:
            self.collider(c, size, R)

    def beam(self, m, p0, p1, w, h, collide=None, up=None):
        p0, p1 = Vector(p0), Vector(p1)
        L = (p1 - p0).length
        if L < 1e-4:
            return
        self.box(m, (p0 + p1) / 2, (w, L, h), frame_of(p1 - p0, up), collide)

    def cyl(self, m, p0, p1, r, n=10, caps=True, collide=False):
        p0, p1 = Vector(p0), Vector(p1)
        d = (p1 - p0)
        if d.length < 1e-4:
            return
        R = frame_of(d)
        a, b = R.col[0], R.col[2]
        verts = []
        for p in (p0, p1):
            for k in range(n):
                t = k / n * math.tau
                verts.append(p + (a * math.cos(t) + b * math.sin(t)) * r)
        faces = [(k, (k + 1) % n, n + (k + 1) % n, n + k) for k in range(n)]
        if caps:
            faces.append(tuple(reversed(range(n))))
            faces.append(tuple(n + k for k in range(n)))
        self.face_list(m, verts, faces)
        if collide:
            self.collider((p0 + p1) / 2, (r * 1.8, d.length, r * 1.8), R)

    def sphere(self, m, c, r, rz=None, seg=10, rings=7):
        c = Vector(c)
        rz = rz or r
        verts = [c + Vector((0, 0, -rz))]
        for i in range(1, rings):
            phi = -math.pi / 2 + math.pi * i / rings
            for k in range(seg):
                t = k / seg * math.tau
                verts.append(c + Vector((math.cos(t) * math.cos(phi) * r, math.sin(t) * math.cos(phi) * r, math.sin(phi) * rz)))
        verts.append(c + Vector((0, 0, rz)))
        faces = [(0, 1 + (k + 1) % seg, 1 + k) for k in range(seg)]
        for i in range(rings - 2):
            a0, a1 = 1 + i * seg, 1 + (i + 1) * seg
            for k in range(seg):
                faces.append((a0 + k, a0 + (k + 1) % seg, a1 + (k + 1) % seg, a1 + k))
        top = len(verts) - 1
        last = 1 + (rings - 2) * seg
        faces += [(last + k, last + (k + 1) % seg, top) for k in range(seg)]
        self.face_list(m, verts, faces)

    def poly(self, m, pts, thick=0.0, normal=None):
        pts = [Vector(p) for p in pts]
        n = len(pts)
        if thick <= 0:
            self.face_list(m, pts, [tuple(range(n))])
            return
        nv = Vector(normal) if normal else (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
        off = nv * thick / 2
        verts = [p + off for p in pts] + [p - off for p in pts]
        faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
        for k in range(n):
            faces.append((k, n + k, n + (k + 1) % n, (k + 1) % n))
        self.face_list(m, verts, faces)

    def shell(self, m, rows, t):
        nu, nv = len(rows), len(rows[0])
        top = [Vector(p) for row in rows for p in row]

        def P(i, j):
            return Vector(rows[max(0, min(nu - 1, i))][max(0, min(nv - 1, j))])

        normals = []
        for i in range(nu):
            for j in range(nv):
                nrm = (P(i, j + 1) - P(i, j - 1)).cross(P(i + 1, j) - P(i - 1, j))
                if nrm.length < 1e-6:
                    nrm = Vector((0, 0, 1))
                nrm.normalize()
                if nrm.z < 0:
                    nrm = -nrm
                normals.append(nrm)
        bottom = [top[k] - normals[k] * t for k in range(len(top))]
        N = len(top)
        faces = []
        for i in range(nu - 1):
            for j in range(nv - 1):
                a, b, c, d = i * nv + j, i * nv + j + 1, (i + 1) * nv + j + 1, (i + 1) * nv + j
                faces.append((a, b, c, d))
                faces.append((N + d, N + c, N + b, N + a))
        n_uv = len(faces)
        edge = [(i, 0) for i in range(nu)] + [(nu - 1, j) for j in range(nv)] + [(i, nv - 1) for i in reversed(range(nu))] + [(0, j) for j in reversed(range(nv))]
        for k in range(len(edge) - 1):
            a = edge[k][0] * nv + edge[k][1]
            b = edge[k + 1][0] * nv + edge[k + 1][1]
            if a != b:
                faces.append((a, N + a, N + b, b))
        # u: distanza lungo la riga (lungo la gronda), v: distanza lungo la colonna (pendenza)
        uv = [None] * N
        for i in range(nu):
            acc = 0.0
            for j in range(nv):
                if j > 0:
                    acc += (top[i * nv + j] - top[i * nv + j - 1]).length
                uv[i * nv + j] = [acc, 0.0]
        for j in range(nv):
            acc = 0.0
            for i in range(nu):
                if i > 0:
                    acc += (top[i * nv + j] - top[(i - 1) * nv + j]).length
                uv[i * nv + j][1] = acc
        uv = [tuple(x) for x in uv]
        self.face_list(m, top + bottom, faces, uvs=uv + uv, uv_faces=n_uv)

    def tube(self, m, pts, r, n=6, taper=None):
        pts = [Vector(p) for p in pts]
        verts, faces = [], []
        for i, p in enumerate(pts):
            d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
            R = frame_of(d)
            a, b = R.col[0], R.col[2]
            rr = r * (taper(i / (len(pts) - 1)) if taper else 1)
            for k in range(n):
                t = k / n * math.tau
                verts.append(p + (a * math.cos(t) + b * math.sin(t)) * rr)
        for i in range(len(pts) - 1):
            for k in range(n):
                faces.append((i * n + k, i * n + (k + 1) % n, (i + 1) * n + (k + 1) % n, (i + 1) * n + k))
        n_uv = len(faces)
        faces.append(tuple(reversed(range(n))))
        last = (len(pts) - 1) * n
        faces.append(tuple(last + k for k in range(n)))
        acc, uv = 0.0, []
        for i, p in enumerate(pts):
            if i > 0:
                acc += (p - pts[i - 1]).length
            for k in range(n):
                uv.append((k / n * math.tau * r, acc))
        self.face_list(m, verts, faces, uvs=uv, uv_faces=n_uv)

    def build(self, collection, at=(0, 0, 0)):
        miny = min((v.y for vs, _ in self.geo.values() for v in vs), default=0.0)
        self.box("FRONT", (0, miny - 1.0, 0.5), (1.0, 1.0, 1.0), collide=False)
        self.box("ORIGIN", (0, 0, 0.5), (1.0, 1.0, 1.0), collide=False)
        root = bpy.data.objects.new(self.name, None)
        collection.objects.link(root)
        root.location = at
        root.empty_display_size = 3
        for m, (vs, fs) in self.geo.items():
            if not fs:
                continue
            me = bpy.data.meshes.new(self.name + "__" + m)
            bm = bmesh.new()
            bv = [bm.verts.new(v) for v in vs]
            uvl = bm.loops.layers.uv.new("UVMap")
            sc = TEX_SCALE.get(m, 4.0)
            for f, cu in zip(fs, self.fuv[m]):
                if len(set(f)) < 3:
                    continue
                try:
                    face = bm.faces.new([bv[i] for i in f])
                except ValueError:
                    continue  # faccia doppia
                face.normal_update()
                nrm = face.normal
                ax = max(range(3), key=lambda a: abs(nrm[a]))
                for k, loop in enumerate(face.loops):
                    if cu:
                        u, v = cu[k]
                    else:
                        co = loop.vert.co
                        u, v = (co.y, co.z) if ax == 0 else ((co.x, co.z) if ax == 1 else (co.x, co.y))
                    loop[uvl].uv = (u / sc, v / sc)
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
            bmesh.ops.triangulate(bm, faces=[fc for fc in bm.faces if len(fc.verts) > 4], quad_method="BEAUTY", ngon_method="EAR_CLIP")
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            if m in SMOOTH:
                for fc in bm.faces:
                    fc.smooth = True
            bm.to_mesh(me)
            bm.free()
            me.materials.append(material(m))
            ob = bpy.data.objects.new(self.name + "__" + m, me)
            collection.objects.link(ob)
            ob.parent = root
            if m in self.remesh:
                # i pezzi fusi in una sola pelle (voxel) e levigati: per le nuvole
                rm = ob.modifiers.new("Remesh", "REMESH")
                rm.mode = "VOXEL"
                rm.voxel_size = self.remesh[m]
                sm = ob.modifiers.new("Liscia", "SMOOTH")
                sm.factor, sm.iterations = 0.8, 6
                dg = bpy.context.evaluated_depsgraph_get()
                fused = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
                ob.modifiers.clear()
                ob.data = fused
                fused.materials.clear()
                fused.materials.append(material(m))
                for poly in fused.polygons:
                    poly.use_smooth = m in SMOOTH
            if m in ("FRONT", "ORIGIN"):
                ob.hide_viewport = False
                ob.display_type = "WIRE"
                ob.hide_render = True
        return root


# ---------------------------------------------------------------------------------------
# tetti curvi

def roof(b, cx, cy, z0, hx, hy, H, style="gable", lift=None, ug=0.42, mat="TILE", ridge=True,
         ribs=True, t=0.55, gable_mat="TIMBERDARK", p=1.75, tips=True, skip_tip_x=0, white=False):
    """(cx, cy, z0) centro della gronda; hx, hy mezze misure della gronda; H altezza del colmo.
    style: "gable" (padiglione e capanna), "hip" (padiglione), "skirt" (tettoia), "simple" (due falde)."""
    simple = style == "simple"
    lift = (0.0 if simple else min(hx, hy) * 0.16) if lift is None else lift
    L = min(hx, hy) * 0.6
    top_u = ug if style == "skirt" else 1.0
    gu = 0.0 if simple else (ug if style in ("gable", "skirt") else 1.0)
    if simple:
        tips = False

    def cornerf(dist):
        return max(0.0, 1 - dist / L) ** 2.3

    def point(x, y, u, dist):
        c = cornerf(dist) * (1 - min(u / max(gu, 0.3), 1)) ** 2 if lift > 0 else 0.0
        z = z0 + H * (u ** p) + lift * c
        return Vector((cx + x + math.copysign(1, x) * lift * 0.45 * c, cy + y + math.copysign(1, y) * lift * 0.45 * c, z))

    def ex(u):
        return max(hx - hy * min(u, gu), 0.02)

    def front(s, u, v):
        e = ex(u)
        return point(-e + 2 * e * v, s * (hy - hy * u), u, min(v, 1 - v) * 2 * e)

    def side(s, u, v):
        e = hy - hy * u
        return point(s * (hx - hy * u), -e + 2 * e * v, u, min(v, 1 - v) * 2 * e)

    nu = 9
    nvf = max(10, int(hx * 0.9))
    nvs = max(6, int(hy * 0.9))
    for s in (-1, 1):
        b.shell(mat, [[front(s, top_u * i / nu, j / nvf) for j in range(nvf + 1)] for i in range(nu + 1)], t)
        nside = max(3, int(nu * gu))
        if not simple:
            b.shell(mat, [[side(s, gu * i / nside, j / nvs) for j in range(nvs + 1)] for i in range(nside + 1)], t)
        if ribs:
            n = max(4, int(2 * hx / 1.3))
            for k in range(n + 1):
                v = (k + 0.5) / (n + 1)
                b.tube(mat, [front(s, top_u * i / nu, v) + Vector((0, 0, 0.16)) for i in range(nu + 1)], 0.24, n=3)
            n = 0 if simple else max(2, int(2 * hy / 1.3))
            for k in range(n + 1 if n > 0 else 0):
                v = (k + 0.5) / (n + 1)
                pts = []
                for i in range(nside + 1):
                    u = gu * i / nside
                    if (hy - hy * u) * 2 * min(v, 1 - v) > 0.4 or i == 0:
                        pts.append(side(s, u, v) + Vector((0, 0, 0.16)))
                if len(pts) > 2:
                    b.tube(mat, pts, 0.24, n=3)
    rz = z0 + H
    if style in ("gable", "simple"):
        xg = hx - hy * gu - 0.4
        for s in (-1, 1):
            pts = []
            for k in range(13):
                y = -(hy - hy * gu) + 2 * (hy - hy * gu) * k / 12
                u = 1 - abs(y) / hy
                pts.append((cx + s * xg, cy + y, z0 + H * (u ** p) - 0.25))
            pts.append((cx + s * xg, cy + (hy - hy * gu), z0 + H * (gu ** p)))
            pts.append((cx + s * xg, cy - (hy - hy * gu), z0 + H * (gu ** p)))
            b.poly(gable_mat, pts, thick=0.3, normal=(s, 0, 0))
    k = max(0.25, min(1.1, min(hx, hy) / 7))
    if style != "skirt" and ridge:
        e = ex(1.0)
        if e > 0.3:
            b.box("RIDGE", (cx, cy, rz + 0.35), (2 * e + 0.6, 1.1, 1.0), collide=False)
            b.box("RIDGEWHITE" if white else "RIDGE", (cx, cy, rz + 0.95), (2 * e + 0.2, 0.6, 0.4), collide=False)
            if tips:
                for s in (-1, 1):
                    pts = []
                    for i in range(9):
                        a = i / 8 * math.pi * 1.1
                        pts.append((cx + s * (e + 0.4 - 0.8 * math.sin(a) * k), cy, rz + 0.5 + 1.1 * (1 - math.cos(a)) * k))
                    b.tube("RIDGE", pts, 0.42 * max(k, 0.6), n=6, taper=lambda f: 1 - 0.5 * f)
    if tips:
        for sx in (-1, 1):
            if sx == skip_tip_x:
                continue
            for sy in (-1, 1):
                pts = [front(sy, gu * i / 8, 1.0 if sx > 0 else 0.0) + Vector((0, 0, 0.35)) for i in range(9)]
                d = Vector((sx, sy, 0)).normalized()
                tip = pts[0]
                pts = [tip + d * 1.6 * k + Vector((0, 0, 1.5 * k)), tip + d * 0.8 * k + Vector((0, 0, 0.55 * k))] + pts
                b.tube("RIDGEWHITE" if white else "RIDGE", pts, 0.38 * max(k, 0.55), n=5, taper=lambda f: 0.55 + 0.45 * f)


def shed_roof(b, x0, x1, y_low, y_high, z_low, z_high, mat="TILE", t=0.5, axis="y"):
    """Tetto a una falda, leggermente incurvato, coi coppi. axis="y": sale da y_low a y_high ed e'
    largo da x0 a x1; axis="x": i ruoli di x e y si scambiano (sale da x_low=y_low a x_high=y_high,
    largo da y0=x0 a y1=x1)."""
    def P(a, s, z):  # a: lungo la larghezza, s: lungo la pendenza
        return (a, s, z) if axis == "y" else (s, a, z)

    nu, nv = 6, max(6, int(abs(x1 - x0)))
    rows = []
    for i in range(nu + 1):
        u = i / nu
        s = y_low + (y_high - y_low) * u
        z = z_low + (z_high - z_low) * (u ** 1.4)
        rows.append([P(x0 + (x1 - x0) * j / nv, s, z) for j in range(nv + 1)])
    b.shell(mat, rows, t)
    n = max(3, int(abs(x1 - x0) / 1.3))
    for k in range(n + 1):
        a = x0 + (x1 - x0) * (k + 0.5) / (n + 1)
        b.tube(mat, [P(a, y_low + (y_high - y_low) * i / nu, z_low + (z_high - z_low) * ((i / nu) ** 1.4) + 0.16) for i in range(nu + 1)], 0.24, n=3)
    size = (abs(x1 - x0) + 0.4, 0.9, 0.8) if axis == "y" else (0.9, abs(x1 - x0) + 0.4, 0.8)
    b.box("RIDGE", P((x0 + x1) / 2, y_high, z_high + 0.3), size, collide=False)


# ---------------------------------------------------------------------------------------
# muri con le aperture vere

def wall(b, mat, p0, p1, z0, h, t=0.5, holes=(), collide=True):
    """Muro da p0 a p1 (punti x, y) dalla quota z0 alta h. holes: (s0, s1, zb, zt) lungo il
    muro (distanza da p0) e in altezza (da z0): li' il muro e' aperto (porte, finestre)."""
    p0, p1 = Vector((p0[0], p0[1], 0)), Vector((p1[0], p1[1], 0))
    L = (p1 - p0).length
    d = (p1 - p0) / L
    R = frame_of(d)
    cuts = sorted({0.0, L} | {max(0.0, min(L, v)) for hole in holes for v in hole[:2]})
    for a, c in zip(cuts[:-1], cuts[1:]):
        if c - a < 1e-3:
            continue
        mid = (a + c) / 2
        hole = next((hh for hh in holes if hh[0] <= a + 1e-4 and hh[1] >= c - 1e-4), None)
        pieces = [(0.0, h)] if not hole else [(0.0, hole[2]), (hole[3], h)]
        for zb, zt in pieces:
            if zt - zb > 1e-3:
                cpos = p0 + d * mid
                # il muro corre lungo Y della matrice (d): misure (spessore, lunghezza, altezza)
                b.box(mat, (cpos.x, cpos.y, z0 + (zb + zt) / 2), (t, c - a, zt - zb), R, collide=collide)


def opening_frame(b, p0, p1, s0, s1, z0, zb, zt, t=0.5, mat="TIMBERDARK", sill=True):
    """Cornice di legno attorno a un'apertura del muro (sporge un poco dai due lati)."""
    p0, p1 = Vector((p0[0], p0[1], 0)), Vector((p1[0], p1[1], 0))
    d = (p1 - p0).normalized()
    a = p0 + d * s0
    c = p0 + d * s1
    for q in (a, c):
        b.box(mat, (q.x, q.y, z0 + (zb + zt) / 2), (0.45, 0.45, zt - zb) if abs(d.x) > 0.5 else (0.45, 0.45, zt - zb), None, collide=False)
    b.beam(mat, (a.x, a.y, z0 + zt + 0.2), (c.x, c.y, z0 + zt + 0.2), t + 0.3, 0.45, collide=False)
    if sill and zb > 0.5:
        b.beam(mat, (a.x, a.y, z0 + zb - 0.15), (c.x, c.y, z0 + zb - 0.15), t + 0.5, 0.3, collide=False)


def lattice(b, p0, p1, s0, s1, z0, zb, zt, offset=0.0, bars=(4, 3), mat="TIMBERDARK", paper=True, step=None):
    """Grata di legno (e carta dietro) dentro un'apertura del muro."""
    p0, p1 = Vector((p0[0], p0[1], 0)), Vector((p1[0], p1[1], 0))
    d = (p1 - p0).normalized()
    n = Vector((-d.y, d.x, 0)) * offset
    a = p0 + d * s0 + n
    c = p0 + d * s1 + n
    nx, nz = bars
    for k in range(1, nx + 1):
        q = a.lerp(c, k / (nx + 1))
        b.beam(mat, (q.x, q.y, z0 + zb), (q.x, q.y, z0 + zt), 0.14, 0.14, collide=False)
    for k in range(1, nz + 1):
        z = z0 + zb + (zt - zb) * k / (nz + 1)
        b.beam(mat, (a.x, a.y, z), (c.x, c.y, z), 0.14, 0.14, collide=False)
    if paper:
        back = -n.normalized() * 0.12 if n.length > 0 else Vector((0, 0, 0))
        b.poly("PAPER", [a + back + Vector((0, 0, z0 + zb)), c + back + Vector((0, 0, z0 + zb)), c + back + Vector((0, 0, z0 + zt)), a + back + Vector((0, 0, z0 + zt))], thick=0.06)


def slab(b, mat, x0, x1, y0, y1, z, t=0.6, hole=None, collide=True):
    """Solaio da (x0, y0) a (x1, y1), quota del piano z (sopra), con un buco (hx0, hx1, hy0, hy1)."""
    if not hole:
        b.box(mat, ((x0 + x1) / 2, (y0 + y1) / 2, z - t / 2), (x1 - x0, y1 - y0, t), collide=collide)
        return
    hx0, hx1, hy0, hy1 = hole
    parts = [(x0, hx0, y0, y1), (hx1, x1, y0, y1), (hx0, hx1, y0, hy0), (hx0, hx1, hy1, y1)]
    for a, c, e, f in parts:
        if c - a > 0.05 and f - e > 0.05:
            b.box(mat, ((a + c) / 2, (e + f) / 2, z - t / 2), (c - a, f - e, t), collide=collide)


def stairs(b, start, direction, width, height, rise=0.9, tread=1.25, mat="WOOD", rail=True):
    """Scala che parte da start (x, y, z del primo gradino a terra) e sale lungo direction."""
    start = Vector(start)
    d = Vector((direction[0], direction[1], 0)).normalized()
    side = Vector((-d.y, d.x, 0))
    n = max(1, round(height / rise))
    r = height / n
    for i in range(n):
        c = start + d * (tread * (i + 0.5)) + Vector((0, 0, r * (i + 0.5)))
        R = frame_of(d)
        b.box(mat, (c.x, c.y, c.z), (width, tread, r), R, collide=True)
    length = tread * n
    top = start + d * length + Vector((0, 0, height))
    for s in (-1, 1):
        o = side * s * (width / 2 + 0.15)
        b.beam("TIMBERDARK", start + o + Vector((0, 0, 0.2)), top + o + Vector((0, 0, 0.2)), 0.3, 0.8, collide=False)
    if rail:
        o = side * (width / 2 + 0.15)
        b.beam("TIMBERDARK", start + o + Vector((0, 0, 3.0)), top + o + Vector((0, 0, 3.0)), 0.25, 0.25, collide=False)
        for k in range(0, n + 1, 3):
            q = start + d * (tread * k) + o + Vector((0, 0, r * k))
            b.beam("TIMBERDARK", q, q + Vector((0, 0, 3.0)), 0.22, 0.22, collide=False)
    return length


# ---------------------------------------------------------------------------------------
# dettagli e arredi

def red_lantern(b, top, size=1.0):
    top = Vector(top)
    b.cyl("TIMBERDARK", top, top - Vector((0, 0, 0.6 * size)), 0.05, n=4)
    c = top - Vector((0, 0, 0.6 * size + 0.75 * size))
    b.sphere("LANTERN", c, 0.75 * size, rz=0.8 * size, seg=10, rings=7)
    b.cyl("GOLD", c + Vector((0, 0, 0.7 * size)), c + Vector((0, 0, 0.9 * size)), 0.38 * size, n=8)
    b.cyl("GOLD", c - Vector((0, 0, 0.7 * size)), c - Vector((0, 0, 0.9 * size)), 0.38 * size, n=8)
    b.cyl("LANTERN", c - Vector((0, 0, 0.9 * size)), c - Vector((0, 0, 1.6 * size)), 0.08 * size, n=4)


def railing(b, p0, p1, h=3.2, mat="TIMBERDARK", lattice=True, bench=False):
    """Ringhiera; bench=True e' la "panchina della bella" (meirenkao): sedile e schienale che
    pende verso fuori, come sui ballatoi delle case di Fenghuang."""
    p0, p1 = Vector(p0), Vector(p1)
    up = Vector((0, 0, h))
    L = (p1 - p0).length
    d = (p1 - p0).normalized()
    out = Vector((d.y, -d.x, 0))  # verso fuori (a destra andando da p0 a p1)
    b.beam(mat, p0 + up * 0.15, p1 + up * 0.15, 0.3, 0.3, collide=False)
    if bench:
        seat = up * 0.55
        b.box("WOOD", (p0 + p1) / 2 + seat - out * 0.5, (L, 1.2, 0.25) if abs(d.x) > 0.5 else (1.2, L, 0.25), collide=False)
        top = up * 1.15 + out * 0.6
        b.beam(mat, p0 + top, p1 + top, 0.35, 0.3, collide=True)
        n = max(2, int(L / 0.8))
        for k in range(n + 1):
            q = p0.lerp(p1, k / n)
            b.beam(mat, q + seat, q + top, 0.16, 0.16, collide=False)
        for k in range(0, n + 1, max(1, n // 4)):
            q = p0.lerp(p1, k / n)
            b.beam(mat, q, q + seat, 0.3, 0.3, collide=False)
        return
    b.beam(mat, p0 + up, p1 + up, 0.4, 0.3, collide=True)
    n = max(1, int(L / 2.2))
    for k in range(n + 1):
        q = p0.lerp(p1, k / n)
        b.beam(mat, q, q + up, 0.32, 0.32, collide=False)
    if lattice:
        m = max(2, int(L / 1.1))
        for k in range(m):
            a = p0.lerp(p1, k / m)
            c = p0.lerp(p1, (k + 1) / m)
            b.beam(mat, a + up * 0.15, c + up * 0.85, 0.12, 0.12, collide=False)
            b.beam(mat, a + up * 0.85, c + up * 0.15, 0.12, 0.12, collide=False)


def table(b, c, w=3.0, d=2.0, h=2.6, mat="TIMBER"):
    c = Vector(c)
    b.box(mat, c + Vector((0, 0, h - 0.15)), (w, d, 0.3), collide=True)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(mat, c + Vector((sx * (w / 2 - 0.25), sy * (d / 2 - 0.25), (h - 0.3) / 2)), (0.3, 0.3, h - 0.3), collide=False)


def stool(b, c, h=1.6):
    c = Vector(c)
    b.cyl("TIMBER", c, c + Vector((0, 0, h)), 0.55, n=8)
    b.cyl("TIMBERDARK", c + Vector((0, 0, h - 0.1)), c + Vector((0, 0, h + 0.1)), 0.62, n=8)


def teapot(b, c):
    c = Vector(c)
    b.sphere("CERAMIC", c + Vector((0, 0, 0.3)), 0.32, rz=0.28, seg=8, rings=5)
    b.cyl("CERAMIC", c + Vector((0.25, 0, 0.3)), c + Vector((0.55, 0, 0.5)), 0.06, n=4)
    for k in range(2):
        b.cyl("CERAMIC", c + Vector((-0.6 + k * 0.3, 0.45, 0)), c + Vector((-0.6 + k * 0.3, 0.45, 0.22)), 0.12, n=6)


def jar(b, c, r=0.6, h=1.6, mat="CERAMIC"):
    c = Vector(c)
    b.sphere(mat, c + Vector((0, 0, h * 0.45)), r, rz=h * 0.45, seg=10, rings=6)
    b.cyl(mat, c + Vector((0, 0, h * 0.85)), c + Vector((0, 0, h)), r * 0.45, n=8)


def bed(b, c, d_axis="x"):
    c = Vector(c)
    size = (6.0, 3.6) if d_axis == "x" else (3.6, 6.0)
    b.box("TIMBER", c + Vector((0, 0, 0.8)), (size[0], size[1], 0.6), collide=True)
    b.box("CLOTH", c + Vector((0, 0, 1.25)), (size[0] - 0.4, size[1] - 0.3, 0.3), collide=False)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box("TIMBERDARK", c + Vector((sx * (size[0] / 2 - 0.2), sy * (size[1] / 2 - 0.2), 2.2)), (0.25, 0.25, 4.4), collide=False)
    b.box("TIMBERDARK", c + Vector((0, 0, 4.4)), (size[0], size[1], 0.25), collide=False)


def shelf(b, c, w=5.0, h=6.0, along="x", items=True):
    """Scaffale contro il muro con giare e scatole."""
    c = Vector(c)
    dx = Vector((1, 0, 0)) if along == "x" else Vector((0, 1, 0))
    for s in (-1, 1):
        q = c + dx * (s * w / 2)
        b.box("TIMBERDARK", q + Vector((0, 0, h / 2)), (0.3, 0.3, h) if True else None, collide=False)
    for k in range(4):
        z = 0.6 + k * (h - 0.6) / 3.5
        b.box("TIMBER", c + Vector((0, 0, z)), (w, 1.2, 0.2) if along == "x" else (1.2, w, 0.2), collide=k == 0)
        if items and k < 3:
            for j in range(4):
                q = c + dx * (-w / 2 + w * (j + 0.5) / 4) + Vector((0, 0, z + 0.1))
                jar(b, q, r=0.32, h=0.9, mat="CERAMIC" if (j + k) % 2 == 0 else "BRONZE")


def hanging_post(b, x, y, z_top, drop=2.4):
    """Pilastro sospeso dei diaojiaolou: non tocca terra e finisce con il pomolo intagliato."""
    b.box("TIMBERDARK", (x, y, z_top - drop / 2), (0.7, 0.7, drop), collide=False)
    b.sphere("TIMBER", (x, y, z_top - drop - 0.45), 0.55, rz=0.6, seg=8, rings=6)
    b.cyl("TIMBERDARK", (x, y, z_top - drop - 1.0), (x, y, z_top - drop - 1.4), 0.18, n=6)


def buddha(b, c, scale=1.0):
    """Statua seduta stilizzata, dorata, sul fiore di loto."""
    c = Vector(c)
    s = scale
    b.cyl("LACQUER", c, c + Vector((0, 0, 0.6 * s)), 1.6 * s, n=12)
    for k in range(8):
        a = k / 8 * math.tau
        b.sphere("LACQUER", c + Vector((math.cos(a) * 1.4 * s, math.sin(a) * 1.4 * s, 0.7 * s)), 0.45 * s, seg=6, rings=4)
    b.sphere("GOLD", c + Vector((0, 0, 1.3 * s)), 1.45 * s, rz=0.75 * s, seg=12, rings=6)
    b.sphere("GOLD", c + Vector((0, 0, 2.6 * s)), 0.95 * s, rz=1.2 * s, seg=12, rings=7)
    b.sphere("GOLD", c + Vector((0, 0, 4.1 * s)), 0.62 * s, rz=0.7 * s, seg=10, rings=6)
    b.sphere("GOLD", c + Vector((0, 0, 4.85 * s)), 0.28 * s, seg=6, rings=4)
    b.sphere("GOLD", c + Vector((0, 0.55 * s, 3.4 * s)), 1.5 * s, rz=1.9 * s, seg=12, rings=6)  # aureola dietro


def incense_burner(b, c, s=1.0):
    """Bruciaincenso di bronzo (ding) a tre piedi, col coperchio a tettino."""
    c = Vector(c)
    for k in range(3):
        a = k / 3 * math.tau
        b.cyl("BRONZE", c + Vector((math.cos(a) * 0.9 * s, math.sin(a) * 0.9 * s, 0)), c + Vector((math.cos(a) * 0.8 * s, math.sin(a) * 0.8 * s, 1.0 * s)), 0.2 * s, n=6)
    b.sphere("BRONZE", c + Vector((0, 0, 1.7 * s)), 1.3 * s, rz=0.9 * s, seg=12, rings=6)
    b.cyl("BRONZE", c + Vector((0, 0, 2.4 * s)), c + Vector((0, 0, 2.6 * s)), 1.25 * s, n=12)
    for sx in (-1, 1):
        b.tube("BRONZE", [c + Vector((sx * 1.1 * s, 0, 2.4 * s)), c + Vector((sx * 1.4 * s, 0, 3.0 * s)), c + Vector((sx * 1.1 * s, 0, 3.4 * s))], 0.12 * s, n=5)
    roof(b, c.x, c.y, c.z + 3.0 * s, 1.0 * s, 1.0 * s, 0.9 * s, style="hip", mat="BRONZE", ribs=False, ridge=False, tips=False, lift=0.2 * s, t=0.15)
    b.sphere("GOLD", c + Vector((0, 0, 4.2 * s)), 0.25 * s, seg=6, rings=4)


# ---------------------------------------------------------------------------------------
# texture pronte per Roblox: una per materiale (tinta gia' applicata), in out/tex
#   <MAT>_Color.jpg, <MAT>_Normal.jpg, <MAT>_Roughness.jpg (e _Metalness per i metalli)

def _load_px(path):
    import numpy as np
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4), w, h


def _save_px(px, path, quality=88):
    h, w = px.shape[:2]
    img = bpy.data.images.new("tmp_tex", w, h)
    img.pixels.foreach_set(px.astype("float32").ravel())
    img.filepath_raw = path
    img.file_format = "JPEG"
    bpy.context.scene.render.image_settings.quality = quality
    img.save()
    bpy.data.images.remove(img)


def _crystal_maps(size=512, seeds=26, rnd=7):
    """Texture del cristallo fatta da codice: sfaccettature (Voronoi) chiare con gli spigoli piu'
    luminosi e le normali inclinate per ogni faccetta. In Roblox prende il colore del bioma."""
    import numpy as np
    rng = np.random.default_rng(rnd)
    pts = rng.random((seeds, 2))
    tilt = rng.normal(0, 0.35, (seeds, 2))
    shade = 0.78 + rng.random(seeds) * 0.22
    yy, xx = np.mgrid[0:size, 0:size] / size
    best = np.full((size, size), 9.0)
    second = np.full((size, size), 9.0)
    idx = np.zeros((size, size), dtype=np.int32)
    for k, (px, py) in enumerate(pts):
        dx = np.abs(xx - px)
        dy = np.abs(yy - py)
        dx = np.minimum(dx, 1 - dx)
        dy = np.minimum(dy, 1 - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < best
        second = np.where(closer, best, np.minimum(second, d))
        idx = np.where(closer, k, idx)
        best = np.where(closer, d, best)
    edge = np.clip(1 - (second - best) * 40, 0, 1)
    col = np.clip(shade[idx][..., None] * np.ones(3) + edge[..., None] * 0.25, 0, 1)
    nx, ny = tilt[idx, 0], tilt[idx, 1]
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0.2, 1))
    nrm = np.stack([nx * 0.5 + 0.5, ny * 0.5 + 0.5, nz], -1)
    rough = 0.08 + edge * 0.25
    alpha = np.ones((size, size, 1))
    return (np.concatenate([col, alpha], -1), np.concatenate([nrm, alpha], -1),
            np.concatenate([np.repeat(rough[..., None], 3, -1), alpha], -1))


def prepare_textures(src_dir, out_dir):
    """Prepara le texture dei materiali (quelle gia' fatte non si rifanno)."""
    import numpy as np
    global TEXTURES_DIR
    os.makedirs(out_dir, exist_ok=True)
    TEXTURES_DIR = out_dir
    made = []
    for mat, (src, tint) in TEX_SRC.items():
        folder = os.path.join(src_dir, src + "_1K-JPG")
        target = os.path.join(out_dir, mat + "_Color.jpg")
        if not os.path.isdir(folder) or os.path.exists(target):
            continue
        px, w, h = _load_px(os.path.join(folder, src + "_1K-JPG_Color.jpg"))
        t = np.array(tint if isinstance(tint, tuple) else (tint, tint, tint), dtype=np.float32)
        px[..., :3] = np.clip(px[..., :3] * t, 0, 1)
        _save_px(px, target)
        for kind, src_kind in (("Normal", "NormalGL"), ("Roughness", "Roughness"), ("Metalness", "Metalness")):
            f = os.path.join(folder, "%s_1K-JPG_%s.jpg" % (src, src_kind))
            if os.path.exists(f):
                q, _, _ = _load_px(f)
                _save_px(q, os.path.join(out_dir, "%s_%s.jpg" % (mat, kind)), 92)
        made.append(mat)
    if not os.path.exists(os.path.join(out_dir, "CRYSTAL_Color.jpg")):
        c, n, r = _crystal_maps()
        _save_px(c, os.path.join(out_dir, "CRYSTAL_Color.jpg"))
        _save_px(n, os.path.join(out_dir, "CRYSTAL_Normal.jpg"), 95)
        _save_px(r, os.path.join(out_dir, "CRYSTAL_Roughness.jpg"))
        made.append("CRYSTAL")
    return made
