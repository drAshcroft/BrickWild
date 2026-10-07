extends SceneTree
## Bounded generated ordinary-house coverage for LIVE-GROUPS.
## Run: godot --headless --path . --script res://tests/house_activity_coverage_test.gd

const STYLES: Array[StringName] = [&"cottage", &"farmhouse", &"townhouse", &"longhall", &"witch_hut"]
const SCALES: Array[Dictionary] = [
	{"name": "small", "width": 7.0, "length": 9.0, "height": 2.6},
	{"name": "default", "width": 9.0, "length": 12.0, "height": 2.6},
	{"name": "ample", "width": 17.0, "length": 18.0, "height": 2.8},
]
const SEEDS: Array[int] = [1, 8102, 21325]

var failures: Array[String] = []
var case_summaries: Array[Dictionary] = []

func _init() -> void:
	var case_index := 0
	for scale_index in range(SCALES.size()):
		for style_index in range(STYLES.size()):
			# Every style receives all three sizes. Each style's three-size run
			# covers all three fixed seeds; each size is likewise balanced.
			var seed_index: int = (style_index + scale_index) % SEEDS.size()
			var row: Dictionary = SCALES[scale_index].duplicate(true)
			row["style"] = STYLES[style_index]
			row["seed"] = SEEDS[seed_index]
			row["case_id"] = "%s_%s_%d" % [STYLES[style_index], row["name"], row["seed"]]
			_run_case(row, case_index == 0 or case_index == 14)
			case_index += 1
	for summary in case_summaries:
		print(JSON.stringify(summary))
	for failure in failures:
		push_error(failure)
	print("generated activity coverage: %d cases, %d deterministic repeats, %d failures" % [
		case_summaries.size(), 2, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _spec(row: Dictionary) -> HouseSpec:
	var spec := HouseSpec.new()
	spec.style = row["style"]
	spec.trade = &"none"
	spec.width = float(row["width"])
	spec.length = float(row["length"])
	spec.height = float(row["height"])
	spec.storeys = 1
	return spec


func _run_case(row: Dictionary, repeat: bool) -> void:
	var who: String = String(row["case_id"])
	var plan: HousePlan = HouseGenerator.generate(_spec(row), int(row["seed"]), true)
	var nav: Dictionary = HouseNavCheck.new().check(plan)
	var missing: Array[String] = _missing_required_groups(plan)
	var compromised := _compromised_groups(plan)
	var layout_status: String = String(plan.domestic_layout.get("status", "not_reported"))
	var summary := {
		"case": who, "style": String(row["style"]), "scale": String(row["name"]),
		"seed": int(row["seed"]), "layout_status": layout_status,
		"nav_ok": bool(nav.get("ok", false)), "nav_failures": nav.get("failures", []),
		"missing_mandatory": missing, "compromised_groups": compromised,
		"rooms": plan.room_count(), "furniture": plan.furniture.size(), "deterministic_repeat": repeat,
		"deterministic_repeat_scope": "layout/openings/activity groups/furniture/rugs/hearth/compromises",
	}
	case_summaries.append(summary)
	if not bool(nav.get("ok", false)):
		failures.append("%s navigation: %s" % [who, str(nav.get("failures", []))])
	for item in missing:
		failures.append("%s mandatory group: %s" % [who, item])
	for group in compromised:
		failures.append("%s explicit compromise: %s" % [who, group])
	if repeat:
		var signature: String = _snapshot(plan)
		var repeated: HousePlan = HouseGenerator.generate(_spec(row), int(row["seed"]), true)
		if signature != _snapshot(repeated):
			failures.append("%s did not reproduce the same plan and furniture" % who)


func _missing_required_groups(plan: HousePlan) -> Array[String]:
	var missing: Array[String] = []
	if not HouseFurnishingRecipes.is_ordinary_house(plan):
		return ["fixture was not an ordinary no-trade HouseSpec"]
	for room in range(plan.room_count()):
		var recipe: Array = HouseFurnishingRecipes.recipe_for_room(plan, room,
			not HouseFurnisher._dining_table_lost(plan, room))
		if plan.kind_of(room) == &"hall" and not HouseFurnisher._anybody_sleeps(plan):
			recipe = recipe.duplicate(true)
			recipe.append_array([
				{"cat": "bed", "n": [1, 1], "opt": 1.0, "group": "sleep"},
				{"cat": "chest", "n": [1, 1], "opt": 1.0, "group": "sleep"},
				{"cat": "chest", "n": [1, 1], "opt": 1.0, "group": "sleep"},
				{"cat": "sconce", "n": [1, 1], "opt": 1.0, "group": "sleep"},
			])
		var ample: Dictionary = HouseFurnishingRecipes.AMPLE.get(plan.kind_of(room), {})
		if not ample.is_empty() and HouseGeometry.room_area(plan, room) >= float(ample["area"]):
			recipe.append_array(HouseFurnishingRecipes.ample_steps_for_room(plan, room))
		var required: Dictionary = {}
		for step_variant in recipe:
			var step: Dictionary = step_variant
			var group_name: String = String(step.get("group", ""))
			if group_name.is_empty() or float(step.get("opt", 0.0)) < 1.0:
				continue
			if not required.has(group_name):
				required[group_name] = {}
			var counts: Dictionary = required[group_name]
			var category: String = String(step.get("cat", ""))
			counts[category] = int(counts.get(category, 0)) + int(step.get("min_n", step.get("n", [1, 1])[0]))
		for group_variant in required:
			var required_group: String = String(group_variant)
			var categories: Dictionary = required[group_variant]
			for category_variant in categories:
				var required_category: String = String(category_variant)
				var actual := 0
				for piece in plan.furniture:
					if int(piece.get("room", -1)) == room \
							and String(piece.get("activity_group", "")) == required_group \
							and String(piece.get("cat", "")) == required_category:
						actual += 1
				if actual < int(categories[category_variant]):
					missing.append("room=%d %s/%s %d<%d" % [room, required_group, required_category,
						actual, int(categories[category_variant])])
			if plan.was_dropped(room, "activity:%s" % required_group):
				missing.append("room=%d %s recorded dropped" % [room, required_group])
		for piece in plan.furniture:
			if int(piece.get("room", -1)) != room:
				continue
			var piece_group: String = String(piece.get("activity_group", ""))
			var piece_category: String = String(piece.get("cat", ""))
			var minimum: float = 0.70 if piece_group == "eating" and piece_category == "table" else 0.0
			if piece_group == "cooking" and piece_category == "workbench":
				minimum = 0.75
			if minimum > 0.0 and PropCatalog.placement_height(piece) < minimum:
				missing.append("room=%d %s/%s surface too low" % [room, piece_group, piece_category])
		if "eating" in required and room == HouseFurnishingRecipes.dining_room_of(plan):
			var seats := 0
			for piece in plan.furniture:
				if int(piece.get("room", -1)) == room \
						and String(piece.get("activity_group", "")) == "eating" \
						and String(piece.get("cat", "")) == "seat":
					seats += 1
			var household_capacity: int = HouseFurnisher._household_seat_capacity(plan)
			if seats < household_capacity:
				missing.append("room=%d eating/seat_capacity %d<%d" % [room, seats, household_capacity])
	return missing


func _compromised_groups(plan: HousePlan) -> Array[String]:
	var out: Array[String] = []
	for room in range(plan.room_count()):
		for name in plan.compromises.get(room, []):
			var value: String = String(name)
			if value.begins_with("activity:") and not out.has("room=%d %s" % [room, value]):
				out.append("room=%d %s" % [room, value])
	out.sort()
	return out


func _snapshot(plan: HousePlan) -> String:
	# This is an explicit value signature, not var_to_str(plan): objects print
	# instance IDs and do not form a cross-generation deterministic check.
	var rows := PackedStringArray()
	rows.append("S|%s|%d|%.3f|%.3f|%.3f|%d|%d" % [String(plan.spec.style), plan.spec.seed,
		plan.spec.width, plan.spec.length, plan.spec.height, plan.spec.storeys, plan.spec.room_count])
	for room in range(plan.room_count()):
		var room_row: Dictionary = plan.rooms[room]
		rows.append("R|%d|%s|%d|%s|%s|%s" % [room, String(room_row.get("kind", "")),
			plan.storey_of_room(room), str(Rect2(room_row.get("rect", Rect2()))),
			String(room_row.get("domestic_role", "")),
			str(room_row.get("domestic_functions", []))])
		rows.append("A|%s" % str(room_row.get("activity_regions", {})))
	for door in plan.doors:
		rows.append("D|%s|%s|%s|%s|%s|%s|%s" % [str(door.get("a", -1)), str(door.get("b", -1)),
			str(door.get("pos", Vector2.ZERO)), str(door.get("normal", Vector2.ZERO)),
			str(door.get("width", 0.0)), str(door.get("exterior", false)),
			str(door.get("storey", 0))])
	for window in plan.windows:
		rows.append("W|%s|%s|%s|%s|%s" % [str(window.get("room", -1)),
			str(window.get("pos", Vector2.ZERO)), str(window.get("normal", Vector2.ZERO)),
			str(window.get("width", 0.0)), str(window.get("storey", 0))])
	for piece in plan.furniture:
		rows.append("F|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
			str(piece.get("room", -1)), str(piece.get("storey", 0)),
			String(piece.get("cat", "")), String(piece.get("key", "")),
			String(piece.get("activity_group", "")),
			String(piece.get("activity_host_cat", "")),
			String(piece.get("activity_host_anchor", "")),
			str(Rect2(piece.get("rect", Rect2()))),
			str(Rect2(piece.get("zone", Rect2()))), str(piece.get("pos", Vector3.ZERO)),
			str(piece.get("yaw", 0.0)), str(piece.get("scale", 1.0)),
			str(piece.get("must", false)), str(piece.get("host", -1))])
		rows.append("Y|%s" % str(PropCatalog.placement_height_scale(piece)))
		rows.append("REL|%s" % String(piece.get("activity_relation", "")))
	for rug in plan.rugs:
		rows.append("G|%s|%s|%s" % [str(rug.get("room", -1)),
			String(rug.get("id", "")), str(Rect2(rug.get("rect", Rect2())))])
	var hearth_keys: Array[String] = []
	for key in plan.hearth:
		hearth_keys.append(String(key))
	hearth_keys.sort()
	for key in hearth_keys:
		rows.append("H|%s|%s" % [key, str(plan.hearth[key])])
	var compromise_rooms: Array = plan.compromises.keys()
	compromise_rooms.sort()
	for room_key in compromise_rooms:
		var compromise_rows: Array[String] = []
		for compromise in plan.compromises[room_key]:
			compromise_rows.append(String(compromise))
		compromise_rows.sort()
		rows.append("C|%s|%s" % [str(room_key), ",".join(compromise_rows)])
	var layout_keys: Array[String] = []
	for key in plan.domestic_layout:
		layout_keys.append(String(key))
	layout_keys.sort()
	for key in layout_keys:
		rows.append("L|%s|%s" % [key, str(plan.domestic_layout[key])])
	return "\n".join(rows)
