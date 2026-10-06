extends SceneTree

var failures: Array[String] = []
var checked := 0

class MissingBreast extends HouseBuilder:
	func _build_hearth_breast() -> void:
		pass

func _init() -> void:
	for fixture in [[&"farmhouse", 12.0, 16.0, 2, 4413], [&"cottage", 9.0, 12.0, 1, 21637], [&"townhouse", 10.0, 15.0, 2, 4411]]:
		var spec := HouseSpec.new(fixture[4])
		spec.style = fixture[0]
		spec.width = fixture[1]
		spec.length = fixture[2]
		spec.storeys = fixture[3]
		var plan := HouseGenerator.generate(spec, spec.seed)
		var builder := HouseBuilder.new()
		var mesh := builder.build(plan)
		var normals := SuiteResult.new("interior details normals")
		NormalsSuite.check_mesh(normals, mesh, str(fixture))
		checked += normals.checked
		for error in normals.failures:
			failures.append(str(error))
		print("DETAIL_FIXTURE ", fixture, " rugs=", plan.rugs.size(), " breast=", plan.hearth.has("breast"))
		var result := HouseQA.new().check(plan, builder)
		for error in result["failures"]:
			failures.append(str(fixture) + ": " + str(error))
		checked += 1
		_check(plan, builder, mesh)
		_mutations(plan)
		var codec := BuildingCodec.new()
		var restored: HousePlan = codec.decode(BuildingCodec.encode(plan))
		_expect(restored != null and codec.errors.is_empty(), "interior plan codec failed")
		if restored != null:
			_expect(restored.rugs == plan.rugs and restored.hearth == plan.hearth, "rug/breast records drifted through codec")
			var rebuilt := HouseBuilder.new().build(restored)
			for surface in mesh.get_surface_count():
				_expect(mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] == rebuilt.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX],
					"restored interior mesh vertices differ")
	_dining_fixture()
	print("HOUSE_INTERIOR_DETAILS: %d checks, %d failures" % [checked, failures.size()])
	for error in failures:
		print("FAIL ", error)
	quit(0 if failures.is_empty() else 1)


func _expect(ok: bool, message: String) -> void:
	checked += 1
	if not ok:
		failures.append(message)


func _check(plan: HousePlan, builder: HouseBuilder, mesh: ArrayMesh) -> void:
	_expect(mesh.get_surface_count() == 4, "interior details changed four-surface contract")
	# one rug per free-standing table, one runner per row of tables
	var wanted := 0
	var rows := {}
	for item in plan.furniture:
		if PropCatalog.category(item["key"]) == "table" and plan.kind_of(int(item["room"])) in [&"hall", &"parlour", &"dining", &"dining_room"]:
			var row := String(item.get("row", ""))
			if row == "":
				wanted += 1
			elif not rows.has(row):
				rows[row] = true
				wanted += 1
	_expect(plan.rugs.size() == wanted, "missing or orphan table rug")
	var arrays := mesh.surface_get_arrays(HouseBuilder.SURF_FLOOR)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var textile_count := 0
	for i in vertices.size():
		if colours[i].r < 0.5:
			textile_count += 1
			_expect(normals[i].distance_to(Vector3.UP) < 0.001, "rug normal is not flat/up")
	_expect(textile_count == plan.rugs.size() * 6, "rug material region triangle count drifted")
	for rug in plan.rugs:
		var rect: Rect2 = rug["rect"]
		var y := int(rug["storey"]) * plan.spec.height + HouseGeometry.FLOOR_T + 0.002
		var matches := 0
		for i in vertices.size():
			if colours[i].r < 0.5 and absf(vertices[i].y - y) < 0.0001 and rect.grow(0.001).has_point(Vector2(vertices[i].x, vertices[i].z)):
				matches += 1
		_expect(matches >= 6, "rug not emitted 2 mm above actual floor")
	var breast := HouseGeometry.hearth_breast(plan)
	for item in plan.furniture:
		if PropCatalog.category(item["key"]) != "hearth":
			continue
		_expect(not breast.is_empty(), "placed hearth has no structural breast")
		if breast.is_empty():
			continue
		var width := PropCatalog.footprint(item["key"]).x * float(item.get("scale", 1.0))
		_expect(float(breast["width"]) >= width + 0.399, "breast too narrow for actual measured hearth")
		_expect(float(breast["depth"]) >= 0.4 and float(breast["depth"]) <= 0.6, "breast depth outside 0.4–0.6m")
		_expect(HouseFurnishArrangementCheck.back_gap(plan, item) < 0.02, "hearth back does not touch breast")
	if not breast.is_empty():
		var found := false
		for mass in builder.mass_log:
			if mass["name"] == "chimney_breast":
				found = is_equal_approx(AABB(mass["aabb"]).size.y, plan.spec.height)
		_expect(found, "full-height chimney_breast mass missing")


