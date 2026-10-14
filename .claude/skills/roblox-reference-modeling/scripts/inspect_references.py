"""Stage `reference_inspection` (stdlib only, no Blender needed).

Reads config/reference_annotations.json (see assets/reference_annotations.example.json),
then for every view: image size + EXIF, orthographic/perspective evidence, pixel scale;
for orthographic views: triangulated 3D landmarks, cross-view residuals,
registration fits (scale/offset error vs pose inconsistency), bilateral symmetry.

Usage:
  python inspect_references.py --manifest P [--annotations FILE] [--force]

Writes: reports/reference_inspection.json (full), manifest.references,
manifest.landmarks (source=reference_triangulation), stage status, defects.
Prints one @@RESULT@@ JSON line (schema in references/script-cli.md).

STATUS: implemented, untested.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402
import reference_math as rm  # noqa: E402

STAGE = "reference_inspection"


def run(params: dict) -> dict:
    mpath, data = pc.load_manifest(params["manifest"])
    pc.check_retry_budget(data, STAGE)
    ann_path = pc.to_abs(mpath, params.get("annotations") or data["paths"]["reference_annotations"])
    ann = pc.load_json(ann_path, "Reference annotations")
    views = ann.get("views") or {}
    if not views:
        raise pc.PipelineError(f"No views in {ann_path}. Add at least one view (see reference-analysis.md).")
    images = [pc.to_abs(mpath, v["image"]) for v in views.values() if v.get("image")]
    ihash = pc.fingerprint([ann_path, *images], {"v": 1})
    if pc.should_skip(data, STAGE, ihash, params.get("force", False)):
        return {"skipped": True, "reason": "inputs unchanged", "stage": STAGE}

    tol = {"axis_residual_m": 0.05, "axis_residual_ratio": 0.01, "parallel_deg": 2.0,
           "symmetry_ratio": 0.05, **ann.get("tolerances", {})}
    log = pc.StageLog(mpath, STAGE)
    defects: list[tuple[str, str, list[str]]] = []
    refs, per_view = [], {}
    for name, view in views.items():
        img = pc.to_abs(mpath, view.get("image", ""))
        if not img.is_file():
            defects.append(("error", f"view {name}: image missing {view.get('image')}", []))
            continue
        try:
            info = rm.image_info(img)
        except rm.ReferenceError_ as exc:
            defects.append(("error", f"view {name}: {exc}", []))
            continue
        evidence = rm.projection_evidence(view, info, float(tol["parallel_deg"]))
        ppm = None
        if rm.is_ortho(view):
            try:
                rm.view_basis(view)
                ppm = rm.px_per_m(view)
            except rm.ReferenceError_ as exc:
                defects.append(("error", f"view {name}: {exc}", []))
        usable = []
        if view.get("projection") == "orthographic" and ppm and not evidence["conflict"]:
            usable = ["triangulation", "silhouette", "visual_hull"]
        elif view.get("projection") == "perspective" and view.get("camera"):
            usable = ["silhouette", "visual_hull"]
        else:
            usable = ["visual_only"]
        if evidence["conflict"]:
            defects.append(("warning", f"view {name}: declared {evidence['declared']} but evidence suggests "
                                       f"{evidence['assessed']}; excluded from triangulation", []))
        refs.append({"view": name, "image": pc.to_rel(mpath, img),
                     "projection_declared": evidence["declared"],
                     "projection_assessed": evidence["assessed"], "usable_for": usable,
                     "px_per_m": round(ppm, 4) if ppm else None,
                     "size_px": [info["width"] or 0, info["height"] or 0],
                     "evidence": evidence["evidence"][:6]})
        per_view[name] = {"info": info, "evidence": evidence, "n_landmarks": len(view.get("landmarks", {}))}

    tri_views = {n: v for n, v in views.items()
                 if any(r["view"] == n and "triangulation" in r["usable_for"] for r in refs)}
    tri = rm.triangulate(tri_views, float(tol["axis_residual_m"]), float(tol["axis_residual_ratio"]))
    fits = rm.registration_fits(tri_views)
    bilat = rm.bilateral_checks(tri["landmarks"], ann.get("bilateral_segments", []), float(tol["symmetry_ratio"]))

    for f in fits:
        if abs(f["scale"] - 1.0) > 0.02 or abs(f["offset_m"]) > tol["axis_residual_m"]:
            defects.append(("warning", f"views {f['views']} axis {f['axis']}: registration scale {f['scale']} "
                                       f"offset {f['offset_m']} m - check scale bar / origin pixel", []))
        if f["rms_after_fit_m"] > tol["axis_residual_m"]:
            worst = ", ".join(w["landmark"] for w in f["worst"])
            defects.append(("warning", f"views {f['views']} axis {f['axis']}: residual {f['rms_after_fit_m']} m "
                                       f"after fit, worst at {worst} - likely pose/proportion mismatch", []))
    for b in bilat:
        defects.append(("info", f"L/R length mismatch {b['segment']} ratio {b['ratio']}", []))
    incomplete = sorted(k for k, v in tri["landmarks"].items() if not v["complete"])
    if incomplete:
        defects.append(("info", f"{len(incomplete)} landmarks seen in only one view (one axis unknown)",
                        incomplete[:20]))

    report = {"views": per_view, "references": refs, "triangulation": tri,
              "registration_fits": fits, "bilateral": bilat, "tolerances": tol}
    report_path = pc.write_json(pc.project_root(mpath) / "reports" / "reference_inspection.json", report)
    log.write("report", report_path)

    data["references"] = refs
    lm_store = data.setdefault("landmarks", {})
    for k, v in tri["landmarks"].items():
        if lm_store.get(k, {}).get("source") == "scene_edit":
            continue  # never overwrite manual corrections made in Blender
        lm_store[k] = {"co": v["co"], "source": "reference_triangulation",
                       "complete": v["complete"], "residual_m": v["residual_m"]}
    dsum = pc.sync_stage_defects(data, STAGE, defects)
    blocking = any(s in ("error", "blocker") for s, _, _ in defects)
    summary = {"views": len(views), "triangulation_views": list(tri_views),
               "landmarks_3d": len(tri["landmarks"]), "incomplete": len(incomplete),
               "axis_issues": len(tri["issues"]), "defects": dsum}
    pc.set_stage(data, STAGE, "failed" if blocking else "done", summary, pc.to_rel(mpath, log.path), ihash)
    pc.save_manifest(mpath, data)
    log.close()
    return {"ok": not blocking, "stage": STAGE, **summary,
            "per_view": {r["view"]: {"declared": r["projection_declared"], "assessed": r["projection_assessed"],
                                     "usable_for": r["usable_for"]} for r in refs},
            "top_axis_issues": tri["issues"][:5],
            "registration": [{k: f[k] for k in ("views", "axis", "scale", "offset_m", "rms_after_fit_m")}
                             for f in fits][:6],
            "report": pc.to_rel(mpath, report_path)}


def main() -> None:
    p = pc.base_parser(__doc__)
    p.add_argument("--annotations", help="Override path to reference annotations JSON")
    pc.cli_entry(run, p)


if __name__ == "__main__":
    main()
