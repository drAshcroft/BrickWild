extends SceneTree
## Measures the plan-derived Witch high roof and retains controls for the
## compact fallback, Cottage, and the 8.5 m lower-roof eligibility boundary.
## The mesh bounds come from real emitted roof-role triangles.

const SEEDS := [1, 8102, 21325]
const SIZES := [Vector2(7.0, 9.0), Vector2(9.0, 12.0), Vector2(17.0, 18.0)]
const CUSTOM_SPEC := preload("res://tests/fixtures/witch_custom_house_spec.gd")
var failures: Array[String] = []

func _init() -> void:
	for size in SIZES:
		for seed in SEEDS:
			_check_case(&"witch_hut", size, seed, minf(size.x, size.y) >= 8.5)
	for size in SIZES:
		_check_case(&"cottage", size, 8102, false)
	_check_case(&"witch_hut", Vector2(8.0, 10.0), 8102, false)
	_check_case(&"witch_hut", Vector2(8.5, 10.0), 8102, true)
	_check_chimney_scope_controls()
	for failure in failures:
		push_error(failure)
	print("Witch core roof: %d cases, %d failures" % [14, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _check_case(style: StringName, size: Vector2, seed: int, expect_ell: bool) -> void:
	var spec := HouseSpec.new(seed)
	spec.style = style
	spec.trade = &"none"
	spec.width = size.x
	spec.length = size.y
	spec.height = 2.8 if size.x >= 17.0 else 2.6
	spec.storeys = 1
	spec.cellars = 0
	var plan := HouseGenerator.generate(spec, seed, false)
	if plan == null:
		failures.append("%s %.1fx%.1f seed%d: no plan" % [style, size.x, size.y, seed])
		return
	var layout := HouseGeometry.roof_layout(plan)
	var bay: Dictionary = layout.get("witch_bay", {})
	if not expect_ell:
		if not bay.is_empty():
			failures.append("%s %.1fx%.1f seed%d: unexpected Witch lower roof" % [style, size.x, size.y, seed])
		if style == &"witch_hut" and minf(size.x, size.y) < 8.5:
			var has_compact_shared_hall := false
			for hall_index in plan.rooms_of(&"hall"):
				has_compact_shared_hall = has_compact_shared_hall \
						or bool(plan.rooms[hall_index].get("shared_witchwork", false))
			var threshold := HouseGeometry.witch_compact_service_threshold(plan)
			if has_compact_shared_hall and threshold.is_empty():
				failures.append("%.1fx%.1f seed%d: compact shared-Hall threshold descriptor is missing" % [size.x, size.y, seed])
			if not has_compact_shared_hall and not threshold.is_empty():
				failures.append("%.1fx%.1f seed%d: noncompact domestic grammar was mislabeled as a compact shared-Hall threshold" % [size.x, size.y, seed])
			var full_storey := HouseGeometry.storey_rect(plan, 0)
			if absf(float(layout.span) - minf(full_storey.size.x, full_storey.size.y)) > 0.01:
				failures.append("%.1fx%.1f seed%d: unsupported below-boundary roof differs from the unmodified storey footprint" % [size.x, size.y, seed])
		return
	if bay.is_empty():
		failures.append("%s %.1fx%.1f seed%d: expected lower roof is unsupported" % [style, size.x, size.y, seed])
		return
	var core := HouseGeometry.witch_high_core_rect(plan)
	var expected_span := minf(core.size.x, core.size.y)
	if absf(float(layout.span) - expected_span) > 0.01:
		failures.append("%.1fx%.1f seed%d: roof span %.3f does not match occupied core %.3f" % [size.x, size.y, seed, layout.span, expected_span])
	var expected_rise := minf(expected_span * spec.roof_pitch * 0.5,
		clampf(expected_span * 0.52, 3.6, 5.6))
	if absf(float(layout.rise) - expected_rise) > 0.01:
		failures.append("%.1fx%.1f seed%d: main rise %.3f is not derived from core width %.3f" % [size.x, size.y, seed, layout.rise, expected_span])
	var builder := HouseBuilder.new()
	var mesh: ArrayMesh = builder.build(plan, true)
	var chimney_point := HouseGeometry.chimney_center(plan)
	var flue_s: float = HouseGeometry.chimney_flue_size(spec, plan.world_family)
	var hearth_wall := plan.hearth_wall()
	var site := HouseGeometry.site_rect(spec)
	var wall_line := site.position.y if hearth_wall == 0 else site.end.y if hearth_wall == 1 \
		else site.position.x if hearth_wall == 2 else site.end.x
	var chimney_axis := chimney_point.y if hearth_wall <= 1 else chimney_point.x
	if absf(chimney_axis - wall_line) > 0.01:
		failures.append("%.1fx%.1f seed%d: split-roof Witch flue is not centred on its actual exterior host wall" % [size.x, size.y, seed])
	var roof_top := builder._roof_top_surface_in_flue_footprint(chimney_point,
		Vector2.ONE * flue_s)
	var emitted_local_roof_top := _actual_surface_height_near(mesh,
		HouseBuilder.SURF_ROOF, chimney_point, 3.0)
	var emitted_flue_top := _emitted_flue_top(builder, flue_s)
	if not is_finite(roof_top):
		failures.append("%.1fx%.1f seed%d: plan roof sampler has no roof crossing anywhere under the flue footprint" % [size.x, size.y, seed])
	else:
		var chimney_mass_top := -INF
		for mass in builder.mass_log:
			if String(mass.get("name", "")) == "chimney":
				var chimney_aabb: AABB = mass["aabb"]
				chimney_mass_top = chimney_aabb.position.y + chimney_aabb.size.y
		if not is_finite(emitted_local_roof_top) or not is_finite(emitted_flue_top):
			failures.append("%.1fx%.1f seed%d: emitted roof triangle oracle or flue component top is missing" % [size.x, size.y, seed])
		else:
			var local_clearance := emitted_flue_top - emitted_local_roof_top
			if local_clearance < HouseBuilder.CHIMNEY_CLEAR - 0.002 \
					or local_clearance > HouseBuilder.CHIMNEY_CLEAR + 0.02:
				failures.append("%.1fx%.1f seed%d: emitted flue top clears the exact 3 m roof-triangle neighbourhood by %.3f m; require %.3f–%.3f m" % [
					size.x, size.y, seed, local_clearance, HouseBuilder.CHIMNEY_CLEAR - 0.002,
					HouseBuilder.CHIMNEY_CLEAR + 0.02])
		var expected_chimney_top := emitted_flue_top + 0.18 + HouseGeometry.CHIMNEY_POT_H
		if not is_finite(chimney_mass_top) or absf(chimney_mass_top - expected_chimney_top) > 0.025:
			failures.append("%.1fx%.1f seed%d: chimney mass top does not contain emitted flue, crown and pot (mass %.3f, emitted stack %.3f)" % [size.x, size.y, seed, chimney_mass_top, expected_chimney_top])
	var roof_rows := builder.components("roof_face_")
	var bay_rows := builder.components("witch_workshop_bay_roof")
	if roof_rows.is_empty() or bay_rows.is_empty():
		failures.append("%.1fx%.1f seed%d: roof component roles are missing" % [size.x, size.y, seed])
		return
	if mesh == null or mesh.get_surface_count() <= HouseBuilder.SURF_ROOF:
		failures.append("%.1fx%.1f seed%d: emitted roof mesh surface is missing" % [size.x, size.y, seed])
		return
	var xf: Transform3D = layout.transform
	var inverse := xf.affine_inverse()
	var max_x := 0.0
	var max_z := 0.0
	for row in roof_rows:
		for world in row["points"]:
			var local: Vector3 = inverse * world
			max_x = maxf(max_x, absf(local.x))
			max_z = maxf(max_z, absf(local.z))
	if max_x > float(layout.span) * 0.5 + HouseGeometry.roof_span_out(spec) + 0.03:
		failures.append("%.1fx%.1f seed%d: emitted main roof exceeds the measured high-core cross-span" % [size.x, size.y, seed])
	if max_z > float(layout.along) * 0.5 + HouseGeometry.roof_along_out(spec) + 0.03:
		failures.append("%.1fx%.1f seed%d: emitted main roof exceeds the core's actual long run" % [size.x, size.y, seed])
	var wing: Rect2 = bay.wing_rect
	if core.intersection(wing).get_area() > 0.001:
		failures.append("%.1fx%.1f seed%d: high-core roof AABB intersects marked service-roof wing by %.3fm2 (%s vs %s)" % [size.x, size.y, seed, core.intersection(wing).get_area(), str(core), str(wing)])
	var marked_working_rooms: Array[int] = []
	for room_index in plan.room_count():
		if bool(plan.rooms[room_index].get("witch_service_wing", false)):
			marked_working_rooms.append(room_index)
	var workshops := plan.rooms_of(&"workshop")
	if marked_working_rooms.is_empty() or workshops.is_empty() or not marked_working_rooms.has(workshops[0]):
		failures.append("%.1fx%.1f seed%d: lower roof is not attached to the marked Workshop service group" % [size.x, size.y, seed])
	for room_index in plan.room_count():
		if plan.storey_of_room(room_index) != 0 \
				or bool(plan.rooms[room_index].get("witch_service_wing", false)):
			continue
		if not core.grow(0.01).encloses(HouseGeometry.room_floor_rect(plan, room_index)):
			failures.append("%.1fx%.1f seed%d: high roof footprint omits an occupied core room" % [size.x, size.y, seed])
	for room_index in marked_working_rooms:
		var room: Rect2 = plan.rooms[room_index]["rect"]
		if not wing.grow(0.01).encloses(HouseGeometry.room_floor_rect(plan, room_index)):
			failures.append("%.1fx%.1f seed%d: lower roof/ceiling misses marked working room %d (%s)" % [size.x, size.y, seed, room_index, str(plan.kind_of(room_index))])
		if room.intersection(core).get_area() > 0.001:
			failures.append("%.1fx%.1f seed%d: occupied core overlaps the service wing" % [size.x, size.y, seed])
	_check_emitted_join(mesh, layout, bay, size, seed)
	_check_emitted_chimney_top(mesh, chimney_point, size, seed, flue_s, roof_top)
	var room_bounds: Array[Dictionary] = []
	for room_index in plan.room_count():
		room_bounds.append({"room": room_index, "kind": String(plan.kind_of(room_index)),
			"rect": plan.rooms[room_index]["rect"],
			"witch_service_wing": bool(plan.rooms[room_index].get("witch_service_wing", false))})
	print(JSON.stringify({"style": style, "size": size, "seed": seed,
		"core": core, "wing": wing, "core_wing_intersection_area": core.intersection(wing).get_area(),
		"room_bounds": room_bounds, "roof_span": layout.span, "roof_rise": layout.rise,
		"flue_footprint_roof_plan": roof_top, "flue_neighbourhood_roof_mesh": emitted_local_roof_top,
		"emitted_flue_top": emitted_flue_top,
		"emitted_flue_clearance": emitted_flue_top - emitted_local_roof_top,
		"ridge_local": layout.ridge_x, "bay_join_y": bay.join_y,
		"bay_eave_y": bay.eave_y, "bay_wall_outer": bay.wall_outer,
		"join_backset": absf(float(bay.inner) - float(bay.wall_outer)),
		"host_at_join": RoofShape.height_at(layout.faces, Vector2(float(bay.inner), (float(bay.along_lo) + float(bay.along_hi)) * 0.5) if int(bay.axis) == 0 else Vector2((float(bay.along_lo) + float(bay.along_hi)) * 0.5, float(bay.inner))),
		"emitted_roof_half_span": max_x}))


func _emitted_flue_top(builder: HouseBuilder, flue_size: float) -> float:
	var highest := -INF
	for part in builder.part_log:
		if String(part.get("tag", "")) != "chimney" or String(part.get("kind", "")) != "box":
			continue
		var size: Vector3 = part["size"]
		if absf(size.x - flue_size) > 0.001 or absf(size.z - flue_size) > 0.001:
			continue
		var position: Vector3 = part["pos"]
		highest = maxf(highest, position.y + size.y * 0.5)
	return highest if is_finite(highest) else NAN


## Independent exact-ish extrema oracle: inspect committed roof triangles and
## find each triangle's highest point inside the safety circle. Candidate
## points include triangle vertices, closest edge points, circle/edge
## intersections, and circle boundary points inside the triangle.
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


func _check_chimney_scope_controls() -> void:
	var controls: Array[Dictionary] = []
	var cottage_spec := HouseSpec.new(8102)
	cottage_spec.style = &"cottage"
	cottage_spec.width = 9.0
	cottage_spec.length = 12.0
	var cottage_plan := HouseGenerator.generate(cottage_spec, 8102, false)
	if cottage_plan != null:
		controls.append({"name": "cottage", "plan": cottage_plan})
	var compact_spec := HouseSpec.new(8102)
	compact_spec.style = &"witch_hut"
	compact_spec.width = 7.0
	compact_spec.length = 9.0
	var compact_plan := HouseGenerator.generate(compact_spec, 8102, false)
	if compact_plan != null:
		controls.append({"name": "compact", "plan": compact_plan})
	var below_boundary_spec := HouseSpec.new(8102)
	below_boundary_spec.style = &"witch_hut"
	below_boundary_spec.width = 8.0
	below_boundary_spec.length = 10.0
	var below_boundary_plan := HouseGenerator.generate(below_boundary_spec, 8102, false)
	if below_boundary_plan != null:
		controls.append({"name": "below_boundary", "plan": below_boundary_plan})
	var trade_spec := HouseSpec.new(8102)
	trade_spec.style = &"witch_hut"
	trade_spec.trade = &"smith"
	trade_spec.width = 9.0
	trade_spec.length = 12.0
	var trade_plan := HouseGenerator.generate(trade_spec, 8102, false)
	if trade_plan != null:
		controls.append({"name": "trade", "plan": trade_plan})
	var world_spec := HouseSpec.new(8102)
	world_spec.style = &"witch_hut"
	world_spec.width = 9.0
	world_spec.length = 12.0
	var world_plan := HouseGenerator.generate(world_spec, 8102, false)
	if world_plan != null:
		world_plan.world_family = &"vastu"
		controls.append({"name": "world", "plan": world_plan})
	var custom_spec := CUSTOM_SPEC.new() as HouseSpec
	custom_spec.style = &"witch_hut"
	custom_spec.width = 9.0
	custom_spec.length = 12.0
	var custom_plan := HouseGenerator.generate(HouseSpec.new(), 8102, false)
	if custom_plan != null:
		custom_plan.spec = custom_spec
		controls.append({"name": "custom", "plan": custom_plan})
	if controls.size() != 6:
		failures.append("chimney scope controls built %d plans; expected six" % controls.size())
	for control in controls:
		var plan: HousePlan = control["plan"]
		if not HouseGeometry.witch_workshop_bay(plan).is_empty():
			failures.append("chimney control %s unexpectedly entered the split-roof bay scope" % control.name)
			continue
		var actual := HouseGeometry.chimney_center(plan)
		var expected := _legacy_chimney_center(plan)
		if actual.distance_to(expected) > 0.001:
			failures.append("chimney control %s moved from its legacy exterior-stack origin" % control.name)


func _legacy_chimney_center(plan: HousePlan) -> Vector2:
	var s := HouseGeometry.chimney_size(plan.spec)
	var r := HouseGeometry.site_rect(plan.spec)
	var c := Vector2(r.end.x + s / 2.0 - 0.15, 0.0)
	var host := plan.hearth_room()
	if host < 0:
		return c
	var wall := plan.hearth_wall()
	var run := HousePlanFeatures.clear_wall_span(plan, host, wall)
	var along := (run.x + run.y) * 0.5
	if plan.focus_room() == host and plan.focus_cat() == "hearth" and plan.focus_pos().is_finite():
		along = plan.focus_pos().x if wall <= 1 else plan.focus_pos().y
	match wall:
		0: c = Vector2(along, r.position.y - s / 2.0 + 0.15)
		1: c = Vector2(along, r.end.y + s / 2.0 - 0.15)
		2: c = Vector2(r.position.x - s / 2.0 + 0.15, along)
		_: c = Vector2(r.end.x + s / 2.0 - 0.15, along)
	return c


func _check_emitted_join(mesh: ArrayMesh, layout: Dictionary, bay: Dictionary,
		size: Vector2, seed: int) -> void:
	var xf: Transform3D = layout.transform
	var axis := int(bay["axis"])
	var outer := float(bay["outer"])
	var inner := float(bay["inner"])
	var along_mid := (float(bay["along_lo"]) + float(bay["along_hi"])) * 0.5
	var direction := signf(inner - outer)
	if absf(direction) < 0.5:
		failures.append("%.1fx%.1f seed%d: degenerate roof join axis" % [size.x, size.y, seed])
		return
	# The high-core roof lies inward of the joining edge. The lower service roof
	# lies outward. Probe the emitted triangles along the full shared seam.
	var main_cross := inner + direction * 0.04
	var service_cross := inner - direction * 0.04
	var lo := float(bay["along_lo"])
	var hi := float(bay["along_hi"])
	for fraction in [0.02, 0.25, 0.5, 0.75, 0.98]:
		var along := lerpf(lo, hi, float(fraction))
		var main_local := Vector3(main_cross, 0.0, along) if axis == 0 else Vector3(along, 0.0, main_cross)
		var service_local := Vector3(service_cross, 0.0, along) if axis == 0 else Vector3(along, 0.0, service_cross)
		var main_world := xf * main_local
		var service_world := xf * service_local
		var main_y := _emitted_roof_height(mesh, main_world.x, main_world.z)
		var service_y := _emitted_roof_height(mesh, service_world.x, service_world.z)
		if not is_finite(main_y) or not is_finite(service_y):
			failures.append("%.1fx%.1f seed%d: emitted roof triangles leave a gap at join fraction %.2f" % [size.x, size.y, seed, fraction])
			continue
		if absf(main_y - service_y) > 0.14:
			failures.append("%.1fx%.1f seed%d: emitted main/service roof surfaces disagree by %.3fm at join fraction %.2f" % [size.x, size.y, seed, absf(main_y - service_y), fraction])
	var host_at_join := RoofShape.height_at(layout.faces, Vector2(inner, along_mid) if axis == 0 else Vector2(along_mid, inner))
	if not is_finite(host_at_join) or absf(host_at_join - float(bay.join_y)) > 0.14:
		failures.append("%.1fx%.1f seed%d: join seam is not physically inset to the measured host plane" % [size.x, size.y, seed])


func _check_emitted_chimney_top(mesh: ArrayMesh, centre: Vector2,
		size: Vector2, seed: int, flue_size: float, expected_plan_roof_top: float) -> void:
	var roof_y := -INF
	var crossing_samples := 0
	for fx in [-0.5, 0.0, 0.5]:
		for fz in [-0.5, 0.0, 0.5]:
			var point := centre + Vector2(float(fx) * flue_size, float(fz) * flue_size)
			var actual_y := _emitted_roof_height(mesh, point.x, point.y)
			if is_finite(actual_y):
				crossing_samples += 1
				roof_y = maxf(roof_y, actual_y)
	if crossing_samples < 3:
		failures.append("%.1fx%.1f seed%d: only %d of nine measured flue-footprint samples cross emitted roof triangles" % [size.x, size.y, seed, crossing_samples])
		return
	if absf(roof_y - expected_plan_roof_top) > 0.08:
		failures.append("%.1fx%.1f seed%d: plan roof footprint top %.3f differs from emitted triangle top %.3f" % [size.x, size.y, seed, expected_plan_roof_top, roof_y])
	if is_finite(_emitted_roof_height(ArrayMesh.new(), centre.x, centre.y)):
		failures.append("%.1fx%.1f seed%d: roof crossing probe accepted a mesh with no emitted roof surface" % [size.x, size.y, seed])
	var chimney_top := -INF
	for surface in [HouseBuilder.SURF_FLOOR, HouseBuilder.SURF_TRIM]:
		if surface >= mesh.get_surface_count():
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0, count - 2, 3):
			var a: Vector3 = vertices[indices[i]] if not indices.is_empty() else vertices[i]
			var b: Vector3 = vertices[indices[i + 1]] if not indices.is_empty() else vertices[i + 1]
			var c: Vector3 = vertices[indices[i + 2]] if not indices.is_empty() else vertices[i + 2]
			var centre_xz := Vector2((a.x + b.x + c.x) / 3.0, (a.z + b.z + c.z) / 3.0)
			if centre_xz.distance_to(centre) <= 0.55:
				chimney_top = maxf(chimney_top, maxf(a.y, maxf(b.y, c.y)))
	if not is_finite(chimney_top) or chimney_top - roof_y < HouseBuilder.CHIMNEY_CLEAR - 0.04:
		failures.append("%.1fx%.1f seed%d: emitted chimney faces clear roof by %.3fm; need %.3fm" % [size.x, size.y, seed, chimney_top - roof_y, HouseBuilder.CHIMNEY_CLEAR])


func _emitted_roof_height(mesh: ArrayMesh, x: float, z: float) -> float:
	if mesh == null or HouseBuilder.SURF_ROOF >= mesh.get_surface_count():
		return NAN
	var arrays := mesh.surface_get_arrays(HouseBuilder.SURF_ROOF)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var highest := -INF
	var count := indices.size() if not indices.is_empty() else vertices.size()
	for i in range(0, count - 2, 3):
		var a: Vector3 = vertices[indices[i]] if not indices.is_empty() else vertices[i]
		var b: Vector3 = vertices[indices[i + 1]] if not indices.is_empty() else vertices[i + 1]
		var c: Vector3 = vertices[indices[i + 2]] if not indices.is_empty() else vertices[i + 2]
		var point := Vector2(x, z)
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var c2 := Vector2(c.x, c.z)
		var denom := (b2 - a2).cross(c2 - a2)
		if absf(denom) < 0.000001:
			continue
		var wb := (point - a2).cross(c2 - a2) / denom
		var wc := (b2 - a2).cross(point - a2) / denom
		var wa := 1.0 - wb - wc
		if wa < -0.0001 or wb < -0.0001 or wc < -0.0001:
			continue
		highest = maxf(highest, wa * a.y + wb * b.y + wc * c.y)
	return highest if is_finite(highest) else NAN
