class_name HouseFurnisher
extends RefCounted
## Fills the rooms.
##
## Every piece is placed by a rule rather than a coordinate, and each rule
## encodes something a person would say out loud about furniture:
##
##   wall      a bed, a cabinet, a bookcase wants its back to a wall
##   free      a table wants room all round it
##   around    seats belong at a table, facing it, with room to push back
##   corner    barrels and crates go where nobody walks
##   mounted   shelves, racks and sconces hang on the wall at head height
##   ceiling   the chandelier hangs over the middle of the room
##   on        a mug belongs on a table, never on the floor
##
## Each placement records the floor it occupies AND the floor a person needs to
## USE it -- the pull-back space behind a chair, the side of a bed you get into
## it from. Declaring that zone here is what lets HouseNavCheck ask the only
## question that really matters: can somebody walk in the front door and reach
## every one of them.
##
## Nothing here trusts itself. Everything it places is judged afterwards by
## HouseFurnishCheck and HouseNavCheck, which re-derive the overlaps, the
## clearances and the walkable floor from the placements alone.

static func furnish(plan: HousePlan, spec: HouseSpec) -> void:
	plan.furniture.clear()
	plan.rugs.clear()
	plan.hearth.erase("breast")
	for i in range(plan.room_count()):
		_furnish_room(plan, spec, i)
	HouseFurnishRepair.relax(plan)


## Whether native furnishing can author any part of this plan's emitted shell.
static func shell_needs_furnishing(plan: HousePlan) -> bool:
	# Keep this beside the features that derive emitted shell geometry from
	# furniture. A planner may have selected a hearth wall before a shop's
	# temporary hall was renamed to a room whose recipe contains no hearth.
	if plan.focus_cat() == "hearth":
		return true
	var hearth_room := plan.hearth_room()
	if hearth_room >= 0:
		for step in HouseFurnishingRecipes.RECIPES.get(plan.kind_of(hearth_room), []):
			if step["cat"] == "hearth":
				return true
	for room in plan.rooms:
		if room["kind"] in HouseFurnishingRecipes.RUG_ROOM_KINDS:
			return true
	return false


## Placement-only shell preparation. Chimney masonry follows the final hearth
## placement, and floor textiles follow tables that survive navigation repair.
## Both are emitted shell geometry, so the complete native furnishing pass is
## required before discarding temporary furniture. Keep all authored shell data.
static func prepare_shell_focus(plan: HousePlan, spec: HouseSpec) -> void:
	furnish(plan, spec)
	plan.furniture.clear()


## Does anybody sleep anywhere in this plan?
##
## A hall doubles as a bedroom only when nothing else in the building is one,
## which is what a one-room cottage does. But &"bedroom" is not the only room
## people sleep in: a keep lord sleeps in his chamber at the top, and asking
## for that one name put a bed in his hall as well.
static func _anybody_sleeps(plan: HousePlan) -> bool:
	for kind in HouseGeometry.SLEEPING:
		if plan.has_kind(kind):
			return true
	return false


