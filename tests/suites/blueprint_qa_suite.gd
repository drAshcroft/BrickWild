class_name BlueprintQASuite
extends RefCounted
## 5. Full voxel QA: rasterizes each mesh and runs the eight geometric checks.
##    Slowest suite, so it runs last.

static func run() -> SuiteResult:
	var res := SuiteResult.new("voxel QA")
	for style in TestSweep.styles():
		for i in range(TestSweep.COUNT):
			var spec: ChurchSpec = TestSweep.spec_at(style, i)
			var builder := ChurchBuilder.new()
			var mesh: ArrayMesh = builder.build(spec)
			var report: Dictionary = BlueprintQA.new().check(spec, mesh, builder)
			res.checked += 1
			var who := "%s %s seed=%d" % [String(style), spec.variant_name, spec.seed]
			if not report["ok"]:
				for f in report["failures"]:
					res.fail("%s: %s" % [who, str(f)])
			for w in report["warnings"]:
				res.warn("%s: %s" % [who, str(w)])
	return res
