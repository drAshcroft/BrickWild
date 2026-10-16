extends SceneTree
## C1: a mythsim SiteRequest in, a SitePlan on disk out (VIL-014).
##
##   godot --headless --path . --script res://tools/export_village_plan.gd \
##       -- --request in.json --out out.json
##
## The contract is `C:/Projects/Dm_View/docs/contracts/c1-site.md` and it is
## binding. This is a SERIALISER, not a generator: the site, lot and
## programme planners already produce a `VillagePlan` carrying roads, lots,
## buildings, commons, water, fields and props as plain Rect2/Vector2 data,
## and the whole of the work here is mapping mythsim's vocabulary onto a
## `VillageSpec` and writing the result out in the agreed shape.
##
## Two things the contract asks for that BrickWild did not already have:
##
##   * `building_id`, `"<city_id>/b-<nnn>"`, the join key C2 (the interior
##     plan) and C4 (the people who live in it) hang off. It is the
##     building's index in the plan, which is stable because the planner is.
##   * BYTE-IDENTICAL output on two runs and two machines. DM_View does not
##     store generated geometry, it regenerates it. So every float is snapped
##     before it is written (a double printed at full precision is where two
##     machines differ), every list keeps the planner's own order, and the
##     seed is taken from the REQUEST TEXT rather than from the parsed
##     number -- mythsim's seeds are unsigned 64-bit and do not survive a
##     JSON parse as integers.
##
## The settlement's size comes from the CALLER (owner decision 2026-10-09).
## A schema 2 SiteRequest's `population` is the people of the whole polity
## node (`population_of: "node"`, Voxel_Build VXB-002): tens of thousands,
## sometimes millions, sometimes 0. It is never read as a village. Such a
## request needs `--population N`, the people of the settlement to plan:
##
##   godot --headless --path . --script res://tools/export_village_plan.gd ##       -- --request site-city-0004.json --population 45 --out out.json
##
## Without it the request is refused with exit 2. A schema 1 request plans its
## own `population` as before; `--population` overrides it. Either way the plan
## carries the caller's number as `population_asked` and a note.
##
## The caller may also pass `--implied-population M`, the city the history
## says it is (owner decision 2026-10-10). M sizes the CIVIC programme -- the
## seat, the walls, the landmark, the halls and the market -- and never adds a
## home or a residential lot: those people exist in the game's logic, not on
## the ground. Civic scale stops at `VillageSpec.CIVIC_MAX`. The plan then
## carries `population_implied`, `population_civic` and, per building,
## `serves` ("visible" or "implied").
##
## The caller may pass the GROUND (docs/VILLAGE_TERRAIN.md): a
## `brickwild.terrain` height grid as `terrain.height` in the request (inline,
## or a path relative to the request), or `--terrain <grid.json>`. It must
## cover the planned site. The plan then carries `ground` (the whole site) and
## a `ground` block on every lot, building and road: how high, how much fall,
## how steep, which way down. The planners do not yet use it; without it the
## output is byte-identical to before.
##
## Exit codes: 0 written, 2 usage or I/O, 3 refused (cannot satisfy).
##
## Scope, deliberately: no mesh, no props-as-geometry, no assets. This is the
## plan, not the build.

const OUT_SCHEMA := "dmv.site.plan"
const OUT_SCHEMA_VERSION := 1
const GENERATOR := "brickwild-0.3"
## Everything is written to this many decimal places, and nothing is written
## at more. A millimetre is far below anything a village plan means, and it
## is what makes two runs byte-identical.
const PLACES := 0.001

