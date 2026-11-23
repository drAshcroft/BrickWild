extends SceneTree
## Why a SiteRequest is refused, in seconds instead of the exporter's minutes
## (BG-017, BG-018). Builds the spec exactly as `export_village_plan.gd` does,
## measures the programme, runs the lot planner and prints what was left out
## and which lot rule refused it (`VillagePlan.unplaced`). It writes no site
## plan: this is the planner alone, with no walk, navmesh or dressing export.
##
##   godot --headless --path . --script res://tools/probe_site_refusal.gd -- \
##       --request <in.json> --population N [--implied-population M] \
##       [--terrain grid.json] [--vernacular file|json] [--search-attempts N] \
##       [--search-budget-s S] [--cache DIR] [--out summary.json]
##
## `--cache DIR` keeps every measured placement (and a church's, temple's or
## castle's measurement on each fall it was asked to stand on) on disk, keyed by
## the request's own fields, so the second run measures nothing: on flat ground
## the whole probe is then the lot search. A house or a shop on given ground is
## still generated (its entry flights are planned on its own plan). The cache
## holds measurements only; delete it after changing a builder.
##
## `--out` writes the plan's geometry (site, common, roads, lots, buildings,
## the unplaced rows) as JSON, for `tools/settlements/draw_refusal.py`.

const Exporter := preload("res://tools/export_village_plan.gd")


func _init() -> void:
	var opts: Dictionary = Exporter._options(OS.get_cmdline_user_args())
	if not opts.has("request") or not opts.has("population"):
		printerr("usage: --request <in.json> --population N [--implied-population M] [--terrain grid.json] [--vernacular v] [--search-attempts N] [--search-budget-s S] [--cache DIR] [--out summary.json]")
		quit(2)
		return
	var text: String = Exporter._read(opts["request"])
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		printerr("%s is not a JSON object" % opts["request"])
		quit(2)
		return
	var notes: Array[String] = []
	var request: Dictionary = Exporter.with_implied_population(
		Exporter.with_caller_population(parsed, String(opts["population"]), notes),
		String(opts.get("implied-population", "")))
	var spec: VillageSpec = Exporter.spec_from_request(request, text, notes)
	var brief_errors: Array[String] = Exporter.request_errors(request)
	if not brief_errors.is_empty():
		printerr("SiteRequest refused: %s" % "; ".join(brief_errors))
		quit(3)
		return
	if opts.has("vernacular"):
		var read: Dictionary = Exporter.vernacular_from_arg(String(opts["vernacular"]))
		if not (read["errors"] as Array).is_empty():
			printerr("--vernacular refused: %s" % "; ".join(read["errors"]))
			quit(2)
			return
		Exporter.apply_vernacular(spec, read["vernacular"], request, notes)
	var ground: VillageTerrain = Exporter.terrain_from_request(request,
		String(opts["request"]).get_base_dir(), String(opts.get("terrain", "")))
	spec.terrain = ground
	spec.search_budget_s = float(String(opts.get("search-budget-s", "0")))
	spec.search_max_attempts = int(String(opts.get("search-attempts", "0")))
	if not spec.valid():
		printerr("SiteRequest does not map to a village: %s" % ", ".join(spec.errors()))
		quit(3)
		return
	spec.generate(spec.seed)
	# `--detail 1`: the recorder also names the road class crossed and the fall refused
	VillageLotPlanner.why_detail = opts.has("detail")

	var t0 := Time.get_ticks_msec()
	var cache_dir: String = String(opts.get("cache", ""))
	if cache_dir != "":
		DirAccess.make_dir_recursive_absolute(cache_dir)
	var programme: Array[BuildingRequest] = VillageProgrammer.programme(spec)
	var jobs: Array[Dictionary] = []
	var hits := 0
	for i in range(programme.size()):
		var job: Dictionary = _measure(programme[i], cache_dir, ground != null)
		if job.is_empty():
			print("  request %d (%s) does not generate" % [i, programme[i].kind])
			continue
		if bool(job.get("cached", false)):
			hits += 1
		job["order"] = i
		job["class"] = VillageLotPlanner.lot_class(programme[i])
		jobs.append(job)
	var t1 := Time.get_ticks_msec()
	print("%s: form %s (intent %s), %d shown + %d civic people, %d households, %d requests, measured in %.1f s (%d from cache)" % [
		String(request.get("city_id", "?")), spec.form, spec.form_intent, spec.population,
		spec.civic_population(), spec.households, programme.size(), float(t1 - t0) / 1000.0, hits])
	for job in jobs:
		var r: BuildingRequest = job["request"]
		print("  %2d %-9s %-8s %-14s asked %5.1f x %5.1f  measured %5.1f x %5.1f" % [int(job["order"]),
			String(job["class"]), String(r.kind), Exporter._label(spec, r).get_slice("/", 1) if r.kind == &"shop" else Exporter._label(spec, r),
			r.width, r.length, float(job["width"]), float(job["depth"])])

	var plan: VillagePlan = VillageLotPlanner.plan_measured(spec, jobs)
	var t2 := Time.get_ticks_msec()
	if cache_dir != "":
		_save_slopes(jobs, cache_dir)
	var search: Dictionary = plan.search
	print("planned in %.1f s: %d of %d placed on %.0f x %.0f m, %d re-plans, stopped '%s'" % [
		float(t2 - t1) / 1000.0, plan.buildings.size(), programme.size(), plan.site.size.x, plan.site.size.y,
		int(search.get("attempts", 0)), String(search.get("stopped", ""))])
	for c in plan.commons:
		var cr: Rect2 = Poly.bounding_rect(c["poly"])
		print("  common %s %.1f x %.1f m at (%.0f, %.0f)" % [String(c.get("kind", "")), cr.size.x, cr.size.y,
			cr.get_center().x, cr.get_center().y])
	for cut in search.get("cuts", []):
		print("  cut at %6.1f s site %s roads %d left %d %s" % [float(cut.get("at_s", 0.0)), str(cut["site"]),
			int(cut["roads"]), int(cut["left"]), ", ".join(cut["unplaced"])])
	for row in Exporter.unplaced_why(plan, programme):
		print("  UNPLACED %s" % String(row["says"]))
		for rule in row["rules"]:
			print("      %6d  %s" % [int(rule["refused"]), String(rule["rule"])])
	if opts.has("out"):
		var f := FileAccess.open(String(opts["out"]), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(_summary(plan, programme), "\t") + "\n")
			f.close()
	quit(0 if plan.buildings.size() >= programme.size() else 3)


