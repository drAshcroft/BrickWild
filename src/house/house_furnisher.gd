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

## Recipes per room kind: a list of steps, each
##   {"cat": String, "rule": StringName, "n": [min, max], "opt": float}
##
## `opt` of 1.0 marks a piece the room is not that room without: it is placed
## without a dice roll, it is placed before everything else, and the passes
## that thin a room out to keep it walkable will not touch it. Everything else
## takes a roll and can be taken back out again -- which is why the barrels in
## a store are 0.9 and not 1.0: a store crowded to the point that you cannot
## reach the room beyond it should lose a barrel, not keep it.
## `cat` names a prop category from PropCatalog; the furnisher picks which
## actual prop fills it, so swapping the art pack does not rewrite the rules.
const RECIPES := {
	&"hall": [
		{"cat": "table", "rule": &"free", "n": [1, 1], "opt": 1.0},
		{"cat": "seat", "rule": &"around", "n": [2, 4], "opt": 1.0},
		{"cat": "storage", "rule": &"wall", "n": [1, 1], "opt": 0.8},
		{"cat": "chest", "rule": &"wall", "n": [0, 1], "opt": 0.5},
		{"cat": "shelf", "rule": &"mounted", "n": [1, 2], "opt": 0.7},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
		{"cat": "chandelier", "rule": &"ceiling", "n": [0, 1], "opt": 0.35},
		{"cat": "tableware", "rule": &"on", "n": [2, 4], "opt": 0.9},
		{"cat": "candle", "rule": &"on", "n": [1, 1], "opt": 0.8},
	],
	&"kitchen": [
		{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "storage", "rule": &"wall", "n": [1, 1], "opt": 0.9},
		{"cat": "barrel", "rule": &"corner", "n": [1, 2], "opt": 0.9},
		{"cat": "crate", "rule": &"corner", "n": [0, 2], "opt": 0.6},
		{"cat": "cookware", "rule": &"corner", "n": [1, 2], "opt": 0.8},
		{"cat": "shelf", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 1], "opt": 0.8},
		{"cat": "tableware", "rule": &"on", "n": [1, 3], "opt": 0.8},
	],
	&"bedroom": [
		{"cat": "bed", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "nightstand", "rule": &"wall", "n": [1, 1], "opt": 0.9},
		{"cat": "chest", "rule": &"wall", "n": [1, 1], "opt": 0.8},
		{"cat": "storage", "rule": &"wall", "n": [0, 1], "opt": 0.5},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 1], "opt": 0.7},
		{"cat": "candle", "rule": &"on", "n": [1, 1], "opt": 0.9},
		{"cat": "books", "rule": &"on", "n": [0, 1], "opt": 0.4},
	],
	&"store": [
		{"cat": "barrel", "rule": &"corner", "n": [1, 3], "opt": 0.9},
		{"cat": "crate", "rule": &"corner", "n": [1, 3], "opt": 0.9},
		{"cat": "chest", "rule": &"wall", "n": [0, 1], "opt": 0.5},
		{"cat": "shelf", "rule": &"mounted", "n": [1, 2], "opt": 0.8},
		{"cat": "sconce", "rule": &"mounted", "n": [0, 1], "opt": 0.5},
	],
	&"parlour": [
		{"cat": "table", "rule": &"free", "n": [1, 1], "opt": 1.0},
		{"cat": "bench", "rule": &"around", "n": [1, 2], "opt": 0.9},
		{"cat": "seat", "rule": &"around", "n": [1, 2], "opt": 0.7},
		{"cat": "bookcase", "rule": &"wall", "n": [0, 1], "opt": 0.6},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
		{"cat": "tableware", "rule": &"on", "n": [2, 4], "opt": 0.9},
		{"cat": "candle", "rule": &"on", "n": [1, 1], "opt": 0.9},
	],
	&"workshop": [
		{"cat": "workbench", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "crate", "rule": &"corner", "n": [1, 2], "opt": 0.8},
		{"cat": "shelf", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
		{"cat": "rack", "rule": &"mounted", "n": [0, 1], "opt": 0.6},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
		{"cat": "tool", "rule": &"on", "n": [1, 2], "opt": 0.8},
	],
	&"sales_floor": [
		{"cat": "counter", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "storage", "rule": &"wall", "n": [1, 1], "opt": 0.8},
		{"cat": "shelf", "rule": &"mounted", "n": [1, 3], "opt": 0.9},
		{"cat": "crate", "rule": &"corner", "n": [1, 2], "opt": 0.7},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
		{"cat": "trinket", "rule": &"on", "n": [1, 2], "opt": 0.7},
	],
	&"stable": [
		{"cat": "stall", "rule": &"free", "n": [1, 1], "opt": 1.0},
		{"cat": "barrel", "rule": &"corner", "n": [1, 2], "opt": 0.8},
		{"cat": "sack", "rule": &"corner", "n": [1, 2], "opt": 0.8},
		{"cat": "rack", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
	],
	&"tack_room": [
		{"cat": "storage", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "rack", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
		{"cat": "chest", "rule": &"wall", "n": [0, 1], "opt": 0.6},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 1], "opt": 0.8},
	],
	&"dining_room": [
		{"cat": "table", "rule": &"free", "n": [1, 1], "opt": 1.0},
		{"cat": "seat", "rule": &"around", "n": [2, 4], "opt": 1.0},
		{"cat": "bench", "rule": &"around", "n": [0, 1], "opt": 0.7},
		{"cat": "barrel", "rule": &"corner", "n": [1, 2], "opt": 0.7},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
		{"cat": "tableware", "rule": &"on", "n": [2, 4], "opt": 0.95},
	],
	&"guest_room": [
		{"cat": "bed", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "chest", "rule": &"wall", "n": [1, 1], "opt": 0.8},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 1], "opt": 0.8},
	],
	&"office": [
		{"cat": "workbench", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "seat", "rule": &"around", "n": [1, 1], "opt": 0.8},
		{"cat": "books", "rule": &"on", "n": [1, 2], "opt": 0.8},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 1], "opt": 0.9},
	],
	&"records": [
		{"cat": "bookcase", "rule": &"wall", "n": [1, 2], "opt": 1.0},
		{"cat": "lectern", "rule": &"free", "n": [0, 1], "opt": 0.7},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 1], "opt": 0.9},
	],
	&"council_chamber": [
		{"cat": "table", "rule": &"free", "n": [1, 1], "opt": 1.0},
		{"cat": "seat", "rule": &"around", "n": [3, 5], "opt": 1.0},
		{"cat": "banner", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
		{"cat": "sconce", "rule": &"mounted", "n": [2, 3], "opt": 0.9},
	],
	&"meeting_hall": [
		{"cat": "table", "rule": &"free", "n": [1, 1], "opt": 1.0},
		{"cat": "bench", "rule": &"around", "n": [2, 3], "opt": 1.0},
		{"cat": "banner", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
		{"cat": "sconce", "rule": &"mounted", "n": [2, 3], "opt": 0.9},
	],
	&"lobby": [
		{"cat": "counter", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "table", "rule": &"free", "n": [1, 1], "opt": 0.85},
		{"cat": "seat", "rule": &"around", "n": [2, 4], "opt": 0.9},
		{"cat": "bench", "rule": &"around", "n": [1, 2], "opt": 0.8},
		{"cat": "banner", "rule": &"mounted", "n": [1, 2], "opt": 0.95},
		{"cat": "chandelier", "rule": &"ceiling", "n": [1, 1], "opt": 1.0},
		{"cat": "trinket", "rule": &"on", "n": [1, 2], "opt": 0.8},
	],
	&"lounge": [
		{"cat": "table", "rule": &"free", "n": [1, 1], "opt": 1.0},
		{"cat": "seat", "rule": &"around", "n": [2, 4], "opt": 1.0},
		{"cat": "bookcase", "rule": &"wall", "n": [1, 2], "opt": 0.8},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.95},
		{"cat": "tableware", "rule": &"on", "n": [1, 3], "opt": 0.8},
	],
	&"suite": [
		{"cat": "bed", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "nightstand", "rule": &"wall", "n": [1, 1], "opt": 0.9},
		{"cat": "table", "rule": &"free", "n": [1, 1], "opt": 0.85},
		{"cat": "seat", "rule": &"around", "n": [1, 2], "opt": 0.9},
		{"cat": "chest", "rule": &"wall", "n": [1, 1], "opt": 0.8},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.95},
	],
	&"gallery": [
		{"cat": "bookcase", "rule": &"wall", "n": [1, 2], "opt": 0.8},
		{"cat": "banner", "rule": &"mounted", "n": [2, 3], "opt": 0.95},
		{"cat": "sconce", "rule": &"mounted", "n": [2, 3], "opt": 1.0},
		{"cat": "lectern", "rule": &"free", "n": [0, 1], "opt": 0.55},
	],
	&"laundry": [
		{"cat": "workbench", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "storage", "rule": &"wall", "n": [1, 1], "opt": 0.9},
		{"cat": "sack", "rule": &"corner", "n": [1, 2], "opt": 0.8},
		{"cat": "bucket", "rule": &"corner", "n": [1, 2], "opt": 0.8},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 1], "opt": 0.9},
	],
}

