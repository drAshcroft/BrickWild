extends RefCounted
## Roof-only regression tests measure the triangles, not projected coverage
## or the AABB the builder hoped to produce. The slow furnishing path is opt-in.

static func run(full := false) -> SuiteResult:
	var res := SuiteResult.new("house roofs")
	_hip_primitive(res)
	_subtraction(res)
	_lowered_gable(res)
	_gable_profile_and_half_hip(res)
	for kind in [&"gable", &"half_hipped", &"hipped"]:
		for size in [Vector2(7, 9), Vector2(14, 7), Vector2(8, 8), Vector2(10, 13)]:
			for pitch in [0.7, 1.6]:
				var s := HouseSpec.new()
				s.width = size.x
				s.length = size.y
				s.height = 2.7
				s.storeys = 2
				s.roof_pitch = pitch
				s.roof_type = kind
				s.room_count = 1
				s.program = [&"hall"]
				s.dormers = true
				s.dormer_count = 3
				s.timber_frame = false
				s.bargeboards = false
				var plan := HousePlanner.plan(s)
				var builder := HouseBuilder.new()
				var mesh := builder.build(plan)
				var who := "%s %s pitch %.1f" % [kind, size, pitch]
				_check_house(res, plan, mesh, who)
				if kind == &"hipped":
					_check_builder_hip_surface(res, plan, builder, mesh, who)
				var before: PackedVector3Array = mesh.surface_get_arrays(2)[Mesh.ARRAY_VERTEX]
				var second := builder.build(plan)
				_expect(res, before == second.surface_get_arrays(2)[Mesh.ARRAY_VERTEX], who + " rebuild changed roof")
				builder.build(plan, false)
				_expect(res, builder.roof_components.is_empty(), who + " cutaway retained roof components")
	_rotation(res)
	for row in [[&"farmhouse", 4413, 10.0, 13.0, 2.7, 1],
			[&"townhouse", 4411, 9.0, 12.0, 2.7, 2],
			[&"cottage", 4412, 7.0, 9.0, 2.5, 1],
			[&"longhall", 4414, 12.0, 16.0, 2.7, 1]]:
		var s := HouseSpec.new()
		s.style = row[0]
		s.width = row[2]
		s.length = row[3]
		s.height = row[4]
		s.storeys = row[5]
		var plan := HouseGenerator.generate(s, row[1], full)
		var builder := HouseBuilder.new()
		var mesh := builder.build(plan)
		_check_house(res, plan, mesh, "%s seed=%s" % [row[0], row[1]])
		if row[0] == &"farmhouse" and int(row[1]) == 4413:
			_expect(res, s.roof_type == &"hipped",
				"farmhouse seed=4413 stopped exercising the natural hipped-roof regression")
		if s.roof_type == &"hipped":
			_check_builder_hip_surface(res, plan, builder, mesh,
				"%s seed=%s" % [row[0], row[1]])
		res.note("%s seed=%d roof=%s fitted_dormers=%d" % [s.style, s.seed, s.roof_type,
			HouseGeometry.roof_layout(plan)["dormers"].size()])
	return res


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)


static func _triangles(mesh: ArrayMesh, surface: int) -> Array:
	return HouseQASuite._triangles(mesh, surface)


