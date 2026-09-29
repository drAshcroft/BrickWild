class_name HousePlanOpenings
extends RefCounted
## Interior doors, entrances, and daylight openings.

# ----------------------------------------------------------------- doors

## Where two rooms meet, and how much of that wall they share.
## Returns [] when they do not touch along a usable run.
static func shared_edge(p: HousePlan, i: int, j: int) -> Array:
	if p.storey_of_room(i) != p.storey_of_room(j):
		return []
	var a: Rect2 = p.rooms[i]["rect"]
	var b: Rect2 = p.rooms[j]["rect"]
	var eps := 0.01
	# vertical partition: a's right face on b's left face, or the reverse
	for pair in [[a, b], [b, a]]:
		var l: Rect2 = pair[0]
		var r: Rect2 = pair[1]
		if absf(l.end.x - r.position.x) < eps:
			var z0: float = maxf(l.position.y, r.position.y)
			var z1: float = minf(l.end.y, r.end.y)
			if z1 - z0 > 0.01:
				return [Vector2(1, 0), l.end.x, z0, z1]
		if absf(l.end.y - r.position.y) < eps:
			var x0: float = maxf(l.position.x, r.position.x)
			var x1: float = minf(l.end.x, r.end.x)
			if x1 - x0 > 0.01:
				return [Vector2(0, 1), l.end.y, x0, x1]
	return []


## Doors on a spanning tree from the hall, expanding through public rooms
## first so bedrooms and stores end up as leaves.
static func place_doors(p: HousePlan, spec: HouseSpec) -> void:
	var n: int = p.rooms.size()
	var hall: int = p.rooms_of(&"hall")[0] if p.has_kind(&"hall") else 0
	_place_front_door(p, spec, hall)

	var joined := {hall: true}
	var guard := 0
	while joined.size() < n and guard < 64:
		guard += 1
		var best: Array = []
		var best_score := -INF
		for i in range(n):
			if not joined.has(i):
				continue
			for j in range(n):
				if joined.has(j):
					continue
				var edge: Array = shared_edge(p, i, j)
				if edge.is_empty():
					continue
				var run: float = edge[3] - edge[2]
				if run < HouseGeometry.INNER_DOOR_W + HouseGeometry.DOOR_CORNER_MARGIN * 2.0:
					continue
				# prefer hanging a room off a public one, and prefer the widest
				# wall to hang it on
				var score: float = run
				if p.kind_of(i) in HouseGeometry.SLEEPING or p.kind_of(i) == &"store":
					score -= 100.0        # only route through these as a last resort
				if p.kind_of(i) == &"hall":
					score += 20.0
				if score > best_score:
					best_score = score
					best = [i, j, edge]
		if best.is_empty():
			break
		joined[best[1]] = true
		add_inner_door(p, best[0], best[1], best[2])

	open_up_privacy(p)
	demote_through_bedrooms(p)
	if spec.back_door:
		_place_back_door(p, spec)


## A spanning tree can leave the only route to a room running through a
## bedroom. Where that happened, look for a wall the stranded room shares with
## a room you may walk through, and cut a second door into it. That is what a
## builder would do, and it is cheaper than replanning the whole house.
static func open_up_privacy(p: HousePlan) -> void:
	var start: int = p.entrance_room()
	if start < 0:
		return
	for guard in range(6):
		var polite: Dictionary = p.reachable_rooms(start, HouseGeometry.SLEEPING)
		var stranded := -1
		for i in range(p.rooms.size()):
			if p.kind_of(i) != &"bedroom" and not polite.has(i):
				stranded = i
				break
		if stranded < 0:
			return
		var added := false
		for j in range(p.rooms.size()):
			if j == stranded or p.kind_of(j) in HouseGeometry.SLEEPING or not polite.has(j):
				continue
			var edge: Array = shared_edge(p, j, stranded)
			if edge.is_empty():
				continue
			var run: float = edge[3] - edge[2]
			if run < HouseGeometry.INNER_DOOR_W + HouseGeometry.DOOR_CORNER_MARGIN * 2.0:
				continue
			if _door_between(p, j, stranded):
				continue
			add_inner_door(p, j, stranded, edge)
			added = true
			break
		if not added:
			return


