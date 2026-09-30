# Visual QA

Written against `32c27b7` (2026-09-26). Every claim below names the image it was
read from, so it can be checked rather than believed. No generator code was
changed; this is a look at what the system puts on screen, and at what would
move that.

53 images were examined:

- 41 from `tools/render_shots.gd` — 8 landmark churches, 6 feature close-ups,
  8 castles, 6 furnished houses, 7 temples, 4 blueprint sheets, 2 cutaway
  extras
- 10 village form renders from `tools/render_village_forms.gd` (5 forms × 2
  views)
- 2 from a throwaway light probe (below)

**The short version.** The harness is extraordinary and the output is
*legible*: every building is the right plan, on the right axis, at the right
scale, and the settlement logic is the best thing here. What is missing is
everything one layer above correctness — depth at the openings, material on
the surfaces, a light that belongs to the shot, and a ground the building
stands on. The house family already has all four. The church and castle
families have none of them, which is why they score lowest despite passing
every structural suite.

---

## 1. The rubric

Nine axes, 0–5, 45 maximum. Chosen because each one is answerable from a single
render by someone who is not a generator author, and each one names a specific
piece of the system rather than a feeling.

| # | Axis | The question it asks | 0 | 3 | 5 |
|---|---|---|---|---|---|
| A | **Silhouette** | does the outline read in one glance, in profile? | shapeless | readable massing | a skyline you could identify |
| B | **Structure** | can you see what holds it up? | nothing carries | piers and walls read | the load path is legible |
| C | **Surface** | is there a material story? | one flat colour | two tones | course, texture, weathering |
| D | **Openings** | do windows have depth? | black decals | recessed | splay, sill, hood, surround |
| E | **Rhythm** | does the elevation have a beat? | one flat field | even spacing | hierarchy between bays |
| F | **Setting** | is it in a place? | floating | grounded | sited, shadowed, weathered in |
| G | **Hierarchy** | is there a focal point, scaled to the shot? | none | one accent | a graded hierarchy |
| H | **Programme** | can you tell what it is for? | no | roughly | at a glance, and named |
| I | **Palette** | colour relationships and tonal range | monochrome | two hues | a full range with a focal accent |

Axis H scores highest across the board and axis C lowest. That is the shape of
this project: it knows *what* to build and has not started on *how it looks*.

---

## 2. Scores

| | A | B | C | D | E | F | G | H | I | **/45** |
|---|---|---|---|---|---|---|---|---|---|---|
| **House** | 4.0 | 3.5 | 3.5 | 3.0 | 3.5 | 1.5 | 3.5 | 4.0 | 3.5 | **30.0** |
| **Village** | 3.5 | 3.0 | 3.0 | 3.0 | 3.5 | 3.0 | 2.0 | 4.0 | 2.5 | **27.5** |
| **Temple** | 3.0 | 2.5 | 1.5 | 2.0 | 3.5 | 2.0 | 3.0 | 4.5 | 3.5 | **25.5** |
| **Church** | 3.5 | 1.5 | 1.0 | 1.0 | 1.5 | 1.0 | 2.0 | 3.5 | 1.5 | **16.5** |
| **Castle** | 3.0 | 2.5 | 1.0 | 1.0 | 2.0 | 1.0 | 1.5 | 3.0 | 1.5 | **16.5** |

The spread is the finding. House and castle are the same codebase, the same
`MeshKit`, the same `mass_builder`. One is the best thing the system draws and
the other is the worst. The difference is `ShellAssembler.house_materials` and
a timber frame with structure in it.

### House — 30.0

`house_exterior.jpg` is a real building. Half-timbered upper storey on a stone
plinth, jettied, with studs, rails and braces doing visible work; a slate roof
with a ridge, verge and bargeboards; a porch; mullioned windows with sills; a
chimney with pots; a bench against the wall. This is the only image in the set
where every surface has a material.

Deductions:

