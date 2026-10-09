extends SceneTree
## Emitted aperture, structural-bearing and occupied-route fixture.
## Includes geometry-removal controls; run through the native Godot engine.

const ChurchApertures = preload("res://tests/suites/church_aperture_suite.gd")

var failures: Array[String] = []
var active_case: String = "unlabelled"

func _fail(message: String) -> void:
	failures.append("%s: %s" % [active_case, message])

func _init() -> void:
	for church_style in [&"romanesque", &"gothic", &"nordic_stave",
			&"byzantine", &"renaissance", &"russian"]:
		active_case = "church style=%s" % church_style
		_check_church_openings_and_arch(church_style)
		_check_sealed_east_wall_negative(church_style)
		_check_compact_church_route(church_style)
		_check_dome_frame_exemption(church_style)
	_check_representative_nave_elevations()
	_check_string_course_perimeters()
	active_case = "ambulatory annular shell, roof and paving"
	_check_ambulatory_architecture()
	_check_painted_dome_slot_controls()
	for form in TempleSweep.forms():
		for cult in TempleSweep.cults():
			_check_temple_beams(form, cult)
			_check_compact_temple_route(form, cult)
	_check_route_probe_negative_controls()
	for failure in failures:
		push_error(failure)
	print("sacred structural fixture: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


## Fixed public requests from the reviewed six-style image set. These are the
## actual requested footprints and seeds, not aliases for sweep indices.
func _check_representative_nave_elevations() -> void:
	var cases: Array[Dictionary] = [
		{"style": &"romanesque", "width": 8.0, "length": 14.0, "height": 7.0, "seed": 1},
		{"style": &"gothic", "width": 10.0, "length": 22.0, "height": 12.0, "seed": 8102},
		{"style": &"byzantine", "width": 16.0, "length": 48.0, "height": 24.0, "seed": 21325},
		{"style": &"nordic_stave", "width": 8.0, "length": 14.0, "height": 7.0, "seed": 8102},
		{"style": &"renaissance", "width": 10.0, "length": 22.0, "height": 12.0, "seed": 21325},
		{"style": &"russian", "width": 16.0, "length": 48.0, "height": 24.0, "seed": 1},
	]
	for row in cases:
		var spec := ChurchSpec.new()
		spec.style = row.style
		spec.width = row.width
		spec.length = row.length
		spec.height = row.height
		ChurchGenerator.generate(spec, int(row.seed))
		active_case = "nave elevation style=%s size=%.0fx%.0fx%.0f seed=%d aisles=%d" % [
			String(spec.style), spec.width, spec.length, spec.height, spec.seed, spec.aisles]
		var builder := ChurchBuilder.new()
		var mesh: ArrayMesh = builder.build(spec)
		_check_nave_supports(mesh, builder, spec)
		_check_nave_elevation_openings(mesh, builder, spec)


func _check_nave_supports(mesh: ArrayMesh, builder: ChurchBuilder,
		spec: ChurchSpec) -> void:
	var rows: Array[Dictionary] = []
	var buttress_rows: Array[Dictionary] = []
	for row in builder.component_log:
		var role: String = String(row.get("role", ""))
		var host_name: String = String(row.get("host", ""))
		if role == "nave_exterior_pier":
			rows.append(row)
		elif role == "shaft_0" and (host_name.begins_with("nave_left_") \
				or host_name.begins_with("nave_right_")):
			buttress_rows.append(row)
	var supports := ChurchGeometry.nave_support_zs(spec)
	if supports.is_empty():
		_fail("no nave support stations supplied to the elevation")
	var verified_support_rows: Array[Dictionary] = []
	for z in supports:
		for side in [-1.0, 1.0]:
			var matches: Array[Dictionary] = []
			for row in rows + buttress_rows:
				var xf: Transform3D = row.xf
				if absf(xf.origin.z - z) <= 0.001 and signf(xf.origin.x) == side:
					matches.append(row)
			if matches.size() != 1:
				_fail("support station z=%.3f side=%.0f has %d exterior bearings, expected one" % [
					z, side, matches.size()])
			else:
				verified_support_rows.append(matches[0])
	if verified_support_rows.size() != supports.size() * 2:
		return
	for row in verified_support_rows:
		var expected_surface: int = ChurchBuilder.SURF_STONE
		if String(row.get("role", "")) == "nave_exterior_pier" \
				and spec.style == &"nordic_stave":
			expected_surface = ChurchBuilder.SURF_WOOD
		if int(row.surface) != expected_surface:
			_fail("%s uses logical slot %d, expected %d" % [
				row.id, int(row.surface), expected_surface])
		var row_surface: int = _logical_mesh_surface(mesh, expected_surface)
		if row_surface < 0:
			_fail("nave support material slot %d is empty" % int(row.surface))
			continue
		var bounds: AABB = MassBuilder.component_aabb(row)
		if String(row.get("role", "")) == "nave_exterior_pier" \
				and absf(bounds.position.y - ChurchGeometry.FLOOR_LIFT) > 0.02:
			_fail("%s foot does not meet the nave floor" % row.id)
		if String(row.get("role", "")) == "nave_exterior_pier":
			var expected_width: float = ChurchGeometry.nave_pier_width(spec)
			var expected_projection: float = ChurchGeometry.nave_pier_projection(spec) * 0.65
			if absf(float(row.size.z) - expected_width) > 0.001 \
					or absf(float(row.size.x) - expected_projection) > 0.001:
				_fail("%s does not use the %s structural section" % [row.id, spec.style])
		elif absf(float(row.size.z) - ChurchGeometry.BUTTRESS_FACE) > 0.001:
			_fail("%s lost the existing stepped-buttress face width" % row.id)
		_check_support_component_removal(mesh, row, row_surface, spec)


func _check_support_component_removal(mesh: ArrayMesh, row: Dictionary,
		surface: int, spec: ChurchSpec) -> void:
	var label: String = String(row.get("id", "nave support"))
	_check_components_emitted(mesh, [row], label)
	var expected_kit := MeshKit.new(1)
	expected_kit.oriented_box(Vector3(row["size"]), row["xf"], 0)
	var expected_mesh: ArrayMesh = expected_kit.commit()
	var expected_counts: Dictionary = ComponentCheck.triangle_counts(
		_surface_vertex_soup(expected_mesh, 0))
	var before_counts: Dictionary = ComponentCheck.triangle_counts(
		_surface_vertex_soup(mesh, surface))
	var expected_total: int = 0
	for key in expected_counts:
		var count: int = int(expected_counts[key])
		expected_total += count
		if int(before_counts.get(key, 0)) < count:
			_fail("%s exact emitted triangle multiset is absent before removal" % label)
			return
	if expected_total != 12:
		_fail("%s box control expected 12 triangles, got %d" % [label, expected_total])
		return
	var bounds: AABB = MassBuilder.component_aabb(row).grow(0.01)
	var component_xf: Transform3D = row["xf"]
	var side: float = signf(component_xf.origin.x)
	var wall_plane: float = side * spec.width * 0.5
	var wall_key: String = ""
	for triangle in MeshProbe.surface_triangles(null, mesh, surface):
		var a: Vector3 = triangle[0]
		var b: Vector3 = triangle[1]
		var c: Vector3 = triangle[2]
		var key: String = ComponentCheck.triangle_key(
			a, b, c)
		if expected_counts.has(key):
			continue
		var low_y: float = minf(a.y, minf(b.y, c.y))
		var high_y: float = maxf(a.y, maxf(b.y, c.y))
		var low_z: float = minf(a.z, minf(b.z, c.z))
		var high_z: float = maxf(a.z, maxf(b.z, c.z))
		var lies_on_wall: bool = absf(a.x - wall_plane) <= 0.0001 \
			and absf(b.x - wall_plane) <= 0.0001 \
			and absf(c.x - wall_plane) <= 0.0001
		var overlaps_support_projection: bool = high_y >= bounds.position.y \
			and low_y <= bounds.end.y and high_z >= bounds.position.z \
			and low_z <= bounds.end.z
		if lies_on_wall and overlaps_support_projection:
			wall_key = key
			break
	if wall_key.is_empty():
		_fail("%s has no distinct nave-wall triangle in its local control region" % label)
		return
	var remaining_counts: Dictionary = expected_counts.duplicate()
	var removed := MeshProbe.remove_triangles(mesh, surface,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			var key: String = ComponentCheck.triangle_key(a, b, c)
			var count: int = int(remaining_counts.get(key, 0))
			if count <= 0:
				return false
			remaining_counts[key] = count - 1
			return true)
	if int(removed.get("removed_triangles", 0)) != expected_total:
		_fail("%s mutation removed %d triangles, expected exactly %d" % [
			label, int(removed.get("removed_triangles", 0)), expected_total])
		return
	for key in remaining_counts:
		if int(remaining_counts[key]) != 0:
			_fail("%s component triangle occurrence was not removed" % label)
			return
	var after_counts: Dictionary = ComponentCheck.triangle_counts(
		_surface_vertex_soup(removed.mesh as ArrayMesh, surface))
	for key in expected_counts:
		var expected_after: int = int(before_counts.get(key, 0)) - int(expected_counts[key])
		if int(after_counts.get(key, 0)) != expected_after:
			_fail("%s exact triangle count after mutation differs for %s" % [label, key])
			return
	if int(after_counts.get(wall_key, 0)) != int(before_counts.get(wall_key, 0)):
		_fail("%s component removal also removed the separate nave-wall triangle" % label)


func _check_nave_elevation_openings(mesh: ArrayMesh, builder: ChurchBuilder,
		spec: ChurchSpec) -> void:
	var cases: Array[Dictionary] = []
	if spec.aisles == 0 and spec.hero != &"basil":
		for opening in ChurchGeometry.nave_bay_windows(spec):
			for side in [-1.0, 1.0]:
				cases.append({"pos": Vector3(side * (spec.width * 0.5
					+ ChurchGeometry.OPENING_EPS), opening.y, opening.z),
					"face": side * PI * 0.5, "opening": opening})
	elif spec.aisles > 0 and not ChurchGeometry.hero_bays(spec):
		var ring: int = spec.aisles - 1
		for opening in ChurchGeometry.aisle_bay_windows(spec, ring):
			for side in [-1.0, 1.0]:
				var aisle: AABB = ChurchGeometry.aisle_aabb(spec, side, ring)
				var x: float = aisle.end.x + ChurchGeometry.OPENING_EPS \
					if side > 0.0 else aisle.position.x - ChurchGeometry.OPENING_EPS
				cases.append({"pos": Vector3(x, opening.y, opening.z),
					"face": side * PI * 0.5, "opening": opening})
	elif spec.aisles > 0:
		for opening in ChurchGeometry.hero_aisle_windows(spec):
			for side in [-1.0, 1.0]:
				var aisle: AABB = ChurchGeometry.aisle_aabb(spec, side, spec.aisles - 1)
				var x: float = aisle.end.x + ChurchGeometry.OPENING_EPS \
					if side > 0.0 else aisle.position.x - ChurchGeometry.OPENING_EPS
				cases.append({"pos": Vector3(x, opening.y, opening.z),
					"face": side * PI * 0.5, "opening": opening})
	if cases.is_empty():
		_fail("no lower nave/aisle bay lights were planned")
		return
	for index in range(cases.size()):
		var case: Dictionary = cases[index]
		var opening: Dictionary = case.opening
		var pos: Vector3 = case.pos
		var face: float = case.face
		var aperture_result := SuiteResult.new("nave bay apertures")
		ChurchApertures._check_opening(aperture_result, mesh, builder, pos, face,
			float(opening.width), float(opening.height), "bay light %d" % index)
		for message in aperture_result.failures:
			_fail(message)
		if opening.has("support_left"):
			var edge_margin: float = float(opening.width) * 0.5
			var support_half: float = ChurchGeometry.nave_pier_width(spec) * 0.5
			if pos.z - edge_margin - float(opening.support_left) < support_half + 0.2 \
					or float(opening.support_right) - (pos.z + edge_margin) < support_half + 0.2:
				_fail("bay light %d intrudes on its measured support bearing" % index)
		if index > 0:
			continue
		# Inject solid masonry into this real through-opening. The same clear-ray
		# sample that passed on the emitted mesh must hit the inserted wall.
		var wall_slot: int = ChurchBuilder.SURF_WOOD \
			if spec.style == &"nordic_stave" else ChurchBuilder.SURF_STONE
		var surface: int = _logical_mesh_surface(mesh, wall_slot)
		if surface < 0:
			_fail("wall surface for aperture negative control is missing")
			continue
		var plug_size: Vector3 = Vector3(0.8, opening.height * 0.68,
			opening.width * 0.68)
		var plug := AABB(pos - plug_size * 0.5, plug_size)
		var mutated := MeshProbe.add_box(mesh, surface, plug)
		if int(mutated.added_triangles) != 12:
			_fail("could not inject actual wall into bay-light negative control")
			continue
		var basis := Basis(Vector3.UP, face)
		var outward: Vector3 = basis * Vector3.FORWARD * -1.0
		var clear: Vector3 = pos + basis * Vector3.RIGHT * (float(opening.width) * 0.22)
		if ChurchApertures._first_hit(mutated.mesh as ArrayMesh,
				clear + outward * 0.45, clear - outward * 0.75, true).is_empty():
			_fail("actual-wall aperture negative control stayed clear")


func _triangles_matching(mesh: ArrayMesh, surface: int, predicate: Callable) -> int:
	var count := 0
	for triangle in MeshProbe.surface_triangles(null, mesh, surface):
		if bool(predicate.call(triangle[0], triangle[1], triangle[2])):
			count += 1
	return count


func _check_string_course_perimeters() -> void:
	for style in [&"romanesque", &"gothic", &"nordic_stave",
			&"byzantine", &"renaissance", &"russian"]:
		for size_index in [0, 7, 14]:
			var spec: ChurchSpec = TestSweep.spec_at(style, size_index)
			spec.string_course = true
			_check_string_course_case(spec, "sweep_%d" % size_index)
		for preset in [
			{"name": "small", "width": 8.0, "length": 14.0, "height": 7.0, "seed": 1},
			{"name": "default", "width": 10.0, "length": 22.0, "height": 12.0, "seed": 8102},
			{"name": "large", "width": 16.0, "length": 48.0, "height": 24.0, "seed": 21325}]:
			var spec := ChurchSpec.new()
			spec.style = style
			spec.width = preset["width"]
			spec.length = preset["length"]
			spec.height = preset["height"]
			ChurchGenerator.generate(spec, preset["seed"])
			spec.string_course = true
			_check_string_course_case(spec, String(preset["name"]))
		for tower_count in [1, 2]:
			var tower_spec := ChurchSpec.new()
			tower_spec.style = style
			tower_spec.width = 10.0
			tower_spec.length = 22.0
			tower_spec.height = 12.0
			ChurchGenerator.generate(tower_spec, 8102)
			tower_spec.tower = true
			tower_spec.west_towers = tower_count
			tower_spec.tower_width = 3.0 if tower_count == 2 else 4.0
			if tower_count == 2:
				tower_spec.tower_width = minf(tower_spec.tower_width,
					ChurchGeometry.max_twin_tower_width(tower_spec))
			tower_spec.tower_height = maxf(tower_spec.tower_height, 14.0)
			if tower_spec.tower_roof == &"flat":
				tower_spec.tower_roof = &"pyramid"
			tower_spec.string_course = true
			_check_string_course_case(tower_spec, "forced_%d_towers" % tower_count)


func _check_string_course_case(spec: ChurchSpec, fixture_name: String) -> void:
	active_case = "string-course %s style=%s seed=%d dims=%.1fx%.1fx%.1f towers=%d" % [
		fixture_name, spec.style, spec.seed, spec.width, spec.length, spec.height,
		spec.west_towers]
	var builder := ChurchBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	var host_faces := {}
	for row in builder.component_log:
		if not String(row.get("role", "")).begins_with("string_course_"):
			continue
		var host_name: String = String(row["host"])
		if not host_faces.has(host_name):
			host_faces[host_name] = {}
		host_faces[host_name][String(row["role"]).trim_prefix("string_course_").split("_")[0]] = true
		_check_components_emitted(mesh, [row], "string course %s" % row["id"])
		var linked_part := false
		for part in builder.part_log:
			if part.get("component_id", "") == row["id"]:
				linked_part = part["size"].is_equal_approx(row["size"]) \
					and part["pos"].distance_to(row["xf"].origin) <= 0.0001
				break
		if not linked_part:
			_fail("%s has no matching emitted part record" % row["id"])
		for opening in _course_test_openings(spec, row["host"]):
			if int(opening["face"]) != _course_face_index(String(row["role"])):
				continue
			var y0: float = float(opening["y"]) - float(opening["height"]) * 0.5
			var y1: float = ChurchBuilder.new()._box_opening_top(opening, float(opening["u"]))
			if y1 <= spec.height * 0.62 - 0.09 or y0 >= spec.height * 0.62 + 0.09:
				continue
			var along_min: float = float(opening["u"]) - float(opening["width"]) * 0.5
			var along_max: float = float(opening["u"]) + float(opening["width"]) * 0.5
			var row_bounds := _box_bounds(row)
			var row_min: float = row_bounds.position.x if int(opening["face"]) in [0, 2] else row_bounds.position.z
			var row_max: float = row_bounds.end.x if int(opening["face"]) in [0, 2] else row_bounds.end.z
			if row_max > along_min and row_min < along_max:
				_fail("%s crosses its real course-height aperture" % row["id"])
	for host_name in host_faces:
		var faces: Dictionary = host_faces[host_name]
		if not faces.has("east") or not faces.has("west") \
				or not faces.has("left") or not faces.has("right"):
			_fail("%s course perimeter is incomplete: %s" % [host_name, str(faces.keys())])
	if not host_faces.has("nave_string_course"):
		_fail("nave has no perimeter course host")
	for side in ChurchGeometry.west_tower_sides(spec):
		var tower_bounds: AABB = ChurchGeometry.tower_aabb(spec, side)
		if spec.height * 0.62 - 0.09 < tower_bounds.position.y \
				or spec.height * 0.62 + 0.09 > tower_bounds.end.y:
			continue
		var tower_host: String = "tower_string_course" if spec.west_towers == 1 else \
			"tower_%s_string_course" % ("left" if side < 0.0 else "right")
		if not host_faces.has(tower_host):
			_fail("%s has no perimeter course host" % tower_host)
	var structural := _all_structural_triangles(mesh)
	var course_y: float = spec.height * 0.62
	var probe_from := Vector3(0, course_y - 0.22, 0)
	var probe_to := Vector3(0, course_y + 0.22, 0)
	if MeshProbe.ray_blocked(structural, probe_from, probe_to):
		_fail("nave center ray is blocked across string-course elevation")
	var trim_surface: int = _logical_mesh_surface(mesh, ChurchBuilder.SURF_TRIM)
	var old_slab := AABB(Vector3(-spec.width * 0.5 - 0.175,
		course_y - 0.09, -spec.length * 0.5 - 0.175),
		Vector3(spec.width + 0.35, 0.18, spec.length + 0.35))
	var mutated := MeshProbe.add_box(mesh, trim_surface, old_slab)
	if trim_surface < 0 or int(mutated.get("added_triangles", 0)) != 12:
		_fail("full-slab control could not inject the exact former string-course box")
	else:
		var mutated_mesh: ArrayMesh = mutated["mesh"]
		if not MeshProbe.ray_blocked(_all_structural_triangles(mutated_mesh),
				probe_from, probe_to):
			_fail("former full-slab defect was not detected by the center ray")


func _course_test_openings(spec: ChurchSpec, host_name: String) -> Array[Dictionary]:
	var builder := ChurchBuilder.new()
	builder.spec = spec
	var tower_host: String = host_name.trim_suffix("_string_course")
	if tower_host == "nave":
		return builder._nave_openings()
	for side in ChurchGeometry.west_tower_sides(spec):
		var center_x := ChurchGeometry.tower_center_x(spec, side)
		var expected_host := "tower" if spec.west_towers == 1 else \
			"tower_%s" % ("left" if side < 0.0 else "right")
		if tower_host == expected_host:
			return builder._tower_openings(center_x, ChurchGeometry.tower_center_z(spec),
				spec.tower_width, spec.tower_height)
	return []


func _course_face_index(role: String) -> int:
	var face := role.trim_prefix("string_course_").split("_")[0]
	return ["east", "right", "west", "left"].find(face)


func _all_structural_triangles(mesh: ArrayMesh) -> Array:
	var triangles: Array = []
	for slot in [ChurchBuilder.SURF_STONE, ChurchBuilder.SURF_TRIM,
			ChurchBuilder.SURF_ROOF, ChurchBuilder.SURF_ACCENT, ChurchBuilder.SURF_WOOD]:
		var surface := _logical_mesh_surface(mesh, slot)
		if surface >= 0:
			triangles.append_array(MeshProbe.surface_triangles(null, mesh, surface))
	return triangles


func _check_church_openings_and_arch(church_style: StringName) -> void:
	var spec := ChurchSpec.new()
	spec.style = church_style
	spec.width = 12.0
	spec.length = 40.0
	spec.height = 18.0
	ChurchGenerator.generate(spec, 5107)
	active_case = "church opening/arch style=%s seed=%d" % [church_style, spec.seed]
	spec.apse = true
	spec.transept = true
	if spec.transept_len <= 0.0:
		spec.transept_len = spec.width * 2.2
	var builder := ChurchBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	_check_crossing_arch_profile(spec, builder)
	var east: float = spec.length * 0.5
	# Probe from the nave through the east wall and into the apse. Starting
	# beyond the apse spring would hit its curved exterior shell and test the
	# wrong boundary.
	var nav_hit := ChurchApertures._first_hit(mesh, Vector3(0.0, 1.2, east - 0.8),
		Vector3(0.0, 1.2, east + 0.4), true)
	if not nav_hit.is_empty():
		_fail("apse entrance ray hit=%s ray=(%.2f,%.2f) to (%.2f,%.2f)" % [str(nav_hit), east - 0.8, 1.2, east + 0.4, 1.2])
	var mouth: float = ChurchGeometry.apse_springing_z(spec)
	var apse_hit := ChurchApertures._first_hit(mesh, Vector3(0.0, 1.2, mouth - 0.5),
		Vector3(0.0, 1.2, mouth + 0.5), true)
	if not apse_hit.is_empty():
		_fail("apse mouth ray hit=%s at z=%.3f y=1.2" % [str(apse_hit), mouth])
	var apse_cap_y: float = spec.height * ChurchGeometry.APSE_HEIGHT_RATIO
	var apse_roof_probe := Vector3(0.0, apse_cap_y - 0.4,
		mouth + spec.apse_radius * 0.5)
	var apse_roof_probe_top := Vector3(apse_roof_probe.x, apse_cap_y + 0.4,
		apse_roof_probe.z)
	var wall_triangles := _church_wall_triangles(mesh)
	if MeshProbe.ray_blocked(wall_triangles, apse_roof_probe, apse_roof_probe_top):
		_fail("apse vertical interior ray hits a structural wall cap at y=%.3f" % apse_cap_y)
	var arch_rows: Array[Dictionary] = []
	for row in builder.component_log:
		if String(row.get("role", "")) == "sanctuary_triumphal_arch":
			arch_rows.append(row)
	if arch_rows.size() < 8:
		_fail("apse threshold is not an articulated bearing arch")
	else:
		_check_components_emitted(mesh, arch_rows, "apse bearing arch")
		if church_style == &"gothic":
			_check_curved_arch(arch_rows)
		_check_arch_bearings(mesh, spec, builder, arch_rows)
	var crossing_half: float = ChurchGeometry.transept_depth(spec) * 0.5
	var crossing_center: float = ChurchGeometry.transept_center_z(spec)
	var crossing_hit := ChurchApertures._first_hit(mesh,
		Vector3(0.0, 1.2, crossing_center - crossing_half - 0.3),
		Vector3(0.0, 1.2, crossing_center + crossing_half + 0.3), true)
	if not crossing_hit.is_empty():
		_fail("transept box-shell blocks the processional axis")
	_check_church_clear_route(spec, builder)
	if church_style == &"nordic_stave":
		_check_stave_wall_bearings(spec, builder, mesh)
		_check_stave_roof_network(builder, mesh)
		_check_stave_material_assignment(spec, mesh)


func _check_stave_wall_bearings(spec: ChurchSpec, builder: ChurchBuilder, mesh: ArrayMesh) -> void:
	var wall_inner: float = spec.width * 0.5 - ChurchBuilder.NAVE_WALL_T
	var wood_triangles := MeshProbe.surface_triangles(builder, null, ChurchBuilder.SURF_WOOD)
	if wood_triangles.is_empty():
		_fail("nordic stave shell and posts emitted no timber surface triangles")
	var bearing_rows: Array[Dictionary] = []
	for row in builder.component_log:
		if String(row.get("role", "")) in ["stave_tie_beam", "stave_raised_rafter"]:
			bearing_rows.append(row)
	if bearing_rows.is_empty():
		_fail("nordic stave nave has no tie/rafter bearing components")
		return
	var tested_roles: Dictionary = {}
	var negative_checked: Dictionary = {}
	for row in bearing_rows:
		var row_role := String(row["role"])
		var size: Vector3 = row["size"]
		var xf: Transform3D = row["xf"]
		var e0: Vector3 = xf * Vector3(-size.x * 0.5, 0.0, 0.0)
		var e1: Vector3 = xf * Vector3(size.x * 0.5, 0.0, 0.0)
		var bearing: Vector3 = e0 if absf(e0.x) > absf(e1.x) else e1
		var side := signf(bearing.x)
		var ray_from := Vector3(side * (wall_inner - 0.24), bearing.y, bearing.z)
		var ray_to := Vector3(side * (wall_inner + 0.24), bearing.y, bearing.z)
		var component_triangles := _component_triangles(row)
		if not MeshProbe.ray_blocked(component_triangles, ray_from, ray_to):
			_fail("nordic stave %s misses the emitted wall-plane bearing segment" % row_role)
			continue
		if not MeshProbe.ray_blocked(wood_triangles, ray_from, ray_to):
			_fail("nordic stave %s bearing segment misses actual timber wall triangles" % row_role)
			continue
		tested_roles[row_role] = true
		if negative_checked.has(row_role):
			continue
		negative_checked[row_role] = true
		var shortened: Dictionary = row.duplicate()
		var moved_xf: Transform3D = xf
		moved_xf.origin.x -= side * 1.0
		shortened["xf"] = moved_xf
		var shortened_triangles := _component_triangles(shortened)
		if MeshProbe.ray_blocked(shortened_triangles, ray_from, ray_to):
			_fail("nordic stave moved-short %s bearing negative was not detected" % row_role)
	for required_role in ["stave_tie_beam", "stave_raised_rafter"]:
		if not tested_roles.has(required_role):
			_fail("nordic stave %s has no verified wall bearing" % required_role)


func _check_stave_material_assignment(spec: ChurchSpec, mesh: ArrayMesh) -> void:
	var stone_triangles := MeshProbe.surface_triangles(null, mesh, ChurchBuilder.SURF_STONE)
	if not MeshProbe.ray_blocked(stone_triangles,
			Vector3(0.0, -0.05, 0.0), Vector3(0.0, 0.05, 0.0)):
		_fail("Nordic material fixture has no actual stone floor at the nave centre")
	_check_nordic_wall_emission(spec, mesh)
	var palette := [spec.stone_color, spec.trim_color, spec.roof_color,
		Color("1a1c20"), Color.WHITE, Color.WHITE]
	var root := ShellAssembler.build("NordicMaterialContract", mesh, palette, [],
		ChurchBuilder.SURF_ROOF, false)
	ChurchAssembler._finish_nordic_timber(root, spec)
	var shell := root.get_node_or_null("Shell") as MeshInstance3D
	if shell == null:
		_fail("Nordic material fixture has no assembled shell")
		root.free()
		return
	var wood_before_surface := _logical_material_surface(shell, ChurchBuilder.SURF_WOOD)
	var wood_before_painters: Material = null
	if wood_before_surface >= 0:
		wood_before_painters = shell.get_surface_override_material(wood_before_surface)
	ChurchAssembler._finish_glazing(root)
	ChurchAssembler._finish_painted_domes(root)
	var wood_surface := -1
	var stone_surface := -1
	for surface in range(shell.mesh.get_surface_count()):
		var slot := surface
		var name: String = shell.mesh.surface_get_name(surface)
		if name.begins_with("material_slot:"):
			slot = int(name.trim_prefix("material_slot:"))
		if slot == ChurchBuilder.SURF_WOOD:
			wood_surface = surface
		elif slot == ChurchBuilder.SURF_STONE:
			stone_surface = surface
	if wood_surface < 0 or stone_surface < 0:
		_fail("Nordic timber or stone logical material slot is absent from assembled shell")
		_release_material_fixture(root, shell)
		return
	var wood_material := shell.get_surface_override_material(wood_surface)
	var floor_material := shell.get_surface_override_material(stone_surface)
	if not _stave_wood_material_preserved(shell, wood_surface, wood_before_painters) \
			or floor_material == null or wood_material == floor_material:
		_fail("Nordic timber override was changed by a later painter or replaced stone")
		_release_material_fixture(root, shell)
		return
	if DisplayServer.get_name() == "headless":
		if not wood_material is StandardMaterial3D or not floor_material is StandardMaterial3D:
			_fail("headless Nordic material fallback has an unexpected material type")
		elif absf((wood_material as StandardMaterial3D).roughness - 0.94) > 0.001 \
				or absf((floor_material as StandardMaterial3D).roughness - ShellAssembler.DEFAULT_ROUGHNESS) > 0.001 \
				or (floor_material as StandardMaterial3D).albedo_color != spec.stone_color:
			_fail("Nordic wood override was not assigned to slot 5 or altered stone paving")
	_release_material_fixture(root, shell)


func _check_nordic_wall_emission(spec: ChurchSpec, mesh: ArrayMesh) -> void:
	var wood_surface := _logical_mesh_surface(mesh, ChurchBuilder.SURF_WOOD)
	var stone_surface := _logical_mesh_surface(mesh, ChurchBuilder.SURF_STONE)
	if wood_surface < 0 or stone_surface < 0:
		_fail("Nordic nave wall probe cannot find logical wood and stone surfaces")
		return
	var wall_y := minf(2.0, spec.height * 0.25)
	var inner_x: float = spec.width * 0.5 - ChurchBuilder.NAVE_WALL_T
	var negative_from := Vector3.ZERO
	var negative_to := Vector3.ZERO
	var first_probe := true
	# Frozen 12x40 Nordic fixture: all six stations per side are below glazing
	# and between the end walls. Every point must prove the same slot contract.
	for side in [-1.0, 1.0]:
		for fraction in [-0.34, -0.27, -0.19, 0.19, 0.27, 0.34]:
			var z := spec.length * float(fraction)
			var ray_from := Vector3(float(side) * (inner_x - 0.12), wall_y, z)
			var ray_to := Vector3(float(side) * (spec.width * 0.5 + 0.12), wall_y, z)
			if not _nordic_wall_segment_has_expected_surfaces(mesh, wood_surface,
					stone_surface, ray_from, ray_to):
				_fail("Nordic side wall side=%+.0f z=%.2f is not emitted on timber slot 5 alone" \
						% [side, z])
			if first_probe:
				negative_from = ray_from
				negative_to = ray_to
				first_probe = false
	if first_probe:
		_fail("Nordic wall fixture made no fixed side-wall probes")
		return

	# Negative: select the actual timber triangles intersecting the first fixed
	# probe and re-emit those exact triangles on logical stone slot 0. A remote
	# dummy triangle keeps wood slot 5 present. The same contract must reject it.
	var wall_hit := func(a: Vector3, b: Vector3, c: Vector3) -> bool:
		return Geometry3D.segment_intersects_triangle(negative_from, negative_to, a, b, c) != null
	var reassigned := _wrong_surface_wall_control(mesh, wood_surface, wall_hit)
	var negative_wood_surface := _logical_mesh_surface(reassigned, ChurchBuilder.SURF_WOOD)
	var negative_stone_surface := _logical_mesh_surface(reassigned, ChurchBuilder.SURF_STONE)
	if reassigned == null or negative_wood_surface < 0 or negative_stone_surface < 0 \
			or not MeshProbe.ray_blocked(MeshProbe.surface_triangles(null, reassigned,
					negative_stone_surface), negative_from, negative_to):
		_fail("wrong-surface control did not reassign selected wall triangles to stone")
		return
	if _nordic_wall_segment_has_expected_surfaces(reassigned, negative_wood_surface,
			negative_stone_surface, negative_from, negative_to):
		_fail("timber-only wall contract accepted actual wall triangles assigned to stone")


func _wrong_surface_wall_control(mesh: ArrayMesh, wood_surface: int,
		wall_hit: Callable) -> ArrayMesh:
	var selected := MeshProbe.surface_triangles(null, mesh, wood_surface)
	var actual_wall := []
	for triangle in selected:
		if bool(wall_hit.call(triangle[0], triangle[1], triangle[2])):
			actual_wall.append(triangle)
	if actual_wall.is_empty():
		return null
	var wrong := ArrayMesh.new()
	var stone_arrays: Array = []
	stone_arrays.resize(Mesh.ARRAY_MAX)
	var stone_vertices := PackedVector3Array()
	for triangle in actual_wall:
		stone_vertices.append_array(PackedVector3Array(triangle))
	stone_arrays[Mesh.ARRAY_VERTEX] = stone_vertices
	wrong.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, stone_arrays)
	wrong.surface_set_name(0, "material_slot:%d" % ChurchBuilder.SURF_STONE)
	var wood_arrays: Array = []
	wood_arrays.resize(Mesh.ARRAY_MAX)
	wood_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(10000.0, 0.0, 0.0), Vector3(10001.0, 0.0, 0.0),
		Vector3(10000.0, 1.0, 0.0)])
	wrong.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, wood_arrays)
	wrong.surface_set_name(1, "material_slot:%d" % ChurchBuilder.SURF_WOOD)
	return wrong


