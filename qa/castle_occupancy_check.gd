class_name CastleOccupancyCheck
extends RefCounted
## Occupied structures must exist independently of the records they supply.
## The occupied inventory comes from the site specification, never interiors.
## Every supplied interior is then checked against the final combined mesh.


## Share of in-polygon samples that must have emitted floor and headroom.
const ROOM_FLOOR_MIN_FRACTION := 0.5


static func expected_ids(spec: CastleSpec) -> Array[String]:
	var ids: Array[String] = []
	if CastleGeometry.is_tower_house(spec):
		ids.append("tower_house")
		for index in CastleGeometry.tower_jog_aabbs(spec).size():
			ids.append("wing_jog_%d" % index)
		return ids
	if CastleGeometry.is_sky(spec):
		for index in CastleGeometry.sky_towers(spec).size():
			ids.append("sky_tower_%d" % index)
		return ids
	if CastleGeometry.is_ridge(spec):
		for segment in CastleGeometry.ridge_ranges(spec):
			ids.append(String(segment.name))
		var spire_vertex: int = CastleGeometry.spine(spec).size() / 2
		for index in CastleGeometry.ridge_tower_centers(spec).size():
			if spec.style != &"dark" or index != spire_vertex:
				ids.append("tower_0_corner_%d" % index)
		if spec.style == &"dark" and spec.keep:
			ids.append("keep")
		return ids
	if not CastleGeometry.is_enclosed(spec):
		ids.append("hall")
		if spec.tier == &"house":
			if CastleGeometry.annexe_aabb(spec).size.x > 0.0:
				ids.append("annexe")
		else:
			for side in CastleGeometry.wing_sides(spec):
				ids.append("wing_%s" % ("left" if side < 0.0 else "right"))
			if CastleGeometry.manor_front_range_aabb(spec).size.x > 0.0:
				ids.append("range_front")
			for index in CastleGeometry.manor_tower_centers(spec).size():
				ids.append("tower_manor_%d" % index)
		return ids
	if CastleGeometry.is_motte(spec):
		ids.append("keep_shell")
	if spec.keep and CastleGeometry.keep_aabb(spec).size.x > 0.0:
		ids.append("keep")
	if CastleGeometry.hall_aabb(spec).size.x > 0.0:
		ids.append("hall")
	if CastleGeometry.chapel_aabb(spec).size.x > 0.0:
		ids.append("chapel")
	if CastleGeometry.apse_aabb(spec).size.x > 0.0:
		ids.append("apse")
	for entry in CastleGenerator.bailey_buildings(spec):
		ids.append("yard_" + String(entry.business))
	for ring in CastleGeometry.rings(spec):
		if CastleGeometry.gatehouse_aabb(spec, ring).size.x > 0.0:
			ids.append("gate_%d" % ring)
		for index in CastleGeometry.vertex_tower_centers(spec, ring).size():
			ids.append("tower_%d_corner_%d" % [ring, index])
		for index in CastleGeometry.side_tower_slots(spec, ring).size():
			ids.append("tower_%d_side_%d" % [ring, index])
		for index in CastleGeometry.gate_tower_centers(spec, ring).size():
			ids.append("tower_%d_gate_%d" % [ring, index])
	return ids


