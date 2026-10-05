[CmdletBinding()]
param(
    # The commit to release. Never the working tree: other agents edit that.
    [string]$Ref = 'HEAD',

    # Where releases live. Git-ignored, and carries a .gdignore so this
    # project's own Godot never imports the frozen copies of its classes.
    [string]$OutputRoot = '',

    [string]$GodotPath = 'C:\Projects\godot\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64.exe',

    # Freeze and write the release without the Godot smoke. For debugging the
    # tool only; such a release is marked unverified in release.json.
    [switch]$SkipGodot
)

# Freezes one BrickWild addon release:
#
#   releases/
#     .gdignore
#     LATEST                      -> brick_wild-0.1.0
#     current/                    junction to the newest VERIFIED release
#     brick_wild-0.1.0/           never rewritten once written
#       addons/brick_wild/        for projects that EMBED BrickWild (read-only)
#       install.ps1               standalone; needs nothing from this repo
#       brick_wild-0.1.0.zip      the addon tree, Asset Library layout
#       project/                  for tools that RUN it: godot --path <this>
#       release.json              commit, version, verification
#
# Steps: check out $Ref in a temporary git worktree, copy in the licensed prop
# packs git does not track, install the addon from that worktree into a staging
# project, freeze it, then install the FROZEN copy into a fresh project with
# the release's own install.ps1 and run tools/brick_wild_addon_smoke.gd there.
# The frozen project/ is the same commit as a whole Godot project, imported and
# smoked the same way, for consumers that call `godot --path ... --script`.
# Only a release that passed is moved into place. A version is written once:
# releasing a different commit under the same VERSION is refused.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $repositoryRoot 'releases'
}
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
$utf8NoBom = New-Object Text.UTF8Encoding($false)

function Invoke-Git {
    param([string[]]$Arguments)
    $output = & git -C $repositoryRoot @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed:`n$output"
    }
    return $output
}

function Invoke-Godot {
    param([string[]]$Arguments, [string]$LogPath)

    $startInfo = New-Object Diagnostics.ProcessStartInfo
    # The console shim spawns the real engine; start the engine itself so the
    # timeout owns the actual child.
    $startInfo.FileName = $GodotPath -replace '_console\.exe$', '.exe'
    $startInfo.Arguments = @($Arguments | ForEach-Object {
        '"' + $_.Replace('"', '\"') + '"'
    }) -join ' '
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw 'Godot process did not start' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(1800000)) {
        $process.Kill()
        $process.WaitForExit()
        throw "Godot timed out after 30 minutes; see $LogPath"
    }
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    [IO.File]::AppendAllText($LogPath,
        "### godot $($Arguments -join ' ')`n--- stdout`n$stdout`n--- stderr`n$stderr`n", $utf8NoBom)
    if ($process.ExitCode -ne 0 -or $stderr -match 'SCRIPT ERROR:|ERROR:') {
        throw "Godot failed with exit code $($process.ExitCode); see $LogPath"
    }
    return $stdout
}

