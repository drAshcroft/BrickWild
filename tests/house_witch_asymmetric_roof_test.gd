extends SceneTree
## Structural roof check for the no-trade Witch silhouette. It reads the
## emitted mesh triangles as well as the recipe/component records.

const ROOF_SURFACE := 2
const WALL_SURFACE := 0
const SIZES := [
	{"name": "small", "width": 7.0, "length": 9.0, "height": 2.6},
	{"name": "default", "width": 9.0, "length": 12.0, "height": 2.6},
	{"name": "large", "width": 17.0, "length": 18.0, "height": 2.8},
]
const SEEDS := [1, 8102, 21325]
const CUSTOM_SPEC := preload("res://tests/fixtures/witch_custom_house_spec.gd")

var failures: Array[String] = []


func _init() -> void:
	_check_roof_shape_degenerate_control()
	_check_custom_and_world_family_controls()
	_check_witch_case({"name": "rotated", "width": 12.0, "length": 9.0, "height": 2.6}, 8102)
	for size in SIZES:
		for seed in SEEDS:
			_check_witch_case(size, seed)
		_check_symmetric_control(size, &"cottage", &"none")
		_check_symmetric_control(size, &"witch_hut", &"alchemist")
	for failure in failures:
		printerr("FAIL ", failure)
	print("witch asymmetric roof: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_roof_shape_degenerate_control() -> void:
	if not RoofShape.asymmetric_gable(0.0, 9.0, 4.0, 0.8).is_empty():
		failures.append("asymmetric gable accepted a zero-span roof")
	var clipped := RoofShape.asymmetric_gable(4.0, 9.0, 3.0, 99.0)
	if clipped.size() != 2:
		failures.append("asymmetric-gable clamp control did not retain both roof planes")
		return
	var points: PackedVector3Array = clipped[0]
	var ridge_x := points[2].x
	if ridge_x > 1.96 or ridge_x < 1.90:
		failures.append("asymmetric-gable ridge escaped its end bearing: %.3f" % ridge_x)


func _check_witch_case(size: Dictionary, seed: int) -> void:
	var spec := HouseSpec.new()
	spec.style = &"witch_hut"
	spec.width = float(size.width)
	spec.length = float(size.length)
	spec.height = float(size.height)
	spec.storeys = 1
	var plan := HouseGenerator.generate(spec, seed, false)
	if plan == null or plan.spec == null:
		failures.append("Witch %s seed %d did not generate" % [size.name, seed])
		return
	plan.spec.dormers = false
	plan.spec.dormer_count = 0
	plan.spec.roof_type = &"gable"
	plan.spec.ridge_finial = true
	var layout := HouseGeometry.roof_layout(plan)
	var ridge_x := float(layout.get("ridge_x", 0.0))
	if not HouseGeometry.uses_witch_asymmetric_roof(plan.spec, plan.world_family) or absf(ridge_x) <= 0.05:
		failures.append("Witch %s seed %d lacks its offset ridge" % [size.name, seed])
		return
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan, true)
	var span := float(layout["span"]) + 2.0 * HouseGeometry.roof_span_out(plan.spec)
	var half := span * 0.5
	var rise := float(layout["rise"])
	var d := minf(half * 0.28, (half - absf(ridge_x)) * 0.55)
	var transform: Transform3D = layout["transform"]
	var roof_probe_z := _uncut_roof_z(layout)
	if not is_finite(roof_probe_z):
		failures.append("Witch %s seed %d has no uncut main-roof station for slope probes" % [size.name, seed])
		roof_probe_z = 0.0 # keep both actual-plane rays and the remaining frame probes active
	var left_run := absf(ridge_x + half)
	var right_run := absf(half - ridge_x)
	var shallow_x := ridge_x - d if left_run > right_run else ridge_x + d
	var steep_x := ridge_x + d if left_run > right_run else ridge_x - d
	var shallow_probe := transform * Vector3(shallow_x, 0.0, roof_probe_z)
	var steep_probe := transform * Vector3(steep_x, 0.0, roof_probe_z)
	var roof_top := float(transform.origin.y) + rise + 1.0
	var shallow_y := _surface_height(mesh, ROOF_SURFACE, Vector2(shallow_probe.x, shallow_probe.z), roof_top)
	var steep_y := _surface_height(mesh, ROOF_SURFACE, Vector2(steep_probe.x, steep_probe.z), roof_top)
	if not is_finite(shallow_y) or not is_finite(steep_y) or shallow_y < steep_y + 0.12:
		failures.append("Witch %s seed %d emitted roof does not show unequal slopes (%.3f / %.3f)" % [size.name, seed, shallow_y, steep_y])
	var peak := transform * Vector3(ridge_x, 0.0, 0.0)
	var peak_y := _surface_height(mesh, ROOF_SURFACE, Vector2(peak.x, peak.z), roof_top)
	if not is_finite(peak_y) or peak_y < float(transform.origin.y) + rise - 0.45 \
			or peak_y > float(transform.origin.y) + rise + 0.25:
		failures.append("Witch %s seed %d emitted ridge peak is not on its specified roof plane: %.3f" % [size.name, seed, peak_y])
	_check_gable_infill(mesh, layout, plan, "%s seed %d" % [size.name, seed])
	_check_ridge_crown(builder, layout, "%s seed %d" % [size.name, seed])
	_check_rafter_bearings(builder, mesh, layout, plan, "%s seed %d" % [size.name, seed])
	mesh.clear_surfaces()


