class_name CastleAccessGeometry
extends RefCounted
## Access structures are measured before yard dressing. All coordinates are
## in the castle frame; emitters and planning reservations read these records.

const LANE := 1.25
const SPINE := 0.2
## A landing turns the walker through a half circle onto the other lane. It
## is at least a lane deep, as a building code asks; at 0.9 m a person met the
## guard rail before they had finished turning (walk-QA, Thorncliffe pin 2).
const LANDING := 1.3
const TREAD := 0.28
## Every rail on a wall stair: posts, flight rail, landing and end guards.
const RAIL_T := 0.12
const RAIL_H := 0.75
const PIER_INSET := 0.02
## A flight's rise. Below this the solid treads of the flight two above leave
## less than a body and a step of headroom over the top of this one.
const MIN_FLIGHT_RISE := 2.15


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
	# A wall stair must not climb under a gallery with less than standing
	# headroom. Ask the same pure access layout that emits those decks. The
	# motte reserves every tower's and the gate chamber's. Other walled castles
	# keep the stair layout their routes were proven on and reserve the gate
	# chamber's gallery only as far as that leaves a stair within 15 m of every
	# gate (Crusader 9118 has none once the gallery counts); then they fall back
	# to the layout without it. CastleRouteCheck still rejects a stair whose
	# headroom is blocked.
	var tower_decks: Array[Rect2] = []
	if CastleGeometry.is_motte(spec):
		var mural := preload("castle_mural_plan.gd").records(spec, true)
		for row in mural.values():
			if Rect2(row.walk_landing).has_area():
				tower_decks.append(Rect2(row.walk_landing))
			for span in row.get("walk_gallery", []):
				var a: Vector2 = span.a
				var b: Vector2 = span.b
				var side := Vector2(-(b - a).y, (b - a).x).normalized() * float(span.width) * 0.5
				tower_decks.append(Poly.bounding_rect(PackedVector2Array([a + side, b + side, b - side, a - side])))
	var gate_decks: Array[Rect2] = []
	for row in preload("castle_gate_plan.gd").records(spec, true).values():
		for gallery in row.gallery:
			gate_decks.append(Rect2(gallery))
	var strict: Array[Rect2] = tower_decks.duplicate()
	strict.append_array(gate_decks)
	out = _plan_wall_stairs(spec, strict, true)
	if CastleGeometry.is_motte(spec) or gate_decks.is_empty() or _stairs_near_gates(spec, out):
		return out
	return _plan_wall_stairs(spec, tower_decks, false)


## Is there a stair within 15 m of the gate of every ring?
static func _stairs_near_gates(spec: CastleSpec, stairs: Array[Dictionary]) -> bool:
	for ring in CastleGeometry.rings(spec):
		var gate := CastleGeometry.gatehouse_aabb(spec, ring)
		var gate_rect := Rect2(gate.position.x, gate.position.z, gate.size.x, gate.size.z)
		var near := false
		for stair in stairs:
			if int(stair.ring) != ring:
				continue
			var rect: Rect2 = stair.footprint
			var dx := maxf(0.0, maxf(rect.position.x - gate_rect.end.x, gate_rect.position.x - rect.end.x))
			var dy := maxf(0.0, maxf(rect.position.y - gate_rect.end.y, gate_rect.position.y - rect.end.y))
			if Vector2(dx, dy).length() <= 15.0:
				near = true
		if not near:
			return false
	return true


