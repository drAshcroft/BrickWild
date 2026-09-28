class_name TreeGenerator
extends RefCounted
## Fills a TreeSpec's derived fields from (style, species, height, seed), and
## writes the crown and the branch skeleton down as DATA.
##
## Every decision a builder could otherwise make at emit time is made here and
## clamped against `TreeGeometry`, for exactly the reason `ChurchGenerator`
## decides the aisle count: a builder that re-rolls a die while emitting blinds
## the QA suite to precisely the cases that forced the roll.
##
## So the crown is not "some blobs" by the time the builder runs -- it is
## `spec.lobes`, a list of {pos, radius, squash, kind} this class wrote, and
## `spec.branches`, a list of {from, to, r0, r1, level, phyl} likewise. The
## voxel stamper, the indie prisms, the natural tubes and `TreeCheck` all read
## those two lists. There is exactly one tree per (style, species, height,
## seed), and everybody agrees on what it is.

## Per style, the species it can make, and the proportions that make it that
## species rather than a generic tree. Every fraction is of `spec.height`, so a
## 4 m hedge tree and a 40 m veteran are the same tree at two sizes.
##
##   trunk_h   clear trunk, ground to first branch
##   trunk_r   trunk radius at the base
##   canopy_r  crown radius
##   lobe_h    crown height as a multiple of its radius -- a spruce is a tall
##             thin cone (~2), an oak is a squat ball (~0.85), an acacia flat
##             and wide (~0.4). One number is the whole silhouette.
##   branches  whorls of primary branches up the clear trunk
##   conifer   the crown is stacked skirts rather than blobs
const STYLES := {
	&"voxel": {
		&"oak": {"trunk_h": 0.34, "trunk_r": 0.020, "canopy_r": 0.30, "lobe_h": 0.80,
			"branches": 4, "conifer": false, "phyl": 0.62, "leaf": "4f7038", "bark": "6b5138"},
		&"birch": {"trunk_h": 0.46, "trunk_r": 0.012, "canopy_r": 0.20, "lobe_h": 0.95,
			"branches": 5, "conifer": false, "phyl": 0.78, "leaf": "86a84c", "bark": "cfc7b4"},
		&"spruce": {"trunk_h": 0.16, "trunk_r": 0.016, "canopy_r": 0.24, "lobe_h": 1.95,
			"branches": 6, "conifer": true, "phyl": 0.34, "leaf": "2f5730", "bark": "5a4630"},
		&"acacia": {"trunk_h": 0.44, "trunk_r": 0.015, "canopy_r": 0.36, "lobe_h": 0.42,
			"branches": 4, "conifer": false, "phyl": 0.52, "leaf": "6f8442", "bark": "7d6a4c"},
		&"willow": {"trunk_h": 0.30, "trunk_r": 0.022, "canopy_r": 0.28, "lobe_h": 0.72,
			"branches": 5, "conifer": false, "phyl": 0.85, "leaf": "7d9a4a", "bark": "6a5740"},
		&"palm": {"trunk_h": 0.72, "trunk_r": 0.013, "canopy_r": 0.24, "lobe_h": 0.30,
			"branches": 6, "conifer": false, "phyl": 1.05, "leaf": "5f8a3c", "bark": "8a7550"},
	},
	&"indie": {
		&"oak": {"trunk_h": 0.36, "trunk_r": 0.026, "canopy_r": 0.30, "lobe_h": 0.82,
			"branches": 4, "conifer": false, "phyl": 0.60, "leaf": "527f3a", "bark": "6d5339"},
		&"birch": {"trunk_h": 0.50, "trunk_r": 0.015, "canopy_r": 0.20, "lobe_h": 0.95,
			"branches": 5, "conifer": false, "phyl": 0.76, "leaf": "8fb04f", "bark": "d6cfbc"},
		&"poplar": {"trunk_h": 0.24, "trunk_r": 0.018, "canopy_r": 0.15, "lobe_h": 1.85,
			"branches": 5, "conifer": false, "phyl": 0.66, "leaf": "6b9247", "bark": "7d6a52"},
		&"willow": {"trunk_h": 0.28, "trunk_r": 0.024, "canopy_r": 0.30, "lobe_h": 0.70,
			"branches": 5, "conifer": false, "phyl": 0.88, "leaf": "84a24c", "bark": "6d5942"},
		&"pine": {"trunk_h": 0.14, "trunk_r": 0.018, "canopy_r": 0.22, "lobe_h": 2.10,
			"branches": 7, "conifer": true, "phyl": 0.32, "leaf": "35603a", "bark": "5f4a33"},
		&"dead": {"trunk_h": 0.40, "trunk_r": 0.020, "canopy_r": 0.12, "lobe_h": 0.60,
			"branches": 6, "conifer": false, "phyl": 1.25, "leaf": "000000", "bark": "8a8074"},
	},
	&"natural": {
		&"oak": {"trunk_h": 0.38, "trunk_r": 0.028, "canopy_r": 0.30, "lobe_h": 0.85,
			"branches": 4, "conifer": false, "phyl": 0.58, "leaf": "4e7536", "bark": "6a5138"},
		&"ash": {"trunk_h": 0.44, "trunk_r": 0.023, "canopy_r": 0.26, "lobe_h": 0.92,
			"branches": 4, "conifer": false, "phyl": 0.64, "leaf": "5c8442", "bark": "7b7566"},
		&"beech": {"trunk_h": 0.42, "trunk_r": 0.025, "canopy_r": 0.24, "lobe_h": 0.88,
			"branches": 4, "conifer": false, "phyl": 0.60, "leaf": "5f8a41", "bark": "9aa0a2"},
		&"hawthorn": {"trunk_h": 0.28, "trunk_r": 0.032, "canopy_r": 0.26, "lobe_h": 0.66,
			"branches": 5, "conifer": false, "phyl": 0.94, "leaf": "4a6f3c", "bark": "5f4c3a"},
		&"pine": {"trunk_h": 0.12, "trunk_r": 0.019, "canopy_r": 0.23, "lobe_h": 2.20,
			"branches": 7, "conifer": true, "phyl": 0.30, "leaf": "2f5c35", "bark": "5c4830"},
		&"willow": {"trunk_h": 0.30, "trunk_r": 0.025, "canopy_r": 0.29, "lobe_h": 0.74,
			"branches": 5, "conifer": false, "phyl": 0.86, "leaf": "7f9c48", "bark": "685540"},
	},
	&"magic": {
		&"worldtree": {"trunk_h": 0.44, "trunk_r": 0.062, "canopy_r": 0.42, "lobe_h": 0.62,
			"branches": 5, "conifer": false, "phyl": 0.50, "leaf": "3f6f3a", "bark": "6b5a42",
			"glow": "9fe0c0"},
		&"crystal": {"trunk_h": 0.30, "trunk_r": 0.030, "canopy_r": 0.26, "lobe_h": 1.30,
			"branches": 5, "conifer": true, "phyl": 0.72, "leaf": "6d5a9c", "bark": "4a4468",
			"glow": "c8a8ff"},
		&"inverted": {"trunk_h": 0.34, "trunk_r": 0.034, "canopy_r": 0.30, "lobe_h": 0.80,
			"branches": 5, "conifer": false, "phyl": 0.82, "leaf": "3a6a52", "bark": "5a4c44",
			"glow": "7fe0b0"},
		&"floating": {"trunk_h": 0.10, "trunk_r": 0.030, "canopy_r": 0.32, "lobe_h": 0.70,
			"branches": 5, "conifer": false, "phyl": 0.74, "leaf": "4a7a48", "bark": "6b5f4e",
			"glow": "b8d8ff"},
		&"weeping": {"trunk_h": 0.40, "trunk_r": 0.032, "canopy_r": 0.32, "lobe_h": 0.66,
			"branches": 6, "conifer": false, "phyl": 0.90, "leaf": "547a62", "bark": "5f5344",
			"glow": "9fd4e8"},
		&"ember": {"trunk_h": 0.46, "trunk_r": 0.028, "canopy_r": 0.20, "lobe_h": 0.90,
			"branches": 5, "conifer": false, "phyl": 1.05, "leaf": "000000", "bark": "3a2a22",
			"glow": "ff9a44"},
	},
}

