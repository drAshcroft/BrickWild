class_name HotelLandmarkSuite
extends RefCounted
## The supplied elevation translated into measurable silhouette, programme,
## symmetry, furnishing, and circulation rules at several scales.

const SCALES: Array[float] = [0.78, 1.0, 1.3]


static func run() -> SuiteResult:
	var res := SuiteResult.new("grand hotel landmark")
	for scale in SCALES:
		var spec := HotelSpec.new()
		spec.style = &"grand_budapest"
		spec.width = 48.0 * scale
		spec.length = 24.0 * scale
		spec.height = 3.6
		var plan := HotelGenerator.generate(spec, 42000 + int(scale * 100.0))
		var builder := HotelBuilder.new()
		builder.build(plan)
		var report := HotelQA.new().check(plan, builder)
		res.checked += 1
		for failure in report["failures"]:
			res.fail("scale=%.2f: %s" % [scale, failure])
		for warning in report["warnings"]:
			res.warn("scale=%.2f: %s" % [scale, warning])
	return res
