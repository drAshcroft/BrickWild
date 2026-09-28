class_name TreeAssembler
extends RefCounted
## A generated tree as a scene: one mesh, four materials, and the lights a
## magic tree carries.
##
## The same split as `VillageAssembler` and `TempleAssembler`, and for the same
## reason. Everything above this file works in metres and polygons and never
## loads a model, which is what lets the geometry suite sweep hundreds of trees
## headless in milliseconds; here, at the very end, the mesh is handed a
## `StandardMaterial3D` per surface and becomes something a camera can see.
## `TreeBuilder` turns a `TreeSpec` into an `ArrayMesh` and stops there.
##
## Three things live here that the builder deliberately does not:
##
##   * MATERIALS. `TreeBuilder` never makes one. The palette is the spec's, so
##     the generator decides it and the picture can be argued about from a spec
##     rather than from a builder.
##   * LIGHTS. `spec.glow` is a list of DATA: {"pos", "colour", "energy",
##     "range"}, and each row becomes an `OmniLight3D` here. The houses, shops,
##     hotel, temple and village all take their lamps from `LightKit`, so a
##     lamp that is dark in one family is dark in all of them and is fixed once.
##     `TreeMagic` writes the ROWS -- which lobes carry a light is part of what
##     makes a crystal a crystal -- and clears the list on every build, so the
##     lamps are a function of the spec and never of a previous tree's.
##   * VARIATION. `scatter()` is how a caller plants a wood of N from one spec.
##     Before it existed every caller grew its own copy of that loop, and they
##     all planted the same tree N times.
##
## Model axes are the family's: +X right, +Y up, +Z deep, every tree rooted at
## y = 0 -- the one invariant `TreeCheck` holds every family to, bar the one
## magic kind that hangs on purpose. Nothing in this file moves a vertex; a tree
## is placed by its transform, which is why a scatter of forty oaks costs forty
## transforms and not forty copies of the geometry maths.


## The four surfaces, in `TreeGeometry`'s order. Repeated here as constants
## because every other family assembler does the same, and because a caller
## that wants to recolour one surface after the fact should not have to reach
## into the geometry module to say which number it means.
const SURF_BARK := TreeGeometry.SURF_BARK
const SURF_LEAF := TreeGeometry.SURF_LEAF
const SURF_ACCENT := TreeGeometry.SURF_ACCENT
const SURF_GLOW := TreeGeometry.SURF_GLOW

## What a `spec.glow` row that leaves a number out gets. A row is a
## `Dictionary` and a caller that appends one by hand should get a lit tree
## rather than a light left at the origin with no colour and no reach.
const GLOW_ENERGY := 1.8
const GLOW_RANGE := 6.0
## A scatter varies a wood's height by this much either side, and turns each
## tree about Y. A wood of one height and one facing is a plantation, not a wood.
const HEIGHT_JITTER := 0.15

## The seed stride between two neighbours in a scatter. 7919 is prime and coprime
## with the short period a `RandomNumberGenerator` shows across nearby seeds, so
## `seed + i * SEED_STRIDE` does not walk two trees down the same stream -- which
## is the failure a `+ 1` stride produces and the reason a wood looks like one
## tree reflected.
const SEED_STRIDE := 7919


## One surface's material, and the reason it is not the project's house
## material.
##
## `vertex_color_use_as_albedo` is REQUIRED here rather than a nicety. The
## voxel stamper puts its per-cell grain in the vertex colours -- `TreeShapes`
## emits none of its own, so `TreeBuilder` writes a stable jitter per cell from
## `TreeShapes.cell_hash()` -- and a material that ignores COLOR renders a voxel
## crown as one flat plastic blob, which is the single ugliest thing a voxel
## tree can do. It is also what gives the natural and indie styles their tonal
## range, because a leaf clump is flat-shaded geometry lit by one light.
##
## Culling is off for the reason `ShellAssembler` turns it off: a greedy mesher
## emits a face wherever the material changes, so a bark cell against a leaf
## cell has two coincident faces, and a one-sided pass through the pair is how a
## canopy gets holes in it. Everything else stays default. A tree is not metal
## and not glass.
static func tree_material(colour: Color, rough := 0.92) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	return m


