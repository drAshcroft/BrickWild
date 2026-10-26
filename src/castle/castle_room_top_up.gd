class_name CastleRoomTopUp
extends RefCounted
## A castle room the furnisher has dressed can still fail the walk QA three
## ways that a house room rarely does, because castle rooms are big and their
## minimum programme is small:
##
##   SEAT_COUNT  a table in a room people eat in seats nobody, or one person
##   SPARSE      a 116 m2 guardroom holds one table: an empty shed
##   LAMPS       and nothing lights it
##
## This pass adds what is missing, room by room, with the ordinary placers and
## their footprint, door, stair and collision rules. It never changes a check.
## A room's additions are kept only if the room is no worse afterwards:
##
##   * no furnishing complaint the plan did not already have (HouseFurnishCheck
##     rules that judge arrangement and walking), and
##   * no loss of walkability INSIDE the room: every door threshold, stair
##     landing, plan zone and use zone of the room that was reachable from the
##     room's own way in still is, on a WalkGrid aligned with HouseNavCheck's.
##
## A room is joined to the rest of its building only through its doors and
## stair landings, so a room whose own thresholds stay connected cannot cut
## off any other room, and the whole-plan HouseNavCheck (half a second to a
## second in a castle tower) is not run here at all. CastleQA runs it on every
## interior and stays the judge. Set `verify_whole_plan` to have this pass run
## it before and after each plan and undo rooms, last first, until the walk is
## no worse; across the castlechange and README hero builds it never had to.
## Validating every trial placement against the whole plan is what turned a
## Crusader castle's build from minutes into 700-940 s (14 Oct).
##
## Two other costs are kept down the same way. A room is dressed in one go and
## judged once; only a room that came out worse is dressed again a piece at a
## time. And the furnishing check is remembered by the furniture state, so the
## state after one room is not checked again as the state before the next.

## Aim a little over the sparse rule's share, so rounding cannot leave a room
## a hair under it.
const COVER_TARGET := HouseFurnishWalkCheck.SPARSE_MIN + 0.008
## Most pieces one room's sparse top-up may try.
const MAX_TRIES := 30
## A great room gets more: wall pieces cover little of a 344 m2 parlour, and 30
## of them left it at 7% (CASTLE-YARD-WINDOW). One extra try per this many m2.
const TRIES_PER_AREA := 8.0

## Every furnishing complaint is judged except the two whose wording carries
## the measure this pass changes ("with 3% of it furnished", "lit by 1"): a
## piece that adds any other complaint is taken back out. seat_count is judged
## too, so no cut ever leaves a table laid for one.
const _CURED := ["sparse:", "lamps:"]

static var dbg_usec := 0
static var dbg_check_usec := 0
static var dbg_nav_usec := 0
static var dbg_rooms := 0
static var dbg_undone := 0
static var dbg_redone := 0
static var dbg_phase_usec: Array[int] = [0, 0, 0]
## True while a room is dressed in one go, before it is judged as a whole.
static var _trusting := false
static var _debug := OS.has_environment("BW_TOPUP_DEBUG")
## Run the whole-plan walk before and after each plan (see the header).
static var verify_whole_plan := OS.has_environment("BW_TOPUP_VERIFY")


## The house furnisher, then this pass: what every castle plan that gets the
## full furnisher calls.
static func furnish(plan: HousePlan, spec: HouseSpec) -> void:
	HouseFurnisher.furnish(plan, spec)
	apply(plan, spec)


