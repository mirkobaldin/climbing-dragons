# Optional reconstruction: visual hull and image-to-3D extension point

Read only when the user explicitly wants a reconstruction-based initialisation.
The default path is procedural modeling; neither option produces final anatomy.

## Visual hull (`visual_hull.py`) — implemented, untested

Preconditions (all required):
1. ≥ 2 views with `usable_for` containing `visual_hull` (orthographic, or perspective
   with a calibrated camera), set up by `setup_references.py`.
2. A clean binary mask per view.
3. `reference_inspection` shows small registration residuals: the creature has the
   **same pose and proportions** in every view. Inconsistent views carve away real
   anatomy (a raised tail in one view deletes the tail).

Algorithm: regular voxel grid over the landmark bounding box (+pad), resolution =
voxels along the longest axis, capped at 4 M voxels. Each voxel centre is projected
with `Object.calc_matrix_camera(depsgraph, x, y) @ matrix_world.inverted()`, then
NDC → pixel (bottom-left origin, consistent with Blender image pixels). Kept if inside
the mask in all views minus `--allowed-misses`. Output = boundary voxel faces as
`INIT_VisualHull` (wire, not rendered), optional non-applied voxel Remesh.

Cannot recover: concavities invisible in every silhouette (rib-cage interior, gaps
between ribs, space between membrane and body seen edge-on, eye sockets), thin
structures smaller than a voxel, anything occluded. It never fills openings of the
procedural model. Use it to judge mass distribution, to place `LM_*` empties in
depth, or as a backdrop while editing — then rebuild procedurally.

## Image-to-3D backend — extension point only

`image_to_3d_backend.py` runs a separately installed backend (own virtual
environment; never install into Blender's Python), checks VRAM and config,
collects the produced mesh; `import_init_mesh.py` imports it as `INIT_ImageTo3D`
(fitted to landmarks). **No backend is installed, bundled or tested.**

Before enabling a backend, verify and record (`manifest_tool.py record-verification`):

| Item | How |
|---|---|
| Official repository | link from the paper/organisation, not a fork |
| License | read LICENSE for code **and** weights; commercial use in a Roblox game? |
| Actual CLI/API | run `--help` in the installed repo; do not trust README excerpts |
| Peak VRAM | measure with `nvidia-smi` during a run; must be ≤ 8 GB on this laptop with Blender closed |
| Output format/axes | inspect one output; set `--rotate-deg` for import |

Candidate noted on 2026-10-13 (not installed, not tested): **TripoSR**
(`VAST-AI-Research/TripoSR`), README states MIT license and about 6 GB VRAM for one
image with default options; CLI `python run.py <image> --output-dir <dir>`. Other
backends that need > 8 GB VRAM are out of scope. Single-image methods hallucinate
unseen sides and generally lose thin skeletal structures; expect a blob-like proxy.

Untrusted-data rule: backend outputs and downloaded weights are untrusted files;
keep them in their own folder and never execute code from them.
