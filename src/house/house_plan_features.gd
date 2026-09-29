class_name HousePlanFeatures
extends RefCounted
## Hearth and focus placement selected after circulation and glazing.

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
static func choose_hearth(p: HousePlan, spec: HouseSpec) -> void:
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
	if absf(rect.position.y - inner.position.y) < 0.01 and not (spec.jetty and spec.storeys > 1):
		out.append(0)
	if absf(rect.end.y - inner.end.y) < 0.01:
		out.append(1)
	if absf(rect.position.x - inner.position.x) < 0.01:
		out.append(2)
	if absf(rect.end.x - inner.end.x) < 0.01:
		out.append(3)
	return out


## What the house is arranged around. For a house it is the fire: the focus
## stands in the hearth room, on the hearth wall, at the middle of the clear
## run the chimney was chosen for, looking into the room. A shop overrides
## this with its counter, forge or bar (ShopPlanner), which must also face the
## door; a fireplace need not. The furnisher pins the piece to `pos`, and
## writes back where it actually stood, so the check that reads this record
## is comparing the plan with the furniture and not the plan with itself.
static func choose_focus(p: HousePlan, _spec: HouseSpec) -> void:
	p.focus = {}
	var room: int = p.hearth_room()
	var wi: int = p.hearth_wall()
	if room < 0 or wi < 0:
		return
	p.focus = focus_on_wall(p, room, wi, "hearth", false)


## A focus record for a piece backed to wall `wi` of `room`: at the middle of
## the wall's longest clear run, looking along the wall's inward normal.
static func focus_on_wall(p: HousePlan, room: int, wi: int, cat: String,
		faces_door: bool, prefer := INF) -> Dictionary:
	var wall: Dictionary = HouseGeometry.room_walls(p, room)[wi]
	var n: Vector2 = wall["normal"]
	var span: Vector2 = clear_wall_span(p, room, wi)
	var from: Vector2 = wall["from"]
	var horizontal: bool = absf(n.y) > 0.5
	var mid: float = (span.x + span.y) / 2.0
	# a piece that must look at the door stands square across from it, as
	# near its line as the clear runs of the wall allow: of every run wide
	# enough, the one that gets nearest
	if is_finite(prefer):
		var best := INF
		for s in clear_wall_spans(p, room, wi):
			if s.y - s.x < 1.2:
				continue
			var at: float = clampf(prefer, s.x + 0.6, s.y - 0.6)
			if absf(at - prefer) < best:
				best = absf(at - prefer)
				mid = at
	var pos: Vector2 = Vector2(mid, from.y) if horizontal else Vector2(from.x, mid)
	return {"room": room, "cat": cat, "pos": pos,
		"facing": atan2(-n.x, -n.y), "faces_door": faces_door}


## A focus record for a piece standing free in `room`: at the middle of the
## floor, looking along `facing` (a unit vector in plan space).
static func focus_in_room(p: HousePlan, room: int, cat: String,
		facing: Vector2, faces_door: bool) -> Dictionary:
	var f: Rect2 = HouseGeometry.room_floor_rect(p, room)
	return {"room": room, "cat": cat, "pos": f.get_center(),
		"facing": atan2(-facing.x, -facing.y), "faces_door": faces_door}


## The longest UNBROKEN stretch of a wall, once its doors and windows have
## taken theirs. Total clear length is the wrong measure: a wall with a window
## in the middle has plenty of room and nowhere to put a hearth.
static func _clear_wall_run(p: HousePlan, room: int, wi: int) -> float:
	var span: Vector2 = clear_wall_span(p, room, wi)
	return span.y - span.x


## The longest unbroken stretch itself, as (start, end) along the wall's own
## axis -- X for a front or back wall, Z for a side wall.
static func clear_wall_span(p: HousePlan, room: int, wi: int) -> Vector2:
	var best := Vector2.ZERO
	for span in clear_wall_spans(p, room, wi):
		if span.y - span.x > best.y - best.x:
			best = span
	return best


## Every unbroken stretch of a wall, as (start, end) along its own axis.
static func clear_wall_spans(p: HousePlan, room: int, wi: int) -> Array[Vector2]:
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
	# A stair standing against this wall (LAY-005) takes its stretch of it too:
	# a hearth pinned under the well would have no chimney breast to sit in.
	for stair in p.stairs:
		var srect := Rect2()
		if int(stair.get("a", -1)) == room:
			srect = Rect2(stair.get("lower_rect", stair.get("rect", Rect2())))
		elif int(stair.get("b", -1)) == room:
			srect = Rect2(stair.get("upper_rect", stair.get("rect", Rect2())))
		if srect.size.x <= 0.0:
			continue
		var touches: bool = (absf(srect.position.y - line) < 0.1 or absf(srect.end.y - line) < 0.1) \
			if horizontal else (absf(srect.position.x - line) < 0.1 or absf(srect.end.x - line) < 0.1)
		if not touches:
			continue
		if horizontal:
			cuts.append(Vector2(srect.position.x - 0.1, srect.end.x + 0.1))
		else:
			cuts.append(Vector2(srect.position.y - 0.1, srect.end.y + 0.1))
	cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var spans: Array[Vector2] = []
	var cursor: float = lo
	for cut in cuts:
		if cut.x - cursor > 0.05:
			spans.append(Vector2(cursor, cut.x))
		cursor = maxf(cursor, cut.y)
	if hi - cursor > 0.05:
		spans.append(Vector2(cursor, hi))
	if spans.is_empty():
		spans.append(Vector2(lo, lo))
	return spans