- **F 1.5** — the cutaways float on a plane. No garden, no yard, no fence, no
  clutter outside. `house_room.jpg` shows the interior and `house_exterior.jpg`
  the shell, and nothing in between.
- **The chimney stands in the middle of the room.** `house_inn.jpg`,
  `house_smithy.jpg`, `house_farmhouse.jpg` and `house_family_cottage.jpg` all
  show the stack as a free-standing rectangular column bisecting a room, with
  the hearth nowhere near it. See S8.
- **Rooms are large and half empty.** Every cutaway shows the same pattern:
  furniture against the walls, a bare middle, and floors at the same value as
  the sky behind them.
- The gable end of the inn carries two black braces that read as loose sticks.
  A king-post truss and a gable window would cost one emitter.

### Village — 27.5

`gate_common.jpg` and `crossroads_common.jpg` are the best pictures the system
makes. A roofscape with spires, chimneys and jetties; a church with an apse and
a spire; a green with a well; a road network with a crossroads; an orchard
around the edge. `strand_actual.jpg` gets the linear form on a river exactly
right.

This is also the proof that **the church generator is good at the wrong scale.**
The same `ChurchGeometry` that produces the 127 m Notre-Dame produces a
perfectly convincing 40 m parish church here, seen at the right distance with
the right neighbours.

Deductions:

- **G 2.0** — the green's stalls are breadcrumbs at this scale, and the orchard
  is a dotted line of identical lollipops around three sides of the site.
- **I 2.5** — the ground is one green with no variation, and the autumn trees
  are a coral that fights everything around it.
- **F 3.0** — the site is a perfect rectangle with a printed tree border, and
  the grey void beyond the ground plane is visible in all five aerials.

### Temple — 25.5

`temple_bloodpit_basilica.jpg` and `temple_ossuary_basilica.jpg` are
atmospheric: raking red and green light down a colonnade, braziers down both
aisles, the idol glowing at the end. The brazier is the best single prop in the
system.

- **H 4.5** — the highest single score anywhere. The gate-to-idol axis is
  unmistakable, which is exactly what `TempleRiteCheck` was written to enforce.
  The pictures and the harness agree.
- **C 1.5 / D 2.0** — the flat wall behind the altar is the largest surface in
  the best temple shot and it is a dead grey field. The altar in
  `temple_coiled_rotunda.jpg` floats in mid-air over the pit.
- **The serpent idol is a stack of green cubes.** Unrecognisable as a cult image.
- **F 2.0** — `_dim()` works for two temples and fails one. See S10.

### Church — 16.5

`detail_crossing.jpg` is the most damning image in the set and it is the one
most like a real photograph. Durham's lantern tower is a squat box with a plain
pyramid and four 2-pixel pinnacles. The buttresses are vertical strips of the
same colour as the wall, glued flat, casting no shadow — painted stripes, not
structure. Below them is one row of twelve identical black rectangles at
exactly one height. The transept gable is a red triangle floating on a white
wall. Roughly 70% of the visible surface is undifferentiated plane.

- **B 1.5** — `detail_flyers.jpg`: the flyer is a thin curved blade with a
  shallow 16%-of-span bow (`bow = |px - wall_x| * 0.16`,
  `church_builder.gd:322`) over a 6-step `arc_ribbon`, with no spandrel, no
  coping and no channel. `detail_dome.jpg`: the pendentives are two flat white
  triangular blades poking *horizontally* out of the drum.
- **C 1.0** — every stone surface is one flat albedo. See S3.
- **D 1.0** — windows are black quads flush with the wall. The rose window has
  tracery; nothing else does.
- **A 3.5** — the long ridge and the crossing spire genuinely compose. The
  north-west elevation of `notre_dame.jpg` is a good building. `hagia_sophia.jpg`
  and `florence_duomo.jpg` are sheds with a hat: a 12–16-sided dome on a 100 m
  plain box, and a 153 m box with two horizontal bands of black dashes.
