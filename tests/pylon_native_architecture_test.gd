extends SceneTree
## Source-only proposal fixture. Root runs this after promoting the staged Pylon files.

var failures: Array[String] = []
var active_case := "unlabelled"
const PINNED_SEEDS := [1, 8102, 21325]
const SIZE_NAMES := ["small", "default", "large"]
const FROZEN_PYLON_SIZES := [
	{"w": 18.0, "l": 24.0, "h": 8.0},
	{"w": 26.0, "l": 44.0, "h": 12.0},
	{"w": 48.0, "l": 80.0, "h": 20.0},
]

func _initialize() -> void:
	var cases := 0
	if TempleSweep.cults().size() != 5:
		_fail("the frozen sacred matrix no longer contains five temple cults")
	for seed in PINNED_SEEDS:
		for size_index in range(FROZEN_PYLON_SIZES.size()):
			for cult in TempleSweep.cults():
				var dimensions: Dictionary = FROZEN_PYLON_SIZES[size_index]
				var spec := TempleSpec.new()
				spec.form = &"pylon"
				spec.cult = cult
				spec.width = float(dimensions["w"])
				spec.length = float(dimensions["l"])
				spec.height = float(dimensions["h"])
				TempleGenerator.generate(spec, seed)
				active_case = "temple/pylon/%s/%d %s" % [SIZE_NAMES[size_index], seed, String(cult)]
				var builder := TempleBuilder.new()
				var mesh: ArrayMesh = builder.build(spec)
				_check_pylon_column_lights(spec, builder)
				_check_open_court_and_hall_roof(spec, builder, mesh)
				_check_outer_gate_aperture(spec, mesh)
				_check_shrine_sequence(spec, builder, mesh)
				_check_dais_return_clearance(spec, builder, mesh)
				_check_floor_and_rite_route(spec, builder, mesh)
				_check_published_bounds(spec, mesh)
				cases += 1
	_check_pylon_column_light_negative()
	if cases != 45:
		_fail("Pylon fixture ran %d cases instead of all 45 frozen cult/size/seed requests" % cases)
	for failure in failures:
		push_error(failure)
	print("pylon native architecture fixture: %d frozen cases, %d failures" % [cases, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _fail(message: String) -> void:
	failures.append("%s: %s" % [active_case, message])


func _check_published_bounds(spec: TempleSpec, mesh: ArrayMesh) -> void:
	var extent: Rect2 = TempleGeometry.plan_extent(spec)
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if not extent.grow(0.02).has_point(Vector2(vertex.x, vertex.z)):
				_fail("emitted Pylon vertex escapes the published roof/outwork/apron extent: %s" % str(vertex))
				return


func _check_pylon_column_lights(spec: TempleSpec, builder: TempleBuilder) -> void:
	var records: Array[Dictionary] = TempleGeometry.column_records(spec)
	var stone: Array = MeshProbe.surface_triangles(builder, null, TempleBuilder.SURF_STONE)
	for index in range(records.size()):
		var column: Dictionary = records[index]
		if int(column.get("ring", -1)) != 0:
			continue
		var c: Vector3 = column["pos"]
		var side: float = signf(c.x)
		var radius: float = float(column["radius"])
		var torch_y := 2.4
		var shaft_height: float = float(column["height"])
		var taper: float = clampf((torch_y - 0.22) / maxf(shaft_height - 0.22, 0.01),
			0.0, 1.0)
		var shaft_radius: float = lerpf(radius, radius * 0.86, taper)
		var expected := Vector3(c.x - side * shaft_radius, torch_y, c.z)
		var host: AABB = builder.mass_aabb("column_%d" % index)
		if host.size.y <= 0.0 or not host.has_point(expected) \
				or expected.y + PropCatalog.floor_offset("Torch_Metal") < 2.0:
			_fail("Pylon inner-column torch lacks emitted host support or safe head clearance")
			continue
		var from := Vector3(expected.x - side * 0.1, expected.y, expected.z)
		var to := Vector3(expected.x + side * 0.02, expected.y, expected.z)
		if not MeshProbe.ray_blocked(stone, from, to):
			_fail("Pylon inner-column torch contact misses the actual tapered stone shaft")
			continue
		var found := false
		for prop in builder.prop_log:
			if prop.get("key") != "Torch_Metal" or prop.get("kind") != &"light":
				continue
			var pos: Vector3 = prop["pos"]
			var expected_yaw: float = -PI / 2.0 if side > 0.0 else PI / 2.0
			if pos.distance_to(expected) <= 0.02 \
					and absf(float(prop.get("yaw", 0.0)) - expected_yaw) <= 0.001:
				found = true
				break
		if not found:
			_fail("Pylon inner-column bearing is missing its paired hosted fire light")


func _check_pylon_column_light_negative() -> void:
	for cult in [&"blood", &"void"]:
		active_case = "temple/pylon/%s/31049 column-light negative" % cult
		var spec := TempleSpec.new()
		spec.form = &"pylon"
		spec.cult = cult
		spec.width = 16.0
		spec.length = 26.0
		spec.height = 8.0
		TempleGenerator.generate(spec, 31049)
		var builder := TempleBuilder.new()
		builder.build(spec)
		var before: Dictionary = TempleRiteCheck.new().check(spec, builder)
		if not before["ok"] or _has_fire_failure(before):
			_fail("Pylon seed 31049 %s lacks a passing fire baseline before the light-removal negative" % cult)
			continue
		# Seed 31049's original failed axis sample was z=4.7. Remove every
		# actual light within its longitudinal reach so other fire families
		# cannot mask the deliberate local blackout.
		var negative_sample_z := 4.7
		var kept: Array[Dictionary] = []
		var removed_lights := 0
		for prop in builder.prop_log:
			var removes_sample_light := false
			if prop.get("kind") == &"light":
				var pos: Vector3 = prop["pos"]
				removes_sample_light = absf(pos.z - negative_sample_z) \
					<= TempleGeometry.LIGHT_REACH
			if removes_sample_light:
				removed_lights += 1
			else:
				kept.append(prop)
		if removed_lights == 0:
			_fail("Pylon seed 31049 light-removal negative found no lights covering its recorded dark sample")
		builder.prop_log = kept
		var after: Dictionary = TempleRiteCheck.new().check(spec, builder)
		if not _has_fire_failure(after) or float(after["stats"].get("darkest_step", 0.0)) \
				<= TempleGeometry.LIGHT_REACH:
			_fail("removing lights covering the seed 31049 axis sample did not restore the fire complaint")


func _has_fire_failure(report: Dictionary) -> bool:
	for failure in report.get("failures", []):
		if String(failure).begins_with("fire:"):
			return true
	return false


func _check_open_court_and_hall_roof(spec: TempleSpec, builder: TempleBuilder,
		mesh: ArrayMesh) -> void:
	var court: Rect2 = TempleGeometry.hall_rect(spec)
	court.position.y = TempleGeometry.interior_rect(spec).position.y
	court.size.y = TempleGeometry.court_depth(spec)
	var interior: Rect2 = TempleGeometry.interior_rect(spec)
	var shrine_need: float = spec.altar_l + TempleGeometry.ALTAR_CLEAR * 2.0 \
		+ TempleGeometry.IDOL_GAP + spec.idol_width + 1.2
	var expected_court: float = minf(maxf(4.0, interior.size.y * 0.4),
		maxf(0.0, interior.size.y - maxf(4.0, shrine_need) - 4.0))
	if absf(court.size.y - expected_court) > 0.02:
		_fail("Pylon forecourt does not preserve the designed open-court depth")
	var roof: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_ROOF)
	var stone: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE)
	var trim: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_TRIM)
	var towers: Array[Rect2] = TempleGeometry.pylon_rects(spec)
	if builder.has_mass("wall_front"):
		_fail("Pylon gate still has overlapping rectangular front-wall piers behind its towers")
	if towers.size() != 2:
		_fail("monumental gate is missing its paired battered pylon towers")
	else:
		var tower_back: float = towers[0].end.y
		for side_wall in ["wall_left", "wall_right"]:
			var side_mass: AABB = builder.mass_aabb(side_wall)
			if side_mass.size.z <= 0.0 or absf(side_mass.position.z - tower_back) > 0.02:
				_fail("Pylon perimeter side wall does not meet the gate tower at its rear face")
		for tower_index in range(towers.size()):
			var tower: Rect2 = towers[tower_index]
			if tower.size.y < 4.0:
				_fail("paired battered Pylon gate towers lack architectural depth")
			var center: Vector2 = tower.get_center()
			var tower_h: float = spec.height * 1.35
			var shell_depth: float = TempleGeometry.pylon_tower_shell_depth(spec)

			var tower_rows: Array[Dictionary] = builder.components_of("pylon_tower_%d" % tower_index)
			var base_rows: Array[Dictionary] = []
			var face_rows: Array[Dictionary] = []
			var cap_rows: Array[Dictionary] = []
			for component in tower_rows:
				if String(component.get("role", "")) == "pylon_tower_base_course":
					base_rows.append(component)
				elif String(component.get("role", "")) == "pylon_battered_face":
					face_rows.append(component)
				elif String(component.get("role", "")) == "pylon_tower_cap_course":
					cap_rows.append(component)
			var wall_probe: Dictionary = _pylon_front_face_probe(face_rows, shell_depth)
			var wall_from: Vector3 = wall_probe.get("from", Vector3.ZERO)
			var wall_to: Vector3 = wall_probe.get("to", Vector3.ZERO)
			if wall_probe.is_empty() or not MeshProbe.ray_blocked(stone, wall_from, wall_to):
				_fail("paired Pylon has no actual horizontal probe through its emitted battered front face")
			elif tower_rows.size() == 6 and face_rows.size() == 4:
				var front_face: Dictionary = wall_probe["face"]
				var without_front_result := MeshProbe.remove_triangles(mesh,
					TempleBuilder.SURF_STONE, _component_triangle_filter([front_face]))
				var front_removed: int = int(without_front_result.get("removed_triangles", 0))
				if front_removed < 8:
					_fail("front-face control did not remove emitted triangles of the matched Pylon profile")
				elif without_front_result.get("mesh") == null:
					_fail("front-face control could not rebuild the mutated mesh")
				else:
					var without_front: Array = MeshProbe.surface_triangles(null,
						without_front_result["mesh"], TempleBuilder.SURF_STONE)
					if MeshProbe.ray_blocked(without_front, wall_from, wall_to):
						_fail("front-face control retained the same short wall-crossing probe")
			if tower_rows.size() != 6 or base_rows.size() != 1 or face_rows.size() != 4 \
					or cap_rows.size() != 1:
				_fail("Pylon tower must emit grounded base, four battered faces, and its cap course")
			else:
				var cap: Dictionary = cap_rows[0]
				var cap_xf: Transform3D = cap["xf"]
				var cap_size: Vector3 = cap["size"]
				var cap_removed := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_TRIM, \
					_component_triangle_filter(cap_rows))
				if int(cap_removed.get("removed_triangles", 0)) < 12 \
						or cap_removed.get("mesh") == null:
					_fail("cap-course negative did not remove its actual emitted component triangles")
				if absf(cap_size.x - tower.size.x) > 0.001 \
						or absf(cap_size.z - tower.size.y) > 0.001 \
						or cap_xf.origin.y + cap_size.y * 0.5 > tower_h + 0.001:
					_fail("Pylon cap course escapes the published tower envelope")
				var base: Dictionary = base_rows[0]
				var xf: Transform3D = base["xf"]
				var base_size: Vector3 = base["size"]
				var base_bottom: float = xf.origin.y - base_size.y * 0.5
				var base_top: float = xf.origin.y + base_size.y * 0.5
				var base_rect := Rect2(Vector2(xf.origin.x - base_size.x * 0.5,
					xf.origin.z - base_size.z * 0.5), Vector2(base_size.x, base_size.z))
				if absf(base_bottom) > 0.001 or absf(base_rect.position.x - tower.position.x) > 0.001 \
						or absf(base_rect.position.y - tower.position.y) > 0.001 \
						or absf(base_rect.size.x - tower.size.x) > 0.001 \
						or absf(base_rect.size.y - tower.size.y) > 0.001:
					_fail("Pylon base course does not ground at y=0 inside its exact published tower footprint")
				var without_base_result := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_STONE,
					_component_triangle_filter(base_rows))
				if int(without_base_result.get("removed_triangles", 0)) < 12 \
						or without_base_result.get("mesh") == null:
					_fail("foundation-removal negative did not remove the actual base-course triangles")
				else:
					var without_base: Array = MeshProbe.surface_triangles(null,
						without_base_result["mesh"], TempleBuilder.SURF_STONE)
					for face in face_rows:
						var profile: PackedVector3Array = face["points"]
						if profile.size() != 4:
							_fail("battered face profile is not a quadrilateral")
							continue
						var base_edge := PackedVector3Array()
						for profile_point in profile:
							if absf(profile_point.y - base_top) <= 0.001:
								base_edge.append(profile_point)
						if base_edge.size() != 2:
							_fail("battered face does not start with an actual edge on the base-course top")
							continue
						var point3: Vector3 = (base_edge[0] + base_edge[1]) * 0.5
						var inset := Vector2(tower.get_center().x - point3.x,
							tower.get_center().y - point3.z).normalized() * 0.025
						var seat := Vector2(point3.x, point3.z) + inset
						if not MeshProbe.has_upward_support(stone, seat, base_top, 0.003):
							_fail("actual base course does not support a battered face at its foot")
						if MeshProbe.has_upward_support(without_base, seat, base_top, 0.003):
							_fail("removing the actual base course retained support at the same battered-face foot")
			var removed_tower := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_STONE,
				_component_triangle_filter(tower_rows))
			if int(removed_tower.get("removed_triangles", 0)) < 60 \
					or removed_tower.get("mesh") == null:
				_fail("Pylon tower-removal negative did not remove its actual six-component shell triangles")
			else:
				var without_tower: Array = MeshProbe.surface_triangles(null,
					removed_tower["mesh"], TempleBuilder.SURF_STONE)
				if MeshProbe.ray_blocked(without_tower, wall_from, wall_to):
					_fail("Pylon tower-removal negative retained the same short wall-crossing probe")
	if spec.obelisks:
		var apron: Rect2 = TempleGeometry.forecourt_rect(spec)
		var half_base: float = TempleGeometry.obelisk_height(spec) * 0.07
		for side in [-1.0, 1.0]:
			var obelisk: Vector2 = TempleGeometry.obelisk_center(spec, side)
			for dx in [-half_base * 0.75, half_base * 0.75]:
				for dz in [-half_base * 0.75, half_base * 0.75]:
					var base_point := obelisk + Vector2(dx, dz)
					if not apron.has_point(base_point) \
							or not MeshProbe.has_upward_support(stone, base_point, 0.001, 0.03):
						_fail("measured Pylon obelisk base lacks full actual forecourt support")
						return
	var court_probe := Vector3(0.0, spec.height - 0.2, court.get_center().y)
	var court_top := Vector3(court_probe.x, spec.height + 0.2, court_probe.z)
	if MeshProbe.ray_blocked(roof, court_probe, court_top):
		_fail("open court is covered by emitted roof triangles")
	var hall: Rect2 = TempleGeometry.hall_rect(spec)
	var roof_rect: Rect2 = TempleGeometry.pylon_roof_rect(spec)
	if absf(roof_rect.position.y - (hall.position.y \
			+ TempleGeometry.pylon_hypostyle_setback(spec) - 0.12)) > 0.02:
		_fail("hypostyle roof does not begin at its set-back bearing row")
	var hall_probe := Vector3(0.0, spec.height - 0.2, hall.get_center().y)
	var hall_top := Vector3(hall_probe.x, spec.height + 0.2, hall_probe.z)
	if not MeshProbe.ray_blocked(roof, hall_probe, hall_top):
		_fail("hypostyle hall has no emitted overhead roof")
	if spec.columns.is_empty():
		_fail("hypostyle hall lost its authored column grid")
	else:
		var first_column_z: float = INF
		for column in spec.columns:
			var column_pos: Vector3 = column["pos"]
			first_column_z = minf(first_column_z, column_pos.z)
		if absf(first_column_z - (hall.position.y \
				+ TempleGeometry.pylon_hypostyle_setback(spec))) > 0.02:
			_fail("first Pylon bearing row is not set back within the hypostyle hall")
		var bearing_from := Vector3(0.0, spec.height - 0.30, first_column_z)
		var bearing_to := Vector3(0.0, spec.height + 0.06, first_column_z)
		if not MeshProbe.ray_blocked(trim, bearing_from, bearing_to):
			_fail("first hypostyle cross-architrave does not meet the flat-roof soffit datum")
		var min_column_x: float = INF
		var max_column_x: float = -INF
		for column in spec.columns:
			var column_pos: Vector3 = column["pos"]
			min_column_x = minf(min_column_x, column_pos.x)
			max_column_x = maxf(max_column_x, column_pos.x)
		var removed_beam := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_TRIM,
			MeshProbe.any_face_in(AABB(Vector3(min_column_x - 0.5, spec.height - 0.3,
				first_column_z - 0.5), Vector3(max_column_x - min_column_x + 1.0,
				0.5, 1.0))))
		if int(removed_beam.get("removed_triangles", 0)) < 2 \
				or removed_beam.get("mesh") == null:
			_fail("missing-bearing negative did not remove actual cross-architrave triangles")
		else:
			var without_beam: Array = MeshProbe.surface_triangles(null,
				removed_beam["mesh"], TempleBuilder.SURF_TRIM)
			if MeshProbe.ray_blocked(without_beam, bearing_from, bearing_to):
				_fail("missing-bearing negative retained an actual first-row roof support")
		var cross_beams := builder_role_count(builder, "column_cross_architrave")
		if cross_beams == 0:
			_fail("hypostyle has no emitted cross-architrave bearing course")
	var roof_negative := MeshProbe.add_box(mesh, TempleBuilder.SURF_ROOF,
		AABB(Vector3(-0.3, spec.height - 0.1, court.get_center().y - 0.3),
			Vector3(0.6, 0.2, 0.6)))
	if int(roof_negative.get("added_triangles", 0)) != 12 or roof_negative.get("mesh") == null:
		_fail("court-cover negative could not add twelve actual roof triangles")
	else:
		var covered: Array = MeshProbe.surface_triangles(null, roof_negative["mesh"],
			TempleBuilder.SURF_ROOF)
		if not MeshProbe.ray_blocked(covered, court_probe, court_top):
			_fail("court-cover negative escaped the sky-exposure probe")


