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
var population: int = 40
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
var requested_site_m: float = 400.0

# ---- derived from seed + the six above ----
var households: int = 0
var form: StringName = &""
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
const WATERS: Array[StringName] = [&"none", &"pond", &"stream", &"river", &"coast"]

## Wall needs a population that could plausibly build and man one, or a
## garrison purpose that supplies the manpower regardless of headcount.
const WALL_MIN_POPULATION := 150

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
	if not (enclosure in ENCLOSURES):
		out.append("unknown enclosure '%s'" % enclosure)
	if not (water in WATERS):
		out.append("unknown water '%s'" % water)
	if enclosure == &"wall" and population < WALL_MIN_POPULATION and purpose != &"garrison":
		out.append("enclosure 'wall' needs population >= %d or purpose 'garrison'" % WALL_MIN_POPULATION)
	return out


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
	form = &"planted" if compact_display else _derive_form(population, purpose, culture)
	programme = _derive_programme(population, purpose, water)
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
