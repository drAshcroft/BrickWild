extends RefCounted
## Ray checks against the emitted triangles: coverage alone would miss crossed
## slabs hiding beneath the visible roof or floating above an unclosed gable.

static func run() -> SuiteResult:
	var res := SuiteResult.new("church roofs")
	for width in [6.0, 10.0, 18.0]:
		for pitch in [0.3, 0.65, 1.0]:
			var s := ChurchSpec.new()
			s.width = width
			s.length = width * 2.6
			s.height = width * 1.2
			s.roof_pitch = pitch
			s.transept = true
			s.transept_len = width * 2.4
			s.aisles = 2
			s.aisle_width = width * 0.3
			var kit := MeshKit.new(4)
			# Keep the four material slots present without touching the test area.
			for surf in range(4):
				kit.box(Vector3.ONE, Vector3(-100, -100, -100), surf)
			preload("res://src/church/church_roofs.gd").emit(s, kit, [])
			var mesh := kit.commit()
			var roofs := _triangles(mesh, 2)
			var walls := _triangles(mesh, 0)
			var who := "width=%.1f pitch=%.2f" % [width, pitch]
			var zc := ChurchGeometry.transept_center_z(s)
			# Sweep both sides of both ridges and the four valleys. Independent
			# equations describe perpendicular gables; samples avoid exact edges.
			for ix in range(1, 24):
				for iz in range(1, 19):
					var x: float = -s.transept_len * 0.5 + s.transept_len * (ix + 0.17) / 24.0
					var z: float = zc - width * 0.45 + width * 0.9 * (iz + 0.31) / 19.0
					var expected := -INF
					if absf(x) < (width + 0.5) * 0.5 and absf(z) < (s.length + 0.4) * 0.5:
						expected = s.height + width * pitch * (1.0 - absf(x) / ((width + 0.5) * 0.5))
					if absf(z - zc) < (width * 0.55 + 0.5) * 0.5:
						expected = maxf(expected, s.height + width * pitch * 0.9 * (1.0 - absf(z - zc) / ((width * 0.55 + 0.5) * 0.5)))
					if not is_finite(expected):
						continue
					var hits := _heights(roofs, x, z, s.height - 0.5, s.height + width * 2)
					_expect(res, hits.size() == 2 and absf(hits[-1] - expected - 0.12) < 0.003 and absf(hits[0] - expected + 0.12) < 0.003,
						who + " crossing has a gap or extra slab at %s; heights=%s expected=%.3f" % [Vector2(x,z), hits, expected])
			# Both aisle rings must cover their own outer wall and have a closed
			# end immediately below the roof, even on the mirrored side.
			for ring in range(2):
				for side in [-1.0, 1.0]:
					var wall := ChurchGeometry.aisle_aabb(s, side, ring)
					var x: float = wall.get_center().x
					var roof := _heights(roofs, x, wall.position.z + 0.013, wall.end.y, s.height)
					_expect(res, not roof.is_empty(), who + " uncovered aisle %s/%s" % [ring, side])
					if not roof.is_empty():
						_expect(res, _intersects(walls, Vector3(x, roof[0] - 0.01, wall.position.z - 1), Vector3(x, roof[0] - 0.01, wall.position.z + 0.4)), who + " open aisle gable")
			for side in [-1.0, 1.0]:
				for f in [0.0, 0.35, 0.8]:
					var x: float = width * 0.5 * f
					var top: float = s.height + width * pitch * (1.0 - absf(x) / ((width + 0.5) * 0.5)) - 0.12
					var z: float = side * s.length * 0.5
					_expect(res, _intersects(walls, Vector3(x, top - 0.01, z - 0.5), Vector3(x, top - 0.01, z + 0.5)), who + " gap above nave gable")
			NormalsSuite.check_mesh(res, mesh, who)
	# The apse cap must cover the shoulders of the actual semicircular drum.
	var s := ChurchSpec.new()
	s.width = 10
	s.length = 26
	s.height = 12
	s.roof_pitch = 0.65
	s.apse = true
	s.apse_radius = 4
	var builder := ChurchBuilder.new()
	builder.spec = s
	builder.begin(4)
	for surf in range(4):
		builder._kit.box(Vector3.ONE, Vector3(-100, -100, -100), surf)
	var base := Vector3(0, s.height * 0.85, ChurchGeometry.apse_springing_z(s))
	builder._half_cone_cap(base, s.apse_radius + 0.35, s.apse_radius * 0.9, 2)
	var cap := _triangles(builder.commit(), 2)
	for i in range(1, 40):
		var angle := PI * (i + 0.13) / 41.0
		var p := Vector2(cos(angle), sin(angle)) * s.apse_radius * 0.98
		_expect(res, not _heights(cap, p.x, base.z + p.y, base.y - 0.2, base.y + 5).is_empty(), "apse shoulder uncovered at angle %.3f" % angle)
	_tower_and_domes(res)
	return res

