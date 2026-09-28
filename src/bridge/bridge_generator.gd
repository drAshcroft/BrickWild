class_name BridgeGenerator
extends RefCounted
## Fills a BridgeSpec from (kind, span, width, deck_height, seed) and writes the
## piers, the deck and the members down as DATA.
##
## Same contract as every other family: the generator decides and clamps against
## `BridgeGeometry`, the builder only emits, and the check reads the same lists.
## A bridge is unusually unforgiving of a builder that decides for itself --
## a pier placed a metre off and the arch above it stops being an arch -- so
## `spec.members` carries, for every piece of structure, the x RANGE it is
## responsible for holding up. The deck can then be asked, station by station,
## "what is under you?", and a span with nothing under it is caught as a
## cantilever rather than as an aesthetic opinion.

const KINDS: Array[StringName] = [&"stone", &"covered", &"rope", &"mobile"]

## The four things a mobile span can be. Four different mechanisms and four
## different silhouettes: a lift is two towers and a box that rises, a swing is
## a pier and a cantilever that rotates, a pontoon is a raft that floats, and a
## drawbridge is a leaf that lifts at one end and leaves a span open.
const MOTIONS: Array[StringName] = [&"lift", &"swing", &"pontoon", &"drawbridge"]

## How tall and how thick, per kind, as a fraction of the span unless said.
## Every proportion is of `spec.span` or `spec.width` so a 6 m footbridge and a
## 300 m gorge crossing are the same bridge at two sizes.
const STYLE := {
	&"stone": {
		"bays": [2, 5],              # arches, chosen by span
		"pier_w": 0.13,              # of span
		"parapet": 0.10,             # of width
		"camber": 0.020,             # of span -- a shallow hump
		"deck_t": 0.45,              # metres, floored
		"spring": 0.30,              # of span: springing below the deck
		"stone": "9a9284", "deck": "7d6a4e", "timber": "6b543c", "metal": "4a4a52",
	},
	&"covered": {
		"bays": [3, 9],              # roof bays
		"pier_w": 1.6,               # metres: an abutment wall
		"parapet": 0.09,
		"camber": 0.0,
		"roof_rise": 0.22,           # of width
		"roof_over": 0.16,           # of width
		"roof_pitch": 0.62,
		"bay": 0.0,                  # metres; solved from the span below
		"stone": "8f887a", "deck": "8a7458", "timber": "5f4a34", "metal": "4a4a52",
	},
	&"rope": {
		"bays": [7, 16],             # hangers
		"pier_w": 0.20,              # of span: the towers
		"parapet": 0.10,
		"tower": 0.42,               # of span above the deck
		"sag": 0.085,                # of span
		"tilt": 0.16,                # of width: the towers lean in
		"stone": "6f6a62", "deck": "7d6a4e", "timber": "6b543c", "metal": "3f4048",
	},
	&"mobile": {
		"bays": [2, 3],              # fixed spans
		"pier_w": 0.16,
		"parapet": 0.10,
		"camber": 0.0,
		"tower": 0.40,               # of span above the deck
		"stone": "8a8579", "deck": "7d6a4e", "timber": "6b543c", "metal": "3f4048",
	},
}

## Lanterns: a covered bridge is a roof over a deck and a lantern at each end
## is the only reason anybody ever sees one at night. Not decoration -- it is
## the thing that makes the kind worth having.
const LANTERNS := 2


