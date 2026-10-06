class_name HouseAssetsSuite
extends RefCounted
## 13. The prop catalogue describes the props.
##
## Everything the furnisher does rests on the measured sizes in
## assets/props/catalog.json. If an asset is replaced, re-exported at another
## scale, or simply missing, every layout decision built on it is quietly
## wrong -- so this loads each model the catalogue claims and measures it again.

## Tolerance on a re-measured size, in metres.
const TOL := 0.02


static func run() -> SuiteResult:
	var res := SuiteResult.new("house assets")
	for key in PropCatalog.keys():
		res.checked += 1
		if not PropCatalog.known(key):
			res.fail("%s is described but was never measured -- run tools/build_prop_catalog.gd" % key)
			continue
		var path: String = PropCatalog.scene_path(key)
		if not ResourceLoader.exists(path):
			res.fail("%s has no model at %s" % [key, path])
			continue
		var packed: PackedScene = load(path)
		if packed == null:
			res.fail("%s could not be loaded from %s" % [key, path])
			continue
		var node: Node = packed.instantiate()
		# A plant is measured from its vertices, with a crown and a stem
		# radius, exactly as the tool measured it -- see
		# SceneBounds.plant_of_node(). Measuring it the other way here would
		# fail every tree in the catalogue for being the size it is.
		var plant := {}
		if PropCatalog.has_tag(key, PropCatalog.PLANT):
			plant = SceneBounds.plant_of_node(node)
		var measured: AABB = plant["box"] if plant.has("box") else SceneBounds.of_node(node)
		node.queue_free()
		if not plant.is_empty():
			res.checked += 1
			if absf(float(plant["canopy"]) - PropCatalog.canopy(key)) > TOL \
					or absf(float(plant["trunk"]) - PropCatalog.trunk(key)) > TOL:
				res.fail("%s has a %.2fm crown over a %.2fm stem; the catalogue says %.2f over %.2f"
					% [key, plant["canopy"], plant["trunk"],
						PropCatalog.canopy(key), PropCatalog.trunk(key)])
			elif PropCatalog.canopy(key) <= 0.0:
				res.fail("%s is a plant with no measured canopy" % key)
			# The ground line the assembler sits a plant on (walk QA pin:
			# a bush sat on its buried stem stub floated 0.23 m).
			res.checked += 1
			if absf(float(plant["seat"]) - PropCatalog.seat_offset(key)) > TOL:
				res.fail("%s has its ground line %.3fm off its origin; the catalogue says %.3f"
					% [key, plant["seat"], PropCatalog.seat_offset(key)])
		var want: Vector3 = PropCatalog.size(key)
		if (measured.size - want).length() > TOL:
			res.fail("%s measures %.3f x %.3f x %.3f, the catalogue says %.3f x %.3f x %.3f"
				% [key, measured.size.x, measured.size.y, measured.size.z,
					want.x, want.y, want.z])
		# The flame is where the catalogue says it is (LAY-011): a lamp whose
		# light hangs a metre from its model is a lamp somebody re-exported.
		if PropCatalog.has_tag(key, PropCatalog.LIGHT):
			var flame := Vector3(measured.get_center().x, measured.end.y, measured.get_center().z)
			if (flame - PropCatalog.light_offset(key)).length() > TOL:
				res.fail("%s has its flame at %v and the catalogue says %v"
					% [key, flame, PropCatalog.light_offset(key)])
		# A prop whose feet are not at its own origin has to be sat down by the
		# assembler, which reads the offset from the catalogue. What matters is
		# that the catalogue KNOWS -- an unrecorded offset is a floating chair.
		if PropCatalog.blocks_floor(key) and absf(measured.position.y) > 0.08:
			if absf(PropCatalog.floor_offset(key) - measured.position.y) > TOL:
				res.fail("%s sits %.2fm off its own origin and the catalogue says %.2fm"
					% [key, measured.position.y, PropCatalog.floor_offset(key)])
			else:
				res.warn("%s has its feet %.2fm from its origin; the assembler drops it"
					% [key, measured.position.y])

	_check_lights(res)

	# and every category a recipe asks for must have something in it
	for kind in HouseFurnishingRecipes.RECIPES:
		for step in HouseFurnishingRecipes.RECIPES[kind]:
			res.checked += 1
			if PropCatalog.of_category(String(step["cat"])).is_empty():
				res.fail("the %s recipe asks for a '%s' and the catalogue has none"
					% [String(kind), String(step["cat"])])
	for trade in HouseFurnishingRecipes.TRADE_FITTINGS:
		for step2 in HouseFurnishingRecipes.TRADE_FITTINGS[trade]:
			res.checked += 1
			if PropCatalog.of_category(String(step2["cat"])).is_empty():
				res.fail("the %s fittings ask for a '%s' and the catalogue has none"
					% [String(trade), String(step2["cat"])])
	return res


## Lights that light (LAY-011): an assembled house, shop and hotel carry one
## OmniLight3D for every piece of furniture the catalogue tags LIGHT, no more
## and no fewer. Indoor lights stand inside; exterior lights are checked in
## house_exterior_suite against their assembled models.
static func _check_lights(res: SuiteResult) -> void:
	var plans: Array = []
	var house := HouseSpec.new()
	house.style = &"cottage"
	house.width = 9.0
	house.length = 11.0
	plans.append(["house", HouseGenerator.generate(house, 81001), HouseAssembler.build(HouseGenerator.generate(house, 81001))])
	var shop := ShopSpec.new()
	shop.business = &"tavern"
	shop.width = 12.0
	shop.length = 15.0
	var shop_plan: HousePlan = ShopGenerator.generate(shop, 81002)
	plans.append(["shop", shop_plan, ShopAssembler.build(shop_plan)])
	var hotel := HotelSpec.new()
	var hotel_plan: HousePlan = HotelGenerator.generate(hotel, 81003)
	plans.append(["hotel", hotel_plan, HotelAssembler.build(hotel_plan)])
	for row in plans:
		var plan: HousePlan = row[1]
		var root: Node3D = row[2]
		var want := 0
		for p in plan.furniture:
			if PropCatalog.has_tag(p["key"], PropCatalog.LIGHT):
				want += 1
		var got: Array[Node] = root.get_node("Lights").find_children("*", "OmniLight3D", true, false)
		res.checked += 1
		if got.size() != want:
			res.fail("%s: %d lights for %d lamps, sconces and candles" % [row[0], got.size(), want])
		var extent: Rect2 = HouseGeometry.interior_rect(plan.spec).grow(HouseGeometry.WALL_T)
		var top: float = plan.spec.height * float(plan.spec.storeys) + 0.5
		for l in got:
			var pos: Vector3 = (l as Node3D).position
			if not extent.has_point(Vector2(pos.x, pos.z)) or pos.y < -0.1 or pos.y > top:
				res.fail("%s: a light at %v is outside the building" % [row[0], pos])
				break
		root.free()
