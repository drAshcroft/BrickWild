import io
p = "src/house/prop_catalog.gd"
s = io.open(p, encoding="utf-8").read()

anchor = '''	"Pouch_Large": {"cat": "trinket", "tags": [ON_SURFACE], "zone": 0.0},
}'''

block = '''	"Pouch_Large": {"cat": "trinket", "tags": [ON_SURFACE], "zone": 0.0},

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
	"Dungeon_Statue_Stag": {"cat": "statue", "tags": [], "zone": 0.8},
	"Dungeon_Statue_Fox": {"cat": "statue", "tags": [], "zone": 0.8},
	"Dungeon_Column_Round": {"cat": "column", "tags": [], "zone": 0.0},
	"Dungeon_Column_Square": {"cat": "column", "tags": [], "zone": 0.0},
	"Dungeon_Column_Round_Short": {"cat": "column", "tags": [], "zone": 0.0},
	"Dungeon_Rail_Straight": {"cat": "rail", "tags": [], "zone": 0.0},
	"Dungeon_Rail_Corner": {"cat": "rail", "tags": [], "zone": 0.0},
	"Dungeon_Rail_Divider": {"cat": "rail", "tags": [], "zone": 0.0},
	# Modelled centred on their own mounting point, so no `face` correction --
	# unlike every wall prop in the MegaKit. PropCatalog.mount_yaw() reads the
	# difference rather than assuming it.
	"Dungeon_Flag_Wall": {"cat": "war_banner", "tags": [WALL_MOUNTED], "zone": 0.0},
	"Dungeon_Flag_Wall2": {"cat": "war_banner", "tags": [WALL_MOUNTED], "zone": 0.0},
	"Dungeon_Flag_GothicArch": {"cat": "arch_flag", "tags": [WALL_MOUNTED], "zone": 0.0},
	"Dungeon_Flag_RoundArch": {"cat": "arch_flag", "tags": [WALL_MOUNTED], "zone": 0.0},
	"Dungeon_Candles_1": {"cat": "floor_candles", "tags": [LIGHT], "zone": 0.0},
	"Dungeon_Candles_2": {"cat": "floor_candles", "tags": [LIGHT], "zone": 0.0},
	"Dungeon_Torch": {"cat": "wall_torch", "tags": [WALL_MOUNTED, LIGHT], "zone": 0.0},
	"Dungeon_Bookcase_Empty": {"cat": "tall_bookcase", "tags": [WALL], "zone": 0.7},
	"Dungeon_Bookcase_Full": {"cat": "tall_bookcase", "tags": [WALL], "zone": 0.7},
	"Dungeon_Chest": {"cat": "reliquary", "tags": [WALL], "zone": 0.6},
	"Dungeon_Chest_Gold": {"cat": "reliquary", "tags": [WALL], "zone": 0.6},
	"Dungeon_Cart": {"cat": "wagon", "tags": [], "zone": 0.9},
	"Dungeon_Barrel": {"cat": "cask", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Crate": {"cat": "cask", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Pot1": {"cat": "urn", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Pot2": {"cat": "urn", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Pot3": {"cat": "urn", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Pot1_Broken": {"cat": "urn", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Pot2_Broken": {"cat": "urn", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Pot3_Broken": {"cat": "urn", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Brick": {"cat": "rubble", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Bricks": {"cat": "rubble", "tags": [CORNER], "zone": 0.0},
	"Dungeon_Skull": {"cat": "relic", "tags": [], "zone": 0.0},
	"Dungeon_Trapdoor": {"cat": "hatch", "tags": [], "zone": 0.0},
	"Dungeon_BearTrap_Closed": {"cat": "trap", "tags": [], "zone": 0.0},
	"Dungeon_BearTrap_Open": {"cat": "trap", "tags": [], "zone": 0.0},
}'''
assert s.count(anchor) == 1
s = s.replace(anchor, block)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("patched")
