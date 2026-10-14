# Todo and style-target review, 13 October 2026

The starting queue contained 13 pending and 3 executing tasks. The concept
boards in `visualqa/styles/**/targets` guide composition. They are not actual
renders or proof of physical correctness. Broad family tasks remain open until
their own complete matrices and critiques are addressed.

**Current result: eight focused todos complete; eight larger todos remain open.**
The current [gallery](../visualqa/styles/house/index.html) preserves 677 native
images with source hashes and scoped reviews. Geometry, furnishing, assembly
and the focused repairs have passing receipts. The broader planning and
interior-detail gates still fail; their exact remaining findings are below.
This is not a completed whole-backlog or whole-style acceptance.

The newer Witch recess and ordinary hearth composition have scoped physical
and visual acceptance. The original combined geometry and furnishing lanes
reached their time caps; their full suite sets subsequently passed in smaller
bounded processes. Those final receipts are recorded below. Broader style,
programme and family tasks remain active work.

## Witch fitted work areas — scoped visual repair, regression in progress

The six small/default Witch houses formerly placed their cooking benches
1.95 m or 1.33 m away from a supporting wall. The early paired cupboard/bench
path now checks the actual back edge against the actual wall in every
placement arrangement. Opposing runs use wall planes rather than arbitrary
aisle widths. The search includes measured minimum scales, wall ends and
obstacle boundaries. Each compact front-wall run divided by the entrance
keeps its own candidates until the complete cooking group has been replayed.

The small shared hall reserves a rear dining rectangle and uses the remaining
L-shaped space for cooking and brewing. Both working benches, water, storage,
the shared heat source, the meal group and private sleeping space remain
required. The cupboard/prep pair reserves a real water-vessel placement before
commit, and the complete group still passes the rasterized walking check.
This also fixes the mirrored seed-8102 kitchen that lost its bucket after
selecting a larger bench too early.

The window-clearance rule now reads the actual placement height. The measured
Cabinet at its supported 0.8 uniform scale fits under the 0.95 m sill; using
its raw full-size catalogue height gave a false failure. The independent
`house_scaled_window_clearance_test.gd` checks the imported model bounds in
four orientations and rejects the corresponding full-height models: 20 checks
passed in 18.02 s (`scaled_window_v2`).

The frozen nine-case fixture now also runs `HousePlanCheck`. Latest receipts
are under `artifacts/todo_completion_20261013/`:

| Receipt | Checks | Remaining failures | Host wall time |
| --- | ---: | --- | ---: |
| `witch_wall_prep_seed1_v10` | 80 | large Hall/records sparsity | 132.27 s |
| `witch_wall_prep_seed8102_v10` | 80 | large Hall/records sparsity | 176.51 s |
| `witch_wall_prep_seed21325_v10` | 80 | large Hall/records sparsity | 115.00 s |

All six small/default cases pass their full plan, furnishing, activity,
navigation, supported preparation-pot and physical recess assertions. The combined 240-check population
retains three failing cases, one per large house; every process therefore
correctly exits 1. There are no script errors. The remaining 91 m² Hall and
30 m² records room failures are not waived. The large building also still
reads as a broad regular mass beside the compact concept target.

`witch_wall_prep_matrix_v3` produced 78 images from all twelve requests,
including Cottage controls, in 427.87 s with native exit 0, no script errors
and unchanged source. Thirty images were inspected: nine working-room or
firebox views individually, twelve exteriors and nine cutaways in labelled
contact sheets. Forty-eight other images are preserved without a direct
review claim. Small-house benches now form fitted working areas on opposite
sides of the entrance. The larger masses remain visibly too broad and regular.

Additional kitchen portraits found that the random `Shelf_Arch` display rack
could consume the work area above a bench. Ordinary no-trade Witch kitchens
now use the measured short `Shelf_Simple` board and place one `Pot_1` on the
preparation bench instead of scattering cookware on the floor. The independent
pot-host assertion has been added to the nine-case fixture. The final
`witch_cooking_prep_v5` cohort contains six individual bench/cupboard views,
all directly inspected. It passed reachable-body, framing and clear-front
sight checks with unchanged source, native exit 0 and no script errors in
134.03 s. Earlier camera failures and the startup failure are retained in
their own receipts, not called passes.

