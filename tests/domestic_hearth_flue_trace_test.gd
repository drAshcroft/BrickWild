extends SceneTree
## Source-only trace of requested ordinary hearths versus emitted flue masses.
const SIZES: Array[Dictionary] = [
	{"name": "small", "width": 7.0, "length": 9.0, "height": 2.6},
	{"name": "default", "width": 9.0, "length": 12.0, "height": 2.6},
	{"name": "large", "width": 17.0, "length": 18.0, "height": 2.8},
]
const ORIGINAL := {"name": "original_11x14", "width": 11.0,
	"length": 14.0, "height": 2.6}

func _initialize() -> void:
	var failures: Array[String] = []
	var requests: Array[Dictionary] = []
	for style in [&"farmhouse", &"cottage", &"thatch_cottage"]:
		for size: Dictionary in SIZES:
			requests.append({"style": style, "size": size})
		requests.append({"style": style, "size": ORIGINAL})
	for request: Dictionary in requests:
		var style: StringName = StringName(request["style"])
		var size: Dictionary = request["size"]
		var spec := HouseSpec.new(7441)
		spec.style = style
		spec.width = float(size["width"])
		spec.length = float(size["length"])
		spec.height = float(size["height"])
		var plan: HousePlan = HouseGenerator.generate(spec, spec.seed, true)
		var builder := HouseBuilder.new()
		builder.build(plan, true)
		var chimney_mass := AABB()
		var chimney_count := 0
		for row: Dictionary in builder.mass_log:
			if String(row.get("name", "")) == "chimney":
				chimney_mass = row["aabb"]
				chimney_count += 1
		var chimney_parts := 0
		for row: Dictionary in builder.part_log:
			if String(row.get("tag", "")) == "chimney":
				chimney_parts += 1
		var breast: Dictionary = HouseGeometry.hearth_breast(plan)
		var roof_top := NAN
		var roof_sample_hits := 0
		var outlet_ray_start := Vector3.ZERO
		var outlet_ray_end := Vector3.ZERO
		var outlet_hit: Variant = null
		var outlet_stack_hit: Variant = null
		var outlet_witness := false
		var outlet_removed_control := false
		var outlet_removed_triangle_count := 0
		var center_alignment_error := INF
		if spec.chimney:
			var centre := HouseGeometry.chimney_center(plan)
			var footprint := HouseGeometry.chimney_size(spec)
			var roof_sample: Dictionary = _actual_roof_top_in_footprint(
				builder.emitted_mesh, centre, Vector2.ONE * footprint)
			roof_top = float(roof_sample.get("top", NAN))
			roof_sample_hits = int(roof_sample.get("hits", 0))
		var flue_clearance := chimney_mass.end.y - roof_top if chimney_count == 1 \
				and is_finite(roof_top) else NAN
		if chimney_count == 1 and is_finite(roof_top):
			var centre := HouseGeometry.chimney_center(plan)
			var footprint := HouseGeometry.chimney_size(spec)
			var probe_y := roof_top + 0.30
			var emitted_center := chimney_mass.position + chimney_mass.size * 0.5
			center_alignment_error = Vector2(emitted_center.x, emitted_center.z).distance_to(centre)
			outlet_ray_start = Vector3(centre.x - footprint, probe_y, centre.y)
			outlet_ray_end = Vector3(centre.x + footprint, probe_y, centre.y)
			outlet_hit = HouseQA._first_mesh_hit(builder.emitted_mesh,
				outlet_ray_start, outlet_ray_end)
			outlet_stack_hit = _outlet_triangle_hit_inside_mass(builder.emitted_mesh,
				chimney_mass, outlet_ray_start, outlet_ray_end)
			outlet_witness = outlet_stack_hit != null
			if outlet_witness:
				# Remove the complete actual emitted chimney volume, not just the
				# one triangle found by the probe. Keep the mass log unchanged.
				var stripped_mesh := _without_actual_chimney_triangles(
					builder.emitted_mesh, chimney_mass)
				outlet_removed_triangle_count = int(stripped_mesh.get_meta(
					"removed_chimney_volume_triangles", 0))
				outlet_removed_control = not _outlet_ray_hits_mass(stripped_mesh,
					chimney_mass, outlet_ray_start, outlet_ray_end) \
					and chimney_count == 1 \
					and outlet_removed_triangle_count > 0
		var row := {
			"style": String(style), "size": String(size["name"]),
			"seed": spec.seed, "dimensions": [spec.width, spec.length, spec.height],
			"host_kind": String(plan.hearth.get("host_kind", "")),
			"breast_present": not breast.is_empty(),
			"spec_chimney": spec.chimney,
			"chimney_mass_count": chimney_count,
			"chimney_mass_position": [chimney_mass.position.x, chimney_mass.position.y, chimney_mass.position.z],
			"chimney_mass_size": [chimney_mass.size.x, chimney_mass.size.y, chimney_mass.size.z],
			"chimney_part_count": chimney_parts,
			"outlet_axis_alignment_error": center_alignment_error,
			"roof_top_in_flue_footprint": roof_top,
			"actual_roof_triangle_sample_hits": roof_sample_hits,
			"emitted_mass_top_minus_roof": flue_clearance,
			"outlet_ray_y": outlet_ray_start.y,
			"outlet_ray_hit": outlet_hit != null,
			"first_ray_hit_point": _hit_point_array(outlet_hit),
			"first_ray_hit_surface": _hit_surface(outlet_hit),
			"first_ray_hit_surface_name": _hit_surface_name(builder.emitted_mesh, outlet_hit),
			"outlet_hit_inside_actual_mass": outlet_witness,
			"actual_chimney_triangle_hit_point": _hit_point_array(outlet_stack_hit),
			"actual_chimney_triangle_hit_surface": _hit_surface(outlet_stack_hit),
			"actual_chimney_triangle_hit_surface_name": _hit_surface_name(builder.emitted_mesh, outlet_stack_hit),
			"same_ray_removed_actual_chimney_triangles": outlet_removed_triangle_count,
			"same_ray_clear_after_actual_chimney_volume_removed": outlet_removed_control,
		}
		print("DOMESTIC_FLUE_TRACE ", JSON.stringify(row))
		if spec.chimney and chimney_count != 1:
			failures.append("%s/%s says chimney=true but has %d emitted chimney masses" % [String(style), String(size["name"]), chimney_count])
		if not spec.chimney and chimney_count != 0:
			failures.append("%s/%s says chimney=false but emitted a chimney mass" % [String(style), String(size["name"])])
		if String(plan.hearth.get("host_kind", "")) == "ordinary_fireplace" \
				and not spec.chimney:
			failures.append("%s/%s has a native fireplace but no requested chimney/flue" % [String(style), String(size["name"])])
		if spec.chimney and (not is_finite(flue_clearance) or flue_clearance < 0.55):
			failures.append("%s/%s emitted flue does not clear sampled roof by 0.55 m" % [String(style), String(size["name"])])
		if spec.chimney and roof_sample_hits == 0:
			failures.append("%s/%s has no actual emitted roof triangle under the chimney footprint" % [String(style), String(size["name"])])
		if spec.chimney and (not outlet_witness or not outlet_removed_control):
			failures.append("%s/%s lacks an actual above-roof outlet triangle witness or its removal control" % [String(style), String(size["name"])])
		if spec.chimney and center_alignment_error > 0.02:
			failures.append("%s/%s emitted outlet is not aligned over its hearth wall station" % [String(style), String(size["name"])])
	for failure in failures:
		push_error(failure)
	print("domestic flue trace: %d requests, %d failures" % [requests.size(), failures.size()])
	quit(1 if not failures.is_empty() else 0)


