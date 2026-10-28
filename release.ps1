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
    & powershell -ExecutionPolicy Bypass -File (Join-Path $root 'build.ps1')
    if ($LASTEXITCODE -ne 0) { Fail "build.ps1 failed with exit code $LASTEXITCODE" }
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
    Compress-Archive -Path (Join-Path $root 'dist\*') -DestinationPath $zipPath -CompressionLevel Optimal
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        if ($archive.Entries.Count -ne 1) { Fail ('zip must contain exactly 1 entry, found ' + $archive.Entries.Count) }
        if ($archive.Entries[0].FullName -ne 'JianFanConverter.exe') {
            Fail ('zip root entry mismatch: ' + $archive.Entries[0].FullName)
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

    $release = $null
    try {
        $release = Invoke-RestMethod -Uri ($api + '/releases/tags/' + $tag) -TimeoutSec 30
        Write-Host ('release exists: id=' + $release.id)
    } catch {
        Write-Host 'release does not exist yet, creating it'
    }

    if (-not $release) {
        $payload = @{
            access_token     = $token
            tag_name         = $tag
            name             = $title
            body             = $notes
            target_commitish = $head
            prerelease       = $false
        } | ConvertTo-Json
        # PS 5.1 encodes string bodies as ASCII; send UTF-8 bytes so Chinese survives.
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $release = Invoke-RestMethod -Method Post -Uri ($api + '/releases') `
            -ContentType 'application/json; charset=utf-8' -Body $bytes -TimeoutSec 60
        Write-Host ('created: id=' + $release.id)
    }

    $alreadyAttached = $false
    foreach ($asset in $release.assets) {
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

        $hasRelease = $false
        & gh release view $tag --repo $slug *> $null
        if ($LASTEXITCODE -eq 0) { $hasRelease = $true }

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
