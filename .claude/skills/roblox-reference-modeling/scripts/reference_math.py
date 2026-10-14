"""Reference-image math shared by inspect_references.py (plain Python) and
setup_references.py / compare_silhouettes.py (Blender). Stdlib only.

Conventions (see references/reference-analysis.md):
  * Blender world: Z up, creature faces -Y, creature left = +X.
  * Each orthographic view declares which signed world axis points along the
    image's +u (right) and +v (up) directions, e.g. side view seen from +X:
    image_right "+Y", image_up "+Z".
  * Pixel coordinates are (x right, y down) with origin at the top-left corner.

STATUS: implemented, untested.
"""
from __future__ import annotations

import math
import struct
from pathlib import Path

AXES = {"+X": (0, 1.0), "-X": (0, -1.0), "+Y": (1, 1.0), "-Y": (1, -1.0), "+Z": (2, 1.0), "-Z": (2, -1.0)}
AXIS_NAMES = "XYZ"


class ReferenceError_(ValueError):
    """Invalid annotation data (message is user-facing)."""


# --------------------------------------------------------------------------- image headers

def image_info(path: str | Path) -> dict:
    """Width/height for PNG/JPEG plus selected EXIF tags (JPEG). No third-party deps."""
    p = Path(path)
    data = p.read_bytes()
    info: dict = {"path": str(p), "format": None, "width": None, "height": None, "exif": {}}
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        info["format"] = "PNG"
        info["width"], info["height"] = struct.unpack(">II", data[16:24])
        return info
    if data[:2] == b"\xff\xd8":
        info["format"] = "JPEG"
        i = 2
        while i + 4 <= len(data):
            if data[i] != 0xFF:
                i += 1
                continue
            marker = data[i + 1]
            if marker in (0xD8, 0x01) or 0xD0 <= marker <= 0xD7:
                i += 2
                continue
            seg_len = struct.unpack(">H", data[i + 2:i + 4])[0]
            seg = data[i + 4:i + 2 + seg_len]
            if marker == 0xE1 and seg[:6] == b"Exif\x00\x00":
                info["exif"] = _parse_exif(seg[6:])
            if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                info["height"], info["width"] = struct.unpack(">HH", seg[1:5])
            if marker == 0xDA:
                break
            i += 2 + seg_len
        return info
    raise ReferenceError_(f"Unsupported image format (PNG/JPEG only): {p}")


_EXIF_TAGS = {0x010F: "Make", 0x0110: "Model", 0x920A: "FocalLength", 0xA405: "FocalLengthIn35mmFilm"}


def _parse_exif(tiff: bytes) -> dict:
    if len(tiff) < 8:
        return {}
    endian = "<" if tiff[:2] == b"II" else ">"
    out: dict = {}

    def read_ifd(offset: int, depth: int = 0) -> None:
        if depth > 2 or offset + 2 > len(tiff):
            return
        (count,) = struct.unpack(endian + "H", tiff[offset:offset + 2])
        for k in range(count):
            e = offset + 2 + 12 * k
            if e + 12 > len(tiff):
                return
            tag, typ, n, val = struct.unpack(endian + "HHII", tiff[e:e + 12])
            if tag == 0x8769:  # Exif sub-IFD
                read_ifd(val, depth + 1)
            elif tag in _EXIF_TAGS:
                name = _EXIF_TAGS[tag]
                if typ == 2:  # ASCII
                    raw = tiff[val:val + n] if n > 4 else tiff[e + 8:e + 8 + n]
                    out[name] = raw.split(b"\x00")[0].decode("ascii", "replace")
                elif typ == 5 and val + 8 <= len(tiff):  # RATIONAL
                    num, den = struct.unpack(endian + "II", tiff[val:val + 8])
                    out[name] = num / den if den else None
                elif typ == 3:  # SHORT
                    out[name] = struct.unpack(endian + "H", tiff[e + 8:e + 10])[0]

    (first,) = struct.unpack(endian + "I", tiff[4:8])
    read_ifd(first)
    return out


# --------------------------------------------------------------------------- view calibration

def view_basis(view: dict) -> tuple[tuple[int, float], tuple[int, float]]:
    try:
        u = AXES[view["image_right"]]
        v = AXES[view["image_up"]]
    except KeyError as exc:
        raise ReferenceError_(f"image_right/image_up must be one of {list(AXES)}") from exc
    if u[0] == v[0]:
        raise ReferenceError_("image_right and image_up must be different world axes")
    return u, v


def view_normal_axis(view: dict) -> tuple[int, float]:
    """Signed world axis pointing from the creature toward the viewer (u x v)."""
    (ui, us), (vi, vs) = view_basis(view)
    w = 3 - ui - vi
    # cyclic order X->Y->Z gives +1
    sign = 1.0 if (ui + 1) % 3 == vi else -1.0
    return w, sign * us * vs


