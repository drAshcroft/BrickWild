# Critique: layouts, castles, and fantasy interiors

Written against the tree at `7aafa0e` (hotels and shops). Every claim below
names the file and function it was read from, so it can be checked rather
than believed. The short version: the harness is excellent and the plan
representation is the right one, but the *placement* layer knows exactly one
feng shui rule, the castle generator knows exactly one plan shape, and the
castles have no inside at all. Those three gaps are also, in that order, the
cheapest things left to fix.

## 1. Where the layouts stop short of feng shui

`HouseFurnishCheck` has a section headed "feng shui" and it contains one rule:
the bed's commanding position (`_check_command_position`, with `_bed_bonus`
in the furnisher as its other half). Everything else in the house is placed
by "does it fit here" plus a random number. Read the three scoring lines:

| placer | score | what it optimises |
|---|---|---|
| `_place_against_wall` | `mid * 0.6 + randf() * 0.5 + wi * 0.01` (+ `_bed_bonus` for beds only) | the middle of *some* wall |
| `_free_at_scale` | `-dist_to_room_centre + randf() * 0.35 + scale * 4` | the dead centre of the room, at the biggest size |
| `_place_corner` | first corner in `_shuffled([0,1,2,3])` that fits | nothing |
| `_place_mounted` | random wall, random `t` along it | nothing |

That is why the renders look the way they do: a table in the exact middle of
every room, a hearth on whichever wall the dice chose, sconces scattered.
The fixes are all scoring terms in those four functions, and the point of
listing them is that none needs a new representation.

### 1.1 The hearth does not know where the chimney is

`HouseBuilder._build_chimney` puts the stack on the exterior long wall of the
hearth room (`_hearth_room`: kitchen, else hall, else workshop). The hearth
itself is placed by `_place_against_wall` with no term for which wall, so
as often as not the hearth stands against a partition or the front wall
while the chimney rises from a different wall entirely. The
massing check cannot see it because the hearth is furniture and the chimney
is a mass.

Proposal: decide the chimney wall in the planner, record it on the plan
(`plan.hearth = {"room": i, "wall": wi}`), and have *both* the builder and the
furnisher read it — the "one rule" from the church (`ChurchGeometry` owns the
massing, nobody derives their own position) applied to the house. Then add
the check: `hearth: the hearth in room %d stands on wall %d but the chimney
is on wall %d`. This is the single most visible layout defect and it is an
afternoon.

### 1.2 Nothing faces anything

Seats face the table (`_place_around`) and that is where orientation stops.
The rules a person would say out loud, none of which exist yet:

- The **workbench wants the window** (a craftsman works by daylight); the
  **bookcase wants to be away from the hearth and the window** (heat and
  damp); the **bed avoids the window wall** (feng shui: a bed under a window
  has no support behind it — `_window_blocks` only stops *tall* things across
  a window, and a bed is low, so it is currently allowed).
- The **table** in a hall or parlour should sit toward the hearth end, not
  the geometric centre; the hearth is the room's focus and the seating
  should acknowledge it.
- **Sconces** flank the door or the hearth in a symmetric pair; a
  **shelf** goes above the workbench or counter, not on a random wall; the
  **chandelier** hangs over the table, not over the room centre
  (`_place_ceiling` uses the room centre).
- **Corner pieces** (barrels, crates) belong in the corner *furthest from
  the doors*, which is also the feng shui rule about not cluttering the
  mouth of chi. `_place_corner` shuffles.

Proposal: give `PropCatalog.PROPS` an optional affinity block per category —
`{"near": ["hearth"], "far": ["door"], "daylight": 1.0, "over": "workbench",
"flank": "door"}` — and one function, `_affinity(plan, room, cand) -> float`,
called from all four placers in place of the bare `randf()`. Keep a small
jitter (0.1, not 0.5) so seeds still differ. Each affinity that matters
gets a matching line in `HouseFurnishCheck` so it is measured, not hoped
for. This turns the "feng shui" section of the check from one rule into a
dozen, with the same shape as the twelve rules of `TempleRiteCheck`.

