# Sacred review: the processional sequence (LIVE-SACRED)

Household density rules do not apply to churches and temples. Sparse floor is
accepted when the brief explains it: a chancel is empty so the priest can
kneel; a temple hall is empty so a congregation can stand. What is judged
instead is the SEQUENCE: gate, aisle or colonnade, focus.

## The frozen matrix

`tests/fixtures/sacred_sequence_requests.json`, 49 public requests, each
generated through `BrickWild.generate` as a consumer would:

* churches: six styles (romanesque, gothic, byzantine, nordic_stave,
  renaissance, russian) at small 8x14x7, default 10x22x12, large 16x48x24,
  seeds 1 / 8102 / 21325, plus a second default seed;
* temples: four forms (basilica, pylon, ziggurat, rotunda) at small 18x24x8,
  default 26x44x12, large 48x80x20, two cults each, cults and seeds rotated so
  all five cults and all three seeds appear;
* the pinned barn-like basilica: timber basilica / blood, seed 1, 26x44x12.
  The walk-QA rated it "looks like a barn" on 2026-10-06 and 2026-10-07
  (`visualqa/HumanRate.md`). It is the comparison point: its sequence passes
  like the others (procession 2.88 m, idol visible, axis run 45.6 m); what is
  wrong with it is exterior identity, which no ray can judge.

## What is asserted (`-- sacredseq`, also in `lane:temple` and `lane:church-change`)

| question | temple | church |
|---|---|---|
| axis | `TempleRiteCheck` axis | `SacredSequenceCheck`: altar and door on the centre line, altar down the nave |
| focus visible | rite sightline: eye at the gate to the idol, against every mass and column | ray from the eye inside the door to the altar top, against floor-standing props and pier/column/screen components |
| processed | rite procession, 2.4 m | one `WalkGrid`, door to the altar foot, at least 1.0 m clear |
| congregation | rite congregation | standable share of the nave zone, and seating exists |

Church checks live in `qa/sacred_sequence_check.gd` and use
`TempleRiteCheck.axis_faults`, `sightline_blockers` and `WalkGrid`; there is no
second distance transform.

## Negative controls (each must FAIL, on the named rule)

* hides the focus: a tall veil across the axis (temple), a screen across the
  nave (church) -> `sightline`;
* breaks the axis: a file of columns across the hall (temple), a wall of pews
  across the nave (church) -> `procession`; the altar shifted 1.5 m
  off-centre (church) -> `axis`.

One pair per style/form, on the default size.

## What the matrix found

The altar rail's finishing posts stood inside the aisle: the gate through the
rail was 0.78 m against the 1.5 m nave aisle, in every church. Posts now stand
outside the aisle (`ChurchFurnisher._dress_rail`); procession is 1.32 to 1.44 m.

## Exterior review, 2026-10-14

Tool: `tools/render_sacred_exterior.gd` (not headless; `-- --out=res://... --ids=<matrix ids>`),
front / side / rear roof-on portraits through `BrickWild.generate` + `instantiate`.
Before: `artifacts/sacred_exterior_20261014/before/`, after: `.../after/`
(gitignored artifacts; paths relative to the repo).

Verdicts, by matrix id (default size unless stated):

* `temple/basilica/blood/default/1/pinned-barn` (before): a long brown shed. The
  pronaos gable was a bare dark triangle, the roofline a flat line, a 12-bay
  flank of identical pilasters. Still reads as a barn. A podium of 0.66 m is
  present but invisible at portrait distance.
* same (after): the pronaos gable now carries a trim base cornice, a lozenge
  emblem, a tall apex acroterion and two eave-corner acroteria
  (`_build_basilica_pediment_dress`). From the front it reads as a pedimented
  temple front, and the skyline is no longer a straight line. Verdict: better,
  not finished. The long flank remains plain; the roof is a low dark slab.
* `temple/basilica/flame/default/8102` (has a lantern): reads as a basilica with
  a bell-cote; the new pediment dress helps the entrance. Acceptable.
* `temple/pylon/serpent/default/8102`: strong identity (pylon towers, battered
  faces, cut gate). Roof of the hall is a flat black slab. Acceptable.
* `temple/ziggurat/void/default/8102`: identity clear (terraces, central stair);
  the shrine on top is a small cone, a little thin. Acceptable.
* `temple/rotunda/blood/default/8102`: drum with a colonnade above and a flat
  ring roof; reads as a rotunda but the hollow open top is odd from outside.
  Needs a look (open oculus intended; the colonnade is exposed).
* `church/gothic/default/1`: tower with a stepped-block "spire" (reads as a
  ziggurat of boxes), tiny paired lights, bare white walls, no pinnacle line
  along the nave, buttresses are three short fins. Short of
  `visualqa/styles/church/gothic/targets/design_board_v1.png`: the board has a
  true spire, tall traceried windows, a faceted chevet with pinnacled buttresses
  and rubble stone. NOT improved this pass.
* `church/romanesque/default/1`: rendered, not reviewed in depth.

Not done on purpose: a taller podium. PODIUM_STEPS 4 x 0.27 raised the
architecture fixture's visible coplanar overlaps from 8/8/10 to 10/12/12 (budget
12) for a change that cannot be seen at portrait distance; reverted.

Receipts: `lane:temple` 3409 checks / 0 failures / 4 known rotunda warnings;
`lane:temple-contract` 3274 / 0 / 0; `sacred_basilica_architecture_test`
0 failures, overlaps 8/8/10 (unchanged).

## Not yet done

Gothic exterior (true spire, traceried windows, pinnacled buttresses), the
basilica's plain flank and low roof (colour or relief per bay, a clerestory
hip), a roof-on look at all 49 matrix ids, and focal visibility from the
congregation zone as an image.

## Gothic exterior pass (2026-10-14, second increment)

Changed (src/church/church_builder.gd, church_geometry.gd), Gothic only:

* The tower roof (`spire` and `pyramid`) is now `_gothic_spire`: a corbelled
  cornice, four corner pinnacles, a short octagonal drum, then an eight-faced
  tapering spire (five-ring profile, true apex) with crockets on the ridges.
  Same total rise as before, so `tower_roof_rise()` and the height contract are
  unchanged. The box-stepped "ziggurat" spire and the stepped twin-tower caps
  are gone.
* Clerestory lights are wider (64% of the bay pitch, band-limited) and nave bay
  lights taller and wider (to 46% of nave height); both are still cut through
  the wall surface by the existing opening path.
* A flyerless Gothic nave gets a pinnacle on each stepped buttress; with flying
  buttresses the flyer pier pinnacles already carry the line and the arcs cross
  that cap, so none is added.

Renders (roof on, front / side / rear), before in
`artifacts/gothic_20261014/before/`, after in `artifacts/gothic_20261014/after/`,
ids `church/gothic/default/1` and `church/gothic/large/21325`.

Verdict, honest: the silhouette is now Gothic. Default 1 reads as a church with
a spire instead of a stack of blocks, and the large twin-tower west front now
ends in pinnacled octagonal caps. The large clerestory is visibly glazed. It is
STILL short of the design board: walls remain smooth pale stone with no rubble
or relief, the windows have no tracery (a pointed head and nothing in it), the
default-1 aisle lights barely changed (band-limited), the chevet is plain
cylinders against the board's faceted pinnacled chevet, and there is no
parapet or pinnacle line along the nave eaves. Not accepted as complete.

