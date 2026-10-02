# Evaluation: beauty, correctness, furnishing (2026-10-01)

Measured against `b568e5b` on 2026-10-01. Every lane below was run on this
machine today and its log is in `artifacts/eval_20261001/`. Every render was
made today with `tools/render_shots.gd` and its companions; the files it
overwrote in `artifacts/renders/` are the ones this document reads from.
Scores are a visual opinion, 0 to 5, on the same nine axes as
[VISUAL_QA.md](VISUAL_QA.md) collapsed to one number. Correctness is what the
suites said. Furnishing is what is in the building and whether a check
measures it.

Nothing was changed. Three lanes were run at a time; wall times are therefore
contended and only comparable to each other.

## 1. Scorecard

| Family | Beauty (Sep 26) | Beauty (today) | Correctness today | Furnishing |
|---|---|---|---|---|
| House | 30.0 / 45 | **32** | geom, exterior, furnishing, plan: all pass | 3.5: 35 recipe categories reach 84 measured props; the hearth is the first thing removed |
| Village | 27.5 | **27** | `vquick`: 17 documented VIL-017 failures, unchanged | 3: 24 categories, 7 of them have no catalogue prop and are built |
| Temple | 25.5 | **26** | temple, rite: pass; 7 idol-dominance warnings | 2.5: 8 props, braziers only; pylon interior still black |
| Church | 16.5 | **23** | church-change, churchroof: pass, 0 warnings | 2.5: 21 props, altar, pews, lights; dressing sweep pending |
| Castle | 16.5 | **21** | castle-change: pass, 5 known probe warnings | 3: 42 props, halls, keeps, chapels, a yard; sparse at fortress scale |
| Hotel | not scored | **26** | **`hlandmark` fails at every scale** | 3: house furnisher; rugs planned but not emitted |
| Shop | not scored | not rendered | **`shop` fails (prison), `sarchetype` fails (3)** | 3: library and palace carry 27 and 9 warnings |
| World (19 families) | not scored | **12** (courtyards, timber hall) | **`wld001` 48 failures, `wld003` 4 failures**; 12 families pass | 1: only the courtyard house is furnished; mosque has a fountain |
| Trees | not scored | **17** | pass; 142 warnings in 835 checks | n/a |
| Bridges | not scored | **13** | pass | n/a |
| Studio | not scored | **27** | not under test | shows the sheet and the furniture list |

Churches and castles moved most, as the VIS work intended. The house is still
the best thing on screen, and it still has the two faults the September
critique named: a chimney with no fire under it, and rooms that are mostly
empty floor.

## 2. Correctness: what the lanes said

| Lane | Suites | Checks | Fail | Warn | Wall | Verdict |
|---|---|---|---|---|---|---|
| `lane:geom` | 10 | 6975 | 0 | 0 | 129 s | pass |
| `lane:church-change` + `lane:temple` + tree + bridge | 6 | 8711 | 0 | 149 | 230 s | pass |
| `lane:castle-change` | 5 | 214 | 0 | 5 | 310 s | pass, known warnings |
| `lane:village-fast` + assets-fast + library-change + palace-change | 7 | 176 | **18** | 47 | 314 s | shops 1, vquick 17 |
| `lane:house-furnish-fast` + exterior-fast + 3 archetype suites | 6 | 1227 | **3** | 64 | 836 s | sarchetype 3 |
| `hmultistory`, `hotel`, `hotelroof` | 3 | n/a | 0 | 1 | 1408 s for `hotel` alone | killed at 30 min during `hlandmark` |
| `houseqaplan`, `hlandmark` | 2 | 56 | **21** | 23 | 781 s | hlandmark 21 |
| `lane:world` + `court` | 15 | 307 | **52** | 454 | 1930 s | wld001 48, wld003 4 |
| `library placement poly dressing interior ...` | killed at 60 min | | | | `library` 1521 s, `placement` unfinished at 35 min | no verdict |
| `dressing ckfurnish cshop psconce int012 int013` | 6 | 567273 | **124** | 50 | 2529 s, `dressing` 2210 s | dressing 124, cshop 2 script errors |

### 2.1 Failures no ledger records

Ranked by what they say about the building rather than about the test.