const SHOP_FITTINGS := {
	&"blacksmith": [{"cat": "anvil", "rule": &"free", "n": [1, 1], "opt": 1.0}],
	&"bakery": [{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0}],
	&"butcher": [{"cat": "blade", "rule": &"on", "n": [1, 2], "opt": 1.0}],
	&"apothecary": [{"cat": "alchemy", "rule": &"on", "n": [2, 4], "opt": 1.0}],
	&"tailor": [{"cat": "sack", "rule": &"corner", "n": [1, 2], "opt": 0.8}],
	&"carpenter": [{"cat": "rack", "rule": &"mounted", "n": [1, 1], "opt": 1.0}],
}

## What a trade adds to its workshop, on top of the generic bench and crates.
const TRADE_FITTINGS := {
	&"smith": [
		{"cat": "anvil", "rule": &"free", "n": [1, 1], "opt": 1.0},
		{"cat": "stand", "rule": &"wall", "n": [1, 1], "opt": 0.8},
		{"cat": "barrel", "rule": &"corner", "n": [1, 1], "opt": 0.7},
	],
	&"alchemist": [
		{"cat": "bookcase", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 0.8},
		{"cat": "alchemy", "rule": &"on", "n": [2, 4], "opt": 0.95},
		{"cat": "books", "rule": &"on", "n": [1, 2], "opt": 0.8},
	],
	&"farmer": [
		{"cat": "barrel", "rule": &"corner", "n": [1, 2], "opt": 0.95},
		{"cat": "crate", "rule": &"corner", "n": [1, 2], "opt": 0.95},
	],
	&"innkeeper": [
		{"cat": "barrel", "rule": &"corner", "n": [1, 2], "opt": 0.9},
		{"cat": "tableware", "rule": &"on", "n": [2, 3], "opt": 0.95},
	],
	&"scholar": [
		{"cat": "bookcase", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "lectern", "rule": &"free", "n": [0, 1], "opt": 0.7},
		{"cat": "books", "rule": &"on", "n": [1, 3], "opt": 0.95},
	],
}

