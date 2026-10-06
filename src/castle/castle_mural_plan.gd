extends RefCounted
## Mural towers are occupied guardrooms, entered from the curtain walk.
## Their shared HousePlans own every floor, stair, doorway and window.

const THICKNESS := 0.6
## KeepSpec's storey limit; a tower plan may not declare more.
const MAX_TOWER_STOREYS := 8
## Shortest facet that takes a 1.2 m door and its jambs.
const DOOR_FACET := 1.56
## Curtain points beyond this from a tower door are searched only as a fallback.
const NEAR_REACH := 14.0


static var _geometry_cache := {}


static func records(spec: CastleSpec, geometry_only := false) -> Dictionary:
	if geometry_only:
		# Pure in the spec, asked for repeatedly by the stair planner.
		var key := CastleGeometry.spec_signature(spec)
		if not _geometry_cache.has(key):
			if _geometry_cache.size() >= 6:
				_geometry_cache.clear()
			_geometry_cache[key] = _records(spec, true)
		return _geometry_cache[key]
	return _records(spec, false)


static func _records(spec: CastleSpec, geometry_only: bool) -> Dictionary:
	var out := {}
	if not CastleGeometry.is_enclosed(spec):
		return out
	for ring in CastleGeometry.rings(spec):
		var corners := CastleGeometry.vertex_tower_centers(spec, ring)
		for i in range(corners.size()):
			_add(out, spec, ring, corners[i], "tower_%d_corner_%d" % [ring, i], i,
				geometry_only)
		var sides := CastleGeometry.side_tower_slots(spec, ring)
		for i in range(sides.size()):
			_add(out, spec, ring, sides[i].pos, "tower_%d_side_%d" % [ring, i], -1,
				geometry_only)
		var gates := CastleGeometry.gate_tower_centers(spec, ring)
		for i in range(gates.size()):
			_add(out, spec, ring, gates[i], "tower_%d_gate_%d" % [ring, i], -1,
				geometry_only)
	return out


