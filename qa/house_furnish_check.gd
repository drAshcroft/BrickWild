class_name HouseFurnishCheck
extends RefCounted
## Does the furnishing make sense?
##
## The physical rules first, because a room that fails those is not furnished
## at all:
##   PLACED     every piece is inside its own room, and nothing is inside
##              anything else
##   SUPPORTED  a mug is on a table, not hovering where a table used to be
##   DOORWAYS   nothing stands in the swing of a door
##   DAYLIGHT   nothing tall stands across a window
##
## Then the rules an interior designer would recognise:
##   PROGRAM    a bedroom has a bed, a kitchen has a hearth, a hall has
##              somewhere to sit, a smithy has an anvil
##   AGAINST    the pieces that want a wall have one behind them
##   SEATING    seats are at a table and facing it
##   LIGHT      every room people use has something to see by
##   DENSITY    the room is furnished, not filled
##
## And last the ones the brief called feng shui, which in a bedroom are simply
## the ones everybody already follows:
##   COMMAND    the bed's head is against solid wall, and the bed does not sit
##              in the line of the door
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

const TOL := 0.03

## What each room kind must actually contain, by prop category.
const REQUIRED := {
	&"bedroom": ["bed"],
	&"kitchen": ["hearth"],
	&"hall": ["table"],
	&"parlour": ["table"],
	&"workshop": ["workbench"],
	&"sales_floor": ["counter"],
	&"stable": ["stall"],
	&"tack_room": ["storage"],
	&"dining_room": ["table"],
	&"guest_room": ["bed"],
	&"office": ["workbench"],
	&"records": ["bookcase"],
	&"council_chamber": ["table"],
	&"meeting_hall": ["table"],
	&"lobby": ["counter"],
	&"lounge": ["table"],
	&"suite": ["bed"],
	&"laundry": ["workbench"],
}

## And what a trade must have in the room it works in.
const TRADE_REQUIRED := {
	&"smith": {&"workshop": ["anvil"]},
	&"alchemist": {&"workshop": ["bookcase"]},
	&"scholar": {&"parlour": ["bookcase"]},
}

const BUSINESS_REQUIRED := {
	&"blacksmith": {&"workshop": ["anvil"]},
	&"bakery": {&"kitchen": ["hearth"]},
}

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}


func check(plan: HousePlan) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	stats["furniture"] = plan.furniture.size()

	_check_placed(plan)
	_check_vertical(plan)
	_check_supported(plan)
	_check_doorways(plan)
	_check_windows(plan)
	_check_program(plan)
	_check_against_wall(plan)
	_check_seating(plan)
	_check_light(plan)
	_check_density(plan)
	_check_command_position(plan)
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats}


static func _who(plan: HousePlan, f: int) -> String:
	var p: Dictionary = plan.furniture[f]
	return "%s in room %d (%s)" % [p["key"], p["room"], String(plan.kind_of(p["room"]))]


# --------------------------------------------------------------- physical

