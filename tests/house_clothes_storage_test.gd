extends SceneTree
## Closed clothes storage is separate from the bedside surface and must be usable.
var failures: Array[String] = []

func _initialize() -> void:
	_check_cabinet_front()
	for row: Dictionary in [
		{"style": &"farmhouse", "trade": &"none", "seed": 8102, "w": 9.0, "l": 12.0, "floors": 1},
		{"style": &"townhouse", "trade": &"none", "seed": 8102, "w": 10.0, "l": 14.0, "floors": 1},
		{"style": &"townhouse", "trade": &"innkeeper", "seed": 32102, "w": 13.0, "l": 16.0, "floors": 2},
	]:
		var spec := HouseSpec.new()
		spec.style = row["style"]
		spec.trade = row["trade"]
		spec.width = row["w"]
		spec.length = row["l"]
		spec.height = 2.9 if spec.trade == &"innkeeper" else 2.6
		spec.storeys = row["floors"]
		var plan := HouseGenerator.generate(spec, row["seed"])
		if spec.trade == &"innkeeper":
			plan = BrickWild.generate(BuildingRequest.house(32102, &"townhouse",
				&"innkeeper", 13.0, 16.0, 2.9, 2)).plan
		_check_generated(plan, "%s/%s seed=%d" % [spec.style, spec.trade, row["seed"]])
	_check_scope()
	for message in failures:
		push_error(message)
	print("clothes storage: 3 generated households and role/access/scope controls, %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_generated(plan: HousePlan, where: String) -> void:
	var checker := HouseFurnishWalkCheck.new()
	checker.check_stowage(plan)
	checker.check_bedside(plan)
	for message: String in checker.failures:
		failures.append(where + ": " + message)
	var nav := HouseNavCheck.new().check(plan)
	if not nav["ok"]:
		failures.append(where + ": navigation failed: " + str(nav["failures"]))
	for room in plan.rooms_of(&"bedroom"):
		var bedside := -1
		var clothes := -1
		var bed := -1
		for index in plan.furniture_of(room):
			var piece: Dictionary = plan.furniture[index]
			if PropCatalog.category(String(piece["key"])) == "nightstand":
				bedside = index
			if PropCatalog.category(String(piece["key"])) == "bed":
				bed = index
			if HouseFurnishWalkCheck._accessible_clothes_capacity(plan, index) > 0:
				clothes = index
		if bed < 0 or bedside < 0 or clothes < 0:
			failures.append(where + ": room %d lacks bed, separate bedside or clothes storage" % room)
			continue
		if PropCatalog.clothes_capacity(plan.furniture[bedside]) != 0:
			failures.append(where + ": open bedside shelf claims clothes capacity")
		if PropCatalog.placement_height(plan.furniture[bedside]) > 0.8:
			failures.append(where + ": bedside support is too tall to use from the bed")
		var storage: Dictionary = plan.furniture[clothes]
		var saved_key: String = storage["key"]
		storage["key"] = "Nightstand_Shelf"
		if HouseFurnishWalkCheck._accessible_clothes_capacity(plan, clothes) != 0:
			failures.append(where + ": shelf substitution passed the clothes role")
		storage["key"] = saved_key
		var saved_scale: float = float(storage.get("scale", 1.0))
		storage["scale"] = 0.1
		if PropCatalog.clothes_capacity(storage) != 0:
			failures.append(where + ": miniature chest retained household capacity")
		storage["scale"] = saved_scale
		var zone := HouseFurnishGeometry.zone_rect(saved_key, storage["rect"], storage["yaw"])
		var obstruction := HouseFurnishGeometry.candidate("Crate_Wooden", zone.get_center(), 0.0)
		obstruction["room"] = room
		obstruction["storey"] = plan.storey_of_room(room)
		plan.furniture.append(obstruction)
		if HouseFurnishWalkCheck._accessible_clothes_capacity(plan, clothes) != 0:
			failures.append(where + ": blocked lid/door access still counted as usable storage")
		plan.furniture.pop_back()


func _check_scope() -> void:
	for spec: HouseSpec in [ShopSpec.new(), HotelSpec.new(), InsulaSpec.new()]:
		spec.trade = &"innkeeper"
		var plan := HousePlan.new()
		plan.spec = spec
		plan.rooms = [{"kind": &"bedroom", "rect": Rect2(0, 0, 5, 5), "storey": 0}]
		if HouseFurnishingRecipes.recipe_for_room(plan, 0) != HouseFurnishingRecipes.RECIPES[&"bedroom"]:
			failures.append("guest-room override escaped into a custom/shop/hotel family")


## Door handles and hinges are actual imported metal vertices, not a label
## assigned to the planned footprint. They must face the planned use zone.
func _check_cabinet_front() -> void:
	var packed := load(PropCatalog.scene_path("Cabinet")) as PackedScene
	var root := packed.instantiate()
	var fittings: Array[Vector3] = []
	_collect_metal_vertices(root, Transform3D.IDENTITY, fittings)
	root.free()
	if fittings.is_empty():
		failures.append("Cabinet has no measured metal door fittings")
		return
	var centre := Vector3.ZERO
	for vertex in fittings:
		centre += vertex
	centre /= float(fittings.size())
	for yaw in [0.0, PI * 0.5, PI, -PI * 0.5]:
		var use_direction := Basis(Vector3.UP, yaw) * Vector3.FORWARD
		var assembled_front := Basis(Vector3.UP, yaw + PropCatalog.face_offset("Cabinet")) * centre
		if assembled_front.dot(use_direction) < 0.13:
			failures.append("Cabinet door fittings face away from their planned access")
		var uncorrected := Basis(Vector3.UP, yaw) * centre
		if uncorrected.dot(use_direction) > -0.13:
			failures.append("Uncorrected Cabinet negative does not expose its reversed front")


func _collect_metal_vertices(node: Node, parent: Transform3D, out: Array[Vector3]) -> void:
	var transform := parent
	if node is Node3D:
		transform = parent * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		for surface in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(surface)
			if material == null or not material.resource_name.contains("Metal"):
				continue
			var arrays := mesh.surface_get_arrays(surface)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				out.append(transform * vertex)
	for child in node.get_children():
		_collect_metal_vertices(child, transform, out)
