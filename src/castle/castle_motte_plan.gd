class_name CastleMottePlan
extends RefCounted
## Pure plan for the occupied oval shell keep on a motte.
##
## The plan is local to the mound-top origin.  Its room outlines are the
## ellipse inside CastleGeometry.shell_keep_aabb(), never that AABB itself.
## The centre is occupied floor (not a court); CastleBuilder owns the shell
## mesh and later integration can transform this plan by `origin(spec)`.

const SIDES := 14
const WALL_INSET := 0.6
const WINDOW_SILL := 1.15
const WINDOW_HEAD := 2.15
const WINDOW_PITCH := 4.8
const KeepPlan = preload("castle_keep_plan.gd")


static func origin(spec: CastleSpec) -> Vector3:
	var keep := CastleGeometry.shell_keep_aabb(spec)
	return Vector3(keep.get_center().x, spec.motte_height, keep.get_center().z)


static func levels(spec: CastleSpec) -> int:
	return clampi(int(floor(spec.keep_height / CastleInteriorPlans.KEEP_STOREY_H)), 3, 8)


static func inner_radii(spec: CastleSpec) -> Vector2:
	var keep := CastleGeometry.shell_keep_aabb(spec)
	var inset := maxf(spec.shell_thickness, WALL_INSET)
	return Vector2(maxf(0.5, keep.size.x * 0.5 - inset),
		maxf(0.5, keep.size.z * 0.5 - inset))