func _check_custom_and_world_family_controls() -> void:
	var custom := CUSTOM_SPEC.new() as HouseSpec
	custom.style = &"witch_hut"
	custom.trade = &"none"
	custom.roof_type = &"gable"
	custom.width = 9.0
	custom.length = 12.0
	custom.height = 2.6
	var generated := HouseGenerator.generate(HouseSpec.new(), 8102, false)
	if generated == null:
		failures.append("custom-spec control plan did not generate")
		return
	generated.spec = custom
	if HouseGeometry.uses_witch_asymmetric_roof(custom) or absf(float(HouseGeometry.roof_layout(generated).get("ridge_x", 0.0))) > 0.001:
		failures.append("custom HouseSpec subclass entered built-in Witch roof path")
	var builtin := HouseSpec.new()
	builtin.style = &"witch_hut"
	builtin.trade = &"none"
	builtin.roof_type = &"gable"
	if HouseGeometry.uses_witch_asymmetric_roof(builtin, &"vastu"):
		failures.append("world-family adapter entered built-in Witch roof path")
	generated.spec = builtin
	generated.world_family = &"vastu"
	if absf(float(HouseGeometry.roof_layout(generated).get("ridge_x", 0.0))) > 0.001:
		failures.append("world-family plan received asymmetric Witch roof")


func _check_symmetric_control(size: Dictionary, style: StringName, trade: StringName) -> void:
	var spec := HouseSpec.new()
	spec.style = style
	spec.trade = trade
	spec.width = float(size.width)
	spec.length = float(size.length)
	spec.height = float(size.height)
	spec.storeys = 1
	var plan := HouseGenerator.generate(spec, 8102, false)
	if plan == null or plan.spec == null:
		failures.append("control %s/%s %s did not generate" % [style, trade, size.name])
		return
	plan.spec.dormers = false
	plan.spec.dormer_count = 0
	plan.spec.roof_type = &"gable"
	var layout := HouseGeometry.roof_layout(plan)
	if HouseGeometry.uses_witch_asymmetric_roof(plan.spec, plan.world_family) or absf(float(layout.get("ridge_x", 0.0))) > 0.001:
		failures.append("control %s/%s %s entered the Witch-only roof path" % [style, trade, size.name])
		return
	var control_builder := HouseBuilder.new()
	var mesh := control_builder.build(plan, true)
	var span := float(layout["span"]) + 2.0 * HouseGeometry.roof_span_out(plan.spec)
	var d := span * 0.32
	var transform: Transform3D = layout["transform"]
	var left := transform * Vector3(-d, 0.0, 0.0)
	var right := transform * Vector3(d, 0.0, 0.0)
	var roof_top := float(transform.origin.y) + float(layout["rise"]) + 1.0
	var left_y := _surface_height(mesh, ROOF_SURFACE, Vector2(left.x, left.z), roof_top)
	var right_y := _surface_height(mesh, ROOF_SURFACE, Vector2(right.x, right.z), roof_top)
	if not is_finite(left_y) or not is_finite(right_y) or absf(left_y - right_y) > 0.06:
		failures.append("control %s/%s %s lost its symmetric roof (%.3f / %.3f)" % [style, trade, size.name, left_y, right_y])
	mesh.clear_surfaces()


func _uncut_roof_z(layout: Dictionary) -> float:
	var along := float(layout.get("along", 0.0))
	var half := along * 0.5
	var bay: Dictionary = layout.get("witch_bay", {})
	for candidate in [0.0, -half * 0.5, half * 0.5, -half + 0.12, half - 0.12]:
		if absf(candidate) > half - 0.04:
			continue
		if bay.is_empty() or candidate < float(bay.get("along_lo", INF)) - 0.04 or candidate > float(bay.get("along_hi", -INF)) + 0.04:
			return float(candidate)
	return NAN


