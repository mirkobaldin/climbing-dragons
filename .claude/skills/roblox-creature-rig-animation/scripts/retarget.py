"""Stage `retarget` (optional): BVH or joint-trajectory motion -> control bones.

  python run_stage.py run retarget --manifest P -- --mapping config/retarget_bvh.json --clip WalkMocap
         [--source FILE] [--keep-source] [--frames 1,120]

Mapping file `mode`:
  "bvh"        : imports the BVH (import_anim.bvh, axis/scale from mapping.source),
                 transfers world-space rotation deltas per mapped bone
                 R_t(f) = R_s(f) * R_s_rest^-1 * R_t_rest (+ optional per-bone
                 rest_offset_deg), root translation scaled ("auto" = hip-height ratio),
                 IK foot controls follow source foot positions.
  "trajectory" : JSON {fps, axis_forward, axis_up, scale, joints: {name: [[x,y,z], ...]}};
                 position_targets drive IK/torso controls, aim entries rotate a
                 control so its rest direction (+Y) follows (to - from).
Rest pose, scale (meters), axis conversion (bpy_extras.io_utils.axis_conversion)
and local/global conversion (pose_bone.matrix assignment, parents first, depsgraph
update per hierarchy level) are explicit. Values are recorded first and written as
F-curves at the end (Euler continuity via make_compatible, quaternion sign continuity).
Rig chains without any mapped source (typically wings, tail, jaw for human mocap)
are reported as `unsupported_by_source`; no motion is invented for them.

STATUS: implemented, untested.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402
import rig_common as rc  # noqa: E402

STAGE = "retarget"


def depth_of(pb):
    d = 0
    while pb.parent is not None:
        d += 1
        pb = pb.parent
    return d


class Recorder:
    def __init__(self):
        self.data: dict = {}
        self.prev: dict = {}

    def rot(self, pb, frame):
        if pb.rotation_mode in ("QUATERNION", "AXIS_ANGLE"):
            q = pb.rotation_quaternion.copy()
            p = self.prev.get(pb.name)
            if p is not None and p.dot(q) < 0:
                q.negate()
            self.prev[pb.name] = q
            self.data.setdefault((pb.name, "rotation_quaternion"), []).append((frame, tuple(q)))
        else:
            e = pb.rotation_euler.copy()
            p = self.prev.get(pb.name)
            if p is not None:
                e.make_compatible(p)
            self.prev[pb.name] = e
            self.data.setdefault((pb.name, "rotation_euler"), []).append((frame, tuple(e)))

    def loc(self, pb, frame):
        self.data.setdefault((pb.name, "location"), []).append((frame, tuple(pb.location)))

    def keyed(self) -> set:
        return {b for b, _ in self.data}

    def write(self, cb):
        for (bone, prop), seq in self.data.items():
            frames = [f for f, _ in seq]
            for idx in range(len(seq[0][1])):
                rc.write_curve(cb, rc.data_path(bone, prop), idx, frames, [v[idx] for _, v in seq], bone)


def set_world(rig, pb, rot_world=None, loc_world=None):
    """Set a pose bone from a world rotation and/or world head position."""
    from mathutils import Matrix
    inv = rig.matrix_world.inverted()
    cur = pb.matrix.copy()
    loc = inv @ loc_world if loc_world is not None else cur.translation
    rot = (inv.to_quaternion() @ rot_world) if rot_world is not None else cur.to_quaternion()
    pb.matrix = Matrix.LocRotScale(loc, rot, None)


def unsupported_chains(data, keyed: set) -> list[str]:
    chains = {}
    for j in data["joints"]:
        chains.setdefault(f"{j['chain']}|{j['side']}", []).append(j["name"])
    ik = data.get("rig", {}).get("ik_chains", {})
    out = []
    for key, names in chains.items():
        ctrls = {rc.CTRL + n for n in names}
        if key in ik:
            ctrls.add(ik[key]["foot"])
        if not ctrls & keyed and not key.startswith("root"):
            out.append(key)
    return sorted(out)


def run_bvh(rig, mp, src_path, scene, frames_opt, keep_source, rec):
    import bpy
    from mathutils import Euler, Vector
    s = mp["source"]
    before = set(bpy.data.objects)
    bpy.ops.import_anim.bvh(filepath=str(src_path), target="ARMATURE", global_scale=float(s.get("scale", 1.0)),
                            rotate_mode=s.get("rotate_mode", "NATIVE"), axis_forward=s.get("axis_forward", "-Z"),
                            axis_up=s.get("axis_up", "Y"), use_fps_scale=False, frame_start=1)
    new = [o for o in bpy.data.objects if o not in before and o.type == "ARMATURE"]
    if not new:
        raise pc.PipelineError("BVH import produced no armature")
    src = new[0]
    src.name = "SRC_retarget"
    try:
        sad = src.animation_data
        if not sad or not sad.action:
            raise pc.PipelineError("Imported BVH has no animation")
        f0, f1 = (int(x) for x in sad.action.frame_range)
        if frames_opt:
            f0, f1 = frames_opt
        pairs = []
        for m in mp.get("bones", []):
            if m["source"] not in src.pose.bones or m["target"] not in rig.pose.bones:
                raise pc.PipelineError(f"Mapping {m['source']} -> {m['target']}: bone not found")
            pairs.append(m)
        root = mp.get("root")
        feet = mp.get("ik_targets", [])
        for fm in feet:
            if fm["source"] not in src.pose.bones or fm["target"] not in rig.pose.bones:
                raise pc.PipelineError(f"IK mapping {fm['source']} -> {fm['target']}: bone not found")
        rest_src = {m["source"]: (src.matrix_world @ src.data.bones[m["source"]].matrix_local).to_quaternion()
                    for m in pairs}
        rest_tgt = {m["target"]: (rig.matrix_world @ rig.data.bones[m["target"]].matrix_local).to_quaternion()
                    for m in pairs}
        k = 1.0
        if root:
            if root.get("scale", "auto") == "auto":
                sh = (src.matrix_world @ src.data.bones[root["source"]].head_local).z
                th = (rig.matrix_world @ rig.data.bones[root["target"]].head_local).z
                k = th / sh if sh > 1e-6 else 1.0
            else:
                k = float(root["scale"])
        scene.frame_set(f0)
        start_hips = (src.matrix_world @ src.pose.bones[root["source"]].head) if root else None
        start_feet = {f["source"]: src.matrix_world @ src.pose.bones[f["source"]].head for f in feet}
        levels: dict[int, list] = {}
        for m in pairs:
            levels.setdefault(depth_of(rig.pose.bones[m["target"]]), []).append(m)
        in_place = mp.get("in_place", True)
        for f in range(f0, f1 + 1):
            scene.frame_set(f)
            frame = f - f0 + 1
            horiz = Vector()
            if root:
                disp = (src.matrix_world @ src.pose.bones[root["source"]].head - start_hips) * k
                horiz = Vector((disp.x, disp.y, 0.0))
                if in_place:
                    disp = Vector((0.0, 0.0, disp.z))
                pb = rig.pose.bones[root["target"]]
                set_world(rig, pb, loc_world=rig.matrix_world @ pb.bone.head_local + disp)
                bpy.context.view_layer.update()
            for d in sorted(levels):
                for m in levels[d]:
                    rs = (src.matrix_world @ src.pose.bones[m["source"]].matrix).to_quaternion()
                    rt = (rs @ rest_src[m["source"]].inverted()) @ rest_tgt[m["target"]]
                    if m.get("rest_offset_deg"):
                        rt = rt @ Euler([math.radians(a) for a in m["rest_offset_deg"]]).to_quaternion()
                    set_world(rig, rig.pose.bones[m["target"]], rot_world=rt)
                bpy.context.view_layer.update()
            for fm in feet:
                pb = rig.pose.bones[fm["target"]]
                p = (src.matrix_world @ src.pose.bones[fm["source"]].head - start_feet[fm["source"]]) * k
                if in_place:
                    p -= horiz
                set_world(rig, pb, loc_world=rig.matrix_world @ pb.bone.head_local + p)
            bpy.context.view_layer.update()
            for m in pairs:
                rec.rot(rig.pose.bones[m["target"]], frame)
            if root:
                rec.loc(rig.pose.bones[root["target"]], frame)
            for fm in feet:
                rec.loc(rig.pose.bones[fm["target"]], frame)
    finally:
        if not keep_source:
            act = src.animation_data.action if src.animation_data else None
            arm = src.data
            bpy.data.objects.remove(src)
            if arm.users == 0:
                bpy.data.armatures.remove(arm)
            if act is not None and act.users == 0:
                bpy.data.actions.remove(act)
    return (1, f1 - f0 + 1), {"root_scale": round(k, 4)}


def run_trajectory(rig, mp, src_path, frames_opt, rec):
    import bpy
    from bpy_extras.io_utils import axis_conversion
    from mathutils import Vector
    tr = pc.load_json(src_path, "Trajectory file")
    conv = axis_conversion(from_forward=tr.get("axis_forward", "-Z"), from_up=tr.get("axis_up", "Y"),
                           to_forward="Y", to_up="Z").to_3x3()
    sc = float(tr.get("scale", 1.0))
    joints = {k: [conv @ Vector(p) * sc for p in v] for k, v in tr["joints"].items()}
    for ref in [t["joint"] for t in mp.get("position_targets", [])] + \
               [a[x] for a in mp.get("aim", []) for x in ("from", "to")]:
        if ref not in joints:
            raise pc.PipelineError(f"Trajectory joint {ref!r} not in file")
    n = min(len(v) for v in joints.values())
    f0, f1 = frames_opt or (0, n - 1)
    f1 = min(f1, n - 1)
    origin = {k: v[f0] for k, v in joints.items()}
    aims = sorted(mp.get("aim", []), key=lambda a: depth_of(rig.pose.bones[a["target"]]))
    for i in range(f0, f1 + 1):
        frame = i - f0 + 1
        for t in mp.get("position_targets", []):
            pb = rig.pose.bones[t["target"]]
            p = joints[t["joint"]][i] - origin[t["joint"]]
            if mp.get("in_place", True) and mp.get("root_joint"):
                rj = joints[mp["root_joint"]][i] - origin[mp["root_joint"]]
                p -= Vector((rj.x, rj.y, 0.0))
            set_world(rig, pb, loc_world=rig.matrix_world @ pb.bone.head_local + p * float(t.get("scale", 1.0)))
        bpy.context.view_layer.update()
        for a in aims:
            pb = rig.pose.bones[a["target"]]
            d = joints[a["to"]][i] - joints[a["from"]][i]
            if d.length < 1e-6:
                continue
            rest = rig.matrix_world @ pb.bone.matrix_local
            rest_dir = (rest.to_3x3() @ Vector((0, 1, 0))).normalized()
            set_world(rig, pb, rot_world=rest_dir.rotation_difference(d.normalized()) @ rest.to_quaternion())
            bpy.context.view_layer.update()
        for t in mp.get("position_targets", []):
            rec.loc(rig.pose.bones[t["target"]], frame)
        for a in aims:
            rec.rot(rig.pose.bones[a["target"]], frame)
    return (1, f1 - f0 + 1), {"source_fps": tr.get("fps")}


def run(params: dict) -> dict:
    import bpy
    pc.require_blender()
    mpath, data = pc.load_manifest(params["manifest"])
    pc.ensure_working_blend(mpath, data, adopt_current=bool(params.get("adopt_current")))
    pc.ensure_object_mode()
    rig = rc.get_rig(data)
    mp = pc.load_json(pc.to_abs(mpath, params["mapping"]), "Retarget mapping")
    src = pc.to_abs(mpath, params.get("source") or mp.get("source", {}).get("file", ""))
    if not src.is_file():
        raise pc.PipelineError(f"Motion source not found: {src}")
    clip = params["clip"]
    fr = pc.csv_list(params.get("frames"))
    frames_opt = (int(fr[0]), int(fr[1])) if len(fr) == 2 else None
    scene = bpy.context.scene
    log = pc.StageLog(mpath, STAGE)
    ad = rig.animation_data or rig.animation_data_create()
    previous = ad.action
    ad.action = None  # compute on a clean pose; F-curves are written at the end
    for pb in rig.pose.bones:
        pb.location, pb.rotation_euler, pb.rotation_quaternion = (0, 0, 0), (0, 0, 0), (1, 0, 0, 0)
    rec = Recorder()
    mode = mp.get("mode", "bvh")
    try:
        if mode == "bvh":
            (s, e), extra = run_bvh(rig, mp, src, scene, frames_opt, params.get("keep_source"), rec)
        elif mode == "trajectory":
            (s, e), extra = run_trajectory(rig, mp, src, frames_opt, rec)
        else:
            raise pc.PipelineError("mapping.mode must be 'bvh' or 'trajectory'")
    except Exception:
        ad.action = previous
        raise
    act, slot, cb = rc.ensure_action(rig, f"ANIM_{clip}")
    rec.write(cb)
    act.use_frame_range = True
    act.frame_start, act.frame_end = s, e
    rc.assign_action(rig, act, slot)
    for pb in rig.pose.bones:
        pb.location, pb.rotation_euler, pb.rotation_quaternion = (0, 0, 0), (0, 0, 0), (1, 0, 0, 0)
    keyed = rec.keyed()
    unsupported = unsupported_chains(data, keyed)
    data.setdefault("animations", {})[clip] = {
        "action": act.name, "frames": [s, e], "fps": scene.render.fps, "loop": bool(mp.get("loop", False)),
        "source": f"retarget_{mode}", "source_file": pc.to_rel(mpath, src),
        "in_place": bool(mp.get("in_place", True)), "unsupported_by_source": unsupported, **extra}
    pc.sync_stage_defects(data, STAGE, [("info", f"{clip}: no source motion for chains {unsupported}", [])]
                          if unsupported else [])
    pc.set_stage(data, STAGE, "done", {"clip": clip, "keyed_controls": len(keyed), "unsupported": unsupported},
                 pc.to_rel(mpath, log.path))
    saved = pc.save_working(mpath, data, params.get("save"))
    pc.save_manifest(mpath, data)
    log.close()
    return {"stage": STAGE, "clip": clip, "frames": [s, e], "keyed_controls": len(keyed),
            "unsupported_by_source": unsupported, **extra, "saved_blend": saved,
            "note": "Unsupported chains keep the rest pose; add procedural layers or keyframe them by hand."}


def main() -> None:
    p = pc.base_parser(__doc__)
    p.add_argument("--mapping", required=True)
    p.add_argument("--clip", required=True)
    p.add_argument("--source", help="BVH or trajectory JSON (default: mapping.source.file)")
    p.add_argument("--frames", help="start,end in source frames")
    p.add_argument("--keep-source", action="store_true")
    pc.cli_entry(run, p)


if __name__ == "__main__":
    main()