## If a bedroom is still the only way through to somewhere, it stops being a
## bedroom. A room people traipse through is a parlour if it is big enough to
## be one and a store otherwise -- which is what it actually is.
static func demote_through_bedrooms(p: HousePlan) -> void:
	var start: int = p.entrance_room()
	if start < 0:
		return
	for guard in range(6):
		var polite: Dictionary = p.reachable_rooms(start, &"bedroom")
		var stranded := -1
		for i in range(p.rooms.size()):
			if p.kind_of(i) != &"bedroom" and not polite.has(i):
				stranded = i
				break
		if stranded < 0:
			return
		# find the bedroom on the route and rename it
		var culprit := -1
		var graph: Dictionary = p.door_graph()
		for j in graph[stranded]:
			if p.kind_of(int(j)) == &"bedroom":
				culprit = int(j)
				break
		if culprit < 0:
			return
		p.rooms[culprit]["kind"] = &"parlour" \
			if HouseGeometry.room_suits(p, culprit, &"parlour") else &"store"


static func _door_between(p: HousePlan, a: int, b: int) -> bool:
	for d in p.doors:
		if (d["a"] == a and d["b"] == b) or (d["a"] == b and d["b"] == a):
			return true
	return false


## Doors go NEAR A CORNER, not in the middle of the wall.
##
## A door in the middle of a partition cuts both rooms' longest wall in half
## and takes a metre of clear floor out of the centre of each. Pushed to one
## end it leaves a long unbroken wall on both sides -- which is where the bed,
## the dresser and the table want to go, and is why real plans do it. The end
## chosen is the one nearer the front door, so the route through the house
## stays short as well.
static func add_inner_door(p: HousePlan, a: int, b: int, edge: Array) -> void:
	var normal: Vector2 = edge[0]
	var line: float = edge[1]
	var t0: float = edge[2]
	var t1: float = edge[3]
	var w: float = HouseGeometry.INNER_DOOR_W
	var m: float = HouseGeometry.DOOR_CORNER_MARGIN + w / 2.0
	var t: float = clampf(t0 + m, t0 + m, t1 - m)
	if (t1 - t0) > m * 2.0:
		var entry: int = p.entrance()
		var toward: Vector2 = Vector2(p.doors[entry]["pos"]) if entry >= 0 else Vector2.ZERO
		var near_t: float = toward.y if normal.x > 0.5 else toward.x
		if absf(near_t - t1) < absf(near_t - t0):
			t = t1 - m
	var pos: Vector2 = Vector2(line, t) if normal.x > 0.5 else Vector2(t, line)
	p.doors.append({"a": a, "b": b, "pos": pos, "normal": normal, "width": w,
		"exterior": false, "front": false, "storey": p.storey_of_room(a)})


## The front door, on the hall's own stretch of the front wall.
static func _place_front_door(p: HousePlan, spec: HouseSpec, hall: int) -> void:
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	var room: int = hall
	var rect: Rect2 = p.rooms[room]["rect"]
	# the hall may not reach the front wall; if it does not, the front door goes
	# to whichever room does and sits nearest the middle of the house
	if absf(rect.position.y - inner.position.y) > 0.01:
		var best := -1
		var best_d := INF
		for i in range(p.rooms.size()):
			var r: Rect2 = p.rooms[i]["rect"]
			if absf(r.position.y - inner.position.y) > 0.01:
				continue
			var d: float = absf(r.get_center().x)
			if d < best_d:
				best_d = d
				best = i
		if best >= 0:
			room = best
			rect = p.rooms[room]["rect"]
	# as wide as the spec asks (a stable door, a forge opening), unless the
	# wall is too short for it, in which case the ordinary leaf
	var w: float = spec.front_door_width()
	if rect.size.x < w + 2.0 * HouseGeometry.DOOR_CORNER_MARGIN + 0.2:
		w = HouseGeometry.DOOR_W
	var m: float = HouseGeometry.DOOR_CORNER_MARGIN + w / 2.0
	var x: float = clampf(rect.get_center().x, rect.position.x + m, rect.end.x - m)
	p.doors.append({"a": room, "b": -1, "pos": Vector2(x, inner.position.y),
		"normal": Vector2(0, -1), "width": w, "exterior": true, "front": true,
		"storey": p.storey_of_room(room)})


