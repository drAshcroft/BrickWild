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
	&"market_hall": ["market_hall", "counter"],
	&"alchemist_laboratory": ["laboratory", "workbench", "alchemy", "cage", "hearth"],
	&"bathhouse": ["changing_room", "bench", "bath_hall", "barrel"],
	&"hospice": ["ward", "bed", "dispensary", "alchemy"],
	&"school": ["schoolroom", "bench", "lectern", "masters_office"],
	&"thieves_den": ["sales_floor", "counter", "bookcase"],
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
		if business in [&"alchemist_laboratory", &"bathhouse", &"hospice", &"school"]:
			spec.width = 20.0
			spec.length = 26.0
		if business == &"thieves_den":
			spec.width = 30.0
			spec.length = 24.0
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
		if business in [&"alchemist_laboratory", &"bathhouse", &"hospice", &"school"]:
			for contract_failure in _int013_failures(plan, business):
				res.fail("%s: %s" % [String(business), contract_failure])
		if business == &"thieves_den":
			for contract_failure in _thieves_den_failures(plan):
				res.fail("thieves_den: %s" % contract_failure)
		var report: Dictionary = HouseQA.new().check(plan, builder)
		for failure in report["failures"]:
			res.fail("%s: %s" % [String(business), failure])
		for warning in report["warnings"]:
			res.warn("%s: %s" % [String(business), warning])
		for failure2 in shopfront_rules(spec, plan, builder):
			res.fail("%s: %s" % [String(business), failure2])
		if business == &"market_hall":
			_market_hall_contract(res, plan, builder)
	if REQUIRED.has(&"barracks"):
		_check_barracks(res)
	_check_lodging(res)
	return res


## INT-013's focused contract. Three measured footprints check the room
## programme and the defining fixtures; one standard plan per family is then
## deliberately stripped to prove its defining rule can fail.
static func run_int013() -> SuiteResult:
	var res := SuiteResult.new("INT-013 shop archetypes")
	var businesses: Array[StringName] = [&"alchemist_laboratory", &"bathhouse", &"hospice", &"school"]
	for business in businesses:
		for scale in [0.7, 1.0, 1.4]:
			var spec := _int013_spec(business, scale)
			var plan := ShopGenerator.generate(spec, 71300 + businesses.find(business) * 10 + int(scale * 100))
			var builder := HouseBuilder.new()
			builder.build(plan)
			res.checked += 1
			for failure in _int013_failures(plan, business):
				res.fail("%s scale=%.1f: %s" % [String(business), scale, failure])
			for failure2 in HouseQA.new().check(plan, builder)["failures"]:
				res.fail("%s scale=%.1f QA: %s" % [String(business), scale, failure2])
		var control_spec := _int013_spec(business, 1.0)
		var control := ShopGenerator.generate(control_spec, 71399 + businesses.find(business))
		if not _int013_failures(control, business).is_empty():
			res.fail("%s negative control starts from a plan that is already invalid" % String(business))
			continue
		var room := _int013_contract_room(control, business)
		var category := "alchemy"
		var expected := "alchemy"
		match business:
			&"bathhouse":
				category = "barrel"
				expected = "tubs"
			&"hospice":
				category = "bed"
				expected = "bed row"
			&"school":
				category = "bench"
				expected = "bench rows"
		for i in range(control.furniture.size() - 1, -1, -1):
			if int(control.furniture[i]["room"]) == room \
					and PropCatalog.category(control.furniture[i]["key"]) == category:
				control.furniture.remove_at(i)
		var negative := _int013_failures(control, business)
		res.checked += 1
		if not negative.any(func(row: String) -> bool: return row.contains(expected)):
			res.fail("%s negative control: removing %s escaped the defining check" % [String(business), expected])
	return res


