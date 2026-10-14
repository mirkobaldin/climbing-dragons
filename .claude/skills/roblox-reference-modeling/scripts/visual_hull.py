"""Optional stage `visual_hull`: voxel carving from calibrated, consistent silhouettes.

  python run_stage.py run visual_hull --manifest P -- [--views side,top,front]
         [--resolution 96] [--allowed-misses 0] [--pad 0.1] [--remesh]

Each voxel centre is projected through every CAM_REF_<view> camera
(Object.calc_matrix_camera + matrix_world) and kept only if it falls inside the
reference mask in all views (minus --allowed-misses). The result is the
*visual hull*: the largest shape consistent with the silhouettes.

Fundamental limits (also in references/visual-hull.md):
  * hidden concavities (rib cage interior, gaps between ribs, the space between
    wing membrane and body seen edge-on) cannot be recovered;
  * inconsistent poses/proportions between views carve away real anatomy;
  * output is blocky boundary-voxel geometry - an INITIALISATION / proportion
    guide only, never final anatomy. It is placed in collection INIT as
    INIT_VisualHull (wire display), and is not added to manifest.components.
The script never fills openings of the procedural model.

STATUS: implemented, untested.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402

STAGE = "visual_hull"
MAX_VOXELS = 4_000_000


def boundary_mesh(occ, origin, vs):
    import numpy as np
    nx, ny, nz = occ.shape
    pad = np.pad(occ, 1)
    quads = []
    # (axis, sign, corner offsets in (i,j,k) for a face of voxel (i,j,k)), outward winding
    specs = [
        (0, 1, [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]),
        (0, -1, [(0, 0, 1), (0, 1, 1), (0, 1, 0), (0, 0, 0)]),
        (1, 1, [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]),
        (1, -1, [(1, 0, 0), (1, 0, 1), (0, 0, 1), (0, 0, 0)]),
        (2, 1, [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]),
        (2, -1, [(0, 1, 0), (1, 1, 0), (1, 0, 0), (0, 0, 0)]),
    ]
    for axis, sign, corners in specs:
        sl = [slice(1, -1)] * 3
        sl[axis] = slice(1 + sign, pad.shape[axis] - 1 + sign)
        neighbour = pad[tuple(sl)]
        idx = np.argwhere(occ & ~neighbour)
        if len(idx) == 0:
            continue
        q = np.stack([(idx + np.array(c)) for c in corners], axis=1)  # (n, 4, 3)
        quads.append(q)
    if not quads:
        return [], []
    q = np.concatenate(quads)
    flat = q.reshape(-1, 3)
    keys = (flat[:, 0] * (ny + 1) + flat[:, 1]) * (nz + 1) + flat[:, 2]
    uniq, inv = np.unique(keys, return_inverse=True)
    k = uniq % (nz + 1)
    j = (uniq // (nz + 1)) % (ny + 1)
    i = uniq // ((nz + 1) * (ny + 1))
    verts = np.stack([i, j, k], axis=1) * vs + np.asarray(origin)
    faces = inv.reshape(-1, 4)
    return verts.tolist(), faces.tolist()


def run(params: dict) -> dict:
    import bpy
    import numpy as np
    import render_compare as rc

    pc.require_blender()
    mpath, data = pc.load_manifest(params["manifest"])
    pc.ensure_working_blend(mpath, data, adopt_current=bool(params.get("adopt_current")))
    pc.ensure_object_mode()
    ann = pc.load_json(pc.to_abs(mpath, data["paths"]["reference_annotations"]), "Reference annotations")
    wanted = set(pc.csv_list(params.get("views")))
    cams = []
    for ref in data.get("references", []):
        if "visual_hull" not in ref.get("usable_for", []) or (wanted and ref["view"] not in wanted):
            continue
        cam = bpy.data.objects.get(f"CAM_REF_{ref['view']}")
        mask = rc.reference_mask(mpath, ann["views"][ref["view"]]) if cam else None
        if cam is not None and mask is not None:
            cams.append((ref["view"], cam, mask))
    if len(cams) < 2:
        raise pc.PipelineError("Visual hull needs >= 2 calibrated views with masks "
                               "(orthographic or calibrated perspective). Run reference_setup first.")
    lms = [v["co"] for v in data.get("landmarks", {}).values() if v.get("complete", True)]
    if len(lms) < 2:
        raise pc.PipelineError("Need landmarks to bound the voxel grid.")
    lo = np.min(np.array(lms), axis=0)
    hi = np.max(np.array(lms), axis=0)
    pad = float(params.get("pad") or 0.1) * float(np.max(hi - lo))
    lo, hi = lo - pad, hi + pad
    res = int(params.get("resolution") or 96)
    vs = float(np.max(hi - lo)) / res
    dims = np.maximum(1, np.ceil((hi - lo) / vs)).astype(int)
    while int(np.prod(dims)) > MAX_VOXELS:
        vs *= 1.25
        dims = np.maximum(1, np.ceil((hi - lo) / vs)).astype(int)
    log = pc.StageLog(mpath, STAGE)
    gi, gj, gk = np.meshgrid(*[np.arange(d) for d in dims], indexing="ij")
    centres = np.stack([gi, gj, gk], axis=-1).reshape(-1, 3) * vs + lo + vs / 2
    hom = np.concatenate([centres, np.ones((len(centres), 1))], axis=1)
    votes = np.zeros(len(centres), dtype=np.int16)
    dg = bpy.context.evaluated_depsgraph_get()
    for name, cam, mask in cams:
        W, H = cam["rbx_res"]
        mask = rc._resize_nearest(mask, int(W), int(H))
        P = np.array(cam.calc_matrix_camera(dg, x=int(W), y=int(H)))
        V = np.array(cam.matrix_world.inverted())
        clip = hom @ (P @ V).T
        w = clip[:, 3]
        ok = w > 1e-9
        ndc = np.zeros((len(clip), 2))
        ndc[ok] = clip[ok, :2] / w[ok, None]
        ix = np.floor((ndc[:, 0] + 1) / 2 * W).astype(int)
        iy = np.floor((ndc[:, 1] + 1) / 2 * H).astype(int)
        inside = ok & (ix >= 0) & (ix < W) & (iy >= 0) & (iy < H)
        hit = np.zeros(len(clip), dtype=bool)
        hit[inside] = mask[iy[inside], ix[inside]]
        votes += hit
        log.write(name, "inside-mask voxels", int(hit.sum()))
    need = len(cams) - int(params.get("allowed_misses") or 0)
    occ = (votes >= need).reshape(tuple(dims))
    verts, faces = boundary_mesh(occ, lo, vs)
    if not faces:
        raise pc.PipelineError("Carving removed every voxel - views or masks are inconsistent "
                               "(check reference_inspection registration fits).")
    col = pc.ensure_collection("INIT")
    mesh = bpy.data.meshes.new("INIT_VisualHull__new")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = pc.upsert_mesh_object("INIT_VisualHull", mesh, col)
    obj.display_type = "WIRE"
    obj.hide_render = True
    obj["rbx_init"] = "visual_hull"
    if params.get("remesh"):
        mod = obj.modifiers.get("RBX_Remesh") or obj.modifiers.new("RBX_Remesh", "REMESH")
        mod.name = "RBX_Remesh"
        mod.mode = "VOXEL"
        mod.voxel_size = vs * 1.5
    summary = {"views": [c[0] for c in cams], "voxel_size_m": round(vs, 4), "grid": dims.tolist(),
               "occupied_voxels": int(occ.sum()), "volume_m3": round(float(occ.sum()) * vs ** 3, 4),
               "faces": len(faces)}
    pc.set_stage(data, STAGE, "done", summary, pc.to_rel(mpath, log.path))
    data.setdefault("verifications", [])
    saved = pc.save_working(mpath, data, params.get("save"))
    pc.save_manifest(mpath, data)
    log.close()
    return {"stage": STAGE, **summary, "object": "INIT_VisualHull", "saved_blend": saved,
            "note": "Initialisation only: concavities and gaps are not recoverable from silhouettes."}


def main() -> None:
    p = pc.base_parser(__doc__)
    p.add_argument("--views")
    p.add_argument("--resolution", type=int, default=96, help="Voxels along the longest bbox axis")
    p.add_argument("--allowed-misses", type=int, default=0)
    p.add_argument("--pad", type=float, default=0.1)
    p.add_argument("--remesh", action="store_true", help="Add a non-applied voxel Remesh modifier")
    pc.cli_entry(run, p)


if __name__ == "__main__":
    main()
