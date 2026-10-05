extends RefCounted
## Focused assembly-level tests for village building appearance controls.

static func run() -> SuiteResult:
	var res := SuiteResult.new("village appearance")
	var spec := VillageSpec.new()
	var built := GeneratedBuilding.new()
	var root := Node3D.new()
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = _mesh()
	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color("e9e2d2")
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color("dadada")
	var roof := StandardMaterial3D.new()
	roof.albedo_color = Color("504050")
	shell.set_surface_override_material(0, wall)
	shell.set_surface_override_material(1, trim)
	shell.set_surface_override_material(2, roof)
	root.add_child(shell)
	built.plan = null

	VillageAssembler._apply_building_appearance(root, built, spec)
	_expect(res, shell.get_surface_override_material(0) == wall \
		and shell.get_surface_override_material(1) == trim \
		and shell.get_surface_override_material(2) == roof,
		"default settings replaced legacy shell materials")
	_expect(res, shell.mesh.get_surface_count() == 3,
		"default appearance changed shell geometry")

	spec.decoration_level = 0.0
	VillageAssembler._apply_building_appearance(root, built, spec)
	var bare_wall := (shell.get_surface_override_material(0) as StandardMaterial3D).albedo_color
	var bare_trim := (shell.get_surface_override_material(1) as StandardMaterial3D).albedo_color
	_expect(res, bare_wall != wall.albedo_color and bare_trim != trim.albedo_color,
		"bare decoration did not recolor wall and trim")
	_expect(res, shell.get_surface_override_material(2) == roof,
		"building appearance changed the roof")

	# A fresh shell makes the colorful and upkeep comparisons independent.
	var colorful := _shell_with_materials()
	var colorful_wall := (colorful.get_surface_override_material(0) as StandardMaterial3D).albedo_color
	var colorful_trim := (colorful.get_surface_override_material(1) as StandardMaterial3D).albedo_color
	spec.decoration_level = 1.0
	VillageAssembler._paint_shell(colorful, 1.0, 1.0)
	_expect(res, (colorful.get_surface_override_material(0) as StandardMaterial3D).albedo_color != colorful_wall \
		and (colorful.get_surface_override_material(1) as StandardMaterial3D).albedo_color != colorful_trim,
		"storybook decoration did not recolor wall and trim")

	var clean := _shell_with_materials()
	var worn := _shell_with_materials()
	var clean_mesh := clean.mesh
	var worn_mesh := worn.mesh
	VillageAssembler._paint_shell(clean, 0.7, 1.0)
	VillageAssembler._paint_shell(worn, 0.7, 0.0)
	_expect(res, (clean.get_surface_override_material(0) as StandardMaterial3D).albedo_color \
		!= (worn.get_surface_override_material(0) as StandardMaterial3D).albedo_color,
		"upkeep did not weather the same decoration level independently")
	_expect(res, clean.mesh == clean_mesh and worn.mesh == worn_mesh,
		"appearance settings replaced the generated mesh")
	var matkit_shell := _shell_with_materials()
	var stone := MaterialKit.church_stone(Color("aeb3ba"))
	matkit_shell.set_surface_override_material(0, stone)
	VillageAssembler._paint_shell(matkit_shell, 0.9, 1.0)
	var painted_stone := matkit_shell.get_surface_override_material(0) as ShaderMaterial
	_expect(res, painted_stone != stone \
		and painted_stone.get_shader_parameter("stone_colour") != Color("aeb3ba"),
		"MaterialKit masonry shader was not duplicated and recolored")
	var yard := Node3D.new()
	yard.name = "Exterior"
	root.add_child(yard)
	var flowers := StaticBody3D.new()
	flowers.name = "yard_flowers"
	yard.add_child(flowers)
	var work := Node3D.new()
	work.name = "yard_work"
	yard.add_child(work)
	var yard_plan := HousePlan.new()
	yard_plan.yard = [{"id": "yard_flowers", "group": "flowers#0"},
		{"id": "yard_work", "group": "woodpile#0"}]
	VillageAssembler._suppress_yard_ornament(root, yard_plan)
	_expect(res, yard.get_node_or_null("yard_flowers") == null \
		and yard.get_node_or_null("yard_work") == work,
		"bare yard retained invisible ornamental collision or removed work equipment")
	var thin_a := Node3D.new()
	var thin_b := Node3D.new()
	var paired_plan := HousePlan.new()
	for scene in [thin_a, thin_b]:
		var exterior := Node3D.new()
		exterior.name = "Exterior"
		scene.add_child(exterior)
		for i in 20:
			for side in ["a", "b"]:
				var plant := Node3D.new()
				plant.name = "bed_%d_%s" % [i, side]
				exterior.add_child(plant)
	for i in 20:
		for side in ["a", "b"]:
			paired_plan.yard.append({"id": "bed_%d_%s" % [i, side], "group": "flowers#%d" % i})
	VillageAssembler._suppress_yard_ornament(thin_a, paired_plan, 0.25)
	VillageAssembler._suppress_yard_ornament(thin_b, paired_plan, 0.25)
	var kept := thin_a.get_node("Exterior").get_child_count()
	_expect(res, kept > 0 and kept < 40, "intermediate decoration did not thin household planting")
	var consistent := true
	for i in 20:
		var a_exists := thin_a.has_node("Exterior/bed_%d_a" % i)
		consistent = consistent and a_exists == thin_a.has_node("Exterior/bed_%d_b" % i) \
			and a_exists == thin_b.has_node("Exterior/bed_%d_a" % i)
	_expect(res, consistent, "household planting thinned nondeterministically or split paired beds")
	thin_a.free()
	thin_b.free()
	root.free()
	colorful.free()
	clean.free()
	worn.free()
	matkit_shell.free()
	return res


static func _shell_with_materials() -> MeshInstance3D:
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = _mesh()
	for i in 3:
		var material := StandardMaterial3D.new()
		material.albedo_color = [Color("e9e2d2"), Color("dadada"), Color("504050")][i]
		shell.set_surface_override_material(i, material)
	return shell


static func _mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO,
		Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	for i in 3:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_name(i, "material_slot:%d" % i)
	return mesh


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
