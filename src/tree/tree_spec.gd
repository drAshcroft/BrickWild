class_name TreeSpec
extends RefCounted
## Plan data for the tree family (TRE-001..004).
##
## A tree follows the same three-part contract as every other family here:
## `TreeGenerator` decides, `TreeGeometry` owns the maths, `TreeBuilder` only
## emits. Everything the builder needs is written onto this object first, so a
## builder that re-rolls a die at emit time is a bug the QA suite can see.
##
## Four styles, and they are four different ALGORITHMS rather than four
## palettes on one shape -- a reskin of one tree four times is not a tree
## family:
##
##   voxel   a cubic grid, faces merged into runs. A Minecraft tree.
##   indie   faceted low-poly: a 6-sided tapered trunk, golden-angle forks,
##           chunky ellipsoid crown clumps. Reads at 60 px and at 6 m.
##   natural an L-system-ish skeleton with taper, tropism and layered crown
##           shells. What a village or a forest wants.
##   magic   six named supernaturals, each a different SILHOUETTE and not a
##           tint: world tree, crystal, inverted, floating, weeping, ember.
##
## Model axes: +X right, +Y up, +Z deep. Every tree is rooted at y = 0, which
## is the one invariant `TreeQA` holds every family to.

# ---- what a person chooses ----
var style: StringName = &"natural"
var species: StringName = &"oak"
var seed := 0
var rng := RandomNumberGenerator.new()

## The height a caller locks. The generator fits every part into it and the
## check refuses a tree whose crown escapes it.
var height := 12.0

# ---- what the generator derives ----
## Clear trunk: ground to the first branch. `trunk_clear` is the promised
## radius at or below `TRUNK_HEIGHT` -- the same measure SceneBounds takes of
## an imported model, so a generated tree and a loaded one answer the same
## question the same way.
var trunk_height := 0.0
var trunk_radius := 0.0
var trunk_clear := 0.0
## The promised canopy radius, and the crown's vertical band.
var canopy_radius := 0.0
var canopy_base := 0.0
var canopy_top := 0.0

# ---- shape controls, all dimensionless fractions so a style can share them ----
var lean := 0.06                 ## 0 = plumb, 1 = the top a body-width off plumb
var lean_dir := 0.0              ## radians, so a seed picks a direction not a magnitude
var root_flare := 0.55           ## extra radius at the ground, as a fraction of trunk_radius
var branch_levels := 3
var branch_angle := 0.62         ## radians off the parent, before tropism
var branch_decay := 0.71         ## radius kept by each child
var branch_pitch := 2.3          ## height between successive whorls, in metres
var taper := 0.9                 ## radius kept per metre of rise along a branch
var leaf_density := 0.62
## Voxel only: the grid edge, in metres. The single number that decides
## whether a voxel tree reads as a tree or as a pile of cubes.
var block := 0.5
## How far the crown may dip below `canopy_base` and the trunk may overshoot it.
var crown_slack := 0.0

# ---- what the generator writes as DATA, so the builder and the check agree ----
## Crown blobs: {"pos": Vector3, "radius": float, "squash": float, "kind": StringName}
## `squash` MULTIPLIES: a lobe's true half-height is `radius * squash`, which is
## exactly what `TreeGeometry.in_lobe` computes, so 0.30 is a pancake and 1.95
## is a spindle. It divided, once, in `_lobe_top`, so the crown was fitted
## against an envelope twice the wrong size and the top of every tall species
## was trimmed away for no reason.
var lobes: Array[Dictionary] = []
## Branch skeleton: {"from": Vector3, "to": Vector3, "r0": float, "r1": float,
##                   "level": int, "phyl": float}
var branches: Array[Dictionary] = []
## Lights the assembler turns into OmniLight3D: {"pos", "colour", "energy", "range"}
var glow: Array[Dictionary] = []
## Voxel only: the grid, in cells, and the cell size the builder must use.
var grid: Vector3i = Vector3i.ONE

# ---- materials ----
var bark_color := Color("5c4634")
var leaf_color := Color("4c7038")
## A tree with no foliage at all -- a dead indie tree, an ember magic tree.
## A flag rather than a colour with zero alpha, because a later consumer will
## happily multiply an alpha-0 green into an opaque black.
var leafless := false

var accent_color := Color("8fa36b")
var glow_color := Color("bfe6ff")

# ---- naming ----
var variant_name := ""


## A deep copy, for anything that wants to grow a VARIANT of a spec -- a wood
## that jitters each tree's height, a caller that recolours one surface.
##
## Not `Object.duplicate()`: `RefCounted` does not have one. `SceneTree` and
## `Node` do; a plain `RefCounted` has to be copied by hand, and getting that
## wrong is how a wood ends up with one tree's crown on forty stems. So the
## arrays are rebuilt element by element and the dictionaries inside them are
## copied too, and the RNG is a fresh one -- sharing an RNG between the source
## and the copy is how a regeneration reads out of a stream another tree is
## already using.
func copy() -> TreeSpec:
	var out := TreeSpec.new()
	out.style = style
	out.species = species
	out.seed = seed
	out.rng = RandomNumberGenerator.new()
	out.rng.seed = seed
	out.height = height
	out.trunk_height = trunk_height
	out.trunk_radius = trunk_radius
	out.trunk_clear = trunk_clear
	out.canopy_radius = canopy_radius
	out.canopy_base = canopy_base
	out.canopy_top = canopy_top
	out.lean = lean
	out.lean_dir = lean_dir
	out.root_flare = root_flare
	out.branch_levels = branch_levels
	out.branch_angle = branch_angle
	out.branch_decay = branch_decay
	out.branch_pitch = branch_pitch
	out.taper = taper
	out.leaf_density = leaf_density
	out.block = block
	out.crown_slack = crown_slack
	out.lobes = []
	for lobe in lobes:
		out.lobes.append(lobe.duplicate())
	out.branches = []
	for branch in branches:
		out.branches.append(branch.duplicate())
	out.glow = []
	for g in glow:
		out.glow.append(g.duplicate())
	out.grid = grid
	out.bark_color = bark_color
	out.leaf_color = leaf_color
	out.accent_color = accent_color
	out.glow_color = glow_color
	out.leafless = leafless
	out.variant_name = variant_name
	return out
