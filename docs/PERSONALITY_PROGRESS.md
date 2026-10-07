# Personality implementation evidence

2026-10-06, America/Phoenix. This records implementation evidence, not visual
acceptance of the buildings.

## Execution checkpoint after the implementation request

The user requested reviewed Luna implementation, rendered verification and a
commit after each completed todo. Work is now executing that backlog.
`visualqa/personality/` preserves the full ninety-request seed/size matrix,
81-row style inventory and 109-pin evidence ledger. The design plan now
includes labelled proposed witch-hut room relationships and roof/silhouette
direction. These are briefs, not claims of completed architecture.

A ten-case development render batch generated all nine public families plus
the witch hut, with forty images. Its manifest reports `source_changed=true`:
agents were editing during generation, so this is a development observation,
not an immutable before/after snapshot. Root review and camera limitations are
recorded in `visualqa/personality/README.md`. No family is visually accepted.

`LIVE-BRIEF` and `LIVE-ASSETS` are complete and separately committed as
`57658a3` and `47f85ae`. This completes the briefs and asset audit, not the
building designs. `LIVE-ROOMS` is now complete as a planning foundation; its
evidence and remaining design limitations are in
`visualqa/personality/room_evidence/README.md`. All subsequent implementation
and final style review tasks remain open.

The activity-led planner is under review. Root's first actual engine runs
caught type-inference parse errors, then bedroom-through-route defects and
compact layouts falling back to legacy subdivision. A stronger dining-group
fixture also initially mistook a placement probe for committed chairs; that
test itself is being corrected. Native exit 0 and a printed zero-failure
summary are not sufficient when the engine log contains script errors.
These intermediate failures are not accepted completion evidence.

The ninth focused fixture passed all 45 style/size/seed cases, but the wider
planning lane then exposed new farmhouse privacy and kitchen service-pole
failures. Its 270 checks had 61 failures, compared with 49 baseline failures;
the detailed failure sets differ and the counts alone do not establish
regression safety. Root also found a rendered plan with two parlours, one
silently demoted from a bedroom with stale activity metadata. `LIVE-ROOMS`
remained executing while these were corrected. Intermediate evidence is under
`artifacts/personality/current/focused9.log` and
`artifacts/qa_fast/lane_house-plan-fast/20261006_225512/`.

The final focused fixture passes, including the added farmhouse privacy
regressions. The final planning suite passes 56 checks. The whole bounded lane
still reports 57 furnishing/stair failures against 49 baseline failures;
the evidence README classifies the differences rather than calling the lane
green. Eighteen plan sheets and sixteen assembled views were rendered from
stable sources. Root and Luna reviewed them. Private sleeping access and
direct kitchen access are improved; bare rooms, gallery-like large halls and
weak witch identity remain explicitly assigned to the next tasks.

The asset audit now has actual model boards rendered through the existing
assembler at measured scale. Root reviewed the cooking, sleeping, sitting,
witch-work and wall/light palette. No catalogue or imported asset changed.
See `INHABITED_ASSET_PALETTE.md` for approved current candidates and honest
gaps. Stair, landing and guard work is in progress separately.

## Historical first increment (superseded by the execution checkpoint)

- The design briefs now map all nine public families, their styles, purposes
  and world sub-kinds. See `BUILDING_PERSONALITY_BRIEFS.md`.
- `tools/personality_inventory.gd` reads the public descriptor API and saves
  a source-revision/script-fingerprint snapshot. The current catalogue has
  **81 style rows across nine families**, counting shared house/shop styles
  in each family. Every row starts explicitly unreviewed.
- Ordinary house style data can now declare its domestic room programme.
  Farmhouses include work space, townhouses include a parlour and office,
  and witch huts include a workroom and records/book storage. Cottage keeps
  its existing household programme. Explicit trades retain their legacy base
  programme and trade-room promotion; custom family programmes remain
  supported. Other styles currently use the legacy
  programme; their personality work remains open.
- Sleeping takes priority over optional personality rooms. The initial
  townhouse/witch ordering could consume the room needed for a bedroom;
  the default-size generated-plan fixtures now guard against that mistake.
- A public-API renderer saves request metadata and paired exterior/cutaway
  views, supports published family/style selection, and returns failure for
  failed generation, assembly or image writes.

At this earlier checkpoint, the programme change did **not** change the rectangular subdivision method,
create a new silhouette, or deliver a fully furnished activity group. Those
are still required parts of `LIVE-ROOMS`, `LIVE-GROUPS`, `LIVE-SURFACES` and
the style rollout tasks. `LIVE-BRIEF` was also in progress: all-family
renders and first-person review are not yet complete.

## Current visual evidence

`artifacts/personality/houses/manifest.json` records five seed-1 public house
requests and ten images, with the exact source revision and script hash.
These were captured after the programme change and before the narrow-corner
placement correction. They are baseline images, not before/after comparisons
and not a replay of every historic pin. The roof-on camera shows a rear/side
elevation; the cutaway is an elevated overview, not a walking view.

Direct inspection of the farmhouse, townhouse and witch-hut cutaways shows
large plain wall surfaces, sparse furnishing and similar rectangular spatial
patterns. The witch-hut exterior still resembles the cottage strongly despite
its steeper green roof. This is evidence that the remaining composition and
architecture work is necessary. None of these styles is marked visually
accepted. A room named `workshop` is not proof of a convincing workroom.

## Reproduce

Use the Godot executable in `AGENTS.md`. Redirect engine logs to disk.