Both cohorts are archived with source and image hashes. Matrix v3 precedes
the final short-shelf/pot recipe; the six-image v5 cohort records that newer
arrangement. Neither is final whole-style acceptance. Empty shelf boards,
dense bottle racks elsewhere, sparse large rooms and broad masses remain
design work. Final v10 seed checks are recorded above; broader bounded lanes are in progress.
`LIVE-WITCH` remains open.

## Townhouse writing place — complete

The old room view placed a chair at the bench end and the books beyond useful
reach. The ordinary, no-trade Townhouse recipe now centers its chair on the
long edge, positions the ledger and scroll from that chair's actual facing,
and places the records cabinet facing the work area. Other styles and family
recipes do not enter this rule.

The imported chair's seat plane is 0.5011 m above its floor. The scaled bench
top is 0.76075 m. `tools/measure_townhouse_writing_pair.py` now reads the same
named recipe constant that production uses. The fixture measures the real
bench triangles for knee space and rejects a chair shifted into a trestle.
It also rejects a ledger beyond reach, missing shelf support and blocked
chair access. The final focused run passed in 60.65 s, native exit 0.

Fresh public small/default/large renders are in
`visualqa/styles/house/townhouse/renders/writing_20261013_v2/`: 3 requests,
19 views, no render errors, unchanged source fingerprints, native exit 0,
109.46 s. The assistant directly inspected the two office portraits and two
office overviews against `rooms/work/targets/design_board_v1.png`. The desk,
chair, reachable work and nearby records now read as one activity. The small
request keeps its original programme without inventing an office.

This accepts the writing-place task. Plain interior surfaces, large empty
spaces and broader Townhouse architecture remain under `LIVE-HOUSE-STYLES`.

The bounded furnishing lane passed assembly and reproduced the known
Romanesque 94/92 overlap failure. It then timed out at 300.65 s during the
furnishing sweep. That interrupted lane is **not** a pass. Receipts and the
measurement are under `artifacts/todo_completion_20261013/`; the lane log is
under `artifacts/qa_fast/lane_house-furnish-fast/20261013_001734/`.

## Initial test-runner repair

The baseline Witch flue suite used inferred typing on a dynamically loaded
script instance. This prevented the entire suite runner from compiling,
including unrelated selectors. Explicit dynamic assignment repairs the
bootstrap. The first failed Temple run remains archived; it is not counted
as geometry evidence.

## Romanesque buttress course joints

The pinned public seed 1 had 94 visible coplanar overlaps against a budget of
92. Most came from shaft tiers running through the shoulder courses between
them. The shafts now end at a course underside and restart on its upper face.
The course envelopes stay in place. The resulting count is 12, and the budget
has been reduced to 12.

The focused course fixture passes six height/corner cases and a deliberately
duplicated-face negative control. The church-change and walk-pin gate passed
5,770 checks in 127.52 s with 12 existing opening warnings. After ratcheting the
budget, assets-fast plus walkpins passed 200 checks in 145.85 s, no warnings.

The final public seed-1 exterior, nave-axis and cutaway renders are now at
`artifacts/todo_completion_20261013/romanesque_v1/` (24.07 s, native 0).
All three were directly inspected; the stepped courses remain continuous.
`WALK-ROMANESQUE-ZFIGHT` is complete. The first generic house geometry lane
timed out at 300.31 s during roof-opening checks; it is not counted as a pass.

## Dining and clothes storage

The innkeeper's seat fallback tucked into a trestle end. Tucked candidates now
use long sides only. The innkeeper parlour explicitly reserves its table and
two matching seats together. The exact seed 32102 fixture passes navigation,
retained dining capacity and the tuck rule in 23.54 s.

The catalogue now distinguishes closed clothes storage from an open bedside
shelf. Capacity follows the real model and placement scale; QA derives the
clear opening/standing space. Ordinary bedroom recipes already required a
chest. Base-HouseSpec innkeeper guest rooms now pair the bed with its low
head-end stand and use the shallower closed Cabinet for clothes, without
changing the shared shop/hotel/custom-family recipe. The first storage-only
fixture missed beds removed during repair; the image review rejected it and
the strengthened fixture now requires every bed, its bedside surface, clothes
storage and access. It passes native and public innkeeper generation plus two
ordinary households in 57.07 s.

