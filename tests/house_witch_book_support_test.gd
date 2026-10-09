extends SceneTree
## Required Witchwork book-support regression. Root runs this in Godot after rebasing.
## Checks the reported public request, all nine frozen Witch requests, and an
## obstructed measured workbench top.

const REQUESTS := "res://tests/fixtures/personality/witch_requests.json"
var failures: Array[String] = []

func _init() -> void:
	_check_exact_reported_request()
	_check_frozen_witch_matrix()
	_check_fully_obstructed_support_negative()
	for failure in failures:
		printerr("FAIL " + failure)
	print("witch required book support fixture: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_exact_reported_request() -> void:
	var request := _make_request(11.0, 14.0, 2.6, 1)
	_check_request(request, "witch_hut_ample_1")


func _check_frozen_witch_matrix() -> void:
	var root: Variant = JSON.parse_string(FileAccess.get_file_as_string(REQUESTS))
	if not root is Dictionary or not root.get("cases", null) is Array:
		failures.append("frozen WITCH request matrix is unreadable")
		return
	var found := 0
	for raw in root["cases"]:
		if not raw is Dictionary or String(raw.get("role", "")) != "witch":
			continue
		found += 1
		var request := BuildingRequest.from_dict(raw.get("request", {}))
		_check_request(request, String(raw.get("id", "<missing>")))
	if found != 9:
		failures.append("frozen WITCH matrix has %d requests; expected 9" % found)


func _make_request(width: float, length: float, height: float,
		seed_value: int) -> BuildingRequest:
	return BuildingRequest.from_dict({
		"schema": "brickwild.request", "schema_version": 1, "kind": "house",
		"style": "witch_hut", "purpose": "none", "seed": str(seed_value),
		"width": width, "length": length, "height": height, "storeys": 1,
		"material": "timber", "enclosure": "none", "water": "none",
		"orientation": 0.0, "period": 1200,
	})


func _check_request(request: BuildingRequest, label: String) -> void:
	if not request._decode_errors.is_empty():
		failures.append("%s request decode failed: %s" % [label, str(request._decode_errors)])
		return
	var built: GeneratedBuilding = BrickWild.generate(request)
	if not built.is_ok() or built.plan == null:
		failures.append("%s public generation failed: %s" % [label, str(built.errors)])
		return
	var plan: HousePlan = built.plan
	var room := -1
	var room_ids := plan.rooms_of(&"workshop")
	if not room_ids.is_empty():
		room = room_ids[0]
	else:
		for candidate in plan.rooms_of(&"kitchen"):
			if plan.rooms[candidate].get("domestic_functions", []).has(&"witchwork"):
				room = candidate
				break
	if room < 0:
		failures.append("%s has no generated Witchwork room or shared-service function" % label)
		return
	var books: Array[Dictionary] = []
	for index in plan.furniture_of(room):
		var item: Dictionary = plan.furniture[index]
		if String(item.get("activity_group", "")) == "witchwork" \
				and String(item.get("cat", "")) == "books":
			books.append(item)
	if books.size() != 1:
		failures.append("%s required Witchwork book count is %d, expected exactly 1" % [label, books.size()])
		return
	var book: Dictionary = books[0]
	if String(book.get("key", "")) != "Book_Stack_1":
		failures.append("%s Witchwork book is not the compact Book_Stack_1 stack" % label)
		return
	var host_index := int(book.get("host", -1))
	if host_index < 0 or host_index >= plan.furniture.size():
		failures.append("%s Witchwork book has no measured support host" % label)
		return
	var host: Dictionary = plan.furniture[host_index]
	if String(host.get("cat", "")) != "workbench" \
			or String(host.get("activity_group", "")) != "witchwork" \
			or bool(host.get("mounted", false)):
		failures.append("%s required book is not hosted by the Witchwork workbench" % label)
		return
	var support: Rect2 = host.get("rect", Rect2())
	var book_rect: Rect2 = book.get("rect", Rect2())
	if not support.grow(-0.05).encloses(book_rect):
		failures.append("%s book footprint leaves the measured workbench top" % label)
	var host_key := String(host["key"])
	var host_scale := PropCatalog.placement_height_scale(host)
	var expected_top := PropCatalog.house_origin(host).y \
		+ PropCatalog.floor_offset(host_key) * host_scale \
		+ PropCatalog.surface_height(host_key) * host_scale
	var book_key := String(book["key"])
	var book_bottom := PropCatalog.house_origin(book).y \
		+ PropCatalog.floor_offset(book_key) * PropCatalog.placement_height_scale(book)
	if absf(book_bottom - expected_top) > 0.005:
		failures.append("%s book bottom does not meet the measured workbench top" % label)


func _check_fully_obstructed_support_negative() -> void:
	var plan := HousePlan.new()
	plan.rooms.append({"kind": &"workshop", "rect": Rect2(Vector2(-2.0, -2.0), Vector2(4.0, 4.0)), "storey": 0})
	var support_size := PropCatalog.footprint_rotated("Workbench", 0.0)
	var support_rect := Rect2(-support_size * 0.5, support_size)
	plan.furniture.append({"key": "Workbench", "room": 0, "storey": 0,
		"pos": Vector3.ZERO, "yaw": 0.0, "rect": support_rect, "zone": Rect2(),
		"host": -1, "cat": "workbench", "activity_group": "witchwork", "mounted": false, "scale": 1.0})
	var book_key := "Book_Stack_1"
	var book_size := PropCatalog.footprint_rotated(book_key, 0.0)
	var surface_top := PropCatalog.surface_height("Workbench")
	for ix in range(ceili(support_size.x / book_size.x)):
		for iz in range(ceili(support_size.y / book_size.y)):
			var rect := Rect2(support_rect.position + Vector2(ix * book_size.x, iz * book_size.y), book_size)
			if not support_rect.encloses(rect):
				continue
			var centre := rect.get_center()
			plan.furniture.append({"key": book_key, "room": 0, "storey": 0,
				"pos": Vector3(centre.x, surface_top, centre.y), "yaw": 0.0,
				"rect": rect, "zone": Rect2(), "host": 0, "cat": "books",
				"mounted": false, "scale": 1.0})
	var before := plan.furniture.size()
	HouseFurnishPlacement._place_witchwork_book_on_support(plan, 0,
		PropCatalog.of_category("books"), book_key, "workbench")
	if plan.furniture.size() != before:
		failures.append("fully occupied measured workbench accepted an overlapping or floor book")
	for index in range(1, plan.furniture.size()):
		if int(plan.furniture[index].get("host", -1)) != 0:
			failures.append("negative obstruction fixture contains a book that fell onto the floor")
