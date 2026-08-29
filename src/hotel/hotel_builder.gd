class_name HotelBuilder
extends HouseBuilder
## The walkable house shell with a palatial, bilaterally symmetric facade and
## a steep mansard-like roofline layered on before the mesh is committed.

const WINDOW_W := 0.92
const WINDOW_H := 1.5
const FRAME := 0.13
const FACADE_D := 0.12


func build(p_plan: HousePlan, with_roof := true) -> ArrayMesh:
	plan = p_plan
	spec = p_plan.spec
	begin(4)
	total_height = HotelGeometry.wall_top(spec as HotelSpec)
	_build_floor()
	_build_exterior_walls()
	_build_partitions()
	_build_facade()
	if with_roof:
		_build_palace_roof()
	return commit()


func _build_facade() -> void:
	var hs := spec as HotelSpec
	var z := HotelGeometry.front_z(hs)
	var top := HotelGeometry.wall_top(hs)
	var centre_w := HotelGeometry.centre_width(hs)

	# Horizontal cornices make the elevation read as stacked public, piano
	# nobile, and guest-room zones rather than one tall pink slab.
	for level in range(hs.storeys + 1):
		var y := 0.25 if level == 0 else float(level) * hs.height - 0.12
		tag("cornice")
		box(Vector3(hs.width + 0.8, 0.22, 0.34), Vector3(0, y, z), SURF_TRIM)
	# Quoins and central pilasters carry the strict symmetry of the reference.
	for x in [-hs.width * 0.5, -centre_w * 0.5, centre_w * 0.5, hs.width * 0.5]:
		tag("pilaster")
		box(Vector3(0.42, top, 0.36), Vector3(x, top * 0.5, z - 0.02), SURF_TRIM)
		for course in range(int(top / 0.65)):
			box(Vector3(0.62, 0.12, 0.42),
				Vector3(x, 0.35 + course * 0.65, z - 0.04), SURF_TRIM)

	var bays := HotelGeometry.facade_bay_positions(hs)
	for level in range(hs.storeys):
		var y := float(level) * hs.height + hs.height * 0.58
		for i in range(bays.size()):
			if level == 0 and i == bays.size() / 2:
				continue
			_window(Vector3(bays[i], y, z - 0.16), level == 0)
	_build_entrance(z, centre_w)
	_build_balconies(z, centre_w)
	_build_centre_crown(z, top, centre_w)


func _window(pos: Vector3, ground := false) -> void:
	var h := WINDOW_H * (1.12 if ground else 1.0)
	tag("facade_window")
	box(Vector3(WINDOW_W, h, FACADE_D), pos, SURF_ROOF)
	box(Vector3(WINDOW_W + FRAME * 2.0, FRAME, FACADE_D * 1.8),
		pos + Vector3(0, h * 0.5 + FRAME * 0.5, -0.02), SURF_TRIM)
	box(Vector3(WINDOW_W + FRAME * 2.0, FRAME, FACADE_D * 1.8),
		pos - Vector3(0, h * 0.5 + FRAME * 0.5, 0.02), SURF_TRIM)
	for side in [-1.0, 1.0]:
		box(Vector3(FRAME, h + FRAME * 2.0, FACADE_D * 1.8),
			pos + Vector3(side * (WINDOW_W + FRAME) * 0.5, 0, -0.02), SURF_TRIM)
	# A mullion and hood turn the rectangles into the tall paired windows in
	# the reference without pretending they are holes in the wall.
	box(Vector3(0.08, h, FACADE_D * 2.0), pos + Vector3(0, 0, -0.03), SURF_TRIM)
	box(Vector3(WINDOW_W + 0.38, 0.12, 0.3),
		pos + Vector3(0, h * 0.5 + 0.22, 0), SURF_TRIM)


func _build_entrance(z: float, centre_w: float) -> void:
	tag("ceremonial_entrance")
	var door_w := 3.8
	var door_h := 3.15
	for side in [-1.0, 1.0]:
		box(Vector3(0.52, door_h + 1.35, 0.52),
			Vector3(side * (door_w * 0.5 + 0.6), (door_h + 1.35) * 0.5, z - 0.12),
			SURF_TRIM)
		box(Vector3(0.68, 0.18, 0.64),
			Vector3(side * (door_w * 0.5 + 0.6), 0.09, z - 0.12), SURF_TRIM)
		# Dark side leaves make the opening read at landmark scale while the
		# central 1.8m planned doorway remains physically open.
		box(Vector3(0.72, 2.45, FACADE_D),
			Vector3(side * 1.28, 1.23, z - 0.18), SURF_ROOF)
	_kit.arc_ribbon(Vector3(-door_w * 0.5, door_h + 0.05, z - 0.14),
		Vector3(door_w * 0.5, door_h + 0.05, z - 0.14), 0.75, 0.18, 0.25,
		SURF_TRIM, 10)
	box(Vector3(minf(centre_w * 0.78, 11.0), 0.24, 1.35),
		Vector3(0, door_h + 1.35, z - 0.5), SURF_TRIM)
	# The sign panel is wall-colored and framed, leaving the real entrance void
	# below it open for navigation and collision.
	box(Vector3(minf(centre_w * 0.62, 8.2), 0.88, 0.24),
		Vector3(0, door_h + 2.05, z - 0.1), SURF_WALL)
	box(Vector3(minf(centre_w * 0.68, 8.8), 0.12, 0.34),
		Vector3(0, door_h + 2.55, z - 0.12), SURF_TRIM)