func _nordic_wall_segment_has_expected_surfaces(mesh: ArrayMesh,
		wood_surface: int, stone_surface: int, ray_from: Vector3,
		ray_to: Vector3) -> bool:
	var wood_triangles := MeshProbe.surface_triangles(null, mesh, wood_surface)
	var stone_triangles := MeshProbe.surface_triangles(null, mesh, stone_surface)
	return MeshProbe.ray_blocked(wood_triangles, ray_from, ray_to) \
		and not MeshProbe.ray_blocked(stone_triangles, ray_from, ray_to)


func _check_painted_dome_slot_controls() -> void:
	var spec := ChurchSpec.new()
	spec.style = &"nordic_stave"
	_check_painted_dome_slot_case(spec, [0, 1, 2, 3, 5], false,
		"accent-absent compressed slot")
	_check_painted_dome_slot_case(spec, [0, 1, 2, 3, 4, 5], true,
		"accent-present adjacent slots")


func _check_painted_dome_slot_case(spec: ChurchSpec, logical_slots: Array,
		expect_accent: bool, label: String) -> void:
	var fixture_root := Node3D.new()
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	var mesh := ArrayMesh.new()
	for logical_slot in logical_slots:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
			Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_name(mesh.get_surface_count() - 1,
			"material_slot:%d" % int(logical_slot))
	shell.mesh = mesh
	fixture_root.add_child(shell)
	for surface in range(mesh.get_surface_count()):
		var base := StandardMaterial3D.new()
		base.roughness = 0.71
		shell.set_surface_override_material(surface, base)
	ChurchAssembler._finish_nordic_timber(fixture_root, spec)
	var accent_surface := _logical_material_surface(shell, ChurchBuilder.SURF_ACCENT)
	var wood_surface := _logical_material_surface(shell, ChurchBuilder.SURF_WOOD)
	if wood_surface < 0:
		_fail("%s control has no logical wood surface" % label)
		_release_material_fixture(fixture_root, shell)
		return
	var wood_material := shell.get_surface_override_material(wood_surface)
	ChurchAssembler._finish_glazing(fixture_root)
	ChurchAssembler._finish_painted_domes(fixture_root)
	if not _stave_wood_material_preserved(shell, wood_surface, wood_material):
		_fail("%s paint pass changed the logical wood material" % label)
	if expect_accent:
		if accent_surface < 0:
			_fail("%s lost its logical accent surface" % label)
		else:
			var accent_material := shell.get_surface_override_material(accent_surface)
			if not accent_material is StandardMaterial3D \
					or not (accent_material as StandardMaterial3D).vertex_color_use_as_albedo:
				_fail("%s was not painted by logical accent slot" % label)
	else:
		if accent_surface >= 0:
			_fail("%s unexpectedly contains an accent slot" % label)
		# Deliberately reproduce the former physical-index write. The same
		# wood-preservation assertion must reject this collision.
		var collision := StandardMaterial3D.new()
		collision.roughness = 0.42
		shell.set_surface_override_material(wood_surface, collision)
		if _stave_wood_material_preserved(shell, wood_surface, wood_material):
			_fail("%s collision negative did not detect a wood overwrite" % label)
	_release_material_fixture(fixture_root, shell)


