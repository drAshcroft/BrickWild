extends RefCounted
## The island fill (VTER-ISLAND-FILL; docs/VILLAGE_TERRAIN.md "The island
## fill"): a village that is its island -- Isola dei Pescatori -- built out to
## the water all round, a ring quay inside the shore and a spine from landing
## to landing.
##
##   derive    an enclosed island the programme fills derives `water` (row 0),
##             and a village too small for it, a cone island too big for it, the
##             90 m DEM's smear of the real Isola (20 ha) and a lagoon without
##             an island do not (VillageIslandForm.fits)
##   frame     the plan is turned along the island's long axis, its shoreline is
##             the island's outline, the ring's arcs join, the spine runs from a
##             landing to a landing (VillageIslandCheck)
##   housed    every building of the programme stands, none on the water
##   fill      the island is built out: 85 % of its dry ground within 30 m of a
##             building (VillageIslandCheck.REACH_MIN), and the ring stands
##             within RING_GAP_MAX of the shore
##   qa        VillageQA (scale, roads, lots, places, dressing, walking)
##   walk      from a landing every door is walked to; with the spine taken away
##             the doors are not (the control)
##   export    form `water`, the island written
##   mesh      the village built and assembled: components are triangles, the
##             ground leaves the island dry and the rest of VillageGroundCheck
##   controls  half the buildings taken away fails `fill`; the same ground with
##             the form off is not an island plan; a ring opened fails `ring`
##   pure      the same spec on the same ground is the same site plan
##
## `ISLAND_DUMP=1` prints the plan's ascii map.

const SYNTH := preload("res://tests/fixtures/terrain/synthetic_terrain.gd")
const EXPORTER := preload("res://tools/export_village_plan.gd")
const WORLD90 := "res://tests/fixtures/terrain/world90/isola_dei_pescatori.json"
## The survey's own spec for Isola dei Pescatori: 89 people, fishing, a coast.
const POPULATION := 89
const SEED := 4242
## The ring's mean distance inside the shore, at most: it stands at the shore,
## not floating inland of it.
const RING_GAP_MAX := 24.0


