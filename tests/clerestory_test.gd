extends SceneTree

class MissingCourse extends ChurchBuilder:
	func _build_clerestory() -> void:
		pass

func _init() -> void:
	var result := SuiteResult.new("clerestory mutation")
	for scale in [0.25, 1.0, 1.75]:
		var spec := ChurchSpec.new()
		spec.style = &"gothic"
		spec.width = 12 * scale
		spec.length = 127 * scale
		spec.height = 33 * scale
		ChurchGenerator.generate(spec, 42)
		LandmarkSuite._force_features("notre_dame", spec)
		# Even a caller forcing flyers after generation needs their windows.
		spec.clerestory = false
		var builder := ChurchBuilder.new()
		builder.build(spec)
		LandmarkSuite._check_clerestory(spec, builder, str(scale), result)
		result.checked += 1
		var broken := MissingCourse.new()
		broken.build(spec)
		var mutation := SuiteResult.new("missing clerestory")
		LandmarkSuite._check_clerestory(spec, broken, str(scale), mutation)
		if mutation.ok():
			result.fail("omitted clerestory geometry was accepted")
		result.checked += 1
	print(result.summary())
	for failure in result.failures:
		print("FAIL: " + failure)
	quit(0 if result.ok() else 1)