## Top up every room of a dressed plan.
static func apply(plan: HousePlan, spec: HouseSpec) -> void:
	if plan == null or plan.room_count() == 0:
		return
	var t0 := Time.get_ticks_usec()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.seed) ^ 0x54_4F_50_55
	_furnish_cache.clear()
	_pass_start = plan.furniture.size()
	var any := false
	for room in range(plan.room_count()):
		any = any or _wants_work(plan, room)
	if not any:
		dbg_usec += Time.get_ticks_usec() - t0
		return
	var nav_t := Time.get_ticks_usec()
	var nav_before: Dictionary = HouseNavCheck.new().check(plan) if verify_whole_plan else {}
	dbg_nav_usec += Time.get_ticks_usec() - nav_t
	var marks: Array[int] = []
	for room in range(plan.room_count()):
		var mark := plan.furniture.size()
		if _wants_work(plan, room):
			_top_up_room(plan, spec, room, rng)
		marks.append(mark)
	# The check on the argument above: a room's own thresholds stayed
	# connected, so the house should walk exactly as before. If it does not,
	# undo whole rooms, last first, until it does.
	if verify_whole_plan and plan.furniture.size() > marks[0]:
		nav_t = Time.get_ticks_usec()
		var nav_after: Dictionary = HouseNavCheck.new().check(plan)
		dbg_nav_usec += Time.get_ticks_usec() - nav_t
		var room := marks.size() - 1
		while room >= 0 and _nav_worse(nav_before, nav_after):
			if plan.furniture.size() > marks[room]:
				plan.furniture.resize(marks[room])
				dbg_undone += 1
				nav_t = Time.get_ticks_usec()
				nav_after = HouseNavCheck.new().check(plan)
				dbg_nav_usec += Time.get_ticks_usec() - nav_t
			room -= 1
	dbg_usec += Time.get_ticks_usec() - t0


static func _nav_worse(before: Dictionary, after: Dictionary) -> bool:
	var had := {}
	for failure in before.get("failures", []):
		had[String(failure)] = int(had.get(String(failure), 0)) + 1
	for failure in after.get("failures", []):
		var count := int(had.get(String(failure), 0))
		if count <= 0:
			return true
		had[String(failure)] = count - 1
	return false


## Only rooms that fail one of the three rules are touched.
static func _wants_work(plan: HousePlan, room: int) -> bool:
	if not HouseGeometry.is_habitable(plan.kind_of(room)):
		return false
	return not _short_tables(plan, room).is_empty() or _sparse(plan, room) \
		or _lights(plan, room) < _lights_wanted(plan, room)


static func _lights_wanted(plan: HousePlan, room: int) -> int:
	var area: float = HouseGeometry.room_area(plan, room)
	if area < HouseFurnishWalkCheck.LAMP_ROOM:
		return 0
	return int(ceil(area / HouseFurnishWalkCheck.LAMP_AREA))


static func _lights(plan: HousePlan, room: int) -> int:
	var lights := 0
	for f in plan.furniture_of(room):
		if PropCatalog.has_tag(String(plan.furniture[f]["key"]), PropCatalog.LIGHT):
			lights += 1
	return lights


static func _sparse(plan: HousePlan, room: int) -> bool:
	var area: float = HouseGeometry.room_area(plan, room)
	if area < HouseFurnishWalkCheck.SPARSE_AREA \
			or HouseFurnishWalkCheck._corridor(HouseGeometry.room_floor_rect(plan, room)):
		return false
	return floor_cover(plan, room) / area < HouseFurnishWalkCheck.SPARSE_MIN


## The floor the sparse rule counts as furnished, measured the same way.
static func floor_cover(plan: HousePlan, room: int) -> float:
	var used := 0.0
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if HouseFurnishWalkCheck._on_floor(p) \
				or (HouseFurnishWalkCheck._is_table(String(p["key"])) and not p.get("mounted", false)):
			used += Rect2(p["rect"]).get_area()
	return used


## Tables the seat-count rule would fail: free-standing tables (not a trestle
## row) holding one person, or nobody in a room people eat in.
static func _short_tables(plan: HousePlan, room: int) -> Array[int]:
	var out: Array[int] = []
	var eats: bool = plan.kind_of(room) in HouseFurnishWalkCheck.EATING
	for t in plan.furniture_of(room):
		var tp: Dictionary = plan.furniture[t]
		if not HouseFurnishWalkCheck._is_table(String(tp["key"])) or tp.get("mounted", false) \
				or String(tp.get("row", "")) != "":
			continue
		var holds := _holds_at(plan, room, t)
		if holds == 1 or (holds == 0 and eats):
			out.append(t)
	return out


static func _holds_at(plan: HousePlan, room: int, table: int) -> int:
	var holds := 0
	for f in plan.furniture_of(room):
		if int(plan.furniture[f].get("host", -1)) == table \
				and HouseFurnishWalkCheck._is_seat(String(plan.furniture[f]["key"])):
			holds += HouseFurnishWalkCheck._holds(plan.furniture[f])
	return holds