static func _add(out: Dictionary, spec: CastleSpec, ring: int, centre: Vector3,
		id: String, vertex := -1, geometry_only := false) -> void:
	var bounds := CastleGeometry.tower_aabb(spec, ring, centre, vertex)
	var height := CastleGeometry.tower_height_at(spec, ring, vertex)
	var half := CastleGeometry.tower_half_at(spec, ring, vertex)
	var walk_y := CastleGeometry.wall_height(spec, ring) + CastleGeometry.PARAPET_RISE
	var levels := 2
	var entry := 1
	var score := INF
	# Keep the raised entrance within an ordinary step of the curtain walk.
	# All storeys still fit exactly under the existing tower cap.
	for count in range(2, 9):
		var storey_h := height / float(count)
		if storey_h < 2.4:
			continue
		var candidate := clampi(roundi((walk_y - HouseGeometry.FLOOR_T) / storey_h), 1, count - 1)
		var delta := absf(candidate * storey_h + HouseGeometry.FLOOR_T - walk_y)
		var cost := delta + absf(storey_h - 3.0) * 0.02
		if cost < score:
			score = cost
			levels = count
			entry = candidate
	# Uniform storeys may land the raised door more than a step off the coping
	# (battered Crusader towers: 0.61 m). Then fit the storey height to the
	# walk instead, and let the walls rise unbroken over any short last void.
	var storey_override := 0.0
	# Always align the door floor with the coping, which stands 0.25 m proud of
	# the wall: a sill a third of a metre below it leaves the walk slab across
	# the doorway (the door-clearance rays caught it on every polygon castle).
	if true:
		var gap := INF
		for fit_entry in range(1, 8):
			var fit_h := (walk_y - HouseGeometry.FLOOR_T) / float(fit_entry)
			if fit_h < 2.4 or fit_h > 7.0:
				continue
			var fit_levels := int(floor(height / fit_h + 0.001))
			if fit_levels <= fit_entry or fit_levels > MAX_TOWER_STOREYS:
				continue
			# A short void under the cap is harmless; thirty-centimetre storeys
			# or a dozen furnished rooms are not. Favour ordinary storey heights.
			var fit_gap := height - float(fit_levels) * fit_h + absf(fit_h - 3.5)
			if fit_gap < gap:
				gap = fit_gap
				levels = fit_levels
				entry = fit_entry
				storey_override = fit_h
	# A tower lower than the coping, or whose storeys cannot be fitted to it,
	# has no raised door that meets the walk. It is entered from the ward.
	var raised := absf(float(entry) * (storey_override if storey_override > 0.0
		else height / float(levels)) + HouseGeometry.FLOOR_T - walk_y) <= WalkGrid.MAX_STEP
	if not raised:
		entry = 0
		storey_override = 0.0
		levels = clampi(roundi(height / 3.4), 2, MAX_TOWER_STOREYS)
	var hs := KeepSpec.new(spec.seed ^ int(id.hash()))
	hs.material = &"stone"
	hs.style = &"townhouse"
	hs.width = half * 2.0
	hs.length = half * 2.0
	hs.height = storey_override if storey_override > 0.0 else height / float(levels)
	hs.storeys = levels
	hs.entry_storey = entry
	hs.room_count = levels
	hs.wall_thickness_override = THICKNESS
	hs.plinth_height = 0.0
	hs.porch = false
	hs.chimney = false
	hs.exterior_props = false
	hs.wall_color = spec.stone_color
	hs.trim_color = spec.trim_color
	hs.roof_color = spec.roof_color
	hs.floor_color = spec.stone_color.darkened(0.35)
	var plan := HousePlan.new()
	plan.spec = hs
	var outline := PackedVector2Array()
	var sides := coarse_sides(CastleGeometry.tower_sides(spec), half - THICKNESS)
	var rotation := PI / float(sides)
	var radius := (half - THICKNESS) / cos(PI / float(sides))
	for side in range(sides):
		var angle := rotation + TAU * float(side) / float(sides)
		outline.append(Vector2(cos(angle), sin(angle)) * radius)
	# A coarse outline (a hexagon has a vertex on its Y axis) can reach past the
	# tower's own square; the interior the tiling check measures must hold it.
	var probe := Poly.bounding_rect(outline)
	var reach := maxf(maxf(absf(probe.position.x), probe.end.x),
		maxf(absf(probe.position.y), probe.end.y))
	hs.width = maxf(hs.width, 2.0 * (reach + THICKNESS))
	hs.length = maxf(hs.length, 2.0 * (reach + THICKNESS))
	for level in range(levels):
		plan.rooms.append({"kind": &"guardroom", "rect": Poly.bounding_rect(outline),
			"outline": outline.duplicate(), "storey": level, "host": id})
		hs.program.append(&"guardroom")
	var access := {}
	if raised:
		access = _door(plan, spec, ring, centre, entry, vertex, id.contains("_gate_"))
	if raised and access.is_empty() and CastleGeometry.tower_sides(spec) > 4:
		_exact_towers = true
		access = _door(plan, spec, ring, centre, entry, vertex, id.contains("_gate_"))
		_exact_towers = false
	var ground := false
	if access.is_empty():
		# No clear gallery from the coping reaches this tower (a hexagon's
		# side vertex, say). Enter it at courtyard level instead, from the ward.
		access = _ground_door(plan, spec, ring, centre)
		ground = true
		hs.entry_storey = 0
		if access.is_empty():
			return
	plan.doors.append(access.door)
	if geometry_only:
		var access_row := {"id": id, "plan": plan, "bounds": bounds,
			"transform": Transform3D(Basis.IDENTITY, centre), "mural_tower": true,
			"ground_entry": ground,
			"walk_landing": access.landing, "walk_y": walk_y,
			"walk_target": access.target, "walk_outer": access.outer,
			"walk_inside": access.inside, "walk_route": access.route,
			"walk_gallery": access.gallery}
		out[id] = access_row
		return
	var previous := Rect2()
	for level in range(levels - 1):
		CastleKeepPlan._add_stair(plan, level, level + 1, previous)
		if not plan.stairs.is_empty():
			previous = plan.stairs[-1].upper_rect
	var toward := Vector2(centre.x, centre.z - CastleGeometry.enceinte_rect(spec, ring).get_center().y).normalized()
	for level in range(levels):
		# Facets that look away from the curtain first; a tower at a polygon's
		# side vertex may have none that are clear, so widen the net rather than
		# leave an occupied storey without daylight.
		for facing in [0.4, 0.0, -0.4]:
			var before := plan.windows.size()
			for wall in HouseGeometry.room_walls(plan, level):
				var normal := -Vector2(wall.normal)
				if normal.dot(toward) < facing:
					continue
				var opening := _window_on_wall(plan, level, wall, spec, ring, centre)
				if opening.is_empty():
					continue
				plan.windows.append({"room": level, "storey": level,
					"pos": opening.pos,
					"normal": normal, "width": opening.width,
					"sill": 0.95, "head": minf(hs.height - 0.3, 2.15), "host": id})
			if plan.windows.size() > before:
				break
	# A storey no window can reach (curtain masonry on every facet) is a store,
	# not a guardroom: nobody is posted where they cannot see out.
	for level in range(levels):
		var lit := false
		for window in plan.windows:
			if int(window.get("room", -1)) == level:
				lit = true
		if not lit:
			plan.rooms[level]["kind"] = &"store"
			hs.program[level] = &"store"
	CastleKeepPlan.furnish_minimum_programme(plan, hs)
	var row := {"id": id, "plan": plan, "bounds": bounds,
		"transform": Transform3D(Basis.IDENTITY, centre), "mural_tower": true,
		"ground_entry": ground,
		"walk_landing": access.landing, "walk_y": walk_y,
		"walk_target": access.target, "walk_outer": access.outer,
		"walk_inside": access.inside, "walk_route": access.route,
		"walk_gallery": access.gallery}
	out[id] = row


