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
This bridge emits their valid plans; it does not invent a plan for a range that
those planners reject. Ridge castles, tower houses, and motte shell keeps need
dedicated plans matching their rotated ranges, raised entrances, and mound
geometry. They remain separate follow-up work. Ordinary castle wings and
annexes without an authored HousePlan also retain their existing geometry.
Tall hall and chapel ranges can contain an unoccupied void between the plan's
ceiling height and the castle-owned roof.

Remaining form and polygon-affinity work is detailed in
[CASTLE_INTERIOR_FOLLOWUPS.md](CASTLE_INTERIOR_FOLLOWUPS.md). Large castles can
still be slow to generate and check: the complete massing sweep took about
30 minutes while other suites ran concurrently. The
[performance follow-up](tasks/castle_interior_performance.json) requires phase
profiles on an otherwise idle machine before further optimization.

The hotel dormer roof defect is tracked separately as `ROOF-AUDIT-001`.

The canonical voxel QA sweep passes all 84 fixtures with 204 nonfatal warnings.
[The warning handoff](CASTLE_INTERIOR_WARNINGS.md) records category counts,
exact fixtures, rule locations and the related pending triage task. Warnings
include explicit furnishing compromises, generic seating rules applied to
chapel pews, measured stable floor pockets, and secondary placement preferences.
The same handoff separately records 169 normals warnings: 141 outside-opening
probes against mass bounds and 28 reports covering 56 degenerate roof triangles.
Their physical causes remain a separate pending investigation.
