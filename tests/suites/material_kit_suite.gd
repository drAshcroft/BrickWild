extends RefCounted
## EVAL-B04: the shared material kit and the world's palettes.
##
## What it holds the kit to:
##   * the shader's metre chart IS `MeshKit`'s own projection (the contract with
##     VIS-003), checked on faces of every orientation;
##   * the world builders that carry no metric UVs carry unit, finite normals
##     -- the chart is built from them, so a builder that wrote a bad normal
##     would paint a bad wall;
##   * every kit function hands back a material, flat in a headless build;
##   * every world family has a palette that covers every surface its mesh
##     actually emitted, so no surface falls back to a flat colour;
##   * the timber hall's wall panels are their own surface, so plaster can sit
##     between posts of timber.

const FACE_NORMALS := [
	Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0),
	Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0.6, 0.8, 0), Vector3(0, 0.7071, -0.7071),
	Vector3(-0.5, 0.7071, 0.5),
]

## One building per family at the smallest size the family allows.
const FAMILIES := [
	[&"courtyard_house", &"domus"], [&"courtyard_house", &"riad"],
	[&"courtyard_house", &"palazzo"], [&"insula", &"port_tenement"],
	[&"caravanserai", &"sultan_han"], [&"hammam", &"steam_baths"],
	[&"mosque", &"hypostyle"], [&"tulou", &"clan_ring"], [&"pagoda", &"square_pagoda"],
	[&"siheyuan", &"scholars_compound"], [&"vastu", &"merchants_haveli"],
	[&"vihara", &"monks_cloister"], [&"timber_hall", &"great_hall"],
	[&"timber_hall", &"phoenix_pavilion"], [&"stupa", &"saints_mound"],
	[&"cruciform_temple", &"temple_of_four_winds"], [&"nagara", &"hundred_spires"],
	[&"dravida", &"god_kings_precinct"], [&"rock_cut_temple", &"quarried_temple"],
	[&"temple_mountain", &"angkor_mountain"], [&"stepwell", &"queens_well"],
]


static func run() -> SuiteResult:
	var res := SuiteResult.new("material kit")
	_chart_is_meshkits(res)
	_kit_hands_back_materials(res)
	_world_palettes(res)
	_hall_walls_are_plaster(res)
	_bridges_and_trees(res)
	return res


static func _chart_is_meshkits(res: SuiteResult) -> void:
	var kit := MeshKit.new(1, true)
	kit.box(Vector3(7.0, 5.0, 3.0), Vector3(2.0, 3.0, -1.0), 0)
	var arrays: Array = kit.commit().surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	res.checked += 1
	var worst := 0.0
	for i in range(vertices.size()):
		# the face's own normal, from its corners: the mesh stores it compressed,
		# and a face that is exactly level must stay exactly level
		var t := i - i % 3
		var face := MeshKit._face_normal(vertices[t], vertices[t + 1], vertices[t + 2])
		var chart := MaterialKit.metric_chart(vertices[i], face)
		worst = maxf(worst, chart.distance_to(uvs[i]))
	if vertices.is_empty() or worst > 0.0005:
		res.fail("kit chart differs from MeshKit metric UV by %.4f m" % worst)
	for n in FACE_NORMALS:
		var axes: Array = MeshKit._surface_uv_axes(n)
		res.checked += 1
		var u: Vector3 = axes[0]
		var v: Vector3 = axes[1]
		# U is horizontal (the eave) unless the face is flat; V climbs.
		if absf(u.y) > 0.001 or absf(u.dot(v)) > 0.001 or v.y < -0.001 \
				and absf(n.y) < 0.999:
			res.fail("chart axes for normal %s are not (horizontal, climbing)" % n)
	# The shader's chart is the same formula: keep the source honest.
	res.checked += 1
	if not MaterialKit.HEAD.contains("cross(vec3(0.0, 1.0, 0.0), n)") \
			or not MaterialKit.HEAD.contains("dot(mpos, u), dot(mpos, v)"):
		res.fail("MaterialKit.HEAD no longer builds the MeshKit chart")


