extends SceneTree

func _initialize() -> void:
	var spec := CastleSpec.new()
	spec.style = &"crusader"
	spec.width = 90.0
	spec.length = 140.0
	spec.height = 20.0
	CastleGenerator.generate(spec, 9118)
	var builder := CastleBuilder.new()
	builder.spec = spec
	builder.begin(4)
	for ring in CastleGeometry.rings(spec):
		builder._build_ring(ring)
	builder._build_wall_stairs()
	for tower in builder.mass_log:
		if not String(tower.name).begins_with("tower_1_gate_") and not String(tower.name).begins_with("tower_0_gate_"):
			continue
		print("GATE_TOWER ", tower.name, " aabb=", tower.aabb)
		for stair in builder.mass_log:
			if not String(stair.name).begins_with("wall_stair_"):
				continue
			var overlap: AABB = tower.aabb.intersection(stair.aabb)
			if overlap.size.x > 0.0 and overlap.size.z > 0.0:
				print("OVERLAP tower=", tower.name, " stair=", stair.name, " x=", overlap.size.x, " z=", overlap.size.z, " area=", overlap.size.x * overlap.size.z)
	for stair in builder.mass_log:
		if String(stair.name).begins_with("wall_stair_"):
			print("STAIR ", stair.name, " ring=", stair.get("ring"), " aabb=", stair.aabb)
	for stair in CastleGeometry.wall_stairs(spec):
		print("PLAN ring=", stair.ring, " at=", stair.at, " along=", stair.along, " inside=", stair.inside, " poly=", stair.poly)
	print("SPEC ring_count=", CastleGeometry.rings(spec).size(), " gates=", CastleGeometry.gate_tower_centers(spec, 1).size(), "stairs=", CastleGeometry.wall_stairs(spec).size())
	for ring in CastleGeometry.rings(spec):
		print("RING", ring, "gate=", CastleGeometry.gatehouse_aabb(spec, ring), "gate towers=", CastleGeometry.gate_tower_centers(spec, ring), "side towers=", CastleGeometry.side_tower_slots(spec, ring).map(func(s): return s.pos))
	quit()
