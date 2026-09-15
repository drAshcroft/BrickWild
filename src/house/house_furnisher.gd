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
	# the forge first, on the chimney wall the planner chose, and the anvil
	# beside it (its affinity says so) facing the door (the plan's focus)
	&"blacksmith": [
		{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0},
		{"cat": "anvil", "rule": &"free", "n": [1, 1], "opt": 1.0},
	],
	&"bakery": [{"cat": "hearth", "rule": &"wall", "n": [1, 1], "opt": 1.0}],
	&"butcher": [{"cat": "blade", "rule": &"on", "n": [1, 2], "opt": 1.0}],
	&"apothecary": [{"cat": "alchemy", "rule": &"on", "n": [2, 4], "opt": 1.0}],
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

## Pieces that must have a wall behind them, whatever the room looks like: a
## bed in the middle of the floor is not a bed that ran out of options, it is a
## mistake. Everything else may stand free if no wall will take it.
const WALL_ESSENTIAL := ["bed", "hearth", "bookcase", "nightstand", "chest"]

## Step along a wall when hunting for somewhere to put a piece.
const PROBE_STEP := 0.12
## And the most probe positions any one search takes along a line or across a
## floor. Below about fifteen metres it never binds, which is every room in a
## house -- but a castle great hall is sixty metres across, and at 12 cm that
## is five hundred offsets on one wall and a quarter of a million across the
## floor, for an answer that stopped changing after the first few dozen. Past
## the cap the SPACING opens up; nothing a house is measured on changes.
const MAX_PROBES := 128
## How many pieces the repair pass may remove before it gives up and lets the
## checks report the house as it stands.
const MAX_REPAIRS := 8
## How many removals it tries per pass. The list is biggest-first, and the
## thing blocking a doorway is nearly always one of the big ones.
const MAX_TRIALS := 8
## Whether the piece being placed right now is one the room cannot do without.
## Carried on the placement so the repair pass knows what it may not remove.
static var _mandatory := false
## The outline of the room being furnished, when it has one that a rectangle
## cannot say (GEO-002). Carried here rather than threaded through seven
## placers, the same way `_mandatory` is: every one of them already tests
## `_fits`, and this is one more thing `_fits` has to be true of. Empty for a
## rectangular room, which is every room in a house.
static var _outline := PackedVector2Array()
## Sizes a shrinkable piece is tried at, biggest first: a smaller table is a
## compromise, not a preference.
const SCALE_STEPS := [1.0, 0.88, 0.76, 0.62]
## How much of a room a piece has to span before the gap left beside it counts
## as the only way past rather than as somewhere to step round.
const BAR_FRACTION := 0.55

# ---- affinity: how strongly a piece's wishes outweigh a coin toss ----
## The dice are the last word only between placements the rules cannot tell
## apart. Before LAY-002 the jitter was 0.5 against a 0.6 centring term, which
## is not a tie-break, it is the decision.
const JITTER := 0.1
## Beyond this many metres "near" and "far" stop caring.
const AFF_REACH := 4.0
const NEAR_W := 2.0
const FAR_W := 2.0
## Clutter out of the traffic. Softened rather than clamped, so that of four
## corners the one furthest from every door always scores highest.
const DOOR_W := 4.0
const DOOR_SOFT := 3.0
const DAYLIGHT_W := 2.5
## How hard a daylit piece is pushed along the wall to stand beside the window
## rather than square across it, and over what distance.
const BESIDE_W := 1.5
const BESIDE_REACH := 1.5
## The penalty for a wall a piece asked not to be on -- big enough that any
## other wall wins, small enough that the piece still goes in if none does.
const WRONG_WALL := 3.0
## How close a back has to be to a wall to count as standing against it.
const BACK_TOL := 0.14
## A table draws up to the fire: it stands off the middle of the room toward
## the hearth wall by this fraction of the room's half-depth, and wants no
## more than that -- a table in the fireplace is not a table by the fire.
const FOCUS_W := 6.0
const FOCUS_WANT := 0.36
## A shelf over the bench it serves; a chandelier over the table.
const OVER_W := 5.0
## A pair of sconces, mirrored about the door or the fire.
const FLANK_W := 6.0
const FLANK_IDEAL := 0.9
## Wall a pair needs either side of what it flanks: the lamp's own half width
## and the clearance _on_opening() keeps around a door, with a little over.
const FLANK_REACH := 1.5
const FLANK_TOL := 0.6
## Step along a wall when hunting for somewhere to hang something. Finer than
## PROBE_STEP because the mirror of a sconce is judged in centimetres.
const MOUNT_STEP := 0.06
## The focus piece is pinned to HousePlan.focus: it loses this much per metre
## it stands from the point the planner chose, which beats the wall-middle
## term and the jitter within a hand's breadth. A piece that must look at the
## door is pushed to face it by FACE_W; a table in the focus room is pushed to
## lie broadside to the focus by the same weight. (INT-002)
const PIN_W := 4.0
## How far either side of the pin a pinned piece is searched for.
const PIN_SEARCH := 0.9
const FACE_W := 6.0
## How far off the planner's point the focus piece may stand and still count
## as being there. HouseFurnishCheck measures with the same figure.
const FOCUS_TOL := 0.3


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
	# Whatever stands ON the piece goes with it, the way _reindex_hosts() takes
	# it when the removal is real. Asking "would taking the table out help?"
	# with the bench still drawn up to it answers no every time, which is how a
	# parlour cut in half by a table and its bench survived every repair pass.
	var doomed: Array[int] = _hosted_by(plan, f)
	doomed.append(f)
	doomed.sort()
	for k in range(doomed.size() - 1, -1, -1):
		trial.furniture.remove_at(doomed[k])
	return trial


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

	_outline = plan.outline_of(room) if plan.is_polygonal(room) \
		else PackedVector2Array()
	var blocked: Array[Rect2] = _initial_blocked(plan, room)
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
		var must: bool = float(step["opt"]) >= 1.0
		if not must and r.randf() > float(step["opt"]) * lerpf(0.75, 1.15, spec.clutter):
			continue
		_mandatory = must
		if step["rule"] == &"row":
			_place_row(plan, room, step, blocked, zones, r)
			continue
		var lo: int = int(step["n"][0])
		var hi: int = int(step["n"][1])
		var want: int = lo if hi <= lo else r.randi_range(lo, hi)
		var seats_before: int = _count_cat(plan, room, ["seat", "bench"])
		for k in range(want):
			_place_one(plan, spec, room, String(step["cat"]), step["rule"],
				blocked, zones, r, step)
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
		if plan.focus_room() == room and plan.focus_cat() == "table" 				and Rect2(p["rect"]).get_center().distance_to(plan.focus_pos()) 					< FOCUS_TOL:
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
	probe.hearth = plan.hearth
	probe.focus = plan.focus.duplicate()
	probe.furniture = []
	var r := RandomNumberGenerator.new()
	r.seed = 1
	var blocked: Array[Rect2] = _initial_blocked(probe, room)
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
static func _window_blocks(plan: HousePlan, room: int, key: String) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if PropCatalog.height(key) <= HouseGeometry.WINDOW_SILL:
		return out
	for w in plan.windows_of(room):
		out.append(HouseGeometry.window_clear_rect(plan.windows[w]))
	return out


