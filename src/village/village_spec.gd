class_name VillageSpec
extends RefCounted
## One village. Seven inputs a person chooses (population, culture, purpose,
## wealth, enclosure, water, seed); everything else -- households, form,
## programme, site, variant_name -- is DERIVED, deterministically, from those
## seven, so a village is reproducible from the spec alone. VILLAGES §1.
##
## Unlike HouseSpec/CastleSpec, invalid inputs are not clamped into range: a
## population of 4 or 900 is a mistake, not a smaller or bigger village, so
## `generate()` records it in `errors()` and pushes a Godot error instead of
## silently reshaping the request. Callers that want a valid village check
## `valid()` before trusting the derived fields.

var seed: int
var rng: RandomNumberGenerator

# ---- user-specified (never randomized, never clamped) ----
## Opt-in close urban display. Buildings remain measured in real metres.
var compact_display: bool = false
## Optional exterior planting and ornament. 0 is plain; 0.5 preserves the
## historic recipe; values above it add separately seeded planting.
var decoration_level: float = 0.5
## Care of optional outdoor dressing, independent of household wealth.
var upkeep: float = 1.0
## The lavish garden village (PaperFjord's request): 0 is today's dressing,
## untouched; above it `VillageGarden` plants a compact display's open ground
## -- beds along every house front and path verge, flower scatter, flowering
## shrubs, trees where a canopy fits, lamp posts along the paths and small
## ponds dug in the gaps the layout leaves. Buildings, lots and roads never
## move for it. Compact displays only; a full village ignores it.
var garden: float = 0.0
var population: int = 40
## The people the history says this settlement serves beyond the `population`
## shown (C1, owner decision 2026-10-10). 0 is none. It sizes the civic
## programme only -- seat, walls, landmark, halls, market -- never the homes.
var implied_population: int = 0
var culture: StringName = &"english"
var purpose: StringName = &"farming"
var wealth: float = 0.4
var enclosure: StringName = &"none"
var water: StringName = &"none"
var orientation: float = 0.0
var period: int = 1200
## Optional external C1 brief. Empty strings and the default palette preserve
## the native seven-input village path exactly.
var site_brief := false
var regime: StringName = &""
var tongue: StringName = &""
var source_culture: StringName = &""
var plant_palette: StringName = &"english"
var kept_buildings: Dictionary = {}
var enclosure_kept_fraction: float = 1.0
var terrain_envelope: Dictionary = {}
## The measured ground under the site (VillageTerrain), or null for flat.
## Optional and read-only to the planners today: with it the exporter reports
## how the ground lies under every lot, building and road
## (docs/VILLAGE_TERRAIN.md); without it every output is byte-identical.
var terrain: VillageTerrain = null
var requested_site_m: float = 400.0

# ---- derived from seed + the six above ----
var households: int = 0
## The form the PLANNERS lay: one of VillageSitePlanner.FORMS_SUPPORTED.
var form: StringName = &""
## The form the village SHOULD have: with terrain, derived from the ground
## (one of FORM_VOCABULARY); without, the same as `form`. Where it has no
## planner yet `form` is its FORM_FALLBACK.
var form_intent: StringName = &""
var programme: Array[Dictionary] = []   # {kind, min_pop, request, where}
var site: Rect2 = Rect2()
var variant_name: String = ""

const POP_MIN := 12
const POP_MAX := 500
const PEOPLE_PER_HOUSEHOLD := 4.5
const HOUSEHOLD_JITTER := 0.10   # +-10% from the seed

const CULTURES: Array[StringName] = [
	&"english", &"frankish", &"norse", &"alpine", &"moorish", &"eastern", &"blighted",
	&"mediterranean", &"east_asian", &"saharan"]
const PURPOSES: Array[StringName] = [
	&"farming", &"crossroads", &"market", &"mill", &"fishing", &"mining",
	&"garrison", &"pilgrim", &"forest"]
