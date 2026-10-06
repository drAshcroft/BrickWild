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
## Placement corrections come from the
## measured catalogue rather than from guesswork:
##   * the model's measured centre follows the planned footprint, and a
##     mounted model's back follows the room's wall face;
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
	# one material per surface, from ShellAssembler, like every other family
	# (API-005). The house's roof is not hidden for a cutaway -- the builder
	# is asked not to emit it at all, which is why `not cutaway` goes in above.
	ShellAssembler.surface_materials(shell, BuildingFamilyAdapter.colours(plan.spec))
	# A shop's shell IS a house's shell, roof and all, so it gets the coursed
	# roof too: the `room_program` test was meant for the castle families that
	# borrow this assembler, and a flat brown shop roof was the price of it
	# (WALK-QA, 6 Oct, shop pin 3).
	if plan.spec.material != &"stone" and (plan.spec is ShopSpec
			or not plan.spec.has_method("room_program")):
		ShellAssembler.house_materials(shell, plan.spec)
	else:
		ShellAssembler.house_floor_material(shell, plan.spec)
	if plan.world_family != &"":
		# a family of the wider world is built of its own things (EVAL-B04)
		WorldAssembler.dress_house(shell, plan)
	root.add_child(shell)
	furnish(root, plan)
	dress_exterior(root, plan)
	return root


static func dress_exterior(root: Node3D, plan: HousePlan) -> void:
	var exterior := Node3D.new()
	exterior.name = "Exterior"
	root.add_child(exterior)
	if not plan.spec.exterior_props:
		return
	for p in plan.exterior:
		var node := _instance(p, false)
		if node == null:
			push_error("Missing exterior prop model: %s" % p["key"])
			continue
		node.name = p["id"]
		exterior.add_child(node)
		if PropCatalog.has_tag(p["key"], PropCatalog.LIGHT):
			exterior.add_child(LightKit.for_prop(p["key"], node.position,
				node.rotation.y, float(p["scale"])))
	# The yard's catalogue props, instantiated the same way as the facade
	# pieces: this is the only place a model loads. Its built pieces are in the
	# shell mesh (HouseBuilder._build_yard), not here.
	for p in plan.yard:
		var node := _instance(p, false)
		if node == null:
			push_error("Missing yard prop model: %s" % p["key"])
			continue
		node.name = p["id"]
		exterior.add_child(node)


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


## One piece of furniture, placed as the plan says. Exterior dressing already
## records a model origin and opts out of the interior centre convention.
static func _instance(p: Dictionary, centred := true) -> Node3D:
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
	if centred:
		node.position = PropCatalog.house_origin(p)
		return node
	var pos: Vector3 = p["pos"]
	# sit it on whatever it stands on: the floor, a table top, or its bracket
	var drop: float = PropCatalog.seat_offset(key) * scale_factor
	if PropCatalog.has_tag(key, PropCatalog.WALL_MOUNTED) \
			or PropCatalog.has_tag(key, PropCatalog.CEILING):
		drop = 0.0
	node.position = Vector3(pos.x, pos.y - drop, pos.z)
	return node


## The camera framing a house wants: high enough to see over the walls, and
## far enough back to hold the whole footprint.
static func viewing_distance(plan: HousePlan) -> float:
	# The PLAN-AWARE bound, not the spec-only one: this caller has a plan, so
	# it can know which wall the chimney and the porch are actually on instead
	# of being padded for all four.
	var shell: AABB = HouseGeometry.exterior_bounds(plan)
	var r := Rect2(Vector2(shell.position.x, shell.position.z),
		Vector2(shell.size.x, shell.size.z))
	if plan.spec.exterior_props:
		for p in plan.exterior + plan.yard:
			var b := HouseExterior.bounds_of(p)
			r = r.merge(Rect2(Vector2(b.position.x, b.position.z), Vector2(b.size.x, b.size.z)))
	return maxf(r.size.x, r.size.y) * 1.25 + 6.0
