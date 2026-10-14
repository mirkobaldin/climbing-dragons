# Script CLI reference (roblox-reference-modeling)

All scripts are **implemented but untested**. Every script prints exactly one line
`@@RESULT@@{json}` on stdout; full logs go to `<project>/logs/`. `run_stage.py` strips
Blender noise and prints only that JSON (plus `run_log`, `exit_code`).

## Interpreters

| Kind | How to run |
|---|---|
| stdlib scripts (`manifest_tool`, `run_stage`, `inspect_references`, `image_to_3d_backend`) | any Python ≥ 3.10. On this machine there is no system Python: use Blender's `"C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe"` |
| Blender stage scripts | `python run_stage.py run <script> --manifest P -- <script args>` (background, `--factory-startup`) |
| Interactive (MCP) | `execute_blender_code`: `import sys; sys.path.insert(0, r"<skill>\scripts"); import importlib, X; importlib.reload(X); result = X.run({...})` — keys = CLI option names with `_` (e.g. `{"manifest": r"P", "only": "skull"}`) |

Exit codes: 0 ok, 1 ran with `ok:false`, 2 actionable `PipelineError`, 3 unexpected
exception (`traceback_file` in result). Common result keys: `ok`, `stage`, `error`,
`log`, `saved_blend`, `skipped` + `reason` (inputs unchanged).

Common options of Blender stage scripts: `--manifest P` (required), `--force` (ignore
unchanged-input skip), `--no-save` (default: save in background, never in interactive).

## manifest_tool.py (shared with the rigging skill)

| Command | Arguments | Result keys |
|---|---|---|
| `init` | `--project DIR --creature-id ID [--display-name] [--profile pc_standard]` | `manifest, dirs, configs_copied, next` |
| `copy-configs` | `--project DIR [--overwrite]` | `copied` (only this skill's assets) |
| `validate` | `--manifest P` | `errors[], warnings[], error_count` |
| `status` | `--manifest P` | `stages{}, components, approved_components, joints, open_defects{}, handoff_ready` |
| `set-stage` | `--stage S --status pending\|done\|approved\|stale\|… [--note]` | `stage, status` (pending resets attempts) |
| `add-defect` / `resolve-defect` | `--stage --severity info\|warning\|error\|blocker --description [--objects]` / `--id D001 [--resolution wontfix] [--note]` | `id` |
| `approve` / `unapprove` | `--checkpoint ID` or `--components a,b` or `--all-components` | `changed, unknown` |
| `record-verification` | `--topic --source URL --result TEXT` | `recorded` |
| `check-sync` | `--other-skill DIR` | `files{path: identical\|DIFFERENT}` |

## run_stage.py (shared)

`run_stage.py detect --manifest P [--blender EXE]` → writes `manifest.environment`
`{os, blender_exe, blender_version, blender_python, gpu{name, vram_total_mb, vram_free_mb}}`.

`run_stage.py run SCRIPT --manifest P [--blend F | --no-blend] [--blender EXE] [--timeout 3600] [--user-startup] -- ARGS`
→ the script's result + `run_log`, `exit_code`. `--user-startup` keeps user prefs
(UI language may then translate new datablock names; scripts set names explicitly anyway).

## Stage scripts

| Script | Stage | Key options | Result (besides common keys) |
|---|---|---|---|
| `inspect_references.py` (stdlib) | reference_inspection | `[--annotations F]` | `views, triangulation_views[], landmarks_3d, incomplete, axis_issues, per_view{declared, assessed, usable_for}, top_axis_issues[≤5], registration[{views, axis, scale, offset_m, rms_after_fit_m}], report` |
| `setup_references.py` | reference_setup | `[--depth 3.0] [--overwrite-landmarks]` | `views[], skipped, landmarks_written, landmarks_kept_manual, landmarks_incomplete` |
| `build_dragon.py` | coarse_model / refine | `[--stage refine] [--only k1,k2] [--detail 1.0] [--landmarks auto\|config] [--config F] [--no-checkpoint]` | `built, skipped{approved, manual_edit, unchanged}, removed_stale, errors, errors_first[], joints, components_total, landmark_sources{}` |
| `render_compare.py` | silhouette_compare | `[--views a,b] [--scale 0.5] [--grid 8] [--shaded] [--note T]` | `iteration, mean_iou, delta_vs_previous, per_view{iou, precision, recall, worst[{near_landmark, kind, share}]}, continue_refinement, stop_reason, renders, report` |
| `mesh_audit.py` | mesh_audit | `[--fix safe] [--profile P] [--merge-dist 1e-5] [--no-intersections] [--include-approved]` | `objects, total_tris, group_tris{}, over_role_budgets{}, cross_intersections, fixed, defects{open, auto_resolved}, worst_objects[≤5]` |
| `prepare_uv_materials.py` | uv_pbr | `[--groups Bone] [--keep-uv] [--no-bake] [--device CPU\|GPU] [--estimate-color VIEW [--apply-estimate]]` | `groups[], device, textures, per_group{objects, baked[]}, estimate` |
| `export_handoff.py` | handoff | `[--allow-warnings] [--allow-errors]` | `ready, checkpoint, warnings[], report, next` or `blockers[]` |
| `visual_hull.py` (optional) | visual_hull | `[--views] [--resolution 96] [--allowed-misses 0] [--pad 0.1] [--remesh]` | `views, voxel_size_m, grid, occupied_voxels, volume_m3, faces, object` |
| `setup_image_to_3d.ps1` (Windows, once) | — | `-Project DIR [-Root C:\ai] [-InstallPrereqs]` | writes `config/image_to_3d_backend.json` |
| `image_to_3d_backend.py` (mandatory, stdlib) | image_to_3d | `check\|run --manifest P [--config F] [--image F]` | check: `problems[]`; run: `mesh, log, backend, commit, seconds, vram_base_gb, vram_peak_gb[, warning]` |
| `import_init_mesh.py` | — | `[--file F] [--rotate-deg x,y,z] [--no-fit] [--as-model [--scale-m M]]` | `object, verts, tris, materials, images, fit` |

## Files written per stage

| Stage | Disk | Manifest |
|---|---|---|
| reference_inspection | `reports/reference_inspection.json` | `references[]`, `landmarks{}` (never overwrites `source: scene_edit`) |
| reference_setup | `.blend` objects `REF_*`, `CAM_REF_*`, `LM_*` | stage summary |
| coarse_model/refine | `.blend` `DRG_*` objects, `checkpoints/*_coarse_model_NNN.blend` (before replacing) | `components[]`, `joints[]` |
| silhouette_compare | `renders/iter_NNN/*`, `reports/silhouette_iter_NNN.json` | `stages.silhouette_compare.history[]` |
| mesh_audit | log JSON with per-object results | `components[].tris`, `export_groups[]`, defects |
| uv_pbr | `textures/<group>_<map>.png` | `textures[]`, `materials_estimate` |
| handoff | `checkpoints/*_handoff_NNN.blend`, `reports/geometry_materials_report.md` | `handoff{ready, checkpoint, blend, …}` |
