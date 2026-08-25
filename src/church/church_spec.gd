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

# ---- landmark features (see docs/LANDMARKS.md) ----
var west_towers: int             # 0, 1 (single) or 2 (twin facade towers)
var flying_buttresses: bool      # pier + flyer arch + pinnacle, Gothic
var flyer_tiers: int             # 1 or 2 stacked flyers per pier
var crossing_tower: bool         # lantern/tower over the crossing
var crossing_tower_height: float
var dome: bool
var dome_shape: StringName       # &"hemisphere", &"onion", &"octagonal"
var dome_radius: float
var dome_drum_height: float      # vertical drum the dome springs from
var dome_lantern: bool
var half_domes: bool             # buttressing half-domes east/west, Byzantine
var exedrae: bool                # small semi-domed niches flanking the half-domes
var ambulatory: bool             # aisle carried around the apse
var radiating_chapels: int       # apsidal alcoves off the ambulatory
var chapel_arrangement: StringName  # &"chevet" (fanned off the apse) or
                                 # &"cluster" (ringed round the central mass)
var chapel_radius: float
var narthex: bool                # entrance vestibule across the west front

const STYLES := {
	&"romanesque": {
		"label": "Romanesque",
		"tower": 0.8, "spire": 0.15, "apse": 0.85, "transept": 0.3,
		"aisles": [0, 0, 1], "buttresses": 0.7, "windows": &"round",
		"rose": 0.2, "clerestory": 0.25, "door": [&"arched", &"twin"],
		"towers_roof": [&"pyramid", &"flat", &"belfry"],
		# Durham: a central lantern plus twin west towers.
		"twin_towers": 0.45, "flying": 0.0, "crossing_tower": 0.5,
		"dome": 0.0, "dome_shapes": [], "ambulatory": 0.15,
		"chapels": [0, 0, 3], "narthex": 0.2,
	},
	&"gothic": {
		"label": "Gothic",
		"tower": 0.9, "spire": 0.6, "apse": 0.8, "transept": 0.75,
		"aisles": [1, 2], "buttresses": 1.0, "windows": &"pointed",
		"rose": 0.65, "clerestory": 0.8, "door": [&"portal"],
		"towers_roof": [&"spire", &"pyramid"],
		# Notre-Dame / Cologne / Chartres: flyers, twin towers, chapels.
		"twin_towers": 0.8, "flying": 0.9, "crossing_tower": 0.3,
		"dome": 0.0, "dome_shapes": [], "ambulatory": 0.7,
		"chapels": [0, 3, 5, 7], "narthex": 0.25,
	},
	&"byzantine": {
		"label": "Byzantine",
		"tower": 0.15, "spire": 0.05, "apse": 0.95, "transept": 0.5,
		"aisles": [0, 1], "buttresses": 0.2, "windows": &"round",
		"rose": 0.35, "clerestory": 0.5, "door": [&"arched"],
		"towers_roof": [&"pyramid", &"flat"],
		# Hagia Sophia: a great dome on pendentives, braced by half-domes.
		"twin_towers": 0.1, "flying": 0.0, "crossing_tower": 0.0,
		"dome": 0.95, "dome_shapes": [&"hemisphere"], "ambulatory": 0.4,
		"chapels": [0, 0, 2], "narthex": 0.8, "half_domes": 0.85,
	},
	&"nordic_stave": {
		"label": "Nordic Stave",
		"tower": 0.95, "spire": 0.85, "apse": 0.4, "transept": 0.35,
		"aisles": [0], "buttresses": 0.3, "windows": &"square",
		"rose": 0.3, "clerestory": 0.15, "door": [&"arched"],
		"towers_roof": [&"spire"],
		"twin_towers": 0.0, "flying": 0.0, "crossing_tower": 0.1,
		"dome": 0.0, "dome_shapes": [], "ambulatory": 0.0,
		"chapels": [0], "narthex": 0.3,
	},
	&"renaissance": {
		"label": "Renaissance",
		"tower": 0.5, "spire": 0.1, "apse": 0.8, "transept": 0.9,
		"aisles": [1, 2], "buttresses": 0.3, "windows": &"round",
		"rose": 0.2, "clerestory": 0.6, "door": [&"portal", &"arched"],
		"towers_roof": [&"pyramid", &"flat"],
		# Florence: an octagonal drum carrying a lantern-topped dome, with
		# radial tribunes of chapels around it.
		"twin_towers": 0.2, "flying": 0.0, "crossing_tower": 0.0,
		"dome": 1.0, "dome_shapes": [&"octagonal"], "ambulatory": 0.5,
		"chapels": [3, 5], "narthex": 0.4, "lantern": 0.95,
	},
	&"russian": {
		"label": "Russian Orthodox",
		"tower": 0.7, "spire": 0.3, "apse": 0.7, "transept": 0.4,
		"aisles": [0, 1], "buttresses": 0.1, "windows": &"round",
		"rose": 0.05, "clerestory": 0.2, "door": [&"arched"],
		"towers_roof": [&"spire", &"belfry"],
		# St Basil's: onion domes over a cluster of chapels.
		"twin_towers": 0.0, "flying": 0.0, "crossing_tower": 0.6,
		"dome": 0.95, "dome_shapes": [&"onion"], "ambulatory": 0.3,
		"chapels": [4, 6, 8], "narthex": 0.3, "lantern": 0.2,
		"chapel_arrangement": &"cluster",
	},
}

## The seed passed here is provisional: ChurchGenerator.generate() is the
## authoritative seeding point and re-seeds both fields. Callers that are about
## to generate can simply use ChurchSpec.new().
func _init(p_seed := 0) -> void:
	seed = p_seed
	rng = RandomNumberGenerator.new()
	rng.seed = seed

