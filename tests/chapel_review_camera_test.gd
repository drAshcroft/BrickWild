extends SceneTree
## Native framing and clearance checks for the Gothic chevet review cameras.

const CameraFixture = preload("res://tests/fixtures/chapel_review_camera_fixture.gd")
const ApertureProbe = preload("res://tests/suites/church_aperture_suite.gd")
const LandmarkSuite = preload("res://tests/suites/landmark_suite.gd")
const EXPECTED_CASES := 2
const EXPECTED_CHECKS := 1 + EXPECTED_CASES * 12
var result := SuiteResult.new("chapel review camera")
var _completed_cases := 0


func _initialize() -> void:
	var generated := ChurchSpec.new()
	generated.style = &"gothic"
	generated.width = 12.0
	generated.length = 80.0
	generated.height = 24.0
	ChurchGenerator.generate(generated, 5001)
	var chartres := ChurchSpec.new()
	chartres.style = &"gothic"
	chartres.width = 16.4
	chartres.length = 130.0
	chartres.height = 37.5
	ChurchGenerator.generate(chartres, 5003)
	LandmarkSuite._force_features("chartres", chartres)
	var cases: Array[ChurchSpec] = [generated, chartres]
	var valid_cases := true
	for spec in cases:
		valid_cases = valid_cases and spec.apse and spec.ambulatory \
			and spec.radiating_chapels > 0 and spec.chapel_arrangement == &"chevet"
	_check(valid_cases,
		"generated and Chartres requests no longer supply the camera fixture chevet cases")
	if valid_cases:
		for spec in cases:
			var builder := ChurchBuilder.new()
			var mesh: ArrayMesh = builder.build(spec)
			var placements: Array[Dictionary] = ChurchFurnisher.dress(spec)
			_print_chapel_diagnostic(spec, 0, placements)
			_check_case(spec, 0, mesh, placements)
	if _completed_cases != EXPECTED_CASES or result.checked != EXPECTED_CHECKS:
		result.fail("camera fixture did not complete all cases/checks (%d/%d cases, %d/%d checks)" % [
			_completed_cases, EXPECTED_CASES, result.checked, EXPECTED_CHECKS])
	print("chapel review camera fixture: %s (%d checks, %d failures)" % [
		"PASS" if result.ok() else "FAIL", result.checked, result.failures.size()])
	for failure in result.failures:
		push_error(failure)
	quit(0 if result.ok() else 1)


