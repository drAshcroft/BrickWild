extends SceneTree

const SIZE_CASES := [
	{"name": "small", "width": 18.0, "length": 24.0, "height": 8.0},
	{"name": "default", "width": 26.0, "length": 44.0, "height": 12.0},
	{"name": "large", "width": 48.0, "length": 80.0, "height": 20.0},
]

var failures: Array[String] = []
var active_case := "unlabelled"

func _fail(message: String) -> void:
	failures.append("%s: %s" % [active_case, message])

func _initialize() -> void:
	for row in SIZE_CASES:
		_check_case(row)
	for failure in failures:
		push_error(failure)
	print("basilica architecture fixture: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_case(row: Dictionary) -> void:
	active_case = "public basilica blood/%s seed=1" % row["name"]
	var spec := TempleSpec.new(1)
	spec.form = &"basilica"
	spec.cult = &"blood"
	spec.width = float(row["width"])
	spec.length = float(row["length"])
	spec.height = float(row["height"])
	TempleGenerator.generate(spec, 1)
	var builder := TempleBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	_check_no_degenerate_triangles(mesh)
	_check_hosted_components(builder.component_log)
	_check_vertical_profile_slabs(builder, mesh)
	_check_roof_hierarchy(spec, builder, mesh)
	_check_portico_floor_and_route(spec, mesh)
	_check_portico_load_path(spec, builder, mesh)
	_check_nave_load_path(spec, builder, mesh)
	_check_clerestory_ray(spec, builder, mesh)
	_check_nave_eave_joint(spec, mesh)
	_check_order_pilaster_bearings(builder, mesh)
	var visible_overlaps := CoplanarCheck.visible(mesh, "basilica/%s" % row["name"])
	print("basilica ", row["name"], " visible_overlaps=", visible_overlaps.size())
	if visible_overlaps.size() > 12:
		_fail("visible same-facing coplanar overlaps %d exceed the unchanged budget 12"
			% visible_overlaps.size())
	if row["name"] == "small":
		_check_missing_column_negative(spec, builder, mesh)
		_check_lifted_portico_roof_negative(spec, builder, mesh)
		_check_no_columns_fallback(spec)


func _check_order_pilaster_bearings(builder: TempleBuilder, mesh: ArrayMesh) -> void:
	var shafts := _roles(builder.component_log, "basilica_order_pilaster_shaft")
	var capitals := _roles(builder.component_log, "basilica_order_pilaster_capital")
	if shafts.is_empty() or shafts.size() != capitals.size():
		_fail("exterior pilasters lack their measured shafts and capitals")
		return
	var capitals_by_host: Dictionary = {}
	for capital in capitals:
		capitals_by_host[capital["host"]] = capital
	for shaft in shafts:
		var capital: Dictionary = capitals_by_host.get(shaft["host"], {})
		if capital.is_empty() or not _pilaster_bears(mesh, shaft, capital):
			_fail("exterior pilaster does not meet its actual capital underside: " + String(shaft["host"]))
	# Delete actual component triangles while retaining all builder records.
	# Both damaged components must fail the positive bearing predicate.
	var first_shaft: Dictionary = shafts[0]
	var first_capital: Dictionary = capitals_by_host[first_shaft["host"]]
	for component in [first_shaft, first_capital]:
		var removed := MeshProbe.remove_triangles(mesh, int(component["surface"]),
			MeshProbe.any_face_in(MassBuilder.component_aabb(component).grow(0.001)))
		var damaged: ArrayMesh = removed.get("mesh")
		if int(removed.get("removed_triangles", 0)) < 12 or damaged == null \
				or _pilaster_bears(damaged, first_shaft, first_capital):
			_fail("removed actual pilaster component escaped the same bearing predicate: " + String(component["role"]))


func _pilaster_bears(mesh: ArrayMesh, shaft: Dictionary, capital: Dictionary) -> bool:
	var shaft_box := MassBuilder.component_aabb(shaft)
	var capital_box := MassBuilder.component_aabb(capital)
	if absf(shaft_box.end.y - capital_box.position.y) > 0.002 \
			or not _component_box_emitted(mesh, shaft) or not _component_box_emitted(mesh, capital):
		return false
	var centre := shaft_box.get_center()
	return MeshProbe.has_upward_support(
		MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE),
		Vector2(centre.x, centre.z), capital_box.position.y, 0.002)


