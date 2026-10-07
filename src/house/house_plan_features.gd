class_name HousePlanFeatures
extends RefCounted
## Hearth and focus placement selected after circulation and glazing.

const BASE_HOUSE_SPEC := preload("res://src/house/house_spec.gd")

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
	# A room is only a hearth room if the fire will actually fit on one of its
	# outside walls. The planner used to take the first room of the right kind
	# and its best wall however short that wall's clear run was, so a kitchen
	# whose one outside wall was taken up by the back door and a window was
	# given a chimney with nowhere to light a fire under it, and the furnisher
	# had to give the kitchen's hearth up. The next room of a hearth-bearing
	# kind (the hall, then the workshop) takes the chimney instead; the kitchen
	# keeps its cooking fire but not the flue. Only when NO room can hold a
	# hearth does the longest short run win, as before.
	var need: float = hearth_run_needed()
	var room := -1
	var fallback := -1
	var door_blocked := false
	for kind in [&"kitchen", &"hall", &"workshop"]:
		for i in p.rooms_of(kind):
			if p.storey_of_room(i) != 0:
				continue
			var all_walls: Array[int] = _hearth_walls(p, spec, i)
			var candidates: Array[int] = _walls_clear_of_doors(p, spec, i, all_walls)
			door_blocked = door_blocked or candidates.size() < all_walls.size()
			if candidates.is_empty():
				continue
			if fallback < 0:
				fallback = i
			var longest := 0.0
			for wi in candidates:
				longest = maxf(longest, _clear_wall_run(p, i, wi))
			if longest >= need:
				room = i
				break
		if room >= 0:
			break
	if room < 0:
		room = fallback
	if room < 0:
		# a flue whose only possible wall has an exterior door under the stack
		# is not built at all (EVAL-C12): no chimney beats a chimney in a door
		if door_blocked:
			spec.chimney = false
		return
	var walls: Array[int] = _walls_clear_of_doors(p, spec, room, _hearth_walls(p, spec, room))
	var best: int = walls[0]
	var best_run := -INF
	for wi in walls:
		var run: float = _clear_wall_run(p, room, wi)
		if run > best_run:
			best_run = run
			best = wi
	p.hearth = {"room": room, "wall": best}


