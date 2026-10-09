extends SceneTree
## Focused, artifact-only roofcraft fixture. It checks actual emitted roof
## triangles, named component parity, plan-aware bounds, and chimney clearance.

class MissingChimneyPotBuilder extends HouseBuilder:
	func _emit_chimney_pots(_centre: Vector2, _top: float, _flue_size: float) -> void:
		pass


const ROOF_SURFACE := 2
const FLUE_CLEAR := 0.6
const SIZES := [
	{"name": "small", "width": 7.0, "length": 9.0, "height": 2.6},
	{"name": "default", "width": 9.0, "length": 12.0, "height": 2.6},
	{"name": "large", "width": 17.0, "length": 18.0, "height": 2.8},
]
const SEEDS := [1, 8102, 21325]
const CUSTOM_SPEC := preload("res://tests/fixtures/witch_custom_house_spec.gd")

var failures: Array[String] = []


func _init() -> void:
	for size in SIZES:
		for seed in SEEDS:
			_check_witch(size, seed)
	_check_control(&"cottage", &"none", false)
	_check_legacy_thatch_control()
	_check_control(&"witch_hut", &"alchemist", false)
	_check_control(&"witch_hut", &"none", true)
	_check_custom_control()
	for failure in failures:
		printerr("FAIL ", failure)
	print("witch roofcraft: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_witch(size: Dictionary, seed: int) -> void:
	var spec := HouseSpec.new()
	spec.style = &"witch_hut"
	spec.width = float(size.width)
	spec.length = float(size.length)
	spec.height = float(size.height)
	var plan := HouseGenerator.generate(spec, seed, false)
	if plan == null:
		_fail("%s/%d plan did not generate" % [size.name, seed])
		return
	var layout := HouseGeometry.roof_layout(plan)
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan, true)
	var who := "%s/%d" % [size.name, seed]
	if not HouseGeometry.roof_has_thatch_roll(plan.spec, plan.world_family):
		_fail("%s eligible built-in Witch did not receive physical thatch" % who)
	var eaves := _components_exact(builder, "thatch_eave")
	var service_eaves := _components_exact(builder, "thatch_eave_service")
	var rolls := builder.components("thatch_roll_")
	var bay: Dictionary = layout.get("witch_bay", {})
	if (bay.is_empty() and eaves.size() != 2) or (not bay.is_empty() and (eaves.size() != 1 or service_eaves.size() != 1)) or rolls.is_empty():
		_fail("%s exposed eave coverage main/service=%d/%d, ridge bundles=%d" % [who, eaves.size(), service_eaves.size(), rolls.size()])
	var surface_map := {}
	if not _components_match_committed_mesh(builder, mesh, surface_map):
		_fail("%s named components do not resolve to their committed logical material slots" % who)
	var roof_triangles := _main_roof_triangles(builder, mesh, surface_map, who)
	_check_eave_contacts(builder, roof_triangles, layout, who)
	if not bay.is_empty():
		_check_service_eave_contact(builder, mesh, surface_map, layout, who)
	_check_ridge_contacts(builder, mesh, roof_triangles, layout, who)
	_check_bundles_clear_of_roof_cuts(plan, builder, layout, who)
	_check_chimney(plan, builder, mesh, rolls, surface_map, who)
	_check_bounds(plan, mesh, who)
	mesh.clear_surfaces()


