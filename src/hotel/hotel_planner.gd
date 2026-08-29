class_name HotelPlanner
extends RefCounted
## A designed palatial plan: three bays by two ranks on every level, with the
## entrance and stair spine held on the facade axis.

const GROUND_KINDS: Array[StringName] = [
	&"dining_room", &"lobby", &"lounge", &"kitchen", &"office", &"store"]
const UPPER_KINDS: Array[StringName] = [
	&"guest_room", &"gallery", &"suite", &"guest_room", &"laundry", &"guest_room"]


static func plan(spec: HotelSpec) -> HousePlan:
	var out := HousePlan.new()
	out.spec = spec
	var inner := HouseGeometry.interior_rect(spec)
	var centre_w := HotelGeometry.centre_width(spec)
	var xs := [inner.position.x, -centre_w * 0.5, centre_w * 0.5, inner.end.x]
	var split_z := lerpf(inner.position.y, inner.end.y, 0.52)
	var zs := [inner.position.y, split_z, inner.end.y]

	for storey in range(spec.storeys):
		var kinds: Array[StringName] = GROUND_KINDS if storey == 0 else UPPER_KINDS
		var base := out.rooms.size()
		for row in range(2):
			for col in range(3):
				var rect := Rect2(Vector2(xs[col], zs[row]),
					Vector2(xs[col + 1] - xs[col], zs[row + 1] - zs[row]))
				out.rooms.append({"kind": kinds[row * 3 + col], "rect": rect,
					"storey": storey})
		_connect_level(out, base, xs, zs, storey)
		_add_windows(out, base, xs, zs, storey, spec)

	_add_exterior_doors(out, inner, spec)
	for storey in range(spec.storeys - 1):
		_add_stair(out, storey * 6 + 1, (storey + 1) * 6 + 1, storey)
	return out


static func _connect_level(plan: HousePlan, base: int, xs: Array, zs: Array,
		storey: int) -> void:
	var front_mid := (float(zs[0]) + float(zs[1])) * 0.5
	var back_mid := (float(zs[1]) + float(zs[2])) * 0.5
	_add_door(plan, base + 0, base + 1, Vector2(xs[1], front_mid), Vector2(1, 0), storey)
	_add_door(plan, base + 1, base + 2, Vector2(xs[2], front_mid), Vector2(1, 0), storey)
	_add_door(plan, base + 1, base + 4, Vector2(0.0, zs[1]), Vector2(0, 1), storey)
	_add_door(plan, base + 0, base + 3,
		Vector2((float(xs[0]) + float(xs[1])) * 0.5, zs[1]), Vector2(0, 1), storey)
	_add_door(plan, base + 2, base + 5,
		Vector2((float(xs[2]) + float(xs[3])) * 0.5, zs[1]), Vector2(0, 1), storey)


static func _add_door(plan: HousePlan, a: int, b: int, pos: Vector2,
		normal: Vector2, storey: int) -> void:
	plan.doors.append({"a": a, "b": b, "pos": pos, "normal": normal,
		"width": HouseGeometry.INNER_DOOR_W, "exterior": false, "storey": storey})


static func _add_exterior_doors(plan: HousePlan, inner: Rect2, spec: HotelSpec) -> void:
	plan.doors.append({"a": 1, "b": -1,
		"pos": Vector2(0.0, inner.position.y), "normal": Vector2(0, -1),
		"width": 1.8, "exterior": true, "front": true, "storey": 0})
	plan.doors.append({"a": 4, "b": -1,
		"pos": Vector2(0.0, inner.end.y), "normal": Vector2(0, 1),
		"width": HouseGeometry.DOOR_W, "exterior": true, "front": false, "storey": 0})
	spec.back_door = true


static func _add_windows(plan: HousePlan, base: int, xs: Array, zs: Array,
		storey: int, spec: HotelSpec) -> void:
	for col in range(3):
		_windows_horizontal(plan, base + col, float(xs[col]), float(xs[col + 1]),
			float(zs[0]), Vector2(0, -1), storey, spec, storey == 0 and col == 1)
		_windows_horizontal(plan, base + 3 + col, float(xs[col]), float(xs[col + 1]),
			float(zs[2]), Vector2(0, 1), storey, spec, storey == 0 and col == 1)
	# Side light makes the end suites read as corner rooms and supplies enough
	# glazing for the unusually deep public rooms.
	_windows_vertical(plan, base + 0, float(zs[0]), float(zs[1]), float(xs[0]),
		Vector2(-1, 0), storey, spec)
	_windows_vertical(plan, base + 3, float(zs[1]), float(zs[2]), float(xs[0]),
		Vector2(-1, 0), storey, spec)
	_windows_vertical(plan, base + 2, float(zs[0]), float(zs[1]), float(xs[3]),
		Vector2(1, 0), storey, spec)
	_windows_vertical(plan, base + 5, float(zs[1]), float(zs[2]), float(xs[3]),
		Vector2(1, 0), storey, spec)


static func _windows_horizontal(plan: HousePlan, room: int, x0: float, x1: float,
		z: float, normal: Vector2, storey: int, spec: HotelSpec,
		keep_centre_clear: bool) -> void:
	var count := clampi(int((x1 - x0 + HouseGeometry.WINDOW_MIN_GAP) /
		(1.05 + HouseGeometry.WINDOW_MIN_GAP)), 1, 12)
	for i in range(count):
		var x := lerpf(x0, x1, (float(i) + 0.5) / count)
		if keep_centre_clear and absf(x) < 1.58:
			continue
		_add_window(plan, room, Vector2(x, z), normal, storey, spec)


static func _windows_vertical(plan: HousePlan, room: int, z0: float, z1: float,
		x: float, normal: Vector2, storey: int, spec: HotelSpec) -> void:
	var count := clampi(int((z1 - z0 + HouseGeometry.WINDOW_MIN_GAP) /
		(1.05 + HouseGeometry.WINDOW_MIN_GAP)), 1, 8)
	for i in range(count):
		var z := lerpf(z0, z1, (float(i) + 0.5) / count)
		_add_window(plan, room, Vector2(x, z), normal, storey, spec)


static func _add_window(plan: HousePlan, room: int, pos: Vector2, normal: Vector2,
		storey: int, spec: HotelSpec) -> void:
	plan.windows.append({"room": room, "pos": pos, "normal": normal,
		"width": 1.05, "sill": 0.9, "head": minf(2.55, spec.height - 0.3),
		"storey": storey})


static func _add_stair(plan: HousePlan, lower: int, upper: int, storey: int) -> void:
	var floor := HouseGeometry.room_floor_rect(plan, lower)
	var size := Vector2(1.35, minf(3.1, floor.size.y * 0.42))
	var centre := Vector2(floor.get_center().x, floor.end.y - size.y * 0.65)
	var rect := Rect2(centre - size * 0.5, size)
	plan.stairs.append({
		"a": lower, "b": upper, "storey": storey, "to_storey": storey + 1,
		"pos": centre, "lower_pos": centre, "upper_pos": centre,
		"rect": rect, "lower_rect": rect, "upper_rect": rect,
		"width": size.x, "run": size.y,
	})