## A back door out of the kitchen or the store, for the yard -- and never in
## line with the front door (LAY-006). Two doors facing each other across the
## house make the plan read as a corridor with rooms off it, and the feng shui
## phrasing is that everything rushes straight through. So the door goes to
## the end of its wall furthest from the front door, and a room whose wall
## cannot get it out of the line is passed over for the next.
static func _place_back_door(p: HousePlan, spec: HouseSpec) -> void:
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	var front: int = p.entrance()
	var fx: float = inner.get_center().x
	var fw: float = HouseGeometry.DOOR_W
	if front >= 0:
		fx = float(p.doors[front]["pos"].x)
		fw = float(p.doors[front]["width"])
	var fallback := {}
	for kind in [&"kitchen", &"store", &"hall"]:
		for i in p.rooms_of(kind):
			var rect: Rect2 = p.rooms[i]["rect"]
			if absf(rect.end.y - inner.end.y) > 0.01:
				continue
			var w: float = HouseGeometry.DOOR_W
			var m: float = HouseGeometry.DOOR_CORNER_MARGIN + w / 2.0
			if rect.size.x < m * 2.0:
				continue
			var lo: float = rect.position.x + m
			var hi: float = rect.end.x - m
			var x: float = lo if absf(lo - fx) >= absf(hi - fx) else hi
			var door := {"a": i, "b": -1, "pos": Vector2(x, inner.end.y),
				"normal": Vector2(0, 1), "width": w, "exterior": true, "front": false,
				"storey": p.storey_of_room(i)}
			if absf(x - fx) >= (w + fw) / 2.0 + 0.05:
				p.doors.append(door)
				return
			if fallback.is_empty():
				fallback = door
	# no room could get its door out of the line: a back door facing the
	# front door across the house is worse than none, so none it is
	spec.back_door = false


# ---------------------------------------------------------------- windows

## Windows on every exterior wall a room owns, enough of them to light it.
## Stores get one at most; a pantry does not need a view.
static func place_windows(p: HousePlan, spec: HouseSpec, only: Array[int] = []) -> void:
	var rooms: Array[int] = only if not only.is_empty() else HousePlanRooms.all_rooms(p)
	for i in rooms:
		var inner := HouseGeometry.interior_rect(spec, p.storey_of_room(i))
		var kind: StringName = p.kind_of(i)
		var rect: Rect2 = p.rooms[i]["rect"]
		var area: float = HouseGeometry.room_area(p, i)
		var want: float = area * HouseGeometry.GLAZING_MIN
		var cap: int = 1 if kind == &"store" else 6
		var got := 0.0
		# the four sides, front and back first: those are the walls a cottage
		# actually shows to the world
		var sides := [
			{"normal": Vector2(0, -1), "line": inner.position.y, "t0": rect.position.x,
				"t1": rect.end.x, "on": absf(rect.position.y - inner.position.y) < 0.01},
			{"normal": Vector2(0, 1), "line": inner.end.y, "t0": rect.position.x,
				"t1": rect.end.x, "on": absf(rect.end.y - inner.end.y) < 0.01},
			{"normal": Vector2(-1, 0), "line": inner.position.x, "t0": rect.position.y,
				"t1": rect.end.y, "on": absf(rect.position.x - inner.position.x) < 0.01},
			{"normal": Vector2(1, 0), "line": inner.end.x, "t0": rect.position.y,
				"t1": rect.end.y, "on": absf(rect.end.x - inner.end.x) < 0.01},
		]
		for side in sides:
			if not side["on"]:
				continue
			if p.windows_of(i).size() >= cap or got >= want:
				break
			windows_along(p, spec, i, side, want, cap)
			got = 0.0
			for wi in p.windows_of(i):
				got += HouseGeometry.window_area(p.windows[wi])


