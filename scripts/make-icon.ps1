# Renders the Just Go 5K icon (design 3a + "5K", Orange scheme) to PNG.
# Usage: make-icon.ps1 -Size 70 -Out icon.png
#   -Bg "#16324A"  fills the square behind the disc (store icon: no black/transparent)
#   -Mip           snaps colours to the 64-colour MIP palette, no anti-aliasing
param([int]$Size = 70, [string]$Out = "icon.png", [string]$Bg = "", [switch]$Mip)
Add-Type -AssemblyName System.Drawing

$P  = [System.Drawing.ColorTranslator]::FromHtml("#FF8A1F")   # run (primary)
$S  = [System.Drawing.ColorTranslator]::FromHtml("#4DABF7")   # walk (secondary)
$W  = [System.Drawing.ColorTranslator]::FromHtml("#F1EFE8")
$B  = [System.Drawing.ColorTranslator]::FromHtml("#0B0B0B")

$bmp = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.PixelOffsetMode = 'HighQuality'
$g.TextRenderingHint = 'AntiAliasGridFit'
if ($Bg) { $g.Clear([System.Drawing.ColorTranslator]::FromHtml($Bg)) } else { $g.Clear([System.Drawing.Color]::Transparent) }
if ($Mip) { $g.SmoothingMode = 'None'; $g.TextRenderingHint = 'SingleBitPerPixelGridFit' }
$g.ScaleTransform($Size / 100.0, $Size / 100.0)

# Background disc
$g.FillEllipse((New-Object System.Drawing.SolidBrush $B), 1, 1, 98, 98)

# Thin run/walk ring (week 4 run 3 proportions), starting at 12 o'clock
$seq = @(@('r',3),@('w',1.5),@('r',5),@('w',2.5),@('r',3),@('w',1.5),@('r',5))
$a = -90.0
foreach ($q in $seq) {
  $sp = 360.0 * $q[1] / 21.5
  $pen = New-Object System.Drawing.Pen ($(if ($q[0] -eq 'r') { $P } else { $S })), 5
  $g.DrawArc($pen, 6, 6, 88, 88, [single]($a + 2), [single]($sp - 4))
  $a += $sp
}

# Quadratic Bezier helper (converted to cubic)
function AddQuad($path, $x0, $y0, $qx, $qy, $x2, $y2) {
  $c1x = $x0 + 2.0/3.0 * ($qx - $x0); $c1y = $y0 + 2.0/3.0 * ($qy - $y0)
  $c2x = $x2 + 2.0/3.0 * ($qx - $x2); $c2y = $y2 + 2.0/3.0 * ($qy - $y2)
  $path.AddBezier([single]$x0,[single]$y0,[single]$c1x,[single]$c1y,[single]$c2x,[single]$c2y,[single]$x2,[single]$y2)
}

# Shoe group: translate(5,10) scale(0.9)
$state = $g.Save()
$g.TranslateTransform(5, 10)
$g.ScaleTransform(0.9, 0.9)

$shoe = New-Object System.Drawing.Drawing2D.GraphicsPath
$shoe.AddLine(24, 60, 24, 46)
AddQuad $shoe 24 46 25 40 31 41
$shoe.AddLine(31, 41, 39, 43)
AddQuad $shoe 39 43 44 36 51 38
$shoe.AddLine(51, 38, 58, 45)
AddQuad $shoe 58 45 70 49 76 55
AddQuad $shoe 76 55 79 61 73 63
$shoe.AddLine(73, 63, 28, 63)
AddQuad $shoe 28 63 24 63 24 60
$shoe.CloseFigure()
$g.FillPath((New-Object System.Drawing.SolidBrush $W), $shoe)

# Sole (rounded rect)
$sole = New-Object System.Drawing.Drawing2D.GraphicsPath
$r = 9
$sole.AddArc(22, 61, $r, $r, 90, 180)
$sole.AddArc(22 + 58 - $r, 61, $r, $r, 270, 180)
$sole.CloseFigure()
$g.FillPath((New-Object System.Drawing.SolidBrush $S), $sole)

# Play mark with a thin dark outline
$play = New-Object System.Drawing.Drawing2D.GraphicsPath
$play.AddPolygon([System.Drawing.PointF[]]@(
  (New-Object System.Drawing.PointF 41, 46),
  (New-Object System.Drawing.PointF 56, 53.5),
  (New-Object System.Drawing.PointF 41, 61)))
$g.FillPath((New-Object System.Drawing.SolidBrush $P), $play)
$op = New-Object System.Drawing.Pen $B, 1.6
$op.LineJoin = 'Round'
$g.DrawPath($op, $play)

# Laces
$lp = New-Object System.Drawing.Pen $B, 2.4
$lp.StartCap = 'Round'; $lp.EndCap = 'Round'
$g.DrawLine($lp, 45, 40, 49, 44)
$g.DrawLine($lp, 50, 38, 54, 42)
$g.Restore($state)

# "5K" - bold, centred, glyph bottom on y = 37
$tp = New-Object System.Drawing.Drawing2D.GraphicsPath
$ff = New-Object System.Drawing.FontFamily "Segoe UI"
$tp.AddString("5K", $ff, [int][System.Drawing.FontStyle]::Bold, 21, (New-Object System.Drawing.PointF 0, 0), [System.Drawing.StringFormat]::GenericTypographic)
$bb = $tp.GetBounds()
$m = New-Object System.Drawing.Drawing2D.Matrix
$m.Translate([single](50 - $bb.X - $bb.Width / 2), [single](37 - $bb.Y - $bb.Height))
$tp.Transform($m)
$g.FillPath((New-Object System.Drawing.SolidBrush $W), $tp)

if ($Mip) {
  # Snap every pixel to the 64-colour palette (each channel 00/55/AA/FF)
  for ($y = 0; $y -lt $Size; $y++) { for ($x = 0; $x -lt $Size; $x++) {
    $c = $bmp.GetPixel($x, $y)
    if ($c.A -lt 128) { $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0)); continue }
    $q = { param($v) [int]([Math]::Round($v / 85.0) * 85) }
    $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, (& $q $c.R), (& $q $c.G), (& $q $c.B)))
  } }
}
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
"saved $Out ($Size px)"
