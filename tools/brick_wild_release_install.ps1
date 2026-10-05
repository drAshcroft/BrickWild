[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$TargetProject,

    [switch]$DryRun
)

# Installs ONE frozen BrickWild release into another Godot project.
#
# release_brick_wild.ps1 copies this file into every release folder as
# install.ps1, beside the addons/brick_wild tree it installs. It needs nothing
# from the BrickWild repository, so a consumer pinned to a release keeps working
# whatever the repository renames or deletes later.
#
# Every managed file is hash-checked. A file the previous install managed and
# this release no longer ships is removed; anything else in the addon directory
# is the consumer's and is left alone.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$manifestName = '.brick_wild_install_manifest.json'
$sourceAddon = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'addons/brick_wild'))
$sourceManifestPath = Join-Path $sourceAddon $manifestName
if (-not (Test-Path -LiteralPath $sourceManifestPath -PathType Leaf)) {
    throw "Release manifest not found beside this installer: $sourceManifestPath"
}

$targetRoot = [IO.Path]::GetFullPath($TargetProject)
if (-not (Test-Path -LiteralPath (Join-Path $targetRoot 'project.godot') -PathType Leaf)) {
    throw "TargetProject is not a Godot project (project.godot not found): $targetRoot"
}
$addonRoot = [IO.Path]::GetFullPath((Join-Path $targetRoot 'addons/brick_wild'))

function Resolve-Inside {
    param([string]$Root, [string]$RelativePath)
    foreach ($segment in $RelativePath.Replace('\', '/').Split('/')) {
        if ([string]::IsNullOrEmpty($segment) -or $segment -eq '.' -or $segment -eq '..') {
            throw "Invalid managed path: $RelativePath"
        }
    }
    $full = [IO.Path]::GetFullPath((Join-Path $Root $RelativePath))
    if (-not $full.StartsWith($Root + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "Managed path escapes its root: $RelativePath"
    }
    return $full
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

$sourceManifestText = [IO.File]::ReadAllText($sourceManifestPath)
$sourceManifest = $sourceManifestText | ConvertFrom-Json
$version = [string]$sourceManifest.package_version
$newPaths = @{}
foreach ($record in @($sourceManifest.files)) {
    $newPaths[[string]$record.path] = [string]$record.sha256
}

$previousVersion = ''
$oldPaths = @()
$installedManifestPath = Join-Path $addonRoot $manifestName
if (Test-Path -LiteralPath $installedManifestPath -PathType Leaf) {
    try {
        $old = [IO.File]::ReadAllText($installedManifestPath) | ConvertFrom-Json
        $previousVersion = [string]$old.package_version
        $oldPaths = @($old.files | ForEach-Object { [string]$_.path })
    }
    catch {
        throw "Installed BrickWild manifest is invalid; refusing to remove any files: $installedManifestPath"
    }
}

$removed = 0
foreach ($relative in $oldPaths) {
    if ($newPaths.ContainsKey($relative)) { continue }
    $path = Resolve-Inside -Root $addonRoot -RelativePath $relative
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        if (-not $DryRun) { Remove-Item -LiteralPath $path -Force }
        $removed++
    }
}

$copied = 0
$updated = 0
$unchanged = 0
foreach ($relative in ($newPaths.Keys | Sort-Object)) {
    $expected = $newPaths[$relative]
    $source = Resolve-Inside -Root $sourceAddon -RelativePath $relative
    if ((Get-Sha256 -Path $source) -ne $expected) {
        throw "Release file does not match its manifest (the release folder was modified): $relative"
    }
    $destination = Resolve-Inside -Root $addonRoot -RelativePath $relative
    $exists = Test-Path -LiteralPath $destination -PathType Leaf
    if ($exists -and (Get-Sha256 -Path $destination) -eq $expected) {
        $unchanged++
        continue
    }
    if (-not $DryRun) {
        [IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
        [IO.File]::Copy($source, $destination, $true)
        # Release files are read-only; the installed copy belongs to the consumer.
        [IO.File]::SetAttributes($destination, [IO.FileAttributes]::Normal)
        if ((Get-Sha256 -Path $destination) -ne $expected) {
            throw "Copied file failed hash verification: $relative"
        }
    }
    if ($exists) { $updated++ } else { $copied++ }
}

if (-not $DryRun) {
    [IO.Directory]::CreateDirectory($addonRoot) | Out-Null
    $current = if (Test-Path -LiteralPath $installedManifestPath -PathType Leaf) {
        [IO.File]::ReadAllText($installedManifestPath)
    } else { '' }
    if ($current -cne $sourceManifestText) {
        if (Test-Path -LiteralPath $installedManifestPath -PathType Leaf) {
            [IO.File]::SetAttributes($installedManifestPath, [IO.FileAttributes]::Normal)
        }
        [IO.File]::WriteAllText($installedManifestPath, $sourceManifestText,
            (New-Object Text.UTF8Encoding($false)))
    }
}

[pscustomobject]@{
    PackageVersion = $version
    PreviousVersion = $previousVersion
    AddonRoot = $addonRoot
    ManagedFiles = $newPaths.Count
    Copied = $copied
    Updated = $updated
    Removed = $removed
    Unchanged = $unchanged
    DryRun = [bool]$DryRun
}
