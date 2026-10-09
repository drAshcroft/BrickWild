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

### 2026-10-08 â€” LIVE-GROUPS completed

Required domestic activity groups and safe light coverage are complete for the stated bounded coverage. Root reviewed 16 final room/cutaway images and two roof-on lighting views. All 232 original furnishing/assembly/walk-pin checks passed in split bounded runs; the combined lane timed out. The 15-case house matrix and two deterministic repeats passed. See `visualqa/personality/GROUPS_REVIEW.md`. Bare surfaces, porch intrusions, bulky bedside supports, legacy trade stairs and witch identity remain active design work.

### 2026-10-08 â€” LIVE-SURFACES completed

Wall hosts now follow surviving activity anchors. Reading binds a measured bedside support, supported book and useful task lamp; separate clothes storage remains required. Cooking binds preparation, heat, storage and task light. Floor-to-ceiling timber bays follow actual faÃ§ade stations and clear opening spans. Root reviewed the Luna patches and critical saved views. All25 selected gates pass, including232 original furnishing/assembly/walk-pin checks,21 composition checks and1679 current component checks. Reviewed34 main renders and5 exactFarmhouse7441 views. Fixture-only cohort changes and earlier geometry/exterior lineage are recorded in `visualqa/personality/SURFACES_REVIEW.md`.

The rooms still have broad bare plaster, heavy repeated frames and hot light. Generic cottage/Witch identity and wider two-storey/trade defects remain work for the next todos. This is foundation completion, not final building-design acceptance.

### 2026-10-08 â€” Restart recovery and sacred entrance step

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

### 2026-10-08 â€” Render-camera checkpoint after computer restart

LIVE-RENDER-CAMERAS records the reproducible render tooling and actual reached
Witch eye-station selector. Four positives and a room-filling obstruction
control pass. Root reviewed fresh exact-pin Witch views and six-style church
captures. See `visualqa/personality/CAMERAS_REVIEW.md`. Witch identity and sacred
interior architecture remain open; sacred body clearance is explicitly
unmeasured. The complete frozen review matrices are retained.

### 2026-10-08 â€” Continued verification after the next computer restart

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

### 2026-10-09 â€” Continued after computer restart

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

### 2026-10-09 — Restart8 review and native diagnostics

The scoped Witch half-hip and continuous reed shader are promoted for testing,
not accepted. Root opened all four fresh exact-pin views (native0, 23.017 s).
The roof has changed but still reads as a conventional timber cottage. The
focused fixture fails nine cases (10.354 s): end rafters enter the roof skin,
and a component counter confuses individual rafters with complete frame sets.
A corrected physical contact proposal is being reviewed. The original Witch
48-image matrix and broad design acceptance remain required.

A separate Workshop fixture measurement is repaired: its old roof-top ray
minus half depth measured the roof middle plane rather than its underside.
Actual oriented roof/ceiling triangles agree within 2 mm. A physically raised
ceiling rejects the same contact check, and actual underside headroom now
passes all fourteen existing cases (native0, 12.140 s). Its earlier parse-error
receipt remains invalid evidence. No ceiling geometry was moved for this fix.

The circular Rotunda drum, crown, actual gate head, conservative navigation
floor and pit-split perimeter slabs are promoted. Root caught and rejected
floor rows that filled the pit before promotion. The corrected native fixture
still fails 1,109 checks (23.292 s): rectangular mass rules misread adjacent
curved walls, while actual gate, floor-edge, route, pit/dais and lantern-removal
failures need repair. Root opened all three fresh diagnostic public images
(native0, 16.587 s). They show a circular room and the ritual pit crossing;
plain walls and generic silhouette remain broader identity work. Read-only
mesh/WalkGrid probes pass (5.220 s); a cross-cult pit probe (1.603 s) locates
real small Flame/Bone dais slabs across the pit. No Rotunda acceptance is claimed.

Church support-aligned openings and style sections remain an artifact proposal.
Root requested removal of duplicated exterior piers at existing buttress
stations and a bounded test queue. No new Church source has been promoted.

## Restart 9: measurement committed, architecture still under review

