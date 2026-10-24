class_name HouseFurnishingRecipes
extends RefCounted
## Room, shop and trade recipes consumed by HouseFurnisher.

const BASE_HOUSE_SPEC := preload("house_spec.gd")
const DOMESTIC_TABLE_MIN_HEIGHT := 0.70
const DOMESTIC_PREP_MIN_HEIGHT := 0.75
const TOWNHOUSE_WRITING_SURFACE_HEIGHT_SCALE := 0.85

## Keep the seated worktop, chair and records together as one measured activity.
const TOWNHOUSE_OFFICE_ACTIVITY := [
	{"cat": "workbench", "key": "Workbench", "rule": &"wall", "n": [1, 1], "opt": 1.0, "height_scale": TOWNHOUSE_WRITING_SURFACE_HEIGHT_SCALE, "group": "writing"},
	{"cat": "seat", "key": "Chair_1", "rule": &"around", "n": [1, 1], "opt": 1.0, "group": "writing", "preferred_sides": ["long_edge"]},
	{"cat": "books", "key": "Book_5", "rule": &"on", "host_category": "workbench", "n": [1, 1], "opt": 1.0, "group": "writing"},
	{"cat": "books", "key": "Scroll_1", "rule": &"on", "host_category": "workbench", "n": [1, 1], "opt": 1.0, "group": "writing"},
	{"cat": "bookcase", "key": "Bookcase_2", "rule": &"wall", "n": [1, 1], "opt": 1.0, "group": "writing"},
	{"cat": "books", "key": "BookGroup_Small_1", "rule": &"on", "host_category": "bookcase", "n": [3, 3], "opt": 1.0, "group": "writing"},
	{"cat": "sconce", "rule": &"mounted", "n": [1, 1], "opt": 0.9},
]

