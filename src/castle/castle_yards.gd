class_name CastleYards
extends RefCounted
## The working yards of a bailey (EVAL-B02): a smithy yard, a stable yard, a
## market and muster ground with the well in it, and a timber store.
##
## A bailey of scattered props reads as confetti from the wall walk: a barrel
## is a metre across and a fortress ward is three hundred. What reads at that
## distance is a PLACE -- a patch of beaten earth in its own colour with a
## roof, a fence or a stack on it -- so each yard is planned as one:
##
##   patch    a quad of earth, logged by the builder as a `yard_<name>_ground`
##            component so the yard suite can measure it
##   pieces   the things that must be BUILT because no pack ships them: lean-to
##            posts and roof, woodpiles, rail fences, haystacks, a trough, the
##            cloth-on-posts of a stall canopy
##   props    catalogue pieces with their measured footprints, already placed
##            (the furnisher appends them as ordinary bailey fixtures)
##
## Like the rest of the castle this is a pure function of the spec. It reserves
## what the furnisher reserves -- keep, hall, ranges, the well, the gate axis,
## towers -- plus each yard it has already placed, so the routes the yard suite
## floods stay open, and every yard stays inside the ward.
##
## Frame. Every yard has a BACK (the wall, range or fence line it leans on) and
## is laid out in (u, v): u along the back, v from the back toward the open
## ward. `_at` turns that into castle metres.

const LANE := 1.4          # walking room between a yard and anything else
const EDGE := 1.2          # air between a yard and the curtain
const MIN_SIDE := 6.0      # smaller than this is a rug, not a yard
const MAX_PROPS := 30
## Thickness of the beaten-earth quad. Props stand on top of it.
const PATCH_H := 0.1
const NAMES: Array[StringName] = [&"smithy", &"stable", &"market", &"timber"]
## Size at scale 1.0, along the back and out from it, in metres.
const BASE := {
	&"smithy": Vector2(12.0, 9.0),
	&"stable": Vector2(16.0, 12.0),
	&"market": Vector2(16.0, 13.0),
	&"timber": Vector2(12.0, 7.5),
}
## Which of the beaten-earth colours each yard is laid on (see CastleBuilder).
const EARTH := {&"smithy": 0, &"stable": 1, &"market": 2, &"timber": 3}
## What is dealt across the open ground of each yard after its fixed pieces.
const POOLS := {
	&"smithy": [["Crate_Wooden", &"store"], ["Bucket_Metal", &"yard"],
		["Barrel", &"store"], ["Bag", &"store"], ["Crate_Metal", &"store"]],
	&"stable": [["Barrel", &"store"], ["Bucket_Wooden_1", &"yard"],
		["Bag", &"store"], ["FarmCrate_Empty", &"store"], ["Crate_Wooden", &"store"]],
	&"market": [["Barrel_Apples", &"store"], ["FarmCrate_Apple", &"store"],
		["FarmCrate_Carrot", &"store"], ["Bag", &"store"], ["Crate_Wooden", &"store"],
		["Stool", &"store"], ["Bucket_Wooden_1", &"yard"]],
	&"timber": [["Rope_3", &"yard"], ["Crate_Wooden", &"store"], ["Barrel", &"store"],
		["Bucket_Wooden_1", &"yard"], ["Dungeon_Pot1", &"urn"]],
}


