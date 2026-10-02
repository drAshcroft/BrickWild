class_name CastleApron
extends RefCounted
## The ground a castle stands in (EVAL-B02 step 3): a ring of trodden earth
## and rough grass out a few metres beyond whatever the plan covers (curtain,
## batter, towers, moat bank), and a cart track that leaves the gate and goes
## away over it.
##
## OPTIONAL. `CastleSpec.ground_apron` is off by default, so a bare castle is
## bit-identical. It is never part of `BrickWild.placement()` bounds: that call
## puts the flag aside while it measures, the way a house sets its yard pieces
## aside and a hotel keeps its finials in `landmark_footprint`. A village that
## lays its own ground round a castle must not be pushed out by ours.
##
## The apron is vertex-coloured skin on CastleBuilder.SURF_GROUND. It lies
## wholly OUTSIDE `CastleGeometry.plan_extent`, so it overlaps no mass. Masses
## logged, tiling the ring: `ground_apron_back`, `_left`, `_right`,
## `_front_left`, `_front_right` and `ground_apron_track` (the gate lane).

const WIDTH := 5.0          # the ring, metres beyond the plan extent
const EARTH_BAND := 1.8     # trodden earth next to the work, then rough grass
const TRACK_W := 3.4
const TRACK_TAIL := 5.0     # the track runs this far beyond the ring
const LIFT := 0.02          # above the y = 0 ground plane
const SEGMENT := 3.5        # tonal variation is cut in lumps this long

const EARTH := [Color("7a6548"), Color("6f5b40"), Color("84704f")]
const GRASS := [Color("6f8546"), Color("7b8f4d"), Color("647c3f"), Color("86975a")]
const TRACK := Color("8a7556")
const RUT := Color("5f4d36")


## The ring and track rectangles by name, for the builder and for a checker.
## Empty when the spec asks for none.
static func rects(spec: CastleSpec) -> Dictionary:
	if not spec.ground_apron or CastleGeometry.is_sky(spec):
		return {}
	var e: Rect2 = CastleGeometry.plan_extent(spec)
	var w := WIDTH
	var x0: float = e.position.x
	var z0: float = e.position.y
	var x1: float = e.end.x
	var z1: float = e.end.y
	var tw: float = _track_width(spec)
	var lo := -tw * 0.5
	var hi := tw * 0.5
	return {
		"back": Rect2(Vector2(x0 - w, z1), Vector2(x1 - x0 + 2.0 * w, w)),
		"left": Rect2(Vector2(x0 - w, z0), Vector2(w, z1 - z0)),
		"right": Rect2(Vector2(x1, z0), Vector2(w, z1 - z0)),
		"front_left": Rect2(Vector2(x0 - w, z0 - w), Vector2(lo - (x0 - w), w)),
		"front_right": Rect2(Vector2(hi, z0 - w), Vector2(x1 + w - hi, w)),
		"track": Rect2(Vector2(lo, z0 - w - TRACK_TAIL), Vector2(tw, w + TRACK_TAIL)),
	}


static func _track_width(spec: CastleSpec) -> float:
	var deck: AABB = CastleGeometry.causeway_deck_aabb(spec)
	return maxf(TRACK_W, deck.size.x) if deck.size.x > 0.0 else TRACK_W


static func emit(b: CastleBuilder) -> void:
	var rows: Dictionary = rects(b.spec)
	if rows.is_empty():
		return
	b.tag("apron")
	b.mark_ground_skin()
	var rng := RandomNumberGenerator.new()
	rng.seed = b.spec.seed ^ 0x41_50_52_4E
	for side in rows:
		var r: Rect2 = rows[side]
		if r.size.x <= 0.05 or r.size.y <= 0.05:
			continue
		if side == "track":
			_track(b, r)
		else:
			_ring_piece(b, r, side, rng)
		b._log_mass("ground_apron_%s" % side,
			AABB(Vector3(r.position.x, 0.0, r.position.y), Vector3(r.size.x, LIFT, r.size.y)))


## One side of the ring, cut into lumps along its length. Each lump is a band
## of earth beside the work and a band of grass beyond, in its own tone, so the
## edge reads as ground that has been walked on and not as a painted frame.
static func _ring_piece(b: CastleBuilder, r: Rect2, side: String,
		rng: RandomNumberGenerator) -> void:
	var along_x: bool = side in ["back", "front_left", "front_right"]
	var length: float = r.size.x if along_x else r.size.y
	var depth: float = r.size.y if along_x else r.size.x
	var near_is_low: bool = side in ["back", "right"]   # which edge touches the castle
	var lumps: int = maxi(1, int(round(length / SEGMENT)))
	for i in range(lumps):
		var a: float = length * float(i) / float(lumps)
		var c: float = length * float(i + 1) / float(lumps)
		var earth: Color = EARTH[rng.randi() % EARTH.size()]
		var grass: Color = GRASS[rng.randi() % GRASS.size()]
		var earth_w: float = clampf(EARTH_BAND + rng.randf_range(-0.5, 0.5), 0.8, depth - 0.5)
		var e_lo: float = 0.0 if near_is_low else depth - earth_w
		var g_lo: float = earth_w if near_is_low else 0.0
		_lump(b, r, along_x, a, c, e_lo, earth_w, earth, LIFT + 0.004)
		_lump(b, r, along_x, a, c, g_lo, depth - earth_w, grass, LIFT)


static func _lump(b: CastleBuilder, r: Rect2, along_x: bool, a0: float, a1: float,
		c0: float, width: float, colour: Color, y: float) -> void:
	var piece: Rect2
	if along_x:
		piece = Rect2(Vector2(r.position.x + a0, r.position.y + c0), Vector2(a1 - a0, width))
	else:
		piece = Rect2(Vector2(r.position.x + c0, r.position.y + a0), Vector2(width, a1 - a0))
	CastleSkin.quad(b, Vector3(piece.position.x, y, piece.position.y),
		Vector3(piece.end.x, y, piece.position.y), Vector3(piece.end.x, y, piece.end.y),
		Vector3(piece.position.x, y, piece.end.y), colour)


## The gate lane: worn earth with two wheel ruts down it.
static func _track(b: CastleBuilder, r: Rect2) -> void:
	_lump(b, r, false, 0.0, r.size.y, 0.0, r.size.x, TRACK, LIFT + 0.006)
	for side in [-1.0, 1.0]:
		var cx: float = side * minf(0.7, r.size.x * 0.22)
		CastleSkin.quad(b, Vector3(cx - 0.17, LIFT + 0.012, r.position.y),
			Vector3(cx + 0.17, LIFT + 0.012, r.position.y),
			Vector3(cx + 0.17, LIFT + 0.012, r.end.y), Vector3(cx - 0.17, LIFT + 0.012, r.end.y), RUT)