## The site is capped at BrickWild's own maximum however big a cell is.
const SITE_MAX_M := 400.0
const BUILDING_MAX := 140


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var opts: Dictionary = _options(args)
	if not opts.has("request") or not opts.has("out"):
		printerr("usage: --request <in.json> --out <out.json> [--population <people>] [--implied-population <people>] [--terrain <grid.json>]")
		quit(2)
		return
	var text: String = _read(opts["request"])
	if text.is_empty():
		printerr("cannot read %s" % opts["request"])
		quit(2)
		return
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		printerr("%s is not a JSON object" % opts["request"])
		quit(2)
		return
	var notes: Array[String] = []
	var population_arg: String = String(opts.get("population", ""))
	var implied_arg: String = String(opts.get("implied-population", ""))
	var size_error: String = population_error(parsed, population_arg)
	if size_error.is_empty():
		size_error = implied_error(implied_arg)
	if not size_error.is_empty():
		printerr(size_error)
		quit(2)
		return
	var request: Dictionary = with_implied_population(
		with_caller_population(parsed, population_arg, notes), implied_arg)
	var spec: VillageSpec = spec_from_request(request, text, notes)
	var brief_errors: Array[String] = request_errors(request)
	if not brief_errors.is_empty():
		printerr("SiteRequest refused: %s" % "; ".join(brief_errors))
		quit(3)
		return
	var ground: VillageTerrain = terrain_from_request(request,
		String(opts["request"]).get_base_dir(), String(opts.get("terrain", "")))
	if ground != null and not ground.valid():
		printerr("SiteRequest refused: terrain %s" % "; ".join(ground.errors()))
		quit(3)
		return
	spec.terrain = ground
	if not spec.valid():
		printerr("SiteRequest does not map to a village: %s" % ", ".join(spec.errors()))
		quit(3)
		return
	spec.generate(spec.seed)
	var intent_note := form_intent_note(spec)
	if not intent_note.is_empty():
		notes.append(intent_note)
	var plan: VillagePlan = VillageLotPlanner.plan(spec)
	if plan.roads.is_empty():
		printerr("SiteRequest refused: no roads could be planned for form '%s'" % String(spec.form))
		quit(3)
		return
	if plan.site.size.x > spec.requested_site_m + 0.01 or plan.site.size.y > spec.requested_site_m + 0.01:
		printerr("SiteRequest refused: population %d needs %.1f x %.1f m, beyond %.1f m terrain envelope" % [
			spec.population, plan.site.size.x, plan.site.size.y, spec.requested_site_m])
		quit(3)
		return
	var programme: Array[BuildingRequest] = VillageProgrammer.programme(spec)
	var requested_buildings: int = programme.size()
	if requested_buildings > BUILDING_MAX:
		printerr("SiteRequest refused: %d buildings exceeds site capacity %d" % [
			requested_buildings, BUILDING_MAX])
		quit(3)
		return
	if plan.buildings.size() < requested_buildings:
		printerr("SiteRequest refused: only %d of %d requested buildings fit in %.1f m (unplaced: %s; planned site %.0f x %.0f m)" % [
			plan.buildings.size(), requested_buildings, spec.requested_site_m,
			", ".join(unplaced_labels(programme, plan)), plan.site.size.x, plan.site.size.y])
		quit(3)
		return
	if ground != null and not ground.covers(plan.site):
		var b: Rect2 = ground.bounds()
		printerr("SiteRequest refused: terrain covers [%.1f, %.1f]-[%.1f, %.1f] m, the planned site needs [%.1f, %.1f]-[%.1f, %.1f] m" % [
			b.position.x, b.position.y, b.end.x, b.end.y,
			plan.site.position.x, plan.site.position.y, plan.site.end.x, plan.site.end.y])
		quit(3)
		return
	var out: Dictionary = site_plan(plan, request)
	if ground != null:
		notes.append(ground_note(out))
	out["notes"] = notes
	for note in notes:
		print("  note: %s" % note)
	var f := FileAccess.open(opts["out"], FileAccess.WRITE)
	if f == null:
		printerr("cannot write %s" % opts["out"])
		quit(2)
		return
	f.store_string(JSON.stringify(out, "\t", true) + "\n")
	f.close()
	print("%s: %d buildings, %d lots, %d roads on a %.0f x %.0f m site -> %s" % [
		String(out["city_id"]), (out["buildings"] as Array).size(),
		(out["lots"] as Array).size(), (out["roads"] as Array).size(),
		out["site"]["width_m"], out["site"]["depth_m"], opts["out"]])
	quit(0)


## True when the request's `population` counts a whole polity node, not a
## settlement: schema 2 onward, or any request that says so.
static func is_node_population(request: Dictionary) -> bool:
	var version: Variant = request.get("schema_version", 1)
	return (_is_number(version) and int(version) >= 2) 		or String(request.get("population_of", "")) == "node"


## Why `--population` cannot be used with this request, or "" when it can.
static func population_error(request: Dictionary, population_arg: String) -> String:
	if not population_arg.is_empty() and not population_arg.is_valid_int():
		return "--population must be a whole number of people, not '%s'" % population_arg
	if population_arg.is_empty() and is_node_population(request):
		return "SiteRequest schema %s population %s is the whole node's people, not a settlement; pass the settlement's size with --population N" % [
			_whole(request.get("schema_version", "?")), _whole(request.get("population", 0))]
	return ""


## The request with the caller's settlement size in `population`, or the
## request itself when the caller gave none.
static func with_caller_population(request: Dictionary, population_arg: String,
		notes: Array[String]) -> Dictionary:
	if population_arg.is_empty():
		return request
	var out: Dictionary = request.duplicate(true)
	out["population"] = population_arg.to_int()
	var whose: String = "the node's" if is_node_population(request) else "the request's"
	notes.append("planned for %d people from the caller's --population; %s population is %s" % [
		population_arg.to_int(), whose, _whole(request.get("population", 0))])
	return out


## Why `--implied-population` cannot be used, or "" when it can.
static func implied_error(implied_arg: String) -> String:
	if implied_arg.is_empty():
		return ""
	if not implied_arg.is_valid_int() or implied_arg.to_int() < 0:
		return "--implied-population must be a whole number of people, not '%s'" % implied_arg
	return ""


## The request carrying the caller's implied population, or the request itself
## when the caller gave none.
static func with_implied_population(request: Dictionary, implied_arg: String) -> Dictionary:
	if implied_arg.is_empty():
		return request
	var out: Dictionary = request.duplicate(true)
	out["implied_population"] = implied_arg.to_int()
	return out