func _stave_wood_material_preserved(shell: MeshInstance3D, surface: int,
		expected: Material) -> bool:
	var actual := shell.get_surface_override_material(surface)
	if expected == null or actual != expected:
		return false
	if DisplayServer.get_name() == "headless":
		return actual is StandardMaterial3D \
			and absf((actual as StandardMaterial3D).roughness - 0.94) <= 0.001
	# In a rendered run the timber is a ShaderMaterial. Identity proves that the
	# shader installed by the timber pass survived the later painters intact.
	return true


func _church_wall_triangles(mesh: ArrayMesh) -> Array:
	var out: Array = []
	for logical_slot in [ChurchBuilder.SURF_STONE, ChurchBuilder.SURF_WOOD]:
		var surface := _logical_mesh_surface(mesh, logical_slot)
		if surface >= 0:
			out.append_array(MeshProbe.surface_triangles(null, mesh, surface))
	return out


func _logical_material_surface(shell: MeshInstance3D, logical_slot: int) -> int:
	if shell.mesh == null:
		return -1
	return _logical_mesh_surface(shell.mesh as ArrayMesh, logical_slot)


func _logical_mesh_surface(mesh: ArrayMesh, logical_slot: int) -> int:
	if mesh == null:
		return -1
	for surface in range(mesh.get_surface_count()):
		var slot := surface
		var surface_name := mesh.surface_get_name(surface)
		if surface_name.begins_with("material_slot:"):
			slot = int(surface_name.trim_prefix("material_slot:"))
		if slot == logical_slot:
			return surface
	return -1


