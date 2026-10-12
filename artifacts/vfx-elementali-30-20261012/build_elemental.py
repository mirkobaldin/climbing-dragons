"""Trenta nuove forme elementali: geometria, atlante colori e tavole Blender."""
import bpy, bmesh, math, random, json, sys, warnings
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parent
for folder in ('fbx', 'preview', 'textures'):
    (ROOT / folder).mkdir(exist_ok=True)
TAU = math.tau
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 20
scene.cycles.use_denoising = True
scene.world.color = (.015, .018, .027)
scene.view_settings.view_transform = 'Standard'
scene.view_settings.exposure = -.35
COLORS = {
 'Roccia': ['45332C', '976646', 'F6AC51', 'FFE2A2'],
 'Gelo': ['124A75', '279BD0', '85EDFF', 'E7FCFF'],
 'Cosmico': ['241642', '693ECC', 'ED5CDD', 'DFBCFF'],
 'Tempesta': ['233F65', '4B8FAF', 'A8EDF8', 'EFFCFF'],
 'Eclissi': ['100E1C', '57243B', 'FF6825', 'FFCC66'],
 'Fulmine': ['241337', '7434C8', 'BA71FF', 'EFE0FF'],
 'Ossa': ['45353C', '9F8475', 'EDDBB6', 'FFF7DC'],
 'Gas': ['263756', '40CCE3', 'E764CD', 'DDFBFF'],
}
elements = list(COLORS)
def rgb(code):
    return tuple(int(code[i:i+2], 16) / 255 for i in (0, 2, 4))

