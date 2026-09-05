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
	return out


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