static func _top_up_room(plan: HousePlan, spec: HouseSpec, room: int,
		rng: RandomNumberGenerator) -> void:
	dbg_rooms += 1
	var blocked: Array[Rect2] = HouseFurnishPlacement.initial_blocked(plan, room)
	blocked.append_array(_front_door_way(plan, room))
	var zones: Array[Rect2] = []
	for index in plan.furniture_of(room):
		var placed: Dictionary = plan.furniture[index]
		if placed.get("mounted", false):
			continue
		blocked.append(Rect2(placed["rect"]))
		var zone: Rect2 = placed.get("zone", Rect2())
		if zone.size != Vector2.ZERO:
			zones.append(zone)
	var base := _faults(plan, room)
	var mark := plan.furniture.size()
	var blocked_mark := blocked.size()
	var zones_mark := zones.size()
	# Dress the room once without judging each piece, then judge the room. Only
	# a room that came out worse is undone and dressed again a piece at a time.
	# Judging is the expensive part (the whole furnishing check), and nearly
	# every room passes first time.
	_trusting = true
	_units.clear()
	_dress(plan, spec, room, blocked, zones, rng, base)
	_trusting = false
	if plan.furniture.size() > mark and _worse(plan, room, base):
		dbg_redone += 1
		_keep_good_prefix(plan, room, base, blocked, zones, mark, blocked_mark, zones_mark)
		_dress(plan, spec, room, blocked, zones, rng, base)


## Where each unit of a trusted dressing ended (a seat, a fill step, a lamp):
## [furniture, blocked, zones] sizes. Cutting there never splits a table from
## the chairs that make it a table set.
static var _units: Array = []


## A dressing that came out worse is cut back to the longest run of its units
## that is not, found by halving: a few furnishing checks rather than one per
## piece. The validated dressing then carries on from there.
static func _keep_good_prefix(plan: HousePlan, room: int, base: Dictionary,
		blocked: Array[Rect2], zones: Array[Rect2], mark: int, blocked_mark: int,
		zones_mark: int) -> void:
	var rows: Array = plan.furniture.slice(mark)
	var rects: Array[Rect2] = blocked.slice(blocked_mark)
	var used: Array[Rect2] = zones.slice(zones_mark)
	var cuts: Array = []
	for unit in _units:
		if int(unit[0]) > mark and int(unit[0]) <= mark + rows.size() \
				and (cuts.is_empty() or int(unit[0]) > int(cuts[-1][0])):
			cuts.append(unit)
	var lo := -1                     # -1: nothing kept, the room as it was
	var hi := cuts.size() - 1        # the whole dressing is known to be worse
	while lo < hi - 1:
		var mid := (lo + hi) / 2
		_restore(plan, blocked, zones, mark, blocked_mark, zones_mark, rows, rects, used, cuts[mid])
		if _worse(plan, room, base):
			hi = mid
		else:
			lo = mid
	if lo < 0:
		_rollback(plan, blocked, zones, mark, blocked_mark, zones_mark)
	else:
		_restore(plan, blocked, zones, mark, blocked_mark, zones_mark, rows, rects, used, cuts[lo])


static func _restore(plan: HousePlan, blocked: Array[Rect2], zones: Array[Rect2],
		mark: int, blocked_mark: int, zones_mark: int, rows: Array,
		rects: Array[Rect2], used: Array[Rect2], unit: Array) -> void:
	_rollback(plan, blocked, zones, mark, blocked_mark, zones_mark)
	plan.furniture.append_array(rows.slice(0, int(unit[0]) - mark))
	blocked.append_array(rects.slice(0, int(unit[1]) - blocked_mark))
	zones.append_array(used.slice(0, int(unit[2]) - zones_mark))


