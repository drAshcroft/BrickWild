extends SceneTree
## VIL-018 acceptance: 50 actual populated/dressed plans per enclosure/water
## pair. Native measurements may be shared only for byte-identical requests;
## every site, retry, lot, crossing and dresser pass uses the production path.
## --start=N --count=N split the same matrix without changing its fixtures.

var checks := 0
var cases := 0
var failures: Array[String] = []

func _init() -> void:
	var start := 0
	var count := 50
	var controls := false
	var waters: Array[StringName] = [&"none", &"pond", &"stream", &"river", &"coast"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--start="): start = int(arg.trim_prefix("--start="))
		if arg.begins_with("--count="): count = int(arg.trim_prefix("--count="))
		if arg == "--controls": controls = true
		if arg.begins_with("--water="):
			var selected := StringName(arg.trim_prefix("--water="))
			_expect(selected in waters, "unknown selected water")
			waters.assign([selected])
	_expect(start >= 0 and count > 0 and start + count <= 50, "invalid matrix slice")
	_edge_controls()
	if controls: count = 0
	for seed_index in range(start, start + count):
		if not failures.is_empty(): break
		var reference := _spec(seed_index, &"hedge", &"none")
		var requests := VillageProgrammer.programme(reference)
		print("ENCLOSURE FULL MEASURE seed=", seed_index, " buildings=", requests.size())
		var jobs: Array[Dictionary] = preload("res://tests/fixtures/native_measurement_cache.gd").measure(requests)
		_expect(jobs.size() == requests.size(), "native measurement omitted an earned request")
		if seed_index == 3: _pond_repair_controls(jobs)
		for enclosure in [&"hedge", &"palisade", &"wall"]:
			for water in waters:
				var spec := _spec(seed_index, enclosure, water)
				var expected := VillageProgrammer.programme(spec)
				var same := requests.size() == expected.size()
				for i in mini(requests.size(), expected.size()):
					same = same and requests[i].to_json() == expected[i].to_json()
				_expect(same, "measurement reuse changed native programme")
				if not same: break
				var label := "%s/%s seed=%d" % [enclosure, water, seed_index]
				var before := failures.size()
				var plan := VillageLotPlanner.plan_measured(spec, jobs)
				_expect(plan.buildings.size() == expected.size(), label + " omitted earned buildings")
				var expected_requests: Array[String] = []
				var actual_requests: Array[String] = []
				for request in expected: expected_requests.append(request.to_json())
				for building in plan.buildings: actual_requests.append(building["request"].to_json())
				expected_requests.sort()
				actual_requests.sort()
				_expect(actual_requests == expected_requests,
					label + " changed native request identities or multiplicities")
				for request in expected:
					if not plan.buildings.any(func(building: Dictionary) -> bool:
						return building["request"].to_json() == request.to_json()):
						print("ENCLOSURE FULL MISSING ", request.to_json())
				_expect(plan.lots.size() == plan.buildings.size(), label + " missing building lots")
				_expect(not plan.props.is_empty() and not plan.plants.is_empty(), label + " was not dressed")
				var scale := VillageScaleCheck.new()
				for rule in ["housed", "earned", "not_a_city", "density"]:
					scale.call("_check_" + rule, plan)
				_expect(scale.failures.is_empty(), label + ": " + "; ".join(scale.failures))
				var lots := VillageLotCheck.new()
				lots._check_tiling(plan)
				lots._check_fit(plan)
				_expect(lots.failures.is_empty(), label + ": " + "; ".join(lots.failures))
				var roads := VillageRoadCheck.new()
				roads._check_crossings(plan)
				roads._check_gates(plan)
				_expect(roads.failures.is_empty(), label + ": " + "; ".join(roads.failures))
				var dress := VillageDressCheck.new()
				dress._check_edge(plan)
				dress._check_fields(plan)
				dress._check_wood(plan)
				dress._check_culture(plan)
				_expect(dress.failures.is_empty(), label + ": " + "; ".join(dress.failures))
				var enclosure_check := VillageEnclosureCheck.check(plan, VillageEnclosurePlan.build(plan))
				_expect(enclosure_check["ok"], label + ": " + "; ".join(enclosure_check["failures"]))
				if water != &"none":
					var places := VillagePlaceCheck.new()
					places._check_mill(plan)
					_expect(places.failures.is_empty(), label + ": " + "; ".join(places.failures))
				if water == &"coast": _check_coastal_estate(plan, label)
				if seed_index == 4 and enclosure == &"hedge" and water == &"coast":
					_coastal_mill_controls(plan)
				if seed_index == 0 and enclosure == &"hedge" and water == &"none" and failures.is_empty():
					var fresh := VillageLotPlanner.plan(_spec(seed_index, enclosure, water))
					_expect(var_to_bytes(BuildingCodec.encode(plan)) == var_to_bytes(BuildingCodec.encode(fresh)),
						"plan_measured differs from ordinary fresh native generation")
				cases += 1
				if failures.size() > before:
					DirAccess.make_dir_recursive_absolute("res://artifacts/village_enclosure_full")
					var path := "res://artifacts/village_enclosure_full/%s_%s_%d.bin" % [enclosure, water, seed_index]
					FileAccess.open(path, FileAccess.WRITE).store_var(BuildingCodec.encode(plan))
				print("ENCLOSURE FULL DONE ", label, " buildings=", plan.buildings.size(),
					" site=", plan.site.size, " density=", scale.stats.get("density", 0), " failures=", failures.size())
	var wanted := count * 3 * waters.size()
	_expect(cases == wanted, "full matrix slice incomplete: %d/%d cases" % [cases, wanted])
	for failure in failures: print("FAIL ", failure)
	print("VILLAGE_ENCLOSURE_FULL: %d checks, %d cases, %d failures" % [checks, cases, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _spec(seed_index: int, enclosure: StringName, water: StringName) -> VillageSpec:
	var spec := VillageSpec.new(18000 + seed_index)
	# A complete small garrison earns native houses, shrine, smithy, tavern,
	# bakery/mill and manor, while making all three enclosures valid inputs.
	spec.population = 50
	spec.purpose = &"garrison"
	spec.culture = &"english"
	spec.wealth = 0.4
	spec.enclosure = enclosure
	spec.water = water
	spec.generate(spec.seed)
	return spec


## The coast may share the plan with a mill race. The one continuous sea edge
## must leave every complete native building dry, including the private estate.
func _check_coastal_estate(plan: VillagePlan, label: String) -> void:
	var coasts: Array[Dictionary] = []
	for water in plan.water:
		if water["kind"] == &"coast": coasts.append(water)
	_expect(plan.spec.form == &"gate" and coasts.size() == 1,
		label + " lost its gate form or continuous coast")
	var manors := plan.buildings_of_kind(&"castle")
	_expect(manors.size() == 1, label + " coast omitted the unique native manor")
	if manors.size() != 1 or coasts.size() != 1: return
	var place := VillagePlaceCheck.new()
	place._check_manor(plan)
	_expect(place.failures.is_empty() and VillageArchetypeSuite._manor_at_lane_head(plan),
		label + " coastal manor has no valid private-lane arrival: " + "; ".join(place.failures))
	var manor: Dictionary = plan.buildings[manors[0]]
	var lot: Dictionary = plan.lots[int(manor["lot"])]
	var road: Dictionary = plan.roads[int(lot["road"])]
	_expect(road["class"] == &"lane" \
		and Poly.polyline_length(road["points"]) <= VillageRoadCheck.DEAD_END_MAX + 0.001,
		label + " coastal manor's access exceeds the legal lane length")
	for index in plan.buildings.size():
		var building: Dictionary = plan.buildings[index]
		var bounds := VillageMeasure.bounds_poly(building)
		var on_site := true
		for point in bounds:
			on_site = on_site and plan.site.grow(0.01).has_point(point)
		_expect(on_site, label + " coastal native architecture leaves the site")
		_expect(_coastal_building_is_dry(plan, index, coasts[0]["poly"]),
			label + " coastal native architecture stands in the sea")
	var lots := VillageLotCheck.new()
	lots._check_fire_gap(plan)
	_expect(lots.failures.is_empty(), label + " coastal lots: " + "; ".join(lots.failures))


## A working bank-side mill may overhang the water with eaves. Its complete
## measured walls stay dry; an ordinary bakery gets no such exception.
func _coastal_building_is_dry(plan: VillagePlan, index: int, sea: PackedVector2Array) -> bool:
	var building: Dictionary = plan.buildings[index]
	var envelope := VillageMeasure.bounds_poly(building)
	var request: BuildingRequest = building["request"]
	if request.kind == &"shop" and request.purpose == &"bakery" \
			and building["placement"].has("mill_wall_rect"):
		var races := 0
		for water in plan.water:
			if water["kind"] != &"race" or int(water.get("host", -1)) != index: continue
			var source := int(water.get("source", -1))
			if source >= 0 and source < plan.water.size() and plan.water[source]["kind"] == &"coast":
				races += 1
		var wheels := 0
		for prop in plan.props:
			if prop["key"] == "mill_wheel" and int(prop.get("host", -1)) == index and bool(prop.get("built", false)):
				wheels += 1
		if races == 1 and wheels == 1:
			envelope = VillageWaterPlan.mill_walls(building["placement"], building["transform"])
	return VillageLotPlanner.overlap_area(envelope, sea) <= 0.01


func _coastal_mill_controls(plan: VillagePlan) -> void:
	var sea: PackedVector2Array = plan.water[0]["poly"]
	for index in plan.buildings.size():
		var building: Dictionary = plan.buildings[index]
		var request: BuildingRequest = building["request"]
		if request.kind != &"shop" or request.purpose != &"bakery": continue
		_expect(VillageLotPlanner.overlap_area(VillageMeasure.bounds_poly(building), sea) > 0.01 \
			and _coastal_building_is_dry(plan, index, sea), "native coastal mill fixture lost its dry-wall/eaves distinction")
		var original: Transform3D = building["transform"]
		var moved := original
		var inward := (VillageMeasure.centre(sea) - VillageMeasure.centre(
			VillageWaterPlan.mill_walls(building["placement"], original))).normalized() * 2.0
		moved.origin += Vector3(inward.x, 0.0, inward.y)
		building["transform"] = moved
		_expect(not _coastal_building_is_dry(plan, index, sea), "actual mill walls translated into the sea escaped")
		building["transform"] = original
		for water in plan.water:
			if water["kind"] != &"race" or int(water.get("host", -1)) != index: continue
			water["host"] = -1
			_expect(not _coastal_building_is_dry(plan, index, sea), "a bakery without its working race received the mill exception")
			water["host"] = index


## This real programme found a pond bay that cleared every road, yet put its
## mill beyond a 14 m race. Preserve the native architecture and prior layout.
func _pond_repair_controls(measured: Array[Dictionary]) -> void:
	var spec := _spec(3, &"hedge", &"pond")
	var jobs: Array[Dictionary] = measured.duplicate(true)
	var mill: Dictionary = {}
	for job in jobs:
		job["siting"] = VillageLotPlanner.siting_of(job["request"], job["class"])
		if job["request"].purpose == &"bakery": mill = job
	_expect(not mill.is_empty(), "pond repair fixture lost its native bakery")
	if mill.is_empty(): return
	var prior: Array[Dictionary] = []
	for job in jobs:
		if VillageLotPlanner._order_of(job) < VillageLotPlanner._order_of(mill) \
				or (VillageLotPlanner._order_of(job) == VillageLotPlanner._order_of(mill) \
				and int(job["order"]) < int(mill["order"])):
			prior.append(job)
	var base := VillageSitePlanner.plan(spec)
	var minimum := maxf(VillageLotPlanner._landmark_site_depth(base, jobs),
		VillageLotPlanner._manor_site_depth(base, jobs))
	var plan := VillageSitePlanner.plan(spec, 12, 3.0, minimum)
	plan = VillageSitePlanner.plan(spec, 12, 3.0,
		maxf(minimum, VillageLotPlanner._manor_site_depth(plan, jobs)))
	_expect(VillageLotPlanner.cut_measured(plan, prior) == 0, "pond fixture omitted prior civic/trade buildings")
	var reserved: Array = []
	for lot in plan.lots:
		if lot["class"] in [&"church", &"manor"]: reserved.append(int(lot["road"]))
	var allowed := VillageLotPlanner._open_roads(plan, reserved)
	var ctx := VillageLotPlanner._context(plan)
	var original: PackedVector2Array = plan.water[0]["poly"]
	var size := Poly.bounding_rect(original).size
	mill["near_point"] = Poly.bounding_rect(original).get_center()
	var before := var_to_bytes(BuildingCodec.encode(plan))
	_expect(VillageLotPlanner._place_on_road(plan, ctx, mill, allowed) < 0.0,
		"pond fixture no longer reproduces the unreachable mill bank")
	_expect(not VillageLotPlanner._place_pond_mill(plan, ctx, mill, []),
		"pond repair used a road outside its caller's allowed list")
	_expect(var_to_bytes(BuildingCodec.encode(plan)) == before, "failed pond placement changed the plan")
	# Every possible wheel wall is blocked. Candidate pond moves must roll back.
	var blocked := mill.duplicate(true)
	blocked["placement"]["mill_openings"] = []
	for normal in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		blocked["placement"]["mill_openings"].append({"pos": Vector2.ZERO,
			"normal": normal, "width": 10000.0, "sill": 0.0})
	_expect(not VillageLotPlanner._place_pond_mill(plan, ctx, blocked, allowed),
		"pond repair put a wheel across blocked facade openings")
	_expect(var_to_bytes(BuildingCodec.encode(plan)) == before, "rejected candidate pond moves were not rolled back")
	plan.water.append({"kind": &"race", "source": 0, "poly": original})
	var attached := var_to_bytes(BuildingCodec.encode(plan))
	_expect(not VillageLotPlanner._place_pond_mill(plan, ctx, mill, allowed),
		"pond repair moved an existing mill's water source")
	_expect(var_to_bytes(BuildingCodec.encode(plan)) == attached, "attached race changed during refused repair")
	plan.water.pop_back()
	var previous := _prior_layout_bytes(plan, plan.buildings.size())
	var count := plan.buildings.size()
	_expect(VillageLotPlanner._place_pond_mill(plan, ctx, mill, allowed), "measured pond repair found no real mill site")
	_expect(_prior_layout_bytes(plan, count) == previous, "pond repair moved prior buildings, lots, roads or reservations")
	_expect(plan.buildings.size() == count + 1 and plan.buildings.back()["request"].to_json() == mill["request"].to_json(),
		"pond repair changed the native mill request")
	var pond: PackedVector2Array = plan.water[0]["poly"]
	_expect(is_equal_approx(pond[0].distance_to(pond[1]), size.x) \
		and is_equal_approx(pond[1].distance_to(pond[2]), size.y), "pond repair changed the pond dimensions")
	var common := VillageMeasure.common_centre(plan)
	_expect((VillageMeasure.centre(original) - common).dot(VillageMeasure.centre(pond) - common) > 0,
		"pond repair moved the pond across the common")
	var race: Dictionary = plan.water.back()
	_expect(race["kind"] == &"race" and int(race["source"]) == 0 \
		and VillageMeasure.point_to_poly(race["wheel"], pond) <= 14.01,
		"pond repair bypassed the short race or changed the source index")
	# The complete matrix separately checks the dressed wheel and race.


func _prior_layout_bytes(plan: VillagePlan, count: int) -> PackedByteArray:
	return var_to_bytes(BuildingCodec.encode({"buildings": plan.buildings.slice(0, count),
		"lots": plan.lots.slice(0, count), "roads": plan.roads, "commons": plan.commons,
		"landmark": plan.landmark_site, "fields": plan.fields}))


func _edge_controls() -> void:
	var spec := VillageSpec.new(18)
	spec.enclosure = &"hedge"
	var plan := VillagePlan.new(spec)
	plan.site = Rect2(-50, -50, 100, 100)
	plan.enclosure = Poly.from_rect(plan.site.grow(-5))
	var check := VillageDressCheck.new()
	check._check_edge(plan)
	_expect(not check.failures.is_empty(), "missing real hedge escaped edge check")
	for i in range(0, 90, 4):
		for point in [Vector2(-45 + i, -45), Vector2(45, -45 + i),
				Vector2(45 - i, 45), Vector2(-45, 45 - i)]:
			plan.plants.append({"pos": point, "key": "Wild_Bush_Common"})
	check.failures.clear()
	check._check_edge(plan)
	_expect(check.failures.is_empty(), "continuous actual hedge rejected")
	for key in ["unknown_hedge_model", "Wild_Grass_Common_Short"]:
		for plant in plan.plants: plant["key"] = key
		check.failures.clear()
		check._check_edge(plan)
		_expect(not check.failures.is_empty(), key + " falsely supplied visible hedge coverage")
	for plant in plan.plants: plant["key"] = "Wild_Bush_Common"
	check.failures.clear()
	plan.fields.append({"poly": Poly.from_rect(Rect2(-5,-5,10,10)), "kind": &"pasture"})
	check._check_fields(plan)
	_expect(not check.failures.is_empty(), "pasture inside enclosure escaped")
	plan.fields[0]["poly"] = Poly.from_rect(Rect2(-70,-10,10,20))
	check.failures.clear()
	check._check_fields(plan)
	_expect(check.failures.is_empty(), "pasture outside enclosure rejected")
	# A far-side wood must stand on land, not merely outside the lot hull.
	var context := VillageDresser._context(plan)
	for kind in [&"pond", &"stream", &"river", &"coast", &"race"]:
		plan.water.assign([{"kind": kind, "poly": Poly.from_rect(Rect2(-8,-8,16,16))}])
		_expect(not VillageDresser._plant_is_clear(plan, context, Vector2.ZERO, 0.4, 2.0),
			"tree rooted in " + String(kind) + " accepted")
		_expect(VillageDresser._plant_is_clear(plan, context, Vector2(10,0), 0.4, 2.0),
			"tree on dry " + String(kind) + " bank rejected")
	plan.lots.assign([{"poly": Poly.from_rect(Rect2(-15,-15,30,30))}])
	var derived := VillageEnclosurePlan.build(plan)
	plan.enclosure = derived["edge"]
	var wood: Vector2 = derived["wood"]
	plan.plants.assign([{"pos": wood, "key": "Wild_CommonTree_1", "canopy": 2.0, "zone": &"wood"}])
	plan.water.assign([{"kind": &"pond", "poly": Poly.from_rect(Rect2(wood - Vector2(4,4), Vector2(8,8)))}])
	var dry_wood: Vector2 = VillageEnclosurePlan.build(plan)["wood"]
	_expect(not Poly.contains_point(plan.water[0]["poly"], dry_wood), "wood reservation remains underwater")
	check.failures.clear()
	check._check_wood(plan)
	_expect(not check.failures.is_empty(), "underwater far-side wood escaped dress check")
	plan.water.clear()
	check.failures.clear()
	check._check_wood(plan)
	_expect(check.failures.is_empty(), "dry far-side wood rejected")


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("ENCLOSURE FULL FAIL ", message)