## The kinds that carry no foliage at all. A flag, not a colour with zero
## alpha: some later consumer will happily multiply an alpha-0 green into an
## opaque black and hand you a dead tree that is somehow still black-leaved.
const LEAFLESS := [&"dead", &"ember"]


static func generate(spec: TreeSpec, p_seed: int) -> void:
	spec.seed = p_seed
	spec.rng.seed = p_seed
	if not STYLES.has(spec.style):
		spec.style = &"natural"
	if not STYLES[spec.style].has(spec.species):
		spec.species = STYLES[spec.style].keys()[0]
	var s: Dictionary = STYLES[spec.style][spec.species]
	var r := spec.rng

	spec.height = clampf(spec.height, TreeGeometry.HEIGHT_MIN, TreeGeometry.HEIGHT_MAX)

	# --- the trunk, fitted to the height the caller locked ---
	spec.trunk_height = spec.height * float(s["trunk_h"])
	spec.canopy_base = spec.trunk_height
	spec.canopy_top = spec.height
	spec.leafless = spec.species in LEAFLESS
	spec.root_flare = r.randf_range(0.35, 0.85)
	spec.trunk_radius = maxf(spec.height * float(s["trunk_r"]), TreeGeometry.TRUNK_R_MIN)
	spec.canopy_radius = maxf(spec.height * float(s["canopy_r"]),
		spec.trunk_radius * TreeGeometry.CANOPY_OVER_TRUNK)
	spec.lean = r.randf_range(0.02, 0.11) * (0.4 if spec.leafless else 1.0)
	# TWO branch levels, not three. Three put a hundred and twenty-eight clumps
	# in an oak's crown -- a tree made of confetti, four shells deep, forty
	# thousand triangles and forty seconds for something that reads as a hedge.
	# Two gives sixty-four tips, which is still a lot of crown and is a tree.
	spec.branch_levels = 2

	# `trunk_clear` is the measure SceneBounds takes at or below TRUNK_HEIGHT.
	# Written here rather than left to the builder, because this is the number
	# a village clearance test will compare a generated tree against, and the
	# promise has to be the one the builder then has to keep.
	#
	# Three things claim that band. The flare at the root. The ROOTS, which
	# splay out from the foot and are exactly what a person walks into, and
	# which, measured at 0.86 m against a promised 0.34 m, were the single
	# biggest clearance failure the first sweep found. And, for four of the six
	# kinds, the crown itself: a rune circle, a dome below the ground, a curtain
	# that reaches it, vines under a floating island. `TreeGeometry.
	# TRUNK_CLAIM` is what makes the promise true for those last four instead
	# of exempting them from the rule that holds every other tree.
	spec.trunk_clear = maxf(
		spec.trunk_radius * (1.0 + spec.root_flare),
	TreeGeometry.root_spread(spec))
	spec.trunk_clear = maxf(spec.trunk_clear,
		spec.canopy_radius * float(TreeGeometry.TRUNK_CLAIM.get(spec.species, 0.0)))
	spec.block = _block_for(spec, r)

	# --- the skeleton and the crown, as data ---
	#
	# `_fit` runs FIRST, and that ordering is the contract rather than a
	# detail. It lifts a tree too short to hold its own crown, which moves
	# `canopy_base` -- and `TreeGeometry.stem_points` reads `canopy_base`, so a
	# skeleton grown before the fit starts its branches from a stem that no
	# longer exists, and the SKELETON rule duly found branch tips hanging in
	# mid-air beside the trunk. Decide the trunk, then grow into it.
	_fit(spec)
	_grow_skeleton(spec, s, r)
	_grow_crown(spec, s, r)
	_refit_crown(spec)
	_claim_head_room(spec)

	# --- palette ---
	spec.bark_color = Color(s["bark"]).lerp(Color(s["bark"]).lightened(0.22), r.randf())
	spec.leaf_color = Color(s["leaf"]).lerp(Color(s["leaf"]).lightened(0.18), r.randf())
	spec.accent_color = spec.leaf_color.lerp(spec.bark_color, 0.45)
	spec.glow_color = Color(s.get("glow", "bfe6ff"))

	spec.variant_name = _name(spec, r)


