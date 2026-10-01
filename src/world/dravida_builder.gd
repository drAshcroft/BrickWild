class_name DravidaBuilder
extends MassBuilder
## Emits the compound from the retained PrakaraPlan records.

const STONE := 0
const TRIM := 1
const ROOF := 2
const WALL_T := DravidaGenerator.WALL_T


func build(plan: HousePlan) -> ArrayMesh:
	begin_metric(3)
	var meta: Dictionary = plan.world_meta
	_emit_enclosure(meta)
	_emit_colonnade(meta)
	_emit_halls(meta)
	_emit_gopurams(meta)
	_emit_nandi(meta)
	_emit_dhvaja(meta)
	_emit_vimana(meta)
	total_height = float(meta["total_height"])
	return commit()


func _emit_enclosure(meta: Dictionary) -> void:
	var enclosure: Rect2 = meta["enclosure"]
	var wall_h := 7.0
	var gate_width := 18.0
	var half_gate := gate_width * 0.5
	var front_z := enclosure.position.y
	var rear_z := enclosure.end.y - WALL_T
	for end in ["front", "rear"]:
		var z := front_z if end == "front" else rear_z
		var left_w := enclosure.get_center().x - half_gate - enclosure.position.x
		var right_start := enclosure.get_center().x + half_gate
		var right_w := enclosure.end.x - right_start
		_box_mass("prakara_%s_left" % end, Vector3(left_w, wall_h, WALL_T),
			Vector3(enclosure.position.x + left_w * 0.5, wall_h * 0.5, z + WALL_T * 0.5), STONE)
		_box_mass("prakara_%s_right" % end, Vector3(right_w, wall_h, WALL_T),
			Vector3(right_start + right_w * 0.5, wall_h * 0.5, z + WALL_T * 0.5), STONE)
	for side in ["left", "right"]:
		var x := enclosure.position.x if side == "left" else enclosure.end.x - WALL_T
		_box_mass("prakara_%s" % side, Vector3(WALL_T, wall_h, enclosure.size.y),
			Vector3(x + WALL_T * 0.5, wall_h * 0.5, enclosure.get_center().y), STONE)


func _emit_colonnade(meta: Dictionary) -> void:
	var ring: Array = meta["colonnade"]
	for i in range(ring.size()):
		var rect: Rect2 = ring[i]
		var floor_size := Vector3(rect.size.x, 0.28, rect.size.y)
		var floor_pos := Vector3(rect.get_center().x, 0.14, rect.get_center().y)
		box(floor_size, floor_pos, TRIM)
		_log_mass("colonnade_floor_%d" % i, AABB(floor_pos - floor_size * 0.5, floor_size))
	var outer: Rect2 = meta["colonnade_outer"]
	var inner: Rect2 = meta["colonnade_inner"]
	var supports: Array[Vector2] = []
	for i in range(5):
		var z := lerpf(outer.position.y + 2.0, outer.end.y - 2.0, float(i) / 4.0)
		supports.append(Vector2(outer.position.x + 1.0, z))
		supports.append(Vector2(outer.end.x - 1.0, z))
	for i in range(1, 4):
		var x := lerpf(inner.position.x + 2.0, inner.end.x - 2.0, float(i) / 4.0)
		supports.append(Vector2(x, outer.position.y + 1.0))
		supports.append(Vector2(x, outer.end.y - 1.0))
	for i in range(supports.size()):
		var p: Vector2 = supports[i]
		var size := Vector3(0.52, 5.0, 0.52)
		var pos := Vector3(p.x, 2.5, p.y)
		_box_mass("colonnade_column_%d" % i, size, pos, STONE)


