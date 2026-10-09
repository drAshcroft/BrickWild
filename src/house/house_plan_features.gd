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
	var need: float = hearth_run_needed(spec, p)
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
	# HouseGenerator has already consumed the style's historical chimney chance.
	# A selected native domestic fireplace has a real shell host and therefore
	# requires its matching exterior flue; resolve that plan fact before upper
	# glazing reservation and furnishing. Specialist families retain the draw.
	if best_run >= need and _requires_native_domestic_flue(p, spec):
		spec.chimney = true


static func _requires_native_domestic_flue(p: HousePlan, spec: HouseSpec) -> bool:
	return p != null and p.world_family == &"" \
		and spec.get_script() == BASE_HOUSE_SPEC and spec.trade == &"none" \
		and spec.style in [&"farmhouse", &"cottage", &"thatch_cottage"] \
		and spec.allows_hearth_furniture()


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


## Required outside-wall run. Ordinary houses use their native masonry breast
## envelope; legacy and specialist families keep the catalogue-based allowance.
static func hearth_run_needed(spec: HouseSpec = null, plan: HousePlan = null) -> float:
	if spec != null and plan != null and plan.world_family == &"" \
			and spec.get_script() == BASE_HOUSE_SPEC \
			and spec.trade == &"none" and spec.style != &"witch_hut" \
			and spec.allows_hearth_furniture():
		return HouseGeometry.DOMESTIC_FIREPLACE_BREAST_WIDTH + 0.10
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
	var witch_hall: int = _shared_witchwork_hall(p, _spec)
	if witch_hall >= 0:
		shared_room = witch_hall
		cooking_region = _assign_compact_witch_hall_regions(p, shared_room)
	elif shared_room >= 0:
		cooking_region = _assign_shared_activity_regions(p, _spec, shared_room)
	else:
		shared_room = _shared_witchwork_kitchen(p, _spec)
		if shared_room >= 0:
			cooking_region = _assign_shared_kitchen_witchwork_regions(p, shared_room)
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
		# A compact Witch hall needs the fire between two distinct prep runs.
		# Center it on the selected side-wall span so it clears the front-wall
		# Witch bench and leaves the rear run available for cooking prep.
		var compact_mid_fire: bool = room == witch_hall and wi >= 2
		var prefer_rear_end: bool = wi >= 2 and not compact_mid_fire
		var hearth_region: Rect2 = cooking_region
		if compact_mid_fire:
			# Move the cauldron just behind the front station stance. The full
			# footprint must clear the bench use zone, not just its plan center.
			hearth_region.position.y += 0.50
			hearth_region.size.y -= 0.50
		var prefer: float = _focus_coordinate_in_region(p, room, wi, hearth_region,
			prefer_rear_end, false)
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
			if room == witch_hall:
				_relocate_compact_witch_workwall_window(p, room)
				_relocate_compact_witch_service_windows(p, room)
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
## The compact no-trade Witch fallback merges only kitchen and workshop into the
## front hall. A shared service reservation contains one physical fire and two distinct
## prep benches; meals occupy the opposite strip.
static func _shared_witchwork_hall(p: HousePlan, spec: HouseSpec) -> int:
	if spec == null or spec.get_script() != BASE_HOUSE_SPEC \
			 or spec.style != &"witch_hut" or spec.trade != &"none" \
			 or spec.storeys != 1 or spec.cellars != 0 or not p.world_family.is_empty():
		return -1
	if String(p.domestic_layout.get("status", "")) != "planned" \
			 or not p.domestic_layout.get("merged_activities", []).has(&"kitchen") \
			 or not p.domestic_layout.get("merged_activities", []).has(&"workshop"):
		return -1
	for room in p.rooms_of(&"hall"):
		var functions: Array = p.rooms[room].get("domestic_functions", [])
		if p.storey_of_room(room) == 0 and bool(p.rooms[room].get("shared_cooking", false)) \
				 and bool(p.rooms[room].get("shared_witchwork", false)) \
				 and functions.has(&"cooking") and functions.has(&"witchwork"):
			return room
	return -1


static func _assign_compact_witch_hall_regions(p: HousePlan, room: int) -> Rect2:
	var floor: Rect2 = HouseGeometry.room_floor_rect(p, room)
	# These are not promises for smaller rooms. The room programme marks their
	# impossibility upstream; do not emit undersized reservations here.
	if floor.size.x < 6.29 or floor.size.y < 4.61:
		var insufficient: Dictionary = p.rooms[room]
		insufficient.erase("activity_regions")
		insufficient["activity_regions_status"] = "unavailable: compact Witch stations need 6.29x4.61 clear hall"
		p.rooms[room] = insufficient
		return Rect2()
	var hearth_wall: int = p.hearth_wall() if p.hearth_room() == room else -1
	if hearth_wall not in [2, 3]:
		var unsupported: Dictionary = p.rooms[room]
		unsupported.erase("activity_regions")
		unsupported["activity_regions_status"] = "unavailable: compact Witch service requires a full side-wall chimney run"
		p.rooms[room] = unsupported
		return Rect2()
	# A single cauldron serves both crafts from the shared left/right service
	# area. Keep the complete hearth breast, use zone, and two distinct benches
	# in that area; reserve the opposite 2.1 m strip for the tested meal group.
	const SERVICE_WIDTH := 4.10
	const BUFFER_WIDTH := 0.10
	const MEAL_BAND_WIDTH := 2.10
	var required_width := SERVICE_WIDTH + BUFFER_WIDTH + MEAL_BAND_WIDTH
	if floor.size.x < required_width - 0.001 or floor.size.y < 4.61:
		var insufficient: Dictionary = p.rooms[room]
		insufficient.erase("activity_regions")
		insufficient["activity_regions_status"] = "unavailable: compact Witch needs a 4.10m shared service zone, 0.10m buffer, and 2.10m meal strip"
		p.rooms[room] = insufficient
		return Rect2()
	var cooking_left := hearth_wall == 2
	var service_x := floor.position.x if cooking_left else floor.end.x - SERVICE_WIDTH
	var eating_x := floor.end.x - MEAL_BAND_WIDTH if cooking_left else floor.position.x
	var cooking := Rect2(Vector2(service_x, floor.position.y),
		Vector2(SERVICE_WIDTH, floor.size.y))
	var witchwork := cooking
	var eating := Rect2(Vector2(eating_x, floor.position.y),
		Vector2(MEAL_BAND_WIDTH, floor.size.y))
	var room_data: Dictionary = p.rooms[room]
	room_data["activity_regions"] = {
		&"eating": eating, &"cooking": cooking, &"witchwork": witchwork,
	}
	room_data["activity_regions_status"] = "planned"
	room_data["shared_activity_station"] = {
		"id": "compact_witch_hearth", "category": "hearth",
		"scope": "compact_witch_shared_hall", "groups": [&"cooking", &"witchwork"], "max_usezone_distance": 1.9,
		"host_wall": hearth_wall,
	}
	p.rooms[room] = room_data
	return cooking


static func _shared_witchwork_kitchen(p: HousePlan, spec: HouseSpec) -> int:
	if spec == null or spec.get_script() != BASE_HOUSE_SPEC or spec.style != &"witch_hut" or spec.trade != &"none":
		return -1
	if spec.storeys != 1 or spec.cellars != 0 or not p.world_family.is_empty():
		return -1
	for room in p.rooms_of(&"kitchen"):
		if p.storey_of_room(room) == 0 and bool(p.rooms[room].get("shared_witchwork", false)):
			return room
	return -1


## Divide a compact shared service kitchen into real cooking and Witchwork bands.
## The dining group remains in the entry hall. Placement borrows the complement
## of each band rectangle; navigation and activity audits judge the result.
static func _assign_shared_kitchen_witchwork_regions(p: HousePlan, room: int) -> Rect2:
	var floor: Rect2 = HouseGeometry.room_floor_rect(p, room)
	if floor.size.x < 2.0 or floor.size.y < 2.0:
		return Rect2()
	var cooking := floor
	var witchwork := floor
	if floor.size.y >= floor.size.x:
		var split_y := floor.position.y + floor.size.y * 0.5
		cooking.size.y = split_y - floor.position.y
		witchwork.position.y = split_y
		witchwork.size.y = floor.end.y - split_y
	else:
		var split_x := floor.position.x + floor.size.x * 0.5
		cooking.size.x = split_x - floor.position.x
		witchwork.position.x = split_x
		witchwork.size.x = floor.end.x - split_x
	var room_data: Dictionary = p.rooms[room]
	room_data["activity_regions"] = {&"cooking": cooking, &"witchwork": witchwork}
	room_data["activity_regions_status"] = "planned"
	p.rooms[room] = room_data
	return cooking

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
	var needed: float = hearth_run_needed(p.spec, p)
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
		region: Rect2, prefer_hi_end: bool = false, prefer_lo_end: bool = false) -> float:
	var horizontal: bool = wall <= 1
	var lo: float = region.position.x if horizontal else region.position.y
	var hi: float = region.end.x if horizontal else region.end.y
	var half_needed: float = hearth_run_needed(p.spec, p) * 0.5
	var region_centre: float = (lo + hi) * 0.5
	# Leave the return wall usable by shallow storage, including its backing
	# gap, instead of letting the hearth approach clip that wall's fittings.
	var target: float = region_centre
	if prefer_hi_end:
		target = hi - half_needed - 0.2
	elif prefer_lo_end:
		target = lo + half_needed + 0.2
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
static func clear_wall_spans(p: HousePlan, room: int, wi: int,
		body_depth := 0.0) -> Array[Vector2]:
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
	# A wall fitting may project into a body-width stair approach even when the
	# wall face itself is clear. Clip only where the actual measured depth of the
	# candidate meets a reserved foot/head landing or access-route rectangle.
	if body_depth > 0.001:
		var band := _wall_body_band(wall, lo, hi, line, body_depth)
		for zone in p.zones:
			if int(zone.get("room", -1)) != room \
					or String(zone.get("why", "")) not in ["stair access route",
					"stair foot landing", "stair head landing"]:
				continue
			var overlap := band.intersection(Rect2(zone.get("rect", Rect2())))
			if overlap.size.x <= 0.01 or overlap.size.y <= 0.01:
				continue
			var cut := Vector2(overlap.position.x, overlap.end.x) if horizontal \
				else Vector2(overlap.position.y, overlap.end.y)
			cuts.append(Vector2(cut.x - 0.03, cut.y + 0.03))
	# Existing mounted models reserve their real projection only for callers
	# that supplied a measured body depth. Legacy span queries keep their old
	# behavior, including for adapters outside the ordinary-house compositor.
	if body_depth > 0.001:
		for fi in p.furniture_of(room):
			var item: Dictionary = p.furniture[fi]
			if not bool(item.get("mounted", false)):
				continue
			var item_wall := HouseFurnishScore._back_wall_index(p, room,
				Rect2(item.get("rect", Rect2())), item)
			if item_wall != wi:
				continue
			var item_extent := HouseFurnishScore._piece_projection(
				Rect2(item.get("rect", Rect2())), Vector2.RIGHT if horizontal else Vector2.DOWN,
				item)
			cuts.append(Vector2(item_extent.x - 0.03, item_extent.y + 0.03))
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


static func _wall_body_band(wall: Dictionary, lo: float, hi: float,
		line: float, body_depth: float) -> Rect2:
	var normal: Vector2 = wall["normal"]
	if absf(normal.y) > 0.5:
		var start_y := line if normal.y > 0.0 else line - body_depth
		return Rect2(Vector2(lo, start_y), Vector2(hi - lo, body_depth))
	var start_x := line if normal.x > 0.0 else line - body_depth
	return Rect2(Vector2(start_x, lo), Vector2(body_depth, hi - lo))


static func _note_activity_surface_unavailable(p: HousePlan, room: int, group_name: String) -> void:
	if group_name in ["cooking", "witchwork", "sleep"]:
		p.note_compromise(room, "surface:%s:no_safe_station" % group_name)