const ENCLOSURES: Array[StringName] = [&"none", &"hedge", &"palisade", &"wall"]
## `lake`: standing fresh water along one side (VILLAGE_TERRAIN.md, Decision
## 3). Laid like a coast; a mill earns it like any water.
const WATERS: Array[StringName] = [&"none", &"pond", &"stream", &"river", &"coast", &"lake"]

## Wall needs a population that could plausibly build and man one, or a
## garrison purpose that supplies the manpower regardless of headcount.
const WALL_MIN_POPULATION := 150
## The civic programme stops growing here. Every civic threshold is at or
## below it, so a capital of millions plans the civic programme of a town of
## this size on one site; the rest of its people are the caller's to imply.
const CIVIC_MAX := POP_MAX

## §3: the road-graph/common vocabulary, in match order. Each row is tried in
## turn and the first whose predicate holds wins, so more specific forms
## (a fortified gate village, a fishing strand) are listed before the general
## farming defaults they would otherwise be shadowed by.
##
## `min_pop`/`max_pop` are inclusive; `purposes` empty means "any purpose";
## `cultures` empty means "any culture". `force` is an extra predicate name
## resolved in `_form_predicate()` for the two rules that are not simple
## population/purpose/culture bounds (`gate`'s "or population >= 200", and
## `round`'s "or blighted culture").
const FORMS := [
	{"form": &"gate", "min_pop": 0, "max_pop": POP_MAX, "purposes": [], "cultures": [], "force": &"gate"},
	{"form": &"strand", "min_pop": 15, "max_pop": 100, "purposes": [&"fishing"], "cultures": []},
	{"form": &"planted", "min_pop": 150, "max_pop": 500, "purposes": [&"market", &"garrison"], "cultures": []},
	{"form": &"crossroads", "min_pop": 30, "max_pop": 150, "purposes": [&"crossroads", &"market"], "cultures": []},
	{"form": &"green", "min_pop": 40, "max_pop": 200, "purposes": [&"farming", &"pilgrim"], "cultures": []},
	{"form": &"round", "min_pop": 12, "max_pop": 60, "purposes": [&"farming", &"forest"], "cultures": [&"blighted"], "force": &"round"},
	{"form": &"street", "min_pop": 12, "max_pop": 80, "purposes": [&"farming", &"forest", &"mining"], "cultures": []},
]
## The forms the ground can derive (VILLAGE_TERRAIN.md, Decision 3). Only a
## spec WITH terrain derives them; FORMS above is the flat vocabulary.
const TERRAIN_FORMS: Array[StringName] = [&"hillside", &"dispersed", &"crest", &"shore",
	&"valley", &"water"]
## Every form a spec can intend: the seven the planners lay, then the six the
## ground adds.
const FORM_VOCABULARY: Array[StringName] = [&"street", &"green", &"crossroads", &"round",
	&"strand", &"planted", &"gate", &"hillside", &"dispersed", &"crest", &"shore",
	&"valley", &"water"]
