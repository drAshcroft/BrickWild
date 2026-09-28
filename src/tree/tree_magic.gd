class_name TreeMagic
extends RefCounted
## The six magical trees. One emitter each, because a magic family that is six
## tints of one silhouette is six colours and not six trees.
##
## Same three-part contract as every other family here: `TreeGenerator` decides,
## `TreeGeometry` owns the maths, and this class only emits. Where a magic
## silhouette cannot be read out of `spec.lobes` the override is written at the
## top of the emitter that makes it. A magical species' lobe list is a
## PLACEHOLDER the generator wrote without knowing this was a magic tree -- the
## generator grows one blob per branch tip because that is right for an oak and
## wrong for a dome that hangs below the ground -- so it is the mass the tree is
## built FROM, not a contract the builder is forbidden to improve on. What is
## never overridden is the SKELETON: every member that has a trunk draws
## `TreeGeometry.stem_points`, and every member that has branches draws
## `spec.branches`, so `TreeCheck._rule_skeleton` is asking about the geometry
## the generator planned rather than about a second opinion.
##
## What each member is, and what makes it ITSELF rather than a recolour:
##
##   worldtree  colossal and BUTTRESSED: a foot of splayed roots is the signature
##   crystal    prismatic -- hex prisms and shard clusters, no wood anywhere
##   inverted   the crown hangs BELOW the ground and the spikes point at the sky
##   floating   a rock island with vines under it, and it does not touch down
##   weeping    a dome from which 14-22 strands fall; the strands ARE it
##   ember      bare and burning: charred spurs, coal tips, rising embers
##
## Determinism: no `randf()` and no `Time` in this file. Every "random" number
## is `TreeShapes.cell_hash` of the index being jittered, which is a pure
## function of that index, so two builds of one spec are byte-identical and the
## reproducibility rule in the family has something it can actually hold.
##
## Every member writes at least one `spec.glow` entry: `TreeCheck._rule_glow`
## holds a magical tree to lighting itself, and a coloured tree that emits no
## light is a failed magic tree even when it is a beautiful one.
##
## On the promised radius. `TreeCheck._rule_clearance` measures the furthest
## vertex from the trunk axis and holds it to `spec.canopy_radius`, and the
## generator's own branch tips overshoot that promise by a third or more, so
## everything drawn out here that would carry the silhouette past the promise is
## pulled back in by `_fit()`. The one thing deliberately NOT pulled back is
## the weeping tree's curtain, which has to reach the ground to be a weeping
## tree at all; that trade is written at the emitter.

## The six, in the order the titles list them.
const SPECIES: Array[StringName] = [&"worldtree", &"crystal", &"inverted",
	&"floating", &"weeping", &"ember"]

## A buttress toe is capped at this radius. It is not a style choice: the toe
## ring is an eight-sided polygon, so its outermost vertex falls short of the
## promised `trunk_clear` by up to 7.6% of the toe, and 0.7 m keeps that
## shortfall inside `TreeCheck`'s 0.06 m tolerance on a tree of any size.
const MAX_TOE := 0.70


## spec -> mesh. Owns its own `TreeShapes`, dispatches on the species, and
## returns the committed four-surface mesh.
##
## `spec.glow` is an OUTPUT channel of this call, so it is cleared first: build
## has to be a function of the spec alone, and a second build of the same spec
## must not leave two copies of every light behind.
static func build(spec: TreeSpec) -> ArrayMesh:
	var shapes := TreeShapes.new()
	spec.glow.clear()
	match spec.species:
		&"crystal":
			_crystal(spec, shapes)
		&"inverted":
			_inverted(spec, shapes)
		&"floating":
			_floating(spec, shapes)
		&"weeping":
			_weeping(spec, shapes)
		&"ember":
			_ember(spec, shapes)
		_:
			_worldtree(spec, shapes)
	# The SAME post-condition the other three styles get, for the same reason: a
	# crystal's shard clusters grow past the lobe they hang on, and a fit held in
	# one builder and not in this one is a fit that applies to three quarters of
	# a family.
	return TreeShapes.fit_envelope(shapes.commit(), spec)




# ------------------------------------------------------------------- 1 worldtree