- `detail_chapels.jpg` is aimed at the roof, not the chevet, and shows no
  chapels. The shot, not the geometry, is the problem — but a shot that cannot
  find its own subject is a finding.

### Castle — 16.5

`castle_stokesay.jpg` is the good one: hipped roofs with real eaves and shadow,
a crenellated gatehouse, four chimneys, a courtyard, a sun angle that lands.

- **A 3.0** — Bodiam, Krak, Chambord, Stokesay and Caernarfon all read as
  plans. `castle_himeji.jpg` has no tenshu and no *kiso-zukuri* stone base; the
  walls run straight to the ground. `castle_neuschwanstein.jpg` is a 5 × 8
  spreadsheet of black dashes on a white box beside a featureless tube.
- **B 2.5** — batter, merlons and drums read. But every tower is the same size
  and shape. `CastleGenerator` produces `great_tower` and `great_tower_scale`
  (`castle_generator.gd:88`) and the silhouette never uses them. See S5.
- **G 1.5** — the bailey is empty. `castle_krak.jpg` is 300 m of curtain around
  a flat tan field. See S9.
- **E 2.0** — Chambord and Neuschwanstein run rows of identical windows with no
  hierarchy, and a concierge's desk of horizontal string courses that reads as
  a car park.
- `castle_caernarfon.jpg`: the corner towers are a mid blue-grey and the curtain
  is near-white, so the towers read as separate objects laid against the wall.

---

## 3. What the light probe showed

Two hypotheses were tested and **both were wrong**, which is worth recording.

**Hypothesis 1: the renderer is the problem.** `project.godot:12` sets
`rendering_method="mobile"`, so `env.ssao_enabled = true` at
`render_shots.gd:511` is a no-op and logs a warning on every single run. The
whole set was re-rendered with `--rendering-method forward_plus`, which brings
SSAO up for real (the warning disappears from the log). **The images are
near-identical.** SSAO on a building whose walls are a handful of large quads,
seen from 200 m, contributes almost nothing. The flatness is not the renderer.

**Hypothesis 2: the key light is fine.** It is not. `_build_stage()` fixes the
sun at `Vector3(-42°, -131°, 0)` while every subject gets its own camera yaw,
so the lighting relationship between light and camera is a lottery. Bodiam,
Hagia Sophia, Chambord, Neuschwanstein, Caernarfon and three of the churches
come out with **no cast shadow at all and no lit/shadowed face split** — flat,
ambient-only, and grey.

The probe (`artifacts/renders/visualqa/sun_probe/`) renders the same Bodiam
spec twice, changing nothing but the light: a warm key at 28° elevation, energy
2.6, and the azimuth swung to 118° off the camera. The planes read, the merlons
cast onto the wall walk, the stone goes cream in light and slate in shade, and
a cast shadow rakes out of frame toward the viewer. Same geometry, same
materials, same camera. See S1.

The probe also exposed a defect that only raking light shows: a black vertical
gash down the left face of Bodiam's square gatehouse — two coplanar faces
z-fighting. See S11.

---

## 4. Suggestions, ranked by impact per unit of work

### S1. Swing the key light with the camera. *~4 lines.*

`_build_stage()` hard-codes one sun; the camera yaw is per subject. Set the key
azimuth from the shot's yaw — 110–125° off camera, 26–32° elevation, warm
(`fff2df`), energy ~2.6, with a cool sky fill opposite at ~0.45. This is the
single highest-impact change in the list and it touches no geometry. The probe
images are the before and after.

### S2. Give openings depth. *One emitter.*

Every church and castle window is a black quad flush with the surface. A
0.12–0.20 m splay plus a projecting sill or hood, in the existing `window()`
path, changes the read of every elevation in both families. The house family
already does exactly this and is visibly a class above.

### S3. Extend the house material shader to the other four families. *One new function beside an existing one.*

