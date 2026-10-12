"""Genera 36 mesh VFX, UV, FBX singoli e tavole di anteprima in Blender 5.2."""
import bpy
import bmesh
import math
import random
import json
import sys
import warnings
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'fbx'
PREVIEW = ROOT / 'preview'
OUT.mkdir(exist_ok=True)
PREVIEW.mkdir(exist_ok=True)
TAU = math.tau
RNG = random.Random(121026)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for collection in list(bpy.data.collections):
    if collection.name != 'Collection':
        bpy.data.collections.remove(collection)
assets = bpy.data.collections.get('Collection')
assets.name = 'VFX_MESH_36'
stage = bpy.data.collections.new('ANTEPRIMA_NON_ESPORTARE')
bpy.context.scene.collection.children.link(stage)

def material(name, color, emission=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    # Blender 5.2 mantiene questa proprieta', ma segnala gia' la futura rimozione.
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', DeprecationWarning)
        mat.use_nodes = True
    node = mat.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = (*color, 1)
    node.inputs['Roughness'].default_value = .7
    node.inputs['Emission Color'].default_value = (*color, 1)
    node.inputs['Emission Strength'].default_value = emission
    return mat

white = material('VFX_Bianco_Colorabile', (.86, .95, 1), .8)
label_mat = material('Etichette', (.48, .70, .86), .7)
floor_mat = material('Sfondo', (.013, .022, .039))

class Form:
    def __init__(self):
        self.v, self.f, self.uv = [], [], []

    def strip(self, func, steps=48, matrix=None, offset=(0, 0, 0)):
        """Nastro: U segue la lunghezza, V attraversa la larghezza."""
        start = len(self.v)
        off = Vector(offset)
        for i in range(steps + 1):
            t = i / steps
            for side in (-1, 1):
                p = Vector(func(t, side))
                if matrix is not None:
                    p = matrix @ p
                self.v.append(tuple(p + off))
        for i in range(steps):
            a = start + i * 2
            self.f.append((a, a + 2, a + 3, a + 1))
            self.uv.append(((i / steps, 0), ((i + 1) / steps, 0),
                            ((i + 1) / steps, 1), (i / steps, 1)))

    def ribbon(self, radius=1.5, start=0, arc=5, width=.22, z=0,
               rise=0, taper=True, jagged=.0, matrix=None, offset=(0, 0, 0), steps=None):
        def fn(t, side):
            a = start + arc * t
            profile = (.018 + .982 * math.sin(math.pi * t) ** .75) if taper else 1
            teeth = 1 + jagged * (math.sin(t * 91) + .5 * math.sin(t * 173 + side))
            r = radius + side * width * profile * teeth / 2
            return r * math.cos(a), r * math.sin(a), z + rise * t
        self.strip(fn, steps if steps is not None else max(8, int(abs(arc) * 10)), matrix, offset)

    def helix(self, r0=1.5, r1=.3, height=2.6, turns=1.5, phase=0, width=.26, offset=(0, 0, 0)):
        def fn(t, side):
            a = phase + TAU * turns * t
            r = r0 + (r1 - r0) * t
            w = width * (.025 + math.sin(math.pi * t) ** .65)
            return r * math.cos(a), r * math.sin(a), height * t + side * w / 2
        self.strip(fn, 76, offset=offset)

    def sphere_patch(self, theta, phi, arc=.7, width=.15, radius=1.5, ragged=.25, matrix=None, offset=(0, 0, 0)):
        def fn(t, side):
            p = phi + arc * t
            w = width * (.035 + math.sin(math.pi * t) ** .6)
            w *= 1 + ragged * math.sin(t * 49 + side * 2)
            a = theta + side * w + .06 * math.sin(t * 11)
            return radius * math.sin(a) * math.cos(p), radius * math.sin(a) * math.sin(p), radius * math.cos(a)
        self.strip(fn, max(12, int(abs(arc) * 9)), matrix, offset)

    def spike(self, base, tip, radius=.16, sides=5):
        """Punta cava alla base; Solidify chiude il bordo con spessore reale."""
        base, tip = Vector(base), Vector(tip)
        axis = (tip - base).normalized()
        u = axis.cross(Vector((0, 0, 1)))
        if u.length < .1:
            u = axis.cross(Vector((0, 1, 0)))
        u.normalize()
        v = axis.cross(u).normalized()
        def fn(t, side):
            a = t * TAU
            p = base + radius * (u * math.cos(a) + v * math.sin(a)) if side == -1 else tip + radius * .018 * (u * math.cos(a) + v * math.sin(a))
            return tuple(p)
        self.strip(fn, sides)

    def bolt(self, points, width=.12, plane=(0, 1, 0)):
        normal = Vector(plane)
        for i in range(len(points) - 1):
            p, q = Vector(points[i]), Vector(points[i + 1])
            direction = (q - p).normalized()
            side = direction.cross(normal).normalized()
            w0 = width * (1 - i / len(points))
            w1 = width * (1 - (i + 1) / len(points))
            def fn(t, sign):
                return tuple(p.lerp(q, t) + sign * side * (w0 * (1 - t) + w1 * t) / 2)
            self.strip(fn, 1)

    def rock(self, center, size, seed):
        """Piccolo volume sfaccettato senza dipendenze; UV per faccia."""
        rr = random.Random(seed)
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1)
        bm.verts.ensure_lookup_table()
        start = len(self.v)
        for vert in bm.verts:
            p = Vector(center) + Vector((vert.co.x * size[0], vert.co.y * size[1], vert.co.z * size[2])) * rr.uniform(.8, 1.13)
            self.v.append(tuple(p))
        for face in bm.faces:
            self.f.append(tuple(start + v.index for v in face.verts))
            self.uv.append(((0, 0), (1, 0), (.5, 1)))
        bm.free()

