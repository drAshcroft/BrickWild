extends RefCounted
## Villages planned ON their ground (VTER-SITING, VTER-ROADS;
## docs/VILLAGE_TERRAIN.md "Planning on the ground").
##
## One small village (50 people, its buildings measured once) planned on
## synthetic landforms with known answers and on two real 30 m grids, a form
## per case so every form planner is planned on ground at least once:
##
##   sited      the plan says where it stands (anchor, yaw), its corners are on
##              the grid, and the frame view reads the caller's ground there
##   grades     every road's grade_max (VillageTerrain.profile on its final
##              points) is within its class's grade_max -- on the plan's own
##              ground and again on the caller's grid at the carried points
##   contour    on ground steeper than 15 %, street_contour_share in 0.45-0.80
##              where most of the plan's street length stands on steep ground
##              (street_steep_share >= 0.5; VillageShape needs 100 m of it
##              near the houses at all); the survey: median 0.57
##   common     on ground <= 5 % where the grid has level ground of its size
##              within reach of the siting
##   cliff, wet no lot crosses a cliff band; no lot, building or common on
##              standing water
##   qa         VillageQA (scale, roads, lots, places, dressing, walking; no
##              per-building QA, and `pure` is its own check below because the
##              form is forced and the twin derives its own)
##   pure       the same spec on the same ground is the same site plan, the
##              siting cache cleared between (the lot planner is pure given
##              its site plan; vcheck's `pure` covers it)
##   fixed      a grid that only just covers the site keeps the caller's
##              centre and chooses the yaw alone
##
## Timings per plan are in the notes; planning is the cost.

const SYNTH := preload("res://tests/fixtures/terrain/synthetic_terrain.gd")
const REAL30 := "res://tests/fixtures/terrain/real30/"
const POPULATION := 50
const SEED := 4242
## [fixture, form, steep (> 15 %: the contour rule applies)]
const CASES := [
	["plane_15", &"crossroads", false],
	["plane_30", &"street", true],
	["valley", &"green", true],
	["spur", &"street", true],
	["crest", &"round", true],
	["cliff_band", &"gate", false],
	["lake_shore", &"green", false],
	["real30/manarola", &"street", true],
	["real30/monpazier", &"green", false],
]
## The contour band applies to a plan whose streets mostly stand on steep
## ground (VillageShape street_steep_share): a village sited on a level patch
## with field tracks climbing out of it has a share of those tracks alone.
const STEEP_STREETS := 0.5
const CONTOUR_BAND := Vector2(0.45, 0.80)
const LEVEL := 0.05
## the caller's grid, read at the carried points, may differ from the frame's
## resampled view by the resampling itself
const CARRIED_TOL := 0.01


