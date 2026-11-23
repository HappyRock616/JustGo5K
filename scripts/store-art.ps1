# Builds Connect IQ Store images from simulator screenshots of the vivoactive 5.
# Usage: store-art.ps1 -Shots <folder with vivoactive5-<t>.png> -Out <store folder>
param([string]$Shots, [string]$Out)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Imaging;
public static class Art {
  // Crop the watch from a simulator window capture and make the white background transparent.
  public static Bitmap Watch(string path, int x, int y, int w, int h) {
    using (var src = new Bitmap(path)) {
      var b = new Bitmap(w, h, PixelFormat.Format32bppArgb);
      var px = new Color[w, h];
      for (int j = 0; j < h; j++) for (int i = 0; i < w; i++) px[i, j] = src.GetPixel(x + i, y + j);
      // Flood-fill near-white background from the edges only, so white text on the watch stays.
      var bg = new bool[w, h];
      var q = new System.Collections.Generic.Queue<int>();
      for (int i = 0; i < w; i++) { q.Enqueue(i); q.Enqueue((h - 1) * w + i); }
      for (int j = 0; j < h; j++) { q.Enqueue(j * w); q.Enqueue(j * w + w - 1); }
      while (q.Count > 0) {
        int k = q.Dequeue(), i = k % w, j = k / w;
        if (bg[i, j]) continue;
        var c = px[i, j];
        if (Math.Min(c.R, Math.Min(c.G, c.B)) < 190) continue;
        bg[i, j] = true;
        if (i > 0) q.Enqueue(k - 1); if (i < w - 1) q.Enqueue(k + 1);
        if (j > 0) q.Enqueue(k - w); if (j < h - 1) q.Enqueue(k + w);
      }
      for (int j = 0; j < h; j++) for (int i = 0; i < w; i++) {
        var c = px[i, j];
        if (bg[i, j]) {
          int m = Math.Min(c.R, Math.Min(c.G, c.B));
          int a = m > 236 ? 0 : (236 - m) * 255 / 46;
          b.SetPixel(i, j, Color.FromArgb(a, c.R, c.G, c.B));
        } else b.SetPixel(i, j, c);
      }
      return b;
    }
  }
}
"@

$names = [ordered]@{
  "01-home"        = 3
  "02-run"         = 47
  "03-walk"        = 51
  "04-summary"     = 39
  "05-pace-map"    = 43
  "06-history"     = 7
  "07-start"       = 27
  "08-countdown"   = 31
  "09-stats"       = 11
  "10-graduation"  = 23
}
New-Item -ItemType Directory -Force -Path (Join-Path $Out "screenshots") | Out-Null
$watch = @{}
foreach ($k in $names.Keys) {
  $f = Join-Path $Shots ("vivoactive5-{0}.png" -f $names[$k])
  if (-not (Test-Path $f)) { continue }
  $bmp = [Art]::Watch($f, 50, 255, 505, 505)
  $watch[$k] = $bmp
  # Store screenshot: watch on the store navy, 600x600
  $s = New-Object System.Drawing.Bitmap 600, 600
  $g = [System.Drawing.Graphics]::FromImage($s)
  $g.Clear([System.Drawing.ColorTranslator]::FromHtml("#16324A"))
  $g.InterpolationMode = 'HighQualityBicubic'
  $g.DrawImage($bmp, 25, 25, 550, 550)
  $s.Save((Join-Path $Out "screenshots\$k.png"))
  $g.Dispose(); $s.Dispose()
}

# Hero image 1440x720
$hero = New-Object System.Drawing.Bitmap 1440, 720
$g = [System.Drawing.Graphics]::FromImage($hero)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g.InterpolationMode = 'HighQualityBicubic'
$g.Clear([System.Drawing.ColorTranslator]::FromHtml("#16324A"))
$icon = [System.Drawing.Image]::FromFile((Join-Path $Out "icon-1024-transparent.png"))
$g.DrawImage($icon, 90, 110, 210, 210)
$white = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#F1EFE8"))
$orange = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#FF8A1F"))
$blue = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#4DABF7"))
$g.DrawString("Just Go 5K", (New-Object System.Drawing.Font "Segoe UI", 64, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)), $white, 82, 345)
$g.DrawString("Your run/walk coach,", (New-Object System.Drawing.Font "Segoe UI Semibold", 34, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)), $orange, 88, 440)
$g.DrawString("right on your wrist.", (New-Object System.Drawing.Font "Segoe UI Semibold", 34, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)), $orange, 88, 482)
$g.DrawString(("9 weeks  {0}  3 runs a week  {0}  free" -f [char]0x00B7), (New-Object System.Drawing.Font "Segoe UI", 26, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)), $blue, 90, 560)
if ($watch.Contains("02-run"))      { $g.DrawImage($watch["02-run"], 600, 190, 360, 360) }
if ($watch.Contains("05-pace-map")) { $g.DrawImage($watch["05-pace-map"], 1080, 190, 360, 360) }
if ($watch.Contains("01-home"))     { $g.DrawImage($watch["01-home"], 800, 110, 440, 440) }
$hero.Save((Join-Path $Out "hero-1440x720.png"))
"store art saved to $Out"