func _release_material_fixture(root: Node3D, shell: MeshInstance3D) -> void:
	if shell.mesh != null:
		for surface in range(shell.mesh.get_surface_count()):
			shell.set_surface_override_material(surface, null)
	shell.mesh = null
	if shell.get_parent() == root:
		root.remove_child(shell)
	shell.free()
	root.free()


func _component_triangles(row: Dictionary) -> Array:
	var kit := MeshKit.new(1)
	kit.oriented_box(Vector3(row["size"]), row["xf"], 0)
	var mesh: ArrayMesh = kit.commit()
	return MeshProbe.surface_triangles(null, mesh, 0)


func _check_compact_church_route(church_style: StringName) -> void:
	var spec := ChurchSpec.new()
	spec.style = church_style
	spec.width = 9.0
	spec.length = 12.0
	spec.height = 8.0
	ChurchGenerator.generate(spec, 5319)
	active_case = "church compact-route style=%s seed=%d" % [church_style, spec.seed]
	var builder := ChurchBuilder.new()
	builder.build(spec)
	_check_church_clear_route(spec, builder)


func _check_sealed_east_wall_negative(church_style: StringName) -> void:
	var spec := ChurchSpec.new()
	spec.style = church_style
	spec.width = 12.0
	spec.length = 40.0
	spec.height = 18.0
	ChurchGenerator.generate(spec, 5107)
	active_case = "church sealed-wall-negative style=%s seed=%d" % [church_style, spec.seed]
	spec.apse = false
	var builder := ChurchBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	var east: float = spec.length * 0.5
	var hit := ChurchApertures._first_hit(mesh, Vector3(0.0, 1.2, east - 0.8),
		Vector3(0.0, 1.2, east + 0.4), true)
	if hit.is_empty():
		_fail("%s sealed east-wall control was not detected by the opening probe" % church_style)