## The raised nave roof bears on both longitudinal walls. Its eave edge is
## closed by the wall face; emitting a second roof side face on that plane
## creates the 53 repeated surface-0/2 fights in the canonical default case.
func _check_nave_eave_joint(spec: TempleSpec, mesh: ArrayMesh) -> void:
	var half: float = TempleGeometry.basilica_nave_half_width(spec)
	var eave: float = TempleGeometry.basilica_nave_eave_height(spec)
	var eave_fights := _nave_eave_fight_count(mesh, half, eave)
	if eave_fights != 0:
		_fail("nave roof still emits %d coplanar wall/eave triangles" % eave_fights)
	var portico_half: float = TempleGeometry.basilica_portico_half_width(spec)
	var portico_eave: float = TempleGeometry.basilica_portico_eave_height(spec)
	var portico_fights := _nave_eave_fight_count(mesh, portico_half, portico_eave)
	if portico_fights != 0:
		_fail("pronaos roof still emits %d coplanar beam/eave triangles" % portico_fights)
	var wall_t: float = TempleGeometry.basilica_nave_wall_thickness(spec)
	var wall_x: float = half - minf(wall_t * 0.05, 0.02)
	var wall_support := MeshProbe.has_upward_support(
		MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE),
		Vector2(wall_x, 0.0), eave, 0.02)
	var roof_triangles := MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_ROOF)
	var roof_hit := _lowest_vertical_hit(roof_triangles, wall_x, 0.0,
		eave - 0.25, eave + 0.35)
	if not wall_support or roof_hit < eave - 0.15 or roof_hit > eave + 0.02:
		_fail("actual nave eave wall/roof bearing was lost with its duplicate edge face")
	var missing_panel := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_STONE,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			return MeshProbe.upward_triangle_contains_point([a, b, c],
				Vector2(wall_x, 0.0), eave, 0.001))
	var panel_mesh: ArrayMesh = missing_panel.get("mesh")
	if int(missing_panel.get("removed_triangles", 0)) == 0 or panel_mesh == null \
			or MeshProbe.has_upward_support(
				MeshProbe.surface_triangles(null, panel_mesh, TempleBuilder.SURF_STONE),
				Vector2(wall_x, 0.0), eave, 0.001):
		_fail("removed actual wall-panel bearing still passes the same support probe")
	var missing_roof := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_ROOF,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			var hit: Variant = Geometry3D.segment_intersects_triangle(
				Vector3(wall_x, eave + 0.02, 0.0), Vector3(wall_x, eave - 0.22, 0.0), a, b, c)
			if hit == null:
				return false
			return (c - a).cross(b - a).normalized().dot(Vector3.UP) < -0.05)
	var roof_mesh: ArrayMesh = missing_roof.get("mesh")
	var missing_roof_hit := _lowest_vertical_hit(
		MeshProbe.surface_triangles(null, roof_mesh, TempleBuilder.SURF_ROOF),
		wall_x, 0.0, eave - 0.25, eave + 0.35) if roof_mesh != null else -1.0
	if int(missing_roof.get("removed_triangles", 0)) == 0 or roof_mesh == null \
			or (missing_roof_hit >= eave - 0.15 and missing_roof_hit <= eave + 0.02):
		_fail("removed actual roof underside still passes the same bearing probe")
	var closed_roof := MeshKit.new(1)
	var xf := Transform3D(Basis(), Vector3(0.0, eave, 0.0))
	var span: float = half * 2.0
	var rise: float = span * TempleGeometry.RIDGE_PITCH
	var length: float = TempleGeometry.site_rect(spec).size.y + 0.8
	for face in RoofShape.faces(span, length, rise):
		var world_face := PackedVector3Array()
		for point in face:
			world_face.append(xf * point)
		# This broken control re-emits the actual omitted eave side quads.
		closed_roof.slab_poly(world_face, RoofShape.DEPTH, 0, true)
	var site: Rect2 = TempleGeometry.site_rect(spec)
	var portico_rise: float = TempleGeometry.basilica_portico_rise(spec)
	var z0: float = site.position.y - TempleGeometry.basilica_portico_depth(spec)
	var z1: float = site.position.y + 0.18
	for side in [-1.0, 1.0]:
		var x: float = side * portico_half
		var points := PackedVector3Array([
			Vector3(x, portico_eave, z0), Vector3(0.0, portico_eave + portico_rise, z0),
			Vector3(0.0, portico_eave + portico_rise, z1), Vector3(x, portico_eave, z1)])
		closed_roof.slab_poly(points, RoofShape.DEPTH, 0, true)
	var closed_mesh: ArrayMesh = closed_roof.commit()
	var mutant := _append_closed_roof_surface(mesh, closed_mesh, TempleBuilder.SURF_ROOF)
	if mutant == null or _nave_eave_fight_count(mutant, half, eave) == 0:
		_fail("re-emitted actual roof eave faces escaped the same coplanar predicate")


func _nave_eave_fight_count(mesh: ArrayMesh, half: float, eave: float) -> int:
	var count := 0
	for finding in CoplanarCheck.find(mesh, [TempleBuilder.SURF_STONE, TempleBuilder.SURF_ROOF]):
		var surfaces: Vector2i = finding["surfaces"]
		if Vector2i(mini(surfaces.x, surfaces.y), maxi(surfaces.x, surfaces.y)) \
				!= Vector2i(TempleBuilder.SURF_STONE, TempleBuilder.SURF_ROOF):
			continue
		var at: Vector3 = finding["at"]
		if absf(absf(at.x) - half) < 0.002 and absf(at.y - eave) <= RoofShape.DEPTH + 0.01:
			count += 1
	return count


func _append_closed_roof_surface(source: ArrayMesh, extra: ArrayMesh,
		roof_surface: int) -> ArrayMesh:
	if source == null or extra == null or roof_surface >= source.get_surface_count() \
			or extra.get_surface_count() == 0:
		return null
	var out := ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		if surface != roof_surface:
			out.add_surface_from_arrays(source.surface_get_primitive_type(surface),
				source.surface_get_arrays(surface))
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(source, surface, Transform3D.IDENTITY)
		st.append_from(extra, 0, Transform3D.IDENTITY)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	return out


func _check_hosted_components(rows: Array[Dictionary]) -> void:
	var required := ["basilica_nave_roof", "basilica_aisle_roof",
		"basilica_portico_roof_slope", "basilica_portico_gable",
		"basilica_portico_column_base", "basilica_portico_column_shaft",
		"basilica_portico_column_capital", "basilica_portico_architrave",
		"basilica_portico_side_beam", "basilica_nave_lower_spandrel",
		"basilica_nave_pier_wall", "basilica_nave_end_crosshead",
		"basilica_nave_end_return", "basilica_clerestory_sill",
		"basilica_clerestory_head", "basilica_nave_gable_spandrel"]
	for role in required:
		var matches := 0
		for row in rows:
			if String(row.get("role", "")) == role:
				matches += 1
				if String(row.get("host", "")).is_empty():
					_fail("new component %s has no host" % role)
		if matches == 0:
			_fail("missing named native component %s" % role)


