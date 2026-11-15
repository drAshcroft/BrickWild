# Vernacular villages: regions, their normal, and blending them

A village can be built FROM A REGION: Provence, the Cyclades, the Norse
north, rural Japan. The result should read as that region at a glance, with the
variation a real village has in colour, house type and wealth. For a fantasy
game, regions can be BLENDED, either feature by feature or as two peoples living
side by side.

Two halves:

* **The dataset** (`src/village/vernacular_regions.json`) says what is NORMAL
  for each region. It holds distributions, not single values: colour clusters
  with weights, roof recipes, the house types each wealth tier lives in, and
  storeys, sizes, landmark, plants, ground and place names. Each region also
  carries a short **signature**: the few checkable traits that make it read as
  itself.
* **The feature set** (`VillageVernacular`) is a blend of regions. Each feature
  group can have its own weights. Every household draws its genome from the
  blend with a seeded stream of its own.

`VillageVernacularCheck` judges a generated village against the dataset. The
dataset is therefore both the generator's input and the check's oracle.

```gdscript
var request := BuildingRequest.village(7, 60, &"english", &"market", 0.5)
request.vernacular = {"provence": 1.0}
var village := BrickWild.generate(request)

# a hybrid people: Norse houses and walls, Japanese roofs, half and half trim
request.vernacular = {
	"blend": {"norse": 1.0},
	"groups": {"roofs": {"japanese": 1.0}, "trim": {"norse": 0.5, "japanese": 0.5}},
}

# two peoples side by side: each house is wholly one or the other
request.vernacular = {"blend": {"provence": 0.6, "norse": 0.4}, "coherence": 1.0}
```

An empty `vernacular` (the default) is the culture alone, and moves nothing. No
look reaches any house, and every pre-existing village is byte for byte the
same (see "Moves nothing" below). `BrickWild.describe_kind(&"village")
["vernacular"]` publishes the regions, the groups and each region's signature in
words.

## The regions

| id (aliases) | Reads as | Signature (`VillageVernacularCheck`) |
|---|---|---|
| `provence` (`provencal`, `south_of_france`) | Luberon hill villages: ochre, sand, rose and cream render, canal-tile roofs, painted shutters, tall village houses, long low mas | warm walls >= 0.9; tile >= 0.9; never flat; shutters >= 0.8; 2-3 storeys >= 0.4; >= 3 wall and >= 4 shutter colours; Romanesque church |
| `cyclades` (`greek`, `greece`, `aegean`) | Aegean island villages: lime-white cubes, flat roofs behind a parapet, blue, green or oxblood openings, a few neoclassical captains' houses under tile | lime-white walls >= 0.55; flat >= 0.6; blue openings >= 0.3; never 3 storeys; no thatch, slate or shingle; >= 3 opening colours; domed Byzantine chapel |
| `norse` (`viking`, `scandinavian`, `nordic`) | Fjord and valley farms: tarred stave longhouses, log houses in falu red or ochre with white trim, turf, straw or tarred-shingle roofs | timber or painted-timber walls >= 0.9; turf >= 0.3; no tile; never flat; one storey >= 0.55; longhouses >= 0.15; >= 3 wall finishes; stave church |
| `japanese` (`japan`, `nihon`) | Edo farming villages and post towns: dark timber over lime or earth plaster, raised floors with an engawa, irimoya roofs of grey kawara tile or straw thatch | irimoya >= 0.9; tile >= 0.3; thatch >= 0.08; plaster or dark-timber walls >= 0.9; dark frames >= 0.85; the minka is every house; one storey >= 0.6 |

Each region names its real places and its sources in the file. The share
thresholds sit well under the shares the sampler draws. A 12-dwelling village
is a small sample, and a real village of the region should never fail its own
signature. `scratch/vernacular_mc.gd` measured the drawn shares
(4000 genomes a region) when the thresholds were set.

## The dataset, field by field

```
regions.<id>
  label, summary, culture        culture: the VillageSpec culture everything the
                                 dataset does not say is built in (castle, the
                                 real-layout sizes and spacing, the form tables)
  aliases, places, sources       words; places and sources are the evidence
  signature[]                    {id, say, measure, ...}: measure is one of walls,
                                 trim, roof_colour (clusters by name), roof_form,
                                 roof_material, storeys, styles, shutters,
                                 parapet (shares, min/max), distinct (group, min),
                                 landmark (church)
  wealth                         {rich, poor}: household shares at wealth 0.5;
                                 weathering {tier: 0..1}: how far paint has gone
                                 toward GRIME
  size.area_scale                on the culture's real median footprint
  walls[], trim[]                colour clusters {name, w, hex: [a, b]}
  roofs.<recipe>                 {w, types {form: w}, pitch [min, max], material,
                                 eave [span_out, along_out]?, colours[]}
  houses.<type>                  {label, style, tiers {poor|middle|rich: w},
                                 purposes {purpose: x}?, trades {trade: x}?,
                                 storeys {"1": w, ...}, area, roofs [recipe ids],
                                 roof_types {form: w}?, walls[]?, trim[]?,
                                 look {...}}
  shop                           the house type shops are built as
  landmark                       {church: ChurchSpec style, look {wall, trim,
                                 roof}, fallback?, wants?}
  plants                         {edge|green|hedge|ground|wild: catalogue keys}
  ground                         {ground|road|common|verge|yard|field|wear|tread: hex}
  names                          {roots, endings, patterns}
```

