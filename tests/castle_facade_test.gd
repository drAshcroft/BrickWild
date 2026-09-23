extends SceneTree

func _init() -> void:
	var result: SuiteResult = preload("res://tests/suites/castle_facade_suite.gd").run()
	# The public builder combines the furnished lower range and the castle's
	# upper window rows. Exercise that hand-off once without multiplying the
	# furnishing search inside every geometry-only mutation fixture.
	var spec := CastleSpec.new()
	spec.style = &"bavarian"
	spec.width = 120
	spec.length = 40
	spec.height = 20
	spec.plan_override = &"ridge"
	CastleGenerator.generate(spec, 8805)
	var builder := CastleBuilder.new()
	builder.build(spec)
	var checker := CastleMassingCheck.new()
	checker._check_facade(spec, builder)
	result.checked += 1
	if not checker.failures.is_empty() or builder.interiors.is_empty():
		result.fail("public ridge with planned interiors: " + str(checker.failures))
	for part in builder.part_log:
		if CastleMassingCheck._facade_window(part):
			part.pos.y *= 0.2
	checker = CastleMassingCheck.new()
	checker._check_facade(spec, builder)
	result.checked += 1
	if checker.failures.is_empty():
		result.fail("public ridge lost upper rows without facade failure")
	for failure in result.failures:
		print("FAIL: " + failure)
	print(result.summary())
	quit(0 if result.ok() else 1)