records = []
objects = []

def finish(form, name, group, use, pivot='centro', animation='rotazione + espansione + dissolvenza'):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(form.v, [], form.f)
    mesh.update()
    uv = mesh.uv_layers.new(name='UVMap')
    for poly, coords in zip(mesh.polygons, form.uv):
        for loop, point in zip(poly.loop_indices, coords):
            uv.data[loop].uv = point
    obj = bpy.data.objects.new(name, mesh)
    assets.objects.link(obj)
    obj.data.materials.append(white)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    # Salda le giunzioni delle punte e corregge l'orientamento prima dello spessore.
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.00001)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    mod = obj.modifiers.new('Spessore_reale', 'SOLIDIFY')
    mod.thickness = .014
    mod.offset = 0
    mod.use_even_offset = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    tri = obj.modifiers.new('Triangoli_export', 'TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=tri.name)
    for poly in obj.data.polygons:
        poly.use_smooth = False
    obj['categoria'] = group
    obj['uso'] = use
    obj['pivot'] = pivot
    obj['animazione_suggerita'] = animation
    objects.append(obj)
    records.append(dict(name=name, group=group, use=use, pivot=pivot, animation=animation))
    return obj

RX = Matrix.Rotation(math.pi / 2, 3, 'X')
RY = Matrix.Rotation(math.pi / 2, 3, 'Y')

# Dodici forme comuni: il riferimento usa strisce luminose e vuoti nella geometria.
f = Form()
for j in range(4):
    f.ribbon(1.65 - j * .32, j * 1.5, 4.9, .2, .06 + j * .19, .25, jagged=.23)
finish(f, 'VFX_01_Vortice', 'Generici', 'Vortice basso, carica e impatto', 'base')
f = Form()
for j in range(3):
    f.helix(1.6, .16, 2.8, 1.25, j * TAU / 3, .30)
finish(f, 'VFX_02_SpiraleConica', 'Generici', 'Spirale a cono ascendente', 'base')
f = Form()
for j in range(7):
    f.sphere_patch(.25 + j * .43, j * .73, 4.5, .10, ragged=.12)
finish(f, 'VFX_03_SferaNastri', 'Generici', 'Sfera aperta avvolta da nastri')
f = Form()
for row in range(6):
    for col in range(5):
        f.sphere_patch(.28 + row * .51, col * TAU / 5 + row * .6, RNG.uniform(.5, 1), .11, ragged=.55)
finish(f, 'VFX_04_SferaFrammentata', 'Generici', 'Sfera a frammenti irregolari, come nella schermata')
f = Form()
f.ribbon(1.5, 0, TAU, .28, .05, taper=False, jagged=.35)
for i in range(8):
    f.ribbon(1.9, i * TAU / 8, .46, .09, .05)
finish(f, 'VFX_05_OndaUrto', 'Generici', 'Anello radiale da picchiata', 'base', 'espansione rapida + dissolvenza')
f = Form()
for layer in range(3):
    for i in range(3):
        f.ribbon(.8 + layer * .44, i * TAU / 3 + layer * .4, 1.7, .12, .05)
finish(f, 'VFX_06_AnelliSpezzati', 'Generici', 'Tre corone discontinue concentriche', 'base')
f = Form()
f.ribbon(1.5, -.8, 4.1, .55, matrix=RX)
finish(f, 'VFX_07_Fendente', 'Generici', 'Taglio largo a mezzaluna', animation='arco di rotazione breve + dissolvenza')
f = Form()
for i in range(3):
    f.ribbon(1.45, -.8 + i * .18, 3.5, .22, matrix=RX, offset=(i * .35, i * .2, i * .1))
finish(f, 'VFX_08_FendenteTriplo', 'Generici', 'Tre tagli arcuati paralleli')
f = Form()
for i in range(10):
    a = i * TAU / 10
    h = 1.2 + .65 * (i % 3) / 2
    def crown(t, side, a=a, h=h):
        angle = a + side * .27 * (1 - t) ** .8
        r = 1.1 + .5 * t
        return r * math.cos(angle), r * math.sin(angle), .05 + h * t
    f.strip(crown, 10)
finish(f, 'VFX_09_CoronaImpatto', 'Generici', 'Corona di punte aperte per atterraggio', 'base', 'scala verticale rapida + dissolvenza')
f = Form()
for i in range(3):
    f.helix(.48, .8, 3.8, .7, i * TAU / 3, .3)
finish(f, 'VFX_10_Colonna', 'Generici', 'Colonna di energia a tre strisce', 'base')
f = Form()
for i in range(12):
    a = i * TAU / 12
    length = 1.9 if i % 2 == 0 else 1.15
    f.spike((.15 * math.cos(a), .15 * math.sin(a), 0), (length * math.cos(a), length * math.sin(a), 0), .16, 4)
finish(f, 'VFX_11_StellaImpatto', 'Generici', 'Lampo radiale a dodici raggi')
f = Form()
for j in range(3):
    f.strip(lambda t, s, j=j: ((t - .5) * 4, math.sin(t * 5 + j * .45) * .45 + s * .22 * math.sin(math.pi * t), j * .15), 44)
finish(f, 'VFX_12_Scia', 'Generici', 'Scia curva a tre nastri; asse locale X', animation='segue il proiettile + allungamento lungo X')

# Due sagome diverse per ciascuno degli otto elementi ancora presenti nel gioco.
f = Form()
for j in range(9):
    a = j * 2.4
    f.rock((.7 * math.cos(a), .7 * math.sin(a), (j - 4) * .17), (.55, .45, .43), j)
finish(f, 'VFX_13_RocciaProiettile', 'Roccia', 'Grappolo di schegge rocciose rotanti')
f = Form()
for i in range(12):
    a = i * TAU / 12
    f.spike((1.1 * math.cos(a), 1.1 * math.sin(a), 0), (1.8 * math.cos(a), 1.8 * math.sin(a), .45 + i % 3 * .25), .27, 5)
f.ribbon(1.15, 0, TAU, .16, .03, taper=False, jagged=.5)
finish(f, 'VFX_14_RocciaOnda', 'Roccia', 'Onda con denti di pietra', 'base')
f = Form()
for i in range(5):
    a = i * TAU / 5
    f.spike((.42 * math.cos(a), -.6, .42 * math.sin(a)), (.2 * math.cos(a), 1.6 + .2 * (i % 2), .2 * math.sin(a)), .22, 6)
finish(f, 'VFX_15_GeloLance', 'Gelo', 'Proiettile di cinque lance; avanti lungo Y', animation='traslazione lungo Y + rotazione')
f = Form()
for i in range(9):
    a = i * TAU / 9
    r = .55 + .35 * (i % 2)
    f.spike((r * math.cos(a), r * math.sin(a), 0), (r * 1.6 * math.cos(a), r * 1.6 * math.sin(a), 1.4 + .35 * (i % 3)), .24, 6)
finish(f, 'VFX_16_GeloEruzione', 'Gelo', 'Ventaglio di ghiaccio dal terreno', 'base', 'crescita dal basso + dissolvenza')
f = Form()
for i in range(3):
    f.ribbon(1.45, i, 5.7, .09, matrix=Matrix.Rotation(.6 + i * 1.0, 3, 'X'))
for i in range(5):
    f.sphere_patch(.35 + i * .55, i * 1.3, 3.8, .1, radius=.72)
finish(f, 'VFX_17_CosmicoNucleo', 'Cosmico', 'Nucleo aperto con orbite inclinate')
f = Form()
for i in range(4):
    for j in range(3):
        f.ribbon(.7 + i * .3, j * TAU / 3 + i * .4, 1.8, .08 + i * .015, matrix=RX)
for i in range(8):
    a = i * TAU / 8
    f.spike((1.65 * math.cos(a), 0, 1.65 * math.sin(a)), (1.95 * math.cos(a), 0, 1.95 * math.sin(a)), .06, 4)
finish(f, 'VFX_18_CosmicoPortale', 'Cosmico', 'Portale verticale a orbite e raggi')
f = Form()
for i in range(5):
    f.ribbon(1.3, i * TAU / 5, 1.75, .45, .25 * math.sin(i), .35)
finish(f, 'VFX_19_TempestaLame', 'Tempesta', 'Girandola di cinque lame di vento')
f = Form()
for i in range(4):
    f.helix(.18, 1.6, 3.1, 1.3, i * TAU / 4, .18)
for i in range(5):
    f.ribbon(1.8, i * TAU / 5, .7, .12, 2.9)
finish(f, 'VFX_20_TempestaTornado', 'Tempesta', 'Tromba di vento allargata in alto', 'base')
f = Form()
for row in range(4):
    for col in range(4):
        f.sphere_patch(.4 + row * .77, col * TAU / 4, .9, .12, radius=1.1, ragged=.4)
f.ribbon(1.45, 0, TAU, .15, taper=False, matrix=RX)
for i in range(10):
    a = i * TAU / 10
    f.spike((1.45 * math.cos(a), 0, 1.45 * math.sin(a)), (1.8 * math.cos(a + .12), 0, 1.8 * math.sin(a + .12)), .08, 4)
finish(f, 'VFX_21_EclissiCorona', 'Eclissi', 'Sfera aperta con corona di eclissi dentata')
f = Form()
f.ribbon(1.45, -.65, 4.4, .65, matrix=RX)
f.ribbon(1.7, -.3, 3.2, .13, matrix=RX, offset=(.1, .16, 0))
for i in range(4):
    a = .4 + i * .7
    f.spike((1.6 * math.cos(a), 0, 1.6 * math.sin(a)), (2.05 * math.cos(a - .12), 0, 2.05 * math.sin(a - .12)), .12, 4)
finish(f, 'VFX_22_EclissiFalce', 'Eclissi', 'Falce larga con quattro denti esterni')
f = Form()
main_bolt = [(-1.8, 0, -.2), (-.8, 0, .3), (-1, 0, -.25), (.15, 0, .25), (-.1, 0, -.2), (1.9, 0, .1)]
f.bolt(main_bolt, .3)
f.bolt([(-.8, 0, .3), (-.4, 0, 1), (.1, 0, .8), (.7, 0, 1.4)], .13)
f.bolt([(.15, 0, .25), (.4, 0, -.8), (.9, 0, -.6), (1.3, 0, -1.2)], .13)
finish(f, 'VFX_23_FulmineDardo', 'Fulmine', 'Saetta ramificata; avanti lungo X', animation='flash breve + traslazione lungo X')
f = Form()
for i in range(7):
    a = i * TAU / 7
    points = []
    for j in range(8):
        r = .25 + 1.25 * math.sin(math.pi * j / 7) + (.14 if j % 2 else -.06)
        points.append((r * math.cos(a), r * math.sin(a), j * .42))
    f.bolt(points, .11, plane=(-math.sin(a), math.cos(a), 0))
finish(f, 'VFX_24_FulmineGabbia', 'Fulmine', 'Gabbia di sette archi elettrici', 'base', 'flash intermittente + dissolvenza')
f = Form()
f.spike((0, -1.35, 0), (0, 1.6, 0), .14, 6)
for i in range(6):
    y = -.95 + i * .38
    f.ribbon(.45 - i * .035, -.3, 3.8, .1, matrix=RX, offset=(0, y, 0), steps=20)
    f.spike((0, y, .25), (0, y - .1, .7 - i * .06), .10, 4)
finish(f, 'VFX_25_OssaSpina', 'Ossa', 'Proiettile a vertebre e costole; avanti lungo Y', animation='traslazione lungo Y + rotazione')
f = Form()
for upper in (-1, 1):
    f.ribbon(1.25, .18, math.pi - .36, .24, matrix=Matrix.Rotation(upper * math.pi / 2, 3, 'X'), offset=(0, 0, upper * .25))
    for i in range(7):
        x = -1 + i / 3
        z = upper * (.25 + math.sqrt(1.25 ** 2 - x * x))
        f.spike((x, 0, z), (x * .95, .12, z - upper * .5), .11, 5)
finish(f, 'VFX_26_OssaMorso', 'Ossa', 'Doppia arcata con zanne, attacco di morso')
f = Form()
for i in range(7):
    a = i * 2.4
    center = (.65 * math.cos(a), .6 * math.sin(a), .35 * math.sin(i * 1.7))
    for j in range(2):
        f.sphere_patch(.65 + j * 1.5, i + j, 3.8, .20, radius=.68, ragged=.2, offset=center)
finish(f, 'VFX_27_GasNube', 'Gas', 'Nube cava di sette volute; ciano e magenta')
f = Form()
for i in range(4):
    def jet(t, s, i=i):
        a = t * TAU * 1.25 + i * TAU / 4
        r = .16 + .68 * t + s * .1 * math.sin(math.pi * t)
        return r * math.cos(a), t * 3.6, r * math.sin(a)
    f.strip(jet, 64)
finish(f, 'VFX_28_GasGetto', 'Gas', 'Soffio spiraliforme che si allarga; avanti Y', 'emettitore', 'scala lungo Y + rotazione + dissolvenza')

# Otto attacchi di mostri: sagome leggibili anche senza texture.
f = Form()
for i in range(5):
    f.ribbon(1.3 + .08 * i, -.5, 2.6, .17, matrix=RX, offset=((i - 2) * .38, (i - 2) * .12, 0))
finish(f, 'VFX_29_YetiArtigli', 'Mostri', 'Cinque strisciate ricurve da artiglio')
f = Form()
for i in range(14):
    a = i * TAU / 14
    f.spike((.4 * math.cos(a), .4 * math.sin(a), .05), (1.6 * math.cos(a), 1.6 * math.sin(a), .25 + (i % 4) * .35), .12, 4)
f.ribbon(.55, 0, TAU, .2, .05, taper=False, jagged=.5)
finish(f, 'VFX_30_YetiPugno', 'Mostri', 'Impatto a schegge di neve e anello centrale', 'base')
f = Form()
for i in range(7):
    a = i * TAU / 7
    points = []
    for j in range(5):
        angle = a + (.16 if j % 2 else -.10)
        r = .1 + j * .5
        points.append((r * math.cos(angle), r * math.sin(angle), .04))
    f.bolt(points, .15, plane=(0, 0, 1))
    f.bolt([points[2], (1.35 * math.cos(a + .4), 1.35 * math.sin(a + .4), .04), (1.8 * math.cos(a + .35), 1.8 * math.sin(a + .35), .04)], .09, plane=(0, 0, 1))
finish(f, 'VFX_31_GolemFrattura', 'Mostri', 'Crepe radiali ramificate sul terreno', 'base', 'comparsa istantanea + dissolvenza')
f = Form()
for i in range(6):
    x = (i - 2.5) * .46
    f.spike((x, 0, 0), (x * 1.2, .15, 1.2 + .9 * math.sin((i + 1) * math.pi / 7)), .3, 5)
finish(f, 'VFX_32_GolemStalagmiti', 'Mostri', 'Fila di sei punte massicce di ghiaccio', 'base', 'crescita progressiva dal terreno')
f = Form()
for i in range(6):
    def breath(t, s, i=i):
        a = i * TAU / 6 + t * 2
        r = .1 + 1.2 * t
        a += s * .18 * math.sin(math.pi * t)
        return r * math.cos(a), t * 4.2, r * math.sin(a)
    f.strip(breath, 48)
for j in range(3):
    f.ribbon(.3 + j * .35, j, 4.8, .10, matrix=RX, offset=(0, .8 + j * 1.1, 0))
finish(f, 'VFX_33_GuardianoRespiro', 'Mostri', 'Grande cono di soffio aperto; avanti Y', 'emettitore', 'espansione lungo Y + rotazione')
f = Form()
for j in range(2):
    f.ribbon(1.1 + j * .55, .2 * j, TAU, .13, .04, taper=False, jagged=.25)
for i in range(16):
    a = i * TAU / 16
    f.spike((1.7 * math.cos(a), 1.7 * math.sin(a), .05), (2.3 * math.cos(a + .06), 2.3 * math.sin(a + .06), .10), .09, 4)
finish(f, 'VFX_34_GuardianoOnda', 'Mostri', 'Onda doppia a sedici raggi', 'base', 'espansione molto ampia + dissolvenza')
f = Form()
for side in (-1, 1):
    for i in range(5):
        x = (i - 2) * .45
        f.spike((x, 0, side * (.9 - abs(x) * .15)), (x + side * .15, 0, side * .15), .16, 3)
    f.bolt([(-1.25, 0, side * .7), (-.4, 0, side * 1.1), (.4, 0, side * 1.1), (1.25, 0, side * .7)], .12)
finish(f, 'VFX_35_MostroMorso', 'Mostri', 'Impronta di morso con dieci triangoli acuminati')
f = Form()
for i in range(3):
    f.ribbon(1.5 - i * .22, -.9 + i * .4, 4.6, .28 - i * .05, .1 + i * .18, .35)
for i in range(5):
    a = -.4 + i * .7
    f.spike((1.5 * math.cos(a), 1.5 * math.sin(a), .25), (1.95 * math.cos(a + .18), 1.95 * math.sin(a + .18), .35), .1, 4)
finish(f, 'VFX_36_MostroCoda', 'Mostri', 'Spazzata orizzontale curva con punte', 'base', 'rotazione orizzontale rapida + dissolvenza')

assert len(objects) == 36

def select_only(objs):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]

