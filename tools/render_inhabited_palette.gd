extends "res://tools/render_shots.gd"
## Inspection boards for the current inhabited-building prop palette.
## Run with the project renderer (not --headless); every model stays at its
## measured, authored scale. This is a review aid, not a room recipe.

const PALETTE_DIR := "res://artifacts/renders/inhabited_palette"
const BOARD_WALL_MAT := Color("756d5c")
const BOARD_FLOOR_MAT := Color("514c40")
const LABEL_MAT := Color("f6e8c9")

var _palette_manifest: Array[Dictionary] = []
var _failed := false


func _init() -> void:
	_build_stage()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PALETTE_DIR))
	await process_frame
	var scenes := [
		_cooking_board(),
		_sleeping_board(),
		_sitting_board(),
		_witchwork_board(),
		_wall_light_board(),
	]
	for board in scenes:
		await _render_board(board)
	var manifest_file := FileAccess.open(PALETTE_DIR + "/manifest.json", FileAccess.WRITE)
	if manifest_file != null:
		manifest_file.store_string(JSON.stringify({
			"purpose": "Review current BrickWild models at true measured scale; boards are not room plans.",
			"units": "metres",
			"scale_policy": "No model scaling. PropCatalog measurements and HouseAssembler placement corrections are used.",
			"boards": _palette_manifest,
			"known_gaps": ["dedicated water jug or basin", "herb bundles", "domestic soft furnishings"],
		}, "\t"))
		manifest_file.close()
	else:
		_failed = true
		printerr("Could not write palette manifest")
	print("INHABITED_PALETTE_MANIFEST ", PALETTE_DIR + "/manifest.json")
	quit(1 if _failed else 0)


func _cooking_board() -> Dictionary:
	return {
		"id": "cooking", "title": "COOK + PREP — current models",
		"note": "Water handling is still only a bucket. No dedicated basin.",
		"placements": [
			{"key": "Workbench", "pos": Vector3(-0.1, 0.0, 1.0), "role": "full-size prep surface; 0.9 m use zone"},
			{"key": "Cauldron", "pos": Vector3(-2.2, 0.0, 1.1), "role": "wall-backed heat focus"},
			{"key": "Pot_1", "pos": Vector3(-0.55, PropCatalog.surface_height("Workbench"), 1.0), "role": "cookware on measured worktop"},
			{"key": "Bucket_Wooden_1", "pos": Vector3(1.65, 0.0, -0.3), "role": "water carrier only; empty asset"},
			{"key": "Barrel_Apples", "pos": Vector3(2.1, 0.0, 0.8), "role": "bulk food storage"},
			{"key": "Cabinet", "pos": Vector3(1.3, 0.0, 1.35), "role": "closed storage"},
		],
	}


func _sleeping_board() -> Dictionary:
	return {
		"id": "sleeping", "title": "SLEEP + REST — current models",
		"note": "Nightstand_Shelf is 1.216 m tall; chest shown as lower bedside storage.",
		"placements": [
			{"key": "Bed_Twin1", "pos": Vector3(-0.35, 0.0, 0.35), "role": "quiet-wall bed; approach kept clear at foot"},
			{"key": "Chest_Wood", "pos": Vector3(1.9, 0.0, -0.1), "role": "low storage within reach"},
			{"key": "Nightstand_Shelf", "pos": Vector3(-1.85, 0.0, 0.0), "role": "scale-check candidate; unusually tall"},
			{"key": "CandleStick_Stand", "pos": Vector3(2.35, 0.0, 0.75), "role": "standing secondary light"},
		],
	}


func _sitting_board() -> Dictionary:
	return {
		"id": "sitting", "title": "SIT + EAT — current models",
		"note": "Long table and bench are each about 2.8 m; allow seat pull-back in rooms.",
		"placements": [
			{"key": "Table_Large", "pos": Vector3(0.0, 0.0, 0.0), "role": "2.848 m table; measured top supports meal"},
			{"key": "Bench", "pos": Vector3(0.0, 0.0, -1.05), "yaw": PI, "role": "long settle, facing table"},
			{"key": "Chair_1", "pos": Vector3(-2.05, 0.0, 0.0), "yaw": -PI / 2.0, "role": "single chair; facing table"},
			{"key": "Stool", "pos": Vector3(2.0, 0.0, 0.0), "role": "small movable seat"},
			{"key": "Mug", "pos": Vector3(-0.65, PropCatalog.surface_height("Table_Large"), 0.0), "role": "tabletop drinkware"},
			{"key": "Table_Plate", "pos": Vector3(0.15, PropCatalog.surface_height("Table_Large"), -0.05), "role": "tabletop place setting"},
			{"key": "CandleStick", "pos": Vector3(0.78, PropCatalog.surface_height("Table_Large"), 0.1), "role": "table light"},
		],
	}