func _check_case(spec: ChurchSpec, chapel_index: int, mesh: ArrayMesh,
		placements: Array[Dictionary]) -> void:
	if not _camera_views_complete(spec, chapel_index, placements):
		_check(false, "chapel %d camera view is missing required fields or a measured-clear station" % chapel_index)
		return
	var radial: Vector3 = CameraFixture.radial(spec, chapel_index)
	var center: Vector3 = ChurchGeometry.chapel_center(spec, chapel_index)
	var ring_center := Vector3(0.0, 0.0, ChurchGeometry.chapel_ring_center_z(spec))
	_check((center - ring_center).normalized().dot(radial) > 0.999,
		"chapel %d radial camera axis does not match the mouth center" % chapel_index)
	var view: Dictionary = CameraFixture.ambulatory_view(spec, chapel_index)
	var eye: Vector3 = view["eye"]
	var target: Vector3 = view["target"]
	var clearance: Dictionary = view["clearance"]
	_check((target - eye).normalized().dot(radial) > 0.8,
		"ambulatory eye does not look outward through chapel %d mouth" % chapel_index)
	_check(float(clearance["body_clearance_inner_m"]) >= -0.001,
		"ambulatory eye body overlaps the apse floor boundary")
	_check(float(clearance["body_clearance_outer_m"]) >= -0.001,
		"ambulatory eye body overlaps the ring wall inner face")
	_check(absf(eye.y - (float(clearance["floor_top_y_m"]) + 1.53)) < 0.01,
		"ambulatory eye height did not follow the emitted floor plane")
	var chapel_view: Dictionary = CameraFixture.chapel_view(spec, chapel_index, placements)
	var chapel_eye: Vector3 = chapel_view["eye"]
	var chapel_target: Vector3 = chapel_view["target"]
	var chapel_clearance: Dictionary = chapel_view["clearance"]
	var chapel_axis: Vector3 = (chapel_target - chapel_eye).normalized()
	_check(chapel_axis.dot(radial) > 0.55,
		"chapel visitor view does not look toward the measured altar at the outer end")
	var station_delta := chapel_eye - center
	var measured_depth: float = station_delta.dot(radial)
	var tangent := Vector3(cos(ChurchGeometry.chapel_angle(spec, chapel_index)), 0.0,
		-sin(ChurchGeometry.chapel_angle(spec, chapel_index)))
	var measured_side: float = absf(station_delta.dot(tangent))
	var station_ok: bool = bool(chapel_clearance["station_found_from_measured_floor_rectangles"]) \
		and absf(measured_depth - float(chapel_clearance["station_depth_from_chapel_face_m"])) < 0.01 \
		and absf(measured_side - float(chapel_clearance["station_side_offset_m"])) < 0.01 \
		and float(chapel_clearance["camera_body_radius_m"]) >= CameraFixture.BODY_RADIUS \
		and _measured_bench_pair_free_width(spec, chapel_index, placements) >= 0.62
	_check(station_ok,
		"chapel visitor station was not derived from actual measured bench rectangles and full body radius")
	var altar_center := Vector3.ZERO
	for placement in placements:
		if int(placement.get("chapel_index", -1)) == chapel_index \
				and String(placement.get("key", "")) == ChurchFurnisher.ALTAR:
			var plan_center: Vector2 = PropCatalog.plan_centre(String(placement.key),
				placement.pos, float(placement.yaw), float(placement.scale))
			altar_center = Vector3(plan_center.x, 0.0, plan_center.y)
			break
	var expected_target := altar_center + Vector3.UP \
		* (float(chapel_clearance["floor_top_y_m"]) - ChurchGeometry.FLOOR_T + 1.05)
	_check(chapel_target.distance_to(expected_target) < 0.01,
		"chapel interior target does not follow the measured altar plan centre")
	_check(ApertureProbe._first_hit(mesh, chapel_eye, chapel_target).is_empty(),
		"chapel visitor eye has no clear emitted-triangle line of sight toward the altar")
	_check(_body_disk_clear(mesh, chapel_eye, float(chapel_clearance["floor_top_y_m"]),
		float(chapel_clearance["camera_body_radius_m"])) ,
		"chapel visitor body disk intersects emitted structural triangles")
	_check(_floor_props_clear(placements, chapel_eye, chapel_index,
		float(chapel_clearance["camera_body_radius_m"])),
		"chapel visitor body disk overlaps a measured floor prop")
	var cutaway_view: Dictionary = CameraFixture.chapel_cutaway_view(spec,
		chapel_index, placements)
	_check(_cutaway_furnishings_are_framed(cutaway_view, spec, chapel_index,
		placements, mesh),
		"cutaway detail does not frame altar and both benches clear of uncut emitted triangles")
	_completed_cases += 1


func _camera_views_complete(spec: ChurchSpec, chapel_index: int,
		placements: Array[Dictionary]) -> bool:
	var ambient: Dictionary = CameraFixture.ambulatory_view(spec, chapel_index)
	var chapel: Dictionary = CameraFixture.chapel_view(spec, chapel_index, placements)
	var cutaway: Dictionary = CameraFixture.chapel_cutaway_view(spec, chapel_index, placements)
	if not ambient.has("eye") or not ambient.has("target") or not ambient.has("clearance") \
			or not chapel.has("eye") or not chapel.has("target") or not chapel.has("clearance") \
			or not cutaway.has("eye") or not cutaway.has("target") \
			or not cutaway.has("clearance"):
		return false
	if typeof(ambient["eye"]) != TYPE_VECTOR3 or typeof(ambient["target"]) != TYPE_VECTOR3 \
			or typeof(chapel["eye"]) != TYPE_VECTOR3 or typeof(chapel["target"]) != TYPE_VECTOR3 \
			or typeof(cutaway["eye"]) != TYPE_VECTOR3 or typeof(cutaway["target"]) != TYPE_VECTOR3 \
			or typeof(ambient["clearance"]) != TYPE_DICTIONARY \
			or typeof(chapel["clearance"]) != TYPE_DICTIONARY \
			or typeof(cutaway["clearance"]) != TYPE_DICTIONARY:
		return false
	var ambient_clearance: Dictionary = ambient["clearance"]
	var chapel_clearance: Dictionary = chapel["clearance"]
	var cutaway_clearance: Dictionary = cutaway["clearance"]
	for key in ["floor_top_y_m", "body_clearance_inner_m", "body_clearance_outer_m"]:
		if not ambient_clearance.has(key):
			return false
	for key in ["floor_top_y_m", "camera_body_radius_m", "camera_station_radius_m",
			"station_depth_from_chapel_face_m", "station_side_offset_m",
			"station_found_from_measured_floor_rectangles", "mouth_wall_inner_radius_m",
			"target_plan_center", "mouth_width_m",
			"mouth_height_m", "camera_fov_degrees", "camera_aspect"]:
		if not chapel_clearance.has(key):
			return false
	for key in ["cutaway_view", "target_plan_center", "chapel_radius_m",
			"chapel_body_height_m", "camera_fov_degrees", "camera_aspect",
			"camera_elevated_height_m", "camera_side_wall_clipped",
			"projected_furnishing_count"]:
		if not cutaway_clearance.has(key):
			return false
	return true


