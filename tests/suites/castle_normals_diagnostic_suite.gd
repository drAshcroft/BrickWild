extends RefCounted
## Fixture-level evidence for CASTLE-NORMALS-WARNINGS.
## This is deliberately diagnostic: it reports the existing AABB warning and
## an independent ray/triangle observation without changing either verdict.

const CASES: Array[Dictionary] = [
	{"style": &"norman", "tier": &"manor", "index": 0},
	{"style": &"norman", "tier": &"castle", "index": 0},
	{"style": &"edwardian", "tier": &"fortress", "index": 0},
	{"style": &"japanese", "tier": &"castle", "index": 0},
]
const RAY_LENGTH := 1.0
const RAY_START := 0.02
const TRI_EPS := 1e-7


static func run() -> SuiteResult:
	var res := SuiteResult.new("castle normals fixture diagnostics")
	_ray_oracle_controls(res)
	for row in CASES:
		var spec: CastleSpec = CastleSweep.spec_at(row["style"], row["tier"], row["index"])
		var seed := CastleSweep.seed_at(row["tier"], row["index"])
		var where := "style=%s tier=%s index=%d seed=%d" % [
			String(row["style"]), String(row["tier"]), int(row["index"]), seed]
		var builder := CastleBuilder.new()
		var mesh: ArrayMesh = builder.build(spec)
		res.checked += 1
		if mesh == null:
			res.fail("no mesh, " + where)
			continue
		res.note("fixture %s dims=%.1fx%.1fx%.1fm" % [where, spec.width, spec.length, spec.height])
		NormalsSuite.check_mesh(res, mesh, where)
		NormalsSuite.check_openings(res, builder, where)
		_report_degenerate_roof_triangles(res, mesh, where)
		_report_aabb_probe_warnings(res, builder, mesh, where)
	return res


static func _ray_oracle_controls(res: SuiteResult) -> void:
	# A solid triangle spanning a probe ray must be reported; a nearby triangle
	# that does not span it must not be mistaken for opaque obstruction.
	var a := Vector3(0.5, -1.0, -1.0)
	var b := Vector3(0.5, 1.0, -1.0)
	var c := Vector3(0.5, 0.0, 1.0)
	var hit := _segment_triangle_t(Vector3.ZERO, Vector3.RIGHT, a, b, c)
	var miss := _segment_triangle_t(Vector3.ZERO, Vector3.UP, a, b, c)
	res.checked += 2
	if absf(hit - 0.5) > 0.001:
		res.fail("triangle ray positive control returned t=%.6f, expected 0.5" % hit)
	if miss >= 0.0:
		res.fail("triangle ray negative control reported t=%.6f for a non-intersecting segment" % miss)


static func _report_degenerate_roof_triangles(res: SuiteResult, mesh: ArrayMesh,
		where: String) -> void:
	var count := 0
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var raw_indices: Variant = arrays[Mesh.ARRAY_INDEX]
		var indices: PackedInt32Array = raw_indices if raw_indices != null else PackedInt32Array()
		if indices.is_empty():
			for i in range(verts.size()):
				indices.append(i)
		for t in range(0, indices.size() - 2, 3):
			var ia: int = indices[t]
			var ib: int = indices[t + 1]
			var ic: int = indices[t + 2]
			var a: Vector3 = verts[ia]
			var b: Vector3 = verts[ib]
			var c: Vector3 = verts[ic]
			var cross := (c - a).cross(b - a)
			if cross.length() >= NormalsSuite.MIN_AREA:
				continue
			count += 1
			res.note("DEGENERATE %s surface=%d triangle=%d indices=[%d,%d,%d] cross_len=%.9g vertices=[%s,%s,%s]"
				% [where, surface, t / 3, ia, ib, ic, cross.length(), str(a), str(b), str(c)])
	if count == 0:
		res.note("DEGENERATE %s none" % where)


