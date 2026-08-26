extends SceneTree
## Measures every prop in assets/props/fantasy and writes assets/props/catalog.json.
##
## The furnisher needs a footprint for each piece before it can place it, and
## guessing those numbers is how furniture ends up half inside a wall. So they
## are measured from the imported meshes once, written down, and then checked
## against the meshes again by the house suite -- if an asset is swapped, the
## suite fails rather than the layout quietly going wrong.
##
## Run: godot --headless --path . --script res://tools/build_prop_catalog.gd

const PROP_DIR := "res://assets/props/fantasy"
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
		}

	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, "\t", true))
	f.close()
	print("measured %d props -> %s" % [rows.size(), OUT])
	quit(0)
