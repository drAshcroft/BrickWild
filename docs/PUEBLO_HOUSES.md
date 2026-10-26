# Pueblo adobe houses

`HouseSpec.STYLES[&"pueblo"]` adds a thick-walled adobe dwelling to the
vernacular house family. It uses a level roof slab, an enclosing parapet, and a
plain earth roof finish. The exterior palette and zero exposed frame keep it
distinct from the timber styles; the 0.72 m shell thickness is resolved before
room planning so the interior and openings use the same wall measurement.

The level roof is represented as one horizontal roof face with the ordinary
roof slab thickness. Wall closure, bounds, roof openings, ridge handling, and
the parapet all use that shared roof geometry. The flat slab has no ridge or
eave tails.

HS-PUEBLO makes the house a stepped one (`HousePueblo`, `src/house/house_pueblo.gd`; the
traits, the measure and the review are in `docs/HOUSE_STYLES.md`). A plain pueblo
(no trade, not a shop or a world family) on a footprint that can step is two or
three storeys, each set back from the one below (front 2.4 m, one side 1.3 m,
alternating). The part of a storey's roof that the next storey does not cover is a
walkable terrace behind a parapet, and the top roof is one too. There is no stair
inside: a ladder climbs the front wall of each storey to the terrace above it, and an
upper room opens through a door onto the terrace in front of it. Round roof beams
(vigas) stand 0.55 m out of every wall under the roof or terrace they carry, and the
doors and windows are small (0.8 m by 1.72 m; windows 0.6 m by 0.65 m, sill 1.1 m).
`HousePlan.terraces` and `HousePlan.ladders` hold the terraces and ladders; the nav
check walks a ladder from its foot to its head (`HousePueblo.walk_floor` is the floor
it adds, read by both the check and `HouseWalkSources`), and `BrickWild.navigation`
publishes each ladder as a link (`"ladder": true`).

The Pueblo-specific rule in `VernacularHouseCheck` reads both the spec and the
emitted roof vertices. The vernacular suite builds Pueblo at every canonical
size and checks its shell thickness, earth roof finish, and parapet. Its fault
fixture leaves the plan marked flat while emitting a hip, proving the rule
checks built geometry. The furnished house archetype suite also includes a
Pueblo home at four sizes and checks its room, furnishings, and cultural form.

Run the focused regression with:

```powershell
& 'C:\Projects\godot\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64.exe' --headless --path . --script res://tests/run_all.gd -- hvernacular
```

Capture Mediterranean, Asian, thatched and Pueblo houses through the public
API with the reference renderer (run without `--headless`):

```powershell
& 'C:\Projects\godot\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64.exe' --path . --script res://tools/render_building_audit.gd -- --family:culture
```

The exterior, entrance and cutaway images are written under
`artifacts/renders/building_audit/culture/`. The accompanying `audit.json`
records the requests, cameras, public API QA and vernacular geometry checks.
