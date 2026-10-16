extends SceneTree
## Plan one small village on every terrain fixture and print how it lies
## (VTER-SITING / VTER-ROADS, docs/VILLAGE_TERRAIN.md). Not a test: a table.
##
##   godot --headless --path . --script res://tools/village_terrain_sweep.gd \
##       -- [--fixtures plane_30,real30/manarola] [--forms street,green] [--population 50] [--qa]
##
## Per plan: where it was sited, the steepest grade per road class (measured
## on the plan's own ground AND on the caller's grid at the carried points),
## street_contour_share, the common's slope, lots across a cliff or on water,
## plan time, and with --qa the VillageQA failures (no per-building QA).

const SYNTH := preload("res://tests/fixtures/terrain/synthetic_terrain.gd")
const REAL30 := "res://tests/fixtures/terrain/real30/"


func _init() -> void:
	var opts := {}
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if args[i].begins_with("--"):
			var k := args[i].substr(2)
			if i + 1 < args.size() and not args[i + 1].begins_with("--"):
				opts[k] = args[i + 1]
				i += 1
			else:
				opts[k] = "1"
		i += 1
	var fixtures: PackedStringArray = String(opts.get("fixtures", "")).split(",", false)
	if fixtures.is_empty():
		fixtures = SYNTH.names()
		for f in DirAccess.get_files_at(REAL30):
			if f.ends_with(".json"):
				fixtures.append("real30/" + f.get_basename())
	var forms: PackedStringArray = String(opts.get("forms", "street")).split(",", false)
	var population := int(opts.get("population", "50"))
	var seed := int(opts.get("seed", "4242"))
	var qa := opts.has("qa")
	var purpose := StringName(String(opts.get("purpose", "farming")))
	var water := StringName(String(opts.get("water", "none")))
	var spec := _spec(population, seed, &"street", null, purpose, water)
	var t0 := Time.get_ticks_msec()
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(VillageProgrammer.programme(spec))
	print("measured %d buildings in %.1f s" % [jobs.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	for name in fixtures:
		var ground := terrain(name)
		if name != "flat" and (ground == null or not ground.valid()):
			print("%s: unreadable" % name)
			continue
		for form in forms:
			var s := _spec(population, seed, StringName(form), ground, purpose, water)
			var t1 := Time.get_ticks_msec()
			var plan := VillageLotPlanner.plan_measured(s, jobs)
			var ms := Time.get_ticks_msec() - t1
			var row := measure(plan)
			row["ms"] = ms
			print(line(name, String(form), row))
			if qa:
				var t2 := Time.get_ticks_msec()
				# the form is forced, so the purity twin (which derives its own)
				# cannot match by construction; purity is vtplan's own check
				var no_pure := func(_plan: VillagePlan) -> Array: return []
				var rep := VillageQA.new().check(plan, {&"pure": no_pure}, false)
				print("    qa %s in %.1f s: %s" % ["ok" if rep["ok"] else "FAIL", (Time.get_ticks_msec() - t2) / 1000.0,
					"; ".join((rep["failures"] as Array).slice(0, 6))])
			if opts.has("map"):
				var rc := VillageRoadCheck.new()
				rc.check(plan)
				print(rc.ascii_map(4.0))
	quit(0)


static func terrain(name: String) -> VillageTerrain:
	if name == "flat":
		return null
	if name.begins_with("real30/"):
		return VillageTerrain.from_file(REAL30 + name.substr(7) + ".json")
	return SYNTH.make(name)


static func _spec(population: int, seed: int, form: StringName, ground: VillageTerrain,
		purpose := &"farming", water := &"none") -> VillageSpec:
	var s := VillageSpec.new(seed)
	s.population = population
	s.purpose = purpose
	s.water = water
	s.generate(seed)
	s.form = form
	s.terrain = ground
	return s


## Everything the acceptance reads off one plan.
static func measure(plan: VillagePlan) -> Dictionary:
	var out := {"anchor": plan.site_anchor, "yaw": rad_to_deg(plan.site_yaw), "site": plan.site.size,
		"buildings": plan.buildings.size(), "programme": VillageProgrammer.programme(plan.spec).size()}
	var g := plan.terrain()
	if g == null:
		g = VillageTerrain.flat(plan.site.grow(200.0), 0.0, 5.0)
	var given: VillageTerrain = g.parent if g != null and g.parent != null else g
	var grades := {}
	var over := []
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		var cls: StringName = road["class"]
		var pts: PackedVector2Array = road["points"]
		var local := VillageRoadRouter.grade_of(g, pts)
		var carried := PackedVector2Array()
		for p in pts:
			carried.append(g.to_parent(p))
		var real := VillageRoadRouter.grade_of(given, carried)
		var worst := maxf(local, real)
		grades[cls] = maxf(float(grades.get(cls, 0.0)), worst)
		if worst > float(VillageSitePlanner.ROAD_CLASSES[cls]["grade_max"]) + 1e-6:
			over.append("%s %d %.3f" % [cls, r, worst])
	out["grades"] = grades
	out["over"] = over
	var shape := VillageShape.measure(plan)
	out["contour"] = shape.get("street_contour_share")
	out["steep_share"] = shape.get("street_steep_share")
	out["slope_med"] = shape.get("slope_median_pct")
	if not plan.commons.is_empty():
		var u := g.under(plan.commons[0]["poly"])
		out["common_slope"] = u["slope_mean"]
		out["common_slope_max"] = u["slope_max"]
	var cliff := 0
	var wet := 0
	for lot in plan.lots:
		var u2 := g.under(lot["poly"])
		if float(u2["slope_max"]) > VillageSiteAnalysis.PATH_MAX:
			cliff += 1
		if float(u2["dry_share"]) < 1.0:
			wet += 1
	out["cliff_lots"] = cliff
	out["wet_lots"] = wet
	return out


static func line(name: String, form: String, m: Dictionary) -> String:
	var gs := ""
	for cls in m["grades"]:
		gs += "%s=%.3f " % [cls, m["grades"][cls]]
	return "%-22s %-10s at (%.0f, %.0f) yaw %5.1f site %s  bld %d/%d  %s contour %s/%s  common %.3f/%.3f  cliff %d wet %d  %.1f s %s" % [
		name, form, m["anchor"].x, m["anchor"].y, m["yaw"], m["site"], m["buildings"], m["programme"], gs,
		str(m["contour"]), str(m["steep_share"]), float(m.get("common_slope", -1.0)), float(m.get("common_slope_max", -1.0)),
		m["cliff_lots"], m["wet_lots"], m["ms"] / 1000.0, "OVER " + ", ".join(m["over"]) if not m["over"].is_empty() else ""]
