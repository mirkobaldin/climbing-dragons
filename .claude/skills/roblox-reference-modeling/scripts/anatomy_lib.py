"""Procedural anatomy generators (Blender-side; needs mathutils, not bpy).

Produces explicit mesh data (verts, faces, per-corner UVs) for skeletal
components and wing membranes, plus the joint list used by the rigging skill.
Algorithms are documented in references/procedural-anatomy.md.

Conventions: meters, Z up, creature faces -Y, creature left = +X.
Bilateral components are generated for the left side and mirrored (x -> -x,
face winding reversed) unless the component sets "symmetry": false.

STATUS: implemented, untested.
"""
from __future__ import annotations

import math
import re
from typing import Any, Sequence

from mathutils import Quaternion, Vector

Z_UP = Vector((0.0, 0.0, 1.0))


class AnatomyError(ValueError):
    """Invalid anatomy configuration (message is user-facing)."""


# --------------------------------------------------------------------------- landmarks

class Landmarks:
    """Landmark lookup with side substitution, auto-mirroring and offsets.

    A reference can be: "name", "name_{S}", [x, y, z],
    {"lm": ref, "offset": [x, y, z]}, or {"lerp": [ref_a, ref_b, t]}."""

    def __init__(self, coords: dict[str, Sequence[float]]):
        self.co = {k: Vector(v[:3]) for k, v in coords.items()}
        self.used: set[str] = set()

    def get(self, ref: Any, side: str | None = None) -> Vector:
        if isinstance(ref, (list, tuple)) and len(ref) == 3 and all(isinstance(x, (int, float)) for x in ref):
            v = Vector(ref)
            return Vector((-v.x, v.y, v.z)) if side == "R" else v
        if isinstance(ref, dict):
            if "lm" in ref:
                base = self.get(ref["lm"], side)
                off = Vector(ref.get("offset", (0, 0, 0)))
                if side == "R":
                    off.x = -off.x
                return base + off
            if "lerp" in ref:
                a, b, t = ref["lerp"]
                return self.get(a, side).lerp(self.get(b, side), float(t))
            raise AnatomyError(f"Bad landmark reference {ref!r}")
        if not isinstance(ref, str):
            raise AnatomyError(f"Bad landmark reference {ref!r}")
        name = ref.replace("{S}", side or "C")
        if "{S}" in ref and side is None:
            raise AnatomyError(f"Reference {ref!r} needs a side but component is central")
        self.used.add(name)
        if name in self.co:
            return self.co[name].copy()
        if name.endswith("_R") and name[:-2] + "_L" in self.co:
            v = self.co[name[:-2] + "_L"]
            return Vector((-v.x, v.y, v.z))
        if name.endswith("_L") and name[:-2] + "_R" in self.co:
            v = self.co[name[:-2] + "_R"]
            return Vector((-v.x, v.y, v.z))
        raise AnatomyError(f"Unknown landmark {name!r}")


def side_name(template: str, side: str | None) -> str:
    return template.replace("{S}", side) if side else template.replace("_{S}", "").replace("{S}", "")


def swap_side(name: str) -> str:
    return re.sub(r"_L$", "_R", name)


# --------------------------------------------------------------------------- curves

def catmull_rom(points: Sequence[Vector], samples: int = 12, alpha: float = 0.5) -> list[Vector]:
    pts = [Vector(p) for p in points]
    if len(pts) < 2:
        raise AnatomyError("A path needs at least two points")
    if len(pts) == 2:
        return [pts[0].lerp(pts[1], i / samples) for i in range(samples + 1)]
    ext = [pts[0] + (pts[0] - pts[1])] + pts + [pts[-1] + (pts[-1] - pts[-2])]
    out: list[Vector] = []
    for i in range(1, len(ext) - 2):
        seg = _cr_segment(ext[i - 1], ext[i], ext[i + 1], ext[i + 2], samples, alpha)
        out.extend(seg if i == 1 else seg[1:])
    return out


