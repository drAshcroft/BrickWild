extends RefCounted
## Reusable emitted-mesh probes. Material slot alone is NOT a roof contract:
## callers supply expected covered regions and the height above occupied space.
const Rays = preload("res://tests/suites/church_roof_suite.gd")

static func inspect(mesh: ArrayMesh, bottom: float, surface := 2) -> Dictionary:
	var out := {"checked": 1, "failures": [], "warnings": [], "triangles": 0, "mesh_findings": []}
	if mesh == null or surface >= mesh.get_surface_count():
		out.failures.append("roof_surface: missing surface %d" % surface)
		return out
	if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
		out.failures.append("roof_surface: expected triangles")
		return out
	var arrays := mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if arrays[Mesh.ARRAY_NORMAL] == null:
		out.failures.append("roof_normals: missing normals")
		return out
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if normals.size() != vertices.size():
		out.failures.append("roof_normals: vertex/normal count mismatch")
		return out
	var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if order.is_empty():
		for i in vertices.size():
			order.append(i)
	if order.size() % 3 != 0:
		out.failures.append("roof_surface: incomplete triangle")
		return out
	for index in order:
		if index < 0 or index >= vertices.size():
			out.failures.append("roof_surface: invalid vertex index %d" % index)
			return out
	var bad := 0
	var degenerate := 0
	var duplicates := 0
	var seen := {}
	for i in range(0, order.size() - 2, 3):
		var a := vertices[order[i]]
		var b := vertices[order[i + 1]]
		var c := vertices[order[i + 2]]
		if not a.is_finite() or not b.is_finite() or not c.is_finite():
			out.failures.append("roof_finite: triangle %d contains non-finite coordinates" % (i / 3))
			continue
		if maxf(a.y, maxf(b.y, c.y)) < bottom:
			continue
		out.triangles += 1
		var cross := (c - a).cross(b - a)
		if cross.length() < 0.000001:
			degenerate += 1
			out.mesh_findings.append(_finding("roof_degenerate", i / 3, a, b, c))
			continue
		var invalid := false
		for j in 3:
			var n := normals[order[i + j]]
			invalid = invalid or not n.is_finite() or absf(n.length() - 1) > 0.01 or cross.normalized().dot(n) < 0.5
		if invalid:
			bad += 1
			out.mesh_findings.append(_finding("roof_normals", i / 3, a, b, c))
		var key: Array[String] = [_point_key(a), _point_key(b), _point_key(c)]
		key.sort()
		var signature := ";".join(key)
		if seen.has(signature):
			duplicates += 1
			var finding := _finding("roof_duplicate", i / 3, a, b, c)
			finding.first_triangle = seen[signature]
			out.mesh_findings.append(finding)
		else:
			seen[signature] = i / 3
	if out.triangles == 0:
		out.failures.append("roof_surface: no roof triangles above %.3fm" % bottom)
	if bad > 0:
		out.failures.append("roof_normals: %d triangles have invalid normals or disagree with clockwise winding" % bad)
	# Zero-area poles and touching solids can be intentional. Keep visible in
	# the audit as warnings; do not claim these are proven envelope defects.
	if degenerate > 0:
		out.warnings.append("roof_degenerate: %d zero-area triangles above %.3fm" % [degenerate, bottom])
	if duplicates > 0:
		out.warnings.append("roof_duplicate: %d coincident triangles; inspect for z-fighting or intentional shared boundaries" % duplicates)
	return out

static func _finding(rule: String, triangle: int, a: Vector3, b: Vector3, c: Vector3) -> Dictionary:
	return {"rule": rule, "triangle": triangle, "vertices": [[a.x,a.y,a.z], [b.x,b.y,b.z], [c.x,c.y,c.z]]}

static func _point_key(p: Vector3) -> String:
	return "%d,%d,%d" % [roundi(p.x * 10000), roundi(p.y * 10000), roundi(p.z * 10000)]

