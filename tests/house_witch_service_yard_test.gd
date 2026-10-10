extends SceneTree
## Focused service-yard contract for the frozen Witch request geometry.
## The yard must be planned around the authored door; role presence alone is not enough.

const SIZES := [
	{"id":"compact","width":7.0,"length":9.0,"height":2.6,"bay":false},
	{"id":"default","width":9.0,"length":12.0,"height":2.6,"bay":true},
	{"id":"large","width":17.0,"length":18.0,"height":2.8,"bay":true},
]
const SEEDS := [1, 8102, 21325]
var failures: Array[String] = []

func _init() -> void:
	for size in SIZES:
		for seed_value in SEEDS:
			_check_witch(size, seed_value)
	for size in SIZES:
		_check_excluded_controls(size)
	for failure in failures:
		printerr("FAIL " + failure)
	print("Witch service-yard threshold contract: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)

func _check_witch(size: Dictionary, seed_value: int) -> void:
	var spec := HouseSpec.new(seed_value)
	spec.style = &"witch_hut"
	spec.trade = &"none"
	spec.width = float(size.width)
	spec.length = float(size.length)
	spec.height = float(size.height)
	spec.storeys = 1
	spec.cellars = 0
	var plan := HouseGenerator.generate(spec, seed_value, true)
	var label := "%s seed=%d" % [size.id, seed_value]
	var door: Dictionary = {}
	for candidate in plan.doors:
		if bool(candidate.get("witch_workshop_yard", false)):
			door = candidate
			break
	if door.is_empty():
		failures.append("%s lost the authored Witch service threshold" % label)
		return
	var compact := bool(door.get("witch_compact_service_threshold", false))
	if compact != (size.id == "compact"):
		failures.append("%s service threshold used the wrong compact/Workshop grammar" % label)
	var bay: Dictionary = HouseGeometry.roof_layout(plan).get("witch_bay", {})
	if bool(size.bay) != not bay.is_empty():
		failures.append("%s changed the separate structural Workshop bay eligibility" % label)
	var shelter: Dictionary = {}
	for piece in plan.yard_pieces:
		if String(piece.get("role", "")) == "witch_work_shelter":
			shelter = piece
			break
	if shelter.is_empty():
		failures.append("%s omitted the required work shelter at the authored threshold; omissions=%s" % [label, str(plan.exterior_omissions)])
		return
	var group := String(shelter.get("group", ""))
	var shelter_rect := Rect2(shelter.get("rect", Rect2()))
	var body: Vector2 = Vector2(door["pos"]) + Vector2(door["normal"]) * \
		(HouseGeometry.wall_thickness(spec) + HouseGeometry.PERSON_RADIUS + 0.05)
	var roof_rects: Dictionary = {}
	var threshold_roof := AABB()
	for part in shelter.get("parts", []):
		var part_bounds: AABB = HouseYard.part_aabb(part)
		var part_reason := HouseYard.clear_reason(plan, HouseGeometry.yard_rect(plan), part_bounds)
		if not part_reason.is_empty():
			failures.append("%s shelter part %s violates the unchanged facade reservation: %s" % [
				label, String(part.get("role", "?")), part_reason])
		var part_role := String(part.get("role", ""))
		if part_role.ends_with("_roof"):
			var part_rect := Rect2(Vector2(part_bounds.position.x, part_bounds.position.z),
				Vector2(part_bounds.size.x, part_bounds.size.z))
			roof_rects[part_role] = part_rect
			if part_role == "witch_shelter_roof":
				threshold_roof = part_bounds
	var expected_roof_count := 1 if compact else 2
	if roof_rects.size() != expected_roof_count:
		failures.append("%s expected %d separated measured roof bays, found %d" % [
			label, expected_roof_count, roof_rects.size()])
	if threshold_roof.size == Vector3.ZERO:
		failures.append("%s shelter has no measured threshold roof part" % label)
	else:
		var threshold_rect := Rect2(Vector2(threshold_roof.position.x, threshold_roof.position.z),
			Vector2(threshold_roof.size.x, threshold_roof.size.z))
		if not threshold_rect.grow(0.05).has_point(body):
			failures.append("%s actual threshold roof does not cover the exterior body datum" % label)
	if not compact:
		for role in ["witch_shelter_roof", "witch_work_wing_roof"]:
			if not roof_rects.has(role):
				failures.append("%s is missing the separate %s" % [label, role])
				continue
			var rect: Rect2 = roof_rects[role]
			var tangent_width := rect.size.y if absf(Vector2(door["normal"]).x) > 0.5 else rect.size.x
			if role == "witch_shelter_roof" and tangent_width > 3.4:
				failures.append("%s separate entry hood spans %.2f m along the facade" % [label, tangent_width])
		if not roof_rects.has("witch_work_wing_roof"):
			failures.append("%s full Workshop has no single roof over the measured service wing" % label)
		else:
			var wing_roof_rect: Rect2 = roof_rects["witch_work_wing_roof"]
			var wing_width: float = wing_roof_rect.size.y \
				if absf(Vector2(door["normal"]).x) > 0.5 else wing_roof_rect.size.x
			if wing_width > 3.9:
				failures.append("%s measured work wing is too stretched along the facade (%.2f m)" % [label, wing_width])
		var wall_parts := 0
		for part in shelter["parts"]:
			if String(part.get("role", "")) != "witch_work_wing_wall":
				continue
			wall_parts += 1
		if wall_parts < 14:
			failures.append("%s enclosed service wing emitted only %d measured wall spans; expected two returns and a closed yard wall" % [label, wall_parts])
		var has_lintel := false
		for part in shelter["parts"]:
			if String(part.get("role", "")) == "witch_work_wing_header":
				has_lintel = true
		if not has_lintel:
			failures.append("%s yard-facing prep opening has no emitted bearing lintel" % label)
		# Collect emitted outward-depth intervals for each return. The inboard
		# return has a real body-width doorway aligned with the service approach.
		var side_intervals: Dictionary = {}
		var service_tangent := Vector2(-Vector2(door["normal"]).y, Vector2(door["normal"]).x)
		var service_out := Vector2(door["normal"])
		var service_origin := Vector2(door["pos"])
		var door_t := service_origin.dot(service_tangent)
		for part in shelter["parts"]:
			if String(part.get("role", "")) != "witch_work_wing_wall":
				continue
			var bounds: AABB = HouseYard.part_aabb(part)
			var center := Vector2(bounds.get_center().x, bounds.get_center().z)
			var normal_extent := bounds.size.x * absf(service_out.x) + bounds.size.z * absf(service_out.y)
			if normal_extent <= 0.14:
				continue # The continuous yard-facing wall is not an entry return.
			var tc := center.dot(service_tangent)
			var dc := center.dot(service_out)
			var side_key := str(snappedf(tc, 0.05))
			var side_intervals_list: Array = side_intervals.get(side_key, [])
			side_intervals_list.append(Vector2(dc - normal_extent * 0.5, dc + normal_extent * 0.5))
			side_intervals[side_key] = side_intervals_list
		var inner_key := ""
		var inner_distance := INF
		for candidate_key in side_intervals:
			var side_t := float(candidate_key)
			if absf(side_t - door_t) < inner_distance:
				inner_distance = absf(side_t - door_t)
				inner_key = String(candidate_key)
		var inner_t := float(inner_key)
		var inner_intervals: Array = side_intervals.get(inner_key, [])
		inner_intervals.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var largest_gap := 0.0
		var entry_center_d := 0.0
		for i in range(inner_intervals.size() - 1):
			var gap_width := Vector2(inner_intervals[i + 1]).x - Vector2(inner_intervals[i]).y
			if gap_width > largest_gap:
				largest_gap = gap_width
				entry_center_d = (Vector2(inner_intervals[i + 1]).x + Vector2(inner_intervals[i]).y) * 0.5
		var required_entry_width := HouseGeometry.PERSON_RADIUS * 2.0 + 0.18
		if largest_gap < required_entry_width:
			failures.append("%s inboard return lacks a measured body-width side entry (gap %.2f m)" % [label, largest_gap])
		else:
			# Move from the jamb into the measured work area, perpendicular to the
			# door approach. The target remains behind the actual return wall.
			var target := service_tangent * (inner_t + signf(inner_t - door_t) * 0.32) \
				+ service_out * entry_center_d
			if not _witch_wing_entry_reachable(plan, door, target):
				failures.append("%s body-width route from threshold to actual side entry is blocked" % label)
		if not _witch_wing_walls_bear_roof(shelter):
			failures.append("%s service-wing return/front wall tops do not bear on the emitted roof plane" % label)
		var broken_wing: Dictionary = shelter.duplicate(true)
		for part in broken_wing["parts"]:
			if String(part.get("role", "")) == "witch_work_wing_wall":
				var shortened: Vector3 = part["size"]
				shortened.y -= 0.1
				part["size"] = shortened
				break
		if _witch_wing_walls_bear_roof(broken_wing):
			failures.append("shortened wall negative control still passed roof-bearing contract")
	if threshold_roof.size != Vector3.ZERO \
				and threshold_roof.position.y < HouseGeometry.DOOR_H + 0.25 - 0.005:
		failures.append("%s shelter roof AABB enters the reserved door/window head zone (bottom %.3f m)" % [
			label, threshold_roof.position.y])
	var roles: Array[String] = []
	for prop in plan.yard:
		if String(prop.get("group", "")) == group:
			roles.append(String(prop.get("role", "")))
			var prop_reason := HouseYard.clear_reason(plan, HouseGeometry.yard_rect(plan),
				HouseExterior.bounds_of(prop))
			if not prop_reason.is_empty():
				failures.append("%s measured work prop %s violates the unchanged facade reservation: %s" % [
					label, String(prop.get("role", "?")), prop_reason])
	for role in ["witch_prep_bench", "witch_brewing_heat", "witch_cookware", "witch_water_vessel"]:
		if role not in roles:
			failures.append("%s threshold shelter lacks measured work role %s" % [label, role])
	var cookware_bounds := AABB()
	var water_bounds := AABB()
	for prop in plan.yard:
		if String(prop.get("group", "")) != group:
			continue
		match String(prop.get("role", "")):
			"witch_cookware":
				cookware_bounds = HouseExterior.bounds_of(prop)
			"witch_water_vessel":
				water_bounds = HouseExterior.bounds_of(prop)
	if cookware_bounds.size != Vector3.ZERO and water_bounds.size != Vector3.ZERO \
			and cookware_bounds.grow(HouseYard.GAP).intersects(water_bounds):
		failures.append("%s measured pot and bucket lack the required %.2f m separation" % [label, HouseYard.GAP])
	if not compact:
		var clearance: Dictionary = shelter.get("work_clearance", {})
		var prep_roof: Rect2 = clearance.get("prep_roof_rect", Rect2())
		var brew_roof: Rect2 = clearance.get("brew_roof_rect", Rect2())
		var prep_zone := Rect2()
		var brew_zone := Rect2()
		for prop in plan.yard:
			if String(prop.get("group", "")) != group:
				continue
			var zone: Rect2 = prop.get("operation_zone", Rect2())
			if String(prop.get("role", "")) == "witch_prep_bench":
				prep_zone = zone
				if not prep_roof.encloses(zone):
					failures.append("%s preparation awning does not cover the full measured standing zone" % label)
			if String(prop.get("role", "")) == "witch_brewing_heat":
				brew_zone = zone
				if not brew_roof.encloses(zone):
					failures.append("%s brewing awning does not cover the full measured tending zone" % label)
		if prep_zone.size != Vector2.ZERO and brew_zone.size != Vector2.ZERO \
				and prep_zone.grow(HouseYard.GAP).intersects(brew_zone):
			failures.append("%s prep and brew standing zones do not retain a measured gap" % label)
		var front_intervals: Array[Vector2] = []
		var wing_clearance: Dictionary = shelter.get("work_clearance", {})
		var wing_origin: Vector2 = wing_clearance.get("origin", Vector2.ZERO)
		var wing_out: Vector2 = wing_clearance.get("out", Vector2(1.0, 0.0))
		var wing_tangent: Vector2 = wing_clearance.get("tangent", Vector2(0.0, 1.0))
		var front_plane := wing_origin.dot(wing_out) \
			+ float(wing_clearance.get("gap", 0.0)) + float(wing_clearance.get("depth", 0.0)) - 0.06
		var batten_count := 0
		for part in shelter["parts"]:
			if String(part.get("role", "")) != "witch_work_wing_batten":
				continue
			batten_count += 1
			var batten_bounds: AABB = HouseYard.part_aabb(part)
			var batten_center := Vector2(batten_bounds.get_center().x, batten_bounds.get_center().z)
			if absf(batten_center.dot(wing_out) - front_plane) > 0.04:
				failures.append("%s shed batten left the emitted yard-facing wall plane" % label)
			var footprint := Rect2(Vector2(batten_bounds.position.x, batten_bounds.position.z),
				Vector2(batten_bounds.size.x, batten_bounds.size.z))
			if (prep_zone.has_area() and footprint.intersects(prep_zone)) \
					or (brew_zone.has_area() and footprint.intersects(brew_zone)):
				failures.append("%s shed batten intrudes into a measured work stance" % label)
		if batten_count < 1:
			failures.append("%s solid service panel emitted no board battens" % label)
		var vent_jambs: Array[Vector2] = []
		var vent_clear_y := Vector2(1.0, 1.3)
		for part in shelter["parts"]:
			if String(part.get("role", "")) != "witch_work_wing_vent_frame":
				continue
			var vent_bounds: AABB = HouseYard.part_aabb(part)
			var vent_center := Vector2(vent_bounds.get_center().x, vent_bounds.get_center().z)
			if absf(vent_center.dot(wing_out) - front_plane) > 0.05:
				failures.append("%s shed vent frame left the measured front wall plane" % label)
			if vent_bounds.size.y > 0.35:
				vent_jambs.append(Vector2(vent_center.dot(wing_tangent), vent_bounds.size.y))
		if vent_jambs.size() != 2:
			failures.append("%s shed front lacks two measured vent jambs" % label)
		else:
			vent_jambs.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
			var vent_width := vent_jambs[1].x - vent_jambs[0].x - 0.07
			if vent_width < 0.35 or vent_width > 0.50:
				failures.append("%s shed vent has unexpected emitted clear width %.2f m" % [label, vent_width])
			var vent_mid_t := (vent_jambs[0].x + vent_jambs[1].x) * 0.5
			for part in shelter["parts"]:
				if String(part.get("role", "")) != "witch_work_wing_wall":
					continue
				var wall_bounds: AABB = HouseYard.part_aabb(part)
				var wall_center := Vector2(wall_bounds.get_center().x, wall_bounds.get_center().z)
				var tangent_half := (wall_bounds.size.x * absf(wing_tangent.x) \
					+ wall_bounds.size.z * absf(wing_tangent.y)) * 0.5
				if absf(wall_center.dot(wing_out) - front_plane) <= 0.05 \
						and absf(wall_center.dot(wing_tangent) - vent_mid_t) < tangent_half \
						and wall_bounds.position.y < vent_clear_y.y \
						and wall_bounds.end.y > vent_clear_y.x:
					failures.append("%s nominal shed vent is filled by an emitted wall part" % label)
		for part in shelter["parts"]:
			if String(part.get("role", "")) != "witch_work_wing_wall":
				continue
			var bounds: AABB = HouseYard.part_aabb(part)
			var center := Vector2(bounds.get_center().x, bounds.get_center().z)
			if absf(center.dot(wing_out) - front_plane) > 0.04:
				continue
			var tangent_half := (bounds.size.x * absf(wing_tangent.x) \
				+ bounds.size.z * absf(wing_tangent.y)) * 0.5
			var tangent_center := center.dot(wing_tangent)
			front_intervals.append(Vector2(tangent_center - tangent_half, tangent_center + tangent_half))
		front_intervals.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var front_gap := 0.0
		var front_gap_center := 0.0
		for i in range(front_intervals.size() - 1):
			var gap_width := front_intervals[i + 1].x - front_intervals[i].y
			if gap_width > front_gap:
				front_gap = gap_width
				front_gap_center = (front_intervals[i + 1].x + front_intervals[i].y) * 0.5
		var prep_center_t := prep_zone.get_center().dot(wing_tangent)
		if front_gap < 1.0 \
				or absf(front_gap_center - prep_center_t) > 0.08:
			failures.append("%s yard-facing wall lacks a measured prep-aligned 1.02 m opening" % label)
		if prep_zone.size != Vector2.ZERO:
			var prep_nav := _witch_wing_zone_nav(plan, door, prep_zone)
			print("WITCH_ZONE_NAV %s role=prep cells=%d span=%s" % [label,
				int(prep_nav.get("cells", 0)), str(prep_nav.get("span", Vector2.ZERO))])
			if int(prep_nav.get("cells", 0)) < 4 \
					or Vector2(prep_nav.get("span", Vector2.ZERO)).x < 0.24 \
					or Vector2(prep_nav.get("span", Vector2.ZERO)).y < 0.24:
				failures.append("%s body-width route does not reach a 0.24 m square within actual prep zone" % label)
		if brew_zone.size != Vector2.ZERO:
			var brew_nav := _witch_wing_zone_nav(plan, door, brew_zone)
			print("WITCH_ZONE_NAV %s role=brew cells=%d span=%s" % [label,
				int(brew_nav.get("cells", 0)), str(brew_nav.get("span", Vector2.ZERO))])
			if int(brew_nav.get("cells", 0)) < 4 \
					or Vector2(brew_nav.get("span", Vector2.ZERO)).x < 0.24 \
				or Vector2(brew_nav.get("span", Vector2.ZERO)).y < 0.24:
				failures.append("%s body-width route does not reach a 0.24 m square within actual brew zone" % label)
	if not _near_service_group(plan, door, "herb_bed", 5.0):
		failures.append("%s has no herb bed within 5 m of the service threshold" % label)
	if not _near_service_group(plan, door, "drying_line", 5.0):
		failures.append("%s has no drying line within 5 m of the service threshold" % label)
	if not HouseYard.access_ok(plan):
		failures.append("%s work shelter/ingredients block a body-width route to the house" % label)

func _witch_wing_walls_bear_roof(shelter: Dictionary) -> bool:
	var clearance: Dictionary = shelter.get("work_clearance", {})
	if clearance.is_empty():
		return false
	var origin: Vector2 = clearance["origin"]
	var outward: Vector2 = clearance["out"]
	var tangent: Vector2 = clearance["tangent"]
	var cell := {"o": origin, "out": outward, "tan": tangent}
	var gap := float(clearance["gap"])
	var depth := float(clearance["depth"])
	var wall_y := float(clearance["wall_y"])
	var drop := float(clearance["drop"])
	var roof_thickness := float(clearance["roof_thickness"])
	var walls := 0
	for part in shelter.get("parts", []):
		var part_role := String(part.get("role", ""))
		if part_role != "witch_work_wing_wall" and part_role != "witch_work_wing_header":
			continue
		walls += 1
		var bounds: AABB = HouseYard.part_aabb(part)
		var center := Vector2(bounds.get_center().x, bounds.get_center().z)
		var normal_extent := bounds.size.x * absf(outward.x) + bounds.size.z * absf(outward.y)
		var sample_d := (center - origin).dot(outward)
		if normal_extent > 0.2:
			sample_d += normal_extent * 0.5
		var roof_bottom := HouseYard._witch_roof_under(cell, sample_d, gap, depth,
			wall_y, drop, roof_thickness)
		if absf(bounds.position.y + bounds.size.y - roof_bottom) > 0.025:
			return false
	return walls >= 14

func _witch_wing_entry_reachable(plan: HousePlan, door: Dictionary, target: Vector2) -> bool:
	return _witch_wing_reachable_rect(plan, door,
		Rect2(target - Vector2(0.18, 0.18), Vector2(0.36, 0.36)))

func _witch_wing_zone_nav(plan: HousePlan, door: Dictionary, zone: Rect2) -> Dictionary:
	# Measure the connected body-sized cells inside the real stance. A small
	# multi-cell span prevents a corner pixel from satisfying the route contract.
	var outward: Vector2 = Vector2(door["normal"])
	var start: Vector2 = Vector2(door["pos"]) + outward * (HouseGeometry.wall_thickness(plan.spec)
		+ HouseGeometry.PERSON_RADIUS + 0.05)
	var floor_rect := HouseGeometry.yard_rect(plan).grow(2.0)
	var grid := WalkGrid.new()
	grid.setup(floor_rect, HouseGeometry.NAV_CELL)
	grid.add_floor(floor_rect)
	for obstacle in HouseYard.obstacles(plan):
		grid.add_obstacle(obstacle)
	grid.build(HouseGeometry.PERSON_RADIUS)
	if not grid.flood_from(start):
		return {"cells": 0, "span": Vector2.ZERO}
	var count := 0
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for gx in range(grid.nx):
		for gz in range(grid.nz):
			var point := grid.origin + Vector2((float(gx) + 0.5) * grid.cell,
				(float(gz) + 0.5) * grid.cell)
			var index := gx * grid.nz + gz
			if zone.has_point(point) and grid._seen[index] == 1:
				count += 1
				min_x = minf(min_x, point.x)
				min_y = minf(min_y, point.y)
				max_x = maxf(max_x, point.x)
				max_y = maxf(max_y, point.y)
	if count == 0:
		return {"cells": 0, "span": Vector2.ZERO}
	return {"cells": count, "span": Vector2(max_x - min_x, max_y - min_y)}

func _witch_wing_reachable_rect(plan: HousePlan, door: Dictionary, target: Rect2) -> bool:
	var outward: Vector2 = Vector2(door["normal"])
	var start: Vector2 = Vector2(door["pos"]) + outward * (HouseGeometry.wall_thickness(plan.spec)
		+ HouseGeometry.PERSON_RADIUS + 0.05)
	var floor_rect := HouseGeometry.yard_rect(plan).grow(2.0)
	var grid := WalkGrid.new()
	grid.setup(floor_rect, HouseGeometry.NAV_CELL)
	grid.add_floor(floor_rect)
	for obstacle in HouseYard.obstacles(plan):
		grid.add_obstacle(obstacle)
	grid.build(HouseGeometry.PERSON_RADIUS)
	return grid.flood_from(start) and grid.reached(target)

func _near_service_group(plan: HousePlan, door: Dictionary, prefix: String, max_distance: float) -> bool:
	var point: Vector2 = door["pos"]
	for piece in plan.yard_pieces:
		var group := String(piece.get("group", ""))
		var role := String(piece.get("role", ""))
		if role != prefix and not group.begins_with(prefix + "#"):
			continue
		var rect := Rect2(piece.get("rect", Rect2()))
		if _point_rect_distance(point, rect) <= max_distance:
			return true
	for prop in plan.yard:
		var group := String(prop.get("group", ""))
		var role := String(prop.get("role", ""))
		if role != prefix and not group.begins_with(prefix + "#"):
			continue
		var bounds: AABB = HouseExterior.bounds_of(prop)
		var rect := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
		if _point_rect_distance(point, rect) <= max_distance:
			return true
	return false

func _point_rect_distance(point: Vector2, rect: Rect2) -> float:
	var closest := Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
	return point.distance_to(closest)

func _check_excluded_controls(size: Dictionary) -> void:
	for control in [{"style":&"cottage","trade":&"none"},{"style":&"witch_hut","trade":&"alchemist"}]:
		var spec := HouseSpec.new(8102)
		spec.style = control.style
		spec.trade = control.trade
		spec.width = float(size.width)
		spec.length = float(size.length)
		var plan := HouseGenerator.generate(spec, 8102, true)
		for piece in plan.yard_pieces:
			if String(piece.get("role", "")) == "witch_work_shelter":
				failures.append("%s/%s inherited the no-trade Witch threshold shelter" % [size.id, str(control.style)])
