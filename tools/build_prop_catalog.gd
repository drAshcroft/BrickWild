extends SceneTree
## Measures the owned prop packs and writes assets/props/catalog.json.
##
## Default (or --full) reloads and measures every model and refreshes a local
## fingerprint cache. --incremental reuses only packs whose complete source
## tree, import settings, measurement code and engine version still match.
## --verify-parity performs a full measurement, reloads its cache from disk,
## then requires the incremental serializer to produce identical bytes.
##
## Run: godot --headless --path . --script res://tools/build_prop_catalog.gd
## Fast repeat: godot --headless --path . --script res://tools/build_prop_catalog.gd -- --incremental

const OUT := "res://assets/props/catalog.json"
# Keep the cache beside Godot's other project-local generated state. This is
# ignored by git and remains writable in managed workspaces where user:// may
# be intentionally read-only.
const CACHE_PATH := "res://.godot/prop_catalog_cache.json"
const CatalogCache := preload("res://tools/prop_catalog_cache.gd")


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var verify: bool = args.has("--verify-parity")
	var incremental: bool = args.has("--incremental")
	if args.has("--full"):
		incremental = false
	if verify:
		incremental = false
	var paths: Array[String] = []
	var pack_of: Dictionary = {}
	var paths_by_pack: Dictionary = {}
	var pack_names: Array[String] = []
	for pack_name in PropCatalog.PACKS:
		pack_names.append(str(pack_name))
		paths_by_pack[str(pack_name)] = []
		var pack: Dictionary = PropCatalog.PACKS[pack_name]
		var pack_dir: String = "res://assets/props/%s" % pack["dir"]
		var dir := DirAccess.open(pack_dir)
		if dir == null:
			printerr("no prop directory at %s" % pack_dir)
			continue
		var suffix: String = ".%s" % pack["ext"]
		for filename in dir.get_files():
			if filename.ends_with(suffix):
				var path: String = "%s/%s" % [pack_dir, filename]
				paths.append(path)
				pack_of[path] = str(pack_name)
				paths_by_pack[str(pack_name)].append(path)
	paths.sort()
	pack_names.sort()
	for pack_name in pack_names:
		paths_by_pack[pack_name].sort()

	var old_cache: Dictionary = CatalogCache.load_cache(CACHE_PATH)
	var result: Dictionary = _build_catalog(paths, pack_names, paths_by_pack,
		pack_of, incremental, old_cache)
	if not result["ok"]:
		printerr(result["error"])
		quit(1)
		return
	var rows: Dictionary = result["rows"]
	var cache: Dictionary = result["cache"]
	var catalog_bytes: String = JSON.stringify(rows, "\t", true)
	if verify:
		if not CatalogCache.store_cache(CACHE_PATH, cache):
			printerr("could not write catalog cache at %s" % CACHE_PATH)
			quit(1)
			return
		var disk_cache: Dictionary = CatalogCache.load_cache(CACHE_PATH)
		var parity: Dictionary = _build_catalog(paths, pack_names, paths_by_pack,
			pack_of, true, disk_cache)
		if not parity["ok"]:
			printerr(parity["error"])
			quit(1)
			return
		var incremental_bytes: String = JSON.stringify(parity["rows"], "\t", true)
		if catalog_bytes != incremental_bytes:
			printerr("incremental catalogue differs from full measurement byte-for-byte")
			quit(1)
			return
		print("byte parity: full measurement equals cache-backed incremental output")
		result["reused"] = parity["reused"]
		result["reused_packs"] = parity["reused_packs"]
		result["measured"] += parity["measured"]

	var output := FileAccess.open(OUT, FileAccess.WRITE)
	if output == null:
		printerr("could not write measured catalogue at %s" % OUT)
		quit(1)
		return
	output.store_string(catalog_bytes)
	output.close()
	if not CatalogCache.store_cache(CACHE_PATH, cache):
		printerr("could not write catalog cache at %s" % CACHE_PATH)
		quit(1)
		return
	print("catalogue has %d props; measured %d, reused %d packs (%d props) -> %s"
		% [rows.size(), result["measured"], result["reused_packs"], result["reused"], OUT])
	quit(0)


func _build_catalog(paths: Array[String], pack_names: Array[String], paths_by_pack: Dictionary,
		pack_of: Dictionary, use_cache: bool, old_cache: Dictionary) -> Dictionary:
	var cache := {"schema": CatalogCache.SCHEMA, "packs": {}}
	var rows_by_pack := {}
	var reused_props := 0
	var reused_packs := 0
	var measured := 0
	for pack_name in pack_names:
		var pack: Dictionary = PropCatalog.PACKS[pack_name]
		var fingerprint: String = CatalogCache.pack_fingerprint(pack_name, pack)
		if fingerprint == "":
			return {"ok": false, "error": "could not fingerprint %s prop inputs" % pack_name}
		var props: Array[String] = []
		for path in paths_by_pack[pack_name]:
			props.append(path.get_file().get_basename())
		var measured_rows: Dictionary = {}
		if use_cache and CatalogCache.cache_pack_is_valid(old_cache,
				pack_name, fingerprint, props):
			measured_rows = old_cache["packs"][pack_name]["props"]
			reused_props += props.size()
			reused_packs += 1
		else:
			for path in paths_by_pack[pack_name]:
				var prop_name: String = path.get_file().get_basename()
				var packed: PackedScene = load(path)
				if packed == null:
					return {"ok": false, "error": "could not load %s" % path}
				var node: Node = packed.instantiate()
				var plant := {}
				if PropCatalog.is_plant_pack(pack_name):
					plant = SceneBounds.plant_of_node(node)
				var aabb: AABB = plant["box"] if plant.has("box") else SceneBounds.of_node(node)
				node.free()
				var row := {
					"size": [snappedf(aabb.size.x, 0.001), snappedf(aabb.size.y, 0.001),
						snappedf(aabb.size.z, 0.001)],
					"centre": [snappedf(aabb.get_center().x, 0.001),
						snappedf(aabb.get_center().y, 0.001), snappedf(aabb.get_center().z, 0.001)],
					"floor": snappedf(aabb.position.y, 0.001),
					"light": [snappedf(aabb.get_center().x, 0.001), snappedf(aabb.end.y, 0.001),
						snappedf(aabb.get_center().z, 0.001)],
				}
				if not plant.is_empty():
					row["canopy"] = plant["canopy"]
					row["trunk"] = plant["trunk"]
				measured_rows[prop_name] = row
				measured += 1
		cache["packs"][pack_name] = {"fingerprint": fingerprint, "props": measured_rows}
		rows_by_pack[pack_name] = measured_rows

	var rows := {}
	for path in paths:
		var prop_name: String = path.get_file().get_basename()
		var pack_name: String = pack_of[path]
		if rows.has(prop_name):
			return {"ok": false, "error": "duplicate catalogue key %s" % prop_name}
		if not rows_by_pack[pack_name].has(prop_name):
			return {"ok": false, "error": "cache omitted measured prop %s" % prop_name}
		rows[prop_name] = rows_by_pack[pack_name][prop_name]
	return {"ok": true, "rows": rows, "cache": cache, "measured": measured,
		"reused": reused_props, "reused_packs": reused_packs}
