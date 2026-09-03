class_name VillageSuite
extends RefCounted
## VIL-001: VillageSpec derives its fields deterministically and purely from
## its seven inputs, invalid inputs are reported rather than clamped, and
## VillagePlan's typed helpers and `equals()` behave as VillageQA will need
## them to. VILLAGES §1, §11.

static func run() -> SuiteResult:
	var res := SuiteResult.new("village")
	_check_valid_spec_derives(res)
	_check_invalid_population_errors(res)
	_check_wall_needs_population_or_garrison(res)
	_check_purity(res)
	_check_households_range(res)
	_check_no_mesh_or_node_references(res)
	_check_plan_helpers(res)
	_check_plan_equals(res)
	_check_programme_house_count(res)
	_check_programme_earned_kinds_sweep(res)
	_check_programme_storeys_and_style_mix(res)
	_check_programme_trades(res)
	_check_programme_special_trades_gated(res)
	_check_programme_no_house_family_import(res)
	_check_programme_culture_styles_build(res)
	return res


static func _make_spec(p_seed: int, population: int = 80, culture: StringName = &"english",
		purpose: StringName = &"farming", wealth: float = 0.4,
		enclosure: StringName = &"none", water: StringName = &"none") -> VillageSpec:
	var spec := VillageSpec.new(p_seed)
	spec.population = population
	spec.culture = culture
	spec.purpose = purpose
	spec.wealth = wealth
	spec.enclosure = enclosure
	spec.water = water
	return spec


static func _check_valid_spec_derives(res: SuiteResult) -> void:
	var spec: VillageSpec = _make_spec(1)
	spec.generate(1)
	res.checked += 1
	if not spec.valid():
		res.fail("valid spec reported errors: %s" % [spec.errors()])
	res.checked += 1
	if spec.households <= 0:
		res.fail("households not derived: %d" % spec.households)
	res.checked += 1
	if spec.form == &"":
		res.fail("form not derived")
	res.checked += 1
	if spec.programme.is_empty():
		res.fail("programme not derived")
	res.checked += 1
	if spec.site.size.x <= 0.0 or spec.site.size.y <= 0.0:
		res.fail("site not derived: %s" % spec.site)
	res.checked += 1
	if spec.variant_name.is_empty():
		res.fail("variant_name not derived")
	# every village gets houses and a well (§4 "every" rows)
	var kinds: Array = []
	for row in spec.programme:
		kinds.append(row["kind"])
	res.checked += 1
	if not (&"house" in kinds):
		res.fail("programme missing 'house' row")
	res.checked += 1
	if not (&"well" in kinds):
		res.fail("programme missing 'well' row")


static func _check_invalid_population_errors(res: SuiteResult) -> void:
	for bad_pop in [4, 900]:
		var spec: VillageSpec = _make_spec(2, bad_pop)
		res.checked += 1
		if spec.valid():
			res.fail("population %d should be invalid" % bad_pop)
		var errs: Array[String] = spec.errors()
		res.checked += 1
		if errs.is_empty():
			res.fail("population %d produced no error message" % bad_pop)
		# not a clamp: generate() must not silently produce a full village
		spec.generate(2)
		res.checked += 1
		if spec.households != 0 or spec.form != &"":
			res.fail("population %d was clamped into a derived village instead of refused" % bad_pop)


static func _check_wall_needs_population_or_garrison(res: SuiteResult) -> void:
	var too_small_walled: VillageSpec = _make_spec(3, 80, &"english", &"farming", 0.4, &"wall")
	res.checked += 1
	if too_small_walled.valid():
		res.fail("wall at population 80, purpose farming should be invalid")

	var garrison_walled: VillageSpec = _make_spec(4, 80, &"english", &"garrison", 0.4, &"wall")
	res.checked += 1
	if not garrison_walled.valid():
		res.fail("wall at population 80, purpose garrison should be valid: %s" % [garrison_walled.errors()])

	var big_walled: VillageSpec = _make_spec(5, 200, &"english", &"farming", 0.4, &"wall")
	res.checked += 1
	if not big_walled.valid():
		res.fail("wall at population 200 should be valid: %s" % [big_walled.errors()])


