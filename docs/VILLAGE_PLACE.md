# Places: a village described by its features

`docs/VILLAGE_VERNACULAR.md` builds a village from a **region**: Provence, the
Cyclades, the Norse north, rural Japan. Each is a row somebody wrote by hand.
That is four places, and a fifth costs another row.

`VillagePlace` is the other way in. The caller says what the place **is**:
how hot, how wet, how high, what the land gives to build with, how rich, how
well kept, how crowded, and which few habits its builders have. The region row
is then written for it. A southern French hill village, a Nordic farm on a
mountainside, a British hamlet, a Russian collective, a forest village on the
Congo and a Chinese merchant city are six points in one space. So is
everything between them and beyond them.

```gdscript
# two numbers are a place
var request := BuildingRequest.village(7, 60)
request.vernacular = {"place": {"heat": 0.2, "rain": 0.8}}

# thirty-three describe it exactly; state only what you know
request.vernacular = {"place": {
	"heat": 0.7, "rain": 0.35, "altitude": 0.3, "stone": 0.8,
	"wealth": 0.6, "upkeep": 0.3, "density": 0.8, "hues": ["blue", "green"]}}

# a named point in the space, with anything laid over it
request.vernacular = {"place": {"like": "british_hamlet", "upkeep": 0.1}}

# or the whole request in one call
var village := BrickWild.generate(VillagePlace.request(7, 60, "sahel_town"))
```

`BrickWild.describe_kind(&"village")["vernacular"]["place"]` publishes every
feature with its range and meaning, and every preset.

## The three rules

1. **Every feature has a value.** A feature the caller leaves out is *derived*
   from the ones it gave: forest from rain and height, timber from forest, flat
   roofs from drought, upkeep from wealth. A stated feature always beats a
   derived one. Provence states `flat_roofs: 0` because its climate would
   otherwise earn a few.
2. **The features choose from what the builders can already build.** A house
   type is one of the `HouseSpec` chassis with a look laid over it, exactly as
   in the hand-written regions. Nothing here adds geometry.
3. **The output is an ordinary region row.** It is registered under an id made
   from the stated features. `VillageVernacularCheck` judges a place village
   with the rules it already has, and a blend may name the place beside a
   region.

## The features

Shares run 0 to 1. A `~` marks a feature that is derived when it is not stated.

### The land: where it is

| Feature | 0 | 1 | What it moves |
|---|---|---|---|
| `heat` | arctic | equatorial | chimneys, shutters, verandas, stone and earth colours, the plants and the ground |
| `rain` | desert | rainforest | roof pitch, forest, thatch, plinth height, what paint weathers toward |
| `altitude` | sea level | 3000 m and over | cools the place (felt heat is `heat - 0.45 * altitude`), brings stone and snow, ends the forest |
| `relief` ~ | plain | cliffside | stone to hand, storeys, and the slope of `VillagePlace.terrain()` |
| `forest` ~ | bare | deep forest | timber |
| `water` | | | `""` leaves the request's own; else `none`, `pond`, `stream`, `river`, `coast`, `lake` |

### The materials: what the land gives

`timber` ~, `stone` ~, `earth` ~, `reed` ~ (straw, reed, grass or palm leaf for
thatch) and `lime` ~. Each is how much of it is to hand. They decide what the
walls are made of and what the roofs wear. State one to describe a place its
climate would not predict: a treeless island with a quarry, a clay plain.

### The people: who builds, and with what

| Feature | 0 | 1 | What it moves |
|---|---|---|---|
| `wealth` | destitute | opulent | coverings (thatch to tile and slate), stone walls, storeys, the share of rich households, house size |
| `upkeep` ~ | rotting | immaculate | weathering, lean, shutters, clutter, moss and rot on the roofs, dead trees and fungus |
| `inequality` | a collective of equals | a lord and his cottars | the shares of rich and poor households |
| `density` | scattered farms | a packed town | town houses, storeys, jetties, the layout culture; a packed town does not thatch |
| `order` | grown | laid out to one pattern | how many materials and house types the place keeps |
| `colour` ~ | bare material | painted everywhere | paint on doors, shutters and boards; tinted render |
| `ornament` ~ | plain | ornate | bargeboards, dormers, the great house, the village's decoration |
| `defence` | open | walled | the enclosure; unstated leaves the request's own |
| `purpose` | | | `""` leaves the request's own; else a `VillageSpec` purpose |

### The habits: what its builders do

