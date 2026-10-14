---
name: roblox-reference-modeling
description: Builds an editable, reference-guided creature mesh in Blender for Roblox (skeletal dragon as the reference example) - inspects orthographic/perspective references, sets up reference planes, cameras and landmarks, generates procedural anatomical components (skull, jaw, vertebrae, ribs, pelvis, legs, claws, wing bones, membranes), compares silhouettes, audits topology and polygon budgets, bakes PBR maps for SurfaceAppearance and writes a handoff manifest for rigging. Use when the user asks to model a creature from reference images, rebuild or correct creature anatomy, check silhouettes against references, prepare creature UVs/PBR textures for Roblox, or produce the modeling handoff.
disable-model-invocation: true
---

# Roblox reference modeling (creature)

Status: **implemented, untested**. No script has been run end-to-end yet. Say so
in every report until validation scenario 1 passes
([references/validation-plan.md](references/validation-plan.md)).

## Ground rules

- Talk to the user in their language; code, identifiers and files stay in English.
- Verify before assuming: list MCP tools with ToolSearch, read
  [references/verified-sources.md](references/verified-sources.md) only if an API
  fails or the facts look stale. Never invent an MCP tool or bpy API.
- Default path = **procedural anatomy**. Visual hull and image-to-3D are optional
  initialisations, never final anatomy. Never promise fidelity to references.
- Preserve originals: scripts checkpoint before replacing geometry; never delete
  user objects; never merge separate bones or fill anatomical openings.
- Ask before destructive scene changes the scripts do not already guard.
- Do not launch subagents. Do not rerun a stage whose result is `skipped: inputs unchanged`.

## Paths

`SKILL` = this folder (resolve from this file, not the CWD). Scripts:
`SKILL/scripts/`. Project = folder holding `pipeline_manifest.json` (generated
assets live there, never inside the skill). Python for stdlib scripts: Blender's
bundled interpreter, e.g. `C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe`
(no system Python was found on this machine).

Run a Blender stage in background (preferred for batch work):
```
"<py>" "SKILL/scripts/run_stage.py" run <script> --manifest "<project>" -- <args>
```
Use MCP `execute_blender_code` for scene inspection and interactive fixes; call a
script's `run({...})` there instead of pasting geometry code (see
[references/script-cli.md](references/script-cli.md) for every command, option and
result schema — read it when you need an option not shown below).

## Workflow

Track progress only through the manifest (`manifest_tool.py status`). Start each
session with `status`; continue from the first stage not `done`/`approved`.

1. **Project setup**
   `manifest_tool.py init --project <dir> --creature-id <id>` → copies config
   templates into `<dir>/config/`. Then `run_stage.py detect --manifest <dir>`.
   Put reference images in `refs/`. Edit `config/dragon_anatomy.json` (proportions,
   components) and `config/reference_annotations.json`.
2. **Inspect references** — `inspect_references.py --manifest <dir>`.
   Before annotating, read [references/reference-analysis.md](references/reference-analysis.md)
   (view axis table, scale/origin, masks). Report to the user: per view declared vs
   assessed projection, views usable for triangulation, top residuals and the likely
   cause (registration vs pose/proportion mismatch). Ask the user which view to trust
   when poses disagree; do not average inconsistent anatomy silently.
3. **Reference planes, cameras, landmarks** — `run_stage.py run setup_references`.
   The user may move `LM_*` empties in Blender; edits are kept and win over config.
4. **Coarse anatomical model** — `run_stage.py run build_dragon`.
   Read [references/procedural-anatomy.md](references/procedural-anatomy.md) before
   changing component types, joint chains, symmetry, or adding a new generator.
5. **Compare with references** — `run_stage.py run render_compare -- --scale 0.5`.
   Inspect at most 1–2 diff PNGs (`renders/iter_NNN/*_diff.png`; red = model only,
   blue = reference only) and use `worst_regions.near_landmark` to choose fixes.
   IoU measures outlines only; say so.
6. **Refine approved anatomy** — change config values or move `LM_*` empties, then
   `build_dragon -- --stage refine --only <keys>`; re-compare. Stop when
   `continue_refinement` is false (iteration limit or stalled improvement, from
   `manifest.limits`) and ask the user how to proceed. When the user approves parts:
   `manifest_tool.py approve --components <names>` (protected from rebuilds).
7. **Topology and budgets** — `run_stage.py run mesh_audit [-- --fix safe]`.
   Read [references/mesh-quality-topology.md](references/mesh-quality-topology.md)
   before fixing or when budgets are exceeded (retopology ≠ decimation; change
   `--detail` or per-component resolution instead).
8. **UVs and PBR** — `run_stage.py run prepare_uv_materials [-- --device GPU]`.
   Read [references/uv-pbr-roblox.md](references/uv-pbr-roblox.md) for bake methods,
   approximations and the SurfaceAppearance mapping.
9. **Handoff** — `run_stage.py run export_handoff`. Show the user
   `reports/geometry_materials_report.md` (summarise, don't paste) and ask them to
   approve the checkpoint: `manifest_tool.py approve --checkpoint handoff_NNN`.
   The rigging skill (`/roblox-creature-rig-animation`) is invoked by the user, not by you.

## Optional reconstruction (only on explicit request)

- Visual hull from ≥ 2 calibrated, pose-consistent views: `run_stage.py run visual_hull`.
- External image-to-3D backend: `image_to_3d_backend.py check`, then `run`, then
  `run_stage.py run import_init_mesh`. No backend is installed or verified.
Read [references/optional-reconstruction.md](references/optional-reconstruction.md)
first: preconditions, limits (no hidden concavities), license/VRAM verification
(≤ 8 GB, separate venv, never Blender's Python).

## Shared data contract

`pipeline_manifest.json` (schema 1.0.0, `assets/pipeline_manifest.schema.json`).
Read [references/data-contract.md](references/data-contract.md) when a manifest error
appears or when changing what is handed to the rigging skill. Shared files must stay
identical in both skills: `manifest_tool.py check-sync --other-skill <rig skill dir>`.

## Low-token operation

- Batch: one background stage call instead of many MCP calls; never one call per object.
- Return the script's JSON summary; full logs stay in `<project>/logs/`. Never paste
  vertex arrays, images as data, or whole logs into the conversation.
- Look at few renders: one diff image per problem view, small scale (0.5 or less).
- Re-read references only when the step needs them; never load all files.
- Retry a failed stage only after changing its cause; the manifest enforces
  `limits.max_stage_retries`.

## Error handling

`ok: false` with `error` = actionable message: fix the cause or ask the user.
Exit code 3 = unexpected exception: open the `traceback_file`, fix, and do not
retry blindly. If Blender is open on another file, background runs still work on
the working blend; interactive `run()` refuses to touch a different file.

## Reporting to the user

Summarise per stage: what ran, key numbers (IoU, tris vs budget, defects), what is
approximate (procedural textures, colour estimate), what is unverified, and the
next decision needed. Distinguish implemented / untested / unsupported features.

## Assets

`assets/` holds templates copied into projects: `dragon_anatomy.example.json`,
`reference_annotations.example.json`, `materials.example.json`,
`polygon_budgets.json`, `image_to_3d_backend.example.json`, and the manifest schema.