## Pieces that must have a wall behind them, whatever the room looks like: a
## bed in the middle of the floor is not a bed that ran out of options, it is a
## mistake. Everything else may stand free if no wall will take it.
const WALL_ESSENTIAL := ["bed", "hearth", "bookcase", "nightstand", "chest"]

## Step along a wall when hunting for somewhere to put a piece.
const PROBE_STEP := 0.12
## How many pieces the repair pass may remove before it gives up and lets the
## checks report the house as it stands.
const MAX_REPAIRS := 8
## How many removals it tries per pass. The list is biggest-first, and the
## thing blocking a doorway is nearly always one of the big ones.
const MAX_TRIALS := 8
## Whether the piece being placed right now is one the room cannot do without.
## Carried on the placement so the repair pass knows what it may not remove.
static var _mandatory := false
## Sizes a shrinkable piece is tried at, biggest first: a smaller table is a
## compromise, not a preference.
const SCALE_STEPS := [1.0, 0.88, 0.76, 0.62]
## How much of a room a piece has to span before the gap left beside it counts
## as the only way past rather than as somewhere to step round.
const BAR_FRACTION := 0.55


static func furnish(plan: HousePlan, spec: HouseSpec) -> void:
	plan.furniture.clear()
	for i in range(plan.room_count()):
		_furnish_room(plan, spec, i)
	relax(plan)


## Vertical origin of a room. Older hand-authored plans have no `storey`, so
## they remain ordinary ground-floor plans.
static func _storey_base(plan: HousePlan, room: int) -> float:
	if room < 0 or room >= plan.rooms.size():
		return 0.0
	return float(HousePlan.record_storey(plan.rooms[room])) * plan.spec.height


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
## This version tries removing each candidate in turn and keeps whichever
## actually opens up the most floor, which needs no theory about where the
## blockage is.
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
		for f in _candidates(plan):
			var p: Dictionary = plan.furniture[f]
			var must: bool = p.get("must", false)
			var trial: HousePlan = _without(plan, f)
			var after: Dictionary = HouseNavCheck.new().check(trial)
			var gain: int = int(after["stats"].get("reached_cells", 0)) - base
			if bool(after["ok"]):
				gain += 10000        # the whole point: it fixes the house
			if gain <= 0:
				continue
			# an optional piece is always preferred to a necessary one, however
			# much floor the necessary one would free
			if best < 0 or (best_must and not must) \
					or (best_must == must and gain > best_gain):
				best = f
				best_gain = gain
				best_must = must
		if best < 0:
			# A plateau: no single removal opens anything up, because two
			# pieces are blocking the same route between them. Take out the
			# biggest optional thing near the trouble anyway and look again --
			# without this the search stops one move short of the answer.
			best = _biggest_near(plan, before)
			if best < 0:
				break
		if plan.furniture[best].get("must", false):
			plan.note_compromise(int(plan.furniture[best]["room"]),
				String(plan.furniture[best]["cat"]))
		plan.furniture.remove_at(best)
		_reindex_hosts(plan, best)
		removed += 1
	return removed


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


## The pieces worth trying to remove: the ones standing on the floor, biggest
## first, capped so the search stays cheap on a large house.
static func _candidates(plan: HousePlan) -> Array[int]:
	var out: Array[int] = []
	for f in range(plan.furniture.size()):
		var p: Dictionary = plan.furniture[f]
		if p.get("mounted", false) or p["host"] >= 0:
			continue
		if not PropCatalog.blocks_floor(p["key"]):
			continue
		out.append(f)
	out.sort_custom(func(a: int, b: int) -> bool:
		var ra: Rect2 = plan.furniture[a]["rect"]
		var rb: Rect2 = plan.furniture[b]["rect"]
		return ra.size.x * ra.size.y > rb.size.x * rb.size.y)
	return out.slice(0, MAX_TRIALS)


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
	trial.furniture = plan.furniture.duplicate()
	trial.furniture.remove_at(f)
	return trial


## Removing a placement shifts every index after it, and things set ON that
## placement point back at it by index. Anything that stood on the piece that
## just left goes with it.
static func _reindex_hosts(plan: HousePlan, removed: int) -> void:
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
		_reindex_hosts(plan, idx)