static func _whole(value: Variant) -> String:
	return "%d" % int(value) if _is_number(value) else str(value)


## What the programme asked for and the plan did not place, as `kind/purpose`.
## A refusal that says only "N of M fit" reads as a full site; it usually
## means one building had no legal lot.
static func unplaced_labels(programme: Array[BuildingRequest], plan: VillagePlan) -> Array[String]:
	var left := {}
	for request in programme:
		var key := _label(plan.spec, request)
		left[key] = int(left.get(key, 0)) + 1
	for b in plan.buildings:
		var request: BuildingRequest = b["request"]
		var key := _label(plan.spec, request)
		left[key] = int(left.get(key, 0)) - 1
	var out: Array[String] = []
	for key in left:
		for i in range(int(left[key])):
			out.append(key)
	return out


static func _label(spec: VillageSpec, request: BuildingRequest) -> String:
	var monument: String = VillageProgrammer.monument_of(spec, request)
	if not monument.is_empty():
		return monument
	return "%s/%s" % [request.kind, request.purpose] if request.purpose != &"" else String(request.kind)


# ------------------------------------------------------- request -> spec

## mythsim's ten authored words for what a city has built. `buildings` in the
## request is a kept FRACTION against each of them -- it says what the city
## has, never how many or where, and turning that into instances is
## BrickWild's half of the contract.
const BUILT_WORDS := ["palisade", "granary", "stone-wall", "shrine", "temple",
	"palace", "forge-hall", "great-tomb", "marble-wall", "ziggurat"]

## mythsim's cultures are its own; BrickWild's seven are the palettes it can
## actually build. Anything not named here is folded onto one of the seven by
## the hash of its own name, which is arbitrary but STABLE -- the same tongue
## always builds in the same style, which is what a consumer needs.
const CULTURE_MAP := {
	"river-song": &"english", "highland": &"alpine", "steppe": &"eastern",
	"desert": &"moorish", "fjord": &"norse", "wood": &"english",
	"ash": &"blighted", "orc": &"blighted", "elf": &"english",
	"dwarf": &"alpine", "human": &"english",
}

## What the city is FOR, read off what it has built and where it stands, in
## priority order: the first row whose test passes wins. Ordered most
## specific first, so a walled city on a river is a garrison rather than a
## fishing village.
const PURPOSE_RULES := [
	{"purpose": &"garrison", "built": ["marble-wall", "stone-wall"], "at": 0.5},
	{"purpose": &"pilgrim", "built": ["temple"], "at": 0.000001},
	{"purpose": &"mining", "built": ["forge-hall"], "at": 0.6},
	{"purpose": &"fishing", "water": true},
	{"purpose": &"forest", "forest": 0.5},
	{"purpose": &"market", "population": 300},
	{"purpose": &"farming"},
]

## Wealth in mythsim is unbounded; BrickWild's is 0..1. A thousand is a rich
## city, and everything past it is simply rich.
const WEALTH_FULL := 1000.0
const PALETTE_ORDER: Array[StringName] = [&"english", &"frankish", &"norse",
	&"alpine", &"moorish", &"eastern", &"blighted"]


## The `VillageSpec` a SiteRequest asks for. `raw` is the request's own text,
## used only for the seed -- see `_seed_of`. Anything the request asks for
## that BrickWild cannot yet build is written into `notes` and carried out to
## the consumer rather than silently swallowed.
static func spec_from_request(request: Dictionary, raw: String = "",
		notes: Array[String] = []) -> VillageSpec:
	var out := VillageSpec.new()
	var errors: Array[String] = request_errors(request)
	if not errors.is_empty():
		return out
	out.seed = _seed_of(request, raw)
	out.site_brief = true
	out.population = int(request.get("population", 40))
	out.implied_population = int(request.get("implied_population", 0))
	out.source_culture = StringName(String(request.get("culture", "english")).to_lower())
	out.tongue = StringName(String(request.get("tongue", "")).to_lower())
	out.culture = _culture_of(String(out.source_culture))
	out.regime = StringName(String(request.get("regime", "")).to_lower())
	out.wealth = clampf(float(request.get("wealth", 0.0)) / WEALTH_FULL, 0.0, 1.0)
	out.decoration_level = float(request.get("decoration_level", 0.5))
	out.upkeep = float(request.get("upkeep", 1.0))
	var terrain: Dictionary = request.get("terrain", {})
	out.terrain_envelope = terrain.duplicate(true)
	# the height grid is read into `spec.terrain`, never echoed: a 400 m site
	# at 1 m is 160 000 numbers
	if out.terrain_envelope.has("height"):
		out.terrain_envelope["height"] = "brickwild.terrain"
	out.requested_site_m = float(request.get("site_m", SITE_MAX_M))
	var built: Dictionary = request.get("buildings", {}).duplicate(true)
	for word in BUILT_WORDS:
		built[word] = float(built.get(word, 0.0))
	out.kept_buildings = built
	out.plant_palette = _plant_palette(String(out.source_culture), String(out.tongue))
	out.water = _water_of(terrain)
	out.purpose = _purpose_for_brief(built, terrain, out.population, out.regime)
	out.enclosure = _enclosure_of(built, out.civic_population(), out.regime)
	out.enclosure_kept_fraction = _enclosure_fraction(built)
	if out.enclosure == &"palisade" and _walled(built) > 0.0 and _walled(built) >= float(built["palisade"]):
		notes.append("the kept wall wants %d people or a military regime and the civic programme has %d; it is built as a palisade" % [
			VillageSpec.WALL_MIN_POPULATION, out.civic_population()])
	if out.implied_population > 0:
		notes.append("the civic programme (seat, walls, landmark, temples, monuments, halls, market) is sized for the implied %d people%s; homes and lots are for the %d shown" % [
			out.implied_population,
			" (civic scale stops at %d)" % VillageSpec.CIVIC_MAX if out.implied_population > VillageSpec.CIVIC_MAX else "",
			out.population])
	return out