## A last pass for any room people live in that still has no window.
##
## The even spacing above gives up easily: it keeps clear of the corners, of
## the doors and of its own neighbours, and on a short wall with a door in it
## there is nowhere left. A room with no daylight is worse than a window close
## to a corner, so this pass tries again with the margins pulled in.
static func glaze_remaining(p: HousePlan, spec: HouseSpec, only: Array[int] = []) -> void:
	var rooms: Array[int] = only if not only.is_empty() else HousePlanRooms.all_rooms(p)
	for i in rooms:
		var inner := HouseGeometry.interior_rect(spec, p.storey_of_room(i))
		if not HouseGeometry.is_habitable(p.kind_of(i)):
			continue
		if not p.windows_of(i).is_empty():
			continue
		var rect: Rect2 = p.rooms[i]["rect"]
		var sides := [
			{"normal": Vector2(0, -1), "line": inner.position.y, "t0": rect.position.x,
				"t1": rect.end.x, "on": absf(rect.position.y - inner.position.y) < 0.01},
			{"normal": Vector2(0, 1), "line": inner.end.y, "t0": rect.position.x,
				"t1": rect.end.x, "on": absf(rect.end.y - inner.end.y) < 0.01},
			{"normal": Vector2(-1, 0), "line": inner.position.x, "t0": rect.position.y,
				"t1": rect.end.y, "on": absf(rect.position.x - inner.position.x) < 0.01},
			{"normal": Vector2(1, 0), "line": inner.end.x, "t0": rect.position.y,
				"t1": rect.end.y, "on": absf(rect.end.x - inner.end.x) < 0.01},
		]
		for side in sides:
			if not side["on"]:
				continue
			if _squeeze_window(p, i, side):
				break


## Try every position along one wall, at a fine step, taking the first that
## clears the doors and the other windows.
static func _squeeze_window(p: HousePlan, room: int, side: Dictionary) -> bool:
	var normal: Vector2 = side["normal"]
	var line: float = float(side["line"])
	# full size first, then a narrow one. A small room whose only outside wall
	# has the front door in it can still take a slit of a window, and a slit is
	# worth having: the alternative is a room with no daylight at all.
	for width in [HouseGeometry.WINDOW_W, HouseGeometry.WINDOW_NARROW]:
		var half: float = width / 2.0
		var t0: float = float(side["t0"]) + half + 0.1
		var t1: float = float(side["t1"]) - half - 0.1
		if t1 < t0:
			continue
		var steps: int = maxi(int((t1 - t0) / 0.08), 1)
		for k in range(steps + 1):
			var t: float = lerpf(t0, t1, float(k) / float(steps))
			var pos: Vector2 = Vector2(line, t) if absf(normal.x) > 0.5 else Vector2(t, line)
			if _crowds(p, pos, normal, width, p.storey_of_room(room)):
				continue
			p.windows.append({"room": room, "pos": pos, "normal": normal,
				"width": width, "sill": HouseGeometry.WINDOW_SILL,
				"head": HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H,
				"storey": p.storey_of_room(room)})
			return true
	return false