```powershell
godot --headless --path . --script res://tools/personality_inventory.gd
godot --headless --path . --script res://tests/house_personality_test.gd
godot --path . --script res://tools/render_personality_baseline.gd -- family=house seed=1 out=res://artifacts/personality/houses
godot --path . --script res://tools/render_personality_baseline.gd -- family=church style=gothic seed=8102 scale=small out=res://artifacts/personality/gothic_small
```

The renderer accepts `revision=` and `fingerprint=` from the inventory for
provenance. Use separate output directories per seed/size/family; otherwise
the files are deliberately replaced. `family=all` includes expensive families
and is not a routine check. Valid family/style selection is supported, but
only the five-house default render set has been exercised in this increment.

The focused fixture checks 24 generated plans (four styles, three fixed seeds,
default and large footprints), their ordinary plan checks and deterministic
repeats, plus trade promotion, tiny-home adaptation, upstairs sleeping and
custom-family preservation: **28 cases passed**. This is mechanical evidence,
not an identity score.

Two further fixtures now force corner storage to slide around occupied corners
in narrow rooms, in both orientations. Storage remains against a long wall
instead of sliding along an end wall into the walking strip. The focused
fixture now passes **30 cases**. This placement correction was prompted by a
new loose kitchen crate found in the direct townhouse comparison, even though
the bounded furnishing lane passed.

Before the code change, `lane:house-plan-fast` completed 270 checks with
49 failures and 29 warnings (292.22 seconds, native exit 1). The 56 planning
checks passed; the 214 multistorey checks reported existing stair/access/
furnishing defects. Baseline logs:
`artifacts/qa_fast/lane_house-plan-fast/20261006_212222/`.

The programme-change planning gate completed in 164.39 seconds with the same 270 checks,
49 failures and 29 warnings. The failure messages match the baseline exactly
(`artifacts/personality/planning_comparison.json`). The ordinary 56 planning
checks still pass. Logs:
`artifacts/qa_fast/lane_house-plan-fast/20261006_213817/`.

An intermediate attempt applied domestic style programmes to explicit trades
too. That added a seating failure to the innkeeper townhouse. The final guard
restricts the overlay to `trade=none`, preserving established trade behaviour;
the focused fixture now checks that an inn does not acquire the domestic office.

Before the corner-placement correction, `lane:house-furnish-fast` **passed 228 checks**, native exit 0, in
145.60 seconds. Its two warnings say the bounded sweep did not exercise
`table_focus` or `table_face`; do not infer coverage of those relations from
this run. Logs:
`artifacts/qa_fast/lane_house-furnish-fast/20261006_214116/`.

The direct seed-1, 9x12 comparison uses the original generator from `HEAD`
without modifying the working source. Original furnishing failure counts were
farmhouse 5, townhouse 5, witch hut 8. After the programme and corner-placement
changes they are 3, 3 and 6 respectively; navigation reports zero failures for
all three in both versions. This is improvement of specific defects, not a
complete furnishing pass. Raw reports:
`artifacts/personality/furnishing_before_corner_fix.json` and
`artifacts/personality/furnishing_comparison.json`. The latter's `baseline`
column reruns the legacy programme with the corrected shared corner placer;
use the former's `baseline` column for the original full behaviour.

Remaining direct-fixture complaints include mixed seating, missing kitchen
preparation surfaces and remote bedside storage. They belong to the complete
activity-group and placement work already queued. The witch hut's existing
bedside complaint moves from 0.86m to 0.87m; a smaller failure count does not
mean every distance improved.

After the corner correction, the final furnishing gate again **passed all
228 checks**, with the same two coverage warnings, native exit 0, in 195.28
seconds: `artifacts/qa_fast/lane_house-furnish-fast/20261006_214904/`.
The planning comparison above predates this placement-only correction; it
establishes the programme change's baseline, not a later full-suite pass.

The narrow-corner fixtures were also replayed against the original placer
from `HEAD`: both orientations report storage in the walking strip. The
corrected placer passes both unchanged fixtures. Evidence:
`artifacts/personality/corner_negative.log` and `corner_positive.log`.

## LIVE-THRESHOLDS implementation and review

The converted domestic room grammar now reserves a full stair run, integer
steps, end landings and a continuous 0.9 m carrying route before furniture.
Flights use the finished floor datum and emit inclined rails, intermediate
rails and guards around the upper opening. An infeasible stair is recorded
explicitly and emits neither a flight nor a navigation edge. Interior doors
in ordinary houses provide 0.95 m nominal width and 2.1 m finished headroom.

Stacked floors use their actual envelopes, including the townhouse projection.
Door and landing clear floor can be shared; flights, wells and their guards
cannot. The render review also exposed an exterior window hood projecting
into a wall stair. Its outside profile is retained with its inner face now
flush with the wall. Mounted furnishings are checked using their measured
assembled pose and the highest overlapping tread, rather than an inflated
plan rectangle.

Scope remains explicit. The 200-case distribution fixture reports 56 converted
domestic layouts and 144 legacy layouts, with no infeasible stair or plan-rule
failure. Of those legacy cases, 29 requests in the five converted styles still
fall back because their room programme cannot be packed; another 115 cover
the remaining styles. LIVE-HOUSE-STYLES retains this work. The broader furnished
multistorey gate still reports 30 furnishing findings and nine legacy trade
stair findings. These are outstanding design work, not accepted exceptions to
the final building-quality goal.

The existing human-pin QA work in the working tree is credited as the basis
for the stair and furnishing diagnostics. Its historical fixtures are adjusted
only where current measured behaviour disproves an old expected symptom.
The threshold mesh probe samples both directions, three lateral positions and
three body heights through actual assembled triangles. It supplements the
walking grid; it is not a continuous capsule-physics proof or a substitute for
the final human walk.
