class_name ShopPlanner
extends RefCounted
## Adapts the domestic subdivision engine to a public-first workplace plan.


static func plan(spec: ShopSpec) -> HousePlan:
	var out: HousePlan = HousePlanner.plan(spec)
	# HousePlanner needs a hall while it establishes the entrance and stair
	# spine. Once that topology is fixed, the public room takes its real role.
	var front := -1
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
	if street_front and front >= 0 and entrance >= 0 and entrance != front \
			and out.storey_of_room(entrance) == 0 \
			and HouseGeometry.room_suits(out, entrance, spec.front_room()):
		var was: StringName = out.kind_of(entrance)
		out.rooms[entrance]["kind"] = spec.front_room()
		out.rooms[front]["kind"] = was
		front = entrance
	if front >= 0:
		_cut_shopfront(out, spec, front)
		_choose_focus(out, spec, front)
	_open_up_lodging(out)
	return out


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
## `HousePlanner._open_up_privacy` does for a house. Failing that, the room
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
		var edge: Array = HousePlanner._shared_edge(plan, room, j)
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
	HousePlanner._add_inner_door(plan, best_j, room, best)
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
	var entrance: int = out.entrance()
	if entrance >= 0 and int(out.doors[entrance]["a"]) == front:
		door_n = out.doors[entrance]["normal"]
		door_pos = out.doors[entrance]["pos"]
	if PropCatalog.has_tag(choices[0], PropCatalog.WALL):
		var walls: Array[Dictionary] = HouseGeometry.room_walls(out, front)
		var best := -1
		var best_run := -INF
		for wi in range(walls.size()):
			var n: Vector2 = walls[wi]["normal"]
			var span: Vector2 = HousePlanner.clear_wall_span(out, front, wi)
			var run: float = span.y - span.x
			if faces_door:
				# the wall whose inward normal points the way the door's
				# outward normal does is the one across the room from it
				if n.dot(door_n) < 0.9:
					continue
			else:
				if HouseFurnisher._wall_has_window(out, front, wi):
					run += 100.0
			if run > best_run:
				best_run = run
				best = wi
		if best < 0:
			best = 0
		var prefer := INF
		if faces_door and door_pos.is_finite():
			prefer = door_pos.x if absf(door_n.y) > 0.5 else door_pos.y
		out.focus = HousePlanner.focus_on_wall(out, front, best, cat, faces_door, prefer)
		return
	var f: Rect2 = HouseGeometry.room_floor_rect(out, front)
	var facing: Vector2 = -door_n
	if faces_door and door_pos.is_finite():
		# square in front of the door, looking straight back at it
		facing = door_n
		out.focus = HousePlanner.focus_in_room(out, front, cat, facing, faces_door)
		var depth: float = f.size.y if absf(door_n.y) > 0.5 else f.size.x
		var pos: Vector2 = door_pos - door_n * (depth / 2.0)
		out.focus["pos"] = Vector2(clampf(pos.x, f.position.x + 1.0, f.end.x - 1.0),
			clampf(pos.y, f.position.y + 1.0, f.end.y - 1.0))
		return
	elif out.hearth_room() == front and out.hearth_wall() >= 0:
		facing = HouseGeometry.room_walls(out, front)[out.hearth_wall()]["normal"]
	out.focus = HousePlanner.focus_in_room(out, front, cat, facing, faces_door)
