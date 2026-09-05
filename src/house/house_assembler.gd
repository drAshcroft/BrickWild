class_name HouseAssembler
extends RefCounted
## Turns a furnished HousePlan into a scene: the shell mesh, and an instance of
## the real model for every piece of furniture in it.
##
## This is the only place that touches the art. Everything above it -- the
## planner, the furnisher, all four checks -- works in metres and rectangles
## and never loads a model, which is what lets the whole harness run headless
## in a few milliseconds per house. Here at the end the rectangles are handed
## their meshes.
##
## Two things are corrected as each prop goes in, and both come from the
## measured catalogue rather than from guesswork:
##   * the model is dropped so its feet sit on the floor, because a few of them
##     are modelled hanging below their own origin;
##   * the placement's scale is applied, so the small table the furnisher chose
##     for a small room is actually small.

## Materials for the shell's four surfaces, in the builder's own order.
const SURFACES := ["wall", "trim", "roof", "floor"]


## Build the whole thing. `cutaway` leaves the roof off, which is the only way
## to photograph a furnished interior.
static func build(plan: HousePlan, cutaway := false) -> Node3D:
	var root := Node3D.new()
	root.name = "House"

	var builder := HouseBuilder.new()
	var mesh: ArrayMesh = builder.build(plan, not cutaway)
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = mesh
	var spec: HouseSpec = plan.spec
	var cols := [spec.wall_color, spec.trim_color, spec.roof_color, spec.floor_color]
	for i in range(mesh.get_surface_count()):
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[i]
		m.roughness = 0.95
		# the shell is seen from outside AND from above with the roof off, so
		# the walls must not vanish when the camera is on their far side
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		shell.set_surface_override_material(i, m)
	root.add_child(shell)
	furnish(root, plan)
	return root


## The furniture, and the light every lamp among it gives off (LAY-011).
## Shared with the shop and hotel assemblers so a house is dressed and lit
## the same way whatever it is called.
static func furnish(root: Node3D, plan: HousePlan) -> void:
	var props := Node3D.new()
	props.name = "Furniture"
	root.add_child(props)
	for p in plan.furniture:
		var node: Node3D = _instance(p)
		if node != null:
			props.add_child(node)
	root.add_child(LightKit.light_the_plan(plan))


## One piece of furniture, placed as the plan says.
static func _instance(p: Dictionary) -> Node3D:
	var key: String = p["key"]
	var path: String = PropCatalog.scene_path(key)
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var node: Node3D = packed.instantiate()
	node.name = key
	var scale_factor: float = float(p.get("scale", 1.0))
	node.scale = Vector3.ONE * scale_factor
	node.rotation.y = float(p["yaw"]) + PropCatalog.face_offset(key)
	var pos: Vector3 = p["pos"]
	# sit it on whatever it stands on: the floor, a table top, or its bracket
	var drop: float = PropCatalog.floor_offset(key) * scale_factor
	if PropCatalog.has_tag(key, PropCatalog.WALL_MOUNTED) \
			or PropCatalog.has_tag(key, PropCatalog.CEILING):
		drop = 0.0
	node.position = Vector3(pos.x, pos.y - drop, pos.z)
	return node


## The camera framing a house wants: high enough to see over the walls, and
## far enough back to hold the whole footprint.
static func viewing_distance(plan: HousePlan) -> float:
	var r: Rect2 = HouseGeometry.plan_extent(plan.spec)
	return maxf(r.size.x, r.size.y) * 1.25 + 6.0