## A slender tower has facets too short for a doorway and its margins. Coarsen
## the plan (12, 8, 6, 4 sides) until a facet takes one; the shell is raised
## from this plan, so a six-sided turret really is six-sided.
static func coarse_sides(sides: int, clear: float) -> int:
	for candidate in [12, 8, 6, 4]:
		if candidate > sides:
			continue
		if 2.0 * clear * tan(PI / float(candidate)) >= DOOR_FACET:
			return candidate
	return 4


## A doorway at courtyard level on the facet that most nearly faces the ward.
static func _ground_door(plan: HousePlan, spec: CastleSpec, ring: int,
		centre: Vector3) -> Dictionary:
	var ward := CastleGeometry.enceinte_rect(spec, ring).get_center()
	var inward := (ward - Vector2(centre.x, centre.z)).normalized()
	var best := {}
	var score := -INF
	for wall in HouseGeometry.room_walls(plan, 0):
		var normal := -Vector2(wall.normal)
		var length := Vector2(wall.from).distance_to(wall.to)
		if length < DOOR_FACET:
			continue
		var candidate := normal.dot(inward)
		if candidate > score:
			score = candidate
			best = wall
	if best.is_empty() or score < 0.2:
		return {}
	var pos := (Vector2(best.from) + Vector2(best.to)) * 0.5
	var normal := -Vector2(best.normal)
	var width := minf(1.2, Vector2(best.from).distance_to(best.to) - 2.0 * 0.32)
	return {"door": {"a": 0, "b": -1, "pos": pos, "normal": normal, "width": width,
		"exterior": true, "front": true, "storey": 0, "sill": 0.0,
		"head": minf(plan.spec.height - 0.2, 2.35), "route": "courtyard"},
		"landing": Rect2(), "target": Vector2.ZERO, "outer": pos, "inside": pos,
		"route": [], "gallery": []}


