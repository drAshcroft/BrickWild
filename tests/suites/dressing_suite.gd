class_name DressingSuite
extends RefCounted
## Is there anything in the churches and the castles, and can anybody move
## about in them?
##
## Sweeps the same variants the massing suites do, dresses each one, and hands
## the placements the builder logged to DressingCheck. Nothing here re-derives
## a position: it reads `builder.prop_log`, which is what the assembler will
## instantiate, so a rule that passes here is a rule the rendered building
## obeys.

## The pieces a church is not a church without.
const CHURCH_WANTS := ["altar", "pew", "light"]
## ...and a castle.
const CASTLE_WANTS := ["table", "light"]


## The bounded selector (`dressingquick`): every church style at three sizes,
## and twelve castles -- three styles across all four tiers.
const QUICK_CHURCH_INDICES := [0, 7, 14]
const QUICK_CASTLE_STYLES := [&"norman", &"edwardian", &"bavarian", &"sky"]


static func run() -> SuiteResult:
	var res := SuiteResult.new("dressing")
	_churches(res, false)
	_castles(res, false)
	_negative_control(res)
	return res


static func run_quick() -> SuiteResult:
	var res := SuiteResult.new("dressing (quick)")
	_churches(res, true)
	_church_openings_case(res)
	_gothic_chevet(res)
	_castles(res, true)
	_negative_control(res)
	return res


## A real generated Gothic ambulatory case. The checks use the same catalogue
## measurements as the furnisher, then confirm ChurchAssembler instantiates
## those exact positions through the ordinary production path.
static func _gothic_chevet(res: SuiteResult) -> void:
	var spec := ChurchSpec.new()
	spec.style = &"gothic"
	spec.width = 12.0
	spec.length = 80.0
	spec.height = 24.0
	ChurchGenerator.generate(spec, 5001)
	var label := "Gothic chevet seed %d" % spec.seed
	if not ChurchGeometry.has_gothic_chevet_roof(spec) or spec.radiating_chapels <= 0:
		res.checked += 1
		res.fail("%s no longer generates a Gothic chevet" % label)
		return
	var builder := ChurchBuilder.new()
	builder.build(spec)
	var chapel_rows: Array = []
	for row in builder.prop_log:
		if row.has("chapel_index"):
			chapel_rows.append(row)
	var usable_radius: float = spec.chapel_radius \
		- minf(ChurchBuilder.NAVE_WALL_T, spec.chapel_radius * 0.24) \
		- ChurchFurnisher.CHAPEL_WALL_CLEAR
	for chapel_index in range(spec.radiating_chapels):
		var rows: Array = chapel_rows.filter(func(p): return int(p.chapel_index) == chapel_index)
		_check_chapel_inventory(res, rows, chapel_index, label)
		var angle: float = ChurchGeometry.chapel_angle(spec, chapel_index)
		var center: Vector3 = ChurchGeometry.chapel_center(spec, chapel_index)
		var radial := Vector3(sin(angle), 0.0, cos(angle))
		var tangent := Vector3(cos(angle), 0.0, -sin(angle))
		var floor_rows: Array = rows.filter(func(p): return not p.rect.size.is_zero_approx())
		for p in floor_rows:
			var corners: Array[Vector3] = _placement_corners(p)
			var min_depth := INF
			for corner in corners:
				var delta: Vector3 = corner - center
				var depth: float = delta.dot(radial)
				var lateral: float = delta.dot(tangent)
				min_depth = minf(min_depth, depth)
				res.checked += 1
				if depth < -0.001 or depth * depth + lateral * lateral > usable_radius * usable_radius + 0.002:
					res.fail("%s chapel %d %s measured footprint leaves its half-disc" % [
						label, chapel_index, String(p.key)])
			if min_depth < ChurchFurnisher.CHAPEL_THRESHOLD_CLEAR - 0.001:
				res.fail("%s chapel %d %s enters the physical mouth threshold" % [
					label, chapel_index, String(p.key)])
		# Verify the route against each bench and altar after all independent
		# footprint measurements are available.
		var altar_row: Dictionary = {}
		for p in floor_rows:
			if String(p.key) == ChurchFurnisher.ALTAR:
				altar_row = p
		if altar_row.is_empty():
			res.checked += 1
			res.fail("%s chapel %d has no floor altar" % [label, chapel_index])
			continue
		var altar_depth := INF
		for corner in _placement_corners(altar_row):
			altar_depth = minf(altar_depth, (corner - center).dot(radial))
		_check_chapel_tabletop(res, rows, altar_row, radial, tangent,
			chapel_index, label)
		var route_rect := Rect2(Vector2(-ChurchFurnisher.CHAPEL_ROUTE_W * 0.5,
			ChurchFurnisher.CHAPEL_THRESHOLD_CLEAR), Vector2(ChurchFurnisher.CHAPEL_ROUTE_W,
			maxf(0.0, altar_depth - ChurchFurnisher.CHAPEL_THRESHOLD_CLEAR - 0.02)))
		for p in floor_rows:
			if String(p.key) != ChurchFurnisher.PEW:
				continue
			var bounds := _local_chapel_bounds(_placement_corners(p), center, radial, tangent)
			res.checked += 1
			if route_rect.intersects(bounds):
				res.fail("%s chapel %d bench obstructs the central %.2f m mouth route" % [
					label, chapel_index, ChurchFurnisher.CHAPEL_ROUTE_W])

	var assembled := ChurchAssembler.build(spec, false)
	var dressing := assembled.get_node_or_null("Dressing") as Node3D
	res.checked += 1
	if dressing == null:
		res.fail("%s production assembly has no Dressing node" % label)
	else:
		var actual := dressing.get_children()
		res.checked += chapel_rows.size()
		if actual.size() < chapel_rows.size():
			res.fail("%s assembled %d props for %d chapel placements" % [
				label, actual.size(), chapel_rows.size()])
		for p in chapel_rows:
			var expected_origin: Vector3 = ShellAssembler.world_origin(p)
			var expected_scene_path: String = PropCatalog.scene_path(String(p.key))
			var found := false
			for node in actual:
				var expected_yaw: float = float(p.yaw) + PropCatalog.face_offset(String(p.key))
				if node.scene_file_path == expected_scene_path \
						and node.position.distance_to(expected_origin) < 0.001 \
						and node.scale.distance_to(Vector3.ONE * float(p.scale)) < 0.001:
					if absf(wrapf(node.rotation.y - expected_yaw, -PI, PI)) >= 0.001:
						continue
					found = true
					break
			if not found:
				res.fail("%s %s at its measured chapel placement was not assembled" % [
					label, String(p.key)])
	assembled.free()
	for row in chapel_rows:
		var scene_path: String = PropCatalog.scene_path(String(row.key))
		res.checked += 1
		if not ResourceLoader.exists(scene_path):
			res.fail("%s measured prop %s has no loadable source scene at %s" % [
				label, String(row.key), scene_path])
		if String(row.key) in ["CandleStick_Triple", "Chalice", "Book_Stack_1"] \
				and not PropCatalog.has_tag(String(row.key), PropCatalog.ON_SURFACE):
			res.checked += 1
			res.fail("%s tabletop prop %s is not tagged for measured surface placement" % [
				label, String(row.key)])


