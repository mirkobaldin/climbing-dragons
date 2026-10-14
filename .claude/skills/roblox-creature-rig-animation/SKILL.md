---
name: roblox-creature-rig-animation
description: Rigs and animates a creature produced by the roblox-reference-modeling handoff in Blender and exports it for Roblox - builds deform/control/mechanism bones with leg IK, poles, wing FK or IK and joint limits, applies rigid and membrane weights within Roblox's 4-influence limit, generates Idle, Walk, Takeoff and Fly actions (Land optional), retargets BVH or joint trajectories where the source supports it, audits loops, foot sliding and curves, bakes to deform bones and exports skinned FBX files per clip with Roblox Studio import instructions. Use when the user asks to rig, skin, animate, retarget, bake or export the creature for Roblox, or to check its weights or animation curves.
disable-model-invocation: true
---

# Roblox creature rigging and animation

Status: **implemented, untested**. No script has been run end-to-end, and nothing has
been validated in Roblox Studio. Say so until validation scenarios 2 and 3 pass
([references/validation-plan.md](references/validation-plan.md)).

## Ground rules

- Talk to the user in their language; code, identifiers and files stay in English.
- Input is the modeling skill's manifest. Never edit modeling stages or rebuild
  meshes here; if geometry is wrong, tell the user to fix it with
  `/roblox-reference-modeling`. Do not invoke the other skill yourself.
- Verify instead of assuming: confirm MCP tool names with ToolSearch; read
  [references/verified-sources.md](references/verified-sources.md) only when an API
  fails, a Roblox fact is quoted, or the check date looks stale.
- Never claim Studio import/playback success unless it was performed in Studio and observed.
- Never present smooth curves or low sliding numbers as proof of good animation.
- Do not launch subagents. Do not rerun stages reported `skipped: inputs unchanged`.

## Paths

`SKILL` = this folder (resolve from this file). Project = folder with
`pipeline_manifest.json`. Python for stdlib tools: Blender's bundled interpreter,
e.g. `C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe`.
Background stage runs (preferred for batches):
```
"<py>" "SKILL/scripts/run_stage.py" run <script> --manifest "<project>" -- <args>
```
Interactive: MCP `execute_blender_code` calling `<script>.run({...})`. All commands,
options and result schemas: [references/script-cli.md](references/script-cli.md)
(read it when you need an option not shown here).

## Preconditions

1. `manifest_tool.py status --manifest <project>`: `handoff_ready` must be true and
   the handoff checkpoint approved. If not approved, ask the user to approve it
   (`manifest_tool.py approve --checkpoint handoff_NNN`); do not bypass unless the
   user explicitly accepts `--allow-unapproved`.
2. `manifest_tool.py copy-configs --project <project>` once, to add
   `config/rig_config.json`, `config/animation_config.json` and retarget templates.
3. Shared files in sync: `manifest_tool.py check-sync --other-skill <modeling skill dir>`.

## Workflow

1. **Rig** — `run_stage.py run build_rig [-- --wing-mode fk|ik_arm]`.
   Read [references/rig-design.md](references/rig-design.md) before changing limits,
   wing mode, control parenting, or when `rest_drift_m`/pole errors are reported.
   Choose wing IK/FK from anatomy: FK for flight strokes (default); `ik_arm` when the
   wrist must stay planted (wing-walking, perching). Explain the choice to the user.
2. **Skin** — `run_stage.py run skin_weights`. Rigid parts get one bone; membranes get
   distance-based, smoothed weights (≤ 4 influences, never the root).
   Read [references/skinning.md](references/skinning.md) when tuning or when audits fail.
3. **Audit weights and deformation** — `run_stage.py run weight_audit`. Report
   influence limits, zero-influence bones (Importer option needed) and membrane
   collapse/stretch per test pose. Fix errors before animating.
4. **Animate** — `run_stage.py run animate_cycles [-- --clips Idle,Walk,Takeoff,Fly]`.
   Read [references/animation-craft.md](references/animation-craft.md) before editing
   `animation_config.json` (wave shapes, gait, anticipation/push-off, loop rules,
   Land extension). Keys go on CTRL bones only.
5. **Audit curves** — `run_stage.py run curve_audit -- --snapshots 3`. Report loop
   continuity, foot sliding (cm/frame), Euler jumps, limit hits, Takeoff→Fly match.
   Look at no more than one snapshot per clip unless a problem needs it; ask the user
   to review motion quality by eye.
6. **Optional retargeting** (only with user-supplied motion) —
   `run_stage.py run retarget -- --mapping config/retarget_bvh.json --clip <Name>`.
   Read [references/retargeting.md](references/retargeting.md) first. Report
   `unsupported_by_source` honestly (a human BVH has no wings or tail).
7. **Bake and export** — `run_stage.py run bake_export`. Produces `<id>_rig.fbx` and one
   `<id>_<Clip>.fbx` per clip after Roblox checks (tris, influences, materials,
   names, frozen transforms). Read [references/roblox-export.md](references/roblox-export.md)
   for FBX settings, in-game vs Marketplace avatar differences, and the Studio steps.
8. **Studio validation** (only when the user asks and Studio is available) — follow
   scenario 3; `assets/studio_playback_check.luau` can be run through the Roblox
   Studio MCP `execute_luau` tool. Report observed output only.

## Iteration limits

`manifest.limits.max_stage_retries` caps failed retries per stage. For tuning loops
(weights, amplitudes), change one thing per iteration, re-run only the affected stage
(`--only`, `--clips`, `--tests`), and stop after the metric stops improving or after
three attempts; then ask the user.

## Data contract

`pipeline_manifest.json` schema 1.0.0. Read
[references/data-contract.md](references/data-contract.md) when the manifest is
rejected or when reading/writing `rig`, `animations`, `exports`.

## Low-token operation

- Prefer one background stage call over many MCP calls; never one call per bone.
- Return only the script's JSON summary; full logs/details stay in `<project>/logs/`.
- Never paste vertex/weight arrays, F-curve dumps or whole logs into the conversation.
- Use MCP for targeted inspection (one object summary, one screenshot) and quick fixes.
- Load reference files only for the step at hand.

## Error handling

`ok: false` + `error` is actionable: fix the cause or ask the user. Exit code 3 =
unexpected exception: open `traceback_file`, fix, then retry once. Stages that
change data save a checkpoint first; restore from `checkpoints/` if a result is worse.

## Reporting

Per stage: what ran, key numbers, what is approximate, what remains untested or
unsupported (e.g. no foot roll, no IK/FK switch, twist not recovered from
trajectories, Land disabled), and the next decision for the user.

## Assets

`assets/rig_config.example.json`, `animation_config.example.json`,
`retarget_bvh.example.json`, `retarget_trajectory.example.json`,
`studio_playback_check.luau` (Studio check, not run), manifest schema (shared).