static func _furnish_room(plan: HousePlan, spec: HouseSpec, room: int) -> void:
	var kind: StringName = plan.kind_of(room)
	var steps: Array = []
	# A house with no room big enough to be a bedroom sleeps in its hall, which
	# is what a one-room cottage has always done. The bed goes in first, before
	# the table has taken the good wall.
	var sleeps_here: bool = not spec is ShopSpec and kind == &"hall" \
		and not _anybody_sleeps(plan)
	if sleeps_here:
		steps.append({"cat": "bed", "rule": &"wall", "n": [1, 1], "opt": 1.0})
		steps.append({"cat": "chest", "rule": &"wall", "n": [1, 1], "opt": 0.9})
	for s in HouseFurnishingRecipes.RECIPES.get(kind, []):
		# A family without a supported flue omits the hearth prop, while its
		# table/bed programme remains the same.
		if String(s["cat"]) == "hearth" and not spec.allows_hearth_furniture():
			continue
		# With a bed in it the hall has no middle left to stand a table in, so
		# the table goes against a wall -- which is what a one-room cottage
		# does anyway.
		if sleeps_here and String(s["cat"]) == "table":
			var wall_table: Dictionary = s.duplicate()
			wall_table["rule"] = &"wall"
			steps.append(wall_table)
			continue
		steps.append(s)
	if spec is ShopSpec and (spec as ShopSpec).business == &"barracks":
		var room_area := HouseGeometry.room_area(plan, room)
		if kind == &"dormitory" and room_area >= 150.0:
			steps.append({"cat": "bed", "rule": &"row", "n": [4, 6], "min_n": 4,
				"pitch": 0.0, "aisle": 1.0, "along": "wall",
				"avoid_window_walls": true, "avoid_door_lines": true, "opt": 1.0})
		if kind == &"armoury" and room_area >= 150.0:
			steps.append({"cat": "stand", "key": "WeaponStand", "rule": &"row",
				"n": [2, 4], "min_n": 2, "pitch": 0.0, "aisle": 0.9,
				"along": "wall", "opt": 1.0})
		if kind == &"mess":
			var extra_tables := 1 if room_area >= 50.0 else 0
			for _table in range(extra_tables):
				steps.append({"cat": "table", "rule": &"free", "n": [1, 1], "opt": 1.0})
				steps.append({"cat": "bench", "rule": &"around", "n": [2, 2], "opt": 1.0})

	# the trade fits out whichever room it works in, after that room's own
	# recipe has had its say
	var trade_room: StringName = HouseSpec.TRADES[spec.trade]["room"] \
		if not spec is ShopSpec else (spec as ShopSpec).front_room()
	var fittings: Array = HouseFurnishingRecipes.TRADE_FITTINGS.get(spec.trade, []) if not spec is ShopSpec \
		else HouseFurnishingRecipes.SHOP_FITTINGS.get((spec as ShopSpec).business, [])
	if trade_room == kind:
		for s2 in fittings:
			if StringName(s2.get("room", trade_room)) == kind:
				if plan.focus_room() == room and String(s2["cat"]) == plan.focus_cat():
					steps.insert(0, s2)
				else:
					steps.append(s2)
	else:
		for s3 in fittings:
			if s3.has("room") and StringName(s3["room"]) == kind:
				steps.append(s3)

	# The focus is the one piece the room is arranged around, so it goes in
	# whether or not the recipe happened to list it: a tavern's bar is not in
	# the dining-room recipe, a great hall's high table is not in any.
	if plan.focus_room() == room and plan.focus_cat() != "":
		var listed := false
		for s3 in steps:
			if String(s3["cat"]) == plan.focus_cat():
				listed = true
		if not listed:
			var choices: Array[String] = PropCatalog.of_category(plan.focus_cat())
			if not choices.is_empty():
				var wants_wall: bool = PropCatalog.has_tag(choices[0], PropCatalog.WALL)
				# and it goes in FIRST: the bar takes the wall across from the
				# door before the row of tables can take it
				steps.insert(0, {"cat": plan.focus_cat(),
					"rule": &"wall" if wants_wall else &"free", "n": [1, 1], "opt": 1.0})

	# The things a room cannot do without go in first, whether they came from
	# the room recipe or from the trade. Otherwise a smithy spends its one good
	# wall on a weapon rack and has nowhere left for the workbench.
	#
	# Among equals the room's own recipe wins: a workshop is a workshop because
	# of its bench, and the trade's anvil can take what is left. Ordering them
	# the other way round left one house with a forge and nothing to work at.
	for i in range(steps.size()):
		steps[i] = steps[i].duplicate()
		steps[i]["order"] = i
	steps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["opt"]), float(b["opt"])):
			return float(a["opt"]) > float(b["opt"])
		return int(a["order"]) < int(b["order"]))

	var blocked: Array[Rect2] = HouseFurnishPlacement.initial_blocked(plan, room)
	# Use zones are tracked apart from footprints. Two people may share a
	# gangway, so zones may overlap each other -- but nothing solid may stand
	# in one, or the piece it belongs to becomes unusable. Leaving zones out of
	# the occupancy entirely is what let a chest be set down in the only gap
	# beside a bed.
	var zones: Array[Rect2] = []
	var r: RandomNumberGenerator = spec.rng
	# The dais belongs to the piece the room is arranged around and to whoever
	# sits behind it. Those two steps come first and stand ON it; everything
	# after them treats it as occupied ground, because a barrel on the dais is
	# a barrel on the lord's table and a row of trestles that runs up onto the
	# step is a row that has walked over the high table.
	var close_dais: int = _dais_closes_after(plan, room, steps)
	var dais_open: bool = close_dais >= 0
	for si in range(steps.size()):
		var step: Dictionary = steps[si]
		if dais_open and si > close_dais:
			blocked.append(plan.dais_rect())
			dais_open = false
		# opt 1.0 means the room is not that room without it. Anything less is a
		# dressing roll, nudged by how cluttered the household is. Rolling for
		# the mandatory pieces too is how a bedroom came out with no bed in it
		# five per cent of the time.
		var must: bool = float(step["opt"]) >= 1.0 \
			and not bool(step.get("repair_optional", false))
		if not must and not bool(step.get("always_attempt", false)) \
				and r.randf() > float(step["opt"]) * lerpf(0.75, 1.15, spec.clutter):
			continue
		var placed_from := plan.furniture.size()
		if step["rule"] == &"row":
			HouseFurnishPlacement.place_row(plan, room, step, blocked, zones, r)
			for placed in range(placed_from, plan.furniture.size()):
				plan.furniture[placed]["must"] = must
			continue
		var lo: int = int(step["n"][0])
		var hi: int = int(step["n"][1])
		var want: int = lo if hi <= lo else r.randi_range(lo, hi)
		var seats_before: int = _count_cat(plan, room, ["seat", "bench"])
		for k in range(want):
			var piece_from := plan.furniture.size()
			HouseFurnishPlacement.place_one(plan, spec, room, String(step["cat"]), step["rule"],
				blocked, zones, r, step)
			for placed in range(piece_from, plan.furniture.size()):
				plan.furniture[placed]["must"] = must
		# A table nobody can sit at is worse than no table: it takes the middle
		# of the room and gives nothing back. If not one seat would go round it,
		# the table goes instead, and the plan records why.
		#
		# A row is the exception: it is placed and judged as a row (straight,
		# pitched, its own shared aisle), and "around" finding nowhere to draw
		# a chair up to ONE end of a long trestle is not the same failure as a
		# free-standing table nobody can reach at all.
		if step["rule"] == &"around" and _count_cat(plan, room, ["seat", "bench"]) \
				== seats_before and _count_freestanding_tables(plan, room) > 0:
			_drop_the_table(plan, room, blocked, zones)
	if dais_open:
		blocked.append(plan.dais_rect())
	_ensure_seating(plan, room, blocked, zones, r)
	_ensure_light(plan, room, r)
	_keep_the_room_passable(plan, room, blocked, zones)


