# Floor seats and causal room repair

A chair assigned to a table still stands on the floor. HouseNavCheck formerly skipped every furniture record with a host index, omitting both hosted-chair bodies and their use zones. The checker now uses the measured catalogue's floor-blocking classification and mounted status for both filters. Elevated tabletop props and wall-mounted objects retain their behavior.

The corrected checker exposed a second defect. Room-end repair checked the entire house and removed the current room's optional furniture even when the same failure belonged to an earlier room. In the two-storey Townhouse innkeeper case (13 x 16 m, 2.9 m per storey, seed 32102), this stripped later bedrooms. Room repair now compares actual failure messages, unreachable room indices and unreachable item indices against the pre-room report. An unchanged inherited failure leaves that room's furniture intact. Newly blocked rooms still receive bounded repair.

The furnisher carries each room's final report to the next room. No plan mutation occurs between those calls. Every removal is followed by a new check, including a removal on the third and final attempt. The cache is local to one furnishing call. Global repair now trials hosted floor seats and compares necessity, complete repair and retained inventory. It still records a necessary local compromise when every useful candidate is required.

## Native evidence

Validated against a clean committed source baseline plus these two production changes, with the owned catalogue and actual models. Existing failures are retained rather than relabelled as passes.

| Check | Native result | Host time | Finding |
|---|---|---:|---|
| Measured hosted/unhosted floor-seat controls | 0 | 17.843 s | Body and use-zone behavior agree; elevated and mounted controls pass |
| Same floor fixture with the old checker | 1, expected negative | 16.786 s | Twelve specific hosted-floor omissions are detected |
| Real Townhouse office activity/blocked-chair control | 0 | 72.054 s | All three ordinary public sizes and scopes; measured blocked hosted chair detected |
| Causal repair and final-report fixture | 0 | 18.292 s | Inherited failure preserves later Cabinet; one, two and three actual blockers repaired; returned reports match independent final checks |
| Causal repair fixture on the current working tree | 0 | 55.569 s | Final report and furniture-preservation controls also pass with the unfinished live building candidates |
| Floor-seat fixture on the current working tree | 0 | 26.912 s | Hosted/unhosted, blocked-zone, elevated and mounted controls pass |
| `lane:house-plan-fast` | 1 | 214.766 s | 270 checks, 25 failures, 33 warnings; planning suite passes all 56 checks |
| `lane:house-furnish-fast` | 1 | 235.915 s | 232 checks; assembly 95 and furnishing 93 pass; existing Romanesque overlap failure remains |
| Exact innkeeper room renders | 0 | 32.224 s | Eleven views, every planned model assembled, source hashes unchanged |

The planning baseline had 26 failures and 32 warnings. Exact complaint comparison finds only the old tucked Stool complaint removed and one honest dining-table compromise warning added. The eight new bedroom-stowage and three light complaints introduced by the checker-only attempt are absent with causal repair. Other baseline failures, including bedside arrangement, sparse rooms, steep stairs, top approaches and guards, remain. The furnishing baseline has the same Romanesque 94-overlap/budget-92 failure. Its intentional disabled-daylight RuleSet negative emits `ERROR`; the native wrapper marks that header while the furnishing suite itself passes.

Production source fingerprints used for the isolated gates and images: NavCheck `420c5b57c46a7ab40d17ff90355a1ea80ca4dcff843f464132bff686556a54d8`; furnisher `7c3c2d76afb5225e6d5133dc82e542b71f50ef1dbd370e6af15d94ff6344575f`. The office activity check uses the separate unpromoted office candidate and the identical Nav checker. The index promotion reproduces the tested navigation/repair source changes and preserves unrelated working-tree edits. Focused fixtures also run on the actual working tree; these do not imply its wider unfinished candidates have passed their family matrices.

## Visual and functional limits

Root opened all eleven [earlier exact-case room and overview images](../visualQA/styles/house/townhouse/renders/nav_inventory_restart56/README.md). Their design status remains **needs_changes**. The bedrooms are repetitive and bare; the cupboard in room 9 stands free; the earlier compromised parlour was empty. Upper floors occlude the lower plan in the roof-off overviews. Retaining inventory is necessary, but does not produce an inhabited home by itself.

The existing stowage rule also counts a nightstand as clothes storage. Rooms 4, 8 and 10 retain bedside shelves without separate clothes storage. `LIVE-SLEEP-CLOTHES-STORAGE` records this design and QA gap. Architecture, stairs and room composition remain in their separate tasks.

## 9 October group-preserving repair

The exact innkeeper plan (13 x 16 m, two 2.9 m storeys, seed 32102) had one unreachable hosted Stool in room 1. The old candidate list excluded it, so global repair tried eight unrelated beds and then removed `Table_Large` with its hosted dining group. Repair now includes hosted floor-blocking pieces and appends named unreachable items beyond the bounded size cap. It prefers optional losses, complete repairs and smaller furniture losses in that order. In the exact native fixture, removing one optional Stool retains `Table_Large`, Bench and another Stool; 14/14 rooms and 33/33 use zones remain reachable.

The focused `tests/house_nav_group_repair_test.gd` passed with native exit 0. The first eleven-view capture is diagnostic only: its source hashes changed during an unrelated recipe edit. The [final twelve-view capture](../visualqa/styles/house/townhouse/renders/nav_group_repair_final_20261009/manifest.json) saved every requested image with native exit 0 and `source_changed=false`. Root opened the assembled parlour and overview images: the table and long bench are visible as a retained dining group; the end Stool is recorded in the measured placement inventory but its room portrait does not show it clearly. The final plan has 78 furniture pieces versus the earlier 68 and one additional honest `tuck` complaint for the restored Stool, 0.15 m into the table end. `HOUSE-DINING-SEAT-TUCK` owns that placement defect. The existing sparse rooms, cupboard placement, stair and floor-gap findings remain visible to their own tasks.

The bounded `lane:house-plan-fast` receipt finished native exit 1: planning passed 56/56 checks; multistorey reported 28 stair/furnishing/design failures and no unreachable-room or use-zone failure in the exact innkeeper case. `lane:house-furnish-fast` finished native exit 1: assembly passed 95/95; the four failures are one known Romanesque z-fight budget miss and the previously traced cottage/mediterranean missing-hearth and workbench-daylight complaints (tracked by `HOUSE-FENG-BOUNDED-HEARTH`). Neither lane is claimed green. Their logs are under `artifacts/personality/resumed/`.

Run the focused regressions with the executable named in AGENTS.md:

```powershell
godot --headless --path . --script res://tests/house_nav_hosted_floor_test.gd
godot --headless --path . --script res://tests/room_local_nav_guard_test.gd
godot --headless --path . --script res://tests/run_all.gd -- lane:house-plan-fast
godot --headless --path . --script res://tests/run_all.gd -- lane:house-furnish-fast
```

Use fresh logs and preserve native exits. The full scheduled family sweeps were not run for this bounded change.
