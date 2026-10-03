extends RefCounted
## Bavarian ridge rooms and the windows cut into their upper range walls share
## the levels and floor bands measured by CastleGeometry.
## This focused suite covers the occupied hall/range segments. The castle-wide
## inventory also requires ridge towers; CastleInteriors.ridge does not yet
## provide tower interior records. This is part of the broader
## CASTLE-INTERIOR-FORMS todo c39aea8a-b8e0-47ca-b658-56cbeb0a24e1.
const Occupancy = preload("res://qa/castle_occupancy_check.gd")
const OccupancySuite = preload("res://tests/suites/castle_occupancy_suite.gd")

static func run() -> SuiteResult:
	var result := SuiteResult.new("castle ridge occupancy")
	var spec := CastleSpec.new()
	spec.style = &"bavarian"
	spec.width = 120.0
	spec.length = 40.0
	spec.height = 20.0
	spec.plan_override = &"ridge"
	CastleGenerator.generate(spec, 8805)
	var builder := CastleBuilder.new()
	var mesh := builder.build(spec)
	if mesh == null:
		result.fail("seed 8805 emitted no ridge mesh")
		return result
	var geometry := Occupancy.prepare_mesh(mesh)
	var levels: int = CastleGeometry.ridge_storeys(spec)
	var mutation_done := false
	for segment in CastleGeometry.ridge_ranges(spec):
		var id := String(segment["name"])
		var row := _range_record(builder, id)
		result.checked += 1
		if row.is_empty():
			result.fail("%s has no occupied range record" % id)
			continue
		_check_range(result, builder, row, segment, levels, geometry)
		if not mutation_done:
			mutation_done = _check_missing_upper_floor(result, spec, builder, mesh, row)
	if not mutation_done:
		result.fail("ridge fixture has no upper room for retained-log floor-removal control")
	return result


static func _range_record(builder: CastleBuilder, id: String) -> Dictionary:
	for row in builder.interiors:
		if String(row.get("id", "")) == id:
			return row
	return {}


static func _check_range(result: SuiteResult, builder: CastleBuilder,
		row: Dictionary, segment: Dictionary, levels: int, geometry: Dictionary) -> void:
	var id := String(row.id)
	var plan: HousePlan = row.plan
	var band_height: float = float(segment["height"]) / float(levels)
	var label := "%s %s" % [id, builder.spec.seed]
	if plan.spec.storeys != levels:
		result.fail("%s plans %d floors for %d emitted facade bands" %
			[label, plan.spec.storeys, levels])
	if absf(plan.spec.height - band_height) > 0.01:
		result.fail("%s floor height %.3f differs from emitted band %.3f" %
			[label, plan.spec.height, band_height])
	if plan.room_count() != plan.spec.program.size():
		result.fail("%s programme does not describe every occupied room" % label)
	if plan.stairs.size() != levels - 1:
		result.fail("%s has %d stairs for %d adjacent occupied levels" %
			[label, plan.stairs.size(), levels - 1])
	var report := HouseQA.new().check(plan, null)
	if not report.failures.is_empty():
		result.fail("%s interior plan: %s" % [label, report.failures])
	var floor_audit := {"failures": [], "stats": {"room_floor_samples": 0}}
	for room_index in plan.rooms.size():
		Occupancy._check_room_floor(floor_audit, id, row, room_index, geometry)
	for failure in floor_audit.failures:
		result.fail("%s emitted floor: %s" % [label, failure])
	if int(floor_audit.stats.room_floor_samples) == 0:
		result.fail("%s emitted-floor probe sampled no room points" % label)
	var plan_windows_by_level := {}
	for level in range(levels):
		if plan.rooms_on_storey(level).is_empty():
			result.fail("%s storey %d has emitted height but no occupied room" % [label, level])
		plan_windows_by_level[level] = 0
	for window in plan.windows:
		var level := HousePlan.record_storey(window)
		var room := int(window.get("room", -1))
		if level < 0 or level >= levels or room < 0 or room >= plan.room_count():
			result.fail("%s has a window with invalid room/storey ownership" % label)
			continue
		if HousePlan.record_storey(plan.rooms[room]) != level:
			result.fail("%s window on storey %d belongs to room %d on another floor" %
				[label, level, room])
		plan_windows_by_level[level] = int(plan_windows_by_level[level]) + 1
	for level in range(levels):
		if int(plan_windows_by_level[level]) == 0:
			result.fail("%s storey %d has no planned facade openings" % [label, level])

	var window_audit := {"failures": [], "stats": {"windows": 0}}
	var emitted_windows := 0
	for part in builder.part_log:
		if String(part.get("tag", "")) != id \
				or String(part.get("kind", "")) != "window":
			continue
		emitted_windows += 1
		Occupancy._check_emitted_window(window_audit, id, row, part, geometry)
	if emitted_windows == 0:
		result.fail("%s has no transformed emitted windows to occupancy-check" % label)
	for failure in window_audit.failures:
		result.fail("%s emitted window: %s" % [label, failure])

	# The range emitter used to add separate upper holes after the ground-floor
	# interior had been emitted. Catch any such unplanned window by locating the
	# real segment facade in its own rotated range frame.
	var inverse: Transform3D = row.transform.affine_inverse()
	var run: float = float(segment["length"])
	var across: float = float(segment["width"])
	var shell_height: float = float(segment["height"])
	var owner_tag := "hall" if id == "hall" else "range"
	for part in builder.part_log:
		if String(part.get("opening_kind", "")) != "window" \
				or bool(part.get("planned_opening", false)) \
				or String(part.get("tag", "")) != owner_tag:
			continue
		var local: Vector3 = inverse * Vector3(part.pos)
		if local.y < 0.0 or local.y > shell_height \
				or absf(local.x) > run * 0.5 + 0.02 \
				or absf(absf(local.z) - across * 0.5) > 0.2:
			continue
		var level := clampi(int(floor(local.y / band_height)), 0, levels - 1)
		if level > 0:
			result.fail("%s retains an unplanned window at upper band %d" % [label, level])


static func _check_missing_upper_floor(result: SuiteResult, spec: CastleSpec,
		builder: CastleBuilder, mesh: ArrayMesh, row: Dictionary) -> bool:
	var plan: HousePlan = row.plan
	var upper_room := -1
	for room_index in plan.rooms.size():
		if plan.storey_of_room(room_index) > 0:
			upper_room = room_index
			break
	if upper_room < 0:
		return false
	var stripped: Dictionary = OccupancySuite._without_floor(mesh, row, upper_room)
	result.checked += 1
	if int(stripped.get("removed", 0)) <= 0:
		result.fail("upper-room floor-removal control removed no final-mesh triangles")
		return true
	var stripped_geometry := Occupancy.prepare_mesh(stripped.mesh)
	var audit := {"failures": [], "stats": {"room_floor_samples": 0}}
	Occupancy._check_room_floor(audit, String(row.id), row, upper_room, stripped_geometry)
	var expected := "occupied_shells[%s]: room %d has no emitted floor with standing clearance" \
		% [String(row.id), upper_room]
	if not audit.failures.has(expected):
		result.fail("retained-log upper-room floor removal escaped direct emitted-floor probe: %s" \
			% [str(audit.failures)])
	var full := Occupancy.check(spec, builder, stripped.mesh, stripped_geometry)
	if not full.failures.has(expected):
		result.fail("retained-log upper-room floor removal escaped full occupancy check: %s" \
			% [str(full.failures)])
	return true
