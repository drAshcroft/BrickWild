class_name CastleMassingSuite
extends RefCounted
## 7. Structural correctness of a castle: no gaps, no undesigned overlap, sizes
##    match the spec, and a walled tier is actually walled.

static func run() -> SuiteResult:
	var res := SuiteResult.new("castle massing")
	for tier in CastleSweep.tiers():
		var defects := 0
		var variants := 0
		for style in CastleSweep.styles():
			for i in range(CastleSweep.COUNT):
				var spec: CastleSpec = CastleSweep.spec_at(style, tier, i)
				var builder := CastleBuilder.new()
				builder.build(spec)
				var rep: Dictionary = CastleMassingCheck.new().check(spec, builder)
				res.checked += 1
				variants += 1
				var who := "%s %s seed=%d" % [String(style), String(tier),
					CastleSweep.seed_at(tier, i)]
				if not rep["ok"]:
					defects += 1
					for f in rep["failures"]:
						res.fail("%s: %s" % [who, str(f)])
				for w in rep["warnings"]:
					res.warn("%s: %s" % [who, str(w)])
		res.note("%-10s %2d/%d variants with defects" % [String(tier), defects, variants])
	return res
