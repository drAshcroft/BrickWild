extends SceneTree
## Source-only proposal fixture. Root runs this after promoting the staged files.

var failures: Array[String] = []
var active_case := "unlabelled"

func _initialize() -> void:
	_check_authored_column_record_controls()
	var cases := 0
	var open_pit_witnesses := 0
	for size_index in range(TempleSweep.COUNT):
		for cult in TempleSweep.cults():
			var spec: TempleSpec = TempleSweep.spec_at(&"rotunda", cult, size_index)
			var builder := TempleBuilder.new()
			var mesh: ArrayMesh = builder.build(spec)
			active_case = "size%d/%s seed=%d" % [size_index,
				String(cult), TempleSweep.seed_at(&"rotunda", cult, size_index)]
			_check_form_and_bounds(spec, builder, mesh)
			_check_perimeter_floor_support(spec, mesh)
			_check_actual_gate_and_floor(spec, mesh)
			_check_gate_head_and_width(spec, builder, mesh)
			_check_drum_dome_contact(spec, builder, mesh)
			if _check_pit_side_support(spec, mesh):
				open_pit_witnesses += 1
			var rite: Dictionary = TempleQA.new().check(spec, builder)
			for issue in rite["failures"]:
				_fail("TempleQA: %s" % String(issue))
			if cult == &"serpent":
				_check_wall_panel_removal_negative(spec, mesh)
				_check_expanded_panel_overlap_negative(spec, builder, mesh)
				_check_perimeter_floor_removal_negative(spec, mesh)
				_check_gate_head_removal_negative(spec, mesh)
				_check_rotunda_wall_dais_overlap_negative(spec)
				_check_pit_fill_negative(spec, mesh)
				_check_gate_fill_negative(spec, mesh)
				_check_floor_removal_negative(spec, mesh)
				_check_threshold_removal_negative(spec, mesh)
				_check_wall_crown_removal_negative(spec, mesh)
				_check_dome_bearing_removal_negative(spec, mesh)
				_check_oculus_fill_negative(spec, mesh)
				_check_arcade_pier_removal_negative(spec, builder, mesh)
				_check_runtime_rotunda_bearing_removals(spec, builder, mesh)
			cases += 1
	if cases != TempleSweep.COUNT * TempleSweep.cults().size():
		_fail("canonical cult/size matrix did not cover the complete Rotunda set")
	if open_pit_witnesses == 0:
		_fail("canonical cases contain no pit-side floor support witness beside the bridge")
	for failure in failures:
		push_error(failure)
	print("rotunda open-arcade architecture fixture: %d canonical cases, %d failures" % [cases, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _check_authored_column_record_controls() -> void:
	var basilica := TempleSpec.new()
	basilica.form = &"basilica"
	basilica.column_r = 0.2
	var first := {"pos": Vector3(-4.0, 0.0, 1.0), "radius": 0.41,
		"height": 3.25, "ring": 7, "fixture_tag": "preserve_left"}
	var second := {"pos": Vector3(4.0, 0.0, 1.0), "radius": 0.73,
		"height": 5.75, "ring": 12, "fixture_tag": "preserve_right"}
	basilica.columns.append(first)
	basilica.columns.append(second)
	var basilica_records: Array[Dictionary] = TempleGeometry.column_records(basilica)
	if basilica_records.size() != 2 \
			or float(basilica_records[0].get("radius", 0.0)) != 0.41 \
			or float(basilica_records[1].get("radius", 0.0)) != 0.73 \
			or float(basilica_records[0].get("height", 0.0)) != 3.25 \
			or int(basilica_records[1].get("ring", -1)) != 12 \
			or String(basilica_records[0].get("fixture_tag", "")) != "preserve_left":
		_fail("authored non-Rotunda column dimensions, ring, or metadata were rewritten")

	var rotunda: TempleSpec = TempleSweep.spec_at(&"rotunda", &"void", 0)
	rotunda.column_r = 0.2
	var lane_left := {"pos": Vector3(-2.0, 0.0, -5.0), "radius": 0.6,
		"height": 4.5, "ring": 31, "fixture_tag": "must_clear_lane"}
	var lane_right := {"pos": Vector3(2.0, 0.0, -5.0), "radius": 0.6,
		"height": 4.5, "ring": 31, "fixture_tag": "must_clear_lane"}
	var lane_foot := Rect2(Vector2(2.0 - 0.6, -5.0 - 0.6), Vector2.ONE * 1.2)
	if not TempleGeometry.processional_lane(rotunda).intersects(lane_foot):
		_fail("authored-radius control does not actually intersect the processional lane")
	rotunda.columns.clear()
	rotunda.columns.append(lane_left)
	rotunda.columns.append(lane_right)
	if not TempleGeometry.column_records(rotunda).is_empty():
		_fail("Rotunda lane filter ignored authored large column radii")
	var safe_left := {"pos": Vector3(-4.0, 0.0, -1.0), "radius": 0.65,
		"height": 5.25, "ring": 47, "fixture_tag": "preserve_rotunda"}
	var safe_right := {"pos": Vector3(4.0, 0.0, -1.0), "radius": 0.65,
		"height": 5.25, "ring": 47, "fixture_tag": "preserve_rotunda"}
	rotunda.columns.clear()
	rotunda.columns.append(safe_left)
	rotunda.columns.append(safe_right)
	var rotunda_records: Array[Dictionary] = TempleGeometry.column_records(rotunda)
	if rotunda_records.size() != 2 \
			or float(rotunda_records[0].get("radius", 0.0)) != 0.65 \
			or float(rotunda_records[0].get("height", 0.0)) != 5.25 \
			or int(rotunda_records[0].get("ring", -1)) != 47 \
			or String(rotunda_records[1].get("fixture_tag", "")) != "preserve_rotunda":
		_fail("surviving Rotunda column record lost its authored bearing or metadata")


func _check_perimeter_floor_support(spec: TempleSpec, mesh: ArrayMesh) -> void:
	var radius: float = TempleGeometry.rotunda_inner_radius(spec) - 0.12
	var stone: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE)
	# This angle lands on the shared row boundary. It must still count as actual
	# support because both neighboring emitted triangles include that closed edge.
	var seam_point := Vector2(radius, 0.0)
	if not MeshProbe.has_upward_support(stone, seam_point, 0.001, 0.03):
		_fail("emitted circular floor has no closed-edge support at the zero-axis row seam")
		return
	var outside_wall := Vector2(TempleGeometry.rotunda_inner_radius(spec) + 0.02, 0.0)
	if MeshProbe.has_upward_support(stone, outside_wall, 0.001, 0.03):
		_fail("closed-edge support probe accepts a point beyond the circular floor")
		return
	for sample in range(72):
		var angle: float = TAU * float(sample) / 72.0
		var point := Vector2(cos(angle), sin(angle)) * radius
		if not MeshProbe.has_upward_support(stone, point, 0.001, 0.03):
			_fail("emitted circular floor has no human-side support at perimeter angle %.3f" % angle)
			return


func _check_perimeter_floor_removal_negative(spec: TempleSpec, mesh: ArrayMesh) -> void:
	var point := Vector2(TempleGeometry.rotunda_inner_radius(spec) - 0.12, 0.0)
	var removed := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_STONE,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			return MeshProbe.upward_triangle_contains_point([a, b, c], point, 0.001, 0.03))
	var without_wedge: ArrayMesh = removed.get("mesh")
	var remaining: Array = MeshProbe.surface_triangles(null,
		without_wedge, TempleBuilder.SURF_STONE)
	if int(removed.get("removed_triangles", 0)) == 0 or without_wedge == null \
			or MeshProbe.has_upward_support(remaining, point, 0.001, 0.03):
		_fail("removed-perimeter-floor negative did not remove closed-edge human-side support")


