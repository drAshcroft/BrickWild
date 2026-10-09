extends SceneTree
## Verifies the Witch workshop bay against emitted roof triangles, planned doors,
## and component supports. Geometry is measured from the real ArrayMesh.

class CustomWitchSpec extends HouseSpec:
	func custom_room_rects(_interior: Rect2) -> Array[Rect2]:
		return []

class MissingBayRoofBuilder extends HouseBuilder:
	func _build_witch_workshop_bay_roof(_xf: Transform3D, _bay: Dictionary, _faces: Array[PackedVector3Array]) -> void:
		pass

class MissingBayWallClipBuilder extends HouseBuilder:
	func _witch_bay_wall_profiles(_faces: Array[PackedVector3Array], _run_a: Vector2, _run_b: Vector2, _bay: Dictionary, _xf: Transform3D, profile: PackedVector3Array) -> Array[PackedVector3Array]:
		return [profile]

class MissingBayBearingBuilder extends HouseBuilder:
	func _build_witch_workshop_bay_bearing(_xf: Transform3D, _bay: Dictionary) -> void:
		pass

class MissingBayReturnsBuilder extends HouseBuilder:
	func _build_witch_workshop_bay_returns(_xf: Transform3D, _bay: Dictionary, _faces: Array[PackedVector3Array]) -> void:
		pass

class RaisedBayCeilingBuilder extends HouseBuilder:
	func _build_witch_bay_ceiling(main_rect: Rect2, ceiling_y: float, bay: Dictionary, level: int) -> void:
		var shifted: Dictionary = bay.duplicate(true)
		var xf: Transform3D = shifted["transform"]
		xf.origin.y += 0.30
		shifted["transform"] = xf
		super._build_witch_bay_ceiling(main_rect, ceiling_y, shifted, level)

class MissingWitchEndWallClosureBuilder extends HouseBuilder:
	var removed_rows := 0
	var closure_rays: Array = []

	func component_slab(role: String, points: PackedVector3Array, depth: float,
			surface: int, vertical := true,
			open_edges: PackedInt32Array = PackedInt32Array()) -> Dictionary:
		if role == "roof_wall" and surface == 0 and _rays_cross_profile(points):
			# Keep the authored row, but omit its emitted triangles. ComponentCheck
			# and the same three view rays must both catch this physical deletion.
			removed_rows += 1
			return _log_component(role, "slab", surface, {"points": points.duplicate(),
				"depth": depth, "vertical": vertical, "open_edges": open_edges.duplicate()})
		return super.component_slab(role, points, depth, surface, vertical, open_edges)

	func _rays_cross_profile(points: PackedVector3Array) -> bool:
		if points.size() < 3:
			return false
		for ray_variant in closure_rays:
			var ray: Array[Vector3] = ray_variant
			for tri_index in range(1, points.size() - 1):
				var hit: Variant = Geometry3D.segment_intersects_triangle(ray[0], ray[1],
					points[0], points[tri_index], points[tri_index + 1])
				if hit is Vector3:
					return true
		return false
class FloatingBaySupportBuilder extends HouseBuilder:
	func _build_witch_workshop_bay_supports(xf: Transform3D, bay: Dictionary, _ground_offset := 0.0) -> void:
		super._build_witch_workshop_bay_supports(xf, bay, 0.5)

class ShortWitchBayCeilingBuilder extends HouseBuilder:
	var short_xf := Transform3D.IDENTITY
	var short_axis := 0
	var short_inner := 0.0
	var short_toward_outer := -1.0

	func _build_witch_bay_ceiling(main_rect: Rect2, ceiling_y: float, bay: Dictionary, level: int) -> void:
		short_xf = bay["transform"]
		short_axis = int(bay["axis"])
		short_inner = float(bay["ceiling_inner"])
		short_toward_outer = signf(float(bay["ceiling_outer"]) - short_inner)
		super._build_witch_bay_ceiling(main_rect, ceiling_y, bay, level)

	func component_slab(role: String, points: PackedVector3Array, depth: float,
			surface: int, vertical := true,
			open_edges: PackedInt32Array = PackedInt32Array()) -> Dictionary:
		if role != "witch_workshop_bay_ceiling":
			return super.component_slab(role, points, depth, surface, vertical, open_edges)
		# Record the original authored panel exactly, then emit only a mesh whose
		# inner edge is shortened. This is a truthful log-vs-mesh negative.
		var row := _log_component(role, "slab", surface, {"points": points.duplicate(),
			"depth": depth, "vertical": vertical, "open_edges": open_edges.duplicate()})
		var clipped := points.duplicate()
		for index in range(clipped.size()):
			var local := short_xf.affine_inverse() * clipped[index]
			var cross := local.x if short_axis == 0 else local.z
			if absf(cross - short_inner) <= 0.001:
				if short_axis == 0:
					local.x += short_toward_outer * 0.30
				else:
					local.z += short_toward_outer * 0.30
				clipped[index] = short_xf * local
		_kit.slab_poly(clipped, depth, surface, vertical, open_edges)
		return row

