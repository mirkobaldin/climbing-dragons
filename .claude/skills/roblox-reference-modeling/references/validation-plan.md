# Validation scenario 1 — reference-guided mesh and silhouette comparison

Defined, **not yet executed**. Run only when the user asks to validate the skill.
Until it passes, report every script as "implemented, untested".

## Goal

Prove that the modeling stages run end-to-end on Blender 5.2 and that the
silhouette comparison measures what it claims, using a case with a known answer.

## Fixture (synthetic, so ground truth is known)

1. `manifest_tool.py init --project <tmp>/val1 --creature-id val_dragon`.
2. Build the example dragon from the shipped config (`build_dragon.py`, `--landmarks config`).
3. Make ground-truth references by rendering the built model through three orthographic
   cameras (side +X, top +Z, front −Y) at 1600 px with Workbench flat black on white;
   save renders as `refs/*_gt.png` and masks. Write `reference_annotations.json` with
   exact `px_per_m`/origin and ~12 landmarks projected with `world_to_pixel`.
4. Perturb the config: tail_c2 +0.25 m in Z, d2_tip_L +0.3 m in X, skull 15 % wider.

## Steps and pass criteria

| # | Step | Pass if |
|---|---|---|
| 1 | `run_stage.py detect` | environment written; Blender 5.2.x found |
| 2 | `inspect_references.py` | all three views orthographic; registration scale within 1 ± 0.005; no axis issue > 0.02 m |
| 3 | inject a 3 % scale error in the top view, re-run | registration warning names the top view; revert |
| 4 | `setup_references.py` | 3 cameras, 3 image empties, landmarks at expected coords (± 1 mm); re-run creates no duplicates |
| 5 | `build_dragon.py` with perturbed config | objects created; re-run → `built: 0`, all `unchanged` |
| 6 | `render_compare.py` | IoU < 1 on side/top; worst regions name `tail_*` and `d2_*`/`skull_*` landmarks |
| 7 | restore config, `build_dragon.py --only vert_tail,wing_d2_bones,wing_membrane,skull` | only those keys rebuilt; checkpoint saved before |
| 8 | `render_compare.py` | mean IoU ≥ 0.97 and higher than step 6; history shows 2 iterations |
| 9 | edit one vertebra by hand, rebuild | object reported under `manual_edit`, kept |
| 10 | `mesh_audit.py` | no non-manifold/winding errors; ribs not merged; group tris reported |
| 11 | `prepare_uv_materials.py --device GPU` | four PNGs per group, ≤ 1024 px, normal map mostly (128,128,255) |
| 12 | `export_handoff.py` | `ready: true`; report written; `manifest_tool.py validate` → 0 errors |
| 13 | stall logic | three runs without changes → `continue_refinement: false` with stall reason |

Record outcome per step in `reports/validation_1.md` and the manifest
(`record-verification --topic validation_1`). A real reference set (painted model
sheet) should follow as a second pass; expect lower IoU and document why.
