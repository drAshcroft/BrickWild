extends SceneTree
## Generated proof for safe mirrored-pair search and honest optional fallback.
## Run after the staged HouseFurnishSurface change is promoted.

const RICH_SEED := 60005
const PUEBLO_SEED := 60011
var failures: Array[String] = []

func _initialize() -> void:
	_check_rich_pair()
	_check_pueblo_single_fallback()
	_check_checker_negative()
	for failure in failures:
		push_error(failure)
	print("sconce pair fixture: 2 generated cases, %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _generated(seed_value: int) -> HousePlan:
	var n: int = seed_value - 60000
	var styles: Array = HouseSweep.styles()
	var trades: Array = HouseSweep.trades()
	var spec := HouseSpec.new()
	spec.style = styles[n % styles.size()]
	spec.trade = trades[n % trades.size()]
	spec.width = 6.0 + float(n % 5) * 2.0
	spec.length = 7.0 + float(n % 7) * 1.8
	spec.storeys = 1 + (n % 2)
	return HouseGenerator.generate(spec, seed_value)


func _hall_one(plan: HousePlan, seed_value: int) -> int:
	for candidate in plan.rooms_of(&"hall"):
		if candidate == 1:
			return candidate
	failures.append("seed %d has no hall 1" % seed_value)
	return -1


func _sconces(plan: HousePlan, room: int) -> Array[int]:
	var lamps: Array[int] = []
	for index in plan.furniture_of(room):
		if PropCatalog.category(String(plan.furniture[index]["key"])) == "sconce":
			lamps.append(index)
	return lamps


func _check_rich_pair() -> void:
	var plan := _generated(RICH_SEED)
	var room := _hall_one(plan, RICH_SEED)
	if room < 0:
		return
	var lamps := _sconces(plan, room)
	if lamps.size() != 2:
		failures.append("rich seed has %d sconces; expected its valid pair" % lamps.size())
		return
	if plan.compromises.get(room, []).has("sconce_pair:no_safe_mirrored_station"):
		failures.append("rich safe pair was incorrectly marked unavailable")
	var tally: Dictionary = {}
	HouseQASuite._aff_sconces(plan, room, tally)
	var result: Array = tally.get("sconce_pair", [0, 0])
	if int(result[0]) != 1 or int(result[1]) != 1:
		failures.append("rich seed's two lamps are not a valid mirrored pair")


func _check_pueblo_single_fallback() -> void:
	var plan := _generated(PUEBLO_SEED)
	var room := _hall_one(plan, PUEBLO_SEED)
	if room < 0:
		return
	var lamps := _sconces(plan, room)
	if lamps.size() != 1:
		failures.append("pueblo seed has %d hall lamps; expected one useful lamp after safe-pair exhaustion" % lamps.size())
		return
	if not plan.compromises.get(room, []).has("sconce_pair:no_safe_mirrored_station"):
		failures.append("pueblo seed omitted the optional mate without recording why")
	var lamp: Dictionary = plan.furniture[lamps[0]]
	var centre := Rect2(lamp["rect"]).get_center()
	var local_y := float(lamp["pos"].y) - HouseFurnishGeometry.storey_base(plan, room)
	if HouseFurnishSurface._blocks_domestic_threshold(plan, room, String(lamp["key"]),
			centre, float(lamp["yaw"]), local_y, float(lamp.get("scale", 1.0))):
		failures.append("pueblo fallback lamp collides with a door or stair route")
	# Independently remove the actual lamp and ask the physical paired-anchor
	# search whether any candidate exists. The fallback flag alone is not proof.
	var probe: HousePlan = HouseFurnisher._meal_probe_plan(plan)
	probe.furniture = plan.furniture.duplicate(true)
	probe.furniture.remove_at(lamps[0])
	var predicate: Callable = func(target: Vector2, normal: Vector2) -> bool:
		return not HouseFurnishSurface._blocks_domestic_threshold(probe, room,
			String(lamp["key"]), target, HouseFurnishGeometry.yaw_facing(normal),
			local_y, float(lamp.get("scale", 1.0)))
	var anchor: Dictionary = HouseFurnishScore._flank_anchor(probe, room,
		HouseFurnishScore._widest_of("sconce"), "sconce", predicate)
	if not anchor.is_empty():
		failures.append("pueblo negative premise failed: safe mirrored station exists: %s" % str(anchor))


func _check_checker_negative() -> void:
	var result := SuiteResult.new("sconce pair negative control")
	HouseQASuite._fs_sconce_pair(result)
	if not result.failures.is_empty():
		failures.append("existing perpendicular-wall negative control no longer proves the checker: %s"
			% str(result.failures))
