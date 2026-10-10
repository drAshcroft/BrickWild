class_name HouseAssembler
extends RefCounted
## Turns a furnished HousePlan into a scene: the shell mesh, and an instance of
## the real model for every piece of furniture in it.
##
## This is the only place that touches the art. Everything above it -- the
## planner, the furnisher, all four checks -- works in metres and rectangles
## and never loads a model, which is what lets the whole harness run headless
## in a few milliseconds per house. Here at the end the rectangles are handed
## their meshes.
##
## Placement corrections come from the
## measured catalogue rather than from guesswork:
##   * the model's measured centre follows the planned footprint, and a
##     mounted model's back follows the room's wall face;
##   * the model is dropped so its feet sit on the floor, because a few of them
##     are modelled hanging below their own origin;
##   * the placement's scale is applied, so the small table the furnisher chose
##     for a small room is actually small.

## Materials for the shell's four surfaces, in the builder's own order.
const SURFACES := ["wall", "trim", "roof", "floor"]
const BASE_HOUSE_SPEC := preload("res://src/house/house_spec.gd")


## Build the whole thing. `cutaway` leaves the roof off, which is the only way
## to photograph a furnished interior.
static func build(plan: HousePlan, cutaway := false) -> Node3D:
	var root := Node3D.new()
	root.name = "House"

	var builder := HouseBuilder.new()
	var mesh: ArrayMesh = builder.build(plan, not cutaway)
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = mesh
	# one material per surface, from ShellAssembler, like every other family
	# (API-005). The house's roof is not hidden for a cutaway -- the builder
	# is asked not to emit it at all, which is why `not cutaway` goes in above.
	ShellAssembler.surface_materials(shell, BuildingFamilyAdapter.colours(plan.spec))
	# A shop's shell IS a house's shell, roof and all, so it gets the coursed
	# roof too: the `room_program` test was meant for the castle families that
	# borrow this assembler, and a flat brown shop roof was the price of it
	# (WALK-QA, 6 Oct, shop pin 3).
	if plan.spec.material != &"stone" and (plan.spec is ShopSpec
			or not plan.spec.has_method("room_program")):
		ShellAssembler.house_materials(shell, plan.spec, plan.world_family)
	else:
		ShellAssembler.house_floor_material(shell, plan.spec)
	if plan.world_family != &"":
		# a family of the wider world is built of its own things (EVAL-B04)
		WorldAssembler.dress_house(shell, plan)
	root.add_child(shell)
	furnish(root, plan, builder)
	dress_exterior(root, plan)
	return root


static func dress_exterior(root: Node3D, plan: HousePlan) -> void:
	var exterior := Node3D.new()
	exterior.name = "Exterior"
	root.add_child(exterior)
	if not plan.spec.exterior_props:
		return
	for p in plan.exterior:
		var node := _instance(p, false)
		if node == null:
			push_error("Missing exterior prop model: %s" % p["key"])
			continue
		node.name = p["id"]
		exterior.add_child(node)
		_add_witch_cauldron_heat(node, p, plan)
		if PropCatalog.has_tag(p["key"], PropCatalog.LIGHT):
			exterior.add_child(LightKit.for_prop(p["key"], node.position,
				node.rotation.y, float(p["scale"])))
	# The yard's catalogue props, instantiated the same way as the facade
	# pieces: this is the only place a model loads. Its built pieces are in the
	# shell mesh (HouseBuilder._build_yard), not here.
	for p in plan.yard:
		var node := _instance(p, false)
		if node == null:
			push_error("Missing yard prop model: %s" % p["key"])
			continue
		node.name = p["id"]
		exterior.add_child(node)
		_add_witch_cauldron_heat(node, p, plan)


## The furniture, and the light every lamp among it gives off (LAY-011).
## Shared with the shop and hotel assemblers so a house is dressed and lit
## the same way whatever it is called.
static func furnish(root: Node3D, plan: HousePlan, builder: HouseBuilder = null) -> void:
	var props := Node3D.new()
	props.name = "Furniture"
	root.add_child(props)
	for p in plan.furniture:
		var node: Node3D = _instance(p)
		if node != null:
			props.add_child(node)
			_add_witch_cauldron_heat(node, p, plan)
	if builder != null and _uses_domestic_hearth_fire(plan):
		var breast: Dictionary = HouseGeometry.hearth_breast(plan)
		if not breast.is_empty():
			var anchor := Node3D.new()
			anchor.name = "OrdinaryFireplaceHost"
			anchor.position = Vector3(Vector2(breast["centre"]).x, 0.0,
				Vector2(breast["centre"]).y)
			anchor.rotation.y = float(breast["yaw"])
			var opening: Dictionary = _domestic_hearth_assembly(anchor,
				{"room": int(breast["room"]), "pos": anchor.position}, plan, builder)
			if not opening.is_empty():
				anchor.add_child(opening["heat"])
				props.add_child(anchor)
				props.add_child(opening["soot"])
			else:
				anchor.free()
	var lights := LightKit.light_the_plan(plan)
	var light_index := 0
	for item_variant in plan.furniture:
		var item: Dictionary = item_variant
		if not PropCatalog.has_tag(String(item.get("key", "")), PropCatalog.LIGHT):
			continue
		var profile: Dictionary = item.get("house_light_profile", {})
		if light_index < lights.get_child_count() and String(profile.get("name", "")) == "witchwork":
			var lamp := lights.get_child(light_index) as OmniLight3D
			if lamp != null:
				lamp.light_energy *= clampf(float(profile.get("energy_scale", 1.0)), 0.1, 1.0)
				lamp.omni_range *= clampf(float(profile.get("range_scale", 1.0)), 0.1, 1.0)
				lamp.set_meta("house_light_profile", "witchwork")
		light_index += 1
	if light_index != lights.get_child_count():
		push_error("LightKit plan mapping mismatch: %d rows, %d nodes" % [light_index, lights.get_child_count()])
	root.add_child(lights)


