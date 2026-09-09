extends RefCounted
## Exercise measured placement, actual assembled meshes, and mutations which
## would leave models in door approaches or in front of glazing.

static func run() -> SuiteResult:
	var res := SuiteResult.new("house exterior")
	for style in [&"cottage", &"farmhouse", &"townhouse", &"longhall", &"witch_hut"]:
		for trade in [&"none", &"farmer", &"smith", &"alchemist", &"innkeeper"]:
			for rotated in [false, true]:
				var s := HouseSpec.new()
				s.style = style
				s.trade = trade
				s.width = 13.0 if rotated else 9.0
				s.length = 9.0 if rotated else 13.0
				s.storeys = 2 if style == &"townhouse" else 1
				var plan := HouseGenerator.generate(s, 4413, false)
				var who := "%s/%s rotated=%s" % [style, trade, rotated]
				_expect(res, not plan.exterior.is_empty(), who + " no exterior dressing")
				for error in HouseExterior.check(plan):
					res.fail(who + ": " + error)
				var before := var_to_str(plan.exterior)
				HouseExterior.dress(plan)
				_expect(res, before == var_to_str(plan.exterior), who + " nondeterministic dressing")
				_check_assembly(res, plan, who)
				s.exterior_props = false
				var disabled := HouseGenerator.generate(s, 4413, false)
				_expect(res, disabled.exterior.is_empty(), who + " ignores exterior_props=false")
				var root := Node3D.new()
				HouseAssembler.dress_exterior(root, disabled)
				_expect(res, root.get_node("Exterior").get_child_count() == 0, who + " disabled props assembled")
				root.free()
	_mutations(res)
	_sill(res)
	_api_bounds(res)
	return res


static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)


static func _check_assembly(res: SuiteResult, plan: HousePlan, who: String) -> void:
	var root := Node3D.new()
	HouseAssembler.dress_exterior(root, plan)
	var exterior := root.get_node("Exterior")
	var expected_lights: Array[Vector3] = []
	for p in plan.exterior:
		var node := exterior.get_node_or_null(NodePath(p["id"])) as Node3D
		_expect(res, node != null, who + " missing model " + p["key"])
		if node == null:
			continue
		var actual := SceneBounds.of_node(node)
		var recorded: AABB = p["bounds"]
		_expect(res, actual.position.distance_to(recorded.position) < 0.02 and actual.size.distance_to(recorded.size) < 0.02,
			who + " model differs from recorded bounds: " + p["key"])
		if p["mounted"]:
			_expect(res, actual.position.y > 1.0, who + " low wall light")
		else:
			_expect(res, absf(actual.position.y) < 0.02, who + " floating/sunken prop " + p["key"])
		if PropCatalog.has_tag(p["key"], PropCatalog.LIGHT):
			expected_lights.append(node.position + node.basis * PropCatalog.light_offset(p["key"]))
	var lamps := exterior.find_children("*", "OmniLight3D", true, false)
	_expect(res, lamps.size() == expected_lights.size(), who + " wrong exterior light count")
	for i in mini(lamps.size(), expected_lights.size()):
		_expect(res, (lamps[i] as Node3D).position.distance_to(expected_lights[i]) < 0.01, who + " light detached from lamp")
	root.free()


static func _mutations(res: SuiteResult) -> void:
	var s := HouseSpec.new()
	s.width = 10.0
	s.length = 13.0
	var plan := HouseGenerator.generate(s, 4413, false)
	var p := HouseExterior._candidate(plan, "Barrel", 1.0, 0, 0.2, "test")
	var door: Dictionary = plan.doors[plan.entrance()]
	var at: Vector2 = door["pos"] + door["normal"] * 1.2
	p["pos"] = Vector3(at.x, 0, at.y)
	_expect(res, HouseExterior.conflict(plan, p, []).contains("door"), "door-blocking mutation escaped")
	var win: Dictionary = plan.windows[0]
	var outside: Vector2 = win["pos"] + win["normal"] * 0.85
	p["pos"] = Vector3(outside.x, float(win["sill"]), outside.y)
	# Match the facade so the host test does not mask the glazing test.
	for i in 4:
		if HouseGeometry.exterior_runs(s)[i]["normal"] == win["normal"]:
			p["host"] = i
	_expect(res, HouseExterior.conflict(plan, p, []).contains("glazing"), "window-blocking mutation escaped")
	_expect(res, not plan.exterior.is_empty(), "mutation fixture has no props")
	if not plan.exterior.is_empty():
		p = plan.exterior[0].duplicate(true)
		_expect(res, HouseExterior.conflict(plan, p, [p]).contains("overlaps"), "overlap mutation escaped")
		p["host"] = 99
		_expect(res, HouseExterior.conflict(plan, p, []).contains("host"), "invalid facade host escaped")
		p["host"] = plan.exterior[0]["host"]
		p["bounds"] = AABB()
		plan.exterior[0] = p
		_expect(res, not HouseExterior.check(plan).is_empty(), "stale bounds mutation escaped")


static func _sill(res: SuiteResult) -> void:
	var s := HouseSpec.new()
	s.style = &"cottage"
	s.width = 7.0
	s.length = 9.0
	s.height = 2.5
	var plan := HouseGenerator.generate(s, 4412, false)
	var mesh := HouseBuilder.new().build(plan)
	var d: Dictionary = plan.doors[plan.entrance()]
	var at: Vector2 = d["pos"]
	var normal: Vector2 = d["normal"]
	for surface in [1, 3]:
		for y in [s.plinth_height, s.plinth_height + HouseGeometry.SILL_BEAM_H * 0.5, 1.1]:
			var start := Vector3(at.x + normal.x, y, at.y + normal.y)
			var end := Vector3(at.x - normal.x * 0.1, y, at.y - normal.y * 0.1)
			var hits := 0
			for t in HouseQASuite._triangles(mesh, surface):
				if Geometry3D.segment_intersects_triangle(start, end, t[0], t[1], t[2]) != null:
					hits += 1
			_expect(res, hits == 0, "cottage 4412 trim/plinth crosses entrance at %.3f surface %d" % [y, surface])


static func _api_bounds(res: SuiteResult) -> void:
	var s := HouseSpec.new()
	s.width = 10
	s.length = 13
	s.style = &"farmhouse"
	var plan := HouseGenerator.generate(s, 4413, false)
	var made := GeneratedBuilding.new()
	made.request = BuildingRequest.house(4413)
	made.spec = s
	made.plan = plan
	var bounds: AABB = BigGlade.placement(made)["bounds"]
	for p in plan.exterior:
		_expect(res, bounds.grow(0.001).encloses(HouseExterior.bounds_of(p)), "public placement crops exterior prop " + p["key"])
	var exported := BuildingDocument._plan_dict(plan)
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(exported))
	_expect(res, roundtrip["exterior"].size() == plan.exterior.size(), "document lost exterior records")
	_expect(res, roundtrip["exterior"][0]["bounds"].size() == 6, "document bounds are not numeric AABB data")
	s.exterior_props = false
	_expect(res, BigGlade.placement(made)["bounds"] == HouseBuilder.new().build(plan).get_aabb(), "disabled props still expand public bounds")
