class_name NormalsSuite
extends RefCounted
## 2. Normals: every triangle carries a finite unit normal that agrees with its
##    own winding, and every opening looks OUT of the wall it is cut into.
##
## This suite exists because two whole classes of defect were invisible to the
## massing checks -- which only ever measured AABBs, and an AABB cannot tell a
## window from a window turned sideways:
##
##   * inverted or degenerate winding, which backface culling renders as a hole;
##   * openings facing along the wall instead of through it, so the recess and
##     its surround stood proud of the stone as a flat panel.

## A triangle smaller than this is treated as degenerate rather than misfacing.
const MIN_AREA := 1e-6
## Cosine floor for "the stored normal agrees with the winding".
const AGREE_COS := 0.5
## Fraction of a surface's triangles that may disagree before it is a failure.
## Not zero: interior faces of embedded masses legitimately point inward.
const MAX_BAD_FRAC := 0.001
## How far either side of an opening to probe for solid material.
const PROBE := 0.35
## Masses are shrunk by this before the containment test, so a point on a wall
## face is not simultaneously inside and outside it.
const SKIN := 0.06
## An opening further than this from every logged mass is untracked detail.
const NEAR := 0.5


static func run() -> SuiteResult:
	var res := SuiteResult.new("normals")
	var worst_out := 1.0
	var worst_out_at := ""
	for style in TestSweep.styles():
		for i in range(TestSweep.COUNT):
			var spec: ChurchSpec = TestSweep.spec_at(style, i)
			var sd: int = TestSweep.seed_at(i)
			var where: String = "style=%s seed=%d" % [String(style), sd]
			var builder := ChurchBuilder.new()
			var mesh: ArrayMesh = builder.build(spec)
			res.checked += 1
			if mesh == null:
				res.fail("no mesh, " + where)
				continue
			_check_mesh(res, mesh, where)
			var frac: float = _check_openings(res, builder, where)
			if frac < worst_out:
				worst_out = frac
				worst_out_at = where
	res.note("openings facing outward: worst run %.0f%% (%s)"
		% [worst_out * 100.0, worst_out_at])
	return res


## Per-surface attribute integrity and winding agreement.
static func _check_mesh(res: SuiteResult, mesh: ArrayMesh, where: String) -> void:
	for s in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: Variant = arrays[Mesh.ARRAY_NORMAL]
		if norms == null:
			res.fail("surface %d has no normals, %s" % [s, where])
			continue
		var n: PackedVector3Array = norms
		if n.size() != verts.size():
			res.fail("surface %d normal/vertex count mismatch (%d vs %d), %s"
				% [s, n.size(), verts.size(), where])
			continue
		if verts.size() % 3 != 0:
			res.fail("surface %d vertex count %d is not a multiple of 3, %s"
				% [s, verts.size(), where])
			continue

		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		var order: PackedInt32Array = idx if idx != null else PackedInt32Array()
		if order.is_empty():
			for k in range(verts.size()):
				order.append(k)

		var bad_unit := 0
		for v in n:
			if not _finite(v) or absf(v.length() - 1.0) > 0.01:
				bad_unit += 1
		if bad_unit > 0:
			res.fail("surface %d has %d non-unit or non-finite normals, %s"
				% [s, bad_unit, where])

		var tris := 0
		var bad_wind := 0
		var degenerate := 0
		for t in range(0, order.size() - 2, 3):
			var a: Vector3 = verts[order[t]]
			var b: Vector3 = verts[order[t + 1]]
			var c: Vector3 = verts[order[t + 2]]
			# Godot front faces are clockwise, so this is the outward direction.
			var cr: Vector3 = (c - a).cross(b - a)
			if cr.length() < MIN_AREA:
				degenerate += 1
				continue
			tris += 1
			var geo: Vector3 = cr.normalized()
			# All three stored normals should sit on the winding's side.
			for vi in range(3):
				if geo.dot(n[order[t + vi]]) < AGREE_COS:
					bad_wind += 1
					break
		if tris > 0 and float(bad_wind) / float(tris) > MAX_BAD_FRAC:
			res.fail("surface %d: %d/%d triangles wound against their normal, %s"
				% [s, bad_wind, tris, where])
		if degenerate > 0:
			res.warn("surface %d has %d degenerate triangles, %s"
				% [s, degenerate, where])


