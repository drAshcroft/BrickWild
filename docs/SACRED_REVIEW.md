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

## Not yet done

Exterior identity and focal visibility from the congregation zone as an image
(not a ray) need the human or vision review of renders; the matrix ids are
stable for that. The barn-like basilica's exterior remains the open item.