Receipts: lane:church-change 5926 checks / 0 failures / 16 warnings (12 known
opening + 4 sacredseq); visible coplanar overlaps (church warnings, not
budgeted for churches) Gothic small/default8102/large/default1 before
69/74/77/72, after 69/78/77/74.

## 49-id roof-on matrix review (2026-10-14)

Every id of `tests/fixtures/sacred_sequence_requests.json` was rendered roof on
through the public API and every contact sheet was read by eye:

```
godot --path . --script res://tools/render_sacred_exterior.gd -- --out=res://artifacts/sacred_matrix_20261014/renders
python -I tools/sacred_contact_sheets.py artifacts/sacred_matrix_20261014/renders artifacts/sacred_matrix_20261014/sheets
```

`render_sacred_exterior.gd` now also takes `--views=front,side,rear,entry`.
`entry` is a first-person view at 1.65 m from the first reached floor inside the
door (the same `WalkGrid` flood the acceptance tool uses, so the eye is on
reached floor), aimed at the altar prop (church) or the idol (temple). A
ziggurat is lit with the dusk rig, because the night rig blacks out its stair
walls. Images are not committed. Each id has a 2x2 sheet
`artifacts/sacred_matrix_20261014/sheets/<slug>.jpg` (front, side, entry, rear)
and singles `renders/<slug>__<view>.jpg`; `<slug>` is the id with `/` as `_`
(for example `church_gothic_default_1`).

Tallies: 31 accepted, 18 needs_changes (churches 10 / 14, temples 21 / 4). After the 14 Oct stave pass: 34 accepted, 15 needs_changes (churches 13 / 11). After the seating increment (two-abreast pew blocks, chancel step, scaled altar group): renaissance_large and nordic_stave_large move to accepted: 36 accepted, 13 needs_changes (churches 15 / 9). Russian rows still cite the floating blocks fixed on 14 Oct (SACRED-RUSSIAN-FLOATING-BLOCKS); re-review them before counting.
Accepted means "reads as its family, the way in leads to the focus, the focus
is visible from the entry". It does not mean "matches the design board"; the
Gothic and basilica notes above still stand. Sparse floor in the temples and
the empty chancel in the churches are accepted where the brief names them.

Columns: Identity = exterior identity (yes / partly / no); Entry = entry and
procession; Focus = focal visibility from the entry image. The slug is
`church_` or `temple_` plus the first column.

### Churches

| Id | Identity | Entry | Congregation | Focus (entry image) | Verdict |
|---|---|---|---|---|---|
| romanesque_small_1 | partly: round apse, lombard pilasters, but square windows and the west tower ends in stepped blocks and bare posts | door in tower base, straight nave, pews to the rail | two pew blocks either side of the aisle, empty chancel (brief) | altar and candles clear at the end of the aisle, apse lights above | needs_changes: tower crown reads unfinished (todo SACRED-TOWER-CROWN). **Re-ticked 2026-10-24 on ed96101: approved; cornice and pyramidal cap seated, no stepped blocks or posts** |
| romanesque_default_8102 | partly: tower, apse, gable porch read Romanesque; flat uncapped tower | door, aisle, apse | pews both sides, empty chancel | altar visible under the chancel arch | accepted |
| romanesque_large_21325 | no: a 24 m gabled box, pilasters and two tiny slit windows, no tower, no apse visible from the front | door in a blank gable, then the nave | FIXED 14 Oct: two benches abreast either side of a 1.5 m aisle, 33 rows, cross-aisles | FIXED 20 Oct: a built reredos (dark ground, pale panels, frames, cross, 6.7 x 10.6 m) on the east wall behind the altar, red banners either side on the wall face; reads at once from the door | FIXED 24 Oct (SACRED-ROMANESQUE-LARGE): the dice gave this seed no tower, so `ChurchGenerator._ensure_west_front_mass` now guarantees a single west tower (0.55 of the width, 1.7 of the wall height, hipped cap) on any Romanesque 14 m wide or more; the apse is east and the nave hides it, so the tower is the front mass. `churchchange` casts rays from the front 3/4 camera at the tower faces (visible fraction >= 0.6, with a wall-in-front control). Render: artifacts/goal/SACRED-ROMANESQUE-LARGE/after. needs an independent reviewer tick |
| romanesque_default_1 | partly: as small/1, with a row of tall lights on the flank | door, aisle, apse | pews both sides | altar and candles clear | needs_changes: same tower crown fault (SACRED-TOWER-CROWN). **Re-ticked 2026-10-24 on ed96101: approved; crown seated** |
| gothic_small_1 | yes, 20 Oct: the twin towers now end in octagonal spires with crockets and finials (every Gothic tower draws `spire`); round chevet, pointed lights | portal in the west front, aisle, apse | pews both sides | altar and candles clear, three apse lights | accepted |
| gothic_default_8102 | yes: twin octagonal spires, flying buttresses, clerestory | portal, aisle between piers | pews both sides, aisles beyond the piers empty | altar clear at the end | accepted (design-board gaps in the section above stand) |
| gothic_large_21325 | yes: tall twin towers, flyer arcade, glazed clerestory | portal, long aisle | pews from the first bay, aisles empty | altar small but readable, apse arch above it | accepted |
| gothic_default_1 | yes: single tapering spire, flyers on the east bays | portal in tower base, aisle | pews both sides | altar and candles clear | accepted |
| byzantine_small_1 | yes: dome on a drum over a gabled cross-body, low apse | door, aisle, apse | pews both sides | altar clear, apse arch frames it | accepted: partly Byzantine, the dome sits over a basilican body |
| byzantine_default_8102 | yes: as small, with pilasters | door, aisle | pews both sides | altar clear | accepted |
| byzantine_large_21325 | partly: dome pushed to the east end of a long barn body, flat flank | door in a blank gable, aisle | Orthodox standing worship: open floor intentional, 14 wall stalls | 20 Oct: reredos (an iconostasis-like screen) and banners behind the altar group; the focus reads from the door | FIXED 24 Oct (SACRED-BYZANTINE-DOME): from 1.6 m on the axis a 24 m nave and its ridge hide any dome east of centre, so `ChurchGenerator._ensure_entry_dome` moves the dome of a domed Byzantine 14 m wide or more over the west bay (`spec.dome_west`, `ChurchGeometry.west_dome_center_z`), drops the transept and half-domes, and grows the drum until the shell crown clears the west gable peak on the sight line from `ChurchGeometry.entry_eye` (20 m west of the narthex). `churchchange` ray-tests five seeds, with a raised-gable control and an east-dome control. Render: artifacts/goal/SACRED-BYZANTINE-DOME/after/church_byzantine_large_21325__approach.jpg (also __front). needs an independent reviewer tick |
| byzantine_default_1 | yes | door, aisle | pews both sides | altar clear | accepted |
| nordic_stave_small_1 | yes, 14 Oct stave pass: tarred dark boards, steep shingle roofs, a three-tier tower of shingled hips ending in a needle spire with crossed boards, a covered svalgang along the flanks, dragon heads on the ridge ends. Still a west tower on a plain nave (no stepped nave roofs, no ridge turret) | door at the foot of the tower, aisle | pews both sides | altar clear in a dark plank hall | accepted: reads as a Scandinavian timber church, not a Borgund copy |
| nordic_stave_default_8102 | yes: as small | as small | pews both sides | altar clear at the end of a long dark hall (dim) | accepted |
| nordic_stave_large_21325 | yes outside: as small, svalgang runs the whole flank; nave roof still one big plane | door, aisle into a huge hall | FIXED 14 Oct: pew blocks fill the nave from the chancel step to the door | altar group on its step, candelabra and candles visible down the aisle | accepted (stave identity and seating both fixed 14 Oct) |
| nordic_stave_default_1 | yes: as small | as small | pews both sides | altar clear | accepted |
| renaissance_small_1 | partly: dome with lantern, pilaster cornice; no pediment or orders | door with a small porch, aisle | pews both sides | altar clear under a round arch | accepted |
| renaissance_default_8102 | partly: dome, lantern, twin stepped tower crowns, round-headed lights | door, aisle | pews both sides | altar clear | accepted |
| renaissance_large_21325 | partly: rose window, dome and a lean-to roof read Italian; flank is a long blank wall | door, long aisle | FIXED 14 Oct: 112 pews in two-abreast blocks to the chancel step, cross-aisle every eighth row | altar group on its step, scaled, candelabra and candles read at the end of the aisle | accepted (seating and focus; exterior as before) |
| renaissance_default_1 | partly: dome and lantern, stepped tower | door, aisle | pews both sides | altar clear | accepted |
| russian_small_1 | partly: one squat onion dome, round chevet; no cluster of domes, no kokoshniki | door in tower base, aisle | pews both sides | altar clear | needs_changes: floating blocks on the nave walls (SACRED-RUSSIAN-FLOATING-BLOCKS) and the tower crown fault. **Re-ticked 2026-10-24 on ed96101: approved; slab, lantern and onion seated, turrets attached, no floating blocks** |
| russian_default_8102 | partly: as small | door, aisle | pews both sides | altar clear | needs_changes: both defects as above. **Re-ticked 2026-10-24 on ed96101: approved; crown seated, no floating blocks** |
| russian_large_21325 | partly: one onion dome on a box, two half-round buttress turrets | door, aisle | Orthodox standing worship: open floor intentional, wall stalls only | 20 Oct: reredos and banners behind the altar group, readable from the door; no floating blocks in the nave (fixed 14 Oct under SACRED-RUSSIAN-FLOATING-BLOCKS, re-reviewed 20 Oct) | accepted (identity partly, as renaissance) |
| russian_default_1 | partly: as small | door, aisle | pews both sides | altar clear | needs_changes: both defects as above. **Re-ticked 2026-10-24 on ed96101: approved; crown seated, no floating blocks** |

