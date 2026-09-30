class_name CastleWaterSuite
extends RefCounted
## Focused CAS-008 fixtures for negative moat cuts and the gate-axis crossing.

static func run() -> SuiteResult:
	var res := SuiteResult.new("castle water")
	for row in [
		{"key": "bodiam", "scale": 0.4, "rings": 1},
		{"key": "bodiam", "scale": 1.0, "rings": 1},
		{"key": "bodiam", "scale": 1.5, "rings": 1},
		{"key": "caerphilly", "scale": 1.0, "rings": 2},
		{"key": "eilean_donan", "scale": 1.0, "rings": 1},
	]:
		var lm: Dictionary = CastleLandmarkSuite.LANDMARKS.filter(
			func(item: Dictionary) -> bool: return item.key == row.key)[0]
		var spec := CastleSpec.new()
		spec.style = lm.style
		spec.tier_override = lm.tier
		spec.width = float(lm.width) * float(row.scale)
		spec.length = float(lm.length) * float(row.scale)
		spec.height = float(lm.height) * float(row.scale)
		CastleGenerator.generate(spec, int(CastleLandmarkSuite._seed_for(row.key, row.scale)))
		CastleLandmarkSuite._force_features(row.key, spec)
		var builder := CastleBuilder.new()
		var mesh := builder.build(spec)
		var who := "%s x%.1f" % [row.key, float(row.scale)]
		res.checked += 1
		CastleLandmarkSuite._assert_water_plan(spec, builder, who, res, int(row.rings))
		var structural := CastleMassingCheck.new().check(spec, builder)
		for failure in structural.failures:
			res.fail("%s massing: %s" % [who, failure])
		var bridge := CastleGeometry.drawbridge_aabb(spec)
		for failure in CastleQA.gate_access_report(spec, builder, mesh).failures:
			res.fail("%s crossing: %s" % [who, failure])
		if bridge.size.z <= 0.0:
			res.fail("%s has no bridge span" % who)
		var negative_bounds: Array[AABB] = []
		for mass in builder.mass_log:
			if String(mass.name).begins_with("moat_"):
				negative_bounds.append(mass.aabb)
		if negative_bounds.is_empty():
			res.fail("%s has no negative trench bounds for the crossing probe" % who)
			continue
		var grid := VoxelGrid.new()
		grid.rasterize(mesh, [CastleBuilder.SURF_OPEN, CastleBuilder.SURF_WATER], 0.5,
			negative_bounds)
		if mesh.get_surface_count() <= CastleBuilder.SURF_WATER:
			res.fail("%s has no emitted water sheet surface" % who)
		elif (mesh.surface_get_arrays(CastleBuilder.SURF_WATER)[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
			res.fail("%s water surface has no emitted triangles" % who)
		var causeway: AABB = CastleGeometry.causeway_aabb(spec)
		if causeway.size.z > 0.5 and not grid.at_world(Vector3(causeway.get_center().x,
				0.1, causeway.get_center().z)):
			res.fail("%s causeway has no emitted solid at its center" % who)
		# Sample a known front-axis trench where it crosses the causeway; for a
		# nested moat, the inner bank may cross only the drawbridge deck.
		var crossing_trench := AABB()
		var has_crossing_trench := false
		var crossing_point := Vector2.ZERO
		var crossing_deck := "causeway"
		var decks := [causeway, bridge]
		for mass in builder.mass_log:
			if not String(mass.name).begins_with("moat_") \
					or not String(mass.name).ends_with("front_axis"):
				continue
			var trench_aabb: AABB = mass.aabb
			var trench_plan := Rect2(trench_aabb.position.x, trench_aabb.position.z,
				trench_aabb.size.x, trench_aabb.size.z)
			for deck_index in decks.size():
				var deck: AABB = decks[deck_index]
				var deck_plan := Rect2(deck.position.x, deck.position.z, deck.size.x, deck.size.z)
				var intersection := trench_plan.intersection(deck_plan)
				if intersection.size.x > 0.01 and intersection.size.y > 0.01:
					crossing_trench = trench_aabb
					has_crossing_trench = true
					crossing_point = intersection.get_center()
					crossing_deck = "causeway" if deck_index == 0 else "drawbridge"
					if deck_index == 0:
						break
			if has_crossing_trench and crossing_deck == "causeway":
				break
		if not has_crossing_trench:
			res.fail("%s has no front-axis trench intersection beneath the causeway or bridge" % who)
		else:
			var under_road := Vector3(crossing_point.x,
				-crossing_trench.size.y * 0.75, crossing_point.y)
			if under_road.y <= crossing_trench.position.y or under_road.y >= crossing_trench.end.y:
				res.fail("%s %s void probe is not strictly inside its front-axis trench" % [who, crossing_deck])
			else:
				var under_cell := Vector3i(grid.vx(under_road.x), grid.vy(under_road.y), grid.vz(under_road.z))
				var under_outside := under_road.x < grid.origin.x or under_road.x >= grid.origin.x + grid.nx * grid.vox \
					or under_road.y < grid.origin.y or under_road.y >= grid.origin.y + grid.ny * grid.vox \
					or under_road.z < grid.origin.z or under_road.z >= grid.origin.z + grid.nz * grid.vox
				if under_outside:
					res.fail("%s below-%s trench probe fell outside voxel bounds" % [who, crossing_deck])
				elif grid.get_voxel(under_cell.x, under_cell.y, under_cell.z):
					res.fail("%s below-%s trench is not a voxel void at %s" % [who, crossing_deck, under_road])
		var moat: Dictionary = builder.mass_log.filter(
			func(mass: Dictionary) -> bool: return String(mass.name).begins_with("moat_"))[0]
		var trench: AABB = moat.aabb
		var water_probe := Vector3(trench.get_center().x, -0.25, trench.get_center().z)
		var water_cell := Vector3i(grid.vx(water_probe.x), grid.vy(water_probe.y), grid.vz(water_probe.z))
		var outside := water_probe.x < grid.origin.x or water_probe.x >= grid.origin.x + grid.nx * grid.vox \
			or water_probe.y < grid.origin.y or water_probe.y >= grid.origin.y + grid.ny * grid.vox \
			or water_probe.z < grid.origin.z or water_probe.z >= grid.origin.z + grid.nz * grid.vox
		if outside or water_cell.x < 0 or water_cell.x >= grid.nx or water_cell.y < 0 or water_cell.y >= grid.ny \
				or water_cell.z < 0 or water_cell.z >= grid.nz:
			res.fail("%s water probe fell outside voxel bounds" % who)
		elif grid.get_voxel(water_cell.x, water_cell.y, water_cell.z):
			res.fail("%s emitted solid voxels in moat %s at %s (cell %s)" % [who, moat.name, water_probe, water_cell])
		if is_equal_approx(float(row.scale), 0.4) and row.key == "bodiam":
			var water_masses: Array = builder.mass_log.filter(
				func(mass: Dictionary) -> bool: return String(mass.name).begins_with("moat_"))
			var reduced: Array = water_masses.duplicate()
			for index in range(reduced.size()):
				if String(reduced[index].name).ends_with("front_right"):
					reduced.remove_at(index)
					break
			if CastleLandmarkSuite._water_ring_valid(spec, reduced, 0):
				res.fail("removing the front-right moat bank escaped all-sides control")
			else:
				res.checked += 1
			var no_under_road: Array = water_masses.duplicate()
			for index_axis in range(no_under_road.size()):
				if String(no_under_road[index_axis].name) == "moat_0_front_axis":
					no_under_road.remove_at(index_axis)
					break
			if CastleLandmarkSuite._water_ring_valid(spec, no_under_road, 0):
				res.fail("removing the below-causeway front trench escaped its continuity control")
			else:
				res.checked += 1
			var displaced: Array = water_masses.duplicate(true)
			for index2 in range(displaced.size()):
				if String(displaced[index2].name) == "moat_0_front_left":
					var moved: AABB = displaced[index2].aabb
					moved.position.x += 5.0
					displaced[index2].aabb = moved
					break
			if CastleLandmarkSuite._water_ring_valid(spec, displaced, 0):
				res.fail("misplacing the front-left moat bank escaped side/gate-axis control")
			else:
				res.checked += 1
			_negative_overlap_control(res, moat)
	return res


static func _negative_overlap_control(res: SuiteResult, moat: Dictionary) -> void:
	var negative: Array[Dictionary] = [moat]
	var a: AABB = moat.aabb
	negative.append({"name": "fault_inside_moat", "aabb": AABB(
		Vector3(a.position.x + a.size.x * 0.4, -0.2,
			a.position.z + a.size.z * 0.4), Vector3(a.size.x * 0.2, 1.0,
			a.size.z * 0.2))})
	var report := MassRules.overlaps(negative,
		func(_left: String, _right: String) -> float: return 0.0, ["moat"])
	if report.failures.is_empty():
		res.fail("positive mass intruding into negative moat escaped overlap control")
	else:
		res.checked += 1