func _body_disk_clear(mesh: ArrayMesh, eye: Vector3, floor_top: float,
		body_radius: float) -> bool:
	var levels := [floor_top + 0.20, floor_top + 0.82, floor_top + 1.42]
	for y in levels:
		var center := Vector3(eye.x, y, eye.z)
		for sample in range(12):
			var angle := TAU * float(sample) / 12.0
			var edge := center + Vector3(cos(angle), 0.0, sin(angle)) * body_radius
			if not ApertureProbe._first_hit(mesh, center, edge, true).is_empty():
				return false
	return true


func _floor_props_clear(placements: Array[Dictionary], eye: Vector3,
		chapel_index: int, body_radius: float) -> bool:
	var disk_center := Vector2(eye.x, eye.z)
	for placement in placements:
		if int(placement.get("chapel_index", -1)) != chapel_index:
			continue
		var rect: Rect2 = placement.get("rect", Rect2())
		if rect.size == Vector2.ZERO:
			continue
		var closest := Vector2(
			clampf(disk_center.x, rect.position.x, rect.end.x),
			clampf(disk_center.y, rect.position.y, rect.end.y))
		if disk_center.distance_to(closest) < body_radius - 0.001:
			return false
	return true


func _cutaway_furnishings_are_framed(view: Dictionary, spec: ChurchSpec,
		chapel_index: int, placements: Array[Dictionary], mesh: ArrayMesh) -> bool:
	var eye: Vector3 = view["eye"]
	var target: Vector3 = view["target"]
	var clearance: Dictionary = view["clearance"]
	if not bool(clearance["cutaway_view"]):
		return false
	var focal: Vector2 = clearance["target_plan_center"]
	var floor_y: float = float(clearance["floor_top_y_m"]) - ChurchGeometry.FLOOR_T + 1.05
	if Vector2(target.x, target.z).distance_to(focal) > 0.01 \
			or absf(target.y - floor_y) > 0.01:
		return false
	var radial_dir: Vector3 = CameraFixture.radial(spec, chapel_index)
	var chapel_center: Vector3 = ChurchGeometry.chapel_center(spec, chapel_index)
	var angle: float = ChurchGeometry.chapel_angle(spec, chapel_index)
	var tangent := Vector3(cos(angle), 0.0, -sin(angle))
	var expected_eye := chapel_center - radial_dir * (float(clearance["chapel_radius_m"]) * 0.65) \
		+ tangent * (float(clearance["chapel_radius_m"]) * 0.45) \
		+ Vector3.UP * (float(clearance["floor_top_y_m"]) - ChurchGeometry.FLOOR_T \
		+ float(clearance["camera_elevated_height_m"]))
	if eye.distance_to(expected_eye) > 0.01 \
			or not bool(clearance["camera_side_wall_clipped"]):
		return false
	var forward := (target - eye).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var camera_up := right.cross(forward).normalized()
	var tan_half_v: float = tan(deg_to_rad(float(clearance["camera_fov_degrees"]) * 0.5))
	var tan_half_h: float = tan_half_v * float(clearance["camera_aspect"])
	var visible_altar := false
	var visible_benches := 0
	var bench_center_x: Array[float] = []
	var visibility_targets: Array[Vector3] = []
	var min_screen_x := INF
	var max_screen_x := -INF
	var min_screen_y := INF
	var max_screen_y := -INF
	for placement in placements:
		if int(placement.get("chapel_index", -1)) != chapel_index:
			continue
		var key: String = String(placement.get("key", ""))
		if key != ChurchFurnisher.ALTAR and key != ChurchFurnisher.PEW:
			continue
		var plan_center: Vector2 = PropCatalog.plan_centre(key, placement.pos,
			float(placement.yaw), float(placement.scale))
		var sample_y: float = float(clearance["floor_top_y_m"]) \
			+ (0.92 if key == ChurchFurnisher.ALTAR else 0.30)
		var rect: Rect2 = placement.get("rect", Rect2())
		if rect.size == Vector2.ZERO:
			return false
		var center_point := Vector3(plan_center.x, sample_y, plan_center.y)
		var center_delta := center_point - eye
		var center_depth: float = center_delta.dot(forward)
		if center_depth <= 0.01:
			return false
		var center_ndc_x: float = center_delta.dot(right) / (center_depth * tan_half_h)
		var center_ndc_y: float = center_delta.dot(camera_up) / (center_depth * tan_half_v)
		var visible: bool = absf(center_ndc_x) <= 0.92 and absf(center_ndc_y) <= 0.92
		var object_min_x := INF
		var object_max_x := -INF
		var object_min_y := INF
		var object_max_y := -INF
		for x in [rect.position.x, rect.end.x]:
			for z in [rect.position.y, rect.end.y]:
				var point := Vector3(float(x), sample_y, float(z))
				var delta := point - eye
				var depth: float = delta.dot(forward)
				if depth <= 0.01:
					return false
				var ndc_x: float = delta.dot(right) / (depth * tan_half_h)
				var ndc_y: float = delta.dot(camera_up) / (depth * tan_half_v)
				object_min_x = minf(object_min_x, ndc_x)
				object_max_x = maxf(object_max_x, ndc_x)
				object_min_y = minf(object_min_y, ndc_y)
				object_max_y = maxf(object_max_y, ndc_y)
		if object_min_x < -0.95 or object_max_x > 0.95 \
				or object_min_y < -0.95 or object_max_y > 0.95:
			return false
		visibility_targets.append(center_point)
		var inset_x: float = minf(0.12, rect.size.x * 0.15)
		var inset_z: float = minf(0.12, rect.size.y * 0.15)
		for x in [rect.position.x + inset_x, rect.end.x - inset_x]:
			for z in [rect.position.y + inset_z, rect.end.y - inset_z]:
				visibility_targets.append(Vector3(float(x), sample_y, float(z)))
		min_screen_x = minf(min_screen_x, object_min_x)
		max_screen_x = maxf(max_screen_x, object_max_x)
		min_screen_y = minf(min_screen_y, object_min_y)
		max_screen_y = maxf(max_screen_y, object_max_y)
		if key == ChurchFurnisher.ALTAR:
			visible_altar = visible
		else:
			visible_benches += 1 if visible else 0
			if visible:
				bench_center_x.append(center_ndc_x)
	if not visible_altar or visible_benches != 2 or bench_center_x.size() != 2:
		return false
	bench_center_x.sort()
	var bench_span: float = bench_center_x.back() - bench_center_x.front()
	var occupied_width: float = max_screen_x - min_screen_x
	var occupied_height: float = max_screen_y - min_screen_y
	return bench_span >= 0.30 and occupied_width >= 0.35 and occupied_height >= 0.20 \
		and _cutaway_rays_clear(mesh, eye, visibility_targets, spec, chapel_index)


