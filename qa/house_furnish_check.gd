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
##   HEARTH     the fire is on the wall the planner gave the chimney, so the
##              smoke has somewhere to go
## and one rule per affinity in PropCatalog, each of them a sentence and a
## measurement (LAY-003):
##   WORKBENCH_DAYLIGHT  a bench is worked at in the light
##   BOOKCASE_HEAT       books keep off the chimney wall
##   BED_WINDOW          you do not sleep with your head under the window
##   TABLE_FOCUS         the table draws up toward the fire
##   SCONCE_PAIR         two lamps are a pair, not a scatter
##   SHELF_OVER          a shelf hangs over the bench it serves
##   CHANDELIER_OVER     the chandelier hangs over the table
##   CORNER_CLUTTER      barrels stand out of the traffic
## and the one the temple taught (INT-002):
##   FOCUS               the piece the plan is arranged around stands where
##                       the plan says, and looks at the door when it must
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
	&"great_hall": ["table"],
	&"lords_chamber": ["bed"],
	&"nave": ["table"],
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

## Which rule each message prefix belongs to, so a report can group a house's
## complaints the way this file is laid out rather than by guessing at the
## words. HouseQA passes it straight through.
const GROUPS := {
	"physical": ["placed", "vertical", "supported", "doorway", "daylight"],
	"programme": ["programme", "light", "density"],
	"arrangement": ["against", "seating", "row", "clear"],
	"feng shui": ["command", "hearth", "workbench_daylight", "bookcase_heat",
		"bed_window", "table_focus", "sconce_pair", "shelf_over",
		"chandelier_over", "corner_clutter", "focus"],
}

## Every rule, in the order it runs, by the name its messages carry. A family
## may replace one through `check(plan, overrides)` (RuleSet, INT-020).
const RULES: Array[StringName] = [&"placed", &"vertical", &"supported", &"doorway",
	&"daylight", &"programme", &"against", &"seating", &"light", &"density",
	&"command", &"hearth", &"row", &"clear", &"workbench_daylight", &"bookcase_heat",
	&"bed_window", &"table_focus", &"sconce_pair", &"shelf_over",
	&"chandelier_over", &"corner_clutter", &"focus"]
## Where a rule's method is not simply "_check_" + its name.
const METHODS := {&"doorway": "_check_doorways", &"daylight": "_check_windows",
	&"programme": "_check_program", &"against": "_check_against_wall",
	&"command": "_check_command_position"}

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
## {rule: replacement name} for the rules a family replaced this run.
var replaced: Dictionary = {}


func check(plan: HousePlan, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	stats["furniture"] = plan.furniture.size()
	replaced = RuleSet.run(self, RULES, METHODS, overrides, [plan], [plan],
		failures, warnings)
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "groups": GROUPS, "replaced": replaced}


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
		# A dining chair has a host to identify its table, but still stands on
		# the floor. Only props physically placed ON a host skip floor bounds.
		if p.get("mounted", false) or (p["host"] >= 0 and PropCatalog.has_tag(key, PropCatalog.ON_SURFACE)):
			continue
		var room_rect: Rect2 = HouseGeometry.room_floor_rect(plan, p["room"])
		var rect: Rect2 = p["rect"]
		if not room_rect.grow(TOL).encloses(rect):
			failures.append("placed: %s is partly in the wall" % _who(plan, f))
		if plan.is_polygonal(int(p["room"])):
			for corner in Poly.from_rect(rect):
				if not Poly.contains_point(plan.outline_of(int(p["room"])), corner, TOL):
					failures.append("placed: %s crosses a shaped room wall" % _who(plan, f))
					break
		# the size it claims must be the size the asset actually is
		var want: Vector2 = PropCatalog.footprint_rotated(key, float(p["yaw"])) \
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

## Does anybody sleep anywhere in this plan?
static func _anybody_sleeps(plan: HousePlan) -> bool:
	for kind in HouseGeometry.SLEEPING:
		if plan.has_kind(kind):
			return true
	return false


## A bedroom with no bed is a room, not a bedroom.
func _check_program(plan: HousePlan) -> void:
	var spec: HouseSpec = plan.spec
	for i in range(plan.room_count()):
		var kind: StringName = plan.kind_of(i)
		var cats: Array = REQUIRED.get(kind, [])
		# A house with nowhere to call a bedroom sleeps in the hall -- but
		# &"bedroom" is not the only room people sleep in, and a keep whose
		# lord has a chamber at the top was being told to bed down in its hall
		# as well. HouseFurnisher asks the same question the same way.
		if not spec is ShopSpec and kind == &"hall" and not _anybody_sleeps(plan):
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
	return HouseFurnishPlacement.could_place(plan, room, cat)


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
		# Vector2 is float32: allow one micrometre of metric roundoff at
		# the authored limit, without relaxing the physical backing rule.
		if gap > HouseGeometry.WALL_GAP + HouseGeometry.BED_HEAD_TOL + BACKING_EPS:
			failures.append("against: %s stands %.2fm off the wall it should back onto"
				% [_who(plan, f), gap])