### 1.3 The upper storeys are a photocopy of the ground floor

`HousePlanner._clone_upper_storeys` duplicates every ground-floor room *with
its kind*, every door and every window. A two-storey cottage therefore has
two kitchens, two halls, two stores, and its bedrooms on the ground floor
next to the front door. It also has two hearths and one chimney (see 1.1).
The stair is placed at the exact centre of the hall (`_add_stair`:
`centre := floor_rect.get_center()`), which is the one place a stair should
never be — it faces the front door head-on (the classic feng shui fault, and
the classic real-estate one) and it takes the spot the table would have had.

Proposal: the upper floor gets its own programme. Bedrooms go up (this is
what the second storey is *for*), the ground floor keeps hall, kitchen,
parlour, workshop and store. The upper plan can still be the cloned
subdivision (the walls have to line up structurally anyway), but `_name_rooms`
runs on it with a private-first ordering instead of public-first, with the
stair landing as its "front door". The stair goes against a wall of the hall,
out of line with the front door, and `_check_command_position` grows a sibling:
`stair: the foot of the stair lies in the line of the front door`.

### 1.4 The privacy gradient has one pole

`_name_rooms` sorts rooms by distance from the middle of the front wall and
hands out kinds most-public-first. That is the right idea and it has only one
pole. When `spec.back_door` is set, `_place_back_door` looks for a kitchen,
store or hall on the back wall, but nothing pulls the kitchen *to* the back
wall in the first place — the kitchen is the second kind in `PROGRAM`, so it
usually lands beside the front door, and the back door goes to the store.

Proposal: two poles, front (public) and service (back), and each kind carries
a weight toward each. Kitchen and store sort toward the service pole,
parlour and hall toward the front, bedrooms away from both. Then the back
door lands on the kitchen where it belongs.

Also worth a rule: **the front door and back door must not be in line**. The
feng shui phrasing is that chi rushes straight through; the practical one is
that the plan reads as a corridor with rooms off it. `_place_back_door` centres
the door on its room, and if that room shares an x-range with the hall the two
doors line up. Offset it to the far end of the wall.

### 1.5 The hotel plan violates the rule the house plan enforces

`HotelPlanner._connect_level` hard-codes doors `0↔3` and `2↔5` on every level.
On upper levels `UPPER_KINDS` makes those `guest_room ↔ guest_room` and
`suite ↔ guest_room`: the only way into guest room 3 is through guest room 0,
and into room 5 through the suite. `HousePlanCheck` cannot catch it because
its privacy pass refuses to walk through `&"bedroom"` only
(`plan.reachable_rooms(start, &"bedroom")`), and a guest room is not a
bedroom to it.

Two fixes: make the privacy check refuse *every* sleeping kind (`bedroom`,
`guest_room`, `suite` — a `SLEEPING` list in `HouseGeometry` beside
`HABITABLE`), and give the hotel a real plan: a double-loaded corridor
(`gallery` running the length of the building) with rooms off it on both
sides, which is what the word *gallery* in `UPPER_KINDS` was reaching for.
Once the corridor exists, the room count stops being a fixed 6 per level and
follows the facade bay count, which the landmark rules already compute.

### 1.6 Shops are houses with the sign changed

`ShopPlanner.plan` calls `HousePlanner.plan` and renames the hall
(`room["kind"] = spec.front_room()`). Everything the house planner assumes
still holds: the public room is whichever room is nearest the front-wall
centre, doors are `INNER_DOOR_W = 0.85 m`, and there is one leaf of front
door. So:

- A **stable** has no door a horse fits through (a stall door is 1.2–1.5 m)
  and no yard; it is a house with a stall in the hall.
- A **smithy** has its forge in a windowed room with a door off the hall,
  when a forge opens to the street (the customer stands outside) and wants a
  wide door and a hearth on the chimney wall (1.1 again).
- A **tavern** has a table and seats; nothing distinguishes it from the
  dining room of an inn. The counter (`sales_floor` has one; `dining_room`
  does not) is what a tavern is *for*: a bar counter facing the door, barrels
  behind it, tables in front.