static func _hits(tris: Array, a: Vector3, b: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for t in tris:
		var hit = Geometry3D.segment_intersects_triangle(a, b, t[0], t[1], t[2])
		if hit != null:
			out.append(hit)
	return out


static func _hip_error(mesh: ArrayMesh, span: float, along: float, rise: float,
		xf := Transform3D.IDENTITY) -> float:
	var tris := _triangles(mesh, 0)
	var error := 0.0
	var h := span * 0.5
	var f := along * 0.5
	var inverse := xf.affine_inverse()
	# Independent envelope equation: a hip is the lower of its side and end
	# planes. The old crossed rectangles fail although every X/Z is covered.
	var end_run := minf(h, f)
	for ix in range(1, 12):
		for iz in range(1, 14):
			var x := -h + span * float(ix) / 12.0
			var z := -f + along * float(iz) / 14.0
			var expected := minf(rise * (1.0 - absf(x) / h), rise * (f - absf(z)) / end_run) \
				+ RoofShape.DEPTH * 0.5
			var hits := _hits(tris, xf * Vector3(x, rise + 2, z), xf * Vector3(x, -1, z))
			var top := -INF
			for p in hits:
				top = maxf(top, (inverse * p).y)
			error = maxf(error, absf(top - expected))
	return error


static func _hip_primitive(res: SuiteResult) -> void:
	var rotated := Transform3D(Basis(Vector3.UP, 0.63), Vector3(2.5, 1.7, -4.0))
	for fixture in [
			{"name": "long ridge", "size": Vector2(10.7, 13.5), "xf": Transform3D.IDENTITY},
			{"name": "square pyramid", "size": Vector2(8, 8), "xf": Transform3D.IDENTITY},
			{"name": "near-square", "size": Vector2(8, 8.02), "xf": Transform3D.IDENTITY},
			{"name": "short plan", "size": Vector2(12, 7), "xf": Transform3D.IDENTITY},
			{"name": "rotated/translated", "size": Vector2(7, 12), "xf": rotated}]:
		_check_hip_primitive(res, fixture["size"], fixture["xf"], fixture["name"])
	# Mutation fixture: retain the previous crossed-slab construction so a
	# future implementation cannot weaken this into a coverage-only test.
	var bad := MeshKit.new(1)
	var h := 5.35
	var f := 6.75
	var rise := 3.6
	for side in [-1.0, 1.0]:
		bad.oriented_box(Vector3(sqrt(h * h + rise * rise), 0.24, 2.8),
			Transform3D(Basis(Vector3.FORWARD, side * atan2(rise, h)), Vector3(side * h * 0.5, rise * 0.5, 0)), 0)
		bad.oriented_box(Vector3(h * 2, 0.24, sqrt(f * f + rise * rise)),
			Transform3D(Basis(Vector3.RIGHT, side * atan2(rise, f)), Vector3(0, rise * 0.5, side * f * 0.5)), 0)
	var bad_mesh := bad.commit()
	var cover_spec := HouseSpec.new()
	cover_spec.width = h * 2.0 - 0.7
	cover_spec.length = f * 2.0 - 0.5
	cover_spec.height = 2.6
	cover_spec.storeys = 1
	_expect(res, HouseQASuite._roof_cover(bad_mesh, cover_spec) >= 0.999,
		"old crossed slabs no longer demonstrate the coverage false negative")
	_expect(res, _hip_error(bad_mesh, h * 2, f * 2, rise) > 0.2,
		"hip regression failed to reject old crossed slabs")
	_builder_hip_integration(res)


static func _check_hip_primitive(res: SuiteResult, size: Vector2,
		xf: Transform3D, who: String) -> void:
	var rise := 3.6
	var faces := RoofShape.faces(size.x, size.y, rise, &"hipped")
	_expect(res, faces.size() == 4, "%s hip did not have four faces" % who)
	var face_geometry_ok := true
	for i in range(faces.size()):
		var face: PackedVector3Array = faces[i]
		if face.size() < 3:
			face_geometry_ok = false
			continue
		for p in face:
			if not p.is_finite():
				face_geometry_ok = false
		for fan in range(1, face.size() - 1):
			var normal := (face[fan] - face[0]).cross(face[fan + 1] - face[0])
			if not normal.is_finite() or normal.length_squared() < 0.000001:
				face_geometry_ok = false
		for j in range(i):
			if Poly.intersection_area(RoofShape.footprint(face),
					RoofShape.footprint(faces[j])) > 0.000001:
				face_geometry_ok = false
	_expect(res, face_geometry_ok, "%s hip faces are degenerate or overlap" % who)
	_check_hip_seams(res, faces, who)
	var kit := MeshKit.new(1)
	kit.hip_roof_at(xf, size.x, size.y, rise, 0)
	var mesh := kit.commit()
	var expected_kit := MeshKit.new(1)
	for face in faces:
		var world := PackedVector3Array()
		for p in face:
			world.append(xf * p)
		expected_kit.slab_poly(world, RoofShape.DEPTH, 0, true)
	var expected_mesh := expected_kit.commit()
	_expect(res, _hip_error(mesh, size.x, size.y, rise, xf) < 0.002,
		"%s envelope differs from joined face planes" % who)
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var expected_vertices: PackedVector3Array = expected_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var expected_vertex_count := 0
	for face in faces:
		expected_vertex_count += (4 * face.size() - 4) * 3
	_expect(res, vertices.size() == expected_vertex_count,
		"%s slab emitter produced an unexpected number of skin/cap triangles" % who)
	_expect(res, _triangle_count_sets_equal(_triangle_counts(vertices),
		_triangle_counts(expected_vertices)), "%s emitter added, lost, or duplicated a face" % who)
	_expect(res, _mesh_edges_closed(vertices), "%s emitted slab mesh has an open edge" % who)
	_check_hip_winding(res, mesh, faces, xf, who)
	if who == "long ridge":
		var arrays := mesh.surface_get_arrays(0)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var skin_only := PackedVector3Array()
		var inverse := xf.affine_inverse()
		for i in range(0, vertices.size(), 3):
			if absf((inverse.basis * normals[i]).y) <= 0.05:
				continue
			for j in range(3):
				skin_only.append(vertices[i + j])
		_expect(res, not _mesh_edges_closed(skin_only),
			"mesh closure check accepted roof skins with every side cap removed")
		var duplicate := vertices.duplicate()
		duplicate.append_array(vertices)
		_expect(res, not _triangle_count_sets_equal(_triangle_counts(duplicate),
			_triangle_counts(expected_vertices)),
			"face comparison accepted a duplicated closed hip roof")


static func _point_key(p: Vector3) -> String:
	return "%d:%d:%d" % [roundi(p.x * 100000.0), roundi(p.y * 100000.0),
		roundi(p.z * 100000.0)]


static func _edge_key(a: Vector3, b: Vector3) -> String:
	var ends: Array[String] = [_point_key(a), _point_key(b)]
	ends.sort()
	return ends[0] + "|" + ends[1]


static func _triangle_key(a: Vector3, b: Vector3, c: Vector3) -> String:
	var points: Array[String] = [_point_key(a), _point_key(b), _point_key(c)]
	points.sort()
	return "|".join(PackedStringArray(points))


static func _triangle_counts(vertices: PackedVector3Array) -> Dictionary:
	var counts := {}
	if vertices.size() % 3 != 0:
		return counts
	for i in range(0, vertices.size(), 3):
		var key := _triangle_key(vertices[i], vertices[i + 1], vertices[i + 2])
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


static func _triangle_count_sets_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a:
		if int(a[key]) != int(b.get(key, 0)):
			return false
	return true


static func _contains_triangles(actual: PackedVector3Array,
		expected: PackedVector3Array) -> bool:
	var actual_counts := _triangle_counts(actual)
	var expected_counts := _triangle_counts(expected)
	for key in expected_counts:
		if int(actual_counts.get(key, 0)) < int(expected_counts[key]):
			return false
	return true


static func _sloped_triangle_counts(mesh: ArrayMesh, surface: int,
		min_height: float) -> Dictionary:
	if surface < 0 or surface >= mesh.get_surface_count():
		return {}
	var arrays := mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if vertices.size() != normals.size() or vertices.size() % 3 != 0:
		return {}
	var counts := {}
	for i in range(0, vertices.size(), 3):
		var ny := absf(normals[i].y)
		if ny <= 0.05 or ny >= 0.999 or maxf(vertices[i].y,
				maxf(vertices[i + 1].y, vertices[i + 2].y)) <= min_height:
			continue
		var key := _triangle_key(vertices[i], vertices[i + 1], vertices[i + 2])
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


static func _polygon_key(points: PackedVector3Array) -> String:
	var keys := PackedStringArray()
	for p in points:
		keys.append(_point_key(p))
	keys.sort()
	return "|".join(keys)


## A complete triangulated slab has no boundary edges. Coincident caps at a
## joined hip can raise incidence to four, six, or eight, but it stays even.
static func _mesh_edges_closed(vertices: PackedVector3Array) -> bool:
	if vertices.is_empty() or vertices.size() % 3 != 0:
		return false
	var edges := {}
	for i in range(0, vertices.size(), 3):
		for j in range(3):
			var a: Vector3 = vertices[i + j]
			var b: Vector3 = vertices[i + (j + 1) % 3]
			if not a.is_finite() or not b.is_finite() or a.distance_squared_to(b) < 0.0000000001:
				return false
			var key := _edge_key(a, b)
			edges[key] = int(edges.get(key, 0)) + 1
	for count in edges.values():
		if int(count) < 2 or int(count) % 2 != 0:
			return false
	return true


## Every non-eave edge must be owned by exactly two faces. This catches a
## hairline ridge/hip crack even when vertical sampling happens to miss it.
static func _check_hip_seams(res: SuiteResult, faces: Array[PackedVector3Array],
		who: String) -> void:
	var edges := {}
	for face in faces:
		for i in range(face.size()):
			var a: Vector3 = face[i]
			var b: Vector3 = face[(i + 1) % face.size()]
			var key := _edge_key(a, b)
			if not edges.has(key):
				edges[key] = {"count": 0, "a": a, "b": b}
			edges[key]["count"] = int(edges[key]["count"]) + 1
	var open_eaves := 0
	var joined := 0
	var valid := true
	for edge in edges.values():
		var count: int = edge["count"]
		if count == 1:
			var a: Vector3 = edge["a"]
			var b: Vector3 = edge["b"]
			if absf(a.y) > 0.00001 or absf(b.y) > 0.00001:
				valid = false
			open_eaves += 1
		elif count == 2:
			joined += 1
		else:
			valid = false
	_expect(res, valid and open_eaves == 4 and joined in [4, 5],
		"%s hip has an open, duplicated, or unmatched seam" % who)


## Stored normals must agree with Godot's clockwise front-face convention.
## The second half checks that the convention points away from each emitted
## slab, rather than consistently winding every face toward its interior.
static func _check_hip_winding(res: SuiteResult, mesh: ArrayMesh,
		faces: Array[PackedVector3Array], xf: Transform3D, who: String) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var inverse := xf.affine_inverse()
	var clockwise := vertices.size() == normals.size() and vertices.size() % 3 == 0
	var outward := clockwise
	var depth_ok := clockwise
	_expect(res, clockwise, "%s mesh has malformed triangle or normal arrays" % who)
	if not clockwise:
		_expect(res, false, "%s mesh faces do not point out of their slabs" % who)
		return
	for i in range(0, vertices.size(), 3):
		var expected := MeshKit._face_normal(vertices[i], vertices[i + 1], vertices[i + 2])
		if expected.dot(normals[i]) < 0.999 or normals[i].dot(normals[i + 1]) < 0.999 \
				or normals[i].dot(normals[i + 2]) < 0.999:
			clockwise = false
		var centre: Vector3 = inverse * ((vertices[i] + vertices[i + 1] + vertices[i + 2]) / 3.0)
		var normal: Vector3 = (inverse.basis * normals[i]).normalized()
		if absf(normal.y) > 0.05:
			var mid_y := RoofShape.height_at(faces, Vector2(centre.x, centre.z))
			if is_nan(mid_y) or (centre.y - mid_y) * normal.y <= 0.00001:
				outward = false
			if is_nan(mid_y) or absf(absf(centre.y - mid_y) - RoofShape.DEPTH * 0.5) > 0.0001:
				depth_ok = false
		else:
			var cap_outward := false
			var at := Vector2(centre.x, centre.z)
			for face in faces:
				var footprint := RoofShape.footprint(face)
				if not Poly.contains_point(footprint, at, 0.001):
					continue
				var face_centre := Vector2.ZERO
				for p in footprint:
					face_centre += p
				face_centre /= float(footprint.size())
				if (at - face_centre).dot(Vector2(normal.x, normal.z)) > 0.00001:
					cap_outward = true
					break
			if not cap_outward:
				outward = false
	_expect(res, clockwise, "%s mesh normals disagree with clockwise winding" % who)
	_expect(res, outward, "%s mesh faces do not point out of their slabs" % who)
	_expect(res, depth_ok, "%s mesh does not preserve vertical slab thickness" % who)


## HouseBuilder emits descriptor faces through _roof_face rather than calling
## hip_roof_at. Keep that integration tied to the same shared face endpoints.
static func _builder_hip_integration(res: SuiteResult) -> void:
	var spec := HouseSpec.new()
	spec.width = 10.0
	spec.length = 13.0
	spec.height = 2.7
	spec.storeys = 1
	spec.roof_pitch = 0.8
	spec.roof_type = &"hipped"
	spec.room_count = 1
	spec.program = [&"hall"]
	spec.dormers = false
	spec.chimney = false
	spec.porch = false
	spec.timber_frame = false
	spec.bargeboards = false
	var plan := HousePlanner.plan(spec)
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan)
	var layout := HouseGeometry.roof_layout(plan)
	var expected: Array[PackedVector3Array] = layout["faces"]
	var xf: Transform3D = layout["transform"]
	var emitted_keys := PackedStringArray()
	for component in builder.roof_components:
		if String(component["role"]).begins_with("roof_face_"):
			emitted_keys.append(_polygon_key(component["points"]))
	var expected_keys := PackedStringArray()
	for face in expected:
		var world := PackedVector3Array()
		for p in face:
			world.append(xf * p)
		expected_keys.append(_polygon_key(world))
	emitted_keys.sort()
	expected_keys.sort()
	_expect(res, emitted_keys == expected_keys,
		"HouseBuilder hipped faces drifted from RoofShape endpoints")
	_check_builder_hip_surface(res, plan, builder, mesh, "forced hipped builder")
	_check_house(res, plan, mesh, "forced hipped builder")


