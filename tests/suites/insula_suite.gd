class_name InsulaSuite
extends RefCounted
## WLD-002 focused tests: four scale probes and one broken plan per rule.

const SCALES: Array[float] = [0.7, 1.0, 1.4, 1.9]


static func run() -> SuiteResult:
	var res := SuiteResult.new("world insula")
	for scale in SCALES:
		var request := _request(scale, 9200 + int(scale * 100.0))
		var building: GeneratedBuilding = BrickWild.generate(request)
		var who := "port_tenement scale=%.2f" % scale
		res.checked += 1
		if building == null or not building.is_ok():
			res.fail("%s: generation failed: %s" % [who,
				str(building.errors) if building != null else "null"])
			continue
		var plan: HousePlan = building.plan
		var builder := HouseBuilder.new()
		var mesh := builder.build(plan)
		if mesh == null:
			res.fail("%s: no emitted house mesh" % who)
		for failure in InsulaCheck.new().check(plan)["failures"]:
			res.fail("%s: %s" % [who, str(failure)])
		for failure2 in HousePlanCheck.new().check(plan)["failures"]:
			res.fail("%s: %s" % [who, str(failure2)])
		for failure3 in HouseNavCheck.new().check(plan)["failures"]:
			res.fail("%s: %s" % [who, str(failure3)])
		if int(plan.world_meta.get("flat_count", -1)) != 6:
			res.fail("%s: generator did not retain six-flat identity" % who)
	_fixtures(res)
	return res


static func _request(scale: float, seed: int) -> BuildingRequest:
	var request := BuildingRequest.new()
	request.kind = &"world"
	request.style = &"insula"
	request.purpose = &"port_tenement"
	request.seed = seed
	request.width = _bounded(30.0, scale, 20.0, 45.0)
	request.length = _bounded(20.0, scale, 18.0, 38.0)
	request.height = 18.0
	return request


static func _bounded(base: float, scale: float, low: float, high: float) -> float:
	if scale <= 1.0:
		return clampf(base * scale, low, high)
	var eased := lerpf(base, high, clampf((scale - 1.0) / 0.9, 0.0, 1.0))
	return clampf(minf(base * scale, eased), low, high)


static func _fixture_plan() -> HousePlan:
	return InsulaGenerator.generate(9301, 30.0, 20.0, 18.0)["plan"]


static func _expect(res: SuiteResult, label: String, plan: HousePlan, prefix: String) -> void:
	res.checked += 1
	var report := InsulaCheck.new().check(plan)
	for failure in report["failures"]:
		if String(failure).begins_with(prefix + ":"):
			return
	res.fail("negative insula fixture %s did not fail %s" % [label, prefix])


static func _fixtures(res: SuiteResult) -> void:
	var cap := _fixture_plan()
	cap.spec.height = 5.0
	_expect(res, "over-cap", cap, "cap")

	var pavement := _fixture_plan()
	for door in pavement.doors:
		if String(door.get("role", "")) == "taberna":
			door["width"] = 1.0
			break
	_expect(res, "narrow-taberna", pavement, "pavement")

	var privacy := _fixture_plan()
	privacy.rooms[1]["kind"] = &"bedroom"
	privacy.windows.append({"room": 1, "pos": Vector2(privacy.rooms[1]["rect"].get_center().x,
		HouseGeometry.interior_rect(privacy.spec).position.y), "normal": Vector2(0, -1),
		"width": 0.8, "sill": 0.7, "head": 1.8, "storey": 0, "role": "privacy_fault"})
	_expect(res, "ground-privacy", privacy, "pavement")

	var stair := _fixture_plan()
	stair.stairs.remove_at(0)
	_expect(res, "missing-stair-flight", stair, "stair")

	var flat := _fixture_plan()
	var medianum := -1
	for i in range(flat.rooms.size()):
		if String(flat.rooms[i].get("role", "")) == "medianum":
			medianum = i
			break
	if medianum >= 0:
		for wi in flat.windows_of(medianum):
			flat.windows[wi]["role"] = "removed_court_window"
			break
	_expect(res, "medianum-window-count", flat, "flat")

	var no_medianum := _fixture_plan()
	for room in no_medianum.rooms:
		if String(room.get("role", "")) == "medianum":
			room["role"] = "parlour_without_medianum"
			break
	_expect(res, "missing-medianum", no_medianum, "flat")

	var no_medianum_door := _fixture_plan()
	var unit_room := -1
	var target_medianum := -1
	for i3 in range(no_medianum_door.rooms.size()):
		var candidate: Dictionary = no_medianum_door.rooms[i3]
		if String(candidate.get("role", "")) == "cubiculum_front":
			unit_room = i3
			break
	if unit_room >= 0:
		var unit_id := String(no_medianum_door.rooms[unit_room].get("unit", ""))
		for j in range(no_medianum_door.rooms.size()):
			if String(no_medianum_door.rooms[j].get("unit", "")) == unit_id \
					and String(no_medianum_door.rooms[j].get("role", "")) == "medianum":
				target_medianum = j
				break
		var kept: Array[Dictionary] = []
		for door in no_medianum_door.doors:
			if (int(door.get("a", -1)) == unit_room and int(door.get("b", -1)) == target_medianum) \
					or (int(door.get("b", -1)) == unit_room and int(door.get("a", -1)) == target_medianum):
				continue
			kept.append(door)
		no_medianum_door.doors = kept
	_expect(res, "missing-medianum-door", no_medianum_door, "flat")

	var outward_window := _fixture_plan()
	for win in outward_window.windows:
		if String(win.get("role", "")) == "court_daylight":
			win["normal"] = -Vector2(win["normal"])
			break
	_expect(res, "window-not-facing-court", outward_window, "flat")

	var daylight := _fixture_plan()
	var dark_room := -1
	for i2 in range(daylight.rooms.size()):
		if String(daylight.rooms[i2].get("role", "")) == "cubiculum_front":
			dark_room = i2
			break
	for wi2 in range(daylight.windows.size() - 1, -1, -1):
		if int(daylight.windows[wi2].get("room", -1)) == dark_room:
			daylight.windows.remove_at(wi2)
	_expect(res, "dark-room", daylight, "daylight")
