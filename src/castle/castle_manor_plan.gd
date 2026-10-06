extends RefCounted
## Occupied wings, front range, annexe and corner towers of houses and manors.
##
## These masses used to be solid blocks with a row of windows painted on each
## face. Every one is now a plan: floors, a way in from the court or road, and
## windows that open into a room. A wing is a ridge range turned to the court,
## so it reuses CastleInteriorPlans.ridge_range_plan rather than growing a
## second multi-bay planner.

const MIN_STOREY_H := 2.7
const STOREY_H := 3.4
const TOWER_THICKNESS := 0.6
const CLOSET_DOOR := 0.8
## A stone wing four metres across has a 2.8 m room: a lord's chamber's minimum.
const NARROW_WING := 2.8
## Shortest facet that takes a door leaf and its two corner margins.
const DOOR_FACET := 1.65


static func records(spec: CastleSpec) -> Dictionary:
	var out := {}
	if CastleGeometry.is_enclosed(spec) or CastleGeometry.is_ridge(spec) \
			or CastleGeometry.is_tower_house(spec) or CastleGeometry.is_sky(spec):
		return out
	if spec.tier == &"house":
		var annexe := CastleGeometry.annexe_aabb(spec)
		if annexe.size.x > 0.0:
			_add(out, "annexe", annexe_plan(spec, annexe), annexe, -PI * 0.5)
		return out
	for side in CastleGeometry.wing_sides(spec):
		var id := "wing_%s" % ("left" if side < 0.0 else "right")
		var box: AABB = wing_nose(spec, side).plan_box
		# The doorway faces the court: local -Z is carried to world +X for the
		# west wing and -X for the east one.
		var yaw := -PI * 0.5 if side < 0.0 else PI * 0.5
		_add(out, id, wing_plan(spec, box, id), box, yaw)
	var front := CastleGeometry.manor_front_range_aabb(spec)
	if front.size.x > 0.0:
		_add(out, "range_front", front_range_plan(spec, front), front, 0.0)
	var index := 0
	var sides := CastleGeometry.wing_sides(spec)
	for centre in CastleGeometry.manor_tower_centers(spec):
		var id := "tower_manor_%d" % index
		var wing_id := "wing_%s" % ("left" if sides[index] < 0.0 else "right")
		index += 1
		# A tower stands inside its wing's end: without the wing's own plan the
		# wing is still a solid block running through the tower's rooms.
		if not out.has(wing_id):
			continue
		var tower_box := CastleGeometry.tower_aabb(spec, 0, centre)
		_add(out, id, tower_plan(spec, id, centre), tower_box, 0.0)
	return out


static func _add(out: Dictionary, id: String, plan: HousePlan, bounds: AABB,
		yaw: float) -> void:
	if plan.spec == null:
		return
	# Same row CastleInteriors.record makes (it cannot be preloaded from here).
	var centre := bounds.get_center()
	out[id] = {"id": id, "plan": plan, "bounds": bounds,
		"transform": Transform3D(Basis(Vector3.UP, yaw),
			Vector3(centre.x, bounds.position.y, centre.z))}


static func _suits(rect: Rect2, kind: StringName) -> bool:
	var enough_area := rect.size.x * rect.size.y >= float(HouseGeometry.MIN_AREA.get(kind, 4.0))
	return enough_area and minf(rect.size.x, rect.size.y) \
		>= float(HouseGeometry.MIN_SIDE.get(kind, 1.6))


static func _levels(height: float, cap := 4) -> int:
	var levels := clampi(roundi(height / STOREY_H), 1, cap)
	while levels > 1 and height / float(levels) < MIN_STOREY_H:
		levels -= 1
	return levels


## A cross wing: a ridge range planned along its long side, door and
## windows facing out of both long walls. Its two ends are shared masonry
## where it meets a front tower and where it laps the main range.
static func wing_plan(spec: CastleSpec, box: AABB, id: String) -> HousePlan:
	var seg := {"name": id, "length": box.size.z, "width": box.size.x,
		"height": box.size.y}
	var options := {"levels": _levels(box.size.y), "buried_lo": 0.0, "buried_hi": 0.0,
		"min_side": NARROW_WING}
	# Too narrow for a lord's chamber (3.0 m): the rooms are parlours.
	var inner := box.size.x - 2.0 * HouseGeometry.wall_thickness(
		CastleInteriorPlans._hall_spec(spec, box))
	if inner < 3.0:
		options["kind"] = &"parlour"
	return CastleInteriorPlans.ridge_range_plan(spec, seg, [], options)


