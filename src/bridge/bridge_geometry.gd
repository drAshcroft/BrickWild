class_name BridgeGeometry
extends RefCounted
## Single source of truth for a bridge's massing AND for the ground it stands on.
##
## Same contract as ChurchGeometry / CastleGeometry / TreeGeometry: the builder
## that emits the mesh, the render tool that builds the terrain, and the check
## that judges the result all read these numbers. A bridge is the case where
## that matters most, because the structure and the site are two separate
## things that have to agree, and the only way they can agree is if one function
## owns both.
##
## Model axes: +X along the span, +Y up, +Z across. y = 0 is the water.

# ---- hard limits ----
const SPAN_MIN := 4.0
const SPAN_MAX := 400.0
const WIDTH_MIN := 1.4
const WIDTH_MAX := 24.0
## A deck has to stand clear of the water, or it is a wet plank.
const DECK_CLEAR_MIN := 0.35
## And a pier has to be narrower than the span it divides, or there is no span.
const PIER_MAX_FRACTION := 0.42

## How far below the top of the bank an abutment's footing goes. Deep enough to
## be believable, shallow enough to be inside the bank the site provides.
const FOOTING := 2.2
## How far the abutment spreads out sideways, as a multiple of its thickness.
const ABUT_SPREAD := 2.1

# ------------------------------------------------------------------ the site

## The GROUND. Everything on the outside of the span, and the single function
## that decides where a bridge's feet go, where the render tool puts its banks,
## and whether a span is even buildable.
##
## A flat shelf at `bank_height` with a straight batter down to the water at
## `|x| = span/2 + bank_run`. Deliberately not noise: a bank with bumps on it
## has abutments that float in front of it or bury themselves in it, and a
## bridge that does not meet its ground is the one thing this family cannot be
## allowed to do.
static func bank_height_at(spec: BridgeSpec, x: float) -> float:
	var half: float = spec.span * 0.5
	var a: float = absf(x)
	var edge: float = half
	var toe: float = half + maxf(spec.bank_run, 0.5)
	if a <= edge:
		return spec.bank_height
	if a >= toe:
		return spec.water_level
	var t: float = (a - edge) / (toe - edge)
	return lerpf(spec.bank_height, spec.water_level, t * t * (3.0 - 2.0 * t))


## Whether an x is over open water, which is what a pier may stand in and what
## a channel must stay clear of.
static func is_over_water(spec: BridgeSpec, x: float) -> bool:
	return absf(x) < spec.span * 0.5


## The widest clear channel under the deck: the biggest gap between the
## INNER FACES of two supports, which is what a boat needs and what a
## navigation rule wants as a number.
##
## Measuring it from the centreline instead -- the obvious thing, and wrong --
## treats a single pier standing on the centreline as a pier on BOTH banks at
## once, reports a channel of zero, and fails every stone bridge and every
## covered bridge in the family. A pier in the middle of a river is the one
## thing that makes a bridge crossable.
static func channel_width(spec: BridgeSpec) -> float:
	# The ABUTMENTS are the outer boundary of the channel, not an absence in
	# it. Leaving them out left a one-arch bridge with a single face and no
	# gap, which is a channel of zero -- the same answer, for the opposite
	# reason, as counting a centreline pier twice.
	var faces: Array[float] = [spec.span * 0.5, -spec.span * 0.5]
	for p in spec.piers:
		var x: float = float(p["x"])
		var hw: float = float(p["w"]) * 0.5
		if p["kind"] == &"abutment":
			if x > 0.0:
				faces.append(x - hw)
			else:
				faces.append(x + hw)
			continue
		faces.append(x - hw)
		faces.append(x + hw)
	faces.sort()
	var best: float = 0.0
	for i in range(faces.size() - 1):
		best = maxf(best, faces[i + 1] - faces[i])
	return maxf(best, 0.0)


# ------------------------------------------------------------------ the deck

## The walking surface at x. Flat for covered, rope and mobile; a CAMBER for
## stone, because a masonry arch bridge's roadway rises over the crown and a
## dead-level one reads as a plank laid on top of an arch rather than as a road
## carried by it.
static func deck_height_at(spec: BridgeSpec, x: float) -> float:
	if spec.kind != &"stone":
		return spec.deck_height
	var half: float = spec.span * 0.5
	var t: float = clampf(x / maxf(half, 0.01), -1.0, 1.0)
	# A shallow circular segment, not a parabola: a raised cosine over the
	# half-span gives a crown at midspan that falls away at a constant-ish slope,
	# which is what an arch road does and what a parabola's sharp peak does not.
	return spec.deck_height + spec.camber * (1.0 - t * t)


## The underside of the deck slab.
static func deck_soffit(spec: BridgeSpec, x: float) -> float:
	return deck_height_at(spec, x) - spec.deck_thickness


## How far the abutment's wall face sits in from the end of the span.
static func abutment_inset(spec: BridgeSpec) -> float:
	return maxf(spec.pier_width, 1.0)


