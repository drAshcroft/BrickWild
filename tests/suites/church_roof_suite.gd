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
	_hero_dome_segments(res)
	_pendentive_transition(res)
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
			if s.crossing_tower and is_equal_approx(pitch, 0.32):
				var assembled := ChurchBuilder.new()
				var assembled_mesh: ArrayMesh = assembled.build(s)
				var stone_triangles: Array = MeshProbe.surface_triangles(null,
					assembled_mesh, ChurchBuilder.SURF_STONE)
				var tower_base: float = ChurchGeometry.crossing_tower_aabb(s).position.y
				var bearing_y: float = tower_base + 0.03
				var center_z: float = ChurchGeometry.crossing_center_z(s)
				var bay_depth: float = ChurchGeometry.crossing_bay_depth(s)
				var corner_points: Array[Vector2] = []
				for side_x in [-1.0, 1.0]:
					for side_z in [-1.0, 1.0]:
						corner_points.append(Vector2(
							side_x * (s.width * 0.5 - ChurchBuilder.NAVE_WALL_T * 0.5),
							center_z + side_z * (bay_depth * 0.5 - ChurchBuilder.NAVE_WALL_T * 0.5)))
				for corner in corner_points:
					var bearing_from := Vector3(corner.x, bearing_y + 0.1, corner.y)
					var bearing_to := Vector3(corner.x, bearing_y - 0.35, corner.y)
					_expect(res, MeshProbe.ray_blocked(stone_triangles, bearing_from, bearing_to),
						"crossing tower corner bearing has no emitted stone contact at %s" % corner)
					for fraction in [0.15, 0.35, 0.8]:
						var wall_y: float = s.height * fraction
						var x_from := Vector3(signf(corner.x) * (s.width * 0.5 + 0.6), wall_y, corner.y)
						var x_to := Vector3(signf(corner.x) * (s.width * 0.5 - 0.6), wall_y, corner.y)
						_expect(res, _intersects(stone_triangles, x_from, x_to),
							"tower corner has no wall-to-bearing path on X below y=%.2f" % wall_y)
						var z_from := Vector3(corner.x, wall_y,
							center_z + signf(corner.y - center_z) * (bay_depth * 0.5 + 0.6))
						var z_to := Vector3(corner.x, wall_y,
							center_z + signf(corner.y - center_z) * (bay_depth * 0.5 - 0.6))
						_expect(res, _intersects(stone_triangles, z_from, z_to),
							"tower corner has no wall-to-bearing path on Z below y=%.2f" % wall_y)
				var control_corner: Vector2 = corner_points[0]
				var control_from := Vector3(control_corner.x, bearing_y + 0.1, control_corner.y)
				var control_to := Vector3(control_corner.x, bearing_y - 0.35, control_corner.y)
				var detached_kit := MeshKit.new(1)
				detached_kit.box(Vector3(ChurchBuilder.NAVE_WALL_T, 0.28, bay_depth),
					Vector3(control_corner.x, bearing_y + 0.75, control_corner.y), 0)
				var detached_mesh: ArrayMesh = detached_kit.commit()
				var detached_triangles: Array = MeshProbe.surface_triangles(null, detached_mesh, 0)
				_expect(res, not MeshProbe.ray_blocked(detached_triangles, control_from, control_to),
					"detached-bearing negative control still contacts the tower datum")
				_expect(res, not MeshProbe.ray_blocked(stone_triangles,
					Vector3(0.0, bearing_y + 0.1, center_z),
					Vector3(0.0, bearing_y - 0.35, center_z)),
					"crossing tower bearing sealed its center opening")
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