## Reject a request when the bounded village planner cannot honor its stated
## population or terrain. Clamping makes a different city and hides failure.
static func request_errors(request: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if request.has("buildings") and not request["buildings"] is Dictionary:
		errors.append("buildings must be an object of kept fractions")
	if request.has("terrain") and not request["terrain"] is Dictionary:
		errors.append("terrain must be an envelope object")
	if not errors.is_empty():
		return errors
	var population_value: Variant = request.get("population", 40)
	if not _is_number(population_value):
		errors.append("population must be numeric")
		return errors
	var raw_population: float = float(population_value)
	var population: int = int(raw_population)
	if not is_equal_approx(raw_population, float(population)):
		errors.append("population must be a whole number")
	if population < VillageSpec.POP_MIN or population > VillageSpec.POP_MAX:
		errors.append("population %d exceeds local capacity [%d, %d]" % [population,
			VillageSpec.POP_MIN, VillageSpec.POP_MAX])
	for field in ["decoration_level", "upkeep"]:
		if not request.has(field):
			continue
		var value: Variant = request[field]
		if not _is_number(value) or not is_finite(float(value)):
			errors.append("%s must be a finite number" % field)
		elif float(value) < 0.0 or float(value) > 1.0:
			errors.append("%s %.3f is outside [0, 1]" % [field, float(value)])
	var site_value: Variant = request.get("site_m", SITE_MAX_M)
	if not _is_number(site_value):
		errors.append("site_m must be numeric")
		return errors
	var site_m: float = float(site_value)
	if site_m < VillageSitePlanner.SITE_MIN_SIDE or site_m > SITE_MAX_M:
		errors.append("site_m %.1f is outside the buildable envelope [%.0f, %.0f] m" % [
			site_m, VillageSitePlanner.SITE_MIN_SIDE, SITE_MAX_M])
	var terrain: Dictionary = request.get("terrain", {})
	for field in ["elevation", "forest", "fertility"]:
		if terrain.has(field):
			if not _is_number(terrain[field]):
				errors.append("terrain %s must be numeric" % field)
				continue
			var reading: float = float(terrain[field])
			if reading < 0.0 or reading > 1.0:
				errors.append("terrain %s %.3f is outside [0, 1]" % [field, reading])
	var slope_value: Variant = terrain.get("slope", 0.0)
	if not _is_number(slope_value):
		errors.append("terrain slope must be numeric")
		return errors
	var slope: float = float(slope_value)
	if slope < 0.0 or slope >= MAX_BUILDABLE_SLOPE:
		errors.append("terrain slope %.3f has no buildable village ground (maximum %.2f)" % [
			slope, MAX_BUILDABLE_SLOPE])
	var edges: Variant = terrain.get("water_edges", [])
	if not edges is Array:
		errors.append("terrain water_edges must be an array")
	else:
		var edge_list: Array = edges
		for edge in edge_list:
			if String(edge) not in ["north", "south", "east", "west"]:
				errors.append("unknown terrain water edge '%s'" % String(edge))
	var regime: String = String(request.get("regime", "" )).to_lower()
	if not regime.is_empty() and regime not in ["royal", "council", "theocracy", "military"]:
		errors.append("unknown regime '%s'" % regime)
	var built: Dictionary = request.get("buildings", {})
	for key in built:
		if String(key) not in BUILT_WORDS:
			errors.append("unknown authored building '%s'" % String(key))
			continue
		if not _is_number(built[key]):
			errors.append("building '%s' kept fraction must be numeric" % String(key))
			continue
		var kept: float = float(built[key])
		if kept < 0.0 or kept > 1.0:
			errors.append("building '%s' kept fraction %.3f is outside [0, 1]" % [String(key), kept])
	var implied_value: Variant = request.get("implied_population", 0)
	if not _is_number(implied_value) or float(implied_value) < 0.0 \
			or not is_equal_approx(float(implied_value), float(int(implied_value))):
		errors.append("implied_population must be a whole number of people")
	return errors


static func _is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT]


const MAX_BUILDABLE_SLOPE := 0.35


