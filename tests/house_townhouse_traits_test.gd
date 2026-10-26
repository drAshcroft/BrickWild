extends SceneTree
## HS-TOWNHOUSE: the three townhouse traits, measured from the plan (HouseTraitMeasure),
## on the style's three frozen requests (tests/fixtures/family_style_requests.json,
## house/townhouse/*), each with a negative control that removes the trait and must be
## noticed. A three-storey request is checked as well, for the stair spine.
##   godot --headless --path . --script res://tests/house_townhouse_traits_test.gd

const FIXTURE := "res://tests/fixtures/family_style_requests.json"
var failures: Array[String] = []
var checks := 0


func _init() -> void:
	var cases := _cases()
	_expect(cases.size() == 3, "fixture holds 3 house/townhouse requests, found %d" % cases.size())
	for c in cases:
		_check_case(c)
	_check_three_storeys()
	for f in failures:
		printerr("FAIL " + f)
	print("HS-TOWNHOUSE: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _cases() -> Array:
	var out: Array = []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for c in parsed["cases"]:
		if str(c["id"]).begins_with("house/townhouse/"):
			out.append(c)
	return out


func _spec_of(req: Dictionary, storeys := -1) -> HouseSpec:
	return HouseTraitMeasure.make_spec(StringName(req["style"]), float(req["width"]),
		float(req["length"]), float(req["height"]), int(req["storeys"]) if storeys < 0 else storeys)


func _spine(m: Dictionary, id: String) -> void:
	var n: int = m["storeys"]
	_expect(m["spine_storeys"] == n, "%s one stair spine reaches all %d storeys (got %d)" % [id, n, m["spine_storeys"]])
	_expect(m["spine_landings"] == n - 1, "%s every flight has a foot and head landing (%d of %d)" % [id, m["spine_landings"], n - 1])
	_expect(m["spine_lit"] == n, "%s the landing room on every storey has a window (%d of %d)" % [id, m["spine_lit"], n])


func _check_case(c: Dictionary) -> void:
	var req: Dictionary = c["request"]
	var seed_value := int(req["seed"])
	var id := str(c["id"])
	var m := HouseTraitMeasure.measure(_spec_of(req), seed_value)
	# (1) two or three storeys, frontage narrower than depth
	_expect(m["storeys"] in [2, 3] and m["room_storeys"] == m["storeys"], "%s is 2-3 storeys (got %d, rooms on %d)" % [id, m["storeys"], m["room_storeys"]])
	_expect(m["frontage_narrower"], "%s frontage %.1f is narrower than depth %.1f" % [id, m["frontage"], m["depth"]])
	# (2) one stair from the entry to every floor, landed and lit
	_spine(m, id)
	# (3) work below, beds above
	_expect(m["ground_work"], "%s ground floor holds a work room" % id)
	_expect(m["ground_bedrooms"] == 0, "%s no bedroom on the ground floor (got %d)" % [id, m["ground_bedrooms"]])
	_expect(m["upper_bedrooms"] >= 1, "%s a bedroom above (got %d)" % [id, m["upper_bedrooms"]])

	# Negative controls: each removal must be seen by the same measure.
	var flat := func(plan: HousePlan) -> void:
		plan.spec.storeys = 1
	var m1 := HouseTraitMeasure.measure(_spec_of(req), seed_value, flat)
	_expect(m1["storeys"] == 1, "%s control: a one-storey house is noticed" % id)
	var turned := func(plan: HousePlan) -> void:
		var w := plan.spec.width
		plan.spec.width = plan.spec.length
		plan.spec.length = w
	var mt := HouseTraitMeasure.measure(_spec_of(req), seed_value, turned)
	_expect(not mt["frontage_narrower"], "%s control: a wide frontage is noticed" % id)
	var no_stair := func(plan: HousePlan) -> void:
		plan.stairs.clear()
	var ms := HouseTraitMeasure.measure(_spec_of(req), seed_value, no_stair)
	_expect(ms["spine_storeys"] < ms["storeys"], "%s control: removing the stair is noticed" % id)
	var no_landing := func(plan: HousePlan) -> void:
		for s in plan.stairs:
			s["head_landing"] = Rect2()
	var ml := HouseTraitMeasure.measure(_spec_of(req), seed_value, no_landing)
	_expect(ml["spine_landings"] < ml["storeys"] - 1, "%s control: removing the landings is noticed" % id)
	var dark := func(plan: HousePlan) -> void:
		var keep: Array[Dictionary] = []
		for w in plan.windows:
			if plan.storey_of_room(int(w["room"])) < 1:
				keep.append(w)
		plan.windows = keep
	var md := HouseTraitMeasure.measure(_spec_of(req), seed_value, dark)
	_expect(md["spine_lit"] < md["storeys"], "%s control: an unlit upper landing is noticed" % id)
	var bed_down := func(plan: HousePlan) -> void:
		for i in plan.rooms_on_storey(0):
			if plan.kind_of(i) == &"office":
				plan.rooms[i]["kind"] = &"bedroom"
	var mb := HouseTraitMeasure.measure(_spec_of(req), seed_value, bed_down)
	_expect(mb["ground_bedrooms"] > 0 and not mb["ground_work"], "%s control: a bedroom in place of the work room is noticed" % id)


func _check_three_storeys() -> void:
	for c in _cases():
		var req: Dictionary = c["request"]
		var id := str(c["id"]) + " at 3 storeys"
		var m := HouseTraitMeasure.measure(_spec_of(req, 3), int(req["seed"]))
		_expect(m["storeys"] == 3, "%s builds 3 storeys" % id)
		_spine(m, id)
		_expect(m["ground_bedrooms"] == 0 and m["ground_work"], "%s work below, no bed below" % id)


func _expect(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures.append(msg)
