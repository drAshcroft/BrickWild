class_name ShopPlanner
extends RefCounted
## Adapts the domestic subdivision engine to a public-first workplace plan.


static func plan(spec: ShopSpec) -> HousePlan:
	var out: HousePlan = HousePlanner.plan(spec)
	# HousePlanner needs a hall while it establishes the entrance and stair
	# spine. Once that topology is fixed, the public room takes its real role.
	var front := -1
	if spec.business == &"prison":
		# The domestic name pass intentionally de-duplicates repeated programme
		# kinds. A prison has many identical cells and corridors, so restore its
		# authored room roles from the stable custom-rectangle order.
		var rects := spec.prison_room_rects(HouseGeometry.interior_rect(spec))
		if rects.size() != out.rooms_on_storey(0).size():
			push_error("ShopPlanner: prison custom room count does not match its authored layout")
		else:
			for i in rects.size():
				if i == 0:
					out.rooms[i]["kind"] = &"guardroom"
				elif is_equal_approx(rects[i].size.x, 1.55):
					out.rooms[i]["kind"] = &"corridor"
				else:
					out.rooms[i]["kind"] = &"cell"
			for i in rects.size():
				if i > 0 and is_equal_approx(rects[i].size.x, 1.55):
					for lower in out.rooms_on_storey(-1):
						if Rect2(out.rooms[lower]["rect"]).is_equal_approx(rects[i]):
							out.rooms[lower]["kind"] = &"corridor"
		front = 0
	else:
		for i in range(out.room_count()):
			if out.kind_of(i) == &"hall":
				out.rooms[i]["kind"] = spec.front_room()
				if front < 0:
					front = i
	# The public room is the one the street door opens into. When the house
	# planner had to put the door somewhere other than its hall, the room it
	# chose becomes the front room and the hall takes that room's kind -- a
	# stable whose stall room is not on the street is not a stable (LAY-009).
	var entrance: int = out.entrance_room()
	var street_front: bool = spec.door_w() >= 1.2 or not spec.front_open().is_empty()
	if spec.business != &"prison" and street_front and front >= 0 and entrance >= 0 and entrance != front \
			and out.storey_of_room(entrance) == 0 \
			and HouseGeometry.room_suits(out, entrance, spec.front_room()):
		var was: StringName = out.kind_of(entrance)
		out.rooms[entrance]["kind"] = spec.front_room()
		out.rooms[front]["kind"] = was
		front = entrance
	if front >= 0:
		_cut_shopfront(out, spec, front)
		_light_workshops(out, spec)
		_choose_focus(out, spec, front)
		if spec.business == &"library":
			_pin_library_focus_to_daylight(out, front)
	if spec.business == &"prison":
		_plan_prison_access(out)
	_open_up_lodging(out)
	return out


