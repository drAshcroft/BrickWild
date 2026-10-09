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

### 2026-10-08 — LIVE-GROUPS completed

Required domestic activity groups and safe light coverage are complete for the stated bounded coverage. Root reviewed 16 final room/cutaway images and two roof-on lighting views. All 232 original furnishing/assembly/walk-pin checks passed in split bounded runs; the combined lane timed out. The 15-case house matrix and two deterministic repeats passed. See `visualqa/personality/GROUPS_REVIEW.md`. Bare surfaces, porch intrusions, bulky bedside supports, legacy trade stairs and witch identity remain active design work.

### 2026-10-08 — LIVE-SURFACES completed

Wall hosts now follow surviving activity anchors. Reading binds a measured bedside support, supported book and useful task lamp; separate clothes storage remains required. Cooking binds preparation, heat, storage and task light. Floor-to-ceiling timber bays follow actual façade stations and clear opening spans. Root reviewed the Luna patches and critical saved views. All25 selected gates pass, including232 original furnishing/assembly/walk-pin checks,21 composition checks and1679 current component checks. Reviewed34 main renders and5 exactFarmhouse7441 views. Fixture-only cohort changes and earlier geometry/exterior lineage are recorded in `visualqa/personality/SURFACES_REVIEW.md`.

The rooms still have broad bare plaster, heavy repeated frames and hot light. Generic cottage/Witch identity and wider two-storey/trade defects remain work for the next todos. This is foundation completion, not final building-design acceptance.

### 2026-10-08 — Restart recovery and sacred entrance step

LIVE-SACRED-ENTRY closes the ziggurat ground-paving gap and retains two metres
of occupied first-chamber headroom. The focused emitted-mesh contract passes
45 cases, including removed-floor and injected-low-ceiling controls; the Temple
lane passes 3,737 checks. Root reviewed fresh roof-on axis and cutaway renders.
See `visualqa/personality/SACRED_ENTRY_REVIEW.md` for precise coverage and limits.

LIVE-WITCH and LIVE-SACRED remain in progress. The witch has distinct supported
craft groups and a lower work roof, but its front remains a generic cottage.
The compact work shelter still needs opening and threshold coordination. Fresh
sacred renders expose plain masonry volumes and incomplete dome/ambulatory
spaces. Successful image generation is not visual acceptance.

### 2026-10-08 — Render-camera checkpoint after computer restart

LIVE-RENDER-CAMERAS records the reproducible render tooling and actual reached
Witch eye-station selector. Four positives and a room-filling obstruction
control pass. Root reviewed fresh exact-pin Witch views and six-style church
captures. See `visualqa/personality/CAMERAS_REVIEW.md`. Witch identity and sacred
interior architecture remain open; sacred body clearance is explicitly
unmeasured. The complete frozen review matrices are retained.

### 2026-10-08 — Continued verification after the next computer restart

The compact Witch opening reservation now follows its actual left/right work
band. The unchanged three-seed service fixture passes (46.997 s), as does the
assembled shelter/threshold mesh fixture (18.216 s). The broader finish fixture
then exposed a generic cookware choice selecting a water bucket instead of the
required cooking pot for seed 21325. The scoped Pot_1 recipe now passes all nine
finish/light cases (136.796 s), compact service (49.555 s), threshold mesh
(21.893 s) and Workshop bay (15.874 s). Fresh exact-pin four-view capture passes
(46.324 s), but root still sees a generic tidy cottage. Visual identity is not
accepted. The shader's horizontal courses lack physical thatch bundles, and
the broad upper flue needs a purposeful proportion; those proposals are staged.

Native basilica hierarchy now includes the raised nave, lower aisles, supported
pronaos and real clerestory openings. Vertical gable slabs have actual normal
extrusion rather than flat in-plane thickness. The three-size structural fixture
and its controls pass (52.168 s); the focused basilica/Gothic public API check
passes 25 checks (27.532 s). The corrected Temple lane passes 3,737 checks with
zero failures or warnings (150.978 s). Root inspected all nine fresh three-size
blood seed1 renders (50.211 s): the nave, aisles and projecting entrance read as
deliberate architecture. Dark interiors, repeated braziers and the generic rear
spire remain broader design work. See `visualqa/personality/BASILICA_REVIEW.md`.
LIVE-SACRED-BASILICA is complete for this bounded architecture slice. The complete
quick API coverage passes in bounded processes; LIVE-SACRED stays open.

