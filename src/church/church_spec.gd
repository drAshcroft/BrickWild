class_name ChurchSpec
extends RefCounted
## One church design. User-locked inputs (footprint, height, style) are stored
## verbatim; everything else is derived from `seed` so variants are reproducible.

var seed: int
var rng: RandomNumberGenerator

# ---- user-specified (never randomized) ----
var style: StringName = &"romanesque"
var width: float = 10.0     # nave width, meters  (X)
var length: float = 20.0    # nave length (Z), before tower/apse additions
var height: float = 12.0    # wall height to eaves, meters

# ---- derived from seed + style ----
var variant_name: String
var tower: bool
var tower_width: float           # meters
var tower_height: float          # meters, above ground
var spire: bool
var spire_pitch: float           # rise/run of the spire pyramid
var apse: bool
var apse_radius: float
var transept: bool
var transept_len: float          # total transept span across X
var aisles: int                  # 0 or 1 side aisle each side
var aisle_width: float
var buttresses: bool
var buttress_count_per_side: int
var buttress_depth: float
var window_style: StringName     # &"round", &"pointed", &"square"
var window_w: float
var window_h: float
var clerestory: bool             # upper window band above the aisle roofs
var door_style: StringName       # &"arched", &"twin", &"portal"
var rose_window: bool
var roof_pitch: float
var tower_roof: StringName       # &"pyramid", &"spire", &"flat", &"belfry"
var stone_color: Color
var trim_color: Color
var roof_color: Color
var corner_turrets: bool         # small pinnacles at transept/corner
var string_course: bool          # horizontal decorative band

const STYLES := {
	&"romanesque": {
		"label": "Romanesque",
		"tower": 0.8, "spire": 0.15, "apse": 0.85, "transept": 0.3,
		"aisles": [0, 0, 1], "buttresses": 0.7, "windows": &"round",
		"rose": 0.2, "clerestory": 0.25, "door": [&"arched", &"twin"],
		"towers_roof": [&"pyramid", &"flat", &"belfry"],
	},
	&"gothic": {
		"label": "Gothic",
		"tower": 0.9, "spire": 0.6, "apse": 0.8, "transept": 0.75,
		"aisles": [1, 2], "buttresses": 1.0, "windows": &"pointed",
		"rose": 0.65, "clerestory": 0.8, "door": [&"portal"],
		"towers_roof": [&"spire", &"pyramid"],
	},
	&"byzantine": {
		"label": "Byzantine",
		"tower": 0.15, "spire": 0.05, "apse": 0.95, "transept": 0.5,
		"aisles": [0, 1], "buttresses": 0.2, "windows": &"round",
		"rose": 0.35, "clerestory": 0.5, "door": [&"arched"],
		"towers_roof": [&"pyramid", &"flat"],
	},
	&"nordic_stave": {
		"label": "Nordic Stave",
		"tower": 0.95, "spire": 0.85, "apse": 0.4, "transept": 0.35,
		"aisles": [0], "buttresses": 0.3, "windows": &"square",
		"rose": 0.3, "clerestory": 0.15, "door": [&"arched"],
		"towers_roof": [&"spire"],
	},
}

## The seed passed here is provisional: ChurchGenerator.generate() is the
## authoritative seeding point and re-seeds both fields. Callers that are about
## to generate can simply use ChurchSpec.new().
func _init(p_seed := 0) -> void:
	seed = p_seed
	rng = RandomNumberGenerator.new()
	rng.seed = seed

