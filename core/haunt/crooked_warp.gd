class_name CrookedWarp
extends RefCounted
## HNT-040: the crooked warp. A building made deliberately janky -- every
## storey leans its own way and the walls kink at the floor lines, the way a
## Caligari set or a Seuss house does. `BuildingRequest.jank` (0..1) asks for
## it; zero is the building exactly as built, not one vertex moved.
##
## The map is a piecewise SHEAR. Between two floor lines a point moves
## sideways by an amount linear in its height; at a floor line the two
## storeys either side agree. Everything this file promises follows from that:
##
##   * a point's height never changes, so floors stay level and the planner,
##     the furnisher and the walking checks need not know the house is crooked;
##   * the map is continuous and one-to-one, so a closed shell stays closed,
##     an attached part stays attached, and two things that did not touch
##     still do not -- a wardrobe cannot be pushed through a leaning wall,
##     because the wardrobe leans with it;
##   * its determinant is 1 everywhere, so no face is ever turned inside out;
##   * inside one storey the map is exactly affine, so a triangle that lies in
##     one storey stays a flat triangle, and a loaded prop -- which cannot be
##     re-meshed -- gets the same affine as the walls round it.
##
## Triangles that cross a floor line are cut along it first. That cut is the
## kink. Every vertex is then moved by the exact map, so two triangles that
## shared a corner still share it.

## The steepest any storey may lean. A crooked chimney looks old; a wall at
## thirty degrees looks broken.
const MAX_LEAN_DEG := 12.0
## Floor-line spacing for a family that has no storeys of its own (a castle,
## a church, a temple, a mill): about one tall storey.
const GENERIC_STOREY := 4.5
## How many floor lines a family without storeys gets: enough for the tallest
## spire, harmless above the top of a low one.
const GENERIC_KEYS := 16
## A vertex this close to a floor line counts as ON it. Deciding that per
## vertex, not per triangle, means two triangles sharing an edge always agree
## on whether the edge is cut, so a cut never leaves a crack.
const ON_LINE := 0.01
## A prop's origin sits on its floor; this nudge puts it in the storey above
## the line rather than the one below.
const PROP_LIFT := 0.01

## Floor lines, ascending. Nothing below keys[0] moves.
var keys: Array[float] = []
## shears[i]: horizontal metres moved per metre of rise, from keys[i] up to
## keys[i + 1]. The last runs on above the last key (the roof).
var shears: Array[Vector2] = []
## The offset already accumulated at keys[i].
var _base: Array[Vector2] = []


## The warp a building asked for, or null when it asked for none (jank 0) or
## its kind cannot be warped as one piece (a village is many buildings).
static func for_building(building) -> CrookedWarp:
	if building == null or building.request == null:
		return null
	var request: BuildingRequest = building.request
	if request.jank <= 0.0 or not supports(request.kind):
		return null
	return make(floor_lines(building), request.jank,
		hash("crooked|%s|%d" % [String(request.kind), request.seed]))


## A village is a street of buildings, not one: shearing it as a block would
## lean the road. Its own buildings can be crooked one by one, later.
static func supports(kind: StringName) -> bool:
	return kind != &"village"


## Where the kinks go. A plan family has real floors, at storey * height, and
## the warp must kink exactly there or a table would straddle two storeys.
## Every other family gets evenly spaced lines from its requested height,
## so the same request always gives the same lines -- the mesh and the scene,
## built separately, are warped identically.
static func floor_lines(building) -> Array[float]:
	var out: Array[float] = []
	var plan = building.get("plan")
	if plan is HousePlan:
		var spec = plan.spec
		var h: float = float(spec.height)
		for s in range(int(spec.storeys) + 1):
			out.append(h * s)
		return out
	var height: float = maxf(building.request.height, 1.0)
	var n: int = maxi(1, roundi(height / GENERIC_STOREY))
	var step: float = height / n
	for i in range(GENERIC_KEYS):
		out.append(step * i)
	return out


