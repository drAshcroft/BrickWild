class_name HousePlanRooms
extends RefCounted
## Ground-floor subdivision and room programme.

const MIN_SPLIT := 0.36
const MAX_SPLIT := 0.64

# --------------------------------------------------------------- subdivide

## Split the interior until there are `spec.room_count` rooms or nothing can be
## split any further without making a cupboard.
static func subdivide(p: HousePlan, spec: HouseSpec) -> void:
	if spec.has_method("custom_room_rects"):
		var custom: Array[Rect2] = spec.custom_room_rects(HouseGeometry.interior_rect(spec))
		if custom.size() == maxi(spec.room_count, 1):
			for rect in custom:
				p.rooms.append({"kind": &"hall", "rect": rect, "storey": 0})
			return
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

## How strongly each kind is drawn to the two poles of a house (LAY-006): the
## FRONT, where the door and the street are, and the SERVICE end at the back,
## where the yard, the well and the midden are. The hall and the parlour want
## the front; the kitchen and the store want the back, so the back door lands
## on the kitchen where it belongs; a bedroom wants neither, and is pushed
## away from both. A kind not listed here sits in the middle. One pole was
## the old rule and it put the kitchen beside the front door, because it was
## second in the programme and second nearest the door was the best it could
## be given.
const KIND_POLES := {
	&"hall": {"front": 1.0, "service": 0.0},
	&"parlour": {"front": 0.8, "service": -0.2},
	&"dining_room": {"front": 0.8, "service": 0.0},
	&"sales_floor": {"front": 1.0, "service": 0.0},
	&"workshop": {"front": 0.5, "service": 0.2},
	&"kitchen": {"front": -0.2, "service": 1.0},
	&"store": {"front": -0.2, "service": 0.7},
	&"tack_room": {"front": 0.0, "service": 0.5},
	&"office": {"front": -0.2, "service": 0.3},
	&"records": {"front": -0.3, "service": 0.3},
	&"bedroom": {"front": -1.0, "service": -0.3},
	&"guest_room": {"front": -1.0, "service": -0.3},
	&"suite": {"front": -1.0, "service": -0.3},
	&"dormitory": {"front": -1.0, "service": 1.0},
	&"armoury": {"front": -0.3, "service": 0.3},
	&"mess": {"front": 0.8, "service": 0.0},
}


## How well room `i` answers what `kind` wants of the two poles: 1 at a pole
## it is drawn to, 0 at the far corner from it, negative where it is pushed.
static func _pole_score(p: HousePlan, spec: HouseSpec, i: int, kind: StringName) -> float:
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	var c: Vector2 = HouseGeometry.room_floor_rect(p, i).get_center()
	var front := Vector2(inner.get_center().x, inner.position.y)
	var back := Vector2(inner.get_center().x, inner.end.y)
	var reach: float = maxf(inner.size.length(), 0.01)
	var w: Dictionary = KIND_POLES.get(kind, {"front": 0.0, "service": 0.0})
	return float(w["front"]) * (1.0 - c.distance_to(front) / reach) \
		+ float(w["service"]) * (1.0 - c.distance_to(back) / reach)


## Assign kinds by publicness: the hall takes the front, the kitchen the back,
## bedrooms go away from both, and anything nothing wanted becomes a store.
static func name_rooms(p: HousePlan, spec: HouseSpec) -> void:
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
	# biggest room takes it, because a house must have somewhere to come in to.
	# A shop's hall becomes its public room afterwards, so it is measured
	# against what that room has to be -- a meeting hall wants a wider room
	# than a cottage hall does
	var hall_kind: StringName = &"hall"
	if spec.has_method("front_room"):
		hall_kind = spec.front_room()
	var hall := -1
	if spec.has_method("preferred_front_room_index"):
		var preferred: int = spec.preferred_front_room_index()
		if preferred >= 0 and preferred < n \
				and HouseGeometry.room_suits(p, preferred, hall_kind) \
				and HouseGeometry.room_suits(p, preferred, &"hall"):
			hall = preferred
	for i in order:
		if hall >= 0:
			break
		if HouseGeometry.room_suits(p, i, hall_kind) and HouseGeometry.room_suits(p, i, &"hall"):
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
		if kind == &"bedroom" and HousePlanLevels.has_upstairs(spec) and HousePlanLevels.can_sleep_upstairs(p):
			deferred.append(kind)
		else:
			queue.append(kind)
	queue.append_array(deferred)
	var rest: Array[int] = []
	for i in order:
		if i != hall:
			rest.append(i)

	# Each kind takes the room that best answers its two poles among those
	# that can hold it; ties go to the room nearer the door, which is the old
	# one-pole order. The kinds the service pole pulls hardest -- the kitchen
	# -- choose first, or a bedroom, which merely wants to be far from the
	# front, would take the back room the kitchen needs. What nothing claimed
	# is the store.
	for i in rest:
		p.rooms[i]["kind"] = &"store"
	var ordered: Array[StringName] = []
	for kind in queue:
		if float(KIND_POLES.get(kind, {"service": 0.0})["service"]) >= 0.9:
			ordered.append(kind)
	for kind2 in queue:
		if not kind2 in ordered:
			ordered.append(kind2)
	for kind in ordered:
		var best := -1
		var best_score := -INF
		for i in rest:
			if p.kind_of(i) != &"store" or not HouseGeometry.room_suits(p, i, kind):
				continue
			var score: float = _pole_score(p, spec, i, kind)
			if score > best_score + 0.0001:
				best_score = score
				best = i
		if best >= 0:
			p.rooms[best]["kind"] = kind

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
				# ra is nearer the door than rb; and a service room at the
				# back is there because the back is where it belongs (LAY-006)
				if p.kind_of(ra) == &"bedroom" and p.kind_of(rb) != &"bedroom" \
						and p.kind_of(rb) != &"hall" \
						and float(KIND_POLES.get(p.kind_of(rb), {"service": 0.0})["service"]) < 0.5:
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


static func all_rooms(p: HousePlan) -> Array[int]:
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
