"""Import an initialisation mesh (image-to-3D output or any OBJ/GLB/PLY) as a guide.

  python run_stage.py run import_init_mesh --manifest P -- [--file PATH | --source image_to_3d]
         [--rotate-deg 90,0,0] [--no-fit] [--as-model [--scale-m 190]]

The mesh replaces INIT_ImageTo3D in collection INIT (wire display, hidden from
render) and is fitted to the landmark bounding box (uniform scale + centre)
unless --no-fit. Backends use different axis conventions: check the result in
a front view and pass --rotate-deg if needed. Never added to manifest.components:
use it to place landmarks or judge proportions.
--as-model: the generated mesh IS the model (image-to-3D is the mandatory path):
it is imported as GEN_ImageTo3D in collection GEN with its materials/textures,
visible and renderable, optionally scaled so its longest side is --scale-m metres
and set on the ground (origin at the base centre). Never fills or deletes geometry.

STATUS: implemented; tested on a stub GLB in Blender 5.2.2 (2026-10-14), not yet on a
real Stable Fast 3D output.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402

NAME = "INIT_ImageTo3D"
MODEL_NAME = "GEN_ImageTo3D"


def run(params: dict) -> dict:
    import bpy
    from mathutils import Euler, Vector

    pc.require_blender()
    mpath, data = pc.load_manifest(params["manifest"])
    pc.ensure_working_blend(mpath, data, adopt_current=bool(params.get("adopt_current")))
    pc.ensure_object_mode()
    if params.get("file"):
        path = pc.to_abs(mpath, params["file"])
    else:
        mesh_rel = data["stages"].get("image_to_3d", {}).get("summary", {}).get("mesh")
        if not mesh_rel:
            raise pc.PipelineError("No --file and no image_to_3d result in the manifest.")
        path = pc.to_abs(mpath, mesh_rel)
    if not path.is_file():
        raise pc.PipelineError(f"Mesh file not found: {path}")
    as_model = bool(params.get("as_model"))
    name = MODEL_NAME if as_model else NAME
    old = bpy.data.objects.get(name)
    if old is not None:
        me = old.data
        bpy.data.objects.remove(old)
        if me is not None and me.users == 0:
            bpy.data.meshes.remove(me)
    before = set(bpy.data.objects)
    ext = path.suffix.lower()
    if ext == ".obj":
        bpy.ops.wm.obj_import(filepath=str(path))
    elif ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=str(path))
    elif ext == ".ply":
        bpy.ops.wm.ply_import(filepath=str(path))
    elif ext == ".stl":
        bpy.ops.wm.stl_import(filepath=str(path))
    else:
        raise pc.PipelineError(f"Unsupported mesh format {ext}; use OBJ, GLB/GLTF, PLY or STL")
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    if not meshes:
        raise pc.PipelineError("Import produced no mesh object")
    obj = max(meshes, key=lambda o: len(o.data.vertices))
    for o in new:
        if o is not obj:
            bpy.data.objects.remove(o)
    obj.name = name
    obj.data.name = name
    obj.parent = None
    col = pc.ensure_collection("GEN" if as_model else "INIT")
    pc.link_only_to(obj, col)
    rot = [math.radians(float(x)) for x in pc.csv_list(params.get("rotate_deg") or "0,0,0")]
    obj.rotation_mode = "XYZ"
    obj.rotation_euler = Euler(rot)
    bpy.context.view_layer.update()
    fit = None
    lms = [Vector(v["co"]) for v in data.get("landmarks", {}).values() if v.get("complete", True)]
    if as_model and params.get("scale_m"):
        corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
        size = max(max(c[i] for c in corners) - min(c[i] for c in corners) for i in range(3))
        s = float(params["scale_m"]) / max(size, 1e-9)
        obj.scale = obj.scale * s
        bpy.context.view_layer.update()
        corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
        lo = Vector([min(c[i] for c in corners) for i in range(3)])
        hi = Vector([max(c[i] for c in corners) for i in range(3)])
        obj.location = obj.location - Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
        fit = {"scale": round(s, 4), "longest_side_m": float(params["scale_m"])}
    elif not params.get("no_fit") and len(lms) >= 2:
        corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
        mlo = Vector([min(c[i] for c in corners) for i in range(3)])
        mhi = Vector([max(c[i] for c in corners) for i in range(3)])
        llo = Vector([min(v[i] for v in lms) for i in range(3)])
        lhi = Vector([max(v[i] for v in lms) for i in range(3)])
        s = max(lhi - llo) / max(max(mhi - mlo), 1e-9)
        obj.scale = obj.scale * s
        bpy.context.view_layer.update()
        corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
        mc = sum(corners, Vector()) / 8.0
        obj.location = obj.location + ((llo + lhi) / 2.0 - mc)
        fit = {"scale": round(s, 4)}
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    mats = [m.name for m in obj.data.materials if m]
    images = sorted({n.image.name for m in obj.data.materials if m and m.node_tree
                     for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image})
    if as_model:
        obj.display_type = "TEXTURED"
        obj.hide_render = False
        obj["rbx_init"] = "image_to_3d_model"
        note = "Generated model (image-to-3D). Unseen sides are guessed by the backend; check before handoff."
    else:
        obj.display_type = "WIRE"
        obj.hide_render = True
        obj["rbx_init"] = "image_to_3d"
        note = "Guide only; not anatomy. Hidden/occluded structure is guessed by the backend."
    saved = pc.save_working(mpath, data, params.get("save"))
    return {"object": name, "verts": len(obj.data.vertices), "tris": tris, "materials": mats, "images": images,
            "fit": fit, "saved_blend": saved, "note": note}


def main() -> None:
    p = pc.base_parser(__doc__)
    p.add_argument("--file")
    p.add_argument("--source", choices=("image_to_3d",), default="image_to_3d")
    p.add_argument("--rotate-deg", help="x,y,z degrees applied before fitting")
    p.add_argument("--no-fit", action="store_true")
    p.add_argument("--as-model", action="store_true", help="import as the model (visible, textured), not as a wire guide")
    p.add_argument("--scale-m", type=float, help="with --as-model: longest side in metres, base on the ground")
    pc.cli_entry(run, p)


if __name__ == "__main__":
    main()
