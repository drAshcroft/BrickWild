class_name HousePlanner
extends RefCounted
## Turns a HouseSpec into rooms, doors and windows.
##
## Three passes, in the order an architect would take them:
##   1. SUBDIVIDE  the interior into rooms, splitting the biggest room each
##      time, so the rooms come out roughly even rather than one hall and five
##      cupboards.
##   2. NAME them, by how public they are. The front of the house is public and
##      the back is private, which is the oldest rule in domestic planning: the
##      hall takes the front door, the kitchen sits next to it, bedrooms go as
##      far from the door as the plan allows, and whatever is left over and too
##      small to live in becomes the store.
##   3. CONNECT them. Doors go on a spanning tree rooted at the hall, expanded
##      through public rooms first, so a bedroom ends up a leaf and nobody has
##      to walk through someone's bedroom to reach the kitchen.
##
## Then windows, on exterior walls only, enough of them to light each room.
## Every one of those rules is checked afterwards by HousePlanCheck -- this
## file tries to build it right, that file refuses to believe it did.

const MIN_SPLIT := 0.36     # a split may not leave either side thinner than this
const MAX_SPLIT := 0.64


static func plan(spec: HouseSpec) -> HousePlan:
	var p := HousePlan.new()
	p.spec = spec
	_subdivide(p, spec)
	_name_rooms(p, spec)
	_place_doors(p, spec)
	_place_windows(p, spec)
	_glaze_the_rest(p, spec)
	_demote_unlit(p)
	return p


## A room that could not be given a window is not a room anybody lives in.
##
## _demote_windowless catches the rooms with no outside wall at all; this one
## catches the rest -- a kitchen whose only stretch of outside wall is taken up
## by the back door has nowhere left to put a window, and calling it a kitchen
## anyway would leave the daylight check failing forever. It becomes the store,
## and the store's kind goes to a room that does have daylight.
static func _demote_unlit(p: HousePlan) -> void:
	for i in range(p.rooms.size()):
		if not HouseGeometry.is_habitable(p.kind_of(i)) or not p.windows_of(i).is_empty():
			continue
		var swap := -1
		for j in range(p.rooms.size()):
			if p.kind_of(j) == &"store" and not p.windows_of(j).is_empty() 					and HouseGeometry.room_suits(p, j, p.kind_of(i)):
				swap = j
				break
		if swap >= 0:
			var mine: StringName = p.kind_of(i)
			p.rooms[i]["kind"] = &"store"
			p.rooms[swap]["kind"] = mine
		else:
			p.rooms[i]["kind"] = &"store"


# --------------------------------------------------------------- subdivide

## Split the interior until there are `spec.room_count` rooms or nothing can be
## split any further without making a cupboard.
static func _subdivide(p: HousePlan, spec: HouseSpec) -> void:
	var rects: Array[Rect2] = [HouseGeometry.interior_rect(spec)]
	var r := spec.rng
	var want: int = maxi(spec.room_count, 1)
	var guard := 0
	while rects.size() < want and guard < 64:
		guard += 1
		# split the biggest room: splitting a random one leaves a great hall
		# next to a broom cupboard
		var best := -1
		var best_area := 0.0
		for i in range(rects.size()):
			var a: float = rects[i].size.x * rects[i].size.y
			if a > best_area and _can_split(rects[i]):
				best_area = a
				best = i
		if best < 0:
			break
		var pair: Array = _split(rects[best], r)
		if pair.is_empty():
			break
		rects.remove_at(best)
		rects.append(pair[0])
		rects.append(pair[1])

	# a stable order: front to back, then left to right, so room 0 is at the
	# front left whatever the seed did
	rects.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		if absf(a.position.y - b.position.y) > 0.01:
			return a.position.y < b.position.y
		return a.position.x < b.position.x)
	for rect in rects:
		p.rooms.append({"kind": &"hall", "rect": rect})


static func _can_split(rect: Rect2) -> bool:
	var m: float = HouseGeometry.MIN_ROOM_SIDE + HouseGeometry.INNER_WALL_T
	return rect.size.x >= m * 2.0 or rect.size.y >= m * 2.0