static func _activity_anchor_rank(group_name: String, category: String, item: Dictionary) -> int:
	match group_name:
		"cooking":
			return {"workbench": 0, "hearth": 1, "storage": 2}.get(category, 100)
		"witchwork":
			return {"workbench": 0, "hearth": 1, "shelf": 2}.get(category, 100)
		"sleep":
			# Reading belongs at the bedside nightstand; independent clothes storage
			# remains a fallback, while a head-end chest keeps its support role.
			if String(item.get("key", "")) == "Nightstand_Shelf":
				return 0
			if category == "chest":
				if String(item.get("activity_host_anchor", "")) == "head_end":
					return 100
				return 1
			return {"bed": 2}.get(category, 100)
		"eating":
			return {"table": 0, "bench": 1}.get(category, 100)
		"sitting":
			return {"bench": 0, "seat": 1}.get(category, 100)
	return 100


static func _mounted_dimensions(key: String, wall: Dictionary) -> Vector2:
	var yaw := PropCatalog.yaw_facing(Vector2(wall["normal"]))
	var footprint := PropCatalog.footprint_rotated(key,
		yaw + PropCatalog.face_offset(key))
	return Vector2(footprint.x, footprint.y)


static func _activity_mount_depth(group_name: String, style: StringName,
		wall: Dictionary) -> float:
	var keys: Array[String] = []
	if group_name in ["cooking", "witchwork"]:
		keys = ["Torch_Metal", "Shelf_Small_Bottles" if style == &"witch_hut" else "Shelf_Simple"]
	elif group_name == "sleep":
		keys = ["Shelf_Simple"]
	var horizontal := absf(Vector2(wall["normal"]).y) > 0.5
	var depth := HouseGeometry.BEAM_D
	for key in keys:
		var dimensions := _mounted_dimensions(key, wall)
		depth = maxf(depth, dimensions.y if horizontal else dimensions.x)
	return depth


static func _wall_point(wall: Dictionary, along: float) -> Vector2:
	var normal: Vector2 = wall["normal"]
	return Vector2(along, wall["from"].y) if absf(normal.y) > 0.5 \
		else Vector2(wall["from"].x, along)


static func _append_wall_host(p: HousePlan, room: int, wall_index: int,
		span: Vector2, wall: Dictionary, role: String, group_name: String,
		anchor_id: String, category: String, host_id: String) -> void:
	var from := _wall_point(wall, span.x)
	var to := _wall_point(wall, span.y)
	p.wall_hosts.append({"id": host_id, "room": room,
		"storey": p.storey_of_room(room), "wall": wall_index,
		"from": from, "to": to, "normal": wall["normal"], "span": span,
		"role": role, "activity_group": group_name,
		"anchor_id": anchor_id, "target_category": category})


static func _clear_wall_mount_center(p: HousePlan, room: int, wall_index: int,
		anchor_extent: Vector2, desired: float, width: float,
		depth: float) -> float:
	var best := INF
	var best_gap := INF
	for clear_span in clear_wall_spans(p, room, wall_index, depth):
		var lo := maxf(clear_span.x + width * 0.5,
			anchor_extent.x - 0.1 + width * 0.5)
		var hi := minf(clear_span.y - width * 0.5,
			anchor_extent.y + 0.1 - width * 0.5)
		if hi < lo:
			continue
		var candidate := clampf(desired, lo, hi)
		var gap := absf(candidate - desired)
		if gap < best_gap:
			best = candidate
			best_gap = gap
	return best


static func _wall_fixture_pose(key: String, wall: Dictionary, along: float,
		base_height: float, scale: float) -> Dictionary:
	var normal: Vector2 = wall["normal"]
	var point := _wall_point(wall, along)
	# HouseAssembler applies face_offset to this semantic record yaw.
	var yaw := PropCatalog.yaw_facing(normal)
	var model_yaw := yaw + PropCatalog.face_offset(key)
	var dimensions := PropCatalog.footprint_rotated(key, model_yaw) * scale
	var horizontal := absf(normal.y) > 0.5
	var depth := dimensions.y if horizontal else dimensions.x
	var desired_centre := point + normal * depth * 0.5
	var seed_placement := {"key": key, "pos": Vector3(point.x, base_height, point.y),
		"yaw": yaw, "scale": scale}
	var seed_origin := PropCatalog.house_origin(seed_placement)
	var seed_centre := PropCatalog.plan_centre(key, seed_origin, model_yaw, scale)
	var corrected_point := point + desired_centre - seed_centre
	var placement := {"key": key, "pos": Vector3(corrected_point.x, base_height, corrected_point.y),
		"yaw": yaw, "scale": scale}
	var origin := PropCatalog.house_origin(placement)
	var centre := PropCatalog.plan_centre(key, origin, model_yaw, scale)
	return {"pos": placement["pos"], "yaw": yaw, "origin": origin,
		"centre": centre, "rect": Rect2(centre - dimensions * 0.5, dimensions),
		"dimensions": dimensions, "bottom": origin.y + PropCatalog.floor_offset(key) * scale,
		"top": origin.y + (PropCatalog.floor_offset(key) + PropCatalog.height(key)) * scale}


static func _append_wall_mount(p: HousePlan, room: int, wall_index: int,
		wall: Dictionary, anchor_extent: Vector2, desired_along: float,
		key: String, pivot_height: float, group_name: String,
		anchor_id: String, relation: String, suffix: String) -> int:
	if not PropCatalog.PROPS.has(key) or not PropCatalog.has_tag(key, PropCatalog.WALL_MOUNTED):
		return -1
	var scale := 1.0
	var normal: Vector2 = wall["normal"]
	var yaw := PropCatalog.yaw_facing(normal)
	var dims := PropCatalog.footprint_rotated(key,
		yaw + PropCatalog.face_offset(key)) * scale
	var horizontal := absf(normal.y) > 0.5
	var width := dims.x if horizontal else dims.y
	var depth := dims.y if horizontal else dims.x
	var along := _clear_wall_mount_center(p, room, wall_index,
		anchor_extent, desired_along, width, depth)
	if is_inf(along):
		return -1
	var base := HouseFurnishGeometry.storey_base(p, room)
	var mount_y := base + pivot_height
	var pose := _wall_fixture_pose(key, wall, along, mount_y, scale)
	var floor_y := base + HouseGeometry.FLOOR_T
	var ceiling_y := base + p.spec.height - HouseGeometry.FLOOR_T - 0.03
	if float(pose["bottom"]) < floor_y + 0.9 or float(pose["top"]) > ceiling_y:
		return -1
	var body_rect: Rect2 = pose["rect"]
	if not _wall_mount_clear_of_furniture(p, room, body_rect,
			float(pose["bottom"]), float(pose["top"])):
		return -1
	for zone in p.zones:
		if int(zone.get("room", -1)) != room or String(zone.get("why", "")) \
				not in ["stair access route", "stair foot landing", "stair head landing"]:
			continue
		if body_rect.intersects(Rect2(zone.get("rect", Rect2()))):
			return -1
	var host_id := "wallhost:surface:%s:%s" % [anchor_id, suffix]
	var body_lo := body_rect.position.x if horizontal else body_rect.position.y
	var body_hi := body_rect.end.x if horizontal else body_rect.end.y
	var host_span := Vector2(body_lo, body_hi)
	_append_wall_host(p, room, wall_index, host_span, wall,
		"lighting" if relation == "lights_activity" else "activity_support",
		group_name, anchor_id, PropCatalog.category(key), host_id)
	var furniture_rect := body_rect
	var record := {"key": key, "room": room,
		"storey": p.storey_of_room(room),
		"pos": pose["pos"], "yaw": yaw,
		"rect": furniture_rect, "zone": Rect2(), "host": -1,
		"cat": PropCatalog.category(key), "mounted": true, "scale": scale,
		"wall_host_id": host_id, "mount_relation": relation,
		"activity_anchor_id": anchor_id, "activity_group": group_name,
		"surface_anchor_id": "surface:%s:%s" % [anchor_id, suffix],
		"surface_generated": true}
	var index := p.furniture.size()
	p.furniture.append(record)
	return index


## A mounted fitting occupies a 3D box, not just an interval on the wall.
## Keep tall floor furniture (and any prior fitting) out of that same volume.
static func _wall_mount_clear_of_furniture(p: HousePlan, room: int,
		body_rect: Rect2, body_bottom: float, body_top: float) -> bool:
	for item in p.furniture:
		if int(item.get("room", -1)) != room or not item.has("pos"):
			continue
		var item_rect := Rect2(item.get("rect", Rect2()))
		var item_key := String(item.get("key", ""))
		var item_scale := float(item.get("scale", 1.0))
		if bool(item.get("mounted", false)):
			var item_yaw := float(item.get("yaw", 0.0)) + PropCatalog.face_offset(item_key)
			var item_origin := PropCatalog.house_origin(item)
			var item_centre := PropCatalog.plan_centre(item_key, item_origin, item_yaw, item_scale)
			var item_size := PropCatalog.footprint_rotated(item_key, item_yaw) * item_scale
			item_rect = Rect2(item_centre - item_size * 0.5, item_size)
		if not body_rect.intersects(item_rect):
			continue
		# Mounted furniture's pos is its model origin, not its lower body edge.
		# Use the same measured vertical convention as HouseAssembler so a raised
		# wall fitting cannot be mistaken for empty space beneath its pivot.
		var item_height_scale: float = PropCatalog.placement_height_scale(item)
		var item_origin := PropCatalog.house_origin(item)
		var item_bottom: float = item_origin.y \
			+ PropCatalog.floor_offset(item_key) * item_height_scale
		var item_top := item_bottom + PropCatalog.placement_height(item)
		if minf(body_top, item_top) - maxf(body_bottom, item_bottom) > 0.03:
			return false
	return true


