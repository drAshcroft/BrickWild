class_name TreeShapes
extends RefCounted
## The primitives every tree style is drawn with: a tapered tube, a faceted
## ellipsoid, a tapered shard, a flat disc, and a greedy voxel mesher.
##
## They live here rather than in `MeshKit` for one reason: `MeshKit` is oriented
## at masonry -- boxes, slabs, revolves, arc ribbons -- and every one of its
## emitters assumes a building. These assume a plant, and folding them into the
## shared kit would put a crown-blob next to a church wall forever.
##
## `MeshKit` is still underneath: this owns one and writes into its surfaces, so
## the surface contract, the handedness rule and `commit()` are the ones the
## whole project already obeys.
##
## Handedness: Godot's front faces are CLOCKWISE, so a triangle wound (a,b,c)
## has outward normal `(c - a).cross(b - a)`. Every solid below builds a basis
## p, q with `p.cross(q) == n` and winds (a, d, c) / (a, c, b), which is the
## ordering that yields n. Getting it backwards is invisible from outside and
## obvious from inside, which is why it is written down once, here.

var kit: MeshKit


func _init(surface_count := TreeGeometry.SURFACE_COUNT) -> void:
	kit = MeshKit.new(surface_count)


func commit() -> ArrayMesh:
	# No generate_normals(), for the reason MeshKit.commit() gives: one smooth
	# group would span the whole tree and average a trunk against a leaf.
	return kit.commit()


# ------------------------------------------------------------------- solids

## A tapered n-gon prism from `from` (radius r0) to `to` (radius r1). The only
## honest way to draw a branch: a box is a stick with corners, and a 32-gon is
## a tube with too many triangles.
func tube(from: Vector3, to: Vector3, r0: float, r1: float, surf: int,
		sides: int, caps := true) -> void:
	var axis: Vector3 = to - from
	var len: float = axis.length()
	if len < 1e-4 or r0 <= 0.0 and r1 <= 0.0:
		return
	var n: Vector3 = axis / len
	var p: Vector3 = _perp(n)
	var q: Vector3 = n.cross(p).normalized()
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	for i in range(sides):
		var a: float = TAU * float(i) / float(sides)
		var off: Vector3 = p * cos(a) + q * sin(a)
		ring0.append(from + off * r0)
		ring1.append(to + off * r1)
	for i in range(sides):
		var j: int = (i + 1) % sides
		_face(ring0[i], ring0[j], ring1[j], ring1[i], surf)
	if caps:
		_cap(ring1, n, surf)
		_cap(ring0, -n, surf)


## A faceted ellipsoid, flat-shaded. `rings`/`segs` are deliberately low: a
## 12-segment lobe is a lobe, a 48-segment lobe is a sphere and reads as one.
## `rings = 1` gives a bipyramid -- the classic chunky leaf clump.
##
## The latitude rows sit BETWEEN the poles, never on them, and the two poles
## are single points that get a fan. The obvious arrangement -- `rings + 1`
## rows from -PI/2 to +PI/2 -- puts every vertex of the top and bottom row at
## the same place, so the end quads have two coincident corners, `_face`
## computes a zero normal and bails, and the blob comes out with its crown
## open. That is invisible from outside and shows as a hole the moment you
## orbit anything, and at `rings = 1` it emits nothing at all.
func ellipsoid(centre: Vector3, radius: Vector3, surf: int, rings := 4, segs := 8,
		rot := 0.0) -> void:
	if radius.x <= 0.0 or radius.y <= 0.0 or radius.z <= 0.0:
		return
	var bands: int = maxi(1, rings)
	var grid: Array = []
	for j in range(bands):
		var v: float = -PI * 0.5 + PI * (float(j) + 0.5) / float(bands)
		var cy: float = sin(v)
		var cr: float = cos(v)
		var row: Array[Vector3] = []
		for i in range(segs):
			var u: float = TAU * float(i) / float(segs) + rot
			row.append(centre + Vector3(cos(u) * cr * radius.x,
				cy * radius.y, sin(u) * cr * radius.z))
		grid.append(row)
	var south: Vector3 = centre - Vector3(0.0, radius.y, 0.0)
	var north: Vector3 = centre + Vector3(0.0, radius.y, 0.0)
	for i in range(segs):
		var i2: int = (i + 1) % segs
		_tri(south, grid[0][i2], grid[0][i], surf)
	for j in range(bands - 1):
		for i in range(segs):
			var i2: int = (i + 1) % segs
			_face(grid[j][i], grid[j][i2], grid[j + 1][i2], grid[j + 1][i], surf)
	var top: Array = grid[bands - 1]
	for i in range(segs):
		var i2: int = (i + 1) % segs
		_tri(top[i], top[i2], north, surf)