## Retained for callers that intentionally adapt a legacy spec into the
## historical street/green planner limits. C1 no longer calls this fallback:
## the brief keeps its population and regime or is explicitly refused.
static func _settle_form(spec: VillageSpec, notes: Array[String],
		wants_temple: bool) -> void:
	if spec.form in VillageSitePlanner.FORMS_SUPPORTED:
		return
	# 1. the population, if it is over the gate threshold. SCALED rather than
	# clamped: the contract's own acceptance is that building count rises
	# with population, and clamping 210, 300 and 420 all to 199 gave three
	# identical villages.
	if spec.population >= GATE_POPULATION:
		var was_pop: int = spec.population
		var was_form: StringName = spec.form
		spec.population = _below_gate(was_pop)
		_settle_enclosure(spec, notes)
		spec.generate(spec.seed)
		notes.append("%d people derives the '%s' form (VILLAGES 3), which has no planner yet; planned at %d"
			% [was_pop, String(was_form), spec.population])
		if spec.form in VillageSitePlanner.FORMS_SUPPORTED:
			return
	# 2. the purpose, through the ones that DO reach a form BrickWild lays,
	# in a fixed order so the same request always lands the same way
	var was_purpose: StringName = spec.purpose
	var unplanned: StringName = spec.form
	for substitute in PURPOSE_FALLBACKS:
		if substitute == spec.purpose:
			continue
		# `pilgrim` is the one purpose that EARNS a building -- a temple in
		# place of the church -- so it is never substituted into a city that
		# did not build one. The contract's own acceptance is that a city
		# with `temple` gets a temple and a city without does not, and a
		# forest hamlet quietly re-planned as a pilgrim village got one.
		if substitute == &"pilgrim" and not wants_temple:
			continue
		spec.purpose = substitute
		_settle_enclosure(spec, notes)
		spec.generate(spec.seed)
		if spec.form in VillageSitePlanner.FORMS_SUPPORTED:
			notes.append("a '%s' village of %d derives the '%s' form, which has no planner yet; planned as '%s'"
				% [String(was_purpose), spec.population, String(unplanned), String(substitute)])
			return
	spec.purpose = was_purpose
	spec.generate(spec.seed)


## With ground, the spec derives its form from the land
## (VillageSpec._derive_form_on_ground); a form with no planner yet is planned
## as its VillageSpec.FORM_FALLBACK, and this says so, as _settle_form says
## when it changes a form. "" when the planned form is the derived one.
static func form_intent_note(spec: VillageSpec) -> String:
	if spec.terrain == null or spec.form_intent == spec.form or spec.form_intent == &"":
		return ""
	return "the ground derives the '%s' form, which has no planner yet; planned as '%s' (form_intent keeps '%s')" % [
		String(spec.form_intent), String(spec.form), String(spec.form_intent)]


## The population at which VillageSpec.FORMS forces the `gate` row.
const GATE_POPULATION := 200
## What is left of a bigger city once it is planned as a village. Anything at
## or over the gate threshold is mapped onto this band, so a city of 420 is
## still a bigger village than one of 210.
const PLANNED_BAND := Vector2(140.0, 199.0)
## Purposes to try, in order, when the one asked for has no planner. Between
## them they cover both forms BrickWild lays: `green` (farming or pilgrim, 40
## to 200) and `street` (farming, forest or mining, 12 to 80).
const PURPOSE_FALLBACKS: Array[StringName] = [&"farming", &"mining", &"forest", &"pilgrim"]


## A wall needs the people to build and man it. Planning a city of four
## hundred as a village of a hundred and eighty takes those people away, and
## `VillageSpec` refuses the spec rather than quietly dropping the wall -- so
## the wall is dropped HERE, in the open, where it can be written down.
static func _settle_enclosure(spec: VillageSpec, notes: Array[String]) -> void:
	if spec.enclosure != &"wall":
		return
	if spec.population >= VillageSpec.WALL_MIN_POPULATION or spec.purpose == &"garrison":
		return
	spec.enclosure = &"palisade"
	notes.append("a wall wants %d people and the village is planned at %d; enclosed with a palisade"
		% [VillageSpec.WALL_MIN_POPULATION, spec.population])


static func _below_gate(population: int) -> int:
	var t: float = float(clampi(population, GATE_POPULATION, VillageSpec.POP_MAX)
			- GATE_POPULATION) / float(VillageSpec.POP_MAX - GATE_POPULATION)
	return int(round(lerpf(PLANNED_BAND.x, PLANNED_BAND.y, t)))


## The seed, taken from the request TEXT and not from the parsed number.
##
## mythsim seeds are unsigned 64-bit -- the contract's own example is
## 12297829382473034410, which is past what an int64 holds, so JSON gives it
## back as a double and two runs could round it differently. The digits
## themselves are exact, so they are what is hashed, and the result is the
## same on every machine.
static func _seed_of(request: Dictionary, raw: String) -> int:
	var digits: String = _seed_text(raw)
	if digits.is_empty():
		digits = str(request.get("seed", 0))
	return hash("%s|%s" % [String(request.get("city_id", "")), digits])


