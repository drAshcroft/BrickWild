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
	if spec.storeys > 1:
		_clone_upper_storeys(p, spec)
	_choose_hearth(p, spec)
	return p


## A room that could not be given a window is not a room anybody lives in.
##
## _demote_windowless catches the rooms with no outside wall at all; this one
## catches the rest -- a kitchen whose only stretch of outside wall is taken up
## by the back door has nowhere left to put a window, and calling it a kitchen
## anyway would leave the daylight check failing forever. It becomes the store,
## and the store's kind goes to a room that does have daylight.
static func _demote_unlit(p: HousePlan, only: Array[int] = []) -> void:
	var rooms: Array[int] = only if not only.is_empty() else _all_rooms(p)
	for i in rooms:
		if not HouseGeometry.is_habitable(p.kind_of(i)) or not p.windows_of(i).is_empty():
			continue
		var swap := -1
		for j in rooms:
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
		p.rooms.append({"kind": &"hall", "rect": rect, "storey": 0})


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
	var deferred: Array[StringName] = []
	for kind in spec.program:
		if kind == &"hall":
			continue
		# A house with an upstairs sleeps upstairs. The ground floor keeps the
		# public and service programme -- hall, kitchen, parlour, workshop,
		# store -- and a bedroom only lands down here when the rooms outlast
		# the kinds that want them.
		if kind == &"bedroom" and _has_upstairs(spec) and _can_sleep_upstairs(p):
			deferred.append(kind)
		else:
			queue.append(kind)
	queue.append_array(deferred)
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


static func _all_rooms(p: HousePlan) -> Array[int]:
	var out: Array[int] = []
	for i in range(p.rooms.size()):
		out.append(i)
	return out


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
	var w: float = HouseGeometry.DOOR_W
	var m: float = HouseGeometry.DOOR_CORNER_MARGIN + w / 2.0
	var x: float = clampf(rect.get_center().x, rect.position.x + m, rect.end.x - m)
	p.doors.append({"a": room, "b": -1, "pos": Vector2(x, inner.position.y),
		"normal": Vector2(0, -1), "width": w, "exterior": true, "front": true,
		"storey": p.storey_of_room(room)})


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
				"normal": Vector2(0, 1), "width": w, "exterior": true, "front": false,
				"storey": p.storey_of_room(i)})
			return


# ---------------------------------------------------------------- windows

## Windows on every exterior wall a room owns, enough of them to light it.
## Stores get one at most; a pantry does not need a view.
static func _place_windows(p: HousePlan, spec: HouseSpec, only: Array[int] = []) -> void:
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	var rooms: Array[int] = only if not only.is_empty() else _all_rooms(p)
	for i in rooms:
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
static func _glaze_the_rest(p: HousePlan, spec: HouseSpec, only: Array[int] = []) -> void:
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	var rooms: Array[int] = only if not only.is_empty() else _all_rooms(p)
	for i in rooms:
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


# ---------------------------------------------------------- stacked storeys