## A wing with a front tower: the tower stands inside the wing's end, so the
## wing's rooms start at the tower's rear face and two masonry cheeks fill the
## strip left either side of the tower. Without a tower the wing is whole.
## Returns {"plan_box": AABB the rooms occupy, "infill": Array[AABB]}.
static func wing_nose(spec: CastleSpec, side: float) -> Dictionary:
	var box := CastleGeometry.manor_wing_aabb(spec, side)
	var infill: Array[AABB] = []
	var out := {"plan_box": box, "infill": infill}
	if CastleGeometry.manor_tower_centers(spec).is_empty():
		return out
	var s := CastleGeometry.tower_base_half(spec, 0)
	var half := CastleGeometry.tower_half_at(spec, 0, -1)
	var centre_z := box.position.z + s * 0.6
	var centre_x := box.position.x + box.size.x * 0.5
	var start := centre_z + half - 0.3
	if start >= box.end.z - 4.0:
		return out
	out.plan_box = AABB(Vector3(box.position.x, 0.0, start),
		Vector3(box.size.x, box.size.y, box.end.z - start))
	var reach := half - TOWER_THICKNESS * 0.8
	var left_edge := centre_x - reach
	var right_edge := centre_x + reach
	var depth := start - box.position.z
	if left_edge > box.position.x + 0.05:
		infill.append(AABB(box.position, Vector3(left_edge - box.position.x, box.size.y, depth)))
	if right_edge < box.end.x - 0.05:
		infill.append(AABB(Vector3(right_edge, 0.0, box.position.z),
			Vector3(box.end.x - right_edge, box.size.y, depth)))
	return out


## Masonry cheeks beside every front tower (see wing_nose).
static func infill_boxes(spec: CastleSpec) -> Array[AABB]:
	var out: Array[AABB] = []
	if CastleGeometry.is_enclosed(spec) or spec.tier == &"house":
		return out
	for side in CastleGeometry.wing_sides(spec):
		out.append_array(wing_nose(spec, side).infill)
	return out


## The annexe is a lean-to on the east end of a house. Large enough it is a
## small range; a three-metre block is a store with one door.
static func annexe_plan(spec: CastleSpec, box: AABB) -> HousePlan:
	var seg := {"name": "annexe", "length": maxf(box.size.x, box.size.z),
		"width": minf(box.size.x, box.size.z), "height": box.size.y}
	# The local +Z wall is the one against the building this leans on.
	var plan := CastleInteriorPlans.ridge_range_plan(spec, seg, [], {
		"levels": _levels(box.size.y, 2), "buried_lo": 0.0, "buried_hi": 0.0,
		"lean": true, "end_windows": true})
	if plan.spec != null:
		return plan
	return _closet_plan(spec, box)


static func _closet_plan(spec: CastleSpec, box: AABB) -> HousePlan:
	var plan := HousePlan.new()
	var hs: HouseSpec = CastleInteriorPlans._hall_spec(spec, box)
	hs.height = clampf(box.size.y, 2.4, 3.2)
	hs.storeys = 1
	hs.program = [&"store"] as Array[StringName]
	hs.variant_name = "%s: a store" % spec.variant_name
	hs.clutter = 0.3
	var room := HouseGeometry.interior_rect(hs)
	if not _suits(room, &"store"):
		return plan
	plan.spec = hs
	plan.rooms.append({"kind": &"store", "rect": room, "storey": 0})
	# On the local -Z wall, like every range's door; the record's yaw turns it
	# away from the building the block leans on.
	plan.doors.append({"a": 0, "b": -1, "pos": Vector2(room.get_center().x, room.position.y),
		"normal": Vector2(0.0, -1.0), "width": CLOSET_DOOR, "exterior": true,
		"front": true, "storey": 0})
	HouseFurnisher.furnish(plan, hs)
	return plan