## The last step allowed to put something on the dais: the seat behind the
## focus if the recipe has one, else the focus itself. -1 when the room has no
## dais, in which case nothing is closed off at all.
static func _dais_closes_after(plan: HousePlan, room: int, steps: Array) -> int:
	if plan.dais_room() != room or plan.dais_rect().size.x <= 0.0:
		return -1
	for i in range(steps.size() - 1, -1, -1):
		if steps[i]["rule"] == &"behind":
			return i
	for i2 in range(steps.size()):
		if String(steps[i2]["cat"]) == plan.focus_cat():
			return i2
	return -1


## Check the walking as each room is finished, not only at the end.
##
## Everything furnished before this room was sound, so if the house has just
## become unwalkable, it is this room that did it -- and the piece responsible
## is one of the ones just put in. Catching it here is worth the walk: by the
## time the whole house is furnished, working out which of forty pieces is the
## problem costs far more, and the answer is worse, because the room has been
## dressed around the offending piece since.
static func _keep_the_room_passable(plan: HousePlan, room: int,
		blocked: Array[Rect2], zones: Array[Rect2]) -> void:
	for attempt in range(3):
		var rep: Dictionary = HouseNavCheck.new().check(plan)
		if rep["ok"]:
			return
		var victim := -1
		var best_area := 0.0
		for f in plan.furniture_of(room):
			var p: Dictionary = plan.furniture[f]
			if p.get("must", false) or p.get("mounted", false) or p["host"] >= 0:
				continue
			if not PropCatalog.blocks_floor(p["key"]):
				continue
			var rect: Rect2 = p["rect"]
			var area: float = rect.size.x * rect.size.y
			if area > best_area:
				best_area = area
				victim = f
		if victim < 0:
			return
		var repair_indices := HouseFurnishRepair._repair_target_indices(plan, victim)
		for ri in range(repair_indices.size() - 1, -1, -1):
			var index: int = repair_indices[ri]
			if index >= plan.furniture.size():
				continue
			blocked.erase(plan.furniture[index]["rect"])
			zones.erase(plan.furniture[index]["zone"])
			plan.furniture.remove_at(index)
			HouseFurnishRepair.reindex_hosts(plan, index)


