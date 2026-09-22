extends "res://tools/render_shots.gd"
## VIL-017 visual gate: one deterministic plan/render for each remaining form.

const OUT := "res://artifacts/p1_acceptance/village_forms"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_build_stage()
	await process_frame
	var cases: Array[Dictionary] = [
		{"name": &"crossroads", "population": 80, "purpose": &"crossroads", "culture": &"english", "water": &"none"},
		{"name": &"round", "population": 60, "purpose": &"forest", "culture": &"blighted", "water": &"none"},
		{"name": &"strand", "population": 70, "purpose": &"fishing", "culture": &"english", "water": &"coast"},
		{"name": &"planted", "population": 150, "purpose": &"market", "culture": &"english", "water": &"none"},
		{"name": &"gate", "population": 200, "purpose": &"garrison", "culture": &"english", "water": &"none"},
	]
	for i in range(cases.size()):
		var c: Dictionary = cases[i]
		var spec := VillageSpec.new(17017 + i)
		spec.population = int(c["population"])
		spec.purpose = c["purpose"]
		spec.culture = c["culture"]
		spec.water = c["water"]
		spec.wealth = 0.8 if c["name"] == &"planted" else 0.4
		spec.enclosure = &"none"
		spec.generate(17017 + i)
		# Site-only render keeps this gate bounded and isolates road/common/water
		# geometry from the full dresser/model load used by the lot harness.
		var plan := VillageLotPlanner.plan(spec)
		await _village_shot(plan, "%s.jpg" % String(c["name"]), i, c["name"])
	print("Village form renders complete")
	quit()

func _village_shot(plan: VillagePlan, file: String, index: int, form: StringName) -> void:
	var mesh := VillageBuilder.new().build(plan)
	_mesh_inst.mesh = mesh
	for i in range(mesh.get_surface_count()):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(VillageBuilder.COLOURS.get(i, "808080"))
		material.roughness = 0.92
		_mesh_inst.set_surface_override_material(i, material)
	var proxies := Node3D.new()
	_root3d.add_child(proxies)
	_add_plan_proxies(proxies, plan)
	await process_frame
	var bounds: AABB = mesh.get_aabb()
	var centre := bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 10.0)
	var yaw: float = [2.45, 2.85, 2.25, 2.65, 2.95][index]
	var pitch: float = [-0.42, -0.55, -0.38, -0.48, -0.45][index]
	var dist := radius / tan(deg_to_rad(_cam.fov) / 2.0) * 1.15
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = centre + dir * dist
	_cam.look_at(centre, Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_jpg(OUT + "/" + file, 0.92)
	print("  ", OUT + "/" + file)
	_mesh_inst.mesh = null
	proxies.queue_free()

func _add_plan_proxies(parent: Node3D, plan: VillagePlan) -> void:
	for b in plan.buildings:
		var request: BuildingRequest = b["request"]
		var size := Vector3(request.width, maxf(request.height * 0.45, 4.0), request.length)
		var xf: Transform3D = b["transform"]
		var node := MeshInstance3D.new()
		var body := BoxMesh.new()
		body.size = size
		node.mesh = body
		node.transform = xf
		node.position.y += size.y * 0.5
		var body_mat := StandardMaterial3D.new()
		body_mat.albedo_color = Color("9a6a4e")
		node.material_override = body_mat
		parent.add_child(node)
		var roof := MeshInstance3D.new()
		var roof_box := BoxMesh.new()
		roof_box.size = Vector3(size.x + 1.5, 0.8, size.z + 1.5)
		roof.mesh = roof_box
		roof.transform = xf
		roof.position.y += size.y + 0.4
		var roof_mat := StandardMaterial3D.new()
		roof_mat.albedo_color = Color("4c5d78")
		roof.material_override = roof_mat
		parent.add_child(roof)
		# Bright witness panels make the authored entrance and side openings legible.
		var door := MeshInstance3D.new()
		var door_box := BoxMesh.new()
		door_box.size = Vector3(1.4, 2.5, 0.12)
		door.mesh = door_box
		door.transform = xf
		door.position.y += size.y * 0.45
		door.position.z -= size.z * 0.5 + 0.08
		var door_mat := StandardMaterial3D.new()
		door_mat.albedo_color = Color("ffe7a3")
		door_mat.emission_enabled = true
		door_mat.emission = Color("ffbd55")
		door_mat.emission_energy_multiplier = 1.5
		door.material_override = door_mat
		parent.add_child(door)