static func _append_shelf_book(p: HousePlan, room: int, shelf_index: int,
		wall: Dictionary, anchor_id: String, group_name: String) -> bool:
	if shelf_index < 0 or shelf_index >= p.furniture.size():
		return false
	var shelf: Dictionary = p.furniture[shelf_index]
	var shelf_key := String(shelf["key"])
	if not PropCatalog.has_tag(shelf_key, PropCatalog.SURFACE):
		return false
	var shelf_origin := PropCatalog.house_origin(shelf)
	var scale := float(shelf.get("scale", 1.0))
	var shelf_top := shelf_origin.y \
		+ PropCatalog.floor_offset(shelf_key) * PropCatalog.placement_height_scale(shelf) \
		+ PropCatalog.surface_height(shelf_key) * PropCatalog.placement_height_scale(shelf)
	var shelf_yaw := float(shelf.get("yaw", 0.0)) + PropCatalog.face_offset(shelf_key)
	var shelf_centre := PropCatalog.plan_centre(shelf_key, shelf_origin, shelf_yaw, scale)
	var shelf_size := PropCatalog.footprint_rotated(shelf_key, shelf_yaw) * scale
	var shelf_rect := Rect2(shelf_centre - shelf_size * 0.5, shelf_size)
	var shelf_id := String(shelf.get("surface_anchor_id", ""))
	# An authored book already on this exact shelf is the useful result. Bind
	# only derived relationships; its pose, scale, activity group, and host stay.
	for item_index in range(p.furniture.size()):
		if item_index == shelf_index:
			continue
		var item: Dictionary = p.furniture[item_index]
		var item_key := String(item.get("key", ""))
		if int(item.get("room", -1)) != room or bool(item.get("mounted", false)) \
				or int(item.get("host", -1)) != shelf_index \
				or not item_key.begins_with("Book_") \
				or not PropCatalog.has_tag(item_key, PropCatalog.ON_SURFACE) \
				or not item.has("pos") or not item.get("rect") is Rect2:
			continue
		if HousePlan.record_storey(item) != HousePlan.record_storey(shelf):
			continue
		var item_yaw := float(item.get("yaw", 0.0)) + PropCatalog.face_offset(item_key)
		var item_scale := float(item.get("scale", 1.0))
		var item_origin := PropCatalog.house_origin(item)
		var item_centre := PropCatalog.plan_centre(item_key, item_origin, item_yaw, item_scale)
		var item_size := PropCatalog.footprint_rotated(item_key, item_yaw) * item_scale
		var item_rect := Rect2(item_centre - item_size * 0.5, item_size)
		var expected_y := shelf_top
		if absf(float(item["pos"].y) - expected_y) > 0.02 \
				or not shelf_rect.grow(-0.02).encloses(item_rect) \
				or not Rect2(item["rect"]).grow(0.02).encloses(item_rect):
			continue
		item["surface_parent_id"] = shelf_id
		item["activity_anchor_id"] = anchor_id
		item["activity_binding_group"] = group_name
		if String(item.get("surface_anchor_id", "")) == "":
			item["surface_anchor_id"] = "surface:%s:reading_book" % anchor_id
		return true
	var key := "Book_Stack_1"
	var book_yaw := float(shelf.get("yaw", 0.0))
	var model_yaw := book_yaw + PropCatalog.face_offset(shelf_key)
	var book_size := PropCatalog.footprint_rotated(key, book_yaw)
	var shelf_footprint := PropCatalog.footprint_rotated(shelf_key, model_yaw) * scale
	if book_size.x > shelf_footprint.x - 0.06 or book_size.y > shelf_footprint.y - 0.04:
		return false
	var pos_xz := PropCatalog.plan_centre(shelf_key, shelf_origin, model_yaw, scale)
	var horizontal := absf(Vector2(wall["normal"]).y) > 0.5
	var along_axis := Vector2.RIGHT if horizontal else Vector2.DOWN
	var book_along := book_size.x if horizontal else book_size.y
	var shelf_along := shelf_footprint.x if horizontal else shelf_footprint.y
	var max_offset := maxf((shelf_along - book_along) * 0.5 - 0.03, 0.0)
	var offsets: Array[float] = [0.0]
	var step := book_along + 0.04
	var offset := step
	while offset <= max_offset + 0.001:
		offsets.append(offset)
		offsets.append(-offset)
		offset += step
	var selected_rect := Rect2()
	var selected_centre := pos_xz
	var found_spot := false
	for along_offset in offsets:
		var candidate_centre := pos_xz + along_axis * along_offset
		var candidate_rect := Rect2(candidate_centre - book_size * 0.5, book_size)
		if not shelf_rect.grow(-0.02).encloses(candidate_rect):
			continue
		var occupied := false
		for item_index in range(p.furniture.size()):
			if item_index == shelf_index:
				continue
			var item: Dictionary = p.furniture[item_index]
			if int(item.get("room", -1)) != room or not item.has("pos") \
					or not item.get("rect") is Rect2:
				continue
			var same_host := int(item.get("host", -1)) == shelf_index
			var same_level := absf(float(item["pos"].y) - shelf_top) <= 0.20
			if (same_host or same_level) and Rect2(item["rect"]).intersects(candidate_rect):
				occupied = true
				break
		if occupied:
			continue
		selected_centre = candidate_centre
		selected_rect = candidate_rect
		found_spot = true
		break
	if not found_spot:
		return false
	var pos := Vector3(selected_centre.x, shelf_top, selected_centre.y)
	p.furniture.append({"key": key, "room": room,
		"storey": HousePlan.record_storey(shelf), "pos": pos, "yaw": book_yaw,
		"rect": selected_rect, "zone": Rect2(), "host": shelf_index,
		"cat": PropCatalog.category(key), "mounted": false, "scale": 1.0,
		"activity_group": group_name, "surface_parent_id": shelf_id,
		"activity_anchor_id": anchor_id, "surface_anchor_id":
		"surface:%s:reading_book" % anchor_id, "surface_generated": true})

	return true

## Try actual sleep supports in semantic order. Failed trials restore source
## furniture, hosts, compromises, and interval reservations.
static func _compose_sleep_anchor_with_fallback(p: HousePlan, spec: HouseSpec,
		room: int, anchors: Array, occupied_by_room: Dictionary) -> bool:
	for candidate_variant in anchors:
		var candidate: Dictionary = candidate_variant
		var item_index := int(candidate["index"])
		if item_index < 0 or item_index >= p.furniture.size():
			continue
		var item: Dictionary = p.furniture[item_index]
		if not item.has("rect") or not item.get("rect") is Rect2:
			continue
		var furniture_before: Array[Dictionary] = p.furniture.duplicate(true)
		var hosts_before: Array[Dictionary] = p.wall_hosts.duplicate(true)
		var compromises_before: Dictionary = p.compromises.duplicate(true)
		var occupied_before: Dictionary = occupied_by_room.duplicate(true)
		var prep_rect := Rect2(item.get("zone", Rect2()))
		if not prep_rect.has_area():
			prep_rect = Rect2(item["rect"])
		var anchor_id := String(candidate["anchor_id"])
		_add_activity_wall_composition(p, spec, room, "sleep",
			String(candidate["category"]), anchor_id, String(item.get("key", "")),
			Rect2(item["rect"]).get_center(), prep_rect, occupied_by_room)
		if _sleep_anchor_has_complete_station(p, room, anchor_id):
			return true
		p.furniture = furniture_before
		p.wall_hosts = hosts_before
		p.compromises.clear()
		for room_key in compromises_before:
			p.compromises[room_key] = compromises_before[room_key]
		occupied_by_room.clear()
		for room_key in occupied_before:
			occupied_by_room[room_key] = occupied_before[room_key]
	return false


static func _sleep_anchor_has_complete_station(p: HousePlan, room: int, anchor_id: String) -> bool:
	var support_index := -1
	for item_index in p.furniture_of(room):
		var item: Dictionary = p.furniture[item_index]
		if (String(item.get("activity_anchor_id", "")) == anchor_id
				and String(item.get("mount_relation", "")) == "supports_activity"
				and String(item.get("key", "")) == "Shelf_Simple"
				and bool(item.get("mounted", false))):
			support_index = item_index
			break
	if support_index < 0:
		return false
	var shelf: Dictionary = p.furniture[support_index]
	var shelf_id := String(shelf.get("surface_anchor_id", ""))
	var book_found := false
	for item_index in p.furniture_of(room):
		var item: Dictionary = p.furniture[item_index]
		if (String(item.get("key", "")).begins_with("Book_")
				and int(item.get("host", -1)) == support_index
				and String(item.get("surface_parent_id", "")) == shelf_id):
			book_found = true
			break
	if not book_found:
		return false
	for item_index in p.furniture_of(room):
		var item: Dictionary = p.furniture[item_index]
		if (String(item.get("activity_anchor_id", "")) == anchor_id
				and String(item.get("mount_relation", "")) == "lights_activity"
				and bool(item.get("mounted", false))):
			return true
	return false


static func _add_activity_wall_composition(p: HousePlan, spec: HouseSpec,
		room: int, group_name: String, category: String, anchor_id: String,
		anchor_key: String, anchor_position: Vector2, prep_rect: Rect2,
		occupied_by_room: Dictionary) -> void:
	var support_key := _activity_support_key(group_name, category, spec.style, anchor_key)
	if support_key == "":
		_note_activity_surface_unavailable(p, room, group_name)
		return
	# Reuse an existing correctly mounted shelf when it is physically attached
	# to a wall near this activity. Its placement and activity group are kept.
	var support := _reuse_existing_activity_support(p, room, support_key,
		group_name, anchor_id, prep_rect, occupied_by_room)
	if support.is_empty():
		support = _append_nearby_activity_support(p, room, support_key,
			group_name, anchor_id, anchor_position, prep_rect, occupied_by_room)
	if support.is_empty():
		_note_activity_surface_unavailable(p, room, group_name)
		return
	var wall_index := int(support["wall"])
	var wall: Dictionary = support["wall_row"]
	var shelf_index := int(support["furniture_index"])
	var shelf_along := float(support["along"])
	var station_extent: Vector2 = support["station_extent"]
	var host_span: Vector2 = support["span"]
	var intervals: Array = occupied_by_room[room].get(wall_index, [])
	intervals.append(host_span)
	occupied_by_room[room][wall_index] = intervals
	if group_name == "sleep":
		var book_available := _append_shelf_book(p, room, shelf_index, wall,
			anchor_id, group_name)
		if not book_available:
			_note_activity_surface_unavailable(p, room, group_name)
	elif group_name == "cooking":
		if not _compose_activity_shelf_contents(p, room, shelf_index,
			anchor_id, group_name):
			p.note_compromise(room, "surface:%s:no_safe_contents" % group_name)
	elif group_name == "witchwork":
		var shelf: Dictionary = p.furniture[shelf_index]
		if String(shelf.get("key", "")) == "Shelf_Small_Bottles" \
				and PropCatalog.has_tag("Shelf_Small_Bottles", PropCatalog.WALL_MOUNTED):
			# The imported asset includes two bottle rows in its real mesh. This is
			# an integrated rack, not a top surface for loose potions.
			shelf["content_kind"] = "integrated_ingredient_rack"
			shelf["content_asset_key"] = "Shelf_Small_Bottles"
			shelf["content_layout"] = "integrated_two_tier_bottles"
			for host_index in range(p.wall_hosts.size()):
				var host: Dictionary = p.wall_hosts[host_index]
				if String(host.get("id", "")) == String(shelf.get("wall_host_id", "")):
					host["content_kind"] = "integrated_ingredient_rack"
					host["content_asset_key"] = "Shelf_Small_Bottles"
					host["content_layout"] = "integrated_two_tier_bottles"
				p.wall_hosts[host_index] = host
		else:
			p.note_compromise(room, "surface:%s:no_safe_contents" % group_name)
	if group_name not in ["cooking", "witchwork", "sleep"]:
		return
	# Prefer the shelf wall, then other nearby task walls. A fitted ingredient
	# shelf can fill a narrow clear span; that does not make the neighboring
	# return wall unsuitable for a real task light.
	var support_rect := Rect2(p.furniture[shelf_index].get("rect", Rect2()))
	if not _append_nearby_activity_light(p, room, wall_index, shelf_along,
			prep_rect, support_rect, group_name, anchor_id, occupied_by_room):
		p.note_compromise(room, "surface:%s:no_safe_light" % group_name)


