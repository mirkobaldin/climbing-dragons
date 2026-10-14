# Validation scenarios 2 and 3 (defined, not executed)

Run only when the user asks. Until a scenario passes, report the related scripts as
"implemented, untested". Scenario 1 (modeling) is in the modeling skill.

## Scenario 2 — one wing rig and a Fly loop with deformation checks

Fixture: the example dragon from scenario 1 (or `build_dragon --only wing_arm_bones,
wing_d2_bones,wing_d3_bones,wing_d4_bones,wing_d5_bones,wing_membrane,vert_spine,sacrum`
plus the joints), handoff approved.

| # | Step | Pass if |
|---|---|---|
| 1 | `build_rig.py` | DEF count = joint count; `rest_drift_m` < 1e-4; pole rest error < 1° per IK chain; re-run → same bone names, no duplicates |
| 2 | Inspect in Blender (one screenshot) | `+rot_x` on `CTRL-wing_humerus_L` and `_R` raises both wings; `+rot_z` on `_L` folds back, mirrored value folds `_R` back |
| 3 | `skin_weights.py` | rigid parts single-bone; membrane ≤ 4 influences, 0 unweighted |
| 4 | `weight_audit.py` | no errors; `wing_fold_L`, up/downstroke: 0 collapsed faces, overstretched faces ≤ 2 % ; rigid deviation < 0.01 |
| 5 | `animate_cycles.py --clips Fly` | channels created on CTRL bones only; keys every 2 frames; last = first |
| 6 | `curve_audit.py --clips Fly --snapshots 4` | loop pose error < 0.1°, velocity error < 0.5°/frame, no Euler jumps, root motion 0 |
| 7 | Visual review of snapshots | downstroke reads stronger/slower than upstroke, digits trail the arm, membrane does not pass through the body; record judgement, not just metrics |
| 8 | Tune limits | if `limit_hits` > 0, decide: widen limits or reduce amplitudes; document |

## Scenario 3 — real Roblox Studio import and playback

Requires Roblox Studio open (optionally the Roblox Studio MCP server).

| # | Step | Pass if (observed in Studio) |
|---|---|---|
| 1 | `bake_export.py --clips Idle,Fly` | files written; tris ≤ 20,000 per mesh; influences ≤ 4 |
| 2 | Import `<id>_rig.fbx` (Rig Type Custom, Keep Zero Influence Bones on, Upload off) | no importer errors; MeshParts = export groups; Bones present incl. root |
| 3 | `studio_playback_check.luau` (no Animation ID) | bounding box ≈ expected studs (length m ÷ 0.28, ± 10 %); LookVector matches the creature's head direction or the needed rotation is documented |
| 4 | SurfaceAppearance | maps visible; normal map shading correct (no inverted bumps) |
| 5 | Animation Editor → Import → From File `<id>_Fly.fbx` | timeline populated; wings move; no exploding bones |
| 6 | Publish/save Fly, run the Luau check with its Animation ID in Play mode | `isPlaying = true`, `trackLength` ≈ 0.8 s, sampled bone positions change between samples, loop seamless by eye |
| 7 | Record | screenshots + console output in `reports/validation_3.md`; `manifest_tool.py set-stage --stage studio_validation --status done` only after all steps pass |

Failures to anticipate: wrong facing (fix axes or rotate root), 100× scale
(FBX units), zero-influence bones removed (setting), clip import refused (rig/bone
name mismatch between rig FBX and clip FBX — both come from the same export rig).