def px_per_m(view: dict) -> float:
    if view.get("px_per_m"):
        return float(view["px_per_m"])
    sb = view.get("scale")
    if sb and "p1" in sb and "p2" in sb and sb.get("meters"):
        d = math.dist(sb["p1"], sb["p2"])
        if d <= 0:
            raise ReferenceError_("scale.p1 and scale.p2 coincide")
        return d / float(sb["meters"])
    raise ReferenceError_("view needs px_per_m or scale {p1, p2, meters}")


def pixel_to_world(view: dict, px: tuple[float, float]) -> dict[int, float]:
    """Return {world_axis_index: coordinate} for the two axes visible in this view."""
    (ui, us), (vi, vs) = view_basis(view)
    ppm = px_per_m(view)
    origin = view.get("origin", {})
    ox, oy = origin.get("px", [0.0, 0.0])
    ou, ov = origin.get("world", [0.0, 0.0])
    u = (px[0] - ox) / ppm + ou
    v = (oy - px[1]) / ppm + ov
    return {ui: us * u, vi: vs * v}


def world_to_pixel(view: dict, co: tuple[float, float, float]) -> tuple[float, float]:
    (ui, us), (vi, vs) = view_basis(view)
    ppm = px_per_m(view)
    origin = view.get("origin", {})
    ox, oy = origin.get("px", [0.0, 0.0])
    ou, ov = origin.get("world", [0.0, 0.0])
    u = us * co[ui]
    v = vs * co[vi]
    return (ox + (u - ou) * ppm, oy - (v - ov) * ppm)


def is_ortho(view: dict) -> bool:
    return view.get("projection", "unknown") == "orthographic"


# --------------------------------------------------------------------------- triangulation

def triangulate(views: dict, tol_abs: float, tol_ratio: float) -> dict:
    """Combine orthographic views into 3D landmarks and per-axis residuals."""
    samples: dict[str, dict[int, list[tuple[str, float]]]] = {}
    for vname, view in views.items():
        if not is_ortho(view):
            continue
        for lm, px in view.get("landmarks", {}).items():
            for axis, val in pixel_to_world(view, px).items():
                samples.setdefault(lm, {}).setdefault(axis, []).append((vname, val))
    span = 0.0
    for axes in samples.values():
        for vals in axes.values():
            for _, v in vals:
                span = max(span, abs(v))
    tol = max(tol_abs, tol_ratio * 2.0 * span)
    landmarks, issues = {}, []
    for lm, axes in samples.items():
        co = [0.0, 0.0, 0.0]
        complete = True
        worst = 0.0
        for a in range(3):
            vals = axes.get(a)
            if not vals:
                complete = False
                continue
            co[a] = sum(v for _, v in vals) / len(vals)
            if len(vals) > 1:
                res = max(v for _, v in vals) - min(v for _, v in vals)
                worst = max(worst, res)
                if res > tol:
                    issues.append({"landmark": lm, "axis": AXIS_NAMES[a], "residual_m": round(res, 4),
                                   "views": {n: round(v, 4) for n, v in vals}})
        landmarks[lm] = {"co": [round(c, 5) for c in co], "complete": complete,
                         "residual_m": round(worst, 5), "axes_seen": [AXIS_NAMES[a] for a in sorted(axes)]}
    issues.sort(key=lambda d: -d["residual_m"])
    return {"landmarks": landmarks, "issues": issues, "tolerance_m": round(tol, 4)}


def registration_fits(views: dict) -> list[dict]:
    """For each pair of ortho views sharing a world axis, fit b = s*a + t over common
    landmarks. s != 1 or large t => scale/origin registration error; large residual
    after the fit concentrated on few landmarks => pose/proportion inconsistency."""
    names = [n for n, v in views.items() if is_ortho(v)]
    fits = []
    for i, a_name in enumerate(names):
        for b_name in names[i + 1:]:
            va, vb = views[a_name], views[b_name]
            common = set(va.get("landmarks", {})) & set(vb.get("landmarks", {}))
            ax_a = {k for k in pixel_to_world(va, (0, 0))}
            ax_b = {k for k in pixel_to_world(vb, (0, 0))}
            for axis in ax_a & ax_b:
                pairs = [(pixel_to_world(va, va["landmarks"][lm])[axis],
                          pixel_to_world(vb, vb["landmarks"][lm])[axis], lm) for lm in sorted(common)]
                if len(pairs) < 3:
                    continue
                n = len(pairs)
                mx = sum(p[0] for p in pairs) / n
                my = sum(p[1] for p in pairs) / n
                sxx = sum((p[0] - mx) ** 2 for p in pairs)
                sxy = sum((p[0] - mx) * (p[1] - my) for p in pairs)
                s = sxy / sxx if sxx > 1e-12 else 1.0
                t = my - s * mx
                resid = [(abs(p[1] - (s * p[0] + t)), p[2]) for p in pairs]
                resid.sort(reverse=True)
                fits.append({"views": [a_name, b_name], "axis": AXIS_NAMES[axis], "n": n,
                             "scale": round(s, 4), "offset_m": round(t, 4),
                             "rms_after_fit_m": round(math.sqrt(sum(r * r for r, _ in resid) / n), 4),
                             "worst": [{"landmark": lm, "residual_m": round(r, 4)} for r, lm in resid[:3]]})
    return fits


