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

Tallies: 31 accepted, 18 needs_changes (churches 10 / 14, temples 21 / 4).
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
| romanesque_small_1 | partly: round apse, lombard pilasters, but square windows and the west tower ends in stepped blocks and bare posts | door in tower base, straight nave, pews to the rail | two pew blocks either side of the aisle, empty chancel (brief) | altar and candles clear at the end of the aisle, apse lights above | needs_changes: tower crown reads unfinished (todo SACRED-TOWER-CROWN) |
| romanesque_default_8102 | partly: tower, apse, gable porch read Romanesque; flat uncapped tower | door, aisle, apse | pews both sides, empty chancel | altar visible under the chancel arch | accepted |
| romanesque_large_21325 | no: a 24 m gabled box, pilasters and two tiny slit windows, no tower, no apse visible from the front | door in a blank gable, then a hall far wider than the pew block | pews are a small cluster far down a bare floor; the west half is empty with nothing in the brief to explain it | altar is a speck washed out against the bright end wall | needs_changes: large size is a barn; furnishing does not scale with the nave |
| romanesque_default_1 | partly: as small/1, with a row of tall lights on the flank | door, aisle, apse | pews both sides | altar and candles clear | needs_changes: same tower crown fault (SACRED-TOWER-CROWN) |
| gothic_small_1 | partly: twin squat towers with domed caps, round chevet; pointed heads only on the windows, so it reads as a Romanesque variant | portal in the west front, aisle, apse | pews both sides | altar and candles clear, three apse lights | needs_changes: no spire, flyers or lancets at small size, so no Gothic silhouette |
| gothic_default_8102 | yes: twin octagonal spires, flying buttresses, clerestory | portal, aisle between piers | pews both sides, aisles beyond the piers empty | altar clear at the end | accepted (design-board gaps in the section above stand) |
| gothic_large_21325 | yes: tall twin towers, flyer arcade, glazed clerestory | portal, long aisle | pews from the first bay, aisles empty | altar small but readable, apse arch above it | accepted |
| gothic_default_1 | yes: single tapering spire, flyers on the east bays | portal in tower base, aisle | pews both sides | altar and candles clear | accepted |
| byzantine_small_1 | yes: dome on a drum over a gabled cross-body, low apse | door, aisle, apse | pews both sides | altar clear, apse arch frames it | accepted: partly Byzantine, the dome sits over a basilican body |
| byzantine_default_8102 | yes: as small, with pilasters | door, aisle | pews both sides | altar clear | accepted |
| byzantine_large_21325 | partly: dome pushed to the east end of a long barn body, flat flank | door in a blank gable, aisle | pews a distant cluster, bare floor before them unexplained | altar lost against the bright end wall | needs_changes: large size is a barn; dome not visible from the entry |
| byzantine_default_1 | yes | door, aisle | pews both sides | altar clear | accepted |
| nordic_stave_small_1 | no: pale stone-textured walls, a black stepped-block spire; no tiered shingle roofs, no dark timber, no dragon heads | door at the foot of the tower, aisle | pews both sides | altar clear, but in a pale plank hall | needs_changes: does not read as a stave church |
| nordic_stave_default_8102 | no: as small | as small | pews both sides | altar clear at the end of a long plank hall | needs_changes: stave identity |
| nordic_stave_large_21325 | no: stone-coloured box with a stepped spire | door, aisle into a huge hall | a distant pew cluster, bare floor unexplained | altar a glow on the far wall, hard to find | needs_changes: stave identity and large-size furnishing |
| nordic_stave_default_1 | no: as small | as small | pews both sides | altar clear | needs_changes: stave identity |
| renaissance_small_1 | partly: dome with lantern, pilaster cornice; no pediment or orders | door with a small porch, aisle | pews both sides | altar clear under a round arch | accepted |
| renaissance_default_8102 | partly: dome, lantern, twin stepped tower crowns, round-headed lights | door, aisle | pews both sides | altar clear | accepted |
| renaissance_large_21325 | partly: rose window, dome and a lean-to roof read Italian; flank is a long blank wall | door, long aisle | pews begin well down a bare floor | altar lost | needs_changes: large size is a barn; altar not findable |
| renaissance_default_1 | partly: dome and lantern, stepped tower | door, aisle | pews both sides | altar clear | accepted |
| russian_small_1 | partly: one squat onion dome, round chevet; no cluster of domes, no kokoshniki | door in tower base, aisle | pews both sides | altar clear | needs_changes: floating blocks on the nave walls (SACRED-RUSSIAN-FLOATING-BLOCKS) and the tower crown fault |
| russian_default_8102 | partly: as small | door, aisle | pews both sides | altar clear | needs_changes: both defects as above |
| russian_large_21325 | partly: one onion dome on a box, two half-round buttress turrets | door, aisle | a distant pew cluster | altar a glow, brown blocks near the ceiling pull the eye | needs_changes: large-size furnishing, floating blocks |
| russian_default_1 | partly: as small | door, aisle | pews both sides | altar clear | needs_changes: both defects as above |

