# Animation: clip design, curves, review

Read before editing `config/animation_config.json` or when reviewing clip quality.

## Contents
1. Clip model · 2. Idle · 3. Walk · 4. Takeoff · 5. Fly · 6. Land (optional) ·
7. Curves, loops, rotations · 8. Review: smoothing is not animation

## 1. Clip model

Value of a control channel at normalised time t = static `pose` + eased `keys` +
`oscillators` + `gait`. Oscillator: `amp · growth^i · wave(cycles·t + phase − lag·i)`
for the i-th matched bone in natural order (tail_01, tail_02, …) — `lag` and
`amp_growth` create overlapping action down a chain. Waves: `sine`, `cos`,
`stroke` (+1 top → −1 at `down` → +1, zero slope at the extremes), `fold` (0 during
downstroke, bump during upstroke). Optional `t_range` + `fade` restrict an
oscillator in time (e.g. flaps starting after lift-off). Keys: `{t, ease, pose}` with
`ease` = smooth | in (accelerating, push-off) | out (decelerating, settle) | linear,
or `pose: "@Clip:phase"` to copy another clip's pose (Takeoff ends on Fly frame 0).
Avoid putting the same channel in `pose` and `keys` (they add up).

All clips are **in place** (Roblox moves the character; animation root motion is not
used). Foot contact is achieved relative to a body that is assumed to move at
`speed_mps`; game code should match it (`speed_studs_per_s_estimate`, using the
0.28 m/stud estimate — confirm in Studio).

## 2. Idle (loop, 4 s)

Breathing on spine (2 cycles), subtle torso lift, neck drift, head look, tail sway
with lag/growth, small jaw motion, wings folded with tiny shuffles. Keep amplitudes
small; the eye reads idle stiffness from the head and tail first.

## 3. Walk (loop)

Lateral-sequence quadruped walk: LH 0, LF 0.25, RH 0.5, RF 0.75; duty 0.62 (each foot
on the ground 62 % of the cycle). Stance: foot control moves back by `stride·duty` at
exactly body speed (planted in the world). Swing: smoothstep forward, sine lift,
toe pitch. Body: two vertical bobs per cycle, lateral sway and roll once per cycle,
neck/head counter-motion to stabilise the head, tail sway with lag. Check sliding with
`curve_audit.py` (`max_cm_per_frame` during contact).

## 4. Takeoff (one-shot, `lift_t` 0.5)

Anticipation (0 → 0.3): crouch (torso down, nose down), wings raised and half
folded, tail up. Push-off (0.3 → 0.45, ease *in*): torso up/forward, powerful first
downstroke, feet still planted (explicit zero keys). Lift (0.45 → 0.55, ease *out*):
feet leave the ground and tuck; wings recover. Climb stroke (0.75), then blend into the
Fly frame 0 pose. Game code should start moving the root upward from
`root_motion_hint.lift_frame`; before that the creature is grounded.

## 5. Fly (loop)

Humerus `stroke` (down fraction 0.55: slower, stronger downstroke) plus forward sweep;
forearm and digits `fold` on the upstroke with phase lag (digits trail the arm);
digit stroke lag for membrane drag. Body rises during the downstroke (torso loc_z
sine, phase −0.05) and pitches slightly; neck/head counter-rotate; tail undulates with
lag. Legs tucked via static foot-control pose. Wing strokes and body motion share one
cycle count so the loop closes exactly.

## 6. Land (optional extension, disabled)

Flare (wings forward/up, body pitched up, legs extended), touchdown with ease-in,
absorption (torso drop), settle and fold wings. Untested; enable with `enabled: true`.

## 7. Curves, loops, rotations

* Keys on controls only, every `key_step` frames, Bezier + **Auto Clamped** handles
  (no overshoot at extremes). Loop clips: integer cycles (enforced), last key = first
  key, optional Cycles F-modifier so auto handles are computed cyclically.
* Controls use Euler XYZ (readable, limit-friendly); retargeting uses
  `make_compatible` to avoid ±360° jumps. Deform bones are baked as quaternions and
  their sign is made continuous (`fix_quaternion_continuity`) before export.
* `curve_audit.py` checks: loop pose/velocity continuity, Euler jumps, joint-limit
  clamping, foot sliding, root motion, Takeoff→Fly transition.

## 8. Review: smoothing is not animation

Clean curves and zero sliding are necessary, not sufficient. Review snapshots or a
playblast for: weight (does the body sink into contacts?), timing/spacing (slow-in on
extremes, fast push-off), arcs (wing tips trace arcs, not straight lines), overlapping
action (neck, tail, digits lag), silhouette readability, and anatomy (no joint
hyper-extension, wings not cutting through the body). Never report a clip as
"good animation" from metrics alone; report metrics and what still needs eyes.
