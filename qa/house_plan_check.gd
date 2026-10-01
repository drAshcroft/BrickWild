class_name HousePlanCheck
extends RefCounted
## Is this a plan of a house, or just a box with lines in it?
##
## Everything here is measured off the plan the builder actually built from.
## The rules are the ones a person would notice being broken:
##
##   TILING     the rooms fill the interior exactly -- no overlaps, no leftover
##              slivers of floor that belong to nobody
##   SHAPE      no room is smaller or thinner than the thing it claims to be
##   WAY IN     exactly one front door, on an exterior wall
##   CONNECTED  every room is reachable from the front door through doors
##   PRIVACY    no room is reachable ONLY by walking through a bedroom
##   OPENINGS   doors and windows fit the wall they are cut into, clear of the
##              corners and of each other
##   DAYLIGHT   every room people live in has a window, and enough glass in it
##   OUTSIDE    windows are on exterior walls; you cannot look from the kitchen
##              into the bedroom through a pane of glass
##   UPSTAIRS   a dwelling's service and public rooms are on the ground floor:
##              no kitchen, hall or workshop up a stair, and one hearth, down
##              here, where the chimney is
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

const TOL := 0.02

## Every rule, in the order it runs, by the name its messages carry. A family
## may replace one through `check(plan, overrides)` (RuleSet, INT-020).
const RULES: Array[StringName] = [&"tiling", &"storeys", &"shape", &"way_in",
	&"connected", &"privacy", &"opening", &"window", &"stairs", &"stair_line",
	&"doors_in_line", &"upstairs_programme", &"colonnade"]
const METHODS := {&"shape": "_check_shapes", &"way_in": "_check_entrance",
	&"connected": "_check_connectivity", &"opening": "_check_door_openings",
	&"window": "_check_windows"}

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
var replaced: Dictionary = {}


func check(plan: HousePlan, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	stats["rooms"] = plan.room_count()
	stats["doors"] = plan.doors.size()
	stats["windows"] = plan.windows.size()
	replaced = RuleSet.run(self, RULES, METHODS, overrides, [plan], [plan],
		failures, warnings)
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "replaced": replaced}


## Rooms that belong on the ground floor of a dwelling and nowhere else. The
## kitchen and the workshop are where the fire is, and there is one chimney per
## house; the hall is the room the front door opens into, and the front door is
## at ground level.
const GROUND_FLOOR_ONLY: Array[StringName] = [&"kitchen", &"hall", &"workshop"]


# ------------------------------------------------------------------ tiling

## The rooms must partition the interior: no overlap, and nothing left over.
func _check_tiling(plan: HousePlan) -> void:
	var n: int = plan.room_count()
	if n == 0:
		failures.append("tiling: the house has no rooms")
		return
	var inner: Rect2 = HouseGeometry.interior_rect(plan.spec)
	var sums := {}
	var shaped := {}
	for i in range(n):
		var a: Rect2 = plan.rooms[i]["rect"]
		var level := HousePlan.record_storey(plan.rooms[i])
		inner = HouseGeometry.storey_rect(plan, level).grow(-HouseGeometry.wall_thickness(plan.spec))
		# The ROOM rectangle, partitions included: this sum is what says the
		# rooms partition the interior with nothing left over, and the clear
		# floor inside each room does not add up to that by design.
		sums[level] = float(sums.get(level, 0.0)) + a.size.x * a.size.y
		if plan.is_polygonal(i):
			shaped[level] = true
		if not inner.grow(TOL).encloses(a):
			failures.append("tiling: room %d (%s) sticks out of the interior"
				% [i, String(plan.kind_of(i))])
		for j in range(i + 1, n):
			if HousePlan.record_storey(plan.rooms[i]) != HousePlan.record_storey(plan.rooms[j]):
				continue
			# Rectangles are compared as rectangles, so a house reads exactly
			# as it always did; a room that carries an outline is compared as
			# the shape it actually is (GEO-001, GEO-002).
			if plan.is_polygonal(i) or plan.is_polygonal(j):
				var lap: float = Poly.intersection_area(plan.outline_of(i),
					plan.outline_of(j))
				if lap > TOL:
					failures.append("tiling: rooms %d (%s) and %d (%s) overlap by %.2f m2"
						% [i, String(plan.kind_of(i)), j, String(plan.kind_of(j)), lap])
				continue
			var b: Rect2 = plan.rooms[j]["rect"]
			var over: Rect2 = a.intersection(b)
			if over.size.x > TOL and over.size.y > TOL:
				failures.append("tiling: rooms %d (%s) and %d (%s) overlap by %.2f x %.2fm"
					% [i, String(plan.kind_of(i)), j, String(plan.kind_of(j)),
						over.size.x, over.size.y])
	# A court is a hole in the plan, and the hole is part of the tiling: the
	# rooms and the courts together fill the interior, and nothing may be built
	# in a court (GEO-003).
	for ci in range(plan.courts.size()):
		var court: Rect2 = plan.courts[ci]["rect"]
		if not inner.grow(TOL).encloses(court):
			failures.append("tiling: court %d sticks out of the interior" % ci)
		var clevel: int = HousePlan.record_storey(plan.courts[ci])
		for i2 in range(n):
			if HousePlan.record_storey(plan.rooms[i2]) < clevel:
				continue
			var lap: float = Poly.intersection_area(plan.outline_of(i2),
				plan.court_outline(ci))
			if lap > TOL:
				failures.append("tiling: room %d (%s) is built in court %d, by %.2f m2"
					% [i2, String(plan.kind_of(i2)), ci, lap])
	var courts_by_level := {}
	for ci2 in range(plan.courts.size()):
		var lv: int = HousePlan.record_storey(plan.courts[ci2])
		var a2: Rect2 = plan.courts[ci2]["rect"]
		courts_by_level[lv] = float(courts_by_level.get(lv, 0.0)) \
			+ a2.size.x * a2.size.y

	var want: float = inner.size.x * inner.size.y
	stats["interior_area"] = snappedf(want, 0.01)
	stats["courts"] = plan.courts.size()
	for level in sums:
		var level_inner := HouseGeometry.storey_rect(plan, int(level)).grow(-HouseGeometry.wall_thickness(plan.spec))
		want = level_inner.get_area()
		# A storey of rectangles PARTITIONS the interior: every square metre
		# belongs to some room, and floor nobody owns is a planner bug. A
		# storey with a shaped room does not and should not -- the corners an
		# octagon cuts off are masonry, and that is what makes it a tower --
		# so the rule that stands there is "no room leaves the interior and no
		# two overlap", which has already been measured above.
		if shaped.has(level):
			continue
		var sum: float = float(sums[level]) + float(courts_by_level.get(level, 0.0))
		if absf(sum - want) > 0.05 * want:
			failures.append("tiling: storey %d rooms cover %.1f m2 of a %.1f m2 interior -- there is floor nobody owns"
				% [int(level), sum, want])