## Every logged opening must face out through the wall it is cut into: a window
## in an X-facing wall has to look along +/-X, not along Z.
##
## The test deliberately does NOT try to work out which mass owns the opening.
## Two earlier attempts did -- nearest centroid, then nearest face -- and both
## drowned in false positives, because a nave window near the crossing is nearer
## to the transept than to the nave, and an aisle window is exactly as near to
## the ring outside it as to its own wall. Instead it probes the material either
## side of the opening: a window that faces the right way has stone behind it
## and open air in front, whichever mass the stone happens to belong to.
## Returns the fraction that passed.
static func _check_openings(res: SuiteResult, builder: ChurchBuilder,
		where: String) -> float:
	var total := 0
	var good := 0
	for part in builder.part_log:
		if part["kind"] != "window":
			continue
		var facing: Vector3 = part["facing"]
		if facing.length_squared() < 0.5:
			continue
		var f := Vector3(facing.x, 0.0, facing.z)
		if f.length() < 0.01:
			continue      # looks straight up or down; no wall to be wrong about
		f = f.normalized()
		var pos: Vector3 = part["pos"]
		if not _near_any_mass(builder, pos):
			continue      # spire, drum or lantern detail; no mass logged to probe
		total += 1
		var inside: Vector3 = pos - f * PROBE
		var outside: Vector3 = pos + f * PROBE
		var behind: bool = _in_solid(builder, inside)
		# A mass that swallows BOTH probes is the opening's own wall, seen
		# through its bounding box -- every apse and dome is curved but logged
		# as a box, so it reads as solid on the open side too. Only a DIFFERENT
		# mass counts as something built in front of the window.
		var ahead: bool = _in_solid(builder, outside, inside)
		if behind and not ahead:
			good += 1
		elif behind and ahead:
			# Correctly oriented, but something is built right in front of it.
			good += 1
			res.warn("[%s] opening at %v is walled in from outside (%s)"
				% [part["tag"], pos, where])
		elif ahead and not behind:
			res.fail("[%s] opening at %v faces %v -- into the building, not out of it (%s)"
				% [part["tag"], pos, f, where])
		else:
			res.fail("[%s] opening at %v faces %v, which runs ALONG its wall rather than through it (%s)"
				% [part["tag"], pos, f, where])
	if total == 0:
		return 1.0
	return float(good) / float(total)


## Is p inside any structural mass? When `unless_also` is given, masses that
## contain that point too are ignored.
static func _in_solid(builder: ChurchBuilder, p: Vector3,
		unless_also := Vector3.INF) -> bool:
	for m in builder.mass_log:
		var box: AABB = (m["aabb"] as AABB).grow(-SKIN)
		if not box.has_point(p):
			continue
		if unless_also != Vector3.INF and box.has_point(unless_also):
			continue
		return true
	return false


static func _near_any_mass(builder: ChurchBuilder, p: Vector3) -> bool:
	for m in builder.mass_log:
		if _dist_to_aabb(m["aabb"], p) <= NEAR:
			return true
	return false


## Distance from p to the surface of a, zero when p is inside it.
static func _dist_to_aabb(a: AABB, p: Vector3) -> float:
	var e: Vector3 = a.position + a.size
	var d := Vector3(
		maxf(maxf(a.position.x - p.x, 0.0), p.x - e.x),
		maxf(maxf(a.position.y - p.y, 0.0), p.y - e.y),
		maxf(maxf(a.position.z - p.z, 0.0), p.z - e.z))
	return d.length()


static func _finite(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)
