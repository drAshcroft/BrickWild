class_name VillageGroundWater
extends RefCounted
## The ground's own standing water as plan water (VTER-LOTS,
## docs/VILLAGE_TERRAIN.md "Lots on the ground").
##
## A grid with `water_level_m` says where its lake or its sea is: every point
## at or under that height (inclusive, as VillageSiteAnalysis reads a DEM's
## water surface). The siting keeps the village off it and the lots refuse it,
## but until it is a `plan.water` polygon nothing else knows it is there: a
## through road routed along a shore ran forty metres into Hallstatt's lake,
## and the walk, the builder, the dressing and the crossing checks all saw dry
## land. Here the wet ground inside the site becomes water polygons (kind
## `coast` for a sea at about 0 m, else `lake`; `"ground": true`), and every
## road is cut back to the shore where it ran into them: a road ends AT the
## water -- a landing, a quay -- and crosses it only on a bridge that lands on
## dry ground at both ends (VillageWaterPlan.crossings).
##
## Only called with ground; a flat plan never reaches this file.

## The raster the shoreline is read on, metres.
const CELL_M := 2.5
## Ground this little above the water level is the strand the water floods,
## and on a 30 m grid the shoreline is uncertain by more than that: it is
## read as water too. Hallstatt's shore road stood 2 mm above its lake.
const FREEBOARD_M := 0.5
## A water body smaller than this (m^2) is a hollow in the DEM, not water.
const MIN_AREA := 4.0 * CELL_M * CELL_M
## Within this of 0 m a water level is the sea.
const SEA_LEVEL_M := 0.5
## A road cut back at the shore stops this far beyond its verge from the
## water, and an end this close (plus SHORE_EPS) to it is "at the shore".
const SHORE_GAP := 0.25
const SHORE_EPS := 1.0
const TRIM_STEP := 0.5


## Add the ground's water inside `plan.site` to `plan.water` and cut every
## road back to its shore. Returns true when there was any.
static func add(plan: VillagePlan) -> bool:
	var g: VillageTerrain = plan.ground
	if g == null or is_nan(g.water_level_m):
		return false
	var polys := polygons(g, plan.site)
	if polys.is_empty():
		return false
	var kind: StringName = &"coast" if absf(g.water_level_m) <= SEA_LEVEL_M else &"lake"
	for p in polys:
		plan.water.append({"poly": p, "kind": kind, "ground": true})
	trim_roads(plan)
	return true


## The wet ground inside `site` as simple polygons: cells of CELL_M whose
## centre is at or under the water level (plus FREEBOARD_M), merged. An island inside a lake is
## read as lake (the outline is kept, the hole dropped) -- a 30 m grid sees
## none worth a house.
static func polygons(g: VillageTerrain, site: Rect2) -> Array[PackedVector2Array]:
	var wl: float = g.water_level_m + FREEBOARD_M
	var cols: int = maxi(1, int(ceil(site.size.x / CELL_M)))
	var rows: int = maxi(1, int(ceil(site.size.y / CELL_M)))
	var cw: float = site.size.x / float(cols)
	var ch: float = site.size.y / float(rows)
	var out: Array[PackedVector2Array] = []
	for row in range(rows):
		var y0: float = site.position.y + ch * float(row)
		var start := -1
		for col in range(cols + 1):
			var wet := false
			if col < cols:
				var c := Vector2(site.position.x + cw * (float(col) + 0.5), y0 + ch * 0.5)
				wet = g.height_at(c) <= wl
			if wet and start < 0:
				start = col
			elif not wet and start >= 0:
				# a little proud of the cell so neighbours share an edge to merge on
				var rect := Rect2(Vector2(site.position.x + cw * float(start), y0),
					Vector2(cw * float(col - start), ch)).grow(0.01)
				_merge_into(out, Poly.from_rect(rect))
				start = -1
	var kept: Array[PackedVector2Array] = []
	for p in out:
		if Poly.area(p) >= MIN_AREA:
			kept.append(_clip_to(p, site))
	return kept


static func _merge_into(polys: Array[PackedVector2Array], piece: PackedVector2Array) -> void:
	var merged := piece
	for i in range(polys.size() - 1, -1, -1):
		if Geometry2D.intersect_polygons(polys[i], merged).is_empty():
			continue
		var res: Array[PackedVector2Array] = Geometry2D.merge_polygons(polys[i], merged)
		var outer: Array[PackedVector2Array] = []
		for q in res:
			if not Geometry2D.is_polygon_clockwise(q):
				outer.append(q)
		if outer.size() == 1:
			merged = outer[0]
			polys.remove_at(i)
	polys.append(merged)


