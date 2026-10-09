class_name HouseFurnishPlacement
extends RefCounted
## Candidate construction and placement rules for furnished rooms.

## These bounds keep a large hall from turning a placement search into a
## quarter million floor probes.
const WALL_ESSENTIAL := ["bed", "hearth", "bookcase", "nightstand", "chest"]
const PROBE_STEP := 0.12
const MAX_PROBES := 128
## How far a seat may run past the side of the table it is drawn up to before
## it is not "at" that side any more. A chair at the end of a table fits; a
## 2.8 m bench across the end of a 1.1 m table does not.
const LONG_SEAT_OVERHANG := 0.3
## How deep into a room the approach to a door is kept clear of tables and
## other free-standing pieces, beyond the swing itself, and how far either
## side of the leaf. A table a hand's breadth past the swing still meets you
## as you come in (walk QA, 6 Oct).
const DOOR_APPROACH := 1.6
const DOOR_APPROACH_SIDE := 0.3
## Clear floor kept round a table before another table may stand there: a
## seat's depth and its pull-back space.
const TABLE_GAP := 1.1
## A cooking prep use zone belongs within the compositor task-reach limit of heat.
const MAX_COOKING_HEAT_GAP := 1.9

static func _seating_probe(plan: HousePlan, room: int, table: Dictionary,
		blocked: Array[Rect2], zones: Array[Rect2], seat_cat := "seat",
		seat_n := 1, retain_seat_set := false) -> Dictionary:
	if seat_n > 1 and not retain_seat_set:
		# Keep the established shared-family probe contract outside the domestic
		# overlay. Its callers retain the first tested seat as before.
		var trial := _seating_probe(plan, room, table, blocked, zones, seat_cat, 1)
		if trial.is_empty():
			return {}
		var occupied2 := blocked.duplicate()
		var used2 := zones.duplicate()
		var probe2 := HousePlan.new()
		probe2.spec = plan.spec
		probe2.rooms = plan.rooms
		probe2.doors = plan.doors
		probe2.windows = plan.windows
		HouseFurnishGeometry.commit(probe2, room, table.duplicate(), occupied2, used2)
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 0
		var key2: String = String(trial["key"])
		for _k in range(seat_n):
			place_around(probe2, room, key2, occupied2, used2, rng2)
		if probe2.furniture.size() < 1 + seat_n:
			return {}
		return trial
	if seat_n > 1 and retain_seat_set:
		# Test a complete seat set at this exact table pose and return those exact
		# placements. Reprobing a single chair later can choose the wrong side and
		# leave the table with fewer seats than the contract requires.
		# Choose the model for the whole set. A failed last chair must not silently
		# turn one place into a stool while the other places remain tall chairs.
		for seat_key in PropCatalog.of_category(seat_cat):
			var occupied2: Array[Rect2] = blocked.duplicate()
			var used2: Array[Rect2] = zones.duplicate()
			var probe2 := HousePlan.new()
			probe2.spec = plan.spec
			probe2.rooms = plan.rooms
			probe2.doors = plan.doors
			probe2.windows = plan.windows
			HouseFurnishGeometry.commit(probe2, room, table.duplicate(), occupied2, used2)
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 0
			var selected_seats: Array[Dictionary] = []
			for _seat_index in range(seat_n):
				var before: int = probe2.furniture.size()
				place_around(probe2, room, String(seat_key), occupied2, used2, rng2)
				if probe2.furniture.size() == before:
					break
				var placed_seat: Dictionary = probe2.furniture[-1].duplicate(true)
				var seat_pos: Vector3 = placed_seat["pos"]
				seat_pos.y = 0.0
				placed_seat["pos"] = seat_pos
				selected_seats.append(placed_seat)
			if selected_seats.size() == seat_n:
				return {"paired_seats": selected_seats}
		return {}
	var probe := HousePlan.new()
	probe.spec = plan.spec
	probe.rooms = plan.rooms
	probe.doors = plan.doors
	probe.windows = plan.windows
	# The candidate table is the only host being tested. Existing counters or
	# workbenches remain in blocked, but must not steal this trial's chair.
	var occupied := blocked.duplicate()
	var used := zones.duplicate()
	HouseFurnishGeometry.commit(probe, room, table.duplicate(), occupied, used)
	var count := probe.furniture.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	for key in PropCatalog.of_category(seat_cat):
		place_around(probe, room, key, occupied, used, rng)
		if probe.furniture.size() > count:
			var seat: Dictionary = probe.furniture[-1].duplicate()
			seat["pos"].y = 0.0 # the final commit supplies the room elevation
			return seat
	return {}


## Is there already something in this room that the room could not do without?
static func _has_other_must(plan: HousePlan, room: int) -> bool:
	for f in plan.furniture_of(room):
		if plan.furniture[f].get("must", false):
			return true
	return false


## Could this room take a piece of that kind AT ALL -- in an empty version of
## itself, with only its doors to work round?
##
## The furnishing check needs to tell "the generator failed to place a bed"
## from "no bed will fit in this room", and the only honest way to answer that
## is to run the real placer on an empty copy of the room. A rule of thumb
## about areas gets it wrong in exactly the rooms that matter: the small ones
## with two doors in them.
static func could_place(plan: HousePlan, room: int, cat: String) -> bool:
	var choices: Array[String] = PropCatalog.of_category(cat)
	if choices.is_empty():
		return false
	var probe := HousePlan.new()
	probe.spec = plan.spec
	probe.rooms = plan.rooms
	probe.doors = plan.doors
	probe.windows = plan.windows
	probe.hearth = plan.hearth.duplicate(true)
	if cat == "hearth":
		probe.hearth.erase("breast")
	probe.focus = plan.focus.duplicate()
	probe.furniture = []
	var r := RandomNumberGenerator.new()
	r.seed = 1
	var blocked: Array[Rect2] = initial_blocked(probe, room)
	var zones: Array[Rect2] = []
	for key in choices:
		var before: int = probe.furniture.size()
		# a bed, a hearth or a bookcase is only ever placed against a wall
		# (WALL_ESSENTIAL): a room that could take one in its middle and
		# nowhere else cannot take one
		var rules: Array = [&"wall"] if cat in WALL_ESSENTIAL else [&"wall", &"free", &"corner"]
		for rule in rules:
			match rule:
				&"wall":
					_place_against_wall(probe, room, key, blocked, zones, r)
				&"free":
					place_free(probe, room, key, blocked, zones, r)
				&"corner":
					_place_corner(probe, room, key, blocked, zones, r)
			if probe.furniture.size() > before:
				return true
	return false


