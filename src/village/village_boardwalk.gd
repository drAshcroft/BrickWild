class_name VillageBoardwalk
extends RefCounted
## The boardwalks of a water village on their piles (VTER-FORM-WATER,
## VillageWaterForm): what VillageBuilder emits for every crossing of kind
## `boardwalk`, in place of a bridge. Only ever reached on given ground; a
## plan without boardwalks emits nothing here, not a vertex.
##
##   boardwalk_deck    the deck, top at the road's `deck_m` (the water level
##                     plus the piles' freeboard: level with every pile house's
##                     landing), as wide as the road's verged ribbon -- the
##                     crossings' ribbons, each less the ones laid before it, so
##                     no two deck faces lie in one plane at a junction
##   boardwalk_bearer  a beam across under the deck at every pair of posts
##   boardwalk_pile    the posts, both edges, every PILE_SPACING, from the
##                     bearers down into the bed
##   boardwalk_ramp    where a crossing lands on the bank, a ramp from the deck
##                     to the ground at no more than RAMP_GRADE
##
## Host "boardwalks"; surface timber.

const DECK_T := HousePiles.DECK_T
const BEARER_H := HousePiles.BEARER_H
const BEARER_W := HousePiles.BEARER_W
const PILE_W := HousePiles.PILE_W
const PILE_SPACING := HousePiles.PILE_SPACING
const EMBED_M := HousePiles.EMBED_M
## A post this close to one already placed is the same post.
const POST_MERGE := 0.6
## The steepest a ramp onto the bank may be (a cart's grade, VILLAGES §5).
const RAMP_GRADE := 0.12
const RAMP_T := 0.06


