class_name CastleNormalsSuite
extends RefCounted
## 8. The castle held to the same surface rules as the church: every triangle
##    carries a finite unit normal that agrees with its own winding, and every
##    arrow slit, window and gate looks OUT of the wall it is cut into.
##
## Both checks are NormalsSuite's, called on a MassBuilder. A castle is where
## they earn their keep twice over: its walls are battered, so an opening
## placed on the wall's bounding box instead of on its actual sloping face
## hangs in mid-air, and nothing but this probe would notice.

static func run() -> SuiteResult:
	var res := SuiteResult.new("castle normals")
	for style in CastleSweep.styles():
		for tier in CastleSweep.tiers():
			for i in range(CastleSweep.COUNT):
				var spec: CastleSpec = CastleSweep.spec_at(style, tier, i)
				var where := "style=%s tier=%s seed=%d" % [String(style), String(tier),
					CastleSweep.seed_at(tier, i)]
				var builder := CastleBuilder.new()
				var mesh: ArrayMesh = builder.build(spec)
				res.checked += 1
				if mesh == null:
					res.fail("no mesh, " + where)
					continue
				NormalsSuite.check_mesh(res, mesh, where)
				NormalsSuite.check_openings(res, builder, where)
	return res