## Planning the same spec twice must give identical derived fields, and must
## not mutate the spec used to derive them a second time (spec.generate() is
## itself pure given the same inputs).
static func _check_purity(res: SuiteResult) -> void:
	var a: VillageSpec = _make_spec(42, 120, &"frankish", &"market", 0.6, &"none", &"river")
	var b: VillageSpec = _make_spec(42, 120, &"frankish", &"market", 0.6, &"none", &"river")
	a.generate(42)
	b.generate(42)

	res.checked += 1
	if a.households != b.households:
		res.fail("households not pure: %d vs %d" % [a.households, b.households])
	res.checked += 1
	if a.form != b.form:
		res.fail("form not pure: %s vs %s" % [a.form, b.form])
	res.checked += 1
	if a.variant_name != b.variant_name:
		res.fail("variant_name not pure: %s vs %s" % [a.variant_name, b.variant_name])
	res.checked += 1
	if a.site != b.site:
		res.fail("site not pure: %s vs %s" % [a.site, b.site])
	res.checked += 1
	if a.programme.size() != b.programme.size():
		res.fail("programme not pure: %d rows vs %d rows" % [a.programme.size(), b.programme.size()])

	# generating twice on the SAME spec object must also be pure
	var before_households: int = a.households
	var before_form: StringName = a.form
	a.generate(42)
	res.checked += 1
	if a.households != before_households or a.form != before_form:
		res.fail("re-generating the same spec changed its derived fields")


static func _check_households_range(res: SuiteResult) -> void:
	# §1: "between 12 and 500 people, households run from 3 to about 110."
	var low: VillageSpec = _make_spec(7, 12)
	low.generate(7)
	res.checked += 1
	if low.households < 2 or low.households > 5:
		res.fail("households at population 12 = %d, expected roughly 3" % low.households)

	var high: VillageSpec = _make_spec(8, 500)
	high.generate(8)
	res.checked += 1
	if high.households < 95 or high.households > 125:
		res.fail("households at population 500 = %d, expected roughly 110" % high.households)


## Grep guard for the acceptance criterion "no Godot node or mesh is
## referenced in VillagePlan". Enforced here (not just by eye) so a future
## edit that reaches for a Node3D/Mesh convenience is caught immediately.
## VillageSpec is allowed to name `MeshKit` in its programme table (the
## request notes, not a reference to the type), so only the plan is grepped,
## matching the acceptance criterion's own wording.
static func _check_no_mesh_or_node_references(res: SuiteResult) -> void:
	var path := "res://src/village/village_plan.gd"
	var f := FileAccess.open(path, FileAccess.READ)
	res.checked += 1
	if f == null:
		res.fail("could not open %s to grep it" % path)
		return
	var text: String = f.get_as_text()
	f.close()
	for banned in ["Node3D", "Mesh"]:
		res.checked += 1
		if text.contains(banned):
			res.fail("%s references '%s'" % [path, banned])


static func _sample_plan(spec: VillageSpec) -> VillagePlan:
	var plan := VillagePlan.new(spec)
	plan.roads.append({"points": PackedVector2Array([Vector2(-40, 0), Vector2(40, 0)]),
		"class": &"through", "width": 6.0})
	plan.roads.append({"points": PackedVector2Array([Vector2(0, 0), Vector2(0, 20)]),
		"class": &"lane", "width": 2.5})
	plan.lots.append({"poly": Poly.from_rect(Rect2(Vector2(-20, 2), Vector2(10, 10))),
		"front": PackedVector2Array([Vector2(-20, 2), Vector2(-10, 2)]), "road": 0})
	plan.buildings.append({"lot": 0, "request": null, "placement": {}, "door": Vector2(-15, 2),
		"kind": &"house"})
	plan.buildings.append({"lot": -1, "request": null, "placement": {}, "door": Vector2(0, 0),
		"kind": &"well"})
	plan.gate_crossings.append({"pos": Vector2(-40, 0), "road": 0})
	plan.gate_crossings.append({"pos": Vector2(0, 20), "road": 1})
	return plan


