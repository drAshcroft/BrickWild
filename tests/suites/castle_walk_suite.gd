class_name CastleWalkSuite
extends RefCounted
## Physical gate -> bailey -> keep threshold -> lord's room checks. The
## deliberately small, unfurnished keep isolates traversal from recipe rates.

static func run() -> SuiteResult:
	var res := SuiteResult.new("castle walk")
	for polygon in [false, true]:
		for concentric in [false, true]:
			var row := _fixture(polygon, concentric)
			var s: CastleSpec = row.spec
			var b: CastleBuilder = row.builder
			var who := "%s %s" % ["polygon" if polygon else "rectangle", "two rings" if concentric else "one ring"]
			var report := CastleQA.lords_walk(s, b)
			_want(res, report.applicable and report.failures.is_empty(), who + ": " + str(report.failures))
			_want(res, int(report.get("rings", 0)) == (2 if concentric else 1), who + ": every ring was counted")
			var gate := CastleGeometry.gatehouse_aabb(s, 1 if concentric else 0)
			# This blocker exists only in the mesh. Neither the mass log nor the
			# HousePlan says it is there, so deriving a clear route would miss it.
			b._kit.box(Vector3(gate.size.x, 2.0, 0.2), Vector3(0, 1.0, gate.get_center().z), CastleBuilder.SURF_STONE)
			var blocked := CastleQA.lords_walk(s, b)
			_want(res, _has(blocked, "gate approach"), who + ": sealed gate/causeway escaped detection")
	# A sealed keep threshold must fail even though the HousePlan has a door.
	var row := _fixture(false, false)
	var b: CastleBuilder = row.builder
	var p: HousePlan = b.interiors[0].plan
	var xf: Transform3D = b.interiors[0].transform
	var d: Dictionary = p.doors[p.entrance()]
	var pos := xf * Vector3(d.pos.x, 1.0, d.pos.y - HouseGeometry.wall_thickness(p.spec) * 0.5)
	b._kit.box(Vector3(float(d.width), 2.0, 0.2), pos, CastleBuilder.SURF_STONE)
	_want(res, _has(CastleQA.lords_walk(row.spec, b), "emitted keep entrance"), "sealed keep door escaped detection")
	# Plan connectivity is a separate leg: physically clear thresholds do not
	# make an upper chamber reachable without its stairs.
	row = _fixture(false, false)
	b = row.builder
	p = b.interiors[0].plan
	p.rooms[0].kind = &"hall"
	p.rooms.append({"kind": &"lords_chamber", "rect": p.rooms[0].rect, "storey": 1})
	p.spec.storeys = 2
	_want(res, _has(CastleQA.lords_walk(row.spec, b), "lord's chamber"), "missing stairs to lord's chamber escaped detection")
	_triangle_projection(res)
	_prop_projection(res)
	_apse_entry(res)
	_corridor_fallback(res)
	_connected_components(res)
	_edwardian_entry(res)
	_surface_mapping(res)
	_opening_logs(res)
	return res


static func _fixture(polygon: bool, concentric: bool) -> Dictionary:
	var s := CastleSpec.new()
	s.width = 44.0
	s.length = 66.0
	s.height = 7.0
	s.tier_override = &"castle"
	s.plan_override = &"polygon" if polygon else &"rect"
	s.sides_override = 6 if polygon else 4
	CastleGenerator.generate(s, 77107)
	s.inner_ward = concentric
	s.ward_gap = 8.0
	s.gatehouse = true
	s.gate_width = 5.0
	s.gate_depth = 3.0
	s.wall_thickness = 0.8
	s.batter = 0.0
	s.tower_size = 1.0
	s.barbican = concentric
	s.corner_towers = false
	s.gate_towers = false
	s.side_towers = 0
	s.battlements = false
	var b := CastleBuilder.new()
	b.spec = s
	b.begin(4)
	for ring in CastleGeometry.rings(s):
		b._build_ring(ring)
	var barbican := CastleGeometry.barbican_aabb(s)
	if barbican.size.x > 0.0:
		b._passage(barbican, minf(barbican.size.x * 0.45, 2.4), barbican.size.y * 0.55)
	for side in [-1.0, 1.0]:
		var link := CastleGeometry.gate_link_aabb(s, side)
		if link.size.z > 0:
			b._box_aabb(link, CastleBuilder.SURF_STONE)
	var hs := HouseSpec.new()
	hs.width = 7.0
	hs.length = 7.0
	hs.height = 3.0
	hs.material = &"stone"
	hs.plinth_height = 0.0
	hs.chimney = false
	hs.porch = false
	hs.exterior_props = false
	var p := HousePlan.new()
	p.spec = hs
	var floor := HouseGeometry.interior_rect(hs)
	p.rooms.append({"kind": &"lords_chamber", "rect": floor, "storey": 0})
	p.doors.append({"a": 0, "b": -1, "pos": Vector2(0, floor.position.y), "normal": Vector2(0, -1), "width": 1.4, "exterior": true, "front": true, "storey": 0})
	var row := CastleBuilder.Interiors.record("keep", p,
		AABB(Vector3(-hs.width * 0.5, 0, 7.0 - hs.length * 0.5), Vector3(hs.width, hs.height, hs.length)))
	CastleBuilder.Interiors.emit(b, row)
	return {"spec": s, "builder": b}