static func _triangles(mesh: ArrayMesh, surface: int) -> Array:
	return HouseQASuite._triangles(mesh, surface)

static func _heights(tris: Array, x: float, z: float, bottom: float, top: float) -> Array[float]:
	var out: Array[float] = []
	for t in tris:
		var hit = Geometry3D.segment_intersects_triangle(Vector3(x, top, z), Vector3(x, bottom, z), t[0], t[1], t[2])
		if hit != null:
			var y: float = hit.y
			if not out.any(func(v: float) -> bool: return absf(v - y) < 0.001):
				out.append(y)
	out.sort()
	return out

static func _intersects(tris: Array, a: Vector3, b: Vector3) -> bool:
	for t in tris:
		if Geometry3D.segment_intersects_triangle(a, b, t[0], t[1], t[2]) != null:
			return true
	return false

static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)


static func _tower_and_domes(res: SuiteResult) -> void:
	for kind in ["tower", "hemisphere", "octagonal", "onion"]:
		for pitch in [0.32, 0.58]:
			var s := ChurchSpec.new()
			s.width = 10
			s.length = 26
			s.height = 12
			s.roof_pitch = pitch
			s.transept = true
			s.transept_len = 24
			s.crossing_tower = kind == "tower"
			s.crossing_tower_height = 25
			s.dome = not s.crossing_tower
			s.dome_shape = StringName(kind)
			s.dome_radius = 4.5
			s.dome_drum_height = 2.0
			var builder := ChurchBuilder.new()
			builder.spec = s
			builder.begin(4)
			for surf in range(4):
				builder._kit.box(Vector3.ONE, Vector3(-100, -100, -100), surf)
			builder._build_crossing_tower()
			builder._build_dome()
			var before := builder.commit()
			var old_roofs := _triangles(before, 2)
			if kind == "octagonal":
				for k in range(8):
					var a := TAU * float(k) / 8.0 + PI / 8.0
					var b := a + PI / 4.0
					var p := (Vector2(cos(a), sin(a)) + Vector2(cos(b), sin(b))) * 4.77 * 0.495
					_expect(res, not _heights(old_roofs, p.x, ChurchGeometry.transept_center_z(s) + p.y, 14.5, 40).is_empty(), "octagonal shell leaves drum rim uncovered")
			var first: int = (before.surface_get_arrays(2)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			preload("res://src/church/church_roofs.gd").emit(s, builder._kit, builder.mass_log, builder._roof_volumes)
			var roofs := _triangles(builder.commit(), 2).slice(first)
			var zc := ChurchGeometry.transept_center_z(s)
			var tower := ChurchGeometry.crossing_tower_aabb(s)
			for ix in range(1, 20):
				for iz in range(1, 20):
					var x := -5.5 + 11.0 * (ix + 0.37) / 20.0
					var z := zc - 5.5 + 11.0 * (iz + 0.19) / 20.0
					var y := -INF
					if absf(x) < 5.25 and absf(z) < 13.2:
						y = 12 + 10 * pitch * (1.0 - absf(x) / 5.25)
					if absf(z - zc) < 3.0:
						y = maxf(y, 12 + 9 * pitch * (1.0 - absf(z - zc) / 3.0))
					if not is_finite(y):
						continue
					var inside: bool
					if s.crossing_tower:
						inside = tower.has_point(Vector3(x, y, z))
					else:
						# A vertical ray crosses a closed shell an odd number of
						# times from inside; two hits below an onion overhang are outside.
						inside = _heights(old_roofs, x, z, y, 40).size() % 2 == 1
						if kind == "octagonal" and y < 14.5:
							var drum := PackedVector2Array()
							for k in range(8):
								var a := TAU * float(k) / 8.0 + PI / 8.0
								drum.append(Vector2(cos(a) * 4.77, zc + sin(a) * 4.77))
							inside = inside or Geometry2D.is_point_in_polygon(Vector2(x,z), drum)
					var hits := _heights(roofs, x, z, y - 0.3, y + 0.3)
					_expect(res, hits.is_empty() if inside else hits.size() == 2,
						"%s pitch=%.2f roof %s at %s (hits=%s)" % [kind, pitch, "inside volume" if inside else "gap beside volume", Vector3(x,y,z), hits])
