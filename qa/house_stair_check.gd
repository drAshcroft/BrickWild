class_name HouseStairCheck
extends RefCounted
## Can you walk up it? The plan rules ask only that a stair exists, where its
## rectangle lies and that there is floor at its foot. Walk QA (3-7 Oct) found
## flights that end in a wall, are too steep to climb, have a shelf hung over
## them and no rail beside a 2.6-3.6 m drop -- in houses, hotels and village
## houses, twice, with every lane green. Each rule is one of those pins:
##
##   STAIR_PITCH     riser <= 0.22, going >= 0.22, 2R + G <= 0.70, pitch <= 42 deg
##   STAIR_HEAD      the top step arrives on floor of the upper room, not a wall
##   STAIR_HEADROOM  nothing hangs or stands within 2 m above a tread
##   STAIR_GUARD     an open side of a flight or of its well has a rail
##                   (a "rail" row in the builder's component_log, hosted
##                   "stair_<n>"); geometry fixtures also probe the actual rails
##   STAIR_APPROACH  a 0.9 m wide walker can reach the foot from the front door
##
## Proposed and proven on the pinned village house_9 and hotel seed 1 in
## artifacts/walkpins/stairs/ (2026-10-07).

const RISER_MAX := 0.22
const GOING_MIN := 0.22
const STRIDE_MAX := 0.70
const PITCH_MAX := 42.0
const HEADROOM := 2.0
const WALKER := 0.45       # half the width of a person carrying something

## What HouseBuilder._emit_stairs uses when a stair names no step count.
const DEFAULT_STEPS := 10


static func check(plan: HousePlan, builder: MassBuilder = null) -> Array[String]:
	var out: Array[String] = []
	for si in plan.stairs.size():
		var st: Dictionary = plan.stairs[si]
		if not bool(st.get("satisfied", true)):
			out.append("stair_infeasible: stair %d has no usable flight: %s" % [
				si, String(st.get("reason", "no fitting layout"))])
			continue
		_pitch(plan, si, st, out)
		_head(plan, si, st, out)
		_headroom(plan, si, st, out)
		if builder != null:
			_guard(plan, si, st, builder, out)
		_approach(plan, si, st, out)
	return out


static func _steps(st: Dictionary) -> int:
	return maxi(4, int(st.get("steps", DEFAULT_STEPS)))


static func _pitch(plan: HousePlan, si: int, st: Dictionary, out: Array[String]) -> void:
	var r := Rect2(st["lower_rect"])
	var h := plan.spec.height
	var run := maxf(r.size.x, r.size.y)
	var riser := h / _steps(st)
	var going := run / _steps(st)
	var pitch := rad_to_deg(atan2(h, run))
	if riser > RISER_MAX + 0.005 or going < GOING_MIN - 0.005 or 2.0 * riser + going > STRIDE_MAX + 0.01 \
			or pitch > PITCH_MAX:
		out.append("stair_pitch: stair %d rises %.2fm a step on a %.2fm going (2R+G %.2f, %.0f deg) -- too steep to climb"
			% [si, riser, going, 2.0 * riser + going, pitch])


static func _head(plan: HousePlan, si: int, st: Dictionary, out: Array[String]) -> void:
	var r := Rect2(st["lower_rect"])
	var b := int(st["b"])
	var climb := HouseGeometry.stair_climb(plan, st)
	var width := minf(r.size.x, r.size.y)
	var head: Rect2 = st.get("head_landing", HouseGeometry.stair_approach(r, -climb, width))
	if not _floor_poly_contains(HouseGeometry.room_floor_poly(plan, b), head):
		out.append("stair_head: stair %d climbs into a wall -- no floor of room %d (%s) beyond its top step"
			% [si, b, String(plan.kind_of(b))])


static func _headroom(plan: HousePlan, si: int, st: Dictionary, out: Array[String]) -> void:
	var r := Rect2(st["lower_rect"])
	var h := plan.spec.height
	var along_x := r.size.x > r.size.y
	var run := maxf(r.size.x, r.size.y)
	var going := run / _steps(st)
	var climb := HouseGeometry.stair_climb(plan, st)
	for fi in plan.furniture.size():
		var f: Dictionary = plan.furniture[fi]
		if HousePlan.record_storey(f) not in [int(st["storey"]), int(st.get("to_storey", 0))]:
			continue
		var key := String(f["key"])
		var scale := float(f.get("scale", 1.0))
		# Assembly offsets wall bodies into the room and hangs ceiling props
		# from their measured top. An isotropic expansion of a mount point
		# falsely puts torches through the adjoining wall and misreads height.
		var yaw := float(f.get("yaw", 0.0)) + PropCatalog.face_offset(key)
		var origin := PropCatalog.house_origin(f)
		var centre := PropCatalog.plan_centre(key, origin, yaw, scale)
		var footprint := PropCatalog.footprint_rotated(key, yaw) * scale
		var over := Rect2(centre - footprint * 0.5, footprint).intersection(r)
		if not over.has_area():
			continue
		var t := over.end.x - r.position.x if along_x else over.end.y - r.position.y
		if climb < 0.0:
			t = r.end.x - over.position.x if along_x else r.end.y - over.position.y
		var tread := h * ceilf(t / going) / _steps(st) + int(st["storey"]) * h
		if bool(st.get("domestic_profile", false)):
			tread += HouseGeometry.FLOOR_T
		var y0: float = origin.y + PropCatalog.floor_offset(key) * scale
		if y0 < tread + HEADROOM:
			out.append("stair_headroom: %s is %.2fm above the stair %d tread under it"
				% [HouseFurnishCheck.who(plan, fi), y0 - tread, si])


