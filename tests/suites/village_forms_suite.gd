class_name VillageFormsSuite
extends RefCounted
## VIL-017: the five remaining §3 settlement forms.  Each form is swept over
## fifty site seeds at its own table row, then one measured lot plan is sent
## through the six village checks. The site sweep is intentionally separate from
## the lot sample: it makes a form's road/common invariant cheap to diagnose,
## while the sample still proves doors and windows sit on measured buildings.
## run_full() is the separate fifty-measured-plans-per-form acceptance matrix.

const SEEDS := 50

static func run() -> SuiteResult:
	var res := SuiteResult.new("vforms")
	_check_planted_regressions(res)
	_check_courtyard_approach(res)
	_check_round_fan(res)
	_check_lane_reach(res)
	_check_street_common(res)
	_check_well_plants(res)
	for c in _cases():
		_check_site_sweep(res, c)
		_check_full_sample(res, c)
	return res


## Fast semantic regression pass while an actual measured-building sweep is
## running. It exercises the same rules; it is not the full VIL-017 gate.
static func run_layout() -> SuiteResult:
	var res := SuiteResult.new("vforms layout")
	_check_planted_regressions(res)
	_check_courtyard_approach(res)
	_check_round_fan(res)
	_check_lane_reach(res)
	_check_street_common(res)
	_check_well_plants(res)
	for c in _cases():
		_check_site_sweep(res, c)
	return res


static func _check_well_plants(res: SuiteResult) -> void:
	# A ground palette may contain a boulder as broad as a tree. Both must
	# leave working room at the actual well, including when it used a
	# fallback position away from the common's geometric centre.
	for key in ["Nature_MapleTree_1", "Wild_Rock_Medium_1"]:
		var plan := VillagePlan.new(VillageSpec.new(17))
		plan.site = Rect2(-20,-20,40,40)
		plan.commons.append({"poly": Poly.from_rect(Rect2(-10,-10,20,20))})
		plan.props.append({"key":"well","pos":Vector2(1,1),"rect":Rect2(0,0,2,2),"built":true})
		var ctx := VillageDresser._context(plan)
		var rng := RandomNumberGenerator.new()
		rng.seed = 17
		res.checked += 1
		if VillageDresser._place(plan,ctx,{"plant":true},key,Vector2(4.9,1),rng,-1):
			res.fail("%s placed inside actual well's four-metre working area" % key)
		res.checked += 1
		if not VillageDresser._place(plan,ctx,{"plant":true},key,Vector2(5.1,1),rng,-1):
			res.fail("%s rejected outside actual well's clear working area" % key)
		var check := VillageDressCheck.new()
		check._check_green(plan)
		res.checked += 1
		if not check.failures.is_empty(): res.fail("legal well planting failed independent green check")


static func _check_street_common(res: SuiteResult) -> void:
	for seed_index in 3:
		for scale in [0.7, 1.0, 1.4]:
			var spec := VillageSpec.new(VillageArchetypeSuite._seed_for(&"mine_camp", seed_index, scale))
			spec.population = int(round(70.0 * scale))
			spec.purpose = &"mining"
			spec.culture = &"norse"
			spec.wealth = 0.6
			spec.generate(spec.seed)
			var plan := VillageSitePlanner.plan(spec)
			VillageDresser._dress_place(plan, VillageDresser._context(plan), &"common")
			var nav := VillageNavCheck.new().check(plan)
			res.checked += 1
			for failure in nav["failures"]:
				if String(failure).begins_with("use:") or String(failure).begins_with("paths:"):
					res.fail("street well approach seed%d/%s: %s" % [seed_index, scale, failure])
			var place := VillagePlaceCheck.new()
			place._check_well(plan)
			res.checked += 1
			if not place.failures.is_empty():
				res.fail("street well approach: " + "; ".join(place.failures))


