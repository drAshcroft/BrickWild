House exterior completion — September 2026
=========================================

The house plan now carries usable upper-storey jetties, measured exterior
dressing, and fitted roof attachments. HouseBuilder remains an emitter;
HouseAssembler alone loads the measured prop models.

Representation and compatibility
-------------------------------

`HouseGeometry.site_rect(spec, level)`, `interior_rect` and `exterior_runs`
accept an optional storey. Level zero and cellars retain the user's exact
width/length. An ordinary timber house with `jetty` projects every upper
front by the same `jetty_depth`; the depth does not accumulate. Front rooms
grow before upper-room naming and window placement. Floors, walls, frames,
clear floor, navigation and the roof use that envelope. Public plan-family
footprints include the upper room envelope. The original spec fields and
actual room/window records serialize without a new per-storey field.

The initial jetty scope is rectangular timber dwellings. Stone shells,
special family programmes and polygon/courtyard shells retain their own
footprint rules; a rectangular jetty must not be added to them. Ground
hearths avoid the projecting front, and their fixed flue reserves upper
glazing space. The beam, joist ends and brackets carry a real floor slab.

The four surface slots remain wall, trim, roof and floor. Glazing uses a
black vertex marker within the roof stream, selecting a fixed blue glass
treatment in the house-only shader. This avoids Godot compacting an empty
roof surface and shifting the floor/glazing indices in cutaways. White
vertices select roofing; unrelated family materials ignore vertex colour.
Slab UVs are metre-scale face coordinates, horizontal along the eave and
uphill along the slope, so clipped pieces retain continuous courses.
`roof_material` is derived deterministically without another RNG draw.
Headless assembly retains base materials; the GPU renderer verifies shader
appearance because Godot's dummy renderer has no shader instances.

Art direction
-------------

These are art-direction preferences, not universal architectural limits.
The generated pitch gradually softens above each style's reference span;
explicitly authored geometry fixtures retain their requested pitch.

| Style | Silhouette and materials | Reference span | Facade/dressing intent |
|---|---|---:|---|
| Cottage | Compact warm shingle cap, plaster and generous timber | 7 m | Entrance lamp/porch, seat when it fits, discreet storage |
| Farmhouse | Broad, quieter thatch roof; readable hip/half-hip edges | 9 m | Produce and work storage grouped on a service wall |
| Townhouse | Narrow vertical silhouette, slate, real upper projection | 8 m | Close studs aligned to window jambs; clear entrance accent |
| Longhall | Strong, deliberately tall thatch gable, expressed truss | 8 m | Entrance and hearth/service end carry the detail |
| Witch hut | Intentionally extravagant, steep green shingle silhouette | 8 m | Asymmetric pot/cauldron work cluster and restrained timber |

Above the reference span, ordinary pitch scales by the square root of
reference/span; witch huts use the much gentler exponent 0.2. This controls
the broadest roofs without imposing a common maximum rise. Facade jambs
establish the bays, then intermediate studs subdivide the solid stretches.
Openings and the entrance retain their clearances.

The dressing uses existing Quaternius Fantasy Props MegaKit Standard models.
The project's `assets/props/fantasy/License_Standard.txt` states CC0 1.0;
source provenance is recorded in that directory's README. No model or
texture files were added. A cramped 4 × 5 m cottage records its omitted
bench and preserves the clear approach, rather than forcing the full recipe.

Evidence and reproduction
-------------------------

Use the console executable next to the Godot path in AGENTS.md for reliably
captured headless output. All long runs are redirected under
`artifacts/p1p2_house/`.

```
godot_console --headless --path . --script res://tests/run_all.gd -- lane:geom
godot_console --headless --path . --script res://tests/run_all.gd -- henvelope
godot_console --headless --path . --script res://tests/run_all.gd -- house assets houseqa hmultistory harchetype court
godot_console --path . --script res://tools/render_house_roofs.gd
godot_console --path . --script res://tools/render_house_roofs.gd -- --matrix --before-art
godot_console --path . --script res://tools/render_house_roofs.gd -- --matrix
python tools/house_art_report.py
```

The named front/back/side/elevated references are in `artifacts/roof_fix/`.
The matrix contains 40 matched pairs across five styles, four canonical
sizes and one/two storeys, with numeric rise and roof-to-wall ratios.
`artifacts/p1p2_house/comparison.html` is the paired sheet. Its before column
isolates the original roof pitch; both columns use current facade/materials.

The geometry lane passed 6,955 checks across nine suites with zero failures
or warnings (`geom_final.log`). The composed runtime envelope checks passed
18 normal/cutaway cases plus six emitted mutations (`mill2.log`, 25 checks;
the separate bounds assertion also observes the moved-mesh fixture).
Mutations move actual roof faces, delete a slope, lower a gable, duplicate a
slope, block an entrance with trim, and move mesh vertices away from their
component records. The original crossed-slab fixture remains in the roof
suite and cannot pass merely by retaining 100% projected coverage.

The final dedicated jetty/envelope run passed 226 checks with no failures or
warnings (`envelope_final.log`: jetty 202, envelope 24 before the extra bounds
assertion). Retracting the actual upper floor or wall is rejected. The legacy
runtime-suite coverage/reach helpers now measure from the upper wall; their
unchanged 0.55 m overhang limit still rejects a translated actual mesh.

The runtime diagnostics identify seed/style and the offending host/component,
measured error and tolerance. Courtyard sky holes and shaped hosts retain
their own checks. The court-support check now measures the actual highest
slab underside: the previous percentage of its AABB incorrectly rejected
flat slabs sitting directly on a wall.

Broader integration evidence includes completed `house` (123 checks),
`assets` (488 checks) and `hmultistory` (210 checks) sections in
`integration.log`. That older process was stopped after loading an obsolete
polygon-furnishing implementation; the entire log is not a passing run.
Fresh `acceptance_final.log` completed `houseqa` (258 checks, no failures)
and `court` (105 checks, no failures). Its archetype section isolated one
family-cottage table/seat regression, repaired separately before closure.
After that furnishing repair, `artifacts/p1p2_furnishing/dining_acceptance.log`
passed all 292 checks: house QA 258 with 19 warnings, archetypes 34 with 24
warnings. The 454 courtyard warnings describe existing room morphology,
daylight and documented furnishing compromises; no failure was suppressed.
The final shared geometry lane plus church normals and castle/temple roof
checks passed 8,992 checks (`artifacts/p1p2_roof_seams/`), and the clean addon
test passed all seven family scenes/roundtrips with all four catalogue packs
(`artifacts/p1p2_api/addon3.log`). `addon_current_house.log` separately confirms
the current house source can roundtrip and instantiate with model collision.
`HOUSE-EXT-010` through `HOUSE-EXT-016` are complete.