## The low range that closes a courtyard manor. The gate passage runs through
## its middle, so the ground floor is a guard bay, a passage and a guard bay;
## the upper floors bridge the passage as one room.
static func front_range_plan(spec: CastleSpec, box: AABB) -> HousePlan:
	var plan := HousePlan.new()
	var hs: HouseSpec = CastleInteriorPlans._hall_spec(spec, box)
	var levels := _levels(box.size.y, 3)
	hs.height = box.size.y / float(levels)
	hs.storeys = levels
	var floor_rect := HouseGeometry.interior_rect(hs)
	var passage := clampf(spec.width * 0.18, 2.0, 6.0) * 0.5
	passage = clampf(passage, 1.4, 2.4)
	var cx := floor_rect.get_center().x
	var x0 := floor_rect.position.x
	var x1 := cx - passage * 0.5
	var x2 := cx + passage * 0.5
	var x3 := floor_rect.end.x
	var y0 := floor_rect.position.y
	var depth := floor_rect.size.y
	var bay_kind: StringName = &"guardroom" if (x1 - x0) >= 2.5 and depth >= 2.5 \
		and (x1 - x0) * depth >= 8.5 else &"store"
	var left := Rect2(Vector2(x0, y0), Vector2(x1 - x0, depth))
	var gate := Rect2(Vector2(x1, y0), Vector2(x2 - x1, depth))
	var right := Rect2(Vector2(x2, y0), Vector2(x3 - x2, depth))
	if not _suits(left, bay_kind) or not _suits(right, bay_kind):
		return plan
	hs.program = [] as Array[StringName]
	plan.spec = hs
	plan.rooms.append({"kind": bay_kind, "rect": left, "storey": 0})
	plan.rooms.append({"kind": &"corridor", "rect": gate, "storey": 0})
	plan.rooms.append({"kind": bay_kind, "rect": right, "storey": 0})
	hs.program.append_array([bay_kind, &"corridor", bay_kind])
	for level in range(1, levels):
		var kind: StringName = &"parlour"
		plan.rooms.append({"kind": kind, "rect": floor_rect, "storey": level})
		hs.program.append(kind)
	var mid_y := y0 + depth * 0.5
	# Both ends of the passage are doorways, one to the road and one to the court.
	plan.doors.append({"a": 1, "b": -1, "pos": Vector2(cx, y0), "normal": Vector2(0, -1),
		"width": minf(passage - 0.3, 1.6), "exterior": true, "front": true, "storey": 0,
		"passage": true})
	plan.doors.append({"a": 1, "b": -1, "pos": Vector2(cx, floor_rect.end.y),
		"normal": Vector2(0, 1), "width": minf(passage - 0.3, 1.6), "exterior": true,
		"front": false, "storey": 0, "passage": true})
	plan.doors.append({"a": 0, "b": 1, "pos": Vector2(x1, mid_y), "normal": Vector2(1, 0),
		"width": HouseGeometry.INNER_DOOR_W, "exterior": false, "front": false, "storey": 0})
	plan.doors.append({"a": 1, "b": 2, "pos": Vector2(x2, mid_y), "normal": Vector2(1, 0),
		"width": HouseGeometry.INNER_DOOR_W, "exterior": false, "front": false, "storey": 0})
	var previous := Rect2()
	for level in range(levels - 1):
		var lower := 0 if level == 0 else 2 + level
		var stair := CastleInteriorPlans._ridge_add_stair(plan, level, level + 1,
			lower, 3 + level, previous)
		if not stair.is_empty():
			plan.stairs.append(stair)
			previous = stair.rect
	for index in range(plan.rooms.size()):
		var kind: StringName = plan.rooms[index].kind
		if kind == &"corridor":
			continue
		var rect: Rect2 = plan.rooms[index].rect
		var before := plan.windows.size()
		CastleInteriorPlans._hall_windows(plan, rect, Vector2(1, 0), hs, index,
			hs.height - 0.2)
		for window in range(before, plan.windows.size()):
			plan.windows[window]["storey"] = int(plan.rooms[index].storey)
	hs.room_count = plan.rooms.size()
	HouseFurnisher.furnish(plan, hs)
	return plan