static func _kit_hands_back_materials(res: SuiteResult) -> void:
	var made := {
		"ashlar": MaterialKit.ashlar(Color("b0a090")), "sandstone": MaterialKit.sandstone(Color("c0a070")),
		"rubble": MaterialKit.rubble(Color("908070")), "plaster": MaterialKit.plaster(Color("d8c090")),
		"brick": MaterialKit.brick(Color("a05030")), "terracotta": MaterialKit.terracotta(Color("b06040")),
		"grey_tile": MaterialKit.grey_tile(Color("505050")), "slate": MaterialKit.slate(Color("484c52")),
		"shingle": MaterialKit.shingle(Color("6a5040")), "thatch": MaterialKit.thatch(Color("b09a60")),
		"timber": MaterialKit.timber(Color("4a3527")), "weathered": MaterialKit.timber(Color("6a5440"), true),
		"lead": MaterialKit.lead(), "water": MaterialKit.water(), "earth": MaterialKit.rammed_earth(Color("8b7156")),
		"rock": MaterialKit.rock(Color("9b8060")), "whitewash": MaterialKit.whitewash(),
		"paving": MaterialKit.paving(Color("a89a80")), "bark": MaterialKit.bark(Color("5a4636")),
		"leaf": MaterialKit.leaf(Color("4f7a3a")), "rope": MaterialKit.rope(),
	}
	for key in made:
		res.checked += 1
		var m: Material = made[key]
		if m == null:
			res.fail("MaterialKit.%s returned no material" % key)
		elif DisplayServer.get_name() == "headless" and not (m is StandardMaterial3D):
			res.fail("MaterialKit.%s is not a flat material in a headless build" % key)
	res.checked += 1
	var tree_bark: Material = made["bark"]
	if DisplayServer.get_name() == "headless" \
			and not (tree_bark as StandardMaterial3D).vertex_color_use_as_albedo:
		res.fail("bark must keep the tree's vertex-colour grain")


static func _request(style: StringName, purpose: StringName) -> BuildingRequest:
	var request := BuildingRequest.new()
	request.kind = &"world"
	request.style = style
	request.purpose = purpose
	request.seed = 4101
	var envelope: Dictionary = WorldFamilies.envelope(style)
	request.width = float(envelope["width"]["min"])
	request.length = float(envelope["length"]["min"])
	request.height = float(envelope["height"]["min"])
	return request


static func _world_palettes(res: SuiteResult) -> void:
	for row in FAMILIES:
		var building := BigGlade.generate(_request(row[0], row[1]))
		res.checked += 1
		if building == null or not building.is_ok():
			res.fail("%s/%s did not generate at its smallest size" % [row[0], row[1]])
			continue
		var mesh: ArrayMesh = WorldFamilies.build_mesh(building)
		var palette: Array = WorldAssembler.palette(building)
		res.checked += 1
		if mesh == null:
			res.fail("%s/%s has no mesh" % [row[0], row[1]])
			continue
		if palette.is_empty():
			res.fail("%s/%s has no palette: it would render as flat colour" % [row[0], row[1]])
			continue
		var node := MeshInstance3D.new()
		node.mesh = mesh
		MaterialKit.apply(node, palette)
		for i in range(mesh.get_surface_count()):
			res.checked += 1
			if node.get_surface_override_material(i) == null:
				res.fail("%s/%s surface %d has no kit material" % [row[0], row[1], i])
		node.free()
		res.checked += 1
		if not _normals_unit(mesh):
			res.fail("%s/%s has a non-unit or non-finite normal; the metre chart is built from it" % [row[0], row[1]])


## Every vertex normal is finite and unit length.
static func _normals_unit(mesh: ArrayMesh) -> bool:
	for surface in range(mesh.get_surface_count()):
		var normals: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_NORMAL]
		if normals.is_empty():
			return false
		for n in normals:
			if not n.is_finite() or absf(n.length() - 1.0) > 0.01:
				return false
	return true


