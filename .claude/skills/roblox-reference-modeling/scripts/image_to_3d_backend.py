"""Mandatory stage `image_to_3d`: runs the image-to-3D backend on a reference image.

Backend: Stable Fast 3D (Stability AI), installed by setup_image_to_3d.ps1 in its own
venv (never Blender's Python) with local weights. This script checks configuration,
weights and free VRAM, runs the backend, measures peak VRAM (nvidia-smi polling) and
records the produced mesh for import_init_mesh.py (--as-model imports it as the model).

  python image_to_3d_backend.py check --manifest P [--config config/image_to_3d_backend.json]
  python image_to_3d_backend.py run   --manifest P --image refs/front.png [--config ...]

Config (written by setup_image_to_3d.ps1; template assets/image_to_3d_backend.example.json):
enabled, name, repository, commit, license, license_verified_at, vram_required_gb,
max_vram_gb (default 8), python, workdir, weights_dir, command (list with {python}
{image} {output_dir} {weights} placeholders), output_globs, timeout_s.

Refuses to run when: enabled=false, python/workdir missing, vram_required_gb >
max_vram_gb, or free VRAM (nvidia-smi) < vram_required_gb.

STATUS: implemented; wiring tested with a stub backend on Linux (2026-10-14); the real
Stable Fast 3D run has not been executed yet (needs the user's NVIDIA GPU).
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import threading
import time
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


def _used_vram_gb():
    smi = shutil.which("nvidia-smi")
    if not smi:
        return None
    try:
        out = subprocess.run([smi, "--query-gpu=memory.used", "--format=csv,noheader,nounits"],
                             capture_output=True, text=True, timeout=10)
        return int(out.stdout.strip().splitlines()[0]) / 1024.0
    except (ValueError, IndexError, OSError, subprocess.TimeoutExpired):
        return None


class _VramMonitor(threading.Thread):
    """polls nvidia-smi once per second while the backend runs (peak includes other apps)"""

    def __init__(self):
        super().__init__(daemon=True)
        self.stop = threading.Event()
        self.base = _used_vram_gb()
        self.peak = self.base

    def run(self):
        while not self.stop.wait(1.0):
            v = _used_vram_gb()
            if v is not None:
                self.peak = v if self.peak is None else max(self.peak, v)


def check(mpath, cfg) -> list[str]:
    problems = []
    if not cfg.get("enabled"):
        problems.append("backend disabled (enabled=false): run scripts/setup_image_to_3d.ps1 -Project <project>")
    for key in ("python", "workdir"):
        if not cfg.get(key) or not Path(cfg[key]).exists():
            problems.append(f"{key} not found: {cfg.get(key)!r}")
    if "{weights}" in " ".join(cfg.get("command", [])):
        wd = Path(cfg.get("weights_dir") or "")
        if not (wd / "config.yaml").is_file() or not (wd / "model.safetensors").is_file():
            problems.append(f"weights missing in {wd} (config.yaml + model.safetensors): rerun setup_image_to_3d.ps1 (Windows GPU) or setup_image_to_3d_cpu.sh (Linux CPU)")
    if cfg.get("device") == "cpu":   # percorso CPU (SF3D: get_device()/--device cpu): niente controlli di VRAM
        pass
    else:
        _check_vram(cfg, problems)
    if not isinstance(cfg.get("command"), list) or "{image}" not in " ".join(cfg.get("command", [])):
        problems.append("command must be a list containing {image} and {output_dir}")
    if not cfg.get("license_verified_at"):
        problems.append("license not verified: set license + license_verified_at after reading the official repo")
    return problems


def _check_vram(cfg, problems):
    need = float(cfg.get("vram_required_gb", 99))
    cap = float(cfg.get("max_vram_gb", 8))
    if need > cap:
        problems.append(f"backend needs {need} GB VRAM > allowed {cap} GB")
    free = _free_vram_gb()
    if free is None:
        problems.append("nvidia-smi unavailable; cannot verify free VRAM")
    elif free < need:
        problems.append(f"free VRAM {free:.1f} GB < required {need} GB (close other GPU apps, incl. Blender)")


def run_backend(mpath, data, cfg, image) -> dict:
    img = pc.to_abs(mpath, image)
    if not img.is_file():
        raise pc.PipelineError(f"Image not found: {img}")
    out_dir = pc.project_root(mpath) / "export" / "image_to_3d" / pc.stamp()
    out_dir.mkdir(parents=True, exist_ok=True)
    cmd = [c.format(python=cfg["python"], image=str(img), output_dir=str(out_dir), weights=str(cfg.get("weights_dir", "")))
           for c in cfg["command"]]
    log = pc.project_root(mpath) / "logs" / f"image_to_3d_{pc.stamp()}.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    mon = _VramMonitor()
    mon.start()
    t0 = time.time()
    try:
        proc = subprocess.run(cmd, cwd=cfg["workdir"], capture_output=True, text=True,
                              timeout=int(cfg.get("timeout_s", 900)), encoding="utf-8", errors="replace")
    except subprocess.TimeoutExpired as exc:
        raise pc.PipelineError(f"Backend timed out after {cfg.get('timeout_s', 900)} s") from exc
    except OSError as exc:
        raise pc.PipelineError(f"Backend could not start: {exc}") from exc
    finally:
        mon.stop.set()
        mon.join(timeout=3)
    seconds = round(time.time() - t0, 1)
    log.write_text(f"CMD {cmd}\nEXIT {proc.returncode}\nSECONDS {seconds}\nVRAM_BASE_GB {mon.base}\nVRAM_PEAK_GB {mon.peak}\n"
                   f"{proc.stdout}\n{proc.stderr}", encoding="utf-8")
    if proc.returncode != 0:
        raise pc.PipelineError(f"Backend exited with {proc.returncode}; see {log}")
    meshes = []
    for g in cfg.get("output_globs", ["**/*.obj", "**/*.glb", "**/*.ply"]):
        meshes.extend(out_dir.glob(g))
    if not meshes:
        raise pc.PipelineError(f"Backend produced no mesh matching {cfg.get('output_globs')} in {out_dir}")
    mesh = max(meshes, key=lambda p: p.stat().st_mtime)
    res = {"mesh": pc.to_rel(mpath, mesh), "log": pc.to_rel(mpath, log), "backend": cfg.get("name"),
           "commit": cfg.get("commit"), "seconds": seconds,
           "vram_base_gb": None if mon.base is None else round(mon.base, 2),
           "vram_peak_gb": None if mon.peak is None else round(mon.peak, 2)}
    if mon.peak is not None and mon.peak > float(cfg.get("max_vram_gb", 8)):
        res["warning"] = f"peak VRAM {mon.peak:.1f} GB above max_vram_gb"
    return res


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
        pc.emit({"ok": True, **res, "next": "run_stage.py run import_init_mesh -- --as-model"})
    except pc.PipelineError as exc:
        pc.emit({"ok": False, "error": str(exc)})
        sys.exit(2)


if __name__ == "__main__":
    main()