## A voxel tree is only a voxel tree at certain sizes. Too fine and the crown
## is a cloud of cubes whose silhouette is noise; too coarse and an oak is a
## lollipop on a stick. A quarter of the canopy radius is the sweet spot, and
## the height cap stops a 40 m spruce from buying 200 cells across.
static func _block_for(spec: TreeSpec, r: RandomNumberGenerator) -> float:
	var target: float = spec.canopy_radius * 0.24 * r.randf_range(0.85, 1.2)
	var coarse: float = spec.height / 44.0
	return clampf(target, 0.18, maxf(0.18, minf(1.2, coarse)))


## The branch skeleton: whorls up the clear trunk, each branch subdividing
## `branch_levels` times with phyllotactic azimuths and gravity tropism.
## Written to `spec.branches` and never recomputed downstream.
static func _grow_skeleton(spec: TreeSpec, s: Dictionary, r: RandomNumberGenerator) -> void:
	spec.branches = []
	var stem: Array[Dictionary] = TreeGeometry.stem_points(spec)
	var whorls: int = int(s["branches"])
	var conifer: bool = bool(s["conifer"])
	for w in range(whorls):
		var t: float = float(w + 1) / float(whorls + 1)
		# Take the base node off the stem polyline rather than recomputing it,
		# so a branch cannot start somewhere the stem does not pass through.
		var base: Vector3 = stem[int(t * float(stem.size() - 1))]["pos"]
		var stem_r: float = spec.trunk_radius * lerpf(1.0, 0.62, t)
		# A conifer carries branches all the way up; a broadleaf carries them on
		# the lower half and gives the rest of the stem to the crown.
		var top_bias: float = 1.0 if conifer else lerpf(0.55, 1.0, t)
		var count: int = 5 if spec.style == &"voxel" else 4
		for k in range(count):
			var az: float = TreeGeometry.phyllotaxis(w * count + k)
			var lift: float = spec.branch_angle * r.randf_range(0.7, 1.25)
			var dir := Vector3(sin(az) * cos(lift), sin(lift) * 0.55,
				cos(az) * cos(lift)).normalized()
			var reach: float = spec.canopy_radius * lerpf(0.30, 0.86, top_bias) \
				* r.randf_range(0.8, 1.2)
			_add_branch(spec, base, dir, reach, stem_r * 0.42, 0, r)


