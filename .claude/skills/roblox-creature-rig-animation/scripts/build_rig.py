"""Stage `rig_build`: armature from manifest.joints + config/rig_config.json.

  python run_stage.py run build_rig --manifest P -- [--allow-unapproved] [--wing-mode fk|ik_arm]

Builds (idempotent: the armature object is kept, its bones are rebuilt):
  DEF-*  deform bones = one per joint, explicit parents, rest roll from pole/up
         hints (local X = main hinge axis), all use_deform, exported later.
  CTRL-* FK controls (Euler, Limit Rotation from joint_limits) for every joint
         not driven by IK, plus CTRL-root, CTRL-torso.
  Legs (chain_type "leg", 3 bones): MCH copies; IK (chain 2) on the middle bone
         to MCH-ankle_tgt (child of CTRL-foot_ik); pole CTRL-pole; lower bone
         Damped-Tracks the foot control. Pole angle is calibrated numerically so the
         rest pose is reproduced. Toes are FK children of the foot control.
  Wings: FK (default) or 2-bone IK on humerus/forearm (--wing-mode ik_arm);
         digits always FK.
  DEF bones follow controls through Copy Transforms (world space), so the
         deform hierarchy stays clean for export.
Requires an approved handoff checkpoint unless --allow-unapproved.

STATUS: implemented, untested.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402
import rig_common as rc  # noqa: E402

STAGE = "rig_build"


def z_reference(joint: dict):
    from mathutils import Vector
    head, tail = Vector(joint["head"]), Vector(joint["tail"])
    d = (tail - head).normalized()
    if joint.get("pole_hint"):
        z = Vector(joint["pole_hint"])
    else:
        z = Vector((0, 0, 1))
        if abs(d.dot(z)) > 0.95:
            z = Vector((0, 1, 0)) if d.z > 0 else Vector((0, -1, 0))
    if abs(d.dot(z.normalized())) > 0.98:
        z = Vector((1, 0, 0))
    return z


PENDING_PARENTS: list[tuple[str, str, bool]] = []


def new_bone(arm, name, head, tail, z_ref, parent=None, deform=False, connect=False, coll=None):
    """Create an edit bone; parenting is deferred (apply_parents) so creation order is free."""
    if arm.edit_bones.get(name) is not None:
        raise pc.PipelineError(f"Duplicate bone name {name!r} (joint names must be unique)")
    eb = arm.edit_bones.new(name)
    eb.name = name
    eb.head, eb.tail = head, tail
    eb.align_roll(z_ref)
    eb.use_deform = deform
    if parent is not None:
        PENDING_PARENTS.append((name, parent, connect))
    if coll is not None:
        coll.assign(eb)
    return eb


def apply_parents(arm):
    for child, parent, connect in PENDING_PARENTS:
        pe = arm.edit_bones.get(parent)
        if pe is None:
            raise pc.PipelineError(f"Bone {child!r}: parent {parent!r} was not created")
        ce = arm.edit_bones[child]
        ce.parent = pe
        ce.use_connect = connect and (pe.tail - ce.head).length < 1e-5
    PENDING_PARENTS.clear()


def calibrate_pole(rig, pb_names, con, view_layer):
    """Pick the pole_angle that best reproduces the rest pose of the IK chain."""
    def err():
        view_layer.update()
        total = 0.0
        for n in pb_names:
            pb = rig.pose.bones[n]
            total += pb.matrix.to_quaternion().rotation_difference(pb.bone.matrix_local.to_quaternion()).angle
        return total
    best = min(range(-180, 180, 15), key=lambda a: (setattr(con, "pole_angle", math.radians(a)), err())[1])
    fine = [best + x * 0.5 for x in range(-30, 31)]
    best = min(fine, key=lambda a: (setattr(con, "pole_angle", math.radians(a)), err())[1])
    con.pole_angle = math.radians(best)
    return best, round(math.degrees(err()), 3)


def run(params: dict) -> dict:
    import bpy
    from mathutils import Vector

    pc.require_blender()
    mpath, data = pc.load_manifest(params["manifest"])
    pc.check_retry_budget(data, STAGE)
    ho = data.get("handoff", {})
    if not ho.get("ready"):
        raise pc.PipelineError("Modeling handoff is not ready (run export_handoff in the modeling skill).")
    approved = any(c["id"] == ho.get("checkpoint") and c.get("approved") for c in data.get("checkpoints", []))
    if not approved and not params.get("allow_unapproved"):
        raise pc.PipelineError(f"Handoff checkpoint {ho.get('checkpoint')} is not approved. Ask the user to run "
                               f"manifest_tool.py approve --checkpoint {ho.get('checkpoint')}.")
    pc.ensure_working_blend(mpath, data, adopt_current=bool(params.get("adopt_current")))
    pc.ensure_object_mode()
    cfg = pc.load_json(pc.to_abs(mpath, data["paths"]["rig_config"]), "Rig config")
    joints = data.get("joints", [])
    if not joints:
        raise pc.PipelineError("manifest.joints is empty.")
    by_name = {j["name"]: j for j in joints}
    wing_mode = params.get("wing_mode") or cfg.get("wing_mode", "fk")
    log = pc.StageLog(mpath, STAGE)

    rig_name = cfg.get("armature_name", "RIG_{creature}").replace("{creature}", data["creature_id"])
    rig = bpy.data.objects.get(rig_name)
    if rig is not None and rig.type != "ARMATURE":
        raise pc.PipelineError(f"{rig_name} exists but is not an armature.")
    if rig is not None:
        ck = pc.save_checkpoint(mpath, data, STAGE, "before rig rebuild")
        log.write("checkpoint", ck["path"])
        if any(abs(v) > 1e-6 for v in rig.location) or any(abs(v) > 1e-6 for v in rig.rotation_euler) \
                or any(abs(v - 1) > 1e-6 for v in rig.scale):
            raise pc.PipelineError(f"{rig_name} has non-identity transforms; Roblox needs frozen transforms. "
                                   "Apply transforms (Ctrl+A) and rerun.")
    else:
        arm_data = bpy.data.armatures.new(rig_name)
        arm_data.name = rig_name
        rig = bpy.data.objects.new(rig_name, arm_data)
        rig.name = rig_name
    col = pc.ensure_collection(f"{data['creature_id']}_Rig")
    pc.link_only_to(rig, col)
    arm = rig.data
    rig.show_in_front = True
    for cname in ("DEF", "CTRL", "MCH"):
        if arm.collections.get(cname) is None:
            arm.collections.new(cname)
    arm.collections["MCH"].is_visible = False
    arm.collections["DEF"].is_visible = False

    leg_chains: dict[str, list[str]] = {}
    for j in joints:
        if j.get("chain_type") == "leg" or (wing_mode == "ik_arm" and j.get("chain_type") == "wing_arm"):
            leg_chains.setdefault(f"{j['chain']}|{j['side']}", []).append(j["name"])
    for key, names in leg_chains.items():
        if not (2 <= len(names) <= 3):
            raise pc.PipelineError(f"IK chain {key} must have 2 or 3 bones, has {len(names)}")
    ik_managed = {n for names in leg_chains.values() for n in names}
    overrides = cfg.get("ctrl_parent_overrides", {"spine_01": "torso"})

    def driver_of(jname: str) -> str:
        return (rc.MCH if jname in ik_managed else rc.CTRL) + jname

    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    PENDING_PARENTS.clear()
    for eb in list(arm.edit_bones):
        arm.edit_bones.remove(eb)
    cdef, cctrl, cmch = arm.collections["DEF"], arm.collections["CTRL"], arm.collections["MCH"]
    root_j = next((j for j in joints if j["parent"] is None), None)
    if root_j is None or root_j["chain_type"] != "root":
        raise pc.PipelineError("The first joint must be the root (chain_type 'root', no parent).")
    if Vector(root_j["head"]).length > 1e-6:
        raise pc.PipelineError("Root joint must start at the origin (Roblox requirement).")
    for j in joints:  # parents precede children in manifest order
        new_bone(arm, rc.DEF + j["name"], Vector(j["head"]), Vector(j["tail"]), z_reference(j),
                 rc.DEF + j["parent"] if j["parent"] else None, True, j.get("connected", False), cdef)
    pelvis = next((j for j in joints if j["chain"] == "pelvis"), None)
    torso_head = Vector(pelvis["head"]) if pelvis else Vector((0, 0, 1))
    new_bone(arm, rc.CTRL + "root", Vector(root_j["head"]), Vector(root_j["tail"]), Vector((0, 0, 1)), None,
             coll=cctrl)
    new_bone(arm, rc.CTRL + "torso", torso_head, torso_head + Vector((0, -0.5, 0)), Vector((0, 0, 1)),
             rc.CTRL + "root", coll=cctrl)
    for j in joints:
        if j is root_j:
            continue
        parent_ctrl = None
        if j["name"] in overrides:
            parent_ctrl = rc.CTRL + overrides[j["name"]]
        elif j["parent"] == root_j["name"]:
            parent_ctrl = rc.CTRL + "torso"
        elif j["parent"]:
            parent_ctrl = driver_of(j["parent"])
        if j["name"] in ik_managed:
            continue
        if j["parent"] and j["parent"] in ik_managed and j.get("chain_type") == "toe":
            parent_ctrl = None  # re-parented to the foot control below
        new_bone(arm, rc.CTRL + j["name"], Vector(j["head"]), Vector(j["tail"]), z_reference(j),
                 parent_ctrl, False, j.get("connected", False) and parent_ctrl is not None
                 and parent_ctrl.startswith(rc.CTRL), cctrl)

    ik_info = {}
    for key, names in leg_chains.items():
        chain, side = key.split("|")
        sfx = "" if side == "C" else f"_{side}"
        first = by_name[names[0]]
        parent_ctrl = driver_of(first["parent"]) if first["parent"] != root_j["name"] else rc.CTRL + "torso"
        if first["name"] in overrides:
            parent_ctrl = rc.CTRL + overrides[first["name"]]
        prev = parent_ctrl
        for i, n in enumerate(names):
            j = by_name[n]
            new_bone(arm, rc.MCH + n, Vector(j["head"]), Vector(j["tail"]), z_reference(j), prev, False,
                     i > 0, cmch)
            prev = rc.MCH + n
        two = len(names) == 2
        end_j = by_name[names[-1]]
        mid_j = by_name[names[1]]
        L = (Vector(end_j["tail"]) - Vector(end_j["head"])).length
        fk = rc.CTRL + f"foot_ik_{chain}{sfx}" if not two else rc.CTRL + f"ik_{chain}{sfx}"
        anchor = Vector(end_j["tail"])
        new_bone(arm, fk, anchor, anchor + Vector((0, -max(L, 0.1) * 0.6, 0)), Vector((0, 0, 1)),
                 rc.CTRL + "root" if not two else rc.CTRL + "torso", coll=cctrl)
        tgt = rc.MCH + f"ankle_tgt_{chain}{sfx}"
        if two:
            tgt = fk
        else:
            ah = Vector(end_j["head"])
            new_bone(arm, tgt, ah, ah + Vector((0, 0, max(L, 0.1) * 0.3)), Vector((0, -1, 0)), fk, coll=cmch)
        upper_len = (Vector(first["tail"]) - Vector(first["head"])).length
        pole_dir = Vector(mid_j.get("pole_hint") or first.get("pole_hint") or (0, -1, 0)).normalized()
        ph = Vector(mid_j["head"]) + pole_dir * upper_len * 1.5
        pole = rc.CTRL + f"pole_{chain}{sfx}"
        new_bone(arm, pole, ph, ph + Vector((0, 0, 0.1)), Vector((0, -1, 0)), rc.CTRL + "torso", coll=cctrl)
        ik_info[key] = {"bones": names, "foot": fk, "target": tgt, "pole": pole, "two_bone": two}
    for j in joints:  # toes whose parent is IK-driven follow the foot control
        if j.get("chain_type") == "toe" and j["parent"] in ik_managed:
            for info in ik_info.values():
                if j["parent"] in info["bones"]:
                    arm.edit_bones[rc.CTRL + j["name"]].parent = arm.edit_bones[info["foot"]]
    apply_parents(arm)
    bpy.ops.object.mode_set(mode="OBJECT")

    euler = cfg.get("euler_order", "XYZ")
    limits = cfg.get("joint_limits", {})
    for pb in rig.pose.bones:  # pose channels survive a same-name rebuild: reset them
        for c in list(pb.constraints):
            pb.constraints.remove(c)
        pb.rotation_mode = euler if pb.name.startswith(rc.CTRL) else "QUATERNION"
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
        for ax in ("x", "y", "z"):
            setattr(pb, f"use_ik_limit_{ax}", False)
            setattr(pb, f"lock_ik_{ax}", False)
    limited = 0
    for j in joints:
        lim = rc.limits_for(j["name"], limits)
        if not lim:
            continue
        if j["name"] in ik_managed:
            pb = rig.pose.bones[rc.MCH + j["name"]]
            for ax in ("x", "y", "z"):
                if ax in lim:
                    lo, hi = lim[ax]
                    if lo == hi == 0:
                        setattr(pb, f"lock_ik_{ax}", True)
                    else:
                        setattr(pb, f"use_ik_limit_{ax}", True)
                        setattr(pb, f"ik_min_{ax}", math.radians(lo))
                        setattr(pb, f"ik_max_{ax}", math.radians(hi))
        else:
            pb = rig.pose.bones.get(rc.CTRL + j["name"])
            if pb is None:
                continue
            con = pb.constraints.new("LIMIT_ROTATION")
            con.name = "RBX_Limit"
            con.owner_space = "LOCAL"
            con.use_transform_limit = True
            for ax in ("x", "y", "z"):
                if ax in lim:
                    setattr(con, f"use_limit_{ax}", True)
                    setattr(con, f"min_{ax}", math.radians(lim[ax][0]))
                    setattr(con, f"max_{ax}", math.radians(lim[ax][1]))
        limited += 1
    pole_angles = {}
    for key, info in ik_info.items():
        names = info["bones"]
        mid = rig.pose.bones[rc.MCH + names[1]]
        con = mid.constraints.new("IK")
        con.name = "RBX_IK"
        con.target, con.subtarget = rig, info["target"]
        con.pole_target, con.pole_subtarget = rig, info["pole"]
        con.chain_count = 2
        con.use_stretch = False
        if not info["two_bone"]:
            low = rig.pose.bones[rc.MCH + names[2]]
            dt = low.constraints.new("DAMPED_TRACK")
            dt.name = "RBX_FootTrack"
            dt.target, dt.subtarget, dt.head_tail = rig, info["foot"], 0.0
            dt.track_axis = "TRACK_Y"
        ang, residual = calibrate_pole(rig, [rc.MCH + n for n in names[:2]], con, bpy.context.view_layer)
        pole_angles[key] = {"pole_angle_deg": ang, "rest_error_deg": residual}
    for j in joints:
        pb = rig.pose.bones[rc.DEF + j["name"]]
        con = pb.constraints.new("COPY_TRANSFORMS")
        con.name = "RBX_Follow"
        con.target, con.subtarget = rig, driver_of(j["name"]) if j is not root_j else rc.CTRL + "root"
    bpy.context.view_layer.update()
    drift = 0.0
    for j in joints:
        pb = rig.pose.bones[rc.DEF + j["name"]]
        drift = max(drift, (pb.matrix.translation - pb.bone.matrix_local.translation).length)
    defects = []
    if drift > 1e-3:
        defects.append(("error", f"rest pose not reproduced by controls (max drift {drift:.4f} m)", []))
    for key, pa in pole_angles.items():
        if pa["rest_error_deg"] > 1.0:
            defects.append(("warning", f"IK chain {key} rest error {pa['rest_error_deg']} deg after pole calibration", []))
    pc.sync_stage_defects(data, STAGE, defects)
    names = [b.name for b in arm.bones]
    rinfo = {"object": rig.name, "deform_bones": sum(1 for n in names if n.startswith(rc.DEF)),
             "control_bones": sum(1 for n in names if n.startswith(rc.CTRL)),
             "mechanism_bones": sum(1 for n in names if n.startswith(rc.MCH)),
             "ik_chains": {k: {kk: v[kk] for kk in ("foot", "pole")} for k, v in ik_info.items()},
             "wing_mode": wing_mode, "pole_angles": pole_angles, "limited_joints": limited,
             "rest_drift_m": round(drift, 6), "built_at": pc.now_iso()}
    data["rig"] = rinfo
    blocking = any(s == "error" for s, _, _ in defects)
    pc.set_stage(data, STAGE, "failed" if blocking else "done",
                 {k: rinfo[k] for k in ("deform_bones", "control_bones", "mechanism_bones", "rest_drift_m")},
                 pc.to_rel(mpath, log.path))
    for s in ("skinning", "weight_audit", "animation", "curve_audit", "bake_export"):
        if data["stages"].get(s, {}).get("status") in ("done", "approved"):
            pc.set_stage(data, s, "stale")
    saved = pc.save_working(mpath, data, params.get("save"))
    pc.save_manifest(mpath, data)
    log.close()
    return {"ok": not blocking, "stage": STAGE, **{k: rinfo[k] for k in (
        "object", "deform_bones", "control_bones", "mechanism_bones", "wing_mode", "pole_angles",
        "rest_drift_m")}, "defects": [d[1] for d in defects], "saved_blend": saved}


def main() -> None:
    p = pc.base_parser(__doc__)
    p.add_argument("--allow-unapproved", action="store_true")
    p.add_argument("--wing-mode", choices=("fk", "ik_arm"))
    pc.cli_entry(run, p)


if __name__ == "__main__":
    main()
