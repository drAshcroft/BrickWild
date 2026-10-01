param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$Selectors,
    [ValidateRange(1, 86400)]
    [int]$TimeoutSeconds = 300
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$godot = 'C:\Projects\godot\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64.exe'
$selection = $Selectors -join '__'
$slug = $selection -replace '[^A-Za-z0-9_-]', '_'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$output = Join-Path $workspace ("artifacts/qa_fast/$slug/$stamp")
$profile = Join-Path $output 'profile'
$env:APPDATA = Join-Path $profile 'Roaming'
$env:LOCALAPPDATA = Join-Path $profile 'Local'
New-Item -ItemType Directory -Force -Path $output,$env:APPDATA,$env:LOCALAPPDATA | Out-Null

$stdout = Join-Path $output 'stdout.log'
$stderr = Join-Path $output 'stderr.log'
$godotLog = Join-Path $output 'godot.log'
$arguments = @('--headless', '--path', $workspace,
    '--log-file', $godotLog,
    '--script', 'res://tests/run_all.gd', '--') + $Selectors

$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = $godot
$start.Arguments = $arguments -join ' '
$start.WorkingDirectory = $workspace
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$start.EnvironmentVariables['APPDATA'] = $env:APPDATA
$start.EnvironmentVariables['LOCALAPPDATA'] = $env:LOCALAPPDATA
$process = [Diagnostics.Process]::new()
$process.StartInfo = $start
$timer = [Diagnostics.Stopwatch]::StartNew()
if (-not $process.Start()) { throw 'Godot did not start' }
$process.Id | Set-Content -LiteralPath (Join-Path $output 'godot_pid.txt')
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
$finished = $process.WaitForExit($TimeoutSeconds * 1000)
if (-not $finished) {
    try {
        $process.Kill()
        $process.WaitForExit()
    } catch {
        Write-Warning "Timed-out Godot PID $($process.Id) could not be stopped: $_"
    }
}
$timer.Stop()
[IO.File]::WriteAllText($stdout, $stdoutTask.Result)
[IO.File]::WriteAllText($stderr, $stderrTask.Result)
$nativeExit = if ($finished) { [string]$process.ExitCode } else { 'TIMEOUT' }

$seconds = [math]::Round($timer.Elapsed.TotalSeconds, 2)
$nativeExit | Set-Content -LiteralPath (Join-Path $output 'native_exit.txt')
$seconds | Set-Content -LiteralPath (Join-Path $output 'wall_seconds.txt')
$verdict = Select-String -LiteralPath $stdout `
    -Pattern '^ALL PASS|^\d+ SUITE\(S\) FAILED|^RUNNER FAILED' -ErrorAction SilentlyContinue |
    Select-Object -Last 1
$scriptErrors = Select-String -LiteralPath @($stdout,$stderr,$godotLog) `
    -Pattern 'Parse Error|SCRIPT ERROR|RUNNER FAILED' -ErrorAction SilentlyContinue

$status = 'PASS'
if (-not $finished) {
    $status = 'TIMEOUT'
} elseif ($nativeExit -ne '0' -or $scriptErrors -or $null -eq $verdict -or
        -not $verdict.Line.StartsWith('ALL PASS')) {
    $status = 'FAIL'
} elseif ($seconds -ge $TimeoutSeconds) {
    $status = 'SLOW'
}
@(
    "selectors=$selection",
    "status=$status",
    "native_exit=$nativeExit",
    "wall_seconds=$seconds",
    "godot_pid=$($process.Id)",
    "verdict=$($verdict.Line)"
) | Set-Content -LiteralPath (Join-Path $output 'result.txt')
Write-Output "$status $selection ${seconds}s native=$nativeExit"
Write-Output $output

if ($status -eq 'PASS') { exit 0 }
if ($status -eq 'SLOW' -or $status -eq 'TIMEOUT') { exit 124 }
exit 1
