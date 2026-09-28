class_name TreeBuilder
extends RefCounted
## Emits the non-magical tree styles: voxel, indie and natural. The six
## supernaturals belong to `TreeMagic`, which `build()` hands the spec to and
## which returns its own committed mesh.
##
## This class is a PURE FUNCTION of a `TreeSpec`, and that is the whole point
## of the family's three-part split. `TreeGenerator` decides; `TreeGeometry`
## owns the maths and is the single source of truth; this only draws. It reads
## the trunk off `TreeGeometry.stem_points(spec)` rather than laying out a line
## of its own, it draws the crown from `spec.lobes` rather than inventing
## blobs, and it never rolls a die -- no `randf`, no `randi`, no `Time`. Two
## calls with one spec therefore produce byte-identical vertex arrays, which
## is what lets the QA suite say a part MOVED instead of merely vanishing. A
## builder that re-rolled while emitting would blind the checks to precisely
## the cases that forced the roll.
##
## The three styles are three ALGORITHMS, not three palettes on one shape,
## because a reskin of one tree four times is not a tree family:
##
##   voxel    a cubic grid. Bark and leaves are CELL MATERIALS, greedy-meshed
##            together into a few hundred quads -- which is the whole point of
##            the merge. The foliage is then given a per-cell value jitter,
##            because the mesher writes no vertex colour and an untextured
##            green block is the single cheapest tell there is.
##   indie    faceted low-poly. A 6-sided tapered stem, golden-angle forks,
##            5-sided tips, chunky ellipsoid clumps that are individually
##            rotated so no two line up. It has to read at 60 px and at 6 m,
##            which means the facets are the point and are never smoothed --
##            `MeshKit.commit()` does not call `generate_normals()` for
##            exactly this reason.
##   natural  an L-system-ish skeleton with real taper and layered crown
##            SHELLS, three or four concentric ellipsoids per lobe rather
##            than one ball, so the crown has depth and tonal range instead of
##            being a single shaded ellipsoid.
##
## Handedness and the surface contract are `TreeShapes`' to keep, not this
## class's: every primitive sets its own per-face normal, and Godot's front
## faces are clockwise, so a triangle wound (a, b, c) has outward normal
## `(c - a).cross(b - a)`.
##
## ---- the two logs, and why there are two ----
##
## `voxel_log` is a COMPOSITING check and exists only because a greedy
## mesher will happily hang a leaf block in mid-air: the mesher does not know
## what supports what, and a voxel tree's foliage is a pile of cubes rather
## than a solid. One row per stamped cell records what is under it.
##
## `supported` answers "is this cell attached to the tree, or is it hanging in
## the air", and it is answered by a flood fill over face-adjacent solids
## rather than per cell, because a voxel crown hangs off a branch network no
## single column can see: measured over the voxel species, a per-cell rule
## alone marks 0% of a broadleaf's leaves as carried, which is not a check.
## A solid is anchored if any cell in its component rests on the ground or on
## bark, and every cell of that component is supported -- so a leaf block is
## loose exactly when its whole clump has nothing under any of it. Every row
## carries the index of the lobe that stamped it, so a clump of loose leaves
## can be traced back to the lobe that made it.
##
## Only LEAF rows are part of the contract; a bark row is structure, and a
## twig at the end of a branch is not a compositing defect.
##
## `part_log` is the other project's QA log: one row per named part, carrying
## the role, an index and the box it occupies, so a check can say a branch
## MOVED rather than that the count went down.

var shapes: TreeShapes
## Every voxel the stamper placed, for the compositing check:
##   {"cell": Vector3i, "surf": int, "under": Vector3i, "lobe": int,
##    "supported": bool}
## `lobe` is the index into `spec.lobes` that stamped the cell, or -1 for
## bark. A bark row is always `supported`: structure carries itself.
var voxel_log: Array[Dictionary] = []
## Every named part, in the project's part_log shape:
##   {"role": StringName, "n": int, "host": StringName, "aabb": AABB}
## A stable `<role>#<n>` id is the caller's job; the log carries role, host
## and box so a part can be said to have MOVED rather than vanished.
var part_log: Array[Dictionary] = []
## The greedy mesher's own count, straight from `TreeShapes.voxel()`.
var voxel_stats: Dictionary = {}

