class_name HousePiles
extends RefCounted
## A house or shop standing on PILES over shallow water (VTER-FORM-WATER):
## Ganvié on its lagoon, Kampong Ayer on the Brunei river, the stilt houses
## of every shallow shore. `BuildingRequest.foundation = &"piles"` asks for
## it; the default (`&""`) is the ground, and then nothing here runs.
##
## The floor never moves, exactly as on falling ground (HouseSlope): local
## y = 0 is the underside of the ground floor, which every flat house already
## stands on. The water and its bed are BELOW it:
##
##   y = 0                       the deck's top: the floor's underside, the
##                               gallery and the landing a person walks on
##   y = -freeboard              the water's surface (`pile_freeboard_m`)
##   y = -freeboard - water      the bed (`pile_water_m`, the water's depth)
##   y = ... - EMBED_M           the foot of every pile, driven into the bed
##
## What stands under and round the house, all emitted through named
## components (host "piles"):
##
##   pile_deck     the timber platform, top at y = 0: the house's footprint
##                 grown by a GALLERY all round (the walkway the facade pieces
##                 stand on) and, at the entrance, a LANDING reaching
##                 `pile_deck_m` out from the wall -- in a village, to the
##                 boardwalk the house fronts. Disjoint rectangles, so no two
##                 deck faces lie in one plane.
##   pile_bearer   the beams the deck rests on, one per row of piles
##   pile          the posts, on a grid no wider than PILE_SPACING, from the
##                 bearers down through the water into the bed
##   pile_ladder   a ladder from the landing's edge down to the water, where
##                 a canoe ties up
##
## A house on piles plans no yard (HouseYard.applies): there is no ground
## round it to plant, fence or stack a woodpile on. Its facade pieces stand on
## the gallery.

## The deck's own thickness (boards), and the bearers' depth under it.
const DECK_T := 0.08
const BEARER_H := 0.20
const BEARER_W := 0.16
## The posts: square timber, no further apart than this, driven this deep.
const PILE_W := 0.20
const PILE_SPACING := 2.2
const EMBED_M := 0.6
## The walkway round the house: wide enough for the facade's bench and barrel.
const GALLERY_M := 1.0
## The request's ranges. Deeper water is refused (`water_too_deep`), not
## clamped: a pile village stands in the shallows, and a planner told why moves
## the lot.
const MAX_WATER_M := 4.0
const FREEBOARD_DEFAULT := 1.2
const FREEBOARD_MIN := 0.4
const FREEBOARD_MAX := 3.0
const DECK_DEFAULT := 1.5
const DECK_MAX := 8.0
## The canoe ladder: rungs this far apart, stiles this wide apart.
const RUNG_STEP := 0.3
const LADDER_W := 0.6

const SURF_FLOOR := 3
const SURF_TRIM := 1


static func on_piles(spec: HouseSpec) -> bool:
	return spec != null and spec.foundation == &"piles"


static func freeboard(spec: HouseSpec) -> float:
	return spec.pile_freeboard if spec.pile_freeboard > 0.0 else FREEBOARD_DEFAULT


static func deck_reach(spec: HouseSpec) -> float:
	return spec.pile_deck if spec.pile_deck > 0.0 else DECK_DEFAULT


## The water's surface and the bed, in the house's own frame.
static func water_y(spec: HouseSpec) -> float:
	return -freeboard(spec)


static func bed_y(spec: HouseSpec) -> float:
	return -freeboard(spec) - maxf(spec.pile_water, 0.0)


## The foot of every pile.
static func foot_y(spec: HouseSpec) -> float:
	return bed_y(spec) - EMBED_M


## Why `request` cannot stand on piles, as [code, field, message]; [] when it
## can (or does not ask to). BuildingLibrary.validate reads this.
static func refusal(request: BuildingRequest) -> Array:
	var f: StringName = request.foundation
	var asked: bool = request.pile_water_m != 0.0 or request.pile_freeboard_m != 0.0 \
		or request.pile_deck_m != 0.0
	if f == &"":
		if asked:
			return [&"unsupported_option", &"foundation",
				"pile_water_m, pile_freeboard_m and pile_deck_m need foundation 'piles'."]
		return []
	if f != &"piles":
		return [&"invalid_ground", &"foundation", "foundation must be '' (the ground) or 'piles'."]
	if request.kind not in [&"house", &"shop"]:
		return [&"unsupported_option", &"foundation", "Only houses and shops stand on piles."]
	if request.ground_fall_m != 0.0:
		return [&"unsupported_option", &"foundation",
			"A building on piles stands over water, not on falling ground: give ground_fall_m 0."]
	for field in ["pile_water_m", "pile_freeboard_m", "pile_deck_m"]:
		var v: float = float(request.get(field))
		if not is_finite(v) or v < 0.0:
			return [&"invalid_ground", StringName(field), "%s must be a finite number of metres, 0 or more." % field]
	if request.pile_water_m > MAX_WATER_M:
		return [&"water_too_deep", &"pile_water_m",
			"Piles stand in at most %.1f m of water; %.2f m was asked." % [MAX_WATER_M, request.pile_water_m]]
	if request.pile_freeboard_m != 0.0 and (request.pile_freeboard_m < FREEBOARD_MIN
			or request.pile_freeboard_m > FREEBOARD_MAX):
		return [&"invalid_ground", &"pile_freeboard_m",
			"pile_freeboard_m must be %.1f-%.1f m (0: %.1f)." % [FREEBOARD_MIN, FREEBOARD_MAX, FREEBOARD_DEFAULT]]
	if request.pile_deck_m > DECK_MAX:
		return [&"invalid_ground", &"pile_deck_m", "pile_deck_m must be at most %.1f m." % DECK_MAX]
	return []