static func _door(plan: HousePlan, spec: CastleSpec, ring: int, centre: Vector3,
		level: int, vertex := -1, gate_tower := false) -> Dictionary:
	var best := {}
	var score := INF
	var half_width := 0.6
	var ward_centre := CastleGeometry.enceinte_rect(spec, ring).get_center()
	var inward := (ward_centre - Vector2(centre.x, centre.z)).normalized()
	var desired := inward
	if gate_tower:
		desired = Vector2.LEFT if centre.x < 0.0 else Vector2.RIGHT
	var tower_bounds := CastleGeometry.tower_aabb(spec, ring, centre, vertex)
	for wall in HouseGeometry.room_walls(plan, level):
		var normal := -Vector2(wall.normal)
		var facing := 0.55 if vertex >= 0 else 0.25
		if normal.dot(desired) < facing:
			continue
		var a: Vector2 = wall.from
		var b: Vector2 = wall.to
		if a.distance_to(b) < 2.0 * (half_width + 0.18):
			continue
		var tangent := (b - a).normalized()
		for fraction in [0.25, 0.5, 0.75]:
			var along := clampf(a.distance_to(b) * fraction, half_width + 0.18,
				a.distance_to(b) - half_width - 0.18)
			var pos := a + tangent * along
			var local_world := Vector2(centre.x, centre.z)
			var door_world := local_world + pos
			var inside := door_world - normal * 0.35
			var outside := _beyond_tower(door_world, normal, tower_bounds)
			var route := _access_route(spec, ring, centre, tower_bounds, vertex,
				outside, inside)
			if route.is_empty():
				continue
			if vertex >= 0 and not CastleGeometry.enceinte_rect(spec, ring).grow(0.02).has_point(route[-1]):
				continue
			var distance := _route_length(route)
			if distance >= score:
				continue
			var corner_links: Array[Dictionary] = []
			if vertex >= 0:
				corner_links = _corner_gallery(spec, ring, centre, vertex, tower_bounds)
				if corner_links.is_empty():
					continue
			score = distance
			var target: Vector2 = route[-1]
			var landing := Rect2(outside - Vector2.ONE * 0.72, Vector2.ONE * 1.44)
			var gallery := _route_gallery(route)
			gallery.append_array(corner_links)
			best = {"door": {"a": level, "b": -1, "pos": pos,
				"normal": normal, "width": half_width * 2.0, "exterior": true,
				# The room's real floor slab supplies the threshold. A wall panel up
				# to FLOOR_T would rise above the coping when this storey is within a
				# small step of the wall-walk elevation.
				"front": true, "storey": level, "sill": 0.0,
				"head": minf(plan.spec.height - 0.2, 2.35), "route": "curtain_walk"},
				"landing": landing, "target": target, "outer": outside,
				"inside": inside, "route": route, "gallery": gallery}
	return best


## Start the route beyond the measured tower envelope. The doorway is on the
## room outline; a fixed shell-thickness offset can still leave a walker inside
## the broad, battered corner mass.
static func _beyond_tower(door: Vector2, normal: Vector2, bounds: AABB) -> Vector2:
	var point := door
	for _step in range(120):
		if not _tower_bounds_has(bounds, point, 0.9):
			return point
		point += normal * 0.1
	return point


static func _access_route(spec: CastleSpec, ring: int, centre: Vector3,
		tower_bounds: AABB, vertex: int, outside: Vector2, inside: Vector2) -> Array[Vector2]:
	# The shortest route is the one we keep, so look near the doorway first:
	# testing every 20 cm of a hundred-metre curtain made each side tower cost
	# seconds. Only if nothing near works is the whole curtain searched.
	var best_route: Array[Vector2] = []
	for reach in [NEAR_REACH, INF]:
		var candidates: Array[Vector2] = []
		if vertex >= 0:
			for link in _corner_targets(spec, ring, centre, vertex):
				candidates.append(link.target)
		else:
			for segment in CastleGeometry.wall_segments(spec, ring):
				var wall_out := Vector2(segment.outward.x, segment.outward.z)
				var offset := wall_out * CastleGeometry.wall_thickness(spec, ring) * 0.5
				var a: Vector2 = Vector2(segment.a) - offset
				var b: Vector2 = Vector2(segment.b) - offset
				var delta := b - a
				var steps := maxi(1, ceili(delta.length() / 0.2))
				for i in range(steps + 1):
					var point := a.lerp(b, float(i) / steps)
					if point.distance_to(outside) > reach:
						continue
					if not _tower_bounds_has(tower_bounds, point, 0.8):
						candidates.append(point)
		best_route = _best_route(spec, ring, centre, tower_bounds, outside, inside, candidates)
		if not best_route.is_empty() or vertex >= 0:
			break
	return best_route


static func _best_route(spec: CastleSpec, ring: int, centre: Vector3,
		tower_bounds: AABB, outside: Vector2, inside: Vector2,
		candidates: Array[Vector2]) -> Array[Vector2]:
	var best_route: Array[Vector2] = []
	var best_length := INF
	for target in candidates:
		var waypoints: Array[Vector2] = [outside, target]
		if _line_hits_tower(outside, target, tower_bounds, 0.8):
			var ward := (CastleGeometry.enceinte_rect(spec, ring).get_center()
				- Vector2(centre.x, centre.z)).normalized()
			var bend := outside + ward * 2.5
			var blocked := _line_hits_tower(outside, bend, tower_bounds, 0.8)
			if not blocked:
				blocked = _line_hits_tower(bend, target, tower_bounds, 0.8)
			if blocked:
				continue
			waypoints = [outside, bend, target]
		var route: Array[Vector2] = [inside]
		for point in waypoints:
			if route[-1].distance_to(point) > 0.02:
				route.append(point)
		var length := _route_length(route)
		if length < best_length:
			best_length = length
			best_route = route
	return best_route