def _cr_segment(p0, p1, p2, p3, n, alpha):
    def knot(ti, a, b):
        return ti + max((b - a).length, 1e-9) ** alpha
    t0 = 0.0
    t1 = knot(t0, p0, p1)
    t2 = knot(t1, p1, p2)
    t3 = knot(t2, p2, p3)
    res = []
    for k in range(n + 1):
        t = t1 + (t2 - t1) * k / n
        a1 = p0 * ((t1 - t) / (t1 - t0)) + p1 * ((t - t0) / (t1 - t0))
        a2 = p1 * ((t2 - t) / (t2 - t1)) + p2 * ((t - t1) / (t2 - t1))
        a3 = p2 * ((t3 - t) / (t3 - t2)) + p3 * ((t - t2) / (t3 - t2))
        b1 = a1 * ((t2 - t) / (t2 - t0)) + a2 * ((t - t0) / (t2 - t0))
        b2 = a2 * ((t3 - t) / (t3 - t1)) + a3 * ((t - t1) / (t3 - t1))
        res.append(b1 * ((t2 - t) / (t2 - t1)) + b2 * ((t - t1) / (t2 - t1)))
    return res


def resample(points: Sequence[Vector], count: int) -> tuple[list[Vector], float]:
    if count < 2:
        raise AnatomyError("resample count must be >= 2")
    cum = [0.0]
    for a, b in zip(points, points[1:]):
        cum.append(cum[-1] + (b - a).length)
    total = cum[-1]
    if total < 1e-9:
        raise AnatomyError("Degenerate path (zero length) - check landmark positions")
    out, j = [], 0
    for i in range(count):
        s = total * i / (count - 1)
        while j < len(cum) - 2 and cum[j + 1] < s:
            j += 1
        seg = cum[j + 1] - cum[j]
        f = 0.0 if seg < 1e-12 else (s - cum[j]) / seg
        out.append(points[j].lerp(points[j + 1], min(max(f, 0.0), 1.0)))
    return out, total


def smooth_path(points: Sequence[Vector], count: int) -> list[Vector]:
    dense = catmull_rom(points, 16) if len(points) > 2 else catmull_rom(points, 32)
    return resample(dense, count)[0]


def transport_frames(path: Sequence[Vector], up_hint: Vector = Z_UP) -> list[tuple[Vector, Vector, Vector]]:
    """Parallel-transport frames (tangent, normal, binormal=t x n); minimal twist."""
    n = len(path)
    tangents = []
    for i in range(n):
        if i == 0:
            t = path[1] - path[0]
        elif i == n - 1:
            t = path[-1] - path[-2]
        else:
            t = path[i + 1] - path[i - 1]
        if t.length < 1e-12:
            t = tangents[-1] if tangents else Vector((0, 1, 0))
        tangents.append(t.normalized())
    up = Vector(up_hint).normalized()
    if abs(tangents[0].dot(up)) > 0.95:
        up = Vector((1, 0, 0)) if abs(tangents[0].x) < 0.9 else Vector((0, 1, 0))
    normal = (up - tangents[0] * up.dot(tangents[0])).normalized()
    frames = []
    for i, t in enumerate(tangents):
        if i > 0:
            prev = tangents[i - 1]
            axis = prev.cross(t)
            if axis.length > 1e-9:
                normal = Quaternion(axis.normalized(), prev.angle(t, 0.0)) @ normal
            normal = (normal - t * normal.dot(t)).normalized()
        frames.append((t.copy(), normal.copy(), t.cross(normal).normalized()))
    return frames


def profile(values: Sequence, s: float) -> float:
    """Piecewise-linear interpolation of evenly spaced values, or [[t, v], ...] pairs."""
    if isinstance(values, (int, float)):
        return float(values)
    vals = list(values)
    if vals and isinstance(vals[0], (list, tuple)):
        pts = sorted((float(a), float(b)) for a, b in vals)
        if s <= pts[0][0]:
            return pts[0][1]
        for (t0, v0), (t1, v1) in zip(pts, pts[1:]):
            if s <= t1:
                return v0 + (v1 - v0) * ((s - t0) / max(t1 - t0, 1e-9))
        return pts[-1][1]
    if len(vals) == 1:
        return float(vals[0])
    x = min(max(s, 0.0), 1.0) * (len(vals) - 1)
    i = min(int(x), len(vals) - 2)
    return float(vals[i]) + (float(vals[i + 1]) - float(vals[i])) * (x - i)


# --------------------------------------------------------------------------- mesh parts

def new_part(name, role, side, bone_hint="", **props) -> dict:
    return {"name": name, "role": role, "side": side, "bone_hint": bone_hint,
            "verts": [], "faces": [], "uvs": [], "props": props}


