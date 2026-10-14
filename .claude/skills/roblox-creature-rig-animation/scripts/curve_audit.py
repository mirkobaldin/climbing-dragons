"""Stage `curve_audit`: technical animation checks on evaluated motion.

  python run_stage.py run curve_audit --manifest P -- [--clips Walk,Fly] [--snapshots 3]
         [--contact-height 0.03] [--slide-limit-cm 0.5]

Per clip (evaluated frame by frame, DEF bones):
  loop continuity  : pose and velocity mismatch between first and last frame (loops)
  Euler jumps      : > 90 deg between consecutive keys on control F-curves (flips)
  joint limits     : control keys outside RBX_Limit ranges (motion gets clamped)
  foot sliding     : per foot (tail of the last IK-chain bone), horizontal motion while
                     in contact (height <= rest + contact_height), compensated for
                     in-place clips by speed_mps along the forward axis (-Y)
  root motion      : DEF-root displacement (must stay 0 for in-place Roblox clips)
  transition       : Takeoff last frame vs Fly first frame (max control difference)
--snapshots N renders N Workbench frames per clip (640 px, side view) to
renders/anim/ for a quick visual review; pictures are the real test of quality.

STATUS: implemented, untested.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402
import rig_common as rc  # noqa: E402

STAGE = "curve_audit"


def control_checks(act, rig):
    jumps, limit_hits = [], {}
    for fc in rc.all_fcurves(act):
        if not fc.data_path.startswith('pose.bones["'):
            continue
        bone = fc.data_path.split('"')[1]
        kps = [kp.co[1] for kp in fc.keyframe_points]
        if fc.data_path.endswith("rotation_euler"):
            for a, b in zip(kps, kps[1:]):
                if abs(b - a) > math.radians(90):
                    jumps.append(bone)
                    break
            pb = rig.pose.bones.get(bone)
            con = pb.constraints.get("RBX_Limit") if pb else None
            if con is not None:
                ax = "xyz"[fc.array_index]
                if getattr(con, f"use_limit_{ax}"):
                    lo, hi = getattr(con, f"min_{ax}"), getattr(con, f"max_{ax}")
                    n = sum(1 for v in kps if v < lo - 1e-4 or v > hi + 1e-4)
                    if n:
                        limit_hits[f"{bone}.{ax}"] = n
    return sorted(set(jumps)), limit_hits


def sample(rig, scene, frames, bones):
    out = {b: [] for b in bones}
    mw = rig.matrix_world
    for f in frames:
        scene.frame_set(f)
        for b in bones:
            pb = rig.pose.bones[b]
            out[b].append((mw @ pb.matrix, (mw @ pb.tail)))
    return out


def snapshot(scene, rig, clip, frames, out_dir, n):
    import bpy
    from mathutils import Vector
    cam_data = bpy.data.cameras.get("CAM_ANIM_side") or bpy.data.cameras.new("CAM_ANIM_side")
    cam_data.name = "CAM_ANIM_side"
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.get("CAM_ANIM_side") or bpy.data.objects.new("CAM_ANIM_side", cam_data)
    cam.name = "CAM_ANIM_side"
    if scene.collection.objects.get(cam.name) is None and not cam.users_collection:
        scene.collection.objects.link(cam)
    pts = [rig.matrix_world @ b.head_local for b in rig.data.bones]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    c = (lo + hi) / 2
    size = max(hi - lo) * 1.6
    cam_data.ortho_scale = size
    cam.location = (c.x + size * 2, c.y, c.z + size * 0.15)
    cam.rotation_euler = (math.radians(90), 0, math.radians(90))
    r = scene.render
    saved = (scene.camera, r.engine, r.resolution_x, r.resolution_y, r.filepath, r.film_transparent)
    try:
        scene.camera = cam
        r.engine = "BLENDER_WORKBENCH"
        r.resolution_x, r.resolution_y = 640, 400
        r.film_transparent = False
        paths = []
        picks = [frames[int(i * (len(frames) - 1) / max(n - 1, 1))] for i in range(n)]
        for f in picks:
            scene.frame_set(f)
            p = out_dir / f"{clip}_{f:04d}.png"
            r.filepath = str(p)
            bpy.ops.render.render(write_still=True)
            paths.append(p)
        return paths
    finally:
        scene.camera, r.engine, r.resolution_x, r.resolution_y, r.filepath, r.film_transparent = saved


def run(params: dict) -> dict:
    import bpy
    pc.require_blender()
    mpath, data = pc.load_manifest(params["manifest"])
    pc.ensure_working_blend(mpath, data, adopt_current=bool(params.get("adopt_current")))
    pc.ensure_object_mode()
    rig = rc.get_rig(data)
    anims = data.get("animations", {})
    wanted = pc.csv_list(params.get("clips")) or list(anims)
    if not wanted:
        raise pc.PipelineError("No animations in manifest; run animate_cycles.py or retarget.py first.")
    contact_h = float(params.get("contact_height") or 0.03)
    slide_lim = float(params.get("slide_limit_cm") or 0.5)
    scene = bpy.context.scene
    log = pc.StageLog(mpath, STAGE)
    ik = data.get("rig", {}).get("ik_chains", {})
    leg_end = {}
    for key in ik:
        chain, side = key.split("|")
        js = [j for j in data["joints"] if j["chain"] == chain and j["side"] == side]
        if js and js[0].get("chain_type") == "leg":
            leg_end[key] = rc.DEF + sorted(js, key=lambda j: j["index"])[-1]["name"]
    root_def = rc.DEF + next(j["name"] for j in data["joints"] if j["parent"] is None)
    ad = rig.animation_data or rig.animation_data_create()
    saved_action = ad.action
    report, defects = {}, []
    snaps = []
    out_dir = pc.project_root(mpath) / "renders" / "anim"
    out_dir.mkdir(parents=True, exist_ok=True)
    try:
        for clip in wanted:
            rec = anims.get(clip)
            act = bpy.data.actions.get(rec["action"]) if rec else None
            if act is None:
                defects.append(("error", f"clip {clip}: action missing", []))
                continue
            rc.assign_action(rig, act)
            s, e = rec["frames"]
            frames = list(range(s, e + 1))
            bones = list(set(leg_end.values()) | {root_def}) + [rc.DEF + j["name"] for j in data["joints"]]
            smp = sample(rig, scene, frames, sorted(set(bones)))
            jumps, hits = control_checks(act, rig)
            r = {"frames": [s, e], "euler_jumps": jumps[:10], "limit_hits": dict(list(hits.items())[:10])}
            if rec.get("loop"):
                worst_pose, worst_vel = 0.0, 0.0
                for b, seq in smp.items():
                    q0, q1 = seq[0][0].to_quaternion(), seq[-1][0].to_quaternion()
                    worst_pose = max(worst_pose, math.degrees(q0.rotation_difference(q1).angle))
                    if len(seq) > 2:
                        v0 = q0.rotation_difference(seq[1][0].to_quaternion()).angle
                        v1 = seq[-2][0].to_quaternion().rotation_difference(q1).angle
                        worst_vel = max(worst_vel, math.degrees(abs(v0 - v1)))
                r["loop_pose_error_deg"] = round(worst_pose, 3)
                r["loop_velocity_error_deg_per_frame"] = round(worst_vel, 3)
                if worst_pose > 0.5:
                    defects.append(("warning", f"clip {clip}: loop pose mismatch {worst_pose:.2f} deg", []))
            fps = rec.get("fps", scene.render.fps)
            v = float(rec.get("speed_mps", 0.0)) if rec.get("in_place") else 0.0
            feet = {}
            for key, bone in leg_end.items():
                seq = [m[1] for m in smp[bone]]
                rest_z = (rig.matrix_world @ rig.data.bones[bone].tail_local).z
                slides = []
                for i in range(1, len(seq)):
                    if seq[i].z <= rest_z + contact_h and seq[i - 1].z <= rest_z + contact_h:
                        dx = seq[i].x - seq[i - 1].x
                        dy = (seq[i].y - seq[i - 1].y) - v / fps  # world forward is -Y
                        slides.append(math.hypot(dx, dy) * 100)
                if slides:
                    feet[key] = {"contact_frames": len(slides) + 1, "max_cm_per_frame": round(max(slides), 3),
                                 "mean_cm_per_frame": round(sum(slides) / len(slides), 3)}
                    if max(slides) > slide_lim:
                        defects.append(("warning", f"clip {clip}: foot {key} slides {max(slides):.2f} cm/frame", []))
            r["feet"] = feet
            root_seq = smp[root_def]
            r["root_motion_m"] = round(max((m[0].translation - root_seq[0][0].translation).length for m in root_seq), 4)
            if r["root_motion_m"] > 1e-3:
                defects.append(("warning", f"clip {clip}: DEF-root moves {r['root_motion_m']} m (Roblox clips should be in place)", []))
            if jumps:
                defects.append(("warning", f"clip {clip}: Euler jumps on {len(jumps)} controls", jumps[:10]))
            if hits:
                defects.append(("info", f"clip {clip}: {len(hits)} channels exceed joint limits (clamped)", []))
            report[clip] = r
            if int(params.get("snapshots") or 0) > 0:
                snaps += [pc.to_rel(mpath, p) for p in snapshot(scene, rig, clip, frames, out_dir, int(params["snapshots"]))]
        if "Takeoff" in anims and "Fly" in anims and bpy.data.actions.get(anims["Takeoff"]["action"]) \
                and bpy.data.actions.get(anims["Fly"]["action"]):
            vals = {}
            for clip, frame in (("Takeoff", anims["Takeoff"]["frames"][1]), ("Fly", anims["Fly"]["frames"][0])):
                act = bpy.data.actions[anims[clip]["action"]]
                vals[clip] = {(fc.data_path, fc.array_index): fc.evaluate(frame) for fc in rc.all_fcurves(act)}
            keys = set(vals["Takeoff"]) | set(vals["Fly"])
            diff = max((abs(vals["Takeoff"].get(k, 0.0) - vals["Fly"].get(k, 0.0)) for k in keys), default=0.0)
            report["_transition_takeoff_fly_max_diff"] = round(diff, 4)
            if diff > 0.02:
                defects.append(("warning", f"Takeoff end differs from Fly start by {diff:.3f} (rad or m)", []))
    finally:
        ad.action = saved_action
    dsum = pc.sync_stage_defects(data, STAGE, defects)
    log.dump("details", report)
    pc.set_stage(data, STAGE, "done", {"clips": list(report), "defects": dsum}, pc.to_rel(mpath, log.path))
    pc.save_manifest(mpath, data)
    log.close()
    return {"stage": STAGE, "clips": report, "defects": [d[1] for d in defects[:8]], "snapshots": snaps}


def main() -> None:
    p = pc.base_parser(__doc__)
    p.add_argument("--clips")
    p.add_argument("--snapshots", type=int, default=0)
    p.add_argument("--contact-height", type=float)
    p.add_argument("--slide-limit-cm", type=float)
    pc.cli_entry(run, p)


if __name__ == "__main__":
    main()