Computer restart recovery retained all uncommitted work. Commit c465003 closes LIVE-MESH-SUPPORT-EDGE only: inclusive actual triangle support passes239checks through2km translations,43world consumer checks and the full sacred structural fixture. It moves no geometry and does not close Rotunda or Witch design.

The clipped Witch timber proposal parses after root renamed one duplicate local. Its native run fails27checks in11.931seconds. Hip supports have no selected upper-face samples, physical tie bearings fail, and the detached control has an inverted expectation. The proposal is not accepted.

LIVE-SACRED-CHURCH-BAYS is executing. Root rejected regional triangle deletion and requested exact named-component multiset removal. The revised three-source packet is promoted. Its full fixture fails64checks in69.853seconds: the wall-preservation witness incorrectly requires a large wall-triangle centroid inside a narrow support box. No other failure is reported in that receipt. Root requested a physical wall witness and retained exact component removal. Church change lane is running.

Root rejected Rotunda overlap-check suppression. The next packet must measure actual oriented walls with physical seam allowances, preserve other overlap pairs, and exercise emitted overlapping geometry as a negative control. Its architecture and cult identities remain open.

## Restart 13: final church bay review and circular diagnostics

Commit a8fd54d completes LIVE-SACRED-CHURCH-BAYS. The full structural fixture passes (86.424 s), Church change/aperture coverage passes 5,796 checks (30.900 s, 12 existing warnings), and VIS-008 passes 47 checks (5.172 s). All eleven geometry selectors pass 9,633 checks in the isolated c465003 checkout, split into three serial bounded processes (347.195 s aggregate). The live combined roof attempt failed unrelated Rotunda assertions and is excluded. Root opened all 18 final original renders (46.656 s) and all six vault views (23.006 s). Bay geometry is accepted; full sacred style identity remains open. See visualqa/personality/CHURCH_BAYS_REVIEW.md.

The pending arcade diagnostic reproduces real barriers: Gothic default seed 8102 has 14 of 16 interface rays blocked (native0, 1.750 s). The two clear nested-ring west probes are not proof of a route because shell extents need checking. Luna is strengthening body, floor, route, crown and removed-bearing controls before promotion.

The final Witch physical frame repair now passes its four focused gates: half-hip contact including the same raised/detached predicates (12.907 s), roofcraft (15.926 s), legacy gable (7.910 s), and all fourteen Workshop bay cases (9.227 s). This supersedes the earlier physical failures, but the exact-pin renders still do not establish Witch identity. A connected Kitchen/Workshop lower wing is staged; root rejected a hard-coded 9 x 12 layout guard and requested a capacity-based procedural rule and furnished diagnostics.

Rotunda v4 was promoted for validation. Root fixed one inferred Vector2 parse error. The focused fixture fails 125 complaints across all fifteen canonical cases (native1, 39.258 s): altar/platform fit, actual jamb-panel overlap, lighting, procession/bridge access, lantern bearing datum and two floor-removal controls remain unresolved. The independent roof quick diagnostic retains 4,170 checks and fails six lantern attachment witnesses (61.537 s); exact circular dome/annulus grid, added-slab and removed-roof controls pass. No Rotunda completion is claimed. Luna is staging measured diagnostics and a focused repair against this exact live source state.


## Restart 18: arcades committed; public threshold diagnosis corrected

Commit9938683 closes LIVE-SACRED-CHURCH-ARCADES. Actual body-height/lateral rays, floor continuity, crowns, exact component bearings and same-predicate plug controls pass. Church-change5561, apertures235 and dome47 pass; all9633 original bounded geometry checks pass in three serial isolated processes (346.804s aggregate). Root opened18 original plus6 vault images. Renaissance side aisles are now visible through the nave wall; blank upper walls, generic exteriors and repetitive seating remain. See visualqa/personality/CHURCH_ARCADES_REVIEW.md. This does not complete sacred identity.

Committed baseline house diagnostics reproduce42 older complaints. The three Cottage failure lists are unchanged by the Witch ell proposal; new Witch roof/placement complaints remain separate. LIVE-HEARTH-MESH-CONTRACT tracks exact hearth geometry/material measurement and must preserve genuine collision rules.