## Cut along the longer axis, so rooms tend toward square rather than toward
## corridors. Returns [] when neither axis has room for the cut.
static func _split(rect: Rect2, r: RandomNumberGenerator) -> Array:
	var m: float = HouseGeometry.MIN_ROOM_SIDE + HouseGeometry.INNER_WALL_T
	var axes: Array[int] = []
	if rect.size.x >= rect.size.y:
		axes = [0, 1]
	else:
		axes = [1, 0]
	for axis in axes:
		var span: float = rect.size.x if axis == 0 else rect.size.y
		if span < m * 2.0:
			continue
		var lo: float = maxf(MIN_SPLIT, m / span)
		var hi: float = minf(MAX_SPLIT, 1.0 - m / span)
		if hi <= lo:
			continue
		var t: float = r.randf_range(lo, hi)
		var cut: float = span * t
		if axis == 0:
			return [
				Rect2(rect.position, Vector2(cut, rect.size.y)),
				Rect2(rect.position + Vector2(cut, 0.0),
					Vector2(rect.size.x - cut, rect.size.y)),
			]
		return [
			Rect2(rect.position, Vector2(rect.size.x, cut)),
			Rect2(rect.position + Vector2(0.0, cut),
				Vector2(rect.size.x, rect.size.y - cut)),
		]
	return []


# ------------------------------------------------------------- name rooms

## Assign kinds by publicness: the hall takes the front, bedrooms go to the
## back, and anything too small for the kind it was given becomes a store.
static func _name_rooms(p: HousePlan, spec: HouseSpec) -> void:
	var n: int = p.rooms.size()
	var inner: Rect2 = HouseGeometry.interior_rect(spec)

	# how far each room's centre sits from the middle of the front wall
	var order: Array[int] = []
	for i in range(n):
		order.append(i)
	var front := Vector2(0.0, inner.position.y)
	var dist := {}
	for i in range(n):
		var f: Rect2 = HouseGeometry.room_floor_rect(p, i)
		dist[i] = f.get_center().distance_to(front)
	order.sort_custom(func(a: int, b: int) -> bool: return dist[a] < dist[b])

	# the hall is the front-most room that can hold a hall; if none can, the
	# biggest room takes it, because a house must have somewhere to come in to
	var hall := -1
	for i in order:
		if HouseGeometry.room_suits(p, i, &"hall"):
			hall = i
			break
	if hall < 0:
		hall = _largest(p)
	p.rooms[hall]["kind"] = &"hall"

	# the rest of the program, most public first, over the remaining rooms
	# ordered from the door backwards
	var queue: Array[StringName] = []
	for kind in spec.program:
		if kind != &"hall":
			queue.append(kind)
	var rest: Array[int] = []
	for i in order:
		if i != hall:
			rest.append(i)

	for i in rest:
		var kind: StringName = queue.pop_front() if not queue.is_empty() else &"store"
		# a room too small for what it was going to be becomes a store, and the
		# kind it could not hold goes back for a bigger room later in the list
		if not HouseGeometry.room_suits(p, i, kind):
			if kind != &"store":
				queue.push_front(kind)
			kind = &"store"
		p.rooms[i]["kind"] = kind

	# bedrooms belong at the back: swap the front-most bedroom with the
	# back-most non-bedroom whenever that improves the arrangement
	_push_bedrooms_back(p, order)
	_demote_windowless(p, spec)


## A room with no outside wall can never have a window, so it cannot be a room
## anybody lives in. It becomes the store, and the store's kind goes to a room
## that does have a wall to the world.
static func _demote_windowless(p: HousePlan, spec: HouseSpec) -> void:
	for i in range(p.rooms.size()):
		if not HouseGeometry.is_habitable(p.kind_of(i)) or _has_outside_wall(p, spec, i):
			continue
		var swap := -1
		for j in range(p.rooms.size()):
			if p.kind_of(j) == &"store" and _has_outside_wall(p, spec, j) \
					and HouseGeometry.room_suits(p, j, p.kind_of(i)):
				swap = j
				break
		if swap >= 0:
			var mine: StringName = p.kind_of(i)
			p.rooms[i]["kind"] = &"store"
			p.rooms[swap]["kind"] = mine
		else:
			p.rooms[i]["kind"] = &"store"


static func _has_outside_wall(p: HousePlan, spec: HouseSpec, i: int) -> bool:
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	var rect: Rect2 = p.rooms[i]["rect"]
	return absf(rect.position.x - inner.position.x) < 0.01 \
		or absf(rect.end.x - inner.end.x) < 0.01 \
		or absf(rect.position.y - inner.position.y) < 0.01 \
		or absf(rect.end.y - inner.end.y) < 0.01


