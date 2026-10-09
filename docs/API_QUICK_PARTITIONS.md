# Bounded public API quick checks

`libraryquick` exercises the published `BrickWild` API across every building kind. It includes eight fixed request fixtures, village and world checks, document parity, placement and mesh contracts, invalid-request controls, kind coverage, the generic world envelope, descriptor immutability, and the stacked-house plan contract.

The single-process quick selector exceeded the five-minute host gate on a recent run. Partitioning preserves that gate per process and retains the full fixture set. It does not make the timed-out run a pass. Run all eleven partitions listed in `tools/validate_library_partitions.ps1`, in fresh Godot processes, and require every one to exit 0 in under 300 host seconds.

The required partition names are `church_101`, `castle_202`, `house_303`, `shop_353`, `hotel_373`, `temple_404`, `windmill_505`, `windmill_515`, `village`, `world`, and `globals`.

The eight request partitions use the exact quick fixtures from `LibrarySuite._run(true)`. Each calls the existing `_check_family`, `_check_contract`, and `_check_documents` helpers. `_check_contract` also retains its unknown-world-family negative control; because the existing helper owns that control, it runs once in each request partition. `village` and `world` call their existing helpers. `world` also runs `_check_world_generic_envelope`; that envelope check runs once. `globals` runs the nine original invalid-request controls, `_check_every_kind_covered` over the complete eight-request fixture list, and the descriptor and stacked-house blocks copied from `_run(true)`.

The driver reuses existing assertion helpers for family, contract, document, village, and world checks. It copies the original invalid-request setup and the descriptor/storey assertion blocks because those checks are inline in `_run(true)` rather than exposed as helpers. Keep those copies synchronized with the source suite. `tests/fixtures/libraryquick_partitions.json` maps each assertion group to its partition.

For each run, capture the complete Godot output in `<partition>.log` and record one CSV row with columns `partition,native_exit,host_seconds` in `run-results.csv`. Use `BRICK_WILD_TEST_TRACE=1` to retain the library suite's per-family timing trace. Then validate the union:

```powershell
$env:BRICK_WILD_TEST_TRACE = '1'
$logRoot = 'artifacts/libraryquick'
New-Item -ItemType Directory -Force $logRoot | Out-Null
$clock = [System.Diagnostics.Stopwatch]::StartNew()
$proc = Start-Process `
  -FilePath 'C:\Projects\godot\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64_console.exe' `
  -ArgumentList @('--headless', '--path', '.', '--script', 'res://tools/library_partition_driver.gd', '--', 'temple_404') `
  -PassThru -WindowStyle Hidden `
  -RedirectStandardOutput "$logRoot\temple_404.stdout.log" `
  -RedirectStandardError "$logRoot\temple_404.stderr.log"
if (-not $proc.WaitForExit(299000)) {
  $proc.Kill()
  $proc.WaitForExit()
  throw 'Owned Godot process reached the host timeout; this is not a pass.'
}
$clock.Stop()
$proc.ExitCode
$clock.Elapsed.TotalSeconds.ToString('F3', [Globalization.CultureInfo]::InvariantCulture)
Get-Content "$logRoot\temple_404.stdout.log", "$logRoot\temple_404.stderr.log" |
  Set-Content "$logRoot\temple_404.log"
```

Repeat for the remaining ten partition names, recording each native exit code and host duration. The validator rejects missing or duplicate partitions, wrong fixture markers, nonzero native exits, runs at or over 300 seconds, engine/script errors, and missing or failing summaries:

```powershell
.\tools\validate_library_partitions.ps1 `
  -LogDirectory artifacts\libraryquick `
  -ResultsCsv artifacts\libraryquick\run-results.csv
```

A passing aggregate may be reported only after all eleven processes and the validator pass. It is an aggregate of bounded processes, not a claim that the original single-process `libraryquick` selector passed.

## Verified checkpoint, 2026-10-08

Root reviewed the request and assertion union against `LibrarySuite._run(true)`.
All eleven processes passed with native exit 0, clean logs and a common unchanged
source fingerprint. The union validator passed. Root also confirmed rejection
of missing native exits, `NaN` timings and duplicate result rows after correcting
two gaps in the original Luna validator proposal.

The aggregate covers 195 checks in 702.046 host seconds. Individual processes
took 20.805–268.386 seconds; the hotel was slowest. Receipts, complete output,
CSV results and the source fingerprint are retained in
`artifacts/personality/resumed/restart5_library_parts/`.

This completes `LIVE-API-PARTITIONS`. It verifies the bounded library coverage
only. The original combined library selector timed out. The placement quick
selector also timed out; its complete coverage and the remaining API lane suites
must be verified separately before claiming that lane passes. Scheduled full
library and placement sweeps remain separate from these quick fixtures.
