"""Stage `bake_export`: bake controls into DEF-bone animation and export FBX files.

  python run_stage.py run bake_export --manifest P -- [--clips Idle,Walk,Takeoff,Fly]
         [--keep-export-objects] [--no-embed-textures] [--allow-warnings]

Steps (a checkpoint is saved first; source objects are never modified):
 1. For each clip: assign ANIM_<clip>, bake visual transforms of DEF-* bones only
    (bpy_extras.anim_utils.bake_action_objects, visual keying) into BAKED_<clip>,
    fix quaternion sign continuity, restore the control action.
 2. Build an export copy of the rig with DEF-* bones only, no constraints, frozen
    object transforms (Roblox requirement checked).
 3. Per export group: evaluated copies of its components (Solidify applied, Armature
    excluded), joined into <prefix>_<Group>, vertex groups limited to DEF bones,
    <= 4 influences, normalised, Armature modifier on the export rig.
 4. Checks: triangles per mesh <= 20,000, influences <= 4, one material per mesh,
    unique names (bones vs meshes), no root weights.
 5. Export export/<id>_rig.fbx (mesh + skin, rest pose, no animation) and one
    export/<id>_<Clip>.fbx per clip (mesh + skin + one baked take), FBX settings
    from rig_config.fbx (defaults follow Roblox's Blender export guidance).
 6. Remove temporary export objects (unless --keep-export-objects); record exports.
No Roblox Studio validation happens here.

STATUS: implemented, untested.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402
import rig_common as rc  # noqa: E402

STAGE = "bake_export"
MAX_TRIS = 20000
MAX_INFL = 4
FBX_DEFAULTS = {
    "apply_scale_options": "FBX_SCALE_UNITS", "global_scale": 1.0, "axis_forward": "-Z", "axis_up": "Y",
    "add_leaf_bones": False, "use_armature_deform_only": True, "primary_bone_axis": "Y",
    "secondary_bone_axis": "X", "mesh_smooth_type": "FACE", "use_tspace": True, "use_mesh_modifiers": True,
    "path_mode": "COPY", "bake_anim_use_nla_strips": False, "bake_anim_use_all_actions": False,
    "bake_anim_force_startend_keying": False, "bake_anim_simplify_factor": 0.0, "bake_anim_use_all_bones": True,
}


def bake_clip(rig, act, frames):
    import bpy
    from bpy_extras import anim_utils
    rc.assign_action(rig, act)
    for pb in rig.pose.bones:
        pb.select = pb.name.startswith(rc.DEF)
    opts = anim_utils.BakeOptions(only_selected=True, do_pose=True, do_object=False, do_visual_keying=True,
                                  do_constraint_clear=False, do_parents_clear=False, do_clean=False,
                                  do_location=True, do_rotation=True, do_scale=True, do_bbone=False,
                                  do_custom_props=False)
    name = "BAKED_" + act.name.removeprefix("ANIM_")
    old = bpy.data.actions.get(name)
    if old is not None:
        bpy.data.actions.remove(old)
    baked = anim_utils.bake_action_objects([(rig, None)], frames=frames, bake_options=opts)[0]
    baked.name = name
    baked.use_fake_user = True
    flips = rc.fix_quaternion_continuity(baked)
    rc.assign_action(rig, act)
    return baked, flips


def export_rig_copy(rig, col, name):
    import bpy
    old = bpy.data.objects.get(name)
    if old is not None:
        arm = old.data
        bpy.data.objects.remove(old)
        if arm and arm.users == 0:
            bpy.data.armatures.remove(arm)
    exp = rig.copy()
    exp.data = rig.data.copy()
    exp.name = name
    exp.data.name = name
    exp.animation_data_clear()
    col.objects.link(exp)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = exp
    exp.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for eb in list(exp.data.edit_bones):
        if not eb.name.startswith(rc.DEF):
            exp.data.edit_bones.remove(eb)
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in exp.pose.bones:
        for c in list(pb.constraints):
            pb.constraints.remove(c)
        pb.location, pb.rotation_quaternion, pb.scale = (0, 0, 0), (1, 0, 0, 0), (1, 1, 1)
    return exp


def export_mesh(group, comps, exp_rig, col, prefix, dg):
    import bpy
    import numpy as np
    temps = []
    for c in comps:
        src = bpy.data.objects.get(c["name"])
        if src is None:
            raise pc.PipelineError(f"Component {c['name']} missing")
        mod = src.modifiers.get("RBX_Armature")
        was = mod.show_viewport if mod else None
        if mod:
            mod.show_viewport = False
        dg.update()
        ev = src.evaluated_get(dg)
        me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
        if mod:
            mod.show_viewport = was
        tmp = bpy.data.objects.new(f"__exp_{c['name']}", me)
        tmp.matrix_world = src.matrix_world.copy()
        col.objects.link(tmp)
        for vg in src.vertex_groups:  # vertex group names live on the object
            if tmp.vertex_groups.get(vg.name) is None:
                tmp.vertex_groups.new(name=vg.name)
        temps.append(tmp)
    dg.update()
    name = f"{prefix}_{group}"
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for t in temps:
        t.select_set(True)
    bpy.context.view_layer.objects.active = temps[0]
    with bpy.context.temp_override(active_object=temps[0], object=temps[0], selected_objects=temps,
                                   selected_editable_objects=temps):
        bpy.ops.object.join()
    obj = temps[0]
    old = bpy.data.objects.get(name)
    if old is not None and old is not obj:
        bpy.data.objects.remove(old)
    obj.name = name
    obj.data.name = name
    with bpy.context.temp_override(active_object=obj, object=obj, selected_objects=[obj],
                                   selected_editable_objects=[obj]):
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bones = {b.name for b in exp_rig.data.bones}
    for vg in list(obj.vertex_groups):
        if vg.name not in bones:
            obj.vertex_groups.remove(vg)
    with bpy.context.temp_override(active_object=obj, object=obj, selected_objects=[obj],
                                   selected_editable_objects=[obj]):
        bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=MAX_INFL)
        bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    mod = obj.modifiers.new("RBX_Armature", "ARMATURE")
    mod.object = exp_rig
    obj.parent = exp_rig
    obj.matrix_parent_inverse = exp_rig.matrix_world.inverted()
    obj.data.calc_loop_triangles()
    counts = np.zeros(len(obj.data.vertices), dtype=int)
    for v in obj.data.vertices:
        counts[v.index] = sum(1 for g in v.groups if g.weight > 0)
    return obj, {"tris": len(obj.data.loop_triangles), "max_influences": int(counts.max()) if len(counts) else 0,
                 "unweighted": int((counts == 0).sum()), "materials": len({m for m in obj.data.materials if m})}


def fbx_export(path, objs, settings, anim, frames=None):
    import bpy
    scene = bpy.context.scene
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if frames:
        scene.frame_start, scene.frame_end = frames
    kw = dict(FBX_DEFAULTS)
    kw.update(settings)
    bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, object_types={"ARMATURE", "MESH"},
                             bake_anim=anim, **kw)


def run(params: dict) -> dict:
    import bpy
    pc.require_blender()
    mpath, data = pc.load_manifest(params["manifest"])
    pc.check_retry_budget(data, STAGE)
    st = data["stages"]
    if st.get("weight_audit", {}).get("status") not in ("done", "approved"):
        raise pc.PipelineError("weight_audit must be done (and without errors) before export.")
    pc.ensure_working_blend(mpath, data, adopt_current=bool(params.get("adopt_current")))
    pc.ensure_object_mode()
    rig = rc.get_rig(data)
    if any(abs(v) > 1e-6 for v in rig.location) or any(abs(v) > 1e-6 for v in rig.rotation_euler) \
            or any(abs(v - 1) > 1e-6 for v in rig.scale):
        raise pc.PipelineError("Rig object transforms are not frozen (location/rotation 0, scale 1).")
    rcfg = pc.load_json(pc.to_abs(mpath, data["paths"]["rig_config"]), "Rig config")
    acfg = pc.load_json(pc.to_abs(mpath, data["paths"]["anatomy_config"]), "Anatomy config") \
        if pc.to_abs(mpath, data["paths"]["anatomy_config"]).exists() else {}
    prefix = acfg.get("name_prefix", "CRT")
    anims = data.get("animations", {})
    clips = pc.csv_list(params.get("clips")) or list(anims)
    missing = [c for c in clips if c not in anims or bpy.data.actions.get(anims[c]["action"]) is None]
    if missing:
        raise pc.PipelineError(f"Clips without actions: {missing}")
    log = pc.StageLog(mpath, STAGE)
    ck = pc.save_checkpoint(mpath, data, STAGE, "before bake/export")
    log.write("checkpoint", ck["path"])
    scene = bpy.context.scene
    saved_range = (scene.frame_start, scene.frame_end)
    ad = rig.animation_data or rig.animation_data_create()
    saved_action = ad.action
    col = pc.ensure_collection("RBX_EXPORT_TMP")
    out_dir = pc.project_root(mpath) / "export"
    out_dir.mkdir(parents=True, exist_ok=True)
    cid = data["creature_id"]
    baked, problems, mesh_info, exports = {}, [], {}, []
    fbx_settings = rcfg.get("fbx", {})
    try:
        for clip in clips:
            act = bpy.data.actions[anims[clip]["action"]]
            s, e = anims[clip]["frames"]
            b, flips = bake_clip(rig, act, range(int(s), int(e) + 1))
            baked[clip] = (b, flips)
        exp_rig = export_rig_copy(rig, col, f"{cid}_Rig")
        dg = bpy.context.evaluated_depsgraph_get()
        groups = data.get("export_groups") or []
        comps_by = {c["name"]: c for c in data.get("components", [])}
        meshes = []
        for g in groups:
            obj, info = export_mesh(g["name"], [comps_by[n] for n in g["components"]], exp_rig, col, prefix, dg)
            meshes.append(obj)
            mesh_info[obj.name] = info
            if info["tris"] > MAX_TRIS:
                problems.append(f"{obj.name}: {info['tris']} tris > {MAX_TRIS}")
            if info["max_influences"] > MAX_INFL:
                problems.append(f"{obj.name}: {info['max_influences']} influences > {MAX_INFL}")
            if info["unweighted"]:
                problems.append(f"{obj.name}: {info['unweighted']} unweighted vertices")
            if info["materials"] > 1:
                problems.append(f"{obj.name}: {info['materials']} materials (one SurfaceAppearance per MeshPart)")
        bone_names = {b.name for b in exp_rig.data.bones}
        clash = bone_names & {m.name for m in meshes} | ({exp_rig.name} & bone_names)
        if clash:
            problems.append(f"name clash between bones and meshes: {sorted(clash)}")
        root = next(j["name"] for j in data["joints"] if j["parent"] is None)
        for m in meshes:
            if m.vertex_groups.get(rc.DEF + root) is not None:
                problems.append(f"{m.name}: root bone has a vertex group")
        if problems and not params.get("allow_warnings"):
            raise pc.PipelineError("Export blocked: " + "; ".join(problems[:6]))
        embed = not params.get("no_embed_textures")
        exp_rig.data.pose_position = "REST"
        rig_path = out_dir / f"{cid}_rig.fbx"
        fbx_export(rig_path, [exp_rig] + meshes, {**fbx_settings, "embed_textures": embed}, anim=False)
        exports.append({"kind": "rig_mesh", "path": pc.to_rel(mpath, rig_path), "meshes": mesh_info,
                        "bones": len(bone_names), "created_at": pc.now_iso()})
        exp_rig.data.pose_position = "POSE"
        for clip in clips:
            b, flips = baked[clip]
            rc.assign_action(exp_rig, b)
            s, e = anims[clip]["frames"]
            path = out_dir / f"{cid}_{clip}.fbx"
            fbx_export(path, [exp_rig] + meshes, {**fbx_settings, "embed_textures": False}, anim=True,
                       frames=(int(s), int(e)))
            exports.append({"kind": "clip", "clip": clip, "path": pc.to_rel(mpath, path), "frames": [s, e],
                            "fps": anims[clip].get("fps"), "loop": anims[clip].get("loop"),
                            "quaternion_flips_fixed": flips, "created_at": pc.now_iso()})
    finally:
        scene.frame_start, scene.frame_end = saved_range
        ad.action = saved_action
        if not params.get("keep_export_objects"):
            for o in list(col.objects):
                d = o.data
                bpy.data.objects.remove(o)
                if d is not None and d.users == 0:
                    (bpy.data.meshes if o.type == "MESH" else bpy.data.armatures).remove(d)
            bpy.data.collections.remove(col)
    data["exports"] = [x for x in data.get("exports", []) if x.get("kind") not in ("rig_mesh", "clip")] + exports
    pc.sync_stage_defects(data, STAGE, [("warning", p, []) for p in problems])
    pc.set_stage(data, STAGE, "done", {"files": len(exports), "meshes": mesh_info, "problems": len(problems)},
                 pc.to_rel(mpath, log.path))
    pc.set_stage(data, "studio_validation", "pending")
    saved = pc.save_working(mpath, data, params.get("save"))
    pc.save_manifest(mpath, data)
    log.close()
    return {"stage": STAGE, "files": [x["path"] for x in exports], "meshes": mesh_info,
            "problems": problems[:6], "saved_blend": saved,
            "studio": "Not validated in Roblox Studio. Follow references/roblox-export.md (validation scenario 3)."}


def main() -> None:
    p = pc.base_parser(__doc__)
    p.add_argument("--clips")
    p.add_argument("--keep-export-objects", action="store_true")
    p.add_argument("--no-embed-textures", action="store_true")
    p.add_argument("--allow-warnings", action="store_true", help="Export despite failed checks (not recommended)")
    pc.cli_entry(run, p)


if __name__ == "__main__":
    main()
