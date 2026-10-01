class_name ShopArchetypeSuite
extends RefCounted
## Occupational landmarks: each business must read through rooms and fixtures,
## then pass the same physical, daylight, furnishing, and walking rules as a house.

const REQUIRED := {
	&"barracks": ["office", "bed", "stand", "table", "bench"],
	&"library": ["reading_room", "bookcase", "lectern", "hearth"],
	&"prison": ["guardroom", "table", "stand"],
	&"blacksmith": ["workshop", "anvil", "workbench"],
	&"stable": ["stable", "stall"],
	&"restaurant": ["dining_room", "table", "seat"],
	&"tavern": ["dining_room", "table", "barrel", "counter"],
	&"inn": ["dining_room", "table", "bed"],
	&"bakery": ["sales_floor", "counter", "hearth"],
	&"butcher": ["sales_floor", "counter", "blade"],
	&"apothecary": ["sales_floor", "counter", "alchemy"],
	&"general_store": ["sales_floor", "counter", "crate"],
	&"tailor": ["sales_floor", "counter", "sack", "rack", "shelf", "workbench"],
	&"carpenter": ["workshop", "workbench", "rack", "bench"],
	&"town_hall": ["council_chamber", "table", "seat"],
	&"guildhall": ["meeting_hall", "table", "bench"],
	&"palace": ["antechamber", "seat", "banner", "bed", "chest"],
}
const BENCH_SEAT_PITCH := 0.65 # metres per usable place along the measured bench


static func run() -> SuiteResult:
	var res := SuiteResult.new("shop archetypes")
	for business in REQUIRED:
		var spec := ShopSpec.new()
		spec.business = business
		spec.style = &"longhall" if business in [&"blacksmith", &"stable", &"carpenter", &"library", &"prison"] else &"townhouse"
		spec.width = 14.0
		spec.length = 18.0
		if business == &"barracks":
			spec.width = 18.0
			spec.length = 28.0
		if business == &"library":
			spec.width = 18.0
			spec.length = 28.0
		if business == &"prison":
			spec.width = 15.8
			spec.length = 22.0
		spec.height = 2.9
		var plan := ShopGenerator.generate(spec, 33000 + absi(String(business).hash()) % 900)
		var builder := HouseBuilder.new()
		builder.build(plan)
		res.checked += 1
		var wants: Array = REQUIRED[business]
		if not plan.has_kind(StringName(wants[0])):
			res.fail("%s has no defining %s room" % [String(business), wants[0]])
		if business == &"prison":
			var cells := 0
			var oubliettes := 0
			for room in range(plan.room_count()):
				if plan.storey_of_room(room) == 0 and plan.kind_of(room) == &"cell": cells += 1
				if plan.kind_of(room) == &"oubliette": oubliettes += 1
			if cells < 3 or oubliettes != 1:
				res.fail("prison archetype lacks at least three cells and one oubliette")
			if not _has_key(plan, "WeaponStand"):
				res.fail("prison archetype lacks a WeaponStand")
		for cat in wants.slice(1):
			if not _has_category(plan, String(cat)):
				res.fail("%s has no defining %s fitting" % [String(business), cat])
		var report: Dictionary = HouseQA.new().check(plan, builder)
		for failure in report["failures"]:
			res.fail("%s: %s" % [String(business), failure])
		for warning in report["warnings"]:
			res.warn("%s: %s" % [String(business), warning])
		for failure2 in shopfront_rules(spec, plan, builder):
			res.fail("%s: %s" % [String(business), failure2])
	if REQUIRED.has(&"barracks"):
		_check_barracks(res)
	_check_lodging(res)
	return res


static func run_barracks_quick() -> SuiteResult:
	var res := SuiteResult.new("barracks focused archetype")
	_check_barracks(res)
	return res