## On a corner, the two curtain runs stop at the tower. Their coping centers
## are usable just past the actual base envelope, not at their shared vertex.
static func _corner_targets(spec: CastleSpec, ring: int, centre: Vector3,
		vertex: int) -> Array[Dictionary]:
	var segments := CastleGeometry.wall_segments(spec, ring)
	var tower_bounds := CastleGeometry.tower_aabb(spec, ring, centre, vertex)
	var vertex_point := Vector2(INF, INF)
	var nearest := INF
	for segment in segments:
		var endpoints: Array[Vector2] = [Vector2(segment.a), Vector2(segment.b)]
		for endpoint in endpoints:
			var d: float = endpoint.distance_squared_to(Vector2(centre.x, centre.z))
			if d < nearest:
				nearest = d
				vertex_point = endpoint
	var edge_best := {}
	for segment in segments:
		var edge := int(segment.edge)
		var endpoint := Vector2(segment.a) if Vector2(segment.a).distance_squared_to(vertex_point) \
				< Vector2(segment.b).distance_squared_to(vertex_point) else Vector2(segment.b)
		var d := endpoint.distance_to(vertex_point)
		if d > 0.01:
			continue
		if not edge_best.has(edge) or d < float(edge_best[edge].distance):
			edge_best[edge] = {"segment": segment, "endpoint": endpoint, "distance": d}
	var candidates: Array[Dictionary] = []
	for row in edge_best.values():
		var segment: Dictionary = row.segment
		var endpoint: Vector2 = row.endpoint
		var other: Vector2 = Vector2(segment.b) if endpoint == Vector2(segment.a) else Vector2(segment.a)
		var tangent := (other - endpoint).normalized()
		var wall_out := Vector2(segment.outward.x, segment.outward.z)
		var target := Vector2(INF, INF)
		var found := false
		var steps := maxi(1, ceili(endpoint.distance_to(other) / 0.05))
		for i in range(1, steps + 1):
			var along := endpoint.distance_to(other) * float(i) / float(steps)
			var sample := endpoint + tangent * along \
				- wall_out * CastleGeometry.wall_thickness(spec, ring) * 0.5
			if not _tower_bounds_has(tower_bounds, sample, 1.0):
				target = sample
				found = true
				break
		if found:
			candidates.append({"target": target, "inward": -wall_out, "edge": int(segment.edge)})
	return candidates


## A joined L-shaped gallery carries the coping round the ward-side face of a
## corner tower. The short returns land on both true wall-top surfaces.
static func _corner_gallery(spec: CastleSpec, ring: int, centre: Vector3,
		vertex: int, tower_bounds: AABB) -> Array[Dictionary]:
	var links := _corner_targets(spec, ring, centre, vertex)
	if links.size() < 2:
		return []
	var first: Dictionary = links[0]
	var second: Dictionary = links[1]
	var width := 1.4
	var reach := width * 0.5 + CastleGeometry.wall_thickness(spec, ring) * 0.5 + 0.25
	var a: Vector2 = first.target + Vector2(first.inward) * reach
	var b: Vector2 = second.target + Vector2(second.inward) * reach
	var elbows := [Vector2(a.x, b.y), Vector2(b.x, a.y)]
	var elbow := Vector2(INF, INF)
	for candidate in elbows:
		if not _line_hits_tower(a, candidate, tower_bounds, 0.8) \
				and not _line_hits_tower(candidate, b, tower_bounds, 0.8):
			elbow = candidate
			break
	if elbow.x == INF:
		return []
	var out: Array[Dictionary] = []
	var pairs := [[first.target, a], [a, elbow], [elbow, b], [b, second.target]]
	for pair_index in range(pairs.size()):
		var pair: Array = pairs[pair_index]
		var start: Vector2 = pair[0]
		var finish: Vector2 = pair[1]
		if _line_hits_tower(start, finish, tower_bounds, 0.8):
			return []
		if start.distance_to(finish) > 0.03:
			out.append({"a": start, "b": finish, "width": width, "guarded": true,
				"open_start": pair_index == 0, "open_end": pair_index == pairs.size() - 1})
	return out