# ------------------------------------------------------------------ arches

## The intrados of a masonry arch of clear span `s` springing at height `y0`:
## a semicircle, so at the springing the arch is vertical and at the crown it is
## horizontal, and the deck above it is pushed UP by exactly the radius. That
## relationship is why a masonry arch bridge humps and a beam bridge does not.
static func arch_intrados(s: float, y0: float, x_centre: float) -> Array[Dictionary]:
	var r: float = s * 0.5
	var out: Array[Dictionary] = []
	var steps: int = 12
	for i in range(steps + 1):
		var a: float = PI * float(i) / float(steps)
		var x: float = x_centre - cos(a) * r
		var y: float = y0 + sin(a) * r
		out.append({"x": x, "y": y})
	return out


# ------------------------------------------------------------------ cables

## The main cable of a suspension bridge, as a PARABOLA.
##
## A catenary is the true curve of a hanging chain, and a catenary is also
## almost never what a bridge is built to: the engineer chooses the sag, the
## deck load and the tower height, and the curve that results is a parabola.
## Using a catenary here is the classic tell of a rope bridge modelled by
## somebody who thought about gravity and not about engineering -- it puts the
## cable's low point off midspan and the hangers stop lining up with the deck.
##
## `t` runs -1..1 across the span; the cable meets the tower tops at the ends
## and hangs `sag` at midspan.
static func cable_height_at(spec: BridgeSpec, t: float) -> float:
	var tower_top: float = spec.deck_height + spec.tower_height
	return tower_top - spec.cable_sag * (1.0 - t * t)


static func cable_point(spec: BridgeSpec, t: float) -> Vector3:
	var half: float = spec.span * 0.5
	return Vector3(t * half, cable_height_at(spec, t), 0.0)


## The point on the CABLE directly above a deck station, for a hanger. Taken
## from the same function as the cable itself, so a hanger can never end in
## mid-air beside the cable it is supposed to hang from.
static func hanger_top(spec: BridgeSpec, x: float) -> Vector3:
	var half: float = spec.span * 0.5
	var t: float = clampf(x / maxf(half, 0.01), -1.0, 1.0)
	return Vector3(x, cable_height_at(spec, t), 0.0)


# ------------------------------------------------------------------ promises

## How tall the TALLEST THING this kind puts above the roadway.
##
## A bridge is not its deck. A suspension bridge's tower and a covered bridge's
## ridge are the silhouette, and a box sized to the deck alone is a box that
## cuts off the two things anybody came to look at -- which is how the first
## envelope pass failed nine times on a covered bridge with a perfectly good
## roof on it.
static func crown_height(spec: BridgeSpec) -> float:
	match spec.kind:
		&"covered":
			# The eaves, then the ridge above them.
			return spec.roof_rise + spec.width * spec.roof_pitch * 0.5 + 0.3
		&"rope":
			return spec.tower_height + 0.5
		&"mobile":
			# A swing's boom stands up as it swings clear, and a lift's ropes run
			# the full height of its towers. The box has to hold the mechanism in
			# the position it is DRAWN in, which is the open one.
			if spec.motion == &"swing":
				return maxf(spec.tower_height, 0.3 + spec.travel * 0.25) + 0.5
			return spec.tower_height + 0.5
		_:
			return spec.parapet_height + 0.4


## The box the bridge is allowed to occupy. The AABB the CHECK measures the mesh
## against, and the target the BUILDER corrects to -- an envelope is a
## post-condition of a builder, not a prediction of a generator, because a
## generator cannot know that a cable will overshoot its tower by a hand's
## breadth.
static func expected_extent(spec: BridgeSpec) -> AABB:
	var half: float = spec.span * 0.5
	# The wing walls splay back into the bank, so the structure is legitimately
	# longer than the span it crosses.
	var wings: float = minf(spec.bank_run * 0.5, spec.span * 0.10) + spec.pier_width
	# A pontoon's DRAUGHT is below the waterline and is part of the bridge, so
	# the box has to reach under the water for it. A box that stops at the
	# surface fails the floating bridge for doing the one thing a pontoon does.
	# FOUNDATIONS. A pier is carried down below the water and an abutment is
	# carried into the bank, and a box that stops at the waterline fails every
	# bridge in the family for the one thing they all do. A pontoon's draught
	# is deeper still and sits in the same place.
	var below: float = spec.water_level - FOOTING * 0.5
	if spec.kind == &"mobile" and spec.motion == &"pontoon":
		below = minf(below, spec.water_level - spec.pontoon_draft * 1.6)
	var lo := Vector3(-half - wings, below, -spec.width * 0.5)
	var hi := Vector3(half + wings,
		spec.deck_height + spec.camber + crown_height(spec),
		spec.width * 0.5)
	return AABB(lo, hi - lo)


