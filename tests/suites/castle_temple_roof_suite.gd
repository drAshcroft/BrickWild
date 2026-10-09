extends RefCounted
const Probe = preload("res://tests/suites/church_roof_suite.gd")

static func run() -> SuiteResult:
	var res := SuiteResult.new("castle and temple roofs")
	_gables(res)
	_joints(res)
	_castles(res)
	_ridge_envelope(res)
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


## A ridge range roof is a joined envelope, not four independent gables.  The
## regression checks the actual emitted bridge: every deferred roof face is
## represented, its eave clears the range wall head, every flat tower owns a
## deck at the bend, and the merlon blocks sit on that deck.
static func _ridge_envelope(res: SuiteResult) -> void:
	var s: CastleSpec = CastleSweep.spec_at(&"norman", &"castle", 0)
	s.plan_kind = &"ridge"
	CastleGenerator.refit(s)
	var b := CastleBuilder.new()
	var mesh: ArrayMesh = b.build(s)
	var ranges: Array[Dictionary] = CastleGeometry.ridge_ranges(s)
	var towers: Array[Dictionary] = CastleGeometry.ridge_tower_centers(s)
	res.checked += 1
	Probe._expect(res, b._roof_faces.size() == ranges.size() * 4,
		"ridge hip envelope lost a roof face at a range join")
	res.checked += 1
	Probe._expect(res, b._roof_covers.size() == towers.size(),
		"ridge tower deck coverage does not match vertex towers")
	var deck_rows := b.part_log.filter(func(p: Dictionary) -> bool:
		return String(p.get("kind", "")) == "tower_deck")
	res.checked += 1
	Probe._expect(res, deck_rows.size() == towers.size(),
		"flat ridge towers have no emitted top deck")
	var min_roof_y := INF
	var roof_vertices: PackedVector3Array = mesh.surface_get_arrays(CastleBuilder.SURF_ROOF)[Mesh.ARRAY_VERTEX]
	for p in roof_vertices:
		min_roof_y = minf(min_roof_y, p.y)
	res.checked += 1
	Probe._expect(res, min_roof_y > s.height,
		"ridge eave shares the range wall-head plane (%.4f vs %.4f)" % [min_roof_y, s.height])
	if s.battlements:
		var seated := 0
		var min_tower_h := INF
		for ti in range(towers.size()):
			min_tower_h = minf(min_tower_h, CastleGeometry.tower_height_at(s, 0, ti))
		for p in b.part_log:
			if String(p.get("tag", "")) != "tower" or String(p.get("kind", "")) != "box":
				continue
			var pos: Vector3 = p["pos"]
			var size: Vector3 = p["size"]
			for d in towers:
				var c: Vector3 = d["pos"]
				if Vector2(pos.x - c.x, pos.z - c.z).length() < 8.0 \
						and pos.y - size.y * 0.5 >= min_tower_h - 0.001:
					seated += 1
					break
		res.checked += 1
		Probe._expect(res, seated > towers.size(),
			"ridge merlons do not have blocks seated on their tower decks")
	NormalsSuite.check_mesh(res, mesh, "ridge envelope")

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
				var dome_radius: float = TempleGeometry.dome_radius(s)
				var facet_step: float = TAU / float(TempleGeometry.DOME_SEGMENTS)
				var exact_vertex := Vector2(dome_radius, 0.0)
				var facet_midpoint := Vector2(cos(facet_step * 0.5),
					sin(facet_step * 0.5)) * dome_radius * cos(facet_step * 0.5)
				Probe._expect(res,
					absf(exact_vertex.length() - facet_midpoint.length()) > 0.0001
					and absf(_rotunda_effective_profile_radius(exact_vertex) - dome_radius) < 0.0001
					and absf(_rotunda_effective_profile_radius(facet_midpoint) - dome_radius) < 0.0001,
					"rotunda facet radius map must distinguish vertex radius from facet midpoint while recovering both profile radii")
				var witness := Vector2(0.273, 0.417)
				for ix in range(1, 14):
					for iz in range(1, 14):
						var x: float = size.x * ((ix + 0.17) / 15.0 - 0.5)
						var z: float = size.y * ((iz + 0.31) / 15.0 - 0.5)
						var point := Vector2(x, z)
						var hits := Probe._heights(roofs, x, z, s.height - 1, s.height + size.length())
						Probe._expect(res, _rotunda_roof_profile_matches(s, point, hits),
							"rotunda emitted roof does not match its exact dome/annulus profile at %s: %s" % [point, hits])
				var positive := Probe._heights(roofs, witness.x, witness.y,
					s.height - 1.0, s.height + size.length())
				var witness_ok: bool = _rotunda_roof_profile_matches(s, witness, positive)
				var extra_roof := MeshProbe.add_box(mesh, TempleBuilder.SURF_ROOF,
					AABB(Vector3(witness.x - 0.4, s.height + 2.0,
						witness.y - 0.4), Vector3(0.8, RoofShape.DEPTH, 0.8)))
				var extra_mesh: ArrayMesh = extra_roof.get("mesh")
				var extra_hits := Probe._heights(Probe._triangles(extra_mesh,
					TempleBuilder.SURF_ROOF), witness.x, witness.y,
					s.height - 1.0, s.height + size.length())
				Probe._expect(res, witness_ok and int(extra_roof.get("added_triangles", 0)) > 0
					and not _rotunda_roof_profile_matches(s, witness, extra_hits),
					"extra-roof negative escaped the exact emitted-profile predicate")
				var removed := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_ROOF,
					func(a: Vector3, b: Vector3, c: Vector3) -> bool:
						return Geometry3D.segment_intersects_triangle(
							Vector3(witness.x, s.height - 0.16, witness.y),
							Vector3(witness.x, s.height + size.length(), witness.y), a, b, c) != null)
				var broken_mesh: ArrayMesh = removed.get("mesh")
				var broken_roofs := Probe._triangles(broken_mesh, TempleBuilder.SURF_ROOF)
				var broken_hits := Probe._heights(broken_roofs, witness.x, witness.y,
					s.height - 1.0, s.height + size.length())
				Probe._expect(res, witness_ok and int(removed.get("removed_triangles", 0)) > 0
					and not _rotunda_roof_profile_matches(s, witness, broken_hits),
					"rotunda removed-roof negative escaped the exact emitted-profile predicate")
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
				var top := TempleGeometry.roof_height(s)
				if form == &"rotunda":
					# The Rotunda lantern starts at the actual emitted dome apex. A
					# lateral stone ray belongs to the old square spire and proves no
					# Rotunda bearing. Test the full emitted circular seat instead.
					var roof_triangles: Array = Probe._triangles(mesh, TempleBuilder.SURF_ROOF)
					var lantern_radius: float = TempleGeometry.rotunda_lantern_radius(s)
					var seat_supported := true
					for ring in [0.0, 0.48, 0.92]:
						for sample in range(TempleGeometry.DOME_SEGMENTS):
							var angle: float = TAU * float(sample) / float(TempleGeometry.DOME_SEGMENTS)
							var point: Vector2 = Vector2(cos(angle), sin(angle)) \
								* lantern_radius * float(ring)
							if not MeshProbe.has_upward_support(roof_triangles, point, top, 0.03):
								seat_supported = false
					res.checked += 1
					Probe._expect(res, seat_supported,
						"Rotunda spire base lacks full-footprint support on its emitted dome seat")
					var removed_seat := MeshProbe.remove_triangles(mesh,
						TempleBuilder.SURF_ROOF,
						func(a: Vector3, b2: Vector3, c: Vector3) -> bool:
							return MeshProbe.upward_triangle_contains_point([a, b2, c],
								Vector2.ZERO, top, 0.03))
					var without_seat: Array = Probe._triangles(
						removed_seat.get("mesh"), TempleBuilder.SURF_ROOF)
					res.checked += 1
					Probe._expect(res,
						int(removed_seat.get("removed_triangles", 0)) > 0
						and not MeshProbe.has_upward_support(without_seat,
							Vector2.ZERO, top, 0.03),
						"removed Rotunda dome-seat triangles still support the optional lantern")
				else:
					var walls := Probe._triangles(mesh, 0)
					var base := TempleGeometry.hall_rect(s).size.x * TempleGeometry.SPIRE_BASE
					var z := TempleGeometry.dais_rect(s).get_center().y
					for side in [-1.0, 1.0]:
						Probe._expect(res, Probe._intersects(walls, Vector3(side * (base * 0.5 + 0.1), top - 0.01, z), Vector3(side * (base * 0.5 - 0.1), top - 0.01, z)), "spire floats above %s roof" % form)


