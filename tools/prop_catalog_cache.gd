extends RefCounted
## Exact, source-fingerprinted pack cache for the measured prop catalogue.

const SCHEMA := 1
const MEASURE_INPUTS: Array[String] = [
	"res://tools/build_prop_catalog.gd",
	"res://tools/prop_catalog_cache.gd",
	"res://core/scene_bounds.gd",
	"res://src/house/prop_catalog.gd",
	"res://project.godot",
]


static func pack_fingerprint(pack_name: String, pack: Dictionary) -> String:
	var pack_dir := "res://assets/props/%s" % String(pack.get("dir", ""))
	var files: Variant = _tree_hashes(pack_dir)
	if files == null:
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(pack_dir)):
			return ""
		files = [{"missing_directory": true}]
	var inputs: Array[Dictionary] = []
	for path in MEASURE_INPUTS:
		var digest: String = _file_hash(path)
		if digest == "":
			return ""
		inputs.append({"path": path, "sha256": digest})
	var version: Dictionary = Engine.get_version_info()
	var material := {
		"schema": SCHEMA,
		"pack": pack_name,
		"pack_info": pack,
		"engine": version.get("string", "unknown"),
		"inputs": inputs,
		"pack_files": files,
	}
	return JSON.stringify(material, "", true).sha256_text()


static func cache_pack_is_valid(cache: Dictionary, pack_name: String,
		fingerprint: String, expected_props: Array[String]) -> bool:
	if int(cache.get("schema", -1)) != SCHEMA:
		return false
	var packs: Variant = cache.get("packs", {})
	if not packs is Dictionary or not packs.has(pack_name):
		return false
	var pack_entry: Variant = packs[pack_name]
	if not pack_entry is Dictionary or str(pack_entry.get("fingerprint", "")) != fingerprint:
		return false
	var props: Variant = pack_entry.get("props", {})
	if not props is Dictionary or props.size() != expected_props.size():
		return false
	for prop_name in expected_props:
		if not props.has(prop_name) or not _valid_measurement(props[prop_name]):
			return false
	return true


static func load_cache(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary and int(parsed.get("schema", -1)) == SCHEMA else {}


static func store_cache(path: String, cache: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(cache, "\t", true))
	file.close()
	return true


static func fingerprint_tree_for_test(root: String) -> String:
	var files: Variant = _tree_hashes(root)
	if files == null:
		return ""
	return JSON.stringify(files, "", true).sha256_text()


static func _tree_hashes(root: String) -> Variant:
	var dir := DirAccess.open(root)
	if dir == null:
		return null
	var paths: Array[String] = []
	_collect_files(root.trim_suffix("/"), paths)
	paths.sort()
	var result: Array[Dictionary] = []
	for path in paths:
		var digest: String = _file_hash(path)
		if digest == "":
			return null
		result.append({"path": path.trim_prefix(root.trim_suffix("/") + "/"), "sha256": digest})
	return result


static func _collect_files(here: String, out: Array[String]) -> void:
	var files: PackedStringArray = DirAccess.get_files_at(here)
	files.sort()
	for name in files:
		out.append(here.path_join(name))
	var directories: PackedStringArray = DirAccess.get_directories_at(here)
	directories.sort()
	for child in directories:
		_collect_files(here.path_join(child), out)


static func _file_hash(path: String) -> String:
	var absolute: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute):
		return ""
	return FileAccess.get_sha256(absolute)


static func _valid_measurement(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for vector_key in ["size", "centre", "light"]:
		var vector: Variant = value.get(vector_key)
		if not vector is Array or vector.size() != 3:
			return false
		for component in vector:
			if not (component is float or component is int) or not is_finite(float(component)):
				return false
	var floor: Variant = value.get("floor")
	if not (floor is float or floor is int) or not is_finite(float(floor)):
		return false
	for optional_key in ["canopy", "trunk"]:
		if value.has(optional_key):
			var metric: Variant = value[optional_key]
			if not (metric is float or metric is int) or not is_finite(float(metric)):
				return false
	return value.has("canopy") == value.has("trunk")
