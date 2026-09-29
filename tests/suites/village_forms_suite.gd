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
	_check_manor_site(res)
	_check_planted_regressions(res)
	_check_courtyard_approach(res)
	_check_round_fan(res)
	_check_lane_reach(res)
	_check_street_common(res)
	_check_well_plants(res)
	_check_strand_working_bank(res)
	for c in _cases():
		_check_site_sweep(res, c)
		_check_full_sample(res, c)
	return res


## Fast semantic regression pass while an actual measured-building sweep is
## running. It exercises the same rules; it is not the full VIL-017 gate.
static func run_layout() -> SuiteResult:
	var res := SuiteResult.new("vforms layout")
	_check_manor_site(res)
	_check_planted_regressions(res)
	_check_courtyard_approach(res)
	_check_round_fan(res)
	_check_lane_reach(res)
	_check_street_common(res)
	_check_well_plants(res)
	_check_strand_working_bank(res)
	for c in _cases():
		_check_site_sweep(res, c)
	return res


static func _check_manor_site(res: SuiteResult) -> void:
	var manor: SuiteResult = preload("res://tests/suites/village_manor_site_suite.gd").run()
	res.checked += manor.checked
	res.failures.append_array(manor.failures)
	res.warnings.append_array(manor.warnings)


static func _check_strand_working_bank(res: SuiteResult) -> void:
	var spec := VillageSpec.new(3)
	spec.population = 70
	spec.purpose = &"fishing"
	spec.enclosure = &"none"
	spec.water = &"coast"
	spec.generate(3)
	var plan := VillagePlan.new(spec)
	plan.site = Rect2(-32, -20, 64, 50)
	plan.roads.append(VillageSitePlanner._road(PackedVector2Array([
		Vector2(-32, 0), Vector2(32, 0)]), &"through", 0.4))
	plan.lots.append({"poly": Poly.from_rect(Rect2(-12, 4.5, 24, 10))})
	plan.water.append({"kind": &"coast", "poly": Poly.from_rect(Rect2(-28, 16, 56, 10))})
	var ctx := VillageDressContext.make_context(plan)
	ctx["strand_walk"] = VillageNavCheck.reached_grid(plan)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	res.checked += 1
	if VillageDressPlacement.place(plan, ctx, {"built": true}, "boat", Vector2(27, 14.5), rng, -1):
		res.fail("boat accepted on an isolated shore beyond every working yard")
	VillageDressHosts.dress_place(plan, ctx, &"strand")
	var boats := 0
	var racks := 0
	for prop in plan.props:
		boats += 1 if prop["key"] == "boat" else 0
		racks += 1 if prop["key"] == "drying_rack" else 0
	res.checked += 1
	if boats == 0 or racks == 0:
		res.fail("reachable shoreline interior needs both a boat and a drying rack")
	var builder := VillageBuilder.new()
	builder.build(plan)
	for i in range(plan.props.size()):
		var prop: Dictionary = plan.props[i]
		if prop["key"] not in ["boat", "drying_rack"]:
			continue
		var mass_name := "%s%d" % [prop["key"], i]
		var emitted := false
		for mass in builder.mass_log:
			if mass["name"] != mass_name:
				continue
			emitted = true
			var actual: AABB = mass["aabb"]
			var footprint := Rect2(Vector2(actual.position.x, actual.position.z),
				Vector2(actual.size.x, actual.size.z))
			res.checked += 1
			if not (prop["rect"] as Rect2).grow(0.01).encloses(footprint):
				res.fail("shore clearance understates the emitted rotated " + String(prop["key"]))
		res.checked += 1
		if not emitted:
			res.fail("shore prop is planned but absent from emitted masses: " + mass_name)
	var nav := VillageNavCheck.new().check(plan)
	res.checked += 1
	for failure in nav["failures"]:
		if String(failure).begins_with("use:"):
			res.fail("shore working space: " + String(failure))
	_check_strand_apron(res, spec)
	_check_strand_edge(res)
	_check_strand_route_obstruction(res, spec)