func _check_church_clear_route(spec: ChurchSpec, builder: ChurchBuilder) -> void:
	var doors: Array[Dictionary] = ChurchGeometry.west_door_layout(spec)
	var route_x: float = 0.0
	var route_half_width: float = 0.6
	if not doors.is_empty():
		route_x = float(doors[0].get("x", 0.0))
		route_half_width = maxf(float(doors[0].get("width", 1.2)) * 0.5, 0.6)
	var route := AABB(Vector3(route_x - route_half_width, -0.1,
		-spec.length * 0.5 - 0.2), Vector3(route_half_width * 2.0, 2.1, spec.length + 0.4))
	for row in builder.component_log:
		var role := String(row.get("role", ""))
		if role not in ["nave_engaged_pier", "stave_tie_beam", "stave_raised_rafter"]:
			continue
		var bounds := _box_bounds(row)
		if bounds.position.y < 2.0 and bounds.intersects(route):
			_fail("%s %s intersects the west-door human-height route" % [spec.style, role])


func _check_dome_frame_exemption(church_style: StringName) -> void:
	var spec := ChurchSpec.new()
	spec.style = church_style
	spec.width = 14.0
	spec.length = 30.0
	spec.height = 15.0
	ChurchGenerator.generate(spec, 5301)
	active_case = "church crossing-span frames style=%s seed=%d" % [church_style, spec.seed]
	spec.dome = true
	spec.dome_shape = &"hemisphere"
	spec.dome_radius = spec.width * 0.42
	spec.dome_drum_height = maxf(spec.height * 0.4, spec.dome_radius * 0.75)
	spec.dome_lantern = false
	spec.transept = true
	if spec.transept_len <= 0.0:
		spec.transept_len = spec.width * 2.2
	var builder := ChurchBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	_check_crossing_ceiling_ray(spec, mesh)
	_check_crossing_tower_bearing_contact(church_style)
	var center_z: float = ChurchGeometry.crossing_center_z(spec)
	var half_span: float = ChurchGeometry.crossing_bay_depth(spec) * 0.5
	var outside_stations: Dictionary = {}
	for row in builder.component_log:
		var host_name := String(row.get("host", ""))
		var role := String(row.get("role", ""))
		if not host_name.begins_with("nave_bay_"):
			continue
		if role not in ["nave_engaged_pier", "nave_pier_capital", "nave_transverse_arch",
				"stave_tie_beam", "stave_raised_rafter", "stave_ridge_beam", "stave_purlin"]:
			continue
		var xf: Transform3D = row["xf"]
		if absf(xf.origin.z - center_z) <= half_span + 0.05:
			_fail("crossing span received generic host=%s role=%s" % [host_name, role])
		else:
			outside_stations[host_name] = true
	if outside_stations.is_empty():
		_fail("dome-bearing church lost every nave station outside its crossing span")


func _check_crossing_tower_bearing_contact(church_style: StringName) -> void:
	active_case = "church crossing-tower local bearing contact style=%s fixed fixture" % church_style
	var spec := ChurchSpec.new()
	spec.style = church_style
	spec.width = 14.0
	spec.length = 30.0
	spec.height = 15.0
	spec.transept = true
	spec.transept_len = spec.width * 2.2
	spec.crossing_tower = true
	spec.crossing_tower_height = spec.height + 8.0
	var builder := ChurchBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	var tower: AABB = ChurchGeometry.crossing_tower_aabb(spec)
	var center_z: float = ChurchGeometry.crossing_center_z(spec)
	var actual_walls := _church_wall_triangles(mesh)
	var plate_row: Dictionary = {}
	var plate_bounds := AABB()
	var plate_probe := Vector3(tower.position.x + ChurchBuilder.NAVE_WALL_T * 0.5,
		tower.position.y - 0.11, center_z)
	for row in builder.component_log:
		if String(row.get("host", "")) != "crossing_tower_bearing" \
				or String(row.get("role", "")) != "crossing_tower_bearing_side":
			continue
		var candidate_bounds := _box_bounds(row)
		if candidate_bounds.has_point(plate_probe):
			plate_row = row
			plate_bounds = candidate_bounds
			break
	if plate_row.is_empty():
		_fail("crossing tower has no emitted side bearing at the fixed local contact station")
		return
	var component_triangles := _component_triangles(plate_row)
	var plate_keys: Dictionary = {}
	for triangle in component_triangles:
		plate_keys[_triangle_key(triangle)] = true
	var plate_body_from := Vector3(plate_bounds.position.x - 0.12,
		plate_probe.y, center_z)
	var plate_body_to := Vector3(plate_bounds.end.x + 0.12,
		plate_probe.y, center_z)
	var wall_base_from := Vector3(plate_probe.x, tower.position.y - 0.05, center_z)
	var wall_base_to := Vector3(plate_probe.x, tower.position.y + 0.01, center_z)
	var positive := _crossing_tower_local_contact(actual_walls, plate_keys,
		plate_bounds, plate_body_from, plate_body_to, wall_base_from,
		wall_base_to, tower.position.y)
	if not bool(positive["plate_body"]) or not bool(positive["wall_base"]):
		_fail("crossing tower side bearing lacks actual plate-body contact below tower base or wall-base overlap")
		return
	var without_plate := MeshProbe.remove_triangles(mesh, ChurchBuilder.SURF_STONE,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			return plate_keys.has(_triangle_key_vertices(a, b, c)))
	if int(without_plate.get("removed_triangles", 0)) < component_triangles.size():
		_fail("crossing tower local-bearing negative did not remove every actual emitted plate triangle")
		return
	var control_mesh: ArrayMesh = without_plate.get("mesh")
	var control_walls := _church_wall_triangles(control_mesh)
	var negative := _crossing_tower_local_contact(control_walls, plate_keys,
		plate_bounds, plate_body_from, plate_body_to, wall_base_from,
		wall_base_to, tower.position.y)
	if bool(negative["plate_body"]) or bool(negative["contact"]):
		_fail("crossing tower bearing negative still finds plate-body contact after exact plate removal")
	if not bool(negative["wall_base"]):
		_fail("crossing tower bearing negative removed unrelated tower-wall base triangles")


func _crossing_tower_local_contact(actual_triangles: Array, plate_keys: Dictionary,
		plate_bounds: AABB, body_from: Vector3, body_to: Vector3,
		wall_from: Vector3, wall_to: Vector3, tower_base_y: float) -> Dictionary:
	var actual_plate: Array = []
	var wall_base := false
	for triangle in actual_triangles:
		var vertices: Array = triangle
		if plate_keys.has(_triangle_key(vertices)):
			actual_plate.append(vertices)
		var hit: Variant = Geometry3D.segment_intersects_triangle(wall_from,
			wall_to, vertices[0], vertices[1], vertices[2])
		if hit != null and absf(hit.y - tower_base_y) < 0.002 \
				and plate_bounds.has_point(hit):
			wall_base = true
	var plate_body := MeshProbe.ray_blocked(actual_plate, body_from, body_to)
	return {"plate_body": plate_body, "wall_base": wall_base,
		"contact": plate_body and wall_base}