## A prism that comes to a point rather than a flat cap: a crystal shard, a
## thorn, a stalactite. With `r1` at or near zero the tip ring collapses to a
## point and fans, which is the only way this makes a closed spike -- emitted
## as quads against a zero-radius ring, every side face has two coincident
## corners and the whole shard collapses to its base cap.
func shard(base: Vector3, tip: Vector3, r0: float, r1: float, surf: int,
		sides := 5, rot := 0.0) -> void:
	var axis: Vector3 = tip - base
	var len: float = axis.length()
	if len < 1e-4 or r0 <= 0.0:
		return
	var n: Vector3 = axis / len
	var p: Vector3 = _perp(n)
	var q: Vector3 = n.cross(p).normalized()
	var ring0: Array[Vector3] = []
	for i in range(sides):
		var a: float = TAU * float(i) / float(sides) + rot
		ring0.append(base + (p * cos(a) + q * sin(a)) * r0)
	if r1 <= 1e-5:
		for i in range(sides):
			_tri(ring0[i], ring0[(i + 1) % sides], tip, surf)
		_cap(ring0, -n, surf)
		return
	var ring1: Array[Vector3] = []
	for i in range(sides):
		var a: float = TAU * float(i) / float(sides) + rot
		ring1.append(tip + (p * cos(a) + q * sin(a)) * r1)
	for i in range(sides):
		var j: int = (i + 1) % sides
		_face(ring0[i], ring0[j], ring1[j], ring1[i], surf)
	_cap(ring1, n, surf)
	_cap(ring0, -n, surf)


## A flat disc: a leaf plate, a rune circle, a lily pad.
func disc(centre: Vector3, radius: float, surf: int, segs := 10,
		normal := Vector3.UP) -> void:
	var n: Vector3 = normal.normalized()
	var p: Vector3 = _perp(n)
	var q: Vector3 = n.cross(p).normalized()
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		_tri(centre + (p * cos(a0) + q * sin(a0)) * radius,
			centre + (p * cos(a1) + q * sin(a1)) * radius, centre, surf)


# --------------------------------------------------------------------- voxel

## The "no cell here" sentinel for the voxel mesher. -1, and never 0, because
## `TreeGeometry.SURF_BARK` is 0.
const EMPTY := -1

## Greedy-mesh a solid voxel set.
##
## `cells` maps a `Vector3i` to a surface index: `SURF_BARK`, `SURF_LEAF` or
## `SURF_ACCENT`. A face is emitted where a solid cell meets air or meets a
## DIFFERENT material, and coplanar runs of the same material are then merged
## into single quads.
## The merge is the point, but not the whole of it, and the honest figure is
## worth stating because the obvious one is a lie. A 20 m voxel oak is around
## 9,000 cells, and unmerged those would be 54,000 faces with roughly half of
## them interior ones you can see straight through. Greedy merging does NOT
## turn that into a few hundred quads: measured across the six voxel species at
## three seeds each, it lands between 0.41 and 0.73 of the unmerged count. The
## reason is structural -- on a curved surface every row of a slice has a
## different extent, so a run never extends downward and most merges are runs
## of one. A solid ball of the same envelope only reaches 0.41.
##
## So the mesher is honest work, not a triumph, and `tests/suites/tree_suite.gd`
## holds it to a floor that a curved surface can actually reach rather than to
## the number that sounds good. Returns {"cells", "raw", "emitted", "merged"},
## where `emitted` counts quads after merging and `merged` counts the cell
## faces they replaced, so a caller can see what the pass earned.
##
## `EMPTY` is -1, deliberately NOT 0. `TreeGeometry.SURF_BARK` is 0, and an
## "absent cell means 0" convention makes every bark cell indistinguishable
## from an empty one: the trunk silently vanishes and you are left with a crown
## floating in the air, which is exactly what happened before this was fixed.
func voxel(cells: Dictionary, spec: TreeSpec, uv_scale := 0.0) -> Dictionary:
	var raw := 0
	for c in cells.keys():
		raw += _open_faces(cells, c as Vector3i)
	var faces := {"cells": cells.size(), "raw": raw, "emitted": 0}
	if cells.is_empty():
		faces["merged"] = 0
		return faces
	var s: float = uv_scale if uv_scale > 0.0 else spec.block
	# The bounding box and the occupied slices, both walked ONCE. Every slice
	# bounds its mask by these rather than re-deriving them, and a slice with
	# no cells in it is skipped outright: a 22 m spruce is 150 cells tall and 60
	# wide, so nine tenths of the slices a bounding box would sweep are air, and
	# testing each with a dictionary scan is worse than meshing them.
	var extents: Array = []
	var occupied: Array = []
	for axis in range(3):
		extents.append(_min_along(cells, axis))
	extents.append(0)
	extents.append(0)
	extents.append(0)
	for axis in range(3):
		extents[axis * 2 + 1] = _max_along(cells, axis)
	var live: Array = [{}, {}, {}]
	for c in cells:
		var cc: Vector3i = c
		for axis in range(3):
			live[axis][cc[axis]] = true
	for axis in range(3):
		occupied.append(live[axis])
	for axis in range(3):
		for sign in [1, -1]:
			var lo: int = int(extents[axis * 2])
			var hi: int = int(extents[axis * 2 + 1])
			for slice in range(lo, hi + 1):
				if not (occupied[axis] as Dictionary).has(slice):
					continue
				_greedy_slice(cells, spec, s, axis, sign, slice, faces, extents)
	faces["merged"] = maxi(0, raw - faces["emitted"])
	return faces