## Explicit bounded family gate for the guardhouse's ordinary plan, furnishing,
## navigation, row and measured seating contracts across deterministic seeds.
static func run_barracks_seeds(seed_count := 100) -> SuiteResult:
	var res := SuiteResult.new("barracks %d-seed QA" % seed_count)
	for seed_offset in range(seed_count):
		var spec := ShopSpec.new()
		spec.business = &"barracks"
		spec.style = &"longhall"
		spec.width = 18.0
		spec.length = 28.0
		spec.height = 2.9
		var seed := 52000 + seed_offset
		var plan: HousePlan = ShopGenerator.generate(spec, seed)
		var builder := HouseBuilder.new()
		builder.build(plan)
		var who := "barracks seed %d" % seed
		res.checked += 1
		if plan.room_count() != 4:
			res.fail("%s has %d rooms, wants the four-room programme" % [who, plan.room_count()])
		for failure in _barracks_failures(plan):
			res.fail("%s: %s" % [who, failure])
		var report: Dictionary = HouseQA.new().check(plan, builder)
		for failure2 in report["failures"]:
			res.fail("%s: %s" % [who, failure2])
		for warning in report["warnings"]:
			res.warn("%s: %s" % [who, warning])
	return res


## INT-008: the same guardhouse programme at three footprints, then mutations
## that prove the row and occupational requirements are being measured.
static func _check_barracks(res: SuiteResult) -> void:
	for scale in [0.7, 1.0, 1.4]:
		var spec := ShopSpec.new()
		spec.business = &"barracks"
		spec.style = &"longhall"
		spec.width = 18.0 * scale
		spec.length = 28.0 * scale
		spec.height = 2.9
		var plan: HousePlan = ShopGenerator.generate(spec, 43800 + int(scale * 100))
		var builder := HouseBuilder.new()
		builder.build(plan)
		res.checked += 1
		var who := "barracks scale=%.2f" % scale
		if plan.room_count() != 4:
			res.fail("%s has %d rooms, wants the four-room programme" % [who, plan.room_count()])
		for failure in _barracks_failures(plan):
			res.fail("%s: %s" % [who, failure])
		var report: Dictionary = HouseQA.new().check(plan, builder)
		for failure2 in report["failures"]:
			res.fail("%s: %s" % [who, failure2])
		for warning in report["warnings"]:
			res.warn("%s: %s" % [who, warning])
		if is_equal_approx(scale, 1.0):
			_barracks_negative_controls(res, plan)