## The walls whose stack, centred on the middle of the wall's clear run, would
## not stand in an exterior door's opening (EVAL-C12).
static func _walls_clear_of_doors(p: HousePlan, spec: HouseSpec, room: int,
		walls: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for wi in walls:
		if not _stack_meets_door(p, spec, room, wi):
			out.append(wi)
	return out


## Would the chimney stack, centred on the middle of this wall's clear run (where
## HouseGeometry.chimney_center puts it), stand in an exterior door's opening?
static func _stack_meets_door(p: HousePlan, spec: HouseSpec, room: int, wi: int) -> bool:
	var span: Vector2 = clear_wall_span(p, room, wi)
	var along: float = (span.x + span.y) * 0.5
	var r: Rect2 = HouseGeometry.site_rect(spec)
	var s: float = HouseGeometry.chimney_size(spec)
	var c: Vector2
	match wi:
		0: c = Vector2(along, r.position.y - s / 2.0 + 0.15)
		1: c = Vector2(along, r.end.y + s / 2.0 - 0.15)
		2: c = Vector2(r.position.x - s / 2.0 + 0.15, along)
		_: c = Vector2(r.end.x + s / 2.0 - 0.15, along)
	var w: float = s + 0.22
	if spec.chimney_style == &"stepped":
		w = maxf(w, s + HouseGeometry.CHIMNEY_BASE_EXTRA)
	var stack := Rect2(c - Vector2.ONE * w * 0.5, Vector2.ONE * w)
	for d in p.doors:
		if not d.get("exterior", false) or bool(d.get("secret", false)):
			continue
		if stack.intersection(HouseGeometry.door_opening_rect(spec, d)).get_area() > 0.0001:
			return true
	return false


## The clear stretch of outside wall a hearth needs: the widest hearth in the
## catalogue and the chimney breast built round it (HouseGeometry.breast_for_hearth
## adds 0.4 m to the piece's width). Measured from the catalogue, not authored.
static func hearth_run_needed() -> float:
	var widest := 0.0
	for key in PropCatalog.of_category("hearth"):
		widest = maxf(widest, PropCatalog.footprint(key).x)
	return widest + 0.4


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
	var shared_room: int = _shared_cooking_hall(p, _spec)
	var cooking_region := Rect2()
	if shared_room >= 0:
		cooking_region = _assign_shared_activity_regions(p, _spec, shared_room)
	var room: int = p.hearth_room()
	var wi: int = p.hearth_wall()
	if room < 0 or wi < 0:
		return
	if room == shared_room and not cooking_region.has_area():
		# The legacy wall focus is safer than pinning a hearth to an unusable
		# half-wall when doors or windows consume the cooking band's clear run.
		p.focus = focus_on_wall(p, room, wi, "hearth", false)
		return
	if room == shared_room:
		var prefer_rear_end: bool = wi >= 2
		var prefer: float = _focus_coordinate_in_region(p, room, wi, cooking_region,
			prefer_rear_end)
		if not is_finite(prefer):
			# Do not force the hearth onto a wall position outside its cooking
			# region. Remove the bands so consumers use their established layout.
			var room_data: Dictionary = p.rooms[shared_room]
			room_data.erase("activity_regions")
			room_data["activity_regions_status"] = "unavailable: no hearth-width clear span in cooking band"
			p.rooms[shared_room] = room_data
			p.focus = focus_on_wall(p, room, wi, "hearth", false)
			return
		var preferred_focus: Dictionary = focus_on_wall(p, room, wi, "hearth", false, prefer)
		if _focus_inside_region(p, room, wi, preferred_focus, cooking_region):
			p.focus = preferred_focus
		else:
			var room_data: Dictionary = p.rooms[shared_room]
			room_data.erase("activity_regions")
			room_data["activity_regions_status"] = "unavailable: preferred hearth wall position escaped cooking band"
			p.rooms[shared_room] = room_data
			p.focus = focus_on_wall(p, room, wi, "hearth", false)
		return
	p.focus = focus_on_wall(p, room, wi, "hearth", false)


## A shared hall gets two actual clear-floor bands only in a plain, one-storey
## domestic house. Trades, adapters, world plans, cellars and upper floors keep
## their existing room-wide placement rules.
static func _shared_cooking_hall(p: HousePlan, spec: HouseSpec) -> int:
	if spec == null or spec.get_script() != BASE_HOUSE_SPEC or spec.trade != &"none" \
			or spec.storeys != 1 or spec.cellars != 0 or not p.world_family.is_empty() \
			or not HouseSpec.STYLES.get(spec.style, {}).has("domestic_program") \
			or spec.has_method("room_program") or spec.has_method("custom_room_rects") \
			or spec.has_method("landmark_footprint"):
		return -1
	for i in p.rooms_of(&"hall"):
		if p.storey_of_room(i) == 0 and bool(p.rooms[i].get("shared_cooking", false)):
			return i
	return -1


## Split along the room's longer clear-floor axis. The rear is positive Z in
## plan coordinates; when the long axis runs left-to-right, place cooking next
## to the selected hearth side or the side with a feasible hearth run.
static func _assign_shared_activity_regions(p: HousePlan, spec: HouseSpec,
		room: int) -> Rect2:
	var floor: Rect2 = HouseGeometry.room_floor_rect(p, room)
	if floor.size.x <= 0.0 or floor.size.y <= 0.0:
		return Rect2()
	var cooking := floor
	var eating := floor
	if floor.size.y >= floor.size.x:
		var split_y: float = floor.position.y + floor.size.y * 0.5
		eating.size.y = split_y - floor.position.y
		cooking.position.y = split_y
		cooking.size.y = floor.end.y - split_y
	else:
		var wall: int = p.hearth_wall() if p.hearth_room() == room else -1
		var cooking_left := wall == 2 or (wall < 0 and posmod(spec.seed, 2) == 0)
		if wall == 0 or wall == 1:
			cooking_left = _feasible_cooking_half(p, room, floor, wall)
		var split_x: float = floor.position.x + floor.size.x * 0.5
		eating.size.x = floor.size.x * 0.5
		cooking.size.x = floor.size.x * 0.5
		if cooking_left:
			cooking.position.x = floor.position.x
			eating.position.x = split_x
		else:
			cooking.position.x = split_x
			eating.position.x = floor.position.x
	var room_data: Dictionary = p.rooms[room]
	room_data["activity_regions"] = {&"cooking": cooking, &"eating": eating}
	room_data["activity_regions_status"] = "planned"
	p.rooms[room] = room_data
	return cooking


static func _feasible_cooking_half(p: HousePlan, room: int, floor: Rect2,
		wall: int) -> bool:
	var needed: float = hearth_run_needed()
	var left := Rect2(floor.position, Vector2(floor.size.x * 0.5, floor.size.y))
	var right := Rect2(Vector2(floor.position.x + floor.size.x * 0.5, floor.position.y),
		Vector2(floor.size.x * 0.5, floor.size.y))
	var left_run := _best_region_wall_run(p, room, wall, left)
	var right_run := _best_region_wall_run(p, room, wall, right)
	if left_run >= needed and right_run < needed:
		return true
	if right_run >= needed and left_run < needed:
		return false
	if left_run != right_run:
		return left_run > right_run
	return posmod(p.spec.seed, 2) == 0


static func _best_region_wall_run(p: HousePlan, room: int, wall: int,
		region: Rect2) -> float:
	var horizontal: bool = wall <= 1
	var region_lo: float = region.position.x if horizontal else region.position.y
	var region_hi: float = region.end.x if horizontal else region.end.y
	var best := 0.0
	for span in clear_wall_spans(p, room, wall):
		var overlap: float = minf(span.y, region_hi) - maxf(span.x, region_lo)
		best = maxf(best, overlap)
	return best


## Return a preferred along-wall coordinate only when a whole hearth plus
## breast fits on a clear stretch inside the cooking band.
static func _focus_coordinate_in_region(p: HousePlan, room: int, wall: int,
		region: Rect2, prefer_hi_end: bool = false) -> float:
	var horizontal: bool = wall <= 1
	var lo: float = region.position.x if horizontal else region.position.y
	var hi: float = region.end.x if horizontal else region.end.y
	var half_needed: float = hearth_run_needed() * 0.5
	var region_centre: float = (lo + hi) * 0.5
	# Leave the return wall usable by shallow storage, including its backing
	# gap, instead of letting the hearth approach clip that wall's fittings.
	var target: float = hi - half_needed - 0.2 if prefer_hi_end else region_centre
	var preferred := target
	var best_distance := INF
	var found := false
	for span in clear_wall_spans(p, room, wall):
		var valid_lo: float = maxf(span.x + half_needed, lo + half_needed)
		var valid_hi: float = minf(span.y - half_needed, hi - half_needed)
		if valid_hi < valid_lo:
			continue
		var at: float = clampf(target, valid_lo, valid_hi)
		var distance: float = absf(at - target)
		if distance < best_distance:
			best_distance = distance
			preferred = at
			found = true
	return preferred if found else INF


static func _focus_inside_region(p: HousePlan, room: int, wall: int,
		focus: Dictionary, region: Rect2) -> bool:
	if focus.is_empty() or not region.has_area():
		return false
	var normal: Vector2 = HouseGeometry.room_walls(p, room)[wall]["normal"]
	var inside: Vector2 = Vector2(focus["pos"]) + normal * 0.05
	return region.has_point(inside)


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
