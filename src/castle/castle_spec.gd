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
## The tower house (CAS-006; plan_kind &"tower_house"): the house tier grown
## up instead of out. `tower_storeys` 4-6; `tower_type` &"bologna" (a slender
## shaft on a base of 10 m or less, four times as tall as wide) or
## &"scottish" (broader, twice as tall as wide); `jog` &"none", &"l" or &"z"
## for the second mass sharing a wall with the shaft.
var tower_storeys: int = 4
var tower_type: StringName = &"bologna"
var jog: StringName = &"none"
## The ridge castle (CAS-007; plan_kind &"ridge"): ranges strung along a
## polyline spine with a tower at every bend and both ends, and no bailey.
## `ridge_points` is how many vertices the spine has (3-6); the ranges are
## `hall_w` wide and `tower_storeys` tall.
var ridge_points: int = 4
## The motte and bailey (CAS-005; plan_kind &"motte_bailey"): a mound behind
## the bailey with a shell keep on its flat top, joined to the bailey by a
## curtain climbing the slope. `motte_height` 6-15 m by tier, `motte_batter`
## the slope in degrees (30-40); the keep's outer diameters are keep_w and
## keep_l and its wall `shell_thickness`.
## 0 until the generator (or a refit onto this plan kind) sizes the mound.
var motte_height: float = 0.0
var motte_batter: float = 35.0
var shell_thickness: float = 1.2

# curtain walls (castle and fortress)
var curtain: bool
var wall_thickness: float
var battlements: bool
var merlon_h: float
## &"block" for historical crenellation, &"spike" for the dark fortress.
var merlon_profile: StringName = &"block"
var batter: float                # talus: how far the wall foot spreads, x height

# towers
var tower_shape: StringName      # &"round", &"square", &"polygonal"
var tower_size: float            # radius, or half the side of a square tower
var tower_height: float
var tower_roof: StringName       # &"cone", &"pyramid", &"flat", &"tiered"
var corner_towers: bool
var side_towers: int             # extra towers per long side, between corners
## The great tower (CAS-002): one vertex tower of the outer ring that is
## bigger than the rest -- the Eagle Tower, the Torre de la Vela -- as the
## index of the vertex it stands on, or -1 for none; and how much bigger, in
## [1.5, 2.0] across. Its height grows with it (CastleGeometry.tower_height_at).
var great_tower: int = -1
var great_tower_scale: float = 1.0

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
## How far east (+) or west (-) of the axis the keep stands, in metres; the
## White Tower is in the south-east corner of its ward. 0 is on the axis.
var keep_offset: float = 0.0
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


## How likely each walled style is to have a great tower at all. Drawn from a
## generator of its own (see plan_for) so the rest of the design is unmoved.
const GREAT_TOWER_CHANCE := {
	&"norman": 0.7, &"edwardian": 0.75, &"crusader": 0.5, &"french_chateau": 0.4,
	&"bavarian": 0.6, &"japanese": 0.3, &"moorish": 0.7,
	&"wizard": 0.0, &"dark": 0.0, &"sky": 0.6,
}


## The great tower a (style, tier, seed) asks for, as {"vertex": int,
## "scale": float}; vertex -1 means none. Pure and on its own generator, like
## plan_for, so switching it on did not redesign every castle after it.
static func great_tower_for(style: StringName, tier: StringName, p_seed: int,
		vertices: int) -> Dictionary:
	var none := {"vertex": -1, "scale": 1.0}
	if (tier != &"castle" and tier != &"fortress") or vertices <= 0:
		return none
	var r := RandomNumberGenerator.new()
	r.seed = hash("great|%s|%s|%d" % [String(style), String(tier), p_seed])
	if r.randf() >= float(GREAT_TOWER_CHANCE.get(style, 0.5)):
		return none
	return {"vertex": r.randi_range(0, vertices - 1), "scale": r.randf_range(1.5, 2.0)}


## How likely each style is to build a tall enough house or manor site as a
## tower house rather than as a range (CAS-006). Only asked when the height
## the user locked is at least twice the longer side: a tower is a tower
## because of its proportion, and a squat one is a house.
const TOWER_HOUSE_CHANCE := {
	&"norman": 0.6, &"edwardian": 0.4, &"crusader": 0.3, &"french_chateau": 0.3,
	&"bavarian": 0.5, &"japanese": 0.0, &"moorish": 0.5,
	&"wizard": 1.0, &"dark": 0.0, &"sky": 0.0,
}