const ROOF_SURFACE := 2
const WALL_SURFACE := 0
const CASES := [
	{"name":"witch_7x9_s1","width":7.0,"length":9.0,"seed":1,"bay":false},
	{"name":"witch_7x9_s8102","width":7.0,"length":9.0,"seed":8102,"bay":false},
	{"name":"witch_7x9_s21325","width":7.0,"length":9.0,"seed":21325,"bay":false},
	{"name":"witch_9x12_s1","width":9.0,"length":12.0,"seed":1,"bay":true},
	{"name":"witch_9x12_s8102","width":9.0,"length":12.0,"seed":8102,"bay":true},
	{"name":"witch_9x12_s21325","width":9.0,"length":12.0,"seed":21325,"bay":true},
	{"name":"witch_17x18_s1","width":17.0,"length":18.0,"seed":1,"bay":true},
	{"name":"witch_17x18_s8102","width":17.0,"length":18.0,"seed":8102,"bay":true},
	{"name":"witch_17x18_s21325","width":17.0,"length":18.0,"seed":21325,"bay":true},
	{"name":"rotated","width":12.0,"length":9.0,"seed":8102,"bay":false},
	{"name":"cottage","width":9.0,"length":12.0,"seed":8102,"bay":false,"style":&"cottage"},
	{"name":"trade","width":9.0,"length":12.0,"seed":8102,"bay":false,"trade":&"alchemist"},
	{"name":"world_family","width":9.0,"length":12.0,"seed":8102,"bay":false,"world_family":&"vastu"},
	{"name":"custom_spec","width":9.0,"length":12.0,"seed":8102,"bay":false,"custom":true},
]
var failures: Array[String] = []

