extends SceneTree
## HS-RICH: the three rich-house traits, measured from the plan and the
## component_log (HouseTraitMeasure) on the style's three frozen requests
## (tests/fixtures/family_style_requests.json, house/rich/*), each with a
## negative control that removes the trait and must be noticed.
##   (1) the front door opens into a hall that holds the main stair
##   (2) a separate parlour (a seating group) and dining room (a table, >= 4 chairs)
##   (3) every cornice and string-course component lies within 0.15 m of a
##       floor line or the eave
##   godot --headless --path . --script res://tests/house_rich_traits_test.gd

const FIXTURE := "res://tests/fixtures/family_style_requests.json"
const TRIM_TOLERANCE := 0.15
var failures: Array[String] = []
var checks := 0


func _init() -> void:
	var cases := _cases()
	_expect(cases.size() == 3, "fixture holds 3 house/rich requests, found %d" % cases.size())
	for c in cases:
		_check_case(c)
	_check_tableware()
	for f in failures:
		printerr("FAIL " + f)
	print("HS-RICH: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _cases() -> Array:
	var out: Array = []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for c in parsed["cases"]:
		if str(c["id"]).begins_with("house/rich/"):
			out.append(c)
	return out


func _spec_of(req: Dictionary) -> HouseSpec:
	return HouseTraitMeasure.make_spec(StringName(req["style"]), float(req["width"]),
		float(req["length"]), float(req["height"]), int(req["storeys"]))


func _measure(req: Dictionary, tweak := Callable()) -> Dictionary:
	return HouseTraitMeasure.measure(_spec_of(req), int(req["seed"]), tweak, true)


func _check_case(c: Dictionary) -> void:
	var req: Dictionary = c["request"]
	var id := str(c["id"])
	var m := _measure(req)
	# (1) the door opens into a hall that holds the stair
	_expect(m["storeys"] >= 2, "%s is a multistorey house (got %d)" % [id, m["storeys"]])
	_expect(m["door_room_kind"] == &"hall", "%s front door opens into a hall (got %s)" % [id, m["door_room_kind"]])
	_expect(m["hall_holds_stair"], "%s the hall holds the main stair" % id)
	# (2) parlour and dining room of their own
	_expect(m["parlour_rooms"] >= 1 and m["dining_rooms"] >= 1 and m["rooms_distinct"],
		"%s hall, parlour and dining room are three rooms (parlours %d, dining %d)" % [id, m["parlour_rooms"], m["dining_rooms"]])
	_expect(m["parlour_settles"] >= 1 and m["parlour_chairs"] >= 2, "%s the parlour has a seating group, a settle and 2 chairs (got %d, %d)" % [id, m["parlour_settles"], m["parlour_chairs"]])
	_expect(m["dining_tables"] >= 1, "%s the dining room has a table (got %d)" % [id, m["dining_tables"]])
	_expect(m["dining_chairs"] >= 4, "%s the dining room has at least 4 chairs (Chair keys, got %d; stools %d)" % [id, m["dining_chairs"], m["dining_stools"]])
	_expect(not m["dining_table_elsewhere"], "%s no second dining table in the hall or parlour" % id)
	# (3) ornament on the floor lines
	_expect(m["trim_count"] > 0, "%s emits cornice and string-course parts (got %d)" % [id, m["trim_count"]])
	_expect(m["trim_worst"] <= TRIM_TOLERANCE, "%s every trim part within %.2f m of a floor line or the eave (worst %.3f)" % [id, TRIM_TOLERANCE, m["trim_worst"]])
	_expect(absf(m["cornice_top_gap"]) <= TRIM_TOLERANCE, "%s the crown stands at the eave (gap %.3f)" % [id, m["cornice_top_gap"]])

	# Negative controls: each removal must be seen by the same measure.
	var no_stair := func(plan: HousePlan) -> void:
		plan.stairs.clear()
	_expect(not _measure(req, no_stair)["hall_holds_stair"], "%s control: removing the stair is noticed" % id)
	var stair_elsewhere := func(plan: HousePlan) -> void:
		for s in plan.stairs:
			s["a"] = -1
	_expect(not _measure(req, stair_elsewhere)["hall_holds_stair"], "%s control: a stair that does not start in the hall is noticed" % id)
	var door_to_parlour := func(plan: HousePlan) -> void:
		for i in plan.rooms.size():
			if plan.kind_of(i) == &"hall" and plan.storey_of_room(i) == 0:
				plan.rooms[i]["kind"] = &"store"
	_expect(_measure(req, door_to_parlour)["door_room_kind"] != &"hall", "%s control: a door into a non-hall is noticed" % id)
	var one_room := func(plan: HousePlan) -> void:
		for i in plan.rooms.size():
			if plan.kind_of(i) == &"dining_room":
				plan.rooms[i]["kind"] = &"parlour"
	var mo := _measure(req, one_room)
	_expect(mo["dining_rooms"] == 0 and not mo["rooms_distinct"], "%s control: no dining room of its own is noticed" % id)
	var no_sofa := func(plan: HousePlan) -> void:
		var keep: Array[Dictionary] = []
		for f in plan.furniture:
			var in_parlour: bool = plan.kind_of(int(f["room"])) == &"parlour"
			if not (in_parlour and str(f.get("cat", "")) in ["seat", "bench"]):
				keep.append(f)
		plan.furniture = keep
	var mn := _measure(req, no_sofa)
	_expect(mn["parlour_settles"] < 1 and mn["parlour_chairs"] < 2, "%s control: a parlour without seating is noticed" % id)
	var stools := func(plan: HousePlan) -> void:
		for f in plan.furniture:
			if plan.kind_of(int(f["room"])) == &"dining_room" and str(f.get("key", "")) == "Chair_1":
				f["key"] = "Stool"
	_expect(_measure(req, stools)["dining_chairs"] < 4, "%s control: stools in place of chairs are noticed" % id)
	var no_chairs_in_group := func(plan: HousePlan) -> void:
		for f in plan.furniture:
			if plan.kind_of(int(f["room"])) == &"parlour" and str(f.get("key", "")) == "Chair_1":
				f["key"] = "Stool"
	_expect(_measure(req, no_chairs_in_group)["parlour_chairs"] < 2, "%s control: a parlour of settle and stools is noticed" % id)
	var two_chairs := func(plan: HousePlan) -> void:
		var keep: Array[Dictionary] = []
		var seen := 0
		for f in plan.furniture:
			if plan.kind_of(int(f["room"])) == &"dining_room" and str(f.get("cat", "")) == "seat":
				seen += 1
				if seen > 2:
					continue
			keep.append(f)
		plan.furniture = keep
	_expect(_measure(req, two_chairs)["dining_chairs"] < 4, "%s control: a table with two chairs is noticed" % id)
	var no_table := func(plan: HousePlan) -> void:
		var keep: Array[Dictionary] = []
		for f in plan.furniture:
			if not (plan.kind_of(int(f["room"])) == &"dining_room" and str(f.get("cat", "")) == "table"):
				keep.append(f)
		plan.furniture = keep
	_expect(_measure(req, no_table)["dining_tables"] == 0, "%s control: a dining room without a table is noticed" % id)
	# The ornament control moves every trim part half a metre up the wall.
	var moved: Array = []
	for row in m["component_log"]:
		var r: Dictionary = row.duplicate()
		var role := str(r.get("role", ""))
		if role.begins_with("cornice") or role == "string_course":
			var xf: Transform3D = r["xf"]
			xf.origin.y -= 0.6
			r["xf"] = xf
		moved.append(r)
	var shifted := HouseTraitMeasure.trim_off_level(moved, float(m["storey_height"]), int(m["storeys"]))
	_expect(shifted["worst"] > TRIM_TOLERANCE, "%s control: trim hung mid-wall is noticed (worst %.3f)" % [id, shifted["worst"]])
	var bare: Array = []
	for row in m["component_log"]:
		if not (str(row.get("role", "")).begins_with("cornice") or str(row.get("role", "")) == "string_course"):
			bare.append(row)
	_expect(HouseTraitMeasure.trim_off_level(bare, float(m["storey_height"]), int(m["storeys"]))["count"] == 0,
		"%s control: a house with no trim is noticed" % id)


func _expect(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures.append(msg)


## HS-RICH-RESIDUE: what the dining recipe sets ON a table must be table-sized.
## The 0.54 m stock pot (Pot_1_Lid) was filed as tableware and sat on every
## dining table. Control: the same measure sees the stock pot as too big.
const TABLEWARE_MAX := 0.40


func _check_tableware() -> void:
	var big: Array = []
	for key in PropCatalog.of_category("tableware"):
		var fp := PropCatalog.footprint(key)
		if maxf(fp.x, fp.y) > TABLEWARE_MAX:
			big.append(key)
	_expect(big.is_empty(), "tableware is table-sized (over %.2f m: %s)" % [TABLEWARE_MAX, str(big)])
	var pot := PropCatalog.footprint("Pot_1_Lid")
	_expect(maxf(pot.x, pot.y) > TABLEWARE_MAX, "control: the stock pot measures over %.2f m" % TABLEWARE_MAX)