static func _check_lane_reach(res: SuiteResult) -> void:
	var spec := VillageSpec.new(2)
	spec.population = 70
	spec.purpose = &"mining"
	spec.generate(2)
	var plan := VillagePlan.new(spec)
	plan.site = Rect2(-60, -60, 120, 120)
	plan.roads.append(VillageSitePlanner._road(PackedVector2Array([Vector2(-60, -30), Vector2(60, -30)]), &"through", 0.6))
	plan.roads.append(VillageSitePlanner._road(PackedVector2Array([Vector2(0, -30), Vector2(0, 0)]), &"lane", 0.6))
	var job := VillageLotPlanner.measure(BuildingRequest.shop(4268721710, &"stable", &"farmhouse", 11.0, 14.0, 2.8, 1))
	job["class"] = &"shop"
	var rule: Dictionary = VillageLotPlanner.LOT_RULES[&"shop"]
	var gap := VillageLotPlanner.fire_gap(&"shop", spec, job["placement"])
	var frontage := float(job["half_w"]) * 2.0 + maxf(gap, 1.0)
	var setback := VillageLotPlanner._setback(rule, job)
	var depth := setback + float(job["back"]) + float(rule["yard"])
	var ctx := VillageLotPlanner._context(plan)
	for edge in ctx["edges"]:
		if int(edge["road"]) != 1 or float(edge["side"]) < 0: continue
		var beyond := VillageLotPlanner._make_lot(edge, 30.0 + absf(float(job["placement"]["door"].x)), frontage, depth, setback)
		res.checked += 1
		if VillageLotPlanner._lot_is_legal(plan, ctx, beyond, job, gap):
			res.fail("isolated lane accepts an entrance beyond its end")
		var reached := VillageLotPlanner._make_lot(edge, 29.5 - frontage * 0.5, frontage, depth, setback)
		res.checked += 1
		if not VillageLotPlanner._lot_is_legal(plan, ctx, reached, job, gap):
			res.fail("isolated lane rejects a reached stable entrance")
		return
	res.fail("lane reach fixture has no candidate edge")


## The task's acceptance matrix uses fifty ACTUAL planned villages per form.
## Keep it explicit: the quick site sweep and one sample do not stand in for
## this expensive measured-building run. Optional form selection allows the
## same strict matrix to be split across background runs.
static func run_full(selected: StringName = &"") -> SuiteResult:
	var res := SuiteResult.new("vforms full")
	for c in _cases():
		if selected != &"" and c["name"] != selected:
			continue
		for seed in range(SEEDS):
			print("VFORMS FULL START ", c["name"], " seed=", seed)
			var before := res.failures.size()
			_check_full_sample(res, c, seed, true)
			print("VFORMS FULL DONE ", c["name"], " seed=", seed, " failures=", res.failures.size())
			if res.failures.size() > before:
				for i in range(before, res.failures.size()):
					print("VFORMS FULL FAIL ", res.failures[i])
				res.note("stopped after first failing measured seed; the fifty-seed gate is incomplete")
				return res
	return res


static func _check_round_fan(res: SuiteResult) -> void:
	var plan := VillageSitePlanner.plan(_spec(0, _cases()[1]))
	var centre := VillageMeasure.common_centre(plan)
	var edge: Dictionary = {}
	for candidate in VillageLotPlanner.road_edges(plan):
		if plan.roads[int(candidate["road"])]["class"] != &"street":
			continue
		var radial: Vector2 = (candidate["a"] + candidate["b"]) * 0.5 - centre
		if radial.dot(candidate["normal"]) > 1.0 and absf(radial.dot(candidate["dir"])) < 0.1:
			edge = candidate
			break
	res.checked += 1
	if edge.is_empty():
		res.fail("round fixture has no outward street frontage")
		return
	var lot := VillageLotPlanner._make_lot(edge, float(edge["length"]) * 0.5, 8.0, 14.0, 3.0)
	var original: PackedVector2Array = lot["poly"]
	VillageLotPlanner._round_lot(plan, lot)
	var fan: PackedVector2Array = lot["poly"]
	if not _is_fan(fan, centre) or not VillageLotPlanner._poly_contains(fan, original):
		res.fail("round lot is not a radial fan containing its full usable rectangle")
	res.checked += 1
	if _is_fan(original, centre):
		res.fail("rectangular round-lot fixture escaped fan check")


static func _is_fan(poly: PackedVector2Array, centre: Vector2) -> bool:
	if poly.size() != 4 or poly[2].distance_to(poly[3]) <= poly[0].distance_to(poly[1]) + 0.1:
		return false
	return absf((poly[0] - centre).normalized().cross((poly[3] - centre).normalized())) < 0.001 \
		and absf((poly[1] - centre).normalized().cross((poly[2] - centre).normalized())) < 0.001


