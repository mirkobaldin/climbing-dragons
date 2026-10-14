# Roblox export, Studio import and playback

Read before `bake_export.py` and when guiding the user through Roblox Studio.
Specs verified 2026-10-13 (see verified-sources.md); re-check if older than ~3 months.

## In-game creature vs Marketplace avatar

| | In-experience creature (this pipeline) | Marketplace avatar body |
|---|---|---|
| Rig | custom skeleton, Rig Type **Custom** in the Importer | R15 humanoid hierarchy, fixed names |
| Triangles | ≤ 20,000 per mesh (MeshPart); budget by profile | 10,742 total over 15 body meshes |
| Textures | ≤ 1024×1024 | ≤ 2048×2048 |
| Animation | AnimationController + Animator on the model | R15 animation packs (CurveAnimation, ≤ 10 s, R15 rig) |
A non-humanoid dragon cannot be sold as an avatar body through this pipeline;
avatar requirements are listed only to avoid confusing the two.

## What bake_export.py produces

* `export/<id>_rig.fbx`: export rig (DEF bones only) + one mesh per export group,
  rest pose, textures embedded (path mode COPY).
* `export/<id>_<Clip>.fbx`: same rig/meshes + **one** baked take (Roblox: only a single
  animation track per exported model, so one file per clip).
* FBX settings (rig_config.fbx overrides): Apply Scalings = FBX Units Scale,
  Forward −Z, Up Y, Add Leaf Bones off, Only Deform Bones on, Bake Animation on for
  clips with NLA Strips off, All Actions off, Force Start/End Keying off, Simplify 0,
  tangent space on (normal maps). Matches Roblox's Blender export guidance.
* Checks before writing: ≤ 20,000 tris per mesh, ≤ 4 influences, no unweighted
  vertices, one material per mesh, unique bone/mesh names, no root weights, rig
  transforms frozen.

## Studio import (manual steps for the user)

1. Studio → Import 3D (File → Import 3D) → `<id>_rig.fbx`.
2. Importer settings: Rig Type **Custom**; **Keep Zero Influence Bones: on** (root and
   other unweighted bones would otherwise be removed); Upload to Roblox off while
   testing; check World Forward/Up and Scale Unit in the preview. Expected size:
   creature length in metres ÷ 0.28 ≈ studs (estimate). If 100× too large, the FBX
   unit setting differs — re-export with global_scale 0.01 or adjust Scale Unit.
3. After import: the Model contains MeshParts (one per export group) and Bones.
   If no SurfaceAppearance was created, add one per MeshPart and assign ColorMap,
   NormalMap, RoughnessMap, MetalnessMap from `textures/`.
4. Add an `AnimationController` with an `Animator` child to the Model if absent.
5. Animation Editor → select the rig → ⋯ → Import → From File → `<id>_<Clip>.fbx`
   (Import Settings: root pose source = Imported Rig). Set Looping for Idle/Walk/Fly,
   then publish/save each animation to get an asset ID.
6. Playback in game: `animator:LoadAnimation(animationInstance):Play()`; drive the
   model's movement from code at `animations.Walk.speed_mps` (≈ studs/s estimate).

## Studio verification script (not run)

`assets/studio_playback_check.luau` prints MeshParts, bone count, bounding box in
studs, LookVector, controller/animator presence, and (with an Animation ID) track
length, IsPlaying, Looped and sampled bone positions. Run it from the Command Bar or
through the Roblox Studio MCP `execute_luau` tool only when the user asks for the
Studio validation, and report its actual output.

## Honesty rule

Never report a successful Roblox import or playback unless it was performed in Roblox
Studio and observed (screenshot, console output, or the user's confirmation). Until
then, the status of `studio_validation` stays `pending`.