## The yards of this castle, in the order they were placed. Each is
## {name, rect, earth, back, pieces: Array[Dictionary], props: Array[Dictionary]}.
## Empty for anything without a bailey, and for a bailey too small to hold one.
static func plan(spec: CastleSpec, ranges: Array = [], well: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not CastleGeometry.is_enclosed(spec) or CastleGeometry.is_sky(spec):
		return out
	var bailey: Rect2 = CastleGeometry.bailey_rect(spec)
	if bailey.size.x < 18.0 or bailey.size.y < 18.0:
		return out
	var taken: Array[Rect2] = CastleFurnisher._reserved(spec, ranges, well)
	# The furnisher keeps the gate's own width clear; the way in is the geometry's
	# strip, which is a shoulder wider on each side, and a yard keeps off that.
	taken.append(CastleGeometry.gate_axis_strip(spec))
	var well_at := Vector2.INF
	var well_res := Rect2()
	var well_body := Rect2()
	if not well.is_empty():
		well_at = well["pos"]
		var wr: float = float(well.get("radius", 0.9))
		well_res = Rect2(well_at - Vector2.ONE * 1.0, Vector2.ONE * 2.0).grow(1.2)
		well_body = Rect2(well_at - Vector2.ONE * wr, Vector2.ONE * wr * 2.0)
	var scale: float = clampf(minf(bailey.size.x, bailey.size.y) / 34.0, 0.7, 2.8)
	# the small pieces grow with the ward, but only so far: a post is a post
	var k: float = clampf(sqrt(scale), 1.0, 1.6)
	var ground: float = CastleGeometry.ring_ground_y(spec, CastleGeometry.inner_ring(spec))
	var rng := RandomNumberGenerator.new()
	rng.seed = spec.seed ^ 0x59415244 ^ 0x1F2E3D
	for yard_name in NAMES:
		var anchor := _anchor(yard_name, bailey, ranges, well_at)
		var placed := _fit(yard_name, bailey, taken, well_res, well_at, anchor, scale)
		if placed.is_empty():
			continue
		var rect: Rect2 = placed["rect"]
		var back := _back(yard_name, rect, bailey, ranges)
		var yard := _lay_out(yard_name, rect, back, well_body, rng, ground, k)
		taken.append(rect.grow(LANE))
		out.append(yard)
	return out


# ------------------------------------------------------------------ fitting

## Where a yard would like to be: beside its trade's own building when the
## bailey has one, else on the side of the ward the old fixture zones used.
static func _anchor(yard_name: StringName, bailey: Rect2, ranges: Array,
		well_at: Vector2) -> Vector2:
	var trade := &"blacksmith" if yard_name == &"smithy" else (
		&"stable" if yard_name == &"stable" else &"")
	if trade != &"":
		for b in ranges:
			if StringName(b.get("business", &"")) == trade:
				return Rect2(b["rect"]).get_center()
	if yard_name == &"market" and well_at.is_finite():
		return well_at
	var c: Vector2 = bailey.get_center()
	var o := Vector2.ZERO
	match yard_name:
		&"smithy":
			o = Vector2(-0.30, 0.22)
		&"stable":
			o = Vector2(0.30, 0.22)
		&"market":
			o = Vector2(0.0, 0.05)
		_:
			o = Vector2(-0.32, -0.20)
	return c + Vector2(bailey.size.x * o.x, bailey.size.y * o.y)


## The free rectangle nearest the anchor, trying the full size first and then
## smaller ones. {} when none fits.
static func _fit(yard_name: StringName, bailey: Rect2, taken: Array[Rect2],
		well_res: Rect2, well_at: Vector2, anchor: Vector2, scale: float) -> Dictionary:
	# The market is laid round the well when the ward lets it: then the well's
	# own reserve is its centre. When the well stands against the gate axis or a
	# range there is no room to hold it, and the market stands beside it instead.
	var holds: Array = [true, false] if yard_name == &"market" and well_at.is_finite() \
		else [false]
	for hold in holds:
		var blocks: Array[Rect2] = []
		for t in taken:
			if hold and t == well_res:
				continue
			blocks.append(t)
		var found := _search(yard_name, bailey, blocks, well_at if hold else Vector2.INF,
			anchor, scale)
		if not found.is_empty():
			return found
	return {}


static func _search(yard_name: StringName, bailey: Rect2, blocks: Array[Rect2],
		hold_at: Vector2, anchor: Vector2, scale: float) -> Dictionary:
	var room: Rect2 = bailey.grow(-EDGE)
	var base: Vector2 = BASE[yard_name]
	for shrink in [1.0, 0.8, 0.64]:
		var size: Vector2 = base * scale * shrink
		if minf(size.x, size.y) < MIN_SIDE:
			size = Vector2(maxf(size.x, MIN_SIDE), maxf(size.y, MIN_SIDE))
		var best := Rect2()
		var best_d := INF
		for turned in [false, true]:
			var sz: Vector2 = Vector2(size.y, size.x) if turned else size
			if sz.x > room.size.x or sz.y > room.size.y:
				continue
			var step: float = clampf(minf(room.size.x, room.size.y) / 70.0, 0.75, 2.5)
			var y: float = room.position.y + sz.y / 2.0
			while y <= room.end.y - sz.y / 2.0 + 0.001:
				var x: float = room.position.x + sz.x / 2.0
				while x <= room.end.x - sz.x / 2.0 + 0.001:
					var c := Vector2(x, y)
					var d: float = c.distance_to(anchor)
					if d < best_d:
						var r := Rect2(c - sz / 2.0, sz)
						if _free(r, blocks) and (not hold_at.is_finite()
								or r.grow(-0.3).encloses(Rect2(hold_at - Vector2.ONE * 1.2,
									Vector2.ONE * 2.4))):
							best = r
							best_d = d
					x += step
				y += step
		if best_d < INF:
			return {"rect": best}
	return {}


static func _free(r: Rect2, blocks: Array[Rect2]) -> bool:
	var g: Rect2 = r.grow(LANE * 0.5)
	for t in blocks:
		if t.intersects(g):
			return false
	return true


## The axis the yard turns its back to: the matching building if there is one,
## else the nearest edge of the ward.
static func _back(yard_name: StringName, rect: Rect2, bailey: Rect2, ranges: Array) -> Vector2:
	var c: Vector2 = rect.get_center()
	if yard_name == &"market":
		return Vector2(0.0, 1.0)
	var trade := &"blacksmith" if yard_name == &"smithy" else (
		&"stable" if yard_name == &"stable" else &"")
	if trade != &"":
		for b in ranges:
			if StringName(b.get("business", &"")) == trade:
				var d: Vector2 = Rect2(b["rect"]).get_center() - c
				return Vector2(signf(d.x), 0.0) if absf(d.x) > absf(d.y) \
					else Vector2(0.0, signf(d.y))
	var to_l: float = c.x - bailey.position.x
	var to_r: float = bailey.end.x - c.x
	var to_n: float = c.y - bailey.position.y
	var to_s: float = bailey.end.y - c.y
	var m: float = minf(minf(to_l, to_r), minf(to_n, to_s))
	if m == to_l:
		return Vector2(-1.0, 0.0)
	if m == to_r:
		return Vector2(1.0, 0.0)
	if m == to_s:
		return Vector2(0.0, 1.0)
	return Vector2(0.0, -1.0)


# ------------------------------------------------------------------- frame

static func _frame(rect: Rect2, back: Vector2) -> Dictionary:
	var along_z: bool = absf(back.y) > 0.5
	return {"c": rect.get_center(), "b": back, "s": Vector2(-back.y, back.x),
		"U": rect.size.x if along_z else rect.size.y,
		"V": rect.size.y if along_z else rect.size.x}


static func _at(f: Dictionary, u: float, v: float) -> Vector2:
	return (f["c"] as Vector2) + (f["s"] as Vector2) * u \
		+ (f["b"] as Vector2) * (float(f["V"]) * 0.5 - v)


static func _rect(f: Dictionary, u0: float, v0: float, u1: float, v1: float) -> Rect2:
	var a := _at(f, u0, v0)
	var b := _at(f, u1, v1)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())