static func _triangle_projection(res: SuiteResult) -> void:
	for variant in ["open", "narrow_open", "roof", "low_lintel", "seal", "decorative_opening"]:
		var grid := WalkGrid.new()
		grid.setup(Rect2(-3, -3, 6, 6), HouseGeometry.NAV_CELL)
		grid.add_floor(Rect2(-3, -3, 6, 6))
		var kit := MeshKit.new(4)
		# SurfaceTool omits empty surfaces. Preserve the castle's material
		# slots with remote trim and overhead roof geometry in this tiny mesh.
		kit.box(Vector3.ONE, Vector3(100, 10, 100), CastleBuilder.SURF_TRIM)
		kit.box(Vector3.ONE, Vector3(100, 12, 100), CastleBuilder.SURF_ROOF)
		var gap := 0.8 if variant == "narrow_open" else 1.3
		var wall_width := (6.0 - gap) * 0.5
		for side in [-1.0, 1.0]:
			kit.box(Vector3(wall_width, 3, 0.4), Vector3(side * (gap + wall_width) * 0.5, 1.5, 0), CastleBuilder.SURF_STONE)
		if variant == "roof":
			kit.box(Vector3(6, 0.2, 6), Vector3(0, 3, 0), CastleBuilder.SURF_ROOF)
		elif variant == "low_lintel":
			kit.box(Vector3(1.3, 0.4, 0.4), Vector3(0, 1.7, 0), CastleBuilder.SURF_STONE)
		elif variant in ["seal", "decorative_opening"]:
			kit.box(Vector3(1.3, 2, 0.1), Vector3(0, 1, 0), CastleBuilder.SURF_OPEN if variant == "decorative_opening" else CastleBuilder.SURF_STONE)
		CastleQA._walk_obstacles(grid, kit.commit())
		grid.build(HouseGeometry.PERSON_RADIUS)
		var reached := grid.flood_from(Vector2(0, -2), grid.cell) and grid.reached(Rect2(-0.1, 1.9, 0.2, 0.2))
		_want(res, reached == (variant in ["open", "narrow_open", "roof", "decorative_opening"]), "physical projection: " + variant)


static func _has(report: Dictionary, fragment: String) -> bool:
	for failure in report.failures:
		if fragment in String(failure):
			return true
	return false


static func _prop_projection(res: SuiteResult) -> void:
	var grid := WalkGrid.new()
	grid.setup(Rect2(-1, -3, 2, 6), HouseGeometry.NAV_CELL)
	grid.add_floor(Rect2(-1, -3, 2, 6))
	var item := PropCatalog.placement("Crate_Wooden", Vector3(100, 0, 100), 0.0, 3.0, &"store")
	# Move the pose while leaving its stored rect far away.
	item.pos = Vector3(0, PropCatalog.floor_offset("Crate_Wooden") * 3.0, 0)
	var items: Array[Dictionary] = [item]
	_want(res, CastleQA._walk_props(grid, items) == 1, "measured ground prop must be an obstacle")
	grid.build(HouseGeometry.PERSON_RADIUS)
	_want(res, not (grid.flood_from(Vector2(0, -2.5), grid.cell) and grid.reached(Rect2(-0.1, 2.3, 0.2, 0.2))), "moved courtyard prop with stale rect escaped detection")
	item.pos.y += 10
	_want(res, CastleQA._walk_props(grid, items) == 0, "prop overhead must not block the bailey floor")