## Bounded secret-door contract. Three footprints are checked once each, then
## deliberately damaged plans prove the secret route and hidden-room rule are
## measurable. The optional 100-seed lane is kept separate for scheduled QA.
static func run_int012() -> SuiteResult:
	var res := SuiteResult.new("INT-012 secret doors")
	for scale in [0.7, 1.0, 1.4]:
		var plan := ShopGenerator.generate(_int012_spec(scale), 81200 + int(scale * 100))
		var builder := HouseBuilder.new()
		builder.build(plan)
		res.checked += 1
		for failure in _thieves_den_failures(plan):
			res.fail("scale=%.1f: %s" % [scale, failure])
		var report: Dictionary = HouseQA.new().check(plan, builder)
		for failure2 in report["failures"]:
			res.fail("scale=%.1f QA: %s" % [scale, failure2])
		var nav := HouseNavCheck.new()
		nav.check(plan)
		if int(nav.stats.get("hidden_rooms_unreached_without_secrets", 0)) != 2:
			res.fail("scale=%.1f: second navigation flood did not isolate both hidden rooms" % scale)
		if not builder.component_log.any(func(part: Dictionary) -> bool:
			return String(part.get("role", "")) == "secret_bookcase_panel"):
			res.fail("scale=%.1f: builder emitted no secret bookcase panel" % scale)
	var control := ShopGenerator.generate(_int012_spec(1.0), 81299)
	if not _thieves_den_failures(control).is_empty():
		res.fail("negative controls: standard thieves' den is invalid")
		return res
	var secret_door := -1
	for i in range(control.doors.size()):
		if bool(control.doors[i].get("secret", false)):
			secret_door = i
			break
	if secret_door < 0:
		res.fail("negative controls: no secret door to mutate")
		return res
	var no_secret := _copy_plan(control)
	no_secret.doors[secret_door].erase("secret")
	var nav_without_marker := HouseNavCheck.new()
	var marker_report: Dictionary = nav_without_marker.check(no_secret)
	res.checked += 1
	if marker_report["ok"] or not marker_report["failures"].any(func(message: String) -> bool:
		return String(message).contains("remain reachable without secret doors")):
		res.fail("negative control: removing the secret marker did not expose the hidden route")
	var no_door := _copy_plan(control)
	no_door.doors.remove_at(secret_door)
	var plan_report: Dictionary = HousePlanCheck.new().check(no_door)
	res.checked += 1
	if not plan_report["failures"].any(func(message: String) -> bool:
		return String(message).begins_with("connected:") and String(message).contains("cannot be reached")):
		res.fail("negative control: removing the secret door escaped plan connectivity")
	var exterior_secret := _copy_plan(control)
	exterior_secret.doors[secret_door]["exterior"] = true
	exterior_secret.doors[secret_door]["front"] = true
	exterior_secret.doors[secret_door]["b"] = -1
	var exterior_report: Dictionary = HousePlanCheck.new().check(exterior_secret)
	res.checked += 1
	if not exterior_report["failures"].any(func(message: String) -> bool:
		return String(message).contains("secret door cannot be an exterior entrance")):
		res.fail("negative control: exterior secret door escaped entrance semantics")
	var no_bookcase := _copy_plan(control)
	var hidden_store := _room_of_kind(no_bookcase, &"store")
	for i in range(no_bookcase.furniture.size() - 1, -1, -1):
		if int(no_bookcase.furniture[i]["room"]) == hidden_store \
				and PropCatalog.category(no_bookcase.furniture[i]["key"]) == "bookcase":
			no_bookcase.furniture.remove_at(i)
	res.checked += 1
	if not _thieves_den_failures(no_bookcase).any(func(message: String) -> bool:
		return String(message).contains("hidden store has no bookcase disguise")):
		res.fail("negative control: removing the hidden-store bookcase escaped the fixture rule")
	return res


static func run_thieves_den_seeds(count := 100) -> SuiteResult:
	var res := SuiteResult.new("INT-012 thieves den seed sweep")
	for seed in range(count):
		var plan := ShopGenerator.generate(_int012_spec(1.0), 81200 + seed)
		var builder := HouseBuilder.new()
		builder.build(plan)
		res.checked += 1
		for failure in _thieves_den_failures(plan):
			res.fail("seed=%d: %s" % [seed, failure])
		for failure2 in HouseQA.new().check(plan, builder)["failures"]:
			res.fail("seed=%d QA: %s" % [seed, failure2])
	return res


