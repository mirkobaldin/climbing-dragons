# Procedural anatomy: config format and algorithms

Read when editing `config/dragon_anatomy.json`, adding a component type, or
diagnosing `build_dragon.py` errors. Code: `scripts/anatomy_lib.py`.

## Contents
1. Landmark references · 2. Joints · 3. Component types · 4. Geometry algorithms ·
5. Symmetry · 6. Local corrections and idempotency · 7. Naming and custom properties

## 1. Landmark references

Anywhere a point is expected you may use:
`"name"`, `"name_{S}"` (side substituted), `[x, y, z]`, `{"lm": ref, "offset": [x, y, z]}`
(offset x mirrored on the right), `{"lerp": [ref_a, ref_b, t]}`.
Missing `_R` landmarks are mirrored from `_L` (x → −x) and vice versa.
Priority: config < manifest triangulated (complete only) < scene `LM_*` empties.

## 2. Joints (`joints`, ordered: parents first)

```json
"leg_hind": {"type": "leg", "side": "LR", "points": ["hip_{S}", "knee_{S}", "ankle_{S}", "ball_{S}"],
             "names": ["thigh", "shin", "metatarsus"], "parent": "pelvis", "pole_hint": [0, -1, 0]}
```
* `names` → one bone per consecutive point pair; else `bones: N` resamples a smooth
  Catmull-Rom curve through the points into N equal-length bones (`key_01…`).
* Single-bone chains without `names` are named after the key. LR chains get `_L/_R`.
* `parent`: a joint name (may contain `{S}`), or `chain:last` / `chain:first`.
* `type` (`root|axial|head|jaw|leg|toe|wing_arm|wing_digit`) tells the rigging skill
  which controls to build. `pole_hint` (world direction of knee/elbow; x mirrored
  for R) sets bone roll and pole placement.
* Output: `manifest.joints[] = {name, head, tail, parent, side, chain, chain_type, index, connected, pole_hint?}`.
  Names are base names; the rigging skill adds `DEF-`/`CTRL-`/`MCH-` prefixes.

## 3. Component types (`components`)

Common keys: `type`, `role`, `side` (`C` default or `LR`), `symmetry` (default true),
`name`, `bone` (rigid binding joint; may contain `{S}`), `segments`, `stations`,
`enabled` (false = skip). Roles: `skull jaw tooth horn vertebra rib pelvis limb_bone claw wing_bone membrane other_rigid`.

| Type | Required keys | Produces |
|---|---|---|
| `loft` | `points`, `sections [[t, half_w, half_h, dz], …]` | one closed solid; elliptical sections interpolated along a smooth path (skull, ilium, scapula) |
| `tube` | `points`, `radius`, opt. `radius_profile [[t, k]]`, `flatten`, `tip` | swept circle/ellipse (jaw U-shape through 5 points) |
| `curved_cone` | `base`, `toward` or `direction`, `length`, `radius`, `curve_deg`, `bend` | tapered arc ending in a point (horns, claws) |
| `vertebra_chain` | `points`, `count`, `centrum_radius`, `bone_chain`; opt. `length_ratio` (gap), `neural_spine_height`, `neural_spine_tilt_deg`, `transverse_length` | one object per vertebra (centrum + neural spine + transverse processes as separate shells) |
| `rib_set` | `vertebrae` (a vertebra_chain key), `range [i0, i1]`, `spread`, `drop`, `sweep`, `radius [base, tip]` | one rib per vertebra and side; bone hint = that vertebra's spine bone |
| `limb_chain` | `points`, `names`, `bones`, `radius` (per segment), `gap` | one long bone per segment with epiphysis profile, shortened by `gap` at both ends |
| `digit_set` | `base`, `toward`, `digits`, `spread_deg`, `phalanx_length/radius`, `claw_length/radius/curve_deg`, `bone` | phalanx + curved claw per digit, fanned around Z |
| `spike_row` | `points`, `count`, `t_range`, `length`, `radius`, `direction` | teeth/spikes as shells of one object |
| `membrane` | `chains{name: {points, rows} \| {compose: [a, b]}}`, `panels [[a, b], …]`, `cols_per_panel`, `sag`, `billow`, `thickness`, `influences` | one connected sheet per side + `RBX_Solidify` modifier |

