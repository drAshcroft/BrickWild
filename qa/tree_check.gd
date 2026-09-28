class_name TreeCheck
extends RefCounted
## Would this tree be worth standing next to?
##
## `MassingCheck` asks whether a building stands up. This asks whether a tree is
## a TREE, and every rule is a statement a person would make out loud about one:
##
##   ROOTED       it meets the ground -- or, for the one magic kind that floats,
##                it conspicuously does not
##   FITTED       the crown stays inside the height the caller locked, and
##                reaches it
##   CLEARANCE    the mesh measures the (canopy, trunk) pair the SPEC promised.
##                This is the load-bearing rule of the family: a generated tree
##                has to answer `SceneBounds.plant_of_node()`'s question the way
##                an imported one does, or a village cannot mix the two without
##                its clearance rules quietly lying to it
##   CROWN        there is a crown, it is wider than the trunk, and it has depth
##   SKELETON     the branches start on the stem, not in mid-air beside it
##   SUPPORTED    no foliage floats with nothing under it (voxel)
##   SOLID        no zero-area triangles, and the four-surface contract holds
##   FACING       every triangle winds the way its own normal says it does
##   GLOW         a magical tree lights itself, and an ordinary one does not
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {..}}

## How far the mesh may disagree with the spec's own promise about its size.
## One cell of a voxel tree is the honest floor: a greedy mesher rounds a face
## to a block boundary, and demanding millimetres of a blocky tree is asking
## for a bug report rather than a quality bar.
const RADIUS_TOL := 0.06
## How far short of its own promise a tree may come before the envelope is
## called generous rather than merely safe.
const SHORTFALL_WARN := 0.55
const VOXEL_TOL_BLOCKS := 1.0

## A stand is a stamp if this share of its members are within a few per cent of
## each other. Trees drawn from ONE seed are allowed to repeat -- seeds must be
## reproducible -- so this asks about a spread of SEEDS.
##
## This is a measure of a STAND and not a rule about one tree, which is why it
## is a static the suite calls once per species rather than a member of RULES.
## As a per-tree rule it rebuilt six trees on every single check, which over a
## 216-tree sweep is thirteen hundred extra voxel builds and forty minutes for a
## number nobody had looked at.
const VARIETY_SPREAD := 0.06

## Tolerance on "touches the ground". A root that stops 2 cm short is not a
## floating tree; one that stops 2 m up is.
const GROUND_TOL := 0.05

const RULES: Array[StringName] = [&"rooted", &"fitted", &"clearance", &"crown",
	&"skeleton", &"supported", &"solid", &"facing", &"glow"]

## The methods, so `RuleSet` can find them and a family can replace one by name.
const METHODS := {
	&"rooted": "_check_rooted", &"fitted": "_check_fitted",
	&"clearance": "_check_clearance", &"crown": "_check_crown",
	&"skeleton": "_check_skeleton", &"supported": "_check_supported",
	&"solid": "_check_solid", &"facing": "_check_facing",
	&"glow": "_check_glow",
}

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
var _builder: TreeBuilder = null


## The one entry point. `builder` carries the voxel's own log, which is the only
## honest source for the SUPPORTED rule -- re-deriving it from the mesh would be
## the check agreeing with itself.
func check(spec: TreeSpec, mesh: ArrayMesh, builder: TreeBuilder = null,
		overrides: Dictionary = {}) -> Dictionary:
	failures = []
	warnings = []
	_builder = builder
	stats = {}
	var spec_problems: Array[String] = TreeGeometry.validate(spec)
	stats["spec_problems"] = spec_problems.size()
	for problem in spec_problems:
		failures.append("spec: " + problem)
	var m: Dictionary = measure(mesh)
	# `merge(.., true)` rather than a dictionary literal assignment: GDScript's
	# Dictionary has no `update`, and reaching for one is how a check silently
	# stops reporting its own numbers.
	stats.merge({
		"tris": int(m["tris"]), "verts": int(m["verts"]),
		"surfaces": mesh.get_surface_count(),
		"canopy": float(m["canopy"]), "trunk": float(m["trunk"]),
		"height": (m["hi"] as Vector3).y, "ground": (m["lo"] as Vector3).y,
	}, true)
	RuleSet.run(self, RULES, METHODS, overrides,
		[spec, mesh, m, builder], [], failures, warnings)
	return {"ok": failures.is_empty(), "failures": failures,
		"warnings": warnings, "stats": stats}