static func _v3(p: Vector2, y := 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


# ---------------------------------------------------------------- layouts

static func _lay_out(yard_name: StringName, rect: Rect2, back: Vector2,
		well_body: Rect2, rng: RandomNumberGenerator, ground: float, k: float) -> Dictionary:
	var f := _frame(rect, back)
	var ctx := {"f": f, "rect": rect, "ground": ground, "k": k, "pieces": [] as Array[Dictionary],
		"blocked": [] as Array[Rect2], "props": [] as Array[Dictionary],
		"rng": rng, "yard": yard_name}
	if well_body.size.x > 0.0 and rect.intersects(well_body):
		(ctx["blocked"] as Array[Rect2]).append(well_body.grow(0.7))
	match yard_name:
		&"smithy":
			_smithy(ctx)
		&"stable":
			_stable(ctx)
		&"market":
			_market(ctx)
		_:
			_timber(ctx)
	return {"name": yard_name, "rect": rect, "ground": ground, "earth": EARTH[yard_name], "back": back,
		"pieces": ctx["pieces"], "props": ctx["props"]}


static func _smithy(ctx: Dictionary) -> void:
	var f: Dictionary = ctx["f"]
	var U: float = f["U"]
	var V: float = f["V"]
	var k: float = ctx["k"]
	var lw: float = clampf(U * 0.5, 5.0, 18.0)
	var ld: float = clampf(V * 0.36, 3.2, 7.0)
	var u0: float = -U * 0.5 + 1.0
	var u1: float = u0 + lw
	var v0 := 0.6
	_leanto(ctx, u0, u1, v0, v0 + ld, 3.4 * k, 2.5 * k, true)
	# the working corner, under the roof, in the order a smith moves
	_prop(ctx, "Anvil", u0 + lw * 0.42, v0 + 1.5, 0.0, &"forge")
	_prop(ctx, "Cauldron", u1 - 1.3, v0 + 1.3, 0.0, &"light")
	_prop(ctx, "Barrel", u0 + lw * 0.42 - 1.5, v0 + 2.6, 0.0, &"store")
	_prop(ctx, "Barrel_Holder", u0 + 1.3, v0 + 1.1, 0.0, &"store")
	_prop(ctx, "WeaponStand", u0 + lw * 0.62, v0 + 1.2, 0.0, &"arms")
	# fuel for the forge, stacked beside the shed
	var pile_w: float = clampf(U * 0.24, 2.5, 8.0)
	_woodpile(ctx, u1 + 1.0, v0 + 0.2, u1 + 1.0 + pile_w, v0 + 1.5, 1.3 * k)
	if U > 24.0:
		_woodpile(ctx, u1 + 1.0, v0 + 2.3, u1 + 1.0 + pile_w * 0.8, v0 + 3.5, 1.1 * k)
	_prop(ctx, "Stall_Cart_Empty", U * 0.28, V * 0.74, 0.1, &"cart")
	_scatter(ctx, V * 0.5, V - 0.8)


static func _stable(ctx: Dictionary) -> void:
	var f: Dictionary = ctx["f"]
	var U: float = f["U"]
	var V: float = f["V"]
	var k: float = ctx["k"]
	var fy: float = clampf(V * 0.26, 2.6, 7.0)
	var fu0: float = -U * 0.5 + 1.0
	var fu1: float = U * 0.5 - 1.0
	var fv0 := 0.9
	var fv1: float = V - fy
	# the corral: three sides and a front with a gate gap
	var gap_c: float = U * 0.16
	var gap_h := 1.7
	_fence(ctx, _at(f, fu0, fv0), _at(f, fu1, fv0))
	_fence(ctx, _at(f, fu0, fv0), _at(f, fu0, fv1))
	_fence(ctx, _at(f, fu1, fv0), _at(f, fu1, fv1))
	_fence(ctx, _at(f, fu0, fv1), _at(f, gap_c - gap_h, fv1))
	_fence(ctx, _at(f, gap_c + gap_h, fv1), _at(f, fu1, fv1))
	# a haystack in the far corner, a trough along the back rail
	var hr: float = clampf(U * 0.075, 1.2, 3.2)
	_stack(ctx, _at(f, fu0 + hr + 1.0, fv0 + hr + 1.0), hr, hr * 1.9)
	_solid(ctx, &"trough", _rect(f, U * 0.1, fv0 + 0.6, U * 0.1 + clampf(U * 0.2, 2.4, 6.0),
		fv0 + 1.2), 0.55 * k)
	_prop(ctx, "Barrel", U * 0.1 - 0.8, fv0 + 1.0, 0.0, &"store")
	_prop(ctx, "Bucket_Wooden_1", U * 0.1 + 1.0, fv0 + 1.8, 0.4, &"yard")
	_prop(ctx, "Bag", fu1 - 1.2, fv0 + 1.4, 0.2, &"store")
	# outside the rails: the cart that brings the fodder
	_prop(ctx, "Stall_Cart_Empty", -U * 0.28, fv1 + fy * 0.55, 0.0, &"cart")
	_stack(ctx, _at(f, U * 0.34, fv1 + fy * 0.5), hr * 0.8, hr * 1.5)
	_scatter(ctx, 0.9, V - 0.6)


static func _market(ctx: Dictionary) -> void:
	var f: Dictionary = ctx["f"]
	var U: float = f["U"]
	var V: float = f["V"]
	var k: float = ctx["k"]
	var cw: float = clampf(U * 0.26, 4.0, 9.0)
	var cd: float = clampf(V * 0.24, 3.0, 6.0)
	var vc: float = V * 0.3
	# two canopies, cloth on four posts, either side of the well
	_canopy(ctx, -U * 0.5 + 1.0, vc - cd / 2.0, -U * 0.5 + 1.0 + cw, vc + cd / 2.0, 2.7 * k, 0)
	_canopy(ctx, U * 0.5 - 1.0 - cw, vc - cd / 2.0, U * 0.5 - 1.0, vc + cd / 2.0, 2.7 * k, 1)
	_prop(ctx, "Table_Large", -U * 0.5 + 1.0 + cw * 0.5, vc, PI * 0.5, &"store")
	_prop(ctx, "Barrel_Apples", -U * 0.5 + 1.0 + cw * 0.85, vc + 0.9, 0.0, &"store")
	_prop(ctx, "Table_Large", U * 0.5 - 1.0 - cw * 0.5, vc, PI * 0.5, &"store")
	_prop(ctx, "FarmCrate_Carrot", U * 0.5 - 1.0 - cw * 0.85, vc - 0.9, 0.0, &"store")
	# the catalogue stalls, in a loose row across the front
	for i in range(3):
		var u: float = lerpf(-U * 0.3, U * 0.3, float(i) / 2.0)
		_prop(ctx, "Stall_Empty", u, V - 1.6, PI, &"store")
	# and the muster end: dummies and a weapon rack at the back
	_prop(ctx, "Dummy", -U * 0.14, 1.2, 0.0, &"yard")
	_prop(ctx, "Dummy", U * 0.14, 1.2, 0.0, &"yard")
	_prop(ctx, "WeaponStand", 0.0, 1.0, 0.0, &"arms")
	_scatter(ctx, 0.8, V - 0.8)


static func _timber(ctx: Dictionary) -> void:
	var f: Dictionary = ctx["f"]
	var U: float = f["U"]
	var V: float = f["V"]
	var k: float = ctx["k"]
	var lw: float = clampf(U * 0.82, 6.0, 30.0)
	var ld: float = clampf(V * 0.46, 3.2, 7.0)
	var u0: float = -lw * 0.5
	var u1: float = lw * 0.5
	var v0 := 0.6
	_leanto(ctx, u0, u1, v0, v0 + ld, 3.0 * k, 2.3 * k, true)
	# the stock, stacked under the shed in lengths between its posts
	var x: float = u0 + 0.6
	while x + 2.0 < u1 - 0.4:
		var seg: float = minf(4.2, u1 - 0.4 - x)
		_woodpile(ctx, x, v0 + 0.7, x + seg, v0 + ld - 1.1, 1.9 * k)
		x += seg + 0.5
	# a free stack and a chopping block in the open
	_woodpile(ctx, -U * 0.34, v0 + ld + 1.4, -U * 0.34 + clampf(U * 0.3, 3.0, 5.0),
		v0 + ld + 2.6, 1.2 * k)
	_prop(ctx, "Anvil_Log", U * 0.3, v0 + ld + 2.2, 0.0, &"forge")
	_prop(ctx, "Dungeon_Cart", U * 0.1, V - 2.4, 0.2, &"cart")
	_scatter(ctx, v0 + ld + 0.8, V - 0.6)


# ---------------------------------------------------------- piece helpers

static func _pieces(ctx: Dictionary) -> Array[Dictionary]:
	return ctx["pieces"]


static func _blocked(ctx: Dictionary) -> Array[Rect2]:
	return ctx["blocked"]


## True when `r` stands clear of everything the yard has already built, and of
## the well, with a hand's width to spare.
static func _clear(ctx: Dictionary, r: Rect2) -> bool:
	for b in _blocked(ctx):
		if b.intersects(r.grow(0.3)):
			return false
	return true


static func _post(ctx: Dictionary, p: Vector2, h: float) -> void:
	_pieces(ctx).append({"kind": &"post", "pos": p, "h": h})
	_blocked(ctx).append(Rect2(p - Vector2.ONE * 0.12, Vector2.ONE * 0.24))


## A solid box of something: the back screen of a shed, a trough.
static func _solid(ctx: Dictionary, role: StringName, r: Rect2, h: float) -> void:
	if not _clear(ctx, r):
		return
	_pieces(ctx).append({"kind": &"solid", "role": role, "rect": r, "h": h})
	_blocked(ctx).append(r)


static func _woodpile(ctx: Dictionary, u0: float, v0: float, u1: float, v1: float,
		h: float) -> void:
	var f: Dictionary = ctx["f"]
	var r := _rect(f, u0, v0, u1, v1)
	if not (ctx["rect"] as Rect2).grow(-0.1).encloses(r) or not _clear(ctx, r):
		return
	# logs lie along the shorter side, so the long face is a wall of log ends
	_pieces(ctx).append({"kind": &"woodpile", "rect": r, "h": h,
		"logs_along_x": r.size.x < r.size.y})
	_blocked(ctx).append(r)


static func _stack(ctx: Dictionary, at: Vector2, radius: float, h: float) -> void:
	var r := Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	if not (ctx["rect"] as Rect2).grow(-0.1).encloses(r) or not _clear(ctx, r):
		return
	_pieces(ctx).append({"kind": &"stack", "pos": at, "r": radius, "h": h})
	_blocked(ctx).append(r)


## A straight run of rail fence, either axis. Its posts and rails are the
## builder's; here it is only a thin blocked strip.
static func _fence(ctx: Dictionary, a: Vector2, b: Vector2) -> void:
	if a.distance_to(b) < 0.8:
		return
	var r := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs()).grow(0.18)
	_pieces(ctx).append({"kind": &"fence", "a": a, "b": b, "h": 1.25})
	_blocked(ctx).append(r)