static func _hall_walls_are_plaster(res: SuiteResult) -> void:
	for kind in [&"great_hall", &"phoenix_pavilion"]:
		var spec := TimberHallGenerator.generate(kind, 4101, 34.0, 18.0, 20.0)
		var builder := TimberHallBuilder.new()
		var mesh := builder.build(spec)
		var components := ComponentCheck.check(builder, mesh)
		res.checked += 1
		if not components["ok"] or int(components["checked"]) < 10:
			res.fail("%s: raised hall frame is missing from its mesh" % kind)
		for c in builder.component_log:
			var bounds := MassBuilder.component_aabb(c)
			var door := AABB(Vector3(-1.49, spec.platform_h, -spec.length * 0.5 - 0.5),
				Vector3(2.98, minf(5.0, spec.height * 0.42) - 0.02, 1.0))
			res.checked += 1
			if bounds.intersects(door):
				res.fail("%s: raised frame obstructs the entrance" % kind)
		var surface := _surface_of_slot(mesh, TimberHallBuilder.SURF_PLASTER)
		res.checked += 1
		if surface < 0:
			res.fail("%s emits no plaster surface for the walls between its posts" % kind)
			continue
		var plaster: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		var height := 0.0
		for p in plaster:
			height = maxf(height, p.y)
		res.checked += 1
		if height < spec.platform_h + spec.height * 0.99:
			res.fail("%s: the plaster walls do not reach the eaves" % kind)
		# the great hall has no dark surface (no pond), so its plaster is the
		# fourth surface in the mesh and must say which slot it is
		res.checked += 1
		if mesh.get_surface_count() < 5 and not mesh.surface_get_name(surface).begins_with("material_slot:"):
			res.fail("%s: a skipped surface shifted plaster's index and the mesh does not name the slot" % kind)


static func _surface_of_slot(mesh: ArrayMesh, slot: int) -> int:
	for i in range(mesh.get_surface_count()):
		var named := mesh.surface_get_name(i)
		if named.begins_with("material_slot:"):
			if int(named.trim_prefix("material_slot:")) == slot:
				return i
		elif i == slot:
			return i
	return -1


## Bridges name their slots when a middle surface is empty (a stone bridge with
## no timber would otherwise hand its deck the timber material), every kind has
## a four-surface kit palette, and a tree's bark and leaf read vertex colour.
static func _bridges_and_trees(res: SuiteResult) -> void:
	for kind in [&"stone", &"covered", &"rope", &"mobile"]:
		var spec := BridgeAssembler.showcase(kind, 5100)
		BridgeGenerator.generate(spec, 5100)
		var mesh: ArrayMesh = BridgeBuilder.new().build(spec)
		res.checked += 1
		var last := -1
		var ordered := true
		for i in range(mesh.get_surface_count()):
			var slot := i
			var named := mesh.surface_get_name(i)
			if named.begins_with("material_slot:"):
				slot = int(named.trim_prefix("material_slot:"))
			ordered = ordered and slot > last and slot < BridgeSpec.SURFACE_COUNT
			last = slot
		if not ordered:
			res.fail("%s bridge surfaces do not resolve to ascending slots" % kind)
		res.checked += 1
		if BridgeAssembler.kit_materials(spec).size() != BridgeSpec.SURFACE_COUNT:
			res.fail("%s bridge palette does not cover the four surfaces" % kind)
		var node: Node3D = BridgeAssembler.build(spec)
		var span: MeshInstance3D = node.get_node("Mesh")
		for i in range(span.mesh.get_surface_count()):
			res.checked += 1
			if span.get_surface_override_material(i) == null:
				res.fail("%s bridge surface %d has no material" % [kind, i])
		node.free()
	var tree := TreeSpec.new()
	TreeGenerator.generate(tree, 4101)
	var tree_node: Node3D = TreeAssembler.build(tree)
	var tree_mesh: MeshInstance3D = tree_node.get_node("Mesh")
	for i in range(tree_mesh.mesh.get_surface_count()):
		var material: Material = tree_mesh.get_surface_override_material(i)
		res.checked += 1
		var reads := false
		if material is StandardMaterial3D:
			reads = (material as StandardMaterial3D).vertex_color_use_as_albedo
		elif material is ShaderMaterial:
			reads = bool((material as ShaderMaterial).get_shader_parameter("vertex_tint"))
		if not reads:
			res.fail("tree surface %d does not read the voxel grain in vertex colour" % i)
	tree_node.free()
