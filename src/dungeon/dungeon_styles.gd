class_name DungeonStyles
extends RefCounted
## What a dungeon is made of, by planner theme.
##
## The planner names a theme and its materials and motifs; it never says what
## those mean in stone. A style is that meaning: which surfaces get which
## material, which ceilings and walls the place prefers, and which set piece
## stands in its landmark rooms. Fantasy first; a theme with no style of its own
## is built as a crypt, which is also VoxelGames' current surface theme.
##
## Bands follow the reading every dungeon keeps (VoxelGames' palette contract):
## the floor lightest and warm, the walls mid and neutral, the ceiling darkest
## and cool, so the three read apart by torchlight.
##
## Material names are the consumer's to map onto its own palette. VoxelGames'
## terrain atlas has `ruin_flagstone`, `wet_stone`, `cliff_rock` and others; a
## name it does not know it paints as its default rock.

const STYLES := {
	&"crypt": {
		"label": "Crypt",
		"bands": {"floor": "ruin_flagstone", "wainscot": "cliff_rock",
			"upper": "cliff_rock", "ceiling": "wet_stone"},
		"accent": "pale_limestone",
		"ceilings": {&"vaulted": 4.0, &"flat": 1.0, &"domed": 1.0},
		"walls": {&"alcove": 3.0, &"columns": 1.0, &"solid": 1.0},
		"floors": {&"flat": 3.0, &"stepped": 1.0},
		"set_pieces": [&"sarcophagus", &"ossuary_wall", &"funeral_statue"],
		"light": &"torch_sconce",
	},
	&"flooded_ruin": {
		"label": "Flooded Ruin",
		"bands": {"floor": "silt", "wainscot": "green_marble",
			"upper": "wet_stone", "ceiling": "dark_rock"},
		"accent": "rotted_timber",
		"ceilings": {&"vaulted": 3.0, &"collapsed": 1.0, &"flat": 1.0},
		"walls": {&"columns": 2.0, &"collapsed": 1.0, &"solid": 1.0},
		"floors": {&"flooded": 1.5, &"flat": 1.5, &"broken": 1.0},
		"set_pieces": [&"sunken_statue", &"broken_aqueduct", &"tide_pool"],
		"light": &"brazier",
	},
	&"crystalline_sanctum": {
		"label": "Crystalline Sanctum",
		"bands": {"floor": "pale_granite", "wainscot": "pale_granite",
			"upper": "quartz", "ceiling": "polished_crystal"},
		"accent": "iron_lattice",
		"ceilings": {&"domed": 3.0, &"enormous": 2.0, &"vaulted": 1.0},
		"walls": {&"columns": 3.0, &"solid": 1.0},
		"floors": {&"flat": 2.0, &"stepped": 2.0},
		"set_pieces": [&"crystal_cluster", &"resonant_chime", &"light_well"],
		"light": &"glow_crystal",
	},
	&"overgrown_library": {
		"label": "Overgrown Library",
		"bands": {"floor": "oak", "wainscot": "oak",
			"upper": "mossed_stone", "ceiling": "wet_slate"},
		"accent": "verdigris_brass",
		"ceilings": {&"vaulted": 2.0, &"flat": 2.0},
		"walls": {&"alcove": 4.0, &"columns": 1.0},
		"floors": {&"flat": 3.0, &"stepped": 1.0},
		"set_pieces": [&"reading_alcove", &"lectern", &"ivy_curtain"],
		"light": &"lantern",
	},
	&"orrery_spire": {
		"label": "Orrery Spire",
		"bands": {"floor": "blue_marble", "wainscot": "blue_marble",
			"upper": "brass", "ceiling": "star_glass"},
		"accent": "lacquered_bronze",
		"ceilings": {&"domed": 4.0, &"enormous": 1.0},
		"walls": {&"columns": 2.0, &"solid": 1.0},
		"floors": {&"stepped": 2.0, &"flat": 2.0},
		"set_pieces": [&"orrery", &"star_chart", &"pendulum"],
		"light": &"star_lamp",
	},
}

const FALLBACK := &"crypt"

## VoxelGames' own surface themes that have a style here. Castle and Cave do
## not yet; caves wait (docs/DUNGEONS.md).
const SURFACE_THEMES := {"Crypt": &"crypt"}


static func ids() -> Array:
	return STYLES.keys()


## The style for a VoxelGames surface theme or a planner theme id, and whether
## it is the theme's own or the fallback.
static func resolve(theme_id: String, surface_theme := "") -> Dictionary:
	# The consumer's own choice of surface, where it made one, outranks the
	# planner's theme: VoxelGames bakes a plan and then says how it is dressed.
	if SURFACE_THEMES.has(surface_theme):
		var mapped: StringName = SURFACE_THEMES[surface_theme]
		return {"id": mapped, "own": true, "style": STYLES[mapped]}
	var id := StringName(theme_id)
	if STYLES.has(id):
		return {"id": id, "own": true, "style": STYLES[id]}
	return {"id": FALLBACK, "own": false, "style": STYLES[FALLBACK]}