static func _check_chapel_inventory(res: SuiteResult, rows: Array,
		chapel_index: int, label: String) -> void:
	var expected := {"Table_Large": 1, "Bench": 2, "Chalice": 1,
		"CandleStick_Triple": 2, "Book_Stack_1": 1}
	for key in expected:
		var count := 0
		for p in rows:
			if String(p.key) == key:
				count += 1
		res.checked += 1
		if count != int(expected[key]):
			res.fail("%s chapel %d expected %d %s placements; got %d" % [
				label, chapel_index, int(expected[key]), key, count])


static func _check_chapel_tabletop(res: SuiteResult, rows: Array, altar: Dictionary,
		radial: Vector3, tangent: Vector3, chapel_index: int,
		label: String) -> void:
	var altar_scale: float = float(altar.scale)
	var altar_yaw: float = float(altar.yaw)
	var altar_plan_center: Vector2 = PropCatalog.plan_centre(String(altar.key),
		altar.pos, altar_yaw, altar_scale)
	var altar_center := Vector3(altar_plan_center.x, float(altar.pos.y), altar_plan_center.y)
	var top: float = altar_center.y + PropCatalog.surface_height(String(altar.key)) * altar_scale
	var table_foot: Vector2 = PropCatalog.footprint(String(altar.key)) * altar_scale * 0.5
	for p in rows:
		if String(p.key) not in ["Chalice", "CandleStick_Triple", "Book_Stack_1"]:
			continue
		res.checked += 1
		if absf(float(p.pos.y) - top) > 0.001:
			res.fail("%s chapel %d %s is not at the measured altar surface height" % [
				label, chapel_index, String(p.key)])
		for corner in _placement_corners(p):
			var altar_delta: Vector3 = corner - altar_center
			if absf(altar_delta.dot(tangent)) > table_foot.x + 0.001 \
					or absf(altar_delta.dot(radial)) > table_foot.y + 0.001:
				res.fail("%s chapel %d %s misses its measured table top" % [
					label, chapel_index, String(p.key)])


