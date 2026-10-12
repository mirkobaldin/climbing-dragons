# Copia solo i file di consegna, senza cancellare alcun file gia' presente.
$ErrorActionPreference = 'Stop'
$deliveryRoot = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Climbing & Dragons - VFX'
$previous = Join-Path (Split-Path $PSScriptRoot -Parent) 'vfx-mesh-20261012'
$kits = @(
    @{source=$previous; folder='01 - Kit originale 36'; files=@('VFX_Kit_36.blend','VFX_Kit_36.fbx','README.md','manifest.json','validation.json','build_vfx.py','verify_exports.py')},
    @{source=$PSScriptRoot; folder='02 - Nuove 30 elementali'; files=@('VFX_Elementali_30.blend','VFX_Elementali_30.fbx','README.md','CATALOGO.md','PER_CLAUDE.md','manifest.json','validation.json','build_elemental.py','verify_elemental.py')}
)
New-Item -ItemType Directory -Force $deliveryRoot | Out-Null
foreach ($kit in $kits) {
    $destination = Join-Path $deliveryRoot $kit.folder
    New-Item -ItemType Directory -Force $destination | Out-Null
    foreach ($name in $kit.files) {
        Copy-Item -LiteralPath (Join-Path $kit.source $name) -Destination (Join-Path $destination $name) -Force
    }
    foreach ($folder in @('fbx','preview','textures')) {
        $sourceFolder = Join-Path $kit.source $folder
        if (-not (Test-Path -LiteralPath $sourceFolder)) { continue }
        $targetFolder = Join-Path $destination $folder
        New-Item -ItemType Directory -Force $targetFolder | Out-Null
        Get-ChildItem -LiteralPath $sourceFolder -File | Where-Object { $_.Extension -in @('.fbx','.png') } | ForEach-Object {
            $targetFile = Join-Path $targetFolder $_.Name
            Copy-Item -LiteralPath $_.FullName -Destination $targetFile -Force
            if ((Get-FileHash -LiteralPath $_.FullName).Hash -ne (Get-FileHash -LiteralPath $targetFile).Hash) { throw "Copia non identica: $targetFile" }
        }
    }
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'PER_CLAUDE.md') -Destination (Join-Path $deliveryRoot 'LEGGIMI - PER CLAUDE.md') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'preview/30_elementali.png') -Destination (Join-Path $deliveryRoot 'ANTEPRIMA - Nuove 30.png') -Force
Copy-Item -LiteralPath (Join-Path $previous 'preview/kit_36.png') -Destination (Join-Path $deliveryRoot 'ANTEPRIMA - Prime 36.png') -Force
$message = @'
CLIMBING & DRAGONS - 66 MESH VFX

01 - Kit originale 36: le prime 36 forme.
02 - Nuove 30 elementali: le nuove 30, dedicate agli otto elementi dei draghi.

Apri le immagini ANTEPRIMA per guardare i modelli.
I file .blend si aprono con Blender; gli FBX si importano in Roblox Studio.
I modelli sono statici: Claude deve collegarli e animarli negli attacchi.

MESSAGGIO DA COPIARE A CLAUDE:
Leggi il file C:\Users\mirko\Desktop\Climbing & Dragons - VFX\LEGGIMI - PER CLAUDE.md.
Codex ha creato 66 mesh VFX, incluse 30 nuove forme per gli otto elementi dei draghi.
Importale e usale negli attacchi di draghi e mostri seguendo la tabella di associazione;
collegale a DragonVFX/VFXKit e verifica il risultato in Play.
'@
[IO.File]::WriteAllText((Join-Path $deliveryRoot 'INIZIA QUI.txt'),$message,[Text.UTF8Encoding]::new($false))
$count = @(Get-ChildItem -LiteralPath $deliveryRoot -Recurse -File -Filter '*.fbx' | Where-Object { $_.Name -match '^VFX_[0-9]{2}_' }).Count
if ($count -ne 66) { throw "Attesi 66 FBX singoli, trovati $count" }
Write-Output "Consegnate 66 mesh in $deliveryRoot"