# ------------------------------------------------------------- the platform

## The entrance door's outward normal, or the front (-Z) when there is none.
static func _front(plan: HousePlan) -> Vector2:
	var d := plan.entrance()
	if d < 0:
		return Vector2(0.0, -1.0)
	return Vector2(plan.doors[d]["normal"]).normalized()


## The deck as disjoint rectangles in the house's frame: the gallery round the
## footprint, the landing beyond it at the entrance, and whatever of the
## chimney stack's foot neither covers.
static func deck_rects(plan: HousePlan) -> Array[Rect2]:
	var spec: HouseSpec = plan.spec
	var core: Rect2 = HouseGeometry.site_rect(spec).grow(GALLERY_M)
	var out: Array[Rect2] = [core]
	var reach: float = deck_reach(spec)
	if reach > GALLERY_M + 0.01:
		var n := _front(plan)
		var site := HouseGeometry.site_rect(spec)
		var landing: Rect2
		if absf(n.y) > 0.5:
			var face: float = site.position.y if n.y < 0.0 else site.end.y
			var z0: float = face + n.y * GALLERY_M
			var z1: float = face + n.y * reach
			landing = Rect2(Vector2(core.position.x, minf(z0, z1)), Vector2(core.size.x, absf(z1 - z0)))
		else:
			var face: float = site.position.x if n.x < 0.0 else site.end.x
			var x0: float = face + n.x * GALLERY_M
			var x1: float = face + n.x * reach
			landing = Rect2(Vector2(minf(x0, x1), core.position.y), Vector2(absf(x1 - x0), core.size.y))
		out.append(landing)
	var chimney := HouseGeometry.chimney_rect(plan)
	if chimney.has_area():
		var rest: Array[Rect2] = [chimney.grow(0.1)]
		for taken in out.duplicate():
			var next: Array[Rect2] = []
			for r in rest:
				next.append_array(_minus(r, taken))
			rest = next
		for r in rest:
			if r.size.x > 0.02 and r.size.y > 0.02:
				out.append(r)
	return out


## The landing alone (empty when the deck is no deeper than the gallery).
static func landing_rect(plan: HousePlan) -> Rect2:
	var rects := deck_rects(plan)
	return rects[1] if rects.size() > 1 and deck_reach(plan.spec) > GALLERY_M + 0.01 else Rect2()


## Everything the platform covers in plan.
static func platform_rect(plan: HousePlan) -> Rect2:
	var out := Rect2()
	for r in deck_rects(plan):
		out = r if not out.has_area() else out.merge(r)
	return out