func _check_eave_contacts(builder: HouseBuilder, roof_triangles: PackedVector3Array,
		layout: Dictionary, who: String) -> void:
	var eaves := _components_exact(builder, "thatch_eave")
	var bay: Dictionary = layout.get("witch_bay", {})
	var roof_xf: Transform3D = layout["transform"]
	var half_x: float = float(layout["span"]) * 0.5 + HouseGeometry.roof_span_out(builder.spec)
	var faces: Array[PackedVector3Array] = layout["faces"]
	var seen_sides: Array[float] = []
	for row in eaves:
		var local_centre := Vector3.ZERO
		var eave_points: PackedVector3Array = row["points"]
		for world_point in eave_points:
			local_centre += roof_xf.affine_inverse() * world_point
		local_centre /= float(eave_points.size())
		var side := 1.0 if local_centre.x > 0.0 else -1.0
		if not seen_sides.has(side):
			seen_sides.append(side)
		var z: float = local_centre.z
		var x := side * (half_x - 0.012)
		var face: PackedVector3Array = faces[0] if side < 0.0 else faces[1]
		var normal := _up_normal(face)
		var y := RoofShape.height_at(faces, Vector2(x, z)) + RoofShape.DEPTH * 0.5 + 0.01
		var contact := roof_xf * Vector3(x, y, z)
		if not _inside_eave_profile(contact, row, roof_xf):
			_fail("%s eave bundle misses the actual roof edge at side %.0f" % [who, side])
		if not _segment_hits(roof_triangles, contact + roof_xf.basis * normal * 0.015,
				contact - roof_xf.basis * normal * 0.015):
			_fail("%s eave edge contact has no emitted main-roof triangle at side %.0f" % [who, side])
		var baseline_eave := _emitted_component_mesh(row)
		if not _segment_hits(baseline_eave, contact + roof_xf.basis * normal * 0.015,
				contact - roof_xf.basis * normal * 0.015):
			_fail("%s emitted high-roof eave mesh misses its measured edge contact" % who)
		var moved_points: PackedVector3Array = row["points"].duplicate()
		for point_index in range(moved_points.size()):
			moved_points[point_index] += roof_xf.basis * Vector3(-side * 0.03, 0.0, 0.0)
		var detached := _emitted_component_mesh(row, moved_points)
		if _segment_hits(detached, contact + roof_xf.basis * normal * 0.002,
				contact - roof_xf.basis * normal * 0.002):
			_fail("%s actual 30 mm displaced eave mesh still touches its roof edge" % who)
	var expected_main_sides := 2 if bay.is_empty() else 1
	if seen_sides.size() != expected_main_sides:
		_fail("%s emitted %d main-roof eaves; expected %d exposed high-roof side(s)" % [who, seen_sides.size(), expected_main_sides])


func _components_exact(builder: HouseBuilder, role: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in builder.component_log:
		if String(row.get("role", "")) == role:
			result.append(row)
	return result


func _check_service_eave_contact(builder: HouseBuilder, mesh: ArrayMesh,
		surface_map: Dictionary, layout: Dictionary, who: String) -> void:
	var rows := _components_exact(builder, "thatch_eave_service")
	if rows.size() != 1:
		_fail("%s lower service roof has no single measured eave bundle" % who)
		return
	var actual_roof := _committed_role_triangles(builder, mesh, int(surface_map.get(ROOF_SURFACE, -1)), "witch_workshop_bay_roof")
	var row: Dictionary = rows[0]
	var support: Vector3 = row["points"][0]
	if not _segment_hits(actual_roof, support - Vector3.UP * 0.02, support + Vector3.UP * 0.02):
		_fail("%s service thatch eave lacks actual emitted shed-roof contact" % who)
	var kit := MeshKit.new(1)
	kit.slab_poly(row["points"], float(row["depth"]), 0, bool(row["vertical"]))
	var eave_mesh: ArrayMesh = kit.commit()
	var eave_triangles: PackedVector3Array = eave_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if not _segment_hits(eave_triangles, support - Vector3.UP * 0.02, support + Vector3.UP * 0.02):
		_fail("%s service eave component mesh misses its roof-bearing edge" % who)
	var moved: PackedVector3Array = row["points"].duplicate()
	for index in range(moved.size()):
		moved[index] += Vector3.UP * 0.03
	var detached_kit := MeshKit.new(1)
	detached_kit.slab_poly(moved, float(row["depth"]), 0, bool(row["vertical"]))
	var detached_mesh: ArrayMesh = detached_kit.commit()
	var detached_triangles: PackedVector3Array = detached_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if _segment_hits(detached_triangles, support - Vector3.UP * 0.002, support + Vector3.UP * 0.002):
		_fail("%s physically raised service eave still touches its roof-bearing edge" % who)
	eave_mesh.clear_surfaces()
	detached_mesh.clear_surfaces()


func _emitted_component_mesh(row: Dictionary, points_override := PackedVector3Array()) -> PackedVector3Array:
	var points: PackedVector3Array = row["points"] if points_override.is_empty() else points_override
	var kit := MeshKit.new(1)
	kit.slab_poly(points, float(row["depth"]), 0, bool(row["vertical"]))
	var emitted: ArrayMesh = kit.commit()
	var result: PackedVector3Array = emitted.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] if emitted.get_surface_count() > 0 else PackedVector3Array()
	emitted.clear_surfaces()
	return result


