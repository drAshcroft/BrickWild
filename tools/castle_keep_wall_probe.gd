extends SceneTree
## Why will no wall take a piece in this castle keep room?
##
## Builds the keep of a castle, then for each room prints the floor rect, the
## walls the placer will walk, the floor already spoken for, and whether the
## ordinary wall placer can stand each top-up category there.
##
##   godot --headless --path . --script res://tools/castle_keep_wall_probe.gd -- sweep crusader castle 1 keep
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := String(args[0] if args.size() > 0 else "sweep")
	var spec := CastleSpec.new()
	if mode == "sweep":
		spec = CastleSweep.spec_at(StringName(args[1] if args.size() > 1 else "crusader"),
			StringName(args[2] if args.size() > 2 else "castle"), int(args[3] if args.size() > 3 else 1))
	else:
		spec.style = StringName(args[1] if args.size() > 1 else "crusader")
		spec.width = float(args[3] if args.size() > 3 else 90.0)
		spec.length = float(args[4] if args.size() > 4 else 140.0)
		spec.height = 20.0
		CastleGenerator.generate(spec, int(args[5] if args.size() > 5 else 9118))
	var builder := CastleBuilder.new()
	builder.build(spec)
	for row in builder.interiors:
		if args.size() > 4 and mode == "sweep" and not args.has(String(row.id)):
			continue
		if args.size() > 6 and mode != "sweep" and not args.has(String(row.id)):
			continue
		var plan: HousePlan = row.plan
		print("== %s" % String(row.id))
		for room in range(plan.room_count()):
			_room(plan, spec, room)
	quit()


func _room(plan: HousePlan, spec: CastleSpec, room: int) -> void:
	var rect := HouseGeometry.room_floor_rect(plan, room)
	print("-- room %d %s rect=%s area=%.1f polygonal=%s outline=%d" % [room,
		String(plan.rooms[room].kind), rect, HouseGeometry.room_area(plan, room),
		plan.is_polygonal(room), plan.outline_of(room).size()])
	var walls := HouseGeometry.room_walls(plan, room)
	for i in range(walls.size()):
		var w: Dictionary = walls[i]
		print("     wall %d from=%s to=%s normal=%s length=%.2f" % [i, w["from"], w["to"],
			w["normal"], Vector2(w["from"]).distance_to(Vector2(w["to"]))])
	for d in plan.doors_of(room):
		var door: Dictionary = plan.doors[d]
		print("     door %d pos=%s normal=%s ext=%s" % [d, door["pos"], door["normal"],
			door.get("exterior", false)])
	for w in plan.windows_of(room):
		print("     window %d pos=%s normal=%s w=%.2f sill=%.2f" % [w, plan.windows[w]["pos"],
			plan.windows[w]["normal"], float(plan.windows[w]["width"]), float(plan.windows[w]["sill"])])
	var blocked := HouseFurnishPlacement.initial_blocked(plan, room)
	for b in blocked:
		print("     blocked %s" % b)
	var kept_zones: Array[Rect2] = []
	for index in plan.furniture_of(room):
		var placed: Dictionary = plan.furniture[index]
		if placed.get("mounted", false):
			continue
		blocked.append(Rect2(placed["rect"]))
		var zone: Rect2 = placed.get("zone", Rect2())
		if zone.size != Vector2.ZERO:
			kept_zones.append(zone)
		print("     furniture %s %s zone=%s" % [placed["key"], placed["rect"],
			placed.get("zone", Rect2())])
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for cat in ["bookcase", "chest", "storage", "crate", "barrel", "bench", "table", "bed"]:
		var trial: HousePlan = plan
		var before := trial.furniture.size()
		var trial_blocked := blocked.duplicate()
		var trial_zones := kept_zones.duplicate()
		var step := {"opt": 0.5, "wall_only": true}
		HouseFurnishPlacement.place_one(trial, trial.spec, room, cat, &"wall",
			trial_blocked, trial_zones, rng, step)
		var added := trial.furniture.size() - before
		var what := ""
		if added > 0:
			what = "%s at %s" % [trial.furniture[before]["key"], trial.furniture[before]["rect"]]
		print("     wall %-10s -> %d %s" % [cat, added, what])
		trial.furniture.resize(before)
	if room == 2:
		for cat in ["bookcase", "chest", "storage", "bench", "barrel"]:
			_diagnose(plan, room, String(PropCatalog.of_category_for_room(cat,
				plan.kind_of(room))[0]), HouseFurnishPlacement.initial_blocked(plan, room), [])