static func check(spec: CastleSpec, builder: CastleBuilder, mesh: ArrayMesh,
		geometry: Dictionary = {}) -> Dictionary:
	var out := {"ok": true, "failures": [], "warnings": [], "stats": {
		"required_buildings": 0, "recorded_buildings": builder.interiors.size(),
		"rooms": 0, "exterior_doors": 0, "windows": 0, "door_rays": 0,
		"room_floor_samples": 0,
		"inventory_scope": "spec_and_geometry", "family": String(spec.plan_kind),
		"unplanned_window_hosts": []}}
	var expected := expected_ids(spec)
	if mesh == null or mesh.get_surface_count() == 0:
		_fail(out, "castle", "occupied structures have no emitted mesh")
	out.stats.required_buildings = expected.size()
	out.stats["required_ids"] = expected
	var records := {}
	for row in builder.interiors:
		var id := String(row.get("id", ""))
		if records.has(id):
			_fail(out, id, "duplicate occupied building record")
		records[id] = row
	for id in expected:
		if not records.has(id):
			_fail(out, id, "required occupied building has no interior record")
	if geometry.is_empty():
		geometry = prepare_mesh(mesh)
	for id in records:
		_check_record(out, String(id), records[id], builder, geometry)
	for part in builder.part_log:
		if String(part.get("kind", "")) != "window":
			continue
		var id := String(part.get("tag", ""))
		if records.has(id):
			_check_emitted_window(out, id, records[id], part, geometry)
		elif not id in out.stats.unplanned_window_hosts:
			out.stats.unplanned_window_hosts.append(id)
			# Arrow slits in an open curtain serve its fighting platform. Every
			# window on a building still needs a room, even when the legacy tag
			# is a generic family name such as "range", "wing" or "tower".
			if id != "curtain":
				_fail(out, id, "building window host has no occupied interior record")
	out.ok = out.failures.is_empty()
	return out


static func _check_record(out: Dictionary, id: String, row: Dictionary,
		builder: CastleBuilder, geometry: Dictionary) -> void:
	var plan: HousePlan = row.get("plan")
	if plan == null or plan.spec == null or plan.rooms.is_empty():
		_fail(out, id, "occupied building has no rooms")
		return
	if not row.get("transform") is Transform3D:
		_fail(out, id, "occupied building has no world transform")
		return
	out.stats.rooms += plan.rooms.size()
	for room in plan.rooms.size():
		_check_room_floor(out, id, row, room, geometry)
	var exterior := 0
	for door in plan.doors:
		if not bool(door.get("exterior", false)):
			continue
		exterior += 1
		out.stats.exterior_doors += 1
		var room := int(door.get("a", -1))
		if room < 0 or room >= plan.rooms.size():
			_fail(out, id, "exterior door has no destination room")
			continue
		var opening := _pose(plan, row.transform, door, room, true)
		if float(opening.width) < HouseGeometry.PATH_MIN or float(opening.height) < 1.85:
			_fail(out, id, "exterior entrance cannot fit a standing person")
		if not _backed_by_room(plan, room, door):
			_fail(out, id, "exterior door faces no occupied room")
		var found := false
		for part in builder.part_log:
			if String(part.get("tag", "")) == id \
					and String(part.get("opening_kind", "")) == "door" \
					and _matches(opening, part):
				found = true
				break
		if not found:
			_fail(out, id, "exterior door has no matching emitted aperture")
		_check_door_mesh(out, id, opening, geometry)
	if exterior == 0:
		_fail(out, id, "occupied building has no exterior entrance")
	for window in plan.windows:
		var room := int(window.get("room", -1))
		if room < 0 or room >= plan.rooms.size() or not _backed_by_room(plan, room, window):
			_fail(out, id, "planned window faces no occupied room")
			continue
		var opening := _pose(plan, row.transform, window, room, false)
		var found := false
		for part in builder.part_log:
			if String(part.get("tag", "")) == id \
					and String(part.get("opening_kind", "")) == "window" \
					and _matches(opening, part):
				found = true
				break
		if not found:
			_fail(out, id, "planned window has no matching emitted aperture")