func _triangle_key(triangle: Array) -> String:
	return _triangle_key_vertices(triangle[0], triangle[1], triangle[2])


func _triangle_key_vertices(a: Vector3, b: Vector3, c: Vector3) -> String:
	var points: Array[String] = [str(_vertex_key(a)), str(_vertex_key(b)), str(_vertex_key(c))]
	points.sort()
	return "%s|%s|%s" % [points[0], points[1], points[2]]


func _check_ambulatory_architecture() -> void:
	var spec := ChurchSpec.new()
	spec.style = &"romanesque"
	spec.width = 12.0
	spec.length = 40.0
	spec.height = 18.0
	spec.apse = true
	spec.ambulatory = true
	spec.apse_radius = 5.0
	var builder := ChurchBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	var cy: float = ChurchGeometry.apse_springing_z(spec)
	var inner: float = ChurchGeometry.ambulatory_inner_radius(spec)
	var outer: float = ChurchGeometry.ambulatory_radius(spec)
	var height: float = spec.height * ChurchGeometry.AISLE_HEIGHT_RATIO
	var walk_radius: float = (inner + outer - ChurchBuilder.NAVE_WALL_T) * 0.5
	var roof_triangles := MeshProbe.surface_triangles(null, mesh, ChurchBuilder.SURF_ROOF)
	var stone_triangles := MeshProbe.surface_triangles(null, mesh, ChurchBuilder.SURF_STONE)
	var wall_triangles := _church_wall_triangles(mesh)
	var roof_y := height - 0.04
	if not MeshProbe.ray_blocked(roof_triangles,
			Vector3(0.0, roof_y - 0.3, cy + walk_radius),
			Vector3(0.0, roof_y + 0.3, cy + walk_radius)):
		_fail("ambulatory annular roof has no emitted walk-cover contact")
	var throat_from := Vector3(0.0, height - 0.2, cy + inner * 0.4)
	var throat_to := Vector3(0.0, height + 0.2, cy + inner * 0.4)
	if MeshProbe.ray_blocked(wall_triangles, throat_from, throat_to) \
			or MeshProbe.ray_blocked(roof_triangles, throat_from, throat_to):
		_fail("ambulatory wall/roof sealed the central apse throat")
	var floor_z: float = cy + walk_radius
	var floor_from := Vector3(0.0, -0.08, floor_z)
	var floor_to := Vector3(0.0, 0.08, floor_z)
	if not MeshProbe.ray_blocked(stone_triangles, floor_from, floor_to):
		_fail("ambulatory's portion beyond nave end has no actual stone paving")
	var apse_floor_z: float = spec.length * 0.5 + 0.2
	if not MeshProbe.ray_blocked(stone_triangles,
			Vector3(0.0, -0.08, apse_floor_z), Vector3(0.0, 0.08, apse_floor_z)):
		_fail("apse interior beyond nave end has no continuous stone paving")
	var detached := MeshKit.new(1)
	detached.box(Vector3(0.8, 0.1, 0.8), Vector3(0.0, 0.6, floor_z), 0)
	var detached_mesh: ArrayMesh = detached.commit()
	var detached_triangles := MeshProbe.surface_triangles(null, detached_mesh, 0)
	if MeshProbe.ray_blocked(detached_triangles, floor_from, floor_to):
		_fail("raised-floor negative control contacts the ambulatory ground datum")


func _check_stave_roof_network(builder: ChurchBuilder, mesh: ArrayMesh) -> void:
	var roofs := MeshProbe.surface_triangles(null, mesh, ChurchBuilder.SURF_ROOF)
	var counts := {"stave_ridge_beam": 0, "stave_purlin": 0}
	var moved_control := false
	for row in builder.component_log:
		var role := String(row.get("role", ""))
		if not counts.has(role):
			continue
		counts[role] += 1
		var xf: Transform3D = row["xf"]
		var size: Vector3 = row["size"]
		var x: float = 0.08 if role == "stave_ridge_beam" else xf.origin.x
		var from := Vector3(x, xf.origin.y + size.y * 0.5 + 0.01, xf.origin.z)
		var to := from + Vector3.UP * 0.25
		if not MeshProbe.ray_blocked(roofs, from, to):
			_fail("Nordic %s is not joined to emitted roof triangles" % role)
		if not moved_control:
			moved_control = true
			var below := from - Vector3.UP * 1.0
			if MeshProbe.ray_blocked(roofs, below, below + Vector3.UP * 0.25):
				_fail("moved-down Nordic roof-contact negative still reaches the roof")
	for role in counts:
		if counts[role] == 0:
			_fail("Nordic timber roof grammar is missing %s" % role)


func _check_crossing_arch_profile(spec: ChurchSpec, builder: ChurchBuilder) -> void:
	var profile: Dictionary = builder._crossing_arch_profile()
	var half_span: float = float(profile["half_span"])
	var spring: float = float(profile["spring_y"])
	var peak: float = float(profile["peak_y"])
	var kind: StringName = StringName(profile["kind"])
	var center_z: float = ChurchGeometry.transept_center_z(spec)
	var half_depth: float = ChurchGeometry.transept_depth(spec) * 0.5
	var wall_zs := [center_z - half_depth + ChurchBuilder.NAVE_WALL_T * 0.5,
		center_z + half_depth - ChurchBuilder.NAVE_WALL_T * 0.5]
	var crossing_ribs := 0
	for row in builder.component_log:
		if String(row.get("role", "")) != "nave_transverse_arch":
			continue
		var xf: Transform3D = row["xf"]
		if minf(absf(xf.origin.z - wall_zs[0]), absf(xf.origin.z - wall_zs[1])) > 0.02:
			continue
		crossing_ribs += 1
		var rib_size: Vector3 = row["size"]
		var chord_half: Vector3 = xf.basis.x * (rib_size.x / (2.0 * 1.04))
		for endpoint in [xf.origin - chord_half, xf.origin + chord_half]:
			var expected_y: float = ChurchGeometry.arch_head_y(endpoint.x,
				half_span, spring, peak, kind)
			if absf(endpoint.y - expected_y) > 0.005:
				_fail("%s crossing rib endpoint profile mismatch x=%.3f actual_y=%.3f expected_y=%.3f delta=%.3f" % [
					spec.style, endpoint.x, endpoint.y, expected_y, absf(endpoint.y - expected_y)])
	if crossing_ribs < 20:
		_fail("%s crossing did not emit both complete transverse ribs" % spec.style)
	var opening := {"u": 0.0, "width": half_span * 2.0, "y": peak * 0.5,
		"height": peak, "spring_y": spring, "arch": kind}
	var fractions: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
	for fraction in fractions:
		var offset: float = half_span * fraction
		var cut_top := builder._box_opening_top(opening, offset)
		var rib_top := ChurchGeometry.arch_head_y(offset, half_span, spring, peak, kind)
		if absf(cut_top - rib_top) > 0.001:
			_fail("%s crossing cut and rib use different span/profile data" % spec.style)
			break
	var other_kind: StringName = &"round" if kind == &"gothic" else &"gothic"
	var probe_offset := half_span * 0.75
	var correct_probe := ChurchGeometry.arch_head_y(probe_offset, half_span, spring, peak, kind)
	var wrong_probe := ChurchGeometry.arch_head_y(probe_offset, half_span, spring, peak, other_kind)
	if absf(correct_probe - wrong_probe) < 0.05:
		_fail("%s profile negative control cannot detect a mismatched opening/rib arch" % spec.style)


func _check_curved_arch(rows: Array[Dictionary]) -> void:
	var angles: Array[float] = []
	for row in rows:
		var xf: Transform3D = row["xf"]
		var angle: float = snappedf(atan2(xf.basis.x.y, xf.basis.x.x), 0.001)
		if not angles.has(angle):
			angles.append(angle)
	if angles.size() < 5:
		_fail("gothic threshold arch is straight sided, not a curved rib")
	var half_span := 2.0
	var spring := 3.0
	var peak := 4.5
	var crown_y := ChurchGeometry.arch_head_y(0.0, half_span, spring, peak, &"gothic")
	var spring_y := ChurchGeometry.arch_head_y(half_span, half_span, spring, peak, &"gothic")
	var near_crown := ChurchGeometry.arch_head_y(0.02, half_span, spring, peak, &"gothic")
	var near_spring := ChurchGeometry.arch_head_y(half_span * 0.999, half_span,
		spring, peak, &"gothic")
	var before_spring := ChurchGeometry.arch_head_y(half_span * 0.99, half_span,
		spring, peak, &"gothic")
	if absf(crown_y - peak) > 0.001 or absf(spring_y - spring) > 0.001:
		_fail("gothic wall cut does not share the arch crown and spring")
	var crown_slope := (crown_y - near_crown) / 0.02
	var spring_slope := (near_spring - before_spring) / (half_span * 0.009)
	if crown_slope <= 0.0 or crown_slope > 100.0 or absf(spring_slope) <= crown_slope:
		_fail("gothic profile lacks a finite crown angle or vertical spring tangent")