static func _outlet_ray_hits_mass(mesh: ArrayMesh, mass: AABB,
		start: Vector3, finish: Vector3) -> bool:
	return _outlet_triangle_hit_inside_mass(mesh, mass, start, finish) != null


## Search every real triangle on the ray. A nearer roof edge can be the first
## hit even while the same ray also crosses the actual stack farther along.
static func _outlet_triangle_hit_inside_mass(mesh: ArrayMesh, mass: AABB,
		start: Vector3, finish: Vector3) -> Variant:
	var accepted := mass.grow(0.005)
	var nearest: Variant = null
	var nearest_distance := INF
	for surface in range(mesh.get_surface_count()):
		if _logical_surface(mesh, surface) != HouseBuilder.SURF_FLOOR:
			continue
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index_value: Variant = arrays[Mesh.ARRAY_INDEX]
		var order: PackedInt32Array = index_value if index_value != null else PackedInt32Array()
		if order.is_empty():
			for vertex_index in range(vertices.size()):
				order.append(vertex_index)
		for triangle in range(0, order.size() - 2, 3):
			var hit: Variant = Geometry3D.segment_intersects_triangle(start, finish,
				vertices[order[triangle]], vertices[order[triangle + 1]],
				vertices[order[triangle + 2]])
			if hit == null:
				continue
			var point: Vector3 = hit
			if not accepted.has_point(point):
				continue
			var distance := start.distance_to(point)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = {"point": point, "surface": surface}
	return nearest


