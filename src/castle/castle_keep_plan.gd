extends RefCounted
## The occupied keep and its outer silhouette share these polygons. Rooms,
## openings, stairs and furniture are all planned on the clear inner faces.

const SIDES := 14
const TOP_SCALE := 0.62
const MIN_TOP_SIDE := 6.4


static func outer_outline(spec: CastleSpec, level: int, levels: int) -> PackedVector2Array:
	var box := CastleGeometry.keep_aabb(spec)
	var side := minf(box.size.x, box.size.z)
	if spec.keep_shape in [&"round", &"shell"]:
		var poly := PackedVector2Array()
		for i in range(SIDES):
			var angle := TAU * float(i) / float(SIDES)
			poly.append(Vector2(cos(angle), sin(angle)) * side * 0.5)
		return poly
	if spec.keep_shape == &"tiered":
		var top := maxf(side * TOP_SCALE, minf(side, MIN_TOP_SIDE))
		var width := lerpf(side, top, float(level) / float(maxi(levels - 1, 1)))
		return Poly.from_rect(Rect2(Vector2.ONE * -width * 0.5, Vector2.ONE * width))
	return Poly.from_rect(Rect2(Vector2(-box.size.x, -box.size.z) * 0.5,
		Vector2(box.size.x, box.size.z)))


static func generate(spec: CastleSpec, with_furniture := true) -> HousePlan:
	var plan := HousePlan.new()
	if not spec.keep or CastleGeometry.is_motte(spec):
		return plan
	var box := CastleGeometry.keep_aabb(spec)
	if minf(box.size.x, box.size.z) <= 0.0:
		return plan
	var levels := clampi(int(box.size.y / CastleGenerator.KEEP_STOREY_H), 3,
		HouseGeometry.MAX_STOREYS)
	var hs := CastleGenerator._keep_spec(spec, box, levels)
	var shaped := spec.keep_shape in [&"round", &"shell", &"tiered"]
	hs.porch = false
	hs.chimney = false # The castle owns flues and roof joins.
	hs.exterior_props = false
	var floor_rect := HouseGeometry.interior_rect(hs)
	if minf(floor_rect.size.x, floor_rect.size.y) < CastleGenerator.MIN_KEEP_SIDE \
			or floor_rect.get_area() < CastleGenerator.MIN_KEEP_AREA \
			or maxf(floor_rect.size.x, floor_rect.size.y) > CastleGenerator.MAX_KEEP_SIDE:
		return plan
	plan.spec = hs
	for level in range(levels):
		var room := {"kind": hs.kind_on(level), "rect": floor_rect, "storey": level}
		if shaped:
			var outer := outer_outline(spec, level, levels)
			# The shapes are regular convex polygons: a radial inset preserves
			# exactly one edge per outside face instead of rounding the corners.
			var inset := HouseGeometry.wall_thickness(hs)
			var scale := 1.0
			if spec.keep_shape in [&"round", &"shell"]:
				scale -= inset / (minf(box.size.x, box.size.z) * 0.5 * cos(PI / SIDES))
			else:
				scale -= 2.0 * inset / Poly.bounding_rect(outer).size.x
			var clear := PackedVector2Array()
			for point in outer:
				clear.append(point * scale)
			room.outline = clear
			room.rect = Poly.bounding_rect(clear)
		plan.rooms.append(room)
	for room_index in range(plan.room_count()):
		if not HouseGeometry.room_suits(plan, room_index, plan.kind_of(room_index)):
			return HousePlan.new()
	var walls := HouseGeometry.room_walls(plan, 0)
	var front := _facing_wall(walls, Vector2(0, 1))
	var front_wall: Dictionary = walls[front]
	plan.doors.append({"a": 0, "b": -1,
		"pos": (Vector2(front_wall.from) + Vector2(front_wall.to)) * 0.5,
		"normal": -Vector2(front_wall.normal), "width": HouseGeometry.DOOR_W,
		"exterior": true, "front": true, "storey": 0})
	for level in range(1, levels):
		if not HouseGeometry.is_habitable(hs.kind_on(level)):
			continue
		if shaped:
			_windows(plan, level)
		else:
			CastleGenerator._keep_windows(plan, floor_rect, level, hs,
				3 if hs.kind_on(level) == &"lords_chamber" else -1)
	for level in range(levels - 1):
		if shaped:
			_add_stair(plan, level, level + 1)
		else:
			HousePlanner._add_stair(plan, level, level + 1, level, level + 1)
	var top_walls := HouseGeometry.room_walls(plan, levels - 1)
	plan.hearth = {"room": levels - 1, "wall": _facing_wall(top_walls, Vector2(1, 0))}
	if with_furniture:
		HouseFurnisher.furnish(plan, hs)
	return plan


