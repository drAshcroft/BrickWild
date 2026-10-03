extends RefCounted
## Access structures are measured before yard dressing. All coordinates are
## in the castle frame; emitters and planning reservations read these records.

const LANE := 1.25
const SPINE := 0.2
const LANDING := 0.9
const TREAD := 0.28


## The emitted motte treads are also the passage reservation at the bailey's
## rear curtain. Extending a stair to the mound toe must cut every wall it
## crosses; a clear line beside the climbing curtain alone is insufficient.
static func motte_approach(spec: CastleSpec, door_xz := Vector2(INF, INF)) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not CastleGeometry.is_motte(spec):
		return out
	var wall := CastleGeometry.climb_wall(spec)
	var keep := CastleGeometry.shell_keep_aabb(spec)
	var centre := CastleGeometry.motte_center(spec)
	var to := Vector3(centre.x, spec.motte_height + HouseGeometry.FLOOR_T,
		keep.position.z + spec.shell_thickness)
	var width := clampf(maxf(float(wall.thickness) * 3.0, 2.0), 2.0, 3.6)
	var outward := Vector2(0.0, -1.0)
	var door_clear := width
	var doorway_depth := 0.0
	if is_finite(door_xz.x) and is_finite(door_xz.y):
		to.x = door_xz.x
		to.z = door_xz.y
		var plan := CastleMottePlan.generate(spec, false)
		if plan.spec != null and plan.entrance() >= 0:
			outward = Vector2(plan.doors[plan.entrance()].normal).normalized()
			door_clear = minf(width, float(plan.doors[plan.entrance()].width) - 0.12)
			doorway_depth = HouseGeometry.wall_thickness(plan.spec)
	else:
		to.x += float(wall.thickness) * 0.5 + width * 0.5 + 0.25
	var radius := CastleGeometry.motte_base_radius(spec)
	# Reach the drum toe along the doorway's true normal. A Z-aligned flight
	# can strike an oblique doorway's jamb even with its centre on the door.
	var offset := Vector2(to.x, to.z) - centre
	var along := offset.dot(outward)
	var length := -along + sqrt(maxf(along * along + radius * radius - offset.length_squared(), 0.0)) + 0.8
	if length <= 0.1:
		return out
	var direction := Vector3(-outward.x, 0.0, -outward.y)
	var lateral := Vector3(direction.z, 0.0, -direction.x)
	var from := Vector3(to.x, 0.0, to.z) - direction * length
	var yaw := atan2(direction.x, direction.z)
	var batter := tan(deg_to_rad(clampf(spec.motte_batter, 20.0, 60.0)))
	var count := maxi(5, maxi(int(ceil(to.y / 0.28)), int(ceil(length * batter / 0.20))))
	var depth := length / float(count)
	var previous_top := 0.0
	for i in range(count):
		var at := from + direction * (depth * (float(i) + 0.5))
		# The broad exterior flight narrows before entering the doorway. The
		# tread itself, as well as its walking corridor, must clear both jambs.
		var remaining := length - depth * (float(i) + 0.5)
		var tread_width := clampf(door_clear + (remaining - doorway_depth - depth) * 2.0,
			door_clear, width)
		var surface_y := 0.0
		for sx in [-tread_width * 0.5, tread_width * 0.5]:
			for sz in [-depth * 0.5, depth * 0.5]:
				var corner := at + lateral * float(sx) + direction * float(sz)
				surface_y = maxf(surface_y, motte_surface_y(spec, corner.x, corner.z))
		# A radial mound can peak between the uphill corners. The closest
		# footprint point to its centre bounds the entire visible tread top.
		var toward_centre := Vector3(centre.x - at.x, 0.0, centre.y - at.z)
		var nearest := at + lateral * clampf(toward_centre.dot(lateral),
			-tread_width * 0.5, tread_width * 0.5) + direction * clampf(
			toward_centre.dot(direction), -depth * 0.5, depth * 0.5)
		surface_y = maxf(surface_y, motte_surface_y(spec, nearest.x, nearest.z))
		# The occupied floor is above the mound by FLOOR_T. A stair following
		# bare terrain alone is buried by that floor at the keep threshold.
		var top := maxf(to.y * float(i + 1) / float(count),
			surface_y + HouseGeometry.FLOOR_T + 0.015)
		# The mound top is a level landing. Artificial micro-risers here used
		# to climb above the occupied floor and obstruct the doorway threshold.
		top = maxf(top, previous_top)
		var base := surface_y + 0.005
		var h := maxf(top - base, 0.01)
		at.y = base + h * 0.5
		out.append({"pos": at, "size": Vector3(tread_width, h, depth), "rot_y": yaw})
		previous_top = at.y + h * 0.5
	return out