## The floor that is spoken for before any furniture arrives: the swing of
## every door into this room, and a strip in front of every window.
static func initial_blocked(plan: HousePlan, room: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var breast := HouseGeometry.hearth_breast(plan)
	if not breast.is_empty() and int(breast["room"]) == room:
		out.append(breast["rect"])
	# Floor the plan itself keeps clear -- a screens passage, a processional
	# aisle. It is occupied ground before the first piece is placed, so a
	# passage the plan drew is a passage the furnishing cannot fill in.
	out.append_array(plan.zones_of(room))
	for d in plan.doors_of(room):
		var door: Dictionary = plan.doors[d]
		for side in [-1.0, 1.0]:
			out.append(HouseGeometry.door_clear_rect(door, side))
	# A stair landing is circulation infrastructure, not furniture space. Keep
	# both landings clear while placing rooms on either end of the stair.
	for stair in plan.stairs:
		if int(stair.get("a", -1)) == room:
			if stair.has("lower_rect"):
				out.append(Rect2(stair["lower_rect"]))
			elif stair.has("rect"):
				out.append(Rect2(stair["rect"]))
		if int(stair.get("b", -1)) == room:
			if stair.has("upper_rect"):
				out.append(Rect2(stair["upper_rect"]))
			elif stair.has("rect"):
				out.append(Rect2(stair["rect"]))
	return out


## Windows only block furniture that would stand IN them. A chest under a
## window is fine; a bookcase across it is not.
static func _window_blocks(plan: HousePlan, room: int, key: String,
		height_scale := -1.0) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var actual_height: float = PropCatalog.height(key)
	if height_scale >= 0.0:
		actual_height *= height_scale
	if actual_height <= HouseGeometry.WINDOW_SILL:
		return out
	for w in plan.windows_of(room):
		out.append(HouseGeometry.window_clear_rect(plan.windows[w]))
	return out


static func place_one(plan: HousePlan, spec: HouseSpec, room: int, cat: String,
		rule: StringName, blocked: Array[Rect2], zones: Array[Rect2],
		r: RandomNumberGenerator, step: Dictionary = {}) -> void:
	var choices: Array[String] = PropCatalog.of_category(cat)
	if step.has("key"):
		var exact_key := String(step["key"])
		if not choices.has(exact_key):
			return
		choices = [exact_key]
	else:
		choices = PropCatalog.of_category_for_room(cat, plan.kind_of(room))
	if choices.is_empty():
		return
	var key: String = choices[r.randi_range(0, choices.size() - 1)]
	var before_place: int = plan.furniture.size()
	var original_blocked_count: int = blocked.size()
	var borrowed_band_count := _borrow_activity_band(plan, room,
		String(step.get("group", "")), blocked)
	var witch_trace: bool = bool(plan.domestic_layout.get("_witch_placement_trace", false)) and HouseFurnishingRecipes.is_ordinary_house(plan) and plan.spec.style == &"witch_hut" and plan.spec.trade == &"none" and String(step.get("group", "")) in ["cooking", "witchwork", "eating", "sleep"]
	if witch_trace:
		print("WITCH_STEP_BEGIN room=", room, " category=", cat, " key=", key, " group=", step.get("group", ""), " rule=", rule, " blocked=", blocked.size(), " zones=", zones.size(), " blocked_rects=", str(blocked), " usezones=", str(zones))
	var retry_compact_witch_sleep_chest: bool = HouseFurnishingRecipes.is_ordinary_house(plan) \
		and plan.spec.style == &"witch_hut" and plan.spec.trade == &"none" \
		and String(step.get("group", "")) == "sleep" and cat == "chest" \
		and plan.kind_of(room) == &"bedroom" \
		and plan.domestic_layout.get("added_activities", []).has(&"store")
	match rule:
		&"wall":
			var had: int = plan.furniture.size()
			_wall_clear_of_doors(plan, room, key, blocked, zones, r, step)
			if plan.furniture.size() == had and retry_compact_witch_sleep_chest:
				# Retry the originally selected measured chest first, with a new
				# bounded deterministic search stream. The initial attempt may have
				# missed a valid wall pose even when the catalogue has one key only.
				var retry_keys: Array[String] = [key]
				for candidate_key in choices:
					if candidate_key != key:
						retry_keys.append(candidate_key)
				for retry_index in range(retry_keys.size()):
					var retry_key: String = retry_keys[retry_index]
					var trial := HouseFurnisher._meal_probe_plan(plan)
					trial.furniture = plan.furniture.duplicate(true)
					var trial_blocked: Array[Rect2] = blocked.duplicate()
					var trial_zones: Array[Rect2] = zones.duplicate()
					var chest_retry := RandomNumberGenerator.new()
					chest_retry.seed = int(plan.spec.seed) * 7919 + room * 104729 + 17 + retry_index * 65537
					var retry_step: Dictionary = step.duplicate(true)
					retry_step["key"] = retry_key
					_wall_clear_of_doors(trial, room, retry_key, trial_blocked,
						trial_zones, chest_retry, retry_step)
					if trial.furniture.size() == had:
						continue
					var nav := HouseNavCheck.new().check(trial)
					if not bool(nav.get("ok", false)):
						continue
					var added_blocked: Array[Rect2] = trial_blocked.slice(blocked.size())
					var added_zones: Array[Rect2] = trial_zones.slice(zones.size())
					plan.furniture = trial.furniture
					blocked.append_array(added_blocked)
					zones.append_array(added_zones)
					break
			_flag_door_approach(plan, room, had)
			var compact_witchwork_wall: bool = _requires_compact_witchwork_wall(plan, room, key, step)
			if plan.furniture.size() == had and not cat in WALL_ESSENTIAL and not compact_witchwork_wall:
				var required_cooking_store: bool = HouseFurnishingRecipes.is_ordinary_house(plan) \
					and String(step.get("group", "")) == "cooking" \
					and cat == "storage"
				var required_sleep_storage: bool = HouseFurnishingRecipes.is_ordinary_house(plan) \
					and String(step.get("group", "")) == "sleep" \
					and cat == "chest" \
					and String(step.get("near_anchor", "")) != "head_end"
				if not required_cooking_store and not required_sleep_storage:
					# no wall will take it. A workbench can stand out in the room --
					# a bed cannot, which is what WALL_ESSENTIAL is for -- and the
					# placement records that it did, so the check that wants a wall
					# behind it knows why there is none.
					place_free(plan, room, key, blocked, zones, r, false, "seat", 1,
						false, float(step.get("height_scale", -1.0)))
					if plan.furniture.size() > had:
						plan.furniture[-1]["free_standing"] = true
			elif plan.furniture.size() == had and (compact_witchwork_wall or _forced_wall(plan, room, key) >= 0):
				# the wall the flue rises on would not take it, and a fire
				# under no chimney is worse than no fire: the room goes
				# without and writes down that it did
				plan.note_compromise(room, cat)
		&"free":
			var before: int = plan.furniture.size()
			var seat_cat := String(step.get("seat_cat", ""))
			if seat_cat != "":
				# a table the recipe means to seat is stood where its seats
				# will go, the first of them drawn up with it; a table stood
				# on the best open floor and THEN found to have no room for a
				# bench was a barracks mess's second table, dropped again
				var seat_n := int(step.get("seat_n", 1))
				var placement_height_scale := -1.0
				if HouseFurnishingRecipes.is_ordinary_house(plan) \
						and String(step.get("group", "")) == "eating" \
						and HouseFurnishingRecipes.dining_room_of(plan) == room:
					placement_height_scale = 1.0
				place_free(plan, room, key, blocked, zones, r, true, seat_cat, seat_n,
					bool(step.get("seat_n_required", false)), placement_height_scale)
				if plan.furniture.size() == before \
						and HouseFurnishingRecipes.is_ordinary_house(plan) \
						and plan.spec.style == &"witch_hut" and plan.spec.trade == &"none" \
						and String(step.get("group", "")) == "eating" \
						and HouseFurnishingRecipes.dining_room_of(plan) == room \
						and _has_compact_witch_shared_meal_contract(plan, room) \
						and bool(step.get("seat_n_required", false)):
					_retry_compact_witch_meal_group(plan, room, choices, key,
						blocked, zones, step)
				if plan.furniture.size() == before and seat_n > 1 \
						and not bool(step.get("seat_n_required", false)):
					place_free(plan, room, key, blocked, zones, r, true, seat_cat, 1)
			if plan.furniture.size() == before and not bool(step.get("seat_n_required", false)):
				place_free(plan, room, key, blocked, zones, r)
			if plan.furniture.size() == before and not bool(step.get("seat_n_required", false)):
				# no room to stand it clear of the walls; against one is better
				# than not at all, and is what a small cottage does
				_wall_clear_of_doors(plan, room, key, blocked, zones, r, step)
				_flag_door_approach(plan, room, before)
		&"corner":
			_place_corner(plan, room, key, blocked, zones, r,
				float(step.get("zone_depth_override", -1.0)))
		&"around":
			place_around(plan, room, key, blocked, zones, r,
				String(step.get("host", "")) == "row")
		&"beside":
			_place_beside(plan, room, key, step, blocked, zones)
		&"behind":
			_place_behind(plan, room, key, blocked, zones, r)
		&"mounted":
			HouseFurnishSurface.place_mounted(plan, room, key, r, String(step.get("group", "")))
		&"ceiling":
			HouseFurnishSurface.place_ceiling(plan, room, key)
		&"on":
			var preferred_host_category: String = String(step.get("host_category", ""))
			var ordinary_cooking_tool := HouseFurnishingRecipes.is_ordinary_house(plan) \
				and String(step.get("group", "")) == "cooking" \
				and preferred_host_category == "workbench"
			var no_trade_witchwork_book := HouseFurnishingRecipes.is_ordinary_house(plan) \
				and plan.spec.style == &"witch_hut" \
				and plan.spec.trade == &"none" \
				and String(step.get("group", "")) == "witchwork" \
				and cat == "books" and preferred_host_category == "workbench"
			if no_trade_witchwork_book:
				_place_witchwork_book_on_support(plan, room, choices, key, preferred_host_category)
			elif _has_compact_witch_shared_meal_contract(plan, room) \
					and String(step.get("group", "")) == "witchwork" and cat == "alchemy":
				_place_on_preferred_category(plan, room, key, "workbench", r,
					String(step.get("group", "")))
			elif ordinary_cooking_tool:
				_place_on_preferred_category(plan, room, key, preferred_host_category, r,
					String(step.get("group", "")))
			else:
				HouseFurnishSurface.place_on_surface(plan, room, key, r,
					String(step.get("host", "")) in ["row", "distributed"])
	_restore_borrowed_blocks(blocked, original_blocked_count, borrowed_band_count)
	if witch_trace:
		print("WITCH_STEP_END room=", room, " category=", cat, " key=", key, " group=", step.get("group", ""), " placed=", plan.furniture.size() - before_place, " added=", str(plan.furniture.slice(before_place)), " blocked_after=", str(blocked), " zones_after=", str(zones))
	# The first focus piece placed writes back where it actually stood, so the
	# check compares the plan with the furniture rather than with itself.
	if plan.furniture.size() > before_place and plan.focus_room() == room \
			and plan.focus_cat() == cat and not plan.focus.get("placed", false):
		var placed: Dictionary = plan.furniture[-1]
		plan.focus["pos"] = Rect2(placed["rect"]).get_center()
		plan.focus["facing"] = float(placed["yaw"])
		plan.focus["placed"] = true
	# A room that could not fit something it needed, because it was already
	# holding the other things it needed, has made a compromise rather than a
	# mistake -- and it is only a compromise if there WAS something else. A bed
	# missing from an empty bedroom is still a defect, and still fails.
	if float(step.get("opt", 0.0)) >= 1.0 and plan.furniture.size() == before_place \
			and _has_other_must(plan, room):
		plan.note_compromise(room, cat)


## Restrict an activity group to its authored clear-floor band. The complement
## is borrowed as blocked space so the normal fit path also keeps use zones in
## the band. Returns the number of temporary rectangles appended.
## Compact no-trade Witch meal groups retry the actual table set as a unit.
## Each catalogue table is probed with its required seats against the current
## furniture, door reservations and borrowed meal band. Only a complete,
## navigable group is copied back. This is bounded by the table catalogue.
static func _has_compact_witch_shared_meal_contract(plan: HousePlan, room: int) -> bool:
	if not HouseFurnishingRecipes.is_ordinary_house(plan) or plan.spec.style != &"witch_hut" or plan.spec.trade != &"none":
		return false
	if room < 0 or room >= plan.rooms.size() or plan.kind_of(room) != &"hall":
		return false
	var room_data: Dictionary = plan.rooms[room]
	var functions: Array = room_data.get("domestic_functions", [])
	var station: Dictionary = room_data.get("shared_activity_station", {})
	var groups: Array = station.get("groups", [])
	var regions: Dictionary = room_data.get("activity_regions", {})
	return bool(room_data.get("shared_cooking", false)) \
		and bool(room_data.get("shared_witchwork", false)) \
		and functions.has(&"cooking") and functions.has(&"witchwork") \
		and String(station.get("id", "")) == "compact_witch_hearth" \
		and String(station.get("scope", "")) == "compact_witch_shared_hall" \
		and String(station.get("category", "")) == "hearth" \
		and groups.has(&"cooking") and groups.has(&"witchwork") \
		and regions.has(&"eating") and regions.has(&"cooking") and regions.has(&"witchwork")


static func _compact_witch_bench_replays_required_core(plan: HousePlan, room: int,
		bench: Dictionary, blocked: Array[Rect2], zones: Array[Rect2],
		rng: RandomNumberGenerator) -> bool:
	if not _has_compact_witch_shared_meal_contract(plan, room):
		return false
	var probe := HouseFurnisher._meal_probe_plan(plan)
	probe.furniture = plan.furniture.duplicate(true)
	var bench_piece: Dictionary = bench.duplicate(true)
	bench_piece["activity_group"] = "witchwork"
	var probe_blocked: Array[Rect2] = blocked.duplicate()
	# _place_against_wall is called while the Witchwork band is borrowed.
	# Restore precisely that temporary complement before replaying the next
	# recipe steps; each place_one call will borrow its own activity band.
	var band_count_probe: Array[Rect2] = []
	var witch_band_count: int = _borrow_activity_band(plan, room, "witchwork", band_count_probe)
	if witch_band_count > 0 and probe_blocked.size() >= witch_band_count:
		probe_blocked.resize(probe_blocked.size() - witch_band_count)
	var probe_zones: Array[Rect2] = zones.duplicate()
	HouseFurnishGeometry.commit(probe, room, bench_piece, probe_blocked, probe_zones)
	var cooking_steps: Array[Dictionary] = []
	var recipe: Array = HouseFurnishingRecipes.recipe_for_room(plan, room)
	var found_witch_bench := false
	for step_variant in recipe:
		var recipe_step: Dictionary = step_variant
		if not found_witch_bench:
			if String(recipe_step.get("cat", "")) == "workbench" \
					and String(recipe_step.get("group", "")) == "witchwork":
				found_witch_bench = true
			continue
		var category: String = String(recipe_step.get("cat", ""))
		if String(recipe_step.get("group", "")) == "cooking" \
				and category in ["hearth", "storage", "workbench", "bucket", "cookware"]:
			cooking_steps.append(recipe_step.duplicate(true))
			if cooking_steps.size() == 5:
				break
	if cooking_steps.size() != 5:
		return false
	var trial_rng := RandomNumberGenerator.new()
	trial_rng.state = rng.state
	for recipe_step in cooking_steps:
		var category: String = String(recipe_step.get("cat", ""))
		var rule: StringName = StringName(recipe_step.get("rule", ""))
		var before_step := probe.furniture.size()
		place_one(probe, probe.spec, room, category, rule,
			probe_blocked, probe_zones, trial_rng, recipe_step)
		if probe.furniture.size() == before_step:
			return false
		HouseFurnisher._set_activity_group(probe.furniture[-1], recipe_step)
	var nav: Dictionary = HouseNavCheck.new().check(probe)
	if nav.get("unreached_rooms", []).has(room):
		return false
	return true


static func _requires_compact_witchwork_wall(plan: HousePlan, room: int,
		key: String, step: Dictionary) -> bool:
	return PropCatalog.category(key) == "workbench" \
		and String(step.get("group", "")) == "witchwork" \
		and _has_compact_witch_shared_meal_contract(plan, room)


static func _retry_compact_witch_meal_group(plan: HousePlan, room: int,
		choices: Array[String], first_key: String, blocked: Array[Rect2],
		zones: Array[Rect2], step: Dictionary) -> bool:
	var candidates: Array[String] = [first_key]
	for table_key in choices:
		if table_key != first_key:
			candidates.append(table_key)
	var seat_cat := String(step.get("seat_cat", "seat"))
	var seat_n := int(step.get("seat_n", 1))
	for candidate_index in range(candidates.size()):
		var candidate_key: String = candidates[candidate_index]
		var probe := HouseFurnisher._meal_probe_plan(plan)
		probe.furniture = plan.furniture.duplicate(true)
		var probe_blocked: Array[Rect2] = blocked.duplicate()
		var probe_zones: Array[Rect2] = zones.duplicate()
		var rng := RandomNumberGenerator.new()
		rng.seed = int(plan.spec.seed) * 7919 + room * 104729 + candidate_index * 65537
		var before: int = probe.furniture.size()
		place_free(probe, room, candidate_key, probe_blocked, probe_zones, rng,
			true, seat_cat, seat_n, true, 1.0)
		if probe.furniture.size() - before != seat_n + 1:
			continue
		var nav := HouseNavCheck.new().check(probe)
		if not bool(nav.get("ok", false)):
			continue
		var added_blocked: Array[Rect2] = probe_blocked.slice(blocked.size())
		var added_zones: Array[Rect2] = probe_zones.slice(zones.size())
		for index in range(before, probe.furniture.size()):
			plan.furniture.append(probe.furniture[index].duplicate(true))
		blocked.append_array(added_blocked)
		zones.append_array(added_zones)
		return true
	return false


static func _borrow_activity_band(plan: HousePlan, room: int, group: String,
		blocked: Array[Rect2]) -> int:
	if group.is_empty() or room < 0 or room >= plan.rooms.size():
		return 0
	var regions: Dictionary = plan.rooms[room].get("activity_regions", {})
	if not regions.has(StringName(group)):
		return 0
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var region: Rect2 = Rect2(regions[StringName(group)]).intersection(floor_rect)
	if not region.has_area():
		return 0
	var start_count: int = blocked.size()
	var top := Rect2(floor_rect.position, Vector2(floor_rect.size.x,
		region.position.y - floor_rect.position.y))
	var bottom := Rect2(Vector2(floor_rect.position.x, region.end.y),
		Vector2(floor_rect.size.x, floor_rect.end.y - region.end.y))
	var left := Rect2(Vector2(floor_rect.position.x, region.position.y),
		Vector2(region.position.x - floor_rect.position.x, region.size.y))
	var right := Rect2(Vector2(region.end.x, region.position.y),
		Vector2(floor_rect.end.x - region.end.x, region.size.y))
	for complement in [top, bottom, left, right]:
		var rect: Rect2 = complement
		if rect.size.x > 0.001 and rect.size.y > 0.001:
			blocked.append(rect)
	return blocked.size() - start_count


## Remove only the borrowed complement, retaining every furniture footprint
## committed by the placement strategy while it was active.
static func _restore_borrowed_blocks(blocked: Array[Rect2], original_count: int,
		borrowed_count: int) -> void:
	if borrowed_count <= 0:
		return
	var committed: Array[Rect2] = blocked.slice(original_count + borrowed_count)
	blocked.resize(original_count)
	blocked.append_array(committed)


## Place a piece beside an earlier activity component. The relation is measured
## from the host and candidate bounds, then subjected to the ordinary overlap
## and use-zone test; it cannot waive clearance.
static func _place_beside(plan: HousePlan, room: int, key: String,
		step: Dictionary, blocked: Array[Rect2], zones: Array[Rect2]) -> void:
	var wanted_cat: String = String(step.get("near_cat", ""))
	if wanted_cat.is_empty():
		return
	var host: Dictionary = {}
	for piece in plan.furniture:
		if int(piece["room"]) == room and String(piece["cat"]) == wanted_cat:
			host = piece
			break
	if host.is_empty():
		return
	if HouseFurnishingRecipes.is_ordinary_house(plan) \
			and String(step.get("group", "")) == "cooking" \
			and String(step.get("cat", "")) == "workbench" \
			and host.has("paired_workbench"):
		var paired: Dictionary = Dictionary(host["paired_workbench"]).duplicate(true)
		host.erase("paired_workbench")
		paired["activity_group"] = "cooking"
		paired["activity_host_cat"] = "storage"
		HouseFurnishGeometry.commit(plan, room, paired, blocked, zones)
		return
	var host_rect := Rect2(host["rect"])
	var host_center := host_rect.get_center()
	var head_dir := Vector2.ZERO
	if String(step.get("near_anchor", "")) == "head_end" and wanted_cat == "bed":
		# Bed models are placed with the headboard on the back (+Z) side. The
		# plan yaw therefore gives a real head-end anchor; a cardinal offset
		# from the bed centre can otherwise leave a bedside item at mid-bed.
		var host_yaw: float = float(host.get("yaw", 0.0))
		# Godot's positive Y rotation maps Vector3.BACK (+Z) to
		# (+sin(yaw), cos(yaw)) in the plan's X/Z plane.
		var head_world: Vector3 = Basis(Vector3.UP, host_yaw) * Vector3.BACK
		head_dir = Vector2(head_world.x, head_world.z).normalized()
		var is_ordinary_bedside: bool = HouseFurnishingRecipes.is_ordinary_house(plan) \
			and String(step.get("group", "")) == "sleep" \
			and String(step.get("cat", "")) == "nightstand" \
			and key == "Nightstand_Shelf"
		var bedside := _head_support_candidate(plan, room, key, host, blocked, zones,
			0.8 if is_ordinary_bedside else -1.0,
			0.62 if is_ordinary_bedside else 1.0, is_ordinary_bedside)
		if not bedside.is_empty():
			HouseFurnishGeometry.commit(plan, room, bedside, blocked, zones)
		return
	if bool(step.get("align_back", false)):
		var height_scale := -1.0
		var cooking_prep_member: bool = false
		if HouseFurnishingRecipes.is_ordinary_house(plan) \
				and String(step.get("group", "")) == "cooking" \
				and String(step.get("cat", "")) == "workbench":
			cooking_prep_member = true
			if String(step.get("cat", "")) == "workbench":
				height_scale = 1.0
		var aligned := _aligned_beside_candidate(plan, room, key, host, blocked, zones, height_scale)
		if aligned.is_empty() and cooking_prep_member:
			aligned = _l_shaped_prep_candidate(plan, room, key, host, blocked, zones, height_scale)
		if aligned.is_empty() and cooking_prep_member:
			aligned = _opposed_prep_candidate(plan, room, key, host, blocked, zones, height_scale)
		if aligned.is_empty() and HouseFurnishingRecipes.is_ordinary_house(plan) \
				and String(step.get("group", "")) == "cooking" \
				and String(step.get("cat", "")) == "bucket":
			# A water vessel can stand just beyond the cabinet's standing zone.
			# It has neither a working front nor a use-zone aisle of its own.
			var vessel := _opposed_prep_candidate(plan, room, key, host, blocked, zones)
			if not vessel.is_empty() and HouseFurnisher._rect_edge_distance(
					Rect2(vessel["rect"]), Rect2(host["rect"])) <= 1.0:
				vessel["activity_relation"] = "beside_work_zone"
				aligned = vessel
		if not aligned.is_empty():
			HouseFurnishGeometry.commit(plan, room, aligned, blocked, zones)
		return
	for scale in HouseFurnishGeometry.scales(key):
		for yaw in [0.0, PI / 2.0, PI, PI * 1.5]:
			var probe := HouseFurnishGeometry.candidate(key, host_center, float(yaw), 1.0, float(scale))
			var candidate_rect := Rect2(probe["rect"])
			if head_dir != Vector2.ZERO:
				continue
			var offsets: Array[Vector2] = [
				Vector2(-(host_rect.size.x + candidate_rect.size.x) / 2.0 - 0.06, 0.0),
				Vector2((host_rect.size.x + candidate_rect.size.x) / 2.0 + 0.06, 0.0),
				Vector2(0.0, -(host_rect.size.y + candidate_rect.size.y) / 2.0 - 0.06),
				Vector2(0.0, (host_rect.size.y + candidate_rect.size.y) / 2.0 + 0.06),
			]
			for offset in offsets:
				var center := host_center + offset
				var candidate := HouseFurnishGeometry.candidate(key, center, float(yaw), 1.0, float(scale))
				if HouseFurnishGeometry.fits(plan, room, candidate,
						HouseGeometry.room_floor_rect(plan, room), blocked, zones, []):
					HouseFurnishGeometry.commit(plan, room, candidate, blocked, zones)
					return


## A required Witchwork book must use a measured Witchwork workbench. The selected
## model may be too long at the random yaw, so try the full measured category in
## stable order and all eight quarter/diagonal orientations before recording a
## shortfall. Nothing falls back to the floor.
static func _place_witchwork_book_on_support(plan: HousePlan, room: int,
		choices: Array[String], first_key: String, preferred_category: String) -> void:
	var keys: Array[String] = [first_key]
	for candidate_key in choices:
		if candidate_key != first_key:
			keys.append(candidate_key)
	for host_index in plan.furniture_of(room):
		var host: Dictionary = plan.furniture[host_index]
		if String(host.get("cat", "")) != preferred_category or String(host.get("activity_group", "")) != "witchwork":
			continue
		var host_key := String(host["key"])
		if not PropCatalog.has_tag(host_key, PropCatalog.SURFACE) or bool(host.get("mounted", false)):
			continue
		var host_scale := float(host.get("scale", 1.0))
		var host_height_scale := PropCatalog.placement_height_scale(host)
		var host_origin := PropCatalog.house_origin(host)
		var surface_top := host_origin.y + PropCatalog.floor_offset(host_key) * host_height_scale
		surface_top += PropCatalog.surface_height(host_key) * host_height_scale
		var host_yaw := float(host.get("yaw", 0.0)) + PropCatalog.face_offset(host_key)
		var host_centre := PropCatalog.plan_centre(host_key, host_origin, host_yaw, host_scale)
		var host_size := PropCatalog.footprint_rotated(host_key, host_yaw) * host_scale
		var support_rect := Rect2(host_centre - host_size * 0.5, host_size)
		for book_key in keys:
			for scale in HouseFurnishGeometry.scales(book_key):
				for orientation in range(8):
					var yaw := TAU * float(orientation) / 8.0
					var physical_yaw := yaw + PropCatalog.face_offset(book_key)
					var foot: Vector2 = PropCatalog.footprint_rotated(book_key, physical_yaw) * float(scale)
					var margin := 0.06
					var lo := support_rect.position + foot * 0.5 + Vector2.ONE * margin
					var hi := support_rect.end - foot * 0.5 - Vector2.ONE * margin
					if lo.x > hi.x or lo.y > hi.y:
						continue
					for ix in range(5):
						for iz in range(5):
							var desired_centre := Vector2(lerpf(lo.x, hi.x, float(ix) / 4.0),
								lerpf(lo.y, hi.y, float(iz) / 4.0))
							var piece := {
								"key": book_key, "room": room,
								"storey": HousePlan.record_storey(plan.rooms[room]),
								"pos": Vector3(desired_centre.x, surface_top, desired_centre.y),
								"yaw": yaw, "scale": float(scale), "host": host_index,
								"cat": PropCatalog.category(book_key), "mounted": false}
							var book_origin := PropCatalog.house_origin(piece)
							var book_bottom := book_origin.y + PropCatalog.floor_offset(book_key) * PropCatalog.placement_height_scale(piece)
							if absf(book_bottom - surface_top) > 0.02:
								continue
							var book_centre := PropCatalog.plan_centre(book_key, book_origin, physical_yaw, float(scale))
							var rect := Rect2(book_centre - foot * 0.5, foot)
							if not support_rect.grow(-0.02).encloses(rect):
								continue
							var clash := false
							for placed in plan.furniture_of(room):
								if int(plan.furniture[placed].get("host", -1)) == host_index and Rect2(plan.furniture[placed]["rect"]).intersects(rect):
									clash = true
									break
							if clash:
								continue
							piece["rect"] = rect
							piece["zone"] = Rect2()
							plan.furniture.append(piece)
							return


## Cooking tools belong on the work surface that was planned for them, rather
## than whichever unrelated prop happened to win the random host draw.
static func _place_on_preferred_category(plan: HousePlan, room: int, key: String,
		preferred_category: String, r: RandomNumberGenerator, group_name := "") -> void:
	var group_bound_hosts := _has_compact_witch_shared_meal_contract(plan, room)
	var hosts: Array[int] = []
	for index in plan.furniture_of(room):
		var host: Dictionary = plan.furniture[index]
		if (String(host.get("cat", "")) == preferred_category
				and PropCatalog.has_tag(String(host["key"]), PropCatalog.SURFACE)
				and not bool(host.get("mounted", false))
				and (not group_bound_hosts or String(host.get("activity_group", "")) == group_name)):
			hosts.append(index)
	if hosts.is_empty():
		return
	var host_index: int = hosts[0]
	var host: Dictionary = plan.furniture[host_index]
	var host_rect: Rect2 = Rect2(host["rect"])
	var host_scale: float = PropCatalog.placement_height_scale(host)
	var top: float = float(host["pos"].y) \
		+ PropCatalog.surface_height(String(host["key"])) * host_scale
	for scale in HouseFurnishGeometry.scales(key):
		for _orientation_try in range(8):
			var yaw := r.randf() * TAU
			var physical_yaw: float = yaw + PropCatalog.face_offset(key)
			var foot: Vector2 = PropCatalog.footprint_rotated(key, physical_yaw) * float(scale)
			var margin := 0.06
			var lo := host_rect.position + foot * 0.5 + Vector2.ONE * margin
			var hi := host_rect.end - foot * 0.5 - Vector2.ONE * margin
			if lo.x > hi.x or lo.y > hi.y:
				continue
			for tries in range(8):
				var center := Vector2(lerpf(lo.x, hi.x, r.randf()), lerpf(lo.y, hi.y, r.randf()))
				var rect := Rect2(center - foot / 2.0, foot)
				var clash := false
				for placed in plan.furniture_of(room):
					if int(plan.furniture[placed].get("host", -1)) == host_index \
							and Rect2(plan.furniture[placed]["rect"]).intersects(rect):
						clash = true
						break
				if clash:
					continue
				plan.furniture.append({
					"key": key, "room": room, "storey": HousePlan.record_storey(plan.rooms[room]),
					"pos": Vector3(center.x, top, center.y), "yaw": yaw,
					"rect": rect, "zone": Rect2(), "host": host_index,
					"cat": PropCatalog.category(key), "mounted": false, "scale": float(scale),
				})
				return


## Return a bedside chest candidate without committing it. The bed-wall search
## calls this first, so it only accepts bed positions that can take the whole
## sleep pair with a usable approach.
static func _head_support_candidate(plan: HousePlan, room: int, key: String,
		host: Dictionary, blocked: Array[Rect2], zones: Array[Rect2],
		max_height := -1.0, min_scale := 1.0, ordinary_bedside := false) -> Dictionary:
	var host_rect: Rect2 = Rect2(host["rect"])
	var host_center: Vector2 = host_rect.get_center()
	var head_world: Vector3 = Basis(Vector3.UP, float(host.get("yaw", 0.0))) * Vector3.BACK
	var head_dir := Vector2(head_world.x, head_world.z).normalized()
	if head_dir == Vector2.ZERO:
		return {}
	var side_dir := Vector2(-head_dir.y, head_dir.x)
	var host_radius: float = absf(head_dir.x) * host_rect.size.x * 0.5 \
		+ absf(head_dir.y) * host_rect.size.y * 0.5
	var host_side_radius: float = absf(side_dir.x) * host_rect.size.x * 0.5 \
		+ absf(side_dir.y) * host_rect.size.y * 0.5
	var support_scales: Array = HouseFurnishGeometry.scales(key)
	if max_height > 0.0 or min_scale > PropCatalog.min_scale(key):
		support_scales = []
		for scale in HouseFurnishGeometry.SCALE_STEPS:
			if float(scale) + 0.001 < min_scale:
				continue
			if max_height > 0.0 and PropCatalog.height(key) * float(scale) > max_height + 0.001:
				continue
			support_scales.append(float(scale))
	for scale in support_scales:
		for yaw in [0.0, PI / 2.0, PI, PI * 1.5]:
			var probe := HouseFurnishGeometry.candidate(key, host_center, float(yaw), 1.0, float(scale))
			var candidate_rect: Rect2 = Rect2(probe["rect"])
			var item_radius: float = absf(head_dir.x) * candidate_rect.size.x * 0.5 \
				+ absf(head_dir.y) * candidate_rect.size.y * 0.5
			var item_side_radius: float = absf(side_dir.x) * candidate_rect.size.x * 0.5 \
				+ absf(side_dir.y) * candidate_rect.size.y * 0.5
			var facing := HouseFurnishScore._facing_of(float(yaw)).normalized()
			for side_sign in [-1.0, 1.0]:
				var outward: Vector2 = side_dir * float(side_sign)
				# Ordinary bedside shelves back onto the head-wall line and face the bed foot.
				var required_facing: Vector2 = -head_dir if ordinary_bedside else outward
				if facing.dot(required_facing) < 0.99:
					continue
				for gap in [0.06, 0.12, 0.18]:
					for head_slide in ([0.0] if ordinary_bedside else [0.0, 0.2, 0.4, 0.6, 0.8]):
						var head_offset: float = host_radius - item_radius - head_slide
						if head_offset + item_radius < host_radius / 3.0:
							continue
						var center := host_center + head_dir * head_offset \
							+ outward * (host_side_radius + item_side_radius + float(gap))
						var candidate := HouseFurnishGeometry.candidate(key, center,
							float(yaw), 1.0, float(scale))
						if ordinary_bedside and not _ordinary_bedside_stance_clear(plan, room, candidate, outward, head_dir, blocked):
							continue
						if HouseFurnishGeometry.fits(plan, room, candidate,
								HouseGeometry.room_floor_rect(plan, room), blocked, zones, []):
							return candidate
	return {}


## The ordinary bedside shelf needs a clear human stance and a full lane on its free side.
## Reject clipped head-corner poses geometrically before final navigation checks.
static func _ordinary_bedside_stance_clear(plan: HousePlan, room: int,
		candidate: Dictionary, outward: Vector2, head_axis: Vector2,
		blocked: Array[Rect2]) -> bool:
	var floor_rect := HouseGeometry.room_floor_rect(plan, room)
	var center_floor := floor_rect.grow(-HouseGeometry.PERSON_RADIUS)
	if center_floor.size.x <= 0.0 or center_floor.size.y <= 0.0:
		return false
	var zone: Rect2 = candidate.get("zone", Rect2())
	if not zone.has_area():
		return false
	var obstacles: Array[Rect2] = blocked.duplicate()
	obstacles.append(Rect2(candidate["rect"]))
	var stance_found := false
	for ix in range(5):
		for iz in range(5):
			var point := Vector2(lerpf(zone.position.x, zone.end.x, float(ix) / 4.0),
				lerpf(zone.position.y, zone.end.y, float(iz) / 4.0))
			if not center_floor.has_point(point):
				continue
			var clear := true
			for obstacle in obstacles:
				if obstacle.grow(HouseGeometry.PERSON_RADIUS).has_point(point):
					clear = false
					break
			if clear:
				stance_found = true
				break
		if stance_found:
			break
	if not stance_found:
		return false
	var rect: Rect2 = candidate["rect"]
	var center: Vector2 = zone.get_center()
	var side_radius := absf(outward.x) * rect.size.x * 0.5 + absf(outward.y) * rect.size.y * 0.5
	var lane_center := center + outward * (side_radius + HouseGeometry.PATH_MIN * 0.5)
	var half_lane := HouseGeometry.PATH_MIN * 0.5
	var lane_rect := Poly.bounding_rect(PackedVector2Array([
		lane_center - head_axis * half_lane - outward * half_lane,
		lane_center + head_axis * half_lane - outward * half_lane,
		lane_center + head_axis * half_lane + outward * half_lane,
		lane_center - head_axis * half_lane + outward * half_lane,
	]))
	if not floor_rect.grow(0.01).encloses(lane_rect):
		return false
	if not HouseFurnishGeometry.inside_outline(plan, room, lane_rect):
		return false
	for obstacle in obstacles:
		if lane_rect.intersects(obstacle):
			return false
	return true

## Pair a deeper work surface beside its storage host, aligning their backs.
## The same predicate reserves kitchen workbench space before the cabinet is
## committed.
static func _aligned_beside_candidate(plan: HousePlan, room: int, key: String,
		host: Dictionary, blocked: Array[Rect2], zones: Array[Rect2],
		height_scale := -1.0) -> Dictionary:
	var host_rect: Rect2 = Rect2(host["rect"])
	var host_center: Vector2 = host_rect.get_center()
	var wall_facing := HouseFurnishScore._facing_of(float(host.get("yaw", 0.0))).normalized()
	var tangent_dir := Vector2(-wall_facing.y, wall_facing.x)
	var host_depth: float = absf(wall_facing.x) * host_rect.size.x \
		+ absf(wall_facing.y) * host_rect.size.y
	var host_span: float = absf(tangent_dir.x) * host_rect.size.x \
		+ absf(tangent_dir.y) * host_rect.size.y
	for scale in _domestic_prep_scales(key):
		for yaw in [0.0, PI / 2.0, PI, PI * 1.5]:
			var facing := HouseFurnishScore._facing_of(float(yaw)).normalized()
			if facing.dot(wall_facing) < 0.99:
				continue
			var probe := HouseFurnishGeometry.candidate(key, host_center, float(yaw),
				1.0, float(scale), height_scale)
			var rect: Rect2 = Rect2(probe["rect"])
			var depth: float = absf(wall_facing.x) * rect.size.x \
				+ absf(wall_facing.y) * rect.size.y
			var span: float = absf(tangent_dir.x) * rect.size.x \
				+ absf(tangent_dir.y) * rect.size.y
			for side_sign in [-1.0, 1.0]:
				var center: Vector2 = host_center \
					+ wall_facing * ((depth - host_depth) * 0.5) \
					+ tangent_dir * float(side_sign) * ((host_span + span) * 0.5 + 0.06)
				var candidate := HouseFurnishGeometry.candidate(key, center,
					float(yaw), 1.0, float(scale), height_scale)
				if HouseFurnishGeometry.fits(plan, room, candidate,
						HouseGeometry.room_floor_rect(plan, room), blocked, zones, []):
					return candidate
	return {}


## The compact shared kitchen cannot always fit a cabinet and workbench in one
## straight run. Try a measured perpendicular attachment around the cabinet's
## ends; the workbench keeps an independent front use zone and the ordinary
## floor/door/obstacle fit rules still decide whether it is usable.
static func _l_shaped_prep_candidate(plan: HousePlan, room: int, key: String,
		host: Dictionary, blocked: Array[Rect2], zones: Array[Rect2],
		height_scale := -1.0) -> Dictionary:
	var host_rect: Rect2 = Rect2(host["rect"])
	var host_center: Vector2 = host_rect.get_center()
	var directions: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	for scale in _domestic_prep_scales(key):
		for yaw in [0.0, PI / 2.0, PI, PI * 1.5]:
			var probe := HouseFurnishGeometry.candidate(key, host_center,
				float(yaw), 1.0, float(scale), height_scale)
			var probe_rect: Rect2 = Rect2(probe["rect"])
			for direction in directions:
				var tangent := Vector2(-direction.y, direction.x)
				var host_radius: float = absf(direction.x) * host_rect.size.x * 0.5 \
					+ absf(direction.y) * host_rect.size.y * 0.5
				var item_radius: float = absf(direction.x) * probe_rect.size.x * 0.5 \
					+ absf(direction.y) * probe_rect.size.y * 0.5
				var host_span: float = absf(tangent.x) * host_rect.size.x \
					+ absf(tangent.y) * host_rect.size.y
				var item_span: float = absf(tangent.x) * probe_rect.size.x \
					+ absf(tangent.y) * probe_rect.size.y
				var max_slide: float = maxf(0.0, (host_span + item_span) * 0.5 - 0.18)
				var slide_offsets: Array[float] = [0.0]
				for step_index in range(1, 9):
					var slide: float = float(step_index) * 0.25
					if slide > max_slide + 0.001:
						break
					slide_offsets.append(slide)
					slide_offsets.append(-slide)
				for slide_offset in slide_offsets:
					var center: Vector2 = host_center \
						+ direction * (host_radius + item_radius + 0.06) \
						+ tangent * slide_offset
					var candidate := HouseFurnishGeometry.candidate(key, center,
						float(yaw), 1.0, float(scale), height_scale)
					if HouseFurnishGeometry.fits(plan, room, candidate,
							HouseGeometry.room_floor_rect(plan, room), blocked, zones, []):
						return candidate
	return {}


## Opposing kitchen runs can share a clear service aisle when a narrow hall
## cannot fit a same-wall prep line. Both fronts face the aisle; the measured
## use zones must fit between the bodies and remain clear of the other body.
static func _opposed_prep_candidate(plan: HousePlan, room: int, key: String,
		host: Dictionary, blocked: Array[Rect2], zones: Array[Rect2],
		height_scale := -1.0) -> Dictionary:
	var host_rect: Rect2 = Rect2(host["rect"])
	var host_yaw: float = float(host.get("yaw", 0.0))
	var host_facing := HouseFurnishScore._facing_of(host_yaw).normalized()
	var host_depth: float = absf(host_facing.x) * host_rect.size.x \
		+ absf(host_facing.y) * host_rect.size.y
	var host_key: String = String(host.get("key", "Cabinet"))
	var host_zone_depth: float = PropCatalog.zone_depth(host_key)
	var tangent := Vector2(-host_facing.y, host_facing.x)
	for scale in _domestic_prep_scales(key):
		for yaw in [0.0, PI / 2.0, PI, PI * 1.5]:
			var facing := HouseFurnishScore._facing_of(float(yaw)).normalized()
			if facing.dot(-host_facing) < 0.99:
				continue
			var probe := HouseFurnishGeometry.candidate(key, host_rect.get_center(),
				float(yaw), 1.0, float(scale), height_scale)
			var rect: Rect2 = Rect2(probe["rect"])
			var depth: float = absf(host_facing.x) * rect.size.x \
				+ absf(host_facing.y) * rect.size.y
			var minimum_gap: float = maxf(host_zone_depth, PropCatalog.zone_depth(key)) + 0.08
			for gap in [minimum_gap, 1.1, 1.35, 1.6, 1.85, 2.0, 2.25, 2.5]:
				if float(gap) + 0.001 < minimum_gap:
					continue
				for side_offset in [0.0, 0.25, -0.25, 0.5, -0.5, 0.75, -0.75,
						1.0, -1.0, 1.25, -1.25, 1.5, -1.5]:
					var center: Vector2 = host_rect.get_center() \
						+ host_facing * (host_depth * 0.5 + float(gap) + depth * 0.5) \
						+ tangent * float(side_offset)
					var candidate := HouseFurnishGeometry.candidate(key, center,
						float(yaw), 1.0, float(scale), height_scale)
					if HouseFurnishGeometry.fits(plan, room, candidate,
							HouseGeometry.room_floor_rect(plan, room), blocked, zones, []):
						candidate["activity_relation"] = "opposed_work_aisle"
						return candidate
	return {}


static func _domestic_prep_scales(key: String) -> Array[float]:
	var out: Array[float] = []
	for scale in HouseFurnishGeometry.scales(key):
		out.append(float(scale))
	var measured_minimum: float = PropCatalog.min_scale(key)
	if measured_minimum > 0.0 and not measured_minimum in out:
		out.append(measured_minimum)
	return out


# ------------------------------------------------------------ floor pieces

## Back to a wall, sliding along it until somewhere fits.
static func _place_against_wall(plan: HousePlan, room: int, key: String,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator,
		step: Dictionary = {}) -> void:
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
	var best: Dictionary = {}
	var best_score := -INF
	var best_dark_sleep_bed: Dictionary = {}
	var best_dark_sleep_bed_score := -INF
	var sleep_storage_by_wall: Dictionary = {}
	var witch_bench_options_by_scale: Dictionary = {}
	var trace_rejections: Dictionary = {}
	var trace_wall: bool = bool(plan.domestic_layout.get("_witch_placement_trace", false)) and HouseFurnishingRecipes.is_ordinary_house(plan) and plan.spec.style == &"witch_hut" and plan.spec.trade == &"none" and String(step.get("group", "")) in ["cooking", "witchwork"]
	var require_sleep_access: bool = HouseFurnishingRecipes.is_ordinary_house(plan) \
		and String(step.get("group", "")) == "sleep" \
		and PropCatalog.category(key) == "chest" \
		and String(step.get("near_anchor", "")) != "head_end"
	var require_cooking_pair: bool = HouseFurnishingRecipes.is_ordinary_house(plan) \
		and String(step.get("group", "")) == "cooking" \
		and PropCatalog.category(key) == "storage"
	var cooking_storage_by_wall: Dictionary = {}
	var extra: Array[Rect2] = _window_blocks(plan, room, key,
		float(step.get("height_scale", -1.0)))
	var hearth_only: int = _forced_wall(plan, room, key)
	# The chimney fixes the hearth wall, not every cooking station. In the
	# compact shared hall the fire's breast otherwise monopolises the only
	# wall considered for the measured storage/prep pair, despite a separate
	# cooking reservation and adequate free wall elsewhere in that band.
	if HouseFurnishingRecipes.is_ordinary_house(plan) \
			and plan.spec.style == &"witch_hut" and plan.spec.trade == &"none" \
			and plan.kind_of(room) == &"hall" \
			and bool(plan.rooms[room].get("shared_cooking", false)) \
			and String(step.get("group", "")) == "cooking" \
			and PropCatalog.category(key) == "storage":
		hearth_only = -1
	var compact_witchwork_wall: bool = _requires_compact_witchwork_wall(plan, room, key, step)
	for wi in range(walls.size()):
		if compact_witchwork_wall and not Array(step.get("preferred_walls", [])).has(wi):
			continue
		if hearth_only >= 0 and wi != hearth_only:
			continue
		var wall: Dictionary = walls[wi]
		var n: Vector2 = wall["normal"]
		var yaw: float = HouseFurnishGeometry.yaw_facing(n)
		var a: Vector2 = wall["from"]
		var b: Vector2 = wall["to"]
		# The direction the wall actually runs, not the nearest axis to it.
		# Taking absf() of the perpendicular was right for the four walls of a
		# rectangle and meaningless on the diagonal of an octagon, where it
		# walked the piece off the wall it was meant to be against (GEO-002).
		var along: Vector2 = (b - a).normalized()
		# A piece backed to a wall stands across it by its own width and into
		# the room by its own depth, whichever way the wall runs.
		var raw: Vector2 = PropCatalog.footprint(key)
		var span: float = raw.x
		var depth: float = raw.y
		var run: float = (b - a).length()
		var small: float = span * PropCatalog.min_scale(key)
		var bed_on_facet := plan.is_polygonal(room) and PropCatalog.category(key) == "bed" \
			and maxf(absf(n.x), absf(n.y)) > 0.999
		if run < small + 0.1 and not bed_on_facet:
			continue
		var steps: int = clampi(int((run - small) / PROBE_STEP), 1, MAX_PROBES)
		for s in range(steps + 1):
			var t: float = (small / 2.0) + float(s) * (run - small) / float(steps)
			if run < small:
				t = run * 0.5
			var centre: Vector2 = a + along * t + n * (depth / 2.0 + HouseGeometry.WALL_GAP)
			# a bed can be got into from either side, so try both before
			# deciding this stretch of wall will not do
			var cand := {}
			var compact_scale_candidates: Array[Dictionary] = []
			for sc in HouseFurnishGeometry.scales(key):
				# Scaling changes depth as well as width. Re-seat the back on
				# the host wall; keeping the full-size centre leaves a smaller
				# bed floating away from its headboard and wastes the aisle.
				var scaled_centre: Vector2 = a + along * t \
					+ n * (depth * float(sc) / 2.0 + (HouseGeometry.BREAST_DEPTH if hearth_only >= 0 else HouseGeometry.WALL_GAP))
				for zs in [1.0, -1.0]:
					var try_cand: Dictionary = HouseFurnishGeometry.candidate(key,
						scaled_centre, yaw, zs, sc, float(step.get("height_scale", -1.0)))
					if HouseFurnishingRecipes.is_ordinary_house(plan) \
							and PropCatalog.category(key) == "bed" \
							and String(step.get("group", "")) == "sleep":
						try_cand["zone"] = HouseFurnishGeometry.ordinary_sleep_access_zone(
							Rect2(try_cand["zone"]), Rect2(try_cand["rect"]),
							float(try_cand["yaw"]))
					if try_cand["cat"] in ["seat", "bench"]:
						# A seat backed to a wall is sat on facing the room: the
						# floor it needs is in FRONT of it, for the legs, not the
						# pull-back space behind a chair at a table, which here
						# would be inside the masonry.
						var z0: Rect2 = try_cand["zone"]
						var c0: Vector2 = Rect2(try_cand["rect"]).get_center()
						try_cand["zone"] = Rect2(c0 * 2.0 - z0.get_center() - z0.size / 2.0, z0.size)
					if hearth_only >= 0:
						var breast := HouseGeometry.breast_for_hearth(plan, room, try_cand, wi)
						if not _breast_fits(plan, room, breast, floor_rect, blocked, zones):
							continue
						try_cand["breast"] = breast
					if HouseFurnishGeometry.fits(plan, room, try_cand, floor_rect, blocked, zones, extra):
						if HouseFurnishingRecipes.is_ordinary_house(plan) \
								and PropCatalog.category(key) == "bed" \
								and String(step.get("group", "")) == "sleep":
							var paired_blocked: Array[Rect2] = blocked.duplicate()
							paired_blocked.append(Rect2(try_cand["rect"]))
							var paired_zones: Array[Rect2] = zones.duplicate()
							var access: Rect2 = Rect2(try_cand["zone"])
							if access.has_area():
								paired_zones.append(HouseFurnishGeometry.ordinary_bedside_aisle(
									access, Rect2(try_cand["rect"]), float(try_cand["yaw"])))
							var host: Dictionary = {"rect": try_cand["rect"], "yaw": try_cand["yaw"], "cat": "bed"}
							if _head_support_candidate(plan, room, "Nightstand_Shelf", host,
									paired_blocked, paired_zones, 0.8, 0.62, true).is_empty():
								continue
						if HouseFurnishingRecipes.is_ordinary_house(plan) \
								and PropCatalog.category(key) == "storage" \
								and String(step.get("group", "")) == "cooking":
							var prep_blocked: Array[Rect2] = blocked.duplicate()
							prep_blocked.append(Rect2(try_cand["rect"]))
							var prep_zones: Array[Rect2] = zones.duplicate()
							var storage_zone: Rect2 = Rect2(try_cand.get("zone", Rect2()))
							if storage_zone.has_area():
								prep_zones.append(storage_zone)
							var storage_host: Dictionary = {"rect": try_cand["rect"],
								"yaw": try_cand["yaw"], "cat": "storage"}
							var prep_fits := false
							for workbench_key in PropCatalog.of_category("workbench"):
								var prep_key: String = String(workbench_key)
								var prep_candidate := _aligned_beside_candidate(plan, room,
									prep_key, storage_host, prep_blocked, prep_zones, 1.0)
								if prep_candidate.is_empty():
									prep_candidate = _l_shaped_prep_candidate(plan, room,
										prep_key, storage_host, prep_blocked, prep_zones, 1.0)
								if prep_candidate.is_empty():
									prep_candidate = _opposed_prep_candidate(plan, room,
										prep_key, storage_host, prep_blocked, prep_zones, 1.0)
								if not prep_candidate.is_empty():
									prep_candidate["activity_group"] = "cooking"
									prep_candidate["activity_host_cat"] = "storage"
									try_cand["paired_workbench"] = prep_candidate
									try_cand["cooking_heat_gap"] = _cooking_prep_heat_gap(
										plan, room, prep_candidate)
									prep_fits = true
									break
							if not prep_fits:
								continue
						cand = try_cand
						break
					else:
						if trace_wall:
							var reason := "other_clearance_or_outline"
							var failed_rect: Rect2 = Rect2(try_cand.get("rect", Rect2()))
							var failed_zone: Rect2 = Rect2(try_cand.get("zone", Rect2()))
							if not floor_rect.grow(0.01).encloses(failed_rect):
								reason = "body_outside_floor " + str(failed_rect)
							else:
								for prior_body in blocked:
									if prior_body.intersects(failed_rect):
										reason = "body_hits_blocked " + str(prior_body)
										break
								if reason == "other_clearance_or_outline":
									for prior_zone in zones:
										if prior_zone.intersects(failed_rect):
											reason = "body_hits_usezone " + str(prior_zone)
											break
								if reason == "other_clearance_or_outline":
									for opening in extra:
										if opening.intersects(failed_rect):
											reason = "body_hits_window_clearance " + str(opening)
											break
								if reason == "other_clearance_or_outline":
									for prior_body in blocked:
										if failed_zone.has_area() and prior_body.intersects(failed_zone):
											reason = "usezone_hits_blocked_body " + str(prior_body)
											break
							trace_rejections[reason] = int(trace_rejections.get(reason, 0)) + 1
					if bed_on_facet:
						# A short polygon facet can hold the bed while the access
						# strip beside its head clips the next corner. Try a small
						# setback within the existing headboard-to-wall limit;
						# the footprint and use zone must both stay on real floor.
						for inset_step in range(1, 4):
							var inset := HouseGeometry.BED_HEAD_TOL * float(inset_step) / 3.0
							try_cand = HouseFurnishGeometry.candidate(key, scaled_centre + n * inset, yaw, zs, sc)
							if HouseFurnishingRecipes.is_ordinary_house(plan) \
									and PropCatalog.category(key) == "bed" \
									and String(step.get("group", "")) == "sleep":
								try_cand["zone"] = HouseFurnishGeometry.ordinary_sleep_access_zone(
									Rect2(try_cand["zone"]), Rect2(try_cand["rect"]),
									float(try_cand["yaw"]))
							if HouseFurnishGeometry.fits(plan, room, try_cand, floor_rect, blocked, zones, extra):
								cand = try_cand
								break
						if not cand.is_empty():
							break
				if not cand.is_empty():
					if compact_witchwork_wall and PropCatalog.category(key) == "workbench" and String(step.get("group", "")) == "witchwork":
						compact_scale_candidates.append(cand.duplicate(true))
						cand = {}
					else:
						break
			if compact_witchwork_wall and PropCatalog.category(key) == "workbench" and String(step.get("group", "")) == "witchwork":
				if compact_scale_candidates.is_empty():
					continue
				var mid: float = 1.0 - absf(t - run / 2.0) / maxf(run / 2.0, 0.01)
				var jitter: float = r.randf() * HouseFurnishScore.JITTER
				for scale_candidate in compact_scale_candidates:
					var scale_score: float = mid * 0.6 + jitter + float(wi) * 0.01
					if Array(step.get("preferred_walls", [])).has(wi):
						scale_score += 5.0
					scale_score += HouseFurnishScore._affinity(plan, room, scale_candidate)
					var scale_pos: Vector3 = scale_candidate.pos
					scale_score -= Vector2(scale_pos.x, scale_pos.z).distance_to(centre)
					var scale_key: String = str(scale_candidate.get("scale", 1.0))
					var scale_options: Array = witch_bench_options_by_scale.get(scale_key, [])
					scale_options.append({"candidate": scale_candidate, "score": scale_score})
					scale_options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
						return float(a["score"]) > float(b["score"]))
					if scale_options.size() > 2:
						scale_options.resize(2)
					witch_bench_options_by_scale[scale_key] = scale_options
				continue
			if cand.is_empty():
				continue
			var mid: float = 1.0 - absf(t - run / 2.0) / maxf(run / 2.0, 0.01)
			var score: float = mid * 0.6 + r.randf() * HouseFurnishScore.JITTER + float(wi) * 0.01
			if Array(step.get("preferred_walls", [])).has(wi):
				score += 5.0 # a scoped preferred wall remains a preference, not a hard restriction
			if cand.has("paired_workbench"):
				score += _workbench_daylight_preference(plan, room, cand["paired_workbench"])
			score += HouseFurnishScore._affinity(plan, room, cand)
			var placed: Vector3 = cand.pos
			score -= Vector2(placed.x, placed.z).distance_to(centre)
			if hearth_only >= 0 and wi != hearth_only:
				# the flue rises on one wall only, so a hearth on any other is
				# not a worse placement but no placement at all
				score = -INF
			if require_sleep_access:
				var wall_options: Array = sleep_storage_by_wall.get(wi, [])
				var nearby_option := -1
				for option_index in range(wall_options.size()):
					var option_candidate: Dictionary = wall_options[option_index]["candidate"]
					if Vector2(option_candidate["pos"].x, option_candidate["pos"].z).distance_to(
							Vector2(cand["pos"].x, cand["pos"].z)) < 1.0:
						nearby_option = option_index
						break
				var new_option := {"candidate": cand, "score": score}
				if nearby_option >= 0:
					if score > float(wall_options[nearby_option]["score"]):
						wall_options[nearby_option] = new_option
				elif wall_options.size() < 2:
					wall_options.append(new_option)
				else:
					var lowest := 0
					for option_index in range(1, wall_options.size()):
						if float(wall_options[option_index]["score"]) < float(wall_options[lowest]["score"]):
							lowest = option_index
					if score > float(wall_options[lowest]["score"]):
						wall_options[lowest] = new_option
				sleep_storage_by_wall[wi] = wall_options
			elif require_cooking_pair:
				var kitchen_options: Array = cooking_storage_by_wall.get(wi, [])
				var nearby_kitchen := -1
				for option_index in range(kitchen_options.size()):
					var option_candidate: Dictionary = kitchen_options[option_index]["candidate"]
					if Vector2(option_candidate["pos"].x, option_candidate["pos"].z).distance_to(
							Vector2(cand["pos"].x, cand["pos"].z)) < 1.0:
						nearby_kitchen = option_index
						break
				var new_kitchen_option := {"candidate": cand, "score": score,
					"heat_gap": float(cand.get("cooking_heat_gap", INF))}
				if nearby_kitchen >= 0:
					if _cooking_option_precedes(new_kitchen_option,
							kitchen_options[nearby_kitchen]):
						kitchen_options[nearby_kitchen] = new_kitchen_option
				elif kitchen_options.size() < 3:
					kitchen_options.append(new_kitchen_option)
				else:
					var lowest_kitchen := 0
					for option_index in range(1, kitchen_options.size()):
						if _cooking_option_precedes(kitchen_options[lowest_kitchen],
								kitchen_options[option_index]):
							lowest_kitchen = option_index
					if _cooking_option_precedes(new_kitchen_option,
							kitchen_options[lowest_kitchen]):
						kitchen_options[lowest_kitchen] = new_kitchen_option
				cooking_storage_by_wall[wi] = kitchen_options
			else:
				var ordinary_sleep_bed := HouseFurnishingRecipes.is_ordinary_house(plan) \
					and PropCatalog.category(key) == "bed" \
					and String(step.get("group", "")) == "sleep"
				if ordinary_sleep_bed:
					var head_wall := HouseFurnishScore._bed_head_wall(plan, room, cand)
					var dark_head_wall := head_wall >= 0 \
						and not HouseFurnishSpatialCheck.fs_wall_lit(plan, room, head_wall)
					if dark_head_wall:
						if score > best_dark_sleep_bed_score:
							best_dark_sleep_bed_score = score
							best_dark_sleep_bed = cand
					else:
						if score > best_score:
							best_score = score
							best = cand
				elif score > best_score:
					best_score = score
					best = cand
	if compact_witchwork_wall and PropCatalog.category(key) == "workbench" and String(step.get("group", "")) == "witchwork":
		var ranked_bench_options: Array[Dictionary] = []
		for scale_options_variant in witch_bench_options_by_scale.values():
			for option in scale_options_variant:
				ranked_bench_options.append(option)
		ranked_bench_options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["score"]) > float(b["score"]))
		for option in ranked_bench_options:
			var trial_candidate: Dictionary = Dictionary(option["candidate"]).duplicate(true)
			if _compact_witch_bench_replays_required_core(
					plan, room, trial_candidate, blocked, zones, r):
				best = trial_candidate
				break
		if trace_wall:
			print("WITCH_BENCH_LOOKAHEAD room=", room, " candidates=", ranked_bench_options.size(), " chosen=", str(best.get("rect", Rect2())), " chosen_scale=", best.get("scale", -1.0))
	elif require_sleep_access:
		var sleep_storage_options: Array[Dictionary] = []
		for wall_options_variant in sleep_storage_by_wall.values():
			for option in wall_options_variant:
				sleep_storage_options.append(option)
		sleep_storage_options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["score"]) > float(b["score"]))
		for candidate_index in mini(sleep_storage_options.size(), 8):
			var option: Dictionary = sleep_storage_options[candidate_index]
			var trial_candidate: Dictionary = Dictionary(option["candidate"]).duplicate(true)
			trial_candidate["activity_group"] = "sleep"
			if _sleep_access_survives_candidate(plan, room, trial_candidate):
				best = trial_candidate
				break
	elif require_cooking_pair:
		var cooking_storage_options: Array[Dictionary] = []
		for wall_options_variant in cooking_storage_by_wall.values():
			for option in wall_options_variant:
				cooking_storage_options.append(option)
		cooking_storage_options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _cooking_option_precedes(a, b))
		for candidate_index in mini(cooking_storage_options.size(), 12):
			var option: Dictionary = cooking_storage_options[candidate_index]
			if float(option.get("heat_gap", INF)) > MAX_COOKING_HEAT_GAP:
				break
			var pair_storage: Dictionary = Dictionary(option["candidate"]).duplicate(true)
			var pair_prep: Dictionary = Dictionary(pair_storage.get("paired_workbench", {})).duplicate(true)
			pair_storage["activity_group"] = "cooking"
			if not pair_prep.is_empty() and _cooking_pair_survives_candidates(plan,
					room, pair_storage, pair_prep):
				best = pair_storage
				break
	if trace_wall:
		print("WITCH_WALL_SEARCH room=", room, " category=", PropCatalog.category(key), " group=", step.get("group", ""), " key=", key, " rejects=", str(trace_rejections), " cooking_options=", cooking_storage_by_wall.size(), " best=", str(best.get("rect", Rect2())))
	# Prefer a feasible dark headwall; retain a glazed-wall fallback only when
	# no valid dark bed-plus-nightstand pose exists in this room.
	if not best_dark_sleep_bed.is_empty():
		best = best_dark_sleep_bed
	HouseFurnishGeometry.commit(plan, room, best, blocked, zones)


