class_name NavBake
extends RefCounted
## Floor outlines and obstruction outlines in, a navigation mesh out: convex
## polygons over shared vertices, eroded by a person's half-width. Godot's own
## 2D baker does the boolean work and the convex partition; this file only
## snaps and orders what it returns, so two runs write the same bytes.
##
## The result is plain data: {"vertices": PackedVector2Array, "polygons":
## Array[PackedInt32Array]}. A 2D point (x, y) is the 3D point (x, h, y), and
## the polygons keep their winding under that mapping (`to_navigation_mesh`).

## Millimetres, the precision every BrickWild export writes at.
const PLACES := 0.001
## The baker's own vertex grid. Finer than a centimetre buys nothing a walker
## can feel and slows the clipping.
const CELL := 0.01
## How far every floor outline is grown before the union.
const WELD := 0.01


static func bake(floor: Array[PackedVector2Array], obstacles: Array[PackedVector2Array],
		radius: float) -> Dictionary:
	var source := NavigationMeshSourceGeometryData2D.new()
	# The baker unions outlines by the non-zero rule, so two overlapping
	# outlines wound opposite ways cancel and leave a seam. One winding for all.
	# Floors laid edge to edge meet at a hairline, not a shared edge; a
	# centimetre of weld makes them one floor before the union.
	for poly in floor:
		if poly.size() < 3:
			continue
		for welded in Geometry2D.offset_polygon(_wound(poly), WELD):
			if not Geometry2D.is_polygon_clockwise(welded):
				source.add_traversable_outline(_wound(welded))
	for poly in obstacles:
		if poly.size() >= 3:
			source.add_obstruction_outline(_wound(poly))
	var nav := NavigationPolygon.new()
	nav.agent_radius = radius
	nav.cell_size = CELL
	NavigationServer2D.bake_from_source_geometry_data(nav, source)
	var polygons: Array[PackedInt32Array] = []
	for i in nav.get_polygon_count():
		polygons.append(nav.get_polygon(i))
	return canonical(nav.get_vertices(), polygons)


## Snap every vertex, merge the ones that snap together, number them in
## (x, y) order, start each polygon at its lowest index without changing its
## winding, and sort the polygons. The baker's own order is an implementation
## detail; this one is a promise.
static func canonical(vertices: PackedVector2Array, polygons: Array[PackedInt32Array]) -> Dictionary:
	var snapped := PackedVector2Array()
	for v in vertices:
		snapped.append(Vector2(snappedf(v.x, PLACES), snappedf(v.y, PLACES)))
	var order: Array = range(snapped.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return snapped[a].x < snapped[b].x or (snapped[a].x == snapped[b].x and snapped[a].y < snapped[b].y))
	var remap := PackedInt32Array()
	remap.resize(snapped.size())
	var out_vertices := PackedVector2Array()
	for i in order:
		if out_vertices.is_empty() or out_vertices[out_vertices.size() - 1] != snapped[i]:
			out_vertices.append(snapped[i])
		remap[i] = out_vertices.size() - 1
	var out_polygons: Array[PackedInt32Array] = []
	for poly in polygons:
		var mapped := PackedInt32Array()
		for k in poly:
			var j: int = remap[k]
			if mapped.is_empty() or mapped[mapped.size() - 1] != j:
				mapped.append(j)
		if mapped.size() >= 2 and mapped[0] == mapped[mapped.size() - 1]:
			mapped.remove_at(mapped.size() - 1)
		if mapped.size() < 3:
			continue
		var start: int = 0
		for k in range(1, mapped.size()):
			if mapped[k] < mapped[start]:
				start = k
		var rotated := PackedInt32Array()
		for k in mapped.size():
			rotated.append(mapped[(start + k) % mapped.size()])
		out_polygons.append(rotated)
	out_polygons.sort_custom(func(a: PackedInt32Array, b: PackedInt32Array) -> bool:
		for k in mini(a.size(), b.size()):
			if a[k] != b[k]:
				return a[k] < b[k]
		return a.size() < b.size())
	return {"vertices": out_vertices, "polygons": out_polygons}


## The polygon a point stands in, or -1.
static func polygon_at(mesh: Dictionary, p: Vector2) -> int:
	var vertices: PackedVector2Array = mesh["vertices"]
	var polygons: Array[PackedInt32Array] = mesh["polygons"]
	for i in polygons.size():
		if Geometry2D.is_point_in_polygon(p, _points(vertices, polygons[i])):
			return i
	return -1


## The nearest point of the mesh to `p`: `p` itself when it is on the mesh.
static func closest_point(mesh: Dictionary, p: Vector2) -> Vector2:
	if polygon_at(mesh, p) >= 0:
		return p
	var vertices: PackedVector2Array = mesh["vertices"]
	var best := Vector2.INF
	for poly in mesh["polygons"]:
		for k in poly.size():
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(p,
				vertices[poly[k]], vertices[poly[(k + 1) % poly.size()]])
			if best == Vector2.INF or p.distance_squared_to(q) < p.distance_squared_to(best):
				best = q
	return best


## Each polygon's island: polygons that share an edge are one island.
static func islands(mesh: Dictionary) -> PackedInt32Array:
	var polygons: Array[PackedInt32Array] = mesh["polygons"]
	var parent: Array[int] = []
	for i in polygons.size():
		parent.append(i)
	var edges := {}
	for i in polygons.size():
		var poly: PackedInt32Array = polygons[i]
		for k in poly.size():
			var a: int = poly[k]
			var b: int = poly[(k + 1) % poly.size()]
			var key := Vector2i(mini(a, b), maxi(a, b))
			if edges.has(key):
				_union(parent, i, edges[key])
			else:
				edges[key] = i
	var out := PackedInt32Array()
	for i in polygons.size():
		out.append(_find(parent, i))
	return out


static func area(mesh: Dictionary) -> float:
	var total := 0.0
	for poly in mesh["polygons"]:
		total += Poly.area(_points(mesh["vertices"], poly))
	return total


## A Godot NavigationMesh at height `y`, in the same frame as the 2D data.
static func to_navigation_mesh(mesh: Dictionary, y := 0.0, cell := 0.25) -> NavigationMesh:
	var out := NavigationMesh.new()
	out.cell_size = cell
	var v3 := PackedVector3Array()
	for v in mesh["vertices"]:
		v3.append(Vector3(v.x, y, v.y))
	out.vertices = v3
	for poly in mesh["polygons"]:
		out.add_polygon(poly)
	return out


static func points_of(mesh: Dictionary, polygon: int) -> PackedVector2Array:
	return _points(mesh["vertices"], mesh["polygons"][polygon])


static func _wound(poly: PackedVector2Array) -> PackedVector2Array:
	if not Geometry2D.is_polygon_clockwise(poly):
		return poly
	var out := poly.duplicate()
	out.reverse()
	return out


static func _points(vertices: PackedVector2Array, poly: PackedInt32Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in poly:
		out.append(vertices[k])
	return out


static func _find(parent: Array[int], i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _union(parent: Array[int], a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[maxi(ra, rb)] = mini(ra, rb)
