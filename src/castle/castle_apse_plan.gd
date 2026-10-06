extends RefCounted
## The chapel's curved end is a room, not a window painted on a solid drum.
## Its shared doorway cuts both the nave wall and the apse's diameter wall.

static func record(spec: CastleSpec) -> Dictionary:
	var bounds := CastleGeometry.apse_aabb(spec)
	if not CastleGeometry.is_enclosed(spec) or bounds.size.x <= 0.0:
		return {}
	var hs := HouseSpec.new(spec.seed ^ 0x41505345)
	hs.material = &"stone"
	hs.style = &"longhall"
	hs.width = bounds.size.x
	hs.length = bounds.size.z
	hs.height = bounds.size.y
	hs.storeys = 1
	hs.room_count = 1
	hs.program = [&"sanctuary"] as Array[StringName]
	hs.plinth_height = 0.0
	hs.porch = false
	hs.chimney = false
	hs.exterior_props = false
	hs.wall_color = spec.stone_color
	hs.trim_color = spec.trim_color
	hs.roof_color = spec.roof_color
	hs.floor_color = spec.stone_color.darkened(0.35)
	var centre := bounds.get_center()
	centre.y = bounds.position.y
	var arc_centre := Vector2(0.0, bounds.size.z * 0.5)
	var radius := CastleGeometry.apse_radius(spec)
	var inner := PackedVector2Array()
	var thick := HouseGeometry.wall_thickness(hs)
	var inner_radius := radius - thick / cos(PI / 20.0)
	for segment in range(11):
		var angle := PI + PI * float(segment) / 10.0
		inner.append(arc_centre + Vector2(cos(angle), sin(angle)) * inner_radius)
	# Clip the straight diameter separately. Poly.offset's inward bevels
	# retain reversed corner edges and are not a usable room-wall polygon.
	var clip := Rect2(-radius * 2.0, arc_centre.y - radius * 2.0,
		radius * 4.0, radius * 2.0 - thick)
	var outline := Poly.clip_convex(inner, Poly.from_rect(clip))
	if outline.size() < 3:
		return {}
	var plan := HousePlan.new()
	plan.spec = hs
	plan.rooms.append({"kind": &"sanctuary", "rect": Poly.bounding_rect(outline),
		"outline": outline, "storey": 0, "host": "apse"})
	var walls := HouseGeometry.room_walls(plan, 0)
	for wall in walls:
		var normal := -Vector2(wall.normal)
		var middle := (Vector2(wall.from) + Vector2(wall.to)) * 0.5
		if normal.y > 0.99:
			plan.doors.append({"a": 0, "b": -1, "pos": middle,
				"normal": normal, "width": HouseGeometry.DOOR_W,
				"exterior": true, "front": true, "storey": 0,
				"sill": 0.0, "head": 2.3, "connects_to": "chapel"})
		elif normal.y < -0.7:
			var span := Vector2(wall.from).distance_to(wall.to)
			var width := minf(0.7, span - 0.22)
			if width > 0.3:
				plan.windows.append({"room": 0, "storey": 0, "pos": middle,
					"normal": normal, "width": width, "sill": 0.9,
					"head": minf(hs.height - 0.3, 2.3)})
	# The sanctuary has its altar and standing place; pews belong to the nave.
	# The approach from the nave stays clear before any furniture is selected.
	var floor_rect := Poly.bounding_rect(outline)
	plan.focus = {"room": 0, "cat": "table", "pos": Vector2(0.0,
		floor_rect.position.y + floor_rect.size.y * 0.4), "facing": 0.0, "faces_door": false}
	plan.zones.append({"room": 0, "rect": Rect2(-0.6,
		floor_rect.end.y - HouseGeometry.DOOR_CLEAR, 1.2, HouseGeometry.DOOR_CLEAR),
		"why": "sanctuary standing approach"})
	HouseFurnisher.furnish(plan, hs)
	return {"id": "apse", "plan": plan, "bounds": bounds,
		"transform": Transform3D(Basis.IDENTITY, centre)}


static func connect_chapel(plan: HousePlan, spec: CastleSpec) -> void:
	if not CastleGeometry.is_enclosed(spec) or CastleGeometry.apse_aabb(spec).size.x <= 0.0:
		return
	var rect := HouseGeometry.room_floor_rect(plan, 0)
	var point := Vector2(rect.get_center().x, rect.position.y)
	for door in plan.doors:
		if Vector2(door.pos).distance_to(point) < 0.01:
			# The chapel's own entrance already stands on this wall. It is also
			# the way through to the apse, whose doorway is 2.3 m: a standard
			# 2.02 m leaf left masonry across the upper part of the passage.
			door["head"] = maxf(float(door.get("head", HouseGeometry.DOOR_H)), 2.3)
			door["sill"] = minf(float(door.get("sill", 0.0)), 0.0)
			return
	plan.doors.append({"a": 0, "b": -1, "pos": point, "normal": Vector2(0, -1),
		"width": HouseGeometry.DOOR_W, "exterior": true, "front": false,
		"storey": 0, "sill": 0.0, "head": 2.3, "connects_to": "apse"})