func _committed_role_triangles(builder: HouseBuilder, mesh: ArrayMesh,
		surface: int, role: String) -> PackedVector3Array:
	if surface < 0 or surface >= mesh.get_surface_count():
		return PackedVector3Array()
	var kit := MeshKit.new(1)
	for row in builder.component_log:
		if String(row.get("role", "")) != role or String(row.get("form", "")) != "slab":
			continue
		kit.slab_poly(row["points"], float(row["depth"]), 0, bool(row["vertical"]))
	var expected_mesh := kit.commit()
	if expected_mesh.get_surface_count() == 0:
		return PackedVector3Array()
	var expected: PackedVector3Array = expected_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var actual: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
	if ComponentCheck.missing_triangles(actual, expected) != 0:
		return PackedVector3Array()
	var remaining := ComponentCheck.triangle_counts(expected)
	var selected := PackedVector3Array()
	for index in range(0, actual.size() - 2, 3):
		var key := ComponentCheck.triangle_key(actual[index], actual[index + 1], actual[index + 2])
		if int(remaining.get(key, 0)) <= 0:
			continue
		selected.append(actual[index]); selected.append(actual[index + 1]); selected.append(actual[index + 2])
		remaining[key] = int(remaining[key]) - 1
	expected_mesh.clear_surfaces()
	return selected


func _actual_surface_height_near(mesh: ArrayMesh, surface: int,
		centre: Vector2, radius: float) -> float:
	if surface < 0 or surface >= mesh.get_surface_count():
		return NAN
	var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
	var highest := -INF
	for index in range(0, vertices.size() - 2, 3):
		var tri := [vertices[index], vertices[index + 1], vertices[index + 2]]
		for candidate in _triangle_circle_candidates(tri, centre, radius):
			var y := _triangle_height_at_xz(tri, candidate)
			if is_finite(y):
				highest = maxf(highest, y)
	return highest if is_finite(highest) else NAN


func _triangle_circle_candidates(tri: Array, centre: Vector2, radius: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var xz := [Vector2(tri[0].x, tri[0].z), Vector2(tri[1].x, tri[1].z), Vector2(tri[2].x, tri[2].z)]
	for point in xz:
		if point.distance_to(centre) <= radius + 0.0001:
			result.append(point)
	for edge in range(3):
		var a: Vector2 = xz[edge]
		var b: Vector2 = xz[(edge + 1) % 3]
		var delta := b - a
		var length_sq := delta.length_squared()
		if length_sq <= 1e-10:
			continue
		var t_near := clampf((centre - a).dot(delta) / length_sq, 0.0, 1.0)
		var near_point := a + delta * t_near
		if near_point.distance_to(centre) <= radius + 0.0001:
			result.append(near_point)
		var relative := a - centre
		var qa := length_sq
		var qb := 2.0 * relative.dot(delta)
		var qc := relative.length_squared() - radius * radius
		var discriminant := qb * qb - 4.0 * qa * qc
		if discriminant >= 0.0:
			var root := sqrt(discriminant)
			for t in [(-qb - root) / (2.0 * qa), (-qb + root) / (2.0 * qa)]:
				if t >= 0.0 and t <= 1.0:
					result.append(a + delta * t)
	for sector in range(48):
		var angle := TAU * float(sector) / 48.0
		var point := centre + Vector2(cos(angle), sin(angle)) * radius
		if _point_in_triangle_xz(point, xz):
			result.append(point)
	if _point_in_triangle_xz(centre, xz):
		result.append(centre)
	return result


func _point_in_triangle_xz(point: Vector2, tri: Array) -> bool:
	var a: Vector2 = tri[0]
	var b: Vector2 = tri[1]
	var c: Vector2 = tri[2]
	var area := (b - a).cross(c - a)
	if absf(area) <= 1e-9:
		return false
	var u := (b - point).cross(c - point) / area
	var v := (c - point).cross(a - point) / area
	var w := (a - point).cross(b - point) / area
	return u >= -0.00001 and v >= -0.00001 and w >= -0.00001


func _triangle_height_at_xz(tri: Array, point: Vector2) -> float:
	var a: Vector3 = tri[0]
	var b: Vector3 = tri[1]
	var c: Vector3 = tri[2]
	var xz := [Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)]
	if not _point_in_triangle_xz(point, xz):
		return NAN
	var denom: float = (xz[1] - xz[0]).cross(xz[2] - xz[0])
	if absf(denom) <= 1e-9:
		return NAN
	var wb: float = (point - xz[0]).cross(xz[2] - xz[0]) / denom
	var wc: float = (xz[1] - xz[0]).cross(point - xz[0]) / denom
	var wa: float = 1.0 - wb - wc
	return wa * a.y + wb * b.y + wc * c.y