func _retained_gable_stations(layout: Dictionary) -> Array[float]:
	var result: Array[float] = []
	var station_offset := float(layout.get("along", 0.0)) * 0.5 + HouseGeometry.BEAM_D * 0.5 - 0.01
	var bay: Dictionary = layout.get("witch_bay", {})
	var roof_faces: Array[PackedVector3Array] = layout["faces"]
	for end_sign in [-1.0, 1.0]:
		var station := float(end_sign) * station_offset
		if bay.is_empty() or station < float(bay.get("along_lo", INF)) - 0.001 or station > float(bay.get("along_hi", -INF)) + 0.001:
			result.append(station)
	return result


func _surface_height(mesh: ArrayMesh, surface: int, xz: Vector2, top_y: float) -> float:
	if surface >= mesh.get_surface_count():
		return NAN
	var arrays := mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
	var count := indices.size() if not indices.is_empty() else vertices.size()
	var best := -INF
	for i in range(0, count - 2, 3):
		var i0: int = indices[i] if not indices.is_empty() else i
		var i1: int = indices[i + 1] if not indices.is_empty() else i + 1
		var i2: int = indices[i + 2] if not indices.is_empty() else i + 2
		var hit: Variant = Geometry3D.segment_intersects_triangle(
			Vector3(xz.x, top_y, xz.y), Vector3(xz.x, -0.5, xz.y),
			vertices[i0], vertices[i1], vertices[i2])
		if hit is Vector3:
			best = maxf(best, hit.y)
	return best


func _surface_segment_hits(mesh: ArrayMesh, surface: int, a: Vector3, b: Vector3) -> bool:
	if surface >= mesh.get_surface_count():
		return false
	var arrays := mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
	var count := indices.size() if not indices.is_empty() else vertices.size()
	for i in range(0, count - 2, 3):
		var i0: int = indices[i] if not indices.is_empty() else i
		var i1: int = indices[i + 1] if not indices.is_empty() else i + 1
		var i2: int = indices[i + 2] if not indices.is_empty() else i + 2
		var hit: Variant = Geometry3D.segment_intersects_triangle(a, b,
			vertices[i0], vertices[i1], vertices[i2])
		if hit is Vector3:
			return true
	return false


func _check_ridge_crown(builder: HouseBuilder, layout: Dictionary, who: String) -> void:
	var transform: Transform3D = layout["transform"]
	var inverse := transform.affine_inverse()
	var expected_x := float(layout["ridge_x"])
	var crowns := 0
	for row in builder.component_log:
		if String(row.get("role", "")) not in ["ridge_crown_plinth", "ridge_crown"]:
			continue
		crowns += 1
		var crown_xf: Transform3D = row["xf"]
		var local := inverse * crown_xf.origin
		if absf(local.x - expected_x) > 0.01 or absf(local.z) > 0.01:
			failures.append("%s ridge crown is not centred on the rotated roof ridge (%.3f, %.3f)" % [who, local.x, local.z])
	if crowns != 2:
		failures.append("%s expected both ridge crown members, found %d" % [who, crowns])


func _check_gable_infill(mesh: ArrayMesh, layout: Dictionary, plan: HousePlan, who: String) -> void:
	var transform: Transform3D = layout["transform"]
	var half_along := float(layout["along"]) * 0.5
	var ridge_x := float(layout["ridge_x"])
	var rise := float(layout["rise"])
	var bay: Dictionary = layout.get("witch_bay", {})
	var roof_faces: Array[PackedVector3Array] = layout["faces"]
	for end_sign in [-1.0, 1.0]:
		var local_z := float(end_sign) * half_along
		var outside_z := local_z + float(end_sign) * 0.5
		var inside_z := local_z - float(end_sign) * 0.5
		var cut_end := not bay.is_empty() and local_z >= float(bay.get("along_lo", INF)) - 0.001 and local_z <= float(bay.get("along_hi", -INF)) + 0.001
		if not cut_end:
			var original_y := rise * 0.56
			var original_outside := transform * Vector3(ridge_x, original_y, outside_z)
			var original_inside := transform * Vector3(ridge_x, original_y, inside_z)
			if not _surface_segment_hits(mesh, WALL_SURFACE, original_outside, original_inside):
				failures.append("%s original gable profile is missing outside the bay at end %.0f" % [who, end_sign])
			continue
		var axis := int(bay.get("axis", 0))
		var outer := float(bay["outer"])
		var inner := float(bay["inner"])
		var local_x := (outer + inner) * 0.5
		var local_point := Vector2(local_x, local_z) if axis == 0 else Vector2(local_z, local_x)
		var host_under := RoofShape.height_at(roof_faces, local_point) - RoofShape.DEPTH * 0.5
		var span_t := clampf((local_x - outer) / (inner - outer), 0.0, 1.0)
		var shed_under := lerpf(float(bay["eave_y"]), float(bay["join_y"]), span_t) - RoofShape.DEPTH * 0.5
		if not is_finite(host_under) or host_under <= shed_under + 0.10:
			failures.append("%s cut gable station %.3f has no measurable upper infill band" % [who, local_z])
			continue
		var lower_y := minf(shed_under - 0.035, maxf(0.025, shed_under * 0.5))
		if lower_y <= 0.0:
			failures.append("%s cut gable station %.3f has no lower wall segment beneath shed" % [who, local_z])
			continue
		var low_a := transform * Vector3(local_x, lower_y, outside_z)
		var low_b := transform * Vector3(local_x, lower_y, inside_z)
		if not _surface_segment_hits(mesh, WALL_SURFACE, low_a, low_b):
			failures.append("%s supported lower shed-section gable infill is missing at end %.0f" % [who, end_sign])
		var upper_y := (shed_under + host_under) * 0.5
		var high_a := transform * Vector3(local_x, upper_y, outside_z)
		var high_b := transform * Vector3(local_x, upper_y, inside_z)
		if _surface_segment_hits(mesh, WALL_SURFACE, high_a, high_b):
			failures.append("%s floating original gable infill remains above shed underside at end %.0f" % [who, end_sign])


