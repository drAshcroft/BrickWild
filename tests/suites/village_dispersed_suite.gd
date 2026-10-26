extends RefCounted
## The `dispersed` form (VTER-FORM-DISPERSED; docs/VILLAGE_TERRAIN.md "The
## dispersed form"): a farming village of 60 people planned on hillsides the
## ground reads as dispersed, measured as the world survey measures a real one.
##
##   form       the ground derives `dispersed` and the spec plans it (no
##              fallback): Ushguli, the synthetic valley, Rubanda (world90,
##              hand-labelled dispersed, high confidence); the spur derives
##              `crest` and is planned dispersed by force
##   hamlets    2-5, each with its own common and a well on it, each housing
##              at least QUOTA_MIN households; the landmark in the main one
##   shape      VillageShape body_share 0.2-0.6 and clusters_ge5 2-5 (the
##              survey's 45 m linkage): more than one settlement body
##   reach      from every gate, every hamlet's well can be walked to
##   grades     every road within its class's grade_max on the plan's ground
##   qa         VillageQA (scale -- the whole settlement housed, its density
##              over its hamlets' own ground --, roads, lots, places,
##              dressing, walking; no per-building QA, and `pure` is checked
##              below because the form is forced on the spur)
##   pure       the same spec on the same ground, siting cache cleared, is the
##              same site plan
##   export     the exporter writes form `dispersed`, `form_intent`
##              `dispersed`, no fallback note, and the hamlets
##   flat       a flat spec of the same inputs is not dispersed and has no
##              hamlets: nothing flat changes

const SYNTH := preload("res://tests/fixtures/terrain/synthetic_terrain.gd")
const EXPORTER := preload("res://tools/export_village_plan.gd")
const POPULATION := 60
const SEED := 4242
## [fixture, forced form (&"" = the ground's own)]
const CASES := [
	["real30/ushguli", &""],
	["valley", &""],
	["spur", &"dispersed"],
	["world90/rubanda", &""],
]
const BODY_SHARE := Vector2(0.2, 0.6)
const CLUSTERS := Vector2i(2, 5)
const WELL_REACH := 3.0
## VTER-DISPERSED-2: hamlets lie 150-400 m from their nearest neighbour
## (Ushguli, Batad: two to four hundred metres).
const SPACING_M := Vector2(150.0, 400.0)


