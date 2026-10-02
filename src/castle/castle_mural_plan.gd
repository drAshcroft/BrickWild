extends RefCounted
## Mural towers are occupied guardrooms, entered from the curtain walk.
## Their shared HousePlans own every floor, stair, doorway and window.

const THICKNESS := 0.6


static func records(spec: CastleSpec) -> Dictionary:
	var out := {}
	if not CastleGeometry.is_motte(spec):
		return out
	for ring in CastleGeometry.rings(spec):
		var corners := CastleGeometry.vertex_tower_centers(spec, ring)
		for i in range(corners.size()):
			_add(out, spec, ring, corners[i], "tower_%d_corner_%d" % [ring, i], i)
		var sides := CastleGeometry.side_tower_slots(spec, ring)
		for i in range(sides.size()):
			_add(out, spec, ring, sides[i].pos, "tower_%d_side_%d" % [ring, i])
		var gates := CastleGeometry.gate_tower_centers(spec, ring)
		for i in range(gates.size()):
			_add(out, spec, ring, gates[i], "tower_%d_gate_%d" % [ring, i])
	return out


static func _add(out: Dictionary, spec: CastleSpec, ring: int, centre: Vector3,
		id: String, vertex := -1) -> void:
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
	var hs := KeepSpec.new(spec.seed ^ int(id.hash()))
	hs.material = &"stone"
	hs.style = &"townhouse"
	hs.width = half * 2.0
	hs.length = half * 2.0
	hs.height = height / float(levels)
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
	var sides := CastleGeometry.tower_sides(spec)
	var rotation := CastleGeometry.tower_rotation(spec)
	var radius := (half - THICKNESS) / cos(PI / float(sides))
	for side in range(sides):
		var angle := rotation + TAU * float(side) / float(sides)
		outline.append(Vector2(cos(angle), sin(angle)) * radius)
	for level in range(levels):
		plan.rooms.append({"kind": &"guardroom", "rect": Poly.bounding_rect(outline),
			"outline": outline.duplicate(), "storey": level, "host": id})
		hs.program.append(&"guardroom")
	var access := _door(plan, spec, ring, centre, entry)
	if access.is_empty():
		return
	plan.doors.append(access.door)
	var previous := Rect2()
	for level in range(levels - 1):
		CastleKeepPlan._add_stair(plan, level, level + 1, previous)
		if not plan.stairs.is_empty():
			previous = plan.stairs[-1].upper_rect
	var toward := Vector2(centre.x, centre.z - CastleGeometry.enceinte_rect(spec, ring).get_center().y).normalized()
	for level in range(levels):
		for wall in HouseGeometry.room_walls(plan, level):
			var normal := -Vector2(wall.normal)
			if normal.dot(toward) < 0.4:
				continue
			var opening := _window_on_wall(plan, level, wall, spec, ring, centre)
			if opening.is_empty():
				continue
			plan.windows.append({"room": level, "storey": level,
				"pos": opening.pos,
				"normal": normal, "width": opening.width,
				"sill": 0.95, "head": minf(hs.height - 0.3, 2.15), "host": id})
	CastleKeepPlan.furnish_minimum_programme(plan, hs)
	var row := {"id": id, "plan": plan, "bounds": bounds,
		"transform": Transform3D(Basis.IDENTITY, centre), "mural_tower": true,
		"walk_landing": access.landing, "walk_y": walk_y,
		"walk_target": access.target, "walk_outer": access.outer}
	out[id] = row


static func _door(plan: HousePlan, spec: CastleSpec, ring: int, centre: Vector3,
		level: int) -> Dictionary:
	var best := {}
	var score := INF
	var half_width := 0.6
	var ward_centre := CastleGeometry.enceinte_rect(spec, ring).get_center()
	var inward := (ward_centre - Vector2(centre.x, centre.z)).normalized()
	for wall in HouseGeometry.room_walls(plan, level):
		var normal := -Vector2(wall.normal)
		if normal.dot(inward) < 0.2:
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
			var outside := pos + normal * (THICKNESS + 0.35) + Vector2(centre.x, centre.z)
			for segment in CastleGeometry.wall_segments(spec, ring):
				var wall_out := Vector2(segment.outward.x, segment.outward.z)
				var offset := wall_out * CastleGeometry.wall_thickness(spec, ring) * 0.5
				var on_walk := Geometry2D.get_closest_point_to_segment(outside,
					Vector2(segment.a) - offset, Vector2(segment.b) - offset)
				var distance := outside.distance_to(on_walk)
				if distance >= score:
					continue
				score = distance
				var landing := Rect2(outside - Vector2.ONE * 0.72, Vector2.ONE * 1.44)
				landing = landing.expand(on_walk - Vector2.ONE * 0.6).expand(on_walk + Vector2.ONE * 0.6)
				best = {"door": {"a": level, "b": -1, "pos": pos,
					"normal": normal, "width": half_width * 2.0, "exterior": true,
					"front": true, "storey": level, "sill": HouseGeometry.FLOOR_T,
					"head": minf(plan.spec.height - 0.2, 2.35), "route": "curtain_walk"},
					"landing": landing, "target": on_walk, "outer": outside}
	return best


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
	for stair in plan.stairs:
		if level != int(stair.storey) and level != int(stair.to_storey):
			continue
		var rect := Rect2(stair.get("rect", Rect2())).grow(0.15)
		for side in [-0.5, 0.0, 0.5]:
			if rect.has_point(pos - normal * 0.45 + tangent * width * side):
				return false
	return true
