# World buildings, 400–1500: the Mediterranean, Asia and India

A reference in the shape of `CASTLES.md` and `TEMPLES.md`: real buildings with
real dimensions, the features that make each one what it is, and — because
the harness has been the most important part of this project — a set of
rules per family that a check can measure from the plan, the `mass_log` and
the walk grid, the way `TempleRiteCheck` measures the rite.

The window is 400 to 1500. A few forms (the domus, the stupa) were invented
before it, but they were still being lived in and built inside it, and they
are the ancestors of everything else here. The selection test was simple:
would a person who has never seen the real thing recognise the *kind* of
building at a glance, and would it look at home next to the castles, halls
and temples the generator already makes. A pagoda passes. A Roman bath
complex the size of a town does not.

Every family ends with its rules. A rule is written as a sentence a person
would say out loud, then as the measurement that decides it, in the vocabulary
the harness already has: `mass_log` AABBs and `MassRules`, `HousePlan` rooms,
doors and windows, `WalkGrid` floods, and the `_segment_hits` sightline test
from the rite check. Where a rule needs something the representation cannot
express yet, the gap is named in section 4 rather than hidden.

---

## 1. Roman and Mediterranean

### 1.1 The courtyard house: domus, riad, palazzo

The oldest idea on this list and the one that pays off most, because it is
the same plan in Rome, Córdoba, Fez, Beijing, Jaipur and Nalanda with the
details swapped. A blank wall to the street, one door, and every room
turned inward onto an open court that gives the house its light and its air.

| Building | Where / when | Site (m) | Defining features |
|---|---|---|---|
| Roman domus | Italy, N. Africa, Levant; to c. 600 | 15–30 × 25–50 × 6 | fauces → **atrium** with **impluvium** under the **compluvium** → tablinum on the axis → **peristyle** garden; **tabernae** on the street with no door into the house; almost no street windows |
| Andalusian / Maghrebi riad | Córdoba, Fez, Marrakesh; 900–1500 | 12–25 × 15–30 × 7 | **bent entrance** so the street cannot see the court; a fountain at the centre; galleries on two or four sides; two storeys |
| Ca' d'Oro, Venice | 1421–1437 | ~20 wide × 30 deep × 20 | **water gate** on the canal into the androne; **portego** running the depth; tripartite facade with the loggia at the centre; piano nobile |
| Tuscan palazzo (Davanzati, Florence) | c. 1350 | 20 × 25 × 25 | a rusticated blind ground floor, a **cortile** with a well, three storeys of rooms round it, a loggia on top |

**What it reads as in fantasy.** The merchant prince's house, the
sorcerer's town house with a garden nobody can see, the thieves' guild
behind a blank wall.

**What the generator needs.** A `HousePlan` with a hole in it: rooms tile
the interior *minus* the court, the court is floor for the walk grid but
sky for the roof, and rooms have doors onto it. That is the courtyard
upgrade in section 4, and every family in this document except the pagoda
and the tower wants it.

**The rules — `CourtCheck`.**

| Rule | The sentence | The measurement |
|---|---|---|
| **sky** | the court is open above | no AABB in `mass_log` intersects the column above the court rect between eave height and infinity, except a `compluvium` roof ring that leaves the impluvium's rect uncovered |
| **inward** | every room looks at the court, not the street | every habitable room has at least one door or window whose normal points into the court; the street wall carries no window below 2.2 m and exactly one house door |
| **blind entry** (riad, siheyuan) | you cannot see into the house from the street | `_segment_hits` from eye height in the middle of the street door to every point of the court's centre rect is blocked by a wall or screen mass |
| **the view through** (domus) | you CAN see from the front door across the atrium to the tablinum | the same ray from the fauces to the tablinum door is clear — the two rules are opposites, and the family flag decides which applies |
| **ring** | you can walk round the court and reach every door | flood the court from the entrance; every door threshold on the court is `reached` |
| **water** | the pool is under the hole, the well is in the middle | the impluvium rect is inside the compluvium opening's projection; a fountain or well stands within 0.15 × court width of the court centre |
| **proportion** | the court is a room without a roof, not a yard | court width between 0.6 and 2.5 × the eave height round it |
| **shops** | the tabernae face the street and do not open into the house | a `shop` room has a street opening ≥ 2 m wide and no door to any non-shop room |
| **water gate** (Venetian) | the front door is on the water | one exterior door with a threshold at or below 0.3 m above the water plane, on the wall flagged `canal`, and the portego runs from it to the far wall on the axis |

### 1.2 The insula

Rome's and Ostia's apartment blocks: shops at the pavement, flats stacked
above, a courtyard in the middle of the bigger ones, and a height limit set
by emperors who had watched them fall down.

| Building | When | Size | Defining features |
|---|---|---|---|
| Insula dell'Ara Coeli, Rome | 2nd c., in use through the window | ~30 × 20 × 20 | five storeys; tabernae below; flats of two to four rooms |
| Ostia garden houses | 2nd–5th c. | blocks ~60 × 40 | flats round a **medianum** — a central room with the windows — with cubicula off it; stairs from the street |

Height: Augustus capped insulae at ~20.7 m, Trajan at ~17.75 m.

**Fantasy read.** The tenement in the port city; the alchemists' quarter.

**The rules — `InsulaCheck`.**

| Rule | The sentence | The measurement |
|---|---|---|
| **cap** | no higher than the law allows | total height ≤ 20.7 m; storeys between 3 and 6 |
| **pavement** | every ground-floor room on the street is a shop | ground-floor rooms with a street wall are `shop` kind with an opening ≥ 2 m; no dwelling room on the ground floor has a street window |
| **stair** | one stair from the street serves every floor | a stair room with an exterior door; `HouseNavCheck` reaches every flat's door from that door and from nowhere else |
| **flat** | each flat is a medianum with its rooms off it | rooms group into flats (a `unit` id); each unit has one room with ≥ 2 windows and every other room in the unit has a door onto it |
| **daylight** | no room without a window, ever | the existing daylight rule, with the court counting as outside |