func _check_vertical_profile_slabs(builder: TempleBuilder, mesh: ArrayMesh) -> void:
	var profile_roles := ["basilica_nave_gable_triangle", "basilica_aisle_gable_fill",
		"basilica_aisle_rake", "basilica_portico_gable"]
	var wrong_axis_control_done := false
	for row in builder.component_log:
		if String(row.get("role", "")) not in profile_roles:
			continue
		if String(row.get("form", "")) != "slab" or bool(row.get("vertical", true)):
			_fail("vertical profile slab %s is not extruded along its actual normal" % row.get("role", ""))
			continue
		var depth: float = float(row.get("depth", 0.0))
		var bounds: AABB = MassBuilder.component_aabb(row)
		if depth <= 0.0 or bounds.size.z < depth - 0.01:
			_fail("vertical profile slab %s has no measured sidewall thickness" % row.get("role", ""))
		var kit := MeshKit.new(1)
		kit.slab_poly(row["points"], depth, 0, false)
		var expected_mesh: ArrayMesh = kit.commit()
		var expected := _surface_vertex_soup(expected_mesh, 0)
		var actual := _surface_vertex_soup(mesh, int(row["surface"]))
		if ComponentCheck.missing_triangles(actual, expected) > 0:
			_fail("vertical profile slab %s is logged but its thickness triangles are absent" % row.get("role", ""))
		if not wrong_axis_control_done:
			var wrong_axis_kit := MeshKit.new(1)
			wrong_axis_kit.slab_poly(row["points"], depth, 0, true)
			var wrong_axis_mesh: ArrayMesh = wrong_axis_kit.commit()
			var wrong_axis := _surface_vertex_soup(wrong_axis_mesh, 0)
			if ComponentCheck.missing_triangles(actual, wrong_axis) == 0:
				_fail("wrong-axis extrusion negative was indistinguishable from the supported slab")
			wrong_axis_control_done = true


func _check_no_degenerate_triangles(mesh: ArrayMesh) -> void:
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var raw_index: Variant = arrays[Mesh.ARRAY_INDEX]
		var order: PackedInt32Array = raw_index as PackedInt32Array \
			if raw_index != null else PackedInt32Array()
		if order.is_empty():
			for index in range(verts.size()):
				order.append(index)
		var degenerate := 0
		for index in range(0, order.size() - 2, 3):
			var a: Vector3 = verts[order[index]]
			var b: Vector3 = verts[order[index + 1]]
			var c: Vector3 = verts[order[index + 2]]
			if (c - a).cross(b - a).length() < 1e-6:
				degenerate += 1
		if degenerate > 0:
			_fail("surface %d contains %d zero-area triangles" % [surface, degenerate])


func _check_roof_hierarchy(spec: TempleSpec, builder: TempleBuilder, mesh: ArrayMesh) -> void:
	var roof: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_ROOF)
	var half: float = TempleGeometry.basilica_nave_half_width(spec)
	var eave: float = TempleGeometry.basilica_nave_eave_height(spec)
	var nave_rise: float = half * 2.0 * TempleGeometry.RIDGE_PITCH
	var nave_hit: float = _vertical_hit_y(roof, 0.0, 0.0, eave - 0.3,
		eave + nave_rise + 0.5)
	var aisle_x: float = (half + spec.width * 0.5) * 0.5
	var aisle_hit: float = _vertical_hit_y(roof, aisle_x, 0.0,
		spec.height - 0.5, eave + 0.5)
	if nave_hit < 0.0 or aisle_hit < 0.0:
		_fail("emitted nave or side-aisle roof lacks a measured triangle at its section")
	elif nave_hit - aisle_hit < 0.65:
		_fail("raised nave ridge is only %.2fm above the lower aisle roof" % (nave_hit - aisle_hit))
	var actual_top := -INF
	for triangle in roof:
		for point in triangle:
			actual_top = maxf(actual_top, point.y)
	var expected_roof_top: float = TempleGeometry.roof_height(spec) \
		+ (spec.spire_height if spec.spire else 0.0)
	if absf(actual_top - expected_roof_top) > 0.02:
		_fail("measured roof top %.3f differs from shared roof plus spire %.3f" % [
			actual_top, expected_roof_top])
	var extent: Rect2 = TempleGeometry.plan_extent(spec)
	var portico: Rect2 = TempleGeometry.basilica_portico_floor_rect(spec)
	if not extent.encloses(portico):
		_fail("public site extent omits the actual covered pronaos floor edge")
	var approach: Rect2 = TempleGeometry.basilica_approach_rect(spec)
	if approach.size.x < TempleGeometry.PROCESSION_MIN - 0.01 \
			or absf(approach.position.y - extent.position.y) > 0.02 \
			or absf(approach.end.y - TempleGeometry.site_rect(spec).position.y) > 0.02:
		_fail("published placement approach does not join actual front paving to the wall gate")
	var bounds := extent.grow(0.02)
	for triangle in roof:
		for point in triangle:
			if not bounds.has_point(Vector2(point.x, point.z)):
				_fail("roof vertex %s escapes the published placement extent" % point)
				return
	for role in ["basilica_nave_gable_spandrel", "basilica_aisle_gable_fill"]:
		for row in _roles(builder.component_log, role):
			var box: AABB = MassBuilder.component_aabb(row)
			for xside in [0.0, 1.0]:
				for yside in [0.0, 1.0]:
					for zside in [0.0, 1.0]:
						var corner := box.position + box.size * Vector3(xside, yside, zside)
						if not bounds.has_point(Vector2(corner.x, corner.z)):
							_fail("%s corner %s escapes the published roof extent" % [role, corner])