## Until a terrain form has its own planner, the spec PLANS the nearest form
## that has one and keeps the derived form in `form_intent`. Each VTER-FORM-*
## task that gives a form its planner deletes that form's ONE line here.
##   hillside  -> street  one street along the slope, the row a contour
##                        street will replace
##   water     -> strand  the row along the water the stilts will stand in
## (`dispersed` has its planner: VillageDispersedForm, VTER-FORM-DISPERSED;
## `shore`: VillageShoreForm, VTER-FORM-SHORE;
## `valley`: VillageValleyForm, VTER-FORM-VALLEY;
## `crest`: VillageCrestForm, VTER-FORM-CREST.)
const FORM_FALLBACK := {
	&"hillside": &"street",
	&"water": &"strand",
}
## The terrain form rule's thresholds (`_derive_form_on_ground`). Fitted on
## the 109 measured world sites against their hand labels and stable under
## a +-20 % change of any one of them (VILLAGE_TERRAIN.md, "The form").
const FORM_HILL_SLOPE := 0.17       ## median dry slope: a hill village from here
const FORM_CREST_TPI_M := 9.0       ## the centre this far over its 30-150 m ring...
const FORM_CREST_RANK := 0.75       ## ...and over this share of the ground round it
const FORM_SHORE_REACH_M := 350.0   ## coast or lake water within this of the centre
const FORM_VALLEY_SIDES := 0.25     ## p75 dry slope: steep sides
const FORM_VALLEY_RANK := 0.55      ## the centre lies in the lower part of its ground
const FORM_DROWNED := 0.5           ## the window this wet: the ground is the water's edge
const FORM_WATER_ROUND := 0.4       ## the wider ground this wet: water all round
const FORM_DISPERSED_POP := 150     ## a farming hill people under this scatters
const FORM_DISPERSED_REGIONS := 3   ## or this many separate level shelves to farm from
## Reading the ground for the form (read_ground): the analysis cell, the
## smallest level region that counts as a place to build a hamlet, and how far
## round the centre the "is this the top" rank looks.
const FORM_READ_CELL_M := 20.0
const FORM_REGION_M2 := 4000.0
const FORM_RANK_M := 350.0
const FORM_WATER_M := 450.0
const FORM_WINDOW_MIN_M := 120.0
const FORM_WINDOW_MAX_M := 400.0
## Below 25 people every form's common shrinks to the well; VILLAGES §3.
const HAMLET_POPULATION := 25

## §4: population -> programme, in the order the table lists them. `min_pop`
## 0 means "every village gets one". `purpose_only`, when set, restricts the
## row to that purpose regardless of population (the pilgrim temple, the
## mining adit, the fishing strand furniture); `needs_water`, when true,
## additionally requires `water != none` (the mill).
const RECIPES := [
	{"kind": &"house", "min_pop": 0, "request": "house(seed, style, trade, w, l, h, storeys)", "where": "on lots"},
	{"kind": &"well", "min_pop": 0, "request": "MeshKit well", "where": "on the common, 1 per 60 people"},
	{"kind": &"shrine", "min_pop": 20, "request": "temple small form, or church at 12m", "where": "on the common or the high point"},
	{"kind": &"smithy", "min_pop": 30, "request": "shop(&\"blacksmith\")", "where": "on the through road, at the edge"},
	{"kind": &"tavern", "min_pop": 40, "request": "shop(&\"tavern\")", "where": "on the through road, near a gate, facing the common"},
	{"kind": &"mill", "min_pop": 50, "request": "shop(&\"bakery\") + mill mass", "where": "on the water, with a race", "needs_water": true},
	{"kind": &"bakery", "min_pop": 50, "request": "shop(&\"bakery\")", "where": "on the through road", "needs_water": false, "unless_water": true},
	{"kind": &"church", "min_pop": 60, "request": "church(seed, style, 10, 20, 12)", "where": "on the common, its own churchyard lot"},
	{"kind": &"general_store", "min_pop": 60, "request": "shop(&\"general_store\")", "where": "on the common"},
	{"kind": &"inn", "min_pop": 80, "request": "shop(&\"inn\")", "where": "on the through road"},
	{"kind": &"stable", "min_pop": 80, "request": "shop(&\"stable\")", "where": "behind or beside the inn"},
	{"kind": &"carpenter", "min_pop": 80, "request": "shop(&\"carpenter\")", "where": "any street"},
	{"kind": &"market", "min_pop": 100, "request": "Stall_Empty / Stall_Cart_Empty rows", "where": "the common becomes a square"},
	{"kind": &"butcher", "min_pop": 100, "request": "shop(&\"butcher\")", "where": "the square"},
	{"kind": &"tailor", "min_pop": 100, "request": "shop(&\"tailor\")", "where": "the square"},
	{"kind": &"town_hall", "min_pop": 100, "request": "shop(&\"town_hall\")", "where": "on the square"},
	{"kind": &"apothecary", "min_pop": 120, "request": "shop(&\"apothecary\")", "where": "streets"},
	{"kind": &"tavern_2", "min_pop": 120, "request": "shop(&\"tavern\")", "where": "streets"},
	{"kind": &"guildhall", "min_pop": 150, "request": "shop(&\"guildhall\")", "where": "on the square"},
	{"kind": &"manor", "min_pop": 200, "request": "castle at house/manor tier", "where": "at the head of the village on its own lane"},
	{"kind": &"temple", "min_pop": 0, "request": "temple(...)", "where": "takes the church's place; the common is its forecourt", "purpose_only": &"pilgrim"},
	{"kind": &"mine_adit", "min_pop": 0, "request": "MeshKit adit", "where": "at the far end of the through road", "purpose_only": &"mining"},
	{"kind": &"strand_racks", "min_pop": 0, "request": "props: racks, boats, smokehouse", "where": "on the strand in front of the row", "purpose_only": &"fishing"},
]