### 1.3 The tower house

Bologna had close to a hundred of them; San Gimignano still has fourteen.
Slender, square, blind for the first two storeys, with the door up a
removable stair and one room per floor.

| Building | When | Size | Defining features |
|---|---|---|---|
| Torre degli Asinelli, Bologna | 1109–1119 | ~8 m square, 97 m | 498 steps; walls thicker at the foot |
| Torre Garisenda, Bologna | c. 1109 | ~8 m square, 48 m | leans; cut down in the 1300s |
| San Gimignano towers | 1100–1300 | 5–8 m square, 25–54 m | fourteen surviving of 72; Torre Grossa 54 m |

**Fantasy read.** The wizard's tower without a fantasy in sight. Give it a
conical cap and a balcony and it is the one every cover artist paints.

**The rules — `TowerCheck`.**

| Rule | The sentence | The measurement |
|---|---|---|
| **slender** | it is a tower, not a house | height ≥ 4 × the longer base side; base ≤ 10 m |
| **lift** | the door is out of reach | the only exterior door's sill ≥ 2.0 m above ground; no opening at all below 2.0 m |
| **stack** | one room per floor and one stair through all of them | every storey is one room; `stairs` chain 0 → top; the roof platform is a storey the walk reaches |
| **foot** | the wall is thickest where it carries most | wall thickness at storey 0 ≥ 1.5 × thickness at the top storey |
| **no gaps** | nothing floats | `MassRules.gaps` and `grounded` as for castles |

### 1.4 The hypostyle mosque

A forest of columns in front of a wall that faces Mecca, an open court with
a fountain, and the tallest thing on the skyline standing beside it.

| Building | When | Size | Defining features |
|---|---|---|---|
| Great Mosque of Córdoba | 785, enlarged to 988 | 180 × 130 overall | 11 then 19 **aisles** perpendicular to the **qibla** wall; double-tier horseshoe arches on ~850 columns; **sahn** with orange trees; minaret 47 m on an 8.5 m square |
| Great Mosque of Kairouan | 836 | 135 × 80 | 17 aisles; a wide central aisle; a 31.5 m three-tier square minaret |
| Ibn Tulun, Cairo | 879 | 162 × 162 with ziyada | brick piers; a spiral minaret |

**Fantasy read.** The desert cult's hall of a thousand pillars; the
library of the caliph.

**The rules — `QiblaCheck`.**

| Rule | The sentence | The measurement |
|---|---|---|
| **qibla** | the prayer wall is blank, and the niche is in its middle | the wall flagged `qibla` has no door; the mihrab mass is centred on it within 0.02 × its length |
| **grid** | the columns stand in rows and files | every column has a neighbour at the file pitch and at the row pitch, within 0.05 × pitch, or stands at an edge; the aisles run perpendicular to the qibla; the central aisle ≥ 1.2 × the others |
| **sightline** | from the court door you see the mihrab down the central aisle | `_segment_hits` from the sahn door to the mihrab's upper half, tested against every column and wall |
| **sahn** | an open court on the axis with water in the middle | `CourtCheck.sky` and `.water` on the sahn; the sahn shares the hall's axis |
| **minaret** | the tallest mass is the minaret, and it stands outside the hall | the tallest AABB is tagged `minaret`; it does not intersect the hall's AABB |
| **rows** | the hall is standing room | standable floor ≥ 0.6 × hall area; no column in the central aisle |

### 1.5 The hammam

Rome's baths shrunk to a neighbourhood: a sequence of ever-hotter rooms,
no windows at all, domes pierced with glass to let the light down through
the steam.

| Building | When | Size | Defining features |
|---|---|---|---|
| Caliphal Baths, Córdoba | 10th c. | 20 × 15 | changing → cold → warm → hot, in a line; horseshoe arches on columns in the warm room |
| Arab Baths of Jaén | 11th c. | 450 m² | the largest surviving Andalusian warm room; star-pierced vaults |
| Mahmut Pasha Hamam, Istanbul | 1466 | 30 × 20 | a great domed cold room, then warm, then hot; the furnace behind |

**Fantasy read.** The bathhouse under the thieves' quarter; the naga's steam
temple; a dungeon level that is not a dungeon.

**The rules — `HammamCheck`.**

| Rule | The sentence | The measurement |
|---|---|---|
| **gradient** | the rooms get hotter as you go in, and you cannot skip one | the door graph from the entrance is a path changing → cold → warm → hot; walk distance to each is strictly increasing; the hot room is a leaf |
| **blind** | no windows | zero windows on the plan; the daylight rule is replaced, not disabled |
| **oculi** | every room is lit from its dome | each bathing room has ≥ 1 roof opening (a new opening kind, `oculus`) within its rect; ≥ 3 in the warm room |
| **dome** | warm and hot rooms are domed | a `dome` mass whose footprint covers ≥ 0.8 of the room rect stands over each; the emitter is `MeshKit.revolve` |
| **furnace** | the fire is behind the hot room, on the far side from the door | a `furnace` mass touches the hot room's far wall (`MassRules.separation` ≤ allowance) and is not reachable from inside |

### 1.6 The caravanserai (han)

A fortified inn on the road: one tall portal, a blind outer wall, cells
and stables round a court, a vaulted hall at the back for winter, and a
little mosque raised on arches in the middle so the animals can walk under
it.

| Building | When | Size | Defining features |
|---|---|---|---|
| Sultan Han, Aksaray | 1229 | 4 900 m²; court 44 × 58; front 50 m | 13 m marble **portal**; **kiosk mosque** on arches at the court centre; stables with rooms above in the side arcades; a barrel-vaulted **winter hall** with a lantern dome |
| Ribat-i Sharaf, Khorasan | 1114 | 110 × 75 | two courts in line; brick |
| Ribat-i Malik | c. 1080 | 90 × 90 | a single court; a great pishtaq |

