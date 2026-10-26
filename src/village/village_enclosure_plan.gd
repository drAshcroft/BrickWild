class_name VillageEnclosurePlan
extends RefCounted
## Pure VIL-018 geometry derived from an authored VillagePlan.

const EDGE_BAND := 6.0
const GATE_MARGIN := 0.8
const EPS := 0.01

static func build(plan: VillagePlan, edge_band: float = EDGE_BAND) -> Dictionary:
	var hull := _lot_hull(plan)
	var edge := _offset_hull(hull, edge_band)
	# The site is the available ground. Clip the offset at its inner edge:
	# lots near the parcel limit must not put a wall beyond both the ground
	# mesh and the endpoints of the approach roads.
	var clipped := Geometry2D.intersect_polygons(edge, Poly.from_rect(plan.site.grow(-1.0)))
	if not clipped.is_empty():
		edge = clipped[0]
	var gates := crossings(plan.roads, edge)
	var crossings := plan.water_crossings.duplicate(true)
	var fields: Array[Dictionary] = []
	for f in plan.fields:
		if _overlap_area(f["poly"], edge) <= EPS:
			fields.append(f)
	var wood: Vector2 = _preferred_wood(plan)
	var offered: Array[Vector2] = wood_candidates(plan, edge)
	if not offered.is_empty():
		wood = offered[0]
		# on given ground (VTER-PLACE) the wood takes the steepest ground offered
		# to it -- woods stand where nobody ploughs; the first wins a tie, so on
		# level ground the flat village's choice stands
		if plan.ground != null:
			var steepest: float = wood_slope(plan, wood)
			for c in offered:
				var s: float = wood_slope(plan, c)
				if s > steepest + 1e-6:
					steepest = s
					wood = c
	return {"hull": hull, "edge": edge, "gates": gates, "crossings": crossings,
		"fields": fields, "wood": wood}


static func _preferred_wood(plan: VillagePlan) -> Vector2:
	var common: PackedVector2Array = VillageMeasure.common_poly(plan)
	if not common.is_empty():
		return VillageMeasure.centre(common) + Vector2(0.0, -plan.site.size.y * 0.45)
	return plan.site.get_center() + Vector2(0.0, -plan.site.size.y * 0.42)