## §1 variant_name: CastleGenerator's word lists plus village-only suffixes.
const VILLAGE_SUFFIXES := ["ton", "ham", "by", "thorpe", " Ford", " Cross", " Mill", " Green"]

## Approximate footprint (m^2) per programme kind, used only to size `site`
## before a real lot planner (VIL-003) exists; sized from the MEASURED
## `placement()` bounds afterwards is what the lot planner actually does
## (§5), this is a rough envelope for the spec's own `site` field.
const AREA_PER_KIND := {
	&"house": 70.0, &"well": 6.0, &"shrine": 40.0, &"smithy": 60.0,
	&"tavern": 90.0, &"mill": 80.0, &"bakery": 60.0, &"church": 240.0,
	&"general_store": 70.0, &"inn": 140.0, &"stable": 70.0, &"carpenter": 60.0,
	&"market": 200.0, &"butcher": 60.0, &"tailor": 60.0, &"town_hall": 120.0,
	&"apothecary": 60.0, &"tavern_2": 90.0, &"guildhall": 150.0,
	&"manor": 900.0, &"temple": 200.0, &"mine_adit": 30.0, &"strand_racks": 30.0,
}
const COMMON_AREA := 150.0
const HAMLET_COMMON_AREA := 30.0
const EDGE_BAND_M := {&"none": 4.0, &"hedge": 5.0, &"palisade": 8.0, &"wall": 10.0}


func _init(p_seed := 0) -> void:
	seed = p_seed
	rng = RandomNumberGenerator.new()
	rng.seed = seed


## Ready-to-plan close urban display for projects that render many settlements
## inside a small scene. The buildings retain their measured real-world size;
## only streets, yards and clearances use the compact layout rules.
static func compact(p_seed: int, p_population: int = 40,
		p_culture: StringName = &"english", p_purpose: StringName = &"market",
		p_wealth: float = 0.4) -> VillageSpec:
	var spec := VillageSpec.new(p_seed)
	spec.compact_display = true
	spec.population = p_population
	spec.culture = p_culture
	spec.purpose = p_purpose
	spec.wealth = p_wealth
	spec.generate(p_seed)
	return spec


## Everything wrong with the CURRENT inputs, independent of whether
## `generate()` has been called. Empty means the spec is safe to derive from.
func errors() -> Array[String]:
	var out: Array[String] = []
	if compact_display and (water != &"none" or enclosure != &"none"):
		out.append("compact_display currently requires water=none and enclosure=none")
	if population < POP_MIN or population > POP_MAX:
		out.append("population %d out of range [%d, %d]" % [population, POP_MIN, POP_MAX])
	if not (culture in CULTURES):
		out.append("unknown culture '%s'" % culture)
	if not (purpose in PURPOSES):
		out.append("unknown purpose '%s'" % purpose)
	if wealth < 0.0 or wealth > 1.0:
		out.append("wealth %f out of range [0, 1]" % wealth)
	if not is_finite(decoration_level) or decoration_level < 0.0 or decoration_level > 1.0:
		out.append("decoration_level %f out of range [0, 1]" % decoration_level)
	if not is_finite(upkeep) or upkeep < 0.0 or upkeep > 1.0:
		out.append("upkeep %f out of range [0, 1]" % upkeep)
	if not is_finite(garden) or garden < 0.0 or garden > 1.0:
		out.append("garden %f out of range [0, 1]" % garden)
	if not (enclosure in ENCLOSURES):
		out.append("unknown enclosure '%s'" % enclosure)
	if not (water in WATERS):
		out.append("unknown water '%s'" % water)
	if enclosure == &"wall" and civic_population() < WALL_MIN_POPULATION and purpose != &"garrison":
		out.append("enclosure 'wall' needs population >= %d or purpose 'garrison'" % WALL_MIN_POPULATION)
	if terrain != null and not terrain.valid():
		out.append("terrain: %s" % "; ".join(terrain.errors()))
	return out


