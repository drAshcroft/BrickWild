# Castle interiors

`CastleBuilder` retains each emitted `HousePlan` in `builder.interiors`. A record
contains the building ID, plan, world transform, original mass bounds, local
`HouseBuilder`, and local mesh. `CastleInteriors` is the shared bridge for the
builder, assembler, and QA. Hall, eligible keep, chapel, and bailey shop shells
replace their former solid blocks. Their top-level mass records remain available
to the existing massing checks.

Stone is a public house/shop request option (`material = &"stone"`). It uses
0.6 m masonry and omits half-timber framing and jetties. The default material
remains timber. Castle roof joins and keep crowns remain
owned by `CastleBuilder`; `HouseAssembler` places the plan's measured furniture
and lights after the shell has been built.

Glazing maps to the castle's opening material. Mapping follows the original
house surface identity, so a windowless house floor still maps to stone when
Godot omits an empty surface. Roof cutaways remove the roof and preserve glazing.

Round and shell keep rooms use the actual 14-sided outline. Tiered keeps have
shrinking floors and roof shoulders. Every staircase fits both adjacent floors;
the upper floor has a real opening. These shapes share their outer description
with `castle_keep_plan.gd` rather than treating the keep's bounding box as a room.
Keep storeys span the complete keep height, including square keeps.

The shared checks ask the plan spec for its supported storey limit: dwellings
retain four, tower houses allow six, and occupied keeps allow eight. Navigation
and stair coverage inspect every declared occupied level. Motte rooms keep the
oval fitted to the mound; fitting the bailey hall cannot flatten that oval into
a narrow rectangle. Their alternating stairs follow real wall facets, every
habitable floor has windows, and the top chamber's planned fireplace has an
emitted wall flue and coping above the parapet. The entrance uses a front facet
with enough space beside the solid climbing curtain for the entire doorway.

The [motte overview](screenshots/motte_revision_hero.png),
[furnished entrance](screenshots/motte_revision_entrance.png), and
[wall flue](screenshots/motte_revision_flue.png) are actual renderer captures.
Reproduce them with `tools/render_castle_specials.gd -- --motte-revision`.
The overview fixture is Norman, 45 by 55 metres, height 6, seed 8856.
Its earlier passing QA result was incomplete: motte dispatch omitted hall and
chapel plans, the small towers had no occupied plans, and the approach check
accepted step records without measuring the curtain crossing in the mesh.
`cmotteaccess` now checks the finished approach and the fixture's occupied
buildings. Its negative controls preserve the step logs while restoring the
blocking curtain or removing emitted tread geometry. `coccupancy` exercises
missing building records, blocked entrances, and windows without rooms.
The motte's mural towers enter from the curtain walk and contain real floors
and connecting stairs. The gate chamber sits above the gate passage, with a
gallery to the wall walk. The curved chapel sanctuary has its own floor,
windows and a shared doorway into the nave. Its altar programme does not
require pews in this smaller space.
The render utility runs `CastleQA` first and saves `motte_revision_qa.json`
beside the captures; a failed report prevents replacement images.
`tests/castle_motte_envelope_test.gd` checks 48 seeded fits;
`tests/castle_motte_native_test.gd -- small compact fortress` checks the furnished
3-, 7-, and 8-storey fixtures against emitted geometry and navigation.

Planned windows and doors keep their actual emitted positions and facing in
the castle part log. In enclosed castles, hall and chapel windows face the
courtyard; their plans establish those windows before furniture is placed.
The massing `facade` rule measures windows by occupied storey, using those
emitted records. Ridge ranges also retain their castle-owned upper rows above
the furnished lower plan. Window count alone cannot satisfy the rule: moving
every opening into the bottom band fails even when the count is unchanged.
Voxel QA measures masonry
at a real window's jambs, head, and sill, while keeping the original backing
checks for decorative slits on solid castle walls.

Rotated furniture and its access strips use measured rotated bounds. The
lord's chamber reserves a usable bed wall, and lamp pairs use actual polygon
edges. Small bailey shops preserve clear entrance approaches for customers and
give workshops cross-light before placing benches.

HousePlan furniture uses footprint centres, so assembly compensates for the
model's measured pivot. Mounted models keep their backs on the room wall, and
lights share the corrected pose. Both bed models receive the half-turn needed
to put their measured headboards on the planned back wall.

