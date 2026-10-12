extends RefCounted
## Fixed public-path regression for the compact Witch Hut Alchemist plan.

const SEED := 21118
const SCALE := 0.75

static func run() -> SuiteResult:
	var res := SuiteResult.new("Witch compact Alchemist")
	var request := BuildingRequest.house(SEED, &"witch_hut", &"alchemist",
		9.5 * SCALE, 12.0 * SCALE, 2.7, 1)
	var generated: GeneratedBuilding = BrickWild.generate(request)
	_expect(res, generated.is_ok() and generated.plan != null,
		"public generation failed: %s" % JSON.stringify(generated.errors))
	if not generated.is_ok() or generated.plan == null:
		return res
	var plan: HousePlan = generated.plan
	_expect(res, bool(plan.domestic_layout.get("witch_alchemist_side_hall", false)),
		"compact side-Hall planner selection missing")

	var hall := _room_of(plan, &"hall")
	var workshop := _room_of(plan, &"workshop")
	var bedroom := _room_of(plan, &"bedroom")
	_expect(res, hall >= 0 and workshop >= 0 and bedroom >= 0 and plan.room_count() == 3,
		"expected exactly Hall, Workshop and Bedroom; got %s" % [_room_summary(plan)])
	if hall < 0 or workshop < 0 or bedroom < 0 or plan.room_count() != 3:
		return res
	for room in [hall, workshop, bedroom]:
		var kind: StringName = plan.kind_of(room)
		_expect(res, HouseGeometry.room_suits(plan, room, kind)
			and HouseGeometry.room_aspect(plan, room) <= HouseGeometry.aspect_max(kind),
			"room %s fails measured fit/aspect contract" % String(kind))
	var functions: Array = plan.rooms[hall].get("domestic_functions", [])
	for role in [&"cooking", &"dining", &"common_living", &"circulation"]:
		_expect(res, functions.has(role), "Hall missing function %s" % String(role))
	_expect(res, _has_door(plan, hall, workshop), "Workshop has no direct Hall door")
	_expect(res, _has_door(plan, hall, bedroom), "Bedroom has no direct Hall door")
	_expect(res, _front_station_ok(plan, hall), "front entrance is not at partition-side Hall station")

	var cooking := {"hearth": false, "storage": false, "workbench": false, "bucket": false, "pot": false}
	var table_index := -1
	var table_count := 0
	var workshop_bench := false
	var bed := false
	for i in range(plan.furniture.size()):
		var piece: Dictionary = plan.furniture[i]
		var room := int(piece.get("room", -1))
		var category := String(piece.get("cat", ""))
		var group := String(piece.get("activity_group", ""))
		if room == hall and group == "cooking":
			if category in ["hearth", "storage", "workbench", "bucket"]:
				cooking[category] = true
			if String(piece.get("key", "")) == "Pot_1":
				var host := int(piece.get("host", -1))
				if host >= 0 and host < plan.furniture.size():
					var host_piece: Dictionary = plan.furniture[host]
					cooking["pot"] = String(host_piece.get("cat", "")) == "workbench" \
						and int(host_piece.get("room", -1)) == hall
		if room == hall and group == "eating" and category == "table" \
				and String(piece.get("key", "")) == "Table_Large":
			table_count += 1
			table_index = i
		if room == workshop and category == "workbench":
			workshop_bench = true
		if room == bedroom and category == "bed" and group == "sleep":
			bed = true
	for role in cooking:
		_expect(res, bool(cooking[role]), "Hall cooking role missing: %s" % role)
	var hosted_seats := 0
	for piece in plan.furniture:
		if int(piece.get("room", -1)) == hall \
				and String(piece.get("activity_group", "")) == "eating" \
				and String(piece.get("cat", "")) == "seat" \
				and int(piece.get("host", -1)) == table_index:
			hosted_seats += 1
	_expect(res, table_count == 1 and hosted_seats >= 2,
		"meal group requires one Table_Large and two hosted seats; got %d/%d" % [table_count, hosted_seats])
	_expect(res, workshop_bench, "Workshop bench missing")
	_expect(res, bed, "Bedroom sleep bed missing")

	var nav: Dictionary = HouseNavCheck.new().check(plan)
	_expect(res, bool(nav.get("ok", false)) and nav.get("unreached_rooms", []).is_empty()
		and nav.get("unreachable_items", []).is_empty()
		and float(nav.get("stats", {}).get("stranded_area", INF)) <= 0.001,
		"navigation failed: %s" % JSON.stringify(nav))
	var furnish: Dictionary = HouseFurnishCheck.new().check(plan)
	_expect(res, bool(furnish.get("ok", false)),
		"HouseFurnishCheck failed: %s" % JSON.stringify(furnish.get("failures", [])))
	res.note("seed=%d scale=%.2f; rooms=3, cooking roles=5, table/seats=%d/%d, nav=%s, furnishing=%s" % [
		SEED, SCALE, table_count, hosted_seats, str(nav.get("ok", false)), str(furnish.get("ok", false))])
	return res

static func _expect(res: SuiteResult, condition: bool, message: String) -> void:
	res.checked += 1
	if not condition:
		res.fail(message)

static func _room_of(plan: HousePlan, kind: StringName) -> int:
	var rows := plan.rooms_of(kind)
	return int(rows[0]) if not rows.is_empty() else -1

static func _room_summary(plan: HousePlan) -> Array[String]:
	var out: Array[String] = []
	for i in range(plan.room_count()):
		out.append(String(plan.kind_of(i)))
	return out

static func _has_door(plan: HousePlan, a: int, b: int) -> bool:
	for door in plan.doors:
		if bool(door.get("exterior", false)):
			continue
		if (int(door.get("a", -1)) == a and int(door.get("b", -1)) == b) \
				or (int(door.get("a", -1)) == b and int(door.get("b", -1)) == a):
			return true
	return false

static func _front_station_ok(plan: HousePlan, hall: int) -> bool:
	var entrance := plan.entrance()
	if entrance < 0:
		return false
	var door: Dictionary = plan.doors[entrance]
	if not bool(door.get("front", false)) or int(door.get("a", -1)) != hall:
		return false
	var rect: Rect2 = plan.rooms[hall].get("rect", Rect2())
	var expected := rect.end.x - HouseGeometry.DOOR_CORNER_MARGIN - float(door.get("width", 0.0)) * 0.5
	return absf(Vector2(door.get("pos", Vector2.ZERO)).x - expected) <= 0.01

