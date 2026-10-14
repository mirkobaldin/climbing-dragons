# Retargeting BVH and joint trajectories

Read only when the user supplies motion data. Templates:
`assets/retarget_bvh.example.json`, `assets/retarget_trajectory.example.json`.

## What a source can and cannot provide

| Source | Usable for this rig | Not provided (reported as `unsupported_by_source`) |
|---|---|---|
| Human biped BVH | torso/hips height, spine, neck, head; feet → hind-leg IK | fore legs (arms are not legs), wings, tail, jaw, digit fans |
| Quadruped mocap/trajectories | torso, 4 feet, neck/tail directions if tracked | wings, jaw, membrane |
| Bird/bat wing tracking | wing directions via aim entries (if mapped) | everything not tracked |

Never fabricate missing motion from the source. Unsupported chains stay at rest;
layer procedural oscillators (`animate_cycles.py`) or keyframe them, and say so.

## BVH mapping (`mode: bvh`)

1. Import with `import_anim.bvh`: `source.scale` (BVH units → metres, e.g. 0.01 for
   cm), `axis_forward`/`axis_up` (BVH is commonly −Z forward, Y up), `rotate_mode`.
   Check the imported skeleton faces −Y like the creature; otherwise change axes.
2. Rest pose: BVH rest = zero channels (usually T-pose); the rig rest = modeled pose.
   Rotations are transferred as **world-space deltas from each rest**:
   `R_target(f) = R_source(f) · R_source_rest⁻¹ · R_target_rest`. Use
   `rest_offset_deg` per bone for systematic differences (e.g. human spine vertical vs
   dragon spine horizontal yields reasonable pitch, but roll conventions may need offsets).
3. Scale: root translation × k, `k = target hip height / source hip height`
   (`scale: "auto"`) or a number. Feet: displacement from the first frame × k,
   applied to IK foot controls.
4. Local/global: desired world transforms are converted with
   `pose_bone.matrix = …` (armature space) processed parents-first with a depsgraph
   update per hierarchy level, then recorded as local channels.
5. In place: horizontal hip motion is removed from torso and feet (Roblox clips are
   in place); report the source's average speed to the user if needed.

## Joint trajectories (`mode: trajectory`)

File: `{fps, axis_forward, axis_up, scale, joints: {name: [[x, y, z], …]}}`.
`position_targets` move controls by each joint's displacement from the first frame;
`aim` rotates a control so its rest +Y axis points from joint `from` to joint `to`
(minimal rotation from rest, so twist is not recovered — limitation).

## After retargeting

Run `curve_audit.py --clips <clip>`: foot sliding, Euler jumps, limit hits. Expect
limit clamping when human ranges exceed creature joint limits. Resampling to the
scene fps is not performed: the source frame rate must match `fps` or be converted
beforehand (`source_fps` is reported).