## `VillageLotPlanner.measure`, from the cache when the placement is there and
## the building itself will not be needed (flat ground, or a family measured
## whole on each fall).
func _measure(request: BuildingRequest, cache_dir: String, on_ground: bool) -> Dictionary:
	var needs_building: bool = on_ground and request.kind in [&"house", &"shop"]
	var path: String = "" if cache_dir == "" else cache_dir.path_join(_key(request) + ".placement.txt")
	if path != "" and not needs_building and FileAccess.file_exists(path):
		var pl: Variant = str_to_var(FileAccess.get_file_as_string(path))
		if pl is Dictionary and not (pl as Dictionary).is_empty():
			var job: Dictionary = _job_of(request, pl)
			job["cached"] = true
			_load_slopes(job, cache_dir)
			return job
	var measured: Dictionary = VillageLotPlanner.measure(request)
	if measured.is_empty():
		return {}
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(var_to_str(measured["placement"]))
			f.close()
		_load_slopes(measured, cache_dir)
	return measured


## The job `VillageLotPlanner.measure` returns, from a placement alone.
static func _job_of(request: BuildingRequest, pl: Dictionary) -> Dictionary:
	var fp: Rect2 = pl["footprint"]
	var bounds: AABB = pl["bounds"]
	var brect := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
	var u: Rect2 = fp.merge(brect)
	var anchor := Vector2(fp.position.x + fp.size.x * 0.5, fp.position.y)
	return {
		"request": request, "placement": pl, "footprint": fp, "bounds_rect": brect,
		"half_w": maxf(anchor.x - u.position.x, u.end.x - anchor.x),
		"over": maxf(0.0, anchor.y - u.position.y), "back": maxf(0.0, u.end.y - anchor.y),
		"width": u.size.x, "depth": u.size.y, "building": null, "slope_cache": {},
	}


