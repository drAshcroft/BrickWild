class_name WorldCourtyardSuite
extends RefCounted
## WLD-001: the three courtyard-house sub-kinds, their negative CourtCheck
## fixtures, and the canonical scale/seed matrix.

const SCALES: Array[float] = [0.7, 1.0, 1.4, 1.9]
const KINDS: Array[StringName] = [&"domus", &"riad", &"palazzo"]


static func run() -> SuiteResult:
	return _run_kinds(KINDS)


static func run_kind(kind: StringName) -> SuiteResult:
	return _run_kinds([kind])


static func run_kind_scale(kind: StringName, scale: float) -> SuiteResult:
	return _run_kinds_at_scale([kind], scale)


static func _run_kinds(kinds: Array[StringName]) -> SuiteResult:
	return _run_kinds_at_scale(kinds, -1.0)


static func _run_kinds_at_scale(kinds: Array[StringName], selected_scale: float) -> SuiteResult:
	var res := SuiteResult.new("world courtyard")
	_fixtures(res)
	if &"domus" in kinds:
		_walk_pin_domus(res)
	for kind in kinds:
		for scale in SCALES:
			if selected_scale >= 0.0 and absf(scale - selected_scale) > 0.001:
				continue
			for seed_offset in range(3):
				var request := _request(kind, scale, 8400 + seed_offset)
				print("wld001 case %s scale=%.2f seed=%d" % [String(kind), scale, seed_offset])
				var case_started := Time.get_ticks_msec()
				var case_failures := res.failures.size()
				var building: GeneratedBuilding = BrickWild.generate(request)
				res.checked += 1
				var who := "%s scale=%.2f seed=%d" % [String(kind), scale, seed_offset]
				if building == null or not building.is_ok():
					var errors := str(building.errors) if building != null else "null"
					res.fail("%s: generation failed: %s" % [who, errors])
					print("wld001 FAIL %s (generation)" % who)
					continue
				var plan: HousePlan = building.plan
				var builder := HouseBuilder.new()
				var mesh := builder.build(plan)
				if mesh == null:
					res.fail("%s: no emitted mesh" % who)
				for f in HouseQA.new().check(plan, builder)["failures"]:
					res.fail("%s: %s" % [who, str(f)])
				for f2 in CourtCheck.new().check(plan, {"builder": builder})["failures"]:
					res.fail("%s: %s" % [who, str(f2)])
				_assert_identity(res, plan, kind, who)
				print("wld001 %s %s (%.2fs)" % [
					"PASS" if res.failures.size() == case_failures else "FAIL",
					who, (Time.get_ticks_msec() - case_started) / 1000.0])
	return res


## The Merchant's Domus the walker pinned (review 1a10f8e7682668f8189), built
## through the public path: its ranges are furnished rooms, nothing hangs
## through the floor, the street door is a door a person walks through, the
## flanks are not blank, the shop fronts are cut, and the glazing the shell
## draws in the roof slot renders as glass rather than as roof tile.
static func _walk_pin_domus(res: SuiteResult) -> void:
	var request := BuildingRequest.from_dict({"kind": "world", "style": "courtyard_house",
		"purpose": "domus", "seed": "1", "width": 20.0, "length": 30.0,
		"height": 6.0, "storeys": 1, "material": "timber"})
	var building: GeneratedBuilding = BrickWild.generate(request)
	res.checked += 1
	if building == null or not building.is_ok():
		res.fail("walk-pin domus: generation failed")
		return
	var plan: HousePlan = building.plan
	var standing := {}
	for f in plan.furniture:
		var room := int(f.get("room", -1))
		var key := String(f.get("key", ""))
		var p: Vector3 = f.get("pos", Vector3.ZERO)
		# standing pieces stand on the floor's TOP (FLOOR_T above the datum)
		if not bool(f.get("mounted", false)) and p.y < HouseGeometry.FLOOR_T + 0.05:
			standing[room] = int(standing.get(room, 0)) + 1
		var host := int(f.get("host", -1))
		if host >= 0:
			res.checked += 1
			if host >= plan.furniture.size() \
					or int(plan.furniture[host].get("room", -2)) != room:
				res.fail("walk-pin domus: %s stands on a host that is not there" % key)
		var bottom: float = p.y + PropCatalog.floor_offset(key) * float(f.get("scale", 1.0))
		res.checked += 1
		if bottom < -0.03:
			res.fail("walk-pin domus: %s hangs %.2f m through the floor" % [key, -bottom])
	for i in range(plan.rooms.size()):
		var kind := plan.kind_of(i)
		if kind == &"gallery":
			continue
		res.checked += 1
		if int(standing.get(i, 0)) < 2:
			res.fail("walk-pin domus: room %d (%s) holds %d standing pieces"
				% [i, String(kind), int(standing.get(i, 0))])
	var programme := 0
	for i in range(plan.rooms.size()):
		if plan.kind_of(i) in [&"dining_room", &"parlour", &"bedroom"]:
			programme += 1
	res.checked += 1
	if programme < 3:
		res.fail("walk-pin domus: only %d ranges have a domestic programme" % programme)
	var street_w := 0.0
	var flank := 0
	for door in plan.doors:
		if bool(door.get("front", false)):
			street_w = float(door.get("width", 0.0))
	for win in plan.windows:
		if String(win.get("role", "")) == "high_side_window":
			flank += 1
	res.checked += 2
	if street_w < 1.4:
		res.fail("walk-pin domus: the street door is %.2f m wide" % street_w)
	if flank < 6:
		res.fail("walk-pin domus: %d high windows relieve the flanks" % flank)
	for f2 in CourtCheck.new().check(plan)["failures"]:
		res.fail("walk-pin domus: %s" % f2)
	var palette: Array = WorldAssembler.house_palette(plan)
	res.checked += 1
	if palette.size() < 3 or palette[2] == null or (palette[2] as Material).next_pass == null:
		res.fail("walk-pin domus: the roof slot has no glazing pass, so windows render as tile")


