# Regenerate docs/screenshot.png for the READMEs (PowerShell 5.1, ASCII only).
#
# It launches dist\JianFanConverter.exe, types the self-check sample into the source
# pane, waits for the debounced conversion, then captures the client area only
# (no OS title bar, no caption-button artifacts) and overwrites docs/screenshot.png.
#
# Why the backspace: WM_SETTEXT is the only pointer-safe way to write text into a
# window owned by another process, but it does not raise TextChanged, so the
# placeholder label would still cover the text and no conversion would start.
# Writing "text + space" and then deleting that space with a real WM_CHAR makes the
# control raise EN_CHANGE, which fires TextChanged exactly as typing would.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools\screenshot.ps1
param(
    [string]$ExePath = '',
    [string]$OutPath = ''
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $ExePath) { $ExePath = Join-Path $root 'dist\JianFanConverter.exe' }
if (-not $OutPath) { $OutPath = Join-Path $root 'docs\screenshot.png' }
if (-not (Test-Path -LiteralPath $ExePath)) {
    throw ('missing ' + $ExePath + ' - run build.ps1 first')
}

Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class JfShot {
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr lParam);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, StringBuilder l);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, string l);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, EntryPoint="SendMessageW")]
    public static extern IntPtr SendMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L; public int T; public int R; public int B; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
}
'@

[void][JfShot]::SetProcessDPIAware()
Add-Type -AssemblyName System.Drawing

# Sample from the self-check list; kept as code points so this script stays ASCII:
#   U+6C49 U+5B57 U+8F6C U+6362 U+6D4B U+8BD5 U+FF0C
#   U+8F6F U+4EF6 U+548C U+786C U+4EF6 U+3002
$chars = @(0x6C49, 0x5B57, 0x8F6C, 0x6362, 0x6D4B, 0x8BD5, 0xFF0C,
           0x8F6F, 0x4EF6, 0x548C, 0x786C, 0x4EF6, 0x3002)
$sample = ''
foreach ($code in $chars) { $sample = $sample + [char]$code }

Get-Process JianFanConverter -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 400

$p = Start-Process -FilePath $ExePath -WorkingDirectory (Split-Path -Parent $ExePath) -PassThru
$deadline = (Get-Date).AddSeconds(20)
while ($p.MainWindowHandle -eq [IntPtr]::Zero -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 200
    $p.Refresh()
}
if ($p.MainWindowHandle -eq [IntPtr]::Zero) { throw 'the app did not open a main window' }
Start-Sleep -Milliseconds 700

# EnumChildWindows already walks every descendant; dedupe by handle.
$script:kids = New-Object System.Collections.ArrayList
$cb = [JfShot+EnumProc]{
    param([IntPtr]$c, [IntPtr]$l)
    [void]$script:kids.Add($c)
    return $true
}
[void][JfShot]::EnumChildWindows($p.MainWindowHandle, $cb, [IntPtr]::Zero)

$seen = @{}
$edits = New-Object System.Collections.ArrayList
foreach ($h in $script:kids) {
    $key = $h.ToString()
    if ($seen.ContainsKey($key)) { continue }
    $seen[$key] = $true
    $sb = New-Object System.Text.StringBuilder 256
    [void][JfShot]::GetClassName($h, $sb, 256)
    if ($sb.ToString() -notlike '*EDIT*') { continue }
    $r = New-Object JfShot+RECT
    [void][JfShot]::GetWindowRect($h, [ref]$r)
    if (($r.B - $r.T) -lt 100) { continue }
    if (($r.R - $r.L) -lt 100) { continue }
    [void]$edits.Add([pscustomobject]@{ H = $h; L = $r.L })
}
if ($edits.Count -ne 2) { throw ('expected 2 text panes, found ' + $edits.Count) }
$sorted = @($edits | Sort-Object L)
$input = [IntPtr]$sorted[0].H

[void][JfShot]::SendMessage($input, 0x000C, [IntPtr]::Zero, ($sample + ' '))
$len = $sample.Length + 1
[void][JfShot]::SendMessageW($input, 0x00B1, [IntPtr]$len, [IntPtr]$len)    # EM_SETSEL: caret to end
Start-Sleep -Milliseconds 120
[void][JfShot]::SendMessageW($input, 0x0102, [IntPtr]0x08, [IntPtr]::Zero)  # WM_CHAR: backspace
Start-Sleep -Milliseconds 1500

$sbIn = New-Object System.Text.StringBuilder 4096
[void][JfShot]::SendMessage($input, 0x000D, [IntPtr]4096, $sbIn)
if ($sbIn.ToString() -ne $sample) {
    throw ('source pane does not hold the sample text (got ' + $sbIn.Length + ' chars)')
}

# Render the client area straight into a bitmap with PrintWindow (PW_CLIENTONLY).
# CopyFromScreen would read whatever happens to be on top of that screen region, so it
# can silently capture another window when the app is not foreground; PrintWindow asks
# the window to paint itself and never touches the desktop.
$client = New-Object JfShot+RECT
[void][JfShot]::GetClientRect($p.MainWindowHandle, [ref]$client)
$w = $client.R - $client.L
$h = $client.B - $client.T
if ($w -le 0 -or $h -le 0) { throw 'the window has no client area' }

$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
try {
    $ok = [JfShot]::PrintWindow($p.MainWindowHandle, $hdc, 1)
} finally {
    $g.ReleaseHdc($hdc)
    $g.Dispose()
}
if (-not $ok) { $bmp.Dispose(); throw 'PrintWindow failed; refusing to fall back to a screen grab' }

$outDir = Split-Path -Parent $OutPath
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

$p.Refresh()
if (-not $p.HasExited) { $p.CloseMainWindow() | Out-Null; Start-Sleep -Seconds 1; $p.Refresh() }
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }

$fi = Get-Item -LiteralPath $OutPath
Write-Host ('saved: ' + $fi.FullName)
Write-Host ('size : ' + $w + 'x' + $h + ', ' + $fi.Length + ' bytes')
