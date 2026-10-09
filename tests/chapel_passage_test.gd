extends SceneTree
## Physical chapel-mouth contract. Uses emitted structural and floor triangles.

const Apertures = preload("res://tests/suites/church_aperture_suite.gd")

var result := SuiteResult.new("chapel passage")
var multi_panel_mouths := 0


func _initialize() -> void:
	var chartres := ChurchSpec.new()
	chartres.style = &"gothic"
	chartres.width = 16.4
	chartres.length = 130.0
	chartres.height = 37.5
	ChurchGenerator.generate(chartres, 5003)
	LandmarkSuite._force_features("chartres", chartres)
	_check_case("Chartres", chartres, true)

	var generated: ChurchSpec = _generated_ambulatory_case()
	_expect(generated != null,
		"fixed seed window contained no generated apse+ambulatory+chevet chapel plan")
	if generated != null:
		_check_case("generated seed %d" % generated.seed, generated, false)
	if multi_panel_mouths == 0:
		var small_multi_panel: ChurchSpec = _generated_small_multi_panel_case()
		_expect(small_multi_panel != null,
			"no frozen case crosses an annular panel seam and no small-radius fixture was found")
		if small_multi_panel != null:
			_check_case("small-radius multi-panel seed %d" % small_multi_panel.seed,
				small_multi_panel, false)
	_check_closed_chapel_end_control(chartres)

	print("chapel passage fixture: %s (%d checks, %d failures)" % [
		"PASS" if result.ok() else "FAIL", result.checked, result.failures.size()])
	for failure in result.failures:
		push_error(failure)
	quit(0 if result.ok() else 1)


func _generated_ambulatory_case() -> ChurchSpec:
	for seed in range(5000, 5400):
		var candidate := ChurchSpec.new()
		candidate.style = &"gothic"
		candidate.width = 12.0
		candidate.length = 80.0
		candidate.height = 24.0
		ChurchGenerator.generate(candidate, seed)
		if candidate.apse and candidate.ambulatory \
				and candidate.radiating_chapels > 0 \
				and candidate.chapel_arrangement == &"chevet" \
				and candidate.chapel_radius >= 0.5:
			return candidate
	return null


func _generated_small_multi_panel_case() -> ChurchSpec:
	for seed in range(5000, 5400):
		var candidate := ChurchSpec.new()
		candidate.style = &"gothic"
		candidate.width = 8.0
		candidate.length = 24.0
		candidate.height = 12.0
		ChurchGenerator.generate(candidate, seed)
		if not candidate.apse or not candidate.ambulatory \
				or candidate.radiating_chapels <= 0 \
				or candidate.chapel_arrangement != &"chevet":
			continue
		var wall_inner: float = ChurchGeometry.ambulatory_radius(candidate) \
			- ChurchBuilder.NAVE_WALL_T
		for index in range(candidate.radiating_chapels):
			var center: float = PI * 0.5 - ChurchGeometry.chapel_angle(candidate, index)
			var half: float = ChurchGeometry.chapel_mouth_half_angle(
				candidate, index, wall_inner)
			for panel in range(1, 20):
				var seam: float = PI * float(panel) / 20.0
				if seam > center - half + 0.00001 and seam < center + half - 0.00001:
					return candidate
	return null