static func _place_one(plan: HousePlan, spec: HouseSpec, room: int, cat: String,
		rule: StringName, blocked: Array[Rect2], zones: Array[Rect2],
		r: RandomNumberGenerator, step: Dictionary = {}) -> void:
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
			elif plan.furniture.size() == had and _forced_wall(plan, room, key) >= 0:
				# the wall the flue rises on would not take it, and a fire
				# under no chimney is worse than no fire: the room goes
				# without and writes down that it did
				plan.note_compromise(room, cat)
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
			_place_around(plan, room, key, blocked, zones, r,
				String(step.get("host", "")) == "row")
		&"behind":
			_place_behind(plan, room, key, blocked, zones, r)
		&"mounted":
			_place_mounted(plan, room, key, r)
		&"ceiling":
			_place_ceiling(plan, room, key)
		&"on":
			_place_on_surface(plan, room, key, r)
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
	if _mandatory and plan.furniture.size() == before_place \
			and _has_other_must(plan, room):
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
	var hearth_only: int = _forced_wall(plan, room, key)
	for wi in range(walls.size()):
		var wall: Dictionary = walls[wi]
		var n: Vector2 = wall["normal"]
		var yaw: float = _yaw_facing(n)
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
		var bed_on_facet := _outline.size() >= 3 and PropCatalog.category(key) == "bed" \
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
			for sc in _scales(key):
				for zs in [1.0, -1.0]:
					var try_cand: Dictionary = _candidate(key, centre, yaw, zs, sc)
					if _fits(try_cand, floor_rect, blocked, zones, extra):
						cand = try_cand
						break
					if bed_on_facet:
						# A short polygon facet can hold the bed while the access
						# strip beside its head clips the next corner. Try a small
						# setback within the existing headboard-to-wall limit;
						# the footprint and use zone must both stay on real floor.
						for inset_step in range(1, 4):
							var inset := HouseGeometry.BED_HEAD_TOL * float(inset_step) / 3.0
							try_cand = _candidate(key, centre + n * inset, yaw, zs, sc)
							if _fits(try_cand, floor_rect, blocked, zones, extra):
								cand = try_cand
								break
						if not cand.is_empty():
							break
				if not cand.is_empty():
					break
			if cand.is_empty():
				continue
			var mid: float = 1.0 - absf(t - run / 2.0) / maxf(run / 2.0, 0.01)
			var score: float = mid * 0.6 + r.randf() * JITTER + float(wi) * 0.01
			score += _affinity(plan, room, cand)
			var placed: Vector3 = cand.pos
			score -= Vector2(placed.x, placed.z).distance_to(centre)
			if hearth_only >= 0 and wi != hearth_only:
				# the flue rises on one wall only, so a hearth on any other is
				# not a worse placement but no placement at all
				score = -INF
			if score > best_score:
				best_score = score
				best = cand
	_commit(plan, room, best, blocked, zones)


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
static func _place_row(plan: HousePlan, room: int, step: Dictionary,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator) -> void:
	var cat: String = String(step["cat"])
	var choices: Array[String] = PropCatalog.of_category(cat)
	if choices.is_empty():
		return
	var key: String = choices[r.randi_range(0, choices.size() - 1)]
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
	for sc in _scales(key):
		for wi in range(lines.size()):
			var wall: Dictionary = lines[wi]
			var n: Vector2 = wall["normal"]
			var yaw: float = _yaw_facing(n)
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
						var cand: Dictionary = _candidate(key, centre, yaw, 1.0, sc)
						# A ROW SHARES ONE AISLE, and that aisle is its use
						# zone -- it is assigned below, once the row is known.
						# The per-piece zone must not be tested here: a seat
						# carries its pull-back space BEHIND it, so a pew
						# backed to a wall has a zone inside the masonry and
						# not one bench of a row would ever fit. Pews in a
						# chapel are the case the row rule was written for
						# (INT-001) and could not do until this line.
						cand["zone"] = Rect2()
						if not _fits(cand, floor_rect, blocked, zones, extra):
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
			var facing: Vector2 = _facing_of(yaw)
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
		_commit(plan, room, cand, blocked, zones)


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


