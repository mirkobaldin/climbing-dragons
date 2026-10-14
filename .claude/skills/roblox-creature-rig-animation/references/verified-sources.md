# Verified versions and sources (rigging/animation skill)

Read when an API call fails, before quoting a Roblox requirement, or when the last
check is older than ~3 months. Do not re-browse on every invocation; when you
re-verify, update this file and run `manifest_tool.py record-verification`.

## Environment (2026-10-13, author's machine)

Windows 11 Home 10.0.26200 · RTX 4070 Laptop GPU 8 GB (driver 610.88) · Blender
5.2.2 LTS connected through the Blender MCP server (Python 3.13.13, numpy 2.3.4) ·
no system Python (use Blender's bundled python.exe) · UI language it_IT with
translated new data names (scripts always set names explicitly) · Roblox Studio MCP
server present (`execute_luau`, `inspect_instance`, `get_console_output`, …) but not
used yet.

## Blender 5.2 animation/rigging API probed live (2026-10-13)

* `bpy.types.Action` is layered: properties `slots`, `layers`, `is_action_layered`,
  `use_cyclic`, `frame_range`; there is **no** `Action.fcurves` (removed after 4.4's
  compatibility layer). F-curves live in `ActionChannelbag.fcurves`
  (`new(data_path, index, group_name)`, `find`, `ensure`, `remove`, `clear`).
* `bpy_extras.anim_utils`: `action_ensure_channelbag_for_slot(action, slot)`,
  `action_get_channelbag_for_slot`, `bake_action_objects(object_action_pairs, *, frames, bake_options)`,
  `BakeOptions(only_selected, do_pose, do_object, do_visual_keying, do_constraint_clear,
  do_parents_clear, do_clean, do_location, do_rotation, do_scale, do_bbone, do_custom_props)`;
  bake honours `PoseBone.select` (`Bone.select` no longer exists).
* `ActionSlots.new(id_type, name)`, `AnimData.action_slot`, keyframe handle types incl.
  `AUTO_CLAMPED`, F-modifier type `CYCLES`, `Quaternion/Euler.make_compatible`.
* `EditBone.align_roll`, `Armature.collections.new(name, parent)`, `BoneCollection.assign`,
  PoseBone `ik_min_x`, `use_ik_limit_x`, `lock_ik_x`, `ik_stretch`; IK constraint
  `pole_target/pole_subtarget/pole_angle/chain_count/use_tail/use_stretch`;
  Limit Rotation `owner_space`, `use_transform_limit`, `min_x…`.
* `bpy.ops.import_anim.bvh(target, global_scale, rotate_mode, axis_forward, axis_up, use_fps_scale, frame_start…)`.
* `bpy.ops.export_scene.fbx` options used: `apply_scale_options` (FBX_SCALE_UNITS),
  `add_leaf_bones`, `use_armature_deform_only`, `bake_anim*`, `path_mode`, `embed_textures`,
  `use_tspace`, `mesh_smooth_type`, `axis_forward/up`, `primary/secondary_bone_axis`.
* `bpy.ops.object.vertex_group_limit_total(group_select_mode, limit)`.

Compatibility: written for and probed on Blender **5.2**; 4.4–5.1 plausible but
unverified; < 4.4 unsupported (no slotted actions).

## Roblox documentation read on 2026-10-13

| Fact | Source |
|---|---|
| ≤ 20,000 tris per mesh; ≤ 4 influences per vertex; bones frozen (rotation 0, scale 1); root at 0,0,0 without influences; only one animation track per exported model | https://create.roblox.com/docs/art/modeling/specifications |
| Importer: Rig Type R15/Custom/No Rig; Keep Zero Influence Bones off by default (zero-influence bones removed); World Forward/Up; Scale Unit studs; Upload to Roblox | https://create.roblox.com/docs/studio/importer |
| Joints with no skin influence are not imported; names must be unique and differ from mesh names | https://create.roblox.com/docs/art/modeling/rig-a-simple-mesh , https://create.roblox.com/docs/art/modeling/skin-a-simple-mesh |
| Blender FBX export for animated content: Path Mode Copy + Embed Textures, Apply Scalings FBX Unit Scale, Add Leaf Bones off, Bake Animation on with NLA Strips/All Actions/Force Start-End off and Simplify 0 | https://create.roblox.com/docs/art/modeling/export-requirements , https://create.roblox.com/docs/art/emotes/export-settings |
| Animation Editor: Import → From File, root pose source "Imported Rig" | https://create.roblox.com/docs/avatar/emotes/import |
| Avatar bodies: R15 hierarchy, 10,742-tri total budget, textures ≤ 2048; animation packs: CurveAnimation, ≤ 10 s, R15 rig | https://create.roblox.com/docs/avatar/character-bodies/specifications , https://create.roblox.com/docs/avatar/animation-packs |
| Normal maps: OpenGL tangent space only; textures ≤ 1024 in-experience | https://create.roblox.com/docs/art/modeling/texture-specifications |

Not verified (check in validation scenario 3): automatic SurfaceAppearance creation
from FBX textures, facing direction after import with −Z/Y axes, exact import scale,
whether the Animation Editor accepts this custom rig's FBX takes without remapping.
