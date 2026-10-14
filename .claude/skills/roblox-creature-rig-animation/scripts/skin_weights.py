"""Stage `skinning`: rigid weights for skeletal components, distributed weights
for membranes, Armature modifier + parenting. Idempotent (DEF-* groups rebuilt).

  python run_stage.py run skin_weights --manifest P -- [--only names] [--max-influences 4]
         [--falloff 2.0] [--smooth-iterations 8] [--smooth-factor 0.5] [--min-weight 0.02]

Rigid roles: every vertex -> DEF-<bone_hint> weight 1.0 (bones never bend).
Membranes: candidate bones = DEF-<influences>; per vertex
  w_b = 1 / (dist(vertex, bone segment) + eps)^falloff, keep the strongest
  `max_influences`, normalise, Laplacian-smooth over mesh edges, re-limit,
  drop weights < min_weight, renormalise. Root bone never receives weight.
Settings may also come from rig_config.skinning. Max influences is capped at 4
(Roblox per-vertex limit, verified 2026-10-13).

STATUS: implemented, untested.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402
import rig_common as rc  # noqa: E402

STAGE = "skinning"
ROBLOX_MAX_INFLUENCES = 4


def segment_distances(P, A, B):
    """P (n,3), A/B (m,3) -> (n,m) distance from each point to each segment."""
    import numpy as np
    AB = B - A
    denom = np.maximum((AB * AB).sum(axis=1), 1e-12)
    AP = P[:, None, :] - A[None, :, :]
    t = np.clip((AP * AB[None]).sum(axis=2) / denom[None], 0.0, 1.0)
    closest = A[None] + t[..., None] * AB[None]
    return np.linalg.norm(P[:, None, :] - closest, axis=2)


def top_k(W, k):
    import numpy as np
    if W.shape[1] > k:
        idx = np.argpartition(-W, k - 1, axis=1)[:, k:]
        np.put_along_axis(W, idx, 0.0, axis=1)
    s = W.sum(axis=1, keepdims=True)
    return np.divide(W, s, out=np.zeros_like(W), where=s > 0)


def membrane_weights(obj, rig, bones, cfg):
    import numpy as np
    me = obj.data
    n = len(me.vertices)
    co = np.empty(n * 3, dtype=np.float64)
    me.vertices.foreach_get("co", co)
    co = co.reshape(n, 3)
    mw = np.array(obj.matrix_world)
    P = co @ mw[:3, :3].T + mw[:3, 3]
    rm = np.array(rig.matrix_world)
    A = np.array([list(rig.data.bones[b].head_local) for b in bones]) @ rm[:3, :3].T + rm[:3, 3]
    B = np.array([list(rig.data.bones[b].tail_local) for b in bones]) @ rm[:3, :3].T + rm[:3, 3]
    D = segment_distances(P, A, B)
    W = 1.0 / (D + 1e-3) ** float(cfg["falloff"])
    k = min(int(cfg["max_influences"]), ROBLOX_MAX_INFLUENCES, len(bones))
    W = top_k(W, k)
    ed = np.empty(len(me.edges) * 2, dtype=np.int64)
    me.edges.foreach_get("vertices", ed)
    ed = ed.reshape(-1, 2)
    deg = np.bincount(ed.ravel(), minlength=n).astype(np.float64)[:, None]
    lam = float(cfg["smooth_factor"])
    for _ in range(int(cfg["smooth_iterations"])):
        acc = np.zeros_like(W)
        np.add.at(acc, ed[:, 0], W[ed[:, 1]])
        np.add.at(acc, ed[:, 1], W[ed[:, 0]])
        avg = np.divide(acc, deg, out=W.copy(), where=deg > 0)
        W = (1 - lam) * W + lam * avg
    W = top_k(W, k)
    W[W < float(cfg["min_weight"])] = 0.0
    W = top_k(W, k)
    return W


def reset_groups(obj):
    for vg in list(obj.vertex_groups):
        if vg.name.startswith(rc.DEF):
            obj.vertex_groups.remove(vg)


def ensure_armature_modifier(obj, rig):
    import bpy
    mod = obj.modifiers.get("RBX_Armature")
    if mod is None:
        mod = obj.modifiers.new("RBX_Armature", "ARMATURE")
        mod.name = "RBX_Armature"
    mod.object = rig
    mod.use_vertex_groups = True
    mod.use_bone_envelopes = False
    mod.use_deform_preserve_volume = False
    idx = list(obj.modifiers).index(mod)
    if idx != 0:  # deform before Solidify so the shell follows the deformed sheet
        with bpy.context.temp_override(object=obj, active_object=obj):
            bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.parent_type = "OBJECT"
    obj.matrix_world = world


def run(params: dict) -> dict:
    import bpy
    pc.require_blender()
    mpath, data = pc.load_manifest(params["manifest"])
    pc.check_retry_budget(data, STAGE)
    if data["stages"].get("rig_build", {}).get("status") not in ("done", "approved"):
        raise pc.PipelineError("Run build_rig.py first (rig_build not done).")
    pc.ensure_working_blend(mpath, data, adopt_current=bool(params.get("adopt_current")))
    pc.ensure_object_mode()
    rig = rc.get_rig(data)
    rcfg = pc.load_json(pc.to_abs(mpath, data["paths"]["rig_config"]), "Rig config").get("skinning", {})
    cfg = {"max_influences": 4, "falloff": 2.0, "smooth_iterations": 8, "smooth_factor": 0.5, "min_weight": 0.02,
           **rcfg, **{k: v for k, v in params.items() if k in (
               "max_influences", "falloff", "smooth_iterations", "smooth_factor", "min_weight") and v is not None}}
    if int(cfg["max_influences"]) > ROBLOX_MAX_INFLUENCES:
        raise pc.PipelineError(f"max_influences {cfg['max_influences']} exceeds Roblox limit {ROBLOX_MAX_INFLUENCES}")
    root = next((j["name"] for j in data["joints"] if j["parent"] is None), None)
    bones = {b.name for b in rig.data.bones if b.use_deform}
    only = set(pc.csv_list(params.get("only")))
    log = pc.StageLog(mpath, STAGE)
    ck = pc.save_checkpoint(mpath, data, STAGE, "before skinning")
    log.write("checkpoint", ck["path"])
    rigid, membranes, problems = 0, {}, []
    for c in data.get("components", []):
        if only and c["name"] not in only:
            continue
        obj = bpy.data.objects.get(c["name"])
        if obj is None or obj.type != "MESH":
            problems.append(f"missing mesh {c['name']}")
            continue
        reset_groups(obj)
        if c["role"] == "membrane":
            cand = [rc.DEF + b for b in c.get("influences", []) if b != root and rc.DEF + b in bones]
            if len(cand) < 2:
                problems.append(f"{c['name']}: fewer than 2 valid influence bones")
                continue
            W = membrane_weights(obj, rig, cand, cfg)
            groups = [obj.vertex_groups.new(name=b) for b in cand]
            nz = W.nonzero()
            for vi, bi in zip(*nz):
                groups[bi].add([int(vi)], float(W[vi, bi]), "REPLACE")
            per_vertex = (W > 0).sum(axis=1)
            membranes[c["name"]] = {"bones": len(cand), "max_influences": int(per_vertex.max()),
                                    "unweighted": int((per_vertex == 0).sum())}
        else:
            bone = rc.DEF + (c.get("bone_hint") or "")
            if bone not in bones or c.get("bone_hint") == root:
                problems.append(f"{c['name']}: bone_hint {c.get('bone_hint')!r} is not a usable deform bone")
                continue
            vg = obj.vertex_groups.new(name=bone)
            vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
            rigid += 1
        ensure_armature_modifier(obj, rig)
    defects = [("error", p, []) for p in problems]
    pc.sync_stage_defects(data, STAGE, defects)
    summary = {"rigid_components": rigid, "membranes": membranes, "problems": len(problems), "settings": cfg}
    log.dump("details", {"problems": problems, "membranes": membranes})
    pc.set_stage(data, STAGE, "failed" if problems else "done", summary, pc.to_rel(mpath, log.path))
    for s in ("weight_audit", "bake_export"):
        if data["stages"].get(s, {}).get("status") in ("done", "approved"):
            pc.set_stage(data, s, "stale")
    saved = pc.save_working(mpath, data, params.get("save"))
    pc.save_manifest(mpath, data)
    log.close()
    return {"ok": not problems, "stage": STAGE, **summary, "problems_first": problems[:5], "saved_blend": saved}


def main() -> None:
    p = pc.base_parser(__doc__)
    p.add_argument("--only")
    p.add_argument("--max-influences", type=int)
    p.add_argument("--falloff", type=float)
    p.add_argument("--smooth-iterations", type=int)
    p.add_argument("--smooth-factor", type=float)
    p.add_argument("--min-weight", type=float)
    pc.cli_entry(run, p)


if __name__ == "__main__":
    main()
