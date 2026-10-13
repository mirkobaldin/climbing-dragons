# Esporta i modelli di Codex (case, falo', glider) in JSON per il caricamento da Studio
# (tools/modelli/LEGGIMI.md). Un JSON per oggetto: vertici in metri e assi Roblox (Y in alto:
# Roblox = Blender (x, z, -y)), UV con la V capovolta, normali, triangoli, materiale, osso
# principale (glider) e ingombro. index.json elenca le parti, la collisione e i marcatori.
import bpy, sys, json, os, bmesh

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
name = os.path.basename(os.path.normpath(src))
os.makedirs(out, exist_ok=True)


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def export_obj(o, prefix):
    dg = bpy.context.evaluated_depsgraph_get()
    me = o.evaluated_get(dg).to_mesh()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    mw = o.matrix_world
    nm = mw.to_3x3().inverted().transposed()
    uvl = me.uv_layers.active.data if me.uv_layers.active else None
    P, U, N, T = {}, {}, {}, []
    pl, ul, nl = [], [], []

    def idx(d, l, k):
        i = d.get(k)
        if i is None:
            i = len(l)
            d[k] = i
            l.append(k)
        return i

    mn, mx = [1e9] * 3, [-1e9] * 3
    for poly in me.polygons:
        tri = []
        for li in poly.loop_indices:
            p = mw @ me.vertices[me.loops[li].vertex_index].co
            rp = (round(p.x, 4), round(p.z, 4), round(-p.y, 4))
            for k in range(3):
                mn[k] = min(mn[k], rp[k])
                mx[k] = max(mx[k], rp[k])
            n = (nm @ me.corner_normals[li].vector).normalized()
            rn = (round(n.x, 2), round(n.z, 2), round(-n.y, 2))
            ru = (round(uvl[li].uv.x, 4), round(1 - uvl[li].uv.y, 4)) if uvl else (0.5, 0.5)
            tri.append((idx(P, pl, rp), idx(U, ul, ru), idx(N, nl, rn)))
        if len(tri) == 3:
            T.append(tri)
    # osso che muove la parte (il gruppo di vertici con piu' peso)
    bone = None
    if o.vertex_groups:
        weight = {}
        for v in me.vertices:
            for g in v.groups:
                weight[g.group] = weight.get(g.group, 0) + g.weight
        if weight:
            bone = o.vertex_groups[max(weight, key=weight.get)].name
    o.evaluated_get(dg).to_mesh_clear()
    mat = o.material_slots[0].material.name if o.material_slots and o.material_slots[0].material else None
    file = prefix + o.name.replace(".", "_")
    data = {
        "p": [c for v in pl for c in v], "u": [c for v in ul for c in v], "n": [c for v in nl for c in v],
        "t": [i for tri in T for corner in tri for i in corner],
    }
    with open(os.path.join(out, file + ".json"), "w") as fh:
        json.dump(data, fh, separators=(",", ":"))
    return {"file": file, "name": o.name, "material": mat, "bone": bone, "tris": len(T), "min": mn, "max": mx}


index = {"model": name, "parts": [], "collision": [], "bones": {}}
main = os.path.join(src, name + ".fbx")
for o in load(main):
    index["parts"].append(export_obj(o, ""))
# teste e code delle ossa (per far battere le ali dei glider)
for a in [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]:
    for b in a.data.bones:
        h, t = a.matrix_world @ b.head_local, a.matrix_world @ b.tail_local
        index["bones"][b.name] = {"head": [h.x, h.z, -h.y], "tail": [t.x, t.z, -t.y]}
col = os.path.join(src, name + "_Collision.fbx")
if os.path.exists(col):
    for o in load(col):
        index["collision"].append(export_obj(o, "COL_"))
mk = os.path.join(src, "Markers.json")
if os.path.exists(mk):
    index["markers"] = json.load(open(mk, encoding="utf-8"))
mt = os.path.join(src, "Materials.json")
if os.path.exists(mt):
    index["materials"] = json.load(open(mt, encoding="utf-8"))
with open(os.path.join(out, "index.json"), "w") as fh:
    json.dump(index, fh, indent=1)
print("FATTO", name, len(index["parts"]), "parti", len(index["collision"]), "collisioni",
      sum(p["tris"] for p in index["parts"]), "triangoli")