**Fantasy read.** The waystation on the trade road, the last inn before the
desert, every "you meet in a tavern" that is not in a town.

**The rules — `HanCheck`.**

| Rule | The sentence | The measurement |
|---|---|---|
| **one gate** | one way in, and a camel fits through it | exactly one exterior door; width ≥ 2.6 m, height ≥ 3.0 m; the outer wall carries no other opening below 3 m |
| **cells** | every traveller's room opens on the court | every `cell` room (≥ 3 × 3 m) has a door with its normal into the court and no other door |
| **stables** | a horse can get in | every `stable` room has a door ≥ 1.5 m wide onto the court |
| **hall** | the winter hall is at the back, on the axis | a `hall` room opposite the gate, centred on the axis within 0.05 × width; its AABB carries a `dome` mass at its centre |
| **kiosk** | the mosque stands on arches in the middle, and you can walk under and round it | a `kiosk` mass at the court centre with its floor ≥ 2.5 m up; the court flood reaches every side of it |
| **court** | `CourtCheck.sky`, `.ring` | as above |

---

## 2. East and South-East Asia

### 2.1 The courtyard compound: siheyuan

The Chinese house from the Tang to the Qing, and the cleanest statement of
courtyard planning anywhere: a walled compound on a north–south axis, the
gate at the south-east corner, a screen wall inside it, the main hall on
the north side facing south, side halls east and west, an opposite hall on
the south. Bigger houses add courtyards in line.

| Building | When | Size | Defining features |
|---|---|---|---|
| One-court siheyuan (Beijing type) | 1200–1500 in this form; the plan is Tang | 20 × 30 × 5 | gate at **SE corner**; **screen wall**; main hall 3 or 5 bays, tallest, on the north; wings east and west; a covered walk joining them |
| Two- and three-court compounds | | 20 × 60–90 | courts in line on the axis; the inner court private; a garden at the back |

The vocabulary is feng shui as written down: the gate in the *xun* corner,
the main hall facing south, the screen so nothing rushes straight in.

**Fantasy read.** The scholar's house, the martial school, the magistrate's
yamen, the walled compound of a great family.

**The rules — `SiheyuanCheck`, on top of `CourtCheck`.**

| Rule | The sentence | The measurement |
|---|---|---|
| **corner gate** | the gate is at the corner, not in the middle | the exterior door's centre is ≥ 0.3 × site width from the axis, on the front wall |
| **screen** | you cannot see the court from the gate | `CourtCheck.blind entry`, satisfied by a `screen` mass inside the gate |
| **south** | the main hall faces the entrance side and is the biggest and tallest | the `main_hall` room is on the far wall from the gate, centred on the axis; its area ≥ every other room's; its ridge is the highest AABB in `mass_log` |
| **wings** | the side halls mirror | every `wing` room has a twin across the axis with the same rect mirrored within 0.1 m |
| **walk** | the covered way joins the three halls | a `verandah` floor strip runs continuously from the main hall's door to both wings' doors; the court flood reaches all three without leaving it |
| **courts in line** | a bigger house is more courts, not a bigger court | every court's centre lies on the axis; courts are ordered front to back with a hall between each pair |

### 2.2 The timber hall on a platform

The building the whole of East Asia is made of: a stone platform, a grid of
wooden columns, bracket sets, and a roof so deep and heavy it *is* the
building. The same hall is a temple, a palace throne room, a gate and a
library.

| Building | When | Size | Defining features |
|---|---|---|---|
| Foguang Temple, East Hall | 857 | 34 × 17.7; 7 × 4 bays | the oldest large Tang hall; inner and outer column rings; bracket sets half a column high; hipped roof; on a 13 m terrace |
| Hōryū-ji kondō | rebuilt after 670 | 18.5 × 15.2 | two storeys of roof; the first eave once reached **4 m** beyond the wall |
| Tōdai-ji Daibutsuden | 752; rebuilt 1709 | originally 11 bays (~86 m) wide; now 57 × 50 × 49 | the largest wooden hall ever built; a 15 m Buddha under it |
| Byōdō-in Phoenix Hall | 1053 | central hall ~14 × 10; wings ~30 each side | a hall with **wing corridors** and a **tail corridor**, facing east across a pond |
| Nanchan Temple hall | 782 | 11.6 × 10; 3 × 3 bays | the smallest and oldest: three bays, hip-and-gable roof |

**Fantasy read.** The elven hall, the temple of the monkey king, the throne
room of the eastern emperor, the monastery where the monks fight.

**What the generator needs.** A column grid the way `TempleGeometry` already
lays one out, a `hip`/`hip-and-gable` roof emitter with an *overhang*
parameter, and a plinth. Interiors are one room with a dais, which the
`focus` idea from the layouts critique handles.

**The rules — `HallCheck`.**

| Rule | The sentence | The measurement |
|---|---|---|
| **bays** | an odd number of bays, and the middle one widest | column count along the front is even (so bays are odd) and ≥ 4; the central bay ≥ every other bay; bay widths mirror about the axis |
| **rings** | the columns stand in an outer ring and an inner ring | every column has a twin across the axis (`_has_mirror`); columns lie on exactly two closed rectangles, or one for a three-bay hall |
| **plinth** | it stands on a platform with the stair on the axis | the hall's floor AABB base ≥ 0.6 m above ground; a `stair` mass on the front, centred within 0.05 × width |
| **eaves** | the roof reaches out | eave overhang beyond the outer column line ≥ 0.25 × column height on every side |
| **roof** | the roof is the building | roof rise from eave to ridge ≥ 0.5 × column height; roof footprint covers the plinth |
| **axis** | the image is at the back on the axis, and you see it from the door | the `image` mass centred within 0.02 × width; in the back third; `_segment_hits` clear from the front door threshold to its upper half |
| **clear** | there is room to stand between the columns | standable floor ≥ 0.5 × hall area; no column within `PATH_MIN` of the axis |
| **wings** (Phoenix type) | the wings mirror and the pond lies in front | wing corridors mirror across the axis; a `water` rect in front of the plinth wider than the hall; the sightline from across the water to the image is clear |