func _dining_fixture() -> void:
	var spec := ShopSpec.new()
	spec.business = &"restaurant"
	spec.style = &"townhouse"
	# The native occupational landmark fixture guarantees a real dining table;
	# a compact 9 x 12 shop can correctly remove every table for circulation.
	spec.width = 14.0
	spec.length = 18.0
	spec.height = 2.9
	var plan := ShopGenerator.generate(spec, 33000 + absi(String(spec.business).hash()) % 900)
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan)
	_expect(not plan.rugs.is_empty(), "native restaurant dining_room has no textile")
	_check(plan, builder, mesh)
	for error in HouseQA.new().check(plan, builder)["failures"]:
		failures.append("restaurant: " + str(error))
	checked += 1
	print("DETAIL_DINING rugs=", plan.rugs.size())


func _mutations(plan: HousePlan) -> void:
	var breast := HouseGeometry.hearth_breast(plan)
	if not breast.is_empty():
		var absent := MissingBreast.new()
		absent.build(plan)
		_expect(not HouseQA.check_interior_details(plan, absent).is_empty(), "removed real breast escaped mesh check")
		var furniture := plan.furniture
		plan.furniture = []
		var blocked := HouseNavCheck.new()
		blocked.check(plan)
		var normal: Vector2 = breast["normal"]
		# A walker's centre just beyond the breast's face needs body clearance;
		# it is clear of the original room wall in both raster grid phases.
		var point: Vector2 = breast["centre"] + normal * (float(breast["depth"]) * 0.5 + HouseGeometry.PERSON_RADIUS * 0.5)
		var level := int(breast["storey"])
		var blocked_grid: WalkGrid = blocked._grids[level]
		var cell := blocked_grid.cell_of(point)
		_expect(blocked_grid.at(blocked_grid._walk, cell.x, cell.y) == 0, "navigation ignores structural breast")
		plan.hearth.erase("breast")
		var open := HouseNavCheck.new()
		open.check(plan)
		var open_grid: WalkGrid = open._grids[level]
		_expect(open_grid.at(open_grid._walk, cell.x, cell.y) == 1, "obstacle fixture was already blocked without breast")
		plan.hearth["breast"] = breast
		plan.furniture = furniture
	var before := HouseNavCheck.new().check(plan)
	var rugs := plan.rugs
	plan.rugs = []
	var after := HouseNavCheck.new().check(plan)
	_expect(before["stats"] == after["stats"], "walkable rugs altered navigation")
	plan.rugs = rugs
	if not rugs.is_empty():
		var builder := HouseBuilder.new()
		var original := builder.build(plan)
		var lifted := ArrayMesh.new()
		for surface in original.get_surface_count():
			var arrays := original.surface_get_arrays(surface)
			if surface == HouseBuilder.SURF_FLOOR:
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				for i in vertices.size():
					if colours[i].r < 0.5:
						vertices[i].y += 0.1
				arrays[Mesh.ARRAY_VERTEX] = vertices
			lifted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		builder.emitted_mesh = lifted
		_expect(HouseQA.check_interior_details(plan, builder).any(func(error: String) -> bool: return error.begins_with("rug:")),
			"raised actual rug escaped floor-contact check")
