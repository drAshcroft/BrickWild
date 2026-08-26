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
## Local axes of a placed prop: it faces local -Z (the direction a person using
## it stands), so a piece against a wall has the wall behind it at +Z. `face`
## corrects a model that was authored pointing some other way.

const CATALOG_PATH := "res://assets/props/catalog.json"

# ---- placement rules a prop can carry ----
const WALL := "wall"              # wants its back to a wall
const CORNER := "corner"          # happiest tucked into a corner
const SURFACE := "surface"        # has a top other things can be set on
const ON_SURFACE := "on_surface"  # must be set ON a surface, never on the floor
const WALL_MOUNTED := "wall_mounted"   # hangs on a wall, no footprint on the floor
const CEILING := "ceiling"        # hangs from the ceiling
const LIGHT := "light"            # counts toward a room being lit

## key -> {cat, tags, zone, face}
##   cat   what the piece is, which is what a room's recipe asks for
##   zone  metres of clear floor a person needs in front of it to use it;
##         0 means it is furniture you walk past, not furniture you use
##   face  yaw correction, radians, for a model authored facing the wrong way.
##         Every wall-mounted prop in this pack carries one: they are modelled
##         with their mass on the +Z side of their mounting point, and the
##         convention here is that a prop faces -Z, so without the half turn a
##         shelf hangs inside the wall it is screwed to.
const PROPS := {
	# ---- beds ----
	"Bed_Twin1": {"cat": "bed", "tags": [WALL], "zone": 0.75},
	"Bed_Twin2": {"cat": "bed", "tags": [WALL], "zone": 0.75},

	# ---- tables and seats ----
	"Table_Large": {"cat": "table", "tags": [SURFACE], "zone": 0.0},
	"Workbench": {"cat": "workbench", "tags": [WALL, SURFACE], "zone": 0.9},
	"Workbench_Drawers": {"cat": "workbench", "tags": [WALL, SURFACE], "zone": 0.9},
	"Chair_1": {"cat": "seat", "tags": [], "zone": 0.55},
	"Stool": {"cat": "seat", "tags": [], "zone": 0.5},
	"Bench": {"cat": "bench", "tags": [], "zone": 0.55},

	# ---- storage ----
	"Cabinet": {"cat": "storage", "tags": [WALL, SURFACE], "zone": 0.7},
	"Bookcase_2": {"cat": "bookcase", "tags": [WALL], "zone": 0.7},
	"Chest_Wood": {"cat": "chest", "tags": [WALL], "zone": 0.6},
	"Nightstand_Shelf": {"cat": "nightstand", "tags": [WALL, SURFACE], "zone": 0.4},
	"Barrel": {"cat": "barrel", "tags": [CORNER], "zone": 0.0},
	"Barrel_Apples": {"cat": "barrel", "tags": [CORNER], "zone": 0.0},
	"Crate_Wooden": {"cat": "crate", "tags": [CORNER, SURFACE], "zone": 0.0},
	"Crate_Metal": {"cat": "crate", "tags": [CORNER, SURFACE], "zone": 0.0},
	"FarmCrate_Apple": {"cat": "crate", "tags": [CORNER, SURFACE], "zone": 0.0},
	"FarmCrate_Carrot": {"cat": "crate", "tags": [CORNER, SURFACE], "zone": 0.0},
	"FarmCrate_Empty": {"cat": "crate", "tags": [CORNER, SURFACE], "zone": 0.0},

	# ---- hearth and kitchen ----
	"Cauldron": {"cat": "hearth", "tags": [WALL], "zone": 0.8},
	"Pot_1": {"cat": "cookware", "tags": [CORNER], "zone": 0.0},
	"Bucket_Wooden_1": {"cat": "cookware", "tags": [CORNER], "zone": 0.0},
	"Bucket_Metal": {"cat": "cookware", "tags": [CORNER], "zone": 0.0},

	# ---- trade fittings ----
	"Anvil": {"cat": "anvil", "tags": [], "zone": 0.9},
	"Anvil_Log": {"cat": "anvil", "tags": [], "zone": 0.9},
	"WeaponStand": {"cat": "stand", "tags": [WALL], "zone": 0.6},
	"Dummy": {"cat": "stand", "tags": [], "zone": 0.7},
	"BookStand": {"cat": "lectern", "tags": [SURFACE], "zone": 0.7},
	"Stall_Empty": {"cat": "counter", "tags": [WALL, SURFACE], "zone": 0.9},

	# ---- shelves and wall furniture ----
	"Shelf_Simple": {"cat": "shelf", "tags": [WALL_MOUNTED, SURFACE], "zone": 0.0, "face": PI},
	"Shelf_Arch": {"cat": "shelf", "tags": [WALL_MOUNTED, SURFACE], "zone": 0.0, "face": PI},
	"Shelf_Small_Bottles": {"cat": "shelf", "tags": [WALL_MOUNTED], "zone": 0.0, "face": PI},
	"Peg_Rack": {"cat": "rack", "tags": [WALL_MOUNTED], "zone": 0.0, "face": PI},
	"Shield_Wooden": {"cat": "trophy", "tags": [WALL_MOUNTED], "zone": 0.0, "face": PI},
	"Banner_1": {"cat": "banner", "tags": [WALL_MOUNTED], "zone": 0.0, "face": PI},
	"Banner_2": {"cat": "banner", "tags": [WALL_MOUNTED], "zone": 0.0, "face": PI},
	"Lantern_Wall": {"cat": "sconce", "tags": [WALL_MOUNTED, LIGHT], "zone": 0.0, "face": PI},
	"Torch_Metal": {"cat": "sconce", "tags": [WALL_MOUNTED, LIGHT], "zone": 0.0, "face": PI},
	"Chandelier": {"cat": "chandelier", "tags": [CEILING, LIGHT], "zone": 0.0},

	# ---- things that live on a surface ----
	"Mug": {"cat": "tableware", "tags": [ON_SURFACE], "zone": 0.0},
	"Chalice": {"cat": "tableware", "tags": [ON_SURFACE], "zone": 0.0},
	"Table_Plate": {"cat": "tableware", "tags": [ON_SURFACE], "zone": 0.0},
	"Bottle_1": {"cat": "tableware", "tags": [ON_SURFACE], "zone": 0.0},
	"Candle_1": {"cat": "candle", "tags": [ON_SURFACE, LIGHT], "zone": 0.0},
	"CandleStick": {"cat": "candle", "tags": [ON_SURFACE, LIGHT], "zone": 0.0},
	"CandleStick_Triple": {"cat": "candle", "tags": [ON_SURFACE, LIGHT], "zone": 0.0},
	"Book_Stack_1": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},
	"Book_Stack_2": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},
	"BookGroup_Small_1": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},
	"Scroll_1": {"cat": "books", "tags": [ON_SURFACE], "zone": 0.0},
	"Potion_1": {"cat": "alchemy", "tags": [ON_SURFACE], "zone": 0.0},
	"Potion_2": {"cat": "alchemy", "tags": [ON_SURFACE], "zone": 0.0},
	"SmallBottles_1": {"cat": "alchemy", "tags": [ON_SURFACE], "zone": 0.0},
	"Vase_2": {"cat": "vase", "tags": [ON_SURFACE], "zone": 0.0},
	"Vase_4": {"cat": "vase", "tags": [ON_SURFACE], "zone": 0.0},
	"Whetstone": {"cat": "tool", "tags": [ON_SURFACE], "zone": 0.0},
	"Key_Metal": {"cat": "trinket", "tags": [ON_SURFACE], "zone": 0.0},
	"Coin_Pile": {"cat": "trinket", "tags": [ON_SURFACE], "zone": 0.0},
}

