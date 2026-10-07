extends SceneTree
## Focused production-helper contract for the upper flight in a generated
## three-storey dwelling. The blocker is a measured Cabinet on the reserved
## route between the real arrival and departure landings.

var failures: Array[String] = []


func _init() -> void:
	var spec := HouseSpec.new()
	spec.style = &"townhouse"
	spec.width = 9.0
	spec.length = 12.0
	spec.storeys = 3
	var plan := HouseGenerator.generate(spec, 9302, false)
	HouseFurnisher.furnish(plan, spec)
	if plan.stairs.size() < 2:
		failures.append("generated three-storey fixture has fewer than two flights")
		_finish()
		return
	var previous: Dictionary = plan.stairs[0]
	var target: Dictionary = plan.stairs[1]
	if not bool(previous.get("satisfied", false)) or not bool(target.get("satisfied", false)):
		failures.append("generated three-storey fixture has an unsatisfied flight")
		_finish()
		return
	if int(previous.get("to_storey", -1)) != int(target.get("storey", -2)) \
			or int(previous.get("b", -1)) != int(target.get("a", -2)):
		failures.append("fixture flights do not connect through the same middle hall")
		_finish()
		return
	var clear: Array[String] = []
	HouseStairCheck._approach(plan, 1, target, clear)
	if not clear.is_empty():
		failures.append("generated upper-flight route is blocked before damage: %s" % "; ".join(clear))
		_finish()
		return
	if not _block_reserved_route(plan, target):
		failures.append("measured Cabinet on the upper route did not block arrival-to-foot access")
	_finish()


func _block_reserved_route(plan: HousePlan, stair: Dictionary) -> bool:
	var room := int(stair["a"])
	var storey := int(stair["storey"])
	var floor := HouseGeometry.room_floor_rect(plan, room)
	var routes: Array[Rect2] = []
	for zone in plan.zones:
		if int(zone.get("room", -1)) == room \
				and String(zone.get("why", "")) == "stair access route":
			routes.append(Rect2(zone.get("rect", Rect2())))
	if routes.is_empty():
		return false
	for route in routes:
		# Present the Cabinet's long side across the route's narrow axis.
		var yaw := PI / 2.0 if route.size.x >= route.size.y else 0.0
		var footprint := PropCatalog.footprint_rotated("Cabinet", yaw)
		var centre := route.get_center()
		var rect := Rect2(centre - footprint * 0.5, footprint)
		if not floor.grow(0.01).encloses(rect):
			continue
		var piece := HouseFurnishGeometry.candidate("Cabinet", centre, yaw)
		piece["room"] = room
		piece["storey"] = storey
		var pos: Vector3 = piece["pos"]
		pos.y = float(storey) * plan.spec.height + HouseGeometry.FLOOR_T
		piece["pos"] = pos
		plan.furniture.append(piece)
		var blocked: Array[String] = []
		HouseStairCheck._approach(plan, 1, stair, blocked)
		plan.furniture.pop_back()
		if _has_approach_failure(blocked):
			return true
	return false


func _has_approach_failure(messages: Array[String]) -> bool:
	for message in messages:
		if message.begins_with("stair_approach:"):
			return true
	return false


func _finish() -> void:
	for failure in failures:
		printerr("FAIL ", failure)
	print("upper flight approach: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)