## Distance from the back of a piece to the room wall behind it.
##
## Measured against the room's OWN WALLS rather than against the box round
## them. For a rectangle the two are the same thing and the answer does not
## move; for an octagon the wall behind a cabinet is a diagonal, and measuring
## to the bounding box reported every piece in the room as standing a metre and
## a quarter off a wall it was flat against (GEO-002).
static func _back_gap(plan: HousePlan, p: Dictionary) -> float:
	var yaw: float = float(p["yaw"])
	var back := Vector2(sin(yaw), cos(yaw))          # the opposite of facing
	# The piece's OWN depth, not half its axis-aligned box: a cabinet turned
	# onto a diagonal wall has a box bigger than it is, and measuring from the
	# corner of that box put it a metre off a wall it was flat against.
	var foot: Vector2 = PropCatalog.footprint(String(p["key"])) 		* float(p.get("scale", 1.0))
	var edge: Vector2 = Rect2(p["rect"]).get_center() + back * (foot.y / 2.0)
	var breast := HouseGeometry.hearth_breast(plan)
	if PropCatalog.category(String(p["key"])) == "hearth" and not breast.is_empty() \
			and int(breast["room"]) == int(p["room"]):
		var normal: Vector2 = breast["normal"]
		var face: Vector2 = breast["centre"] + normal * float(breast["depth"]) * 0.5
		return absf((edge - face).dot(normal))
	var best := INF
	for w in HouseGeometry.room_walls(plan, int(p["room"])):
		var n: Vector2 = w["normal"]                 # points INTO the room
		if n.dot(back) > -0.5:
			continue                                 # not the wall behind it
		best = minf(best, absf((edge - Vector2(w["from"])).dot(n)))
	return best if is_finite(best) else 0.0


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
		if to_table.length() > 1.6:
			failures.append("seating: %s is too far from the table it is drawn up to" % _who(plan, f))
			continue
		if to_table.length() < 0.01:
			continue        # tucked right under it; it can only be facing it
		var yaw: float = float(p["yaw"])
		var facing := Vector2(-sin(yaw), -cos(yaw))
		# a bench across the narrow end of a table is wider than the end it
		# faces, so its centre's nearest point is the table's corner: what
		# counts is that looking straight ahead from the seat you see table
		var across := Vector2(-facing.y, facing.x)
		var half_w: float = (absf(across.x) * Rect2(p["rect"]).size.x
			+ absf(across.y) * Rect2(p["rect"]).size.y) / 2.0
		var sees := false
		for t in [-0.8, -0.4, 0.0, 0.4, 0.8]:
			if _ray_hits_rect(seat_c + across * (half_w * t), facing, host_rect.grow(0.05), 1.6):
				sees = true
		if sees:
			continue
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
		if gap > HouseGeometry.WALL_GAP + HouseGeometry.BED_HEAD_TOL + BACKING_EPS:
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


## A fire needs a flue. HousePlan.hearth is the one record of where the two of
## them meet: the planner names a room and a wall, the builder raises the stack
## on it, and the furnisher stands the hearth against it. This rule is what
## proves the three of them still agree.
func _check_hearth(plan: HousePlan) -> void:
	var lit: Array[int] = []
	for f in range(plan.furniture.size()):
		if PropCatalog.category(plan.furniture[f]["key"]) == "hearth":
			lit.append(f)
	var room: int = plan.hearth_room()
	if room < 0:
		for f in lit:
			failures.append("hearth: the %s stands in a house with no chimney planned"
				% _who(plan, f))
		return
	var wall: int = plan.hearth_wall()
	var wants_one: bool = "hearth" in REQUIRED.get(plan.kind_of(room), [])
	var here: Array[int] = []
	for f in lit:
		if plan.furniture[f]["room"] == room:
			here.append(f)
	if here.is_empty() and wants_one:
		if plan.was_dropped(room, "hearth") or not _could_hold(plan, room, "hearth"):
			warnings.append("hearth: room %d has the chimney on wall %d and no fire under it"
				% [room, wall])
		else:
			failures.append("hearth: room %d has the chimney on wall %d and no fire under it"
				% [room, wall])
	for f in here:
		var on: int = _wall_of(plan, plan.furniture[f])
		if on != wall:
			failures.append("hearth: the hearth in room %d stands on wall %d but the chimney is on wall %d"
				% [room, on, wall])


## Which of the room's four walls a piece has its back to, indexed the way
## HouseGeometry.room_walls() indexes them. Its facing says it: a piece in a
## corner touches two walls and only one of them is behind it.
static func _wall_of(plan: HousePlan, p: Dictionary) -> int:
	var yaw: float = float(p["yaw"])
	var back := Vector2(sin(yaw), cos(yaw))
	var room := int(p.get("room", -1))
	if room >= 0 and room < plan.room_count() and plan.is_polygonal(room):
		var walls := HouseGeometry.room_walls(plan, room)
		var best := -1
		var facing := -INF
		for index in range(walls.size()):
			var dot := back.dot(-Vector2(walls[index].normal))
			if dot > facing:
				best = index
				facing = dot
		return best
	if absf(back.y) >= absf(back.x):
		return 1 if back.y > 0.0 else 0
	return 3 if back.x > 0.0 else 2


## A row is straight, evenly pitched, all facing the same way, and every
## copy's use zone is the same shared aisle strip. `HouseFurnishPlacement._place_row`
## builds a row that way by construction; this measures the result the way
## every other rule here is measured -- from the placements alone, trusting
## nothing about how they got there.
const ROW_STRAIGHT_TOL := 0.05
const ROW_PITCH_TOL := 0.02

func _check_row(plan: HousePlan) -> void:
	var groups: Dictionary = {}
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		var group: String = String(p.get("row", ""))
		if group == "":
			continue
		if not groups.has(group):
			groups[group] = []
		groups[group].append(f)
	for group in groups:
		_check_one_row(plan, groups[group])


func _check_one_row(plan: HousePlan, members: Array) -> void:
	if members.size() < 2:
		return
	var pts: Array[Vector2] = []
	var yaw0: float = float(plan.furniture[members[0]]["yaw"])
	var zone0: Rect2 = plan.furniture[members[0]]["zone"]
	var who0: String = _who(plan, members[0])
	for f in members:
		var p: Dictionary = plan.furniture[f]
		pts.append(Rect2(p["rect"]).get_center())
		if not is_equal_approx(float(p["yaw"]), yaw0) \
				and absf(float(p["yaw"]) - yaw0) > 0.01:
			failures.append("row: %s does not face the same way as %s"
				% [_who(plan, f), who0])
		var zone: Rect2 = p["zone"]
		if not zone.is_equal_approx(zone0):
			failures.append("row: %s does not share the same aisle as %s"
				% [_who(plan, f), who0])
	# collinearity: how far each centre strays from the line through the two ends
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[pts.size() - 1]
	var along: Vector2 = (b - a)
	var len: float = along.length()
	if len > 0.01:
		var dir: Vector2 = along / len
		var normal := Vector2(-dir.y, dir.x)
		for i in range(pts.size()):
			var off: float = absf((pts[i] - a).dot(normal))
			if off > ROW_STRAIGHT_TOL:
				failures.append("row: %s is %.2fm off the line of its row"
					% [_who(plan, members[i]), off])
	# even pitch: consecutive centres (sorted along the row) the same distance apart
	var order: Array = members.duplicate()
	order.sort_custom(func(x: int, y: int) -> bool:
		return Rect2(plan.furniture[x]["rect"]).get_center().distance_to(a) \
			< Rect2(plan.furniture[y]["rect"]).get_center().distance_to(a))
	var pitches: Array[float] = []
	for i in range(1, order.size()):
		var d: float = Rect2(plan.furniture[order[i]]["rect"]).get_center() \
			.distance_to(Rect2(plan.furniture[order[i - 1]]["rect"]).get_center())
		pitches.append(d)
	if pitches.size() > 1:
		var ref: float = pitches[0]
		for i in range(1, pitches.size()):
			if absf(pitches[i] - ref) > ROW_PITCH_TOL:
				failures.append("row: the pitch between %s varies (%.2fm vs %.2fm)"
					% [who0, pitches[i], ref])
	# the shared aisle has to be real floor, deep enough to walk, and every
	# member's own use zone has to be exactly it -- not a private zone that
	# happens to overlap
	if zone0.size.x > 0.0:
		var depth: float = minf(zone0.size.x, zone0.size.y)
		if depth < HouseGeometry.PATH_MIN - TOL:
			failures.append("row: the aisle behind %s is only %.2fm wide"
				% [who0, depth])


