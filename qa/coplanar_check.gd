class_name CoplanarCheck
extends RefCounted
## Z-fighting, measured: two triangles of an emitted mesh that lie in the same
## plane, face the same way and overlap. The renderer cannot order them, so the
## overlap flickers between the two -- a door jamb against its own reveal, the
## underside of an upper partition against the floor it stands on (WALK-QA,
## 6 Oct: hotel pins 1 and 12, shop pin 2).
##
## Two faces that meet back to back (a pier against the panel beside it, a
## wall standing on a floor) face OPPOSITE ways and are not reported: that
## seam is inside the solid. Only same-facing overlap is, and only above
## `min_area`, so a shared edge or a corner touch is not a finding.
##
## This reads the mesh alone. It cannot tell whether an overlap is hidden
## behind something else, so a caller judges a finding by where it is; the
## house-family suite holds the count of the overlaps it knows to be visible
## at zero.

## Coplanar within this distance, metres. Depth buffers fight well past a
## millimetre at walking distance, so this is generous on purpose.
const PLANE_TOL := 0.002
## Overlaps smaller than this, square metres, are edge contact and rounding.
const MIN_AREA := 0.0004
## Normals this close are the same direction.
const NORMAL_COS := 0.9995
## A downward face at or below this height sits on the ground and is not seen.
const GROUND_Y := 0.005


## Every overlapping same-facing coplanar pair, as
## {"surfaces": Vector2i, "area": float, "at": Vector3, "normal": Vector3}.
## `surfaces` filters to those surface indices when not empty.
static func find(mesh: ArrayMesh, surfaces: Array = [],
		min_area := MIN_AREA) -> Array[Dictionary]:
	var tris: Array = []  # [a, b, c, n, d, surface]
	if mesh == null:
		return []
	for s in range(mesh.get_surface_count()):
		if not surfaces.is_empty() and s not in surfaces:
			continue
		if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx_value: Variant = arrays[Mesh.ARRAY_INDEX]
		var idx := PackedInt32Array()
		if idx_value != null:
			idx = idx_value
		var count: int = idx.size() if not idx.is_empty() else v.size()
		for t in range(0, count - 2, 3):
			var a: Vector3 = v[idx[t]] if not idx.is_empty() else v[t]
			var b: Vector3 = v[idx[t + 1]] if not idx.is_empty() else v[t + 1]
			var c: Vector3 = v[idx[t + 2]] if not idx.is_empty() else v[t + 2]
			var n: Vector3 = (c - a).cross(b - a)
			if n.length() < 1e-9:
				continue
			n = n.normalized()
			# a face pressed onto the ground plane is never seen from anywhere
			if n.y < -NORMAL_COS and maxf(a.y, maxf(b.y, c.y)) < GROUND_Y:
				continue
			tris.append([a, b, c, n, n.dot(a), s])
	# group by direction: a coarse key, then exact comparison inside it
	var groups := {}
	for i in range(tris.size()):
		var n: Vector3 = tris[i][3]
		var key := Vector3i(roundi(n.x * 50.0), roundi(n.y * 50.0), roundi(n.z * 50.0))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(i)
	var out: Array[Dictionary] = []
	for key in groups:
		var members: Array = groups[key]
		members.sort_custom(func(x: int, y: int) -> bool:
			return float(tris[x][4]) < float(tris[y][4]))
		var n0: Vector3 = tris[members[0]][3]
		var u: Vector3 = n0.cross(Vector3.UP if absf(n0.y) < 0.9 else Vector3.RIGHT).normalized()
		var w: Vector3 = n0.cross(u)
		var flat := {}
		for i in members:
			flat[i] = PackedVector2Array([
				Vector2(tris[i][0].dot(u), tris[i][0].dot(w)),
				Vector2(tris[i][1].dot(u), tris[i][1].dot(w)),
				Vector2(tris[i][2].dot(u), tris[i][2].dot(w))])
		for x in range(members.size()):
			var i: int = members[x]
			var di: float = tris[i][4]
			var bi := _bounds(flat[i])
			for y in range(x + 1, members.size()):
				var j: int = members[y]
				if float(tris[j][4]) - di > PLANE_TOL:
					break
				if Vector3(tris[i][3]).dot(tris[j][3]) < NORMAL_COS:
					continue
				if not bi.intersects(_bounds(flat[j])):
					continue
				var area := 0.0
				for piece in Geometry2D.intersect_polygons(_ccw(flat[i]), _ccw(flat[j])):
					area += absf(_area(piece))
				if area < min_area:
					continue
				out.append({"surfaces": Vector2i(tris[i][5], tris[j][5]), "area": area,
					"at": (Vector3(tris[i][0]) + tris[i][1] + tris[i][2]) / 3.0,
					"normal": tris[i][3]})
	return out


## The findings summed per surface pair, for a one-line report.
static func summary(found: Array[Dictionary]) -> Dictionary:
	var out := {}
	for f in found:
		var s: Vector2i = f["surfaces"]
		var key := "%d/%d" % [mini(s.x, s.y), maxi(s.x, s.y)]
		out[key] = float(out.get(key, 0.0)) + float(f["area"])
	return out


static func _bounds(p: PackedVector2Array) -> Rect2:
	var r := Rect2(p[0], Vector2.ZERO)
	r = r.expand(p[1])
	return r.expand(p[2])


static func _area(p: PackedVector2Array) -> float:
	var s := 0.0
	for k in range(p.size()):
		s += p[k].cross(p[(k + 1) % p.size()])
	return s * 0.5


static func _ccw(p: PackedVector2Array) -> PackedVector2Array:
	if _area(p) >= 0.0:
		return p
	return PackedVector2Array([p[0], p[2], p[1]])