## A plain domestic fireplace needs fuel and light in the opening that was
## measured for its selected hearth. Read the foot, lintel and jambs from the
## actual build so this assembly follows the same aperture as the shell.
## Witch cauldron heat stays on its established path above.
static func _domestic_hearth_assembly(hearth_node: Node3D, placement: Dictionary,
		plan: HousePlan, builder: HouseBuilder) -> Dictionary:
	if not _uses_domestic_hearth_fire(plan) or hearth_node == null \
			or String(plan.hearth.get("host_kind", "")) != "ordinary_fireplace":
		return {}
	var breast: Dictionary = HouseGeometry.hearth_breast(plan)
	if breast.is_empty() or int(placement.get("room", -1)) != int(breast.get("room", -2)):
		return {}
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
	if foot.is_empty() or lintel.is_empty() or jambs.size() != 2 \
			or builder.emitted_mesh == null:
		return {}
	var foot_xf: Transform3D = foot["xf"]
	var foot_size: Vector3 = foot["size"]
	var lintel_xf: Transform3D = lintel["xf"]
	var lintel_size: Vector3 = lintel["size"]
	var sill: float = foot_xf.origin.y + foot_size.y * 0.5
	var head: float = lintel_xf.origin.y - lintel_size.y * 0.5
	var jamb0_xf: Transform3D = jambs[0]["xf"]
	var jamb1_xf: Transform3D = jambs[1]["xf"]
	var jamb0_size: Vector3 = jambs[0]["size"]
	var jamb1_size: Vector3 = jambs[1]["size"]
	var tangent := jamb0_xf.basis.x.normalized()
	var clear_width: float = absf((jamb0_xf.origin - jamb1_xf.origin).dot(tangent)) \
		- (jamb0_size.x + jamb1_size.x) * 0.5
	var opening_height: float = head - sill
	var recess_depth: float = minf(jamb0_size.z, jamb1_size.z)
	if clear_width <= 0.25 or opening_height <= 0.25 or recess_depth <= 0.08:
		return {}
	if not _hearth_components_present(builder, {
		"hearth_breast_left": 1, "hearth_breast_right": 1,
		"hearth_breast_foot": 1, "hearth_lintel": 1, "hearth_jamb": 2,
	}):
		return {}
	var normal2: Vector2 = breast["normal"]
	var normal := Vector3(normal2.x, 0.0, normal2.y).normalized()
	var firebrick_height: float = opening_height * 0.90
	var firebrick_width: float = clear_width * 0.95
	var soot_height: float = minf(0.42, opening_height * 0.42)
	var soot_width: float = firebrick_width * 0.94
	var soot_y: float = (sill + head) * 0.5
	var backing := _hearth_backing_hit(builder.emitted_mesh, breast, normal,
		soot_y, plan.spec)
	if backing.is_empty():
		return {}
	if not _hearth_has_actual_recess(builder.emitted_mesh, breast, normal,
		soot_y, plan.spec):
		return {}
	var soot_depth: float = minf(0.025, HouseGeometry.wall_thickness(plan.spec) * 0.12)
	var soot := Node3D.new()
	soot.name = "FireboxSoot"
	var backing_point: Vector3 = backing["point"]
	soot.position = backing_point + normal * (soot_depth * 0.5)
	soot.rotation.y = HouseFurnishGeometry.yaw_facing(normal2)
	soot.set_meta("measured_backing_surface", int(backing["surface"]))
	soot.set_meta("measured_backing_depth", soot_depth)
	soot.set_meta("firebrick_width", firebrick_width)
	soot.set_meta("firebrick_height", firebrick_height)
	var firebrick_mesh := BoxMesh.new()
	firebrick_mesh.size = Vector3(firebrick_width, firebrick_height, soot_depth)
	var firebrick_material := StandardMaterial3D.new()
	firebrick_material.albedo_color = Color(0.34, 0.13, 0.065)
	firebrick_material.roughness = 0.97
	var firebrick := MeshInstance3D.new()
	firebrick.name = "FirebrickRecessBack"
	firebrick.mesh = firebrick_mesh
	firebrick.material_override = firebrick_material
	firebrick.position.y = 0.0
	soot.add_child(firebrick)
	_add_firebrick_mortar(firebrick, firebrick_width, firebrick_height, soot_depth)
	var soot_mesh := _feathered_soot_mesh(soot_width, soot_height)
	var soot_material := StandardMaterial3D.new()
	soot_material.albedo_color = Color.WHITE
	soot_material.roughness = 0.98
	soot_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soot_material.vertex_color_use_as_albedo = true
	soot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	soot_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var soot_face := MeshInstance3D.new()
	soot_face.name = "SootedFireboxBack"
	soot_face.mesh = soot_mesh
	soot_face.material_override = soot_material
	# The local -Z face points toward the room after yaw_facing(normal).
	soot_face.position.z = -soot_depth * 0.5 - 0.003
	soot_face.set_meta("backing_depth", soot_depth)
	soot.add_child(soot_face)

	var placement_pos: Vector3 = placement["pos"]
	var fire_origin_world := Vector3(placement_pos.x, sill + 0.035, placement_pos.z)
	var heat := Node3D.new()
	heat.name = "DomesticHearthHeat"
	var parent_inverse := hearth_node.transform.affine_inverse()
	var local_fire_origin: Vector3 = parent_inverse * fire_origin_world
	heat.position = local_fire_origin
	heat.set_meta("opening_center_y", (sill + head) * 0.5)
	heat.set_meta("opening_sill_local_y", sill - fire_origin_world.y)
	heat.set_meta("opening_head_local_y", head - fire_origin_world.y)
	heat.set_meta("opening_clear_width", clear_width)
	heat.set_meta("opening_clear_height", opening_height)
	heat.set_meta("recess_depth", recess_depth)
	var parent_scale: Vector3 = hearth_node.scale.abs()
	var x_scale := maxf(parent_scale.x, 0.001)
	var y_scale := maxf(parent_scale.y, 0.001)
	var depth_scale := maxf(parent_scale.z, 0.001)
	# Width follows the mouth; depth follows the actual return. These are
	# perpendicular measured dimensions, not interchangeable limits.
	var fuel_width: float = minf(clear_width * 0.72, clear_width - 0.04) / x_scale
	var fuel_height := 0.022 / y_scale
	var fuel_depth: float = minf(recess_depth * 0.70, recess_depth - 0.04) / depth_scale
	var ember_material := StandardMaterial3D.new()
	ember_material.albedo_color = Color(0.075, 0.035, 0.018)
	ember_material.emission_enabled = true
	ember_material.emission = Color(0.34, 0.055, 0.008)
	ember_material.emission_energy_multiplier = 0.28
	var fuel := MeshInstance3D.new()
	fuel.name = "FuelBed"
	var fuel_mesh := BoxMesh.new()
	fuel_mesh.size = Vector3(fuel_width, fuel_height, fuel_depth)
	fuel.mesh = fuel_mesh
	fuel.material_override = ember_material
	heat.add_child(fuel)
	var local_log_length: float = minf(clear_width * 0.60, clear_width - 0.08) / x_scale
	var local_log_height := 0.082 / y_scale
	var local_log_depth := 0.078 / depth_scale
	var wood_material := StandardMaterial3D.new()
	wood_material.albedo_color = Color.WHITE
	wood_material.vertex_color_use_as_albedo = true
	wood_material.roughness = 0.94
	for index in range(2):
		var log := MeshInstance3D.new()
		log.name = "Firewood_%d" % index
		log.mesh = _split_firewood_mesh(local_log_length, local_log_height,
			local_log_depth, float(index) * 0.13)
		var log_bounds: AABB = log.mesh.get_aabb()
		log.material_override = wood_material
		# One split length lies at the mouth, the second crosses it and rests on
		# the first. The foreground placement keeps real timber visible below fire.
		log.position = Vector3(0.0, fuel_height * 0.5 - log_bounds.position.y
			+ (0.0 if index == 0 else 0.064 / y_scale),
			(-0.035 if index == 0 else -0.006) / depth_scale)
		log.rotation.y = -0.48 if index == 0 else 0.62
		heat.add_child(log)
	# A second vessel is a named plan feature, distinct from the required Pot_1
	# on the Workbench. Instantiate its real measured model only when that record
	# exists, and support it with native iron geometry inside the measured mouth.
	var vessel_plan: Dictionary = plan.hearth.get("cooking_vessel", {})
	if String(vessel_plan.get("key", "")) == "Pot_1" \
			and String(vessel_plan.get("host", "")) == "ordinary_fireplace":
		var pot_scale: float = minf(0.72, minf(clear_width / 0.539,
			recess_depth / 0.486) * 0.72)
		var pot_width := 0.539 * pot_scale
		var pot_depth := 0.486 * pot_scale
		var trivet_radius: float = minf(pot_width, pot_depth) * 0.30
		var trivet_height := 0.145 / y_scale
		var fuel_top_local := fuel_height * 0.5
		var support_y := fuel_top_local + trivet_height
		var iron := StandardMaterial3D.new()
		iron.albedo_color = Color(0.075, 0.085, 0.09)
		iron.metallic = 0.55
		iron.roughness = 0.76
		var trivet := Node3D.new()
		trivet.name = "HearthIronTripod"
		trivet.set_meta("support_radius", trivet_radius)
		trivet.set_meta("support_y", support_y)
		for leg_index in range(3):
			var angle: float = TAU * float(leg_index) / 3.0 + PI * 0.5
			var bottom := Vector3(cos(angle) * trivet_radius * 1.35,
				fuel_top_local + 0.004 / y_scale, sin(angle) * trivet_radius * 1.35)
			var top := Vector3(cos(angle) * trivet_radius * 0.78,
				support_y, sin(angle) * trivet_radius * 0.78)
			var direction := top - bottom
			var leg_mesh := CylinderMesh.new()
			leg_mesh.top_radius = 0.006 / x_scale
			leg_mesh.bottom_radius = 0.009 / x_scale
			leg_mesh.height = direction.length()
			var leg := MeshInstance3D.new()
			leg.name = "TripodLeg_%d" % leg_index
			leg.mesh = leg_mesh
			leg.material_override = iron
			leg.transform = Transform3D(Basis(Quaternion(Vector3.UP, direction.normalized())),
				(bottom + top) * 0.5)
			trivet.add_child(leg)
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = trivet_radius * 0.68
		ring_mesh.outer_radius = trivet_radius
		ring_mesh.rings = 8
		ring_mesh.ring_segments = 12
		var ring := MeshInstance3D.new()
		ring.name = "TrivetSupportRing"
		ring.mesh = ring_mesh
		ring.material_override = iron
		ring.position.y = support_y - ring_mesh.get_aabb().end.y
		trivet.add_child(ring)
		heat.add_child(trivet)
		var vessel := _instance({"key": "Pot_1", "scale": pot_scale,
			"yaw": 0.0, "pos": Vector3(0.0, support_y, 0.0)}, false)
		if vessel != null:
			vessel.name = "HearthCookingVessel"
			vessel.set_meta("plan_role", "hearth_cooking")
			vessel.set_meta("planned_key", String(vessel_plan["key"]))
			vessel.set_meta("support_node", "HearthIronTripod/TrivetSupportRing")
			heat.add_child(vessel)
	var flame_material := StandardMaterial3D.new()
	flame_material.albedo_color = Color.WHITE
	flame_material.vertex_color_use_as_albedo = true
	flame_material.emission_enabled = true
	flame_material.emission = Color(1.0, 0.25, 0.025)
	flame_material.emission_energy_multiplier = 0.42
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var flame_tip_material := StandardMaterial3D.new()
	flame_tip_material.albedo_color = Color.WHITE
	flame_tip_material.vertex_color_use_as_albedo = true
	flame_tip_material.emission_enabled = true
	flame_tip_material.emission = Color(1.0, 0.42, 0.06)
	flame_tip_material.emission_energy_multiplier = 0.32
	flame_tip_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var flame_height: float = minf(0.27, opening_height * 0.30) / y_scale
	var flame_height_fractions: Array[float] = [0.74, 1.0, 0.61]
	var flame_width_fractions: Array[float] = [0.17, 0.20, 0.15]
	var flame_x_fractions: Array[float] = [-0.20, 0.0, 0.20]
	# Flames sit behind the crossed foreground logs and below the vessel rim.
	var flame_z_fractions: Array[float] = [0.24, 0.30, 0.18]
	var flame_leans: Array[float] = [0.10, -0.08, 0.04]
	for index in range(3):
		var flame := MeshInstance3D.new()
		flame.name = "Flame_%d" % index
		var tongue_height: float = flame_height * flame_height_fractions[index]
		var flame_width: float = minf(clear_width * flame_width_fractions[index],
			recess_depth * 0.65) / x_scale
		var flame_depth: float = minf(recess_depth * 0.36, clear_width * 0.18) / depth_scale
		flame.mesh = _flame_tongue_mesh(flame_width, tongue_height, flame_depth,
			flame_leans[index] * flame_width, float(index) * 1.7)
		flame.material_override = flame_material if index == 1 else flame_tip_material
		flame.position = Vector3(flame_x_fractions[index] * clear_width / x_scale,
			fuel_height * 0.5 + local_log_height - 0.012 / y_scale,
			flame_z_fractions[index] * recess_depth / depth_scale)
		heat.add_child(flame)
	var glow := OmniLight3D.new()
	glow.name = "HearthWarmth"
	glow.light_color = Color(1.0, 0.28, 0.075)
	glow.light_energy = 0.52
	glow.omni_range = clampf(clear_width * 1.45, 1.0, 2.1)
	glow.shadow_enabled = false
	var fire_center_world := Vector3(placement_pos.x, (sill + head) * 0.5,
		placement_pos.z)
	glow.position = parent_inverse * fire_center_world - local_fire_origin
	heat.add_child(glow)
	if not _heat_fits_measured_firebox(hearth_node, heat, sill, head, clear_width, recess_depth):
		soot.free()
		heat.free()
		return {}
	if not vessel_plan.is_empty() and not _hearth_cooking_vessel_fits(
			heat, float(heat.get_meta("opening_sill_local_y")),
			float(heat.get_meta("opening_head_local_y")), clear_width, recess_depth):
		soot.free()
		heat.free()
		return {}
	return {"heat": heat, "soot": soot}


