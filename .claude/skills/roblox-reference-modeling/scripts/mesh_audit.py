"""Stage `mesh_audit`: geometry checks per component and polygon budgets.

  python run_stage.py run mesh_audit --manifest P -- [--fix safe] [--profile pc_standard]
         [--merge-dist 1e-5] [--no-intersections] [--include-approved]

Per object (never across objects, never merges separate bones):
  degenerate faces (area < eps), zero-length edges, duplicate vertices
  (within --merge-dist, same object only), loose vertices/edges, non-manifold
  edges (>2 faces), boundary edges (open shells), inconsistent winding,
  inverted closed shells (negative signed volume), self-intersections between
  faces of the SAME shell (overlapping separate shells in one component are
  reported as info). Evaluated mesh (modifiers) is used for triangle counts and
  watertightness of membranes after RBX_Solidify.
Across objects (bbox prefilter): intersecting component pairs, except role
pairs allowed in anatomy config `intersection_allow_roles`.
Budgets: per role, per export group (Roblox hard limit per mesh), total.

--fix safe (checkpoint first): remove doubles within object, dissolve
degenerate geometry, delete loose verts/edges, recalculate normals outward on
closed shells only. Approved components are skipped unless --include-approved.
No decimation or remeshing is ever performed here.

STATUS: implemented, untested.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402

STAGE = "mesh_audit"
CLOSED_ROLES_EXEMPT = {"membrane"}  # base mesh is an open sheet; checked after solidify


def _shell_ids(bm):
    parent = list(range(len(bm.verts)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for e in bm.edges:
        a, b = find(e.verts[0].index), find(e.verts[1].index)
        if a != b:
            parent[a] = b
    return [find(i) for i in range(len(bm.verts))]


def audit_object(obj, dg, merge_dist, check_self):
    import bmesh
    from mathutils.bvhtree import BVHTree

    res = {"name": obj.name, "role": obj.get("rbx_role", "other_rigid")}
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    res["verts"], res["faces"] = len(bm.verts), len(bm.faces)
    res["degenerate_faces"] = sum(1 for f in bm.faces if f.calc_area() < 1e-10)
    res["zero_edges"] = sum(1 for e in bm.edges if e.calc_length() < 1e-7)
    res["duplicate_verts"] = len(bmesh.ops.find_doubles(bm, verts=bm.verts, dist=merge_dist)["targetmap"])
    res["loose_verts"] = sum(1 for v in bm.verts if not v.link_edges)
    res["loose_edges"] = sum(1 for e in bm.edges if not e.link_faces)
    res["nonmanifold_edges"] = sum(1 for e in bm.edges if len(e.link_faces) > 2)
    res["boundary_edges"] = sum(1 for e in bm.edges if len(e.link_faces) == 1)
    bad_wind = 0
    for e in bm.edges:
        if len(e.link_loops) == 2 and e.link_loops[0].vert == e.link_loops[1].vert:
            bad_wind += 1
    res["inconsistent_winding_edges"] = bad_wind
    res["ngons"] = sum(1 for f in bm.faces if len(f.verts) > 4)
    shells = _shell_ids(bm)
    res["shells"] = len(set(shells))
    vol = 0.0
    if res["boundary_edges"] == 0 and res["nonmanifold_edges"] == 0:
        vol = bm.calc_volume(signed=True)
        res["inverted"] = vol < 0
    res["signed_volume"] = round(vol, 6)
    if check_self and len(bm.faces) < 60000:
        tree = BVHTree.FromBMesh(bm)
        same, cross = 0, 0
        for a, b in tree.overlap(tree):
            if a >= b:
                continue
            fa, fb = bm.faces[a], bm.faces[b]
            if {v.index for v in fa.verts} & {v.index for v in fb.verts}:
                continue
            if shells[fa.verts[0].index] == shells[fb.verts[0].index]:
                same += 1
            else:
                cross += 1
        res["self_intersections_same_shell"] = same
        res["overlapping_shell_pairs"] = cross
    bm.free()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    me.calc_loop_triangles()
    res["tris"] = len(me.loop_triangles)
    if res["role"] in CLOSED_ROLES_EXEMPT:
        bm2 = bmesh.new()
        bm2.from_mesh(me)
        res["evaluated_boundary_edges"] = sum(1 for e in bm2.edges if len(e.link_faces) == 1)
        bm2.free()
    ev.to_mesh_clear()
    return res


def fix_object(obj, merge_dist, closed):
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    out = {}
    targetmap = bmesh.ops.find_doubles(bm, verts=bm.verts[:], dist=merge_dist)["targetmap"]
    out["merged"] = len(targetmap)
    if targetmap:
        bmesh.ops.weld_verts(bm, targetmap=targetmap)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-7, edges=bm.edges[:])
    loose_e = [e for e in bm.edges if not e.link_faces]
    if loose_e:
        bmesh.ops.delete(bm, geom=loose_e, context="EDGES")
    loose_v = [v for v in bm.verts if not v.link_edges]
    if loose_v:
        bmesh.ops.delete(bm, geom=loose_v, context="VERTS")
    out["deleted_loose"] = len(loose_v) + len(loose_e)
    if closed:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        out["normals_recalculated"] = True
    bm.to_mesh(obj.data)
    obj.data.update()
    bm.free()
    return out


def run(params: dict) -> dict:
    import bpy
    pc.require_blender()
    mpath, data = pc.load_manifest(params["manifest"])
    pc.ensure_working_blend(mpath, data, adopt_current=bool(params.get("adopt_current")))
    pc.ensure_object_mode()
    budgets = pc.load_json(pc.to_abs(mpath, data["paths"]["polygon_budgets"]), "Polygon budgets")
    profile_name = params.get("profile") or data.get("polygon_budget_profile", "pc_standard")
    prof = budgets["profiles"].get(profile_name)
    if prof is None:
        raise pc.PipelineError(f"Budget profile {profile_name!r} not in {list(budgets['profiles'])}")
    hard_max = int(budgets["roblox_limits"]["in_experience"]["max_tris_per_mesh"])
    cfg = {}
    ap = data["paths"].get("anatomy_config")
    if ap and pc.to_abs(mpath, ap).exists():
        cfg = pc.load_json(pc.to_abs(mpath, ap), "Anatomy config")
    allow = {tuple(sorted(p)) for p in cfg.get("intersection_allow_roles", [])}
    merge_dist = float(params.get("merge_dist") or 1e-5)
    log = pc.StageLog(mpath, STAGE)
    comps = {c["name"]: c for c in data.get("components", [])}
    objs = [bpy.data.objects[n] for n in comps if bpy.data.objects.get(n) and bpy.data.objects[n].type == "MESH"]
    missing = [n for n in comps if bpy.data.objects.get(n) is None]

    fixed = {}
    if params.get("fix") == "safe":
        ck = pc.save_checkpoint(mpath, data, STAGE, "before safe fix")
        log.write("checkpoint", ck["path"])
        for o in objs:
            if comps[o.name].get("approved") and not params.get("include_approved"):
                continue
            closed_role = o.get("rbx_role") not in CLOSED_ROLES_EXEMPT
            fixed[o.name] = fix_object(o, merge_dist, closed_role)

    dg = bpy.context.evaluated_depsgraph_get()
    results = [audit_object(o, dg, merge_dist, not params.get("no_intersections")) for o in objs]

    cross_hits = []
    if not params.get("no_intersections"):
        from mathutils.bvhtree import BVHTree
        trees, boxes = {}, {}
        for o in objs:
            mw = o.matrix_world
            verts = [mw @ v.co for v in o.data.vertices]
            if not verts:
                continue
            boxes[o.name] = ([min(v[i] for v in verts) for i in range(3)], [max(v[i] for v in verts) for i in range(3)])
            trees[o.name] = BVHTree.FromPolygons(verts, [tuple(p.vertices) for p in o.data.polygons])
        names = sorted(trees)
        for i, a in enumerate(names):
            for b in names[i + 1:]:
                (amin, amax), (bmin, bmax) = boxes[a], boxes[b]
                if any(amax[k] < bmin[k] or bmax[k] < amin[k] for k in range(3)):
                    continue
                roles = tuple(sorted((comps[a]["role"], comps[b]["role"])))
                if roles in allow:
                    continue
                n = len(trees[a].overlap(trees[b]))
                if n:
                    cross_hits.append({"a": a, "b": b, "face_pairs": n})

    role_tris, group_tris = {}, {}
    for r in results:
        role_tris[r["role"]] = role_tris.get(r["role"], 0) + r["tris"]
        g = comps[r["name"]].get("export_group", "default")
        group_tris[g] = group_tris.get(g, 0) + r["tris"]
        comps[r["name"]]["tris"] = r["tris"]
    total = sum(role_tris.values())
    defects = []
    over_roles = {k: v for k, v in role_tris.items() if k in prof.get("roles", {}) and v > prof["roles"][k]}
    for k, v in over_roles.items():
        defects.append(("warning", f"role {k}: {v} tris > profile {profile_name} budget {prof['roles'][k]}", []))
    if total > prof["total_tris"]:
        defects.append(("warning", f"total {total} tris > profile budget {prof['total_tris']}", []))
    for g, v in group_tris.items():
        if v > hard_max:
            defects.append(("error", f"export group {g}: {v} tris exceeds Roblox per-mesh limit {hard_max}; "
                                     "split the group or lower detail", []))
    for r in results:
        n = r["name"]
        for key, sev in (("degenerate_faces", "warning"), ("zero_edges", "warning"), ("duplicate_verts", "warning"),
                         ("loose_verts", "info"), ("loose_edges", "info"), ("nonmanifold_edges", "error"),
                         ("inconsistent_winding_edges", "error"), ("self_intersections_same_shell", "warning")):
            if r.get(key):
                defects.append((sev, f"{key}", [n]))
        if r.get("inverted"):
            defects.append(("error", "inverted normals (negative volume)", [n]))
        if r["role"] not in CLOSED_ROLES_EXEMPT and r["boundary_edges"]:
            defects.append(("warning", "open shell (Roblox expects watertight meshes)", [n]))
        if r["role"] in CLOSED_ROLES_EXEMPT and r.get("evaluated_boundary_edges"):
            defects.append(("warning", "membrane not closed after RBX_Solidify", [n]))
        if r["role"] == "membrane":
            o = bpy.data.objects[n]
            if int(o.get("rbx_rows", 0)) < int(budgets.get("min_membrane_rows", 6)):
                defects.append(("warning", "membrane has too few rows for smooth folding", [n]))
    merged: dict[tuple, list] = {}
    for sev, desc, objs_ in defects:
        merged.setdefault((sev, desc), []).extend(objs_)
    defects = [(s, d, o) for (s, d), o in merged.items()]
    for h in cross_hits[:30]:
        defects.append(("info", "components intersect (check joint gaps)", [h["a"], h["b"]]))
    dsum = pc.sync_stage_defects(data, STAGE, defects)
    data["components"] = sorted(comps.values(), key=lambda c: c["name"])
    groups = {}
    for c in data["components"]:
        groups.setdefault(c.get("export_group", "default"), []).append(c["name"])
    data["export_groups"] = [{"name": g, "components": n, "tris": group_tris.get(g, 0), "max_tris": hard_max}
                             for g, n in sorted(groups.items())]
    blocking = any(s in ("error", "blocker") for s, _, _ in defects)
    summary = {"objects": len(results), "missing_objects": len(missing), "total_tris": total,
               "profile": profile_name, "group_tris": group_tris, "over_role_budgets": over_roles,
               "cross_intersections": len(cross_hits), "fixed": len(fixed), "defects": dsum}
    log.dump("objects", {"results": results, "cross": cross_hits, "fixed": fixed, "missing": missing})
    pc.set_stage(data, STAGE, "failed" if blocking else "done", summary, pc.to_rel(mpath, log.path))
    saved = pc.save_working(mpath, data, params.get("save")) if fixed else False
    pc.save_manifest(mpath, data)
    log.close()
    worst = sorted(results, key=lambda r: -(r.get("nonmanifold_edges", 0) + r.get("inconsistent_winding_edges", 0)
                                            + r.get("degenerate_faces", 0) + r.get("duplicate_verts", 0)))[:5]
    return {"ok": not blocking, "stage": STAGE, **summary, "saved_blend": saved,
            "worst_objects": [{k: w.get(k) for k in ("name", "tris", "nonmanifold_edges", "boundary_edges",
                                                     "degenerate_faces", "duplicate_verts")} for w in worst],
            "log": pc.to_rel(mpath, log.path)}


def main() -> None:
    p = pc.base_parser(__doc__)
    p.add_argument("--fix", choices=("none", "safe"), default="none")
    p.add_argument("--profile", help="Polygon budget profile name")
    p.add_argument("--merge-dist", type=float, default=1e-5)
    p.add_argument("--no-intersections", action="store_true")
    p.add_argument("--include-approved", action="store_true")
    pc.cli_entry(run, p)


if __name__ == "__main__":
    main()