static func _check_strand_route_obstruction(res: SuiteResult, spec: VillageSpec) -> void:
	var plan := VillagePlan.new(spec)
	plan.site = Rect2(-32, -20, 64, 60)
	plan.roads.append(VillageSitePlanner._road(PackedVector2Array([
		Vector2(-32, 0), Vector2(32, 0)]), &"through", 0.4))
	# A narrow reached neck opens onto a broad working yard. Its route is
	# separate from the boat's own apron and cannot be protected by that
	# apron polygon alone.
	plan.lots.append({"poly": Poly.from_rect(Rect2(-0.75, 4.5, 1.5, 8.0))})
	plan.lots.append({"poly": Poly.from_rect(Rect2(-12, 10, 24, 10))})
	plan.water.append({"kind": &"coast", "poly": Poly.from_rect(Rect2(-28, 26, 56, 10))})
	var ctx := VillageDressContext.make_context(plan)
	ctx["strand_walk"] = VillageNavCheck.reached_grid(plan)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	res.checked += 1
	if not VillageDressPlacement.place(plan, ctx, {"built": true}, "boat", Vector2(0, 23), rng, -1):
		res.fail("reached narrow-neck shore yard could not serve its boat")
		return
	res.checked += 1
	if VillageDressPlacement.place(plan, ctx, {}, "Crate_Metal", Vector2(0, 7), rng, -1):
		res.fail("later shore crate cut the boat's only yard route")
	res.checked += 1
	if not VillageNavCheck.reached_grid(plan).reached(plan.props[0]["rect"], VillageNavCheck.PERSON_RADIUS + 0.4):
		res.fail("rejected shore obstruction damaged prior boat access")


static func _check_strand_edge(res: SuiteResult) -> void:
	var spec := _spec(8, _cases()[2])
	var plan := VillagePlan.new(spec)
	# Four consecutive jittered stations used to leave this long northern
	# edge outside the site, despite the entire band being clear and dry.
	plan.site = Rect2(-178.5729, -69.02083, 357.1458, 120.0417)
	VillageDressHosts.dress_place(plan, VillageDressContext.make_context(plan), &"edge")
	var edge := VillageDressCheck.new()
	edge._check_edge(plan)
	res.checked += 1
	if not edge.failures.is_empty():
		res.fail("clear strand edge: " + "; ".join(edge.failures))
	plan.plants.clear()
	var y := plan.site.position.y + 2.5
	var road := VillageSitePlanner._road(PackedVector2Array([
		Vector2(plan.site.position.x, y), Vector2(plan.site.end.x, y)]), &"through", spec.wealth)
	plan.roads.append(road)
	VillageDressHosts.dress_place(plan, VillageDressContext.make_context(plan), &"edge")
	var ribbon := VillageSitePlanner.road_ribbon(road, true)
	res.checked += 1
	for plant in plan.plants:
		if Poly.contains_point(ribbon, plant["pos"]):
			res.fail("projected strand edge tree bypassed an actual road obstruction")
			break


