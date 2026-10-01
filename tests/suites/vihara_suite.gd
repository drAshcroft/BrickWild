class_name ViharaSuite
extends RefCounted
## WLD-018: Monks' Cloister dimensions, court and rule-specific controls.


static func run() -> SuiteResult:
	var res := SuiteResult.new("vihara")
	var request := BuildingRequest.new()
	request.kind = &"world"
	request.style = &"vihara"
	request.purpose = &"monks_cloister"
	request.seed = 18018
	request.width = 50.0
	request.length = 40.0
	request.height = 5.0
	var building: GeneratedBuilding = BigGlade.generate(request)
	res.checked += 1
	if building == null or not building.is_ok():
		res.fail("Monks' Cloister 50 x 40 x 5 did not generate: %s" %
			(str(building.errors) if building != null else "null"))
		return res
	if building.spec.variant_name != "Monks' Cloister" \
			or absf(building.spec.width - 50.0) > 0.01 \
			or absf(building.spec.length - 40.0) > 0.01 \
			or absf(building.spec.height - 5.0) > 0.01:
		res.fail("Monks' Cloister does not retain its canonical dimensions and name")
	var builder := HouseBuilder.new()
	var mesh := builder.build(building.plan)
	if mesh == null:
		res.fail("Monks' Cloister has no emitted shell")
	for failure in ViharaCheck.new().check(building.plan, builder).get("failures", []):
		res.fail("Monks' Cloister: %s" % str(failure))
	_negative_fixtures(res)
	return res


static func _fixture_plan(seed: int) -> HousePlan:
	return ViharaGenerator.generate(seed, 50.0, 40.0, 5.0)["plan"]


static func _expect(res: SuiteResult, label: String, prefix: String,
		plan: HousePlan, builder: HouseBuilder = null) -> void:
	res.checked += 1
	var report := ViharaCheck.new().check(plan, builder)
	for failure in report.get("failures", []):
		if String(failure).begins_with(prefix + ":"):
			return
	res.fail("negative vihara fixture %s did not fail %s" % [label, prefix])


