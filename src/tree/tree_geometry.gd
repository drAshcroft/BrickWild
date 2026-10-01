class_name TreeGeometry
extends RefCounted
## Single source of truth for a tree's massing. Pure functions of a TreeSpec.
##
## Same contract as ChurchGeometry / CastleGeometry / TempleGeometry: the
## builder that emits the mesh and the check that judges the tree read the same
## numbers, so a check cannot pass by agreeing with a second, luckier copy of
## the geometry. Model axes: +X right, +Y up, +Z deep, rooted at y = 0.
##
## The one measure that matters most is the pair `trunk_clear` / `canopy`.
## `SceneBounds.plant_of_node()` already computes exactly that pair for the
## 104 IMPORTED plants in `assets/props/catalog.json` -- canopy being the
## furthest any vertex reaches from the trunk axis, trunk the same at or below
## `TRUNK_HEIGHT`. `expected_radii()` returns the same two numbers for a
## GENERATED tree, from the spec alone, so `TreeQA` can hold the mesh against
## the promise. That is the whole reason a generated tree can stand in a
## village beside a loaded one without the clearance rules knowing which is
## which.

# ---- the shared band ----
## Must equal `SceneBounds.TRUNK_HEIGHT`. A person walking into a plant meets
## the plant in this band, so this band is what must stay off a road.
const TRUNK_HEIGHT := 1.8

## The four styles. `magic` is a style rather than a flag because its members
## are six different SHAPES, not six tints of one shape.
const STYLES: Array[StringName] = [&"voxel", &"indie", &"natural", &"magic"]

## 137.5 degrees. Successive branches off one parent are never evenly spaced in
## azimuth, and an even spacing is instantly readable as a manufactured object
## -- it is the difference between a tree and a Christmas tree.
const GOLDEN_ANGLE := 2.399963

## The four surfaces, in the order TreeBuilder indexes them.
const SURF_BARK := 0
const SURF_LEAF := 1
const SURF_ACCENT := 2
const SURF_GLOW := 3
const SURFACE_COUNT := 4

# ---- hard limits. Outside these a tree is a bug, not a style. ----
const HEIGHT_MIN := 1.2
const HEIGHT_MAX := 60.0
const TRUNK_R_MIN := 0.04
## The crown must be wider than the clear trunk, or the tree is a pole.
const CANOPY_OVER_TRUNK := 1.6
## A crown that starts below this fraction of the tree is a shrub with a stick.
const CROWN_MIN_FRACTION := 0.25
## The crown must not be a balloon on a mast, either.
const CROWN_MAX_FRACTION := 0.86
## Contact with the ground counts within this many metres, so a root that stops
## 2 cm short is not a floating tree.
const ROOT_CONTACT := 0.05


# ------------------------------------------------------------------ promises

## The magic kinds that do not touch the ground. Keyed on SPECIES, not on
## style: a magic tree's style is always `magic`, so a style test would demand
## that the floating one stand on the earth like every other. One kind hangs in
## the air on purpose, and the ROOTED rule has to be able to say so.
const UNROOTED_SPECIES: Array[StringName] = [&"floating"]

## How much of the crown a magic kind is entitled to claim at or below
## `TRUNK_HEIGHT`, as a fraction of `canopy_radius`.
##
## Four of the six magic trees break the plant convention that a plant is
## clear at head height, and each breaks it DELIBERATELY: a crystal lays a rune
## circle on the ground, an inverted tree's crown hangs below it, a weeping
## tree's curtain reaches the earth, and a floating tree has nothing near the
## earth at all. The honest fix is not to exempt them from the clearance rule
## but to make the PROMISE true -- these numbers are what the generator writes
## into `spec.trunk_clear`, and the magic builder is held to them like every
## other tree. A rule that quietly does not apply to half a family is a rule
## that has stopped measuring something.
const TRUNK_CLAIM := {
	&"crystal": 0.70,     # the rune circle
	&"inverted": 0.95,    # the dome, which hangs below the ground
	&"weeping": 0.85,     # the curtain, which reaches it
	&"floating": 0.0,     # nothing: island and vines hang above head height
}

## What the spec PROMISES the mesh will measure, in the two radii
## SceneBounds uses. Computed from the spec, never from the builder, so a
## builder that grew a wider crown than it was told to is caught.
static func expected_radii(spec: TreeSpec) -> Vector2:
	var out: Vector2 = Vector2(spec.canopy_radius, spec.trunk_clear) + draw_allowance(spec)
	# A drawing may stray past an envelope, but there is no envelope where a
	# tree claims nothing: a hanging island is wholly above head height and its
	# trunk promise is nothing, not an allowance on nothing.
	if spec.trunk_clear <= 0.0:
		out.y = 0.0
	return out


