class_name WorldHanSuite
extends RefCounted
## WLD-006: Sultan's Han contract and one negative fixture for each rule.


static func run() -> SuiteResult:
	var res := SuiteResult.new("world han")
	var request := BuildingRequest.new()
	request.kind = &"world"
	request.style = &"caravanserai"
	request.purpose = &"sultan_han"
	request.seed = 9606
	request.width = 70.0
	request.length = 55.0
	request.height = 12.0
	var building: GeneratedBuilding = BigGlade.generate(request)
	res.checked += 1
	if building == null or not building.is_ok():
		res.fail("Sultan's Han 70 x 55 x 12 did not generate: %s" %
			str(building.errors) if building != null else "null")
		return res
	if absf(building.spec.width - 70.0) > 0.01 or absf(building.spec.length - 55.0) > 0.01 \
			or absf(float(building.plan.world_meta.get("total_height", 0.0)) - 12.0) > 0.5:
		res.fail("Sultan's Han did not retain its canonical 70 x 55 x 12 dimensions")
	var builder := HouseBuilder.new()
	var mesh := builder.build(building.plan)
	if mesh == null:
		res.fail("Sultan's Han has no emitted shell")
	for failure in HanCheck.new().check(building.plan, builder)["failures"]:
		res.fail("Sultan's Han: %s" % str(failure))
	_fixtures(res)
	return res


static func _fixture_plan(seed: int) -> HousePlan:
	return WorldHanGenerator.generate(seed, 70.0, 55.0, 12.0)["plan"]


static func _expect(res: SuiteResult, label: String, prefix: String,
		plan: HousePlan, builder: HouseBuilder = null) -> void:
	res.checked += 1
	var report := HanCheck.new().check(plan, builder)
	for failure in report.get("failures", []):
		if String(failure).begins_with(prefix + ":"):
			return
	res.fail("negative Han fixture %s did not fail %s" % [label, prefix])


static func _fixtures(res: SuiteResult) -> void:
	var gate := _fixture_plan(9610)
	for door in gate.doors:
		if String(door.get("role", "")) == "han_gate":
			door["head"] = 2.8
			break
	_expect(res, "short gate", "gate", gate)

	var extra_gate := _fixture_plan(9611)
	var gate_row: Dictionary = {}
	for door in extra_gate.doors:
		if String(door.get("role", "")) == "han_gate":
			gate_row = door.duplicate(true)
			break
	gate_row["role"] = "second_outer_door"
	extra_gate.doors.append(gate_row)
	_expect(res, "second outer door", "gate", extra_gate)

	var outer_window := _fixture_plan(9612)
	var site := HouseGeometry.site_rect(outer_window.spec)
	outer_window.windows.append({"room": 0,
		"pos": Vector2(site.get_center().x, site.position.y), "normal": Vector2(0, -1),
		"width": 0.8, "sill": 0.6, "head": 1.8, "storey": 0})
	_expect(res, "low outer window", "outer_opening", outer_window)

	var small_cell := _fixture_plan(9613)
	for room in small_cell.rooms:
		if room.get("role", "") == "lodging_cell":
			var rect: Rect2 = room["rect"]
			room["rect"] = Rect2(rect.get_center() - Vector2.ONE,
				Vector2(2.0, 2.0))
			break
	_expect(res, "undersized cell", "cell", small_cell)

	var no_cell_door := _fixture_plan(9614)
	var cell_room := _first_room(no_cell_door, &"guest_room")
	_remove_court_doors(no_cell_door, cell_room)
	_expect(res, "cell without a court door", "cell_door", no_cell_door)

	var duplicate_cell_door := _fixture_plan(9615)
	var duplicate_room := _first_room(duplicate_cell_door, &"guest_room")
	for di in duplicate_cell_door.doors_of(duplicate_room):
		duplicate_cell_door.doors.append(duplicate_cell_door.doors[di].duplicate(true))
		break
	_expect(res, "two cell court doors", "cell_door", duplicate_cell_door)

	var narrow_stable := _fixture_plan(9616)
	for door in narrow_stable.doors:
		if String(door.get("role", "")) == "stable_court_door":
			door["width"] = 1.0
			break
	_expect(res, "narrow stable door", "stable", narrow_stable)

	var off_axis_hall := _fixture_plan(9617)
	for room in off_axis_hall.rooms:
		if String(room.get("role", "")) == "winter_hall":
			room["rect"] = Rect2(room["rect"]).translated(Vector2(1.0, 0.0))
			break
	_expect(res, "off-axis winter hall", "winter_hall", off_axis_hall)

	var no_dome := _fixture_plan(9618)
	var no_dome_builder := HouseBuilder.new()
	no_dome_builder.build(no_dome)
	no_dome_builder.mass_log = no_dome_builder.mass_log.filter(
		func(mass: Dictionary) -> bool: return String(mass.get("name", "")) != "han_winter_dome")
	_expect(res, "missing winter dome", "winter_dome", no_dome, no_dome_builder)

	var no_kiosk := _fixture_plan(9619)
	var no_kiosk_builder := HouseBuilder.new()
	no_kiosk_builder.build(no_kiosk)
	no_kiosk_builder.mass_log = no_kiosk_builder.mass_log.filter(
		func(mass: Dictionary) -> bool: return String(mass.get("name", "")) != "han_kiosk")
	_expect(res, "missing kiosk", "kiosk", no_kiosk, no_kiosk_builder)

	var dry_edge := _fixture_plan(9620)
	dry_edge.world_meta["flood_rect"] = Rect2(Vector2(-1.0, -1.0), Vector2(2.0, 2.0))
	var dry_builder := HouseBuilder.new()
	dry_builder.build(dry_edge)
	dry_builder.component_log = dry_builder.component_log.filter(
		func(part: Dictionary) -> bool: return String(part.get("role", "")) != "han_court_flood")
	_expect(res, "flood misses kiosk edges", "flood", dry_edge, dry_builder)

	var blocked_sky := _fixture_plan(9621)
	var court: Rect2 = blocked_sky.world_meta["court_rect"]
	blocked_sky.furniture.append({"key": "Barrel", "room": -1,
		"pos": Vector3(court.get_center().x, 0.0, court.get_center().y),
		"rect": Rect2(court.get_center() - Vector2(0.4, 0.4), Vector2(0.8, 0.8)),
		"zone": Rect2(), "host": -1, "cat": "barrel", "mounted": false})
	_expect(res, "court occupied", "sky", blocked_sky)

	var broken_ring := _fixture_plan(9622)
	_remove_court_doors(broken_ring, -1)
	_expect(res, "broken court ring", "ring", broken_ring)


static func _first_room(plan: HousePlan, kind: StringName) -> int:
	for room in range(plan.room_count()):
		if plan.kind_of(room) == kind:
			return room
	return -1


static func _remove_court_doors(plan: HousePlan, room: int) -> void:
	var kept: Array[Dictionary] = []
	for door in plan.doors:
		var attached := room < 0 or int(door.get("a", -1)) == room \
			or int(door.get("b", -1)) == room
		var normal: Vector2 = door.get("normal", Vector2.ZERO)
		var pos: Vector2 = door.get("pos", Vector2.ZERO)
		var outside := pos + normal * (HouseGeometry.wall_thickness(plan.spec) + 0.05)
		var court: Rect2 = plan.world_meta["court_rect"]
		if attached and court.has_point(outside):
			continue
		kept.append(door)
	plan.doors = kept