# --------------------------------------------------------------------------- projection evidence

def _angle_deg(seg_a, seg_b) -> float:
    ax, ay = seg_a[1][0] - seg_a[0][0], seg_a[1][1] - seg_a[0][1]
    bx, by = seg_b[1][0] - seg_b[0][0], seg_b[1][1] - seg_b[0][1]
    la, lb = math.hypot(ax, ay), math.hypot(bx, by)
    if la < 1e-9 or lb < 1e-9:
        return 0.0
    c = abs(ax * bx + ay * by) / (la * lb)
    return math.degrees(math.acos(max(-1.0, min(1.0, c))))


def projection_evidence(view: dict, info: dict, tol_parallel_deg: float) -> dict:
    """Heuristic orthographic/perspective assessment. Never claims certainty."""
    ev, score = [], 0  # >0 favours perspective, <0 favours orthographic
    exif = info.get("exif") or {}
    if exif.get("FocalLength") or exif.get("Model"):
        ev.append(f"EXIF camera data present ({exif.get('Model', '?')}, f={exif.get('FocalLength')})")
        score += 2
    lms = view.get("landmarks", {})
    for group in view.get("parallel_sets", []):
        segs = []
        for a, b in group:
            if a in lms and b in lms:
                segs.append((lms[a], lms[b]))
        if len(segs) >= 2:
            worst = max(_angle_deg(segs[0], s) for s in segs[1:])
            if worst > tol_parallel_deg:
                ev.append(f"segments declared parallel in 3D diverge by {worst:.1f} deg (convergence)")
                score += 2
            else:
                ev.append(f"parallel segments stay parallel within {worst:.1f} deg")
                score -= 1
    mids = []
    for lm, px in lms.items():
        if lm.endswith("_L") and lm[:-2] + "_R" in lms:
            r = lms[lm[:-2] + "_R"]
            mids.append(((px[0] + r[0]) / 2.0, (px[1] + r[1]) / 2.0, math.dist(px, r)))
    if len(mids) >= 3 and view.get("symmetry_axis") in ("u", "v"):
        k = 0 if view["symmetry_axis"] == "u" else 1
        vals = [m[k] for m in mids]
        spread = max(vals) - min(vals)
        mean_w = sum(m[2] for m in mids) / len(mids)
        if mean_w > 0 and spread / mean_w > 0.15:
            ev.append(f"L/R pair midpoints drift {spread:.0f}px off the symmetry line (pose twist or perspective)")
            score += 1
        else:
            ev.append("L/R pair midpoints align on the symmetry line")
            score -= 1
    declared = view.get("projection", "unknown")
    if score >= 2:
        assessed = "perspective"
    elif score <= -1 and declared != "perspective":
        assessed = "orthographic"
    else:
        assessed = declared if declared != "unknown" else "unknown"
    return {"declared": declared, "assessed": assessed, "score": score, "evidence": ev,
            "conflict": declared != "unknown" and assessed != "unknown" and assessed != declared}


def bilateral_checks(landmarks3d: dict, pairs: list[list[str]], tol_ratio: float) -> list[dict]:
    """Compare left/right segment lengths in 3D (needs complete landmarks)."""
    out = []
    for a, b in pairs:
        la, lb, ra, rb = a + "_L", b + "_L", a + "_R", b + "_R"
        if all(n in landmarks3d and landmarks3d[n]["complete"] for n in (la, lb, ra, rb)):
            dl = math.dist(landmarks3d[la]["co"], landmarks3d[lb]["co"])
            dr = math.dist(landmarks3d[ra]["co"], landmarks3d[rb]["co"])
            ratio = dl / dr if dr > 1e-9 else float("inf")
            if abs(ratio - 1.0) > tol_ratio:
                out.append({"segment": f"{a}-{b}", "left_m": round(dl, 4), "right_m": round(dr, 4),
                            "ratio": round(ratio, 3)})
    return out