static func generate(spec: BridgeSpec, p_seed: int) -> void:
	spec.seed = p_seed
	spec.rng.seed = p_seed
	if not KINDS.has(spec.kind):
		spec.kind = &"stone"
	if spec.kind == &"mobile" and not MOTIONS.has(spec.motion):
		spec.motion = &"lift"
	if not KINDS.has(spec.kind):
		spec.kind = &"stone"
	var s: Dictionary = STYLE[spec.kind]
	var r := spec.rng

	spec.span = clampf(spec.span, BridgeGeometry.SPAN_MIN, BridgeGeometry.SPAN_MAX)
	spec.width = clampf(spec.width, BridgeGeometry.WIDTH_MIN, BridgeGeometry.WIDTH_MAX)
	spec.deck_height = maxf(spec.deck_height, spec.water_level + BridgeGeometry.DECK_CLEAR_MIN)
	# A bridge meets its banks. A deck floating a metre above a bank it is
	# supposed to land on is the one thing this family cannot be allowed to do,
	# and it is also the most common way a caller asks for something impossible.
	spec.bank_height = clampf(spec.bank_height, spec.water_level + 0.5, spec.deck_height + 0.6)
	spec.bank_run = maxf(spec.bank_run, spec.span * 0.18)

	# ---- proportions ----
	var bays: Array = s["bays"]
	spec.bays = int(round(lerpf(float(bays[0]), float(bays[1]), r.randf())))
	if spec.kind == &"stone":
		# A stone bridge is a ROW of arches, and the row length is what the span
		# buys: a 300 m crossing is eight arches, a 12 m one is two.
		spec.bays = clampi(int(round(spec.span / 11.0)), 1, 9)
		spec.pier_width = maxf(spec.span * float(s["pier_w"]), 0.9)
		spec.camber = spec.span * float(s["camber"])
		spec.deck_thickness = maxf(float(s["deck_t"]), spec.span * 0.012)
	else:
		spec.pier_width = maxf(minf(float(s["pier_w"]) * maxf(spec.width, 1.0),
			spec.span * 0.14), 1.0)
		spec.camber = 0.0
		spec.deck_thickness = maxf(0.38, spec.width * 0.11)
	if spec.kind == &"covered":
		spec.bay_pitch = maxf(spec.span / float(spec.bays), 1.6)
		spec.roof_rise = maxf(spec.width * float(s["roof_rise"]), 1.1)
		spec.roof_overhang = spec.width * float(s["roof_over"])
		spec.roof_pitch = float(s["roof_pitch"])
		spec.bays = maxi(3, int(round(spec.span / spec.bay_pitch)))
	if spec.kind == &"rope":
		spec.tower_height = maxf(spec.span * float(s["tower"]),
			spec.width * 2.4)
		spec.cable_sag = spec.span * float(s["sag"])
		spec.hanger_pitch = maxf(spec.span / float(spec.bays), 1.1)
		spec.tower_tilt = float(s["tilt"])
	if spec.kind == &"mobile":
		spec.tower_height = maxf(spec.span * float(s["tower"]), spec.width * 2.0)
		# The travel is the mechanism's own reach, and a mechanism that opens
		# the same distance every time is a stamp with a lever on it. Jittered
		# here rather than drawn differently, because the OPEN position is the
		# one that has to be interesting.
		spec.travel = maxf(spec.span * r.randf_range(0.34, 0.52), 3.0)
	spec.parapet_height = maxf(spec.width * float(s["parapet"]), 0.5)
	spec.parapet_width = maxf(0.28, spec.width * 0.055)

	# ---- palette ----
	spec.stone_color = Color(s["stone"]).lerp(Color(s["stone"]).lightened(0.16), r.randf())
	spec.timber_color = Color(s["timber"]).lerp(Color(s["timber"]).lightened(0.2), r.randf())
	spec.deck_color = Color(s["deck"]).lerp(Color(s["deck"]).lightened(0.18), r.randf())
	spec.metal_color = Color(s["metal"])
	spec.roof_color = spec.timber_color.lightened(0.05).lerp(
		Color("3f4a44"), 0.25)
	spec.variant_name = _name(spec, r)

	# ---- the data ----
	_fit_piers(spec, r)
	_fit_deck(spec)
	_fit_members(spec, r)
	_fit_lights(spec)


# ------------------------------------------------------------------ piers