static func _furnish_room(plan: HousePlan, spec: HouseSpec, room: int) -> void:
	var kind: StringName = plan.kind_of(room)
	var steps: Array = []
	# A house with no room big enough to be a bedroom sleeps in its hall, which
	# is what a one-room cottage has always done. The bed goes in first, before
	# the table has taken the good wall.
	var sleeps_here: bool = not spec is ShopSpec and kind == &"hall" \
		and not plan.has_kind(&"bedroom")
	if sleeps_here:
		steps.append({"cat": "bed", "rule": &"wall", "n": [1, 1], "opt": 1.0})
		steps.append({"cat": "chest", "rule": &"wall", "n": [1, 1], "opt": 0.9})
	for s in RECIPES.get(kind, []):
		# With a bed in it the hall has no middle left to stand a table in, so
		# the table goes against a wall -- which is what a one-room cottage
		# does anyway.
		if sleeps_here and String(s["cat"]) == "table":
			var wall_table: Dictionary = s.duplicate()
			wall_table["rule"] = &"wall"
			steps.append(wall_table)
			continue
		steps.append(s)

	# the trade fits out whichever room it works in, after that room's own
	# recipe has had its say
	var trade_room: StringName = HouseSpec.TRADES[spec.trade]["room"] \
		if not spec is ShopSpec else (spec as ShopSpec).front_room()
	var fittings: Array = TRADE_FITTINGS.get(spec.trade, []) if not spec is ShopSpec \
		else SHOP_FITTINGS.get((spec as ShopSpec).business, [])
	if trade_room == kind:
		for s2 in fittings:
			steps.append(s2)

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

	var blocked: Array[Rect2] = _initial_blocked(plan, room)
	# Use zones are tracked apart from footprints. Two people may share a
	# gangway, so zones may overlap each other -- but nothing solid may stand
	# in one, or the piece it belongs to becomes unusable. Leaving zones out of
	# the occupancy entirely is what let a chest be set down in the only gap
	# beside a bed.
	var zones: Array[Rect2] = []
	var r: RandomNumberGenerator = spec.rng
	for step in steps:
		# opt 1.0 means the room is not that room without it. Anything less is a
		# dressing roll, nudged by how cluttered the household is. Rolling for
		# the mandatory pieces too is how a bedroom came out with no bed in it
		# five per cent of the time.
		var must: bool = float(step["opt"]) >= 1.0
		if not must and r.randf() > float(step["opt"]) * lerpf(0.75, 1.15, spec.clutter):
			continue
		_mandatory = must
		var lo: int = int(step["n"][0])
		var hi: int = int(step["n"][1])
		var want: int = lo if hi <= lo else r.randi_range(lo, hi)
		var seats_before: int = _count_cat(plan, room, ["seat", "bench"])
		for k in range(want):
			_place_one(plan, spec, room, String(step["cat"]), step["rule"], blocked, zones, r)
		# A table nobody can sit at is worse than no table: it takes the middle
		# of the room and gives nothing back. If not one seat would go round it,
		# the table goes instead, and the plan records why.
		if step["rule"] == &"around" and _count_cat(plan, room, ["seat", "bench"]) \
				== seats_before and _count_cat(plan, room, ["table"]) > 0:
			_drop_the_table(plan, room, blocked, zones)
	_ensure_seating(plan, room, blocked, zones, r)
	_ensure_light(plan, room, r)
	_keep_the_room_passable(plan, room, blocked, zones)


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
		blocked.erase(plan.furniture[victim]["rect"])
		zones.erase(plan.furniture[victim]["zone"])
		plan.furniture.remove_at(victim)
		_reindex_hosts(plan, victim)


## A table with nothing to sit at it is a table nobody uses.
##
## The seating steps are rolls like any other, and a room can lose all of them
## to chance or to a tight corner. So the room is checked once at the end: if
## there is a table and no seat, one more seat is attempted, and if even that
## will not go in, the table comes out and the plan says so.
static func _ensure_seating(plan: HousePlan, room: int, blocked: Array[Rect2],
		zones: Array[Rect2], r: RandomNumberGenerator) -> void:
	if _count_cat(plan, room, ["table"]) == 0:
		return
	if _count_cat(plan, room, ["seat", "bench"]) > 0:
		return
	for cat in ["seat", "bench"]:
		for key in PropCatalog.of_category(cat):
			_place_around(plan, room, key, blocked, zones, r)
			if _count_cat(plan, room, ["seat", "bench"]) > 0:
				return
	_drop_the_table(plan, room, blocked, zones)


## Is there already something in this room that the room could not do without?
static func _has_other_must(plan: HousePlan, room: int) -> bool:
	for f in plan.furniture_of(room):
		if plan.furniture[f].get("must", false):
			return true
	return false


static func _count_cat(plan: HousePlan, room: int, cats: Array) -> int:
	var n := 0
	for f in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[f]["key"]) in cats:
			n += 1
	return n


## Take the table back out, and free the floor it was holding.
static func _drop_the_table(plan: HousePlan, room: int, blocked: Array[Rect2],
		zones: Array[Rect2]) -> void:
	for f in range(plan.furniture.size() - 1, -1, -1):
		var p: Dictionary = plan.furniture[f]
		if int(p["room"]) != room or PropCatalog.category(p["key"]) != "table":
			continue
		blocked.erase(p["rect"])
		plan.note_compromise(room, "table")
		plan.furniture.remove_at(f)
		_reindex_hosts(plan, f)
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
			_place_on_surface(plan, room, key, r)
		else:
			_place_mounted(plan, room, key, r)
		if plan.furniture.size() > before:
			return


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
	probe.furniture = []
	var r := RandomNumberGenerator.new()
	r.seed = 1
	var blocked: Array[Rect2] = _initial_blocked(probe, room)
	var zones: Array[Rect2] = []
	for key in choices:
		var before: int = probe.furniture.size()
		for rule in [&"wall", &"free", &"corner"]:
			match rule:
				&"wall":
					_place_against_wall(probe, room, key, blocked, zones, r)
				&"free":
					_place_free(probe, room, key, blocked, zones, r)
				&"corner":
					_place_corner(probe, room, key, blocked, zones, r)
			if probe.furniture.size() > before:
				return true
	return false