## The World Tree. Colossal, and the only member whose IDENTITY is at its feet:
## seven to nine thick buttress roots splaying out of the base and down into the
## ground, half a trunk-radius thick at the shoulder, standing exactly on the
## radius the spec promised in `trunk_clear`.
##
## The crown is a stack of WIDE FLAT PLATES over three tiers of branches, with
## a glow core inside the trunk. A ball of blobs would be an oversized oak: the
## plates are what make the canopy read as layered from below, which is the only
## place anybody ever sees a tree this size from.
static func _worldtree(spec: TreeSpec, shapes: TreeShapes) -> void:
	var tr: float = spec.trunk_radius
	var clear: float = maxf(spec.trunk_clear, tr * 1.05)
	# The stem's first node carries the root flare as a SMOOTH COLLAR, and a
	# collar this thick would swallow the buttresses whole -- they are all
	# inside it, so the tree's signature would not be visible from anywhere.
	# The flare is drawn as the roots instead, which measure the same promised
	# radius from the outside and mean something. Hence base_scale.
	_stem(shapes, spec, TreeGeometry.SURF_BARK, 8, tr / clear)
	_buttresses(spec, shapes)
	_tubes(spec, shapes, TreeGeometry.SURF_BARK, 0, 3)

	var clump: float = _clump(spec)
	var plates: Array[Dictionary] = _plates(spec, clump, 1.05)
	for i in range(plates.size()):
		var c: Vector3 = _fit(spec, plates[i]["pos"], clump * 1.15)
		# Two plates per clump, one above the other: the stacking is what keeps
		# this from being the same lump repeated everywhere.
		_blob(shapes, c, clump * 1.15, clump * 0.35, TreeGeometry.SURF_LEAF, 2, 10)
		_blob(shapes, c + Vector3.UP * (clump * 0.52), clump * 0.82, clump * 0.26,
			TreeGeometry.SURF_LEAF, 2, 10)

	# The core: inside the trunk at 55% of the clear trunk, a little wider than
	# the wood it sits in, so it reads as a knot of light rather than a lamp
	# hidden in a pipe. The branch whorls around it are what let it be seen at
	# all, which is why this tree is drawn with three tiers.
	var core: Dictionary = _at_y(spec, spec.trunk_height * 0.55)
	var core_r: float = minf(float(core["r"]) * 1.16, clear)
	_blob(shapes, core["pos"], core_r, core_r * 0.9,
		TreeGeometry.SURF_GLOW, 3, 7)
	_light(spec, core["pos"], 3.4, spec.canopy_radius * 0.5)
	_light(spec, Vector3(0.0, lerpf(spec.canopy_base, spec.canopy_top, 0.55), 0.0),
		1.7, spec.canopy_radius * 1.5)


## The buttress foot: a splayed limb out of the trunk, then a short VERTICAL
## ankle into the earth.
##
## The ankle is the part that matters. A root that arrives at the ground at an
## angle lands on a single polygon edge, and a tree whose roots meet the soil
## that way looks like cones stuck in a plane; dropped straight down, the foot
## presents a flat ring to the ground, which is both how a buttress really sits
## and how its outermost vertex lands on `trunk_clear` rather than past it.
static func _buttresses(spec: TreeSpec, shapes: TreeShapes) -> void:
	var tr: float = spec.trunk_radius
	var clear: float = maxf(spec.trunk_clear, tr * 1.05)
	var toe: float = minf(tr * 0.34, MAX_TOE)
	var d: float = maxf(clear - toe, tr * 0.5)
	var n: int = 7 + int(_h(0, 0, 0, 3) * 3.0)          # 7..9
	var shoulder: Vector3 = Vector3(0.0, clear * 0.62, 0.0)
	for i in range(n):
		var az: float = TreeGeometry.phyllotaxis(i) + (_h(i, 0, 0, 4) - 0.5) * 0.34
		var out := Vector3(cos(az), 0.0, sin(az))
		var ankle: Vector3 = out * d
		shapes.tube(shoulder, ankle + Vector3.UP * (toe * 1.3), tr * 0.5,
			toe * 1.05, TreeGeometry.SURF_BARK, 6)
		shapes.tube(ankle + Vector3.UP * (toe * 1.3), ankle, toe * 1.05, toe,
			TreeGeometry.SURF_BARK, 8)
		# the heel behind the ankle, so the foot has depth in it and is not a
		# row of pegs: a low shard, well inside the promised radius
		shapes.shard(ankle + Vector3.UP * (toe * 1.6), ankle - out * (toe * 1.5),
			toe * 0.8, toe * 0.25, TreeGeometry.SURF_BARK, 4, az)


# -------------------------------------------------------------------- 2 crystal

