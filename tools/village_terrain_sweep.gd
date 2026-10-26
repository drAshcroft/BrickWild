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
## A second line (VTER-PLACE): VillageShape's worship_elev_pctile,
## worship_centrality, body_elev_pctile and water_within_30m beside the world
## set's (VillagePlaceCheck.WORLD_*), and PlaceCheck's ground reading.

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
	var bands := steep_bands()
	print("STEEP-SITE BANDS (world_settlements.json, %d sites on ground over the survey's 8 %% steep threshold) p10-p90: elongation %.2f-%.2f, street_contour_share %.3f-%.3f, elev_span_m %.1f-%.1f, steps_ways %.0f-%.0f" % [
		int(bands["n"]), bands["elongation"][0], bands["elongation"][1],
		bands["street_contour_share"][0], bands["street_contour_share"][1],
		bands["elev_span_m"][0], bands["elev_span_m"][1],
		bands["steps_ways"][0], bands["steps_ways"][1]])
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
			print(line(name, String(form) if form != "derived" else "~" + String(s.form), row))
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
	if form == &"derived":
		# the form the ground derives (VTER-FORM-DERIVE), as a real request gets
		s.terrain = ground
		s.generate(seed)
		return s
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
	out["span"] = shape.get("elev_span_m")
	out["relief"] = shape.get("relief_disc_m")
	out["band"] = relief_band(shape)
	# the survey's arrangement measures this ticket is judged on (HILLS-CONTOUR)
	out["elongation"] = shape.get("elongation")
	out["steps"] = shape.get("steps_ways")
	out["houses"] = plan.buildings_of_kind(&"house").size()
	out["households"] = plan.spec.households
	out["unhoused"] = maxi(0, plan.spec.households - int(out["houses"]))
	# VTER-PLACE: where the landmark and the body stand against the world set
	out["worship_pct"] = shape.get("worship_elev_pctile")
	out["worship_centre"] = shape.get("worship_centrality")
	out["body_pct"] = shape.get("body_elev_pctile")
	out["water30"] = shape.get("water_within_30m")
	out["place"] = VillagePlaceCheck.ground_reading(plan)
	# VTER-LOTS: lots on water, and the most fall any building stands on
	# against what its family accepts in a village
	var water_lots := 0
	for lot in plan.lots:
		for w in plan.water:
			if VillageLotPlanner.overlap_area(lot["poly"], w["poly"]) > VillageLotPlanner.AREA_EPS:
				water_lots += 1
				break
	out["water_lots"] = water_lots
	var worst_fall := 0.0
	var worst_share := 0.0
	for b in plan.buildings:
		var req: BuildingRequest = b["request"]
		var lim := VillageLotGround.fall_limit(req)
		worst_fall = maxf(worst_fall, req.ground_fall_m)
		if lim > 0.0:
			worst_share = maxf(worst_share, req.ground_fall_m / lim)
		elif req.ground_fall_m > 0.0:
			worst_share = INF
	out["max_fall"] = worst_fall
	out["max_fall_share"] = worst_share
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


## The world set's real p10-p90 bands by relief class (VTER-LOTS,
## docs/VILLAGE_TERRAIN.md "Lots on the ground"): VillageShape's
## elev_span_m and slope_median_pct by relief_disc_m.
const BANDS := {
	"low": {"span": Vector2(0.5, 16.0), "slope": Vector2(0.4, 5.0)},
	"mid": {"span": Vector2(2.0, 44.0), "slope": Vector2(1.2, 14.0)},
	"high": {"span": Vector2(7.5, 72.0), "slope": Vector2(5.0, 36.0)},
}


static func relief_class(relief: float) -> String:
	return "low" if relief < 60.0 else ("mid" if relief < 250.0 else "high")


## The real steep sites' p10-p90 bands, read from the survey fixture rather
## than copied into prose (HILLS-CONTOUR). "Steep" is the survey's own 8 %
## threshold on the median slope under the houses (survey.py's contour
## measure uses the same one). Keys: n, and [p10, p90] per measure.
const WORLD_SET := "res://tests/fixtures/settlements/world_settlements.json"
const STEEP_SLOPE_PCT := 8.0
const BAND_KEYS := ["elongation", "street_contour_share", "elev_span_m", "steps_ways"]


