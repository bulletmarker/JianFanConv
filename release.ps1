# JianFanConverter release script (PowerShell 5.1, ASCII only)
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File release.ps1 -Version 1.0.2
#   powershell -ExecutionPolicy Bypass -File release.ps1 -Version 1.0.1 -SkipBuild -SkipZip -SkipGitPush -SkipGitHub
#
# What it does, in order:
#   1. build.ps1              -> dist\JianFanConverter.exe (single file)
#   2. Compress-Archive       -> JianFanConverter-v<Version>-win-x64.zip
#   3. annotate + push tag    -> Gitee only (origin); GitHub catches up by itself
#   4. Gitee API              -> create the release + upload the zip attachment
#   5. GitHub                 -> trigger the mirror workflow, then gh release create
#
# Requirements:
#   - GITEE_TOKEN: Gitee personal access token with the "projects" scope.
#     Read from the process env first, then from User, then from Machine.
#   - release-notes-v<Version>.md in the repo root. Its first "## " heading
#     becomes the release title on both platforms.
#   - curl.exe (ships with Windows 10 1803+) for the multipart attachment upload.
#   - gh (optional) for the GitHub release; skipped with a warning if missing.
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [switch]$SkipBuild,
    [switch]$SkipZip,
    [switch]$SkipGitPush,
    [switch]$SkipGitee,
    [switch]$SkipGitHub
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $root

if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Version must look like 1.2.3 (got '$Version')" }
$tag       = 'v' + $Version
$zipName   = 'JianFanConverter-v' + $Version + '-win-x64.zip'
$zipPath   = Join-Path $root $zipName
$notesPath = Join-Path $root ('release-notes-v' + $Version + '.md')
$exePath   = Join-Path $root 'dist\JianFanConverter.exe'

function Step([string]$text) { Write-Host ''; Write-Host ('== ' + $text) }
function Fail([string]$text) { throw $text }

function Get-GiteeToken {
    if ($env:GITEE_TOKEN) { return $env:GITEE_TOKEN }
    $fromUser = [Environment]::GetEnvironmentVariable('GITEE_TOKEN', 'User')
    if ($fromUser) { return $fromUser }
    $fromMachine = [Environment]::GetEnvironmentVariable('GITEE_TOKEN', 'Machine')
    if ($fromMachine) { return $fromMachine }
    return $null
}

function Get-RemoteOwnerRepo([string]$remote) {
    $url = (& git remote get-url $remote 2>$null)
    if (-not $url) { return $null }
    $url = $url.Trim()
    if ($url -match '[:/](?<owner>[^/:]+)/(?<repo>[^/:]+?)(\.git)?$') {
        return @{ Owner = $Matches['owner']; Repo = $Matches['repo'] }
    }
    return $null
}

# --- pre-flight -----------------------------------------------------------
Step 'pre-flight'
$dirty = (& git status --porcelain)
if ($dirty) { Fail "worktree is not clean; commit or stash first:`n$dirty" }
$head = (& git rev-parse HEAD).Trim()
Write-Host ('commit: ' + $head)
if (-not (Test-Path -LiteralPath $notesPath)) {
    Fail ('missing release notes: ' + $notesPath + ' (first "## " line becomes the title)')
}
$notes = [System.IO.File]::ReadAllText($notesPath, [System.Text.Encoding]::UTF8)
$heading = ($notes -split "`r?`n" | Where-Object { $_ -match '^##\s+' } | Select-Object -First 1)
if ($heading) { $title = ($heading -replace '^##\s+', '').Trim() } else { $title = $tag }
Write-Host ('title: ' + $title)

$token = $null
if (-not $SkipGitee) {
    $token = Get-GiteeToken
    if (-not $token) { Fail 'GITEE_TOKEN is not set (process env, User or Machine)' }
    $me = Invoke-RestMethod -Uri ('https://gitee.com/api/v5/user?access_token=' + $token) -TimeoutSec 30
    Write-Host ('gitee user: ' + $me.login)
}

# --- 1. build -------------------------------------------------------------
if ($SkipBuild) {
    Step 'build: skipped'
} else {
    Step 'build'
    & powershell -ExecutionPolicy Bypass -File (Join-Path $root 'build.ps1') -Version $Version
    if ($LASTEXITCODE -ne 0) { Fail "build.ps1 failed with exit code $LASTEXITCODE" }
    $builtVersion = (Get-Item -LiteralPath $exePath).VersionInfo.FileVersion
    Write-Host ('exe version: ' + $builtVersion)
    if ($builtVersion -ne ($Version + '.0')) {
        Fail ('exe reports version ' + $builtVersion + ', expected ' + $Version + '.0')
    }
}
if (-not (Test-Path -LiteralPath $exePath)) { Fail ('missing ' + $exePath) }
$distFiles = @(Get-ChildItem -LiteralPath (Join-Path $root 'dist') -File)
if ($distFiles.Count -ne 1) { Fail ('dist must contain exactly 1 file, found ' + $distFiles.Count) }