static func _check_courtyard_approach(res: SuiteResult) -> void:
	var spec := _spec(17217, _cases()[4])
	var job: Dictionary = {}
	for request in VillageProgrammer.programme(spec):
		if request.kind == &"castle":
			job = VillageLotPlanner.measure(request)
			break
	res.checked += 1
	if job.is_empty() or not job["placement"].has("approach"):
		res.fail("native open manor has no measured arrival approach")
		return
	var plan := VillagePlan.new(spec)
	plan.site = Rect2(-100.0, -100.0, 200.0, 200.0)
	plan.roads.append(VillageSitePlanner._road(PackedVector2Array([
		Vector2(-100.0, -64.5), Vector2(100.0, -64.5)]), &"through", 0.4))
	plan.lots.append({"poly": Poly.from_rect(Rect2(-50.0, -60.0, 100.0, 145.0)),
		"front": PackedVector2Array([Vector2(-50.0, -60.0), Vector2(50.0, -60.0)]),
		"road": 0, "class": &"manor", "landmark": false})
	plan.buildings.append({"lot": 0, "request": job["request"], "placement": job["placement"],
		"transform": Transform3D.IDENTITY, "door": job["placement"]["door"], "kind": &"castle", "class": &"manor"})
	var nav := VillageNavCheck.new().check(plan)
	var lot_check := VillageLotCheck.new()
	lot_check._check_setback(plan)
	res.checked += 1
	for failure in nav["failures"]:
		if String(failure).begins_with("arrive:") or String(failure).begins_with("paths:"):
			res.fail("open courtyard route: %s" % failure)
	if not lot_check.failures.is_empty():
		res.fail("courtyard front setback: %s" % "; ".join(lot_check.failures))
	plan.water.append({"poly": Poly.from_rect(Rect2(-2.0, -10.0, 4.0, 2.0)), "kind": &"pond"})
	var blocked := VillageNavCheck.new().check(plan)
	var rejected := false
	for failure in blocked["failures"]:
		rejected = rejected or String(failure).begins_with("arrive:")
	res.checked += 1
	if not rejected:
		res.fail("blocked courtyard approach escaped reachability QA")
	# The winding through road at this seed used to force a 75m cul-de-sac.
	# Use the same freshly measured manor, with no stored placement cache.
	var gate := VillageSitePlanner.plan(spec, 12, 2.0)
	job["class"] = &"manor"
	var lane := VillageLotPlanner._place_manor(gate, job)
	res.checked += 1
	if lane < 0:
		res.fail("native manor cannot find its own short lane")
	else:
		var manor_check := VillagePlaceCheck.new()
		manor_check._check_manor(gate)
		if Poly.polyline_length(gate.roads[lane]["points"]) > 40.0 + 0.001 or not manor_check.failures.is_empty():
			res.fail("native manor short lane: %s" % "; ".join(manor_check.failures))
		res.checked += 1
		if not VillageArchetypeSuite._manor_at_lane_head(gate):
			res.fail("native manor frontage is not recognised as its lane's destination")
		var points: PackedVector2Array = gate.roads[lane]["points"]
		var broken := points.duplicate()
		broken[broken.size() - 1] += Vector2(100.0, 0.0)
		gate.roads[lane]["points"] = broken
		res.checked += 1
		if VillageArchetypeSuite._manor_at_lane_head(gate):
			res.fail("lane ending away from the manor escaped archetype arrival QA")
		gate.roads[lane]["points"] = points


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
		for failure in VillageRoadCheck.new().check(plan)["failures"]:
			out.append(String(failure))
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
		var roads: Dictionary = VillageRoadCheck.new().check(plan)
		for failure in roads["failures"]:
			out.append(String(failure))
	if form == &"gate" and plan.roads_of_class(&"through").size() != 1:
		out.append("gate needs one through road")
	return out


