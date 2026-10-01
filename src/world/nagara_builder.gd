class_name NagaraBuilder
extends MassBuilder
## Emits the axial halls, raised plinth, pradakshina and clustered curved spire.

const STONE := 0
const TRIM := 1
const ROOF := 2
const DARK := 3

func build(plan: HousePlan) -> ArrayMesh:
	begin_metric(4)
	var meta: Dictionary = plan.world_meta
	var plinth: Rect2 = meta["plinth_rect"]
	var plinth_h := float(meta["plinth_height"])
	_box_mass("plinth", Vector3(plinth.size.x, plinth_h, plinth.size.y),
		Vector3(plinth.get_center().x, plinth_h * 0.5, plinth.get_center().y), STONE)
	_emit_stair(plan, plinth_h)
	var halls: Array = meta["hall_rects"]
	var heights: Array = meta["hall_heights"]
	for i in range(halls.size()):
		var rect: Rect2 = halls[i]
		var top := plinth_h + float(heights[i])
		_emit_side_wall(rect, rect.position.x, WALL_T, plinth_h, top, "hall_%d_left" % i)
		_emit_side_wall(rect, rect.end.x - WALL_T, WALL_T, plinth_h, top, "hall_%d_right" % i)
		_box_mass("hall_roof_%d" % i,
			Vector3(rect.size.x, 0.32, rect.size.y),
			Vector3(rect.get_center().x, top, rect.get_center().y), ROOF)
		_log_mass("hall_%d" % i, AABB(Vector3(rect.position.x, plinth_h, rect.position.y),
			Vector3(rect.size.x, float(heights[i]), rect.size.y)))
	_emit_end_walls(plan, halls, heights, plinth_h)
	_emit_sanctum(plan, plinth_h, float(heights[3]))
	_emit_pradakshina(plan, plinth_h)
	_emit_image(plan, plinth_h)
	_emit_shikhara(plan)
	_emit_urushringas(plan)
	total_height = float(meta["total_height"])
	return commit()


func _emit_side_wall(rect: Rect2, x: float, thickness: float, base: float,
		top: float, name: String) -> void:
	var h := top - base
	_box_mass(name, Vector3(thickness, h, rect.size.y),
		Vector3(x + thickness * 0.5, base + h * 0.5, rect.get_center().y), STONE)


func _emit_end_walls(plan: HousePlan, halls: Array, heights: Array,
		plinth_h: float) -> void:
	var first: Rect2 = halls[0]
	var first_h := plinth_h + float(heights[0])
	var entry_door: Dictionary = plan.doors[0]
	_wall_with_door(first, first.position.y, plinth_h, first_h, entry_door, "entry_wall")
	for i in range(halls.size() - 1):
		var rect: Rect2 = halls[i]
		var door: Dictionary = plan.doors[i + 1]
		var wall_h := plinth_h + minf(float(heights[i]), float(heights[i + 1]))
		_wall_with_door(rect, rect.end.y - WALL_T, plinth_h, wall_h, door, "partition_%d" % i)
	var last: Rect2 = halls[-1]
	_box_mass("rear_wall", Vector3(last.size.x, float(heights[-1]), WALL_T),
		Vector3(last.get_center().x, plinth_h + float(heights[-1]) * 0.5,
			last.end.y - WALL_T * 0.5), STONE)


func _wall_with_door(rect: Rect2, z: float, base: float, top: float, door: Dictionary,
		label: String) -> void:
	var center := float((door["pos"] as Vector2).x)
	var width := float(door["width"])
	var left := center - width * 0.5 - rect.position.x
	var right := rect.end.x - center - width * 0.5
	var door_h := minf(3.1, (top - base) * 0.72)
	if left > 0.02:
		_box_mass("%s_left" % label, Vector3(left, top - base, WALL_T),
			Vector3(rect.position.x + left * 0.5, base + (top - base) * 0.5, z + WALL_T * 0.5), STONE)
	if right > 0.02:
		_box_mass("%s_right" % label, Vector3(right, top - base, WALL_T),
			Vector3(center + width * 0.5 + right * 0.5, base + (top - base) * 0.5, z + WALL_T * 0.5), STONE)
	if top - base > door_h:
		_box_mass("%s_lintel" % label, Vector3(width, top - base - door_h, WALL_T),
			Vector3(center, base + door_h + (top - base - door_h) * 0.5, z + WALL_T * 0.5), STONE)