## Every requested storey has rooms, and no record may silently use a level
## outside the spec.  The `get` fallback keeps old hand-authored plans valid.
func _check_storeys(plan: HousePlan) -> void:
	var limit := plan.spec.max_storeys()
	var wanted: int = clampi(int(plan.spec.storeys), 1, limit)
	if plan.spec.storeys < 1 or plan.spec.storeys > limit:
		failures.append("storeys: declared %d exceeds this family's supported 1..%d" % [plan.spec.storeys, limit])
	var lowest: int = _lowest(plan)
	var seen := {}
	for room in plan.rooms:
		var level := HousePlan.record_storey(room)
		if level < lowest or level >= wanted:
			failures.append("storeys: room has invalid storey %d (wanted %d..%d)" % [level, lowest, wanted - 1])
		seen[level] = true
	for level in range(lowest, wanted):
		if not seen.has(level):
			failures.append("storeys: storey %d has no rooms" % level)
	stats["storeys"] = wanted
	stats["cellars"] = -lowest


## A wall kind that opens the arcade must have its actual posts in the plan.
## This validates the authored structure before either the mesh or the walk
## check consumes it.
func _check_colonnade(plan: HousePlan) -> void:
	var used := {}
	for ci in plan.columns.size():
		var column: Dictionary = plan.columns[ci]
		var room := int(column.get("room", -1))
		var wall_index := int(column.get("wall", -1))
		if room < 0 or room >= plan.room_count():
			failures.append("colonnade: column %d names missing room %d" % [ci, room])
			continue
		var walls := HouseGeometry.room_walls(plan, room)
		if wall_index < 0 or wall_index >= walls.size() \
				or walls[wall_index].get("kind", &"solid") != &"colonnade":
			failures.append("colonnade: column %d is not on an authored colonnade wall" % ci)
			continue
		if int(column.get("storey", plan.storey_of_room(room))) != plan.storey_of_room(room):
			failures.append("colonnade: column %d has the wrong storey" % ci)
		var pos: Vector2 = column.get("pos", Vector2(INF, INF))
		var size: Vector2 = column.get("size", Vector2.ZERO)
		var height := float(column.get("height", 0.0))
		var wall: Dictionary = walls[wall_index]
		var nearest := Geometry2D.get_closest_point_to_segment(pos, wall["from"], wall["to"])
		if pos.distance_to(nearest) > HouseGeometry.wall_thickness(plan.spec) * 0.5 + 0.1:
			failures.append("colonnade: column %d is off wall %d" % [ci, wall_index])
		if size.x <= 0.05 or size.y <= 0.05 or height <= 0.5 or height > plan.spec.height + TOL:
			failures.append("colonnade: column %d has invalid dimensions" % ci)
		var key := "%d|%d" % [room, wall_index]
		used[key] = int(used.get(key, 0)) + 1
	for room in range(plan.room_count()):
		for wi in HouseGeometry.room_walls(plan, room).size():
			var wall: Dictionary = HouseGeometry.room_walls(plan, room)[wi]
			if wall.get("kind", &"solid") != &"colonnade":
				continue
			var key := "%d|%d" % [room, wi]
			if int(used.get(key, 0)) < 2:
				failures.append("colonnade: room %d wall %d has fewer than two planned posts" % [room, wi])
			var portal: Dictionary = wall.get("portal", {})
			if portal.is_empty():
				var is_entrance_wall := false
				var entrance := plan.entrance()
				if plan.spec is ShopSpec and (plan.spec as ShopSpec).business == &"market_hall" \
						and entrance >= 0 and int(plan.doors[entrance].get("a", -1)) == room:
					var door_pos: Vector2 = plan.doors[entrance]["pos"]
					var nearest_to_door := Geometry2D.get_closest_point_to_segment(door_pos,
						wall["from"], wall["to"])
					is_entrance_wall = nearest_to_door.distance_to(door_pos) \
						<= HouseGeometry.wall_thickness(plan.spec) * 0.6
				if is_entrance_wall:
					failures.append("colonnade: market hall entrance wall has no solid portal")
				continue
			var start := float(portal.get("start", -1.0))
			var end := float(portal.get("end", -1.0))
			var length: float = Vector2(wall["from"]).distance_to(wall["to"])
			if start < 0.0 or end <= start or end > length:
				failures.append("colonnade: room %d wall %d has an invalid entrance portal" % [room, wi])
				continue
			var has_door := false
			for door in plan.doors:
				if int(door.get("a", -1)) != room or not bool(door.get("exterior", false)):
					continue
				var nearest := Geometry2D.get_closest_point_to_segment(Vector2(door["pos"]),
					wall["from"], wall["to"])
				var along := nearest.distance_to(Vector2(wall["from"]))
				if nearest.distance_to(Vector2(door["pos"])) <= HouseGeometry.wall_thickness(plan.spec) * 0.6 \
						and along - float(door["width"]) * 0.5 >= start - TOL \
						and along + float(door["width"]) * 0.5 <= end + TOL:
					has_door = true
			if not has_door:
				failures.append("colonnade: room %d wall %d portal does not contain its entrance" % [room, wi])


