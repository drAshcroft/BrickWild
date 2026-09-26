extends RefCounted
## Real occupied shell, cut doorway and protected stair, without furniture search.
static func run(filters := PackedStringArray()) -> SuiteResult:
	var result := SuiteResult.new("castle forebuilding")
	for style in CastleSweep.styles():
		for tier in [&"castle", &"fortress"]:
			var who := "%s/%s" % [style, tier]
			if not filters.is_empty() and not Array(filters).any(func(f): return who.contains(f)):
				continue
			var spec := CastleSweep.spec_at(style, tier, 0)
			if not CastleGeometry.is_enclosed(spec) or not spec.keep or CastleGeometry.is_motte(spec):
				continue
			var plan := preload("res://src/castle/castle_keep_plan.gd").generate(spec, false)
			var builder := CastleBuilder.new()
			builder.spec = spec
			builder.begin(4)
			var row := preload("res://src/castle/castle_interiors.gd").record("keep", plan, CastleGeometry.keep_aabb(spec))
			builder._planned_interiors = {"keep": row}
			builder._build_keep()
			var mesh := builder.commit()
			var report := CastleQA.forebuilding_report(spec, builder, mesh, row)
			_expect(result, report.failures.is_empty(), who + " " + str(report.failures))
			_expect(result, ComponentCheck.check(builder, mesh).ok, who + " components differ from emitted geometry")
			var check := CastleMassingCheck.new()
			check._check_forebuilding(spec, builder)
			_expect(result, check.failures.is_empty(), who + " " + str(check.failures))
			builder.mass_log = builder.mass_log.filter(func(m): return m.name != "forebuilding")
			check = CastleMassingCheck.new()
			check._check_forebuilding(spec, builder)
			_expect(result, not check.failures.is_empty(), who + " missing protected stair escaped massing")
			var fore := CastleGeometry.forebuilding(spec)
			builder.box(Vector3(fore.clear, 3.0, 0.4), Vector3(fore.front.x, 1.5, fore.front.y + 0.14), 0)
			var blocked := CastleQA.forebuilding_report(spec, builder, builder.commit(), row)
			_expect(result, not blocked.failures.is_empty(), who + " filled stair escaped physical QA")
			print("FOREBUILDING ", who, " failures=", result.failures.size())
	return result

static func _expect(result: SuiteResult, valid: bool, message: String) -> void:
	result.checked += 1
	if not valid:
		result.fail(message)
		print("FAIL: ", message)