func _check_arch_bearings(mesh: ArrayMesh, spec: ChurchSpec,
		builder: ChurchBuilder, rows: Array[Dictionary]) -> void:
	var min_x := INF
	var max_x := -INF
	for row in rows:
		var bounds := _box_bounds(row)
		min_x = minf(min_x, bounds.position.x)
		max_x = maxf(max_x, bounds.end.x)
	var inner_wall: float = spec.width * 0.5 - ChurchBuilder.NAVE_WALL_T
	if min_x > -inner_wall + 0.5 or max_x < inner_wall - 0.5:
		_fail("apse arch ends do not reach the surviving nave wall returns")
	var imposts: Array[Dictionary] = []
	for component in builder.component_log:
		if component.get("host", "") == "apse_entrance_arch" \
				and component.get("role", "") == "sanctuary_arch_impost":
			imposts.append(component)
	if imposts.size() != 2:
		_fail("apse arch lacks two masonry springing imposts")
	else:
		_check_components_emitted(mesh, imposts, "apse springing imposts")
		for impost in imposts:
			var overlap: float = _check_impost_wall_overlap(mesh, spec, impost)
			if overlap < 0.02:
				_fail("apse springing impost role=%s overlap=%.3f host=%s" % [
					String(impost.get("role", "")), overlap, String(impost.get("host", ""))])
		# Move each real measured bearing box inward. The old broad arch bound
		# still passes with this 0.30m gap, but the triangle-measured contact must fail.
		var initial_overlap: float = _check_impost_wall_overlap(mesh, spec, imposts[0])
		var negative_shift: float = maxf(0.30, initial_overlap + 0.10)
		var floating: Dictionary = imposts[0].duplicate(true)
		var floating_xf: Transform3D = floating["xf"]
		var floating_side: float = signf(floating_xf.origin.x)
		floating_xf.origin.x -= floating_side * negative_shift
		floating["xf"] = floating_xf
		var coarse_min := minf(min_x, _box_bounds(floating).position.x)
		var coarse_max := maxf(max_x, _box_bounds(floating).end.x)
		if coarse_min > -inner_wall + 0.5 or coarse_max < inner_wall - 0.5:
			_fail("floating-impost control no longer falls inside the coarse 0.5m arch tolerance")
		var floating_overlap: float = _check_impost_wall_overlap(mesh, spec, floating)
		if floating_overlap >= 0.02:
			_fail("floating-impost negative control accepted overlap=%.3f, shift=%.3fm" % [
				floating_overlap, negative_shift])
	var side_return_x: float = inner_wall - 0.08
	var east: float = spec.length * 0.5
	var return_hit := ChurchApertures._first_hit(mesh,
		Vector3(side_return_x, 1.2, east + 0.5),
		Vector3(side_return_x, 1.2, east - 0.8), true)
	if return_hit.is_empty():
		_fail("arched passage removed its bearing wall returns")


func _check_temple_beams(form: StringName, cult: StringName) -> void:
	var spec: TempleSpec = TempleSweep.spec_at(form, cult, 1)
	active_case = "temple beam-bearing form=%s cult=%s sweep_index=1 seed=%d" % [form, cult, spec.seed]
	var builder := TempleBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	var beams: Array[Dictionary] = []
	for row in builder.component_log:
		var role: String = String(row.get("role", ""))
		if role in ["rotunda_ring_architrave", "column_cross_architrave",
				"column_longitudinal_architrave"]:
			beams.append(row)
	if beams.is_empty():
		_fail("%s/%s emitted no column-supported beam course" % [form, cult])
		return
	_check_components_emitted(mesh, beams, "%s/%s beam course" % [form, cult])
	if form == &"basilica":
		_check_basilica_gate_bearing(spec, builder, mesh, cult)
	for beam in beams:
		var size: Vector3 = beam["size"]
		var xf: Transform3D = beam["xf"]
		var along_axis := Vector3(0.0, 0.0, size.z * 0.5) \
			if String(beam["role"]) == "column_longitudinal_architrave" else Vector3(size.x * 0.5, 0.0, 0.0)
		var p0: Vector3 = xf * -along_axis
		var p1: Vector3 = xf * along_axis
		var bottom: float = xf.origin.y - size.y * 0.5
		for endpoint in [p0, p1]:
			var nearest: Dictionary = {}
			var best_distance := INF
			for column in spec.columns:
				var pos: Vector3 = column["pos"]
				var distance := Vector2(pos.x - endpoint.x, pos.z - endpoint.z).length()
				if distance < best_distance:
					best_distance = distance
					nearest = column
			if nearest.is_empty() or best_distance > 0.55:
				_fail("%s/%s beam endpoint does not land on a column capital" % [form, cult])
				break
			var cap_top: float = TempleGeometry.column_cap_top(nearest)
			if absf(bottom - cap_top) > 0.02:
				_fail("%s/%s beam soffit misses its column capital" % [form, cult])
				break
			var trim_triangles := MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_TRIM)
			var cap_pos: Vector3 = nearest["pos"]
			var cap_point := Vector2(cap_pos.x + 0.04, cap_pos.z + 0.03)
			if not MeshProbe.has_upward_support(trim_triangles, cap_point, cap_top, 0.02):
				_fail("%s/%s beam endpoint has no emitted upward capital face below it" % [form, cult])
				break
			if MeshProbe.has_upward_support(trim_triangles, cap_point, cap_top + 0.05, 0.02):
				_fail("%s/%s raised-capital negative remains supported above actual cap top" % [form, cult])
				break
	_check_temple_route(spec, beams, builder, mesh)
	if form == &"ziggurat":
		_check_ziggurat_approach_and_dais_boundary(spec, mesh)


func _check_compact_temple_route(form: StringName, cult: StringName) -> void:
	var spec: TempleSpec = TempleSweep.spec_at(form, cult, 0)
	active_case = "temple compact-route form=%s cult=%s sweep_index=0 seed=%d" % [form, cult, spec.seed]
	var builder := TempleBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	var beams: Array[Dictionary] = []
	for row in builder.component_log:
		if String(row.get("role", "")) in ["rotunda_ring_architrave",
				"column_cross_architrave", "column_longitudinal_architrave"]:
			beams.append(row)
	_check_temple_route(spec, beams, builder, mesh)
	if form == &"ziggurat":
		_check_ziggurat_approach_and_dais_boundary(spec, mesh)


func _check_temple_route(spec: TempleSpec, beams: Array[Dictionary],
		builder: TempleBuilder, mesh: ArrayMesh) -> void:
	var lane: Rect2 = TempleGeometry.processional_lane(spec)
	for beam in beams:
		var bounds := _box_bounds(beam)
		if bounds.position.y < 2.0 and Rect2(
				Vector2(bounds.position.x, bounds.position.z),
				Vector2(bounds.size.x, bounds.size.z)).intersects(lane):
			_fail("%s/%s architrave blocks the low processional route" % [spec.form, spec.cult])
			return
	var rite := TempleRiteCheck.new()
	var rite_report: Dictionary = rite.check(spec, builder)
	var rite_stats: Dictionary = rite_report.get("stats", {})
	var route_width: float = float(rite_stats.get("procession_width", 0.0))
	if route_width < TempleGeometry.PROCESSION_MIN - 0.06:
		_fail("%s/%s shared WalkGrid has only %.2fm of procession width" % [
			spec.form, spec.cult, route_width])
	if not _temple_mesh_route_clear(spec, mesh):
		_fail("%s/%s emitted triangles cross the sampled human-height ritual axis" % [
			spec.form, spec.cult])


func _temple_mesh_route_clear(spec: TempleSpec, mesh: ArrayMesh) -> bool:
	var triangles: Array = MeshProbe.all_triangles(null, mesh, mesh.get_surface_count())
	var entry: Vector2 = TempleGeometry.entry_point(spec)
	# This checks the horizontal approach to the first dais step. It does not
	# certify climbing the risers or reaching the raised altar platform.
	var end_z: float = TempleGeometry.dais_footprint(spec).position.y - 0.08
	if end_z <= entry.y:
		return false
	var lane: Rect2 = TempleGeometry.processional_lane(spec)
	for x_fraction in [0.25, 0.5, 0.75]:
		var x: float = lerpf(lane.position.x, lane.end.x, x_fraction)
		for height in [0.8, 1.2, 1.6]:
			var from := Vector3(x, height, entry.y)
			var to := Vector3(x, height, end_z)
			if MeshProbe.ray_blocked(triangles, from, to):
				return false
	return true


func _check_ziggurat_approach_and_dais_boundary(spec: TempleSpec, mesh: ArrayMesh) -> void:
	active_case = "ziggurat flat approach/dais boundary cult=%s seed=%d" % [spec.cult, spec.seed]
	var triangles := MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE)
	var dais: Rect2 = TempleGeometry.dais_rect(spec)
	if not MeshProbe.has_upward_support(triangles, dais.get_center(), TempleGeometry.dais_top(spec), 0.03):
		_fail("actual dais top has no emitted stone support")
	if not _temple_mesh_route_clear(spec, mesh):
		_fail("unmodified flat approach to dais edge is blocked")
		return
	var lane: Rect2 = TempleGeometry.processional_lane(spec)
	var entry: Vector2 = TempleGeometry.entry_point(spec)
	var end_z: float = TempleGeometry.dais_footprint(spec).position.y - 0.08
	var blocked := MeshProbe.add_box(mesh, TempleBuilder.SURF_STONE,
		AABB(Vector3(lane.position.x - 0.12, 0.0, (entry.y + end_z) * 0.5 - 0.10),
			Vector3(lane.size.x + 0.24, 2.0, 0.20)))
	var blocked_mesh: ArrayMesh = blocked.get("mesh")
	if blocked_mesh == null or int(blocked.get("added_triangles", 0)) != 12 \
			or _temple_mesh_route_clear(spec, blocked_mesh):
		_fail("human-height flat-approach blocker was not rejected")