static func _append_nearby_activity_light(p: HousePlan, room: int,
		preferred_wall: int, shelf_along: float, prep_rect: Rect2,
		support_rect: Rect2, group_name: String, anchor_id: String,
		occupied_by_room: Dictionary) -> bool:
	if not occupied_by_room.has(room):
		occupied_by_room[room] = {}
	var walls := HouseGeometry.room_walls(p, room)
	var candidates: Array[Dictionary] = []
	var existing_sconces: Array[Dictionary] = []
	for fi in p.furniture_of(room):
		var placed: Dictionary = p.furniture[fi]
		if bool(placed.get("mounted", false)) and PropCatalog.category(
				String(placed.get("key", ""))) == "sconce":
			existing_sconces.append(placed)
	var mirrored_wall := -1
	var mirrored_stations: Array[float] = []
	if existing_sconces.size() == 1:
		var existing := existing_sconces[0]
		var old_wall := HouseFurnishScore._back_wall_index(p, room,
			Rect2(existing.get("rect", Rect2())), existing)
		if old_wall >= 0 and old_wall < walls.size():
			mirrored_wall = old_wall
			var old_normal: Vector2 = walls[old_wall]["normal"]
			var mirror_axis := Vector2.RIGHT if absf(old_normal.y) > 0.5 else Vector2.DOWN
			var old_center := Rect2(existing["rect"]).get_center()
			var mirror_anchors: Array[Vector2] = [HouseGeometry.room_floor_rect(p, room).get_center()]
			if p.is_polygonal(room):
				mirror_anchors.append((Vector2(walls[old_wall]["from"])
					+ Vector2(walls[old_wall]["to"])) * 0.5)
			for fi in p.furniture_of(room):
				var anchor_item: Dictionary = p.furniture[fi]
				if PropCatalog.category(String(anchor_item.get("key", ""))) == "hearth":
					mirror_anchors.append(Rect2(anchor_item["rect"]).get_center())
			for di in p.doors_of(room):
				mirror_anchors.append(Vector2(p.doors[di]["pos"]))
			for anchor in mirror_anchors:
				mirrored_stations.append(2.0 * anchor.dot(mirror_axis) - old_center.dot(mirror_axis))
	for wi in walls.size():
		var wall: Dictionary = walls[wi]
		var dims := _mounted_dimensions("Torch_Metal", wall)
		var horizontal := absf(Vector2(wall["normal"]).y) > 0.5
		var width := dims.x if horizontal else dims.y
		var depth := dims.y if horizontal else dims.x
		var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
		for span in clear_wall_spans(p, room, wi, depth):
			var lo := span.x + width * 0.5
			var hi := span.y - width * 0.5
			if hi < lo: continue
			var desired := prep_rect.get_center().dot(axis)
			var stations: Array[float] = [clampf(desired, lo, hi), lo, hi]
			if wi == preferred_wall:
				stations.push_front(clampf(shelf_along - 0.78, lo, hi))
				stations.push_front(clampf(shelf_along + 0.78, lo, hi))
			if wi == mirrored_wall:
				for mirrored_along in mirrored_stations:
					if mirrored_along >= lo and mirrored_along <= hi:
						stations.append(mirrored_along)
			for along in stations:
				var pose := _wall_fixture_pose("Torch_Metal", wall, along,
					HouseFurnishGeometry.storey_base(p, room) + HouseGeometry.SCONCE_HEIGHT, 1.0)
				var body := Rect2(pose["rect"])
				var prep_distance := _rect_distance(body, prep_rect)
				var support_distance := _rect_distance(body, support_rect)
				if prep_distance <= 1.9 and support_distance <= 1.9:
					candidates.append({"wall": wi, "row": wall, "span": span,
						"along": along, "distance": maxf(prep_distance, support_distance)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var preferred_a := int(a["wall"]) == preferred_wall
		var preferred_b := int(b["wall"]) == preferred_wall
		if preferred_a != preferred_b: return preferred_a
		if float(a["distance"]) != float(b["distance"]):
			return float(a["distance"]) < float(b["distance"])
		if int(a["wall"]) != int(b["wall"]): return int(a["wall"]) < int(b["wall"])
		return float(a["along"]) < float(b["along"]))
	# Reuse an eligible authored task light when its measured wall pose is
	# actually near both the activity prep and its support.
	for candidate in candidates:
		var wi := int(candidate["wall"])
		var wall: Dictionary = candidate["row"]
		if _bind_existing_task_light(p, room, wi, wall, prep_rect,
				support_rect, anchor_id, group_name, occupied_by_room):
			return true
	# A newly added task light must complete a real mirrored pair with the
	# authored room sconce. A cross-wall pair or third lamp is not a fix.
	if existing_sconces.size() > 1:
		return false
	if existing_sconces.size() == 1:
		var paired_candidates: Array[Dictionary] = []
		for candidate in candidates:
			if _activity_light_mirrors_sconce(p, room, candidate, existing_sconces[0]):
				paired_candidates.append(candidate)
		candidates = paired_candidates
	# Reuse every eligible authored light before adding a new one on any wall.
	for candidate in candidates:
		var wi := int(candidate["wall"])
		var wall: Dictionary = candidate["row"]
		var along := float(candidate["along"])
		var index := _append_wall_mount(p, room, wi, wall, candidate["span"], along,
			"Torch_Metal", HouseGeometry.SCONCE_HEIGHT, group_name,
			anchor_id, "lights_activity", "task_light")
		if index >= 0:
			var intervals: Array = occupied_by_room[room].get(wi, [])
			intervals.append(p.wall_hosts.back()["span"])
			occupied_by_room[room][wi] = intervals
			return true
	return false


static func _activity_light_mirrors_sconce(p: HousePlan, room: int,
		candidate: Dictionary, existing: Dictionary) -> bool:
	var walls := HouseGeometry.room_walls(p, room)
	var existing_wall := HouseFurnishScore._back_wall_index(p, room,
		Rect2(existing.get("rect", Rect2())), existing)
	var candidate_wall := int(candidate.get("wall", -1))
	if existing_wall < 0 or existing_wall != candidate_wall or existing_wall >= walls.size():
		return false
	var wall: Dictionary = walls[existing_wall]
	var normal: Vector2 = wall["normal"]
	var along := Vector2(normal.y, -normal.x)
	var existing_center := Rect2(existing["rect"]).get_center()
	var pose := _wall_fixture_pose("Torch_Metal", wall, float(candidate["along"]),
		HouseFurnishGeometry.storey_base(p, room) + HouseGeometry.SCONCE_HEIGHT, 1.0)
	var candidate_center := Rect2(pose["rect"]).get_center()
	var anchors: Array[Vector2] = [HouseGeometry.room_floor_rect(p, room).get_center()]
	if p.is_polygonal(room):
		anchors.append((Vector2(wall["from"]) + Vector2(wall["to"])) * 0.5)
	for fi in p.furniture_of(room):
		var item: Dictionary = p.furniture[fi]
		if PropCatalog.category(String(item.get("key", ""))) == "hearth":
			anchors.append(Rect2(item["rect"]).get_center())
	for di in p.doors_of(room):
		anchors.append(Vector2(p.doors[di]["pos"]))
	for anchor in anchors:
		var error := absf((existing_center + candidate_center - anchor * 2.0).dot(along))
		if error <= 0.15: # Match HouseFurnishAffinityCheck.FS_MIRROR_TOL.
			return true
	return false

## Add one full-size useful object only when the measured shelf supports it.
## Witch ingredient racks are integrated meshes and need no loose top props.
static func _compose_activity_shelf_contents(p: HousePlan, room: int,
		shelf_index: int, anchor_id: String, group_name: String) -> bool:
	if group_name != "cooking" or shelf_index < 0 or shelf_index >= p.furniture.size():
		return false
	var shelf: Dictionary = p.furniture[shelf_index]
	var shelf_key := String(shelf.get("key", ""))
	if int(shelf.get("room", -1)) != room or not PropCatalog.has_tag(shelf_key, PropCatalog.SURFACE):
		return false
	var shelf_id := String(shelf.get("surface_anchor_id", ""))
	for index in range(p.furniture.size()):
		var child: Dictionary = p.furniture[index]
		if not _is_supported_surface_child(child, shelf, shelf_index) or String(child.get("key", "")) != "Mug":
			continue
		child["surface_parent_id"] = shelf_id
		child["activity_anchor_id"] = anchor_id
		child["activity_binding_group"] = group_name
		child["surface_anchor_id"] = "surface:%s:content:Mug" % anchor_id
		p.furniture[index] = child
		return true
	if not PropCatalog.PROPS.has("Mug") or not PropCatalog.has_tag("Mug", PropCatalog.ON_SURFACE):
		return false
	var shelf_origin := PropCatalog.house_origin(shelf)
	var shelf_yaw := float(shelf.get("yaw", 0.0)) + PropCatalog.face_offset(shelf_key)
	var shelf_scale := float(shelf.get("scale", 1.0))
	var shelf_centre := PropCatalog.plan_centre(shelf_key, shelf_origin, shelf_yaw, shelf_scale)
	var shelf_size := PropCatalog.footprint_rotated(shelf_key, shelf_yaw) * shelf_scale
	var shelf_rect := Rect2(shelf_centre - shelf_size * 0.5, shelf_size)
	var shelf_top := shelf_origin.y + PropCatalog.floor_offset(shelf_key) * PropCatalog.placement_height_scale(shelf) \
		+ PropCatalog.surface_height(shelf_key) * PropCatalog.placement_height_scale(shelf)
	var wall_index := -1
	for host_variant in p.wall_hosts:
		var host: Dictionary = host_variant
		if String(host.get("id", "")) == String(shelf.get("wall_host_id", "")):
			wall_index = int(host.get("wall", -1))
			break
	var walls := HouseGeometry.room_walls(p, room)
	if wall_index < 0 or wall_index >= walls.size():
		return false
	var normal: Vector2 = walls[wall_index]["normal"]
	# Face the room, independent of the shelf model's asset correction yaw.
	var content_yaw := 0.0 if absf(normal.y) > 0.5 else PI * 0.5
	var model_yaw := content_yaw + PropCatalog.face_offset("Mug")
	var mug_size := PropCatalog.footprint_rotated("Mug", model_yaw)
	if mug_size.x > shelf_size.x - 0.06 or mug_size.y > shelf_size.y - 0.06:
		return false
	var centre := shelf_centre
	var proposed_rect := Rect2(centre - mug_size * 0.5, mug_size)
	if not shelf_rect.grow(-0.02).encloses(proposed_rect):
		return false
	var probe := {"key": "Mug", "room": room, "storey": HousePlan.record_storey(shelf),
		"pos": Vector3(centre.x, shelf_top, centre.y), "yaw": content_yaw,
		"rect": proposed_rect, "zone": proposed_rect, "host": shelf_index,
		"cat": PropCatalog.category("Mug"), "mounted": false, "scale": 1.0}
	var origin := PropCatalog.house_origin(probe)
	var bottom := origin.y + PropCatalog.floor_offset("Mug") * PropCatalog.placement_height_scale(probe)
	var height := PropCatalog.placement_height(probe)
	var top := bottom + height
	if absf(bottom - shelf_top) > 0.02:
		return false
	var measured_centre := PropCatalog.plan_centre("Mug", origin, model_yaw, 1.0)
	var measured_size := PropCatalog.footprint_rotated("Mug", model_yaw)
	var measured_rect := Rect2(measured_centre - measured_size * 0.5, measured_size)
	var floor_rect := HouseGeometry.room_floor_rect(p, room)
	if not shelf_rect.grow(-0.02).encloses(measured_rect) or not floor_rect.grow(0.01).encloses(measured_rect):
		return false
	var ceiling_y := HouseFurnishGeometry.storey_base(p, room) + float(p.spec.height) - HouseGeometry.FLOOR_T
	if top > ceiling_y - 0.03:
		return false
	if not _wall_mount_clear_of_furniture(p, room, measured_rect, bottom, top):
		return false
	if not _wall_mount_route_clear(p, room, measured_rect):
		return false
	probe["rect"] = measured_rect
	probe["surface_parent_id"] = shelf_id
	probe["activity_anchor_id"] = anchor_id
	probe["activity_binding_group"] = group_name
	probe["surface_anchor_id"] = "surface:%s:content:Mug" % anchor_id
	probe["surface_generated"] = true
	p.furniture.append(probe)
	if not _is_supported_surface_child(probe, shelf, shelf_index):
		p.furniture.remove_at(p.furniture.size() - 1)
		return false
	return true


static func _activity_support_key(group_name: String, category: String,
		style: StringName, item_key := "") -> String:
	if group_name in ["cooking", "witchwork"] and category == "workbench":
		return "Shelf_Small_Bottles" if style == &"witch_hut" else "Shelf_Simple"
	if group_name == "sleep" and (item_key == "Nightstand_Shelf" or category == "chest"):
		return "Shelf_Simple"
	return ""


## Search room clear spans for a measured mounting station near the
## activity's actual use/prep rectangle. A return wall remains eligible when
## the fitting body is within 1.9 m of that usable task region.
static func _allow_unlit_witchwork_support(p: HousePlan, group_name: String) -> bool:
	return (group_name == "witchwork"
		and HouseFurnishingRecipes.is_ordinary_house(p)
		and p.spec.style == &"witch_hut"
		and p.spec.trade == &"none")


static func _activity_light_candidate_available(p: HousePlan, room: int,
		preferred_wall: int, shelf_along: float, prep_rect: Rect2,
		support_rect: Rect2, group_name: String, anchor_id: String,
		occupied_by_room: Dictionary) -> bool:
	# Trial only on duplicated arrays. The original authored furniture, wall hosts,
	# and interval map are restored by reference after testing the full mount.
	var original_furniture: Array[Dictionary] = p.furniture
	var original_hosts: Array[Dictionary] = p.wall_hosts
	var original_occupied := occupied_by_room.duplicate(true)
	p.furniture = p.furniture.duplicate(true)
	p.wall_hosts = p.wall_hosts.duplicate(true)
	var available := _append_nearby_activity_light(p, room, preferred_wall,
		shelf_along, prep_rect, support_rect, group_name, anchor_id, occupied_by_room)
	p.furniture = original_furniture
	p.wall_hosts = original_hosts
	occupied_by_room.clear()
	for room_key in original_occupied:
		occupied_by_room[room_key] = original_occupied[room_key]
	return available


static func _append_nearby_activity_support(p: HousePlan, room: int,
		key: String, group_name: String, anchor_id: String, anchor: Vector2,
		prep_rect: Rect2, occupied_by_room: Dictionary) -> Dictionary:
	var max_prep_distance: float = 0.75 if group_name == "witchwork" and _is_compact_witch_shared_hall(p, room) else 1.9
	var walls := HouseGeometry.room_walls(p, room)
	var candidates: Array[Dictionary] = []
	var original_wall := HouseGeometry.backing_wall(p, room,
		Rect2(anchor, Vector2.ZERO), 1000.0)
	var base := HouseFurnishGeometry.storey_base(p, room)
	for wi in walls.size():
		var wall: Dictionary = walls[wi]
		var normal: Vector2 = wall["normal"]
		var horizontal := absf(normal.y) > 0.5
		var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
		var dimensions := _mounted_dimensions(key, wall)
		var width := dimensions.x if horizontal else dimensions.y
		var depth := dimensions.y if horizontal else dimensions.x
		var prep_along := prep_rect.get_center().dot(axis)
		for clear_span in clear_wall_spans(p, room, wi, depth):
			var lo := clear_span.x + width * 0.5
			var hi := clear_span.y - width * 0.5
			if hi < lo:
				continue
			# Probe bounded stations, not one pivot-derived point. A shelf near a
			# return can be the only fit that also admits a lawful task light.
			var stations: Array[float] = [clampf(prep_along, lo, hi), lo, hi,
				(lo + hi) * 0.5, lerpf(lo, hi, 0.25), lerpf(lo, hi, 0.75)]
			for station_index in range(stations.size()):
				var station_along := stations[station_index]
				var duplicate_station := false
				for prior in range(station_index):
					if absf(stations[prior] - station_along) < 0.001:
						duplicate_station = true
						break
				if duplicate_station:
					continue
				var pose := _wall_fixture_pose(key, wall, station_along,
					base + HouseGeometry.SHELF_HEIGHT, 1.0)
				var body: Rect2 = pose["rect"]
				var distance := _rect_distance(body, prep_rect)
				if distance > max_prep_distance:
					continue
				if not HouseGeometry.room_floor_rect(p, room).grow(0.01).encloses(body):
					continue
				candidates.append({"wall": wi, "wall_row": wall,
					"along": station_along, "distance": distance,
					"station_extent": clear_span, "body": body})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_bucket := roundi(float(left["distance"]) * 100.0)
		var right_bucket := roundi(float(right["distance"]) * 100.0)
		if left_bucket != right_bucket:
			return left_bucket < right_bucket
		var left_preferred := int(left["wall"]) == original_wall
		var right_preferred := int(right["wall"]) == original_wall
		if left_preferred != right_preferred:
			return left_preferred
		if int(left["wall"]) != int(right["wall"]):
			return int(left["wall"]) < int(right["wall"])
		if float(left["along"]) != float(right["along"]):
			return float(left["along"]) < float(right["along"])
		return float(left["distance"]) < float(right["distance"]))
	for candidate in candidates:
		var wall_index := int(candidate["wall"])
		var wall: Dictionary = candidate["wall_row"]
		var station_extent: Vector2 = candidate["station_extent"]
		var station_along := float(candidate["along"])
		var furniture_index := _append_wall_mount(p, room, wall_index, wall,
			station_extent, station_along, key, HouseGeometry.SHELF_HEIGHT,
			group_name, anchor_id, "supports_activity", "shelf")
		if furniture_index < 0:
			continue
		var host: Dictionary = p.wall_hosts.back()
		var body: Rect2 = Rect2(p.furniture[furniture_index].get("rect", Rect2()))
		if not _allow_unlit_witchwork_support(p, group_name) and not _activity_light_candidate_available(
			p, room, wall_index, station_along, prep_rect, body, group_name, anchor_id, occupied_by_room):
			p.furniture.remove_at(furniture_index)
			p.wall_hosts.pop_back()
			continue
		return {"wall": wall_index, "wall_row": wall, "along": station_along,
			"station_extent": station_extent, "span": host["span"],
			"furniture_index": furniture_index}
	return {}