static func _request(kind: StringName, scale: float, seed: int) -> BuildingRequest:
	var r := BuildingRequest.new()
	r.kind = &"world"
	r.style = &"courtyard_house"
	r.purpose = kind
	r.seed = seed
	# Keep the four canonical scale probes inside the family's published
	# envelope. Large nominal scales ease toward a bound instead of collapsing
	# both upper probes to one clamped rectangle before the planner/emitter is
	# exercised.
	var env: Dictionary = WorldFamilies.envelope(&"courtyard_house")
	match kind:
		&"domus":
			r.width = _bounded_dimension(22.0, scale, env["width"])
			r.length = _bounded_dimension(40.0, scale, env["length"])
			r.height = 6.0
		&"riad":
			r.width = _bounded_dimension(18.0, scale, env["width"])
			r.length = _bounded_dimension(24.0, scale, env["length"])
			r.height = 7.0
		&"palazzo":
			r.width = _bounded_dimension(20.0, scale, env["width"])
			r.length = _bounded_dimension(30.0, scale, env["length"])
			r.height = 18.0
	return r


static func _bounded_dimension(base: float, scale: float, bounds: Dictionary) -> float:
	var lo := float(bounds["min"])
	var hi := float(bounds["max"])
	var nominal := base * scale
	if scale <= 1.0:
		return clampf(nominal, lo, hi)
	# 1.9 is the upper canonical probe. Interpolate the legal upper bound so
	# 1.4 and 1.9 remain meaningful, distinct stress sizes.
	var t := clampf((scale - 1.0) / 0.9, 0.0, 1.0)
	var bounded := lerpf(base, hi, t)
	return clampf(minf(nominal, bounded), lo, hi)


static func _assert_identity(res: SuiteResult, plan: HousePlan,
		kind: StringName, who: String) -> void:
	if plan.world_family != &"courtyard_house" or plan.world_subkind != kind:
		res.fail("%s: family identity was not retained" % who)
	if kind == &"domus" and (not plan.view_through or plan.blind_entry):
		res.fail("%s: domus view_through flag missing" % who)
	if kind == &"riad" and (not plan.blind_entry or plan.view_through):
		res.fail("%s: riad blind_entry flag missing" % who)
	if kind == &"palazzo" and (plan.canal_wall != &"front" or int(plan.spec.storeys) != 3):
		res.fail("%s: palazzo water-gate programme missing" % who)


static func _fixture_plan(kind: StringName, seed: int) -> HousePlan:
	var row := WorldCourtyardGenerator.generate(kind, seed,
		22.0 if kind == &"domus" else (18.0 if kind == &"riad" else 20.0),
		40.0 if kind == &"domus" else (24.0 if kind == &"riad" else 30.0),
		6.0 if kind == &"domus" else (7.0 if kind == &"riad" else 18.0), false)
	return row["plan"]


static func _expect(res: SuiteResult, label: String, report: Dictionary) -> void:
	res.checked += 1
	for failure in report.get("failures", []):
		if String(failure).begins_with(label + ":"):
			return
	res.fail("negative fixture %s did not fail" % label)