## A warp with these floor lines, at this jank, from this seed. The lean
## heads one way and mostly flips at each floor, with a little wander, so the
## building zigzags rather than toppling. The roof leans hardest.
static func make(p_keys: Array[float], jank: float, p_seed: int) -> CrookedWarp:
	var w := CrookedWarp.new()
	var r := RandomNumberGenerator.new()
	r.seed = p_seed
	var cap: float = tan(deg_to_rad(MAX_LEAN_DEG)) * clampf(jank, 0.0, 1.0)
	var heading: float = r.randf() * TAU
	var lean := 1.0
	for i in range(p_keys.size()):
		var magnitude: float = cap * r.randf_range(0.45, 1.0)
		if i == p_keys.size() - 1:
			magnitude = cap
		var dir: float = heading + r.randf_range(-0.45, 0.45)
		w.shears.append(Vector2(cos(dir), sin(dir)) * magnitude * lean)
		if r.randf() < 0.7:
			lean = -lean
	w.keys = p_keys
	w._rebase()
	return w


func _rebase() -> void:
	_base.clear()
	var o := Vector2.ZERO
	for i in range(keys.size()):
		_base.append(o)
		if i + 1 < keys.size():
			o += shears[i] * (keys[i + 1] - keys[i])


# ------------------------------------------------------------------ the map

## Which storey of the warp a height is in: -1 below the first line.
func slab_of(y: float) -> int:
	if keys.is_empty() or y < keys[0]:
		return -1
	var i := 0
	while i + 1 < keys.size() and y >= keys[i + 1]:
		i += 1
	return i


## How far a point at this height moves, sideways.
func offset_at(y: float) -> Vector2:
	var i := slab_of(y)
	if i < 0:
		return Vector2.ZERO
	return _base[i] + shears[i] * (y - keys[i])


## The map itself.
func point(p: Vector3) -> Vector3:
	var o := offset_at(p.y)
	return Vector3(p.x + o.x, p.y, p.z + o.y)


## The exact affine of one storey: point(p) == affine(slab_of(p.y)) * p.
func affine(slab: int) -> Transform3D:
	if slab < 0:
		return Transform3D.IDENTITY
	var s: Vector2 = shears[slab]
	var basis := Basis(Vector3(1.0, 0.0, 0.0), Vector3(s.x, 1.0, s.y), Vector3(0.0, 0.0, 1.0))
	var o: Vector2 = _base[slab] - s * keys[slab]
	return Transform3D(basis, Vector3(o.x, 0.0, o.y))


## The steepest lean of any storey, in degrees. Never above MAX_LEAN_DEG.
func max_lean_deg() -> float:
	var worst := 0.0
	for s in shears:
		worst = maxf(worst, rad_to_deg(atan(s.length())))
	return worst


# ------------------------------------------------------------------ meshes

## A warped copy of a mesh. `xf` places the mesh in the building's own space
## (a shell is usually at the root, so identity); the result is back in the
## mesh's local space. Surface materials and names are kept, and so is the
## surface count, so slot-named materials still land on the right surface.
func warp_mesh(mesh: ArrayMesh, xf := Transform3D.IDENTITY) -> ArrayMesh:
	var out := ArrayMesh.new()
	if mesh == null:
		return out
	var inv := xf.affine_inverse()
	for si in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(si)
		var prim: int = mesh.surface_get_primitive_type(si)
		var warped: Array = _warp_triangles(arrays, xf, inv) \
			if prim == Mesh.PRIMITIVE_TRIANGLES else _warp_points(arrays, xf, inv)
		out.add_surface_from_arrays(prim, warped)
		var k := out.get_surface_count() - 1
		out.surface_set_material(k, mesh.surface_get_material(si))
		out.surface_set_name(k, mesh.surface_get_name(si))
	return out


## Lines and points: no faces to cut, every vertex moved by the map.
func _warp_points(arrays: Array, xf: Transform3D, inv: Transform3D) -> Array:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(v.size()):
		v[i] = inv * point(xf * v[i])
	arrays[Mesh.ARRAY_VERTEX] = v
	return arrays