func _init() -> void:
	for fixture in CASES:
		_check_case(fixture)
	_check_partial_return_mesh_control()
	for failure in failures:
		printerr("FAIL ", failure)
	print("witch workshop bay: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)

func _check_case(fixture: Dictionary) -> void:
	var spec: HouseSpec = CustomWitchSpec.new() if bool(fixture.get("custom", false)) else HouseSpec.new()
	spec.style = StringName(fixture.get("style", &"witch_hut"))
	spec.trade = StringName(fixture.get("trade", &"none"))
	spec.width = float(fixture.width)
	spec.length = float(fixture.length)
	spec.height = float(fixture.get("height", 2.8 if float(fixture.width) >= 17.0 else 2.6))
	spec.storeys = 1
	spec.cellars = 0
	spec.roof_type = &"gable"
	var plan := HouseGenerator.generate(spec, int(fixture.seed), false)
	if plan == null:
		failures.append("%s: plan missing" % fixture.name)
		return
	if StringName(fixture.get("world_family", &"")) != &"":
		plan.world_family = StringName(fixture.world_family)
	var layout := HouseGeometry.roof_layout(plan)
	var bay: Dictionary = layout.get("witch_bay", {})
	var ridge_x := float(layout.get("ridge_x", 0.0))
	if spec.style == &"witch_hut" and spec.trade == &"none" and float(fixture.width) < 8.5 and ridge_x <= 0.05:
		failures.append("%s compact no-bay fallback lost its positive ridge offset" % fixture.name)
	if not bay.is_empty():
		var expected_ridge := HouseGeometry.witch_ridge_x(plan, float(layout["span"]) + HouseGeometry.roof_span_out(spec) * 2.0)
		if absf(ridge_x - expected_ridge) > 0.001:
			failures.append("%s roof layout and bay guard use different ridge locations" % fixture.name)
		var roof_xf: Transform3D = bay.transform
		var workshop_rect: Rect2 = plan.rooms[int(bay.room)]["rect"]
		var workshop_local := roof_xf.affine_inverse() * Vector3(workshop_rect.get_center().x, roof_xf.origin.y, workshop_rect.get_center().y)
		if absf(workshop_local.x) > 0.02 and signf(ridge_x) == signf(workshop_local.x):
			failures.append("%s shifted ridge is not away from the Workshop wing" % fixture.name)
	if bool(fixture.bay) != not bay.is_empty():
		failures.append("%s: expected bay=%s, got %s (%s)" % [fixture.name, fixture.bay, not bay.is_empty(), layout.get("witch_bay_rejection", "")])
		return
	if bay.is_empty():
		if bool(fixture.bay):
			failures.append("%s: workshop exists but its bay was silently omitted" % fixture.name)
		return
	var room := int(bay.room)
	if plan.kind_of(room) != &"workshop" or plan.storey_of_room(room) != 0:
		failures.append("%s: bay is not hosted by a ground workshop" % fixture.name)
		return
	var linked := false
	for door in plan.doors:
		var door_a := int(door.get("a", -1))
		var door_b := int(door.get("b", -1))
		if door_b >= 0 and (door_a == room or door_b == room):
			linked = true
	if not linked or not plan.reachable_rooms(plan.entrance_room()).has(room):
		failures.append("%s: workshop has no reachable internal door" % fixture.name)
	var yard_door: Dictionary = {}
	for door in plan.doors:
		if bool(door.get("witch_workshop_yard", false)):
			yard_door = door
	if yard_door.is_empty() or int(yard_door.get("a", -1)) != room:
		failures.append("%s: missing planned workshop yard threshold" % fixture.name)
		return
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan, true)
	# The opening must be absent from the emitted wall at three body heights,
	# three lateral body positions, and in both directions.
	var door_pos: Vector2 = yard_door.pos
	var door_normal: Vector2 = Vector2(yard_door.normal).normalized()
	var door_across := Vector2(-door_normal.y, door_normal.x)
	for lateral in [-0.28, 0.0, 0.28]:
		for body_y in [0.28, 0.95, 1.75]:
			var centre2: Vector2 = door_pos + door_across * float(lateral)
			var out2: Vector2 = centre2 + door_normal * 0.45
			var in2: Vector2 = centre2 - door_normal * 0.45
			var a2 := Vector3(out2.x, HouseGeometry.FLOOR_T + body_y, out2.y)
			var b2 := Vector3(in2.x, HouseGeometry.FLOOR_T + body_y, in2.y)
			if _segment_hits(mesh, 0, a2, b2) or _segment_hits(mesh, 0, b2, a2):
				failures.append("%s: yard doorway is blocked at offset %.2f height %.2f" % [fixture.name, lateral, body_y])
				break
	for window in plan.windows:
		if HouseGeometry.window_rect(window).intersects(HouseGeometry.door_opening_rect(spec, yard_door)):
			failures.append("%s: workshop door intersects a planned window" % fixture.name)
	var xf: Transform3D = bay.transform
	var axis := int(bay.axis)
	var mid_along := (float(bay.along_lo) + float(bay.along_hi)) * 0.5
	var mid_axis := (float(bay.outer) + float(bay.inner)) * 0.5
	var p := Vector2(mid_axis, mid_along) if axis == 0 else Vector2(mid_along, mid_axis)
	var return_outer := float(bay.outer)
	var return_inner := float(bay.inner)
	var return_x := (return_outer + return_inner) * 0.5
	var internal_return_count := 0
	var actual_return_hits := 0
	var return_probe := Vector3.ZERO
	var has_return_probe := false
	for endpoint in [
		{"z": float(bay.along_lo), "internal": bool(bay.get("return_at_lo", false))},
		{"z": float(bay.along_hi), "internal": bool(bay.get("return_at_hi", false))},
	]:
		if not bool(endpoint["internal"]):
			continue
		internal_return_count += 1
		var return_z := float(endpoint["z"])
		var span_t := clampf((return_x - return_outer) / (return_inner - return_outer), 0.0, 1.0)
		var shed_at_probe := lerpf(float(bay.eave_y), float(bay.join_y), span_t) - RoofShape.DEPTH * 0.5
		var host_at_probe := RoofShape.height_at(layout.faces, Vector2(return_x, return_z)) - RoofShape.DEPTH * 0.5
		if not is_finite(host_at_probe) or host_at_probe <= shed_at_probe + 0.08:
			failures.append("%s internal step has no measured return-wall band" % fixture.name)
			continue
		var return_y := (shed_at_probe + host_at_probe) * 0.5
		var return_point := xf * Vector3(return_x, return_y, return_z)
		if not _segment_hits(mesh, 0, return_point + xf.basis * Vector3(0, 0, 0.25), return_point - xf.basis * Vector3(0, 0, 0.25)):
			failures.append("%s internal partition return has no emitted wall triangles" % fixture.name)
		else:
			actual_return_hits += 1
		return_probe = return_point
		has_return_probe = true
	if actual_return_hits != internal_return_count:
		failures.append("%s emitted %d of %d required internal step returns" % [fixture.name, actual_return_hits, internal_return_count])
	var bearing_x := float(bay.get("wall_outer", bay.inner))
	var bearing_t := clampf((bearing_x - float(bay.outer)) / (float(bay.inner) - float(bay.outer)), 0.0, 1.0)
	var bearing_top := lerpf(float(bay.eave_y), float(bay.join_y), bearing_t) - RoofShape.DEPTH * 0.5
	var bearing_point := xf * Vector3(bearing_x, bearing_top - 0.08, mid_along)
	# Surface zero also contains the inclined ceiling liner inside the bay.
	# Probe the outward half of the actual vertical bearing wall, clear of that liner.
	var main_side := signf(bearing_x - float(bay.outer))
	var bearing_from := bearing_point + xf.basis * Vector3(main_side * (HouseGeometry.wall_thickness(spec) * 0.5 + 0.08), 0, 0)
	var bearing_to := bearing_point + xf.basis * Vector3(main_side * 0.03, 0, 0)
	if absf(bearing_x - float(bay.inner)) < 0.20:
		failures.append("%s: bearing was not kept on the actual room wall below the roof inset" % fixture.name)
	if not _segment_hits(mesh, 0, bearing_from, bearing_to):
		failures.append("%s: workshop bearing has no emitted wall-plate support at the roof joint" % fixture.name)
	if fixture.name == "witch_9x12_s1":
		var wall_x := float(bay.wall_outer)
		var wall_z := mid_along
		var wall_shed_y := lerpf(float(bay.eave_y), float(bay.join_y), clampf((wall_x - float(bay.outer)) / (float(bay.inner) - float(bay.outer)), 0.0, 1.0)) - RoofShape.DEPTH * 0.5
		var wall_host_y := RoofShape.height_at(layout.faces, Vector2(wall_x, wall_z)) - RoofShape.DEPTH * 0.5
		if wall_host_y > wall_shed_y + 0.04:
			var wall_probe := xf * Vector3(wall_x, (wall_shed_y + wall_host_y) * 0.5, wall_z)
			if _segment_hits(mesh, 0, wall_probe + xf.basis * Vector3(0.3, 0, 0), wall_probe - xf.basis * Vector3(0.3, 0, 0)):
				failures.append("default: exterior infill remains above the shed underside")
			var floating_wall_builder := MissingBayWallClipBuilder.new()
			var floating_wall_mesh := floating_wall_builder.build(plan, true)
			if not _segment_hits(floating_wall_mesh, 0, wall_probe + xf.basis * Vector3(0.3, 0, 0), wall_probe - xf.basis * Vector3(0.3, 0, 0)):
				failures.append("negative wall clip control: restored upper infill was not detected")
			floating_wall_mesh.clear_surfaces()
		var missing_bearing := MissingBayBearingBuilder.new()
		var missing_bearing_mesh := missing_bearing.build(plan, true)
		if _segment_hits(missing_bearing_mesh, 0, bearing_from, bearing_to):
			failures.append("negative bearing control: omitted inner support still has wall triangles")
		missing_bearing_mesh.clear_surfaces()
		if has_return_probe:
			var missing_returns := MissingBayReturnsBuilder.new()
			var missing_return_mesh := missing_returns.build(plan, true)
			if _segment_hits(missing_return_mesh, 0, return_probe + xf.basis * Vector3(0, 0, 0.25), return_probe - xf.basis * Vector3(0, 0, 0.25)):
				failures.append("negative return control: omitted internal partition infill still has wall triangles")
			missing_return_mesh.clear_surfaces()
	var shed_y := (float(bay.eave_y) + float(bay.join_y)) * 0.5
	var world := xf * Vector3(p.x, 0.0, p.y)
	var shed_hit := _surface_height(mesh, ROOF_SURFACE, Vector2(world.x, world.z), xf.origin.y + shed_y + 0.6)
	if not is_finite(shed_hit) or absf(shed_hit - (xf.origin.y + shed_y)) > 0.20:
		failures.append("%s: emitted shed roof misses its planned plane (%.3f)" % [fixture.name, shed_hit])
	if float(bay.get("minimum_clearance", 0.0)) < 2.30:
		failures.append("%s: plan permits less than 2.30 m workshop headroom" % fixture.name)
	var actual_clearance := INF
	for clearance_coord in [float(bay.outer), float(bay.inner)]:
		var local_q := Vector2(clearance_coord, mid_along) if axis == 0 else Vector2(mid_along, clearance_coord)
		var wq := xf * Vector3(local_q.x, 0.0, local_q.y)
		var roof_t: float = (clearance_coord - float(bay.outer)) / (float(bay.inner) - float(bay.outer))
		var expected_bottom: float = xf.origin.y + lerpf(float(bay.eave_y), float(bay.join_y), roof_t) - RoofShape.DEPTH * 0.5
		var roof_bottom := _oriented_face_height(mesh, ROOF_SURFACE, Vector3(wq.x, expected_bottom, wq.z), false)
		if is_finite(roof_bottom):
			actual_clearance = minf(actual_clearance, roof_bottom - HouseGeometry.FLOOR_T)
		else:
			failures.append("%s: actual shed underside has no triangle at headroom probe" % fixture.name)
	if not is_finite(actual_clearance) or actual_clearance < 2.30:
		failures.append("%s: emitted shed plane gives only %.3f m floor-relative headroom" % [fixture.name, actual_clearance])	
	var ceiling_found := false
	for component in builder.component_log:
		if String(component.get("role", "")) == "witch_workshop_bay_ceiling":
			ceiling_found = true
	var ceiling_coord := lerpf(float(bay.outer), float(bay.inner), 0.5)
	var ceiling_y_local := float(bay.eave_y) - RoofShape.DEPTH * 0.5 - 0.0075 + (float(bay.join_y) - float(bay.eave_y)) * 0.5
	var ceiling_local := Vector2(ceiling_coord, mid_along) if axis == 0 else Vector2(mid_along, ceiling_coord)
	var ceiling_world := xf * Vector3(ceiling_local.x, ceiling_y_local, ceiling_local.y)
	if not ceiling_found or not _segment_hits(mesh, 0, ceiling_world + Vector3.UP * 0.04, ceiling_world - Vector3.UP * 0.04):
		failures.append("%s: workshop ceiling slab does not contact its emitted pitched plane" % fixture.name)
	var contact_point := ceiling_world + Vector3.UP * 0.0075
	if not _ceiling_contacts_roof(mesh, contact_point):
		failures.append("%s: actual ceiling top and roof underside do not contact" % fixture.name)
	var closure_failures := _pitched_liner_contact_failures(mesh, xf, bay)
	for closure_failure in closure_failures:
		failures.append("%s: %s" % [fixture.name, closure_failure])
	if fixture.name == "witch_9x12_s1":
		var shortened_builder := ShortWitchBayCeilingBuilder.new()
		var shortened_mesh := shortened_builder.build(plan, true)
		var original_closure_rows := _role_rows(builder, "witch_workshop_bay_ceiling")
		var shortened_closure_rows := _role_rows(shortened_builder, "witch_workshop_bay_ceiling")
		if not _same_component_rows(original_closure_rows, shortened_closure_rows):
			failures.append("negative liner-joint control changed the authored component identity or geometry log")
		if ComponentCheck.check(shortened_builder, shortened_mesh).get("ok", false):
			failures.append("negative liner-joint control: unchanged original component rows did not detect shortened emitted triangles")
		if _pitched_liner_contact_failures(shortened_mesh, xf, bay).is_empty():
			failures.append("negative liner-joint control: 0.30 m shortened physical ceiling still contacts the roof everywhere")
		var gap_rays: Array = [_camera_pixel_ray(350.0, 104.0), _camera_gap_ray(), _camera_pixel_ray(470.0, 108.0)]
		for ray_index in range(gap_rays.size()):
			var gap_ray: Array[Vector3] = gap_rays[ray_index]
			if not _ray_hits_surface(mesh, WALL_SURFACE, gap_ray[0], gap_ray[1]):
				failures.append("visible workshop roof-wall gap has no actual closure at recorded sky-gap station %d" % ray_index)
		# The logged shortened-liner negative is measured on the physical edge it
		# removes; a separate end-wall closure must remain solid on the camera ray.
		var edge_cross := lerpf(float(bay["ceiling_outer"]), float(bay["ceiling_inner"]), 0.99)
		var edge_along := (float(bay["ceiling_along_lo"]) + float(bay["ceiling_along_hi"])) * 0.5
		var edge_xz := Vector2(edge_cross, edge_along) if int(bay["axis"]) == 0 else Vector2(edge_along, edge_cross)
		var edge_t := clampf((edge_cross - float(bay["outer"])) / (float(bay["inner"]) - float(bay["outer"])), 0.0, 1.0)
		var edge_center_y := float(bay["eave_y"]) - RoofShape.DEPTH * 0.5 - 0.0075 + (float(bay["join_y"]) - float(bay["eave_y"])) * edge_t
		var edge_world := xf * Vector3(edge_xz.x, edge_center_y + 0.0075, edge_xz.y)
		if not _segment_hits(mesh, WALL_SURFACE, edge_world + Vector3.UP * 0.025, edge_world - Vector3.UP * 0.025):
			failures.append("positive liner-edge control has no actual ceiling triangle at its clipped-edge station")
		if _segment_hits(shortened_mesh, WALL_SURFACE, edge_world + Vector3.UP * 0.025, edge_world - Vector3.UP * 0.025):
			failures.append("negative liner-joint control: shortened physical ceiling still covers its clipped-edge station")
		var missing_closure_builder := MissingWitchEndWallClosureBuilder.new()
		missing_closure_builder.closure_rays = gap_rays
		var missing_closure_mesh: ArrayMesh = missing_closure_builder.build(plan, true)
		if missing_closure_builder.removed_rows == 0:
			failures.append("negative eye-ray control removed no logged gable-wall component triangles")
		if not _same_component_rows(_role_rows(builder, "roof_wall"), _role_rows(missing_closure_builder, "roof_wall")):
			failures.append("negative eye-ray control changed the authored gable-wall component rows")
		if ComponentCheck.check(missing_closure_builder, missing_closure_mesh).get("ok", false):
			failures.append("negative eye-ray control: missing emitted gable-wall triangles were not caught by component parity")
		for ray_index in range(gap_rays.size()):
			var missing_gap_ray: Array[Vector3] = gap_rays[ray_index]
			if _ray_hits_surface(missing_closure_mesh, WALL_SURFACE, missing_gap_ray[0], missing_gap_ray[1]):
				failures.append("negative eye-ray control still blocks visible station %d after closure triangles are removed" % ray_index)
		missing_closure_mesh.clear_surfaces()
		shortened_mesh.clear_surfaces()
	if fixture.name == "witch_9x12_s1":
		var raised_builder := RaisedBayCeilingBuilder.new()
		var raised_mesh := raised_builder.build(plan, true)
		var shifted_point := contact_point + Vector3.UP * 0.30
		if not is_finite(_oriented_face_height(raised_mesh, 0, shifted_point, true)):
			failures.append("negative ceiling control: actual raised ceiling was not emitted")
		if _ceiling_contacts_roof(raised_mesh, shifted_point):
			failures.append("negative ceiling control: raised ceiling still contacts roof underside")
		raised_mesh.clear_surfaces()
	var host_y := RoofShape.height_at(layout.faces, p)
	var clearance_hit := _surface_height(mesh, ROOF_SURFACE, Vector2(world.x, world.z), xf.origin.y + host_y + 0.20)
	if is_finite(clearance_hit) and clearance_hit > xf.origin.y + shed_y + 0.18:
		failures.append("%s: main roof still covers the workshop bay at %.3f" % [fixture.name, clearance_hit])
	if fixture.name == "witch_9x12_s1":
		var missing_roof_builder := MissingBayRoofBuilder.new()
		var missing_roof := missing_roof_builder.build(plan, true)
		var missing_hit := _surface_height(missing_roof, ROOF_SURFACE, Vector2(world.x, world.z), xf.origin.y + float(bay.host_y) + 0.3)
		if is_finite(missing_hit):
			failures.append("negative roof control: missing bay panel still has roof hit %.3f" % missing_hit)
		missing_roof.clear_surfaces()
		var floating_builder := FloatingBaySupportBuilder.new()
		var floating_mesh := floating_builder.build(plan, true)
		var floating_posts := 0
		for part in floating_builder.component_log:
			if String(part.get("role", "")) == "witch_workshop_bay_post":
				floating_posts += 1
				var size: Vector3 = part.size
				var center: Vector3 = part.xf.origin
				if center.y - size.y * 0.5 <= 0.49:
					failures.append("negative support control: raised post still appears grounded")
				var ground_probe := Vector3(center.x, 0.03, center.z)
				if _segment_hits(floating_mesh, 1, ground_probe, Vector3(center.x, -0.03, center.z)):
					failures.append("negative support control: displaced post still contacts ground mesh")
		if floating_posts != 2:
			failures.append("negative support control did not emit both raised posts")
		floating_mesh.clear_surfaces()
		var door_index := -1
		for di in range(plan.doors.size()):
			if bool(plan.doors[di].get("witch_workshop_yard", false)):
				door_index = di
				break
		if door_index >= 0:
			var saved: Dictionary = plan.doors[door_index]
			plan.doors.remove_at(door_index)
			var closed_builder := HouseBuilder.new()
			var closed_mesh := closed_builder.build(plan, true)
			var saved_pos: Vector2 = saved.pos
			var saved_normal := Vector2(saved.normal).normalized()
			var saved_across := Vector2(-saved_normal.y, saved_normal.x)
			for lateral in [-0.28, 0.0, 0.28]:
				for body_y in [0.28, 0.95, 1.75]:
					var centre2: Vector2 = saved_pos + saved_across * float(lateral)
					var outside2: Vector2 = centre2 + saved_normal * 0.45
					var inside2: Vector2 = centre2 - saved_normal * 0.45
					var a3 := Vector3(outside2.x, HouseGeometry.FLOOR_T + body_y, outside2.y)
					var b3 := Vector3(inside2.x, HouseGeometry.FLOOR_T + body_y, inside2.y)
					if not _segment_hits(closed_mesh, 0, a3, b3) or not _segment_hits(closed_mesh, 0, b3, a3):
						failures.append("negative opening control: removed workshop door failed wall ray at %.2f / %.2f" % [lateral, body_y])
			closed_mesh.clear_surfaces()
			plan.doors.insert(door_index, saved)
	var posts := 0
	var beam := false
	for part in builder.component_log:
		if String(part.get("role", "")) == "witch_workshop_bay_eave_beam":
			beam = true
		if String(part.get("role", "")) != "witch_workshop_bay_post":
			continue
		posts += 1
		var size: Vector3 = part.size
		var center: Vector3 = part.xf.origin
		if center.y - size.y * 0.5 > 0.01:
			failures.append("%s: bay support post floats above ground" % fixture.name)
	if posts != 2 or not beam:
		failures.append("%s: emitted support frame is incomplete (posts=%d beam=%s)" % [fixture.name, posts, beam])
	for part in builder.component_log:
		if String(part.get("role", "")) == "witch_workshop_bay_post":
			var post_center: Vector3 = part.xf.origin
			if not _segment_hits(mesh, 1, Vector3(post_center.x, 0.03, post_center.z), Vector3(post_center.x, -0.03, post_center.z)):
				failures.append("%s: support post lacks emitted ground contact" % fixture.name)
		if String(part.get("role", "")) == "witch_workshop_bay_eave_beam":
			var beam_point := xf * Vector3(float(bay.outer), float(bay.eave_y) - RoofShape.DEPTH * 0.5, mid_along)
			if not _segment_hits(mesh, 1, beam_point + Vector3.UP * 0.04, beam_point - Vector3.UP * 0.04) or not _segment_hits(mesh, 2, beam_point + Vector3.UP * 0.04, beam_point - Vector3.UP * 0.04):
				failures.append("%s: eave beam does not contact roof panel in emitted triangles" % fixture.name)
	if fixture.name == "witch_9x12_s8102":
		var parity := ComponentCheck.check(builder, mesh)
		if not bool(parity.get("ok", false)):
			failures.append("component mesh parity failed: %s" % str(parity.get("failures", [])))
	var bounds := HouseGeometry.exterior_bounds(plan)
	for part in builder.component_log:
		if String(part.get("role", "")) not in ["witch_workshop_bay_post", "witch_workshop_bay_eave_beam"]:
			continue
		var pos: Vector3 = part.xf.origin
		if pos.x < bounds.position.x - 0.01 or pos.x > bounds.end.x + 0.01 or pos.z < bounds.position.z - 0.01 or pos.z > bounds.end.z + 0.01:
			failures.append("%s: bay support exceeds planned exterior bounds" % fixture.name)
	mesh.clear_surfaces()

