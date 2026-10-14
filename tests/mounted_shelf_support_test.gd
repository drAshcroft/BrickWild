extends SceneTree
## Mounted-shelf and floor-host support controls for the measured physical QA rule.

const Physical := preload("res://qa/house_furnish_physical_check.gd")
const Plan := preload("res://src/house/house_plan.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_check_mounted_shelf()
	_check_floor_host()
	for failure in failures:
		push_error(failure)
	print("mounted shelf support fixture: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_mounted_shelf() -> void:
	var plan := Plan.new()
	plan.spec = HouseSpec.new()
	plan.rooms.append({"kind": &"parlour", "storey": 0, "rect": Rect2(-2.0, -2.0, 4.0, 4.0)})
	var shelf := {"key": "Shelf_Simple", "room": 0, "storey": 0,
		"pos": Vector3(0.0, 1.6, 0.0), "yaw": 0.0,
		"rect": Rect2(-0.6, -0.25, 1.2, 0.5), "host": -1,
		"scale": 1.0, "mounted": true}
	var shelf_key := String(shelf["key"])
	var shelf_scale := PropCatalog.placement_height_scale(shelf)
	var shelf_origin := PropCatalog.house_origin(shelf)
	var shelf_top := shelf_origin.y + PropCatalog.floor_offset(shelf_key) * shelf_scale + PropCatalog.surface_height(shelf_key) * shelf_scale
	var shelf_centre := PropCatalog.plan_centre(shelf_key, shelf_origin,
		float(shelf["yaw"]) + PropCatalog.face_offset(shelf_key), 1.0)
	var book := {"key": "Book_Stack_1", "room": 0, "storey": 0,
		"pos": Vector3(shelf_centre.x, shelf_top, shelf_centre.y), "yaw": 0.0,
		"rect": Rect2(shelf_centre - Vector2(0.2, 0.1), Vector2(0.4, 0.2)), "host": 0,
		"scale": 1.0, "mounted": false}
	plan.furniture = [shelf, book]
	var supported := Physical.new()
	supported.check_supported(plan)
	if not supported.failures.is_empty():
		failures.append("book at measured mounted shelf top failed support check: %s" % supported.failures)

	var floating := book.duplicate(true)
	floating["pos"] = Vector3(book["pos"]) + Vector3.UP * 0.1
	plan.furniture = [shelf, floating]
	var unsupported := Physical.new()
	unsupported.check_supported(plan)
	if unsupported.failures.size() != 1 or not String(unsupported.failures[0]).contains("floats"):
		failures.append("book 0.1 m above mounted shelf must fail support check: %s" % unsupported.failures)
	var off_board := book.duplicate(true)
	off_board["pos"] = Vector3(book["pos"]) + Vector3.RIGHT * 1.5
	off_board["rect"] = Rect2(book["rect"])
	off_board["rect"].position += Vector2.RIGHT * 1.5
	shelf["rect"] = Rect2(-5.0, -5.0, 10.0, 10.0)
	plan.furniture = [shelf, off_board]
	var overhang := Physical.new()
	overhang.check_supported(plan)
	if overhang.failures.size() != 1 or not String(overhang.failures[0]).contains("edge"):
		failures.append("an inflated mount rectangle concealed an actual shelf overhang")


func _check_floor_host() -> void:
	var plan := Plan.new()
	plan.spec = HouseSpec.new()
	plan.rooms.append({"kind": &"parlour", "storey": 0, "rect": Rect2(-2.0, -2.0, 4.0, 4.0)})
	var chest := {"key": "Table_Large", "room": 0, "storey": 0,
		"pos": Vector3.ZERO, "yaw": 0.0, "rect": Rect2(-0.7, -0.55, 1.4, 1.1),
		"host": -1, "scale": 1.0, "mounted": false}
	var key := String(chest["key"])
	var scale := PropCatalog.placement_height_scale(chest)
	var origin := PropCatalog.house_origin(chest)
	var top := origin.y + PropCatalog.floor_offset(key) * scale + PropCatalog.surface_height(key) * scale
	var book := {"key": "Book_Stack_1", "room": 0, "storey": 0,
		"pos": Vector3(0.0, top, 0.0), "yaw": 0.0,
		"rect": Rect2(-0.2, -0.1, 0.4, 0.2), "host": 0,
		"scale": 1.0, "mounted": false}
	plan.furniture = [chest, book]
	var physical := Physical.new()
	physical.check_supported(plan)
	if not physical.failures.is_empty():
		failures.append("book at measured floor-host top failed unchanged support check: %s" % physical.failures)
