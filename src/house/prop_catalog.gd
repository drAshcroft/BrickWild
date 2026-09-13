class_name PropCatalog
extends RefCounted
## What each prop IS, and how big it actually is.
##
## Two halves, deliberately kept apart:
##   * PROPS below is AUTHORED -- what a piece is for, whether it wants a wall
##     behind it, how much room a person needs in front of it to use it. No
##     amount of measuring can tell you that a bed wants its head to a wall.
##   * assets/props/catalog.json is MEASURED, written by
##     tools/build_prop_catalog.gd from the imported meshes. Sizes are never
##     guessed here, because a guessed footprint is how furniture ends up half
##     inside a wall, and the house suite re-measures the meshes to prove the
##     file still describes them.
##
## The temple generator draws on the same catalogue: a cauldron is a brazier
## when it stands in a nave, and a cage is a cage wherever it is. Only the
## rules that place them differ.
##
## Local axes of a placed prop: it faces local -Z (the direction a person using
## it stands), so a piece against a wall has the wall behind it at +Z. `face`
## corrects a model that was authored pointing some other way.

const SOURCE_ASSET_ROOT := "res://assets/props/"
const ADDON_ASSET_ROOT := "res://addons/big_glade/assets/props/"
const CATALOG_FILE := "catalog.json"

## The art packs the props come from: which folder, and what the models are
## shipped as. A prop names its pack in PROPS; anything that does not name one
## is in `fantasy`, which is where every prop was until the dungeon kit arrived.
##
## Four packs rather than one because they ship different formats -- Quaternius
## exports the Fantasy Props MegaKit as glTF and the Dungeon Kit as FBX only --
## and because they collide: the fantasy and dungeon kits each contain a
## Barrel, a Crate and a Chest, and the two nature kits each contain a
## DeadTree_1. Every file outside `fantasy` is prefixed on disk so a catalogue
## key is still globally unique.
##
## `nature` is the Nature Kit (birch, maple, the flower clumps) and `wild` the
## Stylized Nature MegaKit (the common tree, the pines, the twisted trees, the
## pebbles and the ground cover). `plants` marks those two as things that
## grow, which is what earns a measured canopy and trunk. A village plants
## from one culture's palette (VILLAGES 8), not from both kits at once.
const PACKS := {
	"fantasy": {"dir": "fantasy", "ext": "gltf"},
	"dungeon": {"dir": "dungeon", "ext": "fbx"},
	"nature": {"dir": "nature", "ext": "gltf", "plants": true},
	"wild": {"dir": "wild", "ext": "gltf", "plants": true},
}
const DEFAULT_PACK := "fantasy"

static var _resolved_asset_root := ""

# ---- placement rules a prop can carry ----
const WALL := "wall"              # wants its back to a wall
const CORNER := "corner"          # happiest tucked into a corner
const SURFACE := "surface"        # has a top other things can be set on
const ON_SURFACE := "on_surface"  # must be set ON a surface, never on the floor
const WALL_MOUNTED := "wall_mounted"   # hangs on a wall, no footprint on the floor
const CEILING := "ceiling"        # hangs from the ceiling
const LIGHT := "light"            # counts toward a room being lit
const PLANT := "plant"            # grows: measured as a canopy and a trunk
const GROUND := "ground"          # lies on the ground and is walked over

