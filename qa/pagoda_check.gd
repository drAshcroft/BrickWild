class_name PagodaCheck
extends RefCounted
## Geometry, roof-profile and floor-route acceptance rules for WLD-009.

func check(plan: HousePlan, builder: PagodaBuilder) -> Dictionary:
	var failures: Array[String] = []
	var meta := plan.world_meta
	var tiers: Array = meta.get("eave_tiers", [])
	var storeys := int(meta.get("storey_count", plan.spec.storeys))
	_check_odd(storeys, failures)
	_check_taper(plan, tiers, builder, failures)
	_check_mast(plan, builder, failures)
	_check_plan(plan, failures)
	_check_slender(plan, failures)
	_check_crown(plan, builder, failures)
	_check_climb(plan, failures)
	_check_hidden_floors(plan, tiers, failures)
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": [], "stats": {"storeys": storeys, "sides": int(meta.get("side_count", 0)),
			"eave_tiers": tiers.size(), "stairs": plan.stairs.size()}}


func _check_odd(storeys: int, failures: Array[String]) -> void:
	if storeys < 3 or storeys > 15 or storeys % 2 == 0:
		failures.append("odd: pagodas require 3..15 odd storeys")


func _check_taper(plan: HousePlan, tiers: Array, builder: PagodaBuilder,
		failures: Array[String]) -> void:
	if tiers.is_empty():
		failures.append("taper: no eave tiers were planned")
		return
	var emitted: Array[Dictionary] = []
	for i in range(tiers.size()):
		var host_name := "eave_tier_%d" % i
		var min_x := INF
		var max_x := -INF
		var min_z := INF
		var max_z := -INF
		var top_height := -INF
		var edges := 0
		for component in builder.component_log:
			if String(component.get("host", "")) != host_name:
				continue
			edges += 1
			var size: Vector3 = component["size"]
			var xf: Transform3D = component["xf"]
			top_height = maxf(top_height, size.y)
			for x in [-size.x * 0.5, size.x * 0.5]:
				for z in [-size.z * 0.5, size.z * 0.5]:
					var p: Vector3 = xf * Vector3(x, 0.0, z)
					min_x = minf(min_x, p.x)
					max_x = maxf(max_x, p.x)
					min_z = minf(min_z, p.z)
					max_z = maxf(max_z, p.z)
		if edges != plan.outline_of(int(tiers[i].get("storey", i))).size():
			failures.append("taper: eave tier %d emitted %d of its polygon edges" % [i, edges])
		emitted.append({"width": maxf(max_x - min_x, max_z - min_z), "height": top_height})
	for i in range(1, tiers.size()):
		var previous: Dictionary = tiers[i - 1]
		var current: Dictionary = tiers[i]
		var ratio := float(current.get("width", 0.0)) / maxf(float(previous.get("width", 0.0)), 0.001)
		if ratio < 0.88 or ratio > 0.98:
			failures.append("taper: eave %d width ratio %.3f is outside 0.88..0.98" % [i, ratio])
		if float(current.get("height", INF)) > float(previous.get("height", -INF)) + 0.001:
			failures.append("taper: eave %d is taller than the tier below" % i)
		var actual_ratio := float(emitted[i]["width"]) / maxf(float(emitted[i - 1]["width"]), 0.001)
		if actual_ratio < 0.88 or actual_ratio > 0.98:
			failures.append("taper: emitted eave %d width ratio %.3f is outside 0.88..0.98" % [i, actual_ratio])
		if float(emitted[i]["height"]) > float(emitted[i - 1]["height"]) + 0.001:
			failures.append("taper: emitted eave %d is taller than the tier below" % i)


func _check_mast(plan: HousePlan, builder: PagodaBuilder, failures: Array[String]) -> void:
	var found := false
	for mass in builder.mass_log:
		if String(mass.get("name", "")) != "mast":
			continue
		var aabb: AABB = mass["aabb"]
		found = aabb.position.x <= 0.02 and aabb.end.x >= -0.02 \
			and aabb.position.z <= 0.02 and aabb.end.z >= -0.02
		if found:
			for level in range(int(plan.world_meta.get("storey_count", 0))):
				var y := float(level) * plan.spec.height
				if aabb.position.y > y + 0.02 or aabb.end.y < y + 0.02:
					found = false
					break
		break
	if not found:
		failures.append("mast: no emitted axial mast intersects every floor")


