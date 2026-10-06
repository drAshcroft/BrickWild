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
	_check_gallery(plan, spec, failures)
	_check_landmarks(spec, builder, failures)
	_check_balconies(plan, builder, failures)
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


## The corridor plan (LAY-008): every level has exactly one gallery running
## at least nine tenths of the building's length and wide enough to pass in;
## every guest room and suite has exactly one door and it opens onto the
## gallery or the lobby; the rooms on the two sides of the gallery are within
## one of each other and follow the facade's bays rather than a constant.
static func _check_gallery(plan: HousePlan, spec: HotelSpec, failures: Array[String]) -> void:
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	for storey in range(spec.storeys):
		var galleries: Array[int] = []
		for i in plan.rooms_on_storey(storey):
			if plan.kind_of(i) == &"gallery":
				galleries.append(i)
		if galleries.size() != 1:
			failures.append("gallery: storey %d has %d galleries, wants one" % [storey, galleries.size()])
			continue
		var g: Rect2 = plan.rooms[galleries[0]]["rect"]
		if g.size.x < inner.size.x * 0.9:
			failures.append("gallery: storey %d gallery runs %.1fm of a %.1fm building" % [storey, g.size.x, inner.size.x])
		if g.size.y < 1.5:
			failures.append("gallery: storey %d gallery is only %.2fm wide" % [storey, g.size.y])
		var front := 0
		var back := 0
		for i in plan.rooms_on_storey(storey):
			if i == galleries[0]:
				continue
			var r: Rect2 = plan.rooms[i]["rect"]
			if r.end.y <= g.position.y + 0.01:
				front += 1
			elif r.position.y >= g.end.y - 0.01:
				back += 1
		if storey > 0 and absi(front - back) > 1:
			failures.append("bays: storey %d has %d rooms in front of the gallery and %d behind" % [storey, front, back])
		if storey > 0 and maxi(front, back) != HotelPlanner.rooms_per_side(spec):
			failures.append("bays: storey %d has %d rooms a side for %d facade bays" % [storey, maxi(front, back), spec.facade_bays])
	for i in range(plan.room_count()):
		if not plan.kind_of(i) in [&"guest_room", &"suite"]:
			continue
		var doors: Array[int] = plan.doors_of(i)
		if doors.size() != 1:
			failures.append("gallery: room %d (%s) has %d doors, wants one" % [i, String(plan.kind_of(i)), doors.size()])
			continue
		var d: Dictionary = plan.doors[doors[0]]
		var other: int = int(d["b"]) if int(d["a"]) == i else int(d["a"])
		var onto: String = String(plan.kind_of(other)) if other >= 0 else "the street"
		if other < 0 or not plan.kind_of(other) in [&"gallery", &"lobby"]:
			failures.append("gallery: room %d (%s) opens onto %s, not the gallery"
				% [i, String(plan.kind_of(i)), onto])


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


## A balcony is a door's: each balcony slab stands at its storey's floor in
## front of a french window, and each french window has its balcony. The
## walk-through found three balconies at sill height with no door behind them
## and off the window grid (WALK-QA, 6 Oct, hotel pins 2 and 3).
static func _check_balconies(plan: HousePlan, builder: HotelBuilder,
		failures: Array[String]) -> void:
	var slabs: Array[Vector3] = []   # x, top, front-wall contact
	for part in builder.part_log:
		var size: Vector3 = part.get("size", Vector3.ZERO)
		if part["tag"] == "balcony" and size.x > 1.0 and size.z > 0.5:
			var p: Vector3 = part["pos"]
			slabs.append(Vector3(p.x, p.y + size.y * 0.5, p.z + size.z * 0.5))
	var wall_z := HotelGeometry.wall_face_z(plan.spec as HotelSpec)
	var balconies := {}
	for wi in range(plan.windows.size()):
		var w: Dictionary = plan.windows[wi]
		if not bool(w.get("balcony", false)):
			continue
		var x: float = Vector2(w["pos"]).x
		var centre: float = float(w.get("balcony_x", x))
		balconies[snappedf(centre, 0.01)] = true
		var floor_top := HousePlan.record_storey(w) * plan.spec.height + HouseGeometry.FLOOR_T
		var found := false
		for s in slabs:
			# the slab is centred on its balcony and wide enough for this window
			var part_w := 0.0
			for part in builder.part_log:
				if part["tag"] == "balcony" and absf(Vector3(part["pos"]).x - s.x) < 0.001 \
						and Vector3(part["size"]).x > 1.0:
					part_w = Vector3(part["size"]).x
			if absf(s.x - centre) < 0.05 and absf(s.y - floor_top) < 0.03 \
					and s.z >= wall_z - 0.001 and absf(x - s.x) + 0.5 < part_w * 0.5:
				found = true
		if not found:
			failures.append("balcony: french window %d has no balcony at its floor in front of it" % wi)
		if float(w["sill"]) > HouseGeometry.FLOOR_T + 0.05:
			failures.append("balcony: window %d opens onto a balcony but is not let down to the floor" % wi)
	for s in slabs:
		var found := false
		for w in plan.windows:
			if bool(w.get("balcony", false)) \
					and absf(s.x - float(w.get("balcony_x", Vector2(w["pos"]).x))) < 0.05:
				found = true
		if not found:
			failures.append("balcony: the balcony at x=%.2f has no french window behind it" % s.x)
	if balconies.size() != 3:
		failures.append("balcony: %d balconies with french windows, wants 3" % balconies.size())


static func _check_symmetry(builder: HotelBuilder, failures: Array[String]) -> void:
	var windows: Array[Vector3] = []
	for part in builder.part_log:
		if part["kind"] != "window" or part.get("opening_kind", "") != "window":
			continue
		var pos: Vector3 = part["pos"]
		# Ground-floor public rooms have their own programme. Guest floors
		# retain the bilateral rhythm; inspect real openings, not painted panes.
		if Vector3(part["facing"]).z < -0.9 and pos.y > builder.spec.height:
			windows.append(pos)
	if windows.is_empty():
		failures.append("symmetry: no real guest-floor facade windows")
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
