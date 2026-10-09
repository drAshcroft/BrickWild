param(
    [Parameter(Mandatory = $true)]
    [string]$LogDirectory,
    [Parameter(Mandatory = $true)]
    [string]$ResultsCsv
)

$expected = [ordered]@{
    house_shop = @('request=house:1000', 'request=shop:1000', 'orientation=house:821', 'orientation=shop:822')
    church = @('request=church:1000', 'orientation=church:824')
    castle = @('request=castle:1000')
    castle_orientation = @('orientation=castle:825')
    temple = @('request=temple:1000')
    temple_orientation = @('orientation=temple:826')
    hotel_orientation = @('orientation=hotel:823')
    village = @('request=village:1000', 'orientation=village:827')
    world_insula = @('request=world:1000')
    world_insula_orientation = @('orientation=world:828')
    world_hall_orientation = @('orientation=world:829')
    world_stupa_orientation = @('orientation=world:830')
    world_rect = @('control=world_rect:house:42')
}
$errors = [System.Collections.Generic.List[string]]::new()
$rows = @(Import-Csv -LiteralPath $ResultsCsv)
$seen = @{}
$observedMarkers = [System.Collections.Generic.List[string]]::new()
$commonFingerprint = $null
foreach ($row in $rows) {
    $partition = [string]$row.partition
    if (-not $expected.Contains($partition)) { $errors.Add("unexpected partition '$partition'"); continue }
    if ($seen.ContainsKey($partition)) { $errors.Add("duplicate partition '$partition'"); continue }
    $seen[$partition] = $true
    $nativeExit = 0
    if (-not [int]::TryParse([string]$row.native_exit, [ref]$nativeExit)) {
        $errors.Add("$partition native_exit is missing or not an integer: '$($row.native_exit)'")
    } elseif ($nativeExit -ne 0) { $errors.Add("$partition native exit was $nativeExit") }
    $seconds = 0.0
    if (-not [double]::TryParse([string]$row.host_seconds,
            [Globalization.NumberStyles]::Float,
            [Globalization.CultureInfo]::InvariantCulture, [ref]$seconds) -or
        [double]::IsNaN($seconds) -or [double]::IsInfinity($seconds) -or
        $seconds -le 0.0 -or $seconds -ge 300.0) {
        $errors.Add("$partition host_seconds must be finite and in (0, 300); got '$($row.host_seconds)'")
    }
    $receiptPath = Join-Path $LogDirectory ($partition + '.receipt.json')
    $receipt = $null
    if (-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) {
        $errors.Add("missing $partition native receipt")
    } else {
        try { $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json }
        catch { $errors.Add("$partition receipt is invalid JSON: $_"); $receipt = $null }
        if ($null -ne $receipt) {
            if ([string]$receipt.partition -ne $partition) { $errors.Add("$partition receipt names a different partition") }
            if ([string]$receipt.native_exit -ne [string]$row.native_exit) { $errors.Add("$partition receipt/native CSV exit disagree") }
            $receiptSeconds = 0.0
            if (-not [double]::TryParse([string]$receipt.host_seconds,
                    [Globalization.NumberStyles]::Float,
                    [Globalization.CultureInfo]::InvariantCulture, [ref]$receiptSeconds) -or
                [double]::IsNaN($receiptSeconds) -or [double]::IsInfinity($receiptSeconds) -or
                $receiptSeconds -le 0.0 -or $receiptSeconds -ge 300.0 -or
                [math]::Abs($receiptSeconds - $seconds) -gt 0.001) {
                $errors.Add("$partition receipt host time is invalid or differs from CSV")
            }
            $receiptStableIsBoolean = $receipt.source_stable -is [bool]
            if (-not $receiptStableIsBoolean -or $receipt.source_stable -ne $true) {
                $errors.Add("$partition receipt source_stable must be JSON Boolean true")
            }
            $receiptBefore = [string]$receipt.source_fingerprint_before
            $receiptAfter = [string]$receipt.source_fingerprint_after
            if ($receiptBefore -notmatch '^[0-9a-fA-F]{64}$' -or $receiptAfter -notmatch '^[0-9a-fA-F]{64}$') {
                $errors.Add("$partition receipt fingerprints must be 64 hexadecimal SHA256 characters")
            }
            if ($receiptBefore -ne $receiptAfter) {
                $errors.Add("$partition source fingerprints are missing or changed during the process")
            }
            if ($receiptBefore -match '^[0-9a-fA-F]{64}$' -and $null -eq $commonFingerprint) {
                $commonFingerprint = $receiptBefore
            } elseif ($receiptBefore -match '^[0-9a-fA-F]{64}$' -and $receiptBefore -ne $commonFingerprint) {
                $errors.Add("$partition source fingerprint differs from other partitions")
            }
            $pidValue = 0
            if (-not [int]::TryParse([string]$receipt.owned_pid, [ref]$pidValue) -or $pidValue -le 0) {
                $errors.Add("$partition lacks an exact positive owned PID receipt")
            }
            if ([string]$receipt.status -ne 'RECORDED') { $errors.Add("$partition receipt status is '$($receipt.status)'") }
        }
    }
    if ([string]$row.source_stable -ne 'True') { $errors.Add("$partition CSV reports source drift") }
    $csvBefore = [string]$row.source_fingerprint_before
    $csvAfter = [string]$row.source_fingerprint_after
    if ($csvBefore -notmatch '^[0-9a-fA-F]{64}$' -or $csvAfter -notmatch '^[0-9a-fA-F]{64}$') {
        $errors.Add("$partition CSV fingerprints must be 64 hexadecimal SHA256 characters")
    }
    if ($csvBefore -ne $csvAfter) {
        $errors.Add("$partition CSV source fingerprints differ")
    }
    if ($null -ne $receipt -and
        ($csvBefore -ne [string]$receipt.source_fingerprint_before -or
         $csvAfter -ne [string]$receipt.source_fingerprint_after)) {
        $errors.Add("$partition receipt and CSV fingerprints disagree")
    }
    foreach ($suffix in @('.stdout.log', '.stderr.log', '.godot.log')) {
        $path = Join-Path $LogDirectory ($partition + $suffix)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $errors.Add("missing $partition log $suffix")
            continue
        }
        $log = Get-Content -LiteralPath $path -Raw
        if ($log -match '(?im)^\s*(?:ERROR|SCRIPT ERROR|Parse Error|Compile Error|RUNNER FAILED)\b') {
            $errors.Add("$partition $suffix contains an engine/script error")
        }
    }
    $stdoutPath = Join-Path $LogDirectory ($partition + '.stdout.log')
    if (-not (Test-Path -LiteralPath $stdoutPath -PathType Leaf)) { continue }
    $stdout = Get-Content -LiteralPath $stdoutPath -Raw
    foreach ($marker in $expected[$partition]) {
        if ([regex]::Matches($stdout, '(?m)^\[placement-partition\] ' + [regex]::Escape($marker) + '\s*$').Count -ne 1) {
            $errors.Add("$partition must contain exactly one marker '$marker'")
        } else { $observedMarkers.Add($marker) }
    }
    if ([regex]::Matches($stdout, '(?m)^\[placement-partition\] ' + [regex]::Escape($partition) + ' elapsed_ms=\d+\s*$').Count -ne 1) {
        $errors.Add("$partition must contain exactly one elapsed marker")
    }
    $summary = '(?m)^placementquick:' + [regex]::Escape($partition) +
        '\s+PASS\s+\(\d+ checked, 0 failures, \d+ warnings\)\s*$'
    if ([regex]::Matches($stdout, $summary).Count -ne 1) {
        $errors.Add("$partition lacks exactly one zero-failure passing SuiteResult summary")
    }
}
foreach ($partition in $expected.Keys) {
    if (-not $seen.ContainsKey($partition)) { $errors.Add("missing result '$partition'") }
}
$allMarkerLines = [System.Collections.Generic.List[string]]::new()
foreach ($partition in $expected.Keys) {
    $stdoutPath = Join-Path $LogDirectory ($partition + '.stdout.log')
    if (Test-Path -LiteralPath $stdoutPath -PathType Leaf) {
        foreach ($line in Get-Content -LiteralPath $stdoutPath) {
            if ($line -match '^\[placement-partition\] (request=.*|orientation=.*|control=.*)$') {
                $allMarkerLines.Add($Matches[1])
            }
        }
    }
}
$expectedMarkers = @($expected.Values | ForEach-Object { $_ }) | Sort-Object
$actualMarkers = @($allMarkerLines) | Sort-Object
if ($expectedMarkers.Count -ne $actualMarkers.Count -or
    (Compare-Object $expectedMarkers $actualMarkers -CaseSensitive)) {
    $errors.Add('request/control marker union differs from the frozen placementquick request set')
}
if ($rows.Count -ne $expected.Count) { $errors.Add("results CSV has $($rows.Count) rows; expected $($expected.Count)") }
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { [Console]::Error.WriteLine("FAIL: $_") }
    exit 1
}
Write-Output "PASS: all $($expected.Count) placementquick partitions have unique complete request markers, native exit 0, finite host time under 300 seconds, clean logs, and passing summaries. Full marker union: $($actualMarkers.Count) markers."