static func _check_strand_apron(res: SuiteResult, spec: VillageSpec) -> void:
	var plan := VillagePlan.new(spec)
	plan.site = Rect2(-32, -20, 64, 60)
	plan.roads.append(VillageSitePlanner._road(PackedVector2Array([
		Vector2(-32, 0), Vector2(32, 0)]), &"through", 0.4))
	plan.lots.append({"poly": Poly.from_rect(Rect2(-12, 4.5, 24, 10))})
	plan.water.append({"kind": &"coast", "poly": Poly.from_rect(Rect2(-28, 24, 56, 12))})
	var ctx := VillageDressContext.make_context(plan)
	ctx["strand_walk"] = VillageNavCheck.reached_grid(plan)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	res.checked += 1
	if not VillageDressPlacement.place(plan, ctx, {"built": true}, "boat", Vector2(0, 20.5), rng, -1):
		res.fail("clear shore working apron could not connect to a reached yard")
		return
	var prop: Dictionary = plan.props.back()
	res.checked += 1
	if not prop.has("approach"):
		res.fail("shore boat across a real floor gap received no working apron")
		return
	var apron: PackedVector2Array = prop["approach"]
	var builder := VillageBuilder.new()
	var mesh := builder.build(plan)
	for point in apron:
		var found := false
		for surface in mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				found = found or vertex.distance_to(Vector3(point.x, 0.035, point.y)) < 0.001
		res.checked += 1
		if not found:
			res.fail("shore apron floor is recorded but absent from emitted mesh")
	res.checked += 1
	if VillageDressPlacement.plant_is_clear(plan, ctx, Poly.bounding_rect(apron).get_center(), 0.2, 0.2):
		res.fail("later planting can obstruct the shore working apron")
	var obstruction := Rect2(Poly.bounding_rect(apron).get_center() - Vector2(0.25, 0.25), Vector2(0.5, 0.5))
	res.checked += 1
	if VillageDressPlacement.prop_is_clear(plan, ctx, obstruction, obstruction):
		res.fail("later props can obstruct the shore working apron")
	prop.erase("approach")
	var broken := VillageNavCheck.reached_grid(plan)
	res.checked += 1
	if broken.reached(prop["rect"], VillageNavCheck.PERSON_RADIUS + 0.4):
		res.fail("boat remained reachable after its only apron was removed")


static func _check_well_plants(res: SuiteResult) -> void:
	# A ground palette may contain a boulder as broad as a tree. Both must
	# leave working room at the actual well, including when it used a
	# fallback position away from the common's geometric centre.
	for key in ["Nature_MapleTree_1", "Wild_Rock_Medium_1"]:
		var plan := VillagePlan.new(VillageSpec.new(17))
		plan.site = Rect2(-20,-20,40,40)
		plan.commons.append({"poly": Poly.from_rect(Rect2(-10,-10,20,20))})
		plan.props.append({"key":"well","pos":Vector2(1,1),"rect":Rect2(0,0,2,2),"built":true})
		var ctx := VillageDressContext.make_context(plan)
		var rng := RandomNumberGenerator.new()
		rng.seed = 17
		res.checked += 1
		if VillageDressPlacement.place(plan,ctx,{"plant":true},key,Vector2(4.9,1),rng,-1):
			res.fail("%s placed inside actual well's four-metre working area" % key)
		res.checked += 1
		if not VillageDressPlacement.place(plan,ctx,{"plant":true},key,Vector2(5.1,1),rng,-1):
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
			VillageDressHosts.dress_place(plan, VillageDressContext.make_context(plan), &"common")
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
		job["siting"] = {"road": &"through", "insists": true}
		res.checked += 1
		if VillageLotPlanner._place_on_road(plan, ctx, job, [1]) >= 0.0:
			res.fail("required through-road trade silently fell back to an ordinary lane")
		job["siting"] = {"road": &"lane", "insists": true}
		res.checked += 1
		if VillageLotPlanner._place_on_road(plan, ctx, job, [1]) < 0.0:
			res.fail("explicit companion-lane address rejected a reachable stable")
		return
	res.fail("lane reach fixture has no candidate edge")


## The task's acceptance matrix uses fifty ACTUAL planned villages per form.
## Keep it explicit: the quick site sweep and one sample do not stand in for
## this expensive measured-building run. Optional form selection allows the
## same strict matrix to be split across background runs.
static func run_full(selected: StringName = &"", first_seed := 0, seed_count := SEEDS) -> SuiteResult:
	var res := SuiteResult.new("vforms full")
	if first_seed < 0 or seed_count < 1 or first_seed + seed_count > SEEDS:
		res.fail("seed range must be nonempty and contained within 0..%d" % (SEEDS - 1))
		return res
	var matched := false
	for c in _cases():
		if selected != &"" and c["name"] != selected:
			continue
		matched = true
		print("VFORMS RANGE ", c["name"], " seeds=", first_seed, "..", first_seed + seed_count - 1,
			" of 0..", SEEDS - 1)
		for seed in range(first_seed, first_seed + seed_count):
			print("VFORMS FULL START ", c["name"], " seed=", seed)
			var before := res.failures.size()
			_check_full_sample(res, c, seed, true)
			print("VFORMS FULL DONE ", c["name"], " seed=", seed, " failures=", res.failures.size())
			if res.failures.size() > before:
				for i in range(before, res.failures.size()):
					print("VFORMS FULL FAIL ", res.failures[i])
				res.note("stopped after first failing measured seed; the fifty-seed gate is incomplete")
				return res
	if not matched:
		res.fail("unknown village form %s" % selected)
	return res


