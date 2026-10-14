# Script CLI reference (roblox-creature-rig-animation)

All scripts are **implemented but untested**. Each prints one `@@RESULT@@{json}` line;
full logs go to `<project>/logs/`. Run Blender stages through
`run_stage.py run <script> --manifest P -- <args>` (background, `--factory-startup`),
or interactively via MCP `execute_blender_code`:
`import sys; sys.path.insert(0, r"<skill>\scripts"); import importlib, X; importlib.reload(X); result = X.run({...})`.
Stdlib scripts (`manifest_tool.py`, `run_stage.py`) run with Blender's bundled
`python.exe` (no system Python on this machine). Exit codes: 0 ok, 1 `ok:false`,
2 actionable error, 3 unexpected exception (`traceback_file`).

Shared tools (`manifest_tool.py`, `run_stage.py`) behave exactly as in the modeling
skill; `manifest_tool.py copy-configs --project DIR` copies this skill's templates
(`rig_config`, `animation_config`, `retarget_bvh`, `retarget_trajectory`) into `config/`.

| Script | Stage | Key options | Result keys (besides `ok`, `stage`, `saved_blend`) |
|---|---|---|---|
| `build_rig.py` | rig_build | `[--allow-unapproved] [--wing-mode fk\|ik_arm]` | `object, deform_bones, control_bones, mechanism_bones, wing_mode, pole_angles{chain: {pole_angle_deg, rest_error_deg}}, rest_drift_m, defects[]` |
| `skin_weights.py` | skinning | `[--only names] [--max-influences 4] [--falloff 2] [--smooth-iterations 8] [--smooth-factor 0.5] [--min-weight 0.02]` | `rigid_components, membranes{name: {bones, max_influences, unweighted}}, problems, problems_first[], settings` |
| `weight_audit.py` | weight_audit | `[--tests a,b] [--no-tests]` | `objects, max_influences, zero_influence_bones, tests[], membrane_tests{test: {mesh: {edge_ratio_min/max, collapsed_faces, overstretched_faces}}}, first_defects[]` |
| `animate_cycles.py` | animation | `[--clips Idle,Walk] [--key-step 2] [--force]` | `clips{name: {channels, keys, loop, speed_mps}}, warnings[]` or `skipped` |
| `retarget.py` | retarget | `--mapping F --clip NAME [--source F] [--frames s,e] [--keep-source]` | `clip, frames, keyed_controls, unsupported_by_source[], root_scale \| source_fps` |
| `curve_audit.py` | curve_audit | `[--clips] [--snapshots N] [--contact-height 0.03] [--slide-limit-cm 0.5]` | `clips{name: {loop_pose_error_deg, loop_velocity_error_deg_per_frame, feet{chain: {max_cm_per_frame, mean_cm_per_frame}}, root_motion_m, euler_jumps[], limit_hits{}}}, defects[], snapshots[]` |
| `bake_export.py` | bake_export | `[--clips] [--keep-export-objects] [--no-embed-textures] [--allow-warnings]` | `files[], meshes{name: {tris, max_influences, unweighted, materials}}, problems[], studio` |

## Manifest keys written by this skill

| Key | Content |
|---|---|
| `rig` | `{object, deform_bones, control_bones, mechanism_bones, ik_chains{chain\|side: {foot, pole}}, wing_mode, pole_angles, limited_joints, rest_drift_m, built_at}` |
| `animations{clip}` | `{action, frames[s,e], fps, loop, source procedural\|retarget_bvh\|retarget_trajectory, in_place, keys, speed_mps?, speed_studs_per_s_estimate?, root_motion_hint?, unsupported_by_source?}` |
| `exports[]` | `{kind rig_mesh\|clip, path, clip?, frames?, fps?, loop?, meshes?, bones?, quaternion_flips_fixed?}` |
| `stages.studio_validation` | set to `pending` by export; only the user (or a real Studio check) may set `done` |

## Files

`export/<id>_rig.fbx` (meshes + skin, rest pose), `export/<id>_<Clip>.fbx` (meshes +
skin + one baked take), `renders/anim/<Clip>_NNNN.png` (snapshots),
`checkpoints/<id>_<stage>_NNN.blend` before rig rebuild, skinning and export.
Actions in the .blend: `ANIM_<Clip>` (controls, editable), `BAKED_<Clip>` (DEF bones,
regenerated on every export — do not edit by hand).