static func _rect_distance(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var dy := maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return Vector2(dx, dy).length()


## Bind a previously placed shelf without changing its model pose, scale, or
## source activity_group. It must face the wall, touch its real back edge, fit
## inside the room and clear apertures, routes, and other objects in 3D.


## Preserve daylight while moving a front opening out of the measured compact
## Witchwork bench bay. The window stays on the same exterior wall and passes
## the normal door, flue and window crowd checks.
static func _relocate_compact_witch_workwall_window(p: HousePlan, room: int) -> bool:
	if not _is_compact_witch_shared_hall(p, room):
		return false
	var walls := HouseGeometry.room_walls(p, room)
	if walls.is_empty():
		return false
	var bench_rect := _compact_witchwork_reserved_bench_rect(p, room)
	if not bench_rect.has_area():
		return false
	var room_data: Dictionary = p.rooms[room]
	var regions: Dictionary = room_data.get("activity_regions", {})
	var conflicting_windows: Array[int] = []
	for window_index in p.windows_of(room):
		var window: Dictionary = p.windows[window_index]
		if HouseGeometry.window_clear_rect(window).intersects(bench_rect.grow(0.75)):
			conflicting_windows.append(window_index)
	for window_index in conflicting_windows:
		var original: Dictionary = p.windows[window_index].duplicate(true)
		var width := float(original.get("width", HouseGeometry.WINDOW_W))
		p.windows.remove_at(window_index)
		var best: Dictionary = {}
		var best_service_distance := -INF
		for wall_variant in walls:
			var wall: Dictionary = wall_variant
			var wall_inward: Vector2 = Vector2(wall.get("normal", Vector2.ZERO)).normalized()
			var wall_outward := -wall_inward
			var from: Vector2 = Vector2(wall.get("from", Vector2.ZERO))
			var to: Vector2 = Vector2(wall.get("to", Vector2.ZERO))
			var normal_axis := 0 if absf(wall_inward.x) > 0.5 else 1
			var line_value := from.x if normal_axis == 0 else from.y
			if not HouseGeometry.is_exterior_edge(p.spec, normal_axis, line_value):
				continue
			var wall_axis := (to - from).normalized()
			var run := from.distance_to(to)
			var half := width * 0.5
			var lo := half + 0.1
			var hi := run - half - 0.1
			if hi < lo:
				continue
			var steps := maxi(ceili((hi - lo) / 0.08), 1)
			for station in range(steps + 1):
				var offset := lo + (hi - lo) * float(station) / float(steps)
				var pos := from + wall_axis * offset
				if HousePlanOpenings._crowds(p, pos, wall_outward, width,
						HousePlan.record_storey(original)):
					continue
				var candidate: Dictionary = original.duplicate(true)
				candidate["pos"] = pos
				candidate["normal"] = wall_outward
				var clear: Rect2 = HouseGeometry.window_clear_rect(candidate)
				if clear.intersects(bench_rect.grow(0.01)):
					continue
				var service_distance := _rect_distance(clear, Rect2(regions[&"witchwork"]))
				if service_distance > best_service_distance:
					best_service_distance = service_distance
					best = candidate
		if best.is_empty():
			p.windows.insert(window_index, original)
			return false
		p.windows.insert(window_index, best)
	return true


## The planned bench pose is also the opening-clearance datum. Keeping this in
## one helper prevents the service-window move from drifting away from the
## same measured workwall pose used by the earlier workwall relocation.
static func _compact_witchwork_reserved_bench_rect(p: HousePlan, room: int) -> Rect2:
	if not _is_compact_witch_shared_hall(p, room):
		return Rect2()
	var walls := HouseGeometry.room_walls(p, room)
	if walls.is_empty():
		return Rect2()
	var workwall: Dictionary = walls[0]
	var inward: Vector2 = Vector2(workwall.get("normal", Vector2.ZERO)).normalized()
	var work_from: Vector2 = Vector2(workwall.get("from", Vector2.ZERO))
	var work_to: Vector2 = Vector2(workwall.get("to", Vector2.ZERO))
	if absf(inward.y) < 0.5:
		return Rect2()
	var along := (work_to - work_from).normalized()
	if along.x < 0.0:
		along = -along
	var key := "Workbench"
	var yaw := HouseFurnishGeometry.yaw_facing(inward)
	var bench_size: Vector2 = PropCatalog.footprint_rotated(key, yaw)
	var regions: Dictionary = p.rooms[room].get("activity_regions", {})
	if not regions.has(&"witchwork"):
		return Rect2()
	var service: Rect2 = Rect2(regions[&"witchwork"])
	var wall_lo := minf(work_from.x, work_to.x)
	var wall_hi := maxf(work_from.x, work_to.x)
	var lo := maxf(wall_lo, service.position.x) + bench_size.x * 0.5 + HouseGeometry.WALL_GAP
	var hi := minf(wall_hi, service.end.x) - bench_size.x * 0.5 - HouseGeometry.WALL_GAP
	if hi < lo:
		return Rect2()
	# The actual workbench search may choose any legal station in the reserved
	# Witchwork band. Its stable target is the band centre, not the house's
	# arbitrary left endpoint (which is outside the band when the hearth is on
	# the right wall).
	var station_x := clampf(service.get_center().x, lo, hi)
	var bench_center := Vector2(station_x, work_from.y)
	bench_center += inward * (bench_size.y * 0.5 + HouseGeometry.WALL_GAP)
	var expected: Dictionary = HouseFurnishGeometry.candidate(key, bench_center, yaw, 1.0, 1.0, 1.0)
	var bench_rect: Rect2 = Rect2(expected.get("rect", Rect2()))
	if not regions.has(&"witchwork") or not Rect2(regions[&"witchwork"]).grow(0.01).encloses(bench_rect):
		return Rect2()
	return bench_rect


## Move the two openings that partition the compact Witch's service-side wall:
## the Hall light to its front wall and the rear bedroom light to the back wall.
## Their measured glazing is preserved. The canopy planner then tests the real
## windows and door reservations without weakening exterior clearance.
static func _relocate_compact_witch_service_windows(p: HousePlan, hall: int) -> void:
	if not _is_compact_witch_shared_hall(p, hall):
		return
	var descriptor := HouseGeometry.witch_compact_service_threshold(p)
	if descriptor.is_empty():
		return
	var service_normal: Vector2 = descriptor["normal"]
	var reserved_bench := _compact_witchwork_reserved_bench_rect(p, hall)
	if not reserved_bench.has_area():
		return
	var forbidden_rects: Array[Rect2] = [reserved_bench.grow(0.75)]
	var hearth_breast := _compact_witch_hearth_breast_rect(p, hall)
	# Keep the Hall's Witchwork front-wall bench bay clear. The workwall
	# relocation above has already placed any front opening on another legal
	# wall; do not put the service-side Hall light straight back into that bay.
	var move_by_room: Dictionary = {hall: [Vector2(0.0, 1.0), -service_normal,
		Vector2(0.0, -1.0)]}
	var indices: Array[int] = []
	for wi in range(p.windows.size()):
		var window: Dictionary = p.windows[wi]
		var room := int(window.get("room", -1))
		if move_by_room.has(room) and Vector2(window.get("normal", Vector2.ZERO)) == service_normal:
			indices.append(wi)
	indices.sort()
	for order in range(indices.size() - 1, -1, -1):
		var index: int = indices[order]
		var original: Dictionary = p.windows[index].duplicate(true)
		var room := int(original.get("room", -1))
		var replacement := _compact_window_on_alternate_wall(p, room, original,
			Array(move_by_room[room]), forbidden_rects if room == hall else [],
			[hearth_breast.grow(0.01)] if room == hall and hearth_breast.has_area() else [])
		if replacement.is_empty():
			continue
		p.windows[index] = replacement
	# Move Hall glazing off the service wall before packing bedroom openings into
	# their rear bay. Otherwise that soon-to-move Hall window can make a legal
	# area-preserving bedroom arrangement look crowded during the first pass.
	for bedroom in p.rooms_of(&"bedroom"):
		if p.storey_of_room(bedroom) == 0:
			_relocate_compact_bedroom_service_glazing(p, bedroom, service_normal)


## Reserve the real measured breast the same way the chimney planner does. The
## widest catalogue hearth is used at the existing planned focus point, giving
## a conservative structural interval without blocking the whole cooking band.
static func _compact_witch_hearth_breast_rect(p: HousePlan, room: int) -> Rect2:
	if p.hearth_room() != room or p.hearth_wall() < 0:
		return Rect2()
	var walls := HouseGeometry.room_walls(p, room)
	var wall_index := p.hearth_wall()
	if wall_index >= walls.size():
		return Rect2()
	var wall: Dictionary = walls[wall_index]
	var inward := Vector2(wall.get("normal", Vector2.ZERO)).normalized()
	var hearth_key := ""
	var hearth_width := -INF
	for key in PropCatalog.of_category("hearth"):
		var width := PropCatalog.footprint(key).x
		if width > hearth_width:
			hearth_width = width
			hearth_key = key
	if hearth_key.is_empty():
		return Rect2()
	var yaw := HouseFurnishGeometry.yaw_facing(inward) + PropCatalog.face_offset(hearth_key)
	var footprint := PropCatalog.footprint_rotated(hearth_key, yaw)
	var centre := p.focus_pos() + inward * (footprint.y * 0.5 + HouseGeometry.WALL_GAP)
	var hearth := HouseFurnishGeometry.candidate(hearth_key, centre, yaw)
	var breast := HouseGeometry.breast_for_hearth(p, room, hearth, wall_index)
	return Rect2(breast.get("rect", Rect2()))


## A rear-corner bedroom may already use its back wall for another light. Pack
## both bedroom openings into that real rear glazing bay, preserving each
## measured opening and its daylight, rather than dropping the service-side one.
static func _relocate_compact_bedroom_service_glazing(p: HousePlan, room: int,
		service_normal: Vector2) -> bool:
	var indices: Array[int] = []
	for wi in p.windows_of(room):
		var normal: Vector2 = p.windows[wi].get("normal", Vector2.ZERO)
		if normal == service_normal or normal == Vector2(0.0, 1.0):
			indices.append(wi)
	var needs_relocation := false
	for wi in indices:
		needs_relocation = needs_relocation or Vector2(p.windows[wi].get("normal", Vector2.ZERO)) == service_normal
	if not needs_relocation:
		return true
	var rear_wall: Dictionary = {}
	for wall_variant in HouseGeometry.room_walls(p, room):
		var wall: Dictionary = wall_variant
		var inward: Vector2 = Vector2(wall.get("normal", Vector2.ZERO)).normalized()
		if -inward != Vector2(0.0, 1.0):
			continue
		var from: Vector2 = wall["from"]
		var normal_axis := 0 if absf(inward.x) > 0.5 else 1
		var line := from.x if normal_axis == 0 else from.y
		if HouseGeometry.is_exterior_edge(p.spec, normal_axis, line):
			rear_wall = wall
			break
	if rear_wall.is_empty():
		return false
	var originals: Array[Dictionary] = []
	var indices_in_order: Array[int] = indices.duplicate()
	indices_in_order.sort()
	for wi in indices_in_order:
		originals.append(p.windows[wi].duplicate(true))
	var all_windows: Array[Dictionary] = []
	for win in p.windows:
		all_windows.append(win.duplicate(true))
	for order in range(indices_in_order.size() - 1, -1, -1):
		p.windows.remove_at(indices_in_order[order])
	var from: Vector2 = rear_wall["from"]
	var to: Vector2 = rear_wall["to"]
	var axis := (to - from).normalized()
	var run := from.distance_to(to)
	var total_width := 0.0
	for original in originals:
		total_width += float(original.get("width", HouseGeometry.WINDOW_W))
	var minimum_gap := HouseGeometry.WINDOW_MIN_GAP
	if originals.size() > 1:
		minimum_gap *= float(originals.size() - 1)
	var free := run - 0.2 - total_width - minimum_gap
	var starts := maxi(ceili(free / 0.08), 1)
	for station in range(starts + 1 if free >= 0.0 else 0):
		var edge_gap := 0.1 + free * float(station) / float(starts)
		var cursor := edge_gap
		var moved_windows: Array[Dictionary] = []
		var clear := true
		for original in originals:
			var width := float(original.get("width", HouseGeometry.WINDOW_W))
			cursor += width * 0.5
			var pos := from + axis * cursor
			var normal: Vector2 = -Vector2(rear_wall.get("normal", Vector2.ZERO)).normalized()
			if HousePlanOpenings._crowds(p, pos, normal, width, HousePlan.record_storey(original)):
				clear = false
				break
			var moved := original.duplicate(true)
			moved["pos"] = pos
			moved["normal"] = normal
			p.windows.append(moved)
			moved_windows.append(moved)
			cursor += width * 0.5 + HouseGeometry.WINDOW_MIN_GAP
		if clear:
			p.windows = all_windows
			for i in range(indices_in_order.size()):
				p.windows[indices_in_order[i]] = moved_windows[i]
			return true
		while not moved_windows.is_empty():
			moved_windows.pop_back()
			p.windows.pop_back()
	p.windows = all_windows
	# If the rear bay can fit the glazing only by removing its inter-window gap,
	# preserve the same measured aperture area as one joined light. This is legal
	# only when every source opening has the same sill and head; otherwise keep
	# the original service-side light rather than changing its daylight profile.
	if originals.size() < 2:
		return false
	var sill := float(originals[0].get("sill", HouseGeometry.WINDOW_SILL))
	var head := float(originals[0].get("head", HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H))
	var width_sum := 0.0
	for original in originals:
		if absf(float(original.get("sill", HouseGeometry.WINDOW_SILL)) - sill) > 0.001 \
				or absf(float(original.get("head", HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H)) - head) > 0.001:
			return false
		width_sum += float(original.get("width", HouseGeometry.WINDOW_W))
	var merged_width := width_sum
	if run - 0.2 < merged_width:
		return false
	# Test the replacement against other openings, not its own source windows.
	for order in range(indices_in_order.size() - 1, -1, -1):
		p.windows.remove_at(indices_in_order[order])
	for station in range(maxi(ceili((run - merged_width - 0.2) / 0.08), 1) + 1):
		var edge_gap := 0.1 + maxf(0.0, run - merged_width - 0.2) * float(station) \
			/ float(maxi(ceili((run - merged_width - 0.2) / 0.08), 1))
		var pos := from + axis * (edge_gap + merged_width * 0.5)
		var normal: Vector2 = -Vector2(rear_wall.get("normal", Vector2.ZERO)).normalized()
		if HousePlanOpenings._crowds(p, pos, normal, merged_width, HousePlan.record_storey(originals[0])):
			continue
		var merged := originals[0].duplicate(true)
		merged["pos"] = pos
		merged["normal"] = normal
		merged["width"] = merged_width
		var before_area := 0.0
		for original in originals:
			before_area += HouseGeometry.window_area(original)
		if absf(HouseGeometry.window_area(merged) - before_area) > 0.001:
			p.windows = all_windows
			return false
		p.windows.append(merged)
		return true
	p.windows = all_windows
	return false


static func _compact_window_on_alternate_wall(p: HousePlan, room: int,
		original: Dictionary, preferred_outward_normals: Array,
		forbidden_rects: Array = [], forbidden_wall_rects: Array = []) -> Dictionary:
	var width := float(original.get("width", HouseGeometry.WINDOW_W))
	var storey := HousePlan.record_storey(original)
	var walls := HouseGeometry.room_walls(p, room)
	for preferred_variant in preferred_outward_normals:
		var preferred: Vector2 = preferred_variant
		for wall_variant in walls:
			var wall: Dictionary = wall_variant
			var inward := Vector2(wall.get("normal", Vector2.ZERO)).normalized()
			var outward := -inward
			if outward != preferred:
				continue
			var from: Vector2 = wall["from"]
			var to: Vector2 = wall["to"]
			var axis := (to - from).normalized()
			var run := from.distance_to(to)
			var half := width * 0.5
			var lo := half + 0.1
			var hi := run - half - 0.1
			if hi < lo:
				continue
			var steps := maxi(ceili((hi - lo) / 0.08), 1)
			for station in range(steps + 1):
				var offset := lo + (hi - lo) * float(station) / float(steps)
				var pos := from + axis * offset
				var normal_axis := 0 if absf(inward.x) > 0.5 else 1
				var line := from.x if normal_axis == 0 else from.y
				if not HouseGeometry.is_exterior_edge(p.spec, normal_axis, line):
					continue
				if HousePlanOpenings._crowds(p, pos, outward, width, storey):
					continue
				var moved := original.duplicate(true)
				moved["pos"] = pos
				moved["normal"] = outward
				var clear: Rect2 = HouseGeometry.window_clear_rect(moved)
				var hits_reserved_work := false
				for reserved_variant in forbidden_rects:
					if clear.intersects(Rect2(reserved_variant)):
						hits_reserved_work = true
						break
				if hits_reserved_work:
					continue
				var opening: Rect2 = HouseGeometry.window_rect(moved)
				var hits_reserved_structure := false
				for reserved_variant in forbidden_wall_rects:
					if opening.intersects(Rect2(reserved_variant)):
						hits_reserved_structure = true
						break
				if hits_reserved_structure:
					continue
				return moved
	return {}


static func _is_compact_witch_shared_hall(p: HousePlan, room: int) -> bool:
	if p == null or p.spec == null or p.world_family != &"" or p.spec.get_script() != BASE_HOUSE_SPEC \
			or p.spec.style != &"witch_hut" or p.spec.trade != &"none" \
			or room < 0 or room >= p.rooms.size() or p.kind_of(room) != &"hall":
		return false
	var room_data: Dictionary = p.rooms[room]
	var functions: Array = room_data.get("domestic_functions", [])
	var station: Dictionary = room_data.get("shared_activity_station", {})
	var groups: Array = station.get("groups", [])
	return bool(room_data.get("shared_cooking", false)) \
		and bool(room_data.get("shared_witchwork", false)) \
		and functions.has(&"cooking") and functions.has(&"witchwork") \
		and String(station.get("id", "")) == "compact_witch_hearth" \
		and String(station.get("scope", "")) == "compact_witch_shared_hall" \
		and String(station.get("category", "")) == "hearth" \
		and groups.has(&"cooking") and groups.has(&"witchwork")


static func _reuse_existing_activity_support(p: HousePlan, room: int,
		key: String, group_name: String, anchor_id: String,
		prep_rect: Rect2, occupied_by_room: Dictionary) -> Dictionary:
	var walls := HouseGeometry.room_walls(p, room)
	var base := HouseFurnishGeometry.storey_base(p, room)
	var floor_y := base + HouseGeometry.FLOOR_T
	var ceiling_y := base + p.spec.height - HouseGeometry.FLOOR_T - 0.03
	var best: Dictionary = {}
	for item_index in range(p.furniture.size()):
		var item: Dictionary = p.furniture[item_index]
		if int(item.get("room", -1)) != room or not bool(item.get("mounted", false)) \
				or String(item.get("key", "")) != key or not item.has("pos") \
				or (String(item.get("activity_anchor_id", "")) != "" \
					and String(item.get("activity_anchor_id", "")) != anchor_id):
			continue
		var origin := PropCatalog.house_origin(item)
		var yaw := float(item.get("yaw", 0.0)) + PropCatalog.face_offset(key)
		var scale := float(item.get("scale", 1.0))
		var dimensions := PropCatalog.footprint_rotated(key, yaw) * scale
		var centre := PropCatalog.plan_centre(key, origin, yaw, scale)
		var body := Rect2(centre - dimensions * 0.5, dimensions)
		if not HouseGeometry.room_floor_rect(p, room).grow(0.01).encloses(body):
			continue
		var distance := _rect_distance(body, prep_rect)
		var max_distance: float = 0.75 if group_name == "witchwork" and _is_compact_witch_shared_hall(p, room) else 1.9
		if distance > max_distance:
			continue
		var bottom := origin.y + PropCatalog.floor_offset(key) * PropCatalog.placement_height_scale(item)
		var top := bottom + PropCatalog.placement_height(item)
		if bottom < floor_y + 0.9 or top > ceiling_y:
			continue
		for wi in walls.size():
			var wall: Dictionary = walls[wi]
			var normal: Vector2 = wall["normal"]
			var expected_yaw := PropCatalog.yaw_facing(normal) + PropCatalog.face_offset(key)
			if absf(wrapf(yaw - expected_yaw, -PI, PI)) > 0.03:
				continue
			var wall_point := Vector2(wall["from"])
			var wall_line := wall_point.dot(normal)
			var support := (dimensions.x * absf(normal.x)
				+ dimensions.y * absf(normal.y)) * 0.5
			if absf(centre.dot(normal) - support - wall_line) > 0.015:
				continue
			var horizontal := absf(normal.y) > 0.5
			var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
			var extent := HouseFurnishScore._piece_projection(body, axis, item)
			var depth := dimensions.y if horizontal else dimensions.x
			# A correctly supported on-surface child touches this shelf by design.
			# Temporarily remove only measured children of this exact host while
			# testing the shelf body's own collision volume.
			var removal_rows: Array[Dictionary] = [{"index": item_index}]
			for child_index in range(p.furniture.size()):
				if child_index == item_index:
					continue
				var child: Dictionary = p.furniture[child_index]
				if _is_supported_surface_child(child, item, item_index):
					removal_rows.append({"index": child_index})
			removal_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
				return int(left["index"]) > int(right["index"]))
			for row in removal_rows:
				row["item"] = p.furniture.pop_at(int(row["index"]))
			var span_clear := false
			for span in clear_wall_spans(p, room, wi, depth):
				if extent.x >= span.x - 0.03 and extent.y <= span.y + 0.03:
					span_clear = true
					break
			var collision_free := _wall_mount_clear_of_furniture(p, room, body, bottom, top)
			var route_free := _wall_mount_route_clear(p, room, body)
			removal_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
				return int(left["index"]) < int(right["index"]))
			for row in removal_rows:
				p.furniture.insert(int(row["index"]), row["item"])
			if not span_clear or not collision_free or not route_free:
				continue
			var along := (extent.x + extent.y) * 0.5
			# Keep a physically valid Witchwork rack when no lawful task-light
			# station exists. The light pass below records that shortfall separately.
			if not _allow_unlit_witchwork_support(p, group_name) and not _activity_light_candidate_available(
				p, room, wi, along, prep_rect, body, group_name, anchor_id, occupied_by_room):
				continue
			if not best.is_empty() and distance >= float(best["distance"]):
				continue
			best = {"wall": wi, "wall_row": wall, "extent": extent,
				"body": body, "distance": distance, "item_index": item_index}
	if best.is_empty():
		return {}
	var wall_index := int(best["wall"])
	var wall: Dictionary = best["wall_row"]
	var extent: Vector2 = best["extent"]
	var host_id := "wallhost:activity:%s:existing_support" % anchor_id
	_append_wall_host(p, room, wall_index, extent, wall, "activity_support",
		group_name, anchor_id, PropCatalog.category(key), host_id)
	var item: Dictionary = p.furniture[int(best["item_index"])]
	item["wall_host_id"] = host_id
	item["mount_relation"] = "supports_activity"
	item["activity_anchor_id"] = anchor_id
	item["surface_anchor_id"] = "surface:%s:existing_support" % anchor_id
	var intervals: Array = occupied_by_room[room].get(wall_index, [])
	intervals.append(extent)
	occupied_by_room[room][wall_index] = intervals
	return {"wall": wall_index, "wall_row": wall, "along": (extent.x + extent.y) * 0.5,
		"station_extent": extent, "span": extent,
		"furniture_index": int(best["item_index"])}


