"""Stage `uv_pbr`: UV atlases per material group, procedural PBR materials, and
Cycles bakes to Roblox SurfaceAppearance-compatible maps.

  python run_stage.py run prepare_uv_materials --manifest P -- [--groups Bone,Membrane]
         [--keep-uv] [--no-bake] [--device CPU|GPU] [--estimate-color VIEW]

Per material group (manifest component.material_group):
  UV  : procedural components already carry UVs ("UVMap"); objects without one get
        Smart UV Project. Then average island scale + pack all group objects into
        one atlas (multi-object edit mode). --keep-uv skips packing.
  MAT : MAT_<prefix>_<group> with stable node names (RBX_*), a procedural branch
        (noise-varied base color, roughness, metalness, bump) and a baked branch
        (image textures + tangent-space Normal Map node).
  BAKE: color = DIFFUSE with only the COLOR pass (no lighting baked in);
        roughness = ROUGHNESS; metalness = EMIT via a temporary emission link;
        normal = high->low (selected-to-active) for objects with a "<name>_HP"
        object, otherwise the procedural bump of the low-poly itself.
        Blender bakes OpenGL (+Y) tangent normals = Roblox convention.
Outputs textures/<group>_<map>.png, manifest.textures. Images are capped at 1024 px
(Roblox in-experience maximum, see references/uv-pbr-roblox.md).

--estimate-color VIEW: median chroma inside the reference mask with brightness
normalised to a target value; stored as an APPROXIMATION and only applied when
--apply-estimate is given. It cannot remove baked-in reference lighting fully.

STATUS: implemented, untested.
"""
from __future__ import annotations

import colorsys
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402

STAGE = "uv_pbr"
MAPS = ("color", "roughness", "metalness", "normal")
MAX_PX = 1024


def _node(nt, idname, name, loc):
    n = nt.nodes.get(name)
    if n is None or n.bl_idname != idname:
        if n is not None:
            nt.nodes.remove(n)
        n = nt.nodes.new(idname)
        n.name = name
        n.label = name
    n.location = loc
    return n


def _link(nt, out_sock, in_sock):
    for l in list(in_sock.links):
        nt.links.remove(l)
    nt.links.new(out_sock, in_sock)


def build_material(mat, g: dict, images: dict):
    mat.use_nodes = True
    nt = mat.node_tree
    out = _node(nt, "ShaderNodeOutputMaterial", "RBX_Out", (900, 0))
    for n in list(nt.nodes):  # remove the default Principled created with the material
        if not n.name.startswith("RBX_"):
            nt.nodes.remove(n)
    tc = _node(nt, "ShaderNodeTexCoord", "RBX_TexCoord", (-900, 200))
    noise = _node(nt, "ShaderNodeTexNoise", "RBX_Noise", (-700, 200))
    noise.inputs["Scale"].default_value = float(g.get("noise_scale", 15.0))
    noise.inputs["Detail"].default_value = float(g.get("noise_detail", 4.0))
    _link(nt, tc.outputs["Object"], noise.inputs["Vector"])
    ramp = _node(nt, "ShaderNodeValToRGB", "RBX_Ramp", (-450, 250))
    base = g.get("base_color", [0.8, 0.75, 0.65])
    var = float(g.get("color_variation", 0.1))
    ramp.color_ramp.elements[0].color = (*[max(0.0, c * (1 - var)) for c in base], 1.0)
    ramp.color_ramp.elements[1].color = (*[min(1.0, c * (1 + var)) for c in base], 1.0)
    _link(nt, noise.outputs["Fac"], ramp.inputs["Fac"])
    bump = _node(nt, "ShaderNodeBump", "RBX_Bump", (-450, -150))
    bump.inputs["Strength"].default_value = float(g.get("bump_strength", 0.2))
    _link(nt, noise.outputs["Fac"], bump.inputs["Height"])
    metal = _node(nt, "ShaderNodeValue", "RBX_MetalValue", (-450, -20))
    metal.outputs[0].default_value = float(g.get("metalness", 0.0))
    proc = _node(nt, "ShaderNodeBsdfPrincipled", "RBX_BSDF_Proc", (-100, 200))
    _link(nt, ramp.outputs["Color"], proc.inputs["Base Color"])
    proc.inputs["Roughness"].default_value = float(g.get("roughness", 0.6))
    _link(nt, metal.outputs[0], proc.inputs["Metallic"])
    _link(nt, bump.outputs["Normal"], proc.inputs["Normal"])
    emit = _node(nt, "ShaderNodeEmission", "RBX_Emit", (-100, -300))
    baked = _node(nt, "ShaderNodeBsdfPrincipled", "RBX_BSDF_Baked", (500, -200))
    texn = {}
    for i, m in enumerate(MAPS):
        t = _node(nt, "ShaderNodeTexImage", f"RBX_Tex_{m}", (100, -150 - 260 * i))
        t.image = images[m]
        texn[m] = t
    nm = _node(nt, "ShaderNodeNormalMap", "RBX_NormalMap", (300, -900))
    nm.space = "TANGENT"
    nm.uv_map = "UVMap"
    _link(nt, texn["color"].outputs["Color"], baked.inputs["Base Color"])
    _link(nt, texn["roughness"].outputs["Color"], baked.inputs["Roughness"])
    _link(nt, texn["metalness"].outputs["Color"], baked.inputs["Metallic"])
    _link(nt, texn["normal"].outputs["Color"], nm.inputs["Color"])
    _link(nt, nm.outputs["Normal"], baked.inputs["Normal"])
    return nt, {"out": out, "proc": proc, "baked": baked, "emit": emit, "metal": metal, "tex": texn}


