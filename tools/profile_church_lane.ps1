param(
    [string]$GodotExe = 'C:\Projects\godot\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64.exe',
    [string]$OutputDirectory = 'artifacts/qa_perf_002'
)

$outputPath = Join-Path (Get-Location).Path $OutputDirectory
New-Item -ItemType Directory -Path $outputPath -Force | Out-Null

foreach ($suite in @('churchroof', 'churchchange')) {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $GodotExe
    $startInfo.Arguments = "--headless --path . --script res://tests/run_all.gd -- $suite"
    $startInfo.WorkingDirectory = (Get-Location).Path
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    $watch.Stop()

    $stdout | Set-Content -LiteralPath (Join-Path $outputPath "$suite.log")
    $stderr | Set-Content -LiteralPath (Join-Path $outputPath "$suite.stderr.log")
    '{0}: wall={1:N2}s cpu={2:N2}s exit={3}' -f $suite, `
        $watch.Elapsed.TotalSeconds, $process.TotalProcessorTime.TotalSeconds, $process.ExitCode
    if ($process.ExitCode -ne 0) { exit $process.ExitCode }
}
