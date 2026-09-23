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
## Two things the contract asks for that BigGlade did not already have:
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
## Scope, deliberately: no mesh, no props-as-geometry, no assets. This is the
## plan, not the build.

const OUT_SCHEMA := "dmv.site.plan"
const OUT_SCHEMA_VERSION := 1
const GENERATOR := "bigglade-0.3"
## Everything is written to this many decimal places, and nothing is written
## at more. A millimetre is far below anything a village plan means, and it
## is what makes two runs byte-identical.
const PLACES := 0.001

## The site is capped at BigGlade's own maximum however big a cell is.
const SITE_MAX_M := 400.0


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var opts: Dictionary = _options(args)
	if not opts.has("request") or not opts.has("out"):
		printerr("usage: --request <in.json> --out <out.json>")
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
	var request: Dictionary = parsed
	var notes: Array[String] = []
	var spec: VillageSpec = spec_from_request(request, text, notes)
	if not spec.valid():
		printerr("SiteRequest does not map to a village: %s" % ", ".join(spec.errors()))
		quit(3)
		return
	spec.generate(spec.seed)
	_settle_form(spec, notes, _wants_temple(request.get("buildings", {})))
	var plan: VillagePlan = VillageLotPlanner.plan(spec)
	if plan.roads.is_empty():
		printerr("no plan: form '%s' is not one BigGlade lays yet" % String(spec.form))
		quit(3)
		return
	var out: Dictionary = site_plan(plan, request)
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


# ------------------------------------------------------- request -> spec

## mythsim's ten authored words for what a city has built. `buildings` in the
## request is a kept FRACTION against each of them -- it says what the city
## has, never how many or where, and turning that into instances is
## BigGlade's half of the contract.
const BUILT_WORDS := ["palisade", "granary", "stone-wall", "shrine", "temple",
	"palace", "forge-hall", "great-tomb", "marble-wall", "ziggurat"]

## mythsim's cultures are its own; BigGlade's seven are the palettes it can
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
	{"purpose": &"pilgrim", "built": ["ziggurat", "temple", "great-tomb"], "at": 0.6},
	{"purpose": &"mining", "built": ["forge-hall"], "at": 0.6},
	{"purpose": &"fishing", "water": true},
	{"purpose": &"forest", "forest": 0.5},
	{"purpose": &"market", "population": 300},
	{"purpose": &"farming"},
]

## Did the city build something a temple would stand for? The `pilgrim`
## purpose is the only one that puts a temple in the programme, so this is
## what decides whether it may be substituted in.
static func _wants_temple(built: Dictionary) -> bool:
	for word in ["ziggurat", "temple", "great-tomb", "shrine"]:
		if float(built.get(word, 0.0)) >= 0.3:
			return true
	return false


## Wealth in mythsim is unbounded; BigGlade's is 0..1. A thousand is a rich
## city, and everything past it is simply rich.
const WEALTH_FULL := 1000.0


## The `VillageSpec` a SiteRequest asks for. `raw` is the request's own text,
## used only for the seed -- see `_seed_of`. Anything the request asks for
## that BigGlade cannot yet build is written into `notes` and carried out to
## the consumer rather than silently swallowed.
static func spec_from_request(request: Dictionary, raw: String = "",
		notes: Array[String] = []) -> VillageSpec:
	var out := VillageSpec.new()
	out.seed = _seed_of(request, raw)
	# mythsim counts a city in thousands; a BigGlade site is at most 500
	# people, and the contract's "building count rises with population and
	# never exceeds 140" is what the cap is for.
	var asked: int = int(request.get("population", 40))
	out.population = clampi(asked, VillageSpec.POP_MIN, VillageSpec.POP_MAX)
	if out.population != asked:
		notes.append("population %d is outside a BigGlade site's range; planned at %d"
			% [asked, out.population])
	out.culture = _culture_of(String(request.get("culture", "")))
	out.wealth = clampf(float(request.get("wealth", 0.0)) / WEALTH_FULL, 0.0, 1.0)
	var terrain: Dictionary = request.get("terrain", {})
	var built: Dictionary = request.get("buildings", {})
	out.water = _water_of(terrain)
	out.purpose = _purpose_of(built, terrain, out.population)
	out.enclosure = _enclosure_of(built, out.population, out.purpose)
	return out


## Two of VILLAGES §3's seven forms have planners (VIL-003): `street` and
## `green`. Everything else -- `gate`, `strand`, `planted`, `crossroads`,
## `round` -- is still to come, and a spec that derives one of them plans
## nothing at all.
##
## Rather than write an empty SitePlan, this steps the spec toward a form
## BigGlade can lay and SAYS SO in the plan's `notes`. Both concessions are
## the form table's own thresholds read backwards:
##   * two hundred people or more is a gate village whatever else it is
##   * only farming, pilgrim, forest and mining reach `street` or `green`;
##     garrison, market, crossroads, fishing and mill do not
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
	# 2. the purpose, through the ones that DO reach a form BigGlade lays,
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


## The population at which VillageSpec.FORMS forces the `gate` row.
const GATE_POPULATION := 200
## What is left of a bigger city once it is planned as a village. Anything at
## or over the gate threshold is mapped onto this band, so a city of 420 is
## still a bigger village than one of 210.
const PLANNED_BAND := Vector2(140.0, 199.0)
## Purposes to try, in order, when the one asked for has no planner. Between
## them they cover both forms BigGlade lays: `green` (farming or pilgrim, 40
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


## What is round the edge, from what the city has built. A wall needs the
## people to build and man it (`VillageSpec.WALL_MIN_POPULATION`) or a
## garrison to supply them, so a city that has one but is now too small for
## it keeps a palisade instead of an invalid spec.
static func _enclosure_of(built: Dictionary, population: int, purpose: StringName) -> StringName:
	var walled: float = maxf(float(built.get("marble-wall", 0.0)),
		float(built.get("stone-wall", 0.0)))
	if walled >= 0.3:
		if population >= VillageSpec.WALL_MIN_POPULATION or purpose == &"garrison":
			return &"wall"
		return &"palisade"
	if float(built.get("palisade", 0.0)) >= 0.3:
		return &"palisade"
	return &"none"


# ---------------------------------------------------------- plan -> JSON

## The SitePlan, in the contract's own shape and key order.
static func site_plan(plan: VillagePlan, request: Dictionary) -> Dictionary:
	var city_id: String = String(request.get("city_id", "site:unknown"))
	return {
		"schema": OUT_SCHEMA,
		"schema_version": OUT_SCHEMA_VERSION,
		"city_id": city_id,
		"seed": str(request.get("seed", 0)),
		"generator": GENERATOR,
		# what was asked for, alongside what was planned, so a consumer can
		# see the difference without re-reading its own request
		"population_asked": int(request.get("population", 0)),
		"population_planned": plan.spec.population,
		"culture": String(plan.spec.culture),
		"purpose": String(plan.spec.purpose),
		"form": String(plan.spec.form),
		"enclosure": String(plan.spec.enclosure),
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
		"buildings": _buildings(plan, city_id),
	}


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
static func _buildings(plan: VillagePlan, city_id: String) -> Array:
	var out: Array = []
	for i in range(plan.buildings.size()):
		var b: Dictionary = plan.buildings[i]
		var req: BuildingRequest = b["request"]
		var xf: Transform3D = b["transform"]
		var corners: PackedVector2Array = Placement.world_rect(b["placement"], xf, true)
		var front: Vector3 = xf.basis * Vector3(0.0, 0.0, -1.0)
		var door: Vector3 = b["door"]
		out.append({
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
		})
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