That image review exposed a second defect: the Cabinet showed its back. Its
actual imported metal handles and hinges lie on raw +Z; `face=PI` now turns
them toward the planned use zone. The strengthened fixture measures those
vertices in four rotations and rejects the former pose. It passes in 55.05 s.
The final public inn run is `innkeeper_20261013_v4`: 24 views in 30.07 s,
source fingerprints unchanged, native 0. All eight sleeping views, all eight
cupboard views and both parlours were directly inspected. The paired angles
retain beds, low bedside surfaces, closed cupboards and clear access. The
dining fixture passes again in 15.90 s; the writing regression in 50.76 s.
These are furnishing corrections, not approval of the plain room surfaces.

## Hearth fuel

Fresh baseline: twelve requests, 24 roof-on hearth/exterior images, native
exit 0, 132.67 s. The first split profile still looked like thin boards at the
room camera. The revised mesh has bark, broad cut faces, correctly wound end
caps and a thicker split body. Its pot support now clears the upper timber.
The thicker profile passes 1,174 assembly checks in 111.18 s, including
an upper log moved into the cooking pot as a negative control.

The final version also replaces broad conical flames with unequal narrow
tongues. All 1,174 assembly checks pass in 95.25 s. `hearth_split_v4` contains
12 requests and 24 roof-on hearth/exterior images, rendered in 115.77 s with
matching source fingerprints. Every image was directly inspected against the
saved cooking target. The fuel now reads as split timber and the pot has a
visible working fire. `LIVE-HEARTH-FUEL-READABILITY` is complete. The broader
domestic hearth task still includes the separate Witch cooking design.

The final assets-fast plus walkpins selector passes 200 checks in 65.08 s,
native 0, with no warnings. Image hashes, exact acceptance scope and remaining
visual limitations are in the cohorts' `assistant_review.json` files. The
house gallery preserves its prior sources and now indexes 371 actual images.

## Remaining work

The Temple ritual sweep passes all 60 cases in 216.39 s. The standalone Temple
contract sweep timed out at 300.39 s; no full Temple pass is claimed. Castle
interiors, navigation and the broad family/style tasks remain open.

The focused Rotunda architecture fixture now passes all 15 cult/size cases
in 119.35 s, including physical support and overlap removal controls. The
reported October 10 defect is already fixed in current production source;
`TEMPLE-ROTUNDA-ARCADE` is closed on that evidence. This does not turn the
interrupted full Temple contract run into a pass.

## Final gates for the focused fixes

The geometry rerun passes 9,730 checks in 252.69 s. The furnishing lane passes
237 checks in 187.33 s; its complete twelve-house feng-shui sweep has no
failures. Both return native 0 with no script errors or reported warnings.
Receipts are `artifacts/qa_fast/lane_geom/20261013_022859/` and
`artifacts/qa_fast/lane_house-furnish-fast/20261013_023312/`.

The exact cottage seed 60000 and Mediterranean seed 60006 fixture passes in
19.56 s. The remaining cottage defect was a table in the entrance approach.
Placement now keeps that solid footprint clear while allowing empty use zones
to share the approach. Native hearth validation also covers a combined
hall/kitchen, with missing-host and obstructed-entry negative controls.

Seven todos are complete: Townhouse writing, closed clothes storage, dining
seat tuck, bounded hearth/feng findings, fuel readability, Romanesque course
overlaps and the stale Rotunda arcade report. Larger style tasks retain their
own open acceptance criteria.

## Ordinary ceiling construction and material finish

Cottage, Farmhouse, Thatch Cottage and ordinary Townhouse now emit exposed
short-span joists against the actual room walls and ceiling undersides.
Shallower members preserve the small request's 2.2 m clear headroom. Upper
floor slabs also receive members below them; stair openings, hatches,
chimneys, high windows and tall or hanging fittings reserve their real space.
The focused fixture passes 16 rotated, small and multistorey households,
measuring 288 members against emitted wall/floor triangles, in 12.34 s.
Shortened and lowered members are negative controls.

The same four ordinary styles reuse the plaster finish and give imported wood
a restrained per-instance tint and grain strength. The imported textures,
metal and cloth remain shared originals. Actual-resource isolation checks
pass four ordinary styles and four specialist/trade controls in 11.55 s.
The first three-size material galleries show improved wood readability, but
large repeated masses and sparse rooms remain unfinished design work.