static func _push_bedrooms_back(p: HousePlan, order: Array[int]) -> void:
	var swapped := true
	var guard := 0
	while swapped and guard < 12:
		swapped = false
		guard += 1
		for a in range(order.size()):
			for b in range(order.size() - 1, a, -1):
				var ra: int = order[a]
				var rb: int = order[b]
				# ra is nearer the door than rb
				if p.kind_of(ra) == &"bedroom" and p.kind_of(rb) != &"bedroom" \
						and p.kind_of(rb) != &"hall":
					var ka: StringName = p.kind_of(ra)
					var kb: StringName = p.kind_of(rb)
					# only swap when both rooms can hold the other's kind
					if HouseGeometry.room_suits(p, ra, kb) \
							and HouseGeometry.room_suits(p, rb, ka):
						p.rooms[ra]["kind"] = kb
						p.rooms[rb]["kind"] = ka
						swapped = true
						break
			if swapped:
				break


static func _largest(p: HousePlan) -> int:
	var best := 0
	var area := -1.0
	for i in range(p.rooms.size()):
		var a: float = HouseGeometry.room_area(p, i)
		if a > area:
			area = a
			best = i
	return best


# ----------------------------------------------------------------- doors

## Where two rooms meet, and how much of that wall they share.
## Returns [] when they do not touch along a usable run.
static func _shared_edge(p: HousePlan, i: int, j: int) -> Array:
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
static func _place_doors(p: HousePlan, spec: HouseSpec) -> void:
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
				var edge: Array = _shared_edge(p, i, j)
				if edge.is_empty():
					continue
				var run: float = edge[3] - edge[2]
				if run < HouseGeometry.INNER_DOOR_W + HouseGeometry.DOOR_CORNER_MARGIN * 2.0:
					continue
				# prefer hanging a room off a public one, and prefer the widest
				# wall to hang it on
				var score: float = run
				if p.kind_of(i) == &"bedroom" or p.kind_of(i) == &"store":
					score -= 100.0        # only route through these as a last resort
				if p.kind_of(i) == &"hall":
					score += 20.0
				if score > best_score:
					best_score = score
					best = [i, j, edge]
		if best.is_empty():
			break
		joined[best[1]] = true
		_add_inner_door(p, best[0], best[1], best[2])

	_open_up_privacy(p)
	_demote_through_bedrooms(p)
	if spec.back_door:
		_place_back_door(p, spec)


## A spanning tree can leave the only route to a room running through a
## bedroom. Where that happened, look for a wall the stranded room shares with
## a room you may walk through, and cut a second door into it. That is what a
## builder would do, and it is cheaper than replanning the whole house.
static func _open_up_privacy(p: HousePlan) -> void:
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
		var added := false
		for j in range(p.rooms.size()):
			if j == stranded or p.kind_of(j) == &"bedroom" or not polite.has(j):
				continue
			var edge: Array = _shared_edge(p, j, stranded)
			if edge.is_empty():
				continue
			var run: float = edge[3] - edge[2]
			if run < HouseGeometry.INNER_DOOR_W + HouseGeometry.DOOR_CORNER_MARGIN * 2.0:
				continue
			if _door_between(p, j, stranded):
				continue
			_add_inner_door(p, j, stranded, edge)
			added = true
			break
		if not added:
			return


## If a bedroom is still the only way through to somewhere, it stops being a
## bedroom. A room people traipse through is a parlour if it is big enough to
## be one and a store otherwise -- which is what it actually is.
static func _demote_through_bedrooms(p: HousePlan) -> void:
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
static func _add_inner_door(p: HousePlan, a: int, b: int, edge: Array) -> void:
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
		"exterior": false, "front": false})


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
	var w: float = HouseGeometry.DOOR_W
	var m: float = HouseGeometry.DOOR_CORNER_MARGIN + w / 2.0
	var x: float = clampf(rect.get_center().x, rect.position.x + m, rect.end.x - m)
	p.doors.append({"a": room, "b": -1, "pos": Vector2(x, inner.position.y),
		"normal": Vector2(0, -1), "width": w, "exterior": true, "front": true})


