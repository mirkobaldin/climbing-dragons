"""Stage `animation`: procedural control-bone Actions from config/animation_config.json.

  python run_stage.py run animate_cycles --manifest P -- [--clips Idle,Walk,Takeoff,Fly] [--key-step 2]

One Action per clip (ANIM_<Clip>, fake user, one slot), keys on CTRL-* bones only
(never on DEF-*; baking happens in bake_export.py). Channel value =
  static pose + keyed poses (eased) + oscillators + gait, sampled every key_step
frames, Bezier with Auto Clamped handles. Loop clips: integer cycles enforced,
last key = first key, optional Cycles F-modifier for cyclic handle smoothing.
Rotation channels are Euler degrees in bone-local space (+rot_x moves the bone tip
toward its local +Z: up for axial bones and wings, toward the pole for limbs);
rot_y/rot_z/loc_x are negated on the right side for `{S}` patterns.

Gait (in place, for Roblox): each foot IK control alternates stance (moves back at
exactly the body speed v = stride / cycle_time, so the foot is planted in the world)
and swing (smoothstep forward + sin lift). v is stored as speed_mps.

This creates a technically clean starting point. Timing, weight, arcs and overlap
still need artistic review; smooth curves are not proof of convincing motion.

STATUS: implemented, untested.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402
import rig_common as rc  # noqa: E402

STAGE = "animation"


class ClipBuilder:
    def __init__(self, rig, clips: dict, warnings: list):
        self.rig = rig
        self.bones = list(rig.pose.bones.keys())
        self.clips = clips
        self.warnings = warnings

    def _targets(self, pattern):
        out = []
        for pat, side in rc.expand_side(pattern):
            names = rc.match_bones(self.bones, pat)
            if not names:
                self.warnings.append(f"pattern {pat!r} matches no bone")
            out.append((names, side))
        return out

    def channels(self, name: str, depth: int = 0) -> dict:
        """Return {(bone, channel): [callable(tn) -> value]} for clip `name`."""
        if depth > 3:
            raise pc.PipelineError(f"Clip reference cycle involving {name}")
        spec = self.clips.get(name)
        if spec is None:
            raise pc.PipelineError(f"Unknown clip {name!r}")
        ch: dict = {}

        def add(bone, channel, fn):
            if channel not in rc.CHANNELS:
                raise pc.PipelineError(f"{name}: unknown channel {channel!r}")
            ch.setdefault((bone, channel), []).append(fn)

        for pattern, pose in spec.get("pose", {}).items():
            for names, side in self._targets(pattern):
                for b in names:
                    for kind, axes in (("rot", ("rot_x", "rot_y", "rot_z")), ("loc", ("loc_x", "loc_y", "loc_z"))):
                        for axis, v in zip(axes, pose.get(kind, [])):
                            if v:
                                val = rc.mirror_value(axis, float(v), side)
                                add(b, axis, lambda tn, val=val: val)
        loop = bool(spec.get("loop"))
        for osc in spec.get("oscillators", []):
            cycles = float(osc.get("cycles", 1))
            if loop and abs(cycles - round(cycles)) > 1e-9:
                raise pc.PipelineError(f"{name}: looping clip needs integer cycles (got {cycles})")
            for names, side in self._targets(osc["bones"]):
                for i, b in enumerate(names):
                    amp = float(osc["amp"]) * float(osc.get("amp_growth", 1.0)) ** i
                    amp = rc.mirror_value(osc["channel"], amp, side)
                    ph = float(osc.get("phase", 0.0)) - float(osc.get("lag", 0.0)) * i
                    if side == "R":
                        ph += float(osc.get("phase_R", 0.0))
                    off = rc.mirror_value(osc["channel"], float(osc.get("offset", 0.0)), side)
                    t0, t1 = osc.get("t_range", [0.0, 1.0])
                    fade = float(osc.get("fade", 0.0))

                    def fn(tn, amp=amp, ph=ph, off=off, cycles=cycles, kind=osc.get("wave", "sine"),
                           down=float(osc.get("down", 0.5)), t0=t0, t1=t1, fade=fade):
                        if tn < t0 or tn > t1:
                            return 0.0
                        env = 1.0
                        if fade > 0:
                            env = min(rc.smoothstep((tn - t0) / fade), rc.smoothstep((t1 - tn) / fade))
                        return env * (off + amp * rc.wave(kind, cycles * tn + ph, down))
                    add(b, osc["channel"], fn)
        gait = spec.get("gait")
        if gait:
            duty, stride, lift = float(gait["duty"]), float(gait["stride_m"]), float(gait["lift_m"])
            pitch = float(gait.get("foot_pitch_deg", 0.0))
            travel = stride * duty
            for foot, offset in gait["feet"].items():
                if foot not in self.bones:
                    self.warnings.append(f"gait foot control {foot!r} not in rig")
                    continue

                def phase(tn, offset=float(offset)):
                    return (tn + offset) % 1.0

                def fwd(tn, phase=phase):
                    p = phase(tn)
                    if p < duty:
                        return travel * (0.5 - p / duty)
                    return travel * (-0.5 + rc.smoothstep((p - duty) / (1 - duty)))

                def up(tn, phase=phase):
                    p = phase(tn)
                    return 0.0 if p < duty else lift * math.sin(math.pi * (p - duty) / (1 - duty))

                def tilt(tn, phase=phase):
                    p = phase(tn)
                    return 0.0 if p < duty else -pitch * math.sin(math.pi * (p - duty) / (1 - duty))
                add(foot, "loc_y", fwd)
                add(foot, "loc_z", up)
                if pitch:
                    add(foot, "rot_x", tilt)
        keys = spec.get("keys")
        if keys:
            tracks: dict = {}
            for k in sorted(keys, key=lambda k: float(k["t"])):
                t, ez = float(k["t"]), k.get("ease", "smooth")
                if isinstance(k.get("pose"), str) and k["pose"].startswith("@"):
                    ref, _, ph = k["pose"][1:].partition(":")
                    other = self.channels(ref, depth + 1)
                    for key, fns in other.items():
                        tracks.setdefault(key, []).append((t, sum(f(float(ph or 0)) for f in fns), ez))
                    continue
                for pattern, pose in k.get("pose", {}).items():
                    for names, side in self._targets(pattern):
                        for b in names:
                            for kind, axes in (("rot", ("rot_x", "rot_y", "rot_z")), ("loc", ("loc_x", "loc_y", "loc_z"))):
                                for axis, v in zip(axes, pose.get(kind, [])):
                                    if v is None:
                                        continue
                                    tracks.setdefault((b, axis), []).append(
                                        (t, rc.mirror_value(axis, float(v), side), ez))
            for key, pts in tracks.items():
                if pts[0][0] > 0:
                    pts.insert(0, (0.0, 0.0, "smooth"))

                def interp(tn, pts=pts):
                    if tn <= pts[0][0]:
                        return pts[0][1]
                    for (ta, va, _), (tb, vb, ez) in zip(pts, pts[1:]):
                        if tn <= tb:
                            return va + (vb - va) * rc.ease((tn - ta) / max(tb - ta, 1e-9), ez)
                    return pts[-1][1]
                add(key[0], key[1], interp)
        return ch


def run(params: dict) -> dict:
    import bpy
    pc.require_blender()
    mpath, data = pc.load_manifest(params["manifest"])
    pc.check_retry_budget(data, STAGE)
    if data["stages"].get("rig_build", {}).get("status") not in ("done", "approved"):
        raise pc.PipelineError("Run build_rig.py first.")
    pc.ensure_working_blend(mpath, data, adopt_current=bool(params.get("adopt_current")))
    pc.ensure_object_mode()
    rig = rc.get_rig(data)
    acfg = pc.load_json(pc.to_abs(mpath, data["paths"]["animation_config"]), "Animation config")
    fps = int(acfg.get("fps", 30))
    step = int(params.get("key_step") or acfg.get("key_step", 2))
    clips = {k: v for k, v in acfg["clips"].items() if v.get("enabled", True)}
    wanted = pc.csv_list(params.get("clips")) or list(clips)
    unknown = [c for c in wanted if c not in clips]
    if unknown:
        raise pc.PipelineError(f"Clips not in config or disabled: {unknown}")
    ihash = pc.fingerprint([pc.to_abs(mpath, data["paths"]["animation_config"])],
                           {"clips": wanted, "step": step, "rig": data.get("rig", {}).get("built_at")})
    if pc.should_skip(data, STAGE, ihash, params.get("force", False)):
        return {"skipped": True, "reason": "inputs unchanged", "stage": STAGE}
    log = pc.StageLog(mpath, STAGE)
    scene = bpy.context.scene
    scene.render.fps, scene.render.fps_base = fps, 1.0
    warnings: list[str] = []
    builder = ClipBuilder(rig, acfg["clips"], warnings)
    anims = data.setdefault("animations", {})
    made = {}
    for name in wanted:
        spec = clips[name]
        start, end = int(spec["frames"][0]), int(spec["frames"][1])
        if end <= start:
            raise pc.PipelineError(f"{name}: frames must be [start, end] with end > start")
        loop = bool(spec.get("loop"))
        chans = builder.channels(name)
        frames = list(range(start, end + 1, step))
        if frames[-1] != end:
            frames.append(end)
        act, slot, cb = rc.ensure_action(rig, f"ANIM_{name}")
        act.use_frame_range = True
        act.frame_start, act.frame_end = start, end
        act.use_cyclic = loop
        nkeys = 0
        for (bone, channel), fns in sorted(chans.items()):
            pb = rig.pose.bones[bone]
            prop, idx = rc.CHANNELS[channel]
            if prop == "rotation_euler" and pb.rotation_mode in ("QUATERNION", "AXIS_ANGLE"):
                raise pc.PipelineError(f"{bone} uses {pb.rotation_mode}; animate Euler controls only")
            vals = [sum(f((fr - start) / (end - start)) for f in fns) for fr in frames]
            if loop:
                vals[-1] = vals[0]
            if prop == "rotation_euler":
                vals = [math.radians(v) for v in vals]
            rc.write_curve(cb, rc.data_path(bone, prop), idx, frames, vals, bone,
                           cyclic=loop and bool(acfg.get("cyclic_modifier", True)))
            nkeys += len(frames)
        rec = {"action": act.name, "frames": [start, end], "fps": fps, "loop": loop, "source": "procedural",
               "in_place": True, "keys": nkeys, "channels": len(chans)}
        if spec.get("gait"):
            g = spec["gait"]
            seconds = (end - start) / fps
            rec["speed_mps"] = round(float(g["stride_m"]) / seconds, 4)
            mps = float(data.get("units", {}).get("meters_per_stud", 0.28))
            rec["speed_studs_per_s_estimate"] = round(rec["speed_mps"] / mps, 3)
        if spec.get("lift_t") is not None:
            rec["root_motion_hint"] = {"lift_frame": round(start + float(spec["lift_t"]) * (end - start)),
                                       "note": "game code should start moving the root upward from this frame"}
        anims[name] = rec
        made[name] = {"channels": len(chans), "keys": nkeys, "loop": loop, "speed_mps": rec.get("speed_mps")}
    first = anims.get(wanted[0], {}).get("action")
    if first:
        rc.assign_action(rig, bpy.data.actions[first])
    pc.sync_stage_defects(data, STAGE, [("warning", w, []) for w in sorted(set(warnings))[:20]])
    log.dump("details", {"clips": made, "warnings": warnings})
    pc.set_stage(data, STAGE, "done", {"clips": list(made), "warnings": len(set(warnings))},
                 pc.to_rel(mpath, log.path), ihash)
    for s in ("curve_audit", "bake_export"):
        if data["stages"].get(s, {}).get("status") in ("done", "approved"):
            pc.set_stage(data, s, "stale")
    saved = pc.save_working(mpath, data, params.get("save"))
    pc.save_manifest(mpath, data)
    log.close()
    return {"stage": STAGE, "clips": made, "warnings": sorted(set(warnings))[:8], "saved_blend": saved}


def main() -> None:
    p = pc.base_parser(__doc__)
    p.add_argument("--clips", help="Comma-separated clip names (default: all enabled)")
    p.add_argument("--key-step", type=int)
    pc.cli_entry(run, p)


if __name__ == "__main__":
    main()