# Atlante autentico, senza dipendenze esterne: 4 campioni per ognuno degli 8 elementi.
atlas = bpy.data.images.new('VFX_Palette', width=128, height=256, alpha=True)
pixels = []
for y in range(256):
    el = elements[y // 32]
    for x in range(128):
        pixels.extend((*rgb(COLORS[el][x // 32]), 1))
atlas.pixels.foreach_set(pixels)
atlas.filepath_raw = str(ROOT / 'textures' / 'VFX_Palette.png')
atlas.file_format = 'PNG'
atlas.save()
atlas.pack()
mat = bpy.data.materials.new('VFX_Atlante_Elementi')
with warnings.catch_warnings():
    warnings.simplefilter('ignore', DeprecationWarning)
    mat.use_nodes = True
nodes = mat.node_tree.nodes
bsdf = nodes.get('Principled BSDF')
tex = nodes.new('ShaderNodeTexImage')
tex.image = atlas
tex.interpolation = 'Closest'
mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Emission Color'])
bsdf.inputs['Emission Strength'].default_value = 1.35
bsdf.inputs['Metallic'].default_value = .25
bsdf.inputs['Roughness'].default_value = .28

class Shape:
    def __init__(self):
        self.v, self.f, self.c = [], [], []
    def add(self, verts, faces, color):
        start = len(self.v)
        self.v.extend(tuple(v) for v in verts)
        self.f.extend(tuple(start + i for i in face) for face in faces)
        self.c.extend([color] * len(faces) if isinstance(color, int) else color)
    def surface(self, fn, count=48, color=2):
        verts = [fn(i / count, s) for i in range(count + 1) for s in (-1, 0, 1)]
        faces = []
        for i in range(count):
            for s in range(2):
                a = i * 3 + s
                faces.append((a, a + 3, a + 4, a + 1))
        self.add(verts, faces, color)
    def arc(self, r, a, length, width, color=2, z=0, rise=0, rotate=None, offset=(0,0,0)):
        off = Vector(offset)
        def fn(t, s):
            angle = a + length * t
            w = width * (.018 + math.sin(math.pi * t) ** .85)
            p = Vector(((r + s*w/2)*math.cos(angle), (r+s*w/2)*math.sin(angle), z+rise*t + (1-abs(s))*.035))
            return (rotate @ p if rotate is not None else p) + off
        self.surface(fn, max(12, int(abs(length)*12)), color)
    def curl(self, r0, r1, height, turns, phase, width, color=2, axis='Z', offset=(0,0,0)):
        off = Vector(offset)
        def fn(t, s):
            a = phase + turns*TAU*t
            r = r0 + (r1-r0)*t
            w = width*(.02 + math.sin(math.pi*t)**.7)
            p = Vector((r*math.cos(a), r*math.sin(a), height*t+s*w/2))
            if axis == 'Y': p = Vector((p.x, p.z, p.y))
            return p + off
        self.surface(fn, max(36, int(turns*48)), color)
    def blade(self, points, width, color=2, normal=(0,0,1)):
        """Curva di Bezier cubica, cresta centrale e punte affusolate."""
        p = list(map(Vector, points))
        n = Vector(normal)
        def curve(t): return p[0]*(1-t)**3 + p[1]*3*t*(1-t)**2 + p[2]*3*t*t*(1-t) + p[3]*t**3
        def fn(t, s):
            tangent = (curve(min(1,t+.001))-curve(max(0,t-.001))).normalized()
            lateral = tangent.cross(n).normalized()
            w = width*(.015+math.sin(math.pi*t)**.8)*(1-.55*t)
            return curve(t)+lateral*w*s + n*(1-abs(s))*.05*math.sin(math.pi*t)
        self.surface(fn, 28, color)
    def tube(self, points, radius=.07, color=2, sides=6):
        pts = list(map(Vector, points))
        verts = []
        for i,p in enumerate(pts):
            tangent = (pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]).normalized()
            u = tangent.cross(Vector((0,0,1)))
            if u.length < .05: u = tangent.cross(Vector((0,1,0)))
            u.normalize(); v = tangent.cross(u).normalized()
            r = radius*(.15+.85*math.sin(math.pi*(i+.3)/(len(pts)-.4))**.5)
            for j in range(sides): verts.append(p+r*(u*math.cos(j*TAU/sides)+v*math.sin(j*TAU/sides)))
        faces = [tuple(range(sides-1,-1,-1))]
        for i in range(len(pts)-1):
            for j in range(sides):
                a=i*sides+j; b=i*sides+(j+1)%sides
                faces.append((a,b,b+sides,a+sides))
        faces.append(tuple((len(pts)-1)*sides+j for j in range(sides)))
        self.add(verts, faces, color)
    def crystal(self, base, tip, radius=.2, color=1, sides=6):
        base, tip = Vector(base),Vector(tip)
        axis=(tip-base).normalized(); u=axis.cross(Vector((0,1,0)))
        if u.length<.1: u=axis.cross(Vector((1,0,0)))
        u.normalize(); v=axis.cross(u).normalized()
        verts=[base,tip]
        for fraction, scale in ((.18,.8),(.62,1)):
            for j in range(sides): verts.append(base.lerp(tip,fraction)+radius*scale*(u*math.cos(j*TAU/sides)+v*math.sin(j*TAU/sides)))
        faces=[]; colors=[]
        for j in range(sides):
            a=2+j; b=2+(j+1)%sides
            faces.extend(((0,b,a),(a,b,b+sides,a+sides),(a+sides,b+sides,1)))
            colors.extend((color, min(3,color+(j%3==0)), min(3,color+1)))
        self.add(verts,faces,colors)
    def orb(self, radius=1, bands=5, color=2, offset=(0,0,0), phase=0):
        for band in range(bands):
            theta=.25+(math.pi-.5)*band/max(1,bands-1)
            for seg in range(3):
                phi=seg*TAU/3 + phase + band*.5
                def fn(t,s,theta=theta,phi=phi):
                    a=theta+s*.10*(.025+math.sin(math.pi*t)**.7)
                    b=phi+t*1.75
                    return Vector((radius*math.sin(a)*math.cos(b),radius*math.sin(a)*math.sin(b),radius*math.cos(a)))+Vector(offset)
                self.surface(fn,14,color)

RX=Matrix.Rotation(math.pi/2,3,'X')
RY=Matrix.Rotation(math.pi/2,3,'Y')
def radial(r,a,z=0): return (r*math.cos(a),r*math.sin(a),z)
records=[]; objects=[]
def finish(s,name,el,role,animation,pivot='centro'):
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(s.v,[],s.f); mesh.update()
    uv=mesh.uv_layers.new(name='UVMap')
    row=elements.index(el)
    for poly,color in zip(mesh.polygons,s.c):
        # Ogni faccia usa un campione dell'atlante, con margine per il filtraggio.
        for n,loop in enumerate(poly.loop_indices):
            a=n*TAU/len(poly.loop_indices)
            uv.data[loop].uv=((color+.5+.28*math.cos(a))/4,(row+.5+.28*math.sin(a))/8)
    obj=bpy.data.objects.new(name,mesh); scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bm=bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(mesh); bm.free()
    # Le superfici aperte dei nastri ricevono spessore; i volumi restano pieni.
    mod=obj.modifiers.new('Spessore_nastri','SOLIDIFY'); mod.thickness=.009; mod.offset=0
    bpy.ops.object.modifier_apply(modifier=mod.name)
    tri=obj.modifiers.new('Triangoli','TRIANGULATE'); bpy.ops.object.modifier_apply(modifier=tri.name)
    bpy.context.view_layer.update(); mesh=obj.data; mesh.calc_loop_triangles()
    assert all(p.area>1e-11 for p in mesh.polygons),name
    assert len(mesh.loop_triangles)<15000,(name,len(mesh.loop_triangles))
    obj['elemento']=el; obj['attacco']=role; obj['pivot']=pivot
    records.append(dict(name=name,element=el,role=role,animation=animation,pivot=pivot,
        triangles=len(mesh.loop_triangles),dimensions=list(obj.dimensions),
        file='fbx/'+name+'.fbx',texture='textures/VFX_Palette.png',palette=COLORS[el]))
    objects.append(obj)

# DISEGNI_ELEMENTALI
s=Shape()
for i in range(7):
    a=i*TAU/7
    s.crystal(radial(.38,a,-.8),radial(1.0,a+.25,1.4-(i%3)*.25),.25,0,5)
    s.tube([radial(.42,a,-.6),radial(.65,a+.2,.1),radial(.8,a+.25,.8)],.04,3)
s.arc(1.35,0,4.5,.2,2,z=-.3,rise=.4)
finish(s,'VFX_37_RocciaCuoreFratturato','Roccia','Cuore di pietra aperto con fratture ambra','rotazione lenta, poi lancio')
s=Shape()
for i in range(5):
    a=i*TAU/5
    pts=[radial(.6,a,0),radial(1.9,a+.2,.3),radial(2.1,a+.5,1.7),radial(.9,a+.7,2.1)]
    s.blade(pts,.30,1,normal=radial(1,a+math.pi/2))
    s.crystal(radial(1.4,a,.2),radial(1.8,a+.2,1.2),.2,0)
finish(s,'VFX_38_RocciaArtiglioTellurico','Roccia','Cinque artigli di pietra che si richiudono','emersione dal terreno e stretta', 'base')
s=Shape()
for i in range(10):
    a=i*TAU/10
    s.crystal(radial(1.1,a,-.1),radial(2.2,a+.15,.25+(i%2)*.7),.24,0,5)
    s.arc(1.55,a,.5,.09,3,z=.02)
s.arc(.85,0,TAU,.20,2,z=.03)
finish(s,'VFX_39_RocciaFagliaRadiale','Roccia','Frattura circolare con schegge inclinate','espansione e dissolvenza','base')
s=Shape()
for j in range(3):
    a=j*TAU/3
    s.blade([radial(.3,a,-.9),radial(1.7,a,-.4),radial(1.8,a+.7,.8),radial(.2,a+1,1.6)],.42,1,normal=radial(1,a+1.6))
    s.crystal(radial(.5,a,-.7),radial(.2,a,1.8),.17,2)
s.arc(1.7,0,4.6,.07,3,rotate=RX)
finish(s,'VFX_40_RocciaAriete','Roccia','Testa di proiettile corazzata a tre scaglie','carica e impatto lungo Z')

s=Shape()
s.crystal((0,0,-1.8),(0,0,2.2),.36,1)
for i in range(3):
    a=i*TAU/3
    s.crystal(radial(.35,a,-1.0),radial(.65,a,.95),.14,2)
    s.curl(.8,.28,3.0,.8,a,.11,3,offset=(0,0,-1.4))
finish(s,'VFX_41_GeloLanciaAurora','Gelo','Lancia centrale a facce nette con tre filamenti','lancio e rotazione lungo Z')
s=Shape()
for i in range(6):
    a=i*TAU/6
    s.crystal(radial(.1,a),radial(2.0,a),.11,2,4)
    for k in (-1,1):
        base=Vector(radial(1.05,a)); tip=base+Vector(radial(.68,a+k*.75))
        s.crystal(base,tip,.06,3,4)
s.arc(.6,0,TAU,.1,1,z=.05)
finish(s,'VFX_42_GeloSigilloEsagonale','Gelo','Fiocco esagonale con dodici ramificazioni','rotazione e comparsa sotto il bersaglio','base')
s=Shape()
for i in range(8):
    a=i*TAU/8
    s.crystal(radial(.55,a,0),radial(1.65,a,1.6+.35*(i%2)),.24,1)
    s.blade([radial(.45,a,0),radial(1.2,a,.4),radial(1.5,a,1.1),radial(1.7,a,1.9)],.12,3,normal=radial(1,a+1.57))
s.crystal((0,0,0),(0,0,2.5),.28,2)
finish(s,'VFX_43_GeloLotoGlaciale','Gelo','Eruzione a fiore con otto petali di cristallo','apertura verticale dal terreno','base')
s=Shape()
for i in range(7):
    a=-.8+i*.3
    s.crystal((1.2*math.cos(a),0,1.2*math.sin(a)),(2.0*math.cos(a+.1),0,2.0*math.sin(a+.1)),.17,1)
s.arc(1.35,-.95,3.2,.42,2,rotate=RX)
s.arc(1.7,-.8,2.8,.055,3,rotate=RX,offset=(0,-.05,0))
finish(s,'VFX_44_GeloAlaTagliente','Gelo','Fendente alato con sette penne di ghiaccio','arco di taglio verticale')

s=Shape(); s.orb(.65,4,1)
for i in range(3):
    rot=Matrix.Rotation(.65+i*.7,3,'X') @ Matrix.Rotation(i*.8,3,'Y')
    s.arc(1.35+i*.12,i,5.5,.065,2+i%2,rotate=rot)
    p=rot@Vector(radial(1.35+i*.12,i+.8)); s.crystal(p-Vector((0,0,.15)),p+Vector((0,0,.15)),.10,3,4)
finish(s,'VFX_45_CosmicoAstrolabio','Cosmico','Nucleo a scaglie con tre orbite stellari','rotazione su due assi')
s=Shape()
for i in range(4):
    s.curl(.25,1.65,.25,1.05,i*TAU/4,.24,1+i%3)
s.orb(.7,4,0,offset=(0,0,.15))
for i in range(8):
    a=i*TAU/8
    s.crystal(radial(1.9,a,-.12),radial(1.9,a,.12),.065,3,4)
finish(s,'VFX_46_CosmicoDiscoAccrescimento','Cosmico','Disco galattico a quattro bracci attorno al vuoto','rotazione orizzontale e contrazione')
s=Shape(); s.crystal((0,-.45,0),(0,.75,0),.55,1,5)
for i in range(5):
    a=i*TAU/5
    s.blade([(math.cos(a)*.45,-.2,math.sin(a)*.45),(math.cos(a)*1.0,-1.1,math.sin(a)*.8),(math.cos(a+.7)*.6,-2.5,math.sin(a+.7)*.6),(0,-3.5,0)],.15,2+i%2,normal=radial(1,a+1.57))
finish(s,'VFX_47_CosmicoCometaAstrale','Cosmico','Cometa sfaccettata con cinque code incurvate','punta avanti Y e scia dietro')
s=Shape()
for j in range(2):
    for i in range(4): s.arc(1.3+j*.3,i*TAU/4+j*.25,1.35,.12-j*.04,2+j,rotate=RX)
for i in range(8):
    a=i*TAU/8
    s.crystal((1.45*math.cos(a),0,1.45*math.sin(a)),(2.05*math.cos(a),0,2.05*math.sin(a)),.11,1,4)
s.arc(.85,0,TAU,.04,3,rotate=RY)
finish(s,'VFX_48_CosmicoStellaDimensionale','Cosmico','Sigillo tridimensionale con otto punte stellari','espansione e rotazione')

s=Shape()
for sign in (-1,1):
    for j in range(4):
        s.blade([(0,0,.1),(sign*(.8+j*.2),-.5,.35),(sign*(1.7+j*.18),-.5,1.3-j*.18),(sign*(2.5-j*.16),.4,1.6-j*.3)],.19,1+j%3,normal=(0,-1,0))
finish(s,'VFX_49_TempestaAliBurrasca','Tempesta','Due ali di vento con quattro piume arcuate','battito e proiezione in avanti')
s=Shape()
for i in range(3):
    s.curl(.12,1.65,3.5,1.6,i*TAU/3,.19,1+i)
for j in range(3): s.arc(1.5+j*.12,j*2,1.5,.08,3,z=3.2+j*.1)
finish(s,'VFX_50_TempestaCicloneSpirale','Tempesta','Ciclone con tre correnti e cresta sfilacciata','rotazione verticale e crescita','base')
s=Shape()
for i in range(5):
    a=i*TAU/5
    s.blade([radial(.3,a),radial(1.5,a-.3),radial(2.5,a+.6),radial(1.1,a+1.8)],.28,1+i%3)
    s.arc(1.5,a,.9,.055,3,z=.12)
finish(s,'VFX_51_TempestaRasoioEolico','Tempesta','Cinque falci aerodinamiche a girandola','rotazione rapida e lancio orizzontale')
s=Shape()
for i in range(4):
    rot=Matrix.Rotation(i*math.pi/4,3,'X')
    s.arc(1.35,-.3+i,4.2,.15,1+i%3,rotate=rot)
    s.arc(1.5,1+i,1.6,.04,3,rotate=rot)
finish(s,'VFX_52_TempestaOcchioUragano','Tempesta','Guscio di correnti con centro aperto','rotazione su asse del volo')

s=Shape(); s.orb(.85,5,0)
s.arc(1.3,0,TAU,.24,1,rotate=RX)
s.arc(1.4,0,TAU,.065,3,rotate=RX,offset=(0,-.02,0))
for i in range(12):
    a=i*TAU/12
    s.blade([(1.35*math.cos(a),0,1.35*math.sin(a)),(1.65*math.cos(a+.1),0,1.65*math.sin(a+.1)),(1.9*math.cos(a+.18),0,1.9*math.sin(a+.18)),(1.7*math.cos(a+.4),0,1.7*math.sin(a+.4))],.09,2,normal=(0,1,0))
finish(s,'VFX_53_EclissiSoleNero','Eclissi','Nucleo nero con corona arancio e dodici lingue','carica e pulsazione')
s=Shape()
s.arc(1.5,-1.1,4.4,.72,0,rotate=RX)
s.arc(1.73,-1.05,4.3,.12,2,rotate=RX,offset=(0,-.03,0))
s.arc(1.84,-1.0,4.0,.04,3,rotate=RX,offset=(0,-.04,0))
for i in range(3):
    a=.2+i*.75
    s.crystal((1.6*math.cos(a),0,1.6*math.sin(a)),(2.1*math.cos(a+.1),0,2.1*math.sin(a+.1)),.13,1,4)
finish(s,'VFX_54_EclissiLamaApocalisse','Eclissi','Lama scura larga con doppio filo incandescente','taglio verticale')
s=Shape()
for i in range(8):
    a=i*TAU/8
    s.blade([radial(.4,a),radial(1.1,a-.35),radial(2.0,a-.1),radial(2.4,a+.35)],.3,0)
    s.blade([radial(.55,a,.035),radial(1.2,a-.25,.035),radial(2.1,a,.035),radial(2.35,a+.35,.035)],.055,2)
s.arc(.8,0,TAU,.1,3,z=.02)
finish(s,'VFX_55_EclissiNovaOscura','Eclissi','Otto petali scuri bordati di fuoco arancio','detonazione radiale','base')
s=Shape()
for j in range(3):
    s.curl(.2,.8,3.1,.85,j*TAU/3,.28,0,axis='Y')
    s.curl(.24,.84,3.1,.85,j*TAU/3+.12,.045,2,axis='Y')
s.orb(.75,4,1,offset=(0,3.1,0))
s.arc(.9,0,TAU,.06,3,rotate=RX,offset=(0,3.1,0))
finish(s,'VFX_56_EclissiSerpenteSolare','Eclissi','Soffio intrecciato con testa ad anello','espansione da origine lungo Y','emettitore')

def lightning(s,points,width=.08):
    s.tube(points,width,1,5)
    s.tube([(x,y-width*1.1,z+.015) for x,y,z in points],width*.28,3,5)
s=Shape()
lightning(s,[(-2,0,-.25),(-.9,0,.5),(-1.2,0,-.35),(.15,0,.4),(-.1,0,-.2),(2.2,0,.15)],.14)
for sign in (-1,1): lightning(s,[(-.45,0,.2),(.1,0,sign*.85),(.5,0,sign*.7),(1.1,0,sign*1.3)],.07)
finish(s,'VFX_57_FulmineLanciaRamificata','Fulmine','Saetta spessa con nucleo chiaro e due rami','flash e lancio lungo X')
s=Shape()
for i in range(5):
    a=i*TAU/5
    pts=[radial(.1,a,-1.5),radial(.55,a,-.7),radial(.35,a,-.3),radial(1.25,a,.5),radial(.95,a,.7),radial(1.7,a,1.5)]
    lightning(s,pts,.065)
s.arc(.65,0,5.6,.06,2,z=-.5)
finish(s,'VFX_58_FulmineArtiglioTuono','Fulmine','Cinque dita elettriche che si aprono','apertura a ventaglio')
s=Shape()
for i in range(6):
    rot=Matrix.Rotation(i*math.pi/3,3,'Z')
    pts=[]
    for j in range(13):
        a=j*TAU/12; r=1.25+(.13 if j%2 else -.08)
        pts.append(tuple(rot@Vector((r*math.sin(a),.15*math.sin(j*2),r*math.cos(a)))))
    lightning(s,pts,.035)
s.crystal((0,0,-.4),(0,0,.4),.22,2,4)
finish(s,'VFX_59_FulmineSferaTesla','Fulmine','Gabbia sferica di archi spezzati con nucleo','rotazione e lampeggio')
s=Shape()
for i in range(6):
    a=i*TAU/6
    pts=[radial(.2,a,.02),radial(.8,a+.15,.02),radial(1.0,a-.1,.02),radial(1.6,a+.12,.02),radial(2.1,a,.02)]
    lightning(s,pts,.055)
    lightning(s,[pts[2],radial(1.4,a+.45,.02),radial(1.7,a+.55,.02)],.03)
for i in range(6): s.arc(1.7,i*TAU/6,.6,.045,2,z=.04)
finish(s,'VFX_60_FulmineReteParalizzante','Fulmine','Rete a sei saette con rami e corona interrotta','flash a terra e dissolvenza','base')

s=Shape()
for sign in (-1,1):
    points=[(1.4*math.cos(.15+j*(math.pi-.3)/20),0,sign*(.2+math.sin(.15+j*(math.pi-.3)/20))) for j in range(21)]
    s.tube(points,.15,1,8)
    for j in range(9):
        x=(j-4)*.29; z=sign*(.2+math.sqrt(max(.01,1-(x/1.4)**2)))
        s.crystal((x,0,z),(x*.92,.05,z-sign*(.38+.2*(j%2))),.085,2,5)
    for side in (-1,1): s.crystal((side*1.2,0,sign*.4),(side*1.65,0,sign*1.1),.12,1,5)
finish(s,'VFX_61_OssaFauciDraconiche','Ossa','Mascelle arcuate con diciotto zanne e quattro corni','chiusura suggerita con scala verticale')
s=Shape()
for i in range(5):
    x=(i-2)*.52
    points=[(x,-.8,0),(x*1.1,-.3,.2),(x*1.1,.4,.5),(x*.9,1,.3),(x*.7,1.45,-.3)]
    s.tube(points,.14,2,7)
    s.crystal(points[-2],(x*.6,1.8,-.7),.13,3,5)
    s.crystal((x,-.5,.06),(x,-.3,.35),.12,1,5)
finish(s,'VFX_62_OssaArtiglioScheletrico','Ossa','Cinque dita curve con nocche e unghie','spazzata in avanti Y')
s=Shape()
for i in range(9):
    a=i*.8; z=(i-4)*.3
    s.crystal(radial(.12,a,z-.1),radial(.12,a,z+.16),.18,1,5)
    rot=Matrix.Rotation(a,3,'Z') @ RX
    s.arc(.55,0,math.pi,.13,2,rotate=rot,offset=(0,0,z))
    s.crystal(radial(.3,a,z),radial(.9,a,z+.15),.095,2,5)
finish(s,'VFX_63_OssaSpiraleVertebre','Ossa','Colonna ruotata di nove vertebre con costole','rotazione e proiezione lungo Z')

s=Shape()
for i in range(6):
    a=i*TAU/6
    s.blade([radial(.2,a),radial(1.2,a-.4,.3),radial(2.0,a+.2,1.1),radial(.8,a+1.2,1.7)],.28,1+i%2,normal=radial(1,a+1.57))
    s.arc(1.4,a,1.1,.05,3,z=.4)
finish(s,'VFX_64_GasLotoMiasma','Gas','Sei volute alternate ciano e magenta a fiore','apertura e rotazione lenta','base')
s=Shape()
for i in range(5):
    a=i*TAU/5
    rot=Matrix.Rotation(a,3,'Z') @ Matrix.Rotation(.5,3,'X')
    s.arc(1.1,a,4.7,.27,1+i%2,rotate=rot)
    s.arc(1.35,a+.4,1.6,.055,3,rotate=rot)
finish(s,'VFX_65_GasBollaVorticosa','Gas','Cinque veli curvi con spazi aperti e filamenti chiari','rotazione morbida del proiettile')
s=Shape()
for i in range(4):
    a=i*TAU/4
    s.curl(.15,1.1,3.8,1.0,a,.25,1+i%2,axis='Y')
    s.curl(.2,1.18,3.8,1.0,a+.1,.05,3,axis='Y')
for i in range(3):
    s.arc(.55+i*.25,i*.6,4.0,.08,2,rotate=RX,offset=(0,1.5+i*.9,0))
finish(s,'VFX_66_GasSoffioSerpentino','Gas','Getto a quattro veli e anelli di pressione','crescita lungo Y e dissolvenza','emettitore')

assert len(objects)==30

def export(path,objs):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objs: obj.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},
        axis_forward='-Z',axis_up='Y',bake_space_transform=False,apply_unit_scale=True,
        bake_anim=False,add_leaf_bones=False,path_mode='COPY',embed_textures=True)

for obj,record in zip(objects,records):
    export(ROOT/record['file'],[obj])

def place(obj,x,y):
    center=sum((Vector(c) for c in obj.bound_box),Vector())/8
    obj.location=Vector((x,y,1.6))-center
for i,obj in enumerate(objects): place(obj,(i%6-2.5)*8,(2-i//6)*9)
export(ROOT/'VFX_Elementali_30.fbx',objects)
(ROOT/'manifest.json').write_text(json.dumps(records,indent=2,ensure_ascii=False),encoding='utf-8')

def plain_material(name,color,emission=0):
    m=bpy.data.materials.new(name)
    with warnings.catch_warnings():
        warnings.simplefilter('ignore',DeprecationWarning); m.use_nodes=True
    b=m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value=(*color,1)
    b.inputs['Roughness'].default_value=.7
    b.inputs['Emission Color'].default_value=(*color,1)
    b.inputs['Emission Strength'].default_value=emission
    return m
floor_mat=plain_material('Fondale',(.012,.017,.029))
text_mat=plain_material('Testo',(.65,.77,.88),.6)
stage=bpy.data.collections.new('SOLO_ANTEPRIMA'); scene.collection.children.link(stage)
def staging(obj):
    for col in list(obj.users_collection): col.objects.unlink(obj)
    stage.objects.link(obj)
bpy.ops.mesh.primitive_plane_add(size=300,location=(0,0,-1.5))
floor=bpy.context.object; floor.data.materials.append(floor_mat); staging(floor)
for position,power,size in [((0,-10,28),3500,25),((15,12,20),2400,20)]:
    bpy.ops.object.light_add(type='AREA',location=position)
    light=bpy.context.object; light.data.energy=power; light.data.shape='DISK'; light.data.size=size
    staging(light)
bpy.ops.object.camera_add(); camera=bpy.context.object; staging(camera)
camera.data.type='ORTHO'; scene.camera=camera
def aim(scale):
    camera.location=(0,-40,48)
    camera.rotation_euler=(Vector((0,0,.5))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=scale
labels=[]
for i,obj in enumerate(objects):
    curve=bpy.data.curves.new('Etichetta','FONT'); curve.body=obj.name.replace('VFX_','')
    curve.size=.26; curve.align_x='CENTER'
    label=bpy.data.objects.new('Etichetta_'+obj.name,curve); stage.objects.link(label)
    label.location=((i%6-2.5)*8,(2-i//6)*9-3.25,-.5); curve.materials.append(text_mat)
    labels.append(label)
aim(51)
scene.render.resolution_x=2700; scene.render.resolution_y=2500
scene.render.resolution_percentage=100; scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(ROOT/'preview'/'30_elementali.png')
# Alone contenuto solo nelle anteprime: non nasconde bordi e aperture delle mesh.
comp=bpy.data.node_groups.new('Anteprima_VFX','CompositorNodeTree')
comp.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
layers=comp.nodes.new('CompositorNodeRLayers')
glow=comp.nodes.new('CompositorNodeGlare')
glow.inputs['Type'].default_value='Fog Glow'
glow.inputs['Strength'].default_value=.18
glow.inputs['Size'].default_value=.08
output=comp.nodes.new('NodeGroupOutput')
comp.links.new(layers.outputs['Image'],glow.inputs['Image'])
comp.links.new(glow.outputs['Image'],output.inputs['Image'])
scene.compositing_node_group=comp
bpy.ops.object.select_all(action='DESELECT')
for obj in objects: obj.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'VFX_Elementali_30.blend'))
if '--no-render' not in sys.argv:
    bpy.ops.render.render(write_still=True)
    for page in range(4):
        chosen=objects[page*8:(page+1)*8]
        for obj in objects: obj.hide_render=obj not in chosen
        for label in labels: label.hide_render=True
        for i,obj in enumerate(chosen):
            place(obj,(i%4-1.5)*8,(.5-i//4)*9)
            label=labels[page*8+i]; label.hide_render=False
            label.location=((i%4-1.5)*8,(.5-i//4)*9-3.25,-.5)
        aim(34); scene.render.resolution_x=2000; scene.render.resolution_y=1300
        scene.render.filepath=str(ROOT/'preview'/('dettaglio_%d.png'%(page+1)))
        bpy.ops.render.render(write_still=True)
print('[VFX] Trenta nuovi effetti elementali completati.')