## Mortar joints make the measured backing read as a firebrick recess.
static func _add_firebrick_mortar(parent: Node3D, width: float,
		height: float, depth: float) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.055, 0.032)
	material.roughness = 0.98
	var course_height := height * 0.25
	var front_z := -depth * 0.5 - 0.0015
	for row in range(1, 4):
		var joint := MeshInstance3D.new()
		joint.name = "FirebrickBedJoint_%d" % row
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, 0.012, 0.003)
		joint.mesh = mesh
		joint.material_override = material
		joint.position = Vector3(0.0, -height * 0.5 + course_height * row, front_z)
		parent.add_child(joint)
	for row in range(4):
		var x_joints: Array = [-width / 6.0, width / 6.0] if row % 2 == 0 else [0.0]
		for joint_index in range(x_joints.size()):
			var joint := MeshInstance3D.new()
			joint.name = "FirebrickHeadJoint_%d_%d" % [row, joint_index]
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.012, course_height - 0.012, 0.003)
			joint.mesh = mesh
			joint.material_override = material
			joint.position = Vector3(x_joints[joint_index], -height * 0.5
				+ course_height * (float(row) + 0.5), front_z)
			parent.add_child(joint)


## A broad smoke stain fades across nested vertex-colour rings on the actual
## firebrick. There is no opaque paper-shaped overlay.
static func _feathered_soot_mesh(width: float, height: float) -> ArrayMesh:
	var half_width := width * 0.5
	var half_height := height * 0.5
	var outline := PackedVector2Array([
		Vector2(-half_width * 0.42, -half_height),
		Vector2(half_width * 0.50, -half_height * 0.92),
		Vector2(half_width * 0.86, -half_height * 0.10),
		Vector2(half_width * 0.74, half_height * 0.54),
		Vector2(half_width * 0.12, half_height),
		Vector2(-half_width * 0.42, half_height * 0.84),
		Vector2(-half_width * 0.90, half_height * 0.10),
	])
	var ring_scales: Array[float] = [0.24, 0.45, 0.67, 0.84, 1.0]
	var ring_alpha: Array[float] = [0.32, 0.24, 0.15, 0.06, 0.0]
	var vertices := PackedVector3Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	for ring in range(ring_scales.size()):
		for point in outline:
			vertices.append(Vector3(point.x * ring_scales[ring],
				point.y * ring_scales[ring], 0.0))
			colours.append(Color(0.10, 0.055, 0.025, ring_alpha[ring]))
	var centre_index := vertices.size()
	vertices.append(Vector3(0.0, -half_height * 0.04, 0.0))
	colours.append(Color(0.10, 0.055, 0.025, 0.30))
	# Godot's front-face winding is clockwise. These smoke triangles carry no
	# normals. Unshaded vertex alpha and disabled culling make both sides visible.
	for point_index in range(outline.size()):
		var next := (point_index + 1) % outline.size()
		indices.append_array(PackedInt32Array([centre_index, point_index, next]))
	for ring in range(1, ring_scales.size()):
		var inner_start := (ring - 1) * outline.size()
		var outer_start := ring * outline.size()
		for point_index in range(outline.size()):
			var next := (point_index + 1) % outline.size()
			indices.append_array(PackedInt32Array([
				inner_start + point_index, outer_start + point_index,
				outer_start + next, inner_start + point_index,
				outer_start + next, inner_start + next,
			]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Eight-sided, vertex-colored log shells give the crossed fuel a split end grain.
static func _split_firewood_mesh(length: float, height: float, depth: float,
		variation: float) -> ArrayMesh:
	# Eight measured facets keep each short log round in silhouette. Duplicate
	# face vertices so every bark facet and cut end has a real flat normal.
	const SIDES := 8
	var vertices := PackedVector3Array()
	var colours := PackedColorArray()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var facets: Array[float] = [0.91, 1.0, 0.94, 0.98, 0.89, 1.0, 0.93, 0.97]
	var ring0 := PackedVector3Array()
	var ring1 := PackedVector3Array()
	var colours0 := PackedColorArray()
	var colours1 := PackedColorArray()
	for end_index in range(2):
		var x := (-0.5 if end_index == 0 else 0.5) * length
		var taper := 0.91 if end_index == 0 else 1.0
		for side in range(SIDES):
			var angle: float = TAU * float(side) / float(SIDES) + variation
			var facet: float = facets[side] * taper
			var point := Vector3(x, cos(angle) * height * 0.5 * facet,
				sin(angle) * depth * 0.5 * facet)
			var shade: float = 0.90 + float((side + end_index) % 3) * 0.07
			var bark_color := Color(0.47 * shade, 0.245 * shade, 0.105 * shade)
			if end_index == 0:
				ring0.append(point)
				colours0.append(bark_color)
			else:
				ring1.append(point)
				colours1.append(bark_color)
	for side in range(SIDES):
		var next := (side + 1) % SIDES
		var corners: Array[Vector3] = [ring0[side], ring0[next], ring1[next], ring1[side]]
		var face_colors: Array[Color] = [colours0[side], colours0[next],
			colours1[next], colours1[side]]
		var mid_angle: float = TAU * (float(side) + 0.5) / float(SIDES) + variation
		var face_normal := Vector3(0.0, cos(mid_angle), sin(mid_angle)).normalized()
		for corner_index in [0, 2, 1, 0, 3, 2]:
			vertices.append(corners[corner_index])
			colours.append(face_colors[corner_index])
			normals.append(face_normal)
			indices.append(vertices.size() - 1)
	for end_index in range(2):
		var x := (-0.5 if end_index == 0 else 0.5) * length
		var ring: PackedVector3Array = ring0 if end_index == 0 else ring1
		var cap_normal := Vector3(-1.0 if end_index == 0 else 1.0, 0.0, 0.0)
		var cap_color := Color(0.72, 0.49, 0.28) if end_index == 1 else Color(0.34, 0.19, 0.085)
		for side in range(SIDES):
			var next := (side + 1) % SIDES
			vertices.append(Vector3(x, 0.0, 0.0))
			vertices.append(ring[side])
			vertices.append(ring[next])
			for _vertex in range(3):
				colours.append(cap_color)
				normals.append(cap_normal)
			if end_index == 0:
				indices.append_array(PackedInt32Array([vertices.size() - 3,
					vertices.size() - 1, vertices.size() - 2]))
			else:
				indices.append_array(PackedInt32Array([vertices.size() - 3,
					vertices.size() - 2, vertices.size() - 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _flame_tongue_mesh(width: float, height: float, depth: float,
		lean: float, phase: float = 0.0) -> ArrayMesh:
	# Faceted, closed volumetric tongues. Each triangle owns its vertices and
	# outward normal, so normal backface culling shows an actual rounded volume.
	const SIDES := 8
	var levels: Array[float] = [0.0, 0.16, 0.36, 0.60, 0.82]
	var radii: Array[float] = [1.0, 0.88, 0.62, 0.32, 0.12]
	var colours: Array[Color] = [
		Color(0.55, 0.035, 0.006), Color(0.78, 0.095, 0.012),
		Color(0.94, 0.25, 0.035), Color(1.0, 0.53, 0.10),
		Color(1.0, 0.76, 0.25)]
	var facet_variation: Array[float] = [0.94, 1.0, 0.88, 1.04, 0.91, 1.0, 0.86, 0.97]
	var rings: Array[PackedVector3Array] = []
	var vertices := PackedVector3Array()
	var vertex_colours := PackedColorArray()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for ring in range(levels.size()):
		var level: float = levels[ring]
		var radius: float = radii[ring]
		var bend: float = sin(level * PI * 1.65 + phase) * width * 0.11
		var points := PackedVector3Array()
		for side in range(SIDES):
			var angle: float = TAU * float(side) / float(SIDES) + phase * 0.08
			var facet: float = facet_variation[side]
			points.append(Vector3(lean * level + bend + cos(angle) * width * 0.5 * radius * facet,
				height * level, sin(angle) * depth * 0.5 * radius * facet))
		rings.append(points)
	var base_center := Vector3(0.0, 0.0, 0.0)
	for side in range(SIDES):
		var next := (side + 1) % SIDES
		_append_fire_triangle(vertices, vertex_colours, normals, indices,
			base_center, rings[0][next], rings[0][side], colours[0], colours[0], colours[0],
			Vector3.DOWN)
	for ring in range(levels.size() - 1):
		for side in range(SIDES):
			var next := (side + 1) % SIDES
			var angle: float = TAU * (float(side) + 0.5) / SIDES + phase * 0.08
			var radial := Vector3(cos(angle), 0.0, sin(angle)).normalized()
			var low: PackedVector3Array = rings[ring]
			var high: PackedVector3Array = rings[ring + 1]
			_append_fire_triangle(vertices, vertex_colours, normals, indices,
				low[side], high[next], low[next], colours[ring], colours[ring + 1],
				colours[ring], radial)
			_append_fire_triangle(vertices, vertex_colours, normals, indices,
				low[side], high[side], high[next], colours[ring], colours[ring + 1],
				colours[ring + 1], radial)
	var tip := Vector3(lean + sin(phase) * width * 0.1, height, 0.0)
	var last: PackedVector3Array = rings[levels.size() - 1]
	for side in range(SIDES):
		var next := (side + 1) % SIDES
		var angle: float = TAU * (float(side) + 0.5) / SIDES + phase * 0.08
		var radial := Vector3(cos(angle), 0.12, sin(angle)).normalized()
		_append_fire_triangle(vertices, vertex_colours, normals, indices,
			last[side], tip, last[next], colours[4], colours[4], colours[4], radial)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = vertex_colours
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _append_fire_triangle(vertices: PackedVector3Array,
		colours: PackedColorArray, normals: PackedVector3Array,
		indices: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3,
		ca: Color, cb: Color, cc: Color, expected: Vector3) -> void:
	var face_normal := (c - a).cross(b - a)
	if face_normal.dot(expected) < 0.0:
		var old_b := b
		b = c
		c = old_b
		var old_cb := cb
		cb = cc
		cc = old_cb
	face_normal = (c - a).cross(b - a).normalized()
	for pair in [[a, ca], [b, cb], [c, cc]]:
		vertices.append(pair[0])
		colours.append(pair[1])
		normals.append(face_normal)
		indices.append(vertices.size() - 1)


## Component rows are only a plan for geometry. Require the actual triangles on
## the emitted material surface before using those rows as firebox dimensions.
static func _hearth_components_present(builder: HouseBuilder,
		expected_roles: Dictionary) -> bool:
	if builder.emitted_mesh == null:
		return false
	for role_variant in expected_roles:
		var role := String(role_variant)
		var wanted: int = int(expected_roles[role_variant])
		var rows: Array[Dictionary] = []
		for row: Dictionary in builder.component_log:
			if String(row.get("host", "")) == "hearth" \
					and String(row.get("role", "")) == role:
				rows.append(row)
		if rows.size() != wanted:
			return false
		for row in rows:
			if String(row.get("form", "")) != "box":
				return false
			var surface := _hearth_logical_surface(builder.emitted_mesh,
				int(row.get("surface", -1)))
			if surface < 0 or not _box_component_triangles_present(
					builder.emitted_mesh, surface, row):
				return false
	return true


static func _hearth_logical_surface(mesh: ArrayMesh, logical: int) -> int:
	for surface in range(mesh.get_surface_count()):
		var surface_name: String = mesh.surface_get_name(surface)
		if surface_name.begins_with("material_slot:"):
			if int(surface_name.trim_prefix("material_slot:")) == logical:
				return surface
	if mesh.get_surface_count() > 0:
		for surface in range(mesh.get_surface_count()):
			if mesh.surface_get_name(surface).begins_with("material_slot:"):
				return -1
	return logical if mesh.get_surface_count() == 4 and logical >= 0 and logical < 4 else -1


static func _box_component_triangles_present(mesh: ArrayMesh, surface: int,
		row: Dictionary) -> bool:
	var kit := MeshKit.new(1)
	kit.oriented_box(Vector3(row["size"]), Transform3D(row["xf"]), 0)
	var expected_mesh := kit.commit()
	var expected_arrays: Array = expected_mesh.surface_get_arrays(0)
	var actual_arrays: Array = mesh.surface_get_arrays(surface)
	var expected_vertices: PackedVector3Array = expected_arrays[Mesh.ARRAY_VERTEX]
	var actual_vertices: PackedVector3Array = actual_arrays[Mesh.ARRAY_VERTEX]
	var expected_index_value: Variant = expected_arrays[Mesh.ARRAY_INDEX]
	var actual_index_value: Variant = actual_arrays[Mesh.ARRAY_INDEX]
	var expected_indices: PackedInt32Array = expected_index_value \
		if expected_index_value != null else PackedInt32Array()
	var actual_indices: PackedInt32Array = actual_index_value \
		if actual_index_value != null else PackedInt32Array()
	var expected_counts := _hearth_triangle_counts(expected_vertices, expected_indices)
	var actual_counts := _hearth_triangle_counts(actual_vertices, actual_indices)
	for key_variant in expected_counts:
		if int(actual_counts.get(key_variant, 0)) < int(expected_counts[key_variant]):
			return false
	return not expected_counts.is_empty()


static func _hearth_triangle_counts(vertices: PackedVector3Array,
		indices: PackedInt32Array) -> Dictionary:
	var counts: Dictionary = {}
	var order := indices
	if order.is_empty():
		order = PackedInt32Array()
		for i in range(vertices.size()):
			order.append(i)
	for i in range(0, order.size() - 2, 3):
		var key := _hearth_triangle_key(vertices[order[i]], vertices[order[i + 1]],
			vertices[order[i + 2]])
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


static func _hearth_triangle_key(a: Vector3, b: Vector3, c: Vector3) -> String:
	var points := [a, b, c]
	var point_keys: Array[String] = []
	for point: Vector3 in points:
		point_keys.append("%d:%d:%d" % [roundi(point.x * 100000.0),
			roundi(point.y * 100000.0), roundi(point.z * 100000.0)])
	var first := 0
	for i in range(1, 3):
		if point_keys[i] < point_keys[first]:
			first = i
	return "%s>%s>%s" % [point_keys[first], point_keys[(first + 1) % 3],
		point_keys[(first + 2) % 3]]


static func _hearth_has_actual_recess(mesh: ArrayMesh, breast: Dictionary,
		normal: Vector3, y: float, spec: HouseSpec) -> bool:
	var wall_surface := _hearth_logical_surface(mesh, HouseBuilder.SURF_WALL)
	if wall_surface < 0:
		return false
	var centre: Vector2 = breast["centre"]
	var depth: float = float(breast["depth"])
	var face := Vector3(centre.x, y, centre.y) + normal * depth * 0.5
	var start := face + normal * 0.10
	var finish := face - normal * (depth + HouseGeometry.wall_thickness(spec) * 1.5)
	var nearest_distance := INF
	var arrays: Array = mesh.surface_get_arrays(wall_surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index_value: Variant = arrays[Mesh.ARRAY_INDEX]
	var indices: PackedInt32Array = index_value if index_value != null else PackedInt32Array()
	var order := indices
	if order.is_empty():
		order = PackedInt32Array()
		for i in range(vertices.size()):
			order.append(i)
	for i in range(0, order.size() - 2, 3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(start, finish,
			vertices[order[i]], vertices[order[i + 1]], vertices[order[i + 2]])
		if hit != null:
			nearest_distance = minf(nearest_distance, start.distance_to(Vector3(hit)))
	return is_finite(nearest_distance) and nearest_distance >= depth * 0.65


## Fuel and flame volumes must fit the measured open shell. A fixture checks
## visibility and actual firebox triangle support separately.
static func _heat_fits_measured_firebox(host: Node3D, heat: Node3D,
		sill: float, head: float, clear_width: float, recess_depth: float) -> bool:
	var fuel := heat.find_child("FuelBed", true, false) as MeshInstance3D
	if fuel == null or not fuel.mesh is BoxMesh:
		return false
	var fuel_mesh := fuel.mesh as BoxMesh
	var fire_xf: Transform3D = host.transform * heat.transform
	var vertical_scale: float = fire_xf.basis.y.length()
	var fuel_world_y: float = (fire_xf * fuel.position).y
	var fuel_half_height: float = fuel_mesh.size.y * vertical_scale * 0.5
	if fuel_world_y - fuel_half_height < sill - 0.015 \
			or fuel_world_y - fuel_half_height > sill + 0.025 \
			or fuel_world_y + fuel_half_height >= head - 0.02:
		return false
	var fuel_width: float = fuel_mesh.size.x * fire_xf.basis.x.length()
	var fuel_depth: float = fuel_mesh.size.z * fire_xf.basis.z.length()
	if fuel_width > clear_width - 0.04 or fuel_depth > recess_depth - 0.04:
		return false
	var support_log := heat.find_child("Firewood_0", true, false) as MeshInstance3D
	if support_log == null or not support_log.mesh is ArrayMesh:
		return false
	var fuel_top_y: float = fuel_world_y + fuel_half_height
	for index in range(2):
		var log := heat.find_child("Firewood_%d" % index, true, false) as MeshInstance3D
		if log == null or not log.mesh is ArrayMesh:
			return false
		var log_bounds: AABB = log.mesh.get_aabb()
		var log_basis: Basis = Basis(Vector3.UP, log.rotation.y)
		var half_x: float = absf(log_basis.x.x) * log_bounds.size.x * 0.5 \
				+ absf(log_basis.z.x) * log_bounds.size.z * 0.5
		var half_z: float = absf(log_basis.x.z) * log_bounds.size.x * 0.5 \
				+ absf(log_basis.z.z) * log_bounds.size.z * 0.5
		var log_world_y: float = (fire_xf * log.position).y
		var log_bottom_y: float = log_world_y + log_bounds.position.y * vertical_scale
		var log_top_y: float = log_world_y + log_bounds.end.y * vertical_scale
		if absf(log.position.x) + half_x > clear_width * 0.5 - 0.005 \
				or absf(log.position.z) + half_z > recess_depth * 0.5 - 0.005 \
				or log_bottom_y < sill - 0.02 or log_top_y >= head - 0.08:
			return false
		if index == 0:
			# The base split rests on the measured fuel bed.
			if absf(log_bottom_y - fuel_top_y) > 0.006:
				return false
		else:
			# The crossed upper split must overlap the lower timber vertically and
			# in plan, with no unsupported gap or wholly buried piece.
			var lower: MeshInstance3D = support_log
			var lower_bounds: AABB = lower.mesh.get_aabb()
			var lower_basis: Basis = Basis(Vector3.UP, lower.rotation.y)
			var lower_top_y: float = (fire_xf * lower.position).y \
				+ lower_bounds.end.y * vertical_scale
			var lower_half_x: float = absf(lower_basis.x.x) * lower_bounds.size.x * 0.5 \
				+ absf(lower_basis.z.x) * lower_bounds.size.z * 0.5
			var lower_half_z: float = absf(lower_basis.x.z) * lower_bounds.size.x * 0.5 \
				+ absf(lower_basis.z.z) * lower_bounds.size.z * 0.5
			var vertical_overlap: float = lower_top_y - log_bottom_y
			if vertical_overlap < -0.006 or vertical_overlap > 0.045 \
					or absf(log.position.x - lower.position.x) >= half_x + lower_half_x \
					or absf(log.position.z - lower.position.z) >= half_z + lower_half_z:
				return false
	var support_bounds: AABB = support_log.mesh.get_aabb()
	var support_basis: Basis = Basis(Vector3.UP, support_log.rotation.y)
	var support_half_x: float = absf(support_basis.x.x) * support_bounds.size.x * 0.5 \
		+ absf(support_basis.z.x) * support_bounds.size.z * 0.5
	var support_half_z: float = absf(support_basis.x.z) * support_bounds.size.x * 0.5 \
		+ absf(support_basis.z.z) * support_bounds.size.z * 0.5
	var support_top_y: float = (fire_xf * support_log.position).y \
		+ support_bounds.end.y * vertical_scale
	for index in range(3):
		var flame := heat.find_child("Flame_%d" % index, true, false) as MeshInstance3D
		if flame == null or not flame.mesh is ArrayMesh:
			return false
		var flame_bounds: AABB = flame.mesh.get_aabb()
		var flame_origin: Vector3 = fire_xf * flame.position
		var flame_bottom_y: float = flame_origin.y + flame_bounds.position.y * vertical_scale
		var flame_top_y: float = flame_origin.y + flame_bounds.end.y * vertical_scale
		var flame_min_x: float = (flame.position.x + flame_bounds.position.x) \
				* fire_xf.basis.x.length()
		var flame_max_x: float = (flame.position.x + flame_bounds.end.x) \
				* fire_xf.basis.x.length()
		var flame_min_z: float = (flame.position.z + flame_bounds.position.z) \
				* fire_xf.basis.z.length()
		var flame_max_z: float = (flame.position.z + flame_bounds.end.z) \
				* fire_xf.basis.z.length()
		var overlaps_log := absf(flame.position.x - support_log.position.x) \
				< support_half_x + flame_bounds.size.x * fire_xf.basis.x.length() * 0.5 \
				and absf(flame.position.z - support_log.position.z) \
				< support_half_z + flame_bounds.size.z * fire_xf.basis.z.length() * 0.5
		if not overlaps_log or flame_bottom_y < support_top_y - 0.025 \
				or flame_bottom_y > support_top_y + 0.015 \
				or flame_top_y >= head - 0.08 \
				or flame_min_x < -clear_width * 0.5 or flame_max_x > clear_width * 0.5 \
				or flame_min_z < -recess_depth * 0.5 or flame_max_z > recess_depth * 0.5:
			return false
	return true


## The fireplace cooking vessel is a plan-owned second use of a real catalogue
## model. Its floor must sit on the measured iron ring and remain inside the
## exact mouth; missing the plan record emits no vessel at all.
static func _hearth_cooking_vessel_fits(heat: Node3D, sill: float, head: float,
		clear_width: float, recess_depth: float) -> bool:
	var vessel := heat.find_child("HearthCookingVessel", true, false) as Node3D
	var trivet := heat.find_child("HearthIronTripod", true, false) as Node3D
	var ring := heat.find_child("TrivetSupportRing", true, false) as MeshInstance3D
	if vessel == null or trivet == null or ring == null or not ring.mesh is TorusMesh \
			or not PropCatalog.known("Pot_1"):
		return false
	var leg_count := 0
	var fuel := heat.find_child("FuelBed", true, false) as MeshInstance3D
	if fuel == null or not fuel.mesh is BoxMesh:
		return false
	var fuel_mesh := fuel.mesh as BoxMesh
	var fuel_top_y: float = fuel.position.y + fuel_mesh.size.y * 0.5
	var support_y: float = float(trivet.get_meta("support_y", -INF))
	var pot_center := trivet.position + ring.position
	var ring_bounds: AABB = ring.mesh.get_aabb()
	var ring_top_y: float = pot_center.y + ring_bounds.end.y
	var ring_mesh := ring.mesh as TorusMesh
	var footprint: Vector2 = PropCatalog.footprint_rotated("Pot_1", vessel.rotation.y) * vessel.scale.x
	if absf(vessel.position.x - pot_center.x) > 0.004 \
			or absf(vessel.position.z - pot_center.z) > 0.004 \
			or absf(ring_top_y - support_y) > 0.004 \
			or ring_mesh.outer_radius > minf(footprint.x, footprint.y) * 0.5 + 0.002:
		return false
	for child in trivet.get_children():
		if String(child.name).begins_with("TripodLeg_"):
			leg_count += 1
			if not child is MeshInstance3D or not child.mesh is CylinderMesh:
				return false
			var leg := child as MeshInstance3D
			var leg_mesh := leg.mesh as CylinderMesh
			var leg_top: Vector3 = trivet.position + leg.position \
				+ leg.transform.basis.y * leg_mesh.height * 0.5
			var leg_bottom: Vector3 = trivet.position + leg.position \
				- leg.transform.basis.y * leg_mesh.height * 0.5
			if absf(leg_top.y - support_y) > 0.006 \
					or absf(leg_bottom.y - fuel_top_y) > 0.012 \
					or absf(leg_bottom.x) > clear_width * 0.5 \
					or absf(leg_bottom.z) > recess_depth * 0.5:
				return false
	if leg_count != 3:
		return false
	var scale_x: float = vessel.scale.x
	var scale_y: float = vessel.scale.y
	var floor_y: float = vessel.position.y + PropCatalog.floor_offset("Pot_1") * scale_y
	var top_y: float = floor_y + PropCatalog.height("Pot_1") * scale_y
	var half_x: float = footprint.x * 0.5
	var half_z: float = footprint.y * 0.5
	return absf(floor_y - ring_top_y) <= 0.008 \
		and floor_y > sill + 0.03 and top_y < head - 0.035 \
		and absf(vessel.position.x) + half_x <= clear_width * 0.5 - 0.015 \
		and absf(vessel.position.z) + half_z <= recess_depth * 0.5 - 0.015

static func _uses_domestic_hearth_fire(plan: HousePlan) -> bool:
	return plan != null and HouseFurnishingRecipes.is_ordinary_house(plan) \
		and plan.spec.get_script() == BASE_HOUSE_SPEC \
		and plan.spec.trade == &"none" and plan.spec.style != &"witch_hut" \
		and not plan.spec.has_method("room_program") \
		and not plan.spec.has_method("custom_room_rects") \
		and not plan.spec.has_method("landmark_footprint")


static func _hearth_backing_hit(mesh: ArrayMesh, breast: Dictionary,
		normal: Vector3, y: float, spec: HouseSpec) -> Dictionary:
	var wall_surface := -1
	var has_named_slots := false
	for surface in range(mesh.get_surface_count()):
		var surface_name: String = mesh.surface_get_name(surface)
		if surface_name.begins_with("material_slot:"):
			has_named_slots = true
			if int(surface_name.trim_prefix("material_slot:")) == HouseBuilder.SURF_WALL:
				wall_surface = surface
				break
	if wall_surface < 0 and not has_named_slots and mesh.get_surface_count() == 4:
		wall_surface = HouseBuilder.SURF_WALL
	if wall_surface < 0:
		return {}
	var centre: Vector2 = breast["centre"]
	var face := Vector3(centre.x, y, centre.y) + normal * float(breast["depth"]) * 0.5
	var start := face + normal * 0.025
	var finish := face - normal * (float(breast["depth"]) \
		+ HouseGeometry.wall_thickness(spec) * 1.5)
	var arrays := mesh.surface_get_arrays(wall_surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index_value: Variant = arrays[Mesh.ARRAY_INDEX]
	var indices: PackedInt32Array = index_value if index_value != null else PackedInt32Array()
	var nearest: Variant = null
	var nearest_distance := INF
	if indices.is_empty():
		for i in range(0, vertices.size() - 2, 3):
			var hit: Variant = Geometry3D.segment_intersects_triangle(start, finish,
				vertices[i], vertices[i + 1], vertices[i + 2])
			if hit != null:
				var point_unindexed: Vector3 = hit
				var distance_unindexed: float = start.distance_to(point_unindexed)
				if distance_unindexed < nearest_distance:
					nearest = point_unindexed
					nearest_distance = distance_unindexed
	else:
		for i in range(0, indices.size() - 2, 3):
			var hit: Variant = Geometry3D.segment_intersects_triangle(start, finish,
				vertices[indices[i]], vertices[indices[i + 1]], vertices[indices[i + 2]])
			if hit != null:
				var point_indexed: Vector3 = hit
				var distance_indexed: float = start.distance_to(point_indexed)
				if distance_indexed < nearest_distance:
					nearest = point_indexed
					nearest_distance = distance_indexed
	if nearest == null:
		return {}
	var nearest_point: Vector3 = nearest
	var expected_host_wall := Vector3(centre.x, y, centre.y) \
		- normal * float(breast["depth"]) * 0.5
	var host_plane_error: float = absf((nearest_point - expected_host_wall).dot(normal))
	if host_plane_error > 0.02:
		return {}
	return {"point": nearest_point, "surface": wall_surface,
		"host_plane_error": host_plane_error}


## One piece of furniture, placed as the plan says. Exterior dressing already
## records a model origin and opts out of the interior centre convention.
static func _instance(p: Dictionary, centred := true) -> Node3D:
	var key: String = p["key"]
	var path: String = PropCatalog.scene_path(key)
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var node: Node3D = packed.instantiate()
	node.name = key
	var scale_factor: float = float(p.get("scale", 1.0))
	var height_scale: float = PropCatalog.placement_height_scale(p)
	node.scale = Vector3(scale_factor, height_scale, scale_factor)
	node.rotation.y = float(p["yaw"]) + PropCatalog.face_offset(key)
	if centred:
		node.position = PropCatalog.house_origin(p)
		return node
	var pos: Vector3 = p["pos"]
	# sit it on whatever it stands on: the floor, a table top, or its bracket
	var drop: float = PropCatalog.seat_offset(key) * height_scale
	if PropCatalog.has_tag(key, PropCatalog.WALL_MOUNTED) \
			or PropCatalog.has_tag(key, PropCatalog.CEILING):
		drop = 0.0
	node.position = Vector3(pos.x, pos.y - drop, pos.z)
	return node




## A contained heat cue makes the Witch's existing Cauldron read as active.
## The coals and short emissive tongues stay below the measured bowl and between
## the pot legs. The cue is a child of the real prop, so its pose is not rebuilt.
static func _add_witch_cauldron_heat(parent: Node3D, placement: Dictionary, plan: HousePlan) -> void:
	if plan.spec.style != &"witch_hut" or String(placement.get("key", "")) != "Cauldron":
		return
	var cue := Node3D.new()
	cue.name = "NativeCauldronHeat"
	parent.add_child(cue)
	var floor_y: float = PropCatalog.floor_offset("Cauldron")
	if not placement.has("room"):
		# Exterior Cauldrons are separate placed models, so their fuel belongs
		# under this prop rather than as loose triangles in the house shell mesh.
		var fuel_material := StandardMaterial3D.new()
		fuel_material.albedo_color = Color(0.20, 0.095, 0.045)
		fuel_material.roughness = 0.92
		var lower_height := 0.035
		for side in [-1.0, 1.0]:
			var lower := MeshInstance3D.new()
			lower.name = "FuelLogLower_%d" % (0 if side < 0.0 else 1)
			var lower_mesh := BoxMesh.new()
			lower_mesh.size = Vector3(0.035, lower_height, 0.22)
			lower.mesh = lower_mesh
			lower.position = Vector3(side * 0.035, floor_y + lower_height * 0.5, 0.0)
			lower.material_override = fuel_material
			cue.add_child(lower)
		var upper := MeshInstance3D.new()
		upper.name = "FuelLogUpper"
		var upper_mesh := BoxMesh.new()
		upper_mesh.size = Vector3(0.18, 0.032, 0.035)
		upper.mesh = upper_mesh
		upper.position = Vector3(0.0, floor_y + lower_height + 0.016, 0.0)
		upper.material_override = fuel_material
		cue.add_child(upper)
	var ember_material := StandardMaterial3D.new()
	ember_material.albedo_color = Color(0.30, 0.055, 0.012)
	ember_material.emission_enabled = true
	ember_material.emission = Color(1.0, 0.105, 0.012)
	ember_material.emission_energy_multiplier = 1.8
	var coal := MeshInstance3D.new()
	coal.name = "EmberBed"
	var coal_mesh := CylinderMesh.new()
	coal_mesh.top_radius = 0.052
	coal_mesh.bottom_radius = 0.052
	coal_mesh.height = 0.014
	coal.mesh = coal_mesh
	coal.position = Vector3(0.0, floor_y + coal_mesh.height * 0.5, 0.0)
	coal.material_override = ember_material
	cue.add_child(coal)
	var flame_material := StandardMaterial3D.new()
	flame_material.albedo_color = Color(0.9, 0.19, 0.025)
	flame_material.emission_enabled = true
	flame_material.emission = Color(1.0, 0.20, 0.025)
	flame_material.emission_energy_multiplier = 2.4
	var coal_top := floor_y + coal_mesh.height
	for index in range(2):
		var flame := MeshInstance3D.new()
		flame.name = "LowFlame_%d" % index
		var flame_mesh := CylinderMesh.new()
		flame_mesh.bottom_radius = 0.014 if index == 0 else 0.010
		flame_mesh.top_radius = 0.0
		flame_mesh.height = 0.068 if index == 0 else 0.052
		flame.mesh = flame_mesh
		flame.position = Vector3(-0.022 if index == 0 else 0.024, coal_top + flame_mesh.height * 0.5, 0.0 if index == 0 else 0.018)
		flame.material_override = flame_material
		cue.add_child(flame)
	var glow := OmniLight3D.new()
	glow.name = "CauldronWarmth"
	glow.light_color = Color(1.0, 0.24, 0.055)
	glow.light_energy = 0.42
	glow.omni_range = 1.25
	glow.shadow_enabled = false
	glow.position = Vector3(0.0, floor_y + 0.11, 0.0)
	cue.add_child(glow)

## The camera framing a house wants: high enough to see over the walls, and
## far enough back to hold the whole footprint.
static func viewing_distance(plan: HousePlan) -> float:
	# The PLAN-AWARE bound, not the spec-only one: this caller has a plan, so
	# it can know which wall the chimney and the porch are actually on instead
	# of being padded for all four.
	var shell: AABB = HouseGeometry.exterior_bounds(plan)
	var r := Rect2(Vector2(shell.position.x, shell.position.z),
		Vector2(shell.size.x, shell.size.z))
	if plan.spec.exterior_props:
		for p in plan.exterior + plan.yard:
			var b := HouseExterior.bounds_of(p)
			r = r.merge(Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z)))
	return maxf(r.size.x, r.size.y) * 1.25 + 6.0