func _warp_triangles(arrays: Array, xf: Transform3D, inv: Transform3D) -> Array:
	var src := _Attrs.read(arrays)
	var dst := _Attrs.like(src)
	var rows: Array = []   # one vertex as [pos(root), nrm(root), tangent, colour, uv, uv2]
	var nxf := xf.basis.inverse().transposed()
	var ninv := inv.basis.inverse().transposed()
	for t in range(src.count / 3):
		var tri: Array = []
		for c in range(3):
			tri.append(src.row(src.index(t * 3 + c), xf, nxf))
		for piece in _cut_at_floor_lines(tri):
			_emit(dst, piece, inv, ninv)
	return dst.write(arrays)


## The triangle as one or more convex pieces, each inside one storey. Most
## triangles cross no line and come back as they went in.
func _cut_at_floor_lines(tri: Array) -> Array:
	var lo: float = minf(tri[0][0].y, minf(tri[1][0].y, tri[2][0].y))
	var hi: float = maxf(tri[0][0].y, maxf(tri[1][0].y, tri[2][0].y))
	var pieces: Array = []
	var rest: Array = tri
	for k in keys:
		if k <= lo + ON_LINE:
			continue
		if k >= hi - ON_LINE:
			break
		var halves: Array = _split(rest, k)
		if halves[0].size() >= 3:
			pieces.append(halves[0])
		rest = halves[1]
		if rest.size() < 3:
			return pieces
	pieces.append(rest)
	return pieces


## Sutherland-Hodgman against the plane y = k, both sides at once. A vertex
## within ON_LINE of the plane belongs to both sides and is never cut; an
## edge is cut only where its ends are clearly on opposite sides.
static func _split(poly: Array, k: float) -> Array:
	var below: Array = []
	var above: Array = []
	var n := poly.size()
	for i in range(n):
		var a: Array = poly[i]
		var b: Array = poly[(i + 1) % n]
		var da: float = a[0].y - k
		var db: float = b[0].y - k
		var sa := 0 if absf(da) <= ON_LINE else (1 if da > 0.0 else -1)
		var sb := 0 if absf(db) <= ON_LINE else (1 if db > 0.0 else -1)
		if sa <= 0:
			below.append(a)
		if sa >= 0:
			above.append(a)
		if sa * sb < 0:
			var m: Array = _lerp_row(a, b, da / (da - db))
			below.append(m)
			above.append(m)
	return [below, above]


static func _lerp_row(a: Array, b: Array, t: float) -> Array:
	var out: Array = []
	for i in range(a.size()):
		if not _has(a[i]):
			out.append(null)
		elif i == 1:
			out.append((a[i] as Vector3).lerp(b[i], t).normalized())
		else:
			out.append(lerp(a[i], b[i], t))
	return out


static func _has(value: Variant) -> bool:
	return typeof(value) != TYPE_NIL


## One convex piece, fanned into triangles in its own winding. Positions go
## through the exact map; normals and tangents through the piece's storey.
func _emit(dst: _Attrs, piece: Array, inv: Transform3D, ninv: Basis) -> void:
	var cy := 0.0
	for row in piece:
		cy += row[0].y
	var m := affine(slab_of(cy / piece.size()))
	var nm := m.basis.inverse().transposed()
	for i in range(1, piece.size() - 1):
		for row in [piece[0], piece[i], piece[i + 1]]:
			dst.push(row, inv * point(row[0]),
				(ninv * (nm * (row[1] as Vector3))).normalized() if _has(row[1]) else null,
				inv.basis * (m.basis * Vector3(row[2].x, row[2].y, row[2].z)) if _has(row[2]) else null)


# ------------------------------------------------------------------ scenes

## Warp an assembled building in place: generated meshes vertex by vertex,
## loaded props and lights as whole pieces by the affine of the storey they
## stand in. Call it before collision is made, so the collision leans too.
func warp_scene(root: Node3D) -> void:
	for child in root.get_children():
		if child is Node3D:
			_warp_node(child, Transform3D.IDENTITY)


