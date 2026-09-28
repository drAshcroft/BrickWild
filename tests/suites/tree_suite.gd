extends RefCounted
## The tree family's contract, and the things `TreeCheck` cannot see.
##
## `TreeCheck` judges ONE tree against the ten rules. This suite does the
## per-family sweep the check cannot: every species of every style, at three
## heights, over a spread of seeds -- and the two contracts a check has no
## business holding (a build is a pure function, a voxel mesh is merged).
##
## Every species row is a real assertion, not a smoke test. A missing species
## name falls back silently inside `TreeGenerator`, so a sweep over the table
## is the only thing that notices a species that stopped existing.

## The rows. Every style must make every one of these, or the sweep is a lie.
const SPECIES := {
	&"voxel": [&"oak", &"birch", &"spruce", &"acacia", &"willow", &"palm"],
	&"indie": [&"oak", &"birch", &"poplar", &"willow", &"pine", &"dead"],
	&"natural": [&"oak", &"ash", &"beech", &"hawthorn", &"pine", &"willow"],
	&"magic": [&"worldtree", &"crystal", &"inverted", &"floating", &"weeping", &"ember"],
}

## Three heights per species, because a tree that only works at 14 m is a
## sculpture and not a species. The magic rows get their own heights below.
const HEIGHTS := [3.0, 9.0, 22.0]
const MAGIC_HEIGHTS := [8.0, 18.0, 34.0]
## How much of the unmerged face count the greedy pass must save.
##
## Not the number that sounds good. On a CURVED surface the algorithm is
## structurally limited: every row of a slice has a different extent, so a run
## almost never extends downward and most merges are runs of one. Measured
## across the six voxel species at three seeds each, `emitted / raw` lands
## between 0.41 and 0.73 -- and a SOLID BALL of the same envelope, which is the
## friendliest case the mesher will ever see, only reaches 0.41. A floor above
## that is not a quality bar, it is a suite that can never pass.
const MERGE_MIN := 0.25


static func run() -> SuiteResult:
	var res := SuiteResult.new("trees")
	for style in SPECIES:
		for species in SPECIES[style]:
			_sweep(res, style, species)
	_purity(res)
	_voxel_merge(res)
	_grid(res)
	_variety(res)
	return res


## A stand is a stamp if six seeds of one species come back the same size.
## Asked once per species rather than inside every `TreeCheck`, because it is a
## property of a STAND: two builds of one spec are supposed to be identical, so
## a per-tree version of this rule could only ever fail on its own subject.
static func _variety(res: SuiteResult) -> void:
	for style in SPECIES:
		for species in SPECIES[style]:
			var height: float = 18.0 if style == &"magic" else 12.0
			var spread: Vector2 = TreeCheck.stand_spread(style, species, height)
			res.checked += 1
			res.note("%s/%s stand: %d of 6 seeds distinct, %.0f%% height spread"
				% [style, species, int(round(spread.x * 6.0)), 100.0 * spread.y])
			if TreeCheck.is_a_stamp(spread):
				res.fail("%s/%s: only %d of 6 seeds drew a different tree; that is a stamp"
					% [style, species, int(round(spread.x * 6.0))])


static func _sweep(res: SuiteResult, style: StringName, species: StringName) -> void:
	var heights: Array = MAGIC_HEIGHTS if style == &"magic" else HEIGHTS
	var worst_tris := 0
	var total := 0
	for height in heights:
		for k in range(3):
			var spec := TreeSpec.new()
			spec.style = style
			spec.species = species
			spec.height = float(height)
			TreeGenerator.generate(spec, 9000 + k * 131)
			# The generator must not quietly swap the species out from under a
			# caller: a row for a species that does not exist would otherwise
			# pass by rendering the fallback and reporting it as a success.
			_expect(res, spec.species == species,
				"%s/%s: generator fell back to %s, so the species does not exist"
				% [style, species, spec.species])
			var builder := TreeBuilder.new()
			var mesh: ArrayMesh = builder.build(spec)
			var report: Dictionary = TreeCheck.new().check(spec, mesh, builder)
			if not report["ok"]:
				for f in report["failures"]:
					res.fail("%s/%s h=%.0f seed=%d -- %s"
						% [style, species, height, k, f])
			res.checked += 1
			for w in report["warnings"]:
				res.warn("%s/%s h=%.0f -- %s" % [style, species, height, w])
			var tris: int = int(report["stats"].get("tris", 0))
			total += tris
			worst_tris = maxi(worst_tris, tris)
			# A tree that costs more than 40k triangles is not a tree a village
			# can plant a hundred of, and the voxel rows are the ones that can
			# run away: a greedy mesher that stops merging grows quadratically.
			_expect(res, tris <= 40000,
				"%s/%s h=%.0f costs %d triangles; a wood needs a hundred of these"
				% [style, species, height, tris])
			if style == &"voxel":
				_expect(res, not builder.voxel_log.is_empty(),
					"%s/%s stamped no voxels" % [style, species])
			if style == &"magic":
				_expect(res, not spec.glow.is_empty(),
					"%s wrote no glow light" % species)
	res.note("%s/%s: %d tris worst, %d total over %d builds"
		% [style, species, worst_tris, total, heights.size() * 3])