## Which of the room's four walls a rectangle has its BACK to, or -1 when it
## stands free of all of them. Measured from the gaps, the way LAY-002's
## placer measures it -- yaw says which way a piece looks, not what it is
## pushed up against, and a corner piece looks whichever way it was authored.
const FS_BACK_TOL := 0.14
const BACKING_EPS := 0.000001

static func _fs_back_wall(plan: HousePlan, room: int, rect: Rect2, piece: Dictionary = {}) -> int:
	if plan.is_polygonal(room):
		var walls := HouseGeometry.room_walls(plan, room)
		var found := -1
		var nearest := FS_BACK_TOL
		for i in range(walls.size()):
			var wall: Dictionary = walls[i]
			var normal: Vector2 = wall.normal
			if not piece.is_empty():
				var yaw: float = float(piece.yaw)
				if normal.dot(Vector2(-sin(yaw), -cos(yaw))) < 0.999:
					continue
			var extent := _fs_projection(rect, normal, piece)
			var gap: float = absf(extent.x - Vector2(wall.from).dot(normal))
			if not piece.is_empty() and piece.get("mounted", false):
				gap = absf((rect.get_center() - Vector2(wall.from)).dot(normal))
			if gap < nearest:
				nearest = gap
				found = i
		return found
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var gaps := [rect.position.y - f.position.y, f.end.y - rect.end.y,
		rect.position.x - f.position.x, f.end.x - rect.end.x]
	var best := -1
	var best_gap := FS_BACK_TOL
	for i in range(4):
		if float(gaps[i]) < best_gap:
			best_gap = float(gaps[i])
			best = i
	return best


static func _fs_wall_normal(plan: HousePlan, room: int, wi: int) -> Vector2:
	return HouseGeometry.room_walls(plan, room)[wi].normal


static func _fs_projection(rect: Rect2, axis: Vector2, piece: Dictionary = {}) -> Vector2:
	var center := rect.get_center().dot(axis)
	var half := rect.size.dot(axis.abs()) * 0.5
	if not piece.is_empty():
		var yaw: float = float(piece.yaw)
		var size: Vector2 = PropCatalog.footprint(piece.key) * float(piece.get("scale", 1.0))
		half = (size.x * absf(Vector2(cos(yaw), -sin(yaw)).dot(axis)) \
			+ size.y * absf(Vector2(-sin(yaw), -cos(yaw)).dot(axis))) * 0.5
	return Vector2(center - half, center + half)


static func _fs_wall_lit(plan: HousePlan, room: int, wi: int) -> bool:
	for w in plan.windows_of(room):
		if Vector2(plan.windows[w]["normal"]).dot(_fs_wall_normal(plan, room, wi)) < -0.999:
			return true
	return false


## Every feng shui rule below reports the same way: a piece the furnisher had
## to compromise over -- one it dropped for walkability, or one it could find
## no wall for -- is a warning, and anything else is a defect. Exactly the
## shape the programme rule uses.
func _fs_report(plan: HousePlan, p: Dictionary, cat: String, msg: String) -> void:
	if p.get("free_standing", false) or plan.was_dropped(int(p["room"]), cat):
		warnings.append(msg)
	else:
		failures.append(msg)


## A bench is worked at, and a person works in the light. A workbench in a room
## with a window backs onto the wall that window is in, or at the very least
## stands within reach of it.
## Generated houses satisfy the strict form (the window wall itself) in 100% of
## cases, so this fails outright.
const FS_WINDOW_REACH := 2.5

func _check_workbench_daylight(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) != "workbench":
			continue
		if p.get("mounted", false) or int(p["host"]) >= 0:
			continue
		var room: int = int(p["room"])
		if plan.windows_of(room).is_empty():
			continue
		var wi: int = _fs_back_wall(plan, room, p["rect"], p)
		if wi >= 0 and _fs_wall_lit(plan, room, wi):
			continue
		var c: Vector2 = Rect2(p["rect"]).get_center()
		var near := INF
		for w in plan.windows_of(room):
			near = minf(near, c.distance_to(Vector2(plan.windows[w]["pos"])))
		if near <= FS_WINDOW_REACH:
			continue
		_fs_report(plan, p, "workbench",
			"workbench_daylight: %s works %.2fm from the nearest window, with its back to a blind wall"
			% [_who(plan, f), near])


## Heat and parchment do not mix: a bookcase keeps off the wall the chimney is
## in. No generated house has ever put one there; the rule is kept honest by
## the records-room fixture, where the fire is walked round all four walls.
func _check_bookcase_heat(plan: HousePlan) -> void:
	var room: int = plan.hearth_room()
	if room < 0 or plan.hearth_wall() < 0:
		return
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) != "bookcase":
			continue
		if p.get("mounted", false) or int(p["host"]) >= 0:
			continue
		if _fs_back_wall(plan, room, p["rect"], p) != plan.hearth_wall():
			continue
		_fs_report(plan, p, "bookcase",
			"bookcase_heat: %s stands against wall %d, which is the chimney wall"
			% [_who(plan, f), plan.hearth_wall()])