static func _barracks_failures(plan: HousePlan) -> Array[String]:
	var out: Array[String] = []
	var office: int = plan.entrance_room()
	if office < 0 or plan.kind_of(office) != &"office":
		out.append("front room is not the office")
	else:
		var office_area := HouseGeometry.room_area(plan, office)
		if is_equal_approx(plan.spec.width, 18.0) and is_equal_approx(plan.spec.length, 28.0) \
				and (office_area < 20.0 or office_area > 35.0):
			out.append("standard front office has %.1f m2, wants 20–35 m2" % office_area)
		var office_storage := 0
		for office_item in plan.furniture_of(office):
			if PropCatalog.category(plan.furniture[office_item]["key"]) in ["chest", "bookcase"]:
				office_storage += 1
		if office_storage < 1:
			out.append("office has no storage for records and kit")
	var dormitory := _room_of_kind(plan, &"dormitory")
	if dormitory < 0:
		out.append("no dormitory")
	else:
		var beds: Array[int] = []
		for f in plan.furniture_of(dormitory):
			if PropCatalog.category(plan.furniture[f]["key"]) == "bed":
				beds.append(f)
		var expected_bed_rows := 2 if HouseGeometry.room_area(plan, dormitory) >= 150.0 else 1
		if beds.size() < 4 * expected_bed_rows:
			out.append("dormitory has %d beds, wants %d for its floor area" % [beds.size(), 4 * expected_bed_rows])
		elif not _rows_with_aisles(plan, beds, expected_bed_rows, 4):
			out.append("dormitory beds do not form measured rows with walkable aisles")
	var armoury := _room_of_kind(plan, &"armoury")
	if armoury < 0:
		out.append("no armoury")
	else:
		var weapons: Array[int] = []
		var shields := 0
		for f2 in plan.furniture_of(armoury):
			var item: Dictionary = plan.furniture[f2]
			if String(item["key"]) == "WeaponStand":
				weapons.append(f2)
			if String(item["key"]) == "Shield_Wooden" and bool(item.get("mounted", false)):
				shields += 1
		var expected_weapon_rows := 2 if HouseGeometry.room_area(plan, armoury) >= 150.0 else 1
		if weapons.size() < 2 * expected_weapon_rows:
			out.append("armoury has %d weapon stands, wants at least %d for its floor area" % [weapons.size(), 2 * expected_weapon_rows])
		elif not _rows_with_aisles(plan, weapons, expected_weapon_rows, 2):
			out.append("armoury weapon stands do not form measured rows with walkable aisles")
		if shields < 2:
			out.append("armoury has %d mounted shields, wants at least 2" % shields)
	var mess := _room_of_kind(plan, &"mess")
	if mess < 0:
		out.append("no mess")
	else:
		var tables := 0
		var bench_seats := 0
		var benches_at_table := true
		var bench_zones_on_floor := true
		var floor := HouseGeometry.room_floor_rect(plan, mess)
		for f3 in plan.furniture_of(mess):
			var item: Dictionary = plan.furniture[f3]
			var category := PropCatalog.category(item["key"])
			if category == "table": tables += 1
			if category == "bench":
				var rect := Rect2(item["rect"])
				bench_seats += int(floorf(maxf(rect.size.x, rect.size.y) / BENCH_SEAT_PITCH))
				var zone := Rect2(item["zone"])
				if zone.size.x <= 0.0 or zone.size.y <= 0.0 or not floor.grow(0.02).encloses(zone):
					bench_zones_on_floor = false
				var host := int(item.get("host", -1))
				if host < 0 or PropCatalog.category(plan.furniture[host]["key"]) != "table":
					benches_at_table = false
		var expected_tables := 1
		var expected_seats := 4
		if floor.size.x * floor.size.y >= 50.0:
			expected_tables = 2
			expected_seats = 8
		if floor.size.x * floor.size.y >= 100.0:
			expected_seats = 12
		if tables < expected_tables:
			out.append("mess has %d tables, wants %d for its floor area" % [tables, expected_tables])
		if bench_seats < expected_seats:
			out.append("mess has %d bench seats, wants at least %d" % [bench_seats, expected_seats])
		if not benches_at_table:
			out.append("mess benches are not placed around their table")
		if not bench_zones_on_floor:
			out.append("mess bench pull-back zones are not clear floor")
	return out


static func _rows_with_aisles(plan: HousePlan, members: Array[int],
		expected_rows: int, minimum_per_row: int) -> bool:
	var groups := {}
	for f in members:
		var item: Dictionary = plan.furniture[f]
		var group := String(item.get("row", ""))
		if group.is_empty():
			return false
		if not groups.has(group):
			groups[group] = {"count": 0, "aisle": Rect2(item["zone"])}
		groups[group]["count"] += 1
		if not Rect2(item["zone"]).is_equal_approx(groups[group]["aisle"]):
			return false
	if groups.size() < expected_rows:
		return false
	for row in groups.values():
		if int(row["count"]) < minimum_per_row \
				or minf(row["aisle"].size.x, row["aisle"].size.y) < HouseGeometry.PATH_MIN - 0.01:
			return false
	return true


