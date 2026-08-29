[CmdletBinding()]
param(
    [string]$GodotPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$installer = Join-Path $PSScriptRoot 'install_big_glade_addon.ps1'
$sourceManifestPath = Join-Path $PSScriptRoot 'big_glade_addon_manifest.json'
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar)
$fixture = Join-Path $tempBase ('BigGladeAddonInstall_' + [Guid]::NewGuid().ToString('N'))
$fixture = [IO.Path]::GetFullPath($fixture)
$expectedPrefix = $tempBase + [IO.Path]::DirectorySeparatorChar + 'BigGladeAddonInstall_'
if (-not $fixture.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing unsafe fixture path: $fixture"
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ($Expected -ne $Actual) {
        throw "$Message (expected '$Expected', got '$Actual')"
    }
}

function Invoke-GodotFixture {
    param([string[]]$Arguments)

    $quotedArguments = @($Arguments | ForEach-Object {
        '"' + $_.Replace('"', '\"') + '"'
    }) -join ' '
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $GodotPath
    $startInfo.Arguments = $quotedArguments
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw 'Godot process did not start'
    }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(120000)) {
        $process.Kill()
        throw 'Godot fixture timed out after 120 seconds'
    }
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    if ($process.ExitCode -ne 0) {
        throw "Godot fixture failed with exit code $($process.ExitCode):`n$stdout`n$stderr"
    }
    return [pscustomobject]@{ Stdout = $stdout; Stderr = $stderr }
}

