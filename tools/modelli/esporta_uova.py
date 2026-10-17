# Esporta le uova 3D di Codex (artifacts/uova-3d-20261016/v6, approvate da Mirko il 17/10) in JSON
# per tools/modelli/carica_uova.luau: un JSON per mesh dell'uovo intero (guscio, luce, gemma,
# castone e decori, ali), assi Roblox (Roblox = Blender (x, z, -y)), in studs, UV con la V
# capovolta. I frammenti della rottura per ora non si esportano (la schiusa fa i suoi pezzi).
# Uso: blender -b --factory-startup --python esporta_uova.py -- <cartella v6> <cartella json>
import bpy, sys, json, os, bmesh

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
manifest = json.load(open(os.path.join(src, "manifest.json"), encoding="utf-8"))
os.makedirs(out, exist_ok=True)


def export_obj(o, folder, texture_set):
    dg = bpy.context.evaluated_depsgraph_get()
    me = o.evaluated_get(dg).to_mesh()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    mw = o.matrix_world
    nm = mw.to_3x3().inverted().transposed()
    uv = me.uv_layers.get("UV_Export") or me.uv_layers.active
    uvl = uv.data if uv else None
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
            rn = (round(n.x, 3), round(n.z, 3), round(-n.y, 3))
            ru = (round(uvl[li].uv.x, 5), round(1 - uvl[li].uv.y, 5)) if uvl else (0.5, 0.5)
            tri.append((idx(P, pl, rp), idx(U, ul, ru), idx(N, nl, rn)))
        if len(tri) == 3:
            T.append(tri)
    o.evaluated_get(dg).to_mesh_clear()
    file = o.name.replace(".", "_")
    data = {
        "p": [c for v in pl for c in v], "u": [c for v in ul for c in v], "n": [c for v in nl for c in v],
        "t": [i for tri in T for corner in tri for i in corner],
    }
    with open(os.path.join(folder, file + ".json"), "w") as fh:
        json.dump(data, fh, separators=(",", ":"))
    return {"file": file, "set": texture_set, "tris": len(T), "min": mn, "max": mx}


for element, info in manifest["elements"].items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, info["fbx"]))
    sets = {w["name"]: w["texture_set"] for w in info["whole"]}
    folder = os.path.join(out, "Uovo_" + element)
    os.makedirs(folder, exist_ok=True)
    index = {"element": element, "parts": []}
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.name in sets:
            index["parts"].append(export_obj(o, folder, sets[o.name]))
    with open(os.path.join(folder, "index.json"), "w") as fh:
        json.dump(index, fh, indent=1)
    print("FATTO", element, len(index["parts"]), "parti", sum(p["tris"] for p in index["parts"]), "triangoli")
