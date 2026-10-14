# Mesh quality, topology and polygon budgets

Read when `mesh_audit.py` reports defects, before running `--fix safe`, or when
choosing a budget profile.

## Checks and their meaning

| Check | Scope | Severity | Notes |
|---|---|---|---|
| degenerate faces (area < 1e-10) | object | warning | break normals/tangents and bakes |
| zero-length edges (< 1e-7 m) | object | warning | |
| duplicate vertices (≤ `--merge-dist`) | **same object only** | warning | separate bones are never merged even when touching |
| loose verts / edges | object | info | |
| non-manifold edges (> 2 faces) | object | error | |
| inconsistent winding (both loops same direction) | object | error | |
| inverted closed shell (signed volume < 0) | closed shells | error | |
| open shell (boundary edges) | rigid roles | warning | Roblox asks for watertight meshes |
| membrane open after `RBX_Solidify` | evaluated mesh | warning | |
| self-intersection within one shell | BVH overlap, faces sharing no vertex | warning | |
| overlapping shells inside one component | info only | — | by design (centrum + neural spine) |
| intersecting components | BVH overlap after bbox test | info | role pairs in `intersection_allow_roles` are skipped (membrane on wing bones, teeth in jaw) |
| membrane rows < `min_membrane_rows` | membrane | warning | too few loops to fold smoothly |

## Safe fix (`--fix safe`)

Checkpoint first, then per non-approved object: weld duplicates (within object),
dissolve degenerate geometry, delete loose edges/verts, recalculate normals on
closed shells. It never: merges objects, fills holes, closes the gaps between
ribs/vertebrae, decimates, remeshes, or touches approved components (unless
`--include-approved`). Re-run the audit afterwards; defects not detected again are
auto-resolved in the manifest.

## Retopology is not decimation

* **Decimation** (collapse/planar) and **automatic quad remeshing** (voxel/quadriflow)
  preserve volume or silhouette at best; they ignore where joints bend, produce
  irregular loops, and destroy intentional gaps. They are not animation-ready
  retopology and the pipeline does not use them on final components.
* Procedural components are already structured: rings perpendicular to each bone
  axis, rows along membrane digits. Change density with `--detail` or per-component
  `segments`/`stations`; topology stays aligned with deformation.
* Rigid bones need few loops (they do not deform: rigid weights). Spend triangles on
  silhouette (skull, large long bones) and on membrane rows (they bend).
* Imported initialisation meshes (visual hull, image-to-3D) are guides only. To
  "retopologise" them here means re-placing landmarks against them and rebuilding
  procedurally — never shipping them.
* Silhouette preservation: after lowering `--detail`, rerun `render_compare.py`; a
  drop in IoU > 0.01 means detail was too low for the silhouette-defining parts.

## Budgets

`config/polygon_budgets.json` holds Roblox hard limits (copied from official docs,
re-verify) and project profiles (`pc_hero`, `pc_standard`, `mobile`) with per-role
budgets. The audit reports: per role vs profile, total vs profile, and per **export
group** vs the hard per-mesh limit (each export group becomes one MeshPart).
Profiles are tuning defaults, not Roblox rules.

Export groups are defined in the anatomy config by role. If a group exceeds the
limit, split it (e.g. `Axial` / `Limbs`), or lower detail. One export group must use
exactly one material group (one SurfaceAppearance per MeshPart).