static func _report_aabb_probe_warnings(res: SuiteResult, builder: CastleBuilder,
		mesh: ArrayMesh, where: String) -> void:
	for part in builder.part_log:
		if part.get("kind", "") != "window":
			continue
		var facing: Vector3 = part.get("facing", Vector3.ZERO)
		var horizontal := Vector3(facing.x, 0.0, facing.z)
		if horizontal.length_squared() < 0.0001:
			continue
		var f := horizontal.normalized()
		var pos: Vector3 = part.get("pos", Vector3.ZERO)
		if not NormalsSuite._near_any_mass(builder, pos):
			continue
		var inside := pos - f * NormalsSuite.PROBE
		var outside := pos + f * NormalsSuite.PROBE
		var behind := NormalsSuite._in_solid(builder, inside)
		var ahead := NormalsSuite._in_solid(builder, outside, inside)
		if not (behind and ahead):
			continue
		res.note("AABB_WARNING %s tag=%s pos=%s facing=%s part=%s inside=%s outside=%s"
			% [where, str(part.get("tag", "")), str(pos), str(f), str(part),
				str(_containing_masses(builder, inside)), str(_containing_masses(builder, outside))])
		_report_ray_hits(res, mesh, pos + f * RAY_START,
			pos + f * RAY_LENGTH, where, str(part.get("tag", "")))


static func _containing_masses(builder: CastleBuilder, point: Vector3) -> Array[String]:
	var found: Array[String] = []
	for mass in builder.mass_log:
		var box: AABB = mass["aabb"]
		box = box.grow(-NormalsSuite.SKIN)
		if box.size.x > 0.0 and box.size.y > 0.0 and box.size.z > 0.0 and box.has_point(point):
			found.append("%s:%s" % [str(mass.get("name", "?")), str(box)])
	return found


static func _report_ray_hits(res: SuiteResult, mesh: ArrayMesh, start: Vector3,
		finish: Vector3, where: String, tag: String) -> void:
	var direction := finish - start
	var nearest := 2.0
	var hit_detail := "none"
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var raw_indices: Variant = arrays[Mesh.ARRAY_INDEX]
		var indices: PackedInt32Array = raw_indices if raw_indices != null else PackedInt32Array()
		if indices.is_empty():
			for i in range(verts.size()):
				indices.append(i)
		for t in range(0, indices.size() - 2, 3):
			var ia: int = indices[t]
			var ib: int = indices[t + 1]
			var ic: int = indices[t + 2]
			var hit_t := _segment_triangle_t(start, direction,
				verts[ia], verts[ib], verts[ic])
			if hit_t < 0.0 or hit_t >= nearest:
				continue
			nearest = hit_t
			hit_detail = "surface=%d triangle=%d t=%.6f point=%s indices=[%d,%d,%d] vertices=[%s,%s,%s]"
				% [surface, t / 3, hit_t, str(start + direction * hit_t),
					ia, ib, ic, str(verts[ia]), str(verts[ib]), str(verts[ic])]
	res.note("TRIANGLE_RAY %s tag=%s from=%s to=%s hit=%s" % [
		where, tag, str(start), str(finish), hit_detail])


## Returns segment fraction in [0,1], or -1 when the segment misses the triangle.
static func _segment_triangle_t(start: Vector3, direction: Vector3,
		a: Vector3, b: Vector3, c: Vector3) -> float:
	var edge1 := b - a
	var edge2 := c - a
	var p := direction.cross(edge2)
	var determinant := edge1.dot(p)
	if absf(determinant) <= TRI_EPS:
		return -1.0
	var inv_det := 1.0 / determinant
	var from_a := start - a
	var u := from_a.dot(p) * inv_det
	if u < -TRI_EPS or u > 1.0 + TRI_EPS:
		return -1.0
	var q := from_a.cross(edge1)
	var v := direction.dot(q) * inv_det
	if v < -TRI_EPS or u + v > 1.0 + TRI_EPS:
		return -1.0
	var t := edge2.dot(q) * inv_det
	if t < -TRI_EPS or t > 1.0 + TRI_EPS:
		return -1.0
	return clampf(t, 0.0, 1.0)