## The Singing Crystal. No wood anywhere: the trunk is a hexagonal prism, the
## branches are prisms, and the foliage is a ring of shard spikes.
##
## `spec.lobes` for this species is the generator's CONIFER skirt list, a stack
## of wide flat tiers up the whole height. Drawing those as blobs would give a
## purple spruce, which is exactly what the other three styles already do. Each
## tier is replaced by a RING OF SHARDS standing on its radius instead, so the
## crown is a bundle of crystal points with air between them and the silhouette
## belongs to no other member of the family.
##
## The rune circle is the one flat thing in the tree, and it is flat on purpose:
## it is the only surface here that reads from directly above, and a magic tree
## seen from a hill needs one.
static func _crystal(spec: TreeSpec, shapes: TreeShapes) -> void:
	var tr: float = spec.trunk_radius
	var stem: Array[Dictionary] = TreeGeometry.stem_points(spec)
	var mid: Vector3 = stem[stem.size() / 2]["pos"]
	var top: Vector3 = stem[stem.size() - 1]["pos"]
	# Two hex prisms rather than one: a single 20 m shard is a mast, and the
	# generator's lean has to show as a change of axis, not as a bent tube.
	shapes.shard(stem[0]["pos"], mid, float(stem[0]["r"]), tr * 0.74,
		TreeGeometry.SURF_BARK, 6)
	shapes.shard(mid, top, tr * 0.74, maxf(tr * 0.30, 0.01),
		TreeGeometry.SURF_BARK, 6)

	# The branches are pulled in to 0.7 of the promised radius, because a spike
	# cluster is grown on the end of every one of them and the cluster is a
	# quarter of the radius long. The prisms therefore live INSIDE the cone of
	# skirt shards, which is where a spire's ribs belong anyway.
	var cluster: float = spec.canopy_radius * 0.27
	for b in spec.branches:
		if int(b["level"]) > 1:
			continue
		var from: Vector3 = b["from"]
		var to: Vector3 = _fit(spec, b["to"], float(b["r1"]) + cluster)
		shapes.shard(from, to, float(b["r0"]), float(b["r1"]),
			TreeGeometry.SURF_BARK, 5, float(b["phyl"]))

	# Every branch tip carries a cluster of spikes -- but a gated subset of
	# them. The generator leaves a couple of hundred tips, and that many
	# clusters is a hedge, not a crown. The gate is a hash of the tip index,
	# so which tips spark is still the seed's decision.
	var tips: Array[Dictionary] = _tips(spec)
	var lit := 0
	for i in range(tips.size()):
		if lit >= 26:
			break
		if _h(i, 0, 0, 7) > 0.32:
			continue
		lit += 1
		var b: Dictionary = tips[i]
		var tip: Vector3 = b["to"]
		var root: Vector3 = b["from"]
		var axis: Vector3 = (tip - root).normalized()
		var r: float = maxf(float(b["r1"]), tr * 0.06)
		var k: int = 3 + int(_h(i, 0, 0, 8) * 3.0)          # 3..5 spikes
		for j in range(k):
			var az: float = TreeGeometry.phyllotaxis(i * 5 + j)
			var tilt: float = 0.30 + 0.60 * _h(i, j, 0, 9)
			var d: Vector3 = (axis.rotated(Vector3.UP, az) * cos(tilt)
				+ Vector3.UP * sin(tilt)).normalized()
			var len: float = spec.canopy_radius * (0.10 + 0.17 * _h(i, j, 1, 10))
			# alternating glow and accent: half the cluster is light, half is
			# the solid it is growing out of
			var surf: int = TreeGeometry.SURF_GLOW if j % 2 == 0 \
				else TreeGeometry.SURF_ACCENT
			shapes.shard(tip, tip + d * len, r * 1.15, maxf(r * 0.12, 0.004),
				surf, 4, az)
		_light(spec, tip, 1.1, spec.canopy_radius * 0.30)

	# Every lobe becomes a ring of shards standing on its radius. The ring is
	# cut to a third of the way in: the shard stands at 0.82 of the tier
	# radius and reaches 0.64 of it further out, so a full-radius ring would
	# put the crown half a radius past what the spec promised.
	for li in range(spec.lobes.size()):
		var lobe: Dictionary = spec.lobes[li]
		var c: Vector3 = lobe["pos"]
		var rr: float = maxf(minf(float(lobe["radius"]), spec.canopy_radius / 1.5),
			tr * 0.5)
		var n: int = 5 + (li % 2)
		for j in range(n):
			var az: float = TreeGeometry.phyllotaxis(li * 7 + j)
			var out := Vector3(cos(az), 0.0, sin(az))
			var base: Vector3 = c + out * (rr * 0.82)
			var tilt: float = 0.22 + 0.30 * _h(li, j, 0, 11)
			var d: Vector3 = (out * cos(tilt) - Vector3.UP * sin(tilt)).normalized()
			shapes.shard(base, base + d * (rr * (0.30 + 0.34 * _h(li, j, 1, 12))),
				rr * 0.16, maxf(rr * 0.03, 0.004), TreeGeometry.SURF_LEAF, 4, az)

	# the rune circle
	shapes.disc(Vector3(0.0, 0.02, 0.0), spec.canopy_radius * 0.6,
		TreeGeometry.SURF_GLOW, 14, Vector3.UP)
	shapes.disc(Vector3(0.0, 0.03, 0.0), spec.canopy_radius * 0.34,
		TreeGeometry.SURF_ACCENT, 12, Vector3.UP)
	_light(spec, Vector3(0.0, 0.0, 0.0), 2.2, spec.canopy_radius * 0.9)
	_light(spec, Vector3(0.0, spec.height * 0.72, 0.0), 2.6,
		spec.canopy_radius * 1.1)


# ------------------------------------------------------------------- 3 inverted

