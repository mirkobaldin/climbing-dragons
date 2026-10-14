"""Run a Blender stage script in background mode and print only its JSON result.

Shared file: identical copy in both skills. Stdlib only.

Usage:
  python run_stage.py detect --manifest P [--blender EXE]
  python run_stage.py run SCRIPT --manifest P [--blend FILE | --no-blend] [--blender EXE]
                      [--timeout S] [--user-startup] -- [script args...]

SCRIPT is a file name in this skill's scripts/ folder (".py" optional) or a path.
`--manifest` is forwarded to the script automatically. Full Blender stdout/stderr
is written to <project>/logs/run_<script>_<timestamp>.log; stdout gets one line.

Blender executable resolution order: --blender, $BLENDER_EXE, manifest
environment.blender_exe, the Blender that owns the running Python, PATH,
then standard install folders (highest version wins).

STATUS: implemented, untested.
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import platform
import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402


def _version_key(path: str) -> tuple:
    nums = re.findall(r"(\d+)\.(\d+)", path)
    return tuple(int(x) for x in nums[-1]) if nums else (0, 0)


def find_blender(explicit: str | None, data: dict | None) -> Path:
    cands: list[str] = []
    if explicit:
        cands.append(explicit)
    if os.environ.get("BLENDER_EXE"):
        cands.append(os.environ["BLENDER_EXE"])
    if data and data.get("environment", {}).get("blender_exe"):
        cands.append(data["environment"]["blender_exe"])
    exe = Path(sys.executable).resolve()
    # <Blender>/<ver>/python/bin/python(.exe) -> <Blender>/blender(.exe)
    if len(exe.parents) > 3 and exe.parent.name == "bin" and exe.parents[1].name == "python":
        for name in ("blender.exe", "blender", "Blender"):
            cands.append(str(exe.parents[3] / name))
    which = shutil.which("blender")
    if which:
        cands.append(which)
    system = platform.system()
    if system == "Windows":
        found = glob.glob(r"C:\Program Files\Blender Foundation\Blender *\blender.exe")
        cands.extend(sorted(found, key=_version_key, reverse=True))
    elif system == "Darwin":
        cands.append("/Applications/Blender.app/Contents/MacOS/Blender")
    else:
        cands.extend(sorted(glob.glob("/opt/blender*/blender"), key=_version_key, reverse=True))
    for c in cands:
        p = Path(c)
        if p.is_file():
            return p
    raise pc.PipelineError("Blender executable not found. Pass --blender or set BLENDER_EXE.")


def blender_version(exe: Path) -> str:
    out = subprocess.run([str(exe), "--version"], capture_output=True, text=True, timeout=120)
    first = (out.stdout or "").strip().splitlines()
    return first[0].strip() if first else "unknown"


def gpu_info() -> dict:
    smi = shutil.which("nvidia-smi")
    if not smi:
        return {"nvidia_smi": False}
    try:
        out = subprocess.run([smi, "--query-gpu=name,memory.total,memory.free,driver_version",
                              "--format=csv,noheader,nounits"], capture_output=True, text=True, timeout=30)
        name, total, free, driver = [x.strip() for x in out.stdout.strip().splitlines()[0].split(",")]
        return {"nvidia_smi": True, "name": name, "vram_total_mb": int(total),
                "vram_free_mb": int(free), "driver": driver}
    except (OSError, ValueError, IndexError, subprocess.SubprocessError) as exc:
        return {"nvidia_smi": True, "error": str(exc)}


def cmd_detect(a) -> dict:
    path, data = pc.load_manifest(a.manifest)
    exe = find_blender(a.blender, data)
    ver = blender_version(exe)
    env = {
        "os": f"{platform.system()} {platform.release()} ({platform.version()})",
        "blender_exe": str(exe), "blender_version": ver,
        "blender_python": str(next(iter(sorted(exe.parent.glob("*/python/bin/python*"))), "")),
        "gpu": gpu_info(), "detected_at": pc.now_iso(),
    }
    m = re.search(r"(\d+)\.(\d+)", ver)
    if m and (int(m.group(1)), int(m.group(2))) < pc.MIN_BLENDER[:2]:
        env["warning"] = f"Blender {ver} < required {pc.MIN_BLENDER}"
    data["environment"] = env
    pc.save_manifest(path, data)
    return env


def cmd_run(a, extra: list[str]) -> dict:
    path, data = pc.load_manifest(a.manifest)
    script = Path(a.script)
    if not script.suffix:
        script = script.with_suffix(".py")
    if not script.is_absolute():
        script = pc.SCRIPTS_DIR / script
    if not script.is_file():
        raise pc.PipelineError(f"Stage script not found: {script}")
    exe = find_blender(a.blender, data)
    cmd = [str(exe), "--background"]
    if not a.user_startup:
        cmd.append("--factory-startup")
    if not a.no_blend:
        blend = Path(a.blend) if a.blend else pc.to_abs(path, data["paths"]["working_blend"])
        if blend.exists():
            cmd.append(str(blend))
    cmd += ["--python-exit-code", "3", "--python", str(script), "--", "--manifest", str(path)] + extra
    log = pc.project_root(path) / "logs" / f"run_{script.stem}_{pc.stamp()}.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=a.timeout,
                              encoding="utf-8", errors="replace")
    except subprocess.TimeoutExpired as exc:
        log.write_text(f"TIMEOUT after {a.timeout}s\n{exc.stdout or ''}\n{exc.stderr or ''}", encoding="utf-8")
        raise pc.PipelineError(f"Blender timed out after {a.timeout}s; see {log}") from exc
    log.write_text(f"CMD: {' '.join(cmd)}\nEXIT: {proc.returncode}\n--- STDOUT ---\n{proc.stdout}"
                   f"\n--- STDERR ---\n{proc.stderr}", encoding="utf-8")
    result = None
    for line in reversed(proc.stdout.splitlines()):
        if line.startswith(pc.RESULT_MARKER):
            result = json.loads(line[len(pc.RESULT_MARKER):])
            break
    if result is None:
        tail = [l for l in (proc.stderr or proc.stdout).splitlines() if l.strip()][-6:]
        return {"ok": False, "error": "Script produced no result line", "exit_code": proc.returncode,
                "stderr_tail": tail, "run_log": str(log)}
    result["run_log"] = str(log)
    result["exit_code"] = proc.returncode
    return result


def main() -> None:
    argv = sys.argv[1:]
    extra: list[str] = []
    if "--" in argv:
        i = argv.index("--")
        argv, extra = argv[:i], argv[i + 1:]
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    d = sub.add_parser("detect")
    d.add_argument("--manifest", required=True)
    d.add_argument("--blender")
    r = sub.add_parser("run")
    r.add_argument("script")
    r.add_argument("--manifest", required=True)
    r.add_argument("--blend")
    r.add_argument("--no-blend", action="store_true")
    r.add_argument("--blender")
    r.add_argument("--timeout", type=int, default=3600)
    r.add_argument("--user-startup", action="store_true",
                   help="Do not pass --factory-startup (uses user prefs/add-ons, UI language)")
    a = p.parse_args(argv)
    try:
        res = cmd_detect(a) if a.cmd == "detect" else cmd_run(a, extra)
        res.setdefault("ok", True)
        pc.emit(res)
        sys.exit(0 if res["ok"] else 1)
    except pc.PipelineError as exc:
        pc.emit({"ok": False, "error": str(exc)})
        sys.exit(2)


if __name__ == "__main__":
    main()
