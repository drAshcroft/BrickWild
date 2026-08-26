class_name HouseSpec
extends RefCounted
## One dwelling. User-locked inputs (footprint, wall height, style, trade) are
## stored verbatim; everything else is derived from `seed`, so a variant is
## reproducible from the four things a person actually chose.
##
## A house is not a church or a castle: the interesting part is not the massing
## but what is INSIDE it, so the spec carries a room program and a trade rather
## than a list of towers.

var seed: int
var rng: RandomNumberGenerator

# ---- user-specified (never randomized) ----
var style: StringName = &"cottage"
var trade: StringName = &"none"   # what the household does for a living
var width: float = 8.0            # X, metres, outside face to outside face
var length: float = 10.0          # Z
var height: float = 2.6           # floor to ceiling

# ---- derived from seed + style ----
var variant_name: String
var room_count: int
var program: Array[StringName]    # the kinds the planner must fit, in priority order
var roof_pitch: float
var porch: bool
var chimney: bool
var back_door: bool
var wall_color: Color
var trim_color: Color
var roof_color: Color
var floor_color: Color
var window_shutters: bool
var clutter: float                # 0..1, how heavily rooms get dressed

## Trades a fantasy household might practise, and the workshop fittings each
## one asks for. `room` is the extra room kind the trade needs; the recipes
## themselves live in HouseFurnisher.
const TRADES := {
	&"none": {"label": "Household", "room": &"", "extra": []},
	&"smith": {"label": "Smith", "room": &"workshop", "extra": ["anvil", "workbench"]},
	&"alchemist": {"label": "Alchemist", "room": &"workshop", "extra": ["workbench", "bookcase"]},
	&"farmer": {"label": "Farmer", "room": &"store", "extra": ["barrel", "crate"]},
	&"innkeeper": {"label": "Innkeeper", "room": &"parlour", "extra": ["table", "bench"]},
	&"scholar": {"label": "Scholar", "room": &"parlour", "extra": ["bookcase", "lectern"]},
}

const STYLES := {
	&"cottage": {
		"label": "Cottage",
		"roof_pitch": [0.85, 1.2], "porch": 0.5, "chimney": 0.9, "shutters": 0.7,
		"wall": ["e6ddc8", "cfc3a8"], "trim": ["6b5236", "4a3826"],
		"roof": ["6a4a34", "4e3626"], "floor": ["8a7a5e", "6f6148"],
		"clutter": [0.5, 0.8],
	},
	&"farmhouse": {
		"label": "Farmhouse",
		"roof_pitch": [0.7, 1.0], "porch": 0.7, "chimney": 0.95, "shutters": 0.5,
		"wall": ["d9d2bd", "bcb49c"], "trim": ["7a6242", "56452e"],
		"roof": ["7b6a4a", "5c4e35"], "floor": ["7d6f56", "615641"],
		"clutter": [0.6, 0.95],
	},
	&"townhouse": {
		"label": "Townhouse",
		"roof_pitch": [1.0, 1.4], "porch": 0.2, "chimney": 1.0, "shutters": 0.35,
		"wall": ["cfc9bd", "b3ac9e"], "trim": ["4b4238", "342e28"],
		"roof": ["4a4f57", "353a41"], "floor": ["8e7f63", "6b5f49"],
		"clutter": [0.35, 0.6],
	},
	&"longhall": {
		"label": "Long Hall",
		"roof_pitch": [0.9, 1.25], "porch": 0.35, "chimney": 0.8, "shutters": 0.3,
		"wall": ["c9b899", "ab9877"], "trim": ["5a4429", "3e2f1d"],
		"roof": ["50412c", "39301f"], "floor": ["7a6a4f", "5b4f3a"],
		"clutter": [0.5, 0.85],
	},
	&"witch_hut": {
		"label": "Witch's Hut",
		"roof_pitch": [1.2, 1.7], "porch": 0.25, "chimney": 1.0, "shutters": 0.6,
		"wall": ["b6b2a0", "938f7e"], "trim": ["46402f", "2e2a1e"],
		"roof": ["3f4a3a", "2c352a"], "floor": ["6c6250", "51493c"],
		"clutter": [0.75, 1.0],
	},
}

## Rooms a house gets as it grows, in the order they are worth adding. The
## planner takes the first `room_count` of these that fit, so a one-room hut is
## a hall and a large house works its way down the list.
const PROGRAM := [&"hall", &"bedroom", &"kitchen", &"bedroom", &"store", &"parlour"]

## Floor area, in square metres of INTERIOR, per room. A plan that gives every
## room less than this reads as a rabbit hutch, so the room count follows the
## floor area rather than the other way round.
const AREA_PER_ROOM := 15.0


## How many rooms an interior of this size can carry.
static func rooms_for(interior_area: float) -> int:
	return clampi(int(interior_area / AREA_PER_ROOM), 1, 6)


func _init(p_seed := 0) -> void:
	seed = p_seed
	rng = RandomNumberGenerator.new()
	rng.seed = seed