static func _dress(plan: HousePlan, spec: HouseSpec, room: int, blocked: Array[Rect2],
		zones: Array[Rect2], rng: RandomNumberGenerator, base: Dictionary) -> void:
	# Seats first: a table laid for nobody is the louder defect, and a sparse
	# room's later pieces must leave the places at its table free.
	var t0 := Time.get_ticks_usec()
	for table in _short_tables(plan, room):
		_seat_table(plan, room, table, blocked, zones, rng, base)
	var t1 := Time.get_ticks_usec()
	if _sparse(plan, room):
		_fill(plan, spec, room, blocked, zones, rng, base)
	var t2 := Time.get_ticks_usec()
	_light(plan, spec, room, blocked, zones, rng, base)
	dbg_phase_usec[0] += t1 - t0
	dbg_phase_usec[1] += t2 - t1
	dbg_phase_usec[2] += Time.get_ticks_usec() - t2


## Sconces on the walls until the room has the lights the lamp rule asks for.
## A sconce hangs on a wall, so it never costs a step of floor.
static func _light(plan: HousePlan, spec: HouseSpec, room: int, blocked: Array[Rect2],
		zones: Array[Rect2], rng: RandomNumberGenerator, base: Dictionary) -> void:
	var want := _lights_wanted(plan, room)
	var tries := 0
	while _lights(plan, room) < want and tries < want + 2:
		tries += 1
		var mark := plan.furniture.size()
		var blocked_mark := blocked.size()
		var zones_mark := zones.size()
		HouseFurnishPlacement.place_one(plan, spec, room, "sconce", &"mounted",
			blocked, zones, rng, {"opt": 0.5})
		if plan.furniture.size() == mark:
			break
		if _judge(plan, room, base, blocked, zones):
			_rollback(plan, blocked, zones, mark, blocked_mark, zones_mark)


## The seat kind the room's tables are already set with, or the room's first.
static func _seat_key(plan: HousePlan, room: int) -> String:
	for index in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[index]
		if PropCatalog.category(String(p["key"])) == "seat" and int(p.get("host", -1)) >= 0:
			return String(p["key"])
	var choices: Array[String] = PropCatalog.of_category_for_room("seat", plan.kind_of(room))
	return choices[0] if not choices.is_empty() else ""


## Two places at a table, drawn up together and judged together: the first
## chair alone is "seats 1", as much a defect as "seats 0". If the table will
## not take two, or the pair makes the room worse, both are taken back.
static func _seat_table(plan: HousePlan, room: int, table: int, blocked: Array[Rect2],
		zones: Array[Rect2], rng: RandomNumberGenerator, base: Dictionary) -> void:
	var key := _seat_key(plan, room)
	if key == "":
		return
	var start := plan.furniture.size()
	var start_blocked := blocked.size()
	var start_zones := zones.size()
	for _try in 3:
		if _holds_at(plan, room, table) >= 2:
			break
		var before := plan.furniture.size()
		HouseFurnishPlacement.place_around(plan, room, key, blocked, zones, rng,
			false, [], table)
		if plan.furniture.size() == before:
			break
	if plan.furniture.size() == start:
		return
	if _holds_at(plan, room, table) < 2 or _judge(plan, room, base, blocked, zones):
		_rollback(plan, blocked, zones, start, start_blocked, start_zones)


