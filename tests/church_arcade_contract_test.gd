extends SceneTree
## Full-body through-arcade contract on actual assembled church meshes.
const MeshProbe = preload("res://qa/mesh_probe.gd")
const ComponentCheck = preload("res://qa/component_check.gd")
const MeshKit = preload("res://core/mesh_kit.gd")
const LandmarkSuite = preload("res://tests/suites/landmark_suite.gd")

const BODY_HEIGHTS: Array[float] = [0.1, 0.8, 1.7]
const BODY_OFFSETS: Array[float] = [-0.28, 0.0, 0.28]

var failures: Array[String] = []
var active_case: String = "unlabelled"
var one_ring_seen := false
var two_ring_seen := false

func _init() -> void:
	var requests: Array[Dictionary] = [
		{"label": "Romanesque small seed=1", "style": &"romanesque", "width": 8.0, "length": 14.0, "height": 7.0, "seed": 1},
		{"label": "Gothic default seed=8102", "style": &"gothic", "width": 10.0, "length": 22.0, "height": 12.0, "seed": 8102},
		{"label": "Byzantine large seed=21325", "style": &"byzantine", "width": 16.0, "length": 48.0, "height": 24.0, "seed": 21325},
		{"label": "Nordic stave small seed=8102", "style": &"nordic_stave", "width": 8.0, "length": 14.0, "height": 7.0, "seed": 8102},
		{"label": "Renaissance default seed=21325", "style": &"renaissance", "width": 10.0, "length": 22.0, "height": 12.0, "seed": 21325},
		{"label": "Russian large seed=1", "style": &"russian", "width": 16.0, "length": 48.0, "height": 24.0, "seed": 1},
	]
	for request in requests:
		var spec := _make_spec(request)
		_check_case(spec, String(request["label"]))

	# Real deterministic two-ring landmark fixture, using the landmark suite's
	# published size, seed derivation, and feature forcing.
	var landmark: Dictionary = LandmarkSuite.LANDMARKS.filter(func(row):
		return String(row["key"]) == "notre_dame")[0]
	var scale := 0.25
	var nd := ChurchSpec.new()
	nd.style = landmark["style"]
	nd.width = float(landmark["width"]) * scale
	nd.length = float(landmark["length"]) * scale
	nd.height = float(landmark["height"]) * scale
	var nd_seed: int = LandmarkSuite._seed_for("notre_dame", scale)
	ChurchGenerator.generate(nd, nd_seed)
	LandmarkSuite._force_features("notre_dame", nd)
	_check_case(nd, "Notre-Dame landmark scale=0.25 seed=%d" % nd_seed)

	# Compatibility case for the historic one-ring layout, kept explicit even
	# if the six public representatives happen to generate no single-ring case.
	var legacy := ChurchSpec.new()
	legacy.style = &"gothic"
	legacy.width = 10.0
	legacy.length = 22.0
	legacy.height = 12.0
	ChurchGenerator.generate(legacy, 8102)
	legacy.aisles = 1
	legacy.aisle_width = maxf(legacy.aisle_width, 2.2)
	_check_case(legacy, "legacy single-ring Gothic seed=8102 forced_aisles=1")

	if not one_ring_seen:
		_fail("fixture union did not exercise a single aisle ring")
	if not two_ring_seen:
		_fail("fixture union did not exercise nested aisle rings")
	for failure in failures:
		push_error(failure)
	print("church arcade body contract: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)

func _make_spec(request: Dictionary) -> ChurchSpec:
	var spec := ChurchSpec.new()
	spec.style = request["style"]
	spec.width = float(request["width"])
	spec.length = float(request["length"])
	spec.height = float(request["height"])
	ChurchGenerator.generate(spec, int(request["seed"]))
	return spec

func _check_case(spec: ChurchSpec, label: String) -> void:
	active_case = "%s actual_seed=%d aisles=%d" % [label, spec.seed, spec.aisles]
	if spec.aisles <= 0:
		return
	one_ring_seen = one_ring_seen or spec.aisles == 1
	two_ring_seen = two_ring_seen or spec.aisles >= 2
	var builder := ChurchBuilder.new()
	var mesh: ArrayMesh = builder.build(spec)
	var all_triangles: Array = MeshProbe.all_triangles(builder, mesh, mesh.get_surface_count())
	var bays: Array = ChurchGeometry.nave_arcade_openings(spec,
		ChurchGeometry.aisle_height(spec, 0))
	if bays.is_empty():
		_fail("aisle-bearing church has no supported arcade opening")
		return
	var span: Vector2 = ChurchGeometry.aisle_z_range(spec)
	for bay in bays:
		var z: float = float(bay["u"])
		var half_width: float = float(bay["width"]) * 0.5
		if z - half_width < span.x + 0.029 or z + half_width > span.y - 0.029:
			_fail("planned opening leaves actual aisle shell extent")
	_check_bearing_components(builder, mesh, spec, bays)
	for side in [-1.0, 1.0]:
		var nave_face_x: float = side * spec.width * 0.5
		var first: AABB = ChurchGeometry.aisle_aabb(spec, side, 0)
		var first_inner_x: float = first.position.x if side > 0.0 else first.end.x
		for ring_index in range(spec.aisles):
			var ring_body: AABB = ChurchGeometry.aisle_aabb(spec, side, ring_index)
			var target_x: float = ring_body.get_center().x
			for bay in bays:
				_check_complete_route(all_triangles, target_x,
					float(bay["u"]), float(bay["width"]), ring_index)
		for bay in bays:
			var z: float = float(bay["u"])
			var head: float = minf(float(bay["height"]), ChurchGeometry.aisle_height(spec, 0))
			_check_interface_body(all_triangles, mesh, spec, side, nave_face_x,
				first_inner_x, z, float(bay["width"]), head, "nave/ring0")
			_check_wall_crown(mesh, nave_face_x, z, head,
				float(bay["width"]), side, logical_wall_slot(spec), "nave wall")
			_check_wall_crown(mesh, first_inner_x, z, head,
				float(bay["width"]), -side, logical_wall_slot(spec), "ring0 inner wall")
		for ring_index in range(spec.aisles - 1):
			var inner: AABB = ChurchGeometry.aisle_aabb(spec, side, ring_index)
			var outer: AABB = ChurchGeometry.aisle_aabb(spec, side, ring_index + 1)
			var outer_face: float = inner.end.x if side > 0.0 else inner.position.x
			var next_inner: float = outer.position.x if side > 0.0 else outer.end.x
			var common_height: float = minf(ChurchGeometry.aisle_height(spec, ring_index),
				ChurchGeometry.aisle_height(spec, ring_index + 1))
			var common_bays: Array = ChurchGeometry.nave_arcade_openings(spec, common_height)
			if common_bays.size() != bays.size():
				_fail("nested interface differs from shared opening count")
			for bay in common_bays:
				var z: float = float(bay["u"])
				var head: float = minf(float(bay["height"]), common_height)
				var interface_label := "ring%d/ring%d" % [ring_index, ring_index + 1]
				_check_interface_body(all_triangles, mesh, spec, side, outer_face,
					next_inner, z, float(bay["width"]), head, interface_label)
				_check_wall_crown(mesh, outer_face, z, head,
					float(bay["width"]), side, logical_wall_slot(spec), "ring%d outer wall" % ring_index)
				_check_wall_crown(mesh, next_inner, z, head,
					float(bay["width"]), -side, logical_wall_slot(spec), "ring%d inner wall" % (ring_index + 1))
			if common_bays.is_empty():
				continue
			if not _negative_body_control(all_triangles, mesh, spec, side,
				outer_face, next_inner, float(common_bays[0]["u"]),
				float(common_bays[0]["width"]), minf(float(common_bays[0]["height"]), common_height)):
				_fail("removed-wall control did not fail the full nested-body predicate")
		if spec.aisles == 1 and not _negative_body_control(all_triangles, mesh, spec,
			side, nave_face_x, first_inner_x, float(bays[0]["u"]),
			float(bays[0]["width"]), minf(float(bays[0]["height"]), ChurchGeometry.aisle_height(spec, 0))):
			_fail("removed-wall control did not fail the full single-ring body predicate")

func _check_complete_route(triangles: Array,
		target_x: float, z: float, width: float, ring_index: int) -> void:
	var half: float = width * 0.25
	for y in BODY_HEIGHTS:
		for lateral in [-half, 0.0, half]:
			var sample_z: float = z + lateral
			if MeshProbe.ray_blocked(triangles, Vector3(0.0, y, sample_z),
				Vector3(target_x, y, sample_z)):
				_fail("nave-to-ring%d body route blocked (y=%.2f z=%.2f)" % [ring_index, y, sample_z])
			var steps: int = maxi(2, ceili(absf(target_x) / 0.5))
			for step in range(steps + 1):
				var x: float = lerpf(0.0, target_x, float(step) / float(steps))
				if not MeshProbe.has_upward_support(triangles,
					Vector2(x, sample_z), ChurchGeometry.FLOOR_LIFT, 0.02):
					_fail("nave-to-ring%d route floor discontinuity at x=%.2f" % [ring_index, x])

func _check_interface_body(triangles: Array, mesh: ArrayMesh, spec: ChurchSpec,
		side: float, first_x: float, second_x: float, z: float,
		width: float, head: float, label: String) -> void:
	var low_x: float = minf(first_x, second_x)
	var high_x: float = maxf(first_x, second_x)
	if not _body_envelope_clear(triangles, low_x - 0.08, high_x + 0.08,
		z, width, head):
		_fail("%s full body envelope is blocked" % label)
	for offset in BODY_OFFSETS:
		var sample_z: float = z + clampf(offset, -width * 0.25, width * 0.25)
		if not MeshProbe.has_upward_support(triangles, Vector2((low_x + high_x) * 0.5, sample_z), ChurchGeometry.FLOOR_LIFT, 0.02):
			_fail("%s lacks emitted floor under passage (z=%.2f)" % [label, sample_z])
		for wall_x in [first_x, second_x]:
			for delta in [-0.12, 0.12]:
				if not MeshProbe.has_upward_support(triangles,
					Vector2(wall_x + delta, sample_z), ChurchGeometry.FLOOR_LIFT, 0.02):
					_fail("%s floor breaks across wall plane x=%.2f" % [label, wall_x])

func _body_envelope_clear(triangles: Array, low_x: float, high_x: float,
		z: float, width: float, head: float) -> bool:
	for y in BODY_HEIGHTS:
		if y >= head - 0.05:
			continue
		for offset in BODY_OFFSETS:
			var sample_z: float = z + clampf(offset, -width * 0.25, width * 0.25)
			var from := Vector3(low_x, y, sample_z)
			var to := Vector3(high_x, y, sample_z)
			if MeshProbe.ray_blocked(triangles, from, to):
				return false
	return true

func _check_wall_crown(mesh: ArrayMesh, x: float, z: float, head: float,
		width: float, expected_normal: float, logical: int, label: String) -> void:
	var surface: int = _logical_surface(mesh, logical)
	if surface < 0:
		_fail("%s has no physical wall surface" % label)
		return
	var plane: Array = []
	for tri in MeshProbe.surface_triangles(null, mesh, surface):
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		var normal := (c - a).cross(b - a)
		if normal.length_squared() < 1e-12:
			continue
		if absf(a.x - x) < 0.002 and absf(b.x - x) < 0.002 and absf(c.x - x) < 0.002 \
				and normal.normalized().x * expected_normal > 0.95:
			plane.append(tri)
	var z_sample: float = z + minf(width * 0.09, 0.17)
	if plane.is_empty() or not MeshProbe.ray_blocked(plane,
		Vector3(x - expected_normal * 0.06, head + 0.10, z_sample),
		Vector3(x + expected_normal * 0.06, head + 0.10, z_sample)):
		_fail("%s crown is absent on its own wall layer" % label)
func _negative_body_control(triangles: Array, mesh: ArrayMesh, spec: ChurchSpec,
		side: float, first_x: float, second_x: float, z: float,
		width: float, head: float) -> bool:
	var low: float = minf(first_x, second_x) - 0.08
	var high: float = maxf(first_x, second_x) + 0.08
	if not _body_envelope_clear(triangles, low, high, z, width, head):
		return false
	var surface: int = _logical_surface(mesh, logical_wall_slot(spec))
	if surface < 0:
		return false
	var center_x: float = (low + high) * 0.5
	var plug_width: float = maxf(0.6, width * 0.7)
	var plug := AABB(Vector3(center_x - 0.06, -0.05, z - plug_width * 0.5),
		Vector3(0.12, minf(head + 0.25, 2.2), plug_width))
	var mutation: Dictionary = MeshProbe.add_box(mesh, surface, plug)
	if int(mutation.get("added_triangles", 0)) != 12:
		return false
	var mutated: Array = MeshProbe.all_triangles(null,
		mutation["mesh"] as ArrayMesh, (mutation["mesh"] as ArrayMesh).get_surface_count())
	return not _body_envelope_clear(mutated, low, high, z, width, head)

func _check_bearing_components(builder: ChurchBuilder, mesh: ArrayMesh,
		spec: ChurchSpec, bays: Array) -> void:
	var logical: int = ChurchBuilder.SURF_WOOD if spec.style == &"nordic_stave" \
		else ChurchBuilder.SURF_STONE
	var surface: int = _logical_surface(mesh, logical)
	if surface < 0:
		_fail("bearing component material surface is absent")
		return
	var actual: PackedVector3Array = _surface_vertices(mesh, surface)
	var checked := 0
	for bay in bays:
		for z in [float(bay["support_left"]), float(bay["support_right"])]:
			for side in [-1.0, 1.0]:
				var matches: Array[Dictionary] = []
				for row in builder.component_log:
					if row["role"] != "nave_engaged_pier" or int(row["surface"]) != logical:
						continue
					var xf: Transform3D = row["xf"]
					if absf(xf.origin.z - z) < 0.002 \
							and signf(xf.origin.x) == side:
						matches.append(row)
				if matches.size() != 1:
					_fail("support z=%.2f side=%.0f has %d named bearings" % [z, side, matches.size()])
					continue
				var kit := MeshKit.new(1)
				var row: Dictionary = matches[0]
				kit.oriented_box(row["size"], row["xf"], 0)
				var want: PackedVector3Array = kit.commit().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				if ComponentCheck.missing_triangles(actual, want) != 0:
					_fail("bearing component triangles are not present on their emitted surface")
				checked += 1
	if checked == 0:
		_fail("fixture could not prove any surviving named support bearing")
	else:
		var row_to_remove: Dictionary = {}
		for row in builder.component_log:
			if row["role"] == "nave_engaged_pier" and int(row["surface"]) == logical:
				row_to_remove = row
				break
		if row_to_remove.is_empty() or not _removed_bearing_fails(mesh, surface, row_to_remove):
			_fail("removed actual bearing triangles pass the same component-presence predicate")

func _removed_bearing_fails(mesh: ArrayMesh, surface: int, row: Dictionary) -> bool:
	var kit := MeshKit.new(1)
	kit.oriented_box(row["size"], row["xf"], 0)
	var want: PackedVector3Array = kit.commit().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var counts: Dictionary = ComponentCheck.triangle_counts(want)
	var mutation: Dictionary = MeshProbe.remove_triangles(mesh, surface, func(a: Vector3, b: Vector3, c: Vector3) -> bool:
		var key := ComponentCheck.triangle_key(a, b, c)
		if int(counts.get(key, 0)) <= 0:
			return false
		counts[key] = int(counts[key]) - 1
		return true)
	if int(mutation.get("removed_triangles", 0)) != 12:
		return false
	var mutated_mesh: ArrayMesh = mutation["mesh"]
	var mutated: PackedVector3Array = _surface_vertices(mutated_mesh, surface)
	return ComponentCheck.missing_triangles(mutated, want) > 0

func _surface_vertices(mesh: ArrayMesh, surface: int) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	for triangle in MeshProbe.surface_triangles(null, mesh, surface):
		vertices.append(triangle[0])
		vertices.append(triangle[1])
		vertices.append(triangle[2])
	return vertices

func logical_wall_slot(spec: ChurchSpec) -> int:
	return ChurchBuilder.SURF_WOOD if spec.style == &"nordic_stave" else ChurchBuilder.SURF_STONE
func _wall_triangles(mesh: ArrayMesh) -> Array:
	var result: Array = []
	for slot in [ChurchBuilder.SURF_STONE, ChurchBuilder.SURF_WOOD]:
		var surface: int = _logical_surface(mesh, slot)
		if surface >= 0:
			result.append_array(MeshProbe.surface_triangles(null, mesh, surface))
	return result

func _logical_surface(mesh: ArrayMesh, logical_slot: int) -> int:
	for surface in range(mesh.get_surface_count()):
		var slot: int = surface
		var surface_name: String = mesh.surface_get_name(surface)
		if surface_name.begins_with("material_slot:"):
			slot = int(surface_name.trim_prefix("material_slot:"))
		if slot == logical_slot:
			return surface
	return -1

func _fail(message: String) -> void:
	failures.append("%s: %s" % [active_case, message])