The full sacred structural fixture passes (112.977 s). Its crossing-tower control
now removes an actual bearing component while retaining the tower wall base.
Nordic timber has its own logical material slot. The obsolete four-surface
count is replaced with populated logical-slot checks; the church change lane
still needs its rerun. Its 12 existing opening warnings remain visible.

LIVE-API-PARTITIONS is committed as `18b5730`. All eleven exact canonical library
partitions pass, 195 checks, with a common unchanged source fingerprint. Each
native exit is 0 and each process is under 300 seconds; 702.046 s is the aggregate,
not a passing combined selector. The union validator and root rejection controls
for missing exit, NaN and duplicate rows pass. The original 300.727 s library
timeout remains incomplete evidence. See `docs/API_QUICK_PARTITIONS.md`.

LIVE-API-SCENE-LIFETIME is committed as `fccfae2`. Five temporary WindmillSuite
scenes were never freed: 264 passing API assertions still produced renderer exit
ERRORs. Null-guarded scene cleanup preserves every assertion; the same four
remaining API suites now pass all 264 checks, native0/153.899 s, with clean output.
LIVE-PLACEMENT-PARTITIONS is committed as `406b12a`. All thirteen bounded
processes pass 31 checks and preserve the eighteen original coverage markers
(434.399 s aggregate, 95.811 s maximum). Source stability and rejection controls
pass. Together with the library partitions and four remaining suites, this
retains all quick API-lane coverage: 490 checks. The original combined placement
selector timed out at 300.952 s; it is not reported as a pass. Scheduled sweeps
and final family design acceptance remain separate.

### 2026-10-09 — Continued after computer restart

LIVE-SACRED-CHURCH completes the bounded occupied-structure slice. Real nave
frames, dome bearings, open ambulatory paving/roof and Nordic timber surfaces
are verified. Later dome painting now respects logical material slots; the wall
emitter honors its requested wood surface. Fresh upward renders exposed another
defect: a string course was a solid slab across the whole nave at 62% of wall
height. It is now named perimeter trim split at actual nave/tower openings.

The full structural fixture passes (native0, 74.227 s), including 48 course cases
and the exact former slab as a negative. Church lane plus aperture checks pass
5,796 checks (45.555 s), retaining 12 warnings; VIS-008 passes 47 checks (5.377 s).
All eleven geometry-lane selectors pass in three bounded processes: 9,633 checks,
627.298 s aggregate, each below 300 s. One overlapping bounds process was stopped
and excluded; its fresh serial replacement passes. The selector fixture passes
(9.426 s) and an exact CLI seed8102 public capture passes (14.921 s).

Root opened all 18 original six-style images and six supplemental upward views.
The frames and dome interiors are exposed instead of hidden by the accidental
ceiling. This is structural acceptance, not complete style acceptance. Plain
walls, high small windows, pale Nordic timber, repetitive furnishing and cutaway
trim visibility remain design work. Body clearance is unmeasured; the original
234 requests and 702 images remain frozen. See
`visualqa/personality/CHURCH_STRUCTURE_REVIEW.md`.

LIVE-WITCH remains open. Its scoped physical thatch bundles and narrower flue
parse and render, but the first mesh fixture found floating-point boundary
measurement failures. A tolerance correction with a real undersized-envelope
negative is staged. Root opened all four fresh exact-pin images; the high gable
and tiled-looking roof still read as a generic cottage. A scoped roof/material
revision is staged and unverified. No Witch identity acceptance is claimed.

LIVE-SACRED-ROTUNDA records the next bounded form repair. The artifact proposal
has a circular occupied drum, connected threshold and a real bearing gate head;
its source and fixtures have not yet been run. Parent LIVE-SACRED and the wider
house, shop and family rollout remain in progress.