## You do not sleep with the draught and the daylight at your head. A bed takes
## any wall in the room except the one the window is in.
## Generated houses hold this in 100% of cases, so it fails outright.
func _check_bed_window(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) != "bed":
			continue
		if p.get("mounted", false) or int(p["host"]) >= 0:
			continue
		var room: int = int(p["room"])
		if plan.windows_of(room).is_empty():
			continue
		# Measure the headboard plane; the bed's SIDE may also touch a
		# window wall in a corner without putting glazing behind its head.
		var yaw: float = float(p.yaw)
		var back := Vector2(sin(yaw), cos(yaw))
		var depth: float = PropCatalog.footprint(p.key).y * float(p.get("scale", 1.0))
		var head: Vector2 = Rect2(p.rect).get_center() + back * depth * 0.5
		var wi := -1
		var best := HouseGeometry.BED_HEAD_TOL
		var walls := HouseGeometry.room_walls(plan, room)
		for wall_index in range(walls.size()):
			var wall: Dictionary = walls[wall_index]
			if Vector2(wall.normal).dot(back) > -0.999:
				continue
			var gap := head.distance_to(Geometry2D.get_closest_point_to_segment(head, wall.from, wall.to))
			if gap < best:
				best = gap
				wi = wall_index
		if wi < 0 or not _fs_wall_lit(plan, room, wi):
			continue
		var msg := "bed_window: the head of %s is under the window in wall %d" % [_who(plan, f), wi]
		# a room whose every other wall is glazed or carries the chimney has
		# no dark wall to offer the bed: that is the room, not the placer
		var dark := false
		var span: float = maxf(Rect2(p["rect"]).size.x, Rect2(p["rect"]).size.y)
		for other in range(walls.size()):
			if other == wi or _fs_wall_lit(plan, room, other):
				continue
			if plan.hearth_room() == room and plan.hearth_wall() == other:
				continue
			# and long enough, clear of its doors, to take the bed
			if _fs_clear_wall_run(plan, room, other) < span + 0.1:
				continue
			dark = true
		if dark:
			_fs_report(plan, p, "bed", msg)
		else:
			warnings.append(msg)


## Length of real masonry available on an edge. The rectangular planner's
## axis-coordinate span is intentionally retained for rectangular rooms.
static func _fs_clear_wall_run(plan: HousePlan, room: int, wi: int) -> float:
	if not plan.is_polygonal(room):
		var span := HousePlanner.clear_wall_span(plan, room, wi)
		return span.y - span.x
	var wall: Dictionary = HouseGeometry.room_walls(plan, room)[wi]
	var a: Vector2 = wall.from
	var b: Vector2 = wall.to
	var normal: Vector2 = wall.normal
	var along := (b - a).normalized()
	var length := a.distance_to(b)
	var cuts: Array[Vector2] = []
	for door_index in plan.doors_of(room):
		var door: Dictionary = plan.doors[door_index]
		var position: Vector2 = door.pos
		if absf((position - a).dot(normal)) > HouseGeometry.DOOR_CLEAR:
			continue
		var station := (position - a).dot(along)
		var half := float(door.width) * 0.5 + HouseGeometry.DOOR_CLEAR
		cuts.append(Vector2(station - half, station + half))
	cuts.sort_custom(func(x: Vector2, y: Vector2): return x.x < y.x)
	var cursor := 0.0
	var longest := 0.0
	for cut in cuts:
		longest = maxf(longest, clampf(cut.x, 0, length) - cursor)
		cursor = maxf(cursor, clampf(cut.y, 0, length))
	return maxf(longest, length - cursor)


## The table in the room with the fire in it is drawn up toward the fire, not
## pushed away from it: its centre sits off the middle of the room, along the
## line to the hearth.
##
## Tolerance. LAY-002's placer achieves the full offset (0.30 of the room's
## half-depth, the figure `_affinity_sweep` measures) in 89.5% of cases. The
## rest are halls where the fire side of the room is already taken -- by the
## seats drawn round it, by the dresser, by the stair -- and the table is where
## the floor was. Measured on the offset alone those are indistinguishable from
## a table that simply ignored the fire, so the offset decides the warning and
## the FLOOR decides the defect: a table on the far side of the room whose
## mirror image on the fire side is empty floor could have stood by the fire
## and did not.
const FS_FOCUS_WANT := 0.30
const FS_FOCUS_FAIL := -0.15

func _check_table_focus(plan: HousePlan) -> void:
	var room: int = plan.hearth_room()
	if room < 0 or plan.hearth_wall() < 0:
		return
	var f_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var focus := Vector2(INF, INF)
	for i in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[i]["key"]) == "hearth":
			focus = Rect2(plan.furniture[i]["rect"]).get_center()
	if not focus.is_finite():
		var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
		focus = (Vector2(walls[plan.hearth_wall()]["from"])
			+ Vector2(walls[plan.hearth_wall()]["to"])) / 2.0
	var mid: Vector2 = f_rect.get_center()
	var dir: Vector2 = focus - mid
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var half: float = absf(dir.x) * f_rect.size.x / 2.0 + absf(dir.y) * f_rect.size.y / 2.0
	for i2 in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[i2]
		if PropCatalog.category(p["key"]) != "table" or p.get("mounted", false):
			continue
		if int(p["host"]) >= 0 or String(p.get("row", "")) != "":
			continue
		# A table the PLAN pinned is where the plan put it. A great hall high
		# table stands on the dais at the upper end and the fire is on a side
		# wall behind the trestles: measuring that table against the fire is
		# measuring the plan against a rule the plan already answered (INT-002).
		if plan.focus_cat() == "table" and plan.focus_room() == room \
				and Rect2(p["rect"]).get_center().distance_to(plan.focus_pos()) \
					< FOCUS_TOL:
			continue
		var off: float = (Rect2(p["rect"]).get_center() - mid).dot(dir)
		if off >= FS_FOCUS_WANT * half:
			continue
		if off >= FS_FOCUS_FAIL * half:
			warnings.append("table_focus: %s stands %.2fm toward the fire, short of the %.2fm the room allows"
				% [_who(plan, i2), off, FS_FOCUS_WANT * half])
		elif _fs_mirror_free(plan, room, i2, dir, -off):
			_fs_report(plan, p, "table",
				"table_focus: %s stands %.2fm on the far side of the room from the fire"
				% [_who(plan, i2), -off])
		else:
			warnings.append("table_focus: %s stands %.2fm on the far side of the room from the fire, and the fire side of it is full"
				% [_who(plan, i2), -off])