def append_geo(part: dict, geo: dict) -> dict:
    off = len(part["verts"])
    part["verts"].extend(geo["verts"])
    part["faces"].extend(tuple(i + off for i in f) for f in geo["faces"])
    part["uvs"].extend(geo["uvs"])
    return part


def swept_solid(path: Sequence[Vector], segments: int, widths: Sequence[float], heights: Sequence[float],
                up_hint: Vector = Z_UP, cap_start: bool = True, cap_end: bool = True,
                tip_end: bool = False) -> dict:
    """Elliptical cross-sections swept along `path` (outward winding)."""
    S = len(path)
    if S < 2 or segments < 3:
        raise AnatomyError("swept_solid needs >= 2 stations and >= 3 segments")
    frames = transport_frames(path, up_hint)
    cum = [0.0]
    for a, b in zip(path, path[1:]):
        cum.append(cum[-1] + (b - a).length)
    total = max(cum[-1], 1e-9)
    rings = S - 1 if tip_end else S
    verts, faces, uvs = [], [], []
    for i in range(rings):
        c = path[i]
        _, nrm, bin_ = frames[i]
        w, h = max(widths[i], 1e-4), max(heights[i], 1e-4)
        for k in range(segments):
            a = 2.0 * math.pi * k / segments
            verts.append(c + bin_ * (math.cos(a) * w) + nrm * (math.sin(a) * h))

    def r(i, k):
        return i * segments + (k % segments)

    def uv(i, k):
        return (1.0 if k == segments else k / segments, cum[i] / total)

    for i in range(rings - 1):
        for k in range(segments):
            faces.append((r(i, k), r(i + 1, k), r(i + 1, k + 1), r(i, k + 1)))
            uvs.append((uv(i, k), uv(i + 1, k), uv(i + 1, k + 1), uv(i, k + 1)))
    if tip_end:
        tip = len(verts)
        verts.append(path[-1].copy())
        i = rings - 1
        for k in range(segments):
            faces.append((r(i, k), tip, r(i, k + 1)))
            uvs.append((uv(i, k), ((k + 0.5) / segments, 1.0), uv(i, k + 1)))
    else:
        if cap_end:
            ce = len(verts)
            verts.append(path[-1].copy())
            i = S - 1
            for k in range(segments):
                faces.append((ce, r(i, k + 1), r(i, k)))
                uvs.append(((0.5, 0.5), _cap_uv(k + 1, segments), _cap_uv(k, segments)))
    if cap_start:
        cs = len(verts)
        verts.append(path[0].copy())
        for k in range(segments):
            faces.append((cs, r(0, k), r(0, k + 1)))
            uvs.append(((0.5, 0.5), _cap_uv(k, segments), _cap_uv(k + 1, segments)))
    return {"verts": verts, "faces": faces, "uvs": uvs}


def _cap_uv(k, n):
    a = 2.0 * math.pi * k / n
    return (0.5 + 0.5 * math.cos(a), 0.5 + 0.5 * math.sin(a))


LONG_BONE = [[0.0, 0.75], [0.07, 1.0], [0.25, 0.62], [0.5, 0.55], [0.75, 0.62], [0.93, 1.0], [1.0, 0.75]]


def tube(path_pts: Sequence[Vector], stations: int, segments: int, radius: float,
         radius_profile=None, flatten: float = 1.0, up_hint: Vector = Z_UP,
         tip: bool = False, caps: bool = True, smooth: bool = True) -> dict:
    path = smooth_path(path_pts, stations) if smooth else resample(list(path_pts), stations)[0]
    prof = radius_profile or [[0, 1.0], [1, 1.0]]
    ws = [radius * profile(prof, i / (stations - 1)) for i in range(stations)]
    hs = [w * flatten for w in ws]
    return swept_solid(path, segments, ws, hs, up_hint, cap_start=caps, cap_end=caps and not tip, tip_end=tip)


