extends RefCounted
## Small source-cache controls. Does not instantiate imported props or run the
## full catalogue sweep; that remains a separate oracle command.

const CatalogCache := preload("res://tools/prop_catalog_cache.gd")


static func run() -> SuiteResult:
	var res := SuiteResult.new("catalog cache")
	var root := "user://catalog-cache-%d" % Time.get_ticks_usec()
	var absolute: String = ProjectSettings.globalize_path(root)
	DirAccess.make_dir_recursive_absolute(absolute)
	var model := root.path_join("Prop.gltf")
	var buffer := root.path_join("nested").path_join("Prop.bin")
	_write(model, "scene source", res)
	_write(buffer, "mesh buffer v1", res)
	var baseline: String = CatalogCache.fingerprint_tree_for_test(root)
	_expect(baseline != "", "cache path fingerprints", res)
	_expect(CatalogCache.fingerprint_tree_for_test(root) == baseline,
		"unchanged source fingerprints deterministically", res)
	_write(buffer, "mesh buffer v2", res)
	var dependency_changed: String = CatalogCache.fingerprint_tree_for_test(root)
	_expect(dependency_changed != baseline, "external mesh-buffer edit invalidates pack", res)
	_write(root.path_join("Added.import"), "new import settings", res)
	var added: String = CatalogCache.fingerprint_tree_for_test(root)
	_expect(added != dependency_changed, "new file invalidates pack", res)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root.path_join("Added.import")))
	var removed: String = CatalogCache.fingerprint_tree_for_test(root)
	_expect(removed == dependency_changed, "removed file restores prior fingerprint", res)

	var expected: Array[String] = ["Prop"]
	var expected_after_add: Array[String] = ["Prop", "Added"]
	var row := {"size": [1.0, 2.0, 3.0], "centre": [0.0, 1.0, 0.0],
		"light": [0.0, 2.0, 0.0], "floor": 0.0}
	var cache := {"schema": CatalogCache.SCHEMA, "packs": {
		"fantasy": {"fingerprint": "matching", "props": {"Prop": row}}}}
	_expect(CatalogCache.cache_pack_is_valid(cache, "fantasy", "matching", expected),
		"complete matching pack cache reused", res)
	_expect(not CatalogCache.cache_pack_is_valid(cache, "fantasy", "changed", expected),
		"changed source fingerprint forces measurement", res)
	_expect(not CatalogCache.cache_pack_is_valid(cache, "fantasy", "matching", expected_after_add),
		"added scene forces measurement", res)
	var corrupt := cache.duplicate(true)
	corrupt["packs"]["fantasy"]["props"]["Prop"]["size"] = [1.0]
	_expect(not CatalogCache.cache_pack_is_valid(corrupt, "fantasy", "matching", expected),
		"malformed cached dimensions force measurement", res)
	var old_schema := cache.duplicate(true)
	old_schema["schema"] = CatalogCache.SCHEMA - 1
	_expect(not CatalogCache.cache_pack_is_valid(old_schema, "fantasy", "matching", expected),
		"cache ABI change forces measurement", res)
	_cleanup(root)
	return res


static func _write(path: String, value: String, res: SuiteResult) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	res.checked += 1
	if file == null:
		res.fail("could not create source-cache fixture %s" % path)
		return
	file.store_string(value)
	file.close()


static func _expect(condition: bool, detail: String, res: SuiteResult) -> void:
	res.checked += 1
	if not condition:
		res.fail("%s" % detail)


static func _cleanup(root: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(root)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root.path_join("nested").path_join("Prop.bin")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root.path_join("Prop.gltf")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root.path_join("nested")))
	DirAccess.remove_absolute(absolute)
