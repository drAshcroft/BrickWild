# LIVE-ROOMS evidence

Root reviewed the Luna implementation and corrected it through eleven focused
engine iterations. The accepted slice is room planning, not whole-building
design acceptance.

The frozen 18 cottage/witch requests have unfurnished plan sheets in `plans/`.
Four requests also have 16 assembled roof-on, entry, activity and cutaway
images in `assembled/`. Both manifests report `source_changed=false` and the
same script SHA-256. Original artifact image paths are retained in the
manifests; matching basenames are copied here. Tests ran in the working tree
with its existing walk-QA changes, which were not part of this todo's edits.

## Review

- Default cottage seed 8102 now has a hall leading directly to its kitchen
  and parlour. The bedroom is a private leaf beyond the parlour. The earlier
  route through two parlours to reach the kitchen is gone.
- Default witch seed 8102 has the same domestic access logic with a separate
  workshop. Its private room has daylight; the workroom no longer disappears
  during a windowless-room demotion. This is a reusable planning improvement,
  not proof of witch identity.
- Small cottage seed 1 keeps cooking, sleeping and a lived hall in three
  usable rooms. Optional separate sitting/work/storage rooms may be omitted;
  the plan records the omitted activities and rejected candidate reasons.
- Large witch seed 1 has six exterior side rooms opening directly onto a
  lived central hall. Sleeping rooms remain private. The hall needs several
  composed activities, not one isolated table. Furnishing is still inadequate.
- The assembled views confirm the partitions and openings exist. They still
  show sparse furniture, bare walls, and an excessively large witch roof and
  chimney. LIVE-GROUPS, LIVE-SURFACES and LIVE-WITCH remain open.
- Luna's remaining-sheet review confirms the small witch variants have no
  separate workroom, and default variants omit records/storage. Their shared
  living space must support witch work during the identity rollout. The large
  central hall currently reads as a gallery; its common geometry across styles
  is not accepted as final personality or furnishing.

## Checks and remaining failures

`focused.log`: 45 style/size/seed cases plus activity-fit, trade/custom-plan,
multi-storey privacy, fixed regression, negative-control and determinism
fixtures; zero failures and no script/parse errors.

The bounded planning lane completed in 100.89 seconds. Its planning suite
passed all 56 checks, including kitchen/rear-door and privacy regressions.
The whole lane is **not green**: the multi-storey suite has 57 failures,
versus 49 in the pre-change baseline. The failure sets differ, not just counts.
No planning/privacy failure remains; the remaining categories are listed
below and belong to the subsequent furnishing/threshold work. No check was
weakened to hide them.

| Failure category | Baseline | Current |
|---|---:|---:|
| Seat tuck / coherent seat kinds | 4 | 5 |
| Sparse furnishing / lighting | 8 | 15 |
| Cooking preparation surface | 2 | 3 |
| Bedside relation / bed-door | 17 | 16 |
| Furnished front-door approach | 3 | 1 |
| Stair pitch / head / guard / approach / headroom | 15 | 17 |

The narrow-room corner placement correction included here was separately
checked with both orientations and a legacy-code negative control. Its
earlier bounded furnishing lane passed 228 checks; that result predates the
new room layouts and is not a claim that current furnishing is accepted.