static func _barracks_negative_controls(res: SuiteResult, source: HousePlan) -> void:
	# A positive plan is checked first; each edit below must fail its own rule.
	res.checked += 1
	if not _barracks_failures(source).is_empty():
		res.fail("barracks negative controls: unmutated source is not clean")
		return
	var missing_weapon := _copy_plan(source)
	var weapon_indexes: Array[int] = []
	for f in range(missing_weapon.furniture.size() - 1, -1, -1):
		if String(missing_weapon.furniture[f]["key"]) == "WeaponStand":
			weapon_indexes.append(f)
	for weapon_index in weapon_indexes.slice(1):
		missing_weapon.furniture.remove_at(weapon_index)
	var weapon_failures := _barracks_failures(missing_weapon)
	res.checked += 1
	if not weapon_failures.any(func(message: String) -> bool:
		return message.begins_with("armoury has 1 weapon stands")):
		res.fail("barracks negative control: removing a weapon stand escaped the count rule")
	var sparse_mess := _copy_plan(source)
	var seat_indexes: Array[int] = []
	var mess_room := _room_of_kind(sparse_mess, &"mess")
	for f3 in range(sparse_mess.furniture.size() - 1, -1, -1):
		var item: Dictionary = sparse_mess.furniture[f3]
		if int(item["room"]) == mess_room \
				and PropCatalog.category(item["key"]) == "bench":
			seat_indexes.append(f3)
	for seat_index in seat_indexes:
		sparse_mess.furniture.remove_at(seat_index)
	var seat_failures := _barracks_failures(sparse_mess)
	res.checked += 1
	if not seat_failures.any(func(message: String) -> bool:
		return message.begins_with("mess has 0 bench seats")):
		res.fail("barracks negative control: removing mess benches escaped the measured-seat rule")
	var broken_row := _copy_plan(source)
	var beds: Array[int] = []
	var dormitory := _room_of_kind(broken_row, &"dormitory")
	for f2 in broken_row.furniture_of(dormitory):
		if PropCatalog.category(broken_row.furniture[f2]["key"]) == "bed":
			beds.append(f2)
	if beds.size() >= 3:
		var rect := Rect2(broken_row.furniture[beds[1]]["rect"])
		var a := Rect2(broken_row.furniture[beds[0]]["rect"]).get_center()
		var b := Rect2(broken_row.furniture[beds[2]]["rect"]).get_center()
		var direction := (b - a).normalized()
		var perpendicular := Vector2(-direction.y, direction.x) * 0.3
		rect.position += perpendicular
		broken_row.furniture[beds[1]]["rect"] = rect
		var pos: Vector3 = broken_row.furniture[beds[1]]["pos"]
		pos.x += perpendicular.x
		pos.z += perpendicular.y
		broken_row.furniture[beds[1]]["pos"] = pos
		var report: Dictionary = HouseFurnishCheck.new().check(broken_row)
		res.checked += 1
		if not report["failures"].any(func(message: String) -> bool:
			return String(message).begins_with("row:") and "off the line" in String(message)):
			res.fail("barracks negative control: a bed moved 0.3m off its row escaped QA")
	else:
		res.fail("barracks negative control: source dormitory has too few beds to mutate")


static func _room_of_kind(plan: HousePlan, kind: StringName) -> int:
	for i in range(plan.room_count()):
		if plan.kind_of(i) == kind:
			return i
	return -1


static func _copy_plan(source: HousePlan) -> HousePlan:
	var copy := HousePlan.new()
	copy.spec = source.spec
	copy.rooms = source.rooms.duplicate(true)
	copy.doors = source.doors.duplicate(true)
	copy.windows = source.windows.duplicate(true)
	copy.furniture = source.furniture.duplicate(true)
	copy.rugs = source.rugs.duplicate(true)
	copy.exterior = source.exterior.duplicate(true)
	copy.exterior_omissions = source.exterior_omissions.duplicate()
	copy.courts = source.courts.duplicate(true)
	copy.stairs = source.stairs.duplicate(true)
	copy.zones = source.zones.duplicate(true)
	copy.dais = source.dais.duplicate(true)
	copy.compromises = source.compromises.duplicate(true)
	copy.hearth = source.hearth.duplicate(true)
	copy.focus = source.focus.duplicate(true)
	return copy


