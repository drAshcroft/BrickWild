extends SceneTree
## HS-LONGHALL: the four longhall traits, measured from the plan, mass_log and
## component_log (HouseTraitMeasure) on the style's three frozen requests
## (tests/fixtures/family_style_requests.json, house/longhall/*), each with a
## negative control that removes the trait and must be noticed.
##   (1) at least 2.5 x as long as wide, one storey under one main roof
##   (2) an open fire half way along the hall, a smoke hole and louvre over it
##   (3) no ceiling over the hall: trusses, ridge beam and rafters in view
##   (4) benches along both long walls; private rooms only at the two ends
##   godot --headless --path . --script res://tests/house_longhall_traits_test.gd

const FIXTURE := "res://tests/fixtures/family_style_requests.json"
var failures: Array[String] = []
var checks := 0


func _init() -> void:
	var cases := _cases()
	_expect(cases.size() == 3, "fixture holds 3 house/longhall requests, found %d" % cases.size())
	for c in cases:
		_check_case(c)
	for f in failures:
		printerr("FAIL " + f)
	print("HS-LONGHALL: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _cases() -> Array:
	var out: Array = []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for c in parsed["cases"]:
		if str(c["id"]).begins_with("house/longhall/"):
			out.append(c)
	return out


func _spec_of(req: Dictionary, style := "") -> HouseSpec:
	return HouseTraitMeasure.make_spec(StringName(style if style != "" else req["style"]),
		float(req["width"]), float(req["length"]), float(req["height"]), int(req["storeys"]))


func _check_case(c: Dictionary) -> void:
	var req: Dictionary = c["request"]
	var seed_value := int(req["seed"])
	var id := str(c["id"])
	var m := HouseTraitMeasure.measure(_spec_of(req), seed_value, Callable(), true)
	# (1) long, one storey, one roof
	_expect(m["long_ratio"] >= 2.5, "%s is %.2f times as long as wide" % [id, m["long_ratio"]])
	_expect(m["storeys"] == 1 and m["room_storeys"] == 1, "%s is one storey" % id)
	_expect(m["main_roofs"] == 1, "%s has one main roof (got %d)" % [id, m["main_roofs"]])
	# (2) the open fire, the smoke hole, the louvre
	_expect(m["hearth_kerb_count"] == 4, "%s fire has its four-stone kerb" % id)
	_expect(m["hearth_gap"] >= 1.0, "%s fire stands clear of the hall walls (%.2f m)" % [id, m["hearth_gap"]])
	_expect(m["hearth_mid_offset"] <= 0.1, "%s fire is near the middle of the hall (%.3f of its length off)" % [id, m["hearth_mid_offset"]])
	_expect(not m["hearth_wall_fire"] and m["chimney_count"] == 0, "%s has no wall fireplace or chimney" % id)
	_expect(m["smoke_hole"], "%s has a smoke hole cut in the roof" % id)
	_expect(m["smoke_over_hearth"], "%s smoke hole is over the fire" % id)
	_expect(m["louvre_over_ridge"] >= 0.6, "%s louvre stands %.2f m over the ridge" % [id, m["louvre_over_ridge"]])
	# (3) open to the roof
	_expect(not m["ceiling_over_hall"], "%s has no ceiling over the hall" % id)
	_expect(m["ceiling_over_ends"] >= 0.95, "%s end rooms are ceiled (%.2f)" % [id, m["ceiling_over_ends"]])
	_expect(m["truss_count"] >= 2, "%s shows %d trusses over the hall" % [id, m["truss_count"]])
	_expect(m["rafter_count"] >= 8, "%s shows %d common rafters" % [id, m["rafter_count"]])
	_expect(m["has_ridge_beam"], "%s shows a ridge beam" % id)
	# (4) benches on both long walls, private rooms at the ends
	_expect(m["bench_walls"] == 2, "%s has benches on both long walls (%d)" % [id, m["bench_walls"]])
	_expect(m["bench_front_len"] >= 0.3 * m["hall_length"] and m["bench_back_len"] >= 0.3 * m["hall_length"],
		"%s benches run %.1f m and %.1f m of a %.1f m hall" % [id, m["bench_front_len"], m["bench_back_len"], m["hall_length"]])
	_expect(m["rooms_off_ends"] == 0, "%s has no private room beside the hall (%d)" % [id, m["rooms_off_ends"]])
	_expect(m["end_sides"] == 2, "%s has a room at each end (%d)" % [id, m["end_sides"]])
	_expect(m["hall_full_depth"] and m["hall_fraction"] >= 0.45, "%s hall fills the middle (%.2f)" % [id, m["hall_fraction"]])

	# Negative controls: each removal must be seen by the same measure.
	var other := HouseTraitMeasure.measure(_spec_of(req, "farmhouse"), seed_value, Callable(), true)
	_expect(other["long_ratio"] < 2.5 and not other["smoke_hole"] and other["bench_walls"] < 2
			and other["hearth_kerb_count"] == 0, "%s control: a farmhouse of the same size shows none of it" % id)
	var ceil_over := func(plan: HousePlan) -> void:
		plan.longhall["ends"].append(int(plan.longhall["room"]))
	var mc := HouseTraitMeasure.measure(_spec_of(req), seed_value, ceil_over)
	_expect(mc["ceiling_over_hall"], "%s control: a ceiling over the hall is noticed" % id)
	var smoke_off := func(plan: HousePlan) -> void:
		plan.longhall["smoke"] = Vector2(plan.longhall["smoke"]) + Vector2(3.0, 0.0)
	var ms := HouseTraitMeasure.measure(_spec_of(req), seed_value, smoke_off)
	_expect(not ms["smoke_over_hearth"], "%s control: a smoke hole away from the fire is noticed" % id)
	var fire_at_wall := func(plan: HousePlan) -> void:
		var hr: Rect2 = HouseGeometry.room_floor_rect(plan, int(plan.longhall["room"]))
		plan.longhall["hearth"] = Rect2(hr.position + Vector2(0.1, 0.1), Vector2(1.3, 1.3))
	var mf := HouseTraitMeasure.measure(_spec_of(req), seed_value, fire_at_wall)
	_expect(mf["hearth_gap"] < 1.0 and mf["hearth_mid_offset"] > 0.1, "%s control: a fire pushed into a corner is noticed" % id)
	var one_side := func(plan: HousePlan) -> void:
		var hr: Rect2 = HouseGeometry.room_floor_rect(plan, int(plan.longhall["room"]))
		for i in range(plan.furniture.size() - 1, -1, -1):
			if str(plan.furniture[i]["key"]) == "Bench" and absf(Rect2(plan.furniture[i]["rect"]).end.y - hr.end.y) < 0.12:
				plan.furniture.remove_at(i)
	var mb := HouseTraitMeasure.measure(_spec_of(req), seed_value, one_side, true)
	_expect(mb["bench_walls"] == 1, "%s control: a bare back wall is noticed (%d walls)" % [id, mb["bench_walls"]])
	var beside := func(plan: HousePlan) -> void:
		var hr: Rect2 = HouseGeometry.room_floor_rect(plan, int(plan.longhall["room"]))
		for i in range(plan.rooms.size()):
			if plan.kind_of(i) == &"store":
				plan.rooms[i]["rect"] = Rect2(hr.get_center() + Vector2(1.0, 0.0), Vector2(2.0, 2.0))
	var mr := HouseTraitMeasure.measure(_spec_of(req), seed_value, beside)
	_expect(mr["rooms_off_ends"] >= 1, "%s control: a room beside the hall is noticed" % id)
	var no_frame := func(plan: HousePlan) -> void:
		plan.longhall["room"] = int(plan.longhall["ends"][0])
	var mt := HouseTraitMeasure.measure(_spec_of(req), seed_value, no_frame)
	_expect(mt["truss_count"] < 2, "%s control: a hall with no trusses is noticed (%d)" % [id, mt["truss_count"]])


func _expect(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures.append(msg)
