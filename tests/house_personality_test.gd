extends SceneTree
## LIVE-ROOMS: purpose-led rectangular plans for ordinary house styles.
## Run: godot --headless --script res://tests/house_personality_test.gd

const LegacyPlacement = preload("res://src/house/house_furnish_placement.gd")

const STYLES := {
	&"cottage": &"parlour",
	&"farmhouse": &"workshop",
	&"townhouse": &"office",
	&"longhall": &"workshop",
	&"witch_hut": &"workshop",
}
const SCALES := [
	{"w": 7.0, "l": 9.0, "h": 2.6, "name": "small"},
	{"w": 9.0, "l": 12.0, "h": 2.6, "name": "default"},
	{"w": 17.0, "l": 18.0, "h": 2.8, "name": "large"},
]
const SEEDS := [1, 8102, 21325]

var failures: Array[String] = []

func _init() -> void:
	for style in STYLES:
		for scale in SCALES:
			for seed in SEEDS:
				_check_case({"style": style, "w": scale["w"], "l": scale["l"], "h": scale["h"],
					"seed": seed, "scale": scale["name"], "signature": STYLES[style]})
	_check_compact_shared_cooking()
	_check_narrow_corner_orientations()
	_check_trade_activity()
	_check_multistorey_routes()
	_check_farmhouse_privacy_regressions()
	_check_custom_family_path()
	_check_style_relationships()
	_check_negative_control()
	_check_determinism()
	for failure in failures:
		printerr("FAIL " + failure)
	print("house personality: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _check_case(row: Dictionary) -> void:
	var spec := _spec(row)
	var plan := HouseGenerator.generate(spec, int(row["seed"]), false)
	var who := "%s/%s seed=%d" % [row["style"], row["scale"], row["seed"]]
	if plan.domestic_layout.get("status", &"") != &"planned":
		failures.append("%s used fallback: %s" % [who, plan.domestic_layout.get("reason", "no provenance")])
		return
	if plan.domestic_layout.get("planned_rooms", 0) > plan.domestic_layout.get("requested_rooms", 0) \
			and not plan.domestic_layout.get("capacity_expanded", false):
		failures.append("%s planned more rooms than requested" % who)
	_check_tiling_and_shapes(plan, who)
	_check_activity_footprints(plan, who)
	_check_routes(plan, who)
	_check_entry_semantics(plan, who)
	var signature: StringName = row["signature"]
	if row["scale"] != "small" and not plan.has_kind(signature):
		failures.append("%s lost its signature activity %s: %s" % [who, signature, _room_kinds(plan)])
	if row["scale"] != "small" and plan.has_kind(&"kitchen"):
		var hall: int = plan.rooms_of(&"hall")[0]
		var kitchen: int = plan.rooms_of(&"kitchen")[0]
		if not _rooms_share_door(plan, hall, kitchen):
			failures.append("%s kitchen is not directly served by the common hall" % who)
		if not row_kitchen_touches_yard(plan, kitchen):
			failures.append("%s kitchen does not touch the rear service wall" % who)
	if row["style"] == &"longhall" and plan.domestic_layout.get("hall_role") != &"communal_hall":
		failures.append("%s presents the communal hall as a small entry hall" % who)
	if row["style"] == &"witch_hut" and row["scale"] == "large" \
			and not plan.has_kind(&"records"):
		failures.append("%s large witch hut has no records or dry herb storage activity" % who)
	if row["scale"] == "large":
		for bedroom in plan.rooms_of(&"bedroom"):
			var bed_rect: Rect2 = plan.rooms[bedroom]["rect"]
			var longest_bedroom_side: float = maxf(bed_rect.size.x, bed_rect.size.y)
			if longest_bedroom_side > 6.5:
				failures.append("%s bedroom spans %.1fm and reads as an oversized bay" % [who, longest_bedroom_side])


func _check_tiling_and_shapes(plan: HousePlan, who: String) -> void:
	var inner := HouseGeometry.interior_rect(plan.spec)
	var area := 0.0
	for i in range(plan.rooms.size()):
		var rect: Rect2 = plan.rooms[i]["rect"]
		area += rect.get_area()
		if not inner.grow(0.02).encloses(rect):
			failures.append("%s room %d leaves the footprint" % [who, i])
		if not HouseGeometry.room_suits(plan, i, plan.kind_of(i)):
			failures.append("%s room %d is too small for %s" % [who, i, plan.kind_of(i)])
		if HouseGeometry.room_aspect(plan, i) > HouseGeometry.aspect_max(plan.kind_of(i)):
			failures.append("%s room %d is a corridor-shaped %s" % [who, i, plan.kind_of(i)])
		for j in range(i + 1, plan.rooms.size()):
			var overlap: Rect2 = rect.intersection(plan.rooms[j]["rect"])
			if overlap.size.x > 0.02 and overlap.size.y > 0.02:
				failures.append("%s rooms %d and %d overlap" % [who, i, j])
	if absf(area - inner.get_area()) > 0.05:
		failures.append("%s rooms do not tile the footprint (%.2f vs %.2f)" % [who, area, inner.get_area()])
	var hall := plan.rooms_of(&"hall")
	if hall.size() != 1:
		failures.append("%s has %d entry halls" % [who, hall.size()])
		return
	var hall_rect: Rect2 = plan.rooms[hall[0]]["rect"]
	var large_spine := plan.spec.width >= 12.0 and plan.spec.length >= 14.0
	if large_spine:
		if absf(hall_rect.position.y - inner.position.y) > 0.02 \
				or absf(hall_rect.size.y - inner.size.y) > 0.02 \
				or hall_rect.size.x >= inner.size.x * 0.6:
			failures.append("%s large hall is not a centred lived circulation spine" % who)
	else:
		if absf(hall_rect.position.y - inner.position.y) > 0.02 \
				or absf(hall_rect.size.x - inner.size.x) > 0.02:
			failures.append("%s hall does not span the front entry wall" % who)
	if HouseGeometry.room_aspect(plan, hall[0]) > HouseGeometry.aspect_max(&"hall"):
		failures.append("%s front hall is too wide and shallow" % who)


func _check_routes(plan: HousePlan, who: String) -> void:
	var ground_start := plan.entrance_room()
	if ground_start < 0 or plan.kind_of(ground_start) != &"hall":
		failures.append("%s front door does not enter its hall" % who)
		return
	for level in range(maxi(plan.spec.storeys, 1)):
		var start := ground_start if level == 0 else -1
		if level > 0:
			for stair in plan.stairs:
				if int(stair.get("to_storey", -1)) == level:
					start = int(stair.get("b", -1))
					break
		if start < 0:
			failures.append("%s has no stair landing for storey %d" % [who, level])
			continue
		var reachable := plan.reachable_rooms(start, HouseGeometry.SLEEPING)
		for i in plan.rooms_on_storey(level):
			if plan.kind_of(i) in HouseGeometry.SLEEPING:
				continue
			if not reachable.has(i):
				failures.append("%s cannot reach room %d without crossing a bedroom" % [who, i])
		if level == 0 and plan.has_kind(&"kitchen") \
				and not reachable.has(plan.rooms_of(&"kitchen")[0]):
			failures.append("%s kitchen is disconnected from household circulation" % who)
		for bedroom in plan.rooms_of(&"bedroom"):
			if plan.storey_of_room(bedroom) != level:
				continue
			var degree := 0
			for door in plan.doors:
				if not door["exterior"] and (int(door["a"]) == bedroom or int(door["b"]) == bedroom):
					degree += 1
			if degree > 1:
				failures.append("%s bedroom %d is a through-room" % [who, bedroom])


func _check_activity_footprints(plan: HousePlan, who: String) -> void:
	for bedroom in plan.rooms_of(&"bedroom"):
		if not HouseFurnishPlacement.could_place(plan, bedroom, "bed"):
			failures.append("%s bedroom %d cannot hold its bed with real door/window clearances" % [who, bedroom])
	for kitchen in plan.rooms_of(&"kitchen"):
		if not HouseFurnishPlacement.could_place(plan, kitchen, "table"):
			failures.append("%s kitchen %d cannot hold its work/eating table" % [who, kitchen])
		if not HouseFurnishPlacement.could_place(plan, kitchen, "workbench"):
			failures.append("%s kitchen %d cannot hold a preparation workbench" % [who, kitchen])
	for workshop in plan.rooms_of(&"workshop"):
		if not HouseFurnishPlacement.could_place(plan, workshop, "workbench"):
			failures.append("%s workshop %d cannot hold its defining bench" % [who, workshop])
	for hall in plan.rooms_of(&"hall"):
		var seats: int = 2 if plan.spec.width <= 7.0 else 4
		if not _can_fit_seated_table(plan, hall, seats):
			failures.append("%s common hall cannot hold a household table and %d usable seats" % [who, seats])


func _can_fit_seated_table(plan: HousePlan, room: int, seats: int) -> bool:
	# Exercise the same measured candidate, clearance, and chair-placement path
	# the furnisher uses. A bare table in the room is not a dining arrangement.
	for key in PropCatalog.of_category("table"):
		var trial := HousePlan.new()
		trial.spec = plan.spec
		trial.rooms = plan.rooms
		trial.doors = plan.doors
		trial.windows = plan.windows
		trial.hearth = plan.hearth.duplicate(true)
		trial.focus = plan.focus.duplicate()
		trial.furniture = []
		var blocked := HouseFurnishPlacement.initial_blocked(trial, room)
		var zones: Array[Rect2] = []
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		HouseFurnishPlacement.place_free(trial, room, key, blocked, zones, rng)
		if trial.furniture.is_empty():
			continue
		var placed_seats := 0
		var seat_keys := PropCatalog.of_category("seat")
		for _wanted in range(seats):
			for seat_key in seat_keys:
				var before := trial.furniture.size()
				HouseFurnishPlacement.place_around(trial, room, seat_key, blocked, zones, rng)
				if trial.furniture.size() > before:
					placed_seats += 1
					break
		if placed_seats >= seats:
			return true
	return false


func _check_entry_semantics(plan: HousePlan, who: String) -> void:
	var entry := plan.entrance_room()
	if entry < 0:
		return
	var room: Dictionary = plan.rooms[entry]
	if room.get("domestic_layout_storey", -1) != 0:
		failures.append("%s hall does not identify the floor its domestic role describes" % who)
	if room.get("domestic_role", &"") not in [&"living_hall", &"communal_hall"]:
		failures.append("%s hall lacks an explicit lived common-room role" % who)
	var functions: Array = room.get("domestic_functions", [])
	if not functions.has(&"entry") or not functions.has(&"circulation") or not functions.has(&"dining") \
			or not room.get("meal_room", false):
		failures.append("%s common hall metadata does not record entry and eating uses" % who)


func _check_compact_shared_cooking() -> void:
	var spec := HouseSpec.new()
	spec.style = &"cottage"
	spec.width = 7.0
	spec.length = 7.0
	var plan := HouseGenerator.generate(spec, 1, false)
	if plan.room_count() != 2 or plan.domestic_layout.get("status", &"") != &"planned":
		failures.append("compact cottage did not keep a usable shared hall and sleeping room")
		return
	var hall := plan.rooms_of(&"hall")[0]
	var row: Dictionary = plan.rooms[hall]
	if not row.get("shared_cooking", false) or not row.get("domestic_functions", []).has(&"cooking"):
		failures.append("two-room cottage does not record cooking in its shared common hall")


func _check_narrow_corner_orientations() -> void:
	for rotated in [false, true]:
		var spec := HouseSpec.new()
		spec.width = 8.0 if rotated else 2.8
		spec.length = 2.8 if rotated else 8.0
		var plan := HousePlan.new()
		plan.spec = spec
		plan.rooms = [{"kind": &"store", "rect": HouseGeometry.interior_rect(spec), "storey": 0}]
		var floor_rect := HouseGeometry.room_floor_rect(plan, 0)
		var key := "FarmCrate_Empty"
		var block_size := Vector2(1.2, 0.18) if rotated else Vector2(0.18, 1.2)
		var blocked: Array[Rect2] = []
		for x in [floor_rect.position.x, floor_rect.end.x - block_size.x]:
			for y in [floor_rect.position.y, floor_rect.end.y - block_size.y]:
				blocked.append(Rect2(Vector2(x, y), block_size))
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		var zones: Array[Rect2] = []
		LegacyPlacement._place_corner(plan, 0, key, blocked, zones, rng)
		if plan.furniture.is_empty():
			failures.append("narrow-corner %s lost storage instead of fitting it along a wall" % ("rotated" if rotated else "wide"))
			continue
		var rect: Rect2 = plan.furniture[0]["rect"]
		var across := 1 if rotated else 0
		var gap := minf(rect.position[across] - floor_rect.position[across],
			floor_rect.end[across] - rect.end[across])
		if gap > HouseGeometry.WALL_GAP + 0.01:
			failures.append("narrow-corner %s storage slid into the walking strip" % ("rotated" if rotated else "wide"))


func _check_trade_activity() -> void:
	var spec := _spec({"style": &"farmhouse", "w": 17.0, "l": 18.0, "h": 2.8, "seed": 21325})
	spec.trade = &"smith"
	var plan := HouseGenerator.generate(spec, 21325, false)
	if not plan.has_kind(&"workshop"):
		failures.append("smith's household lost its workshop activity: %s" % _room_kinds(plan))
	if plan.domestic_layout.get("status", &"") != &"planned":
		failures.append("smith farmhouse fell back: %s" % plan.domestic_layout.get("reason", ""))


func _check_multistorey_routes() -> void:
	var spec := _spec({"style": &"townhouse", "w": 9.0, "l": 12.0, "seed": 8102})
	spec.storeys = 3
	var plan := HouseGenerator.generate(spec, 8102, false)
	if plan.stairs.size() != 2:
		failures.append("three-storey townhouse has %d stairs, expected two real flights" % plan.stairs.size())
	for level in [1, 2]:
		var beds := 0
		for room in plan.rooms_on_storey(level):
			if plan.kind_of(room) == &"bedroom":
				beds += 1
		if beds == 0:
			failures.append("three-storey townhouse has no private sleeping room on storey %d" % level)
	_check_routes(plan, "three-storey townhouse")


func _check_farmhouse_privacy_regressions() -> void:
	# Fixed members of the house-plan sweep that previously routed through a bed.
	for seed in [41001, 41037, 41085, 41121, 41169]:
		var n: int = seed - 41000
		var spec := HouseSpec.new(seed)
		spec.style = &"farmhouse"
		spec.width = 9.0 + float(n % 5) * 1.5
		spec.length = 10.0 + float(n % 7) * 1.6
		spec.height = 2.6
		spec.storeys = 2
		spec.room_count = HouseSpec.rooms_for(
			HouseGeometry.interior_rect(spec).size.x * HouseGeometry.interior_rect(spec).size.y)
		spec.program.assign(HouseSpec.PROGRAM)
		spec.back_door = n % 3 == 0
		var plan := HousePlanner.plan(spec)
		var who := "farmhouse privacy regression seed=%d" % seed
		if plan.domestic_layout.get("status", &"") != &"planned":
			failures.append("%s lost its supported room programme: %s" % [who,
				plan.domestic_layout.get("reason", "")])
		_check_routes(plan, who)


func _check_custom_family_path() -> void:
	var shop := ShopSpec.new()
	shop.style = &"witch_hut"
	shop.business = &"general_store"
	shop.program = [&"sales_floor", &"store"]
	var plan := ShopGenerator.generate(shop, 8102, false)
	if not plan.domestic_layout.is_empty():
		failures.append("shop was routed through the ordinary domestic layout")
	if not plan.has_kind(&"sales_floor"):
		failures.append("shop lost its own public room programme")


func _check_style_relationships() -> void:
	var plans := {}
	for style in STYLES:
		var spec := _spec({"style": style, "w": 17.0, "l": 18.0, "h": 2.8, "seed": 8102})
		plans[style] = HouseGenerator.generate(spec, 8102, false)
		if plans[style].domestic_layout.get("status", &"") != &"planned":
			failures.append("style relationship fixture %s fell back" % style)
	var longhall: HousePlan = plans[&"longhall"]
	var cottage: HousePlan = plans[&"cottage"]
	var inner := HouseGeometry.interior_rect(longhall.spec)
	var hall_ratio: float = longhall.rooms[longhall.rooms_of(&"hall")[0]]["rect"].size.y / inner.size.y
	if hall_ratio < 0.38:
		failures.append("longhall did not earn its broad communal hall band")
	for pair in [[&"cottage", &"parlour"], [&"farmhouse", &"workshop"],
			[&"townhouse", &"office"], [&"witch_hut", &"workshop"]]:
		var plan: HousePlan = plans[pair[0]]
		if not plan.has_kind(pair[1]) or not plan.has_kind(&"kitchen"):
			continue
		var signature_room: int = plan.rooms_of(pair[1])[0]
		var kitchen: int = plan.rooms_of(&"kitchen")[0]
		if not _rooms_share_door(plan, plan.rooms_of(&"hall")[0], signature_room):
			failures.append("%s signature room is not directly served by the lived hall" % pair[0])
		if not _rooms_share_door(plan, plan.rooms_of(&"hall")[0], kitchen):
			failures.append("%s kitchen is not directly served by the lived hall" % pair[0])
		if row_kitchen_touches_yard(plan, kitchen):
			continue
		failures.append("%s kitchen does not reach the rear service wall" % pair[0])


func _rooms_share_door(plan: HousePlan, a: int, b: int) -> bool:
	for door in plan.doors:
		if door.get("exterior", false):
			continue
		if (int(door["a"]) == a and int(door["b"]) == b) \
				or (int(door["a"]) == b and int(door["b"]) == a):
			return true
	return false


func row_kitchen_touches_yard(plan: HousePlan, kitchen: int) -> bool:
	var inner := HouseGeometry.interior_rect(plan.spec)
	var rect: Rect2 = plan.rooms[kitchen]["rect"]
	return absf(rect.end.y - inner.end.y) <= 0.02


func _check_negative_control() -> void:
	var spec := _spec({"style": &"farmhouse", "w": 12.0, "l": 14.0, "seed": 1})
	var plan := HouseGenerator.generate(spec, 1, false)
	if plan.rooms.size() < 2:
		failures.append("negative fixture has too few rooms")
		return
	var rect: Rect2 = plan.rooms[1]["rect"]
	rect.position.x += 0.5
	plan.rooms[1]["rect"] = rect
	var report := HousePlanCheck.new().check(plan)
	var caught := false
	for failure in report["failures"]:
		if String(failure).begins_with("tiling:"):
			caught = true
	if not caught:
		failures.append("negative overlapping partition escaped HousePlanCheck.tiling")


func _check_determinism() -> void:
	for row in [
		{"style": &"cottage", "w": 9.0, "l": 12.0, "h": 2.6, "seed": 8102},
		{"style": &"witch_hut", "w": 17.0, "l": 18.0, "h": 2.8, "seed": 21325},
	]:
		var a := HouseGenerator.generate(_spec(row), int(row["seed"]), false)
		var b := HouseGenerator.generate(_spec(row), int(row["seed"]), false)
		if _plan_geometry_text(a) != _plan_geometry_text(b):
			failures.append("%s seed=%d plan geometry changed on an identical repeat" % [row["style"], row["seed"]])


func _plan_geometry_text(plan: HousePlan) -> String:
	var out := ""
	for room in plan.rooms:
		var rect: Rect2 = room["rect"]
		out += "R:%s:%d:%.3f,%.3f,%.3f,%.3f;" % [room["kind"], room.get("storey", 0),
			rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	for door in plan.doors:
		var pos: Vector2 = door["pos"]
		out += "D:%d:%d:%.3f,%.3f,%.3f;" % [door["a"], door["b"], pos.x, pos.y, door["width"]]
	return out


func _spec(row: Dictionary) -> HouseSpec:
	var spec := HouseSpec.new()
	spec.style = row["style"]
	spec.width = float(row["w"])
	spec.length = float(row["l"])
	spec.height = float(row.get("h", 2.6))
	return spec


func _room_kinds(plan: HousePlan) -> Array[StringName]:
	var kinds: Array[StringName] = []
	for room in range(plan.room_count()):
		kinds.append(plan.kind_of(room))
	return kinds
