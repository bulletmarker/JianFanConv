# JianFanConverter UI smoke test (PowerShell 5.1, ASCII only).
#
# Builds the app (unless -SkipBuild), cold-starts it, drives the real WinForms
# controls through WM_SETTEXT / WM_KEYDOWN, and asserts every conversion mode.
# Copy/clear use a real foreground click, which briefly moves the mouse.
#
# All Chinese literals are built from code points so this file stays ASCII:
# PowerShell 5.1 misparses UTF-8 .ps1 files that have no BOM.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools\smoke.ps1
#   powershell -ExecutionPolicy Bypass -File tools\smoke.ps1 -SkipBuild
#   powershell -ExecutionPolicy Bypass -File tools\smoke.ps1 -SkipInteractive
param(
    [string]$ExePath = '',
    [switch]$SkipBuild,
    [switch]$SkipInteractive
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $ExePath) { $ExePath = Join-Path $root 'dist\JianFanConverter.exe' }
$ExePath = [System.IO.Path]::GetFullPath($ExePath)

function Chars([int[]]$codes) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($code in $codes) { [void]$sb.Append([char]$code) }
    return $sb.ToString()
}

$DIRECTION  = Chars @(0x65B9, 0x5411, 0x5207, 0x6362)
$REGION     = Chars @(0x7E41, 0x4F53, 0x5730, 0x533A)
$PHRASES    = Chars @(0x5730, 0x533A, 0x7528, 0x8BCD)
$COPY       = Chars @(0x590D, 0x5236)
$CLEAR      = Chars @(0x6E05, 0x7A7A)

$S1 = Chars @(0x6C49, 0x5B57, 0x8F6C, 0x6362, 0x6D4B, 0x8BD5, 0xFF0C,
              0x8F6F, 0x4EF6, 0x548C, 0x786C, 0x4EF6, 0x3002)
$S2 = Chars @(0x8F6F, 0x4EF6, 0x548C, 0x786C, 0x76D8, 0xFF0C,
              0x9F20, 0x6807, 0xFF0C, 0x6253, 0x5370, 0x673A, 0x3002)
$S3 = Chars @(0x6F22, 0x5B57, 0x8F49, 0x63DB, 0x6E2C, 0x8A66, 0xFF0C,
              0x8EDF, 0x9AD4, 0x548C, 0x786C, 0x9AD4, 0x3002)
$E_TW_PHRASES = $S3
$E_STANDARD = Chars @(0x6F22, 0x5B57, 0x8F49, 0x63DB, 0x6E2C, 0x8A66, 0xFF0C,
                      0x8EDF, 0x4EF6, 0x548C, 0x786C, 0x4EF6, 0x3002)
$E_HK_PHRASES = Chars @(0x8EDF, 0x4EF6, 0x548C, 0x786C, 0x789F, 0xFF0C,
                        0x6ED1, 0x9F20, 0xFF0C, 0x6253, 0x5370, 0x6A5F, 0x3002)
$E_TW_PHRASES2 = Chars @(0x8EDF, 0x9AD4, 0x548C, 0x786C, 0x789F, 0xFF0C,
                         0x6ED1, 0x9F20, 0xFF0C, 0x5370, 0x8868, 0x6A5F, 0x3002)
$E_TW_PLAIN = Chars @(0x8EDF, 0x4EF6, 0x548C, 0x786C, 0x76E4, 0xFF0C,
                      0x9F20, 0x6A19, 0xFF0C, 0x6253, 0x5370, 0x6A5F, 0x3002)
$E_REVERSE = $S1

Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class Smoke {
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr lParam);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, EntryPoint="SendMessageW")] public static extern IntPtr SendText(IntPtr h, uint msg, IntPtr w, string l);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, EntryPoint="SendMessageW")] public static extern IntPtr SendSb(IntPtr h, uint msg, IntPtr w, StringBuilder l);
    [DllImport("user32.dll", EntryPoint="SendMessageW")] public static extern IntPtr SendInt(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint attach, uint attachTo, bool f);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr SetFocus(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, int dx, int dy, uint data, IntPtr extra);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L; public int T; public int R; public int B; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
}
'@

function Get-Text([IntPtr]$h) {
    $sb = New-Object System.Text.StringBuilder 8192
    [void][Smoke]::SendSb($h, 0x000D, [IntPtr]8192, $sb)
    return $sb.ToString()
}

function Get-Class([IntPtr]$h) {
    $sb = New-Object System.Text.StringBuilder 256
    [void][Smoke]::GetClassName($h, $sb, 256)
    return $sb.ToString()
}

function Send-Key([IntPtr]$h, [int]$vk) {
    [void][Smoke]::SendInt($h, 0x0100, [IntPtr]$vk, [IntPtr]::Zero)
    [void][Smoke]::SendInt($h, 0x0101, [IntPtr]$vk, [IntPtr]::Zero)
}