static func motte_surface_y(spec: CastleSpec, x: float, z: float) -> float:
	var centre := CastleGeometry.motte_center(spec)
	var radius := CastleGeometry.motte_base_radius(spec)
	var top_radius := CastleGeometry.motte_top_radius(spec)
	var radial := Vector2(x - centre.x, z - centre.y).length()
	if radial >= radius:
		return 0.0
	if radial <= top_radius:
		return spec.motte_height
	return spec.motte_height * (radius - radial) / maxf(radius - top_radius, 0.001)


## X/Y opening through an axis-aligned rear curtain, including the battered
## toe. Its head follows the highest tread actually crossing that masonry.
static func motte_passage(spec: CastleSpec, wall: AABB,
		door_xz := Vector2(INF, INF)) -> Rect2:
	var opening := Rect2()
	for step in motte_approach(spec, door_xz):
		var at: Vector3 = step.pos
		var size: Vector3 = step.size
		var yaw := float(step.rot_y)
		var half := Vector2(absf(cos(yaw)) * size.x + absf(sin(yaw)) * size.z,
			absf(sin(yaw)) * size.x + absf(cos(yaw)) * size.z) * 0.5
		if at.z + half.y < wall.position.z - 0.12 \
				or at.z - half.y > wall.end.z + 0.12:
			continue
		var gap := Rect2(at.x - half.x - 0.12, 0.0,
			half.x * 2.0 + 0.24, at.y + size.y * 0.5 + 2.2)
		opening = gap if not opening.has_area() else opening.merge(gap)
	return opening

## A roofed straight stair meets the actual first-floor face. Receding keeps
## get a longer top landing across the lower storey's shoulder.
static func forebuilding(spec: CastleSpec) -> Dictionary:
	if not CastleGeometry.is_enclosed(spec) or not spec.keep or CastleGeometry.is_motte(spec):
		return {}
	var plan := preload("castle_keep_plan.gd").generate(spec, false)
	return forebuilding_for_plan(spec, plan)


## Build the stair envelope from the keep plan already in hand. CastleKeepPlan
## uses this to reject a raised doorway whose real approach would strike gate 1.
static func forebuilding_for_plan(spec: CastleSpec, plan: HousePlan) -> Dictionary:
	if not CastleGeometry.is_enclosed(spec) or not spec.keep or CastleGeometry.is_motte(spec):
		return {}
	if plan.spec == null or plan.entrance() < 0:
		return {}
	var door: Dictionary = plan.doors[plan.entrance()]
	# A forebuilding is for a raised keep entrance. Grade-level fallback and
	# terraced doors have no stair to reserve or emit.
	if HousePlan.record_storey(door) <= 0:
		return {}
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
	# A side-facing Bergfried door meets a straight stair. Its landing length
	# is measured along the door normal, not from the tower's north edge.
	var landing := 1.0 if spec.plan_kind in [&"bergfried", &"terraced"] \
		else maxf(1.0, at.y - keep.position.z + 0.3)
	var length := run + landing
	var front := at + normal * length
	var side := Vector2(-normal.y, normal.x)
	var corners := PackedVector2Array([
		front - side * width * 0.5, front + side * width * 0.5,
		at + normal * (HouseGeometry.wall_thickness(plan.spec) + 0.2) - side * width * 0.5,
		at + normal * (HouseGeometry.wall_thickness(plan.spec) + 0.2) + side * width * 0.5])
	var foot: Rect2 = Poly.bounding_rect(corners) if spec.plan_kind == &"bergfried" \
		else Rect2(front.x - width * 0.5, front.y, width, length)
	return {"at": at, "normal": normal, "front": front, "height": height,
		"steps": steps, "run": run, "landing": landing, "width": width,
		"clear": clear, "wall": wall, "length": length, "footprint": foot,
		"door_outer": at + normal * HouseGeometry.wall_thickness(plan.spec)}