## The lowest storey a plan may have: 0, or -cellars for a spec that digs
## (INT-016). Old hand-authored specs have no cellars field.
static func _lowest(plan: HousePlan) -> int:
	if plan.spec.has_method("lowest_storey"):
		return int(plan.spec.lowest_storey())
	return 0


func _check_shapes(plan: HousePlan) -> void:
	for i in range(plan.room_count()):
		var kind: StringName = plan.kind_of(i)
		var f: Rect2 = HouseGeometry.room_floor_rect(plan, i)
		var who := "room %d (%s)" % [i, String(kind)]
		if not HouseGeometry.room_suits(plan, i, kind):
			failures.append("shape: %s is %.1f x %.1fm, too small to be a %s"
				% [who, f.size.x, f.size.y, String(kind)])
		if HouseGeometry.room_aspect(plan, i) > HouseGeometry.aspect_max(kind):
			warnings.append("shape: %s is %.1f x %.1fm -- that is a corridor, not a room"
				% [who, f.size.x, f.size.y])
		var has_vertical_access := false
		for stair in plan.stairs:
			if int(stair.get("a", -1)) == i or int(stair.get("b", -1)) == i:
				has_vertical_access = true
				break
		if plan.doors_of(i).is_empty() and not has_vertical_access and not plan.has_trapdoor_access(i):
			failures.append("shape: %s has no door at all" % who)


# ---------------------------------------------------------------- the way in

func _check_entrance(plan: HousePlan) -> void:
	var fronts := 0
	var exteriors := 0
	var inner: Rect2 = HouseGeometry.interior_rect(plan.spec)
	for d in plan.doors:
		if not d["exterior"]:
			continue
		var entry_level: int = plan.spec.entry_storey if plan.spec is KeepSpec else 0
		if HousePlan.record_storey(d) != entry_level:
			failures.append("way in: exterior door is on storey %d, expected entry storey %d" % [HousePlan.record_storey(d), entry_level])
		exteriors += 1
		if d.get("front", false):
			fronts += 1
		if d["b"] != -1:
			failures.append("way in: an exterior door claims to lead to room %d" % d["b"])
		# a door onto the yard is an exterior door standing well inside the
		# footprint, and it is not the street door
		var pos: Vector2 = d["pos"]
		var n: Vector2 = d["normal"]
		if _onto_court(plan, pos, n):
			if d.get("front", false):
				failures.append("way in: the front door opens onto a court, not the street")
			continue
		var room := int(d.get("a", -1))
		if room >= 0 and room < plan.room_count() and plan.is_polygonal(room):
			if not _on_outline(plan.outline_of(room), pos):
				failures.append("way in: exterior door at %v is not on an exterior wall" % pos)
			continue
		var on_wall: bool = (absf(n.x) > 0.5 and (absf(pos.x - inner.position.x) < TOL
				or absf(pos.x - inner.end.x) < TOL)) \
			or (absf(n.y) > 0.5 and (absf(pos.y - inner.position.y) < TOL
				or absf(pos.y - inner.end.y) < TOL))
		if not on_wall:
			failures.append("way in: exterior door at %v is not on an exterior wall" % pos)
	if fronts != 1:
		failures.append("way in: %d front doors -- a house has exactly one" % fronts)
	stats["exterior_doors"] = exteriors