## Every support, from abutment to abutment. The ends are ALWAYS there: a
## bridge with nothing at one end is a plank in the air, and the generator
## would rather refuse the span than invent a support for it.
static func _fit_piers(spec: BridgeSpec, r: RandomNumberGenerator) -> void:
	spec.piers = []
	var half: float = spec.span * 0.5
	var pw: float = minf(spec.pier_width, half * 2.0 * BridgeGeometry.PIER_MAX_FRACTION)
	spec.piers.append({
		"x": -half + pw * 0.5, "w": pw, "top": spec.deck_height,
		"kind": &"abutment"})
	spec.piers.append({
		"x": half - pw * 0.5, "w": pw, "top": spec.deck_height,
		"kind": &"abutment"})

	if spec.kind == &"rope" or (spec.kind == &"mobile" and spec.motion == &"lift"):
		# The towers go where the cables and the mechanism want them, which is
		# INBOARD of the abutments: a tower on the bank is a post, and a post
		# with a cable on it is a pylon.
		# AT the abutment line, not inboard of it. The cable sags to midspan
		# and rises to the tower tops, so a tower standing halfway along the
		# span is standing where the cable is already at its lowest -- which
		# is how the first render pass produced a suspension bridge with no
		# towers on it at all, just a catenary between two thin air columns.
		for sx in [-1.0, 1.0]:
			spec.piers.append({
				"x": half * 0.94 * sx, "w": maxf(pw * 0.85, 1.4),
				"top": spec.deck_height + spec.tower_height,
				"kind": &"tower"})
		return

	if spec.kind == &"stone" and spec.bays > 1:
		# Evenly spaced, which is the whole argument for a row of arches: one
		# span, one pier, and the eye reads the rhythm.
		# Piers are NOT evenly spaced, and that is the one piece of seed
		# variation the kind was missing. Six seeds of a stone bridge built
		# six identical bridges -- the bays are the whole structure, and a row
		# of identical arches is a diagram of a bridge rather than one. The
		# jitter is a few per cent of a bay, which reads as masonry cut by
		# different masons and not as a mistake.
		var cell: float = spec.span / float(spec.bays + 1)
		for i in range(1, spec.bays):
			var jitter: float = 0.0 if spec.bays < 2 else (r.randf() - 0.5) * cell * 0.16
			var x: float = -half + cell * float(i) + jitter
			# Never inside its neighbour, or two piers grow into one wall.
			var lo_x: float = -half + cell * float(i - 1) + pw * 0.7
			var hi_x: float = -half + cell * float(i + 1) - pw * 0.7
			spec.piers.append({
				"x": clampf(x, lo_x, hi_x), "w": pw,
				"top": spec.deck_height, "kind": &"pier"})
		return

	if spec.kind == &"mobile" and spec.motion == &"swing":
		spec.piers.append({
			"x": 0.0, "w": pw * 0.9, "top": spec.deck_height,
			"kind": &"pier"})
		return

	if spec.kind == &"mobile" and spec.motion == &"pontoon":
		# A pontoon has no piers. It has floats, and they are the supports.
		var n: int = clampi(int(spec.span / 5.0), 2, 7)
		for i in range(n):
			spec.piers.append({
				"x": -half + spec.span * (float(i) + 0.5) / float(n),
				"w": spec.pontoon_width, "top": spec.deck_height,
				"kind": &"pontoon"})
		return

	if spec.kind == &"covered":
		# A covered bridge's only masonry is its two abutment walls; the posts
		# carry the deck between them. It is a timber bridge with stone ends.
		return


# ------------------------------------------------------------------- deck

## The walking surface, sampled at every station a hanger, post or hanger-gap
## needs. Read as data so the builder draws one deck and the check walks one
## deck, and neither can disagree about where the road is.
static func _fit_deck(spec: BridgeSpec) -> void:
	spec.deck = []
	var half: float = spec.span * 0.5
	var stations: int = clampi(int(spec.span / 0.5), 8, 240)
	for i in range(stations + 1):
		var x: float = -half + spec.span * float(i) / float(stations)
		spec.deck.append(Vector2(x, BridgeGeometry.deck_height_at(spec, x)))


# ----------------------------------------------------------------- members

