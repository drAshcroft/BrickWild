extends SceneTree

func _init() -> void:
	var checks := 0
	var failures: Array[String] = []
	for seed_value in [0, 19, 731]:
		var request := BuildingRequest.temple(seed_value, &"ziggurat", &"blood", 24.0, 24.0, 16.0)
		var made := BrickWild.generate(request)
		var mesh := BrickWild.build_mesh(made)
		var placement := BrickWild.placement(made)
		var spec := made.spec as TempleSpec
		var footprint: Rect2 = placement.footprint
		var approach: Rect2 = placement.approach
		var door: Vector3 = placement.door
		checks += 4
		if not footprint.encloses(TempleGeometry.stair_rect(spec)):
			failures.append("stair footprint was truncated")
		if not is_equal_approx(door.z, TempleGeometry.site_rect(spec).position.y):
			failures.append("native portal was moved to the stair toe")
		if not is_equal_approx(approach.end.y, door.z) or approach.position.y >= footprint.position.y:
			failures.append("native approach does not join the full frontage to its portal")
		if not placement == BrickWild.measure(request):
			failures.append("measurement lost native temple arrival metadata")
		for stair in TempleGeometry.stair_rects(spec):
			checks += 1
			if stair.intersects(approach.grow(TempleGeometry.PERSON_RADIUS)):
				failures.append("arrival corridor runs through a solid summit flight")
		# Probe the complete actual centre passage at body height. Decorative
		# metadata cannot make a solid wall or misplaced flight transparent.
		checks += 1
		var middle := (approach.position.y + approach.end.y) * 0.5
		if not CastleQA._door_ray_clear(mesh, Vector3(0, 1.0, middle), Vector3.BACK,
			approach.size.y * 0.5):
			failures.append("emitted ground-level passage is blocked")
	# 40e2601 made the basilica publish its real pronaos approach. It must be a
	# genuine passage: on the axis, joined to the gate, reaching the ground
	# outside the pronaos floor, inside the reserved footprint, and open at body height.
	var plain_request := BuildingRequest.temple(4, &"basilica", &"blood", 24, 30, 12)
	var plain := BrickWild.generate(plain_request)
	var plain_spec := plain.spec as TempleSpec
	var plain_place := BrickWild.placement(plain)
	checks += 1
	if not plain_place.has("approach"):
		failures.append("basilica lost its published approach")
	else:
		var a: Rect2 = plain_place.approach
		var gate_z := TempleGeometry.site_rect(plain_spec).position.y
		var pdoor: Vector3 = plain_place.door
		checks += 6
		if not is_equal_approx(a.end.y, gate_z) or not is_equal_approx(a.end.y, pdoor.z):
			failures.append("basilica approach does not end at the gate")
		if absf(a.get_center().x) > 0.001 or absf(pdoor.x) > 0.001:
			failures.append("basilica approach is off the axis")
		if a.size.x < TempleGeometry.PERSON_RADIUS * 2.0 or a.size.x > TempleGeometry.GATE_W:
			failures.append("basilica approach is not a body-wide passage within the gate")
		if not plain_place.footprint.encloses(a):
			failures.append("basilica approach leaves the reserved footprint")
		if not is_equal_approx(a.position.y, TempleGeometry.basilica_portico_floor_rect(plain_spec).position.y):
			failures.append("basilica approach does not start at the pronaos outer edge")
		var plain_mesh := BrickWild.build_mesh(plain)
		if not CastleQA._door_ray_clear(plain_mesh, Vector3(0, 1.0, a.position.y + 0.05),
			Vector3.BACK, a.size.y - 0.1):
			failures.append("basilica approach is blocked at body height")
	for failure in failures: printerr(failure)
	print("TEMPLE STAIR PLACEMENT COMPLETE ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