func _check_case(label: String, spec: ChurchSpec, add_fault_controls: bool) -> void:
	_expect(spec.apse and spec.ambulatory and spec.radiating_chapels > 0 \
		and spec.chapel_arrangement == &"chevet",
		"%s does not exercise an ambulatory chevet" % label)
	if not spec.apse or not spec.ambulatory or spec.radiating_chapels <= 0:
		return
	var builder := ChurchBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	var mass_rows: Dictionary = {}
	for mass in builder.mass_log:
		mass_rows[String(mass["name"])] = mass["aabb"]
	_expect(mass_rows.has("ambulatory"), "%s lost the ambulatory shell mass record" % label)
	for index in range(spec.radiating_chapels):
		var mass_name := "chapel_%d" % index
		_expect(mass_rows.has(mass_name), "%s lost chapel shell mass %s" % [label, mass_name])
		if mass_rows.has(mass_name):
			var expected: AABB = ChurchGeometry.chapel_aabb(spec, index)
			var actual: AABB = mass_rows[mass_name]
			_expect(actual.position.distance_to(expected.position) < 0.001
				and actual.size.distance_to(expected.size) < 0.001,
				"%s changed chapel %d shell mass bounds" % [label, index])
	var outer_radius: float = ChurchGeometry.ambulatory_radius(spec)
	var wall_inner: float = outer_radius - ChurchBuilder.NAVE_WALL_T
	var cy: float = ChurchGeometry.apse_springing_z(spec)
	var origin := Vector3(0.0, 0.0, cy)
	var aperture_count := 0
	for part in builder.part_log:
		if part.get("kind", "") != "window" or part.get("tag", "") != "chapel":
			continue
		aperture_count += 1
		Apertures._check_opening(result, mesh, builder, part.pos, float(part.rot_y),
			float(part.size.x), float(part.size.y), "%s chapel window" % label)
	_expect(aperture_count == spec.radiating_chapels,
		"%s has %d chapel through-windows for %d shells" % [
			label, aperture_count, spec.radiating_chapels])

	for chapel_index in range(spec.radiating_chapels):
		var angle: float = ChurchGeometry.chapel_angle(spec, chapel_index)
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		var tangent := Vector3(cos(angle), 0.0, -sin(angle))
		var center: Vector3 = ChurchGeometry.chapel_center(spec, chapel_index)
		var width: float = ChurchGeometry.chapel_mouth_width(spec, chapel_index)
		var center_theta: float = PI * 0.5 - angle
		var mouth_half: float = ChurchGeometry.chapel_mouth_half_angle(
			spec, chapel_index, wall_inner)
		var crossed_seams := 0
		for panel in range(1, 20):
			var seam: float = PI * float(panel) / 20.0
			if seam <= center_theta - mouth_half + 0.00001 \
					or seam >= center_theta + mouth_half - 0.00001:
				continue
			crossed_seams += 1
			var seam_direction := Vector3(cos(seam), 0.0, sin(seam))
			var seam_start := origin + seam_direction * (outer_radius + 0.16) \
				+ Vector3.UP * 1.2
			var seam_end := origin + seam_direction * (wall_inner - 0.16) \
				+ Vector3.UP * 1.2
			_expect(Apertures._first_hit(mesh, seam_start, seam_end, true).is_empty(),
				"%s chapel %d mouth is blocked at actual annular panel seam %.4f" % [
					label, chapel_index, seam])
		multi_panel_mouths += crossed_seams
		var target_height: float = 1.2
		var start_radial: float = wall_inner - 0.16
		var end_radial: float = ChurchGeometry.chapel_reach_at(spec, chapel_index) \
			+ spec.chapel_radius * 0.68
		for lateral in [-width * 0.32, 0.0, width * 0.32]:
			var route_start: Vector3 = origin + direction * start_radial + tangent * lateral \
				+ Vector3.UP * target_height
			var route_end: Vector3 = center + direction * (spec.chapel_radius * 0.68) \
				+ tangent * lateral + Vector3.UP * target_height
			var wall_hit: Dictionary = Apertures._first_hit(mesh, route_start, route_end, true)
			_expect(wall_hit.is_empty(),
				"%s chapel %d body-width route at lateral %.3f hits structural wall" % [
					label, chapel_index, lateral])
			_check_floor_line(label, spec, mesh, origin, direction, tangent,
				lateral, start_radial, end_radial, chapel_index)
		_check_threshold_floor_full_footprint(label, spec, mesh, chapel_index,
			add_fault_controls and chapel_index == 0)

		# A nearby lane through the uncut wall must remain masonry.
		var outside_lateral: float = width * 0.5 + 0.2
		var near_start := origin + direction * start_radial \
			+ tangent * outside_lateral + Vector3.UP * target_height
		var near_end := center + direction * 0.12 \
			+ tangent * outside_lateral + Vector3.UP * target_height
		_expect(not Apertures._first_hit(mesh, near_start, near_end, true).is_empty(),
			"%s chapel %d removed adjacent annular wall outside the planned opening" % [
				label, chapel_index])

		# Preserve actual curved chapel shell at a solid, non-window bay.
		var arc: float = ChurchGeometry.chapel_arc_start(spec, chapel_index) \
			+ PI * 2.5 / 7.0
		var shell_normal := Vector3(cos(arc), 0.0, sin(arc))
		var shell_point := center + shell_normal * (spec.chapel_radius - 0.03) \
			+ Vector3.UP * target_height
		_expect(not Apertures._first_hit(mesh, shell_point + shell_normal * 0.35,
			shell_point - shell_normal * 0.35, true).is_empty(),
			"%s chapel %d lost its measured curved shell bay" % [label, chapel_index])

	if add_fault_controls:
		_check_inserted_wall_control(label, spec, mesh, origin, wall_inner,
			outer_radius)
		_check_removed_wall_control(label, spec, mesh, origin, wall_inner,
			outer_radius)


