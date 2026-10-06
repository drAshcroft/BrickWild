class_name VillageGroundCheck
extends RefCounted
## Does every model the village set down stand on the ground? (walk QA,
## Wolfmarch Green pins 1 and 3: a bush with daylight under it, a cart in the
## air beside a farmhouse.)
##
## The only village check that loads models, because the question is about the
## MODEL: the plan says where a thing stands, the catalogue says how far below
## its origin its feet are, and the assembler adds the two. Both defects were in
## the second number -- a cart measured on its declared box, 1.32 m deeper than
## its wheels, and a bush measured on a buried stem stub -- so no plan-level
## check could see them. This one measures the vertices of the assembled scene.
##
## Three kinds of model, one rule each:
##
##   prop    the village dresser's catalogue props: the lowest vertex is on the
##           ground (VillageBuilder.ground_height, or the prop's own elevation)
##   plant   the dresser's plants: the plant's ground line -- the lower of its
##           origin and the height under which 1% of its vertices lie
##           (SceneBounds.base_heights) -- is on the ground; a plant may bury its
##           stem but not itself
##   yard    each house's yard and facade models, against the height its own
##           HousePlan row says it stands at (VillageAssembler records those
##           rows on the building node as `stands`); wall, ceiling and mounted
##           pieces hang and are not asked
##
## "On" means within FLOAT_TOL above and SINK_TOL below. The ground line, not
## the lowest vertex, is what catches the bush: its lowest vertex WAS on the
## ground, and its leaves were a quarter of a metre up.

## A model's feet this far above where it stands: it floats.
const FLOAT_TOL := 0.06
## A prop's lowest point this far under where it stands: it is buried.
const SINK_TOL := 0.06
## A plant's ground line this far under the ground: the plant, not its stem,
## is buried.
const PLANT_BURY := 0.35

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}


## `scene` is what VillageAssembler.build(plan) returned.
func check(plan: VillagePlan, scene: Node3D) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats = {"props": 0, "plants": 0, "yard": 0, "worst": 0.0}
	_props(plan, scene)
	_plants(plan, scene)
	_yards(scene)
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats}


func _props(plan: VillagePlan, scene: Node3D) -> void:
	var props := scene.get_node_or_null("Props")
	if props == null:
		return
	for node in props.get_children():
		var i := _index_of(node)
		if i < 0 or i >= plan.props.size() or not node is Node3D:
			continue
		var p: Dictionary = plan.props[i]
		var stand: float = float(p["elevation"]) if p.has("elevation") \
			else VillageBuilder.ground_height(plan, p["pos"])
		_judge(node as Node3D, scene, String(p["key"]), stand, "prop %s" % node.name)
		stats["props"] = int(stats["props"]) + 1


func _plants(plan: VillagePlan, scene: Node3D) -> void:
	var plants := scene.get_node_or_null("Plants")
	if plants == null:
		return
	for node in plants.get_children():
		var j := _index_of(node)
		if j < 0 or j >= plan.plants.size() or not node is Node3D:
			continue
		var t: Dictionary = plan.plants[j]
		_judge(node as Node3D, scene, String(t["key"]),
			VillageBuilder.ground_height(plan, t["pos"]), "plant %s" % node.name)
		stats["plants"] = int(stats["plants"]) + 1


func _yards(scene: Node3D) -> void:
	var buildings := scene.get_node_or_null("Buildings")
	if buildings == null:
		return
	for b in buildings.get_children():
		var rows: Array = b.get_meta(&"stands", [])
		var exterior := b.get_node_or_null("Exterior")
		if rows.is_empty() or exterior == null:
			continue
		for row in rows:
			var key: String = String(row.get("key", ""))
			if bool(row.get("mounted", false)) or PropCatalog.has_tag(key, PropCatalog.WALL_MOUNTED) \
					or PropCatalog.has_tag(key, PropCatalog.CEILING):
				continue
			var node := exterior.get_node_or_null(String(row.get("id", "")))
			if node == null or not node is Node3D:
				continue
			# the stand height in the building's own frame, carried to the scene's
			var local: Vector3 = (node as Node3D).position
			local.y = float(row["y"])
			var stand: float = (_to_scene(exterior as Node3D, scene) * local).y
			_judge(node as Node3D, scene, key, stand, "%s yard %s" % [b.name, node.name])
			stats["yard"] = int(stats["yard"]) + 1


## One model against the height it stands at.
func _judge(node: Node3D, scene: Node3D, key: String, stand: float, label: String) -> void:
	var parent_xf: Transform3D = _to_scene(node.get_parent() as Node3D, scene)
	var heights: Vector2 = SceneBounds.base_heights(node, parent_xf)
	if heights == Vector2.ZERO and _is_empty(node):
		return
	if PropCatalog.has_tag(key, PropCatalog.PLANT):
		var origin_y: float = (parent_xf * node.transform).origin.y
		var line: float = minf(heights.y, origin_y)
		_worst(line - stand)
		if line > stand + FLOAT_TOL:
			failures.append("ground: %s (%s) floats, its ground line %.2fm above the ground"
				% [label, key, line - stand])
		elif heights.y < stand - PLANT_BURY:
			failures.append("ground: %s (%s) is buried, its ground line %.2fm under the ground"
				% [label, key, stand - heights.y])
		return
	_worst(heights.x - stand)
	if heights.x > stand + FLOAT_TOL:
		failures.append("ground: %s (%s) floats, its lowest point %.2fm above where it stands"
			% [label, key, heights.x - stand])
	elif heights.x < stand - SINK_TOL:
		failures.append("ground: %s (%s) is sunk %.2fm under where it stands"
			% [label, key, stand - heights.x])


func _worst(gap: float) -> void:
	if absf(gap) > absf(float(stats["worst"])):
		stats["worst"] = snappedf(gap, 0.001)


## The transform from `node`'s frame to the scene root's, walked by hand: a
## checked scene need not be in a tree, so global_transform is not available.
static func _to_scene(node: Node3D, scene: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != scene:
		if at is Node3D:
			xf = (at as Node3D).transform * xf
		at = at.get_parent()
	return xf


static func _index_of(node: Node) -> int:
	var name := String(node.name)
	var cut := name.rfind("_")
	if cut < 0 or not name.substr(cut + 1).is_valid_int():
		return -1
	return int(name.substr(cut + 1))


static func _is_empty(node: Node) -> bool:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return false
	for c in node.get_children():
		if not _is_empty(c):
			return false
	return true