func _pit_side_witness(spec: TempleSpec) -> Vector2:
	var pit: Rect2 = TempleGeometry.pit_rect(spec)
	var bridge: Rect2 = TempleGeometry.bridge_rect(spec)
	if pit.size.x <= 0.0 or bridge.size.x <= 0.0:
		return Vector2(INF, INF)
	var point := Vector2(bridge.end.x + 0.1, pit.get_center().y)
	var inner: float = TempleGeometry.rotunda_inner_radius(spec)
	if point.x >= pit.end.x - 0.05 or point.length() >= inner - 0.05:
		return Vector2(INF, INF)
	return point


func _check_pit_side_support(spec: TempleSpec, mesh: ArrayMesh) -> bool:
	var point: Vector2 = _pit_side_witness(spec)
	if not is_finite(point.x) or not is_finite(point.y):
		return false
	var stone: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE)
	var ray_from := Vector3(point.x, 0.6, point.y)
	var ray_to := Vector3(point.x, -0.02, point.y)
	if MeshProbe.has_upward_support(stone, point, 0.001, 0.03) \
			or MeshProbe.ray_blocked(stone, ray_from, ray_to):
		_fail("actual pit-side downward ray beside the bridge hits emitted floor")
	return true


func _check_pit_fill_negative(spec: TempleSpec, mesh: ArrayMesh) -> void:
	var point: Vector2 = _pit_side_witness(spec)
	if not is_finite(point.x) or not is_finite(point.y):
		return
	var pit: Rect2 = TempleGeometry.pit_rect(spec)
	var filled := MeshProbe.add_box(mesh, TempleBuilder.SURF_STONE,
		AABB(Vector3(pit.position.x, -0.019, pit.position.y),
			Vector3(pit.size.x, 0.02, pit.size.y)))
	var filled_mesh: ArrayMesh = filled.get("mesh")
	var stone: Array = MeshProbe.surface_triangles(null, filled_mesh,
		TempleBuilder.SURF_STONE)
	if int(filled.get("added_triangles", 0)) != 12 or filled_mesh == null \
			or not MeshProbe.ray_blocked(stone,
				Vector3(point.x, 0.6, point.y), Vector3(point.x, -0.02, point.y)):
		_fail("full-pit-fill negative did not block the same actual downward ray")


func _fail(message: String) -> void:
	failures.append("%s: %s" % [active_case, message])


