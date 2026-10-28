extends RefCounted
## The `valley` form (VTER-FORM-VALLEY; docs/VILLAGE_TERRAIN.md "The valley
## form"): a farming village of 60 people on a river valley, measured as the
## world survey measures a real one.
##
##   form       the ground derives `valley` and the spec plans it (no fallback)
##   river      the river is plan water of kind `river`; no road runs in it,
##              none crosses it (bridges are VTER-CROSSINGS'), no lot, building
##              or common stands in it
##   shape      VillageShape elongation over 3 (the survey's high-relief band
##              is 1.48-4.72, median 2.71) and dead_end_ratio within the
##              survey's high-relief p10-p90 band, 0.22-0.65 (median 0.44):
##              a ribbon along the road with short ways up the sides
##   ways       the through road runs along the valley (its direction within
##              25 degrees of the river's) with climbing ways off its hill
##              side, each a lane (12 %) or a track (30 %), all within their
##              class's grade
##   slope      every lot is fitted to its ground (ground_fit) within what its
##              family stands on in a village: nothing on unbuildable slope
##   qa         VillageQA (scale, roads, lots, places, dressing, walking; no
##              per-building QA, and `pure` is checked below)
##   pure       the same spec on the same ground, siting cache cleared, is the
##              same site plan
##   export     the exporter writes form `valley`, `form_intent` `valley`, no
##              fallback note, the river among the water
##   flat       a flat spec of the same inputs is not valley: nothing flat
##              changes

const SYNTH := preload("res://tests/fixtures/terrain/synthetic_terrain.gd")
const EXPORTER := preload("res://tools/export_village_plan.gd")
const PLANSUITE := preload("res://tests/suites/village_terrain_plan_suite.gd")
const POPULATION := 60
const SEED := 4242
## [fixture, forced form (&"" = the ground's own)]. The spec's water is
## `river` throughout: the synthetic grids carry none of their own as a spec.
const CASES := [
	["river_valley", &""],
	["valley", &""],
	["world90/gangotri", &""],
	["real30/ushguli", &""],
	["world90/rocamadour", &""],
]
## Derive valley (with a river in the spec) and are NOT cases, each for a stated
## reason (docs/VILLAGE_TERRAIN.md "The valley form", VTER-VALLEY-REAL):
## world90/balan (hand label valley; houses 19 of 19 and fronts its common, but
## its uniform 13 % hillside gives a body of 8 buildings, elongation 2.5),
## world90/lake_argyle (hand label dispersed; the hill row is 30-55 % and the
## bank row a river strip, so a 76 m stretch has no lot and the body splits,
## elongation 2.7), and
## world90/vermont and world90/lugar_de_guene (see Not yet).
## VALLEY_CASE=<fixture> runs any of them.
## Over three, with the survey's high-relief median (2.71) under it and its p90 (4.72) over.
const ELONGATION_MIN := 3.0
## The survey's high-relief p10-p90 band for dead_end_ratio (world_settlements.json,
## relief_disc_m >= 250 m, 40 sites: 0.22 / 0.44 / 0.65).
const DEAD_END_BAND := Vector2(0.22, 0.65)
## the through road keeps within this of the river, at the median of its vertices: a
## grade-limited road leaves a gorge's river where the river drops faster than a cart climbs
const ALONG_M := 45.0
## the river polygon spans at least this share of the site's length (a real river leaves the site where the valley bends)
const RIVER_SHARE_MIN := 0.4
const WORLD90 := "res://tests/fixtures/terrain/world90/"