### Temples

| Id | Identity | Entry | Congregation | Focus (entry image) | Verdict |
|---|---|---|---|---|---|
| basilica_blood_small_1 | yes: pedimented pronaos, clerestory, apse | portico, orange inlay down the axis | open hall floor with braziers either side (sparse is the brief) | altar and idol under the apse arch, clear | accepted |
| basilica_bone_small_8102 | yes: as above plus a belfry | as above | open floor, very dark | idol lit and clear at the end; columns near-black | accepted |
| basilica_flame_default_8102 | yes: long hall, pediment, belfry | portico, inlay, colonnade | braziers between colonnade and aisle | idol small but clear | accepted |
| basilica_serpent_default_21325 | partly: identical in form and colour to flame | as flame | as flame | idol is an orange cone, same as flame; a serpent cult is not told apart | accepted for sequence; cult identity open (see faults) |
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
| ziggurat_bone_large_21325 | yes | foot of a long stair canyon | forecourt | altar a near-invisible slit at the top, idol hidden | needs_changes: the focus is not readable from the entry at large size |
| ziggurat_flame_large_1 | yes | as above | forecourt | as above | needs_changes: same |
| rotunda_serpent_small_1 | partly: drum with open pier clerestory and a thin ring roof; reads as an arena | door in the drum with a framed porch | open floor, braziers round the pit | altar and cone idol large and central | accepted |
| rotunda_void_small_8102 | partly: as above | door | as above | altar and idol clear | accepted |
| rotunda_blood_default_8102 | partly | door, a plain frame | open floor, a pit either side of the path (the pit is in the brief) | altar and idol clear across the pit | accepted |
| rotunda_bone_default_21325 | partly | as above | as above | clear | accepted |
| rotunda_flame_large_21325 | partly: a 24 m blank drum; the door is a 1.2 m orange frame flush with the wall, easy to miss | door | wide open floor | idol clear, altar rail visible | needs_changes: entrance is lost on a large drum |
| rotunda_serpent_large_1 | partly: as above | as above | as above | as above | needs_changes: same |

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
2. Nordic stave never reads as stave: pale stone-textured walls, a black
   stepped-block spire, no tiered shingle roofs or dark timber. 4 ids.
3. Towers with an unfinished crown (flat deck, stepped red blocks, bare posts):
   Romanesque and Russian. Filed as SACRED-TOWER-CROWN.
4. Russian nave interiors carry floating brown blocks. Filed as
   SACRED-RUSSIAN-FLOATING-BLOCKS.
5. Ziggurat at large size: the altar is a slit at the top of the stair canyon
   and the idol is out of sight from the foot. 2 ids.
6. Cult identity is only a tint: every cult has the same orange cone idol and
   the same braziers, so a serpent temple cannot be told from a flame one.
   Not counted in the verdicts above except as a note.
7. Large rotunda: a 1.2 m door flush in a 24 m blank drum. 2 ids.
8. Gothic small has no Gothic silhouette (squat domed towers). 1 id.