## Rebuild every logged roof-surface component in isolation, then require the
## actual house mesh to contain precisely the same sloped triangles above the
## wall head. Horizontal ridge caps and vertical glazing remain deliberate.
static func _check_builder_hip_surface(res: SuiteResult, plan: HousePlan,
		builder: HouseBuilder, mesh: ArrayMesh, who: String) -> void:
	var isolated := MeshKit.new(1)
	var main_footprints: Array[PackedVector2Array] = []
	var roof_component_count := 0
	for component in builder.roof_components:
		if int(component["surface"]) != HouseBuilder.SURF_ROOF:
			continue
		roof_component_count += 1
		var points: PackedVector3Array = component["points"]
		isolated.slab_poly(points, float(component["depth"]), 0,
			bool(component["vertical"]))
		if String(component["role"]).begins_with("roof_face_"):
			main_footprints.append(RoofShape.footprint(points))
	var overlap_free := not main_footprints.is_empty()
	for i in range(main_footprints.size()):
		for j in range(i):
			if Poly.intersection_area(main_footprints[i], main_footprints[j]) > 0.000001:
				overlap_free = false
	_expect(res, overlap_free, "%s HouseBuilder emitted overlapping main roof faces" % who)
	if roof_component_count == 0:
		_expect(res, false, "%s HouseBuilder logged no roof-surface components" % who)
		return
	var isolated_mesh := isolated.commit()
	var isolated_vertices: PackedVector3Array = isolated_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var actual_vertices: PackedVector3Array = mesh.surface_get_arrays(HouseBuilder.SURF_ROOF)[Mesh.ARRAY_VERTEX]
	_expect(res, _mesh_edges_closed(isolated_vertices),
		"%s HouseBuilder roof slabs have an open emitted component" % who)
	_expect(res, _contains_triangles(actual_vertices, isolated_vertices),
		"%s HouseBuilder roof surface is missing logged component triangles" % who)
	var wall_top := plan.spec.height * mini(plan.spec.storeys, 3)
	# Porch roofs can crest a few centimetres above a low single-storey wall.
	# Main hip triangles all reach well past one slab depth above their eaves.
	var main_roof_band := wall_top + RoofShape.DEPTH
	_expect(res, _triangle_count_sets_equal(
			_sloped_triangle_counts(mesh, HouseBuilder.SURF_ROOF, main_roof_band),
			_sloped_triangle_counts(isolated_mesh, 0, main_roof_band)),
		"%s HouseBuilder roof surface has unlogged crossing or duplicate slopes" % who)


