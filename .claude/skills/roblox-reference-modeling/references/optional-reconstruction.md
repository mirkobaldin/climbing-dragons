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

## Image-to-3D backend — mandatory (Stable Fast 3D)

Changed 2026-10-14 at the user's request: the backend is required, not optional.

| Item | Value (read on the official repo 2026-10-14) |
|---|---|
| Repository | https://github.com/Stability-AI/stable-fast-3d (weights: Hugging Face `stabilityai/stable-fast-3d`, gated) |
| License | Stability AI Community License (LICENSE.md): research, non-commercial and commercial use free while annual revenue < US$1M |
| VRAM | README: about 6 GB for one image with default options; limit here 8 GB |
| Output | GLB with UV atlas texture (`--texture-resolution`), optional remesh (`--remesh_option triangle`, `--target_vertex_count`) |
| Windows build | VS 2022 C++ build tools + CUDA Toolkit 12.x to compile `texture_baker` and `uv_unwrapper` |
| CLI | `run.py IMAGE --output-dir D --pretrained-model WEIGHTS_DIR ...` (argparse read from run.py) |

Rejected: Hunyuan3D-2/2.1 (license excludes the EU, UK, South Korea), TRELLIS (≥ 16 GB),
TripoSG (≥ 8 GB, no margin; RMBG-1.4 background remover is non-commercial), TripoSR (lower detail).

Install: `scripts/setup_image_to_3d.ps1` (see its header). Run: `image_to_3d_backend.py check|run`;
the run measures base and peak VRAM with `nvidia-smi` (peak includes other GPU apps, so
close Blender). Import: `import_init_mesh --as-model [--scale-m M]` keeps the textures and
puts the base on the ground; without `--as-model` the mesh is a hidden wire guide (old behaviour).

Limits: one image → the backend guesses hidden sides; thin structures (ribs, banners,
chains) can merge or vanish; a whole scene (arena) comes out as one object at modest
resolution. Check the result in renders before handoff; ask the user before any repair.

Status: setup script written, not executed on the target PC yet. Wiring (check → run →
import --as-model) tested on 2026-10-14 in a Linux cloud session with a stub backend and a
fake nvidia-smi, because that session has no GPU and cannot reach huggingface.co.

Untrusted-data rule: backend outputs and downloaded weights are untrusted files;
keep them in their own folder and never execute code from them.
