extends RefCounted
## The two real Voxel_Build cities planned as the exporter plans them: the
## people shown, the city the history says it is (owner decision 2026-10-10),
## its seat, its walls and its monuments on one site of at most 400 m.

const BRIEF := preload("res://tests/suites/site_brief_suite.gd")
const SITE_MAX := 400.0


static func run() -> SuiteResult:
	var result := SuiteResult.new("dmv implied city")
	var planned := {}
	for row in [
			["Thaannafu", BRIEF.THAAN, 45, "4000"],
			["Wuunafu", BRIEF.WUUN, 60, "6000"],
			["Wuunafu", BRIEF.WUUN, 60, ""]]:
		var label := "%s %d%s" % [row[0], row[2], " + %s implied" % row[3] if row[3] != "" else ""]
		planned[label] = _check_city(result, label, row[1], row[2], row[3])
	_check_own_lane(result, planned["Wuunafu 60"], &"house")
	_check_own_lane(result, planned["Wuunafu 60 + 6000 implied"], &"manor")
	return result


static func _check_city(result: SuiteResult, label: String, path: String, visible: int,
		implied: String) -> VillagePlan:
	var started := Time.get_ticks_msec()
	var spec: VillageSpec = BRIEF.city_spec(path, visible, implied)
	var wanted: Array[BuildingRequest] = VillageProgrammer.programme(spec)
	var plan: VillagePlan = VillageLotPlanner.plan(spec)
	var placed: Array = plan.buildings.map(func(b: Dictionary) -> BuildingRequest: return b["request"])
	var seat_rows: Array = plan.buildings.filter(func(b: Dictionary) -> bool:
		var r: BuildingRequest = b["request"]
		return r.kind == &"castle" and VillageProgrammer.monument_of(spec, r).is_empty())
	var monument_rows: Array = plan.buildings.filter(func(b: Dictionary) -> bool:
		return not VillageProgrammer.monument_of(spec, b["request"]).is_empty())
	var homes: int = placed.filter(func(r: BuildingRequest) -> bool: return r.kind == &"house").size()
	print("  %s: %d buildings (%d homes, %d seat, monuments %s), %s enclosure, %.0f x %.0f m, %.1f s" % [
		label, plan.buildings.size(), homes, seat_rows.size(), BRIEF.monuments(spec, placed),
		spec.enclosure, plan.site.size.x, plan.site.size.y,
		float(Time.get_ticks_msec() - started) / 1000.0])
	result.checked += 1
	if plan.buildings.size() != wanted.size():
		result.fail("%s placed %d of %d buildings" % [label, plan.buildings.size(), wanted.size()])
	result.checked += 1
	if plan.site.size.x > SITE_MAX + 0.01 or plan.site.size.y > SITE_MAX + 0.01:
		result.fail("%s needs a %s site, beyond %.0f m" % [label, plan.site.size, SITE_MAX])
	result.checked += 1
	if homes != spec.households:
		result.fail("%s housed %d of %d households" % [label, homes, spec.households])
	result.checked += 1
	if seat_rows.size() != 1:
		result.fail("%s placed %d seats" % [label, seat_rows.size()])
		return plan
	var seat: BuildingRequest = seat_rows[0]["request"]
	result.checked += 1
	if (CastleSpec.tier_for(seat.width, seat.length) == &"house") != implied.is_empty():
		result.fail("%s: the seat is at the %s tier" % [label, CastleSpec.tier_for(seat.width, seat.length)])
	result.checked += 1
	if str(BRIEF.monuments(spec, placed)) != str(BRIEF.monuments(spec, wanted)) or monument_rows.is_empty():
		result.fail("%s placed monuments %s of %s" % [label, BRIEF.monuments(spec, placed),
			BRIEF.monuments(spec, wanted)])
	var seat_road: int = int(plan.lots[int(seat_rows[0]["lot"])]["road"])
	for row in monument_rows:
		result.checked += 1
		if int(plan.lots[int(row["lot"])]["road"]) == seat_road:
			result.fail("%s: the %s stands on the seat's own lane" % [label,
				VillageProgrammer.monument_of(spec, row["request"])])
	result.checked += 1
	if spec.enclosure != (&"wall" if not implied.is_empty() else &"palisade"):
		result.fail("%s kept enclosure '%s'" % [label, spec.enclosure])
	return plan


## The fallback for a monument with no lot among the roads: its own plot at
## the edge, on its own lane, crossing no lot, road, common or landmark.
static func _check_own_lane(result: SuiteResult, plan: VillagePlan, tier: StringName) -> void:
	if plan == null:
		result.fail("no plan to place a monument beside")
		return
	var size: Vector2 = Vector2(12.0, 14.0) if tier == &"house" else Vector2(40.0, 50.0)
	var request := BuildingRequest.castle(hash("own-lane|%s" % tier), &"moorish", size.x, size.y, 10.0)
	var job: Dictionary = VillageLotPlanner.measure(request)
	job["order"] = plan.buildings.size()
	job["class"] = &"monument"
	var lots_before: int = plan.lots.size()
	var roads_before: int = plan.roads.size()
	var lane: int = VillageLotPlanner._place_monument_lane(plan, job)
	result.checked += 1
	if lane < 0:
		result.fail("a %s-tier monument found no plot of its own beside %s" % [tier, plan.spec.variant_name])
		return
	result.checked += 1
	if lane != roads_before or plan.roads[lane]["class"] != &"lane" or plan.lots.size() != lots_before + 1:
		result.fail("the %s-tier monument's plot is not one new lot on one new lane" % tier)
		return
	var lot: PackedVector2Array = plan.lots.back()["poly"]
	result.checked += 1
	if not VillageLotPlanner._inside_site(plan.site, lot):
		result.fail("the %s-tier monument's plot leaves the site" % tier)
	for i in range(lots_before):
		if VillageLotPlanner._overlaps(lot, plan.lots[i]["poly"]):
			result.checked += 1
			result.fail("the %s-tier monument's plot overlaps lot %d" % [tier, i])
			break
	print("  own lane: a %s-tier monument at %s" % [tier, Poly.bounding_rect(lot)])
