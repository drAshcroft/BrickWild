class_name HotelBuilder
extends HouseBuilder
## The walkable house shell with a palatial, bilaterally symmetric facade and
## a steep mansard-like roofline layered on before the mesh is committed.

const WINDOW_W := 0.92
const WINDOW_H := 1.5
const FRAME := 0.13
const FACADE_D := 0.12

## How far down the slope a dormer front face sits, as a fraction of the roof
## half span. Low enough to read as an attic window from the road, far enough
## from the eave that the slope behind it can still rise to meet the rooflet.
const DORMER_SET_DOWN := 0.62
## The dormer opening, and the body that stands in it.
const DORMER_W := 1.15


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
	# road, as it is in the reference elevation. The roof is turned a quarter
	# turn to get there, so the roof local X runs across the hotel LENGTH and
	# its local Z along the hotel WIDTH. Every dormer number below is in that
	# frame, not in the hotel one.
	var layout := HotelGeometry.roof_layout(hs)
	var xf: Transform3D = layout["transform"]
	var roof: Array[PackedVector3Array] = layout["faces"]
	var dormers := _hotel_dormer_seats(hs, roof)
	# ridge_roof still closes the four wall heads against the actual roof
	# underside; that part has no dormers in it. Its slopes are deferred so the
	# dormer openings can be cut out of them first: a dormer with no hole
	# behind it is a box with the host roof running through its glazing.
	var deferred: Array[PackedVector3Array] = []
	_kit.ridge_roof(xf, hs.length + 1.0, hs.width + 1.0, hs.roof_rise,
		SURF_ROOF, SURF_WALL, hs.length, hs.width, 0.3, 0.0, deferred)
	for fi in range(roof.size()):
		var pieces: Array[PackedVector2Array] = [RoofShape.footprint(roof[fi])]
		for d in dormers:
			if int(d["face"]) != fi:
				continue
			var next: Array[PackedVector2Array] = []
			for piece in pieces:
				next.append_array(RoofShape.subtract(piece, d["opening"]))
			pieces = next
		for piece in pieces:
			_kit.slab_poly(xf * RoofShape.lift(piece, roof[fi]),
				RoofShape.DEPTH, SURF_ROOF, true)
	_log_mass("roof", AABB(
		Vector3(-hs.width * 0.5 - 0.5, top, -hs.length * 0.5 - 0.5),
		Vector3(hs.width + 1.0, hs.roof_rise + 4.0, hs.length + 1.0)))
	_build_hotel_dormers(xf, dormers)
	if hs.cupolas:
		_build_cupola(-HotelGeometry.tower_x(hs), top, hs)
		_build_cupola(HotelGeometry.tower_x(hs), top, hs)
	total_height = maxf(total_height, HotelGeometry.total_height(hs))