## A commercial kitchen (restaurant, tavern, inn, bakery) is a line, not a
## pantry: the fire, a prep bench with plates on it, the larder, and a lamp pair over the work. The generic kitchen
## recipe leaves the bench to a dice roll and one sconce, which is how a 38 m2
## cookshop kitchen came out 7% furnished with a fire and nowhere to chop.
const SHOP_KITCHEN := [
	{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0},
	{"cat": "workbench", "rule": &"wall", "n": [1, 1], "opt": 1.0, "height_scale": 1.0},
	{"cat": "storage", "rule": &"wall", "n": [1, 1], "opt": 1.0},
	{"cat": "workbench", "rule": &"wall", "n": [1, 1], "opt": 0.9, "height_scale": 1.0},
	{"cat": "barrel", "rule": &"corner", "n": [1, 2], "opt": 0.9},
	{"cat": "crate", "rule": &"corner", "n": [1, 1], "opt": 0.8},
	{"cat": "shelf", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
	{"cat": "sconce", "rule": &"mounted", "n": [2, 2], "opt": 1.0},
	{"cat": "cookware", "rule": &"corner", "n": [1, 1], "opt": 0.9},
	{"cat": "tableware", "rule": &"on", "host_category": "workbench", "n": [1, 2], "opt": 1.0},
]

## What a shop's public and working rooms hold once they are big. The base
## recipes were written for a cottage-sized room: a 50 m2 sales floor furnished
## from one counter, one cabinet and two crates is 6% stocked, which reads as an
## empty hall with a label. Each candidate is {cat, rule, fp (footprint m2),
## max}; `shop_composition_steps` takes them in order, round and round, until
## the room's share of floor is met. Bulk goods (barrels, crates, sacks) go in
## corners, which are never a door approach; tables and cabinets stand on a wall
## so the middle of the floor stays the customer's.
const SHOP_FLOOR_SHARE := 0.13
## A counting-house or clerk's office is also furnished by an AMPLE overlay whose
## table and chairs are thinned by the walk; its share is asked for more firmly.
const SHOP_SHARE_BY_KIND := {&"office": 0.18}
const SHOP_COMPOSITION_MIN_AREA := 20.0
const SHOP_COMPOSITION_MAX_PIECES := 22
const SHOP_COMPOSITION := {
	&"sales_floor": {
		# a bread table and the flour, the proving bins in the corners
		&"bakery": [
			{"cat": "counter", "rule": &"wall", "fp": 1.72, "max": 4},
			{"cat": "barrel", "rule": &"corner", "fp": 0.49, "max": 2},
			{"cat": "storage", "rule": &"wall", "fp": 0.49, "max": 1},
			{"cat": "crate", "rule": &"corner", "fp": 0.76, "max": 2},
			{"cat": "shelf", "rule": &"mounted", "fp": 0.0, "per_area": 12.0, "max": 4},
		],
		# a cutting table with a block beside it, hanging rails above
		&"butcher": [
			{"cat": "counter", "rule": &"wall", "fp": 1.72, "max": 4},
			{"cat": "barrel", "rule": &"corner", "fp": 0.49, "max": 2},
			{"cat": "storage", "rule": &"wall", "fp": 0.49, "max": 1},
			{"cat": "crate", "rule": &"corner", "fp": 0.76, "max": 2},
			{"cat": "shelf", "rule": &"mounted", "fp": 0.0, "per_area": 12.0, "max": 4},
		],
		# cases of remedies: cabinets and a book of receipts
		&"apothecary": [
			{"cat": "storage", "rule": &"wall", "fp": 0.49, "max": 2},
			{"cat": "counter", "rule": &"wall", "fp": 1.72, "max": 3},
			{"cat": "bookcase", "rule": &"wall", "fp": 0.63, "max": 2},
			{"cat": "crate", "rule": &"corner", "fp": 0.76, "max": 1},
			{"cat": "shelf", "rule": &"mounted", "fp": 0.0, "per_area": 12.0, "max": 4},
		],
		# a little of everything: bins, bags, a table of goods
		&"general_store": [
			{"cat": "counter", "rule": &"wall", "fp": 1.72, "max": 4},
			{"cat": "crate", "rule": &"corner", "fp": 0.76, "max": 2},
			{"cat": "barrel", "rule": &"corner", "fp": 0.49, "max": 2},
			{"cat": "storage", "rule": &"wall", "fp": 0.49, "max": 2},
			{"cat": "sack", "rule": &"corner", "fp": 0.36, "max": 2},
			{"cat": "shelf", "rule": &"mounted", "fp": 0.0, "per_area": 12.0, "max": 4},
		],
		&"carpenter": [
			{"cat": "counter", "rule": &"wall", "fp": 1.72, "max": 4},
			{"cat": "crate", "rule": &"corner", "fp": 0.76, "max": 2},
			{"cat": "storage", "rule": &"wall", "fp": 0.49, "max": 1},
			{"cat": "chest", "rule": &"wall", "fp": 0.96, "max": 2},
			{"cat": "shelf", "rule": &"mounted", "fp": 0.0, "per_area": 12.0, "max": 4},
		],
		&"thieves_den": [
			{"cat": "counter", "rule": &"wall", "fp": 1.72, "max": 8},
			{"cat": "chest", "rule": &"wall", "fp": 0.96, "max": 4},
			{"cat": "crate", "rule": &"corner", "fp": 0.76, "max": 3},
			{"cat": "barrel", "rule": &"corner", "fp": 0.49, "max": 3},
			{"cat": "storage", "rule": &"wall", "fp": 0.49, "max": 3},
			{"cat": "shelf", "rule": &"mounted", "fp": 0.0, "per_area": 12.0, "max": 4},
		],
		&"": [
			{"cat": "counter", "rule": &"wall", "fp": 1.72, "max": 4},
			{"cat": "crate", "rule": &"corner", "fp": 0.76, "max": 2},
			{"cat": "storage", "rule": &"wall", "fp": 0.49, "max": 2},
			{"cat": "chest", "rule": &"wall", "fp": 0.96, "max": 2},
			{"cat": "shelf", "rule": &"mounted", "fp": 0.0, "per_area": 12.0, "max": 4},
		],
	},
	# the work behind the shop: benches to work at, stock beside them
	&"workshop": {
		&"": [
			{"cat": "workbench", "rule": &"wall", "fp": 1.9, "max": 3, "clear_of_doors": true},
			{"cat": "storage", "rule": &"wall", "fp": 0.49, "max": 2},
			{"cat": "crate", "rule": &"corner", "fp": 0.76, "max": 2},
			{"cat": "barrel", "rule": &"corner", "fp": 0.49, "max": 2},
			{"cat": "sack", "rule": &"corner", "fp": 0.36, "max": 2},
		],
	},
	&"office": {
		&"": [
			{"cat": "workbench", "rule": &"wall", "fp": 1.9, "max": 8},
			{"cat": "chest", "rule": &"wall", "fp": 0.96, "max": 4},
			{"cat": "storage", "rule": &"wall", "fp": 0.49, "max": 4},
			{"cat": "crate", "rule": &"corner", "fp": 0.76, "max": 3},
		],
	},
	&"records": {
		&"": [
			{"cat": "bookcase", "rule": &"wall", "fp": 0.63, "max": 7},
			{"cat": "chest", "rule": &"wall", "fp": 0.96, "max": 3},
			{"cat": "workbench", "rule": &"wall", "fp": 1.9, "max": 2},
			{"cat": "candelabrum", "rule": &"free", "fp": 0.53, "light": true, "max": 4},
		],
	},
	# the great rooms of the public buildings: places to sit and to keep things,
	# and standing lights where the walls cannot carry enough
	&"reading_room": {
		&"": [
			{"cat": "workbench", "rule": &"wall", "fp": 1.9, "max": 6},
			{"cat": "bookcase", "rule": &"wall", "fp": 0.63, "max": 8},
			{"cat": "chest", "rule": &"wall", "fp": 0.96, "max": 3},
			{"cat": "sconce", "rule": &"mounted", "fp": 0.0, "light": true, "max": 6},
		],
	},
	&"scriptorium": {
		&"": [
			{"cat": "workbench", "rule": &"wall", "fp": 1.9, "max": 6},
			{"cat": "bookcase", "rule": &"wall", "fp": 0.63, "max": 5},
			{"cat": "chest", "rule": &"wall", "fp": 0.96, "max": 3},
			{"cat": "candelabrum", "rule": &"free", "fp": 0.53, "light": true, "max": 4},
		],
	},
	&"stacks": {
		&"": [
			{"cat": "bookcase", "rule": &"wall", "fp": 0.63, "max": 12},
			{"cat": "chest", "rule": &"wall", "fp": 0.96, "max": 3},
			{"cat": "workbench", "rule": &"wall", "fp": 1.9, "max": 2},
			{"cat": "candelabrum", "rule": &"free", "fp": 0.53, "light": true, "max": 4},
		],
	},
	&"guardroom": {
		&"": [
			{"cat": "workbench", "rule": &"wall", "fp": 1.9, "max": 2},
			{"cat": "chest", "rule": &"wall", "fp": 0.96, "max": 2},
			{"cat": "barrel", "rule": &"corner", "fp": 0.49, "max": 2},
			{"cat": "crate", "rule": &"corner", "fp": 0.76, "max": 2},
			{"cat": "candelabrum", "rule": &"free", "fp": 0.53, "light": true, "max": 2},
		],
	},
	&"antechamber": {
		&"": [
			{"cat": "bench", "rule": &"wall", "fp": 1.5, "max": 3, "settle": true},
			{"cat": "chest", "rule": &"wall", "fp": 0.96, "max": 3},
			{"cat": "workbench", "rule": &"wall", "fp": 1.9, "max": 2},
			{"cat": "candelabrum", "rule": &"free", "fp": 0.53, "light": true, "max": 3},
		],
	},
	&"throne_room": {
		&"": [
			{"cat": "bench", "rule": &"wall", "fp": 1.5, "max": 4, "settle": true},
			{"cat": "chest", "rule": &"wall", "fp": 0.96, "max": 4},
			{"cat": "workbench", "rule": &"wall", "fp": 1.9, "max": 3},
			{"cat": "candelabrum", "rule": &"free", "fp": 0.53, "light": true, "max": 5},
		],
	},
	&"gallery": {
		&"": [
			{"cat": "bench", "rule": &"wall", "fp": 1.5, "max": 4, "settle": true},
			{"cat": "chest", "rule": &"wall", "fp": 0.96, "max": 3},
			{"cat": "bookcase", "rule": &"wall", "fp": 0.63, "max": 3},
		],
	},
	&"tack_room": {
		&"": [
			{"cat": "chest", "rule": &"wall", "fp": 0.96, "max": 3},
			{"cat": "storage", "rule": &"wall", "fp": 0.49, "max": 2},
			{"cat": "barrel", "rule": &"corner", "fp": 0.49, "max": 2},
			{"cat": "sack", "rule": &"corner", "fp": 0.36, "max": 2},
			{"cat": "bench", "rule": &"wall", "fp": 1.5, "max": 2, "settle": true},
			{"cat": "candelabrum", "rule": &"free", "fp": 0.53, "light": true, "max": 4},
		],
	},
}


## Additive, area-scaled steps for a shop room whose base recipe leaves it bare.
## They draw from private streams (the rest of the house is not reshuffled),
## are always attempted LAST (opt 0.5 sorts after every recipe step, so the room's
## own table and its chairs have had their say) and are below 1.0 so the
## walkability repair may thin them: the customer's way matters more than a third crate.
static func shop_composition_steps(plan: HousePlan, room: int) -> Array:
	if not plan.spec is ShopSpec:
		return []
	var kind: StringName = plan.kind_of(room)
	var by_business: Dictionary = SHOP_COMPOSITION.get(kind, {})
	if by_business.is_empty():
		return []
	var business: StringName = (plan.spec as ShopSpec).business
	var candidates: Array = by_business.get(business, by_business.get(&"", []))
	var area := HouseGeometry.room_area(plan, room)
	if candidates.is_empty():
		return []
	# Wall goods (shelving) are asked for by the metre of wall a room has, so
	# they apply to a small sales floor too; the floor share is for big rooms.
	var share_applies: bool = area >= SHOP_COMPOSITION_MIN_AREA
	var target: float = area * float(SHOP_SHARE_BY_KIND.get(kind, SHOP_FLOOR_SHARE))
	var counts: Array[int] = []
	counts.resize(candidates.size())
	counts.fill(0)
	var have := 0.0
	var pieces := 0
	var progressed := true
	while share_applies and have < target and pieces < SHOP_COMPOSITION_MAX_PIECES and progressed:
		progressed = false
		for i in range(candidates.size()):
			if have >= target or pieces >= SHOP_COMPOSITION_MAX_PIECES:
				break
			if bool(candidates[i].get("light", false)) or candidates[i].has("per_area"):
				continue # lights and wall goods are scaled to the room below
			if counts[i] >= int(candidates[i]["max"]):
				continue
			counts[i] += 1
			have += float(candidates[i]["fp"])
			pieces += 1
			progressed = true
	var steps: Array = []
	for j in range(candidates.size()):
		if candidates[j].has("per_area"):
			counts[j] = clampi(int(ceil(area / float(candidates[j]["per_area"]))), 1,
				int(candidates[j]["max"]))
		elif bool(candidates[j].get("light", false)):
			if not share_applies:
				continue
			# a standing light for each LAMP_AREA of floor the walls and tables
			# cannot be counted on to light (one is assumed from the base recipe; a free spot may be refused)
			counts[j] = clampi(int(ceil(area / 35.0)) - 1, 0, int(candidates[j]["max"]))
		if counts[j] <= 0:
			continue
		# a wall may refuse a piece; whatever fits is kept
		steps.append({"cat": candidates[j]["cat"], "rule": candidates[j]["rule"],
			"n": [counts[j], counts[j]], "opt": 0.5, "always_attempt": true,
			"private_rng": true, "settle": bool(candidates[j].get("settle", false)),
			"clear_of_doors": bool(candidates[j].get("clear_of_doors", false)),
			# an overlay piece that no wall will take is dropped, not stood in the
			# middle of the floor where the customer walks
			"wall_only": true})
	return steps


const RUG_ROOM_KINDS := [&"hall", &"parlour", &"dining", &"dining_room"]

## Where a household eats, best first. A dwelling has ONE dining table: in the
## dining room if it has one, else in the hall. A parlour in a house that eats
## elsewhere is the room you sit in, not a second place to dine -- the village
## walk found houses with three tables and no way past them (walk QA, 6 Oct).
const DINING_KINDS: Array[StringName] = [&"dining_room", &"dining", &"hall"]

## What a parlour holds when the house dines elsewhere: a settle against the
## wall, the books and the chest, the lamps -- and the floor in the middle.
const SITTING_PARLOUR := [
	{"cat": "bench", "rule": &"wall", "n": [1, 1], "opt": 0.9, "settle": true},
	{"cat": "bookcase", "rule": &"wall", "n": [0, 1], "opt": 0.7},
	{"cat": "chest", "rule": &"wall", "n": [0, 1], "opt": 0.6},
	{"cat": "storage", "rule": &"wall", "n": [0, 1], "opt": 0.6},
	{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
	{"cat": "candle", "rule": &"on", "n": [1, 1], "opt": 0.8},
]


## What a room adds when it is far bigger than its recipe was written for.
## A recipe is a cottage-sized list; a hotel lobby of two hundred square metres
## furnished from it is a counter, a chandelier and an echo, and a 65 m2 office
## is one desk in a corner (walk QA, 6 Oct). Above `area` m2 these steps are
## added, after the room's own, so the room still has its defining pieces first.
const AMPLE := {
	&"lobby": {"area": 60.0, "steps": [
		{"cat": "table", "rule": &"free", "n": [1, 2], "opt": 0.9},
		{"cat": "seat", "rule": &"around", "n": [3, 6], "opt": 0.9},
		{"cat": "bench", "rule": &"wall", "n": [1, 2], "opt": 0.8, "settle": true},
		{"cat": "storage", "rule": &"wall", "n": [1, 1], "opt": 0.7},
		{"cat": "candelabrum", "rule": &"free", "n": [1, 2], "opt": 0.7},
		{"cat": "sconce", "rule": &"mounted", "n": [2, 3], "opt": 0.9},
	]},
	&"office": {"area": 30.0, "steps": [
		{"cat": "bookcase", "rule": &"wall", "n": [1, 2], "opt": 0.9},
		{"cat": "table", "rule": &"free", "n": [1, 1], "opt": 0.8},
		{"cat": "seat", "rule": &"around", "n": [2, 3], "opt": 0.8},
		{"cat": "chest", "rule": &"wall", "n": [0, 1], "opt": 0.6},
		{"cat": "storage", "rule": &"wall", "n": [0, 1], "opt": 0.6},
		{"cat": "candle", "rule": &"on", "n": [1, 1], "opt": 0.8},
	]},
	&"kitchen": {"area": 40.0, "steps": [
		# the work table in the middle of a big kitchen, a stool at it
		{"cat": "table", "rule": &"free", "n": [1, 1], "opt": 0.9},
		{"cat": "seat", "rule": &"around", "n": [1, 2], "opt": 0.8},
		{"cat": "storage", "rule": &"wall", "n": [1, 1], "opt": 0.8},
		{"cat": "barrel", "rule": &"corner", "n": [1, 2], "opt": 0.7},
		{"cat": "cookware", "rule": &"corner", "n": [1, 2], "opt": 0.7},
		# no extra lamp: a second one drawn on its own is a pair that was
		# never hung as a pair (sconce_pair)
		{"cat": "shelf", "rule": &"mounted", "n": [1, 2], "opt": 0.8},
	]},
	# A 60 m2 range of a peristyle house is a bed in an acre of floor when the
	# dressing rolls for its nightstand and chest both come up empty (WLD001
	# domus, seed 1: nothing was refused, both were rolled out). A bedroom this
	# big always gets its bedside table and a chest; the attempt is
	# not rolled, and if no wall takes one the placement says so as usual.
	&"bedroom": {"area": 30.0, "steps": [
		{"cat": "nightstand", "rule": &"wall", "n": [1, 1], "opt": 0.9, "always_attempt": true},
		{"cat": "chest", "rule": &"wall", "n": [1, 1], "opt": 0.8, "always_attempt": true},
	]},
	# Marker thresholds for the style-and-trade overlay below. Empty base steps
	# keep every other house family unchanged.
	&"hall": {"area": 60.0, "steps": []},
	&"parlour": {"area": 20.0, "steps": []},
	&"workshop": {"area": 30.0, "steps": []},
	&"records": {"area": 30.0, "steps": []},
}


## Is this a single household's home, as opposed to a shop, an inn, a hotel or
## a block of flats, any of which may lay a table in every room it likes?
static func is_dwelling(plan: HousePlan) -> bool:
	var spec: HouseSpec = plan.spec
	# an innkeeper's house is a public house: its parlour is a second taproom
	return spec != null and not spec is ShopSpec and not spec is HotelSpec \
		and not spec is InsulaSpec and plan.world_family == &"" \
		and spec.trade != &"innkeeper"


## Activity-group overlays belong only to the ordinary HouseSpec. Keep the
## broader is_dwelling helper unchanged for existing callers that include
## keeps and custom house families.
static func is_ordinary_house(plan: HousePlan) -> bool:
	var spec: HouseSpec = plan.spec
	return spec != null and spec.get_script() == BASE_HOUSE_SPEC \
		and plan.world_family == &"" and spec.trade != &"innkeeper"


static func uses_native_domestic_fireplace(plan: HousePlan) -> bool:
	return is_ordinary_house(plan) and plan.spec.get_script() == BASE_HOUSE_SPEC \
		and plan.world_family == &"" and plan.spec.trade == &"none" \
		and plan.spec.style != &"witch_hut" and plan.spec.allows_hearth_furniture()


## Base-house guest bedrooms use the same measured bed/headstand pair. This
## does not opt an inn into domestic cooking, dining or custom-family recipes.
static func uses_bedside_pair(plan: HousePlan) -> bool:
	return plan.spec != null and plan.spec.get_script() == BASE_HOUSE_SPEC \
		and plan.world_family == &""


## The room this dwelling eats in, or -1. Rooms of the first DINING_KINDS kind
## present; the lowest-numbered of them.
static func dining_room_of(plan: HousePlan) -> int:
	# Ordinary houses choose one physically verified household dining room before
	# any furniture is placed. The selected room may be upstairs only when the
	# planner's bare circulation check passed. A missing room is explicit; do not
	# silently infer one from a hall that also sleeps or cooks.
	if is_ordinary_house(plan) and plan.domestic_layout.has("dining_room"):
		var selected: int = int(plan.domestic_layout.get("dining_room", -1))
		return selected if selected >= 0 and selected < plan.room_count() else -1
	for kind in DINING_KINDS:
		# A hall that is also the bedroom -- nobody sleeps anywhere else --
		# has a bed in it and its table against a wall if at all; a parlour
		# beside it is where the household eats.
		if kind == &"hall" and plan.has_kind(&"parlour") and not HouseFurnisher._anybody_sleeps(plan):
			continue
		var rooms: Array[int] = plan.rooms_of(kind)
		if not rooms.is_empty():
			return rooms[0]
	return -1


## Does this parlour's household eat in some other room? Then it gets the
## sitting programme instead of a table.
static func dines_elsewhere(plan: HousePlan, room: int) -> bool:
	if plan.kind_of(room) != &"parlour" or not is_dwelling(plan):
		return false
	var dining := dining_room_of(plan)
	if dining >= 0:
		return dining != room
	# no hall and no dining room: the first parlour is where they eat
	var parlours: Array[int] = plan.rooms_of(&"parlour")
	return not parlours.is_empty() and parlours[0] != room


## Domestic contracts are overlays, not edits to the shared shop, inn, castle,
## temple and world recipes. The base recipe remains the authority for every
## other family. A compact domestic hall may also carry the kitchen when its
## planner says it has no separate kitchen bay.
static func recipe_for_room(plan: HousePlan, room: int, sitting_if_available := true) -> Array:
	var kind: StringName = plan.kind_of(room)
	var recipe: Array = RECIPES.get(kind, [])
	if plan.spec.get_script() == BASE_HOUSE_SPEC and plan.world_family == &"" \
			and plan.spec.trade == &"innkeeper" and kind == &"bedroom":
		# Guest rooms retain both clothes storage and bedside support. These are
		# separate necessities, not independent optional dressing rolls.
		var guest_sleep: Array = []
		for original: Dictionary in recipe:
			if String(original["cat"]) == "storage":
				continue # the required clothes cupboard replaces this optional one
			var step: Dictionary = original.duplicate(true)
			if String(step["cat"]) in ["bed", "chest", "nightstand"]:
				step["opt"] = 1.0
				step["group"] = "sleep"
			if String(step["cat"]) == "chest":
				# This measured closed cupboard is shallower than the metal-bound
				# chest. Its doors retain their full 0.7 m opening/standing zone.
				step["cat"] = "storage"
				step["key"] = "Cabinet"
			if String(step["cat"]) == "nightstand":
				step["key"] = "Nightstand_Shelf"
				step["rule"] = &"beside"
				step["near_cat"] = "bed"
				step["near_anchor"] = "head_end"
			guest_sleep.append(step)
		return guest_sleep
	if plan.spec.get_script() == BASE_HOUSE_SPEC and plan.world_family == &"" \
			and plan.spec.trade == &"innkeeper" and kind == &"kitchen":
		# An inn's kitchen has a fire; it also needs a board to prepare food on.
		var inn_kitchen: Array = recipe.duplicate(true)
		inn_kitchen.append({"cat": "table", "rule": &"free", "n": [1, 1],
			"opt": 1.0, "private_rng": true})
		return inn_kitchen
	if plan.spec.get_script() == BASE_HOUSE_SPEC and plan.world_family == &"" \
			and plan.spec.trade == &"innkeeper" and kind == &"parlour":
		# Public dining is separate from the ordinary household's one-table
		# programme. Reserve this table and its two matching seats together;
		# a later optional stool cannot repair a table placed for one bench.
		var public_dining: Array = []
		for original: Dictionary in recipe:
			if String(original["cat"]) in ["seat", "bench"]:
				continue
			var step: Dictionary = original.duplicate(true)
			if String(step["cat"]) == "table":
				step["seat_cat"] = "seat"
				step["seat_n"] = 2
				step["seat_n_required"] = true
			public_dining.append(step)
		return public_dining
	if kind == &"kitchen" and plan.spec is ShopSpec:
		return SHOP_KITCHEN.duplicate(true)
	if not is_ordinary_house(plan):
		# Keep the old public/private parlour substitution for a keep, custom
		# house or trade family that the broader dwelling predicate includes.
		if sitting_if_available and dines_elsewhere(plan, room):
			return SITTING_PARLOUR
		return recipe
	var parlour_is_sitting: bool = sitting_if_available and dines_elsewhere(plan, room)
	if parlour_is_sitting:
		recipe = _sitting_parlour_recipe()
	else:
		recipe = recipe.duplicate(true)
	# The merchant's townhouse office is a writing place, not a generic shop
	# workbench. Keep this overlay inside ordinary HouseSpec so trade, world,
	# custom-family and other house-style contracts retain their own recipes.
	if is_ordinary_house(plan) and plan.spec.trade == &"none" \
			and kind == &"office" and plan.spec.style == &"townhouse":
		return TOWNHOUSE_OFFICE_ACTIVITY.duplicate(true)
	var domestic_functions: Array = plan.rooms[room].get("domestic_functions", [])
	var shared_cooking: bool = kind == &"hall" and domestic_functions.has(&"cooking")
	if kind == &"kitchen" and (plan.spec.style != &"witch_hut" or plan.spec.trade == &"none"):
		# The cooking compositor needs a usable board for its supported crockery.
		# A random tall display rack can occupy the only nearby shelf/light bay
		# while offering no clear top below the ceiling. Start with the measured
		# kitchen shelf; the compositor still proves its wall, light and contents.
		for step in recipe:
			if String(step.get("cat", "")) == "shelf" and not step.has("key"):
				step["key"] = "Shelf_Simple"
	# A no-trade Witch's Hut has a real craft room. This is a style-local
	# overlay; the alchemist trade and every non-witch workshop keep their own
	# existing recipes.
	if kind == &"workshop" and plan.spec.style == &"witch_hut" \
			and plan.spec.trade == &"none":
		var witch_steps: Array = []
		for step_variant in recipe:
			var step: Dictionary = step_variant.duplicate(true)
			var category := String(step.get("cat", ""))
			if category == "crate":
				# Generic corner crates scatter anonymous stock through the room.
				# One fitted ingredient cabinet replaces them below.
				continue
			if category == "workbench":
				step["group"] = "witchwork"
				step["opt"] = 1.0
				step["height_scale"] = 1.0
			elif category == "shelf":
				if not step.has("key"):
					step["key"] = "Shelf_Small_Bottles"
				step["group"] = "witchwork"
				step["opt"] = 1.0
			elif category == "rack":
				step["key"] = "Peg_Rack"
				step["n"] = [1, 1]
				step["group"] = "witchwork"
				step["opt"] = 1.0
			elif category == "sconce":
				step["group"] = "witchwork"
				step["opt"] = 1.0
			witch_steps.append(step)
		recipe = witch_steps
		recipe.append_array([
			{"cat": "storage", "rule": &"wall", "key": "Cabinet", "n": [1, 1], "opt": 1.0, "group": "witchwork"},
			{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0, "group": "witchwork"},
			{"cat": "shelf", "rule": &"mounted", "key": "Shelf_Simple", "n": [1, 1], "opt": 1.0, "group": "witchwork"},
			{"cat": "alchemy", "rule": &"on", "host_category": "shelf", "key": "SmallBottles_1", "n": [2, 2], "opt": 1.0, "group": "witchwork"},
			{"cat": "alchemy", "rule": &"on", "host_category": "workbench", "n": [2, 2], "opt": 1.0, "group": "witchwork"},
			{"cat": "books", "rule": &"on", "host_category": "workbench", "key": "Book_Stack_1", "n": [1, 1], "opt": 1.0, "group": "witchwork"},
		])
	var tagged: Array = []
	for original in recipe:
		var step: Dictionary = original.duplicate(true)
		var category: String = String(step.get("cat", ""))
		if not parlour_is_sitting and kind in [&"hall", &"dining_room", &"parlour"] \
				and category in ["table", "seat", "bench"]:
			step["group"] = "eating"
			step["opt"] = 1.0
		elif parlour_is_sitting and category in ["bench", "sconce"]:
			step["group"] = "sitting"
			step["opt"] = 1.0
		if kind == &"bedroom":
			if category == "bed":
				step["group"] = "sleep"
			elif category == "nightstand":
				# Keep the measured bedside shelf in its actual role. Placement
				# applies a bedroom-only scale and height cap. Clothes storage stays
				# a separate chest step.
				step["key"] = "Nightstand_Shelf"
				step["rule"] = &"beside"
				step["near_cat"] = "bed"
				step["near_anchor"] = "head_end"
				step["opt"] = 1.0
				step["group"] = "sleep"
			elif category == "chest":
				step["group"] = "sleep"
				step["opt"] = 1.0
			elif category == "sconce":
				step["group"] = "sleep"
				step["opt"] = 1.0
		if kind == &"kitchen" and category in ["hearth", "storage", "cookware"]:
			step["group"] = "cooking"
			step["opt"] = 1.0
		if kind == &"store" and plan.spec.style == &"witch_hut" \
				and plan.spec.trade == &"none" \
				and plan.domestic_layout.get("added_activities", []).has(&"store") \
				and category in ["barrel", "storage"]:
			# The compact Witch plan's added rear room is a working dry pantry,
			# not spare floor. Its container needs a measured access stance.
			step["group"] = "witch_pantry"
			step["n"] = [1, 1]
			step["opt"] = 1.0
			if category == "barrel":
				step["zone_depth_override"] = 0.6
		tagged.append(step)
	if kind == &"kitchen":
		var prep_pair: Array = [
			{"cat": "workbench", "rule": &"beside", "near_cat": "storage", "align_back": true, "n": [1, 1], "opt": 1.0, "group": "cooking"},
			{"cat": "bucket", "rule": &"beside", "near_cat": "storage", "align_back": true, "n": [1, 1], "opt": 1.0, "group": "cooking"},
		]
		if uses_native_domestic_fireplace(plan) \
				or (plan.spec.style == &"witch_hut" and plan.spec.trade == &"none"):
			var without_loose_cookware: Array = []
			for step: Dictionary in tagged:
				if String(step.get("cat", "")) != "cookware":
					without_loose_cookware.append(step)
			tagged = without_loose_cookware
			prep_pair.append({"cat": "cookware", "rule": &"on",
				"host_category": "workbench", "key": "Pot_1", "n": [1, 1],
				"opt": 1.0, "group": "cooking"})
		var storage_index := -1
		for step_index in range(tagged.size()):
			if String(tagged[step_index].get("cat", "")) == "storage":
				storage_index = step_index
				break
		if storage_index >= 0:
			for prep_step in prep_pair:
				tagged.insert(storage_index + 1, prep_step)
				storage_index += 1
		else:
			tagged.append_array(prep_pair)
	var shared_witchwork: bool = is_ordinary_house(plan) \
		and kind in [&"hall", &"kitchen"] \
		and plan.spec.style == &"witch_hut" and plan.spec.trade == &"none" \
		and bool(plan.rooms[room].get("shared_witchwork", false)) \
		and domestic_functions.has(&"witchwork")
	var heat_contract: Dictionary = plan.rooms[room].get("shared_activity_station", {})
	var heat_contract_groups: Array = heat_contract.get("groups", [])
	var activity_regions: Dictionary = plan.rooms[room].get("activity_regions", {})
	var cooking_region: Rect2 = Rect2(activity_regions.get(&"cooking", Rect2()))
	var witchwork_region: Rect2 = Rect2(activity_regions.get(&"witchwork", Rect2()))
	var shared_regions_match: bool = activity_regions.has(&"cooking") \
		and activity_regions.has(&"witchwork") \
		and cooking_region.position.is_equal_approx(witchwork_region.position) \
		and cooking_region.size.is_equal_approx(witchwork_region.size)
	var compact_shared_heat: bool = shared_witchwork and kind == &"hall" \
		and String(heat_contract.get("id", "")) == "compact_witch_hearth" \
		and String(heat_contract.get("category", "")) == "hearth" \
		and String(heat_contract.get("scope", "")) == "compact_witch_shared_hall" \
		and heat_contract_groups.has(&"cooking") and heat_contract_groups.has(&"witchwork") \
		and shared_regions_match
	if kind == &"store" and plan.spec.style == &"witch_hut" \
			and plan.spec.trade == &"none" \
			and plan.domestic_layout.get("added_activities", []).has(&"store"):
		tagged.append({"cat": "storage", "rule": &"wall", "n": [1, 1],
			"opt": 1.0, "group": "witch_pantry"})
	if shared_witchwork:
		tagged.append_array([
			{"cat": "workbench", "rule": &"wall", "n": [1, 1], "opt": 1.0,
				"height_scale": 1.0, "preferred_walls": [0], "group": "witchwork"},
			{"cat": "shelf", "rule": &"mounted", "key": "Shelf_Small_Bottles", "n": [1, 1], "opt": 1.0, "group": "witchwork"},
			{"cat": "sconce", "rule": &"mounted", "n": [1, 1], "opt": 1.0, "group": "witchwork"},
			{"cat": "alchemy", "rule": &"on", "host": "distributed", "n": [2, 2], "opt": 1.0, "group": "witchwork"},
			{"cat": "books", "rule": &"on", "host_category": "workbench", "key": "Book_Stack_1", "n": [1, 1], "opt": 1.0, "group": "witchwork"},
		])
		if not compact_shared_heat:
			tagged.append({"cat": "hearth", "rule": &"wall", "n": [1, 1],
				"opt": 1.0, "group": "witchwork"})
	if shared_cooking:
		var cooking_core: Array = [
			{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0, "group": "cooking",
				"shared_activity_groups": ["witchwork"] if compact_shared_heat else [],
				"shared_station_id": "compact_witch_hearth" if compact_shared_heat else ""},
			{"cat": "storage", "rule": &"wall", "n": [1, 1], "opt": 1.0, "group": "cooking"},
			{"cat": "workbench", "rule": &"beside", "near_cat": "storage", "align_back": true, "n": [1, 1], "opt": 1.0, "group": "cooking"},
			{"cat": "bucket", "rule": &"beside", "near_cat": "storage", "align_back": true, "n": [1, 1], "opt": 1.0, "group": "cooking"},
			{"cat": "cookware", "rule": &"on", "host_category": "workbench", "n": [1, 1], "opt": 1.0, "group": "cooking"},
		]
		if compact_shared_heat or uses_native_domestic_fireplace(plan):
			# These Hall cooking contracts require a measured preparation vessel.
			# The cookware catalogue also contains a metal bucket, which does not
			# meet the authored pot role of the compact Alchemist household.
			var vessel_step: Dictionary = cooking_core[-1]
			vessel_step["key"] = "Pot_1"
			cooking_core[-1] = vessel_step
		var without_duplicate_kitchen_storage: Array = []
		for step in tagged:
			if String(step.get("cat", "")) == "storage":
				continue # cooking_core already supplied the household's store
			without_duplicate_kitchen_storage.append(step)
		if compact_shared_heat:
			# Place Witchwork first, but accept its measured wall candidate only
			# when the following shared hearth and cooking storage/prep group also
			# fit. The actual hearth-first order reserves its breast before that pair.
			var witch_bench: Dictionary = {}
			for index in range(without_duplicate_kitchen_storage.size()):
				var candidate: Dictionary = without_duplicate_kitchen_storage[index]
				if String(candidate.get("cat", "")) == "workbench" and String(candidate.get("group", "")) == "witchwork":
					witch_bench = candidate
					without_duplicate_kitchen_storage.remove_at(index)
					break
			if not witch_bench.is_empty():
				var compact_core: Array = cooking_core.duplicate(true)
				tagged = [witch_bench] + compact_core + without_duplicate_kitchen_storage
			else:
				tagged = cooking_core + without_duplicate_kitchen_storage
		else:
			tagged = cooking_core + without_duplicate_kitchen_storage
	if is_ordinary_house(plan) and plan.domestic_layout.has("dining_room"):
		var selected_room: int = int(plan.domestic_layout.get("dining_room", -1))
		var dining_kinds: Array[StringName] = [&"hall", &"dining_room", &"dining", &"parlour"]
		if kind in dining_kinds and room != selected_room:
			# A household has one meal table. Other parlours are sitting rooms;
			# other halls and dining rooms keep their non-meal pieces only.
			if kind == &"parlour":
				return _sitting_parlour_recipe()
			var without_second_meal: Array = []
			for step in tagged:
				if String(step.get("cat", "")) in ["table", "seat", "bench"]:
					continue
				without_second_meal.append(step)
			tagged = without_second_meal
		elif room == selected_room:
			var preplaced_meal: Array = plan.domestic_layout.get("dining_group", [])
			var without_meal_bench: Array = []
			for step in tagged:
				if String(step.get("cat", "")) == "bench":
					continue
				if not preplaced_meal.is_empty() \
						and String(step.get("cat", "")) in ["table", "seat"]:
					continue
				without_meal_bench.append(step)
			tagged = without_meal_bench
	return tagged


static func _sitting_parlour_recipe() -> Array:
	var out: Array = SITTING_PARLOUR.duplicate(true)
	for step in out:
		var category: String = String(step.get("cat", ""))
		if category in ["bench", "sconce"]:
			step["group"] = "sitting"
			step["opt"] = 1.0
	return out


## Optional large-room additions follow the same family boundary as the core
## recipe. Ordinary bedrooms already receive a scaled Nightstand_Shelf bedside
## support, so the ample recipe does not add a second one.
static func ample_steps_for_room(plan: HousePlan, room: int) -> Array:
	var kind: StringName = plan.kind_of(room)
	if plan.spec.style == &"witch_hut":
		var area := HouseGeometry.room_area(plan, room)
		# A large Witch house keeps records and a great Hall whatever its trade:
		# the room must be furnished for the household that lives in it.
		if kind == &"records" and area >= 30.0:
			return [
				{"cat": "bookcase", "rule": &"wall", "n": [2, 2], "opt": 1.0, "private_rng": true},
				{"cat": "chest", "rule": &"wall", "n": [1, 1], "opt": 1.0, "private_rng": true},
				{"cat": "storage", "rule": &"wall", "n": [1, 1], "opt": 1.0, "private_rng": true},
			]
		if kind == &"workshop" and area >= 30.0 and plan.spec.trade == &"alchemist":
			# Ingredient cabinet: the laboratory needs a place to keep its stock.
			return [{"cat": "storage", "key": "Cabinet", "rule": &"wall",
				"n": [1, 1], "opt": 1.0, "group": "trade_stock"}]
		if kind == &"hall" and area >= 120.0:
			# A great Hall gets distinct places to sit and store books and
			# household goods. The trade's laboratory remains in its Workshop.
			return [
				{"cat": "bench", "rule": &"wall", "n": [7, 7], "opt": 1.0, "settle": true},
				{"cat": "chest", "rule": &"wall", "n": [2, 2], "opt": 1.0},
				{"cat": "bookcase", "rule": &"wall", "n": [2, 2], "opt": 1.0},
				{"cat": "storage", "rule": &"wall", "n": [1, 1], "opt": 1.0},
			]
		if kind == &"hall" and area >= 60.0:
			if plan.spec.trade != &"alchemist":
				# Not essential (opt below 1.0), so the walkability repair may thin
				# these. Each draws from its own stream and the corner pieces never
				# stand in a doorway's approach.
				return [
					{"cat": "bench", "rule": &"wall", "n": [3, 3], "opt": 0.9, "settle": true, "always_attempt": true, "private_rng": true},
					{"cat": "chest", "rule": &"wall", "n": [2, 2], "opt": 0.9, "always_attempt": true, "private_rng": true},
					{"cat": "bookcase", "rule": &"wall", "n": [2, 2], "opt": 0.9, "always_attempt": true, "private_rng": true},
					{"cat": "barrel", "rule": &"corner", "n": [2, 2], "opt": 0.9, "always_attempt": true, "private_rng": true},
					{"cat": "crate", "rule": &"corner", "n": [2, 2], "opt": 0.9, "always_attempt": true, "private_rng": true},
				]
			return [
				{"cat": "bench", "rule": &"wall", "n": [3, 3], "opt": 1.0, "settle": true},
				{"cat": "chest", "rule": &"wall", "n": [1, 1], "opt": 1.0},
			]
		if kind == &"parlour" and area >= 30.0:
			return [
				{"cat": "bench", "rule": &"wall", "n": [2, 2], "opt": 1.0, "settle": true, "group": "sitting"},
				{"cat": "bookcase", "rule": &"wall", "n": [1, 1], "opt": 1.0},
				{"cat": "chest", "rule": &"wall", "n": [1, 1], "opt": 1.0},
			]
	# A big hall or sitting parlour of any other base house (an innkeeper's
	# townhouse included) was a few pieces in an acre of floor with one lamp.
	# Fit its walls and corners to its size. Each step draws from its own
	# stream, so the rooms furnished after it keep their rolls, and the pieces
	# are optional (the walkability repair may thin them).
	if plan.spec.get_script() == BASE_HOUSE_SPEC and plan.world_family == &"" \
			and plan.spec.style != &"witch_hut" and kind in [&"hall", &"parlour"] \
			and room !=int(plan.domestic_layout.get("dining_room", -1)):
		var room_area := HouseGeometry.room_area(plan, room)
		var scale_n := clampi(int(room_area / 20.0), 1, 4)
		var lights := clampi(int(ceil(room_area / 35.0)), 1, 4)
		return [
			{"cat": "bench", "rule": &"wall", "n": [scale_n, scale_n], "opt": 0.9, "settle": true, "always_attempt": true, "private_rng": true},
			{"cat": "bookcase", "rule": &"wall", "n": [1, scale_n], "opt": 0.9, "always_attempt": true, "private_rng": true},
			{"cat": "chest", "rule": &"wall", "n": [1, scale_n], "opt": 0.9, "always_attempt": true, "private_rng": true},
			{"cat": "storage", "rule": &"wall", "n": [1, scale_n], "opt": 0.9, "always_attempt": true, "private_rng": true},
			{"cat": "sconce", "rule": &"mounted", "n": [lights, lights], "opt": 0.9, "always_attempt": true, "private_rng": true},
		]
	# One measured desk group scales with the writer, not the office footprint.
	# Additional generic tables and chairs make a large Townhouse office less
	# usable by filling the pull-back space around its one writing chair.
	if is_ordinary_house(plan) and plan.spec.trade == &"none" \
			and kind == &"office" and plan.spec.style == &"townhouse":
		return []
	var ample: Dictionary = AMPLE.get(kind, {})
	var steps: Array = ample.get("steps", []).duplicate(true)
	if is_ordinary_house(plan) and kind == &"bedroom":
		var domestic_steps: Array = []
		for step in steps:
			if String(step.get("cat", "")) != "nightstand":
				domestic_steps.append(step)
		steps = domestic_steps
	return steps

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
		{"cat": "table", "rule": &"row", "n": [1, 3], "min_n": 1, "pitch": 2.2,
			"aisle": 1.0, "seat_clearance": 1.15, "along": "wall", "opt": 1.0},
		{"cat": "seat", "rule": &"around", "n": [2, 4], "opt": 1.0},
		{"cat": "bench", "rule": &"around", "n": [0, 1], "opt": 0.7},
		{"cat": "barrel", "rule": &"corner", "n": [1, 2], "opt": 0.7},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
		{"cat": "tableware", "rule": &"on", "n": [2, 4], "opt": 0.95},
	],
	&"great_hall": [
		# In order, because in a hall the order IS the arrangement: the high
		# table takes the dais, the lord bench goes behind it, the fire takes
		# its wall, and only then do the trestles take what is left. Run the
		# other way round, the trestles have the wall the flue rises on.
		{"cat": "table", "rule": &"free", "n": [1, 1], "opt": 1.0},
		{"cat": "bench", "rule": &"behind", "n": [1, 2], "opt": 1.0},
		{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "table", "rule": &"row", "n": [2, 8], "min_n": 2, "pitch": 2.4,
			"aisle": 1.0, "seat_clearance": 1.1, "along": "wall", "opt": 1.0},
		{"cat": "table", "rule": &"row", "n": [2, 8], "min_n": 2, "pitch": 2.4,
			"aisle": 1.0, "seat_clearance": 1.1, "along": "wall", "opt": 1.0},
		{"cat": "bench", "rule": &"around", "host": "row", "n": [2, 4], "opt": 1.0},
		{"cat": "storage", "rule": &"wall", "n": [0, 1], "opt": 0.5},
		{"cat": "barrel", "rule": &"corner", "n": [1, 2], "opt": 0.6},
		{"cat": "sconce", "rule": &"mounted", "n": [2, 4], "opt": 1.0},
		{"cat": "chandelier", "rule": &"ceiling", "n": [1, 1], "opt": 0.8},
		{"cat": "tableware", "rule": &"on", "n": [2, 6], "opt": 0.9},
		{"cat": "candle", "rule": &"on", "n": [1, 2], "opt": 0.85},
	],
	&"nave": [
		# A chapel is a hall with one thing at the end of it. The altar is a
		# table, because in this catalogue that is what an altar is -- the
		# castle dressing has said so since CAS-003 -- and the pews are rows
		# either side of a centre aisle, which is the row rule doing what it
		# was written for (INT-001).
		{"cat": "table", "rule": &"free", "n": [1, 1], "opt": 1.0},
		# A pitch of 0 lets the rule space the pews by the pew: a bench in
		# this catalogue is 2.78 m long, and a pitch written for a shorter one
		# is ignored anyway (use_pitch is never less than the piece and a hand).
		{"cat": "bench", "rule": &"row", "n": [2, 4], "min_n": 2, "pitch": 0.0,
			"aisle": 1.2, "seat_clearance": 0.0, "along": "wall", "opt": 1.0},
		{"cat": "bench", "rule": &"row", "n": [2, 4], "min_n": 2, "pitch": 0.0,
			"aisle": 1.2, "seat_clearance": 0.0, "along": "wall", "opt": 1.0},
		{"cat": "candelabrum", "rule": &"free", "n": [0, 2], "opt": 0.7},
		{"cat": "sconce", "rule": &"mounted", "n": [2, 4], "opt": 1.0},
		{"cat": "tableware", "rule": &"on", "n": [1, 2], "opt": 0.9},
		{"cat": "candle", "rule": &"on", "n": [1, 1], "opt": 0.9},
	],
	&"sanctuary": [
		# The altar bay serves standing worship. Congregation seating belongs
		# in the adjoining nave, whose existing pew rows remain unchanged.
		{"cat": "table", "rule": &"free", "n": [1, 1], "opt": 1.0},
		{"cat": "candelabrum", "rule": &"free", "n": [0, 1], "opt": 0.7},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 1], "opt": 1.0},
	],
	&"lords_chamber": [
		# The room at the top of a keep: a bed, a fire of its own, and enough
		# to sit at. The hearth goes in before the bed because the flue is on a
		# wall the plan named (LAY-001) and the bed can take any other.
		{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "bed", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "chest", "rule": &"wall", "n": [1, 1], "opt": 0.9},
		{"cat": "table", "rule": &"free", "n": [0, 1], "opt": 0.6},
		{"cat": "seat", "rule": &"around", "n": [1, 2], "opt": 0.8},
		{"cat": "storage", "rule": &"wall", "n": [0, 1], "opt": 0.6},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
		{"cat": "candle", "rule": &"on", "n": [1, 1], "opt": 0.9},
	],
	&"antechamber": [
		{"cat": "seat", "rule": &"around", "n": [1, 2], "opt": 0.7},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
	],
	&"throne_room": [
		{"cat": "seat", "key": "Chair_1", "rule": &"free", "n": [1, 1], "opt": 1.0},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
	],
	&"treasury": [
		{"cat": "chest", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "storage", "rule": &"wall", "n": [0, 1], "opt": 0.7},
	],
	&"royal_chamber": [
		{"cat": "bed", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "chest", "rule": &"wall", "n": [1, 1], "opt": 0.9},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
	],
	&"guest_room": [
		{"cat": "bed", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "chest", "rule": &"wall", "n": [1, 1], "opt": 0.8},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 1], "opt": 0.8},
	],
	&"dormitory": [
		{"cat": "bed", "rule": &"row", "n": [4, 6], "min_n": 4, "pitch": 0.0,
			"aisle": 1.0, "along": "wall", "avoid_window_walls": true,
			"avoid_door_lines": true, "opt": 1.0},
		{"cat": "chest", "rule": &"wall", "n": [0, 2], "opt": 0.55},
		{"cat": "sconce", "rule": &"mounted", "n": [2, 3], "opt": 0.9},
	],
	&"armoury": [
		{"cat": "stand", "key": "WeaponStand", "rule": &"row", "n": [2, 4], "min_n": 2,
			"pitch": 0.0, "aisle": 0.9, "along": "wall", "opt": 1.0},
		{"cat": "trophy", "key": "Shield_Wooden", "rule": &"mounted", "n": [2, 4], "opt": 1.0},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.8},
	],
	&"mess": [
		{"cat": "table", "rule": &"free", "n": [1, 1], "opt": 1.0},
		{"cat": "bench", "rule": &"around", "n": [2, 2], "opt": 1.0},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.8},
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
	&"guardroom": [
		{"cat": "table", "rule": &"free", "n": [1, 1], "opt": 1.0},
		{"cat": "seat", "rule": &"around", "n": [2, 4], "opt": 1.0},
	],
	# The wall circuit of a small tower: a bench to watch from, an arms rack,
	# and the stores the post keeps. No table: the stair has the floor a
	# diner's chair would need (see HouseGeometry.HABITABLE).
	&"watch_room": [
		{"cat": "bench", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "stand", "key": "WeaponStand", "rule": &"wall", "n": [1, 1], "opt": 0.9},
		{"cat": "chest", "rule": &"wall", "n": [0, 1], "opt": 0.7},
		{"cat": "storage", "rule": &"wall", "n": [0, 1], "opt": 0.6},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 1], "opt": 0.9},
	],
	&"cell": [
		{"cat": "cage", "key": "Cage_Small", "rule": &"wall", "n": [1, 1], "opt": 1.0},
	],
	&"reading_room": [
		{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "lectern", "rule": &"free", "n": [2, 2], "opt": 1.0},
		{"cat": "table", "rule": &"free", "n": [1, 1], "opt": 1.0},
		{"cat": "seat", "rule": &"around", "n": [2, 4], "opt": 1.0},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
	],
	# Two wall-backed runs leave a measured one-metre aisle. A center bank fills
	# the large room when its space is available, but is treated as one optional
	# furnishing so navigation repair cannot tear a hole in its shelf pitch.
	&"stacks": [
		{"cat": "bookcase", "rule": &"row", "n": [3, 5], "min_n": 3,
			"pitch": 0.0, "aisle": 1.0, "along": "wall",
			"avoid_door_lines": true, "opt": 1.0},
		{"cat": "bookcase", "rule": &"row", "n": [3, 5], "min_n": 3,
			"pitch": 0.0, "aisle": 1.0, "along": "wall",
			"avoid_door_lines": true, "opt": 1.0},
		{"cat": "bookcase", "rule": &"row", "n": [3, 8], "min_n": 3,
			"pitch": 0.0, "aisle": 1.0, "along": "axis",
			"avoid_door_lines": true, "free_standing": true,
			"repair_optional": true, "always_attempt": true, "opt": 1.0},
		{"cat": "sconce", "rule": &"mounted", "n": [1, 2], "opt": 0.8},
	],
	&"scriptorium": [
		{"cat": "workbench", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "seat", "rule": &"around", "n": [1, 1], "opt": 0.8},
		{"cat": "books", "rule": &"on", "n": [1, 2], "opt": 0.9},
		{"cat": "shelf", "rule": &"mounted", "n": [1, 2], "opt": 0.8},
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
	&"laboratory": [
		{"cat": "workbench", "rule": &"wall", "n": [2, 2], "opt": 1.0},
		{"cat": "cage", "key": "Cage_Small", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0},
	],
	&"bath_hall": [
		{"cat": "bucket", "rule": &"corner", "n": [1, 2], "opt": 0.8},
	],
	&"changing_room": [
		{"cat": "bench", "rule": &"row", "n": [1, 2], "min_n": 1,
			"pitch": 0.0, "aisle": 0.9, "along": "wall", "opt": 1.0},
		{"cat": "rack", "rule": &"mounted", "n": [1, 2], "opt": 0.9},
	],
	&"ward": [
		{"cat": "bed", "rule": &"row", "n": [2, 6], "min_n": 2,
			"pitch": 0.0, "aisle": 1.0, "along": "wall", "avoid_window_walls": true,
			"avoid_door_lines": true, "opt": 1.0},
		{"cat": "nightstand", "rule": &"wall", "n": [0, 2], "opt": 0.6},
	],
	&"dispensary": [
		{"cat": "bookcase", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "workbench", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "alchemy", "rule": &"on", "n": [1, 2], "opt": 1.0},
	],
	&"schoolroom": [
		{"cat": "bench", "rule": &"row", "n": [2, 4], "min_n": 2,
			"pitch": 0.0, "aisle": 1.1, "along": "wall", "opt": 1.0},
		{"cat": "bench", "rule": &"row", "n": [2, 4], "min_n": 2,
			"pitch": 0.0, "aisle": 1.1, "along": "wall", "opt": 1.0},
	],
	&"masters_office": [
		{"cat": "workbench", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "seat", "rule": &"around", "n": [1, 1], "opt": 1.0},
		{"cat": "bookcase", "rule": &"wall", "n": [1, 1], "opt": 1.0},
	],
}

