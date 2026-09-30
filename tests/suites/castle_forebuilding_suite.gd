extends RefCounted
## The production keep route, including its planned interior and named parts.
static func run(filters := PackedStringArray()) -> SuiteResult:
	var result := SuiteResult.new("castle forebuilding")
	_small_castle_tier_cases(result, filters)
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
		builder.mass_log = builder.mass_log.filter(func(m): return m.name != "forebuilding")
		check = CastleMassingCheck.new()
		check._check_forebuilding(spec, builder)
		_expect(result, not check.failures.is_empty(), who + " missing protected stair escaped massing")
		print("FOREBUILDING ", who, " seed=", spec.seed, " failures=", result.failures.size())
	return result


static func run_small_fixtures() -> SuiteResult:
	var result := SuiteResult.new("castle forebuilding small fixtures")
	_small_castle_tier_cases(result, PackedStringArray())
	return result


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
			builder.mass_log = builder.mass_log.filter(func(m): return m.name != "forebuilding")
			check = CastleMassingCheck.new()
			check._check_forebuilding(spec, builder)
			_expect(result, not check.failures.is_empty(),
				who + " missing protected stair escaped massing")
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
