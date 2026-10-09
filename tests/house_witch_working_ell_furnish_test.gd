extends SceneTree
## Furnished diagnostic for the frozen nine-Witch / three-Cottage request set.
## Run after applying the staged source proposal; no requests are regenerated.

const REQUESTS := "res://tests/fixtures/witch_family_requests.json"

var failures: Array[String] = []
var summaries: Array[Dictionary] = []

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REQUESTS))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("frozen Witch request fixture could not be read")
		quit(2)
		return
	var cases_variant: Variant = (parsed as Dictionary).get("cases", [])
	if typeof(cases_variant) != TYPE_ARRAY:
		push_error("frozen Witch request fixture has no cases array")
		quit(2)
		return
	var cases: Array = cases_variant
	if cases.size() != 12:
		failures.append("frozen request fixture contains %d cases, expected 12" % cases.size())
	for row_variant in cases:
		_check_case(row_variant)
	for summary in summaries:
		print(JSON.stringify(summary))
	for failure in failures:
		push_error(failure)
	print("Witch/Cottage furnished diagnostic: %d cases, %d failures" % [summaries.size(), failures.size()])	
	quit(1 if not failures.is_empty() else 0)


func _check_case(row_variant: Variant) -> void:
	var row: Dictionary = row_variant
	var request: Dictionary = row.get("request", {})
	var spec := HouseSpec.new(int(String(request.get("seed", "0"))))
	spec.style = StringName(request.get("style", "cottage"))
	spec.trade = &"none"
	spec.width = float(request.get("width", 8.0))
	spec.length = float(request.get("length", 10.0))
	spec.height = float(request.get("height", 2.6))
	spec.storeys = int(request.get("storeys", 1))
	spec.material = StringName(request.get("material", "timber"))
	spec.orientation = float(request.get("orientation", 0.0))
	spec.period = int(request.get("period", 1200))
	var plan := HouseGenerator.generate(spec, spec.seed, true)
	if plan == null:
		failures.append("%s: generator returned no furnished plan" % row.get("id", "unknown"))
		return
	var builder := HouseBuilder.new()
	var mesh := builder.build(plan, true)
	var roof_layout := HouseGeometry.roof_layout(plan)
	var service_bay: Dictionary = roof_layout.get("witch_bay", {})
	var qa := HouseQA.new().check(plan, builder)
	var nav := HouseNavCheck.new().check(plan)
	var qa_failures: Array = qa.get("failures", [])
	if not bool(qa.get("ok", false)):
		for failure in qa_failures:
			failures.append("%s HouseQA: %s" % [row.get("id", "unknown"), str(failure)])
	if not bool(nav.get("ok", false)):
		for failure in nav.get("failures", []):
			failures.append("%s navigation: %s" % [row.get("id", "unknown"), str(failure)])
	var cooking_rooms := _cooking_rooms(plan)
	var cooking_windows := 0
	for window in plan.windows:
		if cooking_rooms.has(int(window.get("room", -1))):
			cooking_windows += 1
	if cooking_rooms.is_empty():
		failures.append("%s: no room owns the cooking activity" % row.get("id", "unknown"))
	elif cooking_windows == 0:
		failures.append("%s: cooking room has no planned daylight opening" % row.get("id", "unknown"))
	var hearth_room := plan.hearth_room()
	var hearth_wall := plan.hearth_wall()
	var breast := HouseGeometry.hearth_breast(plan)
	var hearths := _pieces(plan, hearth_room, "hearth")
	var has_breast_mass := _has_mass(builder, "chimney_breast")
	var has_flue_mass := _has_mass(builder, "chimney")
	if spec.chimney and (hearth_room < 0 or hearth_wall < 0 or breast.is_empty() \
			or int(breast.get("room", -1)) != hearth_room or hearths.is_empty() \
			or not has_breast_mass or not has_flue_mass):
		failures.append("%s: furnished hearth, host wall, masonry breast, or chimney flue is missing/mismatched" % row.get("id", "unknown"))
	if not spec.chimney and (has_breast_mass or has_flue_mass):
		failures.append("%s: chimney-off control emitted a hearth breast or flue" % row.get("id", "unknown"))
	var group_issues := _missing_required_groups(plan)
	for issue in group_issues:
		failures.append("%s required activity: %s" % [row.get("id", "unknown"), issue])
	var light_counts: Array[int] = []
	for room_index in range(plan.room_count()):
		var actual := HouseFurnisher._room_light_count(plan, room_index)
		var required := HouseFurnisher._required_light_count(plan, room_index)
		light_counts.append(actual)
		if actual < required:
			failures.append("%s room %d has %d/%d required usable lights" % [row.get("id", "unknown"), room_index, actual, required])
	var hall_rect := Rect2()
	if not plan.rooms_of(&"hall").is_empty():
		hall_rect = plan.rooms[plan.rooms_of(&"hall")[0]]["rect"]
	var main_roof_xf: Transform3D = roof_layout.get("transform", Transform3D.IDENTITY)
	var ridge_world := main_roof_xf * Vector3(float(roof_layout.get("ridge_x", 0.0)),
		float(roof_layout.get("rise", 0.0)), 0.0)
	var service_join_world: Variant = null
	var service_eave_world: Variant = null
	if not service_bay.is_empty():
		service_join_world = main_roof_xf.origin.y + float(service_bay.get("join_y", 0.0))
		service_eave_world = main_roof_xf.origin.y + float(service_bay.get("eave_y", 0.0))
	summaries.append({
		"id": row.get("id", "unknown"), "style": String(spec.style),
		"size": Vector2(spec.width, spec.length), "seed": spec.seed,
		"rooms": plan.room_count(), "cooking_rooms": cooking_rooms,
		"cooking_windows": cooking_windows, "hearth_room": hearth_room,
		"hearth_wall": hearth_wall, "hearth_prop_count": hearths.size(), "chimney_enabled": spec.chimney,
		"hearth_breast_mass": has_breast_mass, "chimney_mass": has_flue_mass,
		"high_core_width": hall_rect.size.x, "main_roof_span": roof_layout.get("span", 0.0),
		"main_ridge_station_local": roof_layout.get("ridge_x", 0.0),
		"main_ridge_station_world": Vector2(ridge_world.x, ridge_world.z),
		"main_gable_rise": roof_layout.get("rise", 0.0),
		"service_join_height_world": service_join_world, "service_eave_height_world": service_eave_world,
		"lights_by_room": light_counts, "navigation_ok": bool(nav.get("ok", false)),
		"navigation_failures": nav.get("failures", []), "house_qa_ok": bool(qa.get("ok", false)),
		"house_qa_failures": qa_failures, "mesh_surfaces": mesh.get_surface_count(),
	})
	mesh.clear_surfaces()