### 2.3 The pagoda

A tower of stacked roofs on a mast. Wooden ones you can climb; brick ones
are often solid or nearly so. The eaves shrink storey by storey, and the
storey count is odd.

| Building | When | Size | Defining features |
|---|---|---|---|
| Sakyamuni Pagoda, Fogong Temple (Yingxian) | 1056 | 67.3 m tall on a 4 m plinth; ~30 m across | **octagonal**; five storeys outside, **nine inside** (four hidden mezzanines); 54 kinds of bracket; no nails; a 10 m steeple |
| Giant Wild Goose Pagoda, Xi'an | 652, rebuilt 704 | 64.1 m; base ~25 m | **square brick**; seven storeys; each storey shorter and narrower; a stair inside |
| Hōryū-ji five-storey pagoda | c. 700 | 32.45 m | a **central pillar** felled in 594; the fifth storey markedly small |
| Songyue Pagoda | 523 | 40 m; 12-sided | the oldest brick pagoda; fifteen close-set eaves over a tall first storey |
| Liaodi Pagoda, Dingzhou | 1055 | 84 m | the tallest premodern Chinese building; octagonal, eleven storeys, a stair through a hollow core |

**Fantasy read.** The wizard's tower of the east, the tomb-tower of the
lich, the watchtower over the mountain pass.

**What the generator needs.** The stepped-taper emitter already in `MeshKit`
plus a roof ring per storey; polygon plans (square, octagon, twelve) which
`revolve` at low segment count can fake on the outside but the interior
rooms cannot — polygon rooms, section 4.

**The rules — `PagodaCheck`.**

| Rule | The sentence | The measurement |
|---|---|---|
| **odd** | an odd number of storeys | visible eave tiers are odd and between 3 and 15 |
| **taper** | every storey is a little smaller and a little shorter than the one below | eave tier *i* is 0.88–0.98 × tier *i−1* in width and ≤ it in height; the sequence is monotone |
| **mast** | one axis runs through the whole tower | a `mast` mass on the axis intersects every storey's AABB, or for solid brick types, the storeys' centres lie on the axis within 0.02 × base width |
| **plan** | a regular polygon | the base is square, octagonal or twelve-sided; every storey has the same polygon |
| **slender** | tall but not thin | total height ÷ base width between 2.0 and 4.0 |
| **crown** | a steeple, in proportion | the finial is 0.1–0.2 × total height and the topmost mass |
| **climb** (hollow types) | the stair reaches the top | `stairs` chain storey 0 to the top; each landing standable |
| **hidden floors** (Yingxian) | the mezzanines are inside, not outside | interior storey count may exceed eave tiers; every interior storey lies within the tier above it |

### 2.4 The tulou

The Hakka clan fortress of Fujian: a ring of rammed earth three to five
storeys high, blind on the outside except for one gate, every room facing
inward on wooden galleries, the ancestral hall at the centre of the
court. Hundreds were built; the oldest surviving are from 1308 and 1371.

| Building | When | Size | Defining features |
|---|---|---|---|
| Chengqi Lou | 1709 (the type is 14th c.) | 62.6 m across; 4 storeys; 288 rooms | **four concentric rings**; 72 rooms per floor in the outer ring; four stairs at the cardinal points; the ancestral hall in the middle |
| Yuchang Lou | 1308 | 36 m; 5 storeys | the oldest round one; leaning posts |
| Square tulou (Heguilou, 1732) | | 5 storeys | the same plan on a square |

**Fantasy read.** The dwarven clan-hold above ground; the halfling
commune; the monastery-fortress. It is the most immediately fantastic
real building in this document.

**The rules — `TulouCheck`.**

| Rule | The sentence | The measurement |
|---|---|---|
| **ring** | a closed wall, thick at the foot | the outer wall is a closed loop (round or square); thickness at storey 0 ≥ 1.2 m and ≥ 1.4 × thickness at the top |
| **blind** | no windows low down, and one gate | zero openings in the outer wall below the third storey except ≤ 2 gates; the main gate on the axis |
| **inward** | every room opens on the gallery | every room has exactly one door, its normal toward the centre, onto a continuous `gallery` floor ring; the gallery flood on each storey goes full circle (reaches its own start from the other direction) |
| **equal** | every room on a ring is the same | room widths on a ring within ±5 % of each other; room count per ring the same on every storey |
| **centre** | the ancestral hall is in the middle, under the sky | a `hall` room at the centre; the court round it satisfies `CourtCheck.sky` |
| **stairs** | stairs spaced evenly round the ring | ≥ 2 stairs; angular spacing within ±15° of even |
| **storeys** | three to five | 3 ≤ storeys ≤ 5 |

### 2.5 The temple mountain

Angkor, Borobudur, Prambanan: enclosures inside enclosures, each higher
than the last, a causeway on the axis, and a quincunx of towers on the
summit with the tallest in the middle. It is the temple rite check turned
into a mountain.

