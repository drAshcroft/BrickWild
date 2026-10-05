extends RefCounted
## Exercise measured placement, actual assembled meshes, and mutations which
## would leave models in door approaches or in front of glazing.

static func run() -> SuiteResult:
	var res := SuiteResult.new("house exterior")
	# Every style the table publishes, not the five that existed when this suite
	# was written: a style that is absent from this list is a style whose
	# dressing and yard are never measured, and it passes by saying nothing.
	for style in HouseSweep.styles():
		for trade in [&"none", &"farmer", &"smith", &"alchemist", &"innkeeper"]:
			for rotated in [false, true]:
				print("    exterior %s/%s rotated=%s" % [style, trade, rotated])
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
	_yard(res)
	_yard_mutations(res)
	_mutations(res)
	_head_clearance_and_omissions(res)
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


## The yard (EVAL-B06): every style and trade, both orientations. The four
## HouseYardCheck rules pass, the plan is deterministic, the assembler makes
## exactly the planned props at the measured bounds, the builder emits exactly
## the planned parts as logged "yard" components, and exterior_props=false
## leaves the bare shell, byte for byte.
static func _yard(res: SuiteResult) -> void:
	var with_pieces := 0
	for style in HouseSweep.styles():
		for trade in [&"none", &"farmer", &"smith", &"alchemist", &"innkeeper", &"scholar"]:
			for rotated in [false, true]:
				print("    yard %s/%s rotated=%s" % [style, trade, rotated])
				var s := HouseSpec.new()
				s.style = style
				s.trade = trade
				s.width = 13.0 if rotated else 9.0
				s.length = 9.0 if rotated else 13.0
				s.storeys = 2 if style == &"townhouse" else 1
				var plan := HouseGenerator.generate(s, 4413, false)
				var who := "yard %s/%s rotated=%s" % [style, trade, rotated]
				var path_parts := 0
				for piece in plan.yard_pieces:
					if piece["kind"] == "path":
						path_parts += piece["parts"].size()
				_expect(res, not plan.yard.is_empty() and path_parts > 0,
					who + " has no procedural approach or porch pail")
				var builder := HouseBuilder.new()
				builder.build(plan, true)
				for error in HouseYardCheck.check(plan, builder):
					res.fail(who + ": " + error)
				if not plan.yard_pieces.is_empty():
					with_pieces += 1
				var before := var_to_str([plan.yard, plan.yard_pieces])
				HouseYard.plan(plan)
				_expect(res, before == var_to_str([plan.yard, plan.yard_pieces]), who + " nondeterministic")
				_check_yard_assembly(res, plan, who)
				var env := HouseGeometry.yard_rect(plan)
				var apron := HouseYard.apron(s)
				_expect(res, apron >= 2.0 and apron <= 3.0, who + " apron outside 2 to 3 m")
				_expect(res, env.size.x >= s.width + 2.0 * apron - 0.01, who + " envelope narrower than the apron")
				for piece in plan.yard_pieces:
					_expect(res, HouseGeometry.exterior_bounds(plan).grow(0.001).encloses(
						AABB(Vector3(piece["rect"].position.x, 0, piece["rect"].position.y),
						Vector3(piece["rect"].size.x, 0.5, piece["rect"].size.y))),
						who + " exterior_bounds does not contain " + piece["id"])
	_expect(res, with_pieces >= 20, "only %d houses carry a built yard piece" % with_pieces)
	# the switch: planned with props off, or toggled off after planning, the
	# shell is the same triangles as a house that never had a yard
	var s2 := HouseSpec.new()
	s2.style = &"cottage"
	s2.width = 9.0
	s2.length = 12.0
	var dressed := HouseGenerator.generate(s2, 4412, false)
	_expect(res, not dressed.yard_pieces.is_empty(), "cottage 4412 has no built yard piece to switch off")
	var with_yard := HouseBuilder.new().build(dressed, true)
	s2.exterior_props = false
	var bare_plan := HouseGenerator.generate(s2, 4412, false)
	_expect(res, bare_plan.yard.is_empty() and bare_plan.yard_pieces.is_empty(), "exterior_props=false still plans a yard")
	var bare := HouseBuilder.new().build(bare_plan, true)
	var toggled := HouseBuilder.new().build(dressed, true)  # same plan, flag now off
	_expect(res, with_yard.get_aabb() != bare.get_aabb() or with_yard.get_surface_count() != bare.get_surface_count()
		or _vertex_count(with_yard) != _vertex_count(bare), "the yard added no geometry")
	_expect(res, _vertex_count(toggled) == _vertex_count(bare)
		and toggled.get_aabb() == bare.get_aabb(), "exterior_props=false leaves yard geometry in the shell")
	var root := Node3D.new()
	HouseAssembler.dress_exterior(root, dressed)
	_expect(res, root.get_node("Exterior").get_child_count() == 0, "disabled yard props assembled")
	root.free()