static func _is_supported_surface_child(child: Dictionary, host: Dictionary,
		host_index: int) -> bool:
	if int(child.get("host", -1)) != host_index or bool(child.get("mounted", false)):
		return false
	if not child.has("pos") or not child.get("rect") is Rect2:
		return false
	if int(child.get("room", -1)) != int(host.get("room", -1)):
		return false
	if HousePlan.record_storey(child) != HousePlan.record_storey(host):
		return false
	var child_key := String(child.get("key", ""))
	var host_key := String(host.get("key", ""))
	if not PropCatalog.has_tag(child_key, PropCatalog.ON_SURFACE):
		return false
	if not PropCatalog.has_tag(host_key, PropCatalog.SURFACE):
		return false
	var host_origin := PropCatalog.house_origin(host)
	var host_scale := float(host.get("scale", 1.0))
	var host_scale_y := PropCatalog.placement_height_scale(host)
	var top := host_origin.y + PropCatalog.floor_offset(host_key) * host_scale_y
	top += PropCatalog.surface_height(host_key) * host_scale_y
	var child_origin := PropCatalog.house_origin(child)
	var bottom := child_origin.y
	bottom += PropCatalog.floor_offset(child_key) * PropCatalog.placement_height_scale(child)
	if absf(bottom - top) > 0.02:
		return false
	var host_yaw := float(host.get("yaw", 0.0)) + PropCatalog.face_offset(host_key)
	var host_centre := PropCatalog.plan_centre(host_key, host_origin, host_yaw, host_scale)
	var host_size := PropCatalog.footprint_rotated(host_key, host_yaw) * host_scale
	var host_rect := Rect2(host_centre - host_size * 0.5, host_size)
	var child_yaw := float(child.get("yaw", 0.0)) + PropCatalog.face_offset(child_key)
	var child_scale := float(child.get("scale", 1.0))
	var child_centre := PropCatalog.plan_centre(child_key, child_origin, child_yaw, child_scale)
	var child_size := PropCatalog.footprint_rotated(child_key, child_yaw) * child_scale
	var child_rect := Rect2(child_centre - child_size * 0.5, child_size)
	if not host_rect.grow(-0.02).encloses(child_rect):
		return false
	return Rect2(child["rect"]).grow(0.02).encloses(child_rect)