# ---- the three styles' constants. Named, because a silhouette decided by a
# ---- literal buried in a loop is a silhouette nobody can change deliberately.
const BARK_SIDES := 6          ## indie: the trunk and its primary forks
const TIP_SIDES := 5           ## indie: the twigs
const NATURAL_SIDES := 7       ## natural: stem and primary branches
const NATURAL_TIP_SIDES := 6   ## natural: the secondaries
const CLUMP_RINGS := 2         ## indie crown clumps
const CLUMP_SEGS := 7
const SHELL_RINGS := 3         ## natural crown shells
const SHELL_SEGS := 9
## Peak-to-peak value jitter on the voxel leaf surface, as a fraction of
## white. 0.28 is +/-14%: enough that neighbouring blocks are visibly
## different leaves, small enough that the crown still reads as one crown.
const LEAF_JITTER := 0.28
## Hash salts. Distinct integers so the stem wobble, the root spread and the
## clump rotation do not all pull the same number out of the same cell.
const BARK_SALT := 7
const ROOT_SALT := 19
const CROWN_SALT := 41
const ROOT_MIN := 3
const ROOT_MAX := 4


## The one entry point. Resets every buffer first, so a second call on the
## same builder accumulates nothing, then dispatches on style and commits.
func build(spec: TreeSpec) -> ArrayMesh:
	shapes = TreeShapes.new()
	voxel_log.clear()
	part_log.clear()
	voxel_stats = {}
	if spec.style == &"magic":
		# The six are a different SHAPE each, not a tint of this one, so they
		# are a different class. It commits its own mesh, and runs the same
		# envelope post-condition at the end -- see `_fit_envelope`.
		return TreeMagic.build(spec)
	match spec.style:
		&"voxel":
			_build_voxel(spec)
		&"indie":
			_build_indie(spec)
		_:
			_build_natural(spec)
	return TreeShapes.fit_envelope(shapes.commit(), spec)





# ======================================================================= voxel
## A Minecraft tree: one dictionary of cells, greedy-meshed leaves, and a bark
## solid emitted cell by cell.
##
## Stamping order IS the material precedence, because it is written as the
## order of the passes: stem and branches first, then the crown, and a crown
## cell is only stamped where nothing is stamped already. Bark therefore wins
## a contested cell, and it wins it by being stamped first rather than by a
## second rule that could disagree with the first.
##
## Nothing here reads `spec.grid`: the bounds are derived from what was
## actually stamped, and the grid edge is `spec.block`, which is the only
## number the voxel geometry really needs. Every cell is placed with
## `TreeGeometry.voxel_cell` and tested with `TreeGeometry.voxel_centre`, so
## a voxel tree lands ON the grid rather than near it.
func _build_voxel(spec: TreeSpec) -> void:
	var cells: Dictionary = {}
	var cell_lobe: Dictionary = {}
	var stem: Array[Dictionary] = TreeGeometry.stem_points(spec)
	var stem_min: Vector3 = stem[0]["pos"] - Vector3.ONE * float(stem[0]["r"])
	var stem_max: Vector3 = stem[0]["pos"] + Vector3.ONE * float(stem[0]["r"])
	for i in range(stem.size() - 1):
		var a: Vector3 = stem[i]["pos"]
		var b: Vector3 = stem[i + 1]["pos"]
		_voxel_stamp(spec, cells, a, float(stem[i]["r"]), b, float(stem[i + 1]["r"]))
		stem_min = Vector3(minf(stem_min.x, a.x - float(stem[i]["r"])),
			minf(stem_min.y, a.y - float(stem[i]["r"])),
			minf(stem_min.z, a.z - float(stem[i]["r"])))
		stem_max = Vector3(maxf(stem_max.x, b.x + float(stem[i + 1]["r"])),
			maxf(stem_max.y, b.y + float(stem[i + 1]["r"])),
			maxf(stem_max.z, b.z + float(stem[i + 1]["r"])))
	_log_part(&"trunk", 0, &"trunk", AABB(stem_min, stem_max - stem_min).abs())

	for i in range(spec.branches.size()):
		var br: Dictionary = spec.branches[i]
		var a: Vector3 = br["from"]
		var z: Vector3 = br["to"]
		_voxel_stamp(spec, cells, a, float(br["r0"]), z, float(br["r1"]))
		_log_part(&"branch", i, &"trunk", _seg_aabb(a, z, maxf(float(br["r0"]), float(br["r1"]))))

	var roots: Array[Dictionary] = _roots(spec)
	for i in range(roots.size()):
		var rt: Dictionary = roots[i]
		_voxel_stamp(spec, cells, rt["from"], float(rt["r0"]), rt["to"], float(rt["r1"]))
		_log_part(&"root", i, &"trunk", _seg_aabb(rt["from"], rt["to"], float(rt["r0"])))

	_voxel_leaf_pass(spec, cells, cell_lobe)
	for i in range(spec.lobes.size()):
		_log_part(&"crown", i, &"crown", _lobe_aabb(spec.lobes[i]))

	voxel_stats = shapes.voxel(cells, spec)
	_tint_voxel_leaves(spec)
	# bark is meshed by TreeShapes.voxel() with the rest of the cells
	_log_voxels(cells, cell_lobe)