## Is there already an opening too close to this one? The last-resort pass
## keeps only the masonry a lintel needs between two openings, rather than the
## comfortable spacing the first pass asks for.
static func _crowds(p: HousePlan, pos: Vector2, normal: Vector2, width: float,
		storey := 0) -> bool:
	if HousePlanner.flue_blocks(p, pos, normal, storey, width):
		return true
	for d in p.doors:
		if not _same_wall(d["pos"], d["normal"], pos, normal,
				HousePlan.record_storey(d), storey):
			continue
		if (Vector2(d["pos"]) - pos).length() < (float(d["width"]) + width) / 2.0 + 0.22:
			return true
	for w in p.windows:
		if not _same_wall(w["pos"], w["normal"], pos, normal,
				HousePlan.record_storey(w), storey):
			continue
		if (Vector2(w["pos"]) - pos).length() < (float(w["width"]) + width) / 2.0 + 0.22:
			return true
	return false


## Space windows evenly along one exterior wall of one room, skipping any slot
## that would land on a door.
static func windows_along(p: HousePlan, spec: HouseSpec, room: int, side: Dictionary,
		want: float, cap: int) -> void:
	var normal: Vector2 = side["normal"]
	var line: float = side["line"]
	var t0: float = float(side["t0"]) + HouseGeometry.WINDOW_CORNER_MARGIN
	var t1: float = float(side["t1"]) - HouseGeometry.WINDOW_CORNER_MARGIN
	var run: float = t1 - t0
	if run < HouseGeometry.WINDOW_W:
		return
	var pitch: float = HouseGeometry.WINDOW_W + HouseGeometry.WINDOW_MIN_GAP
	var fits: int = clampi(int(run / pitch) + 1, 1, 4)
	for k in range(fits):
		if p.windows_of(room).size() >= cap:
			return
		var f: float = 0.5 if fits == 1 else float(k) / float(fits - 1)
		var t: float = lerpf(t0 + HouseGeometry.WINDOW_W / 2.0,
			t1 - HouseGeometry.WINDOW_W / 2.0, f)
		var pos: Vector2 = Vector2(line, t) if absf(normal.x) > 0.5 else Vector2(t, line)
		if _clashes_with_door(p, pos, normal, p.storey_of_room(room)):
			continue
		if _clashes_with_window(p, pos, normal, p.storey_of_room(room)):
			continue
		p.windows.append({"room": room, "pos": pos, "normal": normal,
			"width": HouseGeometry.WINDOW_W, "sill": HouseGeometry.WINDOW_SILL,
			"head": HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H,
			"storey": p.storey_of_room(room)})
		var got := 0.0
		for wi in p.windows_of(room):
			got += HouseGeometry.window_area(p.windows[wi])
		if got >= want:
			return


static func _clashes_with_door(p: HousePlan, pos: Vector2, normal: Vector2,
		storey := 0) -> bool:
	if HousePlanner.flue_blocks(p, pos, normal, storey):
		return true
	for d in p.doors:
		if not _same_wall(d["pos"], d["normal"], pos, normal,
				HousePlan.record_storey(d), storey):
			continue
		var gap: float = (d["pos"] - pos).length()
		if gap < (float(d["width"]) + HouseGeometry.WINDOW_W) / 2.0 + 0.3:
			return true
	return false


static func _clashes_with_window(p: HousePlan, pos: Vector2, normal: Vector2,
		storey := 0) -> bool:
	for w in p.windows:
		if not _same_wall(w["pos"], w["normal"], pos, normal,
				HousePlan.record_storey(w), storey):
			continue
		if (w["pos"] - pos).length() < HouseGeometry.WINDOW_W + HouseGeometry.WINDOW_MIN_GAP - 0.05:
			return true
	return false


## Two openings are on the same wall when they share a normal axis and lie on
## the same line.
static func _same_wall(pa: Vector2, na: Vector2, pb: Vector2, nb: Vector2,
		storey_a := 0, storey_b := 0) -> bool:
	if int(storey_a) != int(storey_b):
		return false
	if absf(na.x) != absf(nb.x):
		return false
	if absf(na.x) > 0.5:
		return absf(pa.x - pb.x) < 0.02
	return absf(pa.y - pb.y) < 0.02