func _check_threshold_floor_full_footprint(label: String, spec: ChurchSpec,
		mesh: ArrayMesh, chapel_index: int, add_removal_negative: bool) -> void:
	var polygon: PackedVector2Array = _threshold_floor_polygon(spec, chapel_index)
	var triangulation: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	if triangulation.is_empty() or triangulation.size() % 3 != 0:
		_expect(false, "%s chapel %d threshold polygon did not triangulate" % [label, chapel_index])
		return
	var expected_area: float = _polygon_area(polygon)
	if expected_area <= 0.01:
		_expect(false, "%s chapel %d threshold polygon has no physical area" % [label, chapel_index])
		return
	var samples: Array[Vector2] = _threshold_footprint_samples(polygon, triangulation)
	var stone: Array = MeshProbe.surface_triangles(null, mesh, ChurchBuilder.SURF_STONE)
	var misses := 0
	for point in samples:
		if not MeshProbe.has_upward_support(stone, point, ChurchGeometry.FLOOR_LIFT, 0.002):
			misses += 1
	_expect(misses == 0,
		"%s chapel %d emitted threshold does not support its full footprint (%d/%d missing)" % [
			label, chapel_index, misses, samples.size()])
	var emitted_area: float = _upward_floor_area_in_polygon(stone, polygon)
	_expect(absf(emitted_area - expected_area) <= maxf(0.02, expected_area * 0.005),
		"%s chapel %d upward threshold triangles cover %.3fm2 of %.3fm2 plan" % [
			label, chapel_index, emitted_area, expected_area])
	if not add_removal_negative:
		return
	var removed := MeshProbe.remove_triangles(mesh, ChurchBuilder.SURF_STONE,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			var face: Vector3 = (c - a).cross(b - a)
			var center: Vector3 = (a + b + c) / 3.0
			return face.length_squared() > 1e-12 \
				and face.normalized().dot(Vector3.UP) > 0.95 \
				and absf(a.y - ChurchGeometry.FLOOR_LIFT) <= 0.002 \
				and absf(b.y - ChurchGeometry.FLOOR_LIFT) <= 0.002 \
				and absf(c.y - ChurchGeometry.FLOOR_LIFT) <= 0.002 \
				and Geometry2D.is_point_in_polygon(Vector2(center.x, center.z), polygon))
	_expect(int(removed.get("removed_triangles", 0)) >= triangulation.size() / 3,
		"%s threshold-removal control did not remove the emitted bridge triangles" % label)
	if removed.get("mesh") == null:
		_expect(false, "%s threshold-removal control produced no mutated mesh" % label)
		return
	var after: Array = MeshProbe.surface_triangles(null, removed["mesh"],
		ChurchBuilder.SURF_STONE)
	var after_misses := 0
	for point in samples:
		if not MeshProbe.has_upward_support(after, point, ChurchGeometry.FLOOR_LIFT, 0.002):
			after_misses += 1
	_expect(after_misses > 0,
		"%s removed-bridge negative retained full-footprint upward support" % label)
	var remaining_area: float = _upward_floor_area_in_polygon(after, polygon)
	_expect(remaining_area < expected_area * 0.1,
		"%s removed-bridge negative retained %.3fm2 of %.3fm2 support area" % [
			label, remaining_area, expected_area])


