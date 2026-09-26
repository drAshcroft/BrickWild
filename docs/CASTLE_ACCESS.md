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