func _warp_node(node: Node3D, parent_xf: Transform3D) -> void:
	var world: Transform3D = parent_xf * node.transform
	var back: Transform3D = parent_xf.affine_inverse()
	if node.scene_file_path != "":
		# a loaded model cannot be re-meshed: it leans as a whole with its storey
		var m := affine(slab_of(world.origin.y + PROP_LIFT))
		node.transform = back * (m * world)
		return
	if node is MeshInstance3D and node.mesh is ArrayMesh and node.mesh.resource_path == "":
		node.mesh = warp_mesh(node.mesh, world)
	elif node.get_child_count() == 0:
		# a light or a marker: it goes where its point goes
		node.transform = back * Transform3D(world.basis, point(world.origin))
		return
	for child in node.get_children():
		if child is Node3D:
			_warp_node(child, world)


## The vertex attributes the warp carries, read from and written back to a
## surface's arrays. Positions and normals are held in the building's space.
class _Attrs:
	var count := 0
	var v := PackedVector3Array()
	var n = null        # PackedVector3Array or null
	var tg = null       # PackedFloat32Array (4 per vertex) or null
	var c = null        # PackedColorArray or null
	var uv = null       # PackedVector2Array or null
	var uv2 = null      # PackedVector2Array or null
	var idx = null      # PackedInt32Array or null

	static func read(arrays: Array) -> _Attrs:
		var a := _Attrs.new()
		a.v = arrays[Mesh.ARRAY_VERTEX]
		a.n = arrays[Mesh.ARRAY_NORMAL]
		a.tg = arrays[Mesh.ARRAY_TANGENT]
		a.c = arrays[Mesh.ARRAY_COLOR]
		a.uv = arrays[Mesh.ARRAY_TEX_UV]
		a.uv2 = arrays[Mesh.ARRAY_TEX_UV2]
		a.idx = arrays[Mesh.ARRAY_INDEX]
		a.count = a.idx.size() if _has(a.idx) else a.v.size()
		return a

	## Empty arrays of the same kinds; the output is never indexed.
	static func like(src: _Attrs) -> _Attrs:
		var a := _Attrs.new()
		a.n = PackedVector3Array() if _has(src.n) else null
		a.tg = PackedFloat32Array() if _has(src.tg) else null
		a.c = PackedColorArray() if _has(src.c) else null
		a.uv = PackedVector2Array() if _has(src.uv) else null
		a.uv2 = PackedVector2Array() if _has(src.uv2) else null
		return a

	func index(i: int) -> int:
		return idx[i] if _has(idx) else i

	## One vertex: [pos, nrm, tangent(Vector4), colour, uv, uv2], with position,
	## normal and tangent direction taken into the building's space.
	func row(i: int, xf: Transform3D, nxf: Basis) -> Array:
		var tangent = null
		if _has(tg):
			var t3: Vector3 = xf.basis * Vector3(tg[i * 4], tg[i * 4 + 1], tg[i * 4 + 2])
			tangent = Vector4(t3.x, t3.y, t3.z, tg[i * 4 + 3])
		return [xf * v[i],
			(nxf * n[i]).normalized() if _has(n) else null,
			tangent,
			c[i] if _has(c) else null,
			uv[i] if _has(uv) else null,
			uv2[i] if _has(uv2) else null]

	func push(row: Array, pos: Vector3, nrm, tangent) -> void:
		v.append(pos)
		count += 1
		if _has(n):
			n.append(nrm)
		if _has(tg):
			var t: Vector3 = (tangent as Vector3).normalized()
			tg.append_array(PackedFloat32Array([t.x, t.y, t.z, row[2].w]))
		if _has(c):
			c.append(row[3])
		if _has(uv):
			uv.append(row[4])
		if _has(uv2):
			uv2.append(row[5])

	static func _has(value: Variant) -> bool:
		return typeof(value) != TYPE_NIL

	func write(_arrays: Array) -> Array:
		var out: Array = []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = v
		out[Mesh.ARRAY_NORMAL] = n
		out[Mesh.ARRAY_TANGENT] = tg
		out[Mesh.ARRAY_COLOR] = c
		out[Mesh.ARRAY_TEX_UV] = uv
		out[Mesh.ARRAY_TEX_UV2] = uv2
		return out