func _actual_chimney_crown_top(mesh: ArrayMesh, centre: Vector2, flue_top: float, footprint: float) -> float:
	var highest := -INF
	for surface in range(mesh.get_surface_count()):
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for point in vertices:
			if Vector2(point.x - centre.x, point.z - centre.y).length() <= footprint * 0.5 + 0.45 and point.y >= flue_top - 0.01:
				highest = maxf(highest, point.y)
	return highest if is_finite(highest) else NAN


func _check_ridge_contacts(builder: HouseBuilder, mesh: ArrayMesh,
		roof_triangles: PackedVector3Array, layout: Dictionary, who: String) -> void:
	var roof_xf: Transform3D = layout["transform"]
	var inverse := roof_xf.affine_inverse()
	var ridge_x := float(layout["ridge_x"])
	var ridge_y := RoofShape.height_at(layout["faces"], Vector2(ridge_x, 0.0))
	var expected_half: float = HouseGeometry.ROLL_W * 0.5
	for row in builder.components("thatch_roll_"):
		var points: PackedVector3Array = row["points"]
		if points.size() != 5:
			_fail("%s ridge bundle is not a rounded five-point bundle section" % who)
			continue
		for foot_index in [0, 4]:
			var local: Vector3 = inverse * points[foot_index]
			var expected_x := ridge_x + (-expected_half if foot_index == 0 else expected_half)
			var face: PackedVector3Array = layout["faces"][0] if foot_index == 0 else layout["faces"][1]
			var normal := _up_normal(face)
			var expected_y: float = RoofShape.height_at(layout["faces"], Vector2(local.x, local.z)) \
				+ RoofShape.DEPTH * 0.5
			if absf(local.x - expected_x) > 0.002 or absf(local.y - expected_y) > 0.002:
				_fail("%s ridge roll foot does not meet the actual offset roof plane" % who)
			var point := points[foot_index]
			var world_normal := (roof_xf.basis * normal).normalized()
			if not _segment_hits(roof_triangles, point + world_normal * 0.015,
					point - world_normal * 0.015):
				_fail("%s ridge roll foot has no emitted main-roof triangle contact" % who)
			var moved := point + world_normal * 0.03
			if _segment_hits(roof_triangles, moved + world_normal * 0.01,
					moved - world_normal * 0.01):
				_fail("%s detached ridge-foot negative still touches the roof" % who)
		var local_apex: Vector3 = inverse * points[2]
		if absf(local_apex.x - ridge_x) > 0.002 or absf(local_apex.y - ridge_y - HouseGeometry.ROLL_H) > 0.002:
			_fail("%s ridge roll crest is not centred over the actual shifted ridge" % who)
		for shoulder_index in [1, 3]:
			var shoulder_local: Vector3 = inverse * points[shoulder_index]
			var expected_shoulder_x: float = ridge_x + (-expected_half * 0.45 if shoulder_index == 1 else expected_half * 0.45)
			var shoulder_y: float = RoofShape.height_at(layout["faces"], Vector2(shoulder_local.x, shoulder_local.z)) \
				+ RoofShape.DEPTH * 0.5 + HouseGeometry.ROLL_H * 0.38
			if absf(shoulder_local.x - expected_shoulder_x) > 0.002 or absf(shoulder_local.y - shoulder_y) > 0.002:
				_fail("%s ridge bundle's rounded shoulder is not supported over the actual roof plane" % who)
	var moved_builder := builder
	var first_roll := -1
	for index in range(builder.component_log.size()):
		if String(builder.component_log[index].get("role", "")).begins_with("thatch_roll_"):
			first_roll = index
			break
	if first_roll >= 0:
		var saved: PackedVector3Array = builder.component_log[first_roll]["points"]
		var moved_points := saved.duplicate()
		for point_index in range(moved_points.size()):
			moved_points[point_index] += Vector3.UP * 0.03
		builder.component_log[first_roll]["points"] = moved_points
		var negative_surface_map := {}
		if _components_match_committed_mesh(moved_builder, mesh, negative_surface_map):
			_fail("%s 30 mm moved component-log negative did not detect lost emitted triangles" % who)
		builder.component_log[first_roll]["points"] = saved