## A corner tower of a manor wing: a stack of rooms entered at ground level
## on the facet that looks away from the wing, with windows on the outward
## facets. The tower stands on level ground, so it needs no curtain walk.
## `opts` lets other forms reuse it (ridge towers): "height", "half", the way
## "desired" the doorway faces, the least dot of a window facet with it
## ("window_dot"), and "facet_facing": true to turn the outline so a flat faces
## `desired` exactly.
static func tower_plan(spec: CastleSpec, id: String, centre: Vector3, opts := {}) -> HousePlan:
	var plan := HousePlan.new()
	var height: float = float(opts.get("height", CastleGeometry.tower_height_at(spec, 0, -1)))
	var half: float = float(opts.get("half", CastleGeometry.tower_half_at(spec, 0, -1)))
	var desired: Vector2 = opts.get("desired", Vector2(0.0, -1.0))
	var window_dot: float = float(opts.get("window_dot", -0.3))
	var levels := _levels(height, 6)
	# A floating tower is entered a storey up, from its bridge: "door_y" is the
	# height above the tower's foot at which the door's floor should be.
	var door_level := clampi(roundi(float(opts.get("door_y", 0.0)) / (height / float(levels))),
		0, levels - 1)
	var hs := KeepSpec.new(spec.seed ^ int(id.hash()))
	hs.material = &"stone"
	hs.style = &"townhouse"
	hs.width = half * 2.0
	hs.length = half * 2.0
	hs.height = height / float(levels)
	hs.storeys = levels
	hs.entry_storey = door_level
	hs.room_count = levels
	hs.wall_thickness_override = TOWER_THICKNESS
	hs.plinth_height = 0.0
	hs.porch = false
	hs.chimney = false
	hs.exterior_props = false
	hs.wall_color = spec.stone_color
	hs.trim_color = spec.trim_color
	hs.roof_color = spec.roof_color
	hs.floor_color = spec.stone_color.darkened(0.35)
	var sides := CastleGeometry.tower_sides(spec)
	var rotation := CastleGeometry.tower_rotation(spec)
	# A slender turret has facets too short for a doorway. Coarsen its plan
	# (12, 8, 6, 4 sides) until one facet takes a door and its margins, with a
	# flat facing the road; the shell is raised from this plan, so the plan wins.
	var clear := half - TOWER_THICKNESS
	for candidate in [sides, 8, 6, 4]:
		if candidate > sides:
			continue
		if 2.0 * clear * tan(PI / float(candidate)) >= DOOR_FACET:
			if candidate != sides:
				sides = candidate
				rotation = -PI * 0.5 + PI / float(sides)
			break
	if bool(opts.get("facet_facing", false)):
		rotation = atan2(desired.y, desired.x) - PI / float(sides)
	var radius := clear / cos(PI / float(sides))
	var outline := PackedVector2Array()
	for side in range(sides):
		var angle := rotation + TAU * float(side) / float(sides)
		outline.append(Vector2(cos(angle), sin(angle)) * radius)
	plan.spec = hs
	var room_kind: StringName = &"guardroom"
	var probe := Poly.bounding_rect(outline)
	# A turned outline can reach past the tower's own square; the interior the
	# tiling check measures has to hold it.
	var reach := maxf(maxf(absf(probe.position.x), probe.end.x),
		maxf(absf(probe.position.y), probe.end.y))
	hs.width = maxf(hs.width, 2.0 * (reach + TOWER_THICKNESS))
	hs.length = maxf(hs.length, 2.0 * (reach + TOWER_THICKNESS))
	if not _suits_outline(outline, probe, &"guardroom"):
		room_kind = &"store"
	for level in range(levels):
		plan.rooms.append({"kind": room_kind, "rect": probe,
			"outline": outline.duplicate(), "storey": level, "host": id})
		hs.program.append(room_kind)
	# The way in: the facet facing the road, else the one most clear of the wing.
	var best := {}
	var score := -INF
	for wall in HouseGeometry.room_walls(plan, door_level):
		var normal := -Vector2(wall.normal)
		var length := Vector2(wall.from).distance_to(wall.to)
		if length < 1.8:
			continue
		var candidate := normal.dot(desired) + length * 0.01
		if candidate > score:
			score = candidate
			best = wall
	if best.is_empty():
		return HousePlan.new()
	var a: Vector2 = best.from
	var b: Vector2 = best.to
	var door_width := minf(float(opts.get("door_width", 1.2)), maxf(HouseGeometry.PATH_MIN,
		a.distance_to(b) - 2.0 * HouseGeometry.DOOR_CORNER_MARGIN))
	plan.doors.append({"a": door_level, "b": -1, "pos": (a + b) * 0.5,
		"normal": -Vector2(best.normal), "width": door_width,
		"exterior": true, "front": true, "storey": door_level, "sill": 0.0,
		"head": minf(hs.height - 0.2, 2.35)})
	var previous := Rect2()
	for level in range(levels - 1):
		CastleKeepPlan._add_stair(plan, level, level + 1, previous)
		if not plan.stairs.is_empty():
			previous = plan.stairs[-1].upper_rect
	# Windows on the facets that look away from the wing, one to a facet.
	for level in range(levels):
		for wall in HouseGeometry.room_walls(plan, level):
			var normal := -Vector2(wall.normal)
			if normal.dot(desired) < window_dot:
				continue
			var opening := _tower_window(plan, level, wall)
			if opening.is_empty():
				continue
			plan.windows.append({"room": level, "storey": level, "pos": opening.pos,
				"normal": normal, "width": opening.width, "sill": 0.95,
				"head": minf(hs.height - 0.3, 2.15), "host": id})
	# A storey no window can reach (the ground floor, or the facets beside the
	# range joins) is a store, not a guardroom.
	for level in range(levels):
		var lit := false
		for window in plan.windows:
			if int(window.get("room", -1)) == level:
				lit = true
		if not lit:
			plan.rooms[level]["kind"] = &"store"
			hs.program[level] = &"store"
	CastleKeepPlan.furnish_minimum_programme(plan, hs)
	return plan