def export_fbx(path, objs):
    select_only(objs)
    bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, object_types={'MESH'},
        axis_forward='-Z', axis_up='Y', apply_unit_scale=True, bake_space_transform=False,
        use_mesh_modifiers=True, mesh_smooth_type='FACE', add_leaf_bones=False,
        bake_anim=False, path_mode='AUTO')

def check_mesh(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    bad = sum(1 for face in mesh.polygons if face.area < 1e-10)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    boundary = sum(e.is_boundary for e in bm.edges)
    nonmanifold = sum(not e.is_manifold for e in bm.edges)
    bm.free()
    uv = mesh.uv_layers.active
    finite = all(math.isfinite(c) for v in mesh.vertices for c in v.co)
    uv_ok = uv is not None and all(math.isfinite(c) and -.001 <= c <= 1.001 for loop in uv.data for c in loop.uv)
    result = dict(vertices=len(mesh.vertices), triangles=len(mesh.loop_triangles),
                  degenerate=bad, boundary_edges=boundary, nonmanifold_edges=nonmanifold,
                  uv_ok=uv_ok, finite=finite, dimensions=[round(d, 4) for d in obj.dimensions])
    assert bad == 0 and boundary == 0 and nonmanifold == 0 and finite and uv_ok, (obj.name, result)
    assert len(mesh.loop_triangles) <= 8000, (obj.name, 'Troppi triangoli')
    return result

bpy.context.view_layer.update()
for obj, record in zip(objects, records):
    record.update(check_mesh(obj))
    record['file'] = 'fbx/' + obj.name + '.fbx'
    export_fbx(OUT / (obj.name + '.fbx'), [obj])

# Una disposizione ordinata nel file principale facilita la scelta delle forme.
def arrange(obj, x, y):
    center = sum((Vector(corner) for corner in obj.bound_box), Vector()) / 8
    obj.location = Vector((x, y, 1.5)) - center

for i, obj in enumerate(objects):
    arrange(obj, (i % 6 - 2.5) * 6.0, (2.5 - i // 6) * 7.5)
export_fbx(ROOT / 'VFX_Kit_36.fbx', objects)

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 16
scene.cycles.use_denoising = True
scene.render.image_settings.file_format = 'PNG'
scene.render.resolution_percentage = 100
scene.world.color = (.035, .035, .035)
scene.view_settings.view_transform = 'Standard'

def move_stage(obj):
    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    stage.objects.link(obj)

bpy.ops.mesh.primitive_plane_add(size=300, location=(0, 0, -1.4))
floor = bpy.context.object
floor.name = 'Fondale_anteprima'
floor.data.materials.append(floor_mat)
move_stage(floor)
bpy.ops.object.light_add(type='AREA', location=(0, -5, 25))
lamp = bpy.context.object
lamp.data.energy = 2400
lamp.data.shape = 'DISK'
lamp.data.size = 25
move_stage(lamp)
bpy.ops.object.camera_add(location=(0, -40, 49))
camera = bpy.context.object
move_stage(camera)
camera.data.type = 'ORTHO'
scene.camera = camera

def aim(position, target, scale):
    camera.location = position
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.ortho_scale = scale

labels = []
for i, obj in enumerate(objects):
    text = bpy.data.curves.new('Etichetta', 'FONT')
    text.body = obj.name.replace('VFX_', '').replace(' ', '')
    text.align_x = 'CENTER'
    text.size = .24
    label = bpy.data.objects.new('Etichetta_' + obj.name, text)
    stage.objects.link(label)
    label.location = ((i % 6 - 2.5) * 6.0, (2.5 - i // 6) * 7.5 - 2.6, -.4)
    label.data.materials.append(label_mat)
    labels.append(label)

aim((0, -38, 48), (0, 0, .5), 42)
scene.render.resolution_x = 2304
scene.render.resolution_y = 2304
scene.render.filepath = str(PREVIEW / 'kit_36.png')
select_only(objects)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.region_3d.view_perspective = 'CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'VFX_Kit_36.blend'))

# Le verifiche degli export avvengono in un secondo processo, dopo questo salvataggio.
(ROOT / 'manifest.json').write_text(json.dumps(records, indent=2, ensure_ascii=False), encoding='utf-8')
if '--no-render' not in sys.argv:
    bpy.ops.render.render(write_still=True)
    for page in range(3):
        chosen = objects[page * 12:(page + 1) * 12]
        for obj in objects:
            obj.hide_render = obj not in chosen
        for label in labels:
            label.hide_render = True
        for k, obj in enumerate(chosen):
            arrange(obj, (k % 4 - 1.5) * 6, (1 - k // 4) * 7.5)
        for k, obj in enumerate(chosen):
            label = labels[page * 12 + k]
            label.hide_render = False
            label.location = ((k % 4 - 1.5) * 6, (1 - k // 4) * 7.5 - 2.6, -.4)
        aim((0, -28, 32), (0, 0, .5), 26)
        scene.render.resolution_x = 2000
        scene.render.resolution_y = 1560
        scene.render.filepath = str(PREVIEW / ('dettaglio_%d.png' % (page + 1)))
        bpy.ops.render.render(write_still=True)
print('[VFX] Completate 36 mesh, UV ed export FBX.')
