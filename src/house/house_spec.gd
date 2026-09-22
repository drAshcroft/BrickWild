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
var storeys: int = 1              # stacked floors, 1..3; height is per storey
var cellars: int = 0              # storeys dug below the ground, 0..1 (INT-016)

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
var timber_frame: bool            # exposed beams on the outside walls
var stud_pitch: float             # metres between studs; smaller is grander
var frame_braces: bool            # diagonal braces across the corners
var frame_rail: bool              # a mid rail at sill height
var clutter: float                # 0..1, how heavily rooms get dressed

# ---- exterior architectural variety ----
var plinth_height: float = 0.45   # masonry foundation dwarf wall height
var stone_ground_floor: bool = false # entire ground level is stone masonry
var jetty: bool = false           # whether upper storeys overhang the lower storey
var jetty_depth: float = 0.28     # cantilever overhang depth in metres
var roof_type: StringName = &"gable" # &"gable", &"half_hipped", &"hipped"
var dormers: bool = false         # dormer windows on roof slope
var dormer_count: int = 0         # number of dormers
var framing_pattern: StringName = &"close_studding" # &"close_studding", &"square_panel", &"saltire", &"arch_brace"
var gable_truss: StringName = &"king_post" # &"king_post", &"queen_post", &"collar_strut"
var bargeboards: bool = true      # decorative verge boards along gables
var window_mullions: bool = true  # vertical timber bars dividing windows
var window_hoods: bool = false    # dripstone hood mouldings over window heads
var chimney_style: StringName = &"stepped" # &"stepped", &"straight", &"louver"
var chimney_pots: int = 1         # terracotta flue pots at the crown
var exterior_props: bool = true   # rain barrels, firewood, trade signs
## Chosen before planning, so clear floor, openings and emitted masonry agree.
var material: StringName = &"timber" # timber | stone
## Optional explicit masonry thickness for non-house shells.  Castle plans
## carry their measured shell thickness here; the negative value preserves the
## historical material-derived default for ordinary houses.
var wall_thickness_override: float = -1.0

