$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = $PSScriptRoot
$review = Join-Path $root 'review'
New-Item -ItemType Directory -Path $review -Force | Out-Null
$jobs = Get-Content -LiteralPath (Join-Path $root 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$font = New-Object System.Drawing.Font('Consolas', 11)
$ink = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$light = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(64, 68, 77))
$dark = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(38, 42, 50))
for ($page = 0; $page -lt [Math]::Ceiling($jobs.Count / 20); $page++) {
    $sheet = New-Object System.Drawing.Bitmap(1000, 1000)
    $g = [System.Drawing.Graphics]::FromImage($sheet)
    $g.Clear([System.Drawing.Color]::FromArgb(16, 20, 28))
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    for ($i = 0; $i -lt 20; $i++) {
        $k = $page * 20 + $i
        if ($k -ge $jobs.Count) { break }
        $job = $jobs[$k]
        $x = ($i % 4) * 250
        $y = [Math]::Floor($i / 4) * 200
        for ($yy = 0; $yy -lt 150; $yy += 10) {
            for ($xx = 0; $xx -lt 240; $xx += 10) {
                $brush = if ((($xx + $yy) / 10) % 2 -eq 0) { $light } else { $dark }
                $g.FillRectangle($brush, [int]($x+$xx), [int]($y+$yy), 10, 10)
            }
        }
        $file = Join-Path $root ($job.name + '.png')
        if (Test-Path -LiteralPath $file) {
            $im = [System.Drawing.Bitmap]::FromFile($file)
            $scale = [Math]::Min(224 / $im.Width, 140 / $im.Height)
            $w = [int]($im.Width * $scale); $h = [int]($im.Height * $scale)
            $g.DrawImage($im, [int]($x+(240-$w)/2), [int]($y+(150-$h)/2), $w, $h)
            $g.DrawImage($im, [int]($x+200), [int]($y+162), 32, 32)
            $im.Dispose()
        }
        $g.DrawString($job.name, $font, $ink, [float]$x, [float]($y+152))
    }
    $sheet.Save((Join-Path $review ('contact-' + ($page+1) + '.png')), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $sheet.Dispose()
}
$font.Dispose(); $ink.Dispose(); $light.Dispose(); $dark.Dispose()
