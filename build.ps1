# JianFanConverter build script (PowerShell 5.1, ASCII only)
# Builds dist\JianFanConverter.exe with the in-box .NET Framework compiler.
$ErrorActionPreference = 'Stop'

$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcDir = Join-Path $root 'src'
$src    = Join-Path $srcDir 'Program.cs'
$dist   = Join-Path $root 'dist'
$csc    = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$vendor = Join-Path $root 'vendor\opencc'

if (-not (Test-Path -LiteralPath $src))    { throw "source not found: $src" }
if (-not (Test-Path -LiteralPath $csc))    { throw "compiler not found: $csc" }
if (-not (Test-Path -LiteralPath $vendor)) { throw "vendored OpenCC assets not found: $vendor" }

# 1. clean dist
if (Test-Path -LiteralPath $dist) { Remove-Item -LiteralPath $dist -Recurse -Force }
New-Item -ItemType Directory -Path $dist -Force | Out-Null

# 2. collect the OpenCC runtime assets from the project's own vendor folder;
#    they are embedded into the exe as resources (no copy into dist)
#    (self-contained: no external install such as ConvertZZ is required)
$runtime = @('opencc.dll','s2t.json','t2s.json','STPhrases.ocd2','STCharacters.ocd2','TSPhrases.ocd2','TSCharacters.ocd2')
$resources = @()
foreach ($f in $runtime) {
    $from = Join-Path $vendor $f
    if (-not (Test-Path -LiteralPath $from)) { throw "missing vendored runtime file: $from" }
    $resources += ('/resource:"' + $from + '",JianFanConverter.Runtime.' + $f)
}
Write-Host ('embedding ' + $runtime.Count + ' OpenCC runtime assets as resources')

# 3. generate app icon (blue rounded square with white Jian) - optional
$ico = Join-Path $dist 'app.ico'
$iconOk = $false
try {
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object System.Drawing.Bitmap 64, 64
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear([System.Drawing.Color]::Transparent)

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = 28
    $path.AddArc(0, 0, $d, $d, 180, 90)
    $path.AddArc(64 - $d, 0, $d, $d, 270, 90)
    $path.AddArc(64 - $d, 64 - $d, $d, $d, 0, 90)
    $path.AddArc(0, 64 - $d, $d, $d, 90, 90)
    $path.CloseFigure()

    $blue = [System.Drawing.ColorTranslator]::FromHtml('#2563EB')
    $brush = New-Object System.Drawing.SolidBrush $blue
    $g.FillPath($brush, $path)

    $han = [string][char]0x7B80   # U+7B80, the character for Jian
    $font = New-Object System.Drawing.Font('Microsoft YaHei UI', 26, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $white = [System.Drawing.Brushes]::White
    $sz = $g.MeasureString($han, $font)
    $fx = [float]((64 - $sz.Width) / 2)
    $fy = [float]((64 - $sz.Height) / 2) - 1
    $g.DrawString($han, $font, $white, $fx, $fy)

    $g.Dispose()
    $icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    $fs = [System.IO.File]::Create($ico)
    try { $icon.Save($fs) } finally { $fs.Dispose() }
    $icon.Dispose()
    $bmp.Dispose()
    $iconOk = $true
    Write-Host "icon generated: $ico"
}
catch {
    Write-Host ("WARNING: icon generation failed, building without icon: " + $_.Exception.Message)
}

# 4. compile
$exe = Join-Path $dist 'JianFanConverter.exe'
$cscArgs = @(
    '/nologo', '/target:winexe', '/platform:x64', '/optimize+', '/codepage:65001',
    ('/out:"' + $exe + '"'),
    '/reference:System.dll',
    '/reference:System.Core.dll',
    '/reference:System.Drawing.dll',
    '/reference:System.Windows.Forms.dll'
)
if ($iconOk) { $cscArgs += ('/win32icon:"' + $ico + '"') }
$cscArgs += $resources
$cscArgs += ('"' + $src + '"')

Write-Host 'compiling...'
& $csc $cscArgs
$exitCode = $LASTEXITCODE

# app.ico is only a build input for /win32icon; keep dist down to the single exe
if (Test-Path -LiteralPath $ico) { Remove-Item -LiteralPath $ico -Force }

if ($exitCode -ne 0) { throw "compile failed with exit code $exitCode" }
if (-not (Test-Path -LiteralPath $exe)) { throw 'compile produced no exe' }

$distFiles = @(Get-ChildItem -LiteralPath $dist -File)
if ($distFiles.Count -ne 1 -or $distFiles[0].Name -ne 'JianFanConverter.exe') {
    throw ('dist must contain exactly JianFanConverter.exe, found: ' + ($distFiles.Name -join ', '))
}

Write-Host ''
Write-Host 'BUILD OK'
Write-Host ('  exe: ' + $exe + ' (' + [math]::Round((Get-Item -LiteralPath $exe).Length / 1KB, 0) + ' KB)')
Write-Host ('  icon: ' + $(if ($iconOk) { 'embedded via /win32icon' } else { '(none)' }))
Write-Host ('  assets: ' + $runtime.Count + ' embedded (JianFanConverter.Runtime.*)')
Write-Host ('  dist: ' + $distFiles.Count + ' file(s)')
foreach ($df in $distFiles) { Write-Host ('    ' + $df.Name + '  ' + [math]::Round($df.Length / 1KB, 0) + ' KB') }
