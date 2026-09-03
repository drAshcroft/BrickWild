class_name CastleSpec
extends RefCounted
## One fortification design. User-locked inputs (site footprint, wall height,
## style) are stored verbatim; everything else is derived from `seed` so
## variants are reproducible.
##
## The one input that changes the KIND of building is size: a small footprint
## is a house, a larger one a manor, larger still a castle, and the largest a
## concentric fortress. TIERS below is where that decision is written down.

var seed: int
var rng: RandomNumberGenerator

# ---- user-specified (never randomized) ----
var style: StringName = &"norman"
var width: float = 40.0     # site width, metres  (X)
var length: float = 50.0    # site length, metres (Z); the gate is at -Z
var height: float = 10.0    # main wall / eaves height, metres
## Force a tier instead of deriving it from the footprint. &"" means derive.
var tier_override: StringName = &""
## Force a plan kind instead of deriving it from style and tier. &"" derives.
var plan_override: StringName = &""
## Force the side count of a polygonal plan. 0 derives it.
var sides_override: int = 0

# ---- derived from seed + style ----
var tier: StringName             # &"house", &"manor", &"castle", &"fortress"
var variant_name: String

# ---- the plan ----
## Shape of the enceinte: &"rect" (an axis-aligned rectangle, the plan every
## castle used to have) or &"polygon" (a regular N-gon with a flat edge facing
## the gate). A rectangle IS the N = 4 polygon; `plan_kind` only says whether
## the builder may take the axis-aligned shortcut.
var plan_kind: StringName = &"rect"
## Sides of the enceinte: 4 for &"rect", POLY_MIN_SIDES..POLY_MAX_SIDES for
## &"polygon".
var sides: int = 4

# curtain walls (castle and fortress)
var curtain: bool
var wall_thickness: float
var battlements: bool
var merlon_h: float
var batter: float                # talus: how far the wall foot spreads, x height

# towers
var tower_shape: StringName      # &"round", &"square", &"polygonal"
var tower_size: float            # radius, or half the side of a square tower
var tower_height: float
var tower_roof: StringName       # &"cone", &"pyramid", &"flat", &"tiered"
var corner_towers: bool
var side_towers: int             # extra towers per long side, between corners

# gate
var gatehouse: bool
var gate_width: float
var gate_depth: float
var gate_towers: bool            # the twin drums flanking the passage
var barbican: bool               # outwork in front of the gate (fortress)

# inner ward (fortress only): the second, higher enceinte
var inner_ward: bool
var ward_gap: float              # clear ground between the two curtains

# buildings inside, or the whole building at house/manor tier
var keep: bool
var keep_shape: StringName       # &"square", &"round", &"shell", &"tiered"
var keep_w: float
var keep_l: float
var keep_height: float
var hall: bool                   # the great hall range
var hall_w: float
var hall_l: float
var hall_height: float
var chapel: bool
var wings: int                   # cross wings on a manor: 0, 1 or 2
var courtyard: bool              # manor ranges close the fourth side
var chimneys: int
var roof_pitch: float
var window_style: StringName     # &"slit", &"square", &"mullioned", &"arched"
var window_w: float
var window_h: float
var dormers: bool

var stone_color: Color
var trim_color: Color
var roof_color: Color

## Footprint area, in square metres, at which each tier takes over. A tier is
## about how much building the site can hold: a hall house is one range, a
## manor is ranges round a court, a castle adds an enceinte with towers, and a
## fortress adds a second one inside the first.
const TIERS := [
	{"tier": &"house", "max_area": 300.0},
	{"tier": &"manor", "max_area": 2000.0},
	{"tier": &"castle", "max_area": 12000.0},
	{"tier": &"fortress", "max_area": INF},
]


## Which tier a footprint falls in. Pure, so the generator, the suites and the
## docs all read the same rule.
static func tier_for(w: float, l: float) -> StringName:
	var area: float = absf(w) * absf(l)
	for row in TIERS:
		if area <= float(row["max_area"]):
			return row["tier"]
	return &"fortress"


## How likely each style is to lay its enceinte out as a polygon rather than a
## rectangle, and which side counts it would use. Only the walled tiers have an
## enceinte to shape at all, so the table is consulted for castle and fortress.
## Caernarfon and Conwy are polygonal, Castel del Monte is a regular octagon;
## a Norman motte castle and a Japanese hirajiro are rectangular, and stay so.
const PLANS := {
	&"norman": {"polygon": 0.0, "sides": [6]},
	&"edwardian": {"polygon": 0.5, "sides": [6, 8]},
	&"crusader": {"polygon": 0.35, "sides": [5, 6]},
	&"french_chateau": {"polygon": 0.25, "sides": [6, 8]},
	&"bavarian": {"polygon": 0.35, "sides": [5, 6, 7]},
	&"japanese": {"polygon": 0.0, "sides": [8]},
	&"moorish": {"polygon": 0.3, "sides": [6, 8]},
}


## The plan a (style, tier, seed) asks for, as {"kind": StringName, "sides":
## int}. Pure, and deliberately drawn from its OWN generator rather than from
## spec.rng: a castle's plan must not shift every other random decision the
## generator makes, or adding this feature would have redesigned every existing
## castle. An unwalled tier is a building, not an enceinte, so it stays rect.
static func plan_for(style: StringName, tier: StringName, p_seed: int) -> Dictionary:
	var rect := {"kind": &"rect", "sides": 4}
	if tier != &"castle" and tier != &"fortress":
		return rect
	var row: Dictionary = PLANS.get(style, {"polygon": 0.0, "sides": [6]})
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s|%s|%d" % [String(style), String(tier), p_seed])
	if r.randf() >= float(row["polygon"]):
		return rect
	var opts: Array = row["sides"]
	return {"kind": &"polygon", "sides": int(opts[r.randi_range(0, opts.size() - 1)])}