static func _placement_corners(p: Dictionary) -> Array[Vector3]:
	var key := String(p.key)
	var scale := float(p.get("scale", 1.0))
	var yaw := float(p.yaw)
	var footprint: Vector2 = PropCatalog.footprint(key) * scale * 0.5
	var local_x := Vector3(cos(yaw), 0.0, -sin(yaw))
	var local_z := Vector3(sin(yaw), 0.0, cos(yaw))
	var center: Vector2 = PropCatalog.plan_centre(key, p.pos, yaw, scale)
	var out: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			out.append(Vector3(center.x, p.pos.y, center.y)
				+ local_x * (float(sx) * footprint.x)
				+ local_z * (float(sz) * footprint.y))
	return out


static func _local_chapel_bounds(corners: Array[Vector3], center: Vector3,
		radial: Vector3, tangent: Vector3) -> Rect2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for corner in corners:
		var delta: Vector3 = corner - center
		var point := Vector2(delta.dot(tangent), delta.dot(radial))
		low = low.min(point)
		high = high.max(point)
	return Rect2(low, high - low)


static func _churches(res: SuiteResult, quick: bool) -> void:
	for style in TestSweep.styles():
		for i in range(TestSweep.COUNT):
			if quick and not i in QUICK_CHURCH_INDICES:
				continue
			var spec: ChurchSpec = TestSweep.spec_at(style, i)
			var label := "church %s/%d" % [String(style), TestSweep.seed_at(i)]
			var builder := ChurchBuilder.new()
			var mesh := builder.build(spec)
			var props: Array = builder.prop_log
			var check := DressingCheck.new()
			check.check(props, _church_bounds(spec), builder.total_height, label)
			check.embedded(props, _solid_triangles(mesh), label)
			_want(check, props, CHURCH_WANTS, label)
			_church_wall(check, spec, props, label)
			# the one piece of floor a church exists to be walked down
			var nave := Rect2(Vector2(-spec.width / 2.0 + 0.15, -spec.length / 2.0 + 0.15),
				Vector2(spec.width - 0.3, spec.length - 0.3))
			var altar_z: float = ChurchFurnisher.altar_z(spec)
			check.walk(props, [nave], [], Vector2(0.0, -spec.length / 2.0 + 0.6),
				Rect2(Vector2(-0.4, altar_z - 1.4), Vector2(0.8, 0.8)),
				label, "west door to the altar")
			_report(res, check)


## Mounted pieces hang on solid wall, and nothing is stored in the way in.
static func _church_wall(check: DressingCheck, spec: ChurchSpec, props: Array, label: String) -> void:
	var bands: Array = [{"x0": spec.width / 2.0 - 0.8, "x1": spec.width / 2.0 + 0.8,
			"holes": ChurchFurnisher.wall_openings(spec)},
		{"x0": -spec.width / 2.0 - 0.8, "x1": -spec.width / 2.0 + 0.8,
			"holes": ChurchFurnisher.wall_openings(spec)}]
	check.mounted_clear(props, bands, label)
	if spec.tower and spec.west_towers == 1:
		var tower: AABB = ChurchGeometry.tower_aabb(spec, ChurchGeometry.west_tower_sides(spec)[0])
		var plan := Rect2(tower.position.x, tower.position.z, tower.size.x, tower.size.z)
		for p in props:
			check.checked += 1
			if p["kind"] in [&"store", &"rope"] and plan.has_point(Vector2(p["pos"].x, p["pos"].z)):
				check.fail("%s: %s stored in the entrance tower" % [label, p["key"]])


## The 26 Oct walk, Grey Ninian-in-the-Wold: a Russian church, seed 1, torches
## burned in the nave windows and a crate and rope sat in the entrance.
## The control hangs a torch in a window and must be called out.
static func _church_openings_case(res: SuiteResult) -> void:
	var spec := ChurchSpec.new()
	spec.style = &"russian"
	spec.width = 10.0
	spec.length = 22.0
	spec.height = 12.0
	ChurchGenerator.generate(spec, 1)
	var builder := ChurchBuilder.new()
	builder.build(spec)
	var check := DressingCheck.new()
	_church_wall(check, spec, builder.prop_log, "russian pin 1")
	_report(res, check)
	var holes: Array[Rect2] = ChurchFurnisher.wall_openings(spec)
	res.checked += 1
	if holes.is_empty():
		res.fail("russian pin 1: the church has no nave windows to hang clear of")
		return
	var h: Rect2 = holes[0]
	var bad := PropCatalog.placement("Torch_Metal",
		Vector3(spec.width / 2.0 - 0.3, h.get_center().y, h.get_center().x), 0.0, 1.0, &"light")
	var probe := DressingCheck.new()
	probe.mounted_clear([bad], [{"x0": spec.width / 2.0 - 0.8, "x1": spec.width / 2.0 + 0.8,
		"holes": holes}], "control")
	res.checked += 1
	if probe.failures.is_empty():
		res.fail("control: a torch hung in a window was not called out")
	res.checked += 1
	if ChurchFurnisher.clear_wall_z("Torch_Metal", h.get_center().y, h.get_center().x, holes,
			-spec.length / 2.0, spec.length / 2.0) == h.get_center().x:
		res.fail("clear_wall_z left a torch in the middle of a window")