## Could this piece have stood the same distance the OTHER side of the middle
## of the room, toward the fire? Its own seats move with it, so they do not
## count as being in its way.
static func _fs_mirror_free(plan: HousePlan, room: int, me: int, dir: Vector2,
		back: float) -> bool:
	var rect: Rect2 = plan.furniture[me]["rect"]
	var moved: Rect2 = Rect2(rect.position + dir * (2.0 * back), rect.size)
	if not HouseGeometry.room_floor_rect(plan, room).grow(0.05).encloses(moved):
		return false
	for f in plan.furniture_of(room):
		if f == me:
			continue
		var q: Dictionary = plan.furniture[f]
		if q.get("mounted", false) or int(q["host"]) >= 0:
			continue
		var cat: String = PropCatalog.category(q["key"])
		if cat == "seat" or cat == "bench":
			continue
		var over: Rect2 = Rect2(q["rect"]).intersection(moved)
		if over.size.x > TOL and over.size.y > TOL:
			return false
		var zone: Rect2 = q["zone"]
		if zone.size.x > 0.0:
			var zover: Rect2 = zone.intersection(moved)
			if zover.size.x > TOL and zover.size.y > TOL:
				return false
	# and it would have to be out of the way of every door, which is the other
	# reason the placer leaves the middle of a hall alone
	for d in plan.doors_of(room):
		for side in [-1.0, 1.0]:
			var clear: Rect2 = HouseGeometry.door_clear_rect(plan.doors[d], side)
			var dover: Rect2 = clear.intersection(moved)
			if dover.size.x > TOL and dover.size.y > TOL:
				return false
	return true


## Two lamps in a room are a pair: one wall, and the same distance either side
## of something -- the door, the fire, or the middle of the wall they share.
## One lamp is a lamp and three are a scatter; only a pair can be lopsided.
##
## Tolerance. LAY-002 measures the strict form -- same wall AND mirrored -- at
## 96%; the shortfall is rooms with no wall long enough to hang a pair on,
## where the furnisher has no station to mirror about and puts the two lamps
## wherever there is masonry. So a pair that is half right (same wall, or
## mirrored across two of them) warns, and a pair that is neither is a defect
## only when some wall of the room could actually have carried the two of them
## either side of its door, its fire or its own middle.
const FS_MIRROR_TOL := 0.15
## The station a pair hangs at, matching the furnisher's own FLANK_IDEAL and
## FLANK_REACH: it settles on one station for the whole room before it hangs
## either lamp, so a room where only some far wider or narrower spacing would
## have fitted is a room where it had no pair to hang.
const FS_PAIR_MIN := 0.9
const FS_PAIR_MAX := 2.1

func _check_sconce_pair(plan: HousePlan) -> void:
	for room in range(plan.room_count()):
		var sc: Array[int] = []
		for i in plan.furniture_of(room):
			if PropCatalog.category(plan.furniture[i]["key"]) == "sconce":
				sc.append(i)
		if sc.size() != 2:
			continue
		var w1: int = _fs_pair_wall(plan, room, plan.furniture[sc[0]]["rect"])
		var w2: int = _fs_pair_wall(plan, room, plan.furniture[sc[1]]["rect"])
		var same: bool = w1 >= 0 and w1 == w2
		var f_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
		var n := Vector2.UP
		if plan.is_polygonal(room) and w1 >= 0:
			n = HouseGeometry.room_walls(plan, room)[w1].normal
		elif not plan.is_polygonal(room):
			n = _fs_wall_normal(plan, room, w1 if w1 >= 0 else 0)
		var along := Vector2(n.y, -n.x)
		var anchors: Array[Vector2] = [(f_rect.position + f_rect.end) / 2.0]
		if plan.is_polygonal(room) and w1 >= 0:
			var wall: Dictionary = HouseGeometry.room_walls(plan, room)[w1]
			anchors.append((Vector2(wall.from) + Vector2(wall.to)) / 2.0)
		for i2 in plan.furniture_of(room):
			if PropCatalog.category(plan.furniture[i2]["key"]) == "hearth":
				anchors.append(Rect2(plan.furniture[i2]["rect"]).get_center())
		for d in plan.doors_of(room):
			anchors.append(plan.doors[d]["pos"])
		var t1: float = Rect2(plan.furniture[sc[0]]["rect"]).get_center().dot(along)
		var t2: float = Rect2(plan.furniture[sc[1]]["rect"]).get_center().dot(along)
		var mirrored := false
		for a in anchors:
			if absf(t1 + t2 - 2.0 * a.dot(along)) <= FS_MIRROR_TOL:
				mirrored = true
		if same and mirrored:
			continue
		var where := "lopsided on wall %d" % w1 if same else "on walls %d and %d" % [w1, w2]
		var msg := "sconce_pair: the two lamps in room %d (%s) are %s" \
			% [room, String(plan.kind_of(room)), where]
		if same or mirrored or not _fs_pair_fits(plan, room):
			warnings.append(msg)
		else:
			failures.append(msg)


static func _fs_pair_wall(plan: HousePlan, room: int, rect: Rect2) -> int:
	if plan.is_polygonal(room):
		return HouseGeometry.backing_wall(plan, room, rect, FS_BACK_TOL)
	return _fs_back_wall(plan, room, rect)