static func _int012_spec(scale: float) -> ShopSpec:
	var spec := ShopSpec.new()
	spec.business = &"thieves_den"
	spec.style = &"townhouse"
	spec.width = 30.0 * scale
	spec.length = 24.0 * scale
	spec.height = 3.0
	return spec


static func _thieves_den_failures(plan: HousePlan) -> Array[String]:
	var out: Array[String] = []
	var sales := _room_of_kind(plan, &"sales_floor")
	var store := _room_of_kind(plan, &"store")
	var dormitory := _room_of_kind(plan, &"dormitory")
	if sales < 0 or store < 0 or dormitory < 0:
		out.append("requires sales floor, hidden store, and hidden dormitory")
		return out
	if plan.entrance_room() != sales:
		out.append("street door does not enter the sales floor")
	if not bool(plan.rooms[store].get("secret", false)) or not bool(plan.rooms[dormitory].get("secret", false)):
		out.append("store and dormitory must be marked private")
	var bookcase := false
	for item in plan.furniture_of(store):
		if PropCatalog.category(plan.furniture[item]["key"]) == "bookcase":
			bookcase = true
	if not bookcase:
		out.append("hidden store has no bookcase disguise")
	var secret_edges := 0
	var has_store_dorm_door := false
	for door in plan.doors:
		var a := int(door.get("a", -1))
		var b := int(door.get("b", -1))
		if bool(door.get("secret", false)):
			secret_edges += 1
			if bool(door.get("exterior", false)) or not ((a == sales and b == store) or (a == store and b == sales)):
				out.append("secret door is not the sales-floor to store passage")
			var edge := HousePlanOpenings.shared_edge(plan, sales, store)
			if edge.is_empty():
				out.append("secret passage does not lie on a shared wall")
			elif absf(Vector2(door["pos"]).dot(Vector2(edge[0])) - float(edge[1])) > 0.05:
				out.append("secret passage is not centered on its shared wall")
		elif (a == store and b == dormitory) or (a == dormitory and b == store):
			has_store_dorm_door = true
		if bool(door.get("exterior", false)) and (a == store or a == dormitory or b == store or b == dormitory):
			out.append("hidden room has an exterior door")
	if secret_edges != 1:
		out.append("requires exactly one concealed sales-floor to store door")
	if not has_store_dorm_door:
		out.append("dormitory lacks its ordinary store-side door")
	for window in plan.windows:
		if int(window.get("room", -1)) == store or int(window.get("room", -1)) == dormitory:
			out.append("hidden room has an exterior window")
	var start := plan.entrance_room()
	var all_rooms := plan.reachable_rooms(start)
	var without_secrets := plan.reachable_rooms(start, &"", true, false)
	if not all_rooms.has(store) or not all_rooms.has(dormitory):
		out.append("secret-aware room graph cannot reach hidden rooms")
	if without_secrets.has(store) or without_secrets.has(dormitory):
		out.append("ordinary room graph reaches hidden rooms without secret door")
	if not plan.is_private_room(store) or not plan.is_private_room(dormitory):
		out.append("privacy model does not identify hidden rooms as private")
	return out


static func _int013_spec(business: StringName, scale: float) -> ShopSpec:
	var spec := ShopSpec.new()
	spec.business = business
	spec.style = &"longhall" if business in [&"alchemist_laboratory", &"school"] else &"townhouse"
	spec.width = 20.0 * scale
	spec.length = 26.0 * scale
	spec.height = 3.0
	return spec


static func _int013_contract_room(plan: HousePlan, business: StringName) -> int:
	var kind: StringName = &"laboratory" if business == &"alchemist_laboratory" else \
		&"bath_hall" if business == &"bathhouse" else \
		&"ward" if business == &"hospice" else &"schoolroom"
	return _room_of_kind(plan, kind)