func _check_portico_floor_and_route(spec: TempleSpec, mesh: ArrayMesh) -> void:
	var floor_rect: Rect2 = TempleGeometry.basilica_portico_floor_rect(spec)
	var threshold: Rect2 = TempleGeometry.basilica_threshold_rect(spec)
	var interior: Rect2 = TempleGeometry.interior_rect(spec)
	if not is_equal_approx(floor_rect.end.y, threshold.position.y) \
			or not is_equal_approx(threshold.end.y, interior.position.y):
		_fail("paving and gate threshold do not form a contiguous floor to the interior")
	var bounds: Rect2 = TempleGeometry.plan_extent(spec).grow(1.0)
	var approach: Rect2 = TempleGeometry.basilica_approach_rect(spec)
	var grid := WalkGrid.new()
	grid.setup(bounds, TempleGeometry.NAV_CELL)
	for floor in TempleGeometry.floor_rects(spec):
		grid.add_floor(floor)
	for obstacle in TempleGeometry.obstacle_rects(spec):
		grid.add_obstacle(obstacle)
	grid.build(TempleGeometry.PERSON_RADIUS)
	var entry: Vector2 = TempleGeometry.entry_point(spec)
	if not grid.flood_from(entry, 1.2) or not grid.reached(floor_rect):
		_fail("a body cannot walk from the public door onto the actual portico paving")
	var approach_start := Vector2(0.0, approach.position.y + TempleGeometry.PERSON_RADIUS + 0.12)
	var gate_landing := Rect2(Vector2(-TempleGeometry.PERSON_RADIUS, approach.end.y - 0.4),
		Vector2(TempleGeometry.PERSON_RADIUS * 2.0, 0.65))
	if not grid.flood_from(approach_start, 1.2) or not grid.reached(gate_landing):
		_fail("a body cannot walk the published approach to the actual gate threshold")
	var blocked_grid := WalkGrid.new()
	blocked_grid.setup(bounds, TempleGeometry.NAV_CELL)
	for floor in TempleGeometry.floor_rects(spec):
		blocked_grid.add_floor(floor)
	for obstacle in TempleGeometry.obstacle_rects(spec):
		blocked_grid.add_obstacle(obstacle)
	blocked_grid.add_obstacle(Rect2(Vector2(floor_rect.position.x - 0.2,
		approach.get_center().y - 0.2), Vector2(floor_rect.size.x + 0.4, 0.4)))
	blocked_grid.build(TempleGeometry.PERSON_RADIUS)
	blocked_grid.flood_from(approach_start, 1.2)
	if blocked_grid.reached(gate_landing):
		_fail("blocked-approach negative still reaches the gate through an across-porch barrier")
	var floor_triangles: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE)
	var porch_center: Vector2 = floor_rect.get_center()
	if not MeshProbe.has_upward_support(floor_triangles, porch_center, 0.001, 0.03):
		_fail("portico walk floor is planned but has no emitted upward stone support")
	var z: float = approach.position.y + 0.08
	while z <= approach.end.y - 0.08:
		for side in [-1.0, 0.0, 1.0]:
			var x: float = side * TempleGeometry.PERSON_RADIUS
			if not MeshProbe.has_upward_support(floor_triangles, Vector2(x, z), 0.001, 0.03):
				_fail("body-width approach has no emitted floor at x=%.2f z=%.2f" % [x, z])
				break
		z += 0.4
	var approach_mid_z: float = approach.get_center().y
	var no_floor: Dictionary = MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_STONE,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			var probe_z: float = approach.position.y + 0.08
			while probe_z <= approach.end.y - 0.08:
				if Geometry3D.segment_intersects_triangle(Vector3(0.0, 0.12, probe_z),
					Vector3(0.0, -0.05, probe_z), a, b, c) != null:
					return true
				probe_z += 0.4
			return false)
	var broken_floor: ArrayMesh = no_floor.get("mesh")
	if int(no_floor.get("removed_triangles", 0)) < 1 or broken_floor == null:
		_fail("no-floor approach negative did not remove actual emitted stone")
	else:
		var broken_floor_triangles := MeshProbe.surface_triangles(null, broken_floor,
			TempleBuilder.SURF_STONE)
		if MeshProbe.has_upward_support(broken_floor_triangles, Vector2(0.0, approach_mid_z),
			0.001, 0.03):
			_fail("no-floor approach negative retained emitted support at its measured midpoint")


