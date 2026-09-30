extends RefCounted
## Access structures are measured before yard dressing. All coordinates are
## in the castle frame; emitters and planning reservations read these records.

const LANE := 1.25
const SPINE := 0.2
const LANDING := 0.9
const TREAD := 0.28

## A roofed straight stair meets the actual first-floor face. Receding keeps
## get a longer top landing across the lower storey's shoulder.
static func forebuilding(spec: CastleSpec) -> Dictionary:
	if not CastleGeometry.is_enclosed(spec) or not spec.keep or CastleGeometry.is_motte(spec):
		return {}
	var plan := preload("castle_keep_plan.gd").generate(spec, false)
	if plan.spec == null or plan.entrance() < 0:
		return {}
	var door: Dictionary = plan.doors[plan.entrance()]
	var keep := CastleGeometry.keep_aabb(spec)
	var centre := Vector2(keep.get_center().x, keep.get_center().z)
	var at: Vector2 = centre + Vector2(door.pos)
	var normal: Vector2 = door.normal
	var height := plan.spec.height * HousePlan.record_storey(door) + HouseGeometry.FLOOR_T
	var steps := maxi(1, int(ceil(height / 0.2)))
	var run := steps * TREAD
	var clear := maxf(2.0, float(door.width) + 0.8)
	var wall := 0.3
	var width := clear + wall * 2.0
	var landing := maxf(1.0, at.y - keep.position.z + 0.3)
	var length := run + landing
	var front := at + normal * length
	var foot := Rect2(front.x - width * 0.5, front.y, width, length)
	return {"at": at, "normal": normal, "front": front, "height": height,
		"steps": steps, "run": run, "landing": landing, "width": width,
		"clear": clear, "wall": wall, "length": length, "footprint": foot,
		"door_outer": at + normal * HouseGeometry.wall_thickness(plan.spec)}

static func wall_stairs(spec: CastleSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not CastleGeometry.is_enclosed(spec):
		return out
	for ring in CastleGeometry.rings(spec):
		var height := CastleGeometry.wall_height(spec, ring) + CastleGeometry.PARAPET_RISE
		var flights := maxi(1, int(ceil(height / 2.5)))
		if height / flights < 2.15:
			flights = maxi(1, flights - 1)
		var rise := height / flights
		var steps := maxi(1, int(ceil(rise / 0.2)))
		var run := steps * TREAD
		var width := LANE * 2.0 + SPINE
		var span := run + LANDING * 2.0
		var edge := CastleGeometry.enceinte_polygon(spec, ring)
		var clear_ward := CastleGeometry.inner_polygon(spec, ring)
		var gate := CastleGeometry.gatehouse_aabb(spec, ring)
		var gate_at := Vector2(gate.get_center().x, gate.get_center().z)
		var blocked: Array[Rect2] = []
		var tower_polygons: Array[PackedVector2Array] = []
		for box in [CastleGeometry.keep_aabb(spec), CastleGeometry.hall_aabb(spec),
			CastleGeometry.chapel_aabb(spec), CastleGeometry.apse_aabb(spec), gate]:
			if box.size.x > 0.0:
				blocked.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(0.15))
		# An inner gate's projecting towers can occupy the outer ward. Reserve
		# every ring's masonry, not only the curtain this stair climbs.
		for other_ring in CastleGeometry.rings(spec):
			var vertices := CastleGeometry.vertex_tower_centers(spec, other_ring)
			for index in vertices.size():
				var outline := _tower_outline(spec, other_ring, vertices[index], index)
				tower_polygons.append(outline)
				# Massing QA compares logged bounds. Keep stairs outside those
				# envelopes as well as outside the exact battered tower footprint.
				if other_ring != ring:
					blocked.append(Poly.bounding_rect(outline))
			var towers := CastleGeometry.gate_tower_centers(spec, other_ring)
			for slot in CastleGeometry.side_tower_slots(spec, other_ring):
				towers.append(slot.pos)
			for tower in towers:
				var outline := _tower_outline(spec, other_ring, tower)
				tower_polygons.append(outline)
				if other_ring != ring:
					blocked.append(Poly.bounding_rect(outline))
			if other_ring != ring:
				var box := CastleGeometry.gatehouse_aabb(spec, other_ring)
				blocked.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))
		for side in [-1.0, 1.0]:
			var best := {}
			var score := INF
			for e in edge.size():
				var a := edge[e]
				var b := edge[(e + 1) % edge.size()]
				var length := a.distance_to(b)
				if length < span + 0.4:
					continue
				var along := (b - a) / length
				var inside := -CastleGeometry.edge_outward(a, b)
				var samples := maxi(1, int(ceil((length - span) / 0.2)))
				for sample in range(samples + 1):
					var boundary := a.lerp(b, (span * 0.5 + 0.2 + (length - span - 0.4) * float(sample) / samples) / length)
					boundary += inside * CastleGeometry.wall_thickness(spec, ring)
					if boundary.x * float(side) <= 0.0:
						continue
					# A narrow gate bay may take a stair end-on. Its final landing
					# then meets the curtain, leaving the passage between towers free.
					for transverse in [false, true]:
						var axis := inside if transverse else along
						var across := -along if transverse else inside
						var at := boundary + inside * span * 0.5 + along * width * 0.5 if transverse else boundary
						var poly := PackedVector2Array([at - axis * span * 0.5,
							at + axis * span * 0.5, at + axis * span * 0.5 + across * width,
							at - axis * span * 0.5 + across * width])
						if not Array(poly).all(func(p): return Poly.contains_point(clear_ward, p, 0.01)):
							continue
						var footprint := Poly.bounding_rect(poly)
						if blocked.any(func(rect): return rect.grow(-0.001).intersects(footprint)):
							continue
						if tower_polygons.any(func(tower): return not Geometry2D.intersect_polygons(tower, poly).is_empty()):
							continue
						var distance := boundary.distance_squared_to(gate_at) + (1.0 if transverse else 0.0)
						if distance >= score:
							continue
						score = distance
						best = {"ring": ring, "edge": e, "at": at, "along": axis,
							"inside": across, "flights": flights, "steps": steps, "rise": rise,
							"run": run, "span": span, "width": width, "height": height,
							"start_forward": -1.0 if transverse and flights % 2 == 1 else 1.0,
							"poly": poly, "footprint": footprint}
			if not best.is_empty():
				out.append(best)
				blocked.append(best.footprint.grow(0.2))
	return out


