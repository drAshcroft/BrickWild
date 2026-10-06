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
	return _of_node(node, xform, Basis.IDENTITY, true)


## `inner` is the turn accumulated INSIDE the model, below `node`'s root: the
## root's own transform is where the model was put (a yard's yaw) and keeps the
## old measurement, the turned declared box every bounds_of() agrees with.
static func _of_node(node: Node, xform: Transform3D, inner: Basis, is_root: bool) -> AABB:
	var out := AABB()
	var seen := false
	var here: Transform3D = xform
	if node is Node3D:
		here = xform * (node as Node3D).transform
		if not is_root:
			inner = inner * (node as Node3D).transform.basis
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		if _axis_aligned(inner):
			out = here * (node as MeshInstance3D).mesh.get_aabb()
		else:
			# A box turned by anything but quarter turns is not a box any more:
			# its AABB is the AABB of the turned corners, which can be half as
			# big again as the mesh. The dungeon kit's cart is exported turned
			# and scaled ~400x; its declared box put its floor 1.32 m below its
			# lowest wheel, and a yard set it down 0.53 m in the air (walk QA,
			# Wolfmarch Green pin 3). Measure such a mesh by its vertices.
			out = _vertex_box(node as MeshInstance3D, here)
		seen = true
	for child in node.get_children():
		var sub: AABB = _of_node(child, here, inner, false)
		if sub.size == Vector3.ZERO:
			continue
		out = sub if not seen else out.merge(sub)
		seen = true
	return out


## True when `b` maps each axis onto an axis (any scale, quarter turns, mirrors),
## so the transformed AABB of a box is still exactly that box's extent.
static func _axis_aligned(b: Basis) -> bool:
	for column in [b.x, b.y, b.z]:
		var v: Vector3 = (column as Vector3).abs()
		var big: float = maxf(v.x, maxf(v.y, v.z))
		if big <= 0.0:
			continue
		var count := 0
		for c in [v.x, v.y, v.z]:
			if c > big * 1e-4:
				count += 1
		if count > 1:
			return false
	return true


static func _vertex_box(mesh_node: MeshInstance3D, here: Transform3D) -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for verts in _meshes_of(mesh_node, here):
		for v in verts:
			lo = lo.min(v)
			hi = hi.max(v)
	if lo.x == INF:
		return here * mesh_node.mesh.get_aabb()
	return AABB(lo, hi - lo)


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
		return {"box": AABB(), "canopy": 0.0, "trunk": 0.0, "seat": 0.0}
	var lo: Vector3 = span[0]
	var hi: Vector3 = span[1]
	var band: float = lo.y + minf(TRUNK_HEIGHT, hi.y - lo.y)
	var radii: Vector2 = _gather_radii(node, Transform3D.IDENTITY, band)
	var base: Vector2 = base_heights(node)
	return {"box": AABB(lo, hi - lo), "canopy": snappedf(radii.x, 0.001),
		"trunk": snappedf(radii.y, 0.001), "seat": snappedf(plant_seat(lo.y, base.y), 0.001)}


## The height a plant is SAT on: the ground line of the model, which is not
## always its lowest vertex. The nature packs model a plant with its origin on
## the ground and a stub of stem or root below it -- seven of the common bush's
## 1800 vertices hang 0.235 m under its origin -- and a bush sat on that stub
## floats its whole leaf mass a quarter of a metre up (walk QA, Wolfmarch Green
## pin 1). So: the height under which only `SEAT_SHARE` of the vertices lie,
## but never above the model's own origin, which is the pack's ground line,
## and never below the lowest vertex. A plant whose bottom is a dense dome
## measures (nearly) its lowest vertex; a tree whose crown outweighs its trunk
## is held at its origin rather than sunk into the crown.
const SEAT_SHARE := 0.01


static func plant_seat(lowest: float, share_height: float) -> float:
	return clampf(share_height, lowest, maxf(lowest, 0.0))


## (lowest vertex height, the height under which SEAT_SHARE of the vertices
## lie) for every mesh under `node`, placed by `xform`. Shared by the catalogue
## measurement and the village ground check, so the check judges a plant by the
## same ground line the assembler sat it on.
static func base_heights(node: Node, xform := Transform3D.IDENTITY) -> Vector2:
	var heights := PackedFloat32Array()
	_gather_heights(node, xform, heights)
	if heights.is_empty():
		return Vector2.ZERO
	heights.sort()
	return Vector2(heights[0], heights[int(SEAT_SHARE * float(heights.size() - 1))])


static func _gather_heights(node: Node, xform: Transform3D, out: PackedFloat32Array) -> void:
	var here: Transform3D = xform
	if node is Node3D:
		here = xform * (node as Node3D).transform
	for verts in _meshes_of(node, here):
		for v in verts:
			out.append(v.y)
	for child in node.get_children():
		_gather_heights(child, here, out)


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