## The first storey is deliberately planned by the original path above. Higher
## storeys reuse that finished partition -- the walls have to line up, a
## partition cannot start in mid-air -- but NOT its programme. A cloned kitchen
## upstairs is a second fire with no flue and a hall with no front door; what
## belongs up a stair is where the household sleeps.
##
## So each upper storey keeps the cloned rectangles and the cloned interior
## doors, and is then NAMED afresh from the stair landing outwards, private
## programme first, and GLAZED afresh by those new kinds. Exterior doors stay
## on the ground floor; the stair is the only way between levels.
static func _clone_upper_storeys(p: HousePlan, spec: HouseSpec) -> void:
	var base_rooms: Array[int] = p.rooms_on_storey(0)
	var base_doors: Array[Dictionary] = []
	for door in p.doors:
		if not door["exterior"] and p.storey_of_room(int(door["a"])) == 0:
			base_doors.append(door)
	var base_windows: Array[Dictionary] = p.windows.duplicate()
	var dwelling: bool = _has_upstairs(spec)
	var hall_by_storey: Dictionary = {}
	for room in base_rooms:
		if p.kind_of(room) == &"hall":
			hall_by_storey[0] = room
			break
	if not hall_by_storey.has(0) and not base_rooms.is_empty():
		hall_by_storey[0] = base_rooms[0]

	for storey in range(1, spec.storeys):
		var remap: Dictionary = {}
		var mine: Array[int] = []
		for source in base_rooms:
			var room := p.rooms[source].duplicate()
			room["storey"] = storey
			var target: int = p.rooms.size()
			p.rooms.append(room)
			remap[source] = target
			mine.append(target)
			if p.kind_of(source) == &"hall":
				hall_by_storey[storey] = target

		for source_door in base_doors:
			var door := source_door.duplicate()
			door["a"] = remap[int(source_door["a"])]
			door["b"] = remap[int(source_door["b"])]
			door["storey"] = storey
			p.doors.append(door)

		# Link adjacent levels so every upper floor has a real route from the
		# front door, including the third storey, without treating a stair as a
		# horizontal door.
		var lower_hall: int = int(hall_by_storey.get(storey - 1,
			hall_by_storey[0]))
		var upper_hall: int = int(hall_by_storey.get(storey, -1))
		if upper_hall >= 0:
			_add_stair(p, lower_hall, upper_hall, storey - 1, storey)

		if dwelling and upper_hall >= 0:
			_name_upstairs(p, mine, upper_hall)
			_place_windows(p, spec, mine)
			_glaze_the_rest(p, spec, mine)
			_demote_unlit(p, mine)
		else:
			# A shop or any other building that brought its own room programme
			# keeps the old copy-the-ground-floor behaviour.
			for source_window in base_windows:
				var window := source_window.duplicate()
				window["room"] = remap[int(source_window["room"])]
				window["storey"] = storey
				p.windows.append(window)

	if dwelling:
		# The upper floors are full of bedrooms now, so the privacy rules have
		# to be re-run over the whole house: a store you can only reach across
		# somebody's bed is the same defect upstairs as down.
		_open_up_privacy(p)
		_ensure_bedrooms_upstairs(p, spec)
		_demote_through_bedrooms(p)
		_ensure_a_bed(p)


## Would the upper storey be able to hold a bedroom at all?
##
## The upper floors are clones of the ground partition, so this is the same
## question asked of the rooms in front of us. A narrow cottage whose rooms are
## all too thin for a bed does not get its bedrooms deferred upstairs -- it
## would end up with nowhere at all to sleep, and a house with no bedroom puts
## the bed in the hall.
static func _can_sleep_upstairs(p: HousePlan) -> bool:
	for i in range(p.rooms.size()):
		if HouseGeometry.room_suits(p, i, &"bedroom"):
			return true
	return false


## Is this a plain dwelling, the kind that sleeps upstairs?
##
## A ShopSpec (and anything else that hands the planner its own programme
## through `room_program`) means the storeys were asked for by a building that
## already knows what goes on each of them, so leave its floors alone. Duck
## typing rather than a class test, so the house package keeps no dependency on
## the shop package.
static func _has_upstairs(spec: HouseSpec) -> bool:
	return int(spec.storeys) > 1 and not spec.has_method("room_program")


## Name one upper storey, private-first, with the stair landing as its pole.
##
## Downstairs the front door is the public end of the house and the plan is
## ordered away from it. Upstairs the stair is the front door: the room you
## step off it into is the one everybody crosses, so it takes the most public
## kind the floor has, and the rooms nobody crosses -- the leaves of the door
## tree, which was cloned from the ground floor along with the walls -- are
## where the household sleeps.
##
## Naming by the tree rather than by distance alone is what keeps the privacy
## rule true by construction: a bedroom is only ever a leaf, so no room is ever
## put behind a bed.
static func _name_upstairs(p: HousePlan, mine: Array[int], landing: int) -> void:
	var order: Array[int] = _upstairs_order(p, mine, landing)
	var leaf: Dictionary = _leaves(p, mine, landing)
	for i in order:
		# the landing, and any room crossed to reach another, is public ground;
		# only a dead end is somebody's own
		var private: bool = i != landing and bool(leaf.get(i, false))
		var kind: StringName = &"bedroom" if private else &"parlour"
		if not HouseGeometry.room_suits(p, i, kind):
			kind = &"store"
		p.rooms[i]["kind"] = kind