func _check_form_and_bounds(spec: TempleSpec, builder: TempleBuilder, mesh: ArrayMesh) -> void:
	if mesh == null or mesh.get_surface_count() != 4:
		_fail("native circular form does not retain the four Temple material surfaces")
		return
	var component_parity: Dictionary = ComponentCheck.check(builder, mesh)
	if not bool(component_parity.get("ok", false)):
		_fail("hosted Rotunda geometry does not match its committed triangles: %s" %
			str(component_parity.get("failures", [])))
	var outer: float = TempleGeometry.rotunda_outer_radius(spec)
	var inner: float = TempleGeometry.rotunda_inner_radius(spec)
	var site: Rect2 = TempleGeometry.site_rect(spec)
	var extent: Rect2 = TempleGeometry.plan_extent(spec)
	var forecourt: Rect2 = TempleGeometry.forecourt_rect(spec)
	if not TempleGeometry.sanctum_fits(spec):
		_fail("Rotunda dais has no honest fit for the complete altar and three-sided service approach")
	if absf(extent.position.x + outer + 0.45) > 0.02 \
			or absf(extent.position.y - forecourt.position.y) > 0.02:
		_fail("published bounds do not reserve the circular roof and real gate apron")
	if inner <= 0.0 or outer > minf(site.size.x, site.size.y) * 0.5 + 0.001:
		_fail("circular drum escapes the native request footprint")
	var panels: Array[Dictionary] = builder.components("rotunda_drum_panel")
	if TempleGeometry.rotunda_wall_panel_count(spec) % 2 != 0:
		_fail("circular wall panel count cannot pair across the gate axis")
	var expected_min: int = TempleGeometry.rotunda_wall_panel_count(spec) - 8
	if panels.size() < expected_min:
		_fail("circular wall is missing tangent bearing panels (%d < %d)" % [panels.size(), expected_min])
	for panel in panels:
		var size: Vector3 = panel.get("size", Vector3.ZERO)
		var xform: Transform3D = panel.get("xf", Transform3D.IDENTITY)
		var center: Vector3 = xform.origin
		if String(panel.get("host", "")).is_empty() \
				or absf(Vector2(center.x, center.z).length() \
					- (outer - spec.wall_t * 0.5)) > 0.03 \
				or absf(size.y - spec.height) > 0.01 \
				or absf(size.z - spec.wall_t) > 0.01:
			_fail("drum panel lacks a hosted radial bearing at the shared wall datum")
			break
	for column in spec.columns:
		var c: Vector3 = column["pos"]
		var radius: float = float(column["radius"])
		if Vector2(c.x, c.z).length() + radius * 1.2 > inner - 1.0:
			_fail("generated circular column plinth enters the drum or its floor edge")
			break
	var lane: Rect2 = TempleGeometry.processional_lane(spec)
	for column_record in TempleGeometry.column_records(spec):
		var column_pos: Vector3 = column_record["pos"]
		var column_radius: float = float(column_record["radius"])
		var column_foot := Rect2(Vector2(column_pos.x - column_radius,
			column_pos.z - column_radius), Vector2.ONE * column_radius * 2.0)
		if lane.intersects(column_foot):
			_fail("authored Rotunda ring column still intersects the actual gate-to-altar axis")
			break
	var injected_lane_column: Array[Vector3] = TempleGeometry.column_positions(spec)
	injected_lane_column.append(Vector3.ZERO)
	for filtered_column in TempleGeometry._clear_of_voids(spec, injected_lane_column):
		if filtered_column.length_squared() < 0.0001:
			_fail("actual lane-intersection negative kept an injected column at the axis")
			break
	var emitted_columns := 0
	for mass in builder.mass_log:
		if String(mass.get("name", "")).begins_with("column_"):
			emitted_columns += 1
	if emitted_columns != TempleGeometry.column_records(spec).size():
		_fail("emitted Rotunda column count differs from the validated shared ring plan")
	var stone_surface: Array = MeshProbe.surface_triangles(null, mesh,
		TempleBuilder.SURF_STONE)
	if spec.obelisks:
		var apron: Rect2 = TempleGeometry.forecourt_rect(spec)
		var half_obelisk: float = TempleGeometry.obelisk_height(spec) * 0.07
		for side in [-1.0, 1.0]:
			var obelisk: Vector2 = TempleGeometry.obelisk_center(spec, side)
			var footprint := Rect2(obelisk - Vector2.ONE * half_obelisk,
				Vector2.ONE * (half_obelisk * 2.0))
			if not apron.encloses(footprint) or not MeshProbe.has_upward_support(
					stone_surface, obelisk, 0.001, 0.03):
				_fail("enabled Rotunda outwork has no emitted paved apron beneath its full base")
	var wall_lights := 0
	for prop in builder.prop_log:
		var key: String = String(prop["key"])
		var p: Vector3 = prop["pos"]
		if key == "Cauldron":
			var flame_footprint: Vector2 = PropCatalog.footprint("Cauldron") \
				* TempleBuilder.BRAZIER_SCALE
			var flame_support_points: Array[Vector2] = [Vector2(p.x, p.z),
				Vector2(p.x - flame_footprint.x * 0.5, p.z - flame_footprint.y * 0.5),
				Vector2(p.x + flame_footprint.x * 0.5, p.z - flame_footprint.y * 0.5),
				Vector2(p.x - flame_footprint.x * 0.5, p.z + flame_footprint.y * 0.5),
				Vector2(p.x + flame_footprint.x * 0.5, p.z + flame_footprint.y * 0.5)]
			var flame_supported := true
			for support_point in flame_support_points:
				if not MeshProbe.has_upward_support(stone_surface, support_point,
						0.001, 0.03):
					flame_supported = false
					break
			if not flame_supported:
				_fail("a measured brazier has no emitted circular-floor support")
		if key in ["Torch_Metal", "Banner_1"]:
			wall_lights += 1 if key == "Torch_Metal" else 0
			var radial: Vector2 = Vector2(p.x, p.z)
			if absf(radial.length() - (inner - 0.12)) > 0.03:
				_fail("wall dressing is not seated on the actual circular inner face")
			var angle: float = atan2(radial.x, radial.y)
			if angle < 0.0:
				angle += TAU
			var gate_half: float = asin(clampf(TempleGeometry.GATE_W * 0.5 / inner,
				0.0, 0.98)) + 0.28
			var back_delta: float = minf(angle, TAU - angle)
			var idol_half: float = asin(clampf(spec.idol_width * 0.5 / inner,
				0.0, 0.95)) + 0.24
			if absf(angle - PI) < gate_half or back_delta < idol_half:
				_fail("wall dressing occludes the real gate or rear god position")
	if wall_lights == 0:
		_fail("circular drum received no wall lights on its real inner face")
	var approach: Rect2 = TempleGeometry.rotunda_approach_rect(spec)
	var threshold: Rect2 = TempleGeometry.rotunda_threshold_rect(spec)
	var door_z: float = -outer
	if approach.size.x < TempleGeometry.PROCESSION_MIN \
			or absf(approach.position.y - extent.position.y) > 0.02 \
			or absf(approach.end.y - door_z) > 0.02 \
			or forecourt.end.y < door_z + 0.25 \
			or absf(threshold.size.x - TempleGeometry.GATE_W) > 0.02 \
			or threshold.position.x < -TempleGeometry.GATE_W * 0.5 - 0.01 \
			or threshold.end.x > TempleGeometry.GATE_W * 0.5 + 0.01:
		_fail("approach floor and actual circular wall gate are not joined in public bounds")
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if not extent.grow(0.02).has_point(Vector2(vertex.x, vertex.z)):
				_fail("emitted vertex %s escapes public bounds" % str(vertex))
				return
	var floors: Array[Rect2] = TempleGeometry.floor_rects(spec)
	if floors.size() < 12:
		_fail("walkable circular interior was reduced to too few measured floor bands")
	for floor in floors:
		if floor == forecourt or floor == TempleGeometry.bridge_rect(spec) \
				or floor == TempleGeometry.rotunda_threshold_rect(spec):
			continue
		for corner in Poly.from_rect(floor):
			if corner.length() > inner + 0.03:
				_fail("planned Rotunda interior floor escapes its circular wall at %s" % str(corner))
				return
	for role_rect in [TempleGeometry.dais_footprint(spec),
			TempleGeometry.altar_approach(spec), TempleGeometry.idol_rect(spec)]:
		for corner in Poly.from_rect(role_rect):
			if corner.length() > inner + 0.03:
				_fail("ritual focus or complete dais escapes the circular interior at %s" % str(corner))
				return
	var pit: Rect2 = TempleGeometry.pit_rect(spec)
	var dais_foot: Rect2 = TempleGeometry.dais_footprint(spec)
	if pit.size.x > 0.0 and dais_foot.position.y < pit.end.y + 0.10:
		_fail("complete stepped dais begins before the actual pit has ended")