static func _add_branch(spec: TreeSpec, from: Vector3, dir: Vector3, reach: float,
		r0: float, level: int, r: RandomNumberGenerator) -> void:
	# Tropism: a branch climbs as it goes, less so at every level. A branch
	# that stays horizontal for its whole length is a stick.
	var lift: float = lerpf(0.55, 0.05, float(level) / 3.0)
	var end: Vector3 = from + dir.lerp(Vector3.UP, lift).normalized() * reach
	if end.y < from.y:
		end.y = from.y + reach * 0.18
	spec.branches.append({
		"from": from, "to": end, "r0": r0,
		"r1": r0 * spec.branch_decay, "level": level,
		"phyl": TreeGeometry.phyllotaxis(spec.branches.size())})
	if level >= spec.branch_levels:
		return
	for k in range(2):
		# Turn the parent direction about Y by the golden angle, then lift it.
		# Rotating rather than offsetting keeps every child genuinely inside its
		# parent's cone, so a subtree stays a subtree.
		var az: float = TreeGeometry.phyllotaxis(spec.branches.size() * 3 + k)
		var turned := dir.rotated(Vector3.UP, az - float(k) * 0.7)
		var d2: Vector3 = (turned + Vector3.UP * (0.30 - 0.08 * float(level))).normalized()
		_add_branch(spec, end, d2, reach * r.randf_range(0.48, 0.66),
			r0 * spec.branch_decay, level + 1, r)