Root rejected a Rotunda v5 regression that would reconstruct all authored column dimensions. Luna's revised packet preserves non-Rotunda records and filters surviving Rotunda records by their own radii. It remains staged and unverified.

The furnished public Witch service-door lifecycle diagnostic currently contradicts the earlier missing-door premise: completed cases retain exactly one marker through planning, furnishing, shell refresh and BrickWild.generate. The existing yard renderer focuses a shelter/yard cluster instead of the actual threshold. No guessed door-search repair is promoted. Full native matrix and strengthened real mesh controls are pending. Witch identity remains visually rejected; a roof derived from actual tall-core rooms is still being staged.

## Restart 19: floor seam committed; design acceptance stays separate

Commit53ea8e5 completes the hearth mesh measurement task:78 controls pass, the full committed surface-host consumer passes, and exactly24 false face probes disappear while the other18 baseline complaints remain identical. Root opened all three corrected hearth portraits. Visible fire and domestic composition remain open.

Commit689f26d completes LIVE-WALK-FLOOR-EDGE. Six floor/hazard controls and43 world support consumers pass. All five large Rotunda routes recover with2.72m processional clearance. Planning56 checks pass. Comparing the same isolated house-plan/walk-pin consumers with unchanged floor code gives exactly the same28 failures and32 warnings. The old multistory furnishing/stair complaints and sacred coplanar surfaces remain explicit work; no full consumer pass is claimed.

The twelve-request public Witch service-door baseline passes native0/185.071s with exactly one retained marker on every Witch and none on Cottage controls. The stronger removed-wall/door fixture and corrected service-yard camera are promoted for verification; no speculative production door repair is included. The plan-derived high-core roof candidate fails8 requirements in6.597s. A corrected native diagnostic (6.397s) shows the bay candidate exists but its near-eave join cannot supply the required fall/headroom. Luna is repairing the geometry; all coverage and headroom guards remain.

Rotunda v6 passes all15 canonical native cases including physical mutations (38.331s), public API focus31 checks (14.774s), rite60 and roof4176 checks. The broader temple suite reports10 brazier/panel AABB intersections; actual oriented clearance and a moved-bowl negative are being verified. Root opened all nine blood-cult size renders (29.409s). The drum, pit crossing and altar are clear, but the exterior is plain and the large room remains too empty. Sacred identity and the full matrix remain open.

The ordinary hearth assembly proposal is promoted for verification. Its first fixture is invalid because scene-global transforms were queried before tree entry; root stopped only its owned process. Luna staged a deferred-start fixture with cached transforms. This invalid run is excluded from acceptance.

## Restart 20–21: Basilica bearings committed; inhabited design remains open

Computer restart recovery preserved the inherited working tree. Commit 2aae811 completes LIVE-SACRED-BASILICA-EAVES only. An isolated committed-baseline candidate passes all eleven geometry selectors (9,633 checks, 214.207 s), Temple/rite (3,737 checks, 40.495 s), actual bearing removal controls and edge-mapping controls. Root opened all nine fresh Basilica size/view renders. Roof and pilaster contacts are accepted. Bare walls, sparse sacred composition and the parent style identity are still open. The walk-pin lane retains its independent Romanesque coplanar failure (94 pairs against a 92 budget); no full walk-pin pass is claimed.

The twelve public Witch service-door requests pass actual body-width/height rays and retained-log wall/door mesh mutations (96.379 s). The roof datum fixture passes fourteen cases plus six scope controls (7.646 s). These are structural receipts, not Witch identity acceptance. The exact default/seed1 four-view render still reads as a tidy timber house and shows a broad Workshop gable sky opening. The ceiling extension does not close that opening: its focused gate retains two failures (7.131 s). A valid actual-triangle diagnostic locates the eye ray beyond the ceiling end, through the missing gable infill. Luna is repairing the emitted wall profile, with same-eye removed-wall controls required.