static func _tower_window(plan: HousePlan, level: int, wall: Dictionary) -> Dictionary:
	var a := Vector2(wall.from)
	var edge := Vector2(wall.to) - a
	var normal := -Vector2(wall.normal)
	for width in [1.1, 0.6]:
		var margin: float = width * 0.5 + 0.25
		if edge.length() < margin * 2.0:
			continue
		var pos := a + edge * 0.5
		if preload("castle_mural_plan.gd")._window_clear(plan, level, pos, normal, width):
			return {"pos": pos, "width": width}
	return {}


static func _suits_outline(outline: PackedVector2Array, probe: Rect2,
		kind: StringName) -> bool:
	var enough_area := Poly.area(outline) >= float(HouseGeometry.MIN_AREA[kind])
	return enough_area and minf(probe.size.x, probe.size.y) \
		>= float(HouseGeometry.MIN_SIDE[kind])


## The jogs of an L or Z tower house. Each is a small block against the shaft;
## its door looks out of the side the shaft does not cover.
static func jog_records(spec: CastleSpec) -> Dictionary:
	var out := {}
	var jogs := CastleGeometry.tower_jog_aabbs(spec)
	for index in range(jogs.size()):
		var box: AABB = jogs[index]
		var long_x := box.size.x >= box.size.z
		var yaw := 0.0
		if long_x:
			yaw = 0.0 if index == 0 else PI
		else:
			yaw = -PI * 0.5 if index == 0 else PI * 0.5
		_add(out, "wing_jog_%d" % index, jog_plan(spec, box), box, yaw)
	return out


## The solid approach steps the builder raises to a tower house's door
## (CastleBuilder._tower_approach_steps), as one box, so a neighbour's window
## is not planned onto them.
static func tower_approach_box(spec: CastleSpec, door_xz: Vector2) -> AABB:
	var t := CastleGeometry.tower_house_aabb(spec)
	var sill := CastleGeometry.tower_door_sill(spec)
	var count := maxi(4, int(ceil(sill / 0.28)))
	var depth := clampf(maxf(t.size.z * 0.08, 0.8), 0.8, 1.5)
	var width := clampf(maxf(t.size.x * 0.28, 2.0), 2.0, 3.6)
	var total := float(count) * depth
	return AABB(Vector3(door_xz.x - width * 0.5 - 0.3, 0.0, door_xz.y - total - 0.3),
		Vector3(width + 0.6, sill + 3.5, total + 0.3))


static func jog_plan(spec: CastleSpec, box: AABB) -> HousePlan:
	return annexe_plan(spec, box)


## The turret-islands of a sky castle: stacks of rooms entered from the bridge
## that leaves each one, a storey up, with windows all round.
static func sky_records(spec: CastleSpec) -> Dictionary:
	var out := {}
	var bridges := CastleGeometry.sky_bridges(spec)
	var index := 0
	for tower in CastleGeometry.sky_towers(spec):
		var pos: Vector3 = tower.pos
		var radius: float = tower.radius
		var centre_xz := Vector2(pos.x, pos.z)
		var desired := centre_xz.normalized() if centre_xz.length() > 0.1 else Vector2(0.0, -1.0)
		var attach := pos.y + float(tower.height) * 0.58
		for bridge in bridges:
			var from_p: Vector3 = bridge.from
			var to_p: Vector3 = bridge.to
			var heading := Vector2(to_p.x - from_p.x, to_p.z - from_p.z).normalized()
			if Vector2(from_p.x, from_p.z).distance_to(centre_xz) < radius + 0.8:
				desired = heading
				attach = from_p.y
				break
			if Vector2(to_p.x, to_p.z).distance_to(centre_xz) < radius + 0.8:
				desired = -heading
				attach = to_p.y
				break
		var id := "sky_tower_%d" % index
		var opts := {"height": float(tower.height), "half": radius * cos(PI / 12.0),
			"desired": desired, "window_dot": -1.0, "facet_facing": true,
			"door_y": attach - pos.y - 1.1, "door_width": 1.0}
		var box := AABB(Vector3(pos.x - radius, pos.y, pos.z - radius),
			Vector3(radius * 2.0, float(tower.height), radius * 2.0))
		_add(out, id, tower_plan(spec, id, pos, opts), box, 0.0)
		index += 1
	return out