## The floor that is spoken for before any furniture arrives: the swing of
## every door into this room, and a strip in front of every window.
static func _initial_blocked(plan: HousePlan, room: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
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
static func _window_blocks(plan: HousePlan, room: int, key: String) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if PropCatalog.height(key) <= HouseGeometry.WINDOW_SILL:
		return out
	for w in plan.windows_of(room):
		out.append(HouseGeometry.window_clear_rect(plan.windows[w]))
	return out


static func _place_one(plan: HousePlan, spec: HouseSpec, room: int, cat: String,
		rule: StringName, blocked: Array[Rect2], zones: Array[Rect2],
		r: RandomNumberGenerator) -> void:
	var choices: Array[String] = PropCatalog.of_category(cat)
	if choices.is_empty():
		return
	var key: String = choices[r.randi_range(0, choices.size() - 1)]
	var before_place: int = plan.furniture.size()
	match rule:
		&"wall":
			var had: int = plan.furniture.size()
			_place_against_wall(plan, room, key, blocked, zones, r)
			if plan.furniture.size() == had and not cat in WALL_ESSENTIAL:
				# no wall will take it. A workbench can stand out in the room --
				# a bed cannot, which is what WALL_ESSENTIAL is for -- and the
				# placement records that it did, so the check that wants a wall
				# behind it knows why there is none.
				_place_free(plan, room, key, blocked, zones, r)
				if plan.furniture.size() > had:
					plan.furniture[-1]["free_standing"] = true
		&"free":
			var before: int = plan.furniture.size()
			_place_free(plan, room, key, blocked, zones, r)
			if plan.furniture.size() == before:
				# no room to stand it clear of the walls; against one is better
				# than not at all, and is what a small cottage does
				_place_against_wall(plan, room, key, blocked, zones, r)
		&"corner":
			_place_corner(plan, room, key, blocked, zones, r)
		&"around":
			_place_around(plan, room, key, blocked, zones, r)
		&"mounted":
			_place_mounted(plan, room, key, r)
		&"ceiling":
			_place_ceiling(plan, room, key)
		&"on":
			_place_on_surface(plan, room, key, r)
	# A room that could not fit something it needed, because it was already
	# holding the other things it needed, has made a compromise rather than a
	# mistake -- and it is only a compromise if there WAS something else. A bed
	# missing from an empty bedroom is still a defect, and still fails.
	if _mandatory and plan.furniture.size() == before_place 			and _has_other_must(plan, room):
		plan.note_compromise(room, cat)


# ------------------------------------------------------------ floor pieces

## Back to a wall, sliding along it until somewhere fits.
static func _place_against_wall(plan: HousePlan, room: int, key: String,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator) -> void:
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
	var best: Dictionary = {}
	var best_score := -INF
	var extra: Array[Rect2] = _window_blocks(plan, room, key)
	for wi in range(walls.size()):
		var wall: Dictionary = walls[wi]
		var n: Vector2 = wall["normal"]
		var yaw: float = _yaw_facing(n)
		var foot: Vector2 = PropCatalog.footprint_yawed(key, yaw)
		var along := Vector2(n.y, -n.x).abs()      # unit vector along the wall
		# Which component of the footprint runs ALONG the wall and which runs
		# INTO it depends on the yaw. Reading them the wrong way round is what
		# stood a shallow cabinet half a metre off the wall it was backed to.
		var span: float = along.x * foot.x + along.y * foot.y
		var depth: float = absf(n.x) * foot.x + absf(n.y) * foot.y
		var a: Vector2 = wall["from"]
		var b: Vector2 = wall["to"]
		var run: float = (b - a).length()
		var small: float = span * PropCatalog.min_scale(key)
		if run < small + 0.1:
			continue
		var steps: int = maxi(int((run - small) / PROBE_STEP), 1)
		for s in range(steps + 1):
			var t: float = (small / 2.0) + float(s) * (run - small) / float(steps)
			var centre: Vector2 = a + along * t + n * (depth / 2.0 + HouseGeometry.WALL_GAP)
			# a bed can be got into from either side, so try both before
			# deciding this stretch of wall will not do
			var cand := {}
			for sc in _scales(key):
				for zs in [1.0, -1.0]:
					var try_cand: Dictionary = _candidate(key, centre, yaw, zs, sc)
					if _fits(try_cand, floor_rect, blocked, zones, extra):
						cand = try_cand
						break
				if not cand.is_empty():
					break
			if cand.is_empty():
				continue
			var mid: float = 1.0 - absf(t - run / 2.0) / maxf(run / 2.0, 0.01)
			var score: float = mid * 0.6 + r.randf() * 0.5 + float(wi) * 0.01
			if PropCatalog.category(key) == "bed":
				score += _bed_bonus(plan, room, cand)
			if score > best_score:
				best_score = score
				best = cand
	_commit(plan, room, best, blocked, zones)


## Feng shui, and common sense: you want to see the door from the bed, but you
## do not want the bed in the doorway. The commanding position is out of the
## line of the door, with the headboard against solid wall -- which is also
## simply where a bed is out of the way.
static func _bed_bonus(plan: HousePlan, room: int, cand: Dictionary) -> float:
	var bonus := 0.0
	for d in plan.doors_of(room):
		var door: Dictionary = plan.doors[d]
		var dp: Vector2 = door["pos"]
		var dn: Vector2 = door["normal"]
		var rect: Rect2 = cand["rect"]
		var c: Vector2 = rect.get_center()
		# in the line of the door: the bed sits in the swim of everything
		# coming through it
		var along: float = absf((c - dp).dot(dn))
		var across: float = absf((c - dp).dot(Vector2(dn.y, -dn.x)))
		if across < (float(door["width"]) + rect.size.x) / 2.0:
			bonus -= 1.5
		else:
			bonus += 0.4
		bonus += clampf(along / 4.0, 0.0, 0.5)
	return bonus


## Room in the middle of the floor, for a table or an anvil.
static func _place_free(plan: HousePlan, room: int, key: String,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator) -> void:
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var extra: Array[Rect2] = _window_blocks(plan, room, key)
	var result := {"best": {}, "score": -INF}
	for yaw in [0.0, PI / 2.0]:
		for sc in _scales(key):
			_free_at_scale(plan, room, key, yaw, sc, floor_rect, blocked, zones,
				extra, r, result)
	_commit(plan, room, result["best"], blocked, zones)


## One pass of the free-standing search at a single size. Split out only
## because trying four sizes at two yaws over a grid is four levels of loop,
## and nesting them all in one function made the body unreadable.
static func _free_at_scale(plan: HousePlan, room: int, key: String, yaw: float,
		sc: float, floor_rect: Rect2, blocked: Array[Rect2], zones: Array[Rect2],
		extra: Array[Rect2], r: RandomNumberGenerator, result: Dictionary) -> void:
	var foot: Vector2 = PropCatalog.footprint_yawed(key, yaw) * sc
	var pad: float = HouseGeometry.PATH_MIN * 0.5
	var lo := Vector2(floor_rect.position.x + foot.x / 2.0 + pad,
		floor_rect.position.y + foot.y / 2.0 + pad)
	var hi := Vector2(floor_rect.end.x - foot.x / 2.0 - pad,
		floor_rect.end.y - foot.y / 2.0 - pad)
	if lo.x > hi.x or lo.y > hi.y:
		return
	var nx: int = maxi(int((hi.x - lo.x) / PROBE_STEP), 1)
	var nz: int = maxi(int((hi.y - lo.y) / PROBE_STEP), 1)
	for ix in range(nx + 1):
		for iz in range(nz + 1):
			var centre := Vector2(lerpf(lo.x, hi.x, float(ix) / nx),
				lerpf(lo.y, hi.y, float(iz) / nz))
			var cand: Dictionary = _candidate(key, centre, yaw, 1.0, sc)
			if not _fits(cand, floor_rect, blocked, zones, extra):
				continue
			# the middle of the room, at the biggest size that fits there
			var d: float = centre.distance_to(floor_rect.get_center())
			var score: float = -d + r.randf() * 0.35 + sc * 4.0
			if score > float(result["score"]):
				result["score"] = score
				result["best"] = cand


## Tucked into whichever corner is emptiest.
static func _place_corner(plan: HousePlan, room: int, key: String,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator) -> void:
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var foot: Vector2 = PropCatalog.footprint(key)
	var g: float = HouseGeometry.WALL_GAP
	var corners := [
		Vector2(floor_rect.position.x + foot.x / 2.0 + g, floor_rect.position.y + foot.y / 2.0 + g),
		Vector2(floor_rect.end.x - foot.x / 2.0 - g, floor_rect.position.y + foot.y / 2.0 + g),
		Vector2(floor_rect.position.x + foot.x / 2.0 + g, floor_rect.end.y - foot.y / 2.0 - g),
		Vector2(floor_rect.end.x - foot.x / 2.0 - g, floor_rect.end.y - foot.y / 2.0 - g),
	]
	for ci in _shuffled([0, 1, 2, 3], r):
		# slide out of the corner along both walls until it fits
		for slide in range(6):
			for dir in [Vector2(1, 0), Vector2(0, 1)]:
				var sign_x: float = 1.0 if ci == 0 or ci == 2 else -1.0
				var sign_z: float = 1.0 if ci == 0 or ci == 1 else -1.0
				var off := Vector2(dir.x * sign_x, dir.y * sign_z) * (float(slide) * 0.25)
				var cand: Dictionary = _candidate(key, corners[ci] + off, 0.0)
				if _fits(cand, floor_rect, blocked, zones,
						_window_blocks(plan, room, key)):
					_commit(plan, room, cand, blocked, zones)
					return


## Seats at a table, facing it, with pull-back space behind them.
static func _place_around(plan: HousePlan, room: int, key: String,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator) -> void:
	var host: int = _find_host(plan, room, ["table", "workbench", "counter"])
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
			var yaw: float = _yaw_facing(-n)        # face back toward the table
			var foot: Vector2 = PropCatalog.footprint_yawed(key, yaw)
			var half: Vector2 = host_rect.size / 2.0
			var out: float = absf(n.x) * half.x + absf(n.y) * half.y + foot.y / 2.0 + 0.04
			if tucked:
				# under the table, the way a stool lives. Only as far as its own
				# front edge: pushed further it passes the middle of the table
				# and ends up facing away from it. The pull-back space behind it
				# is still required either way -- a seat you cannot get out of
				# is not a seat, and the walking check would say so.
				out -= foot.y * 0.4
			var along := Vector2(n.y, -n.x)
			var run: float = absf(along.x) * host_rect.size.x \
				+ absf(along.y) * host_rect.size.y
			var steps: int = maxi(int(run / 0.45), 1)
			for s in range(steps + 1):
				var t: float = lerpf(-run / 2.0 + foot.x / 2.0, run / 2.0 - foot.x / 2.0,
					float(s) / float(steps))
				var centre: Vector2 = hc + n * out + along * t
				var cand: Dictionary = _candidate(key, centre, yaw)
				if not _fits(cand, floor_rect, blocked, zones, [],
						host_rect if tucked else Rect2()):
					continue
				var score: float = r.randf() - absf(t) * 0.2
				if score > best_score:
					best_score = score
					best = cand
	if not best.is_empty():
		best["host"] = host
	_commit(plan, room, best, blocked, zones)


static func _find_host(plan: HousePlan, room: int, cats: Array) -> int:
	for f in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[f]["key"]) in cats:
			return f
	return -1


