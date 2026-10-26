extends "res://tools/render_shots.gd"
## CULTURE-FURNISH-VOCAB review renders (real renderer, NOT headless): the
## furnished minka (asian), Sahel courtyard house (african) and roundhouse on
## their three frozen requests (8 x 10 m, seeds 1, 8102, 21325).
##   <style>_<seed>_interior  eye level, roof on, in the room with most of the
##                            household's stock, looking across it
##   <style>_<seed>_cutaway   roof off, from above at a steep angle: every room
## Output: artifacts/culture_furnish/renders/
const CULTURE := preload("res://src/house/house_culture_furnish.gd")


func _init() -> void:
	_build_stage()
	await process_frame
	_cam.current = true
	var out := "res://artifacts/culture_furnish/renders"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for style in [&"asian", &"african", &"roundhouse"]:
		for seed_value in [1, 8102, 21325]:
			var spec := HouseTraitMeasure.make_spec(style, 8.0, 10.0, 2.6, 1)
			var plan: HousePlan = HouseGenerator.generate(spec, seed_value, true)
			var raise := HouseGeometry.floor_raise(plan.spec)
			_family = &"house"
			# the room with most looked rows
			var looks: Dictionary = CULTURE.looks(plan)
			var count := {}
			for i in looks:
				var r := int(plan.furniture[i]["room"])
				count[r] = int(count.get(r, 0)) + (3 if String(looks[i]) in ["low_table", "futon", "rope_bed", "pallet", "tokonoma", "grinding_stone"] else 1)
			var room := 0
			for r in count:
				if int(count[r]) > int(count.get(room, 0)):
					room = r
			var rr := HouseGeometry.room_floor_rect(plan, room)
			var eye: Vector2
			var aim: Vector2
			if plan.room_count() == 1 and style == &"roundhouse":
				# a round room: stand inside the door, look across the fire
				var e := plan.entrance()
				var dn := Vector2(plan.doors[e]["normal"]).normalized()
				var dpos := Vector2(plan.doors[e]["pos"])
				eye = dpos - dpos.normalized() * 1.3
				aim = eye.lerp(Vector2.ZERO, 2.0)
			else:
				# from the corner farthest from the furniture's middle, across it
				var mid := Vector2.ZERO
				var n := 0
				for i in looks:
					if int(plan.furniture[i]["room"]) == room:
						mid += Rect2(plan.furniture[i]["rect"]).get_center()
						n += 1
				mid = mid / float(maxi(n, 1)) if n > 0 else rr.get_center()
				# the eye point farthest from the stock's middle that has no
				# furniture within 0.7 m of it
				var inner := rr.grow(-0.35)
				var best := inner.get_center()
				var best_score := -INF
				for gx in range(9):
					for gy in range(9):
						var c := inner.position + Vector2(inner.size.x * gx / 8.0, inner.size.y * gy / 8.0)
						var gap := 9.0
						for f in plan.furniture:
							if int(f["room"]) == room and not bool(f.get("mounted", false)):
								var fr := Rect2(f["rect"])
								var q := Vector2(clampf(c.x, fr.position.x, fr.end.x), clampf(c.y, fr.position.y, fr.end.y))
								gap = minf(gap, q.distance_to(c))
						var score := c.distance_to(mid) - (10.0 if gap < 0.7 else 0.0)
						if score > best_score:
							best_score = score
							best = c
				eye = best
				aim = mid.lerp(rr.get_center(), 0.3)
			var building: Node3D = HouseAssembler.build(plan, false)
			_root3d.add_child(building)
			await process_frame
			_cam.fov = 82.0
			_cam.position = Vector3(eye.x, raise + HouseGeometry.FLOOR_T + 1.45, eye.y)
			_cam.look_at(Vector3(aim.x, raise + 0.35, aim.y), Vector3.UP)
			_set_shot_lighting(0.7, 8.0)
			await _save_review_image(out.path_join("%s_%d_interior.jpg" % [style, seed_value]))
			building.queue_free()
			await process_frame
			var cut: Node3D = HouseAssembler.build(plan, true)
			_root3d.add_child(cut)
			await process_frame
			var c0 := HouseGeometry.site_rect(plan.spec).get_center()
			_cam.fov = 50.0
			_cam.position = Vector3(c0.x + 4.5, raise + 13.0, c0.y + 7.5)
			_cam.look_at(Vector3(c0.x, raise, c0.y), Vector3.UP)
			_set_shot_lighting(0.7, 8.0)
			await _save_review_image(out.path_join("%s_%d_cutaway.jpg" % [style, seed_value]))
			cut.queue_free()
			await process_frame
	quit(0)


func _save_review_image(path: String) -> Error:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered: Image = _vp.get_texture().get_image()
	return rendered.save_jpg(ProjectSettings.globalize_path(path), 0.92)