- `SHOP_FITTINGS` for **tailor** is a sack, for **carpenter** a rack. Neither
  has a fixture the harness would fail without, so `sarchetype` proves less
  than it looks like it proves.

Proposal: `BUSINESSES` gains `door_w`, `front_open` (a shopfront: a wide
opening or a hatch on the street wall, which the builder already knows how to
cut) and a `focus` fixture that must face the entrance — counter, forge,
bar. Then the archetype rows can demand the focus fixture, and the check
grows `focus: the counter in room %d faces away from the door`.

### 1.7 Rooms are bare

The inn render has three to five pieces per room; `FURNITURE_DENSITY_MAX =
0.42` is never approached. Some of that is the asset pack (no rugs, no
hangings, no hooks, no fireplaces with chimney breasts — the "hearth" is a
cauldron). Two cheap wins that need no new models: a rug emitted as a flat
quad by the builder under the table (it gives the room a centre and the
"free" rule something to sit on), and a chimney breast emitted as a mass
inside the hearth room on the chimney wall, which gives the hearth a home and
makes 1.1 self-evident in the render.

## 2. More castles

### 2.1 What the castle generator actually varies

Reading `CastleGenerator.generate` and `CastleGeometry`: every castle is an
axis-aligned rectangle with the gate at the middle of the −Z wall, a keep on
the back centre, a hall on one side and a chapel mirroring it. The corner
towers are identical; the side towers are identical; the inner ring is the
outer ring scaled. Seven styles change tower shape, roof, batter, colour and
a few probabilities. That is a lot of castles that are all the *same*
castle, and it is why the Neuschwanstein render is a white box with spires
and the Himeji render has its tenshu peering over a wall it should be
standing above. A castle is judged by its plan (`docs/CASTLES.md` says so)
and there is one plan.

### 2.2 Plan kinds the generator should know

Each of these is a `plan_kind` on the spec, chosen by style and tier, with
its own `enceinte_rect`/`tower_centers` in `CastleGeometry`. The massing
rules and the voxel sweep do not care what shape the ring is.

| plan kind | what it is | real examples | what it needs |
|---|---|---|---|
| **polygonal ring** | N-sided enceinte following an imagined hilltop | Caernarfon, Conwy, Carcassonne | wall segments as arbitrary quads; towers at vertices |
| **motte and bailey** | a mound with a shell keep, and a *separate* lower bailey beside it | Windsor, Arundel, Lewes | two rings side by side joined by a wall, a mound as a truncated cone |
| **tower house** | one tall L- or Z-plan tower, no curtain | Scottish tower houses, Irish castles | the house tier grown upward instead of outward |
| **ridge castle** | ranges strung along a spine, towers where the spine bends | Neuschwanstein, Edinburgh, Hohenzollern | a polyline spine; ranges as segments; no enclosed bailey |
| **water castle** | a rectangular ring in a moat, reached by a bridge | Bodiam, Caerphilly, Leeds | a moat as a negative mass + a causeway; the bridge is the barbican link already written |
| **Bergfried + Palas** | a slender fighting tower beside a hall block, on a rock | Rhine castles, Marksburg | a very tall thin keep and a hall that is the main mass |
| **terraced baileys** | rings that step up a hill, each higher than the last | Himeji, Edinburgh, Krak in section | a ground plane per ring; the batter grows into a retaining wall |
| **octagonal** | a regular polygon with towers of the same polygon at every vertex | Castel del Monte | the polygonal ring at N = 8 — and a superb symmetry test |

### 2.3 Landmarks to add

`docs/CASTLES.md` has eleven rows. These fill the gaps in the table above,
and each forces a feature the generator cannot currently make: Tower of
London (concentric with a *square* keep off-centre), Conwy (eight towers, two
wards side by side, not nested), Carcassonne (double wall with a town inside),
Malbork (three wards in a line, brick), Castel del Monte (octagon), Edinburgh
(ridge, terraced), Eilean Donan (island, causeway), Caerphilly (water, two
moats), Dover (concentric with a great square keep), Mont-Saint-Michel (the
monastery on the rock — half castle, half church, a fine test of the shared
mesh kit).