static func _negative_fixtures(res: SuiteResult) -> void:
	var small_cell := _fixture_plan(18019)
	for room in range(small_cell.room_count()):
		if small_cell.kind_of(room) == &"cell":
			var rect: Rect2 = small_cell.rooms[room]["rect"]
			small_cell.rooms[room]["rect"] = Rect2(rect.position, Vector2(2.4, 2.4))
			break
	_expect(res, "undersized cell", "cell_size", small_cell)

	var varied_width := _fixture_plan(18020)
	for room in range(varied_width.room_count()):
		if varied_width.kind_of(room) == &"cell":
			var rect: Rect2 = varied_width.rooms[room]["rect"]
			varied_width.rooms[room]["rect"] = Rect2(rect.position, Vector2(3.2, 3.2))
			break
	_expect(res, "inconsistent cell module", "cell_width", varied_width)

	var no_cell_door := _fixture_plan(18021)
	var cell := _first_cell(no_cell_door)
	no_cell_door.doors = no_cell_door.doors.filter(
		func(door: Dictionary) -> bool:
			return not (String(door.get("role", "")) == "cell_verandah_door"
				and int(door.get("a", -1)) == cell))
	_expect(res, "cell without its verandah door", "cell_door", no_cell_door)

	var duplicate_cell_door := _fixture_plan(18029)
	var duplicate_cell := _first_cell(duplicate_cell_door)
	var repeated: Dictionary = {}
	for door in duplicate_cell_door.doors:
		if String(door.get("role", "")) == "cell_verandah_door" \
				and int(door.get("a", -1)) == duplicate_cell:
			repeated = door.duplicate(true)
			break
	duplicate_cell_door.doors.append(repeated)
	_expect(res, "cell with a second verandah door", "cell_door", duplicate_cell_door)

	var windowed_cell := _fixture_plan(18022)
	windowed_cell.windows.append({"room": _first_cell(windowed_cell),
		"pos": Vector2.ZERO, "normal": Vector2(0, 1), "width": 0.6,
		"sill": 0.8, "head": 1.8, "storey": 0})
	_expect(res, "window in a cell", "cell_window", windowed_cell)

	var broken_verandah := _fixture_plan(18023)
	for room in broken_verandah.rooms:
		if String(room.get("role", "")) == "verandah_corner_front_west":
			var rect: Rect2 = room["rect"]
			rect.position.x += 0.5
			room["rect"] = rect
			break
	_expect(res, "verandah corner gap", "verandah_floor", broken_verandah)

	var off_axis := _fixture_plan(18024)
	var shrine := _shrine(off_axis)
	var shrine_rect: Rect2 = off_axis.rooms[shrine]["rect"]
	shrine_rect.position.x += 0.5
	off_axis.rooms[shrine]["rect"] = shrine_rect
	_expect(res, "off-axis shrine", "shrine_axis", off_axis)

	var reversed_door := _fixture_plan(18025)
	for door in reversed_door.doors:
		if String(door.get("role", "")) == "shrine_axis_door":
			door["normal"] = Vector2(0, 1)
			break
	_expect(res, "shrine door faces away", "shrine_door", reversed_door)

	var blocked_axis := _fixture_plan(18026)
	var court: Rect2 = blocked_axis.world_meta["court_rect"]
	var obstruction := Rect2(court.get_center() - Vector2.ONE * 0.7,
		Vector2.ONE * 1.4)
	blocked_axis.furniture.append({"key": "Statue", "room": -1,
		"pos": Vector3(court.get_center().x, 0.0, court.get_center().y),
		"rect": obstruction, "zone": Rect2(), "host": -1, "cat": "statue",
		"mounted": false, "yaw": 0.0, "storey": 0})
	_expect(res, "obstructed shrine axis", "shrine_sightline", blocked_axis)

	var off_center_well := _fixture_plan(18027)
	off_center_well.world_meta["water_pos"] += Vector2(2.0, 0.0)
	_expect(res, "off-center well", "well_center", off_center_well)

	var missing_well := _fixture_plan(18028)
	var no_well_builder := HouseBuilder.new()
	no_well_builder.build(missing_well)
	no_well_builder.mass_log = no_well_builder.mass_log.filter(
		func(mass: Dictionary) -> bool: return String(mass.get("name", "")) != "vihara_well")
	_expect(res, "well was not emitted", "well_emission", missing_well, no_well_builder)

	var filled_court := _fixture_plan(18030)
	var filled_center: Vector2 = filled_court.world_meta["court_rect"].get_center()
	filled_court.furniture.append({"key": "Statue", "room": -1,
		"pos": Vector3(filled_center.x, 0.0, filled_center.y),
		"rect": Rect2(filled_center - Vector2.ONE, Vector2.ONE * 2.0),
		"zone": Rect2(), "host": -1, "cat": "statue", "mounted": false,
		"yaw": 0.0, "storey": 0})
	_expect(res, "occupied open court", "sky", filled_court)

	var closed_court := _fixture_plan(18031)
	closed_court.doors = closed_court.doors.filter(
		func(door: Dictionary) -> bool: return not String(door.get("role", "")).begins_with("court_"))
	_expect(res, "court with no verandah thresholds", "ring", closed_court)

	var shaft_court := _fixture_plan(18032)
	shaft_court.world_meta["court_rect"] = Rect2(
		shaft_court.world_meta["court_rect"].get_center() - Vector2.ONE,
		Vector2.ONE * 2.0)
	shaft_court.courts[0]["rect"] = shaft_court.world_meta["court_rect"]
	_expect(res, "light-well court", "proportion", shaft_court)


static func _first_cell(plan: HousePlan) -> int:
	for room in range(plan.room_count()):
		if plan.kind_of(room) == &"cell":
			return room
	return -1


static func _shrine(plan: HousePlan) -> int:
	for room in range(plan.room_count()):
		if String(plan.rooms[room].get("role", "")) == "vihara_shrine":
			return room
	return -1