const SHOP_FITTINGS := {
	&"barracks": [
		{"cat": "chest", "rule": &"wall", "n": [1, 1], "opt": 1.0},
	],
	&"prison": [
		{"cat": "stand", "key": "WeaponStand", "rule": &"wall", "n": [1, 1], "opt": 1.0},
	],
	# the forge first, on the chimney wall the planner chose, and the anvil
	# beside it (its affinity says so) facing the door (the plan's focus)
	&"blacksmith": [
		{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0, "first": true},
		{"cat": "anvil", "rule": &"free", "n": [1, 1], "opt": 1.0},
	],
	# the oven in the shop, and flour in sacks in the bakehouse behind it
	&"bakery": [
		{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "sack", "rule": &"corner", "n": [1, 2], "opt": 1.0, "room": "kitchen"},
	],
	# the trade's own work at the bench behind the counter, not only on it: a
	# cleaver at the block, remedies being made up, cloth to be cut (LIVE-SHOPS)
	&"butcher": [
		{"cat": "blade", "rule": &"on", "n": [1, 2], "opt": 1.0},
		{"cat": "blade", "rule": &"on", "n": [1, 1], "opt": 1.0, "room": "workshop"},
	],
	&"apothecary": [
		{"cat": "alchemy", "rule": &"on", "n": [2, 4], "opt": 1.0},
		{"cat": "alchemy", "rule": &"on", "n": [1, 2], "opt": 1.0, "room": "workshop"},
	],
	&"alchemist_laboratory": [
		{"cat": "alchemy", "rule": &"on", "n": [2, 4], "host": "distributed", "opt": 1.0},
	],
	&"bathhouse": [
		{"cat": "barrel", "rule": &"row", "n": [2, 4], "min_n": 2,
			"pitch": 0.0, "aisle": 0.9, "along": "wall", "room": "bath_hall", "opt": 1.0},
	],
	&"hospice": [
		{"cat": "alchemy", "rule": &"on", "n": [2, 3], "room": "dispensary", "opt": 1.0},
	],
	&"school": [
		{"cat": "lectern", "rule": &"free", "n": [1, 1], "room": "schoolroom", "opt": 1.0},
	],
	&"thieves_den": [
		{"cat": "bookcase", "rule": &"wall", "n": [1, 1], "room": "store", "opt": 1.0},
	],
	# 1.0 like every other trade's own fitting: the shop archetype asks for a
	# tailor's sacks by name, and a defining fitting placed on a dice roll is a
	# tailor with nothing in it one time in five.
	# a tailor cuts at a table under a rack of cloth with the shelf of the
	# sales floor behind; a carpenter works at his bench with a rack of tools
	# over it and a bench to saw on (LAY-009)
	&"tavern": [{"cat": "barrel", "rule": &"corner", "n": [1, 2], "opt": 1.0}],
	&"tailor": [
		{"cat": "rack", "rule": &"mounted", "n": [1, 1], "opt": 1.0},
		{"cat": "shelf", "rule": &"mounted", "n": [1, 1], "opt": 1.0},
		{"cat": "sack", "rule": &"corner", "n": [1, 2], "opt": 1.0},
		{"cat": "sack", "rule": &"corner", "n": [1, 1], "opt": 1.0, "room": "workshop"},
	],
	&"carpenter": [
		{"cat": "rack", "rule": &"mounted", "n": [1, 1], "opt": 1.0},
		# against a wall, out of the customer's place and out of the doorways:
		# a 2.8 m trestle standing free cut the workshop in two (shoptrade)
		{"cat": "bench", "rule": &"wall", "n": [1, 1], "opt": 1.0,
			"clear_of_serving": true},
		{"cat": "crate", "rule": &"corner", "n": [1, 2], "opt": 0.9},
	],
}