## `envelopes`: also keep clear of each tower's own logged box on its own ring
## (massing QA compares those boxes), not only of the exact footprint.
static func _plan_wall_stairs(spec: CastleSpec, galleries: Array[Rect2],
		envelopes: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
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
				# envelopes (the tower's own logged box, not just the polygon's
				# bounding rectangle) as well as outside the exact footprint.
				if envelopes:
					blocked.append(_mass_rect(spec, other_ring, vertices[index], index))
				elif other_ring != ring:
					blocked.append(Poly.bounding_rect(outline))
			var towers := CastleGeometry.gate_tower_centers(spec, other_ring)
			for slot in CastleGeometry.side_tower_slots(spec, other_ring):
				towers.append(slot.pos)
			for tower in towers:
				var outline := _tower_outline(spec, other_ring, tower)
				tower_polygons.append(outline)
				if envelopes:
					blocked.append(_mass_rect(spec, other_ring, tower))
				elif other_ring != ring:
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


static func _mass_rect(spec: CastleSpec, ring: int, centre: Vector3, vertex := -1) -> Rect2:
	var box := CastleGeometry.tower_aabb(spec, ring, centre, vertex)
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(0.05)


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
			# A transverse stair climbs away from the curtain and must arrive
			# back at it. With an even number of flights it therefore starts
			# at the curtain too, its foot boxed into a landing-deep slot
			# against the wall (walk-QA, Thorncliffe pin 1). An odd count
			# puts the foot at the open end, facing the ward.
			var f_count := flights
			var f_steps := steps
			var f_rise := rise
			var f_run := run
			var f_span := span
			if transverse and flights % 2 == 0:
				var more := height / float(flights + 1) >= MIN_FLIGHT_RISE
				f_count = flights + 1 if more else flights - 1
				if f_count < 1:
					continue
				f_rise = height / float(f_count)
				f_steps = maxi(1, int(ceil(f_rise / 0.2)))
				f_run = f_steps * TREAD
				f_span = f_run + LANDING * 2.0
			var edge_span := width if transverse else f_span
			if length < edge_span + 0.4:
				continue
			var edge_offset := edge_span * 0.5 + 0.2
			var samples := maxi(1, int(ceil((length - edge_span) / 0.2)))
			for sample in range(samples + 1):
				var boundary := a.lerp(b, (edge_offset + (length - edge_span - 0.4) \
					* float(sample) / samples) / length)
				# Stand clear of the coping's lip. Flush with the inner face,
				# the top landing and the lip shared one plane at walk height
				# and z-fought (walk-QA, Thorncliffe pin 6).
				boundary += inside * (CastleGeometry.wall_thickness(spec, ring) + CastleGeometry.WALK_LIP)
				if absf(side) > 0.1 and boundary.x * side <= 0.0:
					continue
				var axis := inside if transverse else along
				var across := -along if transverse else inside
				var at := boundary + inside * f_span * 0.5 + along * width * 0.5 if transverse else boundary
				var poly := PackedVector2Array([at - axis * f_span * 0.5,
					at + axis * f_span * 0.5, at + axis * f_span * 0.5 + across * width,
					at - axis * f_span * 0.5 + across * width])
				if not Array(poly).all(func(p): return Poly.contains_point(clear_ward, p, 0.01)):
					continue
				var footprint := Poly.bounding_rect(poly)
				if blocked.any(func(rect): return rect.grow(-0.001).intersects(footprint)):
					continue
				if tower_polygons.any(func(tower): return not Geometry2D.intersect_polygons(tower, poly).is_empty()):
					continue
				# The flight can be clear while its final step onto the curtain
				# crosses a projecting tower. Reserve that body corridor as well.
				var start_forward := -1.0 if transverse and f_count % 2 == 1 else 1.0
				# The foot must be walked up to from open ward. A stair along a
				# curtain may climb either way; on a polygon its foot can run
				# into the corner where the next curtain turns in. Take the
				# direction whose foot is clear, or skip the place.
				var lane0 := (f_count - 1) % 2
				var foot_across := across * (LANE * 0.5 + lane0 * (LANE + SPINE))
				var foot_ok := func(sf: float) -> bool:
					var foot: Vector2 = at + axis * (sf * (-f_span * 0.5 - 0.6)) + foot_across
					return Poly.contains_point(clear_ward, foot, 0.01) \
						and _edge_distance(clear_ward, foot) >= 0.5 \
						and not blocked.any(func(rect): return rect.has_point(foot))
				if not foot_ok.call(start_forward):
					if transverse or not foot_ok.call(-start_forward):
						continue
					start_forward = -start_forward
				var finish_forward := start_forward * (1.0 if f_count % 2 == 1 else -1.0)
				var arrival := at + axis * finish_forward * (f_run + LANDING) * 0.5 + across * LANE * 0.5
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
					"inside": across, "flights": f_count, "steps": f_steps, "rise": f_rise,
					"run": f_run, "span": f_span, "width": width, "height": height,
					"start_forward": start_forward, "transverse": transverse,
					"landing": LANDING, "poly": poly, "footprint": footprint}
	return best