A **house type** is a chassis, one of the existing `HouseSpec.STYLES`, plus a
**look**: a patch over that style's own row (`HouseSpec.LOOK_KEYS`). The
Provençal mas is the `farmhouse` with no timber frame, no jetty, no dormers,
tile on a low pitch and shutters on every window. The Cycladic cube is the
`mediterranean` house with a flat roof behind a parapet and no loggia. The Norse
longhouse is the `longhall` with close studding and no braces or rail, which
reads as a stave wall.

### What a look may ask of a style

A look may only CHANGE a value the style's row already has. It cannot add a key,
so the generator takes exactly the draws it always took, in the same order. A
patch moves what a draw lands on, never which draws there are.
`HouseSpec.look_errors(style, look)` says what is wrong with a look, and
`BuildingLibrary.validate` refuses it with `invalid_look`.

| Kind | May change |
|---|---|
| house, shop | colours (`wall`, `trim`, `roof`, `floor`); `roof_pitch`, `studs`, `plinth`, `clutter` ranges; `porch`, `chimney`, `shutters`, `timber`, `braces`, `rail`, `jetty`, `dormers`, `bargeboards`, `stone_ground`, `parapet`, `veranda` chances; `roof_types`, `framing`, `truss` lists; `roof_material`, `chimney_style`; `span_out`, `along_out` |
| church, castle | colours only: `wall` (the masonry), `trim`, `roof` |

The roof forms a style has been measured to build (`HouseSpec.LOOK_ROOFS`):
`cottage`, `farmhouse`, `townhouse`, `longhall` and `rich` build gable,
half-hipped and hipped roofs. `mediterranean` builds gable, hipped and flat.
Every other style keeps its own row's forms: the minka's irimoya, the
roundhouse's cone, the Pueblo and Sahel flat roofs. A flat roof is always given
its parapet (a slab with nothing round it reads as a lid; HS-SAHEL-RESIDUE).

A shop's roof form follows its look's `roof_types` with no draw. Before this, a
shop's roof was always its spec's gable. A shop without a look is unchanged.

## How a household is drawn