## Prefer lit kitchen work surfaces while retaining geometry and route checks.
static func _workbench_daylight_preference(plan: HousePlan, room: int,
		candidate: Dictionary) -> float:
	if plan.windows_of(room).is_empty():
		return 0.0
	var rect: Rect2 = candidate["rect"]
	var back_wall := HouseFurnishSpatialCheck.fs_back_wall(plan, room, rect, candidate)
	if back_wall >= 0 and HouseFurnishSpatialCheck.fs_wall_lit(plan, room, back_wall):
		return 100.0
	var nearest := INF
	for window_index in plan.windows_of(room):
		nearest = minf(nearest, rect.get_center().distance_to(Vector2(plan.windows[window_index]["pos"])))
	return 50.0 if nearest <= HouseFurnishAffinityCheck.FS_WINDOW_REACH else 0.0


## Keep ordinary cooking prep close to the real heat-use area. Daylight and
## affinity still break ties, but a bright bench across a long kitchen should
## not outrank a workable prep position beside the cooking hearth.
static func _cooking_prep_heat_gap(plan: HousePlan, room: int,
		prep: Dictionary) -> float:
	var prep_use := Rect2(prep.get("zone", Rect2()))
	if not prep_use.has_area():
		prep_use = Rect2(prep.get("rect", Rect2()))
	if not prep_use.has_area():
		return INF
	var best := INF
	for item_index in plan.furniture_of(room):
		var item: Dictionary = plan.furniture[item_index]
		if String(item.get("cat", "")) != "hearth" \
				or String(item.get("activity_group", "")) != "cooking":
			continue
		var heat_use := Rect2(item.get("zone", Rect2()))
		if not heat_use.has_area():
			heat_use = Rect2(item.get("rect", Rect2()))
		if heat_use.has_area():
			best = minf(best, _rect_gap(prep_use, heat_use))
	# An ordinary masonry fireplace is a measured shell host, not a furniture
	# row. Use its actual planned breast bounds as the cooking heat anchor; do
	# not make a proxy hearth prop that would occupy floor the shell already owns.
	if HouseFurnishingRecipes.uses_native_domestic_fireplace(plan):
		var breast: Dictionary = HouseGeometry.hearth_breast(plan)
		if int(breast.get("room", -1)) == room:
			var heat_use := Rect2(breast.get("rect", Rect2()))
			if heat_use.has_area():
				best = minf(best, _rect_gap(prep_use, heat_use))
	return best