## The furniture a room of this kind keeps along its walls, largest first. A
## garrison room also gets a row of trestles with benches, the great hall's own
## arrangement.
static func _fill_steps(kind: StringName) -> Array:
	var trestles := [
		{"group": [{"cat": "table", "key": "Table_Large", "rule": &"row", "n": [2, 4],
			"min_n": 2, "pitch": 2.4, "aisle": 1.0, "seat_clearance": 1.1,
			"along": "wall", "opt": 0.5},
			{"cat": "bench", "rule": &"around", "host": "row", "n": [1, 1], "opt": 0.5},
			{"cat": "bench", "rule": &"around", "host": "row", "n": [1, 1], "opt": 0.5},
			{"cat": "bench", "rule": &"around", "host": "row", "n": [1, 1], "opt": 0.5},
			{"cat": "bench", "rule": &"around", "host": "row", "n": [1, 1], "opt": 0.5}]},
	]
	# A table laid for two, standing in the open floor a round tower room has
	# plenty of once its short facets are taken.
	var table_set := {"cat": "table", "key": "Table_Large", "rule": &"set"}
	var stores := [
		{"cat": "chest", "rule": &"wall"},
		{"cat": "storage", "rule": &"wall"},
		{"cat": "crate", "rule": &"corner"},
		{"cat": "barrel", "rule": &"corner"},
	]
	match kind:
		&"guardroom", &"mess":
			return trestles + [table_set, {"cat": "stand", "key": "WeaponStand", "rule": &"wall"}] \
				+ stores + [{"cat": "workbench", "rule": &"wall"}]
		&"hall", &"great_hall", &"dining_room":
			return trestles + [table_set] + stores
		&"nave":
			# More pews, the nave recipe's own row; nothing else stands in one.
			var pews := {"cat": "bench", "rule": &"row", "n": [2, 4], "min_n": 2,
				"pitch": 0.0, "aisle": 1.2, "seat_clearance": 0.0, "along": "wall", "opt": 0.5}
			return [pews, pews]
		&"parlour", &"lounge":
			# A sitting room. When the household eats elsewhere the table goes
			# and only wall storage is left, which leaves a great drum parlour
			# under the sparse rule's share with nowhere to sit at all: a
			# settle along the wall is what the room is for (CASTLE-CHANGE-17).
			# A great drum or keep parlour runs out of wall long before it
			# reaches the sparse share (344 m2 stood at 9% with every wall
			# step refused): the last step is rows of settles down the open
			# floor, the nave's pews in a sitting room (CASTLE-YARD-WINDOW).
			var settles := {"cat": "bench", "rule": &"row", "n": [4, 12], "min_n": 2,
				"pitch": 0.0, "aisle": 1.2, "seat_clearance": 0.0, "along": "axis", "opt": 0.5}
			return [{"cat": "bookcase", "rule": &"wall"}, {"cat": "bench", "rule": &"wall"},
				table_set] + stores + [settles, settles]
		&"bedroom", &"guest_room", &"lords_chamber", &"suite":
			return [{"cat": "chest", "rule": &"wall"}, {"cat": "storage", "rule": &"wall"},
				{"cat": "bookcase", "rule": &"wall"}, table_set]
	return stores


static func _fill(plan: HousePlan, spec: HouseSpec, room: int, blocked: Array[Rect2],
		zones: Array[Rect2], rng: RandomNumberGenerator, base: Dictionary) -> void:
	var area: float = HouseGeometry.room_area(plan, room)
	var steps := _fill_steps(plan.kind_of(room))
	# A parlour in a household that eats elsewhere is a sitting room: the
	# programme rule calls any table in it a second dining table. Ask its
	# question first rather than lay the table and take it up again.
	if HouseFurnishingRecipes.dines_elsewhere(plan, room):
		steps = steps.filter(func(step: Dictionary) -> bool:
			return String(step.get("cat", "")) != "table")
	if steps.is_empty():
		return
	var tries := 0
	var refused := {}
	var i := 0
	while floor_cover(plan, room) / area < COVER_TARGET and tries < MAX_TRIES + int(area / TRIES_PER_AREA) \
			and refused.size() < steps.size():
		var index := i % steps.size()
		i += 1
		if refused.has(index):
			continue
		tries += 1
		var mark := plan.furniture.size()
		var blocked_mark := blocked.size()
		var zones_mark := zones.size()
		var step: Dictionary = steps[index]
		if step.has("group"):
			for part in step["group"]:
				_place(plan, spec, room, part, blocked, zones, rng)
				if plan.furniture.size() == mark:
					break       # no row of trestles, no benches to draw up
		else:
			_place(plan, spec, room, step, blocked, zones, rng)
		var placed := plan.furniture.size() - mark
		var rejected := placed > 0 and _judge(plan, room, base, blocked, zones)
		if _debug:
			print("TOPUP room %d %s %.0fm2 cover %.3f step %s placed %d%s" % [room,
				plan.kind_of(room), area, floor_cover(plan, room) / area,
				step.get("cat", "trestles"), placed, " REJECTED" if rejected else ""])
		if placed == 0 or rejected:
			_rollback(plan, blocked, zones, mark, blocked_mark, zones_mark)
			refused[index] = true


