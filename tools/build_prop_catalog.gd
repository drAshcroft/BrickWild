extends SceneTree
## Measures every prop in every pack under assets/props and writes
## assets/props/catalog.json.
##
## The furnisher needs a footprint for each piece before it can place it, and
## guessing those numbers is how furniture ends up half inside a wall. So they
## are measured from the imported meshes once, written down, and then checked
## against the meshes again by the house suite -- if an asset is swapped, the
## suite fails rather than the layout quietly going wrong.
##
## Run: godot --headless --path . --script res://tools/build_prop_catalog.gd

const OUT := "res://assets/props/catalog.json"


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
		var packed: PackedScene = load(path)
		if packed == null:
			printerr("could not load %s" % path)
			continue
		var node: Node = packed.instantiate()
		var aabb: AABB = SceneBounds.of_node(node)
		node.queue_free()
		rows[prop_name] = {
			"size": [snappedf(aabb.size.x, 0.001), snappedf(aabb.size.y, 0.001),
				snappedf(aabb.size.z, 0.001)],
			# offset from the node origin to the AABB centre, so a placer can put
			# the piece where it means to rather than where its pivot happens to be
			"centre": [snappedf(aabb.get_center().x, 0.001),
				snappedf(aabb.get_center().y, 0.001),
				snappedf(aabb.get_center().z, 0.001)],
			"floor": snappedf(aabb.position.y, 0.001),
			# where a light goes if this prop is one: the top centre of the
			# model, which is where the flame of every lamp in this pack is
			"light": [snappedf(aabb.get_center().x, 0.001),
				snappedf(aabb.end.y, 0.001),
				snappedf(aabb.get_center().z, 0.001)],
		}

	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, "\t", true))
	f.close()
	print("measured %d props from %d packs -> %s"
		% [rows.size(), PropCatalog.PACKS.size(), OUT])
	quit(0)
