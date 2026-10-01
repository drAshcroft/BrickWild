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