static func _logical_surface(mesh: ArrayMesh, surface: int) -> int:
	var surface_name: String = String(mesh.surface_get_name(surface))
	if surface_name.begins_with("material_slot:"):
		return int(surface_name.trim_prefix("material_slot:"))
	if mesh.get_surface_count() == 4:
		return surface
	return -1


## Measure the roof skin itself with vertical triangle rays over the stack's
## actual footprint. The plan sampler can return the eave plane while the roof
## rises rapidly beside it, making an outlet probe start below the real roof.
static func _actual_roof_top_in_footprint(mesh: ArrayMesh, centre: Vector2,
		footprint: Vector2) -> Dictionary:
	var highest := -INF
	var hits := 0
	for fx in [-0.45, -0.22, 0.0, 0.22, 0.45]:
		for fz in [-0.45, -0.22, 0.0, 0.22, 0.45]:
			var point := centre + Vector2(float(fx) * footprint.x,
				float(fz) * footprint.y)
			var start := Vector3(point.x, 40.0, point.y)
			var finish := Vector3(point.x, -1.0, point.y)
			for surface in range(mesh.get_surface_count()):
				if _logical_surface(mesh, surface) != HouseBuilder.SURF_ROOF:
					continue
				var arrays: Array = mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var index_value: Variant = arrays[Mesh.ARRAY_INDEX]
				var order: PackedInt32Array = index_value if index_value != null else PackedInt32Array()
				if order.is_empty():
					for vertex_index in range(vertices.size()):
						order.append(vertex_index)
				for triangle in range(0, order.size() - 2, 3):
					var hit: Variant = Geometry3D.segment_intersects_triangle(start, finish,
						vertices[order[triangle]], vertices[order[triangle + 1]],
						vertices[order[triangle + 2]])
					if hit == null:
						continue
					var hit_point: Vector3 = hit
					hits += 1
					highest = maxf(highest, hit_point.y)
	return {"top": highest if is_finite(highest) else NAN, "hits": hits}


static func _hit_point_array(hit: Variant) -> Array:
	if hit == null:
		return []
	var row: Dictionary = hit
	var point: Vector3 = row["point"]
	return [point.x, point.y, point.z]


static func _hit_surface(hit: Variant) -> int:
	if hit == null:
		return -1
	var row: Dictionary = hit
	return int(row["surface"])


static func _hit_surface_name(mesh: ArrayMesh, hit: Variant) -> String:
	var surface := _hit_surface(hit)
	if surface < 0 or surface >= mesh.get_surface_count():
		return ""
	return String(mesh.surface_get_name(surface))


## Remove actual emitted triangles wholly within the logged chimney volume.
## The ray witness is checked first; the independent removal then tests the
## same outlet predicate while leaving the mass log untouched.
static func _without_actual_chimney_triangles(source: ArrayMesh,
		chimney_mass: AABB) -> ArrayMesh:
	var stripped := ArrayMesh.new()
	var removed_count := 0
	for surface in range(source.get_surface_count()):
		if _logical_surface(source, surface) != HouseBuilder.SURF_FLOOR:
			var arrays: Array = source.surface_get_arrays(surface)
			stripped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			continue
		var source_arrays: Array = source.surface_get_arrays(surface)
		var source_vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
		var index_value: Variant = source_arrays[Mesh.ARRAY_INDEX]
		var source_indices: PackedInt32Array = index_value if index_value != null else PackedInt32Array()
		var order := PackedInt32Array()
		if source_indices.is_empty():
			for vertex_index in range(source_vertices.size()):
				order.append(vertex_index)
		else:
			order = source_indices
		var kept := PackedVector3Array()
		for triangle in range(0, order.size() - 2, 3):
			var a: Vector3 = source_vertices[order[triangle]]
			var b: Vector3 = source_vertices[order[triangle + 1]]
			var c: Vector3 = source_vertices[order[triangle + 2]]
			var accepted := chimney_mass.grow(0.005)
			if accepted.has_point(a) and accepted.has_point(b) \
				and accepted.has_point(c):
				removed_count += 1
				continue
			kept.append_array(PackedVector3Array([a, b, c]))
		if kept.is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = kept
		stripped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	stripped.set_meta("removed_chimney_volume_triangles", removed_count)
	return stripped
