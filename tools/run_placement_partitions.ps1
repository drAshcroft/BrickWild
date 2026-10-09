param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,
    [ValidateRange(1, 290)]
    [int]$PartitionTimeoutSeconds = 285
)

$ErrorActionPreference = 'Stop'
$workspace = 'C:\Projects\BrickWild'
$godot = 'C:\Projects\godot\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64.exe'
$driverRelative = 'tools/placement_partition_driver.gd'
$driver = 'res://tools/placement_partition_driver.gd'
$partitions = @(
    'house_shop', 'church', 'castle', 'castle_orientation', 'temple',
    'temple_orientation', 'hotel_orientation', 'village', 'world_insula',
    'world_insula_orientation', 'world_hall_orientation',
    'world_stupa_orientation', 'world_rect'
)

function Get-SourceFingerprint {
    $files = [System.Collections.Generic.List[string]]::new()
    foreach ($relative in @('src', 'core', 'qa', 'tests')) {
        $root = Join-Path $workspace $relative
        foreach ($file in Get-ChildItem -LiteralPath $root -File -Recurse) {
            $files.Add($file.FullName)
        }
    }
    $files.Add((Join-Path $workspace 'tools/placement_partition_driver.gd'))
    $rows = [System.Collections.Generic.List[string]]::new()
    foreach ($path in @($files | Sort-Object -Unique)) {
        $rel = [IO.Path]::GetRelativePath($workspace, $path).Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        $rows.Add("$rel`t$hash")
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($rows -join "`n"))
    $sha = [Security.Cryptography.SHA256]::HashData($bytes)
    return [Convert]::ToHexString($sha).ToLowerInvariant()
}

$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$resultsCsv = Join-Path $OutputDirectory 'results.csv'
$rows = [System.Collections.Generic.List[object]]::new()
$initialFingerprint = Get-SourceFingerprint
$previousFingerprint = $initialFingerprint
foreach ($partition in $partitions) {
    $before = Get-SourceFingerprint
    if ($before -ne $previousFingerprint -or $before -ne $initialFingerprint) {
        $rows.Add([pscustomobject]@{
            partition = $partition; native_exit = 'SOURCE_DRIFT'; host_seconds = '0.001'
            owned_pid = ''; source_fingerprint_before = $before
            source_fingerprint_after = $before; source_stable = 'false'
        })
        $rows | Export-Csv -LiteralPath $resultsCsv -NoTypeInformation
        Write-Error "Source fingerprint changed before $partition; stopping the partition sequence."
        break
    }
    $stdoutPath = Join-Path $OutputDirectory ($partition + '.stdout.log')
    $stderrPath = Join-Path $OutputDirectory ($partition + '.stderr.log')
    $godotLogPath = Join-Path $OutputDirectory ($partition + '.godot.log')
    $pidPath = Join-Path $OutputDirectory ($partition + '.owned_pid.txt')
    $receiptPath = Join-Path $OutputDirectory ($partition + '.receipt.json')
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $godot
    $start.Arguments = @('--headless', '--path', $workspace, '--log-file', $godotLogPath,
        '--script', $driver, '--', $partition) -join ' '
    $start.WorkingDirectory = $workspace
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $timer = [Diagnostics.Stopwatch]::StartNew()
    if (-not $process.Start()) { throw "Godot did not start for $partition" }
    $process.Id | Set-Content -LiteralPath $pidPath
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $finished = $false
    $earlyError = $false
    while (-not $process.HasExited) {
        if (Test-Path -LiteralPath $godotLogPath -PathType Leaf) {
            $liveLog = Get-Content -LiteralPath $godotLogPath -Raw -ErrorAction SilentlyContinue
            if ($liveLog -match '(?im)SCRIPT ERROR|Parse Error|Compile Error|RUNNER FAILED') {
                $earlyError = $true
                $process.Kill() # this Process object is the exact PID owned by this partition
                $process.WaitForExit()
                break
            }
        }
        if ($timer.Elapsed.TotalSeconds -ge $PartitionTimeoutSeconds) {
            $process.Kill() # never search for or kill an unrelated Godot process
            $process.WaitForExit()
            break
        }
        Start-Sleep -Milliseconds 200
    }
    $finished = $process.HasExited -and -not $earlyError -and
        $timer.Elapsed.TotalSeconds -lt $PartitionTimeoutSeconds
    $timer.Stop()
    [IO.File]::WriteAllText($stdoutPath, $stdoutTask.Result)
    [IO.File]::WriteAllText($stderrPath, $stderrTask.Result)
    $nativeExit = if ($earlyError) { 'EARLY_SCRIPT_ERROR' } elseif (-not $finished) { 'TIMEOUT' } else { [string]$process.ExitCode }
    $after = Get-SourceFingerprint
    $sourceStable = ($before -eq $after) -and ($after -eq $initialFingerprint)
    $seconds = [math]::Round($timer.Elapsed.TotalSeconds, 3)
    $status = if (-not $sourceStable) { 'SOURCE_DRIFT' } elseif ($earlyError) { 'SCRIPT_ERROR' } elseif (-not $finished) { 'TIMEOUT' } elseif ($nativeExit -ne '0') { 'FAIL' } else { 'RECORDED' }
    $receipt = [ordered]@{
        partition = $partition; native_exit = $nativeExit; host_seconds = $seconds
        status = $status; owned_pid = $process.Id; source_fingerprint_before = $before
        source_fingerprint_after = $after; source_stable = $sourceStable
        stdout = [IO.Path]::GetFileName($stdoutPath); stderr = [IO.Path]::GetFileName($stderrPath)
        godot_log = [IO.Path]::GetFileName($godotLogPath)
    }
    $receipt | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $receiptPath -Encoding utf8
    $rows.Add([pscustomobject]@{
        partition = $partition; native_exit = $nativeExit; host_seconds = $seconds
        owned_pid = $process.Id; source_fingerprint_before = $before
        source_fingerprint_after = $after; source_stable = [string]$sourceStable
    })
    $rows | Export-Csv -LiteralPath $resultsCsv -NoTypeInformation
    Write-Output "$partition status=$status native=$nativeExit host_seconds=$seconds pid=$($process.Id)"
    $previousFingerprint = $after
    if (-not $sourceStable) {
        Write-Error "Source fingerprint changed during $partition; stopping the partition sequence."
        break
    }
    if ($earlyError) {
        Write-Error "Script or parse error in $partition; receipt was recorded and the partition sequence is stopping."
        break
    }
}
Write-Output "results=$resultsCsv"