## Blind rooms still require emitted occupied floor. Do not let window count
## decide whether a cellar, guardroom or a removed whole floor is inspected.
static func _check_room_floor(out: Dictionary, id: String, row: Dictionary,
		room: int, geometry: Dictionary) -> void:
	var plan: HousePlan = row.plan
	var polygon := HouseGeometry.room_floor_poly(plan, room)
	var rect := Poly.bounding_rect(polygon)
	var storey := plan.storey_of_room(room)
	var floor_y := float(storey) * plan.spec.height
	var xf: Transform3D = row.transform
	# Stair wells are real holes in a floor, and a dais is a real step up. A
	# sample inside either is judged against what the plan says is there: the
	# well is not floor to be missed, the dais is floor a step higher.
	var wells: Array[Rect2] = []
	for stair in plan.stairs:
		if int(stair.get("storey", -1)) == storey:
			wells.append(Rect2(stair.get("lower_rect", stair.get("rect", Rect2()))).grow(0.1))
		if int(stair.get("to_storey", -1)) == storey:
			wells.append(Rect2(stair.get("upper_rect", stair.get("rect", Rect2()))).grow(0.1))
	var samples: Array[Vector3] = []
	var bounds := AABB(xf * Vector3(rect.position.x, floor_y, rect.position.y), Vector3.ZERO)
	var in_wells := 0
	for u in range(1, 6):
		for v in range(1, 6):
			var point := rect.position + rect.size * Vector2(float(u) / 6.0, float(v) / 6.0)
			if not Poly.contains_point(polygon, point, 0.01):
				continue
			var within_well := false
			for well in wells:
				if well.has_point(point):
					within_well = true
					break
			if within_well:
				in_wells += 1
				continue
			var level := floor_y + (plan.dais_rise() if plan.on_dais(room, point) else 0.0)
			var world := xf * Vector3(point.x, level, point.y)
			samples.append(world)
			bounds = bounds.expand(world - Vector3.UP * 0.3).expand(world + Vector3.UP * 1.9)
	var nearby: Array = []
	for triangle in _nearby(geometry, bounds.grow(0.01)):
		if int(triangle.surface) not in [CastleBuilder.SURF_OPEN, CastleBuilder.SURF_GROUND]:
			nearby.append(triangle)
	var supported := 0
	for point in samples:
		out.stats.room_floor_samples += 1
		var floored := _hits(nearby, point + Vector3.UP * 0.10, point - Vector3.UP * 0.30)
		if floored and not _hits(nearby, point + Vector3.UP * 0.15, point + Vector3.UP * 1.85):
			supported += 1
	var fraction := float(supported) / float(maxi(1, samples.size()))
	out.stats.min_room_floor_fraction = minf(float(out.stats.get("min_room_floor_fraction", 1.0)), fraction)
	# One surviving stair landing must not stand in for a floor: outside the
	# wells and the dais, at least half the room has to be somewhere to stand.
	if samples.is_empty() or fraction < ROOM_FLOOR_MIN_FRACTION:
		_fail(out, id, "room %d has no emitted floor with standing clearance" % room)
		# The counts stay out of the message: callers match it exactly.
		out.stats["floor_shortfalls"] = out.stats.get("floor_shortfalls", []) + [
			"%s room %d: %d of %d samples supported, %d in stair wells"
			% [id, room, supported, samples.size(), in_wells]]


## Windows are matched in both directions: a valid plan cannot excuse an
## extra facade opening that has no room, or one turned away from its room.
static func _check_emitted_window(out: Dictionary, id: String, row: Dictionary,
		part: Dictionary, geometry: Dictionary) -> void:
	var plan: HousePlan = row.get("plan")
	if plan == null or plan.spec == null:
		return
	out.stats.windows += 1
	for window in plan.windows:
		var room := int(window.get("room", -1))
		if room < 0 or room >= plan.rooms.size():
			continue
		if _backed_by_room(plan, room, window) \
				and _matches(_pose(plan, row.transform, window, room, false), part):
			_check_window_mesh(out, id, row, room, window, part, geometry)
			return
	_fail(out, id, "emitted window at %s faces no matching occupied room" % part.get("pos", Vector3.ZERO))


