class_name VillageFormsSuite
extends RefCounted
## VIL-017: the five remaining §3 settlement forms.  Each form is swept over
## fifty seeds at its own table row, then one measured lot plan is sent through
## the four placement checks.  The site sweep is intentionally separate from
## the lot sample: it makes a form's road/common invariant cheap to diagnose,
## while the sample still proves doors and windows sit on measured buildings.

const SEEDS := 50

static func run() -> SuiteResult:
	var res := SuiteResult.new("vforms")
	for c in _cases():
		_check_site_sweep(res, c)
		_check_full_sample(res, c)
	return res


static func _cases() -> Array[Dictionary]:
	return [
		{"name": &"crossroads", "population": 80, "purpose": &"crossroads",
			"culture": &"english", "water": &"none"},
		{"name": &"round", "population": 60, "purpose": &"forest",
			"culture": &"blighted", "water": &"none"},
		{"name": &"strand", "population": 70, "purpose": &"fishing",
			"culture": &"english", "water": &"coast"},
		{"name": &"planted", "population": 150, "purpose": &"market",
			"culture": &"english", "water": &"none"},
		{"name": &"gate", "population": 200, "purpose": &"garrison",
			"culture": &"english", "water": &"none"},
	]


static func _spec(seed: int, c: Dictionary) -> VillageSpec:
	var spec := VillageSpec.new(seed)
	spec.population = int(c["population"])
	spec.purpose = c["purpose"]
	spec.culture = c["culture"]
	spec.water = c["water"]
	spec.wealth = 0.8 if c["name"] == &"planted" else 0.4
	spec.enclosure = &"none"
	spec.generate(seed)
	return spec


static func _check_site_sweep(res: SuiteResult, c: Dictionary) -> void:
	var failures := 0
	for seed in range(SEEDS):
		var spec := _spec(seed, c)
		var plan := VillageSitePlanner.plan(spec)
		var problems := _site_problems(plan, spec, c["name"])
		res.checked += 1
		if not problems.is_empty():
			failures += 1
			if failures <= 3:
				res.fail("%s seed %d: %s" % [c["name"], seed, "; ".join(problems)])
	res.note("%s: %d seeds, %d clean" % [c["name"], SEEDS, SEEDS - failures])


static func _site_problems(plan: VillagePlan, spec: VillageSpec,
		form: StringName) -> Array[String]:
	var out: Array[String] = []
	if spec.form != form:
		out.append("derived form is %s" % spec.form)
	if plan.roads.is_empty() or plan.commons.size() != 1:
		out.append("roads=%d commons=%d" % [plan.roads.size(), plan.commons.size()])
	if plan.site.size.x > 400.0 or plan.site.size.y > 400.0:
		out.append("site exceeds 400m")
	if not plan.commons.is_empty() and Poly.area(plan.commons[0]["poly"]) < 150.0:
		out.append("common below 150m2")
	for road in plan.roads:
		var cls: StringName = road["class"]
		if not VillageSitePlanner.ROAD_CLASSES.has(cls):
			out.append("unknown road class %s" % cls)
	if form == &"crossroads":
		if plan.roads_of_class(&"through").size() != 2:
			out.append("crossroads needs two through roads")
		elif VillageSitePlanner.road_components(plan) != 1:
			out.append("crossroads roads are disconnected")
		elif VillageSitePlanner.junctions(plan).is_empty():
			out.append("crossroads has no junction")
	if form == &"round":
		if plan.commons[0]["poly"].size() < 12:
			out.append("round common is not polygonal")
		if plan.roads_of_class(&"lane").size() != 1:
			out.append("round site has %d authored lanes" % plan.roads_of_class(&"lane").size())
	if form == &"strand":
		if spec.water != &"coast" or plan.water.size() != 1:
			out.append("strand has no coast water")
		elif plan.roads_of_class(&"through").is_empty():
			out.append("strand has no road behind shore")
	if form == &"planted":
		if plan.commons[0]["kind"] != &"square" or Poly.area(plan.commons[0]["poly"]) < 400.0:
			out.append("planted square is below 400m2")
		if plan.roads_of_class(&"street").size() < 2:
			out.append("planted grid has fewer than two streets")
	if form == &"gate" and plan.roads_of_class(&"through").size() != 1:
		out.append("gate needs one through road")
	return out


static func _check_full_sample(res: SuiteResult, c: Dictionary) -> void:
	var spec := _spec(17017 + int(c["population"]), c)
	var plan := VillageLotPlanner.plan(spec)
	var no_pure := func(_plan: VillagePlan) -> Array: return []
	var reports := [
		["scale", VillageScaleCheck.new().check(plan, {&"pure": no_pure})],
		["road", VillageRoadCheck.new().check(plan)],
		["lot", VillageLotCheck.new().check(plan)],
		["place", VillagePlaceCheck.new().check(plan)],
	]
	for row in reports:
		res.checked += 1
		if not row[1]["ok"]:
			res.fail("%s sample %s: %s" % [c["name"], row[0], "; ".join(row[1]["failures"])])
