"""Stage `reference_setup`: reference image planes, matching cameras, landmark empties.

Requires `reference_inspection` to have run (uses manifest.references/landmarks).

  python run_stage.py run setup_references --manifest P -- [--depth 3.0] [--overwrite-landmarks]

Creates/updates (by stable name, never duplicated):
  collection REF_Images   : image empties  REF_<view>   (behind the model, alpha 0.5)
  collection REF_Cameras  : cameras        CAM_REF_<view> (ortho; or perspective if calibrated)
  collection REF_Landmarks: empties        LM_<name>   (custom prop rbx_written_co)
Landmark empties moved by hand since the last write are kept (manual correction)
unless --overwrite-landmarks. Scene units: metric, scale_length 1.0.

STATUS: implemented, untested.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402
import reference_math as rm  # noqa: E402

STAGE = "reference_setup"


def _basis(view):
    from mathutils import Matrix, Vector
    (ui, us), (vi, vs) = rm.view_basis(view)
    u = Vector((0, 0, 0))
    u[ui] = us
    v = Vector((0, 0, 0))
    v[vi] = vs
    n = u.cross(v)
    return u, v, n, Matrix((u, v, n)).transposed()


def _get_or_new(name, data, col):
    import bpy
    obj = bpy.data.objects.get(name)
    if obj is None:
        obj = bpy.data.objects.new(name, data)
        obj.name = name
    elif data is not None and obj.data is not data:
        obj.data = data
    pc.link_only_to(obj, col)
    return obj


def run(params: dict) -> dict:
    import bpy
    from mathutils import Vector

    pc.require_blender()
    mpath, data = pc.load_manifest(params["manifest"])
    pc.check_retry_budget(data, STAGE)
    if data["stages"].get("reference_inspection", {}).get("status") not in ("done", "approved"):
        raise pc.PipelineError("Run inspect_references.py first (stage reference_inspection is not done).")
    pc.ensure_working_blend(mpath, data, adopt_current=bool(params.get("adopt_current")))
    pc.ensure_object_mode()
    ann = pc.load_json(pc.to_abs(mpath, data["paths"]["reference_annotations"]), "Reference annotations")
    log = pc.StageLog(mpath, STAGE)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0

    col_img = pc.ensure_collection("REF_Images")
    col_cam = pc.ensure_collection("REF_Cameras")
    col_lm = pc.ensure_collection("REF_Landmarks")
    col_img.hide_render = True
    col_lm.hide_render = True
    depth = float(params.get("depth") or 3.0)
    views_done, skipped = [], []

    for ref in data.get("references", []):
        name = ref["view"]
        view = ann["views"].get(name)
        if view is None:
            skipped.append(f"{name}: not in annotations")
            continue
        img_path = pc.to_abs(mpath, ref["image"])
        img = bpy.data.images.load(str(img_path), check_existing=True)
        w, h = img.size
        if w == 0 or h == 0:
            skipped.append(f"{name}: image could not be read")
            continue
        if "triangulation" in ref["usable_for"]:
            u, v, n, rot = _basis(view)
            ppm = rm.px_per_m(view)
            size = max(w, h) / ppm
            center_axes = rm.pixel_to_world(view, (w / 2.0, h / 2.0))
            center = Vector((0, 0, 0))
            for axis, val in center_axes.items():
                center[axis] = val
            emp = _get_or_new(f"REF_{name}", None, col_img)
            emp.empty_display_type = "IMAGE"
            emp.data = img
            emp.empty_display_size = size
            emp.empty_image_offset = (-0.5, -0.5)
            emp.use_empty_image_alpha = True
            emp.color[3] = 0.5
            emp.empty_image_side = "FRONT"
            emp.matrix_world = rot.to_4x4()
            emp.location = center - n * depth
            cam_data = bpy.data.cameras.get(f"CAM_REF_{name}") or bpy.data.cameras.new(f"CAM_REF_{name}")
            cam_data.name = f"CAM_REF_{name}"
            cam_data.type = "ORTHO"
            cam_data.ortho_scale = size
            cam_data.clip_start = 0.01
            cam_data.clip_end = depth * 4 + size * 2
            cam = _get_or_new(f"CAM_REF_{name}", cam_data, col_cam)
            cam.matrix_world = rot.to_4x4()
            cam.location = center + n * (depth * 2)
            cam["rbx_res"] = [w, h]
            cam["rbx_view"] = name
            cam["rbx_projection"] = "orthographic"
            views_done.append(name)
        elif view.get("camera") and "silhouette" in ref["usable_for"]:
            c = view["camera"]
            cam_data = bpy.data.cameras.get(f"CAM_REF_{name}") or bpy.data.cameras.new(f"CAM_REF_{name}")
            cam_data.name = f"CAM_REF_{name}"
            cam_data.type = "PERSP"
            cam_data.lens = float(c["lens_mm"])
            cam_data.sensor_fit = "HORIZONTAL"
            cam_data.sensor_width = float(c.get("sensor_width_mm", 36.0))
            cam = _get_or_new(f"CAM_REF_{name}", cam_data, col_cam)
            cam.location = c["location"]
            cam.rotation_mode = "XYZ"
            cam.rotation_euler = [math.radians(a) for a in c["rotation_euler_deg"]]
            cam_data.show_background_images = True
            bg = cam_data.background_images[0] if len(cam_data.background_images) else cam_data.background_images.new()
            bg.image = img
            bg.alpha = 0.5
            cam["rbx_res"] = [w, h]
            cam["rbx_view"] = name
            cam["rbx_projection"] = "perspective"
            views_done.append(name)
        else:
            skipped.append(f"{name}: visual-only reference (no orthographic calibration or camera)")

    lm_written, lm_kept, lm_incomplete = 0, [], []
    for lname, lmd in data.get("landmarks", {}).items():
        obj = _get_or_new(f"LM_{lname}", None, col_lm)
        obj.empty_display_type = "SPHERE"
        obj.empty_display_size = 0.03
        cur = list(obj.location)
        written = obj.get("rbx_written_co")
        moved = written is not None and max(abs(a - b) for a, b in zip(cur, written)) > 1e-5
        if moved and not params.get("overwrite_landmarks"):
            lm_kept.append(lname)
            continue
        obj.location = lmd["co"]
        obj["rbx_written_co"] = list(lmd["co"])
        obj["rbx_complete"] = bool(lmd.get("complete", True))
        if not lmd.get("complete", True):
            lm_incomplete.append(lname)
        lm_written += 1

    defects = [("info", f"reference skipped: {s}", []) for s in skipped]
    if lm_incomplete:
        defects.append(("warning", "landmarks with an unknown axis were placed at 0 on that axis; "
                                   "annotate them in a second view or fix in config", lm_incomplete[:20]))
    pc.sync_stage_defects(data, STAGE, defects)
    summary = {"views": views_done, "skipped": len(skipped), "landmarks_written": lm_written,
               "landmarks_kept_manual": len(lm_kept), "landmarks_incomplete": len(lm_incomplete)}
    log.dump("details", {"skipped": skipped, "kept": lm_kept, "incomplete": lm_incomplete})
    pc.set_stage(data, STAGE, "done", summary, pc.to_rel(mpath, log.path))
    saved = pc.save_working(mpath, data, params.get("save"))
    pc.save_manifest(mpath, data)
    log.close()
    return {"stage": STAGE, **summary, "saved_blend": saved}


def main() -> None:
    p = pc.base_parser(__doc__)
    p.add_argument("--depth", type=float, default=3.0, help="Distance of image planes behind the origin (m)")
    p.add_argument("--overwrite-landmarks", action="store_true")
    pc.cli_entry(run, p)


if __name__ == "__main__":
    main()
