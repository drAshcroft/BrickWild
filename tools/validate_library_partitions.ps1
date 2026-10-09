param(
    [Parameter(Mandatory = $true)]
    [string]$LogDirectory,
    [Parameter(Mandatory = $true)]
    [string]$ResultsCsv
)

$expected = [ordered]@{
    church_101 = 'church:101'
    castle_202 = 'castle:202'
    house_303 = 'house:303'
    shop_353 = 'shop:353'
    hotel_373 = 'hotel:373'
    temple_404 = 'temple:404'
    windmill_505 = 'windmill:505'
    windmill_515 = 'windmill:515'
    village = 'village:9101'
    world = 'world:828'
    globals = 'controls=globals'
}

$errors = [System.Collections.Generic.List[string]]::new()
$rows = @(Import-Csv -LiteralPath $ResultsCsv)
$seen = @{}
foreach ($row in $rows) {
    $partition = [string]$row.partition
    if (-not $expected.Contains($partition)) {
        $errors.Add("unexpected partition row '$partition'")
        continue
    }
    if ($seen.ContainsKey($partition)) {
        $errors.Add("duplicate partition row '$partition'")
        continue
    }
    $seen[$partition] = $true
    $nativeExit = 0
    if (-not [int]::TryParse([string]$row.native_exit, [ref]$nativeExit)) {
        $errors.Add("$partition native_exit is missing or not an integer: '$($row.native_exit)'")
    } elseif ($nativeExit -ne 0) {
        $errors.Add("$partition native exit was $nativeExit, expected 0")
    }
    $seconds = 0.0
    if (-not [double]::TryParse([string]$row.host_seconds,
            [Globalization.NumberStyles]::Float,
            [Globalization.CultureInfo]::InvariantCulture, [ref]$seconds) -or
        [double]::IsNaN($seconds) -or [double]::IsInfinity($seconds) -or
        $seconds -le 0.0 -or $seconds -ge 300.0) {
        $errors.Add("$partition host_seconds must be finite and in (0, 300); got '$($row.host_seconds)'")
    }
    $logPath = Join-Path $LogDirectory ($partition + '.log')
    if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) {
        $errors.Add("missing log for $partition at $logPath")
        continue
    }
    $log = Get-Content -LiteralPath $logPath -Raw
    if ($log -match '(?im)^\s*(?:ERROR|SCRIPT ERROR|Parse Error|Compile Error)\b') {
        $errors.Add("$partition log contains an engine/script error")
    }
    $expectedMarker = if ($partition -eq 'globals') {
        '\[library-partition\] controls=globals'
    } else {
        '\[library-partition\] request=' + [regex]::Escape($expected[$partition])
    }
    if ([regex]::Matches($log, '(?m)^' + $expectedMarker + '\s*$').Count -ne 1) {
        $errors.Add("$partition log must contain exactly one expected request/control marker")
    }
    if ([regex]::Matches($log, '(?m)^\[library-partition\] ' +
            [regex]::Escape($partition) + ' elapsed_ms=\d+\s*$').Count -ne 1) {
        $errors.Add("$partition log must contain exactly one elapsed marker")
    }
    $summaryPattern = '(?m)^libraryquick:' + [regex]::Escape($partition) +
        '\s+PASS\s+\(\d+ checked, 0 failures, \d+ warnings\)\s*$'
    if ([regex]::Matches($log, $summaryPattern).Count -ne 1) {
        $errors.Add("$partition log lacks exactly one passing zero-failure suite summary")
    }
}
foreach ($partition in $expected.Keys) {
    if (-not $seen.ContainsKey($partition)) {
        $errors.Add("missing partition result '$partition'")
    }
}
if ($rows.Count -ne $expected.Count) {
    $errors.Add("results CSV has $($rows.Count) rows; expected $($expected.Count)")
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { [Console]::Error.WriteLine("FAIL: $_") }
    exit 1
}
Write-Output "PASS: all $($expected.Count) libraryquick partitions have unique request markers, native exit 0, under-300-second host timings, clean logs, and passing summaries."