## Hero dome tessellation is explicit: Hagia gains radial sides, while Florence
## keeps eight plan facets and both hero shells get a finer vertical profile.
static func _hero_dome_segments(res: SuiteResult) -> void:
	for kind in [&"hemisphere", &"octagonal"]:
		var s := ChurchSpec.new()
		s.style = &"byzantine" if kind == &"hemisphere" else &"renaissance"
		s.width = 10.0
		s.length = 26.0
		s.height = 12.0
		s.transept = true
		s.transept_len = 24.0
		s.dome = true
		s.dome_shape = kind
		s.dome_radius = 4.5
		s.dome_drum_height = 2.0
		var builder := ChurchBuilder.new()
		builder.spec = s
		builder.begin_metric(4)
		for surface in range(4):
			builder._kit.box(Vector3.ONE, Vector3(-100, -100, -100), surface)
		var before := builder.commit()
		var roof_before: PackedVector3Array = before.surface_get_arrays(2)[Mesh.ARRAY_VERTEX]
		builder._build_dome()
		var mesh := builder.commit()
		_expect(res, builder.has_mass("pendentive"),
			"%s dome lost its pendentive mass log" % String(kind))
		var arrays := mesh.surface_get_arrays(2)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var octagonal: bool = kind == &"octagonal"
		var segments: int = 8 if octagonal else 32
		var radius := s.dome_radius * (ChurchGeometry.OCTAGONAL_RADIUS_FACTOR if octagonal else 1.0)
		var profile := builder._dome_profile(radius, ChurchGeometry.dome_shell_rise(s))
		# Each final apex ring degenerates one of the two triangles per facet.
		var expected_vertices := segments * ((profile.size() - 1) * 6 - 3)
		var emitted_vertices := points.size() - roof_before.size()
		var who := String(kind)
		_expect(res, emitted_vertices == expected_vertices,
			"%s dome shell emitted %d vertices; %d explicit segments/profile predict %d" % [
				who, emitted_vertices, segments, expected_vertices])
		var ring_angles: Dictionary = {}
		var spring_y := ChurchGeometry.dome_base_height(s) \
			+ ChurchGeometry.pendentive_height(s) + s.dome_drum_height
		var cz := ChurchGeometry.crossing_center_z(s)
		for point in points:
			if absf(point.y - spring_y) < 0.0001 \
					and absf(Vector2(point.x, point.z - cz).length() - radius) < 0.0001:
				var angle := fposmod(atan2(point.z - cz, point.x), TAU)
				ring_angles[roundi(angle * 100000.0)] = true
		_expect(res, ring_angles.size() == segments,
			"%s shell spring has %d ring facets, expected %d" % [who, ring_angles.size(), segments])
		_expect(res, normals.size() == points.size() and uvs.size() == points.size(),
			"%s shell lost per-vertex normals or metric UVs" % who)
		var finite_uvs := true
		for uv in uvs:
			if not is_finite(uv.x) or not is_finite(uv.y):
				finite_uvs = false
				break
		_expect(res, finite_uvs, "%s shell emitted non-finite metric UVs" % who)