func _check_connectivity(plan: HousePlan) -> void:
	var start: int = plan.entrance_room()
	if start < 0:
		failures.append("connected: no front door to start from")
		return
	var seen: Dictionary = plan.reachable_rooms(start)
	stats["rooms_reached"] = seen.size()
	var prison: bool = plan.spec is ShopSpec and plan.spec.business == &"prison"
	var without_keys: Dictionary = plan.reachable_rooms(start, &"", false) if prison else seen
	if prison:
		stats["rooms_reached_without_keys"] = without_keys.size()
		var cells := 0
		var locked_cells := 0
		var oubliettes := 0
		for i in range(plan.room_count()):
			if plan.storey_of_room(i) != 0 and plan.kind_of(i) != &"oubliette":
				continue
			match plan.kind_of(i):
				&"cell":
					cells += 1
					var exits := 0
					for d in plan.doors:
						if int(d.get("a", -1)) == i or int(d.get("b", -1)) == i:
							exits += 1
							if not bool(d.get("locked", false)):
								failures.append("connected: prison cell %d has an unlocked door" % i)
					if exits != 1:
						failures.append("connected: prison cell %d has %d doors, expected one" % [i, exits])
					if not seen.has(i) or without_keys.has(i):
						failures.append("connected: prison cell %d must be key-reachable and locked without keys" % i)
					locked_cells += 1
				&"oubliette":
					oubliettes += 1
					if not bool(plan.rooms[i].get("sealed", false)) or seen.has(i) or not plan.has_trapdoor_access(i):
						failures.append("connected: prison oubliette %d must be sealed and reachable only by its trapdoor" % i)
		if cells < 3 or locked_cells != cells:
			failures.append("connected: prison has %d cells; at least three locked cells are required" % cells)
		if oubliettes != 1:
			failures.append("connected: prison has %d oubliettes; exactly one is required" % oubliettes)
		if plan.trapdoors.size() != 1:
			failures.append("connected: prison has %d trapdoors; exactly one is required" % plan.trapdoors.size())
		for hatch in plan.trapdoors:
			var upper := int(hatch.get("upper_room", -1))
			var lower := int(hatch.get("lower_room", -1))
			var hatch_rect: Rect2 = hatch.get("rect", Rect2())
			if upper < 0 or lower < 0 or upper >= plan.room_count() or lower >= plan.room_count():
				failures.append("connected: prison trapdoor references a missing room")
				continue
			if plan.kind_of(lower) != &"oubliette" or not bool(hatch.get("sealed", false)) \
					or int(hatch.get("upper_storey", 0)) != plan.storey_of_room(upper) \
					or int(hatch.get("lower_storey", 0)) != plan.storey_of_room(lower) \
					or not HouseGeometry.room_floor_rect(plan, upper).encloses(hatch_rect):
				failures.append("connected: prison trapdoor is not a sealed hatch from its upper room to the oubliette")
		stats["locked_cells"] = locked_cells
		stats["sealed_oubliettes"] = oubliettes
	for i in range(plan.room_count()):
		if plan.world_family == &"courtyard_house" and _world_shop_has_street_opening(plan, i):
			continue
		if not seen.has(i) and not (prison and plan.kind_of(i) == &"oubliette"):
			failures.append("connected: room %d (%s) cannot be reached from the front door"
				% [i, String(plan.kind_of(i))])


static func _world_shop_has_street_opening(plan: HousePlan, room: int) -> bool:
	if room < 0 or room >= plan.rooms.size():
		return false
	if not String(plan.rooms[room].get("role", "")).begins_with("taberna"):
		return false
	for d in plan.doors:
		if int(d.get("a", -1)) == room and bool(d.get("exterior", false)) \
				and not bool(d.get("front", false)):
			return true
	return false


