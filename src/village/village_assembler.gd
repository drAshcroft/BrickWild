class_name VillageAssembler
extends RefCounted
## Turns a VillagePlan into a scene (VIL-018).
##
## `VillageBuilder` raises everything that is mesh -- the ground, the roads,
## the water and its bridges, the edge and its gates, and the ten small props
## no art pack ships. This file adds everything that is a MODEL: every
## building generated through BrickWild and set down at the transform the lot
## planner gave it, every catalogue prop the dresser placed, every plant it
## planted, and an `OmniLight3D` for each light through `LightKit`, which is
## the same lamp the house, shop, hotel and temple assemblers hang.
##
## The same split as the house and temple assemblers, and the reason the
## whole village harness runs headless: everything above this file works in
## metres and polygons and never loads a model.

const SURF_GROUND := VillageBuilder.SURF_GROUND
const SURF_ROAD := VillageBuilder.SURF_ROAD
const SURF_COMMON := VillageBuilder.SURF_COMMON
const SURF_WATER := VillageBuilder.SURF_WATER
## A plant is turned by its own yaw and left at the size it was modelled;
## this is how far below its measured seat it is pushed, so the rim of its
## base never shows a hairline of daylight on level ground.
const PLANT_SINK := 0.02


## The whole village. `cutaway` takes the roofs off the plan-based buildings.
static func build(plan: VillagePlan, cutaway := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Village"
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = ground_mesh(plan)
	ShellAssembler.surface_materials(ground,
		BuildingFamilyAdapter.colours(plan.spec))
	_ground_finish(ground)
	root.add_child(ground)
	var houses := Node3D.new()
	houses.name = "Buildings"
	root.add_child(houses)
	for i in range(plan.buildings.size()):
		var b: Dictionary = plan.buildings[i]
		var built: GeneratedBuilding = BrickWild.generate(b["request"])
		if built == null or not built.is_ok():
			continue
		var node: Node3D = BrickWild.instantiate(built, cutaway)
		if node == null:
			continue
		node.name = "%s_%d" % [String(b["kind"]), i]
		node.transform = b["transform"]
		_record_stands(node, built)
		_apply_building_appearance(node, built, plan.spec)
		houses.add_child(node)
	_dressing(root, plan)
	return root


## Where each of a house's yard and facade models stands, in the building's
## own frame, as plain data on its node: `VillageGroundCheck` judges the loaded
## models against it (walk QA: a yard cart in the air). Plain rows rather than
## the plan, so the scene stays packable.
static func _record_stands(node: Node3D, built: GeneratedBuilding) -> void:
	if not built.plan is HousePlan:
		return
	var rows: Array = []
	for row in built.plan.exterior + built.plan.yard:
		rows.append({"id": String(row.get("id", "")), "key": String(row.get("key", "")),
			"y": float((row["pos"] as Vector3).y), "mounted": bool(row.get("mounted", false))})
	node.set_meta(&"stands", rows)


## Paint only the architectural shell of each generated building. Surface 0 is
## the wall and surface 1 is trim in all current building families. Catalogue
## models, furniture, roofs, floors, and geometry retain their own materials.
static func _apply_building_appearance(node: Node3D, built: GeneratedBuilding,
		spec: VillageSpec) -> void:
	var decoration := clampf(spec.decoration_level, 0.0, 1.0)
	var upkeep := clampf(spec.upkeep, 0.0, 1.0)
	# This fast path preserves the legacy material objects and rendered output.
	if is_equal_approx(decoration, 0.5) and is_equal_approx(upkeep, 1.0):
		return
	var palette_seed := built.request.seed if built.request != null else 0
	_paint_architecture(node, decoration, upkeep, palette_seed)
	# House and shop yards have an independent planner. Thin ornamental groups
	# below the legacy setting; keep paths, tools, washing and trade work.
	if decoration < 0.5 and built.plan is HousePlan:
		_suppress_yard_ornament(node, built.plan as HousePlan, decoration)


static func _paint_architecture(root: Node, decoration: float, upkeep: float,
		palette_seed: int) -> void:
	for child in root.get_children():
		if child is MeshInstance3D and (child.name == "Shell" or child.name == "Stone"):
			_paint_shell_seeded(child as MeshInstance3D, decoration, upkeep, palette_seed)
		_paint_architecture(child, decoration, upkeep, palette_seed)


static func _paint_shell(shell: MeshInstance3D, decoration: float, upkeep: float) -> void:
	_paint_shell_seeded(shell, decoration, upkeep, 0)


static func _paint_shell_seeded(shell: MeshInstance3D, decoration: float,
		upkeep: float, palette_seed: int) -> void:
	if shell.mesh == null:
		return
	for surface in range(shell.mesh.get_surface_count()):
		var slot := surface
		if shell.mesh is ArrayMesh:
			var surface_name := (shell.mesh as ArrayMesh).surface_get_name(surface)
			if surface_name.begins_with("material_slot:"):
				slot = int(surface_name.trim_prefix("material_slot:"))
		if slot > 1:
			continue
		var original := shell.get_active_material(surface)
		if original == null:
			continue
		var material := original.duplicate() as Material
		if material is StandardMaterial3D:
			var standard := material as StandardMaterial3D
			standard.albedo_color = _appearance_color(standard.albedo_color, slot,
				decoration, upkeep, palette_seed)
		elif material is ShaderMaterial:
			var shader_material := material as ShaderMaterial
			var base = shader_material.get_shader_parameter("base_colour")
			if base is Color:
				shader_material.set_shader_parameter("base_colour",
					_appearance_color(base, slot, decoration, upkeep, palette_seed))
			elif slot == 0:
				# The carved masonry finish uses its own historical uniform name.
				var stone = shader_material.get_shader_parameter("stone_colour")
				if stone is Color:
					shader_material.set_shader_parameter("stone_colour",
						_appearance_color(stone, slot, decoration, upkeep, palette_seed))
				else:
					continue
			else:
				continue
		else:
			continue
		shell.set_surface_override_material(surface, material)


static func _appearance_color(base: Color, slot: int, decoration: float,
		upkeep: float, palette_seed := 0) -> Color:
	var result := base
	if decoration < 0.5:
		var bare := Color("b4aea0") if slot == 0 else Color("888176")
		result = result.lerp(bare, (0.5 - decoration) * 2.0)
	elif decoration > 0.5:
		var hue := base.h
		var saturation := base.s
		var value := base.v
		if saturation < 0.18:
			# Neutral source colours get a deterministic warm pastel; already
			# cultural colours keep their hue and become brighter and richer.
			var warm_hues := [0.075, 0.11, 0.035, 0.15, 0.96]
			hue = float(warm_hues[absi(palette_seed) % warm_hues.size()])
			if slot == 1:
				hue = fposmod(hue + 0.86, 1.0)
			saturation = 0.42 if slot == 0 else 0.48
			value = 0.88 if slot == 0 else 0.53
		else:
			hue = fposmod(hue + (0.035 if slot == 1 else 0.0), 1.0)
			saturation = minf(1.0, saturation + (0.20 if slot == 0 else 0.24))
			value = maxf(value, 0.84 if slot == 0 else 0.66)
		var fantasy := Color.from_hsv(hue, saturation, value, base.a)
		result = result.lerp(fantasy, (decoration - 0.5) * 2.0)
	# Upkeep changes wear independently of decoration and never reads wealth.
	var weathered := Color("817d73") if slot == 0 else Color("77716a")
	return result.lerp(weathered, (1.0 - upkeep) * 0.38)


static func _suppress_yard_ornament(root: Node, plan: HousePlan, decoration := 0.0) -> void:
	const ORNAMENTAL_GROUPS := [&"garden", &"flowers", &"herb_bed", &"mushrooms"]
	var exterior := root.get_node_or_null("Exterior")
	if exterior == null:
		return
	for row in plan.yard:
		var tag := String(row.get("group", ""))
		var group := tag.get_slice("#", 0)
		if StringName(group) in ORNAMENTAL_GROUPS:
			# One deterministic decision per authored group, so paired beds stay
			# paired and thinning never consumes the house planner's random stream.
			var rng := RandomNumberGenerator.new()
			var seed_value := plan.spec.seed if plan.spec != null else 0
			rng.seed = hash("village-yard|%d|%s" % [seed_value, tag])
			if decoration > 0.0 and rng.randf() < decoration * 2.0:
				continue
			var ornament := exterior.get_node_or_null(String(row.get("id", "")))
			if ornament != null:
				# Remove the model as well as any imported collision children.
				# An invisible garden must not become an invisible obstacle.
				ornament.free()


## The surfaces that carry their own vertex colour (a lot's tint, a bank's
## wet-to-dry gradient) multiply it into the slot colour.
static func _ground_finish(ground: MeshInstance3D) -> void:
	var mesh := ground.mesh as ArrayMesh
	if mesh == null:
		return
	for i in mesh.get_surface_count():
		var slot := int(mesh.surface_get_name(i).trim_prefix("material_slot:"))
		var m := ground.get_surface_override_material(i) as StandardMaterial3D
		if m == null:
			continue
		if slot in [VillageBuilder.SURF_YARD, VillageBuilder.SURF_BANK]:
			m.vertex_color_use_as_albedo = true
		elif slot == VillageBuilder.SURF_WATER:
			# clear at the margin, dark where it is deep: the bank and the bed
			# show through, so the colour of the water is the depth of it
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = 0.74
			m.roughness = 0.45


## How far below its seat a plant is set. A leaning plant is tilted about its
## foot, which lifts the uphill rim of its trunk base by the base radius times
## the sine of the lean -- a 7 degree tree showed 6 cm of daylight on one side.
## The base radius is the measured trunk at the plant's scale, held to
## LEAN_BASE_MAX because the trunk band also takes in low branches.
const LEAN_BASE_MAX := 0.5


static func plant_sink(t: Dictionary) -> float:
	var lean: float = absf(float(t.get("lean", 0.0)))
	if lean <= 0.0:
		return PLANT_SINK
	var base: float = minf(PropCatalog.trunk(String(t["key"])) * float(t.get("scale", 1.0)),
		LEAN_BASE_MAX)
	return PLANT_SINK + base * sin(lean)


## The dressing: every catalogue prop and plant the dresser placed, and a
## light for each one the catalogue tags LIGHT. The props the dresser marked
## `built` are already in the ground mesh -- `VillageBuilder` raised them --
## so they are skipped here rather than loaded twice.
static func _dressing(root: Node3D, plan: VillagePlan) -> void:
	var props := Node3D.new()
	props.name = "Props"
	root.add_child(props)
	var plants := Node3D.new()
	plants.name = "Plants"
	root.add_child(plants)
	var lights := Node3D.new()
	lights.name = "Lights"
	root.add_child(lights)
	for i in range(plan.props.size()):
		var p: Dictionary = plan.props[i]
		var key: String = String(p["key"])
		var at := Vector3(float(p["pos"].x), 0.0, float(p["pos"].y))
		var yaw: float = float(p.get("yaw", 0.0))
		# a wall torch hangs at its recorded elevation; the rest stand on the ground
		at.y = float(p["elevation"]) if p.has("elevation") \
			else VillageBuilder.ground_height(plan, p["pos"])
		if not bool(p.get("built", false)):
			var node: Node3D = _model(key, at, yaw)
			if node != null:
				node.name = "%s_%d" % [key, i]
				props.add_child(node)
		# A built prop has no model and still has a flame: the lamp post
		# carries one. Both kinds are lit from the same place.
		if bool(p.get("light", false)) or PropCatalog.has_tag(key, PropCatalog.LIGHT):
			lights.add_child(_light_for(p, key, at, yaw))
	for j in range(plan.plants.size()):
		var t: Dictionary = plan.plants[j]
		var key2: String = String(t["key"])
		var node2: Node3D = _model(key2,
			Vector3(float(t["pos"].x), VillageBuilder.ground_height(plan, t["pos"]) - plant_sink(t),
				float(t["pos"].y)),
			float(t.get("yaw", 0.0)), float(t.get("scale", 1.0)),
			float(t.get("lean", 0.0)), float(t.get("lean_yaw", 0.0)))
		if node2 != null:
			node2.name = "%s_%d" % [key2, j]
			plants.add_child(node2)


## One catalogue model, set down on the ground and turned. Null when the
## catalogue does not know the key or the pack is not installed -- a village
## missing an art pack should be a village missing its barrels, not a crash.
static func _model(key: String, at: Vector3, yaw: float, scale := 1.0,
		lean := 0.0, lean_yaw := 0.0) -> Node3D:
	if not PropCatalog.known(key):
		return null
	var path: String = PropCatalog.scene_path(key)
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var node := packed.instantiate() as Node3D
	if node == null:
		return null
	# The measured ground line, not an authored offset: a plant's seat (its
	# own ground line), anything else its lowest point.
	node.position = at - Vector3(0.0, PropCatalog.seat_offset(key) * scale, 0.0)
	node.rotation.y = yaw + PropCatalog.face_offset(key)
	if lean != 0.0:
		# tilted about the foot, in the direction `lean_yaw`
		var axis := Vector3(cos(lean_yaw), 0.0, -sin(lean_yaw))
		node.basis = Basis(axis, lean) * node.basis
	if scale != 1.0:
		node.scale = Vector3.ONE * scale
	return node


## The flame of one lit prop. A built lamp post has no catalogue entry to
## measure, so its light sits at the top of the mass PropKit raised.
static func _light_for(p: Dictionary, key: String, at: Vector3,
		yaw: float) -> OmniLight3D:
	if bool(p.get("built", false)):
		var rect: Rect2 = p.get("rect", Rect2())
		var top: float = maxf(rect.size.x, rect.size.y) * 1.6
		return LightKit.make(at + Vector3(0.0, maxf(top, 2.4), 0.0),
			LightKit.FLAME, 1.6, 9.0)
	return LightKit.for_prop(key, at, yaw, 1.0)


## The ground, the roads, the water and everything else of the village that
## is mesh, from `VillageBuilder` -- which is the one place it is decided,
## the way each family's own builder is for that family. Kept as a function
## here because every caller of this file already asks for it by this name.
static func ground_mesh(plan: VillagePlan) -> ArrayMesh:
	return VillageBuilder.new().build(plan)


## The village in words: the form, who lives there, what stands on it.
static func sheet(plan: VillagePlan) -> String:
	var spec: VillageSpec = plan.spec
	var lines: Array[String] = ["%s -- a %s %s village of %d (%d households), %s culture, wealth %.2f"
		% [spec.variant_name, String(spec.form), String(spec.purpose), spec.population,
			spec.households, String(spec.culture), spec.wealth]]
	lines.append("site %.0f x %.0f m, %d roads, %d lots, %d buildings"
		% [plan.site.size.x, plan.site.size.y, plan.roads.size(), plan.lots.size(), plan.buildings.size()])
	var kinds := {}
	for b in plan.buildings:
		var req: BuildingRequest = b["request"]
		var key: String = String(req.kind) if req.kind != &"shop" else String(req.purpose)
		if req.kind == &"house":
			key = "%s %s" % [String(req.style), String(req.purpose)]
		kinds[key] = int(kinds.get(key, 0)) + 1
	for k in kinds:
		lines.append("  %d x %s" % [int(kinds[k]), k])
	var road_check := VillageRoadCheck.new()
	road_check.check(plan)
	lines.append(road_check.ascii_map(3.0))
	return "\n".join(lines)