static func _facing_wall(walls: Array[Dictionary], inward: Vector2) -> int:
	var best := 0
	var score := -INF
	for index in range(walls.size()):
		var dot := Vector2(walls[index].normal).dot(inward)
		if dot > score:
			score = dot
			best = index
	return best


static func _windows(plan: HousePlan, level: int) -> void:
	var walls := HouseGeometry.room_walls(plan, level)
	# A round keep's cardinal X direction falls between two diagonal facets.
	# Keep its front horizontal facet solid for the bed and its side access;
	# the far side is already reserved for the stair landing.
	var blind := _facing_wall(walls, Vector2(0, 1) if walls.size() > 4 else Vector2(-1, 0))
	var head := minf(CastleGenerator.WINDOW_SILL + CastleGenerator.WINDOW_H,
		plan.spec.height - 0.2)
	for wi in range(walls.size()):
		if plan.kind_of(level) == &"lords_chamber" and wi == blind:
			continue
		var wall: Dictionary = walls[wi]
		var length := Vector2(wall.from).distance_to(wall.to)
		var width := minf(CastleGenerator.WINDOW_W,
			length - 2.0 * HouseGeometry.WINDOW_CORNER_MARGIN)
		if width < 0.45:
			continue
		var count := maxi(1, int(length / CastleGenerator.KEEP_WINDOW_PITCH))
		for i in range(count):
			plan.windows.append({"room": level,
				"pos": Vector2(wall.from).lerp(wall.to, (float(i) + 0.5) / float(count)),
				"normal": -Vector2(wall.normal), "width": width,
				"sill": CastleGenerator.WINDOW_SILL, "head": head, "storey": level})


## A common footprint touches a real wall on either landing and fits BOTH
## floors. Sampling against polygon faces avoids placing stairs in AABB corners.
static func _add_stair(plan: HousePlan, lower: int, upper: int) -> void:
	var floor := HouseGeometry.room_floor_rect(plan, upper)
	var run := minf(2.4, maxf(HouseGeometry.PATH_MIN, maxf(floor.size.x, floor.size.y) - 0.3))
	var width := minf(1.0, maxf(HouseGeometry.PATH_MIN, minf(floor.size.x, floor.size.y) - 0.3))
	var front := Vector2(plan.doors[plan.entrance()].pos)
	var best := Rect2()
	var best_score := -INF
	var walls := HouseGeometry.room_walls(plan, upper)
	walls.append_array(HouseGeometry.room_walls(plan, lower))
	var sizes: Array[Vector2] = [Vector2(run, width), Vector2(width, run)]
	for size in sizes:
		for wall in walls:
			var normal := Vector2(wall.normal)
			var support := (absf(normal.x) * size.x + absf(normal.y) * size.y) * 0.5
			var length := Vector2(wall.from).distance_to(wall.to)
			var samples := maxi(int(length / 0.2), 1)
			for step in range(samples + 1):
				var centre := Vector2(wall.from).lerp(wall.to, float(step) / float(samples)) + normal * support
				var rect := Rect2(centre - size * 0.5, size)
				if not _inside(plan, lower, rect) or not _inside(plan, upper, rect):
					continue
				var score := centre.distance_to(front)
				if lower == 0 and _overlap(rect, HousePlanner.door_line(plan, lower, plan.doors[plan.entrance()])):
					score -= 1000.0
				for door in plan.doors:
					if HousePlan.record_storey(door) == lower:
						if _overlap(rect, HouseGeometry.door_clear_rect(door, -1.0)):
							score -= 1000.0
				if score > best_score:
					best = rect
					best_score = score
	if best.size.x <= 0.0:
		return # Missing transition remains a QA failure, never invented floor.
	if best_score < -100.0:
		plan.note_compromise(lower, "stair")
	var centre := best.get_center()
	plan.stairs.append({"a": lower, "b": upper,
		"storey": lower, "to_storey": upper,
		"pos": centre, "lower_pos": centre, "upper_pos": centre,
		"rect": best, "lower_rect": best, "upper_rect": best,
		"width": width, "run": run})


static func _inside(plan: HousePlan, room: int, rect: Rect2) -> bool:
	for point in Poly.from_rect(rect):
		if not Poly.contains_point(plan.outline_of(room), point, 0.001):
			return false
	return true


static func _overlap(a: Rect2, b: Rect2) -> bool:
	var overlap := a.intersection(b)
	return overlap.size.x > 0.02 and overlap.size.y > 0.02