## The crown: one blob per branch tip for a broadleaf, a stack of skirts for a
## conifer. `leaf_density` carries the species' crown height-to-radius ratio,
## so a spruce is tall and thin and an acacia is flat and wide from one code.
static func _grow_crown(spec: TreeSpec, s: Dictionary, r: RandomNumberGenerator) -> void:
	spec.lobes = []
	if bool(s["conifer"]):
		_grow_conifer_crown(spec, r)
		return
	var tips: Array[Vector3] = []
	for b in spec.branches:
		if int(b["level"]) >= spec.branch_levels:
			tips.append(b["to"])
	# A broadleaf with no usable tip -- a dead tree, or a level count of one --
	# still needs a crown or validate() rejects the spec. Fall back to a whorl
	# on the stem's own top rather than inventing branches here.
	if tips.is_empty():
		var stem: Array[Dictionary] = TreeGeometry.stem_points(spec)
		tips.append(stem[stem.size() - 1]["pos"])
	# How big each clump is, and how far out the tip it sits on.
	#
	# The clumps have to OVERLAP. A crown sized so that neighbouring tips just
	# touch is not a crown: it is a cloud of separate blobs with sky between
	# them, which is exactly what the first render pass produced -- three flat
	# green slabs on an oak, a gap you could see the horizon through on a pine.
	# A lobe's radius is therefore about a quarter of the whole crown, not a
	# fraction of the spacing between tips, and the tips are pulled INWARD to
	# make room, so tip + clump still lands inside the envelope the spec
	# promised. Sizing for packing (R/cbrt(n)) and then drawing what you sized is
	# the mistake; the envelope is the promise and the crown is fitted into it.
	var count: int = maxi(1, tips.size())
	var spread: float = maxf(spec.canopy_radius * 0.30,
		spec.canopy_radius * 1.15 / pow(float(count), 1.0 / 3.0))
	spread = maxf(spread, spec.block * 1.1)
	# Far enough in that the LARGEST drawn lobe still lands inside the envelope:
	# a tip at `reach_in` plus a lobe of `spread * 1.18` is `canopy + 0.33 *
	# spread`, which overshot the promise by 7 cm on every species in the first
	# sweep. Pull by the lobe's own maximum, not by a fraction of it.
	var reach_in: float = maxf(spec.canopy_radius - spread * 1.25, 0.0)
	# STRETCH the crown to fill the height it was promised.
	#
	# Every branch tip lands at much the same height -- the branches leave the
	# clear trunk with a small lift and stop when they have spent their reach --
	# so the crown is a thick disc floating a third of the way up a tall tree,
	# and `canopy_base`/`height` describe an envelope the crown ignores. Scaling
	# the tips' HEIGHTS (never their radius, never their azimuth) opens the
	# crown out to the full vertical space it was allotted, which is what makes
	# a 12 m oak fill 12 m and a 26 m hawthorn not look like a bush on a pole.
	#
	# A LEADER was tried here first and is the wrong tool: put on the stem's top
	# it is a single blob with a metre of daylight under it, and pinning it to
	# the promised height just moves the gap above the crown instead of below.
	var sq_mid: float = spec.leaf_density
	var have: float = -INF
	for t in tips:
		have = maxf(have, t.y + spread * sq_mid)
	var want: float = spec.height - spread * sq_mid
	var floor_y: float = spec.canopy_base
	if have > floor_y + 0.01 and have < want - 0.01:
		var k: float = (want - floor_y) / (have - floor_y)
		for t in tips:
			t.y = floor_y + (t.y - floor_y) * k
	for tip in tips:
		var flat := Vector2(tip.x, tip.z)
		if flat.length() > reach_in and flat.length() > 0.001:
			flat = flat.normalized() * reach_in
		var squash: float = spec.leaf_density * r.randf_range(0.85, 1.1)
		spec.lobes.append({
			"pos": Vector3(flat.x, tip.y + spread * squash * 0.5, flat.y),
			"radius": spread * r.randf_range(0.88, 1.18),
			"squash": squash,
			"kind": &"crown"})
	# Then FIT, by measuring what was actually built. Predicting the top from the
	# mean radius and the mean squash undershoots every time, because both are
	# jittered, and a 3 m oak stopped at 2.47 m. One shift, measured, is the
	# whole correction; scaling would distort a crown that is already the right
	# shape.
	var built: float = -INF
	for lobe in spec.lobes:
		built = maxf(built, _lobe_top(lobe))
	var shift: float = spec.height - built
	if absf(shift) > 0.01:
		for lobe in spec.lobes:
			lobe["pos"].y += shift