## Another trade's sign: a piece kept off the floors a shop works and sells on
## (its front room and its workshop) unless the trade is one of these. A rack
## of bottles reads as the apothecary, a sword as the smith, a crate of apples
## or carrots as the grocer: on a butcher's or a tailor's floor each made the
## shop read as some other trade (shoptrade identity, LIVE-SHOPS).
const SHOP_FOREIGN_SIGNS := {
	"Shelf_Small_Bottles": [&"apothecary", &"general_store"],
	"Sword_Bronze": [&"blacksmith"],
	"FarmCrate_Apple": [&"general_store", &"bakery"],
	"FarmCrate_Carrot": [&"general_store", &"bakery"],
	"Barrel_Apples": [&"general_store", &"bakery"],
}
## The trades the signs are kept apart for; every other building draws freely.
const SHOP_SIGN_TRADES: Array[StringName] = [&"bakery", &"butcher", &"apothecary",
	&"general_store", &"tailor", &"carpenter", &"blacksmith"]


## The keys a shop room may draw for a category: the choices less another
## trade's sign, on the floors where the trade is seen. Unchanged for every
## other building, and never emptied.
static func shop_key_choices(plan: HousePlan, room: int, choices: Array[String]) -> Array[String]:
	if not plan.spec is ShopSpec:
		return choices
	var business: StringName = (plan.spec as ShopSpec).business
	if not business in SHOP_SIGN_TRADES:
		return choices
	if room != plan.entrance_room() and plan.kind_of(room) != &"workshop":
		return choices
	var out: Array[String] = []
	for key in choices:
		if not SHOP_FOREIGN_SIGNS.has(key) or (SHOP_FOREIGN_SIGNS[key] as Array).has(business):
			out.append(key)
	return out if not out.is_empty() else choices


