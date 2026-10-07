extends SceneTree
## Snapshot the published design scope without generating expensive buildings.
## Every row begins unreviewed. An inventory is NOT visual acceptance.
## godot --headless --path . --script res://tools/personality_inventory.gd

const OUTPUT := "res://artifacts/personality/inventory.json"
const SEEDS := [1, 8102, 21325]


func _init() -> void:
	var families: Array[Dictionary] = []
	var rows := 0
	for kind in BrickWild.kinds():
		var descriptor := BrickWild.describe_kind(kind)
		var styles: Array[Dictionary] = []
		for option in descriptor["styles"]:
			styles.append({"id": String(option["id"]), "label": String(option["label"]),
				"brief": "docs/BUILDING_PERSONALITY_BRIEFS.md", "generated": false,
				"mechanically_checked": false, "visually_reviewed": false})
			rows += 1
		families.append({"kind": String(kind), "styles": styles,
			"purposes": descriptor["purposes"], "descriptor": descriptor,
			"default_request": BrickWild.default_request(kind, 1).to_dict()})
	var revision: Array = []
	var revision_exit := OS.execute("git", ["rev-parse", "HEAD"], revision)
	var paths: Array[String] = []
	for root in ["res://src", "res://core", "res://qa", "res://tools", "res://tests"]:
		_scripts(root, paths)
	paths.sort()
	var fingerprints := PackedStringArray()
	for path in paths:
		fingerprints.append(path + ":" + FileAccess.get_sha256(path))
	var snapshot := {"purpose": "scope and source baseline; no quality claims",
		"source_revision": String(revision[0]).strip_edges() if revision_exit == 0 else "unknown",
		"script_sha256": "\n".join(fingerprints).sha256_text(),
		"script_count": paths.size(), "seed_matrix": SEEDS,
		"size_matrix": ["small", "default", "large"],
		"size_policy": "Use each family's supported envelope; never shrink furniture to fit.",
		"families": families, "style_rows": rows}
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if error != OK:
		printerr("Cannot create inventory directory: ", error_string(error))
		quit(1)
		return
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write personality inventory: ", FileAccess.get_open_error())
		quit(1)
		return
	file.store_string(JSON.stringify(snapshot, "\t") + "\n")
	file.close()
	print("Personality scope: %d families, %d style rows; %s" % [families.size(), rows, OUTPUT])
	quit()


func _scripts(path: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file in directory.get_files():
		if file.ends_with(".gd"):
			paths.append(path.path_join(file))
	for child in directory.get_directories():
		_scripts(path.path_join(child), paths)