## The people the civic programme is sized for: the shown population, or the
## implied one up to CIVIC_MAX when the caller gave a larger one.
func civic_population() -> int:
	if implied_population <= population:
		return population
	return mini(implied_population, CIVIC_MAX)


func valid() -> bool:
	return errors().is_empty()


## Fills every derived field from the seven inputs. Pure given (population,
## culture, purpose, wealth, enclosure, water, seed): calling it twice on two
## specs built from the same inputs leaves both with identical derived
## fields (the purity rule VillageQA.ScaleCheck enforces on the plan).
##
## On an invalid spec this still records `errors()` via push_error and
## leaves the derived fields at their unpopulated defaults rather than
## guessing a clamped village nobody asked for.
func generate(p_seed: int) -> void:
	seed = p_seed
	rng = RandomNumberGenerator.new()
	rng.seed = seed

	var errs: Array[String] = errors()
	for e in errs:
		push_error("VillageSpec: %s" % e)
	if population < POP_MIN or population > POP_MAX:
		return   # nothing sane to derive without a population in range

	households = _derive_households(population, seed)
	if compact_display:
		form = &"planted"
		form_intent = form
	elif terrain != null and terrain.valid():
		form_intent = _derive_form_on_ground(read_ground(terrain, form_window_m()),
			population, purpose, water, culture)
		form = FORM_FALLBACK.get(form_intent, form_intent)
	else:
		form = _derive_form(population, purpose, culture)
		form_intent = form
	programme = _derive_programme(civic_population(), purpose, water)
	if culture == &"blighted":
		programme = programme.filter(func(row): return row["kind"] not in [&"shrine", &"church", &"temple"])
		programme.append({"kind": &"temple", "min_pop": 0,
			"request": "ziggurat of the void", "where": "landmark beside the common"})
	site = _derive_site(programme, enclosure)
	variant_name = _derive_variant_name(seed)
	if site_brief:
		variant_name = _brief_variant_name(seed, source_culture, tongue)


## `round(population / 4.5)`, then nudged +-10% by a value drawn from the
## seed so two villages with the same population are not always identical
## households. Deterministic: same (population, seed) -> same households.
static func _derive_households(p_population: int, p_seed: int) -> int:
	var base: float = float(p_population) / PEOPLE_PER_HOUSEHOLD
	var r := RandomNumberGenerator.new()
	r.seed = hash("households|%d" % p_seed)
	var jitter: float = r.randf_range(-HOUSEHOLD_JITTER, HOUSEHOLD_JITTER)
	return maxi(1, int(round(base * (1.0 + jitter))))


## §3's form table, first matching row wins (see FORMS' doc comment above).
static func _derive_form(p_population: int, p_purpose: StringName, p_culture: StringName) -> StringName:
	for row in FORMS:
		if not _form_predicate(row, p_population, p_purpose, p_culture):
			continue
		return row["form"]
	return &"street"   # the fallback form below 25 people is a hamlet, still 'street'


