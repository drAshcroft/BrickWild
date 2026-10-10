extends SceneTree
## Draft acceptance fixture for a reachable, plan-owned hearth tending patch.
## Apply only with the companion candidate.patch, then run as a focused test.

class CustomHouseSpec extends HouseSpec:
	func custom_room_rects(_inner: Rect2) -> Array[Rect2]:
		return []

var failures: Array[String] = []
var checks := 0
const CASES: Array[Dictionary] = [
	{"name": "small", "width": 7.0, "length": 9.0, "height": 2.6},
	{"name": "default", "width": 9.0, "length": 12.0, "height": 2.6},
	{"name": "large", "width": 17.0, "length": 18.0, "height": 2.8},
	{"name": "original_11x14", "width": 11.0, "length": 14.0, "height": 2.6},
]
const STYLES: Array[StringName] = [&"cottage", &"farmhouse", &"thatch_cottage"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for style in STYLES:
		for size in CASES:
			_check_ordinary(style, size)
	_check_exclusions()
	for failure in failures:
		push_error(failure)
	print("Domestic hearth tending draft: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)

func _check_ordinary(style: StringName, size: Dictionary) -> void:
	var spec := HouseSpec.new(7441)
	spec.style = style
	spec.width = float(size["width"])
	spec.length = float(size["length"])
	spec.height = float(size["height"])
	var plan := HouseGenerator.generate(spec, spec.seed, true)
	var where := "%s/%s seed=%d" % [String(style), String(size["name"]), spec.seed]
	var before_refurnish := _tending_count(plan)
	HouseFurnisher.furnish(plan, spec)
	_expect(before_refurnish == 1 and _tending_count(plan) == 1,
		where + ": repeat furnishing duplicated or lost the tending zone")
	var tending: Array[Dictionary] = []
	for zone: Dictionary in plan.zones:
		if String(zone.get("why", "")) == "hearth tending":
			tending.append(zone)
	_expect(tending.size() == 1, where + ": expected one plan-owned tending patch")
	if tending.size() != 1:
		return
	var zone: Dictionary = tending[0]
	var room := int(zone.get("room", -1))
	var patch := Rect2(zone["rect"])
	_expect(room >= 0 and room < plan.rooms.size() and plan.storey_of_room(room) == 0,
		where + ": tending patch is not on the hearth room floor")
	if room >= 0 and room < plan.rooms.size():
		var outline: PackedVector2Array = plan.outline_of(room)
		for corner in [patch.position, Vector2(patch.end.x, patch.position.y), patch.end,
			Vector2(patch.position.x, patch.end.y)]:
			_expect(Geometry2D.is_point_in_polygon(corner, outline),
				where + ": tending patch corner falls outside its room")
		for furniture: Dictionary in plan.furniture:
			if int(furniture.get("room", -1)) != room:
				continue
			var body := Rect2(furniture.get("rect", Rect2()))
			_expect(not patch.intersects(body, true), where + ": tending patch overlaps furniture body")
	var workbenches := 0
	var pots := 0
	for i in plan.furniture.size():
		var row: Dictionary = plan.furniture[i]
		if String(row.get("cat", "")) == "workbench" and int(row.get("room", -1)) == room:
			workbenches += 1
		if String(row.get("key", "")) == "Pot_1":
			pots += 1
			var host := int(row.get("host", -1))
			_expect(host >= 0 and host < plan.furniture.size()
				and String(plan.furniture[host].get("cat", "")) == "workbench"
				and int(plan.furniture[host].get("room", -1)) == int(row.get("room", -2)),
				where + ": required Pot_1 is not hosted on its room Workbench")
	_expect(workbenches >= 1, where + ": required Workbench was lost")
	_expect(pots == 1, where + ": expected exactly one hosted Pot_1")
	# The one furniture Pot_1 remains hosted on the Workbench. Hearth cookware
	# is a separate plan.hearth role, not a duplicate furniture row or count.
	var hearth_vessel: Dictionary = plan.hearth.get("cooking_vessel", {})
	_expect(String(hearth_vessel.get("key", "")) == "Pot_1"
		and String(hearth_vessel.get("purpose", "")) == "hearth_cooking"
		and String(hearth_vessel.get("host", "")) == "ordinary_fireplace"
		and String(hearth_vessel.get("support", "")) == "iron_tripod",
		where + ": missing explicit plan-owned fireplace vessel/support role")
	var nav: Dictionary = HouseNavCheck.new().check(plan)
	_expect(bool(nav.get("ok", false)),
		where + ": nav/tending patch failed: %s" % [str(nav.get("failures", []))])

func _check_exclusions() -> void:
	var witch := HouseSpec.new(7441)
	witch.style = &"witch_hut"
	var trade := HouseSpec.new(7441)
	trade.style = &"farmhouse"
	trade.trade = &"smith"
	var world := HouseSpec.new(7441)
	world.style = &"farmhouse"
	var shop := ShopSpec.new(7441)
	shop.style = &"farmhouse"
	var townhouse := HouseSpec.new(7441)
	townhouse.style = &"townhouse"
	var custom := CustomHouseSpec.new(7441)
	custom.style = &"cottage"
	var controls: Array[Dictionary] = [
		{"name": "Witch", "spec": witch, "world": &""},
		{"name": "trade", "spec": trade, "world": &""},
		{"name": "world", "spec": world, "world": &"domus"},
		{"name": "ShopSpec", "spec": shop, "world": &""},
		{"name": "out-of-scope ordinary style", "spec": townhouse, "world": &""},
		{"name": "custom HouseSpec", "spec": custom, "world": &""},
	]
	for control: Dictionary in controls:
		# The feature reserves its zone in HouseFurnisher after identifying the
		# native host. Generate with furniture so every scope control exercises
		# the same production path as an accepted domestic case.
		var plan: HousePlan = HouseGenerator.generate(control["spec"], 7441, true,
			StringName(control["world"]))
		var out_of_scope_vessel: Dictionary = plan.hearth.get("cooking_vessel", {})
		_expect(out_of_scope_vessel.is_empty(),
			"out-of-scope fireplace vessel record added for %s" % [control["name"]])
		for zone: Dictionary in plan.zones:
			_expect(String(zone.get("why", "")) != "hearth tending",
				"out-of-scope hearth tending zone added for %s" % [control["name"]])

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _tending_count(plan: HousePlan) -> int:
	var count := 0
	for zone: Dictionary in plan.zones:
		if String(zone.get("why", "")) == "hearth tending":
			count += 1
	return count
