class_name CastleMoatBuilder
extends RefCounted
## A moat that holds water (EVAL-B02): earth banks up to a crest and down to
## the water, a stone revetment facing the water along the curtain, water with
## shallows and a deep middle, and a causeway carried on piers.
##
## The ground is a plane at y = 0 and the trench a negative mass, so the water
## cannot be dug. It stands at CastleGeometry.WATER_LEVEL and the banks are
## built UP round it. Everything is cut back at the road so the causeway is not
## walled out of its own gate.
##
## What goes where:
##   slot 4 (SURF_GROUND, vertex-coloured)  water, bank, dam. Thin sheets: QA
##          excludes the slot from its solid checks exactly as it did water.
##   slot 0 (stone)                         revetment, causeway deck, parapets
##          and piers: real masonry, so the voxel QA sees and seeds them.
## Masses logged: `bank_<ring>_<side>`, `revetment_<side>`, `causeway` (the deck
## as built) with `causeway_parapet_*` and `causeway_pier_*`. All stand outside
## or on top of the trench, which is below ground, so none interpenetrates it.

const SHALLOW := Color("6f9694")
const MID := Color("587d80")
const DEEP := Color("426167")
const MUD := Color("5d4c37")
const GRASS := Color("66734f")
const GRASS_OUTER := Color("74805a")


static func emit(b: CastleBuilder) -> void:
	var rings := CastleGeometry.moat_rings(b.spec)
	if rings.is_empty():
		return
	b.tag("water")
	b.mark_ground_skin()
	var gap := CastleGeometry.causeway_gap_half(b.spec)
	for row in rings:
		_water(b, row)
	for row in rings:
		b.tag("bank")
		_bank(b, row, gap)
	b.tag("revetment")
	_revetment(b, rings[0], gap)


# ------------------------------------------------------------------- water

## The ring as four rectangles that do not overlap, each in three bands across
## its width: shallows at both edges and the deep water between.
static func _water(b: CastleBuilder, row: Dictionary) -> void:
	var o: Rect2 = row["outer"]
	var w: float = float(row["width"])
	var x0 := o.position.x
	var z0 := o.position.y
	var x1 := o.end.x
	var z1 := o.end.y
	var rects := [
		[Rect2(Vector2(x0, z1 - w), Vector2(x1 - x0, w)), true],             # back
		[Rect2(Vector2(x0, z0), Vector2(w, z1 - w - z0)), false],            # left
		[Rect2(Vector2(x1 - w, z0), Vector2(w, z1 - w - z0)), false],        # right
		[Rect2(Vector2(x0 + w, z0), Vector2(x1 - x0 - 2.0 * w, w)), true],   # front
	]
	var rim: float = minf(1.6, w * 0.2)
	var y := CastleGeometry.WATER_LEVEL
	for entry in rects:
		var r: Rect2 = entry[0]
		var across_z: bool = entry[1]
		var bands := [[0.0, rim, SHALLOW], [rim, rim * 2.0, MID],
			[rim * 2.0, w - rim * 2.0, DEEP], [w - rim * 2.0, w - rim, MID],
			[w - rim, w, SHALLOW]]
		for band in bands:
			var a: float = band[0]
			var c: float = band[1]
			var piece: Rect2
			if across_z:
				piece = Rect2(Vector2(r.position.x, r.position.y + a), Vector2(r.size.x, c - a))
			else:
				piece = Rect2(Vector2(r.position.x + a, r.position.y), Vector2(c - a, r.size.y))
			_flat(b, piece, y, band[2])


static func _flat(b: CastleBuilder, r: Rect2, y: float, colour: Color) -> void:
	if r.size.x < 0.001 or r.size.y < 0.001:
		return
	CastleSkin.quad(b, Vector3(r.position.x, y, r.position.y), Vector3(r.end.x, y, r.position.y),
		Vector3(r.end.x, y, r.end.y), Vector3(r.position.x, y, r.end.y), colour)


# -------------------------------------------------------------------- bank

