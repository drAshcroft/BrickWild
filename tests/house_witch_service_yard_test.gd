extends SceneTree
## Focused service-yard contract for the frozen Witch request geometry.
## The yard must be planned around the authored door; role presence alone is not enough.

const SIZES := [
	{"id":"compact","width":7.0,"length":9.0,"height":2.6,"bay":false},
	{"id":"default","width":9.0,"length":12.0,"height":2.6,"bay":true},
	{"id":"large","width":17.0,"length":18.0,"height":2.8,"bay":true},
]
const SEEDS := [1, 8102, 21325]
var failures: Array[String] = []

func _init() -> void:
	for size in SIZES:
		for seed_value in SEEDS:
			_check_witch(size, seed_value)
	for size in SIZES:
		_check_excluded_controls(size)
	for failure in failures:
		printerr("FAIL " + failure)
	print("Witch service-yard threshold contract: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)

func _check_witch(size: Dictionary, seed_value: int) -> void:
	var spec := HouseSpec.new(seed_value)
	spec.style = &"witch_hut"
	spec.trade = &"none"
	spec.width = float(size.width)
	spec.length = float(size.length)
	spec.height = float(size.height)
	spec.storeys = 1
	spec.cellars = 0
	var plan := HouseGenerator.generate(spec, seed_value, true)
	var label := "%s seed=%d" % [size.id, seed_value]
	var door: Dictionary = {}
	for candidate in plan.doors:
		if bool(candidate.get("witch_workshop_yard", false)):
			door = candidate
			break
	if door.is_empty():
		failures.append("%s lost the authored Witch service threshold" % label)
		return
	var compact := bool(door.get("witch_compact_service_threshold", false))
	if compact != (size.id == "compact"):
		failures.append("%s service threshold used the wrong compact/Workshop grammar" % label)
	var bay: Dictionary = HouseGeometry.roof_layout(plan).get("witch_bay", {})
	if bool(size.bay) != not bay.is_empty():
		failures.append("%s changed the separate structural Workshop bay eligibility" % label)
	var shelter: Dictionary = {}
	for piece in plan.yard_pieces:
		if String(piece.get("role", "")) == "witch_work_shelter":
			shelter = piece
			break
	if shelter.is_empty():
		failures.append("%s omitted the required work shelter at the authored threshold; omissions=%s" % [label, str(plan.exterior_omissions)])
		return
	var group := String(shelter.get("group", ""))
	var shelter_rect := Rect2(shelter.get("rect", Rect2()))
	var body: Vector2 = Vector2(door["pos"]) + Vector2(door["normal"]) * \
		(HouseGeometry.wall_thickness(spec) + HouseGeometry.PERSON_RADIUS + 0.05)
	if not shelter_rect.grow(0.05).has_point(body):
		failures.append("%s shelter does not cover the exterior body datum at the real door" % label)
	var roof_bounds := AABB()
	var found_roof := false
	for part in shelter.get("parts", []):
		var part_bounds: AABB = HouseYard.part_aabb(part)
		var part_reason := HouseYard.clear_reason(plan, HouseGeometry.yard_rect(plan), part_bounds)
		if not part_reason.is_empty():
			failures.append("%s shelter part %s violates the unchanged facade reservation: %s" % [
				label, String(part.get("role", "?")), part_reason])
		if String(part.get("role", "")) == "witch_shelter_roof":
			roof_bounds = part_bounds
			found_roof = true
	if not found_roof:
		failures.append("%s shelter has no measured roof part" % label)
	elif roof_bounds.position.y < HouseGeometry.DOOR_H + 0.25 - 0.005:
		failures.append("%s shelter roof AABB enters the reserved door/window head zone (bottom %.3f m)" % [
			label, roof_bounds.position.y])
	var roles: Array[String] = []
	for prop in plan.yard:
		if String(prop.get("group", "")) == group:
			roles.append(String(prop.get("role", "")))
			var prop_reason := HouseYard.clear_reason(plan, HouseGeometry.yard_rect(plan),
				HouseExterior.bounds_of(prop))
			if not prop_reason.is_empty():
				failures.append("%s measured work prop %s violates the unchanged facade reservation: %s" % [
					label, String(prop.get("role", "?")), prop_reason])
	for role in ["witch_prep_bench", "witch_brewing_heat", "witch_cookware", "witch_water_vessel"]:
		if role not in roles:
			failures.append("%s threshold shelter lacks measured work role %s" % [label, role])
	if not _near_service_group(plan, door, "herb_bed", 5.0):
		failures.append("%s has no herb bed within 5 m of the service threshold" % label)
	if not _near_service_group(plan, door, "drying_line", 5.0):
		failures.append("%s has no drying line within 5 m of the service threshold" % label)
	if not HouseYard.access_ok(plan):
		failures.append("%s work shelter/ingredients block a body-width route to the house" % label)

func _near_service_group(plan: HousePlan, door: Dictionary, prefix: String, max_distance: float) -> bool:
	var point: Vector2 = door["pos"]
	for piece in plan.yard_pieces:
		var group := String(piece.get("group", ""))
		var role := String(piece.get("role", ""))
		if role != prefix and not group.begins_with(prefix + "#"):
			continue
		var rect := Rect2(piece.get("rect", Rect2()))
		if _point_rect_distance(point, rect) <= max_distance:
			return true
	for prop in plan.yard:
		var group := String(prop.get("group", ""))
		var role := String(prop.get("role", ""))
		if role != prefix and not group.begins_with(prefix + "#"):
			continue
		var bounds: AABB = HouseExterior.bounds_of(prop)
		var rect := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
		if _point_rect_distance(point, rect) <= max_distance:
			return true
	return false

func _point_rect_distance(point: Vector2, rect: Rect2) -> float:
	var closest := Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
	return point.distance_to(closest)

func _check_excluded_controls(size: Dictionary) -> void:
	for control in [{"style":&"cottage","trade":&"none"},{"style":&"witch_hut","trade":&"alchemist"}]:
		var spec := HouseSpec.new(8102)
		spec.style = control.style
		spec.trade = control.trade
		spec.width = float(size.width)
		spec.length = float(size.length)
		var plan := HouseGenerator.generate(spec, 8102, true)
		for piece in plan.yard_pieces:
			if String(piece.get("role", "")) == "witch_work_shelter":
				failures.append("%s/%s inherited the no-trade Witch threshold shelter" % [size.id, str(control.style)])
