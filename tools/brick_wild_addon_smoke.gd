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
	var repeat := BrickWild.generate(BuildingRequest.church(101))
	if repeat.name() != BrickWild.generate(BuildingRequest.church(101)).name():
		printerr("same-seed generation was not deterministic")
		failed = true
	print("BRICKWILD_ADDON_SMOKE_OK")
	quit(1 if failed else 0)