| Building | When | Size | Defining features |
|---|---|---|---|
| Angkor Wat | 1113–1150 | outer wall 1 024 × 802 × 4.5; moat 190 m wide; galleries 187 × 215, 100 × 115, 60 sq.; central tower 65 m | three nested galleried terraces; **quincunx**; a 350 m **causeway**; faces **west** |
| Borobudur | c. 780–833 | 118 m square; 35 m | six square and three circular platforms; a stair on each side; 72 stupas round one; a 3 km circumambulation |
| Prambanan | 856 | Shiva temple 47 m tall, 34 m wide; zones 390 and 225 m square | three concentric walled zones with gates at the cardinal points; 224 minor shrines in four rings |
| Bayon | c. 1200 | 140 × 160 | face towers; three levels |

**Fantasy read.** The lost temple in the jungle, the mountain of the
serpent-god, the level-with-a-boss-at-the-top.

**The rules — `MountainCheck`, extending `TempleRiteCheck`.**

| Rule | The sentence | The measurement |
|---|---|---|
| **nest** | rings inside rings, each higher | every enclosure rect strictly contains the next; floor level rises with each (≥ 1.5 m per step); `MassRules.overlaps` allows only the stair joints |
| **quincunx** | five towers on top, the middle one tallest | five `tower` masses on the top terrace: one at the centre, four at the ordinal corners equidistant from it within 0.05; the centre one taller than the others by ≥ 1.2× |
| **axis** | the causeway leads straight to the top | the causeway rect is centred on the axis; every gopura (gate) on the axis; `_segment_hits` from the causeway start to the central tower's upper half is clear |
| **moat** | water all the way round, one crossing | a `water` rect surrounds the outer wall on all sides ≥ 20 m wide; exactly one causeway crosses it |
| **climb** | the pilgrim can walk from the gate to the summit | the walk grid, one level per terrace with the stairs as links, reaches the top platform; never narrower than 1.2 m |
| **pradakshina** | each gallery is a loop you can walk round | on every terrace the gallery flood returns to its start |
| **symmetry**, **dominance** | as the rite check | `_check_symmetry`, `_check_dominance` applied to the whole mountain |

### 2.6 The cruciform temple: Bagan

| Building | When | Size | Defining features |
|---|---|---|---|
| Ananda Temple, Bagan | 1105 | 53 m square core; porches 17 m out on each face; 51 m tall | a **Greek cross**; four 9.5 m standing Buddhas facing the cardinal points; **two concentric vaulted corridors** round the core; a stepped sikhara |

**Fantasy read.** The temple of the four winds; a dungeon that is four
shrines and two rings.

**The rules — `CruciformCheck`.** four entrances on the cardinal axes,
mirrored in both axes (`_has_mirror` in x *and* z); four `image` masses each
facing its own entrance with a clear sightline; the two corridor rings both
walk full circle and are linked; the sikhara the tallest mass and centred.

---

## 3. India

### 3.1 The Nagara temple: Khajuraho

A sequence of halls that each rise higher than the last, ending in a small
square dark sanctum under a curved spire that is buttressed by dozens of
smaller spires clustered round it like a mountain range.

| Building | When | Size | Defining features |
|---|---|---|---|
| Kandariya Mahadeva, Khajuraho | c. 1030 | 31 × 20 × 31; on a 4 m plinth | ardhamandapa → mandapa → mahamandapa → antarala → **garbhagriha**; the halls **rise in sequence**; **84 subsidiary spires** on the shikhara; a circumambulatory passage |
| Lakshmana, Khajuraho | 954 | 26 × 13 | four corner shrines on the plinth (panchayatana) |
| Sun Temple, Modhera | 1026 | with a stepped **kund** (tank) in front | hall, dance pavilion, tank, in a line on the axis |

**Fantasy read.** The temple of the many-armed goddess; the spire that is a
hundred spires.

**The rules — `ShikharaCheck`, extending `TempleRiteCheck`.**

| Rule | The sentence | The measurement |
|---|---|---|
| **ascent** | each hall is taller than the one before | ridge/roof heights of the halls along the axis are strictly increasing toward the sanctum; the shikhara is the tallest (`_check_dominance`) |
| **axis** | entrance, halls, sanctum on one line | every hall's centre within 0.02 × width of the axis; doors between them on the axis |
| **sanctum** | small, square, dark, one door | the garbhagriha area ≤ 1/6 of the largest hall; aspect within 1.1; no window; exactly one door, on the axis |
| **plinth** | it stands on a platform you climb on the axis | floor ≥ 0.1 × shikhara height above ground; a stair on the front axis |
| **cluster** | the little spires hug the big one and none is taller | every `urushringa` mass touches the main shikhara's AABB (`separation` ≤ 0) and its top is below the main's by ≥ 0.15 × its height |
| **pradakshina** (sandhara type) | you can walk round the sanctum inside | a passage ring round the garbhagriha; the walk flood circles it |
| **sightline** | the image is seen from the mandapa | as the rite check, from the mandapa door |

### 3.2 The Dravida compound: Thanjavur and after

The southern temple is a walled town: a rectangular enclosure with a
colonnade inside its wall, gate-towers on the axis, a Nandi pavilion facing
the sanctum, and a stepped pyramid over the sanctum. Before about 1200 the
sanctum tower is the tallest thing; after it the gateways overtake it.

| Building | When | Size | Defining features |
|---|---|---|---|
| Brihadisvara, Thanjavur | 1003–1010 | compound 241 × 122; vimana 63.4 m on a 30 m square | the tallest vimana in India; 16 tiers; a **prakara** colonnade 450 m round; two gopurams on the axis; **Nandi mandapa** |
| Airavatesvara, Darasuram | 1150 | | a hall carved as a chariot with wheels |
| Meenakshi, Madurai | 1200–1600 | 254 × 238; gopurams to 52 m | fourteen gopurams; the gates taller than the shrine |

**Fantasy read.** The temple city; the god-king's precinct.

**The rules — `PrakaraCheck`.**