## Posts at the corners and every few metres between, cloth over them.
static func _canopy(ctx: Dictionary, u0: float, v0: float, u1: float, v1: float,
		h: float, scheme: int) -> void:
	var f: Dictionary = ctx["f"]
	if not _clear(ctx, _rect(f, u0 - 0.4, v0 - 0.4, u1 + 0.4, v1 + 0.4)):
		return
	var corners: Array[Vector2] = [_at(f, u0, v0), _at(f, u1, v0), _at(f, u1, v1), _at(f, u0, v1)]
	for c in corners:
		_post(ctx, c, h)
	var rise: float = 0.55
	var strips := maxi(4, int(round((u1 - u0) / 0.9)))
	strips += strips % 2
	for i in range(strips):
		var ua: float = lerpf(u0 - 0.3, u1 + 0.3, float(i) / float(strips))
		var ub: float = lerpf(u0 - 0.3, u1 + 0.3, float(i + 1) / float(strips))
		var tone := &"cloth_a" if (i + scheme) % 2 == 0 else &"cloth_b"
		var vr: float = (v0 + v1) * 0.5
		for side in [0, 1]:
			var ve: float = v0 - 0.35 if side == 0 else v1 + 0.35
			var drop: float = h - 0.35
			_pieces(ctx).append({"kind": &"roof", "surf": tone, "pts": PackedVector3Array([
				_v3(_at(f, ua, ve), drop), _v3(_at(f, ub, ve), drop),
				_v3(_at(f, ub, vr), h + rise), _v3(_at(f, ua, vr), h + rise)])})


