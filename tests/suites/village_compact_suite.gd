extends RefCounted
## Compact pedestrian display village contract for projects that place many
## small settlements in a limited scene. Architecture remains full scale.

static func run() -> SuiteResult:
	var res := SuiteResult.new("vcompact")
	var cases: Array[Dictionary] = [
		{"culture": &"mediterranean", "style": &"mediterranean", "population": 40},
		{"culture": &"east_asian", "style": &"asian"},
	]
	var deterministic_plan: VillagePlan
	for i in range(cases.size()):
		var row: Dictionary = cases[i]
		var population: int = int(row.get("population", 12))
		var spec := VillageSpec.compact(741 + i, population, row["culture"], &"market", 0.4)
		res.checked += 1
		if not spec.valid():
			res.fail("compact factory returned invalid %s spec: %s" % [row["culture"], "; ".join(spec.errors())])
			continue
		if not spec.compact_display or spec.form != &"planted" or spec.water != &"none" or spec.enclosure != &"none":
			res.fail("compact factory did not derive the expected open planted display for %s" % row["culture"])

		var requests := VillageProgrammer.programme(spec)
		var house_count := 0
		for request in requests:
			if request.kind != &"house":
				continue
			house_count += 1
			if request.style != row["style"]:
				res.fail("%s compact house requested %s style, expected %s" % [row["culture"], request.style, row["style"]])
		res.checked += 1
		if house_count != spec.households:
			res.fail("%s compact programme has %d houses for %d households" % [row["culture"], house_count, spec.households])

		var plan: VillagePlan = VillageLotPlanner.plan(spec)
		res.checked += 1
		var earned_landmark := false
		for row_programme in spec.programme:
			if row_programme["kind"] in [&"shrine", &"church", &"temple"]:
				earned_landmark = true
				break
		if plan.landmark_reserved() != earned_landmark:
			res.fail("%s compact landmark reservation does not match its programme" % row["culture"])
		var expected_depth := 80.0 if earned_landmark else 64.0
		if not is_equal_approx(plan.site.size.y, expected_depth):
			res.fail("%s compact site depth %.1f does not fit its civic programme (want %.1f)" % [
				row["culture"], plan.site.size.y, expected_depth])
		if earned_landmark:
			var civic: PackedVector2Array = plan.landmark_site["poly"]
			for point in civic:
				if not plan.site.grow(0.01).has_point(point):
					res.fail("%s compact civic plot leaves the site at %s" % [row["culture"], point])
					break
		if plan.buildings.size() < house_count:
			res.fail("%s compact plan placed %d buildings for %d houses" % [row["culture"], plan.buildings.size(), house_count])
		var placed_houses := 0
		for building in plan.buildings:
			var request: BuildingRequest = building["request"]
			if request.kind == &"house":
				placed_houses += 1
		res.checked += 1
		if placed_houses != spec.households:
			res.fail("%s compact plan placed %d houses for %d households" % [row["culture"], placed_houses, spec.households])
		for problem in VillageLotSuite.judge(plan):
			res.fail("%s compact lots: %s" % [row["culture"], problem])
		var qa: Dictionary = VillageQA.new().check(plan, {}, false)
		for problem in qa["failures"]:
			res.fail("%s compact QA: %s" % [row["culture"], problem])
		if i == 0:
			deterministic_plan = plan

	var repeated := VillageLotPlanner.plan(VillageSpec.compact(741, 40, &"mediterranean", &"market", 0.4))
	res.checked += 1
	if deterministic_plan == null or not deterministic_plan.equals(repeated):
		res.fail("same compact inputs did not produce equal plans")

	var native := VillageSpec.new(741)
	native.population = 12
	native.culture = &"mediterranean"
	native.purpose = &"market"
	native.generate(741)
	var compact_rule := VillageLotPlanner.lot_rule(&"cottage", VillageSpec.compact(741, 12, &"mediterranean"))
	var native_rule := VillageLotPlanner.lot_rule(&"cottage", native)
	res.checked += 1
	if float(compact_rule["set_min"]) >= float(native_rule["set_min"]):
		res.fail("compact cottage setback minimum did not shrink (%s vs %s)" % [compact_rule, native_rule])
	var compact_rich := VillageSpec.compact(742, 160, &"mediterranean", &"market", 0.9)
	var planted_rich := VillageSpec.new(742)
	planted_rich.population = 160
	planted_rich.culture = &"mediterranean"
	planted_rich.purpose = &"market"
	planted_rich.wealth = 0.9
	planted_rich.generate(742)
	res.checked += 1
	if VillageLotPlanner.fire_gap(&"townhouse", compact_rich) <= 0.0:
		res.fail("compact display removed townhouse fire clearance")
	if VillageLotPlanner.fire_gap(&"townhouse", planted_rich) != 0.0:
		res.fail("native rich planted village lost its terrace option")
	var defaults := VillageSpec.compact(743)
	res.checked += 1
	if defaults.population != 40 or defaults.culture != &"english" or defaults.purpose != &"market" or not defaults.valid():
		res.fail("compact factory defaults are invalid or unexpected")

	return res