static func _place(plan: HousePlan, spec: HouseSpec, room: int, step: Dictionary,
		blocked: Array[Rect2], zones: Array[Rect2], rng: RandomNumberGenerator) -> void:
	var t0 := Time.get_ticks_usec()
	_place_step(plan, spec, room, step, blocked, zones, rng)
	dbg_place_usec += Time.get_ticks_usec() - t0


static var dbg_place_usec := 0


static func _place_step(plan: HousePlan, spec: HouseSpec, room: int, step: Dictionary,
		blocked: Array[Rect2], zones: Array[Rect2], rng: RandomNumberGenerator) -> void:
	if step["rule"] == &"row":
		HouseFurnishPlacement.place_row(plan, room, step, blocked, zones, rng)
		return
	if step["rule"] == &"set":
		_table_set(plan, room, String(step["key"]), blocked, zones, rng)
		return
	var full := step.duplicate()
	full["opt"] = 0.5
	# An overlay piece no wall will take is dropped, not stood in the floor.
	full["wall_only"] = true
	HouseFurnishPlacement.place_one(plan, spec, room, String(step["cat"]),
		StringName(step["rule"]), blocked, zones, rng, full)


## A free-standing table and two places at it, in the seats the room's
## tables are already set with. Without both places the table is taken back.
##
## The spot is the clear one nearest the middle of the room, found on a
## SET_STEP grid, first fit. HouseFurnishPlacement.place_free scores every
## point of a 12 cm grid (up to 128 x 128 per yaw and scale) for the best
## spot; across seven storeys of a 254 m2 tower that search alone cost ten
## minutes of a Crusader castle's build. The tests a spot must pass are the
## same: HouseFurnishGeometry.fits against the room, its furniture and its
## use zones, the window sills, the approach to every door, and a chair and a
## passage (TABLE_GAP) from every other table.
const SET_STEP := 0.5
## Spots tried whose table then would not take two seats.
const SET_TRIES := 6


static func _table_set(plan: HousePlan, room: int, key: String, blocked: Array[Rect2],
		zones: Array[Rect2], rng: RandomNumberGenerator) -> void:
	var seat_key := _seat_key(plan, room)
	if seat_key == "":
		return
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var extra: Array[Rect2] = HouseFurnishPlacement._window_blocks(plan, room, key)
	extra.append_array(HouseFurnishPlacement.door_approaches(plan, room))
	for f in plan.furniture_of(room):
		if HouseFurnishWalkCheck._is_table(String(plan.furniture[f]["key"])) \
				and not plan.furniture[f].get("mounted", false):
			extra.append(Rect2(plan.furniture[f]["rect"]).grow(HouseFurnishPlacement.TABLE_GAP))
	var inner := floor_rect.grow(-HouseGeometry.PATH_MIN * 0.5)
	var centre := floor_rect.get_center()
	var spots: Array[Vector2] = []
	var nx := int(floor_rect.size.x / SET_STEP)
	var nz := int(floor_rect.size.y / SET_STEP)
	for ix in range(nx + 1):
		for iz in range(nz + 1):
			spots.append(floor_rect.position + Vector2(ix, iz) * SET_STEP)
	spots.sort_custom(func(p: Vector2, q: Vector2) -> bool:
		return p.distance_squared_to(centre) < q.distance_squared_to(centre))
	# Along the room first: a table across a long room stands in its way.
	var yaws: Array = [0.0, PI / 2.0]
	var along := PropCatalog.footprint_rotated(key, 0.0)
	if (along.x >= along.y) != (floor_rect.size.x >= floor_rect.size.y):
		yaws = [PI / 2.0, 0.0]
	var seating_base := _seating_faults(plan)
	var tries := 0
	for spot in spots:
		for yaw in yaws:
			var cand: Dictionary = HouseFurnishGeometry.candidate(key, spot, float(yaw))
			# free-standing: a path's half-width from the walls, as place_free
			if not inner.encloses(Rect2(cand["rect"])):
				continue
			if not HouseFurnishGeometry.fits(plan, room, cand, floor_rect, blocked, zones, extra):
				continue
			var mark := plan.furniture.size()
			var blocked_mark := blocked.size()
			var zones_mark := zones.size()
			HouseFurnishGeometry.commit(plan, room, cand, blocked, zones)
			for _seat in 2:
				HouseFurnishPlacement.place_around(plan, room, seat_key, blocked, zones, rng,
					false, [], mark)
			# fits() keeps a chair's body off other pull-out floor, not its own
			# pull-out floor off a neighbour's; the walk rules say both.
			if _holds_at(plan, room, mark) >= 2 and _seating_faults(plan) <= seating_base:
				return
			_rollback(plan, blocked, zones, mark, blocked_mark, zones_mark)
			tries += 1
			if tries >= SET_TRIES:
				return
			break        # the other yaw at the same spot is the same crowding


