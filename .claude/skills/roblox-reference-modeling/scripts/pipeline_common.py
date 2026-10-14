"""Shared runtime helpers for the Roblox creature pipeline skills.

This file is duplicated byte-for-byte in:
  .claude/skills/roblox-reference-modeling/scripts/pipeline_common.py
  .claude/skills/roblox-creature-rig-animation/scripts/pipeline_common.py
so that each skill stays self-contained. `manifest_tool.py check-sync` compares
the copies when both skills are installed side by side.

Runs in plain CPython >= 3.10 (no bpy) and inside Blender's bundled Python.
Helpers that need bpy import it lazily.

STATUS: implemented, untested (see references/verified-sources.md).
"""
from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import json
import os
import re
import sys
import traceback
from pathlib import Path
from typing import Any, Callable, Iterable

SCHEMA_VERSION = "1.0.0"
COMMON_VERSION = "1.0.0"
RESULT_MARKER = "@@RESULT@@"
SCRIPTS_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPTS_DIR.parent
ASSETS_DIR = SKILL_DIR / "assets"
SCHEMA_PATH = ASSETS_DIR / "pipeline_manifest.schema.json"
MANIFEST_NAME = "pipeline_manifest.json"
MIN_BLENDER = (4, 4, 0)          # layered (slotted) Action API is required
VERIFIED_BLENDER = "5.2.2 LTS"   # API probed on 2026-10-13

STAGES_MODELING = (
    "reference_inspection", "reference_setup", "coarse_model", "silhouette_compare",
    "refine", "visual_hull", "image_to_3d", "mesh_audit", "uv_pbr", "handoff",
)
STAGES_RIGGING = (
    "rig_build", "skinning", "weight_audit", "animation", "retarget",
    "curve_audit", "bake_export", "studio_validation",
)
ALL_STAGES = STAGES_MODELING + STAGES_RIGGING
STATUSES = ("pending", "running", "done", "failed", "approved", "stale", "skipped", "unsupported")
SEVERITIES = ("info", "warning", "error", "blocker")
PROJECT_DIRS = ("refs", "config", "blend", "checkpoints", "textures", "renders",
                "logs", "export", "reports")


class PipelineError(Exception):
    """Expected, actionable failure. The message is returned to the user."""


# --------------------------------------------------------------------------- time / args

def now_iso() -> str:
    return _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat()


def stamp() -> str:
    return _dt.datetime.now().strftime("%Y%m%d_%H%M%S")


def script_args(argv: list[str] | None = None) -> list[str]:
    """Return the script's own arguments (after `--` when run inside Blender)."""
    argv = list(sys.argv if argv is None else argv)
    if "--" in argv:
        return argv[argv.index("--") + 1:]
    return argv[1:]


def csv_list(value: str | None) -> list[str]:
    if not value:
        return []
    return [v.strip() for v in str(value).split(",") if v.strip()]


# --------------------------------------------------------------------------- JSON IO

def load_json(path: str | os.PathLike, what: str = "file") -> Any:
    p = Path(path)
    if not p.is_file():
        raise PipelineError(f"{what} not found: {p}")
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise PipelineError(f"{what} is not valid JSON ({p}:{exc.lineno}:{exc.colno}): {exc.msg}") from exc


def write_json(path: str | os.PathLike, data: Any) -> Path:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_name(p.name + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False, default=str), encoding="utf-8")
    os.replace(tmp, p)
    return p


def sha256_file(path: str | os.PathLike, chunk: int = 1 << 20) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(chunk), b""):
            h.update(block)
    return h.hexdigest()


# --------------------------------------------------------------------------- manifest

def find_manifest(path: str | os.PathLike) -> Path:
    p = Path(path).expanduser().resolve()
    if p.is_dir():
        p = p / MANIFEST_NAME
    if not p.is_file():
        raise PipelineError(
            f"Manifest not found: {p}. Create it with "
            f"`manifest_tool.py init --project <dir> --creature-id <id>`.")
    return p


def load_manifest(path: str | os.PathLike) -> tuple[Path, dict]:
    p = find_manifest(path)
    data = load_json(p, "Manifest")
    ver = str(data.get("schema_version", ""))
    if ver.split(".")[0] != SCHEMA_VERSION.split(".")[0]:
        raise PipelineError(
            f"Manifest schema_version {ver!r} is incompatible with scripts ({SCHEMA_VERSION}). "
            "Use matching skill versions or migrate the manifest.")
    return p, data


