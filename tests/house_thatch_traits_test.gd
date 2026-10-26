extends SceneTree
## HS-THATCH: the four thatch_cottage traits, measured from the plan, mass_log
## and component_log (HouseTraitMeasure) on the style's three frozen requests
## (tests/fixtures/family_style_requests.json, house/thatch_cottage/*, the
## style's 8 x 10 m default), each with a negative control that removes the
## trait and must be noticed.
##   (1) thick soft thatch: eaves at least 0.4 m through and rounded (a closed
##       profile, no corner sharper than 60 degrees), and a combed ridge roll of
##       bundles along the whole ridge, each a saddle with no hard edge
##   (2) an eyebrow dormer: a hood of thatch swept out of the slope, seated on
##       the roof, below the ridge, with a window under the brow, near the door
##   (3) pale rendered cob: a pale wall and not one timber-frame component
##   (4) a flower-garden front: a path to the door, a flower bed on each side of
##       it, flowers on the beds, and no work-yard prop at the front
##   godot --headless --path . --script res://tests/house_thatch_traits_test.gd

const FIXTURE := "res://tests/fixtures/family_style_requests.json"
const EAVE_MIN := 0.40
const SOFT_TURN_MAX := 60.0
var failures: Array[String] = []
var checks := 0


func _init() -> void:
	var cases := _cases()
	_expect(cases.size() == 3, "fixture holds 3 house/thatch_cottage requests, found %d" % cases.size())
	for c in cases:
		_check_case(c)
	for f in failures:
		printerr("FAIL " + f)
	print("HS-THATCH: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _cases() -> Array:
	var out: Array = []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for c in parsed["cases"]:
		if str(c["id"]).begins_with("house/thatch_cottage/"):
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
	# (1) thick, soft thatch
	_expect(m["eave_count"] == 2 and m["eave_form"] == "slab", "%s has two rolled eave bundles (%d, %s)" % [id, m["eave_count"], m["eave_form"]])
	_expect(m["eave_thick"] >= EAVE_MIN, "%s eave bundle is %.2f m through" % [id, m["eave_thick"]])
	_expect(m["eave_points"] >= 8 and m["eave_turn_max"] <= SOFT_TURN_MAX,
		"%s eave is soft-edged: %d profile points, sharpest turn %.0f degrees" % [id, m["eave_points"], m["eave_turn_max"]])
	_expect(m["roll_count"] >= 10 and m["roll_cover"] >= 0.95,
		"%s ridge roll is %d bundles spanning %.0f%% of the ridge" % [id, m["roll_count"], m["roll_cover"] * 100.0])
	_expect(m["roll_points"] >= 8 and m["roll_turn_max"] <= SOFT_TURN_MAX,
		"%s ridge roll is rounded: %d profile points, sharpest exposed turn %.0f degrees" % [id, m["roll_points"], m["roll_turn_max"]])
	_expect(m["roll_height"] >= 0.25, "%s roll stands %.2f m above the ridge" % [id, m["roll_height"]])
	# the bolster hides the rafters: no tail hangs below it as a loose block
	_expect(_floating_hoods(m).is_empty(), "%s window hoods rest on their heads (floating: %s)" % [id, str(_floating_hoods(m))])
	_expect(_role_count(m, "eave_tail") == 0, "%s shows %d rafter tails under the thatch bolster" % [id, _role_count(m, "eave_tail")])
	# (2) the eyebrow dormer
	_expect(m["eyebrow_count"] >= 1, "%s has %d eyebrow dormer(s)" % [id, m["eyebrow_count"]])
	_expect(m["eyebrow_glazing"] >= m["eyebrow_count"], "%s eyebrow has a window under its brow (%d panes)" % [id, m["eyebrow_glazing"]])
	_expect(m["eyebrow_width"] >= 1.2 and m["eyebrow_rise"] >= 0.35,
		"%s eyebrow hood is %.2f m wide and %.2f m proud of the thatch" % [id, m["eyebrow_width"], m["eyebrow_rise"]])
	_expect(m["eyebrow_seated"], "%s eyebrow hood sits on the roof surface" % id)
	_expect(m["eyebrow_below_ridge"], "%s eyebrow hood stays below the ridge" % id)
	_expect(m["eyebrow_faces_entrance"], "%s eyebrow is on the slope by the entrance" % id)
	_expect(m["eyebrow_clear_of_chimney"], "%s eyebrow clears the chimney" % id)
	# (3) pale cob, no frame
	_expect(m["wall_pale"], "%s wall is pale" % id)
	_expect(m["wall_rendered"], "%s wall is rendered cob: no frame, no stone storey" % id)
	_expect((m["frame_parts"] as Array).is_empty(), "%s shows no timber-frame component (%s)" % [id, str(m["frame_parts"])])
	# (4) the flower-garden front
	_expect(m["path_reaches_door"], "%s has a path of %d pavers to the door" % [id, m["path_pavers"]])
	_expect(m["flower_beds"] >= 2 and m["flower_bed_sides"] == 2,
		"%s has flower beds on both sides of the path (%d beds, %d sides)" % [id, m["flower_beds"], m["flower_bed_sides"]])
	_expect(m["bed_flowers"] >= 4, "%s beds carry %d flower clumps" % [id, m["bed_flowers"]])
	_expect((m["front_roles"] as Array).is_empty(), "%s front has no work-yard prop (%s)" % [id, str(m["front_roles"])])

	# Negative controls: each removal must be seen by the same measure.
	var hard := func(plan: HousePlan) -> void:
		# the same plan, built as any other thatched style builds it: a box eave, fins
		plan.spec.style = &"farmhouse"
	var mh := HouseTraitMeasure.measure(_spec_of(req), seed_value, hard)
	_expect(mh["eave_form"] == "box" and mh["eave_thick"] < EAVE_MIN,
		"%s control: a box eave is %.2f m and hard (%s)" % [id, mh["eave_thick"], mh["eave_form"]])
	_expect(mh["eave_turn_max"] > SOFT_TURN_MAX and mh["roll_turn_max"] > SOFT_TURN_MAX,
		"%s control: a box eave and a fin roll are not soft (%.0f, %.0f degrees)" % [id, mh["eave_turn_max"], mh["roll_turn_max"]])
	_expect(mh["eyebrow_count"] == 0, "%s control: the plain thatched style grows no eyebrow" % id)
	_expect(_role_count(mh, "eave_tail") > 0, "%s control: a box eave keeps its rafter tails" % id)
	var bare := func(plan: HousePlan) -> void:
		plan.spec.thatch_roll = false
	var mb := HouseTraitMeasure.measure(_spec_of(req), seed_value, bare)
	_expect(mb["eave_count"] == 0 and mb["roll_count"] == 0 and mb["eyebrow_count"] == 0,
		"%s control: no thatch roll, no eave, no roll, no eyebrow" % id)
	var no_eyebrow := func(plan: HousePlan) -> void:
		plan.spec.eyebrows = 0
	var me := HouseTraitMeasure.measure(_spec_of(req), seed_value, no_eyebrow)
	_expect(me["eyebrow_count"] == 0 and not me["eyebrow_seated"], "%s control: eyebrows off, none measured" % id)
	_expect(me["eave_thick"] >= EAVE_MIN, "%s control: the eave is untouched by removing the eyebrow" % id)
	var framed := func(plan: HousePlan) -> void:
		plan.spec.timber_frame = true
	var mf := HouseTraitMeasure.measure(_spec_of(req), seed_value, framed)
	_expect(not mf["wall_rendered"] and not (mf["frame_parts"] as Array).is_empty(),
		"%s control: a timber-framed wall is not cob (%s)" % [id, str(mf["frame_parts"])])
	var dark := func(plan: HousePlan) -> void:
		plan.spec.wall_color = Color("4a5a3a")
	_expect(not HouseTraitMeasure.measure(_spec_of(req), seed_value, dark)["wall_pale"],
		"%s control: a dark wall is not pale cob" % id)
	var no_beds := func(plan: HousePlan) -> void:
		var pieces: Array[Dictionary] = []
		for pc in plan.yard_pieces:
			if str(pc["role"]) != "flower_bed":
				pieces.append(pc)
		plan.yard_pieces = pieces
		var props: Array[Dictionary] = []
		for pr in plan.yard:
			if str(pr["role"]) != "bed_flowers":
				props.append(pr)
		plan.yard = props
	var mn := HouseTraitMeasure.measure(_spec_of(req), seed_value, no_beds)
	_expect(mn["flower_beds"] == 0 and mn["bed_flowers"] == 0, "%s control: no beds, no flower garden" % id)
	var yard_work := func(plan: HousePlan) -> void:
		var door: Dictionary = plan.doors[plan.entrance()]
		var n := Vector2(door["normal"]).normalized()
		var at := Vector2(door["pos"]) + n * 2.2 + Vector2(n.y, -n.x) * 2.4
		plan.yard.append(HouseYard.make_prop("Crate_Wooden", at, 0.0, 0.9, "crates", "front"))
	var mw := HouseTraitMeasure.measure(_spec_of(req), seed_value, yard_work)
	_expect(not (mw["front_roles"] as Array).is_empty(), "%s control: a crate at the front is a work-yard prop" % id)
	var no_path := func(plan: HousePlan) -> void:
		var pieces: Array[Dictionary] = []
		for pc in plan.yard_pieces:
			if str(pc["kind"]) != "path":
				pieces.append(pc)
		plan.yard_pieces = pieces
	_expect(not HouseTraitMeasure.measure(_spec_of(req), seed_value, no_path)["path_reaches_door"],
		"%s control: with the path taken up nothing reaches the door" % id)


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func _role_count(m: Dictionary, role: String) -> int:
	var n := 0
	for row in m.get("component_log", []):
		if str(row.get("role", "")) == role:
			n += 1
	return n


## Hosts whose dripstone hood does not rest on the window head under it (a gap
## of more than 5 mm reads as a loose bar above the window).
func _floating_hoods(m: Dictionary) -> Array:
	var head_top := {}
	for row in m.get("component_log", []):
		if str(row.get("role", "")) == "opening_head":
			head_top[row["host"]] = Transform3D(row["xf"]).origin.y + Vector3(row["size"]).y * 0.5
	var out: Array = []
	for row in m.get("component_log", []):
		if str(row.get("role", "")) != "opening_hood":
			continue
		var bottom := Transform3D(row["xf"]).origin.y - Vector3(row["size"]).y * 0.5
		if not head_top.has(row["host"]) or absf(bottom - float(head_top[row["host"]])) > 0.005:
			out.append(row["host"])
	return out