`ShellAssembler.house_materials` already ships slate courses, thatch reed,
floorboards and rugs. `render_shots.gd:_shoot_mesh` hands churches, castles and
temples a bare `StandardMaterial3D` with a flat albedo. A `stone_materials`
(coursed ashlar, per-course value jitter, a little dirt at the base) and a
`lead_materials` (sheet lines) beside it would lift 24 of the 41 portraits and
would cost less than the shader that is already there.

### S4. Set the buttresses off the wall. *Two or three stages.*

`detail_crossing.jpg` is the evidence. Coplanar strips in the wall's own colour
cannot read as structure at any light. Two or three stages of decreasing
projection plus a weathering cap is the difference between Durham reading as
Durham and reading as a barn.

### S5. Vary the towers. *The data is already there.*

`great_tower` and `great_tower_scale` are generated and never reach the
silhouette. One corner drum at 1.5–2× the rest is the cheapest silhouette
improvement in the castle family, and it is the single most repeated note about
castle silhouettes in every critique of this project to date.

### S6. Round the hero solids. *Two defaults.*

`MeshKit.revolve` defaults to `segments := 16` and `cone` to 12. The facets are
the loudest "cheap" tell in Hagia Sophia, Florence, St Basil and the rotunda.
32 and 24 on the hero objects only — these are a handful of triangles each.

### S7. Fix the sheet. *Three separate things.*

- `BlueprintView._draw_elevation` draws nave, tower, apse, crossing tower and
  dome, and **omits aisles, aisle roofs, buttresses, flyers, clerestory,
  transept and chapels**. The result is a drawing of a different building from
  the mesh. `sheet_notre_dame.jpg` shows a plain gable where the model has five
  flyers and two aisle rings. Draw them, or caption the elevation "principal
  elements only" and stop implying it is the south elevation.
- `church_generator.gd:143` builds `"%s %s%s"`, so a suffix that does not begin
  with a hyphen jams onto the name. Two of the four rendered sheets are titled
  `Black DenysMinster` and `Abbey AldhelmMinster`. One space.
- Roughly half of each sheet is blank paper, and the plan for a 127 m × 12 m
  building is a 10:1 sliver with the dimension text sitting inside the nave.
  A landscape sheet, or a plan at a larger scale beside a smaller elevation,
  would use the page.

### S8. Put the chimney on the hearth's wall. *One record, two readers.*

The chimney is on the exterior wall; the hearth is placed by
`_place_against_wall` with no term for which wall. The stack then punches
through the middle of a room in every cutaway. Recording
`plan.hearth = {"room": i, "wall": wi}` in the planner and reading it from both
the builder and the furnisher fixes the plan and the picture at once.

### S9. Populate the bailey. *A function that already exists.*

`CastleFurnisher` deals a working yard; the render path does not call it. Krak's
300 m curtain encloses a flat tan field.

### S10. Lift the temple floor. *Three constants.*

`_dim()` drops the sun to 0.35 and ambient to 0.3. `temple_starless_pylon.jpg`
is 90% black and the obelisks, court and idol are invisible. Raise the floor
and put a rim on the idol so the axis the rite check tests is always legible.

### S11. Kill the z-fight on the gatehouse. *One coplanar pair.*

Bodiam's square gate tower shows a black vertical gash under raking light.

### S12. Give the ground plane a world. *Low priority; S1 does most of it.*

900 m, hard edge, grey void beyond, in 30 of the 41 portraits.

### S13. Break the orchard line. *Three lines of variation.*

Height, lean and canopy radius. The lollipop row is the first thing the eye
finds in a village aerial.

---

## 5. Limits of the original review