static func _apse_entry(res: SuiteResult) -> void:
	var s := CastleSpec.new()
	s.width = 40
	s.length = 60
	s.height = 10
	s.tier_override = &"castle"
	s.plan_override = &"rect"
	CastleGenerator.generate(s, 77108)
	s.chapel = true
	s.keep = false
	s.inner_ward = false
	s.hall_w = 6
	s.hall_l = 18
	s.hall_height = 6
	var p := CastleGenerator.chapel_plan(s)
	_want(res, p.spec != null, "apse fixture has a chapel HousePlan")
	if p.spec == null:
		return
	var box := CastleGeometry.chapel_aabb(s)
	var b := CastleBuilder.new()
	b.spec = s
	b.begin(4)
	var row := CastleBuilder.Interiors.record("chapel", p, box)
	b._planned_interiors["chapel"] = row
	CastleBuilder.Interiors.emit(b, row)
	b._build_apse()
	var mesh := b.commit()
	var apse := CastleGeometry.apse_aabb(s)
	var r := CastleGeometry.apse_radius(s)
	var origin := Vector3(apse.get_center().x, 0, apse.end.z)
	var from := Vector3(origin.x, 1.2, apse.position.z - 1)
	var to := Vector3(origin.x, 1.2, box.position.z + 1.5)
	_want(res, _ray_hits(mesh, from, to).is_empty(), "apse front and diameter must not seal the chapel entrance")
	var angle := PI + PI * 3.5 / 10.0
	var normal := Vector3(cos(angle), 0, sin(angle))
	var outside := origin + normal * (r * cos(PI / 20.0)) + Vector3.UP * 1.2
	var hits := _ray_hits(mesh, outside + normal * 0.2, outside - normal * 0.8)
	_want(res, hits.size() == 2 and absf(hits[0].distance_to(hits[1]) - 0.6) < 0.01, "apse masonry must have outer and inner faces 0.6m apart: " + str(hits))
	_want(res, b.mass_aabb("apse").is_equal_approx(apse), "apse retains its structural mass bounds")
	# Restore the old diameter seal: the same physical ray must now catch it.
	b._kit.box(Vector3(float(p.doors[p.entrance()].width), 2.0, 0.1), Vector3(origin.x, 1.0, origin.z), CastleBuilder.SURF_STONE)
	_want(res, not _ray_hits(b.commit(), from, to).is_empty(), "restored apse diameter seal escaped the mesh test")


static func _ray_hits(mesh: ArrayMesh, from: Vector3, to: Vector3) -> Array[Vector3]:
	var hits: Array[Vector3] = []
	for surface in mesh.get_surface_count():
		if surface == CastleBuilder.SURF_OPEN:
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0, count - 2, 3):
			var a := vertices[indices[i] if not indices.is_empty() else i]
			var b := vertices[indices[i + 1] if not indices.is_empty() else i + 1]
			var c := vertices[indices[i + 2] if not indices.is_empty() else i + 2]
			var hit: Variant = Geometry3D.segment_intersects_triangle(from, to, a, b, c)
			if hit == null:
				continue
			var duplicate := false
			for previous in hits:
				if previous.distance_to(hit) < 0.001:
					duplicate = true
			if not duplicate:
				hits.append(hit)
	return hits