static func _form_predicate(row: Dictionary, p_population: int, p_purpose: StringName, p_culture: StringName) -> bool:
	var force: StringName = row.get("force", &"")
	if force == &"gate":
		if p_purpose == &"garrison" or p_population >= 200:
			return true
		return false
	if p_population < int(row["min_pop"]) or p_population > int(row["max_pop"]):
		return false
	var purposes: Array = row["purposes"]
	var cultures: Array = row["cultures"]
	if force == &"round":
		return (p_purpose in purposes) or (p_culture in cultures)
	if purposes.is_empty() and cultures.is_empty():
		return true
	if not purposes.is_empty() and p_purpose in purposes:
		return true
	if not cultures.is_empty() and p_culture in cultures:
		return true
	return false


## The side of the square the form is read over: the planner's own site,
## never smaller than a hamlet's nor larger than SITE_MAX.
func form_window_m() -> float:
	return clampf(requested_site_m, FORM_WINDOW_MIN_M, FORM_WINDOW_MAX_M)


## The form WITH terrain (VILLAGE_TERRAIN.md, Decision 2: landform first,
## then water and purpose, then population). First row that holds wins:
##
##   | # | the ground (read_ground) and the spec              | form      |
##   |---|----------------------------------------------------|-----------|
##   | 1 | window wet_share >= FORM_DROWNED                   | shore     |
##   | 2 | ground within FORM_WATER_M wet >= FORM_WATER_ROUND | water     |
##   | 3 | centre_tpi >= FORM_CREST_TPI_M and                 | crest     |
##   |   |   centre_rank >= FORM_CREST_RANK                   |           |
##   | 4 | water coast/lake, wet ground <= FORM_SHORE_REACH_M | shore     |
##   | 5 | water river/lake, slope_p75 >= FORM_VALLEY_SIDES,  | valley    |
##   |   |   centre_rank < FORM_VALLEY_RANK                   |           |
##   | 6 | slope_median >= FORM_HILL_SLOPE, farming/forest,   | dispersed |
##   |   |   population < FORM_DISPERSED_POP or               |           |
##   |   |   level_regions >= FORM_DISPERSED_REGIONS          |           |
##   | 7 | slope_median >= FORM_HILL_SLOPE                    | hillside  |
##   |   | -- level ground: water and purpose --              |           |
##   | 8 | purpose garrison                                   | gate      |
##   | 9 | water lake, purpose fishing                        | water     |
##   |10 | water coast, purpose fishing                       | shore     |
##   |11 | purpose crossroads                                 | crossroads|
##   |12 | anything else                                      | planted   |
##
## Population enters at row 6 only: on level ground the survey's real
## villages read `planted` at every size from 12 people to 500, and the
## flat rule's `gate` at 200 people is a flat-world habit the ground replaces.
## Unreadable ground (an empty reading) falls back to the flat rule.
static func _derive_form_on_ground(g: Dictionary, p_population: int, p_purpose: StringName,
		p_water: StringName, p_culture: StringName) -> StringName:
	if g.is_empty():
		return _derive_form(p_population, p_purpose, p_culture)
	if float(g["wet_share"]) >= FORM_DROWNED:
		return &"shore"
	if float(g["wide_wet_share"]) >= FORM_WATER_ROUND:
		return &"water"
	if float(g["centre_tpi"]) >= FORM_CREST_TPI_M and float(g["centre_rank"]) >= FORM_CREST_RANK:
		return &"crest"
	if p_water in [&"coast", &"lake"] and float(g["water_far_m"]) <= FORM_SHORE_REACH_M:
		return &"shore"
	if p_water in [&"river", &"lake"] and float(g["slope_p75"]) >= FORM_VALLEY_SIDES \
			and float(g["centre_rank"]) < FORM_VALLEY_RANK:
		return &"valley"
	if float(g["slope_median"]) >= FORM_HILL_SLOPE:
		if p_purpose in [&"farming", &"forest"] and (p_population < FORM_DISPERSED_POP
				or int(g["level_regions"]) >= FORM_DISPERSED_REGIONS):
			return &"dispersed"
		return &"hillside"
	if p_purpose == &"garrison":
		return &"gate"
	if p_water == &"lake" and p_purpose == &"fishing":
		return &"water"
	if p_water == &"coast" and p_purpose == &"fishing":
		return &"shore"
	if p_purpose == &"crossroads":
		return &"crossroads"
	return &"planted"


