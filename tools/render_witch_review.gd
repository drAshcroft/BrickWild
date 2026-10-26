extends "res://tools/render_shots.gd"
## WITCH-REVIEW renders (real renderer, NOT headless): the 6 frozen witch huts
## and the oversize clamp control from tests/fixtures/personality/witch_requests.json,
## roofs ON, two views each:
##   _exterior  three-quarter, from the door side, a little above eye height
##   _interior  eye level (1.6 m) inside the hearth room, aimed at the cooking
##              recess (stove + cauldron) and, where the angle allows, a broom.
## The interior camera is chosen from the plan: the hearth breast
## (HouseGeometry.hearth_breast) and the broom records (plan.witch_props).
## Output: artifacts/witch_review/renders/<case>_<view>.png
const FIXTURE := "res://tests/fixtures/personality/witch_requests.json"

func _init() -> void:
	_build_stage()
	await process_frame
	_cam.current = true
	var out := "res://artifacts/witch_review/renders"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for row in parsed["cases"]:
		var role := String(row.get("role", ""))
		if role != "witch" and role != "clamp_control":
			continue
		var q: Dictionary = row["request"]
		var id := String(row["id"])
		var request := BuildingRequest.house(int(q["seed"]), &"witch_hut", &"none",
			float(q["width"]), float(q["length"]), float(q["height"]), int(q["storeys"]))
		var generated: GeneratedBuilding = BrickWild.generate(request)
		if not generated.is_ok() or generated.plan == null:
			printerr("generation failed: ", id)
			continue
		var plan: HousePlan = generated.plan
		var building: Node3D = HouseAssembler.build(plan, false)
		_root3d.add_child(building)
		await process_frame
		_family = &"house"
		var door: Dictionary = plan.doors[plan.entrance()]
		var n := Vector2(door["normal"]).normalized()
		var tang := Vector2(n.y, -n.x)
		var dp := Vector2(door["pos"])
		var span := maxf(plan.spec.width, plan.spec.length)
		var rise := HouseGeometry.roof_rise(plan.spec)
		_cam.fov = 50.0
		var eye := dp + n * (span * 1.15) + tang * (span * 0.75)
		_cam.position = Vector3(eye.x, 3.4 + span * 0.12, eye.y)
		_cam.look_at(Vector3(0.0, (plan.spec.height + rise) * 0.55, 0.0), Vector3.UP)
		_set_shot_lighting(atan2(n.x, n.y), 8.0)
		await _save("%s/%s_exterior.png" % [out, id])

		var shot := _interior_shot(plan)
		_cam.fov = float(shot["fov"])
		var p: Vector3 = shot["pos"]
		_cam.position = p
		_cam.look_at(shot["aim"], Vector3.UP)
		_set_shot_lighting(atan2(n.x, n.y), 8.0)
		print("%s interior: cam=%s aim=%s broom_in_frame=%s" % [id, p, shot["aim"], shot["brooms"]])
		await _save("%s/%s_interior.png" % [out, id])
		# supplementary: the broom itself, for plans where the main view misses it
		var bshot := _broom_shot(plan)
		if not bshot.is_empty():
			_cam.fov = 75.0
			_cam.position = bshot["pos"]
			_cam.look_at(bshot["aim"], Vector3.UP)
			await _save("%s/%s_broom.png" % [out, id])
		building.queue_free()
		await process_frame
	quit(0)