func _check_plan(plan: HousePlan, failures: Array[String]) -> void:
	var expected := int(plan.world_meta.get("side_count", 0))
	if expected not in [4, 8, 12] or plan.rooms.is_empty():
		failures.append("plan: pagoda requires a square, octagonal or 12-sided room")
		return
	for room in plan.rooms:
		var outline: PackedVector2Array = room.get("outline", PackedVector2Array())
		if outline.size() != expected:
			failures.append("plan: storey room has %d sides, expected %d" % [outline.size(), expected])
			return


func _check_slender(plan: HousePlan, failures: Array[String]) -> void:
	var base := float(plan.world_meta.get("base_width", 0.0))
	var total := float(plan.world_meta.get("total_height", 0.0))
	var ratio := total / maxf(base, 0.001)
	if ratio < 2.0 or ratio > 4.0:
		failures.append("slender: height/base %.2f is outside 2.0..4.0" % ratio)


func _check_crown(plan: HousePlan, builder: PagodaBuilder, failures: Array[String]) -> void:
	var finial_height := float(plan.world_meta.get("finial_height", 0.0))
	var total := float(plan.world_meta.get("total_height", 0.0))
	var ratio := finial_height / maxf(total, 0.001)
	if ratio < 0.1 or ratio > 0.2:
		failures.append("crown: finial height ratio %.3f is outside 0.10..0.20" % ratio)
	var crown_found := false
	var top := -INF
	for mass in builder.mass_log:
		var name := String(mass.get("name", ""))
		if name == "finial":
			crown_found = true
			var aabb: AABB = mass["aabb"]
			top = aabb.end.y
	if not crown_found or absf(top - total) > 0.02:
		failures.append("crown: emitted finial is absent or not the topmost mass")


func _check_climb(plan: HousePlan, failures: Array[String]) -> void:
	var count := int(plan.world_meta.get("storey_count", plan.spec.storeys))
	var rooms_by_level: Array[int] = []
	for level in range(count):
		var found := -1
		for room in range(plan.room_count()):
			if plan.storey_of_room(room) == level:
				found = room
				break
		rooms_by_level.append(found)
		if found < 0:
			failures.append("climb: storey %d has no standable landing" % level)
	for level in range(count - 1):
		var joined := false
		for stair in plan.stairs:
			if int(stair.get("storey", -1)) == level and int(stair.get("to_storey", -1)) == level + 1 \
					and int(stair.get("a", -1)) == rooms_by_level[level] \
					and int(stair.get("b", -1)) == rooms_by_level[level + 1]:
				var rect: Rect2 = stair.get("lower_rect", Rect2())
				var upper_rect: Rect2 = stair.get("upper_rect", Rect2())
				if rect.size.x < 1.2 or rect.size.y < 1.2:
					break
				var outline := plan.outline_of(rooms_by_level[level])
				var upper_outline := plan.outline_of(rooms_by_level[level + 1])
				if not _rect_inside(rect, outline) or not _rect_inside(upper_rect, upper_outline):
					break
				joined = true
				break
		if not joined:
			failures.append("climb: no standable stair chain joins storeys %d and %d" % [level, level + 1])


func _rect_inside(rect: Rect2, outline: PackedVector2Array) -> bool:
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]:
		if not Poly.contains_point(outline, corner, 0.02):
			return false
	return true


func _check_hidden_floors(plan: HousePlan, tiers: Array, failures: Array[String]) -> void:
	if tiers.is_empty():
		failures.append("hidden_floors: no eave tier covers the interior storeys")
		return
	var storeys := maxi(1, int(plan.world_meta.get("storey_count", plan.spec.storeys)))
	for room_id in range(plan.room_count()):
		var level := plan.storey_of_room(room_id)
		if level < 0 or level >= storeys:
			failures.append("hidden_floors: room %d is assigned to invalid storey %d" % [room_id, level])
			continue
		# Several occupied floors may sit beneath one visible eave. Assign each
		# floor to the next tier above it, then prove the complete clear-floor
		# bounds fit under that tier's emitted width.
		var tier_index := mini(tiers.size() - 1,
			ceili(float(level + 1) * float(tiers.size()) / float(storeys)) - 1)
		var room_bounds := Poly.bounding_rect(plan.outline_of(room_id))
		var tier: Dictionary = tiers[tier_index]
		if maxf(room_bounds.size.x, room_bounds.size.y) > float(tier.get("width", 0.0)) + 0.02:
			failures.append("hidden_floors: room %d projects beyond eave tier %d" % [room_id, tier_index])