def curved_cone(base: Vector, direction: Vector, bend: Vector, length: float, radius: float,
                curve_deg: float, stations: int, segments: int) -> dict:
    d = direction.normalized()
    perp = bend - d * bend.dot(d)
    axis = d.cross(perp.normalized()) if perp.length > 1e-6 else Vector((0, 0, 0))
    step = length / (stations - 1)
    dang = math.radians(curve_deg) / (stations - 1)
    pts, p = [base.copy()], base.copy()
    for _ in range(stations - 1):
        p = p + d * step
        pts.append(p.copy())
        if axis.length > 0:
            d = Quaternion(axis, dang) @ d
    ws = [radius * (1.0 - i / (stations - 1)) ** 0.9 for i in range(stations)]
    return swept_solid(pts, segments, ws, ws, Z_UP if abs(direction.normalized().z) < 0.9 else Vector((0, 1, 0)),
                       cap_start=True, tip_end=True)


def mirror_part(part: dict) -> dict:
    m = dict(part)
    m["name"] = swap_side(part["name"])
    m["side"] = "R"
    m["bone_hint"] = swap_side(part["bone_hint"]) if part["bone_hint"] else ""
    m["verts"] = [Vector((-v.x, v.y, v.z)) for v in part["verts"]]
    m["faces"] = [tuple(reversed(f)) for f in part["faces"]]
    m["uvs"] = [tuple(reversed(u)) for u in part["uvs"]]
    m["props"] = dict(part["props"])
    if "influences" in m["props"]:
        m["props"]["influences"] = [swap_side(x) for x in part["props"]["influences"]]
    return m


# --------------------------------------------------------------------------- joints

def resolve_joints(joint_cfg: dict, lm: Landmarks) -> tuple[list[dict], dict]:
    """Return (joints, chains) where chains maps 'key|side' -> ordered joint names."""
    joints: list[dict] = []
    by_name: dict[str, dict] = {}
    chains: dict[str, list[str]] = {}
    for key, spec in joint_cfg.items():
        sides = ["L", "R"] if spec.get("side") == "LR" else [None]
        for side in sides:
            pts = [lm.get(p, side) for p in spec["points"]]
            names = spec.get("names")
            nb = len(names) if names else int(spec.get("bones", len(pts) - 1))
            jp = pts if len(pts) == nb + 1 else smooth_path(pts, nb + 1)
            suffix = f"_{side}" if side else ""
            bnames = [(names[i] if names else (key if nb == 1 else f"{key}_{i + 1:02d}")) + suffix
                      for i in range(nb)]
            parent = _resolve_parent(spec.get("parent"), side, chains)
            if parent and parent not in by_name:
                raise AnatomyError(f"Joint chain {key!r}: parent {parent!r} is not defined earlier")
            pole = spec.get("pole_hint")
            if pole and side == "R":
                pole = [-pole[0], pole[1], pole[2]]
            for i in range(nb):
                par = parent if i == 0 else bnames[i - 1]
                head, tail = jp[i], jp[i + 1]
                if (tail - head).length < 1e-4:
                    raise AnatomyError(f"Joint {bnames[i]} has zero length - check landmarks")
                connected = par is not None and (head - Vector(by_name[par]["tail"])).length < 1e-4
                j = {"name": bnames[i], "head": [round(x, 5) for x in head], "tail": [round(x, 5) for x in tail],
                     "parent": par, "side": side or "C", "chain": key,
                     "chain_type": spec.get("type", "axial"), "index": i, "connected": connected}
                if pole:
                    j["pole_hint"] = list(pole)
                joints.append(j)
                by_name[j["name"]] = j
            chains[f"{key}|{side or 'C'}"] = bnames
    return joints, chains


def _resolve_parent(ref: str | None, side: str | None, chains: dict) -> str | None:
    if not ref:
        return None
    ref = ref.replace("{S}", side) if side else ref
    if ":" in ref:
        key, which = ref.split(":", 1)
        lst = chains.get(f"{key}|{side or 'C'}") or chains.get(f"{key}|C")
        if not lst:
            raise AnatomyError(f"Parent chain {key!r} unknown (define it earlier in 'joints')")
        return lst[-1] if which == "last" else lst[0]
    return ref


def expand_influences(refs: Sequence[str], side: str | None, chains: dict) -> list[str]:
    out = []
    for ref in refs:
        r = ref.replace("{S}", side) if side else ref
        if ":" in r:
            out.append(_resolve_parent(r, side, chains))
            continue
        lst = chains.get(f"{r}|{side or 'C'}") or chains.get(f"{r}|C")
        out.extend(lst if lst else [r])
    seen, uniq = set(), []
    for x in out:
        if x not in seen:
            seen.add(x)
            uniq.append(x)
    return uniq