## Styles carry their own timber: `timber` is the chance of an exposed frame at
## all, `studs` the spacing between uprights (a town house is close-studded,
## which was expensive and meant to look it), `braces` the chance of diagonals
## across the corners and `rail` of a mid rail at sill height.

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
		"timber": 0.95, "studs": [0.95, 1.5], "braces": 0.8, "rail": 0.5,
		"roof_pitch": [0.85, 1.2], "porch": 0.5, "chimney": 0.9, "shutters": 0.7,
		"wall": ["e6ddc8", "cfc3a8"], "trim": ["6b5236", "4a3826"],
		"roof": ["6a4a34", "4e3626"], "floor": ["8a7a5e", "6f6148"],
		"clutter": [0.5, 0.8],
		"plinth": [0.35, 0.55], "roof_types": [&"gable", &"half_hipped"],
		"framing": [&"square_panel", &"arch_brace"], "truss": [&"king_post", &"collar_strut"],
		"jetty": 0.3, "dormers": 0.35, "bargeboards": 0.85, "stone_ground": 0.1,
		"chimney_style": &"stepped", "pots": [1, 1],
	},
	&"farmhouse": {
		"label": "Farmhouse",
		"timber": 0.9, "studs": [1.1, 1.7], "braces": 0.85, "rail": 0.4,
		"roof_pitch": [0.7, 1.0], "porch": 0.7, "chimney": 0.95, "shutters": 0.5,
		"wall": ["d9d2bd", "bcb49c"], "trim": ["7a6242", "56452e"],
		"roof": ["7b6a4a", "5c4e35"], "floor": ["7d6f56", "615641"],
		"clutter": [0.6, 0.95],
		"plinth": [0.35, 0.6], "roof_types": [&"half_hipped", &"gable", &"hipped"],
		"framing": [&"square_panel", &"arch_brace"], "truss": [&"collar_strut", &"king_post"],
		"jetty": 0.4, "dormers": 0.4, "bargeboards": 0.8, "stone_ground": 0.15,
		"chimney_style": &"stepped", "pots": [1, 2],
	},
	&"townhouse": {
		"label": "Townhouse",
		"timber": 1.0, "studs": [0.45, 0.7], "braces": 0.3, "rail": 0.9,
		"roof_pitch": [1.0, 1.4], "porch": 0.2, "chimney": 1.0, "shutters": 0.35,
		"wall": ["cfc9bd", "b3ac9e"], "trim": ["4b4238", "342e28"],
		"roof": ["4a4f57", "353a41"], "floor": ["8e7f63", "6b5f49"],
		"clutter": [0.35, 0.6],
		"plinth": [0.45, 0.75], "roof_types": [&"gable", &"half_hipped"],
		"framing": [&"close_studding", &"saltire"], "truss": [&"queen_post", &"collar_strut"],
		"jetty": 0.9, "dormers": 0.6, "bargeboards": 0.95, "stone_ground": 0.35,
		"chimney_style": &"stepped", "pots": [1, 2],
	},
	&"longhall": {
		"label": "Long Hall",
		"timber": 0.85, "studs": [1.0, 1.6], "braces": 0.9, "rail": 0.35,
		"roof_pitch": [0.9, 1.25], "porch": 0.35, "chimney": 0.8, "shutters": 0.3,
		"wall": ["c9b899", "ab9877"], "trim": ["5a4429", "3e2f1d"],
		"roof": ["50412c", "39301f"], "floor": ["7a6a4f", "5b4f3a"],
		"clutter": [0.5, 0.85],
		"plinth": [0.4, 0.65], "roof_types": [&"gable", &"half_hipped"],
		"framing": [&"arch_brace", &"square_panel"], "truss": [&"queen_post", &"king_post"],
		"jetty": 0.3, "dormers": 0.3, "bargeboards": 0.9, "stone_ground": 0.2,
		"chimney_style": &"stepped", "pots": [1, 2],
	},
	&"witch_hut": {
		"label": "Witch's Hut",
		"timber": 0.8, "studs": [0.8, 1.4], "braces": 0.6, "rail": 0.5,
		"roof_pitch": [1.2, 1.7], "porch": 0.25, "chimney": 1.0, "shutters": 0.6,
		"wall": ["b6b2a0", "938f7e"], "trim": ["46402f", "2e2a1e"],
		"roof": ["3f4a3a", "2c352a"], "floor": ["6c6250", "51493c"],
		"clutter": [0.75, 1.0],
		"plinth": [0.25, 0.45], "roof_types": [&"gable"],
		"framing": [&"arch_brace", &"square_panel"], "truss": [&"king_post"],
		"jetty": 0.2, "dormers": 0.2, "bargeboards": 0.6, "stone_ground": 0.05,
		"chimney_style": &"stepped", "pots": [1, 1],
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


## The lowest storey index: -cellars. Storeys run lowest_storey() .. storeys - 1.
func lowest_storey() -> int:
	return -maxi(cellars, 0)


## Every storey index, lowest first.
func storey_indices() -> Array[int]:
	var out: Array[int] = []
	for s in range(lowest_storey(), maxi(storeys, 1)):
		out.append(s)
	return out


## The width of the front door leaf. A dwelling's is HouseGeometry.DOOR_W;
## a shop's depends on what comes through it (ShopSpec.door_w, LAY-009).
func front_door_width() -> float:
	return HouseGeometry.DOOR_W


## How many rooms an interior of this size can carry.
static func rooms_for(interior_area: float) -> int:
	return clampi(int(interior_area / AREA_PER_ROOM), 1, 6)


func _init(p_seed := 0) -> void:
	seed = p_seed
	rng = RandomNumberGenerator.new()
	rng.seed = seed