Profiles (`centrum_radius`, `spread`, …) accept a number, evenly spaced values
`[a, b, c]` along the chain, or `[[t, v], …]` pairs.

## 4. Geometry algorithms

* **Paths**: centripetal Catmull-Rom (α = 0.5) through the points, then arc-length
  resampling → even stations; straight 2-point segments are resampled linearly.
* **Frames**: parallel transport from an initial normal = `up_hint` projected
  orthogonal to the first tangent (falls back to X/Y if nearly parallel). Frames are
  right-handed (`b = t × n`), so quads `(i,k)(i+1,k)(i+1,k+1)(i,k+1)` face outward.
* **Sections**: `p = c + b·cos(a)·w + n·sin(a)·h`. Caps are triangle fans; `tip` ends
  in a single vertex. UVs: u around, v along arc length; caps are separate islands.
* **Vertebrae**: path resampled to `2·count+1`; vertebra i sits at odd sample `2i+1`.
  Centrum length = spacing × `length_ratio` → the remaining fraction is the
  intervertebral gap. Spine tilt is toward −tangent (use negative values on chains
  whose direction is reversed, e.g. tail).
* **Ribs**: 4 control points in the vertebra frame (lateral = n × t), barrel-shaped
  by the `spread`/`drop` profiles, swept back by `sweep`. Ribs are separate objects;
  gaps between ribs are never filled.
* **Long bones**: profile `[0.75, 1.0, 0.62, 0.55, 0.62, 1.0, 0.75]` (epiphyses at the
  ends), trimmed by `gap` at each joint so bones do not interpenetrate.
* **Membrane**: each chain is resampled to `rows+1` points (composed chains reuse
  the exact samples of their parts, so shared digits produce shared vertices).
  Panel grid `P[r][c] = lerp(A[r], B[r], c/cols)` plus trailing-edge sag
  `(rootmid − tipmid)·sag·sin(πs)·(r/R)²` and optional billow along the panel normal.
  Coincident vertices are merged (1 µm); collapsed quads become triangles.
  Rows run along the digits = deformation loops for folding.

## 5. Symmetry

`side: LR` builds the left side and mirrors vertices (x → −x) with reversed winding,
names `_L → _R`, bone hints and influences swapped. `symmetry: false` builds each
side from its own landmarks (use when references show real asymmetry).
`rib_set` is always bilateral.

## 6. Local corrections and idempotency

* `--only key1,key2` rebuilds just those components.
* Approved components (`manifest_tool.py approve --components …`) are never rebuilt
  without `--force`.
* Each object stores `rbx_src_hash` (generator output) and `rbx_mesh_hash` (mesh as
  stored). Unchanged output → skipped. Mesh edited by hand since the last build →
  kept and reported (use `--force` to regenerate, or approve it to protect it).
* Stale objects of a rebuilt component (e.g. vertebra count reduced) are removed;
  objects without `rbx_generator` are never touched.
* A checkpoint is saved before existing geometry is replaced.
* `--detail` scales segments/stations (minimums enforced) to hit budget profiles
  without decimation.

## 7. Naming and custom properties

Object = mesh name = `<prefix>_<Name>[_NN][_L|_R]` (e.g. `DRG_VertTail_07`,
`DRG_Rib_04_R`, `DRG_WingMembrane_L`). Collections `<prefix>_Model/<prefix>_<Region>`.
Custom properties: `rbx_component` (config key), `rbx_role`, `rbx_side`,
`rbx_bone_hint`, `rbx_export_group`, `rbx_material_group`, `rbx_generator`,
`rbx_src_hash`, `rbx_mesh_hash`; membranes also `rbx_rows`, `rbx_cols`,
`rbx_thickness`, `rbx_influences`. The rigging skill relies on these.

## Adding a component type

Write `gen_<type>(key, spec, lm, ctx, side) -> list[part]` in `anatomy_lib.py`
(use `swept_solid`/`tube`/`curved_cone`, `new_part`, `append_geo`), register it in
`GENERATORS`, document it in the table above. Keep outputs closed and outward-facing.
