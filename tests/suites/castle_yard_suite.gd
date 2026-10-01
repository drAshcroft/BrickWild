extends RefCounted
## VIS-015: large working baileys measure exterior occupancy separately from
## the furniture in their ranges, and keep routes between the gate and uses.

static func run() -> SuiteResult:
	var res := SuiteResult.new("VIS-015 castle yard occupancy")
	var krak := _fixture(&"crusader", 300.0, 140.0, 20.0, 6002)
	var chambord := _fixture(&"french_chateau", 156.0, 117.0, 32.0, 6003)
	var first := _check_fixture(res, krak, "Krak seed 6002", true)
	var second := _check_fixture(res, chambord, "large fortress seed 6003", false)
	if float(first.get("clear_before_m2", 0.0)) > float(second.get("clear_before_m2", 0.0)) \
			and int(first.get("exterior_fixture_count", 0)) < int(second.get("exterior_fixture_count", 0)):
		res.fail("yard placement count did not scale with available clear ward area")
	return res


static func _fixture(style: StringName, width: float, length: float,
		height: float, seed: int) -> Dictionary:
	var spec := CastleSpec.new()
	spec.style = style
	spec.tier_override = &"fortress"
	spec.width = width
	spec.length = length
	spec.height = height
	CastleGenerator.generate(spec, seed)
	var builder := CastleBuilder.new()
	builder.build(spec)
	return {"spec": spec, "builder": builder}


static func _check_fixture(res: SuiteResult, fixture: Dictionary,
		label: String, run_route := false) -> Dictionary:
	var spec: CastleSpec = fixture.spec
	var builder: CastleBuilder = fixture.builder
	var report: Dictionary = builder.yard_report
	res.note("%s: ward %.0f m²; clear %.0f -> %.0f m²; %d exterior fixtures occupy %.0f m²; %d range-interior props" % [
		label, float(report.get("ward_area_m2", 0.0)),
		float(report.get("clear_before_m2", 0.0)), float(report.get("clear_after_m2", 0.0)),
		int(report.get("exterior_fixture_count", 0)),
		float(report.get("fixture_occupied_m2", 0.0)),
		int(report.get("interior_prop_count", 0))])
	_want(res, int(report.get("range_count", 0)) > 0, label + ": bailey ranges disappeared")
	_want(res, bool(report.get("well_present", false)), label + ": planned well disappeared")
	_want(res, int(report.get("interior_prop_count", 0)) > 0,
		label + ": range furniture was not measured separately")
	_want(res, int(report.get("exterior_fixture_count", 0)) >= 3,
		label + ": fewer than three exterior yard fixtures")
	_want(res, int(report.get("exterior_fixture_count", 0)) > CastleFurnisher.YARD_PROGRAMME.size(),
		label + ": area-scaled programme fell back to the former fixed prop count")
	_want(res, float(report.get("ward_area_m2", 0.0)) > float(report.get("clear_before_m2", 0.0)),
		label + ": pre-dressing clear-area record is invalid")
	_want(res, float(report.get("clear_before_m2", 0.0)) > float(report.get("clear_after_m2", 0.0)),
		label + ": exterior fixtures did not reduce the measured clear area")
	_want(res, float(report.get("clear_after_m2", 0.0)) > 0.0,
		label + ": yard fixtures consumed the whole ward")
	_want(res, not report.get("fixtures", []).is_empty(), label + ": no fixture footprint records")
	var uses := {}
	var union_area := 0.0
	var fixtures: Array = report.get("fixtures", [])
	var reserved: Array[Rect2] = CastleFurnisher._reserved(spec)
	for i in range(fixtures.size()):
		var row: Dictionary = fixtures[i]
		uses[StringName(row["use"])] = true
		var rect: Rect2 = row["rect"]
		union_area += float(row["occupied_m2"])
		for obstacle in reserved:
			_want(res, not rect.intersects(obstacle),
				label + ": %s intersects a route, range, well or access reserve" % row["key"])
		if run_route:
			var pos: Vector3 = row["pos"]
			for mass in builder.mass_log:
				var aabb: AABB = mass.get("aabb", AABB())
				if aabb.size.x <= 0.0 or aabb.size.z <= 0.0 \
						or pos.y > aabb.position.y + aabb.size.y:
					continue
				var body: Rect2 = Rect2(aabb.position.x, aabb.position.z,
					aabb.size.x, aabb.size.z)
				_want(res, not rect.intersects(body),
					label + ": %s intersects logged mass %s" % [row["key"], mass.get("name", "?")])
		for j in range(i + 1, fixtures.size()):
			_want(res, not rect.intersects(fixtures[j]["rect"]),
				label + ": exterior fixtures overlap")
	_want(res, uses.has(&"transport") and uses.has(&"smithing") and uses.has(&"training"),
		label + ": yard uses are not visibly distinct")
	_want(res, is_equal_approx(union_area, float(report["fixture_occupied_m2"])),
		label + ": occupied-footprint total disagrees with fixture records")
	if run_route:
		_route_checks(res, spec, builder, label)
	return report


