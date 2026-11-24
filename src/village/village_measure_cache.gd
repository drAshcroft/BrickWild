class_name VillageMeasureCache
extends RefCounted
## The measurements of a village's programme, kept between plans and between
## runs (BG-018-MEASURE-CACHE, docs/VILLAGE_TERRAIN.md "The town shown small").
##
## WHY. A plan measures every building once, flat, and on given ground it
## measures a church, a temple and a castle again on every fall the lot search
## asks them to stand on: a whole building generated per lattice point.
## Wuunafu's ground plan took 1752 s with nothing measured and 81 s with these
## kept. One cache serves every plan of one run (the easing ladder re-plans the
## same programme on gentler ground) and, with a directory, every later run.
##
## WHAT IS KEPT, keyed by the request's own fields:
##   <kind>_<hash>.placement.txt   the flat placement (`BrickWild.placement`)
##   <kind>_<hash>.slopes.txt      a church's, temple's or castle's measurement
##                                 on each fall (`VillageLotGround.ground_parts`)
## A house or a shop on given ground is always generated: its entry flights are
## planned on its own plan (`VillageLotGround._house_parts`), which no file
## holds.
##
## The cache holds measurements only and knows nothing of the code that made
## them. A frozen release never changes, so a directory per release is safe
## for ever; in a working tree, delete it after changing a builder.

## Where the files are kept; "" keeps them in memory for this run only.
var dir := ""
## request key -> job, for the plans of one run.
var _jobs := {}
var hits := 0


func _init(p_dir := "") -> void:
	dir = p_dir
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)


## `VillageLotPlanner.measure_all` through the cache: one job per request that
## generates, in order, each carrying its `order` and `class`. `on_ground`
## says the plan has ground (houses and shops then need their building).
func jobs_for(programme: Array[BuildingRequest], on_ground: bool) -> Array[Dictionary]:
	var jobs: Array[Dictionary] = []
	var taken := {}
	for i in range(programme.size()):
		var job: Dictionary = measure(programme[i], on_ground)
		if job.is_empty():
			continue
		# two requests alike in every field share one measurement, not one row
		var key: String = key_of(programme[i])
		if taken.has(key):
			job = job.duplicate()
		taken[key] = true
		job["order"] = i
		job["class"] = VillageLotPlanner.lot_class(programme[i])
		jobs.append(job)
	return jobs


## `VillageLotPlanner.measure`, from this run's memory, else from the
## directory when the building itself will not be needed, else measured (and
## kept).
func measure(request: BuildingRequest, on_ground: bool) -> Dictionary:
	var key: String = key_of(request)
	var needs_building: bool = on_ground and request.kind in [&"house", &"shop"]
	if _jobs.has(key):
		var kept: Dictionary = _jobs[key]
		if not needs_building or kept.get("building") != null:
			return kept
	var path: String = "" if dir == "" else dir.path_join(key + ".placement.txt")
	if path != "" and not needs_building and FileAccess.file_exists(path):
		var pl: Variant = str_to_var(FileAccess.get_file_as_string(path))
		if pl is Dictionary and not (pl as Dictionary).is_empty():
			var job: Dictionary = job_of(request, pl)
			job["cached"] = true
			hits += 1
			_load_slopes(job)
			_jobs[key] = job
			return job
	var measured: Dictionary = VillageLotPlanner.measure(request)
	if measured.is_empty():
		return {}
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(var_to_str(measured["placement"]))
			f.close()
		_load_slopes(measured)
	_jobs[key] = measured
	return measured


## Write what the plans measured on falling ground since the files were read.
## Call once the planning is done; nothing is written without a directory.
func save() -> void:
	if dir == "":
		return
	for key in _jobs:
		var job: Dictionary = _jobs[key]
		var path: String = _slope_path(job)
		var cache: Dictionary = job.get("slope_cache", {})
		if path == "" or cache.size() <= int(job.get("slopes_loaded", 0)):
			continue
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(var_to_str(cache))
			f.close()
			job["slopes_loaded"] = cache.size()


## The job `VillageLotPlanner.measure` returns, from a placement alone.
static func job_of(request: BuildingRequest, pl: Dictionary) -> Dictionary:
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


static func key_of(request: BuildingRequest) -> String:
	return "%s_%s" % [String(request.kind), JSON.stringify(request.to_dict(), "", true).sha256_text().substr(0, 20)]


func _slope_path(job: Dictionary) -> String:
	var request: BuildingRequest = job["request"]
	if dir == "" or request.kind in [&"house", &"shop"]:
		return ""
	return dir.path_join(key_of(request) + ".slopes.txt")


func _load_slopes(job: Dictionary) -> void:
	var path: String = _slope_path(job)
	if path == "" or not FileAccess.file_exists(path):
		return
	var kept: Variant = str_to_var(FileAccess.get_file_as_string(path))
	if kept is Dictionary:
		job["slope_cache"] = kept
		job["slopes_loaded"] = (kept as Dictionary).size()
