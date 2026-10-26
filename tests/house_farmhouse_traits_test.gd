extends SceneTree
## HS-FARMHOUSE: the three farmhouse traits, measured from the plan, mass_log and
## component_log (HouseTraitMeasure), on the style's three frozen requests
## (tests/fixtures/family_style_requests.json, house/farmhouse/*), each with a
## negative control that removes the trait and must be noticed.
##   godot --headless --path . --script res://tests/house_farmhouse_traits_test.gd

const FIXTURE := "res://tests/fixtures/family_style_requests.json"
var failures: Array[String] = []
var checks := 0


func _init() -> void:
	var cases := _cases()
	_expect(cases.size() == 3, "fixture holds 3 house/farmhouse requests, found %d" % cases.size())
	for c in cases:
		_check_case(c)
	for f in failures:
		printerr("FAIL " + f)
	print("HS-FARMHOUSE: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _cases() -> Array:
	var out: Array = []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for c in parsed["cases"]:
		if str(c["id"]).begins_with("house/farmhouse/"):
			out.append(c)
	return out


func _spec_of(req: Dictionary) -> HouseSpec:
	return HouseTraitMeasure.make_spec(StringName(req["style"]), float(req["width"]),
		float(req["length"]), float(req["height"]), int(req["storeys"]))


func _check_case(c: Dictionary) -> void:
	var req: Dictionary = c["request"]
	var seed_value := int(req["seed"])
	var id := str(c["id"])
	var m := HouseTraitMeasure.measure(_spec_of(req), seed_value)
	# (1) kitchen or store door onto a side or rear facade
	_expect(m["back_door_room"] in ["kitchen", "store"], "%s has a kitchen/store exterior door (got '%s')" % [id, m["back_door_room"]])
	_expect(m["back_door_off_front"], "%s yard door is not on the front facade" % id)
	# (2) an attached outbuilding under its own, lower roof
	_expect(m["byre_attached"], "%s byre stands against the shell" % id)
	_expect(m["byre_roof_count"] == 1, "%s byre has one roof of its own (got %d)" % [id, m["byre_roof_count"]])
	_expect(m["byre_lower_than_eave"], "%s byre roof top %.2f is below the eave %.2f" % [id, m["byre_roof_top"], m["eave_top"]])
	# (3) at least three kinds of working props
	_expect((m["yard_kinds"] as Array).size() >= 3, "%s yard carries >= 3 kinds, got %s" % [id, str(m["yard_kinds"])])

	# Negative controls: each removal must be seen by the same measure.
	var no_back := func(plan: HousePlan) -> void:
		var keep: Array[Dictionary] = []
		for d in plan.doors:
			if not d["exterior"] or d.get("front", false):
				keep.append(d)
		plan.doors = keep
	var mb := HouseTraitMeasure.measure(_spec_of(req), seed_value, no_back)
	_expect(mb["back_door_room"] == "", "%s control: removing the back door is noticed" % id)
	var front_only := func(plan: HousePlan) -> void:
		for d in plan.doors:
			if d["exterior"] and not d.get("front", false):
				d["normal"] = plan.doors[plan.entrance()]["normal"]
	var mf := HouseTraitMeasure.measure(_spec_of(req), seed_value, front_only)
	_expect(not mf["back_door_off_front"], "%s control: a yard door on the front wall is noticed" % id)
	var no_byre := func(plan: HousePlan) -> void:
		var keep: Array[Dictionary] = []
		for pc in plan.yard_pieces:
			if str(pc["kind"]) != "byre":
				keep.append(pc)
		plan.yard_pieces = keep
	var mo := HouseTraitMeasure.measure(_spec_of(req), seed_value, no_byre)
	_expect(mo["byre_roof_count"] == 0 and not mo["byre_attached"], "%s control: removing the byre is noticed" % id)
	var bare := func(plan: HousePlan) -> void:
		plan.yard.clear()
		plan.exterior.clear()
		var keep: Array[Dictionary] = []
		for pc in plan.yard_pieces:
			if str(pc["kind"]) == "byre":
				keep.append(pc)
		plan.yard_pieces = keep
	var my := HouseTraitMeasure.measure(_spec_of(req), seed_value, bare)
	_expect((my["yard_kinds"] as Array).size() < 3, "%s control: a bare yard (byre only) fails the 3-kind rule: %s" % [id, str(my["yard_kinds"])])


func _expect(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures.append(msg)