## The build contract. `CastleBuilder` and `ChurchBuilder` are both pure
## functions of their spec, and both families have a suite asserting it; a tree
## that re-rolled a die at emit time would make `TreeCheck`'s measurements a
## second, luckier opinion, which is the exact blindness the generator split
## exists to prevent.
static func _purity(res: SuiteResult) -> void:
	for style in SPECIES:
		var spec := TreeSpec.new()
		spec.style = style
		spec.species = SPECIES[style][0]
		spec.height = 11.0
		TreeGenerator.generate(spec, 4242)
		var a: ArrayMesh = TreeBuilder.new().build(spec)
		var b: ArrayMesh = TreeBuilder.new().build(spec)
		_expect(res, a.get_surface_count() == b.get_surface_count(),
			"%s: two builds disagreed on the surface count" % style)
		for s in range(a.get_surface_count()):
			_expect(res, a.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
					== b.surface_get_arrays(s)[Mesh.ARRAY_VERTEX],
				"%s surface %d: two builds of one spec produced different vertices"
				% [style, s])
		# And the builder must be reusable: a second build on the SAME builder
		# must not carry the first one's cells into the second one's log.
		var reused := TreeBuilder.new()
		reused.build(spec)
		var first: int = reused.voxel_log.size()
		reused.build(spec)
		_expect(res, reused.voxel_log.size() == first,
			"%s: a reused builder accumulated voxels (%d then %d)"
			% [style, first, reused.voxel_log.size()])


## The compositing claim. `TreeShapes.voxel()` merges coplanar runs; if that
## pass silently stopped matching, every voxel tree would get three times
## heavier and nobody would see it in a picture.
static func _voxel_merge(res: SuiteResult) -> void:
	for species in SPECIES[&"voxel"]:
		for height in [6.0, 14.0]:
			var spec := TreeSpec.new()
			spec.style = &"voxel"
			spec.species = species
			spec.height = height
			TreeGenerator.generate(spec, 777)
			var builder := TreeBuilder.new()
			builder.build(spec)
			var stats: Dictionary = builder.voxel_stats
			res.checked += 1
			if stats.is_empty():
				res.fail("voxel/%s h=%.0f: no mesher stats" % [species, height])
				continue
			var raw: int = int(stats.get("raw", 0))
			var emitted: int = int(stats.get("emitted", 0))
			res.note("voxel/%s h=%.0f: %d cells, %d raw faces -> %d quads"
				% [species, height, int(stats.get("cells", 0)), raw, emitted])
			if raw <= 0:
				continue
			var saved: float = 1.0 - float(emitted) / float(raw)
			_expect(res, saved >= MERGE_MIN,
				"voxel/%s h=%.0f: merging only saved %.0f%% of %d faces (want %.0f%%)"
				% [species, height, 100.0 * saved, raw, 100.0 * MERGE_MIN])


## A voxel tree that is not ON the grid is a low-poly tree that happens to be
## aligned by luck. Every cell corner must land on a multiple of `block` from
## the grid origin, or two voxel trees side by side will not tile.
static func _grid(res: SuiteResult) -> void:
	for species in SPECIES[&"voxel"]:
		var spec := TreeSpec.new()
		spec.style = &"voxel"
		spec.species = species
		spec.height = 10.0
		TreeGenerator.generate(spec, 31337)
		var builder := TreeBuilder.new()
		var mesh: ArrayMesh = builder.build(spec)
		var origin: Vector3 = TreeGeometry.voxel_origin(spec)
		var off_grid := 0
		var checked_corners := 0
		for s in range(mesh.get_surface_count()):
			var vs: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v in vs:
				checked_corners += 1
				for axis in range(3):
					if not _on_grid(v[axis] - origin[axis], spec.block):
						off_grid += 1
						break
		res.checked += 1
		if off_grid > 0:
			res.fail("voxel/%s: %d of %d vertices are off the %.3f m grid"
				% [species, off_grid, checked_corners, spec.block])
		# And the ground contact must be an exact multiple of the block, so a
		# voxel tree can be dropped on a tile floor without a seam.
		var lo: float = (TreeCheck.measure(mesh)["lo"] as Vector3).y - origin.y
		_expect(res, _on_grid(lo, spec.block),
			"voxel/%s: the tree's foot is %.4f m off the grid origin" % [species, lo])


static func _on_grid(v: float, block: float) -> bool:
	var k: float = v / block
	return absf(k - roundf(k)) < 1e-4


static func _expect(res: SuiteResult, ok: bool, why: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(why)