static func _check_round_fan(res: SuiteResult) -> void:
	_check_blight_common(res)
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


static func _check_blight_common(res: SuiteResult) -> void:
	for seed in range(SEEDS):
		var plan := VillagePlan.new(_spec(seed, _cases()[1]))
		plan.site = Rect2(-45, -45, 90, 90)
		var common := Poly.from_rect(Rect2(-15, -15, 30, 30))
		plan.commons.append({"poly": common})
		VillageDressContext.blight_remnants(plan, VillageDressContext.make_context(plan))
		var clear := not plan.props.is_empty()
		for prop in plan.props:
			clear = clear and VillageLotPlanner.overlap_area(Poly.from_rect(prop["rect"]), common) <= VillageLotPlanner.AREA_EPS
		res.checked += 1
		if not clear:
			res.fail("blight seed %d must retain a ruin cluster wholly outside the common" % seed)
	var blocked := VillagePlan.new(_spec(41, _cases()[1]))
	blocked.site = Rect2(-45, -45, 90, 90)
	blocked.commons.append({"poly": Poly.from_rect(blocked.site)})
	VillageDressContext.blight_remnants(blocked, VillageDressContext.make_context(blocked))
	res.checked += 1
	if not blocked.props.is_empty():
		res.fail("blight ruin bypassed a common covering every candidate site")


