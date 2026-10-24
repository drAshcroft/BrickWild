# Castle access structures (CAS-004)

Castle access is planned in `src/castle/castle_access_geometry.gd`, exposed
through `CastleGeometry`, and emitted by `CastleBuilder`. The same footprints
reserve space before yard dressing. Gate accessories, wall stairs and the
protected keep stair are logged as structural masses and named components.

Portcullis guides are a recessed pair inside each gate passage. A lowered
drawbridge supplies a real walking deck when the spec requests a ditch or
moat. Wall stairs use alternating flights and landings beside the curtain,
with a grounded spine and clear headroom. The forebuilding encloses a stair
to the keep's actual first-floor door; its landing spans the shoulder of a
receding keep when necessary.

The checks inspect emitted triangles as well as logs. They require tread
surfaces, headroom, open portcullis grooves, a solid guide behind each groove,
a continuous bridge deck and a clear protected stair route. Negative controls
remove structural logs and fill real passages to prove the checks detect
missing or obstructed access.

The standard runner and `lane:castle` include all three focused suites:

```powershell
godot --headless --path . --script res://tests/run_all.gd -- caccess cforebuilding cgateaccess
```

The standalone `castle_access_test.gd`, `castle_forebuilding_test.gd` and
`castle_gate_access_test.gd` entry points call those same suites. The first
two still accept style/tier substring filters for diagnosis. Full acceptance
also requires the castle contract, massing and voxel suites; focused access
checks alone do not establish that the occupied castle works as a whole.

The focused runner passed 285 checks on 2026-09-25: 199 for wall stairs,
70 for forebuildings and 16 for gate access, with zero failures or warnings.
Its log is `artifacts/todo_completion/cas004_access.log`.

## Polygon corner galleries (CASTLE-CURVED-CURTAIN-ROUTES)

Three things made the polygon castles' corner routes cross masonry that the
rect castles do not have. All three apply to `CastleGeometry.is_polygonal` only,
so the rect layouts are untouched.

* The corner L's elbow is where the two curtain-parallel arms meet
  (`CastleMuralPlan._corner_gallery`), not an axis-aligned corner. On a slanted
  curtain the axis-aligned elbow made a 36 degree hairpin whose parapets and
  deck seams crossed the walker.
* `wall_stairs` reserves the corner towers' decks (it did so only on a motte), so
  a stair's piers and end rails stay off the route.
* `_clear_gallery` takes the L's arm that is clear of the keep, hall, chapel and
  apse. The L is still decked whole: trimming the unused arm cut the coping's
  continuity and stranded every corner on french_chateau. Do not use
  `bailey_obstacles` there; it asks for the wall stairs, which ask for the routes.

## Elven (bowed) curtains (CASTLE-ELVEN-TOWERS)

`_curved_wall_run` is its own emitter, so it had none of the straight run's
tower handling and no stair. Six things were wrong; all are `curved_edges` only.

* The towers were never cut out. `CastleBuilder._curtain_cuts` is the shared
  list (room outlines, and above the walk the landing and gallery decks);
  `MeshKit.curved_wall(..., cuts_at)` rebuilds a course that meets a cut as
  prisms of what is left. The walk laps a deck's edge by 4 cm, because meeting
  it on the line left a hairline the walk grid read as a crack.
* The bow (`CastleGeometry.bow_offset`, sine to the fourth power) leaves a tower
  along the chord. The old parabola left at 32 degrees and swept across the
  windows a tower turns to its neighbour. The centreline is also half a wall
  thickness inside the bow, as on a straight run (the polygon edge is the OUTER
  face at the corner), so the tower galleries land on the walk.
* Tower windows are checked against the bowed shell
  (`CastleGeometry.bowed_wall_near`), not the chord's box.
* `CastleMuralPlan`/`_best_wall_stair`: stairs are squared to the curtain's
  tangent where they stand, against a ward that includes what the bow gives
  back (`_bowed_ward`), and only where the wall is within `BOW_GAP` of the
  stair's back line. They land on the bowed centreline, and the tower route
  stops keep a body's width of clear walk.
* `CastleRouteCheck._wall_stair_route` finds the coping on the bowed centreline.
* `MeshKit.curved_wall` mitres its joints. Strips each on their own normal left
  a wedge crack in the walk wherever the curve bent; one such crack sat on a
  tower's route stop.

Elven fortress 0 no longer has an occupancy or route failure. What it reports
is the inner ring's tower furnishing: seating and seat_count in `store` and
`guardroom` rooms, with out-of-range index errors in `HouseFurnishArrangementCheck`
and `HouseFurnishWalkCheck` on the 49th and 50th seat. That is a furnishing
class, not an access one. The elven castle's `chapel` "sparse" line is the same.