func _open_faces(cells: Dictionary, c: Vector3i) -> int:
	var mat: int = int(cells.get(c, EMPTY))
	if mat < 0:
		return 0
	var n := 0
	for axis in range(3):
		for sign in [1, -1]:
			var nb: Vector3i = c
			nb[axis] += sign
			if int(cells.get(nb, EMPTY)) != mat:
				n += 1
	return n


## One slice of the greedy pass.
##
## The mask is bounded to the cells that actually exist ON THIS SLICE, not to
## the tree's global extent. The obvious version allocated the full u-by-v
## rectangle for every slice of every axis, which for a 22 m voxel spruce is
## 6 x 150 slices over a 60-by-60 rectangle -- 3.2 million `Array[int]`
## allocations to mesh a few thousand cells, and a single 6 m tree took five
## seconds to build. Two orders of magnitude for no output.
##
## `_extents` is computed once per call and walks the cell dictionary once.
func _greedy_slice(cells: Dictionary, spec: TreeSpec, uv_scale: float,
		axis: int, sign: int, slice: int, faces: Dictionary,
		extents: Array) -> void:
	var u: int = (axis + 1) % 3
	var v: int = (axis + 2) % 3
	var u_lo: int = int(extents[u * 2])
	var u_hi: int = int(extents[u * 2 + 1])
	var v_lo: int = int(extents[v * 2])
	var v_hi: int = int(extents[v * 2 + 1])
	if u_hi < u_lo or v_hi < v_lo:
		return
	# mask[row][col] = the surface to draw there, or EMPTY for nothing.
	var mask: Array = []
	for dv in range(v_lo, v_hi + 1):
		var row: Array[int] = []
		row.resize(u_hi - u_lo + 1)
		row.fill(EMPTY)
		for du in range(u_lo, u_hi + 1):
			var c := Vector3i.ZERO
			c[axis] = slice
			c[u] = du
			c[v] = dv
			var mat: int = int(cells.get(c, EMPTY))
			if mat < 0:
				continue
			var nb: Vector3i = c
			nb[axis] += sign
			if int(cells.get(nb, EMPTY)) == mat:
				continue   # the neighbour is the same material: this is interior
			row[du - u_lo] = mat
		mask.append(row)
	# Greedy: from each uncovered cell run right while the material matches,
	# then run down while every cell of that run matches. One quad for the lot.
	for r in range(mask.size()):
		var c0: int = 0
		while c0 < mask[r].size():
			var mat: int = mask[r][c0]
			if mat < 0:
				c0 += 1
				continue
			var run: int = 1
			while c0 + run < mask[r].size() and mask[r][c0 + run] == mat:
				run += 1
			var down: int = 1
			while r + down < mask.size():
				var same := true
				for k in range(run):
					if mask[r + down][c0 + k] != mat:
						same = false
						break
				if not same:
					break
				down += 1
			for rr in range(down):
				for k in range(run):
					mask[r + rr][c0 + k] = EMPTY
			_voxel_quad(spec, uv_scale, axis, sign, slice, c0 + u_lo,
				r + v_lo, run, down, mat)
			faces["emitted"] += 1
			c0 += run


