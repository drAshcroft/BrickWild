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