## The seed field's digits, lifted out of the request text before any parse.
static func _seed_text(raw: String) -> String:
	var re := RegEx.new()
	re.compile('"seed"\\s*:\\s*(-?[0-9]+)')
	var m: RegExMatch = re.search(raw)
	return m.get_string(1) if m != null else ""


static func _culture_of(name: String) -> StringName:
	var key: String = name.to_lower()
	if CULTURE_MAP.has(key):
		return CULTURE_MAP[key]
	if StringName(key) in VillageSpec.CULTURES:
		return StringName(key)
	var list: Array[StringName] = VillageSpec.CULTURES
	return list[absi(hash(key)) % list.size()]


static func _water_of(terrain: Dictionary) -> StringName:
	var edges: Array = terrain.get("water_edges", [])
	if edges.is_empty():
		return &"none"
	# a city on more than one water edge stands on a river through it; on one,
	# the water is a shore
	return &"river" if edges.size() > 1 else &"coast"


static func _purpose_of(built: Dictionary, terrain: Dictionary, population: int) -> StringName:
	# Native callers have no government regime to apply.
	return _purpose_for_brief(built, terrain, population, &"")


static func _purpose_for_brief(built: Dictionary, terrain: Dictionary, population: int,
		regime: StringName) -> StringName:
	if regime == &"military":
		return &"garrison"
	if regime == &"council":
		return &"market"
	if regime == &"theocracy" and float(built.get("temple", 0.0)) > 0.0:
		return &"pilgrim"
	for rule in PURPOSE_RULES:
		if rule.has("built"):
			var got := false
			for word in rule["built"]:
				if float(built.get(word, 0.0)) >= float(rule["at"]):
					got = true
			if not got:
				continue
		if rule.has("water") and (terrain.get("water_edges", []) as Array).is_empty():
			continue
		if rule.has("forest") and float(terrain.get("forest", 0.0)) < float(rule["forest"]):
			continue
		if rule.has("population") and population < int(rule["population"]):
			continue
		return rule["purpose"]
	return &"farming"


static func _plant_palette(culture: String, tongue: String) -> StringName:
	var cultural: StringName = _culture_of(culture)
	var linguistic: StringName = cultural if tongue.is_empty() else _culture_of(tongue)
	var a: int = PALETTE_ORDER.find(cultural)
	var b: int = PALETTE_ORDER.find(linguistic)
	return PALETTE_ORDER[posmod(a * 2 + b, PALETTE_ORDER.size())]


## What is round the edge, from what the city has built. A wall needs the
## people to build and man it (`VillageSpec.WALL_MIN_POPULATION`, counting the
## implied people) or a military regime to supply them; a city with fewer
## keeps a palisade, the light enclosure, rather than being refused (owner
## decision 2026-10-10). A wall kept as fully as the palisade is the wall.
static func _enclosure_of(built: Dictionary, people: int, regime: StringName) -> StringName:
	var walled: float = _walled(built)
	var palisade: float = float(built.get("palisade", 0.0))
	if walled > 0.0 and walled >= palisade:
		if people >= VillageSpec.WALL_MIN_POPULATION or regime == &"military":
			return &"wall"
		return &"palisade"
	if palisade > 0.0:
		return &"palisade"
	return &"none"


static func _walled(built: Dictionary) -> float:
	return maxf(float(built.get("marble-wall", 0.0)), float(built.get("stone-wall", 0.0)))


static func _enclosure_fraction(built: Dictionary) -> float:
	return maxf(float(built.get("palisade", 0.0)), maxf(float(built.get("stone-wall", 0.0)),
		float(built.get("marble-wall", 0.0))))


# ---------------------------------------------------------- plan -> JSON

## The SitePlan, in the contract's own shape and key order.
static func site_plan(plan: VillagePlan, request: Dictionary) -> Dictionary:
	var city_id: String = String(request.get("city_id", "site:unknown"))
	var out := {
		"schema": OUT_SCHEMA,
		"schema_version": OUT_SCHEMA_VERSION,
		"city_id": city_id,
		"seed": str(request.get("seed", 0)),
		"generator": GENERATOR,
		"name": String(request.get("name", plan.spec.variant_name)),
		"local_name": plan.spec.variant_name,
		"culture_source": String(plan.spec.source_culture),
		"tongue": String(plan.spec.tongue),
		"regime": String(plan.spec.regime),
		"plant_palette": String(plan.spec.plant_palette),
		"enclosure_kept_fraction": _n(plan.spec.enclosure_kept_fraction),
		"authored_buildings": plan.spec.kept_buildings.duplicate(true),
		"terrain": plan.spec.terrain_envelope.duplicate(true),
		"site_m_requested": _n(plan.spec.requested_site_m),
		# what was asked for, alongside what was planned, so a consumer can
		# see the difference without re-reading its own request
		"population_asked": int(request.get("population", 0)),
		"population_planned": plan.spec.population,
		"culture": String(plan.spec.culture),
		"purpose": String(plan.spec.purpose),
		"form": String(plan.spec.form),
		"enclosure": String(plan.spec.enclosure),
		"decoration_level": _n(plan.spec.decoration_level),
		"upkeep": _n(plan.spec.upkeep),
		"site": {
			"width_m": _n(minf(plan.site.size.x, SITE_MAX_M)),
			"depth_m": _n(minf(plan.site.size.y, SITE_MAX_M)),
			"origin": "site centre",
			"axes": "+X east, +Z south",
		},
		"roads": _roads(plan),
		"lots": _lots(plan),
		"commons": _polys(plan.commons, "kind"),
		"water": _polys(plan.water, "kind"),
		"fields": _polys(plan.fields, "kind"),
		"props": _props(plan),
		"buildings": _buildings(plan, city_id, request.has("implied_population")),
		"walk": VillageWalk.projection(plan, city_id),
	}
	if request.has("implied_population"):
		out["population_implied"] = plan.spec.implied_population
		out["population_civic"] = plan.spec.civic_population()
	if plan.spec.terrain != null:
		# the form the ground derived, beside the form planned; only with
		# ground, so a flat request's bytes never change
		out["form_intent"] = String(plan.spec.form_intent)
		_add_ground(out, plan)
	return out


