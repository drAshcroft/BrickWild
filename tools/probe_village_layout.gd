extends SceneTree
## VREAL-LAYOUT probe: plan villages the way the walk does (flat ground, no
## extras) and write what a person standing in them would notice -- every
## building's measured footprint, storeys and lot, the gaps between
## neighbours, how far each building stands from the common, and how far the
## enclosure stands from the houses -- as JSON for tools/settlements/layout_compare.py.
##
##   godot --headless --path . --script res://tools/probe_village_layout.gd -- \
##       [series=mixed] [stops=1,2,3] [seeds=1] [out=artifacts/vreal_layout/probe.json]
##       [population=N] [enclosure=wall] [extras=1]
##       [variants=nopack,pack]   measure each stop's buildings ONCE, then plan
##                                it under each named setting (`_apply_variant`);
##                                every row carries its `variant`

const _Walk := preload("res://visualqa/walk/walk_village.gd")


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	# NOPACK=1 measures a plan without snapping or joining (VREAL-PACK's control)
	VillageLotPlanner.pack_enabled = OS.get_environment("NOPACK") != "1"
	var series: String = args.get("series", "mixed")
	var out_path: String = args.get("out", "res://artifacts/vreal_layout/probe.json")
	var stops: Array = JSON.parse_string(FileAccess.get_file_as_string(
		"res://visualqa/villages/%s.json" % series))["stops"]
	var picks: Array[int] = []
	if args.has("stops"):
		for s in String(args["stops"]).split(","):
			picks.append(int(s))
	else:
		for i in stops.size():
			picks.append(i + 1)
	var seeds: Array[int] = []
	for s in String(args.get("seeds", "")).split(",", false):
		seeds.append(int(s))
	var rows: Array = []
	for n in picks:
		var stop: Dictionary = (stops[n - 1] as Dictionary).duplicate(true)
		if not args.has("extras"):
			stop.erase("extras")
		stop.erase("terrain")
		if args.has("population"):
			stop["population"] = int(args["population"])
		if args.has("enclosure"):
			stop["enclosure"] = String(args["enclosure"])
		var stop_seeds: Array[int] = seeds.duplicate()
		if stop_seeds.is_empty():
			stop_seeds.append(int(stop.get("seed", n)))
		for v_seed in stop_seeds:
			if args.has("variants"):
				rows.append_array(_variants(stop, n, v_seed, String(args["variants"]).split(",")))
				continue
			var t0 := Time.get_ticks_msec()
			var planned: Dictionary = _Walk.plan(stop, v_seed)
			if planned.has("error"):
				print("stop %d seed %d: %s" % [n, v_seed, planned["error"]])
				continue
			var row := _describe(planned["plan"], stop, n, v_seed)
			row["t_s"] = (Time.get_ticks_msec() - t0) / 1000.0
			rows.append(row)
			print("stop %d seed %d: %d buildings, site %s, %.1f s" % [n, v_seed,
				(row["buildings"] as Array).size(), row["site"], row["t_s"]])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"plans": rows}, " "))
	f.close()
	print("wrote ", out_path)
	quit(0)