def chain_bone_for(chains: dict, chain_key: str, side: str | None, i: int, count: int) -> str:
    lst = chains.get(f"{chain_key}|{side or 'C'}") or chains.get(f"{chain_key}|C")
    if not lst:
        raise AnatomyError(f"bone_chain {chain_key!r} not found in joints")
    return lst[min(len(lst) - 1, int(i * len(lst) / max(count, 1)))]


# --------------------------------------------------------------------------- component generators

def _seg(spec, detail, key="segments", default=10, minimum=4):
    return max(minimum, int(round(spec.get(key, default) * detail)))


def gen_tube(key, spec, lm, ctx, side):
    pts = [lm.get(p, side) for p in spec["points"]]
    up = Vector(spec.get("up_hint", (0, 0, 1)))
    geo = tube(pts, _seg(spec, ctx["detail"], "stations", 8, 3), _seg(spec, ctx["detail"]),
               float(spec["radius"]), spec.get("radius_profile"), float(spec.get("flatten", 1.0)),
               up, tip=bool(spec.get("tip", False)))
    part = new_part(ctx["name"](spec.get("name", key), side), spec["role"], side or "C",
                    side_name(spec.get("bone", ""), side))
    return [append_geo(part, geo)]


def gen_loft(key, spec, lm, ctx, side):
    pts = [lm.get(p, side) for p in spec["points"]]
    st = _seg(spec, ctx["detail"], "stations", 10, 4)
    path = smooth_path(pts, st)
    secs = spec["sections"]  # [[t, half_width, half_height, dz], ...]
    ws = [profile([[s[0], s[1]] for s in secs], i / (st - 1)) for i in range(st)]
    hs = [profile([[s[0], s[2]] for s in secs], i / (st - 1)) for i in range(st)]
    dz = [profile([[s[0], s[3] if len(s) > 3 else 0.0] for s in secs], i / (st - 1)) for i in range(st)]
    path = [p + Vector((0, 0, z)) for p, z in zip(path, dz)]
    geo = swept_solid(path, _seg(spec, ctx["detail"], "segments", 16, 6), ws, hs,
                      Vector(spec.get("up_hint", (0, 0, 1))), tip_end=bool(spec.get("tip", False)))
    part = new_part(ctx["name"](spec.get("name", key), side), spec["role"], side or "C",
                    side_name(spec.get("bone", ""), side))
    return [append_geo(part, geo)]


def gen_curved_cone(key, spec, lm, ctx, side):
    base = lm.get(spec["base"], side)
    if "toward" in spec:
        direction = lm.get(spec["toward"], side) - base
    else:
        direction = Vector(spec["direction"])
        if side == "R":
            direction.x = -direction.x
    bend = Vector(spec.get("bend", (0, 0, -1)))
    geo = curved_cone(base, direction, bend, float(spec["length"]), float(spec["radius"]),
                      float(spec.get("curve_deg", 30)), _seg(spec, ctx["detail"], "stations", 6, 3),
                      _seg(spec, ctx["detail"], "segments", 8, 4))
    part = new_part(ctx["name"](spec.get("name", key), side), spec["role"], side or "C",
                    side_name(spec.get("bone", ""), side))
    return [append_geo(part, geo)]


def vertebra_layout(spec, lm, side=None):
    pts = [lm.get(p, side) for p in spec["points"]]
    count = int(spec["count"])
    path = smooth_path(pts, 2 * count + 1)
    frames = transport_frames(path, Vector(spec.get("up_hint", (0, 0, 1))))
    total = sum((b - a).length for a, b in zip(path, path[1:]))
    return [(path[2 * i + 1], frames[2 * i + 1]) for i in range(count)], total / count