## The support is a closed loft. Its square base meets the crossing, and its
## upper ring matches the round/octagonal drum at the same height and phase.
## VIS-016, hero Hagia Sophia: the bearing under the drum must be masonry. A
## square block with vertical faces (not a flared skirt), a solid wall where
## there is no window and an open throat where there is one, four great arches
## and four corner piers.
static func _hero_bearing(res: SuiteResult) -> void:
	for scale in [1.0, 0.5]:
		var spec := ChurchSpec.new()
		spec.style = &"byzantine"
		spec.width = 31.0 * scale
		spec.length = 76.0 * scale
		spec.height = 40.0 * scale
		ChurchGenerator.generate(spec, 5006)
		ChurchGenerator.apply_landmark(spec, "hagia_sophia")
		var builder := ChurchBuilder.new()
		var mesh: ArrayMesh = builder.build(spec)
		var who := "hero Hagia x%.1f" % scale
		var base: float = ChurchGeometry.dome_base_height(spec)
		var rise: float = ChurchGeometry.pendentive_height(spec)
		var half: float = ChurchGeometry.hagia_bearing_half(spec)
		var cz: float = ChurchGeometry.crossing_center_z(spec)
		var bearing := builder.mass_aabb("pendentive")
		_expect(res, absf(bearing.size.x - half * 2.0) < 0.01 and absf(bearing.size.z - half * 2.0) < 0.01
			and absf(bearing.size.y - rise) < 0.01,
			"%s bearing is not the square block the dome circle is inscribed in" % who)
		_expect(res, rise > spec.dome_radius * 0.6,
			"%s bearing is too shallow to read as masonry" % who)
		var stone := _triangles(mesh, ChurchBuilder.SURF_STONE)
		var flare := 0
		for t in stone:
			for v in t:
				if v.y > base + 0.6 * scale and v.y < base + rise - 0.05 						and absf(v.z - cz) <= half + 0.05 and absf(v.x) > half + 0.05:
					flare += 1
		_expect(res, flare == 0, "%s bearing flares past its square (%d vertices)" % [who, flare])
		var hr: float = ChurchGeometry.half_dome_radius(spec)
		var y: float = base + rise * 0.5
		var wall_z: float = cz + hr * 0.17
		_expect(res, _intersects(stone, Vector3(half + 5.0, y, wall_z), Vector3(half - 1.0, y, wall_z)),
			"%s bearing wall is not solid between its windows" % who)
		_expect(res, not _intersects(stone, Vector3(half + 5.0, y, cz),
			Vector3(-half - 5.0, y, cz)),
			"%s bearing has no open throat at its centre window" % who)
		for i in range(4):
			_expect(res, not builder.components_of("great_arch_%d" % i).is_empty(),
				"%s great arch %d is missing" % [who, i])
		var pier_top: float = ChurchGeometry.hagia_pier_top(spec)
		var piers := 0
		for part in builder.part_log:
			if part.kind == "box" and part.tag == "bearing" 					and absf(part.size.x - ChurchGeometry.hagia_pier_size(spec)) < 0.001 					and absf(part.pos.y + part.size.y / 2.0 - pier_top) < 0.001:
				piers += 1
		_expect(res, piers == 4, "%s has %d corner piers, expected 4" % [who, piers])