func _check_portico_load_path(spec: TempleSpec, builder: TempleBuilder, mesh: ArrayMesh) -> void:
	var rise: float = TempleGeometry.basilica_portico_rise(spec)
	var shaft_d: float = TempleGeometry.basilica_portico_shaft_diameter(spec)
	var rows := builder.component_log
	var bases: Array[Dictionary] = _roles(rows, "basilica_portico_column_base")
	var shafts: Array[Dictionary] = _roles(rows, "basilica_portico_column_shaft")
	var capitals: Array[Dictionary] = _roles(rows, "basilica_portico_column_capital")
	var beams: Array[Dictionary] = _roles(rows, "basilica_portico_architrave")
	var side_beams: Array[Dictionary] = _roles(rows, "basilica_portico_side_beam")
	var expected_columns: int = column_points(spec).size()
	if bases.size() != expected_columns or shafts.size() != expected_columns \
			or capitals.size() != expected_columns or beams.size() != 1 or side_beams.size() != 2:
		_fail("pronaos does not emit %d complete column bearings and one continuous architrave" % expected_columns)
		return
	for row in bases + shafts + capitals + beams + side_beams:
		if not _component_box_emitted(mesh, row):
			_fail("portico support component triangles differ from its recorded box %s" % row.get("role", ""))
	for i in range(expected_columns):
		var base := MassBuilder.component_aabb(bases[i])
		var shaft := MassBuilder.component_aabb(shafts[i])
		var capital := MassBuilder.component_aabb(capitals[i])
		if absf(base.end.y - shaft.position.y) > 0.01 \
				or absf(shaft.end.y - capital.position.y) > 0.01:
			_fail("portico column %d has a discontinuous base / shaft / capital" % i)
		var shaft_ratio: float = shaft.size.y / maxf(shaft.size.x, 0.01)
		if shaft_ratio < 8.0 or shaft_ratio > 13.5:
			_fail("portico shaft %d is outside the measured classical proportion (%.2f:1)" % [i, shaft_ratio])
		var beam := MassBuilder.component_aabb(beams[0])
		if absf(capital.end.y - beam.position.y) > 0.01:
			_fail("portico column %d capital does not meet the architrave soffit" % i)
		var point: Vector2 = column_points(spec)[i]
		var trim: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE)
		var beam_top: float = beam.end.y
		if not _has_horizontal_face(trim, point.x, point.y, beam_top):
			_fail("portico architrave has no emitted bearing face above column %d" % i)
	var closest_left := INF
	var closest_right := INF
	for i in range(expected_columns):
		var shaft_box := MassBuilder.component_aabb(shafts[i])
		if shaft_box.get_center().x < 0.0:
			closest_left = minf(closest_left, -shaft_box.get_center().x - shaft_box.size.x * 0.5)
		else:
			closest_right = minf(closest_right, shaft_box.get_center().x - shaft_box.size.x * 0.5)
	if closest_left + closest_right < TempleGeometry.PROCESSION_MIN:
		_fail("pronaos column shafts leave only %.2fm of body passage" % [closest_left + closest_right])
	var roof: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_ROOF)
	var half: float = TempleGeometry.basilica_portico_half_width(spec)
	var eave: float = TempleGeometry.basilica_portico_eave_height(spec)
	var front: float = TempleGeometry.site_rect(spec).position.y - TempleGeometry.basilica_portico_depth(spec) + 0.5
	for side_beam_row in side_beams:
		var side_box := MassBuilder.component_aabb(side_beam_row)
		var matched_cap := false
		for row in capitals:
			var cap_box := MassBuilder.component_aabb(row)
			if absf(cap_box.get_center().x - side_box.get_center().x) < 0.01 \
					and side_box.position.z <= cap_box.get_center().z + 0.01 \
					and side_box.end.z >= cap_box.get_center().z - 0.01 \
					and absf(side_box.position.y - cap_box.end.y) < 0.01:
				matched_cap = true
				break
		if not matched_cap:
			_fail("pronaos side beam does not bear on its actual portico capital")
		var roof_contact_z: float = (side_box.position.z + side_box.end.z) * 0.5
		var roof_contact: float = _lowest_vertical_hit(roof,
			side_box.get_center().x, roof_contact_z, eave + 0.3, eave - 0.3)
		var expected_underside: float = eave + rise * (shaft_d * 0.5 / half) \
			- RoofShape.DEPTH * 0.5
		if roof_contact < 0.0 or absf(roof_contact - expected_underside) > 0.06:
			_fail("pronaos side beam does not carry the roof sheet at its actual bearing")
	for side in [-1.0, 1.0]:
		var x: float = side * (half - 0.04)
		var bottom_y: float = _lowest_vertical_hit(roof, x, front, eave - 0.3, eave + 0.3)
		var expected_underside: float = eave + rise * (0.04 / half) \
			- RoofShape.DEPTH * 0.5
		if bottom_y < 0.0 or absf(bottom_y - expected_underside) > 0.05:
			_fail("portico roof eave does not seat at its column line side=%s hit=%.3f" % [side, bottom_y])


func _check_missing_column_negative(spec: TempleSpec, builder: TempleBuilder, mesh: ArrayMesh) -> void:
	var shaft: Dictionary = _roles(builder.component_log, "basilica_portico_column_shaft")[0]
	var aabb: AABB = MassBuilder.component_aabb(shaft).grow(0.001)
	var removed: Dictionary = MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_STONE,
		MeshProbe.any_face_in(aabb))
	var mutated: ArrayMesh = removed.get("mesh")
	if int(removed.get("removed_triangles", 0)) < 12 or mutated == null \
			or _component_box_emitted(mutated, shaft):
		_fail("missing-column control did not remove an actual emitted support")


func _check_lifted_portico_roof_negative(spec: TempleSpec, builder: TempleBuilder, mesh: ArrayMesh) -> void:
	var half: float = TempleGeometry.basilica_portico_half_width(spec)
	var eave: float = TempleGeometry.basilica_portico_eave_height(spec)
	var front: float = TempleGeometry.site_rect(spec).position.y - TempleGeometry.basilica_portico_depth(spec) + 0.5
	var x: float = half - 0.04
	var ray_from := Vector3(x, eave + 0.3, front)
	var ray_to := Vector3(x, eave - 0.3, front)
	var removed := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_ROOF,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			return Geometry3D.segment_intersects_triangle(ray_from, ray_to, a, b, c) != null)
	var without_eave: ArrayMesh = removed.get("mesh")
	if int(removed.get("removed_triangles", 0)) == 0 or without_eave == null:
		_fail("raised-roof negative control did not remove the actual portico eave triangles")
		return
	var raised := MeshProbe.add_box(without_eave, TempleBuilder.SURF_ROOF,
		AABB(Vector3(x - 0.12, eave + 0.28, front - 0.12), Vector3(0.24, 0.08, 0.24)))
	var raised_mesh: ArrayMesh = raised.get("mesh")
	var expected_bottom: float = eave - RoofShape.DEPTH * 0.5
	var raised_hit: float = _lowest_vertical_hit(MeshProbe.surface_triangles(null,
		raised_mesh, TempleBuilder.SURF_ROOF), x, front, eave - 0.3, eave + 0.3) \
		if raised_mesh != null else -1.0
	if int(raised.get("added_triangles", 0)) != 12 or raised_mesh == null \
			or raised_hit < 0.0 or absf(raised_hit - expected_bottom) < 0.05:
		_fail("lifted portico roof control was not rejected at its real support line")