static func _wall_mount_route_clear(p: HousePlan, room: int, body: Rect2) -> bool:
	for zone in p.zones:
		if int(zone.get("room", -1)) == room and String(zone.get("why", "")) \
				in ["stair access route", "stair foot landing", "stair head landing"] \
				and body.intersects(Rect2(zone.get("rect", Rect2()))):
			return false
	return true


## Bind a pre-existing, measured wall light to this task when it truly
## occupies the intended clear station. It stays authored furniture; only the
## derived relationship and measured wall interval are added.
static func _bind_existing_task_light(p: HousePlan, room: int, wall_index: int,
		wall: Dictionary, prep_rect: Rect2, support_rect: Rect2,
		anchor_id: String, group_name: String,
		occupied_by_room: Dictionary) -> bool:
	if not occupied_by_room.has(room):
		occupied_by_room[room] = {}
	var wall_normal: Vector2 = wall["normal"]
	var horizontal := absf(wall_normal.y) > 0.5
	var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
	var wall_point := Vector2(wall["from"])
	var wall_line := wall_point.dot(wall_normal)
	for item_index in range(p.furniture.size()):
		var item: Dictionary = p.furniture[item_index]
		if not bool(item.get("mounted", false)) or int(item.get("room", -1)) != room:
			continue
		if String(item.get("activity_anchor_id", "")) != "" \
				and String(item.get("activity_anchor_id", "")) != anchor_id:
			continue
		var key := String(item.get("key", ""))
		if key not in ["Torch_Metal", "Torch_Wall", "Sconce"]:
			continue
		if not item.has("pos") or not item.get("rect") is Rect2:
			continue
		var item_rect := Rect2(item["rect"])
		var origin := PropCatalog.house_origin(item)
		var yaw := float(item.get("yaw", 0.0)) + PropCatalog.face_offset(key)
		var scale := float(item.get("scale", 1.0))
		var centre := PropCatalog.plan_centre(key, origin, yaw, scale)
		var measured_size := PropCatalog.footprint_rotated(key, yaw) * scale
		var measured_rect := Rect2(centre - measured_size * 0.5, measured_size)
		if _rect_distance(measured_rect, prep_rect) > 1.9 \
				or _rect_distance(measured_rect, support_rect) > 1.9:
			continue
		# The model must face into this actual wall and its measured rear edge
		# must touch it. Nav-rectangle proximity alone is not a mounting proof.
		var expected_yaw := PropCatalog.yaw_facing(wall_normal) + PropCatalog.face_offset(key)
		if absf(wrapf(yaw - expected_yaw, -PI, PI)) > 0.03:
			continue
		var inward_projection := centre.dot(wall_normal)
		var back_edge := inward_projection - (measured_size.x * absf(wall_normal.x)
			+ measured_size.y * absf(wall_normal.y)) * 0.5
		if absf(back_edge - wall_line) > 0.015:
			continue
		var room_rect := HouseGeometry.room_floor_rect(p, room)
		if not room_rect.grow(0.01).encloses(measured_rect):
			continue
		var extent := HouseFurnishScore._piece_projection(measured_rect, axis, item)
		var bottom := origin.y + PropCatalog.floor_offset(key) * PropCatalog.placement_height_scale(item)
		var top := bottom + PropCatalog.placement_height(item)
		var base := HouseFurnishGeometry.storey_base(p, room)
		var floor_y := base + HouseGeometry.FLOOR_T
		var ceiling_y := base + p.spec.height - HouseGeometry.FLOOR_T - 0.03
		if bottom < floor_y + 0.9 or top > ceiling_y:
			continue
		# Exclude the candidate while checking its full measured 3D body against
		# other furniture. Then restore it at the same plan index.
		var saved: Dictionary = p.furniture.pop_at(item_index)
		var clear_spans := clear_wall_spans(p, room, wall_index,
			measured_size.y if horizontal else measured_size.x)
		var collision_free := _wall_mount_clear_of_furniture(p, room,
			measured_rect, bottom, top)
		p.furniture.insert(item_index, saved)
		if not collision_free:
			continue
		var fully_clear := false
		for span in clear_spans:
			if extent.x >= span.x - 0.03 and extent.y <= span.y + 0.03:
				fully_clear = true
				break
		if not fully_clear:
			continue
		var host_id := "wallhost:activity:%s:task_light_existing" % anchor_id
		var category := PropCatalog.category(key)
		_append_wall_host(p, room, wall_index, extent, wall,
			"lighting", group_name, anchor_id, category, host_id)
		item["wall_host_id"] = host_id
		item["mount_relation"] = "lights_activity"
		item["activity_anchor_id"] = anchor_id
		item["surface_anchor_id"] = "surface:%s:existing_task_light" % anchor_id
		var intervals: Array = occupied_by_room[room].get(wall_index, [])
		intervals.append(extent)
		occupied_by_room[room][wall_index] = intervals
		return true
	return false