static func _route_gallery(route: Array[Vector2]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(1, route.size()):
		var a: Vector2 = route[i - 1]
		var b: Vector2 = route[i]
		if a.distance_to(b) > 0.03:
			out.append({"a": a, "b": b, "width": 1.4})
	return out


static func _route_length(route: Array[Vector2]) -> float:
	var length := 0.0
	for i in range(1, route.size()):
		length += route[i - 1].distance_to(route[i])
	return length


## Whether `point` is within `grow` of the tower. The measured envelope is the
## base square; a faceted tower occupies a circle inside it, and at a polygon's
## side vertex the square's empty corners hide every route. `_exact_towers`
## (second pass only, so existing routes never move) uses the circle.
static var _exact_towers := false


static func _tower_bounds_has(bounds: AABB, point: Vector2, grow: float) -> bool:
	if _exact_towers:
		var centre := Vector2(bounds.get_center().x, bounds.get_center().z)
		return centre.distance_to(point) <= bounds.size.x * 0.5 * 1.04 + grow
	return Rect2(bounds.position.x, bounds.position.z, bounds.size.x,
		bounds.size.z).grow(grow).has_point(point)


static func _line_hits_tower(a: Vector2, b: Vector2, bounds: AABB, grow: float) -> bool:
	var count := maxi(1, ceili(a.distance_to(b) / 0.08))
	for i in range(1, count):
		if _tower_bounds_has(bounds, a.lerp(b, float(i) / count), grow):
			return true
	return false


static func _window_on_wall(plan: HousePlan, level: int, wall: Dictionary,
		spec: CastleSpec, ring: int, centre: Vector3) -> Dictionary:
	var a := Vector2(wall.from)
	var edge := Vector2(wall.to) - a
	var normal := -Vector2(wall.normal)
	for width in [1.1, 0.6]:
		var margin: float = width * 0.5 + 0.25
		if edge.length() < margin * 2.0:
			continue
		var fractions: Array[float] = [0.5, 0.0, 1.0]
		var samples := maxi(1, ceili((edge.length() - margin * 2.0) / 0.1))
		for i in range(1, samples):
			fractions.append(float(i) / float(samples))
		for fraction in fractions:
			var along := lerpf(margin, edge.length() - margin, fraction)
			var pos := a + edge.normalized() * along
			if _window_clear(plan, level, pos, normal, width) \
					and _window_curtain_clear(spec, ring, centre, pos, normal, width,
						level * plan.spec.height + 0.95):
				return {"pos": pos, "width": width}
	return {}


static func _window_curtain_clear(spec: CastleSpec, ring: int, centre: Vector3,
		pos: Vector2, normal: Vector2, width: float, bottom: float) -> bool:
	if bottom > CastleGeometry.wall_height(spec, ring) + CastleGeometry.PARAPET_RISE + spec.merlon_h:
		return true
	var tangent := Vector2(-normal.y, normal.x)
	for segment in CastleGeometry.wall_segments(spec, ring):
		var wall := CastleGeometry.segment_aabb(spec, ring, segment)
		for side in [-0.6, 0.0, 0.6]:
			var sample: Vector2 = pos + normal * (THICKNESS + 0.1) + tangent * width * side
			var point := centre + Vector3(sample.x, bottom, sample.y)
			if wall.grow(0.05).has_point(point):
				return false
	return true


static func _window_clear(plan: HousePlan, level: int, pos: Vector2,
		normal: Vector2, width: float) -> bool:
	var tangent := Vector2(-normal.y, normal.x)
	# A clear window ray is insufficient if its surround crosses a doorway.
	# Reserve both opening intervals and the intervening masonry before choosing
	# a window, including the raised entrance on a gate tower's outer flank.
	for door in plan.doors:
		if HousePlan.record_storey(door) != level or not door.get("exterior", false):
			continue
		if Vector2(door.normal).dot(normal) < 0.99:
			continue
		var delta := pos - Vector2(door.pos)
		if absf(delta.dot(normal)) < 0.05 \
				and absf(delta.dot(tangent)) < (width + float(door.width)) * 0.5 + 0.25:
			return false
	for stair in plan.stairs:
		if level != int(stair.storey) and level != int(stair.to_storey):
			continue
		var rect := Rect2(stair.get("rect", Rect2())).grow(0.15)
		for side in [-0.5, 0.0, 0.5]:
			if rect.has_point(pos - normal * 0.45 + tangent * width * side):
				return false
	return true
