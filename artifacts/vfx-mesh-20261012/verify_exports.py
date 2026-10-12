"""Reimporta gli FBX prodotti e confronta geometria, UV e dimensioni."""
import bpy
import json
import math
from pathlib import Path

root = Path(__file__).resolve().parent
records = json.loads((root / 'manifest.json').read_text(encoding='utf-8'))
report = []
for record in records:
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.fbx(filepath=str(root / record['file']))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    assert len(meshes) == 1, record['name']
    obj = meshes[0]
    bpy.context.view_layer.update()
    obj.data.calc_loop_triangles()
    triangles = len(obj.data.loop_triangles)
    uv = obj.data.uv_layers.active
    dimensions = list(obj.dimensions)
    ok = (obj.name == record['name'] and triangles == record['triangles']
          and uv is not None and len(uv.data) == len(obj.data.loops)
          and all(abs(a - b) < .002 for a, b in zip(dimensions, record['dimensions']))
          and all(abs(v) < .0001 for v in obj.location)
          and all(math.isfinite(c) for vertex in obj.data.vertices for c in vertex.co))
    assert ok, (record['name'], triangles, dimensions, record['dimensions'])
    report.append(dict(name=obj.name, ok=ok, triangles=triangles, uv=True, pivot_origin=True))

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(root / 'VFX_Kit_36.fbx'))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert len(meshes) == 36
assert {o.name for o in meshes} == {r['name'] for r in records}
assert all(o.type == 'MESH' for o in bpy.context.scene.objects)
for obj in meshes:
    obj.data.calc_loop_triangles()
    expected = next(r for r in records if r['name'] == obj.name)
    assert len(obj.data.loop_triangles) == expected['triangles']
(root / 'validation.json').write_text(json.dumps(dict(
    blender=bpy.app.version_string, single_fbx=report, kit_meshes=len(meshes),
    total_triangles=sum(r['triangles'] for r in report),
    min_triangles=min(r['triangles'] for r in report),
    max_triangles=max(r['triangles'] for r in report),
    studio_tested=False, ok=True), indent=2), encoding='utf-8')
print('[VFX] Verificati 36 FBX singoli e kit: triangoli, UV, dimensioni, pivot e nomi.')