## The rooms of one upper storey, most public first: by how far they sit from
## the stairwell, which is the same measure `_name_rooms` takes from the front
## door downstairs.
static func _upstairs_order(p: HousePlan, mine: Array[int], landing: int) -> Array[int]:
	var pole: Vector2 = HouseGeometry.room_floor_rect(p, landing).get_center()
	for stair in p.stairs:
		if int(stair.get("b", -1)) == landing:
			pole = Rect2(stair["upper_rect"]).get_center()
			break
	var dist := {}
	for i in mine:
		dist[i] = HouseGeometry.room_floor_rect(p, i).get_center().distance_to(pole)
	var order: Array[int] = mine.duplicate()
	order.sort_custom(func(a: int, b: int) -> bool: return dist[a] < dist[b])
	return order


## Which rooms of one storey are dead ends -- reached from the landing and
## leading nowhere further. Those, and only those, may be bedrooms.
static func _leaves(p: HousePlan, mine: Array[int], landing: int) -> Dictionary:
	var adj := {}
	for i in mine:
		adj[i] = []
	for d in p.doors:
		var a: int = int(d["a"])
		var b: int = int(d["b"])
		if b < 0 or not adj.has(a) or not adj.has(b):
			continue
		adj[a].append(b)
		adj[b].append(a)
	var seen := {landing: true}
	var queue: Array[int] = [landing]
	var children := {landing: 0}
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for nb in adj[cur]:
			if seen.has(nb):
				continue
			seen[nb] = true
			children[cur] = int(children.get(cur, 0)) + 1
			children[nb] = int(children.get(nb, 0))
			queue.append(nb)
	var out := {}
	for i in mine:
		# a room the tree never reached is nobody's route either
		out[i] = int(children.get(i, 0)) == 0
	return out


## An upper storey with nobody sleeping on it is not what the stair was for.
##
## `_name_upstairs` will only make a dead end a bedroom, and on a narrow plan
## every dead end is too thin for a bed while the landing is not. Rather than
## leave the floor as a parlour and a cupboard, try the rooms again from the
## far end: take the first one that can hold a bed AND still leaves every other
## room reachable without crossing it. On a two-room floor whose only bedroom
## candidate is the landing itself that finds nothing, which is the right
## answer -- a bedroom you have to walk through to reach the back room is the
## defect this whole pass exists to avoid.
static func _ensure_bedrooms_upstairs(p: HousePlan, spec: HouseSpec) -> void:
	var start: int = p.entrance_room()
	for storey in range(1, int(spec.storeys)):
		var mine: Array[int] = p.rooms_on_storey(storey)
		var slept := false
		for i in mine:
			if p.kind_of(i) in HouseGeometry.SLEEPING:
				slept = true
				break
		if slept:
			continue
		var landing: int = _landing_of(p, storey)
		var order: Array[int] = _upstairs_order(p, mine, landing)
		order.reverse()               # furthest from the stair first
		for i in order:
			if not HouseGeometry.room_suits(p, i, &"bedroom"):
				continue
			var was: StringName = p.kind_of(i)
			p.rooms[i]["kind"] = &"bedroom"
			_open_up_privacy(p)
			if _privacy_holds(p, start):
				break
			p.rooms[i]["kind"] = was


## The room an upper storey is entered into: the top of its stair.
static func _landing_of(p: HousePlan, storey: int) -> int:
	for stair in p.stairs:
		if int(stair.get("to_storey", -1)) == storey:
			return int(stair.get("b", -1))
	var mine: Array[int] = p.rooms_on_storey(storey)
	return mine[0] if not mine.is_empty() else -1


