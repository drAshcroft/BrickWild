extends RefCounted
## A small garrison still earns a full native manor. More frontage cannot
## rescue an estate whose oblique forecourt and yard exceed the site's depth.
## This focused fixture uses the programme's first two native civic jobs;
## the populated enclosure matrix separately exercises the entire programme.

static func run() -> SuiteResult:
	var res := SuiteResult.new("village manor site")
	var spec := VillageSpec.new(18000)
	spec.population = 50
	spec.purpose = &"garrison"
	spec.culture = &"english"
	spec.wealth = 0.4
	spec.enclosure = &"hedge"
	spec.water = &"none"
	spec.generate(spec.seed)
	var requests: Array[BuildingRequest] = []
	for request in VillageProgrammer.programme(spec):
		if request.kind in [&"castle", &"church", &"temple"]:
			requests.append(request)
	var jobs := VillageLotPlanner.measure_all(requests)
	_expect(res, requests.size() == 2 and jobs.size() == requests.size(),
		"fixture must measure the real shrine and manor programme")
	var manor_jobs: Array[Dictionary] = []
	var shrine_jobs: Array[Dictionary] = []
	for job in jobs:
		if job["class"] == &"manor": manor_jobs.append(job)
		else: shrine_jobs.append(job)
	_expect(res, manor_jobs.size() == 1 and shrine_jobs.size() == 1,
		"fixture must contain one measured manor and one shrine")
	if manor_jobs.size() != 1 or shrine_jobs.size() != 1:
		return res
	var base := VillageSitePlanner.plan(spec)
	var depth := VillageLotPlanner._manor_site_depth(base, jobs)
	_expect(res, depth > base.site.size.y,
		"native estate did not reserve the missing cross-road ground")
	_expect(res, is_zero_approx(VillageLotPlanner._manor_site_depth(base, shrine_jobs)),
		"a programme without an estate reserved manor ground")
	# The original defect persists even after the final width-only retry.
	# Measure it with the same native buildings and actual legal-lot checks.
	var last: Array = VillageLotPlanner.RETRIES.back()
	var shallow := VillageSitePlanner.plan(spec, int(last[0]), float(last[1]))
	VillageLotPlanner.cut_measured(shallow, shrine_jobs)
	_expect(res, VillageLotPlanner._place_manor(shallow, manor_jobs[0]) < 0,
		"unreserved fixture no longer reproduces the missing dedicated manor lane")
	# This intermediate retry has room on an ordinary road but no lawful
	# dedicated estate lane. It used to report success and stop retries here.
	var fallback := VillageSitePlanner.plan(spec, 12, 2.5, 170.0)
	var missing := VillageLotPlanner.cut_measured(fallback, jobs)
	_expect(res, missing == 1 and fallback.buildings_of_kind(&"castle").is_empty(),
		"failed dedicated manor lane fell back to an ordinary road and ended retries")
	# The production retry path must keep searching instead of declaring a
	# generic road fallback to be the manor's dedicated approach.
	var plan := VillageLotPlanner.plan_measured(spec, jobs)
	_expect(res, plan.buildings.size() == jobs.size(),
		"measured site reserve still omits an earned native civic building")
	var manors := plan.buildings_of_kind(&"castle")
	_expect(res, manors.size() == 1, "reserved site has no unique native manor")
	if manors.size() != 1:
		return res
	var building: Dictionary = plan.buildings[manors[0]]
	var native := BrickWild.generate(building["request"])
	_expect(res, native.is_ok() and native.spec is CastleSpec \
		and (native.spec as CastleSpec).tier == &"manor",
		"estate was replaced by a smaller building to fit the site")
	var place := VillagePlaceCheck.new()
	place._check_manor(plan)
	_expect(res, place.failures.is_empty(), "reserved manor: " + "; ".join(place.failures))
	_expect(res, VillageArchetypeSuite._manor_at_lane_head(plan),
		"reserved manor does not occupy its own lane's arrival")
	var lot: Dictionary = plan.lots[int(building["lot"])]
	var road: Dictionary = plan.roads[int(lot["road"])]
	_expect(res, road["class"] == &"lane" \
		and Poly.polyline_length(road["points"]) <= VillageRoadCheck.DEAD_END_MAX + 0.001,
		"reserved manor requires an overlong or non-lane approach")
	for row in plan.buildings:
		_expect(res, _bounds_on_site(plan.site, row),
			"complete native building bounds leave the reserved site")
	var lots := VillageLotCheck.new()
	lots._check_tiling(plan)
	lots._check_fit(plan)
	lots._check_fire_gap(plan)
	_expect(res, lots.failures.is_empty(), "reserved civic lots: " + "; ".join(lots.failures))
	# A reverted depth must be visible in the actual transformed architecture,
	# independently of the helper's arithmetic or the lot it claims to reserve.
	var old_depth := Rect2(Vector2(plan.site.position.x, base.site.position.y),
		Vector2(plan.site.size.x, base.site.size.y))
	_expect(res, not _bounds_on_site(old_depth, building),
		"shrinking back to the original depth did not catch the protruding native manor")
	_check_oblique_lane_envelope(res, jobs, manor_jobs[0], shrine_jobs)
	return res