static func _subtraction(res: SuiteResult) -> void:
	var outer := Poly.from_rect(Rect2(-5, -5, 10, 10))
	var hole := PackedVector2Array([Vector2(-2,-1), Vector2(1,-1), Vector2(2,0), Vector2(1,1), Vector2(-2,1)])
	var pieces := RoofShape.subtract(outer, hole)
	var area := 0.0
	for i in range(pieces.size()):
		area += Poly.area(pieces[i])
		_expect(res, Poly.intersection_area(pieces[i], hole) < 0.0001, "roof cut covers its hole")
		for j in range(i):
			_expect(res, Poly.intersection_area(pieces[i], pieces[j]) < 0.0001, "roof cut duplicated a face")
	_expect(res, absf(area + Poly.area(hole) - 100.0) < 0.0001, "roof cut lost area outside opening")


static func _lowered_gable(res: SuiteResult) -> void:
	var s := HouseSpec.new()
	s.width = 7
	s.length = 9
	s.roof_type = &"gable"
	s.dormers = false
	var plan := HousePlanner.plan(s)
	var original := HouseBuilder.new().build(plan)
	var mutant := ArrayMesh.new()
	for surface in original.get_surface_count():
		var arrays := original.surface_get_arrays(surface)
		if surface == 0:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				if vertices[i].y > s.height + 0.01:
					vertices[i].y -= 0.3
			arrays[Mesh.ARRAY_VERTEX] = vertices
		mutant.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var result := SuiteResult.new("lowered gable mutation")
	_check_house(result, plan, mutant, "lowered gable")
	_expect(res, result.failures.any(func(f: String) -> bool: return f.contains("lateral wall/roof gaps")),
		"lateral envelope check accepted a lowered gable")


