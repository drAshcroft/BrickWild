extends SceneTree
## Read-only trace for the compact service failure and large Witch support case.
## Prints only actual service, meal, sleep and pantry rows plus pairwise service conflicts.
const SEEDS := [1, 8102, 21325]
const ROOM_KINDS := [&"hall", &"workshop", &"bedroom", &"store"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for seed_value in SEEDS:
		_probe(seed_value, 7.0, 9.0, 2.6)
	_probe(21325, 17.0, 18.0, 2.8)
	quit(0)

func _request(seed_value: int, width: float, length: float, height: float) -> BuildingRequest:
	return BuildingRequest.from_dict({
		"schema": "brickwild.request", "schema_version": 1, "kind": "house",
		"style": "witch_hut", "purpose": "none", "seed": str(seed_value),
		"width": width, "length": length, "height": height, "storeys": 1,
		"material": "timber", "enclosure": "none", "water": "none",
		"orientation": 0.0, "period": 1200,
	})

func _probe(seed_value: int, width: float, length: float, height: float) -> void:
	print("\nCASE seed=", seed_value, " size=", width, "x", length)
	var built: GeneratedBuilding = BrickWild.generate(_request(seed_value, width, length, height))
	if not built.is_ok() or built.plan == null:
		print("BUILD_FAIL ", str(built.errors))
		return
	var spec: HouseSpec = built.spec as HouseSpec
	var plan: HousePlan = HouseGenerator.generate(spec, seed_value, false)
	plan.domestic_layout["_witch_placement_trace"] = true
	print("TRACE_BEGIN before furnishing/nav/repair seed=", seed_value, " layout=", str(plan.domestic_layout))
	HouseFurnisher.furnish(plan, spec)
	print("TRACE_END after furnishing repair seed=", seed_value, " furniture_count=", plan.furniture.size(), " compromises=", str(plan.compromises))
	for kind in ROOM_KINDS:
		var rooms := plan.rooms_of(kind)
		for room in rooms:
			print("ROOM ", String(kind), " index=", room, " floor=", str(HouseGeometry.room_floor_rect(plan, room)),
				" regions=", str(plan.rooms[room].get("activity_regions", {})),
				" station=", str(plan.rooms[room].get("shared_activity_station", {})))
			for index in plan.furniture_of(room):
				var piece: Dictionary = plan.furniture[index]
				var category := String(piece.get("cat", ""))
				if category in ["workbench", "hearth", "storage", "bucket", "cookware", "shelf", "sconce", "alchemy", "books", "table", "seat", "bed", "chest", "lamp"]:
					_print_piece(plan, room, index, piece)
			var walls := HouseGeometry.room_walls(plan, room)
			for host in plan.wall_hosts:
				if int(host.get("room", -1)) == room and String(host.get("role", "")) == "activity_support":
					var wall_index := int(host.get("wall", -1))
					var wall_text := str(walls[wall_index]) if wall_index >= 0 and wall_index < walls.size() else "INVALID_WALL"
					print("WALL_HOST room=", room, " ", str(host), " wall=", wall_text)
	var service_rooms: Array[int] = plan.rooms_of(&"hall") + plan.rooms_of(&"workshop")
	for room in service_rooms:
		_print_conflicts(plan, room)
	var nav := HouseNavCheck.new().check(plan)
	print("FINAL_NAV ok=", nav.get("ok", false), " result=", str(nav))
	print("ACTIVITY_STATUS ", str(plan.domestic_layout.get("activity_status", "")),
		" shortfalls=", str(plan.domestic_layout.get("activity_shortfalls", [])))

func _print_piece(plan: HousePlan, room: int, index: int, piece: Dictionary) -> void:
	var key := String(piece.get("key", ""))
	var scale := float(piece.get("scale", 1.0))
	var yaw := float(piece.get("yaw", 0.0))
	var model_yaw := yaw + PropCatalog.face_offset(key)
	var origin: Vector3 = PropCatalog.house_origin(piece)
	var centre: Vector2 = PropCatalog.plan_centre(key, origin, model_yaw, scale)
	var footprint: Vector2 = PropCatalog.footprint_rotated(key, model_yaw) * scale
	var measured_rect := Rect2(centre - footprint * 0.5, footprint)
	var height_scale := PropCatalog.placement_height_scale(piece)
	var bottom := origin.y + PropCatalog.floor_offset(key) * height_scale
	var top := origin.y + (PropCatalog.floor_offset(key) + PropCatalog.height(key)) * height_scale
	print("ITEM room=", room, " i=", index, " key=", key,
		" cat=", piece.get("cat", ""), " group=", piece.get("activity_group", ""),
		" shared=", str(piece.get("shared_activity_groups", [])),
		" center=", str(centre), " stored_rect=", str(piece.get("rect", Rect2())),
		" measured_rect=", str(measured_rect), " zone=", str(piece.get("zone", Rect2())),
		" y=", origin.y, " bottom=", bottom, " top=", top,
		" yaw=", yaw, " scale=", scale, " height_scale=", height_scale,
		" mounted=", piece.get("mounted", false), " host=", piece.get("host", -1),
		" anchor=", piece.get("activity_anchor_id", ""),
		" mount_relation=", piece.get("mount_relation", ""),
		" wall_host_id=", piece.get("wall_host_id", ""),
		" content=", piece.get("content_kind", ""), "/", piece.get("content_asset_key", ""))

func _print_conflicts(plan: HousePlan, room: int) -> void:
	var groups: Dictionary = {"cooking": [], "witchwork": []}
	for index in plan.furniture_of(room):
		var piece: Dictionary = plan.furniture[index]
		var group := String(piece.get("activity_group", ""))
		if not groups.has(group):
			continue
		var key := String(piece.get("key", ""))
		var scale := float(piece.get("scale", 1.0))
		var yaw := float(piece.get("yaw", 0.0))
		var model_yaw := yaw + PropCatalog.face_offset(key)
		var origin: Vector3 = PropCatalog.house_origin(piece)
		var measured := PropCatalog.footprint_rotated(key, model_yaw) * scale
		var center := PropCatalog.plan_centre(key, origin, model_yaw, scale)
		var body := Rect2(center - measured * 0.5, measured)
		var use := Rect2(piece.get("zone", Rect2()))
		if bool(piece.get("mounted", false)) or PropCatalog.has_tag(key, PropCatalog.ON_SURFACE) or PropCatalog.has_tag(key, PropCatalog.CEILING):
			use = Rect2()
		var hs := PropCatalog.placement_height_scale(piece)
		var bottom := origin.y + PropCatalog.floor_offset(key) * hs
		var top := origin.y + (PropCatalog.floor_offset(key) + PropCatalog.height(key)) * hs
		groups[group].append({"index": index, "key": key, "body": body, "zone": use, "bottom": bottom, "top": top})
	for c in groups["cooking"]:
		for w in groups["witchwork"]:
			var cbody: Rect2 = c["body"]
			var wbody: Rect2 = w["body"]
			var cz: Rect2 = c["zone"]
			var wz: Rect2 = w["zone"]
			var overlap_h := minf(float(c["top"]), float(w["top"])) - maxf(float(c["bottom"]), float(w["bottom"]))
			if cbody.intersects(wbody) or cbody.intersects(wz) or wbody.intersects(cz):
				print("PAIR cooking=", c["index"], ":", c["key"], " witchwork=", w["index"], ":", w["key"],
					" body_body=", cbody.intersects(wbody), " cooking_body_witch_zone=", cbody.intersects(wz),
					" witch_body_cook_zone=", wbody.intersects(cz), " height_overlap=", overlap_h,
					" cooking_body=", str(cbody), " cooking_zone=", str(cz),
					" witch_body=", str(wbody), " witch_zone=", str(wz),
					" cooking_y=", c["bottom"], "..", c["top"], " witch_y=", w["bottom"], "..", w["top"])