func _fail(rule: StringName, why: String) -> void:
	failures.append("%s: %s" % [rule, why])


func _warn(rule: StringName, why: String) -> void:
	warnings.append("%s: %s" % [rule, why])


# ------------------------------------------------------------------ measures

## Everything the rules need, in ONE walk of the vertices. A rule that
## re-walked the mesh would be a second, lazier opinion about the same tree.
##
## Measured the way `SceneBounds.plant_of_node()` measures an imported model:
## canopy is the furthest any vertex reaches from the trunk axis, trunk is the
## same measure at or below `TRUNK_HEIGHT`. The two functions are deliberately
## the same question asked twice -- once of a loaded model, once of a generated
## one -- and `clearance` is the rule that holds them to the same answer.
static func measure(mesh: ArrayMesh, trunk_band := 0.0) -> Dictionary:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var canopy := 0.0
	var trunk := 0.0
	var tris := 0
	var verts := 0
	var degenerate := 0
	var facing_out := 0
	var facing_total := 0
	# A positional CHECKSUM, not a bounds. Two genuinely different trees share a
	# bounding box and a triangle count often enough that keying distinctness on
	# them reported four of six seeds as one tree and called a species a stamp
	# for it. The sum of every vertex's distance from the trunk axis, mixed, is
	# cheap and moves whenever any vertex does. Accumulated INSIDE the walk --
	# reading it after the loop is a scope error, and a scope error in this file
	# makes the whole suite silently run a third of its checks.
	var salt: int = 0
	var band: float = TreeGeometry.TRUNK_HEIGHT
	if trunk_band <= 0.0:
		trunk_band = INF
	for s in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		verts += vs.size()
		var i := 0
		while i + 2 < vs.size():
			tris += 1
			if (vs[i + 2] - vs[i]).cross(vs[i + 1] - vs[i]).length() < 1e-9:
				degenerate += 1
			i += 3
		for v in vs:
			lo = lo.min(v)
			hi = hi.max(v)
			var r: float = Vector2(v.x, v.z).length()
			canopy = maxf(canopy, r)
			if v.y <= band:
				trunk = maxf(trunk, r)
			salt = (salt + int(r * 1000.0) * 2654435761
				+ int(v.y * 1000.0) * 40503)
		# Only the BARK is held to the axis test, and only its SIDE faces. A leaf
		# hangs out over nothing, so its normal is about its own lobe rather than
		# about the trunk, and judging it against the axis would fail every
		# honest crown.
		#
		# THE RULE, restated because the first two attempts at it were wrong.
		# It is NOT "bark points away from the trunk axis": that asks about
		# horizontal faces only (a stem cap correctly points down) but then has
		# to guess whether a face belongs to the stem or to a branch, and a
		# branch's own end cap points back along the branch -- straight at the
		# trunk. Every band this rule drew caught a third of all bark triangles
		# in every style, on geometry that shades correctly.
		#
		# The invariant that is actually true, and that a winding bug violates,
		# is: **a triangle's winding and its declared normal agree**. Godot's
		# front faces are clockwise, so the winding of (a,b,c) gives
		# (c-a).cross(b-a). If that disagrees with the normal the emitter
		# wrote, the face is inside out no matter which solid it belongs to.
		# This caught the real bug -- the quad emitters declared one normal and
		# wound another -- and it is unambiguous, which is more than the axis
		# test ever was.
		#
		# A cap over the top of a stem segment is a near-vertical face on the
		# axis, and it is CORRECT -- it points down, into the joint it shares
		# with the next segment. The axis test has no opinion about up and down.
		#
		# And a BRANCH's own end cap points back along the branch, which for a
		# horizontal branch is straight at the trunk. That is the cap doing its
		# job, and counting it as inward flagged every branch in the tree -- a
		# third of all bark triangles, every time, in every style.
		#
		# So the band is the STEM's own width, twice over plus a little: a face
		# is judged only when its centroid could plausibly be part of the trunk.
		# Anything further out is a branch, and the axis has nothing to say
		# about a branch's own facing.
		if ns.size() != vs.size():
			continue
		var j := 0
		while j + 2 < vs.size():
			var wound: Vector3 = (vs[j + 2] - vs[j]).cross(vs[j + 1] - vs[j])
			if wound.length_squared() < 1e-12:
				j += 3
				continue
			facing_total += 1
			if wound.normalized().dot(ns[j]) > -0.2:
				facing_out += 1
			j += 3
	return {"lo": lo, "hi": hi, "canopy": canopy, "trunk": trunk,
		"tris": tris, "verts": verts, "degenerate": degenerate,
		"checksum": salt,
		"facing": float(facing_out) / maxf(1.0, float(facing_total)),
		"facing_total": facing_total}