## What a piece WANTS, over and above fitting: one number per candidate
## position, read from the `affinity` block PropCatalog carries per prop.
##
## Before this, every placer ended in "does it fit, plus a random number", and
## the random number was half the score. A dozen rules that anybody would say
## out loud -- the bench goes by the window, the bookcase does not go by the
## fire, the barrels go where nobody walks, the second sconce mirrors the
## first -- are all one expression here, so the placers stay five short
## searches over the positions the room allows.
##
## Pure: the same plan, room and candidate always give the same score. Nothing
## in here draws on an RNG, which is what lets the checks re-derive it.
static func _affinity(plan: HousePlan, room: int, cand: Dictionary) -> float:
	var key: String = String(cand["key"])
	var aff: Dictionary = PropCatalog.affinity(key)
	if aff.is_empty():
		# a counter or a cauldron has no wishes of its own, but it may still
		# be the piece the plan is arranged around
		return _pin_bonus(plan, room, cand)
	var rect: Rect2 = cand["rect"]
	var c: Vector2 = rect.get_center()
	# Only these preferences inspect a wall. Free-standing tables ask about
	# the fire/focus instead, so rebuilding the room floor for every table
	# probe cannot change their score.
	var wall := -1
	if aff.has("daylight") or bool(aff.get("avoid_window_wall", false)) \
			or bool(aff.get("avoid_hearth_wall", false)):
		wall = _back_wall_index(plan, room, rect)
	var score := 0.0

	# daylight: a workbench wants the window wall, a bookcase wants any other
	if aff.has("daylight"):
		var want: float = float(aff["daylight"])
		if wall >= 0:
			if _wall_has_window(plan, room, wall):
				score += want * DAYLIGHT_W
				# Beside the window, not across it. A bench dead in front of
				# the glass has the same light and leaves no wall above it
				# for the shelf that serves it -- worth a nudge along the
				# wall, never worth a different wall.
				if want > 0.0:
					score -= BESIDE_W * _window_crowding(plan, room, rect, wall)
		else:
			var wd: float = _nearest_window_dist(plan, room, c)
			if wd >= 0.0:
				score += want * DAYLIGHT_W * clampf(1.0 - wd / AFF_REACH, 0.0, 1.0)

	for near_cat in aff.get("near", []):
		var nd: float = _nearest_cat_dist(plan, room, String(near_cat), c)
		if nd >= 0.0:
			score += NEAR_W * clampf(1.0 - nd / AFF_REACH, 0.0, 1.0)
	for far_cat in aff.get("far", []):
		var fd: float = _nearest_cat_dist(plan, room, String(far_cat), c)
		if fd >= 0.0:
			score += FAR_W * (fd / (fd + AFF_REACH))

	# Out of the traffic. Softened rather than clamped: of four corners the one
	# furthest from every door has to score strictly highest, however big the
	# room is, or the rule decides nothing in a large one.
	if bool(aff.get("away_from_doors", false)):
		var dd: float = _nearest_door_dist(plan, room, c)
		if dd < INF:
			score += DOOR_W * (dd / (dd + DOOR_SOFT))

	if wall >= 0 and bool(aff.get("avoid_window_wall", false)) \
			and _wall_has_window(plan, room, wall):
		score -= WRONG_WALL
	if wall >= 0 and bool(aff.get("avoid_hearth_wall", false)) \
			and plan.hearth_room() == room and plan.hearth_wall() == wall:
		score -= WRONG_WALL

	if String(aff.get("focus", "")) == "hearth":
		# the placer looks the fire up once for the whole search; a caller
	# scoring a single candidate has not, and pays for it here
		var h := Vector2(INF, INF)
		if cand.has("focus_point"):
			h = cand["focus_point"]
		else:
			h = _hearth_point(plan, room)
		score += _focus_bonus(plan, room, c, h)
	if aff.has("over"):
		score += _over_bonus(plan, room, cand, aff["over"])
	if aff.has("flank"):
		score += _flank_bonus(plan, room, cand)
	if PropCatalog.category(key) == "bed":
		score += _bed_bonus(plan, room, cand)
	if String(aff.get("face", "")) == "focus":
		score += _broadside_bonus(plan, room, rect)
	return score + _pin_bonus(plan, room, cand)


## The focus piece itself: pinned to the point the planner chose, and turned
## to look at the door when the plan says it must. Every other piece scores 0
## here, so this is outside the affinity block -- a hearth has no affinity of
## its own and is still the focus of the room it is in.
static func _pin_bonus(plan: HousePlan, room: int, cand: Dictionary) -> float:
	if plan.focus_room() != room or plan.focus.get("placed", false):
		return 0.0
	if PropCatalog.category(String(cand["key"])) != plan.focus_cat():
		return 0.0
	var rect: Rect2 = cand["rect"]
	var c: Vector2 = rect.get_center()
	var score: float = -PIN_W * c.distance_to(plan.focus_pos())
	if plan.focus_faces_door():
		var door: int = focus_door(plan, room)
		if door >= 0:
			var to: Vector2 = Vector2(plan.doors[door]["pos"]) - c
			if to.length() > 0.01:
				score += FACE_W * _facing_of(float(cand["yaw"])).dot(to.normalized())
	return score