## How far a DRAWING may legitimately reach outside the analytic envelope the
## lobes describe, in metres. Eight per cent, plus half a voxel cell.
##
## The lobes are an envelope, not a mesh, and every emitter draws slightly
## outside it: a crystal shard cluster is placed at a lobe and then grows past
## it, a voxel cell's face sits half a block beyond the lobe that filled it, a
## conifer skirt is a lobe of `width` and the tiers beside it are wider still.
## Without the allowance those are all failures, and a rule that fires on
## correct geometry is a rule nobody can act on.
##
## It is an allowance and not a widening of the promise: the CLEARANCE rule
## still FAILS on anything past it, which is the direction that matters -- a
## crown over a roof, a trunk in a road. A generator that grew its crown by
## thirty per cent still fails; one that drew its shards a few centimetres
## proud of the lobe they sit on does not.
const DRAW_ALLOWANCE := 0.08


static func draw_allowance(spec: TreeSpec) -> Vector2:
	var a: float = spec.canopy_radius * DRAW_ALLOWANCE
	if spec.style == &"voxel":
		a += spec.block * 0.5
	return Vector2(a, a)


## The top of the tree the spec promises. A crown that overshoots it is a
## builder bug -- the generator is supposed to have fitted it.
static func promised_height(spec: TreeSpec) -> float:
	return spec.height


## True when this tree must actually touch the ground. Keyed on the SPECIES
## rather than the style, because a magic tree's style is always `magic` and a
## style test would stand the floating one on the earth like everything else.
static func is_rooted(spec: TreeSpec) -> bool:
	return spec.species not in UNROOTED_SPECIES


## How far above the ground a tree is allowed to start. Zero for everything
## that is rooted; the one kind that is not hangs at 18% of its own height,
## which is enough to read as floating and low enough to stay inside the frame
## of a portrait shot.
static func ground_clearance(spec: TreeSpec) -> float:
	if is_rooted(spec):
		return 0.0
	return maxf(1.6, spec.height * 0.34)


# ------------------------------------------------------------------ validation

## The things a generator must clamp before it writes them down. Returning a
## reason rather than a bool keeps `TreeGenerator` honest: it refuses to
## generate rather than generating a pole, exactly the way ChurchGenerator
## drops aisles that will not fit.
static func validate(spec: TreeSpec) -> Array[String]:
	var bad: Array[String] = []
	if spec.height < HEIGHT_MIN or spec.height > HEIGHT_MAX:
		bad.append("height %.2f m is outside %.1f..%.1f"
			% [spec.height, HEIGHT_MIN, HEIGHT_MAX])
	if spec.trunk_radius < TRUNK_R_MIN:
		bad.append("trunk radius %.3f m is under %.2f" % [spec.trunk_radius, TRUNK_R_MIN])
	if spec.canopy_radius < spec.trunk_radius * CANOPY_OVER_TRUNK:
		bad.append("canopy %.2f m is not %.1fx the trunk radius %.2f"
			% [spec.canopy_radius, CANOPY_OVER_TRUNK, spec.trunk_radius])
	var crown: float = spec.canopy_top - spec.canopy_base
	if crown <= 0.0:
		bad.append("crown has no height: base %.2f, top %.2f" % [spec.canopy_base, spec.canopy_top])
	elif spec.canopy_base < spec.height * CROWN_MIN_FRACTION:
		bad.append("crown starts at %.0f%% of the tree; a tree's crown starts at or above %.0f%%"
			% [100.0 * spec.canopy_base / maxf(spec.height, 0.001), 100.0 * CROWN_MIN_FRACTION])
	if spec.canopy_base > spec.height * CROWN_MAX_FRACTION:
		bad.append("clear trunk is %.0f%% of the tree; the crown is a balloon on a mast"
			% [100.0 * spec.canopy_base / maxf(spec.height, 0.001)])
	if spec.branches.is_empty():
		bad.append("no branches: a tree without a skeleton is a pole with foliage")
	if spec.lobes.is_empty():
		bad.append("no crown lobes")
	return bad


## How far the ROOTS reach from the trunk axis, in metres.
##
## They are part of what a plant occupies at head height, so they are part of
## what `trunk_clear` has to promise. They were not: the first sweep measured
## a trunk radius of 0.86 m against a promise of 0.34 m, and the whole
## difference was a foot of splayed roots -- geometry the generator never
## accounted for and the builder drew anyway.
##
## Scaled off the trunk, because a root is a root: a hawthorn's reach, a third
## of its trunk radius clear of the stem, is a gnarled old thing, and a fir's
## is a gentle swelling. Zero for a tree that does not touch the ground,
## because a floating island has no roots to spread.
static func root_spread(spec: TreeSpec) -> float:
	if not is_rooted(spec):
		return 0.0
	return spec.trunk_radius * (0.8 + spec.root_flare * 0.9)


# ------------------------------------------------------------------ skeleton

## The azimuth of the n-th branch off one parent. Golden angle, so a level is
## never evenly spaced and never lines up with the level above it.
static func phyllotaxis(index: int) -> float:
	return fposmod(GOLDEN_ANGLE * float(index), TAU)