static func run() -> SuiteResult:
	var res := SuiteResult.new("vtplan")
	var t0 := Time.get_ticks_msec()
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(spec_for(&"street", null)))
	res.note("measured %d buildings once in %.1f s" % [jobs.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	_fixed_centre(res)
	for case in CASES:
		_case(res, jobs, case[0], case[1], case[2])
	_pure(res, jobs)
	res.note("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


static func spec_for(form: StringName, ground: VillageTerrain) -> VillageSpec:
	var s := VillageSpec.new(SEED)
	s.population = POPULATION
	s.generate(SEED)
	s.form = form
	s.terrain = ground
	return s


static func terrain(name: String) -> VillageTerrain:
	if name.begins_with("real30/"):
		return VillageTerrain.from_file(REAL30 + name.substr(7) + ".json")
	return SYNTH.make(name)


static func _case(res: SuiteResult, jobs: Array[Dictionary], name: String, form: StringName,
		steep: bool) -> void:
	var label := "%s/%s" % [name, form]
	var ground := terrain(name)
	res.checked += 1
	if ground == null or not ground.valid():
		res.fail("%s: the fixture does not read" % label)
		return
	var t0 := Time.get_ticks_msec()
	var plan := VillageLotPlanner.plan_measured(spec_for(form, ground), jobs)
	var plan_s := (Time.get_ticks_msec() - t0) / 1000.0
	# --- sited
	res.checked += 1
	if plan.ground == null or plan.ground.parent != ground or plan.roads.is_empty():
		res.fail("%s: the plan was not sited on its ground" % label)
		return
	res.checked += 1
	if not preload("res://tools/export_village_plan.gd").covers_plan(ground, plan):
		res.fail("%s: the sited site's corners leave the grid" % label)
	res.checked += 1
	var probe := plan.site.get_center() + Vector2(7.0, -3.0)
	if absf(plan.ground.height_at(probe) - ground.height_at(plan.ground.to_parent(probe))) > 0.05 * maxf(1.0, ground.cell_m):
		res.fail("%s: the frame view does not read the caller's ground at the carried point" % label)
	# --- grades, per class
	var worst := {}
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		var cls: StringName = road["class"]
		var pts: PackedVector2Array = road["points"]
		var cap: float = float(VillageSitePlanner.road_rule(cls, plan.spec)["grade_max"])
		var local: float = float(plan.ground.profile(pts)["grade_max"])
		var carried := PackedVector2Array()
		for p in pts:
			carried.append(plan.ground.to_parent(p))
		var given: float = float(ground.profile(carried)["grade_max"])
		worst[cls] = maxf(float(worst.get(cls, 0.0)), local)
		res.checked += 1
		if local > cap + 1e-6:
			res.fail("%s: %s %d climbs %.1f %%, its class is laid to %.0f %%" % [label, cls, r, local * 100.0, cap * 100.0])
		elif given > cap + CARRIED_TOL:
			res.fail("%s: %s %d climbs %.1f %% on the caller's grid, its class is laid to %.0f %%" % [
				label, cls, r, given * 100.0, cap * 100.0])
	# --- contour
	var shape := VillageShape.measure(plan)
	var share: Variant = shape.get("street_contour_share")
	var steep_share: float = float(shape.get("street_steep_share", 0.0)) if shape.get("street_steep_share") != null else 0.0
	if steep:
		res.checked += 1
		if share == null:
			res.note("%s: no steep street length near the houses (the village stands on level ground)" % label)
		elif steep_share < STEEP_STREETS:
			res.note("%s: street_contour_share %.3f is of the %.0f %% of its street length on steep ground (the village stands on level ground; field tracks climb out of it)" % [
				label, float(share), steep_share * 100.0])
		elif float(share) < CONTOUR_BAND.x or float(share) > CONTOUR_BAND.y:
			res.fail("%s: street_contour_share %.3f outside %.2f-%.2f" % [label, float(share), CONTOUR_BAND.x, CONTOUR_BAND.y])
	# --- common
	var common_slope := NAN
	if not plan.commons.is_empty():
		var u := plan.ground.under(plan.commons[0]["poly"])
		common_slope = float(u["slope_mean"])
		res.checked += 1
		if float(u["dry_share"]) < 1.0:
			res.fail("%s: the common is on standing water" % label)
		res.checked += 1
		if common_slope > LEVEL + 1e-6 and _level_within_reach(ground, Poly.area(plan.commons[0]["poly"])):
			res.fail("%s: the common lies on %.1f %% though the grid has level ground for it within reach" % [
				label, common_slope * 100.0])
	# --- cliff and wet
	for i in range(plan.lots.size()):
		var lot_u := plan.ground.under(plan.lots[i]["poly"])
		res.checked += 1
		if float(lot_u["dry_share"]) < 1.0:
			res.fail("%s: lot %d is on standing water" % [label, i])
		res.checked += 1
		if name == "cliff_band" and float(lot_u["span_m"]) > 10.0:
			res.fail("%s: lot %d crosses the cliff band (%.1f m of fall under it)" % [label, i, float(lot_u["span_m"])])
	for i in range(plan.buildings.size()):
		var b: Dictionary = plan.buildings[i]
		res.checked += 1
		if float(plan.ground.under(Placement.world_rect(b["placement"], b["transform"], true))["dry_share"]) < 1.0:
			res.fail("%s: building %d stands in standing water" % [label, i])
	# --- the village's own QA
	var t1 := Time.get_ticks_msec()
	var no_pure := func(_plan: VillagePlan) -> Array: return []
	var qa: Dictionary = VillageQA.new().check(plan, {&"pure": no_pure}, false)
	var qa_s := (Time.get_ticks_msec() - t1) / 1000.0
	res.checked += 1
	if not qa["ok"]:
		res.fail("%s: VillageQA: %s" % [label, "; ".join((qa["failures"] as Array).slice(0, 4))])
	res.checked += 1
	if plan.buildings.size() < jobs.size():
		res.fail("%s: %d of %d buildings placed" % [label, plan.buildings.size(), jobs.size()])
	var gs := ""
	for cls in worst:
		gs += " %s %.1f%%" % [cls, float(worst[cls]) * 100.0]
	res.note("%-24s at (%.0f, %.0f) yaw %.1f site %.0fx%.0f |%s | contour %s | common %.1f%% | plan %.1f s, qa %.1f s" % [
		label, plan.site_anchor.x, plan.site_anchor.y, rad_to_deg(plan.site_yaw), plan.site.size.x, plan.site.size.y,
		gs, "-" if share == null else "%.3f (steep %.2f)" % [float(share), steep_share], common_slope * 100.0, plan_s, qa_s])


## Level, dry ground (<= 5 % mean slope) of at least `area` within the
## siting's reach of the caller's centre.
static func _level_within_reach(ground: VillageTerrain, area: float) -> bool:
	var a := VillageSiteAnalysis.of(ground, ground.bounds(), maxf(10.0, ground.cell_m * 0.5))
	if not a.valid():
		return false
	for region in a.level_regions(LEVEL, area):
		if Vector2(region["centroid"]).length() <= VillageSiting.REACH_M:
			return true
	return false


## The caller fixes the centre: a grid only just covering the site. The
## anchor stays at the origin, the yaw is chosen, the corners stay covered.
static func _fixed_centre(res: SuiteResult) -> void:
	var spec := spec_for(&"street", null)
	var flat := VillageSitePlanner.plan_flat(spec)
	var half: float = flat.site.size.x * 0.5 + 1.0
	var tight := SYNTH.make("plane_30", Rect2(-half, -half, 2.0 * half, 2.0 * half), 5.0)
	var sited := VillageSiting.choose(tight, flat, false)
	res.checked += 1
	if not bool(sited["fixed_centre"]) or Vector2(sited["anchor"]).length() > 1e-6:
		res.fail("fixed: a grid that only just covers the site moved its centre to %s" % sited["anchor"])
	res.checked += 1
	if not VillageSiting._covered(tight.bounds(), flat.site, sited["anchor"], sited["yaw"]):
		res.fail("fixed: the chosen yaw %.1f turns the site off the grid" % rad_to_deg(sited["yaw"]))
	# the contour of plane_30 runs east-west: the road along it, yaw 0 or 180
	res.checked += 1
	var yaw_deg: float = fposmod(rad_to_deg(float(sited["yaw"])), 180.0)
	if minf(yaw_deg, 180.0 - yaw_deg) > 8.0:
		res.fail("fixed: on a north-facing plane the road should run east-west; yaw %.1f" % rad_to_deg(sited["yaw"]))


## The same spec on the same ground twice, the siting cache cleared between:
## the same site plan. And a flat spec is still sited nowhere.
static func _pure(res: SuiteResult, _jobs: Array[Dictionary]) -> void:
	var a := VillageSitePlanner.plan(spec_for(&"street", terrain("spur")))
	VillageSiting.clear_cache()
	var b := VillageSitePlanner.plan(spec_for(&"street", terrain("spur")))
	res.checked += 1
	if not a.equals(b):
		res.fail("pure: the same spec on the same ground sited twice gave two site plans")
	var flat := VillageSitePlanner.plan(spec_for(&"street", null))
	res.checked += 1
	if flat.ground != null or flat.site_anchor != Vector2.ZERO or flat.site_yaw != 0.0:
		res.fail("pure: a flat spec was sited")
	res.checked += 1
	for road in flat.roads:
		if road["class"] == &"steps":
			res.fail("pure: a flat plan has steps")
			break