1. **The prison has no layout at the standard shop footprint.**
   `shop` suite, business `prison`, seed 31168, 12 x 16 m townhouse.
   `ShopSpec.prison_room_rects` searches for a cell column count whose cell
   width lands between 2.15 and 3.0 m. With 0.35 m walls the inside is
   11.3 m and no count fits: two columns give 3.38 m, three give 1.73 m. The
   function returns nothing, `ShopGenerator` sets `room_count` to zero and
   carries on, the planner logs two `push_error`s and the plan has no
   guardroom. The dead bands for inner width are 8.0 to 8.9, 10.7 to 12.6,
   15.3 to 16.3 and 19.8 to 20.0 m; the library accepts all of them. The
   archetype suite happens to use 15.8 x 22 m and passes. This has failed
   since the `shop` suite grew to 30 businesses; no log shows it green.
2. **The grand hotel landmark fails at every scale.** `hlandmark`, 21
   failures: rugs are planned but no textile quad is emitted 2 mm above the
   floor; at 0.78 the hearth breast has no full-storey masonry; the shell
   leaves its planned exterior by more than 25 mm; and the door trim blocks
   the approach to the front door. The rug, hearth-breast and door-trim rules
   arrived on 2026-09-23 in `9e09baf`; the hotel last passed this suite on
   2026-09-17 and was not taught the new rules. [HOTELS.md](HOTELS.md) still
   names `hotel hlandmark` as the harness.
3. **Every riad and palazzo fails the court roof rule.** `wld001`, 48
   failures, two per case: `roof_support: court roof face does not share
   outer/court corner endpoints`. All twelve domus cases pass. The rule in
   `qa/court_check.gd` (added 2026-09-21) asks each of the four court roof
   components to touch two site corners and two court corners within 2 cm.
   WLD-007 (2026-09-30, `69413aa`) rewrote 83 lines of the court roof emitter
   in `house_builder.gd` and the courtyard suite was not rerun. Whether the
   roof or the rule is wrong needs a run with the component points printed;
   it is not decidable from the code alone.
4. **The castle shell dressing has lost its table and its light.** `dressing`,
   124 failures across 83 castles of all eleven styles: `nothing in it is a
   'table'`, `nothing in it is a 'light'`, plus 41 warnings `nothing in it is
   lit`. Every church passes. The suite reads `builder.prop_log`, the shell
   dressing that `CastleFurnisher` places. It last passed on 2026-09-06 with
   401,557 checks; INT-007 (2026-09-13) moved the hall and keep furniture
   into interior `HousePlan`s, which the dressing suite does not read.
   Either the castles really have no fire on the wall walk and no table in
   any range the shell still dresses, or the suite is measuring a bucket
   that was emptied on purpose. A render of the ward with the roofs off
   shows braziers on the wall walk, which points at the second. Either way
   the suite has been red for three weeks in no lane, at 37 minutes a run.
5. **The kitchen gives up its hearth to keep the house walkable.** Not a
   failure, by design, but it is the signature piece of the room and it goes
   first. At the default scale the farmhouse, smithy and inn all report
   `programme: kitchen gave up its hearth`, then `hearth: room has the
   chimney on wall 1 and no fire under it`, then `focus: kitchen gave up the
   hearth it was arranged around`. The cutaway of the family cottage shows
   it: a cauldron alone on the kitchen floor beside a chimney with nothing in
   it. The September critique's S8 was closed on the record; the picture
   says the chimney now stands outside the wall and the fire still is not
   under it.
6. **Courtyard rooms are corridors.** `court`, 454 warnings over 105 houses:
   `shape: room 0 (hall) is 16.3 x 4.5 m -- that is a corridor` and
   `daylight: 2.99 m2 of glass for 73.4 m2 of floor`. A ring of rooms round a
   court is the oldest plan there is and the planner makes it as four long
   thin boxes with almost no glass on the court side.
7. **The temple idol does not loom.** 7 of 60 rite checks warn that the idol
   fills 35 to 40 percent of the room height; the rule wants it to be the
   tallest thing by a margin. The render agrees: the coiled idol is still a
   stack of green cubes a third of the wall height.
8. **Trees promise a canopy they do not have.** 142 of 835 tree checks warn,
   nearly all `crown: canopy is under a quarter of the height` on birch,
   spruce and oak at 3, 9 and 22 m, plus trunk clearance narrower than
   promised. The forest render is bare branch skeletons with green lumps on
   top.

### 2.2 Failures that are test defects

These fail every run and say nothing about the buildings. They should be
fixed first because they hide the real failures above in the same summary
line.

- **`sarchetype`: bathhouse, hospice, school "have no defining fitting".**
  The `REQUIRED` table in `tests/suites/shop_archetype_suite.gd` lists
  `["changing_room", "bench", "bath_hall", "barrel"]` and the loop treats
  every entry after the first as a prop category. `bath_hall`,
  `dispensary` and `masters_office` are room kinds; no catalogue category
  has those names, so `_has_category` can never return true. Added
  2026-09-30 in `462a08e`; the follow-up fix commit did not touch the table.