## A table in the focus room lies broadside to the focus: its long axis at
## right angles to the line the focus looks along, so a side of it faces the
## fire. A square table has no long axis and no preference.
static func _broadside_bonus(plan: HousePlan, room: int, rect: Rect2) -> float:
	if plan.focus_room() != room or plan.focus_cat() == "table":
		return 0.0
	if absf(rect.size.x - rect.size.y) < 0.1:
		return 0.0
	var axis := Vector2(1, 0) if rect.size.x > rect.size.y else Vector2(0, 1)
	return FACE_W * (1.0 - absf(axis.dot(_facing_of(plan.focus_facing()))))


## The door the focus is judged against: the front door when it opens into
## this room, else the room's first door, else -1.
static func focus_door(plan: HousePlan, room: int) -> int:
	var e: int = plan.entrance()
	if e >= 0 and int(plan.doors[e]["a"]) == room:
		return e
	var doors: Array[int] = plan.doors_of(room)
	return doors[0] if not doors.is_empty() else -1


## The four walls of a room, in the order HouseGeometry.room_walls() gives
## them, as inward normals.
static func _wall_normal(wi: int) -> Vector2:
	return [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)][wi]


## Which wall a rectangle has its back to, or -1 when it stands free. Measured
## rather than passed in, because _affinity() is handed a candidate and has to
## give the same answer wherever the candidate came from.
static func _back_wall_index(plan: HousePlan, room: int, rect: Rect2) -> int:
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var gaps := [rect.position.y - f.position.y, f.end.y - rect.end.y,
		rect.position.x - f.position.x, f.end.x - rect.end.x]
	var best := -1
	var best_gap := BACK_TOL
	for i in range(4):
		if float(gaps[i]) < best_gap:
			best_gap = float(gaps[i])
			best = i
	return best


## How squarely this piece stands in front of the glass, 1 for dead centre and
## 0 once it is BESIDE_REACH along the wall from it. Continuous rather than a
## yes-or-no: a bench nudged just clear of the window still leaves no room for
## the shelf that serves it, because a shelf is kept a shelf-width off the
## opening as well.
static func _window_crowding(plan: HousePlan, room: int, rect: Rect2,
		wi: int) -> float:
	var n: Vector2 = _wall_normal(wi)
	var along := Vector2(n.y, -n.x).abs()
	var c: float = rect.get_center().dot(along)
	var worst := 0.0
	for w in plan.windows_of(room):
		var win: Dictionary = plan.windows[w]
		if Vector2(win["normal"]).dot(n) > -0.9:
			continue
		var d: float = absf(c - Vector2(win["pos"]).dot(along))
		worst = maxf(worst, clampf(1.0 - d / BESIDE_REACH, 0.0, 1.0))
	return worst


## A window record carries the OUTWARD normal of the wall it pierces, so it
## belongs to the wall whose inward normal is its opposite.
static func _wall_has_window(plan: HousePlan, room: int, wi: int) -> bool:
	var n: Vector2 = _wall_normal(wi)
	for w in plan.windows_of(room):
		if Vector2(plan.windows[w]["normal"]).dot(n) < -0.9:
			return true
	return false


static func _nearest_window_dist(plan: HousePlan, room: int, c: Vector2) -> float:
	var best := -1.0
	for w in plan.windows_of(room):
		var d: float = c.distance_to(Vector2(plan.windows[w]["pos"]))
		if best < 0.0 or d < best:
			best = d
	return best


static func _nearest_door_dist(plan: HousePlan, room: int, c: Vector2) -> float:
	var best := INF
	for d in plan.doors_of(room):
		best = minf(best, c.distance_to(Vector2(plan.doors[d]["pos"])))
	return best


## Distance to the nearest piece of a category standing in this room, or -1
## when the room holds none. The fire is the exception: the planner names its
## wall before any furniture exists, so a bookcase can be kept away from it
## even while the hearth is still only a plan.
static func _nearest_cat_dist(plan: HousePlan, room: int, cat: String,
		c: Vector2) -> float:
	if cat == "focus":
		if plan.focus_room() != room or not plan.focus_pos().is_finite():
			return -1.0
		return c.distance_to(plan.focus_pos())
	var best := -1.0
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) != cat:
			continue
		var d: float = c.distance_to(Rect2(p["rect"]).get_center())
		if best < 0.0 or d < best:
			best = d
	if cat == "hearth" and best < 0.0:
		var h: Vector2 = _hearth_point(plan, room)
		if h.is_finite():
			best = c.distance_to(h)
	return best


## Where the fire in this room is, or an infinite vector when there is none:
## the hearth itself if it has been placed, otherwise the middle of the wall
## the planner gave the chimney.
static func _hearth_point(plan: HousePlan, room: int) -> Vector2:
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) == "hearth":
			return Rect2(p["rect"]).get_center()
	if plan.hearth_room() != room or plan.hearth_wall() < 0:
		return Vector2(INF, INF)
	var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
	var wall: Dictionary = walls[plan.hearth_wall()]
	return (Vector2(wall["from"]) + Vector2(wall["to"])) / 2.0