## key -> {cat, tags, zone, face, affinity}
##   cat   what the piece is, which is what a room's recipe asks for
##   zone  metres of clear floor a person needs in front of it to use it;
##         0 means it is furniture you walk past, not furniture you use
##   face  yaw correction, radians, for a model authored facing the wrong way.
##         Every wall-mounted prop in this pack carries one: they are modelled
##         with their mass on the +Z side of their mounting point, and the
##         convention here is that a prop faces -Z, so without the half turn a
##         shelf hangs inside the wall it is screwed to.
##   affinity  optional; see affinity() below. Where the piece WANTS to be,
##         as opposed to where it merely fits.
const PROPS := {
	# ---- beds ----
	# These models have their headboard at raw -Z; the planned back is +Z.
	"Bed_Twin1": {"cat": "bed", "tags": [WALL], "zone": 0.75, "face": PI, "affinity": {"avoid_window_wall": true}},
	"Bed_Twin2": {"cat": "bed", "tags": [WALL], "zone": 0.75, "face": PI, "affinity": {"avoid_window_wall": true}},

	# ---- tables and seats ----
	"Table_Large": {"cat": "table", "tags": [SURFACE], "zone": 0.0, "affinity": {"focus": "hearth", "face": "focus"}},
	"Workbench": {"cat": "workbench", "tags": [WALL, SURFACE], "zone": 0.9, "affinity": {"daylight": 1.0}},
	"Workbench_Drawers": {"cat": "workbench", "tags": [WALL, SURFACE], "zone": 0.9, "affinity": {"daylight": 1.0}},
	"Chair_1": {"cat": "seat", "tags": [], "zone": 0.55},
	"Stool": {"cat": "seat", "tags": [], "zone": 0.5},
	"Bench": {"cat": "bench", "tags": [], "zone": 0.55},

	# ---- storage ----
	"Cabinet": {"cat": "storage", "tags": [WALL, SURFACE], "zone": 0.7},
	"Bookcase_2": {"cat": "bookcase", "tags": [WALL], "zone": 0.7, "affinity": {"daylight": -1.0, "far": ["hearth"], "avoid_hearth_wall": true}},
	"Chest_Wood": {"cat": "chest", "tags": [WALL], "zone": 0.6, "affinity": {"away_from_doors": true}},
	"Nightstand_Shelf": {"cat": "nightstand", "tags": [WALL, SURFACE], "zone": 0.4},
	"Barrel": {"cat": "barrel", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true, "near": ["counter"]}},
	"Barrel_Apples": {"cat": "barrel", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true, "near": ["counter"]}},
	"Barrel_Holder": {"cat": "barrel", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true, "near": ["counter"]}},
	"Crate_Wooden": {"cat": "crate", "tags": [CORNER, SURFACE], "zone": 0.0, "affinity": {"away_from_doors": true}},
	"Crate_Metal": {"cat": "crate", "tags": [CORNER, SURFACE], "zone": 0.0, "affinity": {"away_from_doors": true}},
	"FarmCrate_Apple": {"cat": "crate", "tags": [CORNER, SURFACE], "zone": 0.0, "affinity": {"away_from_doors": true}},
	"FarmCrate_Carrot": {"cat": "crate", "tags": [CORNER, SURFACE], "zone": 0.0, "affinity": {"away_from_doors": true}},
	"FarmCrate_Empty": {"cat": "crate", "tags": [CORNER, SURFACE], "zone": 0.0, "affinity": {"away_from_doors": true}},

	# ---- hearth and kitchen ----
	"Cauldron": {"cat": "hearth", "tags": [WALL], "zone": 0.8},
	"Pot_1": {"cat": "cookware", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true}},
	"Bucket_Metal": {"cat": "cookware", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true}},
	"Bucket_Wooden_1": {"cat": "bucket", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true}},

	# ---- trade fittings ----
	"Anvil": {"cat": "anvil", "tags": [], "zone": 0.9, "affinity": {"near": ["hearth"]}},
	"Anvil_Log": {"cat": "anvil", "tags": [], "zone": 0.9, "affinity": {"near": ["hearth"]}},
	# A pickaxe is a metre of haft: it leans in a corner, and the "tool" category
	# is placed ON a surface, so it cannot go there.
	"Pickaxe_Bronze": {"cat": "big_tool", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true}},
	"WeaponStand": {"cat": "stand", "tags": [WALL], "zone": 0.6},
	"Dummy": {"cat": "stand", "tags": [], "zone": 0.7},
	"BookStand": {"cat": "lectern", "tags": [SURFACE], "zone": 0.7, "affinity": {"daylight": 1.0}},
	"Stall_Empty": {"cat": "counter", "tags": [WALL, SURFACE], "zone": 0.9},
	"Stall_Cart_Empty": {"cat": "stall", "tags": [], "zone": 0.9},
	"Bag": {"cat": "sack", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true}},

	# ---- shelves and wall furniture ----
	"Shelf_Simple": {"cat": "shelf", "tags": [WALL_MOUNTED, SURFACE], "zone": 0.0, "face": PI, "affinity": {"over": ["workbench", "counter"]}},
	"Shelf_Arch": {"cat": "shelf", "tags": [WALL_MOUNTED, SURFACE], "zone": 0.0, "face": PI, "affinity": {"over": ["workbench", "counter"]}},
	"Shelf_Small_Bottles": {"cat": "shelf", "tags": [WALL_MOUNTED], "zone": 0.0, "face": PI, "affinity": {"over": ["workbench", "counter"]}},
	"Peg_Rack": {"cat": "rack", "tags": [WALL_MOUNTED], "zone": 0.0, "face": PI},
	"Shield_Wooden": {"cat": "trophy", "tags": [WALL_MOUNTED], "zone": 0.0, "face": PI},
	"Banner_1": {"cat": "banner", "tags": [WALL_MOUNTED], "zone": 0.0, "face": PI},
	"Banner_2": {"cat": "banner", "tags": [WALL_MOUNTED], "zone": 0.0, "face": PI},
	"Banner_1_Cloth": {"cat": "banner", "tags": [WALL_MOUNTED], "zone": 0.0, "face": PI},
	"Banner_2_Cloth": {"cat": "banner", "tags": [WALL_MOUNTED], "zone": 0.0, "face": PI},
	"Lantern_Wall": {"cat": "sconce", "tags": [WALL_MOUNTED, LIGHT], "zone": 0.0, "face": PI, "affinity": {"flank": "door"}},
	"Torch_Metal": {"cat": "sconce", "tags": [WALL_MOUNTED, LIGHT], "zone": 0.0, "face": PI, "affinity": {"flank": "door"}},
	"Chandelier": {"cat": "chandelier", "tags": [CEILING, LIGHT], "zone": 0.0, "affinity": {"over": ["table"]}},
	# Its own category: a candelabrum is a metre and a third of standing iron, so
	# it cannot join "candle", which every recipe places ON a table.
	"CandleStick_Stand": {"cat": "candelabrum", "tags": [LIGHT], "zone": 0.0},

	# ---- what a temple is fitted out with ----
	"Cage_Small": {"cat": "cage", "tags": [], "zone": 0.6},
	"Chain_Coil": {"cat": "chain", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true}},
	"Rope_1": {"cat": "chain", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true}},
	"Rope_2": {"cat": "chain", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true}},
	"Rope_3": {"cat": "chain", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true}},
	"Vase_Rubble_Medium": {"cat": "rubble", "tags": [CORNER], "zone": 0.0, "affinity": {"away_from_doors": true}},
	"Table_Knife": {"cat": "blade", "tags": [ON_SURFACE], "zone": 0.0},
	"Sword_Bronze": {"cat": "blade", "tags": [ON_SURFACE], "zone": 0.0},
	"Axe_Bronze": {"cat": "blade", "tags": [ON_SURFACE], "zone": 0.0},

	# ---- things that live on a surface ----
	"Mug": {"cat": "tableware", "tags": [ON_SURFACE], "zone": 0.0},
	"Chalice": {"cat": "tableware", "tags": [ON_SURFACE], "zone": 0.0},
	"Table_Plate": {"cat": "tableware", "tags": [ON_SURFACE], "zone": 0.0},
	"Table_Fork": {"cat": "tableware", "tags": [ON_SURFACE], "zone": 0.0},
	"Table_Spoon": {"cat": "tableware", "tags": [ON_SURFACE], "zone": 0.0},
	"Pot_1_Lid": {"cat": "tableware", "tags": [ON_SURFACE], "zone": 0.0},
	"Bottle_1": {"cat": "tableware", "tags": [ON_SURFACE], "zone": 0.0},
	"Candle_1": {"cat": "candle", "tags": [ON_SURFACE, LIGHT], "zone": 0.0},
	"CandleStick": {"cat": "candle", "tags": [ON_SURFACE, LIGHT], "zone": 0.0},
	"CandleStick_Triple": {"cat": "candle", "tags": [ON_SURFACE, LIGHT], "zone": 0.0},
	"Candle_2": {"cat": "candle", "tags": [ON_SURFACE, LIGHT], "zone": 0.0},
	"Book_Stack_1": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},
	"Book_Stack_2": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},
	"BookGroup_Small_1": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},
	"Book_5": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},
	"Book_7": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},
	"Book_Simplified_Single": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},
	"BookGroup_Small_2": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},
	"BookGroup_Small_3": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},
	"BookGroup_Medium_1": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},
	"BookGroup_Medium_2": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},
	"BookGroup_Medium_3": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},
	"Scroll_1": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},
	"Scroll_2": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},
	"Potion_1": {"cat": "alchemy", "tags": [ON_SURFACE], "zone": 0.0},
	"Potion_2": {"cat": "alchemy", "tags": [ON_SURFACE], "zone": 0.0},
	"SmallBottles_1": {"cat": "alchemy", "tags": [ON_SURFACE], "zone": 0.0},
	"SmallBottle": {"cat": "alchemy", "tags": [ON_SURFACE], "zone": 0.0},
	"Potion_4": {"cat": "alchemy", "tags": [ON_SURFACE], "zone": 0.0},
	"Vase_2": {"cat": "vase", "tags": [ON_SURFACE], "zone": 0.0},
	"Vase_4": {"cat": "vase", "tags": [ON_SURFACE], "zone": 0.0},
	"Whetstone": {"cat": "tool", "tags": [ON_SURFACE], "zone": 0.0},
	"Carrot": {"cat": "food", "tags": [ON_SURFACE], "zone": 0.0},
	"Key_Metal": {"cat": "trinket", "tags": [ON_SURFACE], "zone": 0.0},
	"Coin_Pile": {"cat": "trinket", "tags": [ON_SURFACE], "zone": 0.0},
	"Coin_Pile_2": {"cat": "trinket", "tags": [ON_SURFACE], "zone": 0.0},
	"Coin": {"cat": "trinket", "tags": [ON_SURFACE], "zone": 0.0},
	"Key_Gold": {"cat": "trinket", "tags": [ON_SURFACE], "zone": 0.0},
	"Pouch_Large": {"cat": "trinket", "tags": [ON_SURFACE], "zone": 0.0},

	# ---- the Dungeon Kit ----
	# A second pack (PACKS above), for the things a church and a castle want and
	# the MegaKit has none of: statues, an altar rail, standing columns, wall
	# flags, floor candles.
	#
	# Their categories are deliberately their OWN. A dungeon flag is half again
	# the size of a MegaKit banner and cut from a chunkier pack; dropping it into
	# "banner" would let a hotel lobby draw one, and the two art styles would be
	# in the same room by accident rather than by choice. Only the church and
	# castle furnishers ask for these categories.
	"Dungeon_Statue_Stag": {"pack": "dungeon", "cat": "statue", "tags": [], "zone": 0.8},
	"Dungeon_Statue_Fox": {"pack": "dungeon", "cat": "statue", "tags": [], "zone": 0.8},
	"Dungeon_Column_Round": {"pack": "dungeon", "cat": "column", "tags": [], "zone": 0.0},
	"Dungeon_Column_Square": {"pack": "dungeon", "cat": "column", "tags": [], "zone": 0.0},
	"Dungeon_Column_Round_Short": {"pack": "dungeon", "cat": "column", "tags": [], "zone": 0.0},
	"Dungeon_Rail_Straight": {"pack": "dungeon", "cat": "rail", "tags": [], "zone": 0.0},
	"Dungeon_Rail_Corner": {"pack": "dungeon", "cat": "rail", "tags": [], "zone": 0.0},
	"Dungeon_Rail_Divider": {"pack": "dungeon", "cat": "rail", "tags": [], "zone": 0.0},
	# Modelled centred on their own mounting point, so no `face` correction --
	# unlike every wall prop in the MegaKit. PropCatalog.mount_yaw() reads the
	# difference rather than assuming it.
	"Dungeon_Flag_Wall": {"pack": "dungeon", "cat": "war_banner", "tags": [WALL_MOUNTED], "zone": 0.0},
	"Dungeon_Flag_Wall2": {"pack": "dungeon", "cat": "war_banner", "tags": [WALL_MOUNTED], "zone": 0.0},
	"Dungeon_Flag_GothicArch": {"pack": "dungeon", "cat": "arch_flag", "tags": [WALL_MOUNTED], "zone": 0.0},
	"Dungeon_Flag_RoundArch": {"pack": "dungeon", "cat": "arch_flag", "tags": [WALL_MOUNTED], "zone": 0.0},
	"Dungeon_Candles_1": {"pack": "dungeon", "cat": "floor_candles", "tags": [LIGHT], "zone": 0.0},
	"Dungeon_Candles_2": {"pack": "dungeon", "cat": "floor_candles", "tags": [LIGHT], "zone": 0.0},
	"Dungeon_Torch": {"pack": "dungeon", "cat": "wall_torch", "tags": [WALL_MOUNTED, LIGHT], "zone": 0.0},
	"Dungeon_Bookcase_Empty": {"pack": "dungeon", "cat": "tall_bookcase", "tags": [WALL], "zone": 0.7},
	"Dungeon_Bookcase_Full": {"pack": "dungeon", "cat": "tall_bookcase", "tags": [WALL], "zone": 0.7},
	"Dungeon_Chest": {"pack": "dungeon", "cat": "reliquary", "tags": [WALL], "zone": 0.6},
	"Dungeon_Chest_Gold": {"pack": "dungeon", "cat": "reliquary", "tags": [WALL], "zone": 0.6},
	"Dungeon_Cart": {"pack": "dungeon", "cat": "wagon", "tags": [], "zone": 0.9},
	"Dungeon_Barrel": {"pack": "dungeon", "cat": "cask", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Crate": {"pack": "dungeon", "cat": "cask", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Pot1": {"pack": "dungeon", "cat": "urn", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Pot2": {"pack": "dungeon", "cat": "urn", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Pot3": {"pack": "dungeon", "cat": "urn", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Pot1_Broken": {"pack": "dungeon", "cat": "urn", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Pot2_Broken": {"pack": "dungeon", "cat": "urn", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Pot3_Broken": {"pack": "dungeon", "cat": "urn", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Brick": {"pack": "dungeon", "cat": "rubble", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Bricks": {"pack": "dungeon", "cat": "rubble", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Skull": {"pack": "dungeon", "cat": "relic", "tags": [], "zone": 0.0},
	"Dungeon_Trapdoor": {"pack": "dungeon", "cat": "hatch", "tags": [], "zone": 0.0},
	"Dungeon_BearTrap_Closed": {"pack": "dungeon", "cat": "trap", "tags": [], "zone": 0.0},
	"Dungeon_BearTrap_Open": {"pack": "dungeon", "cat": "trap", "tags": [], "zone": 0.0},

	# ---- what grows (VILLAGES 7, 8) ----
	# Two packs, because a culture plants from one palette and not from both:
	# a norse edge is birch and pine, a moorish one twisted trees and pebbles.
	# Every one of these carries a measured `canopy` and `trunk` as well as a
	# box, because a bounding box is the wrong shape for a tree -- see
	# SceneBounds.radii_of_node(). GROUND marks the ones a person walks over
	# rather than round.
	# the Nature Kit's own trees: the birch and the maple of an english,
	# frankish or norse edge
	"Nature_BirchTree_1": {"pack": "nature", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Nature_BirchTree_2": {"pack": "nature", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Nature_BirchTree_3": {"pack": "nature", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Nature_BirchTree_4": {"pack": "nature", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Nature_BirchTree_5": {"pack": "nature", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Nature_MapleTree_1": {"pack": "nature", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Nature_MapleTree_2": {"pack": "nature", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Nature_MapleTree_3": {"pack": "nature", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Nature_MapleTree_4": {"pack": "nature", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Nature_MapleTree_5": {"pack": "nature", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	# a blighted edge, and the one dead tree at the back of anybody's wood
	"Nature_DeadTree_1": {"pack": "nature", "cat": "dead_tree", "tags": [PLANT], "zone": 0.0},
	"Nature_DeadTree_10": {"pack": "nature", "cat": "dead_tree", "tags": [PLANT], "zone": 0.0},
	"Nature_DeadTree_2": {"pack": "nature", "cat": "dead_tree", "tags": [PLANT], "zone": 0.0},
	"Nature_DeadTree_3": {"pack": "nature", "cat": "dead_tree", "tags": [PLANT], "zone": 0.0},
	"Nature_DeadTree_4": {"pack": "nature", "cat": "dead_tree", "tags": [PLANT], "zone": 0.0},
	"Nature_DeadTree_5": {"pack": "nature", "cat": "dead_tree", "tags": [PLANT], "zone": 0.0},
	"Nature_DeadTree_6": {"pack": "nature", "cat": "dead_tree", "tags": [PLANT], "zone": 0.0},
	"Nature_DeadTree_7": {"pack": "nature", "cat": "dead_tree", "tags": [PLANT], "zone": 0.0},
	"Nature_DeadTree_8": {"pack": "nature", "cat": "dead_tree", "tags": [PLANT], "zone": 0.0},
	"Nature_DeadTree_9": {"pack": "nature", "cat": "dead_tree", "tags": [PLANT], "zone": 0.0},
	# hedges and the flowering bush either side of a garden path
	"Nature_Bush": {"pack": "nature", "cat": "bush", "tags": [PLANT], "zone": 0.0},
	"Nature_Bush_Flowers": {"pack": "nature", "cat": "bush", "tags": [PLANT], "zone": 0.0},
	"Nature_Bush_Large": {"pack": "nature", "cat": "bush", "tags": [PLANT], "zone": 0.0},
	"Nature_Bush_Large_Flowers": {"pack": "nature", "cat": "bush", "tags": [PLANT], "zone": 0.0},
	"Nature_Bush_Small": {"pack": "nature", "cat": "bush", "tags": [PLANT], "zone": 0.0},
	"Nature_Bush_Small_Flowers": {"pack": "nature", "cat": "bush", "tags": [PLANT], "zone": 0.0},
	"Nature_Flower_1": {"pack": "nature", "cat": "flower", "tags": [PLANT, GROUND], "zone": 0.0},
	"Nature_Flower_1_Clump": {"pack": "nature", "cat": "flower", "tags": [PLANT, GROUND], "zone": 0.0},
	"Nature_Flower_2": {"pack": "nature", "cat": "flower", "tags": [PLANT, GROUND], "zone": 0.0},
	"Nature_Flower_2_Clump": {"pack": "nature", "cat": "flower", "tags": [PLANT, GROUND], "zone": 0.0},
	"Nature_Flower_3_Clump": {"pack": "nature", "cat": "flower", "tags": [PLANT, GROUND], "zone": 0.0},
	"Nature_Flower_4_Clump": {"pack": "nature", "cat": "flower", "tags": [PLANT, GROUND], "zone": 0.0},
	"Nature_Flower_5_Clump": {"pack": "nature", "cat": "flower", "tags": [PLANT, GROUND], "zone": 0.0},
	"Nature_Grass_Large": {"pack": "nature", "cat": "grass", "tags": [PLANT, GROUND], "zone": 0.0},
	"Nature_Grass_Large_Extruded": {"pack": "nature", "cat": "grass", "tags": [PLANT, GROUND], "zone": 0.0},
	"Nature_Grass_Small": {"pack": "nature", "cat": "grass", "tags": [PLANT, GROUND], "zone": 0.0},
	# ---- the Stylized Nature MegaKit ----
	# the common tree of the green, the pines of an alpine edge, and the
	# twisted trees of a moorish or blighted one
	"Wild_CommonTree_1": {"pack": "wild", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Wild_CommonTree_2": {"pack": "wild", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Wild_CommonTree_3": {"pack": "wild", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Wild_CommonTree_4": {"pack": "wild", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Wild_CommonTree_5": {"pack": "wild", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Wild_Pine_1": {"pack": "wild", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Wild_Pine_2": {"pack": "wild", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Wild_Pine_3": {"pack": "wild", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Wild_Pine_4": {"pack": "wild", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Wild_Pine_5": {"pack": "wild", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Wild_TwistedTree_1": {"pack": "wild", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Wild_TwistedTree_2": {"pack": "wild", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Wild_TwistedTree_3": {"pack": "wild", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Wild_TwistedTree_4": {"pack": "wild", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Wild_TwistedTree_5": {"pack": "wild", "cat": "tree", "tags": [PLANT], "zone": 0.0},
	"Wild_DeadTree_1": {"pack": "wild", "cat": "dead_tree", "tags": [PLANT], "zone": 0.0},
	"Wild_DeadTree_2": {"pack": "wild", "cat": "dead_tree", "tags": [PLANT], "zone": 0.0},
	"Wild_DeadTree_3": {"pack": "wild", "cat": "dead_tree", "tags": [PLANT], "zone": 0.0},
	"Wild_DeadTree_4": {"pack": "wild", "cat": "dead_tree", "tags": [PLANT], "zone": 0.0},
	"Wild_DeadTree_5": {"pack": "wild", "cat": "dead_tree", "tags": [PLANT], "zone": 0.0},
	"Wild_Bush_Common": {"pack": "wild", "cat": "bush", "tags": [PLANT], "zone": 0.0},
	"Wild_Bush_Common_Flowers": {"pack": "wild", "cat": "bush", "tags": [PLANT], "zone": 0.0},
	"Wild_Fern_1": {"pack": "wild", "cat": "plant", "tags": [PLANT], "zone": 0.0},
	"Wild_Plant_1": {"pack": "wild", "cat": "plant", "tags": [PLANT], "zone": 0.0},
	"Wild_Plant_1_Big": {"pack": "wild", "cat": "plant", "tags": [PLANT], "zone": 0.0},
	"Wild_Plant_7": {"pack": "wild", "cat": "plant", "tags": [PLANT], "zone": 0.0},
	"Wild_Plant_7_Big": {"pack": "wild", "cat": "plant", "tags": [PLANT], "zone": 0.0},
	"Wild_Flower_3_Group": {"pack": "wild", "cat": "flower", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Flower_3_Single": {"pack": "wild", "cat": "flower", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Flower_4_Group": {"pack": "wild", "cat": "flower", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Flower_4_Single": {"pack": "wild", "cat": "flower", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Grass_Common_Short": {"pack": "wild", "cat": "grass", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Grass_Common_Tall": {"pack": "wild", "cat": "grass", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Grass_Wispy_Short": {"pack": "wild", "cat": "grass", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Grass_Wispy_Tall": {"pack": "wild", "cat": "grass", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Clover_1": {"pack": "wild", "cat": "ground_cover", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Clover_2": {"pack": "wild", "cat": "ground_cover", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Petal_1": {"pack": "wild", "cat": "ground_cover", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Petal_2": {"pack": "wild", "cat": "ground_cover", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Petal_3": {"pack": "wild", "cat": "ground_cover", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Petal_4": {"pack": "wild", "cat": "ground_cover", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Petal_5": {"pack": "wild", "cat": "ground_cover", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Mushroom_Common": {"pack": "wild", "cat": "mushroom", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Mushroom_Laetiporus": {"pack": "wild", "cat": "mushroom", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Rock_Medium_1": {"pack": "wild", "cat": "rock", "tags": [PLANT], "zone": 0.0},
	"Wild_Rock_Medium_2": {"pack": "wild", "cat": "rock", "tags": [PLANT], "zone": 0.0},
	"Wild_Rock_Medium_3": {"pack": "wild", "cat": "rock", "tags": [PLANT], "zone": 0.0},
	# what the ground is made of where it is not grass: pebbles on a
	# moorish verge, stepping stones over a wet one
	"Wild_Pebble_Round_1": {"pack": "wild", "cat": "pebble", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Pebble_Round_2": {"pack": "wild", "cat": "pebble", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Pebble_Round_3": {"pack": "wild", "cat": "pebble", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Pebble_Round_4": {"pack": "wild", "cat": "pebble", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Pebble_Round_5": {"pack": "wild", "cat": "pebble", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Pebble_Square_1": {"pack": "wild", "cat": "pebble", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Pebble_Square_2": {"pack": "wild", "cat": "pebble", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Pebble_Square_3": {"pack": "wild", "cat": "pebble", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Pebble_Square_4": {"pack": "wild", "cat": "pebble", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Pebble_Square_5": {"pack": "wild", "cat": "pebble", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_Pebble_Square_6": {"pack": "wild", "cat": "pebble", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_RockPath_Round_Small_1": {"pack": "wild", "cat": "stepping_stone", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_RockPath_Round_Small_2": {"pack": "wild", "cat": "stepping_stone", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_RockPath_Round_Small_3": {"pack": "wild", "cat": "stepping_stone", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_RockPath_Round_Thin": {"pack": "wild", "cat": "stepping_stone", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_RockPath_Round_Wide": {"pack": "wild", "cat": "stepping_stone", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_RockPath_Square_Small_1": {"pack": "wild", "cat": "stepping_stone", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_RockPath_Square_Small_2": {"pack": "wild", "cat": "stepping_stone", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_RockPath_Square_Small_3": {"pack": "wild", "cat": "stepping_stone", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_RockPath_Square_Thin": {"pack": "wild", "cat": "stepping_stone", "tags": [PLANT, GROUND], "zone": 0.0},
	"Wild_RockPath_Square_Wide": {"pack": "wild", "cat": "stepping_stone", "tags": [PLANT, GROUND], "zone": 0.0},
}

## Measured sizes, loaded once and shared. Static so the whole sweep pays for
## the JSON parse a single time.
static var _sizes: Dictionary = {}


## BigGlade can run from this repository or from its conventional Godot addon
## location. Resolve once from the catalogue itself so callers do not need to
## configure paths and another project's unrelated res://assets folder cannot
## be mistaken for BigGlade's art when the addon is installed.
static func asset_root() -> String:
	if not _resolved_asset_root.is_empty():
		return _resolved_asset_root
	for root in [ADDON_ASSET_ROOT, SOURCE_ASSET_ROOT]:
		if FileAccess.file_exists(root + CATALOG_FILE):
			_resolved_asset_root = root
			return root
	# Keep the conventional package path in the error that follows. This also
	# makes scene_path() deterministic when an installation is incomplete.
	return ADDON_ASSET_ROOT


static func catalog_path() -> String:
	return asset_root() + CATALOG_FILE


static func _load() -> void:
	if not _sizes.is_empty():
		return
	var path := catalog_path()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error(("PropCatalog: no measured catalogue at %s -- install the complete addon "
			+ "or run tools/build_prop_catalog.gd in the source project") % path)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_sizes = parsed


static func known(key: String) -> bool:
	_load()
	return PROPS.has(key) and _sizes.has(key)


## Every authored prop, in a stable order.
static func keys() -> Array[String]:
	var out: Array[String] = []
	for k in PROPS:
		out.append(k)
	out.sort()
	return out


## Every prop of a category, in a stable order.
static func of_category(cat: String) -> Array[String]:
	var out: Array[String] = []
	for k in keys():
		if PROPS[k]["cat"] == cat:
			out.append(k)
	return out


## Measured bounding size in metres.
static func size(key: String) -> Vector3:
	_load()
	if not _sizes.has(key):
		return Vector3.ZERO
	var s: Array = _sizes[key]["size"]
	return Vector3(float(s[0]), float(s[1]), float(s[2]))


## Offset from the model's own origin to the centre of its bounding box. A
## wall shelf's origin is its mounting point, not its middle, so a placer that
## ignores this hangs the shelf half a metre off the wall.
static func centre_offset(key: String) -> Vector3:
	_load()
	if not _sizes.has(key):
		return Vector3.ZERO
	var c: Array = _sizes[key]["centre"]
	return Vector3(float(c[0]), float(c[1]), float(c[2]))


## Plan footprint, before any yaw is applied: (across, deep).
static func footprint(key: String) -> Vector2:
	var s: Vector3 = size(key)
	return Vector2(s.x, s.z)


## Legacy shortcut for callers restricted to quarter-turn yaws.
static func footprint_yawed(key: String, yaw: float) -> Vector2:
	var f: Vector2 = footprint(key)
	if absf(sin(yaw)) > 0.5:
		return Vector2(f.y, f.x)
	return f


## Plan footprint after ANY yaw: the axis-aligned box the turned piece needs.
##
## Polygon rooms and ranges on a castle ridge place props at arbitrary angles.
## A quarter-turn shortcut can understate their actual measured envelope.
static func footprint_rotated(key: String, yaw: float) -> Vector2:
	var f: Vector2 = footprint(key)
	var c: float = absf(cos(yaw))
	var s: float = absf(sin(yaw))
	return Vector2(f.x * c + f.y * s, f.x * s + f.y * c)


static func height(key: String) -> float:
	return size(key).y


## Height of the top a prop offers to things set on it, or 0 if it offers none.
static func surface_height(key: String) -> float:
	return height(key) if has_tag(key, SURFACE) else 0.0


## Where the model's feet are relative to its own origin. A wall shelf is
## modelled hanging below its mounting point and a couple of the benches sit
## above theirs; the assembler subtracts this so everything lands on the floor.
static func floor_offset(key: String) -> float:
	_load()
	if not _sizes.has(key):
		return 0.0
	return float(_sizes[key]["floor"])


## Where the flame is, relative to the model's own origin: the measured top
## centre of the model. LightKit hangs the OmniLight3D there. Falls back to
## the top of the bounding box for a catalogue measured before LAY-011.
static func light_offset(key: String) -> Vector3:
	_load()
	if not _sizes.has(key):
		return Vector3.ZERO
	if _sizes[key].has("light"):
		var l: Array = _sizes[key]["light"]
		return Vector3(float(l[0]), float(l[1]), float(l[2]))
	var c: Vector3 = centre_offset(key)
	return Vector3(c.x, floor_offset(key) + height(key), c.z)


static func category(key: String) -> String:
	return PROPS[key]["cat"] if PROPS.has(key) else ""


static func has_tag(key: String, tag: String) -> bool:
	return PROPS.has(key) and tag in PROPS[key]["tags"]


## Metres of clear floor a person needs in front of the piece to use it.
static func zone_depth(key: String) -> float:
	return float(PROPS[key]["zone"]) if PROPS.has(key) else 0.0


## What a piece WANTS, over and above fitting: the wall with the daylight on
## it, the corner nobody walks through, the space above the bench it serves.
## Optional, and read only by HouseFurnisher._affinity(), which turns it into
## one number per candidate position. Keys, all optional:
##   near/far            [category] -- be close to / away from these pieces
##   daylight            +1 wants a window wall, -1 wants a dark one
##   away_from_doors     true for the clutter that belongs out of the traffic
##   avoid_window_wall   true when the piece would block the light
##   avoid_hearth_wall   true when heat would ruin it
##   focus               "hearth" -- stand off centre, toward the fire
##   over                [category] -- hang above one of these
##   flank               "door" -- come in a mirrored pair about the opening
##   near: ["focus"]     stand close to HousePlan.focus, in the focus room
##   face: "focus"       lie broadside to the focus: a table's long axis at
##                       right angles to the focus's facing (INT-002)
static func affinity(key: String) -> Dictionary:
	return PROPS[key].get("affinity", {}) if PROPS.has(key) else {}


static func face_offset(key: String) -> float:
	return float(PROPS[key].get("face", 0.0)) if PROPS.has(key) else 0.0


## Does this prop stand on the floor and get in a person's way? Ground cover
## does not: you walk over clover, pebbles and stepping stones, and a village
## whose verges were obstacles would have no walkable verges.
static func blocks_floor(key: String) -> bool:
	return not (has_tag(key, WALL_MOUNTED) or has_tag(key, CEILING)
		or has_tag(key, ON_SURFACE) or has_tag(key, GROUND))


## The crown of a plant, as a radius about its own trunk, in metres; 0 for
## anything that is not one. A tree's bounding box is mostly air, so this --
## not the box -- is what the dressing check holds off the roofs.
static func canopy(key: String) -> float:
	_load()
	return float(_sizes[key].get("canopy", 0.0)) if _sizes.has(key) else 0.0


## The stem where it meets the ground, as a radius. This is a tree's real
## footprint: what stands in the road, and what the walk grid must go round.
static func trunk(key: String) -> float:
	_load()
	return float(_sizes[key].get("trunk", 0.0)) if _sizes.has(key) else 0.0


## Everything that grows, in a stable order -- what a culture's palette is
## drawn from (VILLAGES 8).
static func plants() -> Array[String]:
	var out: Array[String] = []
	for k in keys():
		if has_tag(k, PLANT):
			out.append(k)
	return out


## How far a piece may be scaled down when the room it is going in cannot take
## it at full size.
##
## A fantasy table is whatever the carpenter made, so a smaller one is simply a
## smaller one -- but a bed is a body long and a barrel holds what it holds, so
## most things are not on this list. Anything absent is built at the size it
## was modelled, and the checks hold it to that.
const SHRINKABLE := {
	"table": 0.62, "bench": 0.6, "workbench": 0.72, "counter": 0.7,
	"bookcase": 0.8, "storage": 0.8,
}


static func min_scale(key: String) -> float:
	return float(SHRINKABLE.get(category(key), 1.0))


static func pack(key: String) -> String:
	return String(PROPS[key].get("pack", DEFAULT_PACK)) if PROPS.has(key) \
		else DEFAULT_PACK


## Does this pack hold things that grow? Only those get a canopy and a trunk
## measured (tools/build_prop_catalog.gd); a barrel has neither.
static func is_plant_pack(pack_name: String) -> bool:
	return bool(PACKS.get(pack_name, {}).get("plants", false))


static func scene_path(key: String) -> String:
	var row: Dictionary = PACKS.get(pack(key), PACKS[DEFAULT_PACK])
	return asset_root() + "%s/%s.%s" % [row["dir"], key, row["ext"]]


## The yaw that points a prop face down `d` (a direction in plan). A prop faces
## its own local -Z, which a yaw of y turns to (-sin y, -cos y).
static func yaw_facing(d: Vector2) -> float:
	if d.length_squared() < 0.000001:
		return 0.0
	return atan2(-d.x, -d.y)


## The yaw to store for a wall piece so that it ends up facing `inward`, off the
## wall it hangs on.
##
## Every wall prop in the MegaKit is modelled with its mass behind its mounting
## point and carries a half-turn `face` correction; the Dungeon Kit flags are
## modelled centred on theirs and carry none. Reading the correction from the
## catalogue rather than assuming PI is what lets both hang the right way round
## on the same wall.
static func mount_yaw(key: String, inward: Vector2) -> float:
	return yaw_facing(inward) - face_offset(key)


## Where a placed prop mass actually sits in plan, which is not always where its
## origin is: the stag statue carries its mass half a metre off its own pivot,
## and a rect centred on the pivot describes a stag that is not there.
static func plan_centre(key: String, pos: Vector3, yaw: float, scale: float) -> Vector2:
	var c: Vector3 = centre_offset(key) * scale
	var turned := Vector2(c.x * cos(yaw) + c.z * sin(yaw),
		-c.x * sin(yaw) + c.z * cos(yaw))
	return Vector2(pos.x, pos.z) + turned


## HousePlan furniture records measured footprint centres; the other family
## dressing APIs record model origins. Convert only the HousePlan convention
## here, sharing the exact pose between its visible model and its light.
static func house_origin(placement: Dictionary) -> Vector3:
	var key := String(placement.key)
	var scale := float(placement.get("scale", 1.0))
	var yaw := float(placement.yaw)
	var model_yaw := yaw + face_offset(key)
	var centre := centre_offset(key) * scale
	centre.y = 0.0
	var origin := Vector3(placement.pos) - Basis(Vector3.UP, model_yaw) * centre
	if has_tag(key, WALL_MOUNTED):
		# The record is the wall mount, not the middle of the model's depth.
		# Put the measured back against that face and the body into the room.
		var depth := footprint_rotated(key, face_offset(key)).y * scale
		origin += Vector3(-sin(yaw), 0, -cos(yaw)) * depth * 0.5
	elif not has_tag(key, CEILING):
		origin.y -= floor_offset(key) * scale
	return origin


## One prop placed somewhere, in the form every family that is NOT a HousePlan
## records its dressing in: the temple, the church and the castle all build a
## list of these and hand it to their assembler.
##
## `rect` is the plan floor the piece actually stands on, computed here rather
## than left to the checks: a check that re-derives the footprint from the key
## and the yaw agrees with the placer even when they are both wrong, which is
## the failure mode this whole harness exists to avoid. A wall-mounted,
## ceiling-hung or on-surface piece takes no floor and carries an empty rect.
static func placement(key: String, pos: Vector3, yaw: float, scale: float,
		kind: StringName) -> Dictionary:
	var rect := Rect2()
	if blocks_floor(key):
		var f: Vector2 = footprint_rotated(key, yaw) * scale
		rect = Rect2(plan_centre(key, pos, yaw, scale) - f / 2.0, f)
	return {"key": key, "pos": pos, "yaw": yaw, "scale": scale, "kind": kind,
		"rect": rect}
