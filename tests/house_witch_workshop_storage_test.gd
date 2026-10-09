extends SceneTree
## Artifact proposal fixture: public Witch requests must express fitted storage
## through the actual Workshop role. Compact shared-Hall cooking remains separate.
const REQUESTS := "res://tests/fixtures/personality/witch_requests.json"
var failures: Array[String] = []

func _init() -> void:
	_check_frozen_matrix()
	_check_out_of_scope_recipes()
	for failure in failures:
		printerr("FAIL ", failure)
	print("witch workshop storage-role fixture: ", failures.size(), " failures")
	quit(1 if not failures.is_empty() else 0)

func _check_frozen_matrix() -> void:
	var root: Variant = JSON.parse_string(FileAccess.get_file_as_string(REQUESTS))
	if not root is Dictionary or not root.get("cases", null) is Array:
		failures.append("frozen Witch request matrix unreadable")
		return
	var seen := 0
	for raw in root["cases"]:
		if not raw is Dictionary or String(raw.get("role", "")) != "witch":
			continue
		seen += 1
		var request := BuildingRequest.from_dict(raw.get("request", {}))
		var built: GeneratedBuilding = BrickWild.generate(request)
		var label := String(raw.get("id", "missing_id"))
		if not built.is_ok() or built.plan == null:
			failures.append(label + " public generation failed: " + str(built.errors))
			continue
		var plan: HousePlan = built.plan
		var workshop := -1
		for room in plan.rooms_of(&"workshop"):
			if bool(plan.rooms[room].get("witch_service_wing", false)):
				workshop = room
				break
		if workshop >= 0:
			var cabinet_count := 0
			var rack_count := 0
			var bench_count := 0
			for index in plan.furniture_of(workshop):
				var item: Dictionary = plan.furniture[index]
				if String(item.get("activity_group", "")) != "witchwork":
					continue
				var key := String(item.get("key", ""))
				var category := String(item.get("cat", ""))
				if key == "Cabinet" and category == "storage": cabinet_count += 1
				if key == "Peg_Rack" and category == "rack": rack_count += 1
				if category == "workbench": bench_count += 1
			if cabinet_count != 1:
				failures.append(label + " service Workshop has %d Witchwork ingredient cabinets, expected 1" % cabinet_count)
			if rack_count != 1:
				failures.append(label + " service Workshop has %d Witchwork tool racks, expected 1" % rack_count)
			if bench_count != 1:
				failures.append(label + " service Workshop has %d Witchwork benches, expected 1" % bench_count)
		else:
			# The documented 7x9 compact fallback has no separate workshop.
			# Its shared hall must not acquire the dedicated Workshop cabinet.
			var hall := plan.rooms_of(&"hall")
			var found_wrong_cabinet := false
			if not hall.is_empty():
				for index in plan.furniture_of(hall[0]):
					var item: Dictionary = plan.furniture[index]
					if String(item.get("activity_group", "")) == "witchwork" \
							and String(item.get("key", "")) == "Cabinet":
						found_wrong_cabinet = true
			if found_wrong_cabinet:
				failures.append(label + " compact shared-Hall fallback received the dedicated service cabinet")
	if seen != 9:
		failures.append("frozen Witch matrix yielded %d cases, expected 9" % seen)

func _check_out_of_scope_recipes() -> void:
	for style in [&"cottage", &"witch_hut"]:
		var spec := HouseSpec.new()
		spec.style = style
		spec.trade = &"alchemist" if style == &"witch_hut" else &"none"
		var plan := HousePlan.new()
		plan.spec = spec
		plan.rooms.append({"kind": &"workshop", "rect": Rect2(Vector2(-3.0, -3.0), Vector2(6.0, 6.0)), "storey": 0})
		var recipe := HouseFurnishingRecipes.recipe_for_room(plan, 0)
		for step_variant in recipe:
			var step: Dictionary = step_variant
			if String(step.get("key", "")) in ["Cabinet", "Peg_Rack"] \
					and String(step.get("group", "")) == "witchwork":
				failures.append("%s control recipe received Witchwork role-specific storage" % String(style))