## The bank round one ring's outer edge: a profile of (distance out, height)
## swept round the four sides, mitred at the corners, with the front cut back
## at the road.
static func _bank(b: CastleBuilder, row: Dictionary, gap: float) -> void:
	var o: Rect2 = row["outer"]
	var run: float = float(row["run"])
	var crest: float = float(row["crest"])
	var last: bool = bool(row["last"])
	var wl := CastleGeometry.WATER_LEVEL
	var profile: Array[Vector2]
	var tones: Array[Color]
	if last:
		profile = [Vector2(0.0, wl), Vector2(1.3, crest), Vector2(2.1, crest * 0.94),
			Vector2(run, 0.0)]
		tones = [MUD, GRASS, GRASS_OUTER]
	else:
		profile = [Vector2(0.0, wl), Vector2(0.65, crest), Vector2(run - 0.65, crest),
			Vector2(run, wl)]
		tones = [MUD, GRASS, MUD]
	CastleSkin.sweep(b, o, profile, tones, gap)
	_bank_masses(b, row, gap)


## Five masses that tile the bank's plan without overlapping: the back takes
## both corners, the sides run between, the front is two spans clear of the road.
static func _bank_masses(b: CastleBuilder, row: Dictionary, gap: float) -> void:
	var o: Rect2 = row["outer"]
	var ring: int = int(row["ring"])
	var run: float = float(row["run"])
	var h: float = float(row["crest"])
	var x0 := o.position.x
	var z0 := o.position.y
	var x1 := o.end.x
	var z1 := o.end.y
	var plans := {
		"back": Rect2(Vector2(x0 - run, z1), Vector2(x1 - x0 + run * 2.0, run)),
		"left": Rect2(Vector2(x0 - run, z0), Vector2(run, z1 - z0)),
		"right": Rect2(Vector2(x1, z0), Vector2(run, z1 - z0)),
		"front_left": Rect2(Vector2(x0 - run, z0 - run), Vector2(-gap - (x0 - run), run)),
		"front_right": Rect2(Vector2(gap, z0 - run), Vector2(x1 + run - gap, run)),
	}
	for side in plans:
		var r: Rect2 = plans[side]
		if r.size.x <= 0.01 or r.size.y <= 0.01:
			continue
		b._log_mass("bank_%d_%s" % [ring, side],
			AABB(Vector3(r.position.x, 0.0, r.position.y), Vector3(r.size.x, h, r.size.y)))


# --------------------------------------------------------------- revetment

## A stone face along the curtain's side of the first ring, standing in the
## water's edge, with the road left open through it.
static func _revetment(b: CastleBuilder, row: Dictionary, gap: float) -> void:
	var inner: Rect2 = row["inner"]
	var t := CastleGeometry.REVET_T
	var h := CastleGeometry.REVET_H
	var x0 := inner.position.x
	var z0 := inner.position.y
	var x1 := inner.end.x
	var z1 := inner.end.y
	var plans := {
		"back": Rect2(Vector2(x0 - t, z1), Vector2(x1 - x0 + 2.0 * t, t)),
		"left": Rect2(Vector2(x0 - t, z0), Vector2(t, z1 - z0)),
		"right": Rect2(Vector2(x1, z0), Vector2(t, z1 - z0)),
		"front_left": Rect2(Vector2(x0 - t, z0 - t), Vector2(-gap - (x0 - t), t)),
		"front_right": Rect2(Vector2(gap, z0 - t), Vector2(x1 + t - gap, t)),
	}
	# Towers, gates and the barbican reach out to the water's edge, and a bastion
	# is not faced with a wall: the revetment runs between them.
	var solids: Array[Rect2] = []
	for m in b.mass_log:
		var nm := String(m["name"])
		if nm.begins_with("tower") or nm.begins_with("gate") or nm.begins_with("barbican") \
				or nm.begins_with("wall") or nm.begins_with("link"):
			var a: AABB = m["aabb"]
			solids.append(Rect2(a.position.x, a.position.z, a.size.x, a.size.z).grow(0.15))
	for side in plans:
		var n := 0
		for r in _cut(plans[side], solids):
			if r.size.x <= 0.3 or r.size.y <= 0.3:
				continue
			b._kit.box(Vector3(r.size.x, h, r.size.y),
				Vector3(r.get_center().x, h * 0.5, r.get_center().y), CastleBuilder.SURF_STONE)
			b._log_mass("revetment_%s%d" % [side, n],
				AABB(Vector3(r.position.x, 0.0, r.position.y), Vector3(r.size.x, h, r.size.y)))
			n += 1