func _build_balconies(z: float, centre_w: float) -> void:
	var xs := [-centre_w * 0.32, 0.0, centre_w * 0.32]
	for x in xs:
		tag("balcony")
		var y := spec.height * 1.22
		box(Vector3(3.8, 0.18, 1.05), Vector3(x, y, z - 0.48), SURF_TRIM)
		for post in range(7):
			var px: float = x - 1.6 + post * (3.2 / 6.0)
			box(Vector3(0.08, 0.72, 0.08),
				Vector3(px, y + 0.42, z - 0.92), SURF_TRIM)
		box(Vector3(3.45, 0.09, 0.1), Vector3(x, y + 0.8, z - 0.92), SURF_TRIM)


func _build_centre_crown(z: float, top: float, centre_w: float) -> void:
	tag("centre_pavilion")
	var crown_h := 1.45
	box(Vector3(centre_w, crown_h, 0.72),
		Vector3(0, top + crown_h * 0.5, z + 0.12), SURF_WALL)
	_log_mass("wall_centre_pavilion", AABB(
		Vector3(-centre_w * 0.5, top, z - 0.24), Vector3(centre_w, crown_h, 0.72)))
	for x in [-centre_w * 0.5, 0.0, centre_w * 0.5]:
		box(Vector3(0.36, crown_h + 0.2, 0.5),
			Vector3(x, top + crown_h * 0.5, z - 0.18), SURF_TRIM)
	_window(Vector3(0, top + crown_h * 0.55, z - 0.28))
	_kit.gable_end(centre_w * 0.28, 1.5, top + crown_h, z - 0.28,
		0.28, SURF_WALL)
	total_height = maxf(total_height, top + crown_h + 1.5)


func _build_palace_roof() -> void:
	var hs := spec as HotelSpec
	var top := HotelGeometry.wall_top(hs)
	tag("mansard_roof")
	# Ridge along X: the dark steep slope is the dominant face seen from the
	# road, as it is in the reference elevation.
	var xf := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(0, top, 0))
	_kit.ridge_roof(xf, hs.length + 1.0, hs.width + 1.0, hs.roof_rise,
		SURF_ROOF, SURF_WALL, hs.length, hs.width)
	_log_mass("roof", AABB(
		Vector3(-hs.width * 0.5 - 0.5, top, -hs.length * 0.5 - 0.5),
		Vector3(hs.width + 1.0, hs.roof_rise + 4.0, hs.length + 1.0)))
	_build_dormers(top, hs)
	if hs.cupolas:
		_build_cupola(-HotelGeometry.tower_x(hs), top, hs)
		_build_cupola(HotelGeometry.tower_x(hs), top, hs)
	total_height = maxf(total_height, HotelGeometry.total_height(hs))


func _build_dormers(top: float, hs: HotelSpec) -> void:
	var z := -hs.length * 0.5 - 0.3
	var run := hs.width * 0.76
	for i in range(hs.dormer_count):
		var x := -run * 0.5 + run * (float(i) + 0.5) / hs.dormer_count
		if absf(x) < HotelGeometry.centre_width(hs) * 0.25:
			continue
		tag("dormer")
		var y := top + hs.roof_rise * 0.42
		box(Vector3(1.15, 1.6, 0.95), Vector3(x, y, z), SURF_ROOF)
		box(Vector3(0.62, 0.92, 0.12), Vector3(x, y, z - 0.54), SURF_TRIM)
		_kit.gable_end(0.72, 0.62, y + 0.8, z - 0.62, 0.18, SURF_TRIM)


func _build_cupola(x: float, top: float, hs: HotelSpec) -> void:
	var r := HotelGeometry.cupola_radius(hs)
	var z := HotelGeometry.front_z(hs) + 1.9
	tag("corner_tower")
	box(Vector3(r * 2.05, 2.4, r * 2.05),
		Vector3(x, top + 1.0, z), SURF_WALL)
	_log_mass("wall_cupola_tower", AABB(Vector3(x - r, top - 0.2, z - r),
		Vector3(r * 2.0, 2.6, r * 2.0)))
	for side in [-1.0, 1.0]:
		box(Vector3(0.2, 2.45, 0.26),
			Vector3(x + side * r * 0.82, top + 1.0, z - r - 0.1), SURF_TRIM)
	_window(Vector3(x, top + 1.0, z - r - 0.2))
	tag("cupola")
	var profile := PackedVector2Array([
		Vector2(r * 1.1, 0.0), Vector2(r * 1.12, 0.28),
		Vector2(r * 0.88, 1.15), Vector2(r * 0.42, 2.0), Vector2(0.0, 2.45)])
	_kit.revolve(profile, Vector3(x, top + 2.2, z), SURF_ROOF, 16, TAU)
	_kit.cone(0.16, 1.5, Vector3(x, top + 4.55, z), SURF_TRIM, 10)
