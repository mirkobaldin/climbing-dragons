"""Rig/animation helpers shared by this skill's Blender scripts (bpy required).

Naming: DEF-<joint> deform bones (exported), CTRL-<joint> FK controls,
MCH-<joint> IK mechanism, plus CTRL-torso, CTRL-foot_ik_<chain>_<S>,
CTRL-pole_<chain>_<S>, MCH-ankle_tgt_<chain>_<S> (and wing IK variants).

Blender >= 4.4 layered Actions: one slot per action, channelbag via
bpy_extras.anim_utils (API probed on Blender 5.2.2; see verified-sources.md).

STATUS: implemented, untested.
"""
from __future__ import annotations

import fnmatch
import math
import re
from typing import Iterable

DEF, CTRL, MCH = "DEF-", "CTRL-", "MCH-"
ROT = {"rot_x": ("rotation_euler", 0), "rot_y": ("rotation_euler", 1), "rot_z": ("rotation_euler", 2)}
LOC = {"loc_x": ("location", 0), "loc_y": ("location", 1), "loc_z": ("location", 2)}
CHANNELS = {**ROT, **LOC}
MIRROR_NEGATE = {"rot_y", "rot_z", "loc_x"}


class RigError(ValueError):
    """Configuration or scene problem (message is user-facing)."""


def get_rig(data: dict):
    import bpy
    name = data.get("rig", {}).get("object")
    if not name:
        raise RigError("No rig in manifest; run build_rig.py first.")
    rig = bpy.data.objects.get(name)
    if rig is None or rig.type != "ARMATURE":
        raise RigError(f"Rig object {name!r} not found in the open .blend.")
    return rig


def expand_side(pattern: str) -> list[tuple[str, str | None]]:
    if "{S}" in pattern:
        return [(pattern.replace("{S}", "L"), "L"), (pattern.replace("{S}", "R"), "R")]
    return [(pattern, None)]


def natural_key(s: str):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", s)]


def match_bones(names: Iterable[str], pattern: str) -> list[str]:
    return sorted((n for n in names if fnmatch.fnmatchcase(n, pattern)), key=natural_key)


def mirror_value(channel: str, value: float, side: str | None) -> float:
    return -value if side == "R" and channel in MIRROR_NEGATE else value


def mirror_limits(lim: dict, side: str | None) -> dict:
    """Limits authored for the left side; y/z rotation ranges flip on the right."""
    if side != "R":
        return lim
    out = dict(lim)
    for ax in ("y", "z"):
        if ax in lim:
            lo, hi = lim[ax]
            out[ax] = [-hi, -lo]
    return out


def limits_for(joint: str, table: dict) -> dict | None:
    side = "R" if joint.endswith("_R") else ("L" if joint.endswith("_L") else None)
    for pattern, lim in table.items():
        if fnmatch.fnmatchcase(joint, pattern):
            return mirror_limits(lim, side)
    return None


# --------------------------------------------------------------------------- waveforms

def smoothstep(x: float) -> float:
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def ease(x: float, kind: str) -> float:
    x = min(max(x, 0.0), 1.0)
    if kind == "linear":
        return x
    if kind == "in":
        return x * x
    if kind == "out":
        return 1 - (1 - x) ** 2
    return smoothstep(x)


def wave(kind: str, p: float, down: float = 0.5) -> float:
    """Periodic shapes with period 1.
    sine/cos: standard. stroke: +1 at p=0 (top) -> -1 at p=down (bottom) -> +1,
    with zero slope at both extremes. fold: 0 during the downstroke, a 0..1..0 bump
    during the upstroke (wing folding)."""
    p = p % 1.0
    if kind == "sine":
        return math.sin(2 * math.pi * p)
    if kind == "cos":
        return math.cos(2 * math.pi * p)
    if kind == "stroke":
        if p < down:
            return math.cos(math.pi * p / down)
        return -math.cos(math.pi * (p - down) / (1 - down))
    if kind == "fold":
        return 0.0 if p < down else math.sin(math.pi * (p - down) / (1 - down))
    raise RigError(f"Unknown wave {kind!r} (sine, cos, stroke, fold)")


# --------------------------------------------------------------------------- actions (layered API)

def ensure_action(rig, name: str, clear: bool = True):
    """Get/create Action `name` with one OBJECT slot; return (action, slot, channelbag)."""
    import bpy
    from bpy_extras import anim_utils
    act = bpy.data.actions.get(name)
    if act is None:
        act = bpy.data.actions.new(name)
        act.name = name
    act.use_fake_user = True
    slot = act.slots[0] if len(act.slots) else act.slots.new(id_type="OBJECT", name=rig.name)
    cb = anim_utils.action_ensure_channelbag_for_slot(act, slot)
    if clear:
        cb.fcurves.clear()
    return act, slot, cb


def assign_action(rig, act, slot=None) -> None:
    ad = rig.animation_data or rig.animation_data_create()
    ad.action = act
    if slot is None:
        slot = act.slots[0] if len(act.slots) else None
    if slot is not None and ad.action_slot != slot:
        ad.action_slot = slot


def channelbag(act):
    from bpy_extras import anim_utils
    if not len(act.slots):
        return None
    return anim_utils.action_get_channelbag_for_slot(act, act.slots[0])


def all_fcurves(act):
    for layer in act.layers:
        for strip in layer.strips:
            for cb in strip.channelbags:
                yield from cb.fcurves


def write_curve(cb, data_path: str, index: int, frames, values, group: str,
                handle: str = "AUTO_CLAMPED", cyclic: bool = False):
    fc = cb.fcurves.find(data_path, index=index)
    if fc is None:
        fc = cb.fcurves.new(data_path, index=index, group_name=group)
    fc.keyframe_points.clear()
    n = len(frames)
    fc.keyframe_points.add(n)
    co = []
    for f, v in zip(frames, values):
        co += [float(f), float(v)]
    fc.keyframe_points.foreach_set("co", co)
    for kp in fc.keyframe_points:
        kp.interpolation = "BEZIER"
        kp.handle_left_type = handle
        kp.handle_right_type = handle
    for m in list(fc.modifiers):
        fc.modifiers.remove(m)
    if cyclic:
        fc.modifiers.new("CYCLES")
    fc.update()
    return fc


def fix_quaternion_continuity(act) -> int:
    """Flip quaternion keys whose dot with the previous key is negative."""
    groups: dict[str, dict[int, object]] = {}
    for fc in all_fcurves(act):
        if fc.data_path.endswith("rotation_quaternion"):
            groups.setdefault(fc.data_path, {})[fc.array_index] = fc
    flips = 0
    for comps in groups.values():
        if len(comps) != 4:
            continue
        fcs = [comps[i] for i in range(4)]
        n = min(len(fc.keyframe_points) for fc in fcs)
        prev = None
        for k in range(n):
            q = [fc.keyframe_points[k].co[1] for fc in fcs]
            if prev is not None and sum(a * b for a, b in zip(prev, q)) < 0:
                q = [-x for x in q]
                for fc, val in zip(fcs, q):
                    kp = fc.keyframe_points[k]
                    d = val - kp.co[1]
                    kp.co[1] = val
                    kp.handle_left[1] += d
                    kp.handle_right[1] += d
                flips += 1
            prev = q
        for fc in fcs:
            fc.update()
    return flips


def data_path(bone: str, prop: str) -> str:
    return f'pose.bones["{bone}"].{prop}'