func _pylon_front_face_probe(face_rows: Array[Dictionary], shell_depth: float) -> Dictionary:
	var front: Dictionary = {}
	var front_mean_z: float = INF
	for face in face_rows:
		var points: PackedVector3Array = face.get("points", PackedVector3Array())
		if points.size() != 4:
			continue
		var mean_z: float = 0.0
		for point in points:
			mean_z += point.z
		mean_z /= float(points.size())
		if mean_z < front_mean_z:
			front_mean_z = mean_z
			front = face
	if front.is_empty():
		return {}
	var profile: PackedVector3Array = front.get("points", PackedVector3Array())
	var lower_y: float = (profile[0].y + profile[1].y) * 0.5
	var upper_y: float = (profile[2].y + profile[3].y) * 0.5
	var lower_z: float = (profile[0].z + profile[1].z) * 0.5
	var upper_z: float = (profile[2].z + profile[3].z) * 0.5
	var x: float = (profile[0].x + profile[1].x + profile[2].x + profile[3].x) * 0.25
	var y: float = lerpf(lower_y, upper_y, 0.55)
	var z: float = lerpf(lower_z, upper_z, 0.55)
	var half_span: float = shell_depth * 0.65 + 0.01
	return {
		"from": Vector3(x, y, z - half_span),
		"to": Vector3(x, y, z + half_span),
		"profile": front.get("points", PackedVector3Array()),
		"face": front,
		"surface_z": z,
		"probe_y": y,
	}

