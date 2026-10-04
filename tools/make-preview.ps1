# Regenerates AutoinjectThresholdTweak/PreviewImage.png (the Steam Workshop thumbnail) from vanilla game icons.
# Usage: powershell -ExecutionPolicy Bypass -File tools\make-preview.ps1 [-GamePath "<Barotrauma install folder>"]
param([string]$GamePath = 'C:\Program Files (x86)\Steam\steamapps\common\Barotrauma')

Add-Type -AssemblyName System.Drawing
$game = $GamePath
$out  = Join-Path $PSScriptRoot '..\AutoinjectThresholdTweak\PreviewImage.png'

$size = 512
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.InterpolationMode = 'HighQualityBicubic'
$g.TextRenderingHint = 'AntiAliasGridFit'

# background: dark teal vertical gradient
$rect = New-Object System.Drawing.Rectangle 0, 0, $size, $size
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.Color]::FromArgb(18, 32, 38)), ([System.Drawing.Color]::FromArgb(6, 12, 16)), 90
$g.FillRectangle($bg, $rect)

function Draw-Icon($file, $sx, $sy, $sw, $sh, $cx, $cy, $scale) {
    $img = [System.Drawing.Image]::FromFile($file)
    $w = [int]($sw * $scale); $h = [int]($sh * $scale)
    $dst = New-Object System.Drawing.Rectangle ([int]($cx - $w / 2)), ([int]($cy - $h / 2)), $w, $h
    $src = New-Object System.Drawing.Rectangle $sx, $sy, $sw, $sh
    $g.DrawImage($img, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
    $img.Dispose()
}

$titleFont = New-Object System.Drawing.Font 'Segoe UI', 30, ([System.Drawing.FontStyle]::Bold)
$subFont   = New-Object System.Drawing.Font 'Segoe UI', 15, ([System.Drawing.FontStyle]::Regular)
$pctFont   = New-Object System.Drawing.Font 'Segoe UI', 44, ([System.Drawing.FontStyle]::Bold)
$lblFont   = New-Object System.Drawing.Font 'Segoe UI', 14, ([System.Drawing.FontStyle]::Bold)
$white = [System.Drawing.Brushes]::White
$muted = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(150, 175, 185))
$red   = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(235, 80, 70))
$center = New-Object System.Drawing.StringFormat
$center.Alignment = 'Center'

$g.DrawString('AUTOINJECT', $titleFont, $white, (New-Object System.Drawing.RectangleF 0, 28, $size, 50), $center)
$g.DrawString('THRESHOLD TWEAK', $titleFont, $white, (New-Object System.Drawing.RectangleF 0, 72, $size, 50), $center)
$g.DrawString('adjustable in-game', $subFont, $muted, (New-Object System.Drawing.RectangleF 0, 128, $size, 30), $center)

# divider
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(60, 90, 100)), 2
$g.DrawLine($pen, 256, 190, 256, 470)

# left: autoinjector headset
Draw-Icon "$game\Content\Items\JobGear\TalentGear.png" 113 264 58 45 128 270 2.6
$g.DrawString('AUTOINJECTOR HEADSET', $lblFont, $muted, (New-Object System.Drawing.RectangleF 0, 340, 256, 24), $center)
$g.DrawString('5%', $pctFont, $red, (New-Object System.Drawing.RectangleF 0, 372, 256, 70), $center)
$g.DrawString('default', $subFont, $muted, (New-Object System.Drawing.RectangleF 0, 440, 256, 26), $center)

# right: PUCS
Draw-Icon "$game\Content\Items\InventoryIconAtlas2.png" 384 704 128 128 384 262 1.15
$g.DrawString('PUCS', $lblFont, $muted, (New-Object System.Drawing.RectangleF 256, 340, 256, 24), $center)
$g.DrawString('30%', $pctFont, $red, (New-Object System.Drawing.RectangleF 256, 372, 256, 70), $center)
$g.DrawString('default', $subFont, $muted, (New-Object System.Drawing.RectangleF 256, 440, 256, 26), $center)

$g.Dispose()
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Get-Item $out | Select-Object Name, Length