### Temples

| Id | Identity | Entry | Congregation | Focus (entry image) | Verdict |
|---|---|---|---|---|---|
| basilica_blood_small_1 | yes: pedimented pronaos, clerestory, apse | portico, orange inlay down the axis | open hall floor with braziers either side (sparse is the brief) | altar and idol under the apse arch, clear | accepted |
| basilica_bone_small_8102 | yes: as above plus a belfry | as above | open floor, very dark | idol lit and clear at the end; columns near-black | accepted |
| basilica_flame_default_8102 | yes: long hall, pediment, belfry | portico, inlay, colonnade | braziers between colonnade and aisle | idol small but clear | accepted |
| basilica_serpent_default_21325 | yes, re-rendered 20 Oct with its real cult: green trim and inlay, a coiled serpent idol (the 14 Oct images were flame; see "Cult identity was the render tool") | as flame | as flame | coil idol clear under the apse arch | accepted |
| basilica_void_large_21325 | yes: long, with a belfry; flank is a plain window grid | portico, inlay | long floor, braziers | idol tiny, camera sits against a column but the axis is clear | accepted |
| basilica_blood_large_1 | yes: pedimented pronaos on a long hall | as above | braziers in two lines | idol clear under the apse arch | accepted |
| basilica_blood_default_1_pinned-barn | yes: pronaos and apse; flank is long and plain (the known barn comparison) | portico, inlay | open floor, braziers | idol visible, hall very dark | accepted as the comparison id; the flank is still plain |
| pylon_bone_small_1 | yes: two tapering pylons, gate, wall behind | gate between the pylons, hall of columns | open floor, braziers | altar and idol framed by the far gate | accepted |
| pylon_bone_large_1 | yes: pylons dwarfed by a long blank box | gate, long hypostyle | open floor | altar clear at the end | accepted |
| pylon_flame_small_8102 | yes | gate, columns | open floor | altar and idol clear | accepted |
| pylon_serpent_default_8102 | yes | gate, columns | open floor, nearly black | idol lit, clear | accepted |
| pylon_void_default_21325 | yes | gate, columns | open floor, nearly black | idol lit, clear | accepted |
| pylon_blood_large_21325 | yes | gate, long hall | open floor | idol small but clear | accepted |
| ziggurat_flame_small_1 | yes: three tiers, a stair, a cone idol on top | foot of the stair, two gate frames | the paved forecourt is the congregation (brief) | altar rail visible through the lower gate; the idol is not visible from the foot | accepted |
| ziggurat_serpent_small_8102 | yes | as above | as above | as above | accepted |
| ziggurat_void_default_8102 | yes | foot of a longer stair | forecourt | altar a thin sliver through the gate | accepted: marginal |
| ziggurat_blood_default_21325 | yes | as above | forecourt | altar a thin sliver through the gate | accepted: marginal |
| ziggurat_bone_large_21325 | yes; with the right cult (20 Oct) a pale bone cairn on the summit | foot of a long stair canyon | forecourt | the god is hidden: measured 20 Oct, an apex 39.6 m high would clear the summit edge from the stair foot; it has 23.4 m | needs_changes: the summit god stands at the back of a 56 m summit; see "Ziggurat focus, measured" |
| ziggurat_flame_large_1 | yes | as above | forecourt | as above (needs 39.6 m, has 23.4 m) | needs_changes: same |
| rotunda_serpent_small_1 | partly: drum with open pier clerestory and a thin ring roof; reads as an arena | door in the drum with a framed porch | open floor, braziers round the pit | altar and cone idol large and central | accepted |
| rotunda_void_small_8102 | partly: as above | door | as above | altar and idol clear | accepted |
| rotunda_blood_default_8102 | partly | door, a plain frame | open floor, a pit either side of the path (the pit is in the brief) | altar and idol clear across the pit | accepted |
| rotunda_bone_default_21325 | partly | as above | as above | clear | accepted |
| rotunda_flame_large_21325 | yes, 20 Oct: a pedimented aedicule in the cult trim (pilasters, entablature, dark tablet, dark tympanum under raking cornices) frames the 5.5 m gate; reads from across the forecourt | door | wide open floor | idol clear, altar rail visible | accepted |
| rotunda_serpent_large_1 | yes, 20 Oct: as flame, in serpent green, with the coiled serpent idol | as above | as above | coil idol clear in the centre | accepted |

Images per id: `artifacts/sacred_matrix_20261014/sheets/<slug>.jpg`, with
singles `renders/<slug>__front.jpg`, `__side.jpg`, `__entry.jpg`, `__rear.jpg`.
The ziggurat entry singles were re-shot with the dusk rig; the sheets were
rebuilt afterwards.

### Most common faults

1. Large churches (romanesque, byzantine, nordic stave, renaissance, russian at
   16 to 24 m wide) are blank gabled boxes. The pew block is a small cluster far
   from the door, the west half of the floor is bare and not explained by the
   brief, and the altar is a washed-out speck. Furnishing and the entry
   station do not scale with nave length. 5 ids.
