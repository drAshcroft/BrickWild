# Rugs and structural hearth surrounds (LAY-010)

The furnisher records `plan.rugs` after navigation repair, one rug beneath each
remaining table in a hall, parlour or dining room (including the native shop
`dining_room` programme). Each record names its table,
room, storey and rectangle. Margins adapt to room boundaries and neighbouring
tables, so textile quads do not overlap or escape the room. Rugs are neither
furniture nor obstacles: adding or removing them leaves navigation unchanged.

`HouseBuilder` emits each rug as two flat, upward-facing triangles 2 mm above
the actual floor slab, including storey and dais elevations. Black vertex
colour marks a dedicated textile region on floor surface 3. The house floor
shader gives it a seeded burgundy, teal or ochre palette, a warm border and a
subtle weave. Stone houses receive this material as well as timber houses.

The original task requested a separate rug surface. The later, verified house
exterior/API contract requires exactly four surfaces: wall, trim, roof, floor.
The dedicated vertex-colour region preserves that contract while giving rugs
their own material appearance, following the established glazing convention.
Headless geometry retains the same markers and can be checked without shaders.

The selected hearth placement authors `plan.hearth.breast`: room, wall, storey,
centre, inward normal, width, depth, yaw, polygon and rectangular broad bound.
The breast is 0.5 m deep and at least 0.4 m wider than the measured hearth prop.
The hearth's measured back touches its front face. Candidate fitting reserves
both the prop and the full-height masonry before choosing a location; other
furniture, windows, door approaches and wall-mounted pieces cannot occupy it.

The builder emits a full-storey `chimney_breast` component and structural mass.
The navigation grid blocks its actual polygon, including diagonal walls. A
navigation repair may remove furniture, but it cannot remove structural masonry.
Placement-only shell preparation runs native furnishing through navigation
repair before discarding temporary furniture. This retains the breast, hearth
focus and rugs beneath the surviving tables, preserving every shell triangle
and geometry log as well as native exterior bounds and doors. The older hearth
prefix shortcut cannot derive rugs in later rooms or tables removed by repair.
The room rectangles still tile the building; no density, tiling, overlap or
walking tolerance was relaxed.

`HouseQA.check_interior_details` verifies the mass, real emitted masonry at
three heights, measured hearth contact/width, furniture clearance, and actual
textile vertices at floor height. The dedicated test additionally removes the
real breast, raises actual rug vertices, compares navigation with and without
the breast, and proves rug records do not change navigation. It also checks
all emitted triangle normals on furnished house meshes.

Run the focused controls with:

```powershell
godot --headless --path . --script res://tests/house_interior_details_test.gd
```

Generate the real timber/stone cutaway, hearth and rug closeups with:

```powershell
godot --path . --script res://tools/render_house_interior_details.gd
```

The six images are in `artifacts/renders/house_details_*.jpg`; logs and bounded
acceptance evidence are in `artifacts/p1p2_layout/`. The project Godot path and
required geometry/furnishing lanes are documented in `AGENTS.md`.

The bounded acceptance run in `artifacts/p1p2_layout/acceptance.log` passed
7,376 checks across `house`, `houseqa`, `harchetype` and `lane:geom`, with zero
failures. Its 57 warnings remain visible: limited room sizes can require
navigation repairs, while daylight, density and affinity findings retain their
existing thresholds. `dress_complement_final.log` adds 1,024 passing exterior
and assembly checks with no warnings. `details_dining_final3.log` adds 175
current-source checks with zero failures, including a native restaurant dining
room, mutation controls, normals and saved-plan round trips. The public API
placement parity report supplements that broad run.