## How the ground lies under a village of this spec, read once for the form
## rule (`_derive_form_on_ground`). The window is the planner's site at most,
## `side_m` square about the plan origin, read at FORM_READ_CELL_M (never finer
## than half the terrain cell): a form is a village-scale fact, and the same
## ground at 1 m and at 90 m should read alike. {} when the ground is unread.
##   shares          {class: share of the window's cells} (VillageSiteAnalysis)
##   wet_share       share of window cells under water_level_m
##   slope_median    median mean-facet slope of the DRY window cells
##   slope_p75       its 75th percentile
##   steep_share     dry cells steeper than PLOT_MAX: a house there needs steps
##   level_share     dry cells at or under CART_MAX
##   level_regions   gentle (<= CART_MAX) dry components of >= FORM_REGION_M2
##   level_largest   the largest one's share of the window
##   relief_m        highest minus lowest window cell
##   centre_tpi      the centre's height over its 30-150 m surroundings
##   centre_rank     share of the ground within FORM_RANK_M lower than the centre
##   water_near_m    metres from the centre to the nearest wet cell (INF: none)
##   water_far_m     the same over the ground within FORM_WATER_M (wider than
##                   the window: a fjord 400 m off still makes a shore village)
##   wide_wet_share  share of that wider ground under water_level_m
static func read_ground(ground: VillageTerrain, side_m: float) -> Dictionary:
	if ground == null or not ground.valid():
		return {}
	var half := side_m * 0.5
	var a := VillageSiteAnalysis.of(ground, Rect2(-half, -half, side_m, side_m), FORM_READ_CELL_M)
	if not a.valid():
		return {}
	var n := a.cell_count()
	var counts := a.histogram()
	var shares := {}
	for k in counts:
		shares[String(k)] = float(counts[k]) / maxi(1, n)
	var slopes: Array[float] = []
	var lo := INF
	var hi := -INF
	var wet := 0
	for i in range(n):
		var h := a.height_of(i)
		lo = minf(lo, h)
		hi = maxf(hi, h)
		if a.wet_of(i):
			wet += 1
		else:
			slopes.append(a.slope_of(i))
	slopes.sort()
	var dry := slopes.size()
	var steep := 0
	var level := 0
	for s in slopes:
		steep += int(s > VillageSiteAnalysis.PLOT_MAX)
		level += int(s <= VillageSiteAnalysis.CART_MAX)
	var regions: Array = a.level_regions(VillageSiteAnalysis.CART_MAX, FORM_REGION_M2)
	var site_area := float(n) * a.cell_m * a.cell_m
	var centre := a.cell_at(Vector2.ZERO)
	var ch := a.height_of(centre)
	var below := 0
	var seen := 0
	var wide := 0
	var wide_wet := 0
	var water_far := INF
	var level_m := ground.water_level_m
	var step := maxf(a.cell_m, ground.cell_m)
	var reach := int(floor(FORM_WATER_M / step))
	var box := ground.bounds().grow(1e-6)
	for j in range(-reach, reach + 1):
		for i in range(-reach, reach + 1):
			var p := Vector2(i, j) * step
			if not box.has_point(p) or p.length() > FORM_WATER_M + 1e-6:
				continue
			var h := ground.height_at(p)
			wide += 1
			if not is_nan(level_m) and h <= level_m:   # inclusive, as the analysis is
				wide_wet += 1
				water_far = minf(water_far, p.length())
			if p.length() <= FORM_RANK_M + 1e-6:
				seen += 1
				below += int(h < ch)
	return {
		"shares": shares,
		"wet_share": float(wet) / maxi(1, n),
		"slope_median": slopes[dry / 2] if dry > 0 else 0.0,
		"slope_p75": slopes[mini(dry - 1, (dry * 3) / 4)] if dry > 0 else 0.0,
		"steep_share": float(steep) / maxi(1, dry),
		"level_share": float(level) / maxi(1, dry),
		"level_regions": regions.size(),
		"level_largest": float(regions[0]["area_m2"]) / site_area if not regions.is_empty() else 0.0,
		"relief_m": hi - lo,
		"centre_tpi": a.tpi_of(centre),
		"centre_rank": float(below) / maxi(1, seen),
		"water_near_m": a.water_distance_of(centre),
		"water_far_m": water_far,
		"wide_wet_share": float(wide_wet) / maxi(1, wide),
	}