func _check_bundles_clear_of_roof_cuts(plan: HousePlan, builder: HouseBuilder,
		layout: Dictionary, who: String) -> void:
	var authored_cuts: Array = HouseGeometry.roof_openings(plan).duplicate(true)
	var bay: Dictionary = layout.get("witch_bay", {})
	var roof_xf: Transform3D = layout["transform"]
	for row in builder.component_log:
		var role: String = String(row.get("role", ""))
		if role != "thatch_eave" and role != "thatch_eave_service" and not role.begins_with("thatch_roll_"):
			continue
		var source: PackedVector3Array = row["points"]
		var cuts: Array = authored_cuts.duplicate(true)
		if role != "thatch_eave_service" and not bay.is_empty():
			cuts.append({"polygon": bay["outline"]})
		var lo_x := INF
		var hi_x := -INF
		var centre_z := 0.0
		for world_point in source:
			var local: Vector3 = roof_xf.affine_inverse() * world_point
			lo_x = minf(lo_x, local.x)
			hi_x = maxf(hi_x, local.x)
			centre_z += local.z
		centre_z /= float(source.size())
		var half_depth: float = float(row["depth"]) * 0.5
		var lo_z := centre_z - half_depth
		var hi_z := centre_z + half_depth
		if role == "thatch_eave_service" and int(bay.get("axis", 0)) == 1:
			lo_x -= half_depth
			hi_x += half_depth
			lo_z = INF
			hi_z = -INF
			for world_point in source:
				var local: Vector3 = roof_xf.affine_inverse() * world_point
				lo_z = minf(lo_z, local.z)
				hi_z = maxf(hi_z, local.z)
		var footprint := PackedVector2Array([
			Vector2(lo_x, lo_z), Vector2(hi_x, lo_z),
			Vector2(hi_x, hi_z), Vector2(lo_x, hi_z)])
		for cut in cuts:
			var polygon: PackedVector2Array = cut.get("polygon", PackedVector2Array())
			if polygon.size() >= 3 and Poly.intersection_area(footprint, polygon) > 0.0001:
				_fail("%s %s bundle overlaps an authored/dormer/bay roof opening" % [who, role])
				break


