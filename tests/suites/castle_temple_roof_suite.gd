extends RefCounted
const Probe = preload("res://tests/suites/church_roof_suite.gd")

static func run() -> SuiteResult:
	var res := SuiteResult.new("castle and temple roofs")
	_gables(res)
	_joints(res)
	_castles(res)
	_temples(res)
	return res

static func _kit() -> MeshKit:
	var kit := MeshKit.new(4)
	for surf in range(4):
		kit.box(Vector3.ONE, Vector3(-100, -100, -100), surf)
	return kit

static func _gables(res: SuiteResult) -> void:
	for span in [6.0, 14.0, 26.0]:
		for pitch in [0.3, 0.65, 1.0]:
			for yaw in [0.0, PI / 2.0, 0.37]:
				var kit := _kit()
				var rise: float = span * pitch * 0.5
				var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(3, 8, -4))
				kit.ridge_roof(xf, span + 1.2, span * 2 + 0.8, rise, 2, 0, span, span * 2)
				var mesh := kit.commit()
				var walls := Probe._triangles(mesh, 0)
				var roofs := Probe._triangles(mesh, 2)
				for x in [-span * 0.499, -span * 0.3, 0.017, span * 0.3, span * 0.499]:
					var underside: float = rise * (1 - absf(x) / ((span + 1.2) * 0.5)) - 0.12
					for end_v in [-1.0, 1.0]:
						var a := xf * Vector3(x, underside - 0.008, end_v * (span + 0.1))
						var b := xf * Vector3(x, underside - 0.008, end_v * (span - 0.1))
						Probe._expect(res, Probe._intersects(walls, a, b), "open gable span=%s pitch=%s yaw=%s x=%s" % [span, pitch, yaw, x])
					var at := xf * Vector3(x, 0, 0.131)
					var hits := Probe._heights(roofs, at.x, at.z, 7, 8 + rise + 1)
					Probe._expect(res, hits.size() == 2 and absf(hits[0] - (8 + underside)) < 0.003 and absf(hits[-1] - hits[0] - 0.24) < 0.003,
						"ridge slab gap/overlap or wrong depth: %s" % [hits])
				NormalsSuite.check_mesh(res, mesh, "ridge roof")

static func _joints(res: SuiteResult) -> void:
	for pitch in [0.35, 0.8, 1.4]:
		var s := CastleSpec.new()
		CastleGenerator.generate(s, 42)
		s.roof_pitch = pitch
		s.dormers = false
		var b := CastleBuilder.new()
		b.spec = s
		b.begin(4)
		b._kit = _kit()
		b._range(AABB(Vector3(-4, 0, -12), Vector3(8, 10, 24)), "hall", 0, true)
		b._range(AABB(Vector3(-12, 0, 2), Vector3(24, 10, 8)), "wing_left", 0, true)
		b._join_roofs()
		var mesh := b.commit()
		var tris := Probe._triangles(mesh, 2)
		for ix in range(1, 19):
			for iz in range(1, 19):
				var x: float = -3.9 + 7.8 * (ix + 0.13) / 20.0
				var z: float = 2.1 + 7.8 * (iz + 0.37) / 20.0
				var expected: float = 10 + 4 * pitch * (1 - minf(absf(x), absf(z - 6)) / 4.25)
				var hits := Probe._heights(tris, x, z, 9, 20)
				Probe._expect(res, hits.size() == 2 and absf(hits[0] - expected + 0.12) < 0.003 and absf(hits[-1] - expected - 0.12) < 0.003, "castle valley gap/extra roof at %s: %s" % [Vector2(x,z), hits])
		NormalsSuite.check_mesh(res, mesh, "castle range joint")