static func floor_outline(spec: CastleSpec) -> PackedVector2Array:
	var radii := inner_radii(spec)
	var out := PackedVector2Array()
	for i in range(SIDES):
		var a := TAU * float(i) / float(SIDES)
		out.append(Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return out


static func generate(spec: CastleSpec, with_furniture := false) -> HousePlan:
	var plan := HousePlan.new()
	if not CastleGeometry.is_motte(spec):
		return plan
	var keep := CastleGeometry.shell_keep_aabb(spec)
	if keep.size.x <= 0.0 or keep.size.z <= 0.0 or keep.size.y <= 0.0:
		return plan
	var n := levels(spec)
	var hs := CastleInteriorPlans._keep_spec(spec, keep, n)
	hs.wall_thickness_override = spec.shell_thickness
	hs.porch = false
	hs.chimney = false
	hs.exterior_props = false
	plan.spec = hs
	plan.exterior.append({"id": "keep_shell", "key": "keep_shell",
		"kind": "shell_keep", "host": "keep_shell", "intent": "occupied_shell_keep",
		"origin": origin(spec), "bounds": keep, "inner_radii": inner_radii(spec)})
	var outline := floor_outline(spec)
	var rect := Poly.bounding_rect(outline)
	for level in range(n):
		var kind: StringName = &"lords_chamber" if level == n - 1 else &"hall"
		plan.rooms.append({"kind": kind, "storey": level, "rect": rect,
			"outline": outline.duplicate(), "floor_y": float(level) * hs.height,
			"ceiling_y": float(level + 1) * hs.height})
	var top_walls := HouseGeometry.room_walls(plan, n - 1)
	plan.hearth = {"room": n - 1, "wall": KeepPlan._facing_wall(top_walls, Vector2(1, 0))}
	var door_width := minf(1.6, inner_radii(spec).x * 0.30)
	# Small ovals have a short central facet: shifting within it may leave the
	# doorway behind the solid climb curtain. Choose a real adjacent facet when
	# necessary, keeping the complete opening and stair lane beside the curtain.
	var climb := CastleGeometry.climb_wall(spec)
	var stair_width := clampf(maxf(float(climb["thickness"]) * 3.0, 2.0), 2.0, 3.6)
	var lane_offset := float(climb["thickness"]) * 0.5 + stair_width * 0.5 + 0.25
	var arrival := _climb_door(plan, door_width, lane_offset, float(climb.thickness) * 0.5)
	if arrival.is_empty():
		return HousePlan.new() # An impossible forced site is reported by castle interior QA.
	var front: Dictionary = arrival.wall
	var door_pos: Vector2 = arrival.pos
	var door_normal := -Vector2(front["normal"])
	plan.doors.append({"a": 0, "b": -1, "pos": door_pos,
		"normal": door_normal, "width": door_width,
		"exterior": true, "front": true, "storey": 0, "host": "keep_shell",
		"surface_point": door_pos, "surface_normal": door_normal,
		"route": "motte_climb"})
	for level in range(n):
		_add_windows(plan, level, outline)
	for level in range(n - 1):
		_add_stair(plan, level, level + 1, outline)
	if with_furniture:
		HouseFurnisher.furnish(plan, hs)
	return plan


static func _add_windows(plan: HousePlan, level: int, outline: PackedVector2Array) -> void:
	var walls := HouseGeometry.room_walls(plan, level)
	for i in range(SIDES):
		if i % 2 != level % 2:
			continue
		if level == plan.hearth_room() and i == plan.hearth_wall():
			continue # This solid wall carries the lord's fireplace and flue.
		var a0 := outline[i]
		var a1 := outline[(i + 1) % SIDES]
		var edge := a1 - a0
		var pos := (a0 + a1) * 0.5
		# The radial vector is only the true normal at a few cardinal facets.
		# Use the exact outward normal of the polygon edge so HouseBuilder's
		# opening matcher cuts this same shell run.
		var normal := -Vector2(walls[i]["normal"])
		var width := minf(1.2, edge.length() * 0.45)
		var over_door := false
		for door in plan.doors:
			if HousePlan.record_storey(door) == level and Vector2(door.normal).dot(normal) > 0.99 \
					and Vector2(door.pos).distance_to(pos) < (float(door.width) + width) * 0.5 + 0.08:
				over_door = true
		if over_door:
			continue
		plan.windows.append({"room": level, "pos": pos, "normal": normal,
			"width": width, "sill": WINDOW_SILL,
			"head": WINDOW_HEAD, "storey": level, "host": "keep_shell",
			"surface_point": pos, "surface_normal": normal, "edge": i})


static func _add_stair(plan: HousePlan, lower: int, upper: int,
		_outline: PackedVector2Array) -> void:
	var previous := Rect2()
	if not plan.stairs.is_empty():
		previous = plan.stairs[-1].upper_rect
	var before := plan.stairs.size()
	KeepPlan._add_stair(plan, lower, upper, previous)
	if plan.stairs.size() > before:
		plan.stairs[-1]["opening"] = plan.stairs[-1].rect
		plan.stairs[-1]["host"] = "keep_shell"


## Local masonry flue on the exact hearth facet. The castle emits it because
## its shell/parapet, rather than the generic house roof, owns the top height.
static func flue(plan: HousePlan, clearance := 1.5) -> Dictionary:
	var room := plan.hearth_room()
	if room < 0:
		return {}
	var wall: Dictionary = HouseGeometry.room_walls(plan, room)[plan.hearth_wall()]
	var at := (Vector2(wall.from) + Vector2(wall.to)) * 0.5
	for item in plan.furniture:
		if int(item.room) == room and PropCatalog.category(item.key) == "hearth":
			at = Geometry2D.get_closest_point_to_segment(Vector2(item.pos.x, item.pos.z), wall.from, wall.to)
			break
	var normal := -Vector2(wall.normal)
	var thick := HouseGeometry.wall_thickness(plan.spec)
	var centre := at + normal * (thick * 0.55)
	var bottom := float(plan.storey_of_room(room)) * plan.spec.height
	var top := float(plan.spec.storeys) * plan.spec.height + clearance
	var size := Vector3(0.9, top - bottom, thick + 0.25)
	var xf := Transform3D(Basis(Vector3.UP, atan2(normal.x, normal.y)),
		Vector3(centre.x, (bottom + top) * 0.5, centre.y))
	return {"size": size, "transform": xf, "storey": plan.storey_of_room(room),
		"wall": plan.hearth_wall(), "surface_point": at}


static func validate(plan: HousePlan) -> Dictionary:
	var failures: Array[String] = []
	if plan.spec == null:
		failures.append("missing keep spec")
	if plan.rooms.is_empty():
		failures.append("missing occupied shell-keep rooms")
	if plan.exterior.is_empty() or String(plan.exterior[0].get("id", "")) != "keep_shell":
		failures.append("missing stable keep_shell intent")
	for room in plan.rooms:
		var outline: PackedVector2Array = room.get("outline", PackedVector2Array())
		if outline.size() != SIDES:
			failures.append("room outline is not the 14-sided shell ellipse")
			continue
		var radii: Vector2 = plan.exterior[0].get("inner_radii", Vector2.ONE)
		for p in outline:
			var ellipse := (p.x / radii.x) * (p.x / radii.x) + (p.y / radii.y) * (p.y / radii.y)
			if absf(ellipse - 1.0) > 0.18:
				failures.append("room outline is not on the ellipse surface")
				break
	for door in plan.doors:
		if not _on_surface(Vector2(door.pos), Vector2(door.normal), plan, 0):
			failures.append("door is off the shell polygon facet")
	for window in plan.windows:
		if not _on_ellipse(Vector2(window.pos), plan):
			failures.append("window is off the shell surface")
	for stair in plan.stairs:
		for room_index in [int(stair.a), int(stair.b)]:
			if room_index < 0 or room_index >= plan.rooms.size() \
					or not _rect_inside(stair.get("lower_rect", stair.rect) if room_index == stair.a \
					else stair.get("upper_rect", stair.rect), plan.outline_of(room_index)):
				failures.append("stair landing is outside an adjacent floor outline")
	for i in range(plan.stairs.size() - 1):
		var upper_rect := Rect2(plan.stairs[i].get("upper_rect", plan.stairs[i].rect))
		var next_lower := Rect2(plan.stairs[i + 1].get("lower_rect", plan.stairs[i + 1].rect))
		if upper_rect.intersects(next_lower, true):
			failures.append("adjacent stair flights overlap at storey %d" % (i + 1))
	return {"ok": failures.is_empty(), "failures": failures}


static func _on_ellipse(pos: Vector2, plan: HousePlan) -> bool:
	var radii: Vector2 = plan.exterior[0].get("inner_radii", Vector2.ONE)
	var value := (pos.x / radii.x) * (pos.x / radii.x) + (pos.y / radii.y) * (pos.y / radii.y)
	return absf(value - 1.0) <= 0.18


static func _climb_door(plan: HousePlan, width: float, lane_x: float,
		curtain_half: float) -> Dictionary:
	var walls := HouseGeometry.room_walls(plan, 0)
	var best := {}
	var score := INF
	for wall in walls:
		var outward := -Vector2(wall["normal"])
		if outward.y > -0.45:
			continue
		var a: Vector2 = wall.from
		var edge: Vector2 = Vector2(wall.to) - a
		var tangent := edge.normalized()
		var margin := width * 0.5 + 0.18
		if edge.length() < 2.0 * margin:
			continue
		var along := clampf((lane_x - a.x) / tangent.x, margin, edge.length() - margin)
		var pos := a + tangent * along
		if pos.x - absf(tangent.x) * width * 0.5 < curtain_half + 0.12:
			continue
		var candidate := absf(pos.x - lane_x) + 2.0 * (1.0 + outward.y)
		if candidate < score:
			score = candidate
			best = {"wall": wall, "pos": pos}
	return best


static func _on_surface(pos: Vector2, outward: Vector2, plan: HousePlan,
		level: int) -> bool:
	for wall in HouseGeometry.room_walls(plan, level):
		var a := Vector2(wall["from"])
		var b := Vector2(wall["to"])
		var edge := b - a
		var nearest := a + edge * clampf((pos - a).dot(edge) /
			maxf(edge.length_squared(), 0.0001), 0.0, 1.0)
		if nearest.distance_to(pos) <= 0.001 \
				and (-Vector2(wall["normal"])).dot(outward.normalized()) > 0.999:
			return true
	return false


static func _rect_inside(rect: Rect2, outline: PackedVector2Array) -> bool:
	for point in Poly.from_rect(rect):
		if not Poly.contains_point(outline, point, 0.001):
			return false
	return true