## Compose only after activity placement and repair. Each host is a real wall
## interval left clear of apertures and stair wells, tied to surviving
## activity furniture by a durable ID. Rooms without the LIVE-GROUPS
## annotation stay empty; the surface pass does not invent activity.
static func compose_wall_hosts(p: HousePlan, spec: HouseSpec) -> void:
	# Exact public ordinary-HouseSpec gate. Shops, inns, hotels, keeps, insulae,
	# and every wider-world adapter retain their own composition contract.
	if spec == null or p.spec != spec or spec.trade != &"none" \
		or spec.get_script() != BASE_HOUSE_SPEC \
			or p.world_family != &"" or spec.has_method("room_program") \
			or spec.has_method("custom_room_rects"):
		return
	p.wall_hosts.clear()
	# This is the generator's final furnishing pass, after placement and repair.
	# Remove only prior derived fittings so an unchanged source plan can be
	# recomposed deterministically. Do not call it after adding non-generated
	# children hosted by a generated fitting: HousePlan.host is an array index.
	for fi in range(p.furniture.size() - 1, -1, -1):
		if bool(p.furniture[fi].get("surface_generated", false)):
			p.furniture.remove_at(fi)
	# Recomposition removes only metadata derived by this pass. Retain the
	# activity annotations and every authored placement field.
	for item_variant in p.furniture:
		var item: Dictionary = item_variant
		if bool(item.get("surface_generated", false)):
			continue
		if String(item.get("activity_binding_group", "")) != "":
			item.erase("surface_parent_id")
		for key in ["wall_host_id", "mount_relation", "activity_anchor_id",
				"activity_binding_group", "surface_anchor_id"]:
			item.erase(key)
	var found_activity := false
	var ordinals: Dictionary = {}
	var occupied_by_room: Dictionary = {}
	var selected: Dictionary = {}
	for item_index in range(p.furniture.size()):
		var item: Dictionary = p.furniture[item_index]
		var group_name := String(item.get("activity_group", ""))
		if group_name not in ["cooking", "witchwork", "sleep", "eating", "sitting"]:
			continue
		found_activity = true
		var room := int(item.get("room", -1))
		if room < 0 or room >= p.room_count():
			continue
		if not occupied_by_room.has(room):
			occupied_by_room[room] = {}
		var category := String(item.get("cat", PropCatalog.category(String(item.get("key", "")))))
		var ordinal_key := "%d|%s|%s" % [room, group_name, category]
		var ordinal := int(ordinals.get(ordinal_key, 0))
		ordinals[ordinal_key] = ordinal + 1
		var anchor_id := "activity:%d:%s:%s:%d" % [room, group_name, category, ordinal]
		item["surface_anchor_id"] = anchor_id
		var rank := _activity_anchor_rank(group_name, category, item)
		if rank >= 100:
			continue
		var selection_key := "%d|%s" % [room, group_name]
		var prior: Dictionary = selected.get(selection_key, {})
		if prior.is_empty():
			prior = {"room": room, "group": group_name, "anchors": []}
		var anchors: Array = prior["anchors"]
		anchors.append({"index": item_index, "category": category,
			"anchor_id": anchor_id, "rank": rank})
		prior["anchors"] = anchors
		selected[selection_key] = prior
	_compose_witch_room_finish_hosts(p, spec)
	if not found_activity:
		return
	for selection_variant in selected.values():
		var source: Dictionary = selection_variant
		var room := int(source["room"])
		var group_name := String(source["group"])
		var anchors: Array = source["anchors"]
		anchors.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			if int(left["rank"]) != int(right["rank"]):
				return int(left["rank"]) < int(right["rank"])
			return int(left["index"]) < int(right["index"]))
		if group_name == "sleep":
			if not _compose_sleep_anchor_with_fallback(p, spec, room, anchors, occupied_by_room):
				_note_activity_surface_unavailable(p, room, group_name)
			continue
		var anchor: Dictionary = anchors[0]
		var item: Dictionary = p.furniture[int(anchor["index"])]
		var category := String(anchor["category"])
		var anchor_id := String(anchor["anchor_id"])
		if not item.has("rect") or not item.get("rect") is Rect2:
			_note_activity_surface_unavailable(p, room, group_name)
			continue
		var prep_rect := Rect2(item.get("zone", Rect2()))
		if not prep_rect.has_area():
			prep_rect = Rect2(item["rect"])
		var anchor_position := Rect2(item["rect"]).get_center()
		_add_activity_wall_composition(p, spec, room, group_name, category,
			anchor_id, String(item.get("key", "")), anchor_position, prep_rect, occupied_by_room)
	# Every activity room gets one intentionally quiet wall interval when the
	# architecture has a clear run for it. It is a named design choice, not a
	# quota that encourages covering all available wall with props.
	for room_variant in occupied_by_room:
		var room := int(room_variant)
		var best: Dictionary = {}
		var walls := HouseGeometry.room_walls(p, room)
		for wi in walls.size():
			var cuts: Array = occupied_by_room[room].get(wi, [])
			for span in clear_wall_spans(p, room, wi, HouseGeometry.BEAM_D):
				var cursor := span.x
				var ordered: Array = cuts.duplicate()
				ordered.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
				for cut in ordered:
					# Subtract only the part inside this already-clear interval.
					# A later reservation must not extend its quiet endpoint.
					if cut.y <= span.x or cut.x >= span.y:
						continue
					cut = Vector2(maxf(cut.x, span.x), minf(cut.y, span.y))
					if cut.x - cursor > 0.6 and cut.x - cursor > float(best.get("length", 0.0)):
						best = {"wall": wi, "span": Vector2(cursor, cut.x), "length": cut.x - cursor}
					cursor = maxf(cursor, cut.y)
				if span.y - cursor > 0.6 and span.y - cursor > float(best.get("length", 0.0)):
					best = {"wall": wi, "span": Vector2(cursor, span.y), "length": span.y - cursor}
		if best.is_empty():
			continue
		var quiet_wall: Dictionary = walls[int(best["wall"])]
		var quiet_axis := Vector2.RIGHT if absf(Vector2(quiet_wall["normal"]).y) > 0.5 else Vector2(0.0, 1.0)
		var quiet_span: Vector2 = best["span"]
		var quiet_from := Vector2(quiet_span.x, quiet_wall["from"].y) if quiet_axis.x > 0.5 \
			else Vector2(quiet_wall["from"].x, quiet_span.x)
		var quiet_to := Vector2(quiet_span.y, quiet_wall["from"].y) if quiet_axis.x > 0.5 \
			else Vector2(quiet_wall["from"].x, quiet_span.y)
		var quiet_id := "wallhost:quiet:%d:%d" % [room, int(best["wall"])]
		p.wall_hosts.append({"id": quiet_id, "room": room,
			"storey": p.storey_of_room(room), "wall": int(best["wall"]),
			"from": quiet_from, "to": quiet_to,
			"normal": quiet_wall["normal"], "span": quiet_span,
			"role": "quiet", "anchor_id": "", "activity_group": ""})
		# A timber-framed house receives one interior bay on this already-clear
		# quiet span per activity room. Other construction styles receive none.
		if spec.timber_frame and spec.material != &"stone" and float(best["length"]) >= 1.5 \
				and _timber_bay_clear_of_furniture(p, room, int(best["wall"]), quiet_span):
			var bay_id := "wallhost:timber:%d:%d" % [room, int(best["wall"])]
			p.wall_hosts.append({"id": bay_id, "room": room,
				"storey": p.storey_of_room(room), "wall": int(best["wall"]),
				"from": quiet_from, "to": quiet_to,
				"normal": quiet_wall["normal"], "span": quiet_span,
				"role": "timber_bay", "source_host_id": quiet_id,
				"anchor_id": "", "activity_group": ""})
	# Existing mounted models keep their measured placement. Bind each to the
	# semantic span that actually contains it, so later checks and saves do not
	# need to infer a wall relationship from a changing furniture index.
	for item_variant in p.furniture:
		var item: Dictionary = item_variant
		if not bool(item.get("mounted", false)):
			continue
		if bool(item.get("surface_generated", false)):
			continue
		if String(item.get("wall_host_id", "")) != "":
			continue
		var room := int(item.get("room", -1))
		if room < 0 or room >= p.room_count():
			continue
		var wall := HouseFurnishScore._back_wall_index(p, room,
			Rect2(item.get("rect", Rect2())), item)
		if wall < 0:
			continue
		var walls := HouseGeometry.room_walls(p, room)
		if wall >= walls.size():
			continue
		var axis := Vector2.RIGHT if absf(Vector2(walls[wall]["normal"]).y) > 0.5 else Vector2(0.0, 1.0)
		var extent := HouseFurnishScore._piece_projection(Rect2(item.get("rect", Rect2())), axis, item)
		var preferred_anchor := String(item.get("surface_anchor_id", ""))
		for host_variant in p.wall_hosts:
			var host: Dictionary = host_variant
			if int(host["room"]) != room or int(host["wall"]) != wall:
				continue
			if preferred_anchor != "" and String(host.get("anchor_id", "")) != preferred_anchor:
				continue
			if preferred_anchor == "" and String(host.get("role", "")) != "quiet":
				continue
			var host_span: Vector2 = host["span"]
			if extent.x >= host_span.x - 0.03 and extent.y <= host_span.y + 0.03:
				item["wall_host_id"] = host["id"]
				item["mount_relation"] = "lights_activity" if host["role"] == "lighting" \
					else ("supports_activity" if host["role"] == "activity_support" \
					else "intentionally_quiet_wall")
				item["activity_anchor_id"] = host.get("anchor_id", "")
				break


	_apply_witch_work_light_profiles(p)


static func _apply_witch_work_light_profiles(p: HousePlan) -> void:
	if p == null or p.spec == null or p.spec.style != &"witch_hut" \
			or p.spec.get_script() != BASE_HOUSE_SPEC or p.spec.trade != &"none" \
			or p.world_family != &"":
		return
	for item_variant in p.furniture:
		var item: Dictionary = item_variant
		var room := int(item.get("room", -1))
		if room < 0 or room >= p.room_count() or StringName(p.kind_of(room)) not in [&"workshop", &"hall"]:
			continue
		if String(item.get("activity_group", "")) not in ["cooking", "witchwork"]:
			continue
		if PropCatalog.has_tag(String(item.get("key", "")), PropCatalog.LIGHT):
			item["house_light_profile"] = {"name": "witchwork", "energy_scale": 0.76, "range_scale": 0.84}


static func _compose_witch_room_finish_hosts(p: HousePlan, spec: HouseSpec) -> void:
	if p == null or spec == null or p.spec != spec or spec.style != &"witch_hut" \
			 or spec.get_script() != BASE_HOUSE_SPEC or spec.trade != &"none" \
			 or p.world_family != &"" or spec.has_method("room_program") \
			 or spec.has_method("custom_room_rects"):
		return
	for room in p.room_count():
		var kind := StringName(p.kind_of(room))
		if kind == &"workshop":
			pass
		elif kind == &"hall":
			var room_row: Dictionary = p.rooms[room]
			var functions: Array = room_row.get("domestic_functions", [])
			if not bool(room_row.get("shared_witchwork", false)) \
					 or not bool(room_row.get("shared_cooking", false)) \
					 or not functions.has(&"cooking") or not functions.has(&"witchwork"):
				continue
		else:
			continue
		var walls := HouseGeometry.room_walls(p, room)
		for wi in walls.size():
			var wall: Dictionary = walls[wi]
			var clear_spans := clear_wall_spans(p, room, wi, 0.07)
			for span_index in clear_spans.size():
				var span: Vector2 = clear_spans[span_index]
				if span.y - span.x < 0.55:
					continue
				var horizontal: bool = absf(Vector2(wall["normal"]).y) > 0.5
				var from := Vector2(span.x, wall["from"].y) if horizontal else Vector2(wall["from"].x, span.x)
				var to := Vector2(span.y, wall["from"].y) if horizontal else Vector2(wall["from"].x, span.y)
				var host_id := "witch_finish_%d_%d_%d" % [room, wi, span_index]
				p.wall_hosts.append({"id": host_id, "room": room, "storey": p.storey_of_room(room),
					"wall": wi, "from": from, "to": to, "normal": wall["normal"],
					"span": span, "role": "room_finish",
					"finish_intent": "cleanable_working_room", "room_kind": String(kind),
					"anchor_id": "", "activity_group": ""})


## The framing sits on the wall face, but its measured beam depth still occupies
## a real strip of the room. Do not draw a decorative bay through furniture.
## Stair and opening reservations have already been removed from clear spans.
static func _timber_bay_clear_of_furniture(p: HousePlan, room: int,
		wall_index: int, span: Vector2) -> bool:
	if room < 0 or room >= p.room_count():
		return false
	var walls := HouseGeometry.room_walls(p, room)
	if wall_index < 0 or wall_index >= walls.size():
		return false
	var body_rect := _timber_bay_body_rect(p, room, wall_index, span)
	if not body_rect.has_area():
		return false
	for item in p.furniture:
		if int(item.get("room", -1)) != room or not item.has("rect"):
			continue
		if body_rect.intersects(Rect2(item["rect"])):
			return false
	for zone in p.zones:
		if int(zone.get("room", -1)) == room and body_rect.intersects(Rect2(zone.get("rect", Rect2()))):
			return false
	return true


static func _timber_bay_body_rect(p: HousePlan, room: int,
		wall_index: int, span: Vector2) -> Rect2:
	if room < 0 or room >= p.room_count():
		return Rect2()
	var walls := HouseGeometry.room_walls(p, room)
	if wall_index < 0 or wall_index >= walls.size():
		return Rect2()
	var bay_width: float = span.y - span.x - 0.08
	if bay_width <= 0.0:
		return Rect2()
	var wall: Dictionary = walls[wall_index]
	var normal: Vector2 = wall["normal"]
	var horizontal: bool = absf(normal.y) > 0.5
	var wall_coord: float = float(wall["from"].y) if horizontal else float(wall["from"].x)
	var centre_along: float = (span.x + span.y) * 0.5
	var centre_normal: float = wall_coord + (HouseGeometry.BEAM_D * 0.5 - 0.004) \
		* (normal.y if horizontal else normal.x)
	var centre := Vector2(centre_along, centre_normal) if horizontal \
		else Vector2(centre_normal, centre_along)
	var size := Vector2(bay_width, HouseGeometry.BEAM_D) if horizontal \
		else Vector2(HouseGeometry.BEAM_D, bay_width)
	return Rect2(centre - size * 0.5, size)
