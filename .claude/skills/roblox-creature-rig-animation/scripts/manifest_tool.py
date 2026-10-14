"""Manifest CLI for the Roblox creature pipeline (stdlib only, no bpy).

Shared file: identical copy in both skills. Run with any Python >= 3.10,
for example Blender's bundled interpreter:
  "<Blender>/5.2/python/bin/python.exe" manifest_tool.py <command> [options]

Commands (all print exactly one JSON line prefixed with @@RESULT@@):
  init           --project DIR --creature-id ID [--display-name S] [--profile P]
  copy-configs   --project DIR [--overwrite]
  validate       --manifest P
  status         --manifest P
  set-stage      --manifest P --stage S --status X [--note TEXT]
  add-defect     --manifest P --stage S --severity SEV --description TEXT [--objects a,b]
  resolve-defect --manifest P --id D001 [--resolution resolved|wontfix] [--note TEXT]
  approve        --manifest P (--checkpoint ID | --components a,b | --all-components)
  unapprove      --manifest P --components a,b
  record-verification --manifest P --topic T --source URL --result TEXT
  check-sync     --other-skill DIR

STATUS: implemented, untested.
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402

SHARED_FILES = ("scripts/pipeline_common.py", "scripts/manifest_tool.py",
                "scripts/run_stage.py", "assets/pipeline_manifest.schema.json",
                "references/data-contract.md")


def cmd_init(a) -> dict:
    root = Path(a.project).expanduser().resolve()
    manifest = root / pc.MANIFEST_NAME
    if manifest.exists():
        raise pc.PipelineError(f"{manifest} already exists; refusing to overwrite. Use status/validate.")
    root.mkdir(parents=True, exist_ok=True)
    for d in pc.PROJECT_DIRS:
        (root / d).mkdir(exist_ok=True)
    data = pc.new_manifest(a.creature_id, a.display_name or "", a.profile)
    pc.save_manifest(manifest, data)
    copied = _copy_configs(root, overwrite=False)
    return {"manifest": str(manifest), "dirs": list(pc.PROJECT_DIRS), "configs_copied": copied,
            "next": "Edit config/*.json, put reference images in refs/, then run inspect_references.py"}


def _copy_configs(root: Path, overwrite: bool) -> list[str]:
    out = []
    (root / "config").mkdir(parents=True, exist_ok=True)
    for src in sorted(pc.ASSETS_DIR.glob("*.example.json")):
        dst = root / "config" / src.name.replace(".example", "")
        if dst.exists() and not overwrite:
            continue
        shutil.copyfile(src, dst)
        out.append(dst.name)
    for src in sorted(pc.ASSETS_DIR.glob("*.json")):
        if src.name.endswith(".example.json") or src.name == pc.SCHEMA_PATH.name:
            continue
        dst = root / "config" / src.name
        if dst.exists() and not overwrite:
            continue
        shutil.copyfile(src, dst)
        out.append(dst.name)
    return out


def cmd_copy_configs(a) -> dict:
    root = Path(a.project).expanduser().resolve()
    return {"copied": _copy_configs(root, a.overwrite), "skill": pc.SKILL_DIR.name}


def cmd_validate(a) -> dict:
    path, data = pc.load_manifest(a.manifest)
    errors = pc.validate_manifest(data)
    warnings = []
    for key in ("textures", "checkpoints"):
        for item in data.get(key, []):
            if not pc.to_abs(path, item["path"]).exists():
                warnings.append(f"{key}: missing file {item['path']}")
    for key, rel in data.get("paths", {}).items():
        if key != "working_blend" and not pc.to_abs(path, rel).exists():
            warnings.append(f"paths.{key}: {rel} does not exist yet")
    names = [c["name"] for c in data.get("components", [])]
    dup = sorted({n for n in names if names.count(n) > 1})
    if dup:
        errors.append(f"duplicate component names: {dup}")
    joint_names = {j["name"] for j in data.get("joints", [])}
    for c in data.get("components", []):
        hint = c.get("bone_hint")
        if joint_names and hint and hint not in joint_names:
            errors.append(f"component {c['name']} bone_hint {hint!r} is not a joint")
    return {"ok": not errors, "errors": errors[:50], "warnings": warnings[:50],
            "error_count": len(errors), "warning_count": len(warnings)}


def cmd_status(a) -> dict:
    path, data = pc.load_manifest(a.manifest)
    stages = {k: v.get("status") for k, v in data.get("stages", {}).items()}
    approved = [c["id"] for c in data.get("checkpoints", []) if c.get("approved")]
    defects = pc.open_defects(data, "info")
    by_sev: dict[str, int] = {}
    for d in defects:
        by_sev[d["severity"]] = by_sev.get(d["severity"], 0) + 1
    return {"creature_id": data["creature_id"], "stages": stages,
            "components": len(data.get("components", [])),
            "approved_components": sum(1 for c in data.get("components", []) if c.get("approved")),
            "joints": len(data.get("joints", [])), "textures": len(data.get("textures", [])),
            "latest_approved_checkpoint": approved[-1] if approved else None,
            "open_defects": by_sev, "handoff_ready": data.get("handoff", {}).get("ready", False)}


def cmd_set_stage(a) -> dict:
    path, data = pc.load_manifest(a.manifest)
    entry = pc.set_stage(data, a.stage, a.status)
    if a.note:
        entry.setdefault("notes", []).append({"at": pc.now_iso(), "note": a.note})
    if a.status == "pending":
        entry["attempts"] = 0
    pc.save_manifest(path, data)
    return {"stage": a.stage, "status": a.status}


def cmd_add_defect(a) -> dict:
    path, data = pc.load_manifest(a.manifest)
    did = pc.add_defect(data, a.stage, a.severity, a.description, pc.csv_list(a.objects))
    pc.save_manifest(path, data)
    return {"id": did}


def cmd_resolve_defect(a) -> dict:
    path, data = pc.load_manifest(a.manifest)
    for d in data.get("defects", []):
        if d["id"] == a.id:
            d["status"] = a.resolution
            d["resolved_at"] = pc.now_iso()
            if a.note:
                d["resolution"] = a.note
            pc.save_manifest(path, data)
            return {"id": a.id, "status": a.resolution}
    raise pc.PipelineError(f"Defect {a.id} not found")


def cmd_approve(a, value: bool = True) -> dict:
    path, data = pc.load_manifest(a.manifest)
    changed = []
    if getattr(a, "checkpoint", None):
        for c in data.get("checkpoints", []):
            if c["id"] == a.checkpoint:
                c["approved"] = value
                changed.append(c["id"])
        if not changed:
            raise pc.PipelineError(f"Checkpoint {a.checkpoint} not found")
    wanted = set(pc.csv_list(getattr(a, "components", None)))
    for c in data.get("components", []):
        if getattr(a, "all_components", False) or c["name"] in wanted or c["key"] in wanted:
            c["approved"] = value
            changed.append(c["name"])
    missing = wanted - {c["name"] for c in data.get("components", [])} - {c["key"] for c in data.get("components", [])}
    pc.save_manifest(path, data)
    return {"changed": changed[:100], "count": len(changed), "unknown": sorted(missing)}


def cmd_record_verification(a) -> dict:
    path, data = pc.load_manifest(a.manifest)
    pc.record_verification(data, a.topic, a.source, a.result)
    pc.save_manifest(path, data)
    return {"recorded": a.topic}


def cmd_check_sync(a) -> dict:
    other = Path(a.other_skill).expanduser().resolve()
    report = {}
    for rel in SHARED_FILES:
        mine, theirs = pc.SKILL_DIR / rel, other / rel
        if not theirs.exists():
            report[rel] = "missing in other skill"
        else:
            report[rel] = "identical" if pc.sha256_file(mine) == pc.sha256_file(theirs) else "DIFFERENT"
    return {"ok": all(v == "identical" for v in report.values()), "files": report}


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("init")
    s.add_argument("--project", required=True)
    s.add_argument("--creature-id", required=True)
    s.add_argument("--display-name")
    s.add_argument("--profile", default="pc_standard")
    s = sub.add_parser("copy-configs")
    s.add_argument("--project", required=True)
    s.add_argument("--overwrite", action="store_true")
    for name in ("validate", "status"):
        sub.add_parser(name).add_argument("--manifest", required=True)
    s = sub.add_parser("set-stage")
    s.add_argument("--manifest", required=True)
    s.add_argument("--stage", required=True, choices=pc.ALL_STAGES)
    s.add_argument("--status", required=True, choices=pc.STATUSES)
    s.add_argument("--note")
    s = sub.add_parser("add-defect")
    s.add_argument("--manifest", required=True)
    s.add_argument("--stage", required=True, choices=pc.ALL_STAGES)
    s.add_argument("--severity", required=True, choices=pc.SEVERITIES)
    s.add_argument("--description", required=True)
    s.add_argument("--objects")
    s = sub.add_parser("resolve-defect")
    s.add_argument("--manifest", required=True)
    s.add_argument("--id", required=True)
    s.add_argument("--resolution", default="resolved", choices=("resolved", "wontfix"))
    s.add_argument("--note")
    for name in ("approve", "unapprove"):
        s = sub.add_parser(name)
        s.add_argument("--manifest", required=True)
        s.add_argument("--checkpoint")
        s.add_argument("--components")
        s.add_argument("--all-components", action="store_true")
    s = sub.add_parser("record-verification")
    s.add_argument("--manifest", required=True)
    s.add_argument("--topic", required=True)
    s.add_argument("--source", required=True)
    s.add_argument("--result", required=True)
    sub.add_parser("check-sync").add_argument("--other-skill", required=True)

    a = p.parse_args()
    handlers = {
        "init": cmd_init, "copy-configs": cmd_copy_configs, "validate": cmd_validate,
        "status": cmd_status, "set-stage": cmd_set_stage, "add-defect": cmd_add_defect,
        "resolve-defect": cmd_resolve_defect, "approve": cmd_approve,
        "unapprove": lambda x: cmd_approve(x, False),
        "record-verification": cmd_record_verification, "check-sync": cmd_check_sync,
    }
    try:
        res = handlers[a.cmd](a)
        res.setdefault("ok", True)
        pc.emit(res)
        sys.exit(0 if res["ok"] else 1)
    except pc.PipelineError as exc:
        pc.emit({"ok": False, "error": str(exc)})
        sys.exit(2)


if __name__ == "__main__":
    main()
