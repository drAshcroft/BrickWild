class_name CastleQASuite
extends RefCounted
## 10. Full voxel QA for castles: rasterizes each mesh and runs the checks that
##     measure the geometry rather than the mass log. Slow, so it runs last
##     alongside the church's own voxel sweep.

static func run() -> SuiteResult:
	var res := SuiteResult.new("castle voxel QA")
	for style in CastleSweep.styles():
		for tier in CastleSweep.tiers():
			for i in range(CastleSweep.COUNT):
				var spec: CastleSpec = CastleSweep.spec_at(style, tier, i)
				var builder := CastleBuilder.new()
				var mesh: ArrayMesh = builder.build(spec)
				var report: Dictionary = CastleQA.new().check(spec, mesh, builder)
				res.checked += 1
				var who := "%s %s %s seed=%d" % [String(style), String(tier),
					spec.variant_name, spec.seed]
				if not report["ok"]:
					for f in report["failures"]:
						res.fail("%s: %s" % [who, str(f)])
				for w in report["warnings"]:
					res.warn("%s: %s" % [who, str(w)])
	return res