## The walk rules about people at tables, counted over the plan: cheap (no
## walking), and the ones a crowded table set breaks.
static func _seating_faults(plan: HousePlan) -> int:
	var walk := HouseFurnishWalkCheck.new()
	walk.check_pull_out(plan)
	walk.check_tuck(plan)
	walk.check_table_band(plan)
	walk.check_seat_kinds(plan)
	return walk.failures.size()


static func _rollback(plan: HousePlan, blocked: Array[Rect2], zones: Array[Rect2],
		mark: int, blocked_mark: int, zones_mark: int) -> void:
	plan.furniture.resize(mark)
	blocked.resize(blocked_mark)
	zones.resize(zones_mark)


## The way in through the front door that the walk QA keeps clear of every
## piece on the same storey, whatever room the piece is in.
static func _front_door_way(plan: HousePlan, room: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var d := plan.entrance()
	if d < 0:
		return out
	var door: Dictionary = plan.doors[d]
	if HousePlan.record_storey(plan.rooms[room]) != HousePlan.record_storey(door):
		return out
	var n: Vector2 = door["normal"]
	var along := Vector2(n.y, -n.x).abs()
	var c: Vector2 = door["pos"]
	var w := float(door["width"])
	for side in [-1.0, 1.0]:
		var a: Vector2 = c - along * (w / 2.0)
		var b: Vector2 = c + along * (w / 2.0) + n * side * HouseFurnishPlacement.DOOR_APPROACH
		out.append(Rect2(a.min(b), (b - a).abs()))
	return out


# -- judging a room -----------------------------------------------------------

## What the room's state is judged by: the furnishing complaints the plan has
## under the kept rules, and the room's own walk.
static func _faults(plan: HousePlan, room: int) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	# The pass only appends rows and truncates back to a mark, so the rows it
	# has added name the plan's state exactly. A room judged after the last
	# one was accepted, or after a rollback, is judged from the cache.
	var state := hash(str(plan.furniture.slice(_pass_start)))
	var counts: Dictionary = _furnish_cache.get(state, {})
	if not _furnish_cache.has(state):
		var report := HouseFurnishCheck.new().check(plan)
		for failure in report.get("failures", []):
			var text := String(failure)
			if not _kept(text):
				continue
			counts[text] = int(counts.get(text, 0)) + 1
		_furnish_cache[state] = counts
		dbg_check_calls += 1
	var walk := room_walk_faults(plan, room)
	dbg_check_usec += Time.get_ticks_usec() - t0
	return {"furnish": counts, "walk": walk}


static var _furnish_cache: Dictionary = {}
static var _pass_start := 0
static var dbg_check_calls := 0


static func _kept(text: String) -> bool:
	for prefix in _CURED:
		if text.begins_with(prefix):
			return false
	return true


## A unit of dressing has been placed: while trusting, note where it ended and
## let it stand; otherwise judge it.
static func _judge(plan: HousePlan, room: int, base: Dictionary,
		blocked: Array[Rect2], zones: Array[Rect2]) -> bool:
	if _trusting:
		_units.append([plan.furniture.size(), blocked.size(), zones.size()])
		return false
	return _worse(plan, room, base)


## True when the room now has a complaint it did not have before.
static func _worse(plan: HousePlan, room: int, base: Dictionary) -> bool:
	if _trusting:
		return false
	var now := _faults(plan, room)
	if int(now["walk"]) > int(base["walk"]):
		if _debug:
			print("TOPUP   worse: walk %d -> %d" % [int(base["walk"]), int(now["walk"])])
		return true
	var had: Dictionary = base["furnish"]
	for text in now["furnish"]:
		if int(now["furnish"][text]) > int(had.get(text, 0)):
			if _debug:
				print("TOPUP   worse: ", text)
			return true
	return false


## How many of the room's own places a person cannot walk to from the room's
## way in: door thresholds on this room's side, stair landings, the floor the
## plan keeps clear, each piece's use zone, and the room body itself; plus one
## for any stranded pocket bigger than HouseNavCheck.ISLAND_MIN_AREA.
##
## The grid is laid over the whole storey rectangle with HouseNavCheck's cell,
## so its cells fall exactly where the whole-plan walk's do; only this room's
## floor (and its doorways) is laid down, so it costs one room, not a castle.
static func room_walk_faults(plan: HousePlan, room: int) -> int:
	var level := HousePlan.record_storey(plan.rooms[room])
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var grid := WalkGrid.new()
	grid.setup(HouseGeometry.storey_rect(plan, level), HouseGeometry.NAV_CELL)
	if plan.is_polygonal(room):
		grid.add_floor_poly(plan.outline_of(room))
	else:
		grid.add_floor(floor_rect)
	var targets: Array[Rect2] = []
	var grows: Array[float] = []
	for d in plan.doors_of(room):
		var door: Dictionary = plan.doors[d]
		if HousePlan.record_storey(door) != level:
			continue
		grid.add_floor(HouseWalkSources.door_gap(door))
		var sides: Array = [-1.0] if door["exterior"] else [-1.0, 1.0]
		for side in sides:
			var t: Vector2 = HouseGeometry.door_threshold(door, side)
			if floor_rect.grow(0.05).has_point(t):
				targets.append(Rect2(t - Vector2.ONE * 0.05, Vector2.ONE * 0.1))
				grows.append(HouseGeometry.PERSON_RADIUS)
	if plan.dais_room() == room:
		grid.add_step(plan.dais_rect(), plan.dais_rise())
		targets.append(plan.dais_rect())
		grows.append(0.0)
	for stair in plan.stairs:
		if int(stair.get("a", -1)) == room and int(stair.get("storey", 0)) == level:
			targets.append(HouseWalkSources.stair_rect(stair, false))
			grows.append(0.0)
		if int(stair.get("b", -1)) == room and int(stair.get("to_storey", -999)) == level:
			targets.append(HouseWalkSources.stair_rect(stair, true))
			grows.append(0.0)
	for zone in plan.zones_of(room):
		targets.append(Rect2(zone))
		grows.append(0.0)
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		if p.get("mounted", false) or not PropCatalog.blocks_floor(String(p["key"])):
			continue
		if HousePlan.record_storey(p) != level:
			continue
		grid.add_obstacle(p["rect"])
		var zone: Rect2 = p.get("zone", Rect2())
		if int(p["room"]) == room and zone.size.x > 0.0:
			targets.append(zone)
			grows.append(HouseGeometry.PERSON_RADIUS * 0.5)
	for column in plan.columns:
		if int(column.get("storey", 0)) != level:
			continue
		var pos: Vector2 = column.get("pos", Vector2.ZERO)
		var size: Vector2 = column.get("size", Vector2.ZERO)
		if size.x > 0.0 and size.y > 0.0:
			grid.add_obstacle(Rect2(pos - size * 0.5, size))
	var breast := HouseGeometry.hearth_breast(plan)
	if not breast.is_empty() and int(breast["storey"]) == level:
		grid.add_obstacle_poly(breast["outline"])
	grid.build(HouseGeometry.PERSON_RADIUS)
	var body := floor_rect.grow(-HouseNavCheck.DOORWAY_LIP)
	if body.size.x > 0.3 and body.size.y > 0.3:
		targets.append(body)
		grows.append(0.0)
	# The way in: the first door threshold or landing a person can stand on.
	var seeded := false
	for index in range(targets.size()):
		if grid.flood_from(targets[index].get_center()):
			seeded = true
			break
	if not seeded:
		return targets.size() + 1
	var faults := 0
	for index in range(targets.size()):
		if not grid.reached(targets[index], grows[index]):
			faults += 1
	if grid.stranded_area() > HouseNavCheck.ISLAND_MIN_AREA:
		faults += 1
	return faults