## The Upside-Down. It grows DOWNWARD: a short trunk off the ground, branches
## that sweep down and out into the earth, and a dome of foliage BELOW the
## ground plane. The only growth above ground is a ring of leaf blades at the
## top of the trunk -- the inverted crown, the roots the whole tree stands on,
## pointing back at the sky.
##
## It is still rooted: the trunk's first node is at y = 0 like every other tree
## in the family, which is what keeps it out of `TreeGeometry`'s floating
## exception.
##
## `spec.lobes` cannot be drawn here. The generator put a blob on every branch
## tip, and every one of those tips is at or above the ground; a dome that hangs
## below it cannot be a blob at a tip. What the generator IS trusted for is the
## mass: the clump size, the mean of the lobe radii, is the size of every plate
## in the dome, so the crown is still made of the foliage the spec planned.
static func _inverted(spec: TreeSpec, shapes: TreeShapes) -> void:
	var clump: float = _clump(spec)
	_stem(shapes, spec, TreeGeometry.SURF_BARK, 7)

	# Branches mirrored through the horizontal plane. The generator's azimuths,
	# levels and radii are used unchanged -- only the vertical component of each
	# run is flipped -- so this is the same skeleton turned over, not a second
	# one invented here.
	for b in spec.branches:
		if int(b["level"]) > 1:
			continue
		var from: Vector3 = b["from"]
		var to: Vector3 = b["to"]
		var d: Vector3 = to - from
		var down := Vector3(d.x, -absf(d.y), d.z)
		if down.length_squared() < 1e-6:
			continue
		var tip: Vector3 = _fit(spec, from + down.normalized() * d.length(),
			float(b["r1"]))
		shapes.tube(from, tip, float(b["r0"]), float(b["r1"]),
			TreeGeometry.SURF_BARK, 5)

	# the hanging dome: concentric rings of plates, widest a third of the way
	# down, which is the profile of a mass hanging under a point
	var dome: Array[Dictionary] = [
		{"r": 0.55, "y": -0.012, "n": 7, "s": 1.30},
		{"r": 0.84, "y": -0.058, "n": 9, "s": 1.15},
		{"r": 0.98, "y": -0.105, "n": 9, "s": 1.00},
		{"r": 0.90, "y": -0.150, "n": 8, "s": 0.88},
		{"r": 0.66, "y": -0.180, "n": 7, "s": 0.74},
		{"r": 0.38, "y": -0.195, "n": 5, "s": 0.58},
		{"r": 0.13, "y": -0.200, "n": 3, "s": 0.42},
	]
	for ring in range(dome.size()):
		var row: Dictionary = dome[ring]
		var n: int = int(row["n"])
		for j in range(n):
			var az: float = TreeGeometry.phyllotaxis(ring * 11 + j) \
				+ (_h(ring, j, 0, 13) - 0.5) * 0.30
			var r: float = clump * float(row["s"])
			var c := Vector3(cos(az), 0.0, sin(az)) * spec.canopy_radius * float(row["r"])
			c.y = spec.height * float(row["y"])
			_blob(shapes, _fit(spec, c, r), r, r * 0.30,
				TreeGeometry.SURF_LEAF, 2, 10)

	# the inverted crown: leaf blades rising off the top of the trunk, each
	# tipped with a clump, each reaching a height taken from the spec rather
	# than from a second opinion about how tall a tree ought to be
	var crown: Dictionary = _at_y(spec, spec.canopy_base)
	for i in range(9):
		var az: float = TreeGeometry.phyllotaxis(i + 31)
		var base: Vector3 = crown["pos"] + Vector3(cos(az), 0.0, sin(az)) \
			* spec.trunk_radius * 0.5
		var tip_y: float = (0.90 + 0.09 * _h(i, 0, 0, 22)) * spec.height
		var lean: float = 0.10 + 0.22 * _h(i, 1, 0, 21)
		var dy: float = maxf(tip_y - base.y, 0.05)
		var horiz: float = minf(dy * tan(lean), spec.canopy_radius * 0.55)
		var tip: Vector3 = base + Vector3(cos(az) * horiz, dy, sin(az) * horiz)
		var w: float = maxf(clump * 0.85, 0.02)
		shapes.shard(base, tip, w, w * 0.24, TreeGeometry.SURF_LEAF, 4, az)
		_blob(shapes, tip - Vector3(0.0, dy * 0.18, 0.0), w * 0.95, w * 0.55,
			TreeGeometry.SURF_LEAF, 2, 8, az)

	_light(spec, Vector3(0.0, spec.height * 0.5, 0.0), 2.0,
		spec.canopy_radius * 0.7)
	_light(spec, Vector3(0.0, -spec.height * 0.12, 0.0), 2.8,
		spec.canopy_radius * 1.2)


# -------------------------------------------------------------------- 4 floating