## A table in a room with a fire in it does not sit in the middle of the room:
## it draws up toward the fire. Rewarded up to FOCUS_WANT of the room's half
## depth and no further, so the table stops where a table would stop.
static func _focus_bonus(plan: HousePlan, room: int, c: Vector2,
		h: Vector2) -> float:
	if not h.is_finite():
		return 0.0
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var mid: Vector2 = f.get_center()
	var dir: Vector2 = h - mid
	if dir.length() < 0.01:
		return 0.0
	dir = dir.normalized()
	var half: float = absf(dir.x) * f.size.x / 2.0 + absf(dir.y) * f.size.y / 2.0
	var want: float = maxf(FOCUS_WANT * half, 0.05)
	return FOCUS_W * clampf((c - mid).dot(dir) / want, 0.0, 1.0)


## Above something: a chandelier over the table it lights, a shelf over the
## bench it serves. The ceiling case is a distance, the wall case is how much
## of the shelf actually overhangs the piece, along the wall they share.
static func _over_bonus(plan: HousePlan, room: int, cand: Dictionary,
		cats: Array) -> float:
	var key: String = String(cand["key"])
	var rect: Rect2 = cand["rect"]
	var c: Vector2 = rect.get_center()
	var hanging: bool = PropCatalog.has_tag(key, PropCatalog.CEILING)
	var wall: int = _back_wall_index(plan, room, rect)
	var n: Vector2 = _wall_normal(wall) if wall >= 0 else Vector2(1, 0)
	var along := Vector2(n.y, -n.x).abs()
	var width: float = maxf(PropCatalog.size(key).x, 0.05)
	var best := 0.0
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if not PropCatalog.category(p["key"]) in cats:
			continue
		if p.get("mounted", false) or int(p["host"]) >= 0:
			continue
		var host: Rect2 = p["rect"]
		if hanging:
			best = maxf(best, clampf(1.0 - c.distance_to(host.get_center()) / 2.0, 0.0, 1.0))
			continue
		if wall < 0 or _back_wall_index(plan, room, host) != wall:
			continue
		var span: float = maxf(host.end.dot(along) - host.position.dot(along), 0.05)
		var lo: float = maxf(c.dot(along) - width / 2.0, host.position.dot(along))
		var hi: float = minf(c.dot(along) + width / 2.0, host.end.dot(along))
		# against the narrower of the two: a shelf half a metre wider than the
		# bench it serves still hangs over the whole of it
		best = maxf(best, clampf((hi - lo) / minf(width, span), 0.0, 1.0))
	return OVER_W * best


## Sconces come in pairs, one either side of the door or the fire. The pair's
## station -- how far out from the centre the two of them hang -- is settled
## once, by _flank_anchor(), so the first lamp cannot take a spot its mate is
## unable to answer. The first is scored on reaching that station and the
## second on mirroring the first, which is what makes the pair read as a pair
## rather than as two lamps that happen to share a wall.
static func _flank_bonus(plan: HousePlan, room: int, cand: Dictionary) -> float:
	var key: String = String(cand["key"])
	var cat: String = PropCatalog.category(key)
	# The widest lamp of the kind, not this one: the two halves of a pair are
	# drawn separately and need not be the same prop, and a station worked out
	# from one width is a station the other cannot answer.
	#
	# The placer hands the anchor in, having found it once for the whole wall
	# search; a caller that has not is given the same answer the slow way.
	# An explicitly empty anchor has already proved no pair station exists.
	var anchor: Dictionary = cand.get("flank_anchor", {})
	if not cand.has("flank_anchor"):
		anchor = _flank_anchor(plan, room, _widest_of(cat), cat)
	if anchor.is_empty():
		return 0.0
	var rect: Rect2 = cand["rect"]
	var wall: int = _flank_wall(plan, room, rect)
	if wall < 0:
		return 0.0
	var n: Vector2 = HouseGeometry.room_walls(plan, room)[wall].normal if plan.is_polygonal(room) else _wall_normal(wall)
	var same_wall_cos := 0.999 if plan.is_polygonal(room) else 0.9
	if n.dot(Vector2(anchor["normal"])) < same_wall_cos:
		return -1.0                  # the pair belongs on the wall the door is in
	var along := Vector2(n.y, -n.x)
	var t: float = (rect.get_center() - Vector2(anchor["pos"])).dot(along)
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if PropCatalog.category(p["key"]) != cat or not p.get("mounted", false):
			continue
		var mate: Rect2 = p["rect"]
		if _flank_wall(plan, room, mate) != wall:
			continue
		# mirrored means the two offsets cancel: same distance, opposite sides
		var t2: float = (mate.get_center() - Vector2(anchor["pos"])).dot(along)
		return FLANK_W * clampf(1.0 - absf(t + t2) / FLANK_TOL, 0.0, 1.0)
	var dist: float = float(anchor.get("dist", FLANK_IDEAL))
	return FLANK_W * 0.5 * clampf(1.0 - absf(absf(t) - dist) / FLANK_TOL, 0.0, 1.0)


static func _flank_wall(plan: HousePlan, room: int, rect: Rect2) -> int:
	if plan.is_polygonal(room):
		return HouseGeometry.backing_wall(plan, room, rect, BACK_TOL)
	return _back_wall_index(plan, room, rect)


## The widest prop of a category, so a rule that has to hold for a pair drawn
## from it does not depend on which of them was drawn first.
static func _widest_of(cat: String) -> float:
	var w := 0.05
	for k in PropCatalog.of_category(cat):
		w = maxf(w, PropCatalog.size(k).x)
	return w