static func _guard(plan: HousePlan, si: int, st: Dictionary, builder: MassBuilder, out: Array[String]) -> void:
	var rails := 0
	for row in builder.component_log:
		if String(row.get("host", "")) == "stair_%d" % si and "rail" in String(row.get("role", "")):
			rails += 1
	var r := Rect2(st["lower_rect"])
	var along_x := r.size.x > r.size.y
	var sides := [Rect2(r.position - Vector2(0, 0.1), Vector2(r.size.x, 0.1)),
		Rect2(Vector2(r.position.x, r.end.y), Vector2(r.size.x, 0.1))] if along_x \
		else [Rect2(r.position - Vector2(0.1, 0), Vector2(0.1, r.size.y)),
		Rect2(Vector2(r.end.x, r.position.y), Vector2(0.1, r.size.y))]
	var open := 0
	for side in sides:
		for room in [int(st["a"]), int(st["b"])]:
			if HouseGeometry.room_floor_rect(plan, room).encloses(side):
				open += 1
	if open > rails:
		out.append("stair_guard: stair %d has %d open side(s) over a %.1fm drop and %d rail(s)"
			% [si, open, plan.spec.height, rails])


static func _approach(plan: HousePlan, si: int, st: Dictionary, out: Array[String]) -> void:
	var lo := int(st["storey"])
	var nav := HouseNavCheck.new()
	nav._plan = plan
	nav._rasterize()
	if not nav._grids.has(lo):
		return
	var g: WalkGrid = nav._grids[lo]
	var r := Rect2(st["lower_rect"])
	var start := Vector2.ZERO
	if bool(st.get("domestic_profile", false)) and lo > 0:
		# On an upper storey the route begins where the preceding flight arrives,
		# not at the front door several floors below. Match both storey and room
		# so an unrelated stair into another wing cannot stand in for arrival.
		var arrived := false
		for previous in plan.stairs:
			if not bool(previous.get("satisfied", true)) \
					or int(previous.get("to_storey", -1)) != lo \
					or int(previous.get("b", -1)) != int(st.get("a", -2)):
				continue
			var head := Rect2(previous.get("head_landing", Rect2()))
			if not head.has_area():
				continue
			start = head.get_center()
			arrived = true
			break
		if not arrived:
			out.append("stair_approach: stair %d has no satisfied arrival landing on storey %d"
				% [si, lo])
			return
	else:
		# Legacy/custom stairs have no guaranteed end-landing field. Preserve
		# their existing entrance-floor check; domestic upper flights use the
		# explicit arrival landing path above.
		var door := plan.entrance()
		if door < 0 or HousePlan.record_storey(plan.doors[door]) != lo:
			return
		start = Vector2(plan.doors[door]["pos"]) - Vector2(plan.doors[door]["normal"]) \
			* (HouseGeometry.wall_thickness(plan.spec) * 0.5 + 0.2)
	# A domestic well is not walkable floor on either side of a transition.
	# Preserve legacy checks' former single-flight obstacle exactly.
	if bool(st.get("domestic_profile", false)):
		for other in plan.stairs:
			if not bool(other.get("satisfied", true)):
				continue
			var other_lo := int(other.get("storey", 0))
			var other_hi := int(other.get("to_storey", other_lo + 1))
			var occupied := Rect2()
			if other_lo == lo:
				occupied = Rect2(other.get("lower_rect", other.get("rect", Rect2())))
			elif other_hi == lo:
				occupied = Rect2(other.get("upper_rect", other.get("rect", Rect2())))
			if occupied.has_area():
				g.add_obstacle(occupied)
	else:
		g.add_obstacle(r)
	g.build(WALKER)
	# A body's centre cannot enter the old 0.3 m strip after the flight has
	# been inflated by its 0.45 m radius. Judge the actual landing before the
	# flight, keeping the flight itself blocked so a sideways shortcut fails.
	var foot: Rect2 = st.get("foot_landing", HouseGeometry.stair_approach(r,
		HouseGeometry.stair_climb(plan, st), maxf(WALKER * 2.0, minf(r.size.x, r.size.y))))
	if not g.flood_from(start) or not g.reached(foot):
		var origin := "arrival landing" if bool(st.get("domestic_profile", false)) and lo > 0 \
			else "front door"
		out.append("stair_approach: the foot of stair %d cannot be reached from the %s by a %.1fm wide walker"
			% [si, origin, WALKER * 2.0])


static func _floor_poly_contains(poly: PackedVector2Array, rect: Rect2) -> bool:
	if poly.size() < 3 or not rect.has_area():
		return false
	for point in Poly.from_rect(rect):
		if not Poly.contains_point(poly, point, 0.02):
			return false
	return true