func _component_triangle_filter(rows: Array[Dictionary]) -> Callable:
	var expected: Dictionary = {}
	for row in rows:
		var surface_index: int = int(row["surface"])
		var kit := MeshKit.new(4)
		if String(row["form"]) == "slab":
			var points: PackedVector3Array = row["points"]
			var depth: float = float(row["depth"])
			var vertical: bool = bool(row.get("vertical", true))
			var edges: PackedInt32Array = row.get("open_edges", PackedInt32Array())
			kit.slab_poly(points, depth, surface_index, vertical, edges)
		elif String(row["form"]) == "box":
			var size: Vector3 = row["size"]
			var xform: Transform3D = row["xf"]
			kit.oriented_box(size, xform, surface_index)
		else:
			continue
		var isolated_mesh: ArrayMesh = kit.commit()
		# An isolated MeshKit commits its one populated logical surface at mesh
		# index zero when lower slots are empty (for example trim-only caps).
		var isolated: Array = MeshProbe.surface_triangles(null, isolated_mesh, 0)
		for tri in isolated:
			var a: Vector3 = tri[0]
			var b: Vector3 = tri[1]
			var c: Vector3 = tri[2]
			var key: String = ComponentCheck.triangle_key(a, b, c)
			expected[key] = int(expected.get(key, 0)) + 1
	return func(a: Vector3, b: Vector3, c: Vector3) -> bool:
		var key: String = ComponentCheck.triangle_key(a, b, c)
		var count: int = int(expected.get(key, 0))
		if count <= 0:
			return false
		expected[key] = count - 1
		return true