# ---------------------------------------------------- wall and ceiling kit

## A shelf, rack or sconce on a wall, above the furniture already there.
static func _place_mounted(plan: HousePlan, room: int, key: String,
		r: RandomNumberGenerator) -> void:
	var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
	var y: float = HouseGeometry.SCONCE_HEIGHT if PropCatalog.category(key) == "sconce" \
		else HouseGeometry.SHELF_HEIGHT
	for wi in _shuffled([0, 1, 2, 3], r):
		var wall: Dictionary = walls[wi]
		var n: Vector2 = wall["normal"]
		var a: Vector2 = wall["from"]
		var b: Vector2 = wall["to"]
		var run: float = (b - a).length()
		var along: Vector2 = (b - a) / maxf(run, 0.01)
		var width: float = PropCatalog.size(key).x
		if run < width + 0.4:
			continue
		for tries in range(6):
			var t: float = lerpf(width / 2.0 + 0.2, run - width / 2.0 - 0.2, r.randf())
			var pos: Vector2 = a + along * t
			if _on_opening(plan, room, pos, n, width):
				continue
			var yaw: float = _yaw_facing(n)
			plan.furniture.append({
				"key": key, "room": room, "storey": HousePlan.record_storey(plan.rooms[room]),
				"pos": Vector3(pos.x, _storey_base(plan, room) + y, pos.y), "yaw": yaw,
				"rect": Rect2(pos - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
				"zone": Rect2(), "host": -1, "cat": PropCatalog.category(key),
				"mounted": true, "scale": 1.0,
			})
			return


## Is this stretch of wall taken up by a door or a window?
static func _on_opening(plan: HousePlan, room: int, pos: Vector2, normal: Vector2,
		width: float) -> bool:
	for d in plan.doors_of(room):
		var door: Dictionary = plan.doors[d]
		if door["pos"].distance_to(pos) < (float(door["width"]) + width) / 2.0 + 0.15:
			return true
	for w in plan.windows_of(room):
		var win: Dictionary = plan.windows[w]
		if win["pos"].distance_to(pos) < (float(win["width"]) + width) / 2.0 + 0.15:
			return true
	return false


static func _place_ceiling(plan: HousePlan, room: int, key: String) -> void:
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	if minf(floor_rect.size.x, floor_rect.size.y) < 2.6:
		return                                   # no room to hang anything
	var c: Vector2 = floor_rect.get_center()
	plan.furniture.append({
		"key": key, "room": room, "storey": HousePlan.record_storey(plan.rooms[room]),
		"pos": Vector3(c.x, _storey_base(plan, room) + plan.spec.height, c.y),
		"yaw": 0.0, "rect": Rect2(c - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
		"zone": Rect2(), "host": -1, "cat": PropCatalog.category(key),
		"mounted": true, "scale": 1.0,
	})


## A mug, a candle, a stack of books -- set ON something, never on the floor.
static func _place_on_surface(plan: HousePlan, room: int, key: String,
		r: RandomNumberGenerator) -> void:
	var hosts: Array[int] = []
	for f in plan.furniture_of(room):
		var host_key: String = plan.furniture[f]["key"]
		if PropCatalog.has_tag(host_key, PropCatalog.SURFACE) \
				and not plan.furniture[f].get("mounted", false):
			hosts.append(f)
	if hosts.is_empty():
		return
	var host: int = hosts[r.randi_range(0, hosts.size() - 1)]
	var host_rect: Rect2 = plan.furniture[host]["rect"]
	var top: float = float(plan.furniture[host]["pos"].y) \
		+ PropCatalog.surface_height(plan.furniture[host]["key"]) \
		* float(plan.furniture[host].get("scale", 1.0))
	var foot: Vector2 = PropCatalog.footprint(key)
	var margin := 0.06
	var lo := Vector2(host_rect.position.x + foot.x / 2.0 + margin,
		host_rect.position.y + foot.y / 2.0 + margin)
	var hi := Vector2(host_rect.end.x - foot.x / 2.0 - margin,
		host_rect.end.y - foot.y / 2.0 - margin)
	if lo.x > hi.x or lo.y > hi.y:
		return
	for tries in range(10):
		var p := Vector2(lerpf(lo.x, hi.x, r.randf()), lerpf(lo.y, hi.y, r.randf()))
		var rect := Rect2(p - foot / 2.0, foot)
		var clash := false
		for f2 in plan.furniture_of(room):
			if plan.furniture[f2]["host"] != host:
				continue
			if plan.furniture[f2]["rect"].intersects(rect):
				clash = true
				break
		if clash:
			continue
		plan.furniture.append({
			"key": key, "room": room, "storey": HousePlan.record_storey(plan.rooms[room]),
			"pos": Vector3(p.x, top, p.y),
			"yaw": r.randf() * TAU, "rect": rect, "zone": Rect2(), "host": host,
			"cat": PropCatalog.category(key), "mounted": false, "scale": 1.0,
		})
		return


# ------------------------------------------------------------- mechanics

## A placement, before it is known whether it fits.
static func _candidate(key: String, centre: Vector2, yaw: float,
		zone_side := 1.0, scale := 1.0) -> Dictionary:
	var foot: Vector2 = PropCatalog.footprint_yawed(key, yaw) * scale
	var rect := Rect2(centre - foot / 2.0, foot)
	return {
		"key": key, "pos": Vector3(centre.x, 0.0, centre.y), "yaw": yaw,
		"rect": rect, "zone": _zone_rect(key, rect, yaw, zone_side), "host": -1,
		"cat": PropCatalog.category(key), "mounted": false, "scale": scale,
	}


## The floor a person needs to USE the piece.
##
## Which side that is depends on the piece: you stand in front of a cabinet,
## you push a chair BACK from the table to sit down, and you get into a bed
## from its long side. Getting this wrong is not a cosmetic matter -- the
## navigation check requires every one of these to be reachable, so a zone on
## the wrong side of a chair reports the whole room as unusable.
static func _zone_rect(key: String, rect: Rect2, yaw: float, side := 1.0) -> Rect2:
	var depth: float = PropCatalog.zone_depth(key)
	if depth <= 0.0:
		return Rect2()
	var cat: String = PropCatalog.category(key)
	var facing: Vector2 = _facing_of(yaw)
	var dir: Vector2 = facing
	if cat == "seat" or cat == "bench":
		dir = -facing                      # pull-back space, behind the seat
	elif cat == "bed":
		dir = Vector2(facing.y, -facing.x) * side  # you get in from the side
	var c: Vector2 = rect.get_center()
	var half: Vector2 = rect.size / 2.0
	var out: float = absf(dir.x) * half.x + absf(dir.y) * half.y
	var across := Vector2(dir.y, -dir.x).abs()
	var span: Vector2 = across * (across.x * rect.size.x + across.y * rect.size.y) / 2.0
	var a: Vector2 = c + dir * out - span
	var b: Vector2 = c + dir * (out + depth) + span
	return Rect2(a.min(b), (b - a).abs())


## Does this candidate fit: inside the room, clear of everything already
## placed, and with its use zone on real floor rather than inside a wall?
static func _fits(cand: Dictionary, floor_rect: Rect2, blocked: Array[Rect2],
		zones: Array[Rect2], extra: Array[Rect2], ignore := Rect2()) -> bool:
	var rect: Rect2 = cand["rect"]
	if not floor_rect.grow(0.01).encloses(rect):
		return false
	for b in blocked:
		# a seat tucked under its own table overlaps it on purpose, so the
		# table is passed in as the one rectangle this placement may share
		if ignore.size.x > 0.0 and b.is_equal_approx(ignore):
			continue
		if b.intersects(rect):
			return false
	for z in zones:
		if z.intersects(rect):
			return false
	for e in extra:
		if e.intersects(rect):
			return false
	if not _no_slivers(rect, floor_rect):
		return false
	var zone: Rect2 = cand["zone"]
	if zone.size.x > 0.0:
		# the zone may overlap another zone -- two people can share a gangway --
		# but it may not be inside a wall or under other furniture
		if not floor_rect.grow(0.02).encloses(zone):
			return false
		for b2 in blocked:
			if b2.intersects(zone):
				return false
	return true


static func _commit(plan: HousePlan, room: int, cand: Dictionary,
		blocked: Array[Rect2], zones: Array[Rect2]) -> void:
	if cand.is_empty():
		return
	cand["room"] = room
	cand["storey"] = HousePlan.record_storey(plan.rooms[room])
	var pos: Vector3 = cand["pos"]
	# Candidates are planar (Y=0) while searching. Stamp world elevation only
	# after the placement is accepted, keeping all rectangle logic 2D.
	pos.y += _storey_base(plan, room)
	cand["pos"] = pos
	cand["must"] = _mandatory
	plan.furniture.append(cand)
	blocked.append(cand["rect"])
	var zone: Rect2 = cand["zone"]
	if zone.size.x > 0.0:
		zones.append(zone)


## The sizes this piece may be built at, largest first.
static func _scales(key: String) -> Array:
	var floor_scale: float = PropCatalog.min_scale(key)
	if floor_scale >= 1.0:
		return [1.0]
	var out: Array = []
	for s in SCALE_STEPS:
		if float(s) >= floor_scale - 0.001:
			out.append(float(s))
	return out


## A deterministic shuffle: Array.shuffle() draws on the global RNG, which
## would make the same seed furnish differently from one run to the next.
static func _shuffled(items: Array, r: RandomNumberGenerator) -> Array:
	var out: Array = items.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j: int = r.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## No dead slivers.
##
## The gap between a piece and each wall must be either nothing -- the piece is
## against that wall -- or wide enough to walk down. A table left 38 cm from the
## wall behind it is what cut one test house in half: the room stayed walkable
## on paper and a person could not get past.
static func _no_slivers(rect: Rect2, floor_rect: Rect2) -> bool:
	# A gap beside a stool is a gap you step round. It only becomes a dead
	# sliver when the piece is long enough to bar the room across the other
	# axis, so that the sliver is the only way past.
	var bars_x: bool = rect.size.y > floor_rect.size.y * BAR_FRACTION
	var bars_z: bool = rect.size.x > floor_rect.size.x * BAR_FRACTION
	var gaps := []
	if bars_x:
		gaps.append(rect.position.x - floor_rect.position.x)
		gaps.append(floor_rect.end.x - rect.end.x)
	if bars_z:
		gaps.append(rect.position.y - floor_rect.position.y)
		gaps.append(floor_rect.end.y - rect.end.y)
	for g in gaps:
		var gap: float = float(g)
		if gap > HouseGeometry.WALL_GAP + 0.06 and gap < HouseGeometry.PATH_MIN:
			return false
	return true


## Yaw that turns a prop's face (local -Z) toward `n`.
static func _yaw_facing(n: Vector2) -> float:
	return atan2(-n.x, -n.y)


static func _facing_of(yaw: float) -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))