## Where the hotel dormers sit, in the roof own frame.
##
## The old version put each box at a fixed z just outside the front wall and
## lifted it to 42 per cent of the rise -- two numbers with nothing to do with
## where the roof surface actually is. On a 48x24 palace that left every body
## between 0.78 m and 1.14 m in the air above its own slope (ROOF-AUDIT-001).
## The seat now comes from the roof: RoofShape.dormer_seat answers "at what
## local X is the host plane this high", and every coordinate below is one of
## its answers.
func _hotel_dormer_seats(hs: HotelSpec, roof: Array[PackedVector3Array]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if hs.dormer_count <= 0 or roof.is_empty():
		return out
	var half: float = (hs.length + 1.0) * 0.5
	# The dormers face the road, and the road is -Z. The roof quarter turn maps
	# its +X to the hotel -Z, so the road-facing slope is +X: the face
	# RoofShape.faces emits second.
	var seat := RoofShape.dormer_seat(half, hs.roof_rise,
		half * DORMER_SET_DOWN, DORMER_W)
	if not bool(seat["fits"]):
		return out
	var face_index := 1 if roof.size() > 1 else 0
	var host: PackedVector2Array = RoofShape.footprint(roof[face_index])
	var front: float = seat["front"]
	var rh: float = seat["roof_half"]
	var hw: float = DORMER_W * 0.5
	var out_dir: float = signf(front)
	var run: float = hs.width * 0.76
	var cupola_r: float = HotelGeometry.cupola_radius(hs) + 0.4
	var tower_x: float = HotelGeometry.tower_x(hs)
	for i in range(hs.dormer_count):
		# The dormers march along the ridge, which is the roof local Z and the
		# hotel world X.
		var z := -run * 0.5 + run * (float(i) + 0.5) / float(hs.dormer_count)
		if absf(z) < HotelGeometry.centre_width(hs) * 0.25:
			continue      # the centre crown stands here
		if hs.cupolas and absf(absf(z) - tower_x) < cupola_r + hw:
			continue      # and a cupola here
		var cover := PackedVector2Array([
			Vector2(front + out_dir * 0.12, z - rh),
			Vector2(seat["side_x"], z - rh), Vector2(seat["peak_x"], z),
			Vector2(seat["side_x"], z + rh), Vector2(front + out_dir * 0.12, z + rh)])
		var valid := true
		for p in cover:
			if not Poly.contains_point(host, p):
				valid = false
			for j in range(host.size()):
				var edge: Vector2 = host[(j + 1) % host.size()] - host[j]
				if absf(edge.cross(p - host[j])) / edge.length() < 0.12:
					valid = false
		if not valid:
			continue
		var row := seat.duplicate()
		row["id"] = "dormer_%d" % i
		row["face"] = face_index
		row["z"] = z
		row["out"] = out_dir
		row["opening"] = PackedVector2Array([
			Vector2(front, z - hw), Vector2(seat["cheek_x"], z - hw),
			Vector2(seat["peak_x"], z), Vector2(seat["cheek_x"], z + hw),
			Vector2(front, z + hw)])
		out.append(row)
	return out


## The hotel dormers: a long even row across a mansard, which is not the same
## piece of architecture as HouseBuilder._build_dormers -- that one sets them
## on one pitch of a cottage roof. The SEAT is shared; only the carpentry here
## differs.
func _build_hotel_dormers(xf: Transform3D, dormers: Array[Dictionary]) -> void:
	for d in dormers:
		tag("dormer")
		host(String(d["id"]), maxi(spec.storeys, 1) - 1)
		var first := component_log.size()
		var z: float = d["z"]
		var front: float = d["front"]
		var out_dir: float = d["out"]
		var base: float = float(d["base"]) - RoofShape.DEPTH * 0.5
		var eave: float = d["eave"]
		var peak: float = d["peak"]
		var rh: float = d["roof_half"]
		var hw: float = DORMER_W * 0.5
		var lift: float = peak - eave
		var side_top: float = eave + lift * (1.0 - hw / rh) - RoofShape.DEPTH * 0.5
		var head: float = eave - RoofShape.DEPTH * 0.5
		# Rooflet: ends on the valley where it meets the host plane, not in a
		# rectangle buried behind the slope.
		for side in [-1.0, 1.0]:
			_slab(xf, "dormer_roof", PackedVector3Array([
				Vector3(front + out_dir * 0.12, eave, z + side * rh),
				Vector3(d["side_x"], eave, z + side * rh),
				Vector3(d["peak_x"], peak, z),
				Vector3(front + out_dir * 0.12, peak, z)]),
				RoofShape.DEPTH, SURF_ROOF, true)
			# Cheeks taper to nothing at that same intersection.
			_slab(xf, "dormer_cheek", PackedVector3Array([
				Vector3(front, base, z + side * hw),
				Vector3(front, side_top, z + side * hw),
				Vector3(d["cheek_x"], side_top, z + side * hw)]),
				0.08, SURF_WALL, false)
		_slab(xf, "dormer_gable", PackedVector3Array([
			Vector3(front, head, z - hw), Vector3(front, head, z + hw),
			Vector3(front, side_top, z + hw),
			Vector3(front, peak - RoofShape.DEPTH * 0.5, z),
			Vector3(front, side_top, z - hw)]), 0.10, SURF_WALL, false)
		# The window in it, and the glazing the host roof must not run through.
		var win_bottom: float = base + 0.20
		var win_top: float = head - 0.13
		var win_w: float = DORMER_W * 0.65
		for side in [-1.0, 1.0]:
			component_box("dormer_jamb",
				Vector3(0.10, head - base, hw - win_w * 0.5),
				xf * Transform3D(Basis(), Vector3(front, (head + base) * 0.5,
					z + side * (hw + win_w * 0.5) * 0.5)), SURF_TRIM)
		for band in [[base, win_bottom], [win_top, head]]:
			component_box("dormer_panel", Vector3(0.10, band[1] - band[0], win_w),
				xf * Transform3D(Basis(), Vector3(front,
					(band[0] + band[1]) * 0.5, z)), SURF_TRIM)
		component_box("dormer_glazing", Vector3(0.04, win_top - win_bottom, win_w),
			xf * Transform3D(Basis(), Vector3(front + out_dir * 0.04,
				(win_top + win_bottom) * 0.5, z)), SURF_ROOF)
		# One part_log row per dormer BODY, measured from the pieces actually
		# emitted for it. The landmark rule counts dormers, and geometry that
		# only exists in the mesh is geometry QA cannot count -- which is how
		# seating the dormers correctly still managed to break that rule.
		#
		# The record is the BODY: cheeks and gable front, from the front face
		# back to where the cheeks die into the host. The rooflet overhangs and
		# must stay out of it, or the attachment probe -- which samples the
		# host under the body's REAR edge -- would sample past the join.
		#
		# kind is "box", not "dormer": tools/check_roofs.gd selects bodies with
		# `tag == "dormer" and kind == "box"`, and a record it cannot select is
		# a test that passes by measuring nothing.
		var bounds := AABB()
		var found := false
		for ci in range(first, component_log.size()):
			var role: String = component_log[ci]["role"]
			if role != "dormer_cheek" and role != "dormer_gable":
				continue
			var piece := MassBuilder.component_aabb(component_log[ci])
			bounds = piece if not found else bounds.merge(piece)
			found = true
		if found:
			_log_part("box", bounds.get_center(), bounds.size)
		host_end()


## A roof-local polygon slab, emitted and logged in world space.
func _slab(xf: Transform3D, role: String, local: PackedVector3Array,
		depth: float, surface: int, vertical: bool) -> void:
	var world := PackedVector3Array()
	for p in local:
		world.append(xf * p)
	component_slab(role, world, depth, surface, vertical)


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