## Could a pair have hung on one wall at all? The same question again, asked
## of two lamps at once: a wall, a station on it -- its door, its fire or its
## own middle -- and two spots the same distance either side of that station,
## both far enough from the lamp's own width, both clear of the openings and of
## what is already on the wall. A room with no such wall has no pair to be had,
## and the two lamps it was given hang wherever there was masonry.
static func _fs_pair_fits(plan: HousePlan, room: int) -> bool:
	# the WIDEST lamp in the catalogue, not the one that was hung: the
	# furnisher works its station out from that (_widest_of), because the two
	# halves of a pair need not be the same prop, so a station this room could
	# not have offered the widest is a station it never had
	var width := 0.05
	for key in PropCatalog.of_category("sconce"):
		width = maxf(width, PropCatalog.size(key).x)
	var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
	for wi in range(walls.size()):
		var a: Vector2 = walls[wi]["from"]
		var b: Vector2 = walls[wi]["to"]
		var run: float = (b - a).length()
		if run < width + 0.4:
			continue
		var along: Vector2 = (b - a) / run
		var lo: float = width / 2.0 + 0.2
		var hi: float = run - width / 2.0 - 0.2
		var anchors: Array[float] = [run / 2.0]
		for d in plan.doors_of(room):
			var dp: Vector2 = plan.doors[d]["pos"]
			if absf((dp - a).cross(along)) < 0.2:
				anchors.append((dp - a).dot(along))
		for f2 in plan.furniture_of(room):
			if PropCatalog.category(plan.furniture[f2]["key"]) != "hearth":
				continue
			if _fs_pair_wall(plan, room, plan.furniture[f2]["rect"]) != wi:
				continue
			anchors.append((Rect2(plan.furniture[f2]["rect"]).get_center() - a).dot(along))
		for anchor in anchors:
			var gap: float = maxf(width + 0.1, FS_PAIR_MIN)
			while gap <= minf(run / 2.0, FS_PAIR_MAX):
				var t1: float = anchor - gap
				var t2: float = anchor + gap
				if t1 >= lo and t2 <= hi:
					var p1: Vector2 = a + along * t1
					var p2: Vector2 = a + along * t2
					var ok1: bool = not _fs_on_opening(plan, room, p1, width) and not _fs_crowded(plan, room, p1, width, "sconce")
					var ok2: bool = not _fs_on_opening(plan, room, p2, width) and not _fs_crowded(plan, room, p2, width, "sconce")
					if ok1 and ok2:
						return true
				gap += 0.06
	return false


## A shelf serves the bench or counter under it: it hangs on the same wall,
## over the piece it belongs to.
##
## Tolerance. The strict form -- half the shelf's width over the host's span,
## which is what `_affinity_sweep` counts -- holds in 85.5% of generated rooms.
## The rest are benches with nothing hangable over them: the window the bench
## was put under (workbench_daylight, above, asks for exactly that wall), or
## the rack, banner or lamp that took the stretch first. So a shelf that missed
## its bench is a defect only when the wall over that bench was empty and
## waiting, and a warning when something else already had it.
const FS_SHELF_COVER := 0.5
## Masonry a shelf needs either side of an opening before it counts as free.
const FS_SHELF_CLEAR := 0.3

func _check_shelf_over(plan: HousePlan) -> void:
	for room in range(plan.room_count()):
		var hosts: Array[int] = []
		var shelves: Array[int] = []
		for i in plan.furniture_of(room):
			var cat: String = PropCatalog.category(plan.furniture[i]["key"])
			if cat == "workbench" or cat == "counter":
				hosts.append(i)
			elif cat == "shelf":
				shelves.append(i)
		if hosts.is_empty() or shelves.is_empty():
			continue
		var best_cover := 0.0
		var best_dist := INF
		for s in shelves:
			var p: Dictionary = plan.furniture[s]
			var sc: Vector2 = Rect2(p["rect"]).get_center()
			var wi: int = _fs_back_wall(plan, room, p["rect"], p)
			for h in hosts:
				var host: Rect2 = plan.furniture[h]["rect"]
				var near := Vector2(clampf(sc.x, host.position.x, host.end.x),
					clampf(sc.y, host.position.y, host.end.y))
				best_dist = minf(best_dist, sc.distance_to(near))
				var hw: int = _fs_back_wall(plan, room, host, plan.furniture[h])
				if hw < 0 or hw != wi:
					continue
				var normal := _fs_wall_normal(plan, room, hw)
				var axis := Vector2(normal.y, -normal.x)
				var width: float = maxf(PropCatalog.size(p["key"]).x, 0.05)
				var interval := _fs_projection(host, axis, plan.furniture[h])
				var span: float = maxf(interval.y - interval.x, 0.05)
				var c: float = sc.dot(axis)
				var over: float = minf(c + width / 2.0, interval.y) \
					- maxf(c - width / 2.0, interval.x)
				best_cover = maxf(best_cover, over / minf(width, span))
		if best_cover >= FS_SHELF_COVER:
			continue
		var widest := 0.05
		for s2 in shelves:
			widest = maxf(widest, PropCatalog.size(plan.furniture[s2]["key"]).x)
		var free := false
		for h2 in hosts:
			if _fs_could_hang_over(plan, room, plan.furniture[h2], widest):
				free = true
		var msg := "shelf_over: no shelf in room %d (%s) hangs over the bench it serves (%.0f%% cover, %.2fm away)" \
			% [room, String(plan.kind_of(room)), best_cover * 100.0, best_dist]
		if free:
			failures.append(msg)
		else:
			warnings.append(msg)


## Could a shelf have hung over this bench at all? Not "is the wall bare" but
## the question the placer itself asks: is there a station on the bench's wall,
## clear of the doors and windows by the margin `_on_opening()` keeps and clear
## of whatever else is already screwed up there, from which the shelf would
## cover the bench. A bench under the window it was put beside, or a wall run
## shorter than the shelf, has no such station -- and a check that called that
## a defect would be reporting the size of the room again.
static func _fs_could_hang_over(plan: HousePlan, room: int, piece: Dictionary,
		width: float) -> bool:
	var host: Rect2 = piece.rect
	var wi: int = _fs_back_wall(plan, room, host, piece)
	if wi < 0:
		return false
	var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
	var a: Vector2 = walls[wi]["from"]
	var b: Vector2 = walls[wi]["to"]
	var run: float = (b - a).length()
	if run < width + 0.4:
		return false
	var along: Vector2 = (b - a) / run
	var axis: Vector2 = along
	var interval := _fs_projection(host, axis, piece)
	var span: float = maxf(interval.y - interval.x, 0.05)
	var lo: float = width / 2.0 + 0.2
	var hi: float = run - width / 2.0 - 0.2
	var t: float = lo
	while t <= hi + 0.001:
		var pos: Vector2 = a + along * t
		var clear_here: bool = not _fs_on_opening(plan, room, pos, width)
		if clear_here and not _fs_crowded(plan, room, pos, width, "shelf"):
			var c: float = pos.dot(axis)
			var hi_edge: float = minf(c + width / 2.0, interval.y)
			var lo_edge: float = maxf(c - width / 2.0, interval.x)
			var over: float = hi_edge - lo_edge
			if over / minf(width, span) >= FS_SHELF_COVER:
				return true
		t += 0.06
	return false