func builder_role_count(builder: TempleBuilder, role: String) -> int:
	var count := 0
	for row in builder.component_log:
		if String(row.get("role", "")) == role:
			count += 1
	return count


func _check_outer_gate_aperture(spec: TempleSpec, mesh: ArrayMesh) -> void:
	var width: float = TempleGeometry.pylon_gate_width(spec)
	var expected: float = clampf(spec.width * 0.19, 3.8, 7.0)
	if absf(width - expected) > 0.001:
		_fail("outer Pylon gate differs from its bounded facade formula")
	var towers: Array[Rect2] = TempleGeometry.pylon_rects(spec)
	if towers.size() != 2 or absf(towers[0].size.x - (spec.width - width) * 0.5) > 0.001 \
			or absf(towers[1].size.x - (spec.width - width) * 0.5) > 0.001:
		_fail("paired Pylon towers do not share the new outer gate width")
	var threshold: Rect2 = TempleGeometry.pylon_threshold_rect(spec)
	if absf(threshold.size.x - width) > 0.001 \
			or absf(threshold.position.x + width * 0.5) > 0.001:
		_fail("Pylon threshold floor does not match the widened opening")
	var stone: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE)
	var site: Rect2 = TempleGeometry.site_rect(spec)
	var clearance: float = maxf(0.35, TempleGeometry.pylon_tower_shell_depth(spec) + 0.1)
	for side in [-1.0, 1.0]:
		var open_x: float = side * (width * 0.5 - clearance)
		var open_from := Vector3(open_x, 1.6, site.position.y - 0.2)
		var open_to := Vector3(open_x, 1.6, site.position.y + spec.wall_t + 0.2)
		if MeshProbe.ray_blocked(stone, open_from, open_to):
			_fail("human-height outer gate ray is blocked near an emitted jamb")
		var solid_x: float = side * (width * 0.5 + clearance)
		var solid_from := Vector3(solid_x, 1.6, site.position.y - 0.2)
		var solid_to := Vector3(solid_x, 1.6, site.position.y + spec.wall_t + 0.2)
		if not MeshProbe.ray_blocked(stone, solid_from, solid_to):
			_fail("outer Pylon opening escaped its pair of actual towers")
	if threshold.size.x > 0.0 and threshold.size.y > 0.05:
		for x in [0.0, -width * 0.5 + 0.2, width * 0.5 - 0.2]:
			if not MeshProbe.has_upward_support(stone, Vector2(x, threshold.get_center().y), 0.001, 0.03):
				_fail("widened Pylon threshold lacks actual floor support at x=%.2f" % x)
		var removed := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_STONE, \
			MeshProbe.top_face_in(threshold, 0.001, 0.03))
		if int(removed.get("removed_triangles", 0)) < 2 or removed.get("mesh") == null:
			_fail("threshold-floor negative did not remove actual widened gate-floor triangles")
		else:
			var without_threshold: Array = MeshProbe.surface_triangles(null, removed["mesh"], TempleBuilder.SURF_STONE)
			for x in [0.0, -width * 0.5 + 0.2, width * 0.5 - 0.2]:
				if MeshProbe.has_upward_support(without_threshold, Vector2(x, threshold.get_center().y), 0.001, 0.03):
					_fail("threshold-floor negative retained support at x=%.2f" % x)
	if spec.obelisks:
		var oh: float = TempleGeometry.obelisk_height(spec)
		if oh >= spec.height * 1.35 * 0.5:
			_fail("Pylon gate obelisks still dominate the paired entrance towers")
		var apron: Rect2 = TempleGeometry.forecourt_rect(spec)
		var base_half: float = oh * 0.07
		for side in [-1.0, 1.0]:
			var c: Vector2 = TempleGeometry.obelisk_center(spec, side)
			for dx in [-base_half * 0.75, base_half * 0.75]:
				for dz in [-base_half * 0.75, base_half * 0.75]:
					var p := c + Vector2(dx, dz)
					if not apron.has_point(p) or not MeshProbe.has_upward_support(stone, p, 0.001, 0.03):
						_fail("reduced Pylon obelisk lacks actual forecourt support")