| Feature | Says |
|---|---|
| `flat_roofs` ~ | the share of level roofs |
| `whitewash` ~ | the share of walls limewashed white |
| `eaves` ~ | how far the roof overhangs |
| `openness` ~ | verandas, loggias and porches |
| `raised` ~ | houses with the floor raised clear of the ground |
| `round` ~ | round houses under a cone of thatch |
| `long` ~ | longhouses |
| `swept_roof` | the hip-and-gable roof under grey tile |
| `height` ~ | how many storeys the houses run to |
| `hues` ~ | the paints on doors, shutters and boarded walls (16 named paints) |
| `washes` ~ | the tints in the lime on a rendered wall |
| `sacred` ~ | the landmark: `basilica`, `spire`, `dome` or `stave` |
| `tongue` ~ | the sound of the place names (14 tongues) |

Habits are where culture lives. A climate does not decide that a people builds
round, or sweeps its eaves, or paints its doors blue. The land suggests a
default for each. The caller states the ones that make the place itself.

## Wealth and decay are two features

`wealth` is what a household could spend. `upkeep` is whether anybody still
does. Left unstated, upkeep follows wealth (0.6 at the bottom, 1.0 at the top).
Stated, the two are independent, and all four corners are places:

| | kept | let go |
|---|---|---|
| **rich** | `jewel_harbour`: bright wash, tile, flowers | a rich ruin: tile and slate under lichen, tall houses leaning |
| **poor** | a poor proud village: thatch, clean limewash | `rotting_frontier`: grey boards, rotten thatch, nettles |

What low upkeep does:

- **Paint weathers** toward the place's own grime, up to 0.68 of the way on the
  poorest houses. Grime is moss green in a wet country and dust in a dry one
  (`wealth.grime`), where the hand-written regions keep the soot grey.
- **Houses lean.** `wealth.jank` puts up to 0.35 (about four degrees) of
  `BuildingRequest.jank` on a poor house. It reaches the village through
  `BrickWild.instantiate`. Under upkeep 0.7 nothing leans.
- **Shutters fall off**, bargeboards go, clutter gathers.
- **Roofs rot.** Rotten thatch, mossy shingle and lichen tile take over each
  covering's colours.
- **The village** takes the upkeep too: `VillageSpec.upkeep` (weathered paint,
  dead trees, wild patches) and, with ornament, `decoration_level`.

Letting a place go does not change which houses it has. `vplace` holds that:
the same place at upkeep 1 and 0 has the same house types.

## How a row is made

`VillagePlace.synthesise(stated)`, in order:

1. **Derive** every unstated feature (`derive()`): climate, then what grows,
   then what there is to build with, then what people do with it.
2. **Coverings.** Seven candidates (thatch, turf, shingle, slate, tile, swept
   tile, flat earth or lime), each weighted by what the land gives and what the
   people can pay. The weights are sharpened, because a country settles on its
   coverings, and anything under 0.06 is dropped. The pitch follows rain and
   snow.
3. **Walls.** Timber, stone and earth share the ordinary house by availability.
   Stone costs labour and earth costs none, so wealth moves walls from earth to
   stone. Each material brings its own colours for the climate: grey stone in
   the wet and honey limestone in the warm; adobe, red laterite or pale cob;
   tarred, silvered or sun-bleached timber. Lime and colour go over them as the
   place has them. Timber is log or board where it is plentiful (0.55 and
   over) and a plastered frame where it is not.
4. **House types.** Round, long and raised houses take the shares their habits
   state. The rest live under flat roofs (the rendered cube, the terraced earth
   house, the Sahel courtyard house) or pitched ones (cottage, cob cottage,
   farmhouse, town house), one set per wall material. The well-off get a great
   house: close-studded timber in the cool, a square hipped house in the warm.
5. **Who lives where.** Each type is roofed from the coverings within reach of
   the tiers that live in it. The commonest covering of the place is on every
   house but the great one: a poor Provençal roof is still tile.
6. **The look.** Chimney, shutters, porch, veranda, dormers, bargeboards,
   plinth and clutter follow the climate, the purse and the upkeep.
7. **The rest.** The landmark is the `sacred` form in the place's commonest
   wall and dearest covering. Plants and ground follow the climate. Names come
   from the tongue. `culture` is the measured layout row
   (`VillageRealLayout`) whose crowding and climate are nearest.
8. **The signature** holds only what follows from the row with certainty: a
   covering with no recipe is never worn, a place with no flat recipe has no
   flat roof, a place with no three-storey type has none. The shares a feature
   moves are measured by `vplace`, not promised by the row.

`tools/probe_village_place.gd` prints the row a place makes and what 400 drawn
households come to. Reach for it before changing a formula.

## What the place says of the village

`VillagePlace.apply(spec)` runs in the village family's `generate`, before the
spec is validated. A caller that builds from a `VillageSpec` calls it itself.