func _check_rafter_bearings(builder: HouseBuilder, mesh: ArrayMesh, layout: Dictionary,
		plan: HousePlan, who: String) -> void:
	var rafters: Array[Dictionary] = []
	var collars := 0
	var kingposts: Array[Dictionary] = []
	var ties: Array[Dictionary] = []
	var consistency := ComponentCheck.check(builder, mesh)
	if not bool(consistency.get("ok", false)):
		failures.append("%s frame components differ from emitted mesh triangles: %s" % [who, consistency.get("failures", [])])
	var roof_xf: Transform3D = layout["transform"]
	var inverse := roof_xf.affine_inverse()
	var retained := _retained_gable_stations(layout)
	var ridge_x := float(layout["ridge_x"])
	var rise := float(layout["rise"])
	var span := float(layout["span"])
	var wall_half := span * 0.5
	var roof_half := wall_half + HouseGeometry.roof_span_out(plan.spec)
	for row in builder.component_log:
		match String(row.get("role", "")):
			"gable_tie": ties.append(row)
			"witch_collar": collars += 1
			"witch_kingpost": kingposts.append(row)
			"witch_rafter": rafters.append(row)
	if rafters.size() != retained.size() * 2 or ties.size() != retained.size() or collars != retained.size() or kingposts.size() != retained.size():
		failures.append("%s retained gable frame rafter/tie/collar/kingpost=%d/%d/%d/%d; %d actual stations require 2/1/1/1 each" % [who, rafters.size(), ties.size(), collars, kingposts.size(), retained.size()])
		return
	for station in retained:
		var local_rafters := 0
		for row in rafters:
			var rafter_xf: Transform3D = row["xf"]
			if absf((inverse * rafter_xf.origin).z - station) <= 0.025:
				local_rafters += 1
		if local_rafters != 2:
			failures.append("%s retained gable station %.3f emitted %d principal rafters, expected two" % [who, station, local_rafters])
	var ridge_points: Array[Vector3] = []
	for row in rafters:
		var xf: Transform3D = row["xf"]
		var size: Vector3 = row["size"]
		var local_y := inverse.basis * xf.basis.y.normalized()
		var up_sign := 1.0 if local_y.y > 0.0 else -1.0
		var up := xf.basis.y.normalized() * up_sign
		var end_a := xf * Vector3(-size.x * 0.5, 0.0, 0.0)
		var end_b := xf * Vector3(size.x * 0.5, 0.0, 0.0)
		var local_a := inverse * end_a
		var local_b := inverse * end_b
		var a_is_ridge := absf(local_a.x - ridge_x) < absf(local_b.x - ridge_x)
		var ridge_local: Vector3 = local_a if a_is_ridge else local_b
		var foot_local: Vector3 = local_b if a_is_ridge else local_a
		var side := -1.0 if foot_local.x < 0.0 else 1.0
		var outer_x := side * roof_half
		var slope_dir := (Vector2(ridge_x, rise) - Vector2(outer_x, 0.0)).normalized()
		var normal := Vector2(-slope_dir.y, slope_dir.x)
		if normal.y < 0.0:
			normal = -normal
		var plate_center_y := HouseGeometry.PLATE_H * 0.5
		var seat_plane_y := plate_center_y + RoofShape.DEPTH * 0.5 + normal.y * HouseGeometry.BEAM_W
		var seat_t := clampf(seat_plane_y / rise, 0.0, 1.0)
		var bearing_margin := 0.02
		var min_roof_x := -wall_half + bearing_margin + normal.x * HouseGeometry.BEAM_W
		var max_roof_x := wall_half - bearing_margin + normal.x * HouseGeometry.BEAM_W
		var seat_x := clampf(lerpf(outer_x, ridge_x, seat_t), min_roof_x, max_roof_x)
		var expected_ridge_x := ridge_x - normal.x * size.y * 0.5
		var expected_foot_x := seat_x - normal.x * size.y * 0.5
		if absf(ridge_local.x - expected_ridge_x) > 0.002:
			failures.append("%s rafter normal-offset ridge end misses by %.3f m" % [who, absf(ridge_local.x - expected_ridge_x)])
		var bearing_x := seat_x - normal.x * HouseGeometry.BEAM_W
		if absf(foot_local.x - expected_foot_x) > 0.002 \
				or absf(bearing_x) > wall_half - 0.019:
			failures.append("%s rafter foot misses analytic wall-plate birdsmouth seat" % who)
		ridge_points.append(ridge_local)
		var foot_underside := xf * Vector3(-size.x * 0.5 if not a_is_ridge else size.x * 0.5, -up_sign * size.y * 0.5, 0.0)
		var bearing_found := false
		var bearing_triangle_found := false
		for tie in ties:
			if not _component_box_contains(tie, foot_underside):
				continue
			bearing_found = true
			var tie_xf: Transform3D = tie["xf"]
			var moved_tie := tie.duplicate(true)
			var moved_xf: Transform3D = moved_tie["xf"]
			var moved_local := inverse * moved_xf.origin
			var actual_inset := wall_half - absf((inverse * foot_underside).x)
			moved_local.x -= side * (actual_inset + 0.03)
			moved_xf.origin = roof_xf * moved_local
			moved_tie["xf"] = moved_xf
			if _component_box_contains(moved_tie, foot_underside):
				failures.append("%s translated wall-plate negative still reports rafter bearing" % who)
			var tie_local := inverse * tie_xf.origin
			var underside_local := inverse * foot_underside
			var sample_x := underside_local.x - side * 0.08
			var sample := roof_xf * Vector3(sample_x, tie_local.y, tie_local.z)
			if _surface_segment_hits(mesh, 1, sample - Vector3.UP * 0.15, sample + Vector3.UP * 0.15):
				bearing_triangle_found = true
		if not bearing_found:
			failures.append("%s rafter underside does not overlap the actual tie plate" % who)
		if not bearing_triangle_found:
			failures.append("%s wall-plate bearing has no actual trim-surface triangle in the neighboring plate section" % who)
		# The member's upper face meets roof triangles along the whole bearing run.
		for along in [-0.45, -0.2, 0.0, 0.2, 0.45]:
			var top_point := xf * Vector3(size.x * along, up_sign * size.y * 0.5, 0.0)
			if not _surface_segment_hits(mesh, ROOF_SURFACE, top_point, top_point + up * 0.01):
				failures.append("%s rafter upper face misses roof triangles at %.2f" % [who, along])
				break
		var shifted := xf
		shifted.origin -= up * 0.03
		var shifted_top := shifted * Vector3(0.0, up_sign * size.y * 0.5, 0.0)
		if _surface_segment_hits(mesh, ROOF_SURFACE, shifted_top, shifted_top + up * 0.01):
			failures.append("%s 30 mm displaced rafter still passes roof-contact ray" % who)
	for i in range(0, ridge_points.size(), 2):
		if i + 1 >= ridge_points.size():
			break
		var first_world := roof_xf * ridge_points[i]
		var second_world := roof_xf * ridge_points[i + 1]
		var contacted := false
		for post in kingposts:
			if _component_box_contains(post, first_world) and _component_box_contains(post, second_world):
				contacted = true
		if not contacted:
			failures.append("%s paired rafters do not overlap an emitted kingpost at ridge" % who)


func _component_box_contains(row: Dictionary, point: Vector3) -> bool:
	var xf: Transform3D = row["xf"]
	var size: Vector3 = row["size"]
	var local := xf.affine_inverse() * point
	return absf(local.x) <= size.x * 0.5 + 0.002 \
		and absf(local.y) <= size.y * 0.5 + 0.002 \
		and absf(local.z) <= size.z * 0.5 + 0.002