## Deterministic offset grid avoids exact triangulation seams. `openings`
## are explicit sky polygons, not guessed from absent geometry. Every miss
## is retained numerically; the console can present only the first few.
static func coverage(mesh: ArrayMesh, polygon: PackedVector2Array, bottom: float,
		openings: Array[PackedVector2Array] = [], expect_sky := false, steps := 13) -> Dictionary:
	var out := {"checked": 0, "misses": [], "covered": 0}
	var rect := Poly.bounding_rect(polygon)
	var tris := Rays._triangles(mesh, 2)
	var top := mesh.get_aabb().end.y + 1.0
	for ix in steps:
		for iz in steps:
			var p := rect.position + rect.size * Vector2((ix + 0.37) / steps, (iz + 0.61) / steps)
			if not Geometry2D.is_point_in_polygon(p, polygon):
				continue
			if openings.any(func(hole: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(p, hole)):
				continue
			out.checked += 1
			var hit := Rays._intersects(tris, Vector3(p.x, bottom, p.y), Vector3(p.x, top, p.y))
			if hit:
				out.covered += 1
			if hit == expect_sky:
				out.misses.append([p.x, bottom, p.y])
	return out

## A dormer body must meet the host roof at its rear edge. Take the host
## mesh before dormers are added, so a floating box cannot support itself.
static func attachment(host: ArrayMesh, position: Vector3, size: Vector3) -> Dictionary:
	var x := position.x
	var z := position.z + size.z * 0.5 - 0.02
	var hits := Rays._heights(Rays._triangles(host, 2), x, z,
		host.get_aabb().position.y - 1, host.get_aabb().end.y + 1)
	var bottom := position.y - size.y * 0.5
	var roof_top: float = hits[-1] if not hits.is_empty() else -INF
	return {"attached": roof_top >= bottom - 0.03 and roof_top <= position.y + size.y * 0.5 + 0.03,
		"sample": [x, z], "body_bottom": bottom,
		"host_top": roof_top if is_finite(roof_top) else null,
		"gap": bottom - roof_top if is_finite(roof_top) else null}

static func self_test() -> SuiteResult:
	var res := SuiteResult.new("roof probe controls")
	var kit := MeshKit.new(3)
	for s in 2:
		kit.box(Vector3.ONE, Vector3(-20, -20, -20), s)
	kit.box(Vector3(4, 0.24, 4), Vector3(0, 2, 0), 2)
	var good := kit.commit()
	var footprint := Poly.from_rect(Rect2(-1.9, -1.9, 3.8, 3.8))
	_expect(res, inspect(good, 1.0).failures.is_empty(), "valid slab rejected")
	_expect(res, coverage(good, footprint, 1.0).misses.is_empty(), "covered floor rejected")
	_expect(res, not coverage(good, Poly.from_rect(Rect2(-3,-3,6,6)), 1.0).misses.is_empty(), "missing roof region accepted")
	_expect(res, not coverage(good, footprint, 1.0, [], true).misses.is_empty(), "roof over courtyard accepted")
	_expect(res, coverage(good, footprint, 1.0, [footprint]).checked == 0, "explicit opening ignored")
	_expect(res, attachment(good, Vector3(0, 2.5, 0), Vector3.ONE).attached, "attached dormer rejected")
	_expect(res, not attachment(good, Vector3(0, 4, 0), Vector3.ONE).attached, "floating dormer accepted")
	var bad := ArrayMesh.new()
	for s in 3:
		var arrays := good.surface_get_arrays(s)
		if s == 2:
			var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in n.size():
				n[i] = -n[i]
			arrays[Mesh.ARRAY_NORMAL] = n
		bad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_expect(res, not inspect(bad, 1.0).failures.is_empty(), "reversed normals accepted")
	var doubled := ArrayMesh.new()
	for s in 3:
		var arrays := good.surface_get_arrays(s)
		if s == 2:
			for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL]:
				var values: PackedVector3Array = arrays[slot]
				values.append_array(values.duplicate())
				arrays[slot] = values
			arrays[Mesh.ARRAY_COLOR] = null
			arrays[Mesh.ARRAY_TEX_UV] = null
			arrays[Mesh.ARRAY_TANGENT] = null
		doubled.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var duplicate_report := inspect(doubled, 1.0)
	_expect(res, not duplicate_report.warnings.is_empty() and not duplicate_report.mesh_findings.is_empty(), "duplicate triangles not diagnosed with locations")
	return res

static func _expect(res: SuiteResult, ok: bool, message: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(message)