function New-GodotProject {
    param([string]$Path, [string]$Name)
    [IO.Directory]::CreateDirectory($Path) | Out-Null
    [IO.File]::WriteAllText((Join-Path $Path 'project.godot'),
        "config_version=5`n`n[application]`nconfig/name=`"$Name`"`n", $utf8NoBom)
}

# --- what is being released -------------------------------------------------

$commit = ([string](Invoke-Git @('rev-parse', '--verify', "$Ref^{commit}"))).Trim()
$shortCommit = $commit.Substring(0, 10)
$commitDate = ([string](Invoke-Git @('show', '-s', '--format=%cI', $commit))).Trim()
$version = ([string](Invoke-Git @('show', "${commit}:packaging/brick_wild/VERSION"))).Trim()
$pluginCfg = (Invoke-Git @('show', "${commit}:packaging/brick_wild/plugin.cfg")) -join "`n"
if ($pluginCfg -notmatch "(?m)^version=`"$([regex]::Escape($version))`"") {
    throw "packaging/brick_wild/plugin.cfg version does not match VERSION $version at $shortCommit"
}
if ($version -notmatch '^\d+\.\d+\.\d+([-+][0-9A-Za-z.-]+)?$') {
    throw "VERSION is not a semantic version: '$version'"
}
$releaseId = "brick_wild-$version"
$releaseDir = Join-Path $OutputRoot $releaseId

if (Test-Path -LiteralPath $releaseDir) {
    $existing = [IO.File]::ReadAllText((Join-Path $releaseDir 'release.json')) | ConvertFrom-Json
    if ([string]$existing.commit -eq $commit) {
        Write-Output "$releaseId is already released from $shortCommit; nothing to do."
        return
    }
    throw ("$releaseId already exists, built from $($existing.commit.Substring(0, 10)). " +
        "A release is never rewritten: bump packaging/brick_wild/VERSION, plugin.cfg and " +
        "the manifest's package_version, commit, and release again.")
}

[IO.Directory]::CreateDirectory($OutputRoot) | Out-Null
$gdignore = Join-Path $OutputRoot '.gdignore'
if (-not (Test-Path -LiteralPath $gdignore)) {
    [IO.File]::WriteAllText($gdignore, '', $utf8NoBom)
}

$dirty = @(Invoke-Git @('status', '--porcelain', '--untracked-files=no'))
if ($dirty.Count -gt 0) {
    Write-Output ("Note: the working tree has $($dirty.Count) uncommitted change(s). " +
        "They are NOT in this release; it is built from $shortCommit.")
}
Write-Output "Releasing $releaseId from $shortCommit ($commitDate)"

# --- build in a throwaway worktree ------------------------------------------

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$workPrefix = Join-Path $tempBase 'BrickWildRelease_'
$work = $workPrefix + [Guid]::NewGuid().ToString('N').Substring(0, 12)
$worktree = Join-Path $work 'source'
$stage = Join-Path $work 'stage'
$frozen = Join-Path $work $releaseId
$verify = Join-Path $work 'verify'
$logPath = Join-Path $OutputRoot "$releaseId.build.log"
[IO.Directory]::CreateDirectory($work) | Out-Null
[IO.File]::WriteAllText($logPath, "release $releaseId from $commit`n", $utf8NoBom)
$worktreeAdded = $false

try {
    $null = Invoke-Git @('worktree', 'add', '--detach', $worktree, $commit)
    $worktreeAdded = $true

    # The licensed prop packs are git-ignored; a fresh worktree has only the
    # tracked pack. Copy exactly the ignored files the manifest's trees need.
    $manifest = [IO.File]::ReadAllText((Join-Path $worktree 'tools/brick_wild_addon_manifest.json')) |
        ConvertFrom-Json
    $localPackFiles = 0
    foreach ($tree in @($manifest.trees)) {
        $treeSource = [string]$tree.source
        foreach ($relative in @(Invoke-Git @('ls-files', '--others', '--ignored',
                '--exclude-standard', '--', $treeSource))) {
            $relative = [string]$relative
            if ([string]::IsNullOrWhiteSpace($relative) -or $relative.EndsWith('.import')) { continue }
            $destination = Join-Path $worktree $relative
            [IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
            Copy-Item -LiteralPath (Join-Path $repositoryRoot $relative) -Destination $destination
            $localPackFiles++
        }
    }
    Write-Output "Copied $localPackFiles untracked prop-pack file(s) from the local checkout"

    New-GodotProject -Path $stage -Name 'BrickWild release stage'
    $install = & (Join-Path $worktree 'tools/install_brick_wild_addon.ps1') -TargetProject $stage
    Write-Output "Staged $($install.ManagedFiles) managed files"

    # Freeze.
    $frozenAddon = Join-Path $frozen 'addons/brick_wild'
    [IO.Directory]::CreateDirectory((Split-Path -Parent $frozenAddon)) | Out-Null
    Copy-Item -LiteralPath (Join-Path $stage 'addons/brick_wild') -Destination $frozenAddon -Recurse
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'brick_wild_release_install.ps1') `
        -Destination (Join-Path $frozen 'install.ps1')

    # The whole project at this commit, packs included, minus the worktree's
    # .git pointer: a frozen project is not a checkout.
    $frozenProject = Join-Path $frozen 'project'
    Copy-Item -LiteralPath $worktree -Destination $frozenProject -Recurse
    Remove-Item -LiteralPath (Join-Path $frozenProject '.git') -Force

    # Verify the frozen copy the way a consumer gets it.
    $verified = $false
    if (-not $SkipGodot) {
        if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
            throw "GodotPath does not exist: $GodotPath (or pass -SkipGodot)"
        }
        New-GodotProject -Path $verify -Name 'BrickWild release verify'
        $first = & (Join-Path $frozen 'install.ps1') -TargetProject $verify
        if ($first.Copied -ne $install.ManagedFiles) {
            throw "Release install copied $($first.Copied) of $($install.ManagedFiles) files"
        }
        $again = & (Join-Path $frozen 'install.ps1') -TargetProject $verify
        if ($again.Copied + $again.Updated + $again.Removed -ne 0) {
            throw 'Release install is not idempotent'
        }
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'brick_wild_addon_smoke.gd') `
            -Destination (Join-Path $verify 'smoke.gd')
        Write-Output 'Importing the release into a fresh project (several minutes)...'
        $null = Invoke-Godot -Arguments @('--headless', '--path', $verify, '--editor', '--quit') `
            -LogPath $logPath
        Write-Output 'Running the consumer smoke...'
        $smoke = Invoke-Godot -Arguments @('--headless', '--path', $verify, '--script', 'res://smoke.gd') `
            -LogPath $logPath
        if (-not $smoke.Contains('BRICKWILD_ADDON_SMOKE_OK')) {
            throw "Consumer smoke did not report completion; see $logPath"
        }
        Write-Output 'Importing the frozen project...'
        $null = Invoke-Godot -Arguments @('--headless', '--path', $frozenProject, '--editor', '--quit') `
            -LogPath $logPath
        Write-Output 'Running the smoke against the frozen project, from outside it...'
        $smoke = Invoke-Godot -Arguments @('--headless', '--path', $frozenProject, '--script',
            (Join-Path $verify 'smoke.gd')) -LogPath $logPath
        if (-not $smoke.Contains('BRICKWILD_ADDON_SMOKE_OK')) {
            throw "Project smoke did not report completion; see $logPath"
        }
        $verified = $true
    }

    Compress-Archive -Path (Join-Path $frozen 'addons') `
        -DestinationPath (Join-Path $frozen "$releaseId.zip") -CompressionLevel Optimal

    $files = @(Get-ChildItem -LiteralPath $frozenAddon -File -Recurse)
    $release = [ordered]@{
        id = $releaseId
        package_version = $version
        commit = $commit
        commit_date = $commitDate
        source_ref = $Ref
        built_at = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        godot = '4.5.2'
        addon_path = 'res://addons/brick_wild'
        managed_files = $install.ManagedFiles
        bytes = ($files | Measure-Object -Property Length -Sum).Sum
        untracked_pack_files_from_local_checkout = $localPackFiles
        verified = $verified
        verification = if ($verified) {
            ('release install.ps1 into a fresh project, editor import, tools/brick_wild_addon_smoke.gd; ' +
                'frozen project/ imported and smoked from outside --path')
        } else { 'NONE: built with -SkipGodot' }
    }
    [IO.File]::WriteAllText((Join-Path $frozen 'release.json'),
        ($release | ConvertTo-Json -Depth 4) + "`n", $utf8NoBom)

    # Publish: copy beside the target, then one rename, so a reader never sees
    # half a release.
    $incoming = Join-Path $OutputRoot ".incoming-$releaseId"
    if (Test-Path -LiteralPath $incoming) {
        Remove-Item -LiteralPath $incoming -Recurse -Force
    }
    Copy-Item -LiteralPath $frozen -Destination $incoming -Recurse
    # The addon is read-only. project/ is not: Godot writes its .godot cache
    # on every run, and a read-only cache fails the run.
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $incoming 'addons') -File -Recurse) +
            @(Get-ChildItem -LiteralPath $incoming -File)) {
        $file.IsReadOnly = $true
    }
    Rename-Item -LiteralPath $incoming -NewName $releaseId
    if ($verified) {
        [IO.File]::WriteAllText((Join-Path $OutputRoot 'LATEST'), "$releaseId`n", $utf8NoBom)
        # Repoint the junction. Directory.Delete without recursion removes the
        # link only; a recursive delete would empty the release behind it.
        $current = Join-Path $OutputRoot 'current'
        if (Test-Path -LiteralPath $current) {
            [IO.Directory]::Delete($current, $false)
        }
        $null = New-Item -ItemType Junction -Path $current -Target $releaseDir
    }
    Move-Item -LiteralPath $logPath -Destination (Join-Path $releaseDir 'build.log')
    (Get-Item -LiteralPath (Join-Path $releaseDir 'build.log')).IsReadOnly = $true

    [pscustomobject]$release
}
finally {
    if ($worktreeAdded) {
        & git -C $repositoryRoot worktree remove --force $worktree 2>&1 | Out-Null
    }
    $resolved = [IO.Path]::GetFullPath($work)
    if ($resolved.StartsWith($workPrefix, [StringComparison]::OrdinalIgnoreCase) -and
            (Test-Path -LiteralPath $resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
    }
}
