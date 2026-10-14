# Rig design: bones, controls, IK/FK, limits

Read before changing `config/rig_config.json`, when IK misbehaves, or when the
rest pose is not reproduced (`rest_drift_m` > 0).

## Layers

| Layer | Prefix | Deform | Exported | Animated | Notes |
|---|---|---|---|---|---|
| Deformation | `DEF-` | yes | yes | only by baking | one per manifest joint, explicit parents mirroring the joint tree; Copy Transforms (world) from its driver |
| Controls | `CTRL-` | no | no | yes (Euler) | FK copy of each joint not driven by IK, plus `CTRL-root`, `CTRL-torso`, foot IK and pole controls |
| Mechanism | `MCH-` | no | no | no | IK chains (legs; wing arm in `ik_arm` mode), ankle targets |

`DEF-root` sits at the origin with no weights (Roblox: root at 0,0,0, no influences).
Bone collections `DEF`, `CTRL`, `MCH` (DEF and MCH hidden by default).

## Hierarchy (example dragon)

```
CTRL-root
├─ CTRL-torso ── CTRL-pelvis ── CTRL-tail_01 … CTRL-tail_08
│               │              └─ MCH-thigh_L ─ MCH-shin_L ─ MCH-metatarsus_L (IK, Damped Track)
│               └─ CTRL-spine_01 … CTRL-spine_03 ─┬─ CTRL-neck_01 … 04 ─ CTRL-head ─ CTRL-jaw
│                                                  ├─ MCH-upperarm_L … (fore leg IK)
│                                                  └─ CTRL-wing_humerus_L ─ CTRL-wing_forearm_L ─ CTRL-wing_d2_01_L …
│               └─ CTRL-pole_leg_hind_L …
└─ CTRL-foot_ik_leg_hind_L ─ MCH-ankle_tgt_leg_hind_L, CTRL-toe_L
```
`ctrl_parent_overrides` (default `spine_01 → torso`) keeps the spine from inheriting
pelvis rotation. Foot controls are children of `CTRL-root`, so lowering `CTRL-torso`
bends the legs while feet stay planted.

## Bone roll convention

Each bone's local Y points along the bone. Roll aligns local Z with:
`pole_hint` for limbs (knee/elbow direction), otherwise world +Z (or ±Y for nearly
vertical bones). Consequence: **+rot_x moves the bone tip toward its local +Z** — up
for spine, neck, tail and wings; toward the pole (flexion direction) for legs.
`rot_z` swings sideways/in the wing plane (fold), `rot_y` twists. For `_R` bones the
animation tools negate rot_y, rot_z and loc_x so left-authored values mirror.

## Legs: IK with poles

Digitigrade legs (3 bones: thigh, shin, metatarsus): IK (chain 2) on the shin targets
`MCH-ankle_tgt` (child of the foot control); `MCH-metatarsus` Damped-Tracks the foot
control head (ball of the foot). Toes are FK under the foot control. Pole controls sit
1.5 × thigh length along `pole_hint` from the knee. `pole_angle` is chosen
numerically (coarse 15° sweep, then 0.5° refinement) to reproduce the rest pose; a
residual > 1° raises a warning. No foot-roll or IK/FK switch is implemented.

## Wings: FK or IK

Default **FK**: wing strokes are rotational arcs at the shoulder with delayed
forearm/digit folding; FK gives direct control of arcs and overlap. **ik_arm**
(2-bone IK on humerus/forearm to `CTRL-ik_wing_arm_<S>`) is useful when the wrist must
stay planted (wyvern walking on wing knuckles, perching). Digits are always FK: their
spread/fold is a fan motion that IK does not express. Choose per anatomy and record
the choice (`--wing-mode`).

## Joint limits

`joint_limits` (left-authored degrees, glob patterns, first match wins):
FK controls get a `Limit Rotation` constraint (`RBX_Limit`, local space, affects
transform tools); IK mechanism bones get `ik_min/max` (`[0, 0]` locks the axis).
Leg flexion (x) is left free on IK bones because its sign depends on the rest angle;
check it in validation scenario 2. Animation values outside limits are clamped in
evaluation and reported by `curve_audit.py` (`limit_hits`).

## Rebuild behaviour

The armature object is kept; bones are rebuilt; pose channels with the same names
survive, so constraints/transforms are reset explicitly. Actions keep working
because names are stable. A checkpoint is saved first. Downstream stages become `stale`.
