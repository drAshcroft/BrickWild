class_name HotelQA
extends RefCounted
## Landmark rules derived from the supplied elevation, layered on the complete
## house plan/furnishing/navigation harness.


func check(plan: HousePlan, builder: HotelBuilder) -> Dictionary:
	var shared: Dictionary = HouseQA.new().check(plan, builder)
	var failures: Array[String] = shared["failures"].duplicate()
	var warnings: Array[String] = shared["warnings"].duplicate()
	var spec := plan.spec as HotelSpec
	if spec == null:
		failures.append("identity: hotel plan does not retain a HotelSpec")
		return {"ok": false, "failures": failures, "warnings": warnings,
			"stats": shared["stats"]}

	_check_proportions(spec, failures)
	_check_program(plan, failures)
	_check_landmarks(spec, builder, failures)
	_check_symmetry(builder, failures)
	var stats: Dictionary = shared["stats"].duplicate()
	stats["facade_bays"] = spec.facade_bays
	stats["dormers"] = _parts(builder, "dormer")
	stats["cupola_towers"] = _masses(builder, "cupola_tower")
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": warnings, "stats": stats}


static func _check_proportions(spec: HotelSpec, failures: Array[String]) -> void:
	if spec.width / spec.length < 1.55:
		failures.append("proportion: facade is not broad enough to read as a grand hotel")
	if spec.facade_bays < 11 or spec.facade_bays % 2 == 0:
		failures.append("proportion: facade needs an odd rhythm of at least 11 bays")
	if spec.centre_fraction < 0.28 or spec.centre_fraction > 0.4:
		failures.append("proportion: central pavilion is not subordinate to the wings")
	if spec.storeys != 3:
		failures.append("proportion: landmark plan must carry three walkable storeys")


static func _check_program(plan: HousePlan, failures: Array[String]) -> void:
	for kind in [&"lobby", &"dining_room", &"kitchen", &"lounge", &"guest_room",
			&"suite", &"gallery", &"laundry"]:
		if not plan.has_kind(kind):
			failures.append("programme: hotel has no %s" % String(kind))
	for category in ["counter", "bed", "table", "seat", "chandelier"]:
		var found := false
		for placement in plan.furniture:
			if PropCatalog.category(placement["key"]) == category:
				found = true
				break
		if not found:
			failures.append("programme: hotel has no %s fitting" % category)


static func _check_landmarks(spec: HotelSpec, builder: HotelBuilder,
		failures: Array[String]) -> void:
	if _masses(builder, "centre_pavilion") != 1:
		failures.append("landmark: expected one raised centre pavilion")
	if _masses(builder, "cupola_tower") != 2:
		failures.append("landmark: expected paired corner cupola towers")
	if _parts(builder, "ceremonial_entrance") < 5:
		failures.append("landmark: ceremonial entrance has too little framing")
	if _parts(builder, "balcony") < 20:
		failures.append("landmark: facade lacks the three balustraded balconies")
	if _parts(builder, "dormer") < maxi(4, spec.dormer_count - 3):
		failures.append("landmark: mansard roof has too few dormers")
	if builder.total_height < HotelGeometry.wall_top(spec) + spec.roof_rise:
		failures.append("landmark: roofline does not reach its planned crown")


static func _check_symmetry(builder: HotelBuilder, failures: Array[String]) -> void:
	var windows: Array[Vector3] = []
	for part in builder.part_log:
		if part["tag"] != "facade_window":
			continue
		var size: Vector3 = part["size"]
		if absf(size.x - HotelBuilder.WINDOW_W) < 0.01 \
				and absf(size.z - HotelBuilder.FACADE_D) < 0.01:
			windows.append(part["pos"])
	for pos in windows:
		var paired := false
		for other in windows:
			if absf(pos.x + other.x) < 0.02 and absf(pos.y - other.y) < 0.02:
				paired = true
				break
		if not paired:
			failures.append("symmetry: facade window at %v has no mirror" % pos)
			return


static func _parts(builder: HotelBuilder, wanted: String) -> int:
	var count := 0
	for part in builder.part_log:
		if part["tag"] == wanted:
			count += 1
	return count


static func _masses(builder: HotelBuilder, prefix: String) -> int:
	var count := 0
	for mass in builder.mass_log:
		if prefix in String(mass["name"]):
			count += 1
	return count