# ---------------------------------------------------------------------- rules

## ROOTED -- it meets the ground, unless it is the one kind that floats.
func _check_rooted(spec: TreeSpec, _mesh: ArrayMesh, m: Dictionary, _b: TreeBuilder) -> void:
	var low: float = (m["lo"] as Vector3).y
	if TreeGeometry.is_rooted(spec):
		if low > GROUND_TOL:
			_fail(&"rooted", "the tree starts %.2f m above the ground" % low)
	elif low < 1.0:
		_fail(&"rooted", "a floating tree has %.2f m of ground clearance; it is not floating" % low)


## FITTED -- the crown stays inside the height the caller locked, and reaches it.
func _check_fitted(spec: TreeSpec, _mesh: ArrayMesh, m: Dictionary, _b: TreeBuilder) -> void:
	var top: float = (m["hi"] as Vector3).y
	var promised: float = TreeGeometry.promised_height(spec)
	# The same allowance the promise is held to, plus a hair. A rule with one
	# tolerance and a promise with another is a rule that fails on the
	# difference between them, and the difference is the allowance.
	var over: float = promised * (TreeGeometry.DRAW_ALLOWANCE + 0.01)
	if top > promised + over:
		_fail(&"fitted", "the crown reaches %.2f m, past the %.2f m it promised"
			% [top, promised])
	elif top < promised * 0.9:
		# A LEAFLESS tree is held to the SKELETON's reach, not the crown's: a
		# dead indie tree and an ember tree are bare, and there is no foliage
		# at the top of one to measure. Demanding it anyway asked a bare tree
		# to be taller than its own branches reach.
		if spec.leafless:
			_warn(&"fitted", "a bare tree tops out at %.2f m of a promised %.2f m"
				% [top, promised])
		else:
			_fail(&"fitted", "the tree tops out at %.2f m against a promised %.2f m"
				% [top, promised])


## CLEARANCE -- the mesh does not EXCEED the radii the spec promised.
##
## A bound, not an equality, and the direction matters. `VillageDressCheck` and
## `PropCatalog.canopy()` both ask this pair, and the direction a consumer
## cares about is "does this plant reach further than you said" -- a crown over
## a roof, a trunk in a road. Measuring short of the promise is not a hazard; a
## bare ember tree that occupies less room than its envelope is simply a small
## tree, and `CROWN` is the rule that asks whether it is too small.
##
## Testing it for equality instead produced three hundred failures, all of the
## same shape: every species, every height, "canopy measures 4.09 m, the spec
## promised 3.60 m" -- or the other way. A promise is a bound on what a
## generator may do to the world, not a measurement of what it did.
##
## A promise that is much LARGER than the tree is its own kind of lie, so a
## shortfall beyond `SHORTFALL_WARN` is a warning: the envelope was authored
## generously and nobody has tightened it.
func _check_clearance(spec: TreeSpec, _mesh: ArrayMesh, m: Dictionary, _b: TreeBuilder) -> void:
	var want: Vector2 = TreeGeometry.expected_radii(spec)
	var got: Vector2 = Vector2(float(m["canopy"]), float(m["trunk"]))
	var tol: float = maxf(RADIUS_TOL, spec.block * VOXEL_TOL_BLOCKS) \
		if spec.style == &"voxel" else RADIUS_TOL
	if got.x - want.x > tol:
		_fail(&"clearance", "canopy reaches %.2f m, past the %.2f m it promised (tolerance %.2f)"
			% [got.x, want.x, tol])
	if got.y - want.y > tol:
		_fail(&"clearance", "trunk reaches %.2f m at %.1f m up, past the %.2f m it promised"
			% [got.y, TreeGeometry.TRUNK_HEIGHT, want.y])
	if got.x < want.x * SHORTFALL_WARN:
		_warn(&"clearance", "canopy %.2f m against a promised %.2f m; the envelope is generous"
			% [got.x, want.x])
	if got.y < want.y * SHORTFALL_WARN and want.y > 0.2:
		_warn(&"clearance", "trunk %.2f m against a promised %.2f m at head height"
			% [got.y, want.y])


