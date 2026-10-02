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
	var plain := BrickWild.generate(BuildingRequest.temple(4, &"basilica", &"blood", 24, 30, 12))
	checks += 1
	if BrickWild.placement(plain).has("approach"):
		failures.append("ordinary basilica acquired a fabricated approach")
	for failure in failures: printerr(failure)
	print("TEMPLE STAIR PLACEMENT COMPLETE ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