## The walk's own spec and programme (walk_village.gd `plan`), measured once and
## planned under each variant: an A/B whose two sides share every building.
func _variants(stop: Dictionary, n: int, v_seed: int, names: PackedStringArray) -> Array:
	var out: Array = []
	var spec := VillageSpec.new(v_seed)
	spec.population = int(stop.get("population", 40))
	for f in ["culture", "purpose", "water", "enclosure"]:
		if stop.has(f):
			spec.set(f, StringName(stop[f]))
	if stop.has("wealth"):
		spec.wealth = float(stop["wealth"])
	spec.generate(v_seed)
	var requests: Array[BuildingRequest] = VillageProgrammer.programme(spec)
	requests.append_array(_Walk.extras_of(stop, v_seed))
	var t0 := Time.get_ticks_msec()
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(requests)
	print("stop %d seed %d: measured %d in %.1f s" % [n, v_seed, jobs.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	for name in names:
		_apply_variant(name)
		var t1 := Time.get_ticks_msec()
		var p := VillageLotPlanner.plan_measured(spec, jobs)
		var row := _describe(p, stop, n, v_seed)
		row["variant"] = name
		row["t_s"] = (Time.get_ticks_msec() - t1) / 1000.0
		out.append(row)
		print("   %-16s %d buildings, site %s, %.1f s" % [name, p.buildings.size(), row["site"], row["t_s"]])
	_apply_variant("")
	return out


## Planner switches by name, '+'-joined: `nopack` (VREAL-PACK off), `pack`;
## `gmax`, `gmedian`, `gnone` (VREAL-GRADIENT's floor); `k1.0` (join_share_k);
## `jit0.35` (gradient_jitter).
func _apply_variant(name: String) -> void:
	VillageLotPlanner.pack_enabled = true
	VillageLotPlanner.gradient_mode = VillageLotPlanner.GRADIENT_MODE
	VillageLotPlanner.join_share_k = VillageLotPlanner.JOIN_SHARE_K
	VillageLotPlanner.gradient_jitter = VillageLotPlanner.GRADIENT_JITTER
	VillageLotPlanner.gradient_floor_filters = false
	for token in name.split("+", false):
		if token.begins_with("k") and token.substr(1).is_valid_float():
			VillageLotPlanner.join_share_k = float(token.substr(1))
			continue
		if token.begins_with("jit") and token.substr(3).is_valid_float():
			VillageLotPlanner.gradient_jitter = float(token.substr(3))
			continue
		match token:
			"shipped":
				pass
			"gfilter":
				VillageLotPlanner.gradient_floor_filters = true
			"gmax", "gmedian", "gnone":
				VillageLotPlanner.gradient_mode = StringName(token.substr(1))
			"nopack":
				VillageLotPlanner.pack_enabled = false
			"pack":
				VillageLotPlanner.pack_enabled = true
			_:
				push_error("unknown variant token " + token)


func _describe(p: VillagePlan, stop: Dictionary, n: int, v_seed: int) -> Dictionary:
	var cc: Vector2 = VillageMeasure.common_centre(p)
	var polys: Array[PackedVector2Array] = []
	var buildings: Array = []
	for b in p.buildings:
		var req: BuildingRequest = b["request"]
		var fp_poly: PackedVector2Array = VillageMeasure.footprint_poly(b)
		var bd_poly: PackedVector2Array = VillageMeasure.bounds_poly(b)
		polys.append(bd_poly)
		var fp: Rect2 = b["placement"]["footprint"]
		var bounds: AABB = b["placement"]["bounds"]
		var c: Vector2 = VillageMeasure.centre(fp_poly)
		buildings.append({
			"kind": String(req.kind), "style": String(req.style), "purpose": String(req.purpose),
			"class": String(b["class"]), "storeys": req.storeys,
			"req_w": req.width, "req_l": req.length,
			"fp_w": snappedf(fp.size.x, 0.01), "fp_l": snappedf(fp.size.y, 0.01),
			"fp_area": snappedf(Poly.area(fp_poly), 0.1),
			"bounds_area": snappedf(Poly.area(bd_poly), 0.1),
			"height": snappedf(bounds.size.y, 0.01),
			"c": [snappedf(c.x, 0.01), snappedf(c.y, 0.01)],
			"poly": _pts(fp_poly),
			"to_common": snappedf(c.distance_to(cc), 0.1),
			"lot_area": snappedf(Poly.area(p.lots[int(b["lot"])]["poly"]), 0.1) if int(b.get("lot", -1)) >= 0 else 0.0,
		})
	# wall-to-wall: each building's nearest neighbour by bounds polygon distance
	for i in polys.size():
		var best := INF
		for j in polys.size():
			if i != j:
				best = minf(best, VillageMeasure.poly_distance(polys[i], polys[j]))
		buildings[i]["gap_m"] = snappedf(best, 0.01)
	# the enclosure: how far each of its vertices (resampled every 5 m) is from
	# the nearest building, and from the nearest lot
	var wall: Dictionary = {}
	if not p.enclosure.is_empty():
		var samples := _resample(p.enclosure, 5.0)
		var to_b: Array = []
		for s in samples:
			var best := INF
			for poly in polys:
				best = minf(best, VillageMeasure.point_to_poly(s, poly))
			to_b.append(snappedf(best, 0.1))
		wall = {"poly": _pts(p.enclosure), "to_building_m": to_b,
			"perimeter_m": snappedf(_perimeter(p.enclosure), 0.1), "area_m2": snappedf(Poly.area(p.enclosure), 1.0)}
	var roads: Array = []
	for r in p.roads:
		roads.append({"class": String(r["class"]), "width": r["width"], "points": _pts(r["points"])})
	var commons: Array = []
	for c in p.commons:
		commons.append({"kind": String(c.get("kind", "")), "poly": _pts(c["poly"])})
	return {
		"stop": n, "seed": v_seed, "why": stop.get("why", ""),
		"culture": String(p.spec.culture), "purpose": String(p.spec.purpose),
		"population": p.spec.population, "households": p.spec.households,
		"wealth": p.spec.wealth, "form": String(p.spec.form),
		"enclosure": String(p.spec.enclosure),
		"site": [snappedf(p.site.position.x, 0.1), snappedf(p.site.position.y, 0.1),
			snappedf(p.site.size.x, 0.1), snappedf(p.site.size.y, 0.1)],
		"common_centre": [cc.x, cc.y],
		"buildings": buildings, "wall": wall, "roads": roads, "commons": commons,
		"fields": p.fields.size(),
		"shape": VillageShape.measure(p),
		"qa_failures": _qa(p),
	}


## VillageQA's plan-level failures (no per-building checks, no twins), as
## VillageLotPlanner._faults reads them.
static func _qa(p: VillagePlan) -> Array:
	var no_pure := func(_p: VillagePlan) -> Array: return []
	return VillageQA.new().check(p, {&"pure": no_pure}, false)["failures"]


static func _pts(poly: PackedVector2Array) -> Array:
	var out: Array = []
	for v in poly:
		out.append([snappedf(v.x, 0.01), snappedf(v.y, 0.01)])
	return out


static func _perimeter(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		s += poly[i].distance_to(poly[(i + 1) % poly.size()])
	return s


static func _resample(poly: PackedVector2Array, step: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var n: int = maxi(1, int(ceil(a.distance_to(b) / step)))
		for k in n:
			out.append(a.lerp(b, float(k) / float(n)))
	return out