static func crossings(plan: VillagePlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in plan.water_crossings:
		if c["kind"] == &"boardwalk":
			out.append(c)
	return out


## The deck of crossing `c` in plan: its verged ribbon.
static func ribbon(c: Dictionary) -> PackedVector2Array:
	return Poly.ribbon(c["points"], (float(c["width"]) + VillageBuilder.BRIDGE_MARGIN) * 0.5)


static func emit(b: VillageBuilder, plan: VillagePlan) -> void:
	var walks := crossings(plan)
	if walks.is_empty() or b._surface == null:
		return
	var surface: VillageGroundSurface = b._surface
	b.host("boardwalks")
	var bounds := AABB()
	var first := true
	# the deck: each ribbon less those laid before it
	var laid: Array[PackedVector2Array] = []
	for c in walks:
		var deck: float = _deck(plan, c)
		var pieces: Array[PackedVector2Array] = [ribbon(c)]
		for done in laid:
			var next: Array[PackedVector2Array] = []
			for piece in pieces:
				for rest in Geometry2D.clip_polygons(piece, done):
					if not Geometry2D.is_polygon_clockwise(rest):
						next.append(rest)
			pieces = next
		laid.append(ribbon(c))
		for piece in pieces:
			for part in _convex_parts(piece):
				var pts := PackedVector3Array()
				for v in part:
					pts.append(Vector3(v.x, deck - DECK_T * 0.5, v.y))
				var row := b.component_slab("boardwalk_deck", pts, DECK_T, VillageBuilder.SURF_WOOD)
				var box := MassBuilder.component_aabb(row)
				bounds = box if first else bounds.merge(box)
				first = false
	# bearers and posts along each crossing
	var posts: Array[Vector2] = []
	var stations: Array[Vector2] = []
	for c in walks:
		var deck: float = _deck(plan, c)
		var half: float = (float(c["width"]) + VillageBuilder.BRIDGE_MARGIN) * 0.5
		var under: float = deck - DECK_T - BEARER_H
		var pts: PackedVector2Array = c["points"]
		var length := Poly.polyline_length(pts)
		var n: int = maxi(1, int(ceil(length / PILE_SPACING)))
		for k in range(n + 1):
			var s: float = length * float(k) / float(n)
			var at: Vector2 = VillageGroundWater._at(pts, s)
			var ahead: Vector2 = VillageGroundWater._at(pts, minf(s + 0.5, length))
			var behind: Vector2 = VillageGroundWater._at(pts, maxf(s - 0.5, 0.0))
			var d: Vector2 = (ahead - behind).normalized()
			var across := Vector2(-d.y, d.x)
			var near := false
			for q in stations:
				near = near or q.distance_to(at) < POST_MERGE * 2.0
			if near:
				continue
			stations.append(at)
			var standing := 0
			for side in [-1.0, 1.0]:
				var p: Vector2 = at + across * (half - PILE_W) * side
				var bed: float = surface.height_at(p)
				if bed >= under - 0.05:
					continue    # the bank under it: the deck is on the ground here
				var clash := false
				for q in posts:
					clash = clash or q.distance_to(p) < POST_MERGE
				if clash:
					continue
				posts.append(p)
				standing += 1
				var foot: float = bed - EMBED_M
				var post := b.component_box("boardwalk_pile", Vector3(PILE_W, under - foot, PILE_W),
					Transform3D(Basis.IDENTITY, Vector3(p.x, (under + foot) * 0.5, p.y)), VillageBuilder.SURF_WOOD)
				bounds = bounds.merge(MassBuilder.component_aabb(post))
			if standing > 0:
				var xf := Transform3D(Basis(Vector3.UP, atan2(-across.y, across.x)),
					Vector3(at.x, deck - DECK_T - BEARER_H * 0.5, at.y))
				b.component_box("boardwalk_bearer", Vector3(half * 2.0 - 0.04, BEARER_H, BEARER_W), xf,
					VillageBuilder.SURF_WOOD)
	# ramps where a crossing lands on the bank
	for c in walks:
		var deck: float = _deck(plan, c)
		var half: float = (float(c["width"]) + VillageBuilder.BRIDGE_MARGIN) * 0.5
		var pts: PackedVector2Array = c["points"]
		for end in [0, pts.size() - 1]:
			var inside: int = 1 if end == 0 else pts.size() - 2
			var dir: Vector2 = (pts[end] - pts[inside]).normalized()
			var near: Vector2 = pts[end]
			var ground: float = b._gy(near)
			if ground < plan.ground.water_level_m - 0.05:
				continue    # this end is out on the water: it meets another boardwalk
			var drop: float = deck - ground
			if absf(drop) <= 0.02:
				continue
			var run: float = clampf(absf(drop) / RAMP_GRADE, 0.6, 12.0)
			var far: Vector2 = near + dir * run
			var foot: float = b._gy(far)
			var across := Vector2(-dir.y, dir.x) * half
			var ramp := PackedVector3Array([
				Vector3(near.x + across.x, deck - RAMP_T * 0.5, near.y + across.y),
				Vector3(far.x + across.x, foot + RAMP_T * 0.5, far.y + across.y),
				Vector3(far.x - across.x, foot + RAMP_T * 0.5, far.y - across.y),
				Vector3(near.x - across.x, deck - RAMP_T * 0.5, near.y - across.y)])
			var row := b.component_slab("boardwalk_ramp", ramp, RAMP_T, VillageBuilder.SURF_WOOD)
			bounds = bounds.merge(MassBuilder.component_aabb(row))
	b._log_mass("boardwalks", bounds)
	b.host_end()


static func _deck(plan: VillagePlan, c: Dictionary) -> float:
	var road: Dictionary = plan.roads[int(c["road"])]
	return float(road.get("deck_m", VillageWaterForm.deck_level(plan.ground)))


## A simple polygon as convex pieces: itself when it is convex, else its
## triangles.
static func _convex_parts(poly: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if poly.size() < 3:
		return out
	var turn := 0.0
	var convex := true
	for i in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var c: Vector2 = poly[(i + 2) % poly.size()]
		var z: float = (b - a).cross(c - b)
		if absf(z) < 1e-9:
			continue
		if turn == 0.0:
			turn = signf(z)
		elif signf(z) != turn:
			convex = false
			break
	if convex:
		out.append(poly)
		return out
	var idx := Geometry2D.triangulate_polygon(poly)
	for k in range(0, idx.size(), 3):
		out.append(PackedVector2Array([poly[idx[k]], poly[idx[k + 1]], poly[idx[k + 2]]]))
	return out