2. Nordic stave never read as stave (pale stone-textured walls, a black
   stepped-block spire). FIXED 14 Oct: tarred timber, a shingled three-tier
   tower with a needle spire, a svalgang, dragon heads and crossed boards;
   renders in artifacts/stave_20261014 (before/after). Left: no stepped nave
   roofs or ridge turret; large size still has the furnishing fault in 1.
3. Towers with an unfinished crown (flat deck, stepped red blocks, bare posts):
   Romanesque and Russian. Filed as SACRED-TOWER-CROWN.
4. Russian nave interiors carry floating brown blocks. Filed as
   SACRED-RUSSIAN-FLOATING-BLOCKS.
5. Ziggurat at large size: the altar is a slit at the top of the stair canyon
   and the idol is out of sight from the foot. 2 ids.
6. WITHDRAWN 20 Oct (the render tool rendered every temple as flame; see "Cult identity was the render tool"). Was: cult identity is only a tint: every cult has the same orange cone idol and
   the same braziers, so a serpent temple cannot be told from a flame one.
   Not counted in the verdicts above except as a note.
7. Large rotunda: a 1.2 m door flush in a 24 m blank drum. 2 ids.
8. Gothic small has no Gothic silhouette (squat domed towers). 1 id.

## Seating the large naves (2026-10-14, LIVE-SACRED increment)

Fault: in the five large churches (16 x 48 m nave) the furnisher put one bench
per side in a 16 m hall, capped the rows at 30 (about 34 m of a 48 m nave), and
set the altar at the 2.85 m house scale, so the pews were a thin strip, the west
floor was bare and the altar was a speck.

Change (`src/church/church_furnisher.gd`, `ChurchGeometry.chancel_step_rect`,
`ChurchBuilder._build_floor`):

* Pew blocks: as many benches abreast as the half-nave holds (a 0.9 m side
  aisle between them), the row cap raised 30 to 60, and every ninth slot left
  open as a cross-aisle on a wide, long nave. The centre aisle stays 1.5 m and
  the rail gate stays 1.44 m. The churches have no side doors, so the cross-aisle
  is simply a mid-nave passage. Narrow and default naves have a single block
  and no cross-aisle: their layout is unchanged.
* Chancel: a 0.15 m stone step (mesh, 3.8 m deep from the east wall) carries
  the altar, candelabra, floor candles, lectern, brazier and rail. The altar
  group is scaled by nave width (1.0 to 1.5x) so it reads from the door. A
  banner pair is hung either side of the altar (a reredos) in a wide nave.
* Orthodox (Russian, Byzantine): standing worship has no pews. When the nave is
  wide enough for a pew congregation, the floor is deliberately left open and
  the only seating is one stall at a time along each side wall, facing across the
  nave (pew-kind, so the congregation rule still finds somewhere to sit). That
  is the brief's intentional empty space, not a defect.

Gates: dressingquick 72221 checks, 0 failures (first attempt: 66, benches buried in the chancel step and the engaged piers, a lectern against the rail; the outer block now stops a pier projection short of the wall and the rail and step stand 0.4 m further west in a wide nave). lane:church-change 5942 checks, 0 failures, 16 warnings (the 12 known
opening warnings and 4 sacredseq warnings); chwalk 125 / 0 (a first attempt made
the baker and the grid disagree about a 0.4 m pocket between the scaled altar
and the brazier, 22 stranded vertices; the reader and the fire now stand a body
width clear of the larger altar). Renders: artifacts/church_seating_20261014/
before and after. Still open: the altar remains small at the far end of a 46 m
nave, and the reredos banners are not visible from the door.

## Focus, gate and silhouette pass (2026-10-20, LIVE-SACRED)

Renders: `artifacts/live_sacred_20261020/before/` (7 ids, before) and
`artifacts/live_sacred_20261020/after/` with sheets in `.../sheets/` (all 25
temples, the six large churches, the four Gothic ids). Gitignored.

### The far altar: a built reredos, and banners nobody had seen

At 46 m the scaled altar group was still a speck against a bare pale east wall.
The 14 Oct "reredos" banner pair was never visible at all: a banner is
WALL_MOUNTED, so its position is its TOP, and it was placed with its top at
1.45 m (3.8 m of cloth hanging through the floor) and its plane at
length/2 - 0.12, i.e. 0.24 m inside the 0.36 m east wall. The nave banners and
torches had the same fault on the side walls (width/2 - 0.12).

* `ChurchGeometry.reredos_aabb` / `ChurchBuilder._build_reredos`: on a nave
  wider than 10 m with a solid east wall (no apse arch, no hero, a chancel
  step), a screen 0.42 x nave width by 0.44 x nave height (6.7 x 10.6 m on a
  16 x 24 m nave) stands on the step against the east wall: a dark ground (the
  opening slot), pale panels, frames, predella, cornices and a cross (trim),
  every piece a named component inside the declared box. It uses the existing
  four surfaces: a first version on the painted accent slot (crimson and gilt)
  read better, but gave the sweep a fifth surface (the `church` suite requires
  four) and tripped the floating-block guard. Rather than loosen either, the
  screen was moved to the existing slots.
* The banner pair now hangs on the east wall's face either side of the screen,
  from the screen's cornice to 1.6 m above the step; none where the east wall
  is an apse arch. Side-wall banners and torches hang on the wall face.
* `DressingCheck` now also fails a wall-mounted piece that hangs below the
  floor; the old rule (top above 0.8 m) passed the buried banners.

Verdict, by eye from the door (entry views): romanesque, renaissance,
byzantine, russian and nordic stave large all show the screen, cross and
banners at the end of the aisle. The focus now reads. Gothic large keeps its
apse arch (no screen there) and was already accepted.

### The large rotunda door

`TempleBuilder._build_rotunda_aedicule` (outer radius >= 18 m only): two
pilasters on bases with capitals, an entablature, a dark tablet over the door,
a dark tympanum and two raking cornices, in the cult trim, round the existing
5.5 m gate. Every back runs into the drum at the piece's outermost x, so no
edge floats off the curve; nothing projects past `rotunda_front_projection`.
No masses are logged (as with the existing surround), so the rite and the
overlap QA are unchanged. Both large ids now read as a pedimented entrance from
across the forecourt.

### Gothic small silhouette

Gothic `towers_roof` is now `[spire, spire]` (two entries, so the generator's
random draw is unchanged): every Gothic tower ends in `_gothic_spire` at the
spire rise. Gothic small/1 now has twin crocketed spires; large/21325 has a
twin-spired west front. Accepted.

### Cult identity was the render tool

The matrix stores the cult as `purpose`; `render_sacred_exterior.gd` read
`r.get("cult", &"flame")`, so every temple of the 14 Oct review was rendered as
a flame temple. The tool now builds the request with
`BuildingRequest.from_dict`, as `sacredseq` does. Rendered correctly, the cults
differ in trim, inlay, braziers and idol (serpent: green trim and a coiled
serpent; bone: pale trim and a skull cairn; blood: a figure; void: a leaning
monolith; flame: a pyre). Fault 6 ("cult identity is only a tint") is
withdrawn.

### Ziggurat focus, measured (not fixed)

From the stair foot (`TempleGeometry.sight_point`, eye 1.65 m), the summit god
is hidden behind the summit's own front edge at EVERY size. The apex height that
would clear the highest terrace edge against the apex each ziggurat has:

| ids | summit (z from - to) | idol z | apex needed | apex has |
|---|---|---|---|---|
| small | -7.5 to 7.5 | 5.6 | 11.2 m | 9.4-9.6 m |
| default | -15.5 to 15.5 | 13.6 | 21.8 m | 13.5 m |
| large | -28 to 28 | 24.3 | 39.6 m | 23.4 m |

The god stands at the back of the summit (`idol_center`, behind the chamber
altar on the same axis), and the rite sightline cannot see the problem because
`TempleRiteCheck._exempt_from_sightline` exempts every `terrace` mass. No
dressing fixes this. For a large ziggurat the summit's front edge would have to
move from z = -28 to about z = -1.5 (and terrace 1 from -34 to about -24),
i.e. upper terraces set back more at the front than at the sides, with the
stair flights re-run to the new summit edge. Then the terrace exemption can be
removed from the sightline rule. That is a reshaping of the form, left open.

### Ziggurat focus, fixed (24 October 2026, SACRED-ZIGGURAT-FOCUS)

The god no longer stands at the back of the summit. `TempleGeometry.ziggurat_idol_limit`
finds the furthest-back centre from which the eye at the stair foot (1.65 m) still
clears the front edge of every terrace and sees the idol's upper half; the sanctum
(chamber dais, altar) is anchored under that point, so gate, altar, idol still run
in order. `TempleRiteCheck` no longer exempts `terrace*` and `stair*` masses from
the sightline for a ziggurat. Measured with `tools/sacred_sequence_report.gd`:
`sightline_blockers` 0 for small/1, default/21325 and large/21325 (axis run 7.5 /
8.4 / 17.2 m, procession 6.08 m). Idol apex is unchanged (9.6 / 13.5 / 23.4 m), so
the god shows ABOVE the summit's front edge as a small silhouette, not a full
figure: entry renders in `artifacts/goal/SACRED-ZIGGURAT-FOCUS/renders`. A negative
control (`stair_wall_control`, a wall across the axis between the foot and the
summit) is in `sacred_sequence_suite` and must fail on `sightline`. The "open
failure 1" above is closed; legibility at large size (a ~5 percent silhouette) stays
modest and is the next lever if a taller idol is wanted.

### Rotunda void monolith, fixed (24 October 2026, SACRED-ROTUNDA-FOCUS)

Cause: the void cult's stone is `2f3138`/`1b1d22` and the monolith was a SURF_STONE
slab, so it was the same tone as the drum behind it. In the old entry image
(`artifacts/goal/SACRED-ROTUNDA-FOCUS/before/temple_rotunda_void_small_8102__entry.jpg`)
nothing stands above the altar: the monolith is simply absent. The slab is now the
cult's lighter trim hue (`46506b`) with a black rune cut down its face
(`TempleBuilder._build_idol`, `&"monolith"`). After
(`.../after/temple_rotunda_void_small_8102__entry.jpg`): a pale blue-slate slab,
about 1.3 altar-widths wide, rises from the altar to above the drum wall line,
lighter than the near-black brick on both sides (a clear value step) with a
vertical black rune as an internal silhouette. It is the largest, brightest mass on
the axis. No geometry moved, so the sightline numbers are unchanged.

Rotunda symmetry warning (4 cases): explained and fixed, not a cult exception.
`rotunda_arcade_pier_04` and `_10` (or `_04`/`_13` on the large rotundas) had no
twin because the pier-to-drum-panel snap in `_build_rotunda_upper_arcade` ran pier
by pier: the first pier to claim a contested panel changed what its mirror could
get. Each pier now claims its panel and the panel's mirror for its mirror pier, and a pier
on the gate axis (the portal one, the rear one) may only stand on an axis panel, else
it is left out. `lane:temple`: 3028 checks, 0 failures, 0 warnings (was 4 warnings).

### Tallies after this pass

40 accepted, 9 needs_changes (churches 17 / 7, temples 23 / 2). Open:
romanesque small/1 and default/1 (tower crown, SACRED-TOWER-CROWN), romanesque
large (plain gabled exterior), byzantine large (dome not visible from the
entry), russian small/1, default/8102 and default/1 (tower crown; not
re-reviewed this pass), ziggurat large x2 (focus, above). The small and default
ziggurats stay "accepted: marginal" on the chamber altar seen through the lower
gate, but by the measurement above their god is not visible from the foot
either.

## Acceptance evidence, 23 October 2026 (LIVE-SACRED)

The earlier sections are review-by-eye and measured geometry. This section is
the acceptance record the task asked for: a chosen set of public requests, a
rendered frozen matrix, an UNLABELLED review with the local vision tool, and a
verdict per case with the trait that supports it. The geometry was not changed
to get this evidence; one render-tool fault was found by the first blind pass
and fixed (below). No check was weakened.

### The chosen requests

From `tests/fixtures/sacred_sequence_requests.json` (49 public requests, all
generated through `BrickWild.generate` as a consumer would). Eighteen carry the
matrix: every church style and every temple form, across the three frozen
sizes and the three frozen seeds, with the cults rotated. The pinned barn is
included at its stated request: **basilica / blood / default / seed 1,
26 x 44 x 12 m**.

| id | family | form / style | size (w x l x h) | seed | notes |
|---|---|---|---|---|---|
| `church/romanesque/small/1` | church | romanesque | 8 x 14 x 7 | 1 | apse and west tower at their tightest |
| `church/gothic/small/1` | church | gothic | 8 x 14 x 7 | 1 | twin-spired west front |
| `church/byzantine/default/8102` | church | byzantine | 10 x 22 x 12 | 8102 | dome on a drum |
| `church/nordic_stave/default/1` | church | nordic stave | 10 x 22 x 12 | 1 | timber, tiered tower, svalgang |
| `church/renaissance/large/21325` | church | renaissance | 16 x 48 x 24 | 21325 | dome, rose window, 46 m nave |
| `church/russian/large/21325` | church | russian | 16 x 48 x 24 | 21325 | onion dome, open floor with stalls |
| `temple/basilica/void/large/21325` | temple | basilica / void | 48 x 80 x 20 | 21325 | largest hall, near-black cult stone |
| `temple/basilica/bone/small/8102` | temple | basilica / bone | 18 x 24 x 8 | 8102 | smallest basilica |
| `temple/pylon/bone/small/1` | temple | pylon / bone | 18 x 24 x 8 | 1 | pylons and gate at the smallest size |
| `temple/pylon/serpent/default/8102` | temple | pylon / serpent | 26 x 44 x 12 | 8102 | default hypostyle |
| `temple/pylon/blood/large/21325` | temple | pylon / blood | 48 x 80 x 20 | 21325 | largest hypostyle |
| `temple/ziggurat/flame/small/1` | temple | ziggurat / flame | 18 x 24 x 8 | 1 | stair foot is the gate |
| `temple/ziggurat/blood/default/21325` | temple | ziggurat / blood | 26 x 44 x 12 | 21325 | default terraces |
| `temple/ziggurat/bone/large/21325` | temple | ziggurat / bone | 48 x 80 x 20 | 21325 | largest summit |
| `temple/rotunda/void/small/8102` | temple | rotunda / void | 18 x 24 x 8 | 8102 | ring, pit and monolith |
| `temple/rotunda/bone/default/21325` | temple | rotunda / bone | 26 x 44 x 12 | 21325 | default ring |
| `temple/rotunda/flame/large/21325` | temple | rotunda / flame | 48 x 80 x 20 | 21325 | framed gate and cone idol |
| **`temple/basilica/blood/default/1/pinned-barn`** | temple | basilica / blood | **26 x 44 x 12** | **1** | **the pinned barn-like comparison id** |