## Measure the emitted wall head against the shared roof underside. The old
## gable apex calculation was short by rise * 0.7 / (span + 0.7), which is
## about 0.300 m on the longhall fixture; that nominal difference is not an
## exposed air gap once the actual slab and closure thicknesses are emitted.
## Keep this as a mesh probe rather than a component-log assertion: the latter
## belongs to HOUSE-EXT-005.
static func _gable_profile_and_half_hip(res: SuiteResult) -> void:
	for size in [Vector2(12.0, 16.0), Vector2(16.0, 12.0)]:
		var s := HouseSpec.new()
		s.width = size.x
		s.length = size.y
		s.height = 2.7
		s.roof_pitch = 5.440636 / 6.0
		s.roof_type = &"gable"
		s.dormers = false
		s.chimney = false
		s.porch = false
		s.timber_frame = false
		s.bargeboards = false
		var plan := HousePlanner.plan(s)
		var builder := HouseBuilder.new()
		var mesh := builder.build(plan)
		var gap := _wall_profile_gap(mesh, plan)
		_expect(res, gap <= 0.01,
			"gable orientation %s has %.4fm exposed wall/roof gap" % [size, gap])

	var longhall := HouseSpec.new()
	longhall.width = 12.0
	longhall.length = 16.0
	longhall.height = 2.7
	longhall.roof_pitch = 5.440636 / 6.0
	longhall.roof_type = &"gable"
	longhall.dormers = false
	longhall.chimney = false
	longhall.porch = false
	longhall.timber_frame = false
	longhall.bargeboards = false
	var hall_plan := HousePlanner.plan(longhall)
	var hall_layout := HouseGeometry.roof_layout(hall_plan)
	var hall_span: float = hall_layout["span"]
	var hall_rise: float = hall_layout["rise"]
	var nominal := hall_rise * 0.7 / (hall_span + 0.7)
	_expect(res, absf(nominal - 0.299878) < 0.001,
		"longhall nominal profile offset drifted: %.6fm" % nominal)
	var hall_mesh := HouseBuilder.new().build(hall_plan)
	var final_gap := _wall_profile_gap(hall_mesh, hall_plan)
	_expect(res, final_gap <= 0.01 and final_gap < nominal * 0.1,
		"longhall nominal %.6fm became %.6fm exposed final gap" % [nominal, final_gap])

	# The half hip shares its cut with the gable wall, truss and boards. Probe
	# the actual trim mesh at both end walls; a member climbing above this
	# boundary is the old full-height-gable defect in a different costume.
	var half := HouseSpec.new()
	half.width = 7.0
	half.length = 9.0
	half.height = 2.7
	half.roof_pitch = 1.0
	half.roof_type = &"half_hipped"
	half.dormers = false
	half.chimney = false
	half.porch = false
	half.timber_frame = true
	half.gable_truss = &"king_post"
	half.bargeboards = true
	var half_plan := HousePlanner.plan(half)
	var half_builder := HouseBuilder.new()
	var half_mesh := half_builder.build(half_plan)
	var half_layout := HouseGeometry.roof_layout(half_plan)
	var half_cut: float = float(half_layout["rise"]) * RoofShape.HALF_HIP
	var half_xf: Transform3D = half_layout["transform"]
	var half_local := half_xf.affine_inverse()
	var trim_top := -INF
	for tri in _triangles(half_mesh, HouseBuilder.SURF_TRIM):
		for world_p in tri:
			var p: Vector3 = half_local * world_p
			if absf(absf(p.z) - (float(half_layout["along"]) * 0.5)) < 0.38 \
					and absf(p.x) <= float(half_layout["span"]) * 0.5 + 0.2:
				trim_top = maxf(trim_top, p.y)
	_expect(res, is_finite(trim_top) and absf(trim_top - half_cut) <= 0.16,
		"half-hip trim/truss misses or crosses cut: top %.4f cut %.4f" % [trim_top, half_cut])

	# Full gables alone receive apex finials. The central end-wall trim region
	# is otherwise empty when timber framing is disabled, making this a direct
	# emitted-mesh assertion rather than a tag/count convention.
	var full := HouseSpec.new()
	full.width = 7.0
	full.length = 9.0
	full.height = 2.7
	full.roof_pitch = 1.0
	full.roof_type = &"gable"
	full.dormers = false
	full.chimney = false
	full.porch = false
	full.timber_frame = false
	full.bargeboards = true
	var full_plan := HousePlanner.plan(full)
	var full_mesh := HouseBuilder.new().build(full_plan)
	var full_layout := HouseGeometry.roof_layout(full_plan)
	var full_local := (full_layout["transform"] as Transform3D).affine_inverse()
	var finial_hits := 0
	var half_finial_hits := 0
	for tri in _triangles(full_mesh, HouseBuilder.SURF_TRIM):
		for world_p in tri:
			var p: Vector3 = full_local * world_p
			for end_v in [-1.0, 1.0]:
				var ez: float = end_v * (float(full_layout["along"]) * 0.5 + 0.28)
				if absf(p.x) <= 0.08 and absf(p.z - ez) <= 0.08 \
						and p.y >= float(full_layout["rise"]) - 0.08 \
						and p.y <= float(full_layout["rise"]) + 0.5:
					finial_hits += 1
	_expect(res, finial_hits >= 8, "full gable apex finials missing from emitted trim")
	for tri in _triangles(half_mesh, HouseBuilder.SURF_TRIM):
		for world_p in tri:
			var p: Vector3 = half_local * world_p
			for end_v in [-1.0, 1.0]:
				var ez: float = end_v * (float(half_layout["along"]) * 0.5 + 0.28)
				if absf(p.x) <= 0.08 and absf(p.z - ez) <= 0.08 \
						and p.y >= half_cut + 0.05 and p.y <= half_cut + 0.5:
					half_finial_hits += 1
	_expect(res, half_finial_hits == 0, "half-hip emitted an apex finial above its hip cut")