## How far a drawing may reach outside the box before the fit touches it.
## The same idea as `TreeGeometry.DRAW_ALLOWANCE`, and the reason is the same.
const DRAW_ALLOWANCE := 0.06


static func validate(spec: BridgeSpec) -> Array[String]:
	var bad: Array[String] = []
	if spec.span < SPAN_MIN or spec.span > SPAN_MAX:
		bad.append("span %.1f m is outside %.0f..%.0f"
			% [spec.span, SPAN_MIN, SPAN_MAX])
	if spec.width < WIDTH_MIN or spec.width > WIDTH_MAX:
		bad.append("width %.2f m is outside %.1f..%.1f"
			% [spec.width, WIDTH_MIN, WIDTH_MAX])
	if spec.deck_height - spec.water_level < DECK_CLEAR_MIN:
		bad.append("the deck is %.2f m above the water; a deck has to stand clear of it"
			% (spec.deck_height - spec.water_level))
	if spec.pier_width >= spec.span * PIER_MAX_FRACTION:
		bad.append("a %.2f m pier in a %.1f m span leaves no arch" % [spec.pier_width, spec.span])
	if spec.piers.is_empty():
		bad.append("no piers: a bridge needs something at each end")
	if spec.deck.size() < 2:
		bad.append("no deck")
	if spec.kind == &"rope" and spec.tower_height <= 0.0:
		bad.append("a rope bridge with no towers is a rope")
	if spec.kind == &"covered" and spec.roof_rise <= 0.0:
		bad.append("a covered bridge with no roof is a bridge with a lidless shed")
	return bad


## The ENVELOPE IS A POST-CONDITION OF A BUILDER, not a prediction of a
## generator.
##
## The same lesson the tree family learned at great expense and the reason it
## is written down the FIRST time here. `expected_extent` is a promise the
## check holds the mesh to, and a generator cannot know what its emitters will
## draw: a wing wall splays further than the abutment it grows from, a voussoir
## ring thickens towards the crown, a cable overshoots its tower by a hand's
## breadth. Predicting those and failing on the difference is how a check ends
## up firing on geometry that is correct.
##
## So the mesh is corrected after it exists, once, uniformly about the bridge's
## own centre. A five per cent squeeze is invisible; a bridge that genuinely
## overran its box by a third is a different shape and deserves to be one.
static func fit_mesh(mesh: ArrayMesh, spec: BridgeSpec) -> ArrayMesh:
	var want: AABB = expected_extent(spec)
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for surface in range(mesh.get_surface_count()):
		var vs: PackedVector3Array = \
			mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for v in vs:
			lo = lo.min(v)
			hi = hi.max(v)
	if lo.x > hi.x:
		return mesh
	var k: Vector3 = Vector3.ONE
	# Scale about the BOX's centre, not the mesh's. Scaling about the mesh's own
	# middle makes it the right SIZE and leaves it in the wrong PLACE, so a
	# bridge whose masonry ran two metres above its crown stayed two metres
	# above it after being "fitted", and the envelope rule failed all twenty-one
	# of them.
	var pivot: Vector3 = want.get_center()
	for axis in range(3):
		var span: float = hi[axis] - lo[axis]
		if span <= 1e-4:
			continue
		var room: float = want.size[axis]
		if room <= 1e-4:
			continue
		# Only ever SHRINK. A bridge that is smaller than its box is a small
		# bridge, not a broken one -- the same argument the tree family's
		# clearance rule makes, and for the same reason.
		# AT the box, not at the box plus the allowance. The rule allows a small
		# tolerance ON TOP of a correct fit; aiming the fit at the tolerance as
		# well is how a builder ships geometry its own check rejects, which is
		# what happened for every tall covered bridge in the first sweep.
		if span > room:
			k[axis] = room / span
	if k.is_equal_approx(Vector3.ONE):
		return mesh
	# Scale AND SEAT. A scale about the pivot leaves the middle where it was,
	# so a mesh that is the right HEIGHT and sitting three metres low is
	# untouched by a size-only fit -- and fails the very rule it was just
	# corrected for. On each clamped axis the scaled mesh is then moved so its
	# minimum lands on the box's minimum, because a bridge sits ON its site
	# rather than floating in the middle of the room the box makes for it.
	var shift := Vector3.ZERO
	for axis in range(3):
		if k[axis] >= 1.0:
			continue
		var scaled_lo: float = pivot[axis] + (lo[axis] - pivot[axis]) * k[axis]
		shift[axis] = want.position[axis] - scaled_lo
	var out := ArrayMesh.new()
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface).duplicate(true)
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in range(vs.size()):
			vs[i] = pivot + (vs[i] - pivot) * k + shift
		arrays[Mesh.ARRAY_VERTEX] = vs
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(surface), arrays)
		out.surface_set_material(surface, mesh.surface_get_material(surface))
		out.surface_set_name(surface, mesh.surface_get_name(surface))
	return out