## The two clearances `HouseFurnishPlacement._place_mounted` keeps, measured the same
## way: nothing may hang across an opening, and nothing may hang into what is
## already on the wall.
static func _fs_on_opening(plan: HousePlan, room: int, pos: Vector2,
		width: float) -> bool:
	for d in plan.doors_of(room):
		var door: Dictionary = plan.doors[d]
		if Vector2(door["pos"]).distance_to(pos) < (float(door["width"]) + width) / 2.0 + 0.15:
			return true
	for w in plan.windows_of(room):
		var win: Dictionary = plan.windows[w]
		if Vector2(win["pos"]).distance_to(pos) < (float(win["width"]) + width) / 2.0 + 0.15:
			return true
	return false


static func _fs_crowded(plan: HousePlan, room: int, pos: Vector2, width: float,
		ignore_cat: String) -> bool:
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if not p.get("mounted", false):
			continue
		if PropCatalog.category(p["key"]) == ignore_cat:
			continue
		var other: float = maxf(PropCatalog.size(p["key"]).x, 0.05)
		var c := Vector2(p["pos"].x, p["pos"].z)
		if c.distance_to(pos) < (width + other) / 2.0 + 0.1:
			return true
	return false


## A chandelier hangs over the table, not over the middle of a room whose table
## stands somewhere else. Generated houses hold this in 100% of cases, so
## anything outside the tolerance is a defect.
const FS_CHANDELIER_TOL := 0.35

func _check_chandelier_over(plan: HousePlan) -> void:
	for room in range(plan.room_count()):
		var tables: Array[int] = []
		for i in plan.furniture_of(room):
			var p: Dictionary = plan.furniture[i]
			if PropCatalog.category(p["key"]) == "table" and not p.get("mounted", false):
				tables.append(i)
		if tables.is_empty():
			continue
		for i2 in plan.furniture_of(room):
			var q: Dictionary = plan.furniture[i2]
			if PropCatalog.category(q["key"]) != "chandelier":
				continue
			var c := Vector2(q["pos"].x, q["pos"].z)
			var near := INF
			for t in tables:
				near = minf(near, c.distance_to(Rect2(plan.furniture[t]["rect"]).get_center()))
			if near <= FS_CHANDELIER_TOL:
				continue
			_fs_report(plan, q, "chandelier",
				"chandelier_over: %s hangs %.2fm from the nearest table"
				% [_who(plan, i2), near])


## Barrels, crates and sacks belong out of the traffic: a corner piece stands
## no nearer than a metre to a door.
##
## Tolerance. In the traffic means in the LINE of the door as well as near it:
## a crate half a metre in front of a doorway is what the rule is about, and a
## crate the same distance away but tucked against the jamb, beside the opening
## rather than across it, is a warning. (The doorway rule already guarantees
## neither of them stands in the swing.) A room whose every corner is inside
## the metre is a room too small to obey the rule at all, and warns too.
const FS_CLUTTER_CLEAR := 1.0