## The ground the caller gave, read under everything the plan placed. Only
## called with terrain, so a flat request's bytes never change.
static func _add_ground(out: Dictionary, plan: VillagePlan) -> void:
	var t: VillageTerrain = plan.spec.terrain
	out["ground"] = {"schema": VillageTerrain.SCHEMA, "schema_version": VillageTerrain.SCHEMA_VERSION,
		"source": t.source, "origin_m": [_n(t.origin.x), _n(t.origin.y)], "cell_m": _n(t.cell_m),
		"cols": t.cols, "rows": t.rows, "min_m": _n(t.min_height()), "max_m": _n(t.max_height()),
		"relief_m": _n(t.relief()), "site": _ground(t.under(_rect_poly(plan.site))),
		"water_level_m": null if is_nan(t.water_level_m) else _n(t.water_level_m),
		"fingerprint": t.fingerprint()}
	for i in range(plan.lots.size()):
		out["lots"][i]["ground"] = _ground(t.under(plan.lots[i]["poly"]))
	for i in range(plan.buildings.size()):
		var b: Dictionary = plan.buildings[i]
		var corners: PackedVector2Array = Placement.world_rect(b["placement"], b["transform"], true)
		var g: Dictionary = _ground(t.under(corners))
		var door: Vector3 = b["door"]
		g["door_m"] = _n(t.height_at(Vector2(door.x, door.z)))
		out["buildings"][i]["ground"] = g
	for r in range(plan.roads.size()):
		var pts: PackedVector2Array = plan.roads[r]["points"]
		var pr: Dictionary = t.profile(pts)
		var at: Array = []
		for p in pts:
			at.append(_n(t.height_at(p)))
		out["roads"][r]["ground"] = {"points_m": at, "length_m": _n(pr["length_m"]),
			"rise_m": _n(pr["rise_m"]), "fall_m": _n(pr["fall_m"]), "grade_max": _n(pr["grade_max"])}
	for i in range(plan.commons.size()):
		out["commons"][i]["ground"] = _ground(t.under(plan.commons[i]["poly"]))


## One `under()` reading, snapped.
static func _ground(u: Dictionary) -> Dictionary:
	if u.is_empty():
		return {}
	return {"min_m": _n(u["min_m"]), "max_m": _n(u["max_m"]), "mean_m": _n(u["mean_m"]),
		"span_m": _n(u["span_m"]), "slope_max": _n(u["slope_max"]), "slope_mean": _n(u["slope_mean"]),
		"dry_share": _n(u["dry_share"]),
		"low_m": [_n(u["low_m"][0]), _n(u["low_m"][1])], "high_m": [_n(u["high_m"][0]), _n(u["high_m"][1])]}


## The ground under a building larger than this is called out in the notes.
const GROUND_FALL_NOTE_M := 1.5


## Where the flat plan and the given ground disagree most, in one line.
static func ground_note(out: Dictionary) -> String:
	var steep := 0
	var worst := 0.0
	var worst_id := ""
	for b in out["buildings"]:
		var span: float = float(b["ground"].get("span_m", 0.0))
		if span > GROUND_FALL_NOTE_M:
			steep += 1
		if span > worst:
			worst = span
			worst_id = String(b["building_id"])
	return "terrain: %.1f m of relief under the site; %d of %d buildings stand on more than %.1f m of fall (most: %s, %.1f m). The plan is laid out flat; buildings[].ground says where to cut, fill or step" % [
		float(out["ground"]["site"].get("span_m", 0.0)), steep, (out["buildings"] as Array).size(),
		GROUND_FALL_NOTE_M, worst_id, worst]


## The request's ground, or null for none. `--terrain` wins over the request's
## own `terrain.height`; a relative path is read beside the request.
static func terrain_from_request(request: Dictionary, base_dir: String, terrain_arg: String) -> VillageTerrain:
	if not terrain_arg.is_empty():
		return VillageTerrain.from_file(terrain_arg)
	var terrain: Variant = request.get("terrain", {})
	if not terrain is Dictionary or not (terrain as Dictionary).has("height"):
		return null
	var h: Variant = terrain["height"]
	if h is Dictionary:
		return VillageTerrain.from_dict(h, base_dir)
	if h is String:
		var path: String = h
		if path.is_relative_path() and not base_dir.is_empty():
			path = base_dir.path_join(path)
		return VillageTerrain.from_file(path)
	# neither a grid nor a path: from_dict names what is wrong
	return VillageTerrain.from_dict({})


