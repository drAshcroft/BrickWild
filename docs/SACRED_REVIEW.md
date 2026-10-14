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