## Where the customer stands at a shop's focus piece, and the sawyer must not:
## a fitting marked `clear_of_serving` is placed with the strip before the
## focus piece's door-facing side borrowed as blocked. The carpenter's 2.8 m saw
## bench stood with its end 0.44 m from the customer's place at the workbench
## (shoptrade carpenter 11x15 seed 1); 0.55 m of stance plus the sawyer's 0.6 m
## is 1.15.
const SERVING_CLEAR := 1.2
## How far past every door approach (already 0.3 m to each side of the leaf) a
## step marked `clear_of_doors` keeps its piece: two benches flanking the
## carpenter's 1.2 m street door left 0.16 m between their workers (shoptrade
## carpenter 14x18 seed 1). 0.15 m more leaves ~0.9 m between two 0.6 m work
## stances, over PATH_MIN; 0.6 m pushed the sarchetype smithy's bench onto a
## blind wall (workbench_daylight).
const WORK_STANCE_CLEAR := 0.15


## Borrow the shop clearances a step asks for into `blocked`; returns how many
## rectangles were borrowed (the caller gives them back with its other
## borrowed blocks). Nothing for a step that asks for none.
static func borrow_serving_place(plan: HousePlan, room: int, step: Dictionary,
		blocked: Array[Rect2]) -> int:
	var n := 0
	if bool(step.get("clear_of_doors", false)):
		for d in plan.doors_of(room):
			for approach in HouseFurnishPlacement.door_approach_rects(plan.doors[d]):
				blocked.append(Rect2(approach).grow(WORK_STANCE_CLEAR))
				n += 1
	if not bool(step.get("clear_of_serving", false)) or plan.focus_room() != room:
		return n
	var door := plan.entrance()
	if door < 0:
		return n
	var inside: Vector2 = Vector2(plan.doors[door]["pos"]) \
		- Vector2(plan.doors[door]["normal"]) * (HouseGeometry.wall_thickness(plan.spec) * 0.5 + 0.2)
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(String(p["key"])) != plan.focus_cat() or p.get("mounted", false):
			continue
		# the side the customer comes to: the one nearest the way in
		var r: Rect2 = p["rect"]
		var c := r.get_center()
		var sides := [
			[Vector2(c.x, r.position.y - 0.55), Rect2(r.position.x - 0.3, r.position.y - SERVING_CLEAR, r.size.x + 0.6, SERVING_CLEAR)],
			[Vector2(c.x, r.end.y + 0.55), Rect2(r.position.x - 0.3, r.end.y, r.size.x + 0.6, SERVING_CLEAR)],
			[Vector2(r.position.x - 0.55, c.y), Rect2(r.position.x - SERVING_CLEAR, r.position.y - 0.3, SERVING_CLEAR, r.size.y + 0.6)],
			[Vector2(r.end.x + 0.55, c.y), Rect2(r.end.x, r.position.y - 0.3, SERVING_CLEAR, r.size.y + 0.6)],
		]
		var best: Rect2 = sides[0][1]
		var best_d := INF
		for side in sides:
			var d2: float = Vector2(side[0]).distance_to(inside)
			if d2 < best_d:
				best_d = d2
				best = side[1]
		blocked.append(best)
		return n + 1
	return n


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