## The Wanderer. A rock island in the air with a grass cap, a crown on top and
## vines under the bottom, and it does not touch the ground.
##
## This is the one place the file reconstructs a number the spec does not
## carry. `TreeGeometry.ground_clearance()` answers 0 for this tree, because it
## keys off `spec.style` and a magic tree's style is always `&"magic"` -- the
## generator lifted the FLOATING species' canopy in `TreeGenerator._fit()`
## instead of its style. The 18%-of-height air the magic family promises is
## therefore built here, and the island is hung off it.
##
## The skeleton is used but REMAPPED rather than moved: every y in the
## generator's branches and lobes is scaled from [0, height] into the air band
## above the cap, so the branch grammar, the taper and the clump sizes are all
## still the generator's and only the floor has moved. The bare `stem_points`
## polyline is NOT drawn: for the reason above it starts at y = 0, and drawing
## it would stand this tree on the ground.
static func _floating(spec: TreeSpec, shapes: TreeShapes) -> void:
	var cr: float = spec.canopy_radius
	# ONE source for the clearance. This used to re-derive it as
	# `maxf(1.0, height * 0.18)` while `TreeGeometry.ground_clearance` said
	# `maxf(1.6, height * 0.34)`, and the island sat lower than the rule
	# believed -- ROOTED failed nine times on a tree that was floating in the
	# picture. A number two files both own is a number that will disagree.
	var air: float = TreeGeometry.ground_clearance(spec)
	var cap_y: float = air + maxf(0.35 * cr, 0.5)
	# The rock stops short of the ground, so the clear air under a tree that
	# does not touch down is the island's own UNDERSIDE, not the cap's height.
	# Derived as DEPTH first and subtracted, not the other way round: asking for
	# `floor_y` and clamping it can put the floor above the cap, and an island
	# with its underside over its own roof is a thing no amount of tuning the
	# other half of the equation will fix. Depth is capped by the air beneath,
	# so the underside is always above it.
	var depth: float = clampf(0.42 * cr, 0.12, maxf(0.12, cap_y - air - 0.45))
	var floor_y: float = cap_y - depth
	var span: float = maxf(0.5, spec.height * 0.985 - cap_y)
	var inv: float = 1.0 / maxf(spec.height, 0.001)
	var top: float = spec.height * 0.985

	# the island: a squashed rock hanging under a flat grass cap
	_blob(shapes, Vector3(0.0, floor_y + 0.5 * depth, 0.0), cr * 0.62,
		depth * 0.5, TreeGeometry.SURF_BARK, 3, 7)
	shapes.disc(Vector3(0.0, cap_y, 0.0), cr * 0.66, TreeGeometry.SURF_LEAF,
		12, Vector3.UP)
	for i in range(5):
		var az: float = TreeGeometry.phyllotaxis(i + 47)
		var out := Vector3(cos(az), 0.0, sin(az))
		var d: float = cr * (0.26 + 0.24 * _h(i, 0, 0, 41))
		var y: float = maxf(floor_y + depth * (0.26 + 0.34 * _h(i, 1, 0, 42)),
			floor_y + depth * 0.18)
		shapes.shard(Vector3(0.0, y, 0.0) + out * d,
			Vector3(0.0, y - depth * 0.5, 0.0) + out * (d * 1.2),
			cr * 0.10, maxf(cr * 0.02, 0.004), TreeGeometry.SURF_BARK, 4, az)

	# 5-8 short trunk stubs on the cap: the island's own small forest, which is
	# what makes the crown above read as grown rather than balanced
	var n: int = 5 + int(_h(0, 0, 0, 43) * 4.0)          # 5..8
	var stub_h: float = maxf(0.05 * spec.height, 0.3)
	for i in range(n):
		var az: float = TreeGeometry.phyllotaxis(i + 61)
		var out := Vector3(cos(az), 0.0, sin(az))
		var lean: float = 0.18 + 0.26 * _h(i, 0, 0, 44)
		shapes.tube(Vector3(0.0, cap_y - 0.1, 0.0) + out * (cr * 0.05),
			out * (cr * 0.10 + lean * cr) + Vector3.UP * stub_h,
			spec.trunk_radius * 0.6, maxf(spec.trunk_radius * 0.3, 0.01),
			TreeGeometry.SURF_BARK, 5)
		_blob(shapes, out * (cr * 0.10 + lean * cr) + Vector3.UP * stub_h,
			cr * 0.13, cr * 0.09, TreeGeometry.SURF_LEAF, 2, 8, az)

	# the crown, lifted into the air
	for b in spec.branches:
		var from: Vector3 = b["from"]
		var to: Vector3 = b["to"]
		from.y = cap_y + clampf(from.y * inv, 0.0, 1.0) * span
		to.y = cap_y + clampf(to.y * inv, 0.0, 1.0) * span
		shapes.tube(from, _fit(spec, to, float(b["r1"])), float(b["r0"]),
			float(b["r1"]), TreeGeometry.SURF_BARK, clampi(6 - int(b["level"]), 3, 6))
	var clump: float = _clump(spec)
	var plates: Array[Dictionary] = _plates(spec, clump, 1.05)
	for i in range(plates.size()):
		var c: Vector3 = plates[i]["pos"]
		c.y = minf(cap_y + clampf(c.y * inv, 0.0, 1.0) * span, top)
		_blob(shapes, _fit(spec, c, clump * 1.2), clump * 1.2, clump * 0.38,
			TreeGeometry.SURF_LEAF, 2, 10)

	# vines: the underside of the island is a ceiling, and these hang off it.
	# The drop is capped by the clear air underneath, leaf blob included, so
	# the lowest vertex in the tree is never the thing that fails the rule.
	var v: int = 6 + int(_h(0, 0, 0, 45) * 5.0)          # 6..10
	var leaf: float = maxf(cr * 0.075, 0.02)
	# And the vine drop is floored against the clearance, not against a magic
	# number: a strand with a leaf blob on it reaches `len` BELOW its anchor, so
	# the anchor's depth is not the tree's depth.
	var drop: float = maxf(air + 0.20 - maxf(cr * 0.10, 0.02), 0.10)
	for i in range(v):
		var az: float = TreeGeometry.phyllotaxis(i + 83)
		var out := Vector3(cos(az), 0.0, sin(az))
		var d: float = cr * (0.10 + 0.24 * _h(i, 0, 0, 46))
		var len: float = drop * (0.45 + 0.55 * _h(i, 1, 0, 47))
		var p0: Vector3 = Vector3(0.0,
			floor_y + depth * (0.10 + 0.22 * _h(i, 2, 0, 48)), 0.0) + out * d
		var p1: Vector3 = p0 + out * (cr * 0.03) - Vector3.UP * (len * 0.35)
		var p2: Vector3 = p0 + out * (cr * 0.07) - Vector3.UP * (len * 0.74)
		var p3: Vector3 = p0 + out * (cr * 0.12) - Vector3.UP * len
		var r: float = maxf(cr * 0.022, 0.006)
		shapes.tube(p0, p1, r, r * 0.78, TreeGeometry.SURF_BARK, 4)
		shapes.tube(p1, p2, r * 0.78, r * 0.52, TreeGeometry.SURF_BARK, 4)
		shapes.tube(p2, p3, r * 0.52, maxf(r * 0.3, 0.003), TreeGeometry.SURF_BARK, 4)
		_blob(shapes, p3, leaf, maxf(cr * 0.10, 0.02), TreeGeometry.SURF_LEAF, 2, 6, az)
		_light(spec, p3, 0.8, cr * 0.5)
	_light(spec, Vector3(0.0, floor_y, 0.0), 2.4, cr * 1.1)
	_light(spec, Vector3(0.0, cap_y + span * 0.6, 0.0), 2.0, cr * 1.2)