## Inside its room, and clear of everything else standing on the floor.
func _check_placed(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		var key: String = p["key"]
		if not PropCatalog.known(key):
			failures.append("placed: %s is not in the prop catalogue" % key)
			continue
		if p.get("mounted", false) or p["host"] >= 0:
			continue
		var room_rect: Rect2 = HouseGeometry.room_floor_rect(plan, p["room"])
		var rect: Rect2 = p["rect"]
		if not room_rect.grow(TOL).encloses(rect):
			failures.append("placed: %s is partly in the wall" % _who(plan, f))
		# the size it claims must be the size the asset actually is
		var want: Vector2 = PropCatalog.footprint_yawed(key, float(p["yaw"])) \
			* float(p.get("scale", 1.0))
		if absf(rect.size.x - want.x) > 0.05 or absf(rect.size.y - want.y) > 0.05:
			failures.append("placed: %s claims a %.2f x %.2fm footprint, the model is %.2f x %.2fm"
				% [_who(plan, f), rect.size.x, rect.size.y, want.x, want.y])

	for a in range(plan.furniture.size()):
		var pa: Dictionary = plan.furniture[a]
		if pa.get("mounted", false) or pa["host"] >= 0:
			continue
		for b in range(a + 1, plan.furniture.size()):
			var pb: Dictionary = plan.furniture[b]
			if pb.get("mounted", false) or pb["host"] >= 0:
				continue
			if HousePlan.record_storey(pa) != HousePlan.record_storey(pb):
				continue
			var over: Rect2 = Rect2(pa["rect"]).intersection(pb["rect"])
			if over.size.x > TOL and over.size.y > TOL:
				failures.append("placed: %s and %s stand in the same %.2f x %.2fm of floor"
					% [_who(plan, a), _who(plan, b), over.size.x, over.size.y])


## Furniture is planned in X/Z rectangles, but its model must occupy the room's
## vertical band.  This catches an upper-storey placement left at Y=0 and a
## prop accidentally hanging through the ceiling.
func _check_vertical(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		var room: int = int(p.get("room", -1))
		if room < 0 or room >= plan.room_count():
			failures.append("vertical: furniture %d references no room" % f)
			continue
		var level := HousePlan.record_storey(plan.rooms[room])
		if HousePlan.record_storey(p) != level:
			failures.append("vertical: %s is tagged for storey %d, room is on %d"
				% [_who(plan, f), HousePlan.record_storey(p), level])
		var base: float = float(level) * plan.spec.height
		var y: float = float(p["pos"].y)
		if y < base - TOL or y > base + plan.spec.height + TOL:
			failures.append("vertical: %s origin Y %.2f outside storey %d band %.2f..%.2f"
				% [_who(plan, f), y, level, base, base + plan.spec.height])


## A prop that must sit on a surface must actually be on one, at its height and
## within its top. This is the check that catches a candle floating where a
## table was moved from.
func _check_supported(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		var key: String = p["key"]
		if not PropCatalog.has_tag(key, PropCatalog.ON_SURFACE):
			continue
		var host: int = p["host"]
		if host < 0:
			failures.append("supported: %s is on the floor, and belongs on a surface"
				% _who(plan, f))
			continue
		var host_key: String = plan.furniture[host]["key"]
		if not PropCatalog.has_tag(host_key, PropCatalog.SURFACE):
			failures.append("supported: %s is set on a %s, which has no top"
				% [_who(plan, f), host_key])
			continue
		if HousePlan.record_storey(plan.furniture[host]) != HousePlan.record_storey(p):
			failures.append("supported: %s is hosted by a different storey" % _who(plan, f))
		var top: float = float(plan.furniture[host]["pos"].y) \
			+ PropCatalog.surface_height(host_key) \
			* float(plan.furniture[host].get("scale", 1.0))
		if absf(float(p["pos"].y) - top) > 0.02:
			failures.append("supported: %s floats %.2fm above the %s it sits on"
				% [_who(plan, f), float(p["pos"].y) - top, host_key])
		if not Rect2(plan.furniture[host]["rect"]).grow(0.02).encloses(p["rect"]):
			failures.append("supported: %s hangs over the edge of the %s"
				% [_who(plan, f), host_key])


## Nothing may stand where a door needs to swing, on either side of it.
func _check_doorways(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		if p.get("mounted", false) or p["host"] >= 0:
			continue
		var rect: Rect2 = p["rect"]
		for d in range(plan.doors.size()):
			var door: Dictionary = plan.doors[d]
			if HousePlan.record_storey(door) != HousePlan.record_storey(p):
				continue
			for side in [-1.0, 1.0]:
				var clear: Rect2 = HouseGeometry.door_clear_rect(door, side)
				var over: Rect2 = clear.intersection(rect)
				if over.size.x > TOL and over.size.y > TOL:
					failures.append("doorway: %s stands in the swing of door %d"
						% [_who(plan, f), d])


## And nothing tall may stand across a window.
func _check_windows(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		if p.get("mounted", false) or p["host"] >= 0:
			continue
		if PropCatalog.height(p["key"]) <= HouseGeometry.WINDOW_SILL:
			continue
		for w in plan.windows_of(p["room"]):
			var clear: Rect2 = HouseGeometry.window_clear_rect(plan.windows[w])
			var over: Rect2 = clear.intersection(p["rect"])
			if over.size.x > TOL and over.size.y > TOL:
				failures.append("daylight: %s (%.2fm tall) stands across window %d"
					% [_who(plan, f), PropCatalog.height(p["key"]), w])


# --------------------------------------------------------------- programme

## A bedroom with no bed is a room, not a bedroom.
func _check_program(plan: HousePlan) -> void:
	var spec: HouseSpec = plan.spec
	for i in range(plan.room_count()):
		var kind: StringName = plan.kind_of(i)
		var cats: Array = REQUIRED.get(kind, [])
		# a house with nowhere to call a bedroom sleeps in the hall
		if not spec is ShopSpec and kind == &"hall" and not plan.has_kind(&"bedroom"):
			cats = cats + ["bed"]
		for cat in cats:
			if _room_has(plan, i, cat):
				continue
			if plan.was_dropped(i, cat):
				warnings.append("programme: room %d (%s) gave up its %s so the rooms beyond it could be reached"
					% [i, String(kind), cat])
			elif not _could_hold(plan, i, cat):
				warnings.append("programme: room %d (%s) has no %s, and is too small to take one"
					% [i, String(kind), cat])
			else:
				failures.append("programme: room %d (%s) has no %s"
					% [i, String(kind), cat])
		if kind == &"hall" or kind == &"parlour":
			if _room_has(plan, i, "table") and _seat_count(plan, i) == 0 \
					and not plan.was_dropped(i, "seat"):
				if _could_hold(plan, i, "seat"):
					failures.append("programme: room %d (%s) has a table and nothing to sit on"
						% [i, String(kind)])
				else:
					warnings.append("programme: room %d (%s) has a table and no room for a seat"
						% [i, String(kind)])
	var demands: Dictionary = BUSINESS_REQUIRED.get((spec as ShopSpec).business, {}) \
		if spec is ShopSpec else TRADE_REQUIRED.get(spec.trade, {})
	for kind in demands:
		for i in plan.rooms_of(kind):
			for cat in demands[kind]:
				if _room_has(plan, i, cat):
					continue
				if plan.was_dropped(i, cat):
					warnings.append("programme: a %s's %s could not fit a %s beside everything else it needed"
						% [_purpose(spec), String(kind), cat])
				elif not _could_hold(plan, i, cat):
					warnings.append("programme: a %s's %s is too small for a %s"
						% [_purpose(spec), String(kind), cat])
				else:
					failures.append("programme: a %s's %s has no %s"
						% [_purpose(spec), String(kind), cat])


static func _purpose(spec: HouseSpec) -> String:
	return String((spec as ShopSpec).business) if spec is ShopSpec else String(spec.trade)


## Could ANY prop of this category physically fit in the room, footprint and
## use zone together? A 3 x 3 m hall genuinely cannot hold a 2.8 m table, and
## reporting that as a defect would be reporting the size of the house.
static func _could_hold(plan: HousePlan, room: int, cat: String) -> bool:
	return HouseFurnisher.could_place(plan, room, cat)


static func _room_has(plan: HousePlan, room: int, cat: String) -> bool:
	for f in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[f]["key"]) == cat:
			return true
	return false


static func _seat_count(plan: HousePlan, room: int) -> int:
	var n := 0
	for f in plan.furniture_of(room):
		var c: String = PropCatalog.category(plan.furniture[f]["key"])
		if c == "seat" or c == "bench":
			n += 1
	return n


# ------------------------------------------------------------- arrangement

## A bed, a cabinet, a bookcase with its back to open air reads as furniture
## dropped from above. Check the back of every piece that asked for a wall.
func _check_against_wall(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		if p.get("mounted", false) or p["host"] >= 0:
			continue
		if not PropCatalog.has_tag(p["key"], PropCatalog.WALL):
			continue
		if p.get("free_standing", false):
			# the furnisher could find no wall for it and said so; a workbench
			# out in the room is a compromise, not a defect
			warnings.append("against: %s stands free -- no wall in the room would take it"
				% _who(plan, f))
			continue
		var gap: float = _back_gap(plan, p)
		if gap > HouseGeometry.WALL_GAP + HouseGeometry.BED_HEAD_TOL:
			failures.append("against: %s stands %.2fm off the wall it should back onto"
				% [_who(plan, f), gap])


## Distance from the back of a piece to the room wall behind it.
static func _back_gap(plan: HousePlan, p: Dictionary) -> float:
	var room_rect: Rect2 = HouseGeometry.room_floor_rect(plan, p["room"])
	var yaw: float = float(p["yaw"])
	var facing := Vector2(-sin(yaw), -cos(yaw))
	var back: Vector2 = -facing
	var rect: Rect2 = p["rect"]
	var c: Vector2 = rect.get_center()
	var half: Vector2 = rect.size / 2.0
	var edge: Vector2 = c + back * Vector2(absf(back.x) * half.x + absf(back.y) * half.y,
		absf(back.x) * half.x + absf(back.y) * half.y)
	if absf(back.x) > 0.5:
		var wall_x: float = room_rect.end.x if back.x > 0.0 else room_rect.position.x
		return absf(wall_x - edge.x)
	var wall_z: float = room_rect.end.y if back.y > 0.0 else room_rect.position.y
	return absf(wall_z - edge.y)


## A chair belongs at a table, facing it. A chair in the middle of the floor
## facing a wall is the single clearest sign of an automatic layout.
func _check_seating(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		var cat: String = PropCatalog.category(p["key"])
		if cat != "seat" and cat != "bench":
			continue
		var host: int = p.get("host", -1)
		if host < 0:
			# it may still be at a table it was not explicitly given
			host = _nearest_table(plan, p)
		if host < 0:
			warnings.append("seating: %s is not at any table" % _who(plan, f))
			continue
		# toward the NEAREST PART of the table, not its middle: a stool tucked
		# under one end of a long table is still facing it, and measuring to
		# the centre would say it had its back to it
		var seat_c: Vector2 = Rect2(p["rect"]).get_center()
		var host_rect: Rect2 = plan.furniture[host]["rect"]
		var near := Vector2(
			clampf(seat_c.x, host_rect.position.x, host_rect.end.x),
			clampf(seat_c.y, host_rect.position.y, host_rect.end.y))
		var to_table: Vector2 = near - seat_c
		if to_table.length() < 0.01:
			continue        # tucked right under it; it can only be facing it
		if to_table.length() < 0.01:
			continue
		var yaw: float = float(p["yaw"])
		var facing := Vector2(-sin(yaw), -cos(yaw))
		if facing.dot(to_table.normalized()) < 0.5:
			failures.append("seating: %s has its back to the table it is drawn up to"
				% _who(plan, f))


static func _nearest_table(plan: HousePlan, p: Dictionary) -> int:
	var best := -1
	var best_d := 1.6            # a seat further off than this is not "at" it
	for f in plan.furniture_of(p["room"]):
		var cat: String = PropCatalog.category(plan.furniture[f]["key"])
		if cat != "table" and cat != "workbench" and cat != "counter":
			continue
		var d: float = Rect2(plan.furniture[f]["rect"]).get_center().distance_to(
			Rect2(p["rect"]).get_center())
		if d < best_d:
			best_d = d
			best = f
	return best


## Something to see by, in every room somebody uses after dark.
func _check_light(plan: HousePlan) -> void:
	for i in range(plan.room_count()):
		if not HouseGeometry.is_habitable(plan.kind_of(i)):
			continue
		var lit := false
		for f in plan.furniture_of(i):
			if PropCatalog.has_tag(plan.furniture[f]["key"], PropCatalog.LIGHT):
				lit = true
				break
		if not lit:
			warnings.append("light: room %d (%s) has no lamp, sconce or candle"
				% [i, String(plan.kind_of(i))])


func _check_density(plan: HousePlan) -> void:
	var worst := 0.0
	for i in range(plan.room_count()):
		var used := 0.0
		for f in plan.furniture_of(i):
			var p: Dictionary = plan.furniture[f]
			if p.get("mounted", false) or p["host"] >= 0:
				continue
			used += Rect2(p["rect"]).size.x * Rect2(p["rect"]).size.y
		var area: float = HouseGeometry.room_area(plan, i)
		var frac: float = used / maxf(area, 0.01)
		worst = maxf(worst, frac)
		if frac > HouseGeometry.FURNITURE_DENSITY_MAX:
			warnings.append("density: room %d (%s) is %.0f%% furniture by floor area"
				% [i, String(plan.kind_of(i)), frac * 100.0])
	stats["worst_density"] = snappedf(worst, 0.01)


# ---------------------------------------------------------- feng shui

## The commanding position: headboard against solid wall, and out of the line
## of the door. It is a feng shui rule and also plain sense -- a bed in the
## line of a door is a bed in a corridor.
func _check_command_position(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) != "bed":
			continue
		var gap: float = _back_gap(plan, p)
		if gap > HouseGeometry.WALL_GAP + HouseGeometry.BED_HEAD_TOL:
			failures.append("command: the headboard of the %s stands %.2fm off the wall"
				% [_who(plan, f), gap])
		var rect: Rect2 = p["rect"]
		var c: Vector2 = rect.get_center()
		for d in plan.doors_of(p["room"]):
			var door: Dictionary = plan.doors[d]
			var dn: Vector2 = door["normal"]
			var across: float = absf((c - Vector2(door["pos"])).dot(Vector2(dn.y, -dn.x)))
			var half: float = (absf(dn.y) * rect.size.x + absf(dn.x) * rect.size.y) / 2.0
			if across < (float(door["width"]) / 2.0 + half) * 0.5:
				warnings.append("command: the %s lies in the line of door %d"
					% [_who(plan, f), d])
		# and you have to be able to get into it: its own side is kept clear by
		# the furnisher, so this only re-checks that the zone is real floor
		var zone: Rect2 = p["zone"]
		var room_rect: Rect2 = HouseGeometry.room_floor_rect(plan, p["room"])
		if zone.size.x <= 0.0:
			failures.append("command: the %s has no side to get into it from" % _who(plan, f))
		elif not room_rect.grow(0.05).encloses(zone):
			failures.append("command: the only side of the %s you could get in from is inside a wall"
				% _who(plan, f))