def save_manifest(path: str | os.PathLike, data: dict) -> None:
    data["updated_at"] = now_iso()
    write_json(path, data)


def project_root(manifest_path: str | os.PathLike) -> Path:
    return Path(manifest_path).resolve().parent


def to_abs(manifest_path: str | os.PathLike, rel: str | os.PathLike) -> Path:
    p = Path(rel)
    return p if p.is_absolute() else (project_root(manifest_path) / p).resolve()


def to_rel(manifest_path: str | os.PathLike, path: str | os.PathLike) -> str:
    p = Path(path).resolve()
    try:
        return p.relative_to(project_root(manifest_path)).as_posix()
    except ValueError:
        return p.as_posix()


def new_manifest(creature_id: str, display_name: str, profile: str) -> dict:
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]{1,40}", creature_id):
        raise PipelineError("creature_id must match [A-Za-z][A-Za-z0-9_]{1,40}")
    return {
        "schema_version": SCHEMA_VERSION,
        "creature_id": creature_id,
        "display_name": display_name or creature_id,
        "created_at": now_iso(),
        "updated_at": now_iso(),
        "units": {
            "length": "meter",
            "blender_scale_length": 1.0,
            "meters_per_stud": 0.28,
            "meters_per_stud_note": "Size estimate only; confirm imported size in Roblox Studio.",
        },
        "axes": {
            "blender_up": "+Z", "creature_forward": "-Y", "creature_left": "+X",
            "fbx_axis_forward": "-Z", "fbx_axis_up": "Y",
            "note": "Studio facing direction must be confirmed in validation scenario 3.",
        },
        "paths": {
            "working_blend": f"blend/{creature_id}.blend",
            "anatomy_config": "config/dragon_anatomy.json",
            "reference_annotations": "config/reference_annotations.json",
            "polygon_budgets": "config/polygon_budgets.json",
            "materials_config": "config/materials.json",
            "rig_config": "config/rig_config.json",
            "animation_config": "config/animation_config.json",
        },
        "environment": {},
        "limits": {
            "max_refinement_iterations": 6,
            "min_iou_improvement": 0.005,
            "stall_patience": 2,
            "max_stage_retries": 2,
        },
        "polygon_budget_profile": profile,
        "references": [],
        "components": [],
        "export_groups": [],
        "landmarks": {},
        "joints": [],
        "textures": [],
        "checkpoints": [],
        "stages": {s: {"status": "pending"} for s in ALL_STAGES},
        "defects": [],
        "verifications": [],
        "handoff": {"ready": False},
        "exports": [],
    }


# --------------------------------------------------------------------------- stage tracking

def set_stage(data: dict, stage: str, status: str, summary: dict | None = None,
              log: str | None = None, inputs_hash: str | None = None) -> dict:
    if stage not in ALL_STAGES:
        raise PipelineError(f"Unknown stage {stage!r}. Valid: {', '.join(ALL_STAGES)}")
    if status not in STATUSES:
        raise PipelineError(f"Unknown status {status!r}. Valid: {', '.join(STATUSES)}")
    entry = data.setdefault("stages", {}).setdefault(stage, {"status": "pending"})
    entry["status"] = status
    entry["updated_at"] = now_iso()
    if summary is not None:
        entry["summary"] = summary
    if log:
        entry["log"] = log
    if inputs_hash:
        entry["inputs_hash"] = inputs_hash
    if status == "failed":
        entry["attempts"] = int(entry.get("attempts", 0)) + 1
    return entry


def check_retry_budget(data: dict, stage: str) -> None:
    entry = data.get("stages", {}).get(stage, {})
    limit = int(data.get("limits", {}).get("max_stage_retries", 2))
    if entry.get("status") == "failed" and int(entry.get("attempts", 0)) > limit:
        raise PipelineError(
            f"Stage {stage!r} failed {entry.get('attempts')} times (limit {limit}). "
            "Fix the reported cause, then reset with `manifest_tool.py set-stage --status pending`.")


def fingerprint(files: Iterable[str | os.PathLike], params: dict) -> str:
    """Stable hash of input files and parameters (detects 'nothing changed')."""
    h = hashlib.sha256()
    for f in sorted(str(x) for x in files if x):
        h.update(f.encode("utf-8"))
        fp = Path(f)
        if fp.is_file():
            st = fp.stat()
            if st.st_size > 8 * 1024 * 1024:
                h.update(f"{st.st_size}:{st.st_mtime_ns}".encode())
            else:
                h.update(fp.read_bytes())
    h.update(json.dumps(params, sort_keys=True, default=str).encode("utf-8"))
    return h.hexdigest()[:16]