- **`wld003`: the merchant tower "did not generate".** `run_tower_house`
  takes `ARCHETYPES.back()` as its row. Rows have been appended since
  WLD-003; the last one is now the Dravida precinct at 240 x 120 m, so the
  suite asks for a tower 168 to 456 m wide and the registry refuses it.
  Broken since WLD-014 appended its row on 2026-09-30.
- **`cshop` calls two methods that no longer exist.** The runner logged
  `Nonexistent function '_check_focus'` and `'_check_workbench_daylight'`
  in `HouseFurnishCheck` from `castle_shop_suite.gd` lines 42 and 70. The
  furnishing check was split into physical, programme, arrangement and
  affinity classes and those private methods moved; the suite still reports
  `PASS (19 checked)` because the calls that would have checked the focus
  and the daylight never ran.
- **`vquick`: 17 failures.** Documented in
  [QA_FAST_PROTOCOL.md](QA_FAST_PROTOCOL.md) as existing VIL-017 failures.
  They are all on the street and hamlet site baselines: path verge 0.70
  instead of 0.00, junctions 4.8 m apart, common overlapping a path or a
  street. They have been "existing" long enough to be either fixed or
  removed from the routine lane.

### 2.3 Runtime

- `library` took 1521 s and `placement` was still running after 25 minutes.
  They are the first two suites in `ORDER`, so every full sweep pays an hour
  before it checks a single building. Neither is in any lane table.
- `hotel` took 1408 s for three seeds. `court` took 502 s.
- `lane:world` with `court` took 32 minutes; WLD-001 alone ran 49 cases at
  5 to 76 s each. The lane table in `AGENTS.md` does not list it.

## 3. Beauty, by family

### Churches: 16.5 to 23

What moved: stone courses on every wall, pointed windows with leaded glazing
and coloured panes, buttresses that step and project, flyers with a real arch
and pinnacle, a smooth hero dome with tiles, chapels round the apse. The
`detail_flyers.jpg` close-up is the most improved image in the catalogue and
would pass as a model photograph.

What did not move: the light. Every portrait is still lit flat from the
camera side, no cast shadow, no lit-and-shaded face split, grey ground to a
hard horizon. Florence is still a 150 m box with a band of bars down the
clerestory and a small dome at the far end; it reads as a prison. Hagia's
support is a flared white collar that reads as paper. St Basil shows one
onion, one stepped tower and a box; the cluster of eight chapels the
manifest promises is not in the shot.

### Castles: 16.5 to 21

What moved: windows are cut through the masonry and shadowed at the reveal,
Himeji has its stone base and tiered roofs, the tower sizes vary, the
bailey has four ranges, a well and clusters of yard props, CAS-013's curved
curtains are a genuine new silhouette.

What did not move: Krak is still 300 m of pale wall round a flat field; the
yard props exist and read as confetti at that distance. Chambord and
Neuschwanstein are white boxes with conical hats and a grid of slits.
Bodiam's moat is a flat blue square with a grey slab across it. Every
portrait has the same grey-green ground and no shadow. Stokesay is still the
best castle picture for the same reason it was in September: hipped roofs,
chimneys and a sun angle that lands.

The keep interiors (`castle_square_lords_chamber.png` and companions) show a
bed, a table, a chest and a brazier in a bare grey box. It is furnished; it
is not dressed.

### Houses: 30 to 32

`house_exterior.jpg` is still the best image the system makes: timber frame,
jetty, slate, porch, chimney, bench, shadows. The cutaways are furnished and
lit by their own sconces and chandeliers. Deductions as before: rooms are
walls with furniture against them and a bare middle; the chimney column now
stands outside the wall but the kitchen below it is empty; nothing stands
outside the house.

### Temples: 25.5 to 26

The bloodpit basilica is the best interior in the system: raking red light
down a colonnade of braziers to a lit altar. The starless pylon is still
ninety percent black; the September S10 note to lift the floor was not
acted on. The ziggurat exterior is a brown stepped mass with a candle on top.
The rotunda's coiled idol is still a stack of green cubes.

### Villages: 27.5 to 27

Unchanged and still good at aerial scale: half-timbered houses with
chimneys, a parish church with a spire, market stalls on the green, a river.
Still a rectangle of one green with a border of identical lollipop trees and
a grey void beyond. Two forms stand out in today's renders: `planted_common`
has a real market square, stalls, a well and a church with flying
buttresses; `round_actual` is a blighted village of dead trees round a green
with a black ziggurat in the corner, and it reads as cursed from 300 m.