static func _grow_conifer_crown(spec: TreeSpec, r: RandomNumberGenerator) -> void:
	var tiers: int = clampi(int(spec.trunk_radius * 40.0), 5, 11)
	# A voxel conifer wants its skirt low, almost on the ground: the stepped
	# cone is the whole identity. A modelled one wants air under it.
	var base_y: float = spec.canopy_base * (0.35 if spec.style == &"voxel" else 0.15)
	# The tier pitch. Every tier has to be TALLER than the gap to the next one
	# or the stack is a set of separate discs with air between them, and the
	# SUPPORTED rule -- and the eye -- both call that a broken tree. The pitch
	# is known before the loop precisely so each tier can be sized against it.
	var pitch: float = (spec.height - base_y) / float(maxi(tiers - 1, 1))
	for i in range(tiers):
		var t: float = float(i) / float(tiers - 1)
		# Widest a third of the way up, tapering to a point: the silhouette that
		# reads as a conifer at any distance and any size.
		# A conifer tapers to a POINT, which is a statement about the last tier
		# and not about all of them. Letting the profile run to 8% of the crown
		# put the top three tiers inside one another's width and the tree ended
		# in a needle as thin as a pencil. The taper stops at a tenth, and the
		# squash below is capped, so the tip is a cone and not a wire.
		var width: float = spec.canopy_radius * (1.0 - absf(t - 0.28) / 0.78)
		width = maxf(width, maxf(spec.canopy_radius * 0.11, spec.block * 0.8))
		# A tier has to be TALLER than the gap to the next one or the stack is a
		# column of separate discs with daylight between them -- the pine render
		# was five green plates and a floating cube. The half-height is set to
		# almost the whole pitch, so consecutive tiers overlap by roughly their
		# own depth and the silhouette closes into a cone.
		spec.lobes.append({
			"pos": Vector3(0.0, lerpf(base_y, spec.height, t), 0.0),
			"radius": width,
			"squash": clampf(pitch * 0.95 / maxf(width, 0.01), 0.30, 2.2),
			"kind": &"skirt"})


## The TRUNK fit, and it runs before anything is grown.
##
## A tree too short to hold its own crown has the crown lifted until it fits,
## and `floating` -- the one magic kind that does not touch the ground -- is
## raised by its own clearance. Both of those move `canopy_base`, which
## `TreeGeometry.stem_points` reads, so this has to happen before the skeleton
## is grown or every branch starts from a stem that no longer exists.
static func _fit(spec: TreeSpec) -> void:
	var room: float = TreeGeometry.CROWN_MIN_FRACTION * spec.height
	if spec.canopy_base < room:
		spec.canopy_base = room
		spec.trunk_height = room
	if not TreeGeometry.is_rooted(spec):
		spec.canopy_base = maxf(spec.canopy_base,
			TreeGeometry.ground_clearance(spec))
		spec.trunk_height = spec.canopy_base
	spec.canopy_top = spec.height


## The CROWN fit, and it runs after the crown exists.
##
## Two jobs. A crown that escapes the height it was promised is trimmed; a
## crown that falls short of it is LIFTED, because a 12 m oak whose foliage
## stopped at 9.3 m reads as a tree that has been cut back, and the FITTED
## rule is right to complain. The lift is a leader -- the highest lobe is
## raised to close the last of the gap and the ones under it follow by the
## same amount, so the crown keeps its shape instead of stretching.
static func _refit_crown(spec: TreeSpec) -> void:
	if spec.lobes.is_empty():
		return
	var top: float = -INF
	for lobe in spec.lobes:
		top = maxf(top, _lobe_top(lobe))
	if top > spec.height:
		var drop: float = top - spec.height
		for lobe in spec.lobes:
			lobe["pos"].y -= drop
	# A crown that falls SHORT is not hauled upward here. `_grow_crown` now
	# puts a leader on the stem's top so the crown reaches the promised height by
	# construction; lifting the whole crown after the fact is what left a
	# conifer's tip cube hanging in the sky.
	spec.canopy_top = spec.height