## Every piece of structure, and -- the point of the whole list -- the x RANGE
## it is responsible for holding up.
##
## A bridge is judged by its LOAD PATH. A deck that is continuous, correctly
## sized and touching a pier at both ends is still wrong if the middle eight
## metres of it are a cantilever off one abutment, and no amount of looking at
## the picture tells you that as plainly as asking, station by station, what
## stands under it. So each member declares `carries`, and the check unions
## them and looks for a gap.
static func _fit_members(spec: BridgeSpec, r: RandomNumberGenerator) -> void:
	spec.members = []
	var half: float = spec.span * 0.5
	_add(spec, &"deck", Vector3(-half, 0, -spec.width * 0.5),
		Vector3(half, 0, spec.width * 0.5), -half, half, BridgeSpec.SURF_DECK)

	match spec.kind:
		&"stone":
			_masonry(spec, half, r)
		&"covered":
			_covered(spec, half)
		&"rope":
			_suspension(spec, half)
		_:
			_mobile(spec, half, r)


## A masonry arch: an INTRADOS semicircle of clear span `s` springing at `y0`,
## carried on a pier or an abutment on each side, with the spandrel filled in
## above it and a string course along the face.
##
## The arch is the whole reason for the kind. It is what makes the bridge's
## load path visible from the side -- down the haunches, out along the ring,
## into the piers -- and it is why a stone bridge is drawn in profile and a
## beam bridge is not.
static func _masonry(spec: BridgeSpec, half: float, r: RandomNumberGenerator) -> void:
	# The arch openings, one per bay, between consecutive supports.
	var supports: Array[float] = []
	for p in spec.piers:
		supports.append(float(p["x"]))
	supports.sort()
	# The springing is DERIVED from the arch, not authored. A semicircular
	# arch of clear span s rises s/2 above its springing, so a springing
	# chosen independently of s puts the crown through the roadway -- and a
	# fan of voussoirs standing ON TOP of a bridge is not a subtle fault, it is
	# the kind of thing you can see from the far bank. The spandrel is what is
	# left over between the crown and the underside of the deck, and it is
	# checked rather than hoped for.
	var widest: float = 0.0
	for i in range(supports.size() - 1):
		widest = maxf(widest, supports[i + 1] - supports[i] - spec.pier_width)
	var y0: float = maxf(spec.deck_height - spec.deck_thickness
		- spec.camber * 0.0 - widest * 0.5 - 0.35, 0.4)
	for i in range(supports.size() - 1):
		var x0: float = supports[i] + spec.pier_width * 0.5
		var x1: float = supports[i + 1] - spec.pier_width * 0.5
		var clear: float = x1 - x0
		if clear <= 0.2:
			continue
		var ring: Array[Dictionary] = BridgeGeometry.arch_intrados(clear, y0,
			(x0 + x1) * 0.5)
		var prev: Vector2 = Vector2(ring[0]["x"], ring[0]["y"])
		for k in range(1, ring.size()):
			var cur := Vector2(ring[k]["x"], ring[k]["y"])
			_add(spec, &"arch_ring", Vector3(prev.x, prev.y, 0.0),
				Vector3(cur.x, cur.y, 0.0), x0, x1, BridgeSpec.SURF_STONE)
			prev = cur
		# The spandrel: the wall between the arch's back and the road above it.
		var crown: float = y0 + clear * 0.5
		_add(spec, &"spandrel", Vector3((x0 + x1) * 0.5, crown, 0.0),
			Vector3((x0 + x1) * 0.5, spec.deck_height, 0.0), x0, x1,
			BridgeSpec.SURF_STONE)
	# A string course along the face and a parapet above it. The course is what
	# stops a long stone wall reading as a ribbon: it gives the elevation a
	# horizontal, and a horizontal is what masonry is FOR.
	_add(spec, &"string_course", Vector3(-half, spec.deck_height - 0.9, 0.0),
		Vector3(half, spec.deck_height - 0.9, 0.0), -half, half, BridgeSpec.SURF_STONE)
	_parapet(spec, half)