static func _fixtures(res: SuiteResult) -> void:
	var sky := _fixture_plan(&"domus", 9101)
	sky.furniture.append({"key": "Barrel", "room": 1, "pos": Vector3.ZERO,
		"rect": Rect2(-0.3, -0.3, 0.6, 0.6), "zone": Rect2(), "host": -1,
		"cat": "barrel", "mounted": false, "world_water": false})
	_expect(res, "sky", CourtCheck.new().check(sky))

	var inward := _fixture_plan(&"domus", 9102)
	for door in inward.doors:
		if String(door.get("role", "")) == "court_entry":
			door["normal"] = -Vector2(door["normal"])
	for win in inward.windows:
		win["normal"] = -Vector2(win["normal"])
	_expect(res, "inward", CourtCheck.new().check(inward))

	var blind := _fixture_plan(&"riad", 9103)
	blind.world_meta["blind_screen"] = Rect2()
	_expect(res, "blind_entry", CourtCheck.new().check(blind))

	var view := _fixture_plan(&"domus", 9104)
	var tablinum := -1
	for i in range(view.rooms.size()):
		if view.rooms[i].get("role", &"") == &"tablinum":
			tablinum = i
			break
	var axis_mid := Vector2(view.world_meta["street_door"]).lerp(
			HouseGeometry.room_floor_rect(view, tablinum).get_center(), 0.5)
	view.furniture.append({"key": "Barrel", "room": 1,
		"pos": Vector3(axis_mid.x, 0.0, axis_mid.y),
		"rect": Rect2(axis_mid - Vector2(0.6, 0.6), Vector2(1.2, 1.2)),
		"zone": Rect2(), "host": -1, "cat": "barrel", "mounted": false})
	_expect(res, "view_through", CourtCheck.new().check(view))

	var ring := _fixture_plan(&"riad", 9105)
	var kept: Array[Dictionary] = []
	for door in ring.doors:
		if String(door.get("role", "")) != "court_entry":
			kept.append(door)
	ring.doors = kept
	_expect(res, "ring", CourtCheck.new().check(ring))

	var water := _fixture_plan(&"domus", 9106)
	water.world_meta["water_pos"] = Vector2(99.0, 99.0)
	water.furniture.clear()
	_expect(res, "water", CourtCheck.new().check(water))

	var proportion := _fixture_plan(&"palazzo", 9107)
	for court in proportion.courts:
		court["rect"] = Rect2(-0.2, -0.2, 0.4, 0.4)
	_expect(res, "proportion", CourtCheck.new().check(proportion))

	var shops := _fixture_plan(&"domus", 9108)
	for door in shops.doors:
		if String(door.get("role", "")) == "taberna":
			door["width"] = 1.0
			break
	_expect(res, "shops", CourtCheck.new().check(shops))
	var shop_door := _fixture_plan(&"domus", 9112)
	var shop_room := -1
	for door in shop_door.doors:
		if String(door.get("role", "")) == "taberna":
			shop_room = int(door.get("a", -1))
			break
	shop_door.doors.append({"a": shop_room, "b": 1, "pos": Vector2.ZERO,
		"normal": Vector2(1, 0), "width": 0.8, "exterior": false,
		"front": false, "role": "shop_back_door"})
	_expect(res, "shops", CourtCheck.new().check(shop_door))
	# the walk-pin shop front: the display window stacked on the door's span
	var stacked := _fixture_plan(&"domus", 9114)
	for door in stacked.doors:
		if String(door.get("role", "")) != "taberna":
			continue
		for win in stacked.windows:
			if int(win.get("room", -1)) == int(door.get("a", -2)) \
					and String(win.get("role", "")) == "taberna_display":
				win["pos"] = door["pos"]
		break
	res.checked += 1
	var stacked_failures: Array = CourtCheck.new().check(stacked)["failures"]
	if not str(stacked_failures).contains("stacked"):
		res.fail("negative fixture shops/stacked did not fail: %s" % [stacked_failures])

	var gate := _fixture_plan(&"palazzo", 9109)
	for door in gate.doors:
		if String(door.get("role", "")) == "water_gate":
			door["sill"] = 1.0
			door.erase("wall")
			break
	_expect(res, "water_gate", CourtCheck.new().check(gate))

	var roof := _fixture_plan(&"domus", 9110)
	var roof_builder := HouseBuilder.new()
	roof_builder.build(roof)
	var unsupported: Array[Dictionary] = []
	for mass in roof_builder.mass_log:
		var mass_name := String(mass.get("name", ""))
		if not mass_name.begins_with("wall_") and not mass_name.begins_with("court_roof_fascia_"):
			unsupported.append(mass)
	roof_builder.mass_log = unsupported
	_expect(res, "roof_support", CourtCheck.new().check(roof, {"builder": roof_builder}))

	var duplicate := _fixture_plan(&"riad", 9111)
	var duplicate_builder := HouseBuilder.new()
	duplicate_builder.build(duplicate)
	for mass in duplicate_builder.mass_log.duplicate():
		if String(mass.get("name", "")).begins_with("roof_court_"):
			duplicate_builder.mass_log.append(mass.duplicate(true))
			break
	_expect(res, "roof_support", CourtCheck.new().check(duplicate, {"builder": duplicate_builder}))

	var seam := _fixture_plan(&"domus", 9113)
	var seam_builder := HouseBuilder.new()
	seam_builder.build(seam)
	for part in seam_builder.component_log:
		if String(part.get("role", "")).begins_with("roof_court_"):
			var points: PackedVector3Array = part["points"]
			points[0] += Vector3(0.3, 0.0, 0.0)
			part["points"] = points
			break
	_expect(res, "roof_support", CourtCheck.new().check(seam, {"builder": seam_builder}))