static func _edwardian_entry(res: SuiteResult) -> void:
	# Canonical narrow gate regression: the fitted gate mass is only 2m wide,
	# and its real passage is 0.8m. A repeated convex-hull endpoint used to
	# over-rasterize its walls and reject this otherwise clear route.
	var spec := CastleSpec.new()
	spec.style = &"edwardian"
	spec.width = 60
	spec.length = 90
	spec.height = 18
	CastleGenerator.generate(spec, 43)
	var builder := CastleBuilder.new()
	var mesh := builder.build(spec)
	var report := CastleQA.lords_walk(spec, builder, mesh)
	_want(res, report.applicable and report.failures.is_empty(), "Edwardian 60x90h18 seed43 route: " + str(report.failures))
	var gate := CastleGeometry.gatehouse_aabb(spec, 0)
	builder._kit.box(Vector3(gate.size.x, 2, 0.1), Vector3(0, 1, gate.get_center().z), CastleBuilder.SURF_STONE)
	_want(res, _has(CastleQA.lords_walk(spec, builder), "gate approach"), "Edwardian gate seal escaped physical traversal")


static func _corridor_fallback(res: SuiteResult) -> void:
	var row := _fixture(false, false)
	var b: CastleBuilder = row.builder
	var clear := CastleQA.lords_walk(row.spec, b)
	_want(res, clear.failures.is_empty() and clear.exterior_grid == "corridor", "clear gate axis should pass in the fine corridor grid")
	# The direct corridor is obstructed, but the open bailey has a real way
	# around either end. A failed shortcut must not become a failed castle.
	b._kit.box(Vector3(8, 2, 0.4), Vector3(0, 1, -10), CastleBuilder.SURF_STONE)
	var detour := CastleQA.lords_walk(row.spec, b)
	_want(res, detour.failures.is_empty() and detour.exterior_grid == "full", "route around corridor obstacle was not found by full-site fallback")
	_want(res, detour.exterior_trials.size() == 2 and not detour.exterior_trials[0].ok and detour.exterior_trials[1].ok, "corridor/full outcomes were not retained in route stats")
	var small: Dictionary = detour.exterior_trials[0]
	var full: Dictionary = detour.exterior_trials[1]
	var offset: Vector2 = (Rect2(small.bounds).position - Rect2(full.bounds).position) / float(full.cell)
	_want(res, offset.is_equal_approx(offset.round()) and float(small.cell) == float(full.cell), "corridor grid does not share full-site world cell alignment")
	_want(res, int(clear.exterior_trials[0].grid_cells) * 4 < int(full.grid_cells), "corridor shortcut did not reduce raster area")
	var samples: Array = full.threshold_samples
	_want(res, not samples.is_empty() and Vector2(samples[0].point).is_equal_approx(Vector2(detour.keep_approach))
		and Vector2(samples[samples.size() - 1].point).is_equal_approx(Vector2(detour.door_inside)),
		"route stats lost exact first/last threshold sample")
	# Extend the obstruction to both walls: neither the corridor nor the full
	# grid may invent a route through a real masonry barrier.
	b._kit.box(Vector3(float(row.spec.width), 2, 0.4), Vector3(0, 1, -10), CastleBuilder.SURF_STONE)
	var sealed := CastleQA.lords_walk(row.spec, b)
	_want(res, _has(sealed, "gate approach") and sealed.exterior_grid == "full" and not sealed.exterior_ok, "sealed full-site detour escaped traversal check")


static func _connected_components(res: SuiteResult) -> void:
	# The independent-shell seed must touch emitted masonry at the logged
	# foot. A roof log spanning down to ground cannot manufacture that seed.
	for mode in ["grounded_shell", "roof_only", "detached_roof"]:
		var spec := CastleSpec.new()
		spec.width = 6
		spec.length = 8
		var b := CastleBuilder.new()
		b.begin(4)
		var anchor := AABB(Vector3(-10, 0, -1), Vector3(2, 3, 2))
		b._log_mass("hall", anchor)
		b._kit.box(anchor.size, anchor.get_center(), CastleBuilder.SURF_STONE)
		var roof_y := 7.0 if mode == "detached_roof" else 4.15
		b._log_mass("chapel", AABB(Vector3(3, 0, -3), Vector3(6, roof_y + 0.15, 6)))
		b.interiors.append({"id": "chapel"})
		if mode != "roof_only":
			for x in [3.3, 8.7]:
				b._kit.box(Vector3(0.6, 4, 6), Vector3(x, 2, 0), CastleBuilder.SURF_STONE)
			for z in [-2.7, 2.7]:
				b._kit.box(Vector3(6, 4, 0.6), Vector3(6, 2, z), CastleBuilder.SURF_STONE)
		b._kit.box(Vector3(6, 0.3, 6), Vector3(6, roof_y, 0), CastleBuilder.SURF_STONE)
		var qa := CastleQA.new()
		qa.spec = spec
		qa.builder = b
		qa._grid = VoxelGrid.new()
		qa._grid.rasterize(b.commit(), CastleBuilder.SURF_OPEN)
		qa._check_connected_mass()
		var expected: bool = mode == "grounded_shell"
		_want(res, qa.failures.is_empty() == expected
			and (float(qa.stats.reachable_fraction) == 1.0) == expected,
			"independent hollow-shell voxel connectivity: %s, failures=%s" % [mode, qa.failures])