## What a pair of sconces is arranged about, and how far out the two of them
## stand: the fire if the room has one, otherwise a door, and failing both the
## middle of a wall -- a room whose only door is jammed into a corner has no
## symmetry to hang a pair about, and two lamps evenly set out on one wall
## still read as a pair where two lamps dropped wherever they fit do not.
##
## An anchor is only taken if BOTH stations are real wall: inside the room and
## clear of every other opening. Skipping that test is how one lamp ended up
## an arm's length from the door and its mate a metre and a half the other
## way, on the far side of a second doorway.
static func _flank_anchor(plan: HousePlan, room: int, width: float,
		cat: String) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	for i in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[i]
		if PropCatalog.category(p["key"]) != "hearth":
			continue
		var wi: int = _flank_wall(plan, room, Rect2(p["rect"]))
		if wi < 0:
			continue
		var n: Vector2 = HouseGeometry.room_walls(plan, room)[wi].normal if plan.is_polygonal(room) else _wall_normal(wi)
		var hc: Vector2 = Rect2(p["rect"]).get_center()
		var q: Vector2 = f.position if wi == 0 or wi == 2 else f.end
		if plan.is_polygonal(room):
			q = HouseGeometry.room_walls(plan, room)[wi].from
		# the point on the wall in line with the fire, so the pair is measured
		# along the wall it hangs on rather than out into the room
		var on_wall: Vector2 = hc + n * ((q - hc).dot(n))
		var reach: float = (absf(n.y) * Rect2(p["rect"]).size.x
			+ absf(n.x) * Rect2(p["rect"]).size.y) / 2.0
		candidates.append({"pos": on_wall, "normal": n, "reach": reach})
	for d in plan.doors_of(room):
		var door: Dictionary = plan.doors[d]
		var dn: Vector2 = door["normal"]
		if (f.get_center() - Vector2(door["pos"])).dot(dn) < 0.0:
			dn = -dn
		candidates.append({"pos": door["pos"], "normal": dn,
			"reach": float(door["width"]) / 2.0})
	var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
	for wi2 in range(walls.size()):
		candidates.append({
			"pos": (Vector2(walls[wi2]["from"]) + Vector2(walls[wi2]["to"])) / 2.0,
			"normal": Vector2(walls[wi2]["normal"]), "reach": 0.0,
		})
	for cand in candidates:
		var dist: float = _flank_station(plan, room, cand, width, cat)
		if dist > 0.0:
			cand["dist"] = dist
			return cand
	return {}


## How far either side of an anchor a pair can actually hang, or 0 when it
## cannot. Nearest first: a pair belongs close about what it flanks.
static func _flank_station(plan: HousePlan, room: int, anchor: Dictionary,
		width: float, cat: String) -> float:
	var f: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var n: Vector2 = anchor["normal"]
	var pos: Vector2 = anchor["pos"]
	var along := Vector2(n.y, -n.x)
	var axis := along.abs()
	var lo: float = f.position.dot(axis) + width / 2.0 + 0.2
	var hi: float = f.end.dot(axis) - width / 2.0 - 0.2
	var t: float = pos.dot(axis)
	var first: float = maxf(float(anchor["reach"]) + width / 2.0 + 0.2, FLANK_IDEAL)
	var d: float = first
	var host := {}
	if plan.is_polygonal(room):
		for wall in HouseGeometry.room_walls(plan, room):
			if Vector2(wall.normal).dot(n) > 0.999 and absf((pos - Vector2(wall.from)).dot(n)) < 0.05:
				host = wall
				break
		if host.is_empty():
			return 0.0
	while d <= maxf(hi - lo, 0.0):
		var ok := true
		for side in [-1.0, 1.0]:
			var p: Vector2 = pos + along * (d * side)
			if not host.is_empty():
				var edge := Vector2(host.to) - Vector2(host.from)
				var station := (p - Vector2(host.from)).dot(edge.normalized())
				if station < width / 2.0 + 0.2 or station > edge.length() - width / 2.0 - 0.2:
					ok = false
					break
			if (host.is_empty() and (p.dot(axis) < lo or p.dot(axis) > hi)) 					or _on_opening(plan, room, p, n, width) 					or _crowds_mounted(plan, room, p, width, cat):
				# the pair's own half already hanging there does not count
				ok = false
				break
		if ok:
			return d
		d += MOUNT_STEP
	return 0.0