## Replace the generic spanning tree with parallel guard passages. Every
## corridor reaches the guardroom without a key; each cell is a locked leaf.
## The cellar clone below one cell is the sealed oubliette, entered only by its
## recorded trapdoor and omitted from ordinary door reachability.
static func _plan_prison_access(plan: HousePlan) -> void:
	var guardroom := -1
	var corridors: Array[int] = []
	var cells: Array[int] = []
	for i in range(plan.room_count()):
		if plan.storey_of_room(i) != 0:
			continue
		match plan.kind_of(i):
			&"guardroom": guardroom = i
			&"corridor": corridors.append(i)
			&"cell": cells.append(i)
	if guardroom < 0 or corridors.is_empty() or cells.size() < 3:
		push_error("ShopPlanner: prison layout is missing its guardroom, corridors, or cells")
		return
	# HousePlanner supplied a valid provisional tree. Replace only its ground
	# floor interior edges; cellar copies keep their independent service route.
	for d in range(plan.doors.size() - 1, -1, -1):
		var door: Dictionary = plan.doors[d]
		if not bool(door.get("exterior", false)) and plan.storey_of_room(int(door["a"])) == 0:
			plan.doors.remove_at(d)
	for corridor in corridors:
		var entry: Array = HousePlanOpenings.shared_edge(plan, guardroom, corridor)
		if entry.is_empty():
			push_error("ShopPlanner: prison corridor does not meet the guardroom")
			continue
		HousePlanOpenings.add_inner_door(plan, guardroom, corridor, entry)
	for cell in cells:
		var best_corridor := -1
		var best_edge: Array = []
		var best_run := 0.0
		for corridor in corridors:
			var edge: Array = HousePlanOpenings.shared_edge(plan, cell, corridor)
			if edge.is_empty():
				continue
			var run := float(edge[3]) - float(edge[2])
			if run > best_run:
				best_run = run
				best_corridor = corridor
				best_edge = edge
		if best_corridor < 0:
			push_error("ShopPlanner: prison cell has no corridor wall")
			continue
		HousePlanOpenings.add_inner_door(plan, best_corridor, cell, best_edge)
		if not plan.doors.is_empty():
			plan.doors.back()["locked"] = true
	# Cellars are cloned before the prison's ground-floor door plan is built.
	# Rebuild their service graph from the same measured rectangles; the generic
	# tree cannot reliably place doors on every narrow aisle partition.
	var lower_by_rect := {}
	for lower in plan.rooms_on_storey(-1):
		lower_by_rect[Rect2(plan.rooms[lower]["rect"])] = lower
	var lower_guard := int(lower_by_rect.get(Rect2(plan.rooms[guardroom]["rect"]), -1))
	var lower_corridors: Array[int] = []
	var lower_stores: Array[int] = []
	for corridor in corridors:
		var lower_corridor := int(lower_by_rect.get(Rect2(plan.rooms[corridor]["rect"]), -1))
		if lower_corridor >= 0:
			plan.rooms[lower_corridor]["kind"] = &"corridor"
			lower_corridors.append(lower_corridor)
	for lower in plan.rooms_on_storey(-1):
		if lower != lower_guard and not lower_corridors.has(lower):
			lower_stores.append(lower)
	for d in range(plan.doors.size() - 1, -1, -1):
		var lower_door: Dictionary = plan.doors[d]
		if not bool(lower_door.get("exterior", false)) \
				and plan.storey_of_room(int(lower_door["a"])) == -1:
			plan.doors.remove_at(d)
	for corridor in lower_corridors:
		var edge: Array = HousePlanOpenings.shared_edge(plan, lower_guard, corridor)
		if not edge.is_empty():
			HousePlanOpenings.add_inner_door(plan, lower_guard, corridor, edge)
	for lower in lower_stores:
		var closest_corridor := -1
		var closest_edge: Array = []
		var longest_run := 0.0
		for corridor in lower_corridors:
			var edge: Array = HousePlanOpenings.shared_edge(plan, lower, corridor)
			if edge.is_empty():
				continue
			var run := float(edge[3]) - float(edge[2])
			if run > longest_run:
				longest_run = run
				closest_corridor = corridor
				closest_edge = edge
		if closest_corridor >= 0:
			HousePlanOpenings.add_inner_door(plan, closest_corridor, lower, closest_edge)
	# The lower storey is a clone, so it still tiles the cellar. Seal one cloned
	# cell behind a floor hatch, removing its ordinary door from the graph.
	var upper_cell := cells[0]
	var target_rect: Rect2 = plan.rooms[upper_cell]["rect"]
	var oubliette := -1
	for i in range(plan.room_count()):
		if plan.storey_of_room(i) == -1 and Rect2(plan.rooms[i]["rect"]).is_equal_approx(target_rect):
			oubliette = i
			break
	if oubliette < 0:
		push_error("ShopPlanner: prison has no cellar cell under its trapdoor")
		return
	plan.rooms[oubliette]["kind"] = &"oubliette"
	plan.rooms[oubliette]["sealed"] = true
	for d in range(plan.doors.size() - 1, -1, -1):
		var door2: Dictionary = plan.doors[d]
		if int(door2["a"]) == oubliette or int(door2["b"]) == oubliette:
			plan.doors.remove_at(d)
	var hatch_size := Vector2(0.70, 0.70)
	var upper_floor := HouseGeometry.room_floor_rect(plan, upper_cell)
	var hatch_rect := Rect2(upper_floor.end - hatch_size - Vector2(0.16, 0.16), hatch_size)
	plan.trapdoors.append({"upper_room": upper_cell, "lower_room": oubliette,
		"upper_storey": 0, "lower_storey": -1, "rect": hatch_rect, "sealed": true})