# --- 2. package -----------------------------------------------------------
if ($SkipZip) {
    Step 'package: skipped'
    if (-not (Test-Path -LiteralPath $zipPath)) { Fail ('missing existing zip: ' + $zipPath) }
} else {
    Step 'package'
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

    # Apache-2.0 section 4 and the MIT terms both require the license text to travel
    # with the binary, so the archive ships two extra files beside the exe. dist\ is
    # left alone: it stays a plain build output with a single file.
    $stage = Join-Path ([System.IO.Path]::GetTempPath()) ('jfconv-release-' + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    try {
        Copy-Item -LiteralPath $exePath -Destination (Join-Path $stage 'JianFanConverter.exe')
        Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination (Join-Path $stage 'LICENSE.txt')

        $apache = [System.IO.File]::ReadAllText((Join-Path $root 'vendor\opencc\LICENSE'), [System.Text.Encoding]::UTF8)
        $notice = [System.IO.File]::ReadAllText((Join-Path $root 'vendor\opencc\NOTICE.txt'), [System.Text.Encoding]::UTF8)
        $header = @'
JianFanConverter - third-party notices
======================================

This application embeds the OpenCC engine and its dictionaries at compile time
and extracts them to a per-user cache directory at runtime. Those components
are distributed under the Apache License 2.0. The upstream NOTICE and the full
license text follow below.

'@
        $divider = ('-' * 78) + "`r`n"
        $thirdParty = $header +
            $divider + 'NOTICE (from vendor/opencc/NOTICE.txt)' + "`r`n" + $divider + $notice + "`r`n" +
            $divider + 'Apache License 2.0 (from vendor/opencc/LICENSE)' + "`r`n" + $divider + $apache
        [System.IO.File]::WriteAllText((Join-Path $stage 'THIRD-PARTY-NOTICES.txt'), $thirdParty,
            (New-Object System.Text.UTF8Encoding($false)))

        Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zipPath -CompressionLevel Optimal
    } finally {
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $names = @($archive.Entries | ForEach-Object { $_.FullName })
        foreach ($required in @('JianFanConverter.exe', 'LICENSE.txt', 'THIRD-PARTY-NOTICES.txt')) {
            if ($names -notcontains $required) { Fail ('zip is missing ' + $required) }
        }
        if ($names.Count -ne 3) {
            Fail ('zip must contain exactly 3 entries, found ' + $names.Count + ': ' + ($names -join ', '))
        }
    } finally {
        $archive.Dispose()
    }
}

$exeHash = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash
$zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
$zipKb = [math]::Round((Get-Item -LiteralPath $zipPath).Length / 1KB, 1)
Write-Host ('exe: ' + $exeHash)
Write-Host ('zip: ' + $zipName + '  ' + $zipKb + ' KB')
Write-Host ('zip sha256: ' + $zipHash)

# --- 3. tag + push to Gitee only -----------------------------------------
if ($SkipGitPush) {
    Step 'git: skipped'
} else {
    Step 'git: tag + push (Gitee)'
    $existing = (& git tag -l $tag)
    if ($existing) {
        Write-Host ('tag exists: ' + $tag)
    } else {
        & git tag -a $tag -m ('JianFanConverter ' + $tag)
        if ($LASTEXITCODE -ne 0) { Fail 'git tag failed' }
    }
    & git push origin master
    if ($LASTEXITCODE -ne 0) { Fail 'git push master failed' }
    & git push origin ('refs/tags/' + $tag)
    if ($LASTEXITCODE -ne 0) { Fail 'git push tag failed' }
}

# --- 4. Gitee release -----------------------------------------------------
if ($SkipGitee) {
    Step 'gitee: skipped'
} else {
    Step 'gitee: release'
    $originInfo = Get-RemoteOwnerRepo 'origin'
    if (-not $originInfo) { Fail 'cannot parse owner/repo from origin remote' }
    $api = 'https://gitee.com/api/v5/repos/' + $originInfo.Owner + '/' + $originInfo.Repo

    $tagCommit = (& git rev-list -n 1 $tag 2>$null)
    if (-not $tagCommit) { $tagCommit = $head }
    $tagCommit = $tagCommit.Trim()

    # Gitee answers HTTP 200 with a body of "null" for a tag that has no release
    # yet, so existence must be judged by the id, not by the HTTP status.
    $release = Invoke-RestMethod -Uri ($api + '/releases/tags/' + $tag) -TimeoutSec 30
    if ($release -and $release.id) {
        Write-Host ('release exists: id=' + $release.id)
    } else {
        # The create endpoint only accepts form data; a JSON body answers 405.
        # curl.exe is used because PowerShell 5.1 mangles UTF-8 in form bodies.
        $titleFile = Join-Path ([System.IO.Path]::GetTempPath()) ('jfconv-title-' + $Version + '.txt')
        [System.IO.File]::WriteAllText($titleFile, $title, (New-Object System.Text.UTF8Encoding($false)))
        try {
            $raw = & curl.exe -s -X POST `
                --data-urlencode ('access_token=' + $token) `
                --data-urlencode ('tag_name=' + $tag) `
                --data-urlencode ('name@' + $titleFile) `
                --data-urlencode ('body@' + $notesPath) `
                --data-urlencode ('target_commitish=' + $tagCommit) `
                --data-urlencode 'prerelease=false' `
                ($api + '/releases')
            if ($LASTEXITCODE -ne 0) { Fail "curl failed to create the release (exit $LASTEXITCODE)" }
        } finally {
            if (Test-Path -LiteralPath $titleFile) { Remove-Item -LiteralPath $titleFile -Force }
        }
        $release = ($raw -join "`n") | ConvertFrom-Json
        if (-not $release.id) { Fail ('release creation failed: ' + ($raw -join ' ')) }
        Write-Host ('created: id=' + $release.id)
    }

    $attached = @(Invoke-RestMethod -Uri ($api + '/releases/' + $release.id + '/attach_files?access_token=' + $token) -TimeoutSec 30)
    $alreadyAttached = $false
    foreach ($asset in $attached) {
        if ($asset.name -eq $zipName) { $alreadyAttached = $true }
    }
    if ($alreadyAttached) {
        Write-Host ('attachment already present: ' + $zipName)
    } else {
        $uploadUri = $api + '/releases/' + $release.id + '/attach_files'
        & curl.exe -s -S -X POST -F ('access_token=' + $token) -F ('file=@' + $zipPath) $uploadUri
        if ($LASTEXITCODE -ne 0) { Fail "curl upload failed with exit code $LASTEXITCODE" }
        Write-Host ''
        $check = Invoke-RestMethod -Uri ($api + '/releases/' + $release.id + '/attach_files') -TimeoutSec 30
        $found = $false
        foreach ($asset in $check) {
            if ($asset.name -eq $zipName) { $found = $true }
        }
        if (-not $found) { Fail 'attachment upload could not be confirmed' }
        Write-Host ('attachment uploaded: ' + $zipName)
    }
    Write-Host ('gitee release: https://gitee.com/' + $originInfo.Owner + '/' + $originInfo.Repo +
        '/releases/tag/' + $tag)
}

# --- 5. GitHub ------------------------------------------------------------
if ($SkipGitHub) {
    Step 'github: skipped'
} else {
    Step 'github: mirror + release'
    $ghInfo = Get-RemoteOwnerRepo 'github'
    if (-not $ghInfo) {
        Write-Host 'WARNING: no github remote, skipping GitHub release'
    } else {
        $slug = $ghInfo.Owner + '/' + $ghInfo.Repo
        & gh workflow run sync-from-gitee.yml --repo $slug
        if ($LASTEXITCODE -ne 0) { Fail 'gh workflow run failed' }

        Start-Sleep -Seconds 8
        $runId = $null
        for ($i = 0; $i -lt 30; $i++) {
            $runs = (& gh run list --repo $slug --workflow=sync-from-gitee.yml --limit 1 --json databaseId,status,conclusion | ConvertFrom-Json)
            if ($runs -and $runs.Count -gt 0) {
                $runId = $runs[0].databaseId
                $view = (& gh run view $runId --repo $slug --json status,conclusion | ConvertFrom-Json)
                if ($view.status -eq 'completed') {
                    Write-Host ('mirror run ' + $runId + ': ' + $view.conclusion)
                    if ($view.conclusion -ne 'success') { Fail 'mirror workflow did not succeed' }
                    break
                }
            }
            Start-Sleep -Seconds 10
        }
        if (-not $runId) { Fail 'could not observe the mirror workflow run' }

        $remoteTag = (& git ls-remote github ('refs/tags/' + $tag))
        if (-not $remoteTag) { Fail ('tag not present on GitHub after mirroring: ' + $tag) }

        # gh writes "release not found" to stderr for a missing tag; with
        # ErrorActionPreference=Stop that would abort the run, so relax it for this
        # probe and judge by the exit code only.
        $hasRelease = $false
        $previousEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & gh release view $tag --repo $slug 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { $hasRelease = $true }
        } finally {
            $ErrorActionPreference = $previousEap
        }

        if ($hasRelease) {
            Write-Host ('github release already exists: ' + $tag)
        } else {
            & gh release create $tag $zipPath --repo $slug --title $title --notes-file $notesPath
            if ($LASTEXITCODE -ne 0) { Fail 'gh release create failed' }
        }
        Write-Host ('github release: https://github.com/' + $slug + '/releases/tag/' + $tag)
    }
}

# --- summary --------------------------------------------------------------
Step 'done'
Write-Host ('version : ' + $tag)
Write-Host ('commit  : ' + $head)
Write-Host ('exe     : ' + $exeHash)
Write-Host ('zip     : ' + $zipHash + '  (' + $zipKb + ' KB)')