static func wall_stairs(spec: CastleSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not CastleGeometry.is_enclosed(spec):
		return out
	var galleries: Array[Rect2] = []
	if CastleGeometry.is_motte(spec):
		# A wall stair must not climb under a gallery with less than standing
		# headroom. Ask the same pure access layout that emits those decks.
		var mural := preload("castle_mural_plan.gd").records(spec, true)
		for row in mural.values():
			galleries.append(Rect2(row.walk_landing))
			for span in row.get("walk_gallery", []):
				var a: Vector2 = span.a
				var b: Vector2 = span.b
				var side := Vector2(-(b - a).y, (b - a).x).normalized() * float(span.width) * 0.5
				galleries.append(Poly.bounding_rect(PackedVector2Array([a + side, b + side, b - side, a - side])))
		for row in preload("castle_gate_plan.gd").records(spec, true).values():
			for gallery in row.gallery:
				galleries.append(Rect2(gallery))
	var fore: Dictionary = forebuilding(spec)
	for ring in CastleGeometry.rings(spec):
		var ring_start: int = out.size()
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
		for gallery in galleries:
			blocked.append(gallery.grow(0.15))
		var tower_polygons: Array[PackedVector2Array] = []
		for box in [CastleGeometry.keep_aabb(spec), CastleGeometry.hall_aabb(spec),
			CastleGeometry.chapel_aabb(spec), CastleGeometry.apse_aabb(spec), gate]:
			if box.size.x > 0.0:
				blocked.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(0.15))
		# The raised keep entrance has its own roofed stair on the ground. Its
		# planner footprint does not include the emitted slab and roof overhang;
		# reserve the measured 0.22m envelope so wall stairs cannot cross it.
		if not fore.is_empty():
			var fore_footprint: Rect2 = fore["footprint"]
			blocked.append(fore_footprint.grow(0.22))
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
			var best := _best_wall_stair(spec, ring, edge, clear_ward, blocked,
				tower_polygons, gate_at, width, span, flights, steps, rise, run,
				height, side)
			if not best.is_empty():
				out.append(best)
				blocked.append(best.footprint.grow(0.2))
		# On a small polygon, occupied buildings may leave only one x-half-plane
		# clear. A second independent stair may fit on another face of that side.
		# Keep every physical clearance check and reserve the first stair before
		# looking for this fallback.
		if out.size() - ring_start < 2:
			var fallback := _best_wall_stair(spec, ring, edge, clear_ward,
				blocked, tower_polygons, gate_at, width, span, flights, steps,
				rise, run, height, 0.0)
			if not fallback.is_empty():
				out.append(fallback)
				blocked.append(fallback.footprint.grow(0.2))
	return out


static func _best_wall_stair(spec: CastleSpec, ring: int, edge: PackedVector2Array,
		clear_ward: PackedVector2Array, blocked: Array[Rect2],
		tower_polygons: Array[PackedVector2Array], gate_at: Vector2,
		width: float, span: float, flights: int, steps: int, rise: float,
		run: float, height: float, side: float) -> Dictionary:
	var best := {}
	var score := INF
	for e in edge.size():
		var a := edge[e]
		var b := edge[(e + 1) % edge.size()]
		var length := a.distance_to(b)
		var along := (b - a) / length
		var inside := -CastleGeometry.edge_outward(a, b)
		# A transverse stair uses only its width along the curtain. Sampling by
		# the full flight span rejects short octagon facets before it is considered.
		for transverse in [false, true]:
			var edge_span := width if transverse else span
			if length < edge_span + 0.4:
				continue
			var edge_offset := edge_span * 0.5 + 0.2
			var samples := maxi(1, int(ceil((length - edge_span) / 0.2)))
			for sample in range(samples + 1):
				var boundary := a.lerp(b, (edge_offset + (length - edge_span - 0.4) \
					* float(sample) / samples) / length)
				boundary += inside * CastleGeometry.wall_thickness(spec, ring)
				if absf(side) > 0.1 and boundary.x * side <= 0.0:
					continue
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
				# The flight can be clear while its final step onto the curtain
				# crosses a projecting tower. Reserve that body corridor as well.
				var start_forward := -1.0 if transverse and flights % 2 == 1 else 1.0
				var finish_forward := start_forward * (1.0 if flights % 2 == 1 else -1.0)
				var arrival := at + axis * finish_forward * (run + LANDING) * 0.5 + across * LANE * 0.5
				var coping := Geometry2D.get_closest_point_to_segment(arrival,
					a + inside * CastleGeometry.wall_thickness(spec, ring) * 0.5,
					b + inside * CastleGeometry.wall_thickness(spec, ring) * 0.5)
				var arrival_side := Vector2(-(coping - arrival).y, (coping - arrival).x).normalized() * 0.3
				var arrival_poly := PackedVector2Array([arrival + arrival_side, coping + arrival_side,
					coping - arrival_side, arrival - arrival_side])
				var arrival_bounds := Poly.bounding_rect(arrival_poly).grow(0.01)
				if blocked.any(func(rect): return rect.grow(-0.001).intersects(arrival_bounds)):
					continue
				if tower_polygons.any(func(tower): return not Geometry2D.intersect_polygons(tower, arrival_poly).is_empty()):
					continue
				var distance := boundary.distance_squared_to(gate_at) + (1.0 if transverse else 0.0)
				if distance >= score:
					continue
				score = distance
				best = {"ring": ring, "edge": e, "at": at, "along": axis,
					"inside": across, "flights": flights, "steps": steps, "rise": rise,
					"run": run, "span": span, "width": width, "height": height,
					"start_forward": start_forward,
					"poly": poly, "footprint": footprint}
	return best


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
