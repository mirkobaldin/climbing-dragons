"""Stages `coarse_model` / `refine`: build procedural anatomical components in Blender.

Despite the file name, nothing is dragon-specific: everything comes from the
anatomy config (default config/dragon_anatomy.json, template in assets/).

Background:
  python run_stage.py run build_dragon --manifest P -- [--stage coarse_model|refine]
         [--only key1,key2] [--detail 1.0] [--force] [--landmarks auto|config]
Interactive (MCP execute_blender_code):
  import sys; sys.path.insert(0, r"<skill>/scripts"); import importlib, build_dragon
  importlib.reload(build_dragon); result = build_dragon.run({"manifest": r"<P>", "only": "skull"})

Idempotent: objects are updated in place by stable name. Per object it skips
(a) approved components, (b) meshes edited by hand since the last build,
(c) unchanged generator output - unless --force. Removes stale generated objects
of rebuilt components only. Saves a checkpoint before replacing existing geometry.

STATUS: implemented, untested.
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402

GENERATOR = "build_dragon@1.0.0"
ROLE_COLLECTION = {"skull": "Head", "jaw": "Head", "tooth": "Head", "horn": "Head",
                   "vertebra": "Spine", "rib": "Ribs", "pelvis": "Pelvis", "limb_bone": "Limbs",
                   "claw": "Limbs", "wing_bone": "Wings", "membrane": "Wings", "other_rigid": "Other"}


def _src_hash(part) -> str:
    h = hashlib.sha1()
    for v in part["verts"]:
        h.update(("%.5f,%.5f,%.5f;" % (v[0], v[1], v[2])).encode())
    for f in part["faces"]:
        h.update(str(f).encode())
    return h.hexdigest()[:16]


def mesh_hash(mesh) -> str:
    import numpy as np
    co = np.empty(len(mesh.vertices) * 3, dtype=np.float32)
    mesh.vertices.foreach_get("co", co)
    lv = np.empty(len(mesh.loops), dtype=np.int32)
    mesh.loops.foreach_get("vertex_index", lv)
    h = hashlib.sha1(co.tobytes())
    h.update(lv.tobytes())
    return h.hexdigest()[:16]


def collect_landmarks(mpath, data, cfg, mode):
    """config < manifest (complete triangulated) < scene LM_* empties."""
    import bpy
    coords = {k: list(v) for k, v in cfg.get("landmarks", {}).items()}
    src = {k: "config" for k in coords}
    if mode == "auto":
        for k, v in data.get("landmarks", {}).items():
            if v.get("complete", True) and v.get("source") in ("reference_triangulation", "scene_edit"):
                coords[k], src[k] = list(v["co"]), v["source"]
        for obj in bpy.data.objects:
            if obj.type == "EMPTY" and obj.name.startswith("LM_"):
                name = obj.name[3:]
                co = list(obj.matrix_world.translation)
                written = obj.get("rbx_written_co")
                if written is None or max(abs(a - b) for a, b in zip(co, written)) > 1e-5:
                    coords[name], src[name] = co, "scene_edit"
                    data.setdefault("landmarks", {})[name] = {"co": [round(c, 5) for c in co],
                                                              "source": "scene_edit", "complete": True}
    return coords, src


def ensure_material(prefix, group):
    import bpy
    name = f"MAT_{prefix}_{group}"
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        mat.name = name
    return mat


def build_mesh(part, name):
    import bpy
    mesh = bpy.data.meshes.new(name + "__new")
    mesh.from_pydata([tuple(v) for v in part["verts"]], [], [tuple(f) for f in part["faces"]])
    mesh.validate(clean_customdata=False)
    uv = mesh.uv_layers.new(name="UVMap")
    flat = [c for face in part["uvs"] for corner in face for c in corner]
    if len(flat) == 2 * len(mesh.loops):
        uv.data.foreach_set("uv", flat)
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mesh.update()
    return mesh


def run(params: dict) -> dict:
    import bpy
    from mathutils import Vector  # noqa: F401  (ensures mathutils present)
    import anatomy_lib as al

    pc.require_blender()
    mpath, data = pc.load_manifest(params["manifest"])
    stage = params.get("stage") or "coarse_model"
    pc.check_retry_budget(data, stage)
    pc.ensure_working_blend(mpath, data, adopt_current=bool(params.get("adopt_current")))
    pc.ensure_object_mode()
    cfg_path = pc.to_abs(mpath, params.get("config") or data["paths"]["anatomy_config"])
    cfg = pc.load_json(cfg_path, "Anatomy config")
    prefix = cfg.get("name_prefix", "CRT")
    detail = float(params.get("detail") or cfg.get("detail", 1.0))
    log = pc.StageLog(mpath, stage)
    pc.set_stage(data, stage, "running")

    coords, lm_src = collect_landmarks(mpath, data, cfg, params.get("landmarks") or "auto")
    lm = al.Landmarks(coords)
    try:
        joints, chains = al.resolve_joints(cfg["joints"], lm)
    except (al.AnatomyError, KeyError) as exc:
        raise pc.PipelineError(f"Joint definition error: {exc}") from exc

    def name_fn(base, side):
        return f"{prefix}_{base}" + (f"_{side}" if side else "")

    ctx = {"detail": detail, "chains": chains, "components": cfg["components"], "name": name_fn}
    only = set(pc.csv_list(params.get("only")))
    force = bool(params.get("force"))
    approved = {c["name"] for c in data.get("components", []) if c.get("approved")}
    root_col = pc.ensure_collection(f"{prefix}_Model")
    existing = [o for o in bpy.data.objects if o.get("rbx_generator", "").startswith("build_dragon")]
    if existing and not params.get("no_checkpoint"):
        ckpt = pc.save_checkpoint(mpath, data, stage, f"before {stage}")
        log.write("checkpoint", ckpt["path"])

    role_groups = cfg.get("material_groups", {"Bone": {"roles": [r for r in ROLE_COLLECTION if r != "membrane"]},
                                              "Membrane": {"roles": ["membrane"]}})
    export_groups = cfg.get("export_groups", {"Skeleton": {"roles": [r for r in ROLE_COLLECTION if r != "membrane"]},
                                              "WingMembrane": {"roles": ["membrane"]}})

    def group_for(role, table):
        for g, spec in table.items():
            if role in spec.get("roles", []):
                return g
        return next(iter(table))

    built, skipped, errors, produced = [], {"approved": [], "manual_edit": [], "unchanged": []}, [], {}
    for key, spec in cfg["components"].items():
        if spec.get("enabled", True) is False:
            continue
        if only and key not in only:
            continue
        try:
            parts = al.generate_component(key, spec, lm, ctx)
        except (al.AnatomyError, KeyError, ValueError, ZeroDivisionError) as exc:
            errors.append(f"{key}: {exc}")
            continue
        produced[key] = {p["name"] for p in parts}
        for part in parts:
            name = part["name"]
            obj = bpy.data.objects.get(name)
            src = _src_hash(part)
            if obj is not None and not force:
                if name in approved:
                    skipped["approved"].append(name)
                    continue
                if obj.type == "MESH" and obj.get("rbx_mesh_hash") and mesh_hash(obj.data) != obj["rbx_mesh_hash"]:
                    skipped["manual_edit"].append(name)
                    continue
                if obj.get("rbx_src_hash") == src:
                    skipped["unchanged"].append(name)
                    continue
            col = pc.ensure_collection(f"{prefix}_{ROLE_COLLECTION.get(part['role'], 'Other')}", root_col)
            obj = pc.upsert_mesh_object(name, build_mesh(part, name), col)
            mat = ensure_material(prefix, group_for(part["role"], role_groups))
            if len(obj.data.materials) == 0:
                obj.data.materials.append(mat)
            else:
                obj.data.materials[0] = mat
            obj["rbx_generator"] = GENERATOR
            obj["rbx_component"] = key
            obj["rbx_role"] = part["role"]
            obj["rbx_side"] = part["side"]
            obj["rbx_bone_hint"] = part["bone_hint"]
            obj["rbx_export_group"] = group_for(part["role"], export_groups)
            obj["rbx_material_group"] = group_for(part["role"], role_groups)
            obj["rbx_src_hash"] = src
            for k, v in part["props"].items():
                obj[f"rbx_{k}" if not k.startswith("rbx_") else k] = v
            if part["role"] == "membrane":
                mod = obj.modifiers.get("RBX_Solidify") or obj.modifiers.new("RBX_Solidify", "SOLIDIFY")
                mod.name = "RBX_Solidify"
                mod.thickness = float(part["props"].get("thickness", 0.012))
                mod.offset = 0.0
                mod.use_even_offset = True
                mod.use_rim = True
            obj["rbx_mesh_hash"] = mesh_hash(obj.data)
            built.append(name)

    removed = []
    for key, names in produced.items():
        for obj in list(bpy.data.objects):
            if obj.get("rbx_component") == key and obj.get("rbx_generator", "").startswith("build_dragon") \
                    and obj.name not in names and obj.name not in approved:
                mesh = obj.data
                bpy.data.objects.remove(obj)
                if mesh is not None and mesh.users == 0:
                    bpy.data.meshes.remove(mesh)
                removed.append(key)

    comps = {c["name"]: c for c in data.get("components", [])}
    dg = bpy.context.evaluated_depsgraph_get()
    for obj in bpy.data.objects:
        if not obj.get("rbx_generator", "").startswith("build_dragon"):
            continue
        prev = comps.get(obj.name, {})
        ev = obj.evaluated_get(dg)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        tris = len(me.loop_triangles)  # includes modifiers such as RBX_Solidify
        ev.to_mesh_clear()
        entry = {"name": obj.name, "key": obj["rbx_component"], "role": obj["rbx_role"], "side": obj["rbx_side"],
                 "bone_hint": obj.get("rbx_bone_hint", ""), "export_group": obj.get("rbx_export_group", ""),
                 "material_group": obj.get("rbx_material_group", ""), "tris": int(tris),
                 "approved": bool(prev.get("approved", False)), "source": "procedural"}
        if obj.get("rbx_influences"):
            entry["influences"] = list(obj["rbx_influences"])
        comps[obj.name] = entry
    data["components"] = sorted((c for c in comps.values() if bpy.data.objects.get(c["name"])),
                                key=lambda c: c["name"])
    data["joints"] = joints
    data["paths"]["anatomy_config"] = pc.to_rel(mpath, cfg_path)

    defects = [("error", e, []) for e in errors]
    if skipped["manual_edit"]:
        defects.append(("info", "components edited by hand were kept (use --force to regenerate)",
                        skipped["manual_edit"]))
    unused = sorted(set(coords) - lm.used)
    pc.sync_stage_defects(data, stage, defects)
    summary = {"built": len(built), "skipped": {k: len(v) for k, v in skipped.items()},
               "removed_stale": len(removed), "errors": len(errors), "joints": len(joints),
               "components_total": len(data["components"]), "detail": detail,
               "landmark_sources": {s: sum(1 for v in lm_src.values() if v == s) for s in set(lm_src.values())}}
    log.dump("details", {"built": built, "skipped": skipped, "removed": removed, "errors": errors,
                         "unused_landmarks": unused})
    pc.set_stage(data, stage, "failed" if errors else "done", summary, pc.to_rel(mpath, log.path),
                 pc.fingerprint([cfg_path], {"detail": detail, "only": sorted(only)}))
    for c in ("silhouette_compare", "mesh_audit", "uv_pbr", "handoff"):
        if built and data["stages"].get(c, {}).get("status") in ("done", "approved"):
            pc.set_stage(data, c, "stale")
    saved = pc.save_working(mpath, data, params.get("save"))
    pc.save_manifest(mpath, data)
    log.close()
    return {"ok": not errors, "stage": stage, **summary, "errors_first": errors[:5], "saved_blend": saved,
            "log": pc.to_rel(mpath, log.path)}


def main() -> None:
    p = pc.base_parser(__doc__)
    p.add_argument("--stage", choices=("coarse_model", "refine"), default="coarse_model")
    p.add_argument("--config", help="Anatomy config path (default: manifest paths.anatomy_config)")
    p.add_argument("--only", help="Comma-separated component keys to (re)build")
    p.add_argument("--detail", type=float, help="Resolution multiplier for rings/stations")
    p.add_argument("--landmarks", choices=("auto", "config"), default="auto")
    p.add_argument("--no-checkpoint", action="store_true")
    pc.cli_entry(run, p)


if __name__ == "__main__":
    main()