## LAY-012: nobody walks through a guest room to reach a bed.
##
## Two halves, and the fixture is the point of the first. Proving that inns
## come out right today proves nothing unless the rule can be seen to fire --
## a check that never fails is a check that is not looking -- so the first
## half takes a real inn, CHAINS its guest rooms by hand, and asserts the
## privacy rule catches it and `_open_up_lodging` puts it right. The second
## half then holds every inn the generator makes to the invariant.
static func _check_lodging(res: SuiteResult) -> void:
	var chained: HousePlan = _chained_inn(res)
	if chained != null:
		res.checked += 1
		if not _privacy_failures(chained):
			res.fail("lodging: a plan whose only way to the far bed is through "
				+ "the near one passed the privacy rule")
		ShopPlanner._open_up_lodging(chained)
		res.checked += 1
		# The invariant the landing pass owns, and only that. Renaming two
		# ordinary rooms to guest rooms can leave a THIRD room behind one of
		# them, which is `HousePlanOpenings.open_up_privacy`'s job and not this
		# pass's; holding the pass to the whole privacy rule would be holding
		# it to somebody else's work.
		for i in range(chained.room_count()):
			if chained.kind_of(i) in HouseGeometry.SLEEPING \
					and not ShopPlanner._has_public_door(chained, i):
				res.fail("lodging: room %d (%s) still opens only onto other beds "
					% [i, String(chained.kind_of(i))]
					+ "after the landing pass")

	for size in [[11.0, 14.0], [14.0, 18.0], [18.0, 24.0]]:
		for storeys in [1, 2]:
			for s in range(6):
				var spec := ShopSpec.new()
				spec.business = &"inn"
				spec.style = &"townhouse"
				spec.width = size[0]
				spec.length = size[1]
				spec.height = 2.9
				spec.storeys = storeys
				var plan: HousePlan = ShopGenerator.generate(spec, 41000 + s * 37)
				var where := "inn %.0fx%.0f st%d seed %d" % [size[0], size[1], storeys, 41000 + s * 37]
				res.checked += 1
				for f in _privacy_failures(plan):
					res.fail("lodging: %s: %s" % [where, f])
				for i in range(plan.room_count()):
					if plan.kind_of(i) in HouseGeometry.SLEEPING \
							and not ShopPlanner._has_public_door(plan, i):
						res.fail("lodging: %s: room %d (%s) opens only onto other beds"
							% [where, i, String(plan.kind_of(i))])


## An inn whose guest rooms are in a chain, BUILT BY HAND: two adjoining
## rooms are named `guest_room`, and every door into the second is taken away
## except the one from the first.
##
## Constructed rather than searched for. The generator does not chain guest
## rooms any more -- that is the point of LAY-012 -- so a fixture that waits
## for one would never fire, and a check that never fails is a check that is
## not looking. The two rooms are real rooms of a real plan, so what is
## tested is the rule and the remedy, not a hand-drawn rectangle.
static func _chained_inn(res: SuiteResult) -> HousePlan:
	var spec := ShopSpec.new()
	spec.business = &"inn"
	spec.style = &"townhouse"
	spec.width = 16.0
	spec.length = 20.0
	spec.height = 2.9
	var plan: HousePlan = ShopGenerator.generate(spec, 41777)
	# two rooms that adjoin, are not the way in, and could hold a bed
	var entrance: int = plan.entrance_room()
	var pair: Array[int] = []
	for i in range(plan.room_count()):
		if i == entrance or not HouseGeometry.room_suits(plan, i, &"guest_room"):
			continue
		for j in range(i + 1, plan.room_count()):
			if j == entrance or not HouseGeometry.room_suits(plan, j, &"guest_room"):
				continue
			if not HousePlanOpenings.shared_edge(plan, i, j).is_empty():
				pair = [i, j]
				break
		if not pair.is_empty():
			break
	res.checked += 1
	if pair.is_empty():
		res.fail("lodging: the fixture inn has no two adjoining rooms that could "
			+ "be guest rooms; the privacy rule cannot be shown to fire")
		return null
	var near: int = pair[0]
	var far: int = pair[1]
	plan.rooms[near]["kind"] = &"guest_room"
	plan.rooms[far]["kind"] = &"guest_room"
	# the far bed keeps exactly one door, and it is the near bed's
	var kept: Array[Dictionary] = []
	for door in plan.doors:
		if int(door["a"]) != far and int(door["b"]) != far:
			kept.append(door)
	kept.append({"a": near, "b": far, "pos": plan.rooms[far]["rect"].get_center(),
		"normal": Vector2(1, 0), "width": HouseGeometry.INNER_DOOR_W,
		"exterior": false, "front": false, "storey": plan.storey_of_room(far)})
	plan.doors = kept
	return plan


