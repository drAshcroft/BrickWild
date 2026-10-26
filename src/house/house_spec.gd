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
var roof_material: StringName = &"shingle" # shingle | slate | thatch | earth, derived without extra RNG draws
var dormers: bool = false         # dormer windows on roof slope
var dormer_count: int = 0         # number of dormers
var framing_pattern: StringName = &"close_studding" # &"close_studding", &"square_panel", &"saltire", &"arch_brace"
var gable_truss: StringName = &"king_post" # &"king_post", &"queen_post", &"collar_strut"
var bargeboards: bool = true      # decorative verge boards along gables
var window_mullions: bool = true  # vertical timber bars dividing windows
var window_hoods: bool = false    # dripstone hood mouldings over window heads
var chimney_style: StringName = &"stepped" # &"stepped", &"straight", &"louver"
var chimney_pots: int = 1         # terracotta flue pots at the crown
## ---- rich-house ornament (HOUSE-RICH) ----
## A rich dwelling is the same plan with its storeys ARTICULATED: the bands,
## the crown and the roof are separate pieces you can count, rather than a
## cottage with the height turned up. All four are read from the style row, so
## `rich` is a chance table like every other style and a rich house is still
## reproducible from (style, trade, size, storeys, seed).
var cornice: bool = false        # a projecting crown at the wall head
var string_courses: int = 0      # belt bands at each storey line, 0..2
var pediments: bool = false      # pedimented heads over the upper windows
var ridge_finial: bool = false   # an obelisk crowning the ridge cap
var exterior_props: bool = true   # facade pieces, the yard and its built pieces: the one switch
## Metres of yard round the shell (porch and chimney stack included) that this
## house may dress; the lot owns the rest. Negative means the style's own, 2 to
## 3 m (HouseYard.APRON). Never drawn from `rng`, so it cannot move a plan.
var yard_apron: float = -1.0
## Chosen before planning, so clear floor, openings and emitted masonry agree.
## ---- vernacular exterior culture (HOUSE-CULTURE) ----
## Six dwellings that are not a timber cottage: a whitewashed tile house, a
## stilted timber house under a sweeping roof, a thatched compound house, a
## thatched cottage, a mud hut, and a thick-walled Pueblo adobe house under a
## flat terrace roof. None of them is a European house with the colours changed,
## so each names a PIECE of architecture the six European
## styles never had -- and every switch below is read from the style row
## behind one guard, so the six European rows take no draw and not one
## seeded plan, roof or piece of furniture moves.
var parapet: bool = false          # a wall standing on the roof eave
var veranda: bool = false          # a roofed open platform on the entrance wall
var veranda_depth: float = 1.5     # how far the platform reaches out
var eave_sweep: bool = false       # the eave flicks up at its four corners
var thatch_roll: bool = false      # a combed ridge roll and a thick eave roll
var eyebrows: int = 0              # HS-THATCH: eyebrow dormers swept out of the thatch (no draw; a style row number)
var corner_piers: bool = false     # rounded mud-brick corners
## HS-MINKA (no draw; style row numbers). The floor stands `floor_raise` metres
## above the ground it is built on: local y = 0 stays the floor's underside, and
## the ground, the yard and the entry steps are `floor_raise` BELOW it (the
## assembler lifts the house by that much so the ground lands at the root's y =
## 0). `engawa` is the long-side veranda at floor level, `engawa_depth` its reach.
var floor_raise: float = 0.0
var engawa: bool = false
var engawa_depth: float = 1.2
## How far the roof oversails its walls. Negative means HouseGeometry's
## ordinary 0.35 m / 0.25 m, and the bound reads the resolved value from
## there, so a deep-eaved house cannot be looser than the eave it built.
var roof_span_out: float = -1.0
var roof_along_out: float = -1.0
## Chosen before planning, so clear floor, openings and emitted masonry agree.
var material: StringName = &"timber" # timber | stone
## Site frame metadata. These do not participate in seeded plan generation.
var orientation: float = 0.0
var period: int = 1200
## Falling ground (VTER-HOUSE-SLOPE): metres of fall across the footprint and
## the downhill direction in the house's own frame (0 = toward the front, -Z;
## 90 = toward +X). Zero is flat ground, and a flat house is untouched. Never
## drawn from `rng`. See GroundFall and HouseSlope.
var ground_fall: float = 0.0
var ground_downhill_deg: float = 0.0
## Standing on piles over water (VTER-FORM-WATER): `&""` the ground, or
## `&"piles"`; the water's depth, the floor's height over the water (0: the
## default) and the landing's reach from the entrance wall (0: the default).
## Never drawn from `rng`. See HousePiles.
var foundation: StringName = &""
var pile_water: float = 0.0
var pile_freeboard: float = 0.0
var pile_deck: float = 0.0
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
		# A small household first: shared sleeping, cooking and sitting spaces.
		"domestic_program": [&"hall", &"bedroom", &"kitchen", &"bedroom", &"store", &"parlour"],
		"timber": 0.95, "studs": [0.95, 1.5], "braces": 0.8, "rail": 0.5,
		"roof_pitch": [0.85, 1.2], "porch": 1.0, "chimney": 1.0, "shutters": 0.7,
		# HS-COTTAGE: a sheltered door and a hearth stack are traits, not chances. 1.0
		# still draws, so no later roll in the stream moves.
		"roof_material": &"shingle", "pitch_reference": 7.0,
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
		# The work of the farm shares the ground floor with the kitchen and bed.
		"domestic_program": [&"hall", &"kitchen", &"bedroom", &"workshop", &"store", &"parlour"],
		"timber": 0.9, "studs": [1.1, 1.7], "braces": 0.85, "rail": 0.4,
		"roof_pitch": [0.7, 1.0], "porch": 0.7, "chimney": 0.95, "shutters": 0.5,
		"roof_material": &"thatch", "pitch_reference": 9.0,
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
		# A formal front parlour and a private office distinguish the town home.
		"domestic_program": [&"hall", &"bedroom", &"kitchen", &"parlour", &"office", &"store"],
		"timber": 1.0, "studs": [0.45, 0.7], "braces": 0.3, "rail": 0.9,
		"roof_pitch": [1.0, 1.4], "porch": 0.2, "chimney": 1.0, "shutters": 0.35,
		"roof_material": &"slate", "pitch_reference": 8.0,
		"wall": ["cfc9bd", "b3ac9e"], "trim": ["4b4238", "342e28"],
		"roof": ["4a4f57", "353a41"], "floor": ["8e7f63", "6b5f49"],
		"clutter": [0.35, 0.6],
		"plinth": [0.45, 0.75], "roof_types": [&"gable", &"half_hipped"],
		"framing": [&"close_studding", &"saltire"], "truss": [&"queen_post", &"collar_strut"],
		"jetty": 0.9, "dormers": 0.6, "bargeboards": 0.95, "stone_ground": 0.35,
		"chimney_style": &"stepped", "pots": [1, 2],
		# HS-TOWNHOUSE: tall and narrow, never one storey (style constant, no draw).
		"min_storeys": 2, "beds_upstairs": true,
	},
	&"longhall": {
		"label": "Long Hall",
		# Shared hearth, sleeping places, and work remain grouped around the
		# household's communal hall instead of imitating a parlour house.
		"domestic_program": [&"hall", &"bedroom", &"kitchen", &"store", &"workshop"],
		"timber": 0.85, "studs": [1.0, 1.6], "braces": 0.9, "rail": 0.35,
		"roof_pitch": [0.9, 1.25], "porch": 0.35, "chimney": 0.8, "shutters": 0.3,
		"roof_material": &"thatch", "pitch_reference": 8.0,
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
		# A hut is small (WITCH-SIZE): at most three rooms. The kitchen names
		# the cooking, eating and brewing the main room carries (the planner
		# merges it into the hall); then a sleeping room or nook. The compact
		# planner adds the optional dry store as the third room.
		"domestic_program": [&"hall", &"kitchen", &"bedroom"],
		"timber": 0.8, "studs": [0.8, 1.4], "braces": 0.6, "rail": 0.5,
		"roof_pitch": [1.2, 1.7], "porch": 1.0, "chimney": 1.0, "shutters": 0.6,
		"roof_material": &"thatch", "pitch_reference": 8.0, "pitch_exponent": 0.8,
		"wall": ["87684b", "73563e"], "trim": ["402a1b", "2f1f14"],
		"roof": ["8a7648", "6f5d38"], "floor": ["6c6250", "51493c"],
		"clutter": [0.75, 1.0],
		"plinth": [0.25, 0.45], "roof_types": [&"gable"],
		"framing": [&"arch_brace", &"square_panel"], "truss": [&"king_post"],
		# WITCH-ROOF: a hut has neither jetty nor dormers (0.0 keeps the draw order);
		# a deep thatch eave and verge.
		"jetty": 0.0, "dormers": 0.0, "bargeboards": 0.6, "stone_ground": 0.05,
		# (A deeper eave than the ordinary 0.35 m breaks the rafter birdsmouth seat on
		# the 0.2 m tie plate -- 0.42 already does; see docs/HOUSES.md WITCH-ROOF.)
		"chimney_style": &"stepped", "pots": [1, 1],
	},
	&"rich": {
		"label": "Rich House",
		# The tightest studs in the table and a mid rail at every band: the
		# elevation is read as horizontal stripes, not as a plastered box.
		"timber": 1.0, "studs": [0.32, 0.5], "braces": 0.25, "rail": 1.0,
		"roof_pitch": [1.25, 1.7], "porch": 0.85, "chimney": 1.0, "shutters": 0.8,
		"roof_material": &"shingle", "pitch_reference": 8.0,
		"wall": ["e6dcc4", "cdbda2"], "trim": ["7d5f38", "543f22"],
		"roof": ["5c4230", "3d2b1e"], "floor": ["84745a", "695c46"],
		"clutter": [0.55, 0.9],
		"plinth": [0.5, 0.75], "roof_types": [&"gable", &"half_hipped"],
		"framing": [&"close_studding", &"saltire"], "truss": [&"queen_post", &"king_post"],
		"jetty": 0.95, "dormers": 0.9, "bargeboards": 1.0, "stone_ground": 0.6,
		"chimney_style": &"stepped", "pots": [1, 2],
		# HOUSE-RICH: the four ornament switches. A style row that carries none
		# of these is an ordinary house, whatever its name.
		"cornice": 1.0, "string_courses": [1, 2], "pediments": 0.85,
		"ridge_finial": 1.0, "min_storeys": 2,
		# HS-RICH: a hall that holds the stair, then a parlour and a dining
		# room of their own. Style constants, no random draw: one more room
		# than the floor area asks for, and a table laid for four.
		"domestic_program": [&"hall", &"kitchen", &"parlour", &"dining_room"],
		"dining_seats": 4, "sitting_group": true,
	},
	&"mediterranean": {
		"label": "Mediterranean House",
		# Limewashed rendered masonry under pantiles. There is no frame to
		# expose, so `timber` is zero and the wall is a plastered solid: the
		# elevation is read from its shutters, its deep eave and its terrace
		# wall, not from studs.
		"timber": 0.0, "studs": [1.0, 1.4], "braces": 0.0, "rail": 0.0,
		# HS-MEDITERRANEAN: the roof is LOW (0.32..0.44 is 18 to 24 degrees on
		# the roof face, under the 25 the trait asks; the old 0.5..0.75 was 27
		# to 36), the shade at the door is a loggia (the veranda, always) and
		# not a porch pail's worth of porch, and the rear door opens on a walled
		# court (HouseYard `court`). Same draws as before: only the numbers moved.
		"roof_pitch": [0.32, 0.44], "porch": 0.0, "chimney": 0.45, "shutters": 0.9,
		"wall": ["f2e8d4", "e0cfae"], "trim": ["2f6b63", "1d4a43"],
		"roof": ["b4622f", "8d4722"], "floor": ["bcab89", "9c8a6b"],
		"clutter": [0.35, 0.7],
		"plinth": [0.5, 0.85], "roof_types": [&"hipped", &"gable"],
		"framing": [&"square_panel"], "truss": [&"king_post"],
		"jetty": 0.0, "dormers": 0.25, "bargeboards": 0.0, "stone_ground": 0.0,
		"chimney_style": &"straight", "pots": [1, 2],
		"roof_material": &"tile", "pitch_reference": 9.0,
		"wall_t": 0.45, "culture": 1.0,
		"parapet": 0.7, "veranda": 1.0, "eave_sweep": 0.0, "thatch_roll": 0.0,
		"corner_piers": 0.0, "span_out": 0.55, "along_out": 0.45,
	},
	&"asian": {
		"label": "Japanese Minka",
		# HS-MINKA. A timber house standing on a stone plinth whose floor is
		# raised clear of the ground (`raised_floor`: the plinth draw becomes the
		# floor's height), under an irimoya roof -- a gable on a hipped skirt --
		# whose deep eaves cover the engawa, the veranda that runs along one
		# long side. The long side that carries it is fitted with sliding
		# lattice screens and the main room opens through them onto the garden.
		"timber": 0.85, "studs": [0.9, 1.3], "braces": 0.7, "rail": 0.8,
		"roof_pitch": [0.8, 1.0], "porch": 0.0, "chimney": 0.0, "shutters": 0.0,
		"wall": ["dccfab", "c2b189"], "trim": ["6b4a2f", "47301c"],
		"roof": ["3f4a44", "2b3430"], "floor": ["a08a63", "857050"],
		"clutter": [0.3, 0.65],
		"plinth": [0.45, 0.6], "roof_types": [&"irimoya"],
		"framing": [&"square_panel", &"arch_brace"], "truss": [&"king_post", &"queen_post"],
		"jetty": 0.0, "dormers": 0.0, "bargeboards": 0.0, "stone_ground": 0.0,
		"chimney_style": &"straight", "pots": [1, 1],
		"roof_material": &"tile", "pitch_reference": 8.0,
		"wall_t": 0.3, "culture": 1.0,
		"parapet": 0.0, "veranda": 0.0, "eave_sweep": 0.0, "thatch_roll": 0.0,
		"corner_piers": 0.0, "span_out": 1.0, "along_out": 0.9,
		"raised_floor": true, "engawa": 1.0, "engawa_depth": 0.8,
	},
	&"african": {
		"label": "African Compound House",
		# Thick ochre daub over a rubble core, combed reed over it, and a
		# shaded veranda to sit out the heat under. No chimney: the smoke
		# leaves by the roof, which is why the hearth is in the middle of the
		# floor and not against a wall.
		"timber": 0.0, "studs": [1.0, 1.4], "braces": 0.0, "rail": 0.0,
		"roof_pitch": [1.0, 1.35], "porch": 0.0, "chimney": 0.0, "shutters": 0.15,
		"wall": ["c08a55", "9b6b3e"], "trim": ["5a3a22", "3b2514"],
		"roof": ["ac8a44", "806229"], "floor": ["9c7a52", "7a5f3e"],
		"clutter": [0.5, 0.9],
		"plinth": [0.3, 0.6], "roof_types": [&"hipped", &"conical"],
		"framing": [&"square_panel"], "truss": [&"king_post"],
		"jetty": 0.0, "dormers": 0.0, "bargeboards": 0.0, "stone_ground": 0.0,
		"chimney_style": &"straight", "pots": [1, 1],
		"roof_material": &"thatch", "pitch_reference": 8.0,
		"wall_t": 0.5, "culture": 1.0,
		"parapet": 0.6, "veranda": 0.75, "eave_sweep": 0.0, "thatch_roll": 1.0,
		"corner_piers": 1.0, "span_out": 0.7, "along_out": 0.6,
	},
	&"thatch_cottage": {
		"label": "Thatched Cottage",
		# A cob cottage under a very steep combed roof. Thatch is why this
		# style has no bargeboards at all: a verge board is a thing that holds
	# ON slates or tiles, and a thatcher finishes a gable by turning the reeds
		# down and wiring them, not by nailing a board to the end of them.
		# HS-THATCH: the walls are pale rendered cob and carry NO frame (timber,
		# jetty and the stone ground floor are 0.0, so the same draws are consumed
		# and no later roll moves); one eyebrow dormer is swept out of the thatch
		# (`eyebrow`, read without a draw). Soft thatch: HouseGeometry.thatch_soft.
		"timber": 0.0, "studs": [1.0, 1.5], "braces": 0.0, "rail": 0.0,
		"eyebrow": 1,
		"roof_pitch": [1.15, 1.5], "porch": 0.6, "chimney": 0.85, "shutters": 0.4,
		"wall": ["efe7d3", "dbcfb4"], "trim": ["4a3826", "322518"],
		"roof": ["bda25f", "8d7640"], "floor": ["8a7a5e", "6f6148"],
		"clutter": [0.45, 0.8],
		"plinth": [0.3, 0.55], "roof_types": [&"gable"],
		"framing": [&"arch_brace", &"square_panel"], "truss": [&"king_post", &"collar_strut"],
		"jetty": 0.0, "dormers": 0.2, "bargeboards": 0.0, "stone_ground": 0.0,
		"chimney_style": &"stepped", "pots": [1, 2],
		"roof_material": &"thatch", "pitch_reference": 7.0,
		"wall_t": 0.5, "culture": 1.0,
		"parapet": 0.0, "veranda": 0.0, "eave_sweep": 0.0, "thatch_roll": 1.0,
		"corner_piers": 0.0, "span_out": 0.5, "along_out": 0.35,
	},
	&"mud_hut": {
		"label": "Mud Hut",
		# One room, very thick walls, one cone. There is nothing to put a
		# window in that is not a hole through half a metre of mud, so the
		# openings are small and high and the plan is nearly a square.
		"timber": 0.0, "studs": [1.0, 1.4], "braces": 0.0, "rail": 0.0,
		"roof_pitch": [1.05, 1.4], "porch": 0.0, "chimney": 0.0, "shutters": 0.0,
		"wall": ["b98a5e", "94663d"], "trim": ["6b4527", "472c16"],
		"roof": ["ab8e4c", "82692e"], "floor": ["8a6a45", "6a5033"],
		"clutter": [0.4, 0.75],
		"plinth": [0.25, 0.45], "roof_types": [&"conical"],
		"framing": [&"square_panel"], "truss": [&"king_post"],
		"jetty": 0.0, "dormers": 0.0, "bargeboards": 0.0, "stone_ground": 0.0,
		"chimney_style": &"straight", "pots": [1, 1],
		"roof_material": &"thatch", "pitch_reference": 7.0,
		"wall_t": 0.62, "culture": 1.0,
		"parapet": 0.0, "veranda": 0.45, "eave_sweep": 0.0, "thatch_roll": 1.0,
		"corner_piers": 1.0, "span_out": 0.8, "along_out": 0.7,
	},
	&"pueblo": {
		"label": "Pueblo Adobe House",
		# A broad earthen dwelling with thick, sun-dried walls and a level roof
		# behind a high parapet. Its silhouette is a terrace, not a hidden hip.
		"timber": 0.0, "studs": [1.0, 1.4], "braces": 0.0, "rail": 0.0,
		"roof_pitch": [0.0, 0.0], "porch": 0.0, "chimney": 0.0, "shutters": 0.15,
		"wall": ["c98b58", "a66d40"], "trim": ["755036", "563a27"],
		"roof": ["b58a58", "92704a"], "floor": ["a58b66", "80684d"],
		"clutter": [0.3, 0.6],
		"plinth": [0.25, 0.4], "roof_types": [&"flat"],
		"framing": [&"square_panel"], "truss": [&"king_post"],
		"jetty": 0.0, "dormers": 0.0, "bargeboards": 0.0, "stone_ground": 0.0,
		"chimney_style": &"straight", "pots": [1, 1],
		"roof_material": &"earth", "pitch_reference": 8.0,
		"wall_t": 0.72, "culture": 1.0,
		"parapet": 1.0, "veranda": 0.0, "eave_sweep": 0.0, "thatch_roll": 0.0,
		"corner_piers": 0.0, "span_out": 0.25, "along_out": 0.25,
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


## Family limit used by structural and walking checks. Keeps override this
## because their occupied towers legitimately exceed a dwelling's envelope.
func max_storeys() -> int:
	return HouseGeometry.MAX_STOREYS


## Families without a supported flue may suppress the ordinary hearth prop.
## Ordinary families retain their hearth recipes.
func allows_hearth_furniture() -> bool:
	return true


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