## The glow surface, which is a real material and not a trick: it is what makes
## a magical tree actually cast light in a render, and it is the difference
## between a QA report that says "3 lights" and a picture of a tree you can
## see the colour of.
##
## The albedo is the same colour as the emission, so at energy 1.6 the surface
## reads as its own source rather than as a lit white patch, and the flag is
## inherited from `tree_material` because a glow block is still a voxel cell
## with a colour that must survive.
static func glow_material(colour: Color) -> StandardMaterial3D:
	var m := tree_material(colour)
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = 1.6
	return m


## A whole tree: a `MeshInstance3D` and one `OmniLight3D` per `spec.glow` entry.
##
## `builder` is passed in rather than always created here so the caller can read
## `voxel_log` and `part_log` -- the counts the geometry checks measure -- after
## this returns. A null builder means "just give me the tree", and one is built
## locally for the duration of the call.
##
## The builder is NEVER attached to the returned node, and that is the whole
## reason the node outlives it: a `TreeBuilder` is a `RefCounted` and is
## released the moment this function's local reference goes out of scope, but
## the `ArrayMesh` it returned is a `Resource` the `MeshInstance3D` holds by
## its own reference, so the geometry stays exactly as long as the tree does.
## A node that owned its builder would tie the mesh's lifetime to a working
## variable, and a tree would vanish when a `for` loop ended.
##
## An UNGENERATED spec is not an error. A default `TreeSpec` builds an empty
## mesh under a default name rather than crashing, because a harness
## constructing a spec field by field should be able to put a tree in a scene
## before the generator has decided anything about it -- and because a crash
## here would be a crash in the middle of a scene assembly, which is the worst
## place to find one.
static func build(spec: TreeSpec, builder: TreeBuilder = null) -> Node3D:
	var root := Node3D.new()
	root.name = tree_name(spec)
	# The one local the builder lives in, and the one that is allowed to die.
	var worker: TreeBuilder = TreeBuilder.new() if builder == null else builder
	var mesh: ArrayMesh = worker.build(spec)
	if mesh == null:
		return root
	var tree_mesh := MeshInstance3D.new()
	tree_mesh.name = "Mesh"
	tree_mesh.mesh = mesh
	surface_materials(tree_mesh, spec)
	root.add_child(tree_mesh)
	# The lights hang off the root beside the mesh, not inside a "Lights"
	# node: a tree is one object, and a caller counting `get_child_count()`
	# should be counting the tree's parts, not the folders it is filed in.
	for i in range(spec.glow.size()):
		root.add_child(_light(spec, spec.glow[i], i))
	return root


## A material per surface, in `TreeGeometry`'s order: bark, leaf, accent, glow.
##
## Slot resolution honours a `material_slot:N` surface name, exactly as
## `ShellAssembler.surface_materials` does, because Godot omits an empty stream
## and a tree with no glow surface would otherwise shift every later colour
## one slot along -- a leafless dead tree wearing its accent as bark.
static func surface_materials(node: MeshInstance3D, spec: TreeSpec) -> void:
	if node.mesh == null:
		return
	var colours: Array[Color] = [spec.bark_color, spec.leaf_color,
		spec.accent_color, spec.glow_color]
	for i in range(node.mesh.get_surface_count()):
		var slot: int = _slot_of(node.mesh, i)
		if slot < 0 or slot >= colours.size():
			continue
		var c: Color = colours[slot]
		node.set_surface_override_material(i,
			glow_material(c) if slot == SURF_GLOW else tree_material(c))


