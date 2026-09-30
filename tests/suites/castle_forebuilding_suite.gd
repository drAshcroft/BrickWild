extends RefCounted
## The production keep route, including its planned interior and named parts.
static func run(filters := PackedStringArray()) -> SuiteResult:
	var result := SuiteResult.new("castle forebuilding")
	_small_castle_tier_cases(result, filters)
	_check_mont_inner_gate_clearance(result)
	var cases := [
		{"style": &"norman", "index": 2},
		{"style": &"crusader", "index": 2},
		{"style": &"french_chateau", "index": 2},
		{"style": &"japanese", "index": 1},
		{"style": &"japanese", "index": 2},
		{"style": &"moorish", "index": 2},
		{"style": &"wizard", "index": 2},
	]
	for row_case in cases:
		var style: StringName = row_case.style
		var index: int = row_case.index
		var who := "%s/fortress/%d" % [style, index]
		if not filters.is_empty() and not Array(filters).any(func(f): return who.contains(f)):
			continue
		var spec := CastleSweep.spec_at(style, &"fortress", index)
		var builder := CastleBuilder.new()
		var mesh := builder.build(spec)
		if not builder._planned_interiors.has("keep"):
			_expect(result, false, who + " production build omitted its keep plan")
			continue
		var row: Dictionary = builder._planned_interiors["keep"]
		var report := CastleQA.forebuilding_report(spec, builder, mesh, row)
		_expect(result, report.failures.is_empty(), who + " " + str(report.failures))
		_expect(result, ComponentCheck.check(builder, mesh).ok,
			who + " components differ from emitted geometry")
		var check := CastleMassingCheck.new()
		check._check_forebuilding(spec, builder)
		_expect(result, check.failures.is_empty(), who + " " + str(check.failures))
		var access := CastleQA.lords_walk(spec, builder, mesh)
		_expect(result, access.failures.is_empty(), who + " gate-to-keep route " + str(access.failures))
		_remove_forebuilding(builder)
		check = CastleMassingCheck.new()
		check._check_forebuilding(spec, builder)
		_expect(result, not check.failures.is_empty(), who + " removed protected stair escaped massing")
		print("FOREBUILDING ", who, " seed=", spec.seed, " failures=", result.failures.size())
	return result


static func run_small_fixtures() -> SuiteResult:
	var result := SuiteResult.new("castle forebuilding small fixtures")
	_small_castle_tier_cases(result, PackedStringArray())
	return result


static func run_mont_fixture() -> SuiteResult:
	var result := SuiteResult.new("Mont forebuilding gate clearance")
	_check_mont_inner_gate_clearance(result)
	return result


static func _check_mont_inner_gate_clearance(result: SuiteResult) -> void:
	var found_fixture := false
	var found_negative := false
	for scale in [0.4, 0.7, 1.0, 1.5]:
		var spec := CastleSpec.new()
		spec.style = &"french_chateau"
		spec.tier_override = &"fortress"
		spec.width = 120.0 * scale
		spec.length = 80.0 * scale
		spec.height = 40.0 * scale
		CastleGenerator.generate(spec, CastleLandmarkSuite._seed_for("mont_saint_michel", scale))
		CastleLandmarkSuite._force_features("mont_saint_michel", spec)
		if not spec.inner_ward:
			continue
		var gate: AABB = CastleGeometry.gatehouse_aabb(spec, 1)
		if gate.size.x <= 0.0:
			continue
		# Recreate the centered layout to prove this is a collision repair rather
		# than a permissive overlap rule or a smaller fixture.
		spec.keep_offset = 0.0
		var legacy_plan: HousePlan = CastleKeepPlan.generate(spec, false)
		var legacy_fore: Dictionary = preload("res://src/castle/castle_access_geometry.gd") \
			.forebuilding_for_plan(spec, legacy_plan)
		if legacy_fore.is_empty():
			continue
		var legacy_foot: Rect2 = legacy_fore.footprint
		var gate_foot := Rect2(gate.position.x, gate.position.z, gate.size.x, gate.size.z)
		if not legacy_foot.intersects(gate_foot):
			continue
		found_fixture = true
		CastleGenerator._fit_inner_gate_forebuilding(spec)
		var fore: Dictionary = CastleGeometry.forebuilding(spec)
		result.checked += 1
		if fore.is_empty() or fore.footprint.grow(0.22).intersects(gate_foot):
			result.fail("Mont-Saint-Michel scale %.2f: fitted raised forebuilding envelope still overlaps gate 1" % scale)
		var builder := CastleBuilder.new()
		builder.build(spec)
		var overlap_check := CastleMassingCheck.new()
		overlap_check._check_overlaps(spec, builder)
		for failure in overlap_check.failures:
			if String(failure).contains("gate_1") and String(failure).contains("forebuilding"):
				result.fail("Mont-Saint-Michel scale %.2f: %s" % [scale, String(failure)])
		# The exact centered forebuilding envelope must still be rejected by the
		# ordinary overlap rule when deliberately restored as a negative control.
		var legacy_aabb := AABB(Vector3(legacy_foot.position.x, 0.0, legacy_foot.position.y),
			Vector3(legacy_foot.size.x, spec.keep_height, legacy_foot.size.y))
		var control := CastleBuilder.new()
		control.mass_log = [
			{"name": "gate_1", "aabb": gate},
			{"name": "forebuilding", "aabb": legacy_aabb},
		]
		overlap_check = CastleMassingCheck.new()
		overlap_check._check_overlaps(spec, control)
		result.checked += 1
		var caught := overlap_check.failures.any(func(message):
			return String(message).contains("gate_1") and String(message).contains("forebuilding"))
		if not caught:
			result.fail("Mont-Saint-Michel scale %.2f: centered gate/stair negative control escaped" % scale)
		else:
			found_negative = true
	if not found_fixture:
		result.checked += 1
		result.fail("Mont-Saint-Michel: no fixed scale reproduced centered gate 1/forebuilding overlap")
	if not found_negative:
		result.checked += 1
		result.fail("Mont-Saint-Michel: centered gate/stair negative control was not exercised")


