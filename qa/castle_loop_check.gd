class_name CastleLoopCheck
extends RefCounted
## An arrow loop is a place to stand as much as a hole in a wall.
##
## Every curtain slit cut right through the masonry must have, a step behind
## its outer skin, a floor an archer can stand on below its sill and a clear
## body's height above that floor. A slit pierced straight through four metres
## of wall halfway up the curtain has neither: from the ward it is a hole with
## no way to it (walk-QA, Thorncliffe pin 14).
##
## Measured on the emitted mesh, from the logged opening; the ward's ground is
## the ring's site datum, since courtyard earth is optional dressing.

## How far in from the outer face the archer stands.
const STAND := 1.0
## The floor lies between this far and BODY_LOW below the slit's sill.
const SILL_MAX := 1.3
const SILL_MIN := 0.3
## The clear column above the floor.
const BODY_LOW := 0.1
const BODY_HIGH := 1.8


## Failure strings, one per unreachable loop.
static func check(spec: CastleSpec, builder: CastleBuilder, mesh: ArrayMesh) -> Array[String]:
	var out: Array[String] = []
	if spec == null or mesh == null:
		return out
	var triangles: Array = []
	for surface in mesh.get_surface_count():
		if surface != CastleBuilder.SURF_OPEN and surface != CastleBuilder.SURF_WATER \
				and surface != CastleBuilder.SURF_DRESS:
			triangles.append_array(HouseQA._mesh_triangles(mesh, surface))
	var grounds: Array[float] = []
	for ring in CastleGeometry.rings(spec):
		grounds.append(CastleGeometry.ring_ground_y(spec, ring))
	if grounds.is_empty():
		grounds.append(0.0)
	for part in builder.part_log:
		if part.get("kind") != "window" or String(part.get("tag", "")) != "curtain":
			continue
		if not bool(part.get("through_opening", false)):
			continue
		var why := unreachable(part, triangles, grounds)
		if not why.is_empty():
			out.append("loops_reachable: curtain loop at %s %s" % [Vector3(part.pos).snapped(Vector3.ONE * 0.01), why])
	return out


## Empty when an archer can stand behind `part`; otherwise the reason.
static func unreachable(part: Dictionary, triangles: Array, grounds: Array[float]) -> String:
	var pos: Vector3 = part.pos
	var facing: Vector3 = Vector3(part.facing)
	facing.y = 0.0
	if facing.length_squared() < 0.5:
		return "has no facing"
	facing = facing.normalized()
	var size: Vector3 = part.get("size", Vector3(0.32, 1.5, 0.0))
	var sill := pos.y - size.y * 0.5
	var stand := pos - facing * STAND
	var near := _near(triangles, AABB(Vector3(stand.x, sill - SILL_MAX - 0.1, stand.z),
		Vector3.ZERO).grow(0.05).expand(Vector3(stand.x, sill + BODY_HIGH + 0.1, stand.z)))
	# The floor: the highest up-facing surface below the sill, or the site.
	var floor_y := -INF
	for t in near:
		var hit: Variant = Geometry3D.segment_intersects_triangle(
			Vector3(stand.x, sill + 0.05, stand.z), Vector3(stand.x, sill - SILL_MAX, stand.z),
			t[0], t[1], t[2])
		if hit != null and _up(t):
			floor_y = maxf(floor_y, (hit as Vector3).y)
	for g in grounds:
		if g <= sill - SILL_MIN + 0.001 and g >= sill - SILL_MAX:
			floor_y = maxf(floor_y, g)
	if not is_finite(floor_y):
		return "has no floor within %.1fm below its sill" % SILL_MAX
	for t in near:
		if Geometry3D.segment_intersects_triangle(
				Vector3(stand.x, floor_y + BODY_LOW, stand.z),
				Vector3(stand.x, floor_y + BODY_HIGH, stand.z), t[0], t[1], t[2]) != null:
			return "has masonry where its archer would stand"
	return ""


static func _up(t: Array) -> bool:
	var n: Vector3 = (t[2] - t[0]).cross(t[1] - t[0])
	return n.y > 0.0 and n.normalized().y > 0.7


static func _near(triangles: Array, box: AABB) -> Array:
	var out: Array = []
	for t in triangles:
		if box.intersects(AABB(t[0], Vector3.ZERO).expand(t[1]).expand(t[2]).grow(0.001)):
			out.append(t)
	return out