## A house has to have somewhere to sleep.
##
## The programme sends the bedrooms upstairs, and a floor of rooms too thin for
## a bed can send none of them back. Rather than leave a dwelling with no bed
## at all -- which the furnisher then has to squeeze into the hall, and often
## cannot -- promote the best candidate: the highest, most private room that
## can hold a bed and that nobody has to walk through to get anywhere.
static func _ensure_a_bed(p: HousePlan) -> void:
	for i in range(p.rooms.size()):
		if p.kind_of(i) in HouseGeometry.SLEEPING:
			return
	var start: int = p.entrance_room()
	var order: Array[int] = _all_rooms(p)
	order.sort_custom(func(a: int, b: int) -> bool:
		if p.storey_of_room(a) != p.storey_of_room(b):
			return p.storey_of_room(a) > p.storey_of_room(b)
		return HouseGeometry.room_area(p, a) > HouseGeometry.room_area(p, b))
	for i in order:
		if i == start or p.kind_of(i) == &"hall":
			continue
		if not HouseGeometry.room_suits(p, i, &"bedroom"):
			continue
		var was: StringName = p.kind_of(i)
		p.rooms[i]["kind"] = &"bedroom"
		if _privacy_holds(p, start):
			return
		p.rooms[i]["kind"] = was


## Can every room still be reached without crossing somewhere somebody sleeps?
static func _privacy_holds(p: HousePlan, start: int) -> bool:
	if start < 0:
		return true
	var polite: Dictionary = p.reachable_rooms(start, HouseGeometry.SLEEPING)
	for i in range(p.rooms.size()):
		if p.kind_of(i) == &"bedroom":
			continue
		if not polite.has(i):
			return false
	return true


## Add one stair in the hall equivalent on each of two adjacent levels. The
## landing is kept as an explicit rectangle so layered navigation and a future
## builder can agree on the opening without deriving it from the mesh.
##
## The stairwell runs along the room's LONG axis. Laid the other way it spans
## the short one and walls the room in half: a 4.9 x 3.0 m hall with a 2.4 m
## well across it has two 2 m stubs either side of the well and no way past the
## table, which is how a smith's workshop ended up unreachable from his own
## front door. (Moving it off the middle and against a wall is LAY-005.)
static func _add_stair(p: HousePlan, lower_room: int, upper_room: int,
		lower_storey: int, upper_storey: int) -> void:
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(p, lower_room)
	var along_x: bool = floor_rect.size.x > floor_rect.size.y
	var long_side: float = maxf(floor_rect.size.x, floor_rect.size.y)
	var short_side: float = minf(floor_rect.size.x, floor_rect.size.y)
	var run: float = minf(2.4, maxf(HouseGeometry.PATH_MIN, long_side - 0.3))
	var width: float = minf(1.0, maxf(HouseGeometry.PATH_MIN, short_side - 0.3))
	var centre := floor_rect.get_center()
	var size := Vector2(run, width) if along_x else Vector2(width, run)
	var footprint := Rect2(centre - size / 2.0, size)
	p.stairs.append({
		"a": lower_room, "b": upper_room,
		"storey": lower_storey, "to_storey": upper_storey,
		"pos": centre, "lower_pos": centre, "upper_pos": centre,
		"rect": footprint, "lower_rect": footprint, "upper_rect": footprint,
		"width": width, "run": run,
	})


## Decide once, here, which wall the fire and the flue share.
##
## The builder used to pick the chimney's wall and the furnisher used to pick
## the hearth's, so as often as not the fire stood against a partition while
## the stack rose from the other side of the house. The plan owns the position
## now -- HouseGeometry owns the shell, HousePlanner owns the hearth -- and the
## builder, the furnisher and the check all read this one record.
##
## The room is the kitchen, else the hall, else the workshop, always on the
## ground floor (there is one chimney per house, however many storeys). The
## wall is the exterior wall of that room with the longest clear run left over
## once its doors and windows have taken their share, so the hearth the
## furnisher is forced onto it actually fits.
static func _choose_hearth(p: HousePlan, spec: HouseSpec) -> void:
	p.hearth = {}
	var room := -1
	for kind in [&"kitchen", &"hall", &"workshop"]:
		for i in p.rooms_of(kind):
			if p.storey_of_room(i) != 0:
				continue
			if _hearth_walls(p, spec, i).is_empty():
				continue
			room = i
			break
		if room >= 0:
			break
	if room < 0:
		return
	var walls: Array[int] = _hearth_walls(p, spec, room)
	var best: int = walls[0]
	var best_run := -INF
	for wi in walls:
		var run: float = _clear_wall_run(p, room, wi)
		if run > best_run:
			best_run = run
			best = wi
	p.hearth = {"room": room, "wall": best}