func _cooking_rooms(plan: HousePlan) -> Array[int]:
	var out: Array[int] = []
	for room_index in range(plan.room_count()):
		var functions: Array = plan.rooms[room_index].get("domestic_functions", [])
		if plan.kind_of(room_index) == &"kitchen" \
				or (plan.kind_of(room_index) == &"hall" and functions.has(&"cooking")):
			out.append(room_index)
	return out


func _pieces(plan: HousePlan, room_index: int, category: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if room_index < 0:
		return out
	for piece in plan.furniture:
		if int(piece.get("room", -1)) == room_index and String(piece.get("cat", "")) == category:
			out.append(piece)
	return out


func _has_mass(builder: HouseBuilder, expected: String) -> bool:
	for mass in builder.mass_log:
		if String(mass.get("name", "")) == expected:
			return true
	return false


func _missing_required_groups(plan: HousePlan) -> Array[String]:
	var missing: Array[String] = []
	for room_index in range(plan.room_count()):
		var recipe: Array = HouseFurnishingRecipes.recipe_for_room(plan, room_index,
			not HouseFurnisher._dining_table_lost(plan, room_index))
		var required: Dictionary = {}
		for step_variant in recipe:
			var step: Dictionary = step_variant
			var group := String(step.get("group", ""))
			if group.is_empty() or float(step.get("opt", 0.0)) < 1.0:
				continue
			var category := String(step.get("cat", ""))
			if not required.has(group):
				required[group] = {}
			var counts: Dictionary = required[group]
			counts[category] = int(counts.get(category, 0)) \
				+ int(step.get("min_n", step.get("n", [1, 1])[0]))
		for group_variant in required:
			var group := String(group_variant)
			var categories: Dictionary = required[group]
			for category_variant in categories:
				var category := String(category_variant)
				var actual := 0
				for piece in plan.furniture:
					if int(piece.get("room", -1)) == room_index \
							and String(piece.get("activity_group", "")) == group \
							and String(piece.get("cat", "")) == category:
						actual += 1
				if actual < int(categories[category]):
					missing.append("room=%d %s/%s %d<%d" % [room_index, group, category,
						actual, int(categories[category])])
			if plan.was_dropped(room_index, "activity:%s" % group):
				missing.append("room=%d %s was dropped" % [room_index, group])
	return missing
