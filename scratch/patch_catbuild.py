import io
p = "tools/build_prop_catalog.gd"
s = io.open(p, encoding="utf-8").read()

old = '''## Measures every prop in assets/props/fantasy and writes assets/props/catalog.json.'''
new = '''## Measures every prop in every pack under assets/props and writes
## assets/props/catalog.json.'''
assert s.count(old) == 1
s = s.replace(old, new)

old = '''const PROP_DIR := "res://assets/props/fantasy"
const OUT := "res://assets/props/catalog.json"


func _init() -> void:
	var rows := {}
	var dir := DirAccess.open(PROP_DIR)
	if dir == null:
		printerr("no prop directory at %s" % PROP_DIR)
		quit(1)
		return
	var names: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".gltf"):
			names.append(f.get_basename())
	names.sort()

	for prop_name in names:
		var path: String = "%s/%s.gltf" % [PROP_DIR, prop_name]
		var packed: PackedScene = load(path)'''
new = '''const OUT := "res://assets/props/catalog.json"


func _init() -> void:
	var rows := {}
	# Which packs there are, what they are called on disk and what they ship as
	# is PropCatalog.PACKS -- one table, so a pack cannot be measured from one
	# folder and loaded from another.
	var paths: Array[String] = []
	for pack_name in PropCatalog.PACKS:
		var row: Dictionary = PropCatalog.PACKS[pack_name]
		var pack_dir: String = "res://assets/props/%s" % row["dir"]
		var dir := DirAccess.open(pack_dir)
		if dir == null:
			printerr("no prop directory at %s" % pack_dir)
			continue
		var suffix: String = ".%s" % row["ext"]
		for f in dir.get_files():
			if f.ends_with(suffix):
				paths.append("%s/%s" % [pack_dir, f])
	paths.sort()

	for path in paths:
		var prop_name: String = path.get_file().get_basename()
		var packed: PackedScene = load(path)'''
assert s.count(old) == 1
s = s.replace(old, new)

old = '''	print("measured %d props -> %s" % [rows.size(), OUT])'''
new = '''	print("measured %d props from %d packs -> %s"
		% [rows.size(), PropCatalog.PACKS.size(), OUT])'''
assert s.count(old) == 1
s = s.replace(old, new)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("patched")