func _check_actual_gate_and_floor(spec: TempleSpec, mesh: ArrayMesh) -> void:
	var outer: float = TempleGeometry.rotunda_outer_radius(spec)
	var inner: float = TempleGeometry.rotunda_inner_radius(spec)
	var stone: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE)
	var portal_from := Vector3(0.0, 1.6, -outer - 0.25)
	var portal_to := Vector3(0.0, 1.6, -inner + 0.35)
	if MeshProbe.ray_blocked(stone, portal_from, portal_to):
		_fail("actual human-height ray cannot pass through the circular wall gate")
	for side in [-TempleGeometry.PERSON_RADIUS, TempleGeometry.PERSON_RADIUS]:
		if MeshProbe.ray_blocked(stone,
				Vector3(side, 1.6, -outer - 0.25),
				Vector3(side, 1.6, -inner + 0.35)):
			_fail("actual opened gate does not retain body-width passage at x=%.2f" % side)
	var side_ray_from := Vector3(TempleGeometry.GATE_W * 0.5 + 1.0,
		1.6, -outer - 0.25)
	var side_ray_to := Vector3(side_ray_from.x, 1.6, -inner + 0.35)
	if not MeshProbe.ray_blocked(stone, side_ray_from, side_ray_to):
		_fail("circular gate opening is too wide to form actual jamb-bearing side walls")
	var gate_edge: float = TempleGeometry.GATE_W * 0.5
	var jamb: float = spec.wall_t * 0.35
	for side in [-1.0, 1.0]:
		var near_clear_edge := Vector3(side * (gate_edge - 0.02), 1.6,
			-outer - 0.25)
		if MeshProbe.ray_blocked(stone, near_clear_edge,
				Vector3(near_clear_edge.x, 1.6, -inner + 0.35)):
			_fail("actual gate edge at x=%.2f is obstructed inside the clear opening" % near_clear_edge.x)
		var near_wall_edge := Vector3(side * (gate_edge + 0.02), 1.6,
			-outer - 0.25)
		if not MeshProbe.ray_blocked(stone, near_wall_edge,
				Vector3(near_wall_edge.x, 1.6, -inner + 0.35)):
			_fail("actual gate edge at x=%.2f has no emitted jamb wall outside the opening" % near_wall_edge.x)
		var just_inside := Vector3(side * (gate_edge - 0.05), 1.6, -outer - 0.25)
		var just_inside_to := Vector3(just_inside.x, 1.6, -inner + 0.35)
		if MeshProbe.ray_blocked(stone, just_inside, just_inside_to):
			_fail("actual clear gate width is obstructed just inside its %.2fm jamb" % gate_edge)
		var just_outside := Vector3(side * (gate_edge + jamb + 0.05), 1.6, -outer - 0.25)
		var just_outside_to := Vector3(just_outside.x, 1.6, -inner + 0.35)
		if not MeshProbe.ray_blocked(stone, just_outside, just_outside_to):
			_fail("stone return does not bound the clear gate width outside its jamb")
	var entry: Vector2 = TempleGeometry.entry_point(spec)
	var forecourt: Rect2 = TempleGeometry.forecourt_rect(spec)
	var start_z: float = forecourt.position.y + 0.05
	var route_steps: int = int(ceil((entry.y - start_z) / 0.15))
	for step in range(route_steps + 1):
		var z: float = lerpf(start_z, entry.y, float(step) / float(route_steps))
		for x in [-TempleGeometry.PERSON_RADIUS, 0.0, TempleGeometry.PERSON_RADIUS]:
			if not MeshProbe.has_upward_support(stone, Vector2(x, z), 0.001, 0.03):
				_fail("body-width route has no actual floor support at (%.2f, %.2f)" % [x, z])
				return
	_check_emitted_ground_route(spec, mesh)
	var door: Vector3 = Vector3(0.0, TempleGeometry.GATE_H * 0.5, -outer)
	var approach: Rect2 = TempleGeometry.rotunda_approach_rect(spec)
	var extent: Rect2 = TempleGeometry.plan_extent(spec)
	if absf(door.z - approach.end.y) > 0.02 \
			or absf(approach.position.y - extent.position.y) > 0.02:
		_fail("door datum, paved approach and public footprint front disagree")