`CastleQA.check()` returns a `buildings` dictionary containing the HouseQA report
for every emitted interior. Plan, furnishing, and navigation failures also fail
the castle report. These per-building reports use HouseQA without a local
builder, so they omit its shell-mass, vertical-shell and opening-elevation
checks. CastleQA measures the combined castle mesh, and separate regression
suites measure the local shells, apertures and castle-owned roof coverage.

The `lords_walk` rule traverses the emitted courtyard geometry through actual
gate passages, then uses the keep plan's navigation and stair chain to reach the
lord's chamber. It uses the existing `WalkGrid` and measured prop footprints.
Painting a door on a solid wall cannot satisfy it. This rule applies when the
builder has emitted a keep plan.
Special motte and tower-house approaches also require emitted tread surfaces,
a clear body-width corridor between treads, and 1.95 metres of headroom.
An orderly list of step positions cannot establish those facts.

## Verification

Use the Godot executable documented in `AGENTS.md`:

```text
godot --headless --path . --script res://tests/run_all.gd -- stoneshell cwalk cplanshell crangeplan caperture cshop psconce ckfurnish hassembly
godot --headless --path . --script res://tests/run_all.gd -- castle cnormals cmassing clandmark cvoxelqa
godot --path . --script res://tools/render_castle_interiors.gd
```

The render utility writes roof-on, roof-off, and lord's-chamber PNGs for square,
round, and tiered keeps to `artifacts/renders/`. Run it with a real renderer;
headless mode does not produce useful reference images.

Set `BRICK_WILD_TEST_TRACE=1` to log the style, tier, index, and seed before each
canonical castle case. The runner also prints suite start and elapsed time,
which makes a slow or failing headless run easier to locate.

Regression suites include negative controls for filled doorways, sealed stair
openings, reversed normals, obstructed gate passages, moved courtyard props,
missing entrances, invalid furniture, and polygon hearth wall orientation.
The assembly suite also measures actual model bounds and bed headboards, using
an offset-pivot stall fixture and reversed-bed negative controls.

## Eligibility and remaining work

The existing hall, chapel, and keep planners have room-size eligibility limits.
Ridge castles, tower houses, and motte shell keeps have dedicated plans, but
some forms still emit additional occupied-looking geometry outside those plans.
The inventory check derives required buildings from the site specification for
each family; omitting an entire plan is a failure. Ordinary castle wings,
annexes, defensive towers and upper ridge storeys without complete plans are
reported as missing coverage. Passing the pictured motte does not establish
complete coverage of the castle family.
Tall hall and chapel ranges can contain an unoccupied void between the plan's
ceiling height and the castle-owned roof.

Remaining form and polygon-affinity work is detailed in
[CASTLE_INTERIOR_FOLLOWUPS.md](CASTLE_INTERIOR_FOLLOWUPS.md). Large castles can
still be slow to generate and check: the complete massing sweep took about
30 minutes while other suites ran concurrently. The
[performance follow-up](tasks/castle_interior_performance.json) requires phase
profiles on an otherwise idle machine before further optimization.

The hotel dormer roof defect is tracked separately as `ROOF-AUDIT-001`.

The historical canonical voxel QA sweep passed 84 fixtures with 204 nonfatal
warnings before the occupied-shell checks were added. That result did not prove
that every visible building had an interior or that its windows opened into one.
On 2026-10-02 the stronger bounded `castlechange` check rejected blocked hall
windows in seed 9075, blocked keep windows in seed 9250, and roomless upper
ridge windows in seed 8805. Those are failures, not accepted warning categories.
The castle family must not be described as complete while these remain.
[The warning handoff](CASTLE_INTERIOR_WARNINGS.md) records category counts,
exact fixtures, rule locations and the related pending triage task. Warnings
include explicit furnishing compromises, generic seating rules applied to
chapel pews, measured stable floor pockets, and secondary placement preferences.
The same handoff separately records 169 normals warnings: 141 outside-opening
probes against mass bounds and 28 reports covering 56 degenerate roof triangles.
Their physical causes remain a separate pending investigation.