static func run() -> SuiteResult:
	var res := SuiteResult.new("vdispersed")
	var t0 := Time.get_ticks_msec()
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(spec_for(null)))
	res.note("measured %d buildings once in %.1f s" % [jobs.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	_flat(res)
	for case in CASES:
		_case(res, jobs, case[0], case[1])
	_pure(res)
	res.note("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


static func spec_for(ground: VillageTerrain, form := &"") -> VillageSpec:
	var s := VillageSpec.new(SEED)
	s.population = POPULATION
	s.purpose = &"farming"
	s.terrain = ground
	s.generate(SEED)
	if form != &"":
		s.form = form
	return s


static func terrain(name: String) -> VillageTerrain:
	if name.contains("/"):
		return VillageTerrain.from_file("res://tests/fixtures/terrain/%s.json" % name)
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
	if forced == &"" and (spec.form_intent != &"dispersed" or spec.form != &"dispersed"):
		res.fail("%s: the ground derives '%s', planned '%s'; wants dispersed, planned as itself" % [
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
	# --- hamlets
	var n: int = plan.hamlets.size()
	res.checked += 1
	if n < VillageDispersedForm.HAMLETS_MIN or n > VillageDispersedForm.HAMLETS_MAX:
		res.fail("%s: %d hamlets, wants %d-%d" % [name, n, VillageDispersedForm.HAMLETS_MIN,
			VillageDispersedForm.HAMLETS_MAX])
		return
	# --- spacing, and the link of each hamlet to the main one
	for i in range(n):
		var near := INF
		for j in range(n):
			if i != j:
				near = minf(near, (plan.hamlets[i]["seat"] as Vector2).distance_to(plan.hamlets[j]["seat"]))
		res.checked += 1
		if near < SPACING_M.x or near > SPACING_M.y:
			res.fail("%s: hamlet %d is %.0f m from its nearest neighbour, wants %.0f-%.0f" % [
				name, i, near, SPACING_M.x, SPACING_M.y])
		if bool(plan.hamlets[i]["main"]):
			continue
		var link: int = VillageDispersedForm.spine_of(plan, i)
		res.checked += 1
		if link < 0 or plan.roads[link]["class"] != &"track":
			res.fail("%s: hamlet %d is reached by %s, not a cart track" % [name, i,
				"nothing" if link < 0 else String(plan.roads[link]["class"])])
	var houses: Array[int] = []
	var placed: Array[int] = []
	for _h in plan.hamlets:
		houses.append(0)
		placed.append(0)
	for b in plan.buildings:
		var at: Vector2 = VillageMeasure.centre(VillageMeasure.footprint_poly(b))
		var h: int = VillageDispersedForm.hamlet_of(plan, at)
		placed[h] += 1
		if b["kind"] == &"house":
			houses[h] += 1
	var wells: Array[Vector2] = []
	for p in plan.props:
		if String(p["key"]).to_lower().begins_with("well"):
			wells.append(p["pos"])
	for i in range(n):
		var h: Dictionary = plan.hamlets[i]
		res.checked += 1
		if houses[i] < VillageDispersedForm.QUOTA_MIN:
			res.fail("%s: hamlet %d houses %d households, wants at least %d" % [name, i, houses[i],
				VillageDispersedForm.QUOTA_MIN])
		var common: PackedVector2Array = plan.commons[int(h["common"])]["poly"]
		var has_well := false
		for w in wells:
			has_well = has_well or Poly.contains_point(common, w)
		res.checked += 1
		if not has_well:
			res.fail("%s: hamlet %d has no well on its common" % [name, i])
	res.checked += 1
	var landmark := -1
	for i in range(plan.buildings.size()):
		if plan.buildings[i]["kind"] in [&"church", &"temple"]:
			landmark = VillageDispersedForm.hamlet_of(plan,
				VillageMeasure.centre(VillageMeasure.footprint_poly(plan.buildings[i])))
	if landmark < 0 or not bool(plan.hamlets[landmark]["main"]):
		res.fail("%s: the landmark stands in hamlet %d, not the main one" % [name, landmark])
	# --- shape
	var shape := VillageShape.measure(plan)
	var body: float = float(shape.get("body_share", 0.0))
	var ge5: int = int(shape.get("clusters_ge5", 0))
	res.checked += 1
	if body < BODY_SHARE.x or body > BODY_SHARE.y:
		res.fail("%s: body_share %.3f outside %.1f-%.1f" % [name, body, BODY_SHARE.x, BODY_SHARE.y])
	res.checked += 1
	if ge5 < CLUSTERS.x or ge5 > CLUSTERS.y:
		res.fail("%s: clusters_ge5 %d outside %d-%d" % [name, ge5, CLUSTERS.x, CLUSTERS.y])
	# --- reach: every hamlet's well from every gate
	for g in VillageMeasure.gates(plan):
		var grid := VillageNavCheck.build_grid(plan)
		res.checked += 1
		if not grid.flood_from(g, 3.0):
			res.fail("%s: nowhere to stand at the gate at %v" % [name, g])
			continue
		for i in range(n):
			# the hamlet's own well, or its common's centre where it has none
			# (that is failed above)
			var well: Vector2 = plan.hamlets[i]["seat"]
			for w in wells:
				if Poly.contains_point(plan.commons[int(plan.hamlets[i]["common"])]["poly"], w):
					well = w
			res.checked += 1
			if not grid.reached(Rect2(well, Vector2.ZERO), WELL_REACH):
				res.fail("%s: hamlet %d's well cannot be walked to from the gate at %v" % [name, i, g])
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
	res.checked += 1
	if plan.buildings.size() < jobs.size():
		res.fail("%s: %d of %d buildings placed" % [name, plan.buildings.size(), jobs.size()])
	# --- export
	if forced == &"":
		var out: Dictionary = EXPORTER.site_plan(plan, {"name": name})
		res.checked += 1
		if String(out.get("form", "")) != "dispersed" or String(out.get("form_intent", "")) != "dispersed":
			res.fail("%s: the exporter writes form '%s', form_intent '%s'" % [name, out.get("form"), out.get("form_intent")])
		res.checked += 1
		if not EXPORTER.form_intent_note(spec).is_empty():
			res.fail("%s: the exporter still notes a fallback: %s" % [name, EXPORTER.form_intent_note(spec)])
		res.checked += 1
		if (out.get("hamlets", []) as Array).size() != n:
			res.fail("%s: the exporter writes %d hamlets of %d" % [name, (out.get("hamlets", []) as Array).size(), n])
	var hs := ""
	for i in range(n):
		hs += " %d:%dh/%db" % [i, houses[i], placed[i]]
	var gs := ""
	for cls in worst:
		gs += " %s %.0f%%" % [cls, float(worst[cls]) * 100.0]
	res.note("%-18s %s hamlets%s | body %.3f ge5 %d | density %s | fields %d |%s | plan %.1f s, qa %.1f s" % [
		name, n, hs, body, ge5, qa["stats"].get("density"), plan.fields.size(), gs, plan_s, qa_s])


## A flat spec of the same inputs: the old rule, never dispersed, no hamlets.
static func _flat(res: SuiteResult) -> void:
	var flat := spec_for(null)
	res.checked += 1
	if flat.form == &"dispersed" or flat.form_intent == &"dispersed":
		res.fail("flat: a spec with no ground derived the dispersed form")
	res.checked += 1
	if not VillageSitePlanner.plan(flat).hamlets.is_empty():
		res.fail("flat: a flat plan has hamlets")
	res.checked += 1
	if VillageSpec.FORM_FALLBACK.has(&"dispersed"):
		res.fail("flat: FORM_FALLBACK still maps dispersed")


## The same spec on the same ground twice, the siting cache cleared between.
static func _pure(res: SuiteResult) -> void:
	var a := VillageSitePlanner.plan(spec_for(terrain("real30/ushguli")))
	VillageSiting.clear_cache()
	var b := VillageSitePlanner.plan(spec_for(terrain("real30/ushguli")))
	res.checked += 1
	if not a.equals(b):
		res.fail("pure: the same spec on the same ground planned twice gave two site plans")
	res.checked += 1
	if a.hamlets.size() != b.hamlets.size() or a.hamlets.is_empty():
		res.fail("pure: the hamlets differ or are missing")
