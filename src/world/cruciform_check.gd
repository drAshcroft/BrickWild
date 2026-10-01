class_name CruciformCheck
extends RefCounted
## Structural acceptance checks for Temple of Four Winds.

static func check(plan: HousePlan, builder: CruciformBuilder) -> Dictionary:
	var failures: Array[String] = []
	var meta: Dictionary = plan.world_meta
	var doors: Array = meta.get("entrances", [])
	var seen_axes := {}
	if doors.size() != 4 or plan.doors.size() != 4:
		failures.append("entrances: expected four cardinal openings")
	else:
		for i in range(4):
			var p: Vector2 = doors[i]["pos"]
			var n: Vector2 = doors[i]["normal"]
			if absf(n.length() - 1.0) > 0.001 or (absf(n.x) > 0.001 and absf(n.y) > 0.001):
				failures.append("entrances: opening is not cardinal")
			var axis_key := "%d,%d" % [roundi(n.x), roundi(n.y)]
			if seen_axes.has(axis_key):
				failures.append("entrances: cardinal direction is duplicated")
			seen_axes[axis_key] = true
			var hall: Rect2 = meta["hall_rect"]
			var half_wall := CruciformGenerator.WALL_T * 0.5
			if (absf(n.x) > 0.5 and (absf(p.x - n.x * (hall.size.x * 0.5 - half_wall)) > 0.01 or absf(p.y) > 0.01)) or \
					(absf(n.y) > 0.5 and (absf(p.y - n.y * (hall.size.y * 0.5 - half_wall)) > 0.01 or absf(p.x) > 0.01)):
				failures.append("entrances: opening is not on its cardinal facade")
			var opposite: Dictionary = doors[(i + 2) % 4]
			var opposite_pos: Vector2 = opposite["pos"]
			if absf(float(doors[i]["width"]) - float(opposite["width"])) > 0.001:
				failures.append("entrances: opposite openings are not mirrored")
			if not is_equal_approx(p.x, -opposite_pos.x) or not is_equal_approx(p.y, -opposite_pos.y):
				failures.append("entrances: cardinal positions are not mirrored in x/z")
	if doors.size() == 4:
		var images: Array = meta.get("images", [])
		if images.size() != 4:
			failures.append("images: expected four facing masses")
		else:
			for i in range(4):
				var image: Dictionary = images[i]
				var image_pos: Vector3 = image["pos"]
				var facing: Vector3 = image["facing"]
				var door_pos: Vector2 = doors[i]["pos"]
				var delta := Vector3(door_pos.x - image_pos.x, 0.0, door_pos.y - image_pos.z).normalized()
				if not builder.has_mass(String(image["id"])) or facing.dot(delta) < 0.99:
					failures.append("images: image %d is missing or faces away from its entrance" % i)
				elif _blocked_sightline(image_pos + Vector3.UP * float(image["height"]) * 0.5,
						Vector3(door_pos.x, image_pos.y + float(image["height"]) * 0.5, door_pos.y),
						builder, String(image["id"])):
					failures.append("images: sightline %d is obstructed" % i)
	for ring_key in ["outer_ring", "inner_ring"]:
		var segments: Array = meta.get(ring_key, [])
		if segments.size() != 4 or not _ring_is_closed(segments):
			failures.append("rings: %s does not form a complete walkable circuit" % ring_key)
	if not _rings_linked(meta.get("outer_ring", []), meta.get("inner_ring", []),
			meta.get("ring_links", [])):
		failures.append("rings: inner and outer circuits are not linked")
	var sikhara: AABB = builder.mass_aabb("sikhara")
	if sikhara.size == Vector3.ZERO:
		failures.append("sikhara: centered tallest mass is missing")
	else:
		if Vector2(sikhara.get_center().x, sikhara.get_center().z).length() > 0.01:
			failures.append("sikhara: not centered")
		for mass in builder.mass_log:
			var aabb: AABB = mass["aabb"]
			if mass["name"] != "sikhara" and aabb.end.y >= sikhara.end.y:
				failures.append("sikhara: not the tallest mass")
				break
	return {"failures": failures, "warnings": []}


static func _ring_is_closed(segments: Array) -> bool:
	if segments.size() != 4:
		return false
	var rects: Array[Rect2] = []
	for item in segments:
		var r: Rect2 = item
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			return false
		rects.append(r)
	return rects[0].intersects(rects[2], true) and rects[0].intersects(rects[3], true) and \
		rects[1].intersects(rects[2], true) and rects[1].intersects(rects[3], true)


static func _rings_linked(outer: Array, inner: Array, links: Array) -> bool:
	if links.is_empty():
		return false
	for item in links:
		var r: Rect2 = item
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			return false
		var touches_outer := false
		var touches_inner := false
		for outside in outer:
			var outer_rect: Rect2 = outside
			touches_outer = touches_outer or r.intersects(outer_rect, true)
		for inside in inner:
			var inner_rect: Rect2 = inside
			touches_inner = touches_inner or r.intersects(inner_rect, true)
		if not touches_outer or not touches_inner:
			return false
	return true


static func _blocked_sightline(from: Vector3, to: Vector3, builder: CruciformBuilder,
		image_id: String) -> bool:
	for mass in builder.mass_log:
		var name := String(mass["name"])
		if name == image_id or name == "hall_floor" or name.begins_with("outer_ring_") \
				or name.begins_with("inner_ring_") or name.begins_with("ring_link_"):
			continue
		var aabb: AABB = mass["aabb"]
		if _segment_hits_aabb(from, to, aabb):
			return true
	return false


static func _segment_hits_aabb(a: Vector3, b: Vector3, box: AABB) -> bool:
	var direction := b - a
	var t_min := 0.0
	var t_max := 1.0
	for axis in range(3):
		var origin: float
		var delta: float
		var low: float
		var high: float
		match axis:
			0:
				origin = a.x
				delta = direction.x
				low = box.position.x
				high = box.end.x
			1:
				origin = a.y
				delta = direction.y
				low = box.position.y
				high = box.end.y
			_:
				origin = a.z
				delta = direction.z
				low = box.position.z
				high = box.end.z
		if absf(delta) < 0.0001:
			if origin < low or origin > high:
				return false
			continue
		var t0 := (low - origin) / delta
		var t1 := (high - origin) / delta
		if t0 > t1:
			var swap := t0
			t0 = t1
			t1 = swap
		t_min = maxf(t_min, t0)
		t_max = minf(t_max, t1)
		if t_min > t_max:
			return false
	return t_max > 0.02 and t_min < 0.98