const STYLES := {
	&"norman": {
		"label": "Norman",
		# Square everything: the great rectangular keep of the 12th century.
		"tower_shape": &"square", "tower_roof": [&"pyramid", &"flat"],
		"keep_shape": [&"square"], "battlements": 1.0, "batter": 0.03,
		"side_towers": [0, 1], "gate_towers": 0.6, "barbican": 0.3,
		"roof_pitch": [0.5, 0.8], "windows": &"slit", "dormers": 0.0,
		"stone": ["9c948a", "7d766c"], "roof": ["4d4238", "3a332c"],
		"chimneys": [1, 2], "wings": [1, 2],
	},
	&"edwardian": {
		"label": "Edwardian",
		# Beaumaris and Caernarfon: drum towers, twin-towered gatehouse, and
		# where there is room, a ring of walls inside a ring of walls.
		"tower_shape": &"round", "tower_roof": [&"cone", &"flat"],
		"keep_shape": [&"shell", &"round"], "battlements": 1.0, "batter": 0.05,
		"side_towers": [1, 2], "gate_towers": 0.95, "barbican": 0.6,
		"roof_pitch": [0.55, 0.85], "windows": &"slit", "dormers": 0.0,
		"stone": ["a8a396", "8b8578"], "roof": ["55606b", "424b55"],
		"chimneys": [1, 2], "wings": [1, 2],
	},
	&"crusader": {
		"label": "Crusader",
		# Krak des Chevaliers: low, immensely thick, and battered -- the talus
		# is the signature, so `batter` is far bigger here than anywhere else.
		"tower_shape": &"round", "tower_roof": [&"flat"],
		"keep_shape": [&"square", &"shell"], "battlements": 1.0, "batter": 0.16,
		"side_towers": [2, 3], "gate_towers": 0.7, "barbican": 0.75,
		"roof_pitch": [0.35, 0.5], "windows": &"slit", "dormers": 0.0,
		"stone": ["c2b49a", "a3927a"], "roof": ["8a7357", "6f5c46"],
		"chimneys": [0, 1], "wings": [1],
	},
	&"french_chateau": {
		"label": "French Château",
		# Chambord: drum towers under tall conical roofs, steep dormered
		# ranges, and a keep that is really a lodging block.
		"tower_shape": &"round", "tower_roof": [&"cone"],
		"keep_shape": [&"square"], "battlements": 0.2, "batter": 0.02,
		"side_towers": [0, 1], "gate_towers": 0.4, "barbican": 0.1,
		"roof_pitch": [1.0, 1.5], "windows": &"mullioned", "dormers": 0.9,
		"stone": ["d8d2c4", "c0b9a8"], "roof": ["4a5566", "39424f"],
		"chimneys": [3, 5, 7], "wings": [2],
	},
	&"bavarian": {
		"label": "Bavarian Romantic",
		# Neuschwanstein: slender towers with tall spires, steep roofs, and no
		# real defensive intent at all.
		"tower_shape": &"round", "tower_roof": [&"cone"],
		"keep_shape": [&"square"], "battlements": 0.6, "batter": 0.02,
		"side_towers": [1, 2], "gate_towers": 0.5, "barbican": 0.2,
		"roof_pitch": [1.1, 1.6], "windows": &"arched", "dormers": 0.6,
		"stone": ["e2ded4", "cbc5b8"], "roof": ["6b5a7a", "4d4058"],
		"chimneys": [2, 3], "wings": [2],
	},
	&"japanese": {
		"label": "Japanese",
		# Himeji: a battered stone base carrying a tiered timber tenshu, with
		# yagura turrets on the corners.
		"tower_shape": &"square", "tower_roof": [&"tiered"],
		"keep_shape": [&"tiered"], "battlements": 0.0, "batter": 0.16,
		"side_towers": [1, 2], "gate_towers": 0.3, "barbican": 0.4,
		"roof_pitch": [0.5, 0.7], "windows": &"square", "dormers": 0.0,
		"stone": ["e8e6e0", "d2cfc6"], "roof": ["3f4448", "2e3236"],
		"chimneys": [0], "wings": [1, 2],
	},
	&"moorish": {
		"label": "Moorish",
		# The Alhambra's alcazaba: square towers, flat roofs, courtyards.
		"tower_shape": &"square", "tower_roof": [&"flat"],
		"keep_shape": [&"square"], "battlements": 1.0, "batter": 0.06,
		"side_towers": [2, 3], "gate_towers": 0.4, "barbican": 0.3,
		"roof_pitch": [0.3, 0.45], "windows": &"arched", "dormers": 0.0,
		"stone": ["c8a882", "ad8c66"], "roof": ["a8613c", "8a4c30"],
		"chimneys": [0, 1], "wings": [1, 2],
	},
}


## The seed passed here is provisional: CastleGenerator.generate() is the
## authoritative seeding point and re-seeds both fields.
func _init(p_seed := 0) -> void:
	seed = p_seed
	rng = RandomNumberGenerator.new()
	rng.seed = seed