static func _key(request: BuildingRequest) -> String:
	return "%s_%s" % [String(request.kind), JSON.stringify(request.to_dict(), "", true).sha256_text().substr(0, 20)]


## A church's, temple's or castle's measurements on falling ground, kept
## across runs: each is a whole building generated on one fall.
static func _slope_path(job: Dictionary, cache_dir: String) -> String:
	var request: BuildingRequest = job["request"]
	if cache_dir == "" or request.kind in [&"house", &"shop"]:
		return ""
	return cache_dir.path_join(_key(request) + ".slopes.txt")


static func _load_slopes(job: Dictionary, cache_dir: String) -> void:
	var path: String = _slope_path(job, cache_dir)
	if path == "" or not FileAccess.file_exists(path):
		return
	var kept: Variant = str_to_var(FileAccess.get_file_as_string(path))
	if kept is Dictionary:
		job["slope_cache"] = kept
		job["slopes_loaded"] = (kept as Dictionary).size()


static func _save_slopes(jobs: Array[Dictionary], cache_dir: String) -> void:
	for job in jobs:
		var path: String = _slope_path(job, cache_dir)
		var cache: Dictionary = job.get("slope_cache", {})
		if path == "" or cache.size() <= int(job.get("slopes_loaded", 0)):
			continue
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(var_to_str(cache))
			f.close()


static func _summary(plan: VillagePlan, programme: Array[BuildingRequest]) -> Dictionary:
	var roads: Array = []
	for road in plan.roads:
		roads.append({"class": String(road["class"]), "width": float(road["width"]) + 2.0 * float(road["verge"]),
			"points": Exporter._points(road["points"])})
	var lots: Array = []
	for lot in plan.lots:
		lots.append({"poly": Exporter._points(lot["poly"]), "road": int(lot["road"])})
	var buildings: Array = []
	for b in plan.buildings:
		var r: BuildingRequest = b["request"]
		buildings.append({"label": Exporter._label(plan.spec, r), "class": String(b["class"]),
			"walls": Exporter._points(VillageMeasure.footprint_poly(b)),
			"bounds": Exporter._points(VillageMeasure.bounds_poly(b)),
			"front": [VillageMeasure.front_mid(b).x, VillageMeasure.front_mid(b).y]})
	var commons: Array = []
	for c in plan.commons:
		commons.append(Exporter._points(c["poly"]))
	var water: Array = []
	for w in plan.water:
		water.append(Exporter._points(w["poly"]))
	var out := {
		"form": String(plan.spec.form),
		"site": [plan.site.position.x, plan.site.position.y, plan.site.size.x, plan.site.size.y],
		"commons": commons, "roads": roads, "lots": lots, "buildings": buildings, "water": water,
		"landmark_site": Exporter._points(plan.landmark_site["poly"]) if plan.landmark_reserved() else [],
		"enclosure": Exporter._points(plan.enclosure),
		"requested": programme.size(), "placed": plan.buildings.size(),
		"unplaced": Exporter.unplaced_why(plan, programme),
		"search": plan.search.duplicate(true),
	}
	if plan.ground != null:
		# the ground under the site, on a coarse lattice, for the picture's contours
		var step := 10.0
		var rows: Array = []
		var y: float = plan.site.position.y
		while y <= plan.site.end.y + 0.01:
			var row: Array = []
			var x: float = plan.site.position.x
			while x <= plan.site.end.x + 0.01:
				row.append(snappedf(plan.ground.height_at(Vector2(x, y)), 0.01))
				x += step
			rows.append(row)
			y += step
		out["ground"] = {"step": step, "heights": rows, "water_level": plan.ground.water_level_m
			if not is_nan(plan.ground.water_level_m) else null}
	out["search"].erase("capacity")
	return out