static func _route_checks(res: SuiteResult, spec: CastleSpec,
		builder: CastleBuilder, label: String) -> void:
	var bailey: Rect2 = CastleGeometry.bailey_rect(spec)
	var blocks: Array[Rect2] = []
	for a in [CastleGeometry.keep_aabb(spec), CastleGeometry.hall_aabb(spec),
			CastleGeometry.chapel_aabb(spec), CastleGeometry.apse_aabb(spec)]:
		if a.size.x > 0.0:
			blocks.append(Rect2(a.position.x, a.position.z, a.size.x, a.size.z))
	if CastleGeometry.is_motte(spec):
		var motte: AABB = CastleGeometry.motte_aabb(spec)
		blocks.append(Rect2(motte.position.x, motte.position.z, motte.size.x, motte.size.z))
	for r in CastleGeometry.rings(spec):
		var tower_index := 0
		for tower in CastleGeometry.vertex_tower_centers(spec, r):
			var half: float = CastleGeometry.tower_base_half_at(spec, r, tower_index)
			blocks.append(Rect2(tower.x - half, tower.z - half, half * 2.0, half * 2.0))
			tower_index += 1
	for entry in CastleGenerator.bailey_buildings(spec):
		blocks.append(Rect2(entry["rect"]))
	var well: Dictionary = CastleGenerator.bailey_well(spec)
	if not well.is_empty():
		var at: Vector2 = well["pos"]
		var radius: float = float(well.get("radius", 0.9))
		blocks.append(Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0))
	for prop in builder.prop_log:
		var rect: Rect2 = prop["rect"]
		if rect.size.x > 0.0 and (prop["pos"] as Vector3).y < 1.0:
			blocks.append(rect)
	var grid := _yard_grid(bailey, blocks)
	var from := Vector2(0.0, bailey.position.y + 1.2)
	var keep: AABB = CastleGeometry.keep_aabb(spec)
	var keep_approach := Rect2(Vector2(keep.position.x + keep.size.x * 0.25,
		keep.position.z - 3.0), Vector2(keep.size.x * 0.5, 2.0))
	if not grid.flood_from(from, 2.0) or not grid.reached(keep_approach, 0.4):
		res.fail(label + ": bailey dressing blocks the continuous gate-to-keep route")
	else:
		res.checked += 1
	# One flood proves that the well, shops and wall-stair landings all remain
	# reachable; individual placement checks above prove their approaches are
	# outside the fixture collision envelopes.
	var targets: Array[Dictionary] = []
	if not well.is_empty():
		var at: Vector2 = well["pos"]
		var radius: float = float(well.get("radius", 0.9))
		var body := Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
		targets.append({"label": "well", "rect": _approach_target(body, bailey.get_center())})
	for entry in CastleGenerator.bailey_buildings(spec):
		var r: Rect2 = entry["rect"]
		targets.append({"label": String(entry.get("kind", "range")),
			"rect": _approach_target(r, bailey.get_center())})
	var stair_index := 0
	for stair in CastleGeometry.wall_stairs(spec):
		var approach: Rect2 = stair.footprint.grow(0.3)
		for prop in builder.prop_log:
			if StringName(prop.get("yard_zone", &"")) != &"bailey_exterior":
				continue
			_want(res, not approach.intersects(prop["rect"]),
				label + ": wall stair %d approach is occupied" % stair_index)
		stair_index += 1
	for target in targets:
		_want(res, grid.reached(target.rect, 0.4),
			label + ": %s approach is unreachable" % target.label)
	# A full-width cross-yard barrier is a deliberate negative control. The
	# source-side walk remains possible, but the keep-side target must be cut off.
	var sealed := _yard_grid(bailey, blocks)
	sealed.add_obstacle(Rect2(bailey.position.x - 2.0,
		bailey.get_center().y - 0.8, bailey.size.x + 4.0, 1.6))
	sealed.build(HouseGeometry.PERSON_RADIUS)
	var control_ok := sealed.flood_from(from, 2.0) and not sealed.reached(keep_approach, 0.4)
	_want(res, control_ok, label + ": deliberate blocked-route control was not detected")


static func _yard_grid(bailey: Rect2, blocks: Array[Rect2]) -> WalkGrid:
	var grid := WalkGrid.new()
	grid.setup(bailey.grow(0.5), clampf(maxf(bailey.size.x, bailey.size.y) / 400.0,
		0.12, HouseGeometry.PERSON_RADIUS))
	grid.add_floor(bailey)
	for block in blocks:
		grid.add_obstacle(block)
	grid.build(HouseGeometry.PERSON_RADIUS)
	return grid


## A use is reached at the clear ground beside its footprint, not in the solid
## well/range body itself. Pick the point on the yard-facing edge and step one
## person radius into the court.
static func _approach_target(body: Rect2, toward: Vector2) -> Rect2:
	var edge := Vector2(clampf(toward.x, body.position.x, body.end.x),
		clampf(toward.y, body.position.y, body.end.y))
	var direction := (toward - edge).normalized()
	if direction.length_squared() < 0.0001:
		direction = Vector2.RIGHT
	var centre := edge + direction * (HouseGeometry.PERSON_RADIUS + 0.3)
	return Rect2(centre - Vector2.ONE * 0.4, Vector2.ONE * 0.8)


static func _want(res: SuiteResult, passed: bool, message: String) -> void:
	if passed:
		res.checked += 1
	else:
		res.fail(message)