The original review was visual, but its claim that every structural suite
passed is no longer supported. The castle massing sweep on 2026-09-29 found
pre-existing forebuilding, gate-stair overlap, and tower-house failures, each
reproduced on the pre-aperture build. `CAS-REG-001` restores the planned large
keep and protected entrance in the affected fortress seeds; [focused production
and small-fixture evidence](CAS_REG_001.md) passes. `CAS-REG-002` separates the
nested gate towers and wall stairs in the Crusader fortress; its [production
footprint comparison and 199-check access sweep](CAS_REG_002.md) pass.
`CAS-REG-003` restores the planned 0.32 m tower-house slit rows and updates the
raised-door check to read the existing emitted door record; [fixed-camera
front/raking pairs](CAS_REG_003.md) show the change. The broad castle massing
sweep remains incomplete.
Visual acceptance still needs fixed-camera renders beside the geometry
checks: a log entry or a dark patch cannot prove that masonry was cut.
Routine church geometry edits now have a [bounded change lane](../artifacts/qa_perf_002/README.md)
covering roofs, selected shells, apertures, normals, massing and landmarks.
`QA-PERF-003` [bounded dome clipping](QA_PERF_003.md) and added assembled
Byzantine, Renaissance and Russian fixtures plus three domed landmarks to that
lane. The exhaustive church sweep remains scheduled separately.
Castle geometry now has a [bounded change lane](QA_PERF_001.md) covering fixed
square, round-style, battered, ridge and tower-house builds, aperture rays,
component parity and the nested Crusader gate/stair route. Its 90-second
baseline correctly exposed the tower-house windows missing before `CAS-REG-003`.
Full CastleQA then found two existing interior defects. `CAS-REG-004`
[repaired](CAS_REG_004.md) ridge range doors/windows off their host rooms in
Bavarian 8805. `CAS-REG-005` [repaired](CAS_REG_005.md) a keep stair in the
protected entrance line in Crusader 9250 and 9118. The expanded bounded lane
now passes 195 checks, including full QA on Bavarian 8805 and Crusader 9250,
with five previously known outside-probe warnings under
`CASTLE-NORMALS-WARNINGS`. The exhaustive castle sweep is still unrun after
these changes.

---

## 6. Current audit (2026-09-29)

This section checks the historical suggestions against code at the start of the
visual work. The scores above remain a visual opinion about the original images,
not automated QA results. Recent church and castle commits reorganised planning
and interior code; the mesh and material paths relevant to these suggestions
were largely unchanged. The reference portraits still showed the church and
castle gap. The initial audit was read-only; this table now records subsequent
generator and render changes as their todos land.