func _check_corner_clutter(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		if not PropCatalog.has_tag(p["key"], PropCatalog.CORNER):
			continue
		if p.get("mounted", false) or int(p["host"]) >= 0:
			continue
		var room: int = int(p["room"])
		var doors: Array[int] = plan.doors_of(room)
		if doors.is_empty():
			continue
		var c: Vector2 = Rect2(p["rect"]).get_center()
		var d := INF
		for di in doors:
			d = minf(d, c.distance_to(Vector2(plan.doors[di]["pos"])))
		if d >= FS_CLUTTER_CLEAR:
			continue
		var f_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
		var roomy := false
		for corner in [f_rect.position, Vector2(f_rect.end.x, f_rect.position.y),
				Vector2(f_rect.position.x, f_rect.end.y), f_rect.end]:
			var cd := INF
			for di2 in doors:
				cd = minf(cd, Vector2(corner).distance_to(Vector2(plan.doors[di2]["pos"])))
			if cd >= FS_CLUTTER_CLEAR:
				roomy = true
		var across := false
		for di3 in doors:
			var door: Dictionary = plan.doors[di3]
			var dn: Vector2 = door["normal"]
			var side: float = absf((c - Vector2(door["pos"])).dot(Vector2(dn.y, -dn.x)))
			var half_r: float = (absf(dn.y) * Rect2(p["rect"]).size.x
				+ absf(dn.x) * Rect2(p["rect"]).size.y) / 2.0
			if c.distance_to(Vector2(door["pos"])) < FS_CLUTTER_CLEAR 					and side < float(door["width"]) / 2.0 + half_r:
				across = true
		var msg := "corner_clutter: %s stands %.2fm from a door, in the traffic" \
			% [_who(plan, f), d]
		if roomy and across:
			_fs_report(plan, p, PropCatalog.category(p["key"]), msg)
		else:
			warnings.append(msg)


## The plan names one piece the room is arranged around -- the fire in a hall,
## the counter in a shop, the anvil in a smithy -- and where it stands. This
## is the temple's axis rule brought indoors: the focus exists, it is where
## the plan says (the furnisher writes back where it put it, so this is the
## plan against the furniture, not the plan against itself), and when the
## family says it must -- a counter, a bar -- it looks at the way in.
const FOCUS_TOL := 0.3
const FOCUS_FACE_DEG := 45.0

func _check_focus(plan: HousePlan) -> void:
	var room: int = plan.focus_room()
	if room < 0 or room >= plan.room_count():
		return
	var cat: String = plan.focus_cat()
	if cat == "":
		return
	var pieces: Array[int] = []
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) != cat:
			continue
		if p.get("mounted", false) or int(p["host"]) >= 0:
			continue
		pieces.append(f)
	if pieces.is_empty():
		if plan.was_dropped(room, cat) or not _could_hold(plan, room, cat):
			warnings.append("focus: room %d (%s) gave up the %s it was arranged around"
				% [room, String(plan.kind_of(room)), cat])
		else:
			failures.append("focus: room %d (%s) has no %s to be arranged around"
				% [room, String(plan.kind_of(room)), cat])
		return
	var pos: Vector2 = plan.focus_pos()
	var best: int = pieces[0]
	var best_d := INF
	for f2 in pieces:
		var d: float = Rect2(plan.furniture[f2]["rect"]).get_center().distance_to(pos)
		if d < best_d:
			best_d = d
			best = f2
	# A room that gave up the piece it was arranged around wrote that down, and
	# what is left of the category is not that piece: a great hall whose high
	# table went so the hall could be walked still has its trestles, and
	# measuring one of THOSE against the dais is measuring the wrong table.
	var gave_up: bool = plan.was_dropped(room, cat)
	if pos.is_finite() and best_d > FOCUS_TOL:
		var said := "focus: %s stands %.2fm from the focus the plan recorded" \
			% [_who(plan, best), best_d]
		if gave_up:
			warnings.append(said + ", and the room gave up the one that stood there")
			return
		failures.append(said)
	if not plan.focus_faces_door():
		return
	var door: int = HouseFurnishScore.focus_door(plan, room)
	if door < 0:
		return
	var c: Vector2 = Rect2(plan.furniture[best]["rect"]).get_center()
	var to: Vector2 = Vector2(plan.doors[door]["pos"]) - c
	if to.length() < 0.01:
		return
	# Internal doors carry a partition-axis normal, which need not point out
	# of this room. Measure the room's wall before deciding whether a piece
	# faces the doorway squarely; the opposite direction is its back.
	var door_pos := Vector2(plan.doors[door]["pos"])
	var outward := Vector2(plan.doors[door]["normal"])
	var nearest := INF
	for wall in HouseGeometry.room_walls(plan, room):
		var point := Geometry2D.get_closest_point_to_segment(door_pos, wall.from, wall.to)
		var distance := door_pos.distance_to(point)
		if distance < nearest:
			nearest = distance
			outward = -Vector2(wall.normal)
	var yaw: float = float(plan.furniture[best]["yaw"])
	var facing := Vector2(-sin(yaw), -cos(yaw))
	var off: float = rad_to_deg(acos(clampf(facing.dot(to.normalized()), -1.0, 1.0)))
	# a counter set square to the door's wall a little way along it looks at
	# the doorway well enough: the customer walks in and sees its front
	var squarely: bool = facing.dot(outward) > 0.9
	if off > FOCUS_FACE_DEG and not squarely:
		var said2 := "focus: the %s in room %d faces away from the door" % [cat, room]
		if gave_up:
			warnings.append(said2 + ", and the room gave up the one that faced it")
		else:
			failures.append(said2)
	# and it can be SEEN from the door: the temple's sightline rule, cast from
	# a person's eye inside the doorway to the top of the piece, past every
	# other piece standing in the room (Sightline, INT-020)
	var d: Dictionary = plan.doors[door]
	var base: float = float(plan.storey_of_room(room)) * plan.spec.height
	var inside: Vector2 = Vector2(d["pos"]) - outward * 0.5
	var eye := Vector3(inside.x, base + 1.6, inside.y)
	var top: float = base + PropCatalog.height(plan.furniture[best]["key"]) \
		* float(plan.furniture[best].get("scale", 1.0)) * 0.9
	var aim := Vector3(c.x, top, c.y)
	var boxes: Array = []
	var names: Array[String] = []
	for f3 in plan.furniture_of(room):
		if f3 == best:
			continue
		var q: Dictionary = plan.furniture[f3]
		if q.get("mounted", false) or int(q["host"]) >= 0:
			continue
		var qr: Rect2 = q["rect"]
		var qh: float = PropCatalog.height(q["key"]) * float(q.get("scale", 1.0))
		boxes.append(AABB(Vector3(qr.position.x, base, qr.position.y),
			Vector3(qr.size.x, qh, qr.size.y)))
		names.append(String(q["key"]))
	var hit: Array[int] = Sightline.blockers(eye, aim, boxes)
	if not hit.is_empty():
		warnings.append("focus: the %s in room %d cannot be seen from the door past the %s"
			% [cat, room, names[hit[0]]])


## Floor the plan keeps clear stays clear.
##
## A screens passage is not furniture, and nothing about the pieces standing in
## a hall says where it was: only the plan does. So this is the one rule that
## reads a plan-level zone -- and it reads it against what was actually placed,
## which is the whole point. A passage the plan drew and the furnishing filled
## in is a passage that was never there.
func _check_clear(plan: HousePlan) -> void:
	for z in plan.zones:
		var rect: Rect2 = z["rect"]
		var why: String = String(z.get("why", "clear floor"))
		var room: int = int(z.get("room", -1))
		for f in range(plan.furniture.size()):
			var p: Dictionary = plan.furniture[f]
			if p.get("mounted", false) or int(p["host"]) >= 0:
				continue
			if int(p["room"]) != room:
				continue
			if not PropCatalog.blocks_floor(String(p["key"])):
				continue
			var r: Rect2 = p["rect"]
			if not r.intersects(rect):
				continue
			var over: Rect2 = r.intersection(rect)
			if over.size.x * over.size.y < TOL:
				continue
			failures.append("clear: %s stands in the %s" % [_who(plan, f), why])


## Does a ray from `from` along `dir`, no longer than `reach`, cross `rect`?
static func _ray_hits_rect(from: Vector2, dir: Vector2, rect: Rect2, reach: float) -> bool:
	var to: Vector2 = from + dir.normalized() * reach
	var t0 := 0.0
	var t1 := 1.0
	var d: Vector2 = to - from
	for axis in range(2):
		var lo: float = rect.position[axis]
		var hi: float = rect.end[axis]
		if absf(d[axis]) < 0.00001:
			if from[axis] < lo or from[axis] > hi:
				return false
			continue
		var ta: float = (lo - from[axis]) / d[axis]
		var tb: float = (hi - from[axis]) / d[axis]
		if ta > tb:
			var swap: float = ta
			ta = tb
			tb = swap
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return false
	return true