## A unit direction for a branch leaving `parent` at `level`, `index`, with the
## given lift. Tropism is applied here rather than in the builder so the
## natural and indie styles share one branch grammar and differ only in how
## they draw it.
static func branch_dir(parent_dir: Vector3, level: int, index: int,
		lift: float) -> Vector3:
	var az: float = phyllotaxis(index)
	# A horizontal frame about the parent, so a branch keeps leaving the trunk
	# sideways rather than curling into its own parent direction.
	var ref_up: Vector3 = Vector3.UP if absf(parent_dir.dot(Vector3.UP)) < 0.94 \
		else Vector3.RIGHT
	var side: Vector3 = parent_dir.cross(ref_up).normalized()
	var out: Vector3 = parent_dir.cross(side).normalized()
	var d: Vector3 = (out * cos(az) + side * sin(az)).normalized()
	return d.lerp(Vector3.UP, clampf(lift, 0.0, 0.85)).normalized()


## Interpolate a branch's radius along it. `taper` is the fraction of radius
## kept per metre of run, so a long branch thins faster than a short one and the
## silhouette thickens where the tree is carrying the most crown.
static func branch_radius_at(r0: float, r1: float, t: float) -> float:
	return lerpf(r0, r1, clampf(t, 0.0, 1.0))


## The main stem as a polyline, [{pos, r}] from the ground to the crown, with
## the lean taken out of it and the root flare folded into the first node. The
## voxel stamper, the indie prism and the natural tube all read this one
## function, so a style cannot disagree with another about where the trunk is.
static func stem_points(spec: TreeSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lean: Vector3 = Vector3(sin(spec.lean_dir), 0.0, cos(spec.lean_dir)) * spec.lean
	var steps: int = 6
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		# No clearance offset: the stem of a floating island starts at the
		# island, not `clearance` metres above it. Offsetting it left a metre
		# of daylight between the roots and the first branch.
		var y: float = lerpf(0.0, spec.canopy_base, t)
		# The lean is quadratic in height, so the base stays plumb and the
		# crown does the leaning. A stem that starts leaning at the root looks
		# like it is falling over.
		var bend: Vector3 = lean * (t * t * spec.height)
		var r: float = spec.trunk_radius
		if i == 0 and is_rooted(spec):
			r += spec.trunk_radius * spec.root_flare
		out.append({"pos": Vector3(bend.x, y, bend.z), "r": r})
	return out


## Is `p` inside a crown lobe? Written once because the voxel stamper fills
## from it and the check audits from it, and a voxel tree whose leaves are
## stamped by a different rule than the one the check trusts is a voxel tree
## nobody can debug.
static func in_lobe(lobe: Dictionary, p: Vector3) -> bool:
	var c: Vector3 = lobe["pos"]
	var rad: float = float(lobe["radius"])
	var squash: float = float(lobe.get("squash", 1.0))
	var d: Vector3 = p - c
	d.y /= maxf(squash, 0.05)
	return d.length() <= rad


## The crown as a whole: is this point inside ANY lobe?
static func in_crown(spec: TreeSpec, p: Vector3) -> bool:
	for lobe in spec.lobes:
		if in_lobe(lobe, p):
			return true
	return false


# ------------------------------------------------------------------ voxel grid

## The corner of the voxel grid this tree stands in. Voxel trees are aligned,
## not centred: a tree whose lowest block straddles y = 0 sinks, and one that
## stops short of it floats, and both look like a modelling mistake.
static func voxel_origin(spec: TreeSpec) -> Vector3:
	return Vector3(0.0, TreeGeometry.ground_clearance(spec), 0.0)


## Snap a world point to the cell that contains it. Y is the axis that matters:
## a voxel tree's stack has to be integral or the silhouette staircases oddly.
static func voxel_cell(spec: TreeSpec, p: Vector3) -> Vector3i:
	var o: Vector3 = voxel_origin(spec)
	return Vector3i(
		int(floor((p.x - o.x) / spec.block)),
		int(floor((p.y - o.y) / spec.block)),
		int(floor((p.z - o.z) / spec.block)))


## The world-space centre of a cell.
static func voxel_centre(spec: TreeSpec, c: Vector3i) -> Vector3:
	var o: Vector3 = voxel_origin(spec)
	return o + (Vector3(c) + Vector3(0.5, 0.5, 0.5)) * spec.block


## How many cells across the crown has to be for nothing to be clipped.
static func voxel_span(spec: TreeSpec) -> Vector3i:
	var y: int = maxi(1, int(ceil(spec.height / maxf(spec.block, 0.01))))
	var r: int = maxi(1, int(ceil(spec.canopy_radius / maxf(spec.block, 0.01))))
	return Vector3i(r * 2 + 1, y, r * 2 + 1)


# ------------------------------------------------------------------ naming

const FIRST_WORDS := ["Ash", "Black", "Elder", "Grey", "Hollow", "Old", "Red",
	"Silver", "Thorn", "White", "Winter", "Yew"]
const SECOND_WORDS := ["barrow", "brook", "combe", "croft", "fen", "gate",
	"heath", "hollow", "marsh", "mere", "thwaite", "wold"]

const MAGIC_TITLES := {
	&"worldtree": "the World Tree",
	&"crystal": "the Singing Crystal",
	&"inverted": "the Upside-Down",
	&"floating": "the Wanderer",
	&"weeping": "the Mourner",
	&"ember": "the Ember",
}