## Fill every cell a tapered tube passes through, sampling along the axis at
## well under a block so a fast-moving segment cannot step over a cell, then
## testing each candidate cell CENTRE against the swept radius. The radius is
## never allowed below half a block: a twig a third of a block across still
## claims the cell its axis passes through, which is what rasterising a
## sub-block tube honestly means, and without it the skeleton dissolves
## wherever the maths got small.
func _voxel_stamp(spec: TreeSpec, cells: Dictionary, a: Vector3, ra: float,
		b: Vector3, rb: float) -> void:
	var bs: float = maxf(spec.block, 0.01)
	var steps: int = maxi(2, int(ceil((b - a).length() / (bs * 0.4))))
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector3 = a.lerp(b, t)
		var r: float = maxf(lerpf(ra, rb, t), bs * 0.5)
		var lo: Vector3i = TreeGeometry.voxel_cell(spec, p - Vector3.ONE * r)
		var hi: Vector3i = TreeGeometry.voxel_cell(spec, p + Vector3.ONE * r)
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				for z in range(lo.z, hi.z + 1):
					var c := Vector3i(x, y, z)
					if _seg_dist(TreeGeometry.voxel_centre(spec, c), a, b) <= r:
						cells[c] = TreeGeometry.SURF_BARK


## Mark every cell whose CENTRE falls inside a lobe, skipping anything already
## stamped so the bark under a crown stays bark. A leafless tree skips the
## pass entirely: a dead tree has a skeleton and no foliage, and that is a
## flag on the spec rather than a colour with zero alpha.
func _voxel_leaf_pass(spec: TreeSpec, cells: Dictionary, cell_lobe: Dictionary) -> void:
	if spec.leafless:
		return
	for i in range(spec.lobes.size()):
		var lobe: Dictionary = spec.lobes[i]
		var pos: Vector3 = lobe["pos"]
		var rad: float = float(lobe["radius"])
		var squash: float = maxf(float(lobe.get("squash", 1.0)), 0.05)
		# `in_lobe` divides the vertical offset by squash and then tests the
		# length against the radius, so a lobe's true half-height is radius
		# TIMES squash, not divided by it. The bounding box has to use the
		# same number or the top of every lobe is never visited -- and this
		# is also what makes an acacia (squash 0.42) flat and a poplar
		# (1.85) tall without anyone asking it to.
		var ext: Vector3 = Vector3(rad, rad * squash, rad)
		var lo: Vector3i = TreeGeometry.voxel_cell(spec, pos - ext)
		var hi: Vector3i = TreeGeometry.voxel_cell(spec, pos + ext)
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				for z in range(lo.z, hi.z + 1):
					var c := Vector3i(x, y, z)
					if cells.has(c):
						continue   # bark was stamped first, and bark wins
					if TreeGeometry.in_lobe(lobe, TreeGeometry.voxel_centre(spec, c)):
						cells[c] = TreeGeometry.SURF_LEAF
						cell_lobe[c] = i

## Nothing. The bark solid is meshed by `TreeShapes.voxel()` along with
## everything else, which is where it belongs.
##
## It was not, once. `TreeGeometry.SURF_BARK` is 0 and `TreeShapes.voxel()`
## used 0 as its EMPTY sentinel, so every bark cell was indistinguishable from
## an empty one and a voxel tree meshed as a crown floating over nothing --
## hence this function, which emitted one box per visible bark cell and left
## the dictionary's bark to the log and the support rule.
##
## `TreeShapes.EMPTY` is -1 now, so the collision cannot happen and the boxes
## would be drawn a SECOND time on top of the mesher's. That is not a slow
## path, it is a wrong one: two coincident shells with two different
## tessellations, and a doubled triangle count for a tree nobody could
## afford anyway. The stamping rules are the documented ones -- bark as
## `SURF_BARK`, leaves as `SURF_LEAF` -- and they work.