## Why does no facet take this piece? Counted by the first test that says no.
func _diagnose(plan: HousePlan, room: int, key: String, blocked: Array[Rect2],
		zones: Array[Rect2]) -> void:
	var floor_rect := HouseGeometry.room_floor_rect(plan, room)
	var walls := HouseGeometry.room_walls(plan, room)
	var extra: Array[Rect2] = HouseFurnishPlacement._window_blocks(plan, room, key)
	var raw := PropCatalog.footprint(key)
	var reasons := {}
	for wi in range(walls.size()):
		var wall: Dictionary = walls[wi]
		var n := Vector2(wall.normal)
		var yaw := HouseFurnishGeometry.yaw_facing(n)
		var a := Vector2(wall.from)
		var b := Vector2(wall.to)
		var along := (b - a).normalized()
		var run := (b - a).length()
		var small: float = raw.x * PropCatalog.min_scale(key)
		var steps := clampi(int((run - small) / HouseFurnishPlacement.PROBE_STEP), 1,
			HouseFurnishPlacement.MAX_PROBES)
		for s in range(steps + 1):
			var t := (small / 2.0) + float(s) * (run - small) / float(steps)
			var centre := a + along * t + n * (raw.y / 2.0 + HouseGeometry.WALL_GAP)
			for zs in [1.0, -1.0]:
				var cand := HouseFurnishGeometry.candidate(key, centre, yaw, zs)
				if PropCatalog.category(key) in ["seat", "bench"]:
					var z0: Rect2 = cand["zone"]
					var c0: Vector2 = Rect2(cand["rect"]).get_center()
					var strip0: PackedVector2Array = cand.get("zone_strip",
						PackedVector2Array())
					HouseFurnishGeometry.set_zone(cand,
						Rect2(c0 * 2.0 - z0.get_center() - z0.size / 2.0, z0.size))
					var mirrored := PackedVector2Array()
					for corner in strip0:
						mirrored.append(c0 * 2.0 - corner)
					if not mirrored.is_empty():
						cand["zone_strip"] = mirrored
				var why := _why(plan, room, cand, floor_rect, blocked, zones, extra)
				if key == "Bench" and wi == 10 and s == steps / 2 and zs > 0.0:
					print("     DEBUG yaw=%.4f centre=%s rect=%s" % [yaw, centre, cand["rect"]])
					var turned := Poly.oriented_rect(Rect2(cand["rect"]).get_center(),
						PropCatalog.footprint(key), float(cand["yaw"]))
					for p in turned:
						print("       corner %s inside=%s" % [p,
							Poly.contains_point(plan.outline_of(room), p, 0.01)])
					print("       zone_strip %s" % [cand.get("zone_strip")])
				reasons[why] = int(reasons.get(why, 0)) + 1
	print("     why %-14s %.2fx%.2f %s" % [key, raw.x, raw.y, reasons])


func _why(plan: HousePlan, room: int, cand: Dictionary, floor_rect: Rect2,
		blocked: Array[Rect2], zones: Array[Rect2], extra: Array[Rect2]) -> String:
	var rect: Rect2 = cand["rect"]
	if not plan.is_polygonal(room) and not floor_rect.grow(0.01).encloses(rect):
		return "body_outside_floor"
	if not HouseFurnishGeometry.clears_domestic_entry(plan, room, rect):
		return "domestic_entry"
	for b in blocked:
		if b.intersects(rect):
			return "body_hits_blocked"
	for z in zones:
		if z.intersects(rect):
			return "body_hits_zone"
	for e in extra:
		if e.intersects(rect):
			return "body_hits_window"
	if not HouseFurnishGeometry.no_slivers(rect, floor_rect):
		return "sliver"
	var zone: Rect2 = cand["zone"]
	if zone.size.x > 0.0:
		if not plan.is_polygonal(room) and not floor_rect.grow(0.02).encloses(zone):
			return "zone_outside_floor"
		for b2 in blocked:
			if b2.intersects(zone):
				return "zone_hits_blocked"
	if not HouseFurnishGeometry.inside_candidate(plan, room, cand):
		return "piece_outside_outline"
	if zone.size.x > 0.0 and not HouseFurnishGeometry.zone_on_floor(plan, room, cand):
		return "zone_outside_outline"
	return "OK"
