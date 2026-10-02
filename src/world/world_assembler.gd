class_name WorldAssembler
extends RefCounted
## What each family of the wider world is built OF (EVAL-B04).
##
## The world's generators decide shapes and the builders emit them; neither
## chooses a material. This is the one place that does, family by family, from
## `MaterialKit`'s named surfaces -- the same split the church and castle
## assemblers have. A palette is an Array of Materials indexed by the builder's
## own logical surface (wall, trim, roof, floor / stone, roof, dark / ...), and
## `MaterialKit.apply` honours a `material_slot:N` name exactly as
## `ShellAssembler.surface_materials` does.
##
## Nothing here touches a plan, a log or a vertex.
##
## The painter's choices, by family:
##   domus        ochre lime plaster on a stone plinth, terracotta barrel tile
##   riad         pale lime plaster, cedar, a glazed teal-and-ivory tiled court
##   palazzo      brick with stone quoins at the corners, plaster in the cortile,
##                stone doors and water gate, terracotta
##   insula       rose plaster, weathered timber, terracotta
##   han          big-block stone, lime-washed flat roofs and domes
##   hammam       ashlar, sheet-lead domes
##   mosque       ashlar, glazed tile in the sahn, the fountain as water
##   tulou        rammed earth, dark timber galleries, grey tile ring
##   pagoda       red lacquered timber, grey tile
##   siheyuan     grey brick, red timber, grey tile
##   haveli       ochre sandstone, terracotta
##   vihara       red brick, stone trim, terracotta
##   timber hall  dark timber posts, white plaster between them, grey tile
##                (the phoenix pavilion: red timber, since it is a pavilion)
##   stupa        whitewash, sandstone railings and gateways
##   temples      sandstone; the rock-cut temple in its rock
##   stepwell     sandstone and water

## The black of an opening that is not a window.
const DARK := Color("14161a")


## The scene node for a world building that has no assembler of its own: its
## mesh in the materials of what it is made of. Null when there is no mesh.
static func instance(building) -> MeshInstance3D:
	var mesh: ArrayMesh = WorldFamilies.build_mesh(building)
	if mesh == null:
		return null
	var node := MeshInstance3D.new()
	node.name = building.name()
	node.mesh = mesh
	var materials: Array = palette(building)
	if materials.is_empty():
		ShellAssembler.surface_materials(node, BuildingFamilyAdapter.colours(building.spec))
	else:
		MaterialKit.apply(node, materials)
	return node


## The shell of a plan-based house family, dressed. Called by HouseAssembler
## after its own materials so a world plan overrides them.
static func dress_house(shell: MeshInstance3D, plan: HousePlan) -> void:
	var materials: Array = plan_palette(plan)
	if not materials.is_empty():
		MaterialKit.apply(shell, materials)


## Materials for a generated world building, by surface.
static func palette(building) -> Array:
	if building.spec is TimberHallSpec:
		return hall_palette(building.spec)
	if building.spec is StupaSpec:
		return [MaterialKit.whitewash(Color("e0d9c6"), true),
			MaterialKit.sandstone(Color("c4a47a"), true)]
	if building.plan != null:
		return plan_palette(building.plan)
	return []


## Materials for a plan's family, or empty for a family not listed here.
static func plan_palette(plan: HousePlan) -> Array:
	match plan.world_family:
		&"courtyard_house":
			return _courtyard(plan)
		&"insula":
			var rose := {"plinth_h": 0.6, "plinth_colour": Color("9b9482")}
			var rose_ground := rose.duplicate()
			rose_ground.merge(MaterialKit.floored(Color("9b8d74")))
			return [MaterialKit.plaster(Color("c3a07f"), false, rose),
				MaterialKit.timber(Color("6a5440"), true),
				MaterialKit.terracotta(Color("a9593b")),
				MaterialKit.plaster(Color("c3a07f"), false, rose_ground)]
		&"caravanserai":
			var han_stone := Color("b7a688")
			return [MaterialKit.ashlar(han_stone, false, Vector2(1.6, 0.6)),
				MaterialKit.ashlar(Color("a8987b"), false, Vector2(0.9, 0.45)),
				MaterialKit.plaster(Color("b9a988")),
				MaterialKit.ashlar(han_stone, false, Vector2(1.6, 0.6),
					MaterialKit.floored(Color("a39372")))]
		&"hammam":
			var bath_stone := Color("c7bba6")
			return [MaterialKit.ashlar(bath_stone, false, Vector2(0.9, 0.42)),
				MaterialKit.ashlar(Color("a89c86"), false, Vector2(0.7, 0.35)),
				MaterialKit.lead(Color("68706f")),
				MaterialKit.ashlar(bath_stone, false, Vector2(0.9, 0.42),
					MaterialKit.floored(Color("a89b86")))]
		&"tulou":
			return [MaterialKit.rammed_earth(Color("7a6652")),
				MaterialKit.timber(Color("4d3a2a"), true),
				MaterialKit.grey_tile(Color("505155")),
				MaterialKit.paving(Color("9c8e78"))]
		&"pagoda":
			return [MaterialKit.timber(Color("96382b")),
				MaterialKit.timber(Color("6e2a21")),
				MaterialKit.grey_tile(Color("565a5e")),
				MaterialKit.timber(Color("96382b"), false, false, false, false,
					Color(0.0, 0.0, 0.0, 0.0), MaterialKit.floored(Color("a9a395")))]
		&"siheyuan":
			var grey_brick := {"mortar": Color("5d5a55")}
			return [MaterialKit.brick(Color("86817a"), grey_brick),
				MaterialKit.timber(Color("8e2f24")),
				MaterialKit.grey_tile(Color("4d4e51")),
				MaterialKit.brick(Color("86817a"), _joined(grey_brick,
					MaterialKit.floored(Color("9b9484"), Color("9b9484"), 0.5)))]
		&"vastu":
			return [MaterialKit.sandstone(Color("c8a068")),
				MaterialKit.sandstone(Color("b58a56")),
				MaterialKit.terracotta(Color("9c6141")),
				MaterialKit.ashlar(Color("c8a068"), false, Vector2(1.4, 0.55),
					_joined(MaterialKit.floored(Color("b9935a")),
						{"joint_w": 0.03, "jitter": 0.09, "stagger": 0.6}))]
		&"vihara":
			return [MaterialKit.brick(Color("9c5a40")),
				MaterialKit.ashlar(Color("a89880")),
				MaterialKit.terracotta(Color("8e5238")),
				MaterialKit.brick(Color("9c5a40"), MaterialKit.floored(Color("a2947a")))]
		&"mosque":
			return _mosque(plan)
		&"cruciform_temple":
			return [MaterialKit.ashlar(Color("cfc5ad"), false, Vector2(1.3, 0.55)),
				MaterialKit.sandstone(Color("b79a76")), _flat(DARK)]
		&"nagara":
			return [MaterialKit.sandstone(Color("d2b78e")),
				MaterialKit.sandstone(Color("c19f72")),
				MaterialKit.sandstone(Color("cfa882")), _flat(DARK)]
		&"dravida":
			return [MaterialKit.sandstone(Color("b9a285")),
				MaterialKit.sandstone(Color("c9b293")),
				MaterialKit.sandstone(Color("c4a67f"))]
		&"rock_cut_temple":
			return [MaterialKit.rock(Color("9b8060")),
				MaterialKit.sandstone(Color("a98b66")),
				MaterialKit.rock(Color("8d7253"))]
		&"temple_mountain":
			return [MaterialKit.sandstone(Color("9a8a70")),
				MaterialKit.sandstone(Color("8f7f67")),
				MaterialKit.water(Color("3f6a6e"))]
		&"stepwell":
			return [MaterialKit.sandstone(Color("bba98a")),
				MaterialKit.sandstone(Color("a89574")),
				MaterialKit.water(Color("3d6c6a"))]
	return []


