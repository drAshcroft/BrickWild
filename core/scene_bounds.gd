class_name SceneBounds
extends RefCounted
## Measuring an imported model: the union of every mesh in it, in the root's
## own space.
##
## Used twice, and that is the point. tools/build_prop_catalog.gd measures each
## prop once and writes the numbers down; the house assets suite measures them
## again and compares. Two copies of this function could drift apart, and then
## the check would be agreeing with itself instead of with the model.
static func of_node(node: Node, xform := Transform3D.IDENTITY) -> AABB:
	var out := AABB()
	var seen := false
	var here: Transform3D = xform
	if node is Node3D:
		here = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out = here * (node as MeshInstance3D).mesh.get_aabb()
		seen = true
	for child in node.get_children():
		var sub: AABB = of_node(child, here)
		if sub.size == Vector3.ZERO:
			continue
		out = sub if not seen else out.merge(sub)
		seen = true
	return out


## Everything a PLANT is measured by (VILLAGES §8), in one walk of its
## vertices: {"box": AABB, "canopy": float, "trunk": float}.
##
## Two departures from of_node() above, both of them because a plant is not a
## box of masonry:
##
## 1. It is measured from the VERTICES, not from each mesh's declared
##    bounding box. Two of the Nature Kit's bushes ship an AABB half a metre
##    bigger in every direction than the mesh inside it, and a bush sat down
##    on that box floats. Trusting the declared box is right for a barrel --
##    it is cheap and every pack means it -- and wrong here.
## 2. It also gets two RADII about the model's own vertical axis, because the
##    box is the wrong shape for a tree: a birch is a two metre box of empty
##    air with a 16 cm stem in the middle of it, and a village planted on the
##    box has no trees within four metres of anything.
##      canopy  the furthest any vertex reaches from that axis -- the crown,
##              which is what must not hang over a roof
##      trunk   the same, at or below `TRUNK_HEIGHT` -- what a person walking
##              into the plant would walk into, which is what must stay off
##              the road
##
## `trunk` is deliberately not "the lowest slice". A birch is a bare stem at
## head height and measures its 16 cm; a spruce whose skirt sweeps the ground
## measures the skirt, and a bush measures the whole bush -- which is right,
## because you cannot walk through any of them. A thin slice at the base
## would have called the bush 0 and the spruce a stem.
##
## Here rather than in the tool for the reason of_node() is here: the tool
## writes these numbers into catalog.json and the assets suite measures them
## again, and two copies of the measurement would agree with each other
## rather than with the model.
const TRUNK_HEIGHT := 1.8


static func plant_of_node(node: Node) -> Dictionary:
	var span: Array = _vertex_span(node, Transform3D.IDENTITY)
	if span.is_empty():
		return {"box": AABB(), "canopy": 0.0, "trunk": 0.0}
	var lo: Vector3 = span[0]
	var hi: Vector3 = span[1]
	var band: float = lo.y + minf(TRUNK_HEIGHT, hi.y - lo.y)
	var radii: Vector2 = _gather_radii(node, Transform3D.IDENTITY, band)
	return {"box": AABB(lo, hi - lo), "canopy": snappedf(radii.x, 0.001),
		"trunk": snappedf(radii.y, 0.001)}


## The true extent of every vertex under `node`, as [lo, hi], or [] for a
## node with no mesh in it.
static func _vertex_span(node: Node, xform: Transform3D) -> Array:
	var here: Transform3D = xform
	if node is Node3D:
		here = xform * (node as Node3D).transform
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var seen := false
	for verts in _meshes_of(node, here):
		for v in verts:
			lo = lo.min(v)
			hi = hi.max(v)
			seen = true
	for child in node.get_children():
		var sub: Array = _vertex_span(child, here)
		if sub.is_empty():
			continue
		lo = lo.min(sub[0])
		hi = hi.max(sub[1])
		seen = true
	return [lo, hi] if seen else []


## The widest (canopy, trunk) radius over every vertex under `node`. Returned
## rather than accumulated into an out-parameter: a Vector2 is a value in
## GDScript, so a callee cannot widen the caller's copy.
static func _gather_radii(node: Node, xform: Transform3D, band: float) -> Vector2:
	var here: Transform3D = xform
	if node is Node3D:
		here = xform * (node as Node3D).transform
	var acc := Vector2.ZERO
	for verts in _meshes_of(node, here):
		for v in verts:
			var r: float = Vector2(v.x, v.z).length()
			acc.x = maxf(acc.x, r)
			if v.y <= band:
				acc.y = maxf(acc.y, r)
	for child in node.get_children():
		var sub: Vector2 = _gather_radii(child, here, band)
		acc = Vector2(maxf(acc.x, sub.x), maxf(acc.y, sub.y))
	return acc


## This node's own surfaces, each as its vertices already placed by `here`.
## One array per surface; empty for anything that is not a mesh.
static func _meshes_of(node: Node, here: Transform3D) -> Array:
	var mesh_node := node as MeshInstance3D
	if mesh_node == null or mesh_node.mesh == null:
		return []
	var out: Array = []
	for s in range(mesh_node.mesh.get_surface_count()):
		var verts: PackedVector3Array = \
			mesh_node.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		var placed := PackedVector3Array()
		placed.resize(verts.size())
		for i in range(verts.size()):
			placed[i] = here * verts[i]
		out.append(placed)
	return out