## Which of a room's four walls are on the outside of the house. A chimney
## rises up the outside face; one on a partition would come out through the
## middle of the roof over another room.
static func _hearth_walls(p: HousePlan, spec: HouseSpec, i: int) -> Array[int]:
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	var rect: Rect2 = p.rooms[i]["rect"]
	var out: Array[int] = []
	# same order as HouseGeometry.room_walls: front, back, left, right
	if absf(rect.position.y - inner.position.y) < 0.01:
		out.append(0)
	if absf(rect.end.y - inner.end.y) < 0.01:
		out.append(1)
	if absf(rect.position.x - inner.position.x) < 0.01:
		out.append(2)
	if absf(rect.end.x - inner.end.x) < 0.01:
		out.append(3)
	return out


## The longest UNBROKEN stretch of a wall, once its doors and windows have
## taken theirs. Total clear length is the wrong measure: a wall with a window
## in the middle has plenty of room and nowhere to put a hearth.
static func _clear_wall_run(p: HousePlan, room: int, wi: int) -> float:
	var wall: Dictionary = HouseGeometry.room_walls(p, room)[wi]
	var from: Vector2 = wall["from"]
	var to: Vector2 = wall["to"]
	var horizontal: bool = absf(wall["normal"].y) > 0.5
	var lo: float = from.x if horizontal else from.y
	var hi: float = to.x if horizontal else to.y
	var line: float = from.y if horizontal else from.x
	var cuts: Array[Vector2] = []          # (start, end) along the wall
	for d in p.doors_of(room):
		var door: Dictionary = p.doors[d]
		if HousePlan.record_storey(door) != p.storey_of_room(room):
			continue
		if (absf(door["normal"].y) > 0.5) != horizontal:
			continue
		var at: float = door["pos"].x if horizontal else door["pos"].y
		var across: float = door["pos"].y if horizontal else door["pos"].x
		if absf(across - line) > 0.5:
			continue
		var half: float = float(door["width"]) / 2.0 + HouseGeometry.DOOR_CLEAR
		cuts.append(Vector2(at - half, at + half))
	for w in p.windows_of(room):
		var win: Dictionary = p.windows[w]
		if (absf(win["normal"].y) > 0.5) != horizontal:
			continue
		var at_w: float = win["pos"].x if horizontal else win["pos"].y
		var across_w: float = win["pos"].y if horizontal else win["pos"].x
		if absf(across_w - line) > 0.5:
			continue
		var half_w: float = float(win["width"]) / 2.0 + 0.15
		cuts.append(Vector2(at_w - half_w, at_w + half_w))
	# A door in a wall at right angles to this one eats the end of it: the
	# floor it swings over lies along this wall's last stretch.
	for d2 in p.doors_of(room):
		var side_door: Dictionary = p.doors[d2]
		if HousePlan.record_storey(side_door) != p.storey_of_room(room):
			continue
		if (absf(side_door["normal"].y) > 0.5) == horizontal:
			continue
		var along: float = side_door["pos"].x if horizontal else side_door["pos"].y
		var off: float = side_door["pos"].y if horizontal else side_door["pos"].x
		if absf(off - line) > HouseGeometry.DOOR_CLEAR + 0.6:
			continue
		cuts.append(Vector2(along - HouseGeometry.DOOR_CLEAR,
			along + HouseGeometry.DOOR_CLEAR))
	cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var best := 0.0
	var cursor: float = lo
	for cut in cuts:
		best = maxf(best, cut.x - cursor)
		cursor = maxf(cursor, cut.y)
	return maxf(best, hi - cursor)
