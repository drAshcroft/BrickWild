import io

p = 'src/castle/castle_generator.gd'
s = io.open(p, encoding='utf-8').read()

anchor = '# ------------------------------------------------------------- the interior'
assert anchor in s, 'anchor'

block = '''# ---------------------------------------------------------------- the yard

## What stands in the bailey besides the keep, the hall and the chapel
## (CAS-012; CRITIQUE 2.5, 3.2).
##
## A castle was a village that happened to have a wall round it. The bailey
## here was an empty yard with three big blocks in it, which is a picture of a
## castle nobody worked in: no stable for the horses that got you there, no
## kitchen away from the hall it feeds, no smithy, no store, no well.
##
## Each entry is a SHOP -- the shop family already knows how to plan a stable,
## a cookshop, a smithy and a store, so the bailey does not invent building
## kinds of its own:
##
##   {"business": StringName, "spec": ShopSpec, "rect": Rect2, "yaw": float}
##
## `rect` is the plan footprint in castle space and `yaw` turns the shop's own
## front (-Z, like every family here) to face the yard. Empty for anything
## that is not a walled castle: a manor has no bailey to fill.
static func bailey_buildings(spec: CastleSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not CastleGeometry.is_enclosed(spec):
		return out
	var yard: Rect2 = CastleGeometry.bailey_rect(spec)
	if yard.size.x < 6.0 or yard.size.y < 6.0:
		return out
	var taken: Array[Rect2] = CastleGeometry.bailey_obstacles(spec)
	taken.append(CastleGeometry.gate_axis_strip(spec))

	var roster: Array = BAILEY_ROSTER.get(spec.tier, [])
	var r := RandomNumberGenerator.new()
	r.seed = spec.seed ^ 0x42_41_49_4C
	for row in roster:
		var placed: Dictionary = _place_in_yard(yard, taken, row, r)
		if placed.is_empty():
			continue
		taken.append(Rect2(placed["rect"]).grow(CastleGeometry.BAILEY_CLEAR))
		out.append(placed)
	return out


## Which trades a bailey holds, by tier. A castle keeps the horses and feeds
## itself; a fortress adds the forge and the store, because a garrison that
## size cannot send out for either.
const BAILEY_ROSTER := {
	&"castle": [
		{"business": &"stable", "w": 8.0, "l": 5.5},
		{"business": &"restaurant", "w": 7.0, "l": 5.0},
	],
	&"fortress": [
		{"business": &"stable", "w": 9.0, "l": 6.0},
		{"business": &"restaurant", "w": 7.5, "l": 5.5},
		{"business": &"blacksmith", "w": 7.0, "l": 5.5},
		{"business": &"general_store", "w": 6.5, "l": 5.0},
	],
}
## How far in from the curtain a yard building stands, over and above the
## BAILEY_CLEAR every mass keeps from every other.
const YARD_MARGIN := 0.5
## And how far the well keeps from anything built.
const WELL_CLEAR := 6.0


## One building, against whichever side wall has room for it, marching back
## from the gate. Empty when nothing fits.
##
## Along the SIDES on purpose: the middle of a bailey is the way from the gate
## to the keep and the place a garrison musters, and a yard built across the
## middle is a yard you cannot cross.
static func _place_in_yard(yard: Rect2, taken: Array[Rect2], row: Dictionary,
		r: RandomNumberGenerator) -> Dictionary:
	var clear: float = CastleGeometry.BAILEY_CLEAR
	var w: float = float(row["w"])
	var l: float = float(row["l"])
	# shrink to fit a small ward rather than refuse to stand in one
	var room_x: float = yard.size.x / 2.0 - YARD_MARGIN * 2.0
	w = minf(w, maxf(room_x, 2.5))
	l = minf(l, maxf(yard.size.y * 0.25, 2.5))
	for side in ([-1.0, 1.0] if r.randf() < 0.5 else [1.0, -1.0]):
		var x: float = (yard.end.x - YARD_MARGIN - w / 2.0) if side > 0.0 \\
			else (yard.position.x + YARD_MARGIN + w / 2.0)
		var z: float = yard.position.y + YARD_MARGIN + l / 2.0
		while z + l / 2.0 <= yard.end.y - YARD_MARGIN:
			var rect := Rect2(Vector2(x - w / 2.0, z - l / 2.0), Vector2(w, l))
			if not _hits(rect.grow(clear), taken):
				return {"business": row["business"], "rect": rect,
					"yaw": PI if side < 0.0 else 0.0}
			z += 0.5
	return {}


## The well: in the open yard, clear of everything built and off the way in.
## Empty when the bailey has nowhere to sink one.
static func bailey_well(spec: CastleSpec) -> Dictionary:
	if not CastleGeometry.is_enclosed(spec):
		return {}
	var yard: Rect2 = CastleGeometry.bailey_rect(spec)
	var taken: Array[Rect2] = CastleGeometry.bailey_obstacles(spec)
	taken.append(CastleGeometry.gate_axis_strip(spec))
	for b in bailey_buildings(spec):
		taken.append(Rect2(b["rect"]).grow(WELL_CLEAR))
	var best := Vector2.INF
	var best_d := INF
	var mid: Vector2 = yard.get_center()
	var step := 0.75
	var z: float = yard.position.y + step
	while z < yard.end.y:
		var x: float = yard.position.x + step
		while x < yard.end.x:
			var here := Rect2(Vector2(x - 1.0, z - 1.0), Vector2(2.0, 2.0))
			if not _hits(here, taken):
				var d: float = Vector2(x, z).distance_to(mid)
				if d < best_d:
					best_d = d
					best = Vector2(x, z)
			x += step
		z += step
	return {} if not best.is_finite() else {"pos": best, "radius": 0.9}


static func _hits(rect: Rect2, taken: Array[Rect2]) -> bool:
	for t in taken:
		if t.intersects(rect):
			return true
	return false


## The ShopSpec a bailey building is planned from, generated and ready.
static func bailey_shop(spec: CastleSpec, entry: Dictionary) -> ShopSpec:
	var out := ShopSpec.new()
	out.business = entry["business"]
	var rect: Rect2 = entry["rect"]
	out.width = rect.size.x
	out.length = rect.size.y
	out.height = 2.6
	ShopGenerator.generate(out, spec.seed ^ int(String(entry["business"]).hash()))
	return out


''' + anchor
s = s.replace(anchor, block, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('generator ok')