static func _castles(res: SuiteResult, quick: bool) -> void:
	for style in CastleSweep.styles():
		if quick and not style in QUICK_CASTLE_STYLES:
			continue
		for tier in CastleSweep.tiers():
			for i in range(CastleSweep.COUNT):
				if quick and i != 0:
					continue
				var spec: CastleSpec = CastleSweep.spec_at(style, tier, i)
				var label := "castle %s/%s/%d" % [String(style), String(tier),
					CastleSweep.seed_at(tier, i)]
				var builder := CastleBuilder.new()
				var mesh := builder.build(spec)
				var props: Array = builder.prop_log
				var check := DressingCheck.new()
				# Since INT-007 the great hall and keep are furnished by planned
				# interiors, not by the shell furnisher. A table or a light in
				# either is a table or a light in the castle; a castle with
				# neither anywhere, shell or interior, still fails.
				var inside := _interior_props(builder)
				# A sky castle is dressed like the rest (EVAL-B07): braziers at the
				# foot of its turrets, a board on the rock, heraldry on the drums.
				# It owes a table and a light as every castle does; the old
				# `bare_sky` exemption is gone.
				check.check(props, CastleGeometry.plan_extent(spec),
					builder.total_height, label, inside)
				_want(check, props + inside, CASTLE_WANTS, label)
				check.embedded(props, _solid_triangles(mesh), label)
				if CastleGeometry.is_enclosed(spec):
					_walk_the_yard(check, spec, props, label)
				_report(res, check)


## From the gate, across the courtyard, to the door of everything that stands
## in it. The buildings block the floor; so does the dressing.
static func _walk_the_yard(check: DressingCheck, spec: CastleSpec, props: Array,
		label: String) -> void:
	var bailey: Rect2 = CastleGeometry.bailey_rect(spec)
	if bailey.size.x < 6.0 or bailey.size.y < 6.0:
		return
	var blocks: Array[Rect2] = []
	for a in [CastleGeometry.keep_aabb(spec), CastleGeometry.hall_aabb(spec),
			CastleGeometry.chapel_aabb(spec)]:
		if a.size.x > 0.0:
			blocks.append(Rect2(Vector2(a.position.x, a.position.z),
				Vector2(a.size.x, a.size.z)))
	if CastleGeometry.is_motte(spec):
		var m: AABB = CastleGeometry.motte_aabb(spec)
		blocks.append(Rect2(Vector2(m.position.x, m.position.z),
			Vector2(m.size.x, m.size.z)))
	var from := Vector2(0.0, bailey.position.y + 0.6)
	# the middle of the yard, which everything in it opens onto
	check.walk(props, [bailey], blocks, from,
		Rect2(bailey.get_center() - Vector2(0.4, 0.4), Vector2(0.8, 0.8)),
		label, "gate to the middle of the bailey")


## The ground a church stands on: the nave and everything that grew off it.
static func _church_bounds(spec: ChurchSpec) -> Rect2:
	var out := Rect2(Vector2(-spec.width / 2.0, -spec.length / 2.0),
		Vector2(spec.width, spec.length))
	if spec.aisles > 0:
		var x: float = ChurchGeometry.aisle_outer_x(spec)
		out = out.merge(Rect2(Vector2(-x, -spec.length / 2.0),
			Vector2(x * 2.0, spec.length)))
	if spec.transept:
		var t: AABB = ChurchGeometry.transept_aabb(spec)
		out = out.merge(Rect2(Vector2(t.position.x, t.position.z),
			Vector2(t.size.x, t.size.z)))
	if spec.apse:
		var a: AABB = ChurchGeometry.apse_aabb(spec)
		out = out.merge(Rect2(Vector2(a.position.x, a.position.z),
			Vector2(a.size.x, a.size.z)))
	for chapel_index in range(spec.radiating_chapels):
		var chapel: AABB = ChurchGeometry.chapel_aabb(spec, chapel_index)
		out = out.merge(Rect2(Vector2(chapel.position.x, chapel.position.z),
			Vector2(chapel.size.x, chapel.size.z)))
	if spec.tower:
		for side in ChurchGeometry.west_tower_sides(spec):
			var tw: AABB = ChurchGeometry.tower_aabb(spec, side)
			out = out.merge(Rect2(Vector2(tw.position.x, tw.position.z),
				Vector2(tw.size.x, tw.size.z)))
	if spec.narthex:
		var n: AABB = ChurchGeometry.narthex_aabb(spec)
		out = out.merge(Rect2(Vector2(n.position.x, n.position.z),
			Vector2(n.size.x, n.size.z)))
	return out


