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
	_fantasy_emitters(res)
	_oval_ring_faces(res)
	return res


## The ordinary sweep never produces a 42m house-tier tower, so exercise the
## balcony ring explicitly alongside the dark spikes and sky rock.
static func _fantasy_emitters(res: SuiteResult) -> void:
	for row in [
			{"style": &"wizard", "w": 9.0, "l": 9.0, "h": 42.0, "tier": &"house", "seed": 12012},
			{"style": &"dark", "w": 40.0, "l": 55.0, "h": 14.0, "tier": &"castle", "seed": 9249},
			{"style": &"sky", "w": 80.0, "l": 110.0, "h": 14.0, "tier": &"castle", "seed": 12012},
	]:
		var spec := CastleSpec.new()
		spec.style = row.style
		spec.width = row.w
		spec.length = row.l
		spec.height = row.h
		spec.tier_override = row.tier
		CastleGenerator.generate(spec, row.seed)
		var builder := CastleBuilder.new()
		var mesh := builder.build(spec)
		var where := "fantasy emitter %s" % String(row.style)
		res.checked += 1
		NormalsSuite.check_mesh(res, mesh, where)
		NormalsSuite.check_openings(res, builder, where)


## Winding agreement alone cannot say whether a closed shell faces inward or
## outward. Probe the semantic direction of each oval-ring skin and cap.
static func _oval_ring_faces(res: SuiteResult) -> void:
	var kit := MeshKit.new(1)
	kit.oval_ring(Vector3.ZERO, 4.0, 3.0, 0.5, 5.0, 0, 24)
	var arrays: Array = kit.commit().surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var wrong := 0
	for i in range(0, verts.size(), 3):
		var c: Vector3 = (verts[i] + verts[i + 1] + verts[i + 2]) / 3.0
		var n: Vector3 = normals[i]
		if absf(n.y) > 0.8:
			if (c.y > 2.5 and n.y < 0.0) or (c.y < 2.5 and n.y > 0.0):
				wrong += 1
		else:
			var ellipse: float = sqrt(c.x * c.x / 16.0 + c.z * c.z / 9.0)
			var dot: float = n.dot(Vector3(c.x / 16.0, 0.0, c.z / 9.0))
			if (ellipse > 0.9 and dot < 0.0) or (ellipse < 0.9 and dot > 0.0):
				wrong += 1
	res.checked += 1
	if wrong > 0:
		res.fail("oval ring has %d inward outer faces or outward inner faces" % wrong)
