extends SceneTree
## Focused runtime assembly contract for ordinary household fireboxes.
var failures: Array[String] = []
var checks := 0
const SIZE_CASES: Array[Dictionary] = [
	{"name": "small", "width": 7.0, "length": 9.0, "height": 2.6},
	{"name": "default", "width": 9.0, "length": 12.0, "height": 2.6},
	{"name": "large", "width": 17.0, "length": 18.0, "height": 2.8},
]
const ORIGINAL_REQUEST_CASE: Dictionary = {
	"name": "original_11x14", "width": 11.0, "length": 14.0, "height": 2.6,
}

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for style in [&"farmhouse", &"cottage", &"thatch_cottage"]:
		for size in SIZE_CASES:
			_check_style(style, size)
		_check_style(style, ORIGINAL_REQUEST_CASE)
	_check_family_exclusions()
	for failure in failures:
		push_error(failure)
	print("domestic hearth heat assembly: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _check_style(style: StringName, size: Dictionary) -> void:
	var spec := HouseSpec.new(7441)
	spec.style = style
	spec.width = float(size["width"])
	spec.length = float(size["length"])
	spec.height = float(size["height"])
	var plan := HouseGenerator.generate(spec, spec.seed, true)
	var breast: Dictionary = HouseGeometry.hearth_breast(plan)
	var where := "%s/%s seed=%d %.2fx%.2f" % [String(style), String(size["name"]),
		spec.seed, spec.width, spec.length]
	if breast.is_empty() or String(plan.hearth.get("host_kind", "")) != "ordinary_fireplace":
		_fail(where + ": no native structural fireplace host")
		return
	var old_hearth_rows := 0
	for row: Dictionary in plan.furniture:
		if PropCatalog.category(String(row.get("key", ""))) == "hearth":
			old_hearth_rows += 1
	_expect(old_hearth_rows == 0,
		where + ": ordinary shell host still pretends a hearth prop occupies the room")
	var cooking_vessels := 0
	for row: Dictionary in plan.furniture:
		if String(row.get("key", "")) != "Pot_1":
			continue
		cooking_vessels += 1
		var host_index: int = int(row.get("host", -1))
		var hosted_on_prep_surface := host_index >= 0 \
			and host_index < plan.furniture.size() \
			and String(plan.furniture[host_index].get("cat", "")) == "workbench" \
			and int(plan.furniture[host_index].get("room", -1)) == int(row.get("room", -2))
		_expect(String(row.get("cat", "")) == "cookware" and hosted_on_prep_surface,
			where + ": Pot_1 is not cookware hosted on the room's preparation surface")
	_expect(cooking_vessels == 1,
		where + ": ordinary cooking plan lacks exactly one measured Pot_1 vessel")
	var hearth_vessel_plan: Dictionary = plan.hearth.get("cooking_vessel", {})
	_expect(String(hearth_vessel_plan.get("key", "")) == "Pot_1" \
		and String(hearth_vessel_plan.get("purpose", "")) == "hearth_cooking" \
		and String(hearth_vessel_plan.get("host", "")) == "ordinary_fireplace" \
		and String(hearth_vessel_plan.get("support", "")) == "iron_tripod",
		where + ": no explicit plan-owned firebox vessel/support relation")
	var builder := HouseBuilder.new()
	builder.build(plan, true)
	var scene_root := Node3D.new()
	get_root().add_child(scene_root)
	var anchor := Node3D.new()
	anchor.name = "OrdinaryFireplaceHost"
	anchor.position = Vector3(Vector2(breast["centre"]).x, 0.0, Vector2(breast["centre"]).y)
	anchor.rotation.y = float(breast["yaw"])
	scene_root.add_child(anchor)
	var placement := {"room": int(breast["room"]), "pos": anchor.position}
	var assembly: Dictionary = HouseAssembler._domestic_hearth_assembly(
		anchor, placement, plan, builder)
	if assembly.is_empty():
		_fail(where + ": measured ordinary firebox did not assemble from its real host")
		scene_root.free()
		return
	var heat: Node3D = assembly["heat"]
	var soot: Node3D = assembly["soot"]
	var cooking_vessel := heat.find_child("HearthCookingVessel", true, false) as Node3D
	var tripod := heat.find_child("HearthIronTripod", true, false) as Node3D
	var support_ring := heat.find_child("TrivetSupportRing", true, false) as MeshInstance3D
	_expect(cooking_vessel != null and tripod != null and support_ring != null,
		where + ": planned firebox vessel has no real model and measured iron support")
	if cooking_vessel != null:
		var model_meshes := cooking_vessel.find_children("*", "MeshInstance3D", true, false)
		_expect(not model_meshes.is_empty()
			and cooking_vessel.scene_file_path == PropCatalog.scene_path("Pot_1")
			and String(cooking_vessel.get_meta("planned_key", "")) == "Pot_1"
			and String(cooking_vessel.get_meta("plan_role", "")) == "hearth_cooking",
			where + ": firebox vessel is not the actual plan-owned Pot_1 model")
	anchor.add_child(heat)
	scene_root.add_child(soot)
	var heat_names := ["FuelBed", "Firewood_0", "Firewood_1", "Flame_0", "Flame_1", "Flame_2", "HearthWarmth"]
	for name in heat_names:
		_expect(heat.find_child(name, true, false) != null,
			where + ": missing assembled heat part " + name)
	var metrics := _opening_metrics(builder, breast)
	if metrics.is_empty():
		_fail(where + ": cannot independently measure emitted opening")
		scene_root.free()
		return
	var breast_metrics := _emitted_breast_metrics(builder)
	if breast_metrics.is_empty():
		_fail(where + ": cannot independently measure emitted breast sides")
		scene_root.free()
		return
	var clear_span: float = float(breast.get("clear_wall_span", 0.0))
	_expect(absf(float(breast_metrics["width"]) - float(breast["width"])) < 0.002
		and float(breast_metrics["width"]) >= 1.08 - 0.002
		and absf(float(breast_metrics["width"]) \
			- minf(1.90, clear_span - 0.10)) < 0.002
		and float(breast_metrics["width"]) <= clear_span - 0.10 + 0.002
		and float(breast_metrics["width"]) <= 1.90 + 0.002
		and absf(float(breast_metrics["depth"]) - 0.72) <= 0.002,
		where + ": emitted breast exceeds its clear wall span or measured depth")
	_expect(float(metrics["nominal_width"]) < float(breast_metrics["width"]) - 0.02
		and float(metrics["sill"]) > 0.0
		and float(metrics["head"]) < spec.height,
		where + ": emitted mouth lacks positive breast margins")
	if clear_span >= 2.00:
		_expect(float(breast_metrics["width"]) >= 1.90 - 0.002
			and float(metrics["nominal_width"]) >= 1.45
			and float(metrics["width"]) >= 1.25,
			where + ": roomy wall span did not produce the wider measured mouth")
	else:
		_expect(float(metrics["width"]) >= 0.60,
			where + ": tight wall span lost the prior clear firebox width")
	_check_hearth_finish(anchor, builder, breast_metrics, metrics, spec, where)
	_expect(absf(float(heat.get_meta("opening_center_y")) - float(metrics["center_y"])) < 0.001,
		where + ": center-height metadata differs from emitted foot/lintel")
	_expect(absf(float(heat.get_meta("opening_clear_width")) - float(metrics["width"])) < 0.001,
		where + ": clear width differs from emitted jambs")
	_expect(absf(float(heat.get_meta("recess_depth")) - float(metrics["depth"])) < 0.001,
		where + ": recess depth differs from emitted jamb returns")
	_check_firebox_bounds(anchor, heat, float(metrics["sill"]), float(metrics["head"]),
		float(metrics["width"]), float(metrics["depth"]), where)
	_check_actual_shell_sightlines(anchor, heat, builder, breast, metrics, where)
	_expect(HouseAssembler._heat_fits_measured_firebox(anchor, heat,
		float(metrics["sill"]), float(metrics["head"]),
		float(metrics["width"]), float(metrics["depth"])),
		where + ": actual fire parts fail the shared measured-opening predicate")
	_expect(cooking_vessel != null and HouseAssembler._hearth_cooking_vessel_fits(heat,
		float(heat.get_meta("opening_sill_local_y")),
		float(heat.get_meta("opening_head_local_y")),
		float(metrics["width"]), float(metrics["depth"])),
		where + ": planned vessel does not sit on its measured in-aperture trivet")
	if cooking_vessel != null:
		_check_cooking_vessel(cooking_vessel, heat, float(metrics["sill"]),
			float(metrics["head"]), float(metrics["width"]),
			float(metrics["depth"]), where)
		var vessel_meshes := cooking_vessel.find_children("*", "MeshInstance3D", true, false)
		var vessel_bounds := AABB()
		var has_vessel_bounds := false
		for mesh_variant in vessel_meshes:
			var vessel_mesh := mesh_variant as MeshInstance3D
			if vessel_mesh == null or vessel_mesh.mesh == null:
				continue
			var bounds := _aabb_in_space(vessel_mesh, heat)
			vessel_bounds = bounds if not has_vessel_bounds else vessel_bounds.merge(bounds)
			has_vessel_bounds = true
		_expect(has_vessel_bounds, where + ": cannot measure actual cooking vessel body bounds")
		var central_flame := heat.find_child("Flame_1", true, false) as MeshInstance3D
		if central_flame != null and has_vessel_bounds:
			var central_bounds := _aabb_in_space(central_flame, heat)
			var tip: Vector3 = _flame_apex_in_space(central_flame, heat)
			var rises_under_vessel := central_bounds.position.x < vessel_bounds.end.x \
				and central_bounds.end.x > vessel_bounds.position.x \
				and central_bounds.position.y <= vessel_bounds.position.y + 0.01 \
				and central_bounds.end.y > vessel_bounds.position.y
			_expect(rises_under_vessel and tip.x >= vessel_bounds.end.x + 0.009,
				where + ": central flame tip pierces the measured vessel silhouette or is disconnected from its fire")
			var original_flame_position: Vector3 = central_flame.position
			central_flame.position.x -= maxf(0.0, tip.x - vessel_bounds.end.x) + 0.04
			var negative_tip: Vector3 = _flame_apex_in_space(central_flame, heat)
			_expect(negative_tip.x < vessel_bounds.end.x + 0.009,
				where + ": central flame silhouette negative control failed to restore the pot piercing")
			central_flame.position = original_flame_position
	var base_split: MeshInstance3D = heat.find_child("Firewood_0", true, false)
	var cross_split: MeshInstance3D = heat.find_child("Firewood_1", true, false)
	var cross_position: Vector3 = cross_split.position
	cross_split.position.y += 0.05
	_expect(not HouseAssembler._hearth_cooking_vessel_fits(heat,
		float(heat.get_meta("opening_sill_local_y")),
		float(heat.get_meta("opening_head_local_y")),
		float(metrics["width"]), float(metrics["depth"])),
		where + ": timber raised into the pot escaped the vessel-clearance check")
	cross_split.position = cross_position
	_expect(absf(base_split.rotation.y - cross_split.rotation.y) > 0.7
		and cross_split.position.y > base_split.position.y + 0.04
		and base_split.position.z < 0.0,
		where + ": firewood is not visibly crossed, layered at the mouth")
	for log_mesh: MeshInstance3D in [base_split, cross_split]:
		var log_arrays: Array = log_mesh.mesh.surface_get_arrays(0)
		_expect(_firewood_winding_matches(log_arrays),
			where + ": bark or cut end is culled from outside the log")
		var reversed: Array = log_arrays.duplicate(true)
		var log_indices: PackedInt32Array = reversed[Mesh.ARRAY_INDEX]
		var log_normals: PackedVector3Array = reversed[Mesh.ARRAY_NORMAL]
		for triangle in range(0, log_indices.size(), 3):
			if absf(log_normals[log_indices[triangle]].x) < 0.99:
				continue
			var saved: int = log_indices[triangle + 1]
			log_indices[triangle + 1] = log_indices[triangle + 2]
			log_indices[triangle + 2] = saved
			break
		reversed[Mesh.ARRAY_INDEX] = log_indices
		_expect(not _firewood_winding_matches(reversed),
			where + ": reversed cut-end negative escaped the winding check")
	for flame_index in range(3):
		var flame := heat.find_child("Flame_%d" % flame_index, true, false) as MeshInstance3D
		var flame_arrays: Array = flame.mesh.surface_get_arrays(0)
		var flame_vertices: PackedVector3Array = flame_arrays[Mesh.ARRAY_VERTEX]
		var flame_normals: PackedVector3Array = flame_arrays[Mesh.ARRAY_NORMAL]
		var flame_material := flame.material_override as StandardMaterial3D
		var volumetric: bool = flame.mesh.get_aabb().size.z > 0.025 \
			and flame.mesh.get_aabb().size.x > 0.025 \
			and flame_arrays[Mesh.ARRAY_INDEX].size() >= 100 \
			and flame_normals.size() == flame_vertices.size() \
			and flame_material != null \
			and flame_material.cull_mode != BaseMaterial3D.CULL_DISABLED \
			and flame.mesh.get_aabb().size.y < 0.30
		for triangle in range(0, flame_vertices.size(), 3):
			if triangle + 2 >= flame_vertices.size():
				break
			var geometric := (flame_vertices[triangle + 2] - flame_vertices[triangle]).cross(
				flame_vertices[triangle + 1] - flame_vertices[triangle]).normalized()
			if geometric.dot(flame_normals[triangle]) < 0.98:
				volumetric = false
		_expect(volumetric, where + ": flame still reads as a flat paper triangle")
	if tripod != null and support_ring != null and cooking_vessel != null:
		var ring_parent := support_ring.get_parent()
		var old_ring_y: float = support_ring.position.y
		ring_parent.remove_child(support_ring)
		_expect(not HouseAssembler._hearth_cooking_vessel_fits(heat,
			float(heat.get_meta("opening_sill_local_y")),
			float(heat.get_meta("opening_head_local_y")),
			float(metrics["width"]), float(metrics["depth"])),
			where + ": vessel support negative accepted a missing trivet ring")
		ring_parent.add_child(support_ring)
		support_ring.position.y = old_ring_y
		var old_vessel_position: Vector3 = cooking_vessel.position
		cooking_vessel.position.x += float(metrics["width"])
		_expect(not HouseAssembler._hearth_cooking_vessel_fits(heat,
			float(heat.get_meta("opening_sill_local_y")),
			float(heat.get_meta("opening_head_local_y")),
			float(metrics["width"]), float(metrics["depth"])),
			where + ": aperture negative accepted a pot moved outside the real jambs")
		cooking_vessel.position = old_vessel_position
		var old_pot_scale: Vector3 = cooking_vessel.scale
		cooking_vessel.scale.y *= 5.0
		_expect(not HouseAssembler._hearth_cooking_vessel_fits(heat,
			float(heat.get_meta("opening_sill_local_y")),
			float(heat.get_meta("opening_head_local_y")),
			float(metrics["width"]), float(metrics["depth"])),
			where + ": vessel headroom negative accepted a pot above the measured lintel")
		cooking_vessel.scale = old_pot_scale
	var saved_hearth_vessel: Dictionary = plan.hearth["cooking_vessel"].duplicate(true)
	plan.hearth.erase("cooking_vessel")
	var unplanned_assembly: Dictionary = HouseAssembler._domestic_hearth_assembly(
		anchor, placement, plan, builder)
	var unplanned_heat: Node3D = unplanned_assembly.get("heat") as Node3D
	_expect(unplanned_heat != null
		and unplanned_heat.find_child("HearthCookingVessel", true, false) == null
		and unplanned_heat.find_child("HearthIronTripod", true, false) == null,
		where + ": assembly invented a firebox vessel without a plan-owned record")
	if unplanned_heat != null:
		unplanned_heat.free()
	if unplanned_assembly.has("soot"):
		(unplanned_assembly["soot"] as Node3D).free()
	plan.hearth["cooking_vessel"] = saved_hearth_vessel
	var moved_log := heat.find_child("Firewood_0", true, false) as MeshInstance3D
	var original_log_position: Vector3 = moved_log.position
	moved_log.position.x += 0.40
	_expect(not HouseAssembler._heat_fits_measured_firebox(anchor, heat,
		float(metrics["sill"]), float(metrics["head"]),
		float(metrics["width"]), float(metrics["depth"])),
		where + ": measured-opening predicate accepted a log moved outside the real firebox")
	moved_log.position = original_log_position
	var removed_support := heat.find_child("Firewood_0", true, false) as MeshInstance3D
	heat.remove_child(removed_support)
	_expect(not HouseAssembler._heat_fits_measured_firebox(anchor, heat,
		float(metrics["sill"]), float(metrics["head"]),
		float(metrics["width"]), float(metrics["depth"])),
		where + ": measured-opening predicate accepted fire without its supporting log")
	heat.add_child(removed_support)
	var raised_base_log := heat.find_child("Firewood_0", true, false) as MeshInstance3D
	var original_base_log_position: Vector3 = raised_base_log.position
	raised_base_log.position.y += 0.012
	_expect(not HouseAssembler._heat_fits_measured_firebox(anchor, heat,
		float(metrics["sill"]), float(metrics["head"]),
		float(metrics["width"]), float(metrics["depth"])),
		where + ": measured-opening predicate accepted a split log lifted 12 mm off the fuel bed")
	raised_base_log.position = original_base_log_position
	var raised_top_log := heat.find_child("Firewood_1", true, false) as MeshInstance3D
	var original_top_log_position: Vector3 = raised_top_log.position
	raised_top_log.position.y += 0.08
	_expect(not HouseAssembler._heat_fits_measured_firebox(anchor, heat,
		float(metrics["sill"]), float(metrics["head"]),
		float(metrics["width"]), float(metrics["depth"])),
		where + ": measured-opening predicate accepted an unsupported crossed upper log")
	raised_top_log.position = original_top_log_position
	var flame_clearance := heat.find_child("Flame_1", true, false) as MeshInstance3D
	var original_flame_position: Vector3 = flame_clearance.position
	flame_clearance.position.x += float(metrics["width"]) * 0.5
	_expect(not HouseAssembler._heat_fits_measured_firebox(anchor, heat,
		float(metrics["sill"]), float(metrics["head"]),
		float(metrics["width"]), float(metrics["depth"])),
		where + ": measured-opening predicate accepted a flame beyond the aperture")
	flame_clearance.position = original_flame_position
	var fuel := heat.find_child("FuelBed", true, false) as MeshInstance3D
	var fuel_world: Vector3 = anchor.transform * heat.transform * fuel.position
	_expect(absf(fuel_world.y - (float(metrics["sill"]) + 0.035)) < 0.002,
		where + ": fuel bed is not measured from the actual firebox foot")
	var glow := heat.find_child("HearthWarmth", true, false) as OmniLight3D
	var glow_world: Vector3 = anchor.transform * heat.transform * glow.position
	_expect(absf(glow_world.y - float(metrics["center_y"])) < 0.002,
		where + ": warmth light is not at the actual firebox center height")
	var normal2: Vector2 = breast["normal"]
	var normal := Vector3(normal2.x, 0.0, normal2.y).normalized()
	var backing_depth: float = float(soot.get_meta("measured_backing_depth"))
	var backing: Vector3 = soot.position - normal * backing_depth * 0.5
	var backing_surface: int = int(soot.get_meta("measured_backing_surface"))
	var panel_y: float = soot.position.y
	_expect(backing_surface == HouseBuilder.SURF_WALL,
		where + ": firebox liner is not tied to the real host-wall surface")
	_expect(absf(panel_y - float(metrics["soot_y"])) < 0.002,
		where + ": smoke panel is not at its independently measured backing ray")
	var face := Vector3(breast["centre"].x, panel_y,
		breast["centre"].y) + normal * float(breast["depth"]) * 0.5
	var wall_hit: Variant = HouseQA._first_mesh_hit(builder.emitted_mesh,
		face + normal * 0.025, face - normal * (float(breast["depth"]) \
		+ HouseGeometry.wall_thickness(plan.spec) * 1.5))
	var soot_back_matches := false
	if wall_hit != null:
		var wall_hit_row: Dictionary = wall_hit
		var hit_point: Vector3 = wall_hit_row["point"]
		var wall: Dictionary = HouseGeometry.room_walls(plan, int(breast["room"]))[int(breast["wall"])]
		var wall_normal: Vector2 = wall["normal"]
		var wall_from: Vector2 = wall["from"]
		var wall_to: Vector2 = wall["to"]
		var hit_xz := Vector2(hit_point.x, hit_point.z)
		var host_plane_error: float = absf((hit_xz - wall_from).dot(wall_normal))
		var wall_axis := (wall_to - wall_from).normalized()
		var hit_along: float = (hit_xz - wall_from).dot(wall_axis)
		var wall_length: float = wall_from.distance_to(wall_to)
		soot_back_matches = int(wall_hit_row["surface"]) == backing_surface \
			and backing.distance_to(hit_point) < 0.002 \
			and host_plane_error <= 0.02 \
			and hit_along >= -0.02 and hit_along <= wall_length + 0.02 \
			and absf(wall_normal.dot(normal2)) > 0.999
	_expect(soot_back_matches,
		where + ": firebrick backing does not meet the actual host-wall triangle")
	var firebrick := soot.find_child("FirebrickRecessBack", true, false) as MeshInstance3D
	var firebrick_mesh := firebrick.mesh as BoxMesh
	var firebrick_depth: float = float(soot.get_meta("measured_backing_depth"))
	var firebrick_center_y: float = soot.position.y + firebrick.position.y
	var firebrick_bottom: float = firebrick_center_y - firebrick_mesh.size.y * 0.5
	var firebrick_top: float = firebrick_center_y + firebrick_mesh.size.y * 0.5
	var firebrick_fits_opening := absf(firebrick_mesh.size.x \
		- float(metrics["width"])) <= 0.002 \
		and absf(firebrick_bottom - float(metrics["sill"])) <= 0.002 \
		and absf(firebrick_top - float(metrics["head"])) <= 0.002
	var firebrick_depth_matches := absf(firebrick_mesh.size.z - firebrick_depth) <= 0.0000001
	var firebrick_roomward_offset: float = float(soot.get_meta("firebrick_roomward_offset", 0.0))
	var firebrick_roomward := absf(firebrick.position.z + firebrick_roomward_offset) <= 0.0001 \
		and firebrick_roomward_offset >= 0.059
	_expect(firebrick_fits_opening and firebrick_depth_matches and firebrick_roomward \
		and _firebrick_fills_measured_recess(firebrick_mesh, firebrick_center_y, metrics),
		where + ": firebrick recess lost measured bounds, depth, or roomward offset")
	var lower_band_y: float = float(metrics["sill"]) + 0.18
	var strip_face := Vector3(breast["centre"].x, lower_band_y, breast["centre"].y) \
		+ normal * float(breast["depth"]) * 0.5
	var strip_hit: Variant = HouseQA._first_mesh_hit(builder.emitted_mesh,
		strip_face + normal * 0.025,
		strip_face - normal * (float(breast["depth"]) + HouseGeometry.wall_thickness(plan.spec) * 1.5))
	var strip_surface := -1
	if strip_hit != null:
		strip_surface = int((strip_hit as Dictionary)["surface"])
	var strip_clearance := _firebrick_clears_actual_shell_band(firebrick, strip_hit, normal, lower_band_y)
	_expect(strip_hit != null and strip_surface >= 0 and strip_clearance >= 0.005,
		where + ": firebrick does not clear the actual lower shell face behind the mouth")
	var original_firebrick_position: Vector3 = firebrick.position
	firebrick.position.z = 0.0
	var unshifted_clearance := _firebrick_clears_actual_shell_band(firebrick, strip_hit, normal, lower_band_y)
	print("HEARTH_STRIP_CLEARANCE where=", where, " surface=", strip_surface,
		" shell_point=", (strip_hit as Dictionary)["point"] if strip_hit != null else Vector3.ZERO,
		" offset_m=", firebrick_roomward_offset, " shifted_m=", strip_clearance,
		" unshifted_m=", unshifted_clearance)
	if spec.stone_ground_floor:
		_expect(unshifted_clearance < 0.005,
			where + ": unshifted-back-panel negative unexpectedly clears the stone lower shell face")
	firebrick.position = original_firebrick_position
	var original_firebrick_size: Vector3 = firebrick_mesh.size
	firebrick_mesh.size.x -= 0.04
	_expect(not _firebrick_fills_measured_recess(firebrick_mesh, firebrick_center_y, metrics),
		where + ": backing-width negative accepted an exposed host-wall strip")
	firebrick_mesh.size = original_firebrick_size
	firebrick_mesh.size.y -= 0.04
	_expect(not _firebrick_fills_measured_recess(firebrick_mesh, firebrick_center_y, metrics),
		where + ": backing-height negative accepted an exposed sill or head strip")
	firebrick_mesh.size = original_firebrick_size
	var soot_face := soot.find_child("SootedFireboxBack", true, false) as MeshInstance3D
	var soot_bounds: AABB = soot_face.mesh.get_aabb()
	var panel_fits_width := soot_bounds.size.x < float(metrics["width"])
	var panel_has_height := soot_bounds.size.y > 0.0
	var soot_mesh_is_irregular: bool = soot_face.mesh is ArrayMesh \
		and soot_face.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() >= 29
	var soot_arrays: Array = soot_face.mesh.surface_get_arrays(0) \
		if soot_face.mesh is ArrayMesh else []
	var soot_colours: PackedColorArray = soot_arrays[Mesh.ARRAY_COLOR] \
		if soot_arrays.size() > Mesh.ARRAY_COLOR else PackedColorArray()
	var smoke_has_alpha_gradient := soot_colours.size() >= 29 \
		and soot_colours[soot_colours.size() - 2].a == 0.0 \
		and soot_colours[0].a > soot_colours[soot_colours.size() - 2].a
	var smoke_stays_on_firebrick := soot_face.position.z < -firebrick_mesh.size.z * 0.5 - firebrick_roomward_offset \
		and soot_face.position.z > -firebrick_mesh.size.z * 0.5 - firebrick_roomward_offset - 0.01
	var smoke_world_point: Vector3 = soot.global_transform * soot_face.position
	var expected_smoke_point: Vector3 = backing + normal * (firebrick_depth + 0.003 + firebrick_roomward_offset)
	var smoke_faces_room_side: bool = smoke_world_point.distance_to(expected_smoke_point) < 0.002
	_expect(panel_fits_width and panel_has_height and soot_mesh_is_irregular \
		and smoke_has_alpha_gradient and smoke_stays_on_firebrick \
		and smoke_faces_room_side,
		where + ": soot lacks a feathered smoke profile attached to the measured firebrick backing")
	var mortar_joints := 0
	for child in firebrick.get_children():
		if String(child.name).begins_with("FirebrickBedJoint_") \
				or String(child.name).begins_with("FirebrickHeadJoint_"):
			mortar_joints += 1
	var mortar_faces_room_side := true
	for child in firebrick.get_children():
		if String(child.name).begins_with("FirebrickBedJoint_") \
				or String(child.name).begins_with("FirebrickHeadJoint_"):
			mortar_faces_room_side = mortar_faces_room_side and child.position.z < -firebrick_depth * 0.5
	_expect(mortar_joints >= 8 and mortar_faces_room_side,
		where + ": firebrick recess lacks room-facing, measured bed/head joints")
	var ember_bed := heat.find_child("FuelBed", true, false) as MeshInstance3D
	var log0 := heat.find_child("Firewood_0", true, false) as MeshInstance3D
	var flame0 := heat.find_child("Flame_0", true, false) as MeshInstance3D
	var flame1 := heat.find_child("Flame_1", true, false) as MeshInstance3D
	var flame2 := heat.find_child("Flame_2", true, false) as MeshInstance3D
	var readable_fuel := ember_bed.mesh.get_aabb().size.x >= float(metrics["width"]) * 0.45 \
		and ember_bed.mesh.get_aabb().size.z >= float(metrics["depth"]) * 0.45
	var log_bounds: AABB = log0.mesh.get_aabb()
	var log_arrays: Array = log0.mesh.surface_get_arrays(0) if log0.mesh is ArrayMesh else []
	var log_colours: PackedColorArray = log_arrays[Mesh.ARRAY_COLOR] \
		if log_arrays.size() > Mesh.ARRAY_COLOR else PackedColorArray()
	var log_vertices: PackedVector3Array = log_arrays[Mesh.ARRAY_VERTEX] \
		if log_arrays.size() > Mesh.ARRAY_VERTEX else PackedVector3Array()
	var log_normals: PackedVector3Array = log_arrays[Mesh.ARRAY_NORMAL] \
		if log_arrays.size() > Mesh.ARRAY_NORMAL else PackedVector3Array()
	var log_side_faces_outward := log_normals.size() == log_vertices.size() \
		and log_vertices.size() >= 48
	for triangle_start in range(0, 48, 3):
		var a: Vector3 = log_vertices[triangle_start]
		var b: Vector3 = log_vertices[triangle_start + 1]
		var c: Vector3 = log_vertices[triangle_start + 2]
		var godot_normal := (c - a).cross(b - a).normalized()
		var centroid := (a + b + c) / 3.0
		var expected_outward := Vector3(0.0, centroid.y, centroid.z).normalized()
		if godot_normal.dot(expected_outward) < 0.70 \
				or godot_normal.dot(log_normals[triangle_start]) < 0.98:
			log_side_faces_outward = false
	var wood_material := log0.material_override as StandardMaterial3D
	var distinct_log_colours: Array[Color] = []
	for colour in log_colours:
		if not distinct_log_colours.has(colour):
			distinct_log_colours.append(colour)
	var dark_bark := false
	var pale_cut_face := false
	for colour: Color in log_colours:
		var lightness := colour.get_luminance()
		dark_bark = dark_bark or lightness < 0.10
		pale_cut_face = pale_cut_face or lightness > 0.20
	var readable_log := log0.mesh is ArrayMesh \
		and log_bounds.size.x >= float(metrics["width"]) * 0.55 \
		and distinct_log_colours.size() >= 4 \
		and log_side_faces_outward and dark_bark and pale_cut_face \
		and wood_material != null and wood_material.cull_mode != BaseMaterial3D.CULL_DISABLED
	var flame0_bounds: AABB = flame0.mesh.get_aabb()
	var flame1_bounds: AABB = flame1.mesh.get_aabb()
	var flame2_bounds: AABB = flame2.mesh.get_aabb()
	var readable_flames := flame0_bounds.size.y >= 0.15 \
		and flame1_bounds.size.y >= 0.15 and flame2_bounds.size.y >= 0.15 \
		and flame0_bounds.size.x >= float(metrics["width"]) * 0.12 \
		and flame1_bounds.size.x >= float(metrics["width"]) * 0.12 \
		and flame2_bounds.size.x >= float(metrics["width"]) * 0.12 \
		and flame0_bounds.size.z >= float(metrics["depth"]) * 0.20 \
		and flame1_bounds.size.z >= float(metrics["depth"]) * 0.20 \
		and flame2_bounds.size.z >= float(metrics["depth"]) * 0.20
	var flame_shapes_distinct := absf(flame0_bounds.size.y - flame1_bounds.size.y) >= 0.04 \
		and absf(flame1_bounds.size.y - flame2_bounds.size.y) >= 0.04
	var flame_arrays: Array = flame0.mesh.surface_get_arrays(0)
	var flame_colours: PackedColorArray = flame_arrays[Mesh.ARRAY_COLOR] \
		if flame_arrays.size() > Mesh.ARRAY_COLOR else PackedColorArray()
	var distinct_flame_colours: Array[Color] = []
	for colour in flame_colours:
		if not distinct_flame_colours.has(colour):
			distinct_flame_colours.append(colour)
	var flame_has_volume_gradient := flame_colours.size() >= 24 \
		and distinct_flame_colours.size() >= 4
	var scale_note := " fuel=%.3fx%.3f log=%.3f flame=%.3fx%.3f" % [
		ember_bed.mesh.get_aabb().size.x, ember_bed.mesh.get_aabb().size.z,
		log_bounds.size.x, flame1_bounds.size.x, flame1_bounds.size.y]
	_expect(readable_fuel and readable_log and readable_flames \
		and flame_shapes_distinct and flame_has_volume_gradient,
		where + ": measured fire bed, crossed logs or volumetric flame cluster is undersized" + scale_note)
	_expect(heat.find_child("CollisionShape3D", true, false) == null,
		where + ": decorative fire cue added an unplanned collision body")
	_check_old_cauldron_blocks_firebox_sightline(anchor, heat, breast, metrics, where)
	var missing_lintel_index := -1
	for row_index in range(builder.component_log.size()):
		if String(builder.component_log[row_index].get("role", "")) == "hearth_lintel" \
				and String(builder.component_log[row_index].get("host", "")) == "hearth":
			missing_lintel_index = row_index
			break
	if missing_lintel_index >= 0:
		var removed_row: Dictionary = builder.component_log.pop_at(missing_lintel_index)
		_expect(HouseAssembler._domestic_hearth_assembly(anchor,
			placement, plan, builder).is_empty(),
			where + ": heat assembly accepted a log with no emitted lintel")
		builder.component_log.insert(missing_lintel_index, removed_row)
	else:
		_fail(where + ": cannot select actual lintel for fail-closed assembly control")
	for role in ["hearth_breast_left", "hearth_breast_right",
			"hearth_breast_foot", "hearth_lintel", "hearth_jamb"]:
		_check_removed_component_mesh_control(anchor, placement, plan,
			builder, role, where)
	_check_removed_backing_mesh_control(anchor, placement, plan,
		builder, breast, metrics, soot.position.y, where)
	scene_root.free()


func _emitted_breast_metrics(builder: HouseBuilder) -> Dictionary:
	var left: Dictionary = {}
	var right: Dictionary = {}
	for row: Dictionary in builder.component_log:
		if String(row.get("host", "")) != "hearth":
			continue
		match String(row.get("role", "")):
			"hearth_breast_left":
				left = row
			"hearth_breast_right":
				right = row
	if left.is_empty() or right.is_empty():
		return {}
	var left_xf: Transform3D = left["xf"]
	var right_xf: Transform3D = right["xf"]
	var tangent: Vector3 = left_xf.basis.x.normalized()
	var left_size: Vector3 = left["size"]
	var right_size: Vector3 = right["size"]
	var left_center: float = left_xf.origin.dot(tangent)
	var right_center: float = right_xf.origin.dot(tangent)
	var outer_min: float = minf(left_center - left_size.x * 0.5,
		right_center - right_size.x * 0.5)
	var outer_max: float = maxf(left_center + left_size.x * 0.5,
		right_center + right_size.x * 0.5)
	return {"width": outer_max - outer_min,
		"depth": minf(left_size.z, right_size.z)}


func _aabb_in_space(mesh_node: MeshInstance3D, space: Node3D) -> AABB:
	var relative: Transform3D = space.global_transform.affine_inverse() \
		* mesh_node.global_transform
	return _transformed_aabb(mesh_node.mesh.get_aabb(), relative)


func _flame_apex_in_space(flame: MeshInstance3D, space: Node3D) -> Vector3:
	var arrays: Array = flame.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return Vector3.ZERO
	var apex := vertices[0]
	for vertex in vertices:
		if vertex.y > apex.y:
			apex = vertex
	var relative: Transform3D = space.global_transform.affine_inverse() \
		* flame.global_transform
	return relative * apex


func _transformed_aabb(bounds: AABB, transform: Transform3D) -> AABB:
	var first := true
	var result := AABB()
	for x in [bounds.position.x, bounds.end.x]:
		for y in [bounds.position.y, bounds.end.y]:
			for z in [bounds.position.z, bounds.end.z]:
				var point: Vector3 = transform * Vector3(x, y, z)
				if first:
					result = AABB(point, Vector3.ZERO)
					first = false
				else:
					result = result.expand(point)
	return result


func _check_cooking_vessel(vessel: Node3D, heat: Node3D, sill: float,
		head: float, clear_width: float, recess_depth: float, where: String) -> void:
	var meshes: Array = vessel.find_children("*", "MeshInstance3D", true, false)
	var valid_materials := not meshes.is_empty()
	var has_bounds := false
	var model_bounds := AABB()
	for mesh_variant in meshes:
		var mesh_node := mesh_variant as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			valid_materials = false
			continue
		var material := mesh_node.material_override as StandardMaterial3D
		valid_materials = valid_materials and material != null \
			and maxf(material.albedo_color.r,
				maxf(material.albedo_color.g, material.albedo_color.b)) < 0.20
		var bounds: AABB = _aabb_in_space(mesh_node, heat)
		if not has_bounds:
			model_bounds = bounds
			has_bounds = true
		else:
			model_bounds = model_bounds.merge(bounds)
	var sill_local: float = float(heat.get_meta("opening_sill_local_y"))
	var head_local: float = float(heat.get_meta("opening_head_local_y"))
	var fits: bool = has_bounds \
		and model_bounds.position.x >= -clear_width * 0.5 + 0.015 \
		and model_bounds.end.x <= clear_width * 0.5 - 0.015 \
		and model_bounds.position.z >= -recess_depth * 0.5 + 0.015 \
		and model_bounds.end.z <= recess_depth * 0.5 - 0.015 \
		and model_bounds.position.y >= sill_local + 0.015 \
		and model_bounds.end.y <= head_local - 0.015
	_expect(valid_materials, where + ": Pot_1 actual mesh surfaces lack the dark iron finish")
	_expect(fits and model_bounds.position.y + heat.position.y >= sill + 0.015 \
		and model_bounds.end.y + heat.position.y <= head - 0.015,
		where + ": actual Pot_1 mesh bounds exceed measured mouth or cheek clearance")


func _check_hearth_finish(anchor: Node3D, builder: HouseBuilder,
		breast_metrics: Dictionary,
		metrics: Dictionary, spec: HouseSpec,
		where: String) -> void:
	var finish := anchor.find_child("DomesticHearthStoneFinish", true, false) as Node3D
	if finish == null:
		_fail(where + ": missing stone finish attached to the measured breast")
		return
	var tiles: Array = []
	for mesh_variant in finish.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := mesh_variant as MeshInstance3D
		if mesh_node != null and mesh_node.has_meta("hearth_stone_tile"):
			tiles.append(mesh_node)
	_expect(_hearth_finish_bounds_fit(tiles, anchor, breast_metrics,
		metrics, spec), where + ": stone finish leaves breast bounds or intrudes into the mouth")
	var darker_masonry := not tiles.is_empty()
	for tile_variant in tiles:
		var tile := tile_variant as MeshInstance3D
		var material := tile.material_override as StandardMaterial3D
		if material == null or material.albedo_color.r <= material.albedo_color.b \
				or (material.albedo_color.r + material.albedo_color.g \
				+ material.albedo_color.b) / 3.0 >= 0.22:
			darker_masonry = false
	_expect(darker_masonry, where + ": hearth stone is not a warm, dark masonry finish")
	var reveal_nodes := finish.find_children("HearthDarkReveal*", "MeshInstance3D", true, false)
	_expect(reveal_nodes.size() == 3,
		where + ": firebox lacks paired dark cheek reveals and sill treatment")
	_expect(_hearth_reveals_fit(reveal_nodes, anchor, breast_metrics, metrics),
		where + ": dark reveal finish misses the backing plane or narrows the measured firebox opening")
	var firebox_floor := finish.find_child("HearthRefractoryFloor", true, false) as MeshInstance3D
	if firebox_floor == null:
		_fail(where + ": structural sill top remains uncovered by a refractory floor")
	else:
		var floor_bounds: AABB = _aabb_in_space(firebox_floor, anchor)
		var fuel: MeshInstance3D = anchor.find_child("FuelBed", true, false) as MeshInstance3D
		var fuel_bounds := _aabb_in_space(fuel, anchor) if fuel != null else AABB()
		var expected_front: float = -float(breast_metrics["depth"]) * 0.5 - 0.012
		var expected_back: float = float(breast_metrics["depth"]) * 0.5
		_expect(absf(floor_bounds.position.x + float(metrics["width"]) * 0.5) <= 0.003 \
			and absf(floor_bounds.end.x - float(metrics["width"]) * 0.5) <= 0.003 \
			and absf(floor_bounds.position.y - float(metrics["sill"])) <= 0.002 \
			and absf(floor_bounds.end.y - (float(metrics["sill"]) + 0.024)) <= 0.002 \
			and absf(floor_bounds.position.z - expected_front) <= 0.003 \
			and absf(floor_bounds.end.z - expected_back) <= 0.003,
			where + ": refractory floor misses the measured sill or extends outside the firebox")
		_expect(fuel != null and absf(floor_bounds.end.y - fuel_bounds.position.y) <= 0.003,
			where + ": refractory floor does not meet the actual fuel-bed underside")
	if reveal_nodes.size() >= 2:
		var moved_reveal := reveal_nodes[0] as MeshInstance3D
		var old_reveal_x: float = moved_reveal.position.x
		if old_reveal_x > 0.0:
			moved_reveal.position.x -= 0.02
		else:
			moved_reveal.position.x += 0.02
		_expect(not _hearth_reveals_fit(reveal_nodes, anchor, breast_metrics, metrics),
			where + ": reveal intrusion negative accepted finish inside the clear aperture")
		moved_reveal.position.x = old_reveal_x
		moved_reveal.position.x += signf(old_reveal_x) * 0.002
		_expect(not _hearth_reveals_fit(reveal_nodes, anchor, breast_metrics, metrics),
			where + ": coplanar cheek finish escaped the actual surface-separation check")
		moved_reveal.position.x = old_reveal_x
		var reveal_mesh := moved_reveal.mesh as BoxMesh
		var old_depth: float = reveal_mesh.size.z
		reveal_mesh.size.z -= 0.12
		_expect(not _hearth_reveals_fit(reveal_nodes, anchor, breast_metrics, metrics),
			where + ": truncated reveal negative accepted a gap before the backing plane")
		reveal_mesh.size.z = old_depth
	var mortar_nodes := finish.find_children("HearthStoneMortar_*",
		"MeshInstance3D", true, false)
	var dark_mortar := not mortar_nodes.is_empty()
	for mortar_variant in mortar_nodes:
		var mortar := mortar_variant as MeshInstance3D
		var mortar_material := mortar.material_override as StandardMaterial3D
		if mortar_material == null or (mortar_material.albedo_color.r \
				+ mortar_material.albedo_color.g + mortar_material.albedo_color.b) / 3.0 >= 0.10:
			dark_mortar = false
	_expect(dark_mortar,
		where + ": stone courses have no dark mortar backing in their joints")
	_check_front_face_overlays(anchor, builder, metrics, where)
	_check_wood_mantel(anchor, builder, breast_metrics, metrics, where)
	if tiles.is_empty():
		return
	var tile := tiles[0] as MeshInstance3D
	var old_position: Vector3 = tile.position
	tile.position = Vector3(0.0,
		(float(metrics["sill"]) + float(metrics["head"])) * 0.5, 0.0)
	_expect(not _hearth_finish_bounds_fit(tiles, anchor, breast_metrics,
		metrics, spec),
		where + ": finish intrusion negative accepted a stone tile inside the clear mouth")
	tile.position = old_position


func _firebrick_clears_actual_shell_band(firebrick: MeshInstance3D, shell_hit: Variant,
		normal: Vector3, sample_y: float) -> float:
	if firebrick == null or shell_hit == null or not firebrick.mesh is BoxMesh:
		return -INF
	var panel := firebrick.mesh as BoxMesh
	var local_y: float = sample_y - firebrick.global_position.y
	var room_face: Vector3 = firebrick.global_transform \
		* Vector3(0.0, local_y, -panel.size.z * 0.5)
	var hit_row: Dictionary = shell_hit
	var shell_point: Vector3 = hit_row["point"]
	return (room_face - shell_point).dot(normal)


func _firebrick_fills_measured_recess(mesh: BoxMesh, center_y: float,
		metrics: Dictionary) -> bool:
	if mesh == null:
		return false
	var sill: float = float(metrics["sill"])
	var head: float = float(metrics["head"])
	var clear_width: float = float(metrics["width"])
	var opening_height: float = head - sill
	var bottom: float = center_y - mesh.size.y * 0.5
	var top: float = center_y + mesh.size.y * 0.5
	return absf(mesh.size.x - clear_width) <= 0.002 \
		and absf(mesh.size.y - opening_height) <= 0.002 \
		and absf(bottom - sill) <= 0.002 \
		and absf(top - head) <= 0.002


func _hearth_reveals_fit(reveals: Array, anchor: Node3D,
		breast_metrics: Dictionary, metrics: Dictionary) -> bool:
	if reveals.size() != 3:
		return false
	var clear_width: float = float(metrics["width"])
	var sill: float = float(metrics["sill"])
	var head: float = float(metrics["head"])
	var breast_depth: float = float(breast_metrics["depth"])
	var expected_back: float = breast_depth * 0.5
	var expected_front: float = -breast_depth * 0.5 - 0.012
	var cheek_count: int = 0
	var sill_count: int = 0
	for reveal_variant in reveals:
		var reveal := reveal_variant as MeshInstance3D
		if reveal == null or reveal.mesh == null:
			return false
		var bounds: AABB = _aabb_in_space(reveal, anchor)
		if bounds.position.y < sill - 0.003 or bounds.end.y > head + 0.003:
			return false
		if absf(bounds.position.z - expected_front) > 0.003 \
				or absf(bounds.end.z - expected_back) > 0.003:
			return false
		if reveal.name == "HearthDarkRevealSill":
			sill_count += 1
			if absf(bounds.position.x + clear_width * 0.5) > 0.003 \
					or absf(bounds.end.x - clear_width * 0.5) > 0.003 \
					or bounds.end.y > sill + 0.003:
				return false
		else:
			cheek_count += 1
			var inner_x := bounds.position.x if bounds.get_center().x > 0.0 else bounds.end.x
			var face_separation := clear_width * 0.5 - absf(inner_x)
			if face_separation < 0.0015 or face_separation > 0.003:
				return false
	return cheek_count == 2 and sill_count == 1


func _check_wood_mantel(anchor: Node3D, builder: HouseBuilder,
		breast_metrics: Dictionary, metrics: Dictionary, where: String) -> void:
	var mantel := anchor.find_child("DomesticHearthWoodMantel", true, false) as Node3D
	if mantel == null:
		_fail(where + ": missing separate wood mantel assembly")
		return
	var shelf := mantel.find_child("WoodMantelShelf", true, false) as MeshInstance3D
	var corbels: Array = mantel.find_children("WoodMantelCorbel*", "MeshInstance3D", true, false)
	if shelf == null or corbels.size() != 2:
		_fail(where + ": mantel lacks its shelf and paired corbel supports")
		return
	var shelf_bounds: AABB = _aabb_in_space(shelf, anchor)
	var shelf_mesh := shelf.mesh as BoxMesh
	var shelf_material := shelf.material_override as StandardMaterial3D
	var shelf_bottom: float = float(mantel.get_meta("shelf_bottom", -INF))
	var support_datum: float = float(mantel.get_meta("support_datum", INF))
	var opening_head: float = float(metrics["head"])
	var valid := shelf_material != null \
		and shelf_material.albedo_color.r > shelf_material.albedo_color.g \
		and shelf_mesh != null and shelf_mesh.size.y >= 0.17 \
		and shelf_mesh.size.z >= 0.30 \
		and shelf_bounds.position.y >= opening_head + 0.12 \
		and shelf_bounds.position.y <= support_datum + 0.075 \
		and absf(shelf_bounds.position.y - shelf_bottom) <= 0.003 \
		and shelf_bounds.position.z <= -float(breast_metrics["depth"]) * 0.5 - 0.30 \
		and absf(shelf_bounds.end.z + float(breast_metrics["depth"]) * 0.5) <= 0.003 \
		and shelf_bounds.position.x >= -float(breast_metrics["width"]) * 0.5 - 0.003 \
		and shelf_bounds.end.x <= float(breast_metrics["width"]) * 0.5 + 0.003
	var lintel_triangles := _actual_lintel_triangles(builder)
	for corbel_variant in corbels:
		var corbel := corbel_variant as MeshInstance3D
		var bounds: AABB = _aabb_in_space(corbel, anchor)
		var center: Vector3 = corbel.global_position
		valid = valid and absf(bounds.position.y - support_datum) <= 0.003 \
			and absf(bounds.end.y - shelf_bottom) <= 0.003 \
			and MeshProbe.has_upward_support(lintel_triangles,
				Vector2(center.x, center.z), support_datum, 0.02)
	_expect(valid, where + ": wood mantel is not supported on actual lintel triangles or escapes its measured surround")
	var old_shelf_position: Vector3 = shelf.position
	shelf.position.y += 0.03
	_expect(not _wood_mantel_stack_valid(mantel, anchor, breast_metrics,
		metrics, builder), where + ": shelf-lift negative accepted a disconnected mantel")
	shelf.position = old_shelf_position
	shelf.position.z += 0.08
	_expect(not _wood_mantel_stack_valid(mantel, anchor, breast_metrics,
		metrics, builder), where + ": wall-gap negative accepted an unhosted mantel")
	shelf.position = old_shelf_position
	var saved_parent: Node = corbels[0].get_parent()
	saved_parent.remove_child(corbels[0])
	_expect(not _wood_mantel_stack_valid(mantel, anchor, breast_metrics,
		metrics, builder), where + ": removed-corbel negative accepted a one-sided mantel")
	saved_parent.add_child(corbels[0])
	for row in builder.component_log:
		if String(row.get("role", "")) != "hearth_lintel" or String(row.get("host", "")) != "hearth":
			continue
		var source := builder.emitted_mesh
		var bounds: AABB = Transform3D(row["xf"]) * AABB(-Vector3(row["size"]) * 0.5, row["size"])
		var rect := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
		var surface := HouseQA._logical_mesh_surface(source, int(row["surface"]))
		var removed := MeshProbe.remove_triangles(source, surface,
			MeshProbe.top_face_in(rect, bounds.end.y))
		builder.emitted_mesh = removed["mesh"]
		_expect(not _wood_mantel_stack_valid(mantel, anchor, breast_metrics, metrics, builder),
			where + ": deleted actual lintel support escaped the mantel check")
		builder.emitted_mesh = source
		break


func _actual_lintel_triangles(builder: HouseBuilder) -> Array:
	# Stone lintels belong to the wall material; legacy timber lintels use
	# trim. Read the actual owning surface rather than assuming its finish.
	for row in builder.component_log:
		if String(row.get("role", "")) == "hearth_lintel" and String(row.get("host", "")) == "hearth":
			var surface := HouseQA._logical_mesh_surface(builder.emitted_mesh, int(row["surface"]))
			return MeshProbe.surface_triangles(null, builder.emitted_mesh, surface) if surface >= 0 else []
	return []


func _check_front_face_overlays(anchor: Node3D, builder: HouseBuilder,
		metrics: Dictionary, where: String) -> void:
	var finish := anchor.find_child("DomesticHearthStoneFinish", true, false) as Node3D
	if finish == null:
		_fail(where + ": missing front-face stone overlay host")
		return
	var overlays: Array = finish.find_children("HearthFrontStone*", "MeshInstance3D", true, false)
	var jamb_rows: Array[Dictionary] = []
	var lintel: Dictionary = {}
	for row: Dictionary in builder.component_log:
		if String(row.get("host", "")) != "hearth":
			continue
		match String(row.get("role", "")):
			"hearth_jamb": jamb_rows.append(row)
			"hearth_lintel": lintel = row
	var valid: bool = overlays.size() == 3 and jamb_rows.size() == 2 \
		and not lintel.is_empty()
	for overlay_variant in overlays:
		var overlay := overlay_variant as MeshInstance3D
		if overlay == null or overlay.mesh == null or overlay.material_override == null:
			valid = false
			continue
		var role_row: Dictionary = lintel if overlay.name == "HearthFrontStoneLintel" else {}
		if role_row.is_empty():
			var overlay_center: Vector3 = anchor.global_transform.affine_inverse() \
				* overlay.global_transform.origin
			var closest: float = INF
			for candidate: Dictionary in jamb_rows:
				var candidate_xf: Transform3D = candidate["xf"]
				var local_center: Vector3 = anchor.global_transform.affine_inverse() \
					* candidate_xf.origin
				var distance: float = absf(local_center.x - overlay_center.x)
				if distance < closest:
					closest = distance
					role_row = candidate
		if role_row.is_empty():
			valid = false
			continue
		var component_size: Vector3 = role_row["size"]
		var component_xf: Transform3D = role_row["xf"]
		var relative_xf: Transform3D = anchor.global_transform.affine_inverse() * component_xf
		var expected := _transformed_aabb(AABB(-component_size * 0.5, component_size), relative_xf)
		var actual: AABB = _aabb_in_space(overlay, anchor)
		valid = valid and absf(actual.position.x - expected.position.x) <= 0.003 \
			and absf(actual.end.x - expected.end.x) <= 0.003 \
			and absf(actual.position.y - expected.position.y) <= 0.003 \
			and absf(actual.end.y - expected.end.y) <= 0.003 \
			and actual.end.z <= expected.position.z + 0.003 \
			and actual.end.z >= expected.position.z - 0.006
		if overlay.name == "HearthFrontStoneLintel":
			valid = valid and actual.position.y >= float(metrics["head"]) - 0.003
		else:
			var clear_width: float = float(metrics["width"])
			valid = valid and (actual.position.x >= clear_width * 0.5 - 0.003 \
				or actual.end.x <= -clear_width * 0.5 + 0.003)
	_expect(valid, where + ": warm stone front overlays miss measured jamb/head faces or enter the aperture")
	var lintel_overlay := finish.find_child("HearthFrontStoneLintel", true, false) as MeshInstance3D
	if lintel_overlay != null:
		var old_position: Vector3 = lintel_overlay.position
		lintel_overlay.position.y -= 0.30
		_expect(not _front_face_overlays_valid(anchor, builder, metrics),
			where + ": moved-lintel-overlay negative accepted a head strip inside the opening")
		lintel_overlay.position = old_position


func _front_face_overlays_valid(anchor: Node3D, builder: HouseBuilder,
		metrics: Dictionary) -> bool:
	var finish := anchor.find_child("DomesticHearthStoneFinish", true, false) as Node3D
	if finish == null:
		return false
	var overlays: Array = finish.find_children("HearthFrontStone*", "MeshInstance3D", true, false)
	if overlays.size() != 3:
		return false
	var head: float = float(metrics["head"])
	for overlay_variant in overlays:
		var overlay := overlay_variant as MeshInstance3D
		if overlay == null:
			return false
		if overlay.name == "HearthFrontStoneLintel" \
				and _aabb_in_space(overlay, anchor).position.y < head - 0.003:
			return false
	return true


func _wood_mantel_stack_valid(mantel: Node3D, anchor: Node3D,
		breast_metrics: Dictionary, metrics: Dictionary, builder: HouseBuilder) -> bool:
	var shelf := mantel.find_child("WoodMantelShelf", true, false) as MeshInstance3D
	var corbels: Array = mantel.find_children("WoodMantelCorbel*", "MeshInstance3D", true, false)
	if shelf == null or corbels.size() != 2:
		return false
	var shelf_bounds: AABB = _aabb_in_space(shelf, anchor)
	var shelf_bottom: float = float(mantel.get_meta("shelf_bottom", -INF))
	var support_datum: float = float(mantel.get_meta("support_datum", INF))
	var lintel_triangles := _actual_lintel_triangles(builder)
	if absf(shelf_bounds.position.y - shelf_bottom) > 0.003 \
			or shelf_bounds.position.y < float(metrics["head"]) + 0.12 \
			or shelf_bounds.position.y > support_datum + 0.075 \
			or shelf_bounds.position.z > -float(breast_metrics["depth"]) * 0.5 - 0.30 \
			or absf(shelf_bounds.end.z + float(breast_metrics["depth"]) * 0.5) > 0.003 \
			or shelf_bounds.position.x < -float(breast_metrics["width"]) * 0.5 - 0.003 \
			or shelf_bounds.end.x > float(breast_metrics["width"]) * 0.5 + 0.003:
		return false
	for corbel_variant in corbels:
		var corbel := corbel_variant as MeshInstance3D
		var bounds: AABB = _aabb_in_space(corbel, anchor)
		var center: Vector3 = corbel.global_position
		if absf(bounds.position.y - support_datum) > 0.003 \
				or absf(bounds.end.y - shelf_bottom) > 0.003 \
				or not MeshProbe.has_upward_support(lintel_triangles,
					Vector2(center.x, center.z), support_datum, 0.02):
			return false
	return true


func _hearth_finish_bounds_fit(tiles: Array, anchor: Node3D,
		breast_metrics: Dictionary, metrics: Dictionary, spec: HouseSpec) -> bool:
	if tiles.is_empty():
		return false
	var width: float = float(breast_metrics["width"])
	var depth: float = float(breast_metrics["depth"])
	var clear_width: float = float(metrics["width"])
	var sill: float = float(metrics["sill"])
	var head: float = float(metrics["head"])
	for tile_variant in tiles:
		var tile := tile_variant as MeshInstance3D
		if tile == null or tile.mesh == null:
			return false
		var bounds: AABB = _aabb_in_space(tile, anchor)
		if bounds.position.x < -width * 0.5 - 0.002 \
				or bounds.end.x > width * 0.5 + 0.002 \
				or bounds.position.y < -0.002 \
				or bounds.end.y > spec.height + 0.002 \
				or bounds.position.z < -depth * 0.5 - 0.026 \
				or bounds.end.z > -depth * 0.5 + 0.002:
			return false
		var overlaps_opening_x: bool = bounds.position.x < clear_width * 0.5 \
			and bounds.end.x > -clear_width * 0.5
		var overlaps_opening_y: bool = bounds.position.y < head \
			and bounds.end.y > sill
		if overlaps_opening_x and overlaps_opening_y:
			return false
	return true


func _check_firebox_bounds(host: Node3D, heat: Node3D,
		sill: float, head: float, clear_width: float, recess_depth: float,
		where: String) -> void:
	var fuel := heat.find_child("FuelBed", true, false) as MeshInstance3D
	if fuel == null or not fuel.mesh is BoxMesh:
		_fail(where + ": missing actual floor-supported fuel bed")
		return
	var fuel_mesh := fuel.mesh as BoxMesh
	var fuel_world := host.global_transform * heat.transform * fuel.position
	var fuel_bottom := fuel_world.y - fuel_mesh.size.y * 0.5
	_expect(fuel_bottom >= sill - 0.015 and fuel_bottom <= sill + 0.025,
		where + ": fuel is below the real sill or floats above it")
	var support_log := heat.find_child("Firewood_0", true, false) as MeshInstance3D
	if support_log == null or not support_log.mesh is ArrayMesh:
		_fail(where + ": missing low-poly log support for flame cluster")
		return
	var support_log_bounds: AABB = support_log.mesh.get_aabb()
	var support_log_world := host.global_transform * heat.transform * support_log.position
	var log_top_world: float = support_log_world.y + support_log_bounds.end.y
	var fuel_top_origin := host.global_transform * heat.transform * fuel.position
	var fuel_top_world: float = fuel_top_origin.y + fuel.mesh.get_aabb().end.y
	_expect(absf(support_log_world.y + support_log_bounds.position.y - fuel_top_world) <= 0.006,
		where + ": split logs do not rest on the measured fuel bed")
	for index in range(2):
		var log := heat.find_child("Firewood_%d" % index, true, false) as MeshInstance3D
		if log == null or not log.mesh is ArrayMesh:
			_fail(where + ": missing actual split low-poly log")
			continue
		var log_bounds: AABB = log.mesh.get_aabb()
		var log_world := host.global_transform * heat.transform * log.position
		var log_relative: Transform3D = heat.global_transform.affine_inverse() \
			* log.global_transform
		var rotated_bounds: AABB = _transformed_aabb(log_bounds, log_relative)
		_expect(rotated_bounds.position.x >= -clear_width * 0.5 + 0.005 \
			and rotated_bounds.end.x <= clear_width * 0.5 - 0.005 \
			and rotated_bounds.position.z >= -recess_depth * 0.5 + 0.005 \
			and rotated_bounds.end.z <= recess_depth * 0.5 - 0.005,
			where + ": rotated log mesh bounds cross a jamb or cheek")
		_expect(log_world.y + log_bounds.position.y >= sill - 0.02,
			where + ": log falls below the measured firebox sill")
		if index == 0:
			_expect(absf(log_world.y + log_bounds.position.y - fuel_top_world) <= 0.006,
				where + ": base log is not physically supported by the measured fuel bed")
		else:
			_expect(log_world.y + log_bounds.position.y <= log_top_world + 0.006
				and log_world.y + log_bounds.position.y >= log_top_world - 0.045,
				where + ": crossed upper log is not physically supported by the base split")
	for index in range(3):
		var flame := heat.find_child("Flame_%d" % index, true, false) as MeshInstance3D
		if flame == null or not flame.mesh is ArrayMesh:
			_fail(where + ": missing volumetric flame tongue")
			continue
		var flame_bounds: AABB = flame.mesh.get_aabb()
		var flame_xf: Transform3D = host.global_transform * heat.transform * flame.transform
		var flame_world_bottom: float = (flame_xf * Vector3(0.0,
			flame_bounds.position.y, 0.0)).y
		var flame_world_top: float = (flame_xf * Vector3(0.0,
			flame_bounds.end.y, 0.0)).y
		_expect(flame_world_bottom >= log_top_world - 0.025 \
				and flame_world_bottom <= log_top_world + 0.015 \
				and flame_world_top < head - 0.08 \
				and flame_bounds.size.z > 0.02,
			where + ": volumetric flame does not start on crossed logs inside the aperture")


func _check_actual_shell_sightlines(host: Node3D, heat: Node3D,
		builder: HouseBuilder, breast: Dictionary, metrics: Dictionary, where: String) -> void:
	var normal2: Vector2 = breast["normal"]
	var normal := Vector3(normal2.x, 0.0, normal2.y).normalized()
	var eye := Vector3(Vector2(breast["centre"]).x,
		float(metrics["sill"]) + 1.05, Vector2(breast["centre"]).y) + normal * 1.35
	for index in range(3):
		var flame := heat.find_child("Flame_%d" % index, true, false) as MeshInstance3D
		if flame == null:
			_fail(where + ": missing flame for actual shell sightline")
			continue
		var target: Vector3 = host.global_transform * heat.transform \
			* flame.transform * flame.mesh.get_aabb().get_center()
		var hit: Variant = HouseQA._first_mesh_hit(builder.emitted_mesh, eye, target)
		_expect(hit == null,
			where + ": actual emitted shell blocks the human-eye firebox ray for flame %d" % index)


func _check_old_cauldron_blocks_firebox_sightline(host: Node3D, heat: Node3D,
		breast: Dictionary, metrics: Dictionary, where: String) -> void:
	var normal2: Vector2 = breast["normal"]
	var normal := Vector3(normal2.x, 0.0, normal2.y).normalized()
	var foot: Vector2 = PropCatalog.footprint("Cauldron")
	var old_centre: Vector2 = Vector2(breast["centre"]) \
		+ normal2 * (foot.y * 0.5 + float(breast["depth"]) * 0.5)
	var cauldron_placement := HouseFurnishGeometry.candidate("Cauldron", old_centre,
		float(breast["yaw"]))
	cauldron_placement["pos"] = Vector3(old_centre.x, HouseGeometry.FLOOR_T, old_centre.y)
	var cauldron := HouseAssembler._instance(cauldron_placement)
	if cauldron == null:
		_fail(where + ": actual legacy Cauldron mesh unavailable for visibility negative")
		return
	get_root().add_child(cauldron)
	var flame := heat.find_child("Flame_0", true, false) as MeshInstance3D
	var target: Vector3 = host.global_transform * heat.transform \
		* flame.transform * flame.mesh.get_aabb().get_center()
	var eye := Vector3(Vector2(breast["centre"]).x,
		float(metrics["sill"]) + 1.05, Vector2(breast["centre"]).y) + normal * 1.35
	var blocked := _cauldron_mesh_blocks_segment(cauldron, eye, target)
	_expect(blocked,
		where + ": legacy full-size Cauldron did not block the same firebox sightline")
	cauldron.free()

func _cauldron_mesh_blocks_segment(hearth_node: Node3D,
		start: Vector3, finish: Vector3) -> bool:
	var mesh_nodes: Array[MeshInstance3D] = []
	if hearth_node is MeshInstance3D:
		mesh_nodes.append(hearth_node as MeshInstance3D)
	for mesh_node in hearth_node.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh_node as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		mesh_nodes.append(instance)
	for instance in mesh_nodes:
		if instance.mesh == null:
			continue
		var instance_transform: Transform3D = instance.global_transform
		for surface in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index_value: Variant = arrays[Mesh.ARRAY_INDEX]
			var indices: PackedInt32Array = index_value if index_value != null else PackedInt32Array()
			var order := indices
			if order.is_empty():
				order = PackedInt32Array()
				for i in range(vertices.size()):
					order.append(i)
			for i in range(0, order.size() - 2, 3):
				var a: Vector3 = instance_transform * vertices[order[i]]
				var b: Vector3 = instance_transform * vertices[order[i + 1]]
				var c: Vector3 = instance_transform * vertices[order[i + 2]]
				if Geometry3D.segment_intersects_triangle(start, finish, a, b, c) != null:
					return true
	return false


func _check_removed_component_mesh_control(hearth_node: Node3D,
		placement: Dictionary, plan: HousePlan, builder: HouseBuilder,
		role: String, where: String) -> void:
	var target: Dictionary = {}
	for row: Dictionary in builder.component_log:
		if String(row.get("host", "")) == "hearth" \
				and String(row.get("role", "")) == role:
			target = row
			break
	if target.is_empty():
		_fail(where + ": cannot select actual component triangles for " + role)
		return
	var surface: int = HouseQA._logical_mesh_surface(builder.emitted_mesh,
		int(target["surface"]))
	if surface < 0:
		_fail(where + ": actual mesh surface missing for " + role)
		return
	var kit := MeshKit.new(1)
	kit.oriented_box(target["size"], target["xf"], 0)
	var want: PackedVector3Array = kit.commit().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var remaining: Dictionary = ComponentCheck.triangle_counts(want)
	var mutation := MeshProbe.remove_triangles(builder.emitted_mesh, surface,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			var key := ComponentCheck.triangle_key(a, b, c)
			if int(remaining.get(key, 0)) <= 0:
				return false
			remaining[key] = int(remaining[key]) - 1
			return true)
	if int(mutation.get("removed_triangles", 0)) != 12:
		_fail(where + ": failed to remove exactly one actual " + role + " box")
		return
	var mutant := HouseBuilder.new()
	mutant.emitted_mesh = mutation["mesh"]
	for row: Dictionary in builder.component_log:
		mutant.component_log.append(row.duplicate(true))
	_expect_rejected_assembly(HouseAssembler._domestic_hearth_assembly(hearth_node,
		placement, plan, mutant),
		where + ": assembly accepted removed actual " + role + " triangles while logs remained")


func _check_removed_backing_mesh_control(hearth_node: Node3D,
		placement: Dictionary, plan: HousePlan, builder: HouseBuilder,
		breast: Dictionary, metrics: Dictionary, backing_y: float, where: String) -> void:
	var normal2: Vector2 = breast["normal"]
	var normal := Vector3(normal2.x, 0.0, normal2.y).normalized()
	var y: float = backing_y
	_expect(absf(y - float(metrics["soot_y"])) < 0.002,
		where + ": destructive backing control sampled a different panel height")
	var face := Vector3(breast["centre"].x, y, breast["centre"].y) \
		+ normal * float(breast["depth"]) * 0.5
	var start := face + normal * 0.10
	var finish := face - normal * (float(breast["depth"]) \
		+ HouseGeometry.wall_thickness(plan.spec) * 1.5)
	var wall_surface: int = HouseQA._logical_mesh_surface(builder.emitted_mesh,
		HouseBuilder.SURF_WALL)
	var original_hit: Variant = HouseQA._first_mesh_hit(builder.emitted_mesh, start, finish)
	if original_hit == null:
		_fail(where + ": backing control has no original physical wall witness")
		return
	var original_hit_row: Dictionary = original_hit
	var planned_wall_point := Vector3(breast["centre"].x, y, breast["centre"].y) \
		- normal * float(breast["depth"]) * 0.5
	var original_point: Vector3 = original_hit_row["point"]
	var original_plane_error: float = absf((original_point - planned_wall_point).dot(normal))
	if int(original_hit_row["surface"]) != wall_surface \
			or original_plane_error > 0.02:
		_fail(where + ": backing removal control did not target the planned host-wall triangle")
		return
	var mutation := MeshProbe.remove_triangles(builder.emitted_mesh, wall_surface,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			return Geometry3D.segment_intersects_triangle(start, finish, a, b, c) != null)
	if int(mutation.get("removed_triangles", 0)) <= 0:
		_fail(where + ": backing-ray negative control removed no actual wall triangle")
		return
	var residual_hit: Variant = HouseQA._first_mesh_hit(mutation["mesh"], start, finish)
	var residual_host_wall := false
	if residual_hit != null:
		var residual_row: Dictionary = residual_hit
		var residual_point: Vector3 = residual_row["point"]
		residual_host_wall = int(residual_row["surface"]) == wall_surface \
			and absf((residual_point - planned_wall_point).dot(normal)) <= 0.02
	_expect(not residual_host_wall,
		where + ": backing removal left the same host-plane triangle witness intact")
	var mutant := HouseBuilder.new()
	mutant.emitted_mesh = mutation["mesh"]
	for row: Dictionary in builder.component_log:
		mutant.component_log.append(row.duplicate(true))
	_expect_rejected_assembly(HouseAssembler._domestic_hearth_assembly(hearth_node,
		placement, plan, mutant),
		where + ": assembly accepted missing backing-wall triangles while logs remained")




func _expect_rejected_assembly(result: Dictionary, message: String) -> void:
	if result.is_empty():
		_expect(true, message)
		return
	var heat: Node3D = result.get("heat") as Node3D
	var soot: Node3D = result.get("soot") as Node3D
	if heat != null:
		heat.free()
	if soot != null:
		soot.free()
	_expect(false, message)

func _opening_metrics(builder: HouseBuilder, breast: Dictionary) -> Dictionary:
	var foot: Dictionary = {}
	var lintel: Dictionary = {}
	var jambs: Array[Dictionary] = []
	for row: Dictionary in builder.component_log:
		if String(row.get("host", "")) != "hearth":
			continue
		match String(row.get("role", "")):
			"hearth_breast_foot":
				foot = row
			"hearth_lintel":
				lintel = row
			"hearth_jamb":
				jambs.append(row)
	if foot.is_empty() or lintel.is_empty() or jambs.size() != 2:
		return {}
	var foot_xf: Transform3D = foot["xf"]
	var lintel_xf: Transform3D = lintel["xf"]
	var foot_size: Vector3 = foot["size"]
	var lintel_size: Vector3 = lintel["size"]
	var jamb0_xf: Transform3D = jambs[0]["xf"]
	var jamb1_xf: Transform3D = jambs[1]["xf"]
	var jamb0_size: Vector3 = jambs[0]["size"]
	var jamb1_size: Vector3 = jambs[1]["size"]
	var sill: float = foot_xf.origin.y + foot_size.y * 0.5
	var head: float = lintel_xf.origin.y - lintel_size.y * 0.5
	var tangent := jamb0_xf.basis.x.normalized()
	var width: float = absf((jamb0_xf.origin - jamb1_xf.origin).dot(tangent)) \
		- (jamb0_size.x + jamb1_size.x) * 0.5
	var depth: float = minf(jamb0_size.z, jamb1_size.z)
	return {"sill": sill, "head": head, "width": width, "depth": depth,
		"nominal_width": float(foot_size.x),
		"center_y": (sill + head) * 0.5, "soot_y": (sill + head) * 0.5}


func _check_family_exclusions() -> void:
	var witch := HouseSpec.new(7441)
	witch.style = &"witch_hut"
	var trade_house := HouseSpec.new(7441)
	trade_house.style = &"farmhouse"
	trade_house.trade = &"smith"
	var world_house := HouseSpec.new(7441)
	world_house.style = &"farmhouse"
	var shop := ShopSpec.new(7441)
	shop.style = &"farmhouse"
	var hotel := HotelSpec.new(7441)
	hotel.style = &"farmhouse"
	var controls: Array[Dictionary] = [
		{"name": "Witch", "spec": witch, "world": &""},
		{"name": "trade house", "spec": trade_house, "world": &""},
		{"name": "world family", "spec": world_house, "world": &"domus"},
		{"name": "shop", "spec": shop, "world": &""},
		{"name": "hotel", "spec": hotel, "world": &""},
	]
	var plan := HousePlan.new()
	var empty_builder := HouseBuilder.new()
	var prop := Node3D.new()
	var placement := {"room": 0, "pos": Vector3.ZERO}
	for control: Dictionary in controls:
		plan.spec = control["spec"]
		plan.world_family = control["world"]
		plan.hearth = {"host_kind": "ordinary_fireplace"}
		_expect(not HouseFurnisher._uses_native_domestic_fireplace(plan),
			"excluded family claimed native ordinary fireplace: " + String(control["name"]))
		_expect(HouseAssembler._domestic_hearth_assembly(prop,
			placement, plan, empty_builder).is_empty(),
			"excluded family received domestic fire cues: " + String(control["name"]))
	prop.free()

func _firewood_winding_matches(arrays: Array) -> bool:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var cap_triangles := 0
	for triangle in range(0, indices.size(), 3):
		var a: int = indices[triangle]
		var b: int = indices[triangle + 1]
		var c: int = indices[triangle + 2]
		var geometric := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
		if geometric.length_squared() < 0.000000001 \
				or geometric.normalized().dot(normals[a]) < 0.99 \
				or normals[a].dot((vertices[a] + vertices[b] + vertices[c]) / 3.0) <= 0.0:
			return false
		if absf(normals[a].x) > 0.99:
			cap_triangles += 1
	return cap_triangles >= 2


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _fail(message: String) -> void:
	failures.append(message)