## A table with nothing to sit at it is a table nobody uses.
##
## The seating steps are rolls like any other, and a room can lose all of them
## to chance or to a tight corner. So the room is checked once at the end: if
## there is a table and no seat, one more seat is attempted, and if even that
## will not go in, the table comes out and the plan says so.
static func _ensure_seating(plan: HousePlan, room: int, blocked: Array[Rect2],
		zones: Array[Rect2], r: RandomNumberGenerator) -> void:
	if _count_cat(plan, room, ["table"]) == 0:
		if plan.was_dropped(room, "table"):
			_recover_dining_pair(plan, room, blocked, zones)
		return
	if _count_cat(plan, room, ["seat", "bench"]) > 0:
		return
	for cat in ["seat", "bench"]:
		for key in PropCatalog.of_category(cat):
			HouseFurnishPlacement.place_around(plan, room, key, blocked, zones, r)
			if _count_cat(plan, room, ["seat", "bench"]) > 0:
				return
	_drop_the_table(plan, room, blocked, zones)
	_recover_dining_pair(plan, room, blocked, zones)


## A table that fits alone may leave no room for a chair. Before accepting
## that compromise, try the measured table sizes with a seat as one unit.
## This bounded fallback runs only after the ordinary recipe lost its table.
static func _recover_dining_pair(plan: HousePlan, room: int, blocked: Array[Rect2],
		zones: Array[Rect2]) -> void:
	if _count_cat(plan, room, ["table"]) > 0:
		return
	if plan.focus_room() == room and plan.focus_cat() == "table":
		return # an altar or high table has its own authored seating contract
	var required := false
	for step in HouseFurnishingRecipes.RECIPES.get(plan.kind_of(room), []):
		if step["cat"] == "table" and float(step["opt"]) >= 1.0 and step["rule"] == &"free":
			required = true
	if not required:
		return
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = hash("dining|%d|%d" % [plan.spec.seed, room])
	for key in PropCatalog.of_category("table"):
		var placed_from := plan.furniture.size()
		HouseFurnishPlacement.place_free(plan, room, key, blocked, zones, local_rng, true)
		if _count_cat(plan, room, ["table"]) > 0:
			for placed in range(placed_from, plan.furniture.size()):
				plan.furniture[placed]["must"] = true
			# These two requirements have now been physically restored.
			var dropped: Array = plan.compromises.get(room, [])
			dropped.erase("table")
			dropped.erase("seat")
			break


static func _count_cat(plan: HousePlan, room: int, cats: Array) -> int:
	var n := 0
	for f in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[f]["key"]) in cats:
			n += 1
	return n


## Tables that stand on their own, as opposed to ones placed as part of a row.
static func _count_freestanding_tables(plan: HousePlan, room: int) -> int:
	var n := 0
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) == "table" and String(p.get("row", "")) == "":
			n += 1
	return n


## Take the table back out, and free the floor it was holding.
static func _drop_the_table(plan: HousePlan, room: int, blocked: Array[Rect2],
		zones: Array[Rect2]) -> void:
	for f in range(plan.furniture.size() - 1, -1, -1):
		var p: Dictionary = plan.furniture[f]
		if int(p["room"]) != room or PropCatalog.category(p["key"]) != "table":
			continue
		# a row is placed and judged as a row; taking one trestle out of the
		# middle of it would break the very thing the row rule measures
		if String(p.get("row", "")) != "":
			continue
		# nor the piece the PLAN put there. A table nobody sits at is usually a
		# table in the way -- but a chapel altar is a table nobody sits at on
		# purpose, and dropping it is the furnisher overruling the plan that
		# asked for it (INT-002).
		if plan.focus_room() == room and plan.focus_cat() == "table" \
				and Rect2(p["rect"]).get_center().distance_to(plan.focus_pos()) \
				< HouseFurnishScore.FOCUS_TOL:
			continue
		blocked.erase(p["rect"])
		plan.note_compromise(room, "table")
		plan.furniture.remove_at(f)
		HouseFurnishRepair.reindex_hosts(plan, f)
		return


## A room nobody can see in is not furnished. If the recipe's sconces all
## failed to find a stretch of clear wall, fall back to a candle on whatever
## surface the room has, and failing that to a sconce anywhere at all.
static func _ensure_light(plan: HousePlan, room: int, r: RandomNumberGenerator) -> void:
	if not HouseGeometry.is_habitable(plan.kind_of(room)):
		return
	for f in plan.furniture_of(room):
		if PropCatalog.has_tag(plan.furniture[f]["key"], PropCatalog.LIGHT):
			return
	for cat in ["candle", "sconce"]:
		var before: int = plan.furniture.size()
		var rule: StringName = &"on" if cat == "candle" else &"mounted"
		var choices: Array[String] = PropCatalog.of_category(cat)
		if choices.is_empty():
			continue
		var key: String = choices[r.randi_range(0, choices.size() - 1)]
		if rule == &"on":
			HouseFurnishSurface.place_on_surface(plan, room, key, r)
		else:
			HouseFurnishSurface.place_mounted(plan, room, key, r)
		if plan.furniture.size() > before:
			return