### Hotel: 26

`hotel_grand_budapest.jpg` is pink, symmetrical, and has dormers, corner
domes, a balcony over a canopied door and a central pavilion. It reads as
the building it is named for at one glance, which is the point of a
landmark. It is also entirely flat: no shadow, no material, one plane of
colour per face, and the ground is a beige plane. It scores as the village
does, on charm and legibility, not on surface.

### World families, trees, bridges: 12 to 17

The courtyard houses, timber halls and bridges are flat-shaded boxes with no
material, no openings with depth and no light; they are where the churches
were in September. `riad_roof_on.png` is a grey box with a ring roof and one
door, which is correct for a riad and still a grey box. `palazzo_roof_on.png`
shows blank walls to the camera; the canal front with its water gate is only
in the dedicated shot. The timber great hall interior is a brown box of
posts. The stone bridge is a small grey arch in a cut slab of ground. The
forest is faceted green lumps on bare branch skeletons, which is also what
the tree check's crown warnings say.

### Studio: 27

`studio_house.png` shows the current UI: kind, size, storeys, style, trade,
orientation, period and seed on the left, the model in the middle, six named
variants on the right, and a sheet under the model listing every room with
its doors, windows and furniture by name. It is a working tool. The house
in it has a different roof from the portrait catalogue, and the sheet is
text; the drawn blueprint still exists for churches only.

## 4. Furnishing, by family

| Family | Who furnishes | Reach | Checked by |
|---|---|---|---|
| House, shop, hotel, castle interiors | `HouseFurnisher` + recipes | 35 categories, 84 props of 233 | six `HouseFurnish*Check`s, nav, plan |
| Church | `ChurchFurnisher` | 21 named props | `DressingCheck` (known, inside, clear, walk, lit) |
| Castle shell | `CastleFurnisher` | 42 named props | `DressingCheck`, `castle_yard_suite` |
| Temple | `TempleBuilder._dress` | 8 props | `TempleRiteCheck.fire`, `cells` |
| Village | `VillageDresser` | 24 categories; 7 have no prop and are built | `VillageDressCheck` |
| World courtyard | `HouseFurnisher` via the courtyard generator | as house | `court` |
| Mosque | a fountain | 1 | `qibla` |
| 17 other world families | nothing | 0 | shells only |

Observations:

- 149 of 233 catalogued props are reachable by no house recipe. The unused
  categories are mostly plants, rubble, urns, statues and columns, which is
  right for a house; `war_banner`, `tall_bookcase`, `reliquary`, `cask` and
  `wagon` are not.
- The furnisher's repair pass removes furniture until the house walks, and
  records what it removed. At default scale it removes the kitchen hearth in
  three of the eight archetypes. That is the wrong thing to remove first.
- The castle chapel's 158 `seating` warnings are pews measured by a dining
  rule; [CASTLE_INTERIOR_WARNINGS.md](CASTLE_INTERIOR_WARNINGS.md) says so
  and defers to INT-005. It has been deferred since 2026-09-13.