func _check_gate_head_and_width(spec: TempleSpec, builder: TempleBuilder,
		mesh: ArrayMesh) -> void:
	var outer: float = TempleGeometry.rotunda_outer_radius(spec)
	var inner: float = TempleGeometry.rotunda_inner_radius(spec)
	var gate_height: float = minf(TempleGeometry.GATE_H, spec.height - 0.6)
	var head_rows: Array[Dictionary] = builder.components("rotunda_gate_head")
	var jamb: float = spec.wall_t * 0.35
	if head_rows.size() != 1:
		_fail("gate has no single named bearing head above the actual opening")
	else:
		var row: Dictionary = head_rows[0]
		var size: Vector3 = row.get("size", Vector3.ZERO)
		var xf: Transform3D = row.get("xf", Transform3D.IDENTITY)
		if absf(size.x - (TempleGeometry.GATE_W + jamb * 2.0)) > 0.02 \
				or absf(size.y - (TempleGeometry.rotunda_lower_drum_height(spec) - gate_height)) > 0.02 \
				or absf(xf.origin.y - (TempleGeometry.rotunda_lower_drum_height(spec) + gate_height) * 0.5) > 0.02 \
				or String(row.get("host", "")).is_empty():
			_fail("gate head is not dimensioned to the real jamb width and drum crown")
	var stone: Array = MeshProbe.surface_triangles(null, mesh,
		TempleBuilder.SURF_STONE)
	var head_from := Vector3(0.0, gate_height + 0.1, -outer - 0.25)
	var head_to := Vector3(0.0, gate_height + 0.1, -inner + 0.35)
	if not MeshProbe.ray_blocked(stone, head_from, head_to):
		_fail("actual mesh has no continuous wall head above GATE_H across the portal")


func _check_gate_head_removal_negative(spec: TempleSpec, mesh: ArrayMesh) -> void:
	var outer: float = TempleGeometry.rotunda_outer_radius(spec)
	var inner: float = TempleGeometry.rotunda_inner_radius(spec)
	var gate_height: float = minf(TempleGeometry.GATE_H, spec.height - 0.6)
	var head_from := Vector3(0.0, gate_height + 0.1, -outer - 0.25)
	var head_to := Vector3(0.0, gate_height + 0.1, -inner + 0.35)
	var without_head := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_STONE,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			return Geometry3D.segment_intersects_triangle(head_from, head_to, a, b, c) != null)
	var head_removed_mesh: ArrayMesh = without_head.get("mesh")
	if int(without_head.get("removed_triangles", 0)) == 0 or head_removed_mesh == null \
			or MeshProbe.ray_blocked(MeshProbe.surface_triangles(null,
				head_removed_mesh, TempleBuilder.SURF_STONE), head_from, head_to):
		_fail("removed-head negative does not clear the exact emitted upper-gate ray")


func _check_drum_dome_contact(spec: TempleSpec, builder: TempleBuilder, mesh: ArrayMesh) -> void:
	var outer: float = TempleGeometry.rotunda_outer_radius(spec)
	var mid_radius: float = outer - spec.wall_t * 0.5
	var angle := 0.42
	var lower: float = TempleGeometry.rotunda_lower_drum_height(spec)
	var contact := Vector2(cos(angle) * mid_radius, sin(angle) * mid_radius)
	var stone: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE)
	var roof: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_ROOF)
	var wall_from := Vector3(cos(angle) * (TempleGeometry.rotunda_inner_radius(spec) - 0.08), lower * 0.5,
		sin(angle) * (TempleGeometry.rotunda_inner_radius(spec) - 0.08))
	var wall_to := Vector3(cos(angle) * (outer + 0.08), lower * 0.5,
		sin(angle) * (outer + 0.08))
	if not MeshProbe.ray_blocked(stone, wall_from, wall_to):
		_fail("lower drum has no emitted wall at its continuity witness")
	var roof_y: float = spec.height + RoofShape.DEPTH * 0.5
	if not MeshProbe.has_upward_support(roof, contact, roof_y, 0.04):
		_fail("annular crown has no emitted roof above the outer arcade bearing")
	var center_from := Vector3(0.0, spec.height + 0.4, 0.0)
	var center_to := Vector3(0.0, spec.height - 0.1, 0.0)
	if MeshProbe.ray_blocked(roof, center_from, center_to):
		_fail("Rotunda oculus is physically closed by roof triangles")
	var roof_radius: float = (TempleGeometry.ring_radius(spec) + outer) * 0.5
	var annulus_from := Vector3(roof_radius * cos(angle), spec.height + 0.4,
		roof_radius * sin(angle))
	var annulus_to := Vector3(roof_radius * cos(angle), spec.height - 0.4,
		roof_radius * sin(angle))
	if not MeshProbe.ray_blocked(roof, annulus_from, annulus_to):
		_fail("annular roof witness has no actual emitted stone")
	var arcade_rows: Array[Dictionary] = builder.components("rotunda_arcade_pier")
	if arcade_rows.size() < 6:
		_fail("open upper arcade has too few hosted emitted piers")
	for row in arcade_rows:
		var size: Vector3 = row["size"]
		var xf: Transform3D = row["xf"]
		if absf(xf.origin.y + size.y * 0.5 - (spec.height - RoofShape.DEPTH * 0.5)) > 0.03:
			_fail("upper arcade pier does not reach the annular roof soffit")
			break
	if not builder.components("rotunda_lantern_drum").is_empty():
		_fail("Rotunda emitted a lantern over the open oculus")