Three negative controls, rendered by the same tool with a dark box across the
axis (they are NOT part of the 18):

| id | control | what the box does |
|---|---|---|
| `church/romanesque/default/1` | `hide_focus` | 3.0 m screen across the nave |
| `church/gothic/default/8102` | `break_axis` | 1.35 m body-high barrier across the nave |
| `temple/basilica/flame/default/8102` | `hide_focus` | 8.0 m veil across the hall |

### The frozen matrix and the renders

Tool: `tools/render_sacred_exterior.gd`, through the public API
(`BuildingRequest.from_dict` -> `BrickWild.generate` -> `BrickWild.instantiate`),
run WITHOUT `--headless` (the dummy renderer makes no image). Four views per
request:

* `front`, `side` - roof ON, exterior portrait;
* `entry` - roof ON, first person at 1.65 m on the first reached `WalkGrid`
  cell inside the door, aimed at the altar prop (church) or the idol (temple);
* `cutaway` - roof OFF, aerial 3/4 section.

One scene is instantiated per view. The first attempt shared one cutaway scene
across all four views, so every "exterior" was roofless and the roof-mounted
finials floated in the sky; the blind review caught it (it reported floating
trim in the exteriors). Fixed in the tool before the final pass: `BrickWild.instantiate`
now gets `cutaway = (view == "cutaway")` per view.

```
godot --path . --script res://tools/render_sacred_exterior.gd -- \
  --out=res://artifacts/sacred_review_20261023/renders \
  --ids=<the 18 ids above, comma-separated> --views=front,side,entry,cutaway

godot --path . --script res://tools/render_sacred_exterior.gd -- \
  --out=res://artifacts/sacred_review_20261023/renders_controls \
  --ids=church/romanesque/default/1 --control=hide_focus      # likewise the other two
```

Output: `artifacts/sacred_review_20261023/renders/` (72 jpg, 18 x 4; the
unlabelled pass then copies the 3 controls in, so the directory shows 75) and
`.../renders_controls/` (the 3 originals). Render logs: `render_matrix.log`,
`render_control_*.log`; all exited 0 (the only errors are the host's missing
WASAPI audio device).

### The unlabelled review

The renders are labelled by id in their file names. `tools/sacred_unlabelled_review.py`
copies them to neutral names, `case_01` to `case_21` (the three controls are
mixed in, so the reviewer cannot tell which are controls), shuffles the order
with seed `20261024`, and keeps the mapping in `key.json`. The key was not
opened until `verdicts.json` was written; the join is `joined.json` (key and
verdicts SHA-256 recorded there).

Tool: `waterfree vision look` (skill `waterfree-vision`), model
`qwen2.5vl:7b`, purpose `describe`, two images per call (the exterior pair;
the entry image plus its cutaway). The questions are verbatim in
`answers.json` and `tools/sacred_unlabelled_review.py`; the exterior one asks
what kind of building it is, style, massing, entrance, roof, towers/domes,
windows, material, ornament and whether it is structurally finished; the
interior one asks (a) is the way ahead clear, (b) what stands at the far end
and is it visible from the entrance, (c) where people would stand or sit and
whether that zone is around the axis, (d) any broken or floating geometry.
The cutaway question says that roof-mounted trim may appear to float.

Answers: `artifacts/sacred_review_20261023/answers.json` (all 21 cases, one
retry after an Ollama timeout on `case_13`). Verdicts as written before the
map: `verdicts.json`. Measurements: `measurements.json`, produced by

```
godot --headless --path . --script res://tools/sacred_sequence_report.gd -- \
  --ids=<the 18 ids> --out=res://artifacts/sacred_review_20261023/measurements.json
```

which runs the same judges the gates run (`qa/sacred_sequence_check.gd` for a
church, `TempleRiteCheck` for a temple) and writes their stats and failures.

**Honest limits of the blind pass.** The model is a 7B vision model: it names
broad types well when the silhouette is strong, and it invents detail when the
image is dark. It missed the body-high barrier in the `break_axis` control
(answered "clear of obstructions") and it called Gothic "Romanesque" in one
answer. Where its answer and the image disagree, the verdict uses the image
and the disagreement is stated in the row. Five images had been seen during
render plumbing before the blind pass (gothic small front and cutaway,
renaissance large front, pinned barn entry, ziggurat large entry); the rest of
the 75 were first seen unlabelled. Verdicts were assigned from the neutral
images and the answers, then matched to ids.

### Measured sequence (independent of the pictures)

All 18 chosen requests pass the sequence rules; `measurements.json`,
`failed: 0`.

| id | axis run (m) | procession (m) | sightline blockers | congregation | pews | walkable (m2) |
|---|---|---|---|---|---|---|
| church/romanesque/small/1 | 12.2 | 1.32 | 0 | 0.38 | 14 | - |
| church/gothic/small/1 | 12.2 | 1.32 | 0 | 0.39 | 12 | - |
| church/byzantine/default/8102 | 20.2 | 1.44 | 0 | 0.49 | 28 | - |
| church/nordic_stave/default/1 | 20.2 | 1.44 | 0 | 0.54 | 24 | - |
| church/renaissance/large/21325 | 45.9 | 1.44 | 0 | 0.52 | 112 | - |
| church/russian/large/21325 | 45.9 | 1.44 | 0 | 0.91 | 16 | - |
| temple/basilica/void/large/21325 | 76.9 | 3.36 | 0 | 0.93 | - | 3078.2 |
| temple/basilica/bone/small/8102 | 25.0 | 3.52 | 0 | 0.93 | - | 336.4 |
| temple/pylon/bone/small/1 | 20.1 | 3.04 | 0 | 1.52 | - | 329.5 |
| temple/pylon/serpent/default/8102 | 38.9 | 3.04 | 0 | 1.47 | - | 854.9 |
| temple/pylon/blood/large/21325 | 72.6 | 3.04 | 0 | 1.53 | - | 3023.9 |
| temple/ziggurat/flame/small/1 | 14.4 | 2.88 | 0 | 1.32 | - | 348.5 |
| temple/ziggurat/blood/default/21325 | 31.6 | 3.52 | 0 | 1.16 | - | 851.7 |
| temple/ziggurat/bone/large/21325 | 57.4 | 3.52 | 0 | 1.07 | - | 2608.5 |
| temple/rotunda/void/small/8102 | 12.8 | 2.88 | 0 | 0.45 | - | 117.5 |
| temple/rotunda/bone/default/21325 | 19.4 | 2.88 | 0 | 0.45 | - | 247.8 |
| temple/rotunda/flame/large/21325 | 39.2 | 2.88 | 0 | 0.61 | - | 1157.4 |
| temple/basilica/blood/default/1/pinned-barn | 45.6 | 2.88 | 0 | 0.98 | - | 945.9 |

The temple "congregation" stat is the check's walkable share of the hall; it
exceeds 1.0 where the walkable area it counts includes the forecourt around a
compact hall. The stat is quoted as the check reports it.

### Verdicts, by case

Rule: accepted = identity yes or partly, entry pass, congregation pass, focus
pass. A case that shows an obstruction is failing whatever the model says. The
one exception is the pinned barn comparison, which is `needs_changes` on its
known identity fault even though its sequence passes. The traits are the
model's words where quoted, and what the image shows otherwise.