func _check_shrine_sequence(spec: TempleSpec, builder: TempleBuilder, mesh: ArrayMesh) -> void:
	var hall: Rect2 = TempleGeometry.hall_rect(spec)
	var shrine: Rect2 = TempleGeometry.sanctum_rect(spec)
	if shrine.size.x >= hall.size.x - 0.1 or absf(shrine.get_center().x) > 0.01:
		_fail("inner shrine is not a centered, narrower room inside the hypostyle hall")
	if not shrine.encloses(TempleGeometry.altar_rect(spec)) \
			or not shrine.encloses(TempleGeometry.idol_rect(spec)):
		_fail("cult altar or idol escapes the actual rear shrine room")
	var planned_walls: Array[Rect2] = TempleGeometry.pylon_sanctum_wall_rects(spec)
	var obstacles: Array[Rect2] = TempleGeometry.obstacle_rects(spec)
	if planned_walls.size() != 4 or obstacles.size() < 4:
		_fail("emitted screen has no four-part walk-grid obstacle plan")
	else:
		for index in range(4):
			if obstacles[index] != planned_walls[index]:
				_fail("screen collision footprint differs from the shared emitted geometry source")
	var stone: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE)
	var doorway: float = TempleGeometry.pylon_sanctum_doorway_width(spec)
	var front_z: float = shrine.position.y
	var portal_from := Vector3(0.0, 1.6, front_z - spec.wall_t)
	var portal_to := Vector3(0.0, 1.6, front_z + spec.wall_t)
	if MeshProbe.ray_blocked(stone, portal_from, portal_to):
		_fail("actual human-height axis ray cannot pass the inner shrine portal")
	var side_x: float = doorway * 0.5 + 0.4
	var side_from := Vector3(side_x, 1.6, front_z - 0.02)
	var side_to := Vector3(side_x, 1.6, front_z + spec.wall_t + 0.02)
	if not MeshProbe.ray_blocked(stone, side_from, side_to):
		_fail("actual screen pier does not block the off-axis shrine ray")
	var screen_rows: Array[Dictionary] = []
	for row in builder.component_log:
		if String(row.get("role", "")) in ["pylon_shrine_portal_pier",
				"pylon_shrine_portal_upper_pier", "pylon_shrine_portal_lintel",
				"pylon_shrine_portal_spandrel", "pylon_shrine_return_wall"]:
			if String(row.get("host", "")) != "pylon_inner_shrine":
				_fail("inner shrine masonry is missing its named component host")
			screen_rows.append(row)
	if screen_rows.size() != 8:
		_fail("inner shrine screen requires 2 lower piers, 2 upper piers, a lintel, a transom, and 2 returns")
	var filled_negative := MeshProbe.add_box(mesh, TempleBuilder.SURF_STONE,
		AABB(Vector3(-doorway * 0.5, 0.0, front_z - spec.wall_t * 0.5),
			Vector3(doorway, minf(TempleGeometry.GATE_H, spec.height - 0.6), spec.wall_t)))
	if filled_negative.get("mesh") == null:
		_fail("sealed shrine-portal negative could not create its mesh mutation")
	else:
		var sealed: Array = MeshProbe.surface_triangles(null, filled_negative["mesh"],
			TempleBuilder.SURF_STONE)
		if not MeshProbe.ray_blocked(sealed, portal_from, portal_to):
			_fail("filled shrine-portal negative escaped the axis aperture probe")
	var off_axis_pier: Dictionary = {}
	for row in builder.components("pylon_shrine_portal_pier"):
		var row_xf: Transform3D = row["xf"]
		if row_xf.origin.x > 0.0:
			off_axis_pier = row
			break
	if off_axis_pier.is_empty():
		_fail("off-axis screen pier component is absent")
	else:
		var removed := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_STONE,
			_component_triangle_filter([off_axis_pier]))
		if int(removed.get("removed_triangles", 0)) < 12 or removed.get("mesh") == null:
			_fail("pier-only negative did not remove the actual off-axis pier triangles")
		else:
			var opened: Array = MeshProbe.surface_triangles(null,
				removed["mesh"], TempleBuilder.SURF_STONE)
			if MeshProbe.ray_blocked(opened, side_from, side_to):
				_fail("pier-only triangle removal did not open the same wall-crossing ray")


