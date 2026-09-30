extends SceneTree
## Bounded CastleQA checks for the two same-seed rendered landmarks.

func _init() -> void:
	for row in [
		{"name": "bodiam", "style": &"edwardian", "tier": &"castle",
			"w": 55.0, "l": 50.0, "h": 18.0, "seed": 6001},
		{"name": "krak", "style": &"crusader", "tier": &"fortress",
			"w": 300.0, "l": 140.0, "h": 20.0, "seed": 6002},
	]:
		var spec := CastleSpec.new()
		spec.style = row.style
		spec.tier_override = row.tier
		spec.width = row.w
		spec.length = row.l
		spec.height = row.h
		CastleGenerator.generate(spec, row.seed)
		CastleLandmarkSuite._force_features(row.name, spec)
		spec.keep_shape = &"square"
		var builder := CastleBuilder.new()
		var mesh := builder.build(spec)
		var report: Dictionary = CastleQA.new().check(spec, mesh, builder)
		print("%s seed=%d: %s, %d failures, %d warnings" % [
			row.name, row.seed, "PASS" if report.ok else "FAIL",
			report.failures.size(), report.warnings.size()])
		for failure in report.failures:
			print("  FAIL ", failure)
		for warning in report.warnings:
			print("  WARN ", warning)
		var normals := SuiteResult.new("%s normals" % row.name)
		NormalsSuite.check_mesh(normals, mesh, row.name)
		NormalsSuite.check_openings(normals, builder, row.name)
		print("%s seed=%d normals: %d failures, %d warnings" % [
			row.name, row.seed, normals.failures.size(), normals.warnings.size()])
		for failure in normals.failures:
			print("  FAIL ", failure)
		for warning in normals.warnings:
			print("  WARN ", warning)
	quit()
