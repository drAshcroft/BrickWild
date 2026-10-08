class_name HouseFurnishingRecipes
extends RefCounted
## Room, shop and trade recipes consumed by HouseFurnisher.

const BASE_HOUSE_SPEC := preload("res://src/house/house_spec.gd")
const DOMESTIC_TABLE_MIN_HEIGHT := 0.70
const DOMESTIC_PREP_MIN_HEIGHT := 0.75

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
	var domestic_functions: Array = plan.rooms[room].get("domestic_functions", [])
	var shared_cooking: bool = kind == &"hall" and domestic_functions.has(&"cooking")
	# A no-trade Witch's Hut has a real craft room. This is a style-local
	# overlay; the alchemist trade and every non-witch workshop keep their own
	# existing recipes.
	if kind == &"workshop" and plan.spec.style == &"witch_hut" \
			and plan.spec.trade == &"none":
		for step_variant in recipe:
			var step: Dictionary = step_variant
			if String(step.get("cat", "")) == "workbench":
				step["group"] = "witchwork"
				step["opt"] = 1.0
			elif String(step.get("cat", "")) == "shelf":
				step["group"] = "witchwork"
				step["opt"] = 1.0
			elif String(step.get("cat", "")) == "sconce":
				step["group"] = "witchwork"
				step["opt"] = 1.0
		recipe.append_array([
			{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0, "group": "witchwork"},
			{"cat": "alchemy", "rule": &"on", "host": "distributed", "n": [2, 2], "opt": 1.0, "group": "witchwork"},
			{"cat": "books", "rule": &"on", "host_category": "workbench", "n": [1, 1], "opt": 1.0, "group": "witchwork"},
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
		tagged.append(step)
	if kind == &"kitchen":
		var prep_pair: Array = [
			{"cat": "workbench", "rule": &"beside", "near_cat": "storage", "align_back": true, "n": [1, 1], "opt": 1.0, "group": "cooking"},
			{"cat": "bucket", "rule": &"beside", "near_cat": "storage", "align_back": true, "n": [1, 1], "opt": 1.0, "group": "cooking"},
		]
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
	if shared_cooking:
		var cooking_core: Array = [
			{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0, "group": "cooking"},
			{"cat": "storage", "rule": &"wall", "n": [1, 1], "opt": 1.0, "group": "cooking"},
			{"cat": "workbench", "rule": &"beside", "near_cat": "storage", "align_back": true, "n": [1, 1], "opt": 1.0, "group": "cooking"},
			{"cat": "bucket", "rule": &"beside", "near_cat": "storage", "align_back": true, "n": [1, 1], "opt": 1.0, "group": "cooking"},
			{"cat": "cookware", "rule": &"on", "host_category": "workbench", "n": [1, 1], "opt": 1.0, "group": "cooking"},
		]
		var without_duplicate_kitchen_storage: Array = []
		for step in tagged:
			if String(step.get("cat", "")) == "storage":
				continue # cooking_core already supplied the household's store
			without_duplicate_kitchen_storage.append(step)
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
		{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "anvil", "rule": &"free", "n": [1, 1], "opt": 1.0},
	],
	&"bakery": [{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0}],
	&"butcher": [{"cat": "blade", "rule": &"on", "n": [1, 2], "opt": 1.0}],
	&"apothecary": [{"cat": "alchemy", "rule": &"on", "n": [2, 4], "opt": 1.0}],
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
	],
	&"carpenter": [
		{"cat": "rack", "rule": &"mounted", "n": [1, 1], "opt": 1.0},
		{"cat": "bench", "rule": &"free", "n": [1, 1], "opt": 1.0},
		{"cat": "crate", "rule": &"corner", "n": [1, 2], "opt": 0.9},
	],
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