func _check_gate_fill_negative(spec: TempleSpec, mesh: ArrayMesh) -> void:
	var outer: float = TempleGeometry.rotunda_outer_radius(spec)
	var sealed := MeshProbe.add_box(mesh, TempleBuilder.SURF_STONE,
		AABB(Vector3(-0.25, 0.8, -outer - 0.15), Vector3(0.5, 1.5, 0.9)))
	var blocked_mesh: ArrayMesh = sealed.get("mesh")
	var stone: Array = MeshProbe.surface_triangles(null,
		blocked_mesh, TempleBuilder.SURF_STONE)
	if blocked_mesh == null or not MeshProbe.ray_blocked(stone,
			Vector3(0.0, 1.6, -outer - 0.25),
			Vector3(0.0, 1.6, -TempleGeometry.rotunda_inner_radius(spec) + 0.35)):
		_fail("filled-gate negative did not detect actual masonry across the entrance")


func _check_wall_panel_removal_negative(spec: TempleSpec, mesh: ArrayMesh) -> void:
	var count: int = TempleGeometry.rotunda_wall_panel_count(spec)
	var step: float = TAU / float(count)
	var angle: float = -PI + (float(count / 2) + 0.5) * step
	var radial := Vector3(cos(angle), 0.0, sin(angle))
	var outer: float = TempleGeometry.rotunda_outer_radius(spec)
	var inner: float = TempleGeometry.rotunda_inner_radius(spec)
	var from := radial * (inner - 0.08) + Vector3.UP * (spec.height * 0.5)
	var to := radial * (outer + 0.08) + Vector3.UP * (spec.height * 0.5)
	var removed := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_STONE,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			return Geometry3D.segment_intersects_triangle(from, to, a, b, c) != null)
	var broken: Array = MeshProbe.surface_triangles(null,
		removed.get("mesh"), TempleBuilder.SURF_STONE)
	var failures: Array[String] = TempleQA._rotunda_wall_continuity_triangles(spec,
		broken)
	if int(removed.get("removed_triangles", 0)) == 0 or removed.get("mesh") == null \
			or failures.is_empty():
		_fail("removed-panel negative did not break the actual rotational wall continuity check")


func _check_expanded_panel_overlap_negative(spec: TempleSpec,
		builder: TempleBuilder, baseline_mesh: ArrayMesh) -> void:
	var panels: Array[Dictionary] = builder.components("rotunda_drum_panel")
	if panels.size() < 2:
		_fail("expanded-panel overlap negative has no actual adjacent panel pair")
		return
	var baseline_match: Dictionary = ComponentCheck.check(builder, baseline_mesh)
	if not bool(baseline_match["ok"]):
		_fail("baseline Rotunda component geometry does not match its committed mesh: %s" %
			str(baseline_match["failures"]))
		return
	var first: Dictionary = panels[0]
	var neighbour: Dictionary = panels[1]
	var expanded_size: Vector3 = first["size"]
	expanded_size.x += 1.0
	# Emit both boxes into a detached real builder. The mutant is now triangles
	# in a committed mesh, not a changed dictionary pretending to be geometry.
	var broken := TempleBuilder.new()
	broken.begin(4)
	broken.host("expanded_negative")
	var expanded: Dictionary = broken.component_box("rotunda_drum_panel",
		expanded_size, first["xf"], TempleBuilder.SURF_STONE)
	broken.component_box("rotunda_drum_panel", neighbour["size"],
		neighbour["xf"], TempleBuilder.SURF_STONE)
	var broken_mesh: ArrayMesh = broken.commit()
	var mutant_match: Dictionary = ComponentCheck.check(broken, broken_mesh)
	if not bool(mutant_match["ok"]):
		_fail("expanded-panel negative is not present in its committed mesh: %s" %
			str(mutant_match["failures"]))
		return
	var emitted: Array = MeshProbe.surface_triangles(null, broken_mesh,
		TempleBuilder.SURF_STONE)
	if emitted.is_empty():
		_fail("expanded-panel negative emitted no measurable stone triangles")
		return
	var penetration: float = TempleQA._rotunda_box_overlap_depth(expanded, neighbour)
	var permitted: float = TempleQA._rotunda_wall_pair_allowance(spec,
		expanded, neighbour)
	if penetration <= permitted + MassRules.TOL:
		_fail("expanded emitted panel OBB negative does not exceed its derived physical seam lap")


func _check_floor_removal_negative(spec: TempleSpec, mesh: ArrayMesh) -> void:
	var entry: Vector2 = TempleGeometry.entry_point(spec)
	var removed := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_STONE,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			return MeshProbe.upward_triangle_contains_point([a, b, c], entry,
				0.001, 0.03))
	var without_floor: ArrayMesh = removed.get("mesh")
	if int(removed.get("removed_triangles", 0)) == 0 or without_floor == null \
			or MeshProbe.has_upward_support(MeshProbe.surface_triangles(null,
				without_floor, TempleBuilder.SURF_STONE), entry, 0.001, 0.03):
		_fail("removed-floor negative did not remove the actual entry support")