func _threshold_floor_polygon(spec: ChurchSpec, chapel_index: int) -> PackedVector2Array:
	var segments := 20
	var cy: float = ChurchGeometry.apse_springing_z(spec)
	var origin := Vector3(0.0, 0.0, cy)
	var wall_inner: float = ChurchGeometry.ambulatory_radius(spec) - ChurchBuilder.NAVE_WALL_T
	var angle: float = ChurchGeometry.chapel_angle(spec, chapel_index)
	var center_theta: float = PI * 0.5 - angle
	var half_angle: float = ChurchGeometry.chapel_mouth_half_angle(spec,
		chapel_index, wall_inner)
	var theta0: float = center_theta - half_angle
	var theta1: float = center_theta + half_angle
	var points := PackedVector2Array()
	points.append(_threshold_floor_boundary(origin, wall_inner, theta0, segments))
	for panel in range(1, segments):
		var seam: float = PI * float(panel) / float(segments)
		if seam > theta0 + 0.00001 and seam < theta1 - 0.00001:
			points.append(_threshold_floor_boundary(origin, wall_inner, seam, segments))
	points.append(_threshold_floor_boundary(origin, wall_inner, theta1, segments))
	var center: Vector3 = ChurchGeometry.chapel_center(spec, chapel_index)
	var half_width: float = ChurchGeometry.chapel_mouth_width(spec, chapel_index) * 0.5
	var tangent := Vector3(cos(angle), 0.0, -sin(angle))
	var mouth_left: Vector3 = center - tangent * half_width
	var mouth_right: Vector3 = center + tangent * half_width
	points.append(Vector2(mouth_left.x, mouth_left.z))
	points.append(Vector2(mouth_right.x, mouth_right.z))
	return points


func _threshold_floor_boundary(origin: Vector3, radius: float, theta: float,
		segments: int) -> Vector2:
	var segment: int = clampi(floori(theta / PI * float(segments)), 0, segments - 1)
	var a0: float = PI * float(segment) / float(segments)
	var a1: float = PI * float(segment + 1) / float(segments)
	var p0 := origin + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
	var p1 := origin + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
	var t: float = (theta - a0) / (a1 - a0)
	var point: Vector3 = p0.lerp(p1, t)
	return Vector2(point.x, point.z)


func _threshold_footprint_samples(polygon: PackedVector2Array,
		triangulation: PackedInt32Array) -> Array[Vector2]:
	var samples: Array[Vector2] = []
	var low := polygon[0]
	var high := polygon[0]
	for point in polygon:
		low.x = minf(low.x, point.x); low.y = minf(low.y, point.y)
		high.x = maxf(high.x, point.x); high.y = maxf(high.y, point.y)
	# Regular body-independent mesh coverage across the whole polygon, plus each
	# exact triangulation cell centre so narrow slivers cannot evade the lattice.
	var spacing := 0.08
	var nx: int = ceili((high.x - low.x) / spacing)
	var nz: int = ceili((high.y - low.y) / spacing)
	for ix in range(nx + 1):
		for iz in range(nz + 1):
			var point := Vector2(minf(low.x + (float(ix) + 0.5) * spacing, high.x),
				minf(low.y + (float(iz) + 0.5) * spacing, high.y))
			if Geometry2D.is_point_in_polygon(point, polygon):
				samples.append(point)
	for tri in range(0, triangulation.size(), 3):
		var a: Vector2 = polygon[triangulation[tri]]
		var b: Vector2 = polygon[triangulation[tri + 1]]
		var c: Vector2 = polygon[triangulation[tri + 2]]
		samples.append((a + b + c) / 3.0)
		samples.append(a.lerp(b, 0.5))
		samples.append(b.lerp(c, 0.5))
		samples.append(c.lerp(a, 0.5))
	return samples


func _polygon_area(polygon: PackedVector2Array) -> float:
	var twice_area := 0.0
	for index in range(polygon.size()):
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % polygon.size()]
		twice_area += a.x * b.y - a.y * b.x
	return absf(twice_area) * 0.5