| The place states | The spec gets |
|---|---|
| `wealth` | `spec.wealth`. A place with no wealth takes the request's, so the Studio's wealth slider still moves a place village |
| `upkeep` (or derives it) | `spec.upkeep`, never raised over one the caller lowered |
| `ornament` and `upkeep` | `spec.decoration_level`, when the caller left it at 0.5 |
| `water`, `purpose` | `spec.water`, `spec.purpose` |
| `defence` | `spec.enclosure`: none, hedge, palisade, wall. A wall becomes a palisade under 150 people (the CIVIC people, counting any the caller implies), unless the village is a garrison, which mans its wall at any size |

A `like` preset's features count as stated. `{"like": "rhine_town"}` therefore
brings `wealth: 0.85` and `purpose: "market"` with it, and they beat the
request's. A place that names another purpose over a small walled garrison
leaves it a palisade, not a spec that refuses itself.

The layout culture reaches the village the way a region's does: only when the
request left its culture at the default.

### From another process: the site exporter

`tools/export_village_plan.gd` takes a place too (VXG-PLACE-EXPORT, 0.1.8):

```
godot --headless --path <project> --script res://tools/export_village_plan.gd -- \
  --request C:/abs/site-city-0002.json --population 60 --implied-population 10614806 \
  --vernacular C:/abs/place.json --out C:/abs/plan.json
```

`--vernacular` is a file, or the JSON itself when it starts with `{`; the
content is a `VillageSpec.vernacular`. Pass ABSOLUTE paths: Godot's `--path`
changes the working directory, so a relative one is read from (and `--out`
written into) the project. A value that cannot be read or does not parse is
refused with exit 2 and the parse errors.

The exporter lays the place over the spec its SiteRequest made, in the
village family's order, with two rules of its own. Each move is a line in the
plan's `notes`.

| Rule | What happens |
|---|---|
| The city's facts beat a preset's | The request's wealth, purpose, water and walls stand over a `like` preset's. The caller's OWN stated feature beats the request's. A place with no wealth of its own takes the city's, so `{"like": "rhine_town"}` on a city of wealth 1.0 is built at 1.0, and the place as applied says so |
| A named culture stands | One of BrickWild's cultures, or one `CULTURE_MAP` folds onto one (`fjord` is `norse`, `river-song` is `english`), is kept, english included (`VillageSpec.culture_named`) |
| An unknown culture gives way | A culture BrickWild does not know (`culture:river-crown-compact`) is no longer a hash pick: the culture is left at the default, so the place's layout culture builds the lots and the castle |

With the flag the plan also carries `vernacular` (as applied, with the wealth
folded in), `culture` rewritten to the culture the buildings were BUILT in
(`effective_culture()`), a `look` (and any `jank`) on every house and shop
`request`, and `vernacular_check` {ok, failures, warnings}:
`VillageVernacularCheck` on the planned buildings, so a consumer can see the
plan reads as its place without running Godot. Without the flag the plan is
byte-identical to 0.1.7's, flat and on ground.

## The presets

Eighteen named points. Each states only what sets it apart.

| id | Reads as |
|---|---|
| `provence_hill` | ochre and sand render, canal tile, painted shutters, tall houses on a hill |
| `greek_island` | limewashed cubes, flat roofs, blue doors, a dome |
| `nordic_mountain` | tarred and red timber under turf and shingle on a fjord side |
| `british_hamlet` | cob and stone cottages under thatch, a grey spire |
| `rhine_town` | tall jettied frames, tile and slate, carved and painted |
| `alpine_valley` | broad timber houses on stone, shingle and slate, deep eaves |
| `russian_collective` | identical log houses in rows, a little let go |
| `highland_croft` | low rubble houses under old thatch, half falling in |
| `congo_forest` | round and oblong mud houses under palm thatch on red earth |
| `savanna_kraal` | round thatched houses behind a fence |
| `sahel_town` | banco courtyard houses with terrace roofs |
| `desert_oasis` | a walled knot of earth houses |
| `andean_highland` | stone and adobe under thatch in thin air |
| `japanese_farm` | raised timber farmhouses under thatch and grey tile |
| `asian_city` | two-storey shop-houses under grey tile, shoulder to shoulder |
| `monsoon_delta` | raised timber houses under steep palm thatch |
| `rotting_frontier` | sagging board houses, moss on every roof |
| `jewel_harbour` | tall bright-washed houses on a quay, every shutter painted |

A preset is not a second dataset. To make a new place, state features. To make
a place between two, `VillagePlace.mix(a, b, t)`.

## The ground

A request carries no ground. `VillagePlace.terrain(place, rect, cell_m)` makes
one for a caller that owns the spec: a slope as steep as the relief, with the
sea or lake at its foot when the place has one.