| Rule | The sentence | The measurement |
|---|---|---|
| **enclosure** | a walled rectangle with a colonnade inside it you can walk fully round | `CourtCheck.ring` on the prakara; the colonnade floor strip is continuous |
| **gates** | the gopurams stand on the axis, in the walls | every `gopuram` mass is centred on the axis and intersects an enclosure wall |
| **who is tallest** | before 1200 the vimana; after, the gate | a `period` flag on the spec; the tallest AABB is `vimana` or `gopuram` accordingly |
| **nandi** | the bull faces the god from the court | a `nandi` mass on the axis between gate and hall, facing +axis, with a clear sightline to the sanctum door |
| **tiers** | the vimana steps | the stepped-taper tiers over the sanctum decrease monotonically; tier count ≥ 5 |
| **flagstaff** | on the axis, before the hall | a `dhvaja` mass between the inner gate and the first mandapa, on the axis |

### 3.3 The rock-cut temple

A building made by taking stone away: a courtyard quarried down from the
hilltop and a whole temple left standing in it, bridges and all.

| Building | When | Size | Defining features |
|---|---|---|---|
| Kailasa, Ellora | c. 760 | court 82 × 46, cut ~30 m down; the temple ~7 m per storey on two storeys | a **two-storey gateway**; **Nandi mandapa** joined to the porch by a rock bridge; elephants carrying the plinth; pillars 17 m tall; a colonnade cut into the pit walls |
| Ajanta caves 19, 26 | 5th c. | halls ~14 × 11 | chaitya halls: an apsidal nave with a stupa at the end, a horseshoe window over the door |

**Fantasy read.** The dwarven temple; the thing at the bottom of the
quarry; the place the dragon sleeps.

**The rules — `CutCheck`.** The harness's assumptions inverted, which is
the interesting part.

| Rule | The sentence | The measurement |
|---|---|---|
| **negative** | nothing rises above the ground | every mass except the gateway has its top ≤ ground level; the `pit` rect is the site |
| **free-standing** | the temple touches the pit walls only where it is meant to | `MassRules.separation` between the temple masses and the pit wall ≥ `BAILEY_CLEAR`, except the `bridge` joints |
| **bridge** | the Nandi pavilion is joined to the porch by a bridge you can cross | a `bridge` mass whose floor the walk reaches from both ends, ≥ 1.2 m wide |
| **axis** | gate, Nandi, porch, hall, sanctum in a line | as `ShikharaCheck.axis`, inside the pit |
| **sky** | the court is open above | `CourtCheck.sky` over the pit floor between the temple and the walls |
| **gallery** | the pit walls hold a colonnade you can walk | a floor strip along the pit's walls, reached by the flood |

### 3.4 The stepwell

A building that goes down instead of up: a corridor of stairs descending
through pavilioned landings to a tank and a well shaft, open to the sky for
its whole length.

| Building | When | Size | Defining features |
|---|---|---|---|
| Rani ki Vav, Patan | 1063–1083 | 65 long × 20 wide × 28 deep | seven levels of stairs from the east; pillared multistorey **pavilions** at intervals; the **well shaft** 10 m across and 30 m deep at the west; a 9.5 × 9.4 tank at −23 m |
| Chand Baori, Abhaneri | 8th–9th c. | ~35 m square, 30 m deep | 3 500 steps on three sides in an inverted pyramid; a pillared pavilion on the fourth |
| Adalaj Vav | 1498 | 75 long; five storeys deep | three entrances meeting at an octagonal landing |

**Fantasy read.** The way down; the well the cult meets at; the most
dungeon-like building ever made for fetching water.

**The rules — `VavCheck`.**

| Rule | The sentence | The measurement |
|---|---|---|
| **descent** | you walk down every flight from the entrance to the water | storeys 0 → −N chained by `stairs`; the walk reaches the tank edge; no flight steeper than 40° |
| **landings** | a pavilion at every level, wider than the stair | on every level a standable landing rect ≥ 1.5 × stair width, roofed by a `pavilion` mass on columns |
| **narrowing** (Chand Baori type) | each tier is smaller than the one above | tread rects on level *i* lie strictly inside those on *i+1*; the profile is a straight line |
| **shaft** | the well at the far end, round, deeper than the tank | a `shaft` cylinder on the axis at the far end; its bottom below the tank floor |
| **sky** | open above the whole corridor | `CourtCheck.sky` over the stair corridor, pavilions excepted |
| **water** | the tank at the bottom | a `water` rect at the lowest level; the flood reaches its edge on ≥ 3 sides |
| **no gaps** | nothing floats over the void | `MassRules.grounded` with the pit floor as the ground — pavilion columns must reach a landing |

### 3.5 The stupa

A solid hemisphere on a drum, a railed square on top carrying a mast of
parasols, a raised terrace you circle clockwise, and four gateways at the
cardinal points. Nothing to go into; everything to go round.

| Building | When | Size | Defining features |
|---|---|---|---|
| Great Stupa, Sanchi | enlarged 2nd c. BCE; toranas 1st c.; in use through the window | 36.6 m across, 16.5 m high | four **toranas**; a **drum terrace** for circumambulation with a double stair; a ground-level railed path; **harmika** and **chatra** |
| Dhamek Stupa, Sarnath | 500 | 28 m across, 43.6 m high | a tall cylinder rather than a dome |
| Borobudur's crown | 800s | 72 stupas round one | the stupa multiplied |

**Fantasy read.** The tomb of the saint; the sealed mound; a thing you
circle three times before the door appears.

**The rules — `StupaCheck`.**

| Rule | The sentence | The measurement |
|---|---|---|
| **solid** | there is no inside | the voxel flood from outside reaches no interior air; `count_solid` of the dome ≈ its volume |
| **dome** | a hemisphere on a drum, the harmika square on top, the mast through all of it | a `revolve` dome; `harmika` centred on top; `chatra` the topmost mass on the axis |
| **circle** | you can walk round it twice | the ground path and the drum terrace are both rings the walk goes fully round; the double stair links them |
| **cardinal** | four gates, on the axes | four `torana` masses at 0°, 90°, 180°, 270° from the centre, at the same radius within 0.05 |
| **dominance** | the dome is the tallest thing | as the rite check |

