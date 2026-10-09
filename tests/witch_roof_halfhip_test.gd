extends SceneTree
## Artifact-only gate for the scoped asymmetric half-hip and de-gridded reed shader.

const SIZES := [
	{"name": "small", "width": 7.0, "length": 9.0, "height": 2.6},
	{"name": "default", "width": 9.0, "length": 12.0, "height": 2.6},
	{"name": "large", "width": 17.0, "length": 18.0, "height": 2.8},
]
const SEEDS := [1, 8102, 21325]
const CUSTOM_SPEC := preload("res://tests/fixtures/witch_custom_house_spec.gd")
var failures: Array[String] = []
var raised_negative_cases := 0


func _init() -> void:
	for size in SIZES:
		for seed in SEEDS:
			_check_witch(size, seed)
	_check_scope(&"witch_hut", &"none", &"", true)
	_check_scope(&"cottage", &"none", &"", false)
	_check_scope(&"witch_hut", &"alchemist", &"", false)
	_check_scope(&"witch_hut", &"none", &"vastu", false)
	_check_custom_scope()
	_check_non_thatch_scope()
	_check_actual_controls()
	_check_generic_ridge_controls()
	_check_shader_has_no_bundle_grid()
	if raised_negative_cases == 0:
		_fail("no nonempty clipped end-member case exercised the raised-rafter negative")
	for failure in failures:
		printerr("FAIL ", failure)
	print("witch half-hip: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_witch(size: Dictionary, seed: int) -> void:
	var spec := HouseSpec.new()
	spec.style = &"witch_hut"
	spec.width = float(size.width)
	spec.length = float(size.length)
	spec.height = float(size.height)
	var plan := HouseGenerator.generate(spec, seed, false)
	var who := "%s/%d" % [size.name, seed]
	if plan == null:
		_fail("%s plan did not generate" % who)
		return
	var layout := HouseGeometry.roof_layout(plan)
	var faces: Array[PackedVector3Array] = layout["faces"]
	if not HouseGeometry.uses_witch_half_hip_roof(plan.spec, plan.world_family):
		_fail("%s missed exact Witch half-hip scope" % who)
	if plan.spec.roof_type != &"half_hipped":
		_fail("%s resolved roof metadata does not identify the emitted half-hip" % who)
	if faces.size() != 4:
		_fail("%s expected two slope panels and two hip panels; got %d" % [who, faces.size()])
		return
	var full_span := float(layout["span"]) + HouseGeometry.roof_span_out(plan.spec) * 2.0
	var full_along := float(layout["along"]) + HouseGeometry.roof_along_out(plan.spec) * 2.0
	var h := full_span * 0.5
	var f := full_along * 0.5
	var ridge_x := float(layout["ridge_x"])
	var cut := float(layout["rise"]) * RoofShape.HALF_HIP
	var shoulder_left := lerpf(-h, ridge_x, RoofShape.HALF_HIP)
	var shoulder_right := lerpf(h, ridge_x, RoofShape.HALF_HIP)
	var ridge_half := HouseGeometry.ridge_half_for(plan.spec, float(layout["span"]),
		float(layout["along"]), plan.world_family)
	if absf(float(layout["ridge_half"]) - ridge_half) > 0.0001:
		_fail("%s metadata ridge half disagrees with physical hip edges" % who)
	# These exact vertices are the four shared seams: side-to-ridge, side-to-hip,
	# hip-to-eave. The slab emitter receives the same polygons.
	if not _near(faces[0][3], Vector3(ridge_x, float(layout["rise"]), ridge_half)) \
			or not _near(faces[1][3], faces[0][3]):
		_fail("%s positive ridge edge is not shared exactly" % who)
	if not _near(faces[0][4], Vector3(ridge_x, float(layout["rise"]), -ridge_half)) \
			or not _near(faces[1][4], faces[0][4]):
		_fail("%s negative ridge edge is not shared exactly" % who)
	if not _near(faces[0][2], Vector3(shoulder_left, cut, f)) \
			or not _near(faces[1][2], Vector3(shoulder_right, cut, f)) \
			or not _near(faces[0][5], Vector3(shoulder_left, cut, -f)) \
			or not _near(faces[1][5], Vector3(shoulder_right, cut, -f)):
		_fail("%s lower gable shoulder line is not preserved" % who)
	if not _near(faces[2][2], faces[0][4]) or not _near(faces[3][2], faces[0][3]):
		_fail("%s hip tips do not meet the slope panels at their shortened ridge ends" % who)
	if not _near(faces[2][0], faces[0][5]) or not _near(faces[2][1], faces[1][5]) \
			or not _near(faces[3][0], faces[0][2]) or not _near(faces[3][1], faces[1][2]):
		_fail("%s hip shoulders do not share the slope panel vertices" % who)
	var end_profile := RoofShape.wall_profile(faces, Vector2(-h, f), Vector2(h, f))
	for profile_point in end_profile:
		if profile_point.y > cut + 0.0001:
			_fail("%s end wall profile climbed above the retained lower gable shoulders" % who)
			break
	for face in faces:
		if face.size() < 3:
			_fail("%s contains a roof face with fewer than three vertices" % who)
		for v in face:
			if not is_finite(v.x) or not is_finite(v.y) or not is_finite(v.z):
				_fail("%s roof vertex is not finite" % who)
	# Every point over the measured roof rectangle must have one finite host plane.
	for ix in range(1, 12):
		for iz in range(1, 12):
			var point := Vector2(lerpf(-h, h, float(ix) / 12.0),
				lerpf(-f, f, float(iz) / 12.0))
			if not is_finite(RoofShape.height_at(faces, point)):
				_fail("%s roof plane union has an interior hole at %s" % [who, point])
	# Plan/headroom and compact-vs-Workshop eligibility remain unchanged.
	if not is_equal_approx(plan.spec.height, float(size.height)):
		_fail("%s wall/headroom datum changed" % who)
	var eligible_bay := HouseGeometry.witch_workshop_bay(plan)
	if size.name == "small" and not eligible_bay.is_empty():
		_fail("%s compact shared Hall was incorrectly promoted into a Workshop bay" % who)
	var bay: Dictionary = layout.get("witch_bay", {})
	if not eligible_bay.is_empty() and bay.is_empty():
		_fail("%s eligible Workshop bay lost its roof-plane fit" % who)
	if not bay.is_empty():
		var axis := int(bay["axis"])
		var coord := float(bay["inner"])
		var lo := float(bay["along_lo"])
		var hi := float(bay["along_hi"])
		var mid := (lo + hi) * 0.5
		var p_mid := Vector2(coord, mid) if axis == 0 else Vector2(mid, coord)
		var p_lo := Vector2(coord, lo) if axis == 0 else Vector2(lo, coord)
		var p_hi := Vector2(coord, hi) if axis == 0 else Vector2(hi, coord)
		if absf(float(bay["host_y"]) - RoofShape.height_at(faces, p_mid)) > 0.002 \
				or absf(float(bay["host_y_lo"]) - RoofShape.height_at(faces, p_lo)) > 0.002 \
				or absf(float(bay["host_y_hi"]) - RoofShape.height_at(faces, p_hi)) > 0.002:
			_fail("%s Workshop bay lost measured contact with the new roof planes" % who)
	# Build and compare named components against the committed mesh. This catches
	# missing/reversed roof panels while the vertex seam checks above catch joins.
	plan.spec.timber_frame = true
	var builder := HouseBuilder.new()
	var mesh: ArrayMesh = builder.build(plan, true)
	var components := ComponentCheck.check(builder, mesh)
	if not bool(components["ok"]):
		_fail("%s emitted roof components differ from committed mesh: %s" % [who, components["failures"]])
	var expected_roof_faces := 0
	for row in builder.component_log:
		if String(row.get("role", "")).begins_with("roof_face_"):
			expected_roof_faces += 1
	if expected_roof_faces < 4:
		_fail("%s committed mesh does not contain all four roof-face components" % who)
	if HouseGeometry.uses_witch_half_hip_roof(plan.spec, plan.world_family):
		var contact_failures := _end_rafter_mesh_failures(builder, layout, mesh, 0.0, "contact")
		if not contact_failures.is_empty():
			_fail("%s end rafters do not meet the actual emitted roof underside: %s" % [who, contact_failures])
		var bearing_failures := _end_rafter_plate_bearing_failures(builder, layout, mesh)
		if not bearing_failures.is_empty():
			_fail("%s clipped end rafters lost actual wall-plate bearings: %s" % [who, bearing_failures])
		var detached_failures := _end_rafter_mesh_failures(builder, layout, mesh, -0.03, "detached")
		if not detached_failures.is_empty():
			_fail("%s physically displaced 30 mm rafter still contacts or intrudes into roof: %s" % [who, detached_failures])
		if _expected_end_station_count(layout) > 0:
			var raised_contact_failures := _end_rafter_mesh_failures(builder, layout, mesh, 0.03, "contact")
			if raised_contact_failures.is_empty():
				_fail("%s same contact predicate accepted raised timber" % who)
			else:
				raised_negative_cases += 1
			var penetration_failures := _end_rafter_mesh_failures(builder, layout, mesh, 0.03, "penetration")
			if not penetration_failures.is_empty():
				_fail("%s physically raised 30 mm rafter is not measured inside roof slab: %s" % [who, penetration_failures])
		else:
			print("HALFHIP_NO_END_NEGATIVE %s: both actual end stations are replaced by the full-length service bay; zero end-rafter mesh is expected, so no raised negative is claimed for this case" % who)
	mesh.clear_surfaces()


func _end_rafter_mesh_failures(builder: HouseBuilder, layout: Dictionary,
		host_roof: ArrayMesh, vertical_shift: float, mode: String) -> Array[String]:
	var failures_out: Array[String] = []
	var xf: Transform3D = layout["transform"]
	var inverse := xf.affine_inverse()
	var rows: Array[Dictionary] = []
	var hip_rows: Array[Dictionary] = []
	var expected := 0
	var expected_stations: Array[float] = []
	var along := float(layout["along"])
	var bay: Dictionary = layout.get("witch_bay", {})
	for end_sign in [-1.0, 1.0]:
		var station := float(end_sign) * (along * 0.5 + HouseGeometry.BEAM_D * 0.5 - 0.01)
		if bay.is_empty() or station < float(bay.get("along_lo", INF)) - 0.001 \
				or station > float(bay.get("along_hi", -INF)) + 0.001:
			expected += 1
			expected_stations.append(station)
	for row in builder.component_log:
		var role := String(row.get("role", ""))
		if role == "witch_half_hip_end_rafter":
			rows.append(row)
		elif role == "witch_half_hip_end_hip_rafter":
			hip_rows.append(row)
	var expected_side_rows := expected * 2
	if rows.size() != expected_side_rows:
		failures_out.append("expected %d clipped side-rafter strips for %d uncut end stations; found %d" % [expected_side_rows, expected, rows.size()])
	if hip_rows.size() != expected_side_rows:
		failures_out.append("expected %d shoulder-to-ridge hip supports; found %d" % [expected_side_rows, hip_rows.size()])
	var row_ids := PackedStringArray()
	for row in rows + hip_rows:
		row_ids.append("%s/%s" % [row.get("role", ""), row.get("id", "")])
	var bay_trace: Dictionary = layout.get("witch_bay", {})
	print("HALFHIP_ROWS span=%.3f along=%.3f bay=[%.3f,%.3f] mode=%s expected_end_stations=%d expected_side_rows=%d actual_side_rows=%d actual_hip_rows=%d ids=%s" % [float(layout["span"]), along, float(bay_trace.get("along_lo", NAN)), float(bay_trace.get("along_hi", NAN)), mode, expected, expected_side_rows, rows.size(), hip_rows.size(), ",".join(row_ids)])
	for station in expected_stations:
		var side_count := 0
		for row in rows:
			var centre := Vector3.ZERO
			for point in row["points"]:
				centre += point
			centre /= float((row["points"] as PackedVector3Array).size())
			if absf((inverse * centre).z - station) <= 0.1:
				side_count += 1
		var hip_count := 0
		for row in hip_rows:
			var centre := Vector3.ZERO
			for point in row["points"]:
				centre += point
			centre /= float((row["points"] as PackedVector3Array).size())
			if signf((inverse * centre).z) == signf(station):
				hip_count += 1
		if side_count != 2 or hip_count != 2:
			failures_out.append("end station %.3f has side/hip support counts %d/%d, expected 2/2" % [station, side_count, hip_count])
	var roof_faces: Array[PackedVector3Array] = layout["faces"]
	for row in rows + hip_rows:
		var points: PackedVector3Array = row["points"].duplicate()
		var normal := _host_roof_normal_for_row(row, points, roof_faces, xf, inverse,
			float(layout["ridge_x"]))
		if normal.length_squared() < 0.9:
			failures_out.append("%s has no non-degenerate host roof normal" % row["id"])
			continue
		var depth := float(row["depth"])
		for i in range(points.size()):
			points[i].y += vertical_shift
		var test_kit := MeshKit.new(1)
		test_kit.slab_poly(points, depth, 0, false)
		var test_mesh: ArrayMesh = test_kit.commit()
		# Probe the re-emitted timber mesh itself. Component-log polygons define
		# the perturbation input, but no contact point is derived from those logs.
		var timber_triangles := MeshProbe.surface_triangles(null, test_mesh, 0)
		var roof_triangles := MeshProbe.surface_triangles(null, host_roof,
			HouseBuilder.SURF_ROOF)
		var underside_triangles: Array = []
		for triangle in roof_triangles:
			var tri_normal := _triangle_normal(triangle)
			if tri_normal.dot(normal) < -0.95:
				underside_triangles.append(triangle)
		var upper_samples: Array[Vector3] = []
		for triangle in timber_triangles:
			var a: Vector3 = triangle[0]
			var b: Vector3 = triangle[1]
			var c: Vector3 = triangle[2]
			var face := _triangle_normal(triangle)
			if face.dot(normal) < 0.95:
				continue
			upper_samples.append_array([a, b, c, (a + b) * 0.5,
				(b + c) * 0.5, (c + a) * 0.5, (a + b + c) / 3.0])
		var contact_samples := 0
		var embedded_samples := 0
		for sample in upper_samples:
			if _triangle_segment_hits(underside_triangles,
				sample, sample + Vector3.UP * 0.01):
				contact_samples += 1
			if _roof_triangle_interval_contains(roof_triangles, sample, Vector3.UP):
				embedded_samples += 1
		var enough_contact := not upper_samples.is_empty() \
			and contact_samples == upper_samples.size()
		if mode == "contact" and (not enough_contact or embedded_samples > 0):
			failures_out.append("%s emitted timber does not contact only the downward roof underside (%d/%d contact, %d embedded)" % [row["id"], contact_samples, upper_samples.size(), embedded_samples])
		elif mode == "detached" and (contact_samples > 0 or embedded_samples > 0):
			failures_out.append("%s detached emitted timber still contacts/intrudes (%d contact, %d embedded)" % [row["id"], contact_samples, embedded_samples])
		elif mode == "penetration" and (upper_samples.is_empty() \
				or embedded_samples == 0):
			failures_out.append("%s raised emitted timber has no detected roof penetration (%d/%d samples)" % [row["id"], embedded_samples, upper_samples.size()])
		test_mesh.clear_surfaces()
	return failures_out


func _expected_end_station_count(layout: Dictionary) -> int:
	var along := float(layout["along"])
	var bay: Dictionary = layout.get("witch_bay", {})
	var count := 0
	for end_sign in [-1.0, 1.0]:
		var station := float(end_sign) * (along * 0.5 + HouseGeometry.BEAM_D * 0.5 - 0.01)
		if bay.is_empty() or station < float(bay.get("along_lo", INF)) - 0.001 \
				or station > float(bay.get("along_hi", -INF)) + 0.001:
			count += 1
	return count


func _host_roof_normal_for_row(row: Dictionary, points: PackedVector3Array,
		faces: Array[PackedVector3Array], xf: Transform3D, inverse: Transform3D,
		ridge_x: float) -> Vector3:
	var centre := Vector3.ZERO
	for point in points:
		centre += point
	centre /= float(points.size())
	var local := inverse * centre
	var role := String(row.get("role", ""))
	var face_index := 0
	if role == "witch_half_hip_end_hip_rafter":
		face_index = 2 if local.z < 0.0 else 3
	else:
		face_index = 0 if local.x < ridge_x else 1
	var face: PackedVector3Array = faces[face_index]
	var face_normal := Vector3.ZERO
	for i in range(1, face.size() - 1):
		face_normal = (face[i] - face[0]).cross(face[i + 1] - face[0])
		if face_normal.length_squared() > 1e-10:
			break
	if face_normal.y < 0.0:
		face_normal = -face_normal
	return (xf.basis * face_normal.normalized()).normalized()


func _triangle_normal(triangle: Array) -> Vector3:
	return (triangle[2] - triangle[0]).cross(triangle[1] - triangle[0]).normalized()


func _triangle_segment_hits(triangles: Array, a: Vector3, b: Vector3) -> bool:
	for triangle in triangles:
		if _closed_segment_hit_point(a, b, triangle) is Vector3:
			return true
	return false


func _closed_segment_hit_point(start: Vector3, finish: Vector3,
		triangle: Array) -> Variant:
	var a: Vector3 = triangle[0]
	var b: Vector3 = triangle[1]
	var c: Vector3 = triangle[2]
	var edge0 := b - a
	var edge1 := c - a
	var normal := edge0.cross(edge1)
	var direction := finish - start
	var denominator := normal.dot(direction)
	if absf(denominator) < 1e-10:
		return null
	var t := normal.dot(a - start) / denominator
	if t < -0.00001 or t > 1.00001:
		return null
	var point := start + direction * clampf(t, 0.0, 1.0)
	var rel := point - a
	var d00 := edge0.dot(edge0)
	var d01 := edge0.dot(edge1)
	var d11 := edge1.dot(edge1)
	var d20 := rel.dot(edge0)
	var d21 := rel.dot(edge1)
	var denom := d00 * d11 - d01 * d01
	if absf(denom) < 1e-12:
		return null
	var v := (d11 * d20 - d01 * d21) / denom
	var w := (d00 * d21 - d01 * d20) / denom
	var u := 1.0 - v - w
	const EDGE_EPSILON := 0.00005
	if u >= -EDGE_EPSILON and v >= -EDGE_EPSILON and w >= -EDGE_EPSILON:
		return point
	return null


func _roof_triangle_interval_contains(triangles: Array, point: Vector3,
		normal: Vector3) -> bool:
	var start := point - normal * 0.5
	var finish := point + normal * 0.5
	var hits: Array[Vector3] = []
	for triangle in triangles:
		var hit: Variant = _closed_segment_hit_point(start, finish, triangle)
		if hit is Vector3:
			hits.append(hit)
	if hits.size() < 2:
		return false
	var distances: Array[float] = []
	for hit in hits:
		distances.append((hit - start).dot(normal))
	distances.sort()
	var unique_distances: Array[float] = []
	for distance in distances:
		if unique_distances.is_empty() \
				or absf(distance - unique_distances.back()) > 0.001:
			unique_distances.append(distance)
	var point_distance := (point - start).dot(normal)
	# Adjacent roof planes can create more than two hits at a seam. Accept only
	# a measured entry/exit pair that brackets this emitted timber sample; a
	# global min/max would bridge unrelated roof panels and fake slab thickness.
	for i in range(0, unique_distances.size() - 1, 2):
		var lo := unique_distances[i]
		var hi := unique_distances[i + 1]
		if hi - lo >= RoofShape.DEPTH * 0.5 \
				and point_distance >= lo - 0.0005 and point_distance <= hi + 0.0005:
			return true
	return false


func _end_rafter_plate_bearing_failures(builder: HouseBuilder, layout: Dictionary,
		mesh: ArrayMesh) -> Array[String]:
	var failures_out: Array[String] = []
	var roof_xf: Transform3D = layout["transform"]
	var roof_inverse := roof_xf.affine_inverse()
	var ridge_x := float(layout["ridge_x"])
	var roof_faces: Array[PackedVector3Array] = layout["faces"]
	var side_rows: Array[Dictionary] = []
	var ties: Array[Dictionary] = []
	for row in builder.component_log:
		match String(row.get("role", "")):
			"witch_half_hip_end_rafter": side_rows.append(row)
			"gable_tie": ties.append(row)
	for rafter in side_rows:
		var points: PackedVector3Array = rafter["points"]
		var local_points: Array[Vector3] = []
		for point in points:
			local_points.append(roof_inverse * point)
		var normal := _host_roof_normal_for_row(rafter, points, roof_faces,
			roof_xf, roof_inverse, ridge_x)
		var furthest := 0.0
		for local_point in local_points:
			furthest = maxf(furthest, absf(local_point.x - ridge_x))
		var foot_local := Vector3.ZERO
		var foot_points := 0
		for i in range(local_points.size()):
			if furthest - absf(local_points[i].x - ridge_x) > 0.001:
				continue
			# The component polygon is already inset by half the beam width;
			# extrusion puts the actual lower face another half-width below it.
			foot_local += roof_inverse * (points[i] - normal * float(rafter["depth"]) * 0.5)
			foot_points += 1
		if foot_points < 2:
			failures_out.append("%s has no full-width emitted birdsmouth edge" % rafter["id"])
			continue
		foot_local /= float(foot_points)
		var best_tie: Dictionary = {}
		var best_gap := INF
		for tie in ties:
			var tie_xf: Transform3D = tie["xf"]
			var tie_local := roof_inverse * tie_xf.origin
			var gap := absf(tie_local.z - foot_local.z)
			if gap < best_gap:
				best_gap = gap
				best_tie = tie
		if best_tie.is_empty() or best_gap > 0.1:
			failures_out.append("%s has no matching end tie" % rafter["id"])
			continue
		var tie_xf: Transform3D = best_tie["xf"]
		var tie_size: Vector3 = best_tie["size"]
		# Isolate the tie's measured triangles and prove those exact triangles are
		# present in the committed trim surface before testing its full bearing.
		var tie_kit := MeshKit.new(1)
		tie_kit.oriented_box(tie_size, tie_xf, 0)
		var tie_mesh: ArrayMesh = tie_kit.commit()
		var tie_triangles := MeshProbe.surface_triangles(null, tie_mesh, 0)
		var committed_trim := MeshProbe.surface_triangles(null, mesh,
			HouseBuilder.SURF_TRIM)
		var isolated_in_committed := true
		for triangle in tie_triangles:
			if not _triangle_present(committed_trim, triangle):
				isolated_in_committed = false
				break
		if not isolated_in_committed:
			failures_out.append("%s isolated tie triangles are absent from committed trim mesh" % rafter["id"])
		# The rafter's actual emitted mesh is sampled along its eave bearing edge.
		# At every sample the isolated tie must have its real upward face and the
		# rafter's actual triangles must cross that same point.
		var rafter_kit := MeshKit.new(1)
		rafter_kit.slab_poly(points, float(rafter["depth"]), 0, false)
		var rafter_mesh: ArrayMesh = rafter_kit.commit()
		var rafter_triangles := MeshProbe.surface_triangles(null, rafter_mesh, 0)
		var tie_top_local_y := tie_size.y * 0.5
		var local_bearing := Vector2(foot_local.x, foot_local.z)
		var bearing_samples: Array[Vector2] = []
		for offset in [-0.04, -0.02, 0.0, 0.02, 0.04]:
			bearing_samples.append(Vector2(local_bearing.x, local_bearing.y + offset))
		var supported := 0
		for sample in bearing_samples:
			var world_sample := roof_xf * Vector3(sample.x, 0.0, sample.y)
			var tie_local := tie_xf.affine_inverse() * world_sample
			if absf(tie_local.x) > tie_size.x * 0.5 + 0.001 \
					or absf(tie_local.z) > tie_size.z * 0.5 + 0.001:
				continue
			var top_world := tie_xf * Vector3(tie_local.x, tie_top_local_y, tie_local.z)
			var tie_has_top := MeshProbe.has_upward_support(tie_triangles,
				Vector2(top_world.x, top_world.z), top_world.y, 0.001)
			var ray_start := top_world + Vector3.UP * 0.01
			var ray_end := top_world - Vector3.UP * 0.01
			if tie_has_top and _triangle_segment_hits(rafter_triangles, ray_start, ray_end):
				supported += 1
		if supported != bearing_samples.size():
			failures_out.append("%s emitted rafter loses full tie bearing (%d/%d samples)" % [rafter["id"], supported, bearing_samples.size()])
		# Move a real isolated tie mesh outside the measured wall bearing. The
		# same five emitted-rafter contact probes must all fail.
		var moved_xf: Transform3D = tie_xf
		var outward := signf(foot_local.x)
		var moved_local := roof_inverse * moved_xf.origin
		var bearing_x_edge := foot_local.x * outward
		for sample in bearing_samples:
			bearing_x_edge = maxf(bearing_x_edge, sample.x * outward)
		moved_local.x = outward * (bearing_x_edge + tie_size.x * 0.5 + 0.03)
		moved_xf.origin = roof_xf * moved_local
		var negative_kit := MeshKit.new(1)
		negative_kit.oriented_box(tie_size, moved_xf, 0)
		var negative_mesh: ArrayMesh = negative_kit.commit()
		var negative_triangles := MeshProbe.surface_triangles(null, negative_mesh, 0)
		var negative_supported := 0
		for sample in bearing_samples:
			var world_sample := roof_xf * Vector3(sample.x, 0.0, sample.y)
			var moved_sample_local := moved_xf.affine_inverse() * world_sample
			if absf(moved_sample_local.x) > tie_size.x * 0.5 + 0.001 \
					or absf(moved_sample_local.z) > tie_size.z * 0.5 + 0.001:
				continue
			var negative_top := moved_xf * Vector3(moved_sample_local.x, tie_top_local_y, moved_sample_local.z)
			if MeshProbe.has_upward_support(negative_triangles,
				Vector2(negative_top.x, negative_top.z), negative_top.y, 0.001) \
					and _triangle_segment_hits(rafter_triangles,
					negative_top + Vector3.UP * 0.01, negative_top - Vector3.UP * 0.01):
				negative_supported += 1
		if negative_supported > 0:
			failures_out.append("%s measured-outboard tie negative still bears (%d samples)" % [rafter["id"], negative_supported])
		rafter_mesh.clear_surfaces()
		negative_mesh.clear_surfaces()
		tie_mesh.clear_surfaces()
	return failures_out


func _triangle_present(triangles: Array, target: Array) -> bool:
	var ta: Vector3 = target[0]
	var tb: Vector3 = target[1]
	var tc: Vector3 = target[2]
	for triangle in triangles:
		var a: Vector3 = triangle[0]
		var b: Vector3 = triangle[1]
		var c: Vector3 = triangle[2]
		if (a.distance_to(ta) < 0.00001 and b.distance_to(tb) < 0.00001 and c.distance_to(tc) < 0.00001) \
				or (a.distance_to(tb) < 0.00001 and b.distance_to(tc) < 0.00001 and c.distance_to(ta) < 0.00001) \
				or (a.distance_to(tc) < 0.00001 and b.distance_to(ta) < 0.00001 and c.distance_to(tb) < 0.00001):
			return true
	return false


func _check_scope(style: StringName, trade: StringName, world: StringName,
		expected: bool) -> void:
	var spec := HouseSpec.new()
	spec.style = style
	spec.trade = trade
	spec.roof_type = &"half_hipped"
	spec.roof_material = &"thatch"
	if HouseGeometry.uses_witch_half_hip_roof(spec, world) != expected:
		_fail("half-hip scope mismatch for %s/%s/%s" % [style, trade, world])


func _check_custom_scope() -> void:
	var custom := CUSTOM_SPEC.new() as HouseSpec
	custom.style = &"witch_hut"
	custom.trade = &"none"
	custom.roof_type = &"half_hipped"
	custom.roof_material = &"thatch"
	if HouseGeometry.uses_witch_half_hip_roof(custom):
		_fail("custom Witch HouseSpec entered the built-in half-hip path")


func _check_non_thatch_scope() -> void:
	var spec := HouseSpec.new()
	spec.style = &"witch_hut"
	spec.trade = &"none"
	spec.roof_type = &"half_hipped"
	spec.roof_material = &"shingle"
	if HouseGeometry.uses_witch_half_hip_roof(spec):
		_fail("non-thatch Witch roof entered the bundled half-hip path")


func _check_actual_controls() -> void:
	var trade := HouseSpec.new()
	trade.style = &"witch_hut"
	trade.trade = &"alchemist"
	_check_legacy_roof_layout(trade, 8102, &"", "trade Witch")
	var world := HouseSpec.new()
	world.style = &"witch_hut"
	_check_legacy_roof_layout(world, 8102, &"vastu", "world Witch")
	var custom := CUSTOM_SPEC.new() as HouseSpec
	custom.style = &"witch_hut"
	custom.trade = &"none"
	_check_legacy_roof_layout(custom, 8102, &"", "custom Witch")
	var cottage := HouseSpec.new()
	cottage.style = &"cottage"
	_check_legacy_roof_layout(cottage, 8102, &"", "Cottage")
	var non_thatch := HouseSpec.new()
	non_thatch.style = &"witch_hut"
	var non_thatch_plan := HouseGenerator.generate(non_thatch, 8102, false)
	if non_thatch_plan != null:
		non_thatch_plan.spec.roof_material = &"shingle"
		non_thatch_plan.spec.roof_type = &"gable"
		var layout := HouseGeometry.roof_layout(non_thatch_plan)
		var expected := RoofShape.asymmetric_gable(
			float(layout["span"]) + HouseGeometry.roof_span_out(non_thatch_plan.spec) * 2.0,
			float(layout["along"]) + HouseGeometry.roof_along_out(non_thatch_plan.spec) * 2.0,
			float(layout["rise"]), float(layout["ridge_x"]))
		var actual: Array[PackedVector3Array] = layout["faces"]
		if non_thatch_plan.spec.roof_type != &"gable" or actual.size() != expected.size():
			_fail("non-thatch Witch control changed its legacy gable form")
		else:
			for i in range(actual.size()):
				for j in range(actual[i].size()):
					if not _near(actual[i][j], expected[i][j]):
						_fail("non-thatch Witch control changed its legacy roof surface")
						return


func _check_legacy_roof_layout(spec: HouseSpec, seed: int, world: StringName,
		who: String) -> void:
	var plan := HouseGenerator.generate(spec, seed, false, world)
	if plan == null:
		_fail("%s control did not generate" % who)
		return
	var layout := HouseGeometry.roof_layout(plan)
	var full_span := float(layout["span"]) + HouseGeometry.roof_span_out(plan.spec) * 2.0
	var full_along := float(layout["along"]) + HouseGeometry.roof_along_out(plan.spec) * 2.0
	var expected := RoofShape.faces(full_span, full_along,
		float(layout["rise"]), plan.spec.roof_type)
	var actual: Array[PackedVector3Array] = layout["faces"]
	if HouseGeometry.uses_witch_half_hip_roof(plan.spec, plan.world_family) \
			or actual.size() != expected.size():
		_fail("%s changed roof-face family outside exact built-in Witch scope" % who)
		return
	for i in range(actual.size()):
		if actual[i].size() != expected[i].size():
			_fail("%s legacy roof face %d changed vertex count" % [who, i])
			return
		for j in range(actual[i].size()):
			if not _near(actual[i][j], expected[i][j]):
				_fail("%s legacy roof face %d changed at vertex %d" % [who, i, j])
				return
	_check_legacy_plan_roof_layout(plan, who)


func _check_legacy_plan_roof_layout(plan: HousePlan, who: String) -> void:
	var layout := HouseGeometry.roof_layout(plan)
	var full_span := float(layout["span"]) + HouseGeometry.roof_span_out(plan.spec) * 2.0
	var full_along := float(layout["along"]) + HouseGeometry.roof_along_out(plan.spec) * 2.0
	var expected := RoofShape.faces(full_span, full_along, float(layout["rise"]), plan.spec.roof_type)
	var actual: Array[PackedVector3Array] = layout["faces"]
	if actual.size() != expected.size():
		_fail("%s changed its original roof face count" % who)
		return
	for i in range(actual.size()):
		if actual[i].size() != expected[i].size():
			_fail("%s changed legacy roof face %d vertex count" % [who, i])
			return
		for j in range(actual[i].size()):
			if not _near(actual[i][j], expected[i][j]):
				_fail("%s changed legacy roof face %d at vertex %d" % [who, i, j])
				return


func _check_generic_ridge_controls() -> void:
	for kind in [&"gable", &"half_hipped", &"hipped"]:
		var spec := HouseSpec.new()
		spec.style = &"cottage"
		spec.width = 9.0
		spec.length = 12.0
		spec.roof_type = kind
		var span := minf(spec.width, spec.length)
		var along := maxf(spec.width, spec.length)
		var old_half := along * 0.5 + HouseGeometry.roof_along_out(spec)
		if kind != &"gable":
			var cut := RoofShape.HALF_HIP if kind == &"half_hipped" else 0.0
			old_half = maxf(old_half - (span * 0.5 + HouseGeometry.roof_span_out(spec)) * (1.0 - cut), 0.0)
		var actual := HouseGeometry.ridge_half_for(spec, span, along)
		if absf(actual - old_half) > 0.00001:
			_fail("generic %s ridge length changed from its established formula" % kind)


func _check_shader_has_no_bundle_grid() -> void:
	var shader: String = MaterialKit.HOUSE_ROOF
	if shader.contains("bundle_cell") or shader.contains("u_edge"):
		_fail("Witch shader still contains rectangular cross-bundle grid seams")
	if not shader.contains("lap_wave") or not shader.contains("fiber_body"):
		_fail("Witch shader lost irregular layered laps or down-slope reeds")


func _near(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) <= 0.00001


func _fail(message: String) -> void:
	failures.append(message)
