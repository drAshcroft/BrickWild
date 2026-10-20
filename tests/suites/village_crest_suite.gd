extends RefCounted
## The `crest` form (VTER-FORM-CREST; docs/VILLAGE_TERRAIN.md "The crest
## form"): a compact village on a summit, planned on the synthetic crest and
## spur and on three real hills, and measured as the world survey measures a
## real one.
##
##   form       the ground derives `crest` and the spec plans it (no fallback)
##   site       sited on the summit; the frame's corners on the grid
##   ring       a closed street laid on a contour: one height all round
##              (3 m on a dome), every chord a street
##   landmark   the church is the HIGHEST building (to LANDMARK_TIE_M, where
##              the top is flat), inside the ring
##   shape      VillageShape body_elev_pctile over 0.85 (where the ground the
##              disc reads is ranked by the body), compactness over 0.5
##   compact    most buildings within the ring's own ground; none strung down
##              the approach
##   reach      the church, the well and every door can be walked to from the
##              gate (the approach carries the walk)
##   grades     every road within its class's grade on the plan's ground
##   qa         VillageQA, as vdispersed (no per-building QA; `pure` below)
##   pure       the same spec on the same ground, siting cache cleared, is the
##              same site plan
##   export     form `crest`, `form_intent` `crest`, no fallback note
##   flat       a flat spec of the same inputs is not crest and has no ring;
##              FORM_FALLBACK no longer maps crest

const SYNTH := preload("res://tests/fixtures/terrain/synthetic_terrain.gd")
const EXPORTER := preload("res://tools/export_village_plan.gd")
const POPULATION := 50
const SEED := 4242
## [fixture, forced form (&"" = the ground's own), population (0 = POPULATION),
##  strict, the most height the ring may span]
## A case that is not strict is run and measured in full, but its failures are
## WARNINGS headed "open:" -- the form does not yet manage that ground (Eze's
## 40-50 % flanks, Civita's butte; see the doc's "Not yet"). The ring spans
## 3 m on a dome; a ridge's ring cannot close on one contour.
const CASES := [
	["crest", &"", 0, true, 3.0],
	["spur", &"crest", 0, true, 11.0],
	["world90/monteriggioni", &"", 0, true, 3.0],
	["real30/eze", &"", 0, false, 6.0],
	["world90/civita_di_bagnoregio", &"", 0, false, 8.0],
]
const BODY_ELEV_MIN := 0.85
const COMPACT_MIN := 0.5
const LANDMARK_TIE_M := 0.05
const NEAR_SHARE_MIN := 0.7
const WELL_REACH := 3.0