## A shed roof leaning on its back: tall at v0, low at v1, on posts along the
## front and, when `screen`, a plank wall behind.
static func _leanto(ctx: Dictionary, u0: float, u1: float, v0: float, v1: float,
		hb: float, hf: float, screen: bool) -> void:
	var f: Dictionary = ctx["f"]
	if not _clear(ctx, _rect(f, u0 - 0.4, v0 - 0.4, u1 + 0.4, v1 + 0.4)):
		return
	var n: int = maxi(1, int(ceil((u1 - u0) / 4.2)))
	for i in range(n + 1):
		var u: float = lerpf(u0, u1, float(i) / float(n))
		_post(ctx, _at(f, u, v1), hf)
		if not screen:
			_post(ctx, _at(f, u, v0), hb)
	if screen:
		_solid(ctx, &"screen", _rect(f, u0, v0 - 0.1, u1, v0 + 0.1), hb)
	_pieces(ctx).append({"kind": &"roof", "surf": &"tile", "pts": PackedVector3Array([
		_v3(_at(f, u0 - 0.35, v0 - 0.3), hb + 0.1), _v3(_at(f, u1 + 0.35, v0 - 0.3), hb + 0.1),
		_v3(_at(f, u1 + 0.35, v1 + 0.5), hf - 0.05), _v3(_at(f, u0 - 0.35, v1 + 0.5), hf - 0.05)])})


