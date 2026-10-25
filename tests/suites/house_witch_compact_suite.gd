extends RefCounted
## Fixed public-path regression for the Witch Hut Alchemist at its clamped size.
## WITCH-SIZE: a 7 x 9 m hut cannot hold the old side-Hall layout (a 3 m Hall
## beside a 3.3 m bedroom strip needs 6.4 m clear; the hut has 6.3), so the
## layout and its meal-group checks went with the 7.1 m hut they described.

const SEED := 21118

static func run() -> SuiteResult:
	var res := SuiteResult.new("Witch Alchemist hut")
	var request := BuildingRequest.house(SEED, &"witch_hut", &"alchemist", 9.5, 12.0, 2.7, 2)
	var generated: GeneratedBuilding = BrickWild.generate(request)
	_expect(res, generated.is_ok() and generated.plan != null,
		"public generation failed: %s" % JSON.stringify(generated.errors))
	if not generated.is_ok() or generated.plan == null:
		return res
	var plan: HousePlan = generated.plan
	_expect(res, plan.spec.width <= 7.001 and plan.spec.length <= 9.001 and plan.spec.storeys == 1,
		"alchemist hut is %.2f x %.2f m, %d storeys" % [plan.spec.width, plan.spec.length, plan.spec.storeys])
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
	var nav: Dictionary = HouseNavCheck.new().check(plan)
	_expect(res, bool(nav.get("ok", false)) and nav.get("unreached_rooms", []).is_empty()
		and nav.get("unreachable_items", []).is_empty(),
		"navigation failed: %s" % JSON.stringify(nav))
	var furnish: Dictionary = HouseFurnishCheck.new().check(plan)
	_expect(res, bool(furnish.get("ok", false)),
		"HouseFurnishCheck failed: %s" % JSON.stringify(furnish.get("failures", [])))
	res.note("rooms=3, nav=%s" % str(nav.get("ok", false)))
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
