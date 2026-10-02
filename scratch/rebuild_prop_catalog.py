import io

P = "src/house/prop_catalog.gd"
s = io.open(P, encoding="utf-8").read()


def sub(old, new):
    global s
    assert s.count(old) == 1, ("anchor not unique: " + old[:70])
    s = s.replace(old, new)


PACKS = '''const SOURCE_ASSET_ROOT := "res://assets/props/"
const ADDON_ASSET_ROOT := "res://addons/brick_wild/assets/props/"
const CATALOG_FILE := "catalog.json"

## The art packs the props come from: which folder, and what the models are
## shipped as. A prop names its pack in PROPS; anything that does not name one
## is in `fantasy`, which is where every prop was until the dungeon kit arrived.
##
## Two packs rather than one because they ship different formats -- Quaternius
## exports the Fantasy Props MegaKit as glTF and the Dungeon Kit as FBX only --
## and because both contain a Barrel, a Crate and a Chest. The dungeon files are
## prefixed on disk so a catalogue key is still globally unique.
const PACKS := {
\t"fantasy": {"dir": "fantasy", "ext": "gltf"},
\t"dungeon": {"dir": "dungeon", "ext": "fbx"},
}
const DEFAULT_PACK := "fantasy"
'''

sub('''const SOURCE_ASSET_ROOT := "res://assets/props/"
const ADDON_ASSET_ROOT := "res://addons/brick_wild/assets/props/"
const CATALOG_FILE := "catalog.json"
''', PACKS)

sub("static func height(key: String) -> float:", '''## Plan footprint after ANY yaw: the axis-aligned box the turned piece needs.
##
## footprint_yawed() knows quarter turns only, which is every turn the house
## furnisher makes -- rooms are rectangles and furniture is square to them. A
## range on a ridge castle runs at whatever angle its spine does, and a trestle
## in one is turned 22 degrees; asking footprint_yawed() about that gets the
## UNTURNED footprint back, which is a box the piece does not occupy.
static func footprint_rotated(key: String, yaw: float) -> Vector2:
\tvar f: Vector2 = footprint(key)
\tvar c: float = absf(cos(yaw))
\tvar s: float = absf(sin(yaw))
\treturn Vector2(f.x * c + f.y * s, f.x * s + f.y * c)


static func height(key: String) -> float:''')

sub('''static func scene_path(key: String) -> String:
\treturn asset_root() + "fantasy/%s.gltf" % key''', '''static func pack(key: String) -> String:
\treturn String(PROPS[key].get("pack", DEFAULT_PACK)) if PROPS.has(key) \\
\t\telse DEFAULT_PACK


static func scene_path(key: String) -> String:
\tvar row: Dictionary = PACKS.get(pack(key), PACKS[DEFAULT_PACK])
\treturn asset_root() + "%s/%s.%s" % [row["dir"], key, row["ext"]]


## The yaw that points a prop face down `d` (a direction in plan). A prop faces
## its own local -Z, which a yaw of y turns to (-sin y, -cos y).
static func yaw_facing(d: Vector2) -> float:
\tif d.length_squared() < 0.000001:
\t\treturn 0.0
\treturn atan2(-d.x, -d.y)


## The yaw to store for a wall piece so that it ends up facing `inward`, off the
## wall it hangs on.
##
## Every wall prop in the MegaKit is modelled with its mass behind its mounting
## point and carries a half-turn `face` correction; the Dungeon Kit flags are
## modelled centred on theirs and carry none. Reading the correction from the
## catalogue rather than assuming PI is what lets both hang the right way round
## on the same wall.
static func mount_yaw(key: String, inward: Vector2) -> float:
\treturn yaw_facing(inward) - face_offset(key)


## Where a placed prop mass actually sits in plan, which is not always where its
## origin is: the stag statue carries its mass half a metre off its own pivot,
## and a rect centred on the pivot describes a stag that is not there.
static func plan_centre(key: String, pos: Vector3, yaw: float, scale: float) -> Vector2:
\tvar c: Vector3 = centre_offset(key) * scale
\tvar turned := Vector2(c.x * cos(yaw) + c.z * sin(yaw),
\t\t-c.x * sin(yaw) + c.z * cos(yaw))
\treturn Vector2(pos.x, pos.z) + turned


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
\t\tkind: StringName) -> Dictionary:
\tvar rect := Rect2()
\tif blocks_floor(key):
\t\tvar f: Vector2 = footprint_rotated(key, yaw) * scale
\t\trect = Rect2(plan_centre(key, pos, yaw, scale) - f / 2.0, f)
\treturn {"key": key, "pos": pos, "yaw": yaw, "scale": scale, "kind": kind,
\t\t"rect": rect}''')