static func _clip_to(p: PackedVector2Array, site: Rect2) -> PackedVector2Array:
	var inside: Array[PackedVector2Array] = Geometry2D.intersect_polygons(p, Poly.from_rect(site))
	if inside.size() == 1:
		return inside[0]
	return p


## Is `p` at the shore of the ground's own water: within the road's half
## width, its verge and SHORE_GAP + SHORE_EPS of it? What VillageRoadCheck
## accepts as a road's end in place of the site's edge.
static func on_shore(plan: VillagePlan, p: Vector2, reach := 4.0) -> bool:
	for w in plan.water:
		if not bool(w.get("ground", false)):
			continue
		if VillageMeasure.point_to_poly(p, w["poly"]) <= reach:
			return true
	return false


## Cut every road back to the shore at whichever end runs into the ground's
## water, so its ribbon and verges stop short of it. A road that is wet from
## end to end is taken up (the through road never is: the router keeps it
## dry where it can, and a through road under water is VillageRoadCheck's to
## report).
static func trim_roads(plan: VillagePlan) -> void:
	var waters: Array[PackedVector2Array] = []
	for w in plan.water:
		if bool(w.get("ground", false)):
			waters.append(w["poly"])
	if waters.is_empty():
		return
	var changed := false
	for r in range(plan.roads.size() - 1, -1, -1):
		var road: Dictionary = plan.roads[r]
		var pts: PackedVector2Array = road["points"]
		var clear: float = float(road["width"]) * 0.5 + float(road.get("verge", 0.0)) + SHORE_GAP
		var length := Poly.polyline_length(pts)
		var s0 := 0.0
		while s0 < length and _near(waters, _at(pts, s0), clear):
			s0 += TRIM_STEP
		var s1 := length
		while s1 > s0 and _near(waters, _at(pts, s1), clear):
			s1 -= TRIM_STEP
		if s0 <= 0.0 and s1 >= length:
			continue
		changed = true
		if s1 - s0 < 2.0:
			if r > 0:
				plan.roads.remove_at(r)
			continue
		road["points"] = _between(pts, s0, s1)
	if changed:
		_drop_cut_off(plan)


## A road whose way onto the network was under the water -- a field track
## leaving the stretch of through road that ran into the lake -- now joins
## nothing: taken up, as the grading takes up a lane that goes nowhere.
static func _drop_cut_off(plan: VillagePlan) -> void:
	var joined := {0: true}
	var grew := true
	while grew:
		grew = false
		for r in range(plan.roads.size()):
			if joined.has(r):
				continue
			for k in joined.keys():
				if VillageSitePlanner._roads_touch(plan.roads[r]["points"], plan.roads[int(k)]["points"]):
					joined[r] = true
					grew = true
					break
	for r in range(plan.roads.size() - 1, 0, -1):
		if not joined.has(r):
			plan.roads.remove_at(r)


static func _near(waters: Array[PackedVector2Array], p: Vector2, clear: float) -> bool:
	for w in waters:
		if VillageMeasure.point_to_poly(p, w) < clear:
			return true
	return false


## The point `s` metres along a polyline.
static func _at(pts: PackedVector2Array, s: float) -> Vector2:
	var run := 0.0
	for i in range(pts.size() - 1):
		var seg: float = pts[i].distance_to(pts[i + 1])
		if run + seg >= s:
			return pts[i].lerp(pts[i + 1], clampf((s - run) / maxf(seg, 1e-9), 0.0, 1.0))
		run += seg
	return pts[pts.size() - 1]


## The polyline from arc length `s0` to `s1`, its own vertices kept between.
static func _between(pts: PackedVector2Array, s0: float, s1: float) -> PackedVector2Array:
	var out := PackedVector2Array([_at(pts, s0)])
	var run := 0.0
	for i in range(pts.size() - 1):
		run += pts[i].distance_to(pts[i + 1])
		if run > s0 + 0.01 and run < s1 - 0.01:
			out.append(pts[i + 1])
	out.append(_at(pts, s1))
	return out
