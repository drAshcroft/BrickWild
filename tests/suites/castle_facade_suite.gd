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
	# Fixed-size reproductions from CAS-008's landmark report. Each one checks
	# the production facade rule, then proves that the same opening count moved
	# out of the occupied bands is rejected.
	for fixture in [["neuschwanstein", 0.4], ["edinburgh", 0.4],
		["edinburgh", 0.7], ["mont_saint_michel", 0.4]]:
		var key: String = fixture[0]
		var scale: float = fixture[1]
		var spec := _landmark_spec(key, scale)
		var builder := CastleBuilder.new()
		builder.build(spec)
		_expect(result, spec, builder, true, "%s %.2f source facade" % [key, scale])
		for part in builder.part_log:
			if CastleMassingCheck._facade_window(part):
				part.pos.y = -20.0
		_expect(result, spec, builder, false, "%s %.2f moved-window control" % [key, scale])
	_check_compact_caernarfon(result)
	return result


static func _check_compact_caernarfon(result: SuiteResult) -> void:
	var spec := _landmark_spec("caernarfon", 0.4)
	var builder := CastleBuilder.new()
	builder.build(spec)
	result.checked += 1
	if not builder._planned_interiors.has("keep"):
		result.fail("Caernarfon 0.40: occupied keep plan was not built")
		return
	var plan: HousePlan = builder._planned_interiors["keep"].plan
	var planned_levels: Dictionary = {}
	for window in plan.windows:
		planned_levels[HousePlan.record_storey(window)] = true
	var forwarded_levels: Dictionary = {}
	for part in builder.part_log:
		if part.get("tag", "") == "keep" and String(part.get("kind", "")) == "window":
			forwarded_levels[int(floor(float(part.pos.y) / maxf(plan.spec.height, 0.01)))] = true
	if not planned_levels.has(1) or not planned_levels.has(2):
		result.fail("Caernarfon 0.40: compact shaped keep lacks planned upper-storey windows")
	if not forwarded_levels.has(1) or not forwarded_levels.has(2):
		result.fail("Caernarfon 0.40: planned upper-storey windows were not emitted and forwarded")
	var checker := CastleMassingCheck.new()
	checker._check_facade(spec, builder)
	for failure in checker.failures:
		if String(failure).begins_with("facade: keep "):
			result.fail("Caernarfon 0.40: " + String(failure))
	# Removing every emitted keep window must still trip the occupied-band rule.
	builder.part_log = builder.part_log.filter(func(part):
		return not (part.get("tag", "") == "keep" and String(part.get("kind", "")) == "window"))
	checker = CastleMassingCheck.new()
	checker._check_facade(spec, builder)
	result.checked += 1
	var missing_detected := false
	for failure in checker.failures:
		if String(failure).begins_with("facade: keep occupied storey "):
			missing_detected = true
	if not missing_detected:
		result.fail("Caernarfon 0.40: missing forwarded windows escaped facade QA")


static func _landmark_spec(key: String, scale: float) -> CastleSpec:
	var row: Dictionary = {}
	for entry in CastleLandmarkSuite.LANDMARKS:
		if String(entry.key) == key:
			row = entry
			break
	assert(not row.is_empty(), "unknown castle landmark fixture: " + key)
	var spec := CastleSpec.new()
	spec.style = row.style
	spec.tier_override = row.tier
	spec.width = float(row.width) * scale
	spec.length = float(row.length) * scale
	spec.height = float(row.height) * scale
	CastleGenerator.generate(spec, CastleLandmarkSuite._seed_for(key, scale))
	CastleLandmarkSuite._force_features(key, spec)
	return spec

static func _expect(result: SuiteResult, spec: CastleSpec, builder: CastleBuilder,
		expected: bool, label: String) -> void:
	var checker := CastleMassingCheck.new()
	checker._check_facade(spec, builder)
	result.checked += 1
	if checker.failures.is_empty() != expected:
		result.fail("%s: %s" % [label, str(checker.failures)])