## `TreeShapes.voxel()` writes no per-vertex colour, so a voxel crown comes
## out one flat green. It is the cheapest tell in the whole renderer -- a
## plastic blob of leaf blocks -- and the fix is a per-CELL value jitter from
## `TreeShapes.cell_hash`, which is stable, so the same block jitters the same
## way on every rebuild and an idempotence check never fails for a reason
## nobody could see in the picture.
##
## The write-back has to read the geometry back, because a greedy quad spans
## many cells and the per-vertex stream carries no cell id. The surface is
## committed to a throwaway mesh, the triangles are taken in the order the
## mesher emitted them, and each vertex is nudged a third of the way toward
## its own triangle's centroid before being binned: a quad corner sits on a
## cell boundary, and a point ON a boundary belongs to no cell, so the nudge
## is what makes the binning a fact rather than a rounding accident.
func _tint_voxel_leaves(spec: TreeSpec) -> void:
	var st: SurfaceTool = shapes.kit.surface(TreeGeometry.SURF_LEAF)
	var probe := ArrayMesh.new()
	st.commit(probe)
	if probe.get_surface_count() == 0:
		return
	var arrays: Array = probe.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var order := PackedInt32Array()
	# SurfaceTool commits unindexed triangles, so ARRAY_INDEX is usually absent
	# and reads back as null -- assigning that to a typed PackedInt32Array is a
	# hard error, not a warning. Ask for it defensively and fall back to the
	# vertex order, which is the emission order for an unindexed stream.
	var idx_var: Variant = arrays[Mesh.ARRAY_INDEX]
	var idx: PackedInt32Array = PackedInt32Array() if idx_var == null else idx_var
	if idx.is_empty():
		for i in range(verts.size()):
			order.append(i)
	else:
		order = idx
	st.clear()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in range(0, order.size(), 3):
		var last: int = mini(t + 2, order.size() - 1)
		var centre: Vector3 = (verts[order[t]] + verts[order[t + 1]] + verts[order[last]]) / 3.0
		for k in range(t, mini(t + 3, order.size())):
			var vi: int = order[k]
			var cell: Vector3i = TreeGeometry.voxel_cell(spec, verts[vi].lerp(centre, 0.35))
			var j: float = (TreeShapes.cell_hash(cell) - 0.5) * LEAF_JITTER
			# Value plus a hair of hue: leaves differ in more than their
			# brightness, and a pure value ramp still reads as plastic.
			st.set_normal(norms[vi] if vi < norms.size() else Vector3.UP)
			st.set_uv(uvs[vi] if vi < uvs.size() else Vector2.ZERO)
			st.set_color(Color(1.0 + j * 0.88, 1.0 + j, 1.0 + j * 1.18))
			st.add_vertex(verts[vi])
	for i in order:
		st.add_index(i)


func _log_voxels(cells: Dictionary, cell_lobe: Dictionary) -> void:
	var anchored: Dictionary = _anchored(cells)
	for key in cells.keys():
		var cell: Vector3i = key
		voxel_log.append({
			"cell": cell, "surf": int(cells[cell]),
			"under": Vector3(cell.x, cell.y - 1, cell.z),
			"lobe": int(cell_lobe.get(cell, -1)),
			"supported": bool(anchored.get(cell, false))
				or int(cells[cell]) != TreeGeometry.SURF_LEAF})


