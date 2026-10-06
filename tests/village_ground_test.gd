extends RefCounted
## vground: every model a village sets down stands on the ground, and the open
## land between lots is dressed (walk QA, Wolfmarch Green -- english farming,
## seed 1, the village the pins were taken in).
##
## The negative controls replay the two defects the walk found, on the same
## assembled scene: the bush sat on its buried stem stub (catalogue floor in
## place of its seat) and the yard cart sat on its declared, turned box (the
## old floor of -1.404 at the yard's 0.4 scale). Then a plain lift and a plain
## sink, so the check is shown to fire both ways.

const REQUEST := '{"enclosure": "none", "height": 1.0, "kind": "village", "length": 35.0, "material": "timber", "orientation": 0.0, "period": 1200, "purpose": "farming", "schema": "brickwild.request", "schema_version": 1, "seed": "1", "storeys": 1, "style": "english", "water": "none", "width": 40.0}'
## Dungeon_Cart's floor as the catalogue measured it from its declared box,
## before SceneBounds measured turned meshes by their vertices.
const OLD_CART_FLOOR := -1.404
const Decoration := preload("res://tests/village_decoration_test.gd")


static func run() -> SuiteResult:
	var res := SuiteResult.new("vground")
	var built: GeneratedBuilding = BrickWild.generate(BuildingRequest.from_json(REQUEST))
	res.checked += 1
	if built == null or not built.is_ok() or built.village == null:
		res.fail("Wolfmarch Green did not generate")
		return res
	var plan: VillagePlan = built.village
	var scene: Node3D = VillageAssembler.build(plan)

	# --- the positive case: the pinned village stands on its ground
	var check := VillageGroundCheck.new()
	var report: Dictionary = check.check(plan, scene)
	res.checked += 1
	for f in report["failures"]:
		res.fail("Wolfmarch Green: %s" % f)
	var stats: Dictionary = report["stats"]
	print("  vground: %d props, %d plants, %d yard models; worst gap %.3f m"
		% [stats["props"], stats["plants"], stats["yard"], stats["worst"]])
	res.checked += 1
	if int(stats["plants"]) < 20 or int(stats["yard"]) < 5:
		res.fail("the check measured too little to mean anything: %s" % str(stats))

	# --- the open ground is dressed, and only at a decoration above zero
	res.checked += 1
	var open_plants := plan.plants.filter(func(t: Dictionary) -> bool:
		return t.get("zone", &"") == &"open")
	if open_plants.size() < 6:
		res.fail("open ground: only %d plants in the open land between lots" % open_plants.size())
	res.checked += 1
	var plain: VillagePlan = Decoration._redressed(plan, 0.0, plan.spec.upkeep)
	if plain.plants.any(func(t: Dictionary) -> bool: return t.get("zone", &"") == &"open"):
		res.fail("open ground: decoration 0 still dressed the open land")
	var qa: Dictionary = VillageQA.new().check(plan, {}, false)
	res.checked += 1
	for f in qa["failures"]:
		res.fail("Wolfmarch Green QA: %s" % f)

	# --- negative controls, on the same scene
	var bush := _first(scene.get_node("Plants"), plan.plants, "Wild_Bush_Common")
	res.checked += 1
	if bush == null:
		res.fail("negative control: no Wild_Bush_Common in the pinned village to replay pin 1 with")
	else:
		var keep: Vector3 = bush.position
		var t: Dictionary = plan.plants[VillageGroundCheck._index_of(bush)]
		var s: float = float(t.get("scale", 1.0))
		bush.position.y = VillageBuilder.ground_height(plan, t["pos"]) - VillageAssembler.PLANT_SINK \
			- PropCatalog.floor_offset("Wild_Bush_Common") * s
		_expect_fail(res, check, plan, scene, "floats", "pin 1 replay (bush on its stem stub)")
		bush.position = keep
	var cart := _yard_model(scene, "Dungeon_Cart")
	res.checked += 1
	if cart == null:
		res.fail("negative control: no yard cart in the pinned village to replay pin 3 with")
	else:
		var keep2: Vector3 = cart.position
		var row_scale: float = cart.scale.x
		# where the old catalogue floor put it: its stand height less the old drop
		cart.position.y = keep2.y + PropCatalog.floor_offset("Dungeon_Cart") * row_scale \
			- OLD_CART_FLOOR * row_scale
		_expect_fail(res, check, plan, scene, "floats", "pin 3 replay (cart on its turned box)")
		cart.position = keep2
	var prop: Node3D = null
	for n in scene.get_node("Props").get_children():
		prop = n as Node3D
		break
	if prop != null:
		var keep3: Vector3 = prop.position
		prop.position.y -= 0.3
		_expect_fail(res, check, plan, scene, "sunk", "a prop pushed 0.3 m into the ground")
		prop.position = keep3
	var any_plant := scene.get_node("Plants").get_child(0) as Node3D
	var keep4: Vector3 = any_plant.position
	any_plant.position.y += 0.25
	_expect_fail(res, check, plan, scene, "floats", "a plant lifted 0.25 m")
	any_plant.position = keep4
	# and the scene, restored, is clean again: the controls changed nothing
	res.checked += 1
	if not check.check(plan, scene)["ok"]:
		res.fail("negative controls did not restore the scene")
	scene.free()
	return res


static func _expect_fail(res: SuiteResult, check: VillageGroundCheck, plan: VillagePlan,
		scene: Node3D, word: String, what: String) -> void:
	res.checked += 1
	var r: Dictionary = check.check(plan, scene)
	var hit := false
	for f in r["failures"]:
		hit = hit or String(f).contains(word)
	if not hit:
		res.fail("negative control: the ground check did not catch %s" % what)


static func _first(parent: Node, rows: Array, key: String) -> Node3D:
	for n in parent.get_children():
		var i := VillageGroundCheck._index_of(n)
		if i >= 0 and i < rows.size() and String(rows[i]["key"]) == key:
			return n as Node3D
	return null


static func _yard_model(scene: Node3D, key: String) -> Node3D:
	for b in scene.get_node("Buildings").get_children():
		for row in b.get_meta(&"stands", []):
			if String(row["key"]) == key:
				var n := b.get_node_or_null("Exterior/%s" % String(row["id"]))
				if n != null:
					return n as Node3D
	return null