## A workshop needs useful light across its work area. A small domestic plan
## can meet its glazing-area target with one window beside a broad shop door,
## leaving the only usable bench wall dark. Add cross-light on a free outside
## side before furnishing, using the normal opening clearances.
static func _light_workshops(out: HousePlan, spec: ShopSpec) -> void:
	for room in range(out.room_count()):
		if out.kind_of(room) != &"workshop":
			continue
		var windows := out.windows_of(room)
		if windows.is_empty():
			continue
		var first := Vector2(out.windows[windows[0]].normal)
		var cross_lit := false
		for index in windows:
			if absf(Vector2(out.windows[index].normal).dot(first)) < 0.5:
				cross_lit = true
		if cross_lit:
			continue
		var rect: Rect2 = out.rooms[room].rect
		for wall in HouseGeometry.room_walls(out, room):
			var normal := -Vector2(wall.normal)
			if absf(normal.dot(first)) > 0.5:
				continue
			var horizontal := absf(normal.y) > 0.5
			var line: float = wall.from.y if horizontal else wall.from.x
			if not HouseGeometry.is_exterior_edge(spec, 1 if horizontal else 0, line):
				continue
			var side := {"normal": normal, "line": line,
				"t0": rect.position.x if horizontal else rect.position.y,
				"t1": rect.end.x if horizontal else rect.end.y}
			HousePlanOpenings.windows_along(out, spec, room, side, INF, windows.size() + 1)
			if out.windows_of(room).size() > windows.size():
				break


## A reader starts with the book by the light. Pin the first lectern to a
## window-side patch of floor; the second still follows the same daylight
## affinity while the ordinary placer keeps its clearance and navigation rules.
static func _pin_library_focus_to_daylight(out: HousePlan, room: int) -> void:
	var windows := out.windows_of(room)
	if windows.is_empty() or out.focus_room() != room or out.focus_cat() != "lectern":
		return
	var floor := HouseGeometry.room_floor_rect(out, room)
	var hearth := HouseFurnishScore._hearth_point(out, room)
	var chosen := windows[0]
	var best := -INF
	for wi in windows:
		var point := Vector2(out.windows[wi]["pos"])
		var score := point.distance_to(hearth) if hearth.is_finite() else point.distance_to(floor.get_center())
		if score > best:
			best = score
			chosen = wi
	var window_point := Vector2(out.windows[chosen]["pos"])
	var inward := (floor.get_center() - window_point).normalized()
	out.focus["pos"] = window_point + inward * 0.8
	out.focus["placed"] = false


## A trade that lets rooms gives every one of them its own way out (LAY-012).
##
## The inn's programme is a dining room, a kitchen and a chain of guest
## rooms, and a chain is exactly what LAY-007's privacy rule forbids: the
## spanning tree hangs the second guest room off the first, and the only way
## to the far bed is through somebody else's. The hotel met the same problem
## and answered it with a gallery every room opens onto (LAY-008); an inn is
## too small for a gallery of its own, so its programme carries one when it
## has the rooms for it and this pass guarantees the invariant either way:
##
##   EVERY SLEEPING ROOM HAS A DOOR ONTO A ROOM NOBODY SLEEPS IN.
##
## Two remedies, in the order a builder would reach for them. Cut a second
## door from a room you may walk through -- cheap, and what
## `HousePlanOpenings.open_up_privacy` does for a house. Failing that, the room
## the others hang off stops pretending to be a guest room and becomes the
## landing it has been acting as, which is the same demotion
## `_demote_through_bedrooms` makes for a house's own bedroom.
static func _open_up_lodging(out: HousePlan) -> void:
	for guard in range(6):
		var stranded := -1
		for i in range(out.room_count()):
			if out.kind_of(i) in HouseGeometry.SLEEPING and not _has_public_door(out, i):
				stranded = i
				break
		if stranded < 0:
			return
		if _cut_public_door(out, stranded):
			continue
		var culprit: int = _sleeping_neighbour(out, stranded)
		if culprit < 0:
			return
		out.rooms[culprit]["kind"] = &"gallery" \
			if HouseGeometry.room_suits(out, culprit, &"gallery") else &"store"