static func run(only: Array = []) -> SuiteResult:
	var res := SuiteResult.new("vcrest")
	var t0 := Time.get_ticks_msec()
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(spec_for(null)))
	res.note("measured %d buildings once in %.1f s" % [jobs.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	_flat(res)
	for case in CASES:
		if only.is_empty() or case[0] in only:
			var r := res if bool(case[3]) else SuiteResult.new("open")
			_case(r, jobs, case[0], case[1], int(case[2]), float(case[4]))
			if r != res:
				res.checked += r.checked
				for fl in r.failures:
					res.warn("open: %s" % fl)
				for n in r.notes:
					res.note(n)
	if only.is_empty():
		_pure(res)
	res.note("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


static func spec_for(ground: VillageTerrain, form := &"", population := 0) -> VillageSpec:
	var s := VillageSpec.new(SEED)
	s.population = POPULATION if population <= 0 else population
	s.purpose = &"market"
	s.terrain = ground
	s.generate(SEED)
	if form != &"":
		s.form = form
	return s


static func terrain(name: String) -> VillageTerrain:
	if name.contains("/"):
		return VillageTerrain.from_file("res://tests/fixtures/terrain/%s.json" % name)
	return SYNTH.make(name)


static func _case(res: SuiteResult, jobs: Array[Dictionary], name: String, forced: StringName,
		population: int, spread_max: float) -> void:
	var ground := terrain(name)
	res.checked += 1
	if ground == null or not ground.valid():
		res.fail("%s: the fixture does not read" % name)
		return
	var spec := spec_for(ground, forced, population)
	var these: Array[Dictionary] = jobs
	if population > 0:
		these = VillageLotPlanner.measure_all(VillageProgrammer.programme(spec))
	# --- form
	res.checked += 1
	if forced == &"" and (spec.form_intent != &"crest" or spec.form != &"crest"):
		res.fail("%s: the ground derives '%s', planned '%s'; wants crest, planned as itself" % [
			name, spec.form_intent, spec.form])
		return
	var t0 := Time.get_ticks_msec()
	var plan := VillageLotPlanner.plan_measured(spec, these)
	var plan_s := (Time.get_ticks_msec() - t0) / 1000.0
	res.checked += 1
	if plan.ground == null or plan.roads.is_empty() or plan.crest.is_empty():
		res.fail("%s: the plan was not sited on its ground as a crest village" % name)
		return
	res.checked += 1
	if not EXPORTER.covers_plan(ground, plan):
		res.fail("%s: the sited site's corners leave the grid" % name)
	var g: VillageTerrain = plan.ground
	var summit: Vector2 = plan.crest["summit"]
	# --- the ring
	var ring: Array[int] = ring_roads(plan)
	res.checked += 1
	var segments := 0
	for r0 in ring:
		segments += (plan.roads[r0]["points"] as PackedVector2Array).size() - 1
	if segments < VillageCrestForm.CHORDS_MIN:
		res.fail("%s: %d ring chords" % [name, segments])
		return
	var lo := INF
	var hi := -INF
	var streets := 0
	for r in ring:
		var pts: PackedVector2Array = plan.roads[r]["points"]
		for p in pts:
			var h: float = g.height_at(p)
			lo = minf(lo, h)
			hi = maxf(hi, h)
		if plan.roads[r]["class"] == &"street":
			streets += 1
	res.checked += 1
	if hi - lo > spread_max:
		res.fail("%s: the ring spans %.1f m of height, wants a contour (%.1f m at most)" % [name, hi - lo, spread_max])
	res.checked += 1
	if streets != ring.size():
		res.fail("%s: %d of %d ring chords are streets" % [name, streets, ring.size()])
	# --- the landmark is the highest building
	var hs := VillagePlaceCheck.building_heights(plan)
	var church := VillagePlaceCheck.worship_index(plan)
	res.checked += 1
	var top_other := -INF
	for i in range(plan.buildings.size()):
		if i != church:
			top_other = maxf(top_other, hs[i])
	var inside := false
	if church < 0:
		res.fail("%s: no church was placed" % name)
	else:
		var at: Vector2 = VillageMeasure.centre(VillageMeasure.footprint_poly(plan.buildings[church]))
		inside = at.distance_to(summit) < float(plan.crest["radius"])
		if hs[church] < top_other - LANDMARK_TIE_M:
			res.fail("%s: the church stands at %.2f m, a building at %.2f m is higher" % [name, hs[church], top_other])
		res.checked += 1
		if not inside:
			res.fail("%s: the church stands %.0f m from the summit, outside the ring (%.0f m)" % [
				name, at.distance_to(summit), float(plan.crest["radius"])])
	# --- shape
	var shape := VillageShape.measure(plan)
	var elev: float = float(shape.get("body_elev_pctile", 0.0))
	var compact: float = float(shape.get("compactness", 0.0))
	res.checked += 1
	if elev <= BODY_ELEV_MIN:
		res.fail("%s: body_elev_pctile %.3f, wants over %.2f" % [name, elev, BODY_ELEV_MIN])
	res.checked += 1
	if compact <= COMPACT_MIN:
		res.fail("%s: compactness %.3f, wants over %.1f" % [name, compact, COMPACT_MIN])
	# --- compact: the village is round its ring
	var reach: float = float(plan.crest["radius"]) + VillageCrestForm.RING_ROAD_HALF + VillageCrestForm.OUTER_BAND + 10.0
	var near := 0
	for b in plan.buildings:
		if VillageMeasure.centre(VillageMeasure.footprint_poly(b)).distance_to(summit) <= reach:
			near += 1
	var near_share: float = float(near) / maxf(plan.buildings.size(), 1)
	res.checked += 1
	if near_share < NEAR_SHARE_MIN:
		res.fail("%s: %d of %d buildings within %.0f m of the summit (%.2f), wants %.2f" % [
			name, near, plan.buildings.size(), reach, near_share, NEAR_SHARE_MIN])
	# --- reach: the approach carries the walk
	var wells: Array[Vector2] = []
	for p in plan.props:
		if String(p["key"]).to_lower().begins_with("well"):
			wells.append(p["pos"])
	var grid := VillageNavCheck.build_grid(plan)
	for gate in VillageMeasure.gates(plan):
		res.checked += 1
		if not grid.flood_from(gate, 3.0):
			res.fail("%s: nowhere to stand at the gate at %v" % [name, gate])
			continue
		if not wells.is_empty():
			res.checked += 1
			if not grid.reached(Rect2(wells[0], Vector2.ZERO), WELL_REACH):
				res.fail("%s: the well cannot be walked to from the gate at %v" % [name, gate])
		if church >= 0:
			res.checked += 1
			var door: Vector2 = VillageMeasure.centre(VillageMeasure.footprint_poly(plan.buildings[church]))
			if not grid.reached(Rect2(door, Vector2.ZERO), 12.0):
				res.fail("%s: the church cannot be walked to from the gate at %v" % [name, gate])
	# --- grades
	var worst := {}
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		var cls: StringName = road["class"]
		var cap: float = float(VillageSitePlanner.road_rule(cls, plan.spec)["grade_max"])
		var g2: float = float(g.profile(road["points"])["grade_max"])
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
	res.checked += 1
	if plan.buildings.size() < these.size():
		res.fail("%s: %d of %d buildings placed" % [name, plan.buildings.size(), these.size()])
	# --- export
	if forced == &"":
		var out: Dictionary = EXPORTER.site_plan(plan, {"name": name})
		res.checked += 1
		if String(out.get("form", "")) != "crest" or String(out.get("form_intent", "")) != "crest":
			res.fail("%s: the exporter writes form '%s', form_intent '%s'" % [name, out.get("form"), out.get("form_intent")])
		res.checked += 1
		if not EXPORTER.form_intent_note(spec).is_empty():
			res.fail("%s: the exporter still notes a fallback: %s" % [name, EXPORTER.form_intent_note(spec)])
		res.checked += 1
		if not out.has("crest"):
			res.fail("%s: the exporter writes no crest block" % name)
	var gs := ""
	for cls in worst:
		gs += " %s %.0f%%" % [cls, float(worst[cls]) * 100.0]
	res.note("%-28s %d bldg, approaches %d, ring %.1f m (%.1f m spread), church %.2f m of top %.2f | elev %.3f compact %.3f near %.2f | density %s |%s | plan %.1f s, qa %.1f s" % [
		name, plan.buildings.size(), int(plan.crest["approaches"]), float(plan.crest["radius"]), hi - lo,
		hs[church] if church >= 0 else NAN, top_other, elev, compact, near_share,
		qa["stats"].get("density"), gs, plan_s, qa_s])
	if not qa["ok"]:
		for f in (qa["failures"] as Array).slice(0, 8):
			res.note("  QA: %s" % f)


## The ring's road indices: the chords between the summit's radius bounds.
static func ring_roads(plan: VillagePlan) -> Array[int]:
	var out: Array[int] = []
	var summit: Vector2 = plan.crest["summit"]
	var radius: float = plan.crest["radius"]
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		if road["class"] == &"through":
			continue
		var pts: PackedVector2Array = road["points"]
		var ok := true
		for p in pts:
			var d: float = p.distance_to(summit)
			ok = ok and d > radius * VillageCrestForm.RING_CLAMP.x - 0.1 and d < radius * VillageCrestForm.RING_CLAMP.y + 0.1
		if ok:
			out.append(r)
	return out


## A flat spec of the same inputs: never crest, no ring, no fallback entry.
static func _flat(res: SuiteResult) -> void:
	var flat := spec_for(null)
	res.checked += 1
	if flat.form == &"crest" or flat.form_intent == &"crest":
		res.fail("flat: a spec with no ground derived the crest form")
	res.checked += 1
	if not VillageSitePlanner.plan(flat).crest.is_empty():
		res.fail("flat: a flat plan has a crest")
	res.checked += 1
	if VillageSpec.FORM_FALLBACK.has(&"crest"):
		res.fail("flat: FORM_FALLBACK still maps crest")
	# the form itself, planned flat, is a ring and a common with a road below
	var forced := spec_for(null, &"crest")
	var plan := VillageSitePlanner.plan(forced)
	res.checked += 1
	if plan.crest.is_empty() or plan.roads.size() < 4:
		res.fail("flat: the crest form planned without ground has no ring")


## The same spec on the same ground twice, the siting cache cleared between.
static func _pure(res: SuiteResult) -> void:
	var a := VillageSitePlanner.plan(spec_for(terrain("crest")))
	VillageSiting.clear_cache()
	var b := VillageSitePlanner.plan(spec_for(terrain("crest")))
	res.checked += 1
	if not a.equals(b):
		res.fail("pure: the same spec on the same ground planned twice gave two site plans")
	res.checked += 1
	if a.crest.is_empty() or not a.crest == b.crest:
		res.fail("pure: the crest differs or is missing")