static func run() -> SuiteResult:
	var res := SuiteResult.new("vislandfill")
	var t0 := Time.get_ticks_msec()
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(spec_for(null)))
	res.note("measured %d buildings once in %.1f s" % [jobs.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	_derive(res)
	_islet(res, jobs)
	_off(res, jobs)
	_pure(res)
	res.note("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


static func spec_for(ground: VillageTerrain, population := POPULATION) -> VillageSpec:
	var s := VillageSpec.new(SEED)
	s.population = population
	s.purpose = &"fishing"
	s.water = &"coast"
	s.terrain = ground
	s.generate(SEED)
	return s


# ----------------------------------------------------------------------- derive

static func _derive(res: SuiteResult) -> void:
	var islet: VillageTerrain = SYNTH.make("islet")
	var s := spec_for(islet)
	res.checked += 3
	if s.form_intent != &"water" or s.form != &"water":
		res.fail("derive: the islet derives '%s', planned '%s'; wants water" % [s.form_intent, s.form])
	if not VillageIslandForm.fits(s):
		res.fail("derive: the islet is not an island village for %d households (island %s)" % [
			s.households, VillageIslandForm.describe(islet)])
	var d := VillageIslandForm.describe(islet)
	if d.is_empty() or absf(float(d["yaw"]) - 0.0) > 0.1 and absf(float(d["yaw"]) - PI) > 0.1:
		res.fail("derive: the islet's long axis is %s, wants x" % [d.get("yaw")])
	# a hamlet is too small for it: the window is mostly wet, the old row 1
	var hamlet := spec_for(islet, 20)
	res.checked += 2
	if VillageIslandForm.fits(hamlet):
		res.fail("derive: a 20-person village is an island village on %.1f ha" % (float(d["area_m2"]) / 10000.0))
	if hamlet.form_intent != &"shore":
		res.fail("derive: a 20-person village on the islet derives '%s', the old rule's shore" % hamlet.form_intent)
	# the cone island is 19 ha: far more than 89 people fill
	var cone: VillageTerrain = SYNTH.make("island")
	res.checked += 1
	if VillageIslandForm.fits(spec_for(cone)):
		res.fail("derive: the 19 ha cone island is an island village for 89 people")
	# the real Isola on the 90 m DEM is 20 ha (the grid smears a 3.5 ha island)
	var world: VillageTerrain = VillageTerrain.from_file(WORLD90)
	res.checked += 2
	if world == null or not world.valid():
		res.fail("derive: the Isola dei Pescatori fixture does not read")
	else:
		var ws := spec_for(world)
		if VillageIslandForm.fits(ws):
			res.fail("derive: the 90 m DEM's 20 ha island is an island village for 89 people")
		if ws.form_intent != &"water":
			res.fail("derive: the real Isola derives '%s'; wants water as before" % ws.form_intent)
	# a lagoon has no island at all
	res.checked += 1
	if not VillageIslandForm.describe(SYNTH.make("lagoon")).is_empty():
		res.fail("derive: the lagoon has an island")


# ------------------------------------------------------------------------ islet

static func _islet(res: SuiteResult, jobs: Array[Dictionary]) -> void:
	var name := "islet"
	var ground: VillageTerrain = SYNTH.make("islet")
	var spec := spec_for(ground)
	var t0 := Time.get_ticks_msec()
	var plan := VillageLotPlanner.plan_measured(spec, jobs)
	var plan_s := (Time.get_ticks_msec() - t0) / 1000.0
	res.checked += 3
	if plan.ground == null or plan.island.is_empty() or plan.shoreline.is_empty():
		res.fail("%s: the plan is not sited on its island" % name)
		return
	if absf(sin(plan.site_yaw)) > 0.2:
		res.fail("%s: the plan is turned %.0f deg, not along the island's long axis" % [name, rad_to_deg(plan.site_yaw)])
	if not EXPORTER.covers_plan(ground, plan):
		res.fail("%s: the sited site's corners leave the grid" % name)
	if OS.get_environment("ISLAND_DUMP") == "1":
		var rc := VillageRoadCheck.new()
		rc.check(plan)
		print(rc.ascii_map(3.0))

	# --- the island, as itself
	var ic := VillageIslandCheck.new()
	var ir: Dictionary = ic.check(plan)
	res.checked += 1
	if not ir["ok"]:
		res.fail("%s: VillageIslandCheck: %s" % [name, "; ".join((ir["failures"] as Array).slice(0, 4))])
	var stats: Dictionary = ir["stats"]
	res.checked += 2
	if int(stats.get("ring_arcs", 0)) < 6:
		res.fail("%s: %d ring arcs" % [name, int(stats.get("ring_arcs", 0))])
	if float(stats.get("ring_gap_m", 99.0)) > RING_GAP_MAX:
		res.fail("%s: the ring stands %.1f m inside the shore on average, wants at most %.0f" % [
			name, float(stats.get("ring_gap_m", 99.0)), RING_GAP_MAX])

	# --- housed
	res.checked += 1
	if plan.buildings.size() < jobs.size():
		res.fail("%s: %d of %d buildings placed" % [name, plan.buildings.size(), jobs.size()])

	# --- the village's own QA
	var t1 := Time.get_ticks_msec()
	var no_pure := func(_plan: VillagePlan) -> Array: return []
	var qa: Dictionary = VillageQA.new().check(plan, {&"pure": no_pure}, false)
	var qa_s := (Time.get_ticks_msec() - t1) / 1000.0
	res.checked += 1
	if not qa["ok"]:
		res.fail("%s: VillageQA: %s" % [name, "; ".join((qa["failures"] as Array).slice(0, 4))])

	# --- the walk: every door from a landing; the spine taken away strands them
	var nr: Dictionary = VillageNavCheck.new().check(plan)
	res.checked += 1
	if int(nr["stats"].get("unreached_doors", -1)) != 0:
		res.fail("%s: %s doors cannot be walked to: %s" % [name, nr["stats"].get("unreached_doors"),
			"; ".join((nr["failures"] as Array).slice(0, 3))])
	var walk: Dictionary = VillageWalk.projection(plan, "test")
	var unreachable := 0
	for d in walk["doors"]:
		if not bool(d["reachable"]):
			unreachable += 1
	res.checked += 1
	if unreachable > 0:
		res.fail("%s: the walk export has %d unreachable doors" % [name, unreachable])
	_control_spine(res, name, plan)

	# --- export
	var out: Dictionary = EXPORTER.site_plan(plan, {"name": name})
	res.checked += 3
	if String(out.get("form", "")) != "water" or not out.has("island"):
		res.fail("%s: the exporter writes form '%s' and %s an island" % [name, out.get("form"), "no" if not out.has("island") else "an"])
	if (out.get("shoreline_m", []) as Array).size() != plan.shoreline.size():
		res.fail("%s: the exporter writes %d shoreline points of %d" % [name, (out.get("shoreline_m", []) as Array).size(), plan.shoreline.size()])
	if out.has("island") and (out["island"]["landings_m"] as Array).size() != 2:
		res.fail("%s: the exporter writes %d landings" % [name, (out["island"]["landings_m"] as Array).size()])

	# --- the mesh
	t1 = Time.get_ticks_msec()
	var builder := VillageBuilder.new()
	var mesh := builder.build(plan)
	var comp: Dictionary = ComponentCheck.check(builder, mesh)
	res.checked += 1
	if not comp["ok"]:
		res.fail("%s: the components differ from their triangles: %s" % [name, str(comp.get("failures", comp)).left(300)])
	var scene: Node3D = VillageAssembler.build(plan)
	var mesh_s := (Time.get_ticks_msec() - t1) / 1000.0
	var gr: Dictionary = VillageGroundCheck.new().check(plan, scene)
	res.checked += 1
	for f in (gr["failures"] as Array).slice(0, 6):
		res.fail("%s: ground: %s" % [name, f])
	scene.free()

	# --- the controls
	_control_fill(res, name, plan)
	_control_ring(res, name, plan)

	res.note("%-6s %s | %d buildings, ring scale %.2f, ring %.1f m inside the shore, island reached %.2f | VillageShape %s | plan %.1f s, qa %.1f s, mesh+scene %.1f s"
		% [name, spec.form, plan.buildings.size(), float(plan.island["ring_scale"]), float(stats.get("ring_gap_m", 0.0)),
			float(stats.get("island_reach", 0.0)), _shape(plan), plan_s, qa_s, mesh_s])


static func _shape(plan: VillagePlan) -> String:
	var sh := VillageShape.measure(plan)
	return "hull %.2f ha, coverage %.2f, water_within_30m %.2f, setback %.1f m" % [float(sh.get("body_hull_ha", 0.0)),
		float(sh.get("coverage", 0.0)), float(sh.get("water_within_30m", 0.0)), float(sh.get("setback_median_m", 0.0))]


## The spine taken away, the houses on it are not reached: it is the spine,
## not the island, that carries the walk.
static func _control_spine(res: SuiteResult, name: String, plan: VillagePlan) -> void:
	var through: Array[int] = plan.roads_of_class(&"through")
	if through.is_empty():
		return
	var kept: Dictionary = plan.roads[through[0]]
	var cut: Dictionary = kept.duplicate()
	var pts: PackedVector2Array = kept["points"]
	# a spine of one short stub at one landing: the ring is cut off from the gates
	cut["points"] = PackedVector2Array([pts[0], pts[1]])
	plan.roads[through[0]] = cut
	var r: Dictionary = VillageNavCheck.new().check(plan)
	plan.roads[through[0]] = kept
	res.checked += 1
	if int(r["stats"].get("unreached_doors", 0)) == 0:
		res.fail("%s: control: with the spine cut to a stub every door is still walked to" % name)
	else:
		res.note("%s: control: spine cut to a stub, %d doors unreached" % [name, int(r["stats"].get("unreached_doors", 0))])


## Half the buildings taken away (the east half): the shore is no longer fronted.
static func _control_fill(res: SuiteResult, name: String, plan: VillagePlan) -> void:
	var kept: Array[Dictionary] = plan.buildings.duplicate()
	var half: Array[Dictionary] = []
	for b in kept:
		if VillageMeasure.centre(VillageMeasure.footprint_poly(b)).x < 0.0:
			half.append(b)
	plan.buildings = half
	var r: Dictionary = VillageIslandCheck.new().check(plan)
	plan.buildings = kept
	res.checked += 1
	var fill_failed := false
	for f in r["failures"]:
		fill_failed = fill_failed or String(f).begins_with("fill:")
	if not fill_failed:
		res.fail("%s: control: with the east half of the buildings gone the island is still reached (%.2f)" % [
			name, float(r["stats"].get("island_reach", 0.0))])
	else:
		res.note("%s: control: east half gone, island reached %.2f" % [name, float(r["stats"].get("island_reach", 0.0))])


## One ring arc taken up: the ring is open and the check says so.
static func _control_ring(res: SuiteResult, name: String, plan: VillagePlan) -> void:
	var kept: Array[Dictionary] = plan.roads.duplicate()
	var arc := -1
	for r in range(1, plan.roads.size()):
		if plan.roads[r]["class"] == &"street":
			arc = r
			break
	if arc < 0:
		return
	plan.roads.remove_at(arc)
	var r2: Dictionary = VillageIslandCheck.new().check(plan)
	plan.roads = kept
	res.checked += 1
	var ring_failed := false
	for f in r2["failures"]:
		ring_failed = ring_failed or String(f).begins_with("ring:")
	if not ring_failed:
		res.fail("%s: control: a ring arc taken up and the ring is still closed" % name)


# -------------------------------------------------------------------- the form off

## The same ground with the island form off is the water form as before: no
## island plan, and the lot planner's first attempt reaches a fraction of the
## island (the full ladder housed 14 of 29 and failed VillageQA; measured
## 2026-10-26, 607 s). The ring is the form's, not the ground's.
static func _off(res: SuiteResult, jobs: Array[Dictionary]) -> void:
	VillageIslandForm.enabled = false
	var ground: VillageTerrain = SYNTH.make("islet")
	var spec := spec_for(ground)
	var plan := VillageSitePlanner.plan(spec)
	var left := VillageLotPlanner.cut_measured(plan, jobs)
	VillageIslandForm.enabled = true
	var reach := VillageIslandCheck.reach_share(plan, ground)
	res.checked += 3
	if not plan.island.is_empty():
		res.fail("off: the form switched off still plans an island")
	if left == 0 and plan.island.is_empty() and plan.roads.size() > 6:
		res.fail("off: the plan has a ring (%d roads)" % plan.roads.size())
	if reach >= VillageIslandCheck.REACH_MIN:
		res.fail("off: without the form the first attempt reaches %.2f of the island, as much as the form" % reach)
	res.note("off: form %s, first attempt places %d of %d, reaches %.2f of the island" % [
		spec.form, plan.buildings.size(), jobs.size(), reach])


# ------------------------------------------------------------------------ purity

static func _pure(res: SuiteResult) -> void:
	var a := VillageSitePlanner.plan(spec_for(SYNTH.make("islet")))
	VillageShoreForm.clear_cache()
	VillageSiting.clear_cache()
	VillageIslandForm.clear_cache()
	var b := VillageSitePlanner.plan(spec_for(SYNTH.make("islet")))
	res.checked += 2
	if a.island.is_empty():
		res.fail("pure: the islet plans no island")
	if not a.equals(b):
		res.fail("pure: the same spec on the same ground planned twice gave two site plans")