1. **Tier.** The households' real footprints are ranked (`VillageProgrammer.
   house_areas`). The biggest `rich` share are rich and the smallest `poor`
   share are poor (`tiers_by_area`). Village wealth multiplies the rich share,
   and divides the poor share, by up to 3 at the ends.
2. **Parents.** For each house group (`houses`, `walls`, `trim`, `roofs`) one
   region is drawn by that group's weights. With chance `coherence`, all four
   come instead from one region drawn by the blend.
3. **Type.** From the houses region, weighted by tier (falling back to the next
   tier), village purpose and household trade.
4. **Colours.** Walls and trim come from the type's own clusters when the group
   came from the type's region, otherwise from the group region's clusters.
   Each is a point along its cluster, weathered toward GRIME by the tier's
   share. Roofs weather at half that rate.
5. **Roof.** The type's own recipes when it is the type's region. Otherwise:
   every recipe of the roof region whose form the chassis can build; failing
   that, any recipe, keeping only its material and colour (Cycladic houses under
   Japanese roofing get grey tile and thatch on their own hipped and gable
   forms).
6. **Request.** The chassis style, the type's storeys (one storey under
   `STAIR_MIN_AREA`, as before), the real footprint times the type's `area`,
   and the look. A real site's character (`VillageTerrain.character`:
   `house_style`, `storeys_min`) does NOT reach a vernacular village's houses,
   because the vernacular names the buildings. On Manarola's ground a Cycladic
   village keeps one and two storeys rather than the Cinque Terre's three. The
   ground's form and layout traits (`fire_m`, `setback_m`) still apply. This was
   found by the walk bake of 15 Nov; `vvernacular` holds it, with the plain
   village on the same ground as its control.

Shops are the region's `shop` type, painted and roofed like a middling house,
with that type's storeys. A Provençal shop stands under three storeys. The church
is the landmark region's style and colours. Plants are the union of every region
with at least 0.2 of the plants group. Ground colours are averaged by weight,
since ground is a field of colour and not a set of things to tell apart. The
village's name comes from the names group's dominant region.

## Adding a region

A fantasy people (elves, dwarves, a drowned kingdom) is a region row:

```gdscript
var row := VillageVernacular.region(&"norse").duplicate(true)
row["label"] = "Elven glade"
row["walls"] = [{"name": "moon white", "w": 1.0, "hex": ["e8ecf2", "d8dee8"]}]
var errors := VillageVernacular.register(&"elven", row)   # [] when taken
request.vernacular = {"elven": 0.7, "japanese": 0.3}
```

`register` validates the row exactly as the shipped ones are validated
(`region_errors`): every type's style and look, every roof recipe's forms
against the chassis, colours, tiers, landmark, plants, ground and signature
measures. For a permanent region, add it to the JSON and run `lane:vernacular`.
`vvernacularbuild` builds every type and the shop of every region through
`BrickWild.check`, so a type the generator cannot build is found before any
village draws it.

## The check

`VillageVernacularCheck` measures what the generator MADE. Each dwelling's spec
is generated from its request through the family's placement path. The check
never reads the genome the programme drew. A look the house generator ignored,
a cluster drawn at the wrong weight or a roof the chassis swapped is therefore
found. Colours are sorted into clusters by CIE Lab distance (tolerance 6) to
the nearest point of the cluster, allowing as much weathering as the region
allows.

| Rule | Holds |
|---|---|
| `membership` | every dwelling's walls, trim and roof colour lie in a cluster of a region its group draws from; its roof material is one of those regions' recipes |
| `signature` | a PURE region's village keeps its signature |
| `presence` | in a blend, every region with >= 0.25 of a group shows up in that group |
| `variety` | 10 dwellings or more are not one paint scheme |

The controls (`vvernacular`) fail as they must:

- a plain `mediterranean` village judged as Cycladic (11 complaints: green trim
  off the palette, no flat roofs, a Romanesque church);
- a Norse village judged as Cycladic;
- a Cycladic programme with every look stripped before generation, which proves
  the check reads the house and not the request.

## Lanes

```
godot --headless --path . --script res://tests/run_all.gd -- lane:vernacular
#   vvernacular       63 checks, ~3.5 min: dataset, transport, refusals, moves
#                     nothing, four regions vs their signatures, blends,
#                     coherence, wealth, controls, plants, ground, names
#   vvernacularbuild  38 checks, ~2 min: every type and shop built and checked
godot --path . --script res://tools/render_vernacular_villages.gd   # not headless
#   -> artifacts/renders/vernacular/: overview, near and street views of each
#      region and two blends, with manifest.json (request + check report)
```

## Moves nothing

With no look and no vernacular:

- `HouseSpec.style_row()` returns the style row itself;
- `ShopGenerator`'s look branch is not entered;
- `VillageProgrammer.roof_top_bound` sets no parapet;
- the plant palette and ground colours fall through to the old tables;
- the request document is unchanged.

`vvernacular` checks the first and last directly. A colour-only look is shown
to move no other draw (pitch, roof form, porch, chimney, frame, rooms and name
all equal). `tools/fingerprint_houses.gd` against a clean worktree at ee00a7a
(15 Nov) is IDENTICAL: 120 house plans across the five long-standing styles,
plan text and every shell vertex. The pre-existing suites `cultureapi` and
`compactapi` pass.

## How it reads

`tools/render_vernacular_villages.gd` (40 people, seed 7) was judged twice. I
looked at every image. Then a local vision model (`waterfree vision`,
qwen2.5vl 7B) was shown each image blind and asked to choose one of South of
France, Greek island, Scandinavia, Japan, England, Germany, Spain or Mexico.
The model's answers are advisory: one model, one seed, three views each.

| Region | Overview | Near | Street |
|---|---|---|---|
| Cyclades | Greek island | Greek island | Greek island |
| Japanese | Japan | Japan (it took the stave tower for a pagoda) | England (the smithy's stone chimney under thatch) |
| Norse | England ("thatched roofs") | Scandinavia | Scandinavia ("red house, yellow house with a green roof") |
| Provence | South of France | Spain | Greek island ("blue shutters") |

The first Norse pass read English (two of three): straw thatch and the
cottage's stepped stone chimneys. Thatch went from 0.2 to 0.08 of roofs, every
Norse chimney became a plain straight stack and rarer, and porches rarer; two of
three then read Scandinavian. Provence reads as the Mediterranean but not yet
as Provence in particular -- see the gaps.

## Known gaps

* **The Japanese landmark is a stand-in.** BrickWild has no Japanese sacred
  building at village scale: the pagoda family starts at 40 m, and the
  `timber_hall` phoenix pavilion is a `world` kind that the village's landmark
  rules do not know. The dark nordic stave church under a grey roof stands in
  (`landmark.fallback`, with `wants` saying what it should be).
* **No olive, cypress or umbrella pine.** The catalogue's Mediterranean
  candidates are the green `Wild_CommonTree`. `Wild_TwistedTree` is
  red-leaved and reads as autumn, so it is not used. Its red is also why the
  existing `moorish`/`eastern` palettes look autumnal.
* **The edge is planted at the culture's density.** A Cycladic island village
  should have far fewer trees than its edge band plants.
* **Layout is the culture's.** Density, touching and gaps come from the base
  culture's real-layout row (`mediterranean` 57 % touching), not from the
  region. A Cycladic village is laid out more loosely than Oia.
* **Provence's finer marks.** Génoise eaves (courses of tile under the eave),
  a wrought-iron bell cage, cypress and lavender rows separate Provence from
  Spain or the Greek mainland. They are geometry and assets a look cannot
  ask for.
* **A forced flue.** A smithy or bakery always has its chimney (ShopGenerator);
  under a minka's thatch it reads as an English stack.
* **Bank colour.** `VillageBuilder.bank_colour` still crests at the default
  ground colour, so a river bank seams against a regional ground.