static func _surface_mapping(res: SuiteResult) -> void:
	for glazed in [false, true]:
		var hs := HouseSpec.new()
		hs.material = &"stone"
		hs.plinth_height = 0
		hs.width = 6
		hs.length = 8
		hs.height = 3
		hs.exterior_props = false
		var p := HousePlan.new()
		p.spec = hs
		var floor := HouseGeometry.interior_rect(hs)
		p.rooms.append({"kind": &"nave", "rect": floor, "storey": 0})
		p.doors.append({"a": 0, "b": -1, "pos": Vector2(0, floor.position.y), "normal": Vector2(0, -1), "width": 1.4, "exterior": true, "front": true, "storey": 0})
		if glazed:
			p.windows.append({"room": 0, "pos": Vector2(floor.end.x, 0), "normal": Vector2(1, 0), "width": 0.8, "sill": 1.0, "head": 2.0, "storey": 0})
		var b := CastleBuilder.new()
		b.begin(4)
		var row := CastleBuilder.Interiors.record("hall", p, AABB(Vector3(-3, 0, -4), Vector3(6, 3, 8)))
		CastleBuilder.Interiors.emit(b, row)
		var hb: HouseBuilder = row.builder
		var pane_count := _surface_vertices(hb._kit.surface(HouseBuilder.SURF_ROOF))
		_want(res, _surface_vertices(b._kit.surface(CastleBuilder.SURF_OPEN)) == pane_count and (pane_count > 0) == glazed, "house glazing maps to castle opening material; glazed=" + str(glazed))
		_want(res, _surface_vertices(b._kit.surface(CastleBuilder.SURF_STONE)) == _surface_vertices(hb._kit.surface(HouseBuilder.SURF_WALL)) + _surface_vertices(hb._kit.surface(HouseBuilder.SURF_FLOOR)), "windowless floor retains stone material; glazed=" + str(glazed))
		_want(res, _surface_vertices(b._kit.surface(CastleBuilder.SURF_ROOF)) == 0, "interior panes/floors must not occupy castle roof material")
	for tier in [&"house", &"manor"]:
		for index in CastleSweep.COUNT:
			var spec := CastleSweep.spec_at(&"norman", tier, index)
			var b := CastleBuilder.new()
			var mesh := b.build(spec)
			_want(res, mesh.get_surface_count() == 4, "canonical Norman %s case %d retains four castle materials" % [tier, index])


static func _surface_vertices(surface: SurfaceTool) -> int:
	var arrays := surface.commit_to_arrays()
	return 0 if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null else arrays[Mesh.ARRAY_VERTEX].size()