```gdscript
var spec := VillageSpec.new(7)
spec.vernacular = {"place": {"like": "nordic_mountain"}}
spec.terrain = VillagePlace.terrain(spec.vernacular["place"])
VillagePlace.apply(spec)
spec.generate(7)
```

The form (hillside, shore, crest) is then the ground's to derive, as on any
terrain (`docs/VILLAGE_TERRAIN.md`).

## Lanes

```
godot --headless --path . --script res://tests/run_all.gd -- lane:place
#   vplace       the feature set, 300 random places, derivations, one-feature
#                sweeps, decay, the presets told apart, settings, four places as
#                programmes, three failing controls
#   vplacebuild  every distinct build the presets' types come to, and each
#                kind of shop, through BrickWild.check
godot --headless --path . --script res://tools/probe_village_place.gd -- brief
godot --headless --path . --script res://tools/probe_place_village.gd -- british_hamlet
```

Measured 15 Nov on a loaded host: `vplace` 654 checks in 130 s, `vplacebuild`
63 checks in 123 s (45 distinct builds; 38 more types are a build already
made in another colour).

What `vplace` found, with one feature moved and the rest held:

| Moved | From | To |
|---|---|---|
| `rain` 0.15 to 0.9 | mean roof pitch 0.51 | 0.99 |
| `wealth` 0.1 to 0.9 | thatch on 71 % of roofs, 1.40 storeys | 22 %, 1.72 storeys |
| `density` 0.1 to 0.95 | no town houses | 67 % town houses |
| `upkeep` 1 to 0 | no house leans, shutters 0.45 | every house leans, shutters 0.14 |

Three hundred random places (a random subset of the features, the ends
over-sampled) all make a row the builders take, and between them call for all
eleven village chassis. The fuzz earned its place on its first run: a place
stating every house round AND every roof flat came out with no houses at all.
Contradictory features now fall back to the plainest house the coverings
allow.

The six places asked for by name are told apart by drawn shares of house
style, covering and wall finish (total variation, 0 to 3). The nearest two are
the Nordic mountainside and the Russian collective, 1.30 apart: both are cold
timber country. The controls fail as they must: a Nordic village judged as a
Sahel town (16 complaints), the merchant city judged as the rotting frontier
(17), and the rotting frontier judged as the same place well kept (5: its
paint has gone further than a kept place's may).

Three whole villages were also generated through the public path
(`tools/probe_place_village.gd`, 40 people, seed 7): Nordic mountainside 82 s,
Sahel town 67 s, rotting frontier 84 s. Each passed `VillageVernacularCheck`.
`BrickWild.check` (the full village QA) was not run on them.

Changing a formula in `derive()` or `synthesise()`: run the probe, read the
rows, then `vplace`. Changing `VillageVernacular` itself: `lane:vernacular` too.

## Known gaps

* **The culture row couples layout to castle.** A packed East Asian city is
  laid out on the `frankish` row (the densest measured), so a castle there
  would be a French one. `east_asian` is taken only under density 0.6.
* **Twelve chassis.** A stilt house is the `asian` chassis, so a monsoon
  village has hip-and-gable roofs whatever `swept_roof` says. There is no
  courtyard farm, no log-cabin corner notching, no stone-slab roof geometry:
  slate stands in.
* **Four landmark forms.** A mosque, a pagoda and a wooden Orthodox church are
  the dome, the stave church and the dome again.
* **Few plants.** The catalogue has no palm, olive, cypress or bamboo. A jungle
  is common trees, ferns and tall grass. Edge planting keeps the culture's
  density, so a desert village has as many trees as an English one.
* **Roof material is five names.** Corrugated iron, the roof of most poor
  places since 1900, is not one of them.
* **Order is weak.** It makes the houses uniform. It does not lay them in
  rows; the form is still chosen from population and purpose.
* **Ground through the public request.** `terrain()` is for spec owners.
* **The exporter's plan does not carry the place's colours.** A place says
  the colours of its ground, roads and commons, its plants and its
  landmark's masonry; a SitePlan carries none of them (VXG-PLACE-PALETTE,
  open). Its `plant_palette` still names the brief's palette, while the trees
  in its `props` come from the place's. Nor does a SiteRequest carry a
  vernacular of its own yet: only `--vernacular` does.
* **A preset is a whole point.** `like` brings every feature the preset
  states, wealth and purpose included. Through `BuildingRequest` they beat the
  request's; only the exporter makes the city's facts win. State the feature
  to override it.
* **Not yet looked at.** No place village has been rendered and judged by eye
  or by the vision model. `render_vernacular_villages.gd -- places=...` makes
  the pictures. The rows read right as tables; a table is not a village.
* **Lean and the village QA.** A leaning house passes the vernacular check.
  Whether a village of leaning houses passes the walk and lot checks has not
  been measured.
