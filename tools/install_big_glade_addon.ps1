[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$TargetProject,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceManifestPath = Join-Path $PSScriptRoot 'big_glade_addon_manifest.json'
$installedManifestName = '.big_glade_install_manifest.json'
$utf8NoBom = New-Object Text.UTF8Encoding($false)

function Assert-RelativePackagePath {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath) -or
            [IO.Path]::IsPathRooted($RelativePath)) {
        throw "$Description must be a non-empty relative path: $RelativePath"
    }

    # Reject dot segments instead of merely resolving them. This keeps the
    # manifest's destination identity canonical, so aliases such as
    # `api/../api/foo.gd` cannot bypass duplicate or managed-file checks.
    foreach ($segment in $RelativePath.Replace('\', '/').Split('/')) {
        if ([string]::IsNullOrEmpty($segment) -or $segment -eq '.' -or
                $segment -eq '..') {
            throw "$Description contains an invalid path segment: $RelativePath"
        }
    }
}

function Resolve-ContainedPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Description
    )

    Assert-RelativePackagePath -RelativePath $RelativePath -Description $Description

    $normalized = $RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar)
    $full = [IO.Path]::GetFullPath((Join-Path $Root $normalized))
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar)
    $prefix = $rootFull + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Description escapes its root: $RelativePath"
    }
    return $full
}