## A covered bridge: a masonry abutment at each end, a timber deck between, and
## a gabled roof over the whole thing on posts and side beams.
##
## The roof is the silhouette and the posts are the load path, so both are
## drawn on the same bay rhythm. A covered bridge whose posts do not line up
## with its roof beams is a shed with a fence under it.
static func _covered(spec: BridgeSpec, half: float) -> void:
	var hw: float = spec.width * 0.5
	var pitch: float = spec.bay_pitch
	var n: int = maxi(2, int(round(spec.span / pitch)))
	# Side beams, one per side, the full length.
	for sz in [-1.0, 1.0]:
		_add(spec, &"side_beam", Vector3(-half, spec.deck_height - 0.35, hw * sz),
			Vector3(half, spec.deck_height - 0.35, hw * sz), -half, half,
			BridgeSpec.SURF_TIMBER)
	# Cross beams and posts on the bay rhythm, and the rafters they carry.
	for i in range(n + 1):
		var x: float = -half + spec.span * float(i) / float(n)
		_add(spec, &"cross_beam", Vector3(x, spec.deck_height - 0.3, -hw),
			Vector3(x, spec.deck_height - 0.3, hw), x, x, BridgeSpec.SURF_TIMBER)
		if i == 0 or i == n:
			continue   # the ends stand on the abutment walls
		var post_h: float = spec.roof_rise + spec.width * spec.roof_pitch * 0.5
		for sz in [-1.0, 1.0]:
			_add(spec, &"post", Vector3(x, spec.deck_height, hw * sz),
				Vector3(x, spec.deck_height + post_h, hw * sz), x, x,
				BridgeSpec.SURF_TIMBER)
	# The gable itself, as TWO SLOPING PLANES from each eave up to the ridge.
	# A roof drawn as two horizontal members at the eaves is a pair of
	# gutters: the first pass had beams along the whole length at eave height
	# and nothing sloping between them, which is a covered bridge with no roof
	# and a rail where the roof should be. The slope is the silhouette and the
	# pitch is `roof_pitch`, so the two planes are drawn from the geometry and
	# not from an angle somebody typed.
	var eave: float = spec.deck_height + spec.width * spec.roof_pitch * 0.5
	var over: float = hw + spec.roof_overhang
	for sz in [-1.0, 1.0]:
		_add(spec, &"roof", Vector3(-half, eave, over * sz),
			Vector3(-half, eave + spec.roof_rise, 0.0), -half, half,
			BridgeSpec.SURF_TIMBER)
		_add(spec, &"rafter", Vector3(-half, eave, over * sz),
			Vector3(half, eave, over * sz), -half, half, BridgeSpec.SURF_TIMBER)
		# And a rafter under each plane on the bay rhythm, which is what
		# carries the roof and what a covered bridge is seen for.
		for i in range(n + 1):
			var rx: float = -half + spec.span * float(i) / float(n)
			_add(spec, &"rafter", Vector3(rx, eave, over * sz),
				Vector3(rx, eave + spec.roof_rise, 0.0), rx, rx,
				BridgeSpec.SURF_TIMBER)
	# The ridge, and the gable ends that close the triangle at each abutment.
	_add(spec, &"ridge", Vector3(-half, eave + spec.roof_rise, 0.0),
		Vector3(half, eave + spec.roof_rise, 0.0), -half, half, BridgeSpec.SURF_TIMBER)
	for sx in [-1.0, 1.0]:
		_add(spec, &"gable_end", Vector3(half * sx, eave, 0.0),
			Vector3(half * sx, eave + spec.roof_rise, 0.0), half * sx, half * sx,
			BridgeSpec.SURF_TIMBER)
	# A closed side between the posts, with a rail at hand height.
	for sz in [-1.0, 1.0]:
		_add(spec, &"wall_panel", Vector3(-half, spec.deck_height, hw * sz),
			Vector3(half, spec.deck_height, hw * sz), -half, half,
			BridgeSpec.SURF_TIMBER)
		_add(spec, &"hand_rail", Vector3(-half, spec.deck_height + 0.95, hw * sz),
			Vector3(half, spec.deck_height + 0.95, hw * sz), -half, half,
			BridgeSpec.SURF_TIMBER)