## Stairs are the only legal edge between levels.  Check both their metadata
## and coverage of every adjacent pair; door_graph() then checks reachability.
func _check_stairs(plan: HousePlan) -> void:
	var wanted: int = clampi(int(plan.spec.storeys), 1, plan.spec.max_storeys())
	var lowest: int = _lowest(plan)
	var interior: Rect2 = HouseGeometry.interior_rect(plan.spec)
	var pairs := {}
	for si in range(plan.stairs.size()):
		var stair: Dictionary = plan.stairs[si]
		var lo: int = int(stair.get("storey", 0))
		var hi: int = int(stair.get("to_storey", lo + 1))
		if hi != lo + 1 or lo < lowest or hi >= wanted:
			failures.append("stairs: stair %d does not join adjacent valid storeys (%d to %d)" % [si, lo, hi])
			continue
		var a: int = int(stair.get("a", -1))
		var b: int = int(stair.get("b", -1))
		if a < 0 or b < 0 or a >= plan.room_count() or b >= plan.room_count():
			failures.append("stairs: stair %d references an invalid room" % si)
			continue
		if HousePlan.record_storey(plan.rooms[a]) != lo or HousePlan.record_storey(plan.rooms[b]) != hi:
			failures.append("stairs: stair %d endpoints are not on storeys %d and %d" % [si, lo, hi])
		for key in ["rect", "lower_rect", "upper_rect"]:
			if not stair.has(key) or Rect2(stair[key]).size.x <= 0.0 or Rect2(stair[key]).size.y <= 0.0:
				failures.append("stairs: stair %d has no usable %s landing" % [si, key])
			elif not interior.grow(TOL).encloses(Rect2(stair[key])):
				failures.append("stairs: stair %d %s lies outside the interior" % [si, key])
			else:
				var rooms: Array = [a, b] if key == "rect" else [a if key == "lower_rect" else b]
				for room in rooms:
					for point in Poly.from_rect(Rect2(stair[key])):
						if not Poly.contains_point(HouseGeometry.room_floor_poly(plan, room), point, TOL):
							failures.append("stairs: stair %d %s lies outside room %d's floor" % [si, key, room])
							break
		if stair.has("lower_rect") and stair.has("upper_rect"):
			var lower: Rect2 = stair["lower_rect"]
			var upper: Rect2 = stair["upper_rect"]
			if not lower.position.is_equal_approx(upper.position) \
					or not lower.size.is_equal_approx(upper.size):
				failures.append("stairs: stair %d landings must share one vertical stairwell" % si)
		pairs[lo] = true
	for lo in range(lowest, wanted - 1):
		if not pairs.has(lo):
			failures.append("stairs: no transition from storey %d to %d" % [lo, lo + 1])
	stats["stairs"] = plan.stairs.size()


## You should not have to walk through somebody's bedroom -- or a guest room,
## or a suite -- to get anywhere. Reachability is recomputed refusing to pass
## THROUGH any sleeping room; anything that drops out is a room that has been
## put behind a bed.
func _check_privacy(plan: HousePlan) -> void:
	var start: int = plan.entrance_room()
	if start < 0:
		return
	var polite: Dictionary = plan.reachable_rooms(start, HouseGeometry.SLEEPING)
	for i in range(plan.room_count()):
		# A bedroom is the private endpoint a house's own occupant sleeps in --
		# its own reachability was never in scope (a house does not put one
		# bedroom's only door behind another). A hotel's other sleeping kinds
		# are not exempt: a guest_room or suite reachable only through a
		# DIFFERENT sleeping room is exactly the corridor-through-a-bedroom
		# problem this check exists to catch.
		if plan.kind_of(i) == &"bedroom":
			continue
		if plan.world_family == &"courtyard_house" and _world_shop_has_street_opening(plan, i):
			continue
		if plan.spec is ShopSpec and plan.spec.business == &"prison" \
				and plan.kind_of(i) == &"oubliette" and bool(plan.rooms[i].get("sealed", false)):
			continue
		if not polite.has(i):
			failures.append("privacy: the only way into room %d (%s) is through a %s"
				% [i, String(plan.kind_of(i)), _sleeping_room_on_path(plan, start, i)])


## Names the sleeping room a plain (unrestricted) shortest path from `start`
## to `dest` has to cross, for a readable failure message.
func _sleeping_room_on_path(plan: HousePlan, start: int, dest: int) -> String:
	var g: Dictionary = plan.door_graph()
	var parent := {start: -1}
	var stack: Array[int] = [start]
	while not stack.is_empty():
		var cur: int = stack.pop_back()
		if cur == dest:
			break
		for nb in g[cur]:
			if not parent.has(nb):
				parent[nb] = cur
				stack.append(nb)
	if not parent.has(dest):
		return "sleeping room"
	var node: int = parent[dest]
	while node != -1 and node != start:
		if plan.kind_of(node) in HouseGeometry.SLEEPING:
			return String(plan.kind_of(node))
		node = parent[node]
	return "sleeping room"


# --------------------------------------------------------------- openings

## A door has to fit the wall it is cut into, with masonry either side of it.
func _check_door_openings(plan: HousePlan) -> void:
	for di in range(plan.doors.size()):
		var d: Dictionary = plan.doors[di]
		var run: Array = _wall_run_for(plan, d)
		if run.is_empty():
			failures.append("opening: door %d is not on any wall the rooms share" % di)
			continue
		var t: float = float(run[0])
		var length: float = float(run[1])
		var w: float = float(d["width"])
		var m: float = HouseGeometry.DOOR_CORNER_MARGIN
		if t - w / 2.0 < -TOL or t + w / 2.0 > length + TOL:
			failures.append("opening: door %d hangs off the end of its wall" % di)
		elif t - w / 2.0 < m - TOL or t + w / 2.0 > length - m + TOL:
			warnings.append("opening: door %d is within %.2fm of a corner"
				% [di, HouseGeometry.DOOR_CORNER_MARGIN])
		for dj in range(di + 1, plan.doors.size()):
			var e: Dictionary = plan.doors[dj]
			if not _same_wall(d, e):
				continue
			var gap: float = (Vector2(d["pos"]) - Vector2(e["pos"])).length()
			if gap < (w + float(e["width"])) / 2.0 + 0.1:
				failures.append("opening: doors %d and %d are cut into the same stretch of wall"
					% [di, dj])