## Feng shui, and common sense: you want to see the door from the bed, but you
## do not want the bed in the doorway. The commanding position is out of the
## line of the door, with the headboard against solid wall -- which is also
## simply where a bed is out of the way. Folded into _affinity() by LAY-002.
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
	# Where the fire is does not change while the table hunts for a spot, and
	# the hunt looks at thousands of spots. Found once here and carried on the
	# candidate; leaving it inside the grid made every table in the sweep walk
	# the room's furniture list a few thousand times.
	var focus: Vector2 = _hearth_point(plan, room)
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
	for yaw in yaws:
		for sc in _scales(key):
			_free_at_scale(plan, room, key, yaw, sc, floor_rect, blocked, zones,
				extra, r, result, focus, pin)
	_commit(plan, room, result["best"], blocked, zones)


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
	return Rect2(at - Vector2.ONE * PIN_SEARCH, Vector2.ONE * PIN_SEARCH * 2.0)


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
	var prototype := _candidate(key, Vector2.ZERO, yaw, 1.0, sc)
	var has_zone := PropCatalog.zone_depth(key) > 0.0
	# A customer can stand in the clear approach to the shop's entrance while
	# using its counter or stall. The piece itself must still clear that door;
	# treating the empty approach as solid furniture forced small stalls to
	# turn their service side away from the customer.
	if plan.focus_room() == room and plan.focus_faces_door() \
			and not plan.focus.get("placed", false) and PropCatalog.category(key) == plan.focus_cat():
		var entry := focus_door(plan, room)
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
				cand["zone"] = _zone_rect(key, cand["rect"], yaw)
			if not _fits(cand, floor_rect, blocked, zones, extra):
				continue
			cand["focus_point"] = focus
			# the middle of the room, at the biggest size that fits there
			var d: float = centre.distance_to(floor_rect.get_center())
			var score: float = -d + r.randf() * JITTER + sc * 4.0 \
				+ _affinity(plan, room, cand)
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
	var extra: Array[Rect2] = _window_blocks(plan, room, key)
	var best: Dictionary = {}
	var best_score := -INF
	# All four corners are scored rather than shuffled: a barrel belongs in
	# the corner nobody walks through, and which one that is depends on
	# where the doors are, not on the roll of a die.
	for ci in range(4):
		var jitter: float = r.randf() * JITTER
		var found: Dictionary = {}
		var slid := 0.0
		# slide out of the corner along both walls until it fits
		for slide in range(6):
			for dir in [Vector2(1, 0), Vector2(0, 1)]:
				var sign_x: float = 1.0 if ci == 0 or ci == 2 else -1.0
				var sign_z: float = 1.0 if ci == 0 or ci == 1 else -1.0
				var off := Vector2(dir.x * sign_x, dir.y * sign_z) * (float(slide) * 0.25)
				var cand: Dictionary = _candidate(key, corners[ci] + off, 0.0)
				if _fits(cand, floor_rect, blocked, zones, extra):
					found = cand
					slid = float(slide)
					break
			if not found.is_empty():
				break
		if found.is_empty():
			continue
		# a piece slid a long way out of the corner is not in the corner
		var score: float = _affinity(plan, room, found) + jitter - slid * 0.05
		if score > best_score:
			best_score = score
			best = found
	_commit(plan, room, best, blocked, zones)


## Seats at a table, facing it, with pull-back space behind them.
static func _place_around(plan: HousePlan, room: int, key: String,
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
			var yaw: float = _yaw_facing(-n)        # face back toward the table
			var foot: Vector2 = PropCatalog.footprint_rotated(key, yaw)
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


## Which piece a seat is drawn up to.
##
## The first one of the right kind, except when the step asks for a row: a
## great hall seats the trestles, not the high table, and among the trestles it
## seats whichever has the fewest people at it already, so a second bench goes
## to the next table rather than crowding the first.
static func _find_host(plan: HousePlan, room: int, cats: Array,
		want_row := false) -> int:
	var pool: Array[int] = []
	for f in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[f]["key"]) in cats:
			pool.append(f)
	if pool.is_empty():
		return -1
	if not want_row:
		return pool[0]
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
	var host: int = _find_host(plan, room, ["table", "workbench", "counter"])
	if host < 0:
		return
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var host_rect: Rect2 = plan.furniture[host]["rect"]
	var hc: Vector2 = host_rect.get_center()
	var yaw: float = float(plan.furniture[host]["yaw"])
	var back: Vector2 = -_facing_of(yaw)          # away from what the host faces
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
		var cand: Dictionary = _candidate(key, centre, yaw)
		if not _fits(cand, floor_rect, blocked, zones, []):
			continue
		# the middle of the table first: that is where the lord sits
		var score: float = r.randf() * 0.2 - absf(t)
		if score > best_score:
			best_score = score
			best = cand
	_commit(plan, room, best, blocked, zones)


# ---------------------------------------------------- wall and ceiling kit