## One merged quad, wound so its normal points along `sign` on `axis`, with
## world-projected UVs so a bark or course shader tiles at the right size.
func _voxel_quad(spec: TreeSpec, uv_scale: float, axis: int, sign: int, slice: int,
		u0: int, v0: int, du: int, dv: int, surf: int) -> void:
	var origin: Vector3 = TreeGeometry.voxel_origin(spec)
	var b: float = spec.block
	var u: int = (axis + 1) % 3
	var v: int = (axis + 2) % 3
	# The face sits on the boundary between this cell and its neighbour along
	# `axis` -- the outer face of the cell, not its centre.
	var plane: float = origin[axis] + (float(slice) + (1.0 if sign > 0 else 0.0)) * b
	var corner := func(du_off: int, dv_off: int) -> Vector3:
		var p := Vector3.ZERO
		p[axis] = plane
		p[u] = origin[u] + float(u0 + du_off) * b
		p[v] = origin[v] + float(v0 + dv_off) * b
		return p
	var a: Vector3 = corner.call(0, 0)
	var bb: Vector3 = corner.call(du, 0)
	var c: Vector3 = corner.call(du, dv)
	var d: Vector3 = corner.call(0, dv)
	# (u) x (v) == (axis) for a right-handed triple, so this winding faces +axis
	# and the mirrored one faces -axis. The two orderings are spelled out rather
	# than reached by permuting the corners: permuting them and recomputing n
	# from the permuted corners silently turned a -axis face back into a
	# +axis one, and half the voxels in a tree faced the wrong way.
	var n := Vector3.ZERO
	n[axis] = float(sign)
	var st := kit.surface(surf)
	var inv: float = 1.0 / maxf(uv_scale, 0.001)
	var order: Array = [a, d, c, a, c, bb] if sign > 0 else [a, c, d, a, bb, c]
	for vtx in order:
		_vert(st, vtx, n, Vector2(vtx[u] * inv, vtx[v] * inv))




# ------------------------------------------------------------------ internals

## Any unit vector perpendicular to n, chosen so the result is stable for a
## given n -- a branch that twists as it is drawn shimmers.
static func _perp(n: Vector3) -> Vector3:
	var ref: Vector3 = Vector3.UP if absf(n.dot(Vector3.UP)) < 0.94 else Vector3.RIGHT
	return ref.cross(n).normalized()


## A quad a-b-c-d, wound so the triangles' OWN winding gives the declared
## normal.
##
## This was backwards, and the mistake is worth writing down. The declared
## normal `(c - a).cross(d - a)` is correct for a quad with `b = a + p`,
## `d = a + q` and `p.cross(q) == n` -- so computing n that way is right. But
## emitting the triangles as (a,b,c) and (a,c,d) winds them so that Godot
## computes `(c - a).cross(b - a)`, which is `(p + q).cross(p)` = `q.cross(p)`
## = -n. The geometry rendered, the shading was inverted, and the only
## symptom was that 40% of a trunk's faces pointed inward -- invisible from
## outside a solid and caught by `TreeCheck.FACING`, which is exactly what that
## rule is for. (a,d,c) and (a,c,b) are the orderings that agree with n.
func _face(a: Vector3, b: Vector3, c: Vector3, d: Vector3, surf: int) -> void:
	var n: Vector3 = (c - a).cross(d - a)
	if n.length_squared() < 1e-12:
		return   # two corners coincided: a sliver, not a face
	n = n.normalized()
	var st := kit.surface(surf)
	_vert(st, a, n, Vector2(a.x, a.z))
	_vert(st, d, n, Vector2(d.x, d.z))
	_vert(st, c, n, Vector2(c.x, c.z))
	_vert(st, a, n, Vector2(a.x, a.z))
	_vert(st, c, n, Vector2(c.x, c.z))
	_vert(st, b, n, Vector2(b.x, b.z))