func _check_chimney(plan: HousePlan, builder: HouseBuilder, mesh: ArrayMesh,
		rolls: Array, surface_map: Dictionary, who: String) -> void:
	var roll_top := -INF
	for row in rolls:
		var points: PackedVector3Array = row["points"]
		roll_top = maxf(roll_top, points[2].y)
	var flue_size := HouseGeometry.chimney_flue_size(plan.spec, plan.world_family)
	var flue_top := -INF
	for part in builder.part_log:
		if String(part.get("tag", "")) == "chimney" and is_equal_approx(float(part["size"].x), flue_size) \
				and float(part["size"].y) > 0.5:
			flue_top = maxf(flue_top, float(part["pos"].y) + float(part["size"].y) * 0.5)
	var layout := HouseGeometry.roof_layout(plan)
	var bay: Dictionary = layout.get("witch_bay", {})
	if not is_finite(flue_top):
		_fail("%s stepped flue top is not measured from its emitted masonry" % who)
	elif not bay.is_empty():
		var centre := HouseGeometry.chimney_center(plan)
		var roof_surface := int(surface_map.get(ROOF_SURFACE, -1))
		var adjacent_top := _actual_surface_height_near(mesh, roof_surface, centre, 3.0)
		var measured_clearance := flue_top - adjacent_top
		if not is_finite(adjacent_top) or measured_clearance < FLUE_CLEAR - 0.002 \
				or measured_clearance > FLUE_CLEAR + 0.02:
			_fail("%s flue misses its 0.6 m measured local-roof clearance (%.3f m)" % [who, measured_clearance])
	elif not is_finite(roll_top) or absf(flue_top - roll_top - FLUE_CLEAR) > 0.002:
		_fail("%s legacy flue does not retain its established 0.6 m ridge-roll clearance" % who)
	var mass := builder.mass_aabb("chimney")
	if mass.size == Vector3.ZERO:
		_fail("%s chimney structural mass is missing" % who)
		return
	var chimney_parts := 0
	var shrink_negative_checked := false
	for part in builder.part_log:
		if String(part.get("tag", "")) != "chimney" or String(part.get("kind", "")) != "box":
			continue
		chimney_parts += 1
		var half: Vector3 = Vector3(part["size"]) * 0.5
		var centre: Vector3 = part["pos"]
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var corner := centre + Vector3(half.x * sx, half.y * sy, half.z * sz)
					if not _aabb_contains_with_tolerance(mass, corner, 0.0001):
						_fail("%s chimney mass excludes an emitted masonry box corner %s" % [who, str(corner)])
					if not shrink_negative_checked:
						var shrunken := AABB(mass.position + Vector3.ONE * 0.01,
							mass.size - Vector3.ONE * 0.02)
						if _aabb_contains_with_tolerance(shrunken, corner, 0.0001):
							_fail("%s 10 mm chimney-mass shrink negative still contains a measured emitted corner" % who)
						shrink_negative_checked = true
	if chimney_parts < 4:
		_fail("%s stepped chimney did not emit its lower base, shoulder, upper flue, and crown boxes" % who)
	var chimney_center := HouseGeometry.chimney_center(plan)
	if not _aabb_contains_with_tolerance(mass,
			Vector3(chimney_center.x, flue_top, chimney_center.y), 0.0001):
		_fail("%s chimney structural mass omits the real upper-flue top" % who)
	var mass_top := mass.position.y + mass.size.y
	var expected_mass_top := flue_top + 0.18 + HouseGeometry.CHIMNEY_POT_H
	if absf(mass_top - expected_mass_top) > 0.002:
		_fail("%s chimney mass top does not include the complete emitted pot envelope" % who)
	var mesh_top := _actual_chimney_crown_top(mesh, HouseGeometry.chimney_center(plan), flue_top, mass.size.x)
	if not is_finite(mesh_top) or absf(mesh_top - mass_top) > 0.002:
		_fail("%s actual emitted chimney-pot crown does not reach the top of its structural mass" % who)
	var missing_pot_builder := MissingChimneyPotBuilder.new()
	var missing_pot_mesh: ArrayMesh = missing_pot_builder.build(plan, true)
	var missing_pot_top := _actual_chimney_crown_top(missing_pot_mesh,
		HouseGeometry.chimney_center(plan), flue_top, mass.size.x)
	if is_finite(missing_pot_top) and missing_pot_top >= mass_top - HouseGeometry.CHIMNEY_POT_H * 0.5:
		_fail("%s missing-pot actual-mesh negative still reaches the structural crown" % who)
	missing_pot_mesh.clear_surfaces()


func _check_bounds(plan: HousePlan, mesh: ArrayMesh, who: String) -> void:
	_check_mesh_within(mesh, HouseGeometry.exterior_bounds(plan), who, "plan-aware")


func _check_mesh_within(mesh: ArrayMesh, bounds: AABB, who: String, label: String) -> void:
	for surface in range(mesh.get_surface_count()):
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for point in vertices:
			if point.x < bounds.position.x - 0.002 or point.y < bounds.position.y - 0.002 \
					or point.z < bounds.position.z - 0.002 or point.x > bounds.end.x + 0.002 \
					or point.y > bounds.end.y + 0.002 or point.z > bounds.end.z + 0.002:
				_fail("%s emitted mesh escaped its %s envelope at %s" % [who, label, str(point)])
				return


func _check_control(style: StringName, trade: StringName, world: bool) -> void:
	var spec := HouseSpec.new()
	spec.style = style
	spec.trade = trade
	spec.width = 9.0
	spec.length = 12.0
	var plan := HouseGenerator.generate(spec, 8102, false)
	if plan == null:
		_fail("control %s/%s plan did not generate" % [style, trade])
		return
	if world:
		plan.world_family = &"vastu"
	if HouseGeometry.roof_has_thatch_roll(plan.spec, plan.world_family) or HouseGeometry.has_witch_roofcraft(plan.spec, plan.world_family):
		_fail("control %s/%s world=%s entered Witch roofcraft" % [style, trade, world])
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan, true)
	if not builder.components("thatch_eave").is_empty() or not builder.components("thatch_roll_").is_empty():
		_fail("control %s/%s world=%s emitted Witch thatch bundles" % [style, trade, world])
	if world:
		_check_mesh_within(mesh, HouseGeometry.spec_bounds(plan.spec), "control %s/%s world" % [style, trade], "conservative spec-only")
	mesh.clear_surfaces()