func _check_nave_load_path(spec: TempleSpec, builder: TempleBuilder, mesh: ArrayMesh) -> void:
	var primary_x := INF
	for column in spec.columns:
		var p: Vector3 = column["pos"]
		primary_x = minf(primary_x, absf(p.x))
	if primary_x == INF:
		_fail("basilica has no final generated columns to carry its raised nave")
		return
	var beam_rows := _roles(builder.component_log, "column_longitudinal_architrave")
	var lower_rows := _roles(builder.component_log, "basilica_nave_lower_spandrel")
	var support_rows := _roles(builder.component_log, "basilica_nave_end_crosshead") \
		+ _roles(builder.component_log, "basilica_nave_end_return")
	var stone := MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE)
	for row in lower_rows + support_rows + _roles(builder.component_log, "basilica_nave_pier_wall") \
			+ _roles(builder.component_log, "basilica_clerestory_sill") \
			+ _roles(builder.component_log, "basilica_clerestory_head") \
			+ _roles(builder.component_log, "basilica_nave_gable_spandrel"):
		if not _component_box_emitted(mesh, row):
			_fail("raised nave bearing component differs from its emitted mesh: %s" % row.get("role", ""))
	if _roles(builder.component_log, "basilica_nave_end_crosshead").size() != 4 \
			or _roles(builder.component_log, "basilica_nave_end_return").size() != 4:
		_fail("raised nave longitudinal bearings are not tied to both end gables and side walls")
	var crossheads := _roles(builder.component_log, "basilica_nave_end_crosshead")
	var gable_rows := _roles(builder.component_log, "basilica_nave_gable_spandrel")
	var return_rows := _roles(builder.component_log, "basilica_nave_end_return")
	if gable_rows.size() != 2:
		_fail("raised nave does not have two emitted gable bearing spandrels")
	for row in crossheads:
		var bounds := MassBuilder.component_aabb(row)
		var nearest: Dictionary = {}
		var best := INF
		for column in spec.columns:
			var p: Vector3 = column["pos"]
			var distance: float = Vector2(p.x - bounds.get_center().x, p.z - bounds.get_center().z).length()
			if distance < best:
				best = distance
				nearest = column
		if nearest.is_empty() or absf(bounds.position.y - TempleGeometry.column_cap_top(nearest)) > 0.02:
			_fail("end crosshead does not sit on a final generated column capital")
		var side_wall_center: float = signf(bounds.get_center().x) \
			* (spec.width * 0.5 - spec.wall_t * 0.5)
		if side_wall_center < bounds.position.x or side_wall_center > bounds.end.x:
			_fail("end crosshead misses the actual outer side-wall bearing")
	for row in return_rows:
		var bounds := MassBuilder.component_aabb(row)
		var touches_gable := false
		for gable in gable_rows:
			if bounds.intersects(MassBuilder.component_aabb(gable)):
				touches_gable = true
				break
		if not touches_gable:
			_fail("nave end return is detached from both measured gable supports")
	var primary_columns := 0
	for column in spec.columns:
		var p: Vector3 = column["pos"]
		if absf(absf(p.x) - primary_x) > 0.01:
			continue
		primary_columns += 1
		var cap_top: float = TempleGeometry.column_cap_top(column)
		if not MeshProbe.has_upward_support(stone, Vector2(p.x, p.z), 0.22, 0.02):
			_fail("generated nave column at %s has no emitted foot support" % p)
		var support_beam: Dictionary = {}
		for beam in beam_rows:
			var bounds := MassBuilder.component_aabb(beam)
			if p.x >= bounds.position.x - 0.01 and p.x <= bounds.end.x + 0.01 \
					and p.z >= bounds.position.z - 0.01 and p.z <= bounds.end.z + 0.01 \
					and absf(bounds.position.y - cap_top) < 0.02:
				support_beam = beam
				break
		if support_beam.is_empty():
			_fail("generated nave column at %s has no architrave directly on its capital" % p)
			continue
		if not _component_box_emitted(mesh, support_beam):
			_fail("generated nave architrave at %s differs from its measured component box" % p)
		var beam_bounds := MassBuilder.component_aabb(support_beam)
		var lower_wall: Dictionary = {}
		for wall in lower_rows:
			var bounds := MassBuilder.component_aabb(wall)
			if p.x >= bounds.position.x - 0.01 and p.x <= bounds.end.x + 0.01 \
					and p.z >= bounds.position.z - 0.01 and p.z <= bounds.end.z + 0.01 \
					and absf(bounds.position.y - beam_bounds.end.y) < 0.02:
				lower_wall = wall
				break
		if lower_wall.is_empty():
			_fail("nave spandrel is not seated on the generated column architrave")
	if primary_columns < 4:
		_fail("fewer than two authored nave bearings per side were measured")
	var roof := MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_ROOF)
	var wall_t: float = TempleGeometry.basilica_nave_wall_thickness(spec)
	var bearing_x: float = TempleGeometry.basilica_nave_bearing_x(spec)
	var z: float = (TempleGeometry.site_rect(spec).position.y \
		+ TempleGeometry.site_rect(spec).end.y) * 0.5
	var sills := _roles(builder.component_log, "basilica_clerestory_sill")
	if sills.is_empty():
		_fail("raised nave has no actual clerestory sill to protect from the aisle roof")
	else:
		var sill_box: AABB = MassBuilder.component_aabb(sills[0])
		var aisle_probe_x: float = signf(sill_box.get_center().x) \
			* (bearing_x + wall_t * 0.5 + 0.08)
		var aisle_roof_top: float = _vertical_hit_y(roof, aisle_probe_x,
			sill_box.get_center().z,
			TempleGeometry.basilica_nave_eave_height(spec) + 0.2,
			spec.height - 0.5)
		if aisle_roof_top < 0.0 or aisle_roof_top >= sill_box.position.y - 0.03:
			_fail("measured aisle-roof top %.3f covers or reaches actual clerestory sill bottom %.3f" % [
				aisle_roof_top, sill_box.position.y])
		if absf(sill_box.position.y - TempleGeometry.basilica_clerestory_opening_bottom(spec)) > 0.02:
			_fail("emitted clerestory sill differs from the shared generated-bearing datum")
	for row in lower_rows:
		if MassBuilder.component_aabb(row).size.y <= 0.01:
			_fail("nave lower spandrel has non-positive height")
	for side in [-1.0, 1.0]:
		var x: float = side * (bearing_x + wall_t * 0.5)
		var roof_hit: float = _vertical_hit_y(roof, x, z,
			TempleGeometry.basilica_nave_eave_height(spec) + 0.4,
			TempleGeometry.basilica_nave_eave_height(spec) - 0.4)
		if roof_hit < 0.0 or absf(roof_hit - TempleGeometry.basilica_nave_eave_height(spec)) > 0.18:
			_fail("raised nave roof does not meet the clerestory wall at its bearing line")


