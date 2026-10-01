# INT-008 Barracks Acceptance

The barracks source was prepared in `artifacts/int008_reconcile_worktree` and
integrated into main after CAS-010. The main runner preserves the fast QA lanes.

## Checks

All commands used the local Godot 4.5.2 executable and wrote stdout, stderr, native exit, and engine logs under `artifacts/int008_reconcile/`.

On main, `tools/run_qa_lane.ps1 shop,barracksquick` passed in 38.4 seconds:
native exit 0, 2 suites, 28 checks, 0 failures and 0 warnings. The focused
barracks fixture checks 70/100/140 percent sizes through HouseQA and runs
negative controls for missing weapons, seats and misplaced rows. Log:
`artifacts/qa_fast/shop__barracksquick/20260930_173219/`.

The full `shop,sarchetype` run reached the routine 300-second cap while in
`sarchetype`; its exact Godot process was stopped. Log:
`artifacts/qa_fast/shop__sarchetype/20260930_172643/`. Its green clone
result and the 100-seed barracks result below remain breadth evidence, not
claims that those sweeps passed on the integrated source.

| Run | Native exit | Result |
| --- | ---: | --- |
| `shop` | 0 | 21 checks, 0 failures, 0 warnings |
| `sarchetype` | 0 | 60 checks, 0 failures, 6 warnings |
| `barracks100` | 0 | 100 seeds, 0 failures, 0 warnings |
| `lane:plan` | 0 | 3 suites, 386 checks, 0 failures, 1 warning |
| `lane:dress` | 0 | 4 suites, 1,170 checks, 0 failures, 32 warnings |
| non-headless render | 0 | both PNG writes returned error 0 |

The planning lane's single warning is the existing disconnected 1.2 m2 townhouse floor report in the multi-storey fixture. The furnishing lane's warnings are existing archetype, affinity-coverage, and furnishing reports; none were failures. The 100-seed barracks QA is clean.

## Render inspection

- `artifacts/int008/barracks_cutaway.png`: assembled 18 x 28 m barracks cutaway. The office, mess tables and benches, weapon stands, and dormitory bed rows are all visible. The broad view also shows substantial circulation floor between the programme areas.
- `artifacts/int008/barracks_cutaway_opposite.png`: opposite angle confirms the second sides of the room layout and repeated furnishing rows. Both images are real Vulkan renders from the owned prop assets.
- `artifacts/int008/barracks_dormitory_detail.png`: close view shows six beds in one line and five in the return row. The render script matches every planned bed position to an assembled furniture node; it reports 11 of 11 instances present. The row placement is visible and clear from this angle.

Main regenerated all three images with real Vulkan rendering: native exit 0
in 11.8 seconds, all PNG writes returned error 0, and the assembly reported
11 of 11 planned beds. The images were inspected on main; bed rows and aisles
are visible. Log: `artifacts/int008_main/render.*`.

## Integration notes

The exact `chimney` equality in the forge test is needed because the current builder logs `chimney_breast` as well as the actual `chimney`; prefix matching counted the breast as a second chimney. The internal focus fixture calls `HouseFurnishAffinityCheck.check_focus`, the current owner of that check after the API refactor on this source snapshot.

The `barracks100` runner registration is intentionally a small separate hunk in `tests/run_all_impl.gd`: add `"barracks100"` to `EXTRA`, and add `"barracks100": return ShopArchetypeSuite.run_barracks_seeds(100)` to `_run_one`. Preserve the current `tests/run_all.gd` wrapper and existing `sarchetype` registration when integrating.