## Does this room open onto anything but another bed? Its own door to the
## street counts: a room you can walk into from outside is nobody's corridor.
static func _has_public_door(plan: HousePlan, room: int) -> bool:
	for di in plan.doors_of(room):
		var door: Dictionary = plan.doors[di]
		var other: int = int(door["b"]) if int(door["a"]) == room else int(door["a"])
		if other < 0 or not plan.kind_of(other) in HouseGeometry.SLEEPING:
			return true
	return false


## Cut a door from `room` into the widest wall it shares with a room nobody
## sleeps in. False when it shares no such wall wide enough for a door.
static func _cut_public_door(plan: HousePlan, room: int) -> bool:
	var best: Array = []
	var best_run := 0.0
	var best_j := -1
	for j in range(plan.room_count()):
		if j == room or plan.kind_of(j) in HouseGeometry.SLEEPING:
			continue
		var edge: Array = HousePlanOpenings.shared_edge(plan, room, j)
		if edge.is_empty():
			continue
		var run: float = edge[3] - edge[2]
		if run < HouseGeometry.INNER_DOOR_W + HouseGeometry.DOOR_CORNER_MARGIN * 2.0:
			continue
		if run > best_run:
			best_run = run
			best = edge
			best_j = j
	if best_j < 0:
		return false
	HousePlanOpenings.add_inner_door(plan, best_j, room, best)
	return true


## The sleeping room `room` hangs off: the one that has to stop being a
## bedroom for this one to be reachable.
static func _sleeping_neighbour(plan: HousePlan, room: int) -> int:
	for di in plan.doors_of(room):
		var door: Dictionary = plan.doors[di]
		var other: int = int(door["b"]) if int(door["a"]) == room else int(door["a"])
		if other >= 0 and plan.kind_of(other) in HouseGeometry.SLEEPING:
			return other
	return -1


## The shopfront (LAY-009): a hatch in the street wall of the front room,
## beside the door, from counter height to the door head, recorded as a
## window the builder already knows how to cut. It takes the longer stretch
## of wall beside the door and displaces any window it lands on; a front
## wall with no room for it gets none.
static func _cut_shopfront(out: HousePlan, spec: ShopSpec, front: int) -> void:
	var want: Dictionary = spec.front_open()
	if want.is_empty():
		return
	var door: int = out.entrance()
	if door < 0 or int(out.doors[door]["a"]) != front:
		return
	var d: Dictionary = out.doors[door]
	var rect: Rect2 = out.rooms[front]["rect"]
	var w: float = float(want["width"])
	var dx: float = float(d["pos"].x)
	var m: float = HouseGeometry.WINDOW_CORNER_MARGIN
	var gap: float = float(d["width"]) / 2.0 + HouseGeometry.DOOR_CORNER_MARGIN + w / 2.0
	var side: float = 1.0 if rect.end.x - dx >= dx - rect.position.x else -1.0
	var x: float = dx + side * gap
	if x - w / 2.0 < rect.position.x + m or x + w / 2.0 > rect.end.x - m:
		side = -side
		x = dx + side * gap
		if x - w / 2.0 < rect.position.x + m or x + w / 2.0 > rect.end.x - m:
			return
	var pos := Vector2(x, rect.position.y)
	var keep: Array[Dictionary] = []
	for win in out.windows:
		if int(win["room"]) == front and Vector2(win["normal"]).dot(Vector2(0, -1)) > 0.9 \
				and absf(float(win["pos"].x) - x) < (float(win["width"]) + w) / 2.0 + 0.1:
			continue
		keep.append(win)
	out.windows = keep
	out.windows.append({"room": front, "pos": pos, "normal": Vector2(0, -1),
		"width": w, "sill": 0.9, "head": HouseGeometry.DOOR_H, "hatch": true,
		"storey": 0})