static func _rotunda_roof_profile_matches(spec: TempleSpec, point: Vector2,
		actual: Array[float]) -> bool:
	# Revolve emits a polygonal circle. Convert the point to the equivalent
	# radial profile coordinate at its actual angular facet before measuring.
	var effective_radius: float = _rotunda_effective_profile_radius(point)
	var dome_radius: float = TempleGeometry.dome_radius(spec)
	var outer_radius: float = TempleGeometry.rotunda_outer_radius(spec) + 0.45
	var half_depth: float = RoofShape.DEPTH * 0.5
	var expected: Array[float] = []
	if effective_radius <= dome_radius + 0.0001:
		var dome_y := _rotunda_profile_height(dome_radius, effective_radius)
		_append_unique_height(expected, spec.height + dome_y - half_depth)
		_append_unique_height(expected, spec.height + dome_y + half_depth)
	if effective_radius >= dome_radius - 0.08 - 0.0001 \
			and effective_radius <= outer_radius + 0.0001:
		_append_unique_height(expected, spec.height - half_depth)
		_append_unique_height(expected, spec.height + half_depth)
	expected.sort()
	if expected.size() != actual.size():
		return false
	for i in range(expected.size()):
		if absf(expected[i] - actual[i]) > 0.004:
			return false
	return true


static func _rotunda_effective_profile_radius(point: Vector2) -> float:
	var segment_angle: float = TAU / float(TempleGeometry.DOME_SEGMENTS)
	var angle: float = atan2(point.y, point.x)
	# MeshKit.revolve places vertices on multiples of segment_angle. The facet
	# normal is half a step between vertices, so the offset is measured from it.
	var angular_offset: float = fposmod(angle, segment_angle) - segment_angle * 0.5
	return point.length() * cos(angular_offset) \
		/ cos(PI / float(TempleGeometry.DOME_SEGMENTS))


static func _rotunda_profile_height(radius: float, sample_radius: float) -> float:
	var rise: float = radius * 0.55
	for step in range(6):
		var t0: float = float(step) / 6.0
		var t1: float = float(step + 1) / 6.0
		var r0: float = radius * cos(t0 * PI * 0.5)
		var r1: float = radius * cos(t1 * PI * 0.5)
		if sample_radius >= r1 - 0.0001 and sample_radius <= r0 + 0.0001:
			var alpha: float = clampf((r0 - sample_radius) / maxf(r0 - r1, 0.0001), 0.0, 1.0)
			var y0: float = rise * sin(t0 * PI * 0.5)
			var y1: float = rise * sin(t1 * PI * 0.5)
			return lerpf(y0, y1, alpha)
	return rise


static func _append_unique_height(values: Array[float], height: float) -> void:
	for existing in values:
		if absf(existing - height) < 0.001:
			return
	values.append(height)
