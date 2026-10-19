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
	for case in BRIEF_CASES:
		_brief_case(res, case[0], case[1], case[2])
	res.note("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


## A real SiteRequest on real ground, through the exporter's own reading of
## it and the form the ground derives (VTER-LOTS' review cases): Thorn on
## Hallstatt's lake shore (its through road ran forty metres into the lake)
## and on Manarola's sea cliff (refused: the hold found no lot).
##
## Hallstatt's case keeps the form it was reviewed in (green): the ground now
## derives `dispersed`, which sites Thorn up the hill away from the lake and
## leaves its hold unplaced on terrain-villages already (VTER-FORM-DISPERSED's).
const BRIEF_CASES := [
	["thorn-hamlet", "real30/hallstatt", &"green"],
	["thorn-hamlet", "real30/manarola", &""],
]
const EXPORTER := preload("res://tools/export_village_plan.gd")


static func _brief_case(res: SuiteResult, request_name: String, ground_name: String,
		form: StringName) -> void:
	var label := "%s on %s" % [request_name, ground_name]
	var text := FileAccess.get_file_as_string("res://tests/fixtures/site_requests/%s.json" % request_name)
	var request: Dictionary = JSON.parse_string(text)
	var notes: Array[String] = []
	var spec: VillageSpec = EXPORTER.spec_from_request(request, text, notes)
	spec.terrain = terrain(ground_name)
	spec.generate(spec.seed)
	if form != &"":
		spec.form = form
	var t0 := Time.get_ticks_msec()
	var programme := VillageProgrammer.programme(spec)
	var plan := VillageLotPlanner.plan(spec)
	var plan_s := (Time.get_ticks_msec() - t0) / 1000.0
	res.checked += 1
	if plan.ground == null:
		res.fail("%s: not sited" % label)
		return
	res.checked += 1
	if plan.buildings.size() < programme.size():
		res.fail("%s: only %d of %d requested buildings fit" % [label, plan.buildings.size(), programme.size()])
	# the band a warning here: Thorn on Manarola is a strand on its shore
	# flat, which is the form's choice (open: VTER-FORM-SHORE), not the lots'
	_lots_on_ground(res, label, plan, &"warn")
	# the four checks the review named; the brief's own programme is the
	# exporter's to judge (scale, `earned` and the palette are not this task's)
	for check in [VillageLotCheck.new(), VillageRoadCheck.new(), VillagePlaceCheck.new(), VillageNavCheck.new()]:
		var rep: Dictionary = check.check(plan, {})
		res.checked += 1
		if not (rep["failures"] as Array).is_empty():
			res.fail("%s: %s" % [label, "; ".join((rep["failures"] as Array).slice(0, 4))])
	res.note("%-24s form %s (intent %s) site %.0fx%.0f, %d/%d buildings, plan %.1f s" % [label, spec.form,
		spec.form_intent, plan.site.size.x, plan.site.size.y, plan.buildings.size(), programme.size(), plan_s])


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
	# --- lots on the ground (VTER-LOTS)
	# the band is the REAL world set's: it judges real ground, not a synthetic plane
	_lots_on_ground(res, label, plan, &"fail" if steep and name.begins_with("real30/") else &"")
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


## VTER-LOTS, on every sited plan:
##   fall     every building's request carries its lot's fall and direction,
##            within what its family stands on in a village
##            (VillageLotGround.fall_limit) and accepted by its family's own
##            validate(): nothing is asked to stand on more than it can
##   parts    what a building puts on the ground beyond its walls (entry
##            flights, a terrace, a talus) is on no carriageway, no other lot,
##            the common or the water
##   steps    the analytic flights are the family's own: the sloped house
##            with the most fall, measured for real, puts nothing outside its
##            flat bounds and its recorded parts
##   water    no lot, building or road END on water; every crossing lands on
##            dry ground at both ends (the ground's water is plan water)
##   band     VillageShape's elev_span_m and slope_median_pct against the
##            world set's p10-p90 band for the relief class (noted always; a
##            FAIL for a steep case on REAL ground -- a synthetic plane is one
##            slope everywhere and no real village's -- and a warning for the brief cases)
static func _lots_on_ground(res: SuiteResult, label: String, plan: VillagePlan, band_rule: StringName) -> void:
	var fitted := 0
	var walls := 0
	var high_doors := 0
	var worst := {"share": 0.0, "fall": 0.0, "b": -1}
	var ribbons: Array[PackedVector2Array] = []
	for road in plan.roads:
		ribbons.append(VillageSitePlanner.road_ribbon(road, false))
	for i in range(plan.buildings.size()):
		var b: Dictionary = plan.buildings[i]
		var lot: Dictionary = plan.lots[int(b["lot"])]
		var req: BuildingRequest = b["request"]
		res.checked += 1
		if not lot.has("ground_fit"):
			res.fail("%s: building %d's lot has no platform on given ground" % [label, i])
			continue
		fitted += 1
		var fit: Dictionary = lot["ground_fit"]
		walls += (fit["terraces"] as Array).size()
		if float(fit["door_rise_m"]) > VillageLotGround.DOOR_RISE_PREFERRED:
			high_doors += 1
		var limit := VillageLotGround.fall_limit(req)
		var want: float = float(fit["fall_m"]) if limit > 0.0 else 0.0
		res.checked += 1
		if absf(req.ground_fall_m - want) > 1e-6 \
				or (want > 0.0 and absf(req.ground_downhill_deg - float(fit["downhill_deg"])) > 1e-6):
			res.fail("%s: building %d asks for %.2f m at %.0f deg, its lot says %.2f m at %.0f deg" % [
				label, i, req.ground_fall_m, req.ground_downhill_deg, want, float(fit["downhill_deg"])])
		res.checked += 1
		if limit > 0.0 and req.ground_fall_m > limit + 1e-6:
			res.fail("%s: building %d (%s) stands on %.2f m of fall, its family takes %.2f m in a village" % [
				label, i, req.kind, req.ground_fall_m, limit])
		var errs := BuildingLibrary.validate(req)
		res.checked += 1
		if not errs.is_empty():
			res.fail("%s: building %d's request is refused: %s" % [label, i, errs[0].get("message", errs[0])])
		if limit > 0.0 and req.ground_fall_m / limit > float(worst["share"]):
			worst = {"share": req.ground_fall_m / limit, "fall": req.ground_fall_m, "b": i}
		for part in fit.get("entry_parts", []):
			var beyond: Array = Geometry2D.clip_polygons(part, lot["poly"])
			for off in beyond:
				res.checked += 1
				var why := ""
				for r in range(ribbons.size()):
					if VillageLotPlanner.overlap_area(off, ribbons[r]) > VillageLotPlanner.AREA_EPS:
						why = "%s %d" % [plan.roads[r]["class"], r]
				for j in range(plan.lots.size()):
					if j != int(b["lot"]) and VillageLotPlanner.overlap_area(off, plan.lots[j]["poly"]) > VillageLotPlanner.AREA_EPS:
						why = "lot %d" % j
				for w in plan.water:
					if VillageLotPlanner.overlap_area(off, w["poly"]) > VillageLotPlanner.AREA_EPS:
						why = "the water"
				if why != "":
					res.fail("%s: building %d's steps or terrace stand on %s" % [label, i, why])
	# the analytic flights against the family's own sloped mesh
	_steps_measured(res, label, plan)
	# water: the ground's own, and every other
	for i in range(plan.lots.size()):
		for w in plan.water:
			if w["kind"] == &"race":
				continue
			res.checked += 1
			if VillageLotPlanner.overlap_area(plan.lots[i]["poly"], w["poly"]) > VillageLotPlanner.AREA_EPS \
					and plan.lots[i].get("mill_race") == null:
				res.fail("%s: lot %d is on the %s" % [label, i, w["kind"]])
	for r in range(plan.roads.size()):
		var pts: PackedVector2Array = plan.roads[r]["points"]
		for w in plan.water:
			res.checked += 1
			for p in [pts[0], pts[pts.size() - 1]]:
				if Poly.contains_point(w["poly"], p):
					res.fail("%s: %s %d ends in the %s" % [label, plan.roads[r]["class"], r, w["kind"]])
	for c in plan.water_crossings:
		var route: PackedVector2Array = c["points"]
		var w: PackedVector2Array = plan.water[int(c["water"])]["poly"]
		res.checked += 1
		for p in [route[0], route[route.size() - 1]]:
			var probe: Vector2 = p
			if Poly.contains_point(w, probe) and VillageMeasure.point_to_polyline(probe, plan.roads[int(c["road"])]["points"]) < 0.01:
				var ends: PackedVector2Array = plan.roads[int(c["road"])]["points"]
				if probe.distance_to(ends[0]) < 0.5 or probe.distance_to(ends[ends.size() - 1]) < 0.5:
					res.fail("%s: the %s crossing on %s %d lands in the water" % [
						label, c["kind"], plan.roads[int(c["road"])]["class"], int(c["road"])])
	# the world set's band
	var shape := VillageShape.measure(plan)
	var band := band_of(shape)
	var bs := "-"
	if not band.is_empty():
		bs = "%s relief %.0f m: span %.1f m %s, slope %.1f %% %s" % [band["class"], float(shape["relief_disc_m"]),
			float(shape["elev_span_m"]), band["span"], float(shape["slope_median_pct"]), band["slope"]]
		if band_rule != &"" and (band["span"] != "ok" or band["slope"] != "ok"):
			var why := "%s: the village's ground is outside the world set's band: %s" % [label, bs]
			if band_rule == &"fail":
				res.fail(why)
			else:
				res.warn(why)
		if band_rule == &"fail":
			res.checked += 1
	res.note("%-24s lots: %d of %d on platforms, %d terrace walls, %d doors over 7 risers, most fall %.2f m (%.0f %% of its family's) | %s" % [
		label, fitted, plan.buildings.size(), walls, high_doors, float(worst["fall"]), 100.0 * float(worst["share"]), bs])


## The world set's p10-p90 bands by relief class (docs/VILLAGE_TERRAIN.md
## "Lots on the ground"): the same table tools/village_terrain_sweep.gd prints.
const BANDS := {
	"low": {"span": Vector2(0.5, 16.0), "slope": Vector2(0.4, 5.0)},
	"mid": {"span": Vector2(2.0, 44.0), "slope": Vector2(1.2, 14.0)},
	"high": {"span": Vector2(7.5, 72.0), "slope": Vector2(5.0, 36.0)},
}


static func band_of(shape: Dictionary) -> Dictionary:
	if shape.get("relief_disc_m") == null or shape.get("elev_span_m") == null \
			or shape.get("slope_median_pct") == null:
		return {}
	var relief := float(shape["relief_disc_m"])
	var cls := "low" if relief < 60.0 else ("mid" if relief < 250.0 else "high")
	var b: Dictionary = BANDS[cls]
	var verdict := func(v: float, band: Vector2) -> String:
		return "ok" if v >= band.x and v <= band.y else ("LOW" if v < band.x else "HIGH")
	return {"class": cls, "span": verdict.call(float(shape["elev_span_m"]), b["span"]),
		"slope": verdict.call(float(shape["slope_median_pct"]), b["slope"])}


## The plan-built building with the most fall, measured for real with it:
## its sloped bounds stand inside its flat bounds and the parts the lot
## planner reserved for it (VillageLotGround._house_parts).
static func _steps_measured(res: SuiteResult, label: String, plan: VillagePlan) -> void:
	var best := -1
	for i in range(plan.buildings.size()):
		var req: BuildingRequest = plan.buildings[i]["request"]
		if req.kind in [&"house", &"shop"] and req.ground_fall_m > 0.0 \
				and (best < 0 or req.ground_fall_m > (plan.buildings[best]["request"] as BuildingRequest).ground_fall_m):
			best = i
	if best < 0:
		return
	var b: Dictionary = plan.buildings[best]
	var sloped: Dictionary = BrickWild.measure(b["request"])
	res.checked += 1
	if sloped.is_empty():
		res.fail("%s: building %d does not generate on its fall" % [label, best])
		return
	var flat: AABB = b["placement"]["bounds"]
	var allowed := Rect2(Vector2(flat.position.x, flat.position.z), Vector2(flat.size.x, flat.size.z))
	var xf: Transform3D = b["transform"]
	var inv := xf.affine_inverse()
	for part in plan.lots[int(b["lot"])]["ground_fit"].get("entry_parts", []):
		for p in part:
			var l: Vector3 = inv * Vector3(p.x, 0.0, p.y)
			allowed = allowed.expand(Vector2(l.x, l.z))
	var got: AABB = sloped["bounds"]
	var got_r := Rect2(Vector2(got.position.x, got.position.z), Vector2(got.size.x, got.size.z))
	res.checked += 1
	if not allowed.grow(0.05).encloses(got_r):
		res.fail("%s: building %d on %.2f m of fall reaches %s, outside its flat bounds and its reserved steps %s" % [
			label, best, (b["request"] as BuildingRequest).ground_fall_m, got_r, allowed])


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