func _emit_halls(meta: Dictionary) -> void:
	var hall: Rect2 = meta["hall"]
	var sanctum: Rect2 = meta["sanctum"]
	var hall_h := 11.0
	var floor := Vector3(hall.size.x, 0.3, hall.size.y)
	var floor_pos := Vector3(hall.get_center().x, 0.15, hall.get_center().y)
	box(floor, floor_pos, STONE)
	_log_mass("mandapa_floor", AABB(floor_pos - floor * 0.5, floor))
	for side in [-1.0, 1.0]:
		var size := Vector3(WALL_T, hall_h, hall.size.y)
		var p := Vector3(hall.get_center().x + side * (hall.size.x * 0.5 - WALL_T * 0.5),
			hall_h * 0.5, hall.get_center().y)
		_box_mass("mandapa_side_%s" % ("left" if side < 0 else "right"), size, p, STONE)
	_box_mass("mandapa_roof", Vector3(hall.size.x, 0.5, hall.size.y),
		Vector3(hall.get_center().x, hall_h, hall.get_center().y), ROOF)
	var s_h := 8.5
	var wall_t := 0.7
	var front_z := sanctum.position.y
	var door_w := minf(4.0, sanctum.size.x * 0.5)
	var side_w := (sanctum.size.x - door_w) * 0.5
	for side in [-1.0, 1.0]:
		var p_x := sanctum.get_center().x + side * (door_w * 0.5 + side_w * 0.5)
		_box_mass("sanctum_door_jamb_%s" % ("left" if side < 0 else "right"),
			Vector3(side_w, s_h, wall_t), Vector3(p_x, s_h * 0.5, front_z + wall_t * 0.5), STONE)
	_box_mass("sanctum_door_lintel", Vector3(door_w, s_h - 4.0, wall_t),
		Vector3(0.0, 4.0 + (s_h - 4.0) * 0.5, front_z + wall_t * 0.5), STONE)
	for side in [-1.0, 1.0]:
		var p_x := sanctum.get_center().x + side * (sanctum.size.x * 0.5 - wall_t * 0.5)
		_box_mass("sanctum_side_%s" % ("left" if side < 0 else "right"),
			Vector3(wall_t, s_h, sanctum.size.y),
			Vector3(p_x, s_h * 0.5, sanctum.get_center().y), STONE)
	_box_mass("sanctum_rear", Vector3(sanctum.size.x, s_h, wall_t),
		Vector3(sanctum.get_center().x, s_h * 0.5, sanctum.end.y - wall_t * 0.5), STONE)
	_box_mass("sanctum_roof", Vector3(sanctum.size.x, 0.38, sanctum.size.y),
		Vector3(sanctum.get_center().x, s_h, sanctum.get_center().y), TRIM)


func _emit_gopurams(meta: Dictionary) -> void:
	var height := float(meta["gopuram_height"])
	for gate in meta["gates"]:
		var id := String(gate["id"])
		var center: Vector3 = gate["center"]
		var z := center.z - float(meta["gate_depth"]) * 0.5
		if int(gate["side"]) > 0:
			z = center.z - float(meta["gate_depth"]) * 0.5
		var pier_h := 5.0
		for side in [-1.0, 1.0]:
			var p := Vector3(side * 7.4, pier_h * 0.5, z + float(meta["gate_depth"]) * 0.5)
			_box_mass("%s_pier_%s" % [id, "left" if side < 0 else "right"],
				Vector3(3.2, pier_h, float(meta["gate_depth"])), p, STONE)
		_box_mass("%s_tower" % id, Vector3(16.0, height - pier_h, 10.0),
			Vector3(0.0, pier_h + (height - pier_h) * 0.5, center.z), ROOF)
		var tier_h := maxf(0.8, (height - pier_h) / 5.0)
		for tier in range(4):
			var width := 15.5 - float(tier) * 1.6
			_box_mass("%s_tier_%d" % [id, tier], Vector3(width, tier_h * 0.30, 10.5 - tier),
				Vector3(0.0, height - float(tier) * tier_h * 0.72, center.z), TRIM)


func _emit_nandi(meta: Dictionary) -> void:
	var center: Vector3 = meta["nandi"]
	var body := Vector3(4.5, 2.2, 5.6)
	var body_pos := Vector3(center.x, 1.1, center.z)
	_box_mass("nandi", body, body_pos, STONE)
	var head := Vector3(1.5, 1.8, 1.4)
	var head_pos := Vector3(center.x, 2.0, center.z + body.z * 0.5 - head.z * 0.5)
	_box_mass("nandi_head_facing_plus_axis", head, head_pos, TRIM)


func _emit_dhvaja(meta: Dictionary) -> void:
	var p: Vector3 = meta["dhvaja"]
	var shaft := Vector3(0.55, 8.0, 0.55)
	var pos := Vector3(p.x, shaft.y * 0.5, p.z)
	_box_mass("dhvaja", shaft, pos, TRIM)
	_box_mass("dhvaja_finial", Vector3(1.3, 1.0, 1.3),
		Vector3(p.x, shaft.y + 0.5, p.z), ROOF)


func _emit_vimana(meta: Dictionary) -> void:
	var center: Vector3 = meta["vimana_center"]
	var tiers: Array = meta["vimana_tiers"]
	for row in tiers:
		var index := int(row["index"])
		var width := float(row["width"])
		var height := float(row["height"])
		var size := Vector3(width, height, width)
		var pos := Vector3(center.x, float(row["base_y"]) + height * 0.5, center.z)
		_box_mass("vimana_tier_%d" % index, size, pos, ROOF if index % 2 == 0 else TRIM)
		var cap := Vector3(width * 1.04, 0.35, width * 1.04)
		_box_mass("vimana_tier_cap_%d" % index, cap,
			Vector3(center.x, float(row["base_y"]) + height, center.z), TRIM)


func _box_mass(name: String, size: Vector3, pos: Vector3, surface: int) -> void:
	box(size, pos, surface)
	_log_mass(name, AABB(pos - size * 0.5, size))