def gen_vertebra_chain(key, spec, lm, ctx, side):
    layout, spacing = vertebra_layout(spec, lm, side)
    count = len(layout)
    det = ctx["detail"]
    seg_c = _seg(spec, det, "segments", 10, 5)
    parts = []
    for i, (c, (t, n, b)) in enumerate(layout):
        s = i / max(count - 1, 1)
        r = profile(spec["centrum_radius"], s)
        half = spacing * float(spec.get("length_ratio", 0.75)) / 2.0
        name = ctx["name"](f"{spec.get('name', key)}_{i + 1:02d}", side)
        bone = chain_bone_for(ctx["chains"], spec["bone_chain"], side, i, count)
        part = new_part(name, "vertebra", side or "C", bone, vertebra_index=i)
        append_geo(part, tube([c - t * half, c + t * half], 4, seg_c, r,
                              [[0, 1.0], [0.3, 0.85], [0.7, 0.85], [1, 1.0]], 0.9, n, smooth=False))
        h = profile(spec.get("neural_spine_height", [0.0]), s)
        if h > 1e-4:
            tilt = math.radians(float(spec.get("neural_spine_tilt_deg", 20)))
            base = c + n * (r * 0.8)
            tipp = base + (n * math.cos(tilt) - t * math.sin(tilt)) * h
            ws = [r * 0.22, r * 0.15, r * 0.07]
            hs = [r * 0.55, r * 0.4, r * 0.18]
            append_geo(part, swept_solid([base, base.lerp(tipp, 0.5), tipp], max(4, seg_c // 2), ws, hs, t))
        tl = profile(spec.get("transverse_length", [0.0]), s)
        if tl > 1e-4:
            left = n.cross(t).normalized()
            for sgn in (1.0, -1.0):
                a = c + left * (sgn * r * 0.7) + n * (r * 0.1)
                bpt = c + left * (sgn * (r + tl)) + n * (r * 0.25)
                append_geo(part, tube([a, bpt], 3, max(4, seg_c // 2), r * 0.18,
                                      [[0, 1.0], [1, 0.55]], 0.7, t, smooth=False))
        parts.append(part)
    return parts


def gen_rib_set(key, spec, lm, ctx, side):
    vspec = ctx["components"][spec["vertebrae"]]
    layout, _ = vertebra_layout(vspec, lm, None)
    count = len(layout)
    i0, i1 = spec.get("range", [0, count - 1])
    i1 = min(i1, count - 1)
    det = ctx["detail"]
    side = side or "L"
    parts = []
    for i in range(i0, i1 + 1):
        s = (i - i0) / max(i1 - i0, 1)
        c, (t, n, _b) = layout[i]
        rc = profile(vspec["centrum_radius"], i / max(count - 1, 1))
        left = n.cross(t).normalized() * (1.0 if side == "L" else -1.0)
        spread = profile(spec["spread"], s)
        drop = profile(spec["drop"], s)
        sweep = profile(spec.get("sweep", [0.1]), s)
        pts = [c + left * (rc * 0.9) + n * (rc * 0.4),
               c + left * (spread * 0.85) + n * (rc * 0.2 - drop * 0.1) - t * (sweep * 0.25),
               c + left * spread + n * (-drop * 0.5) - t * (sweep * 0.6),
               c + left * (spread * 0.6) + n * (-drop) - t * sweep]
        r0, r1 = spec.get("radius", [0.025, 0.012])
        geo = tube(pts, _seg(spec, det, "stations", 10, 5), _seg(spec, det, "segments", 6, 4), r0,
                   [[0, 1.0], [1, r1 / r0]], float(spec.get("flatten", 0.6)), t, tip=False)
        bone = chain_bone_for(ctx["chains"], vspec["bone_chain"], None, i, count)
        part = new_part(ctx["name"](f"{spec.get('name', key)}_{i + 1:02d}", side), "rib", side, bone,
                        vertebra_index=i)
        # swept_solid derives right-handed frames from the actual path, so winding is
        # outward on either side; only mirror_part() (vertex reflection) reverses faces.
        parts.append(append_geo(part, geo))
    return parts


def gen_limb_chain(key, spec, lm, ctx, side):
    pts = [lm.get(p, side) for p in spec["points"]]
    names, bones = spec["names"], spec["bones"]
    if len(names) != len(pts) - 1 or len(bones) != len(names):
        raise AnatomyError(f"{key}: names/bones must have len(points)-1 entries")
    radii = spec["radius"] if isinstance(spec["radius"], list) else [spec["radius"]] * len(names)
    gap = float(spec.get("gap", 0.02))
    det = ctx["detail"]
    up = Vector(spec.get("up_hint", (0, 0, 1)))
    parts = []
    for i, nm in enumerate(names):
        a, b = pts[i], pts[i + 1]
        d = b - a
        L = d.length
        if L < 1e-4:
            raise AnatomyError(f"{key}: segment {nm} has zero length")
        g = gap if L > 4 * gap else L * 0.1
        a2, b2 = a + d.normalized() * g, b - d.normalized() * g
        geo = tube([a2, b2], _seg(spec, det, "stations", 7, 4), _seg(spec, det, "segments", 10, 5),
                   float(radii[i]), spec.get("radius_profile", LONG_BONE), float(spec.get("flatten", 0.9)),
                   up, smooth=False)
        part = new_part(ctx["name"](nm, side), spec.get("role", "limb_bone"), side or "C", side_name(bones[i], side))
        parts.append(append_geo(part, geo))
    return parts


def gen_digit_set(key, spec, lm, ctx, side):
    base = lm.get(spec["base"], side)
    toward = lm.get(spec["toward"], side)
    d0 = toward - base
    d0.z = 0.0 if spec.get("flat", True) else d0.z
    if d0.length < 1e-6:
        raise AnatomyError(f"{key}: base and toward coincide")
    d0.normalize()
    n = int(spec.get("digits", 4))
    spread = math.radians(float(spec.get("spread_deg", 60)))
    det = ctx["detail"]
    seg = _seg(spec, det, "segments", 8, 4)
    bone = side_name(spec.get("bone", ""), side)
    claw_bone = side_name(spec.get("claw_bone", spec.get("bone", "")), side)
    parts = []
    for j in range(n):
        ang = 0.0 if n == 1 else -spread / 2 + spread * j / (n - 1)
        dj = Quaternion(Z_UP, ang) @ d0
        pl = float(spec.get("phalanx_length", 0.15))
        gap = float(spec.get("gap", 0.015))
        a, b = base + dj * gap, base + dj * pl
        ph = new_part(ctx["name"](f"{spec.get('name', key)}{j + 1}", side), "limb_bone", side or "C", bone)
        append_geo(ph, tube([a, b], 5, seg, float(spec.get("phalanx_radius", 0.02)), LONG_BONE, 0.85, Z_UP,
                            smooth=False))
        cl = new_part(ctx["name"](f"{spec.get('name', key)}Claw{j + 1}", side), "claw", side or "C", claw_bone)
        append_geo(cl, curved_cone(b + dj * (gap * 0.5), dj, Vector((0, 0, -1)), float(spec.get("claw_length", 0.1)),
                                   float(spec.get("claw_radius", 0.018)), float(spec.get("claw_curve_deg", 60)),
                                   _seg(spec, det, "claw_stations", 6, 3), seg))
        parts += [ph, cl]
    return parts


def gen_spike_row(key, spec, lm, ctx, side):
    pts = [lm.get(p, side) for p in spec["points"]]
    path = smooth_path(pts, 64)
    frames = transport_frames(path)
    n = int(spec.get("count", 8))
    t0, t1 = spec.get("t_range", [0.1, 0.95])
    direction = Vector(spec.get("direction", (0, 0, 1)))
    part = new_part(ctx["name"](spec.get("name", key), side), spec.get("role", "tooth"), side or "C",
                    side_name(spec.get("bone", ""), side))
    seg = _seg(spec, ctx["detail"], "segments", 6, 3)
    for j in range(n):
        s = t0 + (t1 - t0) * (j / max(n - 1, 1))
        idx = min(63, int(round(s * 63)))
        append_geo(part, curved_cone(path[idx], direction, -frames[idx][0],
                                     profile(spec.get("length", [0.04]), s), profile(spec.get("radius", [0.01]), s),
                                     float(spec.get("curve_deg", 10)), 4, seg))
    return [part]


def _chain_points(chains_spec: dict, name: str, lm, side, det, cache: dict) -> list[Vector]:
    if name in cache:
        return cache[name]
    cs = chains_spec[name]
    if "compose" in cs:
        out: list[Vector] = []
        for sub in cs["compose"]:
            pts = _chain_points(chains_spec, sub, lm, side, det, cache)
            out.extend(pts if not out else pts[1:])
    else:
        pts = [lm.get(p, side) for p in cs["points"]]
        rows = max(2, int(round(cs.get("rows", 8) * det)))
        out = smooth_path(pts, rows + 1) if len(pts) > 2 else resample(pts, rows + 1)[0]
    cache[name] = out
    return out


def gen_membrane(key, spec, lm, ctx, side):
    det = ctx["detail"]
    cache: dict = {}
    cols = max(1, int(round(spec.get("cols_per_panel", 4) * det)))
    sag = float(spec.get("sag", 0.2))
    billow = float(spec.get("billow", 0.0))
    panels = spec["panels"]
    verts: list[Vector] = []
    faces, uvs = [], []
    index: dict[tuple, int] = {}
    min_rows = 10 ** 9

    def vid(p: Vector) -> int:
        k = (round(p.x, 6), round(p.y, 6), round(p.z, 6))
        if k not in index:
            index[k] = len(verts)
            verts.append(p.copy())
        return index[k]

    for pi, (an, bn) in enumerate(panels):
        A = _chain_points(spec["chains"], an, lm, side, det, cache)
        B = _chain_points(spec["chains"], bn, lm, side, det, cache)
        if len(B) != len(A):
            B = resample(B, len(A))[0]
        R = len(A) - 1
        min_rows = min(min_rows, R)
        normal = (A[-1] - A[0]).cross(B[-1] - A[0])
        normal = normal.normalized() if normal.length > 1e-9 else Vector((0, 0, 1))
        grid = []
        for r in range(R + 1):
            row = []
            for c in range(cols + 1):
                s = c / cols
                p = A[r].lerp(B[r], s)
                if 0 < c < cols:
                    root_mid, tip_mid = A[0].lerp(B[0], s), A[-1].lerp(B[-1], s)
                    p = p + (root_mid - tip_mid) * (sag * math.sin(math.pi * s) * (r / R) ** 2)
                    p = p + normal * (billow * math.sin(math.pi * s) * math.sin(math.pi * r / R)
                                      * (A[r] - B[r]).length)
                row.append(vid(p))
            grid.append(row)
        for r in range(R):
            for c in range(cols):
                quad = [grid[r][c], grid[r + 1][c], grid[r + 1][c + 1], grid[r][c + 1]]
                quv = [((pi + c / cols) / len(panels), r / R), ((pi + c / cols) / len(panels), (r + 1) / R),
                       ((pi + (c + 1) / cols) / len(panels), (r + 1) / R), ((pi + (c + 1) / cols) / len(panels), r / R)]
                keep = [(v, u) for k, (v, u) in enumerate(zip(quad, quv)) if v not in quad[:k]]
                if len(keep) >= 3:
                    faces.append(tuple(v for v, _ in keep))
                    uvs.append(tuple(u for _, u in keep))
    part = new_part(ctx["name"](spec.get("name", key), side), "membrane", side or "C", "",
                    rbx_rows=min_rows, rbx_cols=cols, thickness=float(spec.get("thickness", 0.012)),
                    influences=expand_influences(spec.get("influences", []), side, ctx["chains"]))
    part["verts"], part["faces"], part["uvs"] = verts, faces, uvs
    return [part]


GENERATORS = {
    "tube": gen_tube, "loft": gen_loft, "curved_cone": gen_curved_cone,
    "vertebra_chain": gen_vertebra_chain, "rib_set": gen_rib_set, "limb_chain": gen_limb_chain,
    "digit_set": gen_digit_set, "spike_row": gen_spike_row, "membrane": gen_membrane,
}


def generate_component(key: str, spec: dict, lm: Landmarks, ctx: dict) -> list[dict]:
    ctype = spec.get("type")
    if ctype not in GENERATORS:
        raise AnatomyError(f"Component {key!r}: unknown type {ctype!r}; valid: {sorted(GENERATORS)}")
    bilateral = spec.get("side", "C") == "LR"
    if ctype == "rib_set":
        bilateral = True
    if not bilateral:
        parts = GENERATORS[ctype](key, spec, lm, ctx, None)
    elif spec.get("symmetry", True):
        left = GENERATORS[ctype](key, spec, lm, ctx, "L")
        parts = left + [mirror_part(p) for p in left]
        if ctype == "rib_set":  # rib bone hints are central bones; do not swap
            for p, q in zip(left, parts[len(left):]):
                q["bone_hint"] = p["bone_hint"]
    else:
        parts = GENERATORS[ctype](key, spec, lm, ctx, "L") + GENERATORS[ctype](key, spec, lm, ctx, "R")
    for p in parts:
        p["key"] = key
    return parts
