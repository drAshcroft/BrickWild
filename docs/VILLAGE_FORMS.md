# Village forms (VIL-017)

All seven forms are implemented by `VillageSitePlanner`. VIL-017 adds
crossroads, round, strand, planted and gate to the existing street and green
forms. **Acceptance is pending.** The full native fifty-seed matrices are
still running; a focused fixture or a partial range does not close this task.

## Implemented plans

| Form | Site and final placement |
|---|---|
| Crossroads | Two through roads meet at the common. The inn occupies a crossing corner. Its stable stays within twenty metres and may use an explicitly addressed companion lane. |
| Round | A polygonal circular common has radial wedge lots and one entrance lane. Common-facing trades and farms fill uncovered sectors. Site retries continue when every request fits but the common's frontage remains below the existing rule. |
| Strand | One row faces the coast, with the through road behind it. Native row depths set the shore reserve. The inland landmark lane is at most forty metres from its junction. Both boats and drying racks occupy usable ground on the shore side. |
| Planted | A market square of at least 400 square metres joins a short grid with at least two distinct parallel streets. Wealth permits the existing terrace rules. |
| Gate | A manor or keep stands at the head of its own approach. The site reserves depth for its complete measured lot, forecourt, rear yard and oblique lane; width retries recalculate that reserve against the actual road. |

Road addresses distinguish a preference from a requirement. When an
`insists` road class has no legal frontage, the building remains unplaced so
the bounded site retries can make room. An ordinary lane cannot satisfy a
trade that requires the through road. A failed manor approach likewise stays
unplaced instead of falling through to ordinary frontage.

Blighted ruin groups reserve their full measured cluster footprint outside
every common. Dry ground alone is insufficient: a broken wall remains an
obstruction on public working space. The placement tries another cluster
site when any part overlaps the common, preserving its ordinary clearance
checks and the independent common rule.

An open manor's measured arrival corridor uses a cropped 0.1-metre grid for
its width check. This retains the same floors, buildings, water, trunks and
props while avoiding the width lost when an oblique two-metre court is
rasterized at village resolution. The required 1.2-metre clearance and the
global gate-to-door flood are unchanged. Rotated fixtures include genuinely
narrow courts and solid obstacles as failure controls.

## Shore working ground

After building decorations, hedges and edge planting are complete, the
dresser samples the actual coast polygon beside reached rear yards.
Boats and racks use their emitted, rotated footprints for collision checks.
Each accepted piece is present as an obstacle when the ordinary village walk
grid verifies access to it and to earlier shore pieces. Optional shore crates
must preserve those routes too. This checks the entire final yard route;
keeping only an apron clear cannot prevent a distant bush from cutting it off.

A short gap may receive a two-metre-wide working apron. Its anchor must lie
on reached yard ground, its length is bounded to eight metres, and its
polygon must fit the site without crossing water, buildings, existing props
or blocking trunks. The village builder emits this polygon as road surface;
the navigation grid reads the same physical approach. Later props and plants
reserve the approach. A negative fixture removes the sole apron and requires
the boat to become unreachable; another checks the emitted mesh vertices.

Long strand sites keep jittered edge-tree candidates inside their visible
edge band. A candidate that falls outside the site is projected inward before
the ordinary road, roof, water and plant-clearance checks. This prevents a run
of discarded stations from leaving an otherwise clear shore boundary bare.

## Acceptance runs

Use the registered suites for ordinary checks:

```text
godot --headless --path . --script res://tests/run_all.gd -- vformslayout
godot --headless --path . --script res://tests/run_all.gd -- vforms
```

The complete gate runs fifty native programmes for each remaining form:

```text
godot --headless --path . --script res://tests/village_forms_full_test.gd
```

It can be split into named forms and disjoint seed ranges. Every seed from
0 through 49 must still pass for every form:

```text
godot --headless --path . --script res://tests/village_forms_full_test.gd -- --form=round --start=0 --count=25
godot --headless --path . --script res://tests/village_forms_full_test.gd -- --form=round --start=25 --count=25
```

Each native sample checks the complete request multiset, the form's final
geometry and all six village groups: Scale, Road, Lot, Place, Dress and Nav.
Scale's determinism check independently regenerates the ordinary native plan
and compares its encoded result. The primary measurements may come from the
shared test-only cache keyed by exact requests, native source, Godot version,
catalogue and project settings. Every placement, retry, crossing, enclosure,
dressing and QA pass still runs. The fresh determinism twin bypasses that
cache. Building-family acceptance is also required by the VIL-020 archetype
matrix.

Redirect long runs to files. A finished range needs its result line, process
exit code and an error log without script failures. A stopped range is
incomplete even when its earlier seeds passed. After a planner fix, rerun
affected seeds on the final source. A cache replay can add new structural
assertions to an already completed native determinism run; record those two
pieces of evidence separately.

On a failed sample, the suite saves its exact `BuildingCodec.encode(plan)`
payload under `artifacts/village_forms_failures/`, named by form, seed and
timestamp. Load the binary with `FileAccess.get_var(false)` and decode it
with `BuildingCodec` to diagnose the actual output without recutting lots.

## Evidence status

The focused shore contract passes twenty-three checks, including emitted bounds,
physical apron geometry, removed-apron failure, edge continuity and obstruction
prevention along both the apron and its upstream yard route.
Fifty seeded ruin placements and a fully blocked common pass fifty-one
focused checks; the actual round seed 41 retains all three ruin pieces away
from its common and passes the six village groups in a diagnostic replay.
The full gate remains open until the following rows have complete evidence.

| Form | Required native seed range | Current acceptance |
|---|---|---|
| Crossroads | 0–49 | Pending final-source full range |
| Round | 0–49 | Pending complete ranges and final semantic replay |
| Strand | 0–49 | Pending final-source full range |
| Planted | 0–49 | Pending full range and final semantic replay |
| Gate | 0–49 | Pending final-source full range |

Fill the final evidence table only after all required ranges pass. Keep
diagnostic runs that exposed real failures distinct from completed acceptance.