## A wood: one regenerated tree per position, under a single `forest` root.
##
## This is the integration seam a village wants later and the reason it cannot
## be a `for` loop in the caller: a wood is N trees that are all the same
## SPECIES and none of them the same TREE, and a caller that only had `build()`
## would have to re-derive a spec, re-seed a generator and grow a jitter by
## hand at every one of its N planting sites.
##
## So for each position the spec is deep-copied, the height is jittered by
## `HEIGHT_JITTER` and the copy is run back through `TreeGenerator` on a seed
## of `seed + i * SEED_STRIDE`. The re-run is not optional: the copy carries
## the source spec's derived fields -- lobes, skeleton, palette -- and a
## jittered height against a stale crown is a taller tree with the old one's
## canopy hanging in its middle.
##
## The spec is copied rather than mutated, because the caller's spec is still
## theirs afterwards -- `duplicate(true)` so the crown, skeleton and palette
## are not shared with it, plus a fresh `rng` rather than a shared one, since
## `TreeGenerator.generate` reseeds it and a shared stream would walk two
## neighbouring trees down one sequence.
##
## Every child is given a fresh `TreeBuilder`: one builder holds one spec, and
## a builder reused across a changing spec is how a wood ends up with one
## canopy in all forty trees.
static func scatter(spec: TreeSpec, positions: PackedVector3Array,
		seed: int) -> Node3D:
	var root := Node3D.new()
	root.name = "forest"
	# The jitter's own stream, seeded from the caller, so the same wood is
	# planted in the same places twice and never out of step with itself.
	var r := RandomNumberGenerator.new()
	r.seed = seed
	for i in range(positions.size()):
		var s: TreeSpec = spec.copy()
		# Cleared because `TreeGenerator` rewrites lobes, branches and palette
		# but never touches `glow`: a copy of a spec that has already been
		# built would otherwise carry the SOURCE tree's lamp positions, and a
		# wood would be forty trees all lit from one crown.
		s.glow = []
		s.height = spec.height * r.randf_range(1.0 - HEIGHT_JITTER, 1.0 + HEIGHT_JITTER)
		TreeGenerator.generate(s, seed + i * SEED_STRIDE)
		var tree: Node3D = build(s)
		# Positioned by transform and not by moving vertices, so forty trees
		# cost forty transforms and one copy of the geometry maths.
		tree.position = positions[i]
		tree.rotation.y = r.randf_range(0.0, TAU)
		tree.name = "%s_%d" % [tree_name(s), i]
		root.add_child(tree)
	return root


## What this tree is called. A generated spec always has a name -- a magic tree
## is a title out of `TreeGeometry.MAGIC_TITLES`, anything else is a first and
## a second word -- and an ungenerated one has none, so it gets the family name
## rather than an empty node that a scene tree reads as a mistake.
static func tree_name(spec: TreeSpec) -> String:
	var n: String = spec.variant_name.strip_edges()
	if n.is_empty():
		return "Tree"
	# Godot refuses `.` `:` `@` `/` `%` and `"` in a node name, and a
	# hand-written spec is a hand-written string.
	for bad: String in [".", ":", "@", "/", "%", "\""]:
		n = n.replace(bad, "_")
	return n


## One `spec.glow` row as a lamp, through `LightKit` so it attenuates like
## every other light in the project. `pos` is in the tree's own space, so the
## lamp turns and moves with the tree when the tree is turned and moved.
static func _light(spec: TreeSpec, entry: Dictionary, index: int) -> OmniLight3D:
	var pos: Vector3 = entry.get("pos", Vector3.ZERO)
	var colour: Color = entry.get("colour", spec.glow_color)
	var energy: float = float(entry.get("energy", GLOW_ENERGY))
	var reach: float = float(entry.get("range", GLOW_RANGE))
	var lamp: OmniLight3D = LightKit.make(pos, colour, energy, reach)
	lamp.name = "glow_%d" % index
	return lamp


## Which logical surface a mesh surface is. The positional index, unless the
## builder named it -- the `material_slot:N` convention `VillageBuilder`
## introduced for exactly the reason above.
static func _slot_of(mesh: Mesh, index: int) -> int:
	if mesh is ArrayMesh:
		var n: String = (mesh as ArrayMesh).surface_get_name(index)
		if n.begins_with("material_slot:"):
			return int(n.trim_prefix("material_slot:"))
	return index
