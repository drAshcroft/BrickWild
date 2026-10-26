extends RefCounted
## The `shore` form (VTER-FORM-SHORE; docs/VILLAGE_TERRAIN.md "The shore
## form"): a fishing village of 50 people on lake and sea shores, the shore
## street laid along the ground's own shoreline.
##
##   form       the ground derives `shore` and the spec plans it (no
##              fallback); the cases that derive something else are forced
##   frame      the village is turned to face its water: the shoreline is
##              found in the frame and every house is dry
##   street     the shore street keeps one distance from the water all along
##              the curve (its spread is small) and, on the cove, really bends
##              (a straight street would have left the shore by its depth)
##   row        every building stands within the waterfront band of the water,
##              none on it; the houses stand on both sides of the street
##   share      VillageShape water_within_30m inside the real shore sites'
##              range (world_settlements.json: the 13 sites labelled shore run
##              0.0-0.658, median 0.121; the three of high confidence 0.284-
##              0.658 -- Hallstatt, Reine, Perast)
##   grades     every road within its class's grade_max on the plan's ground
##   landing    boats and racks stand on the water side, within reach of it
##   qa         VillageQA (scale, roads, lots, places, dressing, walking)
##   export     form `shore`, `form_intent` `shore`, no fallback note, the
##              shoreline
##   pure       the same spec on the same ground, the siting cache cleared, is
##              the same site plan
##   flat       no terrain: a shore spec plans as the straight strand, with no
##              shoreline, and FORM_FALLBACK no longer maps shore

const SYNTH := preload("res://tests/fixtures/terrain/synthetic_terrain.gd")
const EXPORTER := preload("res://tools/export_village_plan.gd")
const POPULATION := 50
const SEED := 4242
## [fixture, water, forced form (&"" = the ground's own)]
const CASES := [
	["lake_shore", &"lake", &""],
	["cove", &"lake", &""],
	["real30/hallstatt", &"lake", &""],
	["world90/limone_sul_garda", &"lake", &""],
	["world90/perast", &"coast", &""],
	["real30/manarola", &"coast", &"shore"],
]
## The survey's measure (see the header).
const WATER30 := Vector2(0.2, 0.66)
## The street's distance from the water varies by no more than this along it.
const STREET_SPREAD_M := 14.0
## A building's centre is within this of the water: the street's mean
## distance plus a lot's depth behind it.
const BAND_BEHIND_M := 48.0
## The cove's shoreline leaves its chord by about 18 m: a street that follows
## it leaves its own by more than this.
const COVE_BOW_M := 8.0


