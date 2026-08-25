class_name MassingSuite
extends RefCounted
## 2. Structural correctness: no gaps, no undesigned overlap, sizes match spec.

static func run() -> SuiteResult:
	var res := SuiteResult.new("massing")
	for style in TestSweep.styles():
		var defects := 0
		for i in range(TestSweep.COUNT):
			var spec: ChurchSpec = TestSweep.spec_at(style, i)
			var builder := ChurchBuilder.new()
			builder.build(spec)
			var rep: Dictionary = MassingCheck.new().check(spec, builder)
			res.checked += 1
			if not rep["ok"]:
				defects += 1
				for f in rep["failures"]:
					res.fail("%s seed=%d: %s" % [String(style), TestSweep.seed_at(i), str(f)])
			for w in rep["warnings"]:
				res.warn("%s seed=%d: %s" % [String(style), TestSweep.seed_at(i), str(w)])
		res.note("%-14s %2d/%d variants with defects" % [String(style), defects, TestSweep.COUNT])
	return res