func _check_dais_return_clearance(spec: TempleSpec, builder: TempleBuilder,
		mesh: ArrayMesh) -> void:
	var shrine: Rect2 = TempleGeometry.sanctum_rect(spec)
	var footprint: Rect2 = TempleGeometry.dais_footprint(spec)
	var walls: Array[Rect2] = TempleGeometry.pylon_sanctum_wall_rects(spec)
	var clear_left: float = shrine.position.x + spec.wall_t
	var clear_right: float = shrine.end.x - spec.wall_t
	if footprint.position.x < clear_left + 0.02 \
			or footprint.end.x > clear_right - 0.02:
		_fail("lowest emitted Pylon dais tread escapes the clear width between shrine returns")
		return
	var return_rows: Array[Dictionary] = builder.components("pylon_shrine_return_wall")
	if walls.size() != 4 or return_rows.size() != 2:
		_fail("Pylon dais clearance requires both actual emitted shrine return walls")
		return
	var overlap_front: float = maxf(footprint.position.y, walls[2].position.y)
	var overlap_back: float = minf(footprint.end.y, walls[2].end.y)
	if overlap_back <= overlap_front + 0.08:
		_fail("lowest Pylon dais tread has no measurable depth alongside the shrine returns")
		return
	var probe_z: float = (overlap_front + overlap_back) * 0.5
	for index in range(2):
		var wall: Rect2 = walls[index + 2]
		var wall_row: Dictionary = return_rows[index]
		var removed := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_STONE,
			_component_triangle_filter([wall_row]))
		if int(removed.get("removed_triangles", 0)) < 12 or removed.get("mesh") == null:
			_fail("return-wall removal did not remove its actual Pylon masonry triangles")
			continue
		var without_wall: Array = MeshProbe.surface_triangles(null,
			removed["mesh"], TempleBuilder.SURF_STONE)
		var from: Vector3
		var to: Vector3
		if index == 0:
			from = Vector3(wall.position.x - 0.1, TempleGeometry.DAIS_RISE * 0.5, probe_z)
			to = Vector3(wall.end.x + 0.02, TempleGeometry.DAIS_RISE * 0.5, probe_z)
		else:
			from = Vector3(wall.end.x + 0.1, TempleGeometry.DAIS_RISE * 0.5, probe_z)
			to = Vector3(wall.position.x - 0.02, TempleGeometry.DAIS_RISE * 0.5, probe_z)
		if MeshProbe.ray_blocked(without_wall, from, to):
			_fail("actual lowest Pylon dais tread penetrates the shrine return wall after wall-face removal")