static func steep_bands() -> Dictionary:
	var text := FileAccess.get_file_as_string(WORLD_SET)
	var data: Variant = JSON.parse_string(text) if not text.is_empty() else null
	var out := {"n": 0}
	for k in BAND_KEYS:
		out[k] = [0.0, 0.0]
	if not (data is Dictionary):
		return out
	var cols := {}
	for k in BAND_KEYS:
		cols[k] = []
	for site in data.get("sites", []):
		var morph: Dictionary = site.get("morph", {})
		if not bool(morph.get("usable", false)):
			continue
		if morph.get("slope_median_pct") == null or float(morph["slope_median_pct"]) < STEEP_SLOPE_PCT:
			continue
		out["n"] = int(out["n"]) + 1
		for k in BAND_KEYS:
			if morph.get(k) != null:
				(cols[k] as Array).append(float(morph[k]))
	for k in BAND_KEYS:
		var v: Array = cols[k]
		out[k] = [_pct(v, 10.0), _pct(v, 90.0)]
	return out


static func _pct(values: Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var v: Array = values.duplicate()
	v.sort()
	var k: float = (v.size() - 1) * p / 100.0
	var lo := int(floor(k))
	var hi := mini(lo + 1, v.size() - 1)
	return lerpf(v[lo], v[hi], k - lo)


## {"class", "span": "ok"/"LOW"/"HIGH", "slope": ...} for a VillageShape reading.
static func relief_band(shape: Dictionary) -> Dictionary:
	if shape.get("relief_disc_m") == null or shape.get("elev_span_m") == null \
			or shape.get("slope_median_pct") == null:
		return {}
	var cls := relief_class(float(shape["relief_disc_m"]))
	var b: Dictionary = BANDS[cls]
	return {"class": cls, "span": _verdict(float(shape["elev_span_m"]), b["span"]),
		"slope": _verdict(float(shape["slope_median_pct"]), b["slope"])}


static func _verdict(v: float, band: Vector2) -> String:
	return "ok" if v >= band.x and v <= band.y else ("LOW" if v < band.x else "HIGH")


static func line(name: String, form: String, m: Dictionary) -> String:
	var gs := ""
	for cls in m["grades"]:
		gs += "%s=%.3f " % [cls, m["grades"][cls]]
	var band: Dictionary = m.get("band", {})
	var place := "  worship %s centre %s body %s water30 %s %s" % [str(m.get("worship_pct")),
		str(m.get("worship_centre")), str(m.get("body_pct")), str(m.get("water30")), str(m.get("place", ""))]
	return "%-22s %-10s at (%.0f, %.0f) yaw %5.1f site %s  bld %d/%d  %s contour %s/%s  common %.3f/%.3f  cliff %d wet %d water %d  relief %s %s span %s %s slope %s %s  elong %s steps %s houses %d/%d unhoused %d  fall %.2f (%.0f%% of limit)  %.1f s %s" % [
		name, form, m["anchor"].x, m["anchor"].y, m["yaw"], m["site"], m["buildings"], m["programme"], gs,
		str(m["contour"]), str(m["steep_share"]), float(m.get("common_slope", -1.0)), float(m.get("common_slope_max", -1.0)),
		m["cliff_lots"], m["wet_lots"], m["water_lots"], str(m["relief"]), band.get("class", "-"), str(m["span"]),
		band.get("span", "-"), str(m["slope_med"]), band.get("slope", "-"),
		str(m["elongation"]), str(m["steps"]), int(m["houses"]), int(m["households"]), int(m["unhoused"]),
		m["max_fall"], 100.0 * m["max_fall_share"],
		m["ms"] / 1000.0, "OVER " + ", ".join(m["over"]) if not m["over"].is_empty() else ""] + "\n   " + place