Churches (6 of 6 accepted):

| id | identity | entry | congregation | focus | verdict |
|---|---|---|---|---|---|
| `church/nordic_stave/default/1` | yes: model "a church ... tall bell tower ... steeply pitched roof ... dark-colored wood ... shingled ... cross at the very top"; image: tarred planks, tiered shingled tower, needle spire, dragon heads | pass: "way ahead is clear"; open aisle between pews | pass: "benches on either side ... arranged around the axis" | pass: "altar ... candles ... visible and recognizable" | accepted |
| `church/renaissance/large/21325` | partly: model "central dome ... Italian or Spanish ... circular window"; image: dome + lantern, rose window, long plain flank | pass: aisle from the door | pass: pew blocks, cross-aisles | pass: reredos, cross, banners, altar read at 46 m | accepted |
| `church/russian/large/21325` | partly: model "central dome ... Islamic or Middle Eastern"; image: onion dome, two half-round corner turrets, long body | pass: long open floor | pass: one stall at a time along each wall (standing worship, the brief) | pass: reredos, banners and altar at the east end | accepted |
| `church/romanesque/small/1` | partly: model "two-story structure ... red-tiled roof ... classical"; image: west tower, gabled nave, buttress fins, round apse | pass: door, aisle, pews | pass: pews both sides | pass: altar and candles under the apse arch | accepted |
| `church/byzantine/default/8102` | yes: model "dome ... Byzantine ... church or a similar religious building" | pass: aisle between pews | pass: pews both sides | pass: altar and chandeliers at the end | accepted |
| `church/gothic/small/1` | yes: model "church ... twin spires ... Gothic or Romanesque ... pointed arch"; image: twin crocketed spires, portal, apse | pass: portal, aisle | pass: pews both sides | pass: altar and candles down the aisle | accepted |

Temples (5 of 12 accepted):

| id | identity | entry | congregation | focus | verdict |
|---|---|---|---|---|---|
| `temple/basilica/bone/small/8102` | yes: model "classical ... colonnaded entrance ... portico"; image: pedimented pronaos, colonnade, apse | pass: portico, colonnade, aisle | pass: open floor with braziers | pass: pale idol on the altar in the apse | accepted |
| `temple/pylon/serpent/default/8102` | partly: model "rectangular ... green accents"; image: battered pylons, cut gate, hypostyle, green trim | pass: gate, columns, aisle | pass: open floor between the columns | pass: "a green glowing object" - the coil idol lit in the apse | accepted |
| `temple/pylon/bone/small/1` | partly: model "central entrance with columns ... classical"; image: two pylons, cut gate, short hall | pass: gate, aisle | pass: open floor | pass: pale stepped idol on the altar, central | accepted |
| `temple/rotunda/bone/default/21325` | partly: model "circular structure ... evenly spaced columns"; image: drum, open pier colonnade, ring roof | pass: door, path between the pits | pass: open floor, braziers | pass: pale stepped idol on the central altar | accepted |
| `temple/rotunda/flame/large/21325` | partly: model "circular ... columns ... triangular pediment ... Greek or Roman"; image: drum, colonnade, pedimented aedicule in the cult trim | pass: framed door, path across the pit | pass: wide open floor | pass: orange cone idol, large and central | accepted |
| `temple/basilica/void/large/21325` | partly: model "public building ... government office or a school"; image: long hall, colonnaded portico and pediment, roof belfry, near-black Starless Deep stone | pass: clear axis | pass: open floor, braziers | **fail**: the far end is lost in darkness; no idol is recognisable ("not fully visible from the entrance") | needs_changes |
| `temple/rotunda/void/small/8102` | partly: model "circular ... watchtower or a small observatory"; image: drum, open pier arcade, ring roof | pass: door, clear path | pass: open floor, braziers (sparse is the brief) | **fail**: only the altar group reads ("a table with two candelabras and a chalice"); the monolith is not legible from the door | needs_changes |
| `temple/pylon/blood/large/21325` | partly: model "simple rectangular massing ... dark color with red accents"; image: battered pylons, cut gate, long dark hypostyle | pass: gate, aisle | pass: open floor, braziers | **fail**: the end of the axis is a red doorway; the blood idol does not read from the entry | needs_changes |
| `temple/ziggurat/flame/small/1` | yes: model "stepped ... Mesoamerican ... conical structure on the roof"; image: terraces, stair flights, cone on the summit | pass: stair canyon and gate clear | pass: forecourt at the stair foot | **fail**: the gate frames the chamber altar, not the summit god; the summit edge hides it | needs_changes |
| `temple/ziggurat/blood/default/21325` | yes: model "stepped pyramid ... Mesoamerican ... flat top"; image: terraces, stair, red figure on the summit | pass: stair and gate clear | pass: forecourt | **fail**: the summit god is not visible from the stair foot | needs_changes |
| `temple/ziggurat/bone/large/21325` | yes: model "stepped pyramid ... Maya ... staircase ... flat top"; image: terraces, long stair, summit shrine | pass: stair canyon and gate clear | pass: forecourt | **fail**: the summit edge hides the god at 48 x 80 | needs_changes |
| **`temple/basilica/blood/default/1/pinned-barn`** | **partly**: model "church ... bell tower ... portico ... classical"; image: pedimented west front and belfry, but a long unbroken flank and a flat dark roof - the known barn comparison | pass: portico, aisle, columns | pass: open floor, braziers | pass: blood idol and altar legible in the apse | **needs_changes** (identity) |

Negative controls (all three recorded failing, as the rule requires):

| id | control | evidence | verdict |
|---|---|---|---|
| `church/gothic/default/8102` | break_axis | image: a body-high black barrier spans the nave between the pews; the altar is hidden behind it. The model said "clear of obstructions" and missed it; the image is the evidence. | needs_changes: entry fail, focus fail |
| `church/romanesque/default/1` | hide_focus | model: "large black structure, possibly a screen or a wall ... visible"; image: the screen fills the nave and the altar behind it is invisible | needs_changes: entry fail, focus fail |
| `temple/basilica/flame/default/8102` | hide_focus | model: "dark, enclosed space ... not possible to see inside this space from the entrance"; image: the veil closes the axis | needs_changes: entry fail, focus fail |

### Open failures

1. **Ziggurat focus, all three sizes** (`ziggurat/flame/small/1`,
   `ziggurat/blood/default/21325`, `ziggurat/bone/large/21325`). The stair foot
   is the gate; the god stands at the back of the summit and the summit's own
   front edge hides it. The measured apex table is the one in "Ziggurat focus,
   measured" above: needs 11.2 / 21.8 / 39.6 m, has 9.4-9.6 / 13.5 / 23.4 m.
   Open: the upper terraces have to be set back at the front and the flights
   re-run; no dressing fixes it.
2. **Rotunda void, small** (`rotunda/void/small/8102`). The measured sightline
   has no blocker, but from the door only the altar group reads: the monolith
   is dark against a dark drum and does not separate from it. Recorded as a
   legibility failure (focus), open. Its siblings (bone default, flame large)
   pass with their brighter idols.
3. **Large dark halls** (`basilica/void/large/21325`,
   `pylon/blood/large/21325`). The measured sightline is clear (0 blockers),
   but the entry image loses the focus: the void hall is near-black, and the
   pylon apse is a bright red doorway. Recorded as focus failures of the
   entry image, open; this is contrast and lighting (cult palette + the
   night-within entry rig), not a geometric occlusion.