func _check_floor_and_rite_route(spec: TempleSpec, builder: TempleBuilder, mesh: ArrayMesh) -> void:
	var stone: Array = MeshProbe.surface_triangles(null, mesh, TempleBuilder.SURF_STONE)
	var site: Rect2 = TempleGeometry.site_rect(spec)
	var inside: Rect2 = TempleGeometry.interior_rect(spec)
	var court_end: float = TempleGeometry.hall_rect(spec).position.y
	var apron: Rect2 = TempleGeometry.forecourt_rect(spec)
	if MeshProbe.ray_blocked(stone, Vector3(0.0, 1.6, site.position.y - 0.2),
			Vector3(0.0, 1.6, inside.position.y + 0.2)):
		_fail("actual human-height entrance ray cannot pass the outer pylon gate")
	var z: float = apron.position.y if apron.size.x > 0.0 else site.position.y
	while z <= court_end + 0.001:
		for side in [-1.0, 1.0]:
			var point := Vector2(side * TempleGeometry.PERSON_RADIUS, z)
			if not MeshProbe.has_upward_support(stone, point, 0.001, 0.03):
				_fail("actual body-width court-to-hypostyle floor is discontinuous at %s" % str(point))
				return
		z += 0.15
	var threshold: Rect2 = TempleGeometry.pylon_threshold_rect(spec)
	if threshold.size.y > 0.05:
		var threshold_floor := MeshProbe.remove_triangles(mesh, TempleBuilder.SURF_STONE,
			MeshProbe.top_face_in(threshold, 0.001, 0.03))
		if int(threshold_floor.get("removed_triangles", 0)) < 2 \
				or threshold_floor.get("mesh") == null:
			_fail("removed-threshold negative did not remove the actual gate-floor triangles")
		else:
			var without_threshold: Array = MeshProbe.surface_triangles(null,
				threshold_floor["mesh"], TempleBuilder.SURF_STONE)
			var center := Vector2(0.0, threshold.get_center().y)
			if MeshProbe.has_upward_support(without_threshold, center, 0.001, 0.03):
				_fail("removed-threshold negative still has actual emitted floor support")
	var rite: Dictionary = TempleQA.new().check(spec, builder)
	for issue in rite["failures"]:
		_fail("TempleQA ritual route: %s" % String(issue))