## Geometry coverage, not programme acceptance: hold the measured native
## estate fixed and vary the site's road bend. The old reserve counted only
## one frontage along the lane, leaving the actual far candidate off-site.
static func _check_oblique_lane_envelope(res: SuiteResult, jobs: Array[Dictionary],
		manor: Dictionary, shrines: Array[Dictionary]) -> void:
	var spec := VillageSpec.new(0)
	spec.population = 50
	spec.purpose = &"garrison"
	spec.culture = &"english"
	spec.wealth = 0.4
	spec.enclosure = &"hedge"
	spec.water = &"none"
	spec.generate(spec.seed)
	var base := VillageSitePlanner.plan(spec)
	var direction := Vector2(VillageLotPlanner.MANOR_LANE_LEAN, 1).normalized()
	var road_top := 0.0
	for road in base.roads:
		if road["class"] != &"through": continue
		for point in road["points"]:
			road_top = maxf(road_top, Vector2(point).y + float(road["width"]) * 0.5 + float(road["verge"]))
	var rule: Dictionary = VillageLotPlanner.LOT_RULES[&"manor"]
	var frontage := float(manor["half_w"]) * 2 + maxf(
		VillageLotPlanner.fire_gap(&"manor", spec, manor["placement"]), 1)
	var lot_depth := VillageLotPlanner._setback(rule, manor) + float(manor["back"]) + float(rule["yard"])
	var old_depth := 2 * (road_top + direction.y * frontage
		+ absf(direction.x) * (lot_depth + VillageLotPlanner.LANE_HALF) + VillageLotPlanner.SITE_MARGIN)
	var last: Array = VillageLotPlanner.RETRIES.back()
	var shallow := VillageSitePlanner.plan(spec, int(last[0]), float(last[1]), old_depth)
	VillageLotPlanner.cut_measured(shallow, shrines)
	_expect(res, VillageLotPlanner._place_manor(shallow, manor) < 0,
		"frontage-only reserve no longer reproduces the oblique-lane failure")
	var plan := VillageLotPlanner.plan_measured(spec, jobs)
	var manors := plan.buildings_of_kind(&"castle")
	_expect(res, plan.buildings.size() == jobs.size() and manors.size() == 1,
		"candidate-envelope reserve omits the fixed native estate on site seed 0")
	if manors.size() != 1: return
	var place := VillagePlaceCheck.new()
	place._check_manor(plan)
	_expect(res, place.failures.is_empty() and VillageArchetypeSuite._manor_at_lane_head(plan),
		"oblique estate does not reach its private lane head: " + "; ".join(place.failures))
	var lot: Dictionary = plan.lots[int(plan.buildings[manors[0]]["lot"])]
	var road: Dictionary = plan.roads[int(lot["road"])]
	_expect(res, road["class"] == &"lane" \
		and Poly.polyline_length(road["points"]) <= VillageRoadCheck.DEAD_END_MAX + 0.001,
		"oblique estate needs an overlong or non-lane approach")
	for building in plan.buildings:
		_expect(res, _bounds_on_site(plan.site, building),
			"oblique estate's complete native bounds leave the reserved site")


static func _bounds_on_site(site: Rect2, building: Dictionary) -> bool:
	for point in VillageMeasure.bounds_poly(building):
		if not site.grow(0.01).has_point(point): return false
	return true


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok: res.fail(message)