## A shelf, rack or sconce on a wall, above the furniture already there.
static func _place_mounted(plan: HousePlan, room: int, key: String,
		r: RandomNumberGenerator) -> void:
	var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
	var y: float = HouseGeometry.SCONCE_HEIGHT if PropCatalog.category(key) == "sconce" \
		else HouseGeometry.SHELF_HEIGHT
	var width: float = PropCatalog.size(key).x
	# Worked out once, not once per candidate: where a pair of these hangs is
	# a fact about the room, and _flank_anchor() scans the walls to find it.
	# Leaving it inside the scoring loop made the house suites four times as
	# slow for an answer that never changed.
	var anchor: Dictionary = _flank_anchor(plan, room,
		_widest_of(PropCatalog.category(key)), PropCatalog.category(key)) 		if PropCatalog.affinity(key).has("flank") else {}
	var best_pos := Vector2.ZERO
	var best_yaw := 0.0
	var best_score := -INF
	# Every clear stretch of every wall is scored. A shelf wants the wall
	# above the bench it serves and a sconce wants to mirror its mate about
	# the door; neither is findable by trying six positions at random.
	for wi in range(walls.size()):
		var wall: Dictionary = walls[wi]
		var n: Vector2 = wall["normal"]
		var a: Vector2 = wall["from"]
		var b: Vector2 = wall["to"]
		var run: float = (b - a).length()
		var along: Vector2 = (b - a) / maxf(run, 0.01)
		if run < width + 0.4:
			continue
		var lo: float = width / 2.0 + 0.2
		var hi: float = run - width / 2.0 - 0.2
		# Keep the same fixed probe phase as HouseFurnishCheck's availability
		# search. Re-dividing the run into `steps` almost-0.06m intervals can
		# skip a narrow but valid station between two openings (seed 60068 has
		# 4cm of wall where the shelf can cover its workbench).
		var steps: int = maxi(int((hi - lo) / MOUNT_STEP), 0)
		for s in range(steps + 1):
			var t: float = lo + float(s) * MOUNT_STEP
			var pos: Vector2 = a + along * t
			if _on_opening(plan, room, pos, n, width):
				continue
			if _crowds_mounted(plan, room, pos, width):
				continue
			var cand := {
				"key": key, "pos": Vector3(pos.x, 0.0, pos.y),
				"rect": Rect2(pos - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
				"host": -1, "mounted": true, "flank_anchor": anchor,
			}
			var score: float = _affinity(plan, room, cand) + r.randf() * JITTER
			if score > best_score:
				best_score = score
				best_pos = pos
				best_yaw = _yaw_facing(n)
	if best_score == -INF:
		return
	plan.furniture.append({
		"key": key, "room": room, "storey": HousePlan.record_storey(plan.rooms[room]),
		"pos": Vector3(best_pos.x, _storey_base(plan, room) + y, best_pos.y),
		"yaw": best_yaw,
		"rect": Rect2(best_pos - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
		"zone": Rect2(), "host": -1, "cat": PropCatalog.category(key),
		"mounted": true, "scale": 1.0,
	})


## Is something already hanging here? Nothing else on a wall keeps mounted
## pieces apart -- they have no footprint on the floor for _fits() to test --
## and now that every one of them is scored rather than dropped at random, two
## shelves that both want the wall over the bench would hang in one another.
static func _crowds_mounted(plan: HousePlan, room: int, pos: Vector2,
		width: float, ignore_cat := "") -> bool:
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if not p.get("mounted", false):
			continue
		if not ignore_cat.is_empty() and PropCatalog.category(p["key"]) == ignore_cat:
			continue
		var other: float = maxf(PropCatalog.size(p["key"]).x, 0.05)
		var c := Vector2(p["pos"].x, p["pos"].z)
		if c.distance_to(pos) < (width + other) / 2.0 + 0.1:
			return true
	return false


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
	# The middle of the room, unless there is a table to hang over -- which
	# is what a chandelier is for, and is decided by the same scorer as
	# everything else rather than by a special case here.
	var spots: Array[Vector2] = [floor_rect.get_center()]
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if p.get("mounted", false) or int(p["host"]) >= 0:
			continue
		var pc: Vector2 = Rect2(p["rect"]).get_center()
		if floor_rect.grow(0.05).has_point(pc):
			spots.append(pc)
	var c: Vector2 = spots[0]
	var best_score := -INF
	for spot in spots:
		var cand := {
			"key": key, "pos": Vector3(spot.x, 0.0, spot.y),
			"rect": Rect2(spot - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
			"host": -1, "mounted": true,
		}
		var score: float = _affinity(plan, room, cand)
		if score > best_score:
			best_score = score
			c = spot
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
	var foot: Vector2 = PropCatalog.footprint_rotated(key, yaw) * scale
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
	var measured := PropCatalog.footprint_rotated(key, yaw)
	var scale := rect.size.x / maxf(measured.x, 0.001)
	var raw := PropCatalog.footprint(key) * scale
	var out: float = raw.x * 0.5 if cat == "bed" else raw.y * 0.5
	var width: float = raw.y if cat == "bed" else raw.x
	var span := Vector2(dir.y, -dir.x) * width * 0.5
	# Bound all four corners of the rotated strip. Bounding just two opposite
	# corners with an absolute tangent can collapse a diagonal use zone.
	return Poly.bounding_rect(PackedVector2Array([
		c + dir * out - span, c + dir * out + span,
		c + dir * (out + depth) + span, c + dir * (out + depth) - span]))


## Does this candidate fit: inside the room, clear of everything already
## placed, and with its use zone on real floor rather than inside a wall?
static func _fits(cand: Dictionary, floor_rect: Rect2, blocked: Array[Rect2],
		zones: Array[Rect2], extra: Array[Rect2], ignore := Rect2()) -> bool:
	var rect: Rect2 = cand["rect"]
	if not floor_rect.grow(0.01).encloses(rect):
		return false
	# A bounding box is not the room when the room is an octagon: every corner
	# of the piece has to be inside the outline as well, or the wardrobe ends
	# up half through the chamfer.
	if not _inside_outline(rect):
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
		if not _inside_outline(zone):
			return false
		for b2 in blocked:
			if b2 in cand.get("zone_passages", []):
				continue
			if b2.intersects(zone):
				return false
	return true


## Are all four corners of `rect` inside the room being furnished? True when
## the room is a plain rectangle -- the enclosing test above has said so
## already.
static func _inside_outline(rect: Rect2) -> bool:
	if _outline.size() < 3:
		return true
	for p in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]:
		if not Poly.contains_point(_outline, p, 0.01):
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
	# after the placement is accepted, keeping all rectangle logic 2D. A dais
	# is part of that elevation: the high table stands ON the step, and
	# everything in plan still measures as though the step were flat floor.
	pos.y += _storey_base(plan, room)
	if plan.on_dais(room, Vector2(pos.x, pos.z)):
		pos.y += plan.dais_rise()
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
	# And the ways round its ENDS. A table across most of the width of a room
	# is got past at its sides, not behind it, so those are the gaps that have
	# to be walkable -- a parlour with a bench drawn up to such a table is cut
	# in two by 49 cm of floor either side, and every repair pass in the world
	# will not open it again.
	if bars_z:
		gaps.append(rect.position.x - floor_rect.position.x)
		gaps.append(floor_rect.end.x - rect.end.x)
	if bars_x:
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