func _check_clerestory_ray(spec: TempleSpec, builder: TempleBuilder, mesh: ArrayMesh) -> void:
	var sills := _roles(builder.component_log, "basilica_clerestory_sill")
	var heads := _roles(builder.component_log, "basilica_clerestory_head")
	if sills.is_empty() or heads.is_empty():
		_fail("clerestory has no measured sill and head around its opening")
		return
	var sill := MassBuilder.component_aabb(sills[0])
	var matching_head: AABB
	var found_head := false
	for row in heads:
		var bounds := MassBuilder.component_aabb(row)
		if absf(bounds.position.x - sill.position.x) < 0.01 \
				and sill.position.z <= bounds.end.z and sill.end.z >= bounds.position.z:
			matching_head = bounds
			found_head = true
			break
	if not found_head:
		_fail("clerestory sill has no masonry head above the same opening")
		return
	var opening_y: float = (sill.end.y + matching_head.position.y) * 0.5
	var opening_z: float = sill.get_center().z
	var wall_x: float = sill.get_center().x
	var from := Vector3(wall_x - spec.column_r * 1.5 - 0.1, opening_y, opening_z)
	var to := Vector3(wall_x + spec.column_r * 1.5 + 0.1, opening_y, opening_z)
	if MeshProbe.ray_blocked(MeshProbe.all_triangles(null, mesh, mesh.get_surface_count()), from, to):
		_fail("human-height sight ray is blocked across the actual clerestory opening")
		return
	var blocked := MeshProbe.add_box(mesh, TempleBuilder.SURF_STONE,
		AABB(Vector3(wall_x - spec.column_r, opening_y - 0.06, opening_z - 0.06),
			Vector3(spec.column_r * 2.0, 0.12, 0.12)))
	var blocked_mesh: ArrayMesh = blocked.get("mesh")
	if blocked_mesh == null or not MeshProbe.ray_blocked(
		MeshProbe.all_triangles(null, blocked_mesh, blocked_mesh.get_surface_count()), from, to):
		_fail("filled-clerestory negative did not detect an actual masonry obstruction")


func _check_no_columns_fallback(source: TempleSpec) -> void:
	active_case = "basilica generated-column absence uses shell-supported single-nave fallback"
	# This is the final check for the small specimen, so remove its generated
	# records in place. The builder then tests the real no-bearing condition.
	var spec: TempleSpec = source
	spec.columns.clear()
	var fallback_portico_floor: Rect2 = TempleGeometry.basilica_portico_floor_rect(spec)
	if fallback_portico_floor.size.x > 0.01 or fallback_portico_floor.size.y > 0.01:
		_fail("no-bearing fallback reserves portico paving with no emitted portico")
	if not TempleGeometry.basilica_portico_column_positions(spec).is_empty():
		_fail("no-bearing fallback reports portico columns without a nave bearing system")
	var builder := TempleBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	_check_no_degenerate_triangles(mesh)
	for role in ["basilica_nave_lower_spandrel", "basilica_nave_pier_wall",
			"basilica_nave_end_crosshead"]:
		if not _roles(builder.component_log, role).is_empty():
			_fail("unsupported nave bearing %s was emitted with no final column records" % role)
	var roof := MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_ROOF)
	var top := -INF
	for triangle in roof:
		for p in triangle:
			top = maxf(top, p.y)
	var expected_roof_top: float = TempleGeometry.roof_height(spec) \
		+ (spec.spire_height if spec.spire else 0.0)
	if absf(top - expected_roof_top) > 0.02:
		_fail("single-nave fallback roof top %.3f differs from shared geometry %.3f" % [
			top, expected_roof_top])
	var wall: Rect2 = TempleGeometry.site_rect(spec)
	var stone := MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE)
	var fallback_bearings: Array[Dictionary] = _roles(builder.component_log,
		"basilica_shell_roof_bearing")
	if fallback_bearings.size() != 2:
		_fail("no-bearing fallback does not emit two named shell roof bearings")
	var expected_wall_top: float = TempleGeometry.basilica_fallback_roof_wall_center_y(spec)
	var roof_contact_points: Array[Vector2] = []
	for side in [-1.0, 1.0]:
		var point: Vector2
		if wall.size.x <= wall.size.y:
			point = Vector2(side * (wall.size.x * 0.5 - spec.wall_t * 0.5), wall.get_center().y)
		else:
			point = Vector2(wall.get_center().x,
				side * (wall.size.y * 0.5 - spec.wall_t * 0.5))
		roof_contact_points.append(point)
		if not MeshProbe.has_upward_support(stone, point, spec.height, 0.03):
			_fail("single-nave fallback has no emitted side-wall bearing")
		var hit: float = _lowest_vertical_hit(roof, point.x, point.y,
			expected_wall_top + 0.3, expected_wall_top - 0.12)
		var stone_top: float = _vertical_hit_y(stone, point.x, point.y,
			expected_wall_top + 0.12, spec.height - 0.12)
		if hit < 0.0 or absf(hit - expected_wall_top) > 0.04 \
				or stone_top < 0.0 or absf(stone_top - expected_wall_top) > 0.04:
			_fail("single-nave fallback eave does not meet its actual side-wall top")
	for row in fallback_bearings:
		if String(row.get("form", "")) != "slab" or String(row.get("host", "")).is_empty():
			_fail("fallback roof bearing is not an emitted, hosted stone slab")
	# Punch the measured roof contact point. The real roof triangle must vanish;
	# a permissive or unrelated nearby ray cannot satisfy this negative control.
	var negative: Dictionary = MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_ROOF,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			for point in roof_contact_points:
				if Geometry3D.segment_intersects_triangle(
					Vector3(point.x, expected_wall_top + 0.2, point.y),
					Vector3(point.x, expected_wall_top - 0.08, point.y), a, b, c) != null:
					return true
			return false)
	var damaged_roof: ArrayMesh = negative.get("mesh")
	if int(negative.get("removed_triangles", 0)) < 1 or damaged_roof == null:
		_fail("fallback roof-gap control did not remove a real bearing-contact triangle")
	else:
		var damaged_triangles := MeshProbe.surface_triangles(null, damaged_roof, TempleBuilder.SURF_ROOF)
		for point in roof_contact_points:
			if _lowest_vertical_hit(damaged_triangles, point.x, point.y,
				expected_wall_top + 0.2, expected_wall_top - 0.08) >= 0.0:
				_fail("fallback roof-gap control retained its actual contact triangle")
	_check_short_wide_roof_span(spec)