func _upward_floor_area_in_polygon(triangles: Array,
		polygon: PackedVector2Array) -> float:
	var area := 0.0
	for triangle in triangles:
		var a: Vector3 = triangle[0]
		var b: Vector3 = triangle[1]
		var c: Vector3 = triangle[2]
		var face: Vector3 = (c - a).cross(b - a)
		var center: Vector3 = (a + b + c) / 3.0
		if face.length_squared() <= 1e-12 or face.normalized().dot(Vector3.UP) <= 0.95 \
				or absf(a.y - ChurchGeometry.FLOOR_LIFT) > 0.002 \
				or absf(b.y - ChurchGeometry.FLOOR_LIFT) > 0.002 \
				or absf(c.y - ChurchGeometry.FLOOR_LIFT) > 0.002 \
				or not Geometry2D.is_point_in_polygon(Vector2(center.x, center.z), polygon):
			continue
		var twice: float = absf((b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x))
		area += twice * 0.5
	return area


func _check_closed_chapel_end_control(spec: ChurchSpec) -> void:
	# With the ambulatory absent there is no matching wall cut. The radiating
	# chapel must retain its physical radial end cap.
	var original_ambulatory: bool = spec.ambulatory
	spec.ambulatory = false
	if spec.radiating_chapels <= 0:
		spec.ambulatory = original_ambulatory
		_expect(false, "closed-end control has no radiating chapel")
		return
	# The shell center depends on the layout. Measure it under the same
	# no-ambulatory state used for this build, before restoring the caller spec.
	var center: Vector3 = ChurchGeometry.chapel_center(spec, 0)
	var start_angle: float = ChurchGeometry.chapel_arc_start(spec, 0)
	var builder := ChurchBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	spec.ambulatory = original_ambulatory
	var radial := Vector3(cos(start_angle), 0.0, sin(start_angle))
	var tangent := Vector3(-radial.z, 0.0, radial.x)
	var plane_point := center + radial * (spec.chapel_radius * 0.5) + Vector3.UP * 1.0
	var hit: Dictionary = Apertures._first_hit(mesh,
		plane_point + tangent * 0.25, plane_point - tangent * 0.25, true)
	_expect(not hit.is_empty(),
		"chapel end cap disappeared when there was no matching ambulatory opening")


func _check_floor_line(label: String, spec: ChurchSpec, mesh: ArrayMesh,
		origin: Vector3, direction: Vector3, tangent: Vector3, lateral: float,
		start_radial: float, end_radial: float, chapel_index: int) -> void:
	var stone: Array = MeshProbe.surface_triangles(null, mesh, ChurchBuilder.SURF_STONE)
	var distance: float = end_radial - start_radial
	var steps: int = maxi(1, ceili(distance / 0.12))
	for step in range(steps + 1):
		var radial: float = lerpf(start_radial, end_radial, float(step) / float(steps))
		var point: Vector3 = origin + direction * radial + tangent * lateral
		var supported: bool = MeshProbe.has_upward_support(
			stone,
			Vector2(point.x, point.z), ChurchGeometry.FLOOR_LIFT, 0.002)
		_expect(supported,
			"%s chapel %d lacks an actual upward floor face at lateral %.3f radial %.3f" % [
				label, chapel_index, lateral, radial])


func _check_inserted_wall_control(label: String, spec: ChurchSpec, mesh: ArrayMesh,
		origin: Vector3, wall_inner: float, outer_radius: float) -> void:
	var chapel_index := 0
	var angle: float = ChurchGeometry.chapel_angle(spec, chapel_index)
	var direction := Vector3(sin(angle), 0.0, cos(angle))
	var width: float = ChurchGeometry.chapel_mouth_width(spec, chapel_index)
	var center: Vector3 = ChurchGeometry.chapel_center(spec, chapel_index)
	var a := origin + direction * (wall_inner - 0.16) + Vector3.UP * 1.2
	var b := center + direction * 0.18 + Vector3.UP * 1.2
	_expect(Apertures._first_hit(mesh, a, b, true).is_empty(),
		"%s positive route is blocked before wall-plug control" % label)
	var plug := MeshKit.new(1)
	var radial_center := origin + direction * ((wall_inner + outer_radius) * 0.5) \
		+ Vector3.UP * (ChurchGeometry.chapel_mouth_height(spec, chapel_index) * 0.5)
	plug.box(Vector3(width + 0.1, ChurchGeometry.chapel_mouth_height(spec, chapel_index) + 0.1,
		ChurchBuilder.NAVE_WALL_T + 0.1), radial_center, ChurchBuilder.SURF_STONE, angle)
	_expect(not Apertures._first_hit(plug.commit(), a, b, true).is_empty(),
		"%s actual inserted wall plug did not block the same route ray" % label)