| Claim | Current finding | Work |
|---|---|---|
| S1, lighting | The original `render_shots.gd` fixed the sun while camera yaw varied. SSAO on the mobile renderer was not the missing geometry. | `VIS-001` now records camera-relative lighting and [paired acceptance renders](../artifacts/renders/visualqa/acceptance/README.md); the remaining flatness is in the building. |
| S2, openings | Church and castle window routines placed shallow dark boxes against intact masonry. Castle planned interiors and the gate tunnel already have real openings. Bodiam and Krak's fixed landmark seeds both use planned shell keeps with 40 planned windows, so their keep windows were never on the legacy drum path. | `VIS-005` cuts Gothic nave clerestory openings and west portals through their nave and twin-tower host walls. [Fixed-camera detail pairs](../artifacts/renders/visualqa/vis005/README.md) and ray checks show the depth. `VIS-012` gives those cut windows a pointed stone head and leaded glazing, and leaves the moulded west entrances deliberately open; [paired detail views](../artifacts/renders/visualqa/vis012/README.md) show the finish. `VIS-011` cuts representative aisle, transept, apse, chapel, tower, narthex, drum and rose hosts; [front and raking evidence](../artifacts/vis011/README.md) includes rays through the stone and blocked adjacent piers. `VIS-014` aligns narthex, single-tower and nave entrance cuts into a complete route; [front, raking and interior pairs](../artifacts/vis014/README.md) and 930 focused checks show the result. `VIS-006` cuts a straight and polygonal curtain slit, a battered tower facet, and a square keep window; [fixture and castle views](../artifacts/vis006/README.md) plus all-surface rays distinguish the aperture from a dark insert. `VIS-013` cuts windows in the unplanned round and shell keep fallback; [fixture pairs](../artifacts/vis013/README.md) show its local effect. |
| S3, surfaces | Church and castle portraits used flat `StandardMaterial3D` overrides. The former box UVs restarted on each triangle and revolved faces had constant UVs. | `VIS-003` gives boxes, sloped faces, drums and partial sweeps metre-scale coordinates, confirmed by a [swatch](../artifacts/vis003/metric_coordinates.png) and mesh assertions. `VIS-004` applies restrained stone courses and roof tiles in both runtime assemblers. [Fixed-camera comparisons](../artifacts/renders/visualqa/vis004/README.md) show clearer scale without distant pattern noise. Temples and hotels still use flat materials. |
| S4, buttresses | They already projected from the nave and had caps. Their thin, same-colour shape read poorly at portrait scale. | `VIS-007` adds three stepped shaft stages and shoulders, corrects twin-tower corner placement, and gives Gothic flyers a heavier arch and coping. [Fixed-camera Durham and Notre-Dame pairs](../artifacts/renders/visualqa/vis007/README.md) show a clearer bearing rhythm; the change remains subtle at whole-building scale. |
| S5, great tower | The generated great-tower index and scale already reach `CastleBuilder._tower` through `CastleGeometry`. `CAS-002` completed this work. | No duplicate tower-wiring task. |
| S6, hero curvature | Hero dome call sites choose explicit segment counts. Changing `MeshKit` defaults would miss them; Florence's eight-sided form is intentional. | `VIS-008` closes the square-to-drum support loft, uses 32 radial sides on Hagia's hero shell, and smooths the vertical profiles of Hagia and Florence while preserving Florence's eight sides. [Fixed-camera pairs](../artifacts/vis008/README.md) show the visible change. `QA-PERF-003` [bounded dome clipping](QA_PERF_003.md) and added assembled dome cases to the 5,388-check church change lane. The exhaustive church sweep has not been rerun since that fix. [Current Hagia detail views](../artifacts/qa_perf_003/README.md) still show a schematic, flat-sided support partly hidden by adjoining roofs; `VIS-016` tracks that remaining bearing-form work. |
| S7, blueprint | Elevations still omit major visible church parts; the variant-name format still joins some suffixes. | `VIS-010`, after the higher-impact building portraits. |
| S8, hearth | `HousePlan.hearth` already records the room and wall, and builder/furnisher read it. The proposed missing-record cause is obsolete. | No duplicate house task; inspect any remaining bad cutaway by seed and camera. |
| S9, bailey | `CastleBuilder` already dresses via `CastleFurnisher`, and `INT-006` added bailey ranges and a well. The former `render_shots.gd` path photographed only the mesh, hiding props and interiors. | `VIS-002` now photographs the assembled scene and adds a [Krak courtyard comparison](../artifacts/renders/visualqa/scene/README.md). Four ranges and a well exist; the court still reads sparse at fortress scale. `VIS-015` measures exterior yard use, circulation and same-camera improvement. |
| S10, temples | `_dim()` controls the dark stage. The coiled idol silhouette needs separate art work; the rotunda altar is built on a dais, so a floating altar is unproved. | Outside the church/castle priority. |
| S11, Bodiam seam | A black image mark does not identify the alleged coplanar triangle pair. | Gather triangle/raking-light evidence before a geometry fix. |
| S12, ground | The reference stage still uses a finite plain ground plane. | Lower priority than structure, openings and material. |
| S13, orchard | Tree position and yaw already vary; size/model repetition remains. Size changes must update measured canopy and trunk bounds. | Outside the church/castle priority. |

Himeji's keep is emitted, yet its silhouette remains weak in the current portrait.
`CAS-010` is already executing the terraced ground and raised tenshu work. The
Neuschwanstein/Chambord facade hierarchy is separate work in `VIS-009`.
