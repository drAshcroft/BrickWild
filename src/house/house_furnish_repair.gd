class_name HouseFurnishRepair
extends RefCounted

const MAX_REPAIRS := 8
const MAX_TRIALS := 8

## Furnish, then walk the house, then take something out and walk it again.
##
## Rules that place one piece at a time cannot see what the room will look like
## when the last of them has been placed: three sound decisions in a row still
## add up to a barrel in the only gap between the table and the wall. So the
## furnisher finishes by asking HouseNavCheck whether a person can actually get
## about, and while the answer is no it takes something out.
##
## WHICH something is measured, not guessed. An earlier version removed the
## biggest thing in the room that had been reported, which is usually the wrong
## room -- what blocks a bedroom is in the parlour you would cross to reach it.
## This version tries removing each candidate in turn. It prefers an optional
## loss, then a complete route repair, then the smallest complete removal
## before comparing floor gains. That keeps one bad chair from costing its
## table, and a kitchen route from costing its required hearth.
##
## Pieces the room cannot do without are only removed when nothing else helps,
## and when one goes the plan records it, so the furnishing check can report a
## missing bed as the compromise it was rather than as a defect.
static func relax(plan: HousePlan) -> int:
	var removed := 0
	for attempt in range(MAX_REPAIRS):
		var before: Dictionary = HouseNavCheck.new().check(plan)
		if before["ok"]:
			break
		var base: int = int(before["stats"].get("reached_cells", 0))
		var best := -1
		var best_gain := 0
		var best_must := true
		var best_solved := false
		var best_loss := 999999
		for f in _candidates(plan, before):
			var p: Dictionary = plan.furniture[f]
			var must: bool = p.get("must", false)
			var trial: HousePlan = _without(plan, f)
			var after: Dictionary = HouseNavCheck.new().check(trial)
			var gain: int = int(after["stats"].get("reached_cells", 0)) - base
			var solved: bool = bool(after["ok"])
			var loss: int = plan.furniture.size() - trial.furniture.size()
			if gain <= 0 and not solved:
				continue
			# Preserve required activities first. Among candidates with the same
			# necessity, a complete repair outranks a partial floor gain. A chair
			# should not take its table and the other seats with it.
			if best < 0 or (best_must and not must) \
					or (best_must == must and solved and not best_solved) \
					or (solved and best_solved and best_must == must and loss < best_loss) \
					or (solved and best_solved and best_must == must and loss == best_loss and gain > best_gain) \
					or (not solved and not best_solved and best_must == must and gain > best_gain):
				best = f
				best_gain = gain
				best_must = must
				best_solved = solved
				best_loss = loss
		if best < 0:
			# A plateau: no single removal opens anything up, because two
			# pieces are blocking the same route between them. Take out the
			# biggest optional thing near the trouble anyway and look again --
			# without this the search stops one move short of the answer.
			best = _biggest_near(plan, before)
			if best < 0:
				break
		if plan.furniture[best].get("must", false):
			var compromised: Dictionary = plan.furniture[best]
			var compromised_room: int = int(compromised["room"])
			plan.note_compromise(compromised_room, String(compromised["cat"]))
			var activity_group: String = String(compromised.get("activity_group", ""))
			if not activity_group.is_empty():
				plan.note_compromise(compromised_room, "activity:" + activity_group)
		var repair_indices := _repair_target_indices(plan, best)
		for ri in range(repair_indices.size() - 1, -1, -1):
			var index: int = repair_indices[ri]
			if index >= plan.furniture.size():
				continue
			plan.furniture.remove_at(index)
			reindex_hosts(plan, index)
		removed += repair_indices.size()
	_plan_rugs(plan)
	return removed


