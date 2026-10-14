# Shared data contract: pipeline_manifest.json (schema 1.0.0)

Read when a script reports a manifest/schema error, when editing the manifest by
hand, or when changing what one skill passes to the other. Identical file in both
skills. Schema: `assets/pipeline_manifest.schema.json` (validated by
`manifest_tool.py validate` with a built-in subset validator, no dependencies).

## Location and paths

* One manifest per creature project: `<project>/pipeline_manifest.json`.
* All paths inside it are **relative to the manifest folder** (absolute paths are
  accepted). Scripts resolve their own resources from `Path(__file__)`, never from
  the current working directory.
* Skill resources (scripts, assets, references) stay in `.claude/skills/...`;
  generated assets stay in the project folder:
  `refs/ config/ blend/ checkpoints/ textures/ renders/ logs/ export/ reports/`.

## Top-level keys

| Key | Written by | Content |
|---|---|---|
| `schema_version` | init | `1.x.y`; scripts refuse a different major |
| `creature_id`, `display_name` | init | `[A-Za-z][A-Za-z0-9_]{1,40}` |
| `units` | init | metres, `blender_scale_length` 1.0, `meters_per_stud` 0.28 (size estimate only) |
| `axes` | init | Blender +Z up, creature forward −Y, left +X; FBX export axes |
| `paths` | init, scripts | `working_blend`, configs (anatomy, annotations, budgets, materials, rig, animation) |
| `environment` | `run_stage.py detect` | OS, Blender exe/version, GPU/VRAM |
| `limits` | init (edit freely) | refinement iterations, min IoU gain, stall patience, stage retries |
| `references[]` | inspect_references | view, image, declared/assessed projection, usable_for, px_per_m, evidence |
| `landmarks{}` | inspect, build, handoff | `{co, source: config\|reference_triangulation\|scene_edit\|mirrored, complete, residual_m}` |
| `components[]` | build_dragon, mesh_audit | `{name, key, role, side, bone_hint, influences?, export_group, material_group, tris, approved, source}` |
| `export_groups[]` | mesh_audit, handoff | `{name, components[], tris, max_tris, material_groups[]}` → one Roblox MeshPart each |
| `joints[]` | build_dragon | `{name, head, tail, parent, side, chain, chain_type, index, connected, pole_hint?}` |
| `textures[]` | prepare_uv_materials | `{material_group, map, path, resolution, color_space, normal_convention, origin, approximation}` |
| `checkpoints[]` | any mutating stage | `{id, stage, path, approved, label}`; approval is a user action |
| `stages{}` | every stage | `{status, updated_at, summary, log, inputs_hash, attempts, history?}` |
| `defects[]` | stages, user | `{id D###, stage, severity, description, objects[], status open\|resolved\|wontfix}` |
| `verifications[]` | user/Claude | `{topic, source, result, checked_at}` — record checked versions/specs |
| `handoff{}` | export_handoff | `{ready, checkpoint, blend, export_groups, warnings, requires_user_approval}` |
| `rig{}`, `animations{}`, `exports[]` | rigging skill | rig object/bone counts, clip records, exported files |

## Stage names and statuses

Modeling: `reference_inspection reference_setup coarse_model silhouette_compare refine
visual_hull image_to_3d mesh_audit uv_pbr handoff`.
Rigging: `rig_build skinning weight_audit animation retarget curve_audit bake_export studio_validation`.
Statuses: `pending running done failed approved stale skipped unsupported`.
Downstream stages become `stale` when an upstream stage rebuilds geometry.
`inputs_hash` lets a stage skip itself when nothing relevant changed (`--force` overrides).
`attempts` counts failures; beyond `limits.max_stage_retries` the stage refuses to
run until reset with `manifest_tool.py set-stage --status pending`.

## Contract between the skills

The rigging skill requires: `handoff.ready = true`, an **approved** handoff checkpoint,
`joints[]`, and `components[]` whose rigid entries have a `bone_hint` that is a joint
name and whose membranes list `influences`. It never edits modeling stages; it adds
`rig`, `animations`, `exports` and its own stages. The modeling skill never edits
rigging keys. Neither skill invokes the other.

## Versioning

Additive, backwards-compatible changes bump the minor version. Renaming/removing
keys or changing meanings bumps the major version and requires a migration note
here. Shared files (`pipeline_common.py`, `manifest_tool.py`, `run_stage.py`, schema,
this document) must stay identical in both skills: `manifest_tool.py check-sync`.
