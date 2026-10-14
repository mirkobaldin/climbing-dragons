"""Optional stage `image_to_3d`: EXTENSION POINT for an external image-to-3D backend.

No backend is bundled, installed or tested. This script only runs a backend the
user installed separately (own venv, never Blender's Python), after checking
VRAM and configuration, then records the produced mesh for import_init_mesh.py.

  python image_to_3d_backend.py check --manifest P [--config config/image_to_3d_backend.json]
  python image_to_3d_backend.py run   --manifest P --image refs/front.png [--config ...]

Config (template assets/image_to_3d_backend.example.json): enabled, name, repository,
license, license_verified_at, vram_required_gb, max_vram_gb (default 8), python,
workdir, command (list with {python} {image} {output_dir} placeholders),
output_globs, timeout_s.

Refuses to run when: enabled=false, python/workdir missing, vram_required_gb >
max_vram_gb, or free VRAM (nvidia-smi) < vram_required_gb.

STATUS: extension point implemented, untested; no backend verified end-to-end.
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402

STAGE = "image_to_3d"


def _cfg(mpath, path):
    p = pc.to_abs(mpath, path or "config/image_to_3d_backend.json")
    return p, pc.load_json(p, "Backend config")


def _free_vram_gb():
    smi = shutil.which("nvidia-smi")
    if not smi:
        return None
    out = subprocess.run([smi, "--query-gpu=memory.free", "--format=csv,noheader,nounits"],
                         capture_output=True, text=True, timeout=30)
    try:
        return int(out.stdout.strip().splitlines()[0]) / 1024.0
    except (ValueError, IndexError):
        return None


def check(mpath, cfg) -> list[str]:
    problems = []
    if not cfg.get("enabled"):
        problems.append("backend disabled (enabled=false); procedural modeling remains the default path")
    for key in ("python", "workdir"):
        if not cfg.get(key) or not Path(cfg[key]).exists():
            problems.append(f"{key} not found: {cfg.get(key)!r}")
    need = float(cfg.get("vram_required_gb", 99))
    cap = float(cfg.get("max_vram_gb", 8))
    if need > cap:
        problems.append(f"backend needs {need} GB VRAM > allowed {cap} GB")
    free = _free_vram_gb()
    if free is None:
        problems.append("nvidia-smi unavailable; cannot verify free VRAM")
    elif free < need:
        problems.append(f"free VRAM {free:.1f} GB < required {need} GB (close other GPU apps, incl. Blender)")
    if not isinstance(cfg.get("command"), list) or "{image}" not in " ".join(cfg.get("command", [])):
        problems.append("command must be a list containing {image} and {output_dir}")
    if not cfg.get("license_verified_at"):
        problems.append("license not verified: set license + license_verified_at after reading the official repo")
    return problems


def run_backend(mpath, data, cfg, image) -> dict:
    img = pc.to_abs(mpath, image)
    if not img.is_file():
        raise pc.PipelineError(f"Image not found: {img}")
    out_dir = pc.project_root(mpath) / "export" / "image_to_3d" / pc.stamp()
    out_dir.mkdir(parents=True, exist_ok=True)
    cmd = [c.format(python=cfg["python"], image=str(img), output_dir=str(out_dir)) for c in cfg["command"]]
    log = pc.project_root(mpath) / "logs" / f"image_to_3d_{pc.stamp()}.log"
    try:
        proc = subprocess.run(cmd, cwd=cfg["workdir"], capture_output=True, text=True,
                              timeout=int(cfg.get("timeout_s", 900)), encoding="utf-8", errors="replace")
    except subprocess.TimeoutExpired as exc:
        raise pc.PipelineError(f"Backend timed out after {cfg.get('timeout_s', 900)} s") from exc
    except OSError as exc:
        raise pc.PipelineError(f"Backend could not start: {exc}") from exc
    log.write_text(f"CMD {cmd}\nEXIT {proc.returncode}\n{proc.stdout}\n{proc.stderr}", encoding="utf-8")
    if proc.returncode != 0:
        raise pc.PipelineError(f"Backend exited with {proc.returncode}; see {log}")
    meshes = []
    for g in cfg.get("output_globs", ["**/*.obj", "**/*.glb", "**/*.ply"]):
        meshes.extend(out_dir.glob(g))
    if not meshes:
        raise pc.PipelineError(f"Backend produced no mesh matching {cfg.get('output_globs')} in {out_dir}")
    mesh = max(meshes, key=lambda p: p.stat().st_mtime)
    return {"mesh": pc.to_rel(mpath, mesh), "log": pc.to_rel(mpath, log), "backend": cfg.get("name")}


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("cmd", choices=("check", "run"))
    p.add_argument("--manifest", required=True)
    p.add_argument("--config")
    p.add_argument("--image")
    a = p.parse_args()
    try:
        mpath, data = pc.load_manifest(a.manifest)
        _, cfg = _cfg(mpath, a.config)
        problems = check(mpath, cfg)
        if a.cmd == "check":
            pc.emit({"ok": not problems, "backend": cfg.get("name"), "problems": problems})
            sys.exit(0 if not problems else 1)
        if problems:
            raise pc.PipelineError("; ".join(problems))
        if not a.image:
            raise pc.PipelineError("--image is required for run")
        res = run_backend(mpath, data, cfg, a.image)
        pc.set_stage(data, STAGE, "done", res)
        pc.save_manifest(mpath, data)
        pc.emit({"ok": True, **res, "next": "import with import_init_mesh.py --source image_to_3d"})
    except pc.PipelineError as exc:
        pc.emit({"ok": False, "error": str(exc)})
        sys.exit(2)


if __name__ == "__main__":
    main()
