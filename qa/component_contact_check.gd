class_name ComponentContactCheck
extends RefCounted
## Does every logged beam end touch something? (HOUSE-EAVE-FLOAT)
##
## ComponentCheck proves the mesh holds what the log claims; it cannot see that
## a rafter tail, viga or ashlar was emitted in the air. This check takes a box
## component, removes its own triangles from the finished mesh, and requires
## some other triangle to lie within TOUCH_TOL of the box. A part that touches
## nothing is a block hovering at the eave. Parts buried in a slab pass: the
## slab's faces still pass within tolerance of at least one of the box faces.

const TOUCH_TOL := 0.005

## Roles that are beam ends, supports or trims and must be attached to the
## building. Prefix match on the role (before the '#').
const WATCH := ["eave_tail", "viga", "witch_ashlar", "witch_rafter", "rafter_tail",
	"toron", "verge_pendant", "gable_member", "witch_collar", "witch_kingpost",
	"witch_gable_raking_brace", "witch_entry_knee_brace"]


## {ok, failures:PackedStringArray, checked:int, floating:Array[Dictionary]}
static func check(builder: MassBuilder, mesh: ArrayMesh, watch: Array = WATCH,
		tol := TOUCH_TOL) -> Dictionary:
	var tris := _mesh_triangles(mesh)
	var failures := PackedStringArray()
	var floating: Array[Dictionary] = []
	var checked := 0
	for row in builder.component_log:
		if row["form"] != "box" or not _watched(String(row["role"]), watch):
			continue
		checked += 1
		var gap := box_gap(row, tris, tol)
		if gap > tol:
			floating.append({"id": row["id"], "host": row["host"], "gap": gap,
				"aabb": MassBuilder.component_aabb(row)})
			failures.append("%s (host %s) hovers %.3f m off the building at %s" % [
				row["id"], row["host"], gap, MassBuilder.component_aabb(row)])
	return {"ok": failures.is_empty(), "failures": failures, "checked": checked,
		"floating": floating}


## Triangles with a NaN or infinite vertex: a roof asked for at pitch 0 emitted
## a NaN ridge before HOUSE-EAVE-FLOAT.
static func non_finite_triangles(mesh: ArrayMesh) -> int:
	var n := 0
	for s in range(mesh.get_surface_count()):
		for v in (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if not v.is_finite():
				n += 1
	return n


static func _watched(role: String, watch: Array) -> bool:
	var base := role.split("#")[0]
	for w in watch:
		if base.begins_with(String(w)):
			return true
	return false


## Every triangle of the mesh as {a,b,c,lo,hi}.
static func _mesh_triangles(mesh: ArrayMesh) -> Array:
	var out := []
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var n: int = v.size() if idx == null else (idx as PackedInt32Array).size()
		for i in range(0, n - n % 3, 3):
			var a: Vector3 = v[i] if idx == null else v[idx[i]]
			var b: Vector3 = v[i + 1] if idx == null else v[idx[i + 1]]
			var c: Vector3 = v[i + 2] if idx == null else v[idx[i + 2]]
			# a NaN triangle "touches" nothing and everything: it is a defect of
			# its own (reported by non_finite_triangles), not a host
			if not (a.is_finite() and b.is_finite() and c.is_finite()):
				continue
			out.append({"a": a, "b": b, "c": c,
				"key": ComponentCheck.triangle_key(a, b, c),
				"lo": a.min(b).min(c), "hi": a.max(b).max(c)})
	return out


## Smallest distance from the box to any triangle that is not one of its own.
## 0 when it is buried or cuts through one.
static func box_gap(row: Dictionary, tris: Array, reach := TOUCH_TOL) -> float:
	var xf: Transform3D = row["xf"]
	var h: Vector3 = (row["size"] as Vector3) * 0.5
	var own := MeshKit.new(1)
	own.oriented_box(row["size"], xf, 0)
	var own_arrays := own.commit().surface_get_arrays(0)
	var own_counts := ComponentCheck.triangle_counts(ComponentCheck._triangle_vertices(own_arrays))
	var box := MassBuilder.component_aabb(row).grow(maxf(reach * 4.0, 0.05))
	var samples := PackedVector3Array()
	for sx in [-1.0, 0.0, 1.0]:
		for sy in [-1.0, 0.0, 1.0]:
			for sz in [-1.0, 0.0, 1.0]:
				if sx == 0.0 and sy == 0.0 and sz == 0.0:
					continue
				samples.append(xf * Vector3(h.x * sx, h.y * sy, h.z * sz))
	var corners := PackedVector3Array()
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				corners.append(xf * Vector3(h.x * sx, h.y * sy, h.z * sz))
	var edges := []
	for i in range(8):
		for bit in [1, 2, 4]:
			if i & bit == 0:
				edges.append([corners[i], corners[i | bit]])
	var best := INF
	var spent := {}
	for t in tris:
		if not box.intersects(AABB(t["lo"], t["hi"] - t["lo"])) \
				and not box.has_point(t["lo"]) and not box.has_point(t["hi"]):
			continue
		var key: String = t["key"]
		if own_counts.get(key, 0) > int(spent.get(key, 0)):
			spent[key] = int(spent.get(key, 0)) + 1
			continue
		# A triangle crossing the box's interior touches it.
		var inv := xf.affine_inverse()
		var la: Vector3 = inv * t["a"]
		var lb: Vector3 = inv * t["b"]
		var lc: Vector3 = inv * t["c"]
		var lbox := AABB(-h, h * 2.0)
		if lbox.has_point(la) or lbox.has_point(lb) or lbox.has_point(lc):
			return 0.0
		# a roof face slicing through the box, no corner of either inside the other
		for e in edges:
			var edge_len: float = e[0].distance_to(e[1])
			if edge_len < 1e-6:
				continue
			var hit = Geometry3D.ray_intersects_triangle(e[0], (e[1] - e[0]) / edge_len,
				t["a"], t["b"], t["c"])
			if hit != null and (hit as Vector3).distance_to(e[0]) <= edge_len:
				return 0.0
		for p in samples:
			var d := p.distance_to(_closest_on_triangle(p, t["a"], t["b"], t["c"]))
			if d < best:
				best = d
		# triangle corners against the box (a small roof face laid against it)
		for q in [t["a"], t["b"], t["c"]]:
			var lq: Vector3 = inv * q
			var cl := lq.clamp(-h, h)
			best = minf(best, lq.distance_to(cl))
	return best


## Ericson, Real-Time Collision Detection 5.1.5.
static func _closest_on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denom := 1.0 / (va + vb + vc)
	return a + ab * (vb * denom) + ac * (vc * denom)
