$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = $PSScriptRoot
$allJobs = Get-Content -LiteralPath (Join-Path $root 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$jobs = @($allJobs | Where-Object { $_.slice -and $_.name -notlike 'btn_round_*' })
$font = New-Object System.Drawing.Font('Consolas', 12)
$ink = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
for ($page = 0; $page -lt [Math]::Ceiling($jobs.Count / 4); $page++) {
    $sheet = New-Object System.Drawing.Bitmap(1000, 880)
    $g = [System.Drawing.Graphics]::FromImage($sheet)
    $g.Clear([System.Drawing.Color]::FromArgb(55, 59, 68))
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    for ($i = 0; $i -lt 4; $i++) {
        $k = $page * 4 + $i
        if ($k -ge $jobs.Count) { break }
        $j = $jobs[$k]
        $im = [System.Drawing.Bitmap]::FromFile((Join-Path $root ($j.name + '.png')))
        $g.DrawString(($j.name + ' / SliceScale 0.5'), $font, $ink, 10, [float]($i*220))
        $sx = @(0, $j.slice[0], ($j.w-$j.slice[2]), $j.w)
        $sy = @(0, $j.slice[1], ($j.h-$j.slice[3]), $j.h)
        foreach ($size in @(@(10, 360, 180), @(410, 560, 130))) {
            $ox = $size[0]; $oy = $i*220+30; $w=$size[1]; $h=$size[2]
            $dx = @($ox, ($ox+$j.slice[0]*0.5), ($ox+$w-$j.slice[2]*0.5), ($ox+$w))
            $dy = @($oy, ($oy+$j.slice[1]*0.5), ($oy+$h-$j.slice[3]*0.5), ($oy+$h))
            for ($ry=0; $ry -lt 3; $ry++) {
                for ($rx=0; $rx -lt 3; $rx++) {
                    $dest = New-Object System.Drawing.Rectangle([int]$dx[$rx], [int]$dy[$ry], [int]($dx[$rx+1]-$dx[$rx]), [int]($dy[$ry+1]-$dy[$ry]))
                    $g.DrawImage($im, $dest, [int]$sx[$rx], [int]$sy[$ry], [int]($sx[$rx+1]-$sx[$rx]), [int]($sy[$ry+1]-$sy[$ry]), [System.Drawing.GraphicsUnit]::Pixel)
                }
            }
        }
        $im.Dispose()
    }
    $sheet.Save((Join-Path $root ('review/slices-' + ($page+1) + '.png')), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $sheet.Dispose()
}
$font.Dispose(); $ink.Dispose()