func _tri(a: Vector3, b: Vector3, c: Vector3, surf: int) -> void:
	var n: Vector3 = (c - a).cross(b - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var st := kit.surface(surf)
	_vert(st, a, n, Vector2(a.x, a.z))
	_vert(st, b, n, Vector2(b.x, b.z))
	_vert(st, c, n, Vector2(c.x, c.z))


## A cap over `ring`, facing `n`.
##
## The order is (centre, ring[i+1], ring[i]) and not the natural
## (centre, ring[i], ring[i+1]). For a ring that runs counter-clockwise about
## +Z, the natural order DECLARES (c-a).cross(b-a) as -Z: a cap facing the way
## it was asked to face, wound the other way round. Swapping the two ring
## vertices flips the declared normal and the winding together, so they still
## agree with each other -- which is the part that matters -- and both now
## agree with `n` as well. Two of a six-sided tube's six faces were inside out
## because of this, and the FACING rule read 60% rather than 100%.
func _cap(ring: Array[Vector3], n: Vector3, surf: int) -> void:
	if ring.size() < 3:
		return
	var centre: Vector3 = Vector3.ZERO
	for v in ring:
		centre += v
	centre /= float(ring.size())
	# The winding decides which way the cap faces, and BOTH caps of a tube use
	# the same ring order. Reversed, the cap at `to` faces along +n -- correct --
	# and the cap at `from` faces along +n too -- which for the far end of a
	# branch is straight into the wood. A short five-sided root is half caps, so
	# a quarter of all bark triangles were inside out and FACING read 64%.
	# Flipping the order for the near cap is the whole fix.
	for i in range(ring.size()):
		var j: int = (i + 1) % ring.size()
		var b: Vector3 = ring[i]
		var c: Vector3 = ring[j]
		# Ask the winding what it is actually going to declare, and reverse the
		# two ring vertices if that is the wrong way round. Computing it beats
		# assuming it: a cap's facing is decided by the order of the ring, the
		# two ends of a tube share one order, and only one of them can be right.
		if (c - centre).cross(b - centre).dot(n) < 0.0:
			var t: Vector3 = b
			b = c
			c = t
		_tri(centre, b, c, surf)


func _vert(st: SurfaceTool, v: Vector3, n: Vector3, uv: Vector2) -> void:
	st.set_normal(n)
	st.set_uv(uv)
	st.add_vertex(v)


## A stable per-cell value in 0..1, so the same cell jitters the same way on
## every rebuild. A jitter that moved between builds would fail an idempotence
## check for a reason nobody could see in the picture.
static func cell_hash(c: Vector3i, salt := 0) -> float:
	var h: int = c.x * 73856093 ^ c.y * 19349663 ^ c.z * 83492791 ^ salt * 2654435761
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(absi(h) % 10000) / 10000.0


func _min_along(cells: Dictionary, axis: int) -> int:
	var lo: int = 1 << 20
	for c in cells:
		lo = mini(lo, (c as Vector3i)[axis])
	return lo


func _max_along(cells: Dictionary, axis: int) -> int:
	var hi: int = -(1 << 20)
	for c in cells:
		hi = maxi(hi, (c as Vector3i)[axis])
	return hi


## A per-axis scale of a COMMITTED mesh, returned as a new one.
##
## `ArrayMesh` has no `surface_set_arrays` -- the arrays can be read with
## `surface_get_arrays` but not written back -- so a committed mesh is rebuilt
## surface by surface, exactly the way `MeshKit.translated()` does it. Both
## `TreeBuilder._fit_envelope` and `TreeMagic._scaled_y` needed this and neither
## could have found it alone, which is what a shared primitive is for.
##
## Normals are directions and are not scaled; only the translation and the
## positions move. Surface names and materials are carried over so the
## assembler's `material_slot:` resolution still works.
static func scaled(mesh: ArrayMesh, k: Vector3) -> ArrayMesh:
	var out := ArrayMesh.new()
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface).duplicate(true)
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in range(vs.size()):
			vs[i] = Vector3(vs[i].x * k.x, vs[i].y * k.y, vs[i].z * k.z)
		arrays[Mesh.ARRAY_VERTEX] = vs
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(surface), arrays)
		out.surface_set_material(surface, mesh.surface_get_material(surface))
		out.surface_set_name(surface, mesh.surface_get_name(surface))
	return out


## How far past its envelope a drawing may sit before the fit touches it. Half
## a per cent: enough to swallow a float epsilon and a quantisation step, far
## too little to let a real overshoot through.
const FIT_EPSILON := 0.005