## The way through a tight tower storey (CASTLE-FURNISH-WALK)

A mural tower storey 4.7 m across is a landing between two flights. The
guardroom recipe's trestle table and chairs filled the floor between where the
flight below lets a walker off and the foot of the next one, with 0.5 m left to
squeeze past (walk pin WALK-1a17b2b3-4). `CastleKeepPlan.walkway_blockers(plan,
room)` names the floor pieces on that straight way (arrival landing or inward
door to the next foot or door, 0.6 m at each wall end spared, 0.4 m of
shoulder each side; rooms wider than 6 m have floor to go round and are not
asked). `_demote_unseated_guardrooms` now also demotes a guardroom whose table
is one of them: it becomes the watch room it is, and anything still in the way
is removed. `CastleWalkAccessCheck.walkway_failures` asks the same question of
the finished plans, and its suite hands it a table across the way.

A great hall needs 3.0 m clear (`MIN_HALL_SIDE`); the generator once allowed a
3.5 m hall range, which with 0.6 m walls is a 2.3 m passage with no hearth
(edwardian seed 1, pin WALK-1a17b2f2-1). `CastleGeometry.HALL_W_MIN` (4.4 m)
is now the narrowest hall range, so a hall range is always a great hall and a
great hall always has its hearth (`CastleWalkAccessCheck.hall_fire_failures`).

## Stair pitch and fittings over treads (CASTLE-STAIR-PITCH)

`HouseStairCheck` wants a flight no steeper than 42 degrees with a 0.22 m
riser at most. A straight flight therefore needs a run of the storey height
over tan 42 (4.0 m for a 3.6 m storey) plus a 1.0 m head landing and a 0.3 m
foot. `CastleKeepPlan._add_stair` tries that walkable run first (and records
`steps` = storey over 0.2 m) wherever the room is long enough, then the old
2.4 m run, then 2.0 and 1.6 m so a slender keep's flight lands on floor rather
than climbing into a wall (stair_head outranks pitch). A square keep's flights
come from `HousePlanLevels.add_stair`; one that would climb into the far wall
is re-planned by `_add_stair`, with the entrance doorway kept clear.

Newel stairs (CASTLE-NEWEL-STAIR). A tower or keep under about 5 m clear
cannot take a walkable straight flight (56 to 70 degrees), so
`CastleKeepPlan._add_stair` falls back to `newel_flight`: a square well of
side 2 x radius (1.1, 1.0 or 0.95 m), wedge treads round a post (`HouseNewel`,
`kind: &"newel"`, `centre`, `radius`, `hub`, `sweep`, `spin`, `steps`). The
sweep is the shortest of 360/540/720/900 degrees that keeps the walking line
(two thirds out along the tread) at 41 degrees or less with 2R + G inside the
0.70 m stride: a 3.6 m storey takes one turn, the 6.75 m bergfried keep two.
After a whole number of turns the walker leaves on the side he entered, after a
half more on the far side. The flight above stands on the same well (one
column through the tower); a candidate well must leave a person a way from every
door to the foot (`_newel_passable`) and may not stand in a doorway on any
storey. `rect` is the well, so rect-based code still works; `foot_landing` /
`head_landing` are 0.7 m strips. `HouseBuilder._emit_newel` emits one
`newel_tread` component per step plus `newel_post`, guard posts and the upper
well rails (host `stair_<n>`); `HouseStairCheck` measures pitch along the
walking line and counts treads and rails; the nav grid treats the well as an
obstruction and walks between landings (`HouseWalkSources.stair_rect`).
`CastleWalkAccessCheck.pitch_failures` reports every steep flight, not just the
avoidable ones. Not solved: a 3.83 m octagon with 4.7 m storeys (edwardian
`tower_1_*`) has no well that leaves the way open and keeps a straight ladder;
`CastleTowerPlan._add_stairs` (the tower house) and the ridge/manor stairs do
not use it.

`HouseFurnishSurface.place_mounted` now skips a wall fitting whose recorded
body (the footprint `HouseStairCheck` measures, not the mount pose) touches a
non-domestic flight leaving the room or the well of the one arriving in it. A
watch room made by demoting a guardroom drops the outdoor Lantern_Wall the
guardroom was allowed, and tops its lights up to what the room wants.