func _witchwork_board() -> Dictionary:
	return {
		"id": "witchwork", "title": "WITCHWORK — current models",
		"note": "Interior work group exists as assets; herb bed/drying line remain exterior. No herb bundle asset.",
		"placements": [
			{"key": "Workbench", "pos": Vector3(0.1, 0.0, 0.45), "role": "working surface; 0.9 m approach"},
			{"key": "Cauldron", "pos": Vector3(-2.25, 0.0, 0.1), "role": "heat/process focus"},
			{"key": "Shelf_Small_Bottles", "pos": Vector3(0.1, 2.0, 1.56), "role": "wall-mounted storage, face correction applied"},
			{"key": "SmallBottles_1", "pos": Vector3(0.45, PropCatalog.surface_height("Workbench"), 0.45), "role": "small vessels on the workbench"},
			{"key": "Potion_1", "pos": Vector3(-0.6, PropCatalog.surface_height("Workbench"), 0.45), "role": "measured on-surface vessel"},
			{"key": "Potion_2", "pos": Vector3(0.0, PropCatalog.surface_height("Workbench"), 0.45), "role": "measured on-surface vessel"},
			{"key": "Book_Stack_1", "pos": Vector3(0.75, PropCatalog.surface_height("Workbench"), 0.45), "role": "reference material on bench"},
			{"key": "Wild_Mushroom_Common", "pos": Vector3(2.1, 0.0, 0.5), "role": "foraged yard ingredient; not a dried herb bundle"},
		],
	}


func _wall_light_board() -> Dictionary:
	return {
		"id": "wall_light", "title": "WALL + LIGHT — current models",
		"note": "Indoor fittings shown. Lantern_Wall is intentionally excluded: catalogue marks it OUTDOOR.",
		"placements": [
			{"key": "Shelf_Arch", "pos": Vector3(-1.75, 1.45, 1.56), "role": "wall-mounted display shelf; measured full height"},
			{"key": "Peg_Rack", "pos": Vector3(0.0, 1.7, 1.56), "role": "wall pegs near a household work zone"},
			{"key": "Torch_Metal", "pos": Vector3(1.6, 1.7, 1.56), "role": "wall task light"},
			{"key": "Chandelier", "pos": Vector3(0.0, 2.8, -0.8), "role": "ceiling light; place over a room focus"},
			{"key": "CandleStick_Stand", "pos": Vector3(2.4, 0.0, -0.1), "role": "standing light"},
		],
	}


func _render_board(board: Dictionary) -> void:
	var group := Node3D.new()
	group.name = String(board["id"])
	_root3d.add_child(group)
	_add_board_surfaces(group)
	var heading := Label.new()
	heading.text = String(board["title"]) + "\n" + String(board["note"])
	heading.position = Vector2(24, 20)
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", Color("202018"))
	_vp.add_child(heading)
	var rows: Array[Dictionary] = []
	for placement in board["placements"]:
		var key := String(placement["key"])
		placement["yaw"] = float(placement.get("yaw", 0.0))
		if not PropCatalog.known(key):
			_failed = true
			push_error("Palette render requested missing prop: " + key)
			continue
		var node := HouseAssembler._instance(placement, false)
		if node == null:
			_failed = true
			push_error("Palette render could not load model: " + key)
			continue
		node.name = key
		group.add_child(node)
		var size := PropCatalog.size(key)
		var pos: Vector3 = placement["pos"]
		rows.append({
			"key": key,
			"role": String(placement["role"]),
			"size_m": [size.x, size.y, size.z],
			"pos_m": [pos.x, pos.y, pos.z],
			"yaw_rad": float(placement.get("yaw", 0.0)),
			"face_correction_rad": PropCatalog.face_offset(key),
			"scale": 1.0,
			"scene": PropCatalog.scene_path(key),
		})
	var focus := Vector3(0.0, 1.1, 0.0)
	_cam.position = Vector3(3.8, 3.8, -6.5)
	_cam.look_at(focus, Vector3.UP)
	var file := String(board["id"]) + ".jpg"
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _vp.get_texture().get_image()
	var output := PALETTE_DIR + "/" + file
	var result := image.save_jpg(output, 0.94)
	if result != OK:
		_failed = true
		push_error("Could not save palette render: " + output)
	else:
		print("INHABITED_PALETTE_RENDER ", output)
	_palette_manifest.append({
		"id": String(board["id"]), "title": String(board["title"]),
		"note": String(board["note"]), "image": output, "props": rows,
	})
	group.queue_free()
	heading.queue_free()
	await process_frame


func _add_board_surfaces(parent: Node3D) -> void:
	var floor := _box_mesh(Vector3(10.0, 0.12, 7.0), BOARD_FLOOR_MAT)
	floor.position = Vector3(0.0, -0.08, 0.0)
	parent.add_child(floor)
	var back := _box_mesh(Vector3(10.0, 3.1, 0.18), BOARD_WALL_MAT)
	back.position = Vector3(0.0, 1.5, 1.65)
	parent.add_child(back)


func _box_mesh(dimensions: Vector3, color: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh_node.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	mesh_node.material_override = material
	return mesh_node


func _add_label(parent: Node3D, text: String, at: Vector3, size: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = 30
	label.pixel_size = size / 30.0
	label.modulate = LABEL_MAT
	label.outline_size = 4
	label.outline_modulate = Color("29251f")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