def should_skip(data: dict, stage: str, inputs_hash: str, force: bool) -> bool:
    entry = data.get("stages", {}).get(stage) or {}
    return (not force and entry.get("status") in ("done", "approved")
            and entry.get("inputs_hash") == inputs_hash)


def add_defect(data: dict, stage: str, severity: str, description: str,
               objects: list[str] | None = None) -> str:
    if severity not in SEVERITIES:
        raise PipelineError(f"severity must be one of {SEVERITIES}")
    defects = data.setdefault("defects", [])
    for d in defects:
        if d.get("status") == "open" and d.get("stage") == stage and d.get("description") == description:
            return d["id"]
    did = f"D{len(defects) + 1:03d}"
    defects.append({"id": did, "stage": stage, "severity": severity, "description": description,
                    "objects": list(objects or [])[:50], "status": "open", "created_at": now_iso()})
    return did


def sync_stage_defects(data: dict, stage: str, current: list[tuple[str, str, list[str]]]) -> dict:
    """Open defects for `current` (severity, description, objects); auto-resolve stale ones."""
    keep = set()
    for sev, desc, objs in current:
        keep.add(add_defect(data, stage, sev, desc, objs))
    resolved = 0
    for d in data.get("defects", []):
        if d["stage"] == stage and d["status"] == "open" and d["id"] not in keep:
            d["status"] = "resolved"
            d["resolved_at"] = now_iso()
            d["resolution"] = "not detected on re-run"
            resolved += 1
    return {"open": len(keep), "auto_resolved": resolved}


def open_defects(data: dict, min_severity: str = "warning") -> list[dict]:
    rank = {s: i for i, s in enumerate(SEVERITIES)}
    return [d for d in data.get("defects", [])
            if d.get("status") == "open" and rank.get(d.get("severity"), 0) >= rank[min_severity]]


def record_verification(data: dict, topic: str, source: str, result: str) -> None:
    data.setdefault("verifications", []).append(
        {"topic": topic, "source": source, "result": result, "checked_at": now_iso()})


# --------------------------------------------------------------------------- mini JSON-Schema validator

def validate_schema(instance: Any, schema: dict, root: dict | None = None, path: str = "$") -> list[str]:
    """Subset of JSON Schema 2020-12: type, enum, const, required, properties,
    additionalProperties, items, minItems, minimum, maximum, pattern, $ref (#/$defs)."""
    root = root or schema
    errors: list[str] = []
    if "$ref" in schema:
        ref = schema["$ref"]
        if not ref.startswith("#/"):
            return [f"{path}: unsupported $ref {ref}"]
        target: Any = root
        for part in ref[2:].split("/"):
            target = target[part]
        return validate_schema(instance, target, root, path)
    types = schema.get("type")
    if types:
        types = [types] if isinstance(types, str) else types
        checks = {
            "object": lambda v: isinstance(v, dict),
            "array": lambda v: isinstance(v, list),
            "string": lambda v: isinstance(v, str),
            "number": lambda v: isinstance(v, (int, float)) and not isinstance(v, bool),
            "integer": lambda v: isinstance(v, int) and not isinstance(v, bool),
            "boolean": lambda v: isinstance(v, bool),
            "null": lambda v: v is None,
        }
        if not any(checks[t](instance) for t in types):
            return [f"{path}: expected {types}, got {type(instance).__name__}"]
    if "enum" in schema and instance not in schema["enum"]:
        errors.append(f"{path}: {instance!r} not in {schema['enum']}")
    if "const" in schema and instance != schema["const"]:
        errors.append(f"{path}: must equal {schema['const']!r}")
    if isinstance(instance, (int, float)) and not isinstance(instance, bool):
        if "minimum" in schema and instance < schema["minimum"]:
            errors.append(f"{path}: {instance} < minimum {schema['minimum']}")
        if "maximum" in schema and instance > schema["maximum"]:
            errors.append(f"{path}: {instance} > maximum {schema['maximum']}")
    if isinstance(instance, str) and "pattern" in schema and not re.search(schema["pattern"], instance):
        errors.append(f"{path}: {instance!r} does not match {schema['pattern']}")
    if isinstance(instance, dict):
        for key in schema.get("required", []):
            if key not in instance:
                errors.append(f"{path}: missing required key {key!r}")
        props = schema.get("properties", {})
        addl = schema.get("additionalProperties", True)
        for key, val in instance.items():
            if key in props:
                errors.extend(validate_schema(val, props[key], root, f"{path}.{key}"))
            elif addl is False:
                errors.append(f"{path}: unexpected key {key!r}")
            elif isinstance(addl, dict):
                errors.extend(validate_schema(val, addl, root, f"{path}.{key}"))
    if isinstance(instance, list):
        if "minItems" in schema and len(instance) < schema["minItems"]:
            errors.append(f"{path}: fewer than {schema['minItems']} items")
        if "items" in schema:
            for i, item in enumerate(instance):
                errors.extend(validate_schema(item, schema["items"], root, f"{path}[{i}]"))
    return errors