4. **Pinned barn identity** (`basilica/blood/default/1/pinned-barn`). Entry,
   procession, congregation and focus pass (procession 2.88 m, 0 blockers,
   idol visible). The long flank and flat dark roof still read as a barn, the
   reason the id exists. Open, as before.
5. **Rotunda and pylon identity is only partly read** (7 of the 12 temples,
   and 4 of the 6 churches). The blind model names the massing (circular
   colonnade, battered pylons, stepped terraces) but not the sacred
   purpose; for the rotundas and pylons it said "observatory", "watchtower",
   "public building", "classical structure". Recorded as partly, not as a
   new fault; the accepted rotundas and pylons pass on sequence and focus.
6. **Identity via cult is weak in the dark.** The void basilica reads as an
   institutional block and the blood pylon as a plain dark hall, because the
   cult palettes (`2f3138`/`1b1d22` void, `4a3b39` blood) are almost
   unlit at the entry rig. This is the same finding as 3, from the outside.

### Receipts

Final run in this worktree, logs redirected:

| lane | suites | checks | failures | warnings | log |
|---|---|---|---|---|---|
| `lane:church-change` | 4 | 5940 | 0 | 16 (12 opening, 4 sacredseq rotunda symmetry) | `artifacts/sacred_review_20261023/lane_church_change_final.log` |
| `lane:temple` | 4 | 3467 | 0 | 4 (rotunda symmetry, judged by `rite`) | `artifacts/sacred_review_20261023/lane_temple_final.log` |

Measured sequence: 18 / 18 cases, 0 failures
(`artifacts/sacred_review_20261023/measurements.log`).
Renders: 72 matrix images + 3 controls, exit 0
(`render_matrix.log`, `render_control_*.log`). Unlabelled answers:
`answers.json`; join: `joined.json`; key: `key.json` (do not read before the
verdicts). Images are not committed (artifacts is gitignored).

## Basilica focus and flank (SACRED-BASILICA-FOCUS, 2026-10-24)

Changed in `TempleBuilder` only; the pinned request (26 x 44 x 12, seed 1) is unchanged.

* **Idol backdrop** (`_build_idol`, basilica and pylon): a panel 0.16 m thick just
  behind the god. Pale cult trim behind a monolith (the monolith itself turns
  dark with a trim rune, the reverse of the rotunda), a dark panel behind a
  figure. Traits per case: `basilica/void/large/21325` - a dark slab framed by a
  pale arch at the end of the axis; `pylon/blood/large/21325` - the figure
  stands against a dark panel instead of dissolving into the red doorway.
  Sightline is unchanged (0 blockers; the panel is behind the idol, unlogged).
  Honest limit: the void hall remains dark, and the idol is small at 80 m; the
  gain is an edge to find, not a bright god.
* **Flank marker** (`_flank_niche`, basilica eave walls): `basilica_flank_niche_<wall>_<bay>`
  hosts, each a trim frame (`basilica_flank_niche_frame`) and a dark recess
  (`basilica_flank_niche_recess`) below the clerestory light, between the
  pilasters. In the component log; visible in the side render
  (`artifacts/goal/SACRED-BASILICA-FOCUS/after/`). The roof is still a low
  dark slab. An independent reviewer has NOT yet ticked the render.
* Receipts: `lane:temple` 3028 / 0 / 0; `lane:church-change` 5941 / 0 / 12 (the known opening warnings).

## Rotunda and pylon identity as a trait checklist (SACRED-IDENTITY, 2026-10-24)

The qwen 7B naming test ("what building is this?") was noisy and flipped with
no change to the building, so it no longer judges identity. Each family now
carries a short checklist, measured from `mass_log` / `component_log` by
`qa/sacred_identity_check.gd` and asserted by `sacredid`
(`tests/suites/sacred_identity_suite.gd`, in `lane:temple`) on all twelve frozen
rotunda and pylon requests in `sacred_sequence_requests.json`.

| family | trait | measured as |
|---|---|---|
| rotunda | round drum plan | >= 12 `wall_rotunda_NN` panels, centres on one radius (spread < 12 % of outer, inside the outer radius), largest angular gap <= 70 deg (the door) |
| rotunda | dome or ring roof | a full-circle `rotunda_drum_crown` revolve at the drum top, outer radius >= the wall, inner radius > 0.5 m and < 90 % of outer: an open ring |
| rotunda | ring colonnade at the door | >= 8 `rotunda_arcade_pier_NN` on one circle, mirrored about the axis, at least one pier within 40 deg either side of the door, and >= 8 inner `column_N` on one ring |
| pylon | twin battered towers flanking the gate | `pylon_0`/`pylon_1` mirror twins on the front line, gap >= the gate width, 1.2 x the wall height or more, and each tower's `pylon_battered_face` slabs are < 90 % of their foot area at the top (measured about 0.46) |
| pylon | hypostyle hall behind the gate | >= 4 `column_N` in >= 2 rows and >= 2 files, all behind the towers' back edge, not standing on one circle |

Controls (a measure that cannot fail is not a measure): for every trait on every
case the same measure runs on logs with that trait's rows deleted and must
fail; and a rotunda measured as a pylon, and a pylon as a rotunda, must miss
every trait of the other.

Result: all 12 cases carry all their traits; 78 checks, 0 failures. No trait
was missed, so there is no miss list. Writing the controls found two real
holes in the first draft of the hypostyle measure (it passed a rotunda's inner
column ring because it looked only at row/file counts; and it passed with no
towers at all), both closed above.

### Independent exterior read of the traits (24 Oct)

A fresh reviewer, given only the checklist and the 24 front/side renders
(`artifacts/goal/SACRED-IDENTITY/renders/`, 6 rotunda and 6 pylon cases), ticked:

* Rotunda: round drum 6/6, ring roof with open centre 6/6 (no dome anywhere),
  **ring colonnade at the door 0/6**. The piers are a ring of square piers on
  the upper drum above a solid wall; the door is a pier-framed gap (small) or
  a pedimented aedicule (large) with no column ring at door level. The
  measure passes (the piers are mirrored and flank the door in plan); the eye
  reads a clerestory ring. Listed as a MISS, not softened: the fix would be a
  door-level peristyle, which is a design change for a later task.
* Pylon: twin battered towers flanking the gate 6/6. Hypostyle hall 0/6 clear
  (blood/large gives a hint of posts under the roof edge): an exterior render
  cannot show a hall under a flat roof. The plan measure (columns in a grid
  behind the towers) is the evidence; the entry views in the matrix show it
  from inside.

Receipts: `lane:temple` 3106 checks / 0 failures / 0 warnings (`artifacts/goal/SACRED-IDENTITY/lane2.log`).

## LIVE-SACRED close-out (2026-10-24)

All six sub-tasks done (676e5e6, 41f0414, 15b30ad, 5e92c0b, ecfaa49, ed96101). The five rows that cited since-fixed defects were re-rendered once on ed96101 with `tools/render_sacred_exterior.gd` (front, side, entry, cutaway; `artifacts/goal/LIVE-SACRED/`) and re-ticked above. Open findings have their own tasks: SACRED-ROTUNDA-PERISTYLE (ring colonnade 0/6 from outside) and TEMPLE-STAIR-TEST-STALE.
