class_name HouseFurnishPhysicalCheck
extends RefCounted
## Physical validity rules for furnished rooms.

const TOL := 0.03

var failures: Array = []
var warnings: Array = []


func _init(report: Dictionary = {}) -> void:
	failures = report.get("failures", [])
	warnings = report.get("warnings", [])


## Inside its room, and clear of everything else standing on the floor.
func check_placed(plan: HousePlan) -> void:
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
			failures.append("placed: %s is partly in the wall" % HouseFurnishCheck.who(plan, f))
		if plan.is_polygonal(int(p["room"])):
			for corner in Poly.from_rect(rect):
				if not Poly.contains_point(plan.outline_of(int(p["room"])), corner, TOL):
					failures.append("placed: %s crosses a shaped room wall" % HouseFurnishCheck.who(plan, f))
					break
		# the size it claims must be the size the asset actually is
		var want: Vector2 = PropCatalog.footprint_rotated(key, float(p["yaw"])) \
			* float(p.get("scale", 1.0))
		if absf(rect.size.x - want.x) > 0.05 or absf(rect.size.y - want.y) > 0.05:
			failures.append("placed: %s claims a %.2f x %.2fm footprint, the model is %.2f x %.2fm"
				% [HouseFurnishCheck.who(plan, f), rect.size.x, rect.size.y, want.x, want.y])

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
					% [HouseFurnishCheck.who(plan, a), HouseFurnishCheck.who(plan, b), over.size.x, over.size.y])


## Furniture is planned in X/Z rectangles, but its model must occupy the room's
## vertical band.  This catches an upper-storey placement left at Y=0 and a
## prop accidentally hanging through the ceiling.
func check_vertical(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		var room: int = int(p.get("room", -1))
		if room < 0 or room >= plan.room_count():
			failures.append("vertical: furniture %d references no room" % f)
			continue
		var level := HousePlan.record_storey(plan.rooms[room])
		if HousePlan.record_storey(p) != level:
			failures.append("vertical: %s is tagged for storey %d, room is on %d"
				% [HouseFurnishCheck.who(plan, f), HousePlan.record_storey(p), level])
		var base: float = float(level) * plan.spec.height
		var y: float = float(p["pos"].y)
		if y < base - TOL or y > base + plan.spec.height + TOL:
			failures.append("vertical: %s origin Y %.2f outside storey %d band %.2f..%.2f"
				% [HouseFurnishCheck.who(plan, f), y, level, base, base + plan.spec.height])


## A prop that must sit on a surface must actually be on one, at its height and
## within its top. This is the check that catches a candle floating where a
## table was moved from.
func check_supported(plan: HousePlan) -> void:
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		var key: String = p["key"]
		if not PropCatalog.has_tag(key, PropCatalog.ON_SURFACE):
			continue
		var host: int = p["host"]
		if host < 0:
			failures.append("supported: %s is on the floor, and belongs on a surface"
				% HouseFurnishCheck.who(plan, f))
			continue
		var host_key: String = plan.furniture[host]["key"]
		if not PropCatalog.has_tag(host_key, PropCatalog.SURFACE):
			failures.append("supported: %s is set on a %s, which has no top"
				% [HouseFurnishCheck.who(plan, f), host_key])
			continue
		if HousePlan.record_storey(plan.furniture[host]) != HousePlan.record_storey(p):
			failures.append("supported: %s is hosted by a different storey" % HouseFurnishCheck.who(plan, f))
		var host_placement: Dictionary = plan.furniture[host]
		var host_scale: float = PropCatalog.placement_height_scale(host_placement)
		var host_origin: Vector3 = PropCatalog.house_origin(host_placement)
		var top: float = host_origin.y \
			+ PropCatalog.floor_offset(host_key) * host_scale \
			+ PropCatalog.surface_height(host_key) * host_scale
		if absf(float(p["pos"].y) - top) > 0.02:
			failures.append("supported: %s floats %.2fm above the %s it sits on"
				% [HouseFurnishCheck.who(plan, f), float(p["pos"].y) - top, host_key])
		if not Rect2(plan.furniture[host]["rect"]).grow(0.02).encloses(p["rect"]):
			failures.append("supported: %s hangs over the edge of the %s"
				% [HouseFurnishCheck.who(plan, f), host_key])


## Nothing may stand where a door needs to swing, on either side of it.
func check_doorways(plan: HousePlan) -> void:
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
						% [HouseFurnishCheck.who(plan, f), d])
			# The swing is not the whole of a way in. A free-standing table a
			# hand's breadth past the swing is the first thing you walk into:
			# the swing rule let two of those through (walk QA, 6 Oct). A row
			# is placed and judged as a row, and the piece the plan is arranged
			# around may face the door on purpose; a table the furnisher had to
			# set there for want of anywhere else says so and is a warning.
			if not _approach_applies(plan, p) or not int(p["room"]) in [int(door.get("a", -1)), int(door.get("b", -1))]:
				continue
			for a in HouseFurnishPlacement.door_approach_rects(door):
				var over2: Rect2 = a.intersection(rect)
				if over2.size.x > TOL and over2.size.y > TOL:
					var msg := "doorway: %s stands in the approach to door %d" \
						% [HouseFurnishCheck.who(plan, f), d]
					if bool(p.get("door_approach", false)):
						warnings.append(msg + " -- the room had nowhere else for it")
					else:
						failures.append(msg)
					break


static func _approach_applies(plan: HousePlan, p: Dictionary) -> bool:
	if PropCatalog.category(String(p["key"])) != "table":
		return false
	if String(p.get("row", "")) != "":
		return false
	return not (plan.focus_room() == int(p["room"]) and plan.focus_cat() == "table")


## And nothing tall may stand across a window.
func check_windows(plan: HousePlan) -> void:
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
					% [HouseFurnishCheck.who(plan, f), PropCatalog.height(p["key"]), w])