## A suspension bridge: two towers, a main cable over each side, hangers down
## to the deck at every pitch, backstays to the anchorages, and railings.
##
## The cable is a PARABOLA and not a catenary, and the reason is written on
## `BridgeGeometry.cable_height_at`. A catenary hangs the way a loose chain
## hangs; a bridge cable is tensioned to a chosen sag against a chosen deck
## load, and what comes out is a parabola. Draw the true catenary and the cable
## bottoms out off midspan, the hangers on one side go slack, and the whole
## thing reads as a rope bridge with a rope bridge's slack in it.
static func _suspension(spec: BridgeSpec, half: float) -> void:
	var hw: float = spec.width * 0.5
	# The main cable, sampled so it is drawn as a curve and not as two straight
	# sticks, in the plane of each handrail.
	for sz in [-1.0, 1.0]:
		var prev: Vector3 = BridgeGeometry.hanger_top(spec, -half)
		prev.z = hw * sz
		var steps: int = 28
		for i in range(1, steps + 1):
			var t: float = -1.0 + 2.0 * float(i) / float(steps)
			var cur: Vector3 = BridgeGeometry.cable_point(spec, t)
			cur.z = hw * sz
			_add(spec, &"main_cable", prev, cur, prev.x, cur.x, BridgeSpec.SURF_METAL)
			prev = cur
	# Hangers, from the cable down to the deck edge, on the pitch.
	var hn: int = maxi(3, int(spec.span / spec.hanger_pitch))
	for i in range(hn + 1):
		var x: float = -half + spec.span * float(i) / float(hn)
		var top: Vector3 = BridgeGeometry.hanger_top(spec, x)
		if top.y <= spec.deck_height + 0.1:
			continue   # the cable is below the rail here; a hanger would be a post
		for sz in [-1.0, 1.0]:
			_add(spec, &"hanger", Vector3(x, spec.deck_height, hw * sz),
				Vector3(top.x, top.y, hw * sz), x, x, BridgeSpec.SURF_METAL)
	# Backstays: the cable past the tower tops and down to the ground, which is
	# what stops a suspension bridge looking like a rope bridge over a gap.
	for sz in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			var tx: float = half * 0.94 * sx
			var anchor := Vector3(half * 1.0 * sx, spec.bank_height + 0.4, hw * sz)
			_add(spec, &"backstay", Vector3(tx, spec.deck_height + spec.tower_height, hw * sz),
				anchor, -half, half, BridgeSpec.SURF_METAL)
	_parapet(spec, half)


## A movable span. Four mechanisms, and the mechanism IS the building: a lift
## is two towers and a box that rises in them, a swing is a pier and a span that
## rotates about it, a pontoon is a raft on floats, and a drawbridge is a leaf
## that lifts at one end and leaves a channel open.
static func _mobile(spec: BridgeSpec, half: float, r: RandomNumberGenerator) -> void:
	var hw: float = spec.width * 0.5
	match spec.motion:
		&"lift":
			# The moving span hangs in a pair of towers, and the ropes that
			# raise it are the detail that makes the mechanism read.
			for sx in [-1.0, 1.0]:
				_add(spec, &"lift_rope", Vector3(half * 0.30 * sx, spec.deck_height, hw * 0.8),
					Vector3(half * 0.30 * sx, spec.deck_height + spec.tower_height, hw * 0.8),
					half * 0.30 * sx, half * 0.30 * sx, BridgeSpec.SURF_METAL)
				_add(spec, &"lift_rope", Vector3(half * 0.30 * sx, spec.deck_height, -hw * 0.8),
					Vector3(half * 0.30 * sx, spec.deck_height + spec.tower_height, -hw * 0.8),
					half * 0.30 * sx, half * 0.30 * sx, BridgeSpec.SURF_METAL)
			# The beam the lift span hangs from, across the top of the towers.
			_add(spec, &"lift_beam", Vector3(-half * 0.30, spec.deck_height + spec.tower_height, 0.0),
				Vector3(half * 0.30, spec.deck_height + spec.tower_height, 0.0),
				-half, half, BridgeSpec.SURF_METAL)
			_parapet(spec, half)
		&"swing":
			# A pivot drum on the pier and a cantilever, drawn in the raised
			# position so the mechanism is legible.
			_add(spec, &"pivot", Vector3(0.0, spec.deck_height - 0.2, 0.0),
				Vector3(0.0, spec.deck_height + 0.5, 0.0), 0.0, 0.0,
				BridgeSpec.SURF_METAL)
			# The boom stands at the angle it happens to be drawn at, and that
			# angle is the mechanism talking. A swing that always opens to the
			# same twenty degrees is a closed bridge with a picture of a bridge
			# drawn on it.
			var boom: float = spec.travel * r.randf_range(0.16, 0.34)
			for sx in [1.0, -1.0]:
				_add(spec, &"swing_boom", Vector3(0.0, spec.deck_height + 0.3, 0.0),
					Vector3(half * 0.5 * sx, spec.deck_height + 0.3 + boom, 0.0),
					0.0, half * 0.5 * sx, BridgeSpec.SURF_TIMBER)
			_parapet(spec, half)
		&"pontoon":
			# Floats under the deck, and a gangway's worth of rail between them.
			for p in spec.piers:
				if p["kind"] != &"pontoon":
					continue
				var px: float = float(p["x"])
				_add(spec, &"float", Vector3(px, spec.water_level, -hw),
					Vector3(px, spec.water_level, hw), px, px, BridgeSpec.SURF_TIMBER)
			_parapet(spec, half)
		_:
			# A drawbridge: a leaf hinged at one abutment, standing at the angle
			# it is drawn at. The counterweight and the chains are what make it
			# read as a mechanism rather than as a ramp.
			var hinge := Vector3(-half, spec.deck_height, 0.0)
			var tip := hinge + Vector3(spec.travel * 0.8, spec.travel * 0.62, 0.0)
			_add(spec, &"leaf", hinge, tip, -half, tip.x, BridgeSpec.SURF_DECK)
			_add(spec, &"backstay", Vector3(-half * 0.98, spec.deck_height, hw * 0.9),
				tip + Vector3(0, 0.3, hw * 0.9), -half, tip.x, BridgeSpec.SURF_METAL)
			_parapet(spec, half)