## A back door out of the kitchen or the store, for the yard.
static func _place_back_door(p: HousePlan, spec: HouseSpec) -> void:
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	for kind in [&"kitchen", &"store", &"hall"]:
		for i in p.rooms_of(kind):
			var rect: Rect2 = p.rooms[i]["rect"]
			if absf(rect.end.y - inner.end.y) > 0.01:
				continue
			var w: float = HouseGeometry.DOOR_W
			var m: float = HouseGeometry.DOOR_CORNER_MARGIN + w / 2.0
			if rect.size.x < m * 2.0:
				continue
			var x: float = clampf(rect.get_center().x, rect.position.x + m, rect.end.x - m)
			p.doors.append({"a": i, "b": -1, "pos": Vector2(x, inner.end.y),
				"normal": Vector2(0, 1), "width": w, "exterior": true, "front": false})
			return


# ---------------------------------------------------------------- windows

## Windows on every exterior wall a room owns, enough of them to light it.
## Stores get one at most; a pantry does not need a view.
static func _place_windows(p: HousePlan, spec: HouseSpec) -> void:
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	for i in range(p.rooms.size()):
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
			_windows_along(p, spec, i, side, want, cap)
			got = 0.0
			for wi in p.windows_of(i):
				got += HouseGeometry.window_area(p.windows[wi])


## A last pass for any room people live in that still has no window.
##
## The even spacing above gives up easily: it keeps clear of the corners, of
## the doors and of its own neighbours, and on a short wall with a door in it
## there is nowhere left. A room with no daylight is worse than a window close
## to a corner, so this pass tries again with the margins pulled in.
static func _glaze_the_rest(p: HousePlan, spec: HouseSpec) -> void:
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	for i in range(p.room_count()):
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
			if _crowds(p, pos, normal, width):
				continue
			p.windows.append({"room": room, "pos": pos, "normal": normal,
				"width": width, "sill": HouseGeometry.WINDOW_SILL,
				"head": HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H})
			return true
	return false


## Is there already an opening too close to this one? The last-resort pass
## keeps only the masonry a lintel needs between two openings, rather than the
## comfortable spacing the first pass asks for.
static func _crowds(p: HousePlan, pos: Vector2, normal: Vector2, width: float) -> bool:
	for d in p.doors:
		if not _same_wall(d["pos"], d["normal"], pos, normal):
			continue
		if (Vector2(d["pos"]) - pos).length() < (float(d["width"]) + width) / 2.0 + 0.22:
			return true
	for w in p.windows:
		if not _same_wall(w["pos"], w["normal"], pos, normal):
			continue
		if (Vector2(w["pos"]) - pos).length() < (float(w["width"]) + width) / 2.0 + 0.22:
			return true
	return false


## Space windows evenly along one exterior wall of one room, skipping any slot
## that would land on a door.
static func _windows_along(p: HousePlan, spec: HouseSpec, room: int, side: Dictionary,
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
		if _clashes_with_door(p, pos, normal):
			continue
		if _clashes_with_window(p, pos, normal):
			continue
		p.windows.append({"room": room, "pos": pos, "normal": normal,
			"width": HouseGeometry.WINDOW_W, "sill": HouseGeometry.WINDOW_SILL,
			"head": HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H})
		var got := 0.0
		for wi in p.windows_of(room):
			got += HouseGeometry.window_area(p.windows[wi])
		if got >= want:
			return


static func _clashes_with_door(p: HousePlan, pos: Vector2, normal: Vector2) -> bool:
	for d in p.doors:
		if not _same_wall(d["pos"], d["normal"], pos, normal):
			continue
		var gap: float = (d["pos"] - pos).length()
		if gap < (float(d["width"]) + HouseGeometry.WINDOW_W) / 2.0 + 0.3:
			return true
	return false


static func _clashes_with_window(p: HousePlan, pos: Vector2, normal: Vector2) -> bool:
	for w in p.windows:
		if not _same_wall(w["pos"], w["normal"], pos, normal):
			continue
		if (w["pos"] - pos).length() < HouseGeometry.WINDOW_W + HouseGeometry.WINDOW_MIN_GAP - 0.05:
			return true
	return false


## Two openings are on the same wall when they share a normal axis and lie on
## the same line.
static func _same_wall(pa: Vector2, na: Vector2, pb: Vector2, nb: Vector2) -> bool:
	if absf(na.x) != absf(nb.x):
		return false
	if absf(na.x) > 0.5:
		return absf(pa.x - pb.x) < 0.02
	return absf(pa.y - pb.y) < 0.02