static func _castles(res: SuiteResult) -> void:
	for offset in [-8.0, 8.0]:
		var s := CastleSpec.new()
		s.width = 80
		s.length = 90
		s.plan_override = &"rect"
		CastleGenerator.generate(s, 42)
		s.keep = true
		s.keep_shape = &"square"
		s.keep_offset = offset
		s.hall = false
		s.chapel = false
		var b := CastleBuilder.new()
		b.spec = s
		b.begin(4)
		b._kit = _kit()
		b._build_keep()
		var roofs := Probe._triangles(b.commit(), 2)
		var k := CastleGeometry.keep_aabb(s)
		# Ignore material-slot marker geometry.
		var xs: Array[float] = []
		for tri in roofs:
			for p in tri:
				if p.y >= k.end.y - 0.2:
					xs.append(p.x)
		Probe._expect(res, absf((xs.min() + xs.max()) * 0.5 - k.get_center().x) < 0.002, "keep roof left behind when keep offset=%s" % offset)
	for shape in [&"square", &"polygonal", &"round"]:
		var s := CastleSpec.new()
		CastleGenerator.generate(s, 42)
		s.tower_shape = shape
		s.tower_roof = &"cone"
		var b := CastleBuilder.new()
		b.spec = s
		b.begin(4)
		b._kit = _kit()
		b._tower(Vector3.ZERO, 0, "tower", Vector3.FORWARD)
		var roofs := Probe._triangles(b.commit(), 2)
		var radius := CastleGeometry.tower_radius_for(s, CastleGeometry.tower_half_at(s, 0, -1))
		var height := CastleGeometry.tower_height_at(s, 0, -1)
		for i in range(CastleGeometry.tower_sides(s)):
			var angle := CastleGeometry.tower_rotation(s) + TAU * i / CastleGeometry.tower_sides(s)
			var p := Vector2(cos(angle), sin(angle)) * radius * 0.995
			Probe._expect(res, not Probe._heights(roofs, p.x, p.y, height - 0.1, height + 30).is_empty(), "tower cap leaves %s corner uncovered" % shape)

static func _temples(res: SuiteResult) -> void:
	for form in TempleSpec.FORMS:
		for size in [Vector2(18, 32), Vector2(36, 22), Vector2(26, 44)]:
			var s := TempleSpec.new()
			s.form = form
			s.width = size.x
			s.length = size.y
			TempleGenerator.generate(s, 42)
			s.spire = false
			var b := TempleBuilder.new()
			b.spec = s
			b.begin(4)
			b._kit = _kit()
			b._build_roof()
			var mesh := b.commit()
			var roofs := Probe._triangles(mesh, 2)
			NormalsSuite.check_mesh(res, mesh, "temple roof %s" % form)
			if form == &"rotunda":
				for ix in range(1, 14):
					for iz in range(1, 14):
						var x: float = size.x * ((ix + 0.17) / 15.0 - 0.5)
						var z: float = size.y * ((iz + 0.31) / 15.0 - 0.5)
						var hits := Probe._heights(roofs, x, z, s.height - 1, s.height + size.length())
						Probe._expect(res, hits.size() == 2 and absf(hits[-1] - hits[0] - 0.24) < 0.004, "rotunda hole, missing underside or extra slab at %s: %s" % [Vector2(x,z), hits])
			if form != &"ziggurat":
				var actual_top := -INF
				for tri in roofs:
					for p in tri:
						actual_top = maxf(actual_top, p.y)
				Probe._expect(res, absf(actual_top - TempleGeometry.roof_height(s)) < 0.003, "temple roof height disagrees for %s: %s vs %s" % [form, actual_top, TempleGeometry.roof_height(s)])
			if form in [&"basilica", &"rotunda"]:
				s.spire = true
				b.begin(4)
				b._kit = _kit()
				b._build_roof()
				mesh = b.commit()
				var walls := Probe._triangles(mesh, 0)
				var base := TempleGeometry.hall_rect(s).size.x * TempleGeometry.SPIRE_BASE
				var z := TempleGeometry.dais_rect(s).get_center().y
				var top := TempleGeometry.roof_height(s)
				for side in [-1.0, 1.0]:
					Probe._expect(res, Probe._intersects(walls, Vector3(side * (base * 0.5 + 0.1), top - 0.01, z), Vector3(side * (base * 0.5 - 0.1), top - 0.01, z)), "spire floats above %s roof" % form)