func _check_short_wide_roof_span(source: TempleSpec) -> void:
	active_case = "short-wide basilica fallback uses the actual transverse roof span"
	var spec := TempleSpec.new(source.seed + 1)
	spec.form = &"basilica"
	spec.cult = source.cult
	spec.width = maxf(source.width, source.length) + 8.0
	spec.length = minf(source.width, source.length)
	spec.height = source.height
	TempleGenerator.generate(spec, source.seed + 1)
	spec.columns.clear()
	var builder := TempleBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	var roof := MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_ROOF)
	var actual_top := -INF
	for triangle in roof:
		for point in triangle:
			actual_top = maxf(actual_top, point.y)
	var expected_roof_top: float = TempleGeometry.roof_height(spec) \
		+ (spec.spire_height if spec.spire else 0.0)
	if absf(actual_top - expected_roof_top) > 0.02:
		_fail("short-wide fallback ridge top %.3f differs from shared roof plus spire %.3f" % [
			actual_top, expected_roof_top])
	var transverse: float = minf(spec.width, spec.length)
	var longitudinal_x: bool = spec.width > spec.length
	var side_point: Vector2 = Vector2(transverse * 0.25, 0.0) if not longitudinal_x \
		else Vector2(0.0, transverse * 0.25)
	var side_hit: float = _vertical_hit_y(roof, side_point.x, side_point.y,
		spec.height + transverse * TempleGeometry.RIDGE_PITCH + 0.1,
		spec.height - 0.1)
	if side_hit < 0.0:
		_fail("short-wide fallback has no roof sheet at its true transverse section")


func _roles(rows: Array[Dictionary], role: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in rows:
		if String(row.get("role", "")) == role:
			out.append(row)
	return out


func _component_box_emitted(mesh: ArrayMesh, row: Dictionary) -> bool:
	if String(row.get("form", "")) != "box":
		return false
	var surface: int = int(row.get("surface", -1))
	if surface < 0 or surface >= mesh.get_surface_count():
		return false
	var kit := MeshKit.new(1)
	kit.oriented_box(Vector3(row["size"]), row["xf"], 0)
	var expected: PackedVector3Array = _surface_vertex_soup(kit.commit(), 0)
	var actual: PackedVector3Array = _surface_vertex_soup(mesh, surface)
	return ComponentCheck.missing_triangles(actual, expected) == 0


func _surface_vertex_soup(mesh: ArrayMesh, surface: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for triangle in MeshProbe.surface_triangles(null, mesh, surface):
		for point in triangle:
			out.append(point)
	return out


func _vertical_hit_y(triangles: Array, x: float, z: float, low: float, high: float) -> float:
	return _first_hit_y(triangles, x, z, high, low)


func _lowest_vertical_hit(triangles: Array, x: float, z: float, low: float, high: float) -> float:
	var ys: Array[float] = []
	for triangle in triangles:
		var hit: Variant = Geometry3D.segment_intersects_triangle(Vector3(x, high, z),
			Vector3(x, low, z), triangle[0], triangle[1], triangle[2])
		if hit != null:
			ys.append((hit as Vector3).y)
	if ys.is_empty():
		return -1.0
	ys.sort()
	return ys[0]


func _first_hit_y(triangles: Array, x: float, z: float, high: float, low: float) -> float:
	var best := -INF
	for triangle in triangles:
		var hit: Variant = Geometry3D.segment_intersects_triangle(Vector3(x, high, z),
			Vector3(x, low, z), triangle[0], triangle[1], triangle[2])
		if hit != null:
			best = maxf(best, (hit as Vector3).y)
	return best


func _has_horizontal_face(triangles: Array, x: float, z: float, y: float) -> bool:
	for triangle in triangles:
		var a: Vector3 = triangle[0]
		var b: Vector3 = triangle[1]
		var c: Vector3 = triangle[2]
		var normal := (c - a).cross(b - a).normalized()
		if normal.dot(Vector3.UP) < 0.95:
			continue
		if absf(a.y - y) < 0.01 and absf(b.y - y) < 0.01 and absf(c.y - y) < 0.01 \
				and Rect2(Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z))),
				Vector2(maxf(a.x, maxf(b.x, c.x)) - minf(a.x, minf(b.x, c.x)),
				maxf(a.z, maxf(b.z, c.z)) - minf(a.z, minf(b.z, c.z)))).has_point(Vector2(x, z)):
			return true
	return false


func column_points(spec: TempleSpec) -> Array[Vector2]:
	return TempleGeometry.basilica_portico_column_positions(spec)