static func _wall_profile_gap(mesh: ArrayMesh, plan: HousePlan) -> float:
	var layout := HouseGeometry.roof_layout(plan)
	var faces: Array[PackedVector3Array] = layout["faces"]
	var xf: Transform3D = layout["transform"]
	var h := float(layout["span"]) * 0.5
	var f := float(layout["along"]) * 0.5
	var walls := _triangles(mesh, HouseBuilder.SURF_WALL)
	var worst := 0.0
	for edge in [[Vector2(-h,-f), Vector2(h,-f), Vector2(0,-1)],
			[Vector2(-h,f), Vector2(h,f), Vector2(0,1)],
			[Vector2(-h,-f), Vector2(-h,f), Vector2(-1,0)],
			[Vector2(h,-f), Vector2(h,f), Vector2(1,0)]]:
		for i in range(1, 12):
			var p: Vector2 = edge[0].lerp(edge[1], float(i) / 12.0)
			var roof_y := RoofShape.height_at(faces, p) - RoofShape.DEPTH * 0.5
			if is_nan(roof_y):
				continue
			var found := false
			# Probe the actual wall triangles laterally, from the expected roof
			# underside downward. This does not assume a dense or vertex-aligned
			# profile: _hits measures the continuous triangle surface.
			for step in range(0, 241):
				var y := roof_y - float(step) * 0.005
				if y < -0.05:
					break
				var outward: Vector2 = edge[2]
				var a := p + outward * 0.35
				var b := p - outward * 0.35
				if not _hits(walls, xf * Vector3(a.x, y, a.y),
						xf * Vector3(b.x, y, b.y)).is_empty():
					worst = maxf(worst, float(step) * 0.005)
					found = true
					break
			if not found:
				worst = maxf(worst, 1.0)
	return worst