## Which cells are attached to the ground, as opposed to hanging in the air?
##
## The question a greedy mesher cannot answer and a compositing check has to,
## so it is answered here, once, from the stamped set. It is a flood fill
## rather than a per-cell rule because a voxel crown hangs off a branch
## network that no single column can see: measured over the voxel species, a
## per-cell rule -- "bark, accent or ground directly beneath" -- marks 0% of
## a broadleaf's leaves as carried, because a clump of leaves sitting on a
## branch has leaves under it, not bark, and the check would either be
## useless or have to lie.
##
## So: a solid is ANCHORED if any cell in its face-connected component rests
## on the ground or on bark, and every cell in that component is supported.
## A leaf block is loose exactly when it belongs to a component with nothing
## under any of it -- a clump hanging in mid-air, which is the defect this
## log exists to catch. It is not a vacuous test: a crown stamped with no
## trunk and no branches under it comes out 100% loose, which is what it
## should.
##
## A bark row is always `supported`. Structure carries itself, and a twig at
## the end of a branch is not a compositing defect.
func _anchored(cells: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in cells.keys():
		var start: Vector3i = key
		if out.has(start):
			continue
		# Breadth-first over face-adjacent solids. The entry is written as a
		# visited marker before the walk and overwritten with the component's
		# verdict after it, so the outer loop can skip the whole component
		# and no separate seen-set is needed.
		var comp: Array[Vector3i] = [start]
		out[start] = false
		var at: int = 0
		var anch: bool = false
		while at < comp.size():
			var c: Vector3i = comp[at]
			at += 1
			if _rests(cells, c):
				anch = true
			for axis in range(3):
				for sign in [1, -1]:
					var nb: Vector3i = c
					nb[axis] += sign
					if not cells.has(nb) or out.has(nb):
						continue
					out[nb] = false
					comp.append(nb)
		for c in comp:
			out[c] = anch
	return out


## Does this cell rest on something? The ground layer counts -- a root that
## stops a centimetre short is still a tree standing on the earth -- and so
## does bark or accent directly beneath, because that is the stem holding the
## crown up. A leaf cell beneath is not: leaves are held by the branch
## network, which is what the flood fill is for.
static func _rests(cells: Dictionary, c: Vector3i) -> bool:
	if c.y <= 0:
		return true
	var below := Vector3i(c.x, c.y - 1, c.z)
	return cells.has(below) and int(cells[below]) != TreeGeometry.SURF_LEAF


# ======================================================================== indie
## Faceted low-poly. Everything about this style is a decision to keep the
## facets: a 6-sided stem rather than a cylinder, 2 rings and 7 segments on a
## clump rather than a sphere, and every clump given its own rotation so a
## crown of a dozen of them is not a dozen of the same lump. Smoothing any of
## it costs more than the whole style is worth.
func _build_indie(spec: TreeSpec) -> void:
	var stem: Array[Dictionary] = TreeGeometry.stem_points(spec)
	# A slight per-node radius wobble, and it is per NODE rather than per
	# segment, so the stem stays continuous and the wobble reads as a trunk
	# that grew rather than as a stack of prisms.
	var wob: Array[float] = []
	for i in range(stem.size()):
		wob.append(1.0 + (_hash01(Vector3i(i, 0, 0), BARK_SALT) - 0.5) * 0.26)
	var stem_min: Vector3 = stem[0]["pos"] - Vector3.ONE * float(stem[0]["r"])
	var stem_max: Vector3 = stem[0]["pos"] + Vector3.ONE * float(stem[0]["r"])
	for i in range(stem.size() - 1):
		var a: Vector3 = stem[i]["pos"]
		var b: Vector3 = stem[i + 1]["pos"]
		shapes.tube(a, b, float(stem[i]["r"]) * wob[i],
			float(stem[i + 1]["r"]) * wob[i + 1], TreeGeometry.SURF_BARK, BARK_SIDES)
		stem_min = Vector3(minf(stem_min.x, a.x), minf(stem_min.y, a.y), minf(stem_min.z, a.z))
		stem_max = Vector3(maxf(stem_max.x, b.x), maxf(stem_max.y, b.y), maxf(stem_max.z, b.z))
	_log_part(&"trunk", 0, &"trunk", AABB(stem_min, stem_max - stem_min).abs())

	for i in range(spec.branches.size()):
		var br: Dictionary = spec.branches[i]
		var a: Vector3 = br["from"]
		var b: Vector3 = br["to"]
		var sides: int = BARK_SIDES if int(br["level"]) == 0 else TIP_SIDES
		shapes.tube(a, b, float(br["r0"]), float(br["r1"]), TreeGeometry.SURF_BARK, sides)
		_log_part(&"branch", i, &"trunk", _seg_aabb(a, b, float(br["r0"])))

	_draw_roots(spec, BARK_SIDES)
	_indie_crown(spec)


## A crown is a ball of CLUMPS, never one ball. Each lobe contributes a main
## clump at the generator's own position and size, plus two satellites thrown
## out of it by hashed angles, which is what stops a broadleaf reading as an
## ellipsoid with facets. The satellites sit on the ACCENT surface: a
## two-value foliage is the tonal range the flat-albedo renders are always
## short of, and a crown lit from one side in one colour is a balloon.
func _indie_crown(spec: TreeSpec) -> void:
	if spec.leafless:
		return
	for i in range(spec.lobes.size()):
		var lobe: Dictionary = spec.lobes[i]
		var pos: Vector3 = lobe["pos"]
		var rad: float = float(lobe["radius"])
		var half: float = _lobe_half(lobe, rad)
		var h: float = _hash01(Vector3i(i, 3, 5), CROWN_SALT)
		var rot: float = h * TAU
		if StringName(lobe.get("kind", &"crown")) == &"skirt":
			# A conifer is a stack of skirts, and a skirt is WIDE AND FLAT
			# whatever squash the generator wrote: see _lobe_half.
			shapes.ellipsoid(pos, Vector3(rad, half, rad), TreeGeometry.SURF_LEAF,
				CLUMP_RINGS, CLUMP_SEGS, rot)
			var h2: float = _hash01(Vector3i(i, 5, 7), CROWN_SALT + 1)
			shapes.ellipsoid(pos + Vector3(0.0, rad * 0.42, 0.0),
				Vector3(rad * 0.68, half * 0.8, rad * 0.68), TreeGeometry.SURF_ACCENT,
				CLUMP_RINGS, CLUMP_SEGS, rot + h2 * 1.7)
		else:
			shapes.ellipsoid(pos, Vector3(rad, half, rad), TreeGeometry.SURF_LEAF,
				CLUMP_RINGS, CLUMP_SEGS, rot)
			for k in 2:
				var hk: float = _hash01(Vector3i(i * 4 + k, 1, 9), CROWN_SALT + k)
				var ang: float = TAU * hk + h * 2.0
				var reach: float = rad * lerpf(0.44, 0.68, hk)
				var off := Vector3(cos(ang) * reach, (hk - 0.5) * half * 0.7,
					sin(ang) * reach)
				var r2: float = rad * lerpf(0.52, 0.72, hk)
				shapes.ellipsoid(pos + off, Vector3(r2, half * 0.78, r2),
					TreeGeometry.SURF_ACCENT, CLUMP_RINGS, CLUMP_SEGS, ang)
		_log_part(&"crown", i, &"crown", _lobe_aabb(lobe))


# ====================================================================== natural
## A real skeleton and a crown with depth. Two things are done here that the
## other styles do not do: the taper along a branch is sampled from
## `TreeGeometry.branch_radius_at` so a long limb visibly thins along its run
## instead of stepping once at the tip, and a lobe is drawn as three or four
## CONCENTRIC SHELLS -- the outer at full radius, the inner ones smaller,
## lifted and rotated off it -- which is what stops a crown from being one
## ellipsoid with a single shaded surface.
func _build_natural(spec: TreeSpec) -> void:
	var stem: Array[Dictionary] = TreeGeometry.stem_points(spec)
	var stem_min: Vector3 = stem[0]["pos"] - Vector3.ONE * float(stem[0]["r"])
	var stem_max: Vector3 = stem[0]["pos"] + Vector3.ONE * float(stem[0]["r"])
	for i in range(stem.size() - 1):
		var a: Vector3 = stem[i]["pos"]
		var b: Vector3 = stem[i + 1]["pos"]
		shapes.tube(a, b, float(stem[i]["r"]), float(stem[i + 1]["r"]),
			TreeGeometry.SURF_BARK, NATURAL_SIDES)
		stem_min = Vector3(minf(stem_min.x, a.x), minf(stem_min.y, a.y), minf(stem_min.z, a.z))
		stem_max = Vector3(maxf(stem_max.x, b.x), maxf(stem_max.y, b.y), maxf(stem_max.z, b.z))
	_log_part(&"trunk", 0, &"trunk", AABB(stem_min, stem_max - stem_min).abs())

	for i in range(spec.branches.size()):
		var br: Dictionary = spec.branches[i]
		var a: Vector3 = br["from"]
		var b: Vector3 = br["to"]
		var r0: float = float(br["r0"])
		var r1: float = float(br["r1"])
		var mid: Vector3 = a.lerp(b, 0.5)
		var sides: int = NATURAL_SIDES if int(br["level"]) == 0 else NATURAL_TIP_SIDES
		# Two spans, so branch_radius_at is sampled at three points and the
		# limb has a visible thinning rather than a shoulder.
		shapes.tube(a, mid, TreeGeometry.branch_radius_at(r0, r1, 0.0),
			TreeGeometry.branch_radius_at(r0, r1, 0.5), TreeGeometry.SURF_BARK, sides)
		shapes.tube(mid, b, TreeGeometry.branch_radius_at(r0, r1, 0.5),
			TreeGeometry.branch_radius_at(r0, r1, 1.0), TreeGeometry.SURF_BARK, sides)
		_log_part(&"branch", i, &"trunk", _seg_aabb(a, b, r0))

	_draw_roots(spec, NATURAL_SIDES)
	_natural_crown(spec)


## Three or four shells per lobe, nested. The outermost two carry the leaf
## colour and the inner ones the accent, so light finding the gaps between the
## shells finds a second tone: the difference between a crown that has depth
## and a crown that is a ball of green plastic. A skirt lobe gets three flat
## ones and a crown lobe four rounded ones, for the same reason a conifer and
## an oak cannot share a silhouette.
func _natural_crown(spec: TreeSpec) -> void:
	if spec.leafless:
		return
	for i in range(spec.lobes.size()):
		var lobe: Dictionary = spec.lobes[i]
		var pos: Vector3 = lobe["pos"]
		var rad: float = float(lobe["radius"])
		var half: float = _lobe_half(lobe, rad)
		var skirt: bool = StringName(lobe.get("kind", &"crown")) == &"skirt"
		var scales: Array = [1.0, 0.72, 0.48] if skirt else [1.0, 0.78, 0.58, 0.40]
		for k in scales.size():
			var s: float = scales[k]
			var hk: float = _hash01(Vector3i(i * 7 + k, 11, 3), CROWN_SALT + k)
			var h2: float = _hash01(Vector3i(i * 7 + k, 13, 2), CROWN_SALT + k + 5)
			var off := Vector3((hk - 0.5) * rad * 0.44 * (1.0 - s),
				half * 0.30 * (1.0 - s) + half * 0.10 * s,
				(h2 - 0.5) * rad * 0.44 * (1.0 - s))
			var surf: int = TreeGeometry.SURF_LEAF if k < 2 else TreeGeometry.SURF_ACCENT
			shapes.ellipsoid(pos + off, Vector3(rad * s, half * s, rad * s), surf,
				SHELL_RINGS, SHELL_SEGS, hk * TAU)
		_log_part(&"crown", i, &"crown", _lobe_aabb(lobe))


# ======================================================================= roots
## The root flare, for every style that has one.
##
## `TreeGeometry.stem_points` folds `root_flare` into its FIRST node, so the
## widened base is already in the data -- but a wide cylinder on its own is a
## pole with a hat on. What a tree needs is to MEET the earth, and the way it
## does that is with roots: three or four short stubs splayed off the base
## node, each buried at its far end so there is no gap for daylight to get
## through. The voxel style stamps them as bark cells, the other two draw them
## as tubes off the same frames, so all three agree on where the roots are.
##
## Whether there are roots at all is asked of the GEOMETRY rather than of the
## species name: a tree whose ground clearance is above zero does not touch the
## ground, and that is exactly the `floating` case, whatever style it arrived
## as.
func _roots(spec: TreeSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if TreeGeometry.ground_clearance(spec) > 0.0:
		return out
	var stem: Array[Dictionary] = TreeGeometry.stem_points(spec)
	if stem.is_empty():
		return out
	var base: Vector3 = stem[0]["pos"]
	var r0: float = float(stem[0]["r"])
	var n: int = clampi(ROOT_MIN + int(_hash01(Vector3i.ZERO, ROOT_SALT) * 2.0),
		ROOT_MIN, ROOT_MAX)
	for i in range(n):
		var h: float = _hash01(Vector3i(i, 2, 4), ROOT_SALT)
		var h2: float = _hash01(Vector3i(i, 6, 8), ROOT_SALT + 1)
		# Golden angle, nudged by a hash, so the roots are never evenly
		# spaced -- an even spacing of anything reads as manufactured.
		var az: float = TreeGeometry.phyllotaxis(i) + (h - 0.5) * 0.6
		var dir := Vector3(cos(az), -0.34, sin(az)).normalized()
		var tip: Vector3 = base + dir * (r0 * lerpf(2.0, 3.0, h2))
		tip.y = minf(tip.y, -r0 * 0.2)   # buried, so the tree meets the earth
		out.append({"from": base, "to": tip, "r0": r0 * 0.62, "r1": r0 * 0.16,
			"az": az})
	return out


## The roots as tubes, plus a squashed collar at the base node. The collar is
## the flare read from the side: four tapering stubs on a cylinder still look
## like a mast with sticks glued to it, and a low ellipsoid under the base
## node is what makes the mass sit in the ground instead of on it.
func _draw_roots(spec: TreeSpec, sides: int) -> void:
	var stem: Array[Dictionary] = TreeGeometry.stem_points(spec)
	if stem.is_empty():
		return
	var roots: Array[Dictionary] = _roots(spec)
	for i in range(roots.size()):
		var rt: Dictionary = roots[i]
		shapes.tube(rt["from"], rt["to"], float(rt["r0"]), float(rt["r1"]),
			TreeGeometry.SURF_BARK, sides)
		_log_part(&"root", i, &"trunk", _seg_aabb(rt["from"], rt["to"], float(rt["r0"])))
	if roots.is_empty():
		return
	var base: Vector3 = stem[0]["pos"]
	var r0: float = float(stem[0]["r"])
	shapes.ellipsoid(base - Vector3(0.0, r0 * 0.22, 0.0),
		Vector3(r0 * 1.12, r0 * 0.52, r0 * 1.12), TreeGeometry.SURF_BARK,
		CLUMP_RINGS, CLUMP_SEGS, _hash01(Vector3i(0, 0, 1), BARK_SALT) * TAU)


# ====================================================================== shared
## A lobe's true half-height.
##
## `TreeGeometry.in_lobe` divides the vertical offset by `squash` and then
## tests the length against the radius, so a lobe's true half-height is the
## radius TIMES its squash. The generator's own table reads `lobe_h` the same
## way -- "crown height as a multiple of its radius" -- and between them a
## species gets the silhouette it is for: an acacia (0.42) and a palm (0.30)
## come out flat and wide, an oak (0.85) round, a poplar (1.85) a tall
## spindle. Nothing here has to invent a proportion.
##
## The one adjustment is a conifer skirt, clamped flat. A tier of a stepped
## cone is wide and low by definition, and clamping can only ever make a lobe
## THINNER than `in_crown` says is there, so the drawn crown is still inside
## the envelope the checks audit.
func _lobe_half(lobe: Dictionary, rad: float) -> float:
	var squash: float = maxf(float(lobe.get("squash", 1.0)), 0.05)
	var half: float = rad * squash
	if StringName(lobe.get("kind", &"crown")) == &"skirt":
		half = clampf(half, rad * 0.16, rad * 0.42)
	return maxf(half, 0.01)


func _lobe_aabb(lobe: Dictionary) -> AABB:
	var pos: Vector3 = lobe["pos"]
	var rad: float = float(lobe["radius"])
	var ext := Vector3(rad, _lobe_half(lobe, rad), rad)
	return AABB(pos - ext, ext * 2.0).abs()


func _seg_aabb(a: Vector3, b: Vector3, pad: float) -> AABB:
	var mn := Vector3(minf(a.x, b.x) - pad, minf(a.y, b.y) - pad, minf(a.z, b.z) - pad)
	var mx := Vector3(maxf(a.x, b.x) + pad, maxf(a.y, b.y) + pad, maxf(a.z, b.z) + pad)
	return AABB(mn, mx - mn).abs()


## A stable 0..1 from a cell, so a per-node or per-clump "random" number is
## reproducible rather than rolled. It is the same hash the voxel tint uses,
## with a different salt, which is why the two do not correlate.
func _hash01(c: Vector3i, salt: int) -> float:
	return TreeShapes.cell_hash(c, salt)


## Distance from a point to a segment, for the swept-radius test. Kept static
## and argument-only: it is a piece of algebra, and a piece of algebra that
## could read the spec is a piece of algebra that could disagree about where
## the tree is.
static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var len2: float = ab.length_squared()
	if len2 < 1e-9:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _log_part(role: StringName, n: int, host: StringName, box: AABB) -> void:
	part_log.append({"role": role, "n": n, "host": host, "aabb": box})