static func _check_plan_helpers(res: SuiteResult) -> void:
	var spec: VillageSpec = _make_spec(9)
	var plan: VillagePlan = _sample_plan(spec)

	res.checked += 1
	if plan.roads_of_class(&"through") != [0]:
		res.fail("roads_of_class(through) = %s, want [0]" % [plan.roads_of_class(&"through")])
	res.checked += 1
	if plan.roads_of_class(&"lane") != [1]:
		res.fail("roads_of_class(lane) = %s, want [1]" % [plan.roads_of_class(&"lane")])
	res.checked += 1
	if plan.roads_of_class(&"street").size() != 0:
		res.fail("roads_of_class(street) should be empty")

	res.checked += 1
	if plan.lot_of_building(0) != 0:
		res.fail("lot_of_building(0) = %d, want 0" % plan.lot_of_building(0))
	res.checked += 1
	if plan.lot_of_building(1) != -1:
		res.fail("lot_of_building(1) = %d, want -1 (no lot)" % plan.lot_of_building(1))
	res.checked += 1
	if plan.lot_of_building(99) != -1:
		res.fail("lot_of_building(out of range) should be -1")

	res.checked += 1
	if plan.buildings_of_kind(&"house") != [0]:
		res.fail("buildings_of_kind(house) = %s, want [0]" % [plan.buildings_of_kind(&"house")])
	res.checked += 1
	if not plan.has_kind(&"well"):
		res.fail("has_kind(well) should be true")
	res.checked += 1
	if plan.has_kind(&"church"):
		res.fail("has_kind(church) should be false")

	res.checked += 1
	if plan.gates().size() != 2:
		res.fail("gates() = %d, want 2" % plan.gates().size())
	res.checked += 1
	if plan.gates(0).size() != 1:
		res.fail("gates(0) = %d, want 1" % plan.gates(0).size())
	res.checked += 1
	if plan.gates(1).size() != 1:
		res.fail("gates(1) = %d, want 1" % plan.gates(1).size())


static func _check_plan_equals(res: SuiteResult) -> void:
	var spec_a: VillageSpec = _make_spec(11, 100)
	spec_a.generate(11)
	var spec_b: VillageSpec = _make_spec(11, 100)
	spec_b.generate(11)

	var plan_a: VillagePlan = _sample_plan(spec_a)
	var plan_b: VillagePlan = _sample_plan(spec_b)

	res.checked += 1
	if not plan_a.equals(plan_b):
		res.fail("two plans built the same way from equal specs should be equal")

	var plan_c: VillagePlan = _sample_plan(spec_b)
	plan_c.buildings[0]["door"] = Vector2(-14, 2)
	res.checked += 1
	if plan_a.equals(plan_c):
		res.fail("plans with a different door position should not be equal")

	res.checked += 1
	if plan_a.equals(null):
		res.fail("equals(null) should be false, not crash")


# ------------------------------------------------------------- VIL-005: Programmer

## House count = households, for every request in `programme()`.
static func _check_programme_house_count(res: SuiteResult) -> void:
	for population in [12, 40, 120, 300, 500]:
		var spec: VillageSpec = _make_spec(100 + population, population)
		spec.generate(100 + population)
		var reqs: Array[BuildingRequest] = VillageProgrammer.programme(spec)
		var houses := 0
		for r in reqs:
			if r.kind == &"house":
				houses += 1
		res.checked += 1
		if houses != spec.households:
			res.fail("population %d: %d house requests, want %d households" % [
				population, houses, spec.households])


## VIL-005's headline criterion: population 12..500 step 10, every purpose,
## `programme()`'s non-house kinds match `VillageProgrammer.earned_kinds()`
## (an independent re-statement of §4's thresholds) in both directions --
## nothing unearned, nothing missing.
static func _check_programme_earned_kinds_sweep(res: SuiteResult) -> void:
	var seed := 1000
	for purpose in VillageSpec.PURPOSES:
		var population := 12
		while population <= 500:
			seed += 1
			var water: StringName = &"river" if population % 20 == 0 else &"none"
			var enclosure: StringName = &"wall" if (population >= 150 and population % 3 == 0) else &"none"
			var spec: VillageSpec = _make_spec(seed, population, &"english", purpose, 0.4, enclosure, water)
			spec.generate(seed)
			res.checked += 1
			if not spec.valid():
				res.fail("sweep spec invalid at pop %d purpose %s: %s" % [population, purpose, spec.errors()])
				population += 10
				continue

			var reqs: Array[BuildingRequest] = VillageProgrammer.programme(spec)
			var got_kinds := _earned_kinds_of(reqs)

			var expect_kinds := {}
			for k in VillageProgrammer.earned_kinds(population, purpose, water):
				expect_kinds[k] = true

			res.checked += 1
			for k in expect_kinds:
				if not got_kinds.has(k):
					res.fail("pop %d purpose %s water %s: missing earned kind '%s'" % [
						population, purpose, water, k])
			res.checked += 1
			for k in got_kinds:
				if not expect_kinds.has(k):
					res.fail("pop %d purpose %s water %s: unearned kind '%s' present" % [
						population, purpose, water, k])

			population += 10