static func _check_house(res: SuiteResult, plan: HousePlan, mesh: ArrayMesh, who: String) -> void:
	var layout := HouseGeometry.roof_layout(plan)
	var faces: Array[PackedVector3Array] = layout["faces"]
	var xf: Transform3D = layout["transform"]
	var h := float(layout["span"]) * 0.5
	var f := float(layout["along"]) * 0.5
	var walls := _triangles(mesh, 0)
	var misses := 0
	for edge in [[Vector2(-h,-f), Vector2(h,-f), Vector2(0,-1)],
			[Vector2(-h,f), Vector2(h,f), Vector2(0,1)],
			[Vector2(-h,-f), Vector2(-h,f), Vector2(-1,0)],
			[Vector2(h,-f), Vector2(h,f), Vector2(1,0)]]:
		for i in range(1, 12):
			var p: Vector2 = edge[0].lerp(edge[1], float(i) / 12.0)
			var y := RoofShape.height_at(faces, p) - 0.12 - 0.025
			if y <= 0.01:
				continue
			var a: Vector2 = p + edge[2] * 0.15
			var b: Vector2 = p - edge[2] * 0.1
			if _hits(walls, xf * Vector3(a.x, y, a.y), xf * Vector3(b.x, y, b.y)).is_empty():
				misses += 1
	_expect(res, misses == 0, "%s: %d lateral wall/roof gaps" % [who, misses])
	var roofs := _triangles(mesh, 2)
	for d in layout["dormers"]:
		var x := lerpf(d["front"], d["peak_x"], 0.32)
		var z: float = d["z"] + 0.03
		var y := RoofShape.height_at(faces, Vector2(x,z))
		_expect(res, _hits(roofs, xf * Vector3(x, y + 0.13, z), xf * Vector3(x, y - 0.13, z)).is_empty(),
			who + ": host roof still crosses dormer opening")
		var cover := _hits(roofs, xf * Vector3(x, y + 3, z), xf * Vector3(x, y + 0.14, z))
		_expect(res, not cover.is_empty(), who + ": missing dormer rooflet")
	# Every emitted triangle has a finite nonzero normal.
	for surface in range(mesh.get_surface_count()):
		var normals: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_NORMAL]
		var valid := true
		for n in normals:
			if not n.is_finite() or n.length_squared() < 0.9:
				valid = false
		_expect(res, valid, who + ": degenerate mesh normal")


static func _rotation(res: SuiteResult) -> void:
	var plans: Array[HousePlan] = []
	for size in [Vector2(7,14), Vector2(14,7)]:
		var s := HouseSpec.new()
		s.width = size.x
		s.length = size.y
		var p := HouseGenerator.generate(s, 4413, false)
		s.chimney = false
		plans.append(p)
	_expect(res, plans[0].spec.dormers == plans[1].spec.dormers and plans[0].spec.dormer_count == plans[1].spec.dormer_count,
		"rotated footprint changed dormer eligibility/count")
	_expect(res, HouseGeometry.roof_layout(plans[0])["dormers"] == HouseGeometry.roof_layout(plans[1])["dormers"],
		"rotated footprint changed roof-local dormer fit")
