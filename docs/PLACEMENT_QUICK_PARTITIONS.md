# Bounded quick placement checks

`tools/placement_partition_driver.gd` preserves the complete `placementquick`
fixture set when its combined process exceeds the five-minute gate. It reuses
the existing family, placement and world-rectangle assertions. The orientation
request factory and per-request assertion loop are extracted into helpers;
the original quick and full selectors still run their original complete sets.

The thirteen parts retain seven canonical seed1000 family requests, all ten
orientation/period requests at seeds821–830 and the seed42 world-rectangle
control. `tests/fixtures/placementquick_partitions.json` records their ownership.
Hotel orientation still checks the hotel door, and all three world orientations
remain included. No request dimensions or assertion tolerances were reduced.

Run the sequential processes and validate the complete union:

```powershell
.\tools\run_placement_partitions.ps1 `
  -OutputDirectory artifacts\placementquick\run1
.\tools\validate_placement_partitions.ps1 `
  -LogDirectory artifacts\placementquick\run1 `
  -ResultsCsv artifacts\placementquick\run1\results.csv
```

The runner records each exact owned PID, native exit, complete output and source
fingerprints, with a 285-second process cap. It writes receipts incrementally,
stops on source drift or script errors and never kills unrelated Godot processes.
The validator requires all thirteen parts, the exact eighteen-marker union,
passing summaries, clean logs, finite positive host times under 300 seconds,
native exit0 and matching unchanged SHA256 fingerprints. A source-stability
receipt must contain the actual JSON Boolean `true`; a string is not accepted.
Inspect and fix any failed part before claiming aggregate success.

## Verified checkpoint, 2026-10-08

Root reviewed the helper extraction against the original complete suite and
ran every partition. All thirteen passed: 31 checks, no failures or warnings,
434.399 seconds in aggregate; the slowest process was 95.811 seconds. The union
validator passed, and root confirmed rejection of string-false stability and
malformed or mismatched fingerprints. Complete receipts are retained in
`artifacts/personality/resumed/restart5_placement_parts/`.

This completes `LIVE-PLACEMENT-PARTITIONS`. The original combined quick selector
remains a timeout at 300.952 seconds. This is an aggregate of bounded processes.
Together with the eleven library partitions and `poly windmill cultureapi
compactapi`, it retains the complete quick API-lane coverage. It does not replace
scheduled full placement/library sweeps or establish visual design acceptance.