## A parapet down both edges: the thing that stops a bridge reading as a plank.
static func _parapet(spec: BridgeSpec, half: float) -> void:
	var hw: float = spec.width * 0.5
	for sz in [-1.0, 1.0]:
		_add(spec, &"parapet", Vector3(-half, spec.deck_height, (hw - spec.parapet_width * 0.5) * sz),
			Vector3(half, spec.deck_height, (hw - spec.parapet_width * 0.5) * sz),
			-half, half, BridgeSpec.SURF_STONE)


# ------------------------------------------------------------------ lights

## A lantern at each end. Only a covered bridge carries them, and that is the
## point of the kind: it is the one bridge you can see at night from the road.
static func _fit_lights(spec: BridgeSpec) -> void:
	spec.glow = []
	if spec.kind != &"covered":
		return
	var half: float = spec.span * 0.5
	for sx in [-1.0, 1.0]:
		spec.glow.append({
			"pos": Vector3(half * 0.86 * sx, spec.deck_height + 1.5, 0.0),
			"colour": Color("ffd08a"), "energy": 2.2, "range": 9.0})


# ------------------------------------------------------------------ helpers

static func _add(spec: BridgeSpec, role: StringName, a: Vector3, b: Vector3,
		x0: float, x1: float, surf: int) -> void:
	spec.members.append({
		"role": role, "a": a, "b": b, "surf": surf,
		"carries": PackedFloat32Array([minf(x0, x1), maxf(x0, x1)])})


## How far the arch springing sits below the deck. Derived, not authored, so a
## short span cannot ask for a springing below its own waterline.
static func spring_depth(spec: BridgeSpec) -> float:
	return maxf(spec.deck_height * 0.55, spec.span * 0.10)


const FIRST := ["Grey", "Old", "Iron", "Long", "Cold", "High", "Low", "Black",
	"White", "Broken", "Three", "Nine"]
const SECOND := ["beck", "bridge", "crossing", "span", "ford", "gate", "wick",
	"holt", "mere", "stones", "weir", "water"]


static func _name(spec: BridgeSpec, r: RandomNumberGenerator) -> String:
	return "%s %s" % [
		FIRST[r.randi() % FIRST.size()],
		SECOND[r.randi() % SECOND.size()]]
