param(
    [string]$GodotPath = 'C:\Projects\godot\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64.exe',
    [ValidateSet('house', 'shop', 'hotel', 'church', 'castle', 'temple')]
    [string[]]$Family = @(),
    [Nullable[int]]$Seed = $null,
    [string]$Output = 'artifacts/roof_audit',
    [int]$TimeoutSeconds = 600,
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$reportBase = [IO.Path]::GetFullPath((Join-Path $workspace $Output))
$reportDirectory = Split-Path $reportBase -Parent
New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}
if ($TimeoutSeconds -lt 1) { throw 'TimeoutSeconds must be positive.' }
$arguments = @('--headless', '--path', ('"' + $workspace + '"'), '--script',
    'res://tools/check_roofs.gd', '--', ('"--out=' + $reportBase.Replace('\', '/') + '"'))
foreach ($item in $Family) { $arguments += "--family=$item" }
if ($null -ne $Seed) { $arguments += "--seed=$Seed" }
if ($SelfTest) { $arguments += '--self-test' }
$started = [DateTime]::UtcNow
$process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WorkingDirectory $workspace `
    -WindowStyle Hidden -PassThru -RedirectStandardOutput ($reportBase + '.log') `
    -RedirectStandardError ($reportBase + '.err')
$null = $process.Handle # Retain the Windows handle so ExitCode survives exit.
try {
    # Godot can hang after a GDScript parse error; stop this process promptly.
    while (-not $process.WaitForExit(500)) {
        $errors = Get-Content -LiteralPath ($reportBase + '.err') -Raw -ErrorAction SilentlyContinue
        if ($errors -match 'SCRIPT ERROR:|Parse Error:') {
            throw "Godot script failed. See $reportBase.err`n$errors"
        }
        if (([DateTime]::UtcNow - $started).TotalSeconds -gt $TimeoutSeconds) {
            throw "Roof audit exceeded ${TimeoutSeconds}s. See $reportBase.log"
        }
    }
    $process.WaitForExit()
    $errors = Get-Content -LiteralPath ($reportBase + '.err') -Raw -ErrorAction SilentlyContinue
    if ($errors -match 'SCRIPT ERROR:|ERROR:') { throw "Godot error. See $reportBase.err`n$errors" }
    if ($process.ExitCode -notin @(0, 1)) { throw "Audit runner exited $($process.ExitCode). See $reportBase.log" }
    $report = Get-Item -LiteralPath ($reportBase + '.json')
    if ($report.LastWriteTimeUtc -lt $started) { throw 'Audit did not produce a fresh report.' }
    $summary = Get-Content -LiteralPath $report.FullName -Raw | ConvertFrom-Json
    Write-Output "Roof audit: $($summary.checked) checks, $($summary.failure_groups) failure groups, $($summary.warning_groups) warning groups."
    Write-Output "Report: $reportBase.md"
    exit $process.ExitCode
} finally {
    if (-not $process.HasExited) { Stop-Process -Id $process.Id }
    $process.Dispose()
}