The first geometry lane after these additions timed out at 300.12 s during
`metriccoords` (`20261013_030918`). It is not a completed gate. Final floor
underside coverage and the subsequently discovered shelf correction require
fresh validation and renders.

## Witch ingredient shelf correction

Direct comparison exposed floating bottle groups above `Shelf_Simple` in the
existing Witch workshop views. The public seed-1 default and large fixture
reproduced four failed contacts against actual imported mesh triangles.
Placement had added the entire shelf height to its wall mount and used a
different horizontal origin from assembly. The repair uses the actual
assembled origin and the measured board support plane. QA now measures the
board footprint rather than treating the small mount reservation as its top.
The inflated-mount/overhanging-child negative passes in 3.42 s. The original
failed receipts remain alongside the corrected runs.

The corrected ingredient fixture passes all four bottle groups in 23.42 s;
raised bottles and lowered boards are rejected. Material isolation now covers
five styles, including Witch, and four specialist/trade controls: zero failures
in 10.03 s. Mounted-shelf support passes again in 3.31 s.

All 22 final Witch images in `witch_heat_{small,default,large}_v3` were directly
inspected. The cauldrons now read as dark iron over a small working fire.
The default and large bottle groups visibly contact their boards. The compact
plan declares one shared cooking/Witchwork station, so its renderer now records
six appropriate views; separate-station plans still require eight. Native exits
are zero, with stable source fingerprints, in 21.21/21.88/26.87 s. Reviews state
the remaining plain hearth recess, sparse work walls and broad regular exterior.
Neither whole-Witch identity nor the complete domestic hearth design is closed.

The broader shelf fixture then exposed a separate farmhouse shortfall:
random tall display shelving occupied the only useful shelf/light bay. Ordinary
kitchen recipes now select the measured shelf board. The compositor still
requires physical wall contact, actual supported contents and a nearby light.
All four original farmhouse/Witch cases pass, including recomposition and
negative controls, in 28.62 s (`kitchen_shelf_v1`).

The latest geometry lane passes **9,785 checks, zero failures and warnings**
in **266.51 s**, native zero (`artifacts/qa_fast/lane_geom/20261013_034640`).
The same revision passes furnishing in **213.74 s: 237 checks**, and assets
plus walkpins in **53.16 s: 200 checks**. Both return native zero, with no
failures, warnings or script errors. Receipts are
`artifacts/qa_fast/lane_house-furnish-fast/20261013_035106` and
`artifacts/qa_fast/lane_assets-fast__walkpins/20261013_035440`.
The Witch cauldron and workshop-flue fixtures also pass in 20.96/21.68 s.

The `finish_20261013_v3` cohorts contain 70 images across all three public
sizes of Cottage, Farmhouse, Thatch Cottage and Townhouse. All four native
runs pass with stable source fingerprints (70.94/80.42/48.45/70.59 s).
Twenty-five listed room/exterior images were directly inspected; exact hashes,
scope and remaining design faults are in each cohort's review. The gallery now
preserves 463 actual images, including all 22 reviewed Witch finish views.
The root review links this dated evidence while retaining earlier findings.

## Chimney intrusion found during hearth review

The structural detail validator still assumed a 0.4–0.6 m legacy breast and
rejected the native 0.72 m fireplace. It now checks the depth for the declared
host kind and still proves actual wall contact. The mesh fixture no longer
requires a nonexistent floor-hearth prop from a native structural fireplace.

The seed-1 Witch ray exposed a real second defect: the lower chimney stack
projected 35 cm into the firebox. The first attempted validator correction did
not waive that obstruction. Chimney emission now subtracts the shared mouth
from the intersecting lower masonry and logs the surviving pieces. The host
wall, chimney envelope and upper flue remain. The four-case fixture passes
109 checks in `hearth_mesh_v3`. The final restored-solid-chimney negative and
component parity raise that to 114 passing checks in 29.69 s (`hearth_mesh_v4`).
The geometry lane passes 9,785 checks in 286.75 s, with zero failures and
warnings (`artifacts/qa_fast/lane_geom/20261013_041515`). Three fresh Witch
recess runs return native zero with stable fingerprints; four cooking/workroom
views were directly inspected. The recess is open but its pale finish still
needs the measured refractory lining.

