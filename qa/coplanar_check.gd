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
				var cen := Vector2.ZERO
				for piece in Geometry2D.intersect_polygons(_ccw(flat[i]), _ccw(flat[j])):
					var pa := absf(_area(piece))
					area += pa
					var cc := Vector2.ZERO
					for q in piece:
						cc += q
					cen += cc / float(piece.size()) * pa
				if area < min_area:
					continue
				# `at` is the middle of the OVERLAP: a big wall triangle's own
				# centroid can be metres from where the flicker is
				out.append({"surfaces": Vector2i(tris[i][5], tris[j][5]), "area": area,
					"at": u * (cen.x / area) + w * (cen.y / area) + n0 * float(tris[i][4]),
					"normal": tris[i][3]})
	return out


## An overlap a person can see, per walk QA (3-7 Oct, 15 z-fight pins, every
## one found by `find` and none reported, because nothing called it):
##   - two DIFFERENT material slots: the same material fighting itself renders
##     the same colour either way and nobody sees it;
##   - at least GATE_AREA: the smallest pinned overlap was 0.014 m2;
##   - in air: a point just off the overlap along its normal is outside the
##     solid (winding number < 0.5). Skip with `closed = false` for a mesh
##     whose shells are not closed (castle battlements wind 0.4-0.7).
## Returns "coplanar: ..." lines naming the surfaces, area and place.
const GATE_AREA := 0.01


static func visible(mesh: ArrayMesh, where: String, closed := true) -> Array[String]:
	var out: Array[String] = []
	if mesh == null:
		return out
	var wind: Winding = Winding.new(mesh) if closed else null
	for f in find(mesh):
		var s: Vector2i = f["surfaces"]
		if s.x == s.y or float(f["area"]) < GATE_AREA:
			continue
		if wind != null and absf(wind.at(Vector3(f["at"]) + Vector3(f["normal"]) * 0.003)) >= 0.5:
			continue
		var at: Vector3 = f["at"]
		out.append("coplanar: %s surfaces %d/%d fight over %.3f m2 at (%.2f, %.2f, %.2f)"
			% [where, s.x, s.y, f["area"], at.x, at.y, at.z])
	return out


## Is a point inside the solid? The generalised winding number over the
## triangles within R of it; every emitted box is closed, so the sum counts
## the boxes that contain the point and far ones contribute about nothing.
class Winding:
	const CELL := 1.0
	const R := 2.0
	var tris: Array = []
	var grid := {}

	func _init(mesh: ArrayMesh) -> void:
		for s in mesh.get_surface_count():
			if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arr := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var iv = arr[Mesh.ARRAY_INDEX]
			var idx := PackedInt32Array() if iv == null else PackedInt32Array(iv)
			var cnt := idx.size() if not idx.is_empty() else v.size()
			for t in range(0, cnt - 2, 3):
				var a: Vector3 = v[idx[t]] if not idx.is_empty() else v[t]
				var b: Vector3 = v[idx[t + 1]] if not idx.is_empty() else v[t + 1]
				var c: Vector3 = v[idx[t + 2]] if not idx.is_empty() else v[t + 2]
				var k := tris.size()
				tris.append([a, b, c])
				var lo := a.min(b).min(c)
				var hi := a.max(b).max(c)
				for x in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
					for y in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
						for z in range(floori(lo.z / CELL), floori(hi.z / CELL) + 1):
							var key := Vector3i(x, y, z)
							if not grid.has(key):
								grid[key] = PackedInt32Array()
							grid[key].append(k)

	func at(p: Vector3) -> float:
		var seen := {}
		var total := 0.0
		var r := ceili(R / CELL)
		var c0 := Vector3i(floori(p.x / CELL), floori(p.y / CELL), floori(p.z / CELL))
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				for z in range(-r, r + 1):
					var key := c0 + Vector3i(x, y, z)
					if not grid.has(key):
						continue
					for k in grid[key]:
						if seen.has(k):
							continue
						seen[k] = true
						var t: Array = tris[k]
						var a: Vector3 = t[0] - p
						var b: Vector3 = t[1] - p
						var c: Vector3 = t[2] - p
						var la := a.length()
						var lb := b.length()
						var lc := c.length()
						var num := a.dot(b.cross(c))
						var den := la * lb * lc + a.dot(b) * lc + b.dot(c) * la + c.dot(a) * lb
						total += 2.0 * atan2(num, den)
		return total / (4.0 * PI)


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