## THE ENVELOPE IS A POST-CONDITION OF A BUILDER, not a prediction of the
## generator.
##
## `TreeBuilder` and `TreeMagic` each emit their own geometry -- the magic six
## commit their own mesh -- so this lives on `TreeShapes` and both call it. A fit
## held in one builder and not the other is a fit that applies to three
## quarters of the family, which is how the crystal's trunk was still 1 m past
## its promise after the other three styles had been fitted.
##
## `spec.canopy_radius` and `spec.trunk_clear` are promises the QA rules hold
## the mesh to, and for four months of iteration the way they were kept was for
## the generator to PREDICT what each emitter would draw. It cannot: a voxel
## cell's face sits half a block past the lobe that filled it, a tube is wider
## than the segment's nominal radius, a palm's leaf fill runs a cell long, a
## crystal shard cluster grows past the lobe it hangs on. Every one of those
## was a CLEARANCE or FITTED failure on geometry that looked right.
##
## So the prediction is replaced by a correction. After the mesh exists, it is
## squeezed vertically to the promised height and, if it reaches further from
## the trunk axis than `canopy_radius` allows, pulled in horizontally about that
## axis. Both are uniform, so a tree that was the right shape stays the right
## shape -- a squeeze of two per cent is invisible and a failure is not.
##
## The alternative is a suite that fires on correct geometry, which is worse
## than no suite at all: it is a check that has stopped measuring anything.
static func fit_envelope(mesh: ArrayMesh, spec: TreeSpec) -> ArrayMesh:
	var lo: float = INF
	var hi: float = -INF
	var reach: float = 0.0
	var at_waist: float = 0.0
	for surface in range(mesh.get_surface_count()):
		var vs: PackedVector3Array = \
			mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for v in vs:
			lo = minf(lo, v.y)
			hi = maxf(hi, v.y)
			var r: float = Vector2(v.x, v.z).length()
			reach = maxf(reach, r)
			if v.y <= TreeGeometry.TRUNK_HEIGHT:
				at_waist = maxf(at_waist, r)
	# Bottom: a floating tree hangs, and its underside is the island's.
	var lift: float = 0.0
	if not TreeGeometry.is_rooted(spec):
		var floor_y: float = TreeGeometry.ground_clearance(spec)
		if lo < floor_y:
			lift = floor_y - lo
			mesh = MeshKit.translated(mesh, Vector3(0.0, lift, 0.0))
			hi += lift
	# Top.
	var ky: float = 1.0
	# The tolerance is the WHOLE fix, and without it this is catastrophic: the
	# mesh reaches the promised height to within a float epsilon -- `_refit_crown`
	# puts it there -- so `hi > spec.height` is true by 1e-7, the correction
	# fires, and every tree in the family is squeezed to 8% of its height. A
	# correction that runs on a rounding error is worse than no correction.
	if hi > spec.height * (1.0 + FIT_EPSILON) and hi > 1e-3:
		# To the height, ALLOWED the same overhang the sides are allowed --
		# (1.0 + allowance), not the allowance. Written as the bare
		# allowance this aimed the crown at EIGHT PER CENT of the promised
		# height and every tree in the family came out a bonsai.
		ky = (spec.height * (1.0 + TreeGeometry.DRAW_ALLOWANCE)) / hi
	# Sides. The allowance is a fraction of the crown, and the crown is what
	# the allowance exists for.
	# The two bands are SEPARATE promises, so they are corrected separately. The
	# crown's radius and the trunk's are not one number: a tree can have a crown
	# half again as wide as its trunk-clearance promise and still be honest,
	# and scaling the whole mesh by the crown's overshoot drags a trunk that was
	# within its own promise out of it. A birch whose branches reach a metre at
	# head height and whose crown is nine is the case in point.
	var kx: float = 1.0
	var lim: float = spec.canopy_radius * (1.0 + TreeGeometry.DRAW_ALLOWANCE)
	if reach > lim * (1.0 + FIT_EPSILON) and reach > 1e-3:
		kx = lim / reach
	var waist_lim: float = spec.trunk_clear * (1.0 + TreeGeometry.DRAW_ALLOWANCE)
	if at_waist > waist_lim * (1.0 + FIT_EPSILON) and at_waist > 1e-3:
		kx = minf(kx, waist_lim / at_waist)
	if absf(kx - 1.0) < 1e-5 and absf(ky - 1.0) < 1e-5 and absf(lift) < 1e-4:
		return mesh
	return scaled(mesh, Vector3(kx, ky, kx))
