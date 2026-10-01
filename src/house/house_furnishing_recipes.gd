class_name HouseFurnishingRecipes
extends RefCounted
## Room, shop and trade recipes consumed by HouseFurnisher.

const RUG_ROOM_KINDS := [&"hall", &"parlour", &"dining", &"dining_room"]

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