### 3.6 The vihara

The Buddhist monastery cell block: cells round a court, a verandah between,
a shrine on the axis facing the entrance. Nalanda had eleven of them in a
row, each rebuilt as many as nine times.

| Building | When | Size | Defining features |
|---|---|---|---|
| Nalanda monastery 1 | 5th–12th c. | ~50 × 40; the site 488 × 244 | cells on all four sides; the **shrine opposite the entrance**; a stair in the SW corner; a well in the court |
| Ajanta cave 1 | 5th c. | hall 20 m square, 20 cells | the same plan cut into rock |

**Fantasy read.** The monks' cloister; the mage school's dormitory; the
cell block that is not a prison.

**The rules — `ViharaCheck`, on top of `CourtCheck`.** every `cell` is
2.5–3.5 m square with one door onto the verandah and no window; cell widths
within ±5 %; the `shrine` room centred on the axis on the wall opposite the
entrance, its door facing the entrance with a clear sightline between; the
verandah floor strip continuous on all four sides; a well or tank at the
court centre.

### 3.7 The haveli and the vastu house

The Indian courtyard house: a deep, narrow light-well of a court, storeys of
rooms round it, and on the street a facade of projecting balconies
(**jharokhas**). The plan is governed by *vastu*, which is to India what
feng shui is to China, and is just as measurable.

| Building | When | Size | Defining features |
|---|---|---|---|
| Haveli, Rajasthan / Gujarat | 1400 onward; the plan is older | 10–20 × 20–35 × 10 | a court narrower than tall; jharokhas; a *chowk* per family branch |
| Nalukettu, Kerala | 1300 onward | 20 × 20 × 6 | four ranges round a sunken court (*nadumittam*), sloping tiled roofs |

**The rules — `VastuCheck`, on top of `CourtCheck`.** The *vastu purusha
mandala* is a 9 × 9 grid over the plan, and it says where things go:

| Rule | The sentence | The measurement |
|---|---|---|
| **brahmasthana** | the centre is open | the court contains the central cell of the 9 × 9 grid; no mass stands in it |
| **agni** | the kitchen is in the south-east | the kitchen's centre lies in the SE quadrant of the site |
| **jal** | water is in the north-east | the well or tank lies in the NE quadrant |
| **door** | the entrance faces east or north | the front door's normal is +x or −z (east or north) in the site's frame |
| **light well** | the court is deep | court width ≤ 1.0 × the eave height round it (contrast the Mediterranean 0.6–2.5) |
| **jharokha** | balconies on the street, upstairs | ≥ 1 `jharokha` mass on the street facade with its floor ≥ one storey up and its footprint outside the site rect |

---

## 4. What the representation has to learn

Every rule above is measurable with today's tools *except* where it leans
on one of these. They are the same four gaps the layouts critique found,
plus two.

| Upgrade | Who needs it | What it is |
|---|---|---|
| **Courtyards** | every family in sections 1, 2.1, 2.4, 3.2, 3.6, 3.7 | a `HousePlan` whose rooms tile the interior minus one or more `court` rects; the court is floor to the walk grid, sky to the roof, and exterior to the daylight rule |
| **Polygon rooms** | tulou, pagoda, stupa, octagonal landings | room outlines as polygons with `rect` as bounding box; `WalkGrid` rasterises polygons |
| **Negative storeys** | stepwell, rock-cut, crypts | `storey` may be < 0; the builder digs a pit mass instead of raising walls; `MassRules.grounded` takes a ground level per building |
| **Roof openings** | domus (compluvium), hammam (oculus), tulou and every court | an opening kind on the roof, with a rect; `CourtCheck.sky` and `HammamCheck.oculi` read it |
| **Column grids as plan data** | halls, mosques, prakaras, viharas | `TempleGeometry` computes columns; they should be on the plan so the walk grid, the sightline and the symmetry rule all read one list |
| **A period / orientation flag** | Dravida (who is tallest), siheyuan (south), vastu (east) | the spec carries `period` and a compass so orientation rules mean something |

## 5. Archetypes for the suites

*Scaffold (WLD-000):* `BigGlade` has a `world` kind whose `style` is the
family and whose `purpose` is the sub-kind; `src/world/world_families.gd` is
the registry (`FAMILIES`, `generate()`, `build_mesh()`), and
`tests/suites/world_archetype_suite.gd` (`world` / `warchetype` in run_all)
builds every row at 70/100/140/190 %, runs its family check and MassRules,
and `assert_contains()` asks for masses, room kinds and furniture by name.
WLD-003 exposes `merchant_tower` through the `tower_house` family and adds the
focused `wld003` selector. It uses the CAS-006 shaft with an INT-004 room and
stair plan, including the reachable roof-platform level. Each family task adds
one row to the registry and its archetype rows here.

In the manner of `house_archetype_suite.gd`: what each must CONTAIN, never
where. Built at 70 %, 100 %, 140 % and 190 % and put through its own check
plus `MassRules`.

