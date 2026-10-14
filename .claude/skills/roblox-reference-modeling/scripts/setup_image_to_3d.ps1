<#
Installs the mandatory image-to-3D backend (Stable Fast 3D, Stability AI) in its own
virtual environment and writes <project>/config/image_to_3d_backend.json for
image_to_3d_backend.py. Windows + NVIDIA GPU (tested target: RTX 4070 Laptop, 8 GB).

  powershell -ExecutionPolicy Bypass -File setup_image_to_3d.ps1 -Project C:\path\to\project [-Root C:\ai] [-InstallPrereqs]

What it does (each step is skipped when already done):
  1. checks nvidia-smi, git, Python 3.11 (py launcher), VS 2022 C++ build tools, CUDA Toolkit 12.x
     (-InstallPrereqs installs the missing ones with winget; free, large downloads)
  2. clones https://github.com/Stability-AI/stable-fast-3d into <Root>\stable-fast-3d and records the commit
  3. creates <Root>\stable-fast-3d\.venv (never Blender's Python), installs PyTorch 2.5.1 + CUDA 12.4,
     the repo requirements and builds texture_baker / uv_unwrapper with the VS + CUDA compilers
  4. downloads the gated weights stabilityai/stable-fast-3d into <Root>\stable-fast-3d\weights
     (needs a Hugging Face account that accepted the model terms + a read token: huggingface-cli login)
  5. verifies: torch sees CUDA, extensions import, `run.py --help` works
  6. writes the backend config into the project (enabled = true, commit, license check date)

License (read 2026-10-14 on the official repo, LICENSE.md): Stability AI Community License -
free for research, non-commercial and commercial use while annual revenue < US$1,000,000;
above that an Enterprise license is required. The weights are covered by the same license.
STATUS: written, not yet executed on the target machine.
#>
param(
    [Parameter(Mandatory = $true)][string]$Project,
    [string]$Root = "C:\ai",
    [switch]$InstallPrereqs
)
$ErrorActionPreference = "Stop"
$Repo = "https://github.com/Stability-AI/stable-fast-3d"
$Dir = Join-Path $Root "stable-fast-3d"
$Venv = Join-Path $Dir ".venv"
$Py = Join-Path $Venv "Scripts\python.exe"
$Weights = Join-Path $Dir "weights"

function Step($t) { Write-Host "`n== $t" -ForegroundColor Cyan }
function Fail($t) { Write-Host "BLOCCO: $t" -ForegroundColor Red; exit 2 }
function Have($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

Step "1. Prerequisiti"
if (-not (Have "nvidia-smi")) { Fail "nvidia-smi non trovato: installa il driver NVIDIA." }
$gpu = (& nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader) -join "; "
Write-Host "GPU: $gpu"
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = $null
if (Test-Path $vswhere) { $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath }
$nvcc = Get-Command nvcc -ErrorAction SilentlyContinue
$missing = @()
if (-not (Have "git")) { $missing += "Git.Git" }
$pyOk = $false
if (Have "py") { & py -3.11 -c "import sys" 2>$null; $pyOk = ($LASTEXITCODE -eq 0) }
if (-not $pyOk) { $missing += "Python.Python.3.11" }
if (-not $vs) { $missing += "Microsoft.VisualStudio.2022.BuildTools" }
if (-not $nvcc) { $missing += "Nvidia.CUDA" }
if ($missing.Count -gt 0) {
    if (-not $InstallPrereqs) { Fail ("mancano: " + ($missing -join ", ") + ". Rilancia con -InstallPrereqs (winget) o installali a mano: Git, Python 3.11, VS 2022 Build Tools con 'Sviluppo di applicazioni desktop C++', CUDA Toolkit 12.4.") }
    foreach ($id in $missing) {
        $extra = @()
        if ($id -eq "Microsoft.VisualStudio.2022.BuildTools") { $extra = @("--override", "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended") }
        if ($id -eq "Nvidia.CUDA") { $extra = @("--version", "12.4") }
        winget install --id $id -e --accept-package-agreements --accept-source-agreements @extra
    }
    Fail "prerequisiti installati: chiudi e riapri PowerShell (PATH aggiornato) e rilancia lo script."
}
$nvccVer = (& nvcc --version | Select-String "release (\d+\.\d+)").Matches[0].Groups[1].Value
if (-not $nvccVer.StartsWith("12.")) { Fail "CUDA Toolkit $nvccVer: serve 12.x (PyTorch cu124)." }
Write-Host "VS: $vs`nCUDA Toolkit: $nvccVer"

Step "2. Repository ufficiale"
New-Item -ItemType Directory -Force -Path $Root | Out-Null
if (-not (Test-Path (Join-Path $Dir ".git"))) { git clone $Repo $Dir; if ($LASTEXITCODE) { Fail "git clone fallito" } }
$commit = (git -C $Dir rev-parse HEAD).Trim()
Write-Host "commit $commit"

Step "3. Ambiente separato e dipendenze"
if (-not (Test-Path $Py)) { & py -3.11 -m venv $Venv }
& $Py -m pip install --upgrade pip setuptools wheel
& $Py -c "import torch,sys; sys.exit(0 if torch.cuda.is_available() else 1)" 2>$null
if ($LASTEXITCODE -ne 0) {
    & $Py -m pip install torch==2.5.1 torchvision==0.20.1 --index-url https://download.pytorch.org/whl/cu124
    if ($LASTEXITCODE) { Fail "installazione di PyTorch fallita" }
}
$req = Get-Content (Join-Path $Dir "requirements.txt") | Where-Object { $_ -and -not $_.StartsWith("./") }
$reqFile = Join-Path $Dir "requirements.noext.txt"
$req | Set-Content $reqFile
& $Py -m pip install -r $reqFile
if ($LASTEXITCODE) { Fail "pip install -r requirements fallito" }
# estensioni C++/CUDA: compilate con i compilatori di VS (vcvars64) e la GPU Ada (8.9)
$vcvars = Join-Path $vs "VC\Auxiliary\Build\vcvars64.bat"
$env:TORCH_CUDA_ARCH_LIST = "8.9"
$env:DISTUTILS_USE_SDK = "1"
cmd /c "`"$vcvars`" && cd /d `"$Dir`" && `"$Py`" -m pip install --no-build-isolation ./texture_baker/ ./uv_unwrapper/"
if ($LASTEXITCODE) { Fail "compilazione di texture_baker / uv_unwrapper fallita (controlla VS C++ e CUDA 12.x)" }

Step "4. Pesi (Hugging Face, modello gated)"
if (-not (Test-Path (Join-Path $Weights "model.safetensors"))) {
    $hf = Join-Path $Venv "Scripts\huggingface-cli.exe"
    & $hf whoami 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Accetta i termini su https://huggingface.co/stabilityai/stable-fast-3d e crea un token 'read' su https://huggingface.co/settings/tokens"
        & $hf login
    }
    & $hf download stabilityai/stable-fast-3d --local-dir $Weights
    if ($LASTEXITCODE) { Fail "download dei pesi fallito (accesso al modello gated non concesso?)" }
}

Step "5. Verifica"
& $Py -c "import torch, texture_baker, uv_unwrapper; print('torch', torch.__version__, 'cuda', torch.cuda.is_available(), torch.cuda.get_device_name(0))"
if ($LASTEXITCODE) { Fail "verifica di torch/estensioni fallita" }
Push-Location $Dir
& $Py run.py --help | Out-Null
$help = $LASTEXITCODE
Pop-Location
if ($help) { Fail "run.py --help fallito" }

Step "6. Configurazione del backend nel progetto"
$cfgDir = Join-Path $Project "config"
New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
$cfg = [ordered]@{
    enabled = $true
    required = $true
    status = "installed by setup_image_to_3d.ps1; first generation not yet run"
    name = "StableFast3D"
    repository = $Repo
    commit = $commit
    license = "Stability AI Community License (code + weights): free incl. commercial use under US`$1M annual revenue"
    license_verified_at = (Get-Date -Format "yyyy-MM-dd")
    vram_required_gb = 6.0
    vram_source = "README: about 6 GB VRAM for a single image with default options"
    max_vram_gb = 8.0
    python = $Py
    workdir = $Dir
    weights_dir = $Weights
    command = @("{python}", "run.py", "{image}", "--output-dir", "{output_dir}", "--pretrained-model", "{weights}",
                "--texture-resolution", "1024", "--remesh_option", "triangle", "--target_vertex_count", "9000")
    output_globs = @("**/*.glb")
    output_axes = "glTF (Y up); Blender's glTF importer converts to Z up"
    timeout_s = 900
}
$cfg | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 (Join-Path $cfgDir "image_to_3d_backend.json")
Write-Host "Scritto $(Join-Path $cfgDir 'image_to_3d_backend.json')" -ForegroundColor Green
Write-Host "Prossimo passo: python image_to_3d_backend.py check --manifest `"$Project`""