## `r` with every rectangle in `holes` taken out of its long axis: the pieces
## that remain.
static func _cut(r: Rect2, holes: Array[Rect2]) -> Array[Rect2]:
	var along_x: bool = r.size.x >= r.size.y
	var spans: Array[Vector2] = [Vector2(r.position.x, r.end.x) if along_x
		else Vector2(r.position.y, r.end.y)]
	for hole in holes:
		if not hole.intersects(r):
			continue
		var lo: float = hole.position.x if along_x else hole.position.y
		var hi: float = hole.end.x if along_x else hole.end.y
		var next: Array[Vector2] = []
		for sp in spans:
			if hi <= sp.x or lo >= sp.y:
				next.append(sp)
				continue
			if lo > sp.x:
				next.append(Vector2(sp.x, lo))
			if hi < sp.y:
				next.append(Vector2(hi, sp.y))
		spans = next
	var out: Array[Rect2] = []
	for sp in spans:
		out.append(Rect2(Vector2(sp.x, r.position.y), Vector2(sp.y - sp.x, r.size.y)) if along_x
			else Rect2(Vector2(r.position.x, sp.x), Vector2(r.size.x, sp.y - sp.x)))
	return out


# ---------------------------------------------------------------- causeway

## The road over the water: a deck as wide as the drawbridge and a shoulder,
## a parapet along each edge and a row of octagonal piers either side, rising
## from the water against the deck's sides. The rest of the lane the trench
## reserves stays water.
static func causeway(b: CastleBuilder) -> void:
	var deck: AABB = CastleGeometry.causeway_deck_aabb(b.spec)
	if deck.size.x <= 0.0 or deck.size.z <= 0.0:
		return
	b.tag("causeway")
	b._kit.box(deck.size, deck.get_center(), CastleBuilder.SURF_STONE)
	b._log_mass("causeway", deck)
	var half: float = deck.size.x * 0.5
	var top: float = deck.end.y
	var par_t := 0.4
	var par_h := 0.6
	for side in [-1.0, 1.0]:
		var name := "causeway_parapet_%s" % ("left" if side < 0.0 else "right")
		var x: float = side * (half - par_t * 0.5)
		b._kit.box(Vector3(par_t, par_h, deck.size.z),
			Vector3(x, top + par_h * 0.5, deck.get_center().z), CastleBuilder.SURF_STONE)
		b._log_mass(name, AABB(Vector3(x - par_t * 0.5, top, deck.position.z),
			Vector3(par_t, par_h, deck.size.z)), top)
	var count: int = maxi(2, int(floor(deck.size.z / 2.4)))
	var pr: float = CastleGeometry.PIER_SIZE * 0.5
	for i in range(count):
		var z: float = deck.position.z + (float(i) + 0.5) * deck.size.z / float(count)
		for side in [-1.0, 1.0]:
			var x: float = side * (half + pr)
			b._kit.revolve(PackedVector2Array([Vector2(pr, 0.0),
				Vector2(pr, CastleGeometry.PIER_H), Vector2(0.0, CastleGeometry.PIER_H)]),
				Vector3(x, 0.0, z), CastleBuilder.SURF_STONE, 8)
			b._log_mass("causeway_pier_%s%d" % ["l" if side < 0.0 else "r", i],
				AABB(Vector3(x - pr, 0.0, z - pr),
					Vector3(pr * 2.0, CastleGeometry.PIER_H, pr * 2.0)))