static func _rect_gap(left: Rect2, right: Rect2) -> float:
	var dx := maxf(maxf(left.position.x - right.end.x,
		right.position.x - left.end.x), 0.0)
	var dy := maxf(maxf(left.position.y - right.end.y,
		right.position.y - left.end.y), 0.0)
	return Vector2(dx, dy).length()


static func _cooking_option_precedes(left: Dictionary, right: Dictionary) -> bool:
	var left_heat := float(left.get("heat_gap", INF))
	var right_heat := float(right.get("heat_gap", INF))
	var left_finite := is_finite(left_heat)
	var right_finite := is_finite(right_heat)
	var left_in_reach := left_finite and left_heat <= MAX_COOKING_HEAT_GAP
	var right_in_reach := right_finite and right_heat <= MAX_COOKING_HEAT_GAP
	if left_in_reach != right_in_reach:
		return left_in_reach
	if left_in_reach:
		# Preserve daylight, affinity, and existing layout scoring among all
		# candidates that meet the real heat-to-prep task distance.
		return float(left.get("score", -INF)) > float(right.get("score", -INF))
	if left_finite != right_finite:
		return left_finite
	if left_finite and absf(left_heat - right_heat) > 0.001:
		return left_heat < right_heat
	return float(left.get("score", -INF)) > float(right.get("score", -INF))