## Maps every non-house request in `reqs` back to the programme `kind`
## vocabulary `earned_kinds()` uses, by family and business/purpose.
## `shrine` vs `church` are told apart by the request's height (the shrine's
## small envelope is 6 m, the full church's 12 m); `manor` is the only
## castle a village programme requests; the second `shop(&"tavern")` request
## (§4: "apothecary, second tavern") is told apart from the first by order.
static func _earned_kinds_of(reqs: Array[BuildingRequest]) -> Dictionary:
	var out := {}
	var tavern_seen := false
	for r in reqs:
		match r.kind:
			&"house":
				continue
			&"church":
				out[&"church" if r.height > 8.0 else &"shrine"] = true
			&"temple":
				out[&"temple"] = true
			&"castle":
				out[&"manor"] = true
			&"shop":
				if r.purpose == &"tavern":
					out[&"tavern_2" if tavern_seen else &"tavern"] = true
					tavern_seen = true
				elif r.purpose == &"blacksmith":
					out[&"smithy"] = true
				else:
					out[r.purpose] = true
	return out


static func _check_programme_storeys_and_style_mix(res: SuiteResult) -> void:
	var poor: VillageSpec = _make_spec(201, 80, &"english", &"farming", 0.1)
	poor.generate(201)
	var poor_reqs: Array[BuildingRequest] = VillageProgrammer.programme(poor)
	res.checked += 1
	for r in poor_reqs:
		if r.kind == &"house" and r.storeys != 1:
			res.fail("wealth 0.1 house has storeys %d, want 1" % r.storeys)
			break

	var rich: VillageSpec = _make_spec(202, 80, &"english", &"farming", 0.9)
	rich.generate(202)
	var rich_reqs: Array[BuildingRequest] = VillageProgrammer.programme(rich)
	res.checked += 1
	for r in rich_reqs:
		if r.kind == &"house" and r.storeys != 2:
			res.fail("wealth 0.9 house has storeys %d, want 2" % r.storeys)
			break

	# cottage/townhouse mix: more townhouse-styled houses at high wealth
	# than at low wealth, for a culture whose base style is cottage.
	var poor_townhouses := 0
	for r in poor_reqs:
		if r.kind == &"house" and r.style == &"townhouse":
			poor_townhouses += 1
	var rich_townhouses := 0
	for r in rich_reqs:
		if r.kind == &"house" and r.style == &"townhouse":
			rich_townhouses += 1
	res.checked += 1
	if not (rich_townhouses > poor_townhouses):
		res.fail("wealth should move the house mix toward townhouse: poor=%d rich=%d" % [
			poor_townhouses, rich_townhouses])


static func _check_programme_trades(res: SuiteResult) -> void:
	var farming: VillageSpec = _make_spec(210, 200, &"english", &"farming")
	farming.generate(210)
	var farming_reqs: Array[BuildingRequest] = VillageProgrammer.programme(farming)
	var farmer_count := 0
	var farming_houses := 0
	for r in farming_reqs:
		if r.kind == &"house":
			farming_houses += 1
			if r.purpose == &"farmer":
				farmer_count += 1
	res.checked += 1
	if float(farmer_count) / float(farming_houses) <= 0.5:
		res.fail("farming village: farmer trade should be a majority, got %d/%d" % [
			farmer_count, farming_houses])

	var market: VillageSpec = _make_spec(211, 200, &"english", &"market")
	market.generate(211)
	var market_reqs: Array[BuildingRequest] = VillageProgrammer.programme(market)
	var none_count := 0
	var market_houses := 0
	for r in market_reqs:
		if r.kind == &"house":
			market_houses += 1
			if r.purpose == &"none":
				none_count += 1
	res.checked += 1
	if float(none_count) / float(market_houses) <= 0.5:
		res.fail("market village: 'none' trade should be a majority, got %d/%d" % [
			none_count, market_houses])


