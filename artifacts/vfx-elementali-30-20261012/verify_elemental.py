"""Verifica round-trip FBX, UV, volume e texture delle trenta mesh."""
import bpy, bmesh, json, math
from pathlib import Path
root=Path(__file__).resolve().parent
records=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
report=[]
for record in records:
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.fbx(filepath=str(root/record['file']))
    objs=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert len(objs)==1,record['name']
    obj=objs[0]; bpy.context.view_layer.update(); mesh=obj.data
    mesh.calc_loop_triangles()
    assert obj.name==record['name']
    assert len(mesh.loop_triangles)==record['triangles']
    assert all(abs(a-b)<.002 for a,b in zip(obj.dimensions,record['dimensions']))
    assert all(abs(v)<.0001 for v in obj.location)
    assert mesh.uv_layers.active
    assert all(math.isfinite(v) and 0<=v<=1 for p in mesh.uv_layers.active.data for v in p.uv)
    assert all(p.area>1e-11 for p in mesh.polygons)
    images=[n.image for mat in mesh.materials if mat and mat.use_nodes for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
    assert images and any(tuple(image.size)==(128,256) for image in images),(record['name'],'Texture mancante')
    # FBX duplica vertici lungo le UV; si ricuce solo nella copia di verifica.
    bm=bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
    boundary=sum(e.is_boundary for e in bm.edges)
    bm.free()
    assert boundary==0,(record['name'],boundary)
    report.append(dict(name=obj.name,triangles=record['triangles'],uv=True,texture=True,boundary_edges=boundary,ok=True))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(root/'VFX_Elementali_30.fbx'))
objs=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert {o.name for o in objs}=={r['name'] for r in records}
assert len(bpy.context.scene.objects)==30
(root/'validation.json').write_text(json.dumps(dict(ok=True,blender=bpy.app.version_string,
    single_fbx=report,kit_meshes=30,max_triangles=max(r['triangles'] for r in records),
    studio_tested=False),indent=2),encoding='utf-8')
print('[VFX] 30 export verificati: nomi, geometria, UV, texture e pivot.')