## Measured sizes, loaded once and shared. Static so the whole sweep pays for
## the JSON parse a single time.
static var _sizes: Dictionary = {}


static func _load() -> void:
	if not _sizes.is_empty():
		return
	var f := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if f == null:
		push_error("PropCatalog: no measured catalogue at %s -- run tools/build_prop_catalog.gd"
			% CATALOG_PATH)
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


## Footprint after a quarter-turn yaw, which is all the furnisher ever uses.
static func footprint_yawed(key: String, yaw: float) -> Vector2:
	var f: Vector2 = footprint(key)
	if absf(sin(yaw)) > 0.5:
		return Vector2(f.y, f.x)
	return f


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


static func category(key: String) -> String:
	return PROPS[key]["cat"] if PROPS.has(key) else ""


static func has_tag(key: String, tag: String) -> bool:
	return PROPS.has(key) and tag in PROPS[key]["tags"]


## Metres of clear floor a person needs in front of the piece to use it.
static func zone_depth(key: String) -> float:
	return float(PROPS[key]["zone"]) if PROPS.has(key) else 0.0


static func face_offset(key: String) -> float:
	return float(PROPS[key].get("face", 0.0)) if PROPS.has(key) else 0.0


## Does this prop stand on the floor and get in a person's way?
static func blocks_floor(key: String) -> bool:
	return not (has_tag(key, WALL_MOUNTED) or has_tag(key, CEILING)
		or has_tag(key, ON_SURFACE))


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


static func scene_path(key: String) -> String:
	return "res://assets/props/fantasy/%s.gltf" % key