func _check_legacy_thatch_control() -> void:
	# Explicit thatch_roll predates the Witch path. Keep its legacy three-point
	# ridge and chimney top at the baseline ridge + CHIMNEY_CLEAR datum.
	var spec := HouseSpec.new()
	spec.style = &"cottage"
	spec.width = 9.0
	spec.length = 12.0
	spec.thatch_roll = true
	var plan := HouseGenerator.generate(spec, 8102, false)
	if plan == null:
		_fail("legacy thatch Cottage control plan did not generate")
		return
	if HouseGeometry.has_witch_roofcraft(spec, plan.world_family):
		_fail("legacy thatch Cottage entered Witch roofcraft scope")
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan, true)
	var rolls := builder.components("thatch_roll_")
	var eaves := builder.components("thatch_eave")
	if rolls.is_empty() or eaves.size() != 2:
		_fail("legacy thatch Cottage no longer emits its baseline rolls and two box eaves")
	for row in rolls:
		if PackedVector3Array(row.get("points", PackedVector3Array())).size() != 3:
			_fail("legacy thatch Cottage ridge roll changed from its baseline triangular section")
	for row in eaves:
		if String(row.get("form", "")) != "box":
			_fail("legacy thatch Cottage eave changed from its baseline box")
	var expected_flue_top: float = spec.height * float(maxi(spec.storeys, 1)) \
		+ HouseGeometry.roof_rise(spec) + HouseBuilder.CHIMNEY_CLEAR
	var actual_flue_top := -INF
	for part in builder.part_log:
		if String(part.get("tag", "")) != "chimney" or String(part.get("kind", "")) != "box":
			continue
		if not is_equal_approx(float(part["size"].x), HouseGeometry.chimney_size(spec)) \
				or float(part["size"].y) <= 0.5:
			continue
		actual_flue_top = maxf(actual_flue_top,
			float(part["pos"].y) + float(part["size"].y) * 0.5)
	if not is_finite(actual_flue_top) or absf(actual_flue_top - expected_flue_top) > 0.002:
		_fail("legacy thatch Cottage chimney top moved from its baseline ridge + 0.6 m")
	mesh.clear_surfaces()


func _check_custom_control() -> void:
	var plan := HouseGenerator.generate(HouseSpec.new(), 8102, false)
	if plan == null:
		_fail("custom scope control plan did not generate")
		return
	var custom := CUSTOM_SPEC.new() as HouseSpec
	custom.style = &"witch_hut"
	custom.trade = &"none"
	custom.roof_type = &"gable"
	custom.roof_material = &"thatch"
	plan.spec = custom
	if HouseGeometry.has_witch_roofcraft(custom) or HouseGeometry.roof_has_thatch_roll(custom):
		_fail("custom Witch HouseSpec subclass entered the built-in roofcraft path")


func _components_match_committed_mesh(builder: HouseBuilder, mesh: ArrayMesh,
		resolved_slots: Dictionary) -> bool:
	resolved_slots.clear()
	var expected_by_slot := {}
	for row in builder.component_log:
		if not ["box", "slab"].has(String(row.get("form", ""))):
			continue
		var slot := int(row["surface"])
		if not expected_by_slot.has(slot):
			expected_by_slot[slot] = MeshKit.new(1)
		var kit: MeshKit = expected_by_slot[slot]
		if row["form"] == "box":
			kit.oriented_box(row["size"], row["xf"], 0)
		else:
			kit.slab_poly(row["points"], float(row["depth"]), 0, bool(row["vertical"]))
	var used_surfaces := {}
	for slot in expected_by_slot:
		var expected_mesh: ArrayMesh = (expected_by_slot[slot] as MeshKit).commit()
		if expected_mesh.get_surface_count() == 0:
			return false
		var expected: PackedVector3Array = expected_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var named_index := -1
		var wanted_name := "material_slot:%d" % int(slot)
		for surface in range(mesh.get_surface_count()):
			if mesh.surface_get_name(surface) == wanted_name:
				named_index = surface
				break
		var candidates: Array[int] = []
		for surface in range(mesh.get_surface_count()):
			if named_index >= 0 and surface != named_index:
				continue
			var actual: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			if ComponentCheck.missing_triangles(actual, expected) == 0:
				candidates.append(surface)
		if candidates.size() != 1 or used_surfaces.has(candidates[0]):
			return false
		resolved_slots[int(slot)] = candidates[0]
		used_surfaces[candidates[0]] = true
	return true


