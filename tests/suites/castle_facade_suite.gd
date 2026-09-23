extends RefCounted
## Real emitter records, with the same number of openings moved into one band.

static func run() -> SuiteResult:
	var result := SuiteResult.new("castle facade distribution")
	for scale in [0.7, 1.0, 1.4]:
		var ridge := CastleSpec.new()
		ridge.style = &"bavarian"
		ridge.width = 120.0 * scale
		ridge.length = 40.0 * scale
		ridge.height = 20.0 * scale
		ridge.plan_override = &"ridge"
		CastleGenerator.generate(ridge, 8805)
		var builder := CastleBuilder.new()
		builder.begin(4)
		builder.spec = ridge
		builder._build_ridge()
		_expect(result, ridge, builder, true, "real ridge facade")
		for part in builder.part_log:
			if CastleMassingCheck._facade_window(part):
				part.pos.y *= 0.2
		_expect(result, ridge, builder, false, "ridge windows compressed to lowest band")
	for shape in [&"square", &"round", &"tiered"]:
		var spec := CastleSweep.spec_at(&"edwardian", &"castle", 1)
		spec.keep = true
		spec.keep_shape = shape
		var plan: HousePlan = preload("res://src/castle/castle_keep_plan.gd").generate(spec, false)
		result.checked += 1
		if plan.spec == null:
			result.fail("%s fixture has no occupied keep" % shape)
			continue
		var builder := CastleBuilder.new()
		builder.begin(4)
		builder.spec = spec
		var record := preload("res://src/castle/castle_interiors.gd").record("keep", plan, CastleGeometry.keep_aabb(spec))
		preload("res://src/castle/castle_interiors.gd").emit(builder, record)
		_expect(result, spec, builder, true, "%s occupied keep" % shape)
		for part in builder.part_log:
			if CastleMassingCheck._facade_window(part):
				part.pos.y = float(record.transform.origin.y) + 1.0
		_expect(result, spec, builder, false, "%s upper windows removed without changing count" % shape)
	return result

static func _expect(result: SuiteResult, spec: CastleSpec, builder: CastleBuilder,
		expected: bool, label: String) -> void:
	var checker := CastleMassingCheck.new()
	checker._check_facade(spec, builder)
	result.checked += 1
	if checker.failures.is_empty() != expected:
		result.fail("%s: %s" % [label, str(checker.failures)])