def _image(name, size, non_color, fill):
    import bpy
    img = bpy.data.images.get(name)
    if img is None or tuple(img.size) != (size, size):
        if img is not None:
            bpy.data.images.remove(img)
        img = bpy.data.images.new(name, size, size, alpha=False, float_buffer=False)
        img.name = name
    img.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    img.generated_color = fill
    return img


def _select_only(objs, active):
    import bpy
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


def _pack(objs, margin, angle_deg):
    import bpy
    import math
    no_uv = [o for o in objs if o.data.uv_layers.get("UVMap") is None]
    for o in no_uv:
        o.data.uv_layers.new(name="UVMap")
        o.data.uv_layers.active = o.data.uv_layers["UVMap"]
        _select_only([o], o)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(angle_deg), island_margin=margin)
        bpy.ops.object.mode_set(mode="OBJECT")
    for o in objs:
        o.data.uv_layers.active = o.data.uv_layers["UVMap"]
    _select_only(objs, objs[0])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(rotate=True, margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")
    return len(no_uv)


def estimate_color(mpath, data, view_name, target_value):
    import numpy as np
    import render_compare as rc
    ann = pc.load_json(pc.to_abs(mpath, data["paths"]["reference_annotations"]), "Reference annotations")
    view = ann["views"].get(view_name)
    if view is None:
        raise pc.PipelineError(f"View {view_name!r} not in annotations")
    mask = rc.reference_mask(mpath, view)
    if mask is None:
        raise pc.PipelineError(f"View {view_name!r} has no mask; color estimation needs one")
    rgba, w, h = rc._load_rgba(pc.to_abs(mpath, view["image"]))
    mask = rc._resize_nearest(mask, w, h)
    px = rgba[..., :3][mask]
    if len(px) < 50:
        raise pc.PipelineError("Mask covers too few pixels for a color estimate")
    med = np.median(px, axis=0)
    hh, ss, _ = colorsys.rgb_to_hsv(*[float(c) for c in med])
    est = colorsys.hsv_to_rgb(hh, ss * 0.85, float(target_value))
    return [round(c, 4) for c in est], [round(float(c), 4) for c in med]


def run(params: dict) -> dict:
    import bpy
    pc.require_blender()
    mpath, data = pc.load_manifest(params["manifest"])
    pc.check_retry_budget(data, STAGE)
    pc.ensure_working_blend(mpath, data, adopt_current=bool(params.get("adopt_current")))
    pc.ensure_object_mode()
    mcfg = pc.load_json(pc.to_abs(mpath, data["paths"]["materials_config"]), "Materials config")
    acfg = pc.load_json(pc.to_abs(mpath, data["paths"]["anatomy_config"]), "Anatomy config")
    prefix = acfg.get("name_prefix", "CRT")
    log = pc.StageLog(mpath, STAGE)
    groups: dict[str, list] = {}
    for c in data.get("components", []):
        o = bpy.data.objects.get(c["name"])
        if o is not None and o.type == "MESH":
            groups.setdefault(c.get("material_group") or "Default", []).append(o)
    wanted = set(pc.csv_list(params.get("groups")))
    if wanted:
        groups = {k: v for k, v in groups.items() if k in wanted}
    if not groups:
        raise pc.PipelineError("No component objects found for the requested material groups.")
    ck = pc.save_checkpoint(mpath, data, STAGE, "before uv/pbr")
    log.write("checkpoint", ck["path"])
    estimate = None
    if params.get("estimate_color"):
        tv = mcfg.get("estimate_from_reference", {}).get("target_value", 0.7)
        est, raw = estimate_color(mpath, data, params["estimate_color"], tv)
        estimate = {"view": params["estimate_color"], "estimated_base_color": est, "raw_median": raw,
                    "approximation": True, "applied": bool(params.get("apply_estimate"))}
        data["materials_estimate"] = estimate
    scene = bpy.context.scene
    device = pc.configure_cycles_device(scene, params.get("device") or mcfg.get("bake", {}).get("device", "CPU"))
    bake = mcfg.get("bake", {})
    scene.cycles.samples = int(bake.get("samples", 16))
    uvc = mcfg.get("uv", {})
    tex_entries = [t for t in data.get("textures", []) if t["material_group"] not in groups]
    report = {}
    for gname, objs in groups.items():
        g = dict(mcfg.get("groups", {}).get(gname, {}))
        if estimate and estimate["applied"] and g.get("use_estimate", True):
            g["base_color"] = estimate["estimated_base_color"]
        res = g.get("resolution", {})
        sizes = {m: min(MAX_PX, int(res.get(m, 512))) for m in MAPS}
        images = {
            "color": _image(f"IMG_{prefix}_{gname}_color", sizes["color"], False, (0.5, 0.5, 0.5, 1)),
            "roughness": _image(f"IMG_{prefix}_{gname}_roughness", sizes["roughness"], True, (0.5, 0.5, 0.5, 1)),
            "metalness": _image(f"IMG_{prefix}_{gname}_metalness", sizes["metalness"], True, (0, 0, 0, 1)),
            "normal": _image(f"IMG_{prefix}_{gname}_normal", sizes["normal"], True, (0.5, 0.5, 1.0, 1)),
        }
        mat = bpy.data.materials.get(f"MAT_{prefix}_{gname}") or bpy.data.materials.new(f"MAT_{prefix}_{gname}")
        mat.name = f"MAT_{prefix}_{gname}"
        nt, nodes = build_material(mat, g, images)
        for o in objs:
            if len(o.data.materials) == 0:
                o.data.materials.append(mat)
            else:
                o.data.materials[0] = mat
        packed_new = 0
        if not params.get("keep_uv"):
            packed_new = _pack(objs, float(uvc.get("island_margin", 0.004)), float(uvc.get("smart_angle_deg", 66)))
        greport = {"objects": len(objs), "smart_projected": packed_new, "sizes": sizes, "baked": []}
        if not params.get("no_bake"):
            margin = int(bake.get("margin_px", 8))
            _link(nt, nodes["proc"].outputs["BSDF"], nodes["out"].inputs["Surface"])
            _select_only(objs, objs[0])

            def bake_map(m, **kw):
                nt.nodes.active = nodes["tex"][m]
                bpy.ops.object.bake(target="IMAGE_TEXTURES", save_mode="INTERNAL", margin=margin,
                                    uv_layer="UVMap", **kw)
                greport["baked"].append(m)

            bake_map("color", type="DIFFUSE", pass_filter={"COLOR"}, use_clear=True)
            bake_map("roughness", type="ROUGHNESS", use_clear=True)
            _link(nt, nodes["metal"].outputs[0], nodes["emit"].inputs["Color"])
            _link(nt, nodes["emit"].outputs["Emission"], nodes["out"].inputs["Surface"])
            bake_map("metalness", type="EMIT", use_clear=True)
            _link(nt, nodes["proc"].outputs["BSDF"], nodes["out"].inputs["Surface"])
            hp = {o.name: bpy.data.objects.get(o.name + "_HP") for o in objs}
            lows = [o for o in objs if hp[o.name] is None]
            images["normal"].generated_color = (0.5, 0.5, 1.0, 1.0)
            if lows:
                _select_only(lows, lows[0])
                bake_map("normal", type="NORMAL", normal_space="TANGENT", use_clear=True)
            highs = [o for o in objs if hp[o.name] is not None]
            for i, o in enumerate(highs):
                _select_only([hp[o.name], o], o)
                nt.nodes.active = nodes["tex"]["normal"]
                bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", use_selected_to_active=True,
                                    cage_extrusion=float(bake.get("cage_extrusion", 0.02)),
                                    use_clear=(i == 0 and not lows), target="IMAGE_TEXTURES",
                                    save_mode="INTERNAL", margin=margin, uv_layer="UVMap")
            greport["high_to_low_objects"] = len(highs)
            _link(nt, nodes["baked"].outputs["BSDF"], nodes["out"].inputs["Surface"])
            for m, img in images.items():
                path = pc.project_root(mpath) / "textures" / f"{gname}_{m}.png"
                path.parent.mkdir(parents=True, exist_ok=True)
                img.filepath_raw = str(path)
                img.file_format = "PNG"
                img.save()
                img.filepath = str(path)
                origin = "high_to_low_bake" if (m == "normal" and highs) else "procedural_bake"
                if m == "color" and estimate and estimate["applied"]:
                    origin = "image_estimate_approximation"
                tex_entries.append({"material_group": gname, "map": m, "path": pc.to_rel(mpath, path),
                                    "resolution": sizes[m], "color_space": "sRGB" if m == "color" else "Non-Color",
                                    "normal_convention": "OpenGL" if m == "normal" else "n/a", "origin": origin,
                                    "approximation": origin == "image_estimate_approximation"})
        report[gname] = greport
    data["textures"] = tex_entries
    summary = {"groups": list(report), "device": device, "textures": len(tex_entries),
               "color_estimate": bool(estimate)}
    log.dump("details", report)
    pc.set_stage(data, STAGE, "done", summary, pc.to_rel(mpath, log.path))
    if data["stages"].get("handoff", {}).get("status") in ("done", "approved"):
        pc.set_stage(data, "handoff", "stale")
    saved = pc.save_working(mpath, data, params.get("save"))
    pc.save_manifest(mpath, data)
    log.close()
    return {"stage": STAGE, **summary, "per_group": {k: {"objects": v["objects"], "baked": v["baked"]}
                                                     for k, v in report.items()},
            "estimate": estimate, "saved_blend": saved}


def main() -> None:
    p = pc.base_parser(__doc__)
    p.add_argument("--groups", help="Comma-separated material groups")
    p.add_argument("--keep-uv", action="store_true")
    p.add_argument("--no-bake", action="store_true")
    p.add_argument("--device", choices=("CPU", "GPU"))
    p.add_argument("--estimate-color", help="Reference view used for the base color estimate")
    p.add_argument("--apply-estimate", action="store_true")
    pc.cli_entry(run, p)


if __name__ == "__main__":
    main()
