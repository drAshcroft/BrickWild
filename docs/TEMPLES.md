# Evil temples

The fourth generator, and the only one whose harness asks whether a *ritual*
would work. A church is judged by its silhouette, a castle by its plan and a
house by whether you can live in it. A temple is judged by the walk from the
door to the god.

## Form and cult

Two independent choices. FORM is the architecture — a plan a real temple was
built to. CULT is what is done in it, which decides the idol, the fittings and
the colour of the stone. Keeping them apart is the point: a basilica of the
Ossuary and a ziggurat of the Ossuary are the same religion in different
buildings.

| Form | Taken from | What it gives you |
|---|---|---|
| **Basilica** | the cathedral plan, corrupted | nave, colonnade, aisles with cells, apse, a spire over the sanctum |
| **Pylon** | Egypt | battered pylon towers, obelisks, an open court, a hypostyle forest, a small dark room at the end |
| **Ziggurat** | Ur | a stepped mountain, twin stairs up the front, the god on the summit, the rite in a chamber inside the base |
| **Rotunda** | a tholos over a chasm | a ring of columns round a hole, the way across it on the axis |

| Cult | Idol | Signature |
|---|---|---|
| The Crimson Choir | a figure | stained stone, cells full, chains everywhere |
| The Starless Deep | a monolith | cold stone, few flames, almost no cells |
| The Ashen Crown | a pyre | braziers by the dozen |
| The Ossuary | a cairn of skulls | bone-pale trim |
| The Coiled Fang | a serpent, wound round its own plinth | green stone |

## The axis

Everything is a statement about the line from the gate to the god:

```
gate ──▶ processional way ──▶ pit + bridge ──▶ dais ──▶ altar ──▶ IDOL
```

`TempleGeometry` places all of it and `qa/temple_rite_check.gd` refuses to
believe any of it. That file is the reason this generator exists.

| Rule | What it means |
|---|---|
| **axis** | altar and idol on the centre line, in that order, with the altar between the congregation and the god, and a person's width between the two |
| **sightline** | you can SEE the idol from the doorway — a ray from eye height to the god's upper half, tested against every structural mass. Not a column, not a wall, not the roof |
| **procession** | you can WALK that line: flood fill from the doorstep, arrive at the altar, and never narrower than 2.4 m the whole way |
| **approach** | the celebrant can get round the altar from at least three sides, one of which is the front |
| **congregation** | at least a fifth of the hall is floor somebody can stand on |
| **dominance** | the idol looms: twice the height of the altar top, and nothing else in the sanctum stands taller |
| **symmetry** | every mass has its twin across the axis, or straddles it evenly |
| **fire** | no point on the processional way is more than 7 m from a flame — these buildings have no windows worth the name |
| **the pit** | if there is a hole it is ON the axis so the procession must cross it, and there is a bridge to cross it by |
| **the cells** | what is kept for the rite can be reached, and is not kept where the congregation would trip over it |

`ascii_map()` prints what the walker saw with the **G**ate, the **A**ltar and
the **I**dol marked.

## What the harness caught

Every one of these was a real defect, found by a rule rather than by looking:

- **The god through the back wall.** Sizing the sanctum by proportion left
  nowhere for the idol to stand once the altar had its clearance, and the
  geometry obliged by pushing it through the masonry. The sanctum is now sized
  to what has to stand in it.
- **A black slab in the doorway.** The gate was filled with a dark panel so it
  would read as an opening from outside. It is not a structural mass, so the
  sightline rule happily reported the god as visible through it — a check
  describing a temple nobody could see into. The gate is a hole now.
- **A colonnade closing across the axis.** A ring of columns closes over the
  centre line unless somebody says not to, and then the god is behind a pillar.
- **Columns standing on nothing**, over the pit and in the mouths of the cells.
- **One missing column in forty.** Every placement rule is symmetrical, but
  they are applied to rectangles, and a column clearing a cell by a millimetre
  on one side did not on the other. The symmetry rule noticed immediately.
- **A pit wider than the light could cross**, leaving the middle of its own
  bridge nine metres from the nearest flame.
- **A stair that buried its own doorway.** One flight on the axis is the
  obvious arrangement and it is wrong twice over — it covers the way in and it
  stands between the ground and the god. Twin flights flanking the door is how
  Ur was built, and for the same reasons.

## The archetypes

`tests/suites/temple_archetype_suite.gd`, built at 70%, 100%, 135% and 180%:

| Archetype | Must contain |
|---|---|
| Bloodpit Basilica | a pit, cells, a colonnade |
| Temple of the Starless Deep | obelisks, a hypostyle hall |
| Ziggurat of the Ashen Crown | terraces, twin stairs |
| Rotunda of the Coiled Fang | a pit, a bridge, a ring of columns |
| The Ossuary | a colonnade, and a spire or cells |
| Drowned Rotunda | a pit and a bridge — small, round, and mostly hole |
| Hungering Pylon | a colonnade |

An archetype says what a temple must CONTAIN, never where anything goes.

## Fire

`TempleAssembler` gives every brazier, candle and torch an `OmniLight3D` in the
cult's colour. That is not decoration: the rite check spends a whole rule on
whether the way to the altar is lit, and a temple that passed that rule in the
report while being pitch black in the render would be a harness lying to
itself.

## Sources

- Egyptian pylon temple plan (Karnak): pylon, court, hypostyle hall, sanctum.
  https://en.wikipedia.org/wiki/Egyptian_temple
- Ziggurat of Ur, and its three stairways.
  https://en.wikipedia.org/wiki/Ziggurat_of_Ur
- Processional axis and the staging of approach in temple architecture.
  https://en.wikipedia.org/wiki/Axis_(architecture)
