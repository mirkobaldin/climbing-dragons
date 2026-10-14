# Skinning: rigid bones, membranes, Roblox limits

Read before changing skinning settings or when `weight_audit.py` reports problems.

## Rigid components

Every skeletal component (`role` ≠ membrane) gets weight 1.0 on `DEF-<bone_hint>`.
A bone does not bend, so blending weights across a joint would make it rubbery;
joints read correctly because components are separate shells with gaps. Rigid
deviation in deformation tests should be ~0 (tolerance `rigid_tolerance`).

## Membranes (distributed weights)

Algorithm (`skin_weights.py`): candidate bones = the component's `influences`
(digits, arm, spine, pelvis, thigh). For each vertex, distance to each bone
**segment** (rest pose); `w = 1 / (d + 1 mm)^falloff`; keep the strongest
`max_influences`; normalise; Laplacian smoothing along mesh edges
(`smooth_iterations`, `smooth_factor`); re-limit; drop weights < `min_weight`;
renormalise. Effects of the knobs:

| Knob | Higher value → |
|---|---|
| `falloff` | sharper ownership by the nearest digit; creases along digits |
| `smooth_iterations` / `smooth_factor` | softer transitions; risk of digits pulling distant membrane |
| `min_weight` | fewer tiny influences; cleaner limit to 4 |

Membrane folding quality depends on rows along the digits (modeling skill) as much
as on weights. Check with the `wing_fold_L` / stroke tests: no collapsed faces
(area ratio < 0.2) and limited over-stretch (> 3.0) at the configured extremes.
Remaining artefacts can be painted by hand in Weight Paint mode; re-running
`skin_weights.py` overwrites `DEF-*` groups, so protect hand edits with `--only`.

## Roblox constraints (verified 2026-10-13)

* ≤ 4 influences per vertex (hard cap in the script).
* No influences on the root bone (dropped on import).
* Bones without influence are removed by the Importer unless **Keep Zero Influence
  Bones** is enabled; `weight_audit.py` lists them (root, pelvis-only chains…). For this
  rig enable that option, then confirm in validation scenario 3.
* Bones frozen: rig object rotation 0, scale 1; skin in the bind (rest) pose.
* Bone and mesh names unique; meshes must not share names with bones.

Weights live on the source components; `bake_export.py` joins copies per export group
(vertex groups merge by name), re-limits to 4 and normalises before export.