func _emit_sanctum(plan: HousePlan, plinth_h: float, hall_height: float) -> void:
	var sanctum: Rect2 = plan.world_meta["sanctum_rect"]
	var top := plinth_h + hall_height * 0.82
	var door: Dictionary = plan.doors[-1]
	# The sanctum is a small, enclosed, windowless square, with exactly one axial door.
	var wall_h := top - plinth_h
	_box_mass("sanctum_left", Vector3(WALL_T, wall_h, sanctum.size.y),
		Vector3(sanctum.position.x + WALL_T * 0.5, plinth_h + wall_h * 0.5, sanctum.get_center().y), STONE)
	_box_mass("sanctum_right", Vector3(WALL_T, wall_h, sanctum.size.y),
		Vector3(sanctum.end.x - WALL_T * 0.5, plinth_h + wall_h * 0.5, sanctum.get_center().y), STONE)
	_box_mass("sanctum_rear", Vector3(sanctum.size.x, wall_h, WALL_T),
		Vector3(sanctum.get_center().x, plinth_h + wall_h * 0.5, sanctum.end.y - WALL_T * 0.5), STONE)
	_wall_with_door(sanctum, sanctum.position.y - WALL_T, plinth_h, top, door, "sanctum_front")
	_box_mass("sanctum_roof", Vector3(sanctum.size.x, 0.28, sanctum.size.y),
		Vector3(sanctum.get_center().x, top, sanctum.get_center().y), DARK)
	_log_mass("garbhagriha", AABB(Vector3(sanctum.position.x, plinth_h, sanctum.position.y),
		Vector3(sanctum.size.x, top - plinth_h, sanctum.size.y)))


func _emit_pradakshina(plan: HousePlan, plinth_h: float) -> void:
	for i in range(plan.world_meta["pradakshina"].size()):
		var rect: Rect2 = plan.world_meta["pradakshina"][i]
		_box_mass("pradakshina_%d" % i, Vector3(rect.size.x, 0.18, rect.size.y),
			Vector3(rect.get_center().x, plinth_h + 0.09, rect.get_center().y), TRIM)


func _emit_image(plan: HousePlan, plinth_h: float) -> void:
	var p: Vector3 = plan.world_meta["image"]
	_box_mass("image", Vector3(1.0, 2.6, 0.8),
		Vector3(p.x, plinth_h + 1.3, p.z), DARK)


func _emit_shikhara(plan: HousePlan) -> void:
	var meta: Dictionary = plan.world_meta
	var base: Vector3 = meta["shikhara_center"]
	var h := float(meta["shikhara_height"])
	var radius := float(meta["spire_base_radius"])
	var profile := PackedVector2Array([
		Vector2(radius * 0.90, 0.0), Vector2(radius, h * 0.18),
		Vector2(radius * 0.94, h * 0.38), Vector2(radius * 0.79, h * 0.60),
		Vector2(radius * 0.59, h * 0.79), Vector2(radius * 0.34, h * 0.93),
		Vector2(0.06, h)])
	_kit.revolve(profile, base, ROOF, 16, TAU, PI / 16.0)
	var aabb := AABB(Vector3(-radius, base.y, base.z - radius),
		Vector3(radius * 2.0, h, radius * 2.0))
	component_note("shikhara", "curved_spire", ROOF,
		{"profile": profile, "center": base, "sides": 16, "aabb": aabb})
	_log_mass("shikhara", aabb)


func _emit_urushringas(plan: HousePlan) -> void:
	var meta: Dictionary = plan.world_meta
	var base: Vector3 = meta["shikhara_center"]
	var main_h := float(meta["shikhara_height"])
	var main_r := float(meta["spire_base_radius"])
	var mini_h := main_h * 0.58
	var mini_r := main_r * 0.23
	var spread := main_r * 0.72
	var points := [Vector2(spread, 0.0), Vector2(-spread, 0.0),
		Vector2(0.0, spread), Vector2(0.0, -spread),
		Vector2(spread * 0.70, spread * 0.70), Vector2(-spread * 0.70, spread * 0.70),
		Vector2(spread * 0.70, -spread * 0.70), Vector2(-spread * 0.70, -spread * 0.70)]
	for i in range(points.size()):
		var p: Vector2 = points[i]
		var center := Vector3(p.x, base.y, base.z + p.y)
		var profile := PackedVector2Array([Vector2(mini_r, 0.0),
			Vector2(mini_r * 0.88, mini_h * 0.42),
			Vector2(mini_r * 0.54, mini_h * 0.78), Vector2(0.04, mini_h)])
		_kit.revolve(profile, center, ROOF, 8, TAU, PI / 8.0)
		var aabb := AABB(Vector3(center.x - mini_r, center.y, center.z - mini_r),
			Vector3(mini_r * 2.0, mini_h, mini_r * 2.0))
		component_note("urushringa", "curved_spire", ROOF,
			{"profile": profile, "center": center, "sides": 8, "aabb": aabb})
		_log_mass("urushringa_%d" % i, aabb)


func _emit_stair(plan: HousePlan, plinth_h: float) -> void:
	var plinth: Rect2 = plan.world_meta["plinth_rect"]
	var stair: Dictionary = plan.stairs[0]
	var width := float(stair["width"])
	var run := 3.2
	var count := 6
	for i in range(count):
		var depth := run / float(count)
		var h := plinth_h * float(i + 1) / float(count)
		var z := plinth.position.y - run + depth * (float(i) + 0.5)
		_box_mass("plinth_stair_%d" % i, Vector3(width, h, depth),
			Vector3(0.0, h * 0.5, z), STONE)


func _box_mass(name: String, size: Vector3, pos: Vector3, surf: int) -> void:
	box(size, pos, surf)
	_log_mass(name, AABB(pos - size * 0.5, size))