static func _opening_logs(res: SuiteResult) -> void:
	for yaw in [0.0, PI * 0.5, -PI * 0.5, 0.37]:
		var hs := HouseSpec.new()
		hs.material = &"stone"
		hs.plinth_height = 0
		hs.width = 8
		hs.length = 10
		hs.height = 3
		hs.storeys = 2
		hs.exterior_props = false
		var p := HousePlan.new()
		p.spec = hs
		var floor := HouseGeometry.interior_rect(hs)
		for level in 2:
			p.rooms.append({"kind": &"nave", "rect": floor, "storey": level})
		p.doors.append({"a": 0, "b": -1, "pos": Vector2(-1.5, floor.position.y), "normal": Vector2(0, -1), "width": 1.2, "exterior": true, "front": true, "storey": 0})
		p.windows.append({"room": 0, "pos": Vector2(1.3, floor.position.y), "normal": Vector2(0, -1), "width": 1.0, "sill": 0.9, "head": 2.0, "storey": 0})
		p.windows.append({"room": 1, "pos": Vector2(floor.end.x, 1), "normal": Vector2(1, 0), "width": 0.9, "sill": 0.9, "head": 2.0, "storey": 1})
		# An invalid record the shell cannot emit must never become a nominal
		# castle window log. The plan checks catch it separately.
		p.windows.append({"room": 0, "pos": Vector2(100, 100), "normal": Vector2(1, 0), "width": 0.9, "sill": 0.9, "head": 2.0, "storey": 0})
		var b := CastleBuilder.new()
		b.begin(4)
		var row := CastleBuilder.Interiors.record("yard_test", p,
			AABB(Vector3(12, 2, -4), Vector3(8, 6, 10)), yaw)
		CastleBuilder.Interiors.emit(b, row)
		var child: Array[Dictionary] = []
		for part in row.builder.part_log:
			if part.has("opening_kind"):
				child.append(part)
		_want(res, child.size() == 3 and b.part_log.size() == 3,
			"only three emitted openings are forwarded, yaw=" + str(yaw))
		var windows := 0
		var doors := 0
		for imported in b.part_log:
			windows += 1 if imported.kind == "window" else 0
			doors += 1 if imported.kind == "door" else 0
		_want(res, windows == 2 and doors == 1, "door counted as a castle window, yaw=" + str(yaw))
		# Bind world records to the plan as well as the child emitter: wrong
		# local facade normals must not survive a self-consistent copy test.
		for opening in [p.windows[0], p.windows[1], p.doors[0]]:
			var normal: Vector2 = opening.normal
			var local_position: Vector2 = Vector2(opening.pos) + normal * HouseGeometry.wall_thickness(hs) * 0.5
			var is_window: bool = opening.has("sill")
			var low := float(opening.sill) if is_window else 0.0
			var high := float(opening.head) if is_window else HouseGeometry.DOOR_H
			var y := HousePlan.record_storey(opening) * hs.height + (low + high) * 0.5
			var xf: Transform3D = row.transform
			var expected_position := xf * Vector3(local_position.x, y, local_position.y)
			var expected_facing := (xf.basis * Vector3(normal.x, 0, normal.y)).normalized()
			var found := false
			for imported in b.part_log:
				if imported.kind != ("window" if is_window else "door"):
					continue
				if Vector3(imported.pos).is_equal_approx(expected_position) and Vector3(imported.facing).is_equal_approx(expected_facing):
					found = Vector3(imported.size).is_equal_approx(Vector3(float(opening.width), high - low, 0))
			_want(res, found, "world opening does not match its plan facade/storey, yaw=" + str(yaw))
		for index in mini(child.size(), b.part_log.size()):
			var local: Dictionary = child[index]
			var imported: Dictionary = b.part_log[index]
			var xf: Transform3D = row.transform
			var facing := (xf.basis * Vector3(local.facing)).normalized()
			_want(res, Vector3(imported.pos).is_equal_approx(xf * Vector3(local.pos))
				and Vector3(imported.facing).is_equal_approx(facing)
				and absf(wrapf(float(imported.rot_y) - atan2(facing.x, facing.z), -PI, PI)) < 0.0001
				and Vector3(imported.size).is_equal_approx(Vector3(local.size)),
				"opening pose/size transform differs from emitted shell, yaw=%s index=%d" % [yaw, index])
			_want(res, local.kind == "window" and not local.has("planned_opening")
				and imported.kind == local.opening_kind and imported.opening_kind == local.opening_kind
				and imported.tag == "yard_test" and imported.planned_opening == true,
				"opening metadata lost identity or changed the child log, yaw=%s index=%d" % [yaw, index])
		if not child.is_empty() and not b.part_log.is_empty():
			var saved: Vector3 = child[0].pos
			b.part_log[0].pos += Vector3.ONE * 100
			_want(res, Vector3(child[0].pos).is_equal_approx(saved), "castle opening mutation leaked into retained HouseBuilder log")


static func _want(res: SuiteResult, condition: bool, message: String) -> void:
	res.checked += 1
	if not condition:
		res.fail(message)
