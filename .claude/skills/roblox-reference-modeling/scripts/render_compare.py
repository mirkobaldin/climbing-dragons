"""Stage `silhouette_compare`: flat Workbench silhouette renders through the
reference cameras, compared with reference masks (IoU / precision / recall,
bbox in meters, worst regions mapped to the nearest landmark).

  python run_stage.py run render_compare --manifest P -- [--views side,top] [--scale 0.5]
         [--grid 8] [--shaded] [--note "after tail fix"]

Only views with a CAM_REF_<view> camera and a usable mask are compared:
orthographic views, or perspective views with a calibrated camera.
Reference mask: view.mask image (white = creature), else view.mask_from_image
{"mode": "dark_on_light"|"light_on_dark"|"alpha", "threshold": 0.5}.
Writes renders/iter_NNN/<view>_sil.png, <view>_diff.png (red = model only,
blue = reference only), reports/silhouette_iter_NNN.json; appends to the stage
history and returns continue_refinement / stop reason using manifest.limits.

The comparison measures outline agreement only. It says nothing about hidden
anatomy, depth, or texture, and a high IoU does not guarantee fidelity.

STATUS: implemented, untested.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402

STAGE = "silhouette_compare"


def _load_rgba(path):
    import bpy
    import numpy as np
    img = bpy.data.images.load(str(path), check_existing=False)
    try:
        w, h = img.size
        px = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        return px.reshape(h, w, 4), w, h
    finally:
        bpy.data.images.remove(img)


def _save_rgba(arr, path):
    import bpy
    h, w = arr.shape[:2]
    img = bpy.data.images.new("__rbx_tmp_diff", w, h, alpha=True)
    try:
        img.pixels.foreach_set(arr.astype("float32").ravel())
        img.filepath_raw = str(path)
        img.file_format = "PNG"
        img.save()
    finally:
        bpy.data.images.remove(img)


def reference_mask(mpath, view):
    import numpy as np
    if view.get("mask"):
        rgba, w, h = _load_rgba(pc.to_abs(mpath, view["mask"]))
        lum = rgba[..., :3].mean(axis=2)
        return lum > 0.5
    spec = view.get("mask_from_image")
    if not spec:
        return None
    rgba, w, h = _load_rgba(pc.to_abs(mpath, view["image"]))
    thr = float(spec.get("threshold", 0.5))
    mode = spec.get("mode", "dark_on_light")
    if mode == "alpha":
        return rgba[..., 3] > thr
    lum = rgba[..., 0] * 0.2126 + rgba[..., 1] * 0.7152 + rgba[..., 2] * 0.0722
    return lum < thr if mode == "dark_on_light" else lum > thr


def _resize_nearest(mask, w, h):
    import numpy as np
    H, W = mask.shape
    ys = np.minimum((np.arange(h) * H / h).astype(int), H - 1)
    xs = np.minimum((np.arange(w) * W / w).astype(int), W - 1)
    return mask[ys][:, xs]


def _bbox(mask):
    import numpy as np
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


class _RenderState:
    """Snapshot/restore of every scene setting touched by the render."""

    def __init__(self, scene, objects):
        r, s = scene.render, scene.display.shading
        self.scene, self.objects = scene, objects
        self.vals = (scene.camera, r.engine, r.resolution_x, r.resolution_y, r.resolution_percentage,
                     r.film_transparent, r.filepath, r.image_settings.file_format, r.image_settings.color_mode,
                     s.light, s.color_type, tuple(s.single_color))
        self.hidden = {o.name: o.hide_render for o in objects}

    def restore(self):
        r, s = self.scene.render, self.scene.display.shading
        (self.scene.camera, r.engine, r.resolution_x, r.resolution_y, r.resolution_percentage,
         r.film_transparent, r.filepath, r.image_settings.file_format, r.image_settings.color_mode,
         s.light, s.color_type, sc) = self.vals
        s.single_color = sc
        import bpy
        for name, hr in self.hidden.items():
            o = bpy.data.objects.get(name)
            if o is not None:
                o.hide_render = hr


def run(params: dict) -> dict:
    import bpy
    import numpy as np
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Vector

    pc.require_blender()
    mpath, data = pc.load_manifest(params["manifest"])
    pc.ensure_working_blend(mpath, data, adopt_current=bool(params.get("adopt_current")))
    pc.ensure_object_mode()
    ann = pc.load_json(pc.to_abs(mpath, data["paths"]["reference_annotations"]), "Reference annotations")
    comp_names = {c["name"] for c in data.get("components", [])}
    if not comp_names:
        raise pc.PipelineError("No components in manifest; run build_dragon first.")
    scale = float(params.get("scale") or 0.5)
    grid = int(params.get("grid") or 8)
    wanted = set(pc.csv_list(params.get("views")))
    hist_entry = data["stages"].setdefault(STAGE, {"status": "pending"})
    history = hist_entry.setdefault("history", [])
    iteration = len(history) + 1
    out_dir = pc.project_root(mpath) / "renders" / f"iter_{iteration:03d}"
    out_dir.mkdir(parents=True, exist_ok=True)
    log = pc.StageLog(mpath, STAGE)
    scene = bpy.context.scene
    state = _RenderState(scene, list(bpy.data.objects))
    lms = {k: Vector(v["co"]) for k, v in data.get("landmarks", {}).items()}
    per_view, skipped = {}, []
    try:
        for o in bpy.data.objects:
            o.hide_render = o.name not in comp_names
        sh = scene.display.shading
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.render.film_transparent = True
        scene.render.image_settings.file_format = "PNG"
        scene.render.image_settings.color_mode = "RGBA"
        scene.render.resolution_percentage = 100
        for ref in data.get("references", []):
            name = ref["view"]
            if wanted and name not in wanted:
                continue
            cam = bpy.data.objects.get(f"CAM_REF_{name}")
            view = ann["views"].get(name, {})
            if cam is None or "silhouette" not in ref.get("usable_for", []):
                skipped.append(f"{name}: no compatible camera")
                continue
            ref_mask = reference_mask(mpath, view)
            if ref_mask is None:
                skipped.append(f"{name}: no mask / mask_from_image")
                continue
            W, H = cam["rbx_res"]
            w, h = max(8, round(W * scale)), max(8, round(H * scale))
            scene.camera = cam
            scene.render.resolution_x, scene.render.resolution_y = w, h
            sh.light, sh.color_type, sh.single_color = "FLAT", "SINGLE", (0.0, 0.0, 0.0)
            sil_path = out_dir / f"{name}_sil.png"
            scene.render.filepath = str(sil_path)
            bpy.ops.render.render(write_still=True)
            if params.get("shaded"):
                sh.light, sh.color_type = "STUDIO", "MATERIAL"
                scene.render.filepath = str(out_dir / f"{name}_shaded.png")
                bpy.ops.render.render(write_still=True)
            rgba, rw, rh = _load_rgba(sil_path)
            model = rgba[..., 3] > 0.5
            refm = _resize_nearest(ref_mask, rw, rh)
            inter = np.logical_and(model, refm).sum()
            union = np.logical_or(model, refm).sum()
            iou = float(inter / union) if union else 0.0
            prec = float(inter / model.sum()) if model.sum() else 0.0
            rec = float(inter / refm.sum()) if refm.sum() else 0.0
            diff = np.zeros((rh, rw, 4), dtype=np.float32)
            diff[..., 3] = 1.0
            diff[np.logical_and(model, refm)] = (0.5, 0.5, 0.5, 1.0)
            diff[np.logical_and(model, ~refm)] = (1.0, 0.1, 0.1, 1.0)
            diff[np.logical_and(~model, refm)] = (0.1, 0.3, 1.0, 1.0)
            _save_rgba(diff, out_dir / f"{name}_diff.png")
            cells = []
            ch, cw = max(1, rh // grid), max(1, rw // grid)
            for gy in range(grid):
                for gx in range(grid):
                    m = model[gy * ch:(gy + 1) * ch, gx * cw:(gx + 1) * cw]
                    r = refm[gy * ch:(gy + 1) * ch, gx * cw:(gx + 1) * cw]
                    excess, deficit = int((m & ~r).sum()), int((~m & r).sum())
                    if excess + deficit:
                        cells.append((excess + deficit, excess, deficit, (gx + 0.5) * cw, (gy + 0.5) * ch))
            cells.sort(reverse=True)
            lm_px = {}
            for lname, co in lms.items():
                p = world_to_camera_view(scene, cam, co)
                if 0 <= p.x <= 1 and 0 <= p.y <= 1 and p.z > 0:
                    lm_px[lname] = (p.x * rw, p.y * rh)
            regions = []
            for tot, ex, de, cx, cy in cells[:3]:
                near = min(lm_px, key=lambda k: (lm_px[k][0] - cx) ** 2 + (lm_px[k][1] - cy) ** 2) if lm_px else None
                regions.append({"near_landmark": near, "kind": "model_excess" if ex > de else "model_deficit",
                                "pixels": tot, "share": round(tot / max(1, union), 4)})
            bb_m, bb_r = _bbox(model), _bbox(refm)
            ppm = ref.get("px_per_m")
            bbox = None
            if bb_m and bb_r and ppm and ref["projection_assessed"] == "orthographic":
                k = 1.0 / (ppm * rw / W)
                bbox = {"model_wh_m": [round((bb_m[2] - bb_m[0]) * k, 3), round((bb_m[3] - bb_m[1]) * k, 3)],
                        "ref_wh_m": [round((bb_r[2] - bb_r[0]) * k, 3), round((bb_r[3] - bb_r[1]) * k, 3)]}
            per_view[name] = {"iou": round(iou, 4), "precision": round(prec, 4), "recall": round(rec, 4),
                              "bbox": bbox, "worst_regions": regions}
    finally:
        state.restore()

    if not per_view:
        pc.set_stage(data, STAGE, "failed", {"skipped": skipped})
        pc.save_manifest(mpath, data)
        raise pc.PipelineError(f"No view could be compared: {skipped}")
    mean_iou = round(sum(v["iou"] for v in per_view.values()) / len(per_view), 4)
    prev = history[-1]["mean_iou"] if history else None
    history.append({"iteration": iteration, "mean_iou": mean_iou, "at": pc.now_iso(), "note": params.get("note"),
                    "per_view": {k: v["iou"] for k, v in per_view.items()}})
    lim = data.get("limits", {})
    min_imp, patience = float(lim.get("min_iou_improvement", 0.005)), int(lim.get("stall_patience", 2))
    max_it = int(lim.get("max_refinement_iterations", 6))
    gains = [b["mean_iou"] - a["mean_iou"] for a, b in zip(history, history[1:])]
    stalled = len(gains) >= patience and all(g < min_imp for g in gains[-patience:])
    reason = None
    if iteration >= max_it:
        reason = f"iteration limit {max_it} reached"
    elif stalled:
        reason = f"improvement < {min_imp} for {patience} iterations"
    report = {"iteration": iteration, "mean_iou": mean_iou, "per_view": per_view, "skipped": skipped,
              "scale": scale}
    rpath = pc.write_json(pc.project_root(mpath) / "reports" / f"silhouette_iter_{iteration:03d}.json", report)
    pc.set_stage(data, STAGE, "done", {"iteration": iteration, "mean_iou": mean_iou}, pc.to_rel(mpath, log.path))
    pc.save_manifest(mpath, data)
    log.close()
    return {"stage": STAGE, "iteration": iteration, "mean_iou": mean_iou,
            "delta_vs_previous": None if prev is None else round(mean_iou - prev, 4),
            "per_view": {k: {"iou": v["iou"], "precision": v["precision"], "recall": v["recall"],
                             "worst": v["worst_regions"][:2]} for k, v in per_view.items()},
            "skipped": skipped, "continue_refinement": reason is None, "stop_reason": reason,
            "renders": pc.to_rel(mpath, out_dir), "report": pc.to_rel(mpath, rpath)}


def main() -> None:
    p = pc.base_parser(__doc__)
    p.add_argument("--views", help="Comma-separated subset of views")
    p.add_argument("--scale", type=float, default=0.5, help="Render scale vs reference resolution")
    p.add_argument("--grid", type=int, default=8)
    p.add_argument("--shaded", action="store_true", help="Also save a shaded review render per view")
    p.add_argument("--note", help="Free text stored in the iteration history")
    pc.cli_entry(run, p)


if __name__ == "__main__":
    main()