static func _tower_outline(spec: CastleSpec, ring: int, at: Vector3, vertex := -1) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var radius := CastleGeometry.tower_radius_for(spec, CastleGeometry.tower_base_half_at(spec, ring, vertex) - 0.001)
	var sides := CastleGeometry.tower_sides(spec)
	for side in sides:
		var angle := CastleGeometry.tower_rotation(spec) + TAU * side / sides
		polygon.append(Vector2(at.x, at.z) + Vector2(cos(angle), sin(angle)) * radius)
	return polygon


static func pieces(stair: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var run: float = stair.run
	var height: float = stair.height
	var span: float = stair.span
	var width: float = stair.width
	# The grounded central spine carries every flight. Landings turn round
	# its ends, so a support is never also a wall across the route.
	_piece(out, "wall_stair_spine", Vector3(run, height, SPINE), Vector3(0, height * 0.5, LANE + SPINE * 0.5), stair)
	for flight in int(stair.flights):
		var lane := (int(stair.flights) - 1 - flight) % 2
		var lane_at := LANE * 0.5 + lane * (LANE + SPINE)
		var forward := (1.0 if flight % 2 == 0 else -1.0) * float(stair.get("start_forward", 1.0))
		var floor_y := flight * float(stair.rise)
		for step in int(stair.steps):
			var rise := float(stair.rise) * (step + 1) / int(stair.steps)
			var u := forward * (-run * 0.5 + (step + 0.5) * TREAD)
			_piece(out, "wall_stair_tread", Vector3(TREAD, rise, LANE),
				Vector3(u, floor_y + rise * 0.5, lane_at), stair)
			if lane == 1 and step % 3 == 0:
				_piece(out, "wall_stair_guard_post", Vector3(0.08, 0.9, 0.08),
					Vector3(u, floor_y + rise + 0.45, width - 0.06), stair)
		if lane == 1:
			var slope := atan2(float(stair.rise), forward * run)
			_piece(out, "wall_stair_flight_rail", Vector3(Vector2(run, float(stair.rise)).length(), 0.09, 0.09),
				Vector3(0, floor_y + float(stair.rise) * 0.5 + 0.9, width - 0.06), stair,
				Basis(Vector3.BACK, slope))
		var level := floor_y + float(stair.rise)
		var end := forward * (run + LANDING) * 0.5
		_piece(out, "wall_stair_landing", Vector3(LANDING, 0.2, width),
			Vector3(end, level - 0.1, width * 0.5), stair)
		# Rails stay on the outside of the two-lane stair. The inside edge
		# opens directly onto the curtain's coping at the top landing.
		_piece(out, "wall_stair_landing_rail", Vector3(LANDING, 0.75, 0.12),
			Vector3(end, level + 0.375, width - 0.06), stair)
	for side in [-1.0, 1.0]:
		_piece(out, "wall_stair_pier", Vector3(0.22, height, 0.22),
			Vector3(float(side) * (span * 0.5 - 0.11), height * 0.5, width - 0.11), stair)
	return out


static func _piece(out: Array[Dictionary], role: String, size: Vector3, centre: Vector3, stair: Dictionary,
		local_basis := Basis.IDENTITY) -> void:
	var along: Vector2 = stair.along
	var inside: Vector2 = stair.inside
	var at: Vector2 = stair.at
	var basis := Basis(Vector3(along.x, 0, along.y), Vector3.UP, Vector3(inside.x, 0, inside.y))
	var xf := Transform3D(basis, Vector3(at.x, 0, at.y))
	xf.origin += basis * centre
	xf.basis *= local_basis
	out.append({"role": role, "size": size, "xf": xf})