# -------------------------------------------------------------------- 5 weeping

## The Mourner. A dome crown, and fourteen to twenty-two long strands falling
## out of its underside -- the strands ARE the silhouette. A weeping tree whose
## strands are short enough to stay inside the crown is a weeping tree with no
## feature at all.
##
## Each strand starts ON a crown plate, picked round robin, so it is anchored in
## foliage rather than started in the air beside it, and the droop runs from a
## quarter of the tree's height to three fifths of it.
##
## The one place the promised radius is deliberately not held. The curtain is
## clamped to `canopy_radius` horizontally, but its LOWER half is inside
## `TRUNK_HEIGHT`, and `TreeCheck._rule_clearance` measures everything below
## that band as trunk -- so a willow that reaches its own ground measures its
## whole crown as a trunk. Stopping the strands above head height would satisfy
## the rule and produce a shrub. The trade is recorded here rather than hidden.
static func _weeping(spec: TreeSpec, shapes: TreeShapes) -> void:
	_stem(shapes, spec, TreeGeometry.SURF_BARK, 7)
	var clump: float = _clump(spec)
	var plates: Array[Dictionary] = _plates(spec, clump, 1.1)
	for i in range(plates.size()):
		var c: Vector3 = _fit(spec, plates[i]["pos"], clump * 1.3)
		_blob(shapes, c, clump * 1.3, clump * 0.32, TreeGeometry.SURF_LEAF, 2, 10)
		_blob(shapes, c + Vector3.UP * (clump * 0.44), clump * 0.95, clump * 0.24,
			TreeGeometry.SURF_LEAF, 2, 10)

	var n: int = clampi(14 + int(spec.height * 1.2), 14, 22)
	for i in range(n):
		var anchor: Vector3 = _fit(spec, plates[i % plates.size()]["pos"],
			clump * 1.3)
		var az: float = TreeGeometry.phyllotaxis(i + 101)
		var out := Vector3(cos(az), 0.0, sin(az))
		var want: float = spec.height * (0.25 + 0.35 * _h(i, 0, 0, 15))
		var tuft: float = maxf(spec.canopy_radius * 0.13, 0.02)
		var drop: float = minf(want, maxf(anchor.y - 0.10 - tuft, 0.12))
		var r: float = maxf(spec.canopy_radius * 0.045, 0.01)
		var p1: Vector3 = _fit(spec, anchor + out * (spec.canopy_radius * 0.06)
			- Vector3.UP * (drop * 0.16), r)
		var p2: Vector3 = _fit(spec, anchor + out * (spec.canopy_radius * 0.13)
			- Vector3.UP * (drop * 0.52), r * 0.7)
		var p3: Vector3 = _fit(spec, anchor + out * (spec.canopy_radius * 0.20)
			- Vector3.UP * drop, r * 0.4)
		# the first segment is the shoot leaving the branch: wood. The rest is
		# what hangs, and what hangs is green.
		shapes.tube(anchor, p1, r * 1.1, r, TreeGeometry.SURF_BARK, 4)
		shapes.tube(p1, p2, r, r * 0.7, TreeGeometry.SURF_LEAF, 4)
		shapes.tube(p2, p3, r * 0.7, maxf(r * 0.34, 0.004), TreeGeometry.SURF_LEAF, 4)
		_blob(shapes, p3, maxf(spec.canopy_radius * 0.09, 0.02), tuft,
			TreeGeometry.SURF_LEAF, 2, 6, az)

	_light(spec, Vector3(0.0, lerpf(spec.canopy_base, spec.canopy_top, 0.4), 0.0),
		2.4, spec.canopy_radius * 1.3)
	_light(spec, Vector3(0.0, spec.trunk_height * 0.9, 0.0), 1.4,
		spec.canopy_radius * 0.6)


# ---------------------------------------------------------------------- 6 ember