## Standing point (1.6 m) on the hearth room's floor, off the furniture, from
## which the breast (cauldron and stove) is in frame and, preferably, a broom too.
func _interior_shot(plan: HousePlan) -> Dictionary:
	var breast: Dictionary = HouseGeometry.hearth_breast(plan)
	var room := int(breast["room"])
	var floor_rect := HouseGeometry.room_floor_rect(plan, room).grow(-0.4)
	var bc := Vector2(breast["centre"])
	var targets: Array[Vector2] = [bc]
	var stove: Dictionary = breast.get("stove", {})
	if not stove.is_empty():
		targets.append(Vector2(stove["centre"]))
	for f in plan.furniture:
		if int(f.get("room", -1)) == room and String(f.get("key", "")) == "Cauldron":
			var r: Rect2 = f["rect"]
			targets.append(r.get_center())
	var brooms: Array[Vector2] = []
	for rec in plan.witch_props:
		if String(rec.get("kind", "")) == "broom" and int(rec.get("room", -1)) == room:
			var r: Rect2 = rec["rect"]
			brooms.append(r.get_center())
	var best := {"score": -1e9}
	var x := floor_rect.position.x
	while x <= floor_rect.end.x:
		var y := floor_rect.position.y
		while y <= floor_rect.end.y:
			var c := Vector2(x, y)
			y += 0.25
			var blocked := false
			for f in plan.furniture:
				var fr: Rect2 = f["rect"]
				if fr.grow(0.3).has_point(c) and not bool(f.get("mounted", false)):
					blocked = true
			if blocked or Rect2(breast["rect"]).grow(0.3).has_point(c):
				continue
			var dist := c.distance_to(bc)
			if dist < 1.6:
				continue
			var aim_dir := (bc - c).normalized()
			var half := 40.0
			var score := -absf(dist - 3.2)
			for t in targets:
				if rad_to_deg(absf(aim_dir.angle_to((t - c).normalized()))) <= half:
					score += 3.0
			var seen: Array = []
			for b in brooms:
				if rad_to_deg(absf(aim_dir.angle_to((b - c).normalized()))) <= half and c.distance_to(b) > 0.8:
					score += 5.0
					seen.append(b)
			# a clear line to the breast
			for k in range(1, 12):
				var pt := c.lerp(bc, float(k) / 12.0)
				for f in plan.furniture:
					var fr2: Rect2 = f["rect"]
					if not bool(f.get("mounted", false)) and fr2.has_point(pt) and pt.distance_to(bc) > 0.6:
						score -= 1.0
			if score > float(best["score"]):
				best = {"score": score, "pos": Vector3(c.x, 1.6, c.y), "seen": seen}
		x += 0.25
	if not best.has("pos"):
		var c0 := floor_rect.get_center()
		best = {"pos": Vector3(c0.x, 1.6, c0.y), "seen": []}
	var cam2 := Vector2(best["pos"].x, best["pos"].z)
	var aim2 := bc
	var seen2: Array = best["seen"]
	if not seen2.is_empty():
		var b0: Vector2 = seen2[0]
		aim2 = bc.lerp(b0, 0.4)
	return {"pos": best["pos"], "aim": Vector3(aim2.x, 0.9, aim2.y), "fov": 85.0, "brooms": seen2.size()}


## Standing point ~2 m from the first broom, off the furniture, in its room.
func _broom_shot(plan: HousePlan) -> Dictionary:
	for rec in plan.witch_props:
		if String(rec.get("kind", "")) != "broom":
			continue
		var room := int(rec["room"])
		var fl := HouseGeometry.room_floor_rect(plan, room).grow(-0.4)
		var r: Rect2 = rec["rect"]
		var bc := r.get_center()
		var best := Vector2.INF
		var best_s := 1e9
		var x := fl.position.x
		while x <= fl.end.x:
			var y := fl.position.y
			while y <= fl.end.y:
				var c := Vector2(x, y)
				y += 0.25
				var bad := false
				for f in plan.furniture:
					var fr: Rect2 = f["rect"]
					if fr.grow(0.3).has_point(c) and not bool(f.get("mounted", false)):
						bad = true
				if bad:
					continue
				var s := absf(c.distance_to(bc) - 2.0)
				# prefer standing in front of the wall the broom leans on
				var toward := (c - bc).normalized()
				s += (1.0 - toward.dot(Vector2(rec["normal"]))) * 1.5
				if s < best_s:
					best_s = s
					best = c
			x += 0.25
		if best.is_finite():
			return {"pos": Vector3(best.x, 1.6, best.y), "aim": Vector3(bc.x, 0.7, bc.y)}
	return {}


func _save(path: String) -> Error:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered: Image = _vp.get_texture().get_image()
	return rendered.save_png(ProjectSettings.globalize_path(path))