func _check_removed_wall_control(label: String, spec: ChurchSpec, mesh: ArrayMesh,
		origin: Vector3, wall_inner: float, outer_radius: float) -> void:
	var segments := 20
	var height: float = spec.height * ChurchGeometry.AISLE_HEIGHT_RATIO
	var found := false
	for segment in range(segments):
		var a0: float = PI * float(segment) / float(segments)
		var a1: float = PI * float(segment + 1) / float(segments)
		var theta: float = (a0 + a1) * 0.5
		var blocked_by_cut := false
		for chapel_index in range(spec.radiating_chapels):
			var center_theta: float = PI * 0.5 - ChurchGeometry.chapel_angle(spec, chapel_index)
			var half: float = ChurchGeometry.chapel_mouth_half_angle(spec, chapel_index, wall_inner)
			if theta >= center_theta - half - 0.02 and theta <= center_theta + half + 0.02:
				blocked_by_cut = true
				break
		if blocked_by_cut:
			continue
		var start := origin + Vector3(cos(theta), 0.0, sin(theta)) \
			* (outer_radius + 0.25) + Vector3.UP * 1.2
		var finish := origin + Vector3(cos(theta), 0.0, sin(theta)) \
			* (wall_inner - 0.2) + Vector3.UP * 1.2
		var original_hit: Dictionary = Apertures._first_hit(mesh, start, finish, true)
		if original_hit.is_empty() or not _triangle_in_panel(original_hit["triangle"],
			origin, wall_inner, outer_radius, height, a0, a1):
			continue
		var mutation: Dictionary = _remove_wall_panel(mesh, origin, wall_inner,
			outer_radius, height, a0, a1)
		var changed: ArrayMesh = mutation["mesh"]
		if int(mutation["removed"]) <= 0:
			continue
		if Apertures._first_hit(changed, start, finish, true).is_empty():
			found = true
			break
	_expect(found,
		"%s actual emitted annular-wall panel removal did not clear its support ray" % label)


func _remove_wall_panel(mesh: ArrayMesh, origin: Vector3, wall_inner: float,
		outer_radius: float, height: float, a0: float, a1: float) -> Dictionary:
	var changed := ArrayMesh.new()
	var removed := 0
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface).duplicate(true)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
			if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for vertex_index in range(vertices.size()):
				indices.append(vertex_index)
		var kept := PackedInt32Array()
		for tri in range(0, indices.size(), 3):
			var points := [vertices[indices[tri]], vertices[indices[tri + 1]],
				vertices[indices[tri + 2]]]
			if _triangle_in_panel(points, origin, wall_inner, outer_radius,
				height, a0, a1):
				removed += 1
			else:
				kept.append(indices[tri]); kept.append(indices[tri + 1]); kept.append(indices[tri + 2])
		if kept.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = kept
		var new_surface: int = changed.get_surface_count()
		changed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material: Material = mesh.surface_get_material(surface)
		if material != null:
			changed.surface_set_material(new_surface, material)
		var surface_name: String = mesh.surface_get_name(surface)
		if not surface_name.is_empty():
			changed.surface_set_name(new_surface, surface_name)
	return {"mesh": changed, "removed": removed}


func _triangle_in_panel(points: Array, origin: Vector3, wall_inner: float,
		outer_radius: float, height: float, a0: float, a1: float) -> bool:
	var lo_y := INF
	var hi_y := -INF
	for point_value in points:
		var point: Vector3 = point_value
		var radius: float = Vector2(point.x, point.z - origin.z).length()
		var theta: float = atan2(point.z - origin.z, point.x)
		if radius < wall_inner - 0.025 or radius > outer_radius + 0.025 \
				or theta < a0 - 0.0001 or theta > a1 + 0.0001 \
				or point.y < -0.02 or point.y > height + 0.02:
			return false
		lo_y = minf(lo_y, point.y)
		hi_y = maxf(hi_y, point.y)
	return hi_y > 0.2 and lo_y < height - 0.2


func _expect(good: bool, complaint: String) -> void:
	result.checked += 1
	if not good:
		result.fail(complaint)