static func _check_courtyard_approach(res: SuiteResult) -> void:
	var approach: SuiteResult = preload("res://tests/suites/village_approach_nav_suite.gd").run()
	res.checked += approach.checked
	res.failures.append_array(approach.failures)
	res.warnings.append_array(approach.warnings)
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
		var lane := VillageLotPlanner._add_landmark_lane(plan)
		if lane >= 0:
			if Poly.polyline_length(plan.roads[lane]["points"]) > 40.0 + 0.001:
				out.append("strand landmark lane exceeds its forty-metre dead-end limit")
			plan.roads.remove_at(lane)
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
	var context := VillageDressContext.make_context(plan)
	var rng := RandomNumberGenerator.new()
	rng.seed = 22
	VillageDressRules.apply(plan, context, VillageDressCatalog.RECIPES[&"common"][0], rng, -1, &"common")
	VillageDressRules.apply(plan, context, VillageDressCatalog.RECIPES[&"market"][0], rng, -1, &"market")
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
	var failures_before := res.failures.size()
	var actual_seed: int = 17017 + int(c["population"]) if seed < 0 else seed
	var spec := _spec(actual_seed, c)
	var requests := VillageProgrammer.programme(spec)
	var jobs: Array[Dictionary] = preload("res://tests/fixtures/native_measurement_cache.gd").measure(requests)
	var plan := VillageLotPlanner.plan_measured(spec, jobs)
	res.checked += 2
	if jobs.size() != requests.size():
		res.fail("%s seed %d lost native programme measurements" % [spec.form, actual_seed])
	var expected := {}
	var actual := {}
	for request in requests:
		var key := request.to_json()
		expected[key] = int(expected.get(key, 0)) + 1
	for building in plan.buildings:
		var key: String = building["request"].to_json()
		actual[key] = int(actual.get(key, 0)) + 1
	if expected != actual:
		res.fail("%s seed %d omitted or duplicated an exact programme request" % [spec.form, actual_seed])
	if spec.form == &"gate":
		res.checked += 1
		if not VillageArchetypeSuite._manor_at_lane_head(plan):
			res.fail("gate seed %d manor is not reached at the head of its own lane" % actual_seed)
	if spec.form == &"strand":
		res.checked += 1
		var coast := Poly.bounding_rect(plan.water[0]["poly"]).get_center()
		for building in plan.buildings:
			if building["class"] in [&"church", &"manor"]:
				continue
			var lot: Dictionary = plan.lots[int(building["lot"])]
			var front: PackedVector2Array = lot["front"]
			if plan.roads[int(lot["road"])]["class"] != &"through" \
					or (coast - (front[0] + front[1]) * 0.5).dot(lot["normal"]) <= 0.0:
				res.fail("strand seed %d ordinary building is outside its one shore-facing row" % actual_seed)
		var boats := 0
		var racks := 0
		for prop in plan.props:
			boats += 1 if prop["key"] == "boat" else 0
			racks += 1 if prop["key"] == "drying_rack" else 0
		if boats == 0 or racks == 0:
			res.fail("strand seed %d needs both a boat and a drying rack" % actual_seed)
	if spec.form == &"crossroads":
		for building in plan.buildings:
			var request: BuildingRequest = building["request"]
			if request.kind == &"shop" and request.purpose == &"inn":
				var lot: Dictionary = plan.lots[int(building["lot"])]
				res.checked += 1
				if VillageMeasure.point_to_poly(VillageLotPlanner._through_crossing(plan), lot["poly"]) > 10.0:
					res.fail("crossroads seed %d inn does not occupy a corner of the crossing" % actual_seed)
	if spec.form == &"round":
		res.checked += 2
		if plan.roads_of_class(&"lane").size() != 1:
			res.fail("round seed %d must retain exactly one entrance lane after placement" % actual_seed)
		var common: PackedVector2Array = plan.commons[0]["poly"]
		var common_centre := Poly.bounding_rect(common).get_center()
		var radius := common[0].distance_to(common_centre)
		var circular := common.size() >= 12
		for point in common:
			circular = circular and absf(point.distance_to(common_centre) - radius) < 0.01
		if not circular:
			res.fail("round seed %d lost its circular polygonal common" % actual_seed)
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
	if spec.form == &"planted":
		res.checked += 2
		if plan.commons[0]["kind"] != &"square" or Poly.area(plan.commons[0]["poly"]) < 400.0:
			res.fail("planted seed %d lost its market square of at least 400m2" % actual_seed)
		var streets: Array[int] = plan.roads_of_class(&"street")
		var parallel := false
		for i in streets.size():
			var a: PackedVector2Array = plan.roads[streets[i]]["points"]
			var direction := (a[a.size() - 1] - a[0]).normalized()
			for j in range(i + 1, streets.size()):
				var b: PackedVector2Array = plan.roads[streets[j]]["points"]
				var other := (b[b.size() - 1] - b[0]).normalized()
				parallel = parallel or (absf(direction.cross(other)) < 0.001 \
					and absf(direction.cross(b[0] - a[0])) > 1.0)
		if not parallel:
			res.fail("planted seed %d needs two distinct parallel streets" % actual_seed)
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
	if res.failures.size() > failures_before:
		_save_failure_plan(plan)


## Keep the actual failing output; reproducing native lots can take minutes.
## The codec restores typed plan data without constructing arbitrary objects.
static func _save_failure_plan(plan: VillagePlan) -> void:
	var folder := "res://artifacts/village_forms_failures"
	DirAccess.make_dir_recursive_absolute(folder)
	var path := "%s/%s_seed%d_%d.bin" % [folder, String(plan.spec.form),
		plan.spec.seed, int(Time.get_unix_time_from_system() * 1000.0)]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("VFORMS could not preserve failure plan: ", path, " error=", FileAccess.get_open_error())
		return
	file.store_var(BuildingCodec.encode(plan))
	print("VFORMS FAILURE PLAN ", path)