func _cutaway_rays_clear(mesh: ArrayMesh, eye: Vector3, targets: Array[Vector3],
		spec: ChurchSpec, chapel_index: int) -> bool:
	var angle: float = ChurchGeometry.chapel_angle(spec, chapel_index)
	var tangent := Vector3(cos(angle), 0.0, -sin(angle))
	var center: Vector3 = ChurchGeometry.chapel_center(spec, chapel_index)
	for target in targets:
		for surface in range(mesh.get_surface_count()):
			var slot := surface
			var surface_name: String = String(mesh.surface_get_name(surface))
			if surface_name.begins_with("material_slot:"):
				slot = int(surface_name.trim_prefix("material_slot:"))
			if slot == ChurchBuilder.SURF_ROOF:
				continue
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
				if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count: int = indices.size() if not indices.is_empty() else vertices.size()
			for i in range(0, count, 3):
				var p0: Vector3 = vertices[indices[i] if not indices.is_empty() else i]
				var p1: Vector3 = vertices[indices[i + 1] if not indices.is_empty() else i + 1]
				var p2: Vector3 = vertices[indices[i + 2] if not indices.is_empty() else i + 2]
				var hit: Variant = Geometry3D.segment_intersects_triangle(eye, target,
					p0, p1, p2)
				if hit == null:
					continue
				var hit_point: Vector3 = hit
				var delta := hit_point - center
				var clipped_stone: bool = slot == ChurchBuilder.SURF_STONE \
					and absf(delta.dot(tangent)) > spec.chapel_radius * 0.06 \
					and Vector2(delta.x, delta.z).length() < spec.chapel_radius * 1.65 \
					and hit_point.y > ChurchGeometry.FLOOR_LIFT \
						- ChurchGeometry.FLOOR_T * 0.5 + 0.14 \
					and hit_point.y < ChurchGeometry.FLOOR_LIFT \
						+ ChurchGeometry.chapel_body_height(spec, chapel_index) + 0.25
				if not clipped_stone:
					return false
	return true