The strengthened hearth fixture passes **114 checks** with component parity and
the restored solid chimney rejected. The broader interior-detail fixture is
**red: 14 findings in 45.71 s**. None is a hearth-detail failure. Its remaining
findings are sparse Farmhouse/Townhouse/restaurant rooms, the Farmhouse seed
4413 stair's pitch/head/guard/approach, a Townhouse office chair classified as
corridor furniture, and restaurant kitchen lighting/preparation. This result
does not invalidate the narrower passing fixtures, and those fixtures do not
constitute a pass of this broader check.

## Witch lining and front-hall recovery

The ordinary Witch cooking recess now reuses the physically witnessed
firebrick and soot lining. Its Cauldron retains ownership of fuel and heat.
The new three-size fixture passes 26 checks in 34.35 s. Its restored-solid-stack
negative exposed a second problem: the assembler had only tested wall
triangles and could look through floor-material chimney stone. It now checks
all emitted surfaces and requires the first hit to reach the breast's backing
plane. The ordinary hearth fixture still passes 1,174 checks in 68.53 s;
Witch heat passes in 30.62 s; assets-fast passes 155 checks in 41.36 s.

The three final lining renders return native zero with stable source in
29.04/27.75/30.18 s. The gallery now preserves **485 actual images**.
Nine listed cooking/control/exterior views were directly inspected against
the Witch target; 13 other images in these new cohorts were not directly
reviewed. The pot still stands before the recess, so the larger hearth design
and Witch identity remain open.

Farmhouse seed 4413's stair failure began in room planning. The 12 × 16 m
request entered the large central-spine grammar although its side rooms could
not fit. Exhausting that grammar led to legacy partitions and the old steep
stair. Exact ordinary no-trade houses now try the established front-hall
grammar for the same activities before reducing the programme. Already
successful spine plans and specialist/trade/world plans retain their path.
The pinned home now has a planned Hall, kitchen, workshop and two ground-floor
bedrooms, with omitted optional activities recorded. Its flight and landings
use the domestic profile. Six adjacent two-storey cases pass 48 checks in
25.47 s, including the furnished pin, plan checks, component parity,
determinism and a steep-riser negative.

The full bounded planning lane finishes in 197.98 s but is **red**, with
19 failures and 30 warnings. Its 56 planning-QA checks pass. The other findings
are 18 multistory furnishing/old trade-stair failures and the compact
Alchemist's missing preparation pot. The three multistory failure fixtures
are outside the new front-hall recovery gate (small Cottage, innkeeper
Townhouse and smith Longhall); they are not claimed fixed.

The Alchemist's cookware selection could choose a metal bucket. Its authored
shared-Hall contract now explicitly selects the measured pot. The final
furnishing lane plus compact Alchemist passes **260 checks, zero failures and
warnings, native zero in 294.82 s**
(`artifacts/qa_fast/lane_house-furnish-fast__hwitchcompact/20261013_045216`).
This clears that compact case, not the other multistory failures.

The broader interior-detail fixture now has **9 failures rather than 14**
in 58.66 s: sparse upper rooms, the narrow-office chair classification and
restaurant kitchen furnishing/light. The pinned Farmhouse's stair errors
are gone. Neither broad check is reported as passing.

The exact repaired Farmhouse request also renders successfully: one request,
six images, native zero, stable source, 41.24 s. All six were directly inspected
against its target. The cutaway shows the guarded upper opening; room views
retain the household activities and ceiling members. Its broad box exterior,
empty workshop surfaces and plain wall composition still need work. The
`front_hall_20261013_v1/assistant_review.json` explicitly records
`needs_changes`. The final gallery contains 491 actual images.

## Measured cooking recess and final hearth composition — complete

The Witch cooking Cauldron now stands inside its structural firebox. The
catalogue footprint sets the breast size, with 12 cm behind the model and
8 cm before it; actual jambs retain lateral clearance. Its three imported
feet contact the emitted 14 cm masonry seat. Furniture, shelving and timber
panelling reserve the complete breast. The same mouth is cut from any
intersecting lower chimney stone while the backing and upper flue remain.

The ordinary domestic surround uses a stone region on its existing structural
surface. Its dark reveal faces sit 2 mm inside the structural faces, removing
the coplanar pale seam without adding duplicate structural cladding. Witch
billets are now thick enough to read beneath the bowl. Their dimensions,
crosspiece bearing and flame positions clear the actual imported legs and pot.