## Whether a (style, tier, seed) on a site this tall grows into a tower house,
## on its own generator like plan_for.
static func tower_house_for(style: StringName, tier: StringName, p_seed: int,
		w: float, l: float, h: float) -> bool:
	if tier != &"house" and tier != &"manor":
		return false
	if h < 2.0 * maxf(w, l):
		return false
	var r := RandomNumberGenerator.new()
	r.seed = hash("tower|%s|%s|%d" % [String(style), String(tier), p_seed])
	return r.randf() < float(TOWER_HOUSE_CHANCE.get(style, 0.3))


## How likely each style is to lay its enceinte out as a polygon rather than a
## rectangle, and which side counts it would use. Only the walled tiers have an
## enceinte to shape at all, so the table is consulted for castle and fortress.
## Caernarfon and Conwy are polygonal, Castel del Monte is a regular octagon;
## a Norman motte castle and a Japanese hirajiro are rectangular, and stay so.
const PLANS := {
	&"norman": {"polygon": 0.0, "sides": [6], "motte": 0.45},
	&"edwardian": {"polygon": 0.5, "sides": [6, 8]},
	&"crusader": {"polygon": 0.35, "sides": [5, 6]},
	&"french_chateau": {"polygon": 0.25, "sides": [6, 8]},
	&"bavarian": {"polygon": 0.2, "sides": [5, 6, 7], "ridge": 0.45},
	&"japanese": {"polygon": 0.0, "sides": [8]},
	&"moorish": {"polygon": 0.3, "sides": [6, 8]},
	# Fantasy families are signatures, not probabilities. Wizard still needs
	# the tall house proportion checked by tower_house_for(); the other two
	# force their defining castle-tier plan.
	&"wizard": {"polygon": 0.0, "sides": [6]},
	&"dark": {"polygon": 0.0, "sides": [4], "forced": &"ridge"},
	&"sky": {"polygon": 1.0, "sides": [7, 8], "forced": &"polygon"},
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
	if row.has("forced"):
		var forced: StringName = row["forced"]
		var opts: Array = row["sides"]
		return {"kind": forced, "sides": int(opts[r.randi_range(0, opts.size() - 1)])}
	# a ridge castle first (CAS-007): Neuschwanstein is a ridge before it is
	# anything else, and only on a site long enough to string ranges along
	var ridge: float = float(row.get("ridge", 0.0))
	if ridge > 0.0 and r.randf() < ridge:
		return {"kind": &"ridge", "sides": 4}
	# a motte and bailey (CAS-005): the Norman plan before the stone one
	var motte: float = float(row.get("motte", 0.0))
	if motte > 0.0 and r.randf() < motte:
		return {"kind": &"motte_bailey", "sides": 4}
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
	&"wizard": {
		"label": "Wizard's Tower",
		"plan_kind": &"tower_house",
		"tower_shape": &"round", "tower_roof": [&"cone"],
		"keep_shape": [&"round"], "battlements": 0.0, "batter": 0.04,
		"side_towers": [0], "gate_towers": 0.0, "barbican": 0.0,
		"roof_pitch": [1.15, 1.45], "windows": &"arched", "dormers": 0.0,
		"stone": ["716783", "49405c"], "roof": ["253653", "151f38"],
		"chimneys": [1], "wings": [0], "merlon_profile": &"block",
	},
	&"dark": {
		"label": "Dark Fortress",
		"plan_kind": &"ridge",
		"tower_shape": &"polygonal", "tower_roof": [&"flat"],
		"keep_shape": [&"spire"], "battlements": 1.0, "batter": 0.12,
		"side_towers": [1, 2], "gate_towers": 0.8, "barbican": 0.6,
		"roof_pitch": [0.55, 0.8], "windows": &"slit", "dormers": 0.0,
		"stone": ["292a32", "111218"], "roof": ["171720", "090a0e"],
		"chimneys": [0], "wings": [1], "merlon_profile": &"spike",
	},
	&"sky": {
		"label": "Sky Citadel",
		"plan_kind": &"polygon",
		"tower_shape": &"polygonal", "tower_roof": [&"cone", &"flat"],
		"keep_shape": [&"round", &"shell"], "battlements": 0.7, "batter": 0.02,
		"side_towers": [0, 1], "gate_towers": 0.5, "barbican": 0.0,
		"roof_pitch": [0.7, 1.0], "windows": &"arched", "dormers": 0.2,
		"stone": ["d6d8e8", "929ac1"], "roof": ["697caf", "34446e"],
		"chimneys": [0, 1], "wings": [1], "merlon_profile": &"block",
	},
}


## The seed passed here is provisional: CastleGenerator.generate() is the
## authoritative seeding point and re-seeds both fields.
func _init(p_seed := 0) -> void:
	seed = p_seed
	rng = RandomNumberGenerator.new()
	rng.seed = seed
