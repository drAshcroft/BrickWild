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
		var measured: AABB = SceneBounds.of_node(node)
		node.queue_free()
		var want: Vector3 = PropCatalog.size(key)
		if (measured.size - want).length() > TOL:
			res.fail("%s measures %.3f x %.3f x %.3f, the catalogue says %.3f x %.3f x %.3f"
				% [key, measured.size.x, measured.size.y, measured.size.z,
					want.x, want.y, want.z])
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

	# and every category a recipe asks for must have something in it
	for kind in HouseFurnisher.RECIPES:
		for step in HouseFurnisher.RECIPES[kind]:
			res.checked += 1
			if PropCatalog.of_category(String(step["cat"])).is_empty():
				res.fail("the %s recipe asks for a '%s' and the catalogue has none"
					% [String(kind), String(step["cat"])])
	for trade in HouseFurnisher.TRADE_FITTINGS:
		for step2 in HouseFurnisher.TRADE_FITTINGS[trade]:
			res.checked += 1
			if PropCatalog.of_category(String(step2["cat"])).is_empty():
				res.fail("the %s fittings ask for a '%s' and the catalogue has none"
					% [String(trade), String(step2["cat"])])
	return res