D = '"pack": "dungeon", '
ROWS = [
    ("Dungeon_Statue_Stag", 'statue', '[]', '0.8'),
    ("Dungeon_Statue_Fox", 'statue', '[]', '0.8'),
    ("Dungeon_Column_Round", 'column', '[]', '0.0'),
    ("Dungeon_Column_Square", 'column', '[]', '0.0'),
    ("Dungeon_Column_Round_Short", 'column', '[]', '0.0'),
    ("Dungeon_Rail_Straight", 'rail', '[]', '0.0'),
    ("Dungeon_Rail_Corner", 'rail', '[]', '0.0'),
    ("Dungeon_Rail_Divider", 'rail', '[]', '0.0'),
    (None, None, None, None),
    ("Dungeon_Flag_Wall", 'war_banner', '[WALL_MOUNTED]', '0.0'),
    ("Dungeon_Flag_Wall2", 'war_banner', '[WALL_MOUNTED]', '0.0'),
    ("Dungeon_Flag_GothicArch", 'arch_flag', '[WALL_MOUNTED]', '0.0'),
    ("Dungeon_Flag_RoundArch", 'arch_flag', '[WALL_MOUNTED]', '0.0'),
    ("Dungeon_Candles_1", 'floor_candles', '[LIGHT]', '0.0'),
    ("Dungeon_Candles_2", 'floor_candles', '[LIGHT]', '0.0'),
    ("Dungeon_Torch", 'wall_torch', '[WALL_MOUNTED, LIGHT]', '0.0'),
    ("Dungeon_Bookcase_Empty", 'tall_bookcase', '[WALL]', '0.7'),
    ("Dungeon_Bookcase_Full", 'tall_bookcase', '[WALL]', '0.7'),
    ("Dungeon_Chest", 'reliquary', '[WALL]', '0.6'),
    ("Dungeon_Chest_Gold", 'reliquary', '[WALL]', '0.6'),
    ("Dungeon_Cart", 'wagon', '[]', '0.9'),
    ("Dungeon_Barrel", 'cask', '[CORNER]', '0.0'),
    ("Dungeon_Crate", 'cask', '[CORNER]', '0.0'),
    ("Dungeon_Pot1", 'urn', '[CORNER]', '0.0'),
    ("Dungeon_Pot2", 'urn', '[CORNER]', '0.0'),
    ("Dungeon_Pot3", 'urn', '[CORNER]', '0.0'),
    ("Dungeon_Pot1_Broken", 'urn', '[CORNER]', '0.0'),
    ("Dungeon_Pot2_Broken", 'urn', '[CORNER]', '0.0'),
    ("Dungeon_Pot3_Broken", 'urn', '[CORNER]', '0.0'),
    ("Dungeon_Brick", 'rubble', '[CORNER]', '0.0'),
    ("Dungeon_Bricks", 'rubble', '[CORNER]', '0.0'),
    ("Dungeon_Skull", 'relic', '[]', '0.0'),
    ("Dungeon_Trapdoor", 'hatch', '[]', '0.0'),
    ("Dungeon_BearTrap_Closed", 'trap', '[]', '0.0'),
    ("Dungeon_BearTrap_Open", 'trap', '[]', '0.0'),
]

NOTE = ('\t# Modelled centred on their own mounting point, so no `face` correction --\n'
        '\t# unlike every wall prop in the MegaKit. PropCatalog.mount_yaw() reads the\n'
        '\t# difference rather than assuming it.\n')

lines = []
for key, cat, tags, zone in ROWS:
    if key is None:
        lines.append(NOTE.rstrip("\n"))
        continue
    lines.append('\t"%s": {%s"cat": "%s", "tags": %s, "zone": %s},'
                 % (key, D, cat, tags, zone))

HEAD = '''\t"Pouch_Large": {"cat": "trinket", "tags": [ON_SURFACE], "zone": 0.0},

\t# ---- the Dungeon Kit ----
\t# A second pack (PACKS above), for the things a church and a castle want and
\t# the MegaKit has none of: statues, an altar rail, standing columns, wall
\t# flags, floor candles.
\t#
\t# Their categories are deliberately their OWN. A dungeon flag is half again
\t# the size of a MegaKit banner and cut from a chunkier pack; dropping it into
\t# "banner" would let a hotel lobby draw one, and the two art styles would be
\t# in the same room by accident rather than by choice. Only the church and
\t# castle furnishers ask for these categories.
'''

sub('\t"Pouch_Large": {"cat": "trinket", "tags": [ON_SURFACE], "zone": 0.0},\n}',
    HEAD + "\n".join(lines) + "\n}")

io.open(P, "w", encoding="utf-8", newline="\n").write(s)
print("rebuilt prop_catalog.gd")