static func _pendentive_transition(res: SuiteResult) -> void:
	var hagia := ChurchSpec.new()
	hagia.style = &"byzantine"
	hagia.dome_shape = &"hemisphere"
	hagia.dome_radius = 10.0
	var florence := ChurchSpec.new()
	florence.style = &"renaissance"
	florence.dome_shape = &"octagonal"
	florence.dome_radius = 10.0
	_expect(res, is_equal_approx(ChurchGeometry.pendentive_height(hagia), 1.8),
		"hero Byzantine pendentive did not scale to a readable bearing height")
	_expect(res, is_equal_approx(ChurchGeometry.pendentive_height(florence),
		ChurchGeometry.PENDENTIVE_H),
		"Florence lost its compact intentional octagonal bearing")
	for kind in [&"hemisphere", &"octagonal"]:
		var octagonal: bool = kind == &"octagonal"
		var segments: int = 8 if octagonal else 32
		var start := PI / 8.0 if octagonal else 0.0
		var lower_half := 4.8
		var upper_radius := 4.5 * (ChurchGeometry.OCTAGONAL_RADIUS_FACTOR if octagonal else 1.0)
		var center := Vector3(0.0, 12.0, 3.0)
		var height := ChurchGeometry.PENDENTIVE_H
		var builder := ChurchBuilder.new()
		builder.begin_metric(4)
		builder.spec = ChurchSpec.new()
		builder._pendentive_support(center, lower_half, upper_radius, height, segments, start,
			not octagonal)
		var mesh := builder.commit()
		var arrays := mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var who := String(kind)
		var expected_rings := ChurchBuilder.PENDENTIVE_PROFILE_STEPS + 1 \
			+ (0 if octagonal else ChurchBuilder.PENDENTIVE_LEDGE_ROWS.size() * 3)
		_expect(res, points.size() == segments * expected_rings * 12,
			"%s pendentive should emit a closed annular curved loft with %d facets" % [who, segments])
		var x_extent := 0.0
		var z_extent := 0.0
		var top_angles: Dictionary = {}
		for point in points:
			x_extent = maxf(x_extent, absf(point.x - center.x))
			z_extent = maxf(z_extent, absf(point.z - center.z))
			if absf(point.y - center.y - height) < 0.0001 \
					and absf(Vector2(point.x - center.x, point.z - center.z).length() - upper_radius) < 0.0001:
				var angle := fposmod(atan2(point.z - center.z, point.x - center.x), TAU)
				top_angles[roundi(angle * 100000.0)] = true
		_expect(res, is_equal_approx(x_extent, lower_half) and is_equal_approx(z_extent, lower_half),
			"%s pendentive lost its square crossing footprint" % who)
		var envelope_ok := true
		for point in points:
			if absf(point.x - center.x) > lower_half + 0.01 \
					or absf(point.z - center.z) > lower_half + 0.01 \
					or point.y < center.y - 0.01 \
					or point.y > center.y + height + 0.01:
				envelope_ok = false
		_expect(res, envelope_ok, "%s pendentive course escaped its roof-cut/mass envelope" % who)
		_expect(res, top_angles.size() == segments,
			"%s pendentive top ring does not match the %d-sided drum" % [who, segments])
		var top_phase_ok := true
		for i in range(segments):
			var expected_angle := roundi(fposmod(start + TAU * float(i) / float(segments), TAU) * 100000.0)
			if not top_angles.has(expected_angle):
				top_phase_ok = false
		_expect(res, top_phase_ok, "%s pendentive top ring phase does not match the drum" % who)
		var square_ring_ok := true
		var drum_ring_ok := true
		for point in points:
			if absf(point.y - center.y) < 0.0001 \
					and Vector2(point.x - center.x, point.z - center.z).length() > 0.1:
				var square_edge := maxf(absf(point.x - center.x), absf(point.z - center.z))
				if square_edge > lower_half - ChurchBuilder.NAVE_WALL_T * 0.5 \
						and absf(square_edge - lower_half) > 0.01:
					square_ring_ok = false
			if absf(point.y - center.y - height) < 0.0001 \
					and Vector2(point.x - center.x, point.z - center.z).length() > 0.1:
				var ring_radius: float = Vector2(point.x - center.x, point.z - center.z).length()
				if ring_radius > upper_radius - ChurchBuilder.NAVE_WALL_T * 0.5 \
						and absf(ring_radius - upper_radius) > 0.01:
					drum_ring_ok = false
		_expect(res, square_ring_ok, "%s lower ring does not meet square crossing within 1 cm" % who)
		_expect(res, drum_ring_ok, "%s upper ring does not meet drum within 1 cm" % who)
		_expect(res, _closed_triangle_shell(points), "%s pendentive shell has an open edge" % who)
		var stone_triangles: Array = MeshProbe.surface_triangles(null, mesh, 0)
		var aperture_from := Vector3(center.x, center.y - 0.1, center.z)
		var aperture_to := Vector3(center.x, center.y + height + 0.1, center.z)
		_expect(res, not MeshProbe.ray_blocked(stone_triangles, aperture_from, aperture_to),
			"%s pendentive bearing bands sealed the true center aperture" % who)
		var curved_ring := false
		if not octagonal:
			for point in points:
				if absf(point.y - center.y - height / 3.0) < 0.0001 \
						and absf(atan2(point.z - center.z, point.x - center.x) - PI / 4.0) < 0.0001:
					var linear_radius := lerpf(lower_half / cos(PI / 4.0), upper_radius, 1.0 / 3.0)
					var radius: float = Vector2(point.x - center.x, point.z - center.z).length()
					if radius > linear_radius + 0.05:
						curved_ring = absf(radius - linear_radius) > 0.05
		_expect(res, octagonal or curved_ring,
			"hemisphere support profile is still a straight-sided square-to-drum funnel")
		if not octagonal:
			var ledge_radius := 0.0
			var ledge_y := center.y + height * (5.0 / ChurchBuilder.PENDENTIVE_PROFILE_STEPS)
			var ledge_t := 5.0 / ChurchBuilder.PENDENTIVE_PROFILE_STEPS
			var eased := ledge_t * ledge_t * (3.0 - 2.0 * ledge_t)
			var base_radius := lerpf(lower_half, upper_radius, pow(eased, 1.35))
			for point in points:
				if absf(point.y - ledge_y) < 0.0001 \
						and absf(point.z - center.z) < 0.0001 \
						and point.x > center.x + 0.1:
					ledge_radius = maxf(ledge_radius,
						Vector2(point.x - center.x, point.z - center.z).length())
			_expect(res, ledge_radius - base_radius >= ChurchBuilder.PENDENTIVE_LEDGE_WIDTH - 0.01,
				"hemisphere bearing lacks the specified visible corbel course")
		_expect(res, builder.part_log.size() == 1 and builder.component_log.size() == 1
			and builder.component_log[0]["role"] == "pendentive_support",
			"pendentive support lost its part/component logging")
		var good_normals := normals.size() == points.size()
		var outer_faces := 0
		var inner_faces := 0
		var side_triangles: int = segments * (expected_rings - 1) * 4
		if good_normals:
			for i in range(0, points.size(), 3):
				var a := points[i]
				var b := points[i + 1]
				var c := points[i + 2]
				var n := normals[i]
				if absf(a.y - b.y) < 0.0001 and absf(b.y - c.y) < 0.0001:
					if absf(a.y - center.y - height) < 0.0001:
						if n.y < 0.99:
							good_normals = false
					elif absf(a.y - center.y) < 0.0001:
						if n.y > -0.99:
							good_normals = false
					elif absf(n.y) < 0.99:
						good_normals = false
				else:
					var radial := Vector3((a.x + b.x + c.x) / 3.0 - center.x, 0.0,
						(a.z + b.z + c.z) / 3.0 - center.z)
					var face_index: int = int(i / 3)
					if face_index < side_triangles:
						if face_index % 4 < 2:
							outer_faces += 1
							if n.dot(radial) <= 0.0:
								good_normals = false
						else:
							inner_faces += 1
							if n.dot(radial) >= 0.0:
								good_normals = false
		_expect(res, outer_faces > 0 and inner_faces > 0,
			"%s pendentive must retain both outward and inward annular faces" % who)
		_expect(res, good_normals, "%s pendentive shell or cap faces inward or lacks normals" % who)
		_expect(res, uvs.size() == points.size(), "%s pendentive lacks metric UVs" % who)
		var finite_uvs := true
		for uv in uvs:
			if not is_finite(uv.x) or not is_finite(uv.y):
				finite_uvs = false
				break
		_expect(res, finite_uvs, "%s pendentive emitted non-finite UVs" % who)
		var metric_uvs := true
		for i in range(0, points.size(), 3):
			for edge in [[0, 1], [1, 2], [2, 0]]:
				var a_index: int = i + int(edge[0])
				var b_index: int = i + int(edge[1])
				var world_length := points[a_index].distance_to(points[b_index])
				var uv_length := uvs[a_index].distance_to(uvs[b_index])
				if absf(world_length - uv_length) > 0.001:
					metric_uvs = false
					break
		_expect(res, metric_uvs, "%s pendentive UVs no longer use metre-scale face projection" % who)
		var broken := points.duplicate()
		broken[0] += Vector3(0.02, 0.0, 0.0)
		_expect(res, not _closed_triangle_shell(broken),
			"disconnected-ring negative control was not detected")


static func _closed_triangle_shell(points: PackedVector3Array) -> bool:
	if points.is_empty() or points.size() % 3 != 0:
		return false
	var edges := {}
	for i in range(0, points.size(), 3):
		var triangle := [points[i], points[i + 1], points[i + 2]]
		for edge_index in range(3):
			var a: Vector3 = triangle[edge_index]
			var b: Vector3 = triangle[(edge_index + 1) % 3]
			var a_key := "%d,%d,%d" % [roundi(a.x * 100000.0), roundi(a.y * 100000.0), roundi(a.z * 100000.0)]
			var b_key := "%d,%d,%d" % [roundi(b.x * 100000.0), roundi(b.y * 100000.0), roundi(b.z * 100000.0)]
			var key := "%s|%s" % [a_key, b_key] if a_key < b_key else "%s|%s" % [b_key, a_key]
			edges[key] = int(edges.get(key, 0)) + 1
	for count in edges.values():
		if int(count) != 2:
			return false
	return true
