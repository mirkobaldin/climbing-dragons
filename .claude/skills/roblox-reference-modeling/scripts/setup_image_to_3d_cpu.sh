#!/usr/bin/env bash
# Stable Fast 3D sul percorso CPU (container Linux senza GPU), in un ambiente separato.
#   bash setup_image_to_3d_cpu.sh <progetto> [/opt/sf3d]
# Rete necessaria: github.com (+ release-assets.githubusercontent.com per u2net), pypi.org /
# files.pythonhosted.org, huggingface.co e i suoi CDN (pesi). Token HF letto da $HF_TOKEN.
# Tempo: circa 10 min per PyTorch da PyPI, poi i pesi (~6 GB).
set -euo pipefail
PROJ="$1"; ROOT="${2:-/opt/sf3d}"
mkdir -p "$ROOT"
[ -d "$ROOT/repo/.git" ] || git clone -q https://github.com/Stability-AI/stable-fast-3d "$ROOT/repo"
COMMIT=$(git -C "$ROOT/repo" rev-parse HEAD)
[ -x "$ROOT/venv/bin/python" ] || python3.11 -m venv "$ROOT/venv"
PY="$ROOT/venv/bin/python"
"$PY" -m pip install -q --upgrade pip setuptools wheel
"$PY" -c "import torch" 2>/dev/null || "$PY" -m pip install -q torch==2.5.1 torchvision==0.20.1
grep -v '^\./' "$ROOT/repo/requirements.txt" > "$ROOT/req.txt"
"$PY" -m pip install -q -r "$ROOT/req.txt"
(cd "$ROOT/repo" && USE_CUDA=0 USE_NATIVE_ARCH=0 "$PY" -m pip install -q --no-build-isolation ./texture_baker/ ./uv_unwrapper/)
mkdir -p ~/.u2net
[ -s ~/.u2net/u2net.onnx ] || curl -sSL -o ~/.u2net/u2net.onnx https://github.com/danielgatis/rembg/releases/download/v0.0.0/u2net.onnx
if [ ! -s "$ROOT/weights/model.safetensors" ]; then
  [ -n "${HF_TOKEN:-}" ] || { echo "BLOCCO: manca HF_TOKEN (variabile d'ambiente dell'ambiente cloud)"; exit 2; }
  "$ROOT/venv/bin/huggingface-cli" download stabilityai/stable-fast-3d --local-dir "$ROOT/weights" --token "$HF_TOKEN"
fi
mkdir -p "$PROJ/config"
"$PY" - "$PROJ" "$ROOT" "$COMMIT" <<'PYEOF'
import json, sys, datetime, pathlib
proj, root, commit = sys.argv[1:4]
p = pathlib.Path(proj) / "config" / "image_to_3d_backend.json"
cfg = json.loads(p.read_text()) if p.exists() else {}
cfg.update(enabled=True, required=True, device="cpu", name="StableFast3D", commit=commit,
           repository="https://github.com/Stability-AI/stable-fast-3d",
           license="Stability AI Community License (code + weights): free incl. commercial use under US$1M annual revenue",
           license_verified_at=str(datetime.date.today()), python=f"{root}/venv/bin/python", workdir=f"{root}/repo",
           weights_dir=f"{root}/weights", output_globs=["**/*.glb"], timeout_s=1800,
           command=["{python}", "run.py", "{image}", "--device", "cpu", "--output-dir", "{output_dir}",
                    "--pretrained-model", "{weights}", "--texture-resolution", "512"],
           status="CPU path (no GPU); installed by setup_image_to_3d_cpu.sh")
p.write_text(json.dumps(cfg, indent=2))
print("config", p)
PYEOF