static func _privacy_failures(plan: HousePlan) -> Array[String]:
	var out: Array[String] = []
	for f in HousePlanCheck.new().check(plan)["failures"]:
		if String(f).begins_with("privacy"):
			out.append(String(f))
	return out


## What a trade's front has to be (LAY-009), measured from the plan: the
## street door is in the front room and as wide as the trade needs; a stable
## has a door a horse fits through; a smithy opens to the street and its
## forge stands on the chimney wall under a real chimney; a shop with a
## shopfront has its hatch in the street wall; a tavern keeps its casks
## behind the bar.
static func shopfront_rules(spec: ShopSpec, plan: HousePlan, builder: HouseBuilder) -> Array[String]:
	var out: Array[String] = []
	var front: int = plan.entrance_room()
	var door: int = plan.entrance()
	if door < 0 or front < 0:
		return ["front: no street door"]
	var street_front: bool = spec.door_w() >= 1.2 or not spec.front_open().is_empty()
	if street_front and plan.kind_of(front) != spec.front_room():
		out.append("front: the street door opens into the %s, not the %s"
			% [String(plan.kind_of(front)), String(spec.front_room())])
	var w: float = float(plan.doors[door]["width"])
	if w < spec.door_w() - 0.01:
		out.append("door: the street door is %.2fm wide, the trade needs %.2fm" % [w, spec.door_w()])
	if spec.business == &"stable" and w < 1.2:
		out.append("door: a horse does not fit through a %.2fm door" % w)
	if spec.business == &"blacksmith":
		if w < 2.4:
			out.append("door: the forge opens to the street through %.2fm" % w)
		if plan.hearth_room() != front:
			out.append("forge: the chimney is in room %d, the forge room is %d" % [plan.hearth_room(), front])
		var stack := 0
		for m in builder.mass_log:
			if String(m["name"]) == "chimney":
				stack += 1
		if stack != 1:
			out.append("forge: %d chimneys" % stack)
	if not spec.front_open().is_empty():
		var hatch := false
		for win in plan.windows:
			if win.get("hatch", false) and int(win["room"]) == front:
				hatch = true
		if not hatch:
			out.append("shopfront: no hatch in the street wall of the %s" % String(spec.front_room()))
	if spec.business == &"tavern":
		var bar := Vector2(INF, INF)
		for p in plan.furniture:
			if int(p["room"]) == front and PropCatalog.category(p["key"]) == "counter":
				bar = Rect2(p["rect"]).get_center()
		if not bar.is_finite():
			out.append("bar: the tavern has no counter in its front room")
		else:
			var near := INF
			for p2 in plan.furniture:
				if int(p2["room"]) == front and PropCatalog.category(p2["key"]) == "barrel":
					near = minf(near, Rect2(p2["rect"]).get_center().distance_to(bar))
			if near > 3.5:
				out.append("bar: the nearest cask is %.2fm from the bar" % near)
	return out


static func _has_category(plan: HousePlan, category: String) -> bool:
	for placement in plan.furniture:
		if PropCatalog.category(placement["key"]) == category:
			return true
	return false


static func _has_key(plan: HousePlan, key: String) -> bool:
	for placement in plan.furniture:
		if String(placement["key"]) == key:
			return true
	return false