Focused receipts under `artifacts/todo_completion_20261013/`:

| Receipt | Result |
|---|---|
| `ordinary_heat_recess_v3` | 1,198 checks, pass, 72.30 s; removed real lintel triangles and coplanar reveal negatives included |
| `witch_fuel_larger_v1` | pass, 32.14 s; imported-mesh fuel/flame collisions and bearing |
| `hearth_mesh_recess_v1` | 118 checks, pass, 36.51 s; sealed-mouth faults on all material surfaces |
| `domestic_material_recess_v1` | five ordinary styles and four specialist/trade controls, pass, 21.78 s |
| `witch_recess_nine_v2` | 195 checks, pass, 137.78 s; recess, seat, recipe activities and navigation |
| `witch_recess_nine_v3` | 222 checks, **nine failing cases**, 129.12 s; added real model vertices pass, full furnishing assertions expose the broader defects below |

The final nine-case Witch render plus three Cottage controls produces 78
images in `witch_recess_matrix_v2`, native zero, 161.88 s. The ordinary cohort
produces 24 images from twelve frozen requests in `ordinary_hearth_stone_v2`,
native zero, 90.01 s. All 1,025 Witch source fingerprints and all 24 ordinary
source fingerprints still match after the runs. Camera selection now tests
rays to actual flame centres against low furniture as well as the emitted
recess. A clear line to the pot alone had allowed the bench to hide the fire.

The assistant inspected nine Witch cooking portraits individually, their nine
heat controls and nine exteriors in labelled contact sheets, plus all 24
ordinary images. The default ordinary Farmhouse hearth was also inspected at
native resolution. These 51 images accept the working cooking hearth scope.
The other 51 Witch/control images have no direct-review claim. All 102 new
images are archived, bringing the gallery to **593**; every archived image
matches its source hash. Matched Cottage controls without reviewed images
are explicitly marked `not_reviewed`.

Whole Witch acceptance remains open. Small/default benches stand 1.95/1.33 m
off their backing wall. Two small seeds also have a daylight failure, the
third a sconce-pair arrangement failure. Large cases have sparse 91 m² halls
and 30 m² records rooms. These are the nine failing full-furnishing cases;
none is suppressed by the hearth validation. The paired-bench candidate
helpers accept L-shaped or opposing floor fits without proving wall backing.
Their early `paired_workbench` commit path is the next placement repair to
address alongside the compact plan's actual available wall runs.

The combined geometry and furnishing runs reached their 300 s caps and are
recorded as timeouts. Additive lane partitions preserve every original suite.
`lane:assets-fast` passes 155 checks, zero failures/warnings, native zero in
42.51 s (`artifacts/qa_fast/lane_assets-fast/20261013_065539`). Final partition
receipts, all native zero with no failures or warnings:

| Selector | Checks | Host seconds | Receipt directory under `artifacts/qa_fast/` |
|---|---:|---:|---|
| `lane:geom-core` | 6,424 | 186.29 | `lane_geom-core/20261013_065702` |
| `lane:geom-openings` | 306 | 152.36 | `lane_geom-openings/20261013_070008` |
| `lane:geom-envelope` | 3,059 | 130.00 | `lane_geom-envelope/20261013_071241` |
| `lane:house-furnish-rules` | 97 | 284.50 | `lane_house-furnish-rules/20261013_070333` |
| `walkpins` | 45 | 89.13 | `walkpins/20261013_070818` |

The geometry partitions contain exactly the original lane's eleven suites,
without duplicate coverage. Their total is 9,789 checks. Furnishing rules,
assembly and walk pins likewise retain the original furnishing lane's suite
set. The first envelope attempt (`20261013_070241`) exited `-1` after 52.53 s
with no error or summary; its cause is unknown. Stage markers were added to
the existing bounds sweep, and the unchanged assertions passed on the rerun.
The failed processes remain preserved and are not reported as passes.

`LIVE-DOMESTIC-HEARTH-DESIGN` is complete for its stated scope. Eight broader
todos remain: Witch, all house styles, shops, sacred buildings, remaining
family styles, castle physical interiors, other-family interior navigation,
and the final cross-family review. The castle task description now reflects
its existing planners and unresolved physical failures instead of asking for
already implemented records. The backlog validator reports no issues.
