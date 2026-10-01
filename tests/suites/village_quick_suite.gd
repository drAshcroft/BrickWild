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
