"""Stage `weight_audit`: influence limits, weight sums, root/zero-influence bones,
and posed deformation tests.

  python run_stage.py run weight_audit --manifest P -- [--tests wing_fold_L,tail_curl] [--no-tests]

Static checks per skinned component: vertices with > 4 influences (Roblox limit),
unweighted vertices, weight sums != 1 (tol 1e-3), groups that are not deform
bones, weights on the root bone (dropped by Roblox), rigid components using more
than one bone. Rig-wide: deform bones with zero influence (removed by the Roblox
Importer unless "Keep Zero Influence Bones" is enabled).

Deformation tests (rig_config.deformation_tests): each test poses control bones,
evaluates meshes and compares with the rest evaluation:
  rigid components: max |edge length ratio - 1| (should be ~0 with rigid weights)
  membranes: min/max edge ratio, faces collapsing (area ratio < 0.2) or
  over-stretching (> 3.0). The pose is reset afterwards.

STATUS: implemented, untested.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402
import rig_common as rc  # noqa: E402

STAGE = "weight_audit"


def static_checks(obj, deform, root_def, rigid):
    import numpy as np
    names = {vg.index: vg.name for vg in obj.vertex_groups}
    counts, sums, bad_groups, root_w = [], [], set(), 0
    used = set()
    for v in obj.data.vertices:
        c, s = 0, 0.0
        for g in v.groups:
            if g.weight <= 0:
                continue
            nm = names.get(g.group, "?")
            if nm not in deform:
                bad_groups.add(nm)
                continue
            if nm == root_def:
                root_w += 1
            c += 1
            s += g.weight
            used.add(nm)
        counts.append(c)
        sums.append(s)
    counts, sums = np.array(counts), np.array(sums)
    res = {"verts": len(counts), "max_influences": int(counts.max()) if len(counts) else 0,
           "over_4": int((counts > 4).sum()), "unweighted": int((counts == 0).sum()),
           "bad_sums": int((np.abs(sums - 1.0) > 1e-3)[counts > 0].sum()),
           "non_deform_groups": sorted(bad_groups)[:10], "root_weighted_verts": root_w,
           "bones_used": sorted(used)}
    if rigid:
        res["rigid_multi_bone"] = len(used) > 1
    return res


def evaluated_geometry(objs, dg):
    import numpy as np
    out = {}
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        n = len(me.vertices)
        co = np.empty(n * 3)
        me.vertices.foreach_get("co", co)
        ed = np.empty(len(me.edges) * 2, dtype=np.int64)
        me.edges.foreach_get("vertices", ed)
        me.calc_loop_triangles()
        tri = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
        me.loop_triangles.foreach_get("vertices", tri)
        out[o.name] = (co.reshape(n, 3), ed.reshape(-1, 2), tri.reshape(-1, 3))
        ev.to_mesh_clear()
    return out


def compare(rest, posed, rigid):
    import numpy as np
    co0, ed, tri = rest
    co1 = posed[0]
    if co0.shape != co1.shape:
        return {"error": "topology changed under deformation"}
    l0 = np.linalg.norm(co0[ed[:, 0]] - co0[ed[:, 1]], axis=1)
    l1 = np.linalg.norm(co1[ed[:, 0]] - co1[ed[:, 1]], axis=1)
    ok = l0 > 1e-7
    ratio = l1[ok] / l0[ok]
    if rigid:
        return {"max_edge_deviation": round(float(np.abs(ratio - 1).max()) if len(ratio) else 0.0, 5)}

    def areas(c):
        return 0.5 * np.linalg.norm(np.cross(c[tri[:, 1]] - c[tri[:, 0]], c[tri[:, 2]] - c[tri[:, 0]]), axis=1)
    a0, a1 = areas(co0), areas(co1)
    aok = a0 > 1e-10
    ar = a1[aok] / a0[aok]
    return {"edge_ratio_min": round(float(ratio.min()), 3), "edge_ratio_max": round(float(ratio.max()), 3),
            "collapsed_faces": int((ar < 0.2).sum()), "overstretched_faces": int((ar > 3.0).sum()),
            "faces": int(aok.sum())}


def apply_pose(rig, pose):
    touched = []
    for pattern, spec in pose.items():
        for pat, side in rc.expand_side(pattern):
            for name in rc.match_bones(rig.pose.bones.keys(), pat):
                pb = rig.pose.bones[name]
                if "rot" in spec:
                    vals = [rc.mirror_value(ch, v, side) for ch, v in zip(("rot_x", "rot_y", "rot_z"), spec["rot"])]
                    pb.rotation_euler = [math.radians(v) for v in vals]
                if "loc" in spec:
                    pb.location = [rc.mirror_value(ch, v, side) for ch, v in zip(("loc_x", "loc_y", "loc_z"), spec["loc"])]
                touched.append(name)
    return touched


def reset_pose(rig, names):
    for n in names:
        pb = rig.pose.bones[n]
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)


def run(params: dict) -> dict:
    import bpy
    pc.require_blender()
    mpath, data = pc.load_manifest(params["manifest"])
    if data["stages"].get("skinning", {}).get("status") not in ("done", "approved"):
        raise pc.PipelineError("Run skin_weights.py first.")
    pc.ensure_working_blend(mpath, data, adopt_current=bool(params.get("adopt_current")))
    pc.ensure_object_mode()
    rig = rc.get_rig(data)
    cfg = pc.load_json(pc.to_abs(mpath, data["paths"]["rig_config"]), "Rig config")
    log = pc.StageLog(mpath, STAGE)
    deform = {b.name for b in rig.data.bones if b.use_deform}
    root = next((j["name"] for j in data["joints"] if j["parent"] is None), None)
    root_def = rc.DEF + root if root else None
    comps = [c for c in data.get("components", []) if bpy.data.objects.get(c["name"])]
    objs = [bpy.data.objects[c["name"]] for c in comps]
    rigid_of = {c["name"]: c["role"] != "membrane" for c in comps}
    results = {o.name: static_checks(o, deform, root_def, rigid_of[o.name]) for o in objs}
    used = set().union(*[set(r["bones_used"]) for r in results.values()]) if results else set()
    zero_infl = sorted(deform - used)
    defects = []
    for name, r in results.items():
        if r["over_4"]:
            defects.append(("error", "vertices with more than 4 influences", [name]))
        if r["unweighted"]:
            defects.append(("error", "unweighted vertices", [name]))
        if r["bad_sums"]:
            defects.append(("warning", "weights do not sum to 1", [name]))
        if r["root_weighted_verts"]:
            defects.append(("error", "root bone has weights (Roblox drops them)", [name]))
        if r["non_deform_groups"]:
            defects.append(("warning", "vertex groups for non-deform bones", [name]))
        if r.get("rigid_multi_bone"):
            defects.append(("warning", "rigid component influenced by several bones", [name]))
    if zero_infl:
        defects.append(("info", f"{len(zero_infl)} deform bones without influence: enable 'Keep Zero Influence Bones' "
                                "in the Roblox Importer or they are removed", zero_infl[:20]))
    tests_out = {}
    tests = cfg.get("deformation_tests", [])
    wanted = set(pc.csv_list(params.get("tests")))
    if not params.get("no_tests") and tests:
        ad = rig.animation_data
        saved_action = ad.action if ad else None
        if ad:
            ad.action = None
        dg = bpy.context.evaluated_depsgraph_get()
        rest = evaluated_geometry(objs, dg)
        for t in tests:
            if wanted and t["name"] not in wanted:
                continue
            touched = apply_pose(rig, t["pose"])
            bpy.context.view_layer.update()
            dg = bpy.context.evaluated_depsgraph_get()
            posed = evaluated_geometry(objs, dg)
            res = {}
            for o in objs:
                cmp = compare(rest[o.name], posed[o.name], rigid_of[o.name])
                if not rigid_of[o.name]:
                    res[o.name] = cmp  # always report membranes
                elif cmp.get("max_edge_deviation", 0) > float(cfg.get("rigid_tolerance", 0.01)):
                    res[o.name] = cmp  # rigid parts only when they deform
            reset_pose(rig, touched)
            bpy.context.view_layer.update()
            tests_out[t["name"]] = {"posed_bones": len(touched), "results": res}
            for name, r in res.items():
                if r.get("collapsed_faces") or r.get("overstretched_faces"):
                    defects.append(("warning", f"test {t['name']}: membrane faces collapse/overstretch", [name]))
                if r.get("max_edge_deviation"):
                    defects.append(("error", f"test {t['name']}: rigid component deforms", [name]))
        if ad:
            ad.action = saved_action
    dsum = pc.sync_stage_defects(data, STAGE, defects)
    blocking = any(s == "error" for s, _, _ in defects)
    summary = {"objects": len(objs), "max_influences": max((r["max_influences"] for r in results.values()), default=0),
               "zero_influence_bones": len(zero_infl), "tests": list(tests_out), "defects": dsum}
    log.dump("details", {"static": results, "tests": tests_out, "zero_influence": zero_infl})
    pc.set_stage(data, STAGE, "failed" if blocking else "done", summary, pc.to_rel(mpath, log.path))
    pc.save_manifest(mpath, data)
    log.close()
    compact_tests = {k: {n: r for n, r in v["results"].items() if "edge_ratio_max" in r or "error" in r}
                     for k, v in tests_out.items()}
    return {"ok": not blocking, "stage": STAGE, **summary, "membrane_tests": compact_tests,
            "first_defects": [d[1] for d in defects[:5]]}


def main() -> None:
    p = pc.base_parser(__doc__)
    p.add_argument("--tests", help="Comma-separated deformation test names")
    p.add_argument("--no-tests", action="store_true")
    pc.cli_entry(run, p)


if __name__ == "__main__":
    main()