static func _int013_failures(plan: HousePlan, business: StringName) -> Array[String]:
	var out: Array[String] = []
	var main_room := _int013_contract_room(plan, business)
	match business:
		&"alchemist_laboratory":
			if main_room < 0:
				out.append("missing laboratory")
				return out
			var benches: Array[int] = []
			for i in plan.furniture_of(main_room):
				if PropCatalog.category(plan.furniture[i]["key"]) == "workbench": benches.append(i)
			if benches.size() < 2: out.append("laboratory has fewer than two workbenches")
			var hosted := {}
			for i2 in plan.furniture_of(main_room):
				var placed: Dictionary = plan.furniture[i2]
				if PropCatalog.category(placed["key"]) == "alchemy" and benches.has(int(placed.get("host", -1))):
					hosted[int(placed["host"])] = true
			if hosted.size() < 2: out.append("alchemy is not carried across both benches")
			if not _has_room_category(plan, main_room, "cage"): out.append("missing cage")
			if not _has_room_category(plan, main_room, "hearth"): out.append("missing hearth")
		&"bathhouse":
			var changing := _room_of_kind(plan, &"changing_room")
			if changing < 0: out.append("missing changing_room")
			elif not _has_room_category(plan, changing, "bench"): out.append("changing room lacks bench")
			var tubs: Array[int] = []
			if main_room >= 0:
				for i3 in plan.furniture_of(main_room):
					if PropCatalog.category(plan.furniture[i3]["key"]) == "barrel": tubs.append(i3)
			if _largest_row(plan, tubs) < 2: out.append("tubs do not form a row of two or more")
		&"hospice":
			var dispensary := _room_of_kind(plan, &"dispensary")
			if main_room < 0: out.append("missing ward")
			else:
				var beds: Array[int] = []
				for i4 in plan.furniture_of(main_room):
					if PropCatalog.category(plan.furniture[i4]["key"]) == "bed": beds.append(i4)
				if _largest_row(plan, beds) < 2: out.append("ward bed row has fewer than two beds")
			if dispensary < 0: out.append("missing dispensary")
			elif not _has_room_category(plan, dispensary, "alchemy"): out.append("dispensary lacks alchemy")
		&"school":
			var office := _room_of_kind(plan, &"masters_office")
			if main_room < 0: out.append("missing schoolroom")
			else:
				var benches2: Array[int] = []
				for i5 in plan.furniture_of(main_room):
					if PropCatalog.category(plan.furniture[i5]["key"]) == "bench": benches2.append(i5)
				if _row_group_count(plan, benches2) < 2: out.append("schoolroom lacks two bench rows")
				if not _has_room_category(plan, main_room, "lectern"): out.append("schoolroom lacks lectern")
			if office < 0: out.append("missing master's office")
	return out


static func _has_room_category(plan: HousePlan, room: int, category: String) -> bool:
	for i in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[i]["key"]) == category: return true
	return false


static func _largest_row(plan: HousePlan, members: Array[int]) -> int:
	var groups := {}
	for i in members:
		var row := String(plan.furniture[i].get("row", ""))
		if row != "": groups[row] = int(groups.get(row, 0)) + 1
	var largest := 0
	for count in groups.values(): largest = maxi(largest, int(count))
	return largest


static func _row_group_count(plan: HousePlan, members: Array[int]) -> int:
	var groups := {}
	for i in members:
		var row := String(plan.furniture[i].get("row", ""))
		if row != "": groups[row] = int(groups.get(row, 0)) + 1
	var count := 0
	for size in groups.values():
		if int(size) >= 2: count += 1
	return count


## INT-017's bounded selector. It checks one real generated hall, its shell and
## walk plan, then mutates the authoring records to prove the new rule detects
## missing posts, drifted posts, and a lost entrance portal.
static func run_market_hall() -> SuiteResult:
	var res := SuiteResult.new("market hall colonnade")
	var spec := ShopSpec.new()
	spec.business = &"market_hall"
	spec.style = &"longhall"
	spec.width = 18.0
	spec.length = 28.0
	spec.height = 3.2
	var plan := ShopGenerator.generate(spec, 41717)
	var builder := HouseBuilder.new()
	builder.build(plan)
	res.checked += 1
	if not plan.has_kind(&"market_hall"):
		res.fail("market hall has no market_hall room")
	for fault in HouseQA.new().check(plan, builder)["failures"]:
		res.fail("market hall: %s" % String(fault))
	for component_fault in ComponentCheck.check(builder, builder.emitted_mesh)["failures"]:
		res.fail("market hall components: %s" % String(component_fault))
	for fault2 in shopfront_rules(spec, plan, builder):
		res.fail("market hall: %s" % fault2)
	_market_hall_contract(res, plan, builder)
	return res