## Test the actual rasterized route to the bed and head-end chest with this
## clothes-chest candidate present. Rectangle fit cannot detect a narrow gap
## that closes after the walk grid expands furniture by a person's radius.
static func _sleep_access_survives_candidate(plan: HousePlan, room: int,
		candidate: Dictionary) -> bool:
	var trial := HousePlan.new()
	trial.spec = plan.spec
	trial.rooms = plan.rooms
	trial.doors = plan.doors
	trial.windows = plan.windows
	trial.stairs = plan.stairs
	trial.columns = plan.columns
	trial.courts = plan.courts
	trial.zones = plan.zones
	trial.hearth = plan.hearth
	trial.dais = plan.dais
	trial.furniture = plan.furniture.duplicate(true)
	var trial_blocked: Array[Rect2] = []
	var trial_zones: Array[Rect2] = []
	HouseFurnishGeometry.commit(trial, room, candidate.duplicate(true),
		trial_blocked, trial_zones)
	var rep: Dictionary = HouseNavCheck.new().check(trial)
	if room in rep.get("unreached_rooms", []):
		return false
	var targets: Array[int] = [trial.furniture.size() - 1]
	for index in range(trial.furniture.size() - 1):
		var piece: Dictionary = trial.furniture[index]
		if int(piece.get("room", -1)) != room:
			continue
		if String(piece.get("activity_group", "")) == "sleep" \
				and (String(piece.get("cat", "")) == "bed" \
				or String(piece.get("activity_host_anchor", "")) == "head_end"):
			targets.append(index)
	var unreachable: Array = rep.get("unreachable_items", [])
	for target in targets:
		if target in unreachable:
			return false
	return true


