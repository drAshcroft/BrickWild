class_name TowerCheck
extends RefCounted
## Is it a tower house? (CAS-006; WORLD_BUILDINGS 1.3)
##
## A tower house is the house tier grown up instead of out: one tall block,
## an L or Z jog off it, no curtain. Six rules say what makes it one, each
## measured from the masses and openings the builder logged, never from the
## spec's intentions alone:
##
##   SLENDER   it is a tower: the block stands at least four times as tall as
##             its longer side (the Bologna type, whose base is 10 m or less),
##             or twice as tall for the broader Scottish type
##   LIFT      the only way in is a raised door, its sill 2 m or more above
##             the ground, and no opening at all sits lower than that
##   STACK     one room per level, stairs between every level, and a walkable
##             route from the raised entrance onto the roof platform
##   FOOT      the walls at the foot are half as thick again as at the top
##   NO GAPS / GROUNDED  the structural rules every building gets
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

const TOL := MassRules.TOL
const LIFT_MIN := 2.0
const FOOT_RATIO := 1.5
const BOLOGNA_BASE_MAX := 10.0
const SLENDER := {&"bologna": 4.0, &"scottish": 2.0}

const RULES: Array[StringName] = [&"slender", &"lift", &"stack", &"foot", &"no_gaps", &"grounded"]
const METHODS := {&"stack": "_check_stack", &"no_gaps": "_check_gaps"}

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
var replaced: Dictionary = {}


func check(spec: CastleSpec, builder: CastleBuilder, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	if not CastleGeometry.is_tower_house(spec):
		failures.append("tower: the plan is %s, not a tower house" % String(spec.plan_kind))
		return _report()
	replaced = RuleSet.run(self, RULES, METHODS, overrides, [spec, builder],
		[spec, builder], failures, warnings)
	return _report()


func _report() -> Dictionary:
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "replaced": replaced}


func _check_slender(spec: CastleSpec, builder: CastleBuilder) -> void:
	var hall: AABB = builder.mass_aabb("hall")
	if hall.size.y <= 0.0:
		failures.append("slender: no hall mass to measure")
		return
	var base: float = maxf(hall.size.x, hall.size.z)
	var want: float = float(SLENDER.get(spec.tower_type, 4.0))
	stats["slenderness"] = snappedf(hall.size.y / maxf(base, 0.01), 0.01)
	if hall.size.y < want * base - TOL:
		failures.append("slender: a %s tower %.1fm high on a %.1fm base is %.1fx, wants %.0fx"
			% [String(spec.tower_type), hall.size.y, base, hall.size.y / maxf(base, 0.01), want])
	if spec.tower_type == &"bologna" and base > BOLOGNA_BASE_MAX + TOL:
		failures.append("slender: a Bologna tower on a %.1fm base; they are %.0fm or less"
			% [base, BOLOGNA_BASE_MAX])


func _check_lift(_spec: CastleSpec, builder: CastleBuilder) -> void:
	var doors := 0
	var lowest := INF
	for p in builder.part_log:
		var opening_kind := StringName(p.get("opening_kind", ""))
		if opening_kind.is_empty():
			opening_kind = &"door" if p.get("tag", "") == "door" else StringName(p.get("kind", ""))
		if opening_kind not in [&"window", &"door"]:
			continue
		var sill: float = float((p["pos"] as Vector3).y) - float((p["size"] as Vector3).y) / 2.0
		if opening_kind == &"door":
			doors += 1
			if sill < LIFT_MIN - TOL:
				failures.append("lift: the door sill is %.2fm up; a tower house is entered at %.0fm or more"
					% [sill, LIFT_MIN])
		lowest = minf(lowest, sill)
	stats["lowest_opening"] = snappedf(lowest, 0.01) if lowest < INF else 0.0
	if doors != 1:
		failures.append("lift: %d doors; a tower house has one raised door" % doors)
	if lowest < LIFT_MIN - TOL:
		failures.append("lift: an opening %.2fm from the ground, below the %.0fm a ladder reaches"
			% [lowest, LIFT_MIN])


func _check_foot(spec: CastleSpec, builder: CastleBuilder) -> void:
	var hall: AABB = builder.mass_aabb("hall")
	var interior: float = hall.size.x - 2.0 * spec.wall_thickness
	var lowest := AABB()
	var highest := AABB()
	for m in builder.mass_log:
		if not String(m["name"]).begins_with("storey_"):
			continue
		var a: AABB = m["aabb"]
		if lowest.size.y <= 0.0 or a.position.y < lowest.position.y:
			lowest = a
		if highest.size.y <= 0.0 or a.position.y > highest.position.y:
			highest = a
	if lowest.size.y <= 0.0:
		failures.append("foot: no storey masses to measure the walls from")
		return
	var t_foot: float = (lowest.size.x - interior) / 2.0
	var t_top: float = (highest.size.x - interior) / 2.0
	stats["wall_foot"] = snappedf(t_foot, 0.01)
	stats["wall_top"] = snappedf(t_top, 0.01)
	if t_foot < t_top * FOOT_RATIO - TOL:
		failures.append("foot: the walls are %.2fm at the foot and %.2fm at the top; the foot wants %.1fx"
			% [t_foot, t_top, FOOT_RATIO])