## §4's population->programme table, RECIPES, filtered to what this village's
## population and purpose actually earn. Every row is a `BuildingRequest`
## family the generator already has; nothing here draws a building of its
## own (§4's opening sentence).
static func _derive_programme(p_population: int, p_purpose: StringName, p_water: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in RECIPES:
		var purpose_only: StringName = row.get("purpose_only", &"")
		if purpose_only != &"":
			if p_purpose == purpose_only:
				out.append(row)
			continue
		if p_population < int(row["min_pop"]):
			continue
		if row.get("needs_water", false) and p_water == &"none":
			continue
		if row.get("unless_water", false) and p_water != &"none":
			continue
		out.append(row)
	return out


## `Sigma lot areas * 1.6` plus the common, plus the edge band, as a square
## site centred on the origin -- a real footprint (VIL-003) replaces this
## once the site planner exists; this is only sized well enough for the
## spec's own scale checks to have something to measure.
static func _derive_site(p_programme: Array[Dictionary], p_enclosure: StringName) -> Rect2:
	var lot_area := 0.0
	for row in p_programme:
		var kind: StringName = row["kind"]
		lot_area += float(AREA_PER_KIND.get(kind, 60.0))
	var common: float = COMMON_AREA
	var built: float = lot_area * 1.6 + common
	var side: float = sqrt(built)
	var band: float = float(EDGE_BAND_M.get(p_enclosure, 4.0)) * 2.0
	side += band
	return Rect2(Vector2(-side * 0.5, -side * 0.5), Vector2(side, side))


## CastleGenerator's word lists, with village suffixes attached instead of
## the castle ones.
static func _derive_variant_name(p_seed: int) -> String:
	var nr := RandomNumberGenerator.new()
	nr.seed = hash("variant_name|%d" % p_seed)
	var first: String = CastleGenerator.FIRST_WORDS[nr.randi_range(0, CastleGenerator.FIRST_WORDS.size() - 1)]
	var second: String = CastleGenerator.SECOND_WORDS[nr.randi_range(0, CastleGenerator.SECOND_WORDS.size() - 1)]
	var suffix: String = VILLAGE_SUFFIXES[nr.randi_range(0, VILLAGE_SUFFIXES.size() - 1)]
	return "%s%s%s" % [first, second, suffix]


## C1 names use both external culture and tongue, while remaining a pure
## function of the brief and its seed. Native villages retain the name above.
static func _brief_variant_name(p_seed: int, p_culture: StringName,
		p_tongue: StringName) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("site_brief_name|%d|%s|%s" % [p_seed, p_culture, p_tongue])
	var roots := ["Alder", "Brook", "Cairn", "Dale", "Elder", "Fen", "Glen", "Hearth"]
	var endings := ["ford", "stead", "mere", "wick", "combe", "holt", "bridge", "field"]
	var tongue_roots := {
		&"orc": ["Grak", "Urz", "Morg", "Drok"], &"elf": ["Leth", "Ael", "Ith", "Sila"],
		&"dwarf": ["Dun", "Kaz", "Brom", "Thrain"], &"human": ["Alder", "Brook", "Cairn", "Dale"]}
	var words: Array = tongue_roots.get(p_tongue, roots)
	var root: String = words[rng.randi_range(0, words.size() - 1)]
	var end: String = endings[rng.randi_range(0, endings.size() - 1)]
	return "%s%s of %s" % [root, end, String(p_culture).capitalize()]