static func _check_planted_regressions(res: SuiteResult) -> void:
	var spec := _spec(17167, _cases()[3])
	var plan := VillageSitePlanner.plan(spec)
	var context := VillageDresser._context(plan)
	var rng := RandomNumberGenerator.new()
	rng.seed = 22
	VillageDresser._apply(plan, context, VillageDresser.RECIPES[&"common"][0], rng, -1, &"common")
	VillageDresser._apply(plan, context, VillageDresser.RECIPES[&"market"][0], rng, -1, &"market")
	var stalls := 0
	for prop in plan.props:
		if String(prop["key"]).begins_with("Stall"):
			stalls += 1
	res.checked += 1
	if stalls < 8:
		res.fail("planted market earns eight stalls, got %d" % stalls)
	var navigation := VillageNavCheck.new().check(plan)
	res.checked += 1
	for failure in navigation["failures"]:
		if String(failure).begins_with("use:"):
			res.fail("square approach must reach the well and market: %s" % failure)
	var approach: Dictionary = plan.roads.pop_back()
	var isolated := VillageNavCheck.new().check(plan)
	plan.roads.append(approach)
	var isolated_rejected := false
	for failure in isolated["failures"]:
		isolated_rejected = isolated_rejected or String(failure).begins_with("use:")
	res.checked += 1
	if not isolated_rejected:
		res.fail("isolated square fixture escaped navigation QA")
	var check := VillagePlaceCheck.new()
	check._check_market(plan)
	res.checked += 1
	if not check.failures.is_empty():
		res.fail("market rows: %s" % "; ".join(check.failures))
	if stalls > 0:
		for prop in plan.props:
			if String(prop["key"]).begins_with("Stall"):
				prop["yaw"] = float(prop["yaw"]) + 0.4
				break
		check.failures.clear()
		check._check_market(plan)
		res.checked += 1
		if check.failures.is_empty():
			res.fail("turned stall fixture escaped market QA")
	# A two-metre porch cannot touch a neighbour when its door may stand only
	# one metre from the frontage. The geometry earns one metre of clearance.
	var placement := {"footprint": Rect2(-4.0, 0.0, 8.0, 10.0), "door": Vector3.ZERO,
		"bounds": AABB(Vector3(-4.5, 0.0, -2.0), Vector3(9.0, 6.0, 12.5))}
	res.checked += 2
	if not is_equal_approx(VillageLotPlanner.fire_gap(&"townhouse", spec, placement), 1.0):
		res.fail("projecting terrace failed to reserve its measured clearance")
	placement["door"] = Vector3(0.0, 1.0, 0.25)
	var recessed := {"placement": placement, "over": 2.0}
	res.checked += 1
	if not is_equal_approx(VillageLotPlanner._setback(VillageLotPlanner.LOT_RULES[&"townhouse"], recessed) + 0.25, 1.0):
		res.fail("native recessed townhouse door exceeds its one-metre setback")
	placement["door"] = Vector3.ZERO
	placement["bounds"] = AABB(Vector3(-4.5, 0.0, -0.5), Vector3(9.0, 6.0, 11.0))
	if not is_zero_approx(VillageLotPlanner.fire_gap(&"townhouse", spec, placement)):
		res.fail("compact townhouse lost its touching-terrace option")


static func _check_full_sample(res: SuiteResult, c: Dictionary, seed := -1, pure := false) -> void:
	var actual_seed: int = 17017 + int(c["population"]) if seed < 0 else seed
	var spec := _spec(actual_seed, c)
	var plan := VillageLotPlanner.plan(spec)
	if spec.form == &"crossroads":
		for building in plan.buildings:
			var request: BuildingRequest = building["request"]
			if request.kind == &"shop" and request.purpose == &"inn":
				var lot: Dictionary = plan.lots[int(building["lot"])]
				res.checked += 1
				if VillageMeasure.point_to_poly(VillageLotPlanner._through_crossing(plan), lot["poly"]) > 10.0:
					res.fail("crossroads seed %d inn does not occupy a corner of the crossing" % actual_seed)
	if spec.form == &"round":
		var fans := 0
		var centre := VillageMeasure.common_centre(plan)
		for lot in plan.lots:
			if plan.roads[int(lot["road"])]["class"] != &"street":
				continue
			var mid: Vector2 = (lot["front"][0] + lot["front"][1]) * 0.5
			if (mid - centre).dot(lot["normal"]) <= 1.0:
				continue
			fans += 1
			if not _is_fan(lot["poly"], centre):
				res.fail("round seed %d has a rectangular common-fronting lot" % actual_seed)
		res.checked += 1
		if fans == 0:
			res.fail("round seed %d has no fan of lots around the common" % actual_seed)
	var no_pure := func(_plan: VillagePlan) -> Array: return []
	var replacements: Dictionary = {} if pure else {&"pure": no_pure}
	var reports := [
		["scale", VillageScaleCheck.new().check(plan, replacements)],
		["road", VillageRoadCheck.new().check(plan)],
		["lot", VillageLotCheck.new().check(plan)],
		["place", VillagePlaceCheck.new().check(plan)],
		["dress", VillageDressCheck.new().check(plan)],
		["nav", VillageNavCheck.new().check(plan)],
	]
	for row in reports:
		res.checked += 1
		if not row[1]["ok"]:
			res.fail("%s seed %d %s: %s" % [c["name"], actual_seed, row[0], "; ".join(row[1]["failures"])])
