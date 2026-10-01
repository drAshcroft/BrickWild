class_name DravidaGenerator
extends RefCounted
## WLD-014: a South Indian prakara compound with a processional axis.

const FAMILY := &"dravida"
const KIND := &"god_kings_precinct"
const WALL_T := 1.4
const TIER_COUNT := 6
const TIER_TAPER := 0.82
const LATE_PERIOD := 1200


static func generate(kind: StringName, seed: int, width: float, length: float,
		height: float, period: int = 900) -> Dictionary:
	var spec := HouseSpec.new(seed)
	spec.style = &"townhouse"
	spec.material = &"stone"
	spec.width = clampf(width, 100.0, 380.0)
	spec.length = clampf(length, 70.0, 240.0)
	spec.height = 8.0
	spec.storeys = 1
	spec.trade = &"none"
	spec.wall_thickness_override = WALL_T
	spec.roof_type = &"flat"
	spec.roof_pitch = 0.0
	spec.porch = false
	spec.chimney = false
	spec.timber_frame = false
	spec.stone_ground_floor = true
	spec.variant_name = "God-King's Precinct"
	spec.period = period
	var total_height := clampf(height, 45.0, 120.0)
	var plan := HousePlan.new()
	plan.spec = spec
	plan.world_family = FAMILY
	plan.world_subkind = kind
	var site := Rect2(Vector2(-spec.width * 0.5, -spec.length * 0.5),
		Vector2(spec.width, spec.length))
	var enclosure := Rect2(Vector2(-spec.width * 0.44, -spec.length * 0.44),
		Vector2(spec.width * 0.88, spec.length * 0.88))
	var colonnade_outer := enclosure.grow(-5.5)
	var colonnade_inner := colonnade_outer.grow(-4.2)
	var colonnade := _ring_rects(colonnade_inner, colonnade_outer)
	var hall_width := minf(spec.width * 0.32, 40.0)
	var hall_depth := minf(spec.length * 0.22, 28.0)
	var hall_rect := Rect2(Vector2(-hall_width * 0.5, -spec.length * 0.08),
		Vector2(hall_width, hall_depth))
	var sanctum_side := minf(14.0, spec.width * 0.10)
	var sanctum_rect := Rect2(Vector2(-sanctum_side * 0.5, hall_rect.end.y + 1.0),
		Vector2(sanctum_side, sanctum_side))
	var outer_half_z := enclosure.size.y * 0.5
	var gate_depth := 10.0
	var gates: Array[Dictionary] = [
		{"id": "gopuram_front", "center": Vector3(0.0, 0.0, -outer_half_z), "side": -1},
		{"id": "gopuram_rear", "center": Vector3(0.0, 0.0, outer_half_z), "side": 1},
	]
	var entry := Vector2(0.0, -outer_half_z - 0.5)
	var hall_door := Vector2(0.0, hall_rect.position.y)
	var sanctum_door := Vector2(0.0, sanctum_rect.position.y)
	var period_is_late := period >= LATE_PERIOD
	var vimana_height := total_height * (0.62 if period_is_late else 0.87)
	var gopuram_height := total_height * (0.94 if period_is_late else 0.55)
	var vimana_base_y := 8.5
	var tier_weights := 0.0
	for i in range(TIER_COUNT):
		tier_weights += pow(TIER_TAPER, i)
	var tiers: Array[Dictionary] = []
	var cursor_y := vimana_base_y
	for i in range(TIER_COUNT):
		var tier_h := vimana_height * pow(TIER_TAPER, i) / tier_weights
		var tier_width := sanctum_side * 1.8 * pow(TIER_TAPER, i)
		tiers.append({"index": i, "height": tier_h, "width": tier_width,
			"base_y": cursor_y})
		cursor_y += tier_h
	var first_mandapa := hall_rect.position.y
	var dhvaja := Vector3(0.0, 0.0, (entry.y + first_mandapa) * 0.5)
	var nandi_z := maxf(hall_rect.position.y - minf(spec.length * 0.17, 18.0), dhvaja.z + 4.0)
	var nandi := Vector3(0.0, 0.0, nandi_z)
	plan.rooms.append({"kind": &"hall", "role": "maha_mandapa", "rect": hall_rect,
		"storey": 0, "wall_thickness": WALL_T})
	plan.rooms.append({"kind": &"hall", "role": "garbhagriha", "rect": sanctum_rect,
		"storey": 0, "wall_thickness": WALL_T})
	plan.doors.append({"a": 0, "b": -1, "pos": hall_door, "normal": Vector2(0, -1),
		"width": 5.0, "exterior": true, "front": true, "storey": 0, "role": "mandapa_entry"})
	plan.doors.append({"a": 1, "b": 0, "pos": sanctum_door, "normal": Vector2(0, 1),
		"width": minf(4.0, sanctum_side * 0.5), "exterior": false,
		"front": false, "storey": 0, "role": "sanctum_door"})
	plan.world_meta = {"site": site, "enclosure": enclosure,
		"colonnade_outer": colonnade_outer, "colonnade_inner": colonnade_inner,
		"colonnade": colonnade, "hall": hall_rect, "sanctum": sanctum_rect,
		"entry": entry, "hall_door": hall_door, "sanctum_door": sanctum_door,
		"gates": gates, "gate_depth": gate_depth, "period": period,
		"late_period": period_is_late, "total_height": total_height,
		"vimana_height": vimana_height, "vimana_base_y": vimana_base_y,
		"vimana_center": Vector3(0.0, vimana_base_y, sanctum_rect.get_center().y),
		"vimana_tiers": tiers, "gopuram_height": gopuram_height,
		"nandi": nandi, "nandi_facing": Vector3.BACK,
		"dhvaja": dhvaja, "first_mandapa_z": first_mandapa}
	return {"spec": spec, "plan": plan}


static func _ring_rects(inner: Rect2, outer: Rect2) -> Array[Rect2]:
	return [
		Rect2(Vector2(outer.position.x, outer.position.y),
			Vector2(outer.size.x, inner.position.y - outer.position.y)),
		Rect2(Vector2(inner.end.x, outer.position.y),
			Vector2(outer.end.x - inner.end.x, outer.size.y)),
		Rect2(Vector2(outer.position.x, inner.end.y),
			Vector2(outer.size.x, outer.end.y - inner.end.y)),
		Rect2(Vector2(outer.position.x, outer.position.y),
			Vector2(inner.position.x - outer.position.x, outer.size.y)),
	]
