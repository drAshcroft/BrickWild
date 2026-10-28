extends RefCounted
## Short, fixed site + lot + plan-check regression. Statistical village
## suites remain the authority for form-wide acceptance; this suite keeps a
## few real plans available for routine task feedback.

static func run() -> SuiteResult:
	var res := SuiteResult.new("village quick")
	var fixtures: Array[Dictionary] = [
		{"name": "street", "seed": 0, "population": 70, "purpose": &"forest", "wealth": 0.4},
		{"name": "hamlet", "seed": 0, "population": 18, "purpose": &"mining", "wealth": 0.4},
	]
	var mutation_plan: VillagePlan
	var street_site: VillagePlan
	var street_spec: VillageSpec
	for row in fixtures:
		var spec := _spec(int(row.seed), int(row.population), row.purpose, float(row.wealth))
		var site_plan: VillagePlan = VillageSitePlanner.plan(spec)
		res.checked += 1
		for problem in VillageSiteSuite._judge(site_plan, spec):
			res.fail("%s site baseline: %s" % [String(row.name), problem])
		if row.name == "hamlet" and not site_plan.commons.is_empty():
			var common_area := Poly.area(site_plan.commons[0]["poly"])
			res.checked += 1
			if common_area > 60.0:
				res.fail("hamlet site baseline: common area %.2fm² exceeds the well-sized limit" % common_area)

		if row.name == "street":
			street_site = site_plan
			street_spec = spec
		var plan: VillagePlan = VillageLotPlanner.plan(spec)
		res.checked += 1
		if plan.lots.is_empty():
			res.fail("%s lot baseline: planner produced no lots" % String(row.name))
		for problem in VillageLotSuite.judge(plan):
			res.fail("%s lot baseline: %s" % [String(row.name), problem])
		var report: Dictionary = VillageQA.new().check(plan, {}, false)
		res.checked += 1
		for problem in report["failures"]:
			res.fail("%s plan QA baseline: %s" % [String(row.name), str(problem)])
		if row.name == "street":
			mutation_plan = plan

	if mutation_plan == null:
		res.fail("width mutation control had no street plan")
	else:
		_check_width_mutation(res, mutation_plan)
	_check_site_controls(res, street_site, street_spec)
	_check_strand_approach(res)
	return res


static func _spec(seed: int, population: int, purpose: StringName, wealth: float) -> VillageSpec:
	var spec := VillageSpec.new(seed)
	spec.population = population
	spec.culture = &"english"
	spec.purpose = purpose
	spec.wealth = wealth
	spec.enclosure = &"none"
	spec.water = &"none"
	spec.generate(seed)
	return spec


static func _check_width_mutation(res: SuiteResult, plan: VillagePlan) -> void:
	var through_roads: Array[int] = plan.roads_of_class(&"through")
	res.checked += 1
	if through_roads.is_empty():
		res.fail("width mutation control has no through road to alter")
		return
	var broken := _copy_plan(plan)
	var road_index: int = through_roads[0]
	var road: Dictionary = broken.roads[road_index]
	road["width"] = float(road["width"]) + 1.0
	var report: Dictionary = VillageRoadCheck.new().check(broken)
	var caught := false
	for problem in report["failures"]:
		if str(problem).begins_with("width: through %d is " % road_index):
			caught = true
			break
	if not caught:
		res.fail("deliberately widened through road escaped the width check: %s" % str(report["failures"]))


static func _copy_plan(plan: VillagePlan) -> VillagePlan:
	var out := VillagePlan.new(plan.spec)
	out.site = plan.site
	out.roads = plan.roads.duplicate(true)
	out.lots = plan.lots.duplicate(true)
	out.buildings = plan.buildings.duplicate(true)
	out.commons = plan.commons.duplicate(true)
	out.landmark_site = plan.landmark_site.duplicate(true)
	out.enclosure = plan.enclosure.duplicate()
	out.gate_crossings = plan.gate_crossings.duplicate(true)
	out.water = plan.water.duplicate(true)
	out.water_crossings = plan.water_crossings.duplicate(true)
	out.fields = plan.fields.duplicate(true)
	out.props = plan.props.duplicate(true)
	out.plants = plan.plants.duplicate(true)
	return out


## Negative controls for the site baseline: the two rules that were once
## silenced by being wrong must still catch a real fault. A street laid across
## the common is a road on the green; a path with no shoulder is a path whose
## verge is not the class's.
static func _check_site_controls(res: SuiteResult, plan: VillagePlan, spec: VillageSpec) -> void:
	res.checked += 1
	if plan == null or plan.commons.is_empty():
		res.fail("site controls had no street site plan with a common")
		return
	var common: PackedVector2Array = plan.commons[0]["poly"]
	var rect := Poly.bounding_rect(common)
	var crossed := _copy_plan(plan)
	var mid := rect.get_center()
	crossed.roads.append(VillageSitePlanner._road(PackedVector2Array([
		mid - Vector2(rect.size.x, 0.0), mid + Vector2(rect.size.x, 0.0)]), &"street", spec.wealth))
	if not "common overlaps a street" in VillageSiteSuite._judge(crossed, spec):
		res.fail("a street laid across the common escaped the common check")
	res.checked += 1
	var bare := _copy_plan(plan)
	var found_path := false
	for road in bare.roads:
		if road["class"] == &"path":
			road["verge"] = 0.0
			found_path = true
	if not found_path:
		res.fail("site controls: the street plan has no path to strip of its verge")
	elif not "path verge 0.00 != 0.70" in VillageSiteSuite._judge(bare, spec):
		res.fail("a path with no verge escaped the verge check")


## VTER-STALE-COMMON-PATH: the strand's approach path to the common starts on
## the through road. A through road with no vertex at x = 0 (an odd column
## count) used to get a path from (0, y of the nearest vertex), floating off
## the road, and a second path from the well-path pass: two networks. Failing
## control: the same path moved back to x = 0 is off the road.
static func _check_strand_approach(res: SuiteResult) -> void:
	var spec := _spec(3, 40, &"fishing", 0.4)
	var out := VillagePlan.new(spec)
	out.site = Rect2(Vector2(-40.0, -30.0), Vector2(80.0, 60.0))
	out.ground = VillageTerrain.new()
	out.roads.append(VillageSitePlanner._road(PackedVector2Array(
		[Vector2(-40.0, 0.0), Vector2(-5.0, 2.0), Vector2(5.0, -2.0), Vector2(40.0, 0.0)]), &"through", spec.wealth))
	VillageSitePlanner._plan_strand(out, spec, out.roads[0]["points"])
	var paths: Array[int] = out.roads_of_class(&"path")
	res.checked += 1
	if paths.size() != 1:
		res.fail("strand approach: %d path roads, wanted the one approach" % paths.size())
		return
	var pts: PackedVector2Array = out.roads[paths[0]]["points"]
	var through: PackedVector2Array = out.roads[0]["points"]
	res.checked += 1
	if not VillageSitePlanner._on_polyline(pts[0], through):
		res.fail("strand approach starts at %s, off the through road" % str(pts[0]))
	# the control: the old start, on the column x = 0, is off this road
	res.checked += 1
	if VillageSitePlanner._on_polyline(Vector2(0.0, pts[0].y), through):
		res.fail("strand approach control: x = 0 is on the road, the case does not discriminate")