## `a` less `b`, as up to four rectangles.
static func _minus(a: Rect2, b: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var i := a.intersection(b)
	if not i.has_area():
		out.append(a)
		return out
	if i.position.y > a.position.y:
		out.append(Rect2(a.position, Vector2(a.size.x, i.position.y - a.position.y)))
	if i.end.y < a.end.y:
		out.append(Rect2(Vector2(a.position.x, i.end.y), Vector2(a.size.x, a.end.y - i.end.y)))
	if i.position.x > a.position.x:
		out.append(Rect2(Vector2(a.position.x, i.position.y), Vector2(i.position.x - a.position.x, i.size.y)))
	if i.end.x < a.end.x:
		out.append(Rect2(Vector2(i.end.x, i.position.y), Vector2(a.end.x - i.end.x, i.size.y)))
	return out


## The pile positions under one deck rectangle: a grid inset half a post from
## its edges, no wider than PILE_SPACING, skipping any row or column that a
## rectangle before it already carries (a shared edge is not posted twice).
static func pile_grid(r: Rect2, before: Array[Rect2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var inner := r.grow(-PILE_W * 0.5)
	var nx: int = maxi(1, int(ceil(inner.size.x / PILE_SPACING)))
	var nz: int = maxi(1, int(ceil(inner.size.y / PILE_SPACING)))
	for iz in range(nz + 1):
		for ix in range(nx + 1):
			var p := inner.position + Vector2(inner.size.x * float(ix) / float(nx),
				inner.size.y * float(iz) / float(nz))
			var carried := false
			for b in before:
				if b.grow(PILE_SPACING * 0.45).has_point(p):
					carried = true
					break
			if not carried:
				out.append(p)
	return out


# ----------------------------------------------------------------- emission

## Emit the deck, the bearers, the piles and the canoe ladder through `b`.
## Called last by HouseBuilder and only for a house on piles.
static func emit(b: HouseBuilder) -> void:
	var plan: HousePlan = b.plan
	var spec: HouseSpec = plan.spec
	if not on_piles(spec):
		return
	var rects := deck_rects(plan)
	var foot := foot_y(spec)
	var under := -DECK_T - BEARER_H
	b.tag("piles")
	b.host("piles", 0)
	var bounds := AABB()
	var first := true
	var before: Array[Rect2] = []
	for r in rects:
		var deck := PackedVector3Array([Vector3(r.position.x, -DECK_T * 0.5, r.position.y),
			Vector3(r.end.x, -DECK_T * 0.5, r.position.y), Vector3(r.end.x, -DECK_T * 0.5, r.end.y),
			Vector3(r.position.x, -DECK_T * 0.5, r.end.y)])
		var row := b.component_slab("pile_deck", deck, DECK_T, SURF_FLOOR)
		bounds = MassBuilder.component_aabb(row) if first else bounds.merge(MassBuilder.component_aabb(row))
		first = false
		var grid := pile_grid(r, before)
		# bearers: one beam along x at each row of this rectangle's piles
		var rows := {}
		for p in grid:
			rows[snappedf(p.y, 0.001)] = true
		for z in rows.keys():
			var xf := Transform3D(Basis.IDENTITY, Vector3(r.get_center().x, -DECK_T - BEARER_H * 0.5, float(z)))
			b.component_box("pile_bearer", Vector3(r.size.x - 0.02, BEARER_H, BEARER_W), xf, SURF_TRIM)
		for p in grid:
			var h: float = under - foot
			var xf := Transform3D(Basis.IDENTITY, Vector3(p.x, foot + h * 0.5, p.y))
			var post := b.component_box("pile", Vector3(PILE_W, h, PILE_W), xf, SURF_TRIM)
			bounds = bounds.merge(MassBuilder.component_aabb(post))
		before.append(r)
	_ladder(b, plan, rects)
	b._log_mass("piles", bounds, foot)
	b.host_end()


## A ladder down the landing's outer edge to the water, at the corner away
## from the door, so a canoe can tie up without blocking the way in.
static func _ladder(b: HouseBuilder, plan: HousePlan, rects: Array[Rect2]) -> void:
	var spec: HouseSpec = plan.spec
	var n := _front(plan)
	var deck: Rect2 = rects[1] if rects.size() > 1 and deck_reach(spec) > GALLERY_M + 0.01 else rects[0]
	var across := Vector2(-n.y, n.x).abs()
	# the outer edge of the deck, at a third of its width from one end
	var edge: Vector2
	if absf(n.y) > 0.5:
		edge = Vector2(deck.position.x + deck.size.x * 0.2, deck.end.y if n.y > 0.0 else deck.position.y)
	else:
		edge = Vector2(deck.end.x if n.x > 0.0 else deck.position.x, deck.position.y + deck.size.y * 0.2)
	# just inside the edge, under the boards, so it stays within the platform
	var out_p: Vector2 = edge - n * 0.04
	var top := -DECK_T
	var bottom := water_y(spec) - 0.3
	var height := top - bottom
	if height <= 0.1:
		return
	for side in [-1.0, 1.0]:
		var at: Vector2 = out_p + across * (LADDER_W * 0.5 * side)
		b.component_box("pile_ladder", Vector3(0.06, height, 0.06),
			Transform3D(Basis.IDENTITY, Vector3(at.x, bottom + height * 0.5, at.y)), SURF_TRIM)
	var rungs: int = int(floor(height / RUNG_STEP))
	for k in range(1, rungs + 1):
		var y: float = top - float(k) * RUNG_STEP
		if y <= bottom + 0.05:
			break
		var size := Vector3(LADDER_W, 0.04, 0.04) if absf(n.y) > 0.5 else Vector3(0.04, 0.04, LADDER_W)
		b.component_box("pile_ladder", size, Transform3D(Basis.IDENTITY, Vector3(out_p.x, y, out_p.y)), SURF_TRIM)