## The Ember. Bare: `spec.leafless` is already true for this species and no leaf
## surface is drawn at all, which is the whole point -- a burning tree with
## leaves would just be a tree with an orange light in it.
##
## A blackened tapering stem, two or three heavy forks, sharp upswept spurs on
## the ends, a coal on every tip, and a column of flat ember discs rising out
## of the crown. The discs face straight up so the column reads from any angle
## a camera can be at, and they are the tree's top: the generator's own branch
## tips stop around half way, so the embers are what carry the height the spec
## promised.
static func _ember(spec: TreeSpec, shapes: TreeShapes) -> void:
	_stem(shapes, spec, TreeGeometry.SURF_BARK, 6)
	# The generator's stem is a cylinder with a flare, so the taper a dead tree
	# is read by is drawn here: a bare leader off the top of the trunk, thinned
	# to a splinter, which is what is left when a tree dies standing up.
	var crown: Dictionary = _at_y(spec, spec.canopy_base)
	shapes.shard(crown["pos"], crown["pos"] + Vector3.UP * (spec.height * 0.17),
		spec.trunk_radius * 0.8, maxf(spec.trunk_radius * 0.10, 0.01),
		TreeGeometry.SURF_BARK, 5)
	var forks := 0
	for bi in range(spec.branches.size()):
		var b: Dictionary = spec.branches[bi]
		var lv: int = int(b["level"])
		if lv > 1:
			continue
		var from: Vector3 = b["from"]
		var to: Vector3 = _fit(spec, b["to"], float(b["r1"]))
		# The first three primaries are the forks, and they are drawn fat: a
		# charred tree that splits three ways reads as a split, one that splits
		# twenty ways reads as a bush.
		var fat: float = 1.0
		if lv == 0 and forks < 3:
			fat = 1.9
			forks += 1
		shapes.tube(from, to, float(b["r0"]) * fat, float(b["r1"]) * fat,
			TreeGeometry.SURF_BARK, 5 if lv == 0 else 4)
		if lv < 1:
			continue
		# an upswept spur and a coal on the end of every secondary
		var dir: Vector3 = (to - from).normalized()
		var az: float = TreeGeometry.phyllotaxis(bi)
		var up: Vector3 = (dir.rotated(Vector3.UP, az) * 0.55
			+ Vector3.UP * 0.85).normalized()
		var coal: float = maxf(spec.trunk_radius
			* (0.34 + 0.22 * _h(bi, 0, 0, 52)), 0.01)
		var spur: Vector3 = _fit(spec, to + up * spec.canopy_radius
			* (0.20 + 0.20 * _h(bi, 0, 0, 51)), coal)
		shapes.shard(to - dir * spec.canopy_radius * 0.05, spur,
			maxf(float(b["r1"]) * 0.9, spec.trunk_radius * 0.05),
			maxf(spec.trunk_radius * 0.012, 0.003), TreeGeometry.SURF_ACCENT, 4, az)
		_blob(shapes, spur, coal, coal * 0.8, TreeGeometry.SURF_GLOW, 2, 6, az)

	# the rising column: decreasing radius, scattered heights, all facing up
	var n: int = 8 + int(_h(0, 0, 0, 31) * 6.0)          # 8..13
	var lo: float = maxf(spec.canopy_base, spec.height * 0.55)
	for i in range(n):
		var t: float = float(i) / maxf(1.0, float(n - 1))
		var az: float = TreeGeometry.phyllotaxis(i + 131)
		var d: float = spec.canopy_radius * 0.55 * _h(i, 1, 0, 33)
		var y: float = lerpf(lo, spec.height * 0.97, pow(t, 0.85))
		if i == n - 1:
			y = spec.height * 0.97
		shapes.disc(Vector3(cos(az) * d, y, sin(az) * d),
			maxf(spec.canopy_radius * lerpf(0.17, 0.035, t)
				* (0.72 + 0.56 * _h(i, 0, 0, 32)), 0.02),
			TreeGeometry.SURF_GLOW, 8, Vector3.UP)

	_light(spec, Vector3(0.0, spec.canopy_base, 0.0), 2.9, spec.canopy_radius)
	_light(spec, Vector3(0.0, spec.height * 0.8, 0.0), 2.2,
		spec.canopy_radius * 0.8)


# -------------------------------------------------------------------- plumbing

## The stem polyline, as tubes. `base_scale` scales only the FIRST node's
## radius, which is the one the generator widened with the root flare: the
## worldtree draws its flare as buttress roots instead of as a collar, and
## passing the ratio there keeps the clearance promise intact without this file
## having to know why.
static func _stem(shapes: TreeShapes, spec: TreeSpec, surf: int, sides: int,
		base_scale := 1.0) -> void:
	var stem: Array[Dictionary] = TreeGeometry.stem_points(spec)
	for i in range(stem.size() - 1):
		var r0: float = float(stem[i]["r"]) * (base_scale if i == 0 else 1.0)
		shapes.tube(stem[i]["pos"], stem[i + 1]["pos"], r0,
			float(stem[i + 1]["r"]), surf, sides)


