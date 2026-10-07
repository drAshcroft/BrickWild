extends SceneTree
## Replays the three ordinary-house daylight failures and the multistorey
## longhall regression from the house furnish gate. Run from the repository:
## Godot --headless --path . --script res://artifacts/personality/daylight_wip/fixtures/daylight_pair_test.gd

const FENG_CASES := [
	{"n": 6, "style": &"mediterranean", "trade": &"none"},
	{"n": 9, "style": &"thatch_cottage", "trade": &"farmer"},
	{"n": 11, "style": &"pueblo", "trade": &"scholar"},
]
const LONGHALL_CASE := {"style": &"longhall", "trade": &"smith", "w": 11.0,
	"l": 14.0, "h": 2.7, "storeys": 3, "seed": 32103}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	for row in FENG_CASES:
		var n: int = int(row["n"])
		var spec := HouseSpec.new()
		spec.style = row["style"]
		spec.trade = row["trade"]
		spec.width = 6.0 + float(n % 5) * 2.0
		spec.length = 7.0 + float(n % 7) * 1.8
		spec.storeys = 1 + (n % 2)
		var plan: HousePlan = HouseGenerator.generate(spec, 60000 + n)
		_check_daylight(failures, plan, "feng seed %d %s" % [60000 + n, String(spec.style)])
		if n == 6:
			_check_dark_wall_negative(failures, plan)
	var long_spec := HouseSpec.new()
	long_spec.style = LONGHALL_CASE.style
	long_spec.trade = LONGHALL_CASE.trade
	long_spec.width = LONGHALL_CASE.w
	long_spec.length = LONGHALL_CASE.l
	long_spec.height = LONGHALL_CASE.h
	long_spec.storeys = LONGHALL_CASE.storeys
	var long_plan: HousePlan = HouseGenerator.generate(long_spec, LONGHALL_CASE.seed)
	_check_daylight(failures, long_plan, "multistorey longhall seed 32103")
	if failures.is_empty():
		print("PASS: all three feng shui reproductions and longhall workbench daylight")
		quit(0)
	for failure in failures:
		printerr(failure)
	quit(1)


func _check_daylight(failures: Array[String], plan: HousePlan, label: String) -> void:
	var kitchen := -1
	for room in range(plan.room_count()):
		if plan.kind_of(room) == &"kitchen":
			kitchen = room
			break
	if kitchen < 0:
		failures.append("%s: generated no kitchen, so the reported kitchen issue was not exercised" % label)
		return
	var kitchen_workbench_count := 0
	for piece in plan.furniture:
		if int(piece.get("room", -1)) == kitchen \
				and PropCatalog.category(String(piece["key"])) == "workbench":
			kitchen_workbench_count += 1
	if kitchen_workbench_count == 0:
		failures.append("%s: generated no kitchen workbench, so the daylight rule was not exercised" % label)
	var check := HouseFurnishAffinityCheck.new()
	check.check_workbench_daylight(plan)
	for failure in check.failures:
		if String(failure).begins_with("workbench_daylight:"):
			failures.append("%s: %s" % [label, String(failure)])


## Put one real kitchen bench on a measured blind wall where the source rule
## says a lit wall run is available. The same affinity checker must then fail.
func _check_dark_wall_negative(failures: Array[String], plan: HousePlan) -> void:
	var room := -1
	for index in range(plan.room_count()):
		if plan.kind_of(index) == &"kitchen":
			room = index
			break
	if room < 0:
		failures.append("dark-wall negative has no kitchen")
		return
	var furniture_index := -1
	for index in range(plan.furniture.size()):
		if int(plan.furniture[index].get("room", -1)) == room \
				and String(plan.furniture[index].get("cat", "")) == "workbench":
			furniture_index = index
			break
	if furniture_index < 0:
		failures.append("dark-wall negative has no actual kitchen workbench")
		return
	var original: Dictionary = plan.furniture[furniture_index].duplicate(true)
	var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
	var selected: Dictionary = {}
	var best_distance := -INF
	for wall in walls:
		var normal: Vector2 = wall["normal"]
		var yaw: float = HouseFurnishGeometry.yaw_facing(normal)
		var foot: Vector2 = PropCatalog.footprint_rotated(String(original["key"]), yaw) \
			* float(original.get("scale", 1.0))
		var along: Vector2 = (Vector2(wall["to"]) - Vector2(wall["from"])).normalized()
		var span: float = absf(along.x) * foot.x + absf(along.y) * foot.y
		if Vector2(wall["from"]).distance_to(Vector2(wall["to"])) < span + 0.1:
			continue
		var center := (Vector2(wall["from"]) + Vector2(wall["to"])) * 0.5 \
			+ normal * (foot.dot(normal.abs()) * 0.5 + HouseGeometry.WALL_GAP)
		var candidate := original.duplicate(true)
		candidate["yaw"] = yaw
		candidate["rect"] = Rect2(center - foot * 0.5, foot)
		var pos: Vector3 = candidate["pos"]
		pos.x = center.x
		pos.z = center.y
		candidate["pos"] = pos
		candidate["zone"] = HouseFurnishGeometry.zone_rect(String(candidate["key"]),
			Rect2(candidate["rect"]), yaw)
		if not HouseGeometry.room_floor_rect(plan, room).grow(0.01).encloses(
				Rect2(candidate["rect"])):
			continue
		var back_wall := HouseFurnishSpatialCheck.fs_back_wall(plan, room,
			Rect2(candidate["rect"]), candidate)
		if back_wall < 0 or HouseFurnishSpatialCheck.fs_wall_lit(plan, room, back_wall):
			continue
		var nearest := INF
		for window_index in plan.windows_of(room):
			nearest = minf(nearest, center.distance_to(Vector2(plan.windows[window_index]["pos"])))
		if nearest <= HouseFurnishAffinityCheck.FS_WINDOW_REACH \
				or not HouseFurnishAffinityCheck._lit_run_takes_bench(plan, room, candidate):
			continue
		var blocked: Array[Rect2] = []
		var zones: Array[Rect2] = []
		for other_index in range(plan.furniture.size()):
			if other_index == furniture_index:
				continue
			var other: Dictionary = plan.furniture[other_index]
			if int(other.get("room", -1)) != room:
				continue
			if PropCatalog.blocks_floor(String(other["key"])):
				blocked.append(Rect2(other["rect"]))
			var use_zone: Rect2 = Rect2(other.get("zone", Rect2()))
			if use_zone.has_area():
				zones.append(use_zone)
		if not HouseFurnishGeometry.fits(plan, room, candidate,
				HouseGeometry.room_floor_rect(plan, room), blocked, zones, []):
			continue
		if nearest > best_distance:
			best_distance = nearest
			selected = candidate
	if selected.is_empty():
		failures.append("dark-wall negative could not construct a measured eligible blind-wall pose")
		return
	plan.furniture[furniture_index] = selected
	var negative := HouseFurnishAffinityCheck.new()
	negative.check_workbench_daylight(plan)
	var rejected := false
	for message in negative.failures:
		if String(message).begins_with("workbench_daylight:"):
			rejected = true
	if not rejected:
		failures.append("real daylight checker accepted a bench on a dark, eligible wall")
	plan.furniture[furniture_index] = original