## Windows: outside walls only, clear of the corners, clear of each other and
## of the doors, and enough of them to light the room.
func _check_windows(plan: HousePlan) -> void:
	for wi in range(plan.windows.size()):
		var w: Dictionary = plan.windows[wi]
		var inner := HouseGeometry.storey_rect(plan, HousePlan.record_storey(w)).grow(-HouseGeometry.wall_thickness(plan.spec))
		if HousePlan.record_storey(w) != HousePlan.record_storey(plan.rooms[int(w["room"])]):
			failures.append("window %d is tagged for the wrong storey" % wi)
		var pos: Vector2 = w["pos"]
		var n: Vector2 = w["normal"]
		# A window onto a COURT is a window: the court is open to the sky, so
		# the wall it is cut into is an outside wall however far inside the
		# footprint it stands (GEO-003).
		if _onto_court(plan, pos, n):
			continue
		# A shaped room's outside walls are its own edges, and a window on a
		# diagonal is on an outside wall even though it is nowhere near the
		# edge of the box round it (GEO-002).
		if plan.is_polygonal(int(w["room"])):
			if not _on_outline(plan.outline_of(int(w["room"])), pos):
				failures.append("window %d at %v is in a partition, not an outside wall"
					% [wi, pos])
			continue
		var on_wall: bool = (absf(n.x) > 0.5 and (absf(pos.x - inner.position.x) < TOL
				or absf(pos.x - inner.end.x) < TOL)) \
			or (absf(n.y) > 0.5 and (absf(pos.y - inner.position.y) < TOL
				or absf(pos.y - inner.end.y) < TOL))
		if not on_wall:
			failures.append("window %d at %v is in a partition, not an outside wall"
				% [wi, pos])
			continue
		# and on the stretch of that wall its own room owns
		var rect: Rect2 = plan.rooms[w["room"]]["rect"]
		var t: float = pos.x if absf(n.y) > 0.5 else pos.y
		var lo: float = rect.position.x if absf(n.y) > 0.5 else rect.position.y
		var hi: float = rect.end.x if absf(n.y) > 0.5 else rect.end.y
		var half: float = float(w["width"]) / 2.0
		if t - half < lo - TOL or t + half > hi + TOL:
			failures.append("window %d is cut into room %d's wall but sits outside the room"
				% [wi, w["room"]])
		if float(w["sill"]) < 0.5:
			failures.append("window %d has a %.2fm sill -- that is a doorway"
				% [wi, float(w["sill"])])
		if float(w["head"]) > plan.spec.height - 0.1:
			failures.append("window %d reaches %.2fm, through a %.2fm wall"
				% [wi, float(w["head"]), plan.spec.height])
		for wj in range(wi + 1, plan.windows.size()):
			var o: Dictionary = plan.windows[wj]
			if not _same_wall(w, o):
				continue
			if (Vector2(w["pos"]) - Vector2(o["pos"])).length() \
					< (float(w["width"]) + float(o["width"])) / 2.0 + 0.05:
				failures.append("windows %d and %d overlap on the same wall" % [wi, wj])
		for d in plan.doors:
			if not _same_wall(w, d):
				continue
			if (Vector2(w["pos"]) - Vector2(d["pos"])).length() \
					< (float(w["width"]) + float(d["width"])) / 2.0 + 0.05 \
					and float(w["sill"]) < float(d.get("head", HouseGeometry.DOOR_H)) - 0.02:
				failures.append("window %d is cut through a doorway" % wi)

	for i in range(plan.room_count()):
		var kind: StringName = plan.kind_of(i)
		if not HouseGeometry.is_habitable(kind):
			continue
		var wins: Array[int] = plan.windows_of(i)
		if wins.is_empty():
			failures.append("daylight: room %d (%s) has no window" % [i, String(kind)])
			continue
		var glass := 0.0
		for k in wins:
			glass += HouseGeometry.window_area(plan.windows[k])
		var area: float = HouseGeometry.room_area(plan, i)
		if glass < area * HouseGeometry.GLAZING_MIN - 0.01:
			warnings.append("daylight: room %d (%s) has %.2f m2 of glass for %.1f m2 of floor"
				% [i, String(kind), glass, area])


# ------------------------------------------------------- upstairs programme

## Does the line between two doors cross a court?
static func _across_a_court(plan: HousePlan, a: Vector2, b: Vector2) -> bool:
	for ci in range(plan.courts.size()):
		var poly: PackedVector2Array = plan.court_outline(ci)
		for k in range(9):
			var t: float = float(k) / 8.0
			if Poly.contains_point(poly, a.lerp(b, t), 0.01):
				return true
	return false


