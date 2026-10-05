# Pueblo adobe houses

`HouseSpec.STYLES[&"pueblo"]` adds a thick-walled adobe dwelling to the
vernacular house family. It uses a level roof slab, an enclosing parapet, and a
plain earth roof finish. The exterior palette and zero exposed frame keep it
distinct from the timber styles; the 0.72 m shell thickness is resolved before
room planning so the interior and openings use the same wall measurement.

The level roof is represented as one horizontal roof face with the ordinary
roof slab thickness. Wall closure, bounds, roof openings, ridge handling, and
the parapet all use that shared roof geometry. The flat slab has no ridge or
eave tails. Roof access is not part of the current house plan vocabulary.

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
