# Esporta i 66 FBX VFX in JSON compatti (posizioni Roblox Y-up, UV con v capovolta)
import bpy, sys, json, os, glob, bmesh

argv = sys.argv[sys.argv.index("--") + 1:]
src_dirs, out_dir = argv[:-1], argv[-1]
os.makedirs(out_dir, exist_ok=True)

files = []
for d in src_dirs:
    files += sorted(glob.glob(os.path.join(d, "fbx", "*.fbx")))

report = []
for f in files:
    name = os.path.splitext(os.path.basename(f))[0]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=f)
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    P, U, N, T = {}, {}, {}, []
    pl, ul, nl = [], [], []
    def idx(dic, lst, key):
        i = dic.get(key)
        if i is None:
            i = len(lst)
            dic[key] = i
            lst.append(key)
        return i
    mn = [1e9] * 3
    mx = [-1e9] * 3
    for o in objs:
        dg = bpy.context.evaluated_depsgraph_get()
        me = o.evaluated_get(dg).to_mesh()
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bm.to_mesh(me)
        bm.free()
        me.calc_loop_triangles() if hasattr(me, "calc_loop_triangles") else None
        mw = o.matrix_world
        nm = mw.to_3x3().inverted().transposed()
        uvl = me.uv_layers.active.data if me.uv_layers.active else None
        cn = me.corner_normals if hasattr(me, "corner_normals") else None
        for poly in me.polygons:
            tri = []
            for li in poly.loop_indices:
                vi = me.loops[li].vertex_index
                p = mw @ me.vertices[vi].co
                rp = (round(p.x, 3), round(p.z, 3), round(-p.y, 3))
                for k in range(3):
                    mn[k] = min(mn[k], rp[k]); mx[k] = max(mx[k], rp[k])
                if cn is not None:
                    n = (nm @ cn[li].vector).normalized()
                else:
                    n = (nm @ poly.normal).normalized()
                rn = (round(n.x, 2), round(n.z, 2), round(-n.y, 2))
                if uvl is not None:
                    uv = uvl[li].uv
                    ru = (round(uv.x, 4), round(1 - uv.y, 4))
                else:
                    ru = (0.5, 0.5)
                tri.append((idx(P, pl, rp), idx(U, ul, ru), idx(N, nl, rn)))
            if len(tri) == 3:
                T.append(tri)
        o.evaluated_get(dg).to_mesh_clear()
    data = {
        "name": name,
        "p": [c for v in pl for c in v],
        "u": [c for v in ul for c in v],
        "n": [c for v in nl for c in v],
        "t": [i for tri in T for corner in tri for i in corner],
        "min": mn, "max": mx,
        "tex": any(len(m.texture_paint_images) > 0 or m.use_nodes for m in bpy.data.materials) if bpy.data.materials else False,
    }
    with open(os.path.join(out_dir, name + ".json"), "w") as fh:
        json.dump(data, fh, separators=(",", ":"))
    report.append("%s objs=%d tris=%d verts=%d uvs=%d norms=%d size=%s" % (
        name, len(objs), len(T), len(pl), len(ul), len(nl),
        [round(mx[k] - mn[k], 2) for k in range(3)]))

print("\n".join(report))
