# Verified versions and sources (modeling skill)

Read when a Blender API call fails, before trusting a Roblox number, or when the
last check is older than ~3 months. Do not re-browse these pages on every
invocation; re-verify only when stale or contradicted, then update this file and
`manifest_tool.py record-verification`.

## Environment detected on 2026-10-13 (author's machine)

| Item | Value | Method |
|---|---|---|
| OS | Windows 11 Home 10.0.26200 | system info |
| GPU | NVIDIA GeForce RTX 4070 Laptop GPU, 8188 MiB, driver 610.88 | `nvidia-smi` |
| Blender installs | 3.6, 4.1 (C:\DreamBlender), 4.2, 4.3, 4.4, 5.2 | file system |
| Blender connected via MCP | **5.2.2 LTS**, Python 3.13.13, numpy 2.3.4 | `bpy.app.version_string` |
| System Python | none (`py -0p` found none) → use Blender's bundled python.exe | |
| UI language | it_IT with "translate new data names" ON → scripts always set names explicitly and look nodes up by name/bl_idname | preferences |
| Cycles device | NONE in prefs (CPU) → `--device GPU` opt-in | preferences |
| MCP server | tools `execute_blender_code`, `execute_blender_code_for_cli`, `get_objects_summary`, `render_viewport_to_path`, `get_python_api_docs`, … (lab_blender_org MCP extension) | ToolSearch |

## Blender 5.2 API facts probed live (2026-10-13)

* Render engines: `BLENDER_WORKBENCH`, `CYCLES`, `BLENDER_EEVEE` (`BLENDER_EEVEE_NEXT` no longer exists).
* `bpy.ops.object.bake` params: `type` (incl. `DIFFUSE`, `ROUGHNESS`, `EMIT`, `NORMAL`), `pass_filter`,
  `margin`, `use_selected_to_active`, `cage_extrusion`, `normal_space`, `target`, `save_mode`, `use_clear`, `uv_layer`.
* `bpy.ops.uv.smart_project(angle_limit, island_margin, …)`, `uv.pack_islands(rotate, margin, …)`.
* `bmesh.ops`: `find_doubles`, `remove_doubles`, `dissolve_degenerate`, `recalc_face_normals`, `delete` present.
* `Object.calc_matrix_camera(depsgraph, x, y, scale_x, scale_y)`, `Object.empty_image_offset` present.
* Importers: `wm.obj_import`, `wm.ply_import`, `wm.stl_import`, `import_scene.gltf`, `import_scene.fbx`.
* `Mesh.use_auto_smooth` removed (since 4.1) — not used.
* Principled BSDF socket names (English, unaffected by UI language): `Base Color`, `Metallic`,
  `Roughness`, `Normal`, `Emission Color`, …; Normal Map node spaces `TANGENT|OBJECT|WORLD|…`.
* Manual (bundled with MCP server): Blender uses the **OpenGL** normal-map convention (Y up in green) for rendering and baking.

Compatibility claim: scripts target Blender **5.2** (probed). 4.4–5.1 are plausible
(layered actions exist since 4.4) but unverified; < 4.4 unsupported (`require_blender`).

## Roblox documentation read on 2026-10-13

| Fact used | Source |
|---|---|
| Individual meshes ≤ 20,000 triangles; watertight geometry; ≤ 4 influences per vertex; bones frozen (rot 0, scale 1); root at origin without influences; only one animation track per exported model | https://create.roblox.com/docs/art/modeling/specifications |
| Texture maps up to 1024×1024; normal maps must be OpenGL tangent space; flat normal (127,127,255) | https://create.roblox.com/docs/art/modeling/texture-specifications , https://create.roblox.com/docs/art/modeling/surface-appearance |
| Marketplace avatar body budgets (total 10,742 tris over 15 meshes, textures ≤ 2048) | https://create.roblox.com/docs/avatar/character-bodies/specifications |

The rigging skill's `verified-sources.md` lists the export/import facts.
