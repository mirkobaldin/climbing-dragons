# UVs, PBR bakes and Roblox SurfaceAppearance

Read before `prepare_uv_materials.py`, when bakes look wrong, or when setting up
textures in Roblox Studio.

## UV strategy

* One atlas per **material group** (all objects of the group share one material and
  one set of images). Procedural UVs (u around / v along) are kept; islands are
  scaled to equal texel density (`average_islands_scale`) and packed with rotation.
* Objects without `UVMap` get Smart UV Project (`smart_angle_deg`, `island_margin`).
* Membrane UVs come from the grid (u across panels, v along digits) — good for
  painting veins along digits later.
* Margins: `uv.island_margin` (UV units) and `bake.margin_px` (dilation) must match
  the lowest resolution used in the group to avoid bleeding.

## Bakes (Cycles)

| Map | Method | Colour space | Notes |
|---|---|---|---|
| color | `DIFFUSE`, pass filter `COLOR` only | sRGB | no direct/indirect light → no lighting baked into albedo |
| roughness | `ROUGHNESS` | Non-Color | |
| metalness | `EMIT` with metal value routed to a temporary emission | Non-Color | Cycles has no metallic bake type; links restored afterwards |
| normal | `NORMAL`, tangent space | Non-Color | high→low (selected-to-active, `cage_extrusion`) for objects that have `<name>_HP`; otherwise procedural bump of the low-poly |

High→low is preferred whenever detailed geometry exists: sculpt or model a
`<component>_HP` object (same position), rerun the stage. Without HP meshes the
normal map only carries procedural bump noise.

GPU: `--device GPU` tries OPTIX, then CUDA, for this Blender process only (prefs not
saved by the script). The RTX 4070 Laptop (8 GB) is enough for these small bakes; close
other GPU applications if Cycles reports out-of-memory, or use `--device CPU`.

## Approximations — label them

* Procedural maps are artistic defaults (`origin: procedural_bake`).
* `--estimate-color VIEW` takes the median colour inside the reference mask, keeps
  hue, reduces saturation by 15 % and sets brightness to `target_value`
  (`origin: image_estimate_approximation`, `approximation: true`). Lighting, shadows,
  colour grading and painted highlights of the reference still bias it. Never project
  reference photos directly onto the albedo: that bakes reference lighting in.

## Roblox mapping (verified 2026-10-13, re-check: references/verified-sources.md)

| Blender output | SurfaceAppearance property | Notes |
|---|---|---|
| `<group>_color.png` | `ColorMap` | sRGB |
| `<group>_normal.png` | `NormalMap` | Roblox supports only **OpenGL, tangent-space** normal maps. Blender bakes OpenGL (+Y green) by default → no channel flip. Flat = (127,127,255). Export tangents with the mesh if the map shows no effect. |
| `<group>_roughness.png` | `RoughnessMap` | grayscale |
| `<group>_metalness.png` | `MetalnessMap` | grayscale; may be omitted for bone (all 0) |

Limits: texture maps up to **1024×1024** for in-experience assets (the script caps at
1024); Marketplace avatar assets allow 2048 but a creature is not an avatar body.
Roblox suggests lowering Color/Roughness/Metalness resolution before Normal.

In Studio: select each imported MeshPart → insert `SurfaceAppearance` → assign the
four uploaded images (Asset Manager / Importer upload). One MeshPart carries one
SurfaceAppearance, therefore one material group per export group. Whether the
Importer creates SurfaceAppearance automatically from FBX-embedded textures is
**not verified** here; check during validation scenario 3.