try {
    $sourceManifest = [IO.File]::ReadAllText($sourceManifestPath) | ConvertFrom-Json
    Assert-Equal 40 @($sourceManifest.scripts).Count `
        'Addon runtime script closure changed unexpectedly'
    foreach ($script in @($sourceManifest.scripts)) {
        $scriptSource = Join-Path $sourceRoot ([string]$script.source)
        if (-not (Test-Path -LiteralPath $scriptSource -PathType Leaf)) {
            throw "Manifest runtime script is missing: $($script.source)"
        }
        if (-not (Test-Path -LiteralPath ($scriptSource + '.uid') -PathType Leaf)) {
            throw "Manifest runtime script UID is missing: $($script.source).uid"
        }
    }

    [IO.Directory]::CreateDirectory($fixture) | Out-Null
    [IO.File]::WriteAllText(
        (Join-Path $fixture 'project.godot'),
        "config_version=5`n`n[application]`nconfig/name=`"BigGlade addon fixture`"`n")

    $dry = & $installer -TargetProject $fixture -DryRun
    Assert-Equal $true $dry.DryRun 'Dry run flag was not reported'
    if ($dry.WouldCopy -le 0) {
        throw 'Dry run did not report the initial addon copies'
    }
    if (Test-Path -LiteralPath (Join-Path $fixture 'addons/big_glade')) {
        throw 'Dry run changed the target project'
    }

    $first = & $installer -TargetProject $fixture
    if ($first.Copied -le 0) {
        throw 'Initial install copied no files'
    }
    Assert-Equal 'created' $first.InstalledManifest 'Initial install manifest action'
    if (@($sourceManifest.trees).Count -ne 1 -or
            [string]$sourceManifest.trees[0].source -ne 'assets/props/fantasy') {
        throw 'Manifest does not package the complete Fantasy Props tree'
    }

    $addonRoot = Join-Path $fixture 'addons/big_glade'
    $installedManifest = Join-Path $addonRoot '.big_glade_install_manifest.json'
    foreach ($required in @(
        'api/big_glade.gd',
        'api/big_glade.gd.uid',
        'runtime/navigation/house_nav_check.gd',
        'assets/props/catalog.json',
        'assets/props/fantasy/Anvil.gltf',
        'assets/props/fantasy/Anvil.bin',
        'assets/props/fantasy/License_Standard.txt',
        'assets/props/fantasy/README.md',
        'plugin.cfg',
        'VERSION'
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $addonRoot $required) -PathType Leaf)) {
            throw "Required installed file is missing: $required"
        }
    }

    $importFiles = @(Get-ChildItem -LiteralPath $addonRoot -Filter '*.import' -File -Recurse)
    Assert-Equal 0 $importFiles.Count 'Installer copied generated .import files'

    $assetSource = [IO.Path]::GetFullPath((Join-Path $sourceRoot 'assets/props/fantasy'))
    $assetDestination = Join-Path $addonRoot 'assets/props/fantasy'
    $expectedAssets = @(Get-ChildItem -LiteralPath $assetSource -File -Recurse |
        Where-Object { -not $_.Name.EndsWith('.import', [StringComparison]::OrdinalIgnoreCase) } |
        ForEach-Object {
            $_.FullName.Substring($assetSource.Length).TrimStart(
                [IO.Path]::DirectorySeparatorChar,
                [IO.Path]::AltDirectorySeparatorChar).Replace('\', '/')
        } | Sort-Object)
    $installedAssets = @(Get-ChildItem -LiteralPath $assetDestination -File -Recurse |
        ForEach-Object {
            $_.FullName.Substring($assetDestination.Length).TrimStart(
                [IO.Path]::DirectorySeparatorChar,
                [IO.Path]::AltDirectorySeparatorChar).Replace('\', '/')
        } | Sort-Object)
    if (@(Compare-Object -ReferenceObject $expectedAssets -DifferenceObject $installedAssets).Count -ne 0) {
        throw 'Installed Fantasy Props tree does not match the complete source tree'
    }

    $installedManifestData = [IO.File]::ReadAllText($installedManifest) | ConvertFrom-Json
    $managedPaths = @($installedManifestData.files | ForEach-Object { [string]$_.path })
    foreach ($script in @($sourceManifest.scripts)) {
        $destination = ([string]$script.destination).Replace('\', '/')
        if ($destination -notin $managedPaths -or ($destination + '.uid') -notin $managedPaths) {
            throw "Installed manifest omitted runtime script closure: $destination"
        }
    }

    $unmanaged = Join-Path $addonRoot 'consumer_owned.txt'
    [IO.File]::WriteAllText($unmanaged, 'keep')
    $manifestHashBefore = (Get-FileHash -LiteralPath $installedManifest -Algorithm SHA256).Hash

    $second = & $installer -TargetProject $fixture
    Assert-Equal 0 $second.Copied 'Idempotent install copied new files'
    Assert-Equal 0 $second.Updated 'Idempotent install updated files'
    Assert-Equal 0 $second.Removed 'Idempotent install removed files'
    Assert-Equal 'unchanged' $second.InstalledManifest 'Idempotent manifest action'
    Assert-Equal $true (Test-Path -LiteralPath $unmanaged -PathType Leaf) `
        'Installer removed an unmanaged consumer file'
    $manifestHashAfter = (Get-FileHash -LiteralPath $installedManifest -Algorithm SHA256).Hash
    Assert-Equal $manifestHashBefore $manifestHashAfter 'Idempotent install rewrote its manifest'

    $finalDry = & $installer -TargetProject $fixture -DryRun
    Assert-Equal 0 $finalDry.WouldCopy 'Idempotent dry run planned copies'
    Assert-Equal 0 $finalDry.WouldUpdate 'Idempotent dry run planned updates'
    Assert-Equal 0 $finalDry.WouldRemove 'Idempotent dry run planned removals'
    Assert-Equal 'unchanged' $finalDry.InstalledManifest 'Idempotent dry-run manifest action'

    $godotVerified = $false
    if (-not [string]::IsNullOrWhiteSpace($GodotPath)) {
        if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
            throw "GodotPath does not exist: $GodotPath"
        }
        $smokePath = Join-Path $fixture 'smoke.gd'
        $smoke = @'
extends SceneTree

func _init() -> void:
	var failed := false
	var requests := [
		BuildingRequest.church(101),
		BuildingRequest.castle(102),
		BuildingRequest.house(103),
		BuildingRequest.temple(104),
	]
	for request in requests:
		var generated := BigGlade.generate(request)
		if not generated.is_ok():
			printerr("generation failed: %s" % generated.errors)
			failed = true
			continue
		var mesh := BigGlade.build_mesh(generated)
		if mesh == null or mesh.get_surface_count() == 0:
			printerr("mesh emission failed for %s" % request.kind)
			failed = true
		var node := BigGlade.instantiate(generated)
		if node == null:
			printerr("scene instantiation failed for %s" % request.kind)
			failed = true
		else:
			node.free()
	for key in PropCatalog.keys():
		if not ResourceLoader.exists(PropCatalog.scene_path(key)):
			printerr("prop resource missing: %s" % key)
			failed = true
	var repeat := BigGlade.generate(BuildingRequest.church(101))
	if repeat.name() != BigGlade.generate(BuildingRequest.church(101)).name():
		printerr("same-seed generation was not deterministic")
		failed = true
	print("BIGGLADE_ADDON_SMOKE_OK")
	quit(1 if failed else 0)
'@
        [IO.File]::WriteAllText($smokePath, $smoke, $utf8NoBom)
        $null = Invoke-GodotFixture -Arguments @('--headless', '--path', $fixture,
            '--editor', '--quit')
        $smokeResult = Invoke-GodotFixture -Arguments @('--headless', '--path', $fixture,
            '--script', 'res://smoke.gd')
        if (-not $smokeResult.Stdout.Contains('BIGGLADE_ADDON_SMOKE_OK')) {
            throw "Godot smoke did not report completion:`n$($smokeResult.Stdout)`n$($smokeResult.Stderr)"
        }
        $godotVerified = $true
    }

    [pscustomobject]@{
        Passed = $true
        ManagedFiles = $second.ManagedFiles
        GodotVerified = $godotVerified
        Fixture = $fixture
    }
}
finally {
    if (Test-Path -LiteralPath $fixture) {
        $resolvedFixture = [IO.Path]::GetFullPath($fixture)
        if (-not $resolvedFixture.StartsWith($expectedPrefix,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing unsafe fixture cleanup: $resolvedFixture"
        }
        Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
    }
}