### 2.4 Fantasy castles

These are styles plus plan kinds plus a few new emitters, in the order they
cost:

- **Wizard's tower** — a tower house at `tier = house`, four to six storeys,
  a conical cap, balconies spiralling up. New emitter: a balcony ring.
- **Dark fortress** — a ridge castle in black stone with spiked merlons, no
  chapel, a keep that is a single spire; `battlements` become spikes
  (`MERLON_W` narrows, merlon height triples).
- **Dwarven hold** — a facade set into a cliff, with everything else being
  interior. Needs section 3.
- **Elven hall** — curved walls and no right angles. Needs a curved wall
  emitter in `MeshKit`; `half_cylinder` and `arc_ribbon` are most of the way
  there.
- **Sky citadel / floating keep** — the polygonal ring on a rock that
  tapers to nothing below; the batter emitter, inverted.

### 2.5 Detail within the castles that exist

Shorter items, each visible in the renders:

- Every tower is the same size. Real castles have one big one (Eagle Tower,
  Torre de la Vela, the Round Tower); a `great_tower` slot at one corner,
  1.5–2× the others, would do more for silhouette than any style change.
- The gatehouse has no portcullis slot, drawbridge or moat; the wall walk
  has no stairs down into the bailey; the keep has no forebuilding.
- The hall and chapel are solid blocks. They need windows on the courtyard
  side (`_shell_openings` exists for towers) and, for the chapel, an apse —
  `ChurchGeometry` knows how.
- The bailey is empty apart from keep, hall and chapel. A castle was a
  village: stables, kitchen, smithy, well, granary. These are *houses*, and
  section 3 says how to put them there.

  *Partly done.* `CastleFurnisher` now deals a working yard round the inside
  of the curtain -- a cart, an anvil and its fire, a training dummy, a weapon
  stand, barrels, crates, sacks and rope -- and dresses the hall, chapel and
  keep with props. That is the smithy as a **prop group**, not as a building
  with an inside; the ask above, bailey buildings as `HousePlan`s, still
  stands.

## 3. Fantasy buildings with interiors

### 3.1 The pattern that already works

Shops and the hotel proved the pattern: a spec with a room programme, a
planner that writes a `HousePlan`, recipes in `RECIPES`, an assembler, an
archetype row. The harness — plan check, furnish check, nav check — judges
the result for free. Every family below should go through that door rather
than getting its own representation, because that harness is the most
valuable thing in the repository.

### 3.2 Castles get interiors the same way

Castles are the biggest buildings and the only enclosed family with *no*
inside. The keep, hall and chapel are logged as masses and nothing more.

Proposal: each bailey building becomes a `HousePlan`. The **great hall** is a
single room with a `dais` at one end (a raised rectangle the walk grid treats
as a step), a high table across it, trestle tables along the length (a new
`row` rule, see 3.4), a hearth on the long wall and a screens passage by the
door. The **keep** is three or four stacked one-or-two-room storeys with a
stair against the wall — exactly what `storeys` already does for a house,
with the upper-floor programme from 1.3. The **chapel** is a temple-lite:
a nave, an altar on the axis, and `TempleRiteCheck`'s sightline and axis
rules with the idol replaced by the altar. The **bailey buildings** are
ordinary shops (stable, blacksmith, bakery) placed on the courtyard by a
small layout pass that keeps `BAILEY_CLEAR` between them.

`CastleBuilder` then emits the shell of each from its plan (the house builder
already does this from a `HousePlan`; it needs a stone material rather than
half-timber), and `CastleQA` composes `HouseQA` over every building the way
`HotelQA` composes it over the hotel. A castle would then be judged by its
plan *and* whether a person can walk from the gate to the lord's chamber.

### 3.3 New families, ranked by interior payoff per representation cost

Buildable today, with the current rectangular `HousePlan`:

| family | programme | defining fixture | what it teaches the harness |
|---|---|---|---|
| **Barracks / guardhouse** | dormitory, armoury, mess, office | rows of beds, weapon racks | the `row` rule |
| **Library / archive** | reading room, stacks, scriptorium, office | bookcases in rows with aisles, lecterns by windows | daylight affinity (1.2) |
| **Prison / dungeon** | guardroom, cells, oubliette | cages, chains (both in the catalogue) | cells reused from `TempleGeometry.cell_rects`; a room *meant* to be unreachable without a key |
| **Throne hall / palace** | antechamber, throne room, treasury, royal chamber | a throne on a dais on the axis, banners flanking | the temple's axis rules applied to a house plan |
| **Thieves' den** | a shop front with a hidden back | a secret door | doors with `secret: true` the nav check passes through and the plan check must not count as an entrance |
| **Alchemist's laboratory** | the alchemist trade, grown into a building | benches with alchemy on them, cages, a hearth | nothing new — an archetype row |
| **Bathhouse / hospice / school** | | | recipes only |

Needing a representation upgrade first:

| family | why it cannot be built yet | the upgrade |
|---|---|---|
| **Wizard's tower, round keep, lighthouse** | rooms are `Rect2`; a round floor is not | polygon rooms (3.4) |
| **Monastery, inn with a yard, caravanserai** | a plan cannot have a hole in it | courtyards in `HousePlan` |
| **Crypt, catacomb, cellar, dwarven hold** | storeys start at 0 and go up | negative storeys; the walk grid does not care which way the stair goes |
| **Market hall, cloister walk** | every wall is solid between openings | open-sided walls (a colonnade as a wall kind; the temple emits colonnades already) |
| **Tree house, ship, sky citadel** | the ground is at y = 0 | a per-building ground plane |

### 3.4 The four representation upgrades that unlock most of the list

1. **Polygon rooms.** `HousePlan.rooms[i]["rect"]` becomes a `PackedVector2Array`
   outline with `rect` kept as its bounding box. `WalkGrid` already
   rasterises rectangles of floor; rasterising a polygon is one scanline
   loop. `room_walls` returns one wall per edge instead of four. This alone
   gives round towers, octagonal chapter houses, and the wizard's tower.
2. **A `row` placement rule.** Beds in a barracks, pews in a chapel, stacks
   in a library, trestles in a hall: N copies of a piece along an axis at a
   pitch, with a shared use zone down one side. It is `_place_against_wall`
   in a loop with the aisle as the zone.
3. **A `focus` on the plan.** The temple's axis (gate → altar → idol) is a
   focus with rules about it; a hall's hearth, a throne room's throne, a
   shop's counter, a smithy's forge are the same idea. One `plan.focus =
   {"room", "pos", "facing"}` that placers score toward and the check reads
   turns the temple's best rules into rules every building can use.
4. **Lights that light.** `KNOWN_ISSUES` 0d: props tagged `LIGHT` place no
   `OmniLight3D`. `TempleAssembler` already does it; lift it into the shared
   assembler. Until then every interior render with the roof on is black,
   which hides most of the feng shui work from the person judging it.

   *Done.* `LightKit` does it for the houses, shops and hotel, and
   `ShellAssembler` does it for the churches and castles: a light per flame,
   at the prop's measured `light_offset`, from the one per-category table.

## 4. Suggested order

Feng shui scoring first (1.1, 1.2, and the matching checks): smallest
change, biggest visible difference, and everything after it inherits it.
Then the two plan bugs the harness cannot see today — the cloned upper
storey (1.3) and the hotel through-bedrooms (1.5) — because each is a
missing rule in a check as much as a generator fault, and the repository's
own rule is that the check comes first. Then castle plan kinds (2.2) with
the great tower and the courtyard windows (2.5), which is where the "more
castles" ask is actually answered. Then castle interiors via `HousePlan`
(3.2), which is the bridge between the two halves of this document. Polygon
rooms (3.4) last, since they touch the plan, the walk grid and the builder
at once and want the suites green before they start.
