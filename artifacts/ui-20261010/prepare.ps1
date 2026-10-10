param([switch]$Validate)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = $PSScriptRoot
$jobs = Get-Content -LiteralPath (Join-Path $root 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$report = @()
$sources = Get-Content -LiteralPath (Join-Path $root 'sources.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($job in $jobs) {
    if ($sources.($job.name)) { $job.source = $sources.($job.name) }
    if (-not $job.source) { continue }
    $dest = Join-Path $root ($job.name + '.png')
    if (-not (Test-Path -LiteralPath $dest)) {
        $src = [System.Drawing.Bitmap]::FromFile($job.source)
        $dst = New-Object System.Drawing.Bitmap([int]$job.w, [int]$job.h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($dst)
        $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.Clear([System.Drawing.Color]::Transparent)
        # Mantiene le proporzioni: margine trasparente per i ritagli, copertura per gli sfondi.
        if ($job.alpha) {
            $factor = [Math]::Min(($job.w - 8) / $src.Width, ($job.h - 8) / $src.Height)
        } else {
            $factor = [Math]::Max($job.w / $src.Width, $job.h / $src.Height)
        }
        $dw = [int][Math]::Round($src.Width * $factor)
        $dh = [int][Math]::Round($src.Height * $factor)
        $rect = New-Object System.Drawing.Rectangle([int](($job.w - $dw) / 2), [int](($job.h - $dh) / 2), $dw, $dh)
        $wrap = New-Object System.Drawing.Imaging.ImageAttributes
        $wrap.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
        $g.DrawImage($src, $rect, 0, 0, $src.Width, $src.Height, [System.Drawing.GraphicsUnit]::Pixel, $wrap)
        $dst.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
        $wrap.Dispose(); $g.Dispose(); $dst.Dispose(); $src.Dispose()
    }
    if ($Validate) {
        $im = [System.Drawing.Bitmap]::FromFile($dest)
        $zero = 0; $partial = 0; $solid = 0; $edge = 0
        for ($y = 0; $y -lt $im.Height; $y++) {
            for ($x = 0; $x -lt $im.Width; $x++) {
                $a = $im.GetPixel($x, $y).A
                if ($a -eq 0) { $zero++ } elseif ($a -eq 255) { $solid++ } else { $partial++ }
                if (($x -eq 0 -or $y -eq 0 -or $x -eq ($im.Width-1) -or $y -eq ($im.Height-1)) -and $a -gt 0) { $edge++ }
            }
        }
        $ok = $im.Width -eq $job.w -and $im.Height -eq $job.h -and $im.Width -le 1024 -and $im.Height -le 1024 -and ($im.Width % 2) -eq 0 -and ($im.Height % 2) -eq 0
        if ($job.alpha) { $ok = $ok -and $zero -gt 0 -and ($solid + $partial) -gt 0 -and $edge -eq 0 } else { $ok = $ok -and $zero -eq 0 -and $partial -eq 0 }
        $report += [pscustomobject]@{name=$job.name; width=$im.Width; height=$im.Height; transparent=$zero; partial=$partial; opaque=$solid; edge=$edge; ok=$ok}
        $im.Dispose()
    }
}
if ($Validate) {
    $report | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $root 'validation.json') -Encoding UTF8
    $report | Format-Table -AutoSize
    if ($report.Where({-not $_.ok}).Count) { throw 'Verifica PNG fallita: vedere validation.json' }
}