## The TOP of a lobe: `squash` multiplies, so this is radius times it, which
## is what `TreeGeometry.in_lobe` measures. (It divided, once, and the crown
## was fitted against an envelope twice the wrong size.)
## Fold whatever hangs into the head-height band into the clearance promise.
##
## Called where the lobes exist, because that is the only place the question can
## be answered. A 3 m oak is mostly crown, and a spruce's lowest tier starts
## below 1.8 m, so at that height the "trunk" measurement is measuring FOLIAGE;
## the promise has to say so or every short or coniferous tree fails its own
## clearance rule for having a low crown, which is what those trees are.
static func _claim_head_room(spec: TreeSpec) -> void:
	var deepest: float = 0.0
	for lobe in spec.lobes:
		var c: Vector3 = lobe["pos"]
		var half: float = float(lobe["radius"]) * maxf(float(lobe["squash"]), 0.05)
		if c.y - half < TreeGeometry.TRUNK_HEIGHT:
			deepest = maxf(deepest, Vector2(c.x, c.z).length() + float(lobe["radius"]))
	# The BRANCHES, which is where most of the surprise was. A nine-metre oak
	# with a clear trunk of three and a half metres has a whorl of branches at
	# sixty centimetres: you cannot walk under it, and `trunk_clear` said half a
	# metre. Every clearance failure that was left after the crown was folded in
	# was a branch, and a branch is exactly as much of an obstacle as a root.
	for branch in spec.branches:
		var a: Vector3 = branch["from"]
		var b: Vector3 = branch["to"]
		# `minf`, not `maxf`. A branch from 1.5 m to 2.0 m has BOTH endpoints
		# near or above the band and the middle of it in the band, and a test
		# on the endpoints waved that one through -- which is how two seeds of
		# one species ended up promising 0.72 m and 0.25 m while measuring the
		# same metre.
		if minf(a.y, b.y) >= TreeGeometry.TRUNK_HEIGHT:
			continue
		deepest = maxf(deepest, maxf(Vector2(a.x, a.z).length(),
			Vector2(b.x, b.z).length()) + float(branch["r0"]))
	# A voxel tree is quantised: a cell's face sits half a block outside the
	# lobe that filled it, and the band measures FACES.
	deepest += spec.block * 0.5 if spec.style == &"voxel" else 0.0
	spec.trunk_clear = maxf(spec.trunk_clear, deepest)


## How far the crown hangs into the head-height band, in metres -- zero for a
## tree whose crown is well clear of it.
##
## A 3 m oak is mostly crown: `canopy_base` is 1.14 m and the foliage hangs below
## that, so at `TRUNK_HEIGHT` the "trunk" measurement is measuring LEAVES. The
## promise has to say so, or every short tree in the family fails its own
## clearance rule for having a low crown, which is what an oak is.
static func _crown_dip(spec: TreeSpec) -> float:
	var low: float = INF
	for lobe in spec.lobes:
		low = minf(low, _lobe_top(lobe) - 2.0 * float(lobe["radius"])
			* maxf(float(lobe["squash"]), 0.05))
	if low >= TreeGeometry.TRUNK_HEIGHT:
		return 0.0
	var deepest: float = 0.0
	for lobe in spec.lobes:
		var c: Vector3 = lobe["pos"]
		var rad: float = Vector2(c.x, c.z).length()
		if c.y - float(lobe["radius"]) * maxf(float(lobe["squash"]), 0.05) \
				< TreeGeometry.TRUNK_HEIGHT:
			deepest = maxf(deepest, rad)
	return deepest


static func _lobe_top(lobe: Dictionary) -> float:
	var pos: Vector3 = lobe["pos"]
	return pos.y + float(lobe["radius"]) * maxf(float(lobe["squash"]), 0.05)


static func _name(spec: TreeSpec, r: RandomNumberGenerator) -> String:
	if spec.style == &"magic":
		return String(TreeGeometry.MAGIC_TITLES.get(spec.species,
			String(spec.species).capitalize()))
	return "%s %s" % [
		TreeGeometry.FIRST_WORDS[r.randi() % TreeGeometry.FIRST_WORDS.size()],
		TreeGeometry.SECOND_WORDS[r.randi() % TreeGeometry.SECOND_WORDS.size()]]