## Kitchen storage and its prep surface are selected as a pair. The clear
## rectangles can fit separately while the actual walk grid leaves one behind
## an inaccessible pinch point, so test only the best geometric candidates.
static func _cooking_pair_survives_candidates(plan: HousePlan, room: int,
		storage: Dictionary, prep: Dictionary) -> bool:
	var trial := HousePlan.new()
	trial.spec = plan.spec
	trial.rooms = plan.rooms
	trial.doors = plan.doors
	trial.windows = plan.windows
	trial.stairs = plan.stairs
	trial.columns = plan.columns
	trial.courts = plan.courts
	trial.zones = plan.zones
	trial.hearth = plan.hearth
	trial.dais = plan.dais
	trial.furniture = plan.furniture.duplicate(true)
	var trial_blocked: Array[Rect2] = []
	var trial_zones: Array[Rect2] = []
	HouseFurnishGeometry.commit(trial, room, storage.duplicate(true),
		trial_blocked, trial_zones)
	HouseFurnishGeometry.commit(trial, room, prep.duplicate(true),
		trial_blocked, trial_zones)
	var rep: Dictionary = HouseNavCheck.new().check(trial)
	if room in rep.get("unreached_rooms", []):
		return false
	var unreachable: Array = rep.get("unreachable_items", [])
	for index in range(trial.furniture.size()):
		if int(trial.furniture[index].get("room", -1)) == room \
				and index in unreachable:
			return false
	return true


## N copies of the same prop, evenly spaced along a line, all facing the same
## shared aisle: beds in a barracks, pews in a chapel, trestles in a hall.
##
## This is `_place_against_wall`'s own fit test (a candidate footprint clear
## of the floor already spoken for) run along a straight run instead of
## slid one piece at a time -- so the row it finds is straight and evenly
## pitched by construction, not by measuring afterwards. `along: "wall"`
## (the default) tries each wall of the room in turn, backs to it, the way a
## row of pews or beds does; `along: "axis"` runs the row down the middle of
## the room instead, for a row nothing is backed onto, such as trestle tables
## with an aisle down both sides.
##
## If fewer than `min_n` fit, nothing is placed and the room records the
## compromise, the same as any other step that could not be met.
static func _in_door_line(plan: HousePlan, room: int, item: Dictionary) -> bool:
	var rect := Rect2(item["rect"])
	var centre := rect.get_center()
	for door_index in plan.doors_of(room):
		var door: Dictionary = plan.doors[door_index]
		var normal := Vector2(door["normal"])
		var relative := centre - Vector2(door["pos"])
		var across := absf(relative.dot(Vector2(normal.y, -normal.x)))
		var half := (absf(normal.y) * rect.size.x + absf(normal.x) * rect.size.y) / 2.0
		if across < (float(door["width"]) / 2.0 + half) * 0.5:
			return true
	return false


