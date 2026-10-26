extends SceneTree
## HS-MINKA: the four traits of the `asian` style (the Japanese minka), measured
## from the plan, mass_log and component_log (HouseTraitMeasure) on the style's
## three frozen requests (tests/fixtures/family_style_requests.json,
## house/asian/*, the style's 8 x 10 m default), each with a negative control
## that removes the trait and must be noticed.
##   (1) the floor raised at least 0.4 m on a stone plinth (the stylobate under
##       every wall, stone steps down to the ground at each entry door) and an
##       engawa along a LONG side: a floor-level deck at least 80% of the wall,
##       on posts under the roof's eave
##   (2) an irimoya roof: a hipped skirt under a steeper gable closed by two
##       vertical hafu triangles, the eaves at least 0.9 m deep all round
##   (3) sliding lattice screens in the engawa-side wall: tracks, overlapping
##       panels on two lanes, a lattice of bars, on that wall and no other
##   (4) the main room (parlour, else hall) opens through a wide screen door onto
##       the engawa, and the dry garden lies beyond it, in front of that door
##   godot --headless --path . --script res://tests/house_minka_traits_test.gd

const FIXTURE := "res://tests/fixtures/family_style_requests.json"
const RISE_MIN := 0.4
const EAVE_MIN := 0.9
var failures: Array[String] = []
var checks := 0