def validate_manifest(data: dict) -> list[str]:
    schema = load_json(SCHEMA_PATH, "Manifest schema")
    return validate_schema(data, schema)


# --------------------------------------------------------------------------- logging / results

class StageLog:
    """Full logs go to disk; only a compact JSON summary goes to stdout."""

    def __init__(self, manifest_path: str | os.PathLike | None, stage: str):
        base = project_root(manifest_path) / "logs" if manifest_path else Path.cwd() / "logs"
        base.mkdir(parents=True, exist_ok=True)
        self.path = base / f"{stage}_{stamp()}.log"
        self.stage = stage
        self._fh = open(self.path, "a", encoding="utf-8")

    def write(self, *parts: Any) -> None:
        self._fh.write(" ".join(str(p) for p in parts) + "\n")
        self._fh.flush()

    def dump(self, name: str, obj: Any) -> Path:
        p = self.path.with_name(f"{self.path.stem}_{name}.json")
        write_json(p, obj)
        return p

    def close(self) -> None:
        if not self._fh.closed:
            self._fh.close()


def emit(result: dict) -> None:
    print(RESULT_MARKER + json.dumps(result, separators=(",", ":"), ensure_ascii=False, default=str))
    sys.stdout.flush()


def cli_entry(run: Callable[[dict], dict], parser: argparse.ArgumentParser) -> None:
    """Parse args, call run(params), print one result line, exit with a status code."""
    args = parser.parse_args(script_args())
    params = vars(args)
    code = 0
    try:
        res = run(params)
        res.setdefault("ok", True)
        emit(res)
        code = 0 if res.get("ok") else 1
    except PipelineError as exc:
        emit({"ok": False, "error": str(exc)})
        code = 2
    except Exception as exc:  # unexpected: keep traceback on disk, not in the conversation
        tb = traceback.format_exc()
        crash_dir = Path(params.get("manifest") or ".").resolve()
        crash_dir = (crash_dir.parent if crash_dir.is_file() else crash_dir) / "logs"
        try:
            crash_dir.mkdir(parents=True, exist_ok=True)
            crash = crash_dir / f"crash_{stamp()}.log"
            crash.write_text(tb, encoding="utf-8")
        except OSError:
            crash = Path("<unwritable>")
        emit({"ok": False, "error": f"{type(exc).__name__}: {exc}", "traceback_file": str(crash)})
        code = 3
    sys.stdout.flush()
    sys.exit(code)


def base_parser(description: str) -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=description)
    p.add_argument("--manifest", required=True, help="Path to pipeline_manifest.json or its folder")
    p.add_argument("--force", action="store_true", help="Run even if inputs are unchanged")
    p.add_argument("--no-save", dest="save", action="store_false", help="Do not save the .blend")
    p.set_defaults(save=None)
    return p


# --------------------------------------------------------------------------- Blender helpers (lazy bpy)

def require_blender() -> str:
    import bpy
    if tuple(bpy.app.version) < MIN_BLENDER:
        raise PipelineError(
            f"Blender {bpy.app.version_string} is too old; >= {'.'.join(map(str, MIN_BLENDER))} "
            f"is required (verified on {VERIFIED_BLENDER}).")
    return bpy.app.version_string


def ensure_object_mode() -> None:
    import bpy
    obj = bpy.context.view_layer.objects.active if bpy.context.view_layer else None
    if obj is not None and obj.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")