static func _courtyard(plan: HousePlan) -> Array:
	var spec: HouseSpec = plan.spec
	match plan.world_subkind:
		&"riad":
			var lime := Color("dccfb4")
			var court: Rect2 = plan.world_meta.get("court_rect", Rect2())
			var riad_ground := _joined(MaterialKit.floored(Color("b58a62")),
				MaterialKit.tiled_court(court, Color("2f7f84"), Color("e8dfc8")))
			return [MaterialKit.plaster(lime),
				MaterialKit.timber(Color("5e4430")),
				MaterialKit.terracotta(Color("a35e42")),
				# flags in the rooms; glazed teal and ivory tile in the court
				MaterialKit.plaster(lime, false, riad_ground)]
		&"palazzo":
			var site := HouseGeometry.storey_rect(plan, 0)
			var stone := Color("d6c8aa")
			# the blind ground floor is rusticated stone, the upper floors brick
			return [MaterialKit.brick(Color("a4573c"), {
					"quoin_rect": Vector4(site.position.x, site.position.y, site.end.x, site.end.y),
					"quoin_colour": Color("d6cfbc"), "quoin_w": 0.85,
					"court_colour": Color("e0d3b6")}),
				MaterialKit.ashlar(Color("d0c9b6"), false, Vector2(0.8, 0.4)),
				MaterialKit.terracotta(Color("a85d3f")),
				MaterialKit.ashlar(stone, false, Vector2(1.5, 0.7),
					_joined(MaterialKit.floored(Color("b3ab98")),
						{"joint_w": 0.06, "jitter": 0.07}))]
	var ochre := Color("d9a965")
	var plinth := {"plinth_h": maxf(spec.plinth_height, 0.5), "plinth_colour": Color("9d9684")}
	var ochre_ground := plinth.duplicate()
	ochre_ground.merge(MaterialKit.floored(Color("a89a80")))
	return [MaterialKit.plaster(ochre, false, plinth),
		MaterialKit.ashlar(Color("c4b79c"), false, Vector2(0.8, 0.4)),
		MaterialKit.terracotta(Color("bc6a45")),
		MaterialKit.plaster(ochre, false, ochre_ground)]


static func _mosque(plan: HousePlan) -> Array:
	var extra := {}
	var sahn: Variant = plan.world_meta.get("sahn_rect", null)
	if sahn is Rect2:
		var r: Rect2 = sahn
		extra = {"inlay_rect": Vector4(r.position.x, r.position.y, r.end.x, r.end.y),
			"inlay_a": Color("2e7078"), "inlay_b": Color("e6dcc2")}
	return [MaterialKit.ashlar(Color("c9b995"), false, Vector2(1.0, 0.42), extra),
		MaterialKit.plaster(Color("c3b8a0")),
		MaterialKit.water(Color("2f6f78"))]


## The timber hall: five surfaces, in TimberHallBuilder's order.
static func hall_palette(spec: TimberHallSpec) -> Array:
	var pavilion := spec.kind == &"phoenix_pavilion"
	var timber := Color("9a3226") if pavilion else Color("4a3527")
	return [MaterialKit.timber(timber),
		MaterialKit.ashlar(Color("b4aea1"), false, Vector2(1.3, 0.5), {"coping": 1.0}),
		MaterialKit.grey_tile(Color("575b5f")),
		MaterialKit.water(Color("3f5c63")),
		MaterialKit.plaster(Color("e4dcc8"))]


static func _joined(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	out.merge(b, true)
	return out


static func _flat(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