static func run() -> SuiteResult:
	var res := SuiteResult.new("vvalley")
	var t0 := Time.get_ticks_msec()
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(spec_for(null)))
	res.note("measured %d buildings once in %.1f s" % [jobs.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	_flat(res)
	# VALLEY_CASE=<fixture> runs that one fixture, in CASES or not
	var only := OS.get_environment("VALLEY_CASE")
	if only != "":
		_case(res, jobs, only, &"")
	else:
		for case in CASES:
			_case(res, jobs, case[0], case[1])
	if only == "":
		_pure(res)
	res.note("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


static func spec_for(ground: VillageTerrain, form := &"") -> VillageSpec:
	var s := VillageSpec.new(SEED)
	s.population = POPULATION
	s.purpose = &"farming"
	s.water = &"river"
	s.terrain = ground
	s.generate(SEED)
	if form != &"":
		s.form = form
	return s


static func terrain(name: String) -> VillageTerrain:
	if name.begins_with("real30/"):
		return VillageTerrain.from_file("res://tests/fixtures/terrain/%s.json" % name)
	if name.begins_with("world90/"):
		return VillageTerrain.from_file(WORLD90 + name.substr(8) + ".json")
	return SYNTH.make(name)


static func _case(res: SuiteResult, jobs: Array[Dictionary], name: String, forced: StringName) -> void:
	var ground := terrain(name)
	res.checked += 1
	if ground == null or not ground.valid():
		res.fail("%s: the fixture does not read" % name)
		return
	var spec := spec_for(ground, forced)
	# --- form
	res.checked += 1
	if forced == &"" and (spec.form_intent != &"valley" or spec.form != &"valley"):
		res.fail("%s: the ground derives '%s', planned '%s'; wants valley, planned as itself" % [
			name, spec.form_intent, spec.form])
		return
	var t0 := Time.get_ticks_msec()
	var plan := VillageLotPlanner.plan_measured(spec, jobs)
	var plan_s := (Time.get_ticks_msec() - t0) / 1000.0
	res.checked += 1
	if plan.ground == null or plan.roads.is_empty():
		res.fail("%s: the plan was not sited on its ground" % name)
		return
	res.checked += 1
	if not EXPORTER.covers_plan(ground, plan):
		res.fail("%s: the sited site's corners leave the grid" % name)
	res.checked += 1
	if not plan.hamlets.is_empty():
		res.fail("%s: a valley is one body, it has %d hamlets" % [name, plan.hamlets.size()])
	# --- the river
	var river := -1
	for w in range(plan.water.size()):
		if plan.water[w]["kind"] == &"river":
			river = w
	res.checked += 1
	if river < 0:
		res.fail("%s: the river is not in the plan's water" % name)
	res.checked += 1
	if not plan.water_crossings.is_empty():
		res.fail("%s: %d crossings; the valley body stays on one bank" % [name, plan.water_crossings.size()])
	var wet_roads := 0
	for r in plan.roads:
		var ribbon := VillageSitePlanner.road_ribbon(r, false)
		for w in plan.water:
			if w["kind"] == &"race":
				continue
			if VillageLotPlanner.overlap_area(ribbon, w["poly"]) > 0.05:
				wet_roads += 1
	res.checked += 1
	if wet_roads > 0:
		res.fail("%s: %d roads run in the river" % [name, wet_roads])
	# --- the through road runs along the river, on its dry bank
	var river_note := ""
	var through: PackedVector2Array = plan.roads[0]["points"]
	res.checked += 1
	if river >= 0:
		var rb := Poly.bounding_rect(plan.water[river]["poly"])
		var near := INF
		var dists: Array[float] = []
		for p in through:
			var d: float = VillageMeasure.point_to_poly(p, plan.water[river]["poly"])
			near = minf(near, d)
			dists.append(d)
		dists.sort()
		var median: float = dists[dists.size() / 2]
		if rb.size.x < plan.site.size.x * RIVER_SHARE_MIN:
			res.fail("%s: the river is only %.0f m of a %.0f m site" % [name, rb.size.x, plan.site.size.x])
		elif near < 3.0 or median > ALONG_M:
			res.fail("%s: the through road is %.1f m from the river at the nearest and %.1f m at the median, wants over 3 and under %.0f" % [
				name, near, median, ALONG_M])
		river_note = " | road %.0f-%.0f m from the river (median %.0f)" % [near, dists[dists.size() - 1], median]

	# --- the ways up the sides
	var ways := 0
	var worst := {}
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		var cls: StringName = road["class"]
		var pts: PackedVector2Array = road["points"]
		if r > 0 and cls in [&"lane", &"track", &"steps"] \
				and VillageMeasure.point_to_polyline(pts[0], through) < 1.0:
			ways += 1
		var cap: float = float(VillageSitePlanner.road_rule(cls, plan.spec)["grade_max"])
		var g2: float = float(plan.ground.profile(pts)["grade_max"])
		worst[cls] = maxf(float(worst.get(cls, 0.0)), g2)
		res.checked += 1
		if g2 > cap + 1e-6:
			res.fail("%s: %s %d climbs %.1f %%, its class is laid to %.0f %%" % [name, cls, r, g2 * 100.0, cap * 100.0])
	res.checked += 1
	if ways < VillageValleyForm.LANES_MIN - 1:
		res.fail("%s: %d ways leave the through road, wants at least %d" % [name, ways, VillageValleyForm.LANES_MIN - 1])
	# --- shape
	var shape := VillageShape.measure(plan)
	var elong: float = float(shape.get("elongation", 0.0))
	var dead: float = float(shape.get("dead_end_ratio", -1.0))
	res.checked += 1
	if elong <= ELONGATION_MIN:
		res.fail("%s: elongation %.2f, wants over %.1f" % [name, elong, ELONGATION_MIN])
	res.checked += 1
	if dead < DEAD_END_BAND.x or dead > DEAD_END_BAND.y:
		res.fail("%s: dead_end_ratio %.3f outside the high-relief band %.2f-%.2f" % [name, dead,
			DEAD_END_BAND.x, DEAD_END_BAND.y])
	# --- lots on the ground (fall within the family's, no platform missing)
	PLANSUITE._lots_on_ground(res, name, plan, &"")
	# --- the village's own QA
	var t1 := Time.get_ticks_msec()
	var no_pure := func(_plan: VillagePlan) -> Array: return []
	var qa: Dictionary = VillageQA.new().check(plan, {&"pure": no_pure}, false)
	var qa_s := (Time.get_ticks_msec() - t1) / 1000.0
	res.checked += 1
	if not qa["ok"]:
		res.fail("%s: VillageQA: %s" % [name, "; ".join((qa["failures"] as Array).slice(0, 4))])
	res.checked += 1
	if plan.buildings.size() < jobs.size():
		res.fail("%s: %d of %d buildings placed" % [name, plan.buildings.size(), jobs.size()])
	# --- export
	if forced == &"":
		var out: Dictionary = EXPORTER.site_plan(plan, {"name": name})
		res.checked += 1
		if String(out.get("form", "")) != "valley" or String(out.get("form_intent", "")) != "valley":
			res.fail("%s: the exporter writes form '%s', form_intent '%s'" % [name, out.get("form"), out.get("form_intent")])
		res.checked += 1
		if not EXPORTER.form_intent_note(spec).is_empty():
			res.fail("%s: the exporter still notes a fallback: %s" % [name, EXPORTER.form_intent_note(spec)])
	if OS.get_environment("VALLEY_DUMP") != "":
		var lines := ""
		for b in plan.buildings:
			var c: Vector2 = VillageMeasure.centre(VillageMeasure.footprint_poly(b))
			var rq: BuildingRequest = b["request"]
			lines += " %s%s(%.0f,%.0f)r%d" % [rq.kind, "/" + String(rq.purpose) if rq.purpose != &"" else "", c.x, c.y, int(plan.lots[int(b["lot"])]["road"])]
		res.note("%s buildings:%s" % [name, lines])
		var left := {}
		for job in jobs:
			var jq: BuildingRequest = job["request"]
			var key := "%s/%s" % [jq.kind, jq.purpose]
			left[key] = int(left.get(key, 0)) + 1
		for b in plan.buildings:
			var bq: BuildingRequest = b["request"]
			var key2 := "%s/%s" % [bq.kind, bq.purpose]
			left[key2] = int(left.get(key2, 0)) - 1
		var missing := ""
		for k in left:
			if int(left[k]) > 0:
				missing += " %s x%d" % [k, int(left[k])]
		res.note("%s unplaced:%s" % [name, missing])
		var rl := ""
		for r in range(plan.roads.size()):
			var pts: PackedVector2Array = plan.roads[r]["points"]
			rl += " %d:%s(%.0f,%.0f)-(%.0f,%.0f)" % [r, plan.roads[r]["class"], pts[0].x, pts[0].y, pts[pts.size() - 1].x, pts[pts.size() - 1].y]
		res.note("%s roads:%s" % [name, rl])
		var cb := Poly.bounding_rect(plan.commons[0]["poly"])
		var fl := ""
		for b in plan.buildings:
			var fr: PackedVector2Array = plan.lots[int(b["lot"])]["front"]
			if VillageMeasure.point_to_poly(fr[0], plan.commons[0]["poly"]) < 40.0:
				fl += " (%.0f,%.0f)-(%.0f,%.0f)" % [fr[0].x, fr[0].y, fr[1].x, fr[1].y]
		res.note("%s common %s landmark %s fronts:%s" % [name, cb, plan.landmark_site.get("poly", PackedVector2Array()), fl])
	var gs := ""
	for cls in worst:
		gs += " %s %.0f%%" % [cls, float(worst[cls]) * 100.0]
	var fit_fall := 0.0
	for b in plan.buildings:
		fit_fall = maxf(fit_fall, float(plan.lots[int(b["lot"])]["ground_fit"]["fall_m"]) if plan.lots[int(b["lot"])].has("ground_fit") else 0.0)
	res.note("%-16s site %.0fx%.0f at (%.0f, %.0f) | %d/%d placed | ways %d |%s | elong %.2f dead %.3f | fall %.2f m | density %s%s | plan %.1f s, qa %.1f s" % [
		name, plan.site.size.x, plan.site.size.y, plan.site_anchor.x, plan.site_anchor.y,
		plan.buildings.size(), jobs.size(), ways, gs, elong, dead, fit_fall,
		qa["stats"].get("density"), river_note, plan_s, qa_s])


## A flat spec of the same inputs: never valley, nothing planned differently.
static func _flat(res: SuiteResult) -> void:
	var flat := spec_for(null)
	res.checked += 1
	if flat.form == &"valley" or flat.form_intent == &"valley":
		res.fail("flat: a spec with no ground derived the valley form")
	res.checked += 1
	if VillageSpec.FORM_FALLBACK.has(&"valley"):
		res.fail("flat: FORM_FALLBACK still maps valley")
	res.checked += 1
	if not (&"valley" in VillageSitePlanner.FORMS_SUPPORTED):
		res.fail("flat: valley is not a supported form")


## The same spec on the same ground twice, the siting cache cleared between.
static func _pure(res: SuiteResult) -> void:
	var a := VillageSitePlanner.plan(spec_for(terrain("river_valley")))
	VillageSiting.clear_cache()
	var b := VillageSitePlanner.plan(spec_for(terrain("river_valley")))
	res.checked += 1
	if not a.equals(b):
		res.fail("pure: the same spec on the same ground planned twice gave two site plans")