static func _edge_distance(poly: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	for i in poly.size():
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])))
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
	var landing := float(stair.get("landing", LANDING))
	var transverse := bool(stair.get("transverse", false))
	var pier := 0.22
	_piece(out, "wall_stair_spine", Vector3(run, height, SPINE), Vector3(0, height * 0.5, LANE + SPINE * 0.5), stair)
	# Which long sides fall away to the ward. The far side (lane 1) always
	# does. Lane 0 stands against the curtain on a stair along it, but on a
	# transverse stair it is the other open side, and it had no guard for its
	# whole height (walk-QA, Thorncliffe pin 3).
	var guarded: Array[int] = [1]
	if transverse:
		guarded.append(0)
	for flight in int(stair.flights):
		var lane := (int(stair.flights) - 1 - flight) % 2
		var lane_at := LANE * 0.5 + lane * (LANE + SPINE)
		var guard_v := width - 0.06 if lane == 1 else 0.06
		var forward := (1.0 if flight % 2 == 0 else -1.0) * float(stair.get("start_forward", 1.0))
		var floor_y := flight * float(stair.rise)
		for step in int(stair.steps):
			var rise := float(stair.rise) * (step + 1) / int(stair.steps)
			var u := forward * (-run * 0.5 + (step + 0.5) * TREAD)
			_piece(out, "wall_stair_tread", Vector3(TREAD, rise, LANE),
				Vector3(u, floor_y + rise * 0.5, lane_at), stair)
			if lane in guarded and step % 3 == 0:
				_piece(out, "wall_stair_guard_post", Vector3(0.08, 0.9, 0.08),
					Vector3(u, floor_y + rise + 0.45, guard_v), stair)
		if lane in guarded:
			var slope := atan2(float(stair.rise), forward * run)
			_piece(out, "wall_stair_flight_rail", Vector3(Vector2(run, float(stair.rise)).length(), 0.09, 0.09),
				Vector3(0, floor_y + float(stair.rise) * 0.5 + 0.9, guard_v), stair,
				Basis(Vector3.BACK, slope))
		var level := floor_y + float(stair.rise)
		var end := forward * (run + landing) * 0.5
		var out_sign := signf(end)
		_piece(out, "wall_stair_landing", Vector3(landing, 0.2, width),
			Vector3(end, level - 0.1, width * 0.5), stair)
		# Side guards stop at the corner pier rather than sharing its outer
		# faces, which z-fought where they overlapped.
		for v_side in guarded:
			var v := width - RAIL_T * 0.5 if v_side == 1 else RAIL_T * 0.5
			var length := landing - (pier if v_side == 1 else 0.0)
			_piece(out, "wall_stair_landing_rail", Vector3(length, RAIL_H, RAIL_T),
				Vector3(end - out_sign * (landing - length) * 0.5, level + RAIL_H * 0.5, v), stair)
		# The landing's outer end is a drop too, except where it meets the
		# curtain: a transverse stair's curtain end (u < 0), where the walk is.
		# The inside edge of a stair along the curtain opens onto the coping at
		# the top landing, so no guard runs there.
		if not (transverse and out_sign < 0.0):
			var v0 := RAIL_T if transverse else 0.0
			var v1 := width - pier
			_piece(out, "wall_stair_end_rail", Vector3(RAIL_T, RAIL_H, v1 - v0),
				Vector3(out_sign * (span * 0.5 - RAIL_T * 0.5), level + RAIL_H * 0.5, (v0 + v1) * 0.5), stair)
	# The stair stands WALK_LIP clear of the curtain so its top landing does not
	# share the coping lip's plane. The gap is built up solid to the coping's
	# underside, so the stair bears on the wall and leaves no slot beside it.
	var lip: float = CastleGeometry.WALK_LIP
	var bear_h: float = height - CastleGeometry.PARAPET_RISE
	if transverse:
		_piece(out, "wall_stair_bearing", Vector3(lip, bear_h, width),
			Vector3(-span * 0.5 - lip * 0.5, bear_h * 0.5, width * 0.5), stair)
	else:
		_piece(out, "wall_stair_bearing", Vector3(span, bear_h, lip),
			Vector3(0.0, bear_h * 0.5, -lip * 0.5), stair)
	# The corner piers stand 2 cm inside the landings' edges and rise to rail
	# height as newels: flush, their faces and tops lay in the landings' planes.
	for side in [-1.0, 1.0]:
		_piece(out, "wall_stair_pier", Vector3(pier, height + RAIL_H, pier),
			Vector3(float(side) * (span * 0.5 - pier * 0.5 - PIER_INSET), (height + RAIL_H) * 0.5,
				width - pier * 0.5 - PIER_INSET), stair)
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