| Archetype | Family | Size (m) | Must contain |
|---|---|---|---|
| Merchant's domus | courtyard house | 22 × 40 × 6 | atrium, impluvium, tablinum, peristyle, two tabernae |
| Riad of the Spice Road | courtyard house | 18 × 24 × 7 | a bent entrance, a fountain, galleries |
| Canal palazzo | courtyard house | 20 × 30 × 18 | a water gate, a portego, three storeys |
| Port tenement | insula | 30 × 20 × 18 | five storeys, tabernae, one stair, six flats |
| Merchant's tower | tower house | 8 × 8 × 45 | a raised door, one room per floor, a roof platform |
| Hall of a Thousand Pillars | mosque | 90 × 60 × 12 | a qibla wall, a mihrab, ≥ 9 aisles, a sahn, a minaret |
| The Steam Baths | hammam | 24 × 16 × 8 | four rooms in a chain, three domes, oculi, a furnace |
| Sultan's Han | caravanserai | 70 × 55 × 12 | one gate, a court, cells, stables, a winter hall, a kiosk |
| Scholar's compound | siheyuan | 22 × 32 × 5 | a corner gate, a screen, a main hall, two wings |
| The Great Hall of the East | timber hall | 34 × 18 × 20 | seven bays, two column rings, a plinth, an image |
| Phoenix Pavilion | timber hall | 60 × 12 × 14 | a central hall, two wings, a pond |
| Nine-Storey Pagoda | pagoda | 30 × 30 × 65 | odd storeys, a taper, a mast, a stair to the top |
| Clan Ring | tulou | 60 × 60 × 15 | a ring, one gate, galleries, an ancestral hall, four stairs |
| Temple Mountain | temple mountain | 200 × 200 × 60 | three enclosures, a moat, a causeway, a quincunx |
| Temple of Four Winds | cruciform | 90 × 90 × 50 | four porches, four images, two corridor rings |
| Spire of a Hundred Spires | Nagara | 31 × 20 × 31 | four halls rising, a sanctum, a shikhara with urushringas, a plinth |
| God-King's Precinct | Dravida | 240 × 120 × 63 | a prakara, two gopurams, a Nandi, a vimana |
| Quarried Temple | rock-cut | 82 × 46 × 30 | a pit, a gateway, a bridge, a free-standing temple |
| The Queen's Well | stepwell | 65 × 20 × 28 | seven levels down, pavilions, a tank, a shaft |
| Saint's Mound | stupa | 40 × 40 × 17 | a dome, a drum terrace, four toranas, a harmika |
| Monks' Cloister | vihara | 50 × 40 × 5 | cells round a court, a shrine on the axis, a verandah |
| Merchant's Haveli | vastu house | 15 × 28 × 10 | a light-well court, a SE kitchen, a NE well, jharokhas |

## 6. Where the rules come from

The ten temple rules were each a real defect caught by a rule rather than
by looking. These are written the same way — as the defects one would
*expect* a generator to produce, and the sentence that would catch each.
Three are worth flagging because they invert something the harness
currently assumes:

- **`CourtCheck.blind entry` is the sightline rule negated.** The temple
  requires that you see the god from the door; the riad and the siheyuan
  require that you do *not* see the court from the gate. The same
  `_segment_hits` test answers both — it must be parameterised by "clear"
  or "blocked", not hard-wired.
- **`HammamCheck.blind` and `StupaCheck.solid` break the daylight rule and
  the walk.** A building with no windows and a building with no inside are
  both correct. The checks need a way for a family to *replace* a rule
  rather than switch it off, so a hammam with a window still fails.
- **`CutCheck.negative` and `VavCheck.descent` turn the ground plane into a
  ceiling.** `MassRules.grounded` assumes y = 0 is the ground. A per-building
  ground level is the smallest change that lets a stepwell be judged by the
  same rule that judges a keep.

## Sources

- Foguang Temple East Hall: https://en.wikipedia.org/wiki/Foguang_Temple
- Pagoda of Fogong Temple: https://en.wikipedia.org/wiki/Pagoda_of_Fogong_Temple
- Giant Wild Goose Pagoda: https://en.wikipedia.org/wiki/Giant_Wild_Goose_Pagoda
- Hōryū-ji: https://en.wikipedia.org/wiki/H%C5%8Dry%C5%AB-ji
- Tōdai-ji: https://en.wikipedia.org/wiki/T%C5%8Ddai-ji
- Byōdō-in: https://en.wikipedia.org/wiki/By%C5%8Dd%C5%8D-in
- Fujian tulou: https://en.wikipedia.org/wiki/Fujian_tulou
- Siheyuan: https://en.wikipedia.org/wiki/Siheyuan
- Angkor Wat: https://en.wikipedia.org/wiki/Angkor_Wat
- Borobudur: https://en.wikipedia.org/wiki/Borobudur
- Prambanan: https://en.wikipedia.org/wiki/Prambanan
- Ananda Temple: https://en.wikipedia.org/wiki/Ananda_Temple
- Kandariya Mahadeva: https://en.wikipedia.org/wiki/Kandariya_Mahadeva_Temple
- Brihadisvara, Thanjavur: https://en.wikipedia.org/wiki/Brihadisvara_Temple,_Thanjavur
- Kailasa, Ellora: https://en.wikipedia.org/wiki/Kailasa_Temple,_Ellora
- Rani ki Vav: https://en.wikipedia.org/wiki/Rani_ki_Vav
- Chand Baori: https://en.wikipedia.org/wiki/Chand_Baori
- Sanchi: https://en.wikipedia.org/wiki/Sanchi
- Nalanda: https://en.wikipedia.org/wiki/Nalanda_mahavihara
- Domus: https://en.wikipedia.org/wiki/Domus
- Insula: https://en.wikipedia.org/wiki/Insula_(building)
- Towers of Bologna: https://en.wikipedia.org/wiki/Towers_of_Bologna
- Ca' d'Oro: https://en.wikipedia.org/wiki/Ca%27_d%27Oro
- Mosque–Cathedral of Córdoba: https://en.wikipedia.org/wiki/Mosque%E2%80%93Cathedral_of_C%C3%B3rdoba
- Hammam: https://en.wikipedia.org/wiki/Hammam
- Caravanserai and Sultan Han: https://en.wikipedia.org/wiki/Caravanserai, https://en.wikipedia.org/wiki/Sultan_Han
- Vastu shastra: https://en.wikipedia.org/wiki/Vastu_shastra
