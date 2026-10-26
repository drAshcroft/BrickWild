extends SceneTree
## HS-SAHEL: the `african` style as a Sahel courtyard house, measured from the
## plan, mass_log and component_log (HouseTraitMeasure) on the style's three
## frozen requests (tests/fixtures/family_style_requests.json, house/african/*),
## each trait with a negative control that removes it and must be noticed.
##   (1) flat-roofed banco rooms round a court: level earth roof behind a
##       parapet, unrendered earthen walls, a walled open court behind the
##       house with a flat-roofed range down each side, entered from the rear
##       door, with a gateway
##   (2) buttressed walls: pilasters on the outer walls, clear of openings
##   (3) projecting toron beams on every outer wall, clear of openings
##   (4) a decorated entry: two pinnacled pilasters and a relief frame
##   (5) the key stays `african`; the label is "Sahel Courtyard House"
##   godot --headless --path . --script res://tests/house_sahel_traits_test.gd

const FIXTURE := "res://tests/fixtures/family_style_requests.json"
var failures: Array[String] = []
var checks := 0


func _init() -> void:
	var cases := _cases()
	_expect(cases.size() == 3, "fixture holds 3 house/african requests, found %d" % cases.size())
	var seeds: Array[int] = []
	for c in cases:
		seeds.append(int(c["request"]["seed"]))
		_check_case(c)
	seeds.sort()
	_expect(seeds == [1, 8102, 21325], "the frozen seeds are 1, 8102 and 21325 (%s)" % [seeds])
	_check_identity()
	for f in failures:
		printerr("FAIL " + f)
	print("HS-SAHEL: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _cases() -> Array:
	var out: Array = []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for c in parsed["cases"]:
		if str(c["id"]).begins_with("house/african/"):
			out.append(c)
	return out


func _spec_of(req: Dictionary) -> HouseSpec:
	return HouseTraitMeasure.make_spec(StringName(req["style"]), float(req["width"]),
		float(req["length"]), float(req["height"]), int(req["storeys"]))


func _check_identity() -> void:
	_expect(HouseSpec.STYLES.has(&"african"), "the style key stays `african`")
	_expect(str(HouseSpec.STYLES[&"african"]["label"]) == "Sahel Courtyard House",
		"the label is the Sahel courtyard house (%s)" % HouseSpec.STYLES[&"african"]["label"])


func _check_case(c: Dictionary) -> void:
	var req: Dictionary = c["request"]
	var sd := int(req["seed"])
	var id := str(c["id"])
	var m := HouseTraitMeasure.measure(_spec_of(req), sd)
	# (1) flat-roofed banco rooms round a court
	_expect(m["sahel"], "%s is a sahel house" % id)
	_expect(m["roof_flat"] and m["roof_earth"], "%s roof is level earth (%.1f degrees)" % [id, m["roof_angle_deg"]])
	_expect(m["parapet_count"] >= 4, "%s has a parapet on the roof edge (%d)" % [id, m["parapet_count"]])
	_expect(m["banco_walls"], "%s walls are unrendered mud brick, thick (%.2f m)" % [id, m["wall_thick"]])
	_expect(m["room_count"] >= 3, "%s has rooms (%d)" % [id, m["room_count"]])
	_expect(m["sahel_court_present"], "%s has a court" % id)
	_expect(m["sahel_court_open"], "%s court is open to the sky" % id)
	_expect(m["sahel_court_rear_wall"], "%s court is closed by a rear wall" % id)
	_expect(m["court_range_sides"] == 2 and m["court_range_roofs"] >= 2, "%s court has a range down each side" % id)
	_expect(m["court_range_flat"], "%s court ranges are flat-roofed" % id)
	_expect(m["court_range_open"], "%s court middle is open (the ranges face it)" % id)
	_expect(m["sahel_court_door"], "%s rear door opens onto the court" % id)
	_expect(m["sahel_court_gate"] >= 1.0, "%s court has a gateway %.2f m wide" % [id, m["sahel_court_gate"]])
	_expect(m["court_sides"] >= 4, "%s court is bounded on 4 sides (house, two ranges, wall): %d" % [id, m["court_sides"]])
	_expect(m["open_windows"], "%s windows are open apertures, no glass (%d panes)" % [id, m["glazing_count"]])
	# (2) buttresses
	_expect(m["buttress_count"] >= 6, "%s has buttresses (%d)" % [id, m["buttress_count"]])
	_expect(m["buttress_walls"] >= 2, "%s buttresses stand on %d walls" % [id, m["buttress_walls"]])
	_expect(m["buttress_reach"] >= 0.35, "%s buttresses stand %.2f m off the wall" % [id, m["buttress_reach"]])
	_expect(m["buttress_height_frac"] >= 0.95, "%s buttresses rise the wall's full height (%.2f)" % [id, m["buttress_height_frac"]])
	_expect(m["buttress_clear"], "%s no buttress stands on a door or window" % id)
	# (3) toron
	_expect(m["toron_count"] >= 24, "%s has toron (%d)" % [id, m["toron_count"]])
	_expect(m["toron_walls"] == 4, "%s toron on all four walls (%d)" % [id, m["toron_walls"]])
	_expect(m["toron_reach"] >= 0.3, "%s toron projects %.2f m" % [id, m["toron_reach"]])
	_expect(m["toron_wood"] and m["toron_inside"], "%s toron are wood stakes that run into the wall" % id)
	_expect(m["toron_clear"], "%s no toron crosses a door or window" % id)
	# (4) the decorated entry
	_expect(m["entry_pinnacles"] == 2 and m["entry_flank"], "%s entry has a pinnacle each side of the door" % id)
	_expect(m["entry_above_parapet"], "%s entry pinnacles rise above the parapet" % id)
	_expect(m["entry_relief_count"] >= 5 and m["entry_relief_frames_door"], "%s door has a relief frame (%d parts)" % [id, m["entry_relief_count"]])

	# Negative controls: each removal must be seen by the same measure.
	var gable := func(plan: HousePlan) -> void:
		plan.spec.roof_type = &"gable"
	var mg := HouseTraitMeasure.measure(_spec_of(req), sd, gable)
	_expect(not mg["roof_flat"], "%s control: a gable roof is not flat (%.1f degrees)" % [id, mg["roof_angle_deg"]])
	var timber := func(plan: HousePlan) -> void:
		plan.spec.timber_frame = true
	_expect(not HouseTraitMeasure.measure(_spec_of(req), sd, timber)["banco_walls"],
		"%s control: a timber-framed wall is not banco" % id)
	var thin := func(plan: HousePlan) -> void:
		plan.spec.wall_thickness_override = 0.2
	_expect(not HouseTraitMeasure.measure(_spec_of(req), sd, thin)["banco_walls"],
		"%s control: a thin wall is not banco" % id)
	var no_court := func(plan: HousePlan) -> void:
		var keep: Array[Dictionary] = []
		for pc in plan.yard_pieces:
			if str(pc["kind"]) != "court":
				keep.append(pc)
		plan.yard_pieces = keep
	var mc := HouseTraitMeasure.measure(_spec_of(req), sd, no_court)
	_expect(not mc["sahel_court_present"] and mc["court_sides"] == 0, "%s control: court removed is noticed" % id)
	var no_ranges := func(plan: HousePlan) -> void:
		for pc in plan.yard_pieces:
			if str(pc["kind"]) == "court":
				var keep: Array = []
				for part in pc["parts"]:
					if not str(part["role"]).begins_with("court_range"):
						keep.append(part)
				pc["parts"] = keep
	var mr := HouseTraitMeasure.measure(_spec_of(req), sd, no_ranges)
	_expect(mr["court_range_sides"] == 0 and mr["court_sides"] < 4, "%s control: a court with no ranges has fewer than 4 sides (%d)" % [id, mr["court_sides"]])
	var pitched := func(plan: HousePlan) -> void:
		for pc in plan.yard_pieces:
			if str(pc["kind"]) == "court":
				for part in pc["parts"]:
					if str(part["role"]) == "court_range_roof":
						part["size"] = Vector3(part["size"].x, 1.2, part["size"].z)
	_expect(not HouseTraitMeasure.measure(_spec_of(req), sd, pitched)["court_range_flat"],
		"%s control: a deep roof slab is not a flat range roof" % id)
	var roofed := func(plan: HousePlan) -> void:
		for pc in plan.yard_pieces:
			if str(pc["kind"]) == "court":
				pc["parts"].append({"role": "court_roof", "surf": "roof", "size": Vector3(6, 0.2, 2),
					"centre": Vector3(0, 2.6, 0), "basis": Basis()})
	_expect(not HouseTraitMeasure.measure(_spec_of(req), sd, roofed)["sahel_court_open"],
		"%s control: a roofed court is not open" % id)
	var no_door := func(plan: HousePlan) -> void:
		for d in plan.doors:
			if bool(d.get("exterior", false)) and not bool(d.get("front", false)):
				d["exterior"] = false
	_expect(not HouseTraitMeasure.measure(_spec_of(req), sd, no_door)["sahel_court_door"],
		"%s control: with no rear door the court is not entered from the house" % id)
	var glazed := func(plan: HousePlan) -> void:
		plan.spec.unglazed = false
	var mgl := HouseTraitMeasure.measure(_spec_of(req), sd, glazed)
	_expect(mgl["glazing_count"] > 0 and not mgl["open_windows"], "%s control: glazing is noticed (%d panes)" % [id, mgl["glazing_count"]])
	var no_but := func(plan: HousePlan) -> void:
		plan.spec.sahel_skip = PackedStringArray(["buttress"])
	var mb := HouseTraitMeasure.measure(_spec_of(req), sd, no_but)
	_expect(mb["buttress_count"] == 0 and not mb["buttress_clear"] and mb["toron_count"] > 0 and mb["entry_pinnacles"] == 2,
		"%s control: buttresses removed, nothing else" % id)
	var no_toron := func(plan: HousePlan) -> void:
		plan.spec.sahel_skip = PackedStringArray(["toron"])
	var mt := HouseTraitMeasure.measure(_spec_of(req), sd, no_toron)
	_expect(mt["toron_count"] == 0 and mt["toron_walls"] == 0 and mt["buttress_count"] > 0,
		"%s control: toron removed, nothing else" % id)
	var no_entry := func(plan: HousePlan) -> void:
		plan.spec.sahel_skip = PackedStringArray(["entry"])
	var me := HouseTraitMeasure.measure(_spec_of(req), sd, no_entry)
	_expect(me["entry_pinnacles"] == 0 and not me["entry_flank"] and not me["entry_relief_frames_door"] and me["toron_count"] > 0,
		"%s control: entry removed, nothing else" % id)
	# a Mediterranean house is none of this (the measure does not read it onto another style)
	var med := HouseTraitMeasure.measure(HouseTraitMeasure.make_spec(&"mediterranean",
		float(req["width"]), float(req["length"]), float(req["height"]), 1), sd)
	_expect(not med["sahel"] and med["buttress_count"] == 0 and med["toron_count"] == 0 and med["entry_pinnacles"] == 0,
		"%s control: a mediterranean house has no buttress, toron or pinnacle" % id)


func _expect(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures.append(msg)