function Force-Foreground([IntPtr]$h) {
    if ([Smoke]::GetForegroundWindow() -eq $h) { return $true }
    $fg = [Smoke]::GetForegroundWindow()
    [uint32]$fgPid = 0
    [uint32]$appPid = 0
    $fgThread = [Smoke]::GetWindowThreadProcessId($fg, [ref]$fgPid)
    $appThread = [Smoke]::GetWindowThreadProcessId($h, [ref]$appPid)
    if ($fgThread -ne $appThread) { [void][Smoke]::AttachThreadInput($fgThread, $appThread, $true) }
    [void][Smoke]::ShowWindow($h, 9)
    [void][Smoke]::BringWindowToTop($h)
    [void][Smoke]::SetForegroundWindow($h)
    [void][Smoke]::SetFocus($h)
    if ($fgThread -ne $appThread) { [void][Smoke]::AttachThreadInput($fgThread, $appThread, $false) }
    Start-Sleep -Milliseconds 300
    return ([Smoke]::GetForegroundWindow() -eq $h)
}

function Click-Real([IntPtr]$h) {
    $r = New-Object Smoke+RECT
    [void][Smoke]::GetWindowRect($h, [ref]$r)
    $x = [int](($r.L + $r.R) / 2)
    $y = [int](($r.T + $r.B) / 2)
    [void][Smoke]::SetCursorPos($x, $y)
    Start-Sleep -Milliseconds 120
    [Smoke]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [Smoke]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero)
}

function Find-Control($items, [string]$text) {
    $hit = @($items | Where-Object { $_.Text -eq $text } | Select-Object -First 1)
    if ($hit.Count -eq 0) { return [IntPtr]::Zero }
    return $hit[0].H
}

function Wait-Text([IntPtr]$h, [string]$expected, [int]$timeoutMs = 8000) {
    $deadline = (Get-Date).AddMilliseconds($timeoutMs)
    do {
        Start-Sleep -Milliseconds 120
        if ((Get-Text $h) -eq $expected) { return $true }
    } while ((Get-Date) -lt $deadline)
    return $false
}

function Wait-Cache([string]$dir, [int]$expected, [int]$timeoutMs = 10000) {
    $deadline = (Get-Date).AddMilliseconds($timeoutMs)
    do {
        Start-Sleep -Milliseconds 200
        if (Test-Path -LiteralPath $dir) {
            $n = @(Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.Name -notlike '*.tmp' }).Count
            if ($n -eq $expected) { return $true }
        }
    } while ((Get-Date) -lt $deadline)
    return $false
}

$script:fail = 0
function Check([string]$name, [bool]$ok, [string]$detail) {
    if ($ok) {
        Write-Host ('PASS  ' + $name)
    } else {
        Write-Host ('FAIL  ' + $name + '  ' + $detail)
        $script:fail++
    }
}

Get-Process JianFanConverter -ErrorAction SilentlyContinue | Stop-Process -Force

if (-not $SkipBuild) {
    $ps = Join-Path $PSHOME 'powershell.exe'
    & $ps -ExecutionPolicy Bypass -File (Join-Path $root 'build.ps1')
    if ($LASTEXITCODE -ne 0) { throw ('build failed with exit code ' + $LASTEXITCODE) }
}
if (-not (Test-Path -LiteralPath $ExePath)) { throw ('missing ' + $ExePath) }

$localAppData = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::LocalApplicationData)
$tempRoot = [System.IO.Path]::GetTempPath()
$cachePrimary = Join-Path (Join-Path $localAppData 'JianFanConv') 'runtime-r2'
$cacheFallback = Join-Path (Join-Path $tempRoot 'JianFanConv') 'runtime-r2'
Remove-Item -LiteralPath $cachePrimary -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $cacheFallback -Recurse -Force -ErrorAction SilentlyContinue

