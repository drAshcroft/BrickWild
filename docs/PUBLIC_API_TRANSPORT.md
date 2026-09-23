# Public data and headless generation

BigGlade targets Godot 4.5.2. API version 1 and JSON schema version 1 are separate:
additive fields can grow without changing either; incompatible schema changes need
a new schema version. Readers ignore unknown fields and reject unknown versions.
Fixed seeds reproduce within the same generator version and Godot precision build;
future releases may deliberately improve generated buildings.

`BigGlade.measure(request)` returns the same placement data as
`BigGlade.placement(BigGlade.generate(request))`. House/shop measurement generates
their real structural plan, shell and exterior props. Rugs and chimney breasts
depend on final furniture placements, so houses and affected shops replay native
furnishing and retain those derived shell records before discarding temporary
furniture. Shops with no hearth or rug-bearing room can omit furnishing. The
older hearth-prefix shortcut is insufficient once later rooms and navigation
repair decide which tables survive and therefore which rugs are emitted.
Other families retain normal generation. This returns only placement;
`generate`, `generate_document`, scene assembly and public QA still retain full
functional interiors. Measurement owns its temporary RNG and does not change a
later generated interior or the caller's RNG stream. Placement may include an
`approach` rectangle for an open manor whose door is recessed inside its courtyard,
or a ziggurat whose twin summit stairs flank the ground-level passage to its
chamber. The physical stairs remain in its footprint and the actual door stays
at the portal; the approach describes only the clear native route between them.

`BuildingRequest.to_dict()/to_json()` and `from_dict()/from_json()` round-trip
requests. The schema is `bigglade.request`. A minimal request is
`{"kind":"house","seed":"42"}`; omitted controls use the published family
defaults. Seeds are signed 64-bit decimal strings so JSON consumers cannot round
them. Numeric seeds are accepted only within JSON's exact integer range.

`BuildingDocument.to_dict()/to_json()` and `from_dict()/from_json()` preserve the
generated state, including edited derived values, rather than rerunning generation.
The `bigglade.building` schema retains readable `spec`, `plan`, and `placement`
projections, plus a lossless `state` used to rebuild. State containers and a fixed
allowlist of data classes are tagged. Engine value types are base64 Godot Variant
bytes with object decoding disabled. RNGs, scene nodes, scripts, callables and
resources are never serialized. This representation requires Godot to rebuild;
the readable projection and DM_View contracts can be read by any JSON consumer.

```gdscript
var document := BigGlade.generate_document(BuildingRequest.house(42))
var restored := BuildingDocument.from_json(document.to_json())
var mesh := BigGlade.build_mesh(restored)
var diagnostics := BigGlade.check(restored)
```

`BigGlade.check()` accepts either a generated building or a document. It invokes
the existing family checks and returns `ok`, `diagnostics` (severity, rule code,
field, message), and plain-data `stats`. It keeps builders and their logs private.
Warnings report genuine compromises without hiding failures. Church/castle voxel
checks and village QA can be expensive; run QA explicitly rather than per frame.

```powershell
godot --headless --path . --script res://tools/generate_building.gd -- --request request.json --out building.json --mesh shell.tres --qa qa.json
```

`--mesh` and `--qa` are optional. Exit codes: 0 success, 2 usage/file errors,
3 invalid request, 4 QA failures. Status and errors are JSON lines after Godot's
engine banner. Document output is deterministic and carries
no timestamp or process identity. Mesh output is an architectural shell; no model
assets are loaded during generation or mesh emission.

DM_View interiors use the separate C2 schema and site coordinates:

```powershell
godot --headless --path . --script res://tools/export_building_plan.gd -- --site site.json --building-id site:city-0042/b-000 --out interior.json
```

C1 now retains each building's exact request and rigid transform. Older C1 files
must be re-exported: a rectangle cannot recover the original seed or interior.
C2 preserves room purpose/privacy/focus, doors, windows, stairs, furniture and
recorded compromises. It validates room containment and graph reachability and
requires stairs between consecutive occupied storeys. Metres use site-centre
origin, +Y up, +Z south; records round spatial coordinates to millimetres.
Families without a HousePlan return `unsupported_interior` with family/building
identity and exit 3. The exporter does not invent an interior for them.