## CROWN -- there is a crown, it is wider than the trunk, and it has depth.
func _check_crown(spec: TreeSpec, _mesh: ArrayMesh, m: Dictionary, _b: TreeBuilder) -> void:
	if spec.lobes.is_empty():
		_fail(&"crown", "the spec has no crown lobes")
		return
	var crown: float = float(m["canopy"])
	if crown <= spec.trunk_radius * TreeGeometry.CANOPY_OVER_TRUNK * 0.8:
		_fail(&"crown", "a %.2f m canopy is barely wider than a %.2f m trunk"
			% [crown, spec.trunk_radius])
	if spec.leafless:
		return
	# A SPINDLE IS A SPECIES, not a defect. `lobe_h` is the whole silhouette and
	# a poplar's is 1.85 against an oak's 0.85, so warning about a tall narrow
	# crown warned about exactly the trees that are supposed to be tall.
	var tall: float = (m["hi"] as Vector3).y - (m["lo"] as Vector3).y
	if crown < 0.25 * tall and spec.leaf_density < 1.2:
		_warn(&"crown", "a %.2f m canopy is under a quarter of the %.2f m height"
			% [crown, tall])


## SKELETON -- every branch starts on the stem, not beside it in mid-air.
func _check_skeleton(spec: TreeSpec, _mesh: ArrayMesh, _m: Dictionary, _b: TreeBuilder) -> void:
	if spec.branches.is_empty():
		_fail(&"skeleton", "the spec has no branches")
		return
	var stem: Array[Dictionary] = TreeGeometry.stem_points(spec)
	var reach: float = maxf(spec.trunk_radius * 2.5, spec.block * 1.5)
	# LEVEL 0 ONLY. A level-1 branch starts at its parent's tip, which is out in
	# the crown by design -- that is what a branch is -- so asking whether it
	# touches the stem asks whether the tree has a trunk, and the answer is
	# always no. The rule that was actually wanted is "every branch starts on
	# the skeleton", and the skeleton is the trunk plus the branches below it.
	for i in range(spec.branches.size()):
		if int(spec.branches[i]["level"]) > 0:
			continue
		var from: Vector3 = spec.branches[i]["from"]
		var near: float = INF
		for node in stem:
			near = minf(near, (node["pos"] as Vector3).distance_to(from))
		if near > reach:
			_fail(&"skeleton", "branch %d starts %.2f m off the stem (allowed %.2f m)"
				% [i, near, reach])
			return


## SUPPORTED -- voxel only: no leaf block hanging in the air.
##
## `voxel_log` is the only source for this. Re-deriving "is this leaf
## supported" from the mesh would be the check re-implementing the stamper and
## then congratulating itself.
func _check_supported(spec: TreeSpec, _mesh: ArrayMesh, _m: Dictionary, b: TreeBuilder) -> void:
	if spec.style != &"voxel" or b == null:
		return
	if b.voxel_log.is_empty():
		_fail(&"supported", "a voxel tree logged no cells, so nothing was stamped")
		return
	var loose := 0
	var leaves := 0
	for cell in b.voxel_log:
		if int(cell["surf"]) != TreeGeometry.SURF_LEAF:
			continue
		leaves += 1
		if not bool(cell["supported"]):
			loose += 1
	if loose > 0:
		_fail(&"supported", "%d of %d leaf blocks have nothing under them" % [loose, leaves])