## Branches as tubes, between two levels, with their tips pulled back inside the
## promised radius. Level 0 is a primary and the last level is a twig, so the
## sides fall with the level: a twig drawn as a hexagonal prism is a twig made
## of scaffolding.
static func _tubes(spec: TreeSpec, shapes: TreeShapes, surf: int,
		first: int, last: int) -> void:
	for b in spec.branches:
		var lv: int = int(b["level"])
		if lv < first or lv > last:
			continue
		var from: Vector3 = b["from"]
		var to: Vector3 = _fit(spec, b["to"], float(b["r1"]))
		shapes.tube(from, to, float(b["r0"]), float(b["r1"]), surf,
			clampi(6 - lv, 3, 6))


## The branches a crown is hung on: the ones that have stopped subdividing.
static func _tips(spec: TreeSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in spec.branches:
		if int(b["level"]) >= spec.branch_levels:
			out.append(b)
	return out


## A closed faceted blob: an ellipsoid plus the disc that closes it.
##
## `TreeShapes.ellipsoid()` builds a lat/long grid whose polar rows collapse to
## a single point, and the quad between the last real ring and that point is
## wound from a duplicated pair of corners -- so it computes a zero normal and
## is dropped. The upper cap of every ellipsoid is therefore open, which on a
## plate means the whole top half is missing. This closes it with exactly the
## ring the dropped band would have had: the last row that is not a pole sits at
## cos(PI/rings) of the height and sin(PI/rings) of the radius, and a disc of
## that size there finishes the solid.
static func _blob(shapes: TreeShapes, centre: Vector3, r: float, hy: float,
		surf: int, rings: int, segs: int, rot := 0.0) -> void:
	shapes.ellipsoid(centre, Vector3(r, hy, r), surf, rings, segs, rot)
	shapes.disc(centre + Vector3.UP * (hy * cos(PI / float(rings))),
		r * sin(PI / float(rings)), surf, segs, Vector3.UP)


## The generator's clump size: the mean of the lobe radii it wrote. Every
## hand-authored crown above is built out of clumps of this size, so the
## generator still decides how coarse this tree's foliage is even where it does
## not decide where the clumps go.
static func _clump(spec: TreeSpec) -> float:
	var total := 0.0
	for lobe in spec.lobes:
		total += float(lobe["radius"])
	return maxf(total / maxf(1.0, float(spec.lobes.size())), 0.01)


## The crown as clump positions, culled.
##
## `spec.lobes` is one entry per branch TIP, and a magic broadleaf's generator
## leaves around two hundred and forty of them. Two hundred plates is noise at
## any distance a tree is seen from, and it is a mesh nobody could look at in a
## debugger. This greedy pass keeps the first lobe of every clump and drops the
## rest: a pure function of the spec's own ordering -- not a new decision about
## the tree, a decision about how much of it to draw.
static func _plates(spec: TreeSpec, clump: float, sep: float) -> Array[Dictionary]:
	var min_sep: float = maxf(clump * sep, 0.01)
	var out: Array[Dictionary] = []
	for lobe in spec.lobes:
		var p: Vector3 = lobe["pos"]
		var keep := true
		for q in out:
			if p.distance_to(q["pos"]) < min_sep:
				keep = false
				break
		if keep:
			out.append({"pos": p})
	return out


## Hold a crown element inside the radius the spec promised.
##
## `TreeCheck._rule_clearance` measures the furthest any vertex reaches from the
## trunk axis and holds it to `spec.canopy_radius`, and the generator's branch
## tips overshoot that promise by a third or more. A clump centre is pulled in
## until the clump's own edge lands on the promise; centres already inside it
## are untouched, so this trims outliers and leaves the shape alone.
static func _fit(spec: TreeSpec, pos: Vector3, r: float) -> Vector3:
	var lim: float = maxf(0.0, spec.canopy_radius - r)
	var d := Vector2(pos.x, pos.z)
	var l: float = d.length()
	if l <= lim or l <= 1e-5:
		return pos
	return Vector3(pos.x * lim / l, pos.y, pos.z * lim / l)


## A point on the stem polyline at height `y`, with the radius there. Read off
## `stem_points` rather than re-derived, so a glow core cannot drift off the
## trunk it is supposed to be inside.
static func _at_y(spec: TreeSpec, y: float) -> Dictionary:
	var stem: Array[Dictionary] = TreeGeometry.stem_points(spec)
	for i in range(stem.size() - 1):
		var a: Vector3 = stem[i]["pos"]
		var b: Vector3 = stem[i + 1]["pos"]
		if y <= b.y and b.y > a.y:
			var t: float = (y - a.y) / maxf(b.y - a.y, 1e-5)
			return {"pos": a.lerp(b, t),
				"r": lerpf(float(stem[i]["r"]), float(stem[i + 1]["r"]), t)}
	var last: int = stem.size() - 1
	return {"pos": stem[last]["pos"], "r": float(stem[last]["r"])}


## One light for the assembler to hang. `spec.glow_color` is the species' own
## colour -- the generator wrote it from the style table -- so a magic tree
## cannot light itself in the wrong hue.
static func _light(spec: TreeSpec, pos: Vector3, energy: float,
		range_m: float) -> void:
	spec.glow.append({"pos": pos, "colour": spec.glow_color,
		"energy": energy, "range": range_m})


## A stable 0..1 for index (i, j, k). The only source of variation in this file.
static func _h(i: int, j: int, k: int, salt: int) -> float:
	return TreeShapes.cell_hash(Vector3i(i, j, k), salt)
