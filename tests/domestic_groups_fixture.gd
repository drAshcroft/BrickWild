extends SceneTree
## Executable contract fixture for LIVE-GROUPS. Run after copying proposed
## sources into src/house, with the normal Godot project bootstrapped.
## It checks domestic overlays and proves a ShopSpec still reads the untouched
## base recipe. Generated placement/repair behavior lives in the other fixture.

var failures: Array[String] = []

const LEGACY_SITTING_PARLOUR := [
	{"cat": "bench", "rule": &"wall", "n": [1, 1], "opt": 0.9, "settle": true},
	{"cat": "bookcase", "rule": &"wall", "n": [0, 1], "opt": 0.7},
	{"cat": "chest", "rule": &"wall", "n": [0, 1], "opt": 0.6},
	{"cat": "storage", "rule": &"wall", "n": [0, 1], "opt": 0.6},
	{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
	{"cat": "candle", "rule": &"on", "n": [1, 1], "opt": 0.8},
]

func _init() -> void:
	_check_recipe_group(&"kitchen", "cooking", ["hearth", "workbench", "storage", "bucket", "cookware"])
	_check_recipe_group(&"bedroom", "sleep", ["bed", "chest", "sconce"])
	_check_recipe_group(&"hall", "eating", ["table", "seat"])
	_check_recipe_group(&"dining_room", "eating", ["table", "seat"])
	_check_recipe_group(&"parlour", "eating", ["table", "bench", "seat"])
	_check_domestic_overlay_is_scoped()
	_check_legacy_sitting_parlour_is_unchanged()
	_check_ample_kitchen_is_not_meal_capacity()
	for failure in failures:
		push_error(failure)
	print("domestic group fixture: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_recipe_group(room_kind: StringName, group_name: String, required: Array[String]) -> void:
	var plan: HousePlan = _plan_for(room_kind)
	var recipe: Array = HouseFurnishingRecipes.recipe_for_room(plan, 0)
	var found: Dictionary = {}
	for step in recipe:
		if String(step.get("group", "")) == group_name and float(step.get("opt", 0.0)) >= 1.0:
			var category: String = String(step["cat"])
			found[category] = int(found.get(category, 0)) + int(step.get("n", [1, 1])[0])
	for category in required:
		if not found.has(category):
			failures.append("%s/%s lacks mandatory %s" % [room_kind, group_name, category])
	if room_kind == &"bedroom" and int(found.get("chest", 0)) < 2:
		failures.append("bedroom sleep group lacks bedside and clothes chests")
	var found_bedside := false
	for step in recipe:
		if String(step.get("group", "")) == "sleep" and String(step["cat"]) == "chest" \
				and String(step.get("near_anchor", "")) == "head_end" and String(step.get("near_cat", "")) == "bed":
			found_bedside = true
	if room_kind == &"bedroom" and not found_bedside:
		failures.append("bedroom lacks explicit low chest at bed head end")


func _check_domestic_overlay_is_scoped() -> void:
	_assert_no_overlay(ShopSpec.new(), "shop")
	_assert_no_overlay(KeepSpec.new(), "keep")


func _check_legacy_sitting_parlour_is_unchanged() -> void:
	var plan: HousePlan = HousePlan.new()
	plan.spec = KeepSpec.new()
	plan.rooms = [
		{"kind": &"hall", "rect": Rect2(0.0, 0.0, 5.0, 5.0), "storey": 0},
		{"kind": &"parlour", "rect": Rect2(5.0, 0.0, 5.0, 5.0), "storey": 0},
		{"kind": &"bedroom", "rect": Rect2(0.0, 5.0, 5.0, 5.0), "storey": 0},
	]
	var resolved: Array = HouseFurnishingRecipes.recipe_for_room(plan, 1)
	if resolved != LEGACY_SITTING_PARLOUR:
		failures.append("KeepSpec dines-elsewhere parlour no longer resolves to the legacy sitting recipe")
	for step in resolved:
		if step.has("group") or float(step.get("opt", 0.0)) == 1.0:
			failures.append("KeepSpec sitting recipe inherited ordinary-house mandatory activity overlay")
			return


func _check_ample_kitchen_is_not_meal_capacity() -> void:
	var plan: HousePlan = HousePlan.new()
	plan.spec = HouseSpec.new()
	plan.rooms = [{"kind": &"kitchen", "rect": Rect2(0.0, 0.0, 8.0, 8.0), "storey": 0}]
	for step in HouseFurnishingRecipes.ample_steps_for_room(plan, 0):
		if String(step.get("cat", "")) in ["table", "seat", "bench"] \
				and String(step.get("group", "")) == "eating":
			failures.append("ample kitchen prep table/seats incorrectly count as household meal capacity")


func _assert_no_overlay(spec: HouseSpec, label: String) -> void:
	var plan: HousePlan = HousePlan.new()
	plan.spec = spec
	plan.rooms = [{"kind": &"kitchen", "rect": Rect2(0.0, 0.0, 5.0, 5.0), "storey": 0}]
	var resolved: Array = HouseFurnishingRecipes.recipe_for_room(plan, 0)
	var base: Array = HouseFurnishingRecipes.RECIPES[&"kitchen"]
	if resolved != base:
		failures.append("custom %s kitchen recipe changed under domestic overlay" % label)
	for step in resolved:
		if step.has("group"):
			failures.append("custom %s kitchen inherited domestic activity group tags" % label)
			return


func _plan_for(kind: StringName) -> HousePlan:
	var plan: HousePlan = HousePlan.new()
	plan.spec = HouseSpec.new()
	var room: Dictionary = {"kind": kind, "rect": Rect2(0.0, 0.0, 5.0, 5.0), "storey": 0}
	if kind == &"hall":
		room["domestic_functions"] = [&"entry", &"dining", &"cooking"]
	plan.rooms = [room]
	return plan