static func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func _roads(plan: VillagePlan) -> Array:
	var out: Array = []
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		out.append({
			"road_id": "%s-%03d" % [String(road["class"]), r],
			"class": String(road["class"]),
			"points_m": _points(road["points"]),
			"width_m": _n(float(road["width"])),
			"verge_m": _n(float(road["verge"])),
		})
	return out


static func _lots(plan: VillagePlan) -> Array:
	var out: Array = []
	for i in range(plan.lots.size()):
		var lot: Dictionary = plan.lots[i]
		var road: int = int(lot["road"])
		out.append({
			"lot_id": "l-%03d" % i,
			"rect_m": _rect(Poly.bounding_rect(lot["poly"])),
			"poly_m": _points(lot["poly"]),
			"road_id": _road_id(plan, road),
			"class": String(lot.get("class", &"")),
			"landmark": bool(lot.get("landmark", false)),
		})
	return out


## Every building, with the join key C2 and C4 hang off. `rect_m` is the
## MEASURED footprint in world space -- the walls' own outline, turned onto
## its lot -- not the envelope the request asked for.
static func _buildings(plan: VillagePlan, city_id: String, implied := false) -> Array:
	var out: Array = []
	for i in range(plan.buildings.size()):
		var b: Dictionary = plan.buildings[i]
		var req: BuildingRequest = b["request"]
		var xf: Transform3D = b["transform"]
		var corners: PackedVector2Array = Placement.world_rect(b["placement"], xf, true)
		var front: Vector3 = xf.basis * Vector3(0.0, 0.0, -1.0)
		var door: Vector3 = b["door"]
		var row := {
			"building_id": "%s/b-%03d" % [city_id, i],
			"request": req.to_dict(),
			"transform": {"origin": [xf.origin.x, xf.origin.y, xf.origin.z],
				"basis": [[xf.basis.x.x, xf.basis.x.y, xf.basis.x.z],
					[xf.basis.y.x, xf.basis.y.y, xf.basis.y.z],
					[xf.basis.z.x, xf.basis.z.y, xf.basis.z.z]]},
			"kind": String(req.kind),
			"trade": String(req.purpose) if req.purpose != &"" else null,
			"style": String(req.style),
			"lot_id": "l-%03d" % int(b["lot"]),
			"rect_m": _rect(Poly.bounding_rect(corners)),
			"poly_m": _points(corners),
			"front": [_n(front.x), _n(front.z)],
			"door_m": [_n(door.x), _n(door.z)],
			"storeys": req.storeys,
		}
		var monument: String = VillageProgrammer.monument_of(plan.spec, req)
		if not monument.is_empty():
			row["monument"] = monument
		if implied:
			row["serves"] = VillageProgrammer.serves(plan.spec, req)
		out.append(row)
	return out


static func _props(plan: VillagePlan) -> Array:
	var out: Array = []
	for p in plan.props:
		out.append({
			"key": String(p["key"]),
			"pos_m": [_n(float(p["pos"].x)), _n(float(p["pos"].y))],
			"yaw": _n(float(p.get("yaw", 0.0))),
		})
	return out


## The commons, the water and the fields all have the same shape: a polygon
## and what it is.
static func _polys(list: Array[Dictionary], kind_key: String) -> Array:
	var out: Array = []
	for row in list:
		out.append({
			"kind": String(row.get(kind_key, &"")),
			"rect_m": _rect(Poly.bounding_rect(row["poly"])),
			"poly_m": _points(row["poly"]),
		})
	return out


static func _road_id(plan: VillagePlan, r: int) -> Variant:
	if r < 0 or r >= plan.roads.size():
		return null
	return "%s-%03d" % [String(plan.roads[r]["class"]), r]


static func _points(poly: PackedVector2Array) -> Array:
	var out: Array = []
	for p in poly:
		out.append([_n(p.x), _n(p.y)])
	return out


static func _rect(r: Rect2) -> Array:
	return [_n(r.position.x), _n(r.position.y), _n(r.size.x), _n(r.size.y)]


## Every number that leaves this file goes through here. Snapping is not
## cosmetic: the acceptance criterion is byte-identical output on two
## machines, and the last few digits of a double are exactly where two
## machines stop agreeing.
static func _n(v: float) -> float:
	return snappedf(v, PLACES)


# ------------------------------------------------------------- plumbing

static func _options(args: PackedStringArray) -> Dictionary:
	var out := {}
	var i := 0
	while i < args.size():
		var a: String = args[i]
		if a.begins_with("--") and i + 1 < args.size():
			out[a.substr(2)] = args[i + 1]
			i += 2
			continue
		i += 1
	return out


static func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text