## The plan is the only record of where the rooms and stair landings are.
## Count each floor, then walk the transition graph from the raised entrance
## to the exposed roof deck.
func _check_stack(spec: CastleSpec, builder: CastleBuilder) -> void:
	var plan: HousePlan
	for row in builder.interiors:
		if String(row.get("id", "")) == "tower_house":
			plan = row.get("plan")
			break
	if plan == null:
		failures.append("stack: the emitted tower has no interior plan")
		return
	var top := maxi(spec.tower_storeys, 1)
	var rooms_by_level := {}
	for room_id in range(plan.rooms.size()):
		var level := HousePlan.record_storey(plan.rooms[room_id])
		rooms_by_level[level] = int(rooms_by_level.get(level, 0)) + 1
	for level in range(top + 1):
		if int(rooms_by_level.get(level, 0)) != 1:
			failures.append("stack: storey %d has %d rooms; it needs exactly one" % [
				level, int(rooms_by_level.get(level, 0))])
	var room_at := {}
	for room_id2 in range(plan.rooms.size()):
		room_at[HousePlan.record_storey(plan.rooms[room_id2])] = room_id2
	if plan.spec == null or int(plan.spec.storeys) != top + 1:
		failures.append("stack: the roof platform is not represented as the final walk level")
		return
	if not room_at.has(top):
		failures.append("stack: the final level has no roof-platform room")
	elif plan.kind_of(int(room_at[top])) != &"roof_platform":
		failures.append("stack: the final level is not the roof platform")
	var links := {}
	for stair in plan.stairs:
		var low := int(stair.get("storey", -999))
		var high := int(stair.get("to_storey", low + 1))
		if high != low + 1 or low < 0 or high > top \
				or int(stair.get("a", -1)) != int(room_at.get(low, -2)) \
				or int(stair.get("b", -1)) != int(room_at.get(high, -2)):
			continue
		if not _stair_lands_in_rooms(plan, stair, int(room_at[low]), int(room_at[high])):
			continue
		links[low] = int(links.get(low, 0)) + 1
	for level2 in range(top):
		if int(links.get(level2, 0)) != 1:
			failures.append("stack: stairs do not form one continuous route across storeys %d to %d"
				% [level2, level2 + 1])
	var entry_level := -1
	for door in plan.doors:
		if bool(door.get("exterior", false)):
			entry_level = HousePlan.record_storey(door)
			break
	var reached := {}
	if entry_level >= 0 and entry_level <= top:
		reached[entry_level] = true
		var queue: Array[int] = [entry_level]
		while not queue.is_empty():
			var here: int = queue.pop_front()
			for stair2 in plan.stairs:
				var lo := int(stair2.get("storey", -999))
				var hi := int(stair2.get("to_storey", lo + 1))
				if hi != lo + 1:
					continue
				var next := hi if here == lo else (lo if here == hi else -1)
				if next >= 0 and not reached.has(next):
					reached[next] = true
					queue.append(next)
	if not reached.has(top):
		failures.append("stack: the roof platform cannot be reached from the raised entrance")
	var nav := HouseNavCheck.new().check(plan)
	var platform_room := int(room_at.get(top, -1))
	if platform_room < 0 or platform_room in nav.get("unreached_rooms", []) \
			or nav.get("failures", []).any(func(message: String) -> bool:
				return String(message).begins_with("nav: storey %d cannot be reached" % top)):
		failures.append("stack: the roof platform is not walkable from the raised entrance")
	stats["reachable_storeys"] = reached.size()
	stats["roof_platform"] = reached.has(top) and platform_room >= 0 \
		and not platform_room in nav.get("unreached_rooms", [])


func _stair_lands_in_rooms(plan: HousePlan, stair: Dictionary,
		low_room: int, high_room: int) -> bool:
	for endpoint in ["lower_rect", "upper_rect"]:
		var level := int(stair.get("storey", 0)) if endpoint == "lower_rect" \
			else int(stair.get("to_storey", 1))
		var room := low_room if endpoint == "lower_rect" else high_room
		var rect: Rect2 = Rect2(stair.get(endpoint, stair.get("rect", Rect2())))
		if rect.size.x <= 0.0 or rect.size.y <= 0.0 \
				or HousePlan.record_storey(plan.rooms[room]) != level:
			return false
		if plan.is_polygonal(room):
			var outline: PackedVector2Array = plan.outline_of(room)
			for corner in [rect.position, Vector2(rect.end.x, rect.position.y),
				rect.end, Vector2(rect.position.x, rect.end.y)]:
				if not Poly.contains_point(outline, corner, 0.02):
					return false
	return true


func _check_gaps(_spec: CastleSpec, builder: CastleBuilder) -> void:
	var g: Dictionary = MassRules.gaps(builder.mass_log, "hall")
	for f in g["failures"]:
		failures.append(str(f))
	stats["masses_joined"] = g["joined"]


## The upper storeys and the roof platform are carried by the storey below.
func _check_grounded(_spec: CastleSpec, builder: CastleBuilder) -> void:
	var carried: Array = ["platform"]
	for m in builder.mass_log:
		var nm: String = m["name"]
		if nm.begins_with("storey_") and nm != "storey_0":
			carried.append(nm)
	for f in MassRules.grounded(builder.mass_log, carried):
		failures.append(str(f))
