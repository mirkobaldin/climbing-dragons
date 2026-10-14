# Reference analysis: projection, calibration, consistency

Read this before writing `config/reference_annotations.json` or when
`inspect_references.py` reports conflicts or large residuals.

## 1. Orthographic vs perspective

Only orthographic views (model sheets, technical drawings, orthographic renders)
can be placed on axis-aligned planes and triangulated. A photo or 3/4 concept
painting is perspective: parallel 3D lines converge, near parts look larger, and
pixel distances do not map to one metric scale.

`projection_evidence()` is a heuristic, never proof:

| Evidence | Favours |
|---|---|
| EXIF FocalLength / camera Model present | perspective (+2) |
| `parallel_sets` segments diverge > `parallel_deg` | perspective (+2) |
| `parallel_sets` stay parallel | orthographic (−1) |
| L/R pair midpoints drift off `symmetry_axis` (> 15 % of mean pair width) | perspective or twisted pose (+1) |
| midpoints on the symmetry line | orthographic (−1) |

Score ≥ 2 → perspective. A declared/assessed conflict excludes the view from
triangulation (defect raised). Painted model sheets often mix projections
(e.g. a perspective head on an orthographic body): annotate only the parts that
are truly orthographic, or mark the view `unknown`.

Perspective views are `visual_only` unless you add a calibrated camera
(`camera: {lens_mm, sensor_width_mm, location, rotation_euler_deg}` in Blender
world space). Calibrated perspective views can be used for silhouettes and the
visual hull, not for triangulation.

## 2. View axes (Blender: Z up, creature faces −Y, left = +X)

| Viewer position | `image_right` | `image_up` | Notes |
|---|---|---|---|
| +X (sees creature's left side) | `+Y` | `+Z` | head on the left of the image |
| −X (sees right side) | `−Y` | `+Z` | head on the right |
| −Y (front, faces viewer) | `+X` | `+Z` | creature's left on image right |
| +Y (back) | `−X` | `+Z` | |
| +Z (top, head pointing up in image) | `−X` | `−Y` | |
| −Z (bottom) | `+X` | `−Y` | |

Mirrored source images (flipped horizontally) need the opposite `image_right` sign.

## 3. Scale and origin

Per orthographic view: `px_per_m`, or `scale: {p1, p2, meters}` (a scale bar or a
known length measured parallel to the image plane). `origin: {px, world}` maps one
pixel to the world coordinates of the two visible axes (usually a ground point
under the pelvis → world `[0, 0]`, or `pelvis_center` with its known height).
Use the same physical scale in all views; registration fits will reveal mistakes.

## 4. Landmark names

Use the anatomy config's landmark names (`skull_tip`, `hip_L`, `wing_wrist_R`, …).
Bilateral names end in `_L`/`_R`. A landmark seen in only one view has one unknown
axis (`complete: false`); it is placed at 0 on that axis and reported. Add it in a
second view or keep the config value (config < triangulated < scene edit).

## 5. Consistency diagnostics

`triangulate()` combines views per world axis. Example: side view (Y, Z) and front
view (X, Z) both observe Z. The residual is max − min of the estimates.
Tolerance = max(`axis_residual_m`, `axis_residual_ratio` × creature extent).

`registration_fits()` fits `b = s·a + t` between two views on a shared axis:

| Pattern | Likely cause | Action |
|---|---|---|
| `scale` ≠ 1 (> 2 %) | wrong px_per_m / scale bar in one view | re-measure scale |
| large `offset_m`, small rms after fit | origin pixel mismatch | fix `origin` |
| small scale/offset error, large rms concentrated on a few landmarks | pose or proportion differs (tail raised in one view, wings at another angle) | treat that region as inconsistent: trust one view, annotate pose-independent landmarks only, or re-pose in Blender |
| large rms everywhere | wrong axes declaration or mirrored image | check §2 |

Bilateral checks compare left/right 3D segment lengths (`bilateral_segments`).
A mismatch indicates asymmetric drawing or pose; the procedural model is
symmetric by default, so decide which side to trust.

## 6. What the setup creates

`setup_references.py`: `REF_<view>` image empties (alpha 0.5, depth offset behind
the model, front-side only), `CAM_REF_<view>` cameras matching each image exactly
(ortho scale = longest image side in metres; `rbx_res` holds the pixel size), and
`LM_<name>` sphere empties. Move an `LM_` empty in Blender to correct a landmark;
`build_dragon.py` picks the edit up (`source: scene_edit`) and later setup runs keep it.

## 7. Masks

Silhouette comparison needs a binary mask per view: either a separate image
(`mask`, white = creature) or `mask_from_image` thresholding (works only on clean
backgrounds). Painted references with shadows, ground planes or overlapping
props need hand-made masks; otherwise IoU numbers are meaningless.
