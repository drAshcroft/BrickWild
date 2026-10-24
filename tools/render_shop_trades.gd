extends "res://tools/render_shots.gd"
## LIVE-SHOPS phase 1: for each counter-trade case in family_style_requests.json,
## render the exterior three-quarter view and an eye-level view from the customer
## door looking in, and write the plan facts beside them.
##
## Must NOT be headless. Run:
##   godot --path . --script res://tools/render_shop_trades.gd [-- kind kind ...]
## Output: artifacts/goal/LIVE-SHOPS/<kind>/{exterior,door_eye}.jpg and
## artifacts/goal/LIVE-SHOPS/plan_facts.json

const FIXTURE := "res://tests/fixtures/family_style_requests.json"
const OUT := "res://artifacts/goal/LIVE-SHOPS"
const KINDS: Array[String] = ["apothecary", "alchemist_laboratory", "bakery", "blacksmith",
	"butcher", "carpenter", "general_store", "tailor", "tavern", "inn", "restaurant"]
const WORK_CATS: Array[String] = ["workbench", "hearth", "anvil", "alchemy", "blade", "bench", "rack"]
const STORAGE_CATS: Array[String] = ["storage", "barrel", "crate", "sack", "chest"]
const NOT_WARES: Array[String] = ["counter", "chair", "stool", "light", "rug", "decor", "plant", "lamp", "candle"]
const EYE := 1.6
const HALF_FOV := 40.0