static func _check_window_mesh(out: Dictionary, id: String, row: Dictionary,
		room: int, window: Dictionary, part: Dictionary, geometry: Dictionary) -> void:
	var plan: HousePlan = row.plan
	var xf: Transform3D = row.transform
	var normal := Vector3(part.facing).normalized()
	var tangent := Vector3(normal.z, 0, -normal.x)
	var centre: Vector3 = part.pos
	var thickness := float(plan.rooms[room].get("wall_thickness", HouseGeometry.wall_thickness(plan.spec)))
	var floor_y := float(plan.storey_of_room(room)) * plan.spec.height
	var local_normal := Vector2(window.normal).normalized()
	var local_tangent := Vector2(-local_normal.y, local_normal.x)
	var samples: Array[Vector3] = []
	var query := AABB(centre, Vector3.ZERO)
	var polygon := HouseGeometry.room_floor_poly(plan, room)
	var sample_count := maxi(1, int(ceil(Poly.bounding_rect(polygon).size.length() / 0.5)))
	for step in sample_count:
		var depth := 0.35 + float(step) * 0.5
		for side in [-0.25, 0.0, 0.25]:
			var point := Vector2(window.pos) - local_normal * depth \
				+ local_tangent * float(window.width) * float(side)
			if not Poly.contains_point(polygon, point, 0.01):
				continue
			var world := xf * Vector3(point.x, floor_y, point.y)
			samples.append(world)
			query = query.expand(world - Vector3.UP * 0.3).expand(world + Vector3.UP * 1.9)
	query = query.expand(centre + normal * (thickness + 0.1)).expand(centre - normal * (thickness + 0.1)).grow(0.1)
	var nearby: Array = []
	for triangle in _nearby(geometry, query):
		if int(triangle.surface) not in [CastleBuilder.SURF_OPEN, CastleBuilder.SURF_GROUND]:
			nearby.append(triangle)
	var floor_backed := false
	for point in samples:
		if _hits(nearby, point + Vector3.UP * 0.10, point - Vector3.UP * 0.30) \
				and not _hits(nearby, point + Vector3.UP * 0.15, point + Vector3.UP * 1.85) \
				and not _hits(nearby, centre - normal * (thickness * 0.5 + 0.08),
					Vector3(point.x, centre.y, point.z)):
			floor_backed = true
			break
	if not floor_backed:
		_fail(out, id, "window at %s has no emitted floor-backed occupied volume" % centre)
	# Four off-centre rays avoid a legitimate central mullion but reject a
	# decorative pane glued over an uncut wall. Glazing itself is transparent.
	var width := float(window.width)
	var height := float(window.head) - float(window.sill)
	for side in [-0.25, 0.25]:
		for rise in [-0.25, 0.25]:
			var point := centre + tangent * width * float(side) + Vector3.UP * height * float(rise)
			if _hits(nearby, point - normal * (thickness * 0.5 + 0.08),
					point + normal * (thickness * 0.5 + 0.08)):
				_fail(out, id, "window at %s has masonry filling its emitted aperture" % centre)
				return


static func _hits(triangles: Array, from: Vector3, to: Vector3) -> bool:
	for triangle in triangles:
		if Geometry3D.segment_intersects_triangle(from, to, triangle.a, triangle.b, triangle.c) != null:
			return true
	return false


static func _backed_by_room(plan: HousePlan, room: int, opening: Dictionary) -> bool:
	if room < 0 or room >= plan.rooms.size():
		return false
	var level := int(opening.get("storey", plan.storey_of_room(room)))
	if level != plan.storey_of_room(room):
		return false
	var point := Vector2(opening.get("pos", Vector2.ZERO))
	var normal := Vector2(opening.get("normal", Vector2.ZERO))
	if normal.length_squared() < 0.9:
		return false
	var tangent := Vector2(-normal.y, normal.x).normalized()
	var half := float(opening.get("width", 0.0)) * 0.5
	if half <= 0.0:
		return false
	var on_wall := false
	for wall in HouseGeometry.room_walls(plan, room):
		var a: Vector2 = wall.from
		var z: Vector2 = wall.to
		var nearest := Geometry2D.get_closest_point_to_segment(point, a, z)
		if nearest.distance_to(point) <= 0.08 \
				and -Vector2(wall.normal).dot(normal.normalized()) >= 0.99:
			on_wall = true
			break
	if not on_wall:
		return false
	var polygon := HouseGeometry.room_floor_poly(plan, room)
	# A point on the facade must have room floor behind its entire clear span.
	# This also rejects a window rotated to face an unrelated empty volume.
	for side in [-0.8, 0.0, 0.8]:
		if not Poly.contains_point(polygon, point - normal * 0.12 + tangent * half * float(side), 0.03):
			return false
	var sill := float(opening.get("sill", 0.0))
	var head := float(opening.get("head", HouseGeometry.DOOR_H))
	return sill >= -0.01 and head > sill and head <= plan.spec.height + 0.01