## One rug under each table -- and ONE under each row of tables. A row of
## trestles with a separate scrap of carpet under every one, each clipped to a
## sliver by its neighbours, read as a stack of unexplained floor patches
## (walk QA, 6 Oct): a row is one arrangement and lies on one runner.
static func _plan_rugs(plan: HousePlan) -> void:
	plan.rugs.clear()
	var rows_done := {}
	for index in plan.furniture.size():
		var item: Dictionary = plan.furniture[index]
		var room := int(item["room"])
		if PropCatalog.category(String(item["key"])) != "table" or plan.kind_of(room) not in HouseFurnishingRecipes.RUG_ROOM_KINDS:
			continue
		var row := String(item.get("row", ""))
		var under := Rect2(item["rect"])
		var members: Array[int] = [index]
		if row != "":
			if rows_done.has(row):
				continue
			rows_done[row] = true
			for j in plan.furniture.size():
				if j != index and String(plan.furniture[j].get("row", "")) == row \
						and int(plan.furniture[j]["room"]) == room:
					members.append(j)
					under = under.merge(Rect2(plan.furniture[j]["rect"]))
		var floor := HouseGeometry.room_floor_rect(plan, room)
		var rug := under
		for margin in [0.55, 0.35, 0.15, 0.0]:
			var candidate := under.grow(margin).intersection(floor)
			var fits := true
			if plan.is_polygonal(room):
				for point in Poly.from_rect(candidate):
					fits = fits and Poly.contains_point(plan.outline_of(room), point, 0.01)
			for oi in plan.furniture.size():
				var other: Dictionary = plan.furniture[oi]
				if oi in members or int(other["room"]) != room or PropCatalog.category(other["key"]) != "table":
					continue
				if candidate.intersects(Rect2(other["rect"]).grow(margin)):
					fits = false
			if not fits:
				continue
			rug = candidate
			break
		plan.rugs.append({"id": ("rug_row_%d" if row != "" else "rug_table_%d") % index,
			"table": index, "tables": members, "room": room,
			"storey": plan.storey_of_room(room), "rect": rug})


## The biggest optional piece standing in a room that failed, or in one of its
## neighbours -- what blocks a room is usually in the room you would cross to
## reach it. Used only to break a plateau, where no single removal helps.
static func _biggest_near(plan: HousePlan, rep: Dictionary) -> int:
	var rooms := {}
	var graph: Dictionary = plan.door_graph()
	var stranded := {}
	for i in rep["unreached_rooms"]:
		stranded[int(i)] = true
	for i2 in rep["unreached_rooms"]:
		for nb in graph[int(i2)]:
			rooms[int(nb)] = true
	for f in rep["unreachable_items"]:
		rooms[int(plan.furniture[int(f)]["room"])] = true
	# Only rooms you can actually get to are worth clearing. Whatever is in the
	# way stands between the door you are at and the room you cannot reach, so
	# it is never in the stranded room itself -- and an earlier version spent
	# every one of its attempts moving barrels around inside one.
	for s2 in stranded:
		rooms.erase(s2)
	# optional pieces first; a necessary one only if there is nothing else in
	# the way, and then the caller records it as a compromise
	for allow_must in [false, true]:
		var found: int = _biggest_in(plan, rooms, allow_must)
		if found >= 0:
			return found
	return -1


static func _biggest_in(plan: HousePlan, rooms: Dictionary, allow_must: bool) -> int:
	var best := -1
	var best_area := 0.0
	for f2 in _candidates(plan):
		var p: Dictionary = plan.furniture[f2]
		if not rooms.has(int(p["room"])):
			continue
		if p.get("must", false) and not allow_must:
			continue
		var rect: Rect2 = p["rect"]
		var area: float = rect.size.x * rect.size.y
		if area > best_area:
			best_area = area
			best = f2
	return best


## The pieces worth trying to remove: the ones standing on the floor, including
## seats associated with a table. Biggest first, capped for large houses; a
## named unreachable piece is always included after the cap.
static func _candidates(plan: HousePlan, rep: Dictionary = {}) -> Array[int]:
	var out: Array[int] = []
	var seen_island_rows := {}
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		if p.get("mounted", false):
			continue
		if not PropCatalog.blocks_floor(p["key"]):
			continue
		var row: String = String(p.get("row", ""))
		if bool(p.get("free_standing", false)) and not row.is_empty():
			# All cases in an island row trial the same whole-row removal. Keep one
			# representative so duplicate trials cannot crowd required pieces out.
			if seen_island_rows.has(row):
				continue
			seen_island_rows[row] = true
		out.append(f)
	out.sort_custom(func(a: int, b: int) -> bool:
		var ra: Rect2 = plan.furniture[a]["rect"]
		var rb: Rect2 = plan.furniture[b]["rect"]
		return ra.size.x * ra.size.y > rb.size.x * rb.size.y)
	var picked: Array[int] = out.slice(0, MAX_TRIALS)
	if rep.is_empty():
		return picked
	# A failed floor-use zone names the actual piece. It must get a trial even
	# when it is hosted by a table and larger furniture filled the size cap.
	for unreachable in rep.get("unreachable_items", []):
		var target: int = int(unreachable)
		if target in out and target not in picked:
			picked.append(target)
	# The cap keeps the search cheap, but "biggest first" can fill all eight
	# slots with furniture from rooms nowhere near the trouble, leaving the
	# crate that stands in the only gap to a stranded room untried (thorpe
	# seed 1, 0.7: two crates in a pass-through store cut the kitchen off).
	# Pieces in rooms beside a stranded room, or holding an unreachable item,
	# always get their trial, after the ordinary candidates so ties break as
	# they always did.
	var near := _rooms_near_trouble(plan, rep)
	var extra := 0
	for f2 in out:
		if extra >= MAX_TRIALS or f2 in picked:
			continue
		if near.has(int(plan.furniture[f2]["room"])):
			picked.append(f2)
			extra += 1
	return picked