func _init() -> void:
	_build_stage()
	await process_frame
	var want: Array[String] = []
	for a in OS.get_cmdline_user_args():
		want.append(a)
	var cases := {}
	var f := FileAccess.open(FIXTURE, FileAccess.READ)
	for c in JSON.parse_string(f.get_as_text())["cases"]:
		if String(c["id"]).begins_with("shop/") and String(c["row"]) in KINDS:
			cases[String(c["row"])] = c
	var facts: Array = []
	for kind in KINDS:
		if not want.is_empty() and kind not in want:
			continue
		var c: Dictionary = cases[kind]
		var built: GeneratedBuilding = BrickWild.generate(BuildingRequest.from_dict(c["request"]))
		var plan: HousePlan = built.plan
		var dir := "%s/%s" % [OUT, kind]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var ext_path := "%s/exterior.jpg" % dir
		var eye_path := "%s/door_eye.jpg" % dir
		await _shoot_exterior(built, ext_path)
		await _shoot_door_eye(built, plan, eye_path)
		var row := _facts(c, plan)
		row["images"] = {"exterior_three_quarter": ProjectSettings.globalize_path(ext_path),
			"door_eye": ProjectSettings.globalize_path(eye_path)}
		facts.append(row)
		print("done ", kind)
	var out := FileAccess.open(OUT + "/plan_facts.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(facts, "  "))
	out.close()
	quit()


func _save(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_jpg(path, 0.92)


func _shoot_exterior(built: GeneratedBuilding, path: String) -> void:
	var node: Node3D = BrickWild.instantiate(built, false)
	_root3d.add_child(node)
	await process_frame
	var aabb: AABB = _node_aabb(node)
	var centre: Vector3 = aabb.get_center()
	var radius: float = maxf(aabb.size.length() / 2.0, 1.0)
	_cam.fov = 48.0
	var dist: float = radius / tan(deg_to_rad(_cam.fov) / 2.0) * 1.12
	var yaw := 2.4
	var pitch := -0.22
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = centre + dir * dist
	_cam.look_at(centre, Vector3.UP)
	_family = &"house"
	_set_shot_lighting(yaw, dist + radius)
	await _save(ProjectSettings.globalize_path(path))
	node.queue_free()
	await process_frame


func _door_pose(plan: HousePlan) -> Dictionary:
	var d := plan.entrance()
	var pos: Vector2 = plan.doors[d]["pos"]
	var n: Vector2 = plan.doors[d]["normal"]
	var inside_dir := -n
	# the plan's normal points outward for an exterior door; check against the room
	var room := plan.entrance_room()
	var rc: Vector2 = Rect2(HouseGeometry.room_floor_rect(plan, room)).get_center()
	if (rc - pos).dot(inside_dir) < 0.0:
		inside_dir = -inside_dir
	return {"pos": pos, "dir": inside_dir.normalized()}


func _shoot_door_eye(built: GeneratedBuilding, plan: HousePlan, path: String) -> void:
	var node: Node3D = BrickWild.instantiate(built, true)
	_root3d.add_child(node)
	await process_frame
	var pose := _door_pose(plan)
	var p: Vector2 = pose["pos"]
	var dir: Vector2 = pose["dir"]
	var at := p - dir * 0.15
	_cam.fov = 80.0
	_cam.position = Vector3(at.x, EYE, at.y)
	var look := p + dir * 5.0
	_cam.look_at(Vector3(look.x, 1.3, look.y), Vector3.UP)
	_family = &"house"
	_set_shot_lighting(atan2(dir.x, dir.y), 60.0)
	await _save(ProjectSettings.globalize_path(path))
	node.queue_free()
	await process_frame


# ------------------------------------------------------------------ facts

func _visible(plan: HousePlan, from: Vector2, dir: Vector2, p: Dictionary, room: int) -> bool:
	var r: Rect2 = p["rect"]
	var c := r.get_center()
	var to := c - from
	if to.length() < 0.01:
		return true
	if rad_to_deg(absf(dir.angle_to(to))) > HALF_FOV:
		return false
	# blocked by any tall piece of furniture in the same room whose rect the sight line crosses
	for q in plan.furniture:
		if q == p or int(q["room"]) != room or bool(q.get("mounted", false)):
			continue
		if PropCatalog.height(String(q["key"])) < 1.5:
			continue
		if _seg_hits_rect(from, c, Rect2(q["rect"]).grow(-0.05)):
			return false
	return true


func _seg_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false


func _piece(plan: HousePlan, p: Dictionary, from: Vector2, dir: Vector2, front: int) -> Dictionary:
	var key := String(p["key"])
	return {"prop": key, "cat": PropCatalog.category(key), "room": int(p["room"]),
		"room_kind": String(plan.kind_of(int(p["room"]))),
		"mounted": bool(p.get("mounted", false)),
		"in_line_of_sight": int(p["room"]) == front and _visible(plan, from, dir, p, front)}


func _facts(c: Dictionary, plan: HousePlan) -> Dictionary:
	var kind := String(c["row"])
	var front := plan.entrance_room()
	var pose := _door_pose(plan)
	var from: Vector2 = Vector2(pose["pos"]) + Vector2(pose["dir"]) * 0.3
	var dir: Vector2 = pose["dir"]
	var rooms: Array = []
	for i in plan.room_count():
		var cats := {}
		for fi in plan.furniture_of(i):
			var cat := String(PropCatalog.category(String(plan.furniture[fi]["key"])))
			cats[cat] = int(cats.get(cat, 0)) + 1
		rooms.append({"room": i, "kind": String(plan.kind_of(i)), "storey": plan.storey_of_room(i),
			"is_front": i == front, "categories": cats})
	var counters: Array = []
	var wares: Array = []
	var stations: Array = []
	var storage: Array = []
	for p in plan.furniture:
		var cat := String(PropCatalog.category(String(p["key"])))
		var piece := _piece(plan, p, from, dir, front)
		if cat == "counter":
			counters.append(piece)
		elif int(p["room"]) == front and cat not in NOT_WARES and cat not in ["bed", "table"] \
				or (int(p["room"]) == front and cat == "table"):
			wares.append(piece)
		if cat in WORK_CATS and int(p["room"]) != front:
			stations.append(piece)
		elif cat in WORK_CATS:
			piece["note"] = "work fixture on the customer floor"
			stations.append(piece)
		if cat in STORAGE_CATS and int(p["room"]) != front:
			storage.append(piece)
	# rooms joined by an interior door to a room holding a work fixture
	var work_rooms: Array[int] = []
	for s in stations:
		if not work_rooms.has(int(s["room"])):
			work_rooms.append(int(s["room"]))
	var store_rooms: Array = []
	for s in storage:
		var r := int(s["room"])
		var joined: Array[int] = []
		for w in work_rooms:
			if w == r or _joined(plan, r, w):
				joined.append(w)
		store_rooms.append({"room": r, "kind": s["room_kind"], "joined_to_work_rooms": joined})
	var counter_visible := false
	for k in counters:
		if bool(k["in_line_of_sight"]):
			counter_visible = true
	var wares_visible := wares.filter(func(w): return bool(w["in_line_of_sight"]))
	return {"id": c["id"], "kind": kind, "name": String(plan.spec.variant_name),
		"seed": c["request"]["seed"], "front_room": front, "front_room_kind": String(plan.kind_of(front)),
		"door_pos": [pose["pos"].x, pose["pos"].y], "door_inward": [dir.x, dir.y],
		"counter": {"present": not counters.is_empty(), "pieces": counters, "in_line_of_sight": counter_visible},
		"wares_on_display": {"count_front_room": wares.size(), "visible_from_door": wares_visible.size(), "pieces": wares},
		"staff_work_station": {"present": not stations.is_empty(), "pieces": stations},
		"storage_off_work_area": {"present": store_rooms.any(func(s): return not (s["joined_to_work_rooms"] as Array).is_empty()),
			"storage_rooms": store_rooms, "pieces": storage},
		"rooms": rooms}


func _joined(plan: HousePlan, a: int, b: int) -> bool:
	for d in plan.doors:
		if bool(d.get("exterior", false)):
			continue
		var x := int(d["a"])
		var y := int(d["b"])
		if (x == a and y == b) or (x == b and y == a):
			return true
	return false