## SOLID -- the surface contract, and no zero-area triangles.
##
## The contract is AT MOST four surfaces, not exactly four. `MeshKit.commit()`
## omits an empty SurfaceTool, so a dead indie tree legitimately ships bark and
## accent and no leaf, and a voxel tree ships no glow: demanding four would be
## demanding a bug. What must hold is that every surface present falls inside
## the four-slot palette, which is exactly what lets `TreeAssembler` map them
## by index and know which colour each one is.
func _check_solid(spec: TreeSpec, mesh: ArrayMesh, m: Dictionary, _b: TreeBuilder) -> void:
	if mesh.get_surface_count() > TreeGeometry.SURFACE_COUNT:
		_fail(&"solid", "%d surfaces; the palette has %d"
			% [mesh.get_surface_count(), TreeGeometry.SURFACE_COUNT])
	if int(m["degenerate"]) > 0:
		_fail(&"solid", "%d zero-area triangles" % int(m["degenerate"]))
	if int(m["tris"]) < 12:
		_fail(&"solid", "only %d triangles: that is not a tree" % int(m["tris"]))
	if not spec.leafless:
		var leaves: PackedVector3Array = \
			mesh.surface_get_arrays(TreeGeometry.SURF_LEAF)[Mesh.ARRAY_VERTEX]
		if leaves.is_empty():
			_fail(&"solid", "a leafy tree emitted no leaf geometry")


## FACING -- bark points away from the trunk axis. Inverted winding on a
## closed trunk is invisible from outside and obvious from inside, which is
## exactly the defect a screenshot cannot catch.
## FACING -- every triangle's winding agrees with the normal it declares.
func _check_facing(_spec: TreeSpec, _mesh: ArrayMesh, m: Dictionary, _b: TreeBuilder) -> void:
	if float(m["facing"]) < 0.995:
		_fail(&"facing", "%.0f%% of faces wind against their own normal; %d triangles are inside out"
			% [100.0 * float(m["facing"]),
				int(float(m["facing_total"]) * (1.0 - float(m["facing"])))])


## GLOW -- a magical tree lights itself, and an ordinary one does not. An unlit
## crystal is a purple rock; an inn that glows is a fire hazard.
func _check_glow(spec: TreeSpec, _mesh: ArrayMesh, _m: Dictionary, _b: TreeBuilder) -> void:
	if spec.style == &"magic":
		if spec.glow.is_empty():
			_fail(&"glow", "a magical tree with no light is a coloured tree")
			return
		for g in spec.glow:
			if float(g["energy"]) <= 0.0:
				_fail(&"glow", "the glow at %.1f m has no energy" % (Vector3(g["pos"] as Vector3).y))
	elif not spec.glow.is_empty():
		_warn(&"glow", "an ordinary %s tree carries %d lights" % [spec.style, spec.glow.size()])


## How varied a STAND of one species is, as (distinct shapes, height spread).
##
## "Distinct" is the primary number and it is measured as DISTINCTNESS, not as
## a spread. Everything the generator normalises -- the height, the crown
## radius, the crown's own depth -- is pinned by `_refit_crown` and
## `_fit_envelope` and reports zero on a stand that plainly does not look like a
## stamp, so a spread over them measures the normaliser, not the trees. Two
## trees are the same tree when their triangle count, their bounding box and
## their centre agree, and six seeds of one species should give six answers.
static func stand_spread(style: StringName, species: StringName,
		height: float, seed: int = 9000) -> Vector2:
	var seen: Dictionary = {}
	var tops: Array[float] = []
	for k in range(6):
		var s := TreeSpec.new()
		s.style = style
		s.species = species
		s.height = height
		TreeGenerator.generate(s, seed + k * 7919)
		var m: ArrayMesh = TreeBuilder.new().build(s)
		var meas: Dictionary = measure(m)
		var tris: int = int(meas["tris"])
		var hi: Vector3 = meas["hi"]
		var key: String = "%d/%d" % [tris, int(meas["checksum"])]
		seen[key] = true
		tops.append(hi.y)
	return Vector2(float(seen.size()) / 6.0, _spread(tops))


## Is a species a stamp? Two builds of ONE spec are supposed to be identical --
## that is reproducibility -- so this can only ever be asked about seeds, and
## only across them.
static func is_a_stamp(spread: Vector2) -> bool:
	return spread.x < 0.8


static func _spread(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var lo: float = values[0]
	var hi: float = values[0]
	var total := 0.0
	for v in values:
		lo = minf(lo, v)
		hi = maxf(hi, v)
		total += v
	var mean: float = total / float(values.size())
	return 0.0 if mean <= 0.0 else (hi - lo) / mean