## Does an opening at `pos`, facing `n`, look into a court?
##
## The step OUT of the wall is what decides it: a window's normal points out of
## the room it lights, so a pace that way lands in the yard when the yard is
## what it looks at.
static func _onto_court(plan: HousePlan, pos: Vector2, n: Vector2) -> bool:
	var outside: Vector2 = pos + n * (HouseGeometry.WALL_T + 0.05)
	for ci in range(plan.courts.size()):
		if Poly.contains_point(plan.court_outline(ci), outside, 0.01):
			return true
	return false


## Does `p` sit on an edge of this outline?
static func _on_outline(poly: PackedVector2Array, p: Vector2) -> bool:
	for k in range(poly.size()):
		var a: Vector2 = poly[k]
		var b: Vector2 = poly[(k + 1) % poly.size()]
		var d: Vector2 = b - a
		var len2: float = d.length_squared()
		if len2 < 1e-9:
			continue
		var t: float = clampf((p - a).dot(d) / len2, 0.0, 1.0)
		if (a + d * t).distance_to(p) < 0.05:
			return true
	return false


## What is upstairs is not a copy of what is downstairs.
##
## The upper floors reuse the ground partition -- the walls have to line up --
## and it used to reuse its NAMES too, which gave a house two kitchens, two
## halls, a second front-door-less entrance hall and a fire with no flue over
## the first one. A dwelling keeps its service and public programme on the
## ground floor and sleeps upstairs.
##
## A building that brought its own room programme (a shop, a hotel: anything
## whose spec can answer `room_program`) is exempt -- an inn's kitchen is on
## whatever floor its own planner put it on, and that is not this rule's
## business.
func _check_upstairs_programme(plan: HousePlan) -> void:
	if int(plan.spec.storeys) <= 1 or plan.spec.has_method("room_program"):
		return
	var beds := 0
	for i in range(plan.room_count()):
		var storey: int = plan.storey_of_room(i)
		var kind: StringName = plan.kind_of(i)
		if storey <= 0:
			continue
		if kind in GROUND_FLOOR_ONLY:
			failures.append("upstairs_programme: room %d is a %s on storey %d -- that belongs on the ground floor"
				% [i, String(kind), storey])
		if kind in HouseGeometry.SLEEPING:
			beds += 1
	stats["upstairs_bedrooms"] = beds
	var hearth: int = plan.hearth_room()
	if hearth >= 0 and plan.storey_of_room(hearth) != 0:
		failures.append("upstairs_programme: the hearth is in room %d on storey %d -- the chimney rises from the ground floor"
			% [hearth, plan.storey_of_room(hearth)])
	if beds == 0 and _could_sleep_upstairs(plan):
		# a warning, not a failure: on a narrow plan the only room upstairs
		# that can hold a bed is the landing itself, and a bedroom you have to
		# cross to reach the back room is the worse defect of the two
		warnings.append("upstairs_programme: nobody sleeps on the %d upper storeys of this house"
			% [int(plan.spec.storeys) - 1])


## Is there a room above the ground floor that could have been a bedroom
## without putting anybody's route through it?
func _could_sleep_upstairs(plan: HousePlan) -> bool:
	var start: int = plan.entrance_room()
	if start < 0:
		return false
	for i in range(plan.room_count()):
		if plan.storey_of_room(i) <= 0:
			continue
		if not HouseGeometry.room_suits(plan, i, &"bedroom"):
			continue
		var was: StringName = plan.rooms[i]["kind"]
		plan.rooms[i]["kind"] = &"bedroom"
		var polite: Dictionary = plan.reachable_rooms(start, HouseGeometry.SLEEPING)
		plan.rooms[i]["kind"] = was
		var stranded := false
		for j in range(plan.room_count()):
			if j != i and not polite.has(j):
				stranded = true
				break
		if not stranded:
			return true
	return false


# ----------------------------------------------------------------- helpers

## Where an opening sits on its wall: [distance along, wall length]. For an
## interior door that is the shared edge of the two rooms; for an exterior one
## it is the room's own stretch of the outside wall.
static func _wall_run_for(plan: HousePlan, d: Dictionary) -> Array:
	var a: int = d["a"]
	var b: int = d["b"]
	if b >= 0:
		var edge: Array = HousePlanOpenings.shared_edge(plan, a, b)
		if edge.is_empty():
			return []
		var t0: float = edge[2]
		var t1: float = edge[3]
		var pos: Vector2 = d["pos"]
		var along: float = pos.y if Vector2(edge[0]).x > 0.5 else pos.x
		return [along - t0, t1 - t0]
	if plan.is_polygonal(a):
		var pos := Vector2(d["pos"])
		for wall in HouseGeometry.room_walls(plan, a):
			var from := Vector2(wall.from)
			var to := Vector2(wall.to)
			var nearest := Geometry2D.get_closest_point_to_segment(pos, from, to)
			if pos.distance_to(nearest) <= TOL \
					and Vector2(d.normal).dot(-Vector2(wall.normal)) > 0.9:
				return [from.distance_to(nearest), from.distance_to(to)]
		return []
	var rect: Rect2 = plan.rooms[a]["rect"]
	var n: Vector2 = d["normal"]
	if absf(n.y) > 0.5:
		return [float(d["pos"].x) - rect.position.x, rect.size.x]
	return [float(d["pos"].y) - rect.position.y, rect.size.y]