func _check(condition: bool, message: String) -> void:
	result.checked += 1
	if not condition:
		result.fail(message)


func _print_chapel_diagnostic(spec: ChurchSpec, chapel_index: int,
		placements: Array[Dictionary]) -> void:
	var angle: float = ChurchGeometry.chapel_angle(spec, chapel_index)
	var mouth_width: float = ChurchGeometry.chapel_mouth_width(spec, chapel_index)
	print("chapel camera diagnostic seed=%d index=%d mouth_width=%.3f route=%.3f body_diameter=%.3f" % [
		int(spec.seed), chapel_index, mouth_width, ChurchFurnisher.CHAPEL_ROUTE_W,
		CameraFixture.BODY_RADIUS * 2.0])
	for placement in placements:
		if int(placement.get("chapel_index", -1)) != chapel_index:
			continue
		var key: String = String(placement.get("key", ""))
		if key != ChurchFurnisher.PEW and key != ChurchFurnisher.ALTAR:
			continue
		var rect: Rect2 = placement.get("rect", Rect2())
		print("  %s scale=%.3f yaw=%.3f origin=%s rect=(%.3f,%.3f)+(%.3f,%.3f)" % [
			key, float(placement.get("scale", 1.0)), float(placement.get("yaw", 0.0)),
			str(placement.get("pos", Vector3.ZERO)), rect.position.x, rect.position.y,
			rect.size.x, rect.size.y])
	var free_width := _measured_bench_pair_free_width(spec, chapel_index, placements)
	print("  measured bench-pair free width=%.3f m (rect projected onto chapel tangent)" % free_width)


func _measured_bench_pair_free_width(spec: ChurchSpec, chapel_index: int,
		placements: Array[Dictionary]) -> float:
	var center: Vector3 = ChurchGeometry.chapel_center(spec, chapel_index)
	var angle: float = ChurchGeometry.chapel_angle(spec, chapel_index)
	var tangent := Vector3(cos(angle), 0.0, -sin(angle))
	var bench_ranges: Array[Vector2] = []
	for placement in placements:
		if int(placement.get("chapel_index", -1)) != chapel_index \
				or String(placement.get("key", "")) != ChurchFurnisher.PEW:
			continue
		var rect: Rect2 = placement.get("rect", Rect2())
		var local_min := INF
		var local_max := -INF
		for x in [rect.position.x, rect.end.x]:
			for z in [rect.position.y, rect.end.y]:
				var lateral: float = (Vector3(float(x), 0.0, float(z)) - center).dot(tangent)
				local_min = minf(local_min, lateral)
				local_max = maxf(local_max, lateral)
		bench_ranges.append(Vector2(local_min, local_max))
	if bench_ranges.size() != 2:
		return -INF
	bench_ranges.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return bench_ranges[1].x - bench_ranges[0].y