## Where the far-side wood may stand, in order of preference: beyond the far
## side of the common, then the site's four corners; each on the site,
## outside `edge` and clear of the water by 4 m.
static func wood_candidates(plan: VillagePlan, edge: PackedVector2Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for candidate: Vector2 in [_preferred_wood(plan),
			Vector2(plan.site.position.x + 3.0, plan.site.position.y + 3.0),
			Vector2(plan.site.end.x - 3.0, plan.site.position.y + 3.0),
			Vector2(plan.site.position.x + 3.0, plan.site.end.y - 3.0),
			Vector2(plan.site.end.x - 3.0, plan.site.end.y - 3.0)]:
		var wet := plan.water.any(func(water: Dictionary) -> bool:
			return Poly.contains_point(water["poly"], candidate) or VillageMeasure.point_to_poly(candidate, water["poly"]) < 4.0)
		if plan.site.has_point(candidate) and not Poly.contains_point(edge, candidate) and not wet:
			out.append(candidate)
	return out


## The ground's mean slope over the wood's few trees (a 12 m square about
## `p`); 0 without ground.
static func wood_slope(plan: VillagePlan, p: Vector2) -> float:
	if plan.ground == null:
		return 0.0
	return float(plan.ground.under(Poly.from_rect(Rect2(p - Vector2(6.0, 6.0), Vector2(12.0, 12.0))))["slope_mean"])

## Woods as plan polygons (VTER-WOOD-POLYGON): on given ground, the steep
## slopes nobody ploughs or builds on. A WOOD_CELL_M lattice over the site; a
## cell is wood where its ground is dry and on the mean at least WOOD_SLOPE_MIN
## (past a pasture's 30 %, VillageDispersedForm.FIELD_PASTURE) and under
## WOOD_SLOPE_MAX (past 45 degrees it is bare rock), outside the
## settlement's edge, and clear of every lot, field, common, water and road by
## WOOD_CLEAR_M. Four-connected runs of WOOD_MIN_CELLS or more become one wood:
## {"kind": &"wood", "poly" (the outline; a lot or road inside a wood's run is
## left in it only when no cell of it is wood), "area_m2", "slope_mean"}.
## Empty without ground. Pure, and nothing in the plan is written: the
## dresser's far-side trees are unchanged; the exporter writes `woods`.
const WOOD_CELL_M := 12.0
const WOOD_SLOPE_MIN := 0.30
const WOOD_SLOPE_MAX := 1.0
const WOOD_CLEAR_M := 3.0
const WOOD_MIN_CELLS := 6
static func woods(plan: VillagePlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if plan == null or plan.ground == null:
		return out
	var g: VillageTerrain = plan.ground
	var edge: PackedVector2Array = plan.enclosure if plan.enclosure.size() >= 3 else build(plan)["edge"]
	var blocks: Array[PackedVector2Array] = []
	for list in [plan.lots, plan.fields, plan.commons, plan.water]:
		for row in list:
			blocks.append(row["poly"])
	var nx := int(floor(plan.site.size.x / WOOD_CELL_M))
	var ny := int(floor(plan.site.size.y / WOOD_CELL_M))
	if nx < 1 or ny < 1:
		return out
	var half := WOOD_CELL_M * 0.5
	var reach: float = half * sqrt(2.0) + WOOD_CLEAR_M
	var wood := PackedByteArray()
	wood.resize(nx * ny)
	var slope := PackedFloat32Array()
	slope.resize(nx * ny)
	for j in range(ny):
		for i in range(nx):
			var cell := Rect2(plan.site.position + Vector2(i, j) * WOOD_CELL_M, Vector2(WOOD_CELL_M, WOOD_CELL_M))
			var c := cell.get_center()
			if edge.size() >= 3 and (Poly.contains_point(edge, c) or VillageMeasure.point_to_poly(c, edge) < half):
				continue
			var u: Dictionary = g.under(Poly.from_rect(cell))
			var us: float = float(u["slope_mean"])
			if float(u["dry_share"]) < 1.0 or us < WOOD_SLOPE_MIN or us > WOOD_SLOPE_MAX:
				continue
			var clear := true
			for b in blocks:
				if Poly.contains_point(b, c) or VillageMeasure.point_to_poly(c, b) < reach:
					clear = false
					break
			if clear:
				for road in plan.roads:
					var pts: PackedVector2Array = road["points"]
					var keep: float = float(road["width"]) * 0.5 + reach
					for k in range(pts.size() - 1):
						if c.distance_to(Geometry2D.get_closest_point_to_segment(c, pts[k], pts[k + 1])) < keep:
							clear = false
							break
					if not clear:
						break
			if clear:
				wood[j * nx + i] = 1
				slope[j * nx + i] = float(u["slope_mean"])
	var seen := PackedByteArray()
	seen.resize(nx * ny)
	for start in range(nx * ny):
		if wood[start] == 0 or seen[start] != 0:
			continue
		var cells: Array[int] = []
		var stack: Array[int] = [start]
		seen[start] = 1
		while not stack.is_empty():
			var k: int = stack.pop_back()
			cells.append(k)
			var ci: int = k % nx
			var cj: int = k / nx
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ni: int = ci + d.x
				var nj: int = cj + d.y
				if ni < 0 or nj < 0 or ni >= nx or nj >= ny:
					continue
				var nk: int = nj * nx + ni
				if wood[nk] != 0 and seen[nk] == 0:
					seen[nk] = 1
					stack.append(nk)
		if cells.size() < WOOD_MIN_CELLS:
			continue
		cells.sort()
		# row runs, then one union: the outline of the run's squares
		var pieces: Array[PackedVector2Array] = []
		var s := 0.0
		var r := 0
		while r < cells.size():
			var e := r
			while e + 1 < cells.size() and cells[e + 1] == cells[e] + 1 and cells[e + 1] / nx == cells[r] / nx:
				e += 1
			var p0: Vector2 = plan.site.position + Vector2(cells[r] % nx, cells[r] / nx) * WOOD_CELL_M
			pieces.append(Poly.from_rect(Rect2(p0, Vector2((e - r + 1) * WOOD_CELL_M, WOOD_CELL_M))))
			for q in range(r, e + 1):
				s += slope[cells[q]]
			r = e + 1
		var outline: PackedVector2Array = pieces[0]
		var rest: Array[PackedVector2Array] = pieces.slice(1)
		# runs touch only rows apart; merge row by row until nothing joins
		var guard := 0
		while not rest.is_empty() and guard < cells.size() * 2:
			guard += 1
			var joined := false
			for q in range(rest.size()):
				var merged: Array[PackedVector2Array] = Geometry2D.merge_polygons(outline, rest[q])
				var outers: Array[PackedVector2Array] = []
				for m in merged:
					if not Geometry2D.is_polygon_clockwise(m):
						outers.append(m)
				if outers.size() == 1:
					outline = outers[0]
					rest.remove_at(q)
					joined = true
					break
			if not joined:
				break
		out.append({"kind": &"wood", "poly": outline,
			"area_m2": float(cells.size()) * WOOD_CELL_M * WOOD_CELL_M,
			"slope_mean": s / float(cells.size())})
	return out


static func _lot_hull(plan: VillagePlan) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for lot in plan.lots:
		for p in lot["poly"]:
			pts.append(p)
	if pts.size() < 3:
		return Poly.from_rect(plan.site.grow(-4.0))
	return Geometry2D.convex_hull(pts)

static func _offset_hull(poly: PackedVector2Array, amount: float) -> PackedVector2Array:
	var offset_polys: Array[PackedVector2Array] = Geometry2D.offset_polygon(poly, amount)
	if not offset_polys.is_empty() and offset_polys[0].size() >= 3:
		return offset_polys[0]
	var out := PackedVector2Array()
	var c: Vector2 = VillageMeasure.centre(poly)
	for p in poly:
		out.append(p + (p - c).normalized() * amount)
	return out

## Store final geometry, never projected near-misses. A single road segment
## can enter AND leave the boundary. Minor field routes get a postern rather
## than a ceremonial through-road gateway, but both remain passable.
static func crossings(roads: Array[Dictionary], edge: PackedVector2Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in roads.size():
		var road := roads[r]
		var points: PackedVector2Array = road["points"]
		for i in range(points.size() - 1):
			var direction := (points[i + 1] - points[i]).normalized()
			for e in edge.size():
				var a := edge[e]
				var b := edge[(e + 1) % edge.size()]
				var hit = Geometry2D.segment_intersects_segment(points[i], points[i + 1], a, b)
				if hit == null or out.any(func(g): return int(g["road"]) == r and Vector2(g["pos"]).distance_to(hit) < 0.01):
					continue
				var tangent := (b - a).normalized()
				var width := float(road["width"]) + GATE_MARGIN
				out.append({"pos": Vector2(hit), "road": r, "edge": e,
					"kind": &"gate" if road["class"] == &"through" else &"postern",
					"direction": direction, "tangent": tangent, "width": width,
					"opening": width / maxf(absf(direction.cross(tangent)), 0.05)})
	return out


static func author(plan: VillagePlan) -> void:
	plan.enclosure = PackedVector2Array()
	plan.gate_crossings.clear()
	if plan.spec.enclosure == &"none":
		return
	var derived := build(plan)
	plan.enclosure = derived["edge"]
	plan.enclosure_kept_fraction = clampf(plan.spec.enclosure_kept_fraction, 0.0, 1.0)
	plan.gate_crossings.assign(derived["gates"])

static func _nearest_boundary(p: Vector2, poly: PackedVector2Array) -> Vector2:
	var best: Vector2 = poly[0]
	var d: float = INF
	for i in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var ab: Vector2 = b - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var q: Vector2 = a + ab * t
		if q.distance_squared_to(p) < d:
			d = q.distance_squared_to(p)
			best = q
	return best

static func _overlap_area(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var hits: Array = Geometry2D.intersect_polygons(a, b)
	if hits.is_empty():
		return 0.0
	return Poly.area(hits[0])