static func place_row(plan: HousePlan, room: int, step: Dictionary,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator) -> void:
	var cat: String = String(step["cat"])
	var choices: Array[String] = PropCatalog.of_category(cat)
	if choices.is_empty():
		return
	var key: String = String(step.get("key", ""))
	if key.is_empty():
		key = choices[r.randi_range(0, choices.size() - 1)]
	elif not choices.has(key):
		return
	var n_max: int = int(step["n"][1])
	var n_want: int = n_max if n_max > 0 else 999
	var min_n: int = int(step.get("min_n", step["n"][0]))
	var pitch: float = float(step.get("pitch", 0.0))
	var aisle: float = maxf(float(step.get("aisle", HouseGeometry.PATH_MIN)), HouseGeometry.PATH_MIN)
	# Room left in front of the row before the aisle starts: a trestle table's
	# aisle is the walkway past the benches, not the space the benches stand
	# and pull back in, and a later "around" step needs that space left clear
	# of the aisle zone or it will never find anywhere to seat anyone.
	var seat_gap: float = float(step.get("seat_clearance", 0.0))
	var along_mode: String = String(step.get("along", "wall"))
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var extra: Array[Rect2] = _window_blocks(plan, room, key)
	var lines: Array[Dictionary] = []
	if along_mode == "axis":
		# Down the middle of the room, along its longer side, facing outward
		# to one side -- the trestle-table case, where nothing backs onto a
		# wall and the aisle is what the row is FOR.
		var c: Vector2 = floor_rect.get_center()
		var horizontal: bool = floor_rect.size.x >= floor_rect.size.y
		var a: Vector2 = c - (Vector2(floor_rect.size.x / 2.0, 0.0) if horizontal
			else Vector2(0.0, floor_rect.size.y / 2.0))
		var b: Vector2 = c + (Vector2(floor_rect.size.x / 2.0, 0.0) if horizontal
			else Vector2(0.0, floor_rect.size.y / 2.0))
		var n2: Vector2 = Vector2(0.0, 1.0) if horizontal else Vector2(1.0, 0.0)
		lines = [{"from": a, "to": b, "normal": n2}]
	else:
		lines = HouseGeometry.room_walls(plan, room)
	var best_row: Array = []
	var best_zone := Rect2()
	var best_score := -INF
	# Largest size first, the same as every other placer here: a row of
	# full-size tables is a better fit than a row of shrunk ones, and a small
	# room should only get the shrunk row if the full-size one will not go in
	# at all.
	for sc in HouseFurnishGeometry.scales(key):
		for wi in range(lines.size()):
			if bool(step.get("avoid_window_walls", false)) \
					and HouseFurnishSpatialCheck.fs_wall_lit(plan, room, wi):
				continue
			var wall: Dictionary = lines[wi]
			var n: Vector2 = wall["normal"]
			var yaw: float = HouseFurnishGeometry.yaw_facing(n)
			var foot: Vector2 = PropCatalog.footprint_rotated(key, yaw) * sc
			var along := Vector2(n.y, -n.x).abs()
			var span: float = along.x * foot.x + along.y * foot.y
			var depth: float = absf(n.x) * foot.x + absf(n.y) * foot.y
			var a2: Vector2 = wall["from"]
			var b2: Vector2 = wall["to"]
			var run: float = (b2 - a2).length()
			var use_pitch: float = maxf(pitch, span + 0.1) if pitch > 0.01 else span + 0.3
			if run < span:
				continue
			var out: float = depth / 2.0 + HouseGeometry.WALL_GAP
			var max_count: int = mini(n_want, int((run + 0.001) / use_pitch))
			var row: Array = []
			# Fewer copies first only if the full count will not go in anywhere;
			# and for each count, slide the row along the wall -- a door swing
			# or a window sill in the middle of the wall should cost the row a
			# few centimetres of centring, not the whole row.
			for count in range(max_count, min_n - 1, -1):
				if count < 1:
					continue
				var span_len: float = float(count - 1) * use_pitch + span
				var slack: float = run - span_len
				if slack < -0.001:
					continue
				var slides: int = clampi(int(slack / PROBE_STEP), 0, MAX_PROBES)
				for si in range(slides + 1):
					var shift: float = -slack / 2.0 + (slack * float(si) / float(maxi(slides, 1)))
					var start_t: float = span / 2.0 + slack / 2.0 + shift
					var try_row: Array = []
					for i in range(count):
						var t: float = start_t + float(i) * use_pitch
						var centre: Vector2 = a2 + along * t + n * out
						var cand: Dictionary = HouseFurnishGeometry.candidate(key, centre, yaw, 1.0, sc)
						if bool(step.get("avoid_door_lines", false)) and _in_door_line(plan, room, cand):
							break
						# A ROW SHARES ONE AISLE, and that aisle is its use
						# zone -- it is assigned below, once the row is known.
						# The per-piece zone must not be tested here: a seat
						# carries its pull-back space BEHIND it, so a pew
						# backed to a wall has a zone inside the masonry and
						# not one bench of a row would ever fit. Pews in a
						# chapel are the case the row rule was written for
						# (INT-001) and could not do until this line.
						cand["zone"] = Rect2()
						if not HouseFurnishGeometry.fits(plan, room, cand, floor_rect, blocked, zones, extra):
							break
						try_row.append(cand)
					if try_row.size() == count:
						row = try_row
						break
				if not row.is_empty():
					break
			if row.size() < min_n:
				continue
			# One aisle the whole row shares, deep enough to walk and wide enough
			# to cover every copy actually placed -- not the run the wall offered,
			# so a short row does not claim an aisle it never reaches the end of.
			var first: Rect2 = row[0]["rect"]
			var last: Rect2 = row[row.size() - 1]["rect"]
			var row_c: Vector2 = (first.get_center() + last.get_center()) / 2.0
			var row_len: float = (last.get_center() - first.get_center()).length() + span
			var facing: Vector2 = HouseFurnishScore._facing_of(yaw)
			var across: Vector2 = Vector2(facing.y, -facing.x).abs()
			var half_span: Vector2 = across * (row_len / 2.0)
			# The aisle the recipe asked for first; failing that, the narrowest
			# the nav check will still call a way through -- a shallow room
			# should not lose its whole row of trestles for want of a few
			# centimetres it was never going to spare.
			var aisle_rect := Rect2()
			for try_aisle in [aisle, HouseGeometry.PATH_MIN]:
				var aisle_a: Vector2 = row_c + facing * (out + seat_gap)
				var aisle_b: Vector2 = row_c + facing * (out + seat_gap + try_aisle)
				var ra: Vector2 = aisle_a - half_span
				var rb: Vector2 = aisle_b + half_span
				var candidate_rect := Rect2(ra.min(rb), (rb - ra).abs())
				if not floor_rect.grow(0.02).encloses(candidate_rect):
					continue
				var clash := false
				for bz in blocked:
					if bz.intersects(candidate_rect):
						clash = true
						break
				if clash:
					continue
				aisle_rect = candidate_rect
				break
			if aisle_rect.size.x <= 0.0:
				continue
			# scale is the primary ordering: a smaller-scale row never beats a
			# larger one, however many more copies it manages to fit
			var score: float = sc * 1000.0 + float(row.size()) * 10.0 + r.randf()
			if score > best_score:
				best_score = score
				best_row = row
				best_zone = aisle_rect
		if not best_row.is_empty():
			break
	if best_row.size() < min_n:
		if float(step["opt"]) >= 1.0 and _has_other_must(plan, room):
			plan.note_compromise(room, cat)
		return
	var row_group: String = "%d_%s_%d" % [room, cat, plan.furniture.size()]
	for cand in best_row:
		cand["zone"] = best_zone
		cand["row"] = row_group
		if bool(step.get("free_standing", false)):
			cand["free_standing"] = true
		HouseFurnishGeometry.commit(plan, room, cand, blocked, zones)


## The one wall a piece may stand against, or -1 when any will do. The planner
## names the hearth wall (HousePlan.hearth) and the builder raises the chimney
## on it, so a hearth anywhere else is a fire with no flue: every other wall
## scores -INF rather than a penalty that a lucky roll could overcome.
static func _forced_wall(plan: HousePlan, room: int, key: String) -> int:
	if PropCatalog.category(key) != "hearth":
		return -1
	if plan.hearth_room() != room:
		return -1
	return plan.hearth_wall()


## Room in the middle of the floor, for a table or an anvil.
static func place_free(plan: HousePlan, room: int, key: String,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator,
		require_seat := false, seat_cat := "seat", seat_n := 1,
		retain_seat_set := false, height_scale := -1.0) -> void:
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var extra: Array[Rect2] = _window_blocks(plan, room, key)
	var result := {"best": {}, "score": -INF, "require_seat": require_seat,
		"seat_cat": seat_cat, "seat_n": seat_n, "retain_seat_set": retain_seat_set,
		"height_scale": height_scale}
	# Where the fire is does not change while the table hunts for a spot, and
	# the hunt looks at thousands of spots. Found once here and carried on the
	# candidate; leaving it inside the grid made every table in the sweep walk
	# the room's furniture list a few thousand times.
	var focus: Vector2 = HouseFurnishScore._hearth_point(plan, room)
	# A footprint turned half round is the same footprint, so two yaws cover
	# every rectangle -- unless the piece must LOOK somewhere, in which case
	# all four matter.
	var yaws: Array = [0.0, PI / 2.0]
	if plan.focus_room() == room and plan.focus_faces_door() \
			and PropCatalog.category(key) == plan.focus_cat():
		yaws = [0.0, PI / 2.0, PI, -PI / 2.0]
	# A piece the plan PINS does not need the whole room searched: the pin
	# already says where it goes, and every probe a stride away from it loses
	# to the pin anyway. Searching a 12 x 30 m great hall at 12 cm for a table
	# the plan had already placed cost ten seconds a hall.
	var pin: Rect2 = _pin_box(plan, room, key)
	# Keep the way in clear first: a free-standing piece is tried out of the
	# approach to every door, and only if the room has nowhere else for it is
	# it allowed back in -- and then it says so, so the check can tell a
	# cramped room's compromise from a careless placement. The focus piece is
	# the exception: a counter that faces the shop door is MEANT to meet you.
	var approach: Array[Rect2] = []
	if not _is_focus_piece(plan, room, key):
		approach = door_approaches(plan, room)
	var with_approach: Array[Rect2] = extra.duplicate()
	with_approach.append_array(approach)
	if PropCatalog.category(key) == "table":
		# and a table keeps a chair and a passage from the tables already in
		# the room: two trestles ten centimetres apart are one table with a
		# crack in it (walk QA, 6 Oct)
		for f in plan.furniture_of(room):
			if PropCatalog.category(plan.furniture[f]["key"]) == "table":
				with_approach.append(Rect2(plan.furniture[f]["rect"]).grow(TABLE_GAP))
	var passes: Array = [with_approach, extra] if with_approach.size() > extra.size() else [extra]
	var in_approach := false
	for pass_any in passes:
		var pass_extra: Array[Rect2] = pass_any
		for yaw in yaws:
			for sc in HouseFurnishGeometry.scales(key):
				_free_at_scale(plan, room, key, yaw, sc, floor_rect, blocked, zones,
					pass_extra, r, result, focus, pin)
		if not Dictionary(result["best"]).is_empty():
			break
		in_approach = true
	var best: Dictionary = result["best"]
	if in_approach and not best.is_empty():
		for a in approach:
			if a.intersects(Rect2(best["rect"])):
				best["door_approach"] = true
				break
	var seat: Dictionary = best.get("paired_seat", {})
	var seats: Array = best.get("paired_seats", [])
	best.erase("paired_seat")
	best.erase("paired_seats")
	HouseFurnishGeometry.commit(plan, room, best, blocked, zones)
	var paired_table_index: int = plan.furniture.size() - 1
	if not seat.is_empty():
		seat["host"] = paired_table_index
		var seat_pos: Vector3 = seat["pos"]
		seat_pos.y = 0.0
		seat["pos"] = seat_pos
		HouseFurnishGeometry.commit(plan, room, seat, blocked, zones)
	for paired_seat in seats:
		var seat_piece: Dictionary = paired_seat
		seat_piece["host"] = paired_table_index
		var paired_pos: Vector3 = seat_piece["pos"]
		paired_pos.y = 0.0
		seat_piece["pos"] = paired_pos
		HouseFurnishGeometry.commit(plan, room, seat_piece, blocked, zones)