func _check_impost_wall_overlap(mesh: ArrayMesh, spec: ChurchSpec,
		impost: Dictionary) -> float:
	var xf: Transform3D = impost["xf"]
	var size: Vector3 = impost["size"]
	var side: float = signf(xf.origin.x)
	var wall_inner: float = spec.width * 0.5 - ChurchBuilder.NAVE_WALL_T
	var sample_y: float = xf.origin.y + size.y * 0.35
	var from_x: float = wall_inner - 0.3
	var to_x: float = spec.width * 0.5 + 0.2
	if side < 0.0:
		from_x = -wall_inner + 0.3
		to_x = -spec.width * 0.5 - 0.2
	# wall-only excludes SURF_TRIM, where the impost and arch are emitted,
	# so this point is measured on the independent nave-wall surfaces.
	var wall_hit := ChurchApertures._first_hit(mesh,
		Vector3(from_x, sample_y, xf.origin.z), Vector3(to_x, sample_y, xf.origin.z), true)
	if wall_hit.is_empty():
		return -INF
	var outer_face_x: float = xf.origin.x + side * size.x * 0.5
	var wall_point: Vector3 = wall_hit["at"]
	return side * (outer_face_x - wall_point.x)


func _check_route_probe_negative_controls() -> void:
	active_case = "shared triangle-ray negative controls"
	# Emit a real box mesh and probe its triangles. The route gate must not pass
	# because the test merely agrees with a logged/AABB envelope.
	var church_kit := MeshKit.new(1, true)
	church_kit.box(Vector3(0.5, 1.8, 0.5), Vector3(0.0, 1.0, -4.0), 0)
	var church_mesh: ArrayMesh = church_kit.commit()
	var church_probe := Vector3(0.0, 1.0, -5.0)
	if not ChurchApertures._blocked(church_mesh, church_probe, Vector3(0.0, 1.0, -3.0)):
		_fail("church triangle-ray negative control missed an injected pier")
	var temple_kit := MeshKit.new(1, true)
	temple_kit.box(Vector3(0.6, 1.8, 0.6), Vector3(0.0, 1.0, 2.0), 0)
	var temple_mesh: ArrayMesh = temple_kit.commit()
	if not ChurchApertures._blocked(temple_mesh,
			Vector3(-1.0, 1.0, 2.0), Vector3(1.0, 1.0, 2.0)):
		_fail("temple triangle-ray negative control missed an injected low beam")
	_check_temple_mesh_route_negative()


func _check_temple_mesh_route_negative() -> void:
	var spec: TempleSpec = TempleSweep.spec_at(&"basilica", &"blood", 1)
	active_case = "temple injected-route-negative form=%s cult=%s sweep_index=1 seed=%d" % [
		spec.form, spec.cult, spec.seed]
	var builder := TempleBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	if not _temple_mesh_route_clear(spec, mesh):
		_fail("basilica route mesh negative control starts from a blocked positive")
		return
	var entry: Vector2 = TempleGeometry.entry_point(spec)
	var altar: Vector3 = TempleGeometry.altar_center(spec)
	var z: float = (entry.y + altar.z - spec.altar_l * 0.5) * 0.5
	var blocker := AABB(Vector3(-0.16, 0.65, z - 0.18), Vector3(0.32, 1.1, 0.36))
	var injected: Dictionary = MeshProbe.add_box(mesh, TempleBuilder.SURF_STONE, blocker)
	var blocked_mesh: ArrayMesh = injected.get("mesh")
	if int(injected.get("added_triangles", 0)) != 12 or blocked_mesh == null \
			or _temple_mesh_route_clear(spec, blocked_mesh):
		_fail("temple route triangle sampler missed an injected axis obstruction")


func _check_basilica_gate_bearing(spec: TempleSpec, builder: TempleBuilder,
		mesh: ArrayMesh, cult: StringName) -> void:
	var piers: Array[Dictionary] = []
	var capitals: Array[Dictionary] = []
	var lintels: Array[Dictionary] = []
	for row in builder.component_log:
		match String(row.get("role", "")):
			"basilica_gate_pier": piers.append(row)
			"basilica_gate_capital": capitals.append(row)
			"basilica_gate_lintel": lintels.append(row)
	if piers.size() != 2 or capitals.size() != 2 or lintels.size() != 1:
		_fail("basilica/%s gate load path lost its paired piers, capitals or lintel" % cult)
		return
	_check_components_emitted(mesh, piers + capitals + lintels, "basilica gate bearing")
	var cap_top := INF
	var cap_bottom := INF
	for cap in capitals:
		var cap_box := _box_bounds(cap)
		cap_top = minf(cap_top, cap_box.end.y)
		cap_bottom = minf(cap_bottom, cap_box.position.y)
	for pier in piers:
		var pier_box := _box_bounds(pier)
		if absf(pier_box.end.y - cap_bottom) > 0.02:
			_fail("basilica/%s gate pier shaft stops before its capital" % cult)
			break
	var lintel_box := _box_bounds(lintels[0])
	if absf(lintel_box.position.y - cap_top) > 0.02:
		_fail("basilica/%s lintel soffit is disconnected from the capitals" % cult)
	var site := TempleGeometry.site_rect(spec)
	var gate_half: float = TempleGeometry.GATE_W * 0.5 + spec.wall_t * 0.35
	var ped_half: float = gate_half + 1.2
	var ped_base_y: float = lintel_box.end.y
	var front: float = site.position.y
	var ent_h: float = clampf(spec.height * 0.11, 0.8, 1.6)
	var ent_y: float = spec.height - ent_h
	var ped_rise: float = ped_half * 0.32
	if ped_base_y + ped_rise < ent_y - 0.2 and (not _mesh_has_vertex(mesh,
			Vector3(-ped_half, ped_base_y, front), 0.02) \
			or not _mesh_has_vertex(mesh, Vector3(ped_half, ped_base_y, front), 0.02)):
		_fail("basilica/%s gate pediment base does not sit on the lintel top" % cult)


func _mesh_has_vertex(mesh: ArrayMesh, target: Vector3, tolerance: float) -> bool:
	for surface_index in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if vertex.distance_to(target) <= tolerance:
				return true
	return false


func _check_components_emitted(mesh: ArrayMesh, rows: Array[Dictionary], label: String) -> void:
	for row in rows:
		if String(row.get("form", "")) != "box":
			_fail("%s contains an unverified non-box component" % label)
			return
		var logical_surface := int(row.get("surface", -1))
		var surface: int = _logical_mesh_surface(mesh, logical_surface)
		if surface < 0 or surface >= mesh.get_surface_count():
			_fail("%s component names a missing mesh surface" % label)
			return
		# Re-emit the recorded shape into an isolated mesh, then compare the
		# exact winding-sensitive triangle multiset on the recorded surface.
		var kit := MeshKit.new(1)
		kit.oriented_box(Vector3(row["size"]), row["xf"], 0)
		var expected_mesh: ArrayMesh = kit.commit()
		var expected := _surface_vertex_soup(expected_mesh, 0)
		var actual := _surface_vertex_soup(mesh, surface)
		if ComponentCheck.missing_triangles(actual, expected) > 0:
			_fail("%s exact emitted triangles differ from its component record" % label)
			return


func _surface_vertex_soup(mesh: ArrayMesh, surface: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for triangle in MeshProbe.surface_triangles(null, mesh, surface):
		for point in triangle:
			out.append(point)
	return out


func _box_bounds(row: Dictionary) -> AABB:
	var xf: Transform3D = row["xf"]
	var size: Vector3 = row["size"]
	var result := AABB()
	var first := true
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var p: Vector3 = xf * Vector3(size.x * sx * 0.5,
					size.y * sy * 0.5, size.z * sz * 0.5)
				if first:
					result = AABB(p, Vector3.ZERO)
					first = false
				else:
					result = result.expand(p)
	return result


func _vertex_key(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x * 500.0), roundi(point.y * 500.0), roundi(point.z * 500.0))

func _check_crossing_ceiling_ray(spec: ChurchSpec, mesh: ArrayMesh) -> void:
	if not spec.transept:
		_fail("dome ceiling probe has no transept crossing host")
		return
	var center_z: float = ChurchGeometry.crossing_center_z(spec)
	var ray_from := Vector3(0.0, spec.height - 0.4, center_z)
	var ray_to := Vector3(0.0, spec.height + 0.4, center_z)
	var walls := _church_wall_triangles(mesh)
	if MeshProbe.ray_blocked(walls, ray_from, ray_to):
		_fail("dome crossing contains a solid wall-surface ceiling at y=%.3f" % spec.height)
	var control_kit := MeshKit.new(1)
	control_kit.slab_poly(PackedVector3Array([
		Vector3(-1.0, spec.height, center_z - 1.0),
		Vector3(1.0, spec.height, center_z - 1.0),
		Vector3(1.0, spec.height, center_z + 1.0),
		Vector3(-1.0, spec.height, center_z + 1.0)]), 0.1, ChurchBuilder.SURF_STONE, true)
	var control_mesh: ArrayMesh = control_kit.commit()
	var control_walls := _church_wall_triangles(control_mesh)
	if not MeshProbe.ray_blocked(control_walls, ray_from, ray_to):
		_fail("closed-ceiling injected control was missed by the vertical crossing ray")