function Get-FileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Add-PackageFile {
    param(
        [Parameter(Mandatory = $true)]$Entries,
        [Parameter(Mandatory = $true)]$Destinations,
        [Parameter(Mandatory = $true)][string]$SourceRelative,
        [Parameter(Mandatory = $true)][string]$DestinationRelative
    )

    if ($SourceRelative.EndsWith('.import', [StringComparison]::OrdinalIgnoreCase) -or
            $DestinationRelative.EndsWith('.import', [StringComparison]::OrdinalIgnoreCase) -or
            $SourceRelative -match '(^|/|\\)\.godot($|/|\\)' -or
            $DestinationRelative -match '(^|/|\\)\.godot($|/|\\)') {
        throw "Generated Godot import data cannot be packaged: $SourceRelative -> $DestinationRelative"
    }

    $source = Resolve-ContainedPath -Root $repositoryRoot -RelativePath $SourceRelative `
        -Description 'Package source'
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required package source is missing: $SourceRelative"
    }

    $destinationKey = $DestinationRelative.Replace('\', '/')
    if ($Destinations.ContainsKey($destinationKey)) {
        throw "Duplicate addon destination in manifest: $destinationKey"
    }
    $Destinations[$destinationKey] = $true
    $Entries.Add([pscustomobject]@{
        Source = $source
        SourceRelative = $SourceRelative.Replace('\', '/')
        Destination = $destinationKey
        Sha256 = Get-FileSha256 -Path $source
    }) | Out-Null
}

if (-not (Test-Path -LiteralPath $sourceManifestPath -PathType Leaf)) {
    throw "Addon source manifest not found: $sourceManifestPath"
}

$targetRoot = [IO.Path]::GetFullPath($TargetProject)
if (-not (Test-Path -LiteralPath (Join-Path $targetRoot 'project.godot') -PathType Leaf)) {
    throw "TargetProject is not a Godot project (project.godot not found): $targetRoot"
}

$addonRoot = [IO.Path]::GetFullPath((Join-Path $targetRoot 'addons/big_glade'))
$expectedAddonParent = [IO.Path]::GetFullPath((Join-Path $targetRoot 'addons'))
$null = Resolve-ContainedPath -Root $expectedAddonParent -RelativePath 'big_glade' `
    -Description 'Addon destination'

$sourceManifest = [IO.File]::ReadAllText($sourceManifestPath) | ConvertFrom-Json
if ([int]$sourceManifest.schema_version -ne 1) {
    throw "Unsupported addon source manifest schema: $($sourceManifest.schema_version)"
}

$versionPath = Join-Path $repositoryRoot 'packaging/big_glade/VERSION'
$version = [IO.File]::ReadAllText($versionPath).Trim()
if ($version -ne [string]$sourceManifest.package_version) {
    throw "Package version mismatch between VERSION and source manifest"
}

$entries = New-Object 'Collections.Generic.List[object]'
$destinations = @{}

foreach ($item in @($sourceManifest.metadata) + @($sourceManifest.files)) {
    Add-PackageFile -Entries $entries -Destinations $destinations `
        -SourceRelative ([string]$item.source) -DestinationRelative ([string]$item.destination)
}

foreach ($script in @($sourceManifest.scripts)) {
    $sourceRelative = [string]$script.source
    $destinationRelative = [string]$script.destination
    Add-PackageFile -Entries $entries -Destinations $destinations `
        -SourceRelative $sourceRelative -DestinationRelative $destinationRelative
    Add-PackageFile -Entries $entries -Destinations $destinations `
        -SourceRelative ($sourceRelative + '.uid') -DestinationRelative ($destinationRelative + '.uid')
}

foreach ($tree in @($sourceManifest.trees)) {
    $treeSourceRelative = [string]$tree.source
    $treeDestination = ([string]$tree.destination).TrimEnd('/', '\')
    $treeSource = Resolve-ContainedPath -Root $repositoryRoot -RelativePath $treeSourceRelative `
        -Description 'Package tree source'
    if (-not (Test-Path -LiteralPath $treeSource -PathType Container)) {
        throw "Required package tree is missing: $treeSourceRelative"
    }

    $suffixes = @($tree.exclude_suffixes)
    foreach ($file in Get-ChildItem -LiteralPath $treeSource -File -Recurse) {
        $excluded = $false
        foreach ($suffix in $suffixes) {
            if ($file.Name.EndsWith([string]$suffix, [StringComparison]::OrdinalIgnoreCase)) {
                $excluded = $true
                break
            }
        }
        if ($excluded) {
            continue
        }

        $relative = $file.FullName.Substring($treeSource.Length).TrimStart(
            [IO.Path]::DirectorySeparatorChar,
            [IO.Path]::AltDirectorySeparatorChar).Replace('\', '/')
        Add-PackageFile -Entries $entries -Destinations $destinations `
            -SourceRelative ($treeSourceRelative.TrimEnd('/', '\') + '/' + $relative) `
            -DestinationRelative ($treeDestination + '/' + $relative)
    }
}

$entries = @($entries | Sort-Object Destination)
$newDestinationSet = @{}
foreach ($entry in $entries) {
    $newDestinationSet[$entry.Destination] = $true
}

$installedManifestPath = Join-Path $addonRoot $installedManifestName
$oldManagedPaths = @()
if (Test-Path -LiteralPath $installedManifestPath -PathType Leaf) {
    try {
        $oldManifest = [IO.File]::ReadAllText($installedManifestPath) | ConvertFrom-Json
        foreach ($record in @($oldManifest.files)) {
            $oldManagedPaths += [string]$record.path
        }
    }
    catch {
        throw "Installed BigGlade manifest is invalid; refusing to remove any files: $installedManifestPath"
    }
}

$removed = 0
$wouldRemove = 0
foreach ($oldRelative in $oldManagedPaths) {
    if ($newDestinationSet.ContainsKey($oldRelative)) {
        continue
    }
    $oldPath = Resolve-ContainedPath -Root $addonRoot -RelativePath $oldRelative `
        -Description 'Previously managed addon file'
    if (Test-Path -LiteralPath $oldPath -PathType Container) {
        throw "Previously managed path is unexpectedly a directory: $oldRelative"
    }
    if (Test-Path -LiteralPath $oldPath -PathType Leaf) {
        if ($DryRun) {
            $wouldRemove++
        }
        else {
            Remove-Item -LiteralPath $oldPath -Force
            $removed++
        }
    }
}

$copied = 0
$updated = 0
$unchanged = 0
$wouldCopy = 0
$wouldUpdate = 0
foreach ($entry in $entries) {
    $destination = Resolve-ContainedPath -Root $addonRoot -RelativePath $entry.Destination `
        -Description 'Addon file destination'
    if (Test-Path -LiteralPath $destination -PathType Container) {
        throw "Addon file destination is unexpectedly a directory: $($entry.Destination)"
    }

    $exists = Test-Path -LiteralPath $destination -PathType Leaf
    $same = $exists -and ((Get-FileSha256 -Path $destination) -eq $entry.Sha256)
    if ($same) {
        $unchanged++
        continue
    }

    if ($DryRun) {
        if ($exists) { $wouldUpdate++ } else { $wouldCopy++ }
        continue
    }

    $parent = Split-Path -Parent $destination
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    [IO.File]::Copy($entry.Source, $destination, $true)
    if ((Get-FileSha256 -Path $destination) -ne $entry.Sha256) {
        throw "Copied addon file failed hash verification: $($entry.Destination)"
    }
    if ($exists) { $updated++ } else { $copied++ }
}

$managedRecords = @($entries | ForEach-Object {
    [ordered]@{ path = $_.Destination; sha256 = $_.Sha256 }
})
$newInstalledManifest = [ordered]@{
    schema_version = 1
    package_version = $version
    files = $managedRecords
}
$installedManifestJson = ($newInstalledManifest | ConvertTo-Json -Depth 6) + `
    [Environment]::NewLine
$manifestAction = 'unchanged'
if (-not (Test-Path -LiteralPath $installedManifestPath -PathType Leaf)) {
    $manifestAction = if ($DryRun) { 'would_create' } else { 'created' }
}
elseif ([IO.File]::ReadAllText($installedManifestPath) -cne $installedManifestJson) {
    $manifestAction = if ($DryRun) { 'would_update' } else { 'updated' }
}

if (-not $DryRun -and $manifestAction -ne 'unchanged') {
    [IO.Directory]::CreateDirectory($addonRoot) | Out-Null
    [IO.File]::WriteAllText($installedManifestPath, $installedManifestJson, $utf8NoBom)
}

[pscustomobject]@{
    PackageVersion = $version
    TargetProject = $targetRoot
    AddonRoot = $addonRoot
    ManagedFiles = $entries.Count
    Copied = $copied
    Updated = $updated
    Removed = $removed
    Unchanged = $unchanged
    WouldCopy = $wouldCopy
    WouldUpdate = $wouldUpdate
    WouldRemove = $wouldRemove
    InstalledManifest = $manifestAction
    DryRun = [bool]$DryRun
}
