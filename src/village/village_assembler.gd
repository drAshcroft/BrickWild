class_name VillageAssembler
extends RefCounted
## Turns a VillagePlan into a scene (VIL-018).
##
## `VillageBuilder` raises everything that is mesh -- the ground, the roads,
## the water and its bridges, the edge and its gates, and the ten small props
## no art pack ships. This file adds everything that is a MODEL: every
## building generated through BigGlade and set down at the transform the lot
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
## this is how far into the ground it is pushed so it does not float on a
## catalogue floor offset.
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
		var built: GeneratedBuilding = BigGlade.generate(b["request"])
		if built == null or not built.is_ok():
			continue
		var node: Node3D = BigGlade.instantiate(built, cutaway)
		if node == null:
			continue
		node.name = "%s_%d" % [String(b["kind"]), i]
		node.transform = b["transform"]
		houses.add_child(node)
	_dressing(root, plan)
	return root


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
		at.y = VillageBuilder.ground_height(plan, p["pos"])
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
			Vector3(float(t["pos"].x), VillageBuilder.ground_height(plan, t["pos"]) - PLANT_SINK,
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
	node.position = at - Vector3(0.0, PropCatalog.floor_offset(key) * scale, 0.0)
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