## Rooms that could be hiding what blocks the route: the neighbours of every
## stranded room, and the rooms of items nobody can reach.
static func _rooms_near_trouble(plan: HousePlan, rep: Dictionary) -> Dictionary:
	var rooms := {}
	var graph: Dictionary = plan.door_graph()
	for i in rep.get("unreached_rooms", []):
		for nb in graph.get(int(i), []):
			rooms[int(nb)] = true
	for f in rep.get("unreachable_items", []):
		rooms[int(plan.furniture[int(f)]["room"])] = true
	return rooms


## A copy of the plan with one piece taken out, for asking what would happen.
## Only the furniture differs, and the nav check reads nothing else that could
## be mutated, so the rooms and doors are shared rather than copied.
static func _without(plan: HousePlan, f: int) -> HousePlan:
	var trial := HousePlan.new()
	trial.spec = plan.spec
	trial.rooms = plan.rooms
	trial.doors = plan.doors
	trial.windows = plan.windows
	trial.stairs = plan.stairs
	trial.hearth = plan.hearth
	trial.furniture = plan.furniture.duplicate()
	# Whatever stands ON the piece goes with it, the way reindex_hosts() takes
	# it when the removal is real. Asking "would taking the table out help?"
	# with the bench still drawn up to it answers no every time, which is how a
	# parlour cut in half by a table and its bench survived every repair pass.
	var doomed := _repair_target_indices(plan, f)
	for target in doomed.duplicate():
		doomed.append_array(_hosted_by(plan, target))
	var unique_doomed: Array[int] = []
	for idx in doomed:
		if not idx in unique_doomed:
			unique_doomed.append(idx)
	doomed = unique_doomed
	doomed.sort()
	for k in range(doomed.size() - 1, -1, -1):
		trial.furniture.remove_at(doomed[k])
	return trial


## Navigation repair removes the intentional center bookcase row as one unit.
## Removing one case would leave a pitch gap and fail the strict row contract.
## Wall-backed runs keep their ordinary per-piece repair behavior.
static func _repair_target_indices(plan: HousePlan, f: int) -> Array[int]:
	var piece: Dictionary = plan.furniture[f]
	var row: String = String(piece.get("row", ""))
	if not bool(piece.get("free_standing", false)) or row.is_empty():
		return [f]
	var members: Array[int] = []
	for i in range(plan.furniture.size()):
		if int(plan.furniture[i]["room"]) == int(piece["room"]) \
				and String(plan.furniture[i].get("row", "")) == row:
			members.append(i)
	return members if not members.is_empty() else [f]


## Everything set on a piece, and everything set on those, by index.
static func _hosted_by(plan: HousePlan, f: int) -> Array[int]:
	var out: Array[int] = []
	var front: Array[int] = [f]
	while not front.is_empty():
		var cur: int = front.pop_back()
		for i in range(plan.furniture.size()):
			if int(plan.furniture[i]["host"]) != cur or i in out:
				continue
			out.append(i)
			front.append(i)
	return out


## Removing a placement shifts every index after it, and things set ON that
## placement point back at it by index. Anything that stood on the piece that
## just left goes with it.
static func reindex_hosts(plan: HousePlan, removed: int) -> void:
	var doomed: Array[int] = []
	for f in range(plan.furniture.size()):
		var host: int = plan.furniture[f]["host"]
		if host == removed:
			doomed.append(f)
		elif host > removed:
			plan.furniture[f]["host"] = host - 1
	for k in range(doomed.size() - 1, -1, -1):
		var idx: int = doomed[k]
		plan.furniture.remove_at(idx)
		reindex_hosts(plan, idx)