- The library family's 27 warnings are all one thing: `Bookcase_2 stands
  free, no wall in the room would take it`, in the stacks, at every scale.
  A library whose bookcases cannot find a wall is a planner problem, not a
  furnishing one.
- Nothing is furnished outside: no yard, fence, cart or woodpile beside a
  house. [house_exterior_tasks.json](tasks/house_exterior_tasks.json) has
  the task pending with ten others.

- `ckfurnish`, `psconce` and `cshop` pass with the nine documented keep
  warnings (free-standing cabinets, lopsided lamp pairs on polygon facets).
  `dressing` fails as described in 2.1. `interior` did not run: the batch
  that carried it was killed inside `placement` at the hour.
- The two INT-012 and INT-013 contract suites pass, so the thieves' den,
  bathhouse, hospice, school and market hall are furnished as their
  contracts ask. Only the archetype suite's table is wrong about them.

## 5. Documentation that no longer matches the code

- [KNOWN_ISSUES.md](KNOWN_ISSUES.md) says houses are one storey (they are
  one to three with a cellar), that `src/building/` awaits a decision (the
  directory is gone), and that the full suite takes nine minutes.
- [HOTELS.md](HOTELS.md) names `hotel hlandmark` as the gate; it fails.
- [QA_FAST_PROTOCOL.md](QA_FAST_PROTOCOL.md) records `sarchetype` and `shop`
  in `lane:library-change` without their standing failures.
- The `waterfree` todo store is empty: zero pending, zero ready. None of the
  seven failures above has a task.

## 6. What to do first

1. Fix the three test defects (`sarchetype` table, `wld003` row lookup,
   `cshop` method names) so the routine lanes can go green and mean it.
   Then decide what `dressing` should measure now that castle interiors are
   plans, and put it, `hlandmark`, `court` and `wld001` in a scheduled lane.
2. Reject or clamp a prison whose width has no cell layout; add the dead
   bands to the `shop` suite as a fixture.
3. Teach the hotel builder rugs, hearth breasts and door-trim clearance, or
   decide the hotel is not a house and give it its own rules.
4. Print the riad roof corner points and decide whether the emitter or the
   rule moved.
5. Make the repair pass remove the hearth last, after everything optional.
6. Lift the temple floor light and give the idol its height; both are
   constants.
7. Swing the key light in the portrait stage. It was S1 in September; it is
   still the cheapest change that touches no geometry.

## 7. What was done the same day

Nineteen tasks were filed in the todo store (EVAL-C01 to C13, B01 to B07,
U01 to U03) and worked by one agent each in isolated worktrees, correctness
first, then beauty, then usefulness. Fourteen were merged into `main` on
2026-10-01; the merged tree was confirmed after each builder-touching merge.

| Task | What landed | Verified on the merged tree |
|---|---|---|
| C01 | sarchetype rooms/fittings table, wld003 row lookup, cshop controls call the affinity check | sarchetype 69/0, wld003 13/0, cshop 21/0 |
| C02 | dressing sweep pools shell props with planned interiors; `dressingquick` | dressingquick 50158/0, dressing 567149/0 |
| C03 | prison tiles every library width; dead-band fixtures | prison 175/0, shop 30/0 |
| C04 | hotel rugs, hearth breast, entrance trim, declared facade reach | hlandmark 3/0, hotel 6/0 |
| C05 | one court record per storey is one court; single roof ring | wld001 riad/palazzo/domus 16/0 each |
| C06 | court ranges divided into rooms with yard doors and glass | court 105/0, warnings 454 to 4 |
| C07 | street and hamlet site baselines, two negative controls | vquick 10/0, vsite 161/0 |
| C08 | chimney room chosen by whether the hearth fits its wall | hearth warnings 6 to 0 |
| C09 | idol fills the room, serpent silhouette, readable dark stage | rite 60/0, dominance warnings gone |
| C10 | crowns fill their promise; head-height promise matches the mesh | tree 835/0, warnings 142 to 13 |
| B01 | per-shot shadow reach, camera-relative key by family, hazed ground | catalogue, scene-qa, vis004 regenerated |
| B03 | Florence crossing and tribunes, St Basil cluster, Hagia bearing | lane:church-change 5411/0, 90 sweep churches unchanged |
| B04 | `core/material_kit.gd`; 21 world families, bridges and trees dressed | matkit 204/0, every wld suite unchanged |
| B05 | village ground surfaces, orchard variation, river bank and reeds | vquick, vsite, vwater, vmill, venclosure 0 failures |
| B06 | house yard: planned placements, built pieces, `HouseYardCheck` | hexterior 2045/0, lane:geom 7080/0 |
| U02 | the house blueprint sheet in the Studio | hblueprint 189/0, church sheet byte-identical |
| U03 | libraryquick, placementquick, lane:api, lane:scheduled, true lane tables | lane:api 149/0, library 77/0 in 601 s |

Confirmations of the merged tree: 42 suites / 66,960 checks / 0 failures
after the correctness merges; 22 / 13,929 / 0 after the material kit;
14 / 7,266 / 0 after the hotel roof and blueprint changes. The final run of
every fast lane plus `lane:api` on the day's last merge
(`artifacts/eval_20261001/final_confirm_main_1204daf.log`) gave 48 suites /
69,652 checks / 16 failures, all one cause the yard agent's own lanes could
not see: the new `HouseYardCheck` access rule ("a ground-floor exterior door
cannot be reached from the road edge") fires on house plans that have no
road edge, namely castle interior plans, the world courtyard houses and the
guildhall. Filed as EVAL-C14 and assigned the same day; until it lands,
`lane:castle-change`, the three `wld001` bounded selectors and `sarchetype`
are red for that reason alone.

Still open: B02 castle yards and moat (step 1 verified, step 2 unverified,
on branch `wip/castle-yards-moat`), B07 sky castle dressing, C11 and C13
village scheduled suites, C12 the farmhouse chimney in the back door, U01
the rest of the document refresh. The September rubric was not re-scored;
the pictures to score are in `artifacts/renders/` at `main`.