static func _pose(plan: HousePlan, transform: Transform3D, opening: Dictionary,
		room: int, door: bool) -> Dictionary:
	var normal := Vector2(opening.normal).normalized()
	var thickness := float(plan.rooms[room].get("wall_thickness", HouseGeometry.wall_thickness(plan.spec)))
	var point := Vector2(opening.pos)
	var level := int(opening.get("storey", plan.storey_of_room(room)))
	var bottom := float(opening.get("sill", 0.0 if door else 1.0))
	var top := float(opening.get("head", HouseGeometry.DOOR_H))
	var y := float(level) * plan.spec.height + (bottom + top) * 0.5
	return {"pos": transform * Vector3(point.x, y, point.y),
		"facing": (transform.basis * Vector3(normal.x, 0, normal.y)).normalized(),
		"width": float(opening.width), "height": top - bottom, "thickness": thickness,
		"floor_y": (transform * Vector3(point.x,
			float(level) * plan.spec.height + HouseGeometry.FLOOR_T, point.y)).y}


static func _matches(opening: Dictionary, part: Dictionary) -> bool:
	var normal: Vector3 = opening.facing
	if normal.dot(Vector3(part.get("facing", Vector3.ZERO))) < 0.99:
		return false
	var delta := Vector3(part.get("pos", Vector3.ZERO)) - Vector3(opening.pos)
	var along_normal := delta.dot(normal)
	# Plans name the inner wall face; emitted records name its centreline.
	# Rectangular and polygon shells can therefore differ by half a wall.
	if absf(along_normal) > float(opening.thickness) * 0.5 + 0.06:
		return false
	if (delta - normal * along_normal).length() > 0.06:
		return false
	var size := Vector3(part.get("size", Vector3.ZERO))
	return absf(size.x - float(opening.width)) < 0.06 and absf(size.y - float(opening.height)) < 0.06


