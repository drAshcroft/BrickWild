import io

def edit(path, pairs):
    s = io.open(path, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (path + " anchor not unique: " + old[:70])
        s = s.replace(old, new)
    io.open(path, "w", encoding="utf-8", newline="\n").write(s)
    print("patched " + path)

edit("src/house/prop_catalog.gd", [
# ---- the pack table ----
("""const SOURCE_ASSET_ROOT := "res://assets/props/"
const ADDON_ASSET_ROOT := "res://addons/big_glade/assets/props/"
const CATALOG_FILE := "catalog.json"
""",
 """const SOURCE_ASSET_ROOT := "res://assets/props/"
const ADDON_ASSET_ROOT := "res://addons/big_glade/assets/props/"
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
	"fantasy": {"dir": "fantasy", "ext": "gltf"},
	"dungeon": {"dir": "dungeon", "ext": "fbx"},
}
const DEFAULT_PACK := "fantasy"
"""),
# ---- scene_path reads the pack ----
("""static func scene_path(key: String) -> String:
	return asset_root() + "fantasy/%s.gltf" % key""",
 """static func pack(key: String) -> String:
	return String(PROPS[key].get("pack", DEFAULT_PACK)) if PROPS.has(key) \
		else DEFAULT_PACK


static func scene_path(key: String) -> String:
	var row: Dictionary = PACKS.get(pack(key), PACKS[DEFAULT_PACK])
	return asset_root() + "%s/%s.%s" % [row["dir"], key, row["ext"]]"""),
])