static func _market_hall_contract(res: SuiteResult, plan: HousePlan,
		builder: HouseBuilder) -> void:
	var room := plan.entrance_room()
	if room < 0 or plan.kind_of(room) != &"market_hall":
		res.fail("market hall: street door does not enter its market hall")
		return
	var walls := HouseGeometry.room_walls(plan, room)
	var arcade_walls := 0
	var portal_walls := 0
	for wall in walls:
		if wall.get("kind", &"solid") == &"colonnade":
			arcade_walls += 1
			if not wall.get("portal", {}).is_empty():
				portal_walls += 1
	if arcade_walls < 4 or portal_walls != 1:
		res.fail("market hall: colonnade walls=%d entrance portals=%d, wants four arcade spans and one solid portal"
			% [arcade_walls, portal_walls])
	if plan.columns.size() < 8:
		res.fail("market hall: only %d columns are authored around the hall" % plan.columns.size())
	var post_masses := 0
	var lintel_masses := 0
	for mass in builder.mass_log:
		var mass_name := String(mass["name"])
		if mass_name.begins_with("colonnade_column_"):
			post_masses += 1
		elif mass_name.begins_with("colonnade_lintel_"):
			lintel_masses += 1
	if post_masses < plan.columns.size() or lintel_masses < 4:
		res.fail("market hall: structural log has %d posts and %d lintels for %d planned columns"
			% [post_masses, lintel_masses, plan.columns.size()])
	var emitted_posts := 0
	var emitted_lintels := 0
	for component in builder.component_log:
		var role := String(component.get("role", component.get("name", component.get("id", ""))))
		if role.contains("colonnade_column"):
			emitted_posts += 1
		elif role.contains("colonnade_lintel"):
			emitted_lintels += 1
	if emitted_posts < plan.columns.size() or emitted_lintels < 4:
		res.fail("market hall: mesh has %d posts and %d lintels for %d planned columns"
			% [emitted_posts, emitted_lintels, plan.columns.size()])
	_negative_market_hall_controls(res, plan)


static func _negative_market_hall_controls(res: SuiteResult, plan: HousePlan) -> void:
	var check := HousePlanCheck.new()
	if not check.check(plan)["failures"].is_empty():
		res.fail("market hall negative controls: valid source plan is already rejected")
		return
	var original_columns: Array[Dictionary] = plan.columns.duplicate(true)
	plan.columns.clear()
	var missing: Array = check.check(plan)["failures"]
	if not missing.any(func(row: String) -> bool: return row.begins_with("colonnade:")):
		res.fail("market hall negative control: removing all posts escaped plan validation")
	plan.columns = original_columns.duplicate(true)
	if not plan.columns.is_empty():
		var column_room := int(plan.columns[0]["room"])
		var column_wall := int(plan.columns[0]["wall"])
		var wall: Dictionary = HouseGeometry.room_walls(plan, column_room)[column_wall]
		var original_pos: Vector2 = plan.columns[0]["pos"]
		plan.columns[0]["pos"] = original_pos - Vector2(wall["normal"]) * 1.0
		var drifted: Array = check.check(plan)["failures"]
		if not drifted.any(func(row: String) -> bool: return row.contains("off wall")):
			res.fail("market hall negative control: moving a post off the wall escaped plan validation")
		plan.columns[0]["pos"] = original_pos
	var room := plan.entrance_room()
	if room >= 0:
		var old_portals: Dictionary = plan.rooms[room].get("wall_portals", {}).duplicate(true)
		plan.rooms[room]["wall_portals"] = {}
		var missing_portal: Array = check.check(plan)["failures"]
		if not missing_portal.any(func(row: String) -> bool: return row.contains("no solid portal")):
			res.fail("market hall negative control: removing the entrance portal escaped plan validation")
		plan.rooms[room]["wall_portals"] = old_portals


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