$oldCursor = New-Object Smoke+POINT
[void][Smoke]::GetCursorPos([ref]$oldCursor)
$oldForeground = [Smoke]::GetForegroundWindow()
$proc = $null
$main = [IntPtr]::Zero
try {
    $proc = Start-Process -FilePath $ExePath -WorkingDirectory (Split-Path -Parent $ExePath) -PassThru
    $deadline = (Get-Date).AddSeconds(20)
    while ($main -eq [IntPtr]::Zero -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 200
        $proc.Refresh()
        $main = $proc.MainWindowHandle
    }
    if ($main -eq [IntPtr]::Zero) { throw 'the app did not open a main window' }

    $cold = (Wait-Cache $cachePrimary 30) -or (Wait-Cache $cacheFallback 30)
    Check 'cold start extracted 30 runtime files' $cold ('primary=' + $cachePrimary)

    $kids = New-Object System.Collections.ArrayList
    $cb = [Smoke+EnumProc]{
        param([IntPtr]$h, [IntPtr]$l)
        [void]$kids.Add($h)
        return $true
    }
    [void][Smoke]::EnumChildWindows($main, $cb, [IntPtr]::Zero)

    $items = @()
    $seen = @{}
    foreach ($h in $kids) {
        $key = $h.ToString()
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        $r = New-Object Smoke+RECT
        [void][Smoke]::GetWindowRect($h, [ref]$r)
        $items += [pscustomobject]@{
            H = $h
            Cls = (Get-Class $h)
            Text = (Get-Text $h)
            Left = $r.L
        }
    }

    $edits = @($items | Where-Object { $_.Cls -match 'EDIT' } | Sort-Object Left)
    if ($edits.Count -ne 2) { throw ('expected 2 text panes, found ' + $edits.Count) }
    $inputBox = $edits[0].H
    $outputBox = $edits[1].H

    $dirH = Find-Control $items $DIRECTION
    $regionH = Find-Control $items $REGION
    $chkH = Find-Control $items $PHRASES
    $copyH = Find-Control $items $COPY
    $clearH = Find-Control $items $CLEAR
    Check 'direction control' ($dirH -ne [IntPtr]::Zero) 'not found'
    Check 'region control' ($regionH -ne [IntPtr]::Zero) 'not found'
    Check 'phrases checkbox' ($chkH -ne [IntPtr]::Zero) 'not found'
    Check 'copy button' ($copyH -ne [IntPtr]::Zero) 'not found'
    Check 'clear button' ($clearH -ne [IntPtr]::Zero) 'not found'
    if ($dirH -eq [IntPtr]::Zero -or $regionH -eq [IntPtr]::Zero -or
        $chkH -eq [IntPtr]::Zero -or $copyH -eq [IntPtr]::Zero -or $clearH -eq [IntPtr]::Zero) {
        throw 'required controls are missing'
    }

    function Set-Input([string]$text) {
        [void][Smoke]::SendText($inputBox, 0x000C, [IntPtr]::Zero, $text)
    }
    function Trigger-Direction {
        Send-Key $dirH 0x27
        Send-Key $dirH 0x25
    }

    Set-Input $S1
    Trigger-Direction
    Check 'default Taiwan + phrases' (Wait-Text $outputBox $E_TW_PHRASES) ('got=' + (Get-Text $outputBox))

    Send-Key $regionH 0x25
    Check 'standard region' (Wait-Text $outputBox $E_STANDARD) ('got=' + (Get-Text $outputBox))

    Send-Key $regionH 0x27
    Send-Key $regionH 0x27
    Check 'Hong Kong region' (Wait-Text $outputBox $E_STANDARD) ('got=' + (Get-Text $outputBox))

    Set-Input $S2
    Send-Key $regionH 0x25
    Send-Key $regionH 0x27
    Check 'Hong Kong phrases' (Wait-Text $outputBox $E_HK_PHRASES) ('got=' + (Get-Text $outputBox))

    Send-Key $regionH 0x25
    Check 'Taiwan phrases' (Wait-Text $outputBox $E_TW_PHRASES2) ('got=' + (Get-Text $outputBox))

    Send-Key $chkH 0x20
    Check 'Taiwan without phrases' (Wait-Text $outputBox $E_TW_PLAIN) ('got=' + (Get-Text $outputBox))

    Send-Key $chkH 0x20
    Set-Input $S3
    Send-Key $dirH 0x27
    Check 'Taiwan phrases to simplified' (Wait-Text $outputBox $E_REVERSE) ('got=' + (Get-Text $outputBox))

    if (-not $SkipInteractive) {
        $fgOk = Force-Foreground $main
        Check 'app brought to foreground for copy/clear' $fgOk 'SetForegroundWindow failed'
        try {
            Set-Clipboard -Value 'SMOKE-SENTINEL'
            Click-Real $copyH
            $deadline = (Get-Date).AddSeconds(3)
            $clip = ''
            do {
                Start-Sleep -Milliseconds 120
                $clip = [string](Get-Clipboard -Raw)
            } while ($clip -ne $E_REVERSE -and (Get-Date) -lt $deadline)
            Check 'copy puts the result on the clipboard' ($clip -eq $E_REVERSE) ('got=' + $clip)
        } catch {
            Check 'copy puts the result on the clipboard' $false $_.Exception.Message
        }

        Click-Real $clearH
        Start-Sleep -Milliseconds 300
        $inText = Get-Text $inputBox
        $outText = Get-Text $outputBox
        Check 'clear empties both panes' (($inText.Length -eq 0) -and ($outText.Length -eq 0)) ('in=' + $inText.Length + ' out=' + $outText.Length)
    }
} finally {
    if ($main -ne [IntPtr]::Zero) {
        [void][Smoke]::SendInt($main, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 500
    }
    if ($proc -ne $null) {
        $proc.Refresh()
        if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
    }
    [void][Smoke]::SetCursorPos($oldCursor.X, $oldCursor.Y)
    if ($oldForeground -ne [IntPtr]::Zero) { [void][Smoke]::SetForegroundWindow($oldForeground) }
}

Write-Host ''
if ($script:fail -eq 0) {
    Write-Host 'SMOKE OK'
} else {
    Write-Host ('SMOKE FAILED: ' + $script:fail + ' check(s)')
}
exit $script:fail