## Keep the original inexpensive castle/fortress controls: the occupied
## shell, its logged forebuilding, and a physical mutation that fills the stair.
static func _small_castle_tier_cases(result: SuiteResult,
		filters: PackedStringArray) -> void:
	for style in CastleSweep.styles():
		for tier in [&"castle", &"fortress"]:
			var who := "%s/%s/0" % [style, tier]
			if not filters.is_empty() and not Array(filters).any(func(f): return who.contains(f)):
				continue
			var spec := CastleSweep.spec_at(style, tier, 0)
			if not CastleGeometry.is_enclosed(spec) or not spec.keep or CastleGeometry.is_motte(spec):
				continue
			var plan := CastleKeepPlan.generate(spec, false)
			if plan.spec == null:
				continue
			var builder := CastleBuilder.new()
			builder.spec = spec
			builder.begin(4)
			var row := preload("res://src/castle/castle_interiors.gd").record(
				"keep", plan, CastleGeometry.keep_aabb(spec))
			builder._planned_interiors = {"keep": row}
			builder._build_keep()
			var mesh := builder.commit()
			var report := CastleQA.forebuilding_report(spec, builder, mesh, row)
			_expect(result, report.failures.is_empty(), who + " " + str(report.failures))
			_expect(result, ComponentCheck.check(builder, mesh).ok,
				who + " components differ from emitted geometry")
			var check := CastleMassingCheck.new()
			check._check_forebuilding(spec, builder)
			_expect(result, check.failures.is_empty(), who + " " + str(check.failures))
			_remove_forebuilding(builder)
			check = CastleMassingCheck.new()
			check._check_forebuilding(spec, builder)
			_expect(result, not check.failures.is_empty(),
				who + " removed protected stair escaped massing")
			var fore := CastleGeometry.forebuilding(spec)
			builder.box(Vector3(fore.clear, 3.0, 0.4),
				Vector3(fore.front.x, 1.5, fore.front.y + 0.14), 0)
			var blocked := CastleQA.forebuilding_report(spec, builder, builder.commit(), row)
			_expect(result, not blocked.failures.is_empty(),
				who + " filled stair escaped physical QA")
			print("FOREBUILDING SMOKE ", who, " failures=", result.failures.size())


static func _expect(result: SuiteResult, valid: bool, message: String) -> void:
	result.checked += 1
	if not valid:
		result.fail(message)
		print("FAIL: ", message)


static func _remove_forebuilding(builder: CastleBuilder) -> void:
	# Remove the logged stair mass and its emitted components/parts. The raised
	# keep door remains, so massing must report the actual missing access route.
	builder.mass_log = builder.mass_log.filter(func(m): return m.name != "forebuilding")
	builder.component_log = builder.component_log.filter(func(row): return row.host != "forebuilding")
	builder.part_log = builder.part_log.filter(func(row): return row.get("tag", "") != "forebuilding")