func _segment_hits(mesh: ArrayMesh, surface: int, a: Vector3, b: Vector3) -> bool:
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
		var hit: Variant = Geometry3D.segment_intersects_triangle(a, b, vertices[i0], vertices[i1], vertices[i2])
		if hit is Vector3:
			return true
	return false


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
			Vector3(xz.x, top_y, xz.y), Vector3(xz.x, -0.2, xz.y),
			vertices[i0], vertices[i1], vertices[i2])
		if hit is Vector3:
			best = maxf(best, hit.y)
	return best


func _role_rows(builder: HouseBuilder, role: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row in builder.component_log:
		if String(row.get("role", "")) == role:
			rows.append(row)
	return rows


func _same_component_rows(expected: Array[Dictionary], actual: Array[Dictionary]) -> bool:
	if expected.size() != actual.size():
		return false
	for index in range(expected.size()):
		var a: Dictionary = expected[index]
		var b: Dictionary = actual[index]
		for key in ["id", "role", "host", "storey", "surface", "tag", "depth", "vertical"]:
			if a.get(key) != b.get(key):
				return false
		var pa: PackedVector3Array = a.get("points", PackedVector3Array())
		var pb: PackedVector3Array = b.get("points", PackedVector3Array())
		if pa.size() != pb.size():
			return false
		for point_index in range(pa.size()):
			if pa[point_index].distance_squared_to(pb[point_index]) > 1e-12:
				return false
	return true


func _check_partial_return_mesh_control() -> void:
	var plan: HousePlan = null
	var layout: Dictionary = {}
	for seed in [1, 8102, 21325]:
		var spec := HouseSpec.new()
		spec.style = &"witch_hut"
		spec.width = 9.0
		spec.length = 12.0
		var candidate := HouseGenerator.generate(spec, seed, false)
		if candidate == null:
			continue
		var candidate_layout := HouseGeometry.roof_layout(candidate)
		var candidate_bay: Dictionary = candidate_layout.get("witch_bay", {})
		if not candidate_bay.is_empty() and int(candidate_bay.get("axis", -1)) == 0:
			plan = candidate
			layout = candidate_layout
			break
	if plan == null:
		failures.append("partial-return physical control could not find a supported axis-0 service roof")
		return
	var bay: Dictionary = layout["witch_bay"].duplicate(true)
	bay["return_at_lo"] = true
	bay["return_at_hi"] = false
	bay["partition_head_y"] = 0.0
	var xf: Transform3D = bay["transform"]
	# Make a partial cut at an interior station where both the lower shed and
	# the upper host roof are physically supported.
	var z := (float(bay["along_lo"]) + float(bay["along_hi"])) * 0.5
	bay["along_lo"] = z
	var x := lerpf(float(bay["outer"]), float(bay["inner"]), 0.5)
	var outer_underside := float(bay["eave_y"]) - RoofShape.DEPTH * 0.5
	var host_inner := RoofShape.height_at(layout["faces"], Vector2(float(bay["inner"]), z)) - RoofShape.DEPTH * 0.5
	var outer_top := maxf(float(bay["partition_head_y"]), outer_underside)
	if not is_finite(host_inner) or host_inner <= float(bay["partition_head_y"]) + 0.04:
		failures.append("partial-return physical control has no measured high-roof bearing at the inner junction")
		return
	var top_at_probe := lerpf(outer_top, host_inner, 0.5)
	var probe_y := lerpf(float(bay["partition_head_y"]), top_at_probe, 0.5)
	var probe := xf * Vector3(x, probe_y, z)
	var positive := HouseBuilder.new()
	positive.spec = plan.spec
	positive.plan = plan
	positive.begin(4)
	positive._build_witch_workshop_bay_returns(xf, bay, layout["faces"])
	var positive_mesh := positive.commit()
	if not bool(ComponentCheck.check(positive, positive_mesh).get("ok", false)):
		failures.append("partial-return positive component rows differ from emitted wall triangles")
	if not _segment_hits(positive_mesh, WALL_SURFACE,
			probe + xf.basis * Vector3(0, 0, 0.25), probe - xf.basis * Vector3(0, 0, 0.25)):
		failures.append("partial-return positive mesh has no actual return-wall section")
	var missing := MissingBayReturnsBuilder.new()
	missing.spec = plan.spec
	missing.plan = plan
	missing.begin(4)
	missing._build_witch_workshop_bay_returns(xf, bay, layout["faces"])
	var missing_mesh := missing.commit()
	if _segment_hits(missing_mesh, WALL_SURFACE,
			probe + xf.basis * Vector3(0, 0, 0.25), probe - xf.basis * Vector3(0, 0, 0.25)):
		failures.append("partial-return negative: omitted return still has emitted wall triangles")
	positive_mesh.clear_surfaces()
	missing_mesh.clear_surfaces()


func _pitched_liner_contact_failures(mesh: ArrayMesh, xf: Transform3D, bay: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var axis := int(bay["axis"])
	var outer := float(bay["ceiling_outer"])
	var inner := float(bay["ceiling_inner"])
	var along_lo := float(bay["ceiling_along_lo"])
	var along_hi := float(bay["ceiling_along_hi"])
	var station_count := 0
	for cross_t in [0.08, 0.28, 0.50, 0.72, 0.92]:
		for along_t in [0.08, 0.50, 0.92]:
			station_count += 1
			var cross := lerpf(outer, inner, float(cross_t))
			var along := lerpf(along_lo, along_hi, float(along_t))
			var local_xz := Vector2(cross, along) if axis == 0 else Vector2(along, cross)
			var roof_t := clampf((cross - float(bay["outer"])) / (float(bay["inner"]) - float(bay["outer"])), 0.0, 1.0)
			var roof_y := float(bay["eave_y"]) + (float(bay["join_y"]) - float(bay["eave_y"])) * roof_t
			var world := xf * Vector3(local_xz.x, roof_y, local_xz.y)
			if not _ceiling_contacts_roof(mesh, world):
				out.append("actual pitched liner/roof underside miss at cross=%.2f along=%.2f (2 mm limit)" % [cross_t, along_t])
	if station_count != 15:
		out.append("pitched liner contact sampler covered %d of 15 stations" % station_count)
	return out


func _camera_gap_ray() -> Array[Vector3]:
	# This is the exact pin pixel from the restart20 Witch seed-1 eye render.
	return _camera_pixel_ray(410.0, 100.0)

func _camera_pixel_ray(pixel_x: float, pixel_y: float) -> Array[Vector3]:
	var eye := Vector3(-2.1600001, 1.7000000, 2.2200003)
	var target := Vector3(-2.2113624, 1.0700001, 5.0780005)
	var forward := (target - eye).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	var screen_x := 2.0 * pixel_x / 1100.0 - 1.0
	var screen_y := 1.0 - 2.0 * pixel_y / 760.0
	var scale := tan(deg_to_rad(76.0) * 0.5)
	var direction := (forward + right * screen_x * scale * (1100.0 / 760.0) + up * screen_y * scale).normalized()
	var ray: Array[Vector3] = [eye, eye + direction * 10.0]
	return ray


func _ray_hits_surface(mesh: ArrayMesh, surface: int, start: Vector3, finish: Vector3) -> bool:
	for triangle in MeshProbe.surface_triangles(null, mesh, surface):
		var hit: Variant = Geometry3D.segment_intersects_triangle(start, finish,
			triangle[0], triangle[1], triangle[2])
		if hit is Vector3:
			return true
	return false


## Compare the actual upward ceiling triangles with the downward roof triangles.
## A roof top ray measures the other side of the slab; it is not its underside.
func _ceiling_contacts_roof(mesh: ArrayMesh, point: Vector3) -> bool:
	var ceiling_top := _oriented_face_height(mesh, 0, point, true)
	var roof_bottom := _oriented_face_height(mesh, ROOF_SURFACE, point, false)
	return is_finite(ceiling_top) and is_finite(roof_bottom) and absf(ceiling_top - roof_bottom) <= 0.002


func _oriented_face_height(mesh: ArrayMesh, surface: int, point: Vector3, upward: bool) -> float:
	var best := NAN
	var nearest := INF
	for triangle in MeshProbe.surface_triangles(null, mesh, surface):
		var a: Vector3 = triangle[0]
		var b: Vector3 = triangle[1]
		var c: Vector3 = triangle[2]
		var normal: Vector3 = (c - a).cross(b - a)
		if (upward and normal.y <= 0.00001) or (not upward and normal.y >= -0.00001):
			continue
		var hit: Variant = Geometry3D.segment_intersects_triangle(point - Vector3.UP * 0.40, point + Vector3.UP * 0.40, a, b, c)
		if hit is Vector3 and absf(hit.y - point.y) < nearest:
			best = hit.y
			nearest = absf(hit.y - point.y)
	return best