## The business's focus replaces the house's fire as what the plan is
## arranged around: the counter, the anvil, the bar, in the front room. A
## focus that must face the door is backed to the wall opposite the entrance
## (a wall piece) or stood in the middle of the floor looking at it (a free
## one); one that need not is backed to the front room's best lit wall, which
## is where a bench wants to be anyway.
static func _choose_focus(out: HousePlan, spec: ShopSpec, front: int) -> void:
	var want: Dictionary = spec.focus()
	if want.is_empty():
		return
	var cat: String = String(want["cat"])
	var faces_door: bool = bool(want.get("faces_door", false))
	var choices: Array[String] = PropCatalog.of_category(cat)
	if choices.is_empty():
		return
	var door_n := Vector2(0, -1)
	var door_pos := Vector2(INF, INF)
	# Some small shops enter through a service room. The business focus must
	# face the doorway into its own room, rather than an imagined street door.
	var entrance := HouseFurnishScore.focus_door(out, front)
	if entrance >= 0:
		door_pos = out.doors[entrance]["pos"]
		var nearest := INF
		for wall in HouseGeometry.room_walls(out, front):
			var point := Geometry2D.get_closest_point_to_segment(door_pos, wall.from, wall.to)
			var distance := door_pos.distance_to(point)
			if distance < nearest:
				nearest = distance
				door_n = -Vector2(wall.normal)
	if PropCatalog.has_tag(choices[0], PropCatalog.WALL):
		var walls: Array[Dictionary] = HouseGeometry.room_walls(out, front)
		var best := -1
		var best_run := -INF
		for wi in range(walls.size()):
			var n: Vector2 = walls[wi]["normal"]
			var span: Vector2 = HousePlanFeatures.clear_wall_span(out, front, wi)
			var run: float = span.y - span.x
			if faces_door:
				# the wall whose inward normal points the way the door's
				# outward normal does is the one across the room from it
				if n.dot(door_n) < 0.9:
					continue
			else:
				if HouseFurnishScore._wall_has_window(out, front, wi):
					run += 100.0
			if run > best_run:
				best_run = run
				best = wi
		if best < 0:
			best = 0
		var prefer := INF
		if faces_door and door_pos.is_finite():
			prefer = door_pos.x if absf(door_n.y) > 0.5 else door_pos.y
		out.focus = HousePlanFeatures.focus_on_wall(out, front, best, cat, faces_door, prefer)
		return
	var f: Rect2 = HouseGeometry.room_floor_rect(out, front)
	var facing: Vector2 = -door_n
	if faces_door and door_pos.is_finite():
		# square in front of the door, looking straight back at it
		facing = door_n
		out.focus = HousePlanFeatures.focus_in_room(out, front, cat, facing, faces_door)
		var depth: float = f.size.y if absf(door_n.y) > 0.5 else f.size.x
		var pos: Vector2 = door_pos - door_n * (depth / 2.0)
		out.focus["pos"] = Vector2(clampf(pos.x, f.position.x + 1.0, f.end.x - 1.0),
			clampf(pos.y, f.position.y + 1.0, f.end.y - 1.0))
		return
	elif out.hearth_room() == front and out.hearth_wall() >= 0:
		facing = HouseGeometry.room_walls(out, front)[out.hearth_wall()]["normal"]
	out.focus = HousePlanFeatures.focus_in_room(out, front, cat, facing, faces_door)