## Counting the planned interiors must not make the wants unfailable: a castle
## with no table and no fire anywhere, shell or interior, still fails all
## three, and one whose only light is a planned interior's sconce does not.
static func _negative_control(res: SuiteResult) -> void:
	var bare := DressingCheck.new()
	_want(bare, [], CASTLE_WANTS, "control: bare castle")
	bare.check([], Rect2(Vector2(-10, -10), Vector2(20, 20)), 10.0, "control: bare castle", [])
	res.checked += 1
	if bare.failures.size() != 2 or bare.warnings.size() != 1:
		res.fail("control: a castle with no table and no fire must fail 'table' and 'light' and warn 'lit' (got %d failures, %d warnings)"
			% [bare.failures.size(), bare.warnings.size()])
	var lit := DressingCheck.new()
	lit.check([], Rect2(Vector2(-10, -10), Vector2(20, 20)), 10.0, "control: sconce",
		[{"key": "Torch_Metal", "kind": "light"}])
	res.checked += 1
	if not lit.warnings.is_empty():
		res.fail("control: an interior sconce should count as light")
	res.checked += lit.checked + bare.checked
	# A standing piece inside a block of masonry is buried; the same piece set
	# beside it, or on top of it, is not.
	var block := MassBuilder.new()
	block.begin(1)
	block.box(Vector3(2, 3, 2), Vector3(0, 1.5, 0), 0)
	var solid := _solid_triangles(block.commit())
	var cases := {"inside": [Vector3(0.3, 0.0, 0.2), true], "beside": [Vector3(2.5, 0.0, 0.0), false],
		"on top": [Vector3(0.0, 3.0, 0.0), false], "sunk": [Vector3(0.0, 2.7, 0.0), true]}
	for name in cases:
		var probe := DressingCheck.new()
		probe.embedded([PropCatalog.placement("Cauldron", cases[name][0], 0.0, 1.0, &"light")], solid, "control")
		res.checked += 1
		if probe.failures.is_empty() == bool(cases[name][1]):
			res.fail("control: a cauldron %s a block %s" % [name,
				"was not called buried" if cases[name][1] else "was called buried"])


## The solid faces of a shell: stone, trim and roof, never openings or glass.
static func _solid_triangles(mesh: ArrayMesh) -> Array:
	var out: Array = []
	for surface in [0, 1, 2]:
		if surface < mesh.get_surface_count():
			out.append_array(HouseQA._mesh_triangles(mesh, surface))
	return out


## The furniture of the castle's planned interiors, as placements the wants
## can read: `kind` is the catalogue category, or "light" for anything the
## catalogue tags as a light. Positions are in each plan's own frame, so these
## feed only the wants and the lit rule, never the placement rules.
static func _interior_props(builder: CastleBuilder) -> Array:
	var out: Array = []
	for row in builder.interiors:
		var plan: HousePlan = row.get("plan")
		if plan == null:
			continue
		for f in plan.furniture:
			var key: String = f.key
			var kind := "light" if PropCatalog.has_tag(key, PropCatalog.LIGHT) \
				else PropCatalog.category(key)
			out.append({"key": key, "kind": kind})
	return out


## A building with none of the things that make it that kind of building has
## not been dressed, whatever else it passed.
static func _want(check: DressingCheck, props: Array, kinds: Array,
		label: String) -> void:
	for kind in kinds:
		check.checked += 1
		var found := false
		for p in props:
			if String(p.get("kind", "")) == String(kind):
				found = true
				break
		if not found:
			check.fail("%s: nothing in it is a '%s'" % [label, kind])


static func _report(res: SuiteResult, check: DressingCheck) -> void:
	res.checked += check.checked
	for f in check.failures:
		res.fail(f)
	for w in check.warnings:
		res.warn(w)