func _check_rotunda_wall_dais_overlap_negative(spec: TempleSpec) -> void:
	var broken := TempleBuilder.new()
	broken.begin(4)
	var size := Vector3(1.2, 1.0, 1.2)
	var xf := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	broken.host("rotunda_drum_panel_00")
	broken.component_box("rotunda_drum_panel", size, xf, TempleBuilder.SURF_STONE)
	broken.host_end()
	broken.host("rotunda_dais_mutant")
	broken.component_box("rotunda_dais_step", size, xf, TempleBuilder.SURF_STONE)
	broken.host_end()
	var broken_mesh: ArrayMesh = broken.commit()
	var parity: Dictionary = ComponentCheck.check(broken, broken_mesh)
	if not bool(parity.get("ok", false)) or broken_mesh == null:
		_fail("wall/dais overlap negative does not use its actual emitted boxes")
		return
	broken.mass_log.append({"name": "wall_rotunda_00", "aabb": AABB(Vector3.ZERO, size)})
	broken.mass_log.append({"name": "dais", "aabb": AABB(Vector3.ZERO, size)})
	var allow := func(a: String, b: String) -> float:
		return TempleQA._allowance(a, b)
	var report: Dictionary = TempleQA._rotunda_non_wall_pair_overlaps(
		broken.mass_log, allow, broken)
	var detected := false
	for issue in report["failures"]:
		if String(issue).begins_with("no_overlap:") and String(issue).contains("emitted"):
			detected = true
	if not detected:
		_fail("actual expanded wall/dais triangles escaped the exact oriented-overlap predicate")


func _check_threshold_removal_negative(spec: TempleSpec, mesh: ArrayMesh) -> void:
	var threshold: Rect2 = TempleGeometry.rotunda_threshold_rect(spec)
	var removed := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_STONE,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			var face := (c - a).cross(b - a)
			var centroid := (a + b + c) / 3.0
			return face.length_squared() > 1e-12 \
				and face.normalized().dot(Vector3.UP) > 0.95 \
				and absf(centroid.y - 0.001) < 0.01 \
				and threshold.has_point(Vector2(centroid.x, centroid.z)))
	var without_threshold: ArrayMesh = removed.get("mesh")
	var grid: WalkGrid = _emitted_ground_grid(spec, without_threshold)
	var target: Vector2 = TempleGeometry.pit_rect(spec).get_center()
	var target_rect := Rect2(target - Vector2.ONE * 0.1, Vector2.ONE * 0.2)
	var flooded: bool = grid.flood_from(Vector2(0.0,
		TempleGeometry.forecourt_rect(spec).position.y + 0.2), 0.3)
	if int(removed.get("removed_triangles", 0)) == 0 or without_threshold == null \
			or not flooded or grid.reached(target_rect):
		_fail("removed-threshold negative did not break the actual apron-to-bridge mesh route")


func _check_emitted_ground_route(spec: TempleSpec, mesh: ArrayMesh) -> void:
	var pit: Rect2 = TempleGeometry.pit_rect(spec)
	if pit.size.x <= 0.0:
		_fail("canonical Rotunda lost its central rite bridge target")
		return
	var grid: WalkGrid = _emitted_ground_grid(spec, mesh)
	var start := Vector2(0.0, TempleGeometry.forecourt_rect(spec).position.y + 0.2)
	var target: Vector2 = pit.get_center()
	var target_rect := Rect2(target - Vector2.ONE * 0.1, Vector2.ONE * 0.2)
	if not grid.flood_from(start, 0.3) or not grid.reached(target_rect):
		_fail("actual emitted ground mesh flood does not reach the central bridge crossing")


func _emitted_ground_grid(spec: TempleSpec, mesh: ArrayMesh) -> WalkGrid:
	var grid := WalkGrid.new()
	grid.setup(TempleGeometry.plan_extent(spec).grow(0.2), 0.12)
	if mesh == null:
		return grid
	var ground_y: float = 0.001
	for triangle in MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE):
		var a: Vector3 = triangle[0]
		var b: Vector3 = triangle[1]
		var c: Vector3 = triangle[2]
		var face := (c - a).cross(b - a)
		if face.length_squared() <= 1e-12 or face.normalized().dot(Vector3.UP) < 0.95:
			continue
		if absf(a.y - ground_y) > 0.01 or absf(b.y - ground_y) > 0.01 \
				or absf(c.y - ground_y) > 0.01:
			continue
		grid.add_floor_poly(PackedVector2Array([
			Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)]))
	for obstacle in TempleGeometry.obstacle_rects(spec):
		grid.add_obstacle(obstacle)
	grid.build(TempleGeometry.PERSON_RADIUS)
	return grid


func _check_wall_crown_removal_negative(spec: TempleSpec, mesh: ArrayMesh) -> void:
	var outer: float = TempleGeometry.rotunda_outer_radius(spec)
	var mid_radius: float = outer - spec.wall_t * 0.5
	var angle := 0.42
	var point := Vector2(cos(angle) * mid_radius, sin(angle) * mid_radius)
	var lower: float = TempleGeometry.rotunda_lower_drum_height(spec)
	var from := Vector3(point.x, lower + 0.08, point.y)
	var to := Vector3(point.x, lower - 0.08, point.y)
	var removed := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_STONE,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			var face := (c - a).cross(b - a)
			return face.length_squared() > 1e-12 and face.normalized().dot(Vector3.UP) > 0.95 \
				and absf(((a + b + c) / 3.0).y - lower) < 0.01 \
				and Geometry3D.segment_intersects_triangle(from, to, a, b, c) != null)
	var without_crown: ArrayMesh = removed.get("mesh")
	if int(removed.get("removed_triangles", 0)) == 0 or without_crown == null \
			or MeshProbe.has_upward_support(MeshProbe.surface_triangles(null,
				without_crown, TempleBuilder.SURF_STONE), point, lower, 0.04):
		_fail("removed-wall-crown negative still reports a real bearing support")