func _init() -> void:
	var cases := _cases()
	_expect(cases.size() == 3, "fixture holds 3 house/asian requests, found %d" % cases.size())
	for c in cases:
		_check_case(c)
	for f in failures:
		printerr("FAIL " + f)
	print("HS-MINKA: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _cases() -> Array:
	var out: Array = []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for c in parsed["cases"]:
		if str(c["id"]).begins_with("house/asian/"):
			out.append(c)
	return out


func _spec_of(req: Dictionary) -> HouseSpec:
	return HouseTraitMeasure.make_spec(StringName(req["style"]), float(req["width"]),
		float(req["length"]), float(req["height"]), int(req["storeys"]))


func _check_case(c: Dictionary) -> void:
	var req: Dictionary = c["request"]
	var seed_value := int(req["seed"])
	var id := str(c["id"])
	_expect(StringName(req["style"]) == &"asian", "%s keeps the style key asian" % id)
	_expect(str(HouseSpec.STYLES[&"asian"]["label"]) == "Japanese Minka", "the style's label is Japanese Minka")
	var m := HouseTraitMeasure.measure(_spec_of(req), seed_value)
	# (1) the raised floor on a stone plinth
	_expect(m["plinth_rise"] >= RISE_MIN, "%s floor stands %.2f m above the ground" % [id, m["plinth_rise"]])
	_expect(m["plinth_runs"] == 4 and m["plinth_closed"], "%s stone plinth under all four walls, up to the floor (%d runs)" % [id, m["plinth_runs"]])
	_expect(m["step_flights"] >= 1 and m["steps_reach_ground"], "%s entry door has stone steps down to the ground (%d flights)" % [id, m["step_flights"]])
	_expect(m["step_riser_max"] <= 0.18, "%s steps rise %.3f m at most" % [id, m["step_riser_max"]])
	_expect(m["engawa_present"] and m["engawa_long_side"] and m["engawa_outside"],
		"%s engawa runs %.1f m along a long wall, outside it" % [id, m["engawa_length"]])
	_expect(m["engawa_depth"] >= 0.75, "%s engawa is %.2f m deep" % [id, m["engawa_depth"]])
	_expect(absf(m["engawa_deck_top"] - m["floor_top"]) < 0.01, "%s engawa deck is level with the floor (%.3f vs %.3f)" % [id, m["engawa_deck_top"], m["floor_top"]])
	_expect(m["engawa_posts"] >= 4 and m["engawa_beam"] >= 1, "%s engawa has %d posts under a head beam" % [id, m["engawa_posts"]])
	_expect(m["eave_over_engawa"] >= 0.15, "%s eave reaches %.2f m past the engawa's edge" % [id, m["eave_over_engawa"]])
	# (2) the irimoya roof
	_expect(m["roof_faces"] == 6 and m["roof_hip_ends"] == 2, "%s roof is a hipped skirt and two gable planes (%d faces, %d hip ends)" % [id, m["roof_faces"], m["roof_hip_ends"]])
	_expect(m["gable_angle"] > m["skirt_angle"] + 8.0, "%s gable (%.0f deg) is steeper than the skirt (%.0f deg)" % [id, m["gable_angle"], m["skirt_angle"]])
	_expect(m["hafu_count"] == 2 and m["hafu_vertical"] == 2 and m["hafu_on_skirt"], "%s two vertical hafu stand on the skirt" % id)
	_expect(m["eave_depth"] >= EAVE_MIN, "%s eaves are %.2f m deep at least (%.2f sides, %.2f ends)" % [id, m["eave_depth"], m["eave_side"], m["eave_end"]])
	# (3) the sliding lattice screens
	_expect(m["screen_openings"] >= 2 and m["screen_tracks"] >= 2 * m["screen_openings"], "%s %d screen openings with tracks" % [id, m["screen_openings"]])
	_expect(m["screen_panels"] >= 4 and m["screen_lanes"] >= 2, "%s %d panels on %d lanes" % [id, m["screen_panels"], m["screen_lanes"]])
	_expect(m["screen_bars"] >= 40, "%s lattice of %d bars" % [id, m["screen_bars"]])
	_expect(m["screen_wall_share"] >= 0.5, "%s screens span %.0f%% of the engawa wall" % [id, m["screen_wall_share"] * 100.0])
	_expect(m["screen_off_wall"] == 0, "%s no screen part off the engawa wall (%d)" % [id, m["screen_off_wall"]])
	# (4) the main room opens onto the garden
	_expect(m["main_room_kind"] in ["parlour", "hall"], "%s main room is the %s" % [id, m["main_room_kind"]])
	_expect(m["main_touches_wall"] and m["main_screen_door"] and m["main_door_on_deck"], "%s main room has a wide screen door onto the engawa" % id)
	_expect(m["garden_present"] and m["garden_beyond_deck"] and m["garden_before_door"], "%s dry garden lies beyond the deck, in front of the door" % id)
	_expect(m["garden_rocks"] >= 3 and m["garden_trees"] >= 1 and m["garden_stones"] >= 3,
		"%s garden has %d rocks, %d tree, %d stepping stones" % [id, m["garden_rocks"], m["garden_trees"], m["garden_stones"]])

	# Negative controls: each removal must be seen by the same measure.
	var flat := func(plan: HousePlan) -> void:
		plan.spec.floor_raise = 0.0
		plan.entry_steps = []
	var mf := HouseTraitMeasure.measure(_spec_of(req), seed_value, flat)
	_expect(mf["plinth_rise"] < RISE_MIN and mf["step_flights"] == 0, "%s control: a floor on the ground has no plinth (%.2f m)" % [id, mf["plinth_rise"]])
	var bare := func(plan: HousePlan) -> void:
		plan.engawa = {}
	var mb := HouseTraitMeasure.measure(_spec_of(req), seed_value, bare)
	_expect(not mb["engawa_present"] and mb["engawa_posts"] == 0, "%s control: no engawa, none measured" % id)
	var stub := func(plan: HousePlan) -> void:
		var r: Rect2 = plan.engawa["rect"]
		if r.size.y > r.size.x:
			r.size.y = 2.0
		else:
			r.size.x = 2.0
		plan.engawa["rect"] = r
	var ms := HouseTraitMeasure.measure(_spec_of(req), seed_value, stub)
	_expect(not ms["engawa_long_side"], "%s control: a 2 m stub is not an engawa along the long side (%.1f m)" % [id, ms["engawa_length"]])
	var hipped := func(plan: HousePlan) -> void:
		plan.spec.roof_type = &"hipped"
	var mh := HouseTraitMeasure.measure(_spec_of(req), seed_value, hipped)
	_expect(mh["hafu_count"] == 0 and mh["roof_faces"] == 4, "%s control: a plain hip has no hafu (%d faces)" % [id, mh["roof_faces"]])
	var gabled := func(plan: HousePlan) -> void:
		plan.spec.roof_type = &"gable"
	var mg := HouseTraitMeasure.measure(_spec_of(req), seed_value, gabled)
	_expect(mg["roof_hip_ends"] == 0 and mg["hafu_count"] == 0, "%s control: a plain gable has no hipped skirt (%d hip ends)" % [id, mg["roof_hip_ends"]])
	var shallow := func(plan: HousePlan) -> void:
		plan.spec.roof_span_out = 0.35
		plan.spec.roof_along_out = 0.35
	var me := HouseTraitMeasure.measure(_spec_of(req), seed_value, shallow)
	_expect(me["eave_depth"] < EAVE_MIN and me["eave_over_engawa"] < 0.15, "%s control: a 0.35 m eave is %.2f m deep" % [id, me["eave_depth"]])
	var glazed := func(plan: HousePlan) -> void:
		for w in plan.windows:
			w.erase("screen")
		for d in plan.doors:
			d.erase("screen")
	var mz := HouseTraitMeasure.measure(_spec_of(req), seed_value, glazed)
	_expect(mz["screen_openings"] == 0 and mz["screen_bars"] == 0, "%s control: without the screen flag no lattice is built" % id)
	var moved := func(plan: HousePlan) -> void:
		for w in plan.windows:
			if bool(w.get("screen", false)):
				w["pos"] = Vector2(-Vector2(w["pos"]).x, Vector2(w["pos"]).y)
				w["normal"] = -Vector2(w["normal"])
	var mm := HouseTraitMeasure.measure(_spec_of(req), seed_value, moved)
	_expect(mm["screen_off_wall"] > 0, "%s control: screens cut into the opposite wall are off the engawa wall (%d parts)" % [id, mm["screen_off_wall"]])
	var no_door := func(plan: HousePlan) -> void:
		for i in range(plan.doors.size() - 1, -1, -1):
			if bool(plan.doors[i].get("screen", false)):
				plan.doors.remove_at(i)
	var md := HouseTraitMeasure.measure(_spec_of(req), seed_value, no_door)
	_expect(not md["main_screen_door"], "%s control: with the screen door gone the main room does not open onto the engawa" % id)
	var elsewhere := func(plan: HousePlan) -> void:
		plan.engawa["main_room"] = plan.entrance_room()
	var mw := HouseTraitMeasure.measure(_spec_of(req), seed_value, elsewhere)
	_expect(not mw["main_screen_door"] or not mw["main_touches_wall"], "%s control: the entrance room is not the room that faces the garden" % id)
	var no_garden := func(plan: HousePlan) -> void:
		var pieces: Array[Dictionary] = []
		for pc in plan.yard_pieces:
			if str(pc["kind"]) != "dry_garden":
				pieces.append(pc)
		plan.yard_pieces = pieces
		var props: Array[Dictionary] = []
		for pr in plan.yard:
			if not str(pr["role"]).begins_with("garden_"):
				props.append(pr)
		plan.yard = props
	var mn := HouseTraitMeasure.measure(_spec_of(req), seed_value, no_garden)
	_expect(not mn["garden_present"] and mn["garden_rocks"] == 0 and mn["garden_stones"] == 0, "%s control: no garden, none measured" % id)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)
