extends SceneTree
## Staged focused contract. Root must run after reviewing the proposal.
## Checks the compact threshold against a real assembled mesh and includes an
## independent missing-ledger negative; no screenshot or role count is proof.

const SEEDS := [1, 8102, 21325]
var failures: Array[String] = []

func _init() -> void:
	for seed_value in SEEDS:
		_check_compact_case(seed_value)
	for failure in failures:
		printerr("FAIL " + failure)
	print("compact Witch threshold mesh fixture: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_compact_case(seed_value: int) -> void:
	var spec := HouseSpec.new(seed_value)
	spec.style = &"witch_hut"
	spec.trade = &"none"
	spec.width = 7.0
	spec.length = 9.0
	spec.height = 2.6
	spec.storeys = 1
	spec.cellars = 0
	spec.room_count = 3
	var plan := HouseGenerator.generate(spec, seed_value, true)
	var label := "seed=%d" % seed_value
	var plan_report := HousePlanCheck.new().check(plan)
	if not Array(plan_report.get("failures", [])).is_empty():
		failures.append("%s lost a plan, window or daylight contract: %s" % [label,
			str(plan_report.get("failures", []))])
	var service_door: Dictionary = {}
	for door in plan.doors:
		if bool(door.get("witch_workshop_yard", false)):
			service_door = door
			break
	if service_door.is_empty() or not bool(service_door.get("witch_compact_service_threshold", false)):
		failures.append("%s compact shared Hall has no marked yard threshold" % label)
		return
	var room := int(service_door.get("a", -1))
	var functions: Array = plan.rooms[room].get("domestic_functions", []) if room >= 0 and room < plan.rooms.size() else []
	if room < 0 or plan.kind_of(room) != &"hall" or not bool(plan.rooms[room].get("shared_witchwork", false)) \
			or not functions.has(&"cooking") or not functions.has(&"witchwork"):
		failures.append("%s service threshold is not in the actual shared cooking/Witchwork Hall" % label)
	if room >= 0 and room < plan.rooms.size():
		var regions: Dictionary = plan.rooms[room].get("activity_regions", {})
		var floor := HouseGeometry.room_floor_rect(plan, room)
		if not regions.has(&"cooking") or not regions.has(&"witchwork") or not regions.has(&"eating"):
			failures.append("%s compact Hall lost a cooking, Witchwork or meal region" % label)
		elif Rect2(regions[&"cooking"]) != Rect2(regions[&"witchwork"]) \
				or not floor.encloses(Rect2(regions[&"cooking"])) \
				or not floor.encloses(Rect2(regions[&"eating"])) \
				or Rect2(regions[&"cooking"]).intersects(Rect2(regions[&"eating"])):
			failures.append("%s compact cooking/Witchwork and meal footprints overlap or escape the Hall floor" % label)
		var hall_rect: Rect2 = plan.rooms[room]["rect"]
		var margin := HouseGeometry.DOOR_CORNER_MARGIN + float(service_door.get("width", 0.0)) * 0.5
		if absf(float(service_door["pos"].y) - (hall_rect.position.y + margin + 0.58)) > 0.02:
			failures.append("%s service threshold is not aligned to the Hall's front workyard end" % label)
		for target_room in [room] + plan.rooms_of(&"bedroom"):
			var glazing := 0.0
			for window_index in plan.windows_of(target_room):
				var window: Dictionary = plan.windows[window_index]
				glazing += HouseGeometry.window_area(window)
				if Vector2(window.get("normal", Vector2.ZERO)) == Vector2(service_door["normal"]):
					failures.append("%s Hall/bedroom service-side window was not relocated clear of the canopy" % label)
			var target_floor := HouseGeometry.room_floor_rect(plan, target_room)
			if glazing < target_floor.get_area() * HouseGeometry.GLAZING_MIN - 0.01:
				failures.append("%s Hall or bedroom glazing fell below the measured daylight minimum" % label)
	var shelter: Dictionary = {}
	for piece in plan.yard_pieces:
		if String(piece.get("role", "")) == "witch_work_shelter":
			shelter = piece
			break
	if shelter.is_empty():
		failures.append("%s compact service threshold has no attached work canopy" % label)
		return
	var shelter_rect: Rect2 = Rect2(shelter.get("rect", Rect2()))
	if maxf(shelter_rect.size.x, shelter_rect.size.y) > 7.2:
		failures.append("%s compact threshold expanded into a %.2f m canopy row" % [
			label, maxf(shelter_rect.size.x, shelter_rect.size.y)])
	var required_roles := ["witch_prep_bench", "witch_brewing_heat", "witch_cookware", "witch_water_vessel"]
	var found_roles: Array[String] = []
	var operation_zones: Array[Rect2] = []
	for prop in plan.yard:
		if String(prop.get("group", "")) != String(shelter.get("group", "")):
			continue
		found_roles.append(String(prop.get("role", "")))
		var zone: Rect2 = Rect2(prop.get("operation_zone", Rect2()))
		if String(prop.get("role", "")) in ["witch_prep_bench", "witch_brewing_heat"]:
			if not zone.has_area():
				failures.append("%s lost a measured prep or cauldron operation zone" % label)
			else:
				operation_zones.append(zone)
	if found_roles.size() != required_roles.size():
		failures.append("%s compact canopy has %d of four required measured work props" % [label, found_roles.size()])
	for role in required_roles:
		if not found_roles.has(role):
			failures.append("%s compact canopy is missing measured role %s" % [label, role])
	# Exterior openings are planned on the inner wall face. Advance one full
	# wall thickness to the outer face, then add the body's radius and margin.
	var approach: Vector2 = Vector2(service_door["pos"]) + Vector2(service_door["normal"]) * \
		(HouseGeometry.wall_thickness(plan.spec) + HouseGeometry.PERSON_RADIUS + 0.05)
	var covered: Rect2 = Rect2(shelter.get("rect", Rect2())).grow(0.05)
	if not covered.has_point(approach):
		failures.append("%s exterior body threshold is outside measured canopy footprint" % label)
	var door_lane_box := HouseExterior._opening_box(service_door["pos"], service_door["normal"],
		float(service_door["width"]) + 1.1, -0.1, HouseGeometry.DOOR_H + 0.25, 3.2,
		HouseGeometry.wall_thickness(plan.spec))
	var door_lane := Rect2(Vector2(door_lane_box.position.x, door_lane_box.position.z),
		Vector2(door_lane_box.size.x, door_lane_box.size.z))
	for zone in operation_zones:
		if zone.intersects(door_lane):
			failures.append("%s measured work stance overlaps the full body-width door approach" % label)
	var moved_door: Dictionary = service_door.duplicate(true)
	var tangent := Vector2(-Vector2(service_door["normal"]).y, Vector2(service_door["normal"]).x)
	var beyond_roof := maxf(shelter_rect.size.x, shelter_rect.size.y) + 1.0
	moved_door["pos"] = Vector2(service_door["pos"]) + tangent * beyond_roof
	if HouseYard._witch_shelter_covers_threshold(shelter, moved_door, plan.spec):
		failures.append("%s moved exterior body threshold remained covered by the same shelter" % label)
	if not HouseYard.access_ok(plan):
		failures.append("%s canopy or yard groups block access to an exterior door" % label)
	var builder := HouseBuilder.new()
	var mesh: ArrayMesh = builder.build(plan, true)
	var parity := ComponentCheck.check(builder, mesh)
	if not bool(parity.get("ok", false)):
		failures.append("%s component log differs from the assembled mesh: %s" % [label, str(parity.get("failures", []))])
		return
	var ledger_index := -1
	for index in range(builder.component_log.size()):
		var row: Dictionary = builder.component_log[index]
		if String(row.get("role", "")) == "witch_shelter_ledger" \
				and String(row.get("piece", "")) == String(shelter.get("id", "")):
			ledger_index = index
			break
	if ledger_index < 0:
		failures.append("%s emitted canopy has no wall-bearing ledger component" % label)
		return
	var roof_vertices: PackedVector3Array = mesh.surface_get_arrays(HouseBuilder.SURF_ROOF)[Mesh.ARRAY_VERTEX]
	var wall_vertices: PackedVector3Array = mesh.surface_get_arrays(HouseBuilder.SURF_WALL)[Mesh.ARRAY_VERTEX]
	var emitted_ledger: Dictionary = builder.component_log[ledger_index]
	var clearance: Dictionary = shelter.get("work_clearance", {})
	var shelter_roof: Dictionary = {}
	for row in builder.component_log:
		if String(row.get("piece", "")) == String(shelter.get("id", "")) \
				and String(row.get("role", "")) == "witch_shelter_roof":
			shelter_roof = row
			break
	if shelter_roof.is_empty():
		failures.append("%s emitted shelter has no roof geometry for body-height check" % label)
	else:
		var canopy_kit := MeshKit.new(1)
		canopy_kit.oriented_box(shelter_roof["size"], shelter_roof["xf"], 0)
		var canopy_mesh: ArrayMesh = canopy_kit.commit()
		var canopy_vertices: PackedVector3Array = canopy_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var heights := _mesh_heights_at(canopy_vertices, approach)
		if heights.is_empty() or heights.min() < HouseYard.HEAD:
			failures.append("%s measured canopy does not give a 1.7 m body clearance at exterior threshold" % label)
	if not _ledger_touches_wall_and_roof(emitted_ledger, roof_vertices, wall_vertices, clearance):
		failures.append("%s emitted service ledger does not physically meet wall and canopy roof" % label)
	var detached: Dictionary = emitted_ledger.duplicate(true)
	var detached_xf: Transform3D = detached["xf"]
	var out: Vector2 = Vector2(clearance.get("out", Vector2.RIGHT))
	detached_xf.origin += Vector3(out.x, 0.0, out.y) * 0.03
	detached["xf"] = detached_xf
	if _ledger_touches_wall_and_roof(detached, roof_vertices, wall_vertices, clearance):
		failures.append("%s 30 mm detached service ledger passed physical wall/roof contact" % label)

func _ledger_touches_wall_and_roof(ledger: Dictionary, roof: PackedVector3Array,
		wall: PackedVector3Array, clearance: Dictionary) -> bool:
	if ledger.is_empty() or roof.is_empty() or wall.is_empty() \
			or not clearance.has("out") or not clearance.has("tangent"):
		return false
	var xf: Transform3D = ledger["xf"]
	var size: Vector3 = ledger["size"]
	var centre: Vector3 = xf * Vector3.ZERO
	var outward: Vector2 = clearance["out"]
	var tangent: Vector2 = clearance["tangent"]
	var top: float = centre.y + size.y * 0.5
	for tangent_offset in [-0.35, 0.0, 0.35]:
		var tangent3 := Vector3(tangent.x, 0.0, tangent.y) * float(tangent_offset)
		var inner := centre - Vector3(outward.x, 0.0, outward.y) * 0.06 + tangent3
		if _point_mesh_distance(inner, wall) > 0.005:
			return false
		var outer := Vector3(centre.x, top, centre.z) \
			+ Vector3(outward.x, 0.0, outward.y) * 0.06 + tangent3
		var heights := _mesh_heights_at(roof, Vector2(outer.x, outer.z))
		if heights.is_empty() or absf(top - heights.min()) > 0.005:
			return false
	return true

func _mesh_heights_at(vertices: PackedVector3Array, point: Vector2) -> Array[float]:
	var heights: Array[float] = []
	if vertices.size() % 3 != 0:
		return heights
	for index in range(0, vertices.size(), 3):
		var a: Vector3 = vertices[index]
		var b: Vector3 = vertices[index + 1]
		var c: Vector3 = vertices[index + 2]
		var u := Vector2(b.x - a.x, b.z - a.z)
		var v := Vector2(c.x - a.x, c.z - a.z)
		var q := point - Vector2(a.x, a.z)
		var determinant := u.cross(v)
		if absf(determinant) < 0.000001:
			continue
		var first := q.cross(v) / determinant
		var second := u.cross(q) / determinant
		if first >= -0.0001 and second >= -0.0001 and first + second <= 1.0001:
			heights.append(a.y + first * (b.y - a.y) + second * (c.y - a.y))
	return heights

func _point_mesh_distance(point: Vector3, vertices: PackedVector3Array) -> float:
	var best := INF
	for index in range(0, vertices.size(), 3):
		var a: Vector3 = vertices[index]
		var b: Vector3 = vertices[index + 1]
		var c: Vector3 = vertices[index + 2]
		var ab := b - a
		var ac := c - a
		var normal := ab.cross(ac)
		if normal.length_squared() < 0.0000001:
			continue
		normal = normal.normalized()
		var projected := point - normal * (point - a).dot(normal)
		var d00 := ac.dot(ac)
		var d01 := ac.dot(ab)
		var d11 := ab.dot(ab)
		var d20 := (projected - a).dot(ac)
		var d21 := (projected - a).dot(ab)
		var denom := d00 * d11 - d01 * d01
		if absf(denom) > 0.0000001:
			var u := (d11 * d20 - d01 * d21) / denom
			var v := (d00 * d21 - d01 * d20) / denom
			if u >= -0.0001 and v >= -0.0001 and u + v <= 1.0001:
				best = minf(best, absf((point - a).dot(normal)))
		best = minf(best, _point_segment_distance(point, a, b))
		best = minf(best, _point_segment_distance(point, b, c))
		best = minf(best, _point_segment_distance(point, c, a))
	return best

func _point_segment_distance(point: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	if ab.length_squared() < 0.0000001:
		return point.distance_to(a)
	var fraction := clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return point.distance_to(a + ab * fraction)