func _check_oculus_fill_negative(spec: TempleSpec, mesh: ArrayMesh) -> void:
	var from := Vector3(0.0, spec.height + 0.4, 0.0)
	var to := Vector3(0.0, spec.height - 0.1, 0.0)
	var filled := MeshProbe.add_box(mesh, TempleBuilder.SURF_STONE,
		AABB(Vector3(-0.5, spec.height - 0.15, -0.5), Vector3(1.0, 0.3, 1.0)))
	var fill_triangles: Array = MeshProbe.surface_triangles(null,
		filled.get("mesh"), TempleBuilder.SURF_STONE)
	if int(filled.get("added_triangles", 0)) != 12 \
			or not MeshProbe.ray_blocked(fill_triangles, from, to):
		_fail("filled-oculus negative did not block the real vertical daylight ray")


func _check_arcade_pier_removal_negative(spec: TempleSpec, builder: TempleBuilder,
		mesh: ArrayMesh) -> void:
	var rows: Array[Dictionary] = builder.components("rotunda_arcade_pier")
	if rows.is_empty():
		_fail("arcade-pier negative has no actual emitted support member")
		return
	var row: Dictionary = rows[0]
	var size: Vector3 = row["size"]
	var xf: Transform3D = row["xf"]
	var inverse: Transform3D = xf.affine_inverse()
	var half_size: Vector3 = size * 0.5
	var removed := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_STONE,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			var local: Vector3 = inverse * ((a + b + c) / 3.0)
			return absf(local.x) <= half_size.x + 0.01 \
				and absf(local.y) <= half_size.y + 0.01 \
				and absf(local.z) <= half_size.z + 0.01)
	var remaining: Array = MeshProbe.surface_triangles(null,
		removed.get("mesh"), TempleBuilder.SURF_STONE)
	var from: Vector3 = xf * Vector3(0.0, 0.0, -size.z * 0.75)
	var to: Vector3 = xf * Vector3(0.0, 0.0, size.z * 0.75)
	var original: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE)
	if int(removed.get("removed_triangles", 0)) == 0 \
			or not MeshProbe.ray_blocked(original, from, to) \
			or MeshProbe.ray_blocked(remaining, from, to):
		_fail("removed-arcade-pier negative retained the emitted horizontal pier crossing")


func _check_dome_bearing_removal_negative(spec: TempleSpec, mesh: ArrayMesh) -> void:
	var outer: float = TempleGeometry.rotunda_outer_radius(spec)
	var inner: float = TempleGeometry.ring_radius(spec) - spec.column_r * 0.8
	var radius: float = (inner + outer) * 0.5
	var from := Vector3(radius, spec.height + 0.4, 0.0)
	var to := Vector3(radius, spec.height - 0.4, 0.0)
	var removed := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_ROOF,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			return Geometry3D.segment_intersects_triangle(from, to, a, b, c) != null)
	var remaining: Array = MeshProbe.surface_triangles(null,
		removed.get("mesh"), TempleBuilder.SURF_ROOF)
	var original: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_ROOF)
	if int(removed.get("removed_triangles", 0)) == 0 or removed.get("mesh") == null \
			or not MeshProbe.ray_blocked(original, from, to) \
			or MeshProbe.ray_blocked(remaining, from, to):
		_fail("annular roof removal negative did not remove the measured roof crossing")


func _check_runtime_rotunda_bearing_removals(spec: TempleSpec,
		builder: TempleBuilder, mesh: ArrayMesh) -> void:
	var head_rows: Array[Dictionary] = builder.components("rotunda_gate_head")
	var return_rows: Array[Dictionary] = builder.components("rotunda_gate_return")
	var stone: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE)
	var roof: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_ROOF)
	if not TempleQA._rotunda_bearing_failures_for_components(spec, head_rows,
			return_rows, stone, roof).is_empty():
		_fail("runtime Rotunda bearing predicate rejects the intact emitted gate/lantern supports")
		return
	if return_rows.size() != 2:
		_fail("gate-bearing removal control has no two emitted return components")
		return
	var left: Dictionary = return_rows[0]
	var left_size: Vector3 = left["size"]
	var left_xf: Transform3D = left["xf"]
	var left_bounds := AABB(left_xf.origin - left_size * 0.5, left_size)
	var removed_return := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_STONE,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			return left_bounds.has_point((a + b + c) / 3.0))
	var without_return: Array = MeshProbe.surface_triangles(null,
		removed_return.get("mesh"), TempleBuilder.SURF_STONE)
	var missing_jamb := TempleQA._rotunda_bearing_failures_for_components(spec,
		head_rows, return_rows, without_return, roof)
	var return_bearing_rejected := false
	for issue in missing_jamb:
		if String(issue).contains("actual upward jamb bearing"):
			return_bearing_rejected = true
	if int(removed_return.get("removed_triangles", 0)) == 0 or not return_bearing_rejected:
		_fail("removed-return negative escaped the runtime gate-head bearing predicate")


func _has_gap_for(report: Dictionary, mass_name: String) -> bool:
	for issue in report.get("failures", []):
		if String(issue).begins_with("no_gaps: %s " % mass_name):
			return true
	return false