static func _check_door_mesh(out: Dictionary, id: String, opening: Dictionary,
		geometry: Dictionary) -> void:
	var normal: Vector3 = opening.facing
	var tangent := Vector3(normal.z, 0.0, -normal.x)
	var centre: Vector3 = opening.pos
	var reach := float(opening.thickness) + 0.20
	var half_width := maxf(0.0, float(opening.width) * 0.5 - 0.12)
	var aperture_bottom := centre.y - float(opening.height) * 0.5
	var aperture_top := centre.y + float(opening.height) * 0.5
	var nominal_floor := float(opening.floor_y)
	var support_bounds := AABB(centre - Vector3.ONE * (reach + half_width),
		Vector3.ONE * (reach + half_width) * 2.0)
	support_bounds.position.y = nominal_floor - 0.31
	support_bounds.size.y = 0.62
	var support := _nearby(geometry, support_bounds)
	var floor_y := nominal_floor
	# The aperture may start below the occupied floor, and an exterior gallery
	# may meet it with an ordinary step. Measure that real threshold; rays below
	# its top are testing the floor's side, not a standing person's clearance.
	for across in [-half_width, 0.0, half_width]:
		for depth in [-reach, 0.0, reach]:
			var foot: Vector3 = centre + tangent * float(across) + normal * float(depth)
			for triangle in support:
				var upward: Vector3 = (triangle.c - triangle.a).cross(triangle.b - triangle.a).normalized()
				if upward.y < 0.9:
					continue
				var hit: Variant = Geometry3D.segment_intersects_triangle(
					Vector3(foot.x, nominal_floor + 0.3, foot.z),
					Vector3(foot.x, nominal_floor - 0.3, foot.z), triangle.a, triangle.b, triangle.c)
				if hit != null:
					floor_y = maxf(floor_y, Vector3(hit).y)
	if aperture_top - maxf(aperture_bottom, floor_y) < 1.85:
		_fail(out, id, "exterior entrance has insufficient standing height above its emitted threshold")
		return
	var low := maxf(aperture_bottom, floor_y) + 0.15
	var high := aperture_top - 0.15
	var bounds := AABB(centre, Vector3.ZERO)
	for across in [-half_width, half_width]:
		for height in [low, high]:
			for depth in [-reach, reach]:
				var point: Vector3 = centre + tangent * across + normal * depth
				point.y = height
				bounds = bounds.expand(point)
	var nearby := _nearby(geometry, bounds.grow(0.001))
	for across in [-half_width, 0.0, half_width]:
		for height in [low, (low + high) * 0.5, high]:
			var point: Vector3 = centre + tangent * float(across)
			point.y = height
			out.stats.door_rays += 1
			for triangle in nearby:
				if Geometry3D.segment_intersects_triangle(point - normal * reach, point + normal * reach,
						triangle.a, triangle.b, triangle.c) != null:
					_fail(out, id, "final mesh blocks exterior door clearance at %s" % point)
					return


## An immutable cache may be reused only while the mesh remains unchanged.
## XZ bins keep the gate bounded even when a castle has hundreds of windows.
static func prepare_mesh(mesh: ArrayMesh) -> Dictionary:
	var out := {"triangles": [], "cells": {}, "wide": []}
	if mesh == null:
		return out
	for surface in mesh.get_surface_count():
		for vertices in HouseQA._mesh_triangles(mesh, surface):
			var bounds := AABB(vertices[0], Vector3.ZERO).expand(vertices[1]).expand(vertices[2])
			var index: int = out.triangles.size()
			out.triangles.append({"a": vertices[0], "b": vertices[1], "c": vertices[2], "bounds": bounds.grow(0.0001), "surface": surface})
			var lo := Vector2i(floori(bounds.position.x / 8.0), floori(bounds.position.z / 8.0))
			var hi := Vector2i(floori(bounds.end.x / 8.0), floori(bounds.end.z / 8.0))
			if (hi.x - lo.x + 1) * (hi.y - lo.y + 1) > 256:
				out.wide.append(index)
				continue
			for x in range(lo.x, hi.x + 1):
				for z in range(lo.y, hi.y + 1):
					var key := Vector2i(x, z)
					if not out.cells.has(key):
						out.cells[key] = []
					out.cells[key].append(index)
	return out


static func _nearby(geometry: Dictionary, bounds: AABB) -> Array:
	var out: Array = []
	var seen := {}
	var lo := Vector2i(floori(bounds.position.x / 8.0), floori(bounds.position.z / 8.0))
	var hi := Vector2i(floori(bounds.end.x / 8.0), floori(bounds.end.z / 8.0))
	for index in geometry.wide:
		seen[index] = true
	for x in range(lo.x, hi.x + 1):
		for z in range(lo.y, hi.y + 1):
			for index in geometry.cells.get(Vector2i(x, z), []):
				seen[index] = true
	for index in seen:
		var triangle: Dictionary = geometry.triangles[index]
		if bounds.intersects(triangle.bounds):
			out.append(triangle)
	return out


static func _fail(out: Dictionary, id: String, reason: String) -> void:
	out.failures.append("occupied_shells[%s]: %s" % [id, reason])