static func _vertex_count(mesh: ArrayMesh) -> int:
	var n := 0
	for i in mesh.get_surface_count():
		n += (mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return n


static func _check_yard_assembly(res: SuiteResult, plan: HousePlan, who: String) -> void:
	var root := Node3D.new()
	HouseAssembler.dress_exterior(root, plan)
	var exterior := root.get_node("Exterior")
	for p in plan.yard:
		var node := exterior.get_node_or_null(NodePath(p["id"])) as Node3D
		_expect(res, node != null, who + " missing yard model " + p["key"])
		if node == null:
			continue
		var actual := SceneBounds.of_node(node)
		var recorded: AABB = p["bounds"]
		_expect(res, actual.position.distance_to(recorded.position) < 0.05 and actual.size.distance_to(recorded.size) < 0.05,
			who + " yard model differs from recorded bounds: " + p["key"])
	root.free()


## Negative controls: every rule must be able to fail. Each mutation breaks
## exactly one thing in an otherwise passing yard.
static func _yard_mutations(res: SuiteResult) -> void:
	var make := func() -> HousePlan:
		var s := HouseSpec.new()
		s.style = &"cottage"
		s.width = 9.0
		s.length = 12.0
		return HouseGenerator.generate(s, 4412, false)
	var plan: HousePlan = make.call()
	var builder := HouseBuilder.new()
	builder.build(plan, true)
	_expect(res, HouseYardCheck.check(plan, builder).is_empty(), "yard control house is not clean")
	var door: Dictionary = plan.doors[plan.entrance()]
	var env := HouseGeometry.yard_rect(plan)
	# CLEAR: a barrel in the doorway
	var barrel := HouseYard.make_prop("Barrel", Vector2(door["pos"]) + Vector2(door["normal"]) * 1.2,
		0.0, 1.0, "test", "front")
	plan.yard.append(barrel)
	var errors := HouseYardCheck.clear(plan)
	_expect(res, errors.size() == 1 and errors[0].contains("door approach") and errors[0].contains("key=Barrel"),
		"barrel in the doorway escaped the clear rule: %s" % [errors])
	_expect(res, "door approach" in HouseExterior.facade_clear(plan, HouseExterior.bounds_of(barrel)),
		"the yard and the facade do not share one clearance rule")
	plan.yard.pop_back()
	# CLEAR: a tall prop in front of a window
	var win: Dictionary = plan.windows[0]
	var sill := HouseYard.make_prop("Barrel", Vector2(win["pos"]) + Vector2(win["normal"]) * 0.7,
		0.0, 1.0, "test", "front")
	plan.yard.append(sill)
	errors = HouseYardCheck.clear(plan)
	_expect(res, errors.size() >= 1 and errors[0].contains("glazing"), "barrel under a sill escaped: %s" % [errors])
	plan.yard.pop_back()
	# ENVELOPE: a barrel beyond the apron
	var stray := HouseYard.make_prop("Barrel", env.end + Vector2(1.5, 1.5), 0.0, 1.0, "test", "rear")
	plan.yard.append(stray)
	errors = HouseYardCheck.envelope(plan)
	_expect(res, errors.size() == 1 and errors[0].contains("envelope"), "prop outside the envelope escaped: %s" % [errors])
	_expect(res, HouseYardCheck.clear(plan).is_empty(), "envelope violation was double reported as a clearance one")
	plan.yard.pop_back()
	# KNOWN: a key the catalogue has never measured
	var ghost := barrel.duplicate(true)
	ghost["key"] = "Barrel_That_Is_Not_In_The_Catalogue"
	ghost["pos"] = Vector3(env.position.x + 0.3, 0, env.position.y + 0.3)
	plan.yard.append(ghost)
	errors = HouseYardCheck.known(plan, builder)
	_expect(res, errors.size() == 1 and errors[0].contains("catalogue"), "unknown key escaped: %s" % [errors])
	plan.yard.pop_back()
	# KNOWN: a built piece with no logged component, and a logged one with no piece
	var piece: Dictionary = plan.yard_pieces[0]
	var dropped: Array = piece["parts"].duplicate(true)
	var fake := piece.duplicate(true)
	fake["parts"].append(dropped[0].duplicate(true))
	fake["parts"][fake["parts"].size() - 1]["centre"] += Vector3(0.0, 0.0, 0.5)
	var restore := plan.yard_pieces[0]
	plan.yard_pieces[0] = fake
	errors = HouseYardCheck.known(plan, builder)
	_expect(res, errors.size() >= 1 and errors[0].contains("no logged yard component"),
		"a planned part the builder never emitted escaped: %s" % [errors])
	plan.yard_pieces[0] = restore
	var at := -1
	for i in builder.component_log.size():
		if builder.component_log[i]["host"] == "yard":
			at = i
	_expect(res, at >= 0, "the builder logged no yard component")
	var removed: Dictionary = builder.component_log.pop_at(at)
	errors = HouseYardCheck.known(plan, builder)
	_expect(res, not errors.is_empty(), "a dropped yard component escaped the known rule")
	builder.component_log.insert(at, removed)
	# ACCESS: a fence right across the yard
	var n: Vector2 = door["normal"]
	var across := Vector2(absf(n.y), absf(n.x))
	var ahead := Vector2(door["pos"]) + n * 2.6
	var centre := env.get_center() * across + ahead * n.abs()
	# longer than the walkable ground, so there is no way round its ends
	var size := Vector3(across.x * (env.size.x + 2.0) + n.abs().x * 0.2, 1.2,
		across.y * (env.size.y + 2.0) + n.abs().y * 0.2)
	var wall := {"id": "wall_0", "kind": "fence", "role": "test", "host": "front", "group": "test#0",
		"parts": [{"role": "fence_rail", "surf": "trim", "size": size,
			"centre": Vector3(centre.x, 0.6, centre.y), "basis": Basis()}]}
	wall["rect"] = HouseYard.piece_rect(wall)
	var open_plan_ok := HouseYardCheck.access(plan).is_empty()
	plan.yard_pieces.append(wall)
	errors = HouseYardCheck.access(plan)
	_expect(res, open_plan_ok and errors.size() == 1 and errors[0].contains("cannot be reached"),
		"a fence across the yard escaped the access rule: %s" % [errors])
	plan.yard_pieces.pop_back()
	_expect(res, HouseYardCheck.check(plan, builder).is_empty(), "yard control did not return to clean")


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


static func _head_clearance_and_omissions(res: SuiteResult) -> void:
	var s := HouseSpec.new()
	s.width = 4.0
	s.length = 5.0
	var plan := HouseGenerator.generate(s, 4412, false)
	_expect(res, HouseExterior.access_clear(plan), "small cottage approach is obstructed")
	_expect(res, not plan.exterior_omissions.is_empty(), "small cottage did not explain unfitted recipe items")
	var before := var_to_str(plan.exterior_omissions)
	HouseExterior.dress(plan)
	_expect(res, before == var_to_str(plan.exterior_omissions), "small cottage omissions are not deterministic")
	var door: Dictionary = plan.doors[plan.entrance()]
	# Use the measured wall-lantern body as a synthetic hanging sign: the
	# clearance rule measures its body, and must not special-case its key.
	var sign := HouseExterior._candidate(plan, "Lantern_Wall", 0.45, 0, 0.5, "trade_sign")
	var at: Vector2 = door["pos"] + door["normal"] * 0.65
	var b := HouseExterior.bounds_of(sign)
	sign["pos"] += Vector3(at.x - b.get_center().x, 1.6 - b.position.y, at.y - b.get_center().z)
	sign["id"] = "low_sign"
	sign["bounds"] = HouseExterior.bounds_of(sign)
	plan.exterior = [sign]
	var errors := "\n".join(HouseExterior.check(plan))
	_expect(res, errors.contains("low_sign role=trade_sign host=0") and errors.contains("door"),
		"low sign escaped role/host/ID doorway diagnostics")
	# A high sign clears walking headroom; moving it up must remove the
	# doorway conflict without changing the expected specification.
	sign["pos"].y += 1.0
	_expect(res, not HouseExterior.conflict(plan, sign, []).contains("door"), "high sign falsely blocks approach")


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
	var bounds: AABB = BrickWild.placement(made)["bounds"]
	_expect(res, plan.yard_pieces.size() > 0, "api fixture lost its yard pieces to placement")
	for p in plan.exterior:
		_expect(res, bounds.grow(0.001).encloses(HouseExterior.bounds_of(p)), "public placement crops exterior prop " + p["key"])
	# The yard is reported BESIDE the architectural bounds, not inside them:
	# the envelope, the extent of what stands in it, and the ground it blocks.
	var placed := BrickWild.placement(made)
	_expect(res, placed["yard"] == HouseGeometry.yard_rect(plan), "placement does not report the yard envelope")
	_expect(res, not plan.yard.is_empty() and not plan.yard_pieces.is_empty(), "api fixture has no yard")
	var extent: Rect2 = placed["yard_extent"]
	for p in plan.yard:
		var pb := HouseExterior.bounds_of(p)
		_expect(res, extent.grow(0.001).encloses(Rect2(Vector2(pb.position.x, pb.position.z), Vector2(pb.size.x, pb.size.z))),
			"yard_extent crops yard prop " + p["key"])
	_expect(res, (placed["yard"] as Rect2).grow(0.001).encloses(extent), "yard extent leaves the yard envelope")
	_expect(res, placed["yard_blocks"].size() > 0, "placement reports no yard blocks")
	var held := plan.yard_pieces.duplicate()
	plan.yard_pieces.clear()
	var bare_aabb := HouseBuilder.new().build(plan).get_aabb()
	plan.yard_pieces.assign(held)
	for p in plan.exterior:
		bare_aabb = bare_aabb.merge(HouseExterior.bounds_of(p))
	_expect(res, bounds == bare_aabb, "placement bounds are not the architecture without the yard")
	_expect(res, plan.yard_pieces.size() == held.size(), "placement left the yard pieces unrestored")
	var exported := BuildingDocument._plan_dict(plan)
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(exported))
	_expect(res, roundtrip["exterior"].size() == plan.exterior.size(), "document lost exterior records")
	_expect(res, roundtrip["exterior"][0]["bounds"].size() == 6, "document bounds are not numeric AABB data")
	s.exterior_props = false
	_expect(res, BrickWild.placement(made)["bounds"] == HouseBuilder.new().build(plan).get_aabb(), "disabled props still expand public bounds")