# ----------------------------------------------------------- prop helpers

static func _foot(key: String, at: Vector2, yaw: float) -> Rect2:
	var fp: Vector2 = PropCatalog.footprint_rotated(key, yaw)
	var centre := PropCatalog.plan_centre(key, Vector3(at.x, 0.0, at.y), yaw, 1.0)
	return Rect2(centre - fp / 2.0, fp)


## Set a catalogue prop at (u, v) facing the open ward. False when it does not
## fit between the pieces and the edge of its own patch.
static func _prop(ctx: Dictionary, key: String, u: float, v: float, yaw_off: float,
		kind: StringName) -> bool:
	var f: Dictionary = ctx["f"]
	var at := _at(f, u, v)
	var yaw: float = CastleFurnisher._yaw_facing(-(f["b"] as Vector2)) + yaw_off
	return _put(ctx, key, at, yaw, kind)


static func _put(ctx: Dictionary, key: String, at: Vector2, yaw: float, kind: StringName) -> bool:
	if (ctx["props"] as Array).size() >= MAX_PROPS:
		return false
	var rect := _foot(key, at, yaw)
	if not (ctx["rect"] as Rect2).grow(-0.25).encloses(rect):
		return false
	for b in _blocked(ctx):
		if b.intersects(rect.grow(0.12)):
			return false
	for p in ctx["props"] as Array:
		if (p["rect"] as Rect2).intersects(rect.grow(0.2)):
			return false
	var placement := PropCatalog.placement(key, _v3(at, float(ctx["ground"]) + PATCH_H), yaw, 1.0, kind)
	placement["yard_zone"] = &"bailey_exterior"
	placement["yard_use"] = CastleFurnisher._yard_use(kind)
	placement["yard_name"] = ctx["yard"]
	(ctx["props"] as Array).append(placement)
	return true


## Seeded dart throws between v_from and v_to over the yard's own pool: enough
## to look worked in, and none of it in the way of what is built.
static func _scatter(ctx: Dictionary, v_from: float, v_to: float) -> void:
	var f: Dictionary = ctx["f"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var pool: Array = POOLS[ctx["yard"]]
	var rect: Rect2 = ctx["rect"]
	var want: int = clampi(int(rect.get_area() * 0.045), 4, MAX_PROPS)
	var tries := 0
	var made := 0
	var U: float = f["U"]
	while made < want and tries < want * 14:
		tries += 1
		var row: Array = pool[rng.randi() % pool.size()]
		var u: float = rng.randf_range(-U * 0.5 + 0.7, U * 0.5 - 0.7)
		var v: float = rng.randf_range(v_from, v_to)
		if _prop(ctx, String(row[0]), u, v, rng.randf_range(-0.7, 0.7), StringName(row[1])):
			made += 1
