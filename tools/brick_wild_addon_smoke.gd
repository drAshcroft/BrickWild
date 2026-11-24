extends SceneTree

# The consumer-side smoke for the BrickWild addon. It runs inside a fresh
# Godot project that has nothing but addons/brick_wild installed, so every
# class it names must come from the package. Used by
# test_brick_wild_addon_installer.ps1 and by release_brick_wild.ps1, which runs
# it against the frozen release, through the release's own install.ps1.

func _init() -> void:
	var failed := false
	var requests := [
		BuildingRequest.church(101),
		BuildingRequest.castle(102),
		BuildingRequest.house(103),
		BuildingRequest.shop(105),
		BuildingRequest.hotel(106),
		BuildingRequest.temple(104),
		BrickWild.default_request(&"world", 107),
	]
	for request in requests:
		var generated := BrickWild.generate_document(request)
		if not generated.is_ok():
			printerr("generation failed: %s" % generated.errors)
			failed = true
			continue
		var mesh := BrickWild.build_mesh(generated)
		if mesh == null or mesh.get_surface_count() == 0:
			printerr("mesh emission failed for %s" % request.kind)
			failed = true
		var node := BrickWild.instantiate(generated)
		if node == null:
			printerr("scene instantiation failed for %s" % request.kind)
			failed = true
		else:
			node.free()
		var restored := BuildingDocument.from_json(generated.to_json())
		if not restored.is_ok() or BrickWild.build_mesh(restored) == null:
			printerr("document round trip failed for %s" % request.kind)
			failed = true
	for key in PropCatalog.keys():
		if not ResourceLoader.exists(PropCatalog.scene_path(key)):
			printerr("prop resource missing: %s" % key)
			failed = true
	# VILLAGE-VERNACULAR: the regional dataset is a JSON file beside the village
	# scripts, not a script -- it ships only by the manifest's `files` entry, so
	# prove it arrived, and that a regional look reaches a house
	var regions := VillageVernacular.region_ids()
	for want in [&"provence", &"cyclades", &"norse", &"japanese"]:
		if not want in regions:
			printerr("vernacular region missing from the addon: %s (have %s)" % [want, regions])
			failed = true
	if &"cyclades" in regions:
		var g := VillageVernacular.house_of_type(&"cyclades", "cube", "smoke")
		var regional := BuildingRequest.house(108, g["style"], &"none", 7.0, 9.0, 2.6, 1)
		regional.look = g["look"]
		var built := BrickWild.generate(regional)
		if not built.is_ok() or (built.spec as HouseSpec).roof_type != &"flat" \
				or (built.spec as HouseSpec).wall_color.to_html(false) != String(g["look"]["wall"][0]):
			printerr("a regional look did not reach its house: %s" % [built.errors])
			failed = true
	# VILLAGE-PLACE: a place described by its features must make a region row
	# inside the addon, by preset and by bare numbers, and its request must be
	# one the library accepts
	for place in [{"like": "nordic_mountain"}, {"heat": 0.9, "rain": 0.1, "wealth": 0.2, "upkeep": 0.1}]:
		var made: Dictionary = VillagePlace.ensure(place)
		var row: Dictionary = VillageVernacular.region(made["id"])
		if not (made["errors"] as Array).is_empty() or (row.get("houses", {}) as Dictionary).is_empty():
			printerr("a place made no region row in the addon: %s %s" % [place, made["errors"]])
			failed = true
	var place_errors: Array = BuildingLibrary.validate(VillagePlace.request(7, 30, "british_hamlet"))
	if not place_errors.is_empty():
		printerr("a place request was refused in the addon: %s" % [place_errors])
		failed = true
	# CITY-GROUND-CONTRACT (0.1.9): a caller that shapes its own ground. Inside
	# the addon the easing must halve a hill's slope and leave the grid's border
	# where the caller put it, the lift must be the difference on the same
	# lattice, the measure cache must hand back the building it kept, and a house
	# must say what it builds at the ground, outside its own clear floor
	var hill := VillageTerrain.from_sampler(func(x: float, _z: float) -> float: return 0.05 * x,
		Rect2(-100.0, -100.0, 200.0, 200.0), 5.0)
	var eased: Dictionary = VillageGroundEasing.eased(hill, 0.5)
	var eased_ground: VillageTerrain = eased["terrain"]
	var lift: VillageTerrain = VillageGroundEasing.lift(hill, eased_ground)
	if not eased_ground.valid() or absf(eased_ground.height_at(Vector2(50.0, 0.0)) - 1.25) > 0.01 \
			or lift.heights.size() != hill.heights.size() or absf(lift.heights[0]) > 0.001 \
			or float(eased["cut_max_m"]) <= 0.0:
		printerr("the ground was not eased in the addon: %s at (50, 0), lift %s at the corner, cut %s" % [
			eased_ground.height_at(Vector2(50.0, 0.0)), lift.heights[0], eased["cut_max_m"]])
		failed = true
	var cache := VillageMeasureCache.new()
	var cottage := BuildingRequest.house(103)
	var job: Dictionary = cache.measure(cottage, true)
	if job.is_empty() or job.get("building") == null \
			or cache.measure(cottage, true).get("building") != job["building"]:
		printerr("the measure cache did not keep a house's measurement in the addon")
		failed = true
	else:
		var family := BuildingFamilyAdapter.for_building(job["building"])
		var outline: Array[PackedVector2Array] = family.ground_outline(job["building"])
		var floor_rect: Rect2 = family.footprint(job["building"])
		var built := Rect2()
		if not outline.is_empty():
			built = Rect2(outline[0][0], Vector2.ZERO)
			for p in outline[0]:
				built = built.expand(p)
		if outline.is_empty() or not built.encloses(floor_rect) or built.get_area() <= floor_rect.get_area():
			printerr("a house's ground outline does not stand outside its floor in the addon: %s against %s" % [
				built, floor_rect])
			failed = true
	var repeat := BrickWild.generate(BuildingRequest.church(101))
	if repeat.name() != BrickWild.generate(BuildingRequest.church(101)).name():
		printerr("same-seed generation was not deterministic")
		failed = true
	print("BRICKWILD_ADDON_SMOKE_OK")
	quit(1 if failed else 0)
