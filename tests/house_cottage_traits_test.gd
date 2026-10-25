extends SceneTree
## HS-COTTAGE: the three cottage traits, measured from the plan, mass_log and
## component_log (HouseTraitMeasure), on the style's three frozen requests
## (tests/fixtures/family_style_requests.json, house/cottage/*), each with a
## negative control that removes the trait and must be noticed.
##   godot --headless --path . --script res://tests/house_cottage_traits_test.gd

const FIXTURE := "res://tests/fixtures/family_style_requests.json"
const EAVE_MAX := 2.6
var failures: Array[String] = []
var checks := 0


func _init() -> void:
	var cases := _cases()
	_expect(cases.size() == 3, "fixture holds 3 house/cottage requests, found %d" % cases.size())
	for c in cases:
		_check_case(c)
	for f in failures:
		printerr("FAIL " + f)
	print("HS-COTTAGE: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _cases() -> Array:
	var out: Array = []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for c in parsed["cases"]:
		if str(c["id"]).begins_with("house/cottage/"):
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
	# (1) one storey, low eaves
	_expect(m["storeys"] == 1, "%s is one storey (got %d)" % [id, m["storeys"]])
	_expect(m["eave_top"] <= EAVE_MAX + 0.001, "%s eave wall top %.2f m <= %.1f" % [id, m["eave_top"], EAVE_MAX])
	# (2) exactly one stack, on the hearth wall, above the ridge
	_expect(m["chimney_count"] == 1, "%s has exactly one chimney stack (got %d)" % [id, m["chimney_count"]])
	_expect(m["chimney_on_hearth_wall"], "%s stack stands on the hearth wall" % id)
	_expect(m["chimney_above_ridge"], "%s stack %.2f rises above ridge %.2f" % [id, m["chimney_top"], m["ridge_top"]])
	# (3) a sheltered door
	_expect(m["door_sheltered"], "%s front door has a porch roof, posts and step" % id)

	# Negative controls: each removal must be seen by the same measure.
	var tall := _spec_of(req)
	tall.storeys = 2
	var mt := HouseTraitMeasure.measure(tall, seed_value)
	_expect(mt["eave_top"] > EAVE_MAX, "%s control: a two-storey house fails the eave limit" % id)
	var no_stack := func(plan: HousePlan) -> void: plan.spec.chimney = false
	var mn := HouseTraitMeasure.measure(_spec_of(req), seed_value, no_stack)
	_expect(mn["chimney_count"] != 1, "%s control: removing the chimney is noticed" % id)
	var no_porch := func(plan: HousePlan) -> void: plan.spec.porch = false
	var mp := HouseTraitMeasure.measure(_spec_of(req), seed_value, no_porch)
	_expect(not mp["door_sheltered"], "%s control: removing the porch is noticed" % id)


func _expect(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures.append(msg)