## The approach to every door of a room: the strip a person walks through
## after the swing, a little wider than the leaf. Both sides of each door are
## returned; the one that lies outside this room never meets a candidate.
static func door_approaches(plan: HousePlan, room: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for d in plan.doors_of(room):
		out.append_array(door_approach_rects(plan.doors[d]))
	return out


static func door_approach_rects(door: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var c: Vector2 = door["pos"]
	var w: float = float(door["width"]) + DOOR_APPROACH_SIDE * 2.0
	for side in [-1.0, 1.0]:
		var n: Vector2 = Vector2(door["normal"]) * side
		var along := Vector2(n.y, -n.x).abs()
		var a: Vector2 = c - along * (w / 2.0)
		var b: Vector2 = c + along * (w / 2.0) + n * DOOR_APPROACH
		out.append(Rect2(a.min(b), (b - a).abs()))
	return out


## Against a wall, out of the approach to the doors if the piece is a table
## and the room has anywhere else for it; otherwise against a wall as before.
static func _wall_clear_of_doors(plan: HousePlan, room: int, key: String,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator,
		step: Dictionary = {}) -> void:
	var before := plan.furniture.size()
	if PropCatalog.category(key) == "table":
		var approach := door_approaches(plan, room)
		var held: Array[Rect2] = blocked.duplicate()
		blocked.append_array(approach)
		_place_against_wall(plan, room, key, blocked, zones, r, step)
		# put the borrowed rectangles back out, keeping what was committed
		var committed: Array[Rect2] = blocked.slice(held.size() + approach.size())
		blocked.assign(held + committed)
		if plan.furniture.size() > before:
			return
	_place_against_wall(plan, room, key, blocked, zones, r, step)


## A table set against a wall had no door approach to avoid -- the wall rule
## slides along the wall it was given -- so when it lands in one, it says so.
static func _flag_door_approach(plan: HousePlan, room: int, placed_from: int) -> void:
	if plan.furniture.size() <= placed_from:
		return
	var p: Dictionary = plan.furniture[placed_from]
	if PropCatalog.category(String(p["key"])) != "table":
		return
	for a in door_approaches(plan, room):
		if a.intersects(Rect2(p["rect"])):
			p["door_approach"] = true
			return


static func _is_focus_piece(plan: HousePlan, room: int, key: String) -> bool:
	return plan.focus_room() == room and PropCatalog.category(key) == plan.focus_cat()


static func _breast_fits(plan: HousePlan, room: int, breast: Dictionary, floor_rect: Rect2,
		blocked: Array[Rect2], zones: Array[Rect2]) -> bool:
	var rect: Rect2 = breast["rect"]
	if not floor_rect.grow(0.01).encloses(rect) or not HouseFurnishGeometry.inside_outline(plan, room, rect):
		return false
	for obstacle in blocked + zones:
		if rect.intersects(obstacle):
			return false
	for window in plan.windows_of(room):
		if rect.intersects(HouseGeometry.window_clear_rect(plan.windows[window])):
			return false
	return true


## The patch of floor a pinned piece is searched in, or an empty rect when the
## plan has not pinned this one. A stride either way, so the probe can still
## slide the piece off a door swing or out of a window.
static func _pin_box(plan: HousePlan, room: int, key: String) -> Rect2:
	if plan.focus_room() != room or plan.focus.get("placed", false):
		return Rect2()
	if PropCatalog.category(key) != plan.focus_cat():
		return Rect2()
	var at: Vector2 = plan.focus_pos()
	if not at.is_finite():
		return Rect2()
	return Rect2(at - Vector2.ONE * HouseFurnishScore.PIN_SEARCH, Vector2.ONE * HouseFurnishScore.PIN_SEARCH * 2.0)


## One pass of the free-standing search at a single size. Split out only
## because trying four sizes at two yaws over a grid is four levels of loop,
## and nesting them all in one function made the body unreadable.
static func _free_at_scale(plan: HousePlan, room: int, key: String, yaw: float,
		sc: float, floor_rect: Rect2, blocked: Array[Rect2], zones: Array[Rect2],
		extra: Array[Rect2], r: RandomNumberGenerator, result: Dictionary,
		focus := Vector2(INF, INF), pin := Rect2()) -> void:
	var foot: Vector2 = PropCatalog.footprint_rotated(key, yaw) * sc
	var pad: float = HouseGeometry.PATH_MIN * 0.5
	var lo := Vector2(floor_rect.position.x + foot.x / 2.0 + pad,
		floor_rect.position.y + foot.y / 2.0 + pad)
	var hi := Vector2(floor_rect.end.x - foot.x / 2.0 - pad,
		floor_rect.end.y - foot.y / 2.0 - pad)
	if pin.size.x > 0.0:
		lo = lo.max(pin.position)
		hi = hi.min(pin.end)
	if lo.x > hi.x or lo.y > hi.y:
		return
	var nx: int = clampi(int((hi.x - lo.x) / PROBE_STEP), 1, MAX_PROBES)
	var nz: int = clampi(int((hi.y - lo.y) / PROBE_STEP), 1, MAX_PROBES)
	# The measured model, yaw, scale and category are constant for this pass.
	# Preserve the same candidates and RNG calls while doing those catalogue
	# lookups once instead of once at every point of the search grid.
	var prototype := HouseFurnishGeometry.candidate(key, Vector2.ZERO, yaw, 1.0, sc,
		float(result.get("height_scale", -1.0)))
	var has_zone := PropCatalog.zone_depth(key) > 0.0
	# A customer can stand in the clear approach to the shop's entrance while
	# using its counter or stall. The piece itself must still clear that door;
	# treating the empty approach as solid furniture forced small stalls to
	# turn their service side away from the customer.
	if plan.focus_room() == room and plan.focus_faces_door() \
			and not plan.focus.get("placed", false) and PropCatalog.category(key) == plan.focus_cat():
		var entry := HouseFurnishScore.focus_door(plan, room)
		if entry >= 0:
			prototype["zone_passages"] = [HouseGeometry.door_clear_rect(plan.doors[entry], -1.0),
				HouseGeometry.door_clear_rect(plan.doors[entry], 1.0)]
	for ix in range(nx + 1):
		for iz in range(nz + 1):
			var centre := Vector2(lerpf(lo.x, hi.x, float(ix) / nx),
				lerpf(lo.y, hi.y, float(iz) / nz))
			var cand := prototype.duplicate()
			cand["pos"] = Vector3(centre.x, 0.0, centre.y)
			cand["rect"] = Rect2(centre - foot / 2.0, foot)
			if has_zone:
				cand["zone"] = HouseFurnishGeometry.zone_rect(key, cand["rect"], yaw)
			if not HouseFurnishGeometry.fits(plan, room, cand, floor_rect, blocked, zones, extra):
				continue
			cand["focus_point"] = focus
			# the middle of the room, at the biggest size that fits there
			var d: float = centre.distance_to(floor_rect.get_center())
			var score: float = -d + r.randf() * HouseFurnishScore.JITTER + sc * 4.0 \
				+ HouseFurnishScore._affinity(plan, room, cand)
			if score > float(result["score"]):
				if bool(result.get("require_seat", false)):
					var seat := _seating_probe(plan, room, cand, blocked, zones,
						String(result["seat_cat"]), int(result["seat_n"]),
						bool(result.get("retain_seat_set", false)))
					if seat.is_empty():
						continue
					if int(result["seat_n"]) > 1:
						cand["paired_seats"] = seat.get("paired_seats", [])
					else:
						cand["paired_seat"] = seat
				result["score"] = score
				result["best"] = cand


## Tucked into whichever corner is emptiest.
static func _place_corner(plan: HousePlan, room: int, key: String,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator,
		zone_depth_override := -1.0) -> void:
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var foot: Vector2 = PropCatalog.footprint(key)
	var g: float = HouseGeometry.WALL_GAP
	# In a narrow passage, sliding along an end wall leaves the object in the
	# walking strip. Search along the long walls instead. Polygon rooms keep
	# their existing geometry-aware fit path; their AABB is not a wall frame.
	var short_span := minf(floor_rect.size.x, floor_rect.size.y)
	var long_span := maxf(floor_rect.size.x, floor_rect.size.y)
	var narrow := not plan.is_polygonal(room) and (short_span < 2.6 or long_span > short_span * 3.5)
	var along := Vector2.RIGHT if floor_rect.size.x >= floor_rect.size.y else Vector2.DOWN
	var corners := [
		Vector2(floor_rect.position.x + foot.x / 2.0 + g, floor_rect.position.y + foot.y / 2.0 + g),
		Vector2(floor_rect.end.x - foot.x / 2.0 - g, floor_rect.position.y + foot.y / 2.0 + g),
		Vector2(floor_rect.position.x + foot.x / 2.0 + g, floor_rect.end.y - foot.y / 2.0 - g),
		Vector2(floor_rect.end.x - foot.x / 2.0 - g, floor_rect.end.y - foot.y / 2.0 - g),
	]
	var extra: Array[Rect2] = _window_blocks(plan, room, key)
	var best: Dictionary = {}
	var best_score := -INF
	# All four corners are scored rather than shuffled: a barrel belongs in
	# the corner nobody walks through, and which one that is depends on
	# where the doors are, not on the roll of a die.
	for ci in range(4):
		var jitter: float = r.randf() * HouseFurnishScore.JITTER
		var found: Dictionary = {}
		var slid := 0.0
		# slide out of the corner along both walls until it fits
		for slide in range(6):
			for dir in [Vector2(1, 0), Vector2(0, 1)]:
				if narrow and dir != along:
					continue
				var sign_x: float = 1.0 if ci == 0 or ci == 2 else -1.0
				var sign_z: float = 1.0 if ci == 0 or ci == 1 else -1.0
				var off := Vector2(dir.x * sign_x, dir.y * sign_z) * (float(slide) * 0.25)
				var cand: Dictionary = HouseFurnishGeometry.candidate(key, corners[ci] + off, 0.0,
					1.0, 1.0, -1.0, zone_depth_override)
				if HouseFurnishGeometry.fits(plan, room, cand, floor_rect, blocked, zones, extra):
					found = cand
					slid = float(slide)
					break
			if not found.is_empty():
				break
		if found.is_empty():
			continue
		# a piece slid a long way out of the corner is not in the corner
		var score: float = HouseFurnishScore._affinity(plan, room, found) + jitter - slid * 0.05
		if score > best_score:
			best_score = score
			best = found
	HouseFurnishGeometry.commit(plan, room, best, blocked, zones)


## Seats at a table, facing it, with pull-back space behind them.
static func place_around(plan: HousePlan, room: int, key: String,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator,
		want_row := false) -> void:
	var host: int = _find_host(plan, room, ["table", "workbench", "counter"], want_row)
	if host < 0:
		return
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var host_rect: Rect2 = plan.furniture[host]["rect"]
	var hc: Vector2 = host_rect.get_center()
	var best: Dictionary = {}
	var best_score := -INF
	# the four sides of the table, each sampled along its length, first drawn
	# up to it and then -- if the room is too tight for that -- tucked under it
	var sides := [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]
	for tucked in [false, true]:
		if not best.is_empty():
			break
		for n in sides:
			var yaw: float = HouseFurnishGeometry.yaw_facing(-n)        # face back toward the table
			var foot: Vector2 = PropCatalog.footprint_rotated(key, yaw)
			var half: Vector2 = host_rect.size / 2.0
			var depth: float = absf(n.x) * foot.x + absf(n.y) * foot.y
			var out: float = absf(n.x) * half.x + absf(n.y) * half.y + depth / 2.0 + 0.04
			if tucked:
				# under the table, the way a stool lives. Only as far as its own
				# front edge: pushed further it passes the middle of the table
				# and ends up facing away from it. The pull-back space behind it
				# is still required either way -- a seat you cannot get out of
				# is not a seat, and the walking check would say so.
				out -= depth * 0.4
			var along := Vector2(n.y, -n.x)
			var seat_span: float = absf(along.x) * foot.x + absf(along.y) * foot.y
			var run: float = absf(along.x) * host_rect.size.x \
				+ absf(along.y) * host_rect.size.y
			if seat_span > run + LONG_SEAT_OVERHANG:
				# A bench drawn up to the END of a trestle sticks out a metre
				# either side of it, faces the wrong way along the room and
				# blocks the floor beyond: a long seat belongs on a long side.
				continue
			var steps: int = maxi(int(run / 0.45), 1)
			for s in range(steps + 1):
				var t: float = lerpf(-run / 2.0 + seat_span / 2.0, run / 2.0 - seat_span / 2.0,
					float(s) / float(steps))
				var centre: Vector2 = hc + n * out + along * t
				var cand: Dictionary = HouseFurnishGeometry.candidate(key, centre, yaw)
				if not HouseFurnishGeometry.fits(plan, room, cand, floor_rect, blocked, zones, [],
						host_rect if tucked else Rect2()):
					continue
				var score: float = r.randf() - absf(t) * 0.2
				if score > best_score:
					best_score = score
					best = cand
	if not best.is_empty():
		best["host"] = host
	HouseFurnishGeometry.commit(plan, room, best, blocked, zones)


## Which piece a seat is drawn up to.
##
## The first one of the right kind, except when the step asks for a row: a
## great hall seats the trestles, not the high table, and among the trestles it
## seats whichever has the fewest people at it already, so a second bench goes
## to the next table rather than crowding the first.
static func _find_host(plan: HousePlan, room: int, cats: Array,
		want_row := false, first_only := false) -> int:
	var pool: Array[int] = []
	for f in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[f]["key"]) in cats:
			pool.append(f)
	if pool.is_empty():
		return -1
	if first_only:
		return pool[0]
	if not want_row:
		# A chair goes to a TABLE before it goes to a counter or a bench, and
		# to the table with the fewest people at it already. Taking simply the
		# first host in the room put a lobby's chairs round its reception desk,
		# seated a tavern at its bar while the dining table went without, and
		# drew a barracks' second bench up to the end of the FIRST table while
		# the second stood bare (walk QA, 6 Oct).
		var best_free: int = pool[0]
		var best_key := Vector2i(1 << 20, 1 << 20)
		for f4 in pool:
			var rank: int = cats.find(PropCatalog.category(plan.furniture[f4]["key"]))
			var seated := 0
			for g2 in plan.furniture_of(room):
				if int(plan.furniture[g2]["host"]) == f4 \
						and not PropCatalog.has_tag(plan.furniture[g2]["key"], PropCatalog.ON_SURFACE):
					seated += 1
			var key := Vector2i(rank, seated)
			if key.x < best_key.x or (key.x == best_key.x and key.y < best_key.y):
				best_key = key
				best_free = f4
		return best_free
	var rows: Array[int] = []
	for f2 in pool:
		if String(plan.furniture[f2].get("row", "")) != "":
			rows.append(f2)
	# A step that seats a ROW and finds no row seats nobody. Falling back to
	# the first table in the room put a bench in front of a great hall high
	# table on every hall too small for its trestles -- which is the one place
	# in the room nobody sits.
	if rows.is_empty():
		return -1
	var best: int = rows[0]
	var fewest: int = 1 << 20
	for f3 in rows:
		var n := 0
		for g in plan.furniture_of(room):
			if int(plan.furniture[g]["host"]) == f3:
				n += 1
		if n < fewest:
			fewest = n
			best = f3
	return best


## The seat that belongs on the far side of its host, looking the same way it
## looks: the lord bench behind the high table, the clerk stool behind the
## counter.
##
## `around` puts a chair on whichever side of a table has room, which is right
## for a kitchen table and wrong for anything with a front and a back. Nobody
## sits between the high table and the hall. (CAS-010)
##
## The bench stands on its own feet -- no `host` -- because it is not drawn up
## to the table and pushed back in again: it is where the lord sits, the walk
## has to reach it, and a body crossing the dais has to go round it.
static func _place_behind(plan: HousePlan, room: int, key: String,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator) -> void:
	var host: int = _find_host(plan, room, ["table", "workbench", "counter"], false, true)
	if host < 0:
		return
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var host_rect: Rect2 = plan.furniture[host]["rect"]
	var hc: Vector2 = host_rect.get_center()
	var yaw: float = float(plan.furniture[host]["yaw"])
	var back: Vector2 = -HouseFurnishScore._facing_of(yaw)          # away from what the host faces
	var foot: Vector2 = PropCatalog.footprint_rotated(key, yaw)
	var half: Vector2 = host_rect.size / 2.0
	var out: float = absf(back.x) * (half.x + foot.x / 2.0) \
		+ absf(back.y) * (half.y + foot.y / 2.0) + 0.04
	var along := Vector2(back.y, -back.x)
	var run: float = absf(along.x) * host_rect.size.x + absf(along.y) * host_rect.size.y
	var span: float = absf(along.x) * foot.x + absf(along.y) * foot.y
	var best: Dictionary = {}
	var best_score := -INF
	var steps: int = maxi(int(run / 0.45), 1)
	for si in range(steps + 1):
		var t: float = lerpf(-run / 2.0 + span / 2.0, run / 2.0 - span / 2.0,
			float(si) / float(steps))
		var centre: Vector2 = hc + back * out + along * t
		var cand: Dictionary = HouseFurnishGeometry.candidate(key, centre, yaw)
		if not HouseFurnishGeometry.fits(plan, room, cand, floor_rect, blocked, zones, []):
			continue
		# the middle of the table first: that is where the lord sits
		var score: float = r.randf() * 0.2 - absf(t)
		if score > best_score:
			best_score = score
			best = cand
	HouseFurnishGeometry.commit(plan, room, best, blocked, zones)