def ensure_working_blend(manifest_path: str | os.PathLike, data: dict,
                         adopt_current: bool = False) -> Path:
    """Make sure the open file is the project's working .blend.

    Background mode: opens or creates it. Interactive mode: never discards the
    user's scene; raises an actionable error instead (unless adopt_current)."""
    import bpy
    wb = to_abs(manifest_path, data["paths"]["working_blend"])
    cur = Path(bpy.data.filepath).resolve() if bpy.data.filepath else None
    if cur == wb:
        return wb
    if bpy.app.background:
        if wb.exists():
            bpy.ops.wm.open_mainfile(filepath=str(wb))
        else:
            bpy.ops.wm.read_factory_settings(use_empty=True)
            wb.parent.mkdir(parents=True, exist_ok=True)
            bpy.ops.wm.save_as_mainfile(filepath=str(wb))
        return wb
    if adopt_current and cur is None and not wb.exists():
        wb.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(wb))
        return wb
    raise PipelineError(
        f"Open file is {cur or '<unsaved>'} but the manifest's working blend is {wb}. "
        "Open the working blend in Blender, or pass adopt_current=True for a new, unsaved scene.")


def save_working(manifest_path: str | os.PathLike, data: dict, save: bool | None) -> bool:
    import bpy
    if save is None:
        save = bool(bpy.app.background)
    if not save:
        return False
    wb = to_abs(manifest_path, data["paths"]["working_blend"])
    if bpy.data.filepath and Path(bpy.data.filepath).resolve() == wb:
        bpy.ops.wm.save_mainfile()
    else:
        bpy.ops.wm.save_as_mainfile(filepath=str(wb))
    return True


def save_checkpoint(manifest_path: str | os.PathLike, data: dict, stage: str,
                    label: str = "") -> dict:
    """Copy of the current scene into checkpoints/ (the open file path is unchanged)."""
    import bpy
    d = project_root(manifest_path) / "checkpoints"
    d.mkdir(parents=True, exist_ok=True)
    existing = [c for c in data.get("checkpoints", []) if c.get("stage") == stage]
    n = len(existing) + 1
    path = d / f"{data.get('creature_id', 'creature')}_{stage}_{n:03d}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(path), copy=True, compress=True)
    entry = {"id": f"{stage}_{n:03d}", "stage": stage, "path": to_rel(manifest_path, path),
             "created_at": now_iso(), "approved": False, "label": label}
    data.setdefault("checkpoints", []).append(entry)
    return entry


def ensure_collection(name: str, parent: Any = None) -> Any:
    import bpy
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        col.name = name
    parent = parent or bpy.context.scene.collection
    if parent.children.get(col.name) is None:
        parent.children.link(col)
    return col


def link_only_to(obj: Any, col: Any) -> None:
    for c in list(obj.users_collection):
        if c != col:
            c.objects.unlink(obj)
    if col.objects.get(obj.name) is None:
        col.objects.link(obj)


def upsert_mesh_object(name: str, mesh: Any, collection: Any) -> Any:
    """Create or update object `name` with new mesh data; never duplicates."""
    import bpy
    obj = bpy.data.objects.get(name)
    if obj is not None and obj.type != "MESH":
        raise PipelineError(f"Object {name!r} exists with type {obj.type}; rename or remove it.")
    if obj is None:
        obj = bpy.data.objects.new(name, mesh)
        obj.name = name
    else:
        old = obj.data
        for mat in old.materials:
            mesh.materials.append(mat)
        obj.data = mesh
        if old.users == 0:
            bpy.data.meshes.remove(old)
    mesh.name = name
    link_only_to(obj, collection)
    return obj


def find_node(nodes: Any, bl_idname: str, name: str | None = None) -> Any:
    """Look nodes up by stable name or bl_idname, never by (translatable) label."""
    if name and nodes.get(name) is not None:
        return nodes[name]
    for n in nodes:
        if n.bl_idname == bl_idname and (name is None):
            return n
    return None


def configure_cycles_device(scene: Any, device: str) -> str:
    """device: CPU | GPU. GPU tries OPTIX then CUDA; preferences are not saved here."""
    import bpy
    scene.render.engine = "CYCLES"
    if device.upper() != "GPU":
        scene.cycles.device = "CPU"
        return "CPU"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
    except KeyError as exc:
        raise PipelineError("Cycles add-on preferences not available; use --device CPU") from exc
    for backend in ("OPTIX", "CUDA"):
        try:
            prefs.compute_device_type = backend
        except TypeError:
            continue
        prefs.get_devices()
        devs = [d for d in prefs.devices if d.type == backend]
        if devs:
            for d in prefs.devices:
                d.use = d.type == backend
            scene.cycles.device = "GPU"
            return backend
    scene.cycles.device = "CPU"
    return "CPU (no OPTIX/CUDA device found)"