func _main_roof_triangles(builder: HouseBuilder, mesh: ArrayMesh,
		resolved_slots: Dictionary, who: String) -> PackedVector3Array:
	var mesh_slot := int(resolved_slots.get(ROOF_SURFACE, -1))
	if mesh_slot < 0:
		_fail("%s committed mesh has no resolvable logical roof slot %d" % [who, ROOF_SURFACE])
		return PackedVector3Array()
	var actual: PackedVector3Array = mesh.surface_get_arrays(mesh_slot)[Mesh.ARRAY_VERTEX]
	var kit := MeshKit.new(1)
	for row in builder.component_log:
		if String(row.get("host", "")) != "roof" \
				or not String(row.get("role", "")).begins_with("roof_face_"):
			continue
		kit.slab_poly(row["points"], float(row["depth"]), 0, bool(row["vertical"]))
	var isolated := kit.commit()
	if isolated.get_surface_count() == 0:
		return PackedVector3Array()
	var expected: PackedVector3Array = isolated.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if ComponentCheck.missing_triangles(actual, expected) != 0:
		_fail("%s actual committed logical roof slot omits logged main-roof triangles" % who)
		return PackedVector3Array()
	var remaining := ComponentCheck.triangle_counts(expected)
	var selected := PackedVector3Array()
	for i in range(0, actual.size() - 2, 3):
		var key := ComponentCheck.triangle_key(actual[i], actual[i + 1], actual[i + 2])
		if int(remaining.get(key, 0)) <= 0:
			continue
		selected.append(actual[i]); selected.append(actual[i + 1]); selected.append(actual[i + 2])
		remaining[key] = int(remaining[key]) - 1
	for key in remaining:
		if int(remaining[key]) != 0:
			_fail("%s could not resolve every expected main-roof triangle from committed slot %d" % [who, ROOF_SURFACE])
			break
	return selected
func _inside_eave_profile(point: Vector3, row: Dictionary, roof_xf: Transform3D) -> bool:
	var inverse := roof_xf.affine_inverse()
	var local_point: Vector3 = inverse * point
	var source: PackedVector3Array = row["points"]
	var profile := PackedVector2Array()
	var local_z := 0.0
	for index in range(source.size()):
		var local: Vector3 = inverse * source[index]
		profile.append(Vector2(local.x, local.y))
		local_z += local.z
	local_z /= float(source.size())
	return absf(local_point.z - local_z) <= float(row["depth"]) * 0.5 + 0.002 \
		and Geometry2D.is_point_in_polygon(Vector2(local_point.x, local_point.y), profile)


func _inside_box(point: Vector3, row: Dictionary) -> bool:
	var local: Vector3 = row["xf"].affine_inverse() * point
	var size: Vector3 = row["size"]
	return absf(local.x) <= size.x * 0.5 + 0.002 and absf(local.y) <= size.y * 0.5 + 0.002 \
		and absf(local.z) <= size.z * 0.5 + 0.002


func _aabb_contains_with_tolerance(bounds: AABB, point: Vector3, epsilon: float) -> bool:
	var end := bounds.position + bounds.size
	return point.x >= bounds.position.x - epsilon and point.y >= bounds.position.y - epsilon \
		and point.z >= bounds.position.z - epsilon and point.x <= end.x + epsilon \
		and point.y <= end.y + epsilon and point.z <= end.z + epsilon


func _up_normal(face: PackedVector3Array) -> Vector3:
	var normal := (face[1] - face[0]).cross(face[2] - face[0]).normalized()
	return -normal if normal.y < 0.0 else normal


func _segment_hits(vertices: PackedVector3Array, from: Vector3, to: Vector3) -> bool:
	for index in range(0, vertices.size() - 2, 3):
		if Geometry3D.segment_intersects_triangle(from, to,
				vertices[index], vertices[index + 1], vertices[index + 2]) != null:
			return true
	return false


func _fail(message: String) -> void:
	failures.append(message)
