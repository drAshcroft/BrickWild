extends SceneTree
## HS-MEDITERRANEAN: the four mediterranean traits, measured from the plan,
## mass_log and component_log (HouseTraitMeasure) on the style's three frozen
## requests (tests/fixtures/family_style_requests.json, house/mediterranean/*),
## each with a negative control that removes the trait and must be noticed.
##   (1) lime-rendered (white or ochre) masonry, reveals at least 0.30 m deep
##   (2) a terracotta tile roof at 25 degrees or less (or a parapeted terrace)
##   (3) a loggia over the entrance: posts, head beam and roof
##   (4) a walled open court behind the house, entered from the rear door,
##       where the footprint allows (shorter side >= HouseYard.COURT_MIN_SIDE)
##   godot --headless --path . --script res://tests/house_mediterranean_traits_test.gd

const FIXTURE := "res://tests/fixtures/family_style_requests.json"
const REVEAL_MIN := 0.30
const ROOF_MAX_DEG := 25.0
var failures: Array[String] = []
var checks := 0


func _init() -> void:
	var cases := _cases()
	_expect(cases.size() == 3, "fixture holds 3 house/mediterranean requests, found %d" % cases.size())
	for c in cases:
		_check_case(c)
	_check_threshold()
	for f in failures:
		printerr("FAIL " + f)
	print("HS-MEDITERRANEAN: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _cases() -> Array:
	var out: Array = []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for c in parsed["cases"]:
		if str(c["id"]).begins_with("house/mediterranean/"):
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
	# (1) lime render, thick walls, deep reveals
	_expect(m["wall_kind"] in ["white", "ochre"], "%s wall is lime white or ochre (%s)" % [id, m["wall_kind"]])
	_expect(m["wall_rendered"], "%s is rendered masonry, not a frame or stone" % id)
	_expect(m["wall_thick"] >= REVEAL_MIN, "%s wall is %.2f m thick" % [id, m["wall_thick"]])
	_expect(m["reveal_min"] >= REVEAL_MIN, "%s shallowest window or door reveal is %.2f m" % [id, m["reveal_min"]])
	# (2) low tile roof (or a parapeted terrace)
	_expect(m["low_tile_roof"] or m["terrace_roof"], "%s has a low terracotta tile roof or a parapeted terrace" % id)
	_expect(m["roof_tile"] and m["roof_terracotta"], "%s roof is terracotta tile" % id)
	_expect(m["roof_angle_deg"] > 5.0 and m["roof_angle_deg"] <= ROOF_MAX_DEG,
		"%s roof falls %.1f degrees (limit %.0f)" % [id, m["roof_angle_deg"], ROOF_MAX_DEG])
	# (3) a loggia at the entrance
	_expect(m["loggia_posts"] >= 4 and m["loggia_beams"] >= 1 and m["loggia_roofs"] >= 1,
		"%s loggia has posts, a head beam and a roof (%d, %d, %d)" % [id, m["loggia_posts"], m["loggia_beams"], m["loggia_roofs"]])
	_expect(m["loggia_covers_door"], "%s loggia covers the entrance door" % id)
	_expect(m["loggia_depth"] >= 1.2, "%s loggia reaches %.2f m out (a place to sit)" % [id, m["loggia_depth"]])
	_expect(m["porch_roof_count"] == 0, "%s has the loggia, not a porch as well" % id)
	# (4) the court; the threshold is the style constant, recorded in the measure
	_expect(m["court_expected"] and m["court_min_side"] == 7.0,
		"%s footprint allows a court (shorter side >= %.1f m)" % [id, m["court_min_side"]])
	_expect(m["court_present"], "%s has a court" % id)
	_expect(m["court_inner_area"] >= 15.0, "%s court holds %.1f m2 of paving" % [id, m["court_inner_area"]])
	_expect(m["court_open"], "%s court is open to the sky" % id)
	_expect(m["court_rear_wall"] and m["court_wall_parts"] >= 4, "%s court is walled (%d wall parts)" % [id, m["court_wall_parts"]])
	_expect(m["court_gate"] >= 1.0, "%s court has a gateway %.2f m wide" % [id, m["court_gate"]])
	_expect(m["court_door"], "%s rear door opens onto the court" % id)

	# Negative controls: each removal must be seen by the same measure.
	var timber := func(plan: HousePlan) -> void:
		plan.spec.timber_frame = true
	_expect(not HouseTraitMeasure.measure(_spec_of(req), seed_value, timber)["wall_rendered"],
		"%s control: a timber-framed wall is not a render" % id)
	var green := func(plan: HousePlan) -> void:
		plan.spec.wall_color = Color("4f7a3a")
	_expect(HouseTraitMeasure.measure(_spec_of(req), seed_value, green)["wall_kind"] == "other",
		"%s control: a green wall is not lime white or ochre" % id)
	var thin := func(plan: HousePlan) -> void:
		plan.spec.wall_thickness_override = 0.12
	var mt := HouseTraitMeasure.measure(_spec_of(req), seed_value, thin)
	_expect(mt["reveal_min"] < REVEAL_MIN, "%s control: a thin wall has shallow reveals (%.2f m)" % [id, mt["reveal_min"]])
	var steep := func(plan: HousePlan) -> void:
		plan.spec.roof_pitch = 0.9
	var ms := HouseTraitMeasure.measure(_spec_of(req), seed_value, steep)
	_expect(ms["roof_angle_deg"] > ROOF_MAX_DEG and not ms["low_tile_roof"],
		"%s control: a steep roof is noticed (%.1f degrees)" % [id, ms["roof_angle_deg"]])
	var slate := func(plan: HousePlan) -> void:
		plan.spec.roof_color = Color("3b3f45")
	_expect(not HouseTraitMeasure.measure(_spec_of(req), seed_value, slate)["roof_terracotta"],
		"%s control: a slate-grey roof is not terracotta" % id)
	var no_loggia := func(plan: HousePlan) -> void:
		plan.spec.veranda = false
	var ml := HouseTraitMeasure.measure(_spec_of(req), seed_value, no_loggia)
	_expect(ml["loggia_posts"] == 0 and not ml["loggia_covers_door"], "%s control: no veranda, no loggia" % id)
	var no_court := func(plan: HousePlan) -> void:
		var keep: Array[Dictionary] = []
		for pc in plan.yard_pieces:
			if str(pc["kind"]) != "court":
				keep.append(pc)
		plan.yard_pieces = keep
	var mc := HouseTraitMeasure.measure(_spec_of(req), seed_value, no_court)
	_expect(not mc["court_present"] and not mc["court_door"], "%s control: court removed is noticed" % id)
	var roofed := func(plan: HousePlan) -> void:
		for pc in plan.yard_pieces:
			if str(pc["kind"]) == "court":
				pc["parts"].append({"role": "court_roof", "surf": "roof", "size": Vector3(6, 0.2, 2),
					"centre": Vector3(0, 2.6, 0), "basis": Basis()})
	_expect(not HouseTraitMeasure.measure(_spec_of(req), seed_value, roofed)["court_open"],
		"%s control: a roofed court is not open" % id)
	var no_rear := func(plan: HousePlan) -> void:
		for pc in plan.yard_pieces:
			if str(pc["kind"]) == "court":
				var keep: Array = []
				for part in pc["parts"]:
					var sz: Vector3 = part["size"]
					if str(part["role"]) == "court_wall" and maxf(sz.x, sz.z) > 6.0:
						continue
					keep.append(part)
				pc["parts"] = keep
	_expect(not HouseTraitMeasure.measure(_spec_of(req), seed_value, no_rear)["court_rear_wall"],
		"%s control: a court with no rear wall is not walled" % id)
	var no_door := func(plan: HousePlan) -> void:
		for d in plan.doors:
			if bool(d.get("exterior", false)) and not bool(d.get("front", false)):
				d["exterior"] = false
	_expect(not HouseTraitMeasure.measure(_spec_of(req), seed_value, no_door)["court_door"],
		"%s control: with no rear door the court is not entered from the house" % id)


## "Where the footprint allows": a 6 x 8 m house is below COURT_MIN_SIDE and is
## not given a court; it keeps the render, the low roof and the loggia.
func _check_threshold() -> void:
	for sd in [1, 8102, 21325]:
		var spec := HouseTraitMeasure.make_spec(&"mediterranean", 6.0, 8.0, 2.6, 1)
		var m := HouseTraitMeasure.measure(spec, sd)
		_expect(not m["court_expected"] and not m["court_present"],
			"6 x 8 m seed %d is below the %.1f m court threshold and builds none" % [sd, m["court_min_side"]])
		_expect(m["low_tile_roof"] and m["wall_rendered"] and m["reveal_min"] >= REVEAL_MIN,
			"6 x 8 m seed %d keeps the render, reveals and low roof" % sd)
		_expect(m["loggia_posts"] >= 4, "6 x 8 m seed %d keeps its loggia" % sd)


func _expect(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures.append(msg)