static func run() -> SuiteResult:
	var res := SuiteResult.new("vshore")
	var t0 := Time.get_ticks_msec()
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(spec_for(null, &"lake")))
	res.note("measured %d buildings once in %.1f s" % [jobs.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	_flat(res)
	for case in CASES:
		_case(res, jobs, case[0], case[1], case[2])
	_pure(res)
	res.note("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


static func spec_for(ground: VillageTerrain, water: StringName, form := &"") -> VillageSpec:
	var s := VillageSpec.new(SEED)
	s.population = POPULATION
	s.purpose = &"fishing"
	s.water = water
	s.terrain = ground
	s.generate(SEED)
	if form != &"":
		s.form = form
	return s


static func terrain(name: String) -> VillageTerrain:
	if name == "cove":
		return cove()
	if name.contains("/"):
		return VillageTerrain.from_file("res://tests/fixtures/terrain/%s.json" % name)
	return SYNTH.make(name)


## A lake whose shore bends: a round water of 140 m radius, its bank a circle
## the land rises 8 % from, the water level 4 m (the bank's height). The village
## stands on the nearest point of the bank; over the 144 m of its street the
## bank falls away from it by about 18 m on either side.
static func cove() -> VillageTerrain:
	var f := func(x: float, z: float) -> float:
		return 4.0 + 0.08 * (Vector2(x, z - 300.0).length() - 140.0)
	var t := VillageTerrain.from_sampler(f, Rect2(-400, -400, 800, 800), 5.0, 4.0)
	t.source = "suite:cove"
	return t


static func _case(res: SuiteResult, jobs: Array[Dictionary], name: String, water: StringName,
		forced: StringName) -> void:
	var ground := terrain(name)
	res.checked += 1
	if ground == null or not ground.valid():
		res.fail("%s: the fixture does not read" % name)
		return
	var spec := spec_for(ground, water, forced)
	# --- form
	res.checked += 1
	if forced == &"" and (spec.form_intent != &"shore" or spec.form != &"shore"):
		res.fail("%s: the ground derives '%s', planned '%s'; wants shore, planned as itself" % [
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
	# --- frame
	res.checked += 1
	if plan.shoreline.size() < 8:
		res.fail("%s: the plan carries no shoreline" % name)
		return
	var waters: Array[PackedVector2Array] = []
	for w in plan.water:
		if bool(w.get("ground", false)):
			waters.append(w["poly"])
	res.checked += 1
	if waters.is_empty():
		res.fail("%s: the ground's water is not in the plan" % name)
		return
	# --- street
	var street: PackedVector2Array = plan.roads[0]["points"]
	var d_min := INF
	var d_max := 0.0
	var d_sum := 0.0
	for p in street:
		var d := _to_water(p, waters)
		d_min = minf(d_min, d)
		d_max = maxf(d_max, d)
		d_sum += d
	var d_mean := d_sum / float(street.size())
	res.checked += 1
	if d_max - d_min > STREET_SPREAD_M:
		res.fail("%s: the shore street keeps %.1f-%.1f m from the water (spread %.1f, wants at most %.0f)" % [
			name, d_min, d_max, d_max - d_min, STREET_SPREAD_M])
	res.checked += 1
	if d_min < VillageShoreForm.ROAD_HALF_M:
		res.fail("%s: the shore street comes within %.1f m of the water" % [name, d_min])
	var bow := _bow(street)
	if name == "cove":
		res.checked += 1
		if bow < COVE_BOW_M:
			res.fail("%s: the street bows %.1f m off its chord, the shore bends more than that" % [name, bow])
	# --- row
	var near_max := 0.0
	var within := 0
	var wet_bldgs := 0
	var seaward := 0
	var landward := 0
	var props_ok := true
	for b in plan.buildings:
		var foot := VillageMeasure.footprint_poly(b)
		var c := VillageMeasure.centre(foot)
		var d := _to_water(c, waters)
		near_max = maxf(near_max, d)
		if d <= d_mean + BAND_BEHIND_M:
			within += 1
		for w in waters:
			if VillageLotPlanner.overlap_area(foot, w) > 0.05:
				wet_bldgs += 1
		var side := _side_of_street(c, street)
		if side > 0.0:
			seaward += 1
		else:
			landward += 1
	res.checked += 1
	if wet_bldgs > 0:
		res.fail("%s: %d buildings stand on the water" % [name, wet_bldgs])
	res.checked += 1
	if within < plan.buildings.size():
		res.fail("%s: %d of %d buildings stand beyond the waterfront band (%.0f m, farthest %.1f m)" % [
			name, plan.buildings.size() - within, plan.buildings.size(), d_mean + BAND_BEHIND_M, near_max])
	res.checked += 1
	if seaward < 2 or landward < 2:
		res.fail("%s: %d buildings on the water side of the street, %d behind it; wants both" % [
			name, seaward, landward])
	res.checked += 1
	if plan.buildings.size() < jobs.size():
		res.fail("%s: %d of %d buildings placed" % [name, plan.buildings.size(), jobs.size()])
	# --- share
	var shape := VillageShape.measure(plan)
	var w30: float = float(shape.get("water_within_30m", -1.0))
	res.checked += 1
	if w30 < WATER30.x or w30 > WATER30.y:
		res.fail("%s: water_within_30m %.3f outside the real shore sites' %.2f-%.2f" % [
			name, w30, WATER30.x, WATER30.y])
	# --- landing
	var boats := 0
	var far_boats := 0
	for p in plan.props:
		var key := String(p["key"]).to_lower()
		if key.contains("boat") or key.contains("rack"):
			boats += 1
			if _to_water(p["pos"], waters) > 30.0:
				far_boats += 1
	res.checked += 1
	if far_boats > 0:
		res.fail("%s: %d boats or racks stand more than 30 m from the water" % [name, far_boats])
	# --- grades
	var worst := {}
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		var cls: StringName = road["class"]
		var cap: float = float(VillageSitePlanner.road_rule(cls, plan.spec)["grade_max"])
		var g2: float = float(plan.ground.profile(road["points"])["grade_max"])
		worst[cls] = maxf(float(worst.get(cls, 0.0)), g2)
		res.checked += 1
		if g2 > cap + 1e-6:
			res.fail("%s: %s %d climbs %.1f %%, its class is laid to %.0f %%" % [name, cls, r, g2 * 100.0, cap * 100.0])
	# --- the village's own QA
	var t1 := Time.get_ticks_msec()
	var no_pure := func(_plan: VillagePlan) -> Array: return []
	var qa: Dictionary = VillageQA.new().check(plan, {&"pure": no_pure}, false)
	var qa_s := (Time.get_ticks_msec() - t1) / 1000.0
	res.checked += 1
	if not qa["ok"]:
		res.fail("%s: VillageQA: %s" % [name, "; ".join((qa["failures"] as Array).slice(0, 4))])
	# --- export
	var out: Dictionary = EXPORTER.site_plan(plan, {"name": name})
	res.checked += 1
	if String(out.get("form", "")) != "shore":
		res.fail("%s: the exporter writes form '%s'" % [name, out.get("form")])
	res.checked += 1
	if forced == &"" and String(out.get("form_intent", "")) != "shore":
		res.fail("%s: the exporter writes form_intent '%s'" % [name, out.get("form_intent")])
	res.checked += 1
	if forced == &"" and not EXPORTER.form_intent_note(spec).is_empty():
		res.fail("%s: the exporter still notes a fallback: %s" % [name, EXPORTER.form_intent_note(spec)])
	res.checked += 1
	if (out.get("shoreline_m", []) as Array).size() != plan.shoreline.size():
		res.fail("%s: the exporter writes %d shoreline points of %d" % [name,
			(out.get("shoreline_m", []) as Array).size(), plan.shoreline.size()])
	var gs := ""
	for cls in worst:
		gs += " %s %.0f%%" % [cls, float(worst[cls]) * 100.0]
	res.note("%-26s %s | street %.1f-%.1f m from water, bow %.1f | sea/land %d/%d, farthest %.1f m | w30 %.3f | boats %d | density %s |%s | site %s yaw %.0f | plan %.1f s, qa %.1f s" % [
		name, spec.form, d_min, d_max, bow, seaward, landward, near_max, w30, boats,
		qa["stats"].get("density"), gs, plan.site, rad_to_deg(plan.site_yaw), plan_s, qa_s])


## Distance from a point to the nearest ground water.
static func _to_water(p: Vector2, waters: Array[PackedVector2Array]) -> float:
	var best := INF
	for w in waters:
		best = minf(best, VillageMeasure.point_to_poly(p, w))
	return best


## How far a polyline strays from the chord between its ends.
static func _bow(pts: PackedVector2Array) -> float:
	var a := pts[0]
	var b := pts[pts.size() - 1]
	var worst := 0.0
	for p in pts:
		worst = maxf(worst, absf((b - a).normalized().cross(p - a)))
	return worst


## >0 on the water side (+y) of the street, <0 behind it.
static func _side_of_street(p: Vector2, street: PackedVector2Array) -> float:
	var best := INF
	var side := 0.0
	for i in range(street.size() - 1):
		var q := Geometry2D.get_closest_point_to_segment(p, street[i], street[i + 1])
		var d := p.distance_to(q)
		if d < best:
			best = d
			side = p.y - q.y
	return side


## A shore spec with no ground is the straight strand: no shoreline, the old
## fallback line gone.
static func _flat(res: SuiteResult) -> void:
	var flat := spec_for(null, &"lake", &"shore")
	var plan := VillageSitePlanner.plan(flat)
	res.checked += 1
	if not plan.shoreline.is_empty():
		res.fail("flat: a plan with no ground has a shoreline")
	res.checked += 1
	if plan.roads.is_empty() or plan.water.is_empty():
		res.fail("flat: a shore spec with no ground did not plan as a strand")
	res.checked += 1
	if VillageSpec.FORM_FALLBACK.has(&"shore"):
		res.fail("flat: FORM_FALLBACK still maps shore")
	res.checked += 1
	if not (&"shore" in VillageSitePlanner.FORMS_SUPPORTED):
		res.fail("flat: FORMS_SUPPORTED lacks shore")


## The same spec on the same ground twice, the siting cache cleared between.
static func _pure(res: SuiteResult) -> void:
	var a := VillageSitePlanner.plan(spec_for(terrain("cove"), &"lake"))
	VillageShoreForm.clear_cache()
	VillageSiting.clear_cache()
	var b := VillageSitePlanner.plan(spec_for(terrain("cove"), &"lake"))
	res.checked += 1
	if not a.equals(b):
		res.fail("pure: the same spec on the same ground planned twice gave two site plans")
	res.checked += 1
	if a.shoreline.is_empty():
		res.fail("pure: the cove has no shoreline")