The Witch yard fixture retains nine failures (62.456 s): six default/large plans omit the required shelter, and all three compact plans put drying too far from the work threshold. A complete candidate trace (41.668 s, no script errors) identifies canopy roof rejection by the door/porch clearance reservation; compact drying candidates are rejected by the door or other yard pieces. Clearances remain requirements. Luna is staging a measured layout repair.

The first ordinary shell-host hearth revision fails twelve missing Pot_1 requirements and is visually rejected in all 24 reviewed renders. The exact cause is now repaired: prep heat reach scanned furniture hearth rows, while the native fireplace has no proxy furniture row. A narrow measured structural-breast fallback passes the focused two checks (3.933 s) and all twelve retained fireplace cases (430 checks, 43.751 s). The hearth todo remains executing: cone-like flame geometry, undersized fuel and sharp rectangular soot need composition work, and every fire must be checked against an actual emitted chimney outlet. No hearth design commit or acceptance is claimed.

The revised Witch exposed-eave/local-flue packet is promoted for verification. The first two attempts have parse errors and are excluded. Root corrected explicit inferred numeric/vector types; the fresh physical run is pending. Chapel threshold and Pylon structure proposals remain unpromoted. Full Rotunda public API coverage, cross-family style review and the complete inherited plan remain required.

Restart21 continuation: roofcraft passes after explicit type fixes (13.967s after deriving layout/openings once, versus141.598s before). The unchanged full nine-case half-hip scope and actual nonempty raised-rafter controls pass79.736s; the corrected independent actual-triangle core flue oracle passes8.728s. Two gable infill candidates still fail the same three recorded eye rays and unchanged-log deletion witnesses (9.017s and10.416s). The actual high-core roof-wall run omits the whole outboard Workshop span; Luna is extending the emitted lower-wing end wall from real house/bay bounds.

The shelter revision now retains default shelters, but its complete native gate remains red with nine requirements (43.005s): compact drying, default nearby herbs, and all large shelters. Root opened all four fresh exact default1 views (28.956s). The service work entrance is clearer, but its long bare awning, empty bench, crowded Workshop chests and tidy-cottage front remain visually unacceptable.

LIVE-SACRED-PYLON is executing. Its first full native45 request gate fails195 assertions (28.387s). A valid three-size diagnostic (4.673s) proves the beam support probe was wholly inside the actual seated beam; large tower geometry and shrine/column overlap still require repairs. Root opened all nine blood seed1 size/view renders (26.041s): hall and restricted shrine are clearer, but exterior remains blank boxes. No Pylon completion.

The ordinary fireplace actual-outlet trace fails12 requirements (28.990s): eight Cottage/Thatched Cottage generated plans have no chimney despite native indoor heat; four Farmhouse outlet witness/removal controls need precise actual ray diagnosis. Derived chimney choice must be resolved consistently with required cooking heat before accepting hearth design. Visual firebrick/faded-soot revision remains staged, not accepted; root caught its inherited half-height flame offset, which would float mesh tongues above the logs. No further todo is complete; no new commit is justified yet.

Restart21 resumed root review: the actual outboard Workshop end gable now passes the complete bearing/closure fixture (7.511s). Root opened all four exact default/seed1 views (20.832s) and confirms the former sky triangle is closed. The Witch identity, service cluster and furnishing are still rejected. Large shelter operation containment has valid read-only diagnostic receipts at31.040s and29.831s; the attempted v4 helper call failed to load and is excluded.

The ordinary native flue passes all twelve actual outlet/removal cases (28.293s) and all eight exclusion cases (16 checks,9.953s). The revised fireplace assembly fails26 of466 assertions (38.989s), including all backing witnesses and fuel scales plus two removed-backing controls. Root rendered and opened every one of24 fresh hearth/exterior images (69.524s): visible firebrick joints and soot are absent, the fire remains two paper-like tongues over a tiny fuel block, and large exteriors still have disproportionate roof/stack silhouettes. This revision is rejected. No task is completed and no new commit is justified. Pylon's next source-only proposal was also rejected before promotion because its surface probe was wholly inside stone and its short portal placed the lintel below the ritual line. These are repairs in progress, not acceptance receipts.