## Two openings are on the same wall when their normals share an axis and they
## lie on the same line.
static func _same_wall(a: Dictionary, b: Dictionary) -> bool:
	if HousePlan.record_storey(a) != HousePlan.record_storey(b):
		return false
	var na: Vector2 = a["normal"]
	var nb: Vector2 = b["normal"]
	if (absf(na.x) > 0.5) != (absf(nb.x) > 0.5):
		return false
	var pa: Vector2 = a["pos"]
	var pb: Vector2 = b["pos"]
	if absf(na.x) > 0.5:
		return absf(pa.x - pb.x) < 0.05
	return absf(pa.y - pb.y) < 0.05


## The stair stands against a wall of the room it rises from, and its foot is
## out of the line of the front door (LAY-005). A stair in the middle of the
## hall faces whoever comes in head-on and takes the table's place; a stair
## across the door line is the first thing you walk into. Measured from the
## stair's footprint and the door alone, the way the planner measures it.
const STAIR_WALL_TOL := 0.06

func _check_stair_line(plan: HousePlan) -> void:
	var front: int = plan.entrance()
	for si in range(plan.stairs.size()):
		var stair: Dictionary = plan.stairs[si]
		var room: int = int(stair.get("a", -1))
		if room < 0 or room >= plan.room_count():
			continue
		var rect: Rect2 = Rect2(stair.get("lower_rect", stair.get("rect", Rect2())))
		if rect.size.x <= 0.0:
			continue
		var gap := stair_wall_gap(plan, stair)
		if gap > STAIR_WALL_TOL:
			failures.append("stair_line: stair %d stands %.2fm off every wall of room %d (%s)"
				% [si, gap, room, String(plan.kind_of(room))])
		if front < 0 or int(plan.doors[front]["a"]) != room:
			continue
		var line: Rect2 = HousePlanLevels.door_line(plan, room, plan.doors[front])
		var over: Rect2 = line.intersection(rect)
		if over.size.x > TOL and over.size.y > TOL:
			var msg := "stair_line: the foot of stair %d lies in the line of the front door" % si
			if plan.was_dropped(room, "stair"):
				warnings.append(msg)
			else:
				failures.append(msg)


## A stair against the wall of a narrowing upper storey may stand away from
## the lower outside wall. Both landings must still fit their real floors.
static func stair_wall_gap(plan: HousePlan, stair: Dictionary) -> float:
	var lower := int(stair.get("a", -1))
	if lower < 0 or lower >= plan.room_count():
		return INF
	var rect := Rect2(stair.get("lower_rect", stair.get("rect", Rect2())))
	var rooms: Array[int] = [lower]
	var upper := int(stair.get("b", -1))
	if upper >= 0 and upper < plan.room_count() \
			and (plan.is_polygonal(lower) or plan.is_polygonal(upper)):
		rooms.append(upper)
	var gap := INF
	for room in rooms:
		for wall in HouseGeometry.room_walls(plan, room):
			for point in Poly.from_rect(rect):
				var nearest := Geometry2D.get_closest_point_to_segment(point, wall.from, wall.to)
				gap = minf(gap, point.distance_to(nearest))
	return gap


## The front door and the back door are not in line (LAY-006): two exterior
## doors on opposite walls whose openings overlap, measured along the wall,
## make the house a corridor with rooms off it. Measured from the doors alone.
func _check_doors_in_line(plan: HousePlan) -> void:
	for di in range(plan.doors.size()):
		var d: Dictionary = plan.doors[di]
		if not d["exterior"]:
			continue
		for dj in range(di + 1, plan.doors.size()):
			var e: Dictionary = plan.doors[dj]
			if not e["exterior"]:
				continue
			var dn: Vector2 = d["normal"]
			var en: Vector2 = e["normal"]
			if dn.dot(en) > -0.9:
				continue
			var along := Vector2(absf(dn.y), absf(dn.x))
			var a: float = Vector2(d["pos"]).dot(along)
			var b: float = Vector2(e["pos"]).dot(along)
			# Two doors facing each other across a YARD are a cloister, not a
			# corridor. The rule is about a house you can see straight through
			# from the street; a court is outside, and a range opening onto it
			# opposite another range is the whole point of the plan (GEO-003).
			if _across_a_court(plan, Vector2(d["pos"]), Vector2(e["pos"])):
				continue
			var overlap: float = (float(d["width"]) + float(e["width"])) / 2.0 - absf(a - b)
			if overlap > TOL:
				failures.append("doors_in_line: doors %d and %d face each other across the house, %.2fm of them in line"
					% [di, dj, overlap])