## smith/alchemist/scholar/innkeeper appear iff the matching shop/threshold
## exists -- checked both below and above each gate.
static func _check_programme_special_trades_gated(res: SuiteResult) -> void:
	var below: VillageSpec = _make_spec(220, 25, &"english", &"farming")
	below.generate(220)
	var below_trades := _trades_present(VillageProgrammer.programme(below))
	res.checked += 1
	if &"smith" in below_trades or &"innkeeper" in below_trades or &"alchemist" in below_trades:
		res.fail("population 25 should not yet have smith/innkeeper/alchemist: %s" % [below_trades])

	var above: VillageSpec = _make_spec(221, 130, &"english", &"farming")
	above.generate(221)
	var above_trades := _trades_present(VillageProgrammer.programme(above))
	res.checked += 1
	if not (&"smith" in above_trades):
		res.fail("population 130 (>=30) should have a smith trade")
	res.checked += 1
	if not (&"innkeeper" in above_trades):
		res.fail("population 130 (>=80) should have an innkeeper trade")
	res.checked += 1
	if not (&"alchemist" in above_trades):
		res.fail("population 130 (>=120) should have an alchemist trade")

	var mining: VillageSpec = _make_spec(222, 15, &"norse", &"mining")
	# 15 is below POP_MIN (12 is the floor, so raise it) -- use a small but
	# valid mining village to prove "smithy at any size" for the purpose.
	mining.population = 18
	mining.generate(222)
	var mining_trades := _trades_present(VillageProgrammer.programme(mining))
	res.checked += 1
	if not (&"smith" in mining_trades):
		res.fail("mining purpose should earn a smith at any size (population 18)")


static func _trades_present(reqs: Array[BuildingRequest]) -> Dictionary:
	var out := {}
	for r in reqs:
		if r.kind == &"house":
			out[r.purpose] = true
	return out


## Grep guard: the village never draws a house of its own. VILLAGES §2's
## opening promise -- "the buildings inside it are ordinary
## `BuildingRequest`s answered by `BigGlade.generate()`" -- means nothing in
## src/village/ may import the house family's own planner/builder.
static func _check_programme_no_house_family_import(res: SuiteResult) -> void:
	var dir := DirAccess.open("res://src/village")
	res.checked += 1
	if dir == null:
		res.fail("could not open res://src/village to grep it")
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".gd"):
			var f := FileAccess.open("res://src/village/%s" % name, FileAccess.READ)
			if f != null:
				var text: String = f.get_as_text()
				f.close()
				res.checked += 1
				if text.contains("HousePlanner") or text.contains("HouseBuilder"):
					res.fail("%s references the house family's own planner/builder" % name)
		name = dir.get_next()
	dir.list_dir_end()


## "Culture maps to the house/shop/church/castle/temple style names that
## exist in each family's spec (a test builds one of each per culture)."
static func _check_programme_culture_styles_build(res: SuiteResult) -> void:
	for culture in VillageSpec.CULTURES:
		var styles: Dictionary = VillageProgrammer.CULTURE_STYLES[culture]

		var house_req := BuildingRequest.house(1, styles["house"], &"none")
		var house_built := BigGlade.generate(house_req)
		res.checked += 1
		if not house_built.is_ok():
			res.fail("%s house style '%s' failed to build: %s" % [
				culture, styles["house"], house_built.errors])

		var shop_req := BuildingRequest.shop(1, &"general_store", styles["house"])
		var shop_built := BigGlade.generate(shop_req)
		res.checked += 1
		if not shop_built.is_ok():
			res.fail("%s shop style '%s' failed to build: %s" % [
				culture, styles["house"], shop_built.errors])

		var church_req := BuildingRequest.church(1, styles["church"])
		var church_built := BigGlade.generate(church_req)
		res.checked += 1
		if not church_built.is_ok():
			res.fail("%s church style '%s' failed to build: %s" % [
				culture, styles["church"], church_built.errors])

		var castle_req := BuildingRequest.castle(1, styles["castle"])
		var castle_built := BigGlade.generate(castle_req)
		res.checked += 1
		if not castle_built.is_ok():
			res.fail("%s castle style '%s' failed to build: %s" % [
				culture, styles["castle"], castle_built.errors])

		var temple_req := BuildingRequest.temple(1, styles["temple_form"], styles["temple_cult"])
		var temple_built := BigGlade.generate(temple_req)
		res.checked += 1
		if not temple_built.is_ok():
			res.fail("%s temple form '%s' cult '%s' failed to build: %s" % [
				culture, styles["temple_form"], styles["temple_cult"], temple_built.errors])
